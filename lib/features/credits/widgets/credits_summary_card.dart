import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatting/currency_formatter.dart';
import '../../../core/providers/credits_providers.dart';
import '../../../core/routing/app_page_route.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/premium_tap_card.dart';
import '../../../domain/calculations/credit_calculation_service.dart';
import '../../../domain/entities/credit_entity.dart';
import '../credits_page.dart';

const _creditCalculationService = CreditCalculationService();

/// Carte "CRÉDITS" du tableau de bord — capital restant total, mensualités
/// totales, nombre de crédits en cours, crédit se terminant le plus tôt.
/// Cliquable : ouvre la page "Crédits" complète.
class CreditsSummaryCard extends ConsumerWidget {
  const CreditsSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final creditsAsync = ref.watch(creditsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return creditsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, st) => const SizedBox.shrink(),
      data: (credits) {
        final activeCount = _creditCalculationService.activeCount(credits);

        return PremiumTapCard(
          color: Color.alphaBlend(
              CategoryColors.credit.withValues(alpha: 0.08), colorScheme.surfaceContainerHigh),
          borderRadius: BorderRadius.circular(AppRadii.lg),
          onTap: () => Navigator.of(context).push(AppPageRoute(builder: (_) => const CreditsPage())),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                          color: CategoryColors.credit.withValues(alpha: 0.2), shape: BoxShape.circle),
                      child: const Icon(Icons.account_balance_rounded,
                          size: 17, color: CategoryColors.credit),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text('Crédits', style: Theme.of(context).textTheme.titleMedium),
                    ),
                    Icon(Icons.chevron_right_rounded, size: 20, color: colorScheme.onSurfaceVariant),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (activeCount == 0)
                  Text(
                    'Aucun crédit en cours',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  )
                else
                  _CreditsSummaryBody(credits: credits),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CreditsSummaryBody extends StatelessWidget {
  final List<CreditEntity> credits;
  const _CreditsSummaryBody({required this.credits});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final totalCapital = _creditCalculationService.totalRemainingCapital(credits);
    final totalPayments = _creditCalculationService.totalMonthlyPayments(credits);
    final activeCount = _creditCalculationService.activeCount(credits);
    final earliest = _creditCalculationService.earliestEnding(credits);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoRow(label: 'Capital restant', value: formatCentsAsEuro(totalCapital)),
        _InfoRow(label: 'Mensualités', value: '${formatCentsAsEuro(totalPayments)}/mois'),
        _InfoRow(label: activeCount > 1 ? 'Crédits' : 'Crédit', value: '$activeCount'),
        if (earliest != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              'Prochain terminé : ${earliest.name} — ${earliest.remainingInstallments} mois',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
          ),
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
