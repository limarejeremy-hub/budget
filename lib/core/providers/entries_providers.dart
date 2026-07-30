import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/converters/entity_mappers.dart';
import '../../data/local/database.dart';
import '../../domain/entities/fixed_expense_entity.dart';
import '../../domain/entities/income_entity.dart';
import '../../domain/entities/saving_entity.dart';
import '../../domain/entities/variable_expense_entity.dart';
import 'dashboard_providers.dart';

/// Cycle actuellement ouvert (null si aucun cycle n'existe encore).
final currentCycleProvider = StreamProvider.autoDispose<BudgetCycle?>((ref) {
  final repository = ref.watch(cycleRepositoryProvider);
  return repository.watchCurrentCycleData().map((data) => data?.cycle);
});

final incomesProvider = StreamProvider.autoDispose<List<IncomeEntity>>((ref) {
  final repository = ref.watch(cycleRepositoryProvider);
  return repository
      .watchCurrentCycleData()
      .map((data) => data?.incomes.map(incomeFromRow).toList() ?? const []);
});

final fixedExpensesProvider = StreamProvider.autoDispose<List<FixedExpenseEntity>>((ref) {
  final repository = ref.watch(cycleRepositoryProvider);
  return repository
      .watchCurrentCycleData()
      .map((data) => data?.fixedExpenses.map(fixedExpenseFromRow).toList() ?? const []);
});

final variableExpensesProvider = StreamProvider.autoDispose<List<VariableExpenseEntity>>((ref) {
  final repository = ref.watch(cycleRepositoryProvider);
  return repository
      .watchCurrentCycleData()
      .map((data) => data?.variableExpenses.map(variableExpenseFromRow).toList() ?? const []);
});

final savingsProvider = StreamProvider.autoDispose<List<SavingEntity>>((ref) {
  final repository = ref.watch(cycleRepositoryProvider);
  return repository
      .watchCurrentCycleData()
      .map((data) => data?.savings.map(savingFromRow).toList() ?? const []);
});

/// Toutes les catégories actives pour un type donné (income / fixed_expense /
/// variable_expense / saving), pour peupler les listes déroulantes "catégorie".
final categoriesForTypeProvider =
    FutureProvider.autoDispose.family<List<Category>, String>((ref, type) {
  final repository = ref.watch(cycleRepositoryProvider);
  return repository.categoriesForType(type);
});

/// Tous les cycles (courant compris), du plus récent au plus ancien —
/// utilisé par l'écran Historique.
final allCyclesProvider = StreamProvider.autoDispose<List<BudgetCycle>>((ref) {
  final repository = ref.watch(cycleRepositoryProvider);
  return repository.watchAllCycles();
});
