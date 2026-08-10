import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatting/currency_formatter.dart';
import '../../core/providers/dashboard_providers.dart';
import '../../core/routing/app_page_route.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/charge_status_presentation.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/animated_amount.dart';
import '../../core/widgets/brand_badge.dart';
import '../../core/widgets/budgetpilot_logo.dart';
import '../../core/widgets/emv_chip.dart';
import '../../core/widgets/premium_tap_card.dart';
import '../../core/widgets/shimmer_sheen.dart';
import '../../core/widgets/staggered_fade_in.dart';
import '../../domain/entities/fixed_expense_entity.dart';
import '../../domain/models/dashboard_view_data.dart';
import '../charges/charge_detail_sheet.dart';
import '../charges/charges_page.dart';
import '../credits/widgets/credit_advice_card.dart';
import '../credits/widgets/credits_summary_card.dart';
import '../cycle/cycle_creation_page.dart';
import '../cycle/cycle_detail_page.dart';
import '../entries/incomes_list_page.dart';
import '../entries/savings_list_page.dart';
import '../expenses/variable_expenses_page.dart';
import '../projects/widgets/project_priority_card.dart';
import '../watchlist/watchlist_page.dart';
import 'widgets/add_entry_fab.dart';
import 'widgets/cycle_progress_bar.dart';
import 'widgets/this_week_section.dart';
import 'widgets/today_section.dart';

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
            Text('Aucun cycle en cours', style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Créez votre premier cycle budgétaire pour commencer à saisir vos revenus, '
              'charges, dépenses et épargnes.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).push(AppPageRoute(
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
        final horizontalPadding = math.max(AppSpacing.xl, (constraints.maxWidth - _maxContentWidth) / 2);

        return ListView(
          padding: EdgeInsets.fromLTRB(horizontalPadding, AppSpacing.lg, horizontalPadding, 100),
          children: [
            _DashboardHeader(cycleId: data.cycleId),
            const SizedBox(height: AppSpacing.xxl),
            _ArgentLibreCard(data: data),
            const SizedBox(height: AppSpacing.lg),
            CycleProgressBar(data: data),
            const SizedBox(height: AppSpacing.xxl),
            TodaySection(data: data),
            const SizedBox(height: AppSpacing.lg),
            ThisWeekSection(data: data),
            const SizedBox(height: AppSpacing.xxl),
            Text('Résumé du cycle', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            _CycleSummaryGrid(data: data),
            const SizedBox(height: AppSpacing.xl),
            const CreditsSummaryCard(),
            const SizedBox(height: AppSpacing.lg),
            const CreditAdviceCard(),
            const SizedBox(height: AppSpacing.lg),
            const ProjectPriorityCard(),
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
  final int cycleId;
  const _DashboardHeader({required this.cycleId});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        const BudgetPilotBadge(diameter: 40),
        const SizedBox(width: AppSpacing.md),
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
          tooltip: 'Éléments à surveiller',
          onPressed: () => Navigator.of(context).push(AppPageRoute(
            builder: (_) => WatchlistPage(cycleId: cycleId),
          )),
          icon: const Icon(Icons.notifications_none_rounded),
        ),
      ],
    );
  }
}

/// Grande carte "Argent Libre" — la signature visuelle de BudgetPilot.
/// Métal brossé or, texture discrète, reflet, marque vectorielle
/// BudgetPilot (aucune image, aucun emoji), montant animé, badge de
/// situation dynamique. Cliquable (avec léger effet au toucher) : ouvre le
/// détail complet du cycle.
class _ArgentLibreCard extends StatelessWidget {
  final DashboardViewData data;
  const _ArgentLibreCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final statusColor = AppTheme.colorForRemainingRatio(data.remainingRatio);
    final statusLabel = AppTheme.statusLabelForRemainingRatio(data.remainingRatio);
    final statusIcon = AppTheme.statusIconForRemainingRatio(data.remainingRatio);
    final accent = GoldGradient.accentForBrightness(brightness);

