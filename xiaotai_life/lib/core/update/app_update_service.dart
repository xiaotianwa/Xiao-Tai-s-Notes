import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../network/app_api_config.dart';
import '../theme/app_colors.dart';

class AppVersionInfo {
  const AppVersionInfo({
    required this.id,
    required this.platform,
    required this.channel,
    required this.versionName,
    required this.versionCode,
    required this.forceUpdate,
    required this.enabled,
    required this.apkUrl,
    this.apkSize,
    this.sha256,
    this.changelog,
  });

  factory AppVersionInfo.fromJson(Map<String, Object?> json) {
    return AppVersionInfo(
      id: json['id'] as String? ?? '',
      platform: json['platform'] as String? ?? 'android',
      channel: json['channel'] as String? ?? 'private',
      versionName: json['versionName'] as String? ?? '',
      versionCode: (json['versionCode'] as num?)?.toInt() ?? 0,
      forceUpdate: json['forceUpdate'] as bool? ?? false,
      enabled: json['enabled'] as bool? ?? false,
      apkUrl: json['apkUrl'] as String? ?? '',
      apkSize: (json['apkSize'] as num?)?.toInt(),
      sha256: json['sha256'] as String?,
      changelog: json['changelog'] as String?,
    );
  }

  final String id;
  final String platform;
  final String channel;
  final String versionName;
  final int versionCode;
  final bool forceUpdate;
  final bool enabled;
  final String apkUrl;
  final int? apkSize;
  final String? sha256;
  final String? changelog;
}

class AppUpdateService {
  AppUpdateService._();

  static final instance = AppUpdateService._();

  static const defaultBaseUrl = String.fromEnvironment(
    'XIAOTAI_API_BASE_URL',
    defaultValue: AppApiConfig.localDevBaseUrl,
  );
  static const fallbackVersionCode = int.fromEnvironment(
    'XIAOTAI_APP_VERSION_CODE',
    defaultValue: 1,
  );

  bool _prompting = false;

  Future<AppVersionInfo?> fetchLatest({
    String platform = 'android',
    String channel = 'private',
    String? baseUrl,
  }) async {
    final effectiveBaseUrl = (baseUrl ?? defaultBaseUrl).replaceFirst(
      RegExp(r'/$'),
      '',
    );
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    try {
      final query = Uri(
        queryParameters: {'platform': platform, 'channel': channel},
      ).query;
      final request = await client
          .getUrl(Uri.parse('$effectiveBaseUrl/app-versions/latest?$query'))
          .timeout(const Duration(seconds: 6));
      final response = await request.close().timeout(
        const Duration(seconds: 10),
      );
      final raw = await response.transform(utf8.decoder).join();
      if (response.statusCode == 404) {
        return null;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw StateError('更新响应格式不正确');
      }
      if ((decoded['code'] as num?)?.toInt() != 0) {
        throw StateError(decoded['message'] as String? ?? '检查更新失败');
      }
      final data = decoded['data'];
      if (data is! Map<String, dynamic>) {
        return null;
      }
      return AppVersionInfo.fromJson(data.cast<String, Object?>());
    } finally {
      client.close(force: true);
    }
  }

  Future<void> checkAndPrompt(
    BuildContext context, {
    String? baseUrl,
    bool notifyWhenCurrent = false,
  }) async {
    if (_prompting) {
      return;
    }

    AppVersionInfo? latest;
    try {
      latest = await fetchLatest(baseUrl: baseUrl);
    } catch (error) {
      if (notifyWhenCurrent && context.mounted) {
        _showUpdateSnack(context, '检查更新失败，请稍后再试');
      }
      return;
    }
    final update = latest;
    final currentVersionCode = await _currentVersionCode();
    if (!context.mounted) {
      return;
    }
    if (update == null || !update.enabled) {
      if (notifyWhenCurrent) {
        _showUpdateSnack(context, '当前没有可用更新');
      }
      return;
    }
    if (update.versionCode <= currentVersionCode) {
      if (notifyWhenCurrent) {
        _showUpdateSnack(context, '已经是最新版本');
      }
      return;
    }

    _prompting = true;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: !update.forceUpdate,
        builder: (dialogContext) {
          return _UpdateDialog(
            version: update,
            downloadUrl: _resolveAssetUrl(update.apkUrl, baseUrl: baseUrl),
          );
        },
      );
    } finally {
      _prompting = false;
    }
  }

  String _resolveAssetUrl(String path, {String? baseUrl}) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    final effectiveBaseUrl = (baseUrl ?? defaultBaseUrl).replaceFirst(
      RegExp(r'/$'),
      '',
    );
    return '${effectiveBaseUrl.replaceFirst(RegExp(r'/api/v1$'), '')}$path';
  }

  Future<int> _currentVersionCode() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return int.tryParse(info.buildNumber) ?? fallbackVersionCode;
    } catch (_) {
      return fallbackVersionCode;
    }
  }

  void _showUpdateSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
      ),
    );
  }
}

class AppApkInstaller {
  AppApkInstaller._();

  static const _channel = MethodChannel('xiaotai_life/app_installer');

  static Future<void> installApk(String path) async {
    await _channel.invokeMethod<void>('installApk', {'path': path});
  }

