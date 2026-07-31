import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatting/currency_formatter.dart';
import '../../../core/providers/credits_providers.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/staggered_fade_in.dart';
import '../../../domain/calculations/credit_calculation_service.dart';

const _creditCalculationService = CreditCalculationService();

/// Encart discret du tableau de bord : suggère, sans jamais l'imposer, le
/// crédit actif le plus proche d'être soldé (capital restant le plus
/// faible). Invisible s'il n'y a aucun crédit actif — jamais d'espace vide
/// résiduel.
class CreditAdviceCard extends ConsumerWidget {
  const CreditAdviceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final creditsAsync = ref.watch(creditsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return creditsAsync.maybeWhen(
      data: (credits) {
        final target = _creditCalculationService.lowestRemainingCapitalCredit(credits);
        if (target == null || target.remainingCapitalCents <= 0) return const SizedBox.shrink();

        return StaggeredFadeIn(
          index: 0,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                  CategoryColors.credit.withValues(alpha: 0.08), colorScheme.surfaceContainerHigh),
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('💡', style: TextStyle(fontSize: 20)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Objectif conseillé',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Encore ${formatCentsAsEuro(target.remainingCapitalCents)} pour solder ${target.name}. '
                        'Tu récupéreras ${formatCentsAsEuro(target.monthlyPaymentCents)}/mois dans '
                        '${target.remainingInstallments} mois.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
