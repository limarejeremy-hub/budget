import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatting/currency_formatter.dart';
import '../../core/providers/dashboard_providers.dart';
import '../../core/providers/entries_providers.dart';
import '../../core/widgets/confirm_delete_dialog.dart';
import '../../domain/entities/income_entity.dart';
import 'income_form_page.dart';

/// Liste des revenus du cycle courant, accessible depuis la tuile
/// "Revenus du cycle" du tableau de bord.
class IncomesListPage extends ConsumerWidget {
  final int cycleId;
  const IncomesListPage({super.key, required this.cycleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incomesAsync = ref.watch(incomesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Revenus')),
      body: SafeArea(
        child: incomesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => const Center(child: Text('Impossible de charger les revenus')),
          data: (incomes) {
            if (incomes.isEmpty) {
              return const Center(child: Text('Aucun revenu pour ce cycle'));
            }
            final sorted = [...incomes]..sort((a, b) => a.expectedDate.compareTo(b.expectedDate));
            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: sorted.length,
              itemBuilder: (context, index) => _IncomeTile(income: sorted[index], cycleId: cycleId),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => IncomeFormPage(cycleId: cycleId),
        )),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _IncomeTile extends ConsumerWidget {
  final IncomeEntity income;
  final int cycleId;
  const _IncomeTile({required this.income, required this.cycleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: Text(income.name),
      subtitle: Text(formatDayMonthFr(income.expectedDate)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(formatCentsAsEuro(income.effectiveAmountCents)),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Supprimer',
            onPressed: () async {
              final confirmed = await confirmDelete(context, title: 'Supprimer "${income.name}" ?');
              if (confirmed) {
                await ref.read(cycleRepositoryProvider).deleteIncome(income.id);
              }
            },
          ),
        ],
      ),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => IncomeFormPage(cycleId: cycleId, existing: income),
      )),
    );
  }
}
