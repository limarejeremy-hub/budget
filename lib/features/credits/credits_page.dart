import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatting/currency_formatter.dart';
import '../../core/providers/credits_providers.dart';
import '../../core/providers/dashboard_providers.dart';
import '../../core/routing/app_page_route.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/staggered_fade_in.dart';
import '../../data/local/converters/entity_mappers.dart';
import '../../domain/calculations/credit_calculation_service.dart';
import '../../domain/calculations/household_finance_service.dart';
import '../../domain/entities/credit_entity.dart';
import '../../domain/models/dashboard_view_data.dart';
import '../entries/fixed_expense_form_page.dart';
import 'credit_detail_page.dart';
import 'credit_form_page.dart';
import 'credit_visuals.dart';
import 'widgets/credit_repayment_simulator_sheet.dart';

const _creditCalculationService = CreditCalculationService();
const _householdFinanceService = HouseholdFinanceService();

enum _SortMode { none, lowestCapital, highestRate, highestPayment }

/// Page "Crédits" : résumé global, tri par priorité (jamais imposé), liste
/// de tous les crédits (actifs et terminés) sous forme de cartes.
class CreditsPage extends ConsumerStatefulWidget {
  const CreditsPage({super.key});

  @override
  ConsumerState<CreditsPage> createState() => _CreditsPageState();
}

class _CreditsPageState extends ConsumerState<CreditsPage> {
  _SortMode _sortMode = _SortMode.none;

