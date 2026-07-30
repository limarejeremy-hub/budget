import 'package:flutter_test/flutter_test.dart';

import 'package:budgetpilot/core/constants/app_constants.dart';
import 'package:budgetpilot/domain/calculations/budget_calculation_service.dart';
import 'package:budgetpilot/domain/entities/fixed_expense_entity.dart';
import 'package:budgetpilot/domain/entities/income_entity.dart';
import 'package:budgetpilot/domain/entities/saving_entity.dart';
import 'package:budgetpilot/domain/entities/variable_expense_entity.dart';

void main() {
  const service = BudgetCalculationService();
  final today = DateTime(2026, 8, 1);

  IncomeEntity income(int cents, {String status = IncomeStatus.prevu}) => IncomeEntity(
        id: 1,
        cycleId: 1,
        name: 'Revenu test',
        expectedAmountCents: cents,
        expectedDate: today,
        status: status,
      );

  FixedExpenseEntity charge(int cents, {String status = ChargeStatus.aVenir, int? actualCents}) =>
      FixedExpenseEntity(
        id: 1,
        cycleId: 1,
        name: 'Charge test',
        expectedAmountCents: cents,
        actualAmountCents: actualCents,
        expectedDate: today,
        status: status,
      );

  VariableExpenseEntity variable(int cents) => VariableExpenseEntity(
        id: 1,
        cycleId: 1,
        amountCents: cents,
        date: today,
      );

  SavingEntity saving(int cents, {String status = SavingStatus.prevu}) => SavingEntity(
        id: 1,
        cycleId: 1,
        name: 'Épargne test',
        expectedAmountCents: cents,
        expectedDate: today,
        status: status,
      );

  group('calculateRealRemaining', () {
    test('calcul simple : 5000 - 2000 - 500 - 800 = 1700 €', () {
      final result = service.calculateRealRemaining(
        incomes: [income(500000)],
        fixedExpenses: [charge(200000)],
        variableExpenses: [variable(50000)],
        savings: [saving(80000)],
      );
      expect(result, 170000);
    });

    test("modification d'une dépense variable : le reste réel diminue du delta", () {
      final avant = service.calculateRealRemaining(
        incomes: [income(500000)],
        fixedExpenses: [charge(200000)],
        variableExpenses: [variable(10000)],
        savings: [],
      );
      final apres = service.calculateRealRemaining(
        incomes: [income(500000)],
        fixedExpenses: [charge(200000)],
        variableExpenses: [variable(15000)],
        savings: [],
      );
      expect(avant - apres, 5000);
    });

    test('montant réel inférieur au montant prévu : le reste réel augmente du delta', () {
      final avecPrevu = service.calculateRealRemaining(
        incomes: [income(500000)],
        fixedExpenses: [charge(20000)],
        variableExpenses: [],
        savings: [],
      );
      final avecReel = service.calculateRealRemaining(
        incomes: [income(500000)],
        fixedExpenses: [charge(20000, actualCents: 18000)],
        variableExpenses: [],
        savings: [],
      );
      expect(avecReel - avecPrevu, 2000);
    });

    test("une charge suspendue n'est pas déduite du reste réel", () {
      final sansCharge = service.calculateRealRemaining(
        incomes: [income(500000)],
        fixedExpenses: [],
        variableExpenses: [],
        savings: [],
      );
      final avecChargeSuspendue = service.calculateRealRemaining(
        incomes: [income(500000)],
        fixedExpenses: [charge(10000, status: ChargeStatus.suspendue)],
        variableExpenses: [],
        savings: [],
      );
      expect(avecChargeSuspendue, sansCharge);
    });
  });

  group('calculateTotalSavings', () {
    test('exclut les épargnes suspendues', () {
      final total = service.calculateTotalSavings([
        saving(80000),
        saving(20000, status: SavingStatus.suspendue),
      ]);
      expect(total, 80000);
    });

    test('exclut les épargnes annulées', () {
      final total = service.calculateTotalSavings([
        saving(80000),
        saving(30000, status: SavingStatus.annule),
      ]);
      expect(total, 80000);
    });
  });

  group('calculateTotalExpectedIncome', () {
    test('exclut les revenus annulés', () {
      final total = service.calculateTotalExpectedIncome([
        income(500000),
        income(100000, status: IncomeStatus.annule),
      ]);
      expect(total, 500000);
    });
  });
}
