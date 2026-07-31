import 'package:drift/drift.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/default_categories.dart';
import 'database.dart';

/// Version du format de sauvegarde JSON (export/import). À incrémenter si
/// la structure change de façon incompatible.
const int backupFormatVersion = 1;

/// Levée lorsqu'un fichier de sauvegarde ne correspond pas au format attendu.
/// Le message est destiné à être affiché directement à l'utilisateur.
class BackupValidationException implements Exception {
  final String message;
  const BackupValidationException(this.message);

  @override
  String toString() => message;
}

class CycleDashboardRawData {
  final BudgetCycle cycle;
  final List<Income> incomes;
  final List<FixedExpense> fixedExpenses;
  final List<VariableExpense> variableExpenses;
  final List<Saving> savings;

  const CycleDashboardRawData({
    required this.cycle,
    required this.incomes,
    required this.fixedExpenses,
    required this.variableExpenses,
    required this.savings,
  });
}

/// Requêtes Drift pour charger le cycle courant, ses données associées, et
/// la création / modification / suppression des saisies (revenus, charges
/// fixes, dépenses variables, épargnes) et des cycles.
class CycleRepository {
  final AppDatabase db;
  const CycleRepository(this.db);

  Future<BudgetCycle?> _fetchCurrentCycle() {
    return (db.select(db.budgetCycles)
          ..where((c) => c.status.equals('ouvert'))
          ..orderBy([(c) => OrderingTerm.desc(c.startDate)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<CycleDashboardRawData?> loadCurrentCycleData() async {
    final cycle = await _fetchCurrentCycle();
    if (cycle == null) return null;

    final incomes = await (db.select(db.incomes)..where((i) => i.cycleId.equals(cycle.id))).get();
    final fixedExpenses =
        await (db.select(db.fixedExpenses)..where((e) => e.cycleId.equals(cycle.id))).get();
    final variableExpenses =
        await (db.select(db.variableExpenses)..where((e) => e.cycleId.equals(cycle.id))).get();
    final savings = await (db.select(db.savings)..where((s) => s.cycleId.equals(cycle.id))).get();

    return CycleDashboardRawData(
      cycle: cycle,
      incomes: incomes,
      fixedExpenses: fixedExpenses,
      variableExpenses: variableExpenses,
      savings: savings,
    );
  }

  /// Flux réactif : se réémet dès qu'une des tables concernées change.
  Stream<CycleDashboardRawData?> watchCurrentCycleData() async* {
    yield await loadCurrentCycleData();
    yield* db
        .tableUpdates(TableUpdateQuery.onAllTables([
          db.budgetCycles,
          db.incomes,
          db.fixedExpenses,
          db.variableExpenses,
          db.savings,
        ]))
        .asyncMap((_) => loadCurrentCycleData());
  }

  /// Tous les cycles (courant compris), du plus récent au plus ancien.
  Stream<List<BudgetCycle>> watchAllCycles() {
    return (db.select(db.budgetCycles)..orderBy([(c) => OrderingTerm.desc(c.startDate)]))
        .watch();
  }

  // ---------------------------------------------------------------------
  // Catégories
  // ---------------------------------------------------------------------

  /// Peuple les catégories par défaut si la table est vide. Idempotent :
  /// peut être appelée à chaque création de cycle sans risque de doublon.
  Future<void> ensureDefaultCategories() async {
    final existing = await db.select(db.categories).get();
    if (existing.isNotEmpty) return;

    final all = <(String, String, String)>[
      ...defaultIncomeCategories,
      ...defaultFixedCategories,
      ...defaultVariableCategories,
      ...defaultSavingCategories,
    ];

    await db.batch((batch) {
      batch.insertAll(db.categories, [
        for (final (name, type, icon) in all)
          CategoriesCompanion.insert(name: name, type: type, icon: Value(icon)),
      ]);
    });
  }

  Future<List<Category>> categoriesForType(String type) {
    return (db.select(db.categories)
          ..where((c) => c.type.equals(type) & c.isActive.equals(true))
          ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
        .get();
  }

  // ---------------------------------------------------------------------
  // Cycles
  // ---------------------------------------------------------------------

  Future<int> createCycle({
    required DateTime startDate,
    required DateTime endDate,
    String? name,
    int? declaredBankBalanceCents,
  }) async {
    await ensureDefaultCategories();
    return db.into(db.budgetCycles).insert(BudgetCyclesCompanion.insert(
          startDate: startDate,
          endDate: endDate,
          name: Value(name),
          declaredBankBalanceCents: Value(declaredBankBalanceCents),
        ));
  }

  // ---------------------------------------------------------------------
  // Revenus
  // ---------------------------------------------------------------------

  Future<int> createIncome({
    required int cycleId,
    required String name,
    required int expectedAmountCents,
    int? actualAmountCents,
    required DateTime expectedDate,
    bool isRecurring = false,
    bool isActive = true,
  }) {
    return db.into(db.incomes).insert(IncomesCompanion.insert(
          cycleId: cycleId,
          name: name,
          expectedAmountCents: expectedAmountCents,
          actualAmountCents: Value(actualAmountCents),
          expectedDate: expectedDate,
          isRecurring: Value(isRecurring),
          isActive: Value(isActive),
        ));
  }

  Future<void> updateIncome({
    required int id,
    required String name,
    required int expectedAmountCents,
    int? actualAmountCents,
    required DateTime expectedDate,
    required bool isRecurring,
    required bool isActive,
  }) {
    return (db.update(db.incomes)..where((t) => t.id.equals(id))).write(IncomesCompanion(
      name: Value(name),
      expectedAmountCents: Value(expectedAmountCents),
      actualAmountCents: Value(actualAmountCents),
      expectedDate: Value(expectedDate),
      isRecurring: Value(isRecurring),
      isActive: Value(isActive),
    ));
  }

  Future<void> deleteIncome(int id) => (db.delete(db.incomes)..where((t) => t.id.equals(id))).go();

  // ---------------------------------------------------------------------
  // Charges fixes
  // ---------------------------------------------------------------------

  Future<int> createFixedExpense({
    required int cycleId,
    required String name,
    required int expectedAmountCents,
    int? actualAmountCents,
    required DateTime expectedDate,
    int? categoryId,
    bool isRecurring = false,
    bool isActive = true,
  }) {
    return db.into(db.fixedExpenses).insert(FixedExpensesCompanion.insert(
          cycleId: cycleId,
          name: name,
          expectedAmountCents: expectedAmountCents,
          actualAmountCents: Value(actualAmountCents),
          expectedDate: expectedDate,
          categoryId: Value(categoryId),
          isRecurring: Value(isRecurring),
          isActive: Value(isActive),
        ));
  }

  Future<void> updateFixedExpense({
    required int id,
    required String name,
    required int expectedAmountCents,
    int? actualAmountCents,
    required DateTime expectedDate,
    int? categoryId,
    required bool isRecurring,
    required bool isActive,
  }) {
    return (db.update(db.fixedExpenses)..where((t) => t.id.equals(id)))
        .write(FixedExpensesCompanion(
      name: Value(name),
      expectedAmountCents: Value(expectedAmountCents),
      actualAmountCents: Value(actualAmountCents),
      expectedDate: Value(expectedDate),
      categoryId: Value(categoryId),
      isRecurring: Value(isRecurring),
      isActive: Value(isActive),
    ));
  }

  Future<void> deleteFixedExpense(int id) =>
      (db.delete(db.fixedExpenses)..where((t) => t.id.equals(id))).go();

  /// Change manuellement le statut d'une charge fixe (ex : "prelevee",
  /// "suspendue", "incident"). Un statut manuel n'est jamais recalculé
  /// automatiquement par [ChargeStatusService] (cf. entity_mappers.dart).
  Future<void> updateFixedExpenseStatus(int id, String status) {
    return (db.update(db.fixedExpenses)..where((t) => t.id.equals(id)))
        .write(FixedExpensesCompanion(status: Value(status)));
  }

  // ---------------------------------------------------------------------
  // Dépenses variables
  // ---------------------------------------------------------------------

  Future<int> createVariableExpense({
    required int cycleId,
    String? name,
    required int amountCents,
    required DateTime date,
    int? categoryId,
  }) {
    return db.into(db.variableExpenses).insert(VariableExpensesCompanion.insert(
          cycleId: cycleId,
          name: Value(name),
          amountCents: amountCents,
          date: date,
          categoryId: Value(categoryId),
        ));
  }

  Future<void> updateVariableExpense({
    required int id,
    String? name,
    required int amountCents,
    required DateTime date,
    int? categoryId,
  }) {
    return (db.update(db.variableExpenses)..where((t) => t.id.equals(id)))
        .write(VariableExpensesCompanion(
      name: Value(name),
      amountCents: Value(amountCents),
      date: Value(date),
      categoryId: Value(categoryId),
      updatedAt: Value(DateTime.now()),
    ));
  }

  Future<void> deleteVariableExpense(int id) =>
      (db.delete(db.variableExpenses)..where((t) => t.id.equals(id))).go();

  // ---------------------------------------------------------------------
  // Épargnes
  // ---------------------------------------------------------------------

  Future<int> createSaving({
    required int cycleId,
    required String name,
    required int expectedAmountCents,
    int? actualAmountCents,
    required DateTime expectedDate,
    bool isRecurring = false,
    bool isActive = true,
  }) {
    return db.into(db.savings).insert(SavingsCompanion.insert(
          cycleId: cycleId,
          name: name,
          expectedAmountCents: expectedAmountCents,
          actualAmountCents: Value(actualAmountCents),
          expectedDate: expectedDate,
          isRecurring: Value(isRecurring),
          isActive: Value(isActive),
        ));
  }

  Future<void> updateSaving({
    required int id,
    required String name,
    required int expectedAmountCents,
    int? actualAmountCents,
    required DateTime expectedDate,
    required bool isRecurring,
    required bool isActive,
  }) {
    return (db.update(db.savings)..where((t) => t.id.equals(id))).write(SavingsCompanion(
      name: Value(name),
      expectedAmountCents: Value(expectedAmountCents),
      actualAmountCents: Value(actualAmountCents),
      expectedDate: Value(expectedDate),
      isRecurring: Value(isRecurring),
      isActive: Value(isActive),
    ));
  }

  Future<void> deleteSaving(int id) => (db.delete(db.savings)..where((t) => t.id.equals(id))).go();

  // ---------------------------------------------------------------------
  // Sauvegarde (export / import JSON local)
  // ---------------------------------------------------------------------

  /// Sérialise l'intégralité des données (tous les cycles et leurs saisies)
  /// en une structure JSON-compatible (Map/List/valeurs primitives). Aucune
  /// donnée bancaire sensible n'est incluse — uniquement les montants et
  /// libellés déjà saisis par l'utilisateur dans l'application.
  Future<Map<String, dynamic>> exportBackup() async {
    final cycles = await db.select(db.budgetCycles).get();
    final categories = await db.select(db.categories).get();
    final categoryNameById = {for (final c in categories) c.id: c.name};

    final cycleMaps = <Map<String, dynamic>>[];
    for (final cycle in cycles) {
      final incomes = await (db.select(db.incomes)..where((i) => i.cycleId.equals(cycle.id))).get();
      final fixedExpenses =
          await (db.select(db.fixedExpenses)..where((e) => e.cycleId.equals(cycle.id))).get();
      final variableExpenses =
          await (db.select(db.variableExpenses)..where((e) => e.cycleId.equals(cycle.id))).get();
      final savings = await (db.select(db.savings)..where((s) => s.cycleId.equals(cycle.id))).get();

      cycleMaps.add({
        'name': cycle.name,
        'startDate': cycle.startDate.toIso8601String(),
        'endDate': cycle.endDate.toIso8601String(),
        'status': cycle.status,
        'declaredBankBalanceCents': cycle.declaredBankBalanceCents,
        'incomes': [
          for (final i in incomes)
            {
              'name': i.name,
              'expectedAmountCents': i.expectedAmountCents,
              'actualAmountCents': i.actualAmountCents,
              'expectedDate': i.expectedDate.toIso8601String(),
              'isRecurring': i.isRecurring,
              'isActive': i.isActive,
            },
        ],
        'fixedExpenses': [
          for (final e in fixedExpenses)
            {
              'name': e.name,
              'expectedAmountCents': e.expectedAmountCents,
              'actualAmountCents': e.actualAmountCents,
              'expectedDate': e.expectedDate.toIso8601String(),
              'status': e.status,
              'categoryName': e.categoryId == null ? null : categoryNameById[e.categoryId],
              'isRecurring': e.isRecurring,
              'isActive': e.isActive,
            },
        ],
        'variableExpenses': [
          for (final e in variableExpenses)
            {
              'name': e.name,
              'amountCents': e.amountCents,
              'date': e.date.toIso8601String(),
              'categoryName': e.categoryId == null ? null : categoryNameById[e.categoryId],
            },
        ],
        'savings': [
          for (final s in savings)
            {
              'name': s.name,
              'expectedAmountCents': s.expectedAmountCents,
              'actualAmountCents': s.actualAmountCents,
              'expectedDate': s.expectedDate.toIso8601String(),
              'status': s.status,
              'isRecurring': s.isRecurring,
              'isActive': s.isActive,
            },
        ],
      });
    }

    return {
      'formatVersion': backupFormatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'cycles': cycleMaps,
    };
  }

  /// Vérifie qu'une structure JSON décodée correspond bien au format de
  /// sauvegarde attendu, avant toute écriture en base. Lève
  /// [BackupValidationException] (message affichable) si le fichier est
  /// invalide, d'une version non prise en charge, ou incomplet.
  void validateBackup(Object? decoded) {
    if (decoded is! Map || decoded['cycles'] == null) {
      throw const BackupValidationException(
          "Ce fichier n'est pas une sauvegarde BudgetPilot valide.");
    }
    final formatVersion = decoded['formatVersion'];
    if (formatVersion != backupFormatVersion) {
      throw const BackupValidationException(
          'Version de sauvegarde non prise en charge par cette version de BudgetPilot.');
    }
    final cycles = decoded['cycles'];
    if (cycles is! List) {
      throw const BackupValidationException('La sauvegarde ne contient aucun cycle exploitable.');
    }
    for (final cycle in cycles) {
      if (cycle is! Map || cycle['startDate'] == null || cycle['endDate'] == null) {
        throw const BackupValidationException('Un cycle de la sauvegarde est incomplet ou corrompu.');
      }
    }
  }

  /// Importe une sauvegarde préalablement validée par [validateBackup].
  /// Si [replaceExisting] est vrai, toutes les données existantes (cycles et
  /// saisies) sont supprimées avant l'import ; sinon les cycles importés
  /// s'ajoutent aux données existantes. Toujours exécuté dans une seule
  /// transaction : soit tout est importé, soit rien ne change.
  /// Renvoie le nombre de cycles importés.
  Future<int> importBackup(Map<String, dynamic> data, {required bool replaceExisting}) {
    final cycles = (data['cycles'] as List).cast<Map<String, dynamic>>();

    return db.transaction<int>(() async {
      if (replaceExisting) {
        await db.delete(db.variableExpenses).go();
        await db.delete(db.savings).go();
        await db.delete(db.fixedExpenses).go();
        await db.delete(db.incomes).go();
        await db.delete(db.budgetCycles).go();
      }

      await ensureDefaultCategories();
      final categories = await db.select(db.categories).get();
      final categoryIdByName = {for (final c in categories) c.name: c.id};

      var importedCycles = 0;
      for (final cycleJson in cycles) {
        final cycleId = await db.into(db.budgetCycles).insert(BudgetCyclesCompanion.insert(
              name: Value(cycleJson['name'] as String?),
              startDate: DateTime.parse(cycleJson['startDate'] as String),
              endDate: DateTime.parse(cycleJson['endDate'] as String),
              status: Value(cycleJson['status'] as String? ?? 'ouvert'),
              declaredBankBalanceCents: Value(cycleJson['declaredBankBalanceCents'] as int?),
            ));
        importedCycles++;

        for (final raw in (cycleJson['incomes'] as List? ?? const [])) {
          final i = raw as Map<String, dynamic>;
          await db.into(db.incomes).insert(IncomesCompanion.insert(
                cycleId: cycleId,
                name: i['name'] as String,
                expectedAmountCents: i['expectedAmountCents'] as int,
                actualAmountCents: Value(i['actualAmountCents'] as int?),
                expectedDate: DateTime.parse(i['expectedDate'] as String),
                isRecurring: Value(i['isRecurring'] as bool? ?? false),
                isActive: Value(i['isActive'] as bool? ?? true),
              ));
        }

        for (final raw in (cycleJson['fixedExpenses'] as List? ?? const [])) {
          final e = raw as Map<String, dynamic>;
          await db.into(db.fixedExpenses).insert(FixedExpensesCompanion.insert(
                cycleId: cycleId,
                name: e['name'] as String,
                expectedAmountCents: e['expectedAmountCents'] as int,
                actualAmountCents: Value(e['actualAmountCents'] as int?),
                expectedDate: DateTime.parse(e['expectedDate'] as String),
                status: Value(e['status'] as String? ?? ChargeStatus.aVenir),
                categoryId: Value(categoryIdByName[e['categoryName']]),
                isRecurring: Value(e['isRecurring'] as bool? ?? false),
                isActive: Value(e['isActive'] as bool? ?? true),
              ));
        }

        for (final raw in (cycleJson['variableExpenses'] as List? ?? const [])) {
          final e = raw as Map<String, dynamic>;
          await db.into(db.variableExpenses).insert(VariableExpensesCompanion.insert(
                cycleId: cycleId,
                name: Value(e['name'] as String?),
                amountCents: e['amountCents'] as int,
                date: DateTime.parse(e['date'] as String),
                categoryId: Value(categoryIdByName[e['categoryName']]),
              ));
        }

        for (final raw in (cycleJson['savings'] as List? ?? const [])) {
          final s = raw as Map<String, dynamic>;
          await db.into(db.savings).insert(SavingsCompanion.insert(
                cycleId: cycleId,
                name: s['name'] as String,
                expectedAmountCents: s['expectedAmountCents'] as int,
                actualAmountCents: Value(s['actualAmountCents'] as int?),
                expectedDate: DateTime.parse(s['expectedDate'] as String),
                status: Value(s['status'] as String? ?? SavingStatus.prevu),
                isRecurring: Value(s['isRecurring'] as bool? ?? false),
                isActive: Value(s['isActive'] as bool? ?? true),
              ));
        }
      }

      return importedCycles;
    });
  }
}
