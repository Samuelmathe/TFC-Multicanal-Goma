// Ces classes reproduisent exactement le JSON renvoye par le serveur API
// embarque de l'ESP32 (voir main.cpp du projet PlatformIO "tfc-multicanal").
// Si tu changes un champ cote firmware, change-le ici aussi.

class CanalEtat {
  final int canal;
  final String role;
  final double courantA;
  final double puissanceW;
  final double energieKWh;
  final double creditUSD;
  final double creditKWh;
  final double cosPhi;
  final bool relaisFerme;
  final bool coupureVolontaire;
  final String nomAffiche;
  final String dernierEvenement;
  final int dernierHorodatageMs;

  CanalEtat({
    required this.canal,
    required this.role,
    required this.courantA,
    required this.puissanceW,
    required this.energieKWh,
    required this.creditUSD,
    required this.creditKWh,
    required this.cosPhi,
    required this.relaisFerme,
    required this.coupureVolontaire,
    required this.nomAffiche,
    required this.dernierEvenement,
    required this.dernierHorodatageMs,
  });

  // Nom "Locataire N" par defaut, ou le nom reel si le bailleur l'a saisi.
  String libelleAffiche(bool estBailleurCanal) {
    if (nomAffiche.isNotEmpty) return nomAffiche;
    return estBailleurCanal ? "Bailleur" : "Locataire $canal";
  }

  // fromJson : transforme une Map (issue du JSON) en objet Dart.
  // C'est l'equivalent de JSON.parse() + acces aux champs en JavaScript.
  factory CanalEtat.fromJson(Map<String, dynamic> json) {
    return CanalEtat(
      canal: json['canal'] as int,
      role: json['role'] as String,
      courantA: (json['courant_A'] as num).toDouble(),
      puissanceW: (json['puissance_W'] as num).toDouble(),
      energieKWh: (json['energie_kWh'] as num).toDouble(),
      creditUSD: (json['credit_USD'] as num).toDouble(),
      creditKWh: (json['credit_kWh'] as num).toDouble(),
      cosPhi: (json['cos_phi'] as num?)?.toDouble() ?? 0.0,
      relaisFerme: json['relais_ferme'] as bool,
      coupureVolontaire: json['coupure_volontaire'] as bool? ?? false,
      nomAffiche: json['nom_affiche'] as String? ?? '',
      dernierEvenement: json['dernier_evenement'] as String,
      dernierHorodatageMs: (json['dernier_horodatage_ms'] as num?)?.toInt() ?? 0,
    );
  }
}

class EtatSysteme {
  final double tensionSecteurV;
  final double tarifUsdParKwh;
  final int maintenantMs;
  final List<CanalEtat> canaux;

  EtatSysteme({
    required this.tensionSecteurV,
    required this.tarifUsdParKwh,
    required this.maintenantMs,
    required this.canaux,
  });

  // Combien de kWh un dollar achete, au tarif courant - c'est ce que le
  // bailleur pense en premier ("1 dollar = combien de kWh").
  double get kwhParDollar => tarifUsdParKwh > 0 ? 1.0 / tarifUsdParKwh : 0.0;

  factory EtatSysteme.fromJson(Map<String, dynamic> json) {
    final liste = (json['canaux'] as List)
        .map((c) => CanalEtat.fromJson(c as Map<String, dynamic>))
        .toList();
    return EtatSysteme(
      tensionSecteurV: (json['tension_secteur_V'] as num).toDouble(),
      tarifUsdParKwh: (json['tarif_usd_par_kwh'] as num).toDouble(),
      maintenantMs: (json['maintenant_ms'] as num?)?.toInt() ?? 0,
      canaux: liste,
    );
  }
}

class HistoriqueEntree {
  final int horodatageMs;
  final String type;
  final double valeur;

  HistoriqueEntree({
    required this.horodatageMs,
    required this.type,
    required this.valeur,
  });

  factory HistoriqueEntree.fromJson(Map<String, dynamic> json) {
    return HistoriqueEntree(
      horodatageMs: (json['horodatage_ms'] as num).toInt(),
      type: json['type'] as String,
      valeur: (json['valeur'] as num).toDouble(),
    );
  }

  // Libelle lisible pour chaque type d'evenement enregistre par le firmware.
  String get libelle {
    switch (type) {
      case 'recharge':
        return 'Recharge';
      case 'coupure_credit':
        return 'Coupure automatique (credit epuise)';
      case 'coupure_volontaire':
        return 'Coupure volontaire';
      case 'retablissement':
        return 'Retablissement';
      case 'demarrage':
        return 'Demarrage du systeme';
      default:
        return type;
    }
  }
}

// Resultat de /api/moi : a qui appartiennent les identifiants saisis sur
// l'ecran de connexion.
class IdentiteConnecte {
  final int canal;
  final String role;

  IdentiteConnecte({required this.canal, required this.role});

  factory IdentiteConnecte.fromJson(Map<String, dynamic> json) {
    return IdentiteConnecte(
      canal: json['canal'] as int,
      role: json['role'] as String,
    );
  }

  bool get estBailleur => role == 'bailleur';
  bool get estElectricien => role == 'electricien';
}
