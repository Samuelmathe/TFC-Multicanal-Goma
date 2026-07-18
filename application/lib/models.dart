// Ces classes reproduisent exactement le JSON renvoye par /api/etat
// dans le firmware (voir construireJsonEtat() dans main.cpp du projet
// PlatformIO "tfc-multicanal"). Si tu changes un champ cote firmware,
// change-le ici aussi.

class CanalEtat {
  final int canal;
  final String role;
  final double courantA;
  final double puissanceW;
  final double energieKWh;
  final double creditUSD;
  final bool relaisFerme;
  final String dernierEvenement;

  CanalEtat({
    required this.canal,
    required this.role,
    required this.courantA,
    required this.puissanceW,
    required this.energieKWh,
    required this.creditUSD,
    required this.relaisFerme,
    required this.dernierEvenement,
  });

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
      relaisFerme: json['relais_ferme'] as bool,
      dernierEvenement: json['dernier_evenement'] as String,
    );
  }
}

class EtatSysteme {
  final double tensionSecteurV;
  final double tarifUsdParKwh;
  final List<CanalEtat> canaux;

  EtatSysteme({
    required this.tensionSecteurV,
    required this.tarifUsdParKwh,
    required this.canaux,
  });

  factory EtatSysteme.fromJson(Map<String, dynamic> json) {
    final liste = (json['canaux'] as List)
        .map((c) => CanalEtat.fromJson(c as Map<String, dynamic>))
        .toList();
    return EtatSysteme(
      tensionSecteurV: (json['tension_secteur_V'] as num).toDouble(),
      tarifUsdParKwh: (json['tarif_usd_par_kwh'] as num).toDouble(),
      canaux: liste,
    );
  }
}
