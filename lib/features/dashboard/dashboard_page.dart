import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatting/currency_formatter.dart';
import '../../core/providers/dashboard_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/charge_status_presentation.dart';
import '../../core/theme/design_tokens.dart';
import '../../domain/entities/fixed_expense_entity.dart';
import '../../domain/models/dashboard_view_data.dart';
import '../charges/charges_page.dart';
import '../cycle/cycle_creation_page.dart';
import '../entries/incomes_list_page.dart';
import '../entries/savings_list_page.dart';
import 'widgets/add_entry_fab.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardProvider);
    final data = dashboardAsync.valueOrNull;

    return Scaffold(
      body: SafeArea(
        child: dashboardAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => _ErrorState(error: error),
          data: (data) => data == null ? const _EmptyState() : _DashboardContent(data: data),
        ),
      ),
      floatingActionButton: data == null ? null : AddEntryFab(cycleId: data.cycleId),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.savings_outlined, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text('Aucun cycle en cours',
                style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Créez votre premier cycle budgétaire pour commencer à saisir vos revenus, '
              'charges, dépenses et épargnes.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const CycleCreationPage(),
              )),
              child: const Text('Créer mon premier cycle'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Object error;
  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text('Impossible de charger le tableau de bord',
                style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('$error', style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

/// Contenu principal du tableau de bord. Le contenu défile toujours
/// verticalement (ListView) et sa largeur est plafonnée sur les très grands
/// écrans (ex. Samsung Galaxy Fold déplié) pour éviter un étirement excessif,
/// sans jamais réduire le padding minimal sur petit écran.
class _DashboardContent extends StatelessWidget {
  final DashboardViewData data;
  const _DashboardContent({required this.data});

  static const double _maxContentWidth = 640;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding =
            math.max(AppSpacing.xl, (constraints.maxWidth - _maxContentWidth) / 2);

        return ListView(
          padding: EdgeInsets.fromLTRB(
              horizontalPadding, AppSpacing.lg, horizontalPadding, 100),
          children: [
            const _DashboardHeader(),
            const SizedBox(height: AppSpacing.xxl),
            _ArgentLibreCard(data: data),
            const SizedBox(height: AppSpacing.xxl),
            Text('Résumé du cycle', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            _CycleSummaryGrid(data: data),
            const SizedBox(height: AppSpacing.xxl),
            _UpcomingChargesSection(data: data),
            if (data.declaredBankBalanceCents != null) ...[
              const SizedBox(height: AppSpacing.lg),
              _DeclaredBalanceRow(cents: data.declaredBankBalanceCents!),
            ],
          ],
        );
      },
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Bonjour Jérémy 👋',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Voici ta situation financière',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        IconButton.filledTonal(
          tooltip: 'Notifications',
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Aucune nouvelle notification')),
          ),
          icon: const Icon(Icons.notifications_none_rounded),
        ),
      ],
    );
  }
}

