# TFC Multicanal Goma

Système embarqué IoT de sous-comptage électrique multicanal (ESP32),
développé dans le cadre d'un Travail de Fin de Cycle (ULPGL) : un boîtier
mesure et facture séparément la consommation électrique de plusieurs
locataires branchés sur une même installation, avec coupure automatique par
crédit prépayé et consultation via une application mobile Flutter.

## État du projet

- **Maquette physique** : construite, soudée sur carte perforée et
  **validée sur matériel réel** (4 canaux : 1 bailleur + 3 locataires,
  capteurs simulés par des potentiomètres). C'est cette maquette qui a servi
  à la validation présentée dans le mémoire.
- **Application mobile Flutter** : développée et testée en conditions
  réelles (connexion Wi-Fi à l'ESP32 depuis un téléphone Android).
- **PCB (circuit imprimé, 8 canaux, capteurs ACS712/ZMPT101B réels)** :
  conçu et **routé** sous KiCad (dossier `kicad/`). Carte **compactée le
  19/11/2026 : 138 x 349,5 mm** au lieu de 260 x 440 mm (−58 % de surface),
  re-routée avec Freerouting (scripts `kicad/tools/compact_pcb.py`,
  `route_pcb.py`, `finish_acs712.py`, `cleanup_after_route.py`). Les 17
  borniers restent sur le bord droit ; le HLK-PM01 et le ZMPT101B sont
  regroupés près de l'entrée secteur J10.
  Dernier DRC (KiCad 10.0.8, 19/11/2026) : **0 élément non connecté**, 11
  violations, dont 4 à traiter avant toute fabrication (distances
  phase/neutre/GND sur le connecteur du ZMPT101B, U12, trop faibles pour du
  230 V) ; les 7 autres sont cosmétiques (empreintes modifiées localement).
  Les liaisons très proches sur les broches du ACS712 sont couvertes par
  `multical.kicad_dru` (les deux côtés du shunt sont au même potentiel).
  **Non fabriqué ni assemblé** : les Gerbers de `kicad/multical/fabrication/`
  ont été régénérés pour la carte compacte. Le firmware cible
  (`firmware_pcb_capteurs_reels/`) est écrit et compile, mais n'a pas pu
  être testé sur matériel réel.
- **Boîtier 3D** (`boitier/multicanal_boitier.scad`, OpenSCAD) : boîtier
  paramétrique pour le PCB, avec rampe inclinée sur les borniers et
  étiquettes gravées (BAI, LOC1 à LOC7, NEUTRE). Cotes mises à jour pour la
  carte compacte.

## Structure du dépôt

```
firmware/                      -> firmware de la maquette physique (4 canaux,
                                   potentiometres) - construit et valide
firmware_pcb_capteurs_reels/    -> firmware cible pour le PCB (8 canaux,
                                    ACS712 + ZMPT101B) - PCB pas encore
                                    fabrique, code non teste sur materiel reel
application/                     -> application mobile Flutter (Android/iOS)
kicad/                            -> conception du circuit imprime (PCB, 8 canaux)
boitier/                          -> boitier 3D du PCB (OpenSCAD)
rapport/                           -> memoire de TFC
presentation/                       -> support de soutenance
```

Chaque dossier de firmware a son propre `README.md` avec le détail de ce qui
a été testé ou non.

## Démarrer

- Firmware maquette : `cd firmware && pio run --target upload` (ESP32 branché
  en USB) — voir `GUIDE_ASSEMBLAGE_ET_FLASH.md` et `GUIDE_MAQUETTE_BOITIER.md`
  à la racine pour le montage physique.
- Application mobile : `cd application && flutter run` (ou `build_apk.sh`
  pour générer un APK).
