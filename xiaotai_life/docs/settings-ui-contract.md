# 设置页 UI 重构接口预留记录

## 已接入能力

- 个人资料：读取并保存 `AppSettings.profileName`、`AppSettings.profileMotto`。
- 通知设置：`提醒通知` 已接入 `LocalNotificationService` 权限申请、提醒重排和取消。
- 主题设置：只保留默认主题与 Eggy 主题，均已接入 `AppThemeId` 与 `AppThemeController`。
- 本地备份：已接入 `AppLocalStore.createBackup()`。
- 恢复备份：已接入 `AppLocalStore.restoreBackup()`，恢复前会自动创建安全备份。
- 关于应用：`检查更新` 已接入 `AppUpdateService.instance.checkAndPrompt(context)`，`开源许可` 使用系统许可页。
- 退出登录：已接入 `AppLocalStore.clearAuthSession()` 与 `AppAuthNotifier.instance.clear()`。

## 预留接口

- 头像编辑：当前使用主题资产 `AppThemeTokens.assets.profile`，后续可扩展 `AppSettings.profileAvatar`。
- 锁屏通知预览：当前为本页本地状态，待接入 `AppSettings.lockScreenPreviewEnabled`。
- 公告通知：当前为本页本地状态，待接入 `AppSettings.announcementNotificationsEnabled`。
- 每日心情提醒：当前可选择时间但未持久化，待接入 `AppSettings.dailyMoodReminderAt` 与调度服务。
- 声音开关：当前为本页本地状态，待接入 `AppSettings.notificationSoundEnabled`。
- 用户协议、隐私政策：入口和弹窗已保留，待接入正式协议文本或远程 URL。
- 主设置页右上角两个圆形按钮：当前作为视觉占位，待接入同步入口和头像/背景编辑入口。