/// Grande carte "Argent Libre" — dégradé or premium construit entièrement
/// en widgets Flutter (aucune image), badge de situation dynamique.
class _ArgentLibreCard extends StatelessWidget {
  final DashboardViewData data;
  const _ArgentLibreCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final statusColor = AppTheme.colorForRemainingRatio(data.remainingRatio);
    final statusLabel = AppTheme.statusLabelForRemainingRatio(data.remainingRatio);
    final accent = GoldGradient.accentForBrightness(brightness);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xxl, AppSpacing.xxl, AppSpacing.xxl, AppSpacing.xl),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.xl),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: GoldGradient.forBrightness(brightness),
        ),
        boxShadow: AppShadows.card(brightness),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'ARGENT LIBRE',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(letterSpacing: 3, color: accent, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppSpacing.md),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  formatCentsAsEuro(data.realRemainingCents),
                  style: Theme.of(context)
                      .textTheme
                      .displayMedium
                      ?.copyWith(fontWeight: FontWeight.bold, color: accent),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Text(
                  statusLabel,
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: statusColor, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                "Disponible jusqu'au ${formatDayMonthFr(data.cycleEnd)}",
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: accent.withValues(alpha: 0.85)),
              ),
            ],
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Opacity(
              opacity: 0.55,
              child: Text('👑', style: TextStyle(fontSize: 22, color: accent)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CycleSummaryGrid extends StatelessWidget {
  final DashboardViewData data;
  const _CycleSummaryGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    final items = <_SummaryItem>[
      _SummaryItem(
        label: 'Revenus',
        subtext: 'Ce cycle',
        cents: data.totalIncomeCents,
        icon: Icons.trending_up_rounded,
        color: CategoryColors.income,
        onTap: (ctx) => Navigator.of(ctx).push(MaterialPageRoute(
          builder: (_) => IncomesListPage(cycleId: data.cycleId),
        )),
      ),
      _SummaryItem(
        label: 'Charges',
        subtext: 'Réservées',
        cents: data.totalFixedExpensesCents,
        icon: Icons.receipt_long_rounded,
        color: CategoryColors.fixedExpense,
      ),
      _SummaryItem(
        label: 'Dépenses',
        subtext: 'Ce cycle',
        cents: data.totalVariableExpensesCents,
        icon: Icons.shopping_bag_rounded,
        color: CategoryColors.variableExpense,
      ),
      _SummaryItem(
        label: 'Épargnes',
        subtext: 'Réservée',
        cents: data.totalSavingsCents,
        icon: Icons.savings_rounded,
        color: CategoryColors.saving,
        onTap: (ctx) => Navigator.of(ctx).push(MaterialPageRoute(
          builder: (_) => SavingsListPage(cycleId: data.cycleId),
        )),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        mainAxisExtent: 108,
      ),
      itemBuilder: (context, index) => _SummaryTile(item: items[index]),
    );
  }
}

class _SummaryItem {
  final String label;
  final String subtext;
  final int cents;
  final IconData icon;
  final Color color;
  final void Function(BuildContext context)? onTap;

  const _SummaryItem({
    required this.label,
    required this.subtext,
    required this.cents,
    required this.icon,
    required this.color,
    this.onTap,
  });
}

class _SummaryTile extends StatelessWidget {
  final _SummaryItem item;
  const _SummaryTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final content = Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: item.color.withValues(alpha: 0.18), shape: BoxShape.circle),
            child: Icon(item.icon, color: item.color, size: 18),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                Text(formatCentsAsEuro(item.cents),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                Text(item.subtext,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );

    if (item.onTap == null) return content;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.md),
      onTap: () => item.onTap!(context),
      child: content,
    );
  }
}

/// Section "Prochaines échéances" — remplace l'ancienne section "À
/// surveiller" par un affichage direct des 3 prochaines charges fixes non
/// confirmées, avec accès à la liste complète.
class _UpcomingChargesSection extends StatelessWidget {
  final DashboardViewData data;
  const _UpcomingChargesSection({required this.data});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Prochaines échéances', style: Theme.of(context).textTheme.titleMedium),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const ChargesPage(),
                  )),
                  child: const Text('Voir toutes'),
                ),
              ],
            ),
            if (data.upcomingCharges.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Row(
                  children: [
                    Icon(Icons.task_alt_rounded, color: colorScheme.onSurfaceVariant, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Aucune échéance à venir',
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              )
            else
              for (final charge in data.upcomingCharges) _UpcomingChargeTile(charge: charge),
          ],
        ),
      ),
    );
  }
}

class _UpcomingChargeTile extends StatelessWidget {
  final FixedExpenseEntity charge;
  const _UpcomingChargeTile({required this.charge});

  @override
  Widget build(BuildContext context) {
    final presentation = ChargeStatusPresentation.of(charge.status, context);
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(presentation.icon, size: 18, color: presentation.color),
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
                Text('${formatDayMonthFr(charge.expectedDate)} · ${presentation.label}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(formatCentsAsEuro(charge.effectiveAmountCents),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _DeclaredBalanceRow extends StatelessWidget {
  final int cents;
  const _DeclaredBalanceRow({required this.cents});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Icon(Icons.account_balance_outlined, size: 16, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            'Solde bancaire déclaré : ${formatCentsAsEuro(cents)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
