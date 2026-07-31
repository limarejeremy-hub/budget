import '../entities/credit_entity.dart';

/// Calculs purs sur les crédits — aucune dépendance à Drift. Les agrégats
/// et indicateurs ne portent que sur les crédits actifs ; les méthodes de
/// tri opèrent sur la liste fournie telle quelle (l'écran décide s'il
/// trie tous les crédits ou seulement les actifs).
class CreditCalculationService {
  const CreditCalculationService();

  List<CreditEntity> activeOnly(List<CreditEntity> credits) =>
      credits.where((c) => c.isActive).toList();

  int totalRemainingCapital(List<CreditEntity> credits) =>
      activeOnly(credits).fold(0, (sum, c) => sum + c.remainingCapitalCents);

  int totalMonthlyPayments(List<CreditEntity> credits) =>
      activeOnly(credits).fold(0, (sum, c) => sum + c.monthlyPaymentCents);

  int activeCount(List<CreditEntity> credits) => activeOnly(credits).length;

  /// Le crédit actif dont la date de fin prévue est la plus proche.
  CreditEntity? earliestEnding(List<CreditEntity> credits) {
    final active = activeOnly(credits);
    if (active.isEmpty) return null;
    return active.reduce((a, b) => a.expectedEndDate.isBefore(b.expectedEndDate) ? a : b);
  }

  /// Le crédit actif au capital restant dû le plus faible.
  CreditEntity? lowestRemainingCapitalCredit(List<CreditEntity> credits) {
    final active = activeOnly(credits);
    if (active.isEmpty) return null;
    return active.reduce((a, b) => a.remainingCapitalCents <= b.remainingCapitalCents ? a : b);
  }

  /// Le crédit actif au capital restant dû le plus élevé.
  CreditEntity? highestRemainingCapitalCredit(List<CreditEntity> credits) {
    final active = activeOnly(credits);
    if (active.isEmpty) return null;
    return active.reduce((a, b) => a.remainingCapitalCents >= b.remainingCapitalCents ? a : b);
  }

  /// Le crédit actif à la mensualité la plus élevée.
  CreditEntity? highestMonthlyPaymentCredit(List<CreditEntity> credits) {
    final active = activeOnly(credits);
    if (active.isEmpty) return null;
    return active.reduce((a, b) => a.monthlyPaymentCents >= b.monthlyPaymentCents ? a : b);
  }

  /// Le crédit actif au taux annuel le plus élevé, parmi ceux dont le taux
  /// est renseigné. `null` si aucun crédit actif n'a de taux renseigné.
  CreditEntity? highestRateCredit(List<CreditEntity> credits) {
    final rated = activeOnly(credits).where((c) => c.annualRatePercent != null).toList();
    if (rated.isEmpty) return null;
    return rated.reduce((a, b) => a.annualRatePercent! >= b.annualRatePercent! ? a : b);
  }

  /// Date de fin estimée pour l'ensemble des crédits actifs (la plus
  /// tardive parmi eux) — `null` si aucun crédit actif.
  DateTime? latestActiveEndDate(List<CreditEntity> credits) {
    final active = activeOnly(credits);
    if (active.isEmpty) return null;
    return active.map((c) => c.expectedEndDate).reduce((a, b) => a.isAfter(b) ? a : b);
  }

  /// Tri "Plus facile à solder" — capital restant le plus faible d'abord.
  List<CreditEntity> sortByLowestCapital(List<CreditEntity> credits) =>
      [...credits]..sort((a, b) => a.remainingCapitalCents.compareTo(b.remainingCapitalCents));

  /// Tri "Plus coûteux" — taux le plus élevé d'abord ; les crédits sans
  /// taux renseigné sont toujours placés en dernier.
  List<CreditEntity> sortByHighestRate(List<CreditEntity> credits) =>
      [...credits]..sort(_byRateDescending);