  @override
  Widget build(BuildContext context) {
    final creditsAsync = ref.watch(creditsProvider);
    final dashboardAsync = ref.watch(dashboardProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Crédits')),
      body: SafeArea(
        child: Column(
          children: [
            const _ChargesToCompleteSection(),
            Expanded(
              child: creditsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => const Center(child: Text('Impossible de charger les crédits')),
                data: (credits) {
                  if (credits.isEmpty) {
                    return const _EmptyCredits();
                  }

                  final displayed = switch (_sortMode) {
                    _SortMode.none => credits,
                    _SortMode.lowestCapital => _creditCalculationService.sortByLowestCapital(credits),
                    _SortMode.highestRate => _creditCalculationService.sortByHighestRate(credits),
                    _SortMode.highestPayment => _creditCalculationService.sortByHighestPayment(credits),
                  };

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 88),
                    children: [
                      _CreditsSummaryHeader(credits: credits, dashboard: dashboardAsync.valueOrNull),
                      const SizedBox(height: AppSpacing.lg),
                      _IndicatorsSection(credits: credits),
                      const SizedBox(height: AppSpacing.xl),
                      OutlinedButton.icon(
                        onPressed: () => showCreditRepaymentSimulatorSheet(context, credits: credits),
                        icon: const Icon(Icons.calculate_outlined),
                        label: const Text('Simuler un remboursement'),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      _SortSelector(
                        selected: _sortMode,
                        onChanged: (mode) => setState(() => _sortMode = mode),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      for (final (index, credit) in displayed.indexed) ...[
                        StaggeredFadeIn(index: index, child: _CreditCard(credit: credit)),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(AppPageRoute(builder: (_) => const CreditFormPage())),
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Charges fixes de catégorie "Crédit" sans crédit lié (migration sans
/// correspondance fiable, ou incohérence à corriger manuellement) — jamais
/// masquées, jamais fusionnées silencieusement. Invisible (aucune hauteur)
/// tant qu'il n'y en a aucune. Traitement discret (ambre, jamais rouge) :
/// une information à compléter, pas une erreur système.
class _ChargesToCompleteSection extends ConsumerWidget {
  const _ChargesToCompleteSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chargesAsync = ref.watch(unlinkedCreditChargesProvider);
    final charges = chargesAsync.valueOrNull ?? const [];
    if (charges.isEmpty) return const SizedBox.shrink();

    final count = charges.length;
    final subtitle = count == 1
        ? '1 charge nécessite quelques informations pour être suivie comme crédit.'
        : '$count charges nécessitent quelques informations pour être suivies comme crédits.';

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
      child: Card(
        margin: EdgeInsets.zero,
        color: Color.alphaBlend(
          CategoryColors.credit.withValues(alpha: 0.1),
          Theme.of(context).colorScheme.surfaceContainerHigh,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 18, color: CategoryColors.credit),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    count == 1 ? '1 crédit à compléter' : '$count crédits à compléter',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700, color: CategoryColors.credit),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitle,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              for (final charge in charges)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(charge.name, style: Theme.of(context).textTheme.bodyMedium),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(formatCentsAsEuro(charge.expectedAmountCents),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(width: AppSpacing.xs),
                      Icon(Icons.chevron_right_rounded,
                          size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ],
                  ),
                  onTap: () => Navigator.of(context).push(AppPageRoute(
                    builder: (_) =>
                        FixedExpenseFormPage(cycleId: charge.cycleId, existing: fixedExpenseFromRow(charge)),
                  )),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyCredits extends StatelessWidget {
  const _EmptyCredits();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_balance_outlined, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: AppSpacing.lg),
            Text('Aucun crédit enregistré',
                style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Ajoutez un crédit pour suivre son capital restant et sa mensualité.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Bloc récapitulatif principal de la page Crédits — inclut le taux
/// d'endettement et le reste à vivre STRUCTUREL actuels (V1.2), calculés
/// avec LES seules formules partagées par toute l'application
/// (`CreditCalculationService.debtRatio` et `HouseholdFinanceService.
/// structuralRemainingCents`, jamais recalculées ici ni ailleurs — mêmes
/// formules qu'au Project Planner). Le reste à vivre affiché ici n'est
/// jamais l'argent libre du cycle : il ne dépend jamais des dépenses
/// variables ni de l'épargne. Les mensualités de crédits liés à une charge
/// fixe ne sont comptées qu'une seule fois : `credits` porte la mensualité,
/// la charge fixe liée n'est qu'un affichage de cette même mensualité dans
/// le cycle, jamais une deuxième saisie.
class _CreditsSummaryHeader extends StatelessWidget {
  final List<CreditEntity> credits;
  final DashboardViewData? dashboard;
  const _CreditsSummaryHeader({required this.credits, required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final activeCredits = _creditCalculationService.activeOnly(credits);
    final totalCapital = _creditCalculationService.totalRemainingCapital(credits);
    final totalPayments = _creditCalculationService.totalMonthlyPayments(credits);
    final activeCount = _creditCalculationService.activeCount(credits);
    final earliest = _creditCalculationService.earliestEnding(credits);
    final income = dashboard?.totalIncomeCents;
    final debtRatio = income == null
        ? null
        : _creditCalculationService.debtRatio(activeCredits: activeCredits, totalIncomeCents: income);
    final currentDashboard = dashboard;
    final remaining = currentDashboard == null
        ? null
        : _householdFinanceService.structuralRemainingCents(
            totalIncomeCents: currentDashboard.totalIncomeCents,
            totalFixedExpensesExcludingCreditsCents: currentDashboard.totalFixedExpensesExcludingCreditsCents,
            activeCredits: activeCredits,
          );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SummaryLine(label: 'Capital restant total', value: formatCentsAsEuro(totalCapital)),
            _SummaryLine(label: 'Mensualités totales', value: '${formatCentsAsEuro(totalPayments)}/mois'),
            _SummaryLine(
              label: 'Taux d\'endettement actuel',
              value: debtRatio == null ? '—' : '${(debtRatio * 100).round()} %',
            ),
            _SummaryLine(
              label: 'Reste à vivre actuel',
              value: remaining == null ? '—' : '${formatCentsAsEuro(remaining)}/mois',
            ),
            _SummaryLine(label: activeCount > 1 ? 'Crédits actifs' : 'Crédit actif', value: '$activeCount'),
            _SummaryLine(
              label: 'Prochain crédit terminé',
              value: earliest == null ? '—' : '${earliest.name} — dans ${earliest.remainingInstallments} mois',
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _IndicatorData {
  final String emoji;
  final String title;
  final String creditName;
  final List<String> valueLines;
  const _IndicatorData({
    required this.emoji,
    required this.title,
    required this.creditName,
    required this.valueLines,
  });
}

class _IndicatorsSection extends StatelessWidget {
  final List<CreditEntity> credits;
  const _IndicatorsSection({required this.credits});

  @override
  Widget build(BuildContext context) {
    final earliest = _creditCalculationService.earliestEnding(credits);
    final highestPayment = _creditCalculationService.highestMonthlyPaymentCredit(credits);
    final highestRate = _creditCalculationService.highestRateCredit(credits);
    final highestCapital = _creditCalculationService.highestRemainingCapitalCredit(credits);

    final indicators = <_IndicatorData>[
      if (earliest != null)
        _IndicatorData(
          emoji: '🏁',
          title: "Crédit le plus proche d'être terminé",
          creditName: earliest.name,
          valueLines: [
            formatCentsAsEuro(earliest.remainingCapitalCents),
            '${earliest.remainingInstallments} mensualité'
                '${earliest.remainingInstallments > 1 ? 's' : ''} restante'
                '${earliest.remainingInstallments > 1 ? 's' : ''}',
          ],
        ),
      if (highestPayment != null)
        _IndicatorData(
          emoji: '💰',
          title: 'Plus grosse mensualité',
          creditName: highestPayment.name,
          valueLines: ['${formatCentsAsEuro(highestPayment.monthlyPaymentCents)}/mois'],
        ),
      _IndicatorData(
        emoji: '📈',
        title: 'Crédit le plus coûteux',
        creditName: highestRate?.name ?? 'Taux non renseigné',
        valueLines: highestRate == null ? const [] : ['${highestRate.annualRatePercent} %'],
      ),
      if (highestCapital != null)
        _IndicatorData(
          emoji: '🏦',
          title: 'Plus gros capital restant',
          creditName: highestCapital.name,
          valueLines: [formatCentsAsEuro(highestCapital.remainingCapitalCents)],
        ),
    ];

    if (indicators.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Indicateurs', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [for (final data in indicators) _IndicatorCard(data: data)],
        ),
      ],
    );
  }
}

class _IndicatorCard extends StatelessWidget {
  final _IndicatorData data;
  const _IndicatorCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 172,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${data.emoji} ${data.title}',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(data.creditName, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          for (final line in data.valueLines) ...[
            const SizedBox(height: 2),
            Text(line, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}

class _SortSelector extends StatelessWidget {
  final _SortMode selected;
  final ValueChanged<_SortMode> onChanged;
  const _SortSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'À toi de choisir ta priorité.',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              ChoiceChip(
                label: const Text('Par défaut'),
                selected: selected == _SortMode.none,
                onSelected: (_) => onChanged(_SortMode.none),
              ),
              const SizedBox(width: AppSpacing.xs),
              ChoiceChip(
                label: const Text('Plus facile à solder'),
                selected: selected == _SortMode.lowestCapital,
                onSelected: (_) => onChanged(_SortMode.lowestCapital),
              ),
              const SizedBox(width: AppSpacing.xs),
              ChoiceChip(
                label: const Text('Plus coûteux'),
                selected: selected == _SortMode.highestRate,
                onSelected: (_) => onChanged(_SortMode.highestRate),
              ),
              const SizedBox(width: AppSpacing.xs),
              ChoiceChip(
                label: const Text('Plus grosse mensualité libérée'),
                selected: selected == _SortMode.highestPayment,
                onSelected: (_) => onChanged(_SortMode.highestPayment),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CreditCard extends StatelessWidget {
  final CreditEntity credit;
  const _CreditCard({required this.credit});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = creditColorFor(credit);
    final icon = creditIconFor(credit);
    final stars = _creditCalculationService.priorityStars(credit);
    final priorityLabel = _creditCalculationService.priorityLabel(credit);
    final pace = _creditCalculationService.creditPace(credit);
    final paceLabel = _creditCalculationService.creditPaceLabel(credit);
    final paceColor = creditPaceColor(pace);
    final paceEmoji = creditPaceEmoji(pace);
    final organisme = credit.organisme;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: () => Navigator.of(context).push(AppPageRoute(builder: (_) => CreditDetailPage(credit: credit))),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.2), shape: BoxShape.circle),
                    child: Icon(icon, size: 18, color: color),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(credit.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.1)),
                        if (organisme != null && organisme.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(organisme,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: colorScheme.onSurfaceVariant)),
                          ),
                      ],
                    ),
                  ),
                  if (!credit.isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                      decoration: BoxDecoration(
                        color: colorScheme.outline.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                      ),
                      child: Text('Terminé',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: colorScheme.outline, fontWeight: FontWeight.w600)),
                    )
                  else
                    Icon(Icons.chevron_right_rounded, size: 20, color: colorScheme.onSurfaceVariant),
                ],
              ),
              if (credit.isActive) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
                  decoration: BoxDecoration(
                    color: paceColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  child: Text('$paceEmoji $paceLabel',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: paceColor, fontWeight: FontWeight.w600)),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: _MiniStat(label: 'Capital restant', value: formatCentsAsEuro(credit.remainingCapitalCents)),
                  ),
                  Expanded(
                    child: _MiniStat(label: 'Mensualité', value: formatCentsAsEuro(credit.monthlyPaymentCents)),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _MiniStat(label: 'Mois restants', value: '${credit.remainingInstallments}'),
                  ),
                  Expanded(
                    child: _MiniStat(label: 'Fin prévue', value: formatDayMonthFr(credit.expectedEndDate)),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.sm),
                child: LinearProgressIndicator(
                  value: credit.repaidProgress,
                  minHeight: 8,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  color: color,
                ),
              ),
              if (credit.isActive) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    for (var i = 0; i < 5; i++)
                      Icon(
                        i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: 14,
                        color: i < stars ? color : colorScheme.outlineVariant,
                      ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(priorityLabel,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant)),
        Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
