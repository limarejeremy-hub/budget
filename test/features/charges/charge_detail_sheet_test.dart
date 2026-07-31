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
}
