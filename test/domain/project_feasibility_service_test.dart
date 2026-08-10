import 'package:flutter_test/flutter_test.dart';

import 'package:budgetpilot/core/constants/app_constants.dart';
import 'package:budgetpilot/domain/calculations/project_feasibility_service.dart';
import 'package:budgetpilot/domain/entities/credit_entity.dart';
import 'package:budgetpilot/domain/entities/project_entity.dart';

ProjectEntity _project({
  int id = 1,
  String name = 'Projet',
  String category = ProjectCategory.car,
  int targetAmountCents = 4000000,
  DateTime? desiredDate,
  int availableContributionCents = 800000,
  int? desiredContributionCents,
  String financingMode = ProjectFinancingMode.mixed,
  int? maxMonthlyPaymentCents,
  int? desiredDurationMonths = 60,
  double? estimatedRatePercent,
  int? extraMonthlyCostCents,
}) {
  final now = DateTime(2026, 1, 1);
  return ProjectEntity(
    id: id,
    name: name,
    category: category,
    targetAmountCents: targetAmountCents,
    desiredDate: desiredDate,
    availableContributionCents: availableContributionCents,
    desiredContributionCents: desiredContributionCents,
    financingMode: financingMode,
    maxMonthlyPaymentCents: maxMonthlyPaymentCents,
    desiredDurationMonths: desiredDurationMonths,
    estimatedRatePercent: estimatedRatePercent,
    extraMonthlyCostCents: extraMonthlyCostCents,
    createdAt: now,
    updatedAt: now,
  );
}

