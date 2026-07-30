import 'package:intl/intl.dart';

final _euroFormat = NumberFormat.currency(locale: 'fr_FR', symbol: '€', decimalDigits: 0);

/// Formate un montant en centimes en euros, style fr-FR (ex : "2 023 €").
String formatCentsAsEuro(int cents) => _euroFormat.format(cents / 100);

/// Formate une date en "26 août" (fr-FR).
String formatDayMonthFr(DateTime date) => DateFormat('d MMMM', 'fr_FR').format(date);
