import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as speech;

import '../../../core/ai/ai_action_parser.dart';
import '../../../core/ai/ai_speech_service.dart';
import '../../../core/ai/bigmodel_service.dart';
import '../../../core/data/app_data_store.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/weather/qweather_service.dart';

Future<void> showAiAssistantSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const AiAssistantSheet(),
  );
}

class AiAssistantSheet extends StatefulWidget {
  const AiAssistantSheet({super.key});

  @override
  State<AiAssistantSheet> createState() => _AiAssistantSheetState();
}

class _AiAssistantSheetState extends State<AiAssistantSheet> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  static const _nativeSpeechChannel = MethodChannel('xiaotai_life/speech');
  late Future<AppLocalStore> _storeFuture;
  late final Future<AppWeatherNow?> _weatherFuture;
  final speech.SpeechToText _speech = speech.SpeechToText();
  bool _loading = false;
  bool _voiceMode = true;
  bool _listening = false;
  bool _nativeSilentListening = false;
  bool _speechReceivedWords = false;
  String? _error;
  AiCreateMoneyRecordAction? _pendingMoneyAction;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onInputChanged);
    _storeFuture = AppLocalStore.create();
    _weatherFuture = QWeatherService.instance
        .fetchNow()
        .timeout(const Duration(seconds: 4), onTimeout: () => null)
        .catchError((_) => null);
  }

  @override
  void dispose() {
    unawaited(AiSpeechService.instance.stop());
    _controller.removeListener(_onInputChanged);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final height = MediaQuery.sizeOf(context).height * 0.82;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: height,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SafeArea(
          top: false,
          child: FutureBuilder<AppLocalStore>(
            future: _storeFuture,
            builder: (context, snapshot) {
              final store = snapshot.data;
              final messages = store?.getAiMessages() ?? const <AppAiMessage>[];
              return Column(
                children: [
                  const SizedBox(height: 10),
                  const _SheetHandle(),
                  _AiHeader(
                    canClear: messages.isNotEmpty && !_loading,
                    onClear: store == null ? null : () => _clear(store),
                  ),
                  Expanded(
                    child: _AiMessageList(
                      controller: _scrollController,
                      messages: messages,
                      loading: _loading,
                      error: _error,
                      pendingMoneyAction: _pendingMoneyAction,
                      onConfirmMoneyAction: store == null
                          ? null
                          : () => _confirmMoneyAction(store),
                      onCancelMoneyAction: _cancelPendingAction,
                    ),
                  ),
                  _AiInputBar(
                    controller: _controller,
                    loading: _loading,
                    voiceMode: _voiceMode,
                    listening: _listening,
                    onToggleInputMode: _toggleInputMode,
                    onListen: _toggleListening,
                    onSend: store == null ? null : () => _ask(store, messages),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _ask(AppLocalStore store, List<AppAiMessage> current) async {
    final question = _controller.text.trim();
    if (_loading) {
      return;
    }
    if (question.isEmpty) {
      _showTopTip('先说一点或写一点想问的内容吧');
      return;
    }
    final now = DateTime.now();
    final userMessage = AppAiMessage(
      id: 'ai_user_${now.microsecondsSinceEpoch}',
      role: 'user',
      content: question,
      createdAt: now,
    );
    _controller.clear();
    setState(() {
      _loading = true;
      _error = null;
      _pendingMoneyAction = null;
    });
    await store.addAiMessage(userMessage);
    _refresh();
    _scrollToBottom();
    try {
      final fixedAnswer = _fixedAnswer(question);
      final action = fixedAnswer == null
          ? await _tryParseAction(question, now)
          : null;
      final answer =
          fixedAnswer ??
          action?.speech ??
          await _chatAnswer(store, current, userMessage);
      await store.addAiMessage(
        AppAiMessage(
          id: 'ai_assistant_${DateTime.now().microsecondsSinceEpoch}',
          role: 'assistant',
          content: answer,
          createdAt: DateTime.now(),
        ),
      );
      if (mounted && action is AiCreateMoneyRecordAction) {
        setState(() => _pendingMoneyAction = action);
        unawaited(AiSpeechService.instance.speak(action.speech));
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = _friendlyError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _refresh();
        _scrollToBottom();
      }
    }
  }

  Future<void> _clear(AppLocalStore store) async {
    await store.clearAiMessages();
    if (mounted) {
      setState(() {
        _error = null;
        _pendingMoneyAction = null;
        _storeFuture = Future.value(store);
      });
    }
  }

  void _toggleInputMode() {
    if (_listening) {
      unawaited(_speech.stop());
    }
    setState(() {
      _voiceMode = !_voiceMode;
      _listening = false;
    });
  }

  void _onInputChanged() {
    if (mounted && _voiceMode) {
      setState(() {});
    }
  }

  Future<void> _toggleListening() async {
    if (_loading) {
      return;
    }
    if (_listening) {
      if (defaultTargetPlatform == TargetPlatform.android &&
          _nativeSilentListening) {
        await _nativeSpeechChannel.invokeMethod<void>('stopSilent');
      } else {
        await _speech.stop();
      }
      if (mounted) {
        setState(() {
          _listening = false;
          _nativeSilentListening = false;
        });
      }
      return;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      final appMicReady = await _ensureAppAudioPermission();
      if (!appMicReady) {
        return;
      }
      final engineReady = await _ensureSpeechEnginePermission();
      if (!engineReady) {
        return;
      }
      await _startNativeSilentSpeechInput();
      return;
    }
    late final bool ready;
    try {
      ready = await _speech.initialize(
        onStatus: (status) {
          debugPrint('speech_to_text status: $status');
          if (!mounted) {
            return;
          }
          if (status == 'done' || status == 'notListening') {
            final shouldPrompt = _listening && !_speechReceivedWords;
            setState(() => _listening = false);
            if (shouldPrompt) {
              Future<void>.delayed(const Duration(milliseconds: 300), () {
                if (mounted &&
                    !_listening &&
                    controllerTextForSpeech.trim().isEmpty) {
                  _showTopTip('没有识别到文字，请再说一次或切换键盘输入');
                }
              });
            }
          }
        },
        onError: (error) {
          debugPrint('speech_to_text error: ${error.errorMsg}');
          if (!mounted) {
            return;
          }
          setState(() => _listening = false);
          final message = _speechErrorMessage(error.errorMsg);
          _showTopTip(message);
        },
      );
    } on Object catch (error) {
      debugPrint('speech_to_text initialize failed: $error');
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _startSystemSpeechInput();
      } else if (mounted) {
        _showTopTip('语音输入启动失败，请检查系统语音识别服务');
      }
      return;
    }
    if (!ready) {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _startSystemSpeechInput();
      } else if (mounted) {
        _showTopTip('没有可用的语音识别服务，请切换键盘输入');
      }
      return;
    }
    final localeId = await _preferredSpeechLocaleId();
    if (mounted) {
      setState(() {
        _listening = true;
        _speechReceivedWords = false;
      });
      _showTopTip('正在听你说话');
    }
    try {
      await _speech.listen(
        listenOptions: speech.SpeechListenOptions(
          listenMode: speech.ListenMode.dictation,
          partialResults: true,
          localeId: localeId,
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
        ),
        onResult: (result) {
          debugPrint(
            'speech_to_text result: "${result.recognizedWords}", final=${result.finalResult}',
          );
          _controller.text = result.recognizedWords;
          _controller.selection = TextSelection.collapsed(
            offset: _controller.text.length,
          );
          if (mounted) {
            setState(() {
              _speechReceivedWords = result.recognizedWords.trim().isNotEmpty;
            });
          }
        },
      );
    } on Object catch (error) {
      debugPrint('speech_to_text listen failed: $error');
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _startSystemSpeechInput();
      } else if (mounted) {
        setState(() => _listening = false);
        _showTopTip('语音输入启动失败，请检查系统语音识别服务');
      }
    }
  }

  Future<bool> _ensureAppAudioPermission() async {
    try {
      final granted =
          await _nativeSpeechChannel.invokeMethod<bool>(
            'ensureAppAudioPermission',
          ) ??
          false;
      if (!granted && mounted) {
        _showTopTip('请先允许小泰使用麦克风');
      }
      return granted;
    } on MissingPluginException {
      return true;
    } on Object catch (error) {
      debugPrint('app audio permission check failed: $error');
      return true;
    }
  }

  Future<bool> _ensureSpeechEnginePermission() async {
    try {
      final engineReady =
          await _nativeSpeechChannel.invokeMethod<bool>(
            'engineHasAudioPermission',
          ) ??
          true;
      if (engineReady) {
        return true;
      }
      _showTopTip('请给系统语音引擎开启麦克风权限');
      unawaited(_nativeSpeechChannel.invokeMethod<void>('openEngineSettings'));
      return false;
    } on MissingPluginException {
      return true;
    } on Object catch (error) {
      debugPrint('speech engine permission check failed: $error');
      return true;
    }
  }

  Future<void> _startNativeSilentSpeechInput() async {
    setState(() {
      _listening = true;
      _nativeSilentListening = true;
      _speechReceivedWords = false;
    });
    _showTopTip('正在听你说话');
    try {
      final text = await _nativeSpeechChannel.invokeMethod<String>(
        'recognizeSilent',
      );
      if (!mounted) {
        return;
      }
      final recognizedText = text?.trim() ?? '';
      setState(() {
        _listening = false;
        _nativeSilentListening = false;
      });
      if (recognizedText.isEmpty) {
        _showTopTip('没有识别到文字，请再说一次或切换键盘输入');
        return;
      }
      _controller.text = recognizedText;
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
      setState(() {
        _speechReceivedWords = true;
        _voiceMode = true;
      });
      _showTopTip('已识别语音内容');
    } on PlatformException catch (error) {
      debugPrint('native silent speech failed: ${error.code} ${error.message}');
      if (!mounted) {
        return;
      }
      setState(() {
        _listening = false;
        _nativeSilentListening = false;
      });
      if (error.code == 'engine_permission_denied') {
        _showTopTip('请给系统语音引擎开启麦克风权限');
        unawaited(
          _nativeSpeechChannel.invokeMethod<void>('openEngineSettings'),
        );
        return;
      }
      _showTopTip('语音识别暂时不可用，请切换键盘输入');
    } on Object catch (error) {
      debugPrint('native silent speech failed: $error');
      if (!mounted) {
        return;
      }
      setState(() {
        _listening = false;
        _nativeSilentListening = false;
      });
      _showTopTip('语音输入启动失败，请切换键盘输入');
    }
  }

  Future<bool> _startSystemSpeechInput() async {
    if (_listening) {
      return true;
    }
    final engineReady =
        await _nativeSpeechChannel.invokeMethod<bool>(
          'engineHasAudioPermission',
        ) ??
        true;
    if (!engineReady) {
      _showTopTip('请给系统语音引擎开启麦克风权限');
      unawaited(_nativeSpeechChannel.invokeMethod<void>('openEngineSettings'));
      return true;
    }
    setState(() {
      _listening = true;
      _speechReceivedWords = false;
    });
    _showTopTip('正在打开系统语音识别');
    try {
      final text = await _nativeSpeechChannel.invokeMethod<String>('recognize');
      if (!mounted) {
        return true;
      }
      final recognizedText = text?.trim() ?? '';
      setState(() => _listening = false);
      if (recognizedText.isEmpty) {
        _showTopTip('没有识别到文字，请再说一次或切换键盘输入');
        return true;
      }
      _controller.text = recognizedText;
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
      setState(() {
        _speechReceivedWords = true;
        _voiceMode = true;
      });
      _showTopTip('已识别语音内容');
      return true;
    } on MissingPluginException {
      if (mounted) {
        setState(() => _listening = false);
      }
      return false;
    } on PlatformException catch (error) {
      debugPrint('native speech failed: ${error.code} ${error.message}');
      if (mounted) {
        setState(() => _listening = false);
        if (error.code == 'engine_permission_denied') {
          _showTopTip('请给系统语音引擎开启麦克风权限');
          unawaited(
            _nativeSpeechChannel.invokeMethod<void>('openEngineSettings'),
          );
        } else {
          _showTopTip('系统语音识别不可用，请切换键盘输入');
        }
      }
      return true;
    } on Object catch (error) {
      debugPrint('native speech failed: $error');
      if (mounted) {
        setState(() => _listening = false);
        _showTopTip('语音输入启动失败，请切换键盘输入');
      }
      return true;
    }
  }

  String get controllerTextForSpeech => _controller.text;

  String _speechErrorMessage(String errorMsg) {
    if (errorMsg.contains('error_no_match')) {
      return '没有识别到文字，请再说一次';
    }
    if (errorMsg.contains('error_speech_timeout')) {
      return '没有听到声音，请靠近手机再试一次';
    }
    if (errorMsg.contains('error_audio')) {
      return '麦克风暂时不可用，请检查录音权限';
    }
    if (errorMsg.contains('error_client') ||
        errorMsg.contains('error_server') ||
        errorMsg.contains('network')) {
      return '系统语音识别暂时不可用，请切换键盘输入';
    }
    return '语音输入暂时不可用，请切换键盘输入';
  }

  Future<String?> _preferredSpeechLocaleId() async {
    try {
      final locales = await _speech.locales();
      for (final locale in locales) {
        final id = locale.localeId.toLowerCase().replaceAll('-', '_');
        if (id == 'zh_cn' || id.startsWith('zh_')) {
          return locale.localeId;
        }
      }
      final systemLocale = await _speech.systemLocale();
      return systemLocale?.localeId;
    } on Object {
      return null;
    }
  }

  void _showTopTip(String message) {
    final overlay = Overlay.of(context, rootOverlay: true);
    final entry = OverlayEntry(
      builder: (context) {
        final top = MediaQuery.paddingOf(context).top + 14;
        return Positioned(
          top: top,
          left: 20,
          right: 20,
          child: IgnorePointer(
            child: Material(
              color: Colors.transparent,
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.textPrimary.withValues(alpha: 0.14),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 11,
                    ),
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(entry);
    Future<void>.delayed(const Duration(milliseconds: 1700), () {
      if (entry.mounted) {
        entry.remove();
      }
    });
  }

  String? _fixedAnswer(String question) {
    final normalized = question.replaceAll(RegExp(r'[\s？?！!。,.，]'), '');
    if (normalized.contains('辛天豪是谁')) {
      return '辛天豪是婷婷小笨笔记的开发和维护者，是究极无敌最最最厉害的婷婷男朋友呀 💪✨';
    }
    if (normalized.contains('婷婷是谁') ||
        normalized.contains('泰书萍是谁') ||
        normalized.contains('婷婷泰书萍是谁')) {
      return '婷婷（泰书萍）是小笨笔记的使用者，这个就是小新大王给婷婷开发的呀。婷婷是辛天豪的可爱女朋友 🥰✨';
    }
    if (normalized.contains('小笨笔记彩蛋') ||
        normalized.contains('布布暗号') ||
        normalized.contains('小新大王暗号')) {
      return '暗号对上啦：婷婷的小笨笔记会偷偷记住每个认真生活的瞬间，也会偷偷偏心婷婷一点点 🫶✨';
    }
    if (normalized.contains('今天也要开心') || normalized.contains('给婷婷一句悄悄话')) {
      return '悄悄话：婷婷不用每天都很厉害，只要每天都被小新大王好好喜欢就可以啦 🌷';
    }
    return null;
  }

  Future<AiPendingAction?> _tryParseAction(
    String question,
    DateTime now,
  ) async {
    try {
      return await AiActionParser.instance
          .parse(question, now)
          .timeout(const Duration(seconds: 12));
    } on Object {
      return null;
    }
  }

  Future<String> _chatAnswer(
    AppLocalStore store,
    List<AppAiMessage> current,
    AppAiMessage userMessage,
  ) async {
    final weather = await _weatherFuture.timeout(
      const Duration(milliseconds: 800),
      onTimeout: () => null,
    );
    final history = [...current, userMessage].takeLast(12).toList();
    final prompt = _buildAiPrompt(store, history, weather);
    return BigModelService.instance.chat(prompt);
  }

  Future<void> _confirmMoneyAction(AppLocalStore store) async {
    final action = _pendingMoneyAction;
    if (action == null || _loading) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final now = DateTime.now();
      final record = AppMoneyRecord(
        id: 'money_${now.microsecondsSinceEpoch}',
        type: action.type,
        title: action.title,
        amountCents: action.amountCents,
        category: action.category,
        happenedAt: action.happenedAt,
        createdAt: now,
        updatedAt: now,
        note: action.note,
        owner: 'shared',
      );
      await store.upsertMoneyRecord(record);
      final successText =
          '已记账：${_formatActionDate(action.happenedAt)}${action.title}${action.isIncome ? '收入' : '花了'}${_formatActionMoney(action.amountCents)}。';
      await store.addAiMessage(
        AppAiMessage(
          id: 'ai_assistant_${DateTime.now().microsecondsSinceEpoch}',
          role: 'assistant',
          content: successText,
          createdAt: DateTime.now(),
        ),
      );
      if (mounted) {
        setState(() => _pendingMoneyAction = null);
      }
      unawaited(AiSpeechService.instance.speak(successText));
    } catch (error) {
      if (mounted) {
        setState(() => _error = _friendlyError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _refresh();
        _scrollToBottom();
      }
    }
  }

  void _cancelPendingAction() {
    if (!mounted) {
      return;
    }
    setState(() => _pendingMoneyAction = null);
  }

  String _formatActionDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return '今天';
    }
    return '${date.month}月${date.day}日';
  }

  String _formatActionMoney(int cents) {
    final yuan = cents ~/ 100;
    final cent = cents % 100;
    if (cent == 0) {
      return '$yuan元';
    }
    return '$yuan.${cent.toString().padLeft(2, '0')}元';
  }

  void _refresh() {
    if (!mounted) {
      return;
    }
    setState(() {
      _storeFuture = AppLocalStore.create();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  String _buildAiPrompt(
    AppLocalStore store,
    List<AppAiMessage> history,
    AppWeatherNow? weather,
  ) {
    final settings = store.getSettings();
    final auth = store.getAuthSession();
    final entries = store.getEntries().takeLast(3).toList();
    final memos = store.getMemos().takeLast(3).toList();
    final reminders = store.getReminders().takeLast(4).toList();
    final places = store.getPlaces().takeLast(3).toList();
    final moneyRecords = store.getMoneyRecords().takeLast(3).toList();
    final buffer = StringBuffer()
      ..writeln('你正在和用户连续对话。请记住并参考下方最近对话，回答最后一个用户问题。')
      ..writeln('要求：优先回答用户原问题，不要改题；回答简短、具体、自然。')
      ..writeln('如果用户询问人物、关系、最近记录或“我是谁”，优先使用下面的应用上下文，不要泛泛回答。')
      ..writeln()
      ..writeln('应用上下文（可信）：')
      ..writeln('应用：婷婷小笨笔记，私有生活记录 App。')
      ..writeln('当前资料：${settings.profileName}；签名：${settings.profileMotto}。')
      ..writeln('称呼约定：布布、小新大王、辛天豪指 App 的开发和维护者；一二、婷婷指主要使用者。');
    if (auth != null) {
      buffer.writeln('当前登录账号：${auth.username}。');
    }
    buffer
      ..writeln(
        '本地数据概况：记录${store.getEntries().length}条，备忘${store.getMemos().length}条，提醒${store.getReminders().length}条，地点${store.getPlaces().length}条，账目${store.getMoneyRecords().length}条。',
      )
      ..writeln(
        _aiLines(
          '最近记录',
          entries.map(
            (entry) => '${entry.title}：${_clipAiText(entry.content)}',
          ),
        ),
      )
      ..writeln(
        _aiLines(
          '最近备忘',
          memos.map((memo) => '${memo.title}：${_clipAiText(memo.content)}'),
        ),
      )
      ..writeln(
        _aiLines(
          '近期提醒',
          reminders.map(
            (reminder) =>
                '${reminder.title}，${_formatAiDate(reminder.scheduledAt)}',
          ),
        ),
      )
      ..writeln(
        _aiLines(
          '想去地点',
          places.map(
            (place) => '${place.title}：${_clipAiText(place.description)}',
          ),
        ),
      )
      ..writeln(
        _aiLines(
          '最近账目',
          moneyRecords.map(
            (record) =>
                '${record.title}，${record.category}，${record.isIncome ? '收入' : '支出'}${_formatAiMoney(record.amountCents)}',
          ),
        ),
      );
    if (weather != null) {
      buffer
        ..writeln()
        ..writeln('天气背景仅在问题相关时参考：')
        ..writeln(
          '${weather.cityName}，${weather.text}，${weather.temp}°C，体感${weather.feelsLike}°C，湿度${weather.humidity}%，${weather.windDir}${weather.windScale}级。',
        );
    }
    buffer.writeln();
    buffer.writeln('最近对话：');
    for (final message in history) {
      buffer.writeln('${message.isUser ? '用户' : '智能布布'}：${message.content}');
    }
    return buffer.toString();
  }

  String _aiLines(String label, Iterable<String> values) {
    final items = values.where((item) => item.trim().isNotEmpty).toList();
    if (items.isEmpty) {
      return '$label：暂无。';
    }
    return '$label：${items.join('；')}。';
  }

  String _clipAiText(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.length <= 48) {
      return normalized;
    }
    return '${normalized.substring(0, 48)}...';
  }

  String _formatAiDate(DateTime date) {
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.year}年${date.month}月${date.day}日 ${date.hour}:$minute';
  }

  String _formatAiMoney(int cents) {
    final yuan = cents ~/ 100;
    final cent = cents % 100;
    return '¥$yuan.${cent.toString().padLeft(2, '0')}';
  }

  String _friendlyError(Object error) {
    if (error is TimeoutException) {
      return '请求超时，请检查项目后端是否正常运行，或 XIAOTAI_API_BASE_URL 是否配置正确';
    }
    final message = error
        .toString()
        .replaceFirst('Bad state: ', '')
        .replaceFirst('Exception: ', '')
        .trim();
    if (message.startsWith('TimeoutException')) {
      return '请求超时，请检查项目后端是否正常运行，或 XIAOTAI_API_BASE_URL 是否配置正确';
    }
    return message;
  }
}

class _AiHeader extends StatelessWidget {
  const _AiHeader({required this.canClear, required this.onClear});

  final bool canClear;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.softPink,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.auto_awesome_outlined,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('智能的布布大王', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 2),
                Text(
                  BigModelService.hasProjectApi
                      ? '布布大王知无不言'
                      : BigModelService.hasApiKey
                      ? '臭一二什么都可以问布布大王哦❤️'
                      : '完蛋了，智能布布大王出问题了快去找小新大王解决😶‍🌫️',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '清空记忆',
            onPressed: canClear ? onClear : null,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
    );
  }
}

class _AiMessageList extends StatelessWidget {
  const _AiMessageList({
    required this.controller,
    required this.messages,
    required this.loading,
    required this.error,
    required this.pendingMoneyAction,
    required this.onConfirmMoneyAction,
    required this.onCancelMoneyAction,
  });

  final ScrollController controller;
  final List<AppAiMessage> messages;
  final bool loading;
  final String? error;
  final AiCreateMoneyRecordAction? pendingMoneyAction;
  final VoidCallback? onConfirmMoneyAction;
  final VoidCallback onCancelMoneyAction;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty && !loading && error == null) {
      return const _AiEmptyState();
    }
    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
      children: [
        for (final message in messages)
          _AiBubble(key: ValueKey(message.id), message: message),
        if (pendingMoneyAction != null)
          _MoneyActionCard(
            action: pendingMoneyAction!,
            loading: loading,
            onConfirm: onConfirmMoneyAction,
            onCancel: onCancelMoneyAction,
          ),
        if (loading) const _TypingBubble(),
        if (error != null) _AiErrorCard(text: error!),
      ],
    );
  }
}

class _MoneyActionCard extends StatelessWidget {
  const _MoneyActionCard({
    required this.action,
    required this.loading,
    required this.onConfirm,
    required this.onCancel,
  });

  final AiCreateMoneyRecordAction action;
  final bool loading;
  final VoidCallback? onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amountText = _formatMoney(action.amountCents);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: .48),
        border: Border.all(color: Colors.white.withValues(alpha: .78)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.softGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.receipt_long_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '待确认记账',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ActionRow(label: '名称', value: action.title),
          _ActionRow(
            label: '金额',
            value: '${action.isIncome ? '+' : '-'}$amountText',
          ),
          _ActionRow(label: '分类', value: action.category),
          _ActionRow(label: '日期', value: _formatDate(action.happenedAt)),
          if (action.note.isNotEmpty)
            _ActionRow(label: '备注', value: action.note),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: loading ? null : onCancel,
                  child: const Text('取消'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: loading ? null : onConfirm,
                  child: const Text('确认记账'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatMoney(int cents) {
    final yuan = cents ~/ 100;
    final cent = cents % 100;
    if (cent == 0) {
      return '$yuan元';
    }
    return '$yuan.${cent.toString().padLeft(2, '0')}元';
  }

  static String _formatDate(DateTime date) {
    return '${date.year}年${date.month}月${date.day}日';
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiBubble extends StatelessWidget {
  const _AiBubble({required this.message, super.key});

  final AppAiMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.74,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(18).copyWith(
            bottomRight: isUser ? const Radius.circular(5) : null,
            bottomLeft: isUser ? null : const Radius.circular(5),
          ),
        ),
        child: Text(
          message.content,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: isUser ? Colors.white : AppColors.textPrimary,
            height: 1.45,
          ),
        ),
      ),
    );
  }
}

class _AiInputBar extends StatelessWidget {
  const _AiInputBar({
    required this.controller,
    required this.loading,
    required this.voiceMode,
    required this.listening,
    required this.onToggleInputMode,
    required this.onListen,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool loading;
  final bool voiceMode;
  final bool listening;
  final VoidCallback onToggleInputMode;
  final VoidCallback onListen;
  final VoidCallback? onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          IconButton.filledTonal(
            tooltip: voiceMode ? '切换到键盘输入' : '切换到语音输入',
            onPressed: loading ? null : onToggleInputMode,
            icon: Icon(voiceMode ? Icons.keyboard_alt_outlined : Icons.mic),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: voiceMode
                ? OutlinedButton.icon(
                    onPressed: loading ? null : onListen,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      alignment: Alignment.centerLeft,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    icon: Icon(
                      listening ? Icons.stop_circle_outlined : Icons.mic,
                    ),
                    label: Text(
                      controller.text.trim().isEmpty
                          ? (listening ? '正在听你说...' : '点这里说话，智能布布会帮你记下来')
                          : controller.text.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                : TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: '智能布布会记住你说问的问题哦~',
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: loading ? null : onSend,
            style: FilledButton.styleFrom(
              minimumSize: const Size(48, 48),
              padding: EdgeInsets.zero,
              shape: const CircleBorder(),
            ),
            child: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.arrow_upward),
          ),
        ],
      ),
    );
  }
}

class _AiEmptyState extends StatelessWidget {
  const _AiEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.forum_outlined,
              color: AppColors.textTertiary,
              size: 42,
            ),
            const SizedBox(height: 12),
            Text('开始连续提问', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              '智能布布会记住最近的问答，下次可以继续追问。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Text('智能布布正在思考...'),
      ),
    );
  }
}

class _AiErrorCard extends StatelessWidget {
  const _AiErrorCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.softPink,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 6,
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}

extension _TakeLast<T> on Iterable<T> {
  Iterable<T> takeLast(int count) {
    final items = toList();
    if (items.length <= count) {
      return items;
    }
    return items.skip(items.length - count);
  }
}
