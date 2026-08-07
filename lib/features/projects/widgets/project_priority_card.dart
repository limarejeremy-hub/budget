import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/credits_providers.dart';
import '../../../core/providers/dashboard_providers.dart';
import '../../../core/providers/projects_providers.dart';
import '../../../core/routing/app_page_route.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../domain/calculations/credit_calculation_service.dart';
import '../../../domain/calculations/project_feasibility_service.dart';
import '../../../domain/calculations/project_scenario_service.dart';
import '../../../domain/entities/project_entity.dart';
import '../project_detail_page.dart';
import '../project_visuals.dart';
import '../projects_page.dart';

const _feasibilityService = ProjectFeasibilityService();
const _scenarioService = ProjectScenarioService();
const _creditCalculationService = CreditCalculationService();

/// Carte "Projets" de la Home — point d'entrée naturel vers le module
/// Projets (§1), qui devient la carte "Projet prioritaire" (§14) dès qu'un
/// projet actif existe : un seul projet mis en avant, jamais toute la
/// liste, jamais une grande zone vide.
class ProjectPriorityCard extends ConsumerWidget {
  const ProjectPriorityCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectsProvider);
    final dashboardAsync = ref.watch(dashboardProvider);
    final creditsAsync = ref.watch(creditsProvider);

    final projects = projectsAsync.valueOrNull;
    final dashboard = dashboardAsync.valueOrNull;
    if (projects == null || dashboard == null) return const SizedBox.shrink();

    final active = projects.where((p) => p.isActive).toList();
    if (active.isEmpty) return const _EmptyProjectsCard();

    final activeCredits = _creditCalculationService.activeOnly(creditsAsync.valueOrNull ?? const []);
    final currentFreeCashCents = dashboard.realRemainingCents;

    // Priorité : le projet actif dont le score n'est pas déjà maximal et
    // qui s'en approche le plus — celui pour lequel un petit effort
    // supplémentaire rapproche le plus concrètement de la réalisation.
    ProjectEntity? priority;
    var priorityScore = -1;
    for (final project in active) {
      final score = _feasibilityService
          .evaluate(project: project, currentFreeCashCents: currentFreeCashCents, activeCredits: activeCredits)
          .totalScore;
      if (score < 100 && score > priorityScore) {
        priority = project;
        priorityScore = score;
      }
    }
    priority ??= active.first;

    final result = _feasibilityService.evaluate(
      project: priority,
      currentFreeCashCents: currentFreeCashCents,
      activeCredits: activeCredits,
    );
    final scenarios = _scenarioService.generate(
      project: priority,
      currentFreeCashCents: currentFreeCashCents,
      activeCredits: activeCredits,
    );
    final recommended = _scenarioService.recommend(scenarios);
    final color = feasibilityLevelColor(result.level);
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      color: Color.alphaBlend(color.withValues(alpha: 0.08), colorScheme.surfaceContainerHigh),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: () =>
            Navigator.of(context).push(AppPageRoute(builder: (_) => ProjectDetailPage(projectId: priority!.id))),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('🎯 PROJET PRIORITAIRE',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(letterSpacing: 1.5, color: colorScheme.onSurfaceVariant)),
              const SizedBox(height: AppSpacing.sm),
              Text('${projectCategoryEmoji(priority.category)} ${priority.name}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Text('${result.totalScore}%',
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(color: color, fontWeight: FontWeight.w700)),
                  const SizedBox(width: AppSpacing.xs),
                  Text('— ${feasibilityLevelEmoji(result.level)} ${feasibilityLevelLabel(result.level)}',
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
              if (recommended != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(recommended.description, style: Theme.of(context).textTheme.bodySmall),
              ],
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (active.length > 1)
                    TextButton(
                      onPressed: () => Navigator.of(context).push(AppPageRoute(builder: (_) => const ProjectsPage())),
                      child: const Text('Tous les projets'),
                    )
                  else
                    const SizedBox.shrink(),
                  TextButton(
                    onPressed: () => Navigator.of(context)
                        .push(AppPageRoute(builder: (_) => ProjectDetailPage(projectId: priority!.id))),
                    child: const Text('Voir le projet'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyProjectsCard extends StatelessWidget {
  const _EmptyProjectsCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: () => Navigator.of(context).push(AppPageRoute(builder: (_) => const ProjectsPage())),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: CategoryColors.credit.withValues(alpha: 0.2), shape: BoxShape.circle),
                child: const Icon(Icons.flag_rounded, size: 17, color: CategoryColors.credit),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Projets', style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      'Voiture, travaux, voyage... découvre si tu peux réellement les réaliser.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 20, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
