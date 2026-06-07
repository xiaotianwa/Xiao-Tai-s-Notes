import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'app_models.dart';

export 'app_models.dart';

class AppLocalStore {
  AppLocalStore._(this._file, this._data);

  static final StreamController<void> _changes =
      StreamController<void>.broadcast(sync: true);

  static Stream<void> get changes => _changes.stream;

  static const _entriesKey = 'entries.v1';
  static const _memosKey = 'memos.v1';
  static const _aiMessagesKey = 'ai_messages.v1';
  static const _remindersKey = 'reminders.v1';
  static const _anniversariesKey = 'anniversaries.v1';
  static const _placesKey = 'places.v1';
  static const _coupleTasksKey = 'couple_tasks.v1';
  static const _weeklyGoalsKey = 'weekly_goals.v1';
  static const _moneyRecordsKey = 'money_records.v1';
  static const _settingsKey = 'settings.v1';
  static const _authSessionKey = 'auth_session.v1';
  static const _backupsKey = 'backups.v1';
  static const _syncQueueKey = 'sync_queue.v1';
  static const _syncDeviceIdKey = 'sync_device_id.v1';
  static const _syncLastPulledAtKey = 'sync_last_pulled_at.v1';
  static const _syncStatusKey = 'sync_status.v1';
  static const _dataRecoveryNoticeKey = 'data_recovery_notice.v1';
  static const _cleanSeedDataKey = 'clean_seed_data.v2';
  static const _seenAnnouncementIdsKey = 'seen_announcement_ids.v1';
  static const _seenDailyComicIdsKey = 'seen_daily_comic_ids.v1';
  static const _maxAiMessages = 80;

  static Map<String, Object?>? _webData;
  static final Map<String, Map<String, Object?>> _webBackups = {};

  final File? _file;
  final Map<String, Object?> _data;

