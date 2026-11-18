# Application mobile — TFC Multicanal Goma

Application Flutter (Android, iOS) qui se connecte en Wi-Fi au boîtier ESP32
pour consulter et gérer la consommation électrique de chaque canal.

## Rôles

L'identifiant saisi à la connexion détermine le rôle :

| Rôle | Ce qu'il voit / peut faire |
|------|----------------------------|
| **Bailleur** | Tous les canaux, recharge du crédit, coupure / rétablissement, réarmement après surintensité |
| **Locataire** | Son propre canal : consommation, crédit restant, historique |
| **Électricien** | Mesures techniques (tension, courant) sans gestion du crédit ni coupure |

## Structure

```
lib/
  main.dart                  point d'entrée, thème Material 3 (clair / sombre)
  api_client.dart            appels HTTP vers l'ESP32 (/api/etat, /api/recharge, ...)
  models.dart                modèles de données (état système, canal, identité)
  historique_db.dart         historique local (SQLite via sqflite)
  temps.dart                 utilitaires de date / heure
  design_tokens.dart         couleurs et espacements partagés
  screens/                   écrans (connexion, bailleur, détail canal, électricien,
                             graphique, historique)
  widgets/stat_card.dart     carte de statistique réutilisable
test/widget_test.dart        test de l'écran de connexion
```

## Lancer

1. Connecter le téléphone au point d'accès Wi-Fi de l'ESP32.
2. Dans l'application, l'adresse par défaut est `http://192.168.4.1`.

```bash
flutter pub get
flutter run            # sur un téléphone branché en USB
flutter test           # tests
./build_apk.sh         # génère l'APK de release
```

Voir aussi `APPRENDRE_FLUTTER.md` et `docs/explication_flutter.pdf`.
