import '../entities/credit_entity.dart';
import '../entities/project_entity.dart';
import 'project_feasibility_service.dart';
import 'project_safety_service.dart';

/// Pondérations du Project Health Score global (§6, V1.1) — la sécurité
/// pèse plus que la faisabilité brute ("la sécurité financière passe avant
/// la simple faisabilité"). Ce score global n'est qu'un résumé : les deux
/// scores détaillés (Faisabilité, Sécurité) restent toujours affichés
/// séparément, jamais masqués par lui.
const double kHealthWeightFeasibility = 0.45;
const double kHealthWeightSafety = 0.55;

/// Nombre maximal de bloqueurs affichés (§7) — classés par importance,
/// jamais une liste exhaustive.
const int kMaxDisplayedBlockers = 3;

/// Résultat combiné faisabilité + sécurité financière d'un projet — jamais
/// l'un sans l'autre : c'est tout l'objet de la V1.1.
class ProjectHealthResult {
  final ProjectFeasibilityResult feasibility;
  final ProjectSafetyResult safety;

  /// Résumé global — ne remplace jamais l'affichage des deux scores
  /// détaillés (§6).
  final int healthScore;

  /// 1 à 3 raisons maximum, classées par importance (§7).
  final List<String> blockers;

  /// Une phrase de synthèse, jamais culpabilisante ni une promesse
  /// bancaire (§6/§10).
  final String conclusion;

  const ProjectHealthResult({
    required this.feasibility,
    required this.safety,
    required this.healthScore,
    required this.blockers,
    required this.conclusion,
  });
}

/// Combine [ProjectFeasibilityService] et [ProjectSafetyService] — jamais de
/// duplication de leurs calculs, uniquement une synthèse.
class ProjectHealthService {
  final ProjectFeasibilityService feasibilityService;
  final ProjectSafetyService safetyService;
  const ProjectHealthService({
    this.feasibilityService = const ProjectFeasibilityService(),
    this.safetyService = const ProjectSafetyService(),
  });

  ProjectHealthResult evaluate({
    required ProjectEntity project,
    required int currentFreeCashCents,
    required int totalIncomeCents,
    required List<CreditEntity> activeCredits,
    DateTime? now,
  }) {
    final feasibility = feasibilityService.evaluate(
      project: project,
      currentFreeCashCents: currentFreeCashCents,
      activeCredits: activeCredits,
      now: now,
    );
    final safety = safetyService.evaluate(
      project: project,
      currentFreeCashCents: currentFreeCashCents,
      totalIncomeCents: totalIncomeCents,
      activeCredits: activeCredits,
    );

    final health = (feasibility.totalScore * kHealthWeightFeasibility + safety.totalScore * kHealthWeightSafety)
        .round()
        .clamp(0, 100);

    return ProjectHealthResult(
      feasibility: feasibility,
      safety: safety,
      healthScore: health,
      blockers: _combinedBlockers(
        project: project,
        feasibility: feasibility,
        safety: safety,
        activeCredits: activeCredits,
      ),
      conclusion: _conclusionFor(feasibility, safety),
    );
  }

  List<String> _combinedBlockers({
    required ProjectEntity project,
    required ProjectFeasibilityResult feasibility,
    required ProjectSafetyResult safety,
    required List<CreditEntity> activeCredits,
  }) {
    final candidates = <MapEntry<int, String>>[];

    if (safety.debtRatioAfter > kDebtRatioTense) {
      final severity = 90 + ((safety.debtRatioAfter - kDebtRatioTense) * 100).round();
      candidates.add(MapEntry(
        severity,
        'Le taux d\'endettement après ce projet deviendrait important '
        '(${(safety.debtRatioAfter * 100).round()} %).',
      ));
    }
    if (safety.remainingAfterCents <= 0) {
      candidates.add(const MapEntry(100, 'Le reste à vivre deviendrait négatif après ce projet.'));
    } else if (safety.score.remainingLivingScore < 50) {
      candidates.add(
          MapEntry(85 - safety.score.remainingLivingScore, 'Le reste à vivre après ce projet serait trop faible.'));
    }
    if (safety.score.marginDropScore < 50) {
      candidates.add(
          MapEntry(70 - safety.score.marginDropScore, 'Ce projet réduirait fortement ta marge mensuelle actuelle.'));
    }
    final maxPayment = project.maxMonthlyPaymentCents;
    if (maxPayment != null && maxPayment > 0 && feasibility.financing.estimatedMonthlyPaymentCents > maxPayment) {
      candidates.add(const MapEntry(65, 'La mensualité estimée dépasse la mensualité maximale souhaitée.'));
    }
    if (activeCredits.length >= 3) {
      candidates.add(const MapEntry(55, 'Plusieurs crédits sont déjà actifs, ce qui limite la capacité disponible.'));
    }
    for (final blocker in feasibility.blockers) {
      candidates.add(MapEntry(40, blocker));
    }

    candidates.sort((a, b) => b.key.compareTo(a.key));
    final result = <String>[];
    for (final candidate in candidates) {
      if (result.contains(candidate.value)) continue;
      result.add(candidate.value);
      if (result.length >= kMaxDisplayedBlockers) break;
    }
    return result;
  }

  /// Phrase de synthèse (§6) — jamais culpabilisante, jamais une promesse
  /// bancaire. Croise les deux scores : un projet finançable mais peu sûr
  /// est déconseillé même s'il "passe" mathématiquement.
  String _conclusionFor(ProjectFeasibilityResult feasibility, ProjectSafetyResult safety) {
    final feasible = feasibility.totalScore >= 60;
    final safe = safety.totalScore >= 60;

    if (feasible && safe) {
      final String nuance;
      if (feasibility.score.contributionScore < 60) {
        nuance = ", mais l'apport est encore faible";
      } else if (safety.totalScore < 80) {
        nuance = ', avec une marge de sécurité correcte sans être large';
      } else {
        nuance = '';
      }
      return 'Le projet est ${feasibilityLevelLabel(feasibility.level).toLowerCase()} '
          'et resterait financièrement ${financialSafetyLevelLabel(safety.level).toLowerCase()}$nuance.';
    }
    if (feasible && !safe) {
      return 'Le projet semble finançable mais réduirait fortement ton reste à vivre. '
          'BudgetPilot déconseille de le réaliser dans ces conditions.';
    }
    if (!feasible && safe) {
      return 'Le budget resterait sain, mais ce projet n\'est pas encore finançable dans de bonnes conditions aujourd\'hui.';
    }
    return 'Ce projet est à la fois difficile à financer et risqué pour ton budget dans sa forme actuelle.';
  }
}
