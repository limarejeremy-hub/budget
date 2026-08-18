import 'package:flutter_test/flutter_test.dart';

import 'package:budgetpilot/core/constants/app_constants.dart';
import 'package:budgetpilot/domain/calculations/recurrence_calculator.dart';

/// Correctif "échéances récurrentes hors cycle" : règle métier fondamentale
/// — une charge n'appartient à un cycle que si la date de son occurrence
/// réelle tombe dans `[cycle.startDate, cycle.endDate]`. Le caractère
/// "récurrent" ne suffit jamais à lui seul.
void main() {
  const calculator = RecurrenceCalculator();

  group('nextOccurrence', () {
    test('mensuel_jour_fixe ajoute un mois, avec repli sur le dernier jour valide', () {
      final next = calculator.nextOccurrence(
        DateTime(2026, 1, 31),
        recurrenceType: RecurrenceType.mensuelJourFixe,
      );
      expect(next, DateTime(2026, 2, 28)); // 2026 n'est pas bissextile
    });

    test('toutes_les_x_semaines avance de 7 * X jours', () {
      final next = calculator.nextOccurrence(
        DateTime(2026, 8, 2),
        recurrenceType: RecurrenceType.toutesLesXSemaines,
        intervalValue: 4,
      );
      expect(next, DateTime(2026, 8, 30)); // 4 semaines = 28 jours
    });

    test('tous_les_x_jours avance de X jours', () {
      final next = calculator.nextOccurrence(
        DateTime(2026, 8, 2),
        recurrenceType: RecurrenceType.tousLesXJours,
        intervalValue: 10,
      );
      expect(next, DateTime(2026, 8, 12));
    });

    test('un intervalle nul ou négatif ne bloque jamais la progression (replié sur 1)', () {
      final next = calculator.nextOccurrence(
        DateTime(2026, 8, 2),
        recurrenceType: RecurrenceType.tousLesXJours,
        intervalValue: 0,
      );
      expect(next, DateTime(2026, 8, 3));
    });
  });

  group('occurrencesInRange — règle métier (cycle.startDate <= dueDate <= cycle.endDate)', () {
    test('échéance strictement avant le début du cycle : jamais comptée', () {
      // Dernière occurrence connue : 20 juillet. Tous les 5 jours, la
      // progression saute par-dessus l'unique jour du cycle (25 puis 30) :
      // aucune occurrence ne tombe jamais dans `[28/07, 28/07]`.
      final occurrences = calculator.occurrencesInRange(
        lastKnownDate: DateTime(2026, 7, 20),
        start: DateTime(2026, 7, 28),
        end: DateTime(2026, 7, 28), // fenêtre volontairement étroite
        recurrenceType: RecurrenceType.tousLesXJours,
        intervalValue: 5,
      );
      expect(occurrences, isEmpty);
    });

    test('échéance le jour de début du cycle : comptée', () {
      final occurrences = calculator.occurrencesInRange(
        lastKnownDate: DateTime(2026, 7, 27),
        start: DateTime(2026, 7, 28),
        end: DateTime(2026, 8, 28),
        recurrenceType: RecurrenceType.tousLesXJours,
        intervalValue: 1,
      );
      expect(occurrences.first, DateTime(2026, 7, 28));
    });

    test('échéance pendant le cycle : comptée', () {
      final occurrences = calculator.occurrencesInRange(
        lastKnownDate: DateTime(2026, 7, 20),
        start: DateTime(2026, 7, 28),
        end: DateTime(2026, 8, 28),
        recurrenceType: RecurrenceType.tousLesXJours,
        intervalValue: 10,
      );
      expect(occurrences, contains(DateTime(2026, 8, 9)));
    });

    test('échéance le jour de fin du cycle : comptée', () {
      final occurrences = calculator.occurrencesInRange(
        lastKnownDate: DateTime(2026, 7, 28),
        start: DateTime(2026, 7, 28),
        end: DateTime(2026, 8, 28),
        recurrenceType: RecurrenceType.tousLesXJours,
        intervalValue: 31,
      );
      expect(occurrences, [DateTime(2026, 8, 28)]);
    });

    test('échéance le lendemain de la fin du cycle : jamais comptée (cas de référence)', () {
      // Cas de référence exact du correctif : cycle 28/07/2026 -> 28/08/2026,
      // occurrence le 30/08/2026 -> 0 occurrence retenue dans ce cycle.
      final occurrences = calculator.occurrencesInRange(
        lastKnownDate: DateTime(2026, 7, 28),
        start: DateTime(2026, 7, 28),
        end: DateTime(2026, 8, 28),
        recurrenceType: RecurrenceType.tousLesXJours,
        intervalValue: 33, // 28 juillet + 33 jours = 30 août
      );
      expect(occurrences, isEmpty);
    });

    test('deux occurrences de la même charge dans un même cycle (toutes les 4 semaines)', () {
      // Cycle 29 août -> 28 septembre (31 jours). Dernière occurrence
      // connue : 2 août. Toutes les 4 semaines (28 jours) : 30 août et 27
      // septembre tombent toutes deux dans ce cycle.
      final occurrences = calculator.occurrencesInRange(
        lastKnownDate: DateTime(2026, 8, 2),
        start: DateTime(2026, 8, 29),
        end: DateTime(2026, 9, 28),
        recurrenceType: RecurrenceType.toutesLesXSemaines,
        intervalValue: 4,
      );
      expect(occurrences, [DateTime(2026, 8, 30), DateTime(2026, 9, 27)]);
    });

    test('zéro occurrence dans un cycle (intervalle plus long que la période)', () {
      final occurrences = calculator.occurrencesInRange(
        lastKnownDate: DateTime(2026, 1, 1),
        start: DateTime(2026, 2, 1),
        end: DateTime(2026, 2, 28),
        recurrenceType: RecurrenceType.tousLesXJours,
        intervalValue: 90,
      );
      expect(occurrences, isEmpty);
    });

    test('charge mensuelle classique : une occurrence par cycle mensuel standard', () {
      final occurrences = calculator.occurrencesInRange(
        lastKnownDate: DateTime(2026, 6, 27),
        start: DateTime(2026, 7, 27),
        end: DateTime(2026, 8, 26),
        recurrenceType: RecurrenceType.mensuelJourFixe,
      );
      expect(occurrences, [DateTime(2026, 7, 27)]);
    });
  });
}
