import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatting/currency_formatter.dart';
import '../../core/providers/notifications_providers.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/local/database.dart';

/// Centre de notifications (V0.9) : historique persistant de tout ce que
/// BudgetPilot a signalé — opérations à confirmer, crédits mis à jour ou
/// terminés — indépendamment de la permission système ou du bandeau
/// Android (déjà disparu ou jamais autorisé). L'historique est conservé.
class NotificationCenterPage extends ConsumerWidget {
  const NotificationCenterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(notificationLogsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: SafeArea(
        child: logsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => const Center(child: Text('Impossible de charger les notifications')),
          data: (logs) {
            if (logs.isEmpty) return const _EmptyNotificationCenter();
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: logs.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) => _NotificationRow(log: logs[index]),
            );
          },
        ),
      ),
    );
  }
}

class _EmptyNotificationCenter extends StatelessWidget {
  const _EmptyNotificationCenter();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none_rounded, size: 48, color: colorScheme.outline),
            const SizedBox(height: AppSpacing.lg),
            Text('Aucune notification', style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'BudgetPilot te préviendra ici de tes prélèvements et de tes crédits.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

(IconData, Color) _presentationFor(String type) {
  switch (type) {
    case 'credit_finished':
      return (Icons.celebration_rounded, CategoryColors.credit);
    case 'credit_auto_updated':
      return (Icons.account_balance_rounded, CategoryColors.credit);
    case 'big_charge_reminder':
      return (Icons.schedule_rounded, CategoryColors.fixedExpense);
    case 'evening_reminder':
      return (Icons.nightlight_round, CategoryColors.fixedExpense);
    case 'morning_summary':
    default:
      return (Icons.today_rounded, CategoryColors.income);
  }
}

class _NotificationRow extends ConsumerWidget {
  final NotificationLog log;
  const _NotificationRow({required this.log});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final (icon, color) = _presentationFor(log.type);

    return Card(
      margin: EdgeInsets.zero,
      color: log.read ? null : Color.alphaBlend(color.withValues(alpha: 0.06), colorScheme.surfaceContainerHigh),
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.16), shape: BoxShape.circle),
          child: Icon(icon, size: 18, color: color),
        ),
        title: Text(log.title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        subtitle: Text(log.body, style: Theme.of(context).textTheme.bodySmall),
        trailing: Text(formatDayMonthFr(log.createdAt),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant)),
      ),
    );
  }
}
