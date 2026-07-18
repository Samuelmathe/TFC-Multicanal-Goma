// TFC ULPGL - Systeme embarque IoT multicanal de sous-comptage
// Firmware de demonstration (maquette Wokwi / breadboard, cf. memoire S3.1-3.6)
//
// Reproduit l'architecture decrite au chapitre 2 : 5 taches FreeRTOS
// (Acquisition, Calcul, Credits, Persistance, ServeurAPI - cf. Annexe A.1),
// capteurs simules par des potentiometres, relais simules par des LED.

#include <Arduino.h>
#include <WiFi.h>
#include <AsyncTCP.h>
#include <ESPAsyncWebServer.h>
#include <ArduinoJson.h>
#include <LittleFS.h>
#include <Preferences.h>

#include "config.h"

struct CanalEtat {
  int   brutCourant;      // lecture ADC brute (0-4095)
  float tensionADC_V;     // tension lue sur la broche (0-3.3V)
  float courant_A;        // courant simule (A)
  float puissance_W;      // puissance active (W)
  float energie_kWh;      // energie cumulee depuis la derniere recharge (kWh)
  float energie_prev_kWh; // valeur precedente, pour calculer le delta credit
  float credit_USD;       // credit restant
  bool  relaisFerme;      // etat du relais (true = alimente)
  String dernierEvenement;
  unsigned long dernierHorodatageMs;
};

static CanalEtat canaux[NUM_CANAUX];
static int brutTension = 0;
static float tensionSecteur_V = 0.0f;
static float tarifCourant = TARIF_USD_PAR_KWH;

static SemaphoreHandle_t mutexCanaux;
static AsyncWebServer server(80);

// ---------------------------------------------------------------------------
// Persistance NVS (Preferences) : credit + energie par canal (cf. S1.5.3)
// ---------------------------------------------------------------------------
static void chargerEtatDepuisNVS() {
  Preferences prefs;
  for (int i = 0; i < NUM_CANAUX; i++) {
    char ns[16];
    snprintf(ns, sizeof(ns), "canal%d", i);
    prefs.begin(ns, true);
    canaux[i].credit_USD      = prefs.getFloat("credit", CREDIT_INITIAL_USD);
    canaux[i].energie_kWh     = prefs.getFloat("energie", 0.0f);
    prefs.end();
    canaux[i].energie_prev_kWh = canaux[i].energie_kWh;
    canaux[i].relaisFerme      = canaux[i].credit_USD > 0.0f;
    canaux[i].dernierEvenement = "demarrage";
    canaux[i].dernierHorodatageMs = millis();
  }
}

static void sauverCanalDansNVS(int i) {
  char ns[16];
  snprintf(ns, sizeof(ns), "canal%d", i);
  Preferences prefs;
  prefs.begin(ns, false);
  prefs.putFloat("credit", canaux[i].credit_USD);
  prefs.putFloat("energie", canaux[i].energie_kWh);
  prefs.end();
}

// ---------------------------------------------------------------------------
// Tache 1 - Acquisition des capteurs (cf. Annexe A.1, prio 3, coeur 1)
// ---------------------------------------------------------------------------
void TacheAcquisitionCapteurs(void *param) {
  for (;;) {
    if (xSemaphoreTake(mutexCanaux, pdMS_TO_TICKS(50)) == pdTRUE) {
      for (int i = 0; i < NUM_CANAUX; i++) {
        canaux[i].brutCourant = analogRead(PIN_COURANT[i]);
      }
      xSemaphoreGive(mutexCanaux);
    }
    // ZMPT101B : lu ici aussi, en dehors des fenetres critiques WiFi (cf. S1.4.3)
    brutTension = analogRead(PIN_TENSION);
    vTaskDelay(pdMS_TO_TICKS(PERIODE_ACQUISITION_MS));
  }
}

