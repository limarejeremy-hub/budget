import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/converters/entity_mappers.dart';
import '../../data/local/cycle_repository.dart';
import '../../domain/calculations/dashboard_view_builder.dart';
import '../../domain/models/dashboard_view_data.dart';
import '../notifications/notification_service.dart';
import 'database_provider.dart';

final cycleRepositoryProvider = Provider<CycleRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return CycleRepository(db);
});

/// Une seule instance de [NotificationService] pour toute l'application
/// (pas `autoDispose` : les notifications planifiées doivent survivre à la
/// navigation entre écrans).
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final repository = ref.watch(cycleRepositoryProvider);
  return NotificationService(repository);
});

/// null = aucun cycle en cours (état vide de l'écran).
final dashboardProvider = StreamProvider.autoDispose<DashboardViewData?>((ref) {
  final repository = ref.watch(cycleRepositoryProvider);
  const builder = DashboardViewBuilder();

  return repository.watchCurrentCycleData().map((raw) {
    if (raw == null) return null;

    return builder.build(
      cycleId: raw.cycle.id,
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
