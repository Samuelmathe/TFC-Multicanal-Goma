# Apprendre Flutter pour ce projet (depuis zéro)

Tu connais déjà la programmation (C++ Arduino, Python) — ce qui te manque
c'est juste la syntaxe Dart et le modèle "widgets" de Flutter. Ce n'est pas
un framework énorme à maîtriser en entier : ce guide se limite à ce dont
**cette app précise** a besoin, pas à "apprendre Flutter" en général.

**Statut actuel** : l'app compile, passe `flutter analyze` sans erreur, et
`flutter test` passe. Elle a 2 écrans fonctionnels (locataire, admin) qui
consomment déjà `/api/etat` et `/api/recharge` — exactement l'API du
firmware. Ce n'est pas un tutoriel vide : c'est du code qui marche, à lire
et à faire évoluer.

**Important** : c'est un objectif secondaire par rapport au matériel et à la
rédaction (deadline < 1 mois, cf. mémoire §3.5 qui explique déjà que
l'interface web suffit comme preuve de concept). Ne sacrifie pas le
câblage/les mesures physiques pour Flutter. Vois ça comme un bonus si tu as
3-5 jours devant toi après le reste.

## Avant de commencer

Flutter est déjà installé sur cette machine (`~/development/flutter`),
ajouté au PATH (`~/.bashrc`). Le SDK Android est aussi déjà configuré.
Vérifie que tout va bien :

```bash
flutter doctor
```

Pour lancer l'app rapidement (sans émulateur Android, juste pour voir
l'interface tourner) :

```bash
cd ~/Documents/TFC-Multicanal-Goma/application
flutter run -d chrome     # le plus rapide pour tester en developpant
# ou : flutter run -d linux
```

Pour tester "pour de vrai" comme dans le mémoire (§3.5, émulateur Android) :
Android Studio n'est pas installé, mais tu peux créer un émulateur en ligne
de commande, ou plus simple : brancher ton téléphone Android en USB avec le
mode développeur + débogage USB activé, puis `flutter run` détectera le
téléphone directement — plus rapide qu'un émulateur sur cette machine.

## Plan sur 4-5 jours (2-3h/jour)

### Jour 1 — Bases du langage Dart
Dart ressemble à un mélange de Java/C++ et de JavaScript moderne. Fais le
tour officiel (1h30-2h), en pratiquant dans DartPad (aucune install requise,
dans le navigateur) :
- Dart Tour : https://dart.dev/language
- DartPad (bac à sable) : https://dartpad.dev

Concentre-toi sur : variables/types, fonctions, classes, `async`/`await`
et `Future` (c'est l'équivalent direct des callbacks/promesses que tu as
déjà croisés en JS pour l'app web, ou du non-bloquant en C++).

### Jour 2 — Widgets et mise en page
Lis `lib/screens/home_screen.dart` de ce projet ligne par ligne, en
t'aidant du codelab officiel en parallèle :
- Write your first Flutter app : https://docs.flutter.dev/get-started/codelab

Concepts clés à comprendre (déjà utilisés dans le code) :
- `StatelessWidget` vs `StatefulWidget` (= un écran qui ne change jamais vs
  un écran qui doit se redessiner quand une donnée change)
- `setState(() { ... })` = "je viens de changer une valeur, redessine
  l'écran" (équivalent de la mise à jour du DOM après un `fetch()` dans
  `app.js` de l'interface web)
- `Scaffold`, `Column`, `Row`, `Padding` = les briques de mise en page
  (comme des `<div>` avec flexbox en CSS)

Fais des petites modifications toi-même dans `home_screen.dart` (change un
texte, une couleur, ajoute un bouton) et observe le "hot reload" (`r` dans
le terminal `flutter run`, ou sauvegarde dans l'IDE) — c'est la boucle de
développement Flutter, très rapide une fois qu'on l'a en main.

### Jour 3 — Appels HTTP et JSON
Lis `lib/models.dart` et `lib/api_client.dart` : c'est la traduction directe
de ce que fait déjà `app.js` (`fetch("/api/etat")` + `JSON.parse`) mais en
Dart typé. Documentation du package `http` :
- https://pub.dev/packages/http

Exercice concret : lance le firmware (Wokwi ou vrai ESP32), note l'IP, mets
cette IP dans le champ de `HomeScreen`, lance `flutter run -d chrome`, et
vérifie que l'écran locataire affiche les vraies valeurs du firmware.

### Jour 4 — Comprendre `tenant_screen.dart` et `admin_screen.dart`
Ce sont les deux écrans complets. Repère :
- `Timer.periodic` = équivalent de `setInterval()` (rafraîchit toutes les
  2 secondes, comme `app.js`)
- `initState()` / `dispose()` = code qui s'exécute à l'ouverture / à la
  fermeture de l'écran (annuler le Timer dans `dispose()` est important,
  sinon il continue de tourner après avoir quitté l'écran)
- `FutureBuilder` n'est pas utilisé ici (on a préféré `setState` + Timer,
  plus simple à suivre pour un premier projet) — tu peux le découvrir plus
  tard si tu veux une version "plus Flutter idiomatique"

### Jour 5 (optionnel, marge) — Captures d'écran pour le mémoire
Le mémoire a des emplacements réservés `[Insérer ici la maquette de
l'application mobile Flutter...]` (§2.9) et `[Insérer ici une capture
d'écran de l'application mobile Flutter...]` (§3.5). Une fois l'app testée
contre le vrai ESP32 (§3.6), fais ces captures et remplace les placeholders.

## Si tu bloques sur quelque chose de précis

Reviens vers moi avec l'erreur exacte (copie le message du terminal) plutôt
que de chercher à tout comprendre d'un coup — c'est comme ça qu'on avance
vite sur un nouveau langage.

## Ressources de secours (si tu préfères la vidéo)
- Chaîne YouTube officielle Flutter : https://www.youtube.com/@flutterdev
- freeCodeCamp "Flutter Course for Beginners" (gratuit, complet, en anglais)
