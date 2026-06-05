import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../data/app_data_store.dart';

const _confirmReminderActionId = 'confirm_reminder';
const _confirmAllDueActionId = 'confirm_all_due_reminders';
const _notificationPayloadOpenReminders = 'open:reminders';
const _notificationPayloadOpenDailyComic = 'open:daily-comic';
const _notificationPayloadOpenMemos = 'open:memos';
const _notificationPayloadReminderPrefix = 'reminder:';

class ReminderNotificationIntentRequest {
  const ReminderNotificationIntentRequest._({
    this.reminderId,
    required this.confirmFirstDueReminder,
  });

  factory ReminderNotificationIntentRequest.reminder(String reminderId) {
    return ReminderNotificationIntentRequest._(
      reminderId: reminderId,
      confirmFirstDueReminder: false,
    );
  }

  factory ReminderNotificationIntentRequest.firstDueReminder() {
    return const ReminderNotificationIntentRequest._(
      confirmFirstDueReminder: true,
    );
  }

  final String? reminderId;
  final bool confirmFirstDueReminder;
}

class ReminderNotificationIntent extends ChangeNotifier {
  ReminderNotificationIntent._();

  static final instance = ReminderNotificationIntent._();

  ReminderNotificationIntentRequest? _pending;

  bool get hasPending => _pending != null;

  void requestReminderConfirmation(String reminderId) {
    _pending = ReminderNotificationIntentRequest.reminder(reminderId);
    notifyListeners();
  }

  void requestFirstDueReminderConfirmation() {
    _pending = ReminderNotificationIntentRequest.firstDueReminder();
    notifyListeners();
  }

  ReminderNotificationIntentRequest? take() {
    final pending = _pending;
    _pending = null;
    return pending;
  }
}

class MemoNotificationIntent extends ChangeNotifier {
  MemoNotificationIntent._();

  static final instance = MemoNotificationIntent._();

  bool _pending = false;

  bool get hasPending => _pending;

  void requestOpenMemos() {
    _pending = true;
    notifyListeners();
  }

  bool take() {
    final pending = _pending;
    _pending = false;
    return pending;
  }
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  unawaited(LocalNotificationService.handleNotificationResponse(response));
}

class LocalNotificationService {
  LocalNotificationService._();

