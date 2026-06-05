import 'package:drift/drift.dart';

import 'app_database.dart';
import 'app_models.dart';

class AppRepository {
  AppRepository(this._database) : _dao = _database.lifeDao;

  final AppDatabase _database;
  final LifeDao _dao;
  bool _seeded = false;

  Future<void> ensureSeedData() async {
    if (_seeded) {
      return;
    }
    final entries = await _dao.getEntries();
    if (entries.isEmpty) {
      for (final entry in AppEntry.seed) {
        await upsertEntry(entry);
      }
    }
    final reminders = await _dao.getReminders();
    if (reminders.isEmpty) {
      for (final reminder in AppReminder.seed) {
        await upsertReminder(reminder);
      }
    }
    final anniversaries = await _dao.getAnniversaries();
    if (anniversaries.isEmpty) {
      for (final anniversary in AppAnniversary.seed) {
        await upsertAnniversary(anniversary);
      }
    }
    final places = await _dao.getPlaces();
    if (places.isEmpty) {
      for (final place in AppPlace.seed) {
        await upsertPlace(place);
      }
    }
    _seeded = true;
  }

  Future<List<AppEntry>> getEntries() async {
    await ensureSeedData();
    final rows = await _dao.getEntries();
    return rows.map(_entryFromRow).toList();
  }

  Future<void> upsertEntry(AppEntry entry) {
    final now = DateTime.now();
    return _dao.upsertEntry(
      EntryRowsCompanion(
        id: Value(entry.id),
        kind: Value(entry.kind),
        title: Value(entry.title),
        content: Value(entry.content),
        mood: Value(entry.mood),
        createdAt: Value(entry.createdAt),
        favorite: Value(entry.favorite),
        mascotVariant: Value(entry.mascotVariant),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> deleteEntry(String id) async {
    await _dao.deleteEntry(id);
  }

  Future<List<AppReminder>> getReminders() async {
    await ensureSeedData();
    final rows = await _dao.getReminders();
    return rows.map(_reminderFromRow).toList();
  }

  Future<void> upsertReminder(AppReminder reminder) {
    final now = DateTime.now();
    return _dao.upsertReminder(
      ReminderRowsCompanion(
        id: Value(reminder.id),
        title: Value(reminder.title),
        scheduledAt: Value(reminder.scheduledAt),
        repeatRule: Value(reminder.repeatRule),
        notifyBeforeMinutes: Value(reminder.notifyBeforeMinutes),
        pinned: Value(reminder.pinned),
        priority: Value(reminder.priority),
        icon: Value(reminder.icon),
        completed: Value(reminder.completed),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> deleteReminder(String id) async {
    await _dao.deleteReminder(id);
  }

  Future<List<AppAnniversary>> getAnniversaries() async {
    await ensureSeedData();
    final rows = await _dao.getAnniversaries();
    return rows.map(_anniversaryFromRow).toList();
  }

  Future<void> upsertAnniversary(AppAnniversary anniversary) {
    final now = DateTime.now();
    return _dao.upsertAnniversary(
      AnniversaryRowsCompanion(
        id: Value(anniversary.id),
        title: Value(anniversary.title),
        date: Value(anniversary.date),
        category: Value(anniversary.category),
        colorName: Value(anniversary.colorName),
        mascotVariant: Value(anniversary.mascotVariant),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  Future<List<AppPlace>> getPlaces() async {
    await ensureSeedData();
    final rows = await _dao.getPlaces();
    return rows.map(_placeFromRow).toList();
  }

  Future<void> upsertPlace(AppPlace place) {
    final now = DateTime.now();
    return _dao.upsertPlace(
      PlaceRowsCompanion(
        id: Value(place.id),
        title: Value(place.title),
        description: Value(place.description),
        distanceKm: Value(place.distanceKm),
        tagsJson: Value(place.tags),
        favorite: Value(place.favorite),
        colorName: Value(place.colorName),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  Future<TodaySnapshot> getTodaySnapshot(DateTime now) async {
    final reminders = await getReminders();
    final entries = await getEntries();
    final anniversaries = await getAnniversaries();
    return TodaySnapshot(
      reminderCount: reminders
          .where((reminder) => _sameDay(reminder.scheduledAt, now))
          .length,
      recentEntryCount: entries.length,
      anniversaryCount: anniversaries.length,
      latestEntries: entries.take(3).toList(),
      todayReminders: reminders
          .where((reminder) => _sameDay(reminder.scheduledAt, now))
          .toList(),
    );
  }

  Future<void> close() {
    return _database.close();
  }

  AppEntry _entryFromRow(EntryRow row) {
    return AppEntry(
      id: row.id,
      kind: row.kind,
      title: row.title,
      content: row.content,
      mood: row.mood,
      createdAt: row.createdAt,
      favorite: row.favorite,
      mascotVariant: row.mascotVariant,
    );
  }

  AppReminder _reminderFromRow(ReminderRow row) {
    return AppReminder(
      id: row.id,
      title: row.title,
      scheduledAt: row.scheduledAt,
      repeatRule: row.repeatRule,
      notifyBeforeMinutes: row.notifyBeforeMinutes,
      pinned: row.pinned,
      priority: row.priority,
      icon: row.icon,
      completed: row.completed,
    );
  }

  AppAnniversary _anniversaryFromRow(AnniversaryRow row) {
    return AppAnniversary(
      id: row.id,
      title: row.title,
      date: row.date,
      category: row.category,
      colorName: row.colorName,
      mascotVariant: row.mascotVariant,
    );
  }

  AppPlace _placeFromRow(PlaceRow row) {
    return AppPlace(
      id: row.id,
      title: row.title,
      description: row.description,
      distanceKm: row.distanceKm,
      tags: row.tagsJson,
      favorite: row.favorite,
      colorName: row.colorName,
    );
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
