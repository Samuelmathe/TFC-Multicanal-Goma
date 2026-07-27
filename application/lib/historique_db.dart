import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'api_client.dart';

// Historique des evenements (recharges, coupures, retablissements) : stocke
// entierement cote application, dans une base SQLite locale au telephone -
// pas durablement sur l'ESP32 (cf. discussion : l'historique long terme n'est
// pas la responsabilite du firmware). Avantage secondaire : les horodatages
// sont ceux, reels, du telephone (contrairement au millis() de l'ESP32 qui ne
// connait pas la date).
//
// Le firmware conserve neanmoins une petite file d'evenements EN ATTENTE
// (non encore recuperes), pour ne rien perdre si l'app etait fermee au
// moment ou l'evenement s'est produit - cf. drainerFirmware() qui la
// recupere et la vide au fur et a mesure (route /api/historique/nouveaux).
class EvenementLocal {
  final int? id;
  final int canal;
  final String type;
  final double valeur;
  final int horodatage; // epoch ms, horloge du telephone
  final int? sourceHorodatageMs; // horodatage firmware d'origine (dedup)

  EvenementLocal({
    this.id,
    required this.canal,
    required this.type,
    required this.valeur,
    required this.horodatage,
    this.sourceHorodatageMs,
  });

  Map<String, dynamic> toMap() => {
        'canal': canal,
        'type': type,
        'valeur': valeur,
        'horodatage': horodatage,
        'source_horodatage_ms': sourceHorodatageMs,
      };

  factory EvenementLocal.fromMap(Map<String, dynamic> m) => EvenementLocal(
        id: m['id'] as int,
        canal: m['canal'] as int,
        type: m['type'] as String,
        valeur: (m['valeur'] as num).toDouble(),
        horodatage: m['horodatage'] as int,
        sourceHorodatageMs: m['source_horodatage_ms'] as int?,
      );

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
      default:
        return type;
    }
  }
}

enum Granularite { jour, semaine, mois }

class PointConsommation {
  final String bucket; // cle de regroupement SQLite (ex: "2026-07-26")
  final double kwh;

  PointConsommation({required this.bucket, required this.kwh});
}

class HistoriqueDB {
  HistoriqueDB._();
  static final HistoriqueDB instance = HistoriqueDB._();

  Database? _db;
  final Map<int, int> _dernierReleveMs = {};
  static const int _intervalleReleveMs = 60 * 1000; // 1 releve/minute max

