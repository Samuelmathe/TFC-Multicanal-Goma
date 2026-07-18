# TFC Multicanal - Maquette Wokwi (5 canaux)

Firmware de démonstration correspondant au chapitre 2 du mémoire (architecture
FreeRTOS à 5 tâches, cf. Annexe A) et au chapitre 3, §3.1-3.6 (validation par
simulation Wokwi puis sur maquette physique). Le firmware **compile déjà**
(vérifié avec `pio run`) — il ne reste qu'à le simuler pour obtenir les
chiffres des tableaux 3.1, 3.2 et 3.5.

## Correction apportée par rapport au mémoire : broches GPIO37/GPIO38

Le Tableau 2.2 (et le Tableau 3.4) assignent les canaux 2 et 3 aux broches
**GPIO37** et **GPIO38**. Ces deux broches existent sur la puce ESP32 mais ne
sont **pas sorties sur le connecteur d'un ESP32 DevKitC standard** (ni dans
Wokwi) — ce n'est pas une erreur de câblage, c'est une limitation physique du
connecteur de ce type de carte.

- Sur le **PCB final** (chapitre 2.5, module WROOM-32 nu et non une carte
  DevKitC toute faite), tu peux tout à fait router GPIO37/38 toi-même : le
  Tableau 2.2 n'a pas besoin de changer pour cette partie-là.
- Pour la **maquette breadboard** (§3.6.2, qui utilise un "ESP32 DevKit V1")
  et pour **cette simulation Wokwi**, ces deux broches sont physiquement
  inaccessibles. J'ai donc réaffecté les canaux 2 et 3 aux broches GPIO34 et
  GPIO35 (elles aussi en ADC1, donc sans conflit Wi-Fi, cf. §1.4.3).

Nouveau mapping utilisé ici (à reporter dans le Tableau 3.4 si tu veux que le
mémoire corresponde exactement à cette maquette) :

| Canal | Rôle        | Potentiomètre (courant) | LED (sortie) |
|-------|-------------|--------------------------|--------------|
| 0     | Bailleur    | GPIO36 (VP)              | GPIO4        |
| 1     | Locataire 1 | GPIO39 (VN)              | GPIO5        |
| 2     | Locataire 2 | GPIO34                   | GPIO13       |
| 3     | Locataire 3 | GPIO35                   | GPIO14       |
| 4     | Locataire 4 | GPIO32                   | GPIO16       |

Le potentiomètre de tension (ZMPT101B simulé) reste sur GPIO25, inchangé.

## Comment lancer la simulation (VS Code + extension Wokwi)

1. Dans VS Code, installe l'extension **"Wokwi Simulator"** (en plus de
   PlatformIO déjà installé sur cette machine).
2. Ouvre le dossier `tfc-multicanal` dans VS Code.
3. `Ctrl+Shift+P` → **"Wokwi: Start Simulator"** (ou l'icône lecture en haut
   à droite du fichier `diagram.json`). Ça compile automatiquement via
   PlatformIO puis lance la simulation.
4. Ouvre le **moniteur série** intégré à Wokwi (icône dans le panneau de
   simulation) : c'est là que tu liras les valeurs pour les tableaux.

> Remarque : le simulateur Wokwi ne charge pas encore d'image LittleFS (c'est
> une limitation connue de Wokwi, pas un bug de ce firmware). Les pages web
> (`/`, `/admin`, `/L0`...) ne s'afficheront donc pas en simulation, seulement
> sur le vrai ESP32. **Ça n'empêche pas de remplir les tableaux 3.1/3.2**, qui
> se lisent entièrement depuis le moniteur série.

## Remplir le Tableau 3.1 (grandeurs électriques)

Le moniteur série affiche toutes les 2 secondes un tableau comme :

```
--- Canal | V_secteur(V) | I(A) | P(W) | E_cumulee(kWh) | Credit(USD) | Relais ---
0     | 220.50       | 3.120 | 688.29| 0.00191        | 0.0490     | FERME
...
```

Pour chaque canal : clique sur le potentiomètre correspondant dans la vue
Wokwi, fais-le glisser vers une position connue, note la valeur affichée dans
`courant_A`/`I(A)`. Le "courant attendu (calcul théorique)" du Tableau 3.1
est simplement `I = |position_pot - 50%| / 50% x 20 A` (cf. `config.h`,
`COURANT_MAX_A`) — compare-le à la valeur `I(A)` imprimée par le firmware.

## Remplir le Tableau 3.2 (coupure / rétablissement)

Le crédit initial est **volontairement bas** (`CREDIT_INITIAL_USD = 0.05` USD
dans `config.h`) pour que la coupure arrive vite en simulation. Laisse tourner
la simulation quelques dizaines de secondes en écartant un potentiomètre de
courant du centre (donc en simulant une consommation) : tu verras la colonne
`Credit(USD)` descendre puis la colonne `Relais` passer de `FERME` à
`OUVERT`, et la LED correspondante s'éteindre dans la vue Wokwi. C'est
exactement le scénario du Tableau 3.2 — note les instants observés.

## Tableau 3.5 (maquette physique réelle)

Une fois que tu as un vrai ESP32 DevKitC : même firmware, même
`platformio.ini`. Étapes supplémentaires propres au matériel réel :

```bash
pio run --target uploadfs   # copie data/ (pages HTML) sur la puce
pio run --target upload     # flashe le firmware
pio device monitor          # équivalent du moniteur série Wokwi
```

Les pages web (`http://192.168.4.1/`, `/admin`, `/L0`...) fonctionneront
cette fois, contrairement à la simulation Wokwi.

## Identifiants de démonstration

- Wi-Fi : SSID `TFC-Multicanal-Goma`, mot de passe `12345678`
- Admin HTTP (Basic Auth sur `/admin` et `/api/recharge`) : utilisateur
  `bailleur`, mot de passe `bailleur2026`

Ces valeurs sont dans `src/config.h`, à changer avant toute utilisation
au-delà de la démonstration.
