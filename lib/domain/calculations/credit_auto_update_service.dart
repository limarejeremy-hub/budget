import '../entities/credit_entity.dart';

/// Prépare l'architecture de la V0.9 (décrémentation automatique d'un
/// crédit lorsqu'une mensualité est payée, recalcul du capital restant et
/// des mensualités restantes, mise à jour automatique du tableau de bord)
/// — SANS activer cette fonctionnalité. Fonction pure, non appelée depuis
/// l'application : aucun provider, aucun repository et aucune UI n'y fait
/// référence pour l'instant. L'activation future consistera uniquement à
/// brancher [applyMonthlyPayment] sur un déclencheur (ex : passage au
/// cycle suivant), sans toucher à ce calcul.
class CreditAutoUpdateService {
  const CreditAutoUpdateService();

  /// Calcule l'état d'un crédit après le paiement d'une mensualité :
  /// capital restant diminué de la mensualité (jamais sous zéro) et
  /// mensualités restantes décrémentées d'une unité (jamais sous zéro).
  /// Ne modifie jamais [credit] ; retourne toujours une nouvelle instance.
  CreditEntity applyMonthlyPayment(CreditEntity credit) {
    final newRemainingCapital =
        (credit.remainingCapitalCents - credit.monthlyPaymentCents).clamp(0, credit.remainingCapitalCents);
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
    );
  }
}
