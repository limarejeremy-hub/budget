import 'dart:math' as math;

import '../entities/credit_entity.dart';
import '../entities/project_entity.dart';
import 'credit_calculation_service.dart';
import 'credit_term_calculator.dart';

const _creditCalculationService = CreditCalculationService();
const _termCalculator = CreditTermCalculator();

/// -----------------------------------------------------------------------
/// Paramètres du moteur de faisabilité — centralisés et documentés, jamais
/// de seuil arbitraire caché ailleurs dans le code (V1.0, §4/§19).
/// -----------------------------------------------------------------------

/// Part de l'argent libre actuel que BudgetPilot considère comme la marge
/// de sécurité "confortable" à conserver après la réalisation d'un projet.
/// Ne signifie pas qu'un projet est refusé au-delà : le score B décroît
/// progressivement, sans jamais bloquer brutalement.
const double kSafetyMarginRatio = 0.20;

/// Durée de financement utilisée quand ni la durée souhaitée, ni la
/// mensualité maximale ne permettent de la déduire — un crédit conso/auto
/// classique en France se négocie le plus souvent entre 3 et 7 ans ; 5 ans
/// est une hypothèse médiane raisonnable, toujours signalée comme estimée
/// (`isDurationEstimated`), jamais silencieuse.
const int kDefaultFinancingDurationMonths = 60;

/// Horizon (en mois) sur lequel BudgetPilot recherche des crédits actifs
/// dont la fin prochaine libérerait de la capacité mensuelle pour le
/// projet — au minimum cette durée, étendue jusqu'à la date souhaitée du
/// projet si elle est plus lointaine (un projet immobilier à 5 ans doit
/// pouvoir bénéficier d'un crédit qui se termine dans 4 ans).
const int kCreditImprovementHorizonMonths = 36;

/// Pondérations du score de faisabilité (§3) — somme = 1.0. Documentées ici
/// plutôt que dispersées dans le calcul, pour rester auditables et faciles
/// à ajuster.
const double kWeightCapacity = 0.25; // A — capacité mensuelle
const double kWeightSafetyMargin = 0.20; // B — marge de sécurité
const double kWeightContribution = 0.20; // C — apport / besoin de financement
const double kWeightCreditPressure = 0.15; // D — pression des crédits actuels
const double kWeightFutureImprovement = 0.10; // E — évolution future connue
const double kWeightHorizon = 0.10; // F — horizon du projet

/// Détail du financement estimé d'un projet — jamais d'hypothèse cachée :
/// [isDurationEstimated] et [isRateEstimated] indiquent explicitement quand
/// une valeur a dû être déduite faute de saisie.
class ProjectFinancingBreakdown {
  final int targetAmountCents;
  final int contributionCents;
  final int financingNeededCents;

  /// Mensualité estimée du financement — 0 pour un projet comptant sans
  /// financement nécessaire.
  final int estimatedMonthlyPaymentCents;
  final int extraMonthlyCostCents;

  /// [estimatedMonthlyPaymentCents] + [extraMonthlyCostCents].
  final int totalMonthlyImpactCents;

  /// Durée (en mois) effectivement utilisée pour estimer la mensualité.
  final int usedDurationMonths;

  /// `true` si ni la durée souhaitée ni la mensualité maximale n'ont permis
  /// de déduire la durée — [kDefaultFinancingDurationMonths] a été utilisée.
  final bool isDurationEstimated;

  /// `true` si aucun taux n'a été renseigné — la mensualité est alors une
  /// estimation simplifiée (capital / durée), sans intérêts.
  final bool isRateEstimated;

  const ProjectFinancingBreakdown({
    required this.targetAmountCents,
    required this.contributionCents,
    required this.financingNeededCents,
    required this.estimatedMonthlyPaymentCents,
    required this.extraMonthlyCostCents,
    required this.totalMonthlyImpactCents,
    required this.usedDurationMonths,
    required this.isDurationEstimated,
    required this.isRateEstimated,
  });
}

/// Niveaux de faisabilité (§3) — jamais présentés comme une décision
/// bancaire, une capacité d'emprunt officielle ni un conseil réglementé.
enum FeasibilityLevel { veryDifficult, fragile, feasible, comfortable, veryComfortable }

