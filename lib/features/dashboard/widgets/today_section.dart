import 'package:flutter/material.dart';

import '../../../core/formatting/currency_formatter.dart';
import '../../../core/routing/app_page_route.dart';
import '../../../core/theme/charge_status_presentation.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../domain/calculations/pending_confirmations.dart';
import '../../../domain/entities/fixed_expense_entity.dart';
import '../../../domain/models/dashboard_view_data.dart';
import '../../confirmations/confirmations_page.dart';

/// Section "Aujourd'hui" — le cockpit du jour : prélèvements du jour,
/// revenus attendus aujourd'hui, alertes importantes. Construit à partir de
/// [DashboardViewData] (déjà filtré par [DashboardViewBuilder]) : aucune
/// nouvelle requête. Cliquable (V0.9) : ouvre directement le centre de
/// confirmations, avec un badge indiquant le nombre d'opérations en
/// attente.
class TodaySection extends StatelessWidget {
  final DashboardViewData data;
  const TodaySection({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final hasContent =
        data.todayFixedExpenses.isNotEmpty || data.todayIncomes.isNotEmpty || data.alerts.isNotEmpty;
    final pendingCount = pendingConfirmations(data).length;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(AppPageRoute(builder: (_) => const ConfirmationsPage())),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.today_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text("Aujourd'hui", style: Theme.of(context).textTheme.titleMedium)),
                  if (pendingCount > 0) _PendingBadge(count: pendingCount),
                  const SizedBox(width: AppSpacing.xs),
                  Icon(Icons.chevron_right_rounded, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (!hasContent)
                _EmptyToday()
              else ...[
                for (final charge in data.todayFixedExpenses)
                  _TodayRow(
                    icon: Icons.receipt_long_rounded,
                    color: CategoryColors.fixedExpense,
                    label: charge.name,
                    cents: charge.effectiveAmountCents,
                    negative: true,
                  ),
                for (final income in data.todayIncomes)
                  _TodayRow(
                    icon: Icons.trending_up_rounded,
                    color: CategoryColors.income,
                    label: income.name,
                    cents: income.effectiveAmountCents,
                    negative: false,
                  ),
                for (final alert in data.alerts) _AlertRow(charge: alert),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingBadge extends StatelessWidget {
  final int count;
  const _PendingBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Text(
        '$count',
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: Theme.of(context).colorScheme.onError, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _EmptyToday extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.check_circle_outline_rounded, size: 18, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            'Aucune opération aujourd\'hui',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _TodayRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final int cents;
  final bool negative;

  const _TodayRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.cents,
    required this.negative,
  });

  @override
  Widget build(BuildContext context) {
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
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium),
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

class _AlertRow extends StatelessWidget {
  final FixedExpenseEntity charge;
  const _AlertRow({required this.charge});

  @override
  Widget build(BuildContext context) {
    final presentation = ChargeStatusPresentation.of(charge.status, context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration:
                BoxDecoration(color: presentation.color.withValues(alpha: 0.16), shape: BoxShape.circle),
            child: Icon(Icons.priority_high_rounded, size: 15, color: presentation.color),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text('${charge.name} · ${presentation.label}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: presentation.color, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
