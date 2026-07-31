import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:budgetpilot/core/providers/database_provider.dart';
import 'package:budgetpilot/data/local/database.dart';
import 'package:budgetpilot/features/settings/settings_page.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Widget wrap() {
    return ProviderScope(
      overrides: [appDatabaseProvider.overrideWith((ref) => db)],
      child: const MaterialApp(home: SettingsPage()),
    );
  }

  testWidgets('le thème système est sélectionné par défaut', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    final segmented = tester.widget<SegmentedButton<ThemeMode>>(find.byType(SegmentedButton<ThemeMode>));
    expect(segmented.selected, {ThemeMode.system});
  });

  testWidgets('changer de thème persiste le choix', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sombre'));
    await tester.pumpAndSettle();

    final segmented = tester.widget<SegmentedButton<ThemeMode>>(find.byType(SegmentedButton<ThemeMode>));
    expect(segmented.selected, {ThemeMode.dark});
  });

  testWidgets('Documentation ouvre la page de documentation', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Documentation'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Documentation'), findsOneWidget);
    expect(find.text('Utiliser BudgetPilot au quotidien'), findsOneWidget);
  });

  testWidgets('7 appuis sur la version révèlent le menu développeur', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Charger les données de démonstration'), findsNothing);

    for (var i = 0; i < 7; i++) {
      await tester.tap(find.text('Version 0.8.0'));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.text('Charger les données de démonstration'), findsOneWidget);
  });
}
