import 'dart:math' as math;

enum EvalFailure { divideByZero, domain, syntax }

class EvalException implements Exception {
  EvalException(this.failure);
  final EvalFailure failure;
}

class ExpressionEvaluator {
  static const _prefixFunctions = {
    'sin', 'cos', 'tan', 'ln', 'log', 'sqrt', 'cbrt', 'square',
  };
  static const _callFunctions = {
    'sin', 'cos', 'tan', 'ln', 'log', 'sqrt', 'cbrt', 'square', 'nroot',
  };

  static double evaluate(String expression) {
    final parser = _Parser(expression.toLowerCase().codeUnits);
    final value = parser.parseExpression();
    parser.skipWhitespace();
    if (parser.peek() != null) {
      throw EvalException(EvalFailure.syntax);
    }
    if (!value.isFinite) throw EvalException(EvalFailure.domain);
    return value;
  }

  static String format(double value) {
    if (!value.isFinite) return '0';
    if (value.abs() < 1e-12) return '0';
    final nearest = value.roundToDouble();
    final scale = value.abs() < 1 ? 1.0 : value.abs();
    if ((value - nearest).abs() < 1e-8 * scale && nearest.abs() < 1e15) {
      return nearest.toStringAsFixed(0);
    }
    // Match Swift "%.10g" style: up to 10 significant digits.
    final text = value.toStringAsPrecision(10);
    if (text.contains('e') || text.contains('E')) return text;
    var cleaned = text;
    if (cleaned.contains('.')) {
      cleaned = cleaned.replaceFirst(RegExp(r'0+$'), '');
      if (cleaned.endsWith('.')) {
        cleaned = cleaned.substring(0, cleaned.length - 1);
      }
    }
    return cleaned;
  }

  static double apply(String name, double value) {
    switch (name) {
      case 'sin':
        return math.sin(value * math.pi / 180);
      case 'cos':
        return math.cos(value * math.pi / 180);
      case 'tan':
        final radians = value * math.pi / 180;
        final adjacent = math.cos(radians);
        if (adjacent.abs() < 1e-12) {
          throw EvalException(EvalFailure.domain);
        }
        return math.sin(radians) / adjacent;
      case 'ln':
        if (value <= 0) throw EvalException(EvalFailure.domain);
        return math.log(value);
      case 'log':
        if (value <= 0) throw EvalException(EvalFailure.domain);
        return math.log(value) / math.ln10;
      case 'sqrt':
        if (value < 0) throw EvalException(EvalFailure.domain);
        return math.sqrt(value);
      case 'cbrt':
        if (value < 0) return -math.pow(-value, 1.0 / 3.0).toDouble();
        return math.pow(value, 1.0 / 3.0).toDouble();
      case 'square':
        return value * value;
      default:
        throw EvalException(EvalFailure.syntax);
    }
  }

  static double raise(double base, double exponent) {
    if ((exponent.roundToDouble() - exponent).abs() < 1e-9 &&
        exponent.abs() < 10000) {
      return integerPower(base, exponent.round());
    }
    if (base < 0) throw EvalException(EvalFailure.domain);
    final value = math.pow(base, exponent).toDouble();
    if (!value.isFinite) throw EvalException(EvalFailure.domain);
    return value;
  }

  static double integerPower(double base, int exponent) {
    if (exponent == 0) return 1;
    if (base == 0) {
      if (exponent < 0) throw EvalException(EvalFailure.divideByZero);
      return 0;
    }
    var result = 1.0;
    var factor = base;
    var remaining = exponent.abs();
    while (remaining > 0) {
      if (remaining & 1 == 1) result *= factor;
      remaining >>= 1;
      if (remaining > 0) factor *= factor;
      if (!result.isFinite || !factor.isFinite) {
        throw EvalException(EvalFailure.domain);
      }
    }
    if (exponent < 0) {
      if (result == 0) throw EvalException(EvalFailure.divideByZero);
      return 1 / result;
    }
    return result;
  }

  static double factorial(double value) {
    if (value < 0 ||
        value > 170 ||
        (value.roundToDouble() - value).abs() > 1e-8) {
      throw EvalException(EvalFailure.domain);
    }
    final limit = value.round();
    if (limit <= 1) return 1;
    var result = 1.0;
    for (var step = 1; step <= limit; step++) {
      result *= step;
      if (!result.isFinite) throw EvalException(EvalFailure.domain);
    }
    return result;
  }

  static double nthRoot(double index, double radicand) {
    if (index.abs() < 1e-12 ||
        (index.roundToDouble() - index).abs() > 1e-8) {
      throw EvalException(EvalFailure.domain);
    }
    final degree = index.round();
    if (radicand < 0 && degree % 2 == 0) {
      throw EvalException(EvalFailure.domain);
    }
    if (radicand < 0) {
      return -math.pow(-radicand, 1.0 / degree).toDouble();
    }
    final value = math.pow(radicand, 1.0 / degree).toDouble();
    if (!value.isFinite) throw EvalException(EvalFailure.domain);
    return value;
  }
}

