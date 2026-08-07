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

late AppDatabase db;
late CycleRepository repository;

Widget wrap(int projectId) {
  return ProviderScope(
    overrides: [appDatabaseProvider.overrideWith((ref) => db)],
    child: MaterialApp(home: ProjectDetailPage(projectId: projectId)),
  );
}

void useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 4200);
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

  Future<int> seedCycleAndIncome({int incomeCents = 300000}) async {
    final cycleId = await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
    await repository.createIncome(
      cycleId: cycleId,
      name: 'Salaire',
      expectedAmountCents: incomeCents,
      expectedDate: DateTime(2026, 1, 1),
    );
    return cycleId;
  }

  testWidgets("affiche un message quand aucun cycle n'existe", (tester) async {
    final id = await repository.createProject(
      name: 'Voyage',
      category: ProjectCategory.travel,
      targetAmountCents: 300000,
      financingMode: ProjectFinancingMode.cash,
    );

    await tester.pumpWidget(wrap(id));
    await tester.pump();

    expect(find.textContaining("Crée d'abord un cycle budgétaire"), findsOneWidget);
  });

  testWidgets('affiche le score, la situation financière et le nom du projet', (tester) async {
    useTallViewport(tester);
    await seedCycleAndIncome();
    final id = await repository.createProject(
      name: 'Porsche Boxster',
      category: ProjectCategory.car,
      targetAmountCents: 4000000,
      availableContributionCents: 800000,
      financingMode: ProjectFinancingMode.mixed,
      desiredDurationMonths: 60,
      estimatedRatePercent: 4.0,
    );

    await tester.pumpWidget(wrap(id));
    await tester.pump();
    await tester.pump();

    expect(find.text('Porsche Boxster'), findsOneWidget);
    expect(find.text('Situation'), findsOneWidget);
    expect(find.text('Prix'), findsOneWidget);
    expect(find.text('À financer'), findsOneWidget);
  });

  testWidgets('affiche "Ce qui va s\'améliorer" quand un crédit se termine bientôt', (tester) async {
    useTallViewport(tester);
    await seedCycleAndIncome(incomeCents: 250000);
    await repository.createCreditForExistingCharge(
      name: 'Crédit Auto',
      initialAmountCents: 1000000,
      remainingCapitalCents: 300000,
      monthlyPaymentCents: 28000,
      expectedEndDate: DateTime(2026, 12, 1),
      remainingInstallments: 11,
    );
    final id = await repository.createProject(
      name: 'Porsche Boxster',
      category: ProjectCategory.car,
      targetAmountCents: 4000000,
      availableContributionCents: 800000,
      financingMode: ProjectFinancingMode.mixed,
      desiredDurationMonths: 60,
      estimatedRatePercent: 4.0,
    );

    await tester.pumpWidget(wrap(id));
    await tester.pump();
    await tester.pump();

    expect(find.text('Ce qui va s\'améliorer'), findsOneWidget);
    expect(find.textContaining('Crédit Auto terminé dans 11 mois'), findsOneWidget);
  });

  testWidgets('le bouton Modifier ouvre le formulaire préremplié', (tester) async {
    useTallViewport(tester);
    await seedCycleAndIncome();
    final id = await repository.createProject(
      name: 'Travaux',
      category: ProjectCategory.renovation,
      targetAmountCents: 500000,
      financingMode: ProjectFinancingMode.cash,
    );

    await tester.pumpWidget(wrap(id));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Modifier'));
    await tester.pumpAndSettle();

    expect(find.byType(ProjectFormPage), findsOneWidget);
  });

  testWidgets('archiver puis réactiver via le menu', (tester) async {
    useTallViewport(tester);
    await seedCycleAndIncome();
    final id = await repository.createProject(
      name: 'Travaux',
      category: ProjectCategory.renovation,
      targetAmountCents: 500000,
      financingMode: ProjectFinancingMode.cash,
    );

    await tester.pumpWidget(wrap(id));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archiver'));
    await tester.pumpAndSettle();

    var project = (await repository.loadProjects()).single;
    expect(project.isActive, isFalse);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Réactiver'));
    await tester.pumpAndSettle();

    project = (await repository.loadProjects()).single;
    expect(project.isActive, isTrue);
  });

  testWidgets('supprimer un projet après confirmation revient en arrière', (tester) async {
    useTallViewport(tester);
    await seedCycleAndIncome();
    final id = await repository.createProject(
      name: 'Travaux',
      category: ProjectCategory.renovation,
      targetAmountCents: 500000,
      financingMode: ProjectFinancingMode.cash,
    );

    await tester.pumpWidget(wrap(id));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer').last);
    await tester.pumpAndSettle();

    expect(await repository.loadProjects(), isEmpty);
  });

  testWidgets('la simulation ne modifie pas les vraies données tant qu\'elle n\'est pas enregistrée', (tester) async {
    useTallViewport(tester);
    await seedCycleAndIncome();
    final id = await repository.createProject(
      name: 'Porsche Boxster',
      category: ProjectCategory.car,
      targetAmountCents: 4000000,
      availableContributionCents: 800000,
      financingMode: ProjectFinancingMode.mixed,
      desiredDurationMonths: 60,
      estimatedRatePercent: 4.0,
    );

    await tester.pumpWidget(wrap(id));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Simuler'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Apport disponible (facultatif)'), '1200');
    await tester.pump();

    // Fermer sans enregistrer : les données réelles ne doivent pas bouger.
    await tester.tapAt(const Offset(50, 50));
    await tester.pumpAndSettle();

    final project = (await repository.loadProjects()).single;
    expect(project.availableContributionCents, 800000);
  });
}
