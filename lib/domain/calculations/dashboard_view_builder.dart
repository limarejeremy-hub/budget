import '../../core/constants/app_constants.dart';
import '../entities/fixed_expense_entity.dart';
import '../entities/income_entity.dart';
import '../entities/saving_entity.dart';
import '../entities/variable_expense_entity.dart';
import '../models/dashboard_view_data.dart';
import 'budget_calculation_service.dart';

/// Construit la vue du tableau de bord à partir des entités du domaine.
/// Classe pure : ne dépend d'aucune source de données (Drift ou autre).
class DashboardViewBuilder {
  final BudgetCalculationService _calculationService;

  const DashboardViewBuilder({
    BudgetCalculationService calculationService = const BudgetCalculationService(),
  }) : _calculationService = calculationService;

  DashboardViewData build({
    required int cycleId,
    required DateTime cycleStart,
    required DateTime cycleEnd,
    required List<IncomeEntity> incomes,
    required List<FixedExpenseEntity> fixedExpenses,
    required List<VariableExpenseEntity> variableExpenses,
    required List<SavingEntity> savings,
    int? declaredBankBalanceCents,
  }) {
    final totalIncome = _calculationService.calculateTotalExpectedIncome(incomes);
    final totalFixed = _calculationService.calculateTotalFixedExpenses(fixedExpenses);
    final totalVariable = _calculationService.calculateTotalVariableExpenses(variableExpenses);
    final totalSavings = _calculationService.calculateTotalSavings(savings);

    final realRemaining = _calculationService.calculateRealRemaining(
      incomes: incomes,
      fixedExpenses: fixedExpenses,
      variableExpenses: variableExpenses,
      savings: savings,
    );

    final ratio = _calculationService.remainingRatio(
      realRemainingCents: realRemaining,
      totalIncomeCents: totalIncome,
    );

    // Une charge est "à surveiller" tant qu'elle n'est ni confirmée ni
    // suspendue — son statut ne change jamais son inclusion dans le reste réel.
    final unconfirmed = fixedExpenses
        .where(
            (e) => e.isActive && e.status != ChargeStatus.prelevee && e.status != ChargeStatus.suspendue)
        .toList()
      ..sort((a, b) => a.expectedDate.compareTo(b.expectedDate));

    return DashboardViewData(
      cycleId: cycleId,
      cycleStart: cycleStart,
      cycleEnd: cycleEnd,
      totalIncomeCents: totalIncome,
      totalFixedExpensesCents: totalFixed,
      totalVariableExpensesCents: totalVariable,
      totalSavingsCents: totalSavings,
      realRemainingCents: realRemaining,
      remainingRatio: ratio,
      unconfirmedChargesCount: unconfirmed.length,
      unconfirmedChargesTotalCents:
          _calculationService.calculateRemainingUnconfirmedCharges(fixedExpenses),
      nextChargeToCheck: unconfirmed.isEmpty ? null : unconfirmed.first,
      upcomingCharges: unconfirmed.take(3).toList(),
      declaredBankBalanceCents: declaredBankBalanceCents,
    );
  }
}
