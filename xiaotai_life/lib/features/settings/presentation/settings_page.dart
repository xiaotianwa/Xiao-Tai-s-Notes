import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/app_auth_notifier.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/data/app_data_store.dart';
import '../../../core/theme/app_theme_controller.dart';
import '../../../core/theme/app_theme_tokens.dart';
import '../../../core/update/app_update_service.dart';
import '../../../shared/widgets/prototype_ui.dart';

const _settingsPurple = Color(0xFF9B6CF2);
const _settingsDeep = Color(0xFF25203F);
const _settingsMuted = Color(0xFF86809B);
const _settingsLine = Color(0xFFF0EAF8);
const _settingsCardShadow = Color(0x1A8E73D7);

enum _SettingsPanel { main, notifications, themes, about }

enum _SyncConflictAction { useServer, keepLocal }

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _mediaPicker = MethodChannel('xiaotai_life/media_picker');

  late Future<AppLocalStore> _storeFuture;
  _SettingsPanel _panel = _SettingsPanel.main;
  AppSettings? _settingsOverride;

  bool _backupBusy = false;
  bool _restoreBusy = false;
  bool _logoutBusy = false;

  @override
  void initState() {
    super.initState();
    _storeFuture = AppLocalStore.create();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppLocalStore>(
      future: _storeFuture,
      builder: (context, snapshot) {
        final store = snapshot.data;
        final settings =
            _settingsOverride ?? store?.getSettings() ?? AppSettings.defaults;
        final backups = store?.getBackups() ?? const <AppDataBackup>[];
        final syncStatus = store?.getSyncStatus() ?? const AppSyncStatus();
        final recoveryNotice = store?.getDataRecoveryNotice();
        final session = store?.getAuthSession();
        final tokens = AppThemeTokens.fromStorageKey(settings.themeId);

        return _SettingsShell(
          panel: _panel,
          onBack: _handleBack,
          onSyncShortcut: () => syncStatus.hasConflicts
              ? _showSnack('有同步冲突待处理，请在设置页中选择处理方式')
              : _showSnack('登录后会自动同步本地变更'),
          onProfileShortcut: store == null
              ? () => _showSnack('资料加载中，请稍后再试')
              : () => _editProfile(store, settings),
          child: switch (_panel) {
            _SettingsPanel.main => _MainSettingsPanel(
              settings: settings,
              backups: backups,
              syncStatus: syncStatus,
              recoveryNotice: recoveryNotice,
              session: session,
              tokens: tokens,
              backupBusy: _backupBusy,
              restoreBusy: _restoreBusy,
              logoutBusy: _logoutBusy,
              onEditProfile: store == null
                  ? null
                  : () => _editProfile(store, settings),
              onNotifications: () =>
                  setState(() => _panel = _SettingsPanel.notifications),
              onThemes: () => setState(() => _panel = _SettingsPanel.themes),
              onCreateBackup: store == null ? null : () => _createBackup(store),
              onRestoreBackup: store == null
                  ? null
                  : () => _restoreBackup(store),
              onPrivacy: _showPrivacyDetails,
              onAbout: () => setState(() => _panel = _SettingsPanel.about),
              onResolveConflict: store == null
                  ? null
                  : (conflict) => _resolveSyncConflict(store, conflict),
              onDismissRecoveryNotice: store == null
                  ? null
                  : () => _dismissRecoveryNotice(store),
              onLogout: store == null ? null : () => _logout(store),
            ),
            _SettingsPanel.notifications => _NotificationsPanel(
              notificationsEnabled: settings.notificationsEnabled,
              lockPreviewEnabled: settings.lockPreviewEnabled,
              announcementEnabled: settings.announcementNotificationsEnabled,
              soundEnabled: settings.notificationSoundEnabled,
              dailyMemoTime: _formatTime(
                TimeOfDay(
                  hour: settings.dailyMemoReminderHour,
                  minute: settings.dailyMemoReminderMinute,
                ),
              ),
              onToggleNotifications: (enabled) async {
                final next = settings.copyWith(
                  notificationsEnabled: enabled,
                  updatedAt: DateTime.now(),
                );
                _setSettingsOverride(next);
                final targetStore = await _resolveStore(store);
                if (!mounted) {
                  return;
                }
                await _toggleNotifications(targetStore, enabled);
              },
              onToggleLockPreview: (enabled) async {
                final next = settings.copyWith(
                  lockPreviewEnabled: enabled,
                  updatedAt: DateTime.now(),
                );
                _setSettingsOverride(next);
                final targetStore = await _resolveStore(store);
                if (!mounted) {
                  return;
                }
                final current = targetStore.getSettings();
                await _saveNotificationSetting(
                  targetStore,
                  current.copyWith(
                    lockPreviewEnabled: enabled,
                    updatedAt: DateTime.now(),
                  ),
                );
              },
              onToggleAnnouncement: (enabled) async {
                final next = settings.copyWith(
                  announcementNotificationsEnabled: enabled,
                  updatedAt: DateTime.now(),
                );
                _setSettingsOverride(next);
                final targetStore = await _resolveStore(store);
                if (!mounted) {
                  return;
                }
                final current = targetStore.getSettings();
                await _saveNotificationSetting(
                  targetStore,
                  current.copyWith(
                    announcementNotificationsEnabled: enabled,
                    updatedAt: DateTime.now(),
                  ),
                );
              },
              onToggleSound: (enabled) async {
                final next = settings.copyWith(
                  notificationSoundEnabled: enabled,
                  updatedAt: DateTime.now(),
                );
                _setSettingsOverride(next);
                final targetStore = await _resolveStore(store);
                if (!mounted) {
                  return;
                }
                await _toggleNotificationSound(
                  targetStore,
                  targetStore.getSettings(),
                  enabled,
                );
              },
              onPickDailyTime: () async {
                await _pickDailyMemoTime(store, settings);
              },
            ),
            _SettingsPanel.themes => _ThemesPanel(
              selectedThemeId: AppThemeId.fromStorageKey(settings.themeId),
              onSelectTheme: store == null
                  ? null
                  : (themeId) => _changeTheme(store, settings, themeId),
            ),
            _SettingsPanel.about => _AboutPanel(
              avatarAsset: tokens.assets.profile,
              onUserAgreement: () => _showLegalPlaceholder('用户协议'),
              onPrivacyPolicy: () => _showLegalPlaceholder('隐私政策'),
              onLicenses: () => showLicensePage(
                context: context,
                applicationName: '婷婷小笨日记',
                applicationVersion: '2.3.1',
              ),
              onCheckUpdate: () => AppUpdateService.instance.checkAndPrompt(
                context,
                notifyWhenCurrent: true,
              ),
            ),
          },
        );
      },
    );
  }

  void _handleBack() {
    if (_panel != _SettingsPanel.main) {
      setState(() => _panel = _SettingsPanel.main);
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    context.go(AppRoutes.today);
  }

  void _refresh(AppLocalStore store) {
    setState(() => _storeFuture = Future.value(store));
  }

  void _applySettings(AppLocalStore store, AppSettings settings) {
    setState(() {
      _settingsOverride = settings;
      _storeFuture = Future.value(store);
    });
  }

  void _setSettingsOverride(AppSettings settings) {
    setState(() => _settingsOverride = settings);
  }

  Future<AppLocalStore> _resolveStore(AppLocalStore? current) async {
    if (current != null) {
      return current;
    }
    try {
      return await _storeFuture.timeout(const Duration(milliseconds: 300));
    } catch (_) {
      final store = await AppLocalStore.create();
      if (mounted) {
        setState(() => _storeFuture = Future.value(store));
      }
      return store;
    }
  }

  Future<void> _editProfile(AppLocalStore store, AppSettings settings) async {
    final edited = await showModalBottomSheet<AppSettings>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ProfileEditSheet(
        settings: settings,
        displayName: _displayName(settings),
        displayMotto: _displayMotto(settings),
        avatarAsset: _profileAvatarAsset(
          settings,
          AppThemeTokens.fromStorageKey(settings.themeId),
        ),
        onPickAvatar: _pickProfileAvatar,
      ),
    );
    if (edited == null) {
      return;
    }
    await store.saveSettings(edited.copyWith(updatedAt: DateTime.now()));
    if (!mounted) {
      return;
    }
    _refresh(store);
    _showSnack('个人资料已保存');
  }

  Future<void> _toggleNotifications(AppLocalStore store, bool enabled) async {
    final previous = store.getSettings();
    final next = previous.copyWith(
      notificationsEnabled: enabled,
      updatedAt: DateTime.now(),
    );
    _applySettings(store, next);
    try {
      await store.saveSettings(next);
      if (!mounted) {
        return;
      }
      _showSnack(enabled ? '提醒通知已开启' : '提醒通知已关闭');
    } catch (_) {
      await store.saveSettings(previous.copyWith(updatedAt: DateTime.now()));
      if (mounted) {
        _applySettings(store, previous);
        _showSnack('通知设置失败，请稍后再试');
      }
    }
  }

  Future<void> _saveNotificationSetting(
    AppLocalStore store,
    AppSettings next,
  ) async {
    final previous = store.getSettings();
    _applySettings(store, next);
    try {
      await store.saveSettings(next);
      if (!mounted) {
        return;
      }
      _showSnack('通知设置已保存');
    } catch (_) {
      await store.saveSettings(previous.copyWith(updatedAt: DateTime.now()));
      if (mounted) {
        _applySettings(store, previous);
        _showSnack('通知设置失败，已恢复原设置');
      }
    }
  }

  Future<void> _toggleNotificationSound(
    AppLocalStore store,
    AppSettings settings,
    bool enabled,
  ) async {
    await _saveNotificationSetting(
      store,
      settings.copyWith(
        notificationSoundEnabled: enabled,
        updatedAt: DateTime.now(),
      ),
    );
    if (enabled) {
      try {
        await SystemSound.play(SystemSoundType.click);
        await HapticFeedback.selectionClick();
      } catch (_) {}
    }
  }

  Future<void> _pickDailyMemoTime(
    AppLocalStore? store,
    AppSettings settings,
  ) async {
    final picked = await showModalBottomSheet<TimeOfDay>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _MemoTimeSheet(
        selected: TimeOfDay(
          hour: settings.dailyMemoReminderHour,
          minute: settings.dailyMemoReminderMinute,
        ),
      ),
    );
    if (picked == null || !mounted) {
      return;
    }
    final next = settings.copyWith(
      dailyMemoReminderHour: picked.hour,
      dailyMemoReminderMinute: picked.minute,
      updatedAt: DateTime.now(),
    );
    _setSettingsOverride(next);
    final targetStore = await _resolveStore(store);
    if (!mounted) {
      return;
    }
    await _saveNotificationSetting(targetStore, next);
    if (!mounted) {
      return;
    }
    _showSnack('每日备忘提醒时间已设置');
  }

  Future<void> _changeTheme(
    AppLocalStore store,
    AppSettings current,
    AppThemeId themeId,
  ) async {
    if (current.themeId == themeId.storageKey) {
      return;
    }
    final settings = current.copyWith(
      themeId: themeId.storageKey,
      updatedAt: DateTime.now(),
    );
    await store.saveSettings(settings);
    AppThemeController.instance.applySettings(settings);
    if (!mounted) {
      return;
    }
    _refresh(store);
    _showSnack('已切换主题');
  }

  Future<void> _createBackup(AppLocalStore store) async {
    if (_backupBusy) {
      return;
    }
    setState(() => _backupBusy = true);
    try {
      final backup = await store.createBackup();
      if (!mounted) {
        return;
      }
      _refresh(store);
      _showSnack('已完成本地备份：${_compactPath(backup.filePath)}');
    } catch (_) {
      if (mounted) {
        _showSnack('本地备份失败，请稍后再试');
      }
    } finally {
      if (mounted) {
        setState(() => _backupBusy = false);
      }
    }
  }

  Future<void> _restoreBackup(AppLocalStore store) async {
    if (_restoreBusy) {
      return;
    }
    final backups = store.getBackups();
    final targetBackup = await store.latestRestorableBackup();
    if (targetBackup == null) {
      _showSnack(backups.isEmpty ? '暂无可恢复的本地备份' : '没有找到可用的备份文件');
      return;
    }
    if (!mounted) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _RestoreConfirmDialog(backup: targetBackup),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _restoreBusy = true);
    try {
      final restored = await store.restoreBackup(targetBackup);
      if (!mounted) {
        return;
      }
      _refresh(store);
      _showSnack('已恢复 ${_formatDate(restored.createdAt)} 的备份');
    } catch (_) {
      if (mounted) {
        _showSnack('恢复失败，当前数据未被覆盖');
      }
    } finally {
      if (mounted) {
        setState(() => _restoreBusy = false);
      }
    }
  }

  Future<void> _resolveSyncConflict(
    AppLocalStore store,
    AppSyncConflict conflict,
  ) async {
    final action = await showDialog<_SyncConflictAction>(
      context: context,
      builder: (context) => _SyncConflictDialog(conflict: conflict),
    );
    if (action == null || !mounted) {
      return;
    }

    try {
      switch (action) {
        case _SyncConflictAction.useServer:
          await store.applyServerConflict(conflict);
          if (!mounted) {
            return;
          }
          _refresh(store);
          _showSnack('已使用云端版本');
          break;
        case _SyncConflictAction.keepLocal:
          await store.keepLocalConflict(conflict);
          if (!mounted) {
            return;
          }
          _refresh(store);
          _showSnack('已保留本机版本，下次同步会重新上传');
          break;
      }
    } catch (_) {
      if (mounted) {
        _showSnack('冲突处理失败，请稍后再试');
      }
    }
  }

  Future<void> _dismissRecoveryNotice(AppLocalStore store) async {
    await store.clearDataRecoveryNotice();
    if (!mounted) {
      return;
    }
    _refresh(store);
    _showSnack('已关闭恢复提示');
  }

  Future<void> _logout(AppLocalStore store) async {
    if (_logoutBusy) {
      return;
    }
    setState(() => _logoutBusy = true);
    try {
      await store.clearAuthSession();
      AppAuthNotifier.instance.clear();
      if (!mounted) {
        return;
      }
      _refresh(store);
      _showSnack('已退出登录，本地记录仍会保留');
    } finally {
      if (mounted) {
        setState(() => _logoutBusy = false);
      }
    }
  }

  void _showPrivacyDetails() {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _InfoSheet(
        title: '隐私说明',
        icon: Icons.shield_outlined,
        color: Color(0xFFFF8E75),
        lines: [
          '当前记录优先保存在本机应用数据目录。',
          '日记、备忘、纪念日、目标和记账数据会写入本地 JSON 文件。',
          '本地备份只保留在当前设备，请在换机前主动完成备份或同步。',
          '远程备份暂未开放，本地备份和恢复可在设置页直接使用。',
        ],
      ),
    );
  }

  void _showLegalPlaceholder(String title) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _InfoSheet(
        title: title,
        icon: title == '隐私政策'
            ? Icons.privacy_tip_outlined
            : Icons.article_outlined,
        color: _settingsPurple,
        lines: title == '隐私政策'
            ? const [
                '我们只为两个人的生活记录提供服务，不做广告画像，也不会出售或共享个人数据。',
                '日记、备忘录、纪念日、提醒、小目标、记账、想去地点等内容优先保存在本机；登录同步时会通过当前配置的私有服务接口传输。',
                '相册权限仅用于选择你主动添加的图片；通知权限仅用于提醒、备忘、漫画更新和系统公告；定位权限仅用于天气和位置相关记录。',
                '本地备份文件只保留在当前设备的应用目录内，卸载应用或清理应用数据可能会删除备份。',
                '你可以在设置中修改资料、关闭通知、创建或恢复本地备份，也可以退出登录保留本机数据。',
              ]
            : const [
                '婷婷小笨日记是私人生活记录工具，当前仅面向已授权用户使用。',
                '你应只记录自己有权保存的文字、图片和提醒内容，不上传侵犯他人权益或违法违规的信息。',
                '应用提供本地记录、提醒、备忘、纪念日、漫画、天气、备份恢复和私有同步等功能，部分功能依赖系统权限和网络服务。',
                '本地备份和恢复会覆盖当前应用数据，恢复前会自动创建安全备份。',
                '继续使用本应用即表示你理解并同意以上约定；如不同意，可停止使用并删除本机数据。',
              ],
      ),
    );
  }

  Future<String?> _pickProfileAvatar() async {
    try {
      final picked = await _mediaPicker.invokeListMethod<String>('pickImages', {
        'maxCount': 1,
      });
      return (picked ?? const <String>[]).isEmpty ? null : picked!.first;
    } on PlatformException catch (error) {
      if (mounted) {
        _showSnack(error.message ?? '暂时无法打开图片选择器');
      }
      return null;
    }
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _settingsDeep,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}

