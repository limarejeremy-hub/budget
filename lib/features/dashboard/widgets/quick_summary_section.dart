import 'package:flutter/material.dart';

import '../../../core/theme/design_tokens.dart';
import '../../../domain/models/dashboard_view_data.dart';

/// Section "Résumé rapide" — un décompte immédiat du nombre de saisies par
/// catégorie sur le cycle, sans aucun pourcentage.
class QuickSummarySection extends StatelessWidget {
  final DashboardViewData data;
  const QuickSummarySection({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Résumé rapide', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            _QuickSummaryRow(count: data.incomesCount, singular: 'revenu', plural: 'revenus'),
            _QuickSummaryRow(count: data.fixedExpensesCount, singular: 'prélèvement', plural: 'prélèvements'),
            _QuickSummaryRow(count: data.variableExpensesCount, singular: 'dépense', plural: 'dépenses'),
            _QuickSummaryRow(count: data.savingsCount, singular: 'épargne', plural: 'épargnes'),
          ],
        ),
      ),
    );
  }
}

class _QuickSummaryRow extends StatelessWidget {
  final int count;
  final String singular;
  final String plural;

  const _QuickSummaryRow({required this.count, required this.singular, required this.plural});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final label = '$count ${count > 1 ? plural : singular}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, size: 18, color: colorScheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
