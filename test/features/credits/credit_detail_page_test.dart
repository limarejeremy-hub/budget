import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:budgetpilot/core/formatting/currency_formatter.dart';
import 'package:budgetpilot/core/providers/database_provider.dart';
import 'package:budgetpilot/data/local/cycle_repository.dart';
import 'package:budgetpilot/data/local/database.dart';
import 'package:budgetpilot/domain/entities/credit_entity.dart';
import 'package:budgetpilot/features/credits/credit_detail_page.dart';

void main() {
  late AppDatabase db;
  late CycleRepository repository;

  Widget wrap(CreditEntity credit) {
    return ProviderScope(
      overrides: [appDatabaseProvider.overrideWith((ref) => db)],
      child: MaterialApp(home: CreditDetailPage(credit: credit)),
    );
  }

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

  CreditEntity buildCredit({String? organisme}) {
    final now = DateTime(2026, 1, 1);
    return CreditEntity(
      id: 1,
      name: 'Voiture',
      initialAmountCents: 1500000,
      remainingCapitalCents: 900000,
      monthlyPaymentCents: 25000,
      expectedEndDate: DateTime(2029, 1, 1),
      remainingInstallments: 36,
      organisme: organisme,
      createdAt: now,
      updatedAt: now,
    );
  }

  testWidgets("affiche l'organisme quand renseigné", (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(wrap(buildCredit(organisme: 'Crédit Agricole')));
    await tester.pumpAndSettle();

    expect(find.text('Banque'), findsOneWidget);
    expect(find.text('Crédit Agricole'), findsOneWidget);
  });

  testWidgets("n'affiche pas la ligne Banque quand l'organisme est absent", (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(wrap(buildCredit()));
    await tester.pumpAndSettle();

    expect(find.text('Banque'), findsNothing);
  });

  testWidgets("affiche la section Historique avec dates d'ajout et de mise à jour", (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(wrap(buildCredit()));
    await tester.pumpAndSettle();

    expect(find.text('Historique'), findsOneWidget);
    expect(find.text('Ajouté le'), findsOneWidget);
    expect(find.text('Dernière mise à jour'), findsOneWidget);
  });

  testWidgets('affiche les étoiles de priorité pour un crédit actif', (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(wrap(buildCredit()));
    await tester.pumpAndSettle();

    // 36 mensualités restantes => "Long terme" (1 étoile).
    expect(find.text('Long terme'), findsOneWidget);
  });

  testWidgets('le simulateur de versement exceptionnel affiche le nouveau format', (tester) async {
    useTallViewport(tester);
    // Voiture : capital restant 900000, mensualité 25000, 36 mensualités,
    // fin prévue janvier 2029. Versement de 1000 € (100000 cents) ->
    // capital restant 800000, 32 mensualités théoriques -> 4 mois gagnés
    // -> nouvelle fin septembre 2028.
    await tester.pumpWidget(wrap(buildCredit()));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Montant du versement'), '1000');
    await tester.tap(find.text('Simuler'));
    await tester.pump();

    expect(find.text('Après un remboursement exceptionnel de :'), findsOneWidget);
    expect(find.text('Capital restant'), findsOneWidget);
    expect(find.text('Gain estimé'), findsOneWidget);
    expect(find.text('4 mensualités'), findsOneWidget);
    expect(find.text('Nouvelle fin'), findsOneWidget);
    expect(find.text('septembre 2028'), findsOneWidget);
    expect(find.text('Mensualité toujours'), findsOneWidget);
    expect(find.text('Tu économiserais environ'), findsOneWidget);
    expect(find.text('4 mois'), findsOneWidget);
    expect(find.text('Excellent choix.'), findsOneWidget);
    expect(
      find.text('Estimation simplifiée — hors intérêts, hors assurance, hors pénalités.'),
      findsWidgets,
    );
  });

  testWidgets('"Marquer comme terminé" bascule bien le statut actif du crédit', (tester) async {
    useTallViewport(tester);
    final id = await repository.createCredit(
      name: 'Voiture',
      initialAmountCents: 1500000,
      remainingCapitalCents: 900000,
      monthlyPaymentCents: 25000,
      expectedEndDate: DateTime(2029, 1, 1),
      remainingInstallments: 36,
    );
    final row = (await repository.loadCredits()).single;
    final credit = CreditEntity(
      id: id,
      name: row.name,
      initialAmountCents: row.initialAmountCents,
      remainingCapitalCents: row.remainingCapitalCents,
      monthlyPaymentCents: row.monthlyPaymentCents,
      expectedEndDate: row.expectedEndDate,
      remainingInstallments: row.remainingInstallments,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );

    await tester.pumpWidget(wrap(credit));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Marquer comme terminé'));
    await tester.pumpAndSettle();

    final updated = (await repository.loadCredits()).single;
    expect(updated.isActive, isFalse);
  });

  group('simulateur "Augmenter ma mensualité" (V1.2, §2)', () {
    Future<CreditEntity> seedCreditWithCycle({
      int incomeCents = 300000,
      int monthlyPaymentCents = 27500,
      double? annualRatePercent,
    }) async {
      await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
      final cycleData = await repository.loadCurrentCycleData();
      await repository.createIncome(
        cycleId: cycleData!.cycle.id,
        name: 'Salaire',
        expectedAmountCents: incomeCents,
        expectedDate: DateTime(2026, 1, 1),
      );
      final id = await repository.createCredit(
        name: 'Prêt personnel',
        initialAmountCents: 2000000,
        remainingCapitalCents: 1000000,
        monthlyPaymentCents: monthlyPaymentCents,
        annualRatePercent: annualRatePercent,
        expectedEndDate: DateTime(2029, 6, 1),
        remainingInstallments: 40,
      );
      final row = (await repository.loadCredits()).single;
      return CreditEntity(
        id: id,
        name: row.name,
        initialAmountCents: row.initialAmountCents,
        remainingCapitalCents: row.remainingCapitalCents,
        monthlyPaymentCents: row.monthlyPaymentCents,
        annualRatePercent: row.annualRatePercent,
        expectedEndDate: row.expectedEndDate,
        remainingInstallments: row.remainingInstallments,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      );
    }

    testWidgets('affiche tous les indicateurs requis après simulation', (tester) async {
      useTallViewport(tester);
      final credit = await seedCreditWithCycle(annualRatePercent: 3.0);

      await tester.pumpWidget(wrap(credit));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Nouvelle mensualité testée'), '400');
      await tester.tap(find.text('Simuler la mensualité'));
      await tester.pump();

      expect(find.text('Mensualité actuelle'), findsOneWidget);
      expect(find.text('${formatCentsAsEuro(27500)}/mois'), findsOneWidget);
      expect(find.text('Mensualité simulée'), findsOneWidget);
      expect(find.text('${formatCentsAsEuro(40000)}/mois'), findsOneWidget);
      expect(find.text('Capital restant'), findsOneWidget);
      expect(find.text('Nouvelle durée estimée'), findsOneWidget);
      expect(find.text('25 mois'), findsOneWidget);
      expect(find.text('Nouvelle date de fin'), findsOneWidget);
      expect(find.text('Mois gagnés'), findsOneWidget);
      expect(find.text('Intérêts économisés (estimation)'), findsOneWidget);
      expect(find.text('Taux d\'endettement actuel'), findsOneWidget);
      expect(find.text('Taux d\'endettement simulé'), findsOneWidget);
      expect(find.text('Reste à vivre actuel'), findsOneWidget);
      expect(find.text('Reste à vivre après augmentation'), findsOneWidget);
      expect(find.text('Appliquer cette nouvelle mensualité'), findsOneWidget);
    });

    testWidgets('sans taux renseigné, aucun intérêt n\'est inventé', (tester) async {
      useTallViewport(tester);
      final credit = await seedCreditWithCycle(annualRatePercent: null);

      await tester.pumpWidget(wrap(credit));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Nouvelle mensualité testée'), '400');
      await tester.tap(find.text('Simuler la mensualité'));
      await tester.pump();

      expect(find.text('Intérêts économisés (estimation)'), findsNothing);
      expect(find.text('Taux non renseigné : estimation simplifiée, sans intérêts calculés.'), findsOneWidget);
    });

    testWidgets('affiche un avertissement quand la mensualité simulée dégrade fortement le reste à vivre',
        (tester) async {
      useTallViewport(tester);
      // Revenus 3000 €, mensualité actuelle 275 €. Simulation à 2900 €/mois :
      // le reste à vivre structurel s'effondre presque entièrement.
      final credit = await seedCreditWithCycle(incomeCents: 300000, monthlyPaymentCents: 27500);

      await tester.pumpWidget(wrap(credit));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Nouvelle mensualité testée'), '2900');
      await tester.tap(find.text('Simuler la mensualité'));
      await tester.pump();

      expect(
        find.text(
          'Cette mensualité dégraderait fortement ton reste à vivre ou ton taux d\'endettement — '
          'à valider avec prudence.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('appliquer la nouvelle mensualité met à jour le crédit et synchronise la charge liée', (tester) async {
      useTallViewport(tester);
      final credit = await seedCreditWithCycle();

      await tester.pumpWidget(wrap(credit));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Nouvelle mensualité testée'), '400');
      await tester.tap(find.text('Simuler la mensualité'));
      await tester.pump();

      await tester.tap(find.text('Appliquer cette nouvelle mensualité'));
      await tester.pumpAndSettle();

      // Confirmation
      expect(find.text('Appliquer cette nouvelle mensualité ?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Appliquer'));
      await tester.pumpAndSettle();

      final updatedCredit = (await repository.loadCredits()).single;
      expect(updatedCredit.monthlyPaymentCents, 40000);

      final cycleData = await repository.loadCurrentCycleData();
      final linkedCharge = cycleData!.fixedExpenses.singleWhere((e) => e.linkedCreditId == credit.id);
      expect(linkedCharge.expectedAmountCents, 40000);
    });

    testWidgets('annuler la confirmation ne modifie rien', (tester) async {
      useTallViewport(tester);
      final credit = await seedCreditWithCycle();

      await tester.pumpWidget(wrap(credit));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Nouvelle mensualité testée'), '400');
      await tester.tap(find.text('Simuler la mensualité'));
      await tester.pump();

      await tester.tap(find.text('Appliquer cette nouvelle mensualité'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Annuler'));
      await tester.pumpAndSettle();

      final unchangedCredit = (await repository.loadCredits()).single;
      expect(unchangedCredit.monthlyPaymentCents, 27500);
    });
  });
}
