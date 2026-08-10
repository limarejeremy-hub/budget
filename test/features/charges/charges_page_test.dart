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

  testWidgets('affiche le bloc "Charges les plus importantes" avec le top 3 par montant', (tester) async {
    final cycleId = await repository.createCycle(startDate: DateTime(2026, 7, 27), endDate: DateTime(2026, 8, 26));
    await repository.createFixedExpense(
        cycleId: cycleId, name: 'Loyer', expectedAmountCents: 95000, expectedDate: DateTime(2026, 8, 1));
    await repository.createFixedExpense(
        cycleId: cycleId, name: 'Crédit auto', expectedAmountCents: 28000, expectedDate: DateTime(2026, 8, 5));
    await repository.createFixedExpense(
        cycleId: cycleId, name: 'Électricité', expectedAmountCents: 14500, expectedDate: DateTime(2026, 8, 10));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Charges les plus importantes'), findsOneWidget);
    expect(find.text('1.'), findsOneWidget);
    expect(find.text('2.'), findsOneWidget);
    expect(find.text('3.'), findsOneWidget);
    expect(find.text(formatCentsAsEuro(95000)), findsWidgets);
  });

  testWidgets('aucune charge : le bloc "Charges les plus importantes" n\'apparaît pas', (tester) async {
    await repository.createCycle(startDate: DateTime(2026, 7, 27), endDate: DateTime(2026, 8, 26));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Charges les plus importantes'), findsNothing);
    expect(find.text('Aucune charge fixe pour ce cycle'), findsOneWidget);
  });

  testWidgets('le raccourci "Les plus coûteuses" trie immédiatement par montant décroissant', (tester) async {
    final cycleId = await repository.createCycle(startDate: DateTime(2026, 7, 27), endDate: DateTime(2026, 8, 26));
    await repository.createFixedExpense(
        cycleId: cycleId, name: 'Électricité', expectedAmountCents: 14500, expectedDate: DateTime(2026, 8, 1));
    await repository.createFixedExpense(
        cycleId: cycleId, name: 'Loyer', expectedAmountCents: 95000, expectedDate: DateTime(2026, 8, 10));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Les plus coûteuses'));
    await tester.pumpAndSettle();

    // Le raccourci sélectionne le champ "Montant" en décroissant : la puce
    // "Les plus coûteuses" ET la puce "Montant" doivent toutes deux
    // apparaître sélectionnées.
    final shortcutChip = tester.widget<ChoiceChip>(
      find.ancestor(of: find.text('Les plus coûteuses'), matching: find.byType(ChoiceChip)),
    );
    final montantChip = tester.widget<ChoiceChip>(
      find.ancestor(of: find.text('Montant'), matching: find.byType(ChoiceChip)),
    );
    expect(shortcutChip.selected, isTrue);
    expect(montantChip.selected, isTrue);

    // Le premier résultat de la liste principale doit être la charge la
    // plus chère : "Loyer" (95000) avant "Électricité" (14500).
    final chargeCardTexts = find.descendant(
      of: find.byType(ListView).last,
      matching: find.byType(Text),
    );
    final firstChargeName = tester.widgetList<Text>(chargeCardTexts).map((t) => t.data).firstWhere(
          (t) => t == 'Loyer' || t == 'Électricité',
        );
    expect(firstChargeName, 'Loyer');
  });

  testWidgets('changer de champ de tri via les puces fonctionne (ex: Nom)', (tester) async {
    final cycleId = await repository.createCycle(startDate: DateTime(2026, 7, 27), endDate: DateTime(2026, 8, 26));
    await repository.createFixedExpense(
        cycleId: cycleId, name: 'Zoo abonnement', expectedAmountCents: 3000, expectedDate: DateTime(2026, 8, 1));
    await repository.createFixedExpense(
        cycleId: cycleId, name: 'Assurance', expectedAmountCents: 6000, expectedDate: DateTime(2026, 8, 5));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nom'));
    await tester.pumpAndSettle();

    expect(find.text('Assurance'), findsWidgets);
    expect(find.text('Zoo abonnement'), findsWidgets);
  });

  testWidgets('la recherche reste compatible avec le tri sélectionné', (tester) async {
    final cycleId = await repository.createCycle(startDate: DateTime(2026, 7, 27), endDate: DateTime(2026, 8, 26));
    // 4 charges : la recherche cible une charge hors du top 3 (toujours
    // visible, indépendamment de la recherche) pour vérifier proprement le
    // filtrage de la liste principale.
    await repository.createFixedExpense(
        cycleId: cycleId, name: 'Loyer', expectedAmountCents: 95000, expectedDate: DateTime(2026, 8, 1));
    await repository.createFixedExpense(
        cycleId: cycleId, name: 'Crédit auto', expectedAmountCents: 28000, expectedDate: DateTime(2026, 8, 5));
    await repository.createFixedExpense(
        cycleId: cycleId, name: 'Électricité', expectedAmountCents: 14500, expectedDate: DateTime(2026, 8, 10));
    await repository.createFixedExpense(
        cycleId: cycleId, name: 'Internet', expectedAmountCents: 3500, expectedDate: DateTime(2026, 8, 12));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Montant'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'internet');
    await tester.pumpAndSettle();

    // "Internet" n'apparaît que dans la liste principale filtrée (absente
    // du top 3). "Crédit auto" reste visible une seule fois — uniquement
    // via le bloc "Charges les plus importantes", filtré hors de la liste
    // principale par la recherche.
    expect(find.text('Internet'), findsOneWidget);
    expect(find.text('Crédit auto'), findsOneWidget);
  });
}
