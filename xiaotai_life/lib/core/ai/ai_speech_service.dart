import 'package:flutter_tts/flutter_tts.dart';

class AiSpeechService {
  AiSpeechService._();

  static final instance = AiSpeechService._();

  final FlutterTts _tts = FlutterTts();
  bool _configured = false;

  Future<void> speak(String text) async {
    final content = text.trim();
    if (content.isEmpty) {
      return;
    }
    try {
      if (!_configured) {
        await _tts.setLanguage('zh-CN');
        await _tts.setSpeechRate(0.48);
        await _tts.setVolume(1);
        await _tts.setPitch(1);
        _configured = true;
      }
      await _tts.stop();
      await _tts.speak(content);
    } on Object {
      // TTS is optional. Unsupported devices should not block the AI flow.
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } on Object {
      // Ignore platform TTS failures.
    }
  }
}
