import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AssistantStartCue {
  beep,
  vibration,
  both;

  bool get playsBeep => this == beep || this == both;
  bool get playsVibration => this == vibration || this == both;

  String get titleKey {
    switch (this) {
      case AssistantStartCue.beep:
        return 'settings.startCue.beep';
      case AssistantStartCue.vibration:
        return 'settings.startCue.vibration';
      case AssistantStartCue.both:
        return 'settings.startCue.both';
    }
  }
}

enum AppLanguage {
  en,
  ar;

  String get localeIdentifier => this == AppLanguage.ar ? 'ar' : 'en';
  String get speechLocale => this == AppLanguage.ar ? 'ar-SA' : 'en-US';
  bool get isRTL => this == AppLanguage.ar;
}

class AppSettings extends ChangeNotifier {
  static const minimumSpeechRate = 0.0;
  static const maximumSpeechRate = 1.0;
  static const defaultSpeechRate = 0.5;

  AppLanguage language = AppLanguage.ar;
  bool keyboardSpeech = true;
  bool assistantSpeech = true;
  AssistantStartCue startCue = AssistantStartCue.both;
  bool verboseMemorySpeech = true;
  bool speakResultAfterEquals = true;
  double speechRate = defaultSpeechRate;

  SharedPreferences? _prefs;
  bool _ready = false;
  bool get isReady => _ready;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final prefs = _prefs!;
    final raw = prefs.getString(_Keys.language);
    if (raw == AppLanguage.en.name) {
      language = AppLanguage.en;
    } else if (raw == AppLanguage.ar.name) {
      language = AppLanguage.ar;
    } else {
      language = AppLanguage.ar; // Default Arabic for TalkBack users.
    }
    keyboardSpeech = prefs.getBool(_Keys.keyboardSpeech) ?? true;
    assistantSpeech = prefs.getBool(_Keys.assistantSpeech) ?? true;
    startCue = _resolveStartCue(prefs);
    verboseMemorySpeech = prefs.getBool(_Keys.verboseMemorySpeech) ?? true;
    speakResultAfterEquals = prefs.getBool(_Keys.speakResultAfterEquals) ?? true;
    if (prefs.containsKey(_Keys.speechRate)) {
      speechRate = clampSpeechRate(prefs.getDouble(_Keys.speechRate) ?? defaultSpeechRate);
    }
    if (!prefs.containsKey(_Keys.startCue)) {
      await prefs.setString(_Keys.startCue, startCue.name);
    }
    _ready = true;
    notifyListeners();
  }

  static double clampSpeechRate(double rate) =>
      rate.clamp(minimumSpeechRate, maximumSpeechRate);

  static AssistantStartCue _resolveStartCue(SharedPreferences prefs) {
    final raw = prefs.getString(_Keys.startCue);
    if (raw != null) {
      for (final cue in AssistantStartCue.values) {
        if (cue.name == raw) return cue;
      }
    }
    if (prefs.getBool(_Keys.legacyStartBeep) == false) {
      return AssistantStartCue.vibration;
    }
    return AssistantStartCue.both;
  }

  Future<void> setLanguage(AppLanguage value) async {
    language = value;
    await _prefs?.setString(_Keys.language, value.name);
    notifyListeners();
  }

  Future<void> setKeyboardSpeech(bool value) async {
    keyboardSpeech = value;
    await _prefs?.setBool(_Keys.keyboardSpeech, value);
    notifyListeners();
  }

  Future<void> setAssistantSpeech(bool value) async {
    assistantSpeech = value;
    await _prefs?.setBool(_Keys.assistantSpeech, value);
    notifyListeners();
  }

  Future<void> setStartCue(AssistantStartCue value) async {
    startCue = value;
    await _prefs?.setString(_Keys.startCue, value.name);
    notifyListeners();
  }

  Future<void> setVerboseMemorySpeech(bool value) async {
    verboseMemorySpeech = value;
    await _prefs?.setBool(_Keys.verboseMemorySpeech, value);
    notifyListeners();
  }

  Future<void> setSpeakResultAfterEquals(bool value) async {
    speakResultAfterEquals = value;
    await _prefs?.setBool(_Keys.speakResultAfterEquals, value);
    notifyListeners();
  }

  Future<void> setSpeechRate(double value) async {
    speechRate = clampSpeechRate(value);
    await _prefs?.setDouble(_Keys.speechRate, speechRate);
    notifyListeners();
  }
}

class _Keys {
  static const language = 'advancedCalculator.language';
  static const keyboardSpeech = 'advancedCalculator.keyboardSpeech';
  static const assistantSpeech = 'advancedCalculator.assistantSpeech';
  static const startCue = 'advancedCalculator.assistantStartCue';
  static const legacyStartBeep = 'advancedCalculator.startBeep';
  static const verboseMemorySpeech = 'advancedCalculator.verboseMemorySpeech';
  static const speakResultAfterEquals = 'advancedCalculator.speakResultAfterEquals';
  static const speechRate = 'advancedCalculator.speechRate';
}
