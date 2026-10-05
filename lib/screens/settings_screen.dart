import 'package:flutter/material.dart';

import '../core/app_phrases.dart';
import '../l10n/l10n.dart';
import '../models/app_settings.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection:
          settings.language.isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(L10n.text('settings.title', settings.language)),
        ),
        body: ListenableBuilder(
          listenable: settings,
          builder: (context, _) {
            return Column(
              children: [
                Expanded(
                  child: ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          L10n.text('settings.language', settings.language),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      _languageTile(AppLanguage.en),
                      _languageTile(AppLanguage.ar),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Text(
                          L10n.text('settings.language.hint', settings.language),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      const Divider(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Text(
                          L10n.text('settings.section.speech', settings.language),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      SwitchListTile(
                        title: Text(
                          L10n.text('settings.keyboardSpeech', settings.language),
                        ),
                        subtitle: Text(
                          L10n.text(
                            'settings.keyboardSpeech.hint',
                            settings.language,
                          ),
                        ),
                        value: settings.keyboardSpeech,
                        onChanged: settings.setKeyboardSpeech,
                      ),
                      SwitchListTile(
                        title: Text(
                          L10n.text(
                            'settings.assistantSpeech',
                            settings.language,
                          ),
                        ),
                        subtitle: Text(
                          L10n.text(
                            'settings.assistantSpeech.hint',
                            settings.language,
                          ),
                        ),
                        value: settings.assistantSpeech,
                        onChanged: settings.setAssistantSpeech,
                      ),
                      SwitchListTile(
                        title: Text(
                          L10n.text(
                            'settings.verboseMemory',
                            settings.language,
                          ),
                        ),
                        subtitle: Text(
                          L10n.text(
                            'settings.verboseMemory.hint',
                            settings.language,
                          ),
                        ),
                        value: settings.verboseMemorySpeech,
                        onChanged: settings.setVerboseMemorySpeech,
                      ),
                      SwitchListTile(
                        title: Text(
                          L10n.text('settings.speakResult', settings.language),
                        ),
                        subtitle: Text(
                          L10n.text(
                            'settings.speakResult.hint',
                            settings.language,
                          ),
                        ),
                        value: settings.speakResultAfterEquals,
                        onChanged: settings.setSpeakResultAfterEquals,
                      ),
                      ListTile(
                        title: Text(
                          L10n.text('settings.startBeep', settings.language),
                        ),
                        subtitle: Text(
                          L10n.text(
                            'settings.startBeep.hint',
                            settings.language,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SegmentedButton<AssistantStartCue>(
                          segments: [
                            for (final cue in AssistantStartCue.values)
                              ButtonSegment(
                                value: cue,
                                label: Text(
                                  L10n.text(cue.titleKey, settings.language),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          selected: {settings.startCue},
                          onSelectionChanged: (set) {
                            if (set.isNotEmpty) {
                              settings.setStartCue(set.first);
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        title: Text(
                          L10n.text('settings.speechRate', settings.language),
                        ),
                        subtitle: Text(
                          L10n.text(
                            'settings.speechRate.hint',
                            settings.language,
                          ),
                        ),
                      ),
                      Slider(
                        value: settings.speechRate,
                        min: AppSettings.minimumSpeechRate,
                        max: AppSettings.maximumSpeechRate,
                        onChanged: settings.setSpeechRate,
                        label: L10n.text(
                          'settings.speechRate',
                          settings.language,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Semantics(
                    label: AppPhrases.credits,
                    child: Text(
                      AppPhrases.credits,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white70,
                          ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _languageTile(AppLanguage language) {
    final selected = settings.language == language;
    final titleKey =
        language == AppLanguage.en ? 'language.english' : 'language.arabic';
    final hintKey = language == AppLanguage.en
        ? 'language.english.hint'
        : 'language.arabic.hint';
    return ListTile(
      title: Text(L10n.text(titleKey, settings.language)),
      trailing: selected ? const Icon(Icons.check) : null,
      selected: selected,
      onTap: () => settings.setLanguage(language),
      subtitle: Text(L10n.text(hintKey, settings.language)),
    );
  }
}
