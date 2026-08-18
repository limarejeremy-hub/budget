import '../entities/credit_entity.dart';

/// Décrémentation automatique d'un crédit lorsqu'une mensualité est payée
/// (capital restant, mensualités restantes) — activée en V0.9 : branchée
/// sur la confirmation d'une charge liée (`CycleRepository.confirmFixedExpense`).
/// Reste un service de calcul pur, sans dépendance à Drift ni à Flutter.
class CreditAutoUpdateService {
  const CreditAutoUpdateService();

  /// Calcule l'état d'un crédit après un versement de [paidCents] : capital
  /// restant diminué de ce montant (jamais sous zéro) et mensualités
  /// restantes décrémentées d'une unité (jamais sous zéro). Ne modifie
  /// jamais [credit] ; retourne toujours une nouvelle instance.
  CreditEntity applyPayment(CreditEntity credit, int paidCents) {
    final newRemainingCapital =
        (credit.remainingCapitalCents - paidCents).clamp(0, credit.remainingCapitalCents);
    final newRemainingInstallments =
        (credit.remainingInstallments - 1).clamp(0, credit.remainingInstallments);

    return CreditEntity(
      id: credit.id,
      name: credit.name,
      initialAmountCents: credit.initialAmountCents,
      remainingCapitalCents: newRemainingCapital,
      monthlyPaymentCents: credit.monthlyPaymentCents,
      annualRatePercent: credit.annualRatePercent,
      startDate: credit.startDate,
      expectedEndDate: credit.expectedEndDate,
      remainingInstallments: newRemainingInstallments,
      creditType: credit.creditType,
      earlyRepaymentAllowed: credit.earlyRepaymentAllowed,
      earlyRepaymentPenaltyCents: credit.earlyRepaymentPenaltyCents,
      notes: credit.notes,
      isActive: credit.isActive,
      createdAt: credit.createdAt,
      updatedAt: credit.updatedAt,
      organisme: credit.organisme,
      colorValue: credit.colorValue,
      iconCodePoint: credit.iconCodePoint,
      paymentDayOfMonth: credit.paymentDayOfMonth,
      insuranceCents: credit.insuranceCents,
    );
  }

  /// Cas particulier de [applyPayment] : verse exactement la mensualité du
  /// crédit (`credit.monthlyPaymentCents`).
  CreditEntity applyMonthlyPayment(CreditEntity credit) => applyPayment(credit, credit.monthlyPaymentCents);
}

/// Résultat d'une décrémentation automatique appliquée lors de la
/// confirmation d'une charge liée à un crédit.
class CreditAutoUpdateResult {
  final CreditEntity credit;

  /// `true` si ce versement a soldé le crédit (capital restant ou
  /// mensualités restantes tombés à zéro) — le crédit est alors
  /// automatiquement marqué terminé.
  final bool finished;

  const CreditAutoUpdateResult({required this.credit, required this.finished});
}
