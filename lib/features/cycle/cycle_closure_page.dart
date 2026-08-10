import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatting/currency_formatter.dart';
import '../../core/providers/credits_providers.dart';
import '../../core/providers/dashboard_providers.dart';
import '../../core/providers/entries_providers.dart';
import '../../core/routing/app_page_route.dart';
import '../../core/theme/design_tokens.dart';
import '../../domain/calculations/cycle_close_service.dart';
import '../../domain/models/dashboard_view_data.dart';
import 'cycle_creation_page.dart';

const _closeService = CycleCloseService();

/// Écran de clôture du cycle courant (finalisation du moteur de cycle) :
/// résumé complet avant clôture, puis bascule directement vers la création
/// du cycle suivant, préremplie — workflow volontairement simple (§21) :
/// Résumé → Clôturer → Créer le prochain cycle → Solde bancaire de départ →
/// Cycle prêt.
class CycleClosurePage extends ConsumerStatefulWidget {
  const CycleClosurePage({super.key});

  @override
  ConsumerState<CycleClosurePage> createState() => _CycleClosurePageState();
}

class _CycleClosurePageState extends ConsumerState<CycleClosurePage> {
  bool _closing = false;

  Future<void> _closeCycle(DashboardViewData data) async {
    setState(() => _closing = true);
    try {
      final repository = ref.read(cycleRepositoryProvider);
      await repository.closeCycle(data.cycleId);

      // Les rappels programmés pour les charges de ce cycle deviennent
      // obsolètes dès la clôture (§15), y compris en cas de clôture
      // manuelle anticipée avant la date de fin prévue.
      final chargeIds = ref.read(fixedExpensesProvider).valueOrNull?.map((c) => c.id) ?? const <int>[];
      await ref.read(notificationServiceProvider).cancelChargeReminders(chargeIds);

      if (!mounted) return;
      final nextStart = _closeService.nextCycleStartDate(data.cycleEnd);
      final nextEnd = _closeService.nextCycleEndDate(
        previousStartDate: data.cycleStart,
        previousEndDate: data.cycleEnd,
        newStartDate: nextStart,
      );
      Navigator.of(context).pushReplacement(AppPageRoute(
        builder: (_) => CycleCreationPage(
          initialStartDate: nextStart,
          initialEndDate: nextEnd,
          suggestedBalanceCents: data.realRemainingCents,
          previousCycleId: data.cycleId,
        ),
      ));
    } finally {
      if (mounted) setState(() => _closing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(dashboardProvider);
    final chargesAsync = ref.watch(fixedExpensesProvider);
    final creditsAsync = ref.watch(creditsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Terminer le cycle')),
      body: SafeArea(
        child: dashboardAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => const Center(child: Text('Impossible de charger le cycle')),
          data: (data) {
            if (data == null) {
              return const Center(child: Text('Aucun cycle en cours à clôturer.'));
            }

            final charges = chargesAsync.valueOrNull ?? const [];
            final credits = creditsAsync.valueOrNull ?? const [];
            final impactedCreditIds = charges.map((c) => c.linkedCreditId).whereType<int>().toSet();
            final impactedCredits = credits.where((c) => impactedCreditIds.contains(c.id)).toList();

            return ListView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              children: [
                Text(
                  'Vérifiez le résumé de ce cycle avant de le clôturer. Une fois clôturé, '
                  'ses revenus, charges, dépenses et épargnes ne changeront plus jamais.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xl),
                _SummaryRow(
                    label: 'Période',
                    value: '${formatDayMonthFr(data.cycleStart)} → ${formatDayMonthFr(data.cycleEnd)}'),
                if (data.declaredBankBalanceCents != null)
                  _SummaryRow(
                      label: 'Solde bancaire de départ', value: formatCentsAsEuro(data.declaredBankBalanceCents!)),
                _SummaryRow(label: 'Revenus', value: formatCentsAsEuro(data.totalIncomeCents)),
                _SummaryRow(label: 'Charges fixes', value: formatCentsAsEuro(data.totalFixedExpensesCents)),
                _SummaryRow(label: 'Dépenses variables', value: formatCentsAsEuro(data.totalVariableExpensesCents)),
                _SummaryRow(label: 'Épargne', value: formatCentsAsEuro(data.totalSavingsCents)),
                const Divider(height: AppSpacing.xxxl),
                _SummaryRow(
                    label: 'Argent libre final', value: formatCentsAsEuro(data.realRemainingCents), emphasize: true),
                if (data.unconfirmedChargesCount > 0) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _UnconfirmedWarning(
                    count: data.unconfirmedChargesCount,
                    totalCents: data.unconfirmedChargesTotalCents,
                  ),
                ],
                if (impactedCredits.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xl),
                  Text('Crédits impactés pendant ce cycle', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.sm),
                  for (final credit in impactedCredits)
                    _SummaryRow(label: credit.name, value: formatCentsAsEuro(credit.monthlyPaymentCents)),
                ],
                const SizedBox(height: AppSpacing.xxxl),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _closing ? null : () => Navigator.of(context).pop(),
                        child: const Text('Annuler'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: FilledButton(
                        onPressed: _closing ? null : () => _closeCycle(data),
                        child: Text(_closing ? 'Clôture…' : 'Clôturer le cycle'),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;
  const _SummaryRow({required this.label, required this.value, this.emphasize = false});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: (emphasize ? Theme.of(context).textTheme.titleMedium : Theme.of(context).textTheme.bodyMedium)
                    ?.copyWith(color: emphasize ? null : colorScheme.onSurfaceVariant)),
          ),
          Text(
            value,
            style: (emphasize ? Theme.of(context).textTheme.titleMedium : Theme.of(context).textTheme.bodyMedium)
                ?.copyWith(fontWeight: emphasize ? FontWeight.bold : FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _UnconfirmedWarning extends StatelessWidget {
  final int count;
  final int totalCents;
  const _UnconfirmedWarning({required this.count, required this.totalCents});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: CategoryColors.fixedExpense.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: CategoryColors.fixedExpense, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '$count prélèvement${count > 1 ? 's' : ''} encore non confirmé${count > 1 ? 's' : ''} '
              '(${formatCentsAsEuro(totalCents)}) — vous pouvez tout de même clôturer ce cycle si vous le '
              'souhaitez.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}
