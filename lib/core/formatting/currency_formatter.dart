import 'package:intl/intl.dart';

final _euroFormat = NumberFormat.currency(locale: 'fr_FR', symbol: '€', decimalDigits: 0);

/// Formate un montant en centimes en euros, style fr-FR (ex : "2 023 €").
String formatCentsAsEuro(int cents) => _euroFormat.format(cents / 100);

/// Formate une date en "26 août 2026" (fr-FR) — l'année est toujours
/// affichée, jamais seulement "jour mois", pour qu'une échéance à un an ne
/// soit jamais confondue avec une échéance dans un mois.
String formatDayMonthFr(DateTime date) => DateFormat('d MMMM y', 'fr_FR').format(date);

/// Formate une date en "août 2028" (fr-FR) — utilisé quand seul le mois
/// compte (ex : nouvelle date de fin estimée après un remboursement
/// anticipé), sans jamais perdre l'année.
String formatMonthYearFr(DateTime date) => DateFormat('MMMM y', 'fr_FR').format(date);

/// Formate un ratio (0.125 => "12,5 %") en pourcentage fr-FR, avec au
/// maximum une décimale — jamais ",0 %" pour un ratio rond ("31 %", pas
/// "31,0 %").
String formatRatioAsPercent(double ratio) {
  final rounded = (ratio * 1000).round() / 10; // pourcentage, 1 décimale max
  final isWhole = rounded == rounded.roundToDouble();
  final text = isWhole ? rounded.round().toString() : rounded.toStringAsFixed(1).replaceAll('.', ',');
  return '$text %';
}

/// Formate une durée en mois en "X ans et Y mois" (fr-FR), en omettant la
/// partie nulle ("2 ans", "5 mois", "2 ans et 5 mois"). `0` donne "0 mois".
String formatDurationYearsMonths(int totalMonths) {
  if (totalMonths <= 0) return '0 mois';
  final years = totalMonths ~/ 12;
  final months = totalMonths % 12;
  final yearsPart = years > 0 ? '$years an${years > 1 ? 's' : ''}' : '';
  final monthsPart = months > 0 ? '$months mois' : '';
  if (yearsPart.isNotEmpty && monthsPart.isNotEmpty) return '$yearsPart et $monthsPart';
  return yearsPart.isNotEmpty ? yearsPart : monthsPart;
}
