import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:budgetpilot/data/local/cycle_repository.dart';
import 'package:budgetpilot/data/local/database.dart';

/// Vérifie qu'une base existante en schéma v1 (avant l'ajout de la colonne
/// `BudgetCycles.name` en v2) migre vers v2 sans perte de données, en
/// utilisant la vraie stratégie de migration de [AppDatabase] (pas de
/// destructiveMigration, jamais de suppression de base).
void main() {
  test('migration v1 -> v2 ne perd aucune donnée existante', () async {
    final tempDir = await Directory.systemTemp.createTemp('budgetpilot_migration_test');
    final dbFile = File('${tempDir.path}/budgetpilot.sqlite');
    addTearDown(() => tempDir.delete(recursive: true));

    // 1. Simuler une base existante en schéma v1 : on crée la base réelle
    // (v2), on retire la colonne `name` pour revenir à la forme v1, puis on
    // force le marqueur de version SQLite à 1 — reproduisant fidèlement
    // l'état d'un appareil qui aurait installé une version antérieure de
    // l'app avant la migration ayant introduit cette colonne.
    var db = AppDatabase.forTesting(NativeDatabase(dbFile));
    var repository = CycleRepository(db);

    final cycleId = await repository.createCycle(
      startDate: DateTime(2025, 1, 1),
      endDate: DateTime(2025, 1, 31),
      declaredBankBalanceCents: 42000,
    );
    final incomeId = await repository.createIncome(
      cycleId: cycleId,
      name: 'Salaire',
      expectedAmountCents: 200000,
      expectedDate: DateTime(2025, 1, 1),
    );
    final chargeId = await repository.createFixedExpense(
      cycleId: cycleId,
      name: 'Loyer',
      expectedAmountCents: 70000,
      expectedDate: DateTime(2025, 1, 5),
    );

    await db.customStatement('ALTER TABLE budget_cycles DROP COLUMN name');
    await db.customStatement('PRAGMA user_version = 1');
    await db.close();

    // 2. Rouvrir avec AppDatabase (schemaVersion 2) : Drift doit exécuter
    // automatiquement migration.onUpgrade(m, 1, 2), qui ajoute la colonne
    // `name` sans jamais supprimer la base ni ses tables.
    db = AppDatabase.forTesting(NativeDatabase(dbFile));
    repository = CycleRepository(db);

    final data = await repository.loadCurrentCycleData();
    expect(data, isNotNull, reason: 'le cycle doit toujours exister après migration');
    expect(data!.cycle.id, cycleId);
    expect(data.cycle.name, isNull, reason: 'colonne ré-ajoutée, valeur par défaut null');
    expect(data.cycle.declaredBankBalanceCents, 42000);
    expect(data.incomes.singleWhere((i) => i.id == incomeId).name, 'Salaire');
    expect(data.incomes.singleWhere((i) => i.id == incomeId).expectedAmountCents, 200000);
    expect(data.fixedExpenses.singleWhere((e) => e.id == chargeId).name, 'Loyer');
    expect(data.fixedExpenses.singleWhere((e) => e.id == chargeId).expectedAmountCents, 70000);

    final versionRow = await db.customSelect('PRAGMA user_version').getSingle();
    expect(versionRow.data['user_version'], 2, reason: 'le marqueur de version doit être mis à jour');

    await db.close();
  });
}
