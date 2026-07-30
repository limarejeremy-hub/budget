import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:budgetpilot/core/formatting/currency_formatter.dart';
import 'package:budgetpilot/core/providers/dashboard_providers.dart';
import 'package:budgetpilot/domain/models/dashboard_view_data.dart';
import 'package:budgetpilot/features/dashboard/dashboard_page.dart';

Widget _wrap(Widget child, List<Override> overrides) {
  return ProviderScope(overrides: overrides, child: MaterialApp(home: child));
}

DashboardViewData _sampleData({int unconfirmed = 4, int? declaredBalance = 264000}) {
  return DashboardViewData(
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
  testWidgets("affiche l'état vide quand aucun cycle n'existe", (tester) async {
    await tester.pumpWidget(_wrap(
      const DashboardPage(),
      [dashboardProvider.overrideWith((ref) => Stream.value(null))],
    ));
    await tester.pump();

    expect(find.text('Aucun cycle en cours'), findsOneWidget);
    expect(find.text('Charger les données de démonstration'), findsOneWidget);
  });

  testWidgets('affiche ARGENT LIBRE, le montant et la section À surveiller', (tester) async {
    final data = _sampleData();

    await tester.pumpWidget(_wrap(
      const DashboardPage(),
      [dashboardProvider.overrideWith((ref) => Stream.value(data))],
    ));
    await tester.pump();

    expect(find.text('ARGENT LIBRE'), findsOneWidget);
    expect(find.textContaining(formatCentsAsEuro(data.realRemainingCents)), findsOneWidget);
    expect(find.textContaining('À surveiller'), findsOneWidget);
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

  testWidgets('le bouton + ouvre le menu avec les 4 options', (tester) async {
    final data = _sampleData(unconfirmed: 0, declaredBalance: null);

    await tester.pumpWidget(_wrap(
      const DashboardPage(),
      [dashboardProvider.overrideWith((ref) => Stream.value(data))],
    ));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('Dépense'), findsOneWidget);
    expect(find.text('Charge fixe'), findsOneWidget);
    expect(find.text('Revenu'), findsOneWidget);
    expect(find.text('Épargne'), findsOneWidget);
  });
}