class _SettingsShell extends StatelessWidget {
  const _SettingsShell({
    required this.panel,
    required this.onBack,
    required this.onSyncShortcut,
    required this.onProfileShortcut,
    required this.child,
  });

  final _SettingsPanel panel;
  final VoidCallback onBack;
  final VoidCallback onSyncShortcut;
  final VoidCallback onProfileShortcut;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final title = switch (panel) {
      _SettingsPanel.main => null,
      _SettingsPanel.notifications => '通知设置',
      _SettingsPanel.themes => '本地主题',
      _SettingsPanel.about => '关于应用',
    };

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0x18FFFFFF), Color(0x10FFF7FC), Color(0x14F8F2FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0, .46, 1],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: _SettingsTopBar(
                    title: title,
                    mainMode: panel == _SettingsPanel.main,
                    onBack: onBack,
                    onSyncShortcut: onSyncShortcut,
                    onProfileShortcut: onProfileShortcut,
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 430),
                      child: child,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsTopBar extends StatelessWidget {
  const _SettingsTopBar({
    required this.title,
    required this.mainMode,
    required this.onBack,
    required this.onSyncShortcut,
    required this.onProfileShortcut,
  });

  final String? title;
  final bool mainMode;
  final VoidCallback onBack;
  final VoidCallback onSyncShortcut;
  final VoidCallback onProfileShortcut;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          children: [
            _CircleIconButton(
              icon: Icons.chevron_left_rounded,
              iconColor: _settingsDeep,
              background: Colors.white.withValues(alpha: .65),
              onTap: onBack,
            ),
            Expanded(
              child: title == null
                  ? const SizedBox.shrink()
                  : Text(
                      title!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _settingsDeep,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
            if (mainMode) ...[
              _CircleIconButton(
                icon: Icons.sync_rounded,
                iconColor: _settingsPurple,
                background: Colors.white.withValues(alpha: .7),
                onTap: onSyncShortcut,
              ),
              const SizedBox(width: 8),
              _CircleIconButton(
                icon: Icons.camera_alt_outlined,
                iconColor: _settingsPurple,
                background: Colors.white.withValues(alpha: .7),
                onTap: onProfileShortcut,
              ),
            ] else
              const SizedBox(width: 44),
          ],
        ),
      ),
    );
  }
}

