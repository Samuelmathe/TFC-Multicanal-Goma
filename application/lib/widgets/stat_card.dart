import 'package:flutter/material.dart';
import '../design_tokens.dart';

// Carte "icone + libelle + valeur", remplace les 4 widgets quasi identiques
// qui avaient fini par diverger legerement (_StatChip, _CarteResume,
// _CarteSolde, _CarteStat - cf. critique design S3) : meme structure visuelle
// partout, une seule source a maintenir.
class StatCard extends StatelessWidget {
  final IconData icone;
  final String label;
  final String valeur;
  final String? unite;
  // null = style neutre (fond surfaceContainerHigh, icone primary) ; une
  // couleur = style teinte (fond + bordure a 10-25% d'opacite, icone et
  // valeur dans cette couleur), utilise pour les grandeurs qu'on veut
  // distinguer visuellement les unes des autres (puissance, courant, ...).
  final Color? couleur;

  const StatCard({
    super.key,
    required this.icone,
    required this.label,
    required this.valeur,
    this.unite,
    this.couleur,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = couleur ?? colorScheme.primary;
    final teinte = couleur != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: teinte
            ? accent.withValues(alpha: 0.10)
            : colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.l),
        border: teinte ? Border.all(color: accent.withValues(alpha: 0.25)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icone, size: 18, color: accent),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: AppTextSize.label,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          if (unite != null)
            // FittedBox : protege aussi bien les cartes solde (2 colonnes
            // pleine largeur) que la grille 2x2 (cellules etroites) contre
            // un debordement si la valeur est longue ou la police systeme
            // agrandie - cf. le meme risque deja identifie pour _CarteStat.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    valeur,
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800, color: accent),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    unite!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          else
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                valeur,
                style: TextStyle(
                  fontSize: AppTextSize.value,
                  fontWeight: FontWeight.w800,
                  color: teinte ? accent : colorScheme.onSurface,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
