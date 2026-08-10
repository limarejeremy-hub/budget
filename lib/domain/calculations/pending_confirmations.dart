import '../../core/constants/app_constants.dart';
import '../entities/fixed_expense_entity.dart';
import '../models/dashboard_view_data.dart';

/// Charges fixes du jour encore "à confirmer" : union de
/// [DashboardViewData.todayFixedExpenses] et [DashboardViewData.alerts]
/// (qui peuvent se recouper), dédupliquées par id, en excluant celles déjà
/// tranchées (prélevée ou ignorée). Triées par date d'échéance. Fonction
/// pure, réutilisée par le badge "Aujourd'hui", le centre de confirmations
/// et la planification des rappels.
List<FixedExpenseEntity> pendingConfirmations(DashboardViewData data) {
  final byId = <int, FixedExpenseEntity>{};
  for (final charge in [...data.todayFixedExpenses, ...data.alerts]) {
    byId[charge.id] = charge;
  }
  final list = byId.values
      .where((e) => e.status != ChargeStatus.prelevee && e.status != ChargeStatus.suspendue)
      .toList()
    ..sort((a, b) => a.expectedDate.compareTo(b.expectedDate));
  return list;
}
