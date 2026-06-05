class TodaySnapshot {
  const TodaySnapshot({
    required this.reminderCount,
    required this.recentEntryCount,
    required this.anniversaryCount,
    required this.latestEntries,
    required this.todayReminders,
  });

  final int reminderCount;
  final int recentEntryCount;
  final int anniversaryCount;
  final List<AppEntry> latestEntries;
  final List<AppReminder> todayReminders;
}

class AppSettings {
  const AppSettings({
    required this.profileName,
    required this.profileMotto,
    this.profileAvatarAsset,
    required this.notificationsEnabled,
    this.lockPreviewEnabled = true,
    this.announcementNotificationsEnabled = true,
    this.notificationSoundEnabled = false,
    this.dailyMemoReminderHour = 20,
    this.dailyMemoReminderMinute = 0,
    this.firstLaunchPromptShown = false,
    this.themeId = 'classic',
    this.updatedAt,
  });

  final String profileName;
  final String profileMotto;
  final String? profileAvatarAsset;
  final bool notificationsEnabled;
  final bool lockPreviewEnabled;
  final bool announcementNotificationsEnabled;
  final bool notificationSoundEnabled;
  final int dailyMemoReminderHour;
  final int dailyMemoReminderMinute;
  // 首次启动引导（通知/相册授权）是否已经向用户弹出过。
  final bool firstLaunchPromptShown;
  final String themeId;
  final DateTime? updatedAt;

  static const defaults = AppSettings(
    profileName: '婷婷大王',
    profileMotto: '婷婷天下第一',
    // 默认关闭通知，首次启动引导用户主动授权后再打开。
    notificationsEnabled: false,
    firstLaunchPromptShown: false,
    themeId: 'classic',
  );