  /// Tri "Plus grosse mensualité libérée" — mensualité la plus élevée
  /// d'abord.
  List<CreditEntity> sortByHighestPayment(List<CreditEntity> credits) =>
      [...credits]..sort((a, b) => b.monthlyPaymentCents.compareTo(a.monthlyPaymentCents));

  int _byRateDescending(CreditEntity a, CreditEntity b) {
    if (a.annualRatePercent == null && b.annualRatePercent == null) return 0;
    if (a.annualRatePercent == null) return 1;
    if (b.annualRatePercent == null) return -1;
    return b.annualRatePercent!.compareTo(a.annualRatePercent!);
  }

  /// Priorité automatique — jamais imposée comme une obligation, seulement
  /// une indication visuelle basée sur le nombre de mensualités restantes :
  /// moins de 6 mois (5 étoiles), entre 6 et 24 (3 étoiles), au-delà (1
  /// étoile).
  int priorityStars(CreditEntity credit) {
    if (credit.remainingInstallments < 6) return 5;
    if (credit.remainingInstallments <= 24) return 3;
    return 1;
  }

  /// Libellé associé à [priorityStars].
  String priorityLabel(CreditEntity credit) {
    final stars = priorityStars(credit);
    if (stars == 5) return 'Priorité maximale';
    if (stars == 3) return 'Priorité moyenne';
    return 'Long terme';
  }

  /// Score visuel automatique d'un crédit, basé sur ses mensualités
  /// restantes — un indicateur distinct de [priorityStars], à l'échelle
  /// différente (utile pour repérer d'un coup d'œil les crédits de très
  /// longue durée, comme un prêt immobilier).
  CreditPace creditPace(CreditEntity credit) {
    final months = credit.remainingInstallments;
    if (months < 12) return CreditPace.veryClose;
    if (months < 48) return CreditPace.medium;
    if (months < 120) return CreditPace.long;
    return CreditPace.veryLong;
  }

  /// Libellé associé à [creditPace].
  String creditPaceLabel(CreditEntity credit) {
    switch (creditPace(credit)) {
      case CreditPace.veryClose:
        return 'Très proche de la fin';
      case CreditPace.medium:
        return 'Moyen terme';
      case CreditPace.long:
        return 'Long terme';
      case CreditPace.veryLong:
        return 'Très longue durée';
    }
  }
}

/// Statut visuel automatique d'un crédit selon ses mensualités restantes :
/// moins de 12 mois, entre 12 et 48, entre 48 et 120, au-delà de 120.
enum CreditPace { veryClose, medium, long, veryLong }

/// Résultat d'une simulation de versement exceptionnel — toujours une
/// estimation simplifiée (capital linéaire / mensualité, hors intérêts et
/// pénalités éventuelles), jamais présentée comme un calcul exact.
class CreditPrepaymentSimulation {
  final int remainingCapitalAfterCents;
  final int theoreticalRemainingInstallments;
  final int monthsSaved;
  final DateTime estimatedEndDate;

  const CreditPrepaymentSimulation({
    required this.remainingCapitalAfterCents,
    required this.theoreticalRemainingInstallments,
    required this.monthsSaved,
    required this.estimatedEndDate,
  });
}

/// Simule l'effet d'un versement exceptionnel de [extraPaymentCents] sur
/// [credit]. Estimation volontairement simplifiée : elle ne modélise pas les
/// intérêts composés ni d'éventuelles pénalités de remboursement anticipé —
/// toujours présentée comme telle dans l'interface.
CreditPrepaymentSimulation simulateCreditPrepayment({
  required CreditEntity credit,
  required int extraPaymentCents,
}) {
  final remainingAfter =
      (credit.remainingCapitalCents - extraPaymentCents).clamp(0, credit.remainingCapitalCents);
  final monthlyPayment = credit.monthlyPaymentCents;
  final newInstallments = monthlyPayment > 0 ? (remainingAfter / monthlyPayment).ceil() : 0;
  final monthsSaved = (credit.remainingInstallments - newInstallments).clamp(0, credit.remainingInstallments);
  final estimatedEndDate = _subtractMonths(credit.expectedEndDate, monthsSaved);

  return CreditPrepaymentSimulation(
    remainingCapitalAfterCents: remainingAfter,
    theoreticalRemainingInstallments: newInstallments,
    monthsSaved: monthsSaved,
    estimatedEndDate: estimatedEndDate,
  );
}

