import '../entities/fixed_expense_entity.dart';

/// Modèle de vue prêt à afficher — construit par [DashboardViewBuilder].
class DashboardViewData {
  final int cycleId;
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

  /// Les prochaines charges fixes non confirmées (au plus 3), triées par
  /// date prévue — même liste que [nextChargeToCheck] (son premier élément),
  /// simplement exposée en totalité pour l'affichage "Prochaines échéances".
  final List<FixedExpenseEntity> upcomingCharges;
  final int? declaredBankBalanceCents;

  const DashboardViewData({
    required this.cycleId,
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
    this.upcomingCharges = const [],
    this.declaredBankBalanceCents,
  });
}
