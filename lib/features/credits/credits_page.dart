import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatting/currency_formatter.dart';
import '../../core/providers/credits_providers.dart';
import '../../core/routing/app_page_route.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/staggered_fade_in.dart';
import '../../domain/calculations/credit_calculation_service.dart';
import '../../domain/entities/credit_entity.dart';
import 'credit_detail_page.dart';
import 'credit_form_page.dart';

const _creditCalculationService = CreditCalculationService();

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

    return Scaffold(
      appBar: AppBar(title: const Text('Crédits')),
      body: SafeArea(
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
                _CreditsSummaryHeader(credits: credits),
                const SizedBox(height: AppSpacing.lg),
                _IndicatorsSection(credits: credits),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(AppPageRoute(builder: (_) => const CreditFormPage())),
        child: const Icon(Icons.add),
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

class _CreditsSummaryHeader extends StatelessWidget {
  final List<CreditEntity> credits;
  const _CreditsSummaryHeader({required this.credits});

  @override
  Widget build(BuildContext context) {
    final totalCapital = _creditCalculationService.totalRemainingCapital(credits);
    final totalPayments = _creditCalculationService.totalMonthlyPayments(credits);
    final activeCount = _creditCalculationService.activeCount(credits);
    final latestEnd = _creditCalculationService.latestActiveEndDate(credits);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SummaryLine(label: 'Capital restant total', value: formatCentsAsEuro(totalCapital)),
            _SummaryLine(label: 'Mensualités totales', value: '${formatCentsAsEuro(totalPayments)}/mois'),
            _SummaryLine(
                label: activeCount > 1 ? 'Crédits actifs' : 'Crédit actif', value: '$activeCount'),
            _SummaryLine(
              label: 'Fin estimée de tous les crédits',
              value: latestEnd == null ? '—' : formatDayMonthFr(latestEnd),
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
          Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _IndicatorsSection extends StatelessWidget {
  final List<CreditEntity> credits;
  const _IndicatorsSection({required this.credits});

  @override
  Widget build(BuildContext context) {
    final earliest = _creditCalculationService.earliestEnding(credits);
    final lowestCapital = _creditCalculationService.lowestRemainingCapitalCredit(credits);
    final highestPayment = _creditCalculationService.highestMonthlyPaymentCredit(credits);
    final highestRate = _creditCalculationService.highestRateCredit(credits);

    final indicators = <(IconData, String, String)>[
      if (earliest != null) (Icons.flag_rounded, 'Le plus proche de la fin', earliest.name),
      if (lowestCapital != null)
        (Icons.trending_down_rounded, 'Capital restant le plus faible', lowestCapital.name),
      if (highestPayment != null)
        (Icons.payments_rounded, 'Mensualité la plus élevée', highestPayment.name),
      (
        Icons.percent_rounded,
        'Taux le plus élevé',
        highestRate?.name ?? 'Taux non renseigné',
      ),
    ];

    if (indicators.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Indicateurs', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        for (final (icon, label, value) in indicators) _IndicatorRow(icon: icon, label: label, value: value),
      ],
    );
  }
}

class _IndicatorRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _IndicatorRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 16, color: CategoryColors.credit),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
          ),
          Text(value, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
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

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: () => Navigator.of(context).push(AppPageRoute(builder: (_) => CreditDetailPage(credit: credit))),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(credit.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
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
              const SizedBox(height: AppSpacing.sm),
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
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                        label: 'Mois restants', value: '${credit.remainingInstallments}'),
                  ),
                  Expanded(
                    child: _MiniStat(label: 'Fin prévue', value: formatDayMonthFr(credit.expectedEndDate)),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.sm),
                child: LinearProgressIndicator(
                  value: credit.repaidProgress,
                  minHeight: 6,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  color: CategoryColors.credit,
                ),
              ),
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
