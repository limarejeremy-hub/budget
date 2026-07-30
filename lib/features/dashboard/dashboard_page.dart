import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatting/currency_formatter.dart';
import '../../core/providers/dashboard_providers.dart';
import '../../core/providers/database_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/local/demo_data_seeder.dart';
import '../../domain/models/dashboard_view_data.dart';
import 'widgets/add_entry_fab.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardProvider);

    return Scaffold(
      body: SafeArea(
        child: dashboardAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => _ErrorState(error: error),
          data: (data) => data == null ? const _EmptyState() : _DashboardContent(data: data),
        ),
      ),
      floatingActionButton: const AddEntryFab(),
    );
  }
}

class _EmptyState extends ConsumerWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              'Chargez les données de démonstration pour découvrir BudgetPilot.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                final db = ref.read(appDatabaseProvider);
                await DemoDataSeeder(db).seedIfEmpty();
              },
              child: const Text('Charger les données de démonstration'),
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

class _DashboardContent extends StatelessWidget {
  final DashboardViewData data;
  const _DashboardContent({required this.data});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
      children: [
        _RealRemainingCard(data: data),
        const SizedBox(height: 24),
        _CycleSummaryGrid(data: data),
        const SizedBox(height: 24),
        _WatchListSection(data: data),
        if (data.declaredBankBalanceCents != null) ...[
          const SizedBox(height: 16),
          _DeclaredBalanceRow(cents: data.declaredBankBalanceCents!),
        ],
      ],
    );
  }
}

class _RealRemainingCard extends StatelessWidget {
  final DashboardViewData data;
  const _RealRemainingCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.colorForRemainingRatio(data.remainingRatio);
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          children: [
            Text(
              'ARGENT LIBRE',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(letterSpacing: 2, color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Text(
              formatCentsAsEuro(data.realRemainingCents),
              style: Theme.of(context)
                  .textTheme
                  .displaySmall
                  ?.copyWith(fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              "Disponible jusqu'au ${formatDayMonthFr(data.cycleEnd)}",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _CycleSummaryGrid extends StatelessWidget {
  final DashboardViewData data;
  const _CycleSummaryGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Revenus du cycle', data.totalIncomeCents),
      ('Charges fixes réservées', data.totalFixedExpensesCents),
      ('Dépenses variables', data.totalVariableExpensesCents),
      ('Épargne réservée', data.totalSavingsCents),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [for (final (label, cents) in items) _SummaryTile(label: label, cents: cents)],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final int cents;
  const _SummaryTile({required this.label, required this.cents});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(formatCentsAsEuro(cents),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _WatchListSection extends StatelessWidget {
  final DashboardViewData data;
  const _WatchListSection({required this.data});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final next = data.nextChargeToCheck;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('À surveiller', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(
              data.unconfirmedChargesCount == 0
                  ? 'Aucun prélèvement à vérifier'
                  : '${data.unconfirmedChargesCount} prélèvement${data.unconfirmedChargesCount > 1 ? 's' : ''} '
                      'restent à vérifier — ${formatCentsAsEuro(data.unconfirmedChargesTotalCents)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (next != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.schedule, size: 18, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${next.name} — ${formatCentsAsEuro(next.expectedAmountCents)} — ${formatDayMonthFr(next.expectedDate)}',
                      style:
                          Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
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
