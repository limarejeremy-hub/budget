import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:budgetpilot/core/providers/database_provider.dart';
import 'package:budgetpilot/data/local/cycle_repository.dart';
import 'package:budgetpilot/data/local/database.dart';
import 'package:budgetpilot/features/entries/fixed_expense_form_page.dart';

void main() {
  late AppDatabase db;
  late CycleRepository repository;
  late int cycleId;

  Widget wrap(Widget child) {
    return ProviderScope(
      overrides: [appDatabaseProvider.overrideWith((ref) => db)],
      child: MaterialApp(home: child),
    );
  }

  setUpAll(() async {
    await initializeDateFormatting('fr_FR', null);
  });

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = CycleRepository(db);
    cycleId =
        await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
  });

  tearDown(() => db.close());

  testWidgets('affiche des erreurs de validation si le formulaire est vide', (tester) async {
    await tester.pumpWidget(wrap(FixedExpenseFormPage(cycleId: cycleId)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Enregistrer'));
    await tester.pump();

    expect(find.text('Nom requis'), findsOneWidget);
    expect(find.text('Montant requis'), findsOneWidget);
  });

  testWidgets('rejette un montant invalide ou négatif', (tester) async {
    await tester.pumpWidget(wrap(FixedExpenseFormPage(cycleId: cycleId)));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Nom'), 'Loyer');
    await tester.enterText(find.widgetWithText(TextFormField, 'Montant prévu'), '0');
    await tester.tap(find.text('Enregistrer'));
    await tester.pump();

    expect(find.text('Le montant doit être supérieur à 0'), findsOneWidget);
  });

  testWidgets('un formulaire valide crée bien la charge fixe en base', (tester) async {
    await tester.pumpWidget(wrap(FixedExpenseFormPage(cycleId: cycleId)));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Nom'), 'Loyer');
    await tester.enterText(find.widgetWithText(TextFormField, 'Montant prévu'), '850,00');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    final data = await repository.loadCurrentCycleData();
    expect(data!.fixedExpenses, hasLength(1));
    expect(data.fixedExpenses.single.name, 'Loyer');
    expect(data.fixedExpenses.single.expectedAmountCents, 85000);
  });
}