  static final instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  Future<void>? _initializing;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    final running = _initializing;
    if (running != null) {
      await running;
      return;
    }
    _initializing = _initializePlugin();
    try {
      await _initializing;
    } finally {
      _initializing = null;
    }
  }

  Future<void> _initializePlugin() async {
    tz.initializeTimeZones();
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
    try {
      await _handleLaunchNotification().timeout(const Duration(seconds: 4));
    } catch (_) {}
    _initialized = true;
  }

  Future<bool> areNotificationsEnabled() async {
    try {
      await initialize().timeout(const Duration(seconds: 6));
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.areNotificationsEnabled().timeout(
            const Duration(seconds: 6),
          ) ??
          true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestNotificationsPermission() async {
    try {
      await initialize().timeout(const Duration(seconds: 6));
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final granted = await android?.requestNotificationsPermission().timeout(
        const Duration(seconds: 8),
      );
      return granted ?? await areNotificationsEnabled();
    } catch (_) {
      return false;
    }
  }

  Future<void> scheduleMemoReminder(AppMemo memo) async {
    final remindAt = memo.remindAt;
    if (remindAt == null || memo.draft) {
      await cancelMemoReminder(memo.id);
      return;
    }
    final settings = (await AppLocalStore.create()).getSettings();
    if (!settings.notificationsEnabled || !remindAt.isAfter(DateTime.now())) {
      await cancelMemoReminder(memo.id);
      return;
    }
    await initialize();
    await cancelMemoReminder(memo.id);
    await _plugin.zonedSchedule(
      _memoNotificationId(memo.id),
      '备忘提醒',
      memo.title,
      tz.TZDateTime.from(remindAt, tz.local),
      NotificationDetails(
        android: _androidNotificationDetails(
          'xiaotai_memo_reminders',
          '备忘提醒',
          channelDescription: '备忘录设置的单次提醒',
          importance: Importance.high,
          priority: Priority.high,
          settings: settings,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: _notificationPayloadOpenMemos,
    );
  }

  Future<void> cancelMemoReminder(String memoId) async {
    await initialize();
    await _plugin.cancel(_memoNotificationId(memoId));
  }

  Future<void> syncMemoReminders(List<AppMemo> memos) async {
    for (final memo in memos) {
      if (memo.remindAt == null || memo.draft) {
        await cancelMemoReminder(memo.id);
      } else {
        await scheduleMemoReminder(memo);
      }
    }
  }

  Future<void> scheduleReminder(AppReminder reminder) async {
    if (reminder.completed) {
      await cancelReminder(reminder.id);
      return;
    }
    final settings = (await AppLocalStore.create()).getSettings();
    if (!settings.notificationsEnabled) {
      await cancelReminder(reminder.id);
      return;
    }
    await initialize();
    await cancelReminder(reminder.id);
    final now = DateTime.now();
    if (reminder.pinned && !reminder.isDoneForDate(now)) {
      await _showPinnedReminder(reminder);
    }
    final firstAlertAt = reminder.scheduledAt.subtract(
      Duration(minutes: reminder.notifyBeforeMinutes),
    );
    final scheduleAt = firstAlertAt.isAfter(now)
        ? firstAlertAt
        : reminder.scheduledAt;
    if (!scheduleAt.isAfter(now)) {
      return;
    }
    await _plugin.zonedSchedule(
      _notificationId(reminder.id),
      '小新提醒',
      reminder.title,
      tz.TZDateTime.from(scheduleAt, tz.local),
      NotificationDetails(
        android: _androidNotificationDetails(
          'xiaotai_reminders',
          '小新提醒',
          channelDescription: '生活事项和日程提醒',
          importance: Importance.high,
          priority: Priority.high,
          actions: [
            AndroidNotificationAction(
              _confirmReminderActionId,
              '确认完成',
              cancelNotification: true,
              showsUserInterface: false,
            ),
          ],
          settings: settings,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: _reminderPayload(reminder.id),
      matchDateTimeComponents: _matchComponents(reminder.repeatRule),
    );
  }

  Future<void> cancelReminder(String reminderId) async {
    await initialize();
    await _plugin.cancel(_notificationId(reminderId));
    await _plugin.cancel(_pinnedNotificationId(reminderId));
  }

  Future<void> cancelAll() async {
    await initialize();
    await _plugin.cancelAll();
  }

  Future<void> cancelAllSafely() async {
    try {
      await cancelAll().timeout(const Duration(seconds: 8));
    } catch (_) {}
  }

  Future<void> scheduleReminderSafely(AppReminder reminder) async {
    try {
      await scheduleReminder(reminder).timeout(const Duration(seconds: 12));
    } catch (_) {}
  }

  Future<void> syncMemoRemindersSafely(List<AppMemo> memos) async {
    try {
      await syncMemoReminders(memos).timeout(const Duration(seconds: 12));
    } catch (_) {}
  }

  Future<void> syncPinnedReminders(List<AppReminder> reminders) async {
    final settings = (await AppLocalStore.create()).getSettings();
    await initialize();
    final now = DateTime.now();
    for (final reminder in reminders) {
      if (reminder.completed || reminder.isDoneForDate(now)) {
        await cancelReminder(reminder.id);
      } else if (!reminder.pinned) {
        await _plugin.cancel(_pinnedNotificationId(reminder.id));
      }
    }
    final activePinned =
        reminders
            .where(
              (reminder) =>
                  !reminder.completed &&
                  reminder.pinned &&
                  !reminder.isDoneForDate(now),
            )
            .toList()
          ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    if (!settings.notificationsEnabled) {
      for (final reminder in activePinned) {
        await _plugin.cancel(_pinnedNotificationId(reminder.id));
      }
      await _plugin.cancel(_overdueSummaryNotificationId);
      return;
    }
    for (final reminder in activePinned) {
      await _showPinnedReminder(reminder);
    }
    await showOverdueReminders(reminders);
  }

  Future<void> showOverdueReminders(List<AppReminder> reminders) async {
    final settings = (await AppLocalStore.create()).getSettings();
    if (!settings.notificationsEnabled) {
      await initialize();
      await _plugin.cancel(_overdueSummaryNotificationId);
      return;
    }
    await initialize();
    final now = DateTime.now();
    for (final reminder in reminders) {
      if (reminder.completed || reminder.isDoneForDate(now)) {
        await cancelReminder(reminder.id);
      }
    }
    final overdue =
        reminders
            .where(
              (reminder) =>
                  !reminder.completed &&
                  reminder.pinned &&
                  !reminder.scheduledAt.isAfter(now) &&
                  !reminder.isDoneForDate(now),
            )
            .toList()
          ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    if (overdue.isEmpty) {
      await _plugin.cancel(_overdueSummaryNotificationId);
      return;
    }
    final body = overdue
        .take(3)
        .map(
          (reminder) =>
              '${_formatClock(reminder.scheduledAt)} ${reminder.title}',
        )
        .join(' · ');
    await _plugin.show(
      _overdueSummaryNotificationId,
      overdue.length == 1 ? '有 1 个提醒待确认' : '有 ${overdue.length} 个提醒待确认',
      body,
      NotificationDetails(
        android: _androidNotificationDetails(
          'xiaotai_reminder_overdue',
          '待确认提醒',
          channelDescription: '按时间顺序显示已到时间且未确认完成的提醒',
          importance: Importance.high,
          priority: Priority.high,
          ongoing: true,
          autoCancel: false,
          onlyAlertOnce: true,
          actions: [
            AndroidNotificationAction(
              _confirmAllDueActionId,
              '确认全部',
              cancelNotification: true,
              showsUserInterface: false,
            ),
          ],
          settings: settings,
        ),
      ),
      payload: _notificationPayloadOpenReminders,
    );
  }

  Future<void> showDailyComicUpdated({
    required String title,
    required DateTime publishDate,
  }) async {
    final settings = (await AppLocalStore.create()).getSettings();
    if (!settings.notificationsEnabled) {
      return;
    }
    await initialize();
    if (!settings.announcementNotificationsEnabled) {
      return;
    }
    await _plugin.show(
      100002,
      '小笨漫画更新啦',
      '${_formatSchedule(publishDate)} · $title',
      NotificationDetails(
        android: _androidNotificationDetails(
          'xiaotai_daily_comic',
          '小笨漫画更新',
          channelDescription: '每日漫画更新时在状态栏提醒',
          importance: Importance.high,
          priority: Priority.high,
          autoCancel: true,
          settings: settings,
        ),
      ),
      payload: _notificationPayloadOpenDailyComic,
    );
  }

  Future<void> _showPinnedReminder(AppReminder reminder) async {
    final settings = (await AppLocalStore.create()).getSettings();
    return _plugin.show(
      _pinnedNotificationId(reminder.id),
      '小新提醒',
      '${reminder.title} · ${_formatSchedule(reminder.scheduledAt)}',
      NotificationDetails(
        android: _androidNotificationDetails(
          'xiaotai_reminder_status',
          '状态栏提醒',
          channelDescription: '在状态栏持续显示未完成的重要提醒',
          importance: Importance.high,
          priority: Priority.high,
          ongoing: true,
          autoCancel: false,
          onlyAlertOnce: true,
          actions: [
            AndroidNotificationAction(
              _confirmReminderActionId,
              '确认完成',
              cancelNotification: true,
              showsUserInterface: false,
            ),
          ],
          settings: settings,
        ),
      ),
      payload: _reminderPayload(reminder.id),
    );
  }

  static Future<void> handleNotificationResponse(
    NotificationResponse response,
  ) async {
    final actionId = response.actionId;
    if (actionId == _confirmAllDueActionId) {
      await instance.confirmAllDueReminders();
      return;
    }
    if (actionId != _confirmReminderActionId) {
      _handleOpenReminderNotification(response.payload);
      return;
    }
    final reminderId = _parseReminderPayload(response.payload);
    if (reminderId == null) {
      return;
    }
    await instance.confirmReminder(reminderId);
  }

  static void _handleOpenReminderNotification(String? payload) {
    if (payload == _notificationPayloadOpenDailyComic) {
      return;
    }
    if (payload == _notificationPayloadOpenMemos) {
      MemoNotificationIntent.instance.requestOpenMemos();
      return;
    }
    if (payload == _notificationPayloadOpenReminders) {
      ReminderNotificationIntent.instance.requestFirstDueReminderConfirmation();
      return;
    }
    final reminderId = _parseReminderPayload(payload);
    if (reminderId != null) {
      ReminderNotificationIntent.instance.requestReminderConfirmation(
        reminderId,
      );
    }
  }

  Future<void> _handleLaunchNotification() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    final response = details?.notificationResponse;
    if (details?.didNotificationLaunchApp == true && response != null) {
      await handleNotificationResponse(response);
    }
  }

  Future<void> confirmAllDueReminders() async {
    final store = await AppLocalStore.create();
    final now = DateTime.now();
    final reminders = store.getReminders();
    var changed = false;
    final nextReminders = [...reminders];
    for (var i = 0; i < nextReminders.length; i++) {
      final reminder = nextReminders[i];
      if (!reminder.completed &&
          reminder.pinned &&
          !reminder.scheduledAt.isAfter(now) &&
          !reminder.isDoneForDate(now)) {
        final updated = reminder.copyWith(
          doneDateKey: AppReminder.dateKey(now),
        );
        nextReminders[i] = updated;
        await store.upsertReminder(updated);
        await cancelReminder(reminder.id);
        changed = true;
      }
    }
    if (changed) {
      await _plugin.cancel(_overdueSummaryNotificationId);
      await showOverdueReminders(nextReminders);
    }
  }

  Future<void> confirmReminder(String reminderId) async {
    final store = await AppLocalStore.create();
    final reminders = store.getReminders();
    final index = reminders.indexWhere((reminder) => reminder.id == reminderId);
    if (index == -1) {
      await cancelReminder(reminderId);
      return;
    }
    final now = DateTime.now();
    final reminder = reminders[index];
    if (!reminder.isDoneForDate(now)) {
      reminders[index] = reminder.copyWith(
        doneDateKey: AppReminder.dateKey(now),
      );
      await store.upsertReminder(reminders[index]);
    }
    await cancelReminder(reminder.id);
    await showOverdueReminders(reminders);
  }

  DateTimeComponents? _matchComponents(String repeatRule) {
    return switch (repeatRule) {
      'daily' => DateTimeComponents.time,
      'weekly' => DateTimeComponents.dayOfWeekAndTime,
      'monthly' => DateTimeComponents.dayOfMonthAndTime,
      _ => null,
    };
  }

  AndroidNotificationDetails _androidNotificationDetails(
    String channelId,
    String channelName, {
    required String channelDescription,
    required Importance importance,
    required Priority priority,
    required AppSettings settings,
    bool ongoing = false,
    bool autoCancel = true,
    bool onlyAlertOnce = false,
    List<AndroidNotificationAction>? actions,
  }) {
    return AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: importance,
      priority: priority,
      ongoing: ongoing,
      autoCancel: autoCancel,
      onlyAlertOnce: onlyAlertOnce,
      actions: actions,
      playSound: settings.notificationSoundEnabled,
      enableVibration: settings.notificationSoundEnabled,
      visibility: settings.lockPreviewEnabled
          ? NotificationVisibility.public
          : NotificationVisibility.secret,
    );
  }

  int _notificationId(String value) {
    var hash = 0;
    for (final codeUnit in value.codeUnits) {
      hash = ((hash * 31) + codeUnit) & 0x7fffffff;
    }
    return hash;
  }

  int _pinnedNotificationId(String value) {
    return _notificationId('pinned_$value');
  }

  int _memoNotificationId(String value) {
    return _notificationId('memo_$value');
  }

  int get _overdueSummaryNotificationId => 100001;

  static String _reminderPayload(String reminderId) {
    return '$_notificationPayloadReminderPrefix$reminderId';
  }

  static String? _parseReminderPayload(String? payload) {
    if (payload == null || payload.isEmpty) {
      return null;
    }
    if (payload.startsWith(_notificationPayloadReminderPrefix)) {
      return payload.substring(_notificationPayloadReminderPrefix.length);
    }
    if (payload == _notificationPayloadOpenReminders) {
      return null;
    }
    return payload;
  }

  String _formatSchedule(DateTime time) {
    return '${time.month}月${time.day}日 ${_formatClock(time)}';
  }

  String _formatClock(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
