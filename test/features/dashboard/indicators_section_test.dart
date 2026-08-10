import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:budgetpilot/core/formatting/currency_formatter.dart';
import 'package:budgetpilot/core/providers/database_provider.dart';
import 'package:budgetpilot/data/local/cycle_repository.dart';
import 'package:budgetpilot/data/local/database.dart';
import 'package:budgetpilot/features/dashboard/widgets/indicators_section.dart';

void main() {
  late AppDatabase db;
  late CycleRepository repository;

  Widget wrap() {
    return ProviderScope(
      overrides: [appDatabaseProvider.overrideWith((ref) => db)],
      child: const MaterialApp(home: Scaffold(body: IndicatorsSection())),
    );
  }

  setUpAll(() async {
    await initializeDateFormatting('fr_FR', null);
  });

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = CycleRepository(db);
  });

  tearDown(() => db.close());

  testWidgets('sans cycle actif, la section reste invisible', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Mes indicateurs'), findsNothing);
  });

  testWidgets('affiche le taux d\'épargne, le taux d\'endettement et les dépenses du cycle', (tester) async {
    final cycleId = await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
    await repository.createIncome(
      cycleId: cycleId,
      name: 'Salaire',
      expectedAmountCents: 400000,
      expectedDate: DateTime(2026, 1, 1),
    );
    await repository.createSaving(
      cycleId: cycleId,
      name: 'Livret',
      expectedAmountCents: 50000,
      expectedDate: DateTime(2026, 1, 5),
    );
    await repository.createVariableExpense(cycleId: cycleId, amountCents: 42800, date: DateTime(2026, 1, 10));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Mes indicateurs'), findsOneWidget);
    expect(find.text('Épargne'), findsOneWidget);
    // 50000 / 400000 = 12,5 %.
    expect(find.text(formatRatioAsPercent(0.125)), findsOneWidget);
    expect(find.text('Endettement'), findsOneWidget);
    expect(find.text('Dépenses'), findsOneWidget);
    expect(find.text(formatCentsAsEuro(42800)), findsOneWidget);
  });

  testWidgets('revenus = 0 : le taux d\'épargne affiche "—", jamais une division par zéro', (tester) async {
    await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Mes indicateurs'), findsOneWidget);
    expect(find.text('—'), findsWidgets);
  });

  testWidgets('le taux d\'endettement réutilise le service central (mensualité de crédit / revenus)', (tester) async {
    final cycleId = await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
    await repository.createIncome(
      cycleId: cycleId,
      name: 'Salaire',
      expectedAmountCents: 300000,
      expectedDate: DateTime(2026, 1, 1),
    );
    await repository.createCredit(
      name: 'Voiture',
      initialAmountCents: 1500000,
      remainingCapitalCents: 900000,
      monthlyPaymentCents: 60000,
      expectedEndDate: DateTime(2029, 1, 1),
      remainingInstallments: 36,
    );

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // 60000 / 300000 = 20 %.
    expect(find.text(formatRatioAsPercent(0.20)), findsOneWidget);
  });

  testWidgets('les dépenses du cycle n\'incluent jamais les charges fixes ni l\'épargne', (tester) async {
    final cycleId = await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
    await repository.createIncome(
      cycleId: cycleId,
      name: 'Salaire',
      expectedAmountCents: 300000,
      expectedDate: DateTime(2026, 1, 1),
    );
    await repository.createFixedExpense(
      cycleId: cycleId,
      name: 'Loyer',
      expectedAmountCents: 90000,
      expectedDate: DateTime(2026, 1, 5),
    );
    await repository.createSaving(
      cycleId: cycleId,
      name: 'Livret',
      expectedAmountCents: 20000,
      expectedDate: DateTime(2026, 1, 6),
    );
    await repository.createVariableExpense(cycleId: cycleId, amountCents: 15000, date: DateTime(2026, 1, 10));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text(formatCentsAsEuro(15000)), findsOneWidget);
    expect(find.text(formatCentsAsEuro(90000)), findsNothing);
    expect(find.text(formatCentsAsEuro(20000)), findsNothing);
  });
}
