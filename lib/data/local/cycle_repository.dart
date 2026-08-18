import 'package:drift/drift.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/default_categories.dart';
import '../../domain/calculations/budget_calculation_service.dart';
import '../../domain/calculations/credit_auto_update_service.dart';
import '../../domain/calculations/cycle_close_service.dart';
import '../../domain/calculations/recurrence_calculator.dart';
import 'converters/entity_mappers.dart';
import 'database.dart';

/// Version du format de sauvegarde JSON (export/import). À incrémenter si
/// la structure change de façon incompatible.
const int backupFormatVersion = 1;

const _budgetCalculationService = BudgetCalculationService();
const _cycleCloseService = CycleCloseService();
const _recurrenceCalculator = RecurrenceCalculator();

/// Levée lorsqu'un fichier de sauvegarde ne correspond pas au format attendu.
/// Le message est destiné à être affiché directement à l'utilisateur.
class BackupValidationException implements Exception {
  final String message;
  const BackupValidationException(this.message);

  @override
  String toString() => message;
}

/// Levée par [CycleRepository.createCycle] quand un cycle 'ouvert' existe
/// déjà — impossible d'avoir deux cycles ouverts simultanément (finalisation
/// du moteur de cycle, §17). Le message est destiné à être affiché
/// directement à l'utilisateur.
class CycleAlreadyOpenException implements Exception {
  final String message;
  const CycleAlreadyOpenException(
      [this.message = 'Un cycle est déjà ouvert. Terminez-le avant d\'en créer un nouveau.']);

  @override
  String toString() => message;
}

