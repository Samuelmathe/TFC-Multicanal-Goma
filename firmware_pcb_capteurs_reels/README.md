# Firmware "capteurs reels" (ACS712 + ZMPT101B, 8 canaux) — PCB

**Statut : non testé sur matériel réel.** Le circuit imprimé conçu sous
KiCad (dossier `../kicad/`) n'a pas encore été fabriqué ni assemblé. Ce
firmware est le design cible pour ce PCB à 8 canaux (chapitre 2 du mémoire),
écrit et documenté, mais jamais exécuté sur les vrais capteurs ACS712 /
ZMPT101B.

Pour la version **réellement construite et validée** (maquette sur carte
perforée, 4 canaux, potentiomètres simulant les capteurs, cf. rapport
chapitre 3), voir le dossier voisin [`../firmware/`](../firmware/).

## Ce qui diffère de la maquette

| | `firmware/` (maquette, validée) | `firmware_pcb_capteurs_reels/` (ce dossier) |
|---|---|---|
| Canaux | 4 (1 bailleur + 3 locataires) | 8 (1 bailleur + 7 locataires) |
| Capteur de courant | Potentiomètre (tension DC proportionnelle) | ACS712-20A (signal AC réel, RMS calculé sur 40 échantillons/cycle 50 Hz) |
| Capteur de tension | Potentiomètre | ZMPT101B |
| cos(φ) | Fixé à 1 (simplification assumée) | Calculé réellement : `P/S` à partir de `P`, `S = I_eff x V_eff`, `Q = √(S²-P²)` |
| Broches ADC | Toutes sur ADC1 | Canaux 1 et 2 + tension sur ADC2 (cf. Tableau 2.2 du mémoire), avec gestion explicite du conflit ADC2/Wi-Fi (`lireADC2Securise`) |
| Matériel exécuté dessus | ESP32 réel, testé et flashé | Aucun — code seul, PCB non fabriqué |

L'algorithme d'acquisition (échantillonnage synchrone courant/tension,
calcul RMS, puissance active/apparente/réactive, cos(φ) réel) suit
exactement la description du mémoire, §2.7.

## Constantes à calibrer avant toute mise en service

Ces valeurs, dans `src/config.h`, sont des valeurs nominales de datasheet ou
des estimations — **pas des mesures faites sur le circuit réel** (qui
n'existe pas encore) :

- `ACS712_SENSIBILITE_V_PAR_A` (100 mV/A, valeur datasheet Allegro pour la
  variante 20A — la tolérance fabricant réelle peut différer de quelques %)
- `ZMPT_FACTEUR_CALIBRATION` (rapport tension secteur réelle / tension RMS
  mesurée à l'ADC — dépend du pont diviseur exact du module ZMPT101B utilisé,
  à déterminer par comparaison avec un multimètre/wattmètre une fois le PCB
  assemblé)

Les offsets DC (Vcc/2 par canal) sont recalibrés automatiquement à chaque
démarrage (`calibrerOffsets()`), en supposant qu'aucun courant ne circule
encore à l'allumage.

## Limitation connue : ADC2 et Wi-Fi

Les canaux 1, 2 et la mesure de tension (ZMPT101B) utilisent l'ADC2 de
l'ESP32, qui n'est pas utilisable pendant que le pilote Wi-Fi l'occupe (le
point d'accès de la maquette tourne en permanence). Le firmware détecte ce
cas via le code retour d'`adc2_get_raw()` et ignore simplement l'échantillon
concerné (plutôt que d'enregistrer une fausse valeur, piège classique
d'`analogRead()` sur ADC2). Cf. mémoire §1.4.3 pour la discussion complète de
cette contrainte matérielle et son impact réduit sur le PCB final par
rapport à la maquette (fenêtres ponctuelles plutôt que Wi-Fi permanent).

## Compiler

Comme pour `firmware/` : `pio run` (compilation seule, aucun upload possible
sans le matériel).
