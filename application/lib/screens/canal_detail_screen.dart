import 'dart:async';
import 'package:flutter/material.dart';
import '../api_client.dart';
import '../historique_db.dart';
import '../models.dart';
import 'graphique_consommation.dart';
import 'historique_liste.dart';

class _Echantillon {
  final DateTime instant;
  final double energieKWh;
  _Echantillon(this.instant, this.energieKWh);
}

// Ecran detail d'un canal - utilise a la fois par le locataire (son propre
// canal, modeBailleur=false) et par le bailleur (apres avoir choisi un
// locataire depuis BailleurHomeScreen, modeBailleur=true : ajoute le
// formulaire de recharge). Deux onglets : Apercu et Historique (cf. S2.9/S2.10).
class CanalDetailScreen extends StatefulWidget {
  final String baseUrl;
  final String username;
  final String password;
  final int canal;
  final bool modeBailleur;

  const CanalDetailScreen({
    super.key,
    required this.baseUrl,
    required this.username,
    required this.password,
    required this.canal,
    required this.modeBailleur,
  });

  @override
  State<CanalDetailScreen> createState() => _CanalDetailScreenState();
}

class _CanalDetailScreenState extends State<CanalDetailScreen> {
  late final ApiClient _api;
  Timer? _timer;
  EtatSysteme? _etat;
  CanalEtat? _canal;
  String? _erreur;
  bool _actionEnCours = false;

