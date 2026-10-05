import 'package:flutter/services.dart';

/// Start-listening cue: synthesized beep and/or vibration via the platform channel.
class CuePlayer {
  static const _channel = MethodChannel('advanced_calculator/cue');

  static Future<void> playBeep() async {
    try {
      await _channel.invokeMethod('beep');
    } catch (_) {}
  }

  static Future<void> vibrate() async {
    try {
      await _channel.invokeMethod('vibrate');
    } catch (_) {
      await HapticFeedback.mediumImpact();
    }
  }

  static Future<void> stop() async {
    try {
      await _channel.invokeMethod('stop');
    } catch (_) {}
  }
}
