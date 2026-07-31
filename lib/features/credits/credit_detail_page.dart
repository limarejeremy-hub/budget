import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatting/currency_formatter.dart';
import '../../core/providers/dashboard_providers.dart';
import '../../core/routing/app_page_route.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/confirm_delete_dialog.dart';
import '../../core/widgets/euro_amount_field.dart';
import '../../domain/calculations/credit_calculation_service.dart';
import '../../domain/entities/credit_entity.dart';
import 'credit_form_page.dart';

/// Détail d'un crédit : toutes ses informations, simulation de versement
/// exceptionnel, et actions (modifier, marquer comme terminé / réactiver,
/// supprimer).
class CreditDetailPage extends ConsumerStatefulWidget {
  final CreditEntity credit;
  const CreditDetailPage({super.key, required this.credit});

  @override
  ConsumerState<CreditDetailPage> createState() => _CreditDetailPageState();
}

class _CreditDetailPageState extends ConsumerState<CreditDetailPage> {
  final _extraPaymentController = TextEditingController();
  CreditPrepaymentSimulation? _simulation;

  @override
  void dispose() {
    _extraPaymentController.dispose();
    super.dispose();
  }

  void _runSimulation() {
    final cents = EuroAmountField.parseCents(_extraPaymentController.text);
    if (cents == null || cents <= 0) {
      setState(() => _simulation = null);
      return;
    }
    setState(() {
      _simulation = simulateCreditPrepayment(credit: widget.credit, extraPaymentCents: cents);
    });
  }

  @override
  Widget build(BuildContext context) {
    final credit = widget.credit;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(credit.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Modifier',
            onPressed: () => Navigator.of(context)
                .push(AppPageRoute(builder: (_) => CreditFormPage(existing: credit))),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            _DetailRow(label: 'Montant initial', value: formatCentsAsEuro(credit.initialAmountCents)),
            _DetailRow(label: 'Capital restant dû', value: formatCentsAsEuro(credit.remainingCapitalCents)),
            _DetailRow(label: 'Mensualité', value: formatCentsAsEuro(credit.monthlyPaymentCents)),
            _DetailRow(
              label: 'Taux annuel',
              value: credit.annualRatePercent == null ? 'Taux non renseigné' : '${credit.annualRatePercent} %',
            ),
            _DetailRow(label: 'Mensualités restantes', value: '${credit.remainingInstallments}'),
            _DetailRow(label: 'Date de fin prévue', value: formatDayMonthFr(credit.expectedEndDate)),
            if (credit.startDate != null)
              _DetailRow(label: 'Date de début', value: formatDayMonthFr(credit.startDate!)),
            if (credit.creditType != null) _DetailRow(label: 'Type', value: credit.creditType!),
            _DetailRow(
              label: 'Remboursement anticipé',
              value: credit.earlyRepaymentAllowed ? 'Autorisé' : 'Non autorisé',
            ),
            if (credit.earlyRepaymentAllowed && credit.earlyRepaymentPenaltyCents != null)
              _DetailRow(label: 'Pénalité anticipée', value: formatCentsAsEuro(credit.earlyRepaymentPenaltyCents!)),
            if (credit.notes != null && credit.notes!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Text(credit.notes!, style: Theme.of(context).textTheme.bodyMedium),
              ),
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              child: LinearProgressIndicator(
                value: credit.repaidProgress,
                minHeight: 8,
                backgroundColor: colorScheme.surfaceContainerHighest,
                color: CategoryColors.credit,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text('${(credit.repaidProgress * 100).round()} % remboursé',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),

            const Divider(height: AppSpacing.xxxl),

            Text('Versement exceptionnel', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Estimation simplifiée, hors intérêts et pénalités.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _extraPaymentController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                    decoration: const InputDecoration(labelText: 'Montant du versement', suffixText: '€'),
                    onChanged: (_) => _runSimulation(),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(onPressed: _runSimulation, child: const Text('Simuler')),
              ],
            ),
            if (_simulation != null) ...[
              const SizedBox(height: AppSpacing.lg),
              _SimulationResult(simulation: _simulation!),
            ],

            const SizedBox(height: AppSpacing.xxxl),
            OutlinedButton.icon(
              onPressed: () async {
                final repository = ref.read(cycleRepositoryProvider);
                await repository.setCreditActive(credit.id, !credit.isActive);
                if (context.mounted) Navigator.of(context).pop();
              },
              icon: Icon(credit.isActive ? Icons.check_circle_outline : Icons.refresh_rounded),
              label: Text(credit.isActive ? 'Marquer comme terminé' : 'Réactiver ce crédit'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: colorScheme.error),
              onPressed: () async {
                final confirmed = await confirmDelete(context, title: 'Supprimer "${credit.name}" ?');
                if (confirmed) {
                  final repository = ref.read(cycleRepositoryProvider);
                  await repository.deleteCredit(credit.id);
                  if (context.mounted) Navigator.of(context).pop();
                }
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Supprimer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant)),
          ),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _SimulationResult extends StatelessWidget {
  final CreditPrepaymentSimulation simulation;
  const _SimulationResult({required this.simulation});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Color.alphaBlend(CategoryColors.credit.withValues(alpha: 0.08), colorScheme.surfaceContainerHigh),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailRow(
              label: 'Capital restant après versement',
              value: formatCentsAsEuro(simulation.remainingCapitalAfterCents)),
          _DetailRow(
              label: 'Mensualités théoriques restantes',
              value: '${simulation.theoreticalRemainingInstallments}'),
          _DetailRow(label: 'Mois potentiellement gagnés', value: '${simulation.monthsSaved}'),
          _DetailRow(label: 'Date de fin estimée', value: formatDayMonthFr(simulation.estimatedEndDate)),
        ],
      ),
    );
  }
}
