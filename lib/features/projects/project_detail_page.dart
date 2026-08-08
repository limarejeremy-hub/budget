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
import '../../domain/calculations/project_debt_impact_service.dart';
import '../../domain/calculations/project_feasibility_service.dart';
import '../../domain/calculations/project_health_service.dart';
import '../../domain/calculations/project_scenario_service.dart';
import '../../domain/entities/credit_entity.dart';
import '../../domain/entities/project_entity.dart';
import 'project_form_page.dart';
import 'project_visuals.dart';
import 'widgets/project_simulator_sheet.dart';

const _healthService = ProjectHealthService();
const _scenarioService = ProjectScenarioService();
const _creditCalculationService = CreditCalculationService();

/// Fiche détaillée d'un projet (V1.0 — Project Planner, §12 ; enrichie
/// V1.1/V1.2 : taux d'endettement et reste à vivre, avant/après — des
/// indicateurs concrets, jamais un pourcentage de "sécurité" calculé).
/// Toujours recalculée à la volée à partir des données courantes — jamais
/// un résultat figé (§18).
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
                  totalIncomeCents: dashboard.totalIncomeCents,
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
  final int totalIncomeCents;
  final List<CreditEntity> activeCredits;

  const _ProjectDetailBody({
    required this.project,
    required this.currentFreeCashCents,
    required this.totalIncomeCents,
    required this.activeCredits,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = _healthService.evaluate(
      project: project,
      currentFreeCashCents: currentFreeCashCents,
      totalIncomeCents: totalIncomeCents,
      activeCredits: activeCredits,
    );
    final scenarios = _scenarioService.generate(
      project: project,
      currentFreeCashCents: currentFreeCashCents,
      totalIncomeCents: totalIncomeCents,
      activeCredits: activeCredits,
    );
    final recommended = _scenarioService.recommend(scenarios);
    final otherScenarios = scenarios.where((s) => s != recommended).toList();
    final roadmap = _scenarioService.buildRoadmap(
      project: project,
      currentFreeCashCents: currentFreeCashCents,
      activeCredits: activeCredits,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 88),
      children: [
        _HeaderSection(project: project, health: health),
        const SizedBox(height: AppSpacing.xl),
        _ActionsRow(
          project: project,
          currentFreeCashCents: currentFreeCashCents,
          totalIncomeCents: totalIncomeCents,
          activeCredits: activeCredits,
        ),
        const SizedBox(height: AppSpacing.xl),
        _SituationSection(result: health.feasibility),
        const SizedBox(height: AppSpacing.xl),
        _DebtImpactSection(debtImpact: health.debtImpact),
        if (health.blockers.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          _BlockersSection(blockers: health.blockers),
        ],
        if (health.feasibility.upcomingImprovements.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          _ImprovementsSection(improvements: health.feasibility.upcomingImprovements),
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
  final ProjectHealthResult health;
  const _HeaderSection({required this.project, required this.health});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final feasibilityColor = feasibilityLevelColor(health.feasibility.level);
    final debtBand = debtRatioBandFor(health.debtImpact.debtRatioAfter);
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
            Expanded(
              child: _ScoreBadge(
                label: 'Faisabilité',
                score: health.feasibility.totalScore,
                color: feasibilityColor,
                levelText:
                    '${feasibilityLevelEmoji(health.feasibility.level)} ${feasibilityLevelLabel(health.feasibility.level)}',
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _MetricBadge(
                label: 'Endettement après projet',
                value: '${(health.debtImpact.debtRatioAfter * 100).round()} %',
                color: debtRatioBandColor(debtBand),
                subText: '${debtRatioBandEmoji(debtBand)} ${debtRatioBandLabel(debtBand)}',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Reste à vivre après projet : ${formatCentsAsEuro(health.debtImpact.remainingAfterCents)}/mois',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(health.conclusion, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  final String label;
  final int score;
  final Color color;
  final String levelText;
  const _ScoreBadge({required this.label, required this.score, required this.color, required this.levelText});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text('$score%',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color, fontWeight: FontWeight.w700)),
          Text(levelText, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

/// Badge d'un indicateur concret (taux d'endettement, reste à vivre) — même
/// habillage visuel que [_ScoreBadge] mais sans laisser croire à un score
/// calculé : la valeur affichée est directement lisible (%, €), jamais un
/// pourcentage de "sécurité" agrégé.
class _MetricBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final String subText;
  const _MetricBadge({required this.label, required this.value, required this.color, required this.subText});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color, fontWeight: FontWeight.w700)),
          Text(subText, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _ActionsRow extends ConsumerWidget {
  final ProjectEntity project;
  final int currentFreeCashCents;
  final int totalIncomeCents;
  final List<CreditEntity> activeCredits;
  const _ActionsRow({
    required this.project,
    required this.currentFreeCashCents,
    required this.totalIncomeCents,
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
              totalIncomeCents: totalIncomeCents,
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
            } else if (value == 'duplicate') {
              await repository.duplicateProject(project.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Projet dupliqué')));
              }
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
            const PopupMenuItem(value: 'duplicate', child: Text('Dupliquer')),
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

/// Impact du projet sur le budget (V1.2 — analyse simplifiée) : taux
/// d'endettement et reste à vivre, avant/après, avec la variation —
/// uniquement des chiffres concrets, jamais un pourcentage de "sécurité"
/// ni une décision bancaire.
class _DebtImpactSection extends StatelessWidget {
  final ProjectDebtImpactResult debtImpact;
  const _DebtImpactSection({required this.debtImpact});

  @override
  Widget build(BuildContext context) {
    final debtBandAfter = debtRatioBandFor(debtImpact.debtRatioAfter);
    final pointsDelta = ((debtImpact.debtRatioAfter - debtImpact.debtRatioBefore) * 100).round();
    final remainingDeltaEuros = (debtImpact.remainingDeltaCents / 100).round();
    return _SectionCard(
      title: 'Impact sur le budget',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Situation actuelle', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          _SituationRow('Taux d\'endettement', '${(debtImpact.debtRatioBefore * 100).round()} %'),
          _SituationRow('Reste à vivre', '${formatCentsAsEuro(debtImpact.remainingBeforeCents)}/mois'),
          const SizedBox(height: AppSpacing.md),
          Text('Avec le projet', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          _SituationRow(
            'Taux d\'endettement ${debtRatioBandEmoji(debtBandAfter)}',
            '${(debtImpact.debtRatioAfter * 100).round()} %',
          ),
          _SituationRow('Reste à vivre', '${formatCentsAsEuro(debtImpact.remainingAfterCents)}/mois'),
          _SituationRow(
              'Marge consommée par le projet', '${formatCentsAsEuro(debtImpact.marginConsumedByProjectCents)}/mois'),
          const SizedBox(height: AppSpacing.md),
          Text('Variation', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${pointsDelta >= 0 ? '+' : ''}$pointsDelta points d\'endettement',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            '${remainingDeltaEuros >= 0 ? '+' : ''}$remainingDeltaEuros €/mois de reste à vivre',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Repères de taux d\'endettement internes à BudgetPilot — jamais une règle d\'acceptation bancaire.',
            style:
                Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
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
            _ScenarioMetricsGrid(scenario: scenario),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(scenario.label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  Text(scenario.description, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: AppSpacing.xs),
                  _ScenarioMetricsGrid(scenario: scenario),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Faisabilité / Endettement / Reste à vivre, avant → après, pour un
/// scénario (§8 V1.1/V1.2) — indicateurs concrets uniquement, jamais un
/// pourcentage de "sécurité" agrégé.
class _ScenarioMetricsGrid extends StatelessWidget {
  final ProjectScenario scenario;
  const _ScenarioMetricsGrid({required this.scenario});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.xs,
      children: [
        _metric(context, 'Faisabilité', '${scenario.baselineScore}% → ${scenario.newScore}%'),
        _metric(
          context,
          'Endettement',
          '${(scenario.baselineDebtRatioAfter * 100).round()}% → ${(scenario.newDebtRatioAfter * 100).round()}%',
        ),
        _metric(
          context,
          'Reste à vivre',
          '${formatCentsAsEuro(scenario.baselineRemainingAfterCents)} → ${formatCentsAsEuro(scenario.newRemainingAfterCents)}/mois',
        ),
      ].map((w) => DefaultTextStyle.merge(style: TextStyle(color: colorScheme.onSurfaceVariant), child: w)).toList(),
    );
  }

  Widget _metric(BuildContext context, String label, String value) {
    return RichText(
      text: TextSpan(
        style: Theme.of(context).textTheme.labelSmall,
        children: [
          TextSpan(text: '$label : '),
          TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.w700)),
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