  final _montantController = TextEditingController();
  final _nomController = TextEditingController();
  final List<_Echantillon> _echantillonsEnergie = [];

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
    _montantController.dispose();
    _nomController.dispose();
    super.dispose();
  }

  Future<void> _rafraichir() async {
    try {
      final etat = await _api.fetchEtat();
      final canal = etat.canaux.firstWhere((c) => c.canal == widget.canal);
      unawaited(HistoriqueDB.instance.drainerFirmware(_api, widget.canal));
      unawaited(HistoriqueDB.instance
          .enregistrerReleveSiUtile(widget.canal, canal.energieKWh));
      if (!mounted) return;
      final premierChargement = _canal == null;
      setState(() {
        _etat = etat;
        _canal = canal;
        _erreur = null;
      });
      if (premierChargement) _nomController.text = canal.nomAffiche;
      _enregistrerEchantillon(canal);
    } catch (e) {
      if (!mounted) return;
      setState(() => _erreur = "Connexion impossible : $e");
    }
  }

  Future<void> _enregistrerNom() async {
    try {
      await _api.definirNomCanal(widget.canal, _nomController.text.trim());
      await _rafraichir();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Nom mis a jour")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Echec : $e")));
    }
  }

  // Garde une petite fenetre glissante (15 minutes) d'echantillons d'energie
  // cumulee pour estimer le rythme de consommation recent - cf. _estimation().
  void _enregistrerEchantillon(CanalEtat c) {
    if (!c.relaisFerme) return; // pas de consommation reelle canal coupe
    final maintenant = DateTime.now();
    _echantillonsEnergie.add(_Echantillon(maintenant, c.energieKWh));
    _echantillonsEnergie.removeWhere(
      (e) => maintenant.difference(e.instant) > const Duration(minutes: 15),
    );
  }

  // Estimation du temps restant avant coupure, a partir du rythme de
  // consommation observe sur les dernieres minutes (pas juste la puissance
  // instantanee, plus stable). Fonctionnalite additionnelle : rien de tel
  // n'existe cote firmware, calculee entierement dans l'app a partir des
  // echantillons deja recus.
  String? _estimation(CanalEtat c) {
    if (!c.relaisFerme) return null;
    if (_echantillonsEnergie.length < 3) return null;
    final premier = _echantillonsEnergie.first;
    final dernier = _echantillonsEnergie.last;
    final dureeH =
        dernier.instant.difference(premier.instant).inSeconds / 3600.0;
    if (dureeH <= 0) return null;
    final deltaKWh = dernier.energieKWh - premier.energieKWh;
    final rythmeKWhParH = deltaKWh / dureeH;
    if (rythmeKWhParH <= 0.0001) return "Consommation quasi nulle - credit stable";
    final heuresRestantes = c.creditKWh / rythmeKWhParH;
    if (heuresRestantes > 48) {
      final jours = (heuresRestantes / 24).round();
      return "Environ $jours jours restants au rythme actuel";
    }
    if (heuresRestantes >= 1) {
      final h = heuresRestantes.floor();
      final min = ((heuresRestantes - h) * 60).round();
      return "Environ ${h}h${min.toString().padLeft(2, '0')} restantes au rythme actuel";
    }
    final min = (heuresRestantes * 60).round();
    return "Environ $min min restantes au rythme actuel";
  }

  Future<void> _basculerCoupure() async {
    final c = _canal;
    if (c == null || _actionEnCours) return;
    setState(() => _actionEnCours = true);
    try {
      if (c.coupureVolontaire) {
        await _api.retablirCanal(widget.canal);
      } else {
        await _api.couperCanal(widget.canal);
      }
      await _rafraichir();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Echec : $e")));
    } finally {
      if (mounted) setState(() => _actionEnCours = false);
    }
  }

  Future<void> _envoyerRecharge() async {
    final montant = double.tryParse(_montantController.text);
    if (montant == null || montant <= 0) return;
    try {
      await _api.recharger(widget.canal, montant);
      _montantController.clear();
      // _rafraichir() declenche drainerFirmware(), qui recuperera l'evenement
      // "recharge" (avec le montant exact) mis en file par le firmware.
      await _rafraichir();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Recharge enregistree")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Echec : $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _canal;
    final etat = _etat;
    final estBailleurCanal = widget.canal == 0;

    final titre = c == null
        ? (estBailleurCanal ? "Bailleur" : "Locataire ${widget.canal}")
        : c.libelleAffiche(estBailleurCanal);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(titre),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.dashboard_rounded), text: "Apercu"),
              Tab(icon: Icon(Icons.bar_chart_rounded), text: "Graphique"),
              Tab(icon: Icon(Icons.history_rounded), text: "Historique"),
            ],
          ),
        ),
        body: SafeArea(
          child: _erreur != null && c == null
              ? _ErreurConnexion(message: _erreur!)
              : c == null || etat == null
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      children: [
                        _onglertApercu(context, c, etat, estBailleurCanal),
                        GraphiqueConsommation(canal: widget.canal),
                        HistoriqueListe(canal: widget.canal),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _onglertApercu(
      BuildContext context, CanalEtat c, EtatSysteme etat, bool estBailleurCanal) {
    final colorScheme = Theme.of(context).colorScheme;
    final estimation = _estimation(c);

    return RefreshIndicator(
      onRefresh: _rafraichir,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StatutBandeau(canal: c),
            const SizedBox(height: 20),

            // -- Solde : kWh restants + equivalent dollars, cote a cote --
            Row(
              children: [
                Expanded(
                  child: _CarteSolde(
                    icone: Icons.bolt_rounded,
                    label: "kWh restants",
                    valeur: c.creditKWh.toStringAsFixed(2),
                    unite: "kWh",
                    couleur: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CarteSolde(
                    icone: Icons.attach_money_rounded,
                    label: "Equivalent",
                    valeur: c.creditUSD.toStringAsFixed(2),
                    unite: "USD",
                    couleur: Colors.teal,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4),
              child: Text(
                "Tarif : 1 USD = ${etat.kwhParDollar.toStringAsFixed(2)} kWh",
                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
              ),
            ),

            if (estimation != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.insights_rounded, size: 18, color: Colors.amber),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        estimation,
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 1.25,
              children: [
                _CarteStat(
                  icone: Icons.flash_on_rounded,
                  label: "Puissance instantanee",
                  valeur: "${c.puissanceW.toStringAsFixed(2)}\nW",
                  couleur: Colors.orange,
                ),
                _CarteStat(
                  icone: Icons.speed_rounded,
                  label: "Courant",
                  valeur: "${c.courantA.toStringAsFixed(3)}\nA",
                  couleur: Colors.purple,
                ),
                _CarteStat(
                  icone: Icons.stacked_line_chart_rounded,
                  label: "Energie cumulee",
                  valeur: "${c.energieKWh.toStringAsFixed(5)}\nkWh",
                  couleur: Colors.indigo,
                ),
                _CarteStat(
                  icone: Icons.bolt_rounded,
                  label: "Tension secteur",
                  valeur: "${etat.tensionSecteurV.toStringAsFixed(1)}\nV",
                  couleur: Colors.blueGrey,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // -- Coupure volontaire (absence, vacances, travail) --
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.power_settings_new_rounded,
                          size: 18, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          estBailleurCanal ? "Couper ce canal" : "Absence / voyage",
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    c.coupureVolontaire
                        ? "Ce canal est coupe volontairement, meme si le credit est suffisant."
                        : "Coupe l'alimentation de ce canal sans perdre le credit restant "
                            "(utile en cas d'absence prolongee, voyage ou journee de travail).",
                    style: TextStyle(fontSize: 12.5, color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _actionEnCours ? null : _basculerCoupure,
                    icon: Icon(c.coupureVolontaire
                        ? Icons.play_circle_outline_rounded
                        : Icons.pause_circle_outline_rounded),
                    label: Text(c.coupureVolontaire
                        ? "Retablir l'alimentation"
                        : "Couper l'alimentation"),
                  ),
                ],
              ),
            ),

            if (widget.modeBailleur) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.badge_rounded, size: 18, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          "Fiche locataire",
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Nom reel affiche a la place de \"${estBailleurCanal ? 'Bailleur' : 'Locataire ${widget.canal}'}\".",
                      style: TextStyle(fontSize: 12.5, color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _nomController,
                      decoration: const InputDecoration(
                        labelText: "Nom",
                        prefixIcon: Icon(Icons.person_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: _enregistrerNom,
                      icon: const Icon(Icons.check_circle_rounded),
                      label: const Text("Enregistrer"),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.add_card_rounded,
                            size: 18, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          "Recharger ce canal",
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _montantController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: "Montant (USD)",
                        prefixIcon: Icon(Icons.attach_money_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: _envoyerRecharge,
                      icon: const Icon(Icons.check_circle_rounded),
                      label: const Text("Recharger"),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatutBandeau extends StatelessWidget {
  final CanalEtat canal;

  const _StatutBandeau({required this.canal});

  @override
  Widget build(BuildContext context) {
    final alimente = canal.relaisFerme;
    final couleur = alimente ? Colors.green : Colors.red;
    final String sousTitre;
    if (alimente) {
      sousTitre = "Alimentation active";
    } else if (canal.coupureVolontaire) {
      sousTitre = "Coupe volontairement";
    } else {
      sousTitre = "Coupe : credit epuise";
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            couleur.withValues(alpha: 0.18),
            couleur.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: couleur.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: couleur.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              alimente ? Icons.check_circle_rounded : Icons.power_off_rounded,
              color: couleur,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                alimente ? "ALIMENTE" : "COUPE",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: couleur,
                ),
              ),
              Text(
                sousTitre,
                style: TextStyle(
                  fontSize: 12.5,
                  color: couleur.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CarteSolde extends StatelessWidget {
  final IconData icone;
  final String label;
  final String valeur;
  final String unite;
  final Color couleur;

  const _CarteSolde({
    required this.icone,
    required this.label,
    required this.valeur,
    required this.unite,
    required this.couleur,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: couleur.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icone, size: 16, color: couleur),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                valeur,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: couleur,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unite,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CarteStat extends StatelessWidget {
  final IconData icone;
  final String label;
  final String valeur;
  final Color couleur;

  const _CarteStat({
    required this.icone,
    required this.label,
    required this.valeur,
    required this.couleur,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: couleur.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icone, size: 18, color: couleur),
          ),
          const Spacer(),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            valeur,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _ErreurConnexion extends StatelessWidget {
  final String message;

  const _ErreurConnexion({required this.message});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 40, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.error),
            ),
          ],
        ),
      ),
    );
  }
}
