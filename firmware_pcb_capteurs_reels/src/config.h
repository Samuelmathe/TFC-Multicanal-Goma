#pragma once

// =============================================================================
// Configuration - version "capteurs reels" (ACS712 + ZMPT101B), 8 canaux
// Cible : le PCB concu sous KiCad (chapitre 2 du memoire, module WROOM-32 nu).
//
// IMPORTANT : ce firmware n'a PAS ete teste sur le materiel reel - le PCB n'a
// pas encore ete fabrique ni assemble au moment de l'ecriture de ce code (cf.
// rapport, discussion des resultats §3.7 et README de ce dossier). Il traduit
// fidelement l'algorithme et le brochage decrits dans le memoire (§2.7,
// Tableau 2.2), mais les constantes de calibration (ACS712_SENSIBILITE_V_PAR_A,
// ZMPT_FACTEUR_CALIBRATION, offsets) sont des valeurs nominales de datasheet a
// verifier/ajuster sur le circuit reel avant toute mise en service.
//
// Cf. firmware/ (dossier voisin) pour la version validee sur la maquette
// physique reelle (4 canaux, potentiometres simulant les capteurs).
// =============================================================================

#define NUM_CANAUX 8

// --- Echantillonnage synchrone courant/tension (cf. memoire §2.7) ---
// N = 40 echantillons par periode secteur (50 Hz => cycle de 20 ms), un
// compromis entre fidelite de restitution de la forme d'onde et charge de
// calcul compatible avec les contraintes temps reel du firmware (§1.4.2).
static const int      FREQUENCE_SECTEUR_HZ      = 50;
static const uint32_t PERIODE_SECTEUR_US        = 1000000UL / FREQUENCE_SECTEUR_HZ; // 20000 us
static const int      N_ECHANTILLONS_CYCLE      = 40;
static const uint32_t INTERVALLE_ECHANTILLON_US = PERIODE_SECTEUR_US / N_ECHANTILLONS_CYCLE; // 500 us

// --- Broches ADC1 des capteurs de courant ACS712 (cf. Tableau 2.2) ---
// Canal 0 (bailleur) + canaux 3 a 7 (locataires 3 a 7) : ADC1, utilisable en
// continu meme Wi-Fi actif (§1.4.3).
// index canal ->broche : 0->GPIO36, 3->GPIO39, 4->GPIO32, 5->GPIO33, 6->GPIO34, 7->GPIO35
static const int PIN_COURANT_ADC1[NUM_CANAUX] = {
    36, // canal 0 (bailleur)      - ADC1_CH0
    -1, // canal 1 (locataire 1)   - sur ADC2, cf. PIN_COURANT_ADC2 ci-dessous
    -1, // canal 2 (locataire 2)   - sur ADC2, cf. PIN_COURANT_ADC2 ci-dessous
    39, // canal 3 (locataire 3)   - ADC1_CH3
    32, // canal 4 (locataire 4)   - ADC1_CH4
    33, // canal 5 (locataire 5)   - ADC1_CH5
    34, // canal 6 (locataire 6)   - ADC1_CH6
    35  // canal 7 (locataire 7)   - ADC1_CH7
};

// --- Broches ADC2 des capteurs de courant ACS712 pour les canaux 1 et 2 ---
// GPIO37/GPIO38 (Tableau 2.2 "ideal") ne sont PAS sortis sur le module
// ESP32-WROOM-32 : on utilise GPIO26/GPIO27 (ADC2_CH9/ADC2_CH7) a la place.
// ADC2 n'est PAS utilisable pendant que le pilote Wi-Fi l'occupe (limitation
// materielle bien documentee de l'ESP32) : cf. lireADC2Securise() dans
// main.cpp, qui gere ce cas plutot que de l'ignorer silencieusement (piege
// classique d'analogRead() sur ADC2, qui peut renvoyer 0 sans erreur).
static const int PIN_COURANT_ADC2[2] = {
    26, // canal 1 (locataire 1) - ADC2_CH9
    27  // canal 2 (locataire 2) - ADC2_CH7
};

