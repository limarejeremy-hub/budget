import 'package:flutter/material.dart';

import '../../../core/theme/design_tokens.dart';

/// Badge discret "Prochain cycle" (§3, "Affectation manuelle d'une charge
/// au prochain cycle") — la seule marque visuelle qu'une charge a été
/// reportée budgétairement ; jamais un statut, jamais mêlé au badge de
/// statut existant (`ChargeStatusPresentation`). Réutilisé par la fiche
/// détaillée d'une charge et par sa carte dans la liste "Charges".
class DeferredBadge extends StatelessWidget {
  const DeferredBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.skip_next_rounded, size: 13, color: colorScheme.onSecondaryContainer),
          const SizedBox(width: 4),
          Text('Prochain cycle',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: colorScheme.onSecondaryContainer, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
