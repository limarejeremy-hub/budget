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
    DateTime? now,
  }) {
    // "Affectation manuelle d'une charge au prochain cycle" : une charge
    // reportée cesse de peser sur le CASH-FLOW de ce cycle (total des
    // charges, argent libre, "à confirmer") mais reste pleinement
    // présente ailleurs — `fixedExpenses` (non filtrée) continue d'irriguer
    // Aujourd'hui/Cette semaine/prochaines échéances/alertes/reste à vivre
    // structurel, tous purement chronologiques ou structurels, jamais
    // affectés par un report ponctuel (§3, §8).
    final cashFlowFixedExpenses = fixedExpenses.where((e) => !e.deferredToNextCycle).toList();

    final totalIncome = _calculationService.calculateTotalExpectedIncome(incomes);
    final totalFixed = _calculationService.calculateTotalFixedExpenses(cashFlowFixedExpenses);
    // Reste à vivre structurel (HouseholdFinanceService) : exclut les
    // charges déjà comptées via la mensualité de leur crédit lié — reste
    // volontairement basé sur `fixedExpenses` (non filtrée par report) : un
    // report ponctuel n'efface jamais une charge récurrente de la situation
    // structurelle du foyer (§8).
    final totalFixedExcludingCredits =
        _calculationService.calculateTotalFixedExpenses(fixedExpenses.where((e) => !e.isLinkedToCredit).toList());
    final totalVariable = _calculationService.calculateTotalVariableExpenses(variableExpenses);
    final totalSavings = _calculationService.calculateTotalSavings(savings);

    final realRemaining = _calculationService.calculateRealRemaining(
      incomes: incomes,
      fixedExpenses: cashFlowFixedExpenses,
      variableExpenses: variableExpenses,
      savings: savings,
      startingBalanceCents: declaredBankBalanceCents ?? 0,
    );

    final ratio = _calculationService.remainingRatio(
      realRemainingCents: realRemaining,
      totalIncomeCents: totalIncome,
    );

    // Une charge est "à surveiller" tant qu'elle n'est ni confirmée ni
    // suspendue — son statut ne change jamais son inclusion dans le reste
    // réel. Volontairement NON filtrée par report : "prochaines échéances"
    // (upcomingCharges/nextChargeToCheck) reste purement chronologique,
    // basé sur la vraie date de prélèvement (§3).
    final unconfirmed = fixedExpenses
        .where((e) => e.isActive && e.status != ChargeStatus.prelevee && e.status != ChargeStatus.suspendue)
        .toList()
      ..sort((a, b) => a.expectedDate.compareTo(b.expectedDate));
    // "À confirmer" est en revanche un indicateur de cash-flow du cycle
    // courant : une charge reportée n'y figure plus (§2).
    final unconfirmedCashFlow = unconfirmed.where((e) => !e.deferredToNextCycle).toList();

    final today = now ?? DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    bool isToday(DateTime d) => DateTime(d.year, d.month, d.day) == todayOnly;

    final todayFixed = fixedExpenses.where((e) => e.isActive && isToday(e.expectedDate)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final todayIncomes = incomes.where((i) => i.isActive && isToday(i.expectedDate)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final alerts = fixedExpenses
        .where((e) => e.isActive && (e.status == ChargeStatus.incident || e.status == ChargeStatus.aConfirmer))
        .toList()
      ..sort((a, b) => a.expectedDate.compareTo(b.expectedDate));

    final weekEnd = todayOnly.add(const Duration(days: 7));
    bool isThisWeek(DateTime d) {
      final day = DateTime(d.year, d.month, d.day);
      return day.isAfter(todayOnly) && !day.isAfter(weekEnd);
    }

    final thisWeekFixed = fixedExpenses.where((e) => e.isActive && isThisWeek(e.expectedDate)).toList()
      ..sort((a, b) => a.expectedDate.compareTo(b.expectedDate));
    final thisWeekIncomes = incomes.where((i) => i.isActive && isThisWeek(i.expectedDate)).toList()
      ..sort((a, b) => a.expectedDate.compareTo(b.expectedDate));
    final thisWeekSavings = savings.where((s) => s.isActive && isThisWeek(s.expectedDate)).toList()
      ..sort((a, b) => a.expectedDate.compareTo(b.expectedDate));

    return DashboardViewData(
      cycleId: cycleId,
      cycleStart: cycleStart,
      cycleEnd: cycleEnd,
      totalIncomeCents: totalIncome,
      totalFixedExpensesCents: totalFixed,
      totalFixedExpensesExcludingCreditsCents: totalFixedExcludingCredits,
      totalVariableExpensesCents: totalVariable,
      totalSavingsCents: totalSavings,
      realRemainingCents: realRemaining,
      remainingRatio: ratio,
      unconfirmedChargesCount: unconfirmedCashFlow.length,
      unconfirmedChargesTotalCents: _calculationService.calculateRemainingUnconfirmedCharges(cashFlowFixedExpenses),
      nextChargeToCheck: unconfirmed.isEmpty ? null : unconfirmed.first,
      upcomingCharges: unconfirmed.take(3).toList(),
      declaredBankBalanceCents: declaredBankBalanceCents,
      todayFixedExpenses: todayFixed,
      todayIncomes: todayIncomes,
      alerts: alerts,
      incomesCount: incomes.where((i) => i.isActive).length,
      fixedExpensesCount: fixedExpenses.where((e) => e.isActive).length,
      variableExpensesCount: variableExpenses.length,
      savingsCount: savings.where((s) => s.isActive).length,
      thisWeekFixedExpenses: thisWeekFixed,
      thisWeekIncomes: thisWeekIncomes,
      thisWeekSavings: thisWeekSavings,
    );
  }
}
