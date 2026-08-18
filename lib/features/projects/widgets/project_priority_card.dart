import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/formatting/currency_formatter.dart';
import '../../../core/providers/credits_providers.dart';
import '../../../core/providers/dashboard_providers.dart';
import '../../../core/providers/projects_providers.dart';
import '../../../core/routing/app_page_route.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../domain/calculations/credit_calculation_service.dart';
import '../../../domain/calculations/debt_ratio_bands.dart';
import '../../../domain/calculations/household_finance_service.dart';
import '../../../domain/calculations/project_health_service.dart';
import '../../../domain/entities/credit_entity.dart';
import '../../../domain/entities/project_entity.dart';
import '../project_detail_page.dart';
import '../project_visuals.dart';
import '../projects_page.dart';

const _healthService = ProjectHealthService();
const _creditCalculationService = CreditCalculationService();
const _householdFinanceService = HouseholdFinanceService();

/// Carte "Projets" de la Home — point d'entrée naturel vers le module
/// Projets (§1), qui devient la carte "Projet prioritaire" (§14 V1.0, §13
/// V1.1) dès qu'un projet actif existe : un seul projet mis en avant,
/// jamais toute la liste, jamais une grande zone vide.
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
    final totalIncomeCents = dashboard.totalIncomeCents;
    // Reste à vivre STRUCTUREL (jamais l'argent libre du cycle) : le
    // Project Planner mesure la capacité financière récurrente du foyer,
    // pas ce qui a déjà été dépensé ce mois-ci.
    final currentFreeCashCents = _householdFinanceService.structuralRemainingCents(
      totalIncomeCents: totalIncomeCents,
      totalFixedExpensesExcludingCreditsCents: dashboard.totalFixedExpensesExcludingCreditsCents,
      activeCredits: activeCredits,
    );

    final priority = _selectPriorityProject(
      active,
      currentFreeCashCents: currentFreeCashCents,
      totalIncomeCents: totalIncomeCents,
      activeCredits: activeCredits,
    );

    final health = _healthService.evaluate(
      project: priority,
      currentFreeCashCents: currentFreeCashCents,
      totalIncomeCents: totalIncomeCents,
      activeCredits: activeCredits,
    );
    final feasibilityColor = feasibilityLevelColor(health.feasibility.level);
    final debtColor = debtRatioBandColor(debtRatioBandFor(health.debtImpact.debtRatioAfter));
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      color: Color.alphaBlend(feasibilityColor.withValues(alpha: 0.08), colorScheme.surfaceContainerHigh),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: () =>
            Navigator.of(context).push(AppPageRoute(builder: (_) => ProjectDetailPage(projectId: priority.id))),
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
              Text('Faisabilité : ${health.feasibility.totalScore}%',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: feasibilityColor, fontWeight: FontWeight.w700)),
              Text('Endettement après projet : ${(health.debtImpact.debtRatioAfter * 100).round()}%',
                  style:
                      Theme.of(context).textTheme.bodyMedium?.copyWith(color: debtColor, fontWeight: FontWeight.w700)),
              Text(
                'Reste à vivre après projet : ${formatCentsAsEuro(health.debtImpact.remainingAfterCents)}/mois',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(health.conclusion, style: Theme.of(context).textTheme.bodySmall),
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
                        .push(AppPageRoute(builder: (_) => ProjectDetailPage(projectId: priority.id))),
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

  /// Choix du projet mis en avant sur la Home (V1.1, §1) : d'abord la
  /// priorité utilisateur (Haute > Moyenne > Basse), puis la faisabilité
  /// (le plus avancé d'abord, en cas d'égalité de priorité), puis la date
  /// cible la plus proche. Jamais limité à un seul projet dans
  /// l'application : c'est uniquement la mise en avant sur la Home qui
  /// n'en choisit qu'un.
  ProjectEntity _selectPriorityProject(
    List<ProjectEntity> active, {
    required int currentFreeCashCents,
    required int totalIncomeCents,
    required List<CreditEntity> activeCredits,
  }) {
    int feasibilityOf(ProjectEntity project) => _healthService
        .evaluate(
          project: project,
          currentFreeCashCents: currentFreeCashCents,
          totalIncomeCents: totalIncomeCents,
          activeCredits: activeCredits,
        )
        .feasibility
        .totalScore;

    final sorted = [...active]..sort((a, b) {
        final byPriority = ProjectPriority.rank(a.priority).compareTo(ProjectPriority.rank(b.priority));
        if (byPriority != 0) return byPriority;

        final byFeasibility = feasibilityOf(b).compareTo(feasibilityOf(a));
        if (byFeasibility != 0) return byFeasibility;

        final dateA = a.desiredDate;
        final dateB = b.desiredDate;
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateA.compareTo(dateB);
      });

    return sorted.first;
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
