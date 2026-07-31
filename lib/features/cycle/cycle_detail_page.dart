import 'package:flutter/material.dart';

import '../../core/formatting/currency_formatter.dart';
import '../../core/theme/design_tokens.dart';
import '../../domain/models/dashboard_view_data.dart';

/// Détail du cycle courant, ouvert depuis la carte "Argent Libre" du
/// tableau de bord. Purement présentationnel : réutilise les totaux déjà
/// calculés dans [DashboardViewData], aucune nouvelle requête.
class CycleDetailPage extends StatelessWidget {
  final DashboardViewData data;
  const CycleDetailPage({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Détail du cycle')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            Text(
              '${formatDayMonthFr(data.cycleStart)} → ${formatDayMonthFr(data.cycleEnd)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xxl),
            _DetailRow(label: 'Revenus', cents: data.totalIncomeCents),
            _DetailRow(label: 'Charges fixes', cents: data.totalFixedExpensesCents, negative: true),
            _DetailRow(
                label: 'Dépenses variables', cents: data.totalVariableExpensesCents, negative: true),
            _DetailRow(label: 'Épargne', cents: data.totalSavingsCents, negative: true),
            const Divider(height: AppSpacing.xxxl),
            _DetailRow(label: 'Argent libre', cents: data.realRemainingCents, emphasize: true),
            if (data.declaredBankBalanceCents != null) ...[
              const SizedBox(height: AppSpacing.lg),
              _DetailRow(label: 'Solde bancaire déclaré', cents: data.declaredBankBalanceCents!),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final int cents;
  final bool negative;
  final bool emphasize;

  const _DetailRow({
    required this.label,
    required this.cents,
    this.negative = false,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final valueStyle = emphasize
        ? Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)
        : Theme.of(context).textTheme.titleMedium;
    final amountText =
        negative ? '− ${formatCentsAsEuro(cents)}' : formatCentsAsEuro(cents);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: emphasize
                  ? Theme.of(context).textTheme.titleMedium
                  : Theme.of(context).textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ),
          Text(amountText, style: valueStyle),
        ],
      ),
    );
  }
}