class _MainSettingsPanel extends StatelessWidget {
  const _MainSettingsPanel({
    required this.settings,
    required this.backups,
    required this.syncStatus,
    required this.recoveryNotice,
    required this.session,
    required this.tokens,
    required this.backupBusy,
    required this.restoreBusy,
    required this.logoutBusy,
    required this.onEditProfile,
    required this.onNotifications,
    required this.onThemes,
    required this.onCreateBackup,
    required this.onRestoreBackup,
    required this.onPrivacy,
    required this.onAbout,
    required this.onResolveConflict,
    required this.onDismissRecoveryNotice,
    required this.onLogout,
  });

  final AppSettings settings;
  final List<AppDataBackup> backups;
  final AppSyncStatus syncStatus;
  final AppDataRecoveryNotice? recoveryNotice;
  final AppAuthSession? session;
  final AppThemeTokens tokens;
  final bool backupBusy;
  final bool restoreBusy;
  final bool logoutBusy;
  final VoidCallback? onEditProfile;
  final VoidCallback onNotifications;
  final VoidCallback onThemes;
  final VoidCallback? onCreateBackup;
  final VoidCallback? onRestoreBackup;
  final VoidCallback onPrivacy;
  final VoidCallback onAbout;
  final ValueChanged<AppSyncConflict>? onResolveConflict;
  final VoidCallback? onDismissRecoveryNotice;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    final latestBackup = backups.isEmpty ? null : backups.first;
    return Column(
      children: [
        _ProfileHero(
          avatarAsset: _profileAvatarAsset(settings, tokens),
          name: _displayName(settings),
          motto: _displayMotto(settings),
          onTap: onEditProfile,
        ),
        if (recoveryNotice != null) ...[
          const SizedBox(height: 16),
          _DataRecoveryNoticeCard(
            notice: recoveryNotice!,
            onDismiss: onDismissRecoveryNotice,
          ),
        ],
        if (syncStatus.lastConflicts.isNotEmpty) ...[
          const SizedBox(height: 16),
          _SyncConflictCard(
            conflicts: syncStatus.lastConflicts,
            onResolveConflict: onResolveConflict,
          ),
        ],
        const SizedBox(height: 16),
        _SettingsMenuCard(
          children: [
            _SettingsMenuRow(
              icon: Icons.person_outline_rounded,
              iconColor: const Color(0xFFFF8A55),
              title: '个人资料',
              onTap: onEditProfile,
            ),
            _SettingsMenuRow(
              icon: Icons.notifications_none_rounded,
              iconColor: const Color(0xFFFF6677),
              title: '通知设置',
              onTap: onNotifications,
            ),
            _SettingsMenuRow(
              icon: Icons.palette_outlined,
              iconColor: const Color(0xFFFFB35D),
              title: '主题设置',
              onTap: onThemes,
            ),
            _SettingsMenuRow(
              icon: Icons.cloud_upload_outlined,
              iconColor: const Color(0xFFFF8777),
              title: '本地备份',
              subtitle: latestBackup == null
                  ? null
                  : '最近 ${_formatDate(latestBackup.createdAt)}',
              busy: backupBusy,
              onTap: onCreateBackup,
            ),
            _SettingsMenuRow(
              icon: Icons.file_download_outlined,
              iconColor: const Color(0xFFFF776A),
              title: '恢复备份',
              subtitle: backups.isEmpty ? '暂无备份' : '${backups.length} 个备份',
              busy: restoreBusy,
              onTap: onRestoreBackup,
            ),
            _SettingsMenuRow(
              icon: Icons.verified_user_outlined,
              iconColor: const Color(0xFFFF806A),
              title: '隐私说明',
              onTap: onPrivacy,
            ),
            _SettingsMenuRow(
              icon: Icons.info_outline_rounded,
              iconColor: const Color(0xFFFF806A),
              title: '关于应用',
              onTap: onAbout,
            ),
            const SizedBox(height: 12),
            _LogoutButton(busy: logoutBusy, onTap: onLogout),
          ],
        ),
      ],
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.avatarAsset,
    required this.name,
    required this.motto,
    required this.onTap,
  });

  final String avatarAsset;
  final String name;
  final String motto;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: onTap,
      child: GlassCard(
        height: 138,
        padding: const EdgeInsets.fromLTRB(22, 22, 18, 18),
        radius: 32,
        color: Colors.white.withValues(alpha: .14),
        tintColor: const Color(0xFFFFD8EA),
        borderColor: Colors.white.withValues(alpha: .78),
        blurSigma: 7,
        child: Stack(
          children: [
            const Positioned(
              top: 8,
              right: 28,
              child: Icon(
                Icons.star_rounded,
                size: 22,
                color: Color(0xFFFFD46E),
              ),
            ),
            const Positioned(
              right: 0,
              bottom: 18,
              child: Icon(
                Icons.auto_fix_high_rounded,
                size: 32,
                color: Color(0xFFC79BFF),
              ),
            ),
            const Positioned(
              left: 128,
              bottom: 42,
              child: Opacity(
                opacity: .24,
                child: Icon(
                  Icons.favorite_rounded,
                  size: 26,
                  color: Color(0xFFFF9BBC),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 76,
                  height: 76,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _settingsPurple.withValues(alpha: .16),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: _ProfileAvatarImage(source: avatarAsset, size: 64),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _settingsDeep,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        motto,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _settingsMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        '点击修改昵称、签名和头像',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFFAAA3BA),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsMenuCard extends StatelessWidget {
  const _SettingsMenuCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      radius: 30,
      color: Colors.white.withValues(alpha: .16),
      tintColor: const Color(0xFFFFE2EF),
      borderColor: Colors.white.withValues(alpha: .80),
      blurSigma: 7,
      child: Column(children: children),
    );
  }
}

class _DataRecoveryNoticeCard extends StatelessWidget {
  const _DataRecoveryNoticeCard({
    required this.notice,
    required this.onDismiss,
  });

  final AppDataRecoveryNotice notice;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final title = notice.restoredFromBackup ? '已从备份恢复数据' : '检测到本地数据异常';
    final detail = notice.restoredFromBackup
        ? '本地数据文件损坏，已保留损坏副本，并使用最新可用备份恢复。'
        : '本地数据文件损坏，已保留损坏副本，但没有找到可用备份。';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF2),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFFFDCA6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1AFFB35D),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SoftIcon(
                icon: Icons.health_and_safety_outlined,
                color: Color(0xFFFFA53E),
                size: 38,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _settingsDeep,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      detail,
                      style: const TextStyle(
                        color: _settingsMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _RecoveryPathLine(
            label: '损坏副本',
            value: _compactPath(notice.corruptFilePath),
          ),
          if (notice.restoredBackupPath != null)
            _RecoveryPathLine(
              label: '恢复备份',
              value: _compactPath(notice.restoredBackupPath!),
            ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: onDismiss,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFFA53E),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text('知道了'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecoveryPathLine extends StatelessWidget {
  const _RecoveryPathLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        children: [
          Text(
            '$label：',
            style: const TextStyle(
              color: Color(0xFFFFA53E),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _settingsDeep,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncConflictCard extends StatelessWidget {
  const _SyncConflictCard({
    required this.conflicts,
    required this.onResolveConflict,
  });

  final List<AppSyncConflict> conflicts;
  final ValueChanged<AppSyncConflict>? onResolveConflict;

  @override
  Widget build(BuildContext context) {
    final visibleConflicts = conflicts.take(3).toList(growable: false);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF7),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFFFD8BC)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1AFF8A55),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _SoftIcon(
                icon: Icons.sync_problem_rounded,
                color: Color(0xFFFF8A55),
                size: 38,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '同步冲突待处理',
                      style: TextStyle(
                        color: _settingsDeep,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${conflicts.length} 条本机改动与云端记录不一致',
                      style: const TextStyle(
                        color: _settingsMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final conflict in visibleConflicts)
            _SyncConflictTile(
              conflict: conflict,
              onResolve: onResolveConflict == null
                  ? null
                  : () => onResolveConflict!(conflict),
            ),
          if (conflicts.length > visibleConflicts.length)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4),
              child: Text(
                '还有 ${conflicts.length - visibleConflicts.length} 条冲突，请处理后再次同步',
                style: const TextStyle(
                  color: Color(0xFFFF8A55),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SyncConflictTile extends StatelessWidget {
  const _SyncConflictTile({required this.conflict, required this.onResolve});

  final AppSyncConflict conflict;
  final VoidCallback? onResolve;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFFFE5D3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_syncTypeLabel(conflict.type)} · ${_conflictTitle(conflict)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _settingsDeep,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '本机 ${_formatSyncDateTime(conflict.localUpdatedAt)} · 云端 ${_formatSyncDateTime(conflict.serverUpdatedAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _settingsMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onResolve,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFFF8A55),
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
            ),
            child: const Text('处理'),
          ),
        ],
      ),
    );
  }
}

class _SyncConflictDialog extends StatelessWidget {
  const _SyncConflictDialog({required this.conflict});

  final AppSyncConflict conflict;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Row(
        children: [
          const Icon(Icons.sync_problem_rounded, color: Color(0xFFFF8A55)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _syncTypeLabel(conflict.type),
              style: const TextStyle(
                color: _settingsDeep,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _conflictTitle(conflict),
            style: const TextStyle(
              color: _settingsDeep,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          _ConflictVersionBox(
            label: '本机版本',
            time: _formatSyncDateTime(conflict.localUpdatedAt),
            summary: _conflictDataSummary(conflict.localData),
          ),
          const SizedBox(height: 10),
          _ConflictVersionBox(
            label: '云端版本',
            time: _formatSyncDateTime(conflict.serverUpdatedAt),
            summary: conflict.serverDeletedAt == null
                ? _conflictDataSummary(conflict.serverData)
                : '云端已删除此记录',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('稍后处理'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(_SyncConflictAction.useServer),
          child: const Text('使用云端'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(_SyncConflictAction.keepLocal),
          style: FilledButton.styleFrom(backgroundColor: _settingsPurple),
          child: const Text('保留本机'),
        ),
      ],
    );
  }
}

class _ConflictVersionBox extends StatelessWidget {
  const _ConflictVersionBox({
    required this.label,
    required this.time,
    required this.summary,
  });

  final String label;
  final String time;
  final String summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8FC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _settingsLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label · $time',
            style: const TextStyle(
              color: _settingsMuted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            summary,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _settingsDeep,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsMenuRow extends StatelessWidget {
  const _SettingsMenuRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.busy = false,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: busy ? null : onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        constraints: const BoxConstraints(minHeight: 63),
        padding: const EdgeInsets.symmetric(horizontal: 2),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _settingsLine)),
        ),
        child: Row(
          children: [
            _SoftIcon(icon: icon, color: iconColor, size: 34),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _settingsDeep,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _settingsMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (busy)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: _settingsPurple,
                ),
              )
            else
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFAAA4BA),
                size: 26,
              ),
          ],
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: TextButton(
        onPressed: busy ? null : onTap,
        style: TextButton.styleFrom(
          backgroundColor: const Color(0xFFFFEAEA),
          foregroundColor: const Color(0xFFFF4F55),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFFF4F55),
                ),
              )
            : const Text(
                '退出登录',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
      ),
    );
  }
}

class _NotificationsPanel extends StatelessWidget {
  const _NotificationsPanel({
    required this.notificationsEnabled,
    required this.lockPreviewEnabled,
    required this.announcementEnabled,
    required this.soundEnabled,
    required this.dailyMemoTime,
    required this.onToggleNotifications,
    required this.onToggleLockPreview,
    required this.onToggleAnnouncement,
    required this.onToggleSound,
    required this.onPickDailyTime,
  });

  final bool notificationsEnabled;
  final bool lockPreviewEnabled;
  final bool announcementEnabled;
  final bool soundEnabled;
  final String dailyMemoTime;
  final ValueChanged<bool>? onToggleNotifications;
  final ValueChanged<bool>? onToggleLockPreview;
  final ValueChanged<bool>? onToggleAnnouncement;
  final ValueChanged<bool>? onToggleSound;
  final VoidCallback? onPickDailyTime;

  @override
  Widget build(BuildContext context) {
    return _PlainListCard(
      children: [
        const _ListHeader(
          icon: Icons.notifications_active_outlined,
          title: '消息通知',
          subtitle: '接收新消息',
        ),
        _NotificationRow(
          rowKey: const ValueKey('notification-main-row'),
          title: '提醒通知',
          subtitle: '活动提醒',
          onTap: onToggleNotifications == null
              ? null
              : () => onToggleNotifications?.call(!notificationsEnabled),
          trailing: _SwitchStatusTrailing(
            statusKey: const ValueKey('notification-main-status'),
            value: notificationsEnabled,
          ),
        ),
        _NotificationRow(
          rowKey: const ValueKey('notification-lock-row'),
          title: '锁屏通知预览',
          subtitle: '显示消息内容',
          onTap: onToggleLockPreview == null
              ? null
              : () => onToggleLockPreview?.call(!lockPreviewEnabled),
          trailing: _SwitchStatusTrailing(
            statusKey: const ValueKey('notification-lock-status'),
            value: lockPreviewEnabled,
          ),
        ),
        _NotificationRow(
          rowKey: const ValueKey('notification-announcement-row'),
          title: '公告通知',
          subtitle: '系统公告推送',
          onTap: onToggleAnnouncement == null
              ? null
              : () => onToggleAnnouncement?.call(!announcementEnabled),
          trailing: _SwitchStatusTrailing(
            statusKey: const ValueKey('notification-announcement-status'),
            value: announcementEnabled,
          ),
        ),
        _NotificationRow(
          rowKey: const ValueKey('notification-time-row'),
          title: '每日备忘提醒',
          subtitle: '记录备忘',
          onTap: onPickDailyTime,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                dailyMemoTime,
                style: const TextStyle(
                  color: _settingsMuted,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: _settingsMuted),
            ],
          ),
        ),
        _NotificationRow(
          rowKey: const ValueKey('notification-sound-row'),
          title: '声音',
          subtitle: null,
          last: true,
          onTap: onToggleSound == null
              ? null
              : () => onToggleSound?.call(!soundEnabled),
          trailing: _SwitchStatusTrailing(
            statusKey: const ValueKey('notification-sound-status'),
            value: soundEnabled,
            active: const Color(0xFFD7D5DE),
          ),
        ),
      ],
    );
  }
}

