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
import 'credit_visuals.dart';

const _creditCalculationService = CreditCalculationService();

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
  int? _simulatedExtraCents;

  @override
  void dispose() {
    _extraPaymentController.dispose();
    super.dispose();
  }

  void _runSimulation() {
    final cents = EuroAmountField.parseCents(_extraPaymentController.text);
    if (cents == null || cents <= 0) {
      setState(() {
        _simulation = null;
        _simulatedExtraCents = null;
      });
      return;
    }
    setState(() {
      _simulation = simulateCreditPrepayment(credit: widget.credit, extraPaymentCents: cents);
      _simulatedExtraCents = cents;
    });
  }

  @override
  Widget build(BuildContext context) {
    final credit = widget.credit;
    final colorScheme = Theme.of(context).colorScheme;
    final color = creditColorFor(credit);
    final icon = creditIconFor(credit);
    final stars = _creditCalculationService.priorityStars(credit);
    final priorityLabel = _creditCalculationService.priorityLabel(credit);
    final pace = _creditCalculationService.creditPace(credit);
    final paceLabel = _creditCalculationService.creditPaceLabel(credit);
    final paceColor = creditPaceColor(pace);
    final paceEmoji = creditPaceEmoji(pace);

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
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.2), shape: BoxShape.circle),
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(width: AppSpacing.md),
                if (credit.isActive)
                  Expanded(
                    child: Row(
                      children: [
                        for (var i = 0; i < 5; i++)
                          Icon(
                            i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                            size: 16,
                            color: i < stars ? color : colorScheme.outlineVariant,
                          ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(priorityLabel, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
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
            if (credit.organisme != null && credit.organisme!.isNotEmpty)
              _DetailRow(label: 'Banque', value: credit.organisme!),
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

            Text('Historique', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            _DetailRow(label: 'Ajouté le', value: formatDayMonthFr(credit.createdAt)),
            _DetailRow(label: 'Dernière mise à jour', value: formatDayMonthFr(credit.updatedAt)),

            const Divider(height: AppSpacing.xxxl),

            Text('Versement exceptionnel', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Estimation simplifiée — hors intérêts, hors assurance, hors pénalités.',
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
            if (_simulation != null && _simulatedExtraCents != null) ...[
              const SizedBox(height: AppSpacing.lg),
              _SimulationResult(
                simulation: _simulation!,
                extraPaymentCents: _simulatedExtraCents!,
                monthlyPaymentCents: credit.monthlyPaymentCents,
              ),
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
  final int extraPaymentCents;
  final int monthlyPaymentCents;
  const _SimulationResult({
    required this.simulation,
    required this.extraPaymentCents,
    required this.monthlyPaymentCents,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Color.alphaBlend(CategoryColors.credit.withValues(alpha: 0.08), colorScheme.surfaceContainerHigh),
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Après un remboursement exceptionnel de :',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
              const SizedBox(height: AppSpacing.xs),
              Text(formatCentsAsEuro(extraPaymentCents),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.md),
              Divider(color: colorScheme.outlineVariant, height: 1),
              const SizedBox(height: AppSpacing.md),
              _DetailRow(label: 'Capital restant', value: formatCentsAsEuro(simulation.remainingCapitalAfterCents)),
              _DetailRow(
                label: 'Gain estimé',
                value: '${simulation.monthsSaved} mensualité${simulation.monthsSaved > 1 ? 's' : ''}',
              ),
              _DetailRow(label: 'Nouvelle fin', value: formatMonthYearFr(simulation.estimatedEndDate)),
              _DetailRow(label: 'Mensualité toujours', value: '${formatCentsAsEuro(monthlyPaymentCents)}/mois'),
            ],
          ),
        ),
        if (simulation.monthsSaved > 0) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: CategoryColors.credit.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tu économiserais environ',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                Text(formatDurationYearsMonths(simulation.monthsSaved),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: AppSpacing.xs),
                Text('Excellent choix.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Estimation simplifiée — hors intérêts, hors assurance, hors pénalités.',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
