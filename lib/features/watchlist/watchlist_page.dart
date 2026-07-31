import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/formatting/currency_formatter.dart';
import '../../core/providers/entries_providers.dart';
import '../../core/theme/charge_status_presentation.dart';
import '../../core/theme/design_tokens.dart';
import '../../domain/entities/fixed_expense_entity.dart';
import '../entries/fixed_expense_form_page.dart';

/// "Éléments à surveiller" — charges fixes à vérifier aujourd'hui, en
/// retard (à confirmer) ou en incident. Ouvert depuis l'icône de
/// notification du tableau de bord.
class WatchlistPage extends ConsumerWidget {
  final int cycleId;
  const WatchlistPage({super.key, required this.cycleId});

  static const _watchedStatuses = {
    ChargeStatus.aVerifierAujourdhui,
    ChargeStatus.aConfirmer,
    ChargeStatus.incident,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chargesAsync = ref.watch(fixedExpensesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Éléments à surveiller')),
      body: SafeArea(
        child: chargesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => const Center(child: Text('Impossible de charger les charges')),
          data: (charges) {
            final watched = charges.where((c) => _watchedStatuses.contains(c.status)).toList()
              ..sort((a, b) => a.expectedDate.compareTo(b.expectedDate));

            if (watched.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.task_alt_rounded,
                          size: 48, color: Theme.of(context).colorScheme.outline),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Rien à surveiller pour le moment',
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              itemCount: watched.length,
              itemBuilder: (context, index) => _WatchedChargeTile(charge: watched[index], cycleId: cycleId),
            );
          },
        ),
      ),
    );
  }
}

class _WatchedChargeTile extends StatelessWidget {
  final FixedExpenseEntity charge;
  final int cycleId;
  const _WatchedChargeTile({required this.charge, required this.cycleId});

  @override
  Widget build(BuildContext context) {
    final presentation = ChargeStatusPresentation.of(charge.status, context);
    return ListTile(
      leading: Icon(presentation.icon, color: presentation.color),
      title: Text(charge.name),
      subtitle: Text('${formatDayMonthFr(charge.expectedDate)} · ${presentation.label}'),
      trailing: Text(formatCentsAsEuro(charge.effectiveAmountCents)),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => FixedExpenseFormPage(cycleId: cycleId, existing: charge),
      )),
    );
  }
}
