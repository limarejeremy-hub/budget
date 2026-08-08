import 'package:flutter_test/flutter_test.dart';

import 'package:budgetpilot/core/constants/app_constants.dart';
import 'package:budgetpilot/domain/calculations/project_debt_impact_service.dart';
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
  const service = ProjectDebtImpactService();

  group('reste à vivre', () {
    test('reste à vivre après = reste à vivre actuel - impact mensuel du projet', () {
      final result = service.evaluate(
        project: _project(availableContributionCents: 3000000, desiredDurationMonths: 60, estimatedRatePercent: 3.0),
        currentFreeCashCents: 200000,
        totalIncomeCents: 300000,
        activeCredits: const [],
      );

      expect(result.remainingBeforeCents, 200000);
      expect(result.remainingAfterCents, 200000 - result.marginConsumedByProjectCents);
      expect(result.remainingDeltaCents, result.remainingAfterCents - 200000);
    });

    test(
        'revenu modifié : ne change jamais le reste à vivre (indépendant du revenu), mais change le taux '
        "d'endettement (dépend du revenu)", () {
      final lowIncome = service.evaluate(
        project: _project(),
        currentFreeCashCents: 100000,
        totalIncomeCents: 150000,
        activeCredits: const [],
      );
      final highIncome = service.evaluate(
        project: _project(),
        currentFreeCashCents: 100000,
        totalIncomeCents: 500000,
        activeCredits: const [],
      );

      expect(highIncome.remainingAfterCents, lowIncome.remainingAfterCents);
      expect(highIncome.debtRatioAfter, lessThan(lowIncome.debtRatioAfter));
    });

    test('charge modifiée (argent libre différent) change le reste à vivre après projet', () {
      final before = service.evaluate(
        project: _project(),
        currentFreeCashCents: 300000,
        totalIncomeCents: 400000,
        activeCredits: const [],
      );
      final afterNewCharge = service.evaluate(
        project: _project(),
        currentFreeCashCents: 200000, // une charge supplémentaire a réduit l'argent libre
        totalIncomeCents: 400000,
        activeCredits: const [],
      );

      expect(afterNewCharge.remainingAfterCents, lessThan(before.remainingAfterCents));
    });
  });

  group("taux d'endettement", () {
    test('ne compte que les mensualités de crédit, jamais les coûts supplémentaires', () {
      final withoutExtra = service.evaluate(
        project: _project(financingMode: ProjectFinancingMode.cash, extraMonthlyCostCents: null),
        currentFreeCashCents: 300000,
        totalIncomeCents: 300000,
        activeCredits: [_credit(id: 1, name: 'Auto', monthlyPaymentCents: 50000)],
      );
      final withExtra = service.evaluate(
        project: _project(financingMode: ProjectFinancingMode.cash, extraMonthlyCostCents: 40000),
        currentFreeCashCents: 300000,
        totalIncomeCents: 300000,
        activeCredits: [_credit(id: 1, name: 'Auto', monthlyPaymentCents: 50000)],
      );

      expect(withoutExtra.debtRatioAfter, withExtra.debtRatioAfter);
      // Les coûts supplémentaires pèsent en revanche bien sur le reste à
      // vivre — c'est là, et uniquement là, qu'ils sont comptés.
      expect(withExtra.remainingAfterCents, lessThan(withoutExtra.remainingAfterCents));
    });

    test("taux d'endettement après intègre la mensualité de financement du projet", () {
      final cash = service.evaluate(
        project: _project(financingMode: ProjectFinancingMode.cash),
        currentFreeCashCents: 300000,
        totalIncomeCents: 300000,
        activeCredits: [_credit(id: 1, name: 'Auto', monthlyPaymentCents: 50000)],
      );
      final financed = service.evaluate(
        project: _project(financingMode: ProjectFinancingMode.financed, availableContributionCents: 0),
        currentFreeCashCents: 300000,
        totalIncomeCents: 300000,
        activeCredits: [_credit(id: 1, name: 'Auto', monthlyPaymentCents: 50000)],
      );

      expect(financed.debtRatioAfter, greaterThan(cash.debtRatioAfter));
      expect(cash.debtRatioAfter, cash.debtRatioBefore);
    });

    test('bandes de lecture du taux d\'endettement — repères internes, jamais une règle bancaire', () {
      expect(debtRatioBandFor(0.20), DebtRatioBand.comfortable);
      expect(debtRatioBandFor(0.32), DebtRatioBand.watch);
      expect(debtRatioBandFor(0.38), DebtRatioBand.tense);
      expect(debtRatioBandFor(0.50), DebtRatioBand.high);
    });
  });

  group('absence de double comptage Charge/Credit', () {
    test(
        'le reste à vivre actuel (argent libre) n\'est jamais réduit une seconde fois par les mensualités de '
        'crédit déjà comptées dans les charges fixes', () {
      // L'argent libre (currentFreeCashCents) est déjà net des mensualités de
      // crédit — elles apparaissent dans les charges fixes une seule fois
      // (charge liée). Le moteur d'impact ne doit JAMAIS les soustraire une
      // seconde fois du reste à vivre : il ne les réutilise que pour le taux
      // d'endettement (un autre indicateur, une autre division).
      const creditMonthlyPaymentCents = 30000;
      const incomeCents = 300000;
      // Argent libre déjà net de cette mensualité (comme le fournirait
      // DashboardViewData.realRemainingCents).
      const freeCashAlreadyNetOfCredit = 120000;

      final result = service.evaluate(
        project: _project(financingMode: ProjectFinancingMode.cash),
        currentFreeCashCents: freeCashAlreadyNetOfCredit,
        totalIncomeCents: incomeCents,
        activeCredits: [_credit(id: 1, name: 'Auto', monthlyPaymentCents: creditMonthlyPaymentCents)],
      );

      // Le reste à vivre "avant" reste exactement l'argent libre fourni —
      // jamais re-diminué par la mensualité du crédit une deuxième fois.
      expect(result.remainingBeforeCents, freeCashAlreadyNetOfCredit);
      // Le taux d'endettement, lui, utilise bien cette même mensualité —
      // une seule fois, dans un calcul séparé (revenu, pas reste à vivre).
      expect(result.debtRatioBefore, creditMonthlyPaymentCents / incomeCents);
    });
  });

  group('modes de financement', () {
    test(
        'projet comptant : aucun impact sur le taux d\'endettement, impact sur le reste à vivre possible via coûts '
        'supplémentaires uniquement', () {
      final result = service.evaluate(
        project: _project(financingMode: ProjectFinancingMode.cash, extraMonthlyCostCents: 15000),
        currentFreeCashCents: 300000,
        totalIncomeCents: 300000,
        activeCredits: const [],
      );

      expect(result.debtRatioAfter, 0);
      expect(result.marginConsumedByProjectCents, 15000);
    });

    test('projet financé : mensualité de financement pèse sur le reste à vivre et l\'endettement', () {
      final result = service.evaluate(
        project: _project(
          financingMode: ProjectFinancingMode.financed,
          availableContributionCents: 0,
          targetAmountCents: 2000000,
          desiredDurationMonths: 48,
          estimatedRatePercent: 3.5,
        ),
        currentFreeCashCents: 300000,
        totalIncomeCents: 300000,
        activeCredits: const [],
      );

      expect(result.marginConsumedByProjectCents, greaterThan(0));
      expect(result.debtRatioAfter, greaterThan(0));
    });

    test('projet mixte : apport partiel réduit le besoin de financement donc l\'impact', () {
      final smallContribution = service.evaluate(
        project: _project(financingMode: ProjectFinancingMode.mixed, availableContributionCents: 200000),
        currentFreeCashCents: 300000,
        totalIncomeCents: 300000,
        activeCredits: const [],
      );
      final bigContribution = service.evaluate(
        project: _project(financingMode: ProjectFinancingMode.mixed, availableContributionCents: 2000000),
        currentFreeCashCents: 300000,
        totalIncomeCents: 300000,
        activeCredits: const [],
      );

      expect(bigContribution.marginConsumedByProjectCents, lessThan(smallContribution.marginConsumedByProjectCents));
      expect(bigContribution.remainingAfterCents, greaterThanOrEqualTo(smallContribution.remainingAfterCents));
    });
  });

  group('apport supplémentaire', () {
    test('augmenter l\'apport disponible réduit l\'impact mensuel et améliore le reste à vivre', () {
      final before = service.evaluate(
        project: _project(availableContributionCents: 500000),
        currentFreeCashCents: 200000,
        totalIncomeCents: 350000,
        activeCredits: const [],
      );
      final afterMoreContribution = service.evaluate(
        project: _project(availableContributionCents: 2500000),
        currentFreeCashCents: 200000,
        totalIncomeCents: 350000,
        activeCredits: const [],
      );

      expect(afterMoreContribution.remainingAfterCents, greaterThanOrEqualTo(before.remainingAfterCents));
      expect(afterMoreContribution.debtRatioAfter, lessThanOrEqualTo(before.debtRatioAfter));
    });
  });

  group('baisse du prix', () {
    test('réduire le prix cible réduit l\'impact mensuel et améliore (ou égale) le reste à vivre', () {
      final expensive = service.evaluate(
        project: _project(targetAmountCents: 5000000),
        currentFreeCashCents: 200000,
        totalIncomeCents: 350000,
        activeCredits: const [],
      );
      final cheaper = service.evaluate(
        project: _project(targetAmountCents: 2000000),
        currentFreeCashCents: 200000,
        totalIncomeCents: 350000,
        activeCredits: const [],
      );

      expect(cheaper.remainingAfterCents, greaterThanOrEqualTo(expensive.remainingAfterCents));
    });
  });

  group('situations concrètes', () {
    test('projet largement dans les moyens : endettement confortable, reste à vivre confortable', () {
      final result = service.evaluate(
        project: _project(
          targetAmountCents: 1000000,
          availableContributionCents: 900000,
          financingMode: ProjectFinancingMode.mixed,
        ),
        currentFreeCashCents: 300000,
        totalIncomeCents: 400000,
        activeCredits: const [],
      );

      expect(debtRatioBandFor(result.debtRatioAfter), DebtRatioBand.comfortable);
      expect(result.remainingAfterCents, greaterThan(0));
    });

    test('projet qui dépasse largement les capacités : endettement à risque élevé, reste à vivre négatif', () {
      final result = service.evaluate(
        project: _project(
          targetAmountCents: 8000000,
          availableContributionCents: 0,
          financingMode: ProjectFinancingMode.financed,
          desiredDurationMonths: 36,
          estimatedRatePercent: 6.0,
        ),
        currentFreeCashCents: 50000,
        totalIncomeCents: 200000,
        activeCredits: [_credit(id: 1, name: 'Auto', monthlyPaymentCents: 40000)],
      );

      expect(debtRatioBandFor(result.debtRatioAfter), DebtRatioBand.high);
      expect(result.remainingAfterCents, lessThan(0));
    });

    test('coûts mensuels supplémentaires réduisent le reste à vivre même pour un projet comptant', () {
      final withoutExtra = service.evaluate(
        project: _project(financingMode: ProjectFinancingMode.cash),
        currentFreeCashCents: 150000,
        totalIncomeCents: 300000,
        activeCredits: const [],
      );
      final withExtra = service.evaluate(
        project: _project(financingMode: ProjectFinancingMode.cash, extraMonthlyCostCents: 60000),
        currentFreeCashCents: 150000,
        totalIncomeCents: 300000,
        activeCredits: const [],
      );

      expect(withExtra.remainingAfterCents, lessThan(withoutExtra.remainingAfterCents));
    });
  });
}