// ---------------------------------------------------------------------------
// Tache 2 - Calcul de la puissance et de l'energie (cf. Annexe A.2, prio 2)
// ---------------------------------------------------------------------------
void TacheCalculPuissance(void *param) {
  unsigned long dernierAffichage = 0;
  for (;;) {
    if (xSemaphoreTake(mutexCanaux, pdMS_TO_TICKS(50)) == pdTRUE) {
      tensionSecteur_V = (brutTension / (float)ADC_RESOLUTION) * TENSION_MAX_V;

      for (int i = 0; i < NUM_CANAUX; i++) {
        float v = (canaux[i].brutCourant / (float)ADC_RESOLUTION) * ADC_VREF;
        canaux[i].tensionADC_V = v;
        // Signal centre sur Vcc/2 = 0 A (cf. S1.3.1 / S3.2)
        float ecart = (v - (ADC_VREF / 2.0f)) / (ADC_VREF / 2.0f);
        canaux[i].courant_A = fabsf(ecart) * COURANT_MAX_A;

        // P = V x I x cos(phi), cos(phi) ~ 1 pour charge resistive (cf. S1.3.3)
        canaux[i].puissance_W = tensionSecteur_V * canaux[i].courant_A;

        // E += P x dt, dt en heures pour un resultat en kWh
        float dt_h = (PERIODE_CALCUL_MS / 1000.0f) / 3600.0f;
        canaux[i].energie_kWh += (canaux[i].puissance_W / 1000.0f) * dt_h;
      }
      xSemaphoreGive(mutexCanaux);
    }

    if (millis() - dernierAffichage >= PERIODE_AFFICHAGE_MS) {
      dernierAffichage = millis();
      Serial.println(F("\n--- Canal | V_secteur(V) | I(A) | P(W) | E_cumulee(kWh) | Credit(USD) | Relais ---"));
      for (int i = 0; i < NUM_CANAUX; i++) {
        Serial.printf("%-6d| %-13.2f| %-6.3f| %-6.2f| %-16.5f| %-12.4f| %s\n",
                      i, tensionSecteur_V, canaux[i].courant_A, canaux[i].puissance_W,
                      canaux[i].energie_kWh, canaux[i].credit_USD,
                      canaux[i].relaisFerme ? "FERME" : "OUVERT");
      }
    }
    vTaskDelay(pdMS_TO_TICKS(PERIODE_CALCUL_MS));
  }
}

// ---------------------------------------------------------------------------
// Tache 3 - Gestion des credits et des relais (cf. Annexe A.2, prio 2)
// ---------------------------------------------------------------------------
void TacheGestionCredits(void *param) {
  for (;;) {
    if (xSemaphoreTake(mutexCanaux, pdMS_TO_TICKS(50)) == pdTRUE) {
      for (int i = 0; i < NUM_CANAUX; i++) {
        float delta_kWh = canaux[i].energie_kWh - canaux[i].energie_prev_kWh;
        if (delta_kWh > 0.0f) {
          canaux[i].credit_USD -= delta_kWh * tarifCourant;
          canaux[i].energie_prev_kWh = canaux[i].energie_kWh;
        }

        bool doitEtreFerme = canaux[i].credit_USD > 0.0f;
        if (doitEtreFerme != canaux[i].relaisFerme) {
          canaux[i].relaisFerme = doitEtreFerme;
          canaux[i].dernierEvenement = doitEtreFerme ? "retablissement" : "coupure";
          canaux[i].dernierHorodatageMs = millis();
        }
        digitalWrite(PIN_RELAIS[i], canaux[i].relaisFerme ? HIGH : LOW);
      }
      xSemaphoreGive(mutexCanaux);
    }
    vTaskDelay(pdMS_TO_TICKS(PERIODE_CREDITS_MS));
  }
}

