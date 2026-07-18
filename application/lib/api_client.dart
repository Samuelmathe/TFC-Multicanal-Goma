import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

// Client HTTP vers le serveur API embarque de l'ESP32 (cf. memoire S2.9/S2.10).
// baseUrl est modifiable depuis l'ecran d'accueil : mets l'IP de l'ESP32
// (192.168.4.1 par defaut sur le point d'acces) ou l'IP de ton PC si tu
// testes avec le firmware lance ailleurs.
class ApiClient {
  final String baseUrl;
  static const String adminUser = "bailleur";
  static const String adminPass = "bailleur2026"; // cf. config.h du firmware

  ApiClient(this.baseUrl);

  Map<String, String> get _headersAdmin {
    final creds = base64Encode(utf8.encode('$adminUser:$adminPass'));
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

  Future<void> recharger(int canal, double montant) async {
    final uri = Uri.parse('$baseUrl/api/recharge?canal=$canal&montant=$montant');
    final reponse = await http
        .get(uri, headers: _headersAdmin)
        .timeout(const Duration(seconds: 5));
    if (reponse.statusCode != 200) {
      throw Exception('Recharge refusee : ${reponse.statusCode}');
    }
  }
}
