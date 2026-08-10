import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/formatting/currency_formatter.dart';
import '../../core/providers/entries_providers.dart';
import '../../core/routing/app_page_route.dart';
import '../../core/theme/charge_status_presentation.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/brand_badge.dart';
import '../../core/widgets/premium_tap_card.dart';
import '../../core/widgets/staggered_fade_in.dart';
import '../../data/local/database.dart' show Category;
import '../../domain/calculations/charge_sorting.dart';
import '../../domain/entities/fixed_expense_entity.dart';
import '../entries/fixed_expense_form_page.dart';
import 'charge_detail_sheet.dart';

/// Sélection "Sans catégorie" dans le menu déroulant — distinct de `null`
/// qui représente ici "Toutes les catégories" (aucun filtre). Jamais un id
/// de catégorie réel (les id Drift auto-incrémentés commencent à 1).
const int _kUncategorizedFilterId = -1;

class _SortOption {
  final String label;
  final ChargeSortField field;
  final bool ascending;
  const _SortOption(this.label, this.field, this.ascending);
}

const _sortOptions = [
  _SortOption('Montant décroissant', ChargeSortField.amount, false),
  _SortOption('Montant croissant', ChargeSortField.amount, true),
  _SortOption('Date', ChargeSortField.date, true),
  _SortOption('Nom', ChargeSortField.name, true),
];

/// Onglet "Charges" : recherche, filtre par catégorie (dérivée des charges
/// existantes, jamais codée en dur), coût total de la catégorie
/// sélectionnée, et classement des catégories par coût — interface
/// volontairement compacte, sans filtres multiples ni gros bloc "Top 3".
class ChargesPage extends ConsumerStatefulWidget {
  const ChargesPage({super.key});

  @override
  ConsumerState<ChargesPage> createState() => _ChargesPageState();
}

class _ChargesPageState extends ConsumerState<ChargesPage> {
  final _searchController = TextEditingController();
  int? _selectedCategoryId; // null = "Toutes les catégories"
  bool _showRanking = false;
  ChargeSortField _sortField = ChargeSortField.amount;
  bool _sortAscending = false; // montant décroissant par défaut (§5)

