import 'package:flutter/material.dart';

import '../core/app_phrases.dart';
import '../l10n/l10n.dart';
import '../models/app_settings.dart';
import '../models/history_store.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/voice_assistant_controller.dart';

class VoiceAssistantScreen extends StatefulWidget {
  const VoiceAssistantScreen({
    super.key,
    required this.settings,
    required this.history,
  });

  final AppSettings settings;
  final HistoryStore history;

  @override
  State<VoiceAssistantScreen> createState() => _VoiceAssistantScreenState();
}

class _VoiceAssistantScreenState extends State<VoiceAssistantScreen> {
  late final VoiceAssistantController _model;

  @override
  void initState() {
    super.initState();
    _model = VoiceAssistantController();
    _model.onRequestClose = () {
      if (mounted) Navigator.of(context).pop();
    };
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _ensureMicRationale();
      if (!mounted) return;
      await _model.start(settings: widget.settings, history: widget.history);
    });
  }

  @override
  void dispose() {
    _model.shutdown();
    _model.dispose();
    super.dispose();
  }


  Future<void> _ensureMicRationale() async {
    final status = await Permission.microphone.status;
    if (status.isGranted || status.isPermanentlyDenied) return;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L10n.text('nav.voice', widget.settings.language)),
        content: Text(L10n.text('permission.mic', widget.settings.language)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(L10n.text('history.close', widget.settings.language)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    return Directionality(
      textDirection:
          settings.language.isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        body: SafeArea(
          child: ListenableBuilder(
            listenable: _model,
            builder: (context, _) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        L10n.text('voice.title', settings.language),
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_model.showingExactError)
                      Semantics(
                        liveRegion: true,
                        label: AppPhrases.notUnderstood,
                        child: Text(
                          AppPhrases.notUnderstood,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFFFC740),
                          ),
                        ),
                      )
                    else
                      Semantics(
                        liveRegion: true,
                        label: _model.statusText,
                        child: Text(
                          _model.statusText,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (_model.transcript.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Semantics(
                        label:
                            '${L10n.text('voice.youSaid', settings.language)} ${_model.transcript}',
                        child: Text(
                          _model.transcript,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                    if (_model.expressionText.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Semantics(
                          label: L10n.text('display.expression', settings.language),
                          value: _model.expressionText,
                          child: Text(
                            _model.expressionText,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 20,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (_model.resultText.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Semantics(
                          liveRegion: true,
                          label: L10n.text('display.result', settings.language),
                          value: _model.resultText,
                          child: Text(
                            _model.resultText,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    _control(
                      title: L10n.text('voice.cancel', settings.language),
                      hint: L10n.text('voice.cancel.hint', settings.language),
                      icon: Icons.cancel,
                      onPressed: _model.cancelTapped,
                    ),
                    const SizedBox(height: 12),
                    _control(
                      title: L10n.text(
                        _model.isPaused ? 'voice.resume' : 'voice.pause',
                        settings.language,
                      ),
                      hint: L10n.text(
                        _model.isPaused
                            ? 'voice.resume.hint'
                            : 'voice.pause.hint',
                        settings.language,
                      ),
                      icon: _model.isPaused ? Icons.play_arrow : Icons.pause,
                      onPressed: _model.pauseTapped,
                    ),
                    const SizedBox(height: 12),
                    _control(
                      title: L10n.text('voice.save', settings.language),
                      hint: L10n.text('voice.save.hint', settings.language),
                      icon: Icons.save,
                      onPressed: _model.saveTapped,
                    ),
                    const SizedBox(height: 12),
                    _control(
                      title: L10n.text('voice.exit', settings.language),
                      hint: L10n.text('voice.exit.hint', settings.language),
                      icon: Icons.exit_to_app,
                      onPressed: () async {
                        await _model.shutdown();
                        if (context.mounted) Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _control({
    required String title,
    required String hint,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Semantics(
      button: true,
      label: title,
      hint: hint,
      child: SizedBox(
        height: 56,
        child: FilledButton.icon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(title, style: const TextStyle(fontSize: 18)),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF21476B),
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(56),
          ),
        ),
      ),
    );
  }
}
