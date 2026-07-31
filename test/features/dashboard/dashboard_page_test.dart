import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:budgetpilot/core/formatting/currency_formatter.dart';
import 'package:budgetpilot/core/providers/dashboard_providers.dart';
import 'package:budgetpilot/core/providers/database_provider.dart';
import 'package:budgetpilot/data/local/database.dart';
import 'package:budgetpilot/domain/models/dashboard_view_data.dart';
import 'package:budgetpilot/features/dashboard/dashboard_page.dart';

// Carte Crédits du tableau de bord : watch un provider indépendant du cycle
// (base de données réelle) — une base en mémoire évite tout accès à
// path_provider (indisponible en test).
late AppDatabase _db;

Widget _wrap(Widget child, List<Override> overrides) {
  return ProviderScope(
    overrides: [appDatabaseProvider.overrideWith((ref) => _db), ...overrides],
    child: MaterialApp(home: child),
  );
}

DashboardViewData _sampleData({int unconfirmed = 4, int? declaredBalance = 264000}) {
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
    unconfirmedChargesCount: unconfirmed,
    unconfirmedChargesTotalCents: 61200,
    declaredBankBalanceCents: declaredBalance,
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR', null);
  });

  setUp(() {
    _db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => _db.close());

  testWidgets("affiche l'état vide quand aucun cycle n'existe", (tester) async {
    await tester.pumpWidget(_wrap(
      const DashboardPage(),
      [dashboardProvider.overrideWith((ref) => Stream.value(null))],
    ));
    await tester.pump();

    expect(find.text('Aucun cycle en cours'), findsOneWidget);
    expect(find.text('Créer mon premier cycle'), findsOneWidget);
  });

  testWidgets('affiche ARGENT LIBRE, le montant et la section Prochaines échéances',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final data = _sampleData();

    await tester.pumpWidget(_wrap(
      const DashboardPage(),
      [dashboardProvider.overrideWith((ref) => Stream.value(data))],
    ));
    await tester.pump();

    expect(find.text('ARGENT LIBRE'), findsOneWidget);
    expect(find.textContaining(formatCentsAsEuro(data.realRemainingCents)), findsOneWidget);
    expect(find.textContaining('Prochaines échéances'), findsOneWidget);
    expect(find.textContaining('Solde bancaire déclaré'), findsOneWidget);
  });

  testWidgets("affiche un état d'erreur si le flux échoue", (tester) async {
    await tester.pumpWidget(_wrap(
      const DashboardPage(),
      [dashboardProvider.overrideWith((ref) => Stream.error(Exception('Erreur DB')))],
    ));
    await tester.pump();

    expect(find.text('Impossible de charger le tableau de bord'), findsOneWidget);
  });

  testWidgets('le bouton + ouvre le menu avec les 5 options', (tester) async {
    final data = _sampleData(unconfirmed: 0, declaredBalance: null);

    await tester.pumpWidget(_wrap(
      const DashboardPage(),
      [dashboardProvider.overrideWith((ref) => Stream.value(data))],
    ));
    // Laisse la transition d'apparition du FAB se terminer avant de taper.
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('Dépense'), findsOneWidget);
    expect(find.text('Charge fixe'), findsOneWidget);
    expect(find.text('Revenu'), findsOneWidget);
    expect(find.text('Épargne'), findsOneWidget);
    expect(find.text('Crédit'), findsOneWidget);
  });
}
