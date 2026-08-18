import '../../core/constants/app_constants.dart';
import 'credit_term_calculator.dart';

const _termCalculator = CreditTermCalculator();

/// Limite défensive contre un intervalle mal configuré (ex : 0) qui
/// bloquerait la boucle de génération d'occurrences en avançant sans fin.
const int _maxIterations = 1000;

/// Calculs purs de récurrence — aucune dépendance à Drift. Correctif
/// "échéances récurrentes hors cycle" (§ règle métier) : une charge
/// n'appartient à un cycle que si la date de son occurrence réelle tombe
/// dans sa période ; le caractère "récurrent" ne suffit jamais à lui seul.
class RecurrenceCalculator {
  const RecurrenceCalculator();

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Prochaine occurrence après [last], selon [recurrenceType]. Réutilise
  /// `CreditTermCalculator.addMonths` pour 'mensuel_jour_fixe' — jamais une
  /// nouvelle formule de date pour ce cas déjà géré ailleurs (29/30/31,
  /// février, année bissextile).
  DateTime nextOccurrence(
    DateTime last, {
    required String recurrenceType,
    int? intervalValue,
  }) {
    final from = _dateOnly(last);
    // Défense contre un intervalle non renseigné ou invalide (<= 0) : ne
    // doit jamais produire une occurrence immobile qui boucle sans fin.
    final interval = (intervalValue != null && intervalValue > 0) ? intervalValue : 1;
    switch (recurrenceType) {
      case RecurrenceType.toutesLesXSemaines:
        return from.add(Duration(days: 7 * interval));
      case RecurrenceType.tousLesXJours:
        return from.add(Duration(days: interval));
      case RecurrenceType.mensuelJourFixe:
      default:
        return _termCalculator.addMonths(from, 1);
    }
  }

  /// Toutes les occurrences dont la date tombe dans `[start, end]` (bornes
  /// incluses), en avançant depuis [lastKnownDate] (l'occurrence la plus
  /// récente déjà existante — jamais recalculée depuis une date fixe
  /// arbitraire, pour ne jamais dériver au fil des cycles). Ne limite
  /// jamais à une seule occurrence par cycle : une charge "toutes les 4
  /// semaines" peut légitimement en produire deux dans une même période, et
  /// zéro dans une autre.
  List<DateTime> occurrencesInRange({
    required DateTime lastKnownDate,
    required DateTime start,
    required DateTime end,
    required String recurrenceType,
    int? intervalValue,
  }) {
    final rangeStart = _dateOnly(start);
    final rangeEnd = _dateOnly(end);
    final result = <DateTime>[];

    var candidate = nextOccurrence(lastKnownDate, recurrenceType: recurrenceType, intervalValue: intervalValue);
    var iterations = 0;
    while (!candidate.isAfter(rangeEnd) && iterations < _maxIterations) {
      if (!candidate.isBefore(rangeStart)) result.add(candidate);
      candidate = nextOccurrence(candidate, recurrenceType: recurrenceType, intervalValue: intervalValue);
      iterations++;
    }
    return result;
  }
}