CreditEntity _credit({
  required int id,
  required String name,
  int remainingCapitalCents = 500000,
  int monthlyPaymentCents = 20000,
  int remainingInstallments = 12,
  bool isActive = true,
}) {
  final now = DateTime(2026, 1, 1);
  return CreditEntity(
    id: id,
    name: name,
    initialAmountCents: remainingCapitalCents * 2,
    remainingCapitalCents: remainingCapitalCents,
    monthlyPaymentCents: monthlyPaymentCents,
    expectedEndDate: now.add(Duration(days: remainingInstallments * 30)),
    remainingInstallments: remainingInstallments,
    isActive: isActive,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  const service = ProjectFeasibilityService();
  final now = DateTime(2026, 1, 1);

  group('computeFinancing', () {
    test('projet comptant : aucune mensualité, écart = prix - apport', () {
      final project = _project(
        financingMode: ProjectFinancingMode.cash,
        targetAmountCents: 600000,
        availableContributionCents: 450000,
      );
      final financing = service.computeFinancing(project);

      expect(financing.financingNeededCents, 150000);
      expect(financing.estimatedMonthlyPaymentCents, 0);
      expect(financing.totalMonthlyImpactCents, 0);
      expect(financing.isDurationEstimated, isFalse);
      expect(financing.isRateEstimated, isFalse);
    });

    test('apport nul : tout le prix doit être financé', () {
      final project = _project(
        financingMode: ProjectFinancingMode.financed,
        targetAmountCents: 1000000,
        availableContributionCents: 0,
      );
      final financing = service.computeFinancing(project);

      expect(financing.financingNeededCents, 1000000);
    });

    test('apport couvrant 100% du prix : aucun financement nécessaire même en mode financé', () {
      final project = _project(
        financingMode: ProjectFinancingMode.financed,
        targetAmountCents: 500000,
        availableContributionCents: 600000,
      );
      final financing = service.computeFinancing(project);

      expect(financing.financingNeededCents, 0);
      expect(financing.estimatedMonthlyPaymentCents, 0);
    });

    test('taux absent : mensualité estimée simplifiée (linéaire), signalée comme estimée', () {
      final project = _project(
        financingMode: ProjectFinancingMode.financed,
        targetAmountCents: 1200000,
        availableContributionCents: 0,
        desiredDurationMonths: 60,
        estimatedRatePercent: null,
      );
      final financing = service.computeFinancing(project);

      expect(financing.isRateEstimated, isTrue);
      expect(financing.estimatedMonthlyPaymentCents, 20000); // 1 200 000 / 60
    });

    test('taux renseigné : mensualité par amortissement, plus élevée que l\'estimation linéaire', () {
      final project = _project(
        financingMode: ProjectFinancingMode.financed,
        targetAmountCents: 1200000,
        availableContributionCents: 0,
        desiredDurationMonths: 60,
        estimatedRatePercent: 5.0,
      );
      final financing = service.computeFinancing(project);

      expect(financing.isRateEstimated, isFalse);
      // L'amortissement inclut des intérêts : la mensualité (et le coût
      // total) sont toujours supérieurs à l'estimation linéaire sans taux.
      expect(financing.estimatedMonthlyPaymentCents, greaterThan(20000));
      expect(financing.estimatedMonthlyPaymentCents * 60, greaterThan(1200000));
    });

    test('un taux plus élevé produit toujours une mensualité plus élevée à durée égale', () {
      final low = service.computeFinancing(_project(
        financingMode: ProjectFinancingMode.financed,
        availableContributionCents: 0,
        targetAmountCents: 2000000,
        desiredDurationMonths: 48,
        estimatedRatePercent: 2.0,
      ));
      final high = service.computeFinancing(_project(
        financingMode: ProjectFinancingMode.financed,
        availableContributionCents: 0,
        targetAmountCents: 2000000,
        desiredDurationMonths: 48,
        estimatedRatePercent: 8.0,
      ));

      expect(high.estimatedMonthlyPaymentCents, greaterThan(low.estimatedMonthlyPaymentCents));
    });

    test('ni durée ni mensualité max renseignées : durée par défaut utilisée et signalée', () {
      final project = _project(
        financingMode: ProjectFinancingMode.financed,
        targetAmountCents: 1000000,
        availableContributionCents: 0,
        desiredDurationMonths: null,
        maxMonthlyPaymentCents: null,
      );
      final financing = service.computeFinancing(project);

      expect(financing.isDurationEstimated, isTrue);
      expect(financing.usedDurationMonths, kDefaultFinancingDurationMonths);
    });

    test('mensualité maximale renseignée sans durée : durée déduite, non signalée comme estimée', () {
      final project = _project(
        financingMode: ProjectFinancingMode.financed,
        targetAmountCents: 1200000,
        availableContributionCents: 0,
        desiredDurationMonths: null,
        maxMonthlyPaymentCents: 20000,
        estimatedRatePercent: null,
      );
      final financing = service.computeFinancing(project);

      expect(financing.isDurationEstimated, isFalse);
      expect(financing.estimatedMonthlyPaymentCents, lessThanOrEqualTo(20000));
    });

    test('coûts mensuels supplémentaires inclus dans l\'impact mensuel total', () {
      final project = _project(
        financingMode: ProjectFinancingMode.financed,
        targetAmountCents: 1200000,
        availableContributionCents: 0,
        desiredDurationMonths: 60,
        extraMonthlyCostCents: 12000,
      );
      final financing = service.computeFinancing(project);

      expect(financing.extraMonthlyCostCents, 12000);
      expect(financing.totalMonthlyImpactCents, financing.estimatedMonthlyPaymentCents + 12000);
    });
  });

  group('evaluate — score', () {
    test('situation confortable : gros argent libre, apport élevé => score élevé, niveau confortable', () {
      final project = _project(
        targetAmountCents: 1000000,
        availableContributionCents: 900000,
        desiredDurationMonths: 60,
        estimatedRatePercent: 3.0,
      );
      final result = service.evaluate(
        project: project,
        currentFreeCashCents: 200000,
        activeCredits: const [],
        now: now,
      );

      expect(result.totalScore, greaterThanOrEqualTo(75));
      expect(
        result.level,
        anyOf(FeasibilityLevel.comfortable, FeasibilityLevel.veryComfortable),
      );
      expect(result.blockers, isEmpty);
    });

    test('situation fragile : gros projet, argent libre faible, aucun apport => score faible', () {
      final project = _project(
        targetAmountCents: 4000000,
        availableContributionCents: 0,
        desiredDurationMonths: 60,
        estimatedRatePercent: 4.0,
      );
      final result = service.evaluate(
        project: project,
        currentFreeCashCents: 15000,
        activeCredits: const [],
        now: now,
      );

      expect(result.totalScore, lessThan(60));
      expect(result.blockers, isNotEmpty);
    });

    test('projet largement supérieur aux capacités : marge négative, score très faible', () {
      final project = _project(
        targetAmountCents: 10000000,
        availableContributionCents: 0,
        desiredDurationMonths: 24,
        estimatedRatePercent: 5.0,
      );
      final result = service.evaluate(
        project: project,
        currentFreeCashCents: 30000,
        activeCredits: const [],
        now: now,
      );

      expect(result.marginAfterCents, lessThan(0));
      expect(result.score.capacityScore, 0);
      expect(result.level, FeasibilityLevel.veryDifficult);
    });

    test('apport nul => score C = 0', () {
      final project = _project(availableContributionCents: 0, targetAmountCents: 500000);
      final result = service.evaluate(
        project: project,
        currentFreeCashCents: 100000,
        activeCredits: const [],
        now: now,
      );
      expect(result.score.contributionScore, 0);
    });

    test('apport couvrant 100% du prix => score C = 100', () {
      final project = _project(availableContributionCents: 500000, targetAmountCents: 500000);
      final result = service.evaluate(
        project: project,
        currentFreeCashCents: 100000,
        activeCredits: const [],
        now: now,
      );
      expect(result.score.contributionScore, 100);
    });

    test('pression des crédits : des crédits déjà lourds abaissent le score D', () {
      final project = _project();
      final withoutCredits = service.evaluate(
        project: project,
        currentFreeCashCents: 100000,
        activeCredits: const [],
        now: now,
      );
      final withHeavyCredits = service.evaluate(
        project: project,
        currentFreeCashCents: 100000,
        activeCredits: [
          _credit(id: 1, name: 'Voiture', monthlyPaymentCents: 80000, remainingInstallments: 24),
        ],
        now: now,
      );

      expect(withHeavyCredits.score.creditPressureScore, lessThan(withoutCredits.score.creditPressureScore));
    });

    test('sans date souhaitée : score horizon neutre (50)', () {
      final project = _project(desiredDate: null);
      final result = service.evaluate(
        project: project,
        currentFreeCashCents: 50000,
        activeCredits: const [],
        now: now,
      );
      expect(result.score.horizonScore, 50);
    });

    test('projet déjà finançable aujourd\'hui : score horizon maximal quelle que soit la date', () {
      final project = _project(
        targetAmountCents: 100000,
        availableContributionCents: 100000,
        desiredDate: DateTime(2026, 2, 1),
      );
      final result = service.evaluate(
        project: project,
        currentFreeCashCents: 50000,
        activeCredits: const [],
        now: now,
      );
      expect(result.score.horizonScore, 100);
    });
  });

  group('crédits en fin de vie — "ce qui va s\'améliorer"', () {
    test('un crédit se terminant bientôt apparaît dans les améliorations à venir', () {
      final project = _project(
        targetAmountCents: 4000000,
        availableContributionCents: 800000,
        desiredDurationMonths: 60,
        estimatedRatePercent: 4.0,
      );
      final autoCredit = _credit(
        id: 1,
        name: 'Crédit Auto',
        monthlyPaymentCents: 28000,
        remainingInstallments: 11,
      );
      final result = service.evaluate(
        project: project,
        currentFreeCashCents: 40000,
        activeCredits: [autoCredit],
        now: now,
      );

      expect(result.upcomingImprovements, hasLength(1));
      expect(result.upcomingImprovements.single.credit.name, 'Crédit Auto');
      expect(result.upcomingImprovements.single.monthsUntilFreed, 11);
      expect(result.upcomingImprovements.single.monthlyPaymentFreedCents, 28000);
    });

    test('plusieurs crédits à échéances différentes sont triés par date de fin la plus proche', () {
      final project = _project();
      final result = service.evaluate(
        project: project,
        currentFreeCashCents: 40000,
        activeCredits: [
          _credit(id: 1, name: 'Lointain', remainingInstallments: 30, monthlyPaymentCents: 10000),
          _credit(id: 2, name: 'Proche', remainingInstallments: 6, monthlyPaymentCents: 15000),
          _credit(id: 3, name: 'Terminé', remainingInstallments: 0, monthlyPaymentCents: 5000),
        ],
        now: now,
      );

      expect(result.upcomingImprovements.map((i) => i.credit.name), ['Proche', 'Lointain']);
    });

    test('un crédit trop lointain (hors horizon) n\'apparaît pas dans les améliorations', () {
      final project = _project(desiredDate: null);
      final result = service.evaluate(
        project: project,
        currentFreeCashCents: 40000,
        activeCredits: [
          _credit(id: 1, name: 'Très lointain', remainingInstallments: 200, monthlyPaymentCents: 10000),
        ],
        now: now,
      );

      expect(result.upcomingImprovements, isEmpty);
    });

    test('un crédit qui se termine libère assez de capacité : la faisabilité future dépasse la faisabilité actuelle',
        () {
      final project = _project(
        targetAmountCents: 3000000,
        availableContributionCents: 800000,
        desiredDurationMonths: 48,
        estimatedRatePercent: 4.0,
      );
      final autoCredit = _credit(
        id: 1,
        name: 'Crédit Auto',
        monthlyPaymentCents: 28000,
        remainingInstallments: 11,
      );

      final today = service.evaluate(
        project: project,
        currentFreeCashCents: 45000,
        activeCredits: [autoCredit],
        now: now,
      );
      // Simule "après extinction du crédit" : plus de crédit actif, et la
      // capacité libérée s'ajoute à l'argent libre.
      final afterCreditEnds = service.evaluate(
        project: project,
        currentFreeCashCents: 45000 + 28000,
        activeCredits: const [],
        now: now,
      );

      expect(afterCreditEnds.totalScore, greaterThan(today.totalScore));
    });
  });

  group('modes de financement', () {
    test('mode mixte : combine apport partiel et financement du reste', () {
      final project = _project(
        financingMode: ProjectFinancingMode.mixed,
        targetAmountCents: 4000000,
        availableContributionCents: 800000,
        desiredDurationMonths: 60,
        estimatedRatePercent: 3.0,
      );
      final financing = service.computeFinancing(project);

      expect(financing.contributionCents, 800000);
      expect(financing.financingNeededCents, 3200000);
      expect(financing.estimatedMonthlyPaymentCents, greaterThan(0));
    });

    test('projet comptant : jamais de mensualité de financement même avec un fort écart', () {
      final project = _project(
        financingMode: ProjectFinancingMode.cash,
        targetAmountCents: 600000,
        availableContributionCents: 450000,
      );
      final result = service.evaluate(
        project: project,
        currentFreeCashCents: 30000,
        activeCredits: const [],
        now: now,
      );

      expect(result.financing.estimatedMonthlyPaymentCents, 0);
    });
  });
}