  AppSettings copyWith({
    String? profileName,
    String? profileMotto,
    String? profileAvatarAsset,
    bool? notificationsEnabled,
    bool? lockPreviewEnabled,
    bool? announcementNotificationsEnabled,
    bool? notificationSoundEnabled,
    int? dailyMemoReminderHour,
    int? dailyMemoReminderMinute,
    bool? firstLaunchPromptShown,
    String? themeId,
    DateTime? updatedAt,
  }) {
    return AppSettings(
      profileName: profileName ?? this.profileName,
      profileMotto: profileMotto ?? this.profileMotto,
      profileAvatarAsset: profileAvatarAsset ?? this.profileAvatarAsset,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      lockPreviewEnabled: lockPreviewEnabled ?? this.lockPreviewEnabled,
      announcementNotificationsEnabled:
          announcementNotificationsEnabled ??
          this.announcementNotificationsEnabled,
      notificationSoundEnabled:
          notificationSoundEnabled ?? this.notificationSoundEnabled,
      dailyMemoReminderHour:
          dailyMemoReminderHour ?? this.dailyMemoReminderHour,
      dailyMemoReminderMinute:
          dailyMemoReminderMinute ?? this.dailyMemoReminderMinute,
      firstLaunchPromptShown:
          firstLaunchPromptShown ?? this.firstLaunchPromptShown,
      themeId: themeId ?? this.themeId,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'profileName': profileName,
      'profileMotto': profileMotto,
      'profileAvatarAsset': profileAvatarAsset,
      'notificationsEnabled': notificationsEnabled,
      'lockPreviewEnabled': lockPreviewEnabled,
      'announcementNotificationsEnabled': announcementNotificationsEnabled,
      'notificationSoundEnabled': notificationSoundEnabled,
      'dailyMemoReminderHour': dailyMemoReminderHour,
      'dailyMemoReminderMinute': dailyMemoReminderMinute,
      'firstLaunchPromptShown': firstLaunchPromptShown,
      'themeId': themeId,
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  static AppSettings fromJson(Map<String, Object?> json) {
    final updatedAtText = json['updatedAt'] as String?;
    return AppSettings(
      profileName: json['profileName'] as String? ?? defaults.profileName,
      profileMotto: json['profileMotto'] as String? ?? defaults.profileMotto,
      profileAvatarAsset: json['profileAvatarAsset'] as String?,
      notificationsEnabled:
          json['notificationsEnabled'] as bool? ??
          defaults.notificationsEnabled,
      lockPreviewEnabled:
          json['lockPreviewEnabled'] as bool? ?? defaults.lockPreviewEnabled,
      announcementNotificationsEnabled:
          json['announcementNotificationsEnabled'] as bool? ??
          defaults.announcementNotificationsEnabled,
      notificationSoundEnabled:
          json['notificationSoundEnabled'] as bool? ??
          defaults.notificationSoundEnabled,
      dailyMemoReminderHour:
          (json['dailyMemoReminderHour'] as num?)?.toInt() ??
          defaults.dailyMemoReminderHour,
      dailyMemoReminderMinute:
          (json['dailyMemoReminderMinute'] as num?)?.toInt() ??
          defaults.dailyMemoReminderMinute,
      // 旧版本数据没有这个字段：如果用户之前已经在用 App，视为已弹过引导，
      // 避免老用户再次被弹窗打扰。判断依据是 updatedAt 已经存在（即旧版本写过资料）。
      firstLaunchPromptShown:
          json['firstLaunchPromptShown'] as bool? ?? (updatedAtText != null),
      themeId: json['themeId'] as String? ?? defaults.themeId,
      updatedAt: updatedAtText == null
          ? null
          : DateTime.tryParse(updatedAtText),
    );
  }
}

class AppSyncConflict {
  const AppSyncConflict({
    required this.type,
    required this.clientId,
    required this.reason,
    this.localUpdatedAt,
    this.serverUpdatedAt,
    this.serverDeletedAt,
    this.serverData = const <String, Object?>{},
    this.localData = const <String, Object?>{},
  });

  final String type;
  final String clientId;
  final String reason;
  final DateTime? localUpdatedAt;
  final DateTime? serverUpdatedAt;
  final DateTime? serverDeletedAt;
  final Map<String, Object?> serverData;
  final Map<String, Object?> localData;

  String get key => '$type:$clientId';

  Map<String, Object?> toJson() {
    return {
      'type': type,
      'clientId': clientId,
      'reason': reason,
      'localUpdatedAt': localUpdatedAt?.toIso8601String(),
      'serverUpdatedAt': serverUpdatedAt?.toIso8601String(),
      'serverDeletedAt': serverDeletedAt?.toIso8601String(),
      'serverData': serverData,
      'localData': localData,
    };
  }

  factory AppSyncConflict.fromJson(Map<String, Object?> json) {
    return AppSyncConflict(
      type: json['type'] as String? ?? '',
      clientId: json['clientId'] as String? ?? '',
      reason: json['reason'] as String? ?? 'server_newer',
      localUpdatedAt: _parseOptionalDateTime(json['localUpdatedAt']),
      serverUpdatedAt: _parseOptionalDateTime(json['serverUpdatedAt']),
      serverDeletedAt: _parseOptionalDateTime(json['serverDeletedAt']),
      serverData: _readObjectMap(json['serverData']),
      localData: _readObjectMap(json['localData']),
    );
  }

  factory AppSyncConflict.fromServerJson(
    Map<dynamic, dynamic> json, {
    AppSyncQueueItem? localItem,
  }) {
    final serverItem = _readDynamicMap(json['serverItem']);
    return AppSyncConflict(
      type: json['type'] as String? ?? localItem?.type ?? '',
      clientId: json['clientId'] as String? ?? localItem?.clientId ?? '',
      reason: json['reason'] as String? ?? 'server_newer',
      localUpdatedAt: localItem?.clientUpdatedAt,
      serverUpdatedAt: _parseOptionalDateTime(serverItem['serverUpdatedAt']),
      serverDeletedAt: _parseOptionalDateTime(serverItem['deletedAt']),
      serverData: _readObjectMap(serverItem['data']),
      localData: localItem?.data ?? const <String, Object?>{},
    );
  }
}

class AppSyncStatus {
  const AppSyncStatus({
    this.lastStartedAt,
    this.lastFinishedAt,
    this.lastSuccessAt,
    this.lastFailureAt,
    this.lastError,
    this.lastPushed = 0,
    this.lastPulled = 0,
    this.lastConflictCount = 0,
    this.lastConflicts = const <AppSyncConflict>[],
    this.pendingCount = 0,
    this.running = false,
  });

  final DateTime? lastStartedAt;
  final DateTime? lastFinishedAt;
  final DateTime? lastSuccessAt;
  final DateTime? lastFailureAt;
  final String? lastError;
  final int lastPushed;
  final int lastPulled;
  final int lastConflictCount;
  final List<AppSyncConflict> lastConflicts;
  final int pendingCount;
  final bool running;

  bool get hasSuccess => lastSuccessAt != null && lastError == null;
  bool get hasFailure => lastError != null && lastError!.isNotEmpty;
  bool get hasConflicts => lastConflicts.isNotEmpty || lastConflictCount > 0;

  AppSyncStatus copyWith({
    DateTime? lastStartedAt,
    DateTime? lastFinishedAt,
    DateTime? lastSuccessAt,
    DateTime? lastFailureAt,
    Object? lastError = _copySentinel,
    int? lastPushed,
    int? lastPulled,
    int? lastConflictCount,
    List<AppSyncConflict>? lastConflicts,
    int? pendingCount,
    bool? running,
  }) {
    return AppSyncStatus(
      lastStartedAt: lastStartedAt ?? this.lastStartedAt,
      lastFinishedAt: lastFinishedAt ?? this.lastFinishedAt,
      lastSuccessAt: lastSuccessAt ?? this.lastSuccessAt,
      lastFailureAt: lastFailureAt ?? this.lastFailureAt,
      lastError: identical(lastError, _copySentinel)
          ? this.lastError
          : lastError as String?,
      lastPushed: lastPushed ?? this.lastPushed,
      lastPulled: lastPulled ?? this.lastPulled,
      lastConflictCount: lastConflictCount ?? this.lastConflictCount,
      lastConflicts: lastConflicts ?? this.lastConflicts,
      pendingCount: pendingCount ?? this.pendingCount,
      running: running ?? this.running,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'lastStartedAt': lastStartedAt?.toIso8601String(),
      'lastFinishedAt': lastFinishedAt?.toIso8601String(),
      'lastSuccessAt': lastSuccessAt?.toIso8601String(),
      'lastFailureAt': lastFailureAt?.toIso8601String(),
      'lastError': lastError,
      'lastPushed': lastPushed,
      'lastPulled': lastPulled,
      'lastConflictCount': lastConflictCount,
      'lastConflicts': lastConflicts.map((item) => item.toJson()).toList(),
      'pendingCount': pendingCount,
      'running': running,
    };
  }

  static AppSyncStatus fromJson(Map<String, Object?> json) {
    DateTime? parseTime(String key) {
      final value = json[key] as String?;
      return value == null ? null : DateTime.tryParse(value);
    }

    final rawConflicts = json['lastConflicts'];
    return AppSyncStatus(
      lastStartedAt: parseTime('lastStartedAt'),
      lastFinishedAt: parseTime('lastFinishedAt'),
      lastSuccessAt: parseTime('lastSuccessAt'),
      lastFailureAt: parseTime('lastFailureAt'),
      lastError: json['lastError'] as String?,
      lastPushed: (json['lastPushed'] as num?)?.toInt() ?? 0,
      lastPulled: (json['lastPulled'] as num?)?.toInt() ?? 0,
      lastConflictCount: (json['lastConflictCount'] as num?)?.toInt() ?? 0,
      lastConflicts: rawConflicts is List
          ? rawConflicts
                .whereType<Map>()
                .map(
                  (item) =>
                      AppSyncConflict.fromJson(item.cast<String, Object?>()),
                )
                .toList()
          : const <AppSyncConflict>[],
      pendingCount: (json['pendingCount'] as num?)?.toInt() ?? 0,
      running: json['running'] as bool? ?? false,
    );
  }
}

class AppDataBackup {
  const AppDataBackup({
    required this.id,
    required this.createdAt,
    required this.filePath,
    required this.bytes,
    required this.itemCount,
  });

  final String id;
  final DateTime createdAt;
  final String filePath;
  final int bytes;
  final int itemCount;

  AppDataBackup copyWith({
    String? id,
    DateTime? createdAt,
    String? filePath,
    int? bytes,
    int? itemCount,
  }) {
    return AppDataBackup(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      filePath: filePath ?? this.filePath,
      bytes: bytes ?? this.bytes,
      itemCount: itemCount ?? this.itemCount,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'createdAt': createdAt.toIso8601String(),
      'filePath': filePath,
      'bytes': bytes,
      'itemCount': itemCount,
    };
  }

  static AppDataBackup fromJson(Map<String, Object?> json) {
    return AppDataBackup(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      filePath: json['filePath'] as String,
      bytes: (json['bytes'] as num?)?.toInt() ?? 0,
      itemCount: (json['itemCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class AppDataRecoveryNotice {
  const AppDataRecoveryNotice({
    required this.id,
    required this.detectedAt,
    required this.corruptFilePath,
    required this.restoredFromBackup,
    this.restoredBackupPath,
    this.errorMessage,
  });

  final String id;
  final DateTime detectedAt;
  final String corruptFilePath;
  final bool restoredFromBackup;
  final String? restoredBackupPath;
  final String? errorMessage;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'detectedAt': detectedAt.toIso8601String(),
      'corruptFilePath': corruptFilePath,
      'restoredFromBackup': restoredFromBackup,
      'restoredBackupPath': restoredBackupPath,
      'errorMessage': errorMessage,
    };
  }

  static AppDataRecoveryNotice fromJson(Map<String, Object?> json) {
    return AppDataRecoveryNotice(
      id: json['id'] as String,
      detectedAt: DateTime.parse(json['detectedAt'] as String),
      corruptFilePath: json['corruptFilePath'] as String,
      restoredFromBackup: json['restoredFromBackup'] as bool? ?? false,
      restoredBackupPath: json['restoredBackupPath'] as String?,
      errorMessage: json['errorMessage'] as String?,
    );
  }
}

class AppAuthSession {
  const AppAuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.username,
    required this.role,
    required this.updatedAt,
  });

  final String accessToken;
  final String refreshToken;
  final String userId;
  final String username;
  final String role;
  final DateTime updatedAt;

  bool get isSignedIn => accessToken.isNotEmpty && refreshToken.isNotEmpty;

  Map<String, Object?> toJson() {
    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'userId': userId,
      'username': username,
      'role': role,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  static AppAuthSession fromJson(Map<String, Object?> json) {
    final updatedAtText = json['updatedAt'] as String?;
    return AppAuthSession(
      accessToken: json['accessToken'] as String? ?? '',
      refreshToken: json['refreshToken'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      username: json['username'] as String? ?? '',
      role: json['role'] as String? ?? '',
      updatedAt: updatedAtText == null
          ? DateTime.now()
          : DateTime.tryParse(updatedAtText) ?? DateTime.now(),
    );
  }
}

class AppSyncQueueItem {
  const AppSyncQueueItem({
    required this.id,
    required this.type,
    required this.clientId,
    required this.clientUpdatedAt,
    required this.data,
    this.deletedAt,
  });

  final String id;
  final String type;
  final String clientId;
  final DateTime clientUpdatedAt;
  final Map<String, Object?> data;
  final DateTime? deletedAt;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'type': type,
      'clientId': clientId,
      'clientUpdatedAt': clientUpdatedAt.toIso8601String(),
      'deletedAt': deletedAt?.toIso8601String(),
      'data': data,
    };
  }

  static AppSyncQueueItem fromJson(Map<String, Object?> json) {
    final deletedAtText = json['deletedAt'] as String?;
    return AppSyncQueueItem(
      id: json['id'] as String,
      type: json['type'] as String,
      clientId: json['clientId'] as String,
      clientUpdatedAt: DateTime.parse(json['clientUpdatedAt'] as String),
      deletedAt: deletedAtText == null
          ? null
          : DateTime.tryParse(deletedAtText),
      data: (json['data'] as Map<dynamic, dynamic>? ?? const {})
          .cast<String, Object?>(),
    );
  }
}

class AppMemo {
  const AppMemo({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.mood,
    this.tags = const <String>[],
    this.remindAt,
    this.imagePaths = const <String>[],
    this.imageMediaIds = const <String>[],
    this.draft = false,
    this.pinned = false,
  });

  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? mood;
  final List<String> tags;
  final DateTime? remindAt;
  final List<String> imagePaths;
  final List<String> imageMediaIds;
  final bool draft;
  final bool pinned;

  AppMemo copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? mood = _copySentinel,
    List<String>? tags,
    Object? remindAt = _copySentinel,
    List<String>? imagePaths,
    List<String>? imageMediaIds,
    bool? draft,
    bool? pinned,
  }) {
    return AppMemo(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      mood: identical(mood, _copySentinel) ? this.mood : mood as String?,
      tags: tags ?? this.tags,
      remindAt: identical(remindAt, _copySentinel)
          ? this.remindAt
          : remindAt as DateTime?,
      imagePaths: imagePaths ?? this.imagePaths,
      imageMediaIds: imageMediaIds ?? this.imageMediaIds,
      draft: draft ?? this.draft,
      pinned: pinned ?? this.pinned,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'mood': mood,
      'tags': tags,
      'remindAt': remindAt?.toIso8601String(),
      'imagePaths': imagePaths,
      'imageMediaIds': imageMediaIds,
      'draft': draft,
      'pinned': pinned,
    };
  }

