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

@DriftDatabase(tables: [
  Categories,
  RecurringTemplates,
  BudgetCycles,
  Incomes,
  FixedExpenses,
  VariableExpenses,
  Savings,
  AppSettingsTable,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'budgetpilot.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
