import '../../core/constants/app_constants.dart';

/// Entité pure — aucune dépendance à Drift. Montants en centimes.
class IncomeEntity {
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

  const IncomeEntity({
    required this.id,
    required this.cycleId,
    required this.name,
    required this.expectedAmountCents,
    this.actualAmountCents,
    required this.expectedDate,
    this.status = IncomeStatus.prevu,
    this.categoryId,
    this.isRecurring = false,
    this.isActive = true,
  });

  int get effectiveAmountCents => actualAmountCents ?? expectedAmountCents;
}
