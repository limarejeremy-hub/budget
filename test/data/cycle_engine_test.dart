import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:budgetpilot/core/constants/app_constants.dart';
import 'package:budgetpilot/data/local/cycle_repository.dart';
import 'package:budgetpilot/data/local/database.dart';

/// Finalisation du moteur de cycle : clôture d'un cycle, création du
/// suivant (revenus/charges/épargnes récurrents recopiés, dépenses
/// variables toujours remises à zéro, crédits/projets jamais dupliqués),
/// protection contre les doublons de cycle ouvert, et sécurité
/// transactionnelle.
void main() {
  late AppDatabase db;
  late CycleRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = CycleRepository(db);
  });

  tearDown(() => db.close());

  group('closeCycle', () {
    test('clôture le cycle : statut fermé, date de clôture, argent libre final figé', () async {
      final cycleId = await repository.createCycle(
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 31),
        declaredBankBalanceCents: -58600,
      );
      await repository.createIncome(
        cycleId: cycleId,
        name: 'Salaire',
        expectedAmountCents: 424300,
        expectedDate: DateTime(2026, 1, 1),
      );

      await repository.closeCycle(cycleId);

      final closed = await (db.select(db.budgetCycles)..where((c) => c.id.equals(cycleId))).getSingle();
      expect(closed.status, CycleStatus.ferme);
      expect(closed.closedAt, isNotNull);
      // Cas de référence : -58600 + 424300 = 365700.
      expect(closed.finalRealRemainingCents, 365700);
    });

    test('archive l\'ancien cycle : n\'est plus le cycle courant, apparaît dans watchAllCycles', () async {
      final cycleId = await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
      await repository.closeCycle(cycleId);

      expect(await repository.loadCurrentCycleData(), isNull);
      final all = await repository.watchAllCycles().first;
      expect(all, hasLength(1));
      expect(all.single.id, cycleId);
      expect(all.single.status, CycleStatus.ferme);
    });

    test('lève une exception si le cycle n\'existe pas ou est déjà clôturé (jamais clôturé deux fois)', () async {
      final cycleId = await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
      await repository.closeCycle(cycleId);

      expect(() => repository.closeCycle(cycleId), throwsA(isA<CycleNotOpenException>()));
      expect(() => repository.closeCycle(999999), throwsA(isA<CycleNotOpenException>()));
    });

    test('erreur transactionnelle : une clôture en échec ne modifie rien', () async {
      final cycleId = await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
      await repository.closeCycle(cycleId);
      final snapshotBefore = await (db.select(db.budgetCycles)..where((c) => c.id.equals(cycleId))).getSingle();

      await expectLater(repository.closeCycle(cycleId), throwsA(isA<CycleNotOpenException>()));

      final snapshotAfter = await (db.select(db.budgetCycles)..where((c) => c.id.equals(cycleId))).getSingle();
      expect(snapshotAfter.closedAt, snapshotBefore.closedAt);
      expect(snapshotAfter.finalRealRemainingCents, snapshotBefore.finalRealRemainingCents);
    });

    test('ne modifie jamais les revenus, charges, dépenses ou épargnes du cycle clôturé', () async {
      final cycleId = await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
      await repository.createIncome(
        cycleId: cycleId,
        name: 'Salaire',
        expectedAmountCents: 300000,
        expectedDate: DateTime(2026, 1, 1),
      );
      await repository.createFixedExpense(
        cycleId: cycleId,
        name: 'Loyer',
        expectedAmountCents: 90000,
        expectedDate: DateTime(2026, 1, 5),
      );
      await repository.createVariableExpense(cycleId: cycleId, amountCents: 4200, date: DateTime(2026, 1, 10));
      await repository.createSaving(
        cycleId: cycleId,
        name: 'Livret',
        expectedAmountCents: 20000,
        expectedDate: DateTime(2026, 1, 1),
      );

      final before = await repository.loadCurrentCycleData();
      await repository.closeCycle(cycleId);

      final incomes = await (db.select(db.incomes)..where((i) => i.cycleId.equals(cycleId))).get();
      final fixedExpenses = await (db.select(db.fixedExpenses)..where((e) => e.cycleId.equals(cycleId))).get();
      final variableExpenses = await (db.select(db.variableExpenses)..where((e) => e.cycleId.equals(cycleId))).get();
      final savings = await (db.select(db.savings)..where((s) => s.cycleId.equals(cycleId))).get();

      expect(incomes.single.name, before!.incomes.single.name);
      expect(incomes.single.expectedAmountCents, before.incomes.single.expectedAmountCents);
      expect(fixedExpenses.single.name, before.fixedExpenses.single.name);
      expect(variableExpenses.single.amountCents, before.variableExpenses.single.amountCents);
      expect(savings.single.name, before.savings.single.name);
    });
  });

  group('createCycle : un seul cycle ouvert à la fois (§17)', () {
    test('bloque la création d\'un second cycle tant que le premier est ouvert', () async {
      await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));

      expect(
        () => repository.createCycle(startDate: DateTime(2026, 2, 1), endDate: DateTime(2026, 2, 28)),
        throwsA(isA<CycleAlreadyOpenException>()),
      );
    });

    test('erreur transactionnelle : une création bloquée ne crée aucun cycle', () async {
      await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
      final countBefore = (await repository.watchAllCycles().first).length;

      await expectLater(
        repository.createCycle(startDate: DateTime(2026, 2, 1), endDate: DateTime(2026, 2, 28)),
        throwsA(isA<CycleAlreadyOpenException>()),
      );

      final countAfter = (await repository.watchAllCycles().first).length;
      expect(countAfter, countBefore);
    });

    test('autorise la création dès que le précédent est clôturé', () async {
      final firstId = await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
      await repository.closeCycle(firstId);

      final secondId = await repository.createCycle(startDate: DateTime(2026, 2, 1), endDate: DateTime(2026, 2, 28));
      final current = await repository.loadCurrentCycleData();
      expect(current!.cycle.id, secondId);
    });
  });

  group('createCycle avec copyRecurringFromCycleId : revenus', () {
    test('recopie les revenus récurrents actifs avec leur valeur la plus récente', () async {
      final firstId = await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
      final incomeId = await repository.createIncome(
        cycleId: firstId,
        name: 'Salaire',
        expectedAmountCents: 300000,
        expectedDate: DateTime(2026, 1, 1),
        isRecurring: true,
      );
      // La valeur la plus récente doit être recopiée, pas la valeur de
      // création.
      await repository.updateIncome(
        id: incomeId,
        name: 'Salaire',
        expectedAmountCents: 320000,
        expectedDate: DateTime(2026, 1, 1),
        isRecurring: true,
        isActive: true,
      );
      await repository.closeCycle(firstId);

      final secondId = await repository.createCycle(
        startDate: DateTime(2026, 2, 1),
        endDate: DateTime(2026, 2, 28),
        copyRecurringFromCycleId: firstId,
      );

      final data = await repository.loadCurrentCycleData();
      expect(data!.cycle.id, secondId);
      expect(data.incomes, hasLength(1));
      expect(data.incomes.single.name, 'Salaire');
      expect(data.incomes.single.expectedAmountCents, 320000);
      expect(data.incomes.single.expectedDate, DateTime(2026, 2, 1));
      expect(data.incomes.single.status, IncomeStatus.prevu);
      expect(data.incomes.single.actualAmountCents, isNull);
    });

    test('ne recopie jamais un revenu ponctuel', () async {
      final firstId = await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
      await repository.createIncome(
        cycleId: firstId,
        name: 'Prime exceptionnelle',
        expectedAmountCents: 50000,
        expectedDate: DateTime(2026, 1, 15),
      );
      await repository.closeCycle(firstId);

      await repository.createCycle(
        startDate: DateTime(2026, 2, 1),
        endDate: DateTime(2026, 2, 28),
        copyRecurringFromCycleId: firstId,
      );

      final data = await repository.loadCurrentCycleData();
      expect(data!.incomes, isEmpty);
    });
  });

  group('createCycle avec copyRecurringFromCycleId : charges fixes', () {
    test('recopie les charges fixes récurrentes actives, conserve categoryId, remet le statut à "à venir"', () async {
      final firstId = await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
      final categories = await repository.categoriesForType(EntityType.fixedExpense);
      final categoryId = categories.first.id;
      final chargeId = await repository.createFixedExpense(
        cycleId: firstId,
        name: 'Loyer',
        expectedAmountCents: 90000,
        expectedDate: DateTime(2026, 1, 3),
        categoryId: categoryId,
        isRecurring: true,
      );
      await repository.confirmFixedExpense(chargeId, actualAmountCents: 90000);
      await repository.closeCycle(firstId);

      await repository.createCycle(
        startDate: DateTime(2026, 2, 1),
        endDate: DateTime(2026, 2, 28),
        copyRecurringFromCycleId: firstId,
      );

      final data = await repository.loadCurrentCycleData();
      expect(data!.fixedExpenses, hasLength(1));
      final newCharge = data.fixedExpenses.single;
      expect(newCharge.name, 'Loyer');
      expect(newCharge.expectedAmountCents, 90000);
      expect(newCharge.expectedDate, DateTime(2026, 2, 3));
      expect(newCharge.categoryId, categoryId);
      expect(newCharge.status, ChargeStatus.aVenir);
      expect(newCharge.actualAmountCents, isNull);
    });

    test('ne recopie jamais une charge ponctuelle', () async {
      final firstId = await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
      await repository.createFixedExpense(
        cycleId: firstId,
        name: 'Réparation exceptionnelle',
        expectedAmountCents: 15000,
        expectedDate: DateTime(2026, 1, 10),
      );
      await repository.closeCycle(firstId);

      await repository.createCycle(
        startDate: DateTime(2026, 2, 1),
        endDate: DateTime(2026, 2, 28),
        copyRecurringFromCycleId: firstId,
      );

      final data = await repository.loadCurrentCycleData();
      expect(data!.fixedExpenses, isEmpty);
    });

    test('ne recopie jamais une charge récurrente désactivée', () async {
      final firstId = await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
      final chargeId = await repository.createFixedExpense(
        cycleId: firstId,
        name: 'Abonnement résilié',
        expectedAmountCents: 1200,
        expectedDate: DateTime(2026, 1, 10),
        isRecurring: true,
      );
      await repository.updateFixedExpense(
        id: chargeId,
        name: 'Abonnement résilié',
        expectedAmountCents: 1200,
        expectedDate: DateTime(2026, 1, 10),
        isRecurring: true,
        isActive: false,
      );
      await repository.closeCycle(firstId);

      await repository.createCycle(
        startDate: DateTime(2026, 2, 1),
        endDate: DateTime(2026, 2, 28),
        copyRecurringFromCycleId: firstId,
      );

      final data = await repository.loadCurrentCycleData();
      expect(data!.fixedExpenses, isEmpty);
    });

    test('une charge récurrente ajoutée en cours de cycle est bien présente dans le suivant', () async {
      final firstId = await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
      // Ajoutée après la création initiale du cycle, "en cours de cycle".
      await repository.createFixedExpense(
        cycleId: firstId,
        name: 'Nouvel abonnement',
        expectedAmountCents: 999,
        expectedDate: DateTime(2026, 1, 20),
        isRecurring: true,
      );
      await repository.closeCycle(firstId);

      await repository.createCycle(
        startDate: DateTime(2026, 2, 1),
        endDate: DateTime(2026, 2, 28),
        copyRecurringFromCycleId: firstId,
      );

      final data = await repository.loadCurrentCycleData();
      expect(data!.fixedExpenses.map((e) => e.name), contains('Nouvel abonnement'));
    });

    test(
        'une charge liée à un crédit n\'est jamais recopiée par la copie récurrente (déjà régénérée séparément, jamais deux fois)',
        () async {
      final firstId = await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
      await repository.createCredit(
        name: 'Voiture',
        initialAmountCents: 1500000,
        remainingCapitalCents: 900000,
        monthlyPaymentCents: 25000,
        expectedEndDate: DateTime(2029, 1, 1),
        remainingInstallments: 36,
      );
      await repository.closeCycle(firstId);

      final secondId = await repository.createCycle(
        startDate: DateTime(2026, 2, 1),
        endDate: DateTime(2026, 2, 28),
        copyRecurringFromCycleId: firstId,
      );

      final data = await repository.loadCurrentCycleData();
      // Exactement une charge "Voiture" (générée par la synchronisation des
      // crédits actifs), jamais deux (qui indiquerait une double création).
      final voitureCharges = data!.fixedExpenses.where((e) => e.name == 'Voiture').toList();
      expect(voitureCharges, hasLength(1));
      expect(voitureCharges.single.linkedCreditId, isNotNull);
      expect(voitureCharges.single.cycleId, secondId);
    });
  });

  group('createCycle avec copyRecurringFromCycleId : dépenses variables', () {
    test('les dépenses variables du cycle précédent ne sont jamais recopiées : le nouveau cycle démarre à 0 €',
        () async {
      final firstId = await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
      await repository.createVariableExpense(cycleId: firstId, amountCents: 42800, date: DateTime(2026, 1, 10));
      await repository.closeCycle(firstId);

      await repository.createCycle(
        startDate: DateTime(2026, 2, 1),
        endDate: DateTime(2026, 2, 28),
        copyRecurringFromCycleId: firstId,
      );

      final data = await repository.loadCurrentCycleData();
      expect(data!.variableExpenses, isEmpty);
    });
  });

  group('createCycle avec copyRecurringFromCycleId : épargne', () {
    test('l\'épargne ponctuelle réalisée n\'est jamais recopiée', () async {
      final firstId = await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
      await repository.createSaving(
        cycleId: firstId,
        name: 'Cadeau mariage',
        expectedAmountCents: 30000,
        expectedDate: DateTime(2026, 1, 15),
      );
      await repository.closeCycle(firstId);

      await repository.createCycle(
        startDate: DateTime(2026, 2, 1),
        endDate: DateTime(2026, 2, 28),
        copyRecurringFromCycleId: firstId,
      );

      final data = await repository.loadCurrentCycleData();
      expect(data!.savings, isEmpty);
    });

    test('une épargne marquée récurrente est recréée comme un nouvel objectif, jamais le montant réalisé', () async {
      final firstId = await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
      final savingId = await repository.createSaving(
        cycleId: firstId,
        name: 'Livret A',
        expectedAmountCents: 20000,
        expectedDate: DateTime(2026, 1, 1),
        isRecurring: true,
      );
      // Réalisée avec un montant réel différent — jamais recopié comme
      // objectif du nouveau cycle.
      await repository.updateSaving(
        id: savingId,
        name: 'Livret A',
        expectedAmountCents: 20000,
        actualAmountCents: 25000,
        expectedDate: DateTime(2026, 1, 1),
        isRecurring: true,
        isActive: true,
      );
      await repository.closeCycle(firstId);

      await repository.createCycle(
        startDate: DateTime(2026, 2, 1),
        endDate: DateTime(2026, 2, 28),
        copyRecurringFromCycleId: firstId,
      );

      final data = await repository.loadCurrentCycleData();
      expect(data!.savings, hasLength(1));
      expect(data.savings.single.name, 'Livret A');
      expect(data.savings.single.expectedAmountCents, 20000);
      expect(data.savings.single.actualAmountCents, isNull); // jamais le montant réalisé
      expect(data.savings.single.status, SavingStatus.prevu);
    });
  });

  group('crédits et projets : jamais dupliqués', () {
    test('les crédits restent persistants, jamais dupliqués, jamais décrémentés par la seule création d\'un cycle',
        () async {
      final firstId = await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
      final creditId = await repository.createCredit(
        name: 'Voiture',
        initialAmountCents: 1500000,
        remainingCapitalCents: 900000,
        monthlyPaymentCents: 25000,
        expectedEndDate: DateTime(2029, 1, 1),
        remainingInstallments: 36,
      );
      await repository.closeCycle(firstId);
      await repository.createCycle(
        startDate: DateTime(2026, 2, 1),
        endDate: DateTime(2026, 2, 28),
        copyRecurringFromCycleId: firstId,
      );

      final credits = await repository.loadCredits();
      expect(credits, hasLength(1));
      expect(credits.single.id, creditId);
      // Jamais décrémenté par le simple passage de cycle — seule une
      // mensualité confirmée fait avancer un crédit.
      expect(credits.single.remainingCapitalCents, 900000);
      expect(credits.single.remainingInstallments, 36);
    });

    test(
        'un crédit avance uniquement sur une mensualité confirmée pendant le cycle précédent, jamais sur la '
        'seule création du cycle suivant', () async {
      final firstId = await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
      await repository.createCredit(
        name: 'Voiture',
        initialAmountCents: 1500000,
        remainingCapitalCents: 900000,
        monthlyPaymentCents: 25000,
        expectedEndDate: DateTime(2029, 1, 1),
        remainingInstallments: 36,
      );
      final dataBefore = await repository.loadCurrentCycleData();
      final linkedCharge = dataBefore!.fixedExpenses.single;
      await repository.confirmFixedExpense(linkedCharge.id);

      await repository.closeCycle(firstId);
      await repository.createCycle(
        startDate: DateTime(2026, 2, 1),
        endDate: DateTime(2026, 2, 28),
        copyRecurringFromCycleId: firstId,
      );

      final credits = await repository.loadCredits();
      expect(credits.single.remainingCapitalCents, 900000 - 25000);
      expect(credits.single.remainingInstallments, 35);

      // Le nouveau cycle recrée simplement la prochaine charge liée.
      final dataAfter = await repository.loadCurrentCycleData();
      final nextCharge = dataAfter!.fixedExpenses.singleWhere((e) => e.linkedCreditId == credits.single.id);
      expect(nextCharge.status, ChargeStatus.aVenir);
    });

    test('les projets restent persistants, jamais dupliqués', () async {
      final firstId = await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
      final projectId = await repository.createProject(
        name: 'Voyage',
        category: ProjectCategory.travel,
        targetAmountCents: 300000,
        financingMode: ProjectFinancingMode.cash,
      );
      await repository.closeCycle(firstId);
      await repository.createCycle(
        startDate: DateTime(2026, 2, 1),
        endDate: DateTime(2026, 2, 28),
        copyRecurringFromCycleId: firstId,
      );

      final projects = await repository.loadProjects();
      expect(projects, hasLength(1));
      expect(projects.single.id, projectId);
    });
  });

  group('solde bancaire du nouveau cycle et argent libre', () {
    test('accepte un solde de départ positif', () async {
      final firstId = await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
      await repository.closeCycle(firstId);
      final secondId = await repository.createCycle(
        startDate: DateTime(2026, 2, 1),
        endDate: DateTime(2026, 2, 28),
        declaredBankBalanceCents: 50000,
        copyRecurringFromCycleId: firstId,
      );

      final data = await (db.select(db.budgetCycles)..where((c) => c.id.equals(secondId))).getSingle();
      expect(data.declaredBankBalanceCents, 50000);
    });

    test('accepte un solde de départ négatif', () async {
      final firstId = await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
      await repository.closeCycle(firstId);
      final secondId = await repository.createCycle(
        startDate: DateTime(2026, 2, 1),
        endDate: DateTime(2026, 2, 28),
        declaredBankBalanceCents: -58600,
        copyRecurringFromCycleId: firstId,
      );

      final data = await (db.select(db.budgetCycles)..where((c) => c.id.equals(secondId))).getSingle();
      expect(data.declaredBankBalanceCents, -58600);
    });
  });

  group('gestion des dates : 29/30/31, février, année bissextile (§14)', () {
    test('une charge récurrente prévue le 31 est déplacée au dernier jour valide du mois suivant (30 jours)', () async {
      final firstId = await repository.createCycle(startDate: DateTime(2026, 3, 1), endDate: DateTime(2026, 3, 31));
      await repository.createFixedExpense(
        cycleId: firstId,
        name: 'Loyer',
        expectedAmountCents: 90000,
        expectedDate: DateTime(2026, 3, 31),
        isRecurring: true,
      );
      await repository.closeCycle(firstId);
      await repository.createCycle(
        startDate: DateTime(2026, 4, 1),
        endDate: DateTime(2026, 4, 30),
        copyRecurringFromCycleId: firstId,
      );

      final data = await repository.loadCurrentCycleData();
      expect(data!.fixedExpenses.single.expectedDate, DateTime(2026, 4, 30));
    });

    test('une charge récurrente prévue le 31 janvier tombe au 28 février (année non bissextile)', () async {
      final firstId = await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
      await repository.createFixedExpense(
        cycleId: firstId,
        name: 'Assurance',
        expectedAmountCents: 5000,
        expectedDate: DateTime(2026, 1, 31),
        isRecurring: true,
      );
      await repository.closeCycle(firstId);
      await repository.createCycle(
        startDate: DateTime(2026, 2, 1),
        endDate: DateTime(2026, 2, 28),
        copyRecurringFromCycleId: firstId,
      );

      final data = await repository.loadCurrentCycleData();
      expect(data!.fixedExpenses.single.expectedDate, DateTime(2026, 2, 28));
    });

    test('une charge récurrente prévue le 31 janvier tombe au 29 février lors d\'une année bissextile', () async {
      final firstId = await repository.createCycle(startDate: DateTime(2028, 1, 1), endDate: DateTime(2028, 1, 31));
      await repository.createFixedExpense(
        cycleId: firstId,
        name: 'Assurance',
        expectedAmountCents: 5000,
        expectedDate: DateTime(2028, 1, 31),
        isRecurring: true,
      );
      await repository.closeCycle(firstId);
      await repository.createCycle(
        startDate: DateTime(2028, 2, 1),
        endDate: DateTime(2028, 2, 29),
        copyRecurringFromCycleId: firstId,
      );

      final data = await repository.loadCurrentCycleData();
      expect(data!.fixedExpenses.single.expectedDate, DateTime(2028, 2, 29));
    });
  });

  test(
      'intégration complète : Cycle A (revenus + charges + dépenses + mensualité crédit confirmée) -> clôture -> '
      'Cycle B (revenus récurrents, charges récurrentes, dépenses = 0, crédit non dupliqué, prochaine charge '
      'crédit) -> Cycle A inchangé', () async {
    // --- Cycle A ---
    final cycleA = await repository.createCycle(
      startDate: DateTime(2026, 1, 27),
      endDate: DateTime(2026, 2, 26),
      declaredBankBalanceCents: -58600,
    );
    await repository.createIncome(
      cycleId: cycleA,
      name: 'Salaire',
      expectedAmountCents: 424300,
      expectedDate: DateTime(2026, 1, 27),
      isRecurring: true,
    );
    await repository.createIncome(
      cycleId: cycleA,
      name: 'Prime one-shot',
      expectedAmountCents: 10000,
      expectedDate: DateTime(2026, 2, 1),
    );
    final loyerId = await repository.createFixedExpense(
      cycleId: cycleA,
      name: 'Loyer',
      expectedAmountCents: 90000,
      expectedDate: DateTime(2026, 1, 31),
      isRecurring: true,
    );
    await repository.createFixedExpense(
      cycleId: cycleA,
      name: 'Réparation ponctuelle',
      expectedAmountCents: 8000,
      expectedDate: DateTime(2026, 2, 5),
    );
    await repository.createVariableExpense(cycleId: cycleA, amountCents: 30000, date: DateTime(2026, 2, 10));
    await repository.createSaving(
      cycleId: cycleA,
      name: 'Épargne mensuelle',
      expectedAmountCents: 20000,
      expectedDate: DateTime(2026, 1, 27),
      isRecurring: true,
    );
    final creditId = await repository.createCredit(
      name: 'Voiture',
      initialAmountCents: 1500000,
      remainingCapitalCents: 900000,
      monthlyPaymentCents: 25000,
      expectedEndDate: DateTime(2029, 1, 1),
      remainingInstallments: 36,
    );
    final dataA = await repository.loadCurrentCycleData();
    final creditCharge = dataA!.fixedExpenses.singleWhere((e) => e.linkedCreditId == creditId);
    await repository.confirmFixedExpense(creditCharge.id);
    await repository.confirmFixedExpense(loyerId, actualAmountCents: 90000);

    // Snapshot de Cycle A juste avant clôture, pour vérifier plus tard
    // qu'il reste parfaitement inchangé.
    final snapshotIncomes = await (db.select(db.incomes)..where((i) => i.cycleId.equals(cycleA))).get();
    final snapshotFixedExpenses = await (db.select(db.fixedExpenses)..where((e) => e.cycleId.equals(cycleA))).get();
    final snapshotVariableExpenses =
        await (db.select(db.variableExpenses)..where((e) => e.cycleId.equals(cycleA))).get();
    final snapshotSavings = await (db.select(db.savings)..where((s) => s.cycleId.equals(cycleA))).get();

    // --- Clôture ---
    await repository.closeCycle(cycleA);
    final closedA = await (db.select(db.budgetCycles)..where((c) => c.id.equals(cycleA))).getSingle();
    expect(closedA.status, CycleStatus.ferme);

    // --- Cycle B ---
    final cycleB = await repository.createCycle(
      startDate: DateTime(2026, 2, 27),
      endDate: DateTime(2026, 3, 26),
      declaredBankBalanceCents: 100000,
      copyRecurringFromCycleId: cycleA,
    );

    final dataB = await repository.loadCurrentCycleData();
    expect(dataB!.cycle.id, cycleB);

    // Revenus récurrents recopiés, ponctuels absents.
    expect(dataB.incomes, hasLength(1));
    expect(dataB.incomes.single.name, 'Salaire');
    expect(dataB.incomes.single.expectedDate, DateTime(2026, 2, 27));
    expect(dataB.incomes.any((i) => i.name == 'Prime one-shot'), isFalse);

    // Charges récurrentes recopiées (hors crédit) + charge de crédit
    // régénérée séparément — jamais la réparation ponctuelle.
    expect(dataB.fixedExpenses.any((e) => e.name == 'Réparation ponctuelle'), isFalse);
    final loyerB = dataB.fixedExpenses.singleWhere((e) => e.name == 'Loyer');
    expect(loyerB.status, ChargeStatus.aVenir);
    expect(loyerB.expectedDate, DateTime(2026, 2, 28)); // 31 jan -> +1 mois -> 28 fév

    // Dépenses variables toujours à 0.
    expect(dataB.variableExpenses, isEmpty);

    // Épargne récurrente recopiée comme nouvel objectif.
    final epargneB = dataB.savings.singleWhere((s) => s.name == 'Épargne mensuelle');
    expect(epargneB.actualAmountCents, isNull);

    // Crédit non dupliqué, avancé uniquement par la mensualité confirmée.
    final credits = await repository.loadCredits();
    expect(credits, hasLength(1));
    expect(credits.single.id, creditId);
    expect(credits.single.remainingCapitalCents, 900000 - 25000);
    expect(credits.single.remainingInstallments, 35);

    // Prochaine charge de crédit bien présente dans Cycle B, à venir.
    final creditChargeB = dataB.fixedExpenses.singleWhere((e) => e.linkedCreditId == creditId);
    expect(creditChargeB.status, ChargeStatus.aVenir);
    expect(creditChargeB.cycleId, cycleB);

    // Cycle A rigoureusement inchangé après la création de Cycle B.
    final incomesAAfter = await (db.select(db.incomes)..where((i) => i.cycleId.equals(cycleA))).get();
    final fixedExpensesAAfter = await (db.select(db.fixedExpenses)..where((e) => e.cycleId.equals(cycleA))).get();
    final variableExpensesAAfter = await (db.select(db.variableExpenses)..where((e) => e.cycleId.equals(cycleA))).get();
    final savingsAAfter = await (db.select(db.savings)..where((s) => s.cycleId.equals(cycleA))).get();

    expect(incomesAAfter.length, snapshotIncomes.length);
    expect(fixedExpensesAAfter.length, snapshotFixedExpenses.length);
    expect(variableExpensesAAfter.length, snapshotVariableExpenses.length);
    expect(savingsAAfter.length, snapshotSavings.length);
    for (final original in snapshotFixedExpenses) {
      final stillThere = fixedExpensesAAfter.singleWhere((e) => e.id == original.id);
      expect(stillThere.status, original.status);
      expect(stillThere.actualAmountCents, original.actualAmountCents);
      expect(stillThere.expectedAmountCents, original.expectedAmountCents);
    }
  });
}
