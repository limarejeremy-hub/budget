import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:budgetpilot/data/local/cycle_repository.dart';
import 'package:budgetpilot/data/local/database.dart';

/// Vérifie qu'une base existante en schéma v8 (avant l'ajout de la colonne
/// `FixedExpenses.deferredToNextCycle` en v9 — "Affectation manuelle d'une
/// charge au prochain cycle") migre vers v9 sans perte de données, en
/// utilisant la vraie stratégie de migration de [AppDatabase] — additive
/// uniquement, jamais de destructiveMigration.
void main() {
  test('migration v8 -> v9 ajoute deferredToNextCycle sans perdre les charges existantes', () async {
    final tempDir = await Directory.systemTemp.createTemp('budgetpilot_deferred_charge_migration_test');
    final dbFile = File('${tempDir.path}/budgetpilot.sqlite');
    addTearDown(() => tempDir.delete(recursive: true));

    // 1. Simuler une base existante en schéma v8 : on crée la vraie base
    // (v9, avec la colonne deferred_to_next_cycle), on retire cette colonne
    // pour revenir à la forme v8, puis on force le marqueur de version
    // SQLite à 8 — reproduisant fidèlement l'état d'un appareil qui aurait
    // installé une version antérieure de l'app, avec ses VRAIES données.
    var db = AppDatabase.forTesting(NativeDatabase(dbFile));
    var repository = CycleRepository(db);

    final cycleId = await repository.createCycle(
      startDate: DateTime(2026, 7, 28),
      endDate: DateTime(2026, 8, 28),
      name: 'Cycle existant',
    );
    final chargeId = await repository.createFixedExpense(
      cycleId: cycleId,
      name: 'EDF',
      expectedAmountCents: 18000,
      expectedDate: DateTime(2026, 8, 26),
    );

    await db.customStatement('ALTER TABLE fixed_expenses DROP COLUMN deferred_to_next_cycle');
    await db.customStatement('PRAGMA user_version = 8');
    await db.close();

    // 2. Rouvrir avec AppDatabase (schemaVersion 9) : Drift doit exécuter
    // automatiquement migration.onUpgrade(m, 8, 9), qui ajoute la colonne
    // sans jamais toucher aux lignes existantes.
    db = AppDatabase.forTesting(NativeDatabase(dbFile));
    repository = CycleRepository(db);

    final data = await repository.loadCurrentCycleData();
    expect(data, isNotNull, reason: 'le cycle doit toujours exister après migration');
    expect(data!.cycle.name, 'Cycle existant');
    expect(data.fixedExpenses.single.name, 'EDF');
    expect(data.fixedExpenses.single.expectedAmountCents, 18000);
    expect(data.fixedExpenses.single.deferredToNextCycle, isFalse,
        reason: 'valeur par défaut pour toute charge existante : son affectation actuelle ne change pas');

    // La nouvelle fonctionnalité est utilisable immédiatement après migration.
    await repository.deferFixedExpenseToNextCycle(chargeId);
    final afterDefer = await (db.select(db.fixedExpenses)..where((e) => e.id.equals(chargeId))).getSingle();
    expect(afterDefer.deferredToNextCycle, isTrue);

    final versionRow = await db.customSelect('PRAGMA user_version').getSingle();
    expect(versionRow.data['user_version'], 9, reason: 'le marqueur de version doit être mis à jour');

    await db.close();
  });
}
