# Guide KiCad — Schéma du système multicanal (8 canaux)

Objectif : redessiner le schéma décrit au chapitre 2.5 de ton mémoire, à la
main, dans le vrai KiCad — l'ancien fichier `energie_locatif.kicad_sch`
(archivé dans `ancien-fichier-casse/` à côté de ce guide, pour référence
uniquement) est cassé et ne s'ouvre pas, mais sa liste de composants
ci-dessous est fiable, reprends-la telle quelle.

Tu peux commencer **avant** d'avoir l'ESP32 physique — rien ici ne demande
le matériel en main.

**État au 17 juillet** : d'après ton fichier `multical.kicad_sch`, il te
manque un deuxième `ULN2003A` (tu n'en as qu'un, avec 7 sorties pour 8
relais — voir étape 3 ci-dessous) et le câblage n'est pas encore fait —
voir la correction du Tableau 2.2 à l'étape 5 avant de commencer à câbler.

## 0. Lancer KiCad

Deux installations existent sur cette machine : une snap (KiCad 9.0.7,
périmée) et une flatpak (KiCad 10.0.4, la version stable actuelle,
vérifiée en juillet 2026). Utilise la flatpak :

```bash
flatpak run org.kicad.KiCad
```
(ou depuis le menu applications — si deux icônes "KiCad" apparaissent,
vérifie dans Aide → À propos que tu ouvres bien la 10.0.4)

## 1. Créer le projet

