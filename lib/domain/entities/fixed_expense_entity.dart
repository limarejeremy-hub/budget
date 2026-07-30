import '../../core/constants/app_constants.dart';

class FixedExpenseEntity {
  final int id;
  final int cycleId;
  final String name;
  final int expectedAmountCents;
  final int? actualAmountCents;
  final DateTime expectedDate;
  final String status;
  final int? categoryId;
  final bool isRecurring;
  final bool isActive;

  const FixedExpenseEntity({
    required this.id,
    required this.cycleId,
    required this.name,
    required this.expectedAmountCents,
    this.actualAmountCents,
    required this.expectedDate,
    this.status = ChargeStatus.aVenir,
    this.categoryId,
    this.isRecurring = false,
    this.isActive = true,
  });

  int get effectiveAmountCents => actualAmountCents ?? expectedAmountCents;
}
