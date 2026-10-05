import 'package:flutter/foundation.dart';

import '../core/expression_evaluator.dart';
import 'history_entry.dart';
import 'history_store.dart';

class CalculatorViewModel extends ChangeNotifier {
  String expression = '0';
  String resultText = '0';
  EvalFailure? failure;
  bool justEvaluated = false;

  HistoryStore? _history;
  static const _binaryOperators = {'+', '-', '*', '/', '^'};

  void attach(HistoryStore store) {
    _history ??= store;
  }

  void clearDisplay() {
    expression = '0';
    resultText = '0';
    failure = null;
    justEvaluated = false;
    notifyListeners();
  }

  void backspace() {
    if (justEvaluated) {
      clearDisplay();
      return;
    }
    if (expression == '0') return;
    expression = _deletingLastToken(expression);
    if (expression.isEmpty) expression = '0';
    justEvaluated = false;
    _refresh(showSyntaxErrors: false);
  }

  void toggleSign() {
    if (justEvaluated && resultText.isNotEmpty) {
      expression = resultText;
      justEvaluated = false;
    }
    if (expression.endsWith('*(-1)')) {
      expression = expression.substring(0, expression.length - 5);
      _refresh(showSyntaxErrors: false);
      return;
    }
    final wrapped = RegExp(r'\(\-(\d+\.?\d*)\)$').firstMatch(expression);
    if (wrapped != null) {
      final inner = wrapped.group(1)!;
      expression = expression.replaceRange(wrapped.start, wrapped.end, inner);
      if (expression.isEmpty) expression = '0';
      _refresh(showSyntaxErrors: false);
      return;
    }
    final range = RegExp(r'(\d+\.?\d*)$').firstMatch(expression);
    if (range == null) {
      if (expression == '0') {
        expression = '-';
      } else {
        expression += '*(-1)';
      }
      _refresh(showSyntaxErrors: false);
      return;
    }
    final number = range.group(0)!;
    if (range.start > 0) {
      final minusIndex = range.start - 1;
      if (expression[minusIndex] == '-' && _isUnaryMinus(minusIndex)) {
        expression = expression.substring(0, minusIndex) +
            expression.substring(minusIndex + 1);
        if (expression.isEmpty) expression = '0';
        _refresh(showSyntaxErrors: false);
        return;
      }
    }
    if (range.start == 0) {
      expression = '-$number';
    } else {
      expression = expression.replaceRange(
        range.start,
        range.end,
        '(-$number)',
      );
    }
    _refresh(showSyntaxErrors: false);
  }

  void input(String token) {
    if (justEvaluated) {
      final continues = (token.length == 1 &&
              _binaryOperators.contains(token[0])) ||
          token == '!' ||
          token == '%' ||
          token == '^2' ||
          token == '^';
      if (continues && resultText.isNotEmpty) {
        expression = resultText;
      } else {
        expression = '0';
      }
      justEvaluated = false;
    }
    if (token == '.') {
      _appendDecimal();
      _refresh(showSyntaxErrors: false);
      return;
    }
    if (token.length == 1 && _binaryOperators.contains(token[0])) {
      _appendOperator(token[0]);
      _refresh(showSyntaxErrors: false);
      return;
    }
    if (expression == '0' && _replacesLeadingZero(token)) {
      expression = '';
    }
    if (expression.isNotEmpty &&
        _endsWithValue(expression) &&
        _startsValue(token)) {
      expression += '*';
    }
    expression += token;
    _refresh(showSyntaxErrors: false);
  }

  Future<void> equals() async {
    _refresh(showSyntaxErrors: true);
    if (failure != null) {
      justEvaluated = false;
      notifyListeners();
      return;
    }
    await _history?.add(expression: expression, result: resultText);
    justEvaluated = true;
    notifyListeners();
  }

  void useHistory(HistoryEntry entry) {
    expression = entry.expression;
    resultText = entry.result;
    failure = null;
    justEvaluated = false;
    notifyListeners();
  }

