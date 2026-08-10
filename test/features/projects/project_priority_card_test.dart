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
import 'package:budgetpilot/features/projects/projects_page.dart';
import 'package:budgetpilot/features/projects/widgets/project_priority_card.dart';

late AppDatabase db;
late CycleRepository repository;

Widget wrap() {
  return ProviderScope(
    overrides: [appDatabaseProvider.overrideWith((ref) => db)],
    child: const MaterialApp(home: Scaffold(body: ProjectPriorityCard())),
  );
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

  testWidgets("affiche la carte d'entrée Projets quand il n'y a aucun projet actif", (tester) async {
    await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));

    await tester.pumpWidget(wrap());
    await tester.pump();
    await tester.pump();

    expect(find.text('Projets'), findsOneWidget);
    expect(find.textContaining('découvre si tu peux réellement les réaliser'), findsOneWidget);

    await tester.tap(find.text('Projets'));
    await tester.pumpAndSettle();

    expect(find.byType(ProjectsPage), findsOneWidget);
  });

  testWidgets('affiche le projet prioritaire avec son score dès qu\'un projet actif existe', (tester) async {
    final cycleId = await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
    await repository.createIncome(
      cycleId: cycleId,
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
      desiredDurationMonths: 60,
      estimatedRatePercent: 4.0,
    );

    await tester.pumpWidget(wrap());
    await tester.pump();
    await tester.pump();

    expect(find.text('🎯 PROJET PRIORITAIRE'), findsOneWidget);
    expect(find.textContaining('Porsche Boxster'), findsOneWidget);
    expect(find.text('Voir le projet'), findsOneWidget);
    expect(find.textContaining('Endettement après projet'), findsOneWidget);
    expect(find.textContaining('Reste à vivre après projet'), findsOneWidget);
    expect(find.textContaining('Sécurité'), findsNothing);
  });

  testWidgets("un projet archivé n'apparaît pas comme prioritaire", (tester) async {
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

    expect(find.text('🎯 PROJET PRIORITAIRE'), findsNothing);
    expect(find.text('Projets'), findsOneWidget);
  });

  testWidgets('le bouton "Voir le projet" ouvre la fiche détaillée', (tester) async {
    final cycleId = await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
    await repository.createIncome(
      cycleId: cycleId,
      name: 'Salaire',
      expectedAmountCents: 300000,
      expectedDate: DateTime(2026, 1, 1),
    );
    await repository.createProject(
      name: 'Voyage',
      category: ProjectCategory.travel,
      targetAmountCents: 300000,
      financingMode: ProjectFinancingMode.cash,
    );

    await tester.pumpWidget(wrap());
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Voir le projet'));
    await tester.pumpAndSettle();

    expect(find.byType(ProjectDetailPage), findsOneWidget);
  });

  testWidgets('"Tous les projets" n\'apparaît que si plusieurs projets actifs existent', (tester) async {
    final cycleId = await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
    await repository.createIncome(
      cycleId: cycleId,
      name: 'Salaire',
      expectedAmountCents: 300000,
      expectedDate: DateTime(2026, 1, 1),
    );
    await repository.createProject(
      name: 'Voyage',
      category: ProjectCategory.travel,
      targetAmountCents: 300000,
      financingMode: ProjectFinancingMode.cash,
    );

    await tester.pumpWidget(wrap());
    await tester.pump();
    await tester.pump();

    expect(find.text('Tous les projets'), findsNothing);

    await repository.createProject(
      name: 'Travaux',
      category: ProjectCategory.renovation,
      targetAmountCents: 500000,
      financingMode: ProjectFinancingMode.cash,
    );

    await tester.pump();
    await tester.pump();

    expect(find.text('Tous les projets'), findsOneWidget);

    await tester.tap(find.text('Tous les projets'));
    await tester.pumpAndSettle();

    expect(find.byType(ProjectsPage), findsOneWidget);
  });
}