// ---------------------------------------------------------------------------
// Tache 4 - Persistance LittleFS + NVS (cf. Annexe A.1/A.3, prio 1, coeur 0)
// ---------------------------------------------------------------------------
void TachePersistanceLittleFS(void *param) {
  for (;;) {
    vTaskDelay(pdMS_TO_TICKS(PERIODE_PERSISTANCE_MS));
    if (xSemaphoreTake(mutexCanaux, pdMS_TO_TICKS(100)) == pdTRUE) {
      for (int i = 0; i < NUM_CANAUX; i++) {
        sauverCanalDansNVS(i);

        // Historique JSON par canal (format Annexe A.3)
        JsonDocument doc;
        doc["canal"] = i;
        doc["energie_cumulee_kWh"] = canaux[i].energie_kWh;
        doc["credit_restant"] = canaux[i].credit_USD;
        doc["dernier_evenement"] = canaux[i].dernierEvenement;
        doc["horodatage_ms"] = canaux[i].dernierHorodatageMs;

        char path[24];
        snprintf(path, sizeof(path), "/canal%d.json", i);
        File f = LittleFS.open(path, "w");
        if (f) {
          serializeJson(doc, f);
          f.close();
        }
      }
      xSemaphoreGive(mutexCanaux);
    }
  }
}

// ---------------------------------------------------------------------------
// Construction du JSON d'etat global, consomme par Flutter et par les pages
// HTML/JS servies depuis LittleFS (source de verite commune, cf. S2.10)
// ---------------------------------------------------------------------------
static String construireJsonEtat() {
  JsonDocument doc;
  doc["tension_secteur_V"] = tensionSecteur_V;
  doc["tarif_usd_par_kwh"] = tarifCourant;
  JsonArray arr = doc["canaux"].to<JsonArray>();
  if (xSemaphoreTake(mutexCanaux, pdMS_TO_TICKS(100)) == pdTRUE) {
    for (int i = 0; i < NUM_CANAUX; i++) {
      JsonObject c = arr.add<JsonObject>();
      c["canal"] = i;
      c["role"] = (i == 0) ? "bailleur" : "locataire";
      c["courant_A"] = canaux[i].courant_A;
      c["puissance_W"] = canaux[i].puissance_W;
      c["energie_kWh"] = canaux[i].energie_kWh;
      c["credit_USD"] = canaux[i].credit_USD;
      c["relais_ferme"] = canaux[i].relaisFerme;
      c["dernier_evenement"] = canaux[i].dernierEvenement;
    }
    xSemaphoreGive(mutexCanaux);
  }
  String out;
  serializeJson(doc, out);
  return out;
}

// ---------------------------------------------------------------------------
// Tache 5 - Serveur API embarque (cf. Annexe A.1, prio 1, coeur 0)
// AsyncWebServer est evenementiel (LwIP) ; cette tache initialise le serveur
// et les routes une seule fois, puis reste en veille (cf. S2.9/S2.10).
// ---------------------------------------------------------------------------
void TacheServeurAPI(void *param) {
  // Page d'accueil et pages statiques (HTML/CSS/JS stockees sur LittleFS)
  server.serveStatic("/", LittleFS, "/").setDefaultFile("index.html");

  // API JSON publique - consommee par Flutter et par le JS des pages web (S2.9/S2.10)
  server.on("/api/etat", HTTP_GET, [](AsyncWebServerRequest *request) {
    request->send(200, "application/json", construireJsonEtat());
  });

  // Recharge d'un canal - protegee par mot de passe verifie cote ESP32 (jamais en JS)
  server.on("/api/recharge", HTTP_GET, [](AsyncWebServerRequest *request) {
    if (!request->authenticate("bailleur", ADMIN_PASSWORD)) {
      return request->requestAuthentication();
    }
    if (!request->hasParam("canal") || !request->hasParam("montant")) {
      request->send(400, "text/plain", "parametres manquants (canal, montant)");
      return;
    }
    int idx = request->getParam("canal")->value().toInt();
    float montant = request->getParam("montant")->value().toFloat();
    if (idx < 0 || idx >= NUM_CANAUX || montant <= 0) {
      request->send(400, "text/plain", "parametres invalides");
      return;
    }
    if (xSemaphoreTake(mutexCanaux, pdMS_TO_TICKS(100)) == pdTRUE) {
      canaux[idx].credit_USD += montant;
      canaux[idx].dernierEvenement = "recharge";
      canaux[idx].dernierHorodatageMs = millis();
      xSemaphoreGive(mutexCanaux);
    }
    request->send(200, "application/json", construireJsonEtat());
  });

  // Page admin - HTTP Basic Auth verifiee cote serveur (cf. S2.10)
  server.on("/admin", HTTP_GET, [](AsyncWebServerRequest *request) {
    if (!request->authenticate("bailleur", ADMIN_PASSWORD)) {
      return request->requestAuthentication();
    }
    request->send(LittleFS, "/admin.html", "text/html");
  });

  // Routes /L0 .. /L(NUM_CANAUX-1) : acces locataire en lecture (cf. S2.10)
  for (int i = 0; i < NUM_CANAUX; i++) {
    String chemin = "/L" + String(i);
    server.on(chemin.c_str(), HTTP_GET, [](AsyncWebServerRequest *request) {
      request->send(LittleFS, "/locataire.html", "text/html");
    });
  }

  server.begin();
  Serial.println(F("Serveur API demarre."));

  for (;;) {
    vTaskDelay(pdMS_TO_TICKS(60000));
  }
}

