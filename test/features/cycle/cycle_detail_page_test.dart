import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:budgetpilot/core/formatting/currency_formatter.dart';
import 'package:budgetpilot/core/theme/design_tokens.dart';
import 'package:budgetpilot/domain/models/dashboard_view_data.dart';
import 'package:budgetpilot/features/cycle/cycle_detail_page.dart';

DashboardViewData _sampleData({int? declaredBalance}) {
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
    unconfirmedChargesCount: 0,
    unconfirmedChargesTotalCents: 0,
    declaredBankBalanceCents: declaredBalance,
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR', null);
  });

  testWidgets('un solde bancaire négatif est affiché avec son signe et une couleur d\'alerte discrète', (tester) async {
    final data = _sampleData(declaredBalance: -18000);

    await tester.pumpWidget(MaterialApp(home: CycleDetailPage(data: data)));
    await tester.pump();

    // L'Argent libre reste affiché tel quel, jamais affecté par le solde
    // bancaire déclaré (donnée distincte).
    expect(find.textContaining(formatCentsAsEuro(data.realRemainingCents)), findsOneWidget);

    final valueText = tester.widget<Text>(find.text(formatCentsAsEuro(-18000)));
    expect(valueText.style?.color, CategoryColors.fixedExpense);
  });

  testWidgets('un solde bancaire positif garde la couleur neutre habituelle', (tester) async {
    final data = _sampleData(declaredBalance: 25000);

    await tester.pumpWidget(MaterialApp(home: CycleDetailPage(data: data)));
    await tester.pump();

    final valueText = tester.widget<Text>(find.text(formatCentsAsEuro(25000)));
    expect(valueText.style?.color, isNot(CategoryColors.fixedExpense));
  });

  testWidgets('aucun solde déclaré : la ligne "Solde bancaire déclaré" est absente', (tester) async {
    final data = _sampleData();

    await tester.pumpWidget(MaterialApp(home: CycleDetailPage(data: data)));
    await tester.pump();

    expect(find.text('Solde bancaire déclaré'), findsNothing);
  });
}