  @override
  void initState() {
    super.initState();
    // Sans ce listener, taper dans le champ de recherche ne reconstruit
    // jamais la page (le texte du contrôleur n'est lu que dans build()) —
    // la recherche resterait silencieusement inopérante.
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() => setState(() {});

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _selectCategory(int? filterId) {
    setState(() {
      _selectedCategoryId = filterId;
      _showRanking = false;
    });
  }

  bool _matchesCategory(FixedExpenseEntity charge, int? filterId) {
    if (filterId == null) return true;
    if (filterId == _kUncategorizedFilterId) return charge.categoryId == null;
    return charge.categoryId == filterId;
  }

  @override
  Widget build(BuildContext context) {
    final cycleAsync = ref.watch(currentCycleProvider);
    final chargesAsync = ref.watch(fixedExpensesProvider);
    final categoriesAsync = ref.watch(categoriesForTypeProvider(EntityType.fixedExpense));
    final cycleId = cycleAsync.valueOrNull?.id;
    final categoryNames = {
      for (final category in categoriesAsync.valueOrNull ?? const <Category>[]) category.id: category.name,
    };

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

                  final categories = usedChargeCategories(charges, categoryNames: categoryNames);
                  final availableFilterIds = {for (final o in categories) o.categoryId ?? _kUncategorizedFilterId};
                  // Si la catégorie sélectionnée n'a plus aucune charge (ex :
                  // dernière charge supprimée pendant que le filtre était
                  // actif), on revient silencieusement à "Toutes les
                  // catégories" plutôt que de garder un menu déroulant sur
                  // une valeur qui n'existe plus.
                  final effectiveCategoryId =
                      (_selectedCategoryId != null && !availableFilterIds.contains(_selectedCategoryId))
                          ? null
                          : _selectedCategoryId;

                  final totals = categoryTotals(charges, categoryNames: categoryNames);
                  final totalsByFilterId = {
                    for (final t in totals) (t.categoryId ?? _kUncategorizedFilterId): t.totalCents
                  };

                  final query = _searchController.text.trim().toLowerCase();
                  final filtered = charges.where((c) {
                    final matchesQuery = query.isEmpty || c.name.toLowerCase().contains(query);
                    return matchesQuery && _matchesCategory(c, effectiveCategoryId);
                  }).toList();
                  final sorted = sortCharges(
                    filtered,
                    field: _sortField,
                    ascending: _sortAscending,
                    categoryNames: categoryNames,
                  );

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            hintText: 'Rechercher une charge',
                            prefixIcon: Icon(Icons.search_rounded),
                            isDense: true,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                        child: Row(
                          children: [
                            Expanded(
                              child: _CategoryDropdown(
                                categories: categories,
                                selectedFilterId: effectiveCategoryId,
                                onChanged: _selectCategory,
                              ),
                            ),
                            if (effectiveCategoryId != null)
                              Text(
                                '${formatCentsAsEuro(totalsByFilterId[effectiveCategoryId] ?? 0)}/mois',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                              )
                            else
                              TextButton(
                                onPressed: () => setState(() => _showRanking = !_showRanking),
                                child: Text(_showRanking ? 'Liste' : 'Classement'),
                              ),
                            if (!_showRanking)
                              PopupMenuButton<int>(
                                tooltip: 'Trier',
                                icon: const Icon(Icons.sort_rounded),
                                itemBuilder: (context) => [
                                  for (final (index, option) in _sortOptions.indexed)
                                    PopupMenuItem(value: index, child: Text(option.label)),
                                ],
                                onSelected: (index) {
                                  final option = _sortOptions[index];
                                  setState(() {
                                    _sortField = option.field;
                                    _sortAscending = option.ascending;
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Expanded(
                        child: _showRanking
                            ? _CategoryRankingList(totals: totals, onSelectCategory: _selectCategory)
                            : sorted.isEmpty
                                ? Center(child: Text('Aucun résultat', style: Theme.of(context).textTheme.bodyMedium))
                                : ListView.separated(
                                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, 88),
                                    itemCount: sorted.length,
                                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                                    itemBuilder: (context, index) {
                                      final charge = sorted[index];
                                      return StaggeredFadeIn(
                                        index: index,
                                        child: _ChargeCard(charge: charge, cycleId: cycleId),
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
                builder: (_) => FixedExpenseFormPage(cycleId: cycleId),
              )),
              child: const Icon(Icons.add),
            ),
    );
  }
}

/// Menu déroulant compact des catégories réellement utilisées (§1) — jamais
/// une liste codée en dur.
class _CategoryDropdown extends StatelessWidget {
  final List<ChargeCategoryOption> categories;
  final int? selectedFilterId;
  final ValueChanged<int?> onChanged;
  const _CategoryDropdown({required this.categories, required this.selectedFilterId, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<int?>(
        value: selectedFilterId,
        isDense: true,
        isExpanded: true,
        items: [
          const DropdownMenuItem(
            value: null,
            child: Text('Toutes les catégories', overflow: TextOverflow.ellipsis),
          ),
          for (final option in categories)
            DropdownMenuItem(
              value: option.categoryId ?? _kUncategorizedFilterId,
              child: Text(option.name, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

/// "Classement par coût" (§3) : catégories du plus coûteux au moins
/// coûteux, chaque ligne cliquable pour filtrer directement la liste des
/// charges sur cette catégorie.
class _CategoryRankingList extends StatelessWidget {
  final List<CategoryChargeTotal> totals;
  final ValueChanged<int?> onSelectCategory;
  const _CategoryRankingList({required this.totals, required this.onSelectCategory});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (totals.isEmpty) {
      return Center(child: Text('Aucune charge à classer', style: Theme.of(context).textTheme.bodyMedium));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, 88),
      itemCount: totals.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: colorScheme.outlineVariant),
      itemBuilder: (context, index) {
        final total = totals[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Text('${index + 1}.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
          title: Text(total.categoryName, style: Theme.of(context).textTheme.bodyMedium),
          trailing: Text('${formatCentsAsEuro(total.totalCents)}/mois',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
          onTap: () => onSelectCategory(total.categoryId ?? _kUncategorizedFilterId),
        );
      },
    );
  }
}

class _ChargeCard extends StatelessWidget {
  final FixedExpenseEntity charge;
  final int cycleId;
  const _ChargeCard({required this.charge, required this.cycleId});

  @override
  Widget build(BuildContext context) {
    final presentation = ChargeStatusPresentation.of(charge.status, context);
    final colorScheme = Theme.of(context).colorScheme;

    return PremiumTapCard(
      color: Color.alphaBlend(presentation.color.withValues(alpha: 0.07), colorScheme.surfaceContainerHigh),
      borderRadius: BorderRadius.circular(AppRadii.md),
      onTap: () => showChargeDetailSheet(context, charge: charge, cycleId: cycleId),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Row(
          children: [
            BrandBadge(
              name: charge.name,
              fallbackIcon: presentation.icon,
              fallbackColor: presentation.color,
              size: 34,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(charge.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  Row(
                    children: [
                      Text(formatDayMonthFr(charge.expectedDate),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                      const SizedBox(width: AppSpacing.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: presentation.color.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(AppRadii.sm),
                        ),
                        child: Text(presentation.label,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: presentation.color, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(formatCentsAsEuro(charge.effectiveAmountCents),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(width: AppSpacing.xs),
            Icon(Icons.chevron_right_rounded, size: 18, color: colorScheme.onSurfaceVariant),
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
