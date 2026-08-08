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

  group('debtRatio (V1.2 — seule formule de taux d\'endettement de l\'application)', () {
    test('mensualités des crédits actifs / revenus mensuels, crédits terminés exclus', () {
      // Mensualités actives : 25000 (Voiture) + 5000 (Montre) + 90000 (Maison) = 120000.
      final ratio = service.debtRatio(activeCredits: service.activeOnly(credits), totalIncomeCents: 300000);
      expect(ratio, closeTo(120000 / 300000, 1e-9));
    });

    test('ajoute une mensualité supplémentaire (ex : financement d\'un projet) au numérateur', () {
      final withoutExtra = service.debtRatio(activeCredits: service.activeOnly(credits), totalIncomeCents: 300000);
      final withExtra = service.debtRatio(
        activeCredits: service.activeOnly(credits),
        totalIncomeCents: 300000,
        extraMonthlyPaymentCents: 30000,
      );
      expect(withExtra, closeTo(withoutExtra + 30000 / 300000, 1e-9));
    });

    test('aucun revenu enregistré => 0.0, jamais une valeur fictive', () {
      expect(service.debtRatio(activeCredits: service.activeOnly(credits), totalIncomeCents: 0), 0.0);
    });

    test('aucun crédit actif => 0.0', () {
      expect(service.debtRatio(activeCredits: const [], totalIncomeCents: 300000), 0.0);
    });
  });

  test('identifie le crédit actif se terminant le plus tôt', () {
    expect(service.earliestEnding(credits)?.name, 'Montre');
  });

  test('identifie le crédit actif au capital restant le plus faible', () {
    expect(service.lowestRemainingCapitalCredit(credits)?.name, 'Montre');
  });

  test('identifie le crédit actif au capital restant le plus élevé', () {
    expect(service.highestRemainingCapitalCredit(credits)?.name, 'Immobilier');
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

  group('priorité automatique (étoiles)', () {
    final samsungFold = _credit(id: 5, name: 'Samsung Fold', remainingCapitalCents: 32000, remainingInstallments: 4);

    test('moins de 6 mensualités restantes => 5 étoiles, "Priorité maximale"', () {
      expect(service.priorityStars(samsungFold), 5);
      expect(service.priorityLabel(samsungFold), 'Priorité maximale');
    });

    test('entre 6 et 24 mensualités restantes (bornes incluses) => 3 étoiles, "Priorité moyenne"', () {
      expect(service.priorityStars(montre), 3); // 8 mensualités
      expect(service.priorityLabel(montre), 'Priorité moyenne');
      final atLowerBound = _credit(id: 6, name: 'Bord bas', remainingInstallments: 6);
      final atUpperBound = _credit(id: 7, name: 'Bord haut', remainingInstallments: 24);
      expect(service.priorityStars(atLowerBound), 3);
      expect(service.priorityStars(atUpperBound), 3);
    });

    test('plus de 24 mensualités restantes => 1 étoile, "Long terme"', () {
      expect(service.priorityStars(voiture), 1); // 36 mensualités
      expect(service.priorityLabel(voiture), 'Long terme');
      expect(service.priorityStars(immobilier), 1); // 220 mensualités
    });
  });

  group('score visuel automatique (CreditPace)', () {
    test('moins de 12 mensualités restantes => veryClose, "Très proche de la fin"', () {
      final samsungFold = _credit(id: 8, name: 'Samsung Fold', remainingInstallments: 4);
      expect(service.creditPace(samsungFold), CreditPace.veryClose);
      expect(service.creditPaceLabel(samsungFold), 'Très proche de la fin');
    });

    test('12 à 47 mensualités restantes => medium, "Moyen terme"', () {
      final atLowerBound = _credit(id: 9, name: 'Bord bas', remainingInstallments: 12);
      final atUpperBound = _credit(id: 10, name: 'Bord haut', remainingInstallments: 47);
      expect(service.creditPace(atLowerBound), CreditPace.medium);
      expect(service.creditPace(atUpperBound), CreditPace.medium);
      expect(service.creditPaceLabel(atLowerBound), 'Moyen terme');
    });

    test('48 à 119 mensualités restantes => long, "Long terme"', () {
      final atLowerBound = _credit(id: 11, name: 'Bord bas', remainingInstallments: 48);
      final atUpperBound = _credit(id: 12, name: 'Bord haut', remainingInstallments: 119);
      expect(service.creditPace(atLowerBound), CreditPace.long);
      expect(service.creditPace(atUpperBound), CreditPace.long);
      expect(service.creditPaceLabel(atLowerBound), 'Long terme');
    });

    test('120 mensualités restantes ou plus => veryLong, "Très longue durée"', () {
      expect(service.creditPace(immobilier), CreditPace.veryLong); // 220 mensualités
      expect(service.creditPaceLabel(immobilier), 'Très longue durée');
    });
  });

  group('simulateAcrossActiveCredits', () {
    test('propose de terminer un crédit quand le versement couvre son capital restant', () {
      final options = simulateAcrossActiveCredits(credits: [voiture, montre, immobilier], extraPaymentCents: 40000);
      final montreOption = options.firstWhere((o) => o.credit.name == 'Montre');
      expect(montreOption.wouldBeFullyRepaid, isTrue);
      expect(montreOption.monthlyPaymentFreedCents, montre.monthlyPaymentCents);
    });

    test('trie les options soldées entièrement en premier', () {
      final options = simulateAcrossActiveCredits(credits: [voiture, montre, immobilier], extraPaymentCents: 40000);
      expect(options.first.credit.name, 'Montre');
      expect(options.first.wouldBeFullyRepaid, isTrue);
    });

    test('ignore les crédits terminés (isActive = false)', () {
      final options = simulateAcrossActiveCredits(credits: credits, extraPaymentCents: 10000);
      expect(options.any((o) => o.credit.name == 'Ancien crédit remboursé'), isFalse);
    });

    test('estime une économie d\'intérêts seulement si un taux est renseigné', () {
      // Voiture (taux 3,5 %) : versement de 200000, capital 900000 -> 700000
      // restant -> mensualités 28 au lieu de 36 -> 8 mois gagnés -> une
      // économie d'intérêts strictement positive est estimée.
      final options = simulateAcrossActiveCredits(credits: [voiture, montre], extraPaymentCents: 200000);
      final voitureOption = options.firstWhere((o) => o.credit.name == 'Voiture');
      final montreOption = options.firstWhere((o) => o.credit.name == 'Montre');
      expect(voitureOption.estimatedInterestSavedCents, isNotNull);
      expect(voitureOption.estimatedInterestSavedCents, greaterThan(0));
      expect(montreOption.estimatedInterestSavedCents, isNull); // pas de taux renseigné
    });

    test('un versement partiel ne solde pas le crédit mais réduit son capital restant', () {
      final options = simulateAcrossActiveCredits(credits: [immobilier], extraPaymentCents: 500000);
      expect(options.single.wouldBeFullyRepaid, isFalse);
      expect(options.single.remainingCapitalAfterCents, immobilier.remainingCapitalCents - 500000);
    });
  });
}
