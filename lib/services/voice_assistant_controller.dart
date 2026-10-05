import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
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
import 'speech_intent_fallback.dart';

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
  final SpeechIntentFallback _intentFallback = SpeechIntentFallback();
  int _generation = 0;
  bool _started = false;
  bool _exited = false;
  bool _acceptingResults = false;
  HistoryEntry? _pendingEntry;
  Timer? _retryTimer;
  Timer? _settleTimer;
  Timer? _listenWatchdog;
  bool _transcriptReadyForEval = false;
  double _runningTotal = 0;
  double _continuationBase = 0;
  String? _evaluatedTranscript;
  bool _didRequestClose = false;
  bool _speechReady = false;
  String? _resolvedLocaleId;
  DateTime? _listenStartedAt;
  bool _handlingSpeechError = false;
  bool _ttsReady = false;
  int _consecutiveListenFails = 0;
  bool _usingIntentFallback = false;
  VoidCallback? onRequestClose;

  static const _runningTotalKey = 'advancedCalculator.voiceRunningTotal';
  static const _maxListenFailsBeforeFallback = 2;

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

    final micStatus = await Permission.microphone.status;
    if (_exited) return;
    PermissionStatus mic = micStatus;
    if (!mic.isGranted) {
      mic = await Permission.microphone.request();
    }
    if (_exited) return;
    if (!mic.isGranted) {
      micDenied = true;
      statusText = L10n.text('voice.micDenied', settings.language);
      isPaused = true;
      notifyListeners();
      return;
    }

    _speechReady = await _initializeSpeechEngine();
    if (_exited) return;
    if (!_speechReady) {
      // Fall through to Intent fallback path rather than pausing forever.
      debugPrint('speech_to_text initialize failed — will use Intent fallback');
      _usingIntentFallback = true;
      statusText = L10n.text('voice.listening', settings.language);
      notifyListeners();
      beginListening();
      return;
    }

    _resolvedLocaleId = await _resolveLocaleId(settings);
    if (_exited) return;
    _resolvedLocaleId ??=
        settings.language == AppLanguage.ar ? 'ar_SA' : 'en_US';

    await _ensureTtsReady(settings);
    beginListening();
  }

  Future<bool> _initializeSpeechEngine() async {
    try {
      // Android workarounds that help on more OEM builds:
      // intentLookup finds the recognizer when the default intent is missing;
      // noBluetooth avoids an extra permission some builds gate on;
      // alwaysUseStop improves teardown between listen cycles.
      final ok = await _speech.initialize(
        onError: _onSpeechError,
        onStatus: _onSpeechStatus,
        options: [
          SpeechToText.androidIntentLookup,
          SpeechToText.androidNoBluetooth,
          SpeechToText.androidAlwaysUseStop,
        ],
      );
      return ok;
    } catch (e) {
      debugPrint('speech initialize exception: $e');
      return false;
    }
  }

  Future<void> _ensureTtsReady(AppSettings settings) async {
    if (_ttsReady) return;
    await _tts.awaitSpeakCompletion(true);
    final preferred = settings.language == AppLanguage.ar ? 'ar-SA' : 'en-US';
    final set = await _tts.setLanguage(preferred);
    if (set == 0 || set == false) {
      if (settings.language == AppLanguage.ar) {
        await _tts.setLanguage('ar');
      } else {
        await _tts.setLanguage('en-US');
      }
    }
    _ttsReady = true;
  }

  /// Prefer ar_SA / ar-SA, then any ar*, then en_US / en.
  Future<String?> _resolveLocaleId(AppSettings settings) async {
    List<LocaleName> available;
    try {
      available = await _speech.locales();
    } catch (_) {
      available = const [];
    }
    final ids = available.map((l) => l.localeId).toList();
    String norm(String s) => s.replaceAll('-', '_').toLowerCase();
    final normalized = {for (final id in ids) norm(id): id};

    final preferred = <String>[
      if (settings.language == AppLanguage.ar) ...[
        'ar_sa',
        'ar',
        'ar_eg',
        'ar_ae',
        'ar_jo',
        'ar_kw',
      ] else ...[
        'en_us',
        'en',
        'en_gb',
      ],
      'ar_sa',
      'ar',
      'en_us',
      'en',
    ];

    for (final want in preferred) {
      final exact = normalized[want];
      if (exact != null) return exact;
      final prefix = want.split('_').first;
      for (final entry in normalized.entries) {
        if (entry.key == prefix || entry.key.startsWith('${prefix}_')) {
          return entry.value;
        }
      }
    }

    if (ids.isNotEmpty) return ids.first;
    return settings.language == AppLanguage.ar ? 'ar_SA' : 'en_US';
  }

  void _onSpeechError(SpeechRecognitionError error) {
    if (_exited || _handlingSpeechError) return;
    _handlingSpeechError = true;
    try {
      final code = error.errorMsg;
      debugPrint('speech error: $code permanent=${error.permanent}');
      final settings = _settings;

      if (code.contains('error_speech_recognizer_disabled') ||
          (code.contains('error_client') && error.permanent) ||
          code.contains('error_insufficient_permissions')) {
        if (settings != null) {
          statusText =
              L10n.text('voice.speechServicesMissing', settings.language);
          notifyListeners();
        }
        _consecutiveListenFails++;
        _acceptingResults = false;
        if (_consecutiveListenFails >= _maxListenFailsBeforeFallback) {
          _usingIntentFallback = true;
        }
        _scheduleListenAgain(after: const Duration(milliseconds: 900));
        return;
      }

      if (code.contains('error_language_not_supported') ||
          code.contains('error_language_unavailable')) {
        _acceptingResults = false;
        _stopEngine();
        // Rotate locale and retry; never pause forever.
        _rotateLocaleFallback();
        if (settings != null) {
          statusText = L10n.text('voice.retrying', settings.language);
          notifyListeners();
        }
        _scheduleListenAgain(after: const Duration(milliseconds: 600));
        return;
      }

      if (code.contains('error_no_match') ||
          code.contains('error_speech_timeout') ||
          code.contains('error_network') ||
          code.contains('error_network_timeout') ||
          code.contains('error_busy') ||
          code.contains('error_retry') ||
          code.contains('error_server') ||
          code.contains('error_audio')) {
        if (_acceptingResults && transcript.trim().isNotEmpty) {
          _finishUtterance(endOfTask: true);
        } else {
          _consecutiveListenFails++;
          if (_consecutiveListenFails >= _maxListenFailsBeforeFallback) {
            _usingIntentFallback = true;
          }
          if (settings != null &&
              (code.contains('error_network') ||
                  code.contains('error_server'))) {
            statusText = L10n.text('voice.networkError', settings.language);
            notifyListeners();
          }
          _scheduleListenAgain(after: const Duration(milliseconds: 800));
        }
        return;
      }

      if (_acceptingResults && transcript.trim().isNotEmpty) {
        _finishUtterance(endOfTask: true);
      } else if (!isPaused && !_exited) {
        _consecutiveListenFails++;
        _scheduleListenAgain(after: const Duration(seconds: 1));
      }
    } finally {
      _handlingSpeechError = false;
    }
  }

  void _rotateLocaleFallback() {
    final settings = _settings;
    if (settings == null) return;
    final current = (_resolvedLocaleId ?? '').toLowerCase();
    if (current.startsWith('ar')) {
      _resolvedLocaleId = 'en_US';
    } else if (settings.language == AppLanguage.ar) {
      _resolvedLocaleId = 'ar_SA';
    } else {
      _resolvedLocaleId = 'en_US';
    }
  }

  void _onSpeechStatus(String status) {
    if (_exited) return;
    final started = _listenStartedAt;
    if (started != null &&
        DateTime.now().difference(started) < const Duration(milliseconds: 450)) {
      return;
    }
    if (status == 'done' || status == 'notListening') {
      if (_acceptingResults) {
        _finishUtterance(endOfTask: true);
      }
    }
  }

  void cancelTapped() {
    _generation++;
    _retryTimer?.cancel();
    _settleTimer?.cancel();
    _listenWatchdog?.cancel();
    _tts.stop();
    _stopEngine();
    _intentFallback.cancel();
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
    _listenWatchdog?.cancel();
    _tts.stop();
    _stopEngine();
    _intentFallback.cancel();
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
    _listenWatchdog?.cancel();
    await _tts.stop();
    _stopEngine();
    await _intentFallback.cancel();
    await CuePlayer.stop();
  }

  Future<void> beginListening() async {
    final settings = _settings;
    if (settings == null || _exited || isPaused) return;
    final generation = _generation;
    Future<void> fire() async {
      if (_generation != generation || _exited || isPaused) return;
      if (_usingIntentFallback || !_speechReady) {
        await _startIntentFallbackRecognition();
      } else {
        await _startRecognition();
      }
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

  Future<void> _startIntentFallbackRecognition() async {
    final settings = _settings;
    if (settings == null || _exited || isPaused) return;
    await CuePlayer.stop();
    _continuationBase = _runningTotal;
    _acceptingResults = true;
    showingExactError = false;
    _transcriptReadyForEval = false;
    statusText = L10n.text('voice.listening', settings.language);
    notifyListeners();

    final localeId = (_resolvedLocaleId ??
            (settings.language == AppLanguage.ar ? 'ar_SA' : 'en_US'))
        .replaceAll('_', '-');

    final text = await _intentFallback.listenOnce(localeId: localeId);
    if (_exited || isPaused) return;
    _acceptingResults = false;
    if (text == null || text.isEmpty) {
      _consecutiveListenFails++;
      if (settings.language == AppLanguage.ar) {
        statusText = L10n.text('voice.retrying', settings.language);
        notifyListeners();
      }
      _scheduleListenAgain(after: const Duration(milliseconds: 900));
      return;
    }
    _consecutiveListenFails = 0;
    transcript = text;
    _transcriptReadyForEval = true;
    notifyListeners();
    if (_handleCommandIfPresent(text)) return;
    await _interpretFinalTranscript();
  }

  Future<void> _startRecognition() async {
    final settings = _settings;
    if (settings == null || _exited || isPaused) return;
    await CuePlayer.stop();
    _continuationBase = _runningTotal;
    _stopEngine();
    if (!_speechReady) {
      _usingIntentFallback = true;
      await _startIntentFallbackRecognition();
      return;
    }
    _listenStartedAt = DateTime.now();
    _acceptingResults = true;
    showingExactError = false;
    _transcriptReadyForEval = false;
    statusText = L10n.text('voice.listening', settings.language);
    notifyListeners();

    final localeId = _resolvedLocaleId ??
        (settings.language == AppLanguage.ar ? 'ar_SA' : 'en_US');

    // Watchdog: if listen never actually starts, auto-retry / fall back.
    _listenWatchdog?.cancel();
    final generation = _generation;
    _listenWatchdog = Timer(const Duration(milliseconds: 1600), () {
      if (_generation != generation || _exited || isPaused) return;
      if (!_speech.isListening && _acceptingResults) {
        debugPrint('listen watchdog: not listening — retry/fallback');
        _acceptingResults = false;
        _consecutiveListenFails++;
        if (_consecutiveListenFails >= _maxListenFailsBeforeFallback) {
          _usingIntentFallback = true;
        }
        _scheduleListenAgain(after: const Duration(milliseconds: 400));
      }
    });

    try {
      // Pass listenFor/pauseFor both via options AND top-level (compat).
      // Never force onDevice — Arabic on-device packs are often missing.
      // listenFor / pauseFor / localeId live on SpeechListenOptions (required on
      // many Android builds). Never force onDevice — Arabic packs are often missing.
      await _speech.listen(
        onResult: (result) {
          if (!_acceptingResults || _exited) return;
          final text = result.recognizedWords.trim();
          if (text.isNotEmpty) {
            _consecutiveListenFails = 0;
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
          listenMode: ListenMode.dictation,
          cancelOnError: false,
          onDevice: false,
          localeId: localeId,
          pauseFor: const Duration(seconds: 3),
          listenFor: const Duration(seconds: 45),
        ),
      );

      // Brief settle then confirm engine actually started.
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (_exited || isPaused || !_acceptingResults) return;
      if (!_speech.isListening) {
        debugPrint('listen returned but isListening=false');
        _acceptingResults = false;
        _consecutiveListenFails++;
        if (_consecutiveListenFails >= _maxListenFailsBeforeFallback) {
          _usingIntentFallback = true;
        }
        // Try re-init once before falling back.
        if (_consecutiveListenFails == 1) {
          await _reinitializeSpeech();
        }
        _scheduleListenAgain(after: const Duration(milliseconds: 500));
      }
    } catch (e) {
      debugPrint('speech listen failed: $e');
      _acceptingResults = false;
      _consecutiveListenFails++;
      if (_consecutiveListenFails >= _maxListenFailsBeforeFallback) {
        _usingIntentFallback = true;
      }
      if (_settings != null) {
        statusText = L10n.text('voice.retrying', _settings!.language);
        notifyListeners();
      }
      if (_consecutiveListenFails == 1) {
        await _reinitializeSpeech();
      }
      _scheduleListenAgain(after: const Duration(milliseconds: 700));
    }
  }

  Future<void> _reinitializeSpeech() async {
    // speech_to_text is a process-wide singleton; initialize() is a no-op after
    // the first success. Best recovery: cancel the session, rotate locale, and
    // escalate to the Android SpeechRecognizer Intent fallback.
    try {
      await _speech.cancel();
    } catch (_) {}
    _rotateLocaleFallback();
    if (_consecutiveListenFails >= _maxListenFailsBeforeFallback) {
      _usingIntentFallback = true;
      _speechReady = false;
    }
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
    _listenWatchdog?.cancel();
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
    var lang = languageCode;
    var set = await _tts.setLanguage(lang);
    if (set == 0 || set == false) {
      if (lang.startsWith('ar')) {
        lang = 'ar';
        set = await _tts.setLanguage(lang);
        if (set == 0 || set == false) {
          await _tts.setLanguage('ar-SA');
        }
      } else {
        await _tts.setLanguage('en-US');
      }
    }
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
    _listenWatchdog?.cancel();
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
    _listenWatchdog?.cancel();
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
