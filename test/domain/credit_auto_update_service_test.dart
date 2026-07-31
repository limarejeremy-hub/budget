import 'package:flutter_test/flutter_test.dart';

import 'package:budgetpilot/domain/calculations/credit_auto_update_service.dart';
import 'package:budgetpilot/domain/entities/credit_entity.dart';

/// Ces tests couvrent uniquement le calcul pur préparé pour la V0.9
/// (décrémentation automatique) — cette fonctionnalité n'est PAS activée
/// dans l'application : aucun provider ni écran ne l'appelle encore.
void main() {
  const service = CreditAutoUpdateService();

  CreditEntity credit({
    int remainingCapitalCents = 100000,
    int monthlyPaymentCents = 25000,
    int remainingInstallments = 4,
  }) {
    final now = DateTime(2026, 1, 1);
    return CreditEntity(
      id: 1,
      name: 'Voiture',
      initialAmountCents: 500000,
      remainingCapitalCents: remainingCapitalCents,
      monthlyPaymentCents: monthlyPaymentCents,
      expectedEndDate: DateTime(2027, 1, 1),
      remainingInstallments: remainingInstallments,
      organisme: 'Test Bank',
      createdAt: now,
      updatedAt: now,
    );
  }

  test('décrémente le capital restant de la mensualité', () {
    final updated = service.applyMonthlyPayment(credit(remainingCapitalCents: 100000, monthlyPaymentCents: 25000));
    expect(updated.remainingCapitalCents, 75000);
  });

  test('décrémente les mensualités restantes d\'une unité', () {
    final updated = service.applyMonthlyPayment(credit(remainingInstallments: 4));
    expect(updated.remainingInstallments, 3);
  });

  test('ne descend jamais sous zéro pour le capital restant', () {
    final updated = service.applyMonthlyPayment(credit(remainingCapitalCents: 10000, monthlyPaymentCents: 25000));
    expect(updated.remainingCapitalCents, 0);
  });

  test('ne descend jamais sous zéro pour les mensualités restantes', () {
    final updated = service.applyMonthlyPayment(credit(remainingInstallments: 0));
    expect(updated.remainingInstallments, 0);
  });

  test('préserve tous les autres champs du crédit (fonction pure, aucune mutation)', () {
    final original = credit();
    final updated = service.applyMonthlyPayment(original);

    expect(updated.id, original.id);
    expect(updated.name, original.name);
    expect(updated.organisme, original.organisme);
    expect(original.remainingCapitalCents, 100000, reason: "l'entité d'origine ne doit jamais être mutée");
  });
}
