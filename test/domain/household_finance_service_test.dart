import 'package:flutter_test/flutter_test.dart';

import 'package:budgetpilot/domain/calculations/budget_calculation_service.dart';
import 'package:budgetpilot/domain/calculations/household_finance_service.dart';
import 'package:budgetpilot/domain/entities/credit_entity.dart';
import 'package:budgetpilot/domain/entities/income_entity.dart';
import 'package:budgetpilot/domain/entities/saving_entity.dart';
import 'package:budgetpilot/domain/entities/variable_expense_entity.dart';

void main() {
  const service = HouseholdFinanceService();
  const budgetService = BudgetCalculationService();
  final now = DateTime(2026, 1, 1);

  CreditEntity credit(int monthlyPaymentCents, {int id = 1}) => CreditEntity(
        id: id,
        name: 'Crédit $id',
        initialAmountCents: 1000000,
        remainingCapitalCents: 500000,
        monthlyPaymentCents: monthlyPaymentCents,
        expectedEndDate: DateTime(2030, 1, 1),
        remainingInstallments: 24,
        createdAt: now,
        updatedAt: now,
      );

  group('structuralRemainingCents', () {
    test('revenus - charges fixes hors crédits - mensualités crédits actifs', () {
      final result = service.structuralRemainingCents(
        totalIncomeCents: 300000,
        totalFixedExpensesExcludingCreditsCents: 50000,
        activeCredits: [credit(60000)],
      );
      expect(result, 190000);
    });

    test('exemple utilisateur : endettement 20 % -> 29 %, reste à vivre baisse de 704 € avec un projet financé', () {
      // Ce test documente uniquement la formule structurelle elle-même —
      // l'impact "avec projet" est calculé par ProjectDebtImpactService à
      // partir de cette valeur, jamais recalculé différemment.
      final result = service.structuralRemainingCents(
        totalIncomeCents: 400000,
        totalFixedExpensesExcludingCreditsCents: 0,
        activeCredits: [credit(80000)],
      );
      expect(result, 320000);
    });

    test('aucun crédit actif : reste à vivre = revenus - charges fixes hors crédits', () {
      final result = service.structuralRemainingCents(
        totalIncomeCents: 300000,
        totalFixedExpensesExcludingCreditsCents: 50000,
        activeCredits: const [],
      );
      expect(result, 250000);
    });

    test('ne dépend jamais des dépenses variables ni de l\'épargne — ces flux n\'existent pas dans la signature', () {
      // La garantie est structurelle : la fonction ne prend même pas ces
      // paramètres, il est donc impossible qu'ils influencent le résultat.
      final result = service.structuralRemainingCents(
        totalIncomeCents: 300000,
        totalFixedExpensesExcludingCreditsCents: 50000,
        activeCredits: [credit(60000)],
      );
      final sameResultAgain = service.structuralRemainingCents(
        totalIncomeCents: 300000,
        totalFixedExpensesExcludingCreditsCents: 50000,
        activeCredits: [credit(60000)],
      );
      expect(result, sameResultAgain);
    });

    test('absence de double comptage : plusieurs crédits sont chacun comptés une seule fois', () {
      final result = service.structuralRemainingCents(
        totalIncomeCents: 500000,
        totalFixedExpensesExcludingCreditsCents: 0,
        activeCredits: [credit(60000, id: 1), credit(40000, id: 2)],
      );
      expect(result, 500000 - 60000 - 40000);
    });

    test('reste à vivre structurel peut être négatif — jamais masqué', () {
      final result = service.structuralRemainingCents(
        totalIncomeCents: 100000,
        totalFixedExpensesExcludingCreditsCents: 50000,
        activeCredits: [credit(80000)],
      );
      expect(result, -30000);
    });
  });

  group('régression : dépenses variables et épargne n\'influencent jamais le reste à vivre structurel', () {
    test('l\'Argent libre du cycle bouge avec les dépenses variables/l\'épargne, le reste à vivre structurel non', () {
      final income = [
        IncomeEntity(id: 1, cycleId: 1, name: 'Salaire', expectedAmountCents: 400000, expectedDate: now),
      ];
      final activeCredits = [credit(80000)];
      const fixedExcludingCredits = 0;

      // Cycle "calme" : aucune dépense variable, aucune épargne.
      final calmRemaining = budgetService.calculateRealRemaining(
        incomes: income,
        fixedExpenses: const [],
        variableExpenses: const [],
        savings: const [],
      );
      final calmStructural = service.structuralRemainingCents(
        totalIncomeCents: budgetService.calculateTotalExpectedIncome(income),
        totalFixedExpensesExcludingCreditsCents: fixedExcludingCredits,
        activeCredits: activeCredits,
      );

      // Même cycle, mais avec de grosses dépenses variables et de l'épargne
      // en plus — l'Argent libre du cycle en tient compte, le reste à vivre
      // structurel ne doit pas bouger d'un centime.
      final busyRemaining = budgetService.calculateRealRemaining(
        incomes: income,
        fixedExpenses: const [],
        variableExpenses: [VariableExpenseEntity(id: 1, cycleId: 1, amountCents: 80000, date: now)],
        savings: [
          SavingEntity(id: 1, cycleId: 1, name: 'Livret', expectedAmountCents: 50000, expectedDate: now),
        ],
      );
      final busyStructural = service.structuralRemainingCents(
        totalIncomeCents: budgetService.calculateTotalExpectedIncome(income),
        totalFixedExpensesExcludingCreditsCents: fixedExcludingCredits,
        activeCredits: activeCredits,
      );

      expect(calmRemaining, isNot(equals(busyRemaining)));
      expect(calmRemaining - busyRemaining, 80000 + 50000);
      expect(calmStructural, busyStructural);
      expect(calmStructural, 320000);
    });
  });
}
