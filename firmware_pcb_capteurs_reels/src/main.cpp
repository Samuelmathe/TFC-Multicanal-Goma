// TFC ULPGL - Systeme embarque IoT multicanal de sous-comptage
// Firmware "capteurs reels" (ACS712 + ZMPT101B, 8 canaux) - PCB chapitre 2.
//
// NON TESTE SUR MATERIEL REEL : le PCB concu sous KiCad n'a pas encore ete
// fabrique ni assemble (cf. README.md de ce dossier et rapport §3.7). Ce
// firmware traduit fidelement l'algorithme et le brochage decrits dans le
// memoire (§2.7, Tableau 2.2). Les constantes de calibration (config.h) sont
// des valeurs nominales de datasheet a verifier sur le circuit reel.
//
// Cf. le dossier voisin firmware/ pour la version reellement construite et
// validee (maquette perfboard, 4 canaux, potentiometres simulant les capteurs).

#include <Arduino.h>
#include <WiFi.h>
#include <AsyncTCP.h>
#include <ESPAsyncWebServer.h>
#include <ArduinoJson.h>
#include <LittleFS.h>
#include <Preferences.h>
#include <vector>
#include <math.h>
#include "driver/adc.h"
#include "esp_timer.h"

#include "config.h"

struct CanalEtat {
  float courant_A;            // I_eff (A), calcule sur le dernier cycle secteur complet
  float puissance_W;          // P, puissance active
  float puissanceApparenteVA; // S = I_eff * V_eff
  float puissanceReactiveVAR; // Q = sqrt(S^2 - P^2)
  float cosPhi;                // P / S, calcule (pas suppose egal a 1)
  float energie_kWh;
  float energie_prev_kWh;
  float credit_USD;
  bool  relaisFerme;
  bool  coupureVolontaire;
  String nomAffiche;
  String dernierEvenement;
  unsigned long dernierHorodatageMs;
  unsigned long dernierCycleMs;  // pour Delta t reel entre deux cycles de calcul de CE canal
};

struct EvenementEnAttente {
  int canal;
  String type;
  float valeur;
  unsigned long horodatageMs;
};

static CanalEtat canaux[NUM_CANAUX];
static float tensionSecteur_V = 0.0f;   // V_eff du dernier canal mesure (commun, cf. §2.7)
static float tarifCourant = TARIF_USD_PAR_KWH;
static std::vector<EvenementEnAttente> evenementsEnAttente;

static float offsetCourant_V[NUM_CANAUX];
static float offsetTension_V = ADC_VREF / 2.0f;

static SemaphoreHandle_t mutexCanaux;
static SemaphoreHandle_t mutexEvenements;
static AsyncWebServer server(80);

