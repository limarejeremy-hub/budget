import 'package:flutter_test/flutter_test.dart';

import 'package:budgetpilot/core/constants/app_constants.dart';
import 'package:budgetpilot/domain/calculations/dashboard_view_builder.dart';
import 'package:budgetpilot/domain/entities/fixed_expense_entity.dart';
import 'package:budgetpilot/domain/entities/income_entity.dart';
import 'package:budgetpilot/domain/entities/saving_entity.dart';
import 'package:budgetpilot/domain/entities/variable_expense_entity.dart';

void main() {
  const builder = DashboardViewBuilder();
  final cycleStart = DateTime(2026, 7, 27);
  final cycleEnd = DateTime(2026, 8, 26);

  test('calcule le reste réel et identifie la prochaine charge à vérifier', () {
    final result = builder.build(
      cycleId: 1,
      cycleStart: cycleStart,
      cycleEnd: cycleEnd,
      incomes: [
        IncomeEntity(id: 1, cycleId: 1, name: 'Jeremy', expectedAmountCents: 245000, expectedDate: cycleStart),
      ],
      fixedExpenses: [
        FixedExpenseEntity(
          id: 1,
          cycleId: 1,
          name: 'EDF',
          expectedAmountCents: 18000,
          expectedDate: DateTime(2026, 8, 10),
          status: ChargeStatus.aVenir,
        ),
        FixedExpenseEntity(
          id: 2,
          cycleId: 1,
          name: 'Internet',
          expectedAmountCents: 12000,
          expectedDate: DateTime(2026, 8, 5),
          status: ChargeStatus.prelevee,
        ),
      ],
      variableExpenses: [
        VariableExpenseEntity(id: 1, cycleId: 1, amountCents: 4200, date: cycleStart),
      ],
      savings: [
        SavingEntity(id: 1, cycleId: 1, name: 'Mariage', expectedAmountCents: 80000, expectedDate: cycleStart),
      ],
    );

    expect(result.realRemainingCents, 245000 - 18000 - 12000 - 4200 - 80000);
    expect(result.unconfirmedChargesCount, 1);
    expect(result.nextChargeToCheck?.name, 'EDF');
  });

  test('identifie les charges et revenus du jour, et les alertes', () {
    final today = DateTime(2026, 8, 5);
    final result = builder.build(
      cycleId: 1,
      cycleStart: cycleStart,
      cycleEnd: cycleEnd,
      now: today,
      incomes: [
        IncomeEntity(id: 1, cycleId: 1, name: 'Salaire', expectedAmountCents: 245000, expectedDate: today),
        IncomeEntity(
            id: 2, cycleId: 1, name: 'Prime', expectedAmountCents: 5000, expectedDate: DateTime(2026, 8, 20)),
      ],
      fixedExpenses: [
        FixedExpenseEntity(
          id: 1,
          cycleId: 1,
          name: 'Internet',
          expectedAmountCents: 12000,
          expectedDate: today,
          status: ChargeStatus.aVenir,
        ),
        FixedExpenseEntity(
          id: 2,
          cycleId: 1,
          name: 'Assurance',
          expectedAmountCents: 8000,
          expectedDate: DateTime(2026, 7, 20),
          status: ChargeStatus.aConfirmer,
        ),
        FixedExpenseEntity(
          id: 3,
          cycleId: 1,
          name: 'Loyer',
          expectedAmountCents: 70000,
          expectedDate: DateTime(2026, 7, 27),
          status: ChargeStatus.incident,
        ),
      ],
      variableExpenses: const [],
      savings: const [],
    );

    expect(result.todayFixedExpenses.map((e) => e.name), ['Internet']);
    expect(result.todayIncomes.map((i) => i.name), ['Salaire']);
    expect(result.alerts.map((e) => e.name), containsAll(['Assurance', 'Loyer']));
  });

  test('daysRemaining et cycleProgress reflètent la position dans le cycle', () {
    final result = builder.build(
      cycleId: 1,
      cycleStart: cycleStart,
      cycleEnd: cycleEnd,
      incomes: const [],
      fixedExpenses: const [],
      variableExpenses: const [],
      savings: const [],
    );

    // Cycle du 27/07 au 26/08 (30 jours) ; "aujourd'hui" = 6/08 → 20 jours restants.
    final midCycle = DateTime(2026, 8, 6);
    expect(result.daysRemaining(now: midCycle), 20);
    expect(result.cycleProgress(now: midCycle), closeTo(10 / 30, 0.001));

    expect(result.daysRemaining(now: DateTime(2026, 8, 26)), 0);
    expect(result.daysRemaining(now: DateTime(2026, 9, 1)), 0);
  });
}
