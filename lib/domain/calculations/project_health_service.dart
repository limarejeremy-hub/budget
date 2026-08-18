import '../entities/credit_entity.dart';
import '../entities/project_entity.dart';
import 'project_debt_impact_service.dart';
import 'project_feasibility_service.dart';

/// Nombre maximal de bloqueurs affichés — classés par importance, jamais une
/// liste exhaustive.
const int kMaxDisplayedBlockers = 3;

/// Part du revenu en dessous de laquelle le reste à vivre après projet est
/// considéré trop faible — repère interne documenté, jamais un montant fixe
/// seul.
const double kLowRemainingIncomeShareThreshold = 0.15;

/// Résultat combiné faisabilité + impact budgétaire d'un projet — jamais
/// l'un sans l'autre. Analyse simplifiée (V1.2) : plus de score de
/// "sécurité" ni de score global agrégé, uniquement des indicateurs
/// concrets (taux d'endettement, reste à vivre) à côté de la faisabilité.
class ProjectHealthResult {
  final ProjectFeasibilityResult feasibility;
  final ProjectDebtImpactResult debtImpact;

  /// 1 à 3 raisons maximum, classées par importance.
  final List<String> blockers;

  /// Une phrase de synthèse, jamais culpabilisante ni une promesse
  /// bancaire.
  final String conclusion;

  const ProjectHealthResult({
    required this.feasibility,
    required this.debtImpact,
    required this.blockers,
    required this.conclusion,
  });
}

/// Combine [ProjectFeasibilityService] et [ProjectDebtImpactService] —
/// jamais de duplication de leurs calculs, uniquement une synthèse.
class ProjectHealthService {
  final ProjectFeasibilityService feasibilityService;
  final ProjectDebtImpactService debtImpactService;
  const ProjectHealthService({
    this.feasibilityService = const ProjectFeasibilityService(),
    this.debtImpactService = const ProjectDebtImpactService(),
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
    final debtImpact = debtImpactService.evaluate(
      project: project,
      currentFreeCashCents: currentFreeCashCents,
      totalIncomeCents: totalIncomeCents,
      activeCredits: activeCredits,
    );

    return ProjectHealthResult(
      feasibility: feasibility,
      debtImpact: debtImpact,
      blockers: _combinedBlockers(
        project: project,
        feasibility: feasibility,
        debtImpact: debtImpact,
        activeCredits: activeCredits,
      ),
      conclusion: _conclusionFor(feasibility, debtImpact),
    );
  }

  List<String> _combinedBlockers({
    required ProjectEntity project,
    required ProjectFeasibilityResult feasibility,
    required ProjectDebtImpactResult debtImpact,
    required List<CreditEntity> activeCredits,
  }) {
    final candidates = <MapEntry<int, String>>[];

    if (debtImpact.debtRatioAfter > kDebtRatioTense) {
      final severity = 90 + ((debtImpact.debtRatioAfter - kDebtRatioTense) * 100).round();
      candidates.add(MapEntry(
        severity,
        'Le taux d\'endettement après ce projet deviendrait important '
        '(${(debtImpact.debtRatioAfter * 100).round()} %).',
      ));
    }
    if (debtImpact.remainingAfterCents <= 0) {
      candidates.add(const MapEntry(100, 'Le reste à vivre deviendrait négatif après ce projet.'));
    } else if (debtImpact.currentIncomeCents > 0 &&
        debtImpact.remainingAfterCents / debtImpact.currentIncomeCents < kLowRemainingIncomeShareThreshold) {
      candidates.add(const MapEntry(85, 'Le reste à vivre après ce projet serait trop faible.'));
    }
    if (debtImpact.remainingBeforeCents > 0) {
      final dropRatio = (-debtImpact.remainingDeltaCents) / debtImpact.remainingBeforeCents;
      if (dropRatio >= kMaxHealthyRemainingDropRatio) {
        candidates.add(const MapEntry(70, 'Ce projet réduirait fortement ta marge mensuelle actuelle.'));
      }
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

  /// Phrase de synthèse — jamais culpabilisante, jamais une promesse
  /// bancaire. Croise la faisabilité avec des indicateurs concrets
  /// (taux d'endettement, reste à vivre) : un projet finançable mais
  /// dangereux pour le budget est déconseillé même s'il "passe"
  /// mathématiquement.
  String _conclusionFor(ProjectFeasibilityResult feasibility, ProjectDebtImpactResult debtImpact) {
    final feasible = feasibility.totalScore >= 60;
    final band = debtRatioBandFor(debtImpact.debtRatioAfter);
    final remainingNegative = debtImpact.remainingAfterCents <= 0;
    final heavyDrop = debtImpact.remainingBeforeCents > 0 &&
        (-debtImpact.remainingDeltaCents) / debtImpact.remainingBeforeCents >= kMaxHealthyRemainingDropRatio;
    final risky = remainingNegative || band == DebtRatioBand.high || heavyDrop;
    final watch = !risky && band == DebtRatioBand.tense;

    if (feasible && risky) {
      return 'Le projet semble finançable, mais l\'endettement ou le reste à vivre deviendrait trop important. '
          'BudgetPilot déconseille de le réaliser dans ces conditions.';
    }
    if (feasible && watch) {
      return 'Le projet est ${feasibilityLevelLabel(feasibility.level).toLowerCase()}, mais l\'endettement '
          'resterait à surveiller après ce projet.';
    }
    if (feasible) {
      final nuance = feasibility.score.contributionScore < 60 ? ", mais l'apport est encore faible" : '';
      return 'Le projet est ${feasibilityLevelLabel(feasibility.level).toLowerCase()} et resterait raisonnable '
          'pour ton budget$nuance.';
    }
    if (!risky) {
      return 'Le budget resterait maîtrisé, mais ce projet n\'est pas encore finançable dans de bonnes '
          'conditions aujourd\'hui.';
    }
    return 'Ce projet est à la fois difficile à financer et risqué pour ton budget dans sa forme actuelle.';
  }
}
