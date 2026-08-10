import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatting/currency_formatter.dart';
import '../../core/providers/credits_providers.dart';
import '../../core/providers/dashboard_providers.dart';
import '../../core/routing/app_page_route.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/confirm_delete_dialog.dart';
import '../../core/widgets/euro_amount_field.dart';
import '../../domain/calculations/credit_calculation_service.dart';
import '../../domain/calculations/debt_ratio_bands.dart';
import '../../domain/calculations/household_finance_service.dart';
import '../../domain/calculations/project_debt_impact_service.dart' show kMaxHealthyRemainingDropRatio;
import '../../domain/entities/credit_entity.dart';
import 'credit_form_page.dart';
import 'credit_visuals.dart';

const _creditCalculationService = CreditCalculationService();
const _householdFinanceService = HouseholdFinanceService();

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

  final _newMonthlyPaymentController = TextEditingController();
  CreditPaymentIncreaseSimulation? _paymentIncreaseSimulation;
  bool _applyingNewPayment = false;

  @override
  void dispose() {
    _extraPaymentController.dispose();
    _newMonthlyPaymentController.dispose();
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

  void _runPaymentIncreaseSimulation() {
    final cents = EuroAmountField.parseCents(_newMonthlyPaymentController.text);
    if (cents == null || cents <= 0) {
      setState(() => _paymentIncreaseSimulation = null);
      return;
    }
    setState(() {
      _paymentIncreaseSimulation = simulateCreditPaymentIncrease(
        credit: widget.credit,
        simulatedMonthlyPaymentCents: cents,
      );
    });
  }

  /// Applique la nouvelle mensualité simulée : met à jour le crédit (qui
  /// synchronise automatiquement la charge fixe liée du cycle en cours,
  /// cf. `CycleRepository.updateCredit`) — notifications, Project Planner
  /// et taux d'endettement se recalculent ensuite d'eux-mêmes via les flux
  /// Riverpod existants, sans action supplémentaire ici.
  Future<void> _applyNewMonthlyPayment(int newMonthlyPaymentCents) async {
    final credit = widget.credit;
    setState(() => _applyingNewPayment = true);
    try {
      final repository = ref.read(cycleRepositoryProvider);
      await repository.updateCredit(
        id: credit.id,
        name: credit.name,
        initialAmountCents: credit.initialAmountCents,
        remainingCapitalCents: credit.remainingCapitalCents,
        monthlyPaymentCents: newMonthlyPaymentCents,
        annualRatePercent: credit.annualRatePercent,
        startDate: credit.startDate,
        expectedEndDate: credit.expectedEndDate,
        remainingInstallments: credit.remainingInstallments,
        creditType: credit.creditType,
        earlyRepaymentAllowed: credit.earlyRepaymentAllowed,
        earlyRepaymentPenaltyCents: credit.earlyRepaymentPenaltyCents,
        notes: credit.notes,
        organisme: credit.organisme,
        colorValue: credit.colorValue,
        iconCodePoint: credit.iconCodePoint,
        paymentDayOfMonth: credit.paymentDayOfMonth,
        insuranceCents: credit.insuranceCents,
      );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _applyingNewPayment = false);
    }
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

    final dashboard = ref.watch(dashboardProvider).valueOrNull;
    final allCredits = ref.watch(creditsProvider).valueOrNull ?? const <CreditEntity>[];
    final activeCredits = _creditCalculationService.activeOnly(allCredits);
    final totalIncomeCents = dashboard?.totalIncomeCents ?? 0;
    final totalFixedExpensesExcludingCreditsCents = dashboard?.totalFixedExpensesExcludingCreditsCents ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(credit.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Modifier',
            onPressed: () => Navigator.of(context).push(AppPageRoute(builder: (_) => CreditFormPage(existing: credit))),
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
            if (credit.isActive) ...[
              const Divider(height: AppSpacing.xxxl),
              Text('Augmenter ma mensualité', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Teste une nouvelle mensualité — rien n\'est enregistré tant que tu ne choisis pas de l\'appliquer.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newMonthlyPaymentController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                      decoration: const InputDecoration(labelText: 'Nouvelle mensualité testée', suffixText: '€'),
                      onChanged: (_) => _runPaymentIncreaseSimulation(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton(onPressed: _runPaymentIncreaseSimulation, child: const Text('Simuler la mensualité')),
                ],
              ),
              if (_paymentIncreaseSimulation != null) ...[
                const SizedBox(height: AppSpacing.lg),
                _PaymentIncreaseResult(
                  simulation: _paymentIncreaseSimulation!,
                  credit: credit,
                  activeCredits: activeCredits,
                  totalIncomeCents: totalIncomeCents,
                  totalFixedExpensesExcludingCreditsCents: totalFixedExpensesExcludingCreditsCents,
                  applying: _applyingNewPayment,
                  onApply: () async {
                    final simulated = _paymentIncreaseSimulation!;
                    final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            title: const Text('Appliquer cette nouvelle mensualité ?'),
                            content: Text(
                              '${credit.name} passera de ${formatCentsAsEuro(simulated.currentMonthlyPaymentCents)} '
                              'à ${formatCentsAsEuro(simulated.simulatedMonthlyPaymentCents)}/mois. '
                              'La charge fixe liée à ce crédit sera mise à jour automatiquement.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(dialogContext).pop(false),
                                child: const Text('Annuler'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.of(dialogContext).pop(true),
                                child: const Text('Appliquer'),
                              ),
                            ],
                          ),
                        ) ??
                        false;
                    if (confirmed) {
                      await _applyNewMonthlyPayment(simulated.simulatedMonthlyPaymentCents);
                    }
                  },
                ),
              ],
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

/// Résultat de la simulation d'augmentation de mensualité (V1.2, §2) :
/// mensualité actuelle/simulée, capital restant, nouvelle durée, nouvelle
/// date de fin, mois gagnés, intérêts économisés si connus, et l'impact sur
/// le taux d'endettement et le RESTE À VIVRE STRUCTUREL — calculés avec LES
/// mêmes formules que Credit Manager / Project Planner
/// (`CreditCalculationService.debtRatio` et `HouseholdFinanceService.
/// structuralRemainingCents`), jamais recalculées différemment ici.
class _PaymentIncreaseResult extends StatelessWidget {
  final CreditPaymentIncreaseSimulation simulation;
  final CreditEntity credit;
  final List<CreditEntity> activeCredits;
  final int totalIncomeCents;
  final int totalFixedExpensesExcludingCreditsCents;
  final bool applying;
  final VoidCallback onApply;

  const _PaymentIncreaseResult({
    required this.simulation,
    required this.credit,
    required this.activeCredits,
    required this.totalIncomeCents,
    required this.totalFixedExpensesExcludingCreditsCents,
    required this.applying,
    required this.onApply,
  });

  CreditEntity _withMonthlyPayment(CreditEntity c, int monthlyPaymentCents) => CreditEntity(
        id: c.id,
        name: c.name,
        initialAmountCents: c.initialAmountCents,
        remainingCapitalCents: c.remainingCapitalCents,
        monthlyPaymentCents: monthlyPaymentCents,
        annualRatePercent: c.annualRatePercent,
        startDate: c.startDate,
        expectedEndDate: c.expectedEndDate,
        remainingInstallments: c.remainingInstallments,
        creditType: c.creditType,
        earlyRepaymentAllowed: c.earlyRepaymentAllowed,
        earlyRepaymentPenaltyCents: c.earlyRepaymentPenaltyCents,
        notes: c.notes,
        isActive: c.isActive,
        createdAt: c.createdAt,
        updatedAt: c.updatedAt,
        organisme: c.organisme,
        colorValue: c.colorValue,
        iconCodePoint: c.iconCodePoint,
        paymentDayOfMonth: c.paymentDayOfMonth,
        insuranceCents: c.insuranceCents,
      );

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final simulatedActiveCredits = [
      for (final c in activeCredits)
        if (c.id == credit.id) _withMonthlyPayment(c, simulation.simulatedMonthlyPaymentCents) else c,
    ];

    final currentDebtRatio =
        _creditCalculationService.debtRatio(activeCredits: activeCredits, totalIncomeCents: totalIncomeCents);
    final simulatedDebtRatio = _creditCalculationService.debtRatio(
      activeCredits: simulatedActiveCredits,
      totalIncomeCents: totalIncomeCents,
    );
    final currentRemaining = _householdFinanceService.structuralRemainingCents(
      totalIncomeCents: totalIncomeCents,
      totalFixedExpensesExcludingCreditsCents: totalFixedExpensesExcludingCreditsCents,
      activeCredits: activeCredits,
    );
    final simulatedRemaining = _householdFinanceService.structuralRemainingCents(
      totalIncomeCents: totalIncomeCents,
      totalFixedExpensesExcludingCreditsCents: totalFixedExpensesExcludingCreditsCents,
      activeCredits: simulatedActiveCredits,
    );

    final debtBandAfter = debtRatioBandFor(simulatedDebtRatio);
    final worseningDebtBand =
        debtBandAfter == DebtRatioBand.high && debtRatioBandFor(currentDebtRatio) != DebtRatioBand.high;
    final remainingDropRatio = currentRemaining > 0 ? (currentRemaining - simulatedRemaining) / currentRemaining : 0.0;
    final heavyDrop = remainingDropRatio >= kMaxHealthyRemainingDropRatio;
    final remainingBecomesNegative = simulatedRemaining <= 0 && currentRemaining > 0;
    final showWarning = worseningDebtBand || heavyDrop || remainingBecomesNegative;

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
              _DetailRow(
                  label: 'Mensualité actuelle',
                  value: '${formatCentsAsEuro(simulation.currentMonthlyPaymentCents)}/mois'),
              _DetailRow(
                  label: 'Mensualité simulée',
                  value: '${formatCentsAsEuro(simulation.simulatedMonthlyPaymentCents)}/mois'),
              _DetailRow(label: 'Capital restant', value: formatCentsAsEuro(simulation.remainingCapitalCents)),
              _DetailRow(label: 'Nouvelle durée estimée', value: '${simulation.simulatedRemainingInstallments} mois'),
              _DetailRow(label: 'Nouvelle date de fin', value: formatMonthYearFr(simulation.simulatedEndDate)),
              _DetailRow(
                label: simulation.monthsSaved >= 0 ? 'Mois gagnés' : 'Mois supplémentaires',
                value: '${simulation.monthsSaved.abs()} mois',
              ),
              if (simulation.estimatedInterestSavedCents != null)
                _DetailRow(
                    label: 'Intérêts économisés (estimation)',
                    value: formatCentsAsEuro(simulation.estimatedInterestSavedCents!))
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Text(
                    'Taux non renseigné : estimation simplifiée, sans intérêts calculés.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              Divider(color: colorScheme.outlineVariant, height: 1),
              const SizedBox(height: AppSpacing.md),
              _DetailRow(label: 'Taux d\'endettement actuel', value: '${(currentDebtRatio * 100).round()} %'),
              _DetailRow(label: 'Taux d\'endettement simulé', value: '${(simulatedDebtRatio * 100).round()} %'),
              _DetailRow(label: 'Reste à vivre actuel', value: '${formatCentsAsEuro(currentRemaining)}/mois'),
              _DetailRow(
                  label: 'Reste à vivre après augmentation', value: '${formatCentsAsEuro(simulatedRemaining)}/mois'),
            ],
          ),
        ),
        if (showWarning) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: BudgetColors.danger.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, color: BudgetColors.danger, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Cette mensualité dégraderait fortement ton reste à vivre ou ton taux d\'endettement — '
                    'à valider avec prudence.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        OutlinedButton(
          onPressed: applying ? null : onApply,
          child: Text(applying ? 'Application…' : 'Appliquer cette nouvelle mensualité'),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Estimation simplifiée — hors intérêts composés, hors assurance, hors renégociation de taux.',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
