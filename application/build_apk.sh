#!/usr/bin/env bash
set -e

cd "$(dirname "$0")"

echo "== Recuperation des dependances =="
flutter pub get

echo "== Compilation de l'APK (release) =="
flutter build apk --release

echo
echo "APK genere ici :"
echo "  $(pwd)/build/app/outputs/flutter-apk/app-release.apk"
