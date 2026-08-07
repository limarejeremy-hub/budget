import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatting/currency_formatter.dart';
import '../../core/providers/credits_providers.dart';
import '../../core/providers/dashboard_providers.dart';
import '../../core/providers/projects_providers.dart';
import '../../core/routing/app_page_route.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/confirm_delete_dialog.dart';
import '../../domain/calculations/credit_calculation_service.dart';
import '../../domain/calculations/project_feasibility_service.dart';
import '../../domain/calculations/project_scenario_service.dart';
import '../../domain/entities/credit_entity.dart';
import '../../domain/entities/project_entity.dart';
import 'project_form_page.dart';
import 'project_visuals.dart';
import 'widgets/project_simulator_sheet.dart';

const _feasibilityService = ProjectFeasibilityService();
const _scenarioService = ProjectScenarioService();
const _creditCalculationService = CreditCalculationService();

/// Fiche détaillée d'un projet (V1.0 — Project Planner, §12) : score de
/// faisabilité, situation financière, ce qui bloque, ce qui va s'améliorer,
/// chemin recommandé, autres scénarios, roadmap. Toujours recalculé à la
/// volée à partir des données courantes — jamais un résultat figé (§18).
class ProjectDetailPage extends ConsumerWidget {
  final int projectId;
  const ProjectDetailPage({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectsProvider);
    final dashboardAsync = ref.watch(dashboardProvider);
    final creditsAsync = ref.watch(creditsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Projet')),
      body: SafeArea(
        child: projectsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => const Center(child: Text('Impossible de charger le projet')),
          data: (projects) {
            ProjectEntity? project;
            for (final p in projects) {
              if (p.id == projectId) project = p;
            }
            if (project == null) {
              return const Center(child: Text('Ce projet a été supprimé.'));
            }

            return dashboardAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => const Center(child: Text('Impossible de charger la situation financière')),
              data: (dashboard) {
                if (dashboard == null) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.xxl),
                      child: Text(
                        "Crée d'abord un cycle budgétaire pour évaluer ce projet.",
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                final credits = creditsAsync.valueOrNull ?? const [];
                final activeCredits = _creditCalculationService.activeOnly(credits);

                return _ProjectDetailBody(
                  project: project!,
                  currentFreeCashCents: dashboard.realRemainingCents,
                  activeCredits: activeCredits,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ProjectDetailBody extends ConsumerWidget {
  final ProjectEntity project;
  final int currentFreeCashCents;
  final List<CreditEntity> activeCredits;

  const _ProjectDetailBody({
    required this.project,
    required this.currentFreeCashCents,
    required this.activeCredits,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = _feasibilityService.evaluate(
      project: project,
      currentFreeCashCents: currentFreeCashCents,
      activeCredits: activeCredits,
    );
    final scenarios = _scenarioService.generate(
      project: project,
      currentFreeCashCents: currentFreeCashCents,
      activeCredits: activeCredits,
    );
    final recommended = _scenarioService.recommend(scenarios);
    final otherScenarios = scenarios.where((s) => s != recommended).toList();
    final roadmap = _scenarioService.buildRoadmap(
      project: project,
      currentFreeCashCents: currentFreeCashCents,
      activeCredits: activeCredits,
    );
    final color = feasibilityLevelColor(result.level);

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 88),
      children: [
        _HeaderSection(project: project, result: result, color: color),
        const SizedBox(height: AppSpacing.xl),
        _ActionsRow(
          project: project,
          currentFreeCashCents: currentFreeCashCents,
          activeCredits: activeCredits,
        ),
        const SizedBox(height: AppSpacing.xl),
        _SituationSection(result: result),
        if (result.blockers.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          _BlockersSection(blockers: result.blockers),
        ],
        if (result.upcomingImprovements.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          _ImprovementsSection(improvements: result.upcomingImprovements),
        ],
        if (recommended != null) ...[
          const SizedBox(height: AppSpacing.xl),
          _RecommendedPathSection(scenario: recommended),
        ],
        if (otherScenarios.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          _OtherScenariosSection(scenarios: otherScenarios),
        ],
        if (roadmap.length > 1) ...[
          const SizedBox(height: AppSpacing.xl),
          _RoadmapSection(steps: roadmap),
        ],
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Estimation BudgetPilot basée sur les données enregistrées dans l\'application — '
          'jamais une décision bancaire, une capacité d\'emprunt officielle ni un conseil réglementé.',
          style:
              Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _HeaderSection extends StatelessWidget {
  final ProjectEntity project;
  final ProjectFeasibilityResult result;
  final Color color;
  const _HeaderSection({required this.project, required this.result, required this.color});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(projectCategoryEmoji(project.category), style: const TextStyle(fontSize: 28)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(project.name, style: Theme.of(context).textTheme.headlineSmall),
                  Text(projectCategoryLabel(project.category),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(formatCentsAsEuro(project.targetAmountCents),
            style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: result.totalScore / 100,
                    strokeWidth: 5,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    color: color,
                  ),
                  Text('${result.totalScore}', style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${feasibilityLevelEmoji(result.level)} ${feasibilityLevelLabel(result.level)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color, fontWeight: FontWeight.w700),
                  ),
                  if (result.blockers.isNotEmpty)
                    Text(
                      'Il manque encore un peu de marge pour réaliser ce projet confortablement.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionsRow extends ConsumerWidget {
  final ProjectEntity project;
  final int currentFreeCashCents;
  final List<CreditEntity> activeCredits;
  const _ActionsRow({
    required this.project,
    required this.currentFreeCashCents,
    required this.activeCredits,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => showProjectSimulatorSheet(
              context,
              project: project,
              currentFreeCashCents: currentFreeCashCents,
              activeCredits: activeCredits,
            ),
            icon: const Icon(Icons.tune_rounded),
            label: const Text('Simuler'),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () =>
                Navigator.of(context).push(AppPageRoute(builder: (_) => ProjectFormPage(existing: project))),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Modifier'),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        PopupMenuButton<String>(
          onSelected: (value) async {
            final repository = ref.read(cycleRepositoryProvider);
            if (value == 'archive') {
              await repository.setProjectActive(project.id, !project.isActive);
            } else if (value == 'delete') {
              final confirmed = await confirmDelete(context, title: 'Supprimer "${project.name}" ?');
              if (confirmed && context.mounted) {
                await repository.deleteProject(project.id);
                if (context.mounted) Navigator.of(context).pop();
              }
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'archive',
              child: Text(project.isActive ? 'Archiver' : 'Réactiver'),
            ),
            const PopupMenuItem(value: 'delete', child: Text('Supprimer')),
          ],
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}

class _SituationSection extends StatelessWidget {
  final ProjectFeasibilityResult result;
  const _SituationSection({required this.result});

  @override
  Widget build(BuildContext context) {
    final financing = result.financing;
    return _SectionCard(
      title: 'Situation',
      child: Column(
        children: [
          _SituationRow('Prix', formatCentsAsEuro(financing.targetAmountCents)),
          _SituationRow('Apport', formatCentsAsEuro(financing.contributionCents)),
          _SituationRow('À financer', formatCentsAsEuro(financing.financingNeededCents)),
          if (financing.estimatedMonthlyPaymentCents > 0)
            _SituationRow(
              'Mensualité estimée${financing.isRateEstimated ? ' (simplifiée)' : ''}',
              formatCentsAsEuro(financing.estimatedMonthlyPaymentCents),
            ),
          if (financing.extraMonthlyCostCents > 0)
            _SituationRow('Coûts supplémentaires', formatCentsAsEuro(financing.extraMonthlyCostCents)),
          _SituationRow('Impact mensuel', formatCentsAsEuro(financing.totalMonthlyImpactCents)),
          _SituationRow('Marge restante', formatCentsAsEuro(result.marginAfterCents)),
        ],
      ),
    );
  }
}

class _SituationRow extends StatelessWidget {
  final String label;
  final String value;
  const _SituationRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
          ),
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _BlockersSection extends StatelessWidget {
  final List<String> blockers;
  const _BlockersSection({required this.blockers});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Ce qui bloque',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final blocker in blockers)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(blocker, style: Theme.of(context).textTheme.bodyMedium),
            ),
        ],
      ),
    );
  }
}

class _ImprovementsSection extends StatelessWidget {
  final List<CreditImprovement> improvements;
  const _ImprovementsSection({required this.improvements});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Ce qui va s\'améliorer',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final improvement in improvements)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(
                'Crédit ${improvement.credit.name} terminé dans ${improvement.monthsUntilFreed} mois '
                '· +${formatCentsAsEuro(improvement.monthlyPaymentFreedCents)}/mois',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
        ],
      ),
    );
  }
}

class _RecommendedPathSection extends StatelessWidget {
  final ProjectScenario scenario;
  const _RecommendedPathSection({required this.scenario});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: Color.alphaBlend(CategoryColors.credit.withValues(alpha: 0.12), colorScheme.surfaceContainerHigh),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('⭐ Chemin recommandé', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(scenario.label, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.xs),
            Text(scenario.description, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Faisabilité : ${scenario.baselineScore}% → ${scenario.newScore}%',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _OtherScenariosSection extends StatelessWidget {
  final List<ProjectScenario> scenarios;
  const _OtherScenariosSection({required this.scenarios});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Autres scénarios',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final scenario in scenarios)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(scenario.label,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                        Text(scenario.description, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  Text('${scenario.baselineScore}% → ${scenario.newScore}%',
                      style: Theme.of(context).textTheme.labelMedium),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RoadmapSection extends StatelessWidget {
  final List<RoadmapStep> steps;
  const _RoadmapSection({required this.steps});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return _SectionCard(
      title: 'Roadmap',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (index, step) in steps.indexed) ...[
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: CategoryColors.credit, shape: BoxShape.circle),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    step.monthsFromNow == 0 ? step.label : '${step.label} (dans ${step.monthsFromNow} mois)',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Text('${step.score}%', style: Theme.of(context).textTheme.labelLarge),
              ],
            ),
            if (index < steps.length - 1)
              Padding(
                padding: const EdgeInsets.only(left: 3),
                child: Container(width: 2, height: 20, color: colorScheme.outlineVariant),
              ),
          ],
        ],
      ),
    );
  }
}
