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

  FixedExpenseEntity charge(int cents, {String status = ChargeStatus.aVenir, int? actualCents}) => FixedExpenseEntity(
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

  // Solde bancaire de départ intégré à l'argent libre : formule centrale
  // argentLibre = soldeBancaireDebutCycle + revenus - charges - dépenses - épargne.
  group('calculateRealRemaining avec solde de départ (startingBalanceCents)', () {
    test('cas de référence obligatoire : -58600 + 424300 = 365700', () {
      final result = service.calculateRealRemaining(
        incomes: [income(424300)],
        fixedExpenses: [],
        variableExpenses: [],
        savings: [],
        startingBalanceCents: -58600,
      );
      expect(result, 365700);
    });

    test('solde de départ négatif réduit naturellement l\'argent libre', () {
      final result = service.calculateRealRemaining(
        incomes: [income(424300)],
        fixedExpenses: [],
        variableExpenses: [],
        savings: [],
        startingBalanceCents: -58600,
      );
      expect(result, lessThan(424300));
    });

    test('solde de départ positif augmente naturellement l\'argent libre : 500 + 4000 = 4500 €', () {
      final result = service.calculateRealRemaining(
        incomes: [income(400000)],
        fixedExpenses: [],
        variableExpenses: [],
        savings: [],
        startingBalanceCents: 50000,
      );
      expect(result, 450000);
    });

    test('solde de départ nul (ou non déclaré) : comportement identique à avant, valeur par défaut 0', () {
      final avecZeroExplicite = service.calculateRealRemaining(
        incomes: [income(500000)],
        fixedExpenses: [charge(200000)],
        variableExpenses: [variable(50000)],
        savings: [saving(80000)],
        startingBalanceCents: 0,
      );
      final sansParametre = service.calculateRealRemaining(
        incomes: [income(500000)],
        fixedExpenses: [charge(200000)],
        variableExpenses: [variable(50000)],
        savings: [saving(80000)],
      );
      expect(avecZeroExplicite, sansParametre);
      expect(sansParametre, 170000);
    });

    test('revenus combinés à un solde de départ négatif', () {
      final result = service.calculateRealRemaining(
        incomes: [income(300000), income(100000)],
        fixedExpenses: [],
        variableExpenses: [],
        savings: [],
        startingBalanceCents: -50000,
      );
      expect(result, 350000);
    });

    test('charges fixes combinées à un solde de départ négatif', () {
      final result = service.calculateRealRemaining(
        incomes: [income(500000)],
        fixedExpenses: [charge(100000)],
        variableExpenses: [],
        savings: [],
        startingBalanceCents: -20000,
      );
      expect(result, 380000);
    });

    test('dépenses variables combinées à un solde de départ négatif', () {
      final result = service.calculateRealRemaining(
        incomes: [income(500000)],
        fixedExpenses: [],
        variableExpenses: [variable(30000)],
        savings: [],
        startingBalanceCents: -20000,
      );
      expect(result, 450000);
    });

    test('épargne combinée à un solde de départ négatif', () {
      final result = service.calculateRealRemaining(
        incomes: [income(500000)],
        fixedExpenses: [],
        variableExpenses: [],
        savings: [saving(40000)],
        startingBalanceCents: -20000,
      );
      expect(result, 440000);
    });

    test('cycle complet : -586 + 4243 - 2000 - 300 - 500 = 857 €', () {
      final result = service.calculateRealRemaining(
        incomes: [income(424300)],
        fixedExpenses: [charge(200000)],
        variableExpenses: [variable(30000)],
        savings: [saving(50000)],
        startingBalanceCents: -58600,
      );
      expect(result, 85700);
    });

    test('exemple confirmé de l\'utilisateur : revenus 4243 €, solde départ -586 €, aucune autre sortie = 3657 €', () {
      final result = service.calculateRealRemaining(
        incomes: [income(424300)],
        fixedExpenses: [],
        variableExpenses: [],
        savings: [],
        startingBalanceCents: -58600,
      );
      expect(result, 365700);
    });

    test(
        'absence de double comptage : le solde de départ n\'intervient qu\'une seule fois, quel que soit le nombre de flux',
        () {
      final soldeSeul = service.calculateRealRemaining(
        incomes: [],
        fixedExpenses: [],
        variableExpenses: [],
        savings: [],
        startingBalanceCents: -58600,
      );
      expect(soldeSeul, -58600);

      // Ajouter plusieurs revenus, charges, dépenses et épargnes ne doit
      // jamais réintroduire le solde de départ une deuxième fois : la
      // différence entre deux appels ne dépend que des flux ajoutés, jamais
      // du solde (identique dans les deux appels).
      final avecFlux = service.calculateRealRemaining(
        incomes: [income(100000), income(50000)],
        fixedExpenses: [charge(30000), charge(20000)],
        variableExpenses: [variable(10000)],
        savings: [saving(15000)],
        startingBalanceCents: -58600,
      );
      const fluxNets = 100000 + 50000 - 30000 - 20000 - 10000 - 15000;
      expect(avecFlux - soldeSeul, fluxNets);
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
