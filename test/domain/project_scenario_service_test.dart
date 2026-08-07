import 'package:flutter_test/flutter_test.dart';

import 'package:budgetpilot/core/constants/app_constants.dart';
import 'package:budgetpilot/domain/calculations/project_scenario_service.dart';
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
  int? desiredDurationMonths = 60,
  double? estimatedRatePercent = 4.0,
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
    desiredDurationMonths: desiredDurationMonths,
    estimatedRatePercent: estimatedRatePercent,
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
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  const service = ProjectScenarioService();
  final now = DateTime(2026, 1, 1);

  group('generate', () {
    test('propose "attendre la fin du crédit" quand un crédit actif existe', () {
      final scenarios = service.generate(
        project: _project(),
        currentFreeCashCents: 40000,
        totalIncomeCents: 300000,
        activeCredits: [_credit(id: 1, name: 'Auto', monthlyPaymentCents: 28000, remainingInstallments: 11)],
        now: now,
      );

      final wait = scenarios.where((s) => s.type == ProjectScenarioType.waitForCredit);
      expect(wait, isNotEmpty);
      expect(wait.first.horizonMonths, 11);
      expect(wait.first.monthlyPaymentFreedCents, 28000);
      expect(wait.first.newScore, greaterThan(wait.first.baselineScore));
    });

    test('un crédit qui se termine améliore aussi le score de sécurité, pas seulement la faisabilité', () {
      // Projet modeste (mensualité significative face à l'argent libre
      // actuel, mais pas déjà hors de portée) : la fin du crédit "Auto"
      // libère assez de marge pour faire bouger la sécurité, sans que les
      // deux scores soient déjà saturés au plancher ou au plafond.
      final scenarios = service.generate(
        project: _project(targetAmountCents: 600000, availableContributionCents: 200000, desiredDurationMonths: 36),
        currentFreeCashCents: 40000,
        totalIncomeCents: 300000,
        activeCredits: [_credit(id: 1, name: 'Auto', monthlyPaymentCents: 28000, remainingInstallments: 11)],
        now: now,
      );

      final wait = scenarios.firstWhere((s) => s.type == ProjectScenarioType.waitForCredit);
      expect(wait.newSafetyScore, greaterThan(wait.baselineSafetyScore));
    });

    test('aucun scénario "attendre un crédit" sans crédit actif', () {
      final scenarios = service.generate(
        project: _project(),
        currentFreeCashCents: 40000,
        totalIncomeCents: 300000,
        activeCredits: const [],
        now: now,
      );

      expect(scenarios.where((s) => s.type == ProjectScenarioType.waitForCredit), isEmpty);
    });

    test('ignore un crédit trop lointain pour "attendre sa fin"', () {
      final scenarios = service.generate(
        project: _project(),
        currentFreeCashCents: 40000,
        totalIncomeCents: 300000,
        activeCredits: [_credit(id: 1, name: 'Lointain', remainingInstallments: 200)],
        now: now,
      );

      expect(scenarios.where((s) => s.type == ProjectScenarioType.waitForCredit), isEmpty);
    });

    test('propose "augmenter l\'apport" quand un financement est nécessaire', () {
      final scenarios = service.generate(
        project: _project(targetAmountCents: 4000000, availableContributionCents: 800000),
        currentFreeCashCents: 40000,
        totalIncomeCents: 300000,
        activeCredits: const [],
        now: now,
      );

      final increase = scenarios.where((s) => s.type == ProjectScenarioType.increaseContribution);
      expect(increase, isNotEmpty);
      expect(increase.first.cashRequiredCents, greaterThan(0));
      expect(increase.first.newScore, greaterThanOrEqualTo(increase.first.baselineScore));
    });

    test('aucun scénario "augmenter l\'apport" si le projet est déjà entièrement couvert', () {
      final scenarios = service.generate(
        project: _project(targetAmountCents: 500000, availableContributionCents: 500000),
        currentFreeCashCents: 40000,
        totalIncomeCents: 300000,
        activeCredits: const [],
        now: now,
      );

      expect(scenarios.where((s) => s.type == ProjectScenarioType.increaseContribution), isEmpty);
    });

    test('propose "solder un crédit" seulement si l\'apport disponible couvre son capital restant', () {
      final withEnoughContribution = service.generate(
        project: _project(availableContributionCents: 100000),
        currentFreeCashCents: 40000,
        totalIncomeCents: 300000,
        activeCredits: [_credit(id: 1, name: 'Petit crédit', remainingCapitalCents: 80000, monthlyPaymentCents: 15000)],
        now: now,
      );
      final withoutEnoughContribution = service.generate(
        project: _project(availableContributionCents: 10000),
        currentFreeCashCents: 40000,
        totalIncomeCents: 300000,
        activeCredits: [_credit(id: 1, name: 'Petit crédit', remainingCapitalCents: 80000, monthlyPaymentCents: 15000)],
        now: now,
      );

      expect(withEnoughContribution.where((s) => s.type == ProjectScenarioType.payoffCredit), isNotEmpty);
      expect(withoutEnoughContribution.where((s) => s.type == ProjectScenarioType.payoffCredit), isEmpty);
    });

    test('"solder un crédit" retire l\'apport utilisé — comparaison réelle apport vs remboursement', () {
      final scenarios = service.generate(
        project: _project(availableContributionCents: 100000, targetAmountCents: 4000000),
        currentFreeCashCents: 40000,
        totalIncomeCents: 300000,
        activeCredits: [_credit(id: 1, name: 'Petit crédit', remainingCapitalCents: 80000, monthlyPaymentCents: 15000)],
        now: now,
      );
      final payoff = scenarios.firstWhere((s) => s.type == ProjectScenarioType.payoffCredit);

      expect(payoff.cashRequiredCents, 80000);
      expect(payoff.monthlyPaymentFreedCents, 15000);
    });

    test('propose toujours "réduire le budget" et "repousser l\'échéance" (si date fixée)', () {
      final scenarios = service.generate(
        project: _project(desiredDate: DateTime(2027, 1, 1)),
        currentFreeCashCents: 40000,
        totalIncomeCents: 300000,
        activeCredits: const [],
        now: now,
      );

      expect(scenarios.where((s) => s.type == ProjectScenarioType.reduceTarget), isNotEmpty);
      expect(scenarios.where((s) => s.type == ProjectScenarioType.extendHorizon), isNotEmpty);
    });

    test('aucun scénario "repousser l\'échéance" sans date souhaitée', () {
      final scenarios = service.generate(
        project: _project(desiredDate: null),
        currentFreeCashCents: 40000,
        totalIncomeCents: 300000,
        activeCredits: const [],
        now: now,
      );

      expect(scenarios.where((s) => s.type == ProjectScenarioType.extendHorizon), isEmpty);
    });

    test('combine deux leviers quand ils sont tous deux disponibles', () {
      final scenarios = service.generate(
        project: _project(targetAmountCents: 4000000, availableContributionCents: 800000),
        currentFreeCashCents: 40000,
        totalIncomeCents: 300000,
        activeCredits: [_credit(id: 1, name: 'Auto', monthlyPaymentCents: 28000, remainingInstallments: 11)],
        now: now,
      );

      final combined = scenarios.where((s) => s.type == ProjectScenarioType.combined);
      expect(combined, isNotEmpty);
      // Combiner les deux leviers doit au moins égaler le meilleur des deux pris seul.
      final wait = scenarios.firstWhere((s) => s.type == ProjectScenarioType.waitForCredit);
      final contribution = scenarios.firstWhere((s) => s.type == ProjectScenarioType.increaseContribution);
      expect(combined.first.newScore, greaterThanOrEqualTo(wait.newScore));
      expect(combined.first.newScore, greaterThanOrEqualTo(contribution.newScore));
    });
  });

  group('recommend', () {
    test('ne recommande jamais "réduire le budget" quand un autre levier améliore significativement le score', () {
      final scenarios = service.generate(
        project: _project(targetAmountCents: 4000000, availableContributionCents: 800000),
        currentFreeCashCents: 40000,
        totalIncomeCents: 300000,
        activeCredits: [_credit(id: 1, name: 'Auto', monthlyPaymentCents: 28000, remainingInstallments: 11)],
        now: now,
      );

      final recommended = service.recommend(scenarios);
      expect(recommended, isNotNull);
      expect(recommended!.type, isNot(ProjectScenarioType.reduceTarget));
    });

    test('renvoie null pour une liste vide', () {
      expect(service.recommend(const []), isNull);
    });

    test(
        'privilégie la sécurité : un scénario plus sûr est préféré à un scénario plus faisable mais peu sûr '
        '(V1.1, §9)', () {
      const risky = ProjectScenario(
        type: ProjectScenarioType.increaseContribution,
        label: 'Scénario A (faisabilité max, sécurité faible)',
        description: '',
        cashRequiredCents: 100000,
        newFinancingNeededCents: 0,
        newScore: 90,
        baselineScore: 60,
        newSafetyScore: 42,
        baselineSafetyScore: 55,
        newDebtRatioAfter: 0.45,
        newRemainingAfterCents: 30000,
      );
      const safer = ProjectScenario(
        type: ProjectScenarioType.waitForCredit,
        label: 'Scénario B (faisabilité correcte, sécurité saine)',
        description: '',
        horizonMonths: 6,
        newFinancingNeededCents: 0,
        newScore: 83,
        baselineScore: 60,
        newSafetyScore: 88,
        baselineSafetyScore: 55,
        newDebtRatioAfter: 0.25,
        newRemainingAfterCents: 180000,
      );

      final recommended = service.recommend([risky, safer]);

      expect(recommended, safer);
    });

    test(
        'si aucun scénario n\'atteint la sécurité minimale, recommande quand même le meilleur compromis '
        'disponible plutôt que de n\'en proposer aucun', () {
      const onlyRisky = ProjectScenario(
        type: ProjectScenarioType.increaseContribution,
        label: 'Seul scénario disponible',
        description: '',
        newFinancingNeededCents: 0,
        newScore: 70,
        baselineScore: 50,
        newSafetyScore: 30,
        baselineSafetyScore: 20,
        newDebtRatioAfter: 0.5,
        newRemainingAfterCents: 10000,
      );

      final recommended = service.recommend([onlyRisky]);

      expect(recommended, onlyRisky);
    });
  });

  group('buildRoadmap', () {
    test('premier point toujours "Aujourd\'hui" à 0 mois', () {
      final roadmap = service.buildRoadmap(
        project: _project(),
        currentFreeCashCents: 40000,
        activeCredits: const [],
        now: now,
      );

      expect(roadmap.first.label, "Aujourd'hui");
      expect(roadmap.first.monthsFromNow, 0);
    });

    test('ajoute un point par crédit actif, triés chronologiquement', () {
      final roadmap = service.buildRoadmap(
        project: _project(),
        currentFreeCashCents: 40000,
        activeCredits: [
          _credit(id: 1, name: 'Lointain', remainingInstallments: 24, monthlyPaymentCents: 10000),
          _credit(id: 2, name: 'Proche', remainingInstallments: 6, monthlyPaymentCents: 15000),
        ],
        now: now,
      );

      expect(roadmap.map((s) => s.monthsFromNow), [0, 6, 24]);
    });

    test('score croissant au fil des extinctions de crédit (jamais décroissant)', () {
      final roadmap = service.buildRoadmap(
        project: _project(targetAmountCents: 4000000, availableContributionCents: 800000),
        currentFreeCashCents: 40000,
        activeCredits: [_credit(id: 1, name: 'Auto', monthlyPaymentCents: 28000, remainingInstallments: 11)],
        now: now,
      );

      for (var i = 1; i < roadmap.length; i++) {
        expect(roadmap[i].score, greaterThanOrEqualTo(roadmap[i - 1].score));
      }
    });

    test('ajoute un point "apport cible atteint" si une capacité d\'épargne fiable est fournie', () {
      final roadmap = service.buildRoadmap(
        project: _project(availableContributionCents: 800000, desiredContributionCents: 1100000),
        currentFreeCashCents: 40000,
        activeCredits: const [],
        monthlySavingsCapacityCents: 30000,
        now: now,
      );

      expect(roadmap.any((s) => s.label.contains('Apport cible atteint')), isTrue);
    });

    test('n\'invente jamais de point "apport cible" sans capacité d\'épargne connue', () {
      final roadmap = service.buildRoadmap(
        project: _project(availableContributionCents: 800000, desiredContributionCents: 1100000),
        currentFreeCashCents: 40000,
        activeCredits: const [],
        now: now,
      );

      expect(roadmap.any((s) => s.label.contains('Apport cible atteint')), isFalse);
    });
  });
}
