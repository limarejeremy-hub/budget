import '../entities/credit_entity.dart';
import '../entities/project_entity.dart';
import 'credit_calculation_service.dart';
import 'project_feasibility_service.dart';

const _creditCalculationService = CreditCalculationService();

/// -----------------------------------------------------------------------
/// Paramètres du Financial Safety Score (V1.1 — Safe Projects) — centralisés
/// et documentés, jamais un seuil arbitraire caché ailleurs dans le code.
/// -----------------------------------------------------------------------

/// Repères internes de taux d'endettement (mensualités de crédits actifs +
/// mensualité de financement du projet / revenus mensuels) — **jamais**
/// présentés comme une règle d'acceptation bancaire : uniquement des
/// repères BudgetPilot, configurables ici.
const double kDebtRatioComfortable = 0.30; // <= : 🟢 confortable
const double kDebtRatioWatch = 0.35; // <= : 🟡 à surveiller
const double kDebtRatioTense = 0.40; // <= : 🟠 tendu
// > kDebtRatioTense : 🔴 risque élevé

/// Au-delà de ce taux, le critère "endettement" du score de sécurité tombe
/// à 0 — un taux déjà extrême n'a pas besoin d'être noté "pire que zéro".
const double kDebtRatioFloorForZeroScore = 0.60;

/// Pondérations du Financial Safety Score (§2-§5) — somme = 1.0.
const double kSafetyWeightDebtRatio = 0.40;
const double kSafetyWeightRemainingLiving = 0.35;
const double kSafetyWeightMarginDrop = 0.25;

/// Part du revenu que la mensualité + les coûts du projet peuvent consommer
/// avant que le critère "reste à vivre relatif au revenu" ne tombe à 0 —
/// repère interne documenté, jamais un montant fixe (§5 : "tenir compte du
/// revenu, pas uniquement un montant fixe").
const double kMaxHealthyIncomeShareForProject = 0.30;

/// Baisse relative du reste à vivre (avant → après le projet) au-delà de
/// laquelle le critère "marge consommée" tombe à 0.
const double kMaxHealthyRemainingDropRatio = 0.50;

/// Niveau de sécurité financière global (§6/§16) — vert = sain, jaune =
/// acceptable, orange = tendu, rouge = risque élevé.
enum FinancialSafetyLevel { critical, tense, acceptable, healthy }

FinancialSafetyLevel financialSafetyLevelForScore(int score) {
  if (score < 40) return FinancialSafetyLevel.critical;
  if (score < 60) return FinancialSafetyLevel.tense;
  if (score < 80) return FinancialSafetyLevel.acceptable;
  return FinancialSafetyLevel.healthy;
}

String financialSafetyLevelLabel(FinancialSafetyLevel level) {
  switch (level) {
    case FinancialSafetyLevel.critical:
      return 'Risque élevé';
    case FinancialSafetyLevel.tense:
      return 'Tendue';
    case FinancialSafetyLevel.acceptable:
      return 'Acceptable';
    case FinancialSafetyLevel.healthy:
      return 'Saine';
  }
}

/// Libellé utilisé spécifiquement pour la "marge de sécurité après projet"
/// (§5) — mêmes seuils que [financialSafetyLevelForScore], vocabulaire
/// adapté à cette lecture précise.
String marginDropLevelLabel(FinancialSafetyLevel level) {
  switch (level) {
    case FinancialSafetyLevel.critical:
      return 'Critique';
    case FinancialSafetyLevel.tense:
      return 'Faible';
    case FinancialSafetyLevel.acceptable:
      return 'Acceptable';
    case FinancialSafetyLevel.healthy:
      return 'Confortable';
  }
}

String financialSafetyLevelEmoji(FinancialSafetyLevel level) {
  switch (level) {
    case FinancialSafetyLevel.critical:
      return '🔴';
    case FinancialSafetyLevel.tense:
      return '🟠';
    case FinancialSafetyLevel.acceptable:
      return '🟡';
    case FinancialSafetyLevel.healthy:
      return '🟢';
  }
}

/// Lecture BudgetPilot du taux d'endettement (§3) — repère interne, jamais
/// une décision bancaire.
enum DebtRatioBand { comfortable, watch, tense, high }

