import 'dart:async';
import 'package:flutter/material.dart';
import '../api_client.dart';
import '../models.dart';

// Ecran bailleur/administrateur : vue de tous les canaux + recharge,
// cf. memoire S2.9 (profil "bailleur/administrateur").
class AdminScreen extends StatefulWidget {
  final String baseUrl;

  const AdminScreen({super.key, required this.baseUrl});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  late final ApiClient _api;
  Timer? _timer;
  EtatSysteme? _etat;
  String? _erreur;

  final TextEditingController _montantController = TextEditingController();
  int _canalSelectionne = 0;

  @override
  void initState() {
    super.initState();
    _api = ApiClient(widget.baseUrl);
    _rafraichir();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _rafraichir());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _montantController.dispose();
    super.dispose();
  }

  Future<void> _rafraichir() async {
    try {
      final etat = await _api.fetchEtat();
      if (!mounted) return;
      setState(() {
        _etat = etat;
        _erreur = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _erreur = "Connexion impossible : $e");
    }
  }

  Future<void> _envoyerRecharge() async {
    final montant = double.tryParse(_montantController.text);
    if (montant == null || montant <= 0) return;
    try {
      await _api.recharger(_canalSelectionne, montant);
      _montantController.clear();
      await _rafraichir();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Recharge enregistree")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Echec : $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final etat = _etat;
    return Scaffold(
      appBar: AppBar(title: const Text("Vue bailleur / administrateur")),
      body: _erreur != null && etat == null
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_erreur!, style: const TextStyle(color: Colors.red)),
            )
          : etat == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      "Tension secteur : ${etat.tensionSecteurV.toStringAsFixed(1)} V "
                      "| Tarif : ${etat.tarifUsdParKwh.toStringAsFixed(2)} USD/kWh",
                    ),
                    const SizedBox(height: 12),
                    ...etat.canaux.map(_carteCanal),
                    const Divider(height: 32),
                    const Text(
                      "Enregistrer une recharge",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButton<int>(
                      value: _canalSelectionne,
                      items: etat.canaux
                          .map((c) => DropdownMenuItem(
                                value: c.canal,
                                child: Text("Canal ${c.canal} (${c.role})"),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _canalSelectionne = v ?? 0),
                    ),
                    TextField(
                      controller: _montantController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: "Montant (USD)",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _envoyerRecharge,
                      child: const Text("Recharger"),
                    ),
                  ],
                ),
    );
  }

  Widget _carteCanal(CanalEtat c) {
    return Card(
      child: ListTile(
        title: Text("Canal ${c.canal} (${c.role})"),
        subtitle: Text(
          "I=${c.courantA.toStringAsFixed(3)} A  "
          "P=${c.puissanceW.toStringAsFixed(2)} W  "
          "E=${c.energieKWh.toStringAsFixed(5)} kWh  "
          "Credit=${c.creditUSD.toStringAsFixed(4)} USD",
        ),
        trailing: Text(
          c.relaisFerme ? "ALIMENTE" : "COUPE",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: c.relaisFerme ? Colors.green : Colors.red,
          ),
        ),
      ),
    );
  }
}
