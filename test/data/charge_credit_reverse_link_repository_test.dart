import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:budgetpilot/data/local/cycle_repository.dart';
import 'package:budgetpilot/data/local/database.dart';

/// Liaison inverse Charges -> Crédits (V0.9.1) : une charge fixe enregistrée
/// avec la catégorie "Crédit" ne doit jamais rester une charge isolée.
/// Complète credit_charge_sync_test.dart (qui couvre le sens Crédit ->
/// Charge, déjà en place depuis la V0.9) avec le sens inverse.
void main() {
  late AppDatabase db;
  late CycleRepository repository;
  late int cycleId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = CycleRepository(db);
    cycleId = await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
  });

  tearDown(() => db.close());

  group('findLinkableCreditForCharge', () {
    test('trouve un crédit actif unique du même nom, non encore lié dans ce cycle', () async {
      final creditId = await repository.createCreditForExistingCharge(
        name: 'Maison',
        initialAmountCents: 20000000,
        remainingCapitalCents: 15000000,
        monthlyPaymentCents: 87500,
        expectedEndDate: DateTime(2040, 1, 1),
        remainingInstallments: 180,
      );

      final match = await repository.findLinkableCreditForCharge(name: 'Maison', cycleId: cycleId);
      expect(match?.id, creditId);
    });

    test('renvoie null si aucun crédit ne correspond', () async {
      final match = await repository.findLinkableCreditForCharge(name: 'Inconnu', cycleId: cycleId);
      expect(match, isNull);
    });

    test('renvoie null si plusieurs crédits actifs portent le même nom (ambiguïté)', () async {
      await repository.createCreditForExistingCharge(
        name: 'Prêt',
        initialAmountCents: 100000,
        remainingCapitalCents: 50000,
        monthlyPaymentCents: 5000,
        expectedEndDate: DateTime(2030, 1, 1),
        remainingInstallments: 10,
      );
      await repository.createCreditForExistingCharge(
        name: 'Prêt',
        initialAmountCents: 200000,
        remainingCapitalCents: 90000,
        monthlyPaymentCents: 9000,
        expectedEndDate: DateTime(2031, 1, 1),
        remainingInstallments: 10,
      );

      final match = await repository.findLinkableCreditForCharge(name: 'Prêt', cycleId: cycleId);
      expect(match, isNull);
    });

    test('renvoie null si le crédit a déjà une charge liée dans ce cycle (prévention des doublons)',
        () async {
      final creditId = await repository.createCreditForExistingCharge(
        name: 'Maison',
        initialAmountCents: 20000000,
        remainingCapitalCents: 15000000,
        monthlyPaymentCents: 87500,
        expectedEndDate: DateTime(2040, 1, 1),
        remainingInstallments: 180,
      );
      await repository.createFixedExpense(
        cycleId: cycleId,
        name: 'Maison',
        expectedAmountCents: 87500,
        expectedDate: DateTime(2026, 1, 5),
        linkedCreditId: creditId,
      );

      final match = await repository.findLinkableCreditForCharge(name: 'Maison', cycleId: cycleId);
      expect(match, isNull);
    });

    test('ignore un crédit inactif (terminé)', () async {
      final creditId = await repository.createCreditForExistingCharge(
        name: 'Terminé',
        initialAmountCents: 100000,
        remainingCapitalCents: 0,
        monthlyPaymentCents: 5000,
        expectedEndDate: DateTime(2025, 1, 1),
        remainingInstallments: 0,
      );
      await repository.setCreditActive(creditId, false);

      final match = await repository.findLinkableCreditForCharge(name: 'Terminé', cycleId: cycleId);
      expect(match, isNull);
    });
  });

  test('createCreditForExistingCharge accepte un capital restant à 0 (crédit déjà soldé)', () async {
    final creditId = await repository.createCreditForExistingCharge(
      name: 'Presque soldé',
      initialAmountCents: 100000,
      remainingCapitalCents: 0,
      monthlyPaymentCents: 5000,
      expectedEndDate: DateTime(2026, 2, 1),
      remainingInstallments: 0,
    );

    final credit = (await repository.loadCredits()).single;
    expect(credit.id, creditId);
    expect(credit.remainingCapitalCents, 0);
    expect(credit.remainingInstallments, 0);
  });

  test('createCreditForExistingCharge accepte taux et organisme absents (facultatifs)', () async {
    await repository.createCreditForExistingCharge(
      name: 'Sans organisme ni taux',
      initialAmountCents: 100000,
      remainingCapitalCents: 50000,
      monthlyPaymentCents: 5000,
      expectedEndDate: DateTime(2030, 1, 1),
      remainingInstallments: 10,
    );

    final credit = (await repository.loadCredits()).single;
    expect(credit.organisme, isNull);
    expect(credit.annualRatePercent, isNull);
  });

  test('createCreditForExistingCharge ne génère jamais de charge automatiquement', () async {
    await repository.createCreditForExistingCharge(
      name: 'Voiture',
      initialAmountCents: 1500000,
      remainingCapitalCents: 900000,
      monthlyPaymentCents: 25000,
      expectedEndDate: DateTime(2029, 1, 1),
      remainingInstallments: 36,
    );

    final data = await repository.loadCurrentCycleData();
    expect(data!.fixedExpenses, isEmpty);
    expect(await repository.loadCredits(), hasLength(1));
  });

  test('syncCreditFromCharge met à jour nom/mensualité/jour/actif sans toucher au capital', () async {
    final creditId = await repository.createCreditForExistingCharge(
      name: 'Voiture',
      initialAmountCents: 1500000,
      remainingCapitalCents: 900000,
      monthlyPaymentCents: 25000,
      expectedEndDate: DateTime(2029, 1, 1),
      remainingInstallments: 36,
    );

    await repository.syncCreditFromCharge(
      creditId: creditId,
      name: 'Voiture (renommée)',
      monthlyPaymentCents: 27500,
      paymentDayOfMonth: 12,
      isActive: false,
    );

    final credit = (await repository.loadCredits()).single;
    expect(credit.name, 'Voiture (renommée)');
    expect(credit.monthlyPaymentCents, 27500);
    expect(credit.paymentDayOfMonth, 12);
    expect(credit.isActive, isFalse);
    // Jamais touché par cette synchronisation partielle.
    expect(credit.remainingCapitalCents, 900000);
    expect(credit.initialAmountCents, 1500000);
    expect(credit.remainingInstallments, 36);
  });

  test('modifier une charge liée (nom, mensualité, jour) synchronise le crédit', () async {
    final creditId = await repository.createCreditForExistingCharge(
      name: 'Voiture',
      initialAmountCents: 1500000,
      remainingCapitalCents: 900000,
      monthlyPaymentCents: 25000,
      expectedEndDate: DateTime(2029, 1, 1),
      remainingInstallments: 36,
    );
    final chargeId = await repository.createFixedExpense(
      cycleId: cycleId,
      name: 'Voiture',
      expectedAmountCents: 25000,
      expectedDate: DateTime(2026, 1, 5),
      linkedCreditId: creditId,
    );

    // Simule le formulaire de charge : modification du nom, du montant et de
    // la date, puis synchronisation explicite du crédit lié (ce que fait
    // FixedExpenseFormPage._save()).
    await repository.updateFixedExpense(
      id: chargeId,
      name: 'Voiture (Peugeot)',
      expectedAmountCents: 26000,
      expectedDate: DateTime(2026, 1, 18),
      isRecurring: false,
      isActive: true,
      linkedCreditId: creditId,
    );
    await repository.syncCreditFromCharge(
      creditId: creditId,
      name: 'Voiture (Peugeot)',
      monthlyPaymentCents: 26000,
      paymentDayOfMonth: 18,
      isActive: true,
    );

    final credit = (await repository.loadCredits()).single;
    expect(credit.name, 'Voiture (Peugeot)');
    expect(credit.monthlyPaymentCents, 26000);
    expect(credit.paymentDayOfMonth, 18);
  });

  group('loadUnlinkedCreditCharges / watchUnlinkedCreditCharges', () {
    test('renvoie les charges catégorie Crédit sans crédit lié, jamais les autres', () async {
      final categories = await repository.categoriesForType('fixed_expense');
      final creditCategoryId = categories.firstWhere((c) => c.name == 'Crédit').id;
      final otherCategoryId = categories.firstWhere((c) => c.name != 'Crédit').id;

      final orphanId = await repository.createFixedExpense(
        cycleId: cycleId,
        name: 'Ancien crédit non relié',
        expectedAmountCents: 30000,
        expectedDate: DateTime(2026, 1, 10),
        categoryId: creditCategoryId,
      );
      // Charge Crédit déjà reliée : ne doit pas apparaître.
      final linkedCreditId = await repository.createCreditForExistingCharge(
        name: 'Relié',
        initialAmountCents: 100000,
        remainingCapitalCents: 50000,
        monthlyPaymentCents: 5000,
        expectedEndDate: DateTime(2030, 1, 1),
        remainingInstallments: 10,
      );
      await repository.createFixedExpense(
        cycleId: cycleId,
        name: 'Relié',
        expectedAmountCents: 5000,
        expectedDate: DateTime(2026, 1, 5),
        categoryId: creditCategoryId,
        linkedCreditId: linkedCreditId,
      );
      // Charge d'une autre catégorie : ne doit jamais apparaître.
      await repository.createFixedExpense(
        cycleId: cycleId,
        name: 'Autre charge',
        expectedAmountCents: 10000,
        expectedDate: DateTime(2026, 1, 5),
        categoryId: otherCategoryId,
      );

      final unlinked = await repository.loadUnlinkedCreditCharges();
      expect(unlinked, hasLength(1));
      expect(unlinked.single.id, orphanId);
    });

    test('se réémet quand une charge orpheline apparaît', () async {
      final categories = await repository.categoriesForType('fixed_expense');
      final creditCategoryId = categories.firstWhere((c) => c.name == 'Crédit').id;

      final emissions = <int>[];
      final sub = repository.watchUnlinkedCreditCharges().listen((list) => emissions.add(list.length));
      await Future<void>.delayed(Duration.zero);

      await repository.createFixedExpense(
        cycleId: cycleId,
        name: 'Ancien crédit non relié',
        expectedAmountCents: 30000,
        expectedDate: DateTime(2026, 1, 10),
        categoryId: creditCategoryId,
      );
      await Future<void>.delayed(Duration.zero);

      await sub.cancel();
      expect(emissions.first, 0);
      expect(emissions.last, 1);
    });
  });
}
