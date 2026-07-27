// Formatage d'un ecart de temps en clair ("il y a 3 min"). Les horodatages
// du firmware sont des millis() ESP32 (temps ecoule depuis le demarrage, pas
// une date calendaire : l'ESP32 n'a pas d'horloge temps reel ni d'acces
// Internet en mode point d'acces pur, cf. rapport S1.5/S2.8). On calcule donc
// toujours un ecart par rapport a l'horodatage serveur le plus recent
// (maintenant_ms de /api/etat), jamais par rapport a l'horloge du telephone.
String ilYA(int horodatageMs, int maintenantMs) {
  final ecartMs = maintenantMs - horodatageMs;
  if (ecartMs < 0) return "a l'instant";
  final secondes = ecartMs ~/ 1000;
  if (secondes < 60) return "il y a ${secondes}s";
  final minutes = secondes ~/ 60;
  if (minutes < 60) return "il y a $minutes min";
  final heures = minutes ~/ 60;
  if (heures < 24) {
    final minutesRestantes = minutes % 60;
    return minutesRestantes == 0
        ? "il y a ${heures}h"
        : "il y a ${heures}h${minutesRestantes.toString().padLeft(2, '0')}";
  }
  final jours = heures ~/ 24;
  return "il y a $jours j";
}
