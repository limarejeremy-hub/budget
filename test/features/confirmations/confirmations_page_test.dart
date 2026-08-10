import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:budgetpilot/core/constants/app_constants.dart';
import 'package:budgetpilot/core/providers/database_provider.dart';
import 'package:budgetpilot/data/local/cycle_repository.dart';
import 'package:budgetpilot/data/local/database.dart';
import 'package:budgetpilot/features/confirmations/confirmations_page.dart';

// Le centre de confirmations (V0.9) agit directement sur de vraies données
// (via CycleRepository) : chaque test seed une base en mémoire plutôt que de
// substituer dashboardProvider, pour vérifier que les actions modifient
// réellement les charges (et les crédits liés) et que l'UI se met à jour en
// conséquence (le flux est réactif, basé sur tableUpdates).
late AppDatabase _db;
late CycleRepository _repository;

Widget _wrap() {
  return ProviderScope(
    overrides: [appDatabaseProvider.overrideWith((ref) => _db)],
    child: const MaterialApp(home: ConfirmationsPage()),
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR', null);
  });

  setUp(() {
    _db = AppDatabase.forTesting(NativeDatabase.memory());
    _repository = CycleRepository(_db);
  });

  tearDown(() => _db.close());

  testWidgets("affiche l'état vide quand rien n'attend de confirmation", (tester) async {
    await _repository.createCycle(startDate: DateTime.now(), endDate: DateTime.now().add(const Duration(days: 30)));

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('Tout est confirmé'), findsOneWidget);
  });

  testWidgets('Confirmer marque la charge comme prélevée et la retire de la liste', (tester) async {
    final today = DateTime.now();
    final cycleId =
        await _repository.createCycle(startDate: today, endDate: today.add(const Duration(days: 30)));
    await _repository.createFixedExpense(
      cycleId: cycleId,
      name: 'Orange',
      expectedAmountCents: 7000,
      expectedDate: today,
    );

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('Orange'), findsOneWidget);

    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();

    expect(find.text('Opération confirmée'), findsOneWidget);
    expect(find.text('Orange'), findsNothing);
  });

  testWidgets('Ignorer suspend la charge et la retire de la liste', (tester) async {
    final today = DateTime.now();
    final cycleId =
        await _repository.createCycle(startDate: today, endDate: today.add(const Duration(days: 30)));
    await _repository.createFixedExpense(
      cycleId: cycleId,
      name: 'Salle de sport',
      expectedAmountCents: 3000,
      expectedDate: today,
    );

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ignorer'));
    await tester.pumpAndSettle();

    expect(find.text('Salle de sport'), findsNothing);
  });

  testWidgets('Reporter décale la charge du lendemain et la retire du jour', (tester) async {
    final today = DateTime.now();
    final cycleId =
        await _repository.createCycle(startDate: today, endDate: today.add(const Duration(days: 30)));
    await _repository.createFixedExpense(
      cycleId: cycleId,
      name: 'Abonnement',
      expectedAmountCents: 1500,
      expectedDate: today,
    );

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reporter'));
    await tester.pumpAndSettle();

    expect(find.text('Abonnement'), findsNothing);
  });

  testWidgets('Modifier enregistre le montant réel confirmé', (tester) async {
    final today = DateTime.now();
    final cycleId =
        await _repository.createCycle(startDate: today, endDate: today.add(const Duration(days: 30)));
    final chargeId = await _repository.createFixedExpense(
      cycleId: cycleId,
      name: 'Électricité',
      expectedAmountCents: 6000,
      expectedDate: today,
    );

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Modifier'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '65,50');
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmer'));
    await tester.pumpAndSettle();

    expect(find.text('Montant réel enregistré'), findsOneWidget);

    final charges = await (_db.select(_db.fixedExpenses)..where((e) => e.id.equals(chargeId))).get();
    expect(charges.single.actualAmountCents, 6550);
    expect(charges.single.status, ChargeStatus.prelevee);
  });

  testWidgets('confirmer une mensualité de crédit décrémente automatiquement le crédit lié', (tester) async {
    final today = DateTime.now();
    await _repository.createCycle(startDate: today, endDate: today.add(const Duration(days: 30)));
    final creditId = await _repository.createCredit(
      name: 'Voiture',
      initialAmountCents: 1000000,
      remainingCapitalCents: 500000,
      monthlyPaymentCents: 25000,
      expectedEndDate: DateTime(today.year + 2, today.month),
      remainingInstallments: 20,
    );

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('Voiture'), findsOneWidget);
    expect(find.text('Mensualité de crédit'), findsOneWidget);

    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();

    final credits = await _repository.loadCredits();
    final credit = credits.singleWhere((c) => c.id == creditId);
    expect(credit.remainingCapitalCents, 475000);
    expect(credit.remainingInstallments, 19);
  });

  testWidgets("l'icône de notification ouvre le centre de notifications", (tester) async {
    await _repository.createCycle(startDate: DateTime.now(), endDate: DateTime.now().add(const Duration(days: 30)));

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.notifications_outlined));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Notifications'), findsOneWidget);
  });
}
