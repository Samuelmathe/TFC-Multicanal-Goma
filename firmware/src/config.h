#pragma once

// NUM_CANAUX est un parametre, pas une valeur cablee en dur (cf. TFC S3.6.1).
// Maquette perfboard reelle : 4 canaux (1 bailleur + 3 locataires) - la carte
// soudee n'avait pas la place pour un 5e potentiometre/LED (locataire 4), qui
// a ete retire de la config (cf. GUIDE_MAQUETTE_BOITIER.md). La simulation
// Wokwi/breadboard visait 5 canaux ; la carte finale (PCB, chapitre 2) vise 8.
#define NUM_CANAUX 4

// --- Broches ADC1 des capteurs de courant (potentiometres simulant les ACS712) ---
// IMPORTANT : GPIO37 et GPIO38 (utilises dans le Tableau 2.2 du memoire) ne sont
// PAS sortis sur un ESP32 DevKitC standard (ni dans Wokwi) : ils existent sur la
// puce mais pas sur le connecteur du DevKitC. Ce mapping les evite. Le PCB final
// (module WROOM-32 nu, chapitre 2.5) peut conserver GPIO37/38 s'il les route
// explicitement sur son propre circuit imprime.
//
// Canaux 2 et 3 (locataire2/locataire3) : les potentiometres ont ete soudes
// inverses sur la carte perforee reelle (celui pose en position "locataire 2"
// est en fait cable sur la broche prevue pour "locataire 3", et vice versa).
// Plutot que de dessouder, on compense ici en inversant les deux broches -
// canal 2 lit la broche 35, canal 3 lit la broche 34.
static const int PIN_COURANT[NUM_CANAUX] = {
    36, // VP  - canal 0 : bailleur
    39, // VN  - canal 1 : locataire 1
    35, //     - canal 2 : locataire 2 (potentiometre soude a la place de loc.3)
    34  //     - canal 3 : locataire 3 (potentiometre soude a la place de loc.2)
};

// --- Broche ADC1 du capteur de tension (potentiometre simulant le ZMPT101B) ---
// Un seul capteur, commun a tous les canaux (cf. S1.3.2). Placee sur l'ADC1 (et
// non l'ADC2 comme dans le Tableau 2.2 du PCB final) car le point d'acces WiFi
// de la maquette est actif en permanence : l'ADC2 est alors inutilisable en
// continu (contrairement au PCB final ou seules de courtes fenetres ponctuelles
// sont concernees, cf. S1.4.3). GPIO33 est libre sur le DevKitC (ADC1_CH5).
static const int PIN_TENSION = 33;

// --- Broches de commande des relais (simulees par des LED) ---
// Canaux 0/1 (bailleur/locataire1) et 2/3 (locataire2/locataire3) : les LED
// ont ete soudees inversees deux a deux sur la carte perforee reelle. Compense
// ici plutot que de dessouder (meme logique que PIN_COURANT ci-dessus).
static const int PIN_RELAIS[NUM_CANAUX] = {5, 4, 14, 13};

// --- Constantes de conversion pour la simulation (a ajuster / etalonner sur le
//     vrai capteur ACS712 20A + diviseur 5V->3.3V lors du prototype physique) ---
static const float ADC_VREF = 3.3f;
static const int   ADC_RESOLUTION = 4095;
static const float COURANT_MAX_A = 20.0f;     // pleine echelle simulee (ACS712 20A)
static const float TENSION_MAX_V = 250.0f;    // pleine echelle simulee du secteur

// --- Lissage des lectures ADC : moyenne de N echantillons consecutifs au
// lieu d'une seule lecture, pour attenuer le bruit propre a l'ADC de l'ESP32
// (cf. TacheAcquisitionCapteurs). N=64 : au-dela du simple lissage, cet
// oversampling combine a une moyenne gardee en virgule flottante (et non
// tronquee a l'entier) gagne en resolution sous le pas natif de l'ADC 12 bits
// - necessaire pour tenir la tolerance de +/-0.01 (A ou V) demandee quand le
// potentiometre est immobile. 64 lectures ADC prennent encore largement moins
// de 10 ms au total, negligeable devant PERIODE_ACQUISITION_MS.
static const int N_ECHANTILLONS_LISSAGE = 64;

// --- Lissage supplementaire entre cycles (moyenne glissante exponentielle) ---
// Teste sur la maquette reelle : le bruit residuel sur les lectures ADC1
// n'est pas purement aleatoire d'un echantillon a l'autre (auquel cas
// N_ECHANTILLONS_LISSAGE suffirait) - il varie plus lentement, probablement
// couple aux emissions Wi-Fi periodiques du point d'acces de la maquette.
// Un simple sur-echantillonnage rapide (64, 128 lectures en rafale sur <10ms)
// ne moyenne pas ce bruit-la. ALPHA_LISSAGE_EMA fait fondre chaque nouvelle
// mesure avec l'historique sur plusieurs cycles (~500ms chacun) : plus alpha
// est petit, plus le filtrage est fort mais plus la reponse a un vrai
// mouvement du potentiometre est lente a se stabiliser.
static const float ALPHA_LISSAGE_EMA = 0.35f;

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
    "bailleur", "locataire1", "locataire2", "locataire3"
};
static const char *CANAL_PASSWORD[NUM_CANAUX] = {
    ADMIN_PASSWORD, "loc1-2026", "loc2-2026", "loc3-2026"
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
