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
        IncomeEntity(id: 2, cycleId: 1, name: 'Prime', expectedAmountCents: 5000, expectedDate: DateTime(2026, 8, 20)),
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

  test('compte les saisies actives par catégorie, en excluant les inactives', () {
    final result = builder.build(
      cycleId: 1,
      cycleStart: cycleStart,
      cycleEnd: cycleEnd,
      incomes: [
        IncomeEntity(id: 1, cycleId: 1, name: 'Salaire', expectedAmountCents: 245000, expectedDate: cycleStart),
        IncomeEntity(
            id: 2, cycleId: 1, name: 'Prime', expectedAmountCents: 5000, expectedDate: cycleStart, isActive: false),
      ],
      fixedExpenses: [
        FixedExpenseEntity(id: 1, cycleId: 1, name: 'EDF', expectedAmountCents: 18000, expectedDate: cycleStart),
        FixedExpenseEntity(id: 2, cycleId: 1, name: 'Internet', expectedAmountCents: 4000, expectedDate: cycleStart),
      ],
      variableExpenses: [
        VariableExpenseEntity(id: 1, cycleId: 1, amountCents: 1500, date: cycleStart),
      ],
      savings: [
        SavingEntity(id: 1, cycleId: 1, name: 'Mariage', expectedAmountCents: 80000, expectedDate: cycleStart),
      ],
    );

    expect(result.incomesCount, 1);
    expect(result.fixedExpensesCount, 2);
    expect(result.variableExpensesCount, 1);
    expect(result.savingsCount, 1);
  });

  test('identifie les opérations planifiées dans les 7 prochains jours ("cette semaine")', () {
    final today = DateTime(2026, 8, 5);
    final result = builder.build(
      cycleId: 1,
      cycleStart: cycleStart,
      cycleEnd: cycleEnd,
      now: today,
      incomes: [
        IncomeEntity(id: 1, cycleId: 1, name: 'Prime', expectedAmountCents: 5000, expectedDate: DateTime(2026, 8, 8)),
        IncomeEntity(
            id: 2, cycleId: 1, name: 'Trop tard', expectedAmountCents: 5000, expectedDate: DateTime(2026, 8, 20)),
      ],
      fixedExpenses: [
        FixedExpenseEntity(
            id: 1, cycleId: 1, name: 'Box internet', expectedAmountCents: 4000, expectedDate: DateTime(2026, 8, 9)),
        // Aujourd'hui même : déjà couvert par todayFixedExpenses, pas par "cette semaine".
        FixedExpenseEntity(id: 2, cycleId: 1, name: 'Aujourdhui', expectedAmountCents: 1000, expectedDate: today),
      ],
      variableExpenses: const [],
      savings: [
        SavingEntity(id: 1, cycleId: 1, name: 'Livret', expectedAmountCents: 10000, expectedDate: DateTime(2026, 8, 6)),
      ],
    );

    expect(result.thisWeekIncomes.map((i) => i.name), ['Prime']);
    expect(result.thisWeekFixedExpenses.map((e) => e.name), ['Box internet']);
    expect(result.thisWeekSavings.map((s) => s.name), ['Livret']);
  });

  test('le solde bancaire déclaré est intégré à realRemainingCents (formule centrale)', () {
    final result = builder.build(
      cycleId: 1,
      cycleStart: cycleStart,
      cycleEnd: cycleEnd,
      incomes: [
        IncomeEntity(id: 1, cycleId: 1, name: 'Jeremy', expectedAmountCents: 424300, expectedDate: cycleStart),
      ],
      fixedExpenses: const [],
      variableExpenses: const [],
      savings: const [],
      declaredBankBalanceCents: -58600,
    );

    // Cas de référence : -58600 + 424300 = 365700.
    expect(result.realRemainingCents, 365700);
    // Le solde déclaré reste par ailleurs exposé tel quel pour l'affichage.
    expect(result.declaredBankBalanceCents, -58600);
  });

  test('sans solde déclaré, realRemainingCents ne change pas de comportement (0 par défaut)', () {
    final result = builder.build(
      cycleId: 1,
      cycleStart: cycleStart,
      cycleEnd: cycleEnd,
      incomes: [
        IncomeEntity(id: 1, cycleId: 1, name: 'Jeremy', expectedAmountCents: 424300, expectedDate: cycleStart),
      ],
      fixedExpenses: const [],
      variableExpenses: const [],
      savings: const [],
    );

    expect(result.realRemainingCents, 424300);
    expect(result.declaredBankBalanceCents, isNull);
  });

  test('Project Planner : realRemainingCents (source de currentFreeCashCents) reflète le solde de départ', () {
    // projects_page.dart lit `dashboard.realRemainingCents` directement comme
    // `currentFreeCashCents` pour le Project Planner — aucune formule séparée
    // n'existe côté simulateur/scénarios/faisabilité : ce test documente que
    // la valeur qu'ils consomment est déjà corrigée par la formule centrale.
    final result = builder.build(
      cycleId: 1,
      cycleStart: cycleStart,
      cycleEnd: cycleEnd,
      incomes: [
        IncomeEntity(id: 1, cycleId: 1, name: 'Jeremy', expectedAmountCents: 400000, expectedDate: cycleStart),
      ],
      fixedExpenses: const [],
      variableExpenses: const [],
      savings: const [],
      declaredBankBalanceCents: 50000,
    );

    final currentFreeCashCents = result.realRemainingCents;
    expect(currentFreeCashCents, 450000);
  });
}