FeasibilityLevel feasibilityLevelForScore(int score) {
  if (score < 40) return FeasibilityLevel.veryDifficult;
  if (score < 60) return FeasibilityLevel.fragile;
  if (score < 75) return FeasibilityLevel.feasible;
  if (score < 90) return FeasibilityLevel.comfortable;
  return FeasibilityLevel.veryComfortable;
}

String feasibilityLevelLabel(FeasibilityLevel level) {
  switch (level) {
    case FeasibilityLevel.veryDifficult:
      return 'Très difficile actuellement';
    case FeasibilityLevel.fragile:
      return 'Fragile';
    case FeasibilityLevel.feasible:
      return 'Envisageable';
    case FeasibilityLevel.comfortable:
      return 'Réalisable';
    case FeasibilityLevel.veryComfortable:
      return 'Très confortable';
  }
}

String feasibilityLevelEmoji(FeasibilityLevel level) {
  switch (level) {
    case FeasibilityLevel.veryDifficult:
      return '🔴';
    case FeasibilityLevel.fragile:
      return '🟠';
    case FeasibilityLevel.feasible:
      return '🟡';
    case FeasibilityLevel.comfortable:
    case FeasibilityLevel.veryComfortable:
      return '🟢';
  }
}

/// Détail des 6 critères du score (§3, A à F), chacun sur 0-100 avant
/// pondération — permet d'expliquer "ce qui bloque" plutôt que de livrer
/// un nombre opaque.
class ProjectFeasibilityScoreBreakdown {
  final int capacityScore; // A
  final int safetyMarginScore; // B
  final int contributionScore; // C
  final int creditPressureScore; // D
  final int futureImprovementScore; // E
  final int horizonScore; // F
  final int totalScore;

  const ProjectFeasibilityScoreBreakdown({
    required this.capacityScore,
    required this.safetyMarginScore,
    required this.contributionScore,
    required this.creditPressureScore,
    required this.futureImprovementScore,
    required this.horizonScore,
    required this.totalScore,
  });
}

/// Un crédit actif dont la fin prochaine (dans l'horizon de recherche)
/// libérerait de la capacité mensuelle pour le projet — "ce qui va
/// s'améliorer" (§6/§12), jamais un événement inventé.
class CreditImprovement {
  final CreditEntity credit;
  final int monthsUntilFreed;
  final int monthlyPaymentFreedCents;

  const CreditImprovement({
    required this.credit,
    required this.monthsUntilFreed,
    required this.monthlyPaymentFreedCents,
  });
}

/// Résultat complet de l'évaluation d'un projet — toujours recalculé à la
/// volée à partir des données courantes, jamais persisté (§18).
class ProjectFeasibilityResult {
  final ProjectFinancingBreakdown financing;
  final ProjectFeasibilityScoreBreakdown score;
  final FeasibilityLevel level;

  /// Argent libre actuel - impact mensuel total du projet. Peut être
  /// négatif : BudgetPilot ne le masque jamais.
  final int marginAfterCents;

  /// Explications de ce qui limite la faisabilité aujourd'hui — vide si le
  /// projet est confortable sur tous les critères.
  final List<String> blockers;

  /// Crédits actifs dont la fin prochaine libérerait de la capacité,
  /// triés par date de fin la plus proche.
  final List<CreditImprovement> upcomingImprovements;

  const ProjectFeasibilityResult({
    required this.financing,
    required this.score,
    required this.level,
    required this.marginAfterCents,
    required this.blockers,
    required this.upcomingImprovements,
  });

  int get totalScore => score.totalScore;
}

/// Moteur de faisabilité financière (V1.0 — Project Planner). Déterministe
/// et pur : ne dépend que des données passées en argument (déjà chargées
/// par les repositories existants — jamais de nouvelle requête, jamais de
/// duplication de la logique financière déjà présente dans
/// `BudgetCalculationService` / `CreditCalculationService`).
///
/// Le score n'est **jamais** `apport / prix × 100` : voir §3, six critères
/// pondérés (constantes `kWeight*` ci-dessus), documentés et testés
/// indépendamment.
class ProjectFeasibilityService {
  const ProjectFeasibilityService();

