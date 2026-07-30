import 'package:drift/drift.dart';

import 'database.dart';

/// Peuple la base avec les données de démonstration du cahier des charges.
/// Ne s'exécute JAMAIS automatiquement : appelée uniquement depuis l'action
/// explicite "Charger les données de démonstration", pour ne jamais être
/// confondue avec de vraies finances.
class DemoDataSeeder {
  final AppDatabase db;
  const DemoDataSeeder(this.db);

  Future<void> seedIfEmpty() async {
    final existingCycles = await db.select(db.budgetCycles).get();
    if (existingCycles.isNotEmpty) return;

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 27).isAfter(now)
        ? DateTime(now.year, now.month - 1, 27)
        : DateTime(now.year, now.month, 27);
    final end = DateTime(start.year, start.month + 1, 26);

    final cycleId = await db.into(db.budgetCycles).insert(
          BudgetCyclesCompanion.insert(startDate: start, endDate: end),
        );

    final salaireCat = await db.into(db.categories).insert(
          CategoriesCompanion.insert(name: 'Salaire', type: 'income'),
        );
    final logementCat = await db.into(db.categories).insert(
          CategoriesCompanion.insert(name: 'Logement', type: 'fixed_expense'),
        );
    final vehiculeCat = await db.into(db.categories).insert(
          CategoriesCompanion.insert(name: 'Véhicule', type: 'fixed_expense'),
        );
    final assuranceCat = await db.into(db.categories).insert(
          CategoriesCompanion.insert(name: 'Assurance', type: 'fixed_expense'),
        );
    final energieCat = await db.into(db.categories).insert(
          CategoriesCompanion.insert(name: 'Énergie', type: 'fixed_expense'),
        );
    final telecomCat = await db.into(db.categories).insert(
          CategoriesCompanion.insert(name: 'Télécommunications', type: 'fixed_expense'),
        );
    final autreFixedCat = await db.into(db.categories).insert(
          CategoriesCompanion.insert(name: 'Autre', type: 'fixed_expense'),
        );
    final coursesCat = await db.into(db.categories).insert(
          CategoriesCompanion.insert(name: 'Courses', type: 'variable_expense'),
        );
    final carburantCat = await db.into(db.categories).insert(
          CategoriesCompanion.insert(name: 'Carburant', type: 'variable_expense'),
        );
    final restoCat = await db.into(db.categories).insert(
          CategoriesCompanion.insert(name: 'Restaurant', type: 'variable_expense'),
        );
    final achatsCat = await db.into(db.categories).insert(
          CategoriesCompanion.insert(name: 'Achats en ligne', type: 'variable_expense'),
        );

    await db.into(db.incomes).insert(IncomesCompanion.insert(
          cycleId: cycleId,
          name: 'Jeremy',
          expectedAmountCents: 245000,
          expectedDate: start,
          categoryId: Value(salaireCat),
        ));
    await db.into(db.incomes).insert(IncomesCompanion.insert(
          cycleId: cycleId,
          name: 'Conjointe',
          expectedAmountCents: 270000,
          expectedDate: start,
          categoryId: Value(salaireCat),
        ));

    // Dates échelonnées sur le cycle, pas toutes au jour 1.
    final charges = <(String, int, int, int)>[
      // (nom, montant en centimes, catégorie, décalage en jours depuis le début du cycle)
      ('Crédit maison', 85000, logementCat, 3),
      ('Voiture 1', 28000, vehiculeCat, 6),
      ('Voiture 2', 13000, vehiculeCat, 6),
      ('Assurances', 25000, assuranceCat, 10),
      ('Électricité', 18000, energieCat, 14),
      ('Internet et téléphones', 12000, telecomCat, 18),
      ('Autres charges', 64000, autreFixedCat, 22),
    ];
    for (final (name, amountCents, catId, offsetDays) in charges) {
      await db.into(db.fixedExpenses).insert(FixedExpensesCompanion.insert(
            cycleId: cycleId,
            name: name,
            expectedAmountCents: amountCents,
            expectedDate: start.add(Duration(days: offsetDays)),
            categoryId: Value(catId),
          ));
    }

    await db.into(db.savings).insert(SavingsCompanion.insert(
          cycleId: cycleId,
          name: 'Mariage',
          expectedAmountCents: 80000,
          expectedDate: start,
        ));

    final variables = <(String, int, int)>[
      ('Courses', 42000, coursesCat),
      ('Carburant', 18000, carburantCat),
      ('Restaurant', 4500, restoCat),
      ('Amazon', 3200, achatsCat),
    ];
    for (final (name, amountCents, catId) in variables) {
      await db.into(db.variableExpenses).insert(VariableExpensesCompanion.insert(
            cycleId: cycleId,
            amountCents: amountCents,
            date: now,
            name: Value(name),
            categoryId: Value(catId),
          ));
    }

    await db.into(db.appSettingsTable).insert(const AppSettingsTableCompanion());
  }

  Future<void> clearDemoData() async {
    await db.delete(db.variableExpenses).go();
    await db.delete(db.savings).go();
    await db.delete(db.fixedExpenses).go();
    await db.delete(db.incomes).go();
    await db.delete(db.budgetCycles).go();
    await db.delete(db.categories).go();
    await db.delete(db.appSettingsTable).go();
  }
}
