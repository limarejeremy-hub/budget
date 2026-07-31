import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatting/currency_formatter.dart';
import '../../core/providers/dashboard_providers.dart';
import '../../core/providers/entries_providers.dart';
import '../../core/routing/app_page_route.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/confirm_delete_dialog.dart';
import '../../core/widgets/premium_search_bar.dart';
import '../../core/widgets/premium_tap_card.dart';
import '../../core/widgets/staggered_fade_in.dart';
import '../../domain/entities/saving_entity.dart';
import 'saving_form_page.dart';

/// Liste premium des épargnes du cycle courant, accessible depuis la tuile
/// "Épargnes" du tableau de bord.
class SavingsListPage extends ConsumerStatefulWidget {
  final int cycleId;
  const SavingsListPage({super.key, required this.cycleId});

  @override
  ConsumerState<SavingsListPage> createState() => _SavingsListPageState();
}

class _SavingsListPageState extends ConsumerState<SavingsListPage> {
  final _searchController = TextEditingController();
  bool _sortAscending = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

            final query = _searchController.text.trim().toLowerCase();
            final filtered = savings.where((s) => query.isEmpty || s.name.toLowerCase().contains(query)).toList()
              ..sort((a, b) => _sortAscending
                  ? a.expectedDate.compareTo(b.expectedDate)
                  : b.expectedDate.compareTo(a.expectedDate));

            return Column(
              children: [
                PremiumSearchBar(
                  controller: _searchController,
                  hintText: 'Rechercher une épargne',
                  sortAscending: _sortAscending,
                  sortTooltip: 'Trier par date',
                  onToggleSort: () => setState(() => _sortAscending = !_sortAscending),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(child: Text('Aucun résultat', style: Theme.of(context).textTheme.bodyMedium))
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 88),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, index) => StaggeredFadeIn(
                            index: index,
                            child: _SavingCard(saving: filtered[index], cycleId: widget.cycleId),
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(AppPageRoute(
          builder: (_) => SavingFormPage(cycleId: widget.cycleId),
        )),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _SavingCard extends ConsumerWidget {
  final SavingEntity saving;
  final int cycleId;
  const _SavingCard({required this.saving, required this.cycleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return PremiumTapCard(
      color: Color.alphaBlend(CategoryColors.saving.withValues(alpha: 0.07), colorScheme.surfaceContainerHigh),
      borderRadius: BorderRadius.circular(AppRadii.md),
      onTap: () => Navigator.of(context).push(AppPageRoute(
        builder: (_) => SavingFormPage(cycleId: cycleId, existing: saving),
      )),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration:
                  BoxDecoration(color: CategoryColors.saving.withValues(alpha: 0.16), shape: BoxShape.circle),
              child: const Icon(Icons.savings_rounded, size: 17, color: CategoryColors.saving),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(saving.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  Text(formatDayMonthFr(saving.expectedDate),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            Text(formatCentsAsEuro(saving.effectiveAmountCents),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
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
      ),
    );
  }
}