  static AppMemo fromJson(Map<String, Object?> json) {
    final createdAt = DateTime.parse(json['createdAt'] as String);
    final updatedAtText = json['updatedAt'] as String?;
    final rawContent = json['content'] as String? ?? '';
    final legacyMood = _legacyMarkerValue(rawContent, 'mood');
    final legacyTags = _legacyMarkerValue(rawContent, 'tags')
        ?.split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
    final legacyRemindAt = _legacyMarkerValue(rawContent, 'remindAt');
    return AppMemo(
      id: json['id'] as String,
      title: json['title'] as String? ?? '未命名备忘',
      content: _stripLegacyMemoMarkers(rawContent),
      createdAt: createdAt,
      updatedAt: updatedAtText == null
          ? createdAt
          : DateTime.tryParse(updatedAtText) ?? createdAt,
      mood: json['mood'] as String? ?? legacyMood,
      tags: _readStringList(json['tags'], fallback: legacyTags),
      remindAt:
          _parseOptionalDateTime(json['remindAt']) ??
          _parseOptionalDateTime(legacyRemindAt),
      imagePaths: _readStringList(json['imagePaths']),
      imageMediaIds: _readStringList(json['imageMediaIds']),
      draft: json['draft'] as bool? ?? rawContent.contains('[draft]'),
      pinned: json['pinned'] as bool? ?? false,
    );
  }

