import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

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

  Future<int> seedCycle() async {
    final cycleId = await repository.createCycle(
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 1, 31),
      name: 'Cycle export',
      declaredBankBalanceCents: 100000,
    );
    await repository.createIncome(
      cycleId: cycleId,
      name: 'Salaire',
      expectedAmountCents: 200000,
      expectedDate: DateTime(2026, 1, 1),
    );
    await repository.createFixedExpense(
      cycleId: cycleId,
      name: 'Loyer',
      expectedAmountCents: 80000,
      expectedDate: DateTime(2026, 1, 5),
    );
    await repository.createVariableExpense(
      cycleId: cycleId,
      amountCents: 4200,
      date: DateTime(2026, 1, 10),
    );
    await repository.createSaving(
      cycleId: cycleId,
      name: 'Mariage',
      expectedAmountCents: 50000,
      expectedDate: DateTime(2026, 1, 1),
    );
    return cycleId;
  }

  test('exportBackup puis importBackup (fusion) restitue les mêmes données', () async {
    await seedCycle();

    final backup = await repository.exportBackup();
    expect(backup['formatVersion'], backupFormatVersion);
    expect((backup['cycles'] as List), hasLength(1));

    final imported = await repository.importBackup(backup, replaceExisting: false);
    expect(imported, 1);

    final cycles = await repository.watchAllCycles().first;
    expect(cycles, hasLength(2), reason: "fusion : le cycle importé s'ajoute à l'existant");
    expect(cycles.every((c) => c.name == 'Cycle export'), isTrue);
  });

  test('importBackup avec replaceExisting supprime les données existantes avant import', () async {
    final firstCycleId = await seedCycle();
    final backup = await repository.exportBackup();

    // Une deuxième saisie, qui ne doit pas survivre au remplacement — un
    // seul cycle 'ouvert' à la fois (§17), donc le premier est clôturé
    // avant d'en créer un second.
    await repository.closeCycle(firstCycleId);
    await repository.createCycle(startDate: DateTime(2026, 3, 1), endDate: DateTime(2026, 3, 31));

    await repository.importBackup(backup, replaceExisting: true);

    final cycles = await repository.watchAllCycles().first;
    expect(cycles, hasLength(1));
    expect(cycles.single.name, 'Cycle export');

    final data = await repository.loadCurrentCycleData();
    expect(data!.incomes.single.name, 'Salaire');
    expect(data.fixedExpenses.single.name, 'Loyer');
    expect(data.variableExpenses.single.amountCents, 4200);
    expect(data.savings.single.name, 'Mariage');
  });

  test('validateBackup rejette un format de version inconnu', () {
    expect(
      () => repository.validateBackup({'formatVersion': 999, 'cycles': []}),
      throwsA(isA<BackupValidationException>()),
    );
  });

  test('validateBackup rejette un JSON sans champ cycles', () {
    expect(
      () => repository.validateBackup({'formatVersion': backupFormatVersion}),
      throwsA(isA<BackupValidationException>()),
    );
  });

  test('validateBackup rejette une entrée qui n\'est pas un objet JSON', () {
    expect(
      () => repository.validateBackup('pas un objet'),
      throwsA(isA<BackupValidationException>()),
    );
  });

  test('validateBackup rejette un cycle incomplet (sans dates)', () {
    expect(
      () => repository.validateBackup({
        'formatVersion': backupFormatVersion,
        'cycles': [
          {'name': 'Cycle sans dates'},
        ],
      }),
      throwsA(isA<BackupValidationException>()),
    );
  });

  test('un import valide passe validateBackup sans exception', () async {
    await seedCycle();
    final backup = await repository.exportBackup();
    expect(() => repository.validateBackup(backup), returnsNormally);
  });

  test('exportBackup puis importBackup restitue les crédits', () async {
    await seedCycle();
    await repository.createCredit(
      name: 'Voiture',
      initialAmountCents: 1500000,
      remainingCapitalCents: 900000,
      monthlyPaymentCents: 25000,
      annualRatePercent: 3.5,
      expectedEndDate: DateTime(2029, 1, 1),
      remainingInstallments: 36,
      organisme: 'Crédit Agricole',
      colorValue: 0xFF4C8DFF,
      iconCodePoint: 0xe1b1,
    );

    final backup = await repository.exportBackup();
    expect((backup['credits'] as List), hasLength(1));

    // Une nouvelle base "vierge" (simule un nouvel appareil) : on y importe
    // la sauvegarde et on vérifie que le crédit est bien restitué.
    final freshDb = AppDatabase.forTesting(NativeDatabase.memory());
    final freshRepository = CycleRepository(freshDb);
    addTearDown(() => freshDb.close());

    await freshRepository.importBackup(backup, replaceExisting: false);

    final credits = await freshRepository.loadCredits();
    expect(credits, hasLength(1));
    expect(credits.single.name, 'Voiture');
    expect(credits.single.remainingCapitalCents, 900000);
    expect(credits.single.annualRatePercent, 3.5);
    expect(credits.single.organisme, 'Crédit Agricole');
    expect(credits.single.colorValue, 0xFF4C8DFF);
    expect(credits.single.iconCodePoint, 0xe1b1);
  });

  test('importBackup avec replaceExisting supprime aussi les crédits existants', () async {
    await seedCycle();
    final backup = await repository.exportBackup(); // sans crédit

    await repository.createCredit(
      name: 'Crédit qui ne doit pas survivre',
      initialAmountCents: 100000,
      remainingCapitalCents: 100000,
      monthlyPaymentCents: 10000,
      expectedEndDate: DateTime(2027, 1, 1),
      remainingInstallments: 10,
    );

    await repository.importBackup(backup, replaceExisting: true);

    expect(await repository.loadCredits(), isEmpty);
  });

  test('une sauvegarde ancienne (sans champ credits) importe toujours correctement', () async {
    // Format tel qu'exporté par une version de BudgetPilot antérieure à la
    // V0.7, avant l'ajout des crédits — aucun champ 'credits' du tout.
    final legacyBackup = {
      'formatVersion': backupFormatVersion,
      'exportedAt': DateTime(2026, 1, 1).toIso8601String(),
      'cycles': [
        {
          'name': 'Cycle ancien',
          'startDate': DateTime(2026, 1, 1).toIso8601String(),
          'endDate': DateTime(2026, 1, 31).toIso8601String(),
          'status': 'ouvert',
          'declaredBankBalanceCents': null,
          'incomes': <Map<String, dynamic>>[],
          'fixedExpenses': <Map<String, dynamic>>[],
          'variableExpenses': <Map<String, dynamic>>[],
          'savings': <Map<String, dynamic>>[],
        },
      ],
    };

    expect(() => repository.validateBackup(legacyBackup), returnsNormally);

    final imported = await repository.importBackup(legacyBackup, replaceExisting: false);
    expect(imported, 1);
    expect(await repository.loadCredits(), isEmpty);
  });

  test('une sauvegarde V0.7 (crédits sans organisme/couleur/icône) importe toujours correctement', () async {
    // Format tel qu'exporté juste après l'introduction du module Crédits,
    // avant l'ajout des champs organisme/colorValue/iconCodePoint — ces
    // clés sont absentes de chaque entrée 'credits', pas seulement nulles.
    final legacyBackup = {
      'formatVersion': backupFormatVersion,
      'exportedAt': DateTime(2026, 1, 1).toIso8601String(),
      'cycles': <Map<String, dynamic>>[],
      'credits': [
        {
          'name': 'Voiture',
          'initialAmountCents': 1500000,
          'remainingCapitalCents': 900000,
          'monthlyPaymentCents': 25000,
          'annualRatePercent': null,
          'startDate': null,
          'expectedEndDate': DateTime(2029, 1, 1).toIso8601String(),
          'remainingInstallments': 36,
          'creditType': null,
          'earlyRepaymentAllowed': true,
          'earlyRepaymentPenaltyCents': null,
          'notes': null,
          'isActive': true,
          // Pas de 'organisme' / 'colorValue' / 'iconCodePoint' du tout.
        },
      ],
    };

    expect(() => repository.validateBackup(legacyBackup), returnsNormally);

    await repository.importBackup(legacyBackup, replaceExisting: false);
    final credit = (await repository.loadCredits()).single;
    expect(credit.name, 'Voiture');
    expect(credit.organisme, isNull);
    expect(credit.colorValue, isNull);
    expect(credit.iconCodePoint, isNull);
  });
}
