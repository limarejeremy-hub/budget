import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:budgetpilot/core/widgets/brand_badge.dart';

void main() {
  testWidgets('affiche le monogramme de la marque reconnue', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: BrandBadge(
          name: 'Abonnement Netflix',
          fallbackIcon: Icons.receipt_long_rounded,
          fallbackColor: Colors.orange,
        ),
      ),
    ));

    expect(find.text('N'), findsOneWidget);
    expect(find.byIcon(Icons.receipt_long_rounded), findsNothing);
  });

  testWidgets("retombe sur l'icône générique quand la marque n'est pas reconnue", (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: BrandBadge(
          name: 'Marché du coin',
          fallbackIcon: Icons.receipt_long_rounded,
          fallbackColor: Colors.orange,
        ),
      ),
    ));

    expect(find.byIcon(Icons.receipt_long_rounded), findsOneWidget);
  });
}
