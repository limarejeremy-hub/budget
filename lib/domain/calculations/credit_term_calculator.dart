/// Conversion pure entre "date de fin prévue" et "nombre de mensualités
/// restantes" d'un crédit — l'utilisateur ne doit renseigner que l'une des
/// deux informations, l'autre est déduite automatiquement. Classe pure :
/// ne dépend d'aucune source de données.
class CreditTermCalculator {
  const CreditTermCalculator();

  /// Nombre de mensualités restantes entre [from] (date de référence,
  /// généralement aujourd'hui) et [to] (date de fin prévue). Toujours au
  /// moins 1 tant que [to] n'est pas strictement passée par rapport à
  /// [from] — il reste alors au moins une mensualité à venir, y compris
  /// quand la date de fin tombe dans le mois courant. Jamais négatif.
  int monthsUntil(DateTime from, DateTime to) {
    final fromMonths = from.year * 12 + from.month;
    final toMonths = to.year * 12 + to.month;
    var diff = toMonths - fromMonths;
    if (to.day < from.day) diff -= 1;

    final fromDay = DateTime(from.year, from.month, from.day);
    final toDay = DateTime(to.year, to.month, to.day);
    if (diff < 1 && !toDay.isBefore(fromDay)) diff = 1;

    return diff < 0 ? 0 : diff;
  }

  /// Date obtenue en ajoutant [months] mois à [from], en conservant le jour
  /// du mois quand c'est possible — sinon le dernier jour du mois cible
  /// (ex : 31 janvier + 1 mois => 28 ou 29 février selon l'année). Même
  /// règle que le reste de l'application pour les calculs de mois.
  DateTime addMonths(DateTime from, int months) {
    final totalMonths = from.year * 12 + (from.month - 1) + months;
    final year = totalMonths ~/ 12;
    final month = totalMonths % 12 + 1;
    final daysInTargetMonth = DateTime(year, month + 1, 0).day;
    final day = from.day > daysInTargetMonth ? daysInTargetMonth : from.day;
    return DateTime(year, month, day);
  }
}
