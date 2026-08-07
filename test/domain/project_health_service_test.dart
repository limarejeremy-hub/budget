import 'package:flutter_test/flutter_test.dart';

import 'package:budgetpilot/core/constants/app_constants.dart';
import 'package:budgetpilot/domain/calculations/project_health_service.dart';
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
    maxMonthlyPaymentCents: maxMonthlyPaymentCents,
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
  const service = ProjectHealthService();

  group('conclusion', () {
    test('sécurité faible malgré faisabilité élevée => BudgetPilot déconseille explicitement', () {
      // Feasibilité correcte (argent libre confortable face à l'impact
      // mensuel), mais des crédits déjà lourds et une mensualité de
      // financement qui, cumulés, pèsent fortement sur le revenu et sur la
      // marge — la sécurité financière reste basse malgré une faisabilité
      // suffisante.
      final result = service.evaluate(
        project: _project(
          targetAmountCents: 2000000,
          availableContributionCents: 1000000,
          financingMode: ProjectFinancingMode.mixed,
          desiredDurationMonths: 10,
          estimatedRatePercent: 4.0,
        ),
        currentFreeCashCents: 200000,
        totalIncomeCents: 800000,
        activeCredits: [
          _credit(id: 1, name: 'Auto', monthlyPaymentCents: 120000),
          _credit(id: 2, name: 'Conso', monthlyPaymentCents: 100000),
          _credit(id: 3, name: 'Travaux', monthlyPaymentCents: 60000),
        ],
      );

      expect(result.feasibility.totalScore, greaterThanOrEqualTo(60));
      expect(result.safety.totalScore, lessThan(60));
      expect(result.conclusion, contains('déconseille'));
    });

    test('projet à la fois faisable et sain : conclusion positive sans "déconseille"', () {
      final result = service.evaluate(
        project: _project(
          targetAmountCents: 1000000,
          availableContributionCents: 950000,
          financingMode: ProjectFinancingMode.mixed,
        ),
        currentFreeCashCents: 300000,
        totalIncomeCents: 400000,
        activeCredits: const [],
      );

      expect(result.feasibility.totalScore, greaterThanOrEqualTo(60));
      expect(result.safety.totalScore, greaterThanOrEqualTo(60));
      expect(result.conclusion, isNot(contains('déconseille')));
    });

    test('le score global ne masque jamais les deux scores détaillés', () {
      final result = service.evaluate(
        project: _project(),
        currentFreeCashCents: 200000,
        totalIncomeCents: 300000,
        activeCredits: const [],
      );

      expect(result.feasibility.totalScore, isNotNull);
      expect(result.safety.totalScore, isNotNull);
      expect(result.healthScore, inInclusiveRange(0, 100));
    });
  });

  group('bloqueurs', () {
    test('jamais plus de 3 bloqueurs affichés', () {
      final result = service.evaluate(
        project: _project(
          targetAmountCents: 9000000,
          availableContributionCents: 0,
          financingMode: ProjectFinancingMode.financed,
          maxMonthlyPaymentCents: 10000,
          desiredDurationMonths: 24,
          estimatedRatePercent: 8.0,
        ),
        currentFreeCashCents: 20000,
        totalIncomeCents: 150000,
        activeCredits: [
          _credit(id: 1, name: 'Auto', monthlyPaymentCents: 30000),
          _credit(id: 2, name: 'Conso', monthlyPaymentCents: 20000),
          _credit(id: 3, name: 'Travaux', monthlyPaymentCents: 15000),
        ],
      );

      expect(result.blockers.length, lessThanOrEqualTo(3));
      expect(result.blockers, isNotEmpty);
    });

    test('projet confortable : aucun bloqueur', () {
      final result = service.evaluate(
        project: _project(
          targetAmountCents: 500000,
          availableContributionCents: 500000,
          financingMode: ProjectFinancingMode.cash,
        ),
        currentFreeCashCents: 300000,
        totalIncomeCents: 400000,
        activeCredits: const [],
      );

      expect(result.blockers, isEmpty);
    });

    test('mensualité cible trop élevée apparaît comme bloqueur', () {
      final result = service.evaluate(
        project: _project(
          targetAmountCents: 3000000,
          availableContributionCents: 0,
          financingMode: ProjectFinancingMode.financed,
          maxMonthlyPaymentCents: 5000,
          desiredDurationMonths: 60,
          estimatedRatePercent: 4.0,
        ),
        currentFreeCashCents: 150000,
        totalIncomeCents: 300000,
        activeCredits: const [],
      );

      expect(result.blockers.any((b) => b.contains('mensualité')), isTrue);
    });
  });
}