class _ThemesPanel extends StatelessWidget {
  const _ThemesPanel({
    required this.selectedThemeId,
    required this.onSelectTheme,
  });

  final AppThemeId selectedThemeId;
  final ValueChanged<AppThemeId>? onSelectTheme;

  @override
  Widget build(BuildContext context) {
    return _PlainListCard(
      children: [
        _ThemeRow(
          title: '一二布布主题',
          subtitle: '布布和小伙伴的温柔手账日常',
          icon: Icons.wb_sunny_outlined,
          iconColor: _settingsPurple,
          selected: selectedThemeId == AppThemeId.classic,
          onTap: () => onSelectTheme?.call(AppThemeId.classic),
        ),
        _ThemeRow(
          title: 'dongdong羊主题',
          subtitle: '软萌羊羊、甜色装扮和轻快陪伴感',
          icon: Icons.egg_alt_outlined,
          iconColor: _settingsPurple,
          selected: selectedThemeId == AppThemeId.eggyParty,
          last: true,
          onTap: () => onSelectTheme?.call(AppThemeId.eggyParty),
        ),
      ],
    );
  }
}

class _AboutPanel extends StatelessWidget {
  const _AboutPanel({
    required this.avatarAsset,
    required this.onUserAgreement,
    required this.onPrivacyPolicy,
    required this.onLicenses,
    required this.onCheckUpdate,
  });

