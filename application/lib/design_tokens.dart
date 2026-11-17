// Echelle de tokens visuels de l'app, extraite de la critique design (S3) :
// les widgets de depart utilisaient des valeurs ad hoc (14/16/18/20/22px de
// rayon, 10 a 22px de texte par pas de 0.5) qui ont fini par diverger entre
// ecrans. Ces constantes servent de reference commune pour les nouveaux
// widgets - les anciens Container existants ne sont pas tous migres (risque
// de regression visuelle trop large pour le benefice), mais tout nouveau
// composant (ex. StatCard) s'appuie dessus.
class AppRadius {
  static const double s = 12; // petites alertes, badges
  static const double m = 16; // lignes de liste, boutons
  static const double l = 20; // cartes, conteneurs de section
}

class AppTextSize {
  static const double label = 11.5; // libelle au-dessus d'une valeur
  static const double body = 13; // texte courant
  static const double value = 16; // valeur mise en avant dans une carte
  static const double valueLarge = 22; // valeur hero (ex. bandeau statut)
}