  Future<Database> get _database async {
    final existante = _db;
    if (existante != null) return existante;
    final chemin = join(await getDatabasesPath(), 'tfc_historique.db');
    final ouverte = await openDatabase(
      chemin,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE evenements (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            canal INTEGER NOT NULL,
            type TEXT NOT NULL,
            valeur REAL NOT NULL,
            horodatage INTEGER NOT NULL,
            source_horodatage_ms INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE releves (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            canal INTEGER NOT NULL,
            horodatage INTEGER NOT NULL,
            energie_kwh REAL NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX idx_releves_canal_horo ON releves(canal, horodatage)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS releves (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              canal INTEGER NOT NULL,
              horodatage INTEGER NOT NULL,
              energie_kwh REAL NOT NULL
            )
          ''');
          await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_releves_canal_horo ON releves(canal, horodatage)');
        }
      },
    );
    _db = ouverte;
    return ouverte;
  }

  // Releve periodique de l'index d'energie cumulee (cf. energie_kWh, jamais
  // remise a zero - comme l'index d'un vrai compteur), utilise pour
  // reconstituer une consommation par jour/semaine/mois. Limite a 1
  // enregistrement par minute et par canal pour ne pas saturer la base -
  // suffisant pour des agregations qui portent sur des jours/semaines/mois.
  Future<void> enregistrerReleveSiUtile(int canal, double energieKWh) async {
    final maintenant = DateTime.now().millisecondsSinceEpoch;
    final dernier = _dernierReleveMs[canal];
    if (dernier != null && maintenant - dernier < _intervalleReleveMs) return;
    _dernierReleveMs[canal] = maintenant;
    final db = await _database;
    await db.insert('releves', {
      'canal': canal,
      'horodatage': maintenant,
      'energie_kwh': energieKWh,
    });
  }

  // Consommation (delta d'index, pas la valeur cumulee) regroupee par
  // jour/semaine/mois pour un canal. Fenetre glissante bornee a
  // [nombrePeriodes] periodes pour rester lisible sur un graphique.
  Future<List<PointConsommation>> consommationParPeriode(
    int canal,
    Granularite granularite, {
    int nombrePeriodes = 14,
  }) async {
    final String format;
    final Duration fenetre;
    switch (granularite) {
      case Granularite.jour:
        format = '%Y-%m-%d';
        fenetre = Duration(days: nombrePeriodes);
        break;
      case Granularite.semaine:
        format = '%Y-%W';
        fenetre = Duration(days: nombrePeriodes * 7);
        break;
      case Granularite.mois:
        format = '%Y-%m';
        fenetre = Duration(days: nombrePeriodes * 31);
        break;
    }
    final cutoff = DateTime.now().subtract(fenetre).millisecondsSinceEpoch;
    final db = await _database;
    final lignes = await db.rawQuery('''
      SELECT strftime('$format', horodatage / 1000, 'unixepoch') as bucket,
             MIN(energie_kwh) as mn, MAX(energie_kwh) as mx
      FROM releves
      WHERE canal = ? AND horodatage >= ?
      GROUP BY bucket
      ORDER BY bucket ASC
    ''', [canal, cutoff]);
    return lignes
        .map((r) => PointConsommation(
              bucket: r['bucket'] as String,
              kwh: ((r['mx'] as num).toDouble() - (r['mn'] as num).toDouble()),
            ))
        .toList();
  }

  Future<void> _enregistrer(int canal, String type, double valeur,
      {int? sourceHorodatageMs}) async {
    final db = await _database;
    await db.insert(
      'evenements',
      EvenementLocal(
        canal: canal,
        type: type,
        valeur: valeur,
        horodatage: DateTime.now().millisecondsSinceEpoch,
        sourceHorodatageMs: sourceHorodatageMs,
      ).toMap(),
    );
  }

  // Recupere les evenements en attente cote firmware pour ce canal et les
  // insere dans la base locale. Idempotent : si le meme evenement (canal +
  // type + valeur + horodatage firmware) a deja ete enregistre - cas d'une
  // simple consultation par le bailleur, qui ne purge pas la file du
  // locataire concerne - il n'est pas duplique. A appeler regulierement
  // (a chaque rafraichissement d'ecran) pour rester a jour en quasi temps
  // reel, en plus de rattraper ce qui a pu se produire app fermee.
  Future<void> drainerFirmware(ApiClient api, int canal) async {
    final nouveaux = await api.nouveauxEvenements(canal);
    if (nouveaux.isEmpty) return;
    final db = await _database;
    for (final e in nouveaux) {
      final existant = await db.query(
        'evenements',
        where: 'canal = ? AND type = ? AND source_horodatage_ms = ?',
        whereArgs: [canal, e.type, e.horodatageMs],
        limit: 1,
      );
      if (existant.isNotEmpty) continue;
      await _enregistrer(canal, e.type, e.valeur, sourceHorodatageMs: e.horodatageMs);
    }
  }

  Future<List<EvenementLocal>> pourCanal(int canal) async {
    final db = await _database;
    final lignes = await db.query(
      'evenements',
      where: 'canal = ?',
      whereArgs: [canal],
      orderBy: 'horodatage DESC',
    );
    return lignes.map(EvenementLocal.fromMap).toList();
  }

  Future<List<EvenementLocal>> tous() async {
    final db = await _database;
    final lignes = await db.query('evenements', orderBy: 'horodatage DESC');
    return lignes.map(EvenementLocal.fromMap).toList();
  }

  Future<double> totalRechargeGlobal() async {
    final db = await _database;
    final resultat = await db.rawQuery(
      "SELECT COALESCE(SUM(valeur), 0) as total FROM evenements WHERE type = 'recharge'",
    );
    return (resultat.first['total'] as num).toDouble();
  }

  Future<void> toutEffacer() async {
    final db = await _database;
    await db.delete('evenements');
  }
}
