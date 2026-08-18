import 'package:flutter_test/flutter_test.dart';

import 'package:budgetpilot/domain/calculations/cycle_close_service.dart';

void main() {
  const service = CycleCloseService();

  group('nextCycleStartDate', () {
    test('le lendemain de la fin du cycle précédent', () {
      expect(service.nextCycleStartDate(DateTime(2026, 8, 26)), DateTime(2026, 8, 27));
    });

    test('traverse un changement de mois', () {
      expect(service.nextCycleStartDate(DateTime(2026, 1, 31)), DateTime(2026, 2, 1));
    });

    test('traverse un changement d\'année', () {
      expect(service.nextCycleStartDate(DateTime(2026, 12, 31)), DateTime(2027, 1, 1));
    });
  });

  group('nextCycleEndDate', () {
    test('conserve la durée exacte du cycle précédent (cycle standard 27 -> 26)', () {
      final end = service.nextCycleEndDate(
        previousStartDate: DateTime(2026, 7, 27),
        previousEndDate: DateTime(2026, 8, 26),
        newStartDate: DateTime(2026, 8, 27),
      );
      expect(end, DateTime(2026, 9, 26));
    });

    test('conserve la durée exacte pour un cycle personnalisé (ex : 45 jours)', () {
      final end = service.nextCycleEndDate(
        previousStartDate: DateTime(2026, 1, 1),
        previousEndDate: DateTime(2026, 2, 15), // 45 jours
        newStartDate: DateTime(2026, 2, 16),
      );
      expect(end.difference(DateTime(2026, 2, 16)).inDays, 45);
    });
  });

  group('recurringEntryDateForNextCycle', () {
    test('avance d\'un mois pour un jour valide dans les deux mois', () {
      expect(service.recurringEntryDateForNextCycle(DateTime(2026, 1, 15)), DateTime(2026, 2, 15));
    });

    test('31 janvier -> 28 février (année non bissextile)', () {
      expect(service.recurringEntryDateForNextCycle(DateTime(2026, 1, 31)), DateTime(2026, 2, 28));
    });

    test('31 janvier -> 29 février (année bissextile)', () {
      expect(service.recurringEntryDateForNextCycle(DateTime(2028, 1, 31)), DateTime(2028, 2, 29));
    });

    test('31 mars -> 30 avril (mois à 30 jours)', () {
      expect(service.recurringEntryDateForNextCycle(DateTime(2026, 3, 31)), DateTime(2026, 4, 30));
    });

    test('traverse un changement d\'année', () {
      expect(service.recurringEntryDateForNextCycle(DateTime(2026, 12, 15)), DateTime(2027, 1, 15));
    });
  });
}
