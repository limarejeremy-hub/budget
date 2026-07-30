import 'package:drift/drift.dart';

import '../../core/constants/default_categories.dart';
import 'database.dart';

class CycleDashboardRawData {
  final BudgetCycle cycle;
  final List<Income> incomes;
  final List<FixedExpense> fixedExpenses;
  final List<VariableExpense> variableExpenses;
  final List<Saving> savings;

  const CycleDashboardRawData({
    required this.cycle,
    required this.incomes,
    required this.fixedExpenses,
    required this.variableExpenses,
    required this.savings,
  });
}

/// Requêtes Drift pour charger le cycle courant, ses données associées, et
/// la création / modification / suppression des saisies (revenus, charges
/// fixes, dépenses variables, épargnes) et des cycles.
class CycleRepository {
  final AppDatabase db;
  const CycleRepository(this.db);

  Future<BudgetCycle?> _fetchCurrentCycle() {
    return (db.select(db.budgetCycles)
          ..where((c) => c.status.equals('ouvert'))
          ..orderBy([(c) => OrderingTerm.desc(c.startDate)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<CycleDashboardRawData?> loadCurrentCycleData() async {
    final cycle = await _fetchCurrentCycle();
    if (cycle == null) return null;

    final incomes = await (db.select(db.incomes)..where((i) => i.cycleId.equals(cycle.id))).get();
    final fixedExpenses =
        await (db.select(db.fixedExpenses)..where((e) => e.cycleId.equals(cycle.id))).get();
    final variableExpenses =
        await (db.select(db.variableExpenses)..where((e) => e.cycleId.equals(cycle.id))).get();
    final savings = await (db.select(db.savings)..where((s) => s.cycleId.equals(cycle.id))).get();

    return CycleDashboardRawData(
      cycle: cycle,
      incomes: incomes,
      fixedExpenses: fixedExpenses,
      variableExpenses: variableExpenses,
      savings: savings,
    );
  }

  /// Flux réactif : se réémet dès qu'une des tables concernées change.
  Stream<CycleDashboardRawData?> watchCurrentCycleData() async* {
    yield await loadCurrentCycleData();
    yield* db
        .tableUpdates(TableUpdateQuery.onAllTables([
          db.budgetCycles,
          db.incomes,
          db.fixedExpenses,
          db.variableExpenses,
          db.savings,
        ]))
        .asyncMap((_) => loadCurrentCycleData());
  }

  /// Tous les cycles (courant compris), du plus récent au plus ancien.
  Stream<List<BudgetCycle>> watchAllCycles() {
    return (db.select(db.budgetCycles)..orderBy([(c) => OrderingTerm.desc(c.startDate)]))
        .watch();
  }

  // ---------------------------------------------------------------------
  // Catégories
  // ---------------------------------------------------------------------

  /// Peuple les catégories par défaut si la table est vide. Idempotent :
  /// peut être appelée à chaque création de cycle sans risque de doublon.
  Future<void> ensureDefaultCategories() async {
    final existing = await db.select(db.categories).get();
    if (existing.isNotEmpty) return;

    final all = <(String, String, String)>[
      ...defaultIncomeCategories,
      ...defaultFixedCategories,
      ...defaultVariableCategories,
      ...defaultSavingCategories,
    ];

    await db.batch((batch) {
      batch.insertAll(db.categories, [
        for (final (name, type, icon) in all)
          CategoriesCompanion.insert(name: name, type: type, icon: Value(icon)),
      ]);
    });
  }

  Future<List<Category>> categoriesForType(String type) {
    return (db.select(db.categories)
          ..where((c) => c.type.equals(type) & c.isActive.equals(true))
          ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
        .get();
  }

  // ---------------------------------------------------------------------
  // Cycles
  // ---------------------------------------------------------------------

  Future<int> createCycle({
    required DateTime startDate,
    required DateTime endDate,
    String? name,
    int? declaredBankBalanceCents,
  }) async {
    await ensureDefaultCategories();
    return db.into(db.budgetCycles).insert(BudgetCyclesCompanion.insert(
          startDate: startDate,
          endDate: endDate,
          name: Value(name),
          declaredBankBalanceCents: Value(declaredBankBalanceCents),
        ));
  }

  // ---------------------------------------------------------------------
  // Revenus
  // ---------------------------------------------------------------------

  Future<int> createIncome({
    required int cycleId,
    required String name,
    required int expectedAmountCents,
    int? actualAmountCents,
    required DateTime expectedDate,
    bool isRecurring = false,
    bool isActive = true,
  }) {
    return db.into(db.incomes).insert(IncomesCompanion.insert(
          cycleId: cycleId,
          name: name,
          expectedAmountCents: expectedAmountCents,
          actualAmountCents: Value(actualAmountCents),
          expectedDate: expectedDate,
          isRecurring: Value(isRecurring),
          isActive: Value(isActive),
        ));
  }

  Future<void> updateIncome({
    required int id,
    required String name,
    required int expectedAmountCents,
    int? actualAmountCents,
    required DateTime expectedDate,
    required bool isRecurring,
    required bool isActive,
  }) {
    return (db.update(db.incomes)..where((t) => t.id.equals(id))).write(IncomesCompanion(
      name: Value(name),
      expectedAmountCents: Value(expectedAmountCents),
      actualAmountCents: Value(actualAmountCents),
      expectedDate: Value(expectedDate),
      isRecurring: Value(isRecurring),
      isActive: Value(isActive),
    ));
  }

  Future<void> deleteIncome(int id) => (db.delete(db.incomes)..where((t) => t.id.equals(id))).go();

  // ---------------------------------------------------------------------
  // Charges fixes
  // ---------------------------------------------------------------------

  Future<int> createFixedExpense({
    required int cycleId,
    required String name,
    required int expectedAmountCents,
    int? actualAmountCents,
    required DateTime expectedDate,
    int? categoryId,
    bool isRecurring = false,
    bool isActive = true,
  }) {
    return db.into(db.fixedExpenses).insert(FixedExpensesCompanion.insert(
          cycleId: cycleId,
          name: name,
          expectedAmountCents: expectedAmountCents,
          actualAmountCents: Value(actualAmountCents),
          expectedDate: expectedDate,
          categoryId: Value(categoryId),
          isRecurring: Value(isRecurring),
          isActive: Value(isActive),
        ));
  }

  Future<void> updateFixedExpense({
    required int id,
    required String name,
    required int expectedAmountCents,
    int? actualAmountCents,
    required DateTime expectedDate,
    int? categoryId,
    required bool isRecurring,
    required bool isActive,
  }) {
    return (db.update(db.fixedExpenses)..where((t) => t.id.equals(id)))
        .write(FixedExpensesCompanion(
      name: Value(name),
      expectedAmountCents: Value(expectedAmountCents),
      actualAmountCents: Value(actualAmountCents),
      expectedDate: Value(expectedDate),
      categoryId: Value(categoryId),
      isRecurring: Value(isRecurring),
      isActive: Value(isActive),
    ));
  }

  Future<void> deleteFixedExpense(int id) =>
      (db.delete(db.fixedExpenses)..where((t) => t.id.equals(id))).go();

  // ---------------------------------------------------------------------
  // Dépenses variables
  // ---------------------------------------------------------------------

  Future<int> createVariableExpense({
    required int cycleId,
    String? name,
    required int amountCents,
    required DateTime date,
    int? categoryId,
  }) {
    return db.into(db.variableExpenses).insert(VariableExpensesCompanion.insert(
          cycleId: cycleId,
          name: Value(name),
          amountCents: amountCents,
          date: date,
          categoryId: Value(categoryId),
        ));
  }

  Future<void> updateVariableExpense({
    required int id,
    String? name,
    required int amountCents,
    required DateTime date,
    int? categoryId,
  }) {
    return (db.update(db.variableExpenses)..where((t) => t.id.equals(id)))
        .write(VariableExpensesCompanion(
      name: Value(name),
      amountCents: Value(amountCents),
      date: Value(date),
      categoryId: Value(categoryId),
      updatedAt: Value(DateTime.now()),
    ));
  }

  Future<void> deleteVariableExpense(int id) =>
      (db.delete(db.variableExpenses)..where((t) => t.id.equals(id))).go();

  // ---------------------------------------------------------------------
  // Épargnes
  // ---------------------------------------------------------------------

  Future<int> createSaving({
    required int cycleId,
    required String name,
    required int expectedAmountCents,
    int? actualAmountCents,
    required DateTime expectedDate,
    bool isRecurring = false,
    bool isActive = true,
  }) {
    return db.into(db.savings).insert(SavingsCompanion.insert(
          cycleId: cycleId,
          name: name,
          expectedAmountCents: expectedAmountCents,
          actualAmountCents: Value(actualAmountCents),
          expectedDate: expectedDate,
          isRecurring: Value(isRecurring),
          isActive: Value(isActive),
        ));
  }

  Future<void> updateSaving({
    required int id,
    required String name,
    required int expectedAmountCents,
    int? actualAmountCents,
    required DateTime expectedDate,
    required bool isRecurring,
    required bool isActive,
  }) {
    return (db.update(db.savings)..where((t) => t.id.equals(id))).write(SavingsCompanion(
      name: Value(name),
      expectedAmountCents: Value(expectedAmountCents),
      actualAmountCents: Value(actualAmountCents),
      expectedDate: Value(expectedDate),
      isRecurring: Value(isRecurring),
      isActive: Value(isActive),
    ));
  }

  Future<void> deleteSaving(int id) => (db.delete(db.savings)..where((t) => t.id.equals(id))).go();
}