  final String avatarAsset;
  final VoidCallback onUserAgreement;
  final VoidCallback onPrivacyPolicy;
  final VoidCallback onLicenses;
  final VoidCallback onCheckUpdate;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
        Container(
          width: 136,
          height: 136,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFFFEDE7),
            border: Border.all(color: const Color(0xFFFF7D3F), width: 4),
          ),
          child: ClipOval(
            child: _ProfileAvatarImage(source: avatarAsset, size: 120),
          ),
        ),
        const SizedBox(height: 26),
        const Text(
          '婷婷小笨日记',
          style: TextStyle(
            color: _settingsDeep,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          '版本 2.3.1：温柔陪伴中',
          style: TextStyle(
            color: _settingsMuted,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 42),
        _PlainListCard(
          flat: true,
          children: [
            _AboutRow(title: '用户协议', onTap: onUserAgreement),
            _AboutRow(title: '隐私政策', onTap: onPrivacyPolicy),
            _AboutRow(title: '开源许可', onTap: onLicenses),
            _AboutRow(title: '检查更新', last: true, onTap: onCheckUpdate),
          ],
        ),
      ],
    );
  }
}

class _PlainListCard extends StatelessWidget {
  const _PlainListCard({required this.children, this.flat = false});

  final List<Widget> children;
  final bool flat;

