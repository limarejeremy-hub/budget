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
import '../../domain/entities/income_entity.dart';
import 'income_form_page.dart';

/// Liste premium des revenus du cycle courant, accessible depuis la tuile
/// "Revenus" du tableau de bord.
class IncomesListPage extends ConsumerStatefulWidget {
  final int cycleId;
  const IncomesListPage({super.key, required this.cycleId});

  @override
  ConsumerState<IncomesListPage> createState() => _IncomesListPageState();
}

class _IncomesListPageState extends ConsumerState<IncomesListPage> {
  final _searchController = TextEditingController();
  bool _sortAscending = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

            final query = _searchController.text.trim().toLowerCase();
            final filtered = incomes.where((i) => query.isEmpty || i.name.toLowerCase().contains(query)).toList()
              ..sort((a, b) => _sortAscending
                  ? a.expectedDate.compareTo(b.expectedDate)
                  : b.expectedDate.compareTo(a.expectedDate));

            return Column(
              children: [
                PremiumSearchBar(
                  controller: _searchController,
                  hintText: 'Rechercher un revenu',
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
                            child: _IncomeCard(income: filtered[index], cycleId: widget.cycleId),
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
          builder: (_) => IncomeFormPage(cycleId: widget.cycleId),
        )),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _IncomeCard extends ConsumerWidget {
  final IncomeEntity income;
  final int cycleId;
  const _IncomeCard({required this.income, required this.cycleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return PremiumTapCard(
      color: Color.alphaBlend(CategoryColors.income.withValues(alpha: 0.07), colorScheme.surfaceContainerHigh),
      borderRadius: BorderRadius.circular(AppRadii.md),
      onTap: () => Navigator.of(context).push(AppPageRoute(
        builder: (_) => IncomeFormPage(cycleId: cycleId, existing: income),
      )),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration:
                  BoxDecoration(color: CategoryColors.income.withValues(alpha: 0.16), shape: BoxShape.circle),
              child: const Icon(Icons.trending_up_rounded, size: 17, color: CategoryColors.income),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(income.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  Text(formatDayMonthFr(income.expectedDate),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            Text(formatCentsAsEuro(income.effectiveAmountCents),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
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
      ),
    );
  }
}
