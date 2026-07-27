# Guide d'entraînement — Bien souder

Ce guide est fait pour progresser par exercices courts, pas juste "souder
au hasard". Fais chaque exercice dans l'ordre, sur des composants de
récupération (pas ceux de ta maquette), avant de passer au suivant.

## Matériel nécessaire

- Fer à souder (température réglable si possible, sinon un fer simple
  fonctionne aussi avec un peu plus de patience)
- Fil de soudure (idéalement avec âme de flux à l'intérieur — c'est écrit
  sur la bobine, "flux core" ou "rosin core")
- Éponge humide ou laine de laiton (pour nettoyer la panne)
- Quelques résistances, fils, et une petite plaque à trous de
  récupération pour t'entraîner — pas tes composants de projet
- Une pince fine (pour tenir les petites pièces)

## Avant de commencer : prépare le fer

1. Allume le fer, laisse-le chauffer 2-3 minutes
2. Nettoie la panne sur l'éponge humide (ou la laine de laiton)
3. **Étame la panne** : dépose un petit filet de soudure directement
   dessus, essuie l'excédent. La panne doit être brillante, pas noire.
   Répète ce nettoyage régulièrement pendant que tu travailles.

## La technique correcte

1. Positionne le fer pour toucher **à la fois** la patte du composant et
   la pastille/le fil sur lequel tu soudes — jamais l'un sans l'autre
2. Compte 1 à 2 secondes pour que **le joint** (pas le fer) devienne assez
   chaud
3. Apporte le fil de soudure directement sur le joint chauffé (pas sur la
   panne du fer) — la chaleur du joint doit faire fondre la soudure
4. Dès qu'un petit cône brillant s'est formé autour du joint, retire
   d'abord la soudure, puis le fer
5. Ne bouge rien pendant 2-3 secondes le temps que ça refroidisse

**Règle des 3 secondes** : ne reste jamais plus de 3 secondes sur un même
joint. Si ce n'est pas assez chaud après 3 secondes, retire le fer,
laisse refroidir un peu, renettoie la panne, réessaie — plutôt que de
insister et cuire le composant.

## Exercice 1 — Contrôle de la chaleur (fils seuls)

Prends deux bouts de fil électrique dénudés, torsade-les ensemble à la
main, puis soude la torsade.

- **Objectif** : obtenir un joint brillant et lisse, pas granuleux
- Recommence 5 fois avec 5 torsades différentes
- Auto-évaluation après chaque essai : brillant et lisse = réussi ;
  terne/granuleux = raté, regarde le tableau de dépannage plus bas

## Exercice 2 — Composants sur plaque à trous

Sur une plaque à trous de récupération, soude 5 résistances, une par une.

- Insère la résistance, plie légèrement les pattes côté opposé pour
  qu'elle ne tombe pas
- Soude chaque patte (2 par résistance = 10 joints au total)
- **Objectif** : 10 joints propres d'affilée, pas juste 1 ou 2 réussis
  par hasard

## Exercice 3 — Composant sensible à la chaleur (LED)

Les LED n'aiment pas la chaleur prolongée — c'est un bon test de vitesse
et de précision.

- Soude une LED sur la plaque (2 pattes)
- Respecte la règle des 3 secondes strictement ici
- Si la LED grille ou change de couleur légèrement après soudure, tu es
  resté trop longtemps — recommence avec une autre LED en étant plus
  rapide

## Exercice 4 — Dessouder (compétence sous-estimée)

Utile pour corriger tes erreurs sans tout jeter.

- Reprends une résistance déjà soudée à l'exercice 2
- Fais fondre la soudure existante avec le fer, puis retire le composant
  à la pince pendant que c'est encore liquide (ou utilise une pompe à
  dessouder / tresse à dessouder si tu en as une)
- **Objectif** : retirer le composant sans arracher la pastille de la
  plaque

## Tableau de dépannage — reconnaître et corriger tes joints

| Aspect du joint | Cause probable | Correction |
|---|---|---|
| Terne, gris, granuleux | Soudure froide : pas assez chaud, ou bougé trop tôt | Rechauffe le joint, refais fondre, ne bouge plus pendant le refroidissement |
| Boule qui ne colle pas | Tu as fait fondre la soudure sur le fer, pas sur le joint | Apporte la soudure directement sur le joint chauffé, pas sur la panne |
| Trop de soudure, aspect de tas | Trop de fil apporté, ou pas assez chaud pour que ça coule bien | Utilise moins de soudure, vérifie que le joint est bien chaud avant d'apporter le fil |
| Pastille qui se décolle de la plaque | Trop de chaleur trop longtemps au même endroit | Respecte la règle des 3 secondes, laisse refroidir entre deux essais |
| Bon joint | Brillant, lisse, petit cône net | — rien à corriger, continue comme ça |

## Quand tu es prêt pour la vraie maquette

Passe à l'exercice suivant seulement quand tu obtiens des joints propres
de façon répétée (pas juste une fois sur deux). Une fois à l'aise, reprends
le `GUIDE_MAQUETTE_BOITIER.pdf` pour souder le vrai circuit — tu auras
beaucoup moins de mauvaises surprises.