  /// Calcule le financement estimé d'un projet — utilisable seul (ex :
  /// affichage "Situation" de la fiche projet) sans recalculer le score.
  ProjectFinancingBreakdown computeFinancing(ProjectEntity project) {
    final contribution = project.availableContributionCents;
    final financingNeeded = math.max(0, project.targetAmountCents - contribution);
    final extra = project.effectiveExtraMonthlyCostCents;

    if (project.isCashOnly || financingNeeded <= 0) {
      return ProjectFinancingBreakdown(
        targetAmountCents: project.targetAmountCents,
        contributionCents: contribution,
        financingNeededCents: financingNeeded,
        estimatedMonthlyPaymentCents: 0,
        extraMonthlyCostCents: extra,
        totalMonthlyImpactCents: extra,
        usedDurationMonths: 0,
        isDurationEstimated: false,
        isRateEstimated: false,
      );
    }

    final rate = project.estimatedRatePercent;
    final isRateEstimated = rate == null;
    final monthlyRate = (rate ?? 0) / 100 / 12;

    final (durationMonths, isDurationEstimated) = _resolveDurationMonths(
      project: project,
      financingNeededCents: financingNeeded,
      monthlyRate: monthlyRate,
    );

    final monthlyPayment = _estimateMonthlyPayment(
      principalCents: financingNeeded,
      monthlyRate: monthlyRate,
      durationMonths: durationMonths,
    );

    return ProjectFinancingBreakdown(
      targetAmountCents: project.targetAmountCents,
      contributionCents: contribution,
      financingNeededCents: financingNeeded,
      estimatedMonthlyPaymentCents: monthlyPayment,
      extraMonthlyCostCents: extra,
      totalMonthlyImpactCents: monthlyPayment + extra,
      usedDurationMonths: durationMonths,
      isDurationEstimated: isDurationEstimated,
      isRateEstimated: isRateEstimated,
    );
  }

