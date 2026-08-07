import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/dashboard_providers.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/euro_amount_field.dart';
import '../../../domain/calculations/project_feasibility_service.dart';
import '../../../domain/entities/credit_entity.dart';
import '../../../domain/entities/project_entity.dart';
import '../project_visuals.dart';

const _feasibilityService = ProjectFeasibilityService();

/// Simulateur interactif (§15) : teste un apport ou un prix cible différent
/// sans jamais modifier les vraies données tant que l'utilisateur n'a pas
/// explicitement choisi "Enregistrer cet apport".
Future<void> showProjectSimulatorSheet(
  BuildContext context, {
  required ProjectEntity project,
  required int currentFreeCashCents,
  required List<CreditEntity> activeCredits,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ProjectSimulatorSheet(
      project: project,
      currentFreeCashCents: currentFreeCashCents,
      activeCredits: activeCredits,
    ),
  );
}

class ProjectSimulatorSheet extends ConsumerStatefulWidget {
  final ProjectEntity project;
  final int currentFreeCashCents;
  final List<CreditEntity> activeCredits;

  const ProjectSimulatorSheet({
    super.key,
    required this.project,
    required this.currentFreeCashCents,
    required this.activeCredits,
  });

  @override
  ConsumerState<ProjectSimulatorSheet> createState() => _ProjectSimulatorSheetState();
}

class _ProjectSimulatorSheetState extends ConsumerState<ProjectSimulatorSheet> {
  late final TextEditingController _contributionController;
  late final TextEditingController _targetController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _contributionController = TextEditingController(
      text: (widget.project.availableContributionCents / 100).toStringAsFixed(2),
    );
    _targetController = TextEditingController(
      text: (widget.project.targetAmountCents / 100).toStringAsFixed(2),
    );
    _contributionController.addListener(_refresh);
    _targetController.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _contributionController.removeListener(_refresh);
    _targetController.removeListener(_refresh);
    _contributionController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  ProjectEntity get _simulatedProject {
    final contribution =
        EuroAmountField.parseCents(_contributionController.text) ?? widget.project.availableContributionCents;
    final target = EuroAmountField.parseCents(_targetController.text) ?? widget.project.targetAmountCents;
    return ProjectEntity(
      id: widget.project.id,
      name: widget.project.name,
      category: widget.project.category,
      targetAmountCents: target,
      desiredDate: widget.project.desiredDate,
      availableContributionCents: contribution,
      desiredContributionCents: widget.project.desiredContributionCents,
      financingMode: widget.project.financingMode,
      maxMonthlyPaymentCents: widget.project.maxMonthlyPaymentCents,
      desiredDurationMonths: widget.project.desiredDurationMonths,
      estimatedRatePercent: widget.project.estimatedRatePercent,
      extraMonthlyCostCents: widget.project.extraMonthlyCostCents,
      notes: widget.project.notes,
      isActive: widget.project.isActive,
      createdAt: widget.project.createdAt,
      updatedAt: widget.project.updatedAt,
    );
  }

  Future<void> _saveContribution() async {
    setState(() => _saving = true);
    final repository = ref.read(cycleRepositoryProvider);
    final simulated = _simulatedProject;
    try {
      await repository.updateProject(
        id: widget.project.id,
        name: widget.project.name,
        category: widget.project.category,
        targetAmountCents: widget.project.targetAmountCents,
        desiredDate: widget.project.desiredDate,
        availableContributionCents: simulated.availableContributionCents,
        desiredContributionCents: widget.project.desiredContributionCents,
        financingMode: widget.project.financingMode,
        maxMonthlyPaymentCents: widget.project.maxMonthlyPaymentCents,
        desiredDurationMonths: widget.project.desiredDurationMonths,
        estimatedRatePercent: widget.project.estimatedRatePercent,
        extraMonthlyCostCents: widget.project.extraMonthlyCostCents,
        notes: widget.project.notes,
      );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseline = _feasibilityService.evaluate(
      project: widget.project,
      currentFreeCashCents: widget.currentFreeCashCents,
      activeCredits: widget.activeCredits,
    );
    final simulated = _feasibilityService.evaluate(
      project: _simulatedProject,
      currentFreeCashCents: widget.currentFreeCashCents,
      activeCredits: widget.activeCredits,
    );
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Simuler', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Teste un autre apport ou un autre prix — rien n\'est enregistré tant que tu ne le choisis pas.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            EuroAmountField(controller: _contributionController, label: 'Apport disponible', required: false),
            const SizedBox(height: AppSpacing.lg),
            EuroAmountField(controller: _targetController, label: 'Prix / budget cible'),
            const SizedBox(height: AppSpacing.xl),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${baseline.totalScore}%', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(width: AppSpacing.sm),
                  const Icon(Icons.arrow_forward_rounded),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '${simulated.totalScore}%',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: feasibilityLevelColor(simulated.level),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _saving ? null : _saveContribution,
              child: Text(_saving ? 'Enregistrement…' : 'Enregistrer cet apport'),
            ),
          ],
        ),
      ),
    );
  }
}
