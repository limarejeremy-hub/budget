import 'package:flutter_test/flutter_test.dart';

import 'package:budgetpilot/domain/entities/credit_entity.dart';

CreditEntity _credit({
  int initialAmountCents = 0,
  int remainingCapitalCents = 0,
  int monthlyPaymentCents = 10000,
  DateTime? startDate,
  DateTime? expectedEndDate,
  int remainingInstallments = 0,
}) {
  final now = DateTime(2026, 1, 1);
  return CreditEntity(
    id: 1,
    name: 'Test',
    initialAmountCents: initialAmountCents,
    remainingCapitalCents: remainingCapitalCents,
    monthlyPaymentCents: monthlyPaymentCents,
    startDate: startDate,
    expectedEndDate: expectedEndDate ?? DateTime(2027, 1, 1),
    remainingInstallments: remainingInstallments,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('repaidProgress — 1. montant initial connu', () {
    test('utilise (initial - restant) / initial quand le montant initial est > 0', () {
      final credit = _credit(initialAmountCents: 100000, remainingCapitalCents: 60000);
      expect(credit.repaidProgress, closeTo(0.4, 0.0001));
    });

    test('reste borné à 1.0 même si le capital restant est négatif par erreur', () {
      final credit = _credit(initialAmountCents: 100000, remainingCapitalCents: -5000);
      expect(credit.repaidProgress, 1.0);
    });

    test('reste borné à 0.0 si le capital restant dépasse le montant initial', () {
      final credit = _credit(initialAmountCents: 100000, remainingCapitalCents: 150000);
      expect(credit.repaidProgress, 0.0);
    });
  });

  group('repaidProgress — 2. repli sur la durée totale (montant initial inconnu)', () {
    test('utilise (durée totale - mensualités restantes) / durée totale quand la date de début est connue', () {
      // Montant initial à 0 (inconnu) ; durée totale = 24 mois (2024-01-01 ->
      // 2026-01-01) ; 6 mensualités restantes -> 18/24 = 0.75.
      final credit = _credit(
        initialAmountCents: 0,
        remainingCapitalCents: 40000,
        startDate: DateTime(2024, 1, 1),
        expectedEndDate: DateTime(2026, 1, 1),
        remainingInstallments: 6,
      );
      expect(credit.repaidProgress, closeTo(0.75, 0.0001));
    });
  });

  group('repaidProgress — 3. dernier recours (ni montant initial ni dates exploitables)', () {
    test('capital restant nul => considéré comme soldé (1.0)', () {
      final credit = _credit(initialAmountCents: 0, remainingCapitalCents: 0, remainingInstallments: 0);
      expect(credit.repaidProgress, 1.0);
    });

    test('capital restant non nul et aucune donnée exploitable => 0.0', () {
      final credit = _credit(initialAmountCents: 0, remainingCapitalCents: 50000, remainingInstallments: 10);
      expect(credit.repaidProgress, 0.0);
    });
  });
}
