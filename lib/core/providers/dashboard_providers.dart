import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/converters/entity_mappers.dart';
import '../../data/local/cycle_repository.dart';
import '../../domain/calculations/dashboard_view_builder.dart';
import '../../domain/models/dashboard_view_data.dart';
import 'database_provider.dart';

final cycleRepositoryProvider = Provider<CycleRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return CycleRepository(db);
});

/// null = aucun cycle en cours (état vide de l'écran).
final dashboardProvider = StreamProvider.autoDispose<DashboardViewData?>((ref) {
  final repository = ref.watch(cycleRepositoryProvider);
  const builder = DashboardViewBuilder();

  return repository.watchCurrentCycleData().map((raw) {
    if (raw == null) return null;

    return builder.build(
      cycleStart: raw.cycle.startDate,
      cycleEnd: raw.cycle.endDate,
      incomes: raw.incomes.map(incomeFromRow).toList(),
      fixedExpenses: raw.fixedExpenses.map(fixedExpenseFromRow).toList(),
      variableExpenses: raw.variableExpenses.map(variableExpenseFromRow).toList(),
      savings: raw.savings.map(savingFromRow).toList(),
      declaredBankBalanceCents: raw.cycle.declaredBankBalanceCents,
    );
  });
});
