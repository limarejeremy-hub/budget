import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:budgetpilot/core/constants/app_constants.dart';
import 'package:budgetpilot/core/providers/database_provider.dart';
import 'package:budgetpilot/data/local/cycle_repository.dart';
import 'package:budgetpilot/data/local/database.dart';
import 'package:budgetpilot/features/projects/project_detail_page.dart';
import 'package:budgetpilot/features/projects/project_form_page.dart';
import 'package:budgetpilot/features/projects/projects_page.dart';

late AppDatabase db;
late CycleRepository repository;

Widget wrap() {
  return ProviderScope(
    overrides: [appDatabaseProvider.overrideWith((ref) => db)],
    child: const MaterialApp(home: ProjectsPage()),
  );
}

void useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR', null);
  });

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = CycleRepository(db);
  });

  tearDown(() => db.close());

  testWidgets("affiche l'état vide quand aucun projet n'existe", (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Aucun projet'), findsOneWidget);
  });

  testWidgets('liste un projet actif avec son score', (tester) async {
    useTallViewport(tester);
    await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
    await repository.createIncome(
      cycleId: (await repository.loadCurrentCycleData())!.cycle.id,
      name: 'Salaire',
      expectedAmountCents: 300000,
      expectedDate: DateTime(2026, 1, 1),
    );
    await repository.createProject(
      name: 'Porsche Boxster',
      category: ProjectCategory.car,
      targetAmountCents: 4000000,
      availableContributionCents: 800000,
      financingMode: ProjectFinancingMode.mixed,
    );

    await tester.pumpWidget(wrap());
    await tester.pump();
    await tester.pump();

    expect(find.text('Porsche Boxster'), findsOneWidget);
  });

  testWidgets('la carte projet affiche l\'endettement concret, plus jamais un score de "sécurité" (V1.2)',
      (tester) async {
    useTallViewport(tester);
    await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
    await repository.createIncome(
      cycleId: (await repository.loadCurrentCycleData())!.cycle.id,
      name: 'Salaire',
      expectedAmountCents: 300000,
      expectedDate: DateTime(2026, 1, 1),
    );
    await repository.createProject(
      name: 'Porsche Boxster',
      category: ProjectCategory.car,
      targetAmountCents: 4000000,
      availableContributionCents: 800000,
      financingMode: ProjectFinancingMode.mixed,
    );

    await tester.pumpWidget(wrap());
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Endettement'), findsWidgets);
    expect(find.textContaining('Reste à vivre'), findsWidgets);
    expect(find.textContaining('Sécurité'), findsNothing);
  });

  testWidgets('le bouton + ouvre le formulaire de création', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.byType(ProjectFormPage), findsOneWidget);
  });

  testWidgets('un tap sur une carte ouvre la fiche détaillée du projet', (tester) async {
    useTallViewport(tester);
    await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
    await repository.createProject(
      name: 'Voyage',
      category: ProjectCategory.travel,
      targetAmountCents: 300000,
      financingMode: ProjectFinancingMode.cash,
    );

    await tester.pumpWidget(wrap());
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Voyage'));
    await tester.pumpAndSettle();

    expect(find.byType(ProjectDetailPage), findsOneWidget);
  });

  testWidgets('les projets archivés apparaissent repliés sous "Archivés"', (tester) async {
    useTallViewport(tester);
    await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
    final id = await repository.createProject(
      name: 'Ancien projet',
      category: ProjectCategory.other,
      targetAmountCents: 100000,
      financingMode: ProjectFinancingMode.cash,
    );
    await repository.setProjectActive(id, false);

    await tester.pumpWidget(wrap());
    await tester.pump();
    await tester.pump();

    expect(find.text('Aucun projet'), findsOneWidget);
    expect(find.text('Archivés (1)'), findsOneWidget);
    expect(find.text('Ancien projet'), findsNothing);

    await tester.tap(find.text('Archivés (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Ancien projet'), findsOneWidget);
  });
}
