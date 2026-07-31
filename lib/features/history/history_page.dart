import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatting/currency_formatter.dart';
import '../../core/providers/entries_providers.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/staggered_fade_in.dart';
import '../../data/local/database.dart';

/// Onglet "Historique" : cycle courant et cycles passés.
class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cyclesAsync = ref.watch(allCyclesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Historique des cycles')),
      body: SafeArea(
        child: cyclesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => const Center(child: Text("Impossible de charger l'historique")),
          data: (cycles) {
            if (cycles.isEmpty) {
              return const Center(child: Text('Aucun cycle pour le moment'));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: cycles.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) => StaggeredFadeIn(
                index: index,
                child: _CycleCard(cycle: cycles[index]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CycleCard extends StatelessWidget {
  final BudgetCycle cycle;
  const _CycleCard({required this.cycle});

  @override
  Widget build(BuildContext context) {
    final isCurrent = cycle.status == 'ouvert';
    final title = (cycle.name == null || cycle.name!.isEmpty)
        ? '${formatDayMonthFr(cycle.startDate)} → ${formatDayMonthFr(cycle.endDate)}'
        : cycle.name!;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: (isCurrent ? colorScheme.primary : colorScheme.outline).withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCurrent ? Icons.play_circle_outline : Icons.check_circle_outline,
                size: 17,
                color: isCurrent ? colorScheme.primary : colorScheme.outline,
              ),
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
                  Text('${formatDayMonthFr(cycle.startDate)} → ${formatDayMonthFr(cycle.endDate)}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            if (isCurrent)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Text('En cours',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.w600)),
              ),
          ],
        ),
      ),
    );
  }
}