  static String? _legacyMarkerValue(String content, String key) {
    return RegExp('\\[$key:([^\\]]+)\\]').firstMatch(content)?.group(1);
  }

  static String _stripLegacyMemoMarkers(String content) {
    return content
        .replaceAll('[image]', '')
        .replaceAll('[draft]', '')
        .replaceAll(RegExp(r'\[mood:[^\]]+\]'), '')
        .replaceAll(RegExp(r'\[tags:[^\]]+\]'), '')
        .replaceAll(RegExp(r'\[remindAt:[^\]]+\]'), '')
        .trim()
        .replaceAll(RegExp(r'\n{3,}'), '\n\n');
  }

  static List<String> _readStringList(Object? value, {List<String>? fallback}) {
    if (value is List) {
      return value
          .whereType<String>()
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    return fallback ?? const <String>[];
  }
}

class AppAiMessage {
  const AppAiMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String role;
  final String content;
  final DateTime createdAt;

  bool get isUser => role == 'user';

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'role': role,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static AppAiMessage fromJson(Map<String, Object?> json) {
    return AppAiMessage(
      id: json['id'] as String,
      role: json['role'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class AppEntry {
  const AppEntry({
    required this.id,
    required this.kind,
    required this.title,
    required this.content,
    required this.mood,
    required this.createdAt,
    required this.favorite,
    required this.mascotVariant,
    this.kindLabel,
    this.moodEmoji = '😊',
    this.location,
    this.tags = const <String>[],
    this.draft = false,
    this.imagePaths = const [],
    this.imageMediaIds = const [],
  });

  final String id;
  final String kind;
  final String? kindLabel;
  final String title;
  final String content;
  final String mood;
  final String moodEmoji;
  final String? location;
  final List<String> tags;
  final bool draft;
  final List<String> imagePaths;
  // 已上传到服务端的 mediaId 列表，与 imagePaths 按下标对齐；
  // 未上传或离线保存时对应位置存空字符串。
  final List<String> imageMediaIds;
  final DateTime createdAt;
  final bool favorite;
  final String mascotVariant;

  AppEntry copyWith({
    String? id,
    String? kind,
    String? kindLabel,
    String? title,
    String? content,
    String? mood,
    String? moodEmoji,
    Object? location = _copySentinel,
    List<String>? tags,
    bool? draft,
    List<String>? imagePaths,
    List<String>? imageMediaIds,
    DateTime? createdAt,
    bool? favorite,
    String? mascotVariant,
  }) {
    return AppEntry(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      kindLabel: kindLabel ?? this.kindLabel,
      title: title ?? this.title,
      content: content ?? this.content,
      mood: mood ?? this.mood,
      moodEmoji: moodEmoji ?? this.moodEmoji,
      location: identical(location, _copySentinel)
          ? this.location
          : location as String?,
      tags: tags ?? this.tags,
      draft: draft ?? this.draft,
      imagePaths: imagePaths ?? this.imagePaths,
      imageMediaIds: imageMediaIds ?? this.imageMediaIds,
      createdAt: createdAt ?? this.createdAt,
      favorite: favorite ?? this.favorite,
      mascotVariant: mascotVariant ?? this.mascotVariant,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'kind': kind,
      'kindLabel': kindLabel,
      'title': title,
      'content': content,
      'mood': mood,
      'moodEmoji': moodEmoji,
      'location': location,
      'tags': tags,
      'draft': draft,
      'imagePaths': imagePaths,
      'imageMediaIds': imageMediaIds,
      'createdAt': createdAt.toIso8601String(),
      'favorite': favorite,
      'mascotVariant': mascotVariant,
    };
  }

  static AppEntry fromJson(Map<String, Object?> json) {
    final rawContent = json['content'] as String? ?? '';
    final legacyLocation = _legacyMarkerValue(rawContent, 'location');
    final legacyTags = _legacyMarkerValue(rawContent, 'tags')
        ?.split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList(growable: false);
    return AppEntry(
      id: json['id'] as String,
      kind: json['kind'] as String,
      kindLabel: json['kindLabel'] as String?,
      title: json['title'] as String,
      content: _stripLegacyEntryMarkers(rawContent),
      mood: json['mood'] as String,
      moodEmoji:
          json['moodEmoji'] as String? ??
          _emojiForMood(json['mood'] as String? ?? '开心'),
      location: json['location'] as String? ?? legacyLocation,
      tags: _readStringList(json['tags'], fallback: legacyTags),
      draft: json['draft'] as bool? ?? false,
      imagePaths: _readStringList(json['imagePaths']),
      imageMediaIds: _readStringList(json['imageMediaIds']),
      createdAt: DateTime.parse(json['createdAt'] as String),
      favorite: json['favorite'] as bool,
      mascotVariant: json['mascotVariant'] as String,
    );
  }

  static String? _legacyMarkerValue(String content, String key) {
    return RegExp('\\[$key:([^\\]]+)\\]').firstMatch(content)?.group(1);
  }

  static String _stripLegacyEntryMarkers(String content) {
    return content
        .replaceAll(RegExp(r'\[location:[^\]]+\]'), '')
        .replaceAll(RegExp(r'\[tags:[^\]]+\]'), '')
        .trim()
        .replaceAll(RegExp(r'\n{3,}'), '\n\n');
  }

  static List<String> _readStringList(Object? value, {List<String>? fallback}) {
    if (value is List) {
      return value
          .whereType<String>()
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    return fallback ?? const <String>[];
  }

  static String _emojiForMood(String mood) {
    return switch (mood) {
      '开心' => '😊',
      '平静' => '🌿',
      '期待' => '✨',
      '想念' => '💗',
      '疲惫' => '😴',
      '难过' => '🥲',
      '生气' => '😤',
      '治愈' => '🍵',
      _ => '😊',
    };
  }

  static const seed = <AppEntry>[];
}

class AppReminder {
  const AppReminder({
    required this.id,
    required this.title,
    required this.scheduledAt,
    required this.repeatRule,
    required this.notifyBeforeMinutes,
    required this.pinned,
    required this.priority,
    required this.icon,
    this.completed = false,
    this.doneDateKey,
  });

  final String id;
  final String title;
  final DateTime scheduledAt;
  final String repeatRule;
  final int notifyBeforeMinutes;
  final bool pinned;
  final String priority;
  final String icon;
  final bool completed;
  final String? doneDateKey;

  AppReminder copyWith({
    String? id,
    String? title,
    DateTime? scheduledAt,
    String? repeatRule,
    int? notifyBeforeMinutes,
    bool? pinned,
    String? priority,
    String? icon,
    bool? completed,
    String? doneDateKey,
  }) {
    return AppReminder(
      id: id ?? this.id,
      title: title ?? this.title,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      repeatRule: repeatRule ?? this.repeatRule,
      notifyBeforeMinutes: notifyBeforeMinutes ?? this.notifyBeforeMinutes,
      pinned: pinned ?? this.pinned,
      priority: priority ?? this.priority,
      icon: icon ?? this.icon,
      completed: completed ?? this.completed,
      doneDateKey: doneDateKey ?? this.doneDateKey,
    );
  }

  bool isDoneForDate(DateTime date) {
    return doneDateKey == dateKey(date);
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'title': title,
      'scheduledAt': scheduledAt.toIso8601String(),
      'repeatRule': repeatRule,
      'notifyBeforeMinutes': notifyBeforeMinutes,
      'pinned': pinned,
      'priority': priority,
      'icon': icon,
      'completed': completed,
      'doneDateKey': doneDateKey,
    };
  }

  static AppReminder fromJson(Map<String, Object?> json) {
    return AppReminder(
      id: json['id'] as String,
      title: json['title'] as String,
      scheduledAt: DateTime.parse(json['scheduledAt'] as String),
      repeatRule: json['repeatRule'] as String,
      notifyBeforeMinutes: json['notifyBeforeMinutes'] as int,
      pinned: json['pinned'] as bool,
      priority: json['priority'] as String,
      icon: json['icon'] as String,
      completed: json['completed'] as bool? ?? false,
      doneDateKey: json['doneDateKey'] as String?,
    );
  }

  static String dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  static const seed = <AppReminder>[];
}

class AppAnniversary {
  const AppAnniversary({
    required this.id,
    required this.title,
    required this.date,
    required this.category,
    required this.colorName,
    required this.mascotVariant,
    this.imagePath,
    this.note = '',
    this.showCountUp = false,
    this.pinnedOnHome = false,
  });

  final String id;
  final String title;
  final DateTime date;
  final String category;
  final String colorName;
  final String mascotVariant;
  final String? imagePath;
  final String note;
  final bool showCountUp;
  final bool pinnedOnHome;

  AppAnniversary copyWith({
    String? id,
    String? title,
    DateTime? date,
    String? category,
    String? colorName,
    String? mascotVariant,
    Object? imagePath = _copySentinel,
    String? note,
    bool? showCountUp,
    bool? pinnedOnHome,
  }) {
    return AppAnniversary(
      id: id ?? this.id,
      title: title ?? this.title,
      date: date ?? this.date,
      category: category ?? this.category,
      colorName: colorName ?? this.colorName,
      mascotVariant: mascotVariant ?? this.mascotVariant,
      imagePath: identical(imagePath, _copySentinel)
          ? this.imagePath
          : imagePath as String?,
      note: note ?? this.note,
      showCountUp: showCountUp ?? this.showCountUp,
      pinnedOnHome: pinnedOnHome ?? this.pinnedOnHome,
    );
  }

  int daysLeft(DateTime now) {
    final target = DateTime(now.year, date.month, date.day);
    final next = target.isBefore(DateTime(now.year, now.month, now.day))
        ? DateTime(now.year + 1, date.month, date.day)
        : target;
    return next.difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  int daysPassed(DateTime now) {
    final start = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);
    if (today.isBefore(start)) {
      return 0;
    }
    return today.difference(start).inDays + 1;
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'title': title,
      'date': date.toIso8601String(),
      'category': category,
      'colorName': colorName,
      'mascotVariant': mascotVariant,
      'imagePath': imagePath,
      'note': note,
      'showCountUp': showCountUp,
      'pinnedOnHome': pinnedOnHome,
    };
  }

  static AppAnniversary fromJson(Map<String, Object?> json) {
    return AppAnniversary(
      id: json['id'] as String,
      title: json['title'] as String,
      date: DateTime.parse(json['date'] as String),
      category: json['category'] as String,
      colorName: json['colorName'] as String,
      mascotVariant: json['mascotVariant'] as String,
      imagePath: json['imagePath'] as String?,
      note: json['note'] as String? ?? '',
      showCountUp: json['showCountUp'] as bool? ?? false,
      pinnedOnHome: json['pinnedOnHome'] as bool? ?? false,
    );
  }

  static const seed = <AppAnniversary>[];
}

AppAnniversary? selectHomeAnniversary(
  List<AppAnniversary> anniversaries,
  DateTime now,
) {
  if (anniversaries.isEmpty) {
    return null;
  }
  final pinned = anniversaries.where((item) => item.pinnedOnHome).toList();
  final candidates = pinned.isEmpty ? [...anniversaries] : pinned;
  candidates.sort((a, b) => a.daysLeft(now).compareTo(b.daysLeft(now)));
  return candidates.first;
}

DateTime? _parseOptionalDateTime(Object? value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}

Map<dynamic, dynamic> _readDynamicMap(Object? value) {
  if (value is Map<dynamic, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.cast<dynamic, dynamic>();
  }
  return const <dynamic, dynamic>{};
}

Map<String, Object?> _readObjectMap(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const <String, Object?>{};
}

const Object _copySentinel = Object();

class AppCoupleTask {
  const AppCoupleTask({
    required this.id,
    required this.index,
    required this.title,
    this.completed = false,
    this.completedAt,
    this.imagePath,
  });

  final String id;
  final int index;
  final String title;
  final bool completed;
  final DateTime? completedAt;
  final String? imagePath;

  AppCoupleTask copyWith({
    String? id,
    int? index,
    String? title,
    bool? completed,
    Object? completedAt = _copySentinel,
    Object? imagePath = _copySentinel,
  }) {
    return AppCoupleTask(
      id: id ?? this.id,
      index: index ?? this.index,
      title: title ?? this.title,
      completed: completed ?? this.completed,
      completedAt: identical(completedAt, _copySentinel)
          ? this.completedAt
          : completedAt as DateTime?,
      imagePath: identical(imagePath, _copySentinel)
          ? this.imagePath
          : imagePath as String?,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'index': index,
      'title': title,
      'completed': completed,
      'completedAt': completedAt?.toIso8601String(),
      'imagePath': imagePath,
    };
  }

  static AppCoupleTask fromJson(Map<String, Object?> json) {
    final completedAtText = json['completedAt'] as String?;
    return AppCoupleTask(
      id: json['id'] as String,
      index: json['index'] as int,
      title: json['title'] as String,
      completed: json['completed'] as bool? ?? false,
      completedAt: completedAtText == null
          ? null
          : DateTime.tryParse(completedAtText),
      imagePath: json['imagePath'] as String?,
    );
  }

  static const seed = <AppCoupleTask>[];
}

class AppWeeklyGoal {
  const AppWeeklyGoal({
    required this.id,
    required this.title,
    required this.targetValue,
    required this.currentValue,
    required this.unit,
    required this.iconName,
    required this.colorName,
    this.period = 'week',
    this.lastCheckInDateKey,
    this.dailyProgress = const <String, double>{},
  });

  final String id;
  final String title;
  final double targetValue;
  final double currentValue;
  final String unit;
  final String iconName;
  final String colorName;
  final String period;
  final String? lastCheckInDateKey;
  final Map<String, double> dailyProgress;

  double get progress {
    if (targetValue <= 0) {
      return 0;
    }
    return (currentValue / targetValue).clamp(0, 1);
  }

  AppWeeklyGoal copyWith({
    String? id,
    String? title,
    double? targetValue,
    double? currentValue,
    String? unit,
    String? iconName,
    String? colorName,
    String? period,
    String? lastCheckInDateKey,
    Map<String, double>? dailyProgress,
  }) {
    return AppWeeklyGoal(
      id: id ?? this.id,
      title: title ?? this.title,
      targetValue: targetValue ?? this.targetValue,
      currentValue: currentValue ?? this.currentValue,
      unit: unit ?? this.unit,
      iconName: iconName ?? this.iconName,
      colorName: colorName ?? this.colorName,
      period: period ?? this.period,
      lastCheckInDateKey: lastCheckInDateKey ?? this.lastCheckInDateKey,
      dailyProgress: dailyProgress ?? this.dailyProgress,
    );
  }

  bool isCheckedInForDate(DateTime date) {
    return lastCheckInDateKey == dateKey(date);
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'title': title,
      'targetValue': targetValue,
      'currentValue': currentValue,
      'unit': unit,
      'iconName': iconName,
      'colorName': colorName,
      'period': period,
      'lastCheckInDateKey': lastCheckInDateKey,
      'dailyProgress': dailyProgress,
    };
  }

  static AppWeeklyGoal fromJson(Map<String, Object?> json) {
    return AppWeeklyGoal(
      id: json['id'] as String,
      title: json['title'] as String,
      targetValue: (json['targetValue'] as num).toDouble(),
      currentValue: (json['currentValue'] as num).toDouble(),
      unit: json['unit'] as String,
      iconName: json['iconName'] as String? ?? 'run',
      colorName: json['colorName'] as String? ?? 'green',
      period: json['period'] as String? ?? 'week',
      lastCheckInDateKey: json['lastCheckInDateKey'] as String?,
      dailyProgress: _readDoubleMap(json['dailyProgress']),
    );
  }

  AppWeeklyGoal recordProgressForDate(DateTime date, double value) {
    return copyWith(
      dailyProgress: {
        ...dailyProgress,
        dateKey(date): value.clamp(0, targetValue).toDouble(),
      },
    );
  }

  double progressForDate(DateTime date) {
    return dailyProgress[dateKey(date)] ?? 0;
  }

  static String dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  static Map<String, double> _readDoubleMap(Object? value) {
    if (value is Map<String, Object?>) {
      return value.map(
        (key, item) => MapEntry(key, item is num ? item.toDouble() : 0),
      );
    }
    if (value is Map) {
      return value.map(
        (key, item) =>
            MapEntry(key.toString(), item is num ? item.toDouble() : 0),
      );
    }
    return const <String, double>{};
  }

  static const seed = <AppWeeklyGoal>[];
}

class AppMoneyRecord {
  const AppMoneyRecord({
    required this.id,
    required this.type,
    required this.title,
    required this.amountCents,
    required this.category,
    required this.happenedAt,
    required this.createdAt,
    required this.updatedAt,
    this.note = '',
    this.owner = 'shared',
    this.paymentMethod = '现金',
  });

  final String id;
  final String type;
  final String title;
  final int amountCents;
  final String category;
  final DateTime happenedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String note;
  final String owner;
  final String paymentMethod;

  bool get isIncome => type == 'income';
  bool get isExpense => !isIncome;
  int get signedAmountCents => isIncome ? amountCents : -amountCents;

  AppMoneyRecord copyWith({
    String? id,
    String? type,
    String? title,
    int? amountCents,
    String? category,
    DateTime? happenedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? note,
    String? owner,
    String? paymentMethod,
  }) {
    return AppMoneyRecord(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      amountCents: amountCents ?? this.amountCents,
      category: category ?? this.category,
      happenedAt: happenedAt ?? this.happenedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      note: note ?? this.note,
      owner: owner ?? this.owner,
      paymentMethod: paymentMethod ?? this.paymentMethod,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'amountCents': amountCents,
      'category': category,
      'happenedAt': happenedAt.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'note': note,
      'owner': owner,
      'paymentMethod': paymentMethod,
    };
  }

  static AppMoneyRecord fromJson(Map<String, Object?> json) {
    final now = DateTime.now();
    final createdAtText = json['createdAt'] as String?;
    final updatedAtText = json['updatedAt'] as String?;
    final happenedAtText = json['happenedAt'] as String?;
    final type = json['type'] as String? ?? 'expense';
    return AppMoneyRecord(
      id: json['id'] as String,
      type: type == 'income' ? 'income' : 'expense',
      title: json['title'] as String? ?? '未命名账目',
      amountCents: _readAmountCents(json),
      category: json['category'] as String? ?? (type == 'income' ? '工资' : '日常'),
      happenedAt: happenedAtText == null
          ? now
          : DateTime.tryParse(happenedAtText) ?? now,
      createdAt: createdAtText == null
          ? now
          : DateTime.tryParse(createdAtText) ?? now,
      updatedAt: updatedAtText == null
          ? DateTime.tryParse(createdAtText ?? '') ?? now
          : DateTime.tryParse(updatedAtText) ?? now,
      note: json['note'] as String? ?? '',
      owner: json['owner'] as String? ?? 'shared',
      paymentMethod: json['paymentMethod'] as String? ?? '现金',
    );
  }

  static int _readAmountCents(Map<String, Object?> json) {
    final cents = json['amountCents'];
    if (cents is num) {
      return cents.toInt().abs();
    }
    final amount = json['amount'];
    if (amount is num) {
      return (amount * 100).round().abs();
    }
    return 0;
  }
}

class AppMoneySummary {
  const AppMoneySummary({
    required this.incomeCents,
    required this.expenseCents,
    required this.recordCount,
  });

  final int incomeCents;
  final int expenseCents;
  final int recordCount;

  int get balanceCents => incomeCents - expenseCents;
}

AppMoneySummary summarizeMoneyRecords(
  List<AppMoneyRecord> records, {
  DateTime? month,
}) {
  var incomeCents = 0;
  var expenseCents = 0;
  var recordCount = 0;

  for (final record in records) {
    if (month != null &&
        (record.happenedAt.year != month.year ||
            record.happenedAt.month != month.month)) {
      continue;
    }
    recordCount += 1;
    if (record.isIncome) {
      incomeCents += record.amountCents;
    } else {
      expenseCents += record.amountCents;
    }
  }

  return AppMoneySummary(
    incomeCents: incomeCents,
    expenseCents: expenseCents,
    recordCount: recordCount,
  );
}

class AppPlace {
  const AppPlace({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.colorName,
    this.imagePath,
    this.imageMediaId,
  });

  final String id;
  final String title;
  final String description;
  final String category;
  final String colorName;
  final String? imagePath;
  // 已上传到服务端的 mediaId，本地新增/编辑时由上层负责填充。
  final String? imageMediaId;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'colorName': colorName,
      'imagePath': imagePath,
      'imageMediaId': imageMediaId,
    };
  }

  static AppPlace fromJson(Map<String, Object?> json) {
    return AppPlace(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      category: json['category'] as String? ?? _categoryFromLegacyTags(json),
      colorName: json['colorName'] as String,
      imagePath: json['imagePath'] as String?,
      imageMediaId: json['imageMediaId'] as String?,
    );
  }

  static String _categoryFromLegacyTags(Map<String, Object?> json) {
    final tags = (json['tags'] as List<dynamic>? ?? const []).cast<String>();
    if (tags.contains('约会') || tags.contains('甜品')) {
      return 'date';
    }
    return 'travel';
  }

  static const seed = <AppPlace>[];
}
