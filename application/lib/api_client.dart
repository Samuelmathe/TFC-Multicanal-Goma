import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

// Client HTTP vers le serveur API embarque de l'ESP32 (cf. memoire S2.9/S2.10).
// baseUrl est saisi sur l'ecran de connexion : mets l'IP de l'ESP32
// (192.168.4.1 par defaut sur le point d'acces) ou l'IP de ton PC si tu
// testes avec le firmware lance ailleurs.
//
// username/password sont ceux saisis a la connexion (un couple par canal,
// cf. CANAL_USER/CANAL_PASSWORD dans config.h du firmware) : ils sont
// renvoyes en HTTP Basic Auth sur chaque appel protege. Le canal 0 (bailleur)
// a acces a tous les canaux ; les autres n'ont acces qu'au leur (verifie
// cote ESP32, jamais uniquement cote app).
class ApiClient {
  final String baseUrl;
  final String username;
  final String password;

  ApiClient(this.baseUrl, {required this.username, required this.password});

  Map<String, String> get _headersAuth {
    final creds = base64Encode(utf8.encode('$username:$password'));
    return {'Authorization': 'Basic $creds'};
  }

  Future<EtatSysteme> fetchEtat() async {
    final uri = Uri.parse('$baseUrl/api/etat');
    final reponse = await http.get(uri).timeout(const Duration(seconds: 5));
    if (reponse.statusCode != 200) {
      throw Exception('Erreur serveur : ${reponse.statusCode}');
    }
    final data = jsonDecode(reponse.body) as Map<String, dynamic>;
    return EtatSysteme.fromJson(data);
  }

  // Verifie les identifiants aupres de l'ESP32 et indique a qui ils
  // correspondent (bailleur ou tel locataire). Utilise par l'ecran de
  // connexion pour router vers le bon ecran.
  Future<IdentiteConnecte> connexion() async {
    final uri = Uri.parse('$baseUrl/api/moi');
    final reponse = await http
        .get(uri, headers: _headersAuth)
        .timeout(const Duration(seconds: 5));
    if (reponse.statusCode == 401) {
      throw Exception('Identifiants incorrects');
    }
    if (reponse.statusCode != 200) {
      throw Exception('Erreur serveur : ${reponse.statusCode}');
    }
    final data = jsonDecode(reponse.body) as Map<String, dynamic>;
    return IdentiteConnecte.fromJson(data);
  }

  Future<void> recharger(int canal, double montant) async {
    final uri = Uri.parse('$baseUrl/api/recharge?canal=$canal&montant=$montant');
    final reponse = await http
        .get(uri, headers: _headersAuth)
        .timeout(const Duration(seconds: 5));
    if (reponse.statusCode != 200) {
      throw Exception('Recharge refusee : ${reponse.statusCode}');
    }
  }

  // Evenements survenus cote firmware pas encore recuperes par une
  // application (cf. config.h/main.cpp - MAX_EVENEMENTS_EN_ATTENTE). Si
  // l'appelant EST le proprietaire de ce canal, l'ESP32 purge sa file apres
  // les avoir renvoyes ; sinon (le bailleur consultant un locataire) c'est
  // une simple consultation, rien n'est purge. A appeler regulierement pour
  // alimenter la base locale (cf. HistoriqueDB.drainerFirmware).
  Future<List<HistoriqueEntree>> nouveauxEvenements(int canal) async {
    final uri = Uri.parse('$baseUrl/api/historique/nouveaux?canal=$canal');
    final reponse = await http
        .get(uri, headers: _headersAuth)
        .timeout(const Duration(seconds: 5));
    if (reponse.statusCode != 200) {
      throw Exception('Evenements indisponibles : ${reponse.statusCode}');
    }
    final data = jsonDecode(reponse.body) as List;
    return data
        .map((e) => HistoriqueEntree.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> couperCanal(int canal) async {
    final uri = Uri.parse('$baseUrl/api/canal/couper?canal=$canal');
    final reponse = await http
        .get(uri, headers: _headersAuth)
        .timeout(const Duration(seconds: 5));
    if (reponse.statusCode != 200) {
      throw Exception('Coupure refusee : ${reponse.statusCode}');
    }
  }

  Future<void> retablirCanal(int canal) async {
    final uri = Uri.parse('$baseUrl/api/canal/retablir?canal=$canal');
    final reponse = await http
        .get(uri, headers: _headersAuth)
        .timeout(const Duration(seconds: 5));
    if (reponse.statusCode != 200) {
      throw Exception('Retablissement refuse : ${reponse.statusCode}');
    }
  }

  // Bailleur uniquement (verifie cote ESP32). Stocke le nom directement sur
  // l'ESP32 (metadonnee de canal, cf. historique_db.dart pour la distinction
  // avec l'historique qui lui est cote application).
  Future<void> definirNomCanal(int canal, String nom) async {
    final uri =
        Uri.parse('$baseUrl/api/canal/nom?canal=$canal&valeur=${Uri.encodeComponent(nom)}');
    final reponse = await http
        .get(uri, headers: _headersAuth)
        .timeout(const Duration(seconds: 5));
    if (reponse.statusCode != 200) {
      throw Exception('Modification du nom refusee : ${reponse.statusCode}');
    }
  }

  // Bailleur uniquement (verifie cote ESP32).
  Future<void> definirTarif(double usdParKwh) async {
    final uri = Uri.parse('$baseUrl/api/tarif?valeur=$usdParKwh');
    final reponse = await http
        .get(uri, headers: _headersAuth)
        .timeout(const Duration(seconds: 5));
    if (reponse.statusCode != 200) {
      throw Exception('Modification du tarif refusee : ${reponse.statusCode}');
    }
  }
}
