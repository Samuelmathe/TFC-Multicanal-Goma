import 'dart:async';
import 'package:flutter/material.dart';
import '../api_client.dart';
import '../models.dart';

// Ecran technicien/electricien : grandeurs electriques brutes de tous les
// canaux (courant, puissance active, cos phi), lecture seule - pas de
// gestion de credit ni de coupure, role different du bailleur. La tension
// secteur est commune a tous les canaux (un seul capteur ZMPT101B, cf.
// S1.3.2) et affichee une seule fois en haut.
class ElectricienScreen extends StatefulWidget {
  final String baseUrl;
  final String username;
  final String password;

  const ElectricienScreen({
    super.key,
    required this.baseUrl,
    required this.username,
    required this.password,
  });

  @override
  State<ElectricienScreen> createState() => _ElectricienScreenState();
}

class _ElectricienScreenState extends State<ElectricienScreen> {
  late final ApiClient _api;
  Timer? _timer;
  EtatSysteme? _etat;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _api = ApiClient(widget.baseUrl,
        username: widget.username, password: widget.password);
    _rafraichir();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _rafraichir());
  }

  @override
  void dispose() {
    _timer?.cancel();
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

  @override
  Widget build(BuildContext context) {
    final etat = _etat;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text("Diagnostic electrique")),
      body: SafeArea(
        child: _erreur != null && etat == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.wifi_off_rounded, size: 40, color: colorScheme.error),
                      const SizedBox(height: 16),
                      Text(
                        _erreur!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colorScheme.error),
                      ),
                    ],
                  ),
                ),
              )
            : etat == null
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _rafraichir,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                colorScheme.primary.withValues(alpha: 0.16),
                                colorScheme.primary.withValues(alpha: 0.06),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: colorScheme.primary.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.bolt_rounded, size: 26, color: colorScheme.primary),
                              const SizedBox(width: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Tension secteur (commune)",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    "${etat.tensionSecteurV.toStringAsFixed(1)} V",
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          "Detail par canal",
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...etat.canaux.map((c) => _LigneDiagnostic(canal: c)),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                            border:
                                Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline_rounded,
                                  size: 18, color: Colors.amber),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  "Sur cette maquette (potentiometres), cos(phi) est "
                                  "fixe a 1 par simplification : il n'y a pas de forme "
                                  "d'onde alternative reelle a echantillonner. Avec les "
                                  "capteurs ACS712/ZMPT101B reels, cos(phi) est calcule, "
                                  "pas suppose (cf. rapport S1.3.3/S2.7).",
                                  style: TextStyle(
                                      fontSize: 11.5, color: colorScheme.onSurfaceVariant),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _LigneDiagnostic extends StatelessWidget {
  final CanalEtat canal;

  const _LigneDiagnostic({required this.canal});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final estBailleur = canal.canal == 0;
    final couleurStatut = canal.relaisFerme ? Colors.green : Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  estBailleur ? Icons.key_rounded : Icons.electric_meter_rounded,
                  size: 18,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  canal.libelleAffiche(estBailleur),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                ),
              ),
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: couleurStatut, shape: BoxShape.circle),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _Mesure(
                  label: "Courant",
                  valeur: "${canal.courantA.toStringAsFixed(3)} A",
                  icone: Icons.speed_rounded,
                  couleur: Colors.purple,
                ),
              ),
              Expanded(
                child: _Mesure(
                  label: "Puissance active",
                  valeur: "${canal.puissanceW.toStringAsFixed(2)} W",
                  icone: Icons.flash_on_rounded,
                  couleur: Colors.orange,
                ),
              ),
              Expanded(
                child: _Mesure(
                  label: "cos(phi)",
                  valeur: canal.cosPhi.toStringAsFixed(2),
                  icone: Icons.show_chart_rounded,
                  couleur: Colors.indigo,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Mesure extends StatelessWidget {
  final String label;
  final String valeur;
  final IconData icone;
  final Color couleur;

  const _Mesure({
    required this.label,
    required this.valeur,
    required this.icone,
    required this.couleur,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icone, size: 13, color: couleur),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          valeur,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
