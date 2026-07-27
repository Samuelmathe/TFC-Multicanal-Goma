import 'package:flutter/material.dart';
import '../historique_db.dart';
import '../temps.dart';

// Liste d'historique reutilisable : embarquee en onglet dans CanalDetailScreen
// (canal precis) et dans l'onglet "Resume" du bailleur (canal = null -> tous
// les canaux, avec le numero de canal affiche sur chaque ligne). Lit
// exclusivement la base SQLite locale (cf. historique_db.dart) - jamais le
// firmware, qui ne conserve pas d'historique.
class HistoriqueListe extends StatefulWidget {
  final int? canal;

  const HistoriqueListe({super.key, this.canal});

  @override
  State<HistoriqueListe> createState() => _HistoriqueListeState();
}

class _HistoriqueListeState extends State<HistoriqueListe>
    with AutomaticKeepAliveClientMixin {
  List<EvenementLocal>? _entrees;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final entrees = widget.canal == null
        ? await HistoriqueDB.instance.tous()
        : await HistoriqueDB.instance.pourCanal(widget.canal!);
    if (!mounted) return;
    setState(() => _entrees = entrees);
  }

  IconData _icone(String type) {
    switch (type) {
      case 'recharge':
        return Icons.add_card_rounded;
      case 'coupure_credit':
        return Icons.money_off_rounded;
      case 'coupure_volontaire':
        return Icons.pause_circle_outline_rounded;
      case 'retablissement':
        return Icons.check_circle_outline_rounded;
      default:
        return Icons.circle_rounded;
    }
  }

  Color _couleur(String type, ColorScheme colorScheme) {
    switch (type) {
      case 'recharge':
        return Colors.teal;
      case 'coupure_credit':
      case 'coupure_volontaire':
        return Colors.red;
      case 'retablissement':
        return Colors.green;
      default:
        return colorScheme.onSurfaceVariant;
    }
  }

  String _dateLisible(int epochMs) {
    final d = DateTime.fromMillisecondsSinceEpoch(epochMs);
    String deux(int n) => n.toString().padLeft(2, '0');
    return "${deux(d.day)}/${deux(d.month)} ${deux(d.hour)}:${deux(d.minute)}";
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colorScheme = Theme.of(context).colorScheme;
    final entrees = _entrees;

    if (entrees == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (entrees.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history_toggle_off_rounded,
                  size: 36, color: colorScheme.onSurfaceVariant),
              const SizedBox(height: 12),
              Text(
                "Aucun evenement enregistre pour l'instant",
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    final maintenant = DateTime.now().millisecondsSinceEpoch;

    return RefreshIndicator(
      onRefresh: _charger,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: entrees.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final e = entrees[i];
          final couleur = _couleur(e.type, colorScheme);
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: couleur.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_icone(e.type), size: 18, color: couleur),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.canal == null
                                  ? "${e.libelle} - canal ${e.canal}"
                                  : e.libelle,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${_dateLisible(e.horodatage)} · ${ilYA(e.horodatage, maintenant)}",
                        style: TextStyle(
                          fontSize: 11.5,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (e.type == 'recharge')
                  Text(
                    "+${e.valeur.toStringAsFixed(2)} \$",
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.teal,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
