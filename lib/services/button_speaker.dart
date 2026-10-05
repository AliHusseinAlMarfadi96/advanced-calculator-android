import 'package:flutter_tts/flutter_tts.dart';

class ButtonSpeaker {
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;

  Future<void> _ensureReady() async {
    if (_ready) return;
    await _tts.awaitSpeakCompletion(true);
    await _tts.setVolume(1.0);
    _ready = true;
  }

  Future<void> speak(
    String text, {
    required String languageCode,
    required bool enabled,
    required double rate,
  }) async {
    if (!enabled) return;
    final spoken = text.trim();
    if (spoken.isEmpty) return;
    await _ensureReady();
    await _tts.stop();
    await _tts.setLanguage(languageCode);
    // flutter_tts rate is typically 0.0–1.0; map AVSpeech-like 0–1 directly.
    await _tts.setSpeechRate(rate.clamp(0.0, 1.0));
    await _tts.speak(spoken);
  }

  Future<void> stop() async {
    await _tts.stop();
  }
}
