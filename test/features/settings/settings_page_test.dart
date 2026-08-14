import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:budgetpilot/core/providers/database_provider.dart';
import 'package:budgetpilot/data/local/cycle_repository.dart';
import 'package:budgetpilot/data/local/database.dart';
import 'package:budgetpilot/features/settings/settings_page.dart';

void main() {
  late AppDatabase db;
  late CycleRepository repository;

  setUpAll(() async {
    await initializeDateFormatting('fr_FR', null);
  });

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

  // Paramètres > Cycle observe des flux Drift (StreamProvider.autoDispose) :
  // à la fin de chaque test, la dépose automatique de l'arbre de widgets
  // planifie un Timer interne à Drift pour fermer proprement ces flux. Sans
  // ce flush explicite, ce Timer reste "en attente" au moment où le banc de
  // test vérifie ses invariants et fait échouer le test suivant.
  Future<void> flushProviderDisposal(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('le thème système est sélectionné par défaut', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    final segmented = tester.widget<SegmentedButton<ThemeMode>>(find.byType(SegmentedButton<ThemeMode>));
    expect(segmented.selected, {ThemeMode.system});

    await flushProviderDisposal(tester);
  });

  testWidgets('changer de thème persiste le choix', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sombre'));
    await tester.pumpAndSettle();

    final segmented = tester.widget<SegmentedButton<ThemeMode>>(find.byType(SegmentedButton<ThemeMode>));
    expect(segmented.selected, {ThemeMode.dark});

    await flushProviderDisposal(tester);
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

    await flushProviderDisposal(tester);
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
      await tester.tap(find.text('Version 1.3.0'));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.text('Charger les données de démonstration'), findsOneWidget);

    await flushProviderDisposal(tester);
  });

  group('Paramètres > Cycle (§16)', () {
    testWidgets('aucun cycle ouvert : propose de créer un nouveau cycle, sans préremplissage', (tester) async {
      useTallViewport(tester);
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('Cycle actuel'), findsNothing);
      expect(find.text('Créer un nouveau cycle'), findsOneWidget);

      await tester.tap(find.text('Créer un nouveau cycle'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Créer mon cycle budgétaire'), findsOneWidget);
      final balanceField = find.widgetWithText(TextFormField, 'Solde bancaire déclaré (facultatif)');
      expect(tester.widget<TextFormField>(balanceField).controller!.text, isEmpty);

      await flushProviderDisposal(tester);
    });

    testWidgets('un cycle ouvert : affiche "Cycle actuel" et permet de le terminer', (tester) async {
      useTallViewport(tester);
      await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('Cycle actuel'), findsOneWidget);
      expect(find.text('1 janvier 2026 → 31 janvier 2026'), findsOneWidget);
      expect(find.text('Créer un nouveau cycle'), findsNothing);

      await tester.tap(find.text('Terminer le cycle'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Terminer le cycle'), findsOneWidget);

      await flushProviderDisposal(tester);
    });

    testWidgets('après clôture du dernier cycle : "Créer un nouveau cycle" est préempli à partir de celui-ci',
        (tester) async {
      useTallViewport(tester);
      final cycleId = await repository.createCycle(
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 31),
        declaredBankBalanceCents: 5000,
      );
      await repository.closeCycle(cycleId);
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('Cycle actuel'), findsNothing);
      await tester.tap(find.text('Créer un nouveau cycle'));
      await tester.pumpAndSettle();

      // Nouveau cycle suggéré du 1er au 31 février 2026 (même durée, jour
      // suivant la fin du précédent) — préempli mais toujours modifiable.
      expect(find.text('1 février 2026'), findsOneWidget);
      expect(find.text('3 mars 2026'), findsOneWidget);

      await flushProviderDisposal(tester);
    });
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

      await flushProviderDisposal(tester);
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

      await flushProviderDisposal(tester);
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

      await flushProviderDisposal(tester);
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

      await flushProviderDisposal(tester);
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

      await flushProviderDisposal(tester);
    });
  });
}
