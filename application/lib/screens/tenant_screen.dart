import 'dart:async';
import 'package:flutter/material.dart';
import '../api_client.dart';
import '../models.dart';

// Ecran locataire : lecture seule, cf. memoire S2.9 (profil "locataire").
class TenantScreen extends StatefulWidget {
  final String baseUrl;
  final int canalIndex;

  const TenantScreen({
    super.key,
    required this.baseUrl,
    required this.canalIndex,
  });

  @override
  State<TenantScreen> createState() => _TenantScreenState();
}

class _TenantScreenState extends State<TenantScreen> {
  late final ApiClient _api;
  Timer? _timer;
  CanalEtat? _canal;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _api = ApiClient(widget.baseUrl);
    _rafraichir();
    // Timer.periodic = l'equivalent de setInterval() en JavaScript.
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _rafraichir());
  }

  @override
  void dispose() {
    _timer?.cancel(); // toujours annuler un Timer quand l'ecran se ferme
    super.dispose();
  }

  Future<void> _rafraichir() async {
    try {
      final etat = await _api.fetchEtat();
      final canal = etat.canaux.firstWhere(
        (c) => c.canal == widget.canalIndex,
      );
      if (!mounted) return; // l'ecran a peut-etre ete ferme entre-temps
      setState(() {
        _canal = canal;
        _erreur = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _erreur = "Connexion impossible : $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _canal;
    return Scaffold(
      appBar: AppBar(title: Text("Canal ${widget.canalIndex}")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _erreur != null
            ? Text(_erreur!, style: const TextStyle(color: Colors.red))
            : c == null
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.role == "bailleur" ? "Bailleur" : "Locataire",
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 16),
                      _Ligne("Statut", c.relaisFerme ? "ALIMENTE" : "COUPE",
                          couleur: c.relaisFerme ? Colors.green : Colors.red),
                      _Ligne("Credit restant",
                          "${c.creditUSD.toStringAsFixed(4)} USD"),
                      _Ligne("Puissance instantanee",
                          "${c.puissanceW.toStringAsFixed(2)} W"),
                      _Ligne("Energie cumulee",
                          "${c.energieKWh.toStringAsFixed(5)} kWh"),
                      _Ligne("Dernier evenement", c.dernierEvenement),
                    ],
                  ),
      ),
    );
  }
}

class _Ligne extends StatelessWidget {
  final String label;
  final String valeur;
  final Color? couleur;

  const _Ligne(this.label, this.valeur, {this.couleur});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            valeur,
            style: TextStyle(fontWeight: FontWeight.bold, color: couleur),
          ),
        ],
      ),
    );
  }
}