  static Future<void> openInstallPermissionSettings() async {
    await _channel.invokeMethod<void>('openInstallPermissionSettings');
  }
}

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({required this.version, required this.downloadUrl});

  final AppVersionInfo version;
  final String downloadUrl;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _downloading = false;
  double? _downloadProgress;
  String? _downloadedApkPath;

  @override
  Widget build(BuildContext context) {
    final changelog = (widget.version.changelog ?? '').trim();

    return PopScope(
      canPop: !widget.version.forceUpdate,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppColors.border.withValues(alpha: .9)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.textPrimary.withValues(alpha: .16),
                  blurRadius: 34,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: AppColors.softBlue,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.system_update_alt_rounded,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '发现新版本',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w900,
                                          height: 1.18,
                                        ),
                                  ),
                                ),
                                _VersionBadge(text: widget.version.versionName),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _versionSummary(widget.version),
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: AppColors.textSecondary,
                                    height: 1.55,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _UpdateInfoPanel(
                    title: changelog.isEmpty ? '本次更新' : '更新内容',
                    body: changelog.isEmpty ? '修复了若干问题，优化使用体验。' : changelog,
                  ),
                  const SizedBox(height: 12),
                  const _InstallGuidePanel(),
                  if (widget.version.forceUpdate) ...[
                    const SizedBox(height: 12),
                    const _ForceUpdateNotice(),
                  ],
                  const SizedBox(height: 20),
                  if (_downloadProgress != null) ...[
                    _DownloadProgress(progress: _downloadProgress!),
                    const SizedBox(height: 14),
                  ],
                  FilledButton.icon(
                    onPressed: _downloading
                        ? null
                        : () => unawaited(_downloadAndInstall(context)),
                    icon: _downloading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_rounded, size: 21),
                    label: Text(_downloading ? '正在下载' : '下载并安装'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      textStyle: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => unawaited(_copyDownloadUrl(context)),
                    icon: const Icon(Icons.content_copy_rounded, size: 18),
                    label: const Text('复制下载链接'),
                  ),
                  if (!widget.version.forceUpdate) ...[
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        minimumSize: const Size.fromHeight(44),
                        textStyle: Theme.of(context).textTheme.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      child: const Text('稍后再说'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _versionSummary(AppVersionInfo version) {
    final apkSize = version.apkSize;
    final sizeText = apkSize == null ? '' : ' · ${_formatBytes(apkSize)}';
    return '建议更新到版本代码 ${version.versionCode}$sizeText，获得更稳定的体验。';
  }

  Future<void> _downloadAndInstall(BuildContext context) async {
    setState(() {
      _downloading = true;
      _downloadProgress = 0;
    });
    try {
      final apkPath = _downloadedApkPath ?? await _downloadApk();
      _downloadedApkPath = apkPath;
      await AppApkInstaller.installApk(apkPath);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已打开安装器，请按系统提示完成安装')));
    } on MissingPluginException {
      await _openExternalDownload(context);
    } on PlatformException catch (error) {
      if (error.code == 'install_permission_required') {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('请先允许此来源安装应用，返回后再点一次安装')),
          );
        }
        await AppApkInstaller.openInstallPermissionSettings();
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message ?? '无法打开 APK 安装器')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('下载失败：$error')));
      }
    } finally {
      if (mounted) {
        setState(() => _downloading = false);
      }
    }
  }

  Future<String> _downloadApk() async {
    final uri = Uri.parse(widget.downloadUrl);
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 10));
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('HTTP ${response.statusCode}');
      }
      final directory = await getApplicationDocumentsDirectory();
      final updatesDir = Directory(
        '${directory.path}${Platform.pathSeparator}updates',
      );
      if (!await updatesDir.exists()) {
        await updatesDir.create(recursive: true);
      }
      final file = File(
        '${updatesDir.path}${Platform.pathSeparator}xiaotai_${widget.version.versionCode}.apk',
      );
      final sink = file.openWrite();
      var downloaded = 0;
      final total = response.contentLength;
      try {
        await for (final chunk in response) {
          downloaded += chunk.length;
          sink.add(chunk);
          if (mounted && total > 0) {
            setState(() => _downloadProgress = downloaded / total);
          }
        }
      } finally {
        await sink.close();
      }
      if (mounted) {
        setState(() => _downloadProgress = 1);
      }
      return file.path;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _openExternalDownload(BuildContext context) async {
    final uri = Uri.parse(widget.downloadUrl);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(opened ? '已打开下载链接，请按系统提示完成安装' : '无法打开下载链接，请复制链接后重试'),
      ),
    );
  }

  Future<void> _copyDownloadUrl(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: widget.downloadUrl));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('下载链接已复制')));
  }
}

class _VersionBadge extends StatelessWidget {
  const _VersionBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.softPink,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.accent.withValues(alpha: .18)),
      ),
      child: Text(
        'v$text',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: AppColors.accent,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

class _DownloadProgress extends StatelessWidget {
  const _DownloadProgress({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final percent = (progress.clamp(0, 1) * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: progress.clamp(0, 1),
          minHeight: 8,
          borderRadius: BorderRadius.circular(999),
          backgroundColor: AppColors.border.withValues(alpha: .55),
          color: AppColors.primary,
        ),
        const SizedBox(height: 8),
        Text(
          '下载进度 $percent%',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _UpdateInfoPanel extends StatelessWidget {
  const _UpdateInfoPanel({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border.withValues(alpha: .8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.warning,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InstallGuidePanel extends StatelessWidget {
  const _InstallGuidePanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.softBlue.withValues(alpha: .42),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: .14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.verified_user_outlined,
            color: AppColors.primary,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '下载完成后如果系统拦截安装，请在提示页允许此来源安装应用，再返回安装 APK。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textPrimary,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ForceUpdateNotice extends StatelessWidget {
  const _ForceUpdateNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.softOrange,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.warning.withValues(alpha: .26)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.warning,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '这是必要更新，需要完成下载后继续使用。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  final kb = bytes / 1024;
  if (kb < 1024) {
    return '${kb.toStringAsFixed(1)} KB';
  }
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(1)} MB';
}
