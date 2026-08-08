import '../entities/credit_entity.dart';
import '../entities/project_entity.dart';
import 'credit_calculation_service.dart';
import 'project_feasibility_service.dart';

export 'debt_ratio_bands.dart';

const _creditCalculationService = CreditCalculationService();

/// Baisse relative du reste à vivre (avant → après le projet) au-delà de
/// laquelle BudgetPilot considère que ce projet réduit fortement la marge
/// mensuelle — repère interne documenté, jamais un montant fixe seul (utilisé
/// pour les bloqueurs et la conclusion, jamais un pourcentage de "sécurité").
const double kMaxHealthyRemainingDropRatio = 0.50;

/// Résultat concret de l'impact d'un projet sur le budget (V1.2 — analyse
/// financière simplifiée) : taux d'endettement et reste à vivre, avant/après
/// — jamais un pourcentage de "sécurité" calculé. Toujours recalculé à la
/// volée à partir des données courantes, jamais persisté.
class ProjectDebtImpactResult {
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
  /// projet".
  final int marginConsumedByProjectCents;

  const ProjectDebtImpactResult({
    required this.currentIncomeCents,
    required this.remainingBeforeCents,
    required this.remainingAfterCents,
    required this.remainingDeltaCents,
    required this.debtRatioBefore,
    required this.debtRatioAfter,
    required this.marginConsumedByProjectCents,
  });
}

/// Moteur d'impact budgétaire d'un projet (V1.2 — analyse simplifiée).
/// Répond à "quel serait le taux d'endettement et le reste à vivre avec ce
/// projet ?" avec des chiffres concrets — jamais un score ou un pourcentage
/// de "sécurité" agrégé. Compose `ProjectFeasibilityService.computeFinancing`
/// et `CreditCalculationService.debtRatio` sans dupliquer leurs calculs : LA
/// seule formule de taux d'endettement de l'application.
class ProjectDebtImpactService {
  final ProjectFeasibilityService feasibilityService;
  const ProjectDebtImpactService({this.feasibilityService = const ProjectFeasibilityService()});

  ProjectDebtImpactResult evaluate({
    required ProjectEntity project,
    required int currentFreeCashCents,
    required int totalIncomeCents,
    required List<CreditEntity> activeCredits,
  }) {
    final financing = feasibilityService.computeFinancing(project);
    final impact = financing.totalMonthlyImpactCents;
    final remainingAfter = currentFreeCashCents - impact;
    final remainingDelta = remainingAfter - currentFreeCashCents;

    final debtRatioBefore =
        _creditCalculationService.debtRatio(activeCredits: activeCredits, totalIncomeCents: totalIncomeCents);
    final debtRatioAfter = _creditCalculationService.debtRatio(
      activeCredits: activeCredits,
      totalIncomeCents: totalIncomeCents,
      extraMonthlyPaymentCents: financing.estimatedMonthlyPaymentCents,
    );

    return ProjectDebtImpactResult(
      currentIncomeCents: totalIncomeCents,
      remainingBeforeCents: currentFreeCashCents,
      remainingAfterCents: remainingAfter,
      remainingDeltaCents: remainingDelta,
      debtRatioBefore: debtRatioBefore,
      debtRatioAfter: debtRatioAfter,
      marginConsumedByProjectCents: impact,
    );
  }
}
