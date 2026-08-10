import 'package:flutter_test/flutter_test.dart';

import 'package:budgetpilot/domain/calculations/credit_term_calculator.dart';

void main() {
  const calculator = CreditTermCalculator();

  group('monthsUntil', () {
    test('compte les mois calendaires pleins entre deux dates', () {
      expect(calculator.monthsUntil(DateTime(2026, 1, 5), DateTime(2030, 1, 5)), 48);
    });

    test('retire un mois si le jour de fin est avant le jour de référence', () {
      expect(calculator.monthsUntil(DateTime(2026, 1, 20), DateTime(2026, 3, 5)), 1);
    });

    test('date de fin dans le mois courant => 1 mensualité restante (au moins une à venir)', () {
      expect(calculator.monthsUntil(DateTime(2026, 1, 5), DateTime(2026, 1, 20)), 1);
    });

    test('date de fin exactement aujourd\'hui => 1 mensualité restante', () {
      final today = DateTime(2026, 3, 15);
      expect(calculator.monthsUntil(today, today), 1);
    });

    test('1 mensualité restante quand la fin est le mois prochain', () {
      expect(calculator.monthsUntil(DateTime(2026, 1, 5), DateTime(2026, 2, 5)), 1);
    });

    test('jamais négatif quand la date de fin est déjà passée', () {
      expect(calculator.monthsUntil(DateTime(2026, 6, 1), DateTime(2026, 1, 1)), 0);
    });
  });

  group('addMonths', () {
    test('ajoute des mois en conservant le jour du mois', () {
      expect(calculator.addMonths(DateTime(2026, 1, 5), 48), DateTime(2030, 1, 5));
    });

    test('1 mois ajouté à janvier donne février', () {
      expect(calculator.addMonths(DateTime(2026, 1, 15), 1), DateTime(2026, 2, 15));
    });

    test('31 janvier + 1 mois retombe sur le dernier jour de février (année non bissextile)', () {
      expect(calculator.addMonths(DateTime(2025, 1, 31), 1), DateTime(2025, 2, 28));
    });

    test('31 janvier + 1 mois retombe sur le 29 février lors d\'une année bissextile', () {
      expect(calculator.addMonths(DateTime(2028, 1, 31), 1), DateTime(2028, 2, 29));
    });

    test('fin de mois : 31 mars + 1 mois retombe sur le 30 avril', () {
      expect(calculator.addMonths(DateTime(2026, 3, 31), 1), DateTime(2026, 4, 30));
    });

    test('traverse une année civile', () {
      expect(calculator.addMonths(DateTime(2026, 11, 10), 3), DateTime(2027, 2, 10));
    });

    test('0 mois renvoie la même date', () {
      expect(calculator.addMonths(DateTime(2026, 6, 15), 0), DateTime(2026, 6, 15));
    });
  });

  test('addMonths puis monthsUntil sont cohérents (aller-retour)', () {
    final from = DateTime(2026, 1, 5);
    const months = 48;
    final end = calculator.addMonths(from, months);
    expect(calculator.monthsUntil(from, end), months);
  });
}
