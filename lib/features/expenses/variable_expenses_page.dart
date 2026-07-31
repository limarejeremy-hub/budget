import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatting/currency_formatter.dart';
import '../../core/providers/dashboard_providers.dart';
import '../../core/providers/entries_providers.dart';
import '../../core/routing/app_page_route.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/brand_badge.dart';
import '../../core/widgets/confirm_delete_dialog.dart';
import '../../core/widgets/premium_search_bar.dart';
import '../../core/widgets/premium_tap_card.dart';
import '../../core/widgets/staggered_fade_in.dart';
import '../../domain/entities/variable_expense_entity.dart';
import '../entries/variable_expense_form_page.dart';

/// Onglet "Dépenses" : liste premium des dépenses variables du cycle
/// courant — recherche, tri par date, cartes.
class VariableExpensesPage extends ConsumerStatefulWidget {
  const VariableExpensesPage({super.key});

  @override
  ConsumerState<VariableExpensesPage> createState() => _VariableExpensesPageState();
}

class _VariableExpensesPageState extends ConsumerState<VariableExpensesPage> {
  final _searchController = TextEditingController();
  bool _sortAscending = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

                  final query = _searchController.text.trim().toLowerCase();
                  final filtered = expenses
                      .where((e) => query.isEmpty || (e.name ?? '').toLowerCase().contains(query))
                      .toList()
                    ..sort((a, b) =>
                        _sortAscending ? a.date.compareTo(b.date) : b.date.compareTo(a.date));

                  return Column(
                    children: [
                      PremiumSearchBar(
                        controller: _searchController,
                        hintText: 'Rechercher une dépense',
                        sortAscending: _sortAscending,
                        sortTooltip: 'Trier par date',
                        onToggleSort: () => setState(() => _sortAscending = !_sortAscending),
                      ),
                      Expanded(
                        child: filtered.isEmpty
                            ? Center(
                                child: Text('Aucun résultat',
                                    style: Theme.of(context).textTheme.bodyMedium))
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                    AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 88),
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                                itemBuilder: (context, index) {
                                  final expense = filtered[index];
                                  return StaggeredFadeIn(
                                    index: index,
                                    child: _ExpenseCard(expense: expense, cycleId: cycleId),
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
      ),
      floatingActionButton: cycleId == null
          ? null
          : FloatingActionButton(
              onPressed: () => Navigator.of(context).push(AppPageRoute(
                builder: (_) => VariableExpenseFormPage(cycleId: cycleId),
              )),
              child: const Icon(Icons.add),
            ),
    );
  }
}

class _ExpenseCard extends ConsumerWidget {
  final VariableExpenseEntity expense;
  final int cycleId;
  const _ExpenseCard({required this.expense, required this.cycleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = (expense.name == null || expense.name!.isEmpty) ? 'Dépense' : expense.name!;
    final colorScheme = Theme.of(context).colorScheme;

    return PremiumTapCard(
      color: Color.alphaBlend(
          CategoryColors.variableExpense.withValues(alpha: 0.07), colorScheme.surfaceContainerHigh),
      borderRadius: BorderRadius.circular(AppRadii.md),
      onTap: () => Navigator.of(context).push(AppPageRoute(
        builder: (_) => VariableExpenseFormPage(cycleId: cycleId, existing: expense),
      )),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Row(
          children: [
            BrandBadge(
              name: title,
              fallbackIcon: Icons.shopping_bag_rounded,
              fallbackColor: CategoryColors.variableExpense,
              size: 34,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  Text(formatDayMonthFr(expense.date),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            Text(formatCentsAsEuro(expense.amountCents),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
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
      ),
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
