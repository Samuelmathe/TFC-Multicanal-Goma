# Guide — Souder la maquette et fabriquer le boîtier bois

Objectif : passer de la breadboard à une maquette soudée, propre, dans un
boîtier en bois — plus solide et plus impressionnant pour la soutenance.

## 1. Support de soudure : plaque à trous (perfboard), pas un vrai PCB

Pas besoin du PCB final KiCad ici — c'est un circuit simple (ESP32 + 5
potentiomètres + 5 LED), une plaque à trous standard (perfboard/veroboard,
~7x9cm suffit largement) fait très bien l'affaire.

**Astuce importante** : ne soude pas l'ESP32 directement sur la plaque.
Soude plutôt deux **rangées de barrettes de connecteurs femelles** (les
mêmes que sur une breadboard) à l'emplacement de l'ESP32, puis enfiche
l'ESP32 dedans. Comme ça, s'il grille ou si tu dois le reprogrammer en le
sortant, tu ne dessoudes rien.

## 2. Plan de câblage (reprend `config.h`)

| Canal | Potentiomètre → broche | LED → broche |
|---|---|---|
| 0 (bailleur) | GPIO36 | GPIO4 |
| 1 (locataire 1) | GPIO39 | GPIO5 |
| 2 (locataire 2) | GPIO34 | GPIO13 |
| 3 (locataire 3) | GPIO35 | GPIO14 |
| 4 (locataire 4) | GPIO32 | GPIO16 |
| Tension secteur (commun, 1 seul potentiomètre) | **GPIO33** | — |

**Important** : le potentiomètre de tension doit être sur GPIO33 (ADC1), pas
GPIO25 comme dans une version antérieure de ce guide — GPIO25 est sur l'ADC2,
qui devient inutilisable en continu dès que le point d'accès WiFi de la
maquette est actif, ce qui bloquait la lecture de tension (et donc puissance/
énergie/crédit, qui en dépendent).

- Potentiomètre : pattes extérieures sur 3.3V / GND, curseur (broche du
  milieu) sur la broche GPIO indiquée
- LED : anode (patte longue) vers la broche GPIO **à travers une
  résistance ~220-330Ω**, cathode (patte courte, méplat sur le boîtier)
  vers GND

## 3. Organisation du perfboard

Pense la disposition **avant** de souder, pas après :

```
 [ESP32 sur barrettes femelles]     [zone résistances LED]
 [bornes à vis ou fils vers panneau avant : 5 pots + 5 LED]
```

Utilise des petites **bornes à vis** (2 ou 3 broches, les mêmes que sur
ton PCB principal) ou simplement des fils soudés directement, pour relier
le perfboard aux potentiomètres et LED qui seront montés sur le panneau
avant du boîtier — plus pratique que de tout souder en dur d'un bloc.

## 4. Le boîtier en bois

**Dimensions** : prévois large — le principal contrainte est la hauteur
de l'ESP32 monté sur ses barrettes (~2,5cm) et l'accès USB. Une boîte
15x10x5cm est confortable pour ce montage.

**Panneau avant** (celui que le jury regarde) :
- 5 trous pour les axes de potentiomètre (Ø ~7mm selon le modèle)
- 5 trous pour les LED (Ø ~5mm, ou 3mm selon la taille de tes LED)
- **Étiquette au-dessus de chaque paire** : "Bailleur", "Locataire 1",
  "Locataire 2", "Locataire 3", "Locataire 4" — ça se fait très bien au
  feutre fin, à la brûlure (pyrogravure) si tu as l'outil, ou avec une
  étiquette imprimée collée

**Panneau arrière ou latéral** :
- Une découpe pour le port USB de l'ESP32 (accès direct au câble sans
  ouvrir la boîte — pratique pour reprogrammer ou simplement alimenter
  pendant la démo)

**Fixation interne** :
- Le perfboard peut être fixé avec de petites vis à bois + entretoises,
  ou plus simplement avec des points de colle chaude aux 4 coins (assez
  solide pour une maquette, facile à décoller si besoin de réparer)
- Ne colle/visse les potentiomètres et LED sur le panneau qu'**après**
  avoir vérifié que tout fonctionne sur la breadboard — inutile de tout
  refaire si un composant est défectueux

## 5. Ordre de travail recommandé

1. Teste tout sur la breadboard d'abord (déjà fait normalement)
2. Prépare le perfboard : barrettes ESP32, résistances, bornes/fils
3. Perce le panneau avant du boîtier (mesure deux fois, perce une fois)
4. Monte les potentiomètres et LED sur le panneau, relie-les au perfboard
   avec des fils assez longs pour pouvoir sortir le panneau si besoin
5. Reteste tout **avant** de refermer définitivement la boîte
6. Ajoute les étiquettes
7. Referme, fais un dernier test complet (flash + Wi-Fi + appli) une fois
   la boîte assemblée, pour être sûr qu'aucun fil ne s'est débranché en
   manipulant

---

Si tu bloques sur une étape (positionnement des trous, dimensions,
choix des résistances LED) demande-moi avant de percer — plus facile de
corriger un plan qu'un trou déjà fait dans le bois.
