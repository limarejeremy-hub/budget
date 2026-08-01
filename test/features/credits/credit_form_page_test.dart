import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:budgetpilot/core/providers/database_provider.dart';
import 'package:budgetpilot/data/local/cycle_repository.dart';
import 'package:budgetpilot/data/local/database.dart';
import 'package:budgetpilot/features/credits/credit_form_page.dart';
import 'package:budgetpilot/features/credits/credit_visuals.dart';

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

  // Le formulaire Crédit compte une quinzaine de champs : un viewport de
  // test haut est nécessaire pour que le bouton "Enregistrer", tout en bas,
  // soit effectivement construit (ListView reste "lazy" même à contenu
  // statique) et atteignable par tap() sans avoir à défiler.
  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 4800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('affiche des erreurs de validation si le formulaire est vide', (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(wrap(const CreditFormPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Enregistrer'));
    await tester.pump();

    expect(find.text('Nom requis'), findsOneWidget);
    expect(find.text('Montant requis'), findsNWidgets(3));
    expect(find.text('Champ requis'), findsOneWidget);
  });

  testWidgets('un formulaire valide crée bien le crédit en base', (tester) async {
    useTallViewport(tester);
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
    useTallViewport(tester);
    await tester.pumpWidget(wrap(const CreditFormPage()));
    await tester.pumpAndSettle();

    // Le champ ne laisse passer que chiffres/point/virgule (inputFormatters)
    // — "1.2.3" est donc saisissable mais reste un nombre invalide.
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Taux annuel % (facultatif)'), '1.2.3');
    await tester.tap(find.text('Enregistrer'));
    await tester.pump();

    expect(find.text('Taux invalide'), findsOneWidget);
  });

  testWidgets("l'organisme, la couleur et l'icône choisis sont bien enregistrés", (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(wrap(const CreditFormPage()));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Nom (ex : Voiture, Prêt immobilier)'), 'Voiture');
    await tester.enterText(find.widgetWithText(TextFormField, 'Organisme (facultatif)'), 'Boursorama');
    await tester.enterText(find.widgetWithText(TextFormField, 'Montant initial emprunté'), '15000');
    await tester.enterText(find.widgetWithText(TextFormField, 'Capital restant dû'), '9000');
    await tester.enterText(find.widgetWithText(TextFormField, 'Mensualité'), '250');
    await tester.enterText(find.widgetWithText(TextFormField, 'Mensualités restantes'), '36');

    final secondColor = creditColorPalette[1];
    final secondIcon = creditIconPalette[1];
    await tester.tap(find.byKey(ValueKey('credit_color_${secondColor.toARGB32()}')));
    await tester.tap(find.byKey(ValueKey('credit_icon_${secondIcon.codePoint}')));
    await tester.pump();

    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    final credit = (await repository.loadCredits()).single;
    expect(credit.organisme, 'Boursorama');
    expect(credit.colorValue, secondColor.toARGB32());
    expect(credit.iconCodePoint, secondIcon.codePoint);
  });

  testWidgets('le jour de prélèvement et l\'assurance choisis sont bien enregistrés', (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(wrap(const CreditFormPage()));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Nom (ex : Voiture, Prêt immobilier)'), 'Voiture');
    await tester.enterText(find.widgetWithText(TextFormField, 'Montant initial emprunté'), '15000');
    await tester.enterText(find.widgetWithText(TextFormField, 'Capital restant dû'), '9000');
    await tester.enterText(find.widgetWithText(TextFormField, 'Mensualité'), '250');
    await tester.enterText(find.widgetWithText(TextFormField, 'Mensualités restantes'), '36');
    await tester.enterText(find.widgetWithText(TextFormField, 'Jour de prélèvement (facultatif)'), '5');
    await tester.enterText(find.widgetWithText(TextFormField, 'Assurance mensuelle (facultatif)'), '12');

    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    final credit = (await repository.loadCredits()).single;
    expect(credit.paymentDayOfMonth, 5);
    expect(credit.insuranceCents, 1200);
  });

  testWidgets('un jour de prélèvement hors 1-31 affiche une erreur', (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(wrap(const CreditFormPage()));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Jour de prélèvement (facultatif)'), '35');
    await tester.tap(find.text('Enregistrer'));
    await tester.pump();

    expect(find.text('Jour invalide (1-31)'), findsOneWidget);
  });
}
