# Guide — De la réception des composants au premier flashage de l'ESP32

Ce guide couvre trois étapes : vérifier les composants à leur arrivée, les
souder correctement, puis téléverser le firmware sur l'ESP32 et vérifier
que tout fonctionne. À suivre dans cet ordre.

## 1. À la réception des composants

- Coche chaque référence contre la nomenclature (Tableau 2.3 du mémoire,
  ou `kicad/multical/bom.csv` si tu veux la liste brute).
- Vérifie visuellement : rien de plié, de cassé, ou qui a l'air corrodé.
- Vérifie les valeurs marquées sur les composants (résistances 10kΩ,
  condensateurs 0,1µF pour C1-C9, 10-22µF pour C10/C11) — une erreur de
  valeur à cette étape est bien plus facile à corriger qu'une fois soudée.
- Range les composants par canal (ACS712 + condensateur + diode + relais
  + bornier) si tu assembles à la main, ça évite les erreurs de câblage.

## 2. Assemblage (soudure)

**Ordre recommandé** (du plus plat au plus haut, pour pouvoir poser la
carte à plat sur la table à chaque étape) :

1. Résistances (R1-R5), diodes (D1-D8) — attention au sens des diodes
   (bande = cathode, cf. discussion sur le montage roue libre)
2. Circuits intégrés : ULN2003A (U13, U14), régulateur AMS1117 (U11)
3. Capteurs ACS712 (U2-U9) — CMS, soudure plus délicate, prends ton temps
4. Condensateurs — attention à la polarité des C10/C11 (électrolytiques,
   patte longue = +)
5. ESP32 (U1), HLK-PM01 (U10)
6. En dernier : relais (K1-K8), borniers à vis (J10-J18) — ce sont les
   plus hauts/gros, plus faciles à souder sans gêner l'accès aux autres

**Précautions** :

- Fer à souder autour de 350°C, pas plus — les CMS (ACS712) chauffent vite.
- Ne reste pas plus de 2-3 secondes sur une même pastille.
- Après chaque composant : inspecte à l'œil (ou à la loupe) qu'il n'y a
  pas de pont de soudure entre deux pastilles voisines, surtout sur les
  ACS712 (pastilles à 1,27mm d'écart, très serrées).

## 3. Vérifications AVANT toute mise sous tension

Avec un multimètre en mode continuité (bip sonore), **avant de brancher
quoi que ce soit** :

- Teste entre `P5V` et `GND` → ne doit **pas** biper (sinon court-circuit
  quelque part, à chercher avant d'aller plus loin)
- Teste entre `PHASE_BUS` et `NEUTRE_BUS` → ne doit pas biper non plus
- Revérifie une dernière fois le sens des composants polarisés (diodes,
  condensateurs électrolytiques, relais)

## 4. Première mise sous tension — SANS le secteur

Ne branche **pas** le 220V à cette étape.

1. Alimente la carte en 5V uniquement (via le port USB de l'ESP32, ou une
   alimentation externe basse tension raccordée après le HLK-PM01)
2. Mesure la sortie de l'AMS1117 (broche VO, U11) → doit indiquer ~3,3V
3. Vérifie que l'ESP32 démarre normalement (pas de redémarrage en boucle)

Si tout est correct, tu peux passer au flashage. Sinon, coupe
l'alimentation et cherche l'erreur avant de continuer.

## 5. Téléverser le firmware sur l'ESP32

PlatformIO est déjà installé sur cette machine. Deux choses à envoyer sur
l'ESP32, dans cet ordre : **le firmware** (le code) et **le système de
fichiers LittleFS** (les pages web `admin.html`, `locataire.html`, etc.
utilisées par l'interface embarquée §2.10 du mémoire) — ce sont deux
étapes séparées, il ne faut pas oublier la seconde.

```bash
cd ~/Documents/TFC-Multicanal-Goma/firmware

# 1) Branche l'ESP32 en USB, puis vérifie qu'il est détecté :
ls /dev/ttyUSB* /dev/ttyACM* 2>/dev/null

# 2) Téléverse le firmware (le code C++) :
pio run --target upload

# 3) Téléverse le système de fichiers (les pages web) :
pio run --target uploadfs

# 4) Ouvre le moniteur série pour voir ce que fait l'ESP32 :
pio device monitor
```

**Si l'upload échoue** (erreur de type "Failed to connect") : certains
modules ESP32 nus (pas les cartes DevKit) n'ont pas l'auto-reset —
maintiens le bouton **BOOT** appuyé pendant les 2-3 premières secondes de
l'upload, relâche quand ça commence à écrire ("Writing at...").

**Pour quitter le moniteur série** : `Ctrl+C`.

## 6. Après le premier flash — vérifications

Dans les logs du moniteur série, tu dois voir apparaître (dans cet
ordre à peu près) :
- Le montage du système de fichiers LittleFS (sans erreur)
- Le démarrage des 5 tâches FreeRTOS (Acquisition, Calcul, Crédits,
  Persistance, ServeurAPI)
- Le point d'accès Wi-Fi qui s'active, avec son nom (SSID) affiché

Ensuite :
1. Depuis ton téléphone/PC, connecte-toi au Wi-Fi diffusé par l'ESP32
2. Ouvre un navigateur, va sur `http://192.168.4.1` (adresse par défaut
   d'un point d'accès ESP32) → tu dois voir la page d'accueil
3. Teste `/admin` (mot de passe défini dans `config.h`) et l'espace
   locataire
4. Installe l'APK Flutter déjà compilé sur ton téléphone, connecte-le au
   même Wi-Fi, vérifie qu'il affiche bien les données

## 7. Seulement après tout ça : test avec le secteur 220V

- **Coupe toujours le disjoncteur** avant de toucher au câblage secteur
- Ne touche jamais les borniers phase/neutre sous tension
- Teste **un seul canal à la fois** la première fois, avec une charge
  simple (une lampe) avant de brancher un vrai sous-compteur
- Vérifie la coupure automatique et le rétablissement après recharge
  (même protocole que le Tableau 3.6 du mémoire, mais en conditions
  réelles cette fois)

---

Si un problème survient à une étape, arrête-toi et redemande-moi avant de
continuer — plus facile de corriger avant l'étape suivante qu'après.
