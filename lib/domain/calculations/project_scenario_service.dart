import '../entities/credit_entity.dart';
import '../entities/project_entity.dart';
import 'credit_term_calculator.dart';
import 'project_debt_impact_service.dart';
import 'project_feasibility_service.dart';

const _feasibilityService = ProjectFeasibilityService();
const _debtImpactService = ProjectDebtImpactService();
const _termCalculator = CreditTermCalculator();

/// Un crédit lointain (au-delà de cet horizon) n'est jamais proposé comme
/// "attendre sa fin" — attendre 15 ans n'est pas un scénario réaliste.
const int kWaitForCreditMaxHorizonMonths = 72;

/// Incrément d'apport proposé par [ProjectScenarioType.increaseContribution] :
/// un quart du besoin de financement restant — un pas significatif sans
/// demander la totalité d'un coup.
const double kContributionIncreaseRatio = 0.25;

/// Réduction de budget proposée par [ProjectScenarioType.reduceTarget].
const double kTargetReductionRatio = 0.15;

/// Allongement d'horizon proposé par [ProjectScenarioType.extendHorizon].
const int kHorizonExtensionMonths = 12;

enum ProjectScenarioType {
  waitForCredit,
  increaseContribution,
  payoffCredit,
  reduceTarget,
  extendHorizon,
  combined,
}

/// Un scénario réaliste parmi lesquels BudgetPilot peut recommander un
/// "chemin" vers la réalisation du projet (§8). Toujours dérivé de données
/// réelles (crédits existants, apport actuel) — jamais un événement
/// inventé.
class ProjectScenario {
  final ProjectScenarioType type;
  final String label;
  final String description;
  final int? horizonMonths;
  final int? cashRequiredCents;
  final int? monthlyPaymentFreedCents;
  final int newFinancingNeededCents;
  final int newScore;
  final int baselineScore;

  /// Taux d'endettement après projet — aujourd'hui (baseline, si le projet
  /// était réalisé tel quel), puis si ce scénario était appliqué. Indicateur
  /// concret (V1.2) : jamais un pourcentage de "sécurité" calculé.
  final double baselineDebtRatioAfter;
  final double newDebtRatioAfter;

  /// Reste à vivre après projet — aujourd'hui (baseline), puis si ce
  /// scénario était appliqué.
  final int baselineRemainingAfterCents;
  final int newRemainingAfterCents;

  const ProjectScenario({
    required this.type,
    required this.label,
    required this.description,
    this.horizonMonths,
    this.cashRequiredCents,
    this.monthlyPaymentFreedCents,
    required this.newFinancingNeededCents,
    required this.newScore,
    required this.baselineScore,
    required this.baselineDebtRatioAfter,
    required this.newDebtRatioAfter,
    required this.baselineRemainingAfterCents,
    required this.newRemainingAfterCents,
  });

  int get scoreDelta => newScore - baselineScore;

  /// Négatif = amélioration (l'endettement après projet baisse).
  double get debtRatioDelta => newDebtRatioAfter - baselineDebtRatioAfter;

  /// Positif = amélioration (le reste à vivre après projet augmente).
  int get remainingDelta => newRemainingAfterCents - baselineRemainingAfterCents;
}

/// Une étape connue de la trajectoire financière du projet (§7) — construite
/// uniquement à partir d'événements réels (fin de crédit, objectif d'apport
/// atteignable via une capacité d'épargne connue), jamais inventée.
class RoadmapStep {
  final String label;
  final int monthsFromNow;
  final int score;

  const RoadmapStep({required this.label, required this.monthsFromNow, required this.score});
}

