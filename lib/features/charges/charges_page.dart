import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/formatting/currency_formatter.dart';
import '../../core/providers/entries_providers.dart';
import '../../core/routing/app_page_route.dart';
import '../../core/theme/charge_status_presentation.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/brand_badge.dart';
import '../../core/widgets/premium_search_bar.dart';
import '../../core/widgets/premium_tap_card.dart';
import '../../core/widgets/staggered_fade_in.dart';
import '../../domain/entities/fixed_expense_entity.dart';
import '../entries/fixed_expense_form_page.dart';
import 'charge_detail_sheet.dart';

const _kAllStatuses = 'toutes';

/// Onglet "Charges" : liste premium des charges fixes du cycle courant —
/// recherche, filtre par statut, tri par date, cartes avec badge.
class ChargesPage extends ConsumerStatefulWidget {
  const ChargesPage({super.key});

  @override
  ConsumerState<ChargesPage> createState() => _ChargesPageState();
}

class _ChargesPageState extends ConsumerState<ChargesPage> {
  final _searchController = TextEditingController();
  bool _sortAscending = true;
  String _statusFilter = _kAllStatuses;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

                  final query = _searchController.text.trim().toLowerCase();
                  final filtered = charges.where((c) {
                    final matchesQuery = query.isEmpty || c.name.toLowerCase().contains(query);
                    final matchesStatus = _statusFilter == _kAllStatuses || c.status == _statusFilter;
                    return matchesQuery && matchesStatus;
                  }).toList()
                    ..sort((a, b) => _sortAscending
                        ? a.expectedDate.compareTo(b.expectedDate)
                        : b.expectedDate.compareTo(a.expectedDate));

                  return Column(
                    children: [
                      PremiumSearchBar(
                        controller: _searchController,
                        hintText: 'Rechercher une charge',
                        sortAscending: _sortAscending,
                        sortTooltip: 'Trier par date',
                        onToggleSort: () => setState(() => _sortAscending = !_sortAscending),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                        child: _StatusFilterRow(
                          selected: _statusFilter,
                          onSelected: (status) => setState(() => _statusFilter = status),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Expanded(
                        child: filtered.isEmpty
                            ? Center(
                                child: Text('Aucun résultat',
                                    style: Theme.of(context).textTheme.bodyMedium))
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                    AppSpacing.lg, 0, AppSpacing.lg, 88),
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                                itemBuilder: (context, index) {
                                  final charge = filtered[index];
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

class _StatusFilterRow extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;
  const _StatusFilterRow({required this.selected, required this.onSelected});

  static const _filters = [
    (_kAllStatuses, 'Toutes'),
    (ChargeStatus.aVenir, 'À venir'),
    (ChargeStatus.aVerifierAujourdhui, "Aujourd'hui"),
    (ChargeStatus.aConfirmer, 'En retard'),
    (ChargeStatus.prelevee, 'Prélevée'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, index) {
          final (value, label) = _filters[index];
          return ChoiceChip(
            label: Text(label),
            selected: selected == value,
            onSelected: (_) => onSelected(value),
          );
        },
      ),
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
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant)),
                      const SizedBox(width: AppSpacing.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: presentation.color.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(AppRadii.sm),
                        ),
                        child: Text(presentation.label,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: presentation.color, fontWeight: FontWeight.w600)),
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
