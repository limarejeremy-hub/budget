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
}