DebtRatioBand debtRatioBandFor(double ratio) {
  if (ratio <= kDebtRatioComfortable) return DebtRatioBand.comfortable;
  if (ratio <= kDebtRatioWatch) return DebtRatioBand.watch;
  if (ratio <= kDebtRatioTense) return DebtRatioBand.tense;
  return DebtRatioBand.high;
}

String debtRatioBandLabel(DebtRatioBand band) {
  switch (band) {
    case DebtRatioBand.comfortable:
      return 'Confortable';
    case DebtRatioBand.watch:
      return 'À surveiller';
    case DebtRatioBand.tense:
      return 'Tendu';
    case DebtRatioBand.high:
      return 'Risque élevé';
  }
}

String debtRatioBandEmoji(DebtRatioBand band) {
  switch (band) {
    case DebtRatioBand.comfortable:
      return '🟢';
    case DebtRatioBand.watch:
      return '🟡';
    case DebtRatioBand.tense:
      return '🟠';
    case DebtRatioBand.high:
      return '🔴';
  }
}

/// Détail des 3 critères du Financial Safety Score, chacun sur 0-100 avant
/// pondération.
class ProjectSafetyBreakdown {
  final int debtRatioScore;
  final int remainingLivingScore;
  final int marginDropScore;
  final int totalScore;

  const ProjectSafetyBreakdown({
    required this.debtRatioScore,
    required this.remainingLivingScore,
    required this.marginDropScore,
    required this.totalScore,
  });
}

/// Résultat complet de l'évaluation de sécurité financière d'un projet —
/// toujours recalculé à la volée, jamais persisté (même principe que
/// [ProjectFeasibilityResult]).
class ProjectSafetyResult {
  final int currentIncomeCents;

  /// Reste à vivre actuel (avant ce projet) — c'est l'argent libre déjà
  /// calculé par `BudgetCalculationService`/`DashboardViewBuilder`, jamais
  /// recalculé ici : les mensualités de crédit y sont déjà déduites une
  /// seule fois (charges fixes liées), pas de double comptage.
  final int remainingBeforeCents;

  /// Reste à vivre estimé une fois ce projet intégré au budget.
  final int remainingAfterCents;

  /// [remainingAfterCents] - [remainingBeforeCents] — toujours <= 0.
  final int remainingDeltaCents;

  /// Mensualités de crédits actifs / revenus — **avant** ce projet.
  final double debtRatioBefore;

  /// (Mensualités de crédits actifs + mensualité de financement du projet,
  /// si financé) / revenus — jamais les coûts supplémentaires, qui ne sont
  /// pas une dette (comptés dans le reste à vivre, pas dans l'endettement).
  final double debtRatioAfter;

  /// Mensualité + coûts supplémentaires du projet — "marge consommée par le
  /// projet" (§11).
  final int marginConsumedByProjectCents;

  final ProjectSafetyBreakdown score;
  final FinancialSafetyLevel level;

  /// Message d'alerte clair (§10) — jamais culpabilisant, jamais une
  /// promesse bancaire.
  final String alertMessage;

  const ProjectSafetyResult({
    required this.currentIncomeCents,
    required this.remainingBeforeCents,
    required this.remainingAfterCents,
    required this.remainingDeltaCents,
    required this.debtRatioBefore,
    required this.debtRatioAfter,
    required this.marginConsumedByProjectCents,
    required this.score,
    required this.level,
    required this.alertMessage,
  });

  int get totalScore => score.totalScore;
}

/// Moteur de sécurité financière (V1.1 — Safe Projects). Répond à "Est-ce
/// que ce projet reste sain pour mon budget ?" — distinct de la faisabilité
/// brute (`ProjectFeasibilityService`) : un projet peut être finançable tout
/// en étant dangereux pour le budget, et inversement. Compose
/// `ProjectFeasibilityService.computeFinancing` sans dupliquer le calcul de
/// financement.
class ProjectSafetyService {
  final ProjectFeasibilityService feasibilityService;
  const ProjectSafetyService({this.feasibilityService = const ProjectFeasibilityService()});

