import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../core/app_phrases.dart';
import '../core/arabic_equation_speech.dart';
import '../core/expression_evaluator.dart';
import '../core/speech_math_parser.dart';
import '../l10n/l10n.dart';
import '../models/app_settings.dart';
import '../models/history_entry.dart';
import '../models/history_store.dart';
import 'cue_player.dart';

class VoiceAssistantController extends ChangeNotifier {
  String statusText = '';
  bool showingExactError = false;
  String transcript = '';
  String expressionText = '';
  String resultText = '';
  bool isPaused = false;
  bool canSave = false;
  bool micDenied = false;

  AppSettings? _settings;
  HistoryStore? _history;
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  int _generation = 0;
  bool _started = false;
  bool _exited = false;
  bool _acceptingResults = false;
  HistoryEntry? _pendingEntry;
  Timer? _retryTimer;
  Timer? _settleTimer;
  bool _transcriptReadyForEval = false;
  double _runningTotal = 0;
  double _continuationBase = 0;
  String? _evaluatedTranscript;
  bool _didRequestClose = false;
  bool _speechReady = false;
  VoidCallback? onRequestClose;

  static const _runningTotalKey = 'advancedCalculator.voiceRunningTotal';

  Future<void> start({
    required AppSettings settings,
    required HistoryStore history,
  }) async {
    _settings = settings;
    _history = history;
    if (_started) return;
    _started = true;
    await _loadRunningTotal();
    statusText = L10n.text('voice.listening', settings.language);
    notifyListeners();

    final mic = await Permission.microphone.request();
    if (_exited) return;
    if (!mic.isGranted) {
      micDenied = true;
      statusText = L10n.text('voice.micDenied', settings.language);
      isPaused = true;
      notifyListeners();
      return;
    }

    _speechReady = await _speech.initialize(
      onError: (e) {
        if (!_exited) {
          _finishUtterance(endOfTask: true);
        }
      },
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (_acceptingResults) {
            _finishUtterance(endOfTask: true);
          }
        }
      },
    );
    if (_exited) return;
    if (!_speechReady) {
      statusText = L10n.text('voice.unavailable', settings.language);
      isPaused = true;
      notifyListeners();
      return;
    }
    await _tts.awaitSpeakCompletion(true);
    beginListening();
  }

  void cancelTapped() {
    _generation++;
    _retryTimer?.cancel();
    _settleTimer?.cancel();
    _tts.stop();
    _stopEngine();
    _transcriptReadyForEval = false;
    _evaluatedTranscript = null;
    transcript = '';
    expressionText = '';
    resultText = '';
    _pendingEntry = null;
    canSave = false;
    showingExactError = false;
    isPaused = true;
    if (_settings != null) {
      statusText = L10n.text('voice.cancelled', _settings!.language);
    }
    notifyListeners();
  }

  void pauseTapped() {
    final settings = _settings;
    if (settings == null) return;
    if (isPaused) {
      isPaused = false;
      showingExactError = false;
      statusText = L10n.text('voice.listening', settings.language);
      notifyListeners();
      beginListening();
      return;
    }
    _generation++;
    _retryTimer?.cancel();
    _settleTimer?.cancel();
    _tts.stop();
    _stopEngine();
    isPaused = true;
    showingExactError = false;
    statusText = L10n.text('voice.paused', settings.language);
    notifyListeners();
  }

  Future<void> saveTapped() async {
    final settings = _settings;
    if (settings == null) return;
    final spoken = transcript.trim();
    if (_handleCommandIfPresent(spoken)) return;
    final visibleExpression = expressionText.trim();
    final text = spoken.isNotEmpty ? spoken : visibleExpression;
    final alreadyEvaluated =
        _pendingEntry != null && spoken.isNotEmpty && spoken == _evaluatedTranscript;
    if (text.isNotEmpty && !alreadyEvaluated) {
      final interpretation =
          SpeechMathParser.interpret(text, continuingFrom: _continuationBase);
      if (interpretation is SpeechSuccess) {
        _commitSuccess(
          expression: interpretation.expression,
          value: interpretation.result,
          spoken: spoken,
        );
      } else if (interpretation is SpeechNotUnderstood) {
        canSave = false;
        _pendingEntry = null;
        _presentNotUnderstood(resumeListening: !isPaused);
        return;
      } else if (interpretation is SpeechMathError) {
        canSave = false;
        _pendingEntry = null;
        showingExactError = false;
        final message = L10n.failure(interpretation.failure, settings.language);
        statusText = message;
        notifyListeners();
        if (settings.assistantSpeech) {
          await _speak(message, languageCode: settings.language.speechLocale);
        }
        return;
      }
    }
    final pending = _pendingEntry;
    if (pending == null) {
      showingExactError = false;
      statusText = L10n.text('voice.nothingToSave', settings.language);
      notifyListeners();
      return;
    }
    await _history?.add(expression: pending.expression, result: pending.result);
    showingExactError = false;
    statusText = L10n.text('voice.saved', settings.language);
    notifyListeners();
  }

  Future<void> shutdown() async {
    _exited = true;
    _generation++;
    _retryTimer?.cancel();
    _settleTimer?.cancel();
    await _tts.stop();
    _stopEngine();
    await CuePlayer.stop();
  }

  Future<void> beginListening() async {
    final settings = _settings;
    if (settings == null || _exited || isPaused) return;
    final generation = _generation;
    Future<void> fire() async {
      if (_generation != generation || _exited || isPaused) return;
      await _startRecognition();
    }

    final cue = settings.startCue;
    if (cue.playsVibration) {
      await CuePlayer.vibrate();
    }
    if (cue.playsBeep) {
      await CuePlayer.playBeep();
      await Future<void>.delayed(const Duration(milliseconds: 280));
      await fire();
    } else {
      await fire();
    }
  }

  Future<void> _startRecognition() async {
    final settings = _settings;
    if (settings == null || _exited || isPaused) return;
    await CuePlayer.stop();
    _continuationBase = _runningTotal;
    _stopEngine();
    if (!_speechReady) {
      statusText = L10n.text('voice.unavailable', settings.language);
      isPaused = true;
      notifyListeners();
      return;
    }
    _acceptingResults = true;
    showingExactError = false;
    _transcriptReadyForEval = false;
    statusText = L10n.text('voice.listening', settings.language);
    notifyListeners();
    final localeId = settings.language.speechLocale;
    await _speech.listen(
      onResult: (result) {
        if (!_acceptingResults || _exited) return;
        final text = result.recognizedWords.trim();
        if (text.isNotEmpty) {
          transcript = result.recognizedWords;
          if (_handleCommandIfPresent(transcript)) return;
          _transcriptReadyForEval = true;
          notifyListeners();
          _scheduleSettle();
        }
        if (result.finalResult) {
          _finishUtterance(endOfTask: true);
        }
      },
      listenOptions: SpeechListenOptions(
        partialResults: true,
        listenMode: ListenMode.confirmation,
        cancelOnError: false,
        onDevice: true,
        localeId: localeId,
        pauseFor: const Duration(seconds: 2),
        listenFor: const Duration(seconds: 30),
      ),
    );
  }

  void _scheduleSettle({bool force = false}) {
    _settleTimer?.cancel();
    final generation = _generation;
    _settleTimer = Timer(const Duration(seconds: 1), () {
      if (_generation != generation || _exited || isPaused) return;
      _finishUtterance(endOfTask: force);
    });
  }

  void _finishUtterance({required bool endOfTask}) {
    if (!_acceptingResults) return;
    final spoken = transcript.trim();
    if (_transcriptReadyForEval && _handleCommandIfPresent(spoken)) return;
    final shouldInterpret = _transcriptReadyForEval && spoken.isNotEmpty;
    if (shouldInterpret && !endOfTask) {
      final interpretation =
          SpeechMathParser.interpret(spoken, continuingFrom: _continuationBase);
      if (interpretation is SpeechNotUnderstood) {
        _scheduleSettle(force: true);
        return;
      }
    }
    _acceptingResults = false;
    _settleTimer?.cancel();
    _stopEngine();
    if (shouldInterpret) {
      _interpretFinalTranscript();
    } else {
      _scheduleListenAgain(after: const Duration(milliseconds: 500));
    }
  }

  Future<void> _interpretFinalTranscript() async {
    final settings = _settings;
    if (settings == null) return;
    final spoken = transcript.trim();
    if (spoken.isEmpty) {
      _scheduleListenAgain(after: const Duration(milliseconds: 400));
      return;
    }
    if (_handleCommandIfPresent(spoken)) return;
    final interpretation =
        SpeechMathParser.interpret(spoken, continuingFrom: _continuationBase);
    if (interpretation is SpeechSuccess) {
      _commitSuccess(
        expression: interpretation.expression,
        value: interpretation.result,
        spoken: spoken,
      );
      final formatted = ExpressionEvaluator.format(interpretation.result);
      final String sentence;
      final String languageCode;
      if (settings.verboseMemorySpeech) {
        sentence = ArabicEquationSpeech.sentence(
          expression: interpretation.expression,
          result: interpretation.result,
        );
        languageCode = 'ar-SA';
      } else {
        sentence = L10n.text('voice.resultSpoken', settings.language)
            .replaceAll('%@', formatted);
        languageCode = settings.language.speechLocale;
      }
      statusText = sentence;
      notifyListeners();
      if (settings.assistantSpeech) {
        await _speak(sentence, languageCode: languageCode);
        _scheduleListenAgain(after: const Duration(milliseconds: 400));
      } else {
        _scheduleListenAgain(after: const Duration(milliseconds: 800));
      }
    } else if (interpretation is SpeechNotUnderstood) {
      _presentNotUnderstood();
    } else if (interpretation is SpeechMathError) {
      final message = L10n.failure(interpretation.failure, settings.language);
      showingExactError = false;
      statusText = message;
      notifyListeners();
      if (settings.assistantSpeech) {
        await _speak(message, languageCode: settings.language.speechLocale);
        _scheduleListenAgain(after: const Duration(milliseconds: 400));
      } else {
        _scheduleListenAgain(after: const Duration(milliseconds: 1200));
      }
    }
  }

  void _presentNotUnderstood({bool resumeListening = true}) {
    _stopEngine();
    showingExactError = true;
    canSave = false;
    _pendingEntry = null;
    statusText = AppPhrases.notUnderstood;
    notifyListeners();
    final settings = _settings;
    if (settings == null) return;
    Future<void> resume() async {
      if (!resumeListening) return;
      _scheduleListenAgain(after: const Duration(seconds: 3));
    }

    if (settings.assistantSpeech) {
      _speak(AppPhrases.notUnderstood, languageCode: 'ar-SA').then((_) => resume());
    } else {
      resume();
    }
  }

  void _scheduleListenAgain({required Duration after}) {
    if (_exited || isPaused) return;
    _retryTimer?.cancel();
    final generation = _generation;
    _retryTimer = Timer(after, () {
      if (_generation != generation || _exited || isPaused) return;
      if (_settings != null) {
        showingExactError = false;
        statusText = L10n.text('voice.listening', _settings!.language);
        notifyListeners();
      }
      beginListening();
    });
  }

  Future<void> _speak(String text, {required String languageCode}) async {
    final settings = _settings;
    await _tts.stop();
    await _tts.setLanguage(languageCode);
    await _tts.setSpeechRate(
      (settings?.speechRate ?? AppSettings.defaultSpeechRate).clamp(0.0, 1.0),
    );
    await _tts.speak(text);
  }

  Future<void> _loadRunningTotal() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_runningTotalKey)) {
      _runningTotal = prefs.getDouble(_runningTotalKey) ?? 0;
    } else {
      _runningTotal = 0;
    }
    _continuationBase = _runningTotal;
    final formatted = ExpressionEvaluator.format(_runningTotal);
    if (formatted != '0') {
      resultText = formatted;
    }
  }

  Future<void> _commitSuccess({
    required String expression,
    required double value,
    required String spoken,
  }) async {
    final formatted = ExpressionEvaluator.format(value);
    expressionText = expression;
    resultText = formatted;
    canSave = true;
    _pendingEntry = HistoryEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      expression: expression,
      result: formatted,
      createdAt: DateTime.now(),
    );
    if (spoken.isNotEmpty) {
      _evaluatedTranscript = spoken;
    }
    _runningTotal = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_runningTotalKey, value);
    showingExactError = false;
    notifyListeners();
  }

  bool _handleCommandIfPresent(String spoken) {
    final command = _recognizeCommand(spoken);
    if (command == null) return false;
    _acceptingResults = false;
    _settleTimer?.cancel();
    _retryTimer?.cancel();
    _stopEngine();
    switch (command) {
      case _AssistantVoiceCommand.clearMemory:
        _clearRunningTotalAndSpeak();
      case _AssistantVoiceCommand.close:
        if (_didRequestClose) return true;
        _didRequestClose = true;
        shutdown();
        onRequestClose?.call();
    }
    return true;
  }

  Future<void> _clearRunningTotalAndSpeak() async {
    _runningTotal = 0;
    _continuationBase = 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_runningTotalKey, 0);
    expressionText = '';
    resultText = '0';
    canSave = false;
    _pendingEntry = null;
    _evaluatedTranscript = null;
    showingExactError = false;
    final settings = _settings;
    if (settings == null) return;
    statusText = AppPhrases.memoryCleared;
    notifyListeners();
    if (settings.assistantSpeech) {
      await _speak(AppPhrases.memoryCleared, languageCode: 'ar-SA');
      _scheduleListenAgain(after: const Duration(milliseconds: 400));
    } else {
      _scheduleListenAgain(after: const Duration(milliseconds: 800));
    }
  }

  void _stopEngine() {
    _acceptingResults = false;
    if (_speech.isListening) {
      _speech.stop();
    }
  }

  _AssistantVoiceCommand? _recognizeCommand(String spoken) {
    switch (SpeechMathParser.commandKey(spoken)) {
      case 'حذف':
      case 'تصفير':
        return _AssistantVoiceCommand.clearMemory;
      case 'ايقاف':
      case 'خروج':
        return _AssistantVoiceCommand.close;
      default:
        return null;
    }
  }
}

enum _AssistantVoiceCommand { clearMemory, close }
