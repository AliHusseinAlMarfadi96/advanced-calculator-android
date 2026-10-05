import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One-shot system speech recognition via Android RecognizerIntent /
/// SpeechRecognizer. Used when continuous [speech_to_text] fails on a device.
class SpeechIntentFallback {
  SpeechIntentFallback();

  static const _channel = MethodChannel('advanced_calculator/speech');

  bool _busy = false;

  /// Returns recognized text, or null if cancelled / unavailable / failed.
  Future<String?> listenOnce({
    required String localeId,
    Duration timeout = const Duration(seconds: 25),
  }) async {
    if (_busy) return null;
    _busy = true;
    try {
      final result = await _channel
          .invokeMethod<dynamic>('listenOnce', <String, dynamic>{
        'localeId': localeId,
        'timeoutMs': timeout.inMilliseconds,
      }).timeout(timeout + const Duration(seconds: 5), onTimeout: () => null);
      if (result is String && result.trim().isNotEmpty) {
        return result.trim();
      }
      return null;
    } on PlatformException catch (e) {
      debugPrint('speech intent fallback failed: ${e.code} ${e.message}');
      return null;
    } catch (e) {
      debugPrint('speech intent fallback error: $e');
      return null;
    } finally {
      _busy = false;
    }
  }

  Future<void> cancel() async {
    try {
      await _channel.invokeMethod<void>('cancel');
    } catch (_) {}
  }
}
