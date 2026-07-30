import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatting/currency_formatter.dart';
import '../../core/providers/dashboard_providers.dart';
import '../../core/providers/entries_providers.dart';
import '../../core/widgets/confirm_delete_dialog.dart';
import '../../domain/entities/variable_expense_entity.dart';
import '../entries/variable_expense_form_page.dart';

/// Onglet "Dépenses" : liste des dépenses variables du cycle courant.
class VariableExpensesPage extends ConsumerWidget {
  const VariableExpensesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cycleAsync = ref.watch(currentCycleProvider);
    final expensesAsync = ref.watch(variableExpensesProvider);
    final cycleId = cycleAsync.valueOrNull?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Dépenses variables')),
      body: SafeArea(
        child: cycleId == null
            ? const _NoCycleMessage()
            : expensesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => const Center(child: Text('Impossible de charger les dépenses')),
                data: (expenses) {
                  if (expenses.isEmpty) {
                    return const Center(child: Text('Aucune dépense variable pour ce cycle'));
                  }
                  final sorted = [...expenses]..sort((a, b) => b.date.compareTo(a.date));
                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 88),
                    itemCount: sorted.length,
                    itemBuilder: (context, index) {
                      final expense = sorted[index];
                      return _ExpenseTile(expense: expense, cycleId: cycleId);
                    },
                  );
                },
              ),
      ),
      floatingActionButton: cycleId == null
          ? null
          : FloatingActionButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => VariableExpenseFormPage(cycleId: cycleId),
              )),
              child: const Icon(Icons.add),
            ),
    );
  }
}

class _ExpenseTile extends ConsumerWidget {
  final VariableExpenseEntity expense;
  final int cycleId;
  const _ExpenseTile({required this.expense, required this.cycleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = (expense.name == null || expense.name!.isEmpty) ? 'Dépense' : expense.name!;
    return ListTile(
      title: Text(title),
      subtitle: Text(formatDayMonthFr(expense.date)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(formatCentsAsEuro(expense.amountCents)),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Supprimer',
            onPressed: () async {
              final confirmed = await confirmDelete(context, title: 'Supprimer "$title" ?');
              if (confirmed) {
                await ref.read(cycleRepositoryProvider).deleteVariableExpense(expense.id);
              }
            },
          ),
        ],
      ),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => VariableExpenseFormPage(cycleId: cycleId, existing: expense),
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
