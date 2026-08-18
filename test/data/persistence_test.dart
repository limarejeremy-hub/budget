import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:budgetpilot/data/local/converters/entity_mappers.dart';
import 'package:budgetpilot/data/local/cycle_repository.dart';
import 'package:budgetpilot/data/local/database.dart';
import 'package:budgetpilot/domain/calculations/dashboard_view_builder.dart';

/// Vérifie que les données survivent réellement à une fermeture puis
/// réouverture de la base — c'est le mécanisme dont dépend la conservation
/// des données lors d'une mise à jour de l'APK (même fichier SQLite, même
/// répertoire de données applicatives).
void main() {
  test('les données existent toujours après fermeture puis réouverture de la base', () async {
    final tempDir = await Directory.systemTemp.createTemp('budgetpilot_persistence_test');
    final dbFile = File('${tempDir.path}/budgetpilot.sqlite');
    addTearDown(() => tempDir.delete(recursive: true));

    // 1. Créer une base, insérer un cycle, un revenu et une charge.
    var db = AppDatabase.forTesting(NativeDatabase(dbFile));
    var repository = CycleRepository(db);

    final cycleId = await repository.createCycle(
      startDate: DateTime(2026, 7, 27),
      endDate: DateTime(2026, 8, 26),
      name: 'Cycle de test',
      declaredBankBalanceCents: 150000,
    );
    await repository.createIncome(
      cycleId: cycleId,
      name: 'Salaire',
      expectedAmountCents: 250000,
      expectedDate: DateTime(2026, 7, 27),
    );
    await repository.createFixedExpense(
      cycleId: cycleId,
      name: 'Loyer',
      expectedAmountCents: 85000,
      expectedDate: DateTime(2026, 8, 1),
    );

    // 2. Fermer la base — simule la fin du processus de l'application.
    await db.close();

    // 3. La rouvrir sur le même fichier — simule un redémarrage après une
    // mise à jour de l'APK (même applicationId, même nom de fichier SQLite).
    db = AppDatabase.forTesting(NativeDatabase(dbFile));
    repository = CycleRepository(db);

    // 4. Vérifier que toutes les données existent toujours.
    final data = await repository.loadCurrentCycleData();
    expect(data, isNotNull);
    expect(data!.cycle.name, 'Cycle de test');
    expect(data.cycle.declaredBankBalanceCents, 150000);
    expect(data.incomes, hasLength(1));
    expect(data.incomes.single.name, 'Salaire');
    expect(data.incomes.single.expectedAmountCents, 250000);
    expect(data.fixedExpenses, hasLength(1));
    expect(data.fixedExpenses.single.name, 'Loyer');
    expect(data.fixedExpenses.single.expectedAmountCents, 85000);

    await db.close();
  });

  test('redémarrage de l\'application : le solde de départ reste intégré au calcul de l\'argent libre', () async {
    final tempDir = await Directory.systemTemp.createTemp('budgetpilot_persistence_restart_test');
    final dbFile = File('${tempDir.path}/budgetpilot.sqlite');
    addTearDown(() => tempDir.delete(recursive: true));

    // 1. Créer une base avec un solde bancaire déclaré négatif et un revenu.
    var db = AppDatabase.forTesting(NativeDatabase(dbFile));
    var repository = CycleRepository(db);

    await repository.createCycle(
      startDate: DateTime(2026, 7, 27),
      endDate: DateTime(2026, 8, 26),
      name: 'Cycle de test',
      declaredBankBalanceCents: -58600,
    );
    final cycleData = await repository.loadCurrentCycleData();
    await repository.createIncome(
      cycleId: cycleData!.cycle.id,
      name: 'Salaire',
      expectedAmountCents: 424300,
      expectedDate: DateTime(2026, 7, 27),
    );

    // 2. Fermer puis rouvrir la base — simule un redémarrage de l'application.
    await db.close();
    db = AppDatabase.forTesting(NativeDatabase(dbFile));
    repository = CycleRepository(db);

    // 3. Recalculer via le même chemin que l'application (DashboardViewBuilder)
    // et vérifier que le solde de départ est toujours intégré à l'argent libre.
    final raw = await repository.loadCurrentCycleData();
    expect(raw, isNotNull);
    expect(raw!.cycle.declaredBankBalanceCents, -58600);

    const builder = DashboardViewBuilder();
    final dashboard = builder.build(
      cycleId: raw.cycle.id,
      cycleStart: raw.cycle.startDate,
      cycleEnd: raw.cycle.endDate,
      incomes: raw.incomes.map(incomeFromRow).toList(),
      fixedExpenses: raw.fixedExpenses.map(fixedExpenseFromRow).toList(),
      variableExpenses: raw.variableExpenses.map(variableExpenseFromRow).toList(),
      savings: raw.savings.map(savingFromRow).toList(),
      declaredBankBalanceCents: raw.cycle.declaredBankBalanceCents,
    );

    // Cas de référence : -58600 + 424300 = 365700.
    expect(dashboard.realRemainingCents, 365700);

    await db.close();
  });

  test('la version de schéma Drift actuelle est bien celle attendue (8)', () {
    // Ce test échoue volontairement si quelqu'un bumpe schemaVersion sans
    // ajouter la branche de migration correspondante dans AppDatabase.migration
    // — rappel explicite à mettre à jour ce test et la doc de persistance.
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    expect(db.schemaVersion, 8);
    db.close();
  });
}
