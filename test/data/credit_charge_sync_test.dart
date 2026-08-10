import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:budgetpilot/core/constants/app_constants.dart';
import 'package:budgetpilot/data/local/cycle_repository.dart';
import 'package:budgetpilot/data/local/database.dart';

/// V0.9 : "un crédit ne doit être créé qu'une seule fois" — la charge fixe
/// mensuelle d'un crédit est générée/mise à jour/supprimée automatiquement,
/// l'utilisateur ne la crée jamais lui-même.
void main() {
  late AppDatabase db;
  late CycleRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = CycleRepository(db);
  });

  tearDown(() => db.close());

  Future<int> seedCycle() => repository.createCycle(
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 31),
      );

  test('createCredit génère automatiquement sa charge fixe dans le cycle courant', () async {
    final cycleId = await seedCycle();

    await repository.createCredit(
      name: 'Voiture',
      initialAmountCents: 1500000,
      remainingCapitalCents: 900000,
      monthlyPaymentCents: 25000,
      expectedEndDate: DateTime(2029, 1, 1),
      remainingInstallments: 36,
      paymentDayOfMonth: 5,
    );

    final data = await repository.loadCurrentCycleData();
    expect(data!.fixedExpenses, hasLength(1));
    final charge = data.fixedExpenses.single;
    expect(charge.name, 'Voiture');
    expect(charge.expectedAmountCents, 25000);
    expect(charge.cycleId, cycleId);
    expect(charge.expectedDate, DateTime(2026, 1, 5));
    expect(charge.status, ChargeStatus.aVenir);

    final credit = (await repository.loadCredits()).single;
    final creditRow = await (db.select(db.fixedExpenses)).getSingle();
    expect(creditRow.linkedCreditId, credit.id);
  });

  test('createCredit sans cycle ouvert ne crée aucune charge (pas de crash)', () async {
    await repository.createCredit(
      name: 'Voiture',
      initialAmountCents: 1500000,
      remainingCapitalCents: 900000,
      monthlyPaymentCents: 25000,
      expectedEndDate: DateTime(2029, 1, 1),
      remainingInstallments: 36,
    );

    expect(await repository.loadCurrentCycleData(), isNull);
  });

  test('updateCredit met à jour la charge liée non confirmée', () async {
    await seedCycle();
    final creditId = await repository.createCredit(
      name: 'Voiture',
      initialAmountCents: 1500000,
      remainingCapitalCents: 900000,
      monthlyPaymentCents: 25000,
      expectedEndDate: DateTime(2029, 1, 1),
      remainingInstallments: 36,
    );

    await repository.updateCredit(
      id: creditId,
      name: 'Voiture',
      initialAmountCents: 1500000,
      remainingCapitalCents: 900000,
      monthlyPaymentCents: 30000,
      expectedEndDate: DateTime(2029, 1, 1),
      remainingInstallments: 36,
      earlyRepaymentAllowed: true,
    );

    final data = await repository.loadCurrentCycleData();
    expect(data!.fixedExpenses.single.expectedAmountCents, 30000);
  });

  test('updateCredit ne réécrit jamais une charge déjà confirmée (prelevee)', () async {
    await seedCycle();
    final creditId = await repository.createCredit(
      name: 'Voiture',
      initialAmountCents: 1500000,
      remainingCapitalCents: 900000,
      monthlyPaymentCents: 25000,
      expectedEndDate: DateTime(2029, 1, 1),
      remainingInstallments: 36,
    );
    final chargeId = (await repository.loadCurrentCycleData())!.fixedExpenses.single.id;
    await repository.confirmFixedExpense(chargeId);

    await repository.updateCredit(
      id: creditId,
      name: 'Voiture',
      initialAmountCents: 1500000,
      remainingCapitalCents: 875000,
      monthlyPaymentCents: 30000,
      expectedEndDate: DateTime(2029, 1, 1),
      remainingInstallments: 35,
      earlyRepaymentAllowed: true,
    );

    final data = await repository.loadCurrentCycleData();
    final charge = data!.fixedExpenses.singleWhere((e) => e.id == chargeId);
    expect(charge.expectedAmountCents, 25000, reason: 'la charge confirmée ne doit jamais être réécrite');
    expect(charge.status, ChargeStatus.prelevee);
  });

  test('deleteCredit supprime aussi toutes ses charges liées', () async {
    await seedCycle();
    final creditId = await repository.createCredit(
      name: 'Voiture',
      initialAmountCents: 1500000,
      remainingCapitalCents: 900000,
      monthlyPaymentCents: 25000,
      expectedEndDate: DateTime(2029, 1, 1),
      remainingInstallments: 36,
    );

    await repository.deleteCredit(creditId);

    final data = await repository.loadCurrentCycleData();
    expect(data!.fixedExpenses, isEmpty);
  });

  test('setCreditActive(false) supprime la charge liée non confirmée', () async {
    await seedCycle();
    final creditId = await repository.createCredit(
      name: 'Voiture',
      initialAmountCents: 1500000,
      remainingCapitalCents: 900000,
      monthlyPaymentCents: 25000,
      expectedEndDate: DateTime(2029, 1, 1),
      remainingInstallments: 36,
    );

    await repository.setCreditActive(creditId, false);

    final data = await repository.loadCurrentCycleData();
    expect(data!.fixedExpenses, isEmpty);
  });

  test('setCreditActive(true) régénère la charge si elle est absente', () async {
    await seedCycle();
    final creditId = await repository.createCredit(
      name: 'Voiture',
      initialAmountCents: 1500000,
      remainingCapitalCents: 900000,
      monthlyPaymentCents: 25000,
      expectedEndDate: DateTime(2029, 1, 1),
      remainingInstallments: 36,
    );
    await repository.setCreditActive(creditId, false);
    expect((await repository.loadCurrentCycleData())!.fixedExpenses, isEmpty);

    await repository.setCreditActive(creditId, true);

    final data = await repository.loadCurrentCycleData();
    expect(data!.fixedExpenses, hasLength(1));
    expect(data.fixedExpenses.single.linkedCreditId, creditId);
  });

  test('createCycle génère automatiquement les charges de tous les crédits actifs', () async {
    final firstCycleId = await seedCycle();
    await repository.createCredit(
      name: 'Voiture',
      initialAmountCents: 1500000,
      remainingCapitalCents: 900000,
      monthlyPaymentCents: 25000,
      expectedEndDate: DateTime(2029, 1, 1),
      remainingInstallments: 36,
    );

    // Un seul cycle 'ouvert' à la fois (§17) : clôturer le premier avant
    // de créer le second.
    await repository.closeCycle(firstCycleId);
    await repository.createCycle(startDate: DateTime(2026, 2, 1), endDate: DateTime(2026, 2, 28));

    final data = await repository.loadCurrentCycleData();
    expect(data!.cycle.startDate, DateTime(2026, 2, 1));
    expect(data.fixedExpenses, hasLength(1));
    expect(data.fixedExpenses.single.name, 'Voiture');
  });

  test('createCycle ne génère rien pour un crédit terminé (isActive = false)', () async {
    final firstCycleId = await seedCycle();
    final creditId = await repository.createCredit(
      name: 'Voiture',
      initialAmountCents: 1500000,
      remainingCapitalCents: 900000,
      monthlyPaymentCents: 25000,
      expectedEndDate: DateTime(2029, 1, 1),
      remainingInstallments: 36,
    );
    await repository.setCreditActive(creditId, false);

    await repository.closeCycle(firstCycleId);
    await repository.createCycle(startDate: DateTime(2026, 2, 1), endDate: DateTime(2026, 2, 28));

    final data = await repository.loadCurrentCycleData();
    expect(data!.fixedExpenses, isEmpty);
  });

  group('confirmFixedExpense', () {
    test('confirme une charge normale (non liée) sans toucher aux crédits', () async {
      final cycleId = await seedCycle();
      final chargeId = await repository.createFixedExpense(
        cycleId: cycleId,
        name: 'Loyer',
        expectedAmountCents: 70000,
        expectedDate: DateTime(2026, 1, 5),
      );

      final result = await repository.confirmFixedExpense(chargeId);

      expect(result, isNull);
      final data = await repository.loadCurrentCycleData();
      expect(data!.fixedExpenses.single.status, ChargeStatus.prelevee);
    });

    test('décrémente automatiquement le crédit lié (capital et mensualités restantes)', () async {
      await seedCycle();
      final creditId = await repository.createCredit(
        name: 'Voiture',
        initialAmountCents: 1500000,
        remainingCapitalCents: 900000,
        monthlyPaymentCents: 25000,
        expectedEndDate: DateTime(2029, 1, 1),
        remainingInstallments: 36,
      );
      final chargeId = (await repository.loadCurrentCycleData())!.fixedExpenses.single.id;

      final result = await repository.confirmFixedExpense(chargeId);

      expect(result, isNotNull);
      expect(result!.finished, isFalse);
      expect(result.credit.remainingCapitalCents, 875000);
      expect(result.credit.remainingInstallments, 35);

      final credit = (await repository.loadCredits()).singleWhere((c) => c.id == creditId);
      expect(credit.remainingCapitalCents, 875000);
      expect(credit.remainingInstallments, 35);
    });

    test('utilise le montant réel confirmé (et non la mensualité) pour décrémenter le capital', () async {
      await seedCycle();
      await repository.createCredit(
        name: 'Voiture',
        initialAmountCents: 1500000,
        remainingCapitalCents: 900000,
        monthlyPaymentCents: 25000,
        expectedEndDate: DateTime(2029, 1, 1),
        remainingInstallments: 36,
      );
      final chargeId = (await repository.loadCurrentCycleData())!.fixedExpenses.single.id;

      final result = await repository.confirmFixedExpense(chargeId, actualAmountCents: 40000);

      expect(result!.credit.remainingCapitalCents, 860000);
      final data = await repository.loadCurrentCycleData();
      expect(data!.fixedExpenses.single.actualAmountCents, 40000);
    });

    test('marque le crédit terminé quand le capital restant tombe à zéro', () async {
      await seedCycle();
      final creditId = await repository.createCredit(
        name: 'Montre',
        initialAmountCents: 40000,
        remainingCapitalCents: 20000,
        monthlyPaymentCents: 25000,
        expectedEndDate: DateTime(2026, 3, 1),
        remainingInstallments: 1,
      );
      final chargeId = (await repository.loadCurrentCycleData())!.fixedExpenses.single.id;

      final result = await repository.confirmFixedExpense(chargeId);

      expect(result!.finished, isTrue);
      expect(result.credit.remainingCapitalCents, 0);
      final credit = (await repository.loadCredits()).singleWhere((c) => c.id == creditId);
      expect(credit.isActive, isFalse);
    });
  });

  test('postponeFixedExpense reporte la charge de la durée indiquée', () async {
    final cycleId = await seedCycle();
    final chargeId = await repository.createFixedExpense(
      cycleId: cycleId,
      name: 'Loyer',
      expectedAmountCents: 70000,
      expectedDate: DateTime(2026, 1, 5),
    );

    await repository.postponeFixedExpense(chargeId);

    final data = await repository.loadCurrentCycleData();
    expect(data!.fixedExpenses.single.expectedDate, DateTime(2026, 1, 6));
  });

  group('notifications (historique)', () {
    test('logNotification puis loadNotificationLogs restitue les entrées, plus récentes en premier', () async {
      await repository.logNotification(type: 'morning_summary', title: 'A', body: 'Corps A');
      await repository.logNotification(type: 'credit_finished', title: 'B', body: 'Corps B');

      final logs = await repository.loadNotificationLogs();
      expect(logs, hasLength(2));
      expect(logs.first.title, 'B');
      expect(logs.every((l) => l.read == false), isTrue);
    });

    test('markNotificationRead marque une entrée comme lue', () async {
      final id = await repository.logNotification(type: 'morning_summary', title: 'A', body: 'Corps A');

      await repository.markNotificationRead(id);

      final logs = await repository.loadNotificationLogs();
      expect(logs.single.read, isTrue);
    });

    test('watchNotificationLogs se réémet quand une notification est journalisée', () async {
      final stream = repository.watchNotificationLogs();
      final emissions = <int>[];
      final subscription = stream.listen((logs) => emissions.add(logs.length));

      await Future<void>.delayed(Duration.zero);
      expect(emissions, [0]);

      await repository.logNotification(type: 'morning_summary', title: 'A', body: 'Corps A');
      await Future<void>.delayed(Duration.zero);
      expect(emissions, [0, 1]);

      await subscription.cancel();
    });
  });
}
