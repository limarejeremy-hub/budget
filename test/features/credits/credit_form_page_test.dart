import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:budgetpilot/core/providers/database_provider.dart';
import 'package:budgetpilot/data/local/cycle_repository.dart';
import 'package:budgetpilot/data/local/database.dart';
import 'package:budgetpilot/features/credits/credit_form_page.dart';

void main() {
  late AppDatabase db;
  late CycleRepository repository;

  Widget wrap(Widget child) {
    return ProviderScope(
      overrides: [appDatabaseProvider.overrideWith((ref) => db)],
      child: MaterialApp(home: child),
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

  testWidgets('affiche des erreurs de validation si le formulaire est vide', (tester) async {
    await tester.pumpWidget(wrap(const CreditFormPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Enregistrer'));
    await tester.pump();

    expect(find.text('Nom requis'), findsOneWidget);
    expect(find.text('Montant requis'), findsNWidgets(3));
    expect(find.text('Champ requis'), findsOneWidget);
  });

  testWidgets('un formulaire valide crée bien le crédit en base', (tester) async {
    await tester.pumpWidget(wrap(const CreditFormPage()));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Nom (ex : Voiture, Prêt immobilier)'), 'Voiture');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Montant initial emprunté'), '15000');
    await tester.enterText(find.widgetWithText(TextFormField, 'Capital restant dû'), '9000');
    await tester.enterText(find.widgetWithText(TextFormField, 'Mensualité'), '250');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Mensualités restantes'), '36');

    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    final credits = await repository.loadCredits();
    expect(credits, hasLength(1));
    expect(credits.single.name, 'Voiture');
    expect(credits.single.initialAmountCents, 1500000);
    expect(credits.single.remainingCapitalCents, 900000);
    expect(credits.single.monthlyPaymentCents, 25000);
    expect(credits.single.remainingInstallments, 36);
  });

  testWidgets('un taux invalide affiche une erreur', (tester) async {
    await tester.pumpWidget(wrap(const CreditFormPage()));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Taux annuel % (facultatif)'), 'abc');
    await tester.tap(find.text('Enregistrer'));
    await tester.pump();

    expect(find.text('Taux invalide'), findsOneWidget);
  });
}
