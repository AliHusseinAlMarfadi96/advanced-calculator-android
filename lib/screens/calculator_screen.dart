import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/app_settings.dart';
import '../models/calculator_view_model.dart';
import '../models/history_store.dart';
import '../services/button_speaker.dart';
import '../widgets/keypad.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'voice_assistant_screen.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({
    super.key,
    required this.settings,
    required this.history,
  });

  final AppSettings settings;
  final HistoryStore history;

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  late final CalculatorViewModel _model;
  late final ButtonSpeaker _speaker;

  @override
  void initState() {
    super.initState();
    _model = CalculatorViewModel()..attach(widget.history);
    _speaker = ButtonSpeaker();
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  String _pretty(String raw) {
    var text = raw;
    const pairs = [
      ('nroot(', 'ⁿ√('),
      ('sqrt(', '√('),
      ('cbrt(', '∛('),
      ('*', '×'),
      ('/', '÷'),
    ];
    for (final pair in pairs) {
      text = text.replaceAll(pair.$1, pair.$2);
    }
    return text;
  }

  Future<void> _confirmClearHistory() async {
    final settings = widget.settings;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L10n.text('history.clear', settings.language)),
        content: Text(L10n.text('history.clear.hint', settings.language)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(L10n.text('history.close', settings.language)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(L10n.text('history.clear', settings.language)),
          ),
        ],
      ),
    );
    if (ok == true) await widget.history.clearAll();
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    return Directionality(
      textDirection:
          settings.language.isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(L10n.text('app.title', settings.language)),
          leading: Semantics(
            button: true,
            label: L10n.text('nav.history', settings.language),
            hint: L10n.text('nav.history.hint', settings.language),
            child: IconButton(
              icon: const Icon(Icons.history),
              tooltip: L10n.text('nav.history', settings.language),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => HistoryScreen(
                      settings: settings,
                      history: widget.history,
                      onSelect: (entry) {
                        _model.useHistory(entry);
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            Semantics(
              button: true,
              label: L10n.text('nav.voice', settings.language),
              hint: L10n.text('nav.voice.hint', settings.language),
              child: IconButton(
                icon: const Icon(Icons.mic),
                tooltip: L10n.text('nav.voice', settings.language),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => VoiceAssistantScreen(
                        settings: settings,
                        history: widget.history,
                      ),
                      fullscreenDialog: true,
                    ),
                  );
                },
              ),
            ),
            Semantics(
              button: true,
              label: L10n.text('nav.settings', settings.language),
              hint: L10n.text('nav.settings.hint', settings.language),
              child: IconButton(
                icon: const Icon(Icons.settings),
                tooltip: L10n.text('nav.settings', settings.language),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SettingsScreen(settings: settings),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        body: ListenableBuilder(
          listenable: Listenable.merge([_model, settings, widget.history]),
          builder: (context, _) {
            final expression = _pretty(_model.expression);
            final failureText = _model.failure == null
                ? null
                : L10n.failure(_model.failure!, settings.language);
            return LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth > 760;
                final display = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      constraints: const BoxConstraints(minHeight: 140),
                      decoration: BoxDecoration(
                        color: const Color(0xFF171A21),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: Semantics(
                              label: L10n.text(
                                'display.expression',
                                settings.language,
                              ),
                              value: expression,
                              child: Text(
                                expression,
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontSize: 20,
                                  color: Colors.white70,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: Semantics(
                              liveRegion: true,
                              label: L10n.text(
                                'display.result',
                                settings.language,
                              ),
                              value: _model.resultText,
                              child: Text(
                                _model.resultText.isEmpty
                                    ? ' '
                                    : _model.resultText,
                                textAlign: TextAlign.right,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          if (failureText != null) ...[
                            const SizedBox(height: 6),
                            Semantics(
                              liveRegion: true,
                              label: failureText,
                              child: Text(
                                failureText,
                                style: const TextStyle(
                                  color: Color(0xFFFF7366),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Semantics(
                      button: true,
                      label: L10n.text('history.clear', settings.language),
                      hint: L10n.text('history.clear.hint', settings.language),
                      child: OutlinedButton.icon(
                        onPressed: _confirmClearHistory,
                        icon: const Icon(Icons.delete_outline),
                        label: Text(
                          L10n.text('history.clear', settings.language),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFF25447),
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                    ),
                  ],
                );
                final keypad = Keypad(
                  model: _model,
                  speaker: _speaker,
                  settings: settings,
                );
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: display),
                            const SizedBox(width: 20),
                            Expanded(child: keypad),
                          ],
                        )
                      : Column(
                          children: [
                            display,
                            const SizedBox(height: 14),
                            keypad,
                          ],
                        ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
