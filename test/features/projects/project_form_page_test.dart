import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:budgetpilot/core/constants/app_constants.dart';
import 'package:budgetpilot/core/providers/database_provider.dart';
import 'package:budgetpilot/data/local/converters/entity_mappers.dart';
import 'package:budgetpilot/data/local/cycle_repository.dart';
import 'package:budgetpilot/data/local/database.dart';
import 'package:budgetpilot/features/projects/project_form_page.dart';

late AppDatabase db;
late CycleRepository repository;

Widget wrap(Widget child) {
  return ProviderScope(
    overrides: [appDatabaseProvider.overrideWith((ref) => db)],
    child: MaterialApp(home: child),
  );
}

void useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 3600);
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

  testWidgets('crée un projet comptant (les champs de financement restent masqués)', (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(wrap(const ProjectFormPage()));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Nom du projet'), 'Voyage au Japon');
    await tester.enterText(find.widgetWithText(TextFormField, 'Prix / budget cible'), '6000');

    await tester.tap(find.text('Indéterminé'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Comptant').last);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, 'Mensualité maximale souhaitée (facultatif)'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Enregistrer'));
    await tester.pumpAndSettle();

    final project = (await repository.loadProjects()).single;
    expect(project.name, 'Voyage au Japon');
    expect(project.targetAmountCents, 600000);
    expect(project.financingMode, ProjectFinancingMode.cash);
  });

  testWidgets('les champs de financement apparaissent en mode financé', (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(wrap(const ProjectFormPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Indéterminé'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Financement').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('Mensualité maximale souhaitée'), findsOneWidget);
    expect(find.textContaining('Taux annuel estimé'), findsOneWidget);
  });

  testWidgets('la date souhaitée n\'est enregistrée que si le bouton est activé', (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(wrap(const ProjectFormPage()));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Nom du projet'), 'Travaux');
    await tester.enterText(find.widgetWithText(TextFormField, 'Prix / budget cible'), '3000');

    await tester.tap(find.widgetWithText(FilledButton, 'Enregistrer'));
    await tester.pumpAndSettle();

    final project = (await repository.loadProjects()).single;
    expect(project.desiredDate, isNull);
  });

  testWidgets('modifier un projet existant préremplit le formulaire', (tester) async {
    useTallViewport(tester);
    final id = await repository.createProject(
      name: 'Porsche Boxster',
      category: ProjectCategory.car,
      targetAmountCents: 4000000,
      availableContributionCents: 800000,
      financingMode: ProjectFinancingMode.mixed,
    );
    final existing = projectFromRow((await repository.loadProjects()).single);
    expect(existing.id, id);

    await tester.pumpWidget(wrap(ProjectFormPage(existing: existing)));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, 'Porsche Boxster'), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Modifier le projet'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Porsche Boxster'), 'Porsche 718');
    await tester.tap(find.widgetWithText(FilledButton, 'Enregistrer'));
    await tester.pumpAndSettle();

    final updated = (await repository.loadProjects()).single;
    expect(updated.name, 'Porsche 718');
    expect(updated.targetAmountCents, 4000000);
  });

  testWidgets('le nom est requis', (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(wrap(const ProjectFormPage()));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Prix / budget cible'), '1000');
    await tester.tap(find.widgetWithText(FilledButton, 'Enregistrer'));
    await tester.pumpAndSettle();

    expect(find.text('Nom requis'), findsOneWidget);
    expect(await repository.loadProjects(), isEmpty);
  });
}
