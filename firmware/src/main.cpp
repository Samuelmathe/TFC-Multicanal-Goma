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
#include <vector>

#include "config.h"

struct CanalEtat {
  int   brutCourant;      // lecture ADC brute (0-4095)
  float tensionADC_V;     // tension lue sur la broche (0-3.3V)
  float courant_A;        // courant simule (A)
  float puissance_W;      // puissance active (W)
  float cosPhi;           // facteur de puissance (cf. remarque dans TacheCalculPuissance)
  float energie_kWh;      // energie cumulee depuis la derniere recharge (kWh)
  float energie_prev_kWh; // valeur precedente, pour calculer le delta credit
  float credit_USD;       // credit restant
  bool  relaisFerme;      // etat du relais (true = alimente)
  bool  coupureVolontaire; // coupure demandee par le locataire lui-meme (absence, etc.)
  String nomAffiche;      // nom reel du locataire, saisi par le bailleur (facultatif)
  String dernierEvenement;
  unsigned long dernierHorodatageMs;
};

// Evenement pas encore recupere par une application (bailleur ou locataire).
// Cf. mettreEnAttente/route /api/historique/nouveaux : chaque canal "possede"
// sa portion de la file, purgee uniquement quand SON proprietaire (ou le
// bailleur pour son propre canal 0) la recupere - une simple consultation par
// le bailleur du canal d'un locataire ne purge pas la file de ce locataire.
struct EvenementEnAttente {
  int canal;
  String type;
  float valeur;
  unsigned long horodatageMs;
};

static CanalEtat canaux[NUM_CANAUX];
static int brutTension = 0;
static float tensionSecteur_V = 0.0f;
static float tarifCourant = TARIF_USD_PAR_KWH;
static std::vector<EvenementEnAttente> evenementsEnAttente;

static SemaphoreHandle_t mutexCanaux;
static SemaphoreHandle_t mutexEvenements;
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
    canaux[i].coupureVolontaire = prefs.getBool("coupvol", false);
    canaux[i].nomAffiche = prefs.getString("nom", "");
    prefs.end();
    canaux[i].energie_prev_kWh = canaux[i].energie_kWh;
    canaux[i].relaisFerme      = canaux[i].credit_USD > 0.0f && !canaux[i].coupureVolontaire;
    canaux[i].dernierEvenement = "demarrage";
    canaux[i].dernierHorodatageMs = millis();
  }

  Preferences config;
  config.begin("config", true);
  tarifCourant = config.getFloat("tarif", TARIF_USD_PAR_KWH);
  config.end();
}

static void sauverCanalDansNVS(int i) {
  char ns[16];
  snprintf(ns, sizeof(ns), "canal%d", i);
  Preferences prefs;
  prefs.begin(ns, false);
  prefs.putFloat("credit", canaux[i].credit_USD);
  prefs.putFloat("energie", canaux[i].energie_kWh);
  prefs.putBool("coupvol", canaux[i].coupureVolontaire);
  prefs.putString("nom", canaux[i].nomAffiche);
  prefs.end();
}

// ---------------------------------------------------------------------------
// Authentification par canal : renvoie l'index du canal dont les identifiants
// (login/mot de passe, cf. config.h) correspondent a la requete, ou -1 si
// aucun ne correspond. Utilise par toutes les routes protegees ci-dessous.
// ---------------------------------------------------------------------------
static int authentifierRequete(AsyncWebServerRequest *request) {
  for (int i = 0; i < NUM_CANAUX; i++) {
    if (request->authenticate(CANAL_USER[i], CANAL_PASSWORD[i])) {
      return i;
    }
  }
  return -1;
}

// Compte technicien (electricien) : role a part, non lie a un canal.
static bool authentifierElectricien(AsyncWebServerRequest *request) {
  return request->authenticate(ELECTRICIEN_USER, ELECTRICIEN_PASSWORD);
}

