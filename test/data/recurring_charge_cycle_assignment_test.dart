import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:budgetpilot/core/constants/app_constants.dart';
import 'package:budgetpilot/data/local/cycle_repository.dart';
import 'package:budgetpilot/data/local/database.dart';
import 'package:budgetpilot/domain/calculations/budget_calculation_service.dart';
import 'package:budgetpilot/data/local/converters/entity_mappers.dart';

const _calculationService = BudgetCalculationService();

/// Correctif "échéances récurrentes hors cycle" : une charge fixe récurrente
/// n'appartient à un cycle que si la date réelle de son occurrence tombe
/// dans `[cycle.startDate, cycle.endDate]` — le caractère "récurrent" ne
/// suffit jamais à lui seul à la faire entrer dans le total d'un cycle.
void main() {
  late AppDatabase db;
  late CycleRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = CycleRepository(db);
  });

  tearDown(() => db.close());

  test(
      'cas de référence : cycle 28/07/2026 -> 28/08/2026, occurrence le 30/08/2026 '
      'contribue exactement 0 € au total du cycle', () async {
    final firstId = await repository.createCycle(startDate: DateTime(2026, 6, 28), endDate: DateTime(2026, 7, 27));
    await repository.createFixedExpense(
      cycleId: firstId,
      name: 'Prélèvement X',
      expectedAmountCents: 10000,
      expectedDate: DateTime(2026, 6, 30),
      isRecurring: true,
      recurrenceType: RecurrenceType.tousLesXJours,
      recurrenceIntervalValue: 61, // 30 juin + 61 jours = 30 août
    );
    await repository.closeCycle(firstId);

    await repository.createCycle(
      startDate: DateTime(2026, 7, 28),
      endDate: DateTime(2026, 8, 28),
      copyRecurringFromCycleId: firstId,
    );

    final data = await repository.loadCurrentCycleData();
    expect(data!.fixedExpenses, isEmpty, reason: '30 août 2026 est après la fin du cycle (28 août)');
    final total = _calculationService.calculateTotalFixedExpenses(
      data.fixedExpenses.map(fixedExpenseFromRow).toList(),
    );
    expect(total, 0);
  });

  group('règle métier : cycle.startDate <= dueDate <= cycle.endDate (via cycle-copy)', () {
    test('une occurrence après la fin du cycle suivant n\'y est jamais recopiée', () async {
      final firstId = await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
      await repository.createFixedExpense(
        cycleId: firstId,
        name: 'Assurance auto',
        expectedAmountCents: 5000,
        expectedDate: DateTime(2026, 1, 1),
        isRecurring: true,
        recurrenceType: RecurrenceType.tousLesXJours,
        recurrenceIntervalValue: 100, // dépasse largement la fin du cycle suivant (28 février)
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

    test('charge mensuelle classique : recopiée à la bonne date, dans le bon cycle', () async {
      final firstId = await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
      await repository.createFixedExpense(
        cycleId: firstId,
        name: 'Loyer',
        expectedAmountCents: 90000,
        expectedDate: DateTime(2026, 1, 5),
        isRecurring: true,
        recurrenceType: RecurrenceType.mensuelJourFixe,
      );
      await repository.closeCycle(firstId);

      await repository.createCycle(
        startDate: DateTime(2026, 2, 1),
        endDate: DateTime(2026, 2, 28),
        copyRecurringFromCycleId: firstId,
      );

      final data = await repository.loadCurrentCycleData();
      expect(data!.fixedExpenses, hasLength(1));
      expect(data.fixedExpenses.single.expectedDate, DateTime(2026, 2, 5));
    });

    test('charge toutes les 4 semaines : recopiée à J+28, jamais convertie en "1 fois par mois"', () async {
      final firstId = await repository.createCycle(startDate: DateTime(2026, 7, 1), endDate: DateTime(2026, 7, 31));
      await repository.createFixedExpense(
        cycleId: firstId,
        name: 'Prélèvement X',
        expectedAmountCents: 5000,
        expectedDate: DateTime(2026, 7, 5),
        isRecurring: true,
        recurrenceType: RecurrenceType.toutesLesXSemaines,
        recurrenceIntervalValue: 4,
      );
      await repository.closeCycle(firstId);

      await repository.createCycle(
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2026, 8, 28),
        copyRecurringFromCycleId: firstId,
      );

      final data = await repository.loadCurrentCycleData();
      expect(data!.fixedExpenses.single.expectedDate, DateTime(2026, 8, 2)); // 5 juillet + 28 jours
    });

    test('deux occurrences d\'une même charge récurrente dans un même cycle', () async {
      // Cycle "from" court, juste pour porter la 1ère occurrence.
      final firstId = await repository.createCycle(startDate: DateTime(2026, 8, 1), endDate: DateTime(2026, 8, 2));
      await repository.createFixedExpense(
        cycleId: firstId,
        name: 'Prélèvement X',
        expectedAmountCents: 5000,
        expectedDate: DateTime(2026, 8, 2),
        isRecurring: true,
        recurrenceType: RecurrenceType.toutesLesXSemaines,
        recurrenceIntervalValue: 4,
      );
      await repository.closeCycle(firstId);

      // Cycle 29 août -> 28 septembre (31 jours) : reçoit les occurrences du
      // 30 août ET du 27 septembre (28 jours d'écart).
      await repository.createCycle(
        startDate: DateTime(2026, 8, 29),
        endDate: DateTime(2026, 9, 28),
        copyRecurringFromCycleId: firstId,
      );

      final data = await repository.loadCurrentCycleData();
      expect(data!.fixedExpenses, hasLength(2));
      final dates = data.fixedExpenses.map((e) => e.expectedDate).toList()..sort();
      expect(dates, [DateTime(2026, 8, 30), DateTime(2026, 9, 27)]);
      final total = _calculationService.calculateTotalFixedExpenses(
        data.fixedExpenses.map(fixedExpenseFromRow).toList(),
      );
      expect(total, 10000); // les deux occurrences comptent bien, sans plafond artificiel
    });

    test(
        'zéro occurrence dans un cycle, puis reprise correcte au cycle suivant '
        '(la chaîne ne casse jamais)', () async {
      final firstId = await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
      await repository.createFixedExpense(
        cycleId: firstId,
        name: 'Prime trimestrielle',
        expectedAmountCents: 15000,
        expectedDate: DateTime(2026, 1, 1),
        isRecurring: true,
        recurrenceType: RecurrenceType.tousLesXJours,
        recurrenceIntervalValue: 90, // ne retombe pas dans le cycle de février
      );
      await repository.closeCycle(firstId);

      final secondId = await repository.createCycle(
        startDate: DateTime(2026, 2, 1),
        endDate: DateTime(2026, 2, 28),
        copyRecurringFromCycleId: firstId,
      );
      final afterGapCycle = await repository.loadCurrentCycleData();
      expect(afterGapCycle!.fixedExpenses, isEmpty, reason: 'aucune occurrence ne doit tomber dans ce cycle');

      await repository.closeCycle(secondId);
      // 1 janvier + 90 jours = 1 avril : doit apparaître dans ce cycle-ci,
      // malgré le cycle précédent sans occurrence — le curseur reste la
      // dernière occurrence réelle (janvier), jamais réinitialisé par un
      // cycle intermédiaire vide.
      await repository.createCycle(
        startDate: DateTime(2026, 4, 1),
        endDate: DateTime(2026, 4, 30),
        copyRecurringFromCycleId: secondId,
      );
      final data = await repository.loadCurrentCycleData();
      expect(data!.fixedExpenses, hasLength(1));
      expect(data.fixedExpenses.single.expectedDate, DateTime(2026, 4, 1));
    });
  });

  test('une charge récurrente antérieure au correctif (sans modèle) continue de fonctionner', () async {
    // Simule une charge créée avant l'ajout du modèle récurrent : recopiée
    // via createFixedExpense sans préciser de type de récurrence explicite
    // (valeur par défaut : mensuel_jour_fixe, comportement historique).
    final firstId = await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
    await repository.createFixedExpense(
      cycleId: firstId,
      name: 'Internet',
      expectedAmountCents: 3500,
      expectedDate: DateTime(2026, 1, 10),
      isRecurring: true,
    );
    await repository.closeCycle(firstId);

    await repository.createCycle(
      startDate: DateTime(2026, 2, 1),
      endDate: DateTime(2026, 2, 28),
      copyRecurringFromCycleId: firstId,
    );

    final data = await repository.loadCurrentCycleData();
    expect(data!.fixedExpenses.single.expectedDate, DateTime(2026, 2, 10));
  });

  test('aucune duplication d\'occurrence en enchaînant plusieurs cycles', () async {
    final firstId = await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
    await repository.createFixedExpense(
      cycleId: firstId,
      name: 'Loyer',
      expectedAmountCents: 90000,
      expectedDate: DateTime(2026, 1, 5),
      isRecurring: true,
    );
    await repository.closeCycle(firstId);

    final secondId = await repository.createCycle(
      startDate: DateTime(2026, 2, 1),
      endDate: DateTime(2026, 2, 28),
      copyRecurringFromCycleId: firstId,
    );
    await repository.closeCycle(secondId);

    await repository.createCycle(
      startDate: DateTime(2026, 3, 1),
      endDate: DateTime(2026, 3, 31),
      copyRecurringFromCycleId: secondId,
    );

    final all = await (db.select(db.fixedExpenses)).get();
    expect(all, hasLength(3)); // une occurrence par cycle, jamais deux fois la même
    final dates = all.map((e) => e.expectedDate).toSet();
    expect(dates, {DateTime(2026, 1, 5), DateTime(2026, 2, 5), DateTime(2026, 3, 5)});
  });

  test('argent libre du cycle : une occurrence hors cycle ne réduit jamais l\'argent libre actuel', () async {
    final firstId = await repository.createCycle(
      startDate: DateTime(2026, 6, 28),
      endDate: DateTime(2026, 7, 27),
      declaredBankBalanceCents: 0,
    );
    await repository.createIncome(
      cycleId: firstId,
      name: 'Salaire',
      expectedAmountCents: 300000,
      expectedDate: DateTime(2026, 6, 28),
    );
    await repository.createFixedExpense(
      cycleId: firstId,
      name: 'Prélèvement X',
      expectedAmountCents: 10000,
      expectedDate: DateTime(2026, 6, 30),
      isRecurring: true,
      recurrenceType: RecurrenceType.tousLesXJours,
      recurrenceIntervalValue: 61, // -> 30 août, hors du cycle suivant
    );
    await repository.closeCycle(firstId);

    await repository.createCycle(
      startDate: DateTime(2026, 7, 28),
      endDate: DateTime(2026, 8, 28),
      copyRecurringFromCycleId: firstId,
      declaredBankBalanceCents: 0,
    );
    final data = await repository.loadCurrentCycleData();
    // Aucun revenu recopié (ponctuel) ni charge (hors cycle) : argent libre = 0.
    final realRemaining = _calculationService.calculateRealRemaining(
      incomes: data!.incomes.map(incomeFromRow).toList(),
      fixedExpenses: data.fixedExpenses.map(fixedExpenseFromRow).toList(),
      variableExpenses: const [],
      savings: const [],
      startingBalanceCents: data.cycle.declaredBankBalanceCents ?? 0,
    );
    expect(realRemaining, 0);
  });

  test(
      'désactiver une charge récurrente (isRecurring toujours vrai) arrête bien les futures '
      'occurrences — pas seulement la mettre en pause d\'un cycle', () async {
    final firstId = await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
    final chargeId = await repository.createFixedExpense(
      cycleId: firstId,
      name: 'Abonnement résilié',
      expectedAmountCents: 1200,
      expectedDate: DateTime(2026, 1, 10),
      isRecurring: true,
    );
    // isRecurring reste vrai (l'utilisateur ne l'a pas décoché) mais la
    // charge est désactivée — le modèle ne doit plus jamais générer.
    await repository.updateFixedExpense(
      id: chargeId,
      name: 'Abonnement résilié',
      expectedAmountCents: 1200,
      expectedDate: DateTime(2026, 1, 10),
      isRecurring: true,
      isActive: false,
    );
    await repository.closeCycle(firstId);

    final secondId = await repository.createCycle(
      startDate: DateTime(2026, 2, 1),
      endDate: DateTime(2026, 2, 28),
      copyRecurringFromCycleId: firstId,
    );
    expect((await repository.loadCurrentCycleData())!.fixedExpenses, isEmpty);

    // Vérifie aussi que ça reste vrai au cycle d'après (le modèle est bien
    // resté désactivé, pas seulement ignoré une fois).
    await repository.closeCycle(secondId);
    await repository.createCycle(
      startDate: DateTime(2026, 3, 1),
      endDate: DateTime(2026, 3, 31),
      copyRecurringFromCycleId: secondId,
    );
    expect((await repository.loadCurrentCycleData())!.fixedExpenses, isEmpty);
  });

  test('historique inchangé : la création du cycle suivant ne modifie jamais le cycle clôturé', () async {
    final firstId = await repository.createCycle(startDate: DateTime(2026, 6, 28), endDate: DateTime(2026, 7, 27));
    final chargeId = await repository.createFixedExpense(
      cycleId: firstId,
      name: 'Prélèvement X',
      expectedAmountCents: 10000,
      expectedDate: DateTime(2026, 6, 30),
      isRecurring: true,
      recurrenceType: RecurrenceType.tousLesXJours,
      recurrenceIntervalValue: 61,
    );
    await repository.closeCycle(firstId);
    final before = await (db.select(db.fixedExpenses)..where((e) => e.id.equals(chargeId))).getSingle();

    await repository.createCycle(
      startDate: DateTime(2026, 7, 28),
      endDate: DateTime(2026, 8, 28),
      copyRecurringFromCycleId: firstId,
    );

    final after = await (db.select(db.fixedExpenses)..where((e) => e.id.equals(chargeId))).getSingle();
    expect(after.expectedAmountCents, before.expectedAmountCents);
    expect(after.expectedDate, before.expectedDate);
    expect(after.cycleId, before.cycleId);
    expect(after.name, before.name);
  });

  group(
      'correctif "affectation des charges par date" : la date modifiée manuellement '
      'est la source de vérité', () {
    test(
        'cas de référence : charge à 100 € le 26/08 comptée dans le cycle 28/07->28/08, '
        'déplacée au 30/08 -> retirée, argent libre +100 € immédiatement', () async {
      final cycleId = await repository.createCycle(
        startDate: DateTime(2026, 7, 28),
        endDate: DateTime(2026, 8, 28),
        declaredBankBalanceCents: 0,
      );
      await repository.createIncome(
        cycleId: cycleId,
        name: 'Salaire',
        expectedAmountCents: 300000,
        expectedDate: DateTime(2026, 7, 28),
      );
      final chargeId = await repository.createFixedExpense(
        cycleId: cycleId,
        name: 'Prélèvement X',
        expectedAmountCents: 10000,
        expectedDate: DateTime(2026, 8, 26),
      );

      final before = await repository.loadCurrentCycleData();
      expect(before!.fixedExpenses, hasLength(1));
      final totalBefore =
          _calculationService.calculateTotalFixedExpenses(before.fixedExpenses.map(fixedExpenseFromRow).toList());
      expect(totalBefore, 10000);
      final remainingBefore = _calculationService.calculateRealRemaining(
        incomes: before.incomes.map(incomeFromRow).toList(),
        fixedExpenses: before.fixedExpenses.map(fixedExpenseFromRow).toList(),
        variableExpenses: const [],
        savings: const [],
        startingBalanceCents: 0,
      );
      expect(remainingBefore, 290000);

      // L'utilisateur déplace manuellement l'échéance au 30 août.
      await repository.updateFixedExpense(
        id: chargeId,
        name: 'Prélèvement X',
        expectedAmountCents: 10000,
        expectedDate: DateTime(2026, 8, 30),
        isRecurring: false,
        isActive: true,
      );

      final after = await repository.loadCurrentCycleData();
      expect(after!.fixedExpenses, isEmpty, reason: '30 août est après la fin du cycle (28 août)');
      final totalAfter =
          _calculationService.calculateTotalFixedExpenses(after.fixedExpenses.map(fixedExpenseFromRow).toList());
      expect(totalAfter, 0);
      final remainingAfter = _calculationService.calculateRealRemaining(
        incomes: after.incomes.map(incomeFromRow).toList(),
        fixedExpenses: after.fixedExpenses.map(fixedExpenseFromRow).toList(),
        variableExpenses: const [],
        savings: const [],
        startingBalanceCents: 0,
      );
      expect(remainingAfter, remainingBefore + 10000); // +100 € immédiatement

      // Une seule ligne existe toujours : jamais comptée deux fois (ni sous
      // l'ancienne date, ni sous la nouvelle).
      final allRows = await (db.select(db.fixedExpenses)..where((e) => e.id.equals(chargeId))).get();
      expect(allRows, hasLength(1));
      expect(allRows.single.expectedDate, DateTime(2026, 8, 30));
    });

    test('cas inverse : charge hors cycle ramenée manuellement dans le cycle -> ajoutée au calcul', () async {
      final cycleId = await repository.createCycle(
        startDate: DateTime(2026, 7, 28),
        endDate: DateTime(2026, 8, 28),
        declaredBankBalanceCents: 0,
      );
      final chargeId = await repository.createFixedExpense(
        cycleId: cycleId,
        name: 'Prélèvement X',
        expectedAmountCents: 10000,
        expectedDate: DateTime(2026, 8, 30), // hors cycle dès la création
      );

      final before = await repository.loadCurrentCycleData();
      expect(before!.fixedExpenses, isEmpty);

      // L'utilisateur ramène manuellement l'échéance au 25 août.
      await repository.updateFixedExpense(
        id: chargeId,
        name: 'Prélèvement X',
        expectedAmountCents: 10000,
        expectedDate: DateTime(2026, 8, 25),
        isRecurring: false,
        isActive: true,
      );

      final after = await repository.loadCurrentCycleData();
      expect(after!.fixedExpenses, hasLength(1));
      final total =
          _calculationService.calculateTotalFixedExpenses(after.fixedExpenses.map(fixedExpenseFromRow).toList());
      expect(total, 10000);
    });

    test(
        'passage réel au cycle suivant : une charge déplacée en dehors du cycle A '
        'apparaît dans le cycle B une fois celui-ci créé, sans jamais être réaffectée manuellement', () async {
      final cycleAId = await repository.createCycle(startDate: DateTime(2026, 7, 28), endDate: DateTime(2026, 8, 28));
      final chargeId = await repository.createFixedExpense(
        cycleId: cycleAId,
        name: 'Prélèvement X',
        expectedAmountCents: 10000,
        expectedDate: DateTime(2026, 8, 26),
      );
      expect((await repository.loadCurrentCycleData())!.fixedExpenses, hasLength(1));

      await repository.updateFixedExpense(
        id: chargeId,
        name: 'Prélèvement X',
        expectedAmountCents: 10000,
        expectedDate: DateTime(2026, 8, 30),
        isRecurring: false,
        isActive: true,
      );
      expect((await repository.loadCurrentCycleData())!.fixedExpenses, isEmpty);

      await repository.closeCycle(cycleAId);
      await repository.createCycle(startDate: DateTime(2026, 8, 29), endDate: DateTime(2026, 9, 28));

      // Le cycle B est maintenant le cycle courant : la charge (toujours
      // cycleId = A, mais dont la date tombe dans B) y apparaît, sans
      // qu'aucune réaffectation explicite de cycleId n'ait jamais eu lieu.
      final currentData = await repository.loadCurrentCycleData();
      expect(currentData!.fixedExpenses, hasLength(1));
      expect(currentData.fixedExpenses.single.id, chargeId);
      expect(currentData.fixedExpenses.single.cycleId, cycleAId);
    });

    test('modifier une occurrence récurrente ne modifie jamais toute la série', () async {
      final firstId = await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
      await repository.createFixedExpense(
        cycleId: firstId,
        name: 'Loyer',
        expectedAmountCents: 90000,
        expectedDate: DateTime(2026, 1, 5),
        isRecurring: true,
      );
      await repository.closeCycle(firstId);

      final secondId = await repository.createCycle(
        startDate: DateTime(2026, 2, 1),
        endDate: DateTime(2026, 2, 28),
        copyRecurringFromCycleId: firstId,
      );
      final secondOccurrence = (await repository.loadCurrentCycleData())!.fixedExpenses.single;
      expect(secondOccurrence.expectedAmountCents, 90000);

      // L'utilisateur corrige exceptionnellement CETTE échéance à 95000 —
      // ne doit jamais changer le modèle ni les échéances futures.
      await repository.updateFixedExpense(
        id: secondOccurrence.id,
        name: 'Loyer',
        expectedAmountCents: 95000,
        expectedDate: secondOccurrence.expectedDate,
        isRecurring: true,
        isActive: true,
      );

      final updated = await (db.select(db.fixedExpenses)..where((e) => e.id.equals(secondOccurrence.id))).getSingle();
      expect(updated.expectedAmountCents, 95000);

      final template = await repository.loadTemplate(updated.templateId!);
      expect(template!.defaultAmountCents, 90000, reason: 'le modèle ne doit jamais être modifié silencieusement');

      await repository.closeCycle(secondId);
      await repository.createCycle(
        startDate: DateTime(2026, 3, 1),
        endDate: DateTime(2026, 3, 31),
        copyRecurringFromCycleId: secondId,
      );
      final thirdOccurrence = (await repository.loadCurrentCycleData())!.fixedExpenses.single;
      expect(thirdOccurrence.expectedAmountCents, 90000, reason: 'la série continue avec le montant du modèle');
    });
  });
}