// --- Broche ADC2 du capteur de tension ZMPT101B, commun a tous les canaux ---
// GPIO25 (ADC2_CH8, cf. Tableau 2.2). Meme contrainte ADC2/Wi-Fi que ci-dessus.
static const int PIN_TENSION_ADC2 = 25;

// --- Broches de commande des relais (cf. Tableau 2.2) ---
static const int PIN_RELAIS[NUM_CANAUX] = {4, 5, 13, 14, 16, 17, 18, 19};

// --- Calibration des capteurs (VALEURS NOMINALES DE DATASHEET - a verifier
//     sur le circuit reel avant mise en service, cf. remarque en tete de
//     fichier) ---
static const float ADC_VREF        = 3.3f;
static const int   ADC_RESOLUTION  = 4095;

// ACS712-20A : 100 mV par ampere (datasheet Allegro), sortie centree sur
// Vcc/2 au repos (0 A). Tolerance fabricant de l'ordre de quelques % - a
// recalibrer canal par canal si besoin de precision metrologique.
static const float ACS712_SENSIBILITE_V_PAR_A = 0.100f;

// ZMPT101B : le module de conditionnement (transformateur + pont diviseur)
// ramene le secteur 220V AC a une plage exploitable par l'ADC (0-3.3V), avec
// un rapport qui depend du montage exact (resistances du pont, cf. schema
// KiCad). FACTEUR_CALIBRATION_ZMPT convertit la tension RMS mesuree a l'ADC
// (apres retrait de l'offset Vcc/2) en tension secteur reelle. Valeur ici =
// PLACEHOLDER, a determiner par mesure comparative avec un multimetre/
// wattmetre sur le circuit reel (cf. GUIDE_ROUTAGE_20A.md, kicad/).
static const float ZMPT_FACTEUR_CALIBRATION = 300.0f; // A CALIBRER SUR LE MATERIEL REEL

// --- Nombre d'echantillons utilises pour l'auto-calibration des offsets DC
// (Vcc/2) au demarrage, cf. calibrerOffsets() dans main.cpp. Effectuee en
// supposant qu'aucun courant ne circule a l'allumage (mise sous tension du
// systeme avant celle des charges, cf. GUIDE_ASSEMBLAGE_ET_FLASH.md). ---
static const int N_ECHANTILLONS_CALIBRATION = 200;

// --- Parametres tarifaires et de credit (identiques a la maquette) ---
static const float TARIF_USD_PAR_KWH   = 0.25f;
static const float CREDIT_INITIAL_USD  = 0.05f;

// --- Periodes des taches (ms) ---
// PERIODE_ACQUISITION_MS n'existe plus ici : l'acquisition tourne en continu,
// canal apres canal (~20 ms/canal mini, cf. TacheAcquisitionCapteurs) plutot
// que par cycles a intervalle fixe comme sur la maquette (potentiometres).
static const uint32_t PERIODE_CREDITS_MS     = 500;
static const uint32_t PERIODE_PERSISTANCE_MS = 5000;
static const uint32_t PERIODE_AFFICHAGE_MS   = 2000;

// --- WiFi point d'acces local ---
static const char *WIFI_SSID     = "TFC-Multicanal-Goma";
static const char *WIFI_PASSWORD = "12345678";
static const char *ADMIN_PASSWORD = "bailleur2026";

// --- Identifiants par canal ---
static const char *CANAL_USER[NUM_CANAUX] = {
    "bailleur", "locataire1", "locataire2", "locataire3",
    "locataire4", "locataire5", "locataire6", "locataire7"
};
static const char *CANAL_PASSWORD[NUM_CANAUX] = {
    ADMIN_PASSWORD, "loc1-2026", "loc2-2026", "loc3-2026",
    "loc4-2026", "loc5-2026", "loc6-2026", "loc7-2026"
};

static const char *ELECTRICIEN_USER     = "electricien";
static const char *ELECTRICIEN_PASSWORD = "elec-2026";

static const size_t MAX_EVENEMENTS_EN_ATTENTE = 64;