/// Levée par [CycleRepository.closeCycle] quand le cycle visé n'existe pas
/// ou n'est plus ouvert (déjà clôturé) — jamais clôturé deux fois.
class CycleNotOpenException implements Exception {
  final String message;
  const CycleNotOpenException([this.message = 'Ce cycle est introuvable ou déjà clôturé.']);

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
          ..where((c) => c.status.equals(CycleStatus.ouvert))
          ..orderBy([(c) => OrderingTerm.desc(c.startDate)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<CycleDashboardRawData?> loadCurrentCycleData() async {
    final cycle = await _fetchCurrentCycle();
    if (cycle == null) return null;

    final incomes = await (db.select(db.incomes)..where((i) => i.cycleId.equals(cycle.id))).get();
    final fixedExpenses = await _fixedExpensesForCycle(cycle);
    final variableExpenses = await (db.select(db.variableExpenses)..where((e) => e.cycleId.equals(cycle.id))).get();
    final savings = await (db.select(db.savings)..where((s) => s.cycleId.equals(cycle.id))).get();

    return CycleDashboardRawData(
      cycle: cycle,
      incomes: incomes,
      fixedExpenses: fixedExpenses,
      variableExpenses: variableExpenses,
      savings: savings,
    );
  }

  /// Retour à la logique précédente (§ "Retour à la logique précédente des
  /// charges") : une charge fixe appartient au cycle [cycle] par son
  /// `cycleId` — jamais retirée du total simplement parce que sa date de
  /// prélèvement dépasse la fin du cycle (ex : EDF prélevée quelques jours
  /// après la clôture reste comptée dans le cycle qui l'a générée).
  /// `expectedDate` reste la source de vérité pour tout ce qui est
  /// chronologique — Aujourd'hui, Cette semaine, prochaines échéances, tri,
  /// notifications, statut — mais plus pour l'appartenance financière au
  /// cycle.
  Future<List<FixedExpense>> _fixedExpensesForCycle(BudgetCycle cycle) {
    return (db.select(db.fixedExpenses)..where((e) => e.cycleId.equals(cycle.id))).get();
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

  Future<List<BudgetCycle>> loadAllCycles() =>
      (db.select(db.budgetCycles)..orderBy([(c) => OrderingTerm.desc(c.startDate)])).get();

  /// Tous les cycles (courant compris), du plus récent au plus ancien.
  /// Basé sur `tableUpdates` plutôt que sur le `.watch()` natif d'une
  /// requête Drift (comme [watchCurrentCycleData]) : ce dernier programme
  /// un timer interne à la fermeture de l'abonnement qui reste "pending"
  /// tant qu'aucune frame supplémentaire n'est pompée — inoffensif en usage
  /// réel, mais fait échouer `testWidgets` (cf. correctif équivalent sur
  /// watchCredits()).
  Stream<List<BudgetCycle>> watchAllCycles() async* {
    yield await loadAllCycles();
    yield* db.tableUpdates(TableUpdateQuery.onAllTables([db.budgetCycles])).asyncMap((_) => loadAllCycles());
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
        for (final (name, type, icon) in all) CategoriesCompanion.insert(name: name, type: type, icon: Value(icon)),
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

  /// Crée un nouveau cycle. Impossible tant qu'un autre cycle est encore
  /// 'ouvert' (finalisation du moteur de cycle, §17) : lève
  /// [CycleAlreadyOpenException] plutôt que de créer un doublon silencieux.
  ///
  /// [copyRecurringFromCycleId], quand fourni (démarrage du cycle suivant
  /// après clôture), recopie dans le nouveau cycle les revenus, charges
  /// fixes et épargnes marqués récurrents et actifs de ce cycle précédent —
  /// jamais les entrées ponctuelles, jamais les dépenses variables (§5, §6,
  /// §8, §9). Toute l'opération est atomique : soit le cycle et toutes ses
  /// entrées recopiées existent, soit rien n'est créé (§18).
  Future<int> createCycle({
    required DateTime startDate,
    required DateTime endDate,
    String? name,
    int? declaredBankBalanceCents,
    int? copyRecurringFromCycleId,
  }) {
    return db.transaction(() async {
      final existingOpen = await _fetchCurrentCycle();
      if (existingOpen != null) {
        throw const CycleAlreadyOpenException();
      }

      await ensureDefaultCategories();
      final cycleId = await db.into(db.budgetCycles).insert(BudgetCyclesCompanion.insert(
            startDate: startDate,
            endDate: endDate,
            name: Value(name),
            declaredBankBalanceCents: Value(declaredBankBalanceCents),
          ));

      // Automatisation mensuelle (V0.9) : chaque nouveau cycle génère
      // automatiquement la charge mensuelle de tous les crédits actifs —
      // l'utilisateur ne recrée jamais une charge de crédit à la main. Les
      // crédits eux-mêmes ne sont jamais dupliqués ni décrémentés ici (§10) :
      // seule leur charge mensuelle est (re)générée pour ce nouveau cycle.
      final activeCredits = await (db.select(db.credits)..where((c) => c.isActive.equals(true))).get();
      for (final credit in activeCredits) {
        await _syncLinkedChargeForCycle(
          cycleId: cycleId,
          cycleStart: startDate,
          creditId: credit.id,
          name: credit.name,
          monthlyPaymentCents: credit.monthlyPaymentCents,
          paymentDayOfMonth: credit.paymentDayOfMonth,
        );
      }

      if (copyRecurringFromCycleId != null) {
        await _copyRecurringEntries(
          fromCycleId: copyRecurringFromCycleId,
          toCycleId: cycleId,
          toCycleStart: startDate,
          toCycleEnd: endDate,
        );
      }

      return cycleId;
    });
  }

  /// Recopie les revenus et épargnes marqués récurrents et actifs du cycle
  /// [fromCycleId] vers [toCycleId] (jamais les entrées ponctuelles, §5,
  /// §9 — comportement inchangé, une seule occurrence par cycle), et
  /// génère les occurrences de charges fixes récurrentes dont la date
  /// tombe réellement dans `[toCycleStart, toCycleEnd]` — jamais les
  /// charges désactivées, jamais celles liées à un crédit (déjà générées
  /// séparément). Correctif "échéances récurrentes hors cycle" : une charge
  /// n'appartient à un cycle que si sa date réelle y tombe, et un cycle
  /// peut légitimement recevoir zéro, une, ou plusieurs occurrences d'une
  /// même charge selon sa récurrence.
  Future<void> _copyRecurringEntries({
    required int fromCycleId,
    required int toCycleId,
    required DateTime toCycleStart,
    required DateTime toCycleEnd,
  }) async {
    final incomes = await (db.select(db.incomes)
          ..where((i) => i.cycleId.equals(fromCycleId) & i.isRecurring.equals(true) & i.isActive.equals(true)))
        .get();
    for (final income in incomes) {
      await db.into(db.incomes).insert(IncomesCompanion.insert(
            cycleId: toCycleId,
            name: income.name,
            expectedAmountCents: income.expectedAmountCents,
            expectedDate: _cycleCloseService.recurringEntryDateForNextCycle(income.expectedDate),
            categoryId: Value(income.categoryId),
            isRecurring: const Value(true),
          ));
    }

    await _generateFixedExpenseOccurrences(
      fromCycleId: fromCycleId,
      toCycleId: toCycleId,
      toCycleStart: toCycleStart,
      toCycleEnd: toCycleEnd,
    );
    await _promoteDeferredCharges(fromCycleId: fromCycleId, toCycleId: toCycleId);

    final savings = await (db.select(db.savings)
          ..where((s) => s.cycleId.equals(fromCycleId) & s.isRecurring.equals(true) & s.isActive.equals(true)))
        .get();
    for (final saving in savings) {
      await db.into(db.savings).insert(SavingsCompanion.insert(
            cycleId: toCycleId,
            name: saving.name,
            expectedAmountCents: saving.expectedAmountCents,
            expectedDate: _cycleCloseService.recurringEntryDateForNextCycle(saving.expectedDate),
            isRecurring: const Value(true),
          ));
    }
  }

  /// Génère, pour chaque modèle récurrent actif (globalement — pas
  /// seulement ceux ayant produit une occurrence dans [fromCycleId], sinon
  /// un cycle à zéro occurrence romprait la chaîne pour toujours, §
  /// "zéro occurrence dans un cycle" + "passage au cycle suivant"), toutes
  /// les occurrences dont la date tombe dans `[toCycleStart, toCycleEnd]` —
  /// jamais limité à une seule par cycle (§ "toutes les 4 semaines" peut
  /// produire 0, 1 ou 2 occurrences selon la période). Les charges
  /// récurrentes antérieures au correctif (sans modèle encore rattaché)
  /// reçoivent un modèle 'mensuel_jour_fixe' — leur comportement historique
  /// exact — au fil de l'eau, sans jamais nécessiter de ressaisie.
  Future<void> _generateFixedExpenseOccurrences({
    required int fromCycleId,
    required int toCycleId,
    required DateTime toCycleStart,
    required DateTime toCycleEnd,
  }) async {
    // Le backfill s'appuie volontairement sur `cycleId` (le cycle
    // d'origine de la charge, jamais modifié par une simple édition de
    // date) plutôt que sur sa date actuelle : ainsi, une charge héritée
    // dont la date a été déplacée manuellement avant la clôture de ce
    // cycle reçoit tout de même son modèle ici, avec sa date à jour comme
    // point de départ — jamais orpheline.
    final legacyRows = await (db.select(db.fixedExpenses)
          ..where((e) =>
              e.cycleId.equals(fromCycleId) &
              e.isRecurring.equals(true) &
              e.isActive.equals(true) &
              e.linkedCreditId.isNull() &
              e.templateId.isNull()))
        .get();
    for (final row in legacyRows) {
      final templateId = await _createTemplate(
        name: row.name,
        amountCents: row.expectedAmountCents,
        day: row.expectedDate.day,
        categoryId: row.categoryId,
        recurrenceType: RecurrenceType.mensuelJourFixe,
        intervalValue: null,
      );
      await (db.update(db.fixedExpenses)..where((e) => e.id.equals(row.id)))
          .write(FixedExpensesCompanion(templateId: Value(templateId)));
    }

    final activeTemplates = await (db.select(db.recurringTemplates)
          ..where((t) => t.type.equals(EntityType.fixedExpense) & t.isActive.equals(true)))
        .get();

    for (final template in activeTemplates) {
      final templateRows = await (db.select(db.fixedExpenses)..where((e) => e.templateId.equals(template.id))).get();
      if (templateRows.isEmpty) continue;
      final lastKnownDate = templateRows.map((r) => r.expectedDate).reduce((a, b) => a.isAfter(b) ? a : b);

      final occurrences = _recurrenceCalculator.occurrencesInRange(
        lastKnownDate: lastKnownDate,
        start: toCycleStart,
        end: toCycleEnd,
        recurrenceType: template.recurrenceType,
        intervalValue: template.intervalValue,
      );
      for (final date in occurrences) {
        await db.into(db.fixedExpenses).insert(FixedExpensesCompanion.insert(
              cycleId: toCycleId,
              templateId: Value(template.id),
              name: template.name,
              expectedAmountCents: template.defaultAmountCents,
              expectedDate: date,
              categoryId: Value(template.categoryId),
              isRecurring: const Value(true),
            ));
      }
    }
  }

  /// "Affectation manuelle d'une charge au prochain cycle", §6 : toute
  /// charge explicitement reportée (`deferredToNextCycle == true`) depuis
  /// [fromCycleId] est déplacée vers [toCycleId] (son vrai cycle
  /// budgétaire désormais) et le report est levé — elle redevient une
  /// charge "normale" du nouveau cycle, comptée dans son total. Sa date
  /// (`expectedDate`) n'est jamais modifiée ici. Indépendant de
  /// [_generateFixedExpenseOccurrences] : si le modèle récurrent de cette
  /// charge produit par ailleurs une nouvelle occurrence normale pour ce
  /// même cycle, les deux coexistent légitimement (§7, "prélèvement
  /// atypique") — jamais un doublon, ce sont deux échéances réellement
  /// distinctes (dates différentes).
  Future<void> _promoteDeferredCharges({required int fromCycleId, required int toCycleId}) async {
    final deferred = await (db.select(db.fixedExpenses)
          ..where((e) => e.cycleId.equals(fromCycleId) & e.deferredToNextCycle.equals(true)))
        .get();
    for (final charge in deferred) {
      await (db.update(db.fixedExpenses)..where((e) => e.id.equals(charge.id))).write(
        FixedExpensesCompanion(
          cycleId: Value(toCycleId),
          deferredToNextCycle: const Value(false),
        ),
      );
    }
  }

  /// Clôture le cycle [cycleId] : fige l'argent libre final (formule
  /// centrale `BudgetCalculationService.calculateRealRemaining`, jamais
  /// recalculée différemment) et passe son statut à 'ferme'. Ses revenus,
  /// charges, dépenses, épargnes et soldes restent inchangés pour toujours
  /// (§3) — cette méthode ne touche jamais que la ligne du cycle lui-même.
  /// Lève [CycleNotOpenException] si le cycle n'existe pas ou n'est plus
  /// ouvert (jamais clôturé deux fois).
  Future<void> closeCycle(int cycleId) {
    return db.transaction(() async {
      final cycle = await (db.select(db.budgetCycles)..where((c) => c.id.equals(cycleId))).getSingleOrNull();
      if (cycle == null || cycle.status != CycleStatus.ouvert) {
        throw const CycleNotOpenException();
      }

      final incomes = await (db.select(db.incomes)..where((i) => i.cycleId.equals(cycleId))).get();
      final fixedExpenses = await _fixedExpensesForCycle(cycle);
      final variableExpenses = await (db.select(db.variableExpenses)..where((e) => e.cycleId.equals(cycleId))).get();
      final savings = await (db.select(db.savings)..where((s) => s.cycleId.equals(cycleId))).get();

      // Une charge explicitement reportée au prochain cycle ne doit jamais
      // peser sur le solde figé de CE cycle (§ "Affectation manuelle d'une
      // charge au prochain cycle") — exactement le même filtre que l'argent
      // libre affiché en direct avant la clôture, pour qu'aucun écart
      // n'apparaisse entre le dernier chiffre vu par l'utilisateur et le
      // solde historisé.
      final cashFlowFixedExpenses = fixedExpenses.where((e) => !e.deferredToNextCycle).toList();

      final finalRemaining = _budgetCalculationService.calculateRealRemaining(
        incomes: incomes.map(incomeFromRow).toList(),
        fixedExpenses: cashFlowFixedExpenses.map(fixedExpenseFromRow).toList(),
        variableExpenses: variableExpenses.map(variableExpenseFromRow).toList(),
        savings: savings.map(savingFromRow).toList(),
        startingBalanceCents: cycle.declaredBankBalanceCents ?? 0,
      );

      await (db.update(db.budgetCycles)..where((c) => c.id.equals(cycleId))).write(BudgetCyclesCompanion(
        status: const Value(CycleStatus.ferme),
        closedAt: Value(DateTime.now()),
        finalRealRemainingCents: Value(finalRemaining),
      ));
    });
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

  /// [recurrenceType]/[recurrenceIntervalValue] ne s'appliquent que si
  /// [isRecurring] est vrai et la charge n'est pas liée à un crédit (les
  /// charges de crédit sont générées séparément, cf. [_syncLinkedChargeForCycle])
  /// : un modèle récurrent (`RecurringTemplates`) est alors créé, qui
  /// pilotera la génération des occurrences futures — correctif "échéances
  /// récurrentes hors cycle".
  Future<int> createFixedExpense({
    required int cycleId,
    required String name,
    required int expectedAmountCents,
    int? actualAmountCents,
    required DateTime expectedDate,
    int? categoryId,
    bool isRecurring = false,
    bool isActive = true,
    int? linkedCreditId,
    String recurrenceType = RecurrenceType.mensuelJourFixe,
    int? recurrenceIntervalValue,
  }) {
    return db.transaction(() async {
      int? templateId;
      if (isRecurring && isActive && linkedCreditId == null) {
        templateId = await _createTemplate(
          name: name,
          amountCents: expectedAmountCents,
          day: expectedDate.day,
          categoryId: categoryId,
          recurrenceType: recurrenceType,
          intervalValue: recurrenceIntervalValue,
        );
      }
      return db.into(db.fixedExpenses).insert(FixedExpensesCompanion.insert(
            cycleId: cycleId,
            templateId: Value(templateId),
            name: name,
            expectedAmountCents: expectedAmountCents,
            actualAmountCents: Value(actualAmountCents),
            expectedDate: expectedDate,
            categoryId: Value(categoryId),
            isRecurring: Value(isRecurring),
            isActive: Value(isActive),
            linkedCreditId: Value(linkedCreditId),
          ));
    });
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
    int? linkedCreditId,
    String recurrenceType = RecurrenceType.mensuelJourFixe,
    int? recurrenceIntervalValue,
  }) {
    return db.transaction(() async {
      final existing = await (db.select(db.fixedExpenses)..where((t) => t.id.equals(id))).getSingle();
      var templateId = existing.templateId;

      // Le modèle ne doit produire de nouvelles occurrences que si la
      // charge est À LA FOIS récurrente ET active ET non liée à un crédit —
      // `isRecurring` seul ne suffit pas : une charge récurrente désactivée
      // (ex : abonnement résilié) ne doit plus jamais être recopiée.
      //
      // Modifier une occurrence ne modifie JAMAIS silencieusement le reste
      // de la série (§ "ne jamais appliquer cela silencieusement") : seul
      // le type de récurrence / intervalle est propagé au modèle — c'est
      // une règle de calcul des occurrences FUTURES, pas une valeur propre
      // à cette échéance. Nom, montant, jour et catégorie du modèle ne sont
      // fixés qu'à sa création ; les modifier ici resterait local à cette
      // seule occurrence (`FixedExpensesCompanion` ci-dessous), jamais
      // propagé aux prochaines générations.
      if (isRecurring && isActive && linkedCreditId == null) {
        if (templateId == null) {
          templateId = await _createTemplate(
            name: name,
            amountCents: expectedAmountCents,
            day: expectedDate.day,
            categoryId: categoryId,
            recurrenceType: recurrenceType,
            intervalValue: recurrenceIntervalValue,
          );
        } else {
          final existingTemplateId = templateId;
          await (db.update(db.recurringTemplates)..where((t) => t.id.equals(existingTemplateId))).write(
            RecurringTemplatesCompanion(
              isActive: const Value(true),
              recurrenceType: Value(recurrenceType),
              intervalValue: Value(recurrenceIntervalValue),
              updatedAt: Value(DateTime.now()),
            ),
          );
        }
      } else if (templateId != null) {
        // Devenue ponctuelle, désactivée, ou liée à un crédit (généré
        // séparément) : le modèle ne doit plus produire de nouvelles
        // occurrences, mais reste conservé (jamais supprimé) — l'historique
        // qu'il a déjà généré ne change pas.
        final existingTemplateId = templateId;
        await (db.update(db.recurringTemplates)..where((t) => t.id.equals(existingTemplateId)))
            .write(const RecurringTemplatesCompanion(isActive: Value(false)));
      }

      await (db.update(db.fixedExpenses)..where((t) => t.id.equals(id))).write(FixedExpensesCompanion(
        templateId: Value(templateId),
        name: Value(name),
        expectedAmountCents: Value(expectedAmountCents),
        actualAmountCents: Value(actualAmountCents),
        expectedDate: Value(expectedDate),
        categoryId: Value(categoryId),
        isRecurring: Value(isRecurring),
        isActive: Value(isActive),
        linkedCreditId: Value(linkedCreditId),
      ));
    });
  }

  Future<void> deleteFixedExpense(int id) => (db.delete(db.fixedExpenses)..where((t) => t.id.equals(id))).go();

  // ---------------------------------------------------------------------
  // Affectation manuelle d'une charge au prochain cycle
  // ---------------------------------------------------------------------

  /// "Reporter au prochain cycle" : la charge [id] reste dans son cycle
  /// d'origine (`cycleId` inchangé) et sa date réelle de prélèvement
  /// (`expectedDate`) n'est jamais modifiée — seule son appartenance
  /// BUDGÉTAIRE change, donc elle cesse immédiatement de participer au
  /// total financier / à l'argent libre du cycle actuel (le flux réactif
  /// existant, `tableUpdates` sur `fixedExpenses`, recalcule tout sans
  /// redémarrage). Jamais supprimée, jamais dupliquée. Automatiquement
  /// recomptée dans le prochain cycle dès sa création (§6, cf.
  /// [_promoteDeferredCharges]), aux côtés d'une éventuelle nouvelle
  /// occurrence normale générée par la récurrence si les deux tombent
  /// réellement sur la même paie (§7).
  Future<void> deferFixedExpenseToNextCycle(int id) {
    return (db.update(db.fixedExpenses)..where((e) => e.id.equals(id)))
        .write(const FixedExpensesCompanion(deferredToNextCycle: Value(true)));
  }

  /// Action inverse : "Ramener au cycle actuel" — recomptée immédiatement
  /// dans le total du cycle qui la porte déjà (`cycleId` n'a jamais changé,
  /// donc aucune ligne à recréer ni à dupliquer).
  Future<void> bringFixedExpenseBackToCurrentCycle(int id) {
    return (db.update(db.fixedExpenses)..where((e) => e.id.equals(id)))
        .write(const FixedExpensesCompanion(deferredToNextCycle: Value(false)));
  }

  Future<int> _createTemplate({
    required String name,
    required int amountCents,
    required int day,
    int? categoryId,
    required String recurrenceType,
    int? intervalValue,
  }) {
    return db.into(db.recurringTemplates).insert(RecurringTemplatesCompanion.insert(
          type: EntityType.fixedExpense,
          name: name,
          defaultAmountCents: amountCents,
          defaultDay: day,
          categoryId: Value(categoryId),
          recurrenceType: Value(recurrenceType),
          intervalValue: Value(intervalValue),
        ));
  }

  Future<RecurringTemplate?> loadTemplate(int templateId) =>
      (db.select(db.recurringTemplates)..where((t) => t.id.equals(templateId))).getSingleOrNull();

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
    return (db.update(db.variableExpenses)..where((t) => t.id.equals(id))).write(VariableExpensesCompanion(
      name: Value(name),
      amountCents: Value(amountCents),
      date: Value(date),
      categoryId: Value(categoryId),
      updatedAt: Value(DateTime.now()),
    ));
  }

  Future<void> deleteVariableExpense(int id) => (db.delete(db.variableExpenses)..where((t) => t.id.equals(id))).go();

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
  // Préférences (thème)
  // ---------------------------------------------------------------------

  Future<String> _loadThemeMode() async {
    final row = await db.select(db.appSettingsTable).getSingleOrNull();
    return row?.themeMode ?? 'system';
  }

  /// Flux du thème choisi ('system' / 'light' / 'dark'), persisté en base
  /// pour survivre aux redémarrages et aux mises à jour de l'app.
  Stream<String> watchThemeMode() async* {
    yield await _loadThemeMode();
    yield* db.tableUpdates(TableUpdateQuery.onAllTables([db.appSettingsTable])).asyncMap((_) => _loadThemeMode());
  }

  Future<void> setThemeMode(String mode) async {
    final existing = await db.select(db.appSettingsTable).getSingleOrNull();
    if (existing == null) {
      await db.into(db.appSettingsTable).insert(AppSettingsTableCompanion.insert(
            themeMode: Value(mode),
          ));
    } else {
      await (db.update(db.appSettingsTable)..where((t) => t.id.equals(existing.id)))
          .write(AppSettingsTableCompanion(themeMode: Value(mode)));
    }
  }

  // ---------------------------------------------------------------------
  // Crédits — indépendants des cycles budgétaires.
  // ---------------------------------------------------------------------

  Future<List<Credit>> loadCredits() =>
      (db.select(db.credits)..orderBy([(c) => OrderingTerm.asc(c.expectedEndDate)])).get();

  /// Basé sur `tableUpdates` (comme [watchCurrentCycleData]) plutôt que sur
  /// le `.watch()` natif d'une requête Drift : ce dernier programme un
  /// timer interne à la fermeture de l'abonnement qui reste "pending" tant
  /// qu'aucune frame supplémentaire n'est pompée — inoffensif en usage réel,
  /// mais fait échouer `testWidgets` (qui exige qu'aucun timer ne traîne à
  /// la fin d'un test).
  Stream<List<Credit>> watchCredits() async* {
    yield await loadCredits();
    yield* db.tableUpdates(TableUpdateQuery.onAllTables([db.credits])).asyncMap((_) => loadCredits());
  }

  Future<int> createCredit({
    required String name,
    required int initialAmountCents,
    required int remainingCapitalCents,
    required int monthlyPaymentCents,
    double? annualRatePercent,
    DateTime? startDate,
    required DateTime expectedEndDate,
    required int remainingInstallments,
    String? creditType,
    bool earlyRepaymentAllowed = true,
    int? earlyRepaymentPenaltyCents,
    String? notes,
    String? organisme,
    int? colorValue,
    int? iconCodePoint,
    int? paymentDayOfMonth,
    int? insuranceCents,
  }) async {
    final id = await db.into(db.credits).insert(CreditsCompanion.insert(
          name: name,
          initialAmountCents: initialAmountCents,
          remainingCapitalCents: remainingCapitalCents,
          monthlyPaymentCents: monthlyPaymentCents,
          annualRatePercent: Value(annualRatePercent),
          startDate: Value(startDate),
          expectedEndDate: expectedEndDate,
          remainingInstallments: remainingInstallments,
          creditType: Value(creditType),
          earlyRepaymentAllowed: Value(earlyRepaymentAllowed),
          earlyRepaymentPenaltyCents: Value(earlyRepaymentPenaltyCents),
          notes: Value(notes),
          organisme: Value(organisme),
          colorValue: Value(colorValue),
          iconCodePoint: Value(iconCodePoint),
          paymentDayOfMonth: Value(paymentDayOfMonth),
          insuranceCents: Value(insuranceCents),
        ));

    // V0.9 : le crédit est la source de vérité — sa charge fixe mensuelle
    // est générée automatiquement, l'utilisateur ne la crée jamais.
    await _syncLinkedChargeForCurrentCycle(
      creditId: id,
      name: name,
      monthlyPaymentCents: monthlyPaymentCents,
      paymentDayOfMonth: paymentDayOfMonth,
    );

    return id;
  }

  Future<void> updateCredit({
    required int id,
    required String name,
    required int initialAmountCents,
    required int remainingCapitalCents,
    required int monthlyPaymentCents,
    double? annualRatePercent,
    DateTime? startDate,
    required DateTime expectedEndDate,
    required int remainingInstallments,
    String? creditType,
    required bool earlyRepaymentAllowed,
    int? earlyRepaymentPenaltyCents,
    String? notes,
    String? organisme,
    int? colorValue,
    int? iconCodePoint,
    int? paymentDayOfMonth,
    int? insuranceCents,
  }) async {
    await (db.update(db.credits)..where((t) => t.id.equals(id))).write(CreditsCompanion(
      name: Value(name),
      initialAmountCents: Value(initialAmountCents),
      remainingCapitalCents: Value(remainingCapitalCents),
      monthlyPaymentCents: Value(monthlyPaymentCents),
      annualRatePercent: Value(annualRatePercent),
      startDate: Value(startDate),
      expectedEndDate: Value(expectedEndDate),
      remainingInstallments: Value(remainingInstallments),
      creditType: Value(creditType),
      earlyRepaymentAllowed: Value(earlyRepaymentAllowed),
      earlyRepaymentPenaltyCents: Value(earlyRepaymentPenaltyCents),
      notes: Value(notes),
      organisme: Value(organisme),
      colorValue: Value(colorValue),
      iconCodePoint: Value(iconCodePoint),
      paymentDayOfMonth: Value(paymentDayOfMonth),
      insuranceCents: Value(insuranceCents),
      updatedAt: Value(DateTime.now()),
    ));

    // Si la mensualité (ou le jour de prélèvement) change, la charge liée
    // encore non confirmée se met à jour automatiquement — jamais celles
    // déjà prélevées (historique intact). Un crédit terminé n'a plus de
    // charge à générer.
    final updated = await (db.select(db.credits)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (updated != null && updated.isActive) {
      await _syncLinkedChargeForCurrentCycle(
        creditId: id,
        name: name,
        monthlyPaymentCents: monthlyPaymentCents,
        paymentDayOfMonth: paymentDayOfMonth,
      );
    }
  }

  /// Supprime le crédit et toutes ses charges liées (tous cycles confondus,
  /// y compris déjà confirmées) — "si un crédit est supprimé, sa charge
  /// disparaît automatiquement".
  Future<void> deleteCredit(int id) async {
    await (db.delete(db.fixedExpenses)..where((e) => e.linkedCreditId.equals(id))).go();
    await (db.delete(db.credits)..where((t) => t.id.equals(id))).go();
  }

  Future<void> setCreditActive(int id, bool isActive) async {
    await (db.update(db.credits)..where((t) => t.id.equals(id))).write(CreditsCompanion(
      isActive: Value(isActive),
      updatedAt: Value(DateTime.now()),
    ));

    if (!isActive) {
      // Crédit marqué terminé : ses charges pas encore confirmées n'ont
      // plus lieu d'être — jamais l'historique déjà prélevé/ignoré.
      await (db.delete(db.fixedExpenses)
            ..where((e) =>
                e.linkedCreditId.equals(id) &
                e.status.isIn([ChargeStatus.aVenir, ChargeStatus.aVerifierAujourdhui, ChargeStatus.aConfirmer])))
          .go();
    } else {
      final credit = await (db.select(db.credits)..where((t) => t.id.equals(id))).getSingleOrNull();
      if (credit != null) {
        await _syncLinkedChargeForCurrentCycle(
          creditId: id,
          name: credit.name,
          monthlyPaymentCents: credit.monthlyPaymentCents,
          paymentDayOfMonth: credit.paymentDayOfMonth,
        );
      }
    }
  }

  // ---------------------------------------------------------------------
  // Liaison automatique Charges ⇄ Crédits (V0.9)
  // ---------------------------------------------------------------------

  /// Crée ou met à jour, dans le cycle actuellement ouvert (s'il y en a
  /// un), la charge fixe générée automatiquement pour [creditId]. Ne crée
  /// jamais de doublon : une charge déjà liée à ce crédit dans ce cycle est
  /// mise à jour plutôt que dupliquée, et une charge déjà confirmée n'est
  /// jamais réécrite.
  Future<void> _syncLinkedChargeForCurrentCycle({
    required int creditId,
    required String name,
    required int monthlyPaymentCents,
    int? paymentDayOfMonth,
  }) async {
    final cycle = await _fetchCurrentCycle();
    if (cycle == null) return;
    await _syncLinkedChargeForCycle(
      cycleId: cycle.id,
      cycleStart: cycle.startDate,
      creditId: creditId,
      name: name,
      monthlyPaymentCents: monthlyPaymentCents,
      paymentDayOfMonth: paymentDayOfMonth,
    );
  }

  Future<void> _syncLinkedChargeForCycle({
    required int cycleId,
    required DateTime cycleStart,
    required int creditId,
    required String name,
    required int monthlyPaymentCents,
    int? paymentDayOfMonth,
  }) async {
    // Normalement une seule ligne par crédit et par cycle — mais un report
    // (§ "Affectation manuelle d'une charge au prochain cycle") peut
    // légitimement en promouvoir une seconde, historique, dans ce même
    // cycle (§7, "prélèvement atypique") : `getSingleOrNull` planterait
    // alors. On ne synchronise jamais la ligne reportée (gelée
    // intentionnellement, cf. [deferFixedExpenseToNextCycle]) — uniquement
    // l'échéance normale du cycle, s'il y en a une.
    final matches = await (db.select(db.fixedExpenses)
          ..where((e) => e.cycleId.equals(cycleId) & e.linkedCreditId.equals(creditId)))
        .get();
    final syncable = matches.where((e) => !e.deferredToNextCycle).toList();
    final existing = syncable.isNotEmpty ? syncable.first : null;

    final expectedDate = _paymentDateForCycle(cycleStart, paymentDayOfMonth);

    if (existing == null) {
      await ensureDefaultCategories();
      final creditCategoryId = await _creditCategoryId();
      await db.into(db.fixedExpenses).insert(FixedExpensesCompanion.insert(
            cycleId: cycleId,
            name: name,
            expectedAmountCents: monthlyPaymentCents,
            expectedDate: expectedDate,
            categoryId: Value(creditCategoryId),
            linkedCreditId: Value(creditId),
          ));
    } else if (existing.status != ChargeStatus.prelevee) {
      await (db.update(db.fixedExpenses)..where((e) => e.id.equals(existing.id))).write(
        FixedExpensesCompanion(
          name: Value(name),
          expectedAmountCents: Value(monthlyPaymentCents),
          expectedDate: Value(expectedDate),
        ),
      );
    }
  }

  Future<int?> _creditCategoryId() async {
    final category = await (db.select(db.categories)
          ..where((c) => c.name.equals('Crédit') & c.type.equals(EntityType.fixedExpense)))
        .getSingleOrNull();
    return category?.id;
  }

  DateTime _paymentDateForCycle(DateTime cycleStart, int? paymentDayOfMonth) {
    if (paymentDayOfMonth == null) return cycleStart;
    final year = cycleStart.year;
    final month = cycleStart.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final day = paymentDayOfMonth.clamp(1, daysInMonth);
    return DateTime(year, month, day);
  }

  // ---------------------------------------------------------------------
  // Liaison inverse Crédits ⇄ Charges (V0.9.1) — une charge fixe de
  // catégorie "Crédit" ne doit jamais rester une charge isolée : elle doit
  // toujours être reliée à un crédit existant ou en déclencher la création.
  // ---------------------------------------------------------------------

  /// Cherche un unique crédit actif dont le nom correspond exactement (une
  /// fois normalisé) à [name] et qui n'a pas déjà de charge liée dans le
  /// cycle [cycleId] (hors [excludeChargeId], la charge en cours
  /// d'édition) — pour ne jamais créer une deuxième mensualité du même
  /// crédit dans le même cycle. Renvoie `null` si aucune correspondance
  /// fiable n'existe (aucune, ou plusieurs crédits du même nom).
  Future<Credit?> findLinkableCreditForCharge({
    required String name,
    required int cycleId,
    int? excludeChargeId,
  }) async {
    final normalized = name.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    final credits = await (db.select(db.credits)..where((c) => c.isActive.equals(true))).get();
    final matches = credits.where((c) => c.name.trim().toLowerCase() == normalized).toList();
    if (matches.length != 1) return null;
    final candidate = matches.first;

    final chargesInCycle = await (db.select(db.fixedExpenses)..where((e) => e.cycleId.equals(cycleId))).get();
    final alreadyLinkedElsewhere =
        chargesInCycle.any((e) => e.linkedCreditId == candidate.id && e.id != excludeChargeId);
    return alreadyLinkedElsewhere ? null : candidate;
  }

  /// Crée un crédit à partir d'une charge fixe déjà existante (ou en cours
  /// de création) — contrairement à [createCredit], ne génère jamais de
  /// charge : l'appelant relie explicitement sa charge (déjà là) via
  /// `linkedCreditId` après l'appel.
  Future<int> createCreditForExistingCharge({
    required String name,
    required int initialAmountCents,
    required int remainingCapitalCents,
    required int monthlyPaymentCents,
    double? annualRatePercent,
    String? organisme,
    required DateTime expectedEndDate,
    required int remainingInstallments,
    int? paymentDayOfMonth,
  }) {
    return db.into(db.credits).insert(CreditsCompanion.insert(
          name: name,
          initialAmountCents: initialAmountCents,
          remainingCapitalCents: remainingCapitalCents,
          monthlyPaymentCents: monthlyPaymentCents,
          annualRatePercent: Value(annualRatePercent),
          organisme: Value(organisme),
          expectedEndDate: expectedEndDate,
          remainingInstallments: remainingInstallments,
          paymentDayOfMonth: Value(paymentDayOfMonth),
        ));
  }

  /// Synchronise sur le crédit lié les champs qui appartiennent à la charge
  /// fixe — nom, mensualité, jour de prélèvement, actif/inactif — chaque
  /// fois que la charge est enregistrée. Ne touche jamais le capital, le
  /// taux ou les autres champs propres au crédit.
  Future<void> syncCreditFromCharge({
    required int creditId,
    required String name,
    required int monthlyPaymentCents,
    required int paymentDayOfMonth,
    required bool isActive,
  }) {
    return (db.update(db.credits)..where((c) => c.id.equals(creditId))).write(CreditsCompanion(
      name: Value(name),
      monthlyPaymentCents: Value(monthlyPaymentCents),
      paymentDayOfMonth: Value(paymentDayOfMonth),
      isActive: Value(isActive),
      updatedAt: Value(DateTime.now()),
    ));
  }

  /// Charges fixes de catégorie "Crédit" sans crédit lié — cas hérité
  /// (migration sans correspondance fiable) ou incohérence à corriger.
  /// Jamais de doublon créé automatiquement : ces charges restent visibles
  /// dans la section "Crédits à compléter" jusqu'à ce que l'utilisateur les
  /// relie ou complète manuellement.
  Future<List<FixedExpense>> loadUnlinkedCreditCharges() async {
    final creditCategoryId = await _creditCategoryId();
    if (creditCategoryId == null) return const [];
    return (db.select(db.fixedExpenses)
          ..where((e) => e.categoryId.equals(creditCategoryId) & e.linkedCreditId.isNull()))
        .get();
  }

  Stream<List<FixedExpense>> watchUnlinkedCreditCharges() async* {
    yield await loadUnlinkedCreditCharges();
    yield* db
        .tableUpdates(TableUpdateQuery.onAllTables([db.fixedExpenses, db.categories]))
        .asyncMap((_) => loadUnlinkedCreditCharges());
  }

  // ---------------------------------------------------------------------
  // Confirmations du jour (V0.9) — Confirmer / Modifier / Reporter / Ignorer
  // ---------------------------------------------------------------------

  /// Confirme une charge fixe (statut "prelevee"), avec un montant réel
  /// facultatif. Si la charge est liée à un crédit, décrémente
  /// automatiquement son capital et ses mensualités restantes avec le
  /// montant réellement confirmé — sans aucune intervention utilisateur
  /// supplémentaire. Renvoie le résultat de la mise à jour du crédit
  /// lorsqu'il y en a une (`null` sinon), pour permettre à l'appelant de
  /// déclencher la notification appropriée.
  ///
  /// Idempotent : une charge déjà "prelevee" ne réapplique jamais son
  /// paiement au crédit lié (protège contre un double appel, par exemple
  /// une action de notification traitée deux fois).
  Future<CreditAutoUpdateResult?> confirmFixedExpense(int chargeId, {int? actualAmountCents}) async {
    final charge = await (db.select(db.fixedExpenses)..where((e) => e.id.equals(chargeId))).getSingleOrNull();
    if (charge == null) return null;
    if (charge.status == ChargeStatus.prelevee) return null;

    await (db.update(db.fixedExpenses)..where((e) => e.id.equals(chargeId))).write(
      FixedExpensesCompanion(
        status: const Value(ChargeStatus.prelevee),
        actualAmountCents: actualAmountCents == null ? const Value.absent() : Value(actualAmountCents),
      ),
    );

    final linkedCreditId = charge.linkedCreditId;
    if (linkedCreditId == null) return null;

    final creditRow = await (db.select(db.credits)..where((c) => c.id.equals(linkedCreditId))).getSingleOrNull();
    if (creditRow == null) return null;

    final paidCents = actualAmountCents ?? charge.actualAmountCents ?? charge.expectedAmountCents;
    final credit = creditFromRow(creditRow);
    final updated = const CreditAutoUpdateService().applyPayment(credit, paidCents);
    final finished = updated.remainingCapitalCents <= 0 || updated.remainingInstallments <= 0;

    await updateCredit(
      id: updated.id,
      name: updated.name,
      initialAmountCents: updated.initialAmountCents,
      remainingCapitalCents: updated.remainingCapitalCents,
      monthlyPaymentCents: updated.monthlyPaymentCents,
      annualRatePercent: updated.annualRatePercent,
      startDate: updated.startDate,
      expectedEndDate: updated.expectedEndDate,
      remainingInstallments: updated.remainingInstallments,
      creditType: updated.creditType,
      earlyRepaymentAllowed: updated.earlyRepaymentAllowed,
      earlyRepaymentPenaltyCents: updated.earlyRepaymentPenaltyCents,
      notes: updated.notes,
      organisme: updated.organisme,
      colorValue: updated.colorValue,
      iconCodePoint: updated.iconCodePoint,
      paymentDayOfMonth: updated.paymentDayOfMonth,
      insuranceCents: updated.insuranceCents,
    );

    if (finished) {
      await setCreditActive(updated.id, false);
    }

    return CreditAutoUpdateResult(credit: updated, finished: finished);
  }

  /// Reporte une charge fixe de [by] (par défaut un jour) — action "⏰
  /// Reporter" du centre de confirmations.
  Future<void> postponeFixedExpense(int id, {Duration by = const Duration(days: 1)}) async {
    final charge = await (db.select(db.fixedExpenses)..where((e) => e.id.equals(id))).getSingleOrNull();
    if (charge == null) return;
    await (db.update(db.fixedExpenses)..where((e) => e.id.equals(id)))
        .write(FixedExpensesCompanion(expectedDate: Value(charge.expectedDate.add(by))));
  }

  // ---------------------------------------------------------------------
  // Notifications locales (V0.9) — historique persistant, indépendant de la
  // permission système et du bandeau Android (non relisible par l'app).
  // ---------------------------------------------------------------------

  Future<int> logNotification({
    required String type,
    required String title,
    required String body,
    int? relatedFixedExpenseId,
    int? relatedCreditId,
  }) {
    return db.into(db.notificationLogs).insert(NotificationLogsCompanion.insert(
          type: type,
          title: title,
          body: body,
          relatedFixedExpenseId: Value(relatedFixedExpenseId),
          relatedCreditId: Value(relatedCreditId),
        ));
  }

  Future<List<NotificationLog>> loadNotificationLogs() =>
      // Trié par id (et non par date) : plus fiable pour deux notifications
      // journalisées dans le même intervalle de résolution de l'horloge.
      (db.select(db.notificationLogs)..orderBy([(n) => OrderingTerm.desc(n.id)])).get();

  Stream<List<NotificationLog>> watchNotificationLogs() async* {
    yield await loadNotificationLogs();
    yield* db.tableUpdates(TableUpdateQuery.onAllTables([db.notificationLogs])).asyncMap((_) => loadNotificationLogs());
  }

  Future<void> markNotificationRead(int id) {
    return (db.update(db.notificationLogs)..where((n) => n.id.equals(id)))
        .write(const NotificationLogsCompanion(read: Value(true)));
  }

  // ---------------------------------------------------------------------
  // Projets (V1.0 — Project Planner) — indépendants des cycles budgétaires,
  // comme les crédits. Seuls les INPUTS sont persistés ici ; le score de
  // faisabilité et la trajectoire sont toujours recalculés à la volée par
  // ProjectFeasibilityService, jamais stockés (évite toute donnée obsolète).
  // ---------------------------------------------------------------------

  Future<int> createProject({
    required String name,
    required String category,
    required int targetAmountCents,
    DateTime? desiredDate,
    int availableContributionCents = 0,
    int? desiredContributionCents,
    required String financingMode,
    int? maxMonthlyPaymentCents,
    int? desiredDurationMonths,
    double? estimatedRatePercent,
    int? extraMonthlyCostCents,
    String? notes,
    String priority = ProjectPriority.medium,
  }) {
    return db.into(db.projects).insert(ProjectsCompanion.insert(
          name: name,
          category: category,
          targetAmountCents: targetAmountCents,
          desiredDate: Value(desiredDate),
          availableContributionCents: Value(availableContributionCents),
          desiredContributionCents: Value(desiredContributionCents),
          financingMode: financingMode,
          maxMonthlyPaymentCents: Value(maxMonthlyPaymentCents),
          desiredDurationMonths: Value(desiredDurationMonths),
          estimatedRatePercent: Value(estimatedRatePercent),
          extraMonthlyCostCents: Value(extraMonthlyCostCents),
          notes: Value(notes),
          priority: Value(priority),
        ));
  }

  Future<void> updateProject({
    required int id,
    required String name,
    required String category,
    required int targetAmountCents,
    DateTime? desiredDate,
    required int availableContributionCents,
    int? desiredContributionCents,
    required String financingMode,
    int? maxMonthlyPaymentCents,
    int? desiredDurationMonths,
    double? estimatedRatePercent,
    int? extraMonthlyCostCents,
    String? notes,
    String priority = ProjectPriority.medium,
  }) {
    return (db.update(db.projects)..where((t) => t.id.equals(id))).write(ProjectsCompanion(
      name: Value(name),
      category: Value(category),
      targetAmountCents: Value(targetAmountCents),
      desiredDate: Value(desiredDate),
      availableContributionCents: Value(availableContributionCents),
      desiredContributionCents: Value(desiredContributionCents),
      financingMode: Value(financingMode),
      maxMonthlyPaymentCents: Value(maxMonthlyPaymentCents),
      desiredDurationMonths: Value(desiredDurationMonths),
      estimatedRatePercent: Value(estimatedRatePercent),
      extraMonthlyCostCents: Value(extraMonthlyCostCents),
      notes: Value(notes),
      priority: Value(priority),
      updatedAt: Value(DateTime.now()),
    ));
  }

  /// Archive (ou réactive) un projet — jamais supprimé par cette action,
  /// contrairement à [deleteProject].
  Future<void> setProjectActive(int id, bool isActive) {
    return (db.update(db.projects)..where((t) => t.id.equals(id))).write(ProjectsCompanion(
      isActive: Value(isActive),
      updatedAt: Value(DateTime.now()),
    ));
  }

  Future<void> deleteProject(int id) => (db.delete(db.projects)..where((t) => t.id.equals(id))).go();

  /// Duplique un projet (V1.1, §1) : même saisie, nouveau projet
  /// indépendant, toujours actif — jamais un simple lien vers l'original.
  Future<int> duplicateProject(int id) async {
    final original = await (db.select(db.projects)..where((t) => t.id.equals(id))).getSingle();
    return db.into(db.projects).insert(ProjectsCompanion.insert(
          name: '${original.name} (copie)',
          category: original.category,
          targetAmountCents: original.targetAmountCents,
          desiredDate: Value(original.desiredDate),
          availableContributionCents: Value(original.availableContributionCents),
          desiredContributionCents: Value(original.desiredContributionCents),
          financingMode: original.financingMode,
          maxMonthlyPaymentCents: Value(original.maxMonthlyPaymentCents),
          desiredDurationMonths: Value(original.desiredDurationMonths),
          estimatedRatePercent: Value(original.estimatedRatePercent),
          extraMonthlyCostCents: Value(original.extraMonthlyCostCents),
          notes: Value(original.notes),
          priority: Value(original.priority),
        ));
  }

  Future<List<Project>> loadProjects() =>
      (db.select(db.projects)..orderBy([(p) => OrderingTerm.desc(p.createdAt)])).get();

  /// Basé sur `tableUpdates` (comme [watchCredits]) plutôt que sur le
  /// `.watch()` natif d'une requête Drift — voir le commentaire de
  /// [watchCredits] pour la raison (timer interne qui bloque les tests).
  Stream<List<Project>> watchProjects() async* {
    yield await loadProjects();
    yield* db.tableUpdates(TableUpdateQuery.onAllTables([db.projects])).asyncMap((_) => loadProjects());
  }

  // ---------------------------------------------------------------------
  // Repartir de zéro (Paramètres > Données)
  // ---------------------------------------------------------------------

  /// Supprime toutes les données financières de l'utilisateur — cycles,
  /// revenus, charges, dépenses, épargnes, crédits, projets, ainsi que
  /// l'historique de notifications/confirmations qui leur est associé — pour
  /// revenir exactement à l'état du tout premier lancement de BudgetPilot.
  ///
  /// Conserve toujours : les préférences d'apparence/langue/paramètres
  /// généraux (`AppSettingsTable` — thème, devise, cycle de prélèvement,
  /// notifications...) et la taxonomie de catégories (`Categories`), qui ne
  /// sont pas des données financières saisies par l'utilisateur mais de la
  /// configuration de l'application.
  ///
  /// Tout est supprimé dans une seule transaction — soit tout disparaît,
  /// soit rien ne change. L'ordre de suppression respecte les dépendances
  /// entre tables (une table n'est vidée qu'après celles qui la référencent).
  Future<void> resetAllUserData() {
    return db.transaction(() async {
      await db.delete(db.notificationLogs).go();
      await db.delete(db.variableExpenses).go();
      await db.delete(db.savings).go();
      await db.delete(db.fixedExpenses).go();
      await db.delete(db.incomes).go();
      await db.delete(db.projects).go();
      await db.delete(db.credits).go();
      await db.delete(db.budgetCycles).go();
      await db.delete(db.recurringTemplates).go();
    });
  }

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
      final fixedExpenses = await (db.select(db.fixedExpenses)..where((e) => e.cycleId.equals(cycle.id))).get();
      final variableExpenses = await (db.select(db.variableExpenses)..where((e) => e.cycleId.equals(cycle.id))).get();
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

    final credits = await db.select(db.credits).get();

    return {
      'formatVersion': backupFormatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'cycles': cycleMaps,
      // Champ additif : absent dans les sauvegardes antérieures à la V0.7,
      // toujours traité comme une liste vide à l'import dans ce cas — la
      // version du format n'a pas besoin de changer.
      'credits': [
        for (final c in credits)
          {
            'name': c.name,
            'initialAmountCents': c.initialAmountCents,
            'remainingCapitalCents': c.remainingCapitalCents,
            'monthlyPaymentCents': c.monthlyPaymentCents,
            'annualRatePercent': c.annualRatePercent,
            'startDate': c.startDate?.toIso8601String(),
            'expectedEndDate': c.expectedEndDate.toIso8601String(),
            'remainingInstallments': c.remainingInstallments,
            'creditType': c.creditType,
            'earlyRepaymentAllowed': c.earlyRepaymentAllowed,
            'earlyRepaymentPenaltyCents': c.earlyRepaymentPenaltyCents,
            'notes': c.notes,
            'isActive': c.isActive,
            'organisme': c.organisme,
            'colorValue': c.colorValue,
            'iconCodePoint': c.iconCodePoint,
            'paymentDayOfMonth': c.paymentDayOfMonth,
            'insuranceCents': c.insuranceCents,
          },
      ],
    };
  }

  /// Vérifie qu'une structure JSON décodée correspond bien au format de
  /// sauvegarde attendu, avant toute écriture en base. Lève
  /// [BackupValidationException] (message affichable) si le fichier est
  /// invalide, d'une version non prise en charge, ou incomplet.
  void validateBackup(Object? decoded) {
    if (decoded is! Map || decoded['cycles'] == null) {
      throw const BackupValidationException("Ce fichier n'est pas une sauvegarde BudgetPilot valide.");
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
        await db.delete(db.credits).go();
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

      // Absent dans les sauvegardes antérieures à la V0.7 : traité comme une
      // liste vide, sans erreur — compatibilité ascendante garantie.
      for (final raw in (data['credits'] as List? ?? const [])) {
        final c = raw as Map<String, dynamic>;
        await db.into(db.credits).insert(CreditsCompanion.insert(
              name: c['name'] as String,
              initialAmountCents: c['initialAmountCents'] as int,
              remainingCapitalCents: c['remainingCapitalCents'] as int,
              monthlyPaymentCents: c['monthlyPaymentCents'] as int,
              annualRatePercent: Value((c['annualRatePercent'] as num?)?.toDouble()),
              startDate: Value(c['startDate'] == null ? null : DateTime.parse(c['startDate'] as String)),
              expectedEndDate: DateTime.parse(c['expectedEndDate'] as String),
              remainingInstallments: c['remainingInstallments'] as int,
              creditType: Value(c['creditType'] as String?),
              earlyRepaymentAllowed: Value(c['earlyRepaymentAllowed'] as bool? ?? true),
              earlyRepaymentPenaltyCents: Value(c['earlyRepaymentPenaltyCents'] as int?),
              notes: Value(c['notes'] as String?),
              isActive: Value(c['isActive'] as bool? ?? true),
              // Absents dans les sauvegardes antérieures à cette version :
              // toujours `null` par défaut, sans erreur.
              organisme: Value(c['organisme'] as String?),
              colorValue: Value(c['colorValue'] as int?),
              iconCodePoint: Value(c['iconCodePoint'] as int?),
              paymentDayOfMonth: Value(c['paymentDayOfMonth'] as int?),
              insuranceCents: Value(c['insuranceCents'] as int?),
            ));
      }

      // Relie les charges "Crédit" importées aux crédits importés par nom
      // — les identifiants internes changent à l'import, donc jamais
      // exportés/réimportés tels quels ; cette réconciliation est la même
      // que celle exécutée lors de la migration V0.9 (voir database.dart).
      await reconcileCreditLinkedCharges(db);

      return importedCycles;
    });
  }
}
