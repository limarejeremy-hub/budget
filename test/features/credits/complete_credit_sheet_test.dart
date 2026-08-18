import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:budgetpilot/core/providers/database_provider.dart';
import 'package:budgetpilot/data/local/cycle_repository.dart';
import 'package:budgetpilot/data/local/database.dart';
import 'package:budgetpilot/domain/calculations/credit_term_calculator.dart';
import 'package:budgetpilot/features/credits/widgets/complete_credit_sheet.dart';
import 'package:budgetpilot/features/entries/fixed_expense_form_page.dart';

/// UX de la BottomSheet "Compléter les informations du crédit" : mensualité
/// jamais redemandée (déjà connue via la charge), et choix explicite entre
/// "date de fin prévue" et "mensualités restantes" — jamais les deux à la
/// fois.
const _termCalculator = CreditTermCalculator();

late AppDatabase _db;
late CycleRepository _repository;

Widget _wrap(Widget child) {
  return ProviderScope(
    overrides: [appDatabaseProvider.overrideWith((ref) => _db)],
    child: MaterialApp(home: child),
  );
}

Future<void> _selectCreditCategory(WidgetTester tester) async {
  await tester.tap(find.text('Aucune catégorie'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Crédit').last);
  await tester.pumpAndSettle();
}

Future<Finder> _openSheet(WidgetTester tester,
    {required int cycleId, required String name, required String amount}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(_wrap(FixedExpenseFormPage(cycleId: cycleId)));
  await tester.pumpAndSettle();

  await tester.enterText(find.widgetWithText(TextFormField, 'Nom'), name);
  await tester.enterText(find.widgetWithText(TextFormField, 'Montant prévu'), amount);
  await _selectCreditCategory(tester);

  await tester.tap(find.widgetWithText(FilledButton, 'Enregistrer'));
  await tester.pumpAndSettle();

  return find.byType(CompleteCreditSheet);
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

  testWidgets('ne demande jamais la mensualité (déjà connue via la charge)', (tester) async {
    final cycleId = await _repository.createCycle(
      startDate: DateTime(2026, 7, 27),
      endDate: DateTime(2026, 8, 26),
    );
    final sheetFinder = await _openSheet(tester, cycleId: cycleId, name: 'Crédit auto', amount: '275');

    expect(
      find.descendant(of: sheetFinder, matching: find.widgetWithText(TextFormField, 'Mensualité')),
      findsNothing,
    );
  });

  testWidgets('mode par défaut : "Mensualités restantes" (compatibilité avec le comportement historique)',
      (tester) async {
    final cycleId = await _repository.createCycle(
      startDate: DateTime(2026, 7, 27),
      endDate: DateTime(2026, 8, 26),
    );
    final sheetFinder = await _openSheet(tester, cycleId: cycleId, name: 'Crédit auto', amount: '275');

    expect(
      find.descendant(of: sheetFinder, matching: find.widgetWithText(TextFormField, 'Mensualités restantes')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheetFinder, matching: find.widgetWithText(TextFormField, 'Date de fin prévue')),
      findsNothing,
    );
  });

  testWidgets('saisir les mensualités restantes affiche la fin estimée calculée', (tester) async {
    final cycleId = await _repository.createCycle(
      startDate: DateTime(2026, 7, 27),
      endDate: DateTime(2026, 8, 26),
    );
    final sheetFinder = await _openSheet(tester, cycleId: cycleId, name: 'Crédit auto', amount: '275');

    await tester.enterText(
      find.descendant(of: sheetFinder, matching: find.widgetWithText(TextFormField, 'Mensualités restantes')),
      '24',
    );
    await tester.pump();

    expect(find.descendant(of: sheetFinder, matching: find.textContaining('Fin estimée')), findsOneWidget);
  });

  testWidgets('basculer sur "Date de fin prévue" masque le champ mensualités et calcule automatiquement',
      (tester) async {
    final cycleId = await _repository.createCycle(
      startDate: DateTime(2026, 7, 27),
      endDate: DateTime(2026, 8, 26),
    );
    final sheetFinder = await _openSheet(tester, cycleId: cycleId, name: 'Prêt travaux', amount: '150');

    await tester.enterText(
      find.descendant(of: sheetFinder, matching: find.widgetWithText(TextFormField, 'Capital initial emprunté')),
      '5000',
    );
    await tester.enterText(
      find.descendant(of: sheetFinder, matching: find.widgetWithText(TextFormField, 'Capital restant dû')),
      '4000',
    );

    await tester.tap(find.descendant(
      of: sheetFinder,
      matching: find.widgetWithText(ChoiceChip, 'Date de fin prévue'),
    ));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: sheetFinder, matching: find.widgetWithText(TextFormField, 'Mensualités restantes')),
      findsNothing,
    );
    expect(find.descendant(of: sheetFinder, matching: find.textContaining('mensualité')), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Créer le crédit'));
    await tester.pumpAndSettle();

    final credit = (await _repository.loadCredits()).single;
    // Date par défaut proposée : aujourd'hui + 365 jours (~12 mois).
    expect(credit.remainingInstallments, inInclusiveRange(11, 13));
    expect(credit.monthlyPaymentCents, 15000);
  });

  testWidgets('la mensualité de la charge (montant prévu) devient la mensualité du crédit sans être redemandée',
      (tester) async {
    final cycleId = await _repository.createCycle(
      startDate: DateTime(2026, 7, 27),
      endDate: DateTime(2026, 8, 26),
    );
    final sheetFinder = await _openSheet(tester, cycleId: cycleId, name: 'Crédit auto', amount: '275');

    await tester.enterText(
      find.descendant(of: sheetFinder, matching: find.widgetWithText(TextFormField, 'Capital initial emprunté')),
      '10000',
    );
    await tester.enterText(
      find.descendant(of: sheetFinder, matching: find.widgetWithText(TextFormField, 'Capital restant dû')),
      '8000',
    );
    await tester.enterText(
      find.descendant(of: sheetFinder, matching: find.widgetWithText(TextFormField, 'Mensualités restantes')),
      '30',
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Créer le crédit'));
    await tester.pumpAndSettle();

    final credit = (await _repository.loadCredits()).single;
    expect(credit.monthlyPaymentCents, 27500);
  });

  test('monthsUntil et addMonths restent cohérents pour un scénario "date de fin" réaliste', () {
    final today = DateTime(2026, 8, 1);
    final end = DateTime(2030, 8, 7);
    final months = _termCalculator.monthsUntil(today, end);
    expect(_termCalculator.addMonths(today, months).month, end.month);
    expect(_termCalculator.addMonths(today, months).year, end.year);
  });
}
