import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:budgetpilot/core/formatting/currency_formatter.dart';
import 'package:budgetpilot/core/providers/database_provider.dart';
import 'package:budgetpilot/data/local/cycle_repository.dart';
import 'package:budgetpilot/data/local/database.dart';
import 'package:budgetpilot/features/credits/credits_page.dart';

void main() {
  late AppDatabase db;
  late CycleRepository repository;

  Widget wrap() {
    return ProviderScope(
      overrides: [appDatabaseProvider.overrideWith((ref) => db)],
      child: const MaterialApp(home: CreditsPage()),
    );
  }

  // La page Crédits (résumé + indicateurs + tri + simulateur + cartes) est
  // plus haute que le viewport de test par défaut — un viewport haut évite
  // que le contenu bas de page (cartes, résultats du simulateur) ne soit
  // jamais construit (ListView reste "lazy" même à contenu statique).
  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  setUpAll(() async {
    await initializeDateFormatting('fr_FR', null);
  });

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = CycleRepository(db);
  });

  tearDown(() => db.close());

  testWidgets('affiche les étoiles de priorité et le libellé pour un crédit actif', (tester) async {
    useTallViewport(tester);
    await repository.createCredit(
      name: 'Samsung Fold',
      initialAmountCents: 80000,
      remainingCapitalCents: 32000,
      monthlyPaymentCents: 8000,
      expectedEndDate: DateTime(2027, 1, 1),
      remainingInstallments: 4, // < 6 => 5 étoiles, priorité maximale
    );

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Priorité maximale'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(5));
  });

  testWidgets("n'affiche pas d'étoiles pour un crédit terminé", (tester) async {
    useTallViewport(tester);
    await repository.createCredit(
      name: 'Ancien crédit',
      initialAmountCents: 80000,
      remainingCapitalCents: 0,
      monthlyPaymentCents: 0,
      expectedEndDate: DateTime(2025, 1, 1),
      remainingInstallments: 0,
    );
    await repository.setCreditActive(1, false);

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Terminé'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsNothing);
  });

  testWidgets('le simulateur de remboursement compare les crédits actifs', (tester) async {
    useTallViewport(tester);
    await repository.createCredit(
      name: 'Samsung Fold',
      initialAmountCents: 80000,
      remainingCapitalCents: 32000,
      monthlyPaymentCents: 8000,
      expectedEndDate: DateTime(2027, 1, 1),
      remainingInstallments: 4,
    );
    await repository.createCredit(
      name: 'Voiture',
      initialAmountCents: 1500000,
      remainingCapitalCents: 900000,
      monthlyPaymentCents: 25000,
      expectedEndDate: DateTime(2029, 1, 1),
      remainingInstallments: 36,
    );

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Simuler un remboursement'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(formatCentsAsEuro(100000)).first);
    await tester.pumpAndSettle();

    expect(find.textContaining('Terminer Samsung Fold'), findsOneWidget);
    expect(find.textContaining('récupération de'), findsOneWidget);
  });

  testWidgets('affiche les indicateurs sous forme de cartes premium', (tester) async {
    useTallViewport(tester);
    await repository.createCredit(
      name: 'Test',
      initialAmountCents: 80000,
      remainingCapitalCents: 80000,
      monthlyPaymentCents: 20000,
      expectedEndDate: DateTime(2027, 1, 1),
      remainingInstallments: 4,
    );
    await repository.createCredit(
      name: 'Maison',
      initialAmountCents: 20000000,
      remainingCapitalCents: 19800000,
      monthlyPaymentCents: 87500,
      expectedEndDate: DateTime(2045, 1, 1),
      remainingInstallments: 200,
    );
    await repository.createCredit(
      name: 'Voiture',
      initialAmountCents: 1500000,
      remainingCapitalCents: 900000,
      monthlyPaymentCents: 25000,
      annualRatePercent: 5.4,
      expectedEndDate: DateTime(2029, 1, 1),
      remainingInstallments: 36,
    );

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text("🏁 Crédit le plus proche d'être terminé"), findsOneWidget);
    expect(find.text('4 mensualités restantes'), findsOneWidget);
    expect(find.text('💰 Plus grosse mensualité'), findsOneWidget);
    expect(find.text('📈 Crédit le plus coûteux'), findsOneWidget);
    expect(find.text('5.4 %'), findsOneWidget);
    expect(find.text('🏦 Plus gros capital restant'), findsOneWidget);
    expect(find.text(formatCentsAsEuro(19800000)), findsWidgets);
  });

  testWidgets('affiche la banque (organisme) et le score visuel sur la carte du crédit', (tester) async {
    useTallViewport(tester);
    await repository.createCredit(
      name: 'Voiture',
      initialAmountCents: 1500000,
      remainingCapitalCents: 900000,
      monthlyPaymentCents: 25000,
      expectedEndDate: DateTime(2029, 1, 1),
      remainingInstallments: 4, // < 12 => veryClose
      organisme: 'Crédit Agricole',
    );

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Crédit Agricole'), findsOneWidget);
    expect(find.textContaining('Très proche de la fin'), findsOneWidget);
  });

  testWidgets('les dates affichées sur la carte incluent toujours l\'année', (tester) async {
    useTallViewport(tester);
    await repository.createCredit(
      name: 'Voiture',
      initialAmountCents: 1500000,
      remainingCapitalCents: 900000,
      monthlyPaymentCents: 25000,
      expectedEndDate: DateTime(2029, 1, 1),
      remainingInstallments: 36,
    );

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.textContaining('2029'), findsWidgets);
  });
}