  @override
  Widget build(BuildContext context) {
    if (flat) {
      return Column(children: children);
    }
    return GlassCard(
      padding: flat ? EdgeInsets.zero : const EdgeInsets.fromLTRB(8, 12, 8, 8),
      radius: 28,
      color: Colors.white.withValues(alpha: .16),
      tintColor: const Color(0xFFFFE2EF),
      borderColor: Colors.white.withValues(alpha: .80),
      blurSigma: 7,
      child: Column(children: children),
    );
  }
}

class _ListHeader extends StatelessWidget {
  const _ListHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 12, 6, 18),
      child: Row(
        children: [
          _SoftIcon(icon: icon, color: _settingsPurple, size: 40),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _settingsDeep,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text('☁', style: TextStyle(color: Color(0xFFE5D9FF))),
                  const Text('☁', style: TextStyle(color: Color(0xFFE5D9FF))),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: _settingsMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.rowKey,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
    this.last = false,
  });

  final Key rowKey;
  final String title;
  final String? subtitle;
  final Widget trailing;
  final VoidCallback? onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: rowKey,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 74),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: _settingsLine)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _settingsDeep,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color: _settingsMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _SwitchStatusTrailing extends StatelessWidget {
  const _SwitchStatusTrailing({
    required this.statusKey,
    required this.value,
    this.active = _settingsPurple,
  });

  final Key statusKey;
  final bool value;
  final Color active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value ? '已开启' : '已关闭',
          key: statusKey,
          style: TextStyle(
            color: value ? active : _settingsMuted,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 10),
        _SettingsSwitch(
          value: value,
          onChanged: null,
          visualOnly: true,
          active: active,
        ),
      ],
    );
  }
}

