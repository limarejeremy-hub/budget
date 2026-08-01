import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:budgetpilot/core/constants/app_constants.dart';
import 'package:budgetpilot/core/providers/database_provider.dart';
import 'package:budgetpilot/data/local/cycle_repository.dart';
import 'package:budgetpilot/data/local/database.dart';
import 'package:budgetpilot/domain/entities/fixed_expense_entity.dart';
import 'package:budgetpilot/features/charges/charge_detail_sheet.dart';

void main() {
  late AppDatabase db;
  late CycleRepository repository;
  late int cycleId;

  setUpAll(() async {
    await initializeDateFormatting('fr_FR', null);
  });

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = CycleRepository(db);
    cycleId = await repository.createCycle(startDate: DateTime(2026, 7, 27), endDate: DateTime(2026, 8, 26));
  });

  tearDown(() => db.close());

  Future<int> seedCharge() => repository.createFixedExpense(
        cycleId: cycleId,
        name: 'Crédit maison',
        expectedAmountCents: 85000,
        expectedDate: DateTime(2026, 8, 3),
      );

  Widget wrap(Widget child) {
    return ProviderScope(
      overrides: [appDatabaseProvider.overrideWith((ref) => db)],
      child: MaterialApp(home: Scaffold(body: Builder(builder: (context) {
        return Center(
          child: ElevatedButton(
            onPressed: () async {
              final charges = await repository.loadCurrentCycleData();
              final charge = charges!.fixedExpenses.first;
              await showChargeDetailSheet(
                context,
                charge: FixedExpenseEntity(
                  id: charge.id,
                  cycleId: charge.cycleId,
                  name: charge.name,
                  expectedAmountCents: charge.expectedAmountCents,
                  expectedDate: charge.expectedDate,
                  status: charge.status,
                  categoryId: charge.categoryId,
                  isRecurring: charge.isRecurring,
                  linkedCreditId: charge.linkedCreditId,
                ),
                cycleId: cycleId,
              );
            },
            child: const Text('ouvrir'),
          ),
        );
      }))),
    );
  }

  testWidgets('"Marquer comme prélevée" change le statut de la charge', (tester) async {
    await seedCharge();
    await tester.pumpWidget(wrap(const SizedBox()));
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Marquer comme prélevée'));
    await tester.pumpAndSettle();

    final data = await repository.loadCurrentCycleData();
    expect(data!.fixedExpenses.single.status, ChargeStatus.prelevee);
  });

  testWidgets('"Dupliquer" crée une seconde charge identique', (tester) async {
    await seedCharge();
    await tester.pumpWidget(wrap(const SizedBox()));
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dupliquer'));
    await tester.pumpAndSettle();

    final data = await repository.loadCurrentCycleData();
    expect(data!.fixedExpenses, hasLength(2));
    expect(data.fixedExpenses.every((e) => e.name == 'Crédit maison'), isTrue);
  });

  testWidgets('"Supprimer" retire la charge après confirmation', (tester) async {
    await seedCharge();
    await tester.pumpWidget(wrap(const SizedBox()));
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer').last);
    await tester.pumpAndSettle();

    final data = await repository.loadCurrentCycleData();
    expect(data!.fixedExpenses, isEmpty);
  });

  group('charge liée à un crédit (V0.9.1)', () {
    Future<int> seedLinkedCharge() async {
      final creditId = await repository.createCreditForExistingCharge(
        name: 'Voiture',
        initialAmountCents: 1500000,
        remainingCapitalCents: 900000,
        monthlyPaymentCents: 25000,
        expectedEndDate: DateTime(2029, 1, 1),
        remainingInstallments: 36,
      );
      await repository.createFixedExpense(
        cycleId: cycleId,
        name: 'Voiture',
        expectedAmountCents: 25000,
        expectedDate: DateTime(2026, 8, 5),
        linkedCreditId: creditId,
      );
      return creditId;
    }

    testWidgets('"Dupliquer" est masqué pour une charge liée à un crédit', (tester) async {
      await seedLinkedCharge();
      await tester.pumpWidget(wrap(const SizedBox()));
      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();

      expect(find.text('Dupliquer'), findsNothing);
    });

    testWidgets('"Supprimer" propose un choix, "uniquement la charge" garde le crédit', (tester) async {
      final creditId = await seedLinkedCharge();
      await tester.pumpWidget(wrap(const SizedBox()));
      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();

      expect(find.text('Supprimer uniquement la charge mensuelle'), findsOneWidget);
      expect(find.text('Supprimer aussi le crédit'), findsOneWidget);

      await tester.tap(find.text('Supprimer uniquement la charge mensuelle'));
      await tester.pumpAndSettle();

      final data = await repository.loadCurrentCycleData();
      expect(data!.fixedExpenses, isEmpty);
      final credits = await repository.loadCredits();
      expect(credits, hasLength(1));
      expect(credits.single.id, creditId);
    });

    testWidgets('"Supprimer aussi le crédit" supprime le crédit et sa charge', (tester) async {
      await seedLinkedCharge();
      await tester.pumpWidget(wrap(const SizedBox()));
      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer aussi le crédit'));
      await tester.pumpAndSettle();

      final data = await repository.loadCurrentCycleData();
      expect(data!.fixedExpenses, isEmpty);
      final credits = await repository.loadCredits();
      expect(credits, isEmpty);
    });
  });
}
