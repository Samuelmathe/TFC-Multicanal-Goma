import 'dart:async';
import 'package:flutter/material.dart';
import '../api_client.dart';
import '../historique_db.dart';
import '../models.dart';
import 'canal_detail_screen.dart';
import 'historique_liste.dart';

// Ecran d'accueil du bailleur, en 3 onglets :
//  - Canaux : vue compacte (statut seulement), le detail d'un locataire ne
//    s'ouvre qu'apres avoir appuye sur "Voir".
//  - Resume : vision globale (revenus cumules, consommation par canal).
//  - Reglages : tarif (1 USD = X kWh), modifiable uniquement ici.
class BailleurHomeScreen extends StatefulWidget {
  final String baseUrl;
  final String username;
  final String password;

  const BailleurHomeScreen({
    super.key,
    required this.baseUrl,
    required this.username,
    required this.password,
  });

  @override
  State<BailleurHomeScreen> createState() => _BailleurHomeScreenState();
}

class _BailleurHomeScreenState extends State<BailleurHomeScreen> {
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
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _rafraichir());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _rafraichir() async {
    try {
      final etat = await _api.fetchEtat();
      // Le bailleur voit tous les canaux : on draine celui du bailleur
      // (purge, c'est le sien) et on consulte ceux des locataires sans les
      // purger (cf. drainerFirmware/route /api/historique/nouveaux), pour
      // alimenter l'onglet Resume sans jamais voler un evenement que le
      // locataire concerne n'a pas encore recupere lui-meme.
      for (final c in etat.canaux) {
        unawaited(HistoriqueDB.instance.drainerFirmware(_api, c.canal));
      }
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

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Espace bailleur"),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.electric_meter_rounded), text: "Canaux"),
              Tab(icon: Icon(Icons.insights_rounded), text: "Resume"),
              Tab(icon: Icon(Icons.tune_rounded), text: "Reglages"),
            ],
          ),
        ),
        body: SafeArea(
          child: _erreur != null && etat == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.wifi_off_rounded,
                            size: 40, color: colorScheme.error),
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
                  : TabBarView(
                      children: [
                        _ongletCanaux(etat),
                        _OngletResume(etat: etat),
                        _OngletReglages(etat: etat, api: _api, onTarifChange: _rafraichir),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _ongletCanaux(EtatSysteme etat) {
    final colorScheme = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: _rafraichir,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(
                child: _StatChip(
                  icone: Icons.bolt_rounded,
                  label: "Tension secteur",
                  valeur: "${etat.tensionSecteurV.toStringAsFixed(1)} V",
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatChip(
                  icone: Icons.payments_rounded,
                  label: "Tarif",
                  valeur: "1\$ = ${etat.kwhParDollar.toStringAsFixed(2)} kWh",
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            "Canaux",
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          ...etat.canaux.map((c) => _LigneCanal(
                canal: c,
                onVoir: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CanalDetailScreen(
                        baseUrl: widget.baseUrl,
                        username: widget.username,
                        password: widget.password,
                        canal: c.canal,
                        modeBailleur: true,
                      ),
                    ),
                  ).then((_) => _rafraichir());
                },
              )),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Onglet Resume : vision globale (revenus cumules depuis la base locale +
// comparaison de consommation par canal). Fonctionnalite additionnelle,
// construite entierement a partir des donnees deja disponibles.
// ---------------------------------------------------------------------------
class _OngletResume extends StatefulWidget {
  final EtatSysteme etat;

  const _OngletResume({required this.etat});

  @override
  State<_OngletResume> createState() => _OngletResumeState();
}

class _OngletResumeState extends State<_OngletResume> {
  double? _totalRecharge;

  @override
  void initState() {
    super.initState();
    _chargerTotal();
  }

  @override
  void didUpdateWidget(covariant _OngletResume oldWidget) {
    super.didUpdateWidget(oldWidget);
    _chargerTotal();
  }

  Future<void> _chargerTotal() async {
    final total = await HistoriqueDB.instance.totalRechargeGlobal();
    if (!mounted) return;
    setState(() => _totalRecharge = total);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final etat = widget.etat;
    final puissanceTotale =
        etat.canaux.fold<double>(0, (somme, c) => somme + c.puissanceW);
    final energieMax = etat.canaux
        .map((c) => c.energieKWh)
        .fold<double>(0.0001, (m, v) => v > m ? v : m);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _CarteResume(
                  icone: Icons.savings_rounded,
                  label: "Total recharge (tous canaux)",
                  valeur: _totalRecharge == null
                      ? "..."
                      : "${_totalRecharge!.toStringAsFixed(2)} \$",
                  couleur: Colors.teal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CarteResume(
                  icone: Icons.flash_on_rounded,
                  label: "Puissance totale instantanee",
                  valeur: "${puissanceTotale.toStringAsFixed(1)} W",
                  couleur: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            "Consommation cumulee par canal",
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: etat.canaux
                  .map((c) => _BarreCanal(canal: c, maxKWh: energieMax))
                  .toList(),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "Activite recente (tous canaux)",
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 320,
            child: const HistoriqueListe(),
          ),
        ],
      ),
    );
  }
}

class _BarreCanal extends StatelessWidget {
  final CanalEtat canal;
  final double maxKWh;

  const _BarreCanal({required this.canal, required this.maxKWh});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final ratio = (canal.energieKWh / maxKWh).clamp(0.0, 1.0);
    final estBailleur = canal.canal == 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  canal.libelleAffiche(estBailleur),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                ),
              ),
              Text(
                "${canal.energieKWh.toStringAsFixed(3)} kWh",
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    Container(
                      height: 10,
                      width: constraints.maxWidth,
                      color: colorScheme.surfaceContainerHighest,
                    ),
                    Container(
                      height: 10,
                      width: constraints.maxWidth * ratio,
                      color: colorScheme.primary,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CarteResume extends StatelessWidget {
  final IconData icone;
  final String label;
  final String valeur;
  final Color couleur;

  const _CarteResume({
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
        color: couleur.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: couleur.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 20, color: couleur),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            valeur,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: couleur),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Onglet Reglages : tarif (1 USD = X kWh), la seule chose modifiable par le
// bailleur en dehors des recharges par canal.
// ---------------------------------------------------------------------------
class _OngletReglages extends StatefulWidget {
  final EtatSysteme etat;
  final ApiClient api;
  final VoidCallback onTarifChange;

  const _OngletReglages({
    required this.etat,
    required this.api,
    required this.onTarifChange,
  });

  @override
  State<_OngletReglages> createState() => _OngletReglagesState();
}

class _OngletReglagesState extends State<_OngletReglages> {
  late final TextEditingController _controller;
  bool _enCours = false;

  @override
  void initState() {
    super.initState();
    _controller =
        TextEditingController(text: widget.etat.kwhParDollar.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    final v = double.tryParse(_controller.text);
    if (v == null || v <= 0) return;
    setState(() => _enCours = true);
    try {
      await widget.api.definirTarif(1.0 / v);
      widget.onTarifChange();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Tarif mis a jour")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Echec : $e")));
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                    Icon(Icons.payments_rounded, size: 18, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      "Tarif de conversion",
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
                  "Combien de kWh vaut 1 dollar recharge. S'applique immediatement "
                  "a tous les canaux.",
                  style: TextStyle(fontSize: 12.5, color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    prefixText: "1 USD = ",
                    suffixText: "kWh",
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _enCours ? null : _enregistrer,
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text("Enregistrer"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LigneCanal extends StatelessWidget {
  final CanalEtat canal;
  final VoidCallback onVoir;

  const _LigneCanal({required this.canal, required this.onVoir});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final estBailleur = canal.canal == 0;
    final Color couleurStatut;
    final String libelleStatut;
    if (canal.relaisFerme) {
      couleurStatut = Colors.green;
      libelleStatut = "ALIMENTE";
    } else if (canal.coupureVolontaire) {
      couleurStatut = Colors.orange;
      libelleStatut = "COUPE (volontaire)";
    } else {
      couleurStatut = Colors.red;
      libelleStatut = "COUPE (credit)";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              estBailleur ? Icons.key_rounded : Icons.electric_meter_rounded,
              size: 20,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  canal.libelleAffiche(estBailleur),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: couleurStatut.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    libelleStatut,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 10.5,
                      color: couleurStatut,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: onVoir,
            icon: const Icon(Icons.visibility_rounded, size: 16),
            label: const Text("Voir"),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icone;
  final String label;
  final String valeur;

  const _StatChip({
    required this.icone,
    required this.label,
    required this.valeur,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icone, size: 15, color: colorScheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            valeur,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