class _ThemeRow extends StatelessWidget {
  const _ThemeRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.selected,
    required this.onTap,
    this.last = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final bool selected;
  final VoidCallback? onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        constraints: const BoxConstraints(minHeight: 86),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: _settingsLine)),
        ),
        child: Row(
          children: [
            _SoftIcon(icon: icon, color: iconColor, size: 40),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _settingsDeep,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: _settingsMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            _RadioMark(selected: selected),
          ],
        ),
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({
    required this.title,
    required this.onTap,
    this.last = false,
  });

  final String title;
  final VoidCallback onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 68),
        padding: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: _settingsLine)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: _settingsDeep,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 26,
              color: Color(0xFFA8A2B7),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSwitch extends StatelessWidget {
  const _SettingsSwitch({
    required this.value,
    required this.onChanged,
    this.active = _settingsPurple,
    this.visualOnly = false,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color active;
  final bool visualOnly;

  @override
  Widget build(BuildContext context) {
    final enabled = visualOnly || onChanged != null;
    final trackColor = value ? active : const Color(0xFFE8E6EF);
    final body = AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: enabled ? 1 : .56,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        width: 58,
        height: 34,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: trackColor,
          borderRadius: BorderRadius.circular(999),
          boxShadow: value
              ? [
                  BoxShadow(
                    color: active.withValues(alpha: .22),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x1F25203F),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (visualOnly) {
      return Semantics(toggled: value, enabled: enabled, child: body);
    }

    return Semantics(
      button: true,
      toggled: value,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => onChanged?.call(!value) : null,
        child: body,
      ),
    );
  }
}

class _SoftIcon extends StatelessWidget {
  const _SoftIcon({
    required this.icon,
    required this.color,
    required this.size,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: size * .52),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.iconColor,
    required this.background,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: .75)),
        ),
        child: Icon(icon, color: iconColor, size: 24),
      ),
    );
  }
}

class _RadioMark extends StatelessWidget {
  const _RadioMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? _settingsPurple : const Color(0xFFBDB8C8),
          width: selected ? 6 : 2,
        ),
      ),
    );
  }
}

class _ProfileEditSheet extends StatefulWidget {
  const _ProfileEditSheet({
    required this.settings,
    required this.displayName,
    required this.displayMotto,
    required this.avatarAsset,
    required this.onPickAvatar,
  });

  final AppSettings settings;
  final String displayName;
  final String displayMotto;
  final String avatarAsset;
  final Future<String?> Function() onPickAvatar;

  @override
  State<_ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends State<_ProfileEditSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _mottoController;
  late String _selectedAvatarAsset;
  bool _pickingAvatar = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.displayName);
    _mottoController = TextEditingController(text: widget.displayMotto);
    _selectedAvatarAsset = widget.avatarAsset;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mottoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(child: _SheetHandle()),
              const SizedBox(height: 18),
              const Text(
                '编辑个人资料',
                style: TextStyle(
                  color: _settingsDeep,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 18),
              _AvatarPicker(
                selectedAsset: _selectedAvatarAsset,
                onSelected: (asset) {
                  setState(() => _selectedAvatarAsset = asset);
                },
                picking: _pickingAvatar,
                onPickLocal: _pickLocalAvatar,
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _nameController,
                maxLength: 16,
                textInputAction: TextInputAction.next,
                decoration: _inputDecoration('昵称'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _mottoController,
                maxLength: 40,
                minLines: 2,
                maxLines: 3,
                decoration: _inputDecoration('个性签名'),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: _settingsLine),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: _settingsPurple,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text('保存'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFFCFBFF),
      counterStyle: const TextStyle(color: _settingsMuted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _settingsLine),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _settingsLine),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _settingsPurple, width: 1.4),
      ),
    );
  }

  void _save() {
    final name = _nameController.text.trim();
    final motto = _mottoController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请填写昵称')));
      return;
    }
    Navigator.of(context).pop(
      widget.settings.copyWith(
        profileName: name,
        profileMotto: motto.isEmpty ? AppSettings.defaults.profileMotto : motto,
        profileAvatarAsset: _selectedAvatarAsset,
      ),
    );
  }

  Future<void> _pickLocalAvatar() async {
    if (_pickingAvatar) {
      return;
    }
    setState(() => _pickingAvatar = true);
    try {
      final path = await widget.onPickAvatar();
      if (path == null || !mounted) {
        return;
      }
      setState(() => _selectedAvatarAsset = path);
    } finally {
      if (mounted) {
        setState(() => _pickingAvatar = false);
      }
    }
  }
}

class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker({
    required this.selectedAsset,
    required this.onSelected,
    required this.picking,
    required this.onPickLocal,
  });

  final String selectedAsset;
  final ValueChanged<String> onSelected;
  final bool picking;
  final VoidCallback onPickLocal;

  static const _assets = [
    'assets/themes/default/profile.png',
    'assets/themes/default/home_mascot.png',
    'assets/themes/eggy/profile.png',
    'assets/themes/eggy/home_mascot.png',
    'assets/themes/eggy/snack.png',
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: picking ? null : onPickLocal,
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFF5FA),
              border: Border.all(color: const Color(0xFFFFC3D9), width: 1.5),
            ),
            child: picking
                ? const Padding(
                    padding: EdgeInsets.all(17),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(
                    Icons.add_a_photo_outlined,
                    color: _settingsPurple,
                    size: 26,
                  ),
          ),
        ),
        for (final asset in _assets)
          InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: () => onSelected(asset),
            child: Container(
              width: 58,
              height: 58,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(
                  color: selectedAsset == asset
                      ? const Color(0xFFFF8A55)
                      : _settingsLine,
                  width: selectedAsset == asset ? 3 : 1,
                ),
              ),
              child: ClipOval(
                child: _ProfileAvatarImage(source: asset, size: 50),
              ),
            ),
          ),
        if (!selectedAsset.startsWith('assets/'))
          Container(
            width: 58,
            height: 58,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: const Color(0xFFFF8A55), width: 3),
            ),
            child: ClipOval(
              child: _ProfileAvatarImage(source: selectedAsset, size: 50),
            ),
          ),
      ],
    );
  }
}

class _ProfileAvatarImage extends StatelessWidget {
  const _ProfileAvatarImage({required this.source, required this.size});

  final String source;
  final double size;

  @override
  Widget build(BuildContext context) {
    final trimmed = source.trim();
    if (trimmed.isNotEmpty && !trimmed.startsWith('assets/')) {
      return Image.file(
        File(trimmed),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _AvatarFallback(size: size),
      );
    }
    return Image.asset(
      trimmed.isEmpty ? 'assets/themes/default/profile.png' : trimmed,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _AvatarFallback(size: size),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: const Color(0xFFFFEEF7),
      alignment: Alignment.center,
      child: Icon(
        Icons.face_retouching_natural_rounded,
        color: _settingsPurple,
        size: size * .58,
      ),
    );
  }
}

