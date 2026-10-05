import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/app_settings.dart';
import '../models/history_entry.dart';
import '../models/history_store.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({
    super.key,
    required this.settings,
    required this.history,
    required this.onSelect,
  });

  final AppSettings settings;
  final HistoryStore history;
  final ValueChanged<HistoryEntry> onSelect;

  @override
  Widget build(BuildContext context) {
    final title = L10n.text('history.title', settings.language);
    return Directionality(
      textDirection:
          settings.language.isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: [
            TextButton(
              onPressed: history.entries.isEmpty
                  ? null
                  : () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(
                            L10n.text('history.clear', settings.language),
                          ),
                          content: Text(
                            L10n.text('history.clear.hint', settings.language),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(
                                L10n.text('history.close', settings.language),
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text(
                                L10n.text('history.clear', settings.language),
                              ),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) await history.clearAll();
                    },
              child: Text(L10n.text('history.clear', settings.language)),
            ),
          ],
        ),
        body: history.entries.isEmpty
            ? Center(
                child: Semantics(
                  label: L10n.text('history.empty', settings.language),
                  child: Text(
                    L10n.text('history.empty', settings.language),
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              )
            : ListenableBuilder(
                listenable: history,
                builder: (context, _) {
                  return ListView.builder(
                    itemCount: history.entries.length,
                    itemBuilder: (context, index) {
                      final entry = history.entries[index];
                      final date = entry.createdAt.toLocal().toString().substring(0, 16);
                      return Semantics(
                        button: true,
                        label: '${entry.expression}, ${entry.result}',
                        hint: L10n.text('history.reuse.hint', settings.language),
                        child: ListTile(
                          onTap: () => onSelect(entry),
                          title: Directionality(
                            textDirection: TextDirection.ltr,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.expression,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    color: Colors.white70,
                                  ),
                                ),
                                Text(
                                  entry.result,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                Text(
                                  date,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white54,
                                  ),
                                ),
                              ],
                            ),
                          ),
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
