import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/formatting/currency_formatter.dart';
import '../../core/providers/dashboard_providers.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/routing/app_page_route.dart';
import '../../core/widgets/euro_amount_field.dart';
import '../../domain/calculations/credit_auto_update_service.dart';
import '../../domain/calculations/pending_confirmations.dart';
import '../../domain/entities/fixed_expense_entity.dart';
import '../notifications/notification_center_page.dart';

/// Centre de confirmation des opérations du jour (V0.9) — ouvert depuis la
/// carte "Aujourd'hui" du tableau de bord. Chaque ligne permet de
/// confirmer, modifier le montant réel, reporter ou ignorer une charge sans
/// quitter cette page. Confirmer une charge liée à un crédit décrémente
/// automatiquement son capital et ses mensualités restantes, sans autre
/// intervention.
class ConfirmationsPage extends ConsumerWidget {
  const ConfirmationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirmations'),
        actions: [
          IconButton(
            tooltip: 'Centre de notifications',
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () =>
                Navigator.of(context).push(AppPageRoute(builder: (_) => const NotificationCenterPage())),
          ),
        ],
      ),
      body: SafeArea(
        child: dashboardAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => const Center(child: Text('Impossible de charger les opérations')),
          data: (data) {
            if (data == null) return const _EmptyConfirmations();
            final pending = pendingConfirmations(data);
            if (pending.isEmpty) return const _EmptyConfirmations();

            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: pending.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) => _ConfirmationCard(charge: pending[index]),
            );
          },
        ),
      ),
    );
  }
}

class _EmptyConfirmations extends StatelessWidget {
  const _EmptyConfirmations();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline_rounded, size: 48, color: colorScheme.outline),
            const SizedBox(height: AppSpacing.lg),
            Text('Tout est confirmé',
                style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(
              "Aucune opération n'attend de confirmation aujourd'hui.",
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmationCard extends ConsumerWidget {
  final FixedExpenseEntity charge;
  const _ConfirmationCard({required this.charge});

  Future<void> _applyCreditNotification(WidgetRef ref, CreditAutoUpdateResult? result) async {
    if (result == null) return;
    final notifications = ref.read(notificationServiceProvider);
    if (result.finished) {
      await notifications.showCreditFinished(result.credit);
    } else {
      await notifications.showCreditAutoUpdated(result.credit);
    }
  }

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(cycleRepositoryProvider);
    final result = await repository.confirmFixedExpense(charge.id);
    await _applyCreditNotification(ref, result);
    messenger.showSnackBar(const SnackBar(content: Text('Opération confirmée')));
  }

  Future<void> _editAmount(BuildContext context, WidgetRef ref) async {
    final confirmedCents = await showDialog<int>(
      context: context,
      builder: (dialogContext) => _EditAmountDialog(initialCents: charge.effectiveAmountCents),
    );
    if (confirmedCents == null || confirmedCents <= 0 || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(cycleRepositoryProvider);
    final result = await repository.confirmFixedExpense(charge.id, actualAmountCents: confirmedCents);
    await _applyCreditNotification(ref, result);
    messenger.showSnackBar(const SnackBar(content: Text('Montant réel enregistré')));
  }

  Future<void> _postpone(WidgetRef ref) => ref.read(cycleRepositoryProvider).postponeFixedExpense(charge.id);

  Future<void> _ignore(WidgetRef ref) =>
      ref.read(cycleRepositoryProvider).updateFixedExpenseStatus(charge.id, ChargeStatus.suspendue);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(charge.name, style: Theme.of(context).textTheme.titleMedium)),
                Text(formatCentsAsEuro(charge.effectiveAmountCents),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(formatDayMonthFr(charge.expectedDate),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
            if (charge.isLinkedToCredit) ...[
              const SizedBox(height: AppSpacing.xs),
              Text('Mensualité de crédit',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: CategoryColors.credit)),
            ],
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _ActionButton(
                  icon: Icons.check_circle_rounded,
                  label: 'Confirmer',
                  color: CategoryColors.income,
                  onTap: () => _confirm(context, ref),
                ),
                _ActionButton(
                  icon: Icons.edit_rounded,
                  label: 'Modifier',
                  color: colorScheme.primary,
                  onTap: () => _editAmount(context, ref),
                ),
                _ActionButton(
                  icon: Icons.schedule_rounded,
                  label: 'Reporter',
                  color: CategoryColors.fixedExpense,
                  onTap: () => _postpone(ref),
                ),
                _ActionButton(
                  icon: Icons.close_rounded,
                  label: 'Ignorer',
                  color: colorScheme.error,
                  onTap: () => _ignore(ref),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Boîte de dialogue "Montant réel" — un `StatefulWidget` dédié plutôt
/// qu'un contrôleur créé en dehors de l'arbre de widgets : `dispose()` est
/// alors appelé par le framework au bon moment (après la fin de
/// l'animation de fermeture), jamais pendant qu'elle est encore affichée.
class _EditAmountDialog extends StatefulWidget {
  final int initialCents;
  const _EditAmountDialog({required this.initialCents});

  @override
  State<_EditAmountDialog> createState() => _EditAmountDialogState();
}

class _EditAmountDialogState extends State<_EditAmountDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: (widget.initialCents / 100).toStringAsFixed(2));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Montant réel'),
      content: EuroAmountField(controller: _controller, label: 'Montant confirmé'),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(EuroAmountField.parseCents(_controller.text)),
          child: const Text('Confirmer'),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.sm),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 2),
            Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}
