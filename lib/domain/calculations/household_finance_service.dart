import '../entities/credit_entity.dart';
import 'credit_calculation_service.dart';

const _creditCalculationService = CreditCalculationService();

/// Source de vérité centrale du RESTE À VIVRE STRUCTUREL — la capacité
/// financière récurrente du foyer, jamais ce qui a déjà été dépensé ce
/// mois-ci. Utilisée par Credit Manager, Project Planner et toutes les
/// simulations : jamais recalculée différemment ailleurs (V1.2, correctif
/// "reste à vivre").
///
/// Distincte de l'ARGENT LIBRE DU CYCLE (`BudgetCalculationService.
/// calculateRealRemaining`), qui lui intègre le solde bancaire de départ,
/// les dépenses variables et l'épargne du cycle — deux indicateurs
/// différents, jamais confondus :
/// - Argent libre du cycle = combien reste-t-il concrètement sur le compte
///   en banque d'ici la fin du cycle ?
/// - Reste à vivre structurel = quelle est la capacité financière récurrente
///   du foyer, indépendamment de ce qui a déjà été dépensé ce mois-ci ?
class HouseholdFinanceService {
  const HouseholdFinanceService();

  /// RESTE À VIVRE STRUCTUREL =
  ///   revenus mensuels
  ///   - charges fixes hors crédits
  ///   - mensualités des crédits actifs.
  ///
  /// Ne soustrait JAMAIS les dépenses variables ni l'épargne du cycle : ce
  /// sont des flux financés ensuite PAR ce reste à vivre, pas une charge
  /// récurrente structurelle du foyer.
  ///
  /// [totalFixedExpensesExcludingCreditsCents] doit déjà exclure les
  /// charges fixes liées à un crédit (`DashboardViewData.
  /// totalFixedExpensesExcludingCreditsCents`) : sinon une mensualité de
  /// crédit serait comptée deux fois — une fois via sa charge fixe liée,
  /// une fois via [activeCredits]. Les mensualités des crédits actifs sont
  /// calculées via `CreditCalculationService.totalMonthlyPayments` — LA
  /// seule formule utilisée dans toute l'application, jamais dupliquée ici.
  int structuralRemainingCents({
    required int totalIncomeCents,
    required int totalFixedExpensesExcludingCreditsCents,
    required List<CreditEntity> activeCredits,
  }) {
    final creditPayments = _creditCalculationService.totalMonthlyPayments(activeCredits);
    return totalIncomeCents - totalFixedExpensesExcludingCreditsCents - creditPayments;
  }
}