// ---------------------------------------------------------------------------
// Persistance NVS (Preferences) : credit + energie par canal
// ---------------------------------------------------------------------------
static void chargerEtatDepuisNVS() {
  Preferences prefs;
  for (int i = 0; i < NUM_CANAUX; i++) {
    char ns[16];
    snprintf(ns, sizeof(ns), "canal%d", i);
    prefs.begin(ns, true);
    canaux[i].credit_USD        = prefs.getFloat("credit", CREDIT_INITIAL_USD);
    canaux[i].energie_kWh       = prefs.getFloat("energie", 0.0f);
    canaux[i].coupureVolontaire = prefs.getBool("coupvol", false);
    canaux[i].nomAffiche        = prefs.getString("nom", "");
    prefs.end();
    canaux[i].energie_prev_kWh    = canaux[i].energie_kWh;
    canaux[i].relaisFerme         = canaux[i].credit_USD > 0.0f && !canaux[i].coupureVolontaire;
    canaux[i].dernierEvenement    = "demarrage";
    canaux[i].dernierHorodatageMs = millis();
    canaux[i].dernierCycleMs      = 0; // 0 = pas encore de cycle valide (cf. TacheAcquisitionEtCalcul)
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

static int authentifierRequete(AsyncWebServerRequest *request) {
  for (int i = 0; i < NUM_CANAUX; i++) {
    if (request->authenticate(CANAL_USER[i], CANAL_PASSWORD[i])) return i;
  }
  return -1;
}

static bool authentifierElectricien(AsyncWebServerRequest *request) {
  return request->authenticate(ELECTRICIEN_USER, ELECTRICIEN_PASSWORD);
}

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
// Lecture ADC2 "securisee" : contrairement a analogRead() sur une broche
// ADC2 (qui peut silencieusement renvoyer 0 si le pilote Wi-Fi occupe l'ADC2
// - piege classique et documente de l'ESP32, cf. config.h), adc2_get_raw()
// renvoie un code d'erreur explicite qu'on peut traiter proprement : on
// laisse simplement tomber CET echantillon plutot que d'enregistrer une
// fausse valeur nulle qui fausserait le calcul RMS.
// ---------------------------------------------------------------------------
static bool lireADC2Securise(adc2_channel_t canal, int &valeurBrute) {
  int brut = 0;
  esp_err_t err = adc2_get_raw(canal, ADC_WIDTH_BIT_12, &brut);
  if (err != ESP_OK) return false;
  valeurBrute = brut;
  return true;
}

static adc2_channel_t adc2CanalCourant(int canal) {
  return (canal == 1) ? ADC2_CHANNEL_9 : ADC2_CHANNEL_7; // canal 1 -> GPIO26, canal 2 -> GPIO27
}

// ---------------------------------------------------------------------------
// Calibration des offsets DC (Vcc/2) au demarrage - cf. config.h,
// N_ECHANTILLONS_CALIBRATION. Suppose qu'aucun courant ne circule encore
// (mettre le systeme sous tension avant les charges, cf.
// GUIDE_ASSEMBLAGE_ET_FLASH.md du firmware maquette pour la procedure
// equivalente).
// ---------------------------------------------------------------------------
static void calibrerOffsets() {
  Serial.println(F("Calibration des offsets DC (Vcc/2) - aucun courant ne doit circuler..."));
  for (int i = 0; i < NUM_CANAUX; i++) {
    double somme = 0;
    int valides = 0;
    for (int k = 0; k < N_ECHANTILLONS_CALIBRATION; k++) {
      int brut;
      bool ok;
      if (i == 1 || i == 2) {
        ok = lireADC2Securise(adc2CanalCourant(i), brut);
      } else {
        brut = analogRead(PIN_COURANT_ADC1[i]);
        ok = true;
      }
      if (ok) { somme += brut; valides++; }
      delayMicroseconds(200);
    }
    offsetCourant_V[i] = valides > 0
        ? (somme / valides) / (float)ADC_RESOLUTION * ADC_VREF
        : ADC_VREF / 2.0f; // repli raisonnable si l'ADC2 est reste indisponible durant toute la calibration
  }

  double sommeT = 0;
  int validesT = 0;
  for (int k = 0; k < N_ECHANTILLONS_CALIBRATION; k++) {
    int brut;
    if (lireADC2Securise(ADC2_CHANNEL_8, brut)) { sommeT += brut; validesT++; }
    delayMicroseconds(200);
  }
  offsetTension_V = validesT > 0
      ? (sommeT / validesT) / (float)ADC_RESOLUTION * ADC_VREF
      : ADC_VREF / 2.0f;

  Serial.printf("Offsets calibres : tension=%.4fV\n", offsetTension_V);
}

// ---------------------------------------------------------------------------
// Acquisition + calcul RMS/puissance pour UN canal, sur un cycle secteur
// complet (N_ECHANTILLONS_CYCLE echantillons synchronises courant/tension,
// cf. memoire §2.7). Retourne false si trop d'echantillons ont ete perdus
// (fenetres Wi-Fi actif sur l'ADC2, cf. lireADC2Securise) pour produire une
// mesure fiable sur ce cycle - le canal garde alors sa derniere valeur
// connue plutot que d'afficher un resultat degrade silencieusement.
// ---------------------------------------------------------------------------
struct MesureCycle { float I_eff; float V_eff; float P; };

static bool acquerirCycleCanal(int canal, MesureCycle &resultat) {
  double sommeI2 = 0, sommeV2 = 0, sommeVI = 0;
  int valides = 0;
  bool courantSurADC2 = (canal == 1 || canal == 2);

  int64_t prochainEchantillon = esp_timer_get_time();
  for (int n = 0; n < N_ECHANTILLONS_CYCLE; n++) {
    while (esp_timer_get_time() < prochainEchantillon) { /* attente active, < 500us */ }
    prochainEchantillon += INTERVALLE_ECHANTILLON_US;

    int brutCourant = 0, brutTension = 0;
    bool okCourant = courantSurADC2
        ? lireADC2Securise(adc2CanalCourant(canal), brutCourant)
        : (brutCourant = analogRead(PIN_COURANT_ADC1[canal]), true);
    bool okTension = lireADC2Securise(ADC2_CHANNEL_8, brutTension); // ZMPT101B, toujours ADC2

    if (!okCourant || !okTension) continue; // echantillon perdu, cf. commentaire ci-dessus

    float vCourant = (brutCourant / (float)ADC_RESOLUTION) * ADC_VREF - offsetCourant_V[canal];
    float vTension = (brutTension / (float)ADC_RESOLUTION) * ADC_VREF - offsetTension_V;

    float i = vCourant / ACS712_SENSIBILITE_V_PAR_A;
    float v = vTension * ZMPT_FACTEUR_CALIBRATION;

    sommeI2 += (double)i * i;
    sommeV2 += (double)v * v;
    sommeVI += (double)v * i;
    valides++;
  }

  if (valides < N_ECHANTILLONS_CYCLE / 2) return false; // trop d'echantillons perdus sur ce cycle

  resultat.I_eff = sqrtf(sommeI2 / valides);
  resultat.V_eff = sqrtf(sommeV2 / valides);
  resultat.P     = sommeVI / valides;
  return true;
}

// ---------------------------------------------------------------------------
// Tache 1 - Acquisition sequentielle des 8 canaux + calcul RMS/puissance
// (fusion des taches "Acquisition" et "Calcul" de la maquette : ici les deux
// sont intrinsequement liees, cf. memoire §2.7/§2.7 "acquisition sequentielle").
// Chaque canal occupe ~20 ms minimum (un cycle secteur) ; un tour complet des
// 8 canaux prend donc environ 160 ms ou plus selon les echantillons perdus.
// ---------------------------------------------------------------------------
void TacheAcquisitionEtCalcul(void *param) {
  unsigned long dernierAffichage = 0;
  for (;;) {
    for (int i = 0; i < NUM_CANAUX; i++) {
      bool relaisFermeActuel;
      if (xSemaphoreTake(mutexCanaux, pdMS_TO_TICKS(20)) == pdTRUE) {
        relaisFermeActuel = canaux[i].relaisFerme;
        xSemaphoreGive(mutexCanaux);
      } else {
        relaisFermeActuel = true; // hypothese optimiste, sera corrigee au prochain cycle
      }

      if (!relaisFermeActuel) {
        // Relais ouvert = coupe physiquement : pas de mesure a faire, valeurs a 0
        // (cf. meme raisonnement que sur la maquette : eviter toute derive due au
        // bruit d'un capteur non alimente/non traverse par un courant reel).
        if (xSemaphoreTake(mutexCanaux, pdMS_TO_TICKS(20)) == pdTRUE) {
          canaux[i].courant_A = 0.0f;
          canaux[i].puissance_W = 0.0f;
          canaux[i].puissanceApparenteVA = 0.0f;
          canaux[i].puissanceReactiveVAR = 0.0f;
          canaux[i].cosPhi = 0.0f;
          canaux[i].dernierCycleMs = millis();
          xSemaphoreGive(mutexCanaux);
        }
        continue;
      }

      MesureCycle m;
      bool ok = acquerirCycleCanal(i, m);
      if (!ok) continue; // on garde la derniere valeur connue de ce canal

      float S = m.I_eff * m.V_eff;
      float P = m.P;
      float Q = sqrtf(fmaxf(S * S - P * P, 0.0f));

      if (xSemaphoreTake(mutexCanaux, pdMS_TO_TICKS(20)) == pdTRUE) {
        canaux[i].courant_A = m.I_eff;
        tensionSecteur_V = m.V_eff; // tension secteur commune, supposee stable sur le tour (§2.7)
        canaux[i].puissance_W = P;
        canaux[i].puissanceApparenteVA = S;
        canaux[i].puissanceReactiveVAR = Q;
        canaux[i].cosPhi = (S > 0.0001f) ? (P / S) : 0.0f;

        unsigned long maintenant = millis();
        if (canaux[i].dernierCycleMs != 0) {
          float dt_h = (maintenant - canaux[i].dernierCycleMs) / 1000.0f / 3600.0f;
          if (dt_h > 0.0f && dt_h < 1.0f) { // garde-fou : ecarte un Delta t aberrant (premier tour, overflow millis())
            canaux[i].energie_kWh += (P / 1000.0f) * dt_h; // E += P x dt (methode des rectangles, cf. §2.7)
          }
        }
        canaux[i].dernierCycleMs = maintenant;
        xSemaphoreGive(mutexCanaux);
      }
    }

    if (millis() - dernierAffichage >= PERIODE_AFFICHAGE_MS) {
      dernierAffichage = millis();
      Serial.println(F("\n--- Canal | V_secteur(V) | I(A) | P(W) | S(VA) | Q(VAR) | cos(phi) | E(kWh) | Credit(USD) | Relais ---"));
      if (xSemaphoreTake(mutexCanaux, pdMS_TO_TICKS(50)) == pdTRUE) {
        for (int i = 0; i < NUM_CANAUX; i++) {
          Serial.printf("%-6d| %-13.2f| %-6.3f| %-7.2f| %-7.2f| %-7.2f| %-9.3f| %-9.5f| %-12.4f| %s\n",
                        i, tensionSecteur_V, canaux[i].courant_A, canaux[i].puissance_W,
                        canaux[i].puissanceApparenteVA, canaux[i].puissanceReactiveVAR, canaux[i].cosPhi,
                        canaux[i].energie_kWh, canaux[i].credit_USD,
                        canaux[i].relaisFerme ? "FERME" : "OUVERT");
        }
        xSemaphoreGive(mutexCanaux);
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Tache 2 - Gestion des credits et des relais (identique a la maquette)
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
          String evt = doitEtreFerme
              ? "retablissement"
              : (canaux[i].coupureVolontaire ? "coupure_volontaire" : "coupure_credit");
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
// Tache 3 - Persistance LittleFS + NVS (identique a la maquette)
// ---------------------------------------------------------------------------
void TachePersistanceLittleFS(void *param) {
  for (;;) {
    vTaskDelay(pdMS_TO_TICKS(PERIODE_PERSISTANCE_MS));
    if (xSemaphoreTake(mutexCanaux, pdMS_TO_TICKS(100)) == pdTRUE) {
      for (int i = 0; i < NUM_CANAUX; i++) {
        sauverCanalDansNVS(i);

        JsonDocument doc;
        doc["canal"] = i;
        doc["energie_cumulee_kWh"] = canaux[i].energie_kWh;
        doc["credit_restant"] = canaux[i].credit_USD;
        doc["dernier_evenement"] = canaux[i].dernierEvenement;
        doc["horodatage_ms"] = canaux[i].dernierHorodatageMs;

        char path[24];
        snprintf(path, sizeof(path), "/canal%d.json", i);
        File f = LittleFS.open(path, "w");
        if (f) { serializeJson(doc, f); f.close(); }
      }
      xSemaphoreGive(mutexCanaux);
    }
  }
}

static String construireJsonEtat() {
  JsonDocument doc;
  doc["tension_secteur_V"] = tensionSecteur_V;
  doc["tarif_usd_par_kwh"] = tarifCourant;
  doc["maintenant_ms"] = millis();
  JsonArray arr = doc["canaux"].to<JsonArray>();
  if (xSemaphoreTake(mutexCanaux, pdMS_TO_TICKS(100)) == pdTRUE) {
    for (int i = 0; i < NUM_CANAUX; i++) {
      JsonObject c = arr.add<JsonObject>();
      c["canal"] = i;
      c["role"] = (i == 0) ? "bailleur" : "locataire";
      c["courant_A"] = canaux[i].courant_A;
      c["puissance_W"] = canaux[i].puissance_W;
      c["puissance_apparente_VA"] = canaux[i].puissanceApparenteVA;
      c["puissance_reactive_VAR"] = canaux[i].puissanceReactiveVAR;
      c["energie_kWh"] = canaux[i].energie_kWh;
      c["credit_USD"] = canaux[i].credit_USD;
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
// Tache 4 - Serveur API embarque (routes identiques a la maquette)
// ---------------------------------------------------------------------------
void TacheServeurAPI(void *param) {
  server.serveStatic("/", LittleFS, "/").setDefaultFile("index.html");

  server.on("/api/etat", HTTP_GET, [](AsyncWebServerRequest *request) {
    request->send(200, "application/json", construireJsonEtat());
  });

  server.on("/api/recharge", HTTP_GET, [](AsyncWebServerRequest *request) {
    if (!request->authenticate("bailleur", ADMIN_PASSWORD)) return request->requestAuthentication();
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
      xSemaphoreGive(mutexCanaux);
    }
    mettreEnAttente(idx, "recharge", montant);
    request->send(200, "application/json", construireJsonEtat());
  });

  server.on("/api/moi", HTTP_GET, [](AsyncWebServerRequest *request) {
    if (authentifierElectricien(request)) {
      JsonDocument doc; doc["canal"] = -1; doc["role"] = "electricien";
      String out; serializeJson(doc, out);
      request->send(200, "application/json", out);
      return;
    }
    int canal = authentifierRequete(request);
    if (canal < 0) return request->requestAuthentication();
    JsonDocument doc;
    doc["canal"] = canal;
    doc["role"] = (canal == 0) ? "bailleur" : "locataire";
    String out; serializeJson(doc, out);
    request->send(200, "application/json", out);
  });

  server.on("/api/historique/nouveaux", HTTP_GET, [](AsyncWebServerRequest *request) {
    int canal = authentifierRequete(request);
    bool estBailleur = (canal == 0);
    if (canal < 0 && !authentifierElectricien(request)) return request->requestAuthentication();
    if (!request->hasParam("canal")) { request->send(400, "text/plain", "parametre canal manquant"); return; }
    int cible = request->getParam("canal")->value().toInt();
    if (cible < 0 || cible >= NUM_CANAUX) { request->send(400, "text/plain", "canal invalide"); return; }
    bool proprietaire = (canal == cible) || estBailleur;

    JsonDocument doc;
    JsonArray arr = doc.to<JsonArray>();
    if (xSemaphoreTake(mutexEvenements, pdMS_TO_TICKS(100)) == pdTRUE) {
      for (auto it = evenementsEnAttente.begin(); it != evenementsEnAttente.end();) {
        if (it->canal == cible) {
          JsonObject o = arr.add<JsonObject>();
          o["horodatage_ms"] = it->horodatageMs;
          o["type"] = it->type;
          o["valeur"] = it->valeur;
          it = proprietaire ? evenementsEnAttente.erase(it) : it + 1;
        } else {
          ++it;
        }
      }
      xSemaphoreGive(mutexEvenements);
    }
    String out; serializeJson(doc, out);
    request->send(200, "application/json", out);
  });

  server.on("/api/canal/couper", HTTP_GET, [](AsyncWebServerRequest *request) {
    int appelant = authentifierRequete(request);
    if (appelant < 0) return request->requestAuthentication();
    if (!request->hasParam("canal")) { request->send(400, "text/plain", "parametre canal manquant"); return; }
    int cible = request->getParam("canal")->value().toInt();
    if (cible < 0 || cible >= NUM_CANAUX || (appelant != 0 && appelant != cible)) {
      request->send(403, "text/plain", "non autorise"); return;
    }
    if (xSemaphoreTake(mutexCanaux, pdMS_TO_TICKS(100)) == pdTRUE) {
      canaux[cible].coupureVolontaire = true;
      xSemaphoreGive(mutexCanaux);
    }
    request->send(200, "application/json", construireJsonEtat());
  });

  server.on("/api/canal/retablir", HTTP_GET, [](AsyncWebServerRequest *request) {
    int appelant = authentifierRequete(request);
    if (appelant < 0) return request->requestAuthentication();
    if (!request->hasParam("canal")) { request->send(400, "text/plain", "parametre canal manquant"); return; }
    int cible = request->getParam("canal")->value().toInt();
    if (cible < 0 || cible >= NUM_CANAUX || (appelant != 0 && appelant != cible)) {
      request->send(403, "text/plain", "non autorise"); return;
    }
    if (xSemaphoreTake(mutexCanaux, pdMS_TO_TICKS(100)) == pdTRUE) {
      canaux[cible].coupureVolontaire = false;
      xSemaphoreGive(mutexCanaux);
    }
    request->send(200, "application/json", construireJsonEtat());
  });

  server.on("/api/tarif", HTTP_GET, [](AsyncWebServerRequest *request) {
    if (!request->authenticate("bailleur", ADMIN_PASSWORD)) return request->requestAuthentication();
    if (!request->hasParam("valeur")) { request->send(400, "text/plain", "parametre valeur manquant"); return; }
    float v = request->getParam("valeur")->value().toFloat();
    if (v <= 0) { request->send(400, "text/plain", "valeur invalide"); return; }
    tarifCourant = v;
    Preferences config; config.begin("config", false); config.putFloat("tarif", v); config.end();
    request->send(200, "application/json", construireJsonEtat());
  });

  server.on("/api/canal/nom", HTTP_GET, [](AsyncWebServerRequest *request) {
    if (!request->authenticate("bailleur", ADMIN_PASSWORD)) return request->requestAuthentication();
    if (!request->hasParam("canal") || !request->hasParam("valeur")) {
      request->send(400, "text/plain", "parametres manquants"); return;
    }
    int idx = request->getParam("canal")->value().toInt();
    if (idx < 0 || idx >= NUM_CANAUX) { request->send(400, "text/plain", "canal invalide"); return; }
    String nom = request->getParam("valeur")->value();
    if (xSemaphoreTake(mutexCanaux, pdMS_TO_TICKS(100)) == pdTRUE) {
      canaux[idx].nomAffiche = nom;
      xSemaphoreGive(mutexCanaux);
    }
    request->send(200, "application/json", construireJsonEtat());
  });

  server.on("/admin", HTTP_GET, [](AsyncWebServerRequest *request) {
    if (!request->authenticate("bailleur", ADMIN_PASSWORD)) return request->requestAuthentication();
    request->send(LittleFS, "/admin.html", "text/html");
  });

  for (int i = 0; i < NUM_CANAUX; i++) {
    String chemin = "/L" + String(i);
    server.on(chemin.c_str(), HTTP_GET, [](AsyncWebServerRequest *request) {
      request->send(LittleFS, "/locataire.html", "text/html");
    });
  }

  server.begin();
}

void setup() {
  Serial.begin(115200);
  delay(300);
  Serial.println(F("\n=== TFC ULPGL - Systeme multicanal (PCB, capteurs reels) ==="));
  Serial.println(F("ATTENTION : firmware non teste sur materiel reel, cf. README.md"));

  if (!LittleFS.begin(true)) {
    Serial.println(F("Erreur montage LittleFS"));
  }

  for (int i = 0; i < NUM_CANAUX; i++) {
    pinMode(PIN_RELAIS[i], OUTPUT);
    digitalWrite(PIN_RELAIS[i], LOW);
  }

  // Configuration des broches ADC2 (courant canaux 1/2 + tension ZMPT101B)
  adc2_config_channel_atten(ADC2_CHANNEL_9, ADC_ATTEN_DB_12); // GPIO26
  adc2_config_channel_atten(ADC2_CHANNEL_7, ADC_ATTEN_DB_12); // GPIO27
  adc2_config_channel_atten(ADC2_CHANNEL_8, ADC_ATTEN_DB_12); // GPIO25

  mutexCanaux = xSemaphoreCreateMutex();
  mutexEvenements = xSemaphoreCreateMutex();
  chargerEtatDepuisNVS();

  WiFi.softAP(WIFI_SSID, WIFI_PASSWORD);
  Serial.print(F("Point d'acces demarre. IP : "));
  Serial.println(WiFi.softAPIP());

  calibrerOffsets();

  xTaskCreatePinnedToCore(TacheAcquisitionEtCalcul, "Acquisition", 4096, NULL, 3, NULL, 1);
  xTaskCreatePinnedToCore(TacheGestionCredits,      "Credits",     2048, NULL, 2, NULL, 1);
  xTaskCreatePinnedToCore(TachePersistanceLittleFS, "Persistance", 4096, NULL, 1, NULL, 0);
  xTaskCreatePinnedToCore(TacheServeurAPI,          "API",         8192, NULL, 1, NULL, 0);
}

void loop() {
  vTaskDelay(pdMS_TO_TICKS(1000));
}
