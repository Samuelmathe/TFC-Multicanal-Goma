import 'package:flutter/material.dart';
import '../historique_db.dart';

// Graphique en barres de la consommation par jour/semaine/mois pour un
// canal, a partir des releves periodiques enregistres localement (cf.
// HistoriqueDB.enregistrerReleveSiUtile/consommationParPeriode). Comme la
// maquette ne tourne que depuis peu, les premieres periodes seront creuses -
// le graphique se remplit au fur et a mesure de l'usage reel.
class GraphiqueConsommation extends StatefulWidget {
  final int canal;

  const GraphiqueConsommation({super.key, required this.canal});

  @override
  State<GraphiqueConsommation> createState() => _GraphiqueConsommationState();
}

class _GraphiqueConsommationState extends State<GraphiqueConsommation>
    with AutomaticKeepAliveClientMixin {
  Granularite _granularite = Granularite.jour;
  List<PointConsommation>? _points;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final points = await HistoriqueDB.instance
        .consommationParPeriode(widget.canal, _granularite);
    if (!mounted) return;
    setState(() => _points = points);
  }

  void _changerGranularite(Granularite g) {
    setState(() {
      _granularite = g;
      _points = null;
    });
    _charger();
  }

  // "2026-07-26" -> "26/07" ; "2026-30" (annee-semaine) -> "S30" ; "2026-07" -> "07/2026"
  String _libelleBucket(String bucket) {
    final parties = bucket.split('-');
    switch (_granularite) {
      case Granularite.jour:
        if (parties.length == 3) return "${parties[2]}/${parties[1]}";
        return bucket;
      case Granularite.semaine:
        if (parties.length == 2) return "S${parties[1]}";
        return bucket;
      case Granularite.mois:
        if (parties.length == 2) return "${parties[1]}/${parties[0]}";
        return bucket;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colorScheme = Theme.of(context).colorScheme;
    final points = _points;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<Granularite>(
            segments: const [
              ButtonSegment(value: Granularite.jour, label: Text("Jour")),
              ButtonSegment(value: Granularite.semaine, label: Text("Semaine")),
              ButtonSegment(value: Granularite.mois, label: Text("Mois")),
            ],
            selected: {_granularite},
            onSelectionChanged: (s) => _changerGranularite(s.first),
          ),
          const SizedBox(height: 24),
          if (points == null)
            const Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (points.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Column(
                children: [
                  Icon(Icons.bar_chart_rounded, size: 36, color: colorScheme.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text(
                    "Pas encore assez de donnees pour cette periode.\n"
                    "Le graphique se remplit au fil de l'utilisation.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            )
          else
            _Barres(points: points, libelle: _libelleBucket, couleur: colorScheme.primary),
        ],
      ),
    );
  }
}

class _Barres extends StatelessWidget {
  final List<PointConsommation> points;
  final String Function(String) libelle;
  final Color couleur;

  const _Barres({required this.points, required this.libelle, required this.couleur});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final maxKwh = points.map((p) => p.kwh).fold<double>(0.0001, (m, v) => v > m ? v : m);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: SizedBox(
        height: 220,
        // stretch est essentiel ici : sans lui, chaque colonne recoit une
        // hauteur non bornee et la barre (FractionallySizedBox) a l'interieur
        // ne peut pas calculer sa hauteur relative - elle disparait
        // silencieusement en release (pas d'erreur visible, juste rien
        // affiche), d'ou le bug observe (rectangle gris totalement vide).
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: points.map((p) {
            final hauteurRatio = (p.kwh / maxKwh).clamp(0.02, 1.0);
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  children: [
                    Text(
                      p.kwh >= 0.01 ? p.kwh.toStringAsFixed(2) : "",
                      style: TextStyle(fontSize: 9.5, color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: hauteurRatio,
                          child: Container(
                            decoration: BoxDecoration(
                              color: couleur,
                              borderRadius:
                                  const BorderRadius.vertical(top: Radius.circular(6)),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      libelle(p.bucket),
                      style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
