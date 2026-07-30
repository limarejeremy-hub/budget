import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatting/currency_formatter.dart';
import '../../core/providers/entries_providers.dart';
import '../../data/local/database.dart';

/// Onglet "Historique" : cycle courant et cycles passés.
class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cyclesAsync = ref.watch(allCyclesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Historique des cycles')),
      body: SafeArea(
        child: cyclesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => const Center(child: Text("Impossible de charger l'historique")),
          data: (cycles) {
            if (cycles.isEmpty) {
              return const Center(child: Text('Aucun cycle pour le moment'));
            }
            return ListView.builder(
              itemCount: cycles.length,
              itemBuilder: (context, index) => _CycleTile(cycle: cycles[index]),
            );
          },
        ),
      ),
    );
  }
}

class _CycleTile extends StatelessWidget {
  final BudgetCycle cycle;
  const _CycleTile({required this.cycle});

  @override
  Widget build(BuildContext context) {
    final isCurrent = cycle.status == 'ouvert';
    final title = (cycle.name == null || cycle.name!.isEmpty)
        ? '${formatDayMonthFr(cycle.startDate)} → ${formatDayMonthFr(cycle.endDate)}'
        : cycle.name!;

    return ListTile(
      leading: Icon(isCurrent ? Icons.play_circle_outline : Icons.check_circle_outline),
      title: Text(title),
      subtitle: Text('${formatDayMonthFr(cycle.startDate)} → ${formatDayMonthFr(cycle.endDate)}'),
      trailing: isCurrent
          ? const Chip(label: Text('En cours'), visualDensity: VisualDensity.compact)
          : null,
    );
  }
}
