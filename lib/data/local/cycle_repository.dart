import 'package:drift/drift.dart';

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

/// Requêtes Drift pour charger le cycle courant et ses données associées.
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
        .tableUpdates(TableUpdateQuery.onTableList([
          db.budgetCycles,
          db.incomes,
          db.fixedExpenses,
          db.variableExpenses,
          db.savings,
        ]))
        .asyncMap((_) => loadCurrentCycleData());
  }
}
