import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

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

  testWidgets('le simulateur de versement exceptionnel fonctionne toujours', (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(wrap(buildCredit()));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Montant du versement'), '1000');
    await tester.tap(find.text('Simuler'));
    await tester.pump();

    expect(find.text('Capital restant après versement'), findsOneWidget);
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
}
