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

  /// Crédit dont cette charge est la mensualité générée automatiquement —
  /// `null` pour une charge fixe "normale" saisie manuellement.
  final int? linkedCreditId;

  /// Modèle récurrent (`RecurringTemplates`) dont cette charge est une
  /// occurrence — `null` pour une charge ponctuelle, ou une charge
  /// récurrente créée avant le correctif "échéances récurrentes hors
  /// cycle" et pas encore rattachée (backfill au fil de l'eau).
  final int? templateId;

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
    this.linkedCreditId,
    this.templateId,
  });

  bool get isLinkedToCredit => linkedCreditId != null;

  int get effectiveAmountCents => actualAmountCents ?? expectedAmountCents;
}
