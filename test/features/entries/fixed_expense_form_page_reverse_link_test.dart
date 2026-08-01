import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:budgetpilot/core/providers/database_provider.dart';
import 'package:budgetpilot/data/local/cycle_repository.dart';
import 'package:budgetpilot/data/local/database.dart';
import 'package:budgetpilot/features/credits/widgets/complete_credit_sheet.dart';
import 'package:budgetpilot/features/entries/fixed_expense_form_page.dart';

/// Test d'intégration complet (bug rapporté après la V0.9) : une charge
/// fixe enregistrée avec la catégorie "Crédit" ne doit jamais rester une
/// charge isolée. Ce fichier fait tourner le vrai flux UI (formulaire de
/// charge -> BottomSheet "Compléter les informations du crédit") sur une
/// vraie base Drift, exactement comme le scénario décrit par l'utilisateur.
late AppDatabase _db;
late CycleRepository _repository;

Widget _wrap(Widget child) {
  return ProviderScope(
    overrides: [appDatabaseProvider.overrideWith((ref) => _db)],
    child: MaterialApp(home: child),
  );
}

Future<int> _selectCreditCategory(WidgetTester tester) async {
  await tester.tap(find.text('Aucune catégorie'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Crédit').last);
  await tester.pumpAndSettle();
  final categories = await _repository.categoriesForType('fixed_expense');
  return categories.firstWhere((c) => c.name == 'Crédit').id;
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

  Future<void> setUpViewport(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
      'créer une charge fixe catégorie Crédit ouvre la BottomSheet, crée le crédit, '
      'le lie à la charge, avance une seule fois à la confirmation, et le lien persiste '
      'après réouverture de la base', (tester) async {
    final cycleId = await _repository.createCycle(
      startDate: DateTime(2026, 7, 27),
      endDate: DateTime(2026, 8, 26),
    );
    await setUpViewport(tester);

    await tester.pumpWidget(_wrap(FixedExpenseFormPage(cycleId: cycleId)));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Nom'), 'Voiture');
    await tester.enterText(find.widgetWithText(TextFormField, 'Montant prévu'), '250');
    await _selectCreditCategory(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Enregistrer'));
    await tester.pumpAndSettle();

    // La BottomSheet "Compléter les informations du crédit" doit s'ouvrir
    // immédiatement — aucun crédit "Voiture" n'existe encore.
    expect(find.byType(CompleteCreditSheet), findsOneWidget);
    expect(find.text('Compléter les informations du crédit'), findsOneWidget);

    final sheetFinder = find.byType(CompleteCreditSheet);
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
      '32',
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Créer le crédit'));
    await tester.pumpAndSettle();

    // La charge est enregistrée, on revient au formulaire précédent (Nouvelle charge fixe).
    expect(find.byType(FixedExpenseFormPage), findsNothing);

    // 1. Un crédit "Voiture" existe désormais dans la page Crédits (vérifié au niveau
    // repository, source de vérité de ce que la page affiche).
    final credits = await _repository.loadCredits();
    expect(credits, hasLength(1));
    final credit = credits.single;
    expect(credit.name, 'Voiture');
    expect(credit.remainingCapitalCents, 800000);
    expect(credit.monthlyPaymentCents, 25000);
    expect(credit.remainingInstallments, 32);

    // 2. La charge contient bien son creditId.
    final charges = await (_db.select(_db.fixedExpenses)..where((e) => e.cycleId.equals(cycleId))).get();
    expect(charges, hasLength(1));
    final charge = charges.single;
    expect(charge.name, 'Voiture');
    expect(charge.linkedCreditId, credit.id);

    // 3. Confirmer la charge : le crédit avance une seule fois.
    final result = await _repository.confirmFixedExpense(charge.id);
    expect(result, isNotNull);
    expect(result!.credit.remainingCapitalCents, 775000);
    expect(result.credit.remainingInstallments, 31);

    // Un second appel (ex : action de notification traitée deux fois) ne
    // doit jamais réappliquer le paiement.
    final secondResult = await _repository.confirmFixedExpense(charge.id);
    expect(secondResult, isNull);
    final creditsAfterDoubleConfirm = await _repository.loadCredits();
    expect(creditsAfterDoubleConfirm.single.remainingCapitalCents, 775000);
    expect(creditsAfterDoubleConfirm.single.remainingInstallments, 31);
  });

  test('le lien crédit ⇄ charge persiste après fermeture puis réouverture de la base (fichier réel)',
      () async {
    // 4. "Rouvrir l'application" — même principe que
    // test/data/persistence_test.dart : un fichier SQLite réel, fermé puis
    // rouvert, plutôt qu'une base en mémoire (qui ne prouverait rien ici).
    final tempDir = await Directory.systemTemp.createTemp('budgetpilot_reverse_link_test');
    addTearDown(() => tempDir.delete(recursive: true));
    final dbFile = File('${tempDir.path}/budgetpilot.sqlite');

    var fileDb = AppDatabase.forTesting(NativeDatabase(dbFile));
    var fileRepository = CycleRepository(fileDb);
    final fileCycleId = await fileRepository.createCycle(
      startDate: DateTime(2026, 7, 27),
      endDate: DateTime(2026, 8, 26),
    );
    final fileCreditId = await fileRepository.createCreditForExistingCharge(
      name: 'Voiture',
      initialAmountCents: 1000000,
      remainingCapitalCents: 775000,
      monthlyPaymentCents: 25000,
      expectedEndDate: DateTime(2029, 3, 27),
      remainingInstallments: 31,
    );
    await fileRepository.createFixedExpense(
      cycleId: fileCycleId,
      name: 'Voiture',
      expectedAmountCents: 25000,
      expectedDate: DateTime(2026, 7, 27),
      linkedCreditId: fileCreditId,
    );
    await fileDb.close();

    fileDb = AppDatabase.forTesting(NativeDatabase(dbFile));
    fileRepository = CycleRepository(fileDb);
    final reloadedCharges = await (fileDb.select(fileDb.fixedExpenses)).get();
    expect(reloadedCharges.single.linkedCreditId, fileCreditId);
    final reloadedCredits = await fileRepository.loadCredits();
    expect(reloadedCredits.single.id, fileCreditId);
    await fileDb.close();
  });

  testWidgets('annuler la BottomSheet ne crée ni crédit ni charge orpheline', (tester) async {
    final cycleId = await _repository.createCycle(
      startDate: DateTime(2026, 7, 27),
      endDate: DateTime(2026, 8, 26),
    );
    await setUpViewport(tester);

    await tester.pumpWidget(_wrap(FixedExpenseFormPage(cycleId: cycleId)));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Nom'), 'Prêt perso');
    await tester.enterText(find.widgetWithText(TextFormField, 'Montant prévu'), '120');
    await _selectCreditCategory(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Enregistrer'));
    await tester.pumpAndSettle();

    expect(find.byType(CompleteCreditSheet), findsOneWidget);
    await tester.tap(find.descendant(
      of: find.byType(CompleteCreditSheet),
      matching: find.widgetWithText(OutlinedButton, 'Annuler'),
    ));
    await tester.pumpAndSettle();

    // Toujours sur le formulaire de charge — rien n'a été enregistré.
    expect(find.byType(FixedExpenseFormPage), findsOneWidget);
    expect(find.textContaining('Choisissez une autre catégorie'), findsOneWidget);

    final credits = await _repository.loadCredits();
    expect(credits, isEmpty);
    final charges = await (_db.select(_db.fixedExpenses)).get();
    expect(charges, isEmpty);
  });

  testWidgets('un nom correspondant à un crédit existant relie automatiquement sans ouvrir la BottomSheet',
      (tester) async {
    final cycleId = await _repository.createCycle(
      startDate: DateTime(2026, 7, 27),
      endDate: DateTime(2026, 8, 26),
    );
    final creditId = await _repository.createCreditForExistingCharge(
      name: 'Maison',
      initialAmountCents: 20000000,
      remainingCapitalCents: 15000000,
      monthlyPaymentCents: 87500,
      expectedEndDate: DateTime(2040, 1, 1),
      remainingInstallments: 180,
    );
    await setUpViewport(tester);

    await tester.pumpWidget(_wrap(FixedExpenseFormPage(cycleId: cycleId)));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Nom'), 'Maison');
    await tester.enterText(find.widgetWithText(TextFormField, 'Montant prévu'), '875');
    await _selectCreditCategory(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Enregistrer'));
    await tester.pumpAndSettle();

    // Aucune BottomSheet : la correspondance a été trouvée automatiquement.
    expect(find.byType(CompleteCreditSheet), findsNothing);
    expect(find.byType(FixedExpenseFormPage), findsNothing);

    final credits = await _repository.loadCredits();
    expect(credits, hasLength(1));
    expect(credits.single.id, creditId);

    final charges = await (_db.select(_db.fixedExpenses)).get();
    expect(charges, hasLength(1));
    expect(charges.single.linkedCreditId, creditId);
  });

  testWidgets(
      'un second crédit du même nom déjà lié dans le cycle ne relie pas automatiquement (prévention des doublons)',
      (tester) async {
    final cycleId = await _repository.createCycle(
      startDate: DateTime(2026, 7, 27),
      endDate: DateTime(2026, 8, 26),
    );
    final creditId = await _repository.createCreditForExistingCharge(
      name: 'Maison',
      initialAmountCents: 20000000,
      remainingCapitalCents: 15000000,
      monthlyPaymentCents: 87500,
      expectedEndDate: DateTime(2040, 1, 1),
      remainingInstallments: 180,
    );
    // Le crédit "Maison" a déjà sa mensualité dans ce cycle.
    await _repository.createFixedExpense(
      cycleId: cycleId,
      name: 'Maison',
      expectedAmountCents: 87500,
      expectedDate: DateTime(2026, 7, 27),
      linkedCreditId: creditId,
    );
    await setUpViewport(tester);

    await tester.pumpWidget(_wrap(FixedExpenseFormPage(cycleId: cycleId)));
    await tester.pumpAndSettle();

    // Un utilisateur crée par erreur une deuxième charge "Maison" dans le même cycle.
    await tester.enterText(find.widgetWithText(TextFormField, 'Nom'), 'Maison');
    await tester.enterText(find.widgetWithText(TextFormField, 'Montant prévu'), '875');
    await _selectCreditCategory(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Enregistrer'));
    await tester.pumpAndSettle();

    // Le crédit "Maison" est déjà relié dans ce cycle : pas de liaison
    // automatique silencieuse — la BottomSheet de complétion s'ouvre plutôt
    // que de dupliquer la mensualité.
    expect(find.byType(CompleteCreditSheet), findsOneWidget);

    await tester.tap(find.descendant(
      of: find.byType(CompleteCreditSheet),
      matching: find.widgetWithText(OutlinedButton, 'Annuler'),
    ));
    await tester.pumpAndSettle();
  });
}
