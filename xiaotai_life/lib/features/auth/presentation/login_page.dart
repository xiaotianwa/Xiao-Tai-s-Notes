import 'package:flutter/material.dart';

import '../../../core/auth/app_auth_notifier.dart';
import '../../../core/auth/app_auth_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/data/app_data_store.dart';
import '../../../core/notifications/local_notification_service.dart';
import '../../../core/sync/app_sync_service.dart';
import '../../../core/theme/app_theme_tokens.dart';
import '../../../shared/widgets/prototype_ui.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController(text: 'admin');
  final _passwordController = TextEditingController();
  bool _busy = false;
  bool _rememberMe = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.themeTokens;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              tokens.warmSurface.withValues(alpha: .18),
              tokens.surface.withValues(alpha: .08),
              tokens.softBlue.withValues(alpha: .12),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(22, 22, 22, bottomInset + 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 14),
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: tokens.surface,
                          borderRadius: BorderRadius.circular(36),
                          boxShadow: softShadowFor(tokens),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: Image.asset(
                            tokens.assets.login,
                            width: 164,
                            height: 164,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '小日常',
                        style: Theme.of(
                          context,
                        ).textTheme.headlineMedium?.copyWith(fontSize: 34),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        AppConstants.appName,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: tokens.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tokens.loginSubtitle,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: tokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                SoftCard(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: tokens.softBlue,
                              borderRadius: BorderRadius.circular(
                                tokens.shape.controlRadius,
                              ),
                            ),
                            child: Icon(
                              Icons.lock_open_outlined,
                              color: tokens.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '私有账号登录',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _usernameController,
                        enabled: !_busy,
                        textInputAction: TextInputAction.next,
                        decoration: _inputDecoration(
                          '用户名',
                          Icons.person_outline,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passwordController,
                        enabled: !_busy,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        decoration: _inputDecoration(
                          '密码',
                          Icons.password_outlined,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Checkbox(
                            value: _rememberMe,
                            onChanged: _busy
                                ? null
                                : (value) {
                                    setState(() => _rememberMe = value ?? true);
                                  },
                          ),
                          Text(
                            '记住我',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _busy ? null : _submit,
                          icon: _busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.login_outlined),
                          label: Text(_busy ? '登录中' : '进入小日常'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    final tokens = context.themeTokens;
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: tokens.background,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.shape.controlRadius),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.shape.controlRadius),
        borderSide: BorderSide(color: tokens.border),
      ),
    );
  }

  Future<void> _submit() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    if (username.isEmpty || password.isEmpty) {
      _showSnack('请填写用户名和密码');
      return;
    }
    setState(() => _busy = true);
    try {
      final store = await AppLocalStore.create();
      final session = await AppAuthService.instance.login(
        username: username,
        password: password,
      );
      await store.saveAuthSession(session);
      var syncMessage = '登录成功，云端记录已确认最新';
      try {
        await store.markSyncStarted();
        final result = await AppSyncService(
          store,
        ).sync(accessToken: session.accessToken);
        await LocalNotificationService.instance.syncPinnedReminders(
          store.getReminders(),
        );
        await LocalNotificationService.instance.syncMemoReminders(
          store.getMemos(),
        );
        await store.markSyncSucceeded(
          pushed: result.pushed,
          pulled: result.pulled,
          conflicts: result.conflicts,
        );
        if (result.conflictCount > 0) {
          syncMessage = '登录成功，已自动同步，有 ${result.conflictCount} 条冲突待处理';
        } else if (result.pushed + result.pulled > 0) {
          syncMessage = '登录成功，已自动同步 ${result.pushed + result.pulled} 条记录';
        }
      } catch (syncError) {
        await store.markSyncFailed(syncError);
        syncMessage = '登录成功，但自动同步失败：${_cleanError(syncError)}';
      }
      if (!mounted) {
        return;
      }
      _showSnack(syncMessage);
      // 通知路由 redirect 重新计算，会自动从 /login 跳到 /today，无需手动 pop。
      AppAuthNotifier.instance.setSession(session);
    } catch (error) {
      if (mounted) {
        _showSnack(error.toString().replaceFirst('Bad state: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(message, textAlign: TextAlign.center),
        ),
      );
  }

  String _cleanError(Object error) {
    return error.toString().replaceFirst('Bad state: ', '');
  }
}