  /// Évalue la faisabilité complète d'un projet à partir de la situation
  /// financière courante — argent libre (déjà calculé par
  /// `BudgetCalculationService`/`DashboardViewBuilder`, jamais recalculé
  /// ici) et crédits actifs (déjà chargés via `CycleRepository`).
  ProjectFeasibilityResult evaluate({
    required ProjectEntity project,
    required int currentFreeCashCents,
    required List<CreditEntity> activeCredits,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final financing = computeFinancing(project);
    final impact = financing.totalMonthlyImpactCents;
    final marginAfter = currentFreeCashCents - impact;

    final scoreA = _capacityScore(impact, currentFreeCashCents);
    final scoreB = _safetyMarginScore(marginAfter, currentFreeCashCents);
    final scoreC = _contributionScore(project);
    final activePayments = _creditCalculationService.totalMonthlyPayments(activeCredits);
    final scoreD = _creditPressureScore(activePayments, currentFreeCashCents);

    final horizonMonths = _improvementHorizonMonths(project, today);
    final improvements = _upcomingImprovements(activeCredits, horizonMonths);
    final potentialFreedCents = improvements.fold(0, (sum, i) => sum + i.monthlyPaymentFreedCents);
    final gapCents = impact - currentFreeCashCents;
    final scoreE = _futureImprovementScore(gapCents, potentialFreedCents);
    final scoreF = _horizonScore(project, today, gapCents, improvements);

    final total = (scoreA * kWeightCapacity +
            scoreB * kWeightSafetyMargin +
            scoreC * kWeightContribution +
            scoreD * kWeightCreditPressure +
            scoreE * kWeightFutureImprovement +
            scoreF * kWeightHorizon)
        .round()
        .clamp(0, 100);

    final breakdown = ProjectFeasibilityScoreBreakdown(
      capacityScore: scoreA,
      safetyMarginScore: scoreB,
      contributionScore: scoreC,
      creditPressureScore: scoreD,
      futureImprovementScore: scoreE,
      horizonScore: scoreF,
      totalScore: total,
    );

    return ProjectFeasibilityResult(
      financing: financing,
      score: breakdown,
      level: feasibilityLevelForScore(total),
      marginAfterCents: marginAfter,
      blockers: _blockersFor(
        scoreA: scoreA,
        scoreB: scoreB,
        scoreC: scoreC,
        scoreD: scoreD,
      ),
      upcomingImprovements: improvements,
    );
  }

  // -- Financement -------------------------------------------------------

  (int durationMonths, bool isEstimated) _resolveDurationMonths({
    required ProjectEntity project,
    required int financingNeededCents,
    required double monthlyRate,
  }) {
    final desired = project.desiredDurationMonths;
    if (desired != null && desired > 0) return (desired, false);

    final maxPayment = project.maxMonthlyPaymentCents;
    if (maxPayment != null && maxPayment > 0) {
      final derived = _durationForMonthlyPayment(
        principalCents: financingNeededCents,
        monthlyRate: monthlyRate,
        monthlyPaymentCents: maxPayment,
      );
      if (derived != null) return (derived, false);
    }

    return (kDefaultFinancingDurationMonths, true);
  }

  /// Mensualité d'amortissement classique quand un taux est renseigné
  /// (M = P·r / (1 − (1+r)⁻ⁿ)), sinon estimation simplifiée linéaire
  /// (M = P / n) — toujours signalée via `isRateEstimated` côté appelant.
  int _estimateMonthlyPayment({
    required int principalCents,
    required double monthlyRate,
    required int durationMonths,
  }) {
    if (durationMonths <= 0) return principalCents;
    if (monthlyRate <= 0) return (principalCents / durationMonths).ceil();
    final factor = math.pow(1 + monthlyRate, durationMonths);
    final payment = principalCents * monthlyRate * factor / (factor - 1);
    return payment.ceil();
  }

  /// Résout la durée (en mois) nécessaire pour amortir [principalCents] à
  /// [monthlyRate] avec une mensualité de [monthlyPaymentCents] — `null` si
  /// cette mensualité ne couvrirait jamais ne serait-ce que les intérêts.
  int? _durationForMonthlyPayment({
    required int principalCents,
    required double monthlyRate,
    required int monthlyPaymentCents,
  }) {
    if (monthlyRate <= 0) {
      return (principalCents / monthlyPaymentCents).ceil();
    }
    final interestOnlyPayment = principalCents * monthlyRate;
    if (monthlyPaymentCents <= interestOnlyPayment) return null;
    final n = -math.log(1 - (monthlyRate * principalCents) / monthlyPaymentCents) / math.log(1 + monthlyRate);
    if (!n.isFinite || n <= 0) return null;
    return n.ceil();
  }

  // -- Score : critères individuels (0-100) -------------------------------

  /// A — capacité mensuelle : 100 si l'impact mensuel est nul, décroît
  /// linéairement jusqu'à 0 quand il atteint (ou dépasse) l'intégralité de
  /// l'argent libre actuel.
  int _capacityScore(int totalMonthlyImpactCents, int currentFreeCashCents) {
    if (totalMonthlyImpactCents <= 0) return 100;
    if (currentFreeCashCents <= 0) return 0;
    final ratio = totalMonthlyImpactCents / currentFreeCashCents;
    return (100 * (1 - ratio)).round().clamp(0, 100);
  }

  /// B — marge de sécurité : 100 quand ce qu'il reste après le projet
  /// atteint (ou dépasse) [kSafetyMarginRatio] de l'argent libre actuel,
  /// décroît linéairement jusqu'à 0 quand il ne reste plus rien.
  int _safetyMarginScore(int marginAfterCents, int currentFreeCashCents) {
    if (currentFreeCashCents <= 0 || marginAfterCents <= 0) return 0;
    final safetyTarget = math.max(1, (currentFreeCashCents * kSafetyMarginRatio).round());
    return (100 * marginAfterCents / safetyTarget).round().clamp(0, 100);
  }

  /// C — apport / besoin de financement : proportion du prix cible déjà
  /// couverte par l'apport disponible.
  int _contributionScore(ProjectEntity project) {
    if (project.targetAmountCents <= 0) return 100;
    final ratio = (project.availableContributionCents / project.targetAmountCents).clamp(0.0, 1.0);
    return (ratio * 100).round();
  }

  /// D — pression des crédits actuels : part de la capacité déjà engagée
  /// dans des mensualités de crédit, avant même ce nouveau projet.
  int _creditPressureScore(int activeCreditMonthlyPaymentsCents, int currentFreeCashCents) {
    final total = activeCreditMonthlyPaymentsCents + currentFreeCashCents;
    if (total <= 0) return activeCreditMonthlyPaymentsCents <= 0 ? 100 : 0;
    final pressure = (activeCreditMonthlyPaymentsCents / total).clamp(0.0, 1.0);
    return (100 * (1 - pressure)).round();
  }

  /// E — évolution future connue : si le projet est déjà finançable
  /// aujourd'hui, ce critère est neutre (100). Sinon, mesure la part de
  /// l'écart manquant que la capacité bientôt libérée par des crédits en
  /// fin de vie permettrait de combler.
  int _futureImprovementScore(int gapCents, int potentialFreedCents) {
    if (gapCents <= 0) return 100;
    final ratio = (potentialFreedCents / gapCents).clamp(0.0, 1.0);
    return (ratio * 100).round();
  }

  /// F — horizon du projet : neutre (50) sans date souhaitée. Avec une
  /// date : 100 si déjà finançable ; sinon compare le temps restant avant
  /// cette date au temps nécessaire pour qu'assez de capacité soit libérée
  /// par les crédits identifiés. Sans crédit suffisant identifié, un
  /// palier prudent reflète l'incertitude plutôt que d'inventer une
  /// évolution future non observable.
  int _horizonScore(
    ProjectEntity project,
    DateTime today,
    int gapCents,
    List<CreditImprovement> improvements,
  ) {
    final desiredDate = project.desiredDate;
    if (desiredDate == null) return 50;
    if (gapCents <= 0) return 100;

    final monthsUntilDesired = _termCalculator.monthsUntil(today, desiredDate);
    final monthsNeeded = _monthsNeededToCloseGap(gapCents, improvements);
    if (monthsNeeded == null) return monthsUntilDesired >= 12 ? 40 : 15;
    if (monthsUntilDesired >= monthsNeeded) return 100;
    if (monthsNeeded <= 0) return 100;
    return (100 * monthsUntilDesired / monthsNeeded).round().clamp(0, 100);
  }

  /// Premier horizon (en mois, trié croissant) où la capacité cumulée
  /// libérée par les crédits identifiés comble [gapCents] — `null` si
  /// aucune combinaison connue n'y suffit.
  int? _monthsNeededToCloseGap(int gapCents, List<CreditImprovement> improvements) {
    var cumulative = 0;
    for (final improvement in improvements) {
      cumulative += improvement.monthlyPaymentFreedCents;
      if (cumulative >= gapCents) return improvement.monthsUntilFreed;
    }
    return null;
  }

  int _improvementHorizonMonths(ProjectEntity project, DateTime today) {
    final desiredDate = project.desiredDate;
    if (desiredDate == null) return kCreditImprovementHorizonMonths;
    final monthsToDesired = _termCalculator.monthsUntil(today, desiredDate);
    return math.max(kCreditImprovementHorizonMonths, monthsToDesired);
  }

  List<CreditImprovement> _upcomingImprovements(List<CreditEntity> activeCredits, int horizonMonths) {
    final improvements = activeCredits
        .where((c) => c.remainingInstallments > 0 && c.remainingInstallments <= horizonMonths)
        .map((c) => CreditImprovement(
              credit: c,
              monthsUntilFreed: c.remainingInstallments,
              monthlyPaymentFreedCents: c.monthlyPaymentCents,
            ))
        .toList()
      ..sort((a, b) => a.monthsUntilFreed.compareTo(b.monthsUntilFreed));
    return improvements;
  }

  List<String> _blockersFor({
    required int scoreA,
    required int scoreB,
    required int scoreC,
    required int scoreD,
  }) {
    final blockers = <String>[];
    if (scoreA < 60) {
      blockers.add('Le financement de ce projet consommerait actuellement une part importante de ton argent libre.');
    }
    if (scoreB < 50) {
      blockers.add('Il resterait peu de marge de sécurité après la réalisation de ce projet.');
    }
    if (scoreC < 40) {
      blockers.add(
          "L'apport actuel ne couvre qu'une faible partie du prix cible — le financement nécessaire est important.");
    }
    if (scoreD < 50) {
      blockers.add('Les crédits déjà en cours limitent la capacité disponible pour ce nouveau projet.');
    }
    return blockers;
  }
}
