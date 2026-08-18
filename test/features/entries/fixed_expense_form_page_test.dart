import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:budgetpilot/core/constants/app_constants.dart';
import 'package:budgetpilot/core/providers/database_provider.dart';
import 'package:budgetpilot/core/widgets/date_picker_field.dart';
import 'package:budgetpilot/data/local/converters/entity_mappers.dart';
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
    // Fenêtre volontairement large : une charge créée sans préciser de
    // date reprend DateTime.now() (cf. FixedExpenseFormPage.initState) et
    // n'appartient au cycle (correctif "affectation des charges par
    // date") que si cette date tombe dans ses bornes.
    cycleId = await repository.createCycle(startDate: DateTime(2020, 1, 1), endDate: DateTime(2035, 12, 31));
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

  group('récurrence (correctif "échéances récurrentes hors cycle")', () {
    testWidgets('une charge ponctuelle ne crée aucun modèle récurrent', (tester) async {
      await tester.pumpWidget(wrap(FixedExpenseFormPage(cycleId: cycleId)));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'Nom'), 'Réparation');
      await tester.enterText(find.widgetWithText(TextFormField, 'Montant prévu'), '120');
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      final data = await repository.loadCurrentCycleData();
      expect(data!.fixedExpenses.single.templateId, isNull);
    });

    testWidgets('activer "Charge récurrente" affiche le sélecteur, par défaut Mensuel (jour fixe)', (tester) async {
      await tester.pumpWidget(wrap(FixedExpenseFormPage(cycleId: cycleId)));
      await tester.pumpAndSettle();

      expect(find.text('Récurrence'), findsNothing);
      await tester.tap(find.widgetWithText(SwitchListTile, 'Charge récurrente'));
      await tester.pumpAndSettle();

      expect(find.text('Récurrence'), findsOneWidget);
      expect(find.text('Mensuel (jour fixe)'), findsOneWidget);
      expect(find.text('Tous les combien de semaines ?'), findsNothing);
    });

    testWidgets('"Toutes les X semaines" crée un modèle récurrent avec le bon intervalle', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrap(FixedExpenseFormPage(cycleId: cycleId)));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'Nom'), 'Prélèvement X');
      await tester.enterText(find.widgetWithText(TextFormField, 'Montant prévu'), '50');
      await tester.tap(find.widgetWithText(SwitchListTile, 'Charge récurrente'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mensuel (jour fixe)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Toutes les X semaines').last);
      await tester.pumpAndSettle();

      expect(find.text('Tous les combien de semaines ?'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextFormField, 'Tous les combien de semaines ?'), '4');
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      final data = await repository.loadCurrentCycleData();
      final charge = data!.fixedExpenses.single;
      expect(charge.templateId, isNotNull);
      final template = await repository.loadTemplate(charge.templateId!);
      expect(template!.recurrenceType, RecurrenceType.toutesLesXSemaines);
      expect(template.intervalValue, 4);
    });

    testWidgets('modifier une charge récurrente existante précharge son type de récurrence', (tester) async {
      await repository.createFixedExpense(
        cycleId: cycleId,
        name: 'Prélèvement X',
        expectedAmountCents: 5000,
        expectedDate: DateTime(2026, 1, 5),
        isRecurring: true,
        recurrenceType: RecurrenceType.tousLesXJours,
        recurrenceIntervalValue: 10,
      );
      final data = await repository.loadCurrentCycleData();
      final existing = fixedExpenseFromRow(data!.fixedExpenses.single);

      await tester.pumpWidget(wrap(FixedExpenseFormPage(cycleId: cycleId, existing: existing)));
      await tester.pumpAndSettle();

      expect(find.text('Tous les X jours'), findsOneWidget);
      expect(find.text('Tous les combien de jours ?'), findsOneWidget);
      final intervalField =
          tester.widget<TextFormField>(find.widgetWithText(TextFormField, 'Tous les combien de jours ?'));
      expect(intervalField.controller!.text, '10');
    });
  });

  group('correctif "affectation des charges par date"', () {
    testWidgets('déplacer manuellement une date hors du cycle retire immédiatement la charge du total', (tester) async {
      // setUp ouvre un cycle très large (2020-2035) pour laisser les autres
      // tests créer librement des charges datées d'aujourd'hui — on le
      // referme ici pour un cycle volontairement étroit, seul moyen de
      // tester un déplacement de date qui en sort réellement.
      await repository.closeCycle(cycleId);
      final narrowCycleId = await repository.createCycle(
        startDate: DateTime(2026, 7, 28),
        endDate: DateTime(2026, 8, 28),
      );
      await repository.createFixedExpense(
        cycleId: narrowCycleId,
        name: 'Prélèvement X',
        expectedAmountCents: 10000,
        expectedDate: DateTime(2026, 8, 26),
      );
      final data = await repository.loadCurrentCycleData();
      final existing = fixedExpenseFromRow(data!.fixedExpenses.single);
      expect((await repository.loadCurrentCycleData())!.fixedExpenses, hasLength(1));

      await tester.pumpWidget(wrap(FixedExpenseFormPage(cycleId: narrowCycleId, existing: existing)));
      await tester.pumpAndSettle();

      // Contourne le sélecteur de date natif (non interactif en test) en
      // appelant directement le callback du champ, exactement comme le
      // ferait un utilisateur choisissant une date dans le calendrier.
      final dateField = tester.widget<DatePickerField>(find.byType(DatePickerField).first);
      dateField.onChanged(DateTime(2026, 8, 30));
      await tester.pump();

      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      final after = await repository.loadCurrentCycleData();
      expect(after!.fixedExpenses, isEmpty, reason: '30 août est hors du cycle (28/07 -> 28/08)');
    });
  });
}