void setup() {
  Serial.begin(115200);
  delay(300);
  Serial.println(F("\n=== TFC ULPGL - Systeme multicanal (maquette Wokwi) ==="));

  if (!LittleFS.begin(true)) {
    Serial.println(F("Erreur montage LittleFS"));
  } else if (!LittleFS.exists("/index.html")) {
    // Attendu dans Wokwi : le simulateur ne charge pas encore d'image LittleFS
    // (limitation connue, cf. wokwi-features#431/#462). Les pages web ne
    // s'afficheront donc pas en simulation ; ce n'est pas une erreur de code.
    // Sur le vrai ESP32 : "PlatformIO: Upload Filesystem Image" avant l'upload
    // du firmware pour que /data soit copie sur la puce.
    Serial.println(F("LittleFS monte mais vide : normal sous Wokwi (voir README)."));
    Serial.println(F("Les tableaux 3.1/3.2 se lisent ici, sur le moniteur serie."));
  }

  for (int i = 0; i < NUM_CANAUX; i++) {
    pinMode(PIN_RELAIS[i], OUTPUT);
    digitalWrite(PIN_RELAIS[i], LOW);
  }

  mutexCanaux = xSemaphoreCreateMutex();
  chargerEtatDepuisNVS();

  WiFi.softAP(WIFI_SSID, WIFI_PASSWORD);
  Serial.print(F("Point d'acces demarre. IP : "));
  Serial.println(WiFi.softAPIP());
  Serial.printf("SSID: %s / mot de passe: %s\n", WIFI_SSID, WIFI_PASSWORD);
  Serial.printf("Admin HTTP - utilisateur: bailleur / mot de passe: %s\n", ADMIN_PASSWORD);

  xTaskCreatePinnedToCore(TacheAcquisitionCapteurs, "Acquisition", 4096, NULL, 3, NULL, 1);
  xTaskCreatePinnedToCore(TacheCalculPuissance,      "Calcul",      4096, NULL, 2, NULL, 1);
  xTaskCreatePinnedToCore(TacheGestionCredits,       "Credits",     2048, NULL, 2, NULL, 1);
  xTaskCreatePinnedToCore(TachePersistanceLittleFS,  "Persistance", 4096, NULL, 1, NULL, 0);
  xTaskCreatePinnedToCore(TacheServeurAPI,           "API",         8192, NULL, 1, NULL, 0);
}

void loop() {
  vTaskDelay(pdMS_TO_TICKS(1000));
}