class _Parser {
  _Parser(this.chars);
  final List<int> chars;
  int index = 0;

  double parseExpression() {
    var value = parseTerm();
    while (true) {
      if (match(0x2B)) {
        value += parseTerm();
      } else if (match(0x2D)) {
        value -= parseTerm();
      } else {
        break;
      }
      if (!value.isFinite) throw EvalException(EvalFailure.domain);
    }
    return value;
  }

  double parseTerm() {
    var value = parsePower();
    while (true) {
      if (match(0x2A)) {
        value *= parsePower();
      } else if (match(0x2F)) {
        final divisor = parsePower();
        if (divisor.abs() < 1e-12) {
          throw EvalException(EvalFailure.divideByZero);
        }
        value /= divisor;
      } else {
        break;
      }
      if (!value.isFinite) throw EvalException(EvalFailure.domain);
    }
    return value;
  }

  double parsePower() {
    final base = parseUnary();
    if (match(0x5E)) {
      final exponent = parsePower();
      return ExpressionEvaluator.raise(base, exponent);
    }
    return base;
  }

  double parseUnary() {
    skipWhitespace();
    if (match(0x2B)) return parseUnary();
    if (match(0x2D)) return -parseUnary();
    final saved = index;
    final identifier = readIdentifier();
    if (identifier != null) {
      if (ExpressionEvaluator._prefixFunctions.contains(identifier)) {
        skipWhitespace();
        if (peek() != 0x28) {
          final argument = parseUnary();
          return ExpressionEvaluator.apply(identifier, argument);
        }
      }
      index = saved;
    }
    return parsePostfix();
  }

  double parsePostfix() {
    var value = parsePrimary();
    while (true) {
      if (match(0x21)) {
        value = ExpressionEvaluator.factorial(value);
      } else if (match(0x25)) {
        value /= 100;
      } else {
        break;
      }
    }
    return value;
  }

  double parsePrimary() {
    skipWhitespace();
    if (match(0x28)) {
      final value = parseExpression();
      if (!match(0x29)) throw EvalException(EvalFailure.syntax);
      return value;
    }
    final number = readNumber();
    if (number != null) return number;
    final identifier = readIdentifier();
    if (identifier == null) throw EvalException(EvalFailure.syntax);
    if (identifier == 'pi') return math.pi;
    if (identifier == 'e') return 2.718281828459045;
    if (!ExpressionEvaluator._callFunctions.contains(identifier)) {
      throw EvalException(EvalFailure.syntax);
    }
    if (!match(0x28)) throw EvalException(EvalFailure.syntax);
    if (identifier == 'nroot') {
      final indexValue = parseExpression();
      if (!match(0x2C)) throw EvalException(EvalFailure.syntax);
      final radicand = parseExpression();
      if (!match(0x29)) throw EvalException(EvalFailure.syntax);
      return ExpressionEvaluator.nthRoot(indexValue, radicand);
    }
    final argument = parseExpression();
    if (!match(0x29)) throw EvalException(EvalFailure.syntax);
    return ExpressionEvaluator.apply(identifier, argument);
  }

  int? peek() => index < chars.length ? chars[index] : null;

  void skipWhitespace() {
    while (true) {
      final c = peek();
      if (c == null) return;
      if (c == 32 || c == 9 || c == 10 || c == 13) {
        index++;
      } else {
        return;
      }
    }
  }

  bool match(int expected) {
    skipWhitespace();
    if (peek() != expected) return false;
    index++;
    return true;
  }

  String? readIdentifier() {
    skipWhitespace();
    final first = peek();
    if (first == null || !_isLetter(first)) return null;
    final start = index;
    while (true) {
      final c = peek();
      if (c == null || !_isLetter(c)) break;
      index++;
    }
    return String.fromCharCodes(chars.sublist(start, index));
  }

  double? readNumber() {
    skipWhitespace();
    final start = index;
    var sawDigit = false;
    var sawDot = false;
    if (peek() == 0x2E) {
      final next = index + 1;
      if (next < chars.length && _isDigit(chars[next])) {
        sawDot = true;
        index++;
      }
    }
    while (true) {
      final c = peek();
      if (c == null) break;
      if (_isDigit(c)) {
        sawDigit = true;
        index++;
      } else if (c == 0x2E && !sawDot) {
        sawDot = true;
        index++;
      } else {
        break;
      }
    }
    if (!sawDigit) {
      index = start;
      return null;
    }
    var literal = String.fromCharCodes(chars.sublist(start, index));
    if (literal.endsWith('.')) {
      literal = literal.substring(0, literal.length - 1);
    }
    final value = double.tryParse(literal);
    if (value == null) {
      index = start;
      return null;
    }
    return value;
  }

  bool _isLetter(int c) =>
      (c >= 97 && c <= 122) || (c >= 65 && c <= 90);
  bool _isDigit(int c) => c >= 48 && c <= 57;
}
