import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatting/currency_formatter.dart';
import '../../core/providers/credits_providers.dart';
import '../../core/providers/dashboard_providers.dart';
import '../../core/providers/projects_providers.dart';
import '../../core/routing/app_page_route.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/staggered_fade_in.dart';
import '../../domain/calculations/credit_calculation_service.dart';
import '../../domain/calculations/project_feasibility_service.dart';
import '../../domain/entities/credit_entity.dart';
import '../../domain/entities/project_entity.dart';
import 'project_detail_page.dart';
import 'project_form_page.dart';
import 'project_visuals.dart';

const _feasibilityService = ProjectFeasibilityService();
const _creditCalculationService = CreditCalculationService();

/// Page "Projets" (V1.0 — Project Planner, §13) : "puis-je réellement
/// réaliser ce projet ?" pour chaque projet actif — jamais une simple jauge
/// d'épargne.
class ProjectsPage extends ConsumerWidget {
  const ProjectsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectsProvider);
    final dashboardAsync = ref.watch(dashboardProvider);
    final creditsAsync = ref.watch(creditsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Projets')),
      body: SafeArea(
        child: projectsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => const Center(child: Text('Impossible de charger les projets')),
          data: (projects) {
            if (projects.isEmpty) return const _EmptyProjects();

            final currentFreeCashCents = dashboardAsync.valueOrNull?.realRemainingCents ?? 0;
            final activeCredits = _creditCalculationService.activeOnly(creditsAsync.valueOrNull ?? const []);
            final active = projects.where((p) => p.isActive).toList();
            final archived = projects.where((p) => !p.isActive).toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 88),
              children: [
                if (active.isEmpty)
                  const _EmptyProjects()
                else
                  for (final (index, project) in active.indexed) ...[
                    StaggeredFadeIn(
                      index: index,
                      child: _ProjectCard(
                        project: project,
                        currentFreeCashCents: currentFreeCashCents,
                        activeCredits: activeCredits,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                if (archived.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text('Archivés (${archived.length})', style: Theme.of(context).textTheme.titleSmall),
                    children: [
                      for (final project in archived)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _ProjectCard(
                            project: project,
                            currentFreeCashCents: currentFreeCashCents,
                            activeCredits: activeCredits,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(AppPageRoute(builder: (_) => const ProjectFormPage())),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _EmptyProjects extends StatelessWidget {
  const _EmptyProjects();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flag_outlined, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: AppSpacing.lg),
            Text('Aucun projet', style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Ajoute un projet — voiture, travaux, voyage — pour savoir si tu peux réellement le réaliser.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final ProjectEntity project;
  final int currentFreeCashCents;
  final List<CreditEntity> activeCredits;

  const _ProjectCard({
    required this.project,
    required this.currentFreeCashCents,
    required this.activeCredits,
  });

  @override
  Widget build(BuildContext context) {
    final result = _feasibilityService.evaluate(
      project: project,
      currentFreeCashCents: currentFreeCashCents,
      activeCredits: activeCredits,
    );
    final color = feasibilityLevelColor(result.level);
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: () => Navigator.of(context).push(AppPageRoute(builder: (_) => ProjectDetailPage(projectId: project.id))),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(projectCategoryEmoji(project.category), style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(project.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  if (!project.isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                      decoration: BoxDecoration(
                        color: colorScheme.outline.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                      ),
                      child: Text('Archivé',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: colorScheme.outline, fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(formatCentsAsEuro(project.targetAmountCents),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.sm),
                child: LinearProgressIndicator(
                  value: result.totalScore / 100,
                  minHeight: 8,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  color: color,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${result.totalScore}%',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                    ),
                    child: Text(
                      '${feasibilityLevelEmoji(result.level)} ${feasibilityLevelLabel(result.level)}',
                      style:
                          Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              if (project.desiredDate != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Objectif : ${formatMonthYearFr(project.desiredDate!)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
