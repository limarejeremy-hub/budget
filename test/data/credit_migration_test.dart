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

    // 2. Rouvrir avec AppDatabase (schemaVersion 4) : Drift doit exécuter
    // automatiquement migration.onUpgrade(m, 2, 4), qui recrée la table
    // credits — déjà avec les colonnes organisme/colorValue/iconCodePoint
    // puisque `createTable` matérialise la définition Dart actuelle — sans
    // jamais toucher aux autres tables.
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
      organisme: 'Crédit Agricole',
    );
    expect(creditId, greaterThan(0));

    final versionRow = await db.customSelect('PRAGMA user_version').getSingle();
    expect(versionRow.data['user_version'], 4, reason: 'le marqueur de version doit être mis à jour');

    await db.close();
  });

  test('migration v3 -> v4 ajoute organisme/couleur/icône sans perdre les crédits existants', () async {
    final tempDir = await Directory.systemTemp.createTemp('budgetpilot_credit_migration_v4_test');
    final dbFile = File('${tempDir.path}/budgetpilot.sqlite');
    addTearDown(() => tempDir.delete(recursive: true));

    // 1. Simuler une base existante en schéma v3 : on crée la vraie base
    // (v4), on retire les 3 nouvelles colonnes pour revenir à la forme v3,
    // puis on force le marqueur de version SQLite à 3.
    var db = AppDatabase.forTesting(NativeDatabase(dbFile));
    var repository = CycleRepository(db);

    final creditId = await repository.createCredit(
      name: 'Voiture',
      initialAmountCents: 1500000,
      remainingCapitalCents: 900000,
      monthlyPaymentCents: 25000,
      expectedEndDate: DateTime(2029, 1, 1),
      remainingInstallments: 36,
    );

    await db.customStatement('ALTER TABLE credits DROP COLUMN organisme');
    await db.customStatement('ALTER TABLE credits DROP COLUMN color_value');
    await db.customStatement('ALTER TABLE credits DROP COLUMN icon_code_point');
    await db.customStatement('PRAGMA user_version = 3');
    await db.close();

    // 2. Rouvrir avec AppDatabase (schemaVersion 4) : Drift doit exécuter
    // onUpgrade(m, 3, 4), qui ajoute les 3 colonnes via addColumn (le crédit
    // existant n'est jamais supprimé).
    db = AppDatabase.forTesting(NativeDatabase(dbFile));
    repository = CycleRepository(db);

    final credits = await repository.loadCredits();
    expect(credits, hasLength(1), reason: 'le crédit existant doit survivre à la migration');
    expect(credits.single.id, creditId);
    expect(credits.single.name, 'Voiture');
    expect(credits.single.organisme, isNull, reason: 'colonne ajoutée, valeur par défaut null');
    expect(credits.single.colorValue, isNull);
    expect(credits.single.iconCodePoint, isNull);

    final versionRow = await db.customSelect('PRAGMA user_version').getSingle();
    expect(versionRow.data['user_version'], 4);

    await db.close();
  });
}
