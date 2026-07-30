import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatting/currency_formatter.dart';
import '../../core/providers/dashboard_providers.dart';
import '../../core/providers/entries_providers.dart';
import '../../core/widgets/confirm_delete_dialog.dart';
import '../../domain/entities/saving_entity.dart';
import 'saving_form_page.dart';

/// Liste des épargnes du cycle courant, accessible depuis la tuile
/// "Épargne réservée" du tableau de bord.
class SavingsListPage extends ConsumerWidget {
  final int cycleId;
  const SavingsListPage({super.key, required this.cycleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savingsAsync = ref.watch(savingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Épargne')),
      body: SafeArea(
        child: savingsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => const Center(child: Text("Impossible de charger l'épargne")),
          data: (savings) {
            if (savings.isEmpty) {
              return const Center(child: Text('Aucune épargne pour ce cycle'));
            }
            final sorted = [...savings]..sort((a, b) => a.expectedDate.compareTo(b.expectedDate));
            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: sorted.length,
              itemBuilder: (context, index) => _SavingTile(saving: sorted[index], cycleId: cycleId),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => SavingFormPage(cycleId: cycleId),
        )),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _SavingTile extends ConsumerWidget {
  final SavingEntity saving;
  final int cycleId;
  const _SavingTile({required this.saving, required this.cycleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: Text(saving.name),
      subtitle: Text(formatDayMonthFr(saving.expectedDate)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(formatCentsAsEuro(saving.effectiveAmountCents)),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Supprimer',
            onPressed: () async {
              final confirmed = await confirmDelete(context, title: 'Supprimer "${saving.name}" ?');
              if (confirmed) {
                await ref.read(cycleRepositoryProvider).deleteSaving(saving.id);
              }
            },
          ),
        ],
      ),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => SavingFormPage(cycleId: cycleId, existing: saving),
      )),
    );
  }
}
