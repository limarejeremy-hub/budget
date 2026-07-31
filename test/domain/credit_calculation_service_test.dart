import 'package:flutter_test/flutter_test.dart';

import 'package:budgetpilot/domain/calculations/credit_calculation_service.dart';
import 'package:budgetpilot/domain/entities/credit_entity.dart';

CreditEntity _credit({
  required int id,
  required String name,
  int remainingCapitalCents = 100000,
  int monthlyPaymentCents = 10000,
  double? annualRatePercent,
  DateTime? expectedEndDate,
  int remainingInstallments = 10,
  bool isActive = true,
}) {
  final now = DateTime(2026, 1, 1);
  return CreditEntity(
    id: id,
    name: name,
    initialAmountCents: remainingCapitalCents * 2,
    remainingCapitalCents: remainingCapitalCents,
    monthlyPaymentCents: monthlyPaymentCents,
    annualRatePercent: annualRatePercent,
    expectedEndDate: expectedEndDate ?? DateTime(2027, 1, 1),
    remainingInstallments: remainingInstallments,
    isActive: isActive,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  const service = CreditCalculationService();

  final voiture = _credit(
    id: 1,
    name: 'Voiture',
    remainingCapitalCents: 900000,
    monthlyPaymentCents: 25000,
    annualRatePercent: 3.5,
    expectedEndDate: DateTime(2029, 6, 1),
    remainingInstallments: 36,
  );
  final montre = _credit(
    id: 2,
    name: 'Montre',
    remainingCapitalCents: 40000,
    monthlyPaymentCents: 5000,
    annualRatePercent: null,
    expectedEndDate: DateTime(2027, 3, 1),
    remainingInstallments: 8,
  );
  final immobilier = _credit(
    id: 3,
    name: 'Immobilier',
    remainingCapitalCents: 15000000,
    monthlyPaymentCents: 90000,
    annualRatePercent: 1.2,
    expectedEndDate: DateTime(2045, 1, 1),
    remainingInstallments: 220,
  );
  final creditSolde = _credit(
    id: 4,
    name: 'Ancien crédit remboursé',
    remainingCapitalCents: 0,
    monthlyPaymentCents: 0,
    expectedEndDate: DateTime(2024, 1, 1),
    remainingInstallments: 0,
    isActive: false,
  );

  final credits = [voiture, montre, immobilier, creditSolde];

  test('calcule le capital restant total (crédits actifs uniquement)', () {
    expect(service.totalRemainingCapital(credits), 900000 + 40000 + 15000000);
  });

  test('calcule les mensualités totales (crédits actifs uniquement)', () {
    expect(service.totalMonthlyPayments(credits), 25000 + 5000 + 90000);
  });

  test('activeCount exclut les crédits terminés', () {
    expect(service.activeCount(credits), 3);
  });

  test('identifie le crédit actif se terminant le plus tôt', () {
    expect(service.earliestEnding(credits)?.name, 'Montre');
  });

  test('identifie le crédit actif au capital restant le plus faible', () {
    expect(service.lowestRemainingCapitalCredit(credits)?.name, 'Montre');
  });

  test('identifie le crédit actif à la mensualité la plus élevée', () {
    expect(service.highestMonthlyPaymentCredit(credits)?.name, 'Immobilier');
  });

  test('identifie le crédit actif au taux le plus élevé', () {
    expect(service.highestRateCredit(credits)?.name, 'Voiture');
  });

  test('highestRateCredit renvoie null si aucun taux actif renseigné', () {
    final noRates = [montre]; // seul crédit actif de la liste, sans taux
    expect(service.highestRateCredit(noRates), isNull);
  });

  test('tri "plus facile à solder" : capital restant croissant', () {
    final sorted = service.sortByLowestCapital([voiture, montre, immobilier]);
    expect(sorted.map((c) => c.name), ['Montre', 'Voiture', 'Immobilier']);
  });

  test('tri "plus coûteux" : taux décroissant, taux non renseigné toujours en dernier', () {
    final sorted = service.sortByHighestRate([voiture, montre, immobilier]);
    expect(sorted.map((c) => c.name), ['Voiture', 'Immobilier', 'Montre']);
  });

  test('tri "plus grosse mensualité libérée" : mensualité décroissante', () {
    final sorted = service.sortByHighestPayment([voiture, montre, immobilier]);
    expect(sorted.map((c) => c.name), ['Immobilier', 'Voiture', 'Montre']);
  });

  group('simulateCreditPrepayment', () {
    test('réduit le capital restant du montant versé', () {
      final result = simulateCreditPrepayment(credit: montre, extraPaymentCents: 20000);
      expect(result.remainingCapitalAfterCents, 20000);
    });

    test('ne descend jamais sous zéro même si le versement dépasse le capital restant', () {
      final result = simulateCreditPrepayment(credit: montre, extraPaymentCents: 999999);
      expect(result.remainingCapitalAfterCents, 0);
      expect(result.theoreticalRemainingInstallments, 0);
    });

    test('estime des mensualités théoriques restantes réduites et des mois gagnés', () {
      // Montre : capital 40000, mensualité 5000 -> 8 mensualités théoriques.
      // Versement de 15000 -> capital restant 25000 -> 5 mensualités.
      final result = simulateCreditPrepayment(credit: montre, extraPaymentCents: 15000);
      expect(result.theoreticalRemainingInstallments, 5);
      expect(result.monthsSaved, 3);
      expect(result.estimatedEndDate.isBefore(montre.expectedEndDate), isTrue);
    });

    test('un versement nul ne change rien', () {
      final result = simulateCreditPrepayment(credit: montre, extraPaymentCents: 0);
      expect(result.remainingCapitalAfterCents, montre.remainingCapitalCents);
      expect(result.monthsSaved, 0);
      expect(result.estimatedEndDate, montre.expectedEndDate);
    });
  });
}
