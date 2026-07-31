/// Entité pure — aucune dépendance à Drift. Montants en centimes.
/// Un crédit est indépendant des cycles budgétaires : il ne se
/// réinitialise jamais, contrairement aux revenus/charges/dépenses/épargnes.
class CreditEntity {
  final int id;
  final String name;
  final int initialAmountCents;
  final int remainingCapitalCents;
  final int monthlyPaymentCents;
  final double? annualRatePercent;
  final DateTime? startDate;
  final DateTime expectedEndDate;
  final int remainingInstallments;
  final String? creditType;
  final bool earlyRepaymentAllowed;
  final int? earlyRepaymentPenaltyCents;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? organisme;
  final int? colorValue;
  final int? iconCodePoint;

  const CreditEntity({
    required this.id,
    required this.name,
    required this.initialAmountCents,
    required this.remainingCapitalCents,
    required this.monthlyPaymentCents,
    this.annualRatePercent,
    this.startDate,
    required this.expectedEndDate,
    required this.remainingInstallments,
    this.creditType,
    this.earlyRepaymentAllowed = true,
    this.earlyRepaymentPenaltyCents,
    this.notes,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.organisme,
    this.colorValue,
    this.iconCodePoint,
  });

  /// Part déjà remboursée du capital initial, entre 0.0 et 1.0.
  double get repaidProgress {
    if (initialAmountCents <= 0) return 1;
    final repaid = initialAmountCents - remainingCapitalCents;
    return (repaid / initialAmountCents).clamp(0.0, 1.0);
  }
}
