import '../../core/constants/app_constants.dart';

class SavingEntity {
  final int id;
  final int cycleId;
  final String name;
  final int expectedAmountCents;
  final int? actualAmountCents;
  final DateTime expectedDate;
  final String status;
  final bool isRecurring;
  final bool isActive;

  const SavingEntity({
    required this.id,
    required this.cycleId,
    required this.name,
    required this.expectedAmountCents,
    this.actualAmountCents,
    required this.expectedDate,
    this.status = SavingStatus.prevu,
    this.isRecurring = false,
    this.isActive = true,
  });

  int get effectiveAmountCents => actualAmountCents ?? expectedAmountCents;
}