/// Une option de remboursement parmi plusieurs, proposée par le simulateur
/// multi-crédits : "et si ce versement était appliqué à CE crédit-là ?"
/// Toujours une estimation simplifiée (voir [CreditPrepaymentSimulation]).
class CreditRepaymentOption {
  final CreditEntity credit;
  final bool wouldBeFullyRepaid;
  final int monthlyPaymentFreedCents;
  final int monthsSaved;
  final int remainingCapitalAfterCents;
  final DateTime estimatedEndDate;

  /// Estimation grossière des intérêts épargnés (taux annuel simple appliqué
  /// au capital versé par anticipation, sur les mois gagnés) — `null` si le
  /// crédit n'a pas de taux renseigné. Toujours présentée comme une
  /// estimation, jamais comme un calcul exact.
  final int? estimatedInterestSavedCents;

  const CreditRepaymentOption({
    required this.credit,
    required this.wouldBeFullyRepaid,
    required this.monthlyPaymentFreedCents,
    required this.monthsSaved,
    required this.remainingCapitalAfterCents,
    required this.estimatedEndDate,
    this.estimatedInterestSavedCents,
  });
}

/// Simule l'effet d'un même versement exceptionnel de [extraPaymentCents]
/// appliqué, tour à tour, à chacun des crédits actifs de [credits] — pour
/// comparer où ce versement aurait le plus d'impact. BudgetPilot ne choisit
/// jamais à la place de l'utilisateur : les options sont simplement triées
/// par impact estimé (un crédit soldé entièrement d'abord, sinon le plus
/// grand nombre de mensualités gagnées).
List<CreditRepaymentOption> simulateAcrossActiveCredits({
  required List<CreditEntity> credits,
  required int extraPaymentCents,
}) {
  const service = CreditCalculationService();
  final active = service.activeOnly(credits);

  final options = active.map((credit) {
    final simulation = simulateCreditPrepayment(credit: credit, extraPaymentCents: extraPaymentCents);
    final fullyRepaid = extraPaymentCents >= credit.remainingCapitalCents;
    final rate = credit.annualRatePercent;
    final interestSaved = rate == null
        ? null
        : (extraPaymentCents * (rate / 100 / 12) * simulation.monthsSaved).round();
    return CreditRepaymentOption(
      credit: credit,
      wouldBeFullyRepaid: fullyRepaid,
      monthlyPaymentFreedCents: fullyRepaid ? credit.monthlyPaymentCents : 0,
      monthsSaved: simulation.monthsSaved,
      remainingCapitalAfterCents: simulation.remainingCapitalAfterCents,
      estimatedEndDate: simulation.estimatedEndDate,
      estimatedInterestSavedCents: interestSaved,
    );
  }).toList();

  options.sort((a, b) {
    if (a.wouldBeFullyRepaid != b.wouldBeFullyRepaid) {
      return a.wouldBeFullyRepaid ? -1 : 1;
    }
    if (a.monthlyPaymentFreedCents != b.monthlyPaymentFreedCents) {
      return b.monthlyPaymentFreedCents.compareTo(a.monthlyPaymentFreedCents);
    }
    return b.monthsSaved.compareTo(a.monthsSaved);
  });

  return options;
}

DateTime _subtractMonths(DateTime date, int months) {
  final totalMonths = date.year * 12 + (date.month - 1) - months;
  final year = totalMonths ~/ 12;
  final month = totalMonths % 12 + 1;
  final daysInTargetMonth = DateTime(year, month + 1, 0).day;
  final day = date.day > daysInTargetMonth ? daysInTargetMonth : date.day;
  return DateTime(year, month, day);
}
