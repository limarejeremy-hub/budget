import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatting/currency_formatter.dart';
import '../../../core/providers/credits_providers.dart';
import '../../../core/providers/dashboard_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../domain/calculations/credit_calculation_service.dart';
import '../../../domain/calculations/debt_ratio_bands.dart';
import '../../projects/project_visuals.dart' show debtRatioBandColor;

const _creditCalculationService = CreditCalculationService();

/// Au-delà de ce taux d'épargne, BudgetPilot considère l'effort d'épargne
/// du cycle "confortable" (vert) — un repère interne documenté, jamais un
/// objectif imposé ni un jugement sur un taux plus faible.
const double kGoodSavingsRateRatio = 0.10;

/// "Mes indicateurs" (V1.2, §3) — trois chiffres concrets et compréhensibles
/// sur l'accueil : taux d'épargne, taux d'endettement, dépenses du cycle.
/// Jamais un nouveau score abstrait : chaque tuile affiche directement le
/// pourcentage ou le montant, avec les formules déjà utilisées ailleurs dans
/// BudgetPilot (`CreditCalculationService.debtRatio`), jamais recalculées
/// différemment ici.
class IndicatorsSection extends ConsumerWidget {
  const IndicatorsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider).valueOrNull;
    if (dashboard == null) return const SizedBox.shrink();

    final activeCredits = _creditCalculationService.activeOnly(ref.watch(creditsProvider).valueOrNull ?? const []);
    final totalIncomeCents = dashboard.totalIncomeCents;

    final savingsRatio = totalIncomeCents <= 0 ? null : dashboard.totalSavingsCents / totalIncomeCents;
    final debtRatio =
        _creditCalculationService.debtRatio(activeCredits: activeCredits, totalIncomeCents: totalIncomeCents);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Mes indicateurs', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _IndicatorTile(
                label: 'Épargne',
                value: savingsRatio == null ? '—' : formatRatioAsPercent(savingsRatio),
                color: (savingsRatio != null && savingsRatio >= kGoodSavingsRateRatio)
                    ? BudgetColors.positive
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _IndicatorTile(
                label: 'Endettement',
                value: totalIncomeCents <= 0 ? '—' : formatRatioAsPercent(debtRatio),
                color: totalIncomeCents <= 0
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : debtRatioBandColor(debtRatioBandFor(debtRatio)),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _IndicatorTile(
                label: 'Dépenses',
                value: formatCentsAsEuro(dashboard.totalVariableExpensesCents),
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _IndicatorTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _IndicatorTile({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Color.alphaBlend(color.withValues(alpha: 0.12), colorScheme.surfaceContainerHigh),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