class _MemoTimeSheet extends StatefulWidget {
  const _MemoTimeSheet({required this.selected});

  final TimeOfDay selected;

  @override
  State<_MemoTimeSheet> createState() => _MemoTimeSheetState();
}

class _MemoTimeSheetState extends State<_MemoTimeSheet> {
  late int _hour;
  late int _minute;

  @override
  void initState() {
    super.initState();
    _hour = widget.selected.hour;
    _minute = widget.selected.minute;
  }

  @override
  Widget build(BuildContext context) {
    final selected = TimeOfDay(hour: _hour, minute: _minute);
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(child: _SheetHandle()),
            const SizedBox(height: 18),
            Row(
              children: [
                const _SoftIcon(
                  icon: Icons.schedule_rounded,
                  color: _settingsPurple,
                  size: 42,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    '每日备忘提醒',
                    style: TextStyle(
                      color: _settingsDeep,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  _formatTime(selected),
                  style: const TextStyle(
                    color: _settingsMuted,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _TimeStepper(
                    label: '小时',
                    value: _hour.toString().padLeft(2, '0'),
                    onMinus: () => setState(() => _hour = (_hour + 23) % 24),
                    onPlus: () => setState(() => _hour = (_hour + 1) % 24),
                    minusKey: const ValueKey('memo-hour-minus'),
                    plusKey: const ValueKey('memo-hour-plus'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimeStepper(
                    label: '分钟',
                    value: _minute.toString().padLeft(2, '0'),
                    onMinus: () =>
                        setState(() => _minute = (_minute + 55) % 60),
                    onPlus: () => setState(() => _minute = (_minute + 5) % 60),
                    minusKey: const ValueKey('memo-minute-minus'),
                    plusKey: const ValueKey('memo-minute-plus'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: _settingsLine),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const ValueKey('memo-time-save'),
                    onPressed: () => Navigator.of(context).pop(selected),
                    style: FilledButton.styleFrom(
                      backgroundColor: _settingsPurple,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text('保存'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeStepper extends StatelessWidget {
  const _TimeStepper({
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
    required this.minusKey,
    required this.plusKey,
  });

  final String label;
  final String value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final Key minusKey;
  final Key plusKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFBFF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _settingsLine),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _settingsMuted,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StepperButton(
                key: minusKey,
                icon: Icons.remove_rounded,
                onTap: onMinus,
              ),
              SizedBox(
                width: 54,
                child: Text(
                  value,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _settingsDeep,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _StepperButton(
                key: plusKey,
                icon: Icons.add_rounded,
                onTap: onPlus,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({super.key, required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _settingsLine),
        ),
        child: Icon(icon, color: _settingsPurple, size: 20),
      ),
    );
  }
}

class _InfoSheet extends StatelessWidget {
  const _InfoSheet({
    required this.title,
    required this.icon,
    required this.color,
    required this.lines,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(child: _SheetHandle()),
            const SizedBox(height: 18),
            Row(
              children: [
                _SoftIcon(icon: icon, color: color, size: 42),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: _settingsDeep,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...lines.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  line,
                  style: const TextStyle(
                    color: _settingsMuted,
                    height: 1.55,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: _settingsPurple,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text('知道了'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RestoreConfirmDialog extends StatelessWidget {
  const _RestoreConfirmDialog({required this.backup});

  final AppDataBackup backup;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: _settingsCardShadow,
              blurRadius: 28,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _SoftIcon(
              icon: Icons.restore_outlined,
              color: _settingsPurple,
              size: 54,
            ),
            const SizedBox(height: 16),
            const Text(
              '恢复本地备份？',
              style: TextStyle(
                color: _settingsDeep,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '将恢复 ${_formatDate(backup.createdAt)} 的备份。当前数据会先自动创建安全备份。',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _settingsMuted,
                height: 1.45,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _settingsLine),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: _settingsPurple,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text('恢复'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 5,
      decoration: BoxDecoration(
        color: const Color(0xFFE6E0F0),
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}

String _syncTypeLabel(String type) {
  return switch (type) {
    'entry' => '日记',
    'memo' => '备忘',
    'reminder' => '提醒',
    'anniversary' => '纪念日',
    'place' => '地点',
    'weekly_goal' => '周目标',
    'money_record' => '账本',
    'settings' => '个人资料',
    _ => '记录',
  };
}

String _conflictTitle(AppSyncConflict conflict) {
  final title =
      _firstReadableValue(conflict.localData) ??
      _firstReadableValue(conflict.serverData);
  return title == null || title.isEmpty ? conflict.clientId : title;
}

String _conflictDataSummary(Map<String, Object?> data) {
  final value = _firstReadableValue(data);
  return value == null || value.isEmpty ? '暂无可预览内容' : value;
}

String? _firstReadableValue(Map<String, Object?> data) {
  const keys = [
    'title',
    'content',
    'body',
    'name',
    'profileName',
    'description',
    'amountCents',
  ];
  for (final key in keys) {
    final value = data[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    if (value is num) {
      return value.toString();
    }
  }
  return null;
}

String _formatSyncDateTime(DateTime? time) {
  if (time == null) {
    return '未知';
  }
  final month = time.month.toString().padLeft(2, '0');
  final day = time.day.toString().padLeft(2, '0');
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$month-$day $hour:$minute';
}

String _displayName(AppSettings settings) {
  final value = settings.profileName.trim();
  if (value.isEmpty) {
    return AppSettings.defaults.profileName;
  }
  return value;
}

String _displayMotto(AppSettings settings) {
  final value = settings.profileMotto.trim();
  if (value.isEmpty || value == '温柔记录每一天') {
    return AppSettings.defaults.profileMotto;
  }
  return value;
}

String _profileAvatarAsset(AppSettings settings, AppThemeTokens tokens) {
  final value = settings.profileAvatarAsset?.trim();
  if (value == null || value.isEmpty) {
    return tokens.assets.profile;
  }
  return value;
}

String _formatDate(DateTime time) {
  final month = time.month.toString().padLeft(2, '0');
  final day = time.day.toString().padLeft(2, '0');
  return '${time.year}-$month-$day';
}

String _formatTime(TimeOfDay time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _compactPath(String path) {
  final normalized = path.replaceAll('\\', '/');
  final index = normalized.lastIndexOf('/');
  if (index < 0) {
    return normalized;
  }
  return normalized.substring(index + 1);
}
