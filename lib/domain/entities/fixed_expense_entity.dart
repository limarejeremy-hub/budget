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

  /// "Reporter au prochain cycle" — `true` quand l'utilisateur a
  /// explicitement décidé que cette échéance sera financée par le cycle
  /// suivant. N'affecte jamais `expectedDate` (toujours la vraie date de
  /// prélèvement) ni `cycleId` : seule son appartenance BUDGÉTAIRE change.
  final bool deferredToNextCycle;

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
    this.deferredToNextCycle = false,
  });

  bool get isLinkedToCredit => linkedCreditId != null;

  int get effectiveAmountCents => actualAmountCents ?? expectedAmountCents;
}