    return PremiumTapCard(
      onTap: () => Navigator.of(context).push(AppPageRoute(
        builder: (_) => CycleDetailPage(data: data),
      )),
      borderRadius: BorderRadius.circular(AppRadii.xl),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.xl),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: GoldGradient.forBrightness(brightness),
        ),
        boxShadow: AppShadows.card(brightness),
      ),
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.xxl, AppSpacing.xxl, AppSpacing.xl),
          child: Stack(
            children: [
              // Texture métal brossé : fines rayures diagonales à très
              // faible opacité, purement décoratives.
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _BrushedMetalPainter(brightness)),
                ),
              ),
              // Reflet subtil : bande diagonale semi-transparente en haut de
              // la carte, pour un effet premium sans image.
              Positioned.fill(
                child: IgnorePointer(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: FractionallySizedBox(
                      widthFactor: 1,
                      heightFactor: 0.45,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(AppRadii.xl),
                            topRight: Radius.circular(AppRadii.xl),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: brightness == Brightness.dark ? 0.07 : 0.38),
                              Colors.white.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const Positioned.fill(child: ShimmerSheen(borderRadius: AppRadii.xl)),
              Positioned(
                top: 2,
                left: 0,
                child: EmvChip(width: 32, color: accent),
              ),
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
                    child: AnimatedAmount(
                      cents: data.realRemainingCents,
                      style: Theme.of(context)
                          .textTheme
                          .displayMedium
                          ?.copyWith(fontWeight: FontWeight.bold, color: accent),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 15, color: statusColor),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          statusLabel,
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(color: statusColor, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    "Disponible jusqu'au ${formatDayMonthFr(data.cycleEnd)}",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: accent.withValues(alpha: 0.85)),
                  ),
                ],
              ),
              Positioned(
                top: 2,
                right: 0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'PREMIUM',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: accent.withValues(alpha: 0.55),
                            letterSpacing: 2,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    BudgetPilotMark(size: 20, color: accent.withValues(alpha: 0.65)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fines rayures diagonales évoquant un métal brossé — purement décoratif,
/// coût de rendu négligeable (une vingtaine de lignes).
class _BrushedMetalPainter extends CustomPainter {
  final Brightness brightness;
  const _BrushedMetalPainter(this.brightness);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: brightness == Brightness.dark ? 0.025 : 0.09)
      ..strokeWidth = 1;
    const spacing = 10.0;
    final diagonal = size.width + size.height;
    for (double offset = -size.height; offset < diagonal; offset += spacing) {
      canvas.drawLine(Offset(offset, 0), Offset(offset - size.height, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BrushedMetalPainter oldDelegate) => oldDelegate.brightness != brightness;
}

/// "1 revenu" / "3 prélèvements" — jamais de pourcentage sous les cartes du
/// résumé du cycle, uniquement un décompte lisible.
String _countLabel(int count, String singular, String plural) => '$count ${count > 1 ? plural : singular}';

class _CycleSummaryGrid extends StatelessWidget {
  final DashboardViewData data;
  const _CycleSummaryGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    final items = <_SummaryItem>[
      _SummaryItem(
        label: 'Revenus',
        subtext: _countLabel(data.incomesCount, 'revenu', 'revenus'),
        cents: data.totalIncomeCents,
        icon: Icons.trending_up_rounded,
        color: CategoryColors.income,
        onTap: (ctx) => Navigator.of(ctx).push(AppPageRoute(
          builder: (_) => IncomesListPage(cycleId: data.cycleId),
        )),
      ),
      _SummaryItem(
        label: 'Charges',
        subtext: _countLabel(data.fixedExpensesCount, 'prélèvement', 'prélèvements'),
        cents: data.totalFixedExpensesCents,
        icon: Icons.receipt_long_rounded,
        color: CategoryColors.fixedExpense,
        onTap: (ctx) => Navigator.of(ctx).push(AppPageRoute(
          builder: (_) => const ChargesPage(),
        )),
      ),
      _SummaryItem(
        label: 'Dépenses',
        subtext: _countLabel(data.variableExpensesCount, 'dépense', 'dépenses'),
        cents: data.totalVariableExpensesCents,
        icon: Icons.shopping_bag_rounded,
        color: CategoryColors.variableExpense,
        onTap: (ctx) => Navigator.of(ctx).push(AppPageRoute(
          builder: (_) => const VariableExpensesPage(),
        )),
      ),
      _SummaryItem(
        label: 'Épargnes',
        subtext: _countLabel(data.savingsCount, 'épargne', 'épargnes'),
        cents: data.totalSavingsCents,
        icon: Icons.savings_rounded,
        color: CategoryColors.saving,
        onTap: (ctx) => Navigator.of(ctx).push(AppPageRoute(
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
        mainAxisExtent: 96,
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
  final void Function(BuildContext context) onTap;

  const _SummaryItem({
    required this.label,
    required this.subtext,
    required this.cents,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class _SummaryTile extends StatelessWidget {
  final _SummaryItem item;
  const _SummaryTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final brightness = Theme.of(context).brightness;
    final tintedBackground = Color.alphaBlend(
      item.color.withValues(alpha: brightness == Brightness.dark ? 0.14 : 0.09),
      colorScheme.surfaceContainerHigh,
    );

    return PremiumTapCard(
      color: tintedBackground,
      borderRadius: BorderRadius.circular(AppRadii.md),
      onTap: () => item.onTap(context),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: item.color.withValues(alpha: 0.2), shape: BoxShape.circle),
              child: Icon(item.icon, color: item.color, size: 17),
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
                  AnimatedAmount(
                    cents: item.cents,
                    style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(item.subtext,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Section "Prochaines échéances" — affiche directement les 3 prochaines
/// charges fixes non confirmées sous forme de vraies cartes (badge de
/// statut inclus). Chaque carte ouvre la fiche détaillée de la charge
/// (Modifier / Marquer comme prélevée / Dupliquer / Supprimer).
class _UpcomingChargesSection extends StatelessWidget {
  final DashboardViewData data;
  const _UpcomingChargesSection({required this.data});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Prochaines échéances', style: Theme.of(context).textTheme.titleMedium),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).push(AppPageRoute(
                builder: (_) => const ChargesPage(),
              )),
              child: const Text('Voir toutes'),
            ),
          ],
        ),
        if (data.upcomingCharges.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Icon(Icons.task_alt_rounded, color: colorScheme.onSurfaceVariant, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Aucune échéance à venir',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          for (final (index, charge) in data.upcomingCharges.indexed) ...[
            StaggeredFadeIn(
              index: index,
              child: _UpcomingChargeCard(charge: charge, cycleId: data.cycleId),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
      ],
    );
  }
}

class _UpcomingChargeCard extends StatelessWidget {
  final FixedExpenseEntity charge;
  final int cycleId;
  const _UpcomingChargeCard({required this.charge, required this.cycleId});

  @override
  Widget build(BuildContext context) {
    final presentation = ChargeStatusPresentation.of(charge.status, context);
    final colorScheme = Theme.of(context).colorScheme;

    return PremiumTapCard(
      color: colorScheme.surfaceContainerHigh,
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

class _DeclaredBalanceRow extends StatelessWidget {
  final int cents;
  const _DeclaredBalanceRow({required this.cents});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Couleur d'alerte discrète (le même orange que les charges, jamais le
    // rouge réservé aux cas réellement problématiques) quand le solde
    // déclaré est à découvert — information distincte de l'Argent libre.
    final color = cents < 0 ? CategoryColors.fixedExpense : colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Icon(Icons.account_balance_outlined, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            'Solde bancaire déclaré : ${formatCentsAsEuro(cents)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