/// Moteur de scénarios et de trajectoire (V1.0 — Project Planner, §7-§10 ;
/// enrichi V1.1/V1.2 : chaque scénario recalcule aussi le taux d'endettement
/// et le reste à vivre concrets, et le chemin recommandé privilégie un
/// endettement raisonnable, jamais uniquement le meilleur score de
/// faisabilité brut). Pur et déterministe : compose [ProjectFeasibilityService]
/// et [ProjectDebtImpactService] sans dupliquer leurs calculs.
class ProjectScenarioService {
  final ProjectFeasibilityService feasibilityService;
  final ProjectDebtImpactService debtImpactService;
  const ProjectScenarioService({
    this.feasibilityService = _feasibilityService,
    this.debtImpactService = _debtImpactService,
  });

  /// Génère les scénarios réalistes applicables à ce projet. Un scénario
  /// n'est proposé que s'il repose sur des données réelles (crédit actif
  /// existant, apport actuellement possédé) — jamais sur une hypothèse
  /// fabriquée.
  List<ProjectScenario> generate({
    required ProjectEntity project,
    required int currentFreeCashCents,
    required int totalIncomeCents,
    required List<CreditEntity> activeCredits,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final baseline = feasibilityService
        .evaluate(
            project: project, currentFreeCashCents: currentFreeCashCents, activeCredits: activeCredits, now: today)
        .totalScore;
    final baselineDebtImpact = debtImpactService.evaluate(
      project: project,
      currentFreeCashCents: currentFreeCashCents,
      totalIncomeCents: totalIncomeCents,
      activeCredits: activeCredits,
    );

    final scenarios = <ProjectScenario>[];

    final waitScenario = _waitForCreditScenario(
      project: project,
      currentFreeCashCents: currentFreeCashCents,
      totalIncomeCents: totalIncomeCents,
      activeCredits: activeCredits,
      baseline: baseline,
      baselineDebtImpact: baselineDebtImpact,
      today: today,
    );
    if (waitScenario != null) scenarios.add(waitScenario);

    final contributionScenario = _increaseContributionScenario(
      project: project,
      currentFreeCashCents: currentFreeCashCents,
      totalIncomeCents: totalIncomeCents,
      activeCredits: activeCredits,
      baseline: baseline,
      baselineDebtImpact: baselineDebtImpact,
      today: today,
    );
    if (contributionScenario != null) scenarios.add(contributionScenario);

    final payoffScenario = _payoffCreditScenario(
      project: project,
      currentFreeCashCents: currentFreeCashCents,
      totalIncomeCents: totalIncomeCents,
      activeCredits: activeCredits,
      baseline: baseline,
      baselineDebtImpact: baselineDebtImpact,
      today: today,
    );
    if (payoffScenario != null) scenarios.add(payoffScenario);

    final reduceScenario = _reduceTargetScenario(
      project: project,
      currentFreeCashCents: currentFreeCashCents,
      totalIncomeCents: totalIncomeCents,
      activeCredits: activeCredits,
      baseline: baseline,
      baselineDebtImpact: baselineDebtImpact,
      today: today,
    );
    if (reduceScenario != null) scenarios.add(reduceScenario);

    final extendScenario = _extendHorizonScenario(
      project: project,
      currentFreeCashCents: currentFreeCashCents,
      totalIncomeCents: totalIncomeCents,
      activeCredits: activeCredits,
      baseline: baseline,
      baselineDebtImpact: baselineDebtImpact,
      today: today,
    );
    if (extendScenario != null) scenarios.add(extendScenario);

    final combinedScenario = _combinedScenario(
      project: project,
      currentFreeCashCents: currentFreeCashCents,
      totalIncomeCents: totalIncomeCents,
      activeCredits: activeCredits,
      baseline: baseline,
      baselineDebtImpact: baselineDebtImpact,
      today: today,
      waitScenario: waitScenario,
      contributionScenario: contributionScenario,
    );
    if (combinedScenario != null) scenarios.add(combinedScenario);

    return scenarios;
  }

  /// Le "chemin recommandé" (§9) : le meilleur compromis entre gain de
  /// score et effort (argent mobilisé ou délai) — jamais simplement le
  /// score de faisabilité le plus élevé, et jamais un scénario dont
  /// l'endettement resterait à risque élevé si une alternative raisonnable
  /// existe (V1.1/V1.2, §9) même s'il maximise la faisabilité brute. Un
  /// scénario "réduire le projet" n'est proposé en tête que si aucune autre
  /// option ne rapproche significativement le projet de la faisabilité.
  ProjectScenario? recommend(List<ProjectScenario> scenarios) {
    if (scenarios.isEmpty) return null;

    final gentle = scenarios.where((s) => s.type != ProjectScenarioType.reduceTarget).toList();
    final meaningful = gentle.where((s) => s.scoreDelta >= 5).toList();
    final candidates = meaningful.isNotEmpty ? meaningful : (gentle.isNotEmpty ? gentle : scenarios);

    final safeEnough = candidates.where(_isReasonableDebtLoad).toList();
    final pool = safeEnough.isNotEmpty ? safeEnough : candidates;

    pool.sort((a, b) => _efficiency(b).compareTo(_efficiency(a)));
    return pool.first;
  }

  /// Un scénario n'est jamais recommandé s'il laisse l'endettement en zone
  /// "risque élevé" ou le reste à vivre négatif, même s'il obtient le
  /// meilleur score de faisabilité brut — "la sécurité financière passe
  /// avant la simple faisabilité". Si AUCUN scénario ne l'atteint,
  /// BudgetPilot recommande quand même le meilleur compromis disponible
  /// plutôt que de n'en proposer aucun (voir [recommend]).
  bool _isReasonableDebtLoad(ProjectScenario scenario) =>
      debtRatioBandFor(scenario.newDebtRatioAfter) != DebtRatioBand.high && scenario.newRemainingAfterCents > 0;

  /// Efficacité = gain de score par unité d'effort. L'effort est mesuré en
  /// "coût" comparable : les mois d'attente pour un scénario sans argent
  /// mobilisé, ou des tranches de 500 € pour un scénario qui mobilise du
  /// cash — les deux ne sont jamais directement comparables en valeur
  /// absolue, seulement via ce ratio normalisé et documenté.
  double _efficiency(ProjectScenario scenario) {
    final delta = scenario.scoreDelta.toDouble();
    if (delta <= 0) return delta; // jamais recommandé si ça n'améliore rien
    final cash = scenario.cashRequiredCents ?? 0;
    final months = scenario.horizonMonths ?? 0;
    final effort = 1 + (cash / 50000) + months; // 500 € ~ 1 mois d'attente
    return delta / effort;
  }

  /// Trajectoire chronologique (§7) — un point "aujourd'hui", puis un point
  /// par crédit actif se terminant dans un horizon raisonnable, puis un
  /// point "objectif d'apport atteint" si une capacité d'épargne mensuelle
  /// fiable est fournie. Ne fabrique jamais d'événement.
  List<RoadmapStep> buildRoadmap({
    required ProjectEntity project,
    required int currentFreeCashCents,
    required List<CreditEntity> activeCredits,
    int? monthlySavingsCapacityCents,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final steps = <RoadmapStep>[
      RoadmapStep(
        label: "Aujourd'hui",
        monthsFromNow: 0,
        score: feasibilityService
            .evaluate(
                project: project, currentFreeCashCents: currentFreeCashCents, activeCredits: activeCredits, now: today)
            .totalScore,
      ),
    ];

    final endingCredits = activeCredits.where((c) => c.remainingInstallments > 0).toList()
      ..sort((a, b) => a.remainingInstallments.compareTo(b.remainingInstallments));

    var freedSoFarCents = 0;
    final remaining = [...activeCredits];
    for (final credit in endingCredits) {
      remaining.removeWhere((c) => c.id == credit.id);
      freedSoFarCents += credit.monthlyPaymentCents;
      steps.add(RoadmapStep(
        label: 'Crédit ${credit.name} terminé (+${_euros(credit.monthlyPaymentCents)} €/mois)',
        monthsFromNow: credit.remainingInstallments,
        score: feasibilityService
            .evaluate(
              project: project,
              currentFreeCashCents: currentFreeCashCents + freedSoFarCents,
              activeCredits: remaining,
              now: today,
            )
            .totalScore,
      ));
    }

    final targetContribution = project.desiredContributionCents;
    if (targetContribution != null &&
        targetContribution > project.availableContributionCents &&
        monthlySavingsCapacityCents != null &&
        monthlySavingsCapacityCents > 0) {
      final missing = targetContribution - project.availableContributionCents;
      final monthsToTarget = (missing / monthlySavingsCapacityCents).ceil();
      final projectedProject = _withContribution(project, targetContribution);
      steps.add(RoadmapStep(
        label: 'Apport cible atteint (+${_euros(missing)} €)',
        monthsFromNow: monthsToTarget,
        score: feasibilityService
            .evaluate(
              project: projectedProject,
              currentFreeCashCents: currentFreeCashCents,
              activeCredits: activeCredits.where((c) => c.remainingInstallments > monthsToTarget).toList(),
              now: today,
            )
            .totalScore,
      ));
    }

    steps.sort((a, b) => a.monthsFromNow.compareTo(b.monthsFromNow));
    return steps;
  }

  // -- Scénarios individuels ----------------------------------------------

  ProjectScenario? _waitForCreditScenario({
    required ProjectEntity project,
    required int currentFreeCashCents,
    required int totalIncomeCents,
    required List<CreditEntity> activeCredits,
    required int baseline,
    required ProjectDebtImpactResult baselineDebtImpact,
    required DateTime today,
  }) {
    final candidates = activeCredits
        .where((c) => c.remainingInstallments > 0 && c.remainingInstallments <= kWaitForCreditMaxHorizonMonths)
        .toList()
      ..sort((a, b) => a.remainingInstallments.compareTo(b.remainingInstallments));
    if (candidates.isEmpty) return null;

    final credit = candidates.first;
    final remainingCredits = activeCredits.where((c) => c.id != credit.id).toList();
    final newFreeCash = currentFreeCashCents + credit.monthlyPaymentCents;
    final result = feasibilityService.evaluate(
      project: project,
      currentFreeCashCents: newFreeCash,
      activeCredits: remainingCredits,
      now: today,
    );
    final debtImpact = debtImpactService.evaluate(
      project: project,
      currentFreeCashCents: newFreeCash,
      totalIncomeCents: totalIncomeCents,
      activeCredits: remainingCredits,
    );

    return ProjectScenario(
      type: ProjectScenarioType.waitForCredit,
      label: 'Attendre la fin du crédit ${credit.name}',
      description:
          'Dans ${credit.remainingInstallments} mois, "${credit.name}" se termine et libère ${_euros(credit.monthlyPaymentCents)} €/mois.',
      horizonMonths: credit.remainingInstallments,
      monthlyPaymentFreedCents: credit.monthlyPaymentCents,
      newFinancingNeededCents: result.financing.financingNeededCents,
      newScore: result.totalScore,
      baselineScore: baseline,
      baselineDebtRatioAfter: baselineDebtImpact.debtRatioAfter,
      newDebtRatioAfter: debtImpact.debtRatioAfter,
      baselineRemainingAfterCents: baselineDebtImpact.remainingAfterCents,
      newRemainingAfterCents: debtImpact.remainingAfterCents,
    );
  }

  ProjectScenario? _increaseContributionScenario({
    required ProjectEntity project,
    required int currentFreeCashCents,
    required int totalIncomeCents,
    required List<CreditEntity> activeCredits,
    required int baseline,
    required ProjectDebtImpactResult baselineDebtImpact,
    required DateTime today,
  }) {
    final financingNeeded = feasibilityService.computeFinancing(project).financingNeededCents;
    if (financingNeeded <= 0) return null;

    final increase = (financingNeeded * kContributionIncreaseRatio).round();
    if (increase <= 0) return null;

    final updated = _withAvailableContribution(project, project.availableContributionCents + increase);
    final result = feasibilityService.evaluate(
      project: updated,
      currentFreeCashCents: currentFreeCashCents,
      activeCredits: activeCredits,
      now: today,
    );
    final debtImpact = debtImpactService.evaluate(
      project: updated,
      currentFreeCashCents: currentFreeCashCents,
      totalIncomeCents: totalIncomeCents,
      activeCredits: activeCredits,
    );

    return ProjectScenario(
      type: ProjectScenarioType.increaseContribution,
      label: "Ajouter ${_euros(increase)} € d'apport",
      description: 'Réduit le besoin de financement de ${_euros(increase)} €.',
      cashRequiredCents: increase,
      newFinancingNeededCents: result.financing.financingNeededCents,
      newScore: result.totalScore,
      baselineScore: baseline,
      baselineDebtRatioAfter: baselineDebtImpact.debtRatioAfter,
      newDebtRatioAfter: debtImpact.debtRatioAfter,
      baselineRemainingAfterCents: baselineDebtImpact.remainingAfterCents,
      newRemainingAfterCents: debtImpact.remainingAfterCents,
    );
  }

  ProjectScenario? _payoffCreditScenario({
    required ProjectEntity project,
    required int currentFreeCashCents,
    required int totalIncomeCents,
    required List<CreditEntity> activeCredits,
    required int baseline,
    required ProjectDebtImpactResult baselineDebtImpact,
    required DateTime today,
  }) {
    final payable = activeCredits
        .where((c) => c.remainingCapitalCents > 0 && c.remainingCapitalCents <= project.availableContributionCents)
        .toList()
      ..sort((a, b) => a.remainingCapitalCents.compareTo(b.remainingCapitalCents));
    if (payable.isEmpty) return null;

    final credit = payable.first;
    // L'argent utilisé pour solder ce crédit provient du même apport
    // disponible : il ne peut pas aussi servir d'apport au projet — c'est
    // précisément la comparaison demandée par le §10.
    final updatedProject = _withAvailableContribution(
      project,
      project.availableContributionCents - credit.remainingCapitalCents,
    );
    final remainingCredits = activeCredits.where((c) => c.id != credit.id).toList();
    final newFreeCash = currentFreeCashCents + credit.monthlyPaymentCents;
    final result = feasibilityService.evaluate(
      project: updatedProject,
      currentFreeCashCents: newFreeCash,
      activeCredits: remainingCredits,
      now: today,
    );
    final debtImpact = debtImpactService.evaluate(
      project: updatedProject,
      currentFreeCashCents: newFreeCash,
      totalIncomeCents: totalIncomeCents,
      activeCredits: remainingCredits,
    );

    return ProjectScenario(
      type: ProjectScenarioType.payoffCredit,
      label: 'Solder le crédit ${credit.name}',
      description:
          'Utiliser ${_euros(credit.remainingCapitalCents)} € pour terminer "${credit.name}" libérerait ${_euros(credit.monthlyPaymentCents)} €/mois immédiatement.',
      cashRequiredCents: credit.remainingCapitalCents,
      monthlyPaymentFreedCents: credit.monthlyPaymentCents,
      newFinancingNeededCents: result.financing.financingNeededCents,
      newScore: result.totalScore,
      baselineScore: baseline,
      baselineDebtRatioAfter: baselineDebtImpact.debtRatioAfter,
      newDebtRatioAfter: debtImpact.debtRatioAfter,
      baselineRemainingAfterCents: baselineDebtImpact.remainingAfterCents,
      newRemainingAfterCents: debtImpact.remainingAfterCents,
    );
  }

  ProjectScenario? _reduceTargetScenario({
    required ProjectEntity project,
    required int currentFreeCashCents,
    required int totalIncomeCents,
    required List<CreditEntity> activeCredits,
    required int baseline,
    required ProjectDebtImpactResult baselineDebtImpact,
    required DateTime today,
  }) {
    if (project.targetAmountCents <= 0) return null;
    final reduction = (project.targetAmountCents * kTargetReductionRatio).round();
    if (reduction <= 0) return null;

    final updated = _withTargetAmount(project, project.targetAmountCents - reduction);
    final result = feasibilityService.evaluate(
      project: updated,
      currentFreeCashCents: currentFreeCashCents,
      activeCredits: activeCredits,
      now: today,
    );
    final debtImpact = debtImpactService.evaluate(
      project: updated,
      currentFreeCashCents: currentFreeCashCents,
      totalIncomeCents: totalIncomeCents,
      activeCredits: activeCredits,
    );

    return ProjectScenario(
      type: ProjectScenarioType.reduceTarget,
      label: 'Réduire le budget du projet de ${_euros(reduction)} €',
      description: 'Vise un budget de ${_euros(project.targetAmountCents - reduction)} € au lieu de '
          '${_euros(project.targetAmountCents)} €.',
      cashRequiredCents: 0,
      newFinancingNeededCents: result.financing.financingNeededCents,
      newScore: result.totalScore,
      baselineScore: baseline,
      baselineDebtRatioAfter: baselineDebtImpact.debtRatioAfter,
      newDebtRatioAfter: debtImpact.debtRatioAfter,
      baselineRemainingAfterCents: baselineDebtImpact.remainingAfterCents,
      newRemainingAfterCents: debtImpact.remainingAfterCents,
    );
  }

  ProjectScenario? _extendHorizonScenario({
    required ProjectEntity project,
    required int currentFreeCashCents,
    required int totalIncomeCents,
    required List<CreditEntity> activeCredits,
    required int baseline,
    required ProjectDebtImpactResult baselineDebtImpact,
    required DateTime today,
  }) {
    final desiredDate = project.desiredDate;
    if (desiredDate == null) return null;

    final newDate = _termCalculator.addMonths(desiredDate, kHorizonExtensionMonths);
    final updated = _withDesiredDate(project, newDate);
    final result = feasibilityService.evaluate(
      project: updated,
      currentFreeCashCents: currentFreeCashCents,
      activeCredits: activeCredits,
      now: today,
    );
    final debtImpact = debtImpactService.evaluate(
      project: updated,
      currentFreeCashCents: currentFreeCashCents,
      totalIncomeCents: totalIncomeCents,
      activeCredits: activeCredits,
    );

    return ProjectScenario(
      type: ProjectScenarioType.extendHorizon,
      label: "Repousser l'échéance de $kHorizonExtensionMonths mois",
      description: 'Laisse plus de temps à la situation pour évoluer avant la date souhaitée.',
      horizonMonths: kHorizonExtensionMonths,
      newFinancingNeededCents: result.financing.financingNeededCents,
      newScore: result.totalScore,
      baselineScore: baseline,
      baselineDebtRatioAfter: baselineDebtImpact.debtRatioAfter,
      newDebtRatioAfter: debtImpact.debtRatioAfter,
      baselineRemainingAfterCents: baselineDebtImpact.remainingAfterCents,
      newRemainingAfterCents: debtImpact.remainingAfterCents,
    );
  }

  ProjectScenario? _combinedScenario({
    required ProjectEntity project,
    required int currentFreeCashCents,
    required int totalIncomeCents,
    required List<CreditEntity> activeCredits,
    required int baseline,
    required ProjectDebtImpactResult baselineDebtImpact,
    required DateTime today,
    required ProjectScenario? waitScenario,
    required ProjectScenario? contributionScenario,
  }) {
    if (waitScenario == null || contributionScenario == null) return null;

    final creditName = waitScenario.label.replaceFirst('Attendre la fin du crédit ', '');
    final remainingCredits = activeCredits.where((c) => c.name != creditName).toList();
    final increase = contributionScenario.cashRequiredCents ?? 0;
    final updated = _withAvailableContribution(project, project.availableContributionCents + increase);
    final freed = waitScenario.monthlyPaymentFreedCents ?? 0;
    final newFreeCash = currentFreeCashCents + freed;

    final result = feasibilityService.evaluate(
      project: updated,
      currentFreeCashCents: newFreeCash,
      activeCredits: remainingCredits,
      now: today,
    );
    final debtImpact = debtImpactService.evaluate(
      project: updated,
      currentFreeCashCents: newFreeCash,
      totalIncomeCents: totalIncomeCents,
      activeCredits: remainingCredits,
    );

    return ProjectScenario(
      type: ProjectScenarioType.combined,
      label: 'Attendre ${waitScenario.horizonMonths} mois + ${_euros(increase)} € d\'apport',
      description: 'Combine les deux leviers précédents.',
      horizonMonths: waitScenario.horizonMonths,
      cashRequiredCents: increase,
      monthlyPaymentFreedCents: freed,
      newFinancingNeededCents: result.financing.financingNeededCents,
      newScore: result.totalScore,
      baselineScore: baseline,
      baselineDebtRatioAfter: baselineDebtImpact.debtRatioAfter,
      newDebtRatioAfter: debtImpact.debtRatioAfter,
      baselineRemainingAfterCents: baselineDebtImpact.remainingAfterCents,
      newRemainingAfterCents: debtImpact.remainingAfterCents,
    );
  }

  // -- Copies immuables (ProjectEntity est un value object sans copyWith) --

  ProjectEntity _withAvailableContribution(ProjectEntity project, int newContributionCents) => ProjectEntity(
        id: project.id,
        name: project.name,
        category: project.category,
        targetAmountCents: project.targetAmountCents,
        desiredDate: project.desiredDate,
        availableContributionCents: newContributionCents.clamp(0, 1 << 62),
        desiredContributionCents: project.desiredContributionCents,
        financingMode: project.financingMode,
        maxMonthlyPaymentCents: project.maxMonthlyPaymentCents,
        desiredDurationMonths: project.desiredDurationMonths,
        estimatedRatePercent: project.estimatedRatePercent,
        extraMonthlyCostCents: project.extraMonthlyCostCents,
        notes: project.notes,
        isActive: project.isActive,
        priority: project.priority,
        createdAt: project.createdAt,
        updatedAt: project.updatedAt,
      );

  ProjectEntity _withContribution(ProjectEntity project, int newContributionCents) =>
      _withAvailableContribution(project, newContributionCents);

  ProjectEntity _withTargetAmount(ProjectEntity project, int newTargetAmountCents) => ProjectEntity(
        id: project.id,
        name: project.name,
        category: project.category,
        targetAmountCents: newTargetAmountCents,
        desiredDate: project.desiredDate,
        availableContributionCents: project.availableContributionCents,
        desiredContributionCents: project.desiredContributionCents,
        financingMode: project.financingMode,
        maxMonthlyPaymentCents: project.maxMonthlyPaymentCents,
        desiredDurationMonths: project.desiredDurationMonths,
        estimatedRatePercent: project.estimatedRatePercent,
        extraMonthlyCostCents: project.extraMonthlyCostCents,
        notes: project.notes,
        isActive: project.isActive,
        priority: project.priority,
        createdAt: project.createdAt,
        updatedAt: project.updatedAt,
      );

  ProjectEntity _withDesiredDate(ProjectEntity project, DateTime newDesiredDate) => ProjectEntity(
        id: project.id,
        name: project.name,
        category: project.category,
        targetAmountCents: project.targetAmountCents,
        desiredDate: newDesiredDate,
        availableContributionCents: project.availableContributionCents,
        desiredContributionCents: project.desiredContributionCents,
        financingMode: project.financingMode,
        maxMonthlyPaymentCents: project.maxMonthlyPaymentCents,
        desiredDurationMonths: project.desiredDurationMonths,
        estimatedRatePercent: project.estimatedRatePercent,
        extraMonthlyCostCents: project.extraMonthlyCostCents,
        notes: project.notes,
        isActive: project.isActive,
        priority: project.priority,
        createdAt: project.createdAt,
        updatedAt: project.updatedAt,
      );

  String _euros(int cents) => (cents / 100).round().toString();
}
