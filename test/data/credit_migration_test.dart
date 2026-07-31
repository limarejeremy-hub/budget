import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:budgetpilot/data/local/cycle_repository.dart';
import 'package:budgetpilot/data/local/database.dart';

/// Vérifie qu'une base existante en schéma v2 (avant l'ajout de la table
/// `Credits` en v3) migre vers v3 sans perte de données, en utilisant la
/// vraie stratégie de migration de [AppDatabase] — additive uniquement,
/// jamais de destructiveMigration.
void main() {
  test('migration v2 -> v3 crée la table credits sans perdre les données existantes', () async {
    final tempDir = await Directory.systemTemp.createTemp('budgetpilot_credit_migration_test');
    final dbFile = File('${tempDir.path}/budgetpilot.sqlite');
    addTearDown(() => tempDir.delete(recursive: true));

    // 1. Simuler une base existante en schéma v2 : on crée la vraie base
    // (v3, avec la table credits), on la supprime pour revenir à la forme
    // v2, puis on force le marqueur de version SQLite à 2.
    var db = AppDatabase.forTesting(NativeDatabase(dbFile));
    var repository = CycleRepository(db);

    final cycleId = await repository.createCycle(
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 1, 31),
      name: 'Cycle existant',
    );
    await repository.createIncome(
      cycleId: cycleId,
      name: 'Salaire',
      expectedAmountCents: 250000,
      expectedDate: DateTime(2026, 1, 1),
    );

    await db.customStatement('DROP TABLE credits');
    await db.customStatement('PRAGMA user_version = 2');
    await db.close();

    // 2. Rouvrir avec AppDatabase (schemaVersion 3) : Drift doit exécuter
    // automatiquement migration.onUpgrade(m, 2, 3), qui recrée la table
    // credits sans jamais toucher aux autres tables.
    db = AppDatabase.forTesting(NativeDatabase(dbFile));
    repository = CycleRepository(db);

    final data = await repository.loadCurrentCycleData();
    expect(data, isNotNull, reason: 'le cycle doit toujours exister après migration');
    expect(data!.cycle.name, 'Cycle existant');
    expect(data.incomes.single.name, 'Salaire');

    // La table credits existe de nouveau et est utilisable, vide.
    final credits = await repository.loadCredits();
    expect(credits, isEmpty);

    final creditId = await repository.createCredit(
      name: 'Voiture',
      initialAmountCents: 1500000,
      remainingCapitalCents: 900000,
      monthlyPaymentCents: 25000,
      expectedEndDate: DateTime(2029, 1, 1),
      remainingInstallments: 36,
    );
    expect(creditId, greaterThan(0));

    final versionRow = await db.customSelect('PRAGMA user_version').getSingle();
    expect(versionRow.data['user_version'], 3, reason: 'le marqueur de version doit être mis à jour');

    await db.close();
  });
}
