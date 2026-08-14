import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:budgetpilot/core/providers/database_provider.dart';
import 'package:budgetpilot/core/widgets/euro_amount_field.dart';
import 'package:budgetpilot/data/local/cycle_repository.dart';
import 'package:budgetpilot/data/local/database.dart';
import 'package:budgetpilot/features/cycle/cycle_creation_page.dart';

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
      child: const MaterialApp(home: CycleCreationPage()),
    );
  }

  testWidgets('un solde bancaire positif crée bien le cycle', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Solde bancaire déclaré (facultatif)'), '250');
    await tester.tap(find.widgetWithText(FilledButton, 'Créer le cycle'));
    await tester.pumpAndSettle();

    final data = await repository.loadCurrentCycleData();
    expect(data!.cycle.declaredBankBalanceCents, 25000);
  });

  testWidgets('un solde bancaire négatif ne bloque jamais la création du cycle', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Solde bancaire déclaré (facultatif)'), '-180');
    await tester.tap(find.widgetWithText(FilledButton, 'Créer le cycle'));
    await tester.pumpAndSettle();

    final data = await repository.loadCurrentCycleData();
    expect(data, isNotNull);
    expect(data!.cycle.declaredBankBalanceCents, -18000);
  });

  testWidgets('un solde bancaire négatif avec virgule française est stocké correctement en centimes', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Solde bancaire déclaré (facultatif)'), '-1250,50');
    await tester.tap(find.widgetWithText(FilledButton, 'Créer le cycle'));
    await tester.pumpAndSettle();

    final data = await repository.loadCurrentCycleData();
    expect(data!.cycle.declaredBankBalanceCents, -125050);
  });

  testWidgets('un solde bancaire à zéro est accepté', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Solde bancaire déclaré (facultatif)'), '0');
    await tester.tap(find.widgetWithText(FilledButton, 'Créer le cycle'));
    await tester.pumpAndSettle();

    final data = await repository.loadCurrentCycleData();
    expect(data!.cycle.declaredBankBalanceCents, 0);
  });

  testWidgets('une valeur invalide affiche une erreur et ne crée pas le cycle', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Solde bancaire déclaré (facultatif)'), '1.2.3');
    await tester.tap(find.widgetWithText(FilledButton, 'Créer le cycle'));
    await tester.pumpAndSettle();

    expect(find.text('Montant invalide'), findsOneWidget);
    expect(await repository.loadCurrentCycleData(), isNull);
  });

  testWidgets('le champ solde bancaire accepte les montants négatifs (allowNegative)', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    final field = tester.widget<EuroAmountField>(find.byType(EuroAmountField));
    expect(field.allowNegative, isTrue);
  });

  group('finalisation du moteur de cycle (§4, §5, §6, §12, §17)', () {
    Widget wrapWithPrefill({
      DateTime? initialStartDate,
      DateTime? initialEndDate,
      int? suggestedBalanceCents,
      int? previousCycleId,
    }) {
      return ProviderScope(
        overrides: [appDatabaseProvider.overrideWith((ref) => db)],
        child: MaterialApp(
          home: CycleCreationPage(
            initialStartDate: initialStartDate,
            initialEndDate: initialEndDate,
            suggestedBalanceCents: suggestedBalanceCents,
            previousCycleId: previousCycleId,
          ),
        ),
      );
    }

    testWidgets('dates et solde suggéré préremplis restent modifiables avant validation', (tester) async {
      await tester.pumpWidget(wrapWithPrefill(
        initialStartDate: DateTime(2026, 2, 1),
        initialEndDate: DateTime(2026, 3, 3),
        suggestedBalanceCents: 12345,
      ));
      await tester.pumpAndSettle();

      expect(find.text('1 février 2026'), findsOneWidget);
      expect(find.text('3 mars 2026'), findsOneWidget);
      final balanceField = find.widgetWithText(TextFormField, 'Solde bancaire déclaré (facultatif)');
      expect(tester.widget<TextFormField>(balanceField).controller!.text, '123.45');

      // La suggestion reste éditable — jamais validée automatiquement (§12).
      await tester.enterText(balanceField, '999');
      await tester.tap(find.widgetWithText(FilledButton, 'Créer le cycle'));
      await tester.pumpAndSettle();

      final data = await repository.loadCurrentCycleData();
      expect(data!.cycle.declaredBankBalanceCents, 99900);
    });

    testWidgets('previousCycleId recopie les revenus et charges fixes récurrents actifs', (tester) async {
      final previousId = await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
      await repository.createIncome(
        cycleId: previousId,
        name: 'Salaire',
        expectedAmountCents: 300000,
        expectedDate: DateTime(2026, 1, 1),
        isRecurring: true,
      );
      await repository.createIncome(
        cycleId: previousId,
        name: 'Prime unique',
        expectedAmountCents: 50000,
        expectedDate: DateTime(2026, 1, 1),
        isRecurring: false,
      );
      await repository.createFixedExpense(
        cycleId: previousId,
        name: 'Loyer',
        expectedAmountCents: 90000,
        expectedDate: DateTime(2026, 1, 5),
        isRecurring: true,
      );
      await repository.closeCycle(previousId);

      await tester.pumpWidget(wrapWithPrefill(
        initialStartDate: DateTime(2026, 2, 1),
        initialEndDate: DateTime(2026, 3, 3),
        previousCycleId: previousId,
      ));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Vos revenus, charges fixes et épargnes récurrents actifs sont repris '
          'automatiquement — les dépenses variables repartent toujours à 0 €.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Créer le cycle'));
      await tester.pumpAndSettle();

      final data = await repository.loadCurrentCycleData();
      expect(data!.incomes.map((i) => i.name), ['Salaire']);
      expect(data.fixedExpenses.map((e) => e.name), ['Loyer']);
    });

    testWidgets('un second cycle déjà ouvert affiche l\'erreur au lieu de planter', (tester) async {
      await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));

      await tester.pumpWidget(wrapWithPrefill(
        initialStartDate: DateTime(2026, 2, 1),
        initialEndDate: DateTime(2026, 3, 3),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Créer le cycle'));
      await tester.pumpAndSettle();

      expect(find.text('Un cycle est déjà ouvert. Terminez-le avant d\'en créer un nouveau.'), findsOneWidget);
      final cycles = await repository.watchAllCycles().first;
      expect(cycles, hasLength(1));

      // Laisse le SnackBar se fermer avant la fin du test — sinon son
      // minuteur d'auto-fermeture reste actif et bloque l'arrêt du banc de
      // test (pumpAndSettle ne fait pas avancer les minuteurs en attente).
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
