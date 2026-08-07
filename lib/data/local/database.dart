import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

// Cible Android uniquement pour la V1. NativeDatabase repose sur dart:io et
// ne fonctionne pas sur le Web — un support Web viendra plus tard avec une
// ouverture de base différente (drift + sqlite3 wasm), pas ce fichier.

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get type => text()();
  TextColumn get icon => text().withDefault(const Constant('category'))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

class RecurringTemplates extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => text()();
  TextColumn get name => text()();
  IntColumn get defaultAmountCents => integer()();
  IntColumn get defaultDay => integer()();
  IntColumn get categoryId => integer().nullable().references(Categories, #id)();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class BudgetCycles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().nullable()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime()();
  TextColumn get status => text().withDefault(const Constant('ouvert'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get closedAt => dateTime().nullable()();
  IntColumn get declaredBankBalanceCents => integer().nullable()();
  IntColumn get finalRealRemainingCents => integer().nullable()();
  TextColumn get notes => text().nullable()();
}

class Incomes extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get cycleId => integer().references(BudgetCycles, #id)();
  IntColumn get templateId => integer().nullable().references(RecurringTemplates, #id)();
  TextColumn get name => text()();
  IntColumn get expectedAmountCents => integer()();
  IntColumn get actualAmountCents => integer().nullable()();
  DateTimeColumn get expectedDate => dateTime()();
  TextColumn get status => text().withDefault(const Constant('prevu'))();
  IntColumn get categoryId => integer().nullable().references(Categories, #id)();
  BoolColumn get isRecurring => boolean().withDefault(const Constant(false))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get notes => text().nullable()();
}

class FixedExpenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get cycleId => integer().references(BudgetCycles, #id)();
  IntColumn get templateId => integer().nullable().references(RecurringTemplates, #id)();
  TextColumn get name => text()();
  IntColumn get expectedAmountCents => integer()();
  IntColumn get actualAmountCents => integer().nullable()();
  DateTimeColumn get expectedDate => dateTime()();
  TextColumn get status => text().withDefault(const Constant('a_venir'))();
  IntColumn get categoryId => integer().nullable().references(Categories, #id)();
  BoolColumn get isRecurring => boolean().withDefault(const Constant(false))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get notes => text().nullable()();

  /// Crédit dont cette charge est la mensualité générée automatiquement —
  /// `null` pour une charge fixe "normale" saisie manuellement. Le crédit
  /// est la source de vérité : cette charge n'est jamais créée à la main
  /// par l'utilisateur quand elle est liée.
  IntColumn get linkedCreditId => integer().nullable().references(Credits, #id)();
}

class VariableExpenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get cycleId => integer().references(BudgetCycles, #id)();
  TextColumn get name => text().nullable()();
  IntColumn get amountCents => integer()();
  DateTimeColumn get date => dateTime()();
  IntColumn get categoryId => integer().nullable().references(Categories, #id)();
  TextColumn get paymentMethod => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class Savings extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get cycleId => integer().references(BudgetCycles, #id)();
  IntColumn get templateId => integer().nullable().references(RecurringTemplates, #id)();
  TextColumn get name => text()();
  IntColumn get expectedAmountCents => integer()();
  IntColumn get actualAmountCents => integer().nullable()();
  DateTimeColumn get expectedDate => dateTime()();
  TextColumn get status => text().withDefault(const Constant('prevu'))();
  BoolColumn get isRecurring => boolean().withDefault(const Constant(false))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get notes => text().nullable()();
}

class AppSettingsTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get currency => text().withDefault(const Constant('EUR'))();
  TextColumn get locale => text().withDefault(const Constant('fr_FR'))();
  IntColumn get cycleStartDay => integer().withDefault(const Constant(27))();
  TextColumn get notificationTime => text().withDefault(const Constant('09:00'))();
  BoolColumn get notificationsEnabled => boolean().withDefault(const Constant(true))();
  TextColumn get themeMode => text().withDefault(const Constant('system'))();
  BoolColumn get biometricEnabled => boolean().withDefault(const Constant(false))();
}

/// Crédits en cours — indépendants des cycles budgétaires (un prêt ne se
/// réinitialise pas à chaque cycle, contrairement aux revenus/charges).
class Credits extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get initialAmountCents => integer()();
  IntColumn get remainingCapitalCents => integer()();
  IntColumn get monthlyPaymentCents => integer()();
  RealColumn get annualRatePercent => real().nullable()();
  DateTimeColumn get startDate => dateTime().nullable()();
  DateTimeColumn get expectedEndDate => dateTime()();
  IntColumn get remainingInstallments => integer()();
  TextColumn get creditType => text().nullable()();
  BoolColumn get earlyRepaymentAllowed => boolean().withDefault(const Constant(true))();
  IntColumn get earlyRepaymentPenaltyCents => integer().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  /// Nom de la banque / de l'organisme prêteur — purement informatif.
  TextColumn get organisme => text().nullable()();

  /// Couleur d'accent choisie par l'utilisateur (ARGB), parmi une palette
  /// prédéfinie — `null` utilise la couleur crédit par défaut du thème.
  IntColumn get colorValue => integer().nullable()();

  /// `codePoint` d'une icône choisie parmi une palette prédéfinie — `null`
  /// utilise l'icône par défaut. Toujours résolu contre une liste fermée
  /// d'IconData référencées en `const` ailleurs dans l'app, pour rester
  /// compatible avec le tree-shaking des icônes en build release.
  IntColumn get iconCodePoint => integer().nullable()();

  /// Jour du mois du prélèvement (1-31, facultatif) — utilisé pour dater la
  /// charge fixe générée automatiquement chaque cycle.
  IntColumn get paymentDayOfMonth => integer().nullable()();

  /// Assurance mensuelle éventuelle, en centimes — purement informatif,
  /// jamais ajoutée automatiquement à la mensualité de la charge générée.
  IntColumn get insuranceCents => integer().nullable()();
}

/// Historique des notifications déclenchées par [NotificationService] — la
/// tentative d'affichage système (bandeau Android) n'est pas garantie ni
/// relisible par l'app ; cette table est la source de vérité affichée dans
/// le centre de notifications, indépendamment de la permission système.
class NotificationLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => text()();
  TextColumn get title => text()();
  TextColumn get body => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get read => boolean().withDefault(const Constant(false))();

  /// Charge ou crédit concerné, purement informatif (facultatif).
  IntColumn get relatedFixedExpenseId => integer().nullable().references(FixedExpenses, #id)();
  IntColumn get relatedCreditId => integer().nullable().references(Credits, #id)();
}

/// Projets (V1.0 — Project Planner) : "puis-je réellement réaliser ce
/// projet ?". Cette table ne stocke que les INPUTS saisis par l'utilisateur
/// — jamais un score ou une faisabilité calculée, toujours recalculée à la
/// volée par `ProjectFeasibilityService` à partir des données financières
/// courantes (revenus, charges, crédits), pour ne jamais afficher un
/// résultat obsolète.
class Projects extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get category => text()();
  IntColumn get targetAmountCents => integer()();
  DateTimeColumn get desiredDate => dateTime().nullable()();
  IntColumn get availableContributionCents => integer().withDefault(const Constant(0))();
  IntColumn get desiredContributionCents => integer().nullable()();
  TextColumn get financingMode => text()();
  IntColumn get maxMonthlyPaymentCents => integer().nullable()();
  IntColumn get desiredDurationMonths => integer().nullable()();
  RealColumn get estimatedRatePercent => real().nullable()();
  IntColumn get extraMonthlyCostCents => integer().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [
  Categories,
  RecurringTemplates,
  BudgetCycles,
  Incomes,
  FixedExpenses,
  VariableExpenses,
  Savings,
  AppSettingsTable,
  Credits,
  NotificationLogs,
  Projects,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Utilisé par les tests pour injecter une base en mémoire.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(budgetCycles, budgetCycles.name);
          }
          // `createTable` matérialise la table telle que définie par la
          // classe Dart *actuelle* — donc déjà avec organisme/colorValue/
          // iconCodePoint/paymentDayOfMonth/insuranceCents si `credits`
          // n'existait pas encore. Les `addColumn` des branches v4/v5 ne
          // doivent s'appliquer qu'aux bases où la table `credits` existait
          // déjà ; sinon ces colonnes existent déjà et `addColumn`
          // échouerait (doublon).
          final createdCreditsTable = from < 3;
          if (createdCreditsTable) {
            await m.createTable(credits);
          }
          if (from < 4 && !createdCreditsTable) {
            await m.addColumn(credits, credits.organisme);
            await m.addColumn(credits, credits.colorValue);
            await m.addColumn(credits, credits.iconCodePoint);
          }
          if (from < 5) {
            if (!createdCreditsTable) {
              await m.addColumn(credits, credits.paymentDayOfMonth);
              await m.addColumn(credits, credits.insuranceCents);
            }
            await m.addColumn(fixedExpenses, fixedExpenses.linkedCreditId);
            await m.createTable(notificationLogs);
            // Réconciliation V0.9 : relie les charges fixes existantes de
            // catégorie "Crédit" au crédit correspondant (même nom), sans
            // jamais créer de doublon ni perdre de données — l'utilisateur
            // ne doit jamais ressaisir ses crédits.
            await reconcileCreditLinkedCharges(this);
          }
          if (from < 6) {
            // V1.0 — Project Planner : nouvelle table uniquement, aucune
            // donnée existante touchée.
            await m.createTable(projects);
          }
        },
      );
}

/// Relie chaque charge fixe de catégorie "Crédit" encore non reliée
/// (`linkedCreditId` nul) au crédit dont le nom correspond exactement
/// (insensible à la casse/espaces), sur tous les cycles. Ne touche jamais
/// aux charges déjà reliées, n'en supprime ni n'en crée aucune.
Future<void> reconcileCreditLinkedCharges(AppDatabase db) async {
  final creditCategoryIds = await (db.select(db.categories)
        ..where((c) => c.name.equals('Crédit') & c.type.equals('fixed_expense')))
      .map((c) => c.id)
      .get();
  if (creditCategoryIds.isEmpty) return;

  final credits = await db.select(db.credits).get();
  if (credits.isEmpty) return;
  final creditIdByNormalizedName = {
    for (final c in credits) c.name.trim().toLowerCase(): c.id,
  };

  final unlinkedCharges = await (db.select(db.fixedExpenses)
        ..where((e) => e.categoryId.isIn(creditCategoryIds) & e.linkedCreditId.isNull()))
      .get();

  for (final charge in unlinkedCharges) {
    final creditId = creditIdByNormalizedName[charge.name.trim().toLowerCase()];
    if (creditId == null) continue;
    await (db.update(db.fixedExpenses)..where((e) => e.id.equals(charge.id)))
        .write(FixedExpensesCompanion(linkedCreditId: Value(creditId)));
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'budgetpilot.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
