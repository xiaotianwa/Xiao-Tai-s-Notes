import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

class EntryRows extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text().withDefault(const Constant('diary'))();
  TextColumn get title => text()();
  TextColumn get content => text().withDefault(const Constant(''))();
  TextColumn get mood => text().withDefault(const Constant('开心'))();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get favorite => boolean().withDefault(const Constant(false))();
  TextColumn get mascotVariant => text().withDefault(const Constant('snack'))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ReminderRows extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  DateTimeColumn get scheduledAt => dateTime()();
  TextColumn get repeatRule => text().withDefault(const Constant('none'))();
  IntColumn get notifyBeforeMinutes => integer().withDefault(const Constant(30))();
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();
  TextColumn get priority => text().withDefault(const Constant('中优先级'))();
  TextColumn get icon => text().withDefault(const Constant('bell'))();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class AnniversaryRows extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  DateTimeColumn get date => dateTime()();
  TextColumn get category => text().withDefault(const Constant('love'))();
  TextColumn get colorName => text().withDefault(const Constant('pink'))();
  TextColumn get mascotVariant => text().withDefault(const Constant('flowers'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class PlaceRows extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  RealColumn get distanceKm => real().withDefault(const Constant(0))();
  TextColumn get tagsJson => text().map(const StringListConverter())();
  BoolColumn get favorite => boolean().withDefault(const Constant(false))();
  TextColumn get colorName => text().withDefault(const Constant('pink'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class FoodLogRows extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  IntColumn get calories => integer().withDefault(const Constant(0))();
  TextColumn get mealType => text().withDefault(const Constant('other'))();
  DateTimeColumn get loggedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class DailyMetricRows extends Table {
  TextColumn get id => text()();
  DateTimeColumn get date => dateTime()();
  TextColumn get mood => text().withDefault(const Constant('开心'))();
  IntColumn get waterCups => integer().withDefault(const Constant(0))();
  IntColumn get sleepMinutes => integer().withDefault(const Constant(0))();
  IntColumn get calories => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class GoalRows extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get category => text().withDefault(const Constant('weekly'))();
  IntColumn get targetValue => integer().withDefault(const Constant(1))();
  IntColumn get currentValue => integer().withDefault(const Constant(0))();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class SettingRows extends Table {
  TextColumn get key => text()();
  TextColumn get value => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

class BackupRows extends Table {
  TextColumn get id => text()();
  TextColumn get fileName => text()();
  TextColumn get filePath => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    EntryRows,
    ReminderRows,
    AnniversaryRows,
    PlaceRows,
    FoodLogRows,
    DailyMetricRows,
    GoalRows,
    SettingRows,
    BackupRows,
  ],
  daos: [LifeDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'xiaotai_life');
  }
}

@DriftAccessor(tables: [EntryRows, ReminderRows, AnniversaryRows, PlaceRows])
class LifeDao extends DatabaseAccessor<AppDatabase> with _$LifeDaoMixin {
  LifeDao(super.db);

  Future<List<EntryRow>> getEntries() {
    return (select(entryRows)..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();
  }

  Future<void> upsertEntry(EntryRowsCompanion entry) {
    return into(entryRows).insertOnConflictUpdate(entry);
  }

  Future<int> deleteEntry(String id) {
    return (delete(entryRows)..where((t) => t.id.equals(id))).go();
  }

  Future<List<ReminderRow>> getReminders() {
    return (select(reminderRows)
          ..orderBy([
            (t) => OrderingTerm.desc(t.pinned),
            (t) => OrderingTerm.asc(t.scheduledAt),
          ]))
        .get();
  }

  Future<void> upsertReminder(ReminderRowsCompanion reminder) {
    return into(reminderRows).insertOnConflictUpdate(reminder);
  }

  Future<int> deleteReminder(String id) {
    return (delete(reminderRows)..where((t) => t.id.equals(id))).go();
  }

  Future<List<AnniversaryRow>> getAnniversaries() {
    return (select(anniversaryRows)..orderBy([(t) => OrderingTerm.asc(t.date)])).get();
  }

  Future<void> upsertAnniversary(AnniversaryRowsCompanion anniversary) {
    return into(anniversaryRows).insertOnConflictUpdate(anniversary);
  }

  Future<List<PlaceRow>> getPlaces() {
    return (select(placeRows)..orderBy([(t) => OrderingTerm.desc(t.favorite)])).get();
  }

  Future<void> upsertPlace(PlaceRowsCompanion place) {
    return into(placeRows).insertOnConflictUpdate(place);
  }
}

class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String fromDb) {
    final value = jsonDecode(fromDb) as List<dynamic>;
    return value.cast<String>();
  }

  @override
  String toSql(List<String> value) {
    return jsonEncode(value);
  }
}
