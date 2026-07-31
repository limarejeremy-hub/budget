import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:budgetpilot/core/constants/app_constants.dart';
import 'package:budgetpilot/core/providers/dashboard_providers.dart';
import 'package:budgetpilot/core/providers/database_provider.dart';
import 'package:budgetpilot/data/local/database.dart';
import 'package:budgetpilot/domain/entities/fixed_expense_entity.dart';
import 'package:budgetpilot/domain/models/dashboard_view_data.dart';
import 'package:budgetpilot/features/dashboard/dashboard_page.dart';

DashboardViewData _sampleData({List<FixedExpenseEntity> upcomingCharges = const []}) {
  return DashboardViewData(
    cycleId: 1,
    cycleStart: DateTime(2026, 7, 27),
    cycleEnd: DateTime(2026, 8, 26),
    totalIncomeCents: 515000,
    totalFixedExpensesCents: 245000,
    totalVariableExpensesCents: 67700,
    totalSavingsCents: 80000,
    realRemainingCents: 122300,
    remainingRatio: 0.24,
    unconfirmedChargesCount: upcomingCharges.length,
    unconfirmedChargesTotalCents: 61200,
    upcomingCharges: upcomingCharges,
    declaredBankBalanceCents: 264000,
  );
}

void main() {
  late AppDatabase db;

  setUpAll(() async {
    await initializeDateFormatting('fr_FR', null);
  });

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Widget wrap(DashboardViewData data) {
    return ProviderScope(
      overrides: [
        dashboardProvider.overrideWith((ref) => Stream.value(data)),
        appDatabaseProvider.overrideWith((ref) => db),
      ],
      child: const MaterialApp(home: DashboardPage()),
    );
  }

  testWidgets('la carte Argent Libre ouvre le détail du cycle', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap(_sampleData()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ARGENT LIBRE'));
    await tester.pumpAndSettle();

    expect(find.text('Détail du cycle'), findsOneWidget);
    expect(find.text('Argent libre'), findsOneWidget);
    expect(find.text('Revenus'), findsOneWidget);
    expect(find.text('Solde bancaire déclaré'), findsOneWidget);
  });

  testWidgets('la carte Revenus ouvre la liste des revenus', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap(_sampleData()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Revenus').first);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Revenus'), findsOneWidget);
  });

  testWidgets('la carte Charges ouvre la liste des charges fixes', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap(_sampleData()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Charges'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Charges fixes'), findsOneWidget);
  });

  testWidgets('la carte Dépenses ouvre la liste des dépenses variables', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap(_sampleData()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dépenses'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Dépenses variables'), findsOneWidget);
  });

  testWidgets('la carte Épargnes ouvre la liste des épargnes', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap(_sampleData()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Épargnes'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Épargne'), findsOneWidget);
  });

  testWidgets("l'icône de notification ouvre les éléments à surveiller", (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap(_sampleData()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.notifications_none_rounded));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Éléments à surveiller'), findsOneWidget);
  });

  testWidgets('"Voir toutes" ouvre la liste complète des charges', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap(_sampleData()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Voir toutes'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Charges fixes'), findsOneWidget);
  });

  testWidgets('une ligne "Prochaines échéances" ouvre la fiche détaillée de la charge', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final charge = FixedExpenseEntity(
      id: 1,
      cycleId: 1,
      name: 'Crédit maison',
      expectedAmountCents: 85000,
      expectedDate: DateTime(2026, 8, 3),
      status: ChargeStatus.aVenir,
    );
    await tester.pumpWidget(wrap(_sampleData(upcomingCharges: [charge])));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Crédit maison'));
    await tester.pumpAndSettle();

    // La fiche détaillée s'ouvre en bas d'écran avec les actions.
    expect(find.text('Modifier'), findsOneWidget);
    expect(find.text('Marquer comme prélevée'), findsOneWidget);
    expect(find.text('Dupliquer'), findsOneWidget);
    expect(find.text('Supprimer'), findsOneWidget);

    await tester.tap(find.text('Modifier'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Modifier la charge fixe'), findsOneWidget);
  });
}
