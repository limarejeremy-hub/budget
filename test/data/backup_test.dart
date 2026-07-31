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
    await seedCycle();
    final backup = await repository.exportBackup();

    // Une deuxième saisie, qui ne doit pas survivre au remplacement.
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
}
