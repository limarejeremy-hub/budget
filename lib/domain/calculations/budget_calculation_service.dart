import '../../core/constants/app_constants.dart';
import '../entities/fixed_expense_entity.dart';
import '../entities/income_entity.dart';
import '../entities/saving_entity.dart';
import '../entities/variable_expense_entity.dart';

/// Service de calcul budgétaire — classe pure.
/// Ne dépend ni de Drift ni d'AppDatabase : elle reçoit des listes d'entités
/// du domaine et ne fait que calculer. Tous les montants sont en centimes
/// (int) pour éviter toute dérive liée aux arrondis flottants.
class BudgetCalculationService {
  const BudgetCalculationService();

  int calculateTotalExpectedIncome(List<IncomeEntity> incomes) {
    return incomes
        .where((i) => i.isActive && i.status != IncomeStatus.annule)
        .fold(0, (sum, i) => sum + i.effectiveAmountCents);
  }

  int calculateTotalFixedExpenses(List<FixedExpenseEntity> expenses) {
    return expenses
        .where((e) => e.isActive && e.status != ChargeStatus.suspendue)
        .fold(0, (sum, e) => sum + e.effectiveAmountCents);
  }

  int calculateTotalVariableExpenses(List<VariableExpenseEntity> expenses) {
    return expenses.fold(0, (sum, e) => sum + e.amountCents);
  }

  /// Exclut les épargnes annulées ou suspendues.
  int calculateTotalSavings(List<SavingEntity> savings) {
    return savings
        .where((s) =>
            s.isActive && s.status != SavingStatus.annule && s.status != SavingStatus.suspendue)
        .fold(0, (sum, s) => sum + s.effectiveAmountCents);
  }

  /// reste réel = revenus - charges fixes - dépenses variables - épargne
  int calculateRealRemaining({
    required List<IncomeEntity> incomes,
    required List<FixedExpenseEntity> fixedExpenses,
    required List<VariableExpenseEntity> variableExpenses,
    required List<SavingEntity> savings,
  }) {
    return calculateTotalExpectedIncome(incomes) -
        calculateTotalFixedExpenses(fixedExpenses) -
        calculateTotalVariableExpenses(variableExpenses) -
        calculateTotalSavings(savings);
  }

  /// Total des charges dont le prélèvement n'est pas encore confirmé
  /// (sert uniquement au suivi bancaire, cf. règle : le statut ne change
  /// jamais la déduction du reste réel, sauf pour une charge suspendue).
  int calculateRemainingUnconfirmedCharges(List<FixedExpenseEntity> fixedExpenses) {
    return fixedExpenses
        .where((e) =>
            e.isActive && e.status != ChargeStatus.prelevee && e.status != ChargeStatus.suspendue)
        .fold(0, (sum, e) => sum + e.effectiveAmountCents);
  }

  /// Progression du cycle entre 0.0 et 1.0.
  double calculateCycleProgress({
    required DateTime startDate,
    required DateTime endDate,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final total = endDate.difference(startDate).inMinutes;
    if (total <= 0) return 1.0;
    final elapsed = current.difference(startDate).inMinutes;
    return elapsed.clamp(0, total) / total;
  }

  /// Ratio reste réel / revenus, pour la couleur d'état (vert/orange/rouge).
  double remainingRatio({required int realRemainingCents, required int totalIncomeCents}) {
    if (totalIncomeCents <= 0) return 0;
    return realRemainingCents / totalIncomeCents;
  }

  // calculateDeclaredBalanceDifference() est volontairement absente ici.
  // La formule simplifiée du cahier des charges ne tient pas compte d'un
  // solde initial, de revenus non reçus ni d'opérations bancaires en
  // attente : elle sera conçue avec la logique de clôture de cycle (Phase 5).
  // Les champs nécessaires (declaredBankBalanceCents, finalRealRemainingCents)
  // restent en base dans BudgetCycles.
}
