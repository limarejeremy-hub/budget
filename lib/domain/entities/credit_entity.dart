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

  /// Progression intelligente du remboursement, entre 0.0 et 1.0 :
  /// 1. Si le montant initial est connu (> 0) : `(initial - restant) /
  ///    initial` — la mesure la plus fidèle.
  /// 2. Sinon, si une durée totale est déductible des dates (début connu) :
  ///    `(durée totale en mois - mensualités restantes) / durée totale`.
  /// 3. En dernier recours (ni montant initial ni dates exploitables) :
  ///    capital restant nul => considéré comme soldé, sinon aucune
  ///    progression fiable ne peut être déduite.
  double get repaidProgress {
    if (initialAmountCents > 0) {
      final repaid = initialAmountCents - remainingCapitalCents;
      return (repaid / initialAmountCents).clamp(0.0, 1.0);
    }

    final totalMonths = _totalMonthsFromDates();
    if (totalMonths != null && totalMonths > 0) {
      final elapsed = totalMonths - remainingInstallments;
      return (elapsed / totalMonths).clamp(0.0, 1.0);
    }

    return remainingCapitalCents <= 0 ? 1.0 : 0.0;
  }

  /// Durée totale du prêt en mois, déduite de la différence entre date de
  /// début et date de fin prévue — `null` si la date de début est absente.
  int? _totalMonthsFromDates() {
    final start = startDate;
    if (start == null) return null;
    return (expectedEndDate.year - start.year) * 12 + (expectedEndDate.month - start.month);
  }
}
