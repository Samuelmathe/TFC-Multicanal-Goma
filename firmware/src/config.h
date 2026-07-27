#pragma once

// NUM_CANAUX est un parametre, pas une valeur cablee en dur (cf. TFC S3.6.1).
// Maquette Wokwi/breadboard : 5 canaux (1 bailleur + 4 locataires).
// La carte finale (PCB, chapitre 2) vise 8 canaux.
#define NUM_CANAUX 5

// --- Broches ADC1 des capteurs de courant (potentiometres simulant les ACS712) ---
// IMPORTANT : GPIO37 et GPIO38 (utilises dans le Tableau 2.2 du memoire) ne sont
// PAS sortis sur un ESP32 DevKitC standard (ni dans Wokwi) : ils existent sur la
// puce mais pas sur le connecteur du DevKitC. Ce mapping les evite. Le PCB final
// (module WROOM-32 nu, chapitre 2.5) peut conserver GPIO37/38 s'il les route
// explicitement sur son propre circuit imprime.
static const int PIN_COURANT[NUM_CANAUX] = {
    36, // VP  - canal 0 : bailleur
    39, // VN  - canal 1 : locataire 1
    34, //     - canal 2 : locataire 2
    35, //     - canal 3 : locataire 3
    32  //     - canal 4 : locataire 4
};

// --- Broche ADC1 du capteur de tension (potentiometre simulant le ZMPT101B) ---
// Un seul capteur, commun a tous les canaux (cf. S1.3.2). Placee sur l'ADC1 (et
// non l'ADC2 comme dans le Tableau 2.2 du PCB final) car le point d'acces WiFi
// de la maquette est actif en permanence : l'ADC2 est alors inutilisable en
// continu (contrairement au PCB final ou seules de courtes fenetres ponctuelles
// sont concernees, cf. S1.4.3). GPIO33 est libre sur le DevKitC (ADC1_CH5).
static const int PIN_TENSION = 33;

// --- Broches de commande des relais (simulees par des LED) ---
static const int PIN_RELAIS[NUM_CANAUX] = {4, 5, 13, 14, 16};

// --- Constantes de conversion pour la simulation (a ajuster / etalonner sur le
//     vrai capteur ACS712 20A + diviseur 5V->3.3V lors du prototype physique) ---
static const float ADC_VREF = 3.3f;
static const int   ADC_RESOLUTION = 4095;
static const float COURANT_MAX_A = 20.0f;     // pleine echelle simulee (ACS712 20A)
static const float TENSION_MAX_V = 250.0f;    // pleine echelle simulee du secteur

// --- Lissage des lectures ADC : moyenne de N echantillons consecutifs au
// lieu d'une seule lecture, pour attenuer le bruit propre a l'ADC de l'ESP32
// (cf. TacheAcquisitionCapteurs). N=8 est un bon compromis : reduction nette
// du bruit sans ralentir sensiblement l'acquisition (8 lectures ADC prennent
// largement moins d'1 ms au total).
static const int N_ECHANTILLONS_LISSAGE = 8;

// --- Parametres tarifaires et de credit (demo) ---
// Valeur par defaut au tout premier demarrage (1 USD = 4 kWh) ; modifiable
// ensuite par le bailleur depuis l'application (/api/tarif), et persistee en
// NVS (cf. chargerEtatDepuisNVS/TacheGestionCredits dans main.cpp).
static const float TARIF_USD_PAR_KWH = 0.25f;
static const float CREDIT_INITIAL_USD = 0.05f; // volontairement faible pour observer
                                                 // la coupure automatique rapidement
                                                 // (cf. Tableau 3.2)

// --- Periodes des taches (ms) ---
static const uint32_t PERIODE_ACQUISITION_MS = 500;
static const uint32_t PERIODE_CALCUL_MS      = 500;
static const uint32_t PERIODE_CREDITS_MS     = 500;
static const uint32_t PERIODE_PERSISTANCE_MS = 5000;
static const uint32_t PERIODE_AFFICHAGE_MS   = 2000;

// --- WiFi point d'acces local ---
static const char *WIFI_SSID = "TFC-Multicanal-Goma";
static const char *WIFI_PASSWORD = "12345678";
static const char *ADMIN_PASSWORD = "bailleur2026";

// --- Identifiants par canal (page d'authentification de l'application) ---
// Le canal 0 (bailleur) reutilise ADMIN_PASSWORD pour rester compatible avec
// les routes /admin et /api/recharge deja protegees par ce mot de passe.
// A CHANGER avant tout deploiement reel (cf. rapport S2.9/S2.10) : ce sont des
// mots de passe de demonstration pour la maquette.
static const char *CANAL_USER[NUM_CANAUX] = {
    "bailleur", "locataire1", "locataire2", "locataire3", "locataire4"
};
static const char *CANAL_PASSWORD[NUM_CANAUX] = {
    ADMIN_PASSWORD, "loc1-2026", "loc2-2026", "loc3-2026", "loc4-2026"
};

// --- Compte technicien (electricien) : acces en lecture seule aux grandeurs
// electriques brutes de tous les canaux (courant, tension, puissance, cos phi)
// - pas de gestion de credit ni de coupure, profil different du bailleur.
static const char *ELECTRICIEN_USER = "electricien";
static const char *ELECTRICIEN_PASSWORD = "elec-2026";

// --- Taille de la file d'evenements en attente (cf. mettreEnAttente dans
// main.cpp) : evenements pas encore recuperes par l'application, purges au
// fur et a mesure de leur recuperation. Bornee pour eviter une croissance
// illimitee en RAM si aucune application ne se connecte pendant longtemps.
static const size_t MAX_EVENEMENTS_EN_ATTENTE = 64;
