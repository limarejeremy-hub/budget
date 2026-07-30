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
}
