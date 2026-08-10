import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:budgetpilot/core/constants/app_constants.dart';
import 'package:budgetpilot/data/local/cycle_repository.dart';
import 'package:budgetpilot/data/local/database.dart';

void main() {
  late AppDatabase db;
  late CycleRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = CycleRepository(db);
  });

  tearDown(() => db.close());

  test('createCycle crée un cycle et le rend courant', () async {
    final start = DateTime(2026, 7, 27);
    final end = DateTime(2026, 8, 26);

    final id = await repository.createCycle(
      startDate: start,
      endDate: end,
      name: 'Cycle test',
      declaredBankBalanceCents: 150000,
    );

    final data = await repository.loadCurrentCycleData();
    expect(data, isNotNull);
    expect(data!.cycle.id, id);
    expect(data.cycle.name, 'Cycle test');
    expect(data.cycle.startDate, start);
    expect(data.cycle.endDate, end);
    expect(data.cycle.declaredBankBalanceCents, 150000);
    expect(data.cycle.status, 'ouvert');
  });

  test('createCycle sans nom ni solde laisse ces champs à null', () async {
    await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));

    final data = await repository.loadCurrentCycleData();
    expect(data!.cycle.name, isNull);
    expect(data.cycle.declaredBankBalanceCents, isNull);
  });

  test('createCycle peuple les catégories par défaut une seule fois', () async {
    await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
    final afterFirst = await db.select(db.categories).get();
    expect(afterFirst, isNotEmpty);

    await repository.ensureDefaultCategories();
    final afterSecond = await db.select(db.categories).get();
    expect(afterSecond.length, afterFirst.length);
  });

  test('createIncome, updateIncome puis deleteIncome', () async {
    final cycleId = await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));

    final incomeId = await repository.createIncome(
      cycleId: cycleId,
      name: 'Salaire',
      expectedAmountCents: 250000,
      expectedDate: DateTime(2026, 1, 5),
    );

    var data = await repository.loadCurrentCycleData();
    expect(data!.incomes, hasLength(1));
    expect(data.incomes.single.name, 'Salaire');
    expect(data.incomes.single.actualAmountCents, isNull);

    await repository.updateIncome(
      id: incomeId,
      name: 'Salaire net',
      expectedAmountCents: 250000,
      actualAmountCents: 248000,
      expectedDate: DateTime(2026, 1, 5),
      isRecurring: true,
      isActive: true,
    );

    data = await repository.loadCurrentCycleData();
    expect(data!.incomes.single.name, 'Salaire net');
    expect(data.incomes.single.actualAmountCents, 248000);
    expect(data.incomes.single.isRecurring, isTrue);

    await repository.deleteIncome(incomeId);
    data = await repository.loadCurrentCycleData();
    expect(data!.incomes, isEmpty);
  });

  test('createFixedExpense associe la catégorie choisie', () async {
    final cycleId = await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
    final categories = await repository.categoriesForType(EntityType.fixedExpense);
    expect(categories, isNotEmpty);
    final categoryId = categories.first.id;

    final id = await repository.createFixedExpense(
      cycleId: cycleId,
      name: 'Loyer',
      expectedAmountCents: 85000,
      expectedDate: DateTime(2026, 1, 3),
      categoryId: categoryId,
    );

    final data = await repository.loadCurrentCycleData();
    final fixed = data!.fixedExpenses.singleWhere((e) => e.id == id);
    expect(fixed.categoryId, categoryId);
    expect(fixed.status, 'a_venir');

    await repository.deleteFixedExpense(id);
    final afterDelete = await repository.loadCurrentCycleData();
    expect(afterDelete!.fixedExpenses, isEmpty);
  });

  test('createVariableExpense puis updateVariableExpense', () async {
    final cycleId = await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));

    final id = await repository.createVariableExpense(
      cycleId: cycleId,
      amountCents: 4200,
      date: DateTime(2026, 1, 10),
    );

    await repository.updateVariableExpense(
      id: id,
      name: 'Courses',
      amountCents: 5000,
      date: DateTime(2026, 1, 11),
    );

    final data = await repository.loadCurrentCycleData();
    final expense = data!.variableExpenses.single;
    expect(expense.name, 'Courses');
    expect(expense.amountCents, 5000);
  });

  test('createSaving puis deleteSaving', () async {
    final cycleId = await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));

    final id = await repository.createSaving(
      cycleId: cycleId,
      name: 'Mariage',
      expectedAmountCents: 80000,
      expectedDate: DateTime(2026, 1, 1),
    );

    var data = await repository.loadCurrentCycleData();
    expect(data!.savings.single.name, 'Mariage');

    await repository.deleteSaving(id);
    data = await repository.loadCurrentCycleData();
    expect(data!.savings, isEmpty);
  });

  test('watchAllCycles renvoie tous les cycles du plus récent au plus ancien', () async {
    final firstId = await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
    // Un seul cycle 'ouvert' à la fois (§17) : le premier doit être
    // clôturé avant de pouvoir créer le second.
    await repository.closeCycle(firstId);
    await repository.createCycle(startDate: DateTime(2026, 2, 1), endDate: DateTime(2026, 2, 28));

    final cycles = await repository.watchAllCycles().first;
    expect(cycles, hasLength(2));
    expect(cycles.first.startDate, DateTime(2026, 2, 1));
  });

  test('watchThemeMode démarre sur "system" puis reflète setThemeMode', () async {
    final stream = repository.watchThemeMode();
    final values = <String>[];
    final subscription = stream.listen(values.add);

    await Future<void>.delayed(Duration.zero);
    expect(values, ['system']);

    await repository.setThemeMode('dark');
    await Future<void>.delayed(Duration.zero);
    expect(values, ['system', 'dark']);

    await repository.setThemeMode('light');
    await Future<void>.delayed(Duration.zero);
    expect(values.last, 'light');

    await subscription.cancel();
  });

  group('resetAllUserData ("Repartir de zéro")', () {
    Future<void> seedEverything() async {
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
        expectedDate: DateTime(2026, 1, 3),
      );
      await repository.createVariableExpense(
        cycleId: cycleId,
        amountCents: 5000,
        date: DateTime(2026, 1, 5),
      );
      await repository.createSaving(
        cycleId: cycleId,
        name: 'Livret',
        expectedAmountCents: 10000,
        expectedDate: DateTime(2026, 1, 1),
      );
      await repository.createCredit(
        name: 'Voiture',
        initialAmountCents: 1500000,
        remainingCapitalCents: 900000,
        monthlyPaymentCents: 25000,
        expectedEndDate: DateTime(2029, 1, 1),
        remainingInstallments: 36,
      );
      await repository.createProject(
        name: 'Voyage',
        category: ProjectCategory.travel,
        targetAmountCents: 300000,
        financingMode: ProjectFinancingMode.cash,
      );
      await repository.setThemeMode('dark');
    }

    test('supprime toutes les données financières et leur historique associé', () async {
      await seedEverything();

      await repository.resetAllUserData();

      expect(await repository.watchAllCycles().first, isEmpty);
      expect(await repository.loadCurrentCycleData(), isNull);
      expect(await repository.loadProjects(), isEmpty);
      final credits = await (db.select(db.credits)).get();
      expect(credits, isEmpty);
      final incomes = await db.select(db.incomes).get();
      expect(incomes, isEmpty);
      final fixedExpenses = await db.select(db.fixedExpenses).get();
      expect(fixedExpenses, isEmpty);
      final variableExpenses = await db.select(db.variableExpenses).get();
      expect(variableExpenses, isEmpty);
      final savings = await db.select(db.savings).get();
      expect(savings, isEmpty);
      final notificationLogs = await db.select(db.notificationLogs).get();
      expect(notificationLogs, isEmpty);
    });

    test('conserve les préférences (thème) et la configuration technique (catégories)', () async {
      await seedEverything();
      final categoriesBefore = await db.select(db.categories).get();
      expect(categoriesBefore, isNotEmpty);

      await repository.resetAllUserData();

      final themeAfter = await repository.watchThemeMode().first;
      expect(themeAfter, 'dark');
      final categoriesAfter = await db.select(db.categories).get();
      expect(categoriesAfter.length, categoriesBefore.length);
    });

    test(
        'revient exactement à l\'état du premier lancement : un nouveau cycle peut être créé normalement '
        'après la réinitialisation', () async {
      await seedEverything();
      await repository.resetAllUserData();

      final id = await repository.createCycle(startDate: DateTime(2026, 6, 1), endDate: DateTime(2026, 6, 30));
      final data = await repository.loadCurrentCycleData();

      expect(data, isNotNull);
      expect(data!.cycle.id, id);
      expect(data.incomes, isEmpty);
      expect(data.fixedExpenses, isEmpty);
    });

    test('ne laisse aucune donnée résiduelle même avec plusieurs cycles', () async {
      final firstId = await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
      await repository.closeCycle(firstId);
      await repository.createCycle(startDate: DateTime(2026, 2, 1), endDate: DateTime(2026, 2, 28));
      final secondId = (await repository.watchAllCycles().first).firstWhere((c) => c.status == 'ouvert').id;
      await repository.closeCycle(secondId);
      await seedEverything();

      await repository.resetAllUserData();

      expect(await repository.watchAllCycles().first, isEmpty);
    });
  });
}
