import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:budgetpilot/core/providers/database_provider.dart';
import 'package:budgetpilot/data/local/cycle_repository.dart';
import 'package:budgetpilot/data/local/database.dart';
import 'package:budgetpilot/features/settings/settings_page.dart';

void main() {
  late AppDatabase db;
  late CycleRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = CycleRepository(db);
  });

  tearDown(() => db.close());

  Widget wrap() {
    return ProviderScope(
      overrides: [appDatabaseProvider.overrideWith((ref) => db)],
      child: const MaterialApp(home: SettingsPage()),
    );
  }

  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('le thème système est sélectionné par défaut', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    final segmented = tester.widget<SegmentedButton<ThemeMode>>(find.byType(SegmentedButton<ThemeMode>));
    expect(segmented.selected, {ThemeMode.system});
  });

  testWidgets('changer de thème persiste le choix', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sombre'));
    await tester.pumpAndSettle();

    final segmented = tester.widget<SegmentedButton<ThemeMode>>(find.byType(SegmentedButton<ThemeMode>));
    expect(segmented.selected, {ThemeMode.dark});
  });

  testWidgets('Documentation ouvre la page de documentation', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Documentation'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Documentation'), findsOneWidget);
    expect(find.text('Utiliser BudgetPilot au quotidien'), findsOneWidget);
  });

  testWidgets('7 appuis sur la version révèlent le menu développeur', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Charger les données de démonstration'), findsNothing);

    for (var i = 0; i < 7; i++) {
      await tester.tap(find.text('Version 1.1.0'));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.text('Charger les données de démonstration'), findsOneWidget);
  });

  group('"Repartir de zéro" (Paramètres > Données)', () {
    Future<void> seedSomeData() async {
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
        monthlyPaymentCents: 25000,
        expectedEndDate: DateTime(2029, 1, 1),
        remainingInstallments: 36,
      );
    }

    testWidgets('affiche la section Données avec l\'action "Repartir de zéro"', (tester) async {
      useTallViewport(tester);
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('Données'), findsOneWidget);
      expect(find.text('Repartir de zéro'), findsOneWidget);
    });

    testWidgets('annuler la première confirmation ne supprime rien', (tester) async {
      useTallViewport(tester);
      await seedSomeData();
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Repartir de zéro'));
      await tester.pumpAndSettle();

      expect(find.text('Repartir de zéro ?'), findsOneWidget);
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(await db.select(db.budgetCycles).get(), isNotEmpty);
    });

    testWidgets('la seconde confirmation affiche le texte exact requis, annuler ne supprime rien', (tester) async {
      useTallViewport(tester);
      await seedSomeData();
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Repartir de zéro'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      expect(
        find.text('Cette action supprimera toutes vos données financières et ne pourra pas être annulée.'),
        findsOneWidget,
      );
      expect(find.text('Dernière confirmation'), findsOneWidget);

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(await db.select(db.budgetCycles).get(), isNotEmpty);
    });

    testWidgets('confirmer les deux étapes supprime toutes les données financières', (tester) async {
      useTallViewport(tester);
      await seedSomeData();
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Repartir de zéro'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Repartir de zéro').last);
      await tester.pumpAndSettle();

      expect(await db.select(db.budgetCycles).get(), isEmpty);
      expect(await repository.loadProjects(), isEmpty);
      final credits = await db.select(db.credits).get();
      expect(credits, isEmpty);
      expect(find.text('Toutes les données ont été supprimées'), findsOneWidget);
    });

    testWidgets('les préférences (thème) survivent à la réinitialisation', (tester) async {
      useTallViewport(tester);
      await seedSomeData();
      await repository.setThemeMode('dark');
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Repartir de zéro'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Repartir de zéro').last);
      await tester.pumpAndSettle();

      expect(await repository.watchThemeMode().first, 'dark');
    });
  });
}
