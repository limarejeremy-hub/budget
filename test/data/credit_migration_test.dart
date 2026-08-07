import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:budgetpilot/core/constants/app_constants.dart';
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

    await db.customStatement('ALTER TABLE fixed_expenses DROP COLUMN linked_credit_id');
    await db.customStatement('DROP TABLE notification_logs');
    await db.customStatement('DROP TABLE credits');
    await db.customStatement('PRAGMA user_version = 2');
    await db.close();

    // 2. Rouvrir avec AppDatabase (schemaVersion 6) : Drift doit exécuter
    // automatiquement migration.onUpgrade(m, 2, 5), qui recrée la table
    // credits — déjà avec toutes les colonnes actuelles puisque
    // `createTable` matérialise la définition Dart actuelle — sans jamais
    // toucher aux autres tables.
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
    expect(versionRow.data['user_version'], 6, reason: 'le marqueur de version doit être mis à jour');

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
    await db.customStatement('ALTER TABLE credits DROP COLUMN payment_day_of_month');
    await db.customStatement('ALTER TABLE credits DROP COLUMN insurance_cents');
    await db.customStatement('ALTER TABLE fixed_expenses DROP COLUMN linked_credit_id');
    await db.customStatement('DROP TABLE notification_logs');
    await db.customStatement('PRAGMA user_version = 3');
    await db.close();

    // 2. Rouvrir avec AppDatabase (schemaVersion 6) : Drift doit exécuter
    // onUpgrade(m, 3, 5), qui ajoute les 3 colonnes de la v4 via addColumn
    // (le crédit existant n'est jamais supprimé), puis enchaîne vers v5.
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
    expect(versionRow.data['user_version'], 6);

    await db.close();
  });

  test(
      'migration v4 -> v5 ajoute jour de prélèvement/assurance/lien de charge '
      'et relie automatiquement les charges "Crédit" existantes', () async {
    final tempDir = await Directory.systemTemp.createTemp('budgetpilot_credit_migration_v5_test');
    final dbFile = File('${tempDir.path}/budgetpilot.sqlite');
    addTearDown(() => tempDir.delete(recursive: true));

    // 1. Simuler une base existante en schéma v4 (V0.8) : un crédit "Voiture"
    // et, comme avant la V0.9, une charge fixe manuelle de catégorie
    // "Crédit" et de même nom — c'est exactement le doublon que la V0.9
    // doit réconcilier automatiquement, sans perte de données.
    var db = AppDatabase.forTesting(NativeDatabase(dbFile));
    var repository = CycleRepository(db);

    final cycleId = await repository.createCycle(
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 1, 31),
    );
    final categories = await (db.select(db.categories)
          ..where((c) => c.name.equals('Crédit') & c.type.equals('fixed_expense')))
        .getSingle();
    final chargeId = await repository.createFixedExpense(
      cycleId: cycleId,
      name: 'Voiture',
      expectedAmountCents: 25000,
      expectedDate: DateTime(2026, 1, 5),
      categoryId: categories.id,
    );
    // Insertion directe (pas via repository.createCredit) : on simule ici
    // une base V0.8, avant que la création d'un crédit ne génère
    // automatiquement sa charge liée — la charge et le crédit ci-dessus
    // existent bien indépendamment, exactement le doublon historique que
    // la réconciliation V0.9 doit résoudre.
    final creditId = await db.into(db.credits).insert(CreditsCompanion.insert(
          name: 'Voiture',
          initialAmountCents: 1500000,
          remainingCapitalCents: 900000,
          monthlyPaymentCents: 25000,
          expectedEndDate: DateTime(2029, 1, 1),
          remainingInstallments: 36,
        ));

    await db.customStatement('ALTER TABLE credits DROP COLUMN payment_day_of_month');
    await db.customStatement('ALTER TABLE credits DROP COLUMN insurance_cents');
    await db.customStatement('ALTER TABLE fixed_expenses DROP COLUMN linked_credit_id');
    await db.customStatement('DROP TABLE notification_logs');
    await db.customStatement('PRAGMA user_version = 4');
    await db.close();

    // 2. Rouvrir avec AppDatabase (schemaVersion 6) : Drift doit exécuter
    // onUpgrade(m, 4, 5), qui ajoute les colonnes manquantes, recrée
    // notification_logs, et relie automatiquement la charge "Voiture"
    // (catégorie Crédit) au crédit "Voiture" par correspondance de nom.
    db = AppDatabase.forTesting(NativeDatabase(dbFile));
    repository = CycleRepository(db);

    final credits = await repository.loadCredits();
    expect(credits, hasLength(1), reason: 'le crédit existant doit survivre à la migration');
    expect(credits.single.id, creditId);
    expect(credits.single.paymentDayOfMonth, isNull);
    expect(credits.single.insuranceCents, isNull);

    final data = await repository.loadCurrentCycleData();
    final charge = data!.fixedExpenses.singleWhere((e) => e.id == chargeId);
    expect(charge.linkedCreditId, creditId,
        reason: 'la charge "Crédit" existante doit être reliée au crédit correspondant par son nom');

    final notificationLogs = await repository.loadNotificationLogs();
    expect(notificationLogs, isEmpty, reason: 'la table notification_logs doit être utilisable, vide');

    final versionRow = await db.customSelect('PRAGMA user_version').getSingle();
    expect(versionRow.data['user_version'], 6);

    await db.close();
  });

  test('migration v5 -> v6 ajoute la table projects sans perdre les crédits ni les charges existants', () async {
    final tempDir = await Directory.systemTemp.createTemp('budgetpilot_credit_migration_test');
    final dbFile = File('${tempDir.path}/budgetpilot.sqlite');
    addTearDown(() => tempDir.delete(recursive: true));

    var db = AppDatabase.forTesting(NativeDatabase(dbFile));
    var repository = CycleRepository(db);

    final cycleId = await repository.createCycle(
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 1, 31),
    );
    final creditId = await repository.createCreditForExistingCharge(
      name: 'Voiture',
      initialAmountCents: 1500000,
      remainingCapitalCents: 900000,
      monthlyPaymentCents: 25000,
      expectedEndDate: DateTime(2029, 1, 1),
      remainingInstallments: 36,
    );
    final chargeId = await repository.createFixedExpense(
      cycleId: cycleId,
      name: 'Loyer',
      expectedAmountCents: 70000,
      expectedDate: DateTime(2026, 1, 5),
    );

    // La table `projects` n'existe pas encore en v5 (V1.0 l'introduit) : on
    // la supprime pour simuler fidèlement un appareil resté sur cette
    // version, `createTable` en v6 la recrée (idempotent, jamais un échec
    // si elle existait déjà).
    await db.customStatement('DROP TABLE projects');
    await db.customStatement('PRAGMA user_version = 5');
    await db.close();

    // Rouvrir avec AppDatabase (schemaVersion 6) : Drift exécute
    // onUpgrade(m, 5, 6), qui crée uniquement la table `projects` — aucune
    // autre donnée n'est touchée.
    db = AppDatabase.forTesting(NativeDatabase(dbFile));
    repository = CycleRepository(db);

    final credits = await repository.loadCredits();
    expect(credits, hasLength(1), reason: 'le crédit existant doit survivre à la migration');
    expect(credits.single.id, creditId);

    final data = await repository.loadCurrentCycleData();
    expect(data!.fixedExpenses.singleWhere((e) => e.id == chargeId).name, 'Loyer');

    expect(await repository.loadProjects(), isEmpty, reason: 'la table projects doit être utilisable, vide');

    final projectId = await repository.createProject(
      name: 'Porsche Boxster',
      category: ProjectCategory.car,
      targetAmountCents: 4000000,
      financingMode: ProjectFinancingMode.mixed,
    );
    expect((await repository.loadProjects()).single.id, projectId);

    final versionRow = await db.customSelect('PRAGMA user_version').getSingle();
    expect(versionRow.data['user_version'], 6);

    await db.close();
  });
}
