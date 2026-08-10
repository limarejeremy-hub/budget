import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:budgetpilot/core/providers/database_provider.dart';
import 'package:budgetpilot/data/local/cycle_repository.dart';
import 'package:budgetpilot/data/local/database.dart';
import 'package:budgetpilot/features/credits/widgets/credits_summary_card.dart';

void main() {
  late AppDatabase db;
  late CycleRepository repository;

  Widget wrap() {
    return ProviderScope(
      overrides: [appDatabaseProvider.overrideWith((ref) => db)],
      child: const MaterialApp(home: Scaffold(body: CreditsSummaryCard())),
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

  testWidgets("affiche 'Aucun crédit en cours' quand il n'y a aucun crédit", (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Aucun crédit en cours'), findsOneWidget);
  });

  testWidgets('affiche le résumé quand des crédits existent', (tester) async {
    await repository.createCredit(
      name: 'Montre',
      initialAmountCents: 80000,
      remainingCapitalCents: 40000,
      monthlyPaymentCents: 5000,
      expectedEndDate: DateTime(2027, 1, 1),
      remainingInstallments: 8,
    );

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.textContaining('Prochain terminé : Montre'), findsOneWidget);
  });

  testWidgets('la carte Crédits est cliquable et ouvre la page Crédits', (tester) async {
    await repository.createCredit(
      name: 'Montre',
      initialAmountCents: 80000,
      remainingCapitalCents: 40000,
      monthlyPaymentCents: 5000,
      expectedEndDate: DateTime(2027, 1, 1),
      remainingInstallments: 8,
    );

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Crédits'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Crédits'), findsOneWidget);
    expect(find.text('Capital restant total'), findsOneWidget);
  });
}