1. **Fichier → Nouveau projet**
2. Nomme-le `multicanal_goma` (évite les espaces/accents dans le nom de
   fichier — KiCad n'aime pas toujours ça)
3. Sauvegarde-le directement dans ce dossier :
   `~/Documents/TFC-Multicanal-Goma/kicad/` (là où se trouve déjà ce guide
   et le symbole `zmpt101b.kicad_sym`, à côté du firmware et de l'appli)
4. Double-clique sur l'icône **Schematic Editor** (feuille bleue) dans la
   fenêtre du projet

## 2. Format de feuille

**Fichier → Propriétés de la feuille** → choisis **A3** (le schéma a
beaucoup de composants, A4 sera trop serré). Remplis le cartouche (titre,
date, ton nom, "Encadreur: Patrick Nzanzu Vingi" — déjà retrouvé dans
l'ancien fichier).

## 3. Placer les composants

Touche **A** (ou icône "Placer un symbole") ouvre le sélecteur. Tape le nom
exact à droite ci-dessous dans la barre de recherche.

**Important** : la liste de composants trouvée dans l'ancien fichier cassé
contenait plusieurs noms qui n'existent pas réellement dans les
bibliothèques KiCad de ta machine (c'est probablement ce qui l'a cassé).
J'ai vérifié un par un le nom exact et la bibliothèque réelle de chaque
composant — utilise ce tableau-ci, pas celui du message précédent.

| Cherche exactement | Bibliothèque réelle | Combien | Où le placer |
|---|---|---|---|
| `ESP32-WROOM-32` | **RF_Module** (pas MCU_Espressif) | 1 | Centre |
| `ACS712xLCTR-20A` | **Sensor_Current** (pas Sensor) | 8 | Colonne de gauche, zone BT |
| `ULN2003A` | **Transistor_Array** (pas Driver) | 2 | Entre ESP32 et relais (chaque ULN2003A pilote jusqu'à 7 sorties, 2 suffisent pour 8 relais) |
| `Relay_SPDT` | Relay | 8 | Colonne de droite, zone HT — voir note ZMPT101B/relais ci-dessous |
| `HLK-PM01` | Converter_ACDC | 1 | Zone HT → alimentation |
| `AMS1117-3.3` | Regulator_Linear | 1 | Zone BT, juste après le HLK-PM01 |
| `D` (diode générique) | Device | 8 | Une en parallèle de chaque relais (roue libre) |
| `R` | Device | 5 | Pull-up strapping pins + limitation courant |
| `C` | Device | 5 | Découplage (près des VCC ACS712 et ESP32) |
| `Conn_01x02_Pin` | Connector | 9 | Un par canal + alimentation secteur |

### ZMPT101B — pas dans les bibliothèques standard

Ce capteur n'existe dans aucune bibliothèque KiCad officielle (normal,
c'est un module très "communauté Arduino", pas un composant industriel
référencé). Bonne nouvelle : tu as déjà un symbole personnalisé tout fait
et valide dans `~/Documents/TFC-Multicanal-Goma/kicad/zmpt101b.kicad_sym` (6 broches : L, N, GND,
GND, VCC, OUT — correspond bien au vrai module). Pour l'utiliser :

1. Dans l'éditeur de schéma : **Préférences → Gestionnaire de bibliothèques
   de symboles**
2. Onglet **Bibliothèque de projet**, clique **+**, choisis
   `~/Documents/TFC-Multicanal-Goma/kicad/zmpt101b.kicad_sym`
3. Il apparaîtra ensuite dans le sélecteur (touche A) sous le nom
   `zmpt101b`

### Relais SLA-05VDC-SL-A — pas de symbole exact non plus

Le nom précis "SLA-05VDC-SL-A" (celui des modules relais tout faits pour
Arduino) n'a pas de symbole officiel KiCad. Utilise le symbole générique
`Relay_SPDT` (fonctionnellement identique — bobine 5V + contact
inverseur) : place-le, puis dans ses propriétés change le champ **Valeur**
de "Relay_SPDT" à "SLA-05VDC-SL-A" pour que ta nomenclature (BOM) reste
correcte, même si le dessin du symbole est générique.

Astuce générale : place d'abord UN exemplaire de chaque, câble-le, puis
sélectionne-le et fais **Ctrl+C / Ctrl+V** pour dupliquer les 7 autres
canaux — beaucoup plus rapide que de rechercher 8 fois le même composant.

## 4. Séparer les zones HT et BT (§2.5.1 de ton mémoire)

C'est le point que ton mémoire promet déjà — respecte-le visuellement dans
le schéma, pas juste dans le texte :

- **Zone haute tension (220V)**, à droite ou en haut de la feuille : arrivée
  secteur (Conn_01x02_Pin), les 8 relais SLA-05VDC-SL-A, le HLK-PM01.
- **Zone basse tension (3.3V/5V)**, à gauche ou en bas : ESP32, les 8
  ACS712, l'AMS1117, les ULN2003A.
- Le ZMPT101B et les ACS712 sont la frontière (isolation galvanique,
  cf. §1.3.4) — dessine une ligne ou une boîte en pointillés entre les deux
  zones sur la feuille, avec une annotation "ISOLATION GALVANIQUE" comme
  rappel visuel pour le jury.

## 5. Câblage — reprends le Tableau 2.2 (corrigé) de ton mémoire

**Correction importante** : contrairement à ce que je t'avais dit au départ,
le symbole `ESP32-WROOM-32` que tu utilises (vérifié directement dans la
bibliothèque KiCad, pas juste supposé) **n'a pas non plus** les broches
GPIO37/GPIO38 — elles n'existent pas sur ce module, DevKitC ou pas. Il n'y a
donc que 6 broches ADC1 réellement utilisables (36, 39, 32, 33, 34, 35) pour
8 canaux. Les canaux 2 et 3 sont déplacés sur ADC2 (GPIO26, GPIO27), sur le
même principe déjà utilisé pour le ZMPT101B (lecture pendant les fenêtres
où le Wi-Fi est inactif, cf. §1.4.3 du mémoire — désormais 3 signaux à
gérer ainsi au lieu d'1, mais aucun composant supplémentaire nécessaire) :

| Canal | ACS712 → ESP32 | ADC | Relais → ESP32 (via ULN2003A) |
|---|---|---|---|
| 1 (bailleur) | GPIO36 | ADC1 | GPIO4 |
| 2 | GPIO26 | ADC2 | GPIO5 |
| 3 | GPIO27 | ADC2 | GPIO13 |
| 4 | GPIO39 | ADC1 | GPIO14 |
| 5 | GPIO32 | ADC1 | GPIO16 |
| 6 | GPIO33 | ADC1 | GPIO17 |
| 7 | GPIO34 | ADC1 | GPIO18 |
| 8 | GPIO35 | ADC1 | GPIO19 |

ZMPT101B → GPIO25 (ADC2).

**Évite ces broches pour toute nouvelle affectation** (strapping pins,
déjà notées dans ton mémoire §2.5.2) : GPIO0, GPIO2, GPIO12, GPIO15.

Pour tracer un fil : touche **W** (wire), clique départ, clique arrivée.
Pour nommer un fil (utile pour les signaux qui se répètent, ex.
`CANAL1_ACS`) : sélectionne-le puis touche **L** (label).

## 6. Vérifier avant de continuer

**Inspecter → Vérification des règles électriques (ERC)** — lance-le, corrige les erreurs
(broches non connectées, conflits de type de pin). Ne passe au routage du
circuit imprimé (PCB, §2.5.3 de ton mémoire) qu'une fois l'ERC propre — ce
sera la prochaine étape, une fois le schéma solide.

## 7. Sauvegarder correctement

**Ctrl+S** régulièrement. KiCad enregistre automatiquement les définitions
complètes des symboles utilisés dans le fichier — contrairement à l'ancien
fichier cassé, tant que tu passes par le vrai logiciel (et pas un script),
ce problème ne peut pas se reproduire.

---

Reviens vers moi avec une capture d'écran ou une description de ce que tu
as si tu bloques sur un placement ou un câblage précis — je peux lire un
export PDF du schéma directement si tu me donnes le chemin du fichier.