  static Future<AppLocalStore> create() async {
    if (kIsWeb) {
      final data = _webData ?? <String, Object?>{};
      _webData = data;
      final store = AppLocalStore._(null, data);
      await store.ensureSeedData();
      return store;
    }
    final directory = await getApplicationDocumentsDirectory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}xiaotai_life_data.json',
    );
    final data = await _readDataFile(file);
    final store = AppLocalStore._(file, data);
    await store.ensureSeedData();
    return store;
  }

  @visibleForTesting
  static Future<AppLocalStore> createInMemoryForTesting({
    Map<String, Object?>? data,
  }) async {
    final store = AppLocalStore._(null, data ?? <String, Object?>{});
    await store.ensureSeedData();
    return store;
  }

  static Future<void> closeSharedDatabase() async {}

  static Future<Map<String, Object?>> _readDataFile(File file) async {
    if (!await file.exists()) {
      return {};
    }
    try {
      final raw = await file.readAsString();
      if (raw.isEmpty) {
        return {};
      }
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded.cast<String, Object?>();
      }
      throw const FormatException('Root JSON value is not an object');
    } on FormatException catch (error) {
      return _recoverCorruptDataFile(file, error);
    }
  }

  static Future<Map<String, Object?>> _recoverCorruptDataFile(
    File file,
    Object error,
  ) async {
    final now = DateTime.now();
    final corruptFilePath = await _copyCorruptDataFile(file, now);
    final recovered = await _readLatestValidBackup(file);
    final data = recovered?.data ?? <String, Object?>{};
    data[_dataRecoveryNoticeKey] = AppDataRecoveryNotice(
      id: 'recovery_${_recoveryStamp(now)}',
      detectedAt: now,
      corruptFilePath: corruptFilePath,
      restoredFromBackup: recovered != null,
      restoredBackupPath: recovered?.path,
      errorMessage: error.toString(),
    ).toJson();
    return data;
  }

  static Future<String> _copyCorruptDataFile(File file, DateTime now) async {
    final copyPath =
        '${file.parent.path}${Platform.pathSeparator}xiaotai_life_data.corrupt.${_recoveryStamp(now)}.json';
    try {
      await file.copy(copyPath);
      return copyPath;
    } on FileSystemException {
      return file.path;
    }
  }

  static Future<({Map<String, Object?> data, String path})?>
  _readLatestValidBackup(File file) async {
    final backupDirectory = Directory(
      '${file.parent.path}${Platform.pathSeparator}xiaotai_life_backups',
    );
    if (!await backupDirectory.exists()) {
      return null;
    }
    final candidates = <File>[];
    await for (final entity in backupDirectory.list()) {
      if (entity is File && entity.path.toLowerCase().endsWith('.json')) {
        candidates.add(entity);
      }
    }
    candidates.sort((a, b) {
      final bModified = b.statSync().modified;
      final aModified = a.statSync().modified;
      return bModified.compareTo(aModified);
    });
    for (final candidate in candidates) {
      try {
        final decoded = jsonDecode(await candidate.readAsString());
        if (decoded is Map<String, dynamic>) {
          return (data: decoded.cast<String, Object?>(), path: candidate.path);
        }
      } on FormatException {
        continue;
      } on FileSystemException {
        continue;
      }
    }
    return null;
  }

  Future<void> ensureSeedData() async {
    if (!_data.containsKey(_entriesKey)) {
      await saveEntries(const []);
    }
    if (!_data.containsKey(_memosKey)) {
      await saveMemos(const []);
    }
    if (!_data.containsKey(_aiMessagesKey)) {
      await saveAiMessages(const []);
    }
    if (!_data.containsKey(_remindersKey)) {
      await saveReminders(const []);
    }
    if (!_data.containsKey(_anniversariesKey)) {
      await saveAnniversaries(const []);
    }
    if (!_data.containsKey(_placesKey)) {
      await savePlaces(const []);
    }
    if (!_data.containsKey(_coupleTasksKey)) {
      await saveCoupleTasks(const []);
    }
    if (!_data.containsKey(_weeklyGoalsKey)) {
      await saveWeeklyGoals(const []);
    }
    if (!_data.containsKey(_moneyRecordsKey)) {
      await saveMoneyRecords(const []);
    }
    if (!_data.containsKey(_settingsKey)) {
      await _writeSettings(AppSettings.defaults);
    }
    if (_data[_cleanSeedDataKey] != true) {
      await _removeLegacySeedData();
      _data[_cleanSeedDataKey] = true;
      await _writeData();
    }
  }

  AppSettings getSettings() {
    final decoded = _data[_settingsKey] as Map<dynamic, dynamic>?;
    if (decoded == null) {
      return AppSettings.defaults;
    }
    return AppSettings.fromJson(decoded.cast<String, Object?>());
  }

  Future<void> saveSettings(AppSettings settings) async {
    await _writeSettings(settings);
    await enqueueSyncItem(
      type: 'settings',
      clientId: 'settings',
      data: settings.toJson(),
      clientUpdatedAt: settings.updatedAt ?? DateTime.now(),
    );
  }

  Future<void> _writeSettings(AppSettings settings) async {
    _data[_settingsKey] = settings.toJson();
    await _writeData();
  }

  AppAuthSession? getAuthSession() {
    final decoded = _data[_authSessionKey] as Map<dynamic, dynamic>?;
    if (decoded == null) {
      return null;
    }
    final session = AppAuthSession.fromJson(decoded.cast<String, Object?>());
    return session.isSignedIn ? session : null;
  }

  Future<void> saveAuthSession(AppAuthSession session) async {
    _data[_authSessionKey] = session.toJson();
    await _writeData();
  }

  Future<void> clearAuthSession() async {
    _data.remove(_authSessionKey);
    await _writeData();
  }

  AppSyncStatus getSyncStatus() {
    final decoded = _data[_syncStatusKey] as Map<dynamic, dynamic>?;
    final pendingCount = getSyncQueue().length;
    if (decoded == null) {
      return AppSyncStatus(pendingCount: pendingCount);
    }
    return AppSyncStatus.fromJson(
      decoded.cast<String, Object?>(),
    ).copyWith(pendingCount: pendingCount, running: false);
  }

  Future<void> saveSyncStatus(AppSyncStatus status) async {
    _data[_syncStatusKey] = status
        .copyWith(pendingCount: getSyncQueue().length)
        .toJson();
    await _writeData();
  }

  AppDataRecoveryNotice? getDataRecoveryNotice() {
    final decoded = _data[_dataRecoveryNoticeKey] as Map<dynamic, dynamic>?;
    if (decoded == null) {
      return null;
    }
    return AppDataRecoveryNotice.fromJson(decoded.cast<String, Object?>());
  }

  Future<void> clearDataRecoveryNotice() async {
    _data.remove(_dataRecoveryNoticeKey);
    await _writeData();
  }

  Future<void> markSyncStarted() async {
    final now = DateTime.now();
    await saveSyncStatus(
      getSyncStatus().copyWith(
        lastStartedAt: now,
        lastError: null,
        running: true,
      ),
    );
  }

  Future<void> markSyncSucceeded({
    required int pushed,
    required int pulled,
    required List<AppSyncConflict> conflicts,
  }) async {
    final now = DateTime.now();
    await saveSyncStatus(
      getSyncStatus().copyWith(
        lastFinishedAt: now,
        lastSuccessAt: now,
        lastError: null,
        lastPushed: pushed,
        lastPulled: pulled,
        lastConflictCount: conflicts.length,
        lastConflicts: conflicts,
        running: false,
      ),
    );
  }

  Future<void> markSyncFailed(Object error) async {
    final now = DateTime.now();
    await saveSyncStatus(
      getSyncStatus().copyWith(
        lastFinishedAt: now,
        lastFailureAt: now,
        lastError: error.toString().replaceFirst('Bad state: ', ''),
        running: false,
      ),
    );
  }

  List<AppEntry> getEntries() {
    return _readList(_entriesKey, AppEntry.fromJson);
  }

  Future<void> saveEntries(List<AppEntry> entries) {
    return _writeList(
      _entriesKey,
      entries.map((entry) => entry.toJson()).toList(),
    );
  }

  Future<void> upsertEntry(AppEntry entry) async {
    final entries = getEntries();
    final index = entries.indexWhere((item) => item.id == entry.id);
    if (index == -1) {
      entries.insert(0, entry);
    } else {
      entries[index] = entry;
    }
    await saveEntries(entries);
    await enqueueSyncItem(
      type: 'entry',
      clientId: entry.id,
      data: entry.toJson(),
      clientUpdatedAt: entry.createdAt,
    );
  }

  Future<void> deleteEntry(String id) async {
    final now = DateTime.now();
    await saveEntries(getEntries().where((entry) => entry.id != id).toList());
    await enqueueSyncItem(
      type: 'entry',
      clientId: id,
      data: const {},
      clientUpdatedAt: now,
      deletedAt: now,
    );
  }

  List<AppMemo> getMemos() {
    final memos = _readList(_memosKey, AppMemo.fromJson);
    memos.sort((a, b) {
      if (a.pinned != b.pinned) {
        return a.pinned ? -1 : 1;
      }
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return memos;
  }

  Future<void> saveMemos(List<AppMemo> memos) {
    return _writeList(_memosKey, memos.map((memo) => memo.toJson()).toList());
  }

  Future<void> upsertMemo(AppMemo memo) async {
    final memos = getMemos();
    final index = memos.indexWhere((item) => item.id == memo.id);
    if (index == -1) {
      memos.insert(0, memo);
    } else {
      memos[index] = memo;
    }
    await saveMemos(memos);
    await enqueueSyncItem(
      type: 'memo',
      clientId: memo.id,
      data: memo.toJson(),
      clientUpdatedAt: memo.updatedAt,
    );
  }

  Future<void> deleteMemo(String id) async {
    final now = DateTime.now();
    await saveMemos(getMemos().where((memo) => memo.id != id).toList());
    await enqueueSyncItem(
      type: 'memo',
      clientId: id,
      data: const {},
      clientUpdatedAt: now,
      deletedAt: now,
    );
  }

  List<AppAiMessage> getAiMessages() {
    final messages = _readList(_aiMessagesKey, AppAiMessage.fromJson);
    messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return messages;
  }

  Future<void> saveAiMessages(List<AppAiMessage> messages) {
    return _writeList(
      _aiMessagesKey,
      messages.map((message) => message.toJson()).toList(),
    );
  }

  Future<void> addAiMessage(AppAiMessage message) async {
    final messages = [...getAiMessages(), message];
    await saveAiMessages(_latestAiMessages(messages));
    await enqueueSyncItem(
      type: 'ai_message',
      clientId: message.id,
      data: message.toJson(),
      clientUpdatedAt: message.createdAt,
    );
  }

  Future<void> clearAiMessages() async {
    final messages = getAiMessages();
    if (messages.isEmpty) {
      return;
    }
    final now = DateTime.now();
    await saveAiMessages(const []);
    for (final message in messages) {
      await enqueueSyncItem(
        type: 'ai_message',
        clientId: message.id,
        data: const {},
        clientUpdatedAt: now,
        deletedAt: now,
      );
    }
  }

  List<AppReminder> getReminders() {
    return _readList(_remindersKey, AppReminder.fromJson);
  }

  Future<void> saveReminders(List<AppReminder> reminders) {
    return _writeList(
      _remindersKey,
      reminders.map((reminder) => reminder.toJson()).toList(),
    );
  }

  Future<void> addReminder(AppReminder reminder) {
    return upsertReminder(reminder);
  }

  Future<void> upsertReminder(AppReminder reminder) async {
    final reminders = getReminders();
    final index = reminders.indexWhere((item) => item.id == reminder.id);
    if (index == -1) {
      reminders.insert(0, reminder);
    } else {
      reminders[index] = reminder;
    }
    await saveReminders(reminders);
    await enqueueSyncItem(
      type: 'reminder',
      clientId: reminder.id,
      data: reminder.toJson(),
      clientUpdatedAt: DateTime.now(),
    );
  }

  Future<void> deleteReminder(String id) async {
    final now = DateTime.now();
    await saveReminders(
      getReminders().where((reminder) => reminder.id != id).toList(),
    );
    await enqueueSyncItem(
      type: 'reminder',
      clientId: id,
      data: const {},
      clientUpdatedAt: now,
      deletedAt: now,
    );
  }

  List<AppAnniversary> getAnniversaries() {
    return _readList(_anniversariesKey, AppAnniversary.fromJson);
  }

  Future<void> saveAnniversaries(List<AppAnniversary> anniversaries) {
    return _writeList(
      _anniversariesKey,
      anniversaries.map((anniversary) => anniversary.toJson()).toList(),
    );
  }

  Future<void> upsertAnniversary(AppAnniversary anniversary) async {
    var anniversaries = getAnniversaries();
    final unpinnedItems = <AppAnniversary>[];
    if (anniversary.pinnedOnHome) {
      anniversaries = anniversaries.map((item) {
        if (item.id != anniversary.id && item.pinnedOnHome) {
          final unpinned = item.copyWith(pinnedOnHome: false);
          unpinnedItems.add(unpinned);
          return unpinned;
        }
        return item;
      }).toList();
    }
    final index = anniversaries.indexWhere((item) => item.id == anniversary.id);
    if (index == -1) {
      anniversaries.insert(0, anniversary);
    } else {
      anniversaries[index] = anniversary;
    }
    final now = DateTime.now();
    await saveAnniversaries(anniversaries);
    for (final item in unpinnedItems) {
      await enqueueSyncItem(
        type: 'anniversary',
        clientId: item.id,
        data: item.toJson(),
        clientUpdatedAt: now,
      );
    }
    await enqueueSyncItem(
      type: 'anniversary',
      clientId: anniversary.id,
      data: anniversary.toJson(),
      clientUpdatedAt: now,
    );
  }

  Future<void> deleteAnniversary(String id) async {
    final now = DateTime.now();
    await saveAnniversaries(
      getAnniversaries().where((anniversary) => anniversary.id != id).toList(),
    );
    await enqueueSyncItem(
      type: 'anniversary',
      clientId: id,
      data: const {},
      clientUpdatedAt: now,
      deletedAt: now,
    );
  }

  List<AppPlace> getPlaces() {
    return _readList(_placesKey, AppPlace.fromJson);
  }

  Future<void> savePlaces(List<AppPlace> places) {
    return _writeList(
      _placesKey,
      places.map((place) => place.toJson()).toList(),
    );
  }

  Future<void> upsertPlace(AppPlace place) async {
    final places = getPlaces();
    final index = places.indexWhere((item) => item.id == place.id);
    if (index == -1) {
      places.insert(0, place);
    } else {
      places[index] = place;
    }
    await savePlaces(places);
    await enqueueSyncItem(
      type: 'place',
      clientId: place.id,
      data: place.toJson(),
      clientUpdatedAt: DateTime.now(),
    );
  }

  Future<void> deletePlace(String id) async {
    final now = DateTime.now();
    await savePlaces(getPlaces().where((place) => place.id != id).toList());
    await enqueueSyncItem(
      type: 'place',
      clientId: id,
      data: const {},
      clientUpdatedAt: now,
      deletedAt: now,
    );
  }

  List<AppCoupleTask> getCoupleTasks() {
    return _readList(_coupleTasksKey, AppCoupleTask.fromJson);
  }

  Future<void> saveCoupleTasks(List<AppCoupleTask> tasks) {
    final sorted = [...tasks]..sort((a, b) => a.index.compareTo(b.index));
    return _writeList(
      _coupleTasksKey,
      sorted.map((task) => task.toJson()).toList(),
    );
  }

  Future<void> upsertCoupleTask(AppCoupleTask task) async {
    final tasks = getCoupleTasks();
    final index = tasks.indexWhere((item) => item.id == task.id);
    if (index == -1) {
      tasks.add(task);
    } else {
      tasks[index] = task;
    }
    await saveCoupleTasks(tasks);
    await enqueueSyncItem(
      type: 'couple_task',
      clientId: task.id,
      data: task.toJson(),
      clientUpdatedAt: DateTime.now(),
    );
  }

  Future<void> deleteCoupleTask(String id) async {
    final now = DateTime.now();
    await saveCoupleTasks(
      getCoupleTasks().where((task) => task.id != id).toList(),
    );
    await enqueueSyncItem(
      type: 'couple_task',
      clientId: id,
      data: const {},
      clientUpdatedAt: now,
      deletedAt: now,
    );
  }

  List<AppWeeklyGoal> getWeeklyGoals() {
    return _readList(_weeklyGoalsKey, AppWeeklyGoal.fromJson);
  }

  Future<void> saveWeeklyGoals(List<AppWeeklyGoal> goals) {
    return _writeList(
      _weeklyGoalsKey,
      goals.map((goal) => goal.toJson()).toList(),
    );
  }

  Future<void> upsertWeeklyGoal(AppWeeklyGoal goal) async {
    final goals = getWeeklyGoals();
    final index = goals.indexWhere((item) => item.id == goal.id);
    if (index == -1) {
      goals.add(goal);
    } else {
      goals[index] = goal;
    }
    await saveWeeklyGoals(goals);
    await enqueueSyncItem(
      type: 'weekly_goal',
      clientId: goal.id,
      data: goal.toJson(),
      clientUpdatedAt: DateTime.now(),
    );
  }

  Future<void> deleteWeeklyGoal(String id) async {
    final now = DateTime.now();
    await saveWeeklyGoals(
      getWeeklyGoals().where((goal) => goal.id != id).toList(),
    );
    await enqueueSyncItem(
      type: 'weekly_goal',
      clientId: id,
      data: const {},
      clientUpdatedAt: now,
      deletedAt: now,
    );
  }

  List<AppMoneyRecord> getMoneyRecords() {
    final records = _readList(_moneyRecordsKey, AppMoneyRecord.fromJson);
    records.sort((a, b) => b.happenedAt.compareTo(a.happenedAt));
    return records;
  }

  Future<void> saveMoneyRecords(List<AppMoneyRecord> records) {
    final sorted = [...records]
      ..sort((a, b) => b.happenedAt.compareTo(a.happenedAt));
    return _writeList(
      _moneyRecordsKey,
      sorted.map((record) => record.toJson()).toList(),
    );
  }

  Future<void> upsertMoneyRecord(AppMoneyRecord record) async {
    final records = getMoneyRecords();
    final index = records.indexWhere((item) => item.id == record.id);
    if (index == -1) {
      records.insert(0, record);
    } else {
      records[index] = record;
    }
    await saveMoneyRecords(records);
    await enqueueSyncItem(
      type: 'money_record',
      clientId: record.id,
      data: record.toJson(),
      clientUpdatedAt: record.updatedAt,
    );
  }

  Future<void> deleteMoneyRecord(String id) async {
    final now = DateTime.now();
    await saveMoneyRecords(
      getMoneyRecords().where((record) => record.id != id).toList(),
    );
    await enqueueSyncItem(
      type: 'money_record',
      clientId: id,
      data: const {},
      clientUpdatedAt: now,
      deletedAt: now,
    );
  }

  TodaySnapshot getTodaySnapshot(DateTime now) {
    final reminders = getReminders();
    final entries = getEntries();
    final anniversaries = getAnniversaries();
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

  String getDataFilePath() {
    return _file?.path ?? 'browser-memory://xiaotai_life_data.json';
  }

  String getSyncDeviceId() {
    final existing = _data[_syncDeviceIdKey] as String?;
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final id = 'device_${DateTime.now().microsecondsSinceEpoch}';
    _data[_syncDeviceIdKey] = id;
    return id;
  }

  DateTime? getLastPulledAt() {
    final value = _data[_syncLastPulledAtKey] as String?;
    if (value == null) {
      return null;
    }
    return DateTime.tryParse(value);
  }

  Future<void> saveLastPulledAt(DateTime value) async {
    _data[_syncLastPulledAtKey] = value.toIso8601String();
    await _writeData();
  }

  /// 已成功上传的系统相册图片 ID 集合（去重用）。

  Set<String> getSeenAnnouncementIds() {
    final raw = _data[_seenAnnouncementIdsKey];
    if (raw is List) {
      return raw.whereType<String>().toSet();
    }
    return <String>{};
  }

  Future<void> markAnnouncementSeen(String id) async {
    final trimmed = id.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final existing = getSeenAnnouncementIds()..add(trimmed);
    _data[_seenAnnouncementIdsKey] = existing.toList(growable: false);
    await _writeData();
  }

  Set<String> getSeenDailyComicIds() {
    final raw = _data[_seenDailyComicIdsKey];
    if (raw is List) {
      return raw.whereType<String>().toSet();
    }
    return <String>{};
  }

  Future<void> markDailyComicSeen(String id) async {
    final trimmed = id.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final existing = getSeenDailyComicIds()..add(trimmed);
    _data[_seenDailyComicIdsKey] = existing.toList(growable: false);
    await _writeData();
  }

  List<AppSyncQueueItem> getSyncQueue() {
    return _readList(_syncQueueKey, AppSyncQueueItem.fromJson)
      ..sort((a, b) => a.clientUpdatedAt.compareTo(b.clientUpdatedAt));
  }

  Future<void> saveSyncQueue(List<AppSyncQueueItem> queue) {
    return _writeList(
      _syncQueueKey,
      queue.map((item) => item.toJson()).toList(),
    );
  }

  Future<void> enqueueSyncItem({
    required String type,
    required String clientId,
    required Map<String, Object?> data,
    required DateTime clientUpdatedAt,
    DateTime? deletedAt,
  }) async {
    final queue = getSyncQueue()
        .where((item) => item.type != type || item.clientId != clientId)
        .toList();
    final id =
        'sync_${type}_${clientId}_${DateTime.now().microsecondsSinceEpoch}';
    queue.add(
      AppSyncQueueItem(
        id: id,
        type: type,
        clientId: clientId,
        clientUpdatedAt: clientUpdatedAt,
        data: data,
        deletedAt: deletedAt,
      ),
    );
    await saveSyncQueue(queue);
  }

  Future<void> removeSyncedQueueItems(Set<String> ids) async {
    if (ids.isEmpty) {
      return;
    }
    final queue = getSyncQueue()
        .where((item) => !ids.contains(item.id))
        .toList();
    await saveSyncQueue(queue);
  }

  Future<void> removeQueuedSyncItem({
    required String type,
    required String clientId,
  }) async {
    final queue = getSyncQueue()
        .where((item) => item.type != type || item.clientId != clientId)
        .toList();
    await saveSyncQueue(queue);
  }

  Future<void> applyRemoteSyncItem({
    required String type,
    required String clientId,
    required Map<String, Object?> data,
    DateTime? deletedAt,
  }) async {
    if (deletedAt != null) {
      await _deleteLocalByType(type, clientId);
      return;
    }
    await _upsertLocalByType(type, data);
  }

  Future<void> applyServerConflict(AppSyncConflict conflict) async {
    await applyRemoteSyncItem(
      type: conflict.type,
      clientId: conflict.clientId,
      data: conflict.serverData,
      deletedAt: conflict.serverDeletedAt,
    );
    await removeQueuedSyncItem(
      type: conflict.type,
      clientId: conflict.clientId,
    );
    await _removeSyncConflict(conflict);
  }

  Future<void> keepLocalConflict(AppSyncConflict conflict) async {
    final now = DateTime.now();
    final queue = getSyncQueue();
    var replaced = false;
    final refreshed = queue.map((item) {
      if (item.type != conflict.type || item.clientId != conflict.clientId) {
        return item;
      }
      replaced = true;
      return AppSyncQueueItem(
        id: item.id,
        type: item.type,
        clientId: item.clientId,
        clientUpdatedAt: now,
        data: item.data,
        deletedAt: item.deletedAt,
      );
    }).toList();

    if (!replaced && conflict.localData.isNotEmpty) {
      refreshed.add(
        AppSyncQueueItem(
          id: 'sync_${conflict.type}_${conflict.clientId}_${now.microsecondsSinceEpoch}',
          type: conflict.type,
          clientId: conflict.clientId,
          clientUpdatedAt: now,
          data: conflict.localData,
          deletedAt: null,
        ),
      );
    }

    await saveSyncQueue(refreshed);
    await _removeSyncConflict(conflict);
  }

  List<AppDataBackup> getBackups() {
    return _readList(_backupsKey, AppDataBackup.fromJson)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> saveBackups(List<AppDataBackup> backups) {
    final sorted = [...backups]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return _writeList(
      _backupsKey,
      sorted.take(1).map((backup) => backup.toJson()).toList(),
    );
  }

  Future<AppDataBackup> createBackup() async {
    await _writeData();
    final now = DateTime.now();
    final id = 'backup_${_backupStamp(now)}';
    final snapshot = _cloneData(_data)..remove(_dataRecoveryNoticeKey);
    final raw = const JsonEncoder.withIndent('  ').convert(snapshot);
    final file = _file;
    if (file == null) {
      _webBackups[id] = snapshot;
      final backup = AppDataBackup(
        id: id,
        createdAt: now,
        filePath: 'browser-memory://$id.json',
        bytes: utf8.encode(raw).length,
        itemCount: _countStoredItems(),
      );
      _webBackups
        ..clear()
        ..[id] = snapshot;
      await saveBackups([backup]);
      return backup;
    }
    final previousBackups = getBackups();
    final backupDirectory = Directory(
      '${file.parent.path}${Platform.pathSeparator}xiaotai_life_backups',
    );
    if (!await backupDirectory.exists()) {
      await backupDirectory.create(recursive: true);
    }
    final backupPath =
        '${backupDirectory.path}${Platform.pathSeparator}$id.json';
    final tempPath = '$backupPath.tmp';
    final tempFile = File(tempPath);
    await tempFile.writeAsString(raw, flush: true);
    final backupFile = await tempFile.rename(backupPath);
    final backup = AppDataBackup(
      id: id,
      createdAt: now,
      filePath: backupFile.path,
      bytes: await backupFile.length(),
      itemCount: _countStoredItems(),
    );
    await _deleteBackupFiles(previousBackups, keepPath: backup.filePath);
    await _deleteOldBackupDirectoryFiles(
      backupDirectory,
      keepPath: backup.filePath,
    );
    await saveBackups([backup]);
    return backup;
  }

  Future<AppDataBackup> restoreLatestBackup() async {
    final backup = await latestRestorableBackup();
    if (backup == null) {
      throw StateError('没有可恢复的备份');
    }
    return restoreBackup(backup);
  }

  Future<AppDataBackup?> latestRestorableBackup() async {
    final backups = getBackups();
    for (final backup in backups) {
      if (await _isRestorableBackup(backup)) {
        return backup;
      }
    }
    return null;
  }

  Future<AppDataBackup> restoreBackup(AppDataBackup backup) async {
    if (_file == null) {
      final restored = _webBackups[backup.id];
      if (restored == null) {
        throw StateError('浏览器预览中的备份已失效');
      }
      final backups = getBackups();
      _data
        ..clear()
        ..addAll(_cloneData(restored));
      _data[_backupsKey] = backups.map((item) => item.toJson()).toList();
      _data.remove(_dataRecoveryNoticeKey);
      await _writeData();
      await ensureSeedData();
      return backup;
    }
    final backupFile = File(backup.filePath);
    if (!await backupFile.exists()) {
      throw FileSystemException('备份文件不存在', backup.filePath);
    }
    final raw = await backupFile.readAsString();
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Backup root JSON value is not an object');
    }
    final restored = decoded.cast<String, Object?>();
    final backups = getBackups();
    _data
      ..clear()
      ..addAll(restored);
    _data[_backupsKey] = backups.map((item) => item.toJson()).toList();
    _data.remove(_dataRecoveryNoticeKey);
    await _writeData();
    await ensureSeedData();
    return backup;
  }

  Future<bool> _isRestorableBackup(AppDataBackup backup) async {
    if (_file == null) {
      return _webBackups.containsKey(backup.id);
    }
    final backupFile = File(backup.filePath);
    if (!await backupFile.exists()) {
      return false;
    }
    try {
      final decoded = jsonDecode(await backupFile.readAsString());
      return decoded is Map<String, dynamic>;
    } catch (_) {
      return false;
    }
  }

  Future<void> _deleteBackupFiles(
    List<AppDataBackup> backups, {
    required String keepPath,
  }) async {
    for (final backup in backups) {
      if (backup.filePath == keepPath ||
          backup.filePath.startsWith('browser-memory://')) {
        continue;
      }
      try {
        final file = File(backup.filePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }
  }

  Future<void> _deleteOldBackupDirectoryFiles(
    Directory backupDirectory, {
    required String keepPath,
  }) async {
    if (!await backupDirectory.exists()) {
      return;
    }
    await for (final entity in backupDirectory.list()) {
      if (entity is! File || entity.path == keepPath) {
        continue;
      }
      final lower = entity.path.toLowerCase();
      if (!lower.endsWith('.json') && !lower.endsWith('.tmp')) {
        continue;
      }
      try {
        await entity.delete();
      } catch (_) {}
    }
  }

  List<T> _readList<T>(
    String key,
    T Function(Map<String, Object?> json) fromJson,
  ) {
    final decoded = _data[key] as List<dynamic>?;
    if (decoded == null) {
      return [];
    }
    return decoded
        .cast<Map<dynamic, dynamic>>()
        .map((item) => fromJson(item.cast<String, Object?>()))
        .toList();
  }

  Future<void> _writeList(String key, List<Map<String, Object?>> values) async {
    _data[key] = values;
    await _writeData();
  }

  Future<void> _writeData() async {
    final file = _file;
    if (file == null) {
      _webData = _data;
      if (!_changes.isClosed) {
        _changes.add(null);
      }
      return;
    }
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    await file.writeAsString(jsonEncode(_data), flush: true);
    if (!_changes.isClosed) {
      _changes.add(null);
    }
  }

  static Map<String, Object?> _cloneData(Map<String, Object?> data) {
    return (jsonDecode(jsonEncode(data)) as Map<String, dynamic>)
        .cast<String, Object?>();
  }

  static String _recoveryStamp(DateTime time) {
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    final second = time.second.toString().padLeft(2, '0');
    return '${time.year}$month${day}_$hour$minute$second';
  }

  Future<void> _removeSyncConflict(AppSyncConflict conflict) async {
    final status = getSyncStatus();
    final conflicts = status.lastConflicts
        .where((item) => item.key != conflict.key)
        .toList();
    await saveSyncStatus(
      status.copyWith(
        lastConflictCount: conflicts.length,
        lastConflicts: conflicts,
      ),
    );
  }

  Future<void> _deleteLocalByType(String type, String clientId) async {
    switch (type) {
      case 'entry':
        await saveEntries(
          getEntries().where((entry) => entry.id != clientId).toList(),
        );
      case 'memo':
        await saveMemos(
          getMemos().where((memo) => memo.id != clientId).toList(),
        );
      case 'ai_message':
        await saveAiMessages(
          getAiMessages().where((message) => message.id != clientId).toList(),
        );
      case 'reminder':
        await saveReminders(
          getReminders().where((reminder) => reminder.id != clientId).toList(),
        );
      case 'anniversary':
        await saveAnniversaries(
          getAnniversaries()
              .where((anniversary) => anniversary.id != clientId)
              .toList(),
        );
      case 'place':
        await savePlaces(
          getPlaces().where((place) => place.id != clientId).toList(),
        );
      case 'couple_task':
        await saveCoupleTasks(
          getCoupleTasks().where((task) => task.id != clientId).toList(),
        );
      case 'weekly_goal':
        await saveWeeklyGoals(
          getWeeklyGoals().where((goal) => goal.id != clientId).toList(),
        );
      case 'money_record':
        await saveMoneyRecords(
          getMoneyRecords().where((record) => record.id != clientId).toList(),
        );
    }
  }

  Future<void> _upsertLocalByType(
    String type,
    Map<String, Object?> data,
  ) async {
    switch (type) {
      case 'entry':
        final item = AppEntry.fromJson(data);
        final items = getEntries();
        final index = items.indexWhere((entry) => entry.id == item.id);
        if (index == -1) {
          items.insert(0, item);
        } else {
          items[index] = item;
        }
        await saveEntries(items);
      case 'memo':
        final item = AppMemo.fromJson(data);
        final items = getMemos();
        final index = items.indexWhere((memo) => memo.id == item.id);
        if (index == -1) {
          items.insert(0, item);
        } else {
          items[index] = item;
        }
        await saveMemos(items);
      case 'ai_message':
        final item = AppAiMessage.fromJson(data);
        final items = getAiMessages();
        final index = items.indexWhere((message) => message.id == item.id);
        if (index == -1) {
          items.add(item);
        } else {
          items[index] = item;
        }
        await saveAiMessages(_latestAiMessages(items));
      case 'reminder':
        final item = AppReminder.fromJson(data);
        final items = getReminders();
        final index = items.indexWhere((reminder) => reminder.id == item.id);
        if (index == -1) {
          items.insert(0, item);
        } else {
          items[index] = item;
        }
        await saveReminders(items);
      case 'anniversary':
        final item = AppAnniversary.fromJson(data);
        final items = getAnniversaries();
        final index = items.indexWhere(
          (anniversary) => anniversary.id == item.id,
        );
        if (index == -1) {
          items.insert(0, item);
        } else {
          items[index] = item;
        }
        await saveAnniversaries(items);
      case 'place':
        final item = AppPlace.fromJson(data);
        final items = getPlaces();
        final index = items.indexWhere((place) => place.id == item.id);
        if (index == -1) {
          items.insert(0, item);
        } else {
          items[index] = item;
        }
        await savePlaces(items);
      case 'couple_task':
        final item = AppCoupleTask.fromJson(data);
        final items = getCoupleTasks();
        final index = items.indexWhere((task) => task.id == item.id);
        if (index == -1) {
          items.add(item);
        } else {
          items[index] = item;
        }
        await saveCoupleTasks(items);
      case 'weekly_goal':
        final item = AppWeeklyGoal.fromJson(data);
        final items = getWeeklyGoals();
        final index = items.indexWhere((goal) => goal.id == item.id);
        if (index == -1) {
          items.add(item);
        } else {
          items[index] = item;
        }
        await saveWeeklyGoals(items);
      case 'money_record':
        final item = AppMoneyRecord.fromJson(data);
        final items = getMoneyRecords();
        final index = items.indexWhere((record) => record.id == item.id);
        if (index == -1) {
          items.insert(0, item);
        } else {
          items[index] = item;
        }
        await saveMoneyRecords(items);
      case 'settings':
        await _writeSettings(AppSettings.fromJson(data));
    }
  }

  List<AppAiMessage> _latestAiMessages(List<AppAiMessage> messages) {
    final sorted = [...messages]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final start = sorted.length > _maxAiMessages
        ? sorted.length - _maxAiMessages
        : 0;
    return sorted.skip(start).toList();
  }

  int _countStoredItems() {
    return getEntries().length +
        getMemos().length +
        getAiMessages().length +
        getReminders().length +
        getAnniversaries().length +
        getPlaces().length +
        getCoupleTasks().length +
        getWeeklyGoals().length +
        getMoneyRecords().length;
  }

  Future<void> _removeLegacySeedData() async {
    await saveEntries(
      getEntries()
          .where(
            (entry) =>
                !_isSeedId(entry.id, 'entry_', 4) &&
                !_isLegacySampleId(entry.id),
          )
          .toList(),
    );
    await saveMemos(
      getMemos().where((memo) => !_isLegacySampleId(memo.id)).toList(),
    );
    await saveReminders(
      getReminders()
          .where(
            (reminder) =>
                !_isSeedId(reminder.id, 'reminder_', 3) &&
                !_isLegacySampleId(reminder.id),
          )
          .toList(),
    );
    await saveAnniversaries(
      getAnniversaries()
          .where(
            (anniversary) =>
                !_isSeedId(anniversary.id, 'anniversary_', 3) &&
                !_isLegacySampleId(anniversary.id),
          )
          .toList(),
    );
    await savePlaces(
      getPlaces()
          .where(
            (place) =>
                !_isSeedId(place.id, 'place_', 4) &&
                !_isLegacySampleId(place.id),
          )
          .toList(),
    );
    await saveCoupleTasks(
      getCoupleTasks()
          .where(
            (task) =>
                !_isSeedId(task.id, 'couple_', 100) &&
                !_isLegacySampleId(task.id),
          )
          .toList(),
    );
    await saveWeeklyGoals(
      getWeeklyGoals()
          .where(
            (goal) =>
                !_isSeedId(goal.id, 'goal_', 4) &&
                !goal.id.startsWith('home_sample_') &&
                !_isLegacySampleId(goal.id),
          )
          .toList(),
    );
    await saveMoneyRecords(
      getMoneyRecords()
          .where((record) => !_isLegacySampleId(record.id))
          .toList(),
    );
  }

  bool _isSeedId(String id, String prefix, int maxIndex) {
    if (!id.startsWith(prefix)) {
      return false;
    }
    final index = int.tryParse(id.substring(prefix.length));
    return index != null && index >= 1 && index <= maxIndex;
  }

  bool _isLegacySampleId(String id) {
    return id.startsWith('sample_');
  }

  String _backupStamp(DateTime time) {
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    final second = time.second.toString().padLeft(2, '0');
    final micros = time.microsecond.toString().padLeft(6, '0');
    return '${time.year}$month${day}_$hour$minute$second$micros';
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
