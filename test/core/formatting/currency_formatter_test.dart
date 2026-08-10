import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:budgetpilot/core/formatting/currency_formatter.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR', null);
  });

  group('formatDayMonthFr', () {
    test('affiche toujours le jour, le mois et l\'année', () {
      expect(formatDayMonthFr(DateTime(2026, 10, 31)), '31 octobre 2026');
      expect(formatDayMonthFr(DateTime(2047, 1, 1)), '1 janvier 2047');
    });
  });

  group('formatMonthYearFr', () {
    test('affiche le mois et l\'année, sans le jour', () {
      expect(formatMonthYearFr(DateTime(2028, 8, 15)), 'août 2028');
    });
  });

  group('formatRatioAsPercent', () {
    test('affiche une décimale quand nécessaire', () {
      expect(formatRatioAsPercent(0.125), '12,5 %');
    });

    test('omet la décimale pour un pourcentage rond', () {
      expect(formatRatioAsPercent(0.31), '31 %');
      expect(formatRatioAsPercent(0.0), '0 %');
    });

    test('arrondit au dixième de pourcent le plus proche', () {
      expect(formatRatioAsPercent(0.12345), '12,3 %');
    });
  });

  group('formatDurationYearsMonths', () {
    test('0 mois', () {
      expect(formatDurationYearsMonths(0), '0 mois');
    });

    test('mois seuls (< 12)', () {
      expect(formatDurationYearsMonths(5), '5 mois');
      expect(formatDurationYearsMonths(1), '1 mois');
    });

    test('années seules (multiple de 12)', () {
      expect(formatDurationYearsMonths(24), '2 ans');
      expect(formatDurationYearsMonths(12), '1 an');
    });

    test('années et mois combinés', () {
      expect(formatDurationYearsMonths(29), '2 ans et 5 mois');
    });

    test('valeur négative traitée comme 0', () {
      expect(formatDurationYearsMonths(-3), '0 mois');
    });
  });
}
