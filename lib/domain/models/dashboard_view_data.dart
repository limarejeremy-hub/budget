import '../entities/fixed_expense_entity.dart';

/// Modèle de vue prêt à afficher — construit par [DashboardViewBuilder].
class DashboardViewData {
  final DateTime cycleStart;
  final DateTime cycleEnd;
  final int totalIncomeCents;
  final int totalFixedExpensesCents;
  final int totalVariableExpensesCents;
  final int totalSavingsCents;
  final int realRemainingCents;
  final double remainingRatio;
  final int unconfirmedChargesCount;
  final int unconfirmedChargesTotalCents;
  final FixedExpenseEntity? nextChargeToCheck;
  final int? declaredBankBalanceCents;

  const DashboardViewData({
    required this.cycleStart,
    required this.cycleEnd,
    required this.totalIncomeCents,
    required this.totalFixedExpensesCents,
    required this.totalVariableExpensesCents,
    required this.totalSavingsCents,
    required this.realRemainingCents,
    required this.remainingRatio,
    required this.unconfirmedChargesCount,
    required this.unconfirmedChargesTotalCents,
    this.nextChargeToCheck,
    this.declaredBankBalanceCents,
  });
}