// ---------------------------------------------------------------------------
// File d'evenements en attente de recuperation par une application (cf.
// struct EvenementEnAttente). Purgee cote application par canal, pas cote
// firmware : l'ESP32 se contente d'empiler, bornee a MAX_EVENEMENTS_EN_ATTENTE
// (le plus ancien est abandonne si la file est pleine faute de recuperation).
// ---------------------------------------------------------------------------
static void mettreEnAttente(int canal, const String &type, float valeur) {
  if (xSemaphoreTake(mutexEvenements, pdMS_TO_TICKS(100)) == pdTRUE) {
    if (evenementsEnAttente.size() >= MAX_EVENEMENTS_EN_ATTENTE) {
      evenementsEnAttente.erase(evenementsEnAttente.begin());
    }
    evenementsEnAttente.push_back({canal, type, valeur, millis()});
    xSemaphoreGive(mutexEvenements);
  }
}

// ---------------------------------------------------------------------------
// Moyenne de plusieurs lectures ADC consecutives, pour lisser le bruit
// propre a l'ADC de l'ESP32 (cf. N_ECHANTILLONS_LISSAGE, config.h).
// ---------------------------------------------------------------------------
static int lireMoyenneADC(int pin, int nEchantillons) {
  long somme = 0;
  for (int k = 0; k < nEchantillons; k++) {
    somme += analogRead(pin);
  }
  return somme / nEchantillons;
}

