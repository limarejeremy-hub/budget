import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatting/currency_formatter.dart';
import '../../core/providers/dashboard_providers.dart';
import '../../core/providers/entries_providers.dart';
import '../../core/theme/charge_status_presentation.dart';
import '../../core/widgets/confirm_delete_dialog.dart';
import '../../domain/entities/fixed_expense_entity.dart';
import '../entries/fixed_expense_form_page.dart';

/// Onglet "Charges" : liste des charges fixes du cycle courant.
class ChargesPage extends ConsumerWidget {
  const ChargesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cycleAsync = ref.watch(currentCycleProvider);
    final chargesAsync = ref.watch(fixedExpensesProvider);
    final cycleId = cycleAsync.valueOrNull?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Charges fixes')),
      body: SafeArea(
        child: cycleId == null
            ? const _NoCycleMessage()
            : chargesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => const Center(child: Text('Impossible de charger les charges')),
                data: (charges) {
                  if (charges.isEmpty) {
                    return const Center(child: Text('Aucune charge fixe pour ce cycle'));
                  }
                  final sorted = [...charges]
                    ..sort((a, b) => a.expectedDate.compareTo(b.expectedDate));
                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 88),
                    itemCount: sorted.length,
                    itemBuilder: (context, index) {
                      final charge = sorted[index];
                      return _ChargeTile(charge: charge, cycleId: cycleId);
                    },
                  );
                },
              ),
      ),
      floatingActionButton: cycleId == null
          ? null
          : FloatingActionButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => FixedExpenseFormPage(cycleId: cycleId),
              )),
              child: const Icon(Icons.add),
            ),
    );
  }
}

class _ChargeTile extends ConsumerWidget {
  final FixedExpenseEntity charge;
  final int cycleId;
  const _ChargeTile({required this.charge, required this.cycleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presentation = ChargeStatusPresentation.of(charge.status, context);
    return ListTile(
      leading: Icon(presentation.icon, color: presentation.color),
      title: Text(charge.name),
      subtitle: Text('${formatDayMonthFr(charge.expectedDate)} · ${presentation.label}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(formatCentsAsEuro(charge.effectiveAmountCents)),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Supprimer',
            onPressed: () async {
              final confirmed = await confirmDelete(context, title: 'Supprimer "${charge.name}" ?');
              if (confirmed) {
                await ref.read(cycleRepositoryProvider).deleteFixedExpense(charge.id);
              }
            },
          ),
        ],
      ),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => FixedExpenseFormPage(cycleId: cycleId, existing: charge),
      )),
    );
  }
}

class _NoCycleMessage extends StatelessWidget {
  const _NoCycleMessage();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          "Aucun cycle en cours — créez votre cycle depuis l'onglet Accueil.",
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
