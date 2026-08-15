# Guide — Terminer le routage 20 A par canal

Objectif : finir de router `multical.kicad_pcb` après la révision pour
20 A par canal (2 oz de cuivre, pistes 6,5 mm, carte agrandie à
236 x 461,5 mm). L'essentiel du travail a déjà été fait automatiquement
(repositionnement des 8 grappes de canaux, agrandissement de la carte,
cuivre 2 oz déclaré) ; il reste **15 connexions non conformes sur plus de
200** à router à la main dans l'interface graphique de KiCad — beaucoup
plus rapide et fiable que de batailler avec l'automatisation en ligne de
commande.

**État au 11 août** : `multical.kicad_pcb` est dans un état sûr et vérifié
par DRC (aucune régression), mais avec l'ancien routage 2,5 mm / 1 oz
encore en place partout. Les fichiers de sauvegarde
`multical.kicad_pcb.before-20A.bak` et `multical.kicad_pcb.before-replan.bak`
(dans le même dossier) permettent de revenir en arrière à tout moment si
besoin — n'y touche pas, ce sont des filets de sécurité.

## 0. Lancer KiCad

Utilise la flatpak (10.0.4, pas la snap 9.0.7 périmée) :

```bash
flatpak run org.kicad.KiCad
```

Ouvre le projet `multical.kicad_pro` (dossier
`kicad/multical/`), puis double-clique sur **PCB Editor**.

## 1. Vérifier l'état actuel

1. **Inspecter → Vérification des règles de conception (DRC)** → lance-le.
   Tu dois voir uniquement les 12 erreurs `drill_out_of_range` déjà
   connues (perçage 0,2 mm au lieu de 0,3 mm sur des pastilles GND de
   U1) — rien de plus grave. Si tu vois des courts-circuits, arrête-toi
   et reviens à `multical.kicad_pcb.before-replan.bak`.
2. Regarde le chevelu (ratsnest) : les lignes blanches fines qui
   traversent la carte sont les connexions pas encore routées. Vu le
   nombre (~15), elles devraient être concentrées près des canaux les
   plus serrés (regarde en particulier les canaux 5 à 8, en bas de la
   carte, qui ont été les plus difficiles à router lors du test
   automatique).

## 2. Router avec Freerouting (en mode graphique, pas en ligne de commande)

Le mode CLI de Freerouting utilisé pour la tentative automatique n'a pas
de bouton "sauvegarder" fiable une fois lancé sans interface — le mode
graphique n'a pas ce problème : tu vois la progression et tu cliques
"stop" puis "sauvegarder" quand tu es content du résultat.

1. Dans KiCad PCB Editor : **Fichier → Exporter → Spécification Specctra
   (.dsn)**. Sauvegarde-le à côté du projet, par exemple
   `multical.dsn`.
2. Lance Freerouting en mode graphique (double-clique sur le fichier
   `.jar`, ou en terminal) :
   ```bash
   java -jar kicad/tools/freerouting-2.1.0.jar
   ```
3. Dans la fenêtre Freerouting : **File → Open** → sélectionne ton
   `multical.dsn`.
4. Avant de lancer l'auto-routeur, vérifie les règles des nets de
   puissance : les 18 nets `CANAL1_HT` à `CANAL8_OUT` doivent être en
   classe **CANAL_20A** (largeur 6,5 mm, dégagement 3 mm), et
   `PHASE_BUS` / `NEUTRE_BUS` en classe **BUS_ENTREE** (largeur 10 mm,
   dégagement 3 mm) — ces classes ont déjà été injectées dans le
   fichier `.dsn` si tu es reparti d'un export frais généré après le
   script `kicad/tools/fix_dsn_widths_20A.py` ; sinon relance ce script
   sur ton `.dsn` avant de l'ouvrir dans Freerouting :
   ```bash
   python3 kicad/tools/fix_dsn_widths_20A.py
   ```
5. Clique sur **Autoroute** (bouton play). Laisse tourner — ça se
   stabilise généralement en 1 à 2 minutes à ~15 connexions non
   routées et n'ira probablement pas plus loin tout seul (les 15
   restantes sont les endroits où la carte est encore trop dense pour
   la nouvelle largeur de piste).
6. Clique sur **Stop** une fois que le compteur de connexions non
   routées ne bouge plus.

## 3. Router les 15 dernières connexions à la main

Pour celles que l'auto-routeur n'a pas réussi à placer :

1. Reste dans Freerouting (ou repasse par KiCad si tu préfères router à
   la main dans le PCB Editor directement, avec la touche **X** pour
   démarrer une piste).
2. Zoome sur chaque connexion non routée (surlignée en rouge dans
   Freerouting, ou visible comme ligne de chevelu dans KiCad).
3. Le plus souvent, il suffit d'écarter légèrement deux composants
   voisins (dans KiCad, sélectionne le composant et déplace-le de
   quelques millimètres) pour libérer la place, puis relance
   l'auto-routeur sur ce qui reste, ou trace la piste manuellement.
4. Pour une piste manuelle en 6,5 mm : sélectionne l'outil piste, puis
   avant de cliquer, tape la largeur voulue dans le champ en haut de
   l'écran (ou clic droit → **Largeur de piste → 6,5 mm** une fois la
   piste commencée).

## 4. Réimporter dans KiCad

1. Dans Freerouting : **File → Export Specctra Session File (.ses)**.
2. Dans KiCad PCB Editor : **Fichier → Importer → Spécification
   Specctra (.ses)** → sélectionne le fichier généré.
3. Relance le DRC (étape 1) pour confirmer que tout est propre.
4. Sauvegarde le projet.

## 5. Les deux points qui ne se règlent pas en routant

Router plus large ne suffit pas à rendre la carte prête pour 20 A — deux
décisions restent à prendre avant fabrication (détaillées dans le
rapport, section 2.5.5) :

- **Relais K1-K8** : actuellement des Hongfa JQC-3FF (10 A). Il faut les
  remplacer par un modèle 15-20 A de même empreinte THT (le schéma les
  a déjà renommés `Relay_SPDT_20A_A_CONFIRMER` pour ne pas l'oublier).
  Vérifie la disponibilité locale à Goma avant de figer le choix.
- **Bus d'entrée (PHASE_BUS / NEUTRE_BUS)** : si les 8 canaux tirent 20 A
  en même temps, ça fait 160 A à faire passer — aucune piste de circuit
  imprimé ne peut raisonnablement porter ça. La piste de 10 mm sur la
  carte ne doit être vue que comme un talon de connexion ; le vrai
  chemin de puissance doit passer par une barre de cuivre ou un câble de
  forte section, câblé en externe entre le bornier secteur et chaque
  relais.

## 6. Une fois le routage terminé

- Relance le DRC une dernière fois, zéro erreur hors les 12
  `drill_out_of_range` connues (ou corrige aussi celles-là en élargissant
  le perçage des pastilles GND de U1 à 0,3 mm).
- Régénère les fichiers de fabrication (Gerbers, perçage, BOM) via
  **Fichier → Fabrication** dans KiCad.
- Mets à jour la section 2.5.5 du rapport (`rapport/59Travail_...docx` ou
  `rapport/TFC_Complet-2.docx` selon lequel tu continues) pour dire que
  le routage est terminé, et remplace la phrase sur les "15 connexions
  restantes" par le résultat final.