// ---------------------------------------------------------------------------
// Tache 1 - Acquisition des capteurs (cf. Annexe A.1, prio 3, coeur 1)
// ---------------------------------------------------------------------------
void TacheAcquisitionCapteurs(void *param) {
  for (;;) {
    if (xSemaphoreTake(mutexCanaux, pdMS_TO_TICKS(50)) == pdTRUE) {
      for (int i = 0; i < NUM_CANAUX; i++) {
        canaux[i].brutCourant = lireMoyenneADC(PIN_COURANT[i], N_ECHANTILLONS_LISSAGE);
      }
      xSemaphoreGive(mutexCanaux);
    }
    // ZMPT101B : lu ici aussi, sur l'ADC1 pour rester utilisable meme avec le
    // point d'acces WiFi actif en permanence sur la maquette (cf. config.h)
    brutTension = lireMoyenneADC(PIN_TENSION, N_ECHANTILLONS_LISSAGE);
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

        if (!canaux[i].relaisFerme) {
          // Relais ouvert = circuit reellement coupe : aucun courant ne peut
          // physiquement circuler, donc courant/puissance affiches a 0 et pas
          // d'accumulation d'energie. Sans cette garde, le bruit du potentiometre
          // flottant continuait a "consommer" meme canal coupe, faisant deriver
          // le credit indefiniment vers des valeurs negatives.
          canaux[i].courant_A = 0.0f;
          canaux[i].puissance_W = 0.0f;
          canaux[i].cosPhi = 0.0f;
        } else {
          // Signal centre sur Vcc/2 = 0 A (cf. S1.3.1 / S3.2)
          float ecart = (v - (ADC_VREF / 2.0f)) / (ADC_VREF / 2.0f);
          canaux[i].courant_A = fabsf(ecart) * COURANT_MAX_A;

          // Simplification maquette : echantillon unique par cycle (potentiometres,
          // pas de forme d'onde AC reelle), donc pas de calcul P/Q/cos(phi) reel ici :
          // cosPhi est fixe a 1 (charge purement resistive supposee). L'algorithme
          // complet (echantillonnage N points/cycle, P, S, Q, cos(phi) calcule et
          // non estime) est celui concu pour les capteurs reels ACS712/ZMPT101B,
          // decrit au rapport S2.7 - a brancher ici lors du passage aux vrais
          // capteurs. cosPhi expose malgre tout (ecran electricien) pour que la
          // grandeur existe dans l'API des la maquette, avec sa limite documentee.
          canaux[i].puissance_W = tensionSecteur_V * canaux[i].courant_A;
          canaux[i].cosPhi = 1.0f;

          // E += P x dt, dt en heures pour un resultat en kWh
          float dt_h = (PERIODE_CALCUL_MS / 1000.0f) / 3600.0f;
          canaux[i].energie_kWh += (canaux[i].puissance_W / 1000.0f) * dt_h;
        }
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

        bool doitEtreFerme = canaux[i].credit_USD > 0.0f && !canaux[i].coupureVolontaire;
        if (doitEtreFerme != canaux[i].relaisFerme) {
          canaux[i].relaisFerme = doitEtreFerme;
          String evt;
          if (doitEtreFerme) {
            evt = "retablissement";
          } else {
            evt = canaux[i].coupureVolontaire ? "coupure_volontaire" : "coupure_credit";
          }
          canaux[i].dernierEvenement = evt;
          canaux[i].dernierHorodatageMs = millis();
          mettreEnAttente(i, evt, 0.0f);
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
  doc["maintenant_ms"] = millis(); // reference pour calculer "il y a X min" cote app
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
      // Equivalent en kWh du credit restant, au tarif courant (1 USD = 1/tarif kWh)
      c["credit_kWh"] = (tarifCourant > 0.0f) ? (canaux[i].credit_USD / tarifCourant) : 0.0f;
      c["cos_phi"] = canaux[i].cosPhi;
      c["relais_ferme"] = canaux[i].relaisFerme;
      c["coupure_volontaire"] = canaux[i].coupureVolontaire;
      c["nom_affiche"] = canaux[i].nomAffiche;
      c["dernier_evenement"] = canaux[i].dernierEvenement;
      c["dernier_horodatage_ms"] = canaux[i].dernierHorodatageMs;
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
    mettreEnAttente(idx, "recharge", montant);
    request->send(200, "application/json", construireJsonEtat());
  });

  // Identification - utilisee par l'ecran de connexion de l'application pour
  // savoir si les identifiants saisis correspondent au bailleur, a un
  // locataire (et lequel) ou au compte electricien, cf. S2.9/S2.10.
  server.on("/api/moi", HTTP_GET, [](AsyncWebServerRequest *request) {
    if (authentifierElectricien(request)) {
      JsonDocument doc;
      doc["canal"] = -1;
      doc["role"] = "electricien";
      String out;
      serializeJson(doc, out);
      request->send(200, "application/json", out);
      return;
    }
    int canal = authentifierRequete(request);
    if (canal < 0) {
      return request->requestAuthentication();
    }
    JsonDocument doc;
    doc["canal"] = canal;
    doc["role"] = (canal == 0) ? "bailleur" : "locataire";
    String out;
    serializeJson(doc, out);
    request->send(200, "application/json", out);
  });

  // Evenements pas encore recuperes par l'application, pour un canal donne
  // (cf. struct EvenementEnAttente). L'historique long terme est stocke cote
  // application (base locale sur le telephone) ; cette route ne sert qu'a
  // garantir qu'aucun evenement n'est perdu si l'app etait fermee au moment
  // ou il s'est produit. La file de CE canal n'est purgee que si le
  // demandeur EST ce canal (son proprietaire) - une simple consultation par
  // le bailleur du canal d'un locataire ne purge pas la file de ce dernier.
  server.on("/api/historique/nouveaux", HTTP_GET, [](AsyncWebServerRequest *request) {
    if (!request->hasParam("canal")) {
      request->send(400, "text/plain", "parametre canal manquant");
      return;
    }
    int canal = request->getParam("canal")->value().toInt();
    if (canal < 0 || canal >= NUM_CANAUX) {
      request->send(400, "text/plain", "canal invalide");
      return;
    }
    int canalAuth = authentifierRequete(request);
    if (canalAuth < 0) {
      return request->requestAuthentication();
    }
    if (canalAuth != 0 && canalAuth != canal) {
      request->send(403, "text/plain", "acces refuse a ce canal");
      return;
    }
    bool doitPurger = (canalAuth == canal);
    String out = "[";
    bool premier = true;
    if (xSemaphoreTake(mutexEvenements, pdMS_TO_TICKS(100)) == pdTRUE) {
      for (auto it = evenementsEnAttente.begin(); it != evenementsEnAttente.end();) {
        if (it->canal == canal) {
          if (!premier) out += ",";
          JsonDocument doc;
          doc["type"] = it->type;
          doc["valeur"] = it->valeur;
          doc["horodatage_ms"] = it->horodatageMs;
          String ligne;
          serializeJson(doc, ligne);
          out += ligne;
          premier = false;
          if (doitPurger) {
            it = evenementsEnAttente.erase(it);
            continue;
          }
        }
        ++it;
      }
      xSemaphoreGive(mutexEvenements);
    }
    out += "]";
    request->send(200, "application/json", out);
  });

  // Coupure/retablissement volontaire par le locataire lui-meme (absence,
  // depart en voyage, etc.) - independant du credit restant. Le bailleur peut
  // aussi l'actionner pour le compte d'un locataire.
  server.on("/api/canal/couper", HTTP_GET, [](AsyncWebServerRequest *request) {
    if (!request->hasParam("canal")) {
      request->send(400, "text/plain", "parametre canal manquant");
      return;
    }
    int canal = request->getParam("canal")->value().toInt();
    if (canal < 0 || canal >= NUM_CANAUX) {
      request->send(400, "text/plain", "canal invalide");
      return;
    }
    int canalAuth = authentifierRequete(request);
    if (canalAuth < 0) {
      return request->requestAuthentication();
    }
    if (canalAuth != 0 && canalAuth != canal) {
      request->send(403, "text/plain", "acces refuse a ce canal");
      return;
    }
    if (xSemaphoreTake(mutexCanaux, pdMS_TO_TICKS(100)) == pdTRUE) {
      canaux[canal].coupureVolontaire = true;
      xSemaphoreGive(mutexCanaux);
    }
    request->send(200, "application/json", construireJsonEtat());
  });

  server.on("/api/canal/retablir", HTTP_GET, [](AsyncWebServerRequest *request) {
    if (!request->hasParam("canal")) {
      request->send(400, "text/plain", "parametre canal manquant");
      return;
    }
    int canal = request->getParam("canal")->value().toInt();
    if (canal < 0 || canal >= NUM_CANAUX) {
      request->send(400, "text/plain", "canal invalide");
      return;
    }
    int canalAuth = authentifierRequete(request);
    if (canalAuth < 0) {
      return request->requestAuthentication();
    }
    if (canalAuth != 0 && canalAuth != canal) {
      request->send(403, "text/plain", "acces refuse a ce canal");
      return;
    }
    if (xSemaphoreTake(mutexCanaux, pdMS_TO_TICKS(100)) == pdTRUE) {
      canaux[canal].coupureVolontaire = false;
      xSemaphoreGive(mutexCanaux);
    }
    request->send(200, "application/json", construireJsonEtat());
  });

  // Tarif (USD/kWh) - lecture publique (deja dans /api/etat), modification
  // reservee au bailleur. L'app affiche/edite l'equivalent en kWh par dollar.
  server.on("/api/tarif", HTTP_GET, [](AsyncWebServerRequest *request) {
    if (!request->hasParam("valeur")) {
      JsonDocument doc;
      doc["tarif_usd_par_kwh"] = tarifCourant;
      String out;
      serializeJson(doc, out);
      request->send(200, "application/json", out);
      return;
    }
    if (!request->authenticate(CANAL_USER[0], CANAL_PASSWORD[0])) {
      return request->requestAuthentication();
    }
    float valeur = request->getParam("valeur")->value().toFloat();
    if (valeur <= 0.0f) {
      request->send(400, "text/plain", "valeur invalide");
      return;
    }
    tarifCourant = valeur;
    Preferences config;
    config.begin("config", false);
    config.putFloat("tarif", tarifCourant);
    config.end();
    request->send(200, "application/json", construireJsonEtat());
  });

  // Nom affiche d'un canal (fiche locataire) - reserve au bailleur. Stocke
  // sur l'ESP32 (pas cote app) car c'est une metadonnee du canal, la meme
  // pour tous les appareils qui s'y connectent, comme le tarif.
  server.on("/api/canal/nom", HTTP_GET, [](AsyncWebServerRequest *request) {
    if (!request->hasParam("canal") || !request->hasParam("valeur")) {
      request->send(400, "text/plain", "parametres manquants (canal, valeur)");
      return;
    }
    int canal = request->getParam("canal")->value().toInt();
    if (canal < 0 || canal >= NUM_CANAUX) {
      request->send(400, "text/plain", "canal invalide");
      return;
    }
    if (!request->authenticate(CANAL_USER[0], CANAL_PASSWORD[0])) {
      return request->requestAuthentication();
    }
    String valeur = request->getParam("valeur")->value();
    if (valeur.length() > 40) valeur = valeur.substring(0, 40);
    if (xSemaphoreTake(mutexCanaux, pdMS_TO_TICKS(100)) == pdTRUE) {
      canaux[canal].nomAffiche = valeur;
      xSemaphoreGive(mutexCanaux);
    }
    sauverCanalDansNVS(canal);
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
  mutexEvenements = xSemaphoreCreateMutex();
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
