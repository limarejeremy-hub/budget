import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:budgetpilot/core/constants/app_constants.dart';
import 'package:budgetpilot/core/formatting/currency_formatter.dart';
import 'package:budgetpilot/core/providers/database_provider.dart';
import 'package:budgetpilot/data/local/cycle_repository.dart';
import 'package:budgetpilot/data/local/database.dart';
import 'package:budgetpilot/features/cycle/cycle_closure_page.dart';
import 'package:budgetpilot/features/cycle/cycle_creation_page.dart';

/// Écran de clôture de cycle (finalisation du moteur de cycle, §2/§21) :
/// résumé complet, avertissement charges non confirmées, crédits impactés,
/// puis bascule vers la création du cycle suivant préremplie.
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

  Widget wrap(Widget home) {
    return ProviderScope(
      overrides: [appDatabaseProvider.overrideWith((ref) => db)],
      child: MaterialApp(
        home: Builder(builder: (context) {
          return Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => home)),
                child: const Text('Ouvrir'),
              ),
            ),
          );
        }),
      ),
    );
  }

  Future<int> seedFullCycle() async {
    final cycleId = await repository.createCycle(
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 1, 31),
      declaredBankBalanceCents: 10000,
    );
    await repository.createIncome(
      cycleId: cycleId,
      name: 'Salaire',
      expectedAmountCents: 300000,
      expectedDate: DateTime(2026, 1, 1),
      isRecurring: true,
    );
    // La création d'un crédit génère automatiquement sa charge liée dans le
    // cycle courant (synchronisation crédit↔charge déjà existante) — pas
    // besoin de créer manuellement cette charge.
    await repository.createCredit(
      name: 'Prêt auto',
      initialAmountCents: 1000000,
      remainingCapitalCents: 500000,
      monthlyPaymentCents: 25000,
      expectedEndDate: DateTime(2028, 1, 1),
      remainingInstallments: 20,
    );
    await repository.createFixedExpense(
      cycleId: cycleId,
      name: 'Loyer',
      expectedAmountCents: 90000,
      expectedDate: DateTime(2026, 1, 5),
      isRecurring: true,
    );
    await repository.createVariableExpense(cycleId: cycleId, amountCents: 4200, date: DateTime(2026, 1, 10));
    await repository.createSaving(
      cycleId: cycleId,
      name: 'Livret',
      expectedAmountCents: 20000,
      expectedDate: DateTime(2026, 1, 1),
      isRecurring: true,
    );
    return cycleId;
  }

  testWidgets('affiche le résumé complet, l\'avertissement et les crédits impactés', (tester) async {
    // Viewport agrandi : le résumé complet dépasse largement les 600 px de
    // hauteur par défaut du banc de test, ce qui laisserait les boutons du
    // bas hors-écran (donc invisibles pour les finders par défaut).
    await tester.binding.setSurfaceSize(const Size(800, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await seedFullCycle();

    await tester.pumpWidget(wrap(const CycleClosurePage()));
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    expect(find.text('Terminer le cycle'), findsWidgets);
    expect(find.text('Revenus'), findsOneWidget);
    expect(find.text(formatCentsAsEuro(300000)), findsOneWidget);
    expect(find.text('Charges fixes'), findsOneWidget);
    expect(find.text(formatCentsAsEuro(115000)), findsOneWidget);
    expect(find.text('Dépenses variables'), findsOneWidget);
    expect(find.text('Épargne'), findsOneWidget);
    expect(find.text('Argent libre final'), findsOneWidget);

    // 2 charges fixes créées, toutes deux non confirmées par défaut.
    expect(find.textContaining('2 prélèvements encore non confirmés'), findsOneWidget);

    expect(find.text('Crédits impactés pendant ce cycle'), findsOneWidget);
    expect(find.text('Prêt auto'), findsOneWidget);

    expect(find.widgetWithText(OutlinedButton, 'Annuler'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Clôturer le cycle'), findsOneWidget);
  });

  testWidgets('Annuler ferme l\'écran sans clôturer le cycle', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final cycleId = await seedFullCycle();

    await tester.pumpWidget(wrap(const CycleClosurePage()));
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Annuler'));
    await tester.pumpAndSettle();

    expect(find.text('Ouvrir'), findsOneWidget);
    final cycle = await (db.select(db.budgetCycles)..where((c) => c.id.equals(cycleId))).getSingle();
    expect(cycle.status, CycleStatus.ouvert);
  });

  testWidgets('Clôturer le cycle ferme le cycle courant et ouvre la création du cycle suivant préremplie',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final cycleId = await seedFullCycle();

    await tester.pumpWidget(wrap(const CycleClosurePage()));
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Clôturer le cycle'));
    await tester.pumpAndSettle();

    final closed = await (db.select(db.budgetCycles)..where((c) => c.id.equals(cycleId))).getSingle();
    expect(closed.status, CycleStatus.ferme);
    expect(closed.closedAt, isNotNull);

    expect(find.byType(CycleCreationPage), findsOneWidget);
    expect(
      find.text(
        'Vos revenus, charges fixes et épargnes récurrents actifs sont repris '
        'automatiquement — les dépenses variables repartent toujours à 0 €.',
      ),
      findsOneWidget,
    );
    // Solde suggéré = argent libre final, prérempli mais éditable (§12).
    final balanceField = find.widgetWithText(TextFormField, 'Solde bancaire déclaré (facultatif)');
    expect(balanceField, findsOneWidget);
    expect(tester.widget<TextFormField>(balanceField).controller!.text, isNotEmpty);
  });

  testWidgets('aucun cycle en cours : message d\'état vide', (tester) async {
    await tester.pumpWidget(wrap(const CycleClosurePage()));
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    expect(find.text('Aucun cycle en cours à clôturer.'), findsOneWidget);
  });
}
