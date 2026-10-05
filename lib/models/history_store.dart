import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'history_entry.dart';

class HistoryStore extends ChangeNotifier {
  HistoryStore({this.limit = 100});

  final int limit;
  final List<HistoryEntry> entries = [];
  SharedPreferences? _prefs;
  static const _storageKey = 'advancedCalculator.history';

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final data = _prefs?.getString(_storageKey);
    if (data == null) return;
    try {
      final list = jsonDecode(data) as List<dynamic>;
      entries
        ..clear()
        ..addAll(list.map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>)));
      notifyListeners();
    } catch (_) {}
  }

  Future<void> add({required String expression, required String result}) async {
    final trimmedExpression = expression.trim();
    final trimmedResult = result.trim();
    if (trimmedExpression.isEmpty || trimmedResult.isEmpty) return;
    if (entries.isNotEmpty &&
        entries.first.expression == trimmedExpression &&
        entries.first.result == trimmedResult) {
      return;
    }
    entries.insert(
      0,
      HistoryEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        expression: trimmedExpression,
        result: trimmedResult,
        createdAt: DateTime.now(),
      ),
    );
    if (entries.length > limit) {
      entries.removeRange(limit, entries.length);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> clearAll() async {
    entries.clear();
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final data = jsonEncode(entries.map((e) => e.toJson()).toList());
    await _prefs?.setString(_storageKey, data);
  }
}
