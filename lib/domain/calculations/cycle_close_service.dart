import 'credit_term_calculator.dart';

const _termCalculator = CreditTermCalculator();

/// Calculs purs pour la clôture d'un cycle et le démarrage du suivant
/// (finalisation du moteur de cycle) — aucune dépendance à Drift. Les dates
/// des entrées récurrentes recopiées réutilisent
/// `CreditTermCalculator.addMonths` — déjà LA seule formule de "+1 mois avec
/// repli sur le dernier jour valide du mois" de l'application (29/30/31,
/// février, année bissextile) — jamais une nouvelle formule de date.
class CycleCloseService {
  const CycleCloseService();

  /// Date de début du prochain cycle : le lendemain de la fin du cycle
  /// précédent.
  DateTime nextCycleStartDate(DateTime previousEndDate) {
    final endDay = DateTime(previousEndDate.year, previousEndDate.month, previousEndDate.day);
    return endDay.add(const Duration(days: 1));
  }

  /// Date de fin du prochain cycle : conserve exactement la durée (en
  /// jours) du cycle précédent, appliquée à partir de la nouvelle date de
  /// début — fonctionne aussi bien pour un cycle standard que pour un cycle
  /// personnalisé, jamais figée sur "27 → 26".
  DateTime nextCycleEndDate({
    required DateTime previousStartDate,
    required DateTime previousEndDate,
    required DateTime newStartDate,
  }) {
    final start = DateTime(previousStartDate.year, previousStartDate.month, previousStartDate.day);
    final end = DateTime(previousEndDate.year, previousEndDate.month, previousEndDate.day);
    final durationDays = end.difference(start).inDays;
    final newStart = DateTime(newStartDate.year, newStartDate.month, newStartDate.day);
    return newStart.add(Duration(days: durationDays));
  }

  /// Date d'une entrée récurrente (revenu, charge fixe, épargne) recopiée
  /// dans le nouveau cycle : un mois après sa date dans le cycle précédent,
  /// avec repli automatique sur le dernier jour valide du mois cible.
  DateTime recurringEntryDateForNextCycle(DateTime previousDate) => _termCalculator.addMonths(previousDate, 1);
}
