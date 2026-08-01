import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/formatting/currency_formatter.dart';
import '../../core/providers/dashboard_providers.dart';
import '../../core/routing/app_page_route.dart';
import '../../core/theme/charge_status_presentation.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/brand_badge.dart';
import '../../core/widgets/confirm_delete_dialog.dart';
import '../../domain/entities/fixed_expense_entity.dart';
import '../entries/fixed_expense_form_page.dart';
import 'widgets/delete_linked_charge_dialog.dart';

/// Ouvre la fiche détaillée d'une charge fixe : détail complet + actions
/// (Modifier, Marquer comme prélevée, Dupliquer, Supprimer).
Future<void> showChargeDetailSheet(
  BuildContext context, {
  required FixedExpenseEntity charge,
  required int cycleId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => ChargeDetailSheet(charge: charge, cycleId: cycleId),
  );
}

class ChargeDetailSheet extends ConsumerWidget {
  final FixedExpenseEntity charge;
  final int cycleId;
  const ChargeDetailSheet({super.key, required this.charge, required this.cycleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presentation = ChargeStatusPresentation.of(charge.status, context);
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                BrandBadge(
                  name: charge.name,
                  fallbackIcon: presentation.icon,
                  fallbackColor: presentation.color,
                  size: 40,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(charge.name, style: Theme.of(context).textTheme.titleLarge),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(formatCentsAsEuro(charge.effectiveAmountCents),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(Icons.event_rounded, size: 16, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: AppSpacing.xs),
                Text(formatDayMonthFr(charge.expectedDate),
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: colorScheme.onSurfaceVariant)),
                const SizedBox(width: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                  decoration: BoxDecoration(
                    color: presentation.color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(presentation.icon, size: 13, color: presentation.color),
                      const SizedBox(width: 4),
                      Text(presentation.label,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: presentation.color, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Modifier'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(AppPageRoute(
                  builder: (_) => FixedExpenseFormPage(cycleId: cycleId, existing: charge),
                ));
              },
            ),
            if (charge.status != ChargeStatus.prelevee)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.check_circle_outline_rounded),
                title: const Text('Marquer comme prélevée'),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await ref
                      .read(cycleRepositoryProvider)
                      .updateFixedExpenseStatus(charge.id, ChargeStatus.prelevee);
                  if (context.mounted) Navigator.of(context).pop();
                  messenger.showSnackBar(const SnackBar(content: Text('Charge marquée comme prélevée')));
                },
              ),
            // Une mensualité de crédit est unique par cycle (générée
            // automatiquement) — la dupliquer n'a pas de sens.
            if (!charge.isLinkedToCredit)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.copy_outlined),
                title: const Text('Dupliquer'),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await ref.read(cycleRepositoryProvider).createFixedExpense(
                        cycleId: cycleId,
                        name: charge.name,
                        expectedAmountCents: charge.expectedAmountCents,
                        expectedDate: charge.expectedDate,
                        categoryId: charge.categoryId,
                        isRecurring: charge.isRecurring,
                      );
                  if (context.mounted) Navigator.of(context).pop();
                  messenger.showSnackBar(const SnackBar(content: Text('Charge dupliquée')));
                },
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.delete_outline, color: colorScheme.error),
              title: Text('Supprimer', style: TextStyle(color: colorScheme.error)),
              onTap: () async {
                if (charge.isLinkedToCredit) {
                  final choice = await showDeleteLinkedChargeDialog(context, chargeName: charge.name);
                  if (choice == null || !context.mounted) return;
                  final repository = ref.read(cycleRepositoryProvider);
                  if (choice == DeleteLinkedChargeChoice.chargeOnly) {
                    await repository.deleteFixedExpense(charge.id);
                  } else {
                    await repository.deleteCredit(charge.linkedCreditId!);
                  }
                  if (context.mounted) Navigator.of(context).pop();
                  return;
                }
                final confirmed = await confirmDelete(context, title: 'Supprimer "${charge.name}" ?');
                if (confirmed && context.mounted) {
                  await ref.read(cycleRepositoryProvider).deleteFixedExpense(charge.id);
                  if (context.mounted) Navigator.of(context).pop();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
