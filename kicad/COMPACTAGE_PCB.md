# Compactage du PCB (19/11/2026)

La carte `multical/multical.kicad_pcb` est passée de **260 x 440 mm** à
**138 x 349,5 mm** (−58 % de surface), sans changer le schéma, les
empreintes ni les règles de conception.

## Ce qui a changé

| Zone | Avant | Après |
|------|-------|-------|
| Basse tension (ESP32, AMS1117, R, C) | haut gauche | inchangée |
| HLK-PM01 (U10) | x = 165 mm | haut, à gauche de la rampe du boîtier |
| ZMPT101B (U12) | à gauche, loin de J10 (230 V traversant la zone BT) | à côté du HLK et de J10 |
| ULN2003 (U13, U14) | à côté de l'ESP32 | sous le HLK |
| 8 canaux (C, ACS712, diode, relais) | lignes au pas de 40-45 mm, grande zone vide à gauche | lignes au pas de 30 mm, relais tournés de 90° |
| 17 borniers | bord droit | bord droit (compatible avec le boîtier) |
| Trous de fixation M3 | 4 | 4 (aux nouveaux coins) |

Vérifications faites avec KiCad 10.0.8 :

- DRC : **0 élément non connecté**, 11 violations, les mêmes qu'avant le
  compactage (les 4 du connecteur U12, voir ci-dessous, et 7 avertissements
  « empreinte modifiée localement ») ;
- parité schéma/PCB : identique à avant (99 écarts qui existaient déjà :
  le PCB n'a pas été mis à jour depuis le schéma, à faire dans KiCad avec
  **Outils → Mettre à jour le PCB depuis le schéma** si besoin) ;
- boîtier OpenSCAD : se compile, cotes et positions des borniers mises à
  jour.

## Ajouts du 19/11/2026 (après compactage)

- **Ponts diviseurs 10 kΩ / 12 kΩ** (R6-R23, CMS 0805) entre chaque capteur et
  son entrée ADC : les capteurs sont alimentés en 5 V (sortie 0,5-4,5 V), ce qui
  dépassait les 3,6 V admissibles par l'ESP32. Ajoutés au schéma
  (`tools/add_dividers_sch.py`, étiquettes `ACSn_VOUT` / `ZMPT_VOUT`) et au PCB.
  Le firmware `firmware_pcb_capteurs_reels` divise la mesure par 12/22
  (`RAPPORT_PONT_DIVISEUR` dans `config.h`). Voir `simulation/acquisition_ac.cir`.
- **32 points d'accueil pour les barres de cuivre** (`BAR1`-`BAR32`, empreinte
  `multical_local:Point_barre_cuivre`, pastille 4 mm percée 2,5 mm, « carte
  seule ») : à côté de la broche 1 de chaque bornier IN/OUT et des broches IP+ /
  IP− de chaque ACS712, reliés par une piste verrouillée de 1,8 mm. Les broches
  COM/NO des relais (perçage 2,5 mm) servent directement. Dessin de principe :
  `simulation/figures/fig_barres_cuivre.png`.
- **Entrée secteur du ZMPT101B déportée** : le connecteur U12 (empreinte
  `multical_local:ZMPT101B_Header_1x04`) ne porte plus que GND / GND / VCC /
  OUT ; la phase et le neutre arrivent sur un nouveau bornier **J27** au pas de
  5 mm, à câbler vers le bornier à vis L/N du module. Les 4 écarts de
  dégagement 230 V (0,84 mm pour 1 mm) ont disparu. Scripts :
  `tools/fix_zmpt_secteur_sch.py`, `fix_zmpt_secteur_sch2.py`,
  `fix_zmpt_secteur_pcb.py`.
- Re-routage complet (Freerouting) : DRC **0 non connecté, 7 violations**
  (avertissements « empreinte modifiée localement ») ; parité schéma/PCB :
  99 écarts cosmétiques préexistants + 2 notes attendues (« pas de pastille »
  pour les broches L/N de U12, câblées hors carte via J27).

## Points à garder en tête avant fabrication

1. **Câblage du ZMPT101B** : relier J27 (PH / N) au bornier à vis du module
   avec du fil isolé 230 V (0,75 mm² suffit, le courant est de quelques mA).
2. **Courant par canal** : les pistes HT font 1 mm (cuivre 2 oz) ; le courant
   de puissance (20 A) passe par les barres de cuivre soudées sur les points
   d'accueil `BAR1`-`BAR32` (voir `simulation/figures/fig_barres_cuivre.png`).
3. Dans chaque canal, le courant fait l'aller-retour relais → ACS712 (à gauche)
   → bornier (à droite) : c'est la topologie d'origine, conservée pour ne pas
   changer le routage qui avait été validé.

## Refaire le compactage / le routage (Windows)

Avec KiCad 10 installé dans `C:\Users\User\Tools\KiCad` et Java + Freerouting
dans `C:\Users\User\Tools` :

```powershell
$k = "C:\Users\User\Tools\KiCad\bin"
& "$k\python.exe" kicad\tools\compact_pcb.py            # placement + contour, supprime les pistes
& "$k\python.exe" kicad\tools\route_pcb.py C:\Users\User\Tools\freerouting-2.1.0.jar `
      "C:\Users\User\Tools\jdk-21.0.13+9-jre\bin\java.exe" 100   # ~25 min
& "$k\kicad-cli.exe" pcb drc --format json --severity-all -o drc.json kicad\multical\multical.kicad_pcb
& "$k\python.exe" kicad\tools\finish_acs712.py drc.json  # liaisons broches 1-2 / 3-4 des ACS712
& "$k\kicad-cli.exe" pcb drc --format json --severity-all -o drc.json kicad\multical\multical.kicad_pcb
& "$k\python.exe" kicad\tools\cleanup_after_route.py drc.json
```

`route_pcb.py --import-only` réimporte `multical_compact.ses` sans relancer
Freerouting.