  ProjectSafetyResult evaluate({
    required ProjectEntity project,
    required int currentFreeCashCents,
    required int totalIncomeCents,
    required List<CreditEntity> activeCredits,
  }) {
    final financing = feasibilityService.computeFinancing(project);
    final impact = financing.totalMonthlyImpactCents;
    final remainingAfter = currentFreeCashCents - impact;
    final remainingDelta = remainingAfter - currentFreeCashCents;

    final activeCreditPayments = _creditCalculationService.totalMonthlyPayments(activeCredits);
    final debtRatioBefore = totalIncomeCents <= 0 ? 0.0 : activeCreditPayments / totalIncomeCents;
    final debtRatioAfter = totalIncomeCents <= 0
        ? 0.0
        : (activeCreditPayments + financing.estimatedMonthlyPaymentCents) / totalIncomeCents;

    final debtScore = _debtRatioScore(debtRatioAfter);
    final remainingScore = _remainingLivingScore(impact, totalIncomeCents);
    final dropScore = _marginDropScore(remainingDelta, currentFreeCashCents);

    final total = (debtScore * kSafetyWeightDebtRatio +
            remainingScore * kSafetyWeightRemainingLiving +
            dropScore * kSafetyWeightMarginDrop)
        .round()
        .clamp(0, 100);

    final breakdown = ProjectSafetyBreakdown(
      debtRatioScore: debtScore,
      remainingLivingScore: remainingScore,
      marginDropScore: dropScore,
      totalScore: total,
    );
    final level = financialSafetyLevelForScore(total);

    return ProjectSafetyResult(
      currentIncomeCents: totalIncomeCents,
      remainingBeforeCents: currentFreeCashCents,
      remainingAfterCents: remainingAfter,
      remainingDeltaCents: remainingDelta,
      debtRatioBefore: debtRatioBefore,
      debtRatioAfter: debtRatioAfter,
      marginConsumedByProjectCents: impact,
      score: breakdown,
      level: level,
      alertMessage: _alertMessageFor(level),
    );
  }

  /// Score d'endettement — 100 sous le repère "confortable", décroît par
  /// paliers linéaires jusqu'à 0 au-delà de [kDebtRatioFloorForZeroScore].
  int _debtRatioScore(double ratio) {
    if (ratio <= kDebtRatioComfortable) return 100;
    if (ratio >= kDebtRatioFloorForZeroScore) return 0;
    if (ratio <= kDebtRatioWatch) {
      return _lerp(100, 75, (ratio - kDebtRatioComfortable) / (kDebtRatioWatch - kDebtRatioComfortable));
    }
    if (ratio <= kDebtRatioTense) {
      return _lerp(75, 50, (ratio - kDebtRatioWatch) / (kDebtRatioTense - kDebtRatioWatch));
    }
    return _lerp(50, 0, (ratio - kDebtRatioTense) / (kDebtRatioFloorForZeroScore - kDebtRatioTense));
  }

  int _lerp(int from, int to, double t) => (from + (to - from) * t.clamp(0.0, 1.0)).round();

  /// Part du revenu consommée par le projet (mensualité + coûts
  /// supplémentaires) — toujours relative au revenu, jamais un montant fixe
  /// seul (§5).
  int _remainingLivingScore(int impactCents, int totalIncomeCents) {
    if (totalIncomeCents <= 0) return impactCents <= 0 ? 100 : 0;
    final share = impactCents / totalIncomeCents;
    if (share <= 0) return 100;
    if (share >= kMaxHealthyIncomeShareForProject) return 0;
    return (100 * (1 - share / kMaxHealthyIncomeShareForProject)).round().clamp(0, 100);
  }

  /// Baisse relative du reste à vivre (avant → après) — jamais un montant
  /// fixe seul (§5).
  int _marginDropScore(int remainingDeltaCents, int remainingBeforeCents) {
    if (remainingDeltaCents >= 0) return 100;
    if (remainingBeforeCents <= 0) return 0;
    final dropRatio = (-remainingDeltaCents) / remainingBeforeCents;
    if (dropRatio >= kMaxHealthyRemainingDropRatio) return 0;
    return (100 * (1 - dropRatio / kMaxHealthyRemainingDropRatio)).round().clamp(0, 100);
  }

  String _alertMessageFor(FinancialSafetyLevel level) {
    switch (level) {
      case FinancialSafetyLevel.healthy:
        return 'Ce projet resterait compatible avec une marge financière confortable.';
      case FinancialSafetyLevel.acceptable:
        return 'Ce projet resterait acceptable pour ton budget, avec une marge plus limitée.';
      case FinancialSafetyLevel.tense:
        return 'Ce projet réduirait fortement ton reste à vivre.';
      case FinancialSafetyLevel.critical:
        return 'BudgetPilot déconseille ce scénario : la pression mensuelle deviendrait trop élevée.';
    }
  }
}
