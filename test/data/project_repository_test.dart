import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:budgetpilot/core/constants/app_constants.dart';
import 'package:budgetpilot/data/local/cycle_repository.dart';
import 'package:budgetpilot/data/local/database.dart';

void main() {
  late AppDatabase db;
  late CycleRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = CycleRepository(db);
  });

  tearDown(() => db.close());

  test('createProject crée un projet avec toutes ses données', () async {
    final id = await repository.createProject(
      name: 'Porsche Boxster',
      category: ProjectCategory.car,
      targetAmountCents: 4000000,
      desiredDate: DateTime(2027, 6, 1),
      availableContributionCents: 800000,
      desiredContributionCents: 1200000,
      financingMode: ProjectFinancingMode.mixed,
      maxMonthlyPaymentCents: 50000,
      desiredDurationMonths: 60,
      estimatedRatePercent: 4.5,
      extraMonthlyCostCents: 10000,
      notes: 'Rêve de toujours',
      priority: ProjectPriority.high,
    );

    final project = (await repository.loadProjects()).single;
    expect(project.id, id);
    expect(project.name, 'Porsche Boxster');
    expect(project.category, ProjectCategory.car);
    expect(project.targetAmountCents, 4000000);
    expect(project.desiredDate, DateTime(2027, 6, 1));
    expect(project.availableContributionCents, 800000);
    expect(project.desiredContributionCents, 1200000);
    expect(project.financingMode, ProjectFinancingMode.mixed);
    expect(project.maxMonthlyPaymentCents, 50000);
    expect(project.desiredDurationMonths, 60);
    expect(project.estimatedRatePercent, 4.5);
    expect(project.extraMonthlyCostCents, 10000);
    expect(project.notes, 'Rêve de toujours');
    expect(project.isActive, isTrue);
    expect(project.priority, ProjectPriority.high);
  });

  test('createProject sans champs facultatifs les laisse à null, priorité "moyenne" par défaut', () async {
    await repository.createProject(
      name: 'Voyage',
      category: ProjectCategory.travel,
      targetAmountCents: 600000,
      financingMode: ProjectFinancingMode.cash,
    );

    final project = (await repository.loadProjects()).single;
    expect(project.desiredDate, isNull);
    expect(project.desiredContributionCents, isNull);
    expect(project.maxMonthlyPaymentCents, isNull);
    expect(project.desiredDurationMonths, isNull);
    expect(project.estimatedRatePercent, isNull);
    expect(project.extraMonthlyCostCents, isNull);
    expect(project.availableContributionCents, 0);
    expect(project.priority, ProjectPriority.medium);
  });

  test('updateProject modifie un projet existant', () async {
    final id = await repository.createProject(
      name: 'Voyage',
      category: ProjectCategory.travel,
      targetAmountCents: 600000,
      financingMode: ProjectFinancingMode.cash,
    );

    await repository.updateProject(
      id: id,
      name: 'Voyage au Japon',
      category: ProjectCategory.travel,
      targetAmountCents: 700000,
      availableContributionCents: 200000,
      financingMode: ProjectFinancingMode.cash,
      priority: ProjectPriority.low,
    );

    final project = (await repository.loadProjects()).single;
    expect(project.name, 'Voyage au Japon');
    expect(project.targetAmountCents, 700000);
    expect(project.availableContributionCents, 200000);
    expect(project.priority, ProjectPriority.low);
  });

  test('setProjectActive archive puis réactive un projet, sans le supprimer', () async {
    final id = await repository.createProject(
      name: 'Travaux',
      category: ProjectCategory.renovation,
      targetAmountCents: 300000,
      financingMode: ProjectFinancingMode.cash,
    );

    await repository.setProjectActive(id, false);
    var project = (await repository.loadProjects()).single;
    expect(project.isActive, isFalse);

    await repository.setProjectActive(id, true);
    project = (await repository.loadProjects()).single;
    expect(project.isActive, isTrue);
  });

  test('duplicateProject crée une copie indépendante, toujours active', () async {
    final id = await repository.createProject(
      name: 'Porsche Boxster',
      category: ProjectCategory.car,
      targetAmountCents: 4000000,
      availableContributionCents: 800000,
      financingMode: ProjectFinancingMode.mixed,
      priority: ProjectPriority.high,
    );
    await repository.setProjectActive(id, false);

    final duplicateId = await repository.duplicateProject(id);

    expect(duplicateId, isNot(id));
    final projects = await repository.loadProjects();
    expect(projects, hasLength(2));
    final duplicate = projects.firstWhere((p) => p.id == duplicateId);
    expect(duplicate.name, 'Porsche Boxster (copie)');
    expect(duplicate.targetAmountCents, 4000000);
    expect(duplicate.availableContributionCents, 800000);
    expect(duplicate.priority, ProjectPriority.high);
    expect(duplicate.isActive, isTrue, reason: 'une copie démarre toujours active, indépendamment de l\'original');
  });

  test('deleteProject supprime définitivement le projet', () async {
    final id = await repository.createProject(
      name: 'Mariage',
      category: ProjectCategory.wedding,
      targetAmountCents: 1500000,
      financingMode: ProjectFinancingMode.cash,
    );

    await repository.deleteProject(id);
    expect(await repository.loadProjects(), isEmpty);
  });

  test('watchProjects se réémet quand un projet est ajouté', () async {
    final emissions = <int>[];
    final sub = repository.watchProjects().listen((list) => emissions.add(list.length));
    await Future<void>.delayed(Duration.zero);

    await repository.createProject(
      name: 'Gros achat',
      category: ProjectCategory.bigPurchase,
      targetAmountCents: 200000,
      financingMode: ProjectFinancingMode.cash,
    );
    await Future<void>.delayed(Duration.zero);

    await sub.cancel();
    expect(emissions.first, 0);
    expect(emissions.last, 1);
  });
}
