import 'package:flutter/material.dart';

import '../../core/formatting/currency_formatter.dart';
import '../../core/routing/app_page_route.dart';
import '../../core/theme/design_tokens.dart';
import '../../domain/models/dashboard_view_data.dart';
import 'cycle_closure_page.dart';

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
            _DetailRow(label: 'Dépenses variables', cents: data.totalVariableExpensesCents, negative: true),
            _DetailRow(label: 'Épargne', cents: data.totalSavingsCents, negative: true),
            const Divider(height: AppSpacing.xxxl),
            _DetailRow(label: 'Argent libre', cents: data.realRemainingCents, emphasize: true),
            if (data.declaredBankBalanceCents != null) ...[
              const SizedBox(height: AppSpacing.lg),
              _DetailRow(
                label: 'Solde bancaire déclaré',
                cents: data.declaredBankBalanceCents!,
                // Couleur d'alerte discrète (le même orange que les charges,
                // jamais le rouge réservé aux cas réellement problématiques)
                // quand le solde déclaré est à découvert. Ce solde de départ
                // est bien intégré à l'Argent libre ci-dessus (formule
                // centrale de BudgetCalculationService) — cette ligne reste
                // affichée séparément comme la donnée persistée d'origine.
                valueColor: data.declaredBankBalanceCents! < 0 ? CategoryColors.fixedExpense : null,
              ),
            ],
            const SizedBox(height: AppSpacing.xxxl),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(AppPageRoute(
                builder: (_) => const CycleClosurePage(),
              )),
              icon: const Icon(Icons.event_available_outlined),
              label: const Text('Terminer le cycle'),
            ),
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
  final Color? valueColor;

  const _DetailRow({
    required this.label,
    required this.cents,
    this.negative = false,
    this.emphasize = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final valueStyle = (emphasize
            ? Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)
            : Theme.of(context).textTheme.titleMedium)
        ?.copyWith(color: valueColor);
    final amountText = negative ? '− ${formatCentsAsEuro(cents)}' : formatCentsAsEuro(cents);

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
