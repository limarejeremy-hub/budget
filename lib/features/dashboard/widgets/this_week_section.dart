import 'package:flutter/material.dart';

import '../../../core/formatting/currency_formatter.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../domain/models/dashboard_view_data.dart';

/// Section "Cette semaine" — les prochaines opérations planifiées dans les
/// 7 jours à venir (hors aujourd'hui, déjà couvert par "Aujourd'hui").
/// Purement présentationnel : construit à partir de [DashboardViewData].
///
/// Quand elle est vide, la section reste volontairement minimale (une seule
/// ligne compacte, sans grande carte ni espace vide) ; dès qu'il y a des
/// opérations, elle s'agrandit naturellement pour les afficher.
class ThisWeekSection extends StatelessWidget {
  final DashboardViewData data;
  const ThisWeekSection({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final rows = <_WeekRow>[
      for (final e in data.thisWeekFixedExpenses)
        _WeekRow(
          icon: Icons.receipt_long_rounded,
          color: CategoryColors.fixedExpense,
          label: e.name,
          date: e.expectedDate,
          cents: e.effectiveAmountCents,
          negative: true,
        ),
      for (final i in data.thisWeekIncomes)
        _WeekRow(
          icon: Icons.trending_up_rounded,
          color: CategoryColors.income,
          label: i.name,
          date: i.expectedDate,
          cents: i.effectiveAmountCents,
          negative: false,
        ),
      for (final s in data.thisWeekSavings)
        _WeekRow(
          icon: Icons.savings_rounded,
          color: CategoryColors.saving,
          label: s.name,
          date: s.expectedDate,
          cents: s.effectiveAmountCents,
          negative: true,
        ),
    ]..sort((a, b) => a.date.compareTo(b.date));

    if (rows.isEmpty) {
      return const _CompactEmptyThisWeek();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.view_week_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Text('Cette semaine', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            for (final row in rows) row,
          ],
        ),
      ),
    );
  }
}

/// Version compacte affichée lorsque rien n'est prévu cette semaine — une
/// seule ligne discrète, pas une grande carte.
class _CompactEmptyThisWeek extends StatelessWidget {
  const _CompactEmptyThisWeek();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        children: [
          Icon(Icons.event_available_rounded, size: 16, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Aucune opération prévue cette semaine',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final DateTime date;
  final int cents;
  final bool negative;

  const _WeekRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.date,
    required this.cents,
    required this.negative,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final amountText = negative ? '− ${formatCentsAsEuro(cents)}' : '+ ${formatCentsAsEuro(cents)}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.16), shape: BoxShape.circle),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium),
                Text(formatDayMonthFr(date),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          Text(
            amountText,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: negative ? null : CategoryColors.income,
                ),
          ),
        ],
      ),
    );
  }
}
