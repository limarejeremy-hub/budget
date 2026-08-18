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

  test('totalFixedExpensesExcludingCreditsCents exclut les charges liées à un crédit (V1.2, reste à vivre structurel)',
      () {
    final result = builder.build(
      cycleId: 1,
      cycleStart: cycleStart,
      cycleEnd: cycleEnd,
      incomes: const [],
      fixedExpenses: [
        FixedExpenseEntity(id: 1, cycleId: 1, name: 'Loyer', expectedAmountCents: 90000, expectedDate: cycleStart),
        FixedExpenseEntity(
          id: 2,
          cycleId: 1,
          name: 'Mensualité voiture',
          expectedAmountCents: 25000,
          expectedDate: cycleStart,
          linkedCreditId: 7,
        ),
      ],
      variableExpenses: const [],
      savings: const [],
    );

    // totalFixedExpensesCents (argent libre) inclut toujours tout.
    expect(result.totalFixedExpensesCents, 90000 + 25000);
    // totalFixedExpensesExcludingCreditsCents (reste à vivre structurel)
    // exclut la charge liée au crédit — sa mensualité est comptée via
    // CreditCalculationService.totalMonthlyPayments côté HouseholdFinanceService,
    // jamais deux fois.
    expect(result.totalFixedExpensesExcludingCreditsCents, 90000);
  });

  test(
      'realRemainingCents (Argent libre du cycle) reste intégré au solde de départ — mais n\'est PLUS la source du '
      'Project Planner (V1.2)', () {
    // Depuis le correctif V1.2, projects_page.dart / project_detail_page.dart
    // / project_priority_card.dart / credits_page.dart ne lisent plus
    // `dashboard.realRemainingCents` pour le Project Planner ou le Credit
    // Manager : ils calculent `HouseholdFinanceService.
    // structuralRemainingCents` à partir de `totalIncomeCents` et
    // `totalFixedExpensesExcludingCreditsCents` (voir
    // household_finance_service_test.dart). realRemainingCents continue
    // d'intégrer le solde de départ, mais uniquement pour l'Argent libre du
    // cycle affiché au tableau de bord / détail du cycle.
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

    expect(result.realRemainingCents, 450000);
  });

  group('"Affectation manuelle d\'une charge au prochain cycle" : deferredToNextCycle', () {
    test('une charge reportée est exclue du total des charges, de l\'argent libre et du "à confirmer"', () {
      final result = builder.build(
        cycleId: 1,
        cycleStart: cycleStart,
        cycleEnd: cycleEnd,
        incomes: [
          IncomeEntity(id: 1, cycleId: 1, name: 'Jeremy', expectedAmountCents: 168000, expectedDate: cycleStart),
        ],
        fixedExpenses: [
          FixedExpenseEntity(
            id: 1,
            cycleId: 1,
            name: 'EDF',
            expectedAmountCents: 18000,
            expectedDate: DateTime(2026, 8, 30),
            deferredToNextCycle: true,
          ),
        ],
        variableExpenses: const [],
        savings: const [],
      );

      expect(result.totalFixedExpensesCents, 0);
      expect(result.realRemainingCents, 168000);
      expect(result.unconfirmedChargesCount, 0);
      expect(result.unconfirmedChargesTotalCents, 0);
    });

    test(
        'une charge reportée reste dans Aujourd\'hui / Cette semaine / prochaines échéances — '
        'purement chronologique, jamais affecté par le report', () {
      final today = DateTime(2026, 8, 5);
      final result = builder.build(
        cycleId: 1,
        cycleStart: cycleStart,
        cycleEnd: cycleEnd,
        incomes: const [],
        fixedExpenses: [
          FixedExpenseEntity(
            id: 1,
            cycleId: 1,
            name: 'EDF',
            expectedAmountCents: 18000,
            expectedDate: today,
            deferredToNextCycle: true,
          ),
          FixedExpenseEntity(
            id: 2,
            cycleId: 1,
            name: 'Assurance',
            expectedAmountCents: 5000,
            expectedDate: today.add(const Duration(days: 2)),
            deferredToNextCycle: true,
          ),
        ],
        variableExpenses: const [],
        savings: const [],
        now: today,
      );

      expect(result.todayFixedExpenses.map((e) => e.id), contains(1));
      expect(result.upcomingCharges.map((e) => e.id), containsAll([1, 2]));
      expect(result.thisWeekFixedExpenses.map((e) => e.id), contains(2));
    });

    test('totalFixedExpensesExcludingCreditsCents (reste à vivre structurel) n\'est jamais affecté par un report', () {
      final result = builder.build(
        cycleId: 1,
        cycleStart: cycleStart,
        cycleEnd: cycleEnd,
        incomes: const [],
        fixedExpenses: [
          FixedExpenseEntity(
            id: 1,
            cycleId: 1,
            name: 'EDF',
            expectedAmountCents: 18000,
            expectedDate: cycleStart,
            deferredToNextCycle: true,
          ),
        ],
        variableExpenses: const [],
        savings: const [],
      );

      expect(result.totalFixedExpensesExcludingCreditsCents, 18000,
          reason: 'le report est une affectation cash-flow ponctuelle, pas une disparition de la charge récurrente');
    });
  });
}
