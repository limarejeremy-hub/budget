import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:budgetpilot/core/formatting/currency_formatter.dart';
import 'package:budgetpilot/core/providers/database_provider.dart';
import 'package:budgetpilot/data/local/cycle_repository.dart';
import 'package:budgetpilot/data/local/database.dart';
import 'package:budgetpilot/features/charges/charges_page.dart';

void main() {
  late AppDatabase db;
  late CycleRepository repository;

  setUpAll(() async {
    await initializeDateFormatting('fr_FR', null);
  });

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = CycleRepository(db);
  });

  tearDown(() => db.close());

  Widget wrap() {
    return ProviderScope(
      overrides: [appDatabaseProvider.overrideWith((ref) => db)],
      child: const MaterialApp(home: ChargesPage()),
    );
  }

  Future<int> seedCategory(String name) async {
    return db.into(db.categories).insert(
          CategoriesCompanion.insert(name: name, type: 'fixed_expense'),
        );
  }

  testWidgets('le menu déroulant liste uniquement les catégories réellement utilisées', (tester) async {
    final cycleId = await repository.createCycle(startDate: DateTime(2026, 7, 27), endDate: DateTime(2026, 8, 26));
    final maisonId = await seedCategory('Maison');
    await seedCategory('Voiture'); // catégorie existante mais jamais utilisée par une charge
    await repository.createFixedExpense(
      cycleId: cycleId,
      name: 'Loyer',
      expectedAmountCents: 95000,
      expectedDate: DateTime(2026, 8, 1),
      categoryId: maisonId,
    );

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Toutes les catégories'), findsOneWidget);
    await tester.tap(find.text('Toutes les catégories'));
    await tester.pumpAndSettle();

    expect(find.text('Maison').last, findsOneWidget);
    expect(find.text('Voiture'), findsNothing);
  });

  testWidgets('sélectionner une catégorie filtre la liste et affiche son coût total mensuel', (tester) async {
    final cycleId = await repository.createCycle(startDate: DateTime(2026, 7, 27), endDate: DateTime(2026, 8, 26));
    final maisonId = await seedCategory('Maison');
    final voitureId = await seedCategory('Voiture');
    await repository.createFixedExpense(
      cycleId: cycleId,
      name: 'Crédit Maison',
      expectedAmountCents: 45300,
      expectedDate: DateTime(2026, 8, 1),
      categoryId: maisonId,
    );
    await repository.createFixedExpense(
      cycleId: cycleId,
      name: 'Fenêtres',
      expectedAmountCents: 36900,
      expectedDate: DateTime(2026, 8, 3),
      categoryId: maisonId,
    );
    await repository.createFixedExpense(
      cycleId: cycleId,
      name: 'Assurance auto',
      expectedAmountCents: 48600,
      expectedDate: DateTime(2026, 8, 5),
      categoryId: voitureId,
    );

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Toutes les catégories'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Maison').last);
    await tester.pumpAndSettle();

    expect(find.text('Crédit Maison'), findsOneWidget);
    expect(find.text('Fenêtres'), findsOneWidget);
    expect(find.text('Assurance auto'), findsNothing);
    expect(find.text('${formatCentsAsEuro(45300 + 36900)}/mois'), findsOneWidget);
  });

  testWidgets('le classement affiche les catégories du plus coûteux au moins coûteux', (tester) async {
    final cycleId = await repository.createCycle(startDate: DateTime(2026, 7, 27), endDate: DateTime(2026, 8, 26));
    final maisonId = await seedCategory('Maison');
    final voitureId = await seedCategory('Voiture');
    final telecomId = await seedCategory('Télécoms');
    await repository.createFixedExpense(
      cycleId: cycleId,
      name: 'Loyer',
      expectedAmountCents: 90000,
      expectedDate: DateTime(2026, 8, 1),
      categoryId: maisonId,
    );
    await repository.createFixedExpense(
      cycleId: cycleId,
      name: 'Assurance auto',
      expectedAmountCents: 45000,
      expectedDate: DateTime(2026, 8, 2),
      categoryId: voitureId,
    );
    await repository.createFixedExpense(
      cycleId: cycleId,
      name: 'Forfait mobile',
      expectedAmountCents: 2500,
      expectedDate: DateTime(2026, 8, 3),
      categoryId: telecomId,
    );

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Classement'));
    await tester.pumpAndSettle();

    final tiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
    expect(tiles, hasLength(3));
    final titles = tiles.map((t) => (t.title as Text).data).toList();
    expect(titles, ['Maison', 'Voiture', 'Télécoms']);
  });

  testWidgets('cliquer sur une catégorie du classement filtre directement la liste sur cette catégorie',
      (tester) async {
    final cycleId = await repository.createCycle(startDate: DateTime(2026, 7, 27), endDate: DateTime(2026, 8, 26));
    final maisonId = await seedCategory('Maison');
    final voitureId = await seedCategory('Voiture');
    await repository.createFixedExpense(
      cycleId: cycleId,
      name: 'Loyer',
      expectedAmountCents: 90000,
      expectedDate: DateTime(2026, 8, 1),
      categoryId: maisonId,
    );
    await repository.createFixedExpense(
      cycleId: cycleId,
      name: 'Assurance auto',
      expectedAmountCents: 45000,
      expectedDate: DateTime(2026, 8, 2),
      categoryId: voitureId,
    );

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Classement'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Maison'));
    await tester.pumpAndSettle();

    expect(find.text('Loyer'), findsOneWidget);
    expect(find.text('Assurance auto'), findsNothing);
    expect(find.text('${formatCentsAsEuro(90000)}/mois'), findsOneWidget);
  });

  testWidgets('la recherche continue de fonctionner combinée à une catégorie sélectionnée', (tester) async {
    final cycleId = await repository.createCycle(startDate: DateTime(2026, 7, 27), endDate: DateTime(2026, 8, 26));
    final maisonId = await seedCategory('Maison');
    await repository.createFixedExpense(
      cycleId: cycleId,
      name: 'Assurance Maison',
      expectedAmountCents: 9500,
      expectedDate: DateTime(2026, 8, 1),
      categoryId: maisonId,
    );
    await repository.createFixedExpense(
      cycleId: cycleId,
      name: 'Crédit Maison',
      expectedAmountCents: 45300,
      expectedDate: DateTime(2026, 8, 2),
      categoryId: maisonId,
    );

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Toutes les catégories'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Maison').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'assurance');
    await tester.pumpAndSettle();

    expect(find.text('Assurance Maison'), findsOneWidget);
    expect(find.text('Crédit Maison'), findsNothing);
  });

  testWidgets('tri par défaut : montant décroissant dans une catégorie', (tester) async {
    final cycleId = await repository.createCycle(startDate: DateTime(2026, 7, 27), endDate: DateTime(2026, 8, 26));
    final maisonId = await seedCategory('Maison');
    await repository.createFixedExpense(
      cycleId: cycleId,
      name: 'Fenêtres',
      expectedAmountCents: 36900,
      expectedDate: DateTime(2026, 8, 1),
      categoryId: maisonId,
    );
    await repository.createFixedExpense(
      cycleId: cycleId,
      name: 'Crédit Maison',
      expectedAmountCents: 45300,
      expectedDate: DateTime(2026, 8, 2),
      categoryId: maisonId,
    );

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Toutes les catégories'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Maison').last);
    await tester.pumpAndSettle();

    final names = tester
        .widgetList<Text>(find.descendant(of: find.byType(ListView), matching: find.byType(Text)))
        .map((t) => t.data)
        .where((t) => t == 'Fenêtres' || t == 'Crédit Maison')
        .toList();
    expect(names.first, 'Crédit Maison'); // le plus cher en premier
  });

  testWidgets('absence de double comptage : une charge liée à un crédit est comptée une seule fois dans le total',
      (tester) async {
    await repository.createCycle(startDate: DateTime(2026, 7, 27), endDate: DateTime(2026, 8, 26));
    final creditCategoryId = await seedCategory('Crédits');
    // createCredit génère automatiquement la charge fixe liée dans le cycle
    // en cours — sa mensualité ne doit apparaître qu'une seule fois dans le
    // total de la catégorie.
    await repository.createCredit(
      name: 'Voiture',
      initialAmountCents: 1500000,
      remainingCapitalCents: 900000,
      monthlyPaymentCents: 28000,
      expectedEndDate: DateTime(2029, 1, 1),
      remainingInstallments: 36,
    );
    final data = await repository.loadCurrentCycleData();
    final linkedCharge = data!.fixedExpenses.single;
    await db.update(db.fixedExpenses).replace(linkedCharge.copyWith(categoryId: Value(creditCategoryId)));
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Toutes les catégories'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crédits').last);
    await tester.pumpAndSettle();

    expect(find.text('${formatCentsAsEuro(28000)}/mois'), findsOneWidget);
    expect(find.text('${formatCentsAsEuro(56000)}/mois'), findsNothing);
  });
}
