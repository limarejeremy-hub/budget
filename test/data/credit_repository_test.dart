import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:budgetpilot/data/local/cycle_repository.dart';
import 'package:budgetpilot/data/local/database.dart';

void main() {
  late AppDatabase db;
  late CycleRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = CycleRepository(db);
  });

  tearDown(() => db.close());

  test('createCredit crée un crédit avec toutes ses données', () async {
    final id = await repository.createCredit(
      name: 'Voiture',
      initialAmountCents: 1500000,
      remainingCapitalCents: 900000,
      monthlyPaymentCents: 25000,
      annualRatePercent: 3.5,
      startDate: DateTime(2024, 1, 1),
      expectedEndDate: DateTime(2029, 1, 1),
      remainingInstallments: 36,
      creditType: 'Auto',
      earlyRepaymentAllowed: true,
      earlyRepaymentPenaltyCents: 5000,
      notes: 'Prêt concessionnaire',
    );

    final credits = await repository.loadCredits();
    final credit = credits.singleWhere((c) => c.id == id);
    expect(credit.name, 'Voiture');
    expect(credit.initialAmountCents, 1500000);
    expect(credit.remainingCapitalCents, 900000);
    expect(credit.monthlyPaymentCents, 25000);
    expect(credit.annualRatePercent, 3.5);
    expect(credit.remainingInstallments, 36);
    expect(credit.creditType, 'Auto');
    expect(credit.earlyRepaymentAllowed, isTrue);
    expect(credit.earlyRepaymentPenaltyCents, 5000);
    expect(credit.notes, 'Prêt concessionnaire');
    expect(credit.isActive, isTrue);
  });

  test('createCredit sans taux ni date de début laisse ces champs à null', () async {
    await repository.createCredit(
      name: 'Montre',
      initialAmountCents: 80000,
      remainingCapitalCents: 40000,
      monthlyPaymentCents: 5000,
      expectedEndDate: DateTime(2027, 1, 1),
      remainingInstallments: 8,
    );

    final credit = (await repository.loadCredits()).single;
    expect(credit.annualRatePercent, isNull);
    expect(credit.startDate, isNull);
  });

  test('updateCredit modifie un crédit existant', () async {
    final id = await repository.createCredit(
      name: 'Voiture',
      initialAmountCents: 1500000,
      remainingCapitalCents: 900000,
      monthlyPaymentCents: 25000,
      expectedEndDate: DateTime(2029, 1, 1),
      remainingInstallments: 36,
    );

    await repository.updateCredit(
      id: id,
      name: 'Voiture (soldée en partie)',
      initialAmountCents: 1500000,
      remainingCapitalCents: 600000,
      monthlyPaymentCents: 25000,
      expectedEndDate: DateTime(2028, 1, 1),
      remainingInstallments: 24,
      earlyRepaymentAllowed: true,
    );

    final credit = (await repository.loadCredits()).single;
    expect(credit.name, 'Voiture (soldée en partie)');
    expect(credit.remainingCapitalCents, 600000);
    expect(credit.remainingInstallments, 24);
  });

  test('deleteCredit supprime le crédit', () async {
    final id = await repository.createCredit(
      name: 'Montre',
      initialAmountCents: 80000,
      remainingCapitalCents: 40000,
      monthlyPaymentCents: 5000,
      expectedEndDate: DateTime(2027, 1, 1),
      remainingInstallments: 8,
    );

    await repository.deleteCredit(id);

    expect(await repository.loadCredits(), isEmpty);
  });

  test('setCreditActive marque comme terminé puis réactive', () async {
    final id = await repository.createCredit(
      name: 'Montre',
      initialAmountCents: 80000,
      remainingCapitalCents: 0,
      monthlyPaymentCents: 5000,
      expectedEndDate: DateTime(2027, 1, 1),
      remainingInstallments: 0,
    );

    await repository.setCreditActive(id, false);
    var credit = (await repository.loadCredits()).single;
    expect(credit.isActive, isFalse);

    await repository.setCreditActive(id, true);
    credit = (await repository.loadCredits()).single;
    expect(credit.isActive, isTrue);
  });

  test('watchCredits se réémet quand un crédit est ajouté', () async {
    final stream = repository.watchCredits();
    final emissions = <int>[];
    final subscription = stream.listen((credits) => emissions.add(credits.length));

    await Future<void>.delayed(Duration.zero);
    expect(emissions, [0]);

    await repository.createCredit(
      name: 'Montre',
      initialAmountCents: 80000,
      remainingCapitalCents: 40000,
      monthlyPaymentCents: 5000,
      expectedEndDate: DateTime(2027, 1, 1),
      remainingInstallments: 8,
    );
    await Future<void>.delayed(Duration.zero);
    expect(emissions, [0, 1]);

    await subscription.cancel();
  });
}
