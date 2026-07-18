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

// --- Broche ADC2 du capteur de tension (potentiometre simulant le ZMPT101B) ---
// Un seul capteur, commun a tous les canaux (cf. S1.3.2). Lu pendant les fenetres
// ou le WiFi est inactif (cf. S1.4.3) : ici, simplement entre deux envois radio.
static const int PIN_TENSION = 25;

// --- Broches de commande des relais (simulees par des LED) ---
static const int PIN_RELAIS[NUM_CANAUX] = {4, 5, 13, 14, 16};

// --- Constantes de conversion pour la simulation (a ajuster / etalonner sur le
//     vrai capteur ACS712 20A + diviseur 5V->3.3V lors du prototype physique) ---
static const float ADC_VREF = 3.3f;
static const int   ADC_RESOLUTION = 4095;
static const float COURANT_MAX_A = 20.0f;     // pleine echelle simulee (ACS712 20A)
static const float TENSION_MAX_V = 250.0f;    // pleine echelle simulee du secteur

// --- Parametres tarifaires et de credit (demo) ---
static const float TARIF_USD_PAR_KWH = 0.20f;
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
