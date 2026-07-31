import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:budgetpilot/core/providers/database_provider.dart';
import 'package:budgetpilot/data/local/cycle_repository.dart';
import 'package:budgetpilot/data/local/database.dart';
import 'package:budgetpilot/features/credits/widgets/credit_advice_card.dart';

void main() {
  late AppDatabase db;
  late CycleRepository repository;

  Widget wrap() {
    return ProviderScope(
      overrides: [appDatabaseProvider.overrideWith((ref) => db)],
      child: const MaterialApp(home: Scaffold(body: CreditAdviceCard())),
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

  testWidgets("reste invisible quand il n'y a aucun crédit actif", (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pump();
    await tester.pump();

    expect(find.text('Objectif conseillé'), findsNothing);
  });

  testWidgets('suggère le crédit actif au capital restant le plus faible', (tester) async {
    await repository.createCredit(
      name: 'Voiture',
      initialAmountCents: 1500000,
      remainingCapitalCents: 900000,
      monthlyPaymentCents: 25000,
      expectedEndDate: DateTime(2029, 1, 1),
      remainingInstallments: 36,
    );
    await repository.createCredit(
      name: 'Samsung Fold',
      initialAmountCents: 80000,
      remainingCapitalCents: 32000,
      monthlyPaymentCents: 8000,
      expectedEndDate: DateTime(2027, 1, 1),
      remainingInstallments: 4,
    );

    await tester.pumpWidget(wrap());
    await tester.pump();
    await tester.pump();

    expect(find.text('Objectif conseillé'), findsOneWidget);
    expect(find.textContaining('Samsung Fold'), findsOneWidget);
    expect(find.textContaining('dans 4 mois'), findsOneWidget);
  });

  testWidgets('reste invisible si le crédit le plus proche a un capital restant nul', (tester) async {
    await repository.createCredit(
      name: 'Crédit soldé',
      initialAmountCents: 80000,
      remainingCapitalCents: 0,
      monthlyPaymentCents: 8000,
      expectedEndDate: DateTime(2027, 1, 1),
      remainingInstallments: 0,
    );

    await tester.pumpWidget(wrap());
    await tester.pump();
    await tester.pump();

    expect(find.text('Objectif conseillé'), findsNothing);
  });
}