  void _appendDecimal() {
    if (justEvaluated) {
      expression = '0';
      justEvaluated = false;
    }
    final segment = _currentNumberSegment(expression);
    if (segment.contains('.')) return;
    if (expression.isEmpty || expression == '0') {
      expression = '0.';
      return;
    }
    final last = expression[expression.length - 1];
    if (_isDigit(last)) {
      expression += '.';
    } else {
      if (_endsWithValue(expression)) expression += '*';
      expression += '0.';
    }
  }

  void _appendOperator(String op) {
    if (expression.isEmpty || expression == '-') {
      if (op == '-') expression = '-';
      return;
    }
    final last = expression[expression.length - 1];
    if (_binaryOperators.contains(last)) {
      expression = expression.substring(0, expression.length - 1) + op;
      return;
    }
    expression += op;
  }

  bool _replacesLeadingZero(String token) {
    if (token == '!' || token == '%' || token == '^' || token == '^2') {
      return false;
    }
    return true;
  }

  bool _endsWithValue(String text) {
    if (text.isEmpty) return false;
    final last = text[text.length - 1];
    if (_isDigit(last) || last == ')' || last == '!' || last == '%') {
      return true;
    }
    if (text.endsWith('pi')) return true;
    if (text.endsWith('e')) {
      if (text.length == 1) return true;
      final prev = text[text.length - 2];
      if (!_isLetter(prev)) return true;
    }
    return false;
  }

  bool _startsValue(String token) {
    if (token == 'pi' || token == 'e' || token == '(') return true;
    if (token.endsWith('(')) return true;
    if (token.isNotEmpty && _isDigit(token[0])) return true;
    return false;
  }

  bool _isUnaryMinus(int index) {
    if (index == 0) return true;
    final previous = expression[index - 1];
    return '+-*/^('.contains(previous);
  }

  String _currentNumberSegment(String text) {
    var segment = '';
    for (var i = text.length - 1; i >= 0; i--) {
      final character = text[i];
      if (_isDigit(character) || character == '.') {
        segment = character + segment;
      } else {
        break;
      }
    }
    return segment;
  }

  String _deletingLastToken(String text) {
    const tokens = [
      'nroot(', 'square(', 'sqrt(', 'cbrt(', 'sin(', 'cos(', 'tan(', 'log(', 'ln(',
      'nroot', 'square', 'sqrt', 'cbrt', 'sin', 'cos', 'tan', 'log', 'ln', 'pi',
    ];
    for (final token in tokens) {
      if (text.endsWith(token)) {
        return text.substring(0, text.length - token.length);
      }
    }
    return text.substring(0, text.length - 1);
  }

  void _refresh({required bool showSyntaxErrors}) {
    final source = expression.trim();
    if (source.isEmpty || source == '-') {
      resultText = source == '-' ? '' : '0';
      failure = showSyntaxErrors ? EvalFailure.syntax : null;
      notifyListeners();
      return;
    }
    try {
      final value = ExpressionEvaluator.evaluate(source);
      resultText = ExpressionEvaluator.format(value);
      failure = null;
    } on EvalException catch (error) {
      switch (error.failure) {
        case EvalFailure.syntax:
          failure = showSyntaxErrors ? EvalFailure.syntax : null;
          resultText = '';
        case EvalFailure.divideByZero:
        case EvalFailure.domain:
          failure = error.failure;
          resultText = '';
      }
    } catch (_) {
      if (showSyntaxErrors) {
        failure = EvalFailure.syntax;
        resultText = '';
      }
    }
    notifyListeners();
  }

  bool _isDigit(String ch) {
    final c = ch.codeUnitAt(0);
    return c >= 48 && c <= 57;
  }

  bool _isLetter(String ch) {
    final c = ch.codeUnitAt(0);
    return (c >= 97 && c <= 122) || (c >= 65 && c <= 90);
  }
}
