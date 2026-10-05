import 'expression_evaluator.dart';

/// Arabic equation speech for the voice assistant ("عشرة زائد خمسة يساوي خمسة عشر").
class ArabicEquationSpeech {
  static String sentence({required String expression, required double result}) {
    final spokenExpression = _verbalize(expression);
    final spokenResult = spell(result);
    if (spokenExpression.isEmpty) return spokenResult;
    return '$spokenExpression يساوي $spokenResult';
  }

  static String spell(double value) =>
      spellLiteral(ExpressionEvaluator.format(value));

  /// Integers from -999 through 999 become words. Everything else is spoken as digits.
  static String spellLiteral(String literal) {
    final negative = literal.startsWith('-');
    final body = negative ? literal.substring(1) : literal;
    final number = int.tryParse(body);
    if (number != null && body == number.toString() && number <= 999) {
      return spellInteger(negative ? -number : number);
    }
    return literal;
  }

  static const _ones = [
    '', 'واحد', 'اثنان', 'ثلاثة', 'أربعة', 'خمسة', 'ستة', 'سبعة', 'ثمانية', 'تسعة',
  ];
  static const _teens = [
    'عشرة', 'أحد عشر', 'اثنا عشر', 'ثلاثة عشر', 'أربعة عشر', 'خمسة عشر',
    'ستة عشر', 'سبعة عشر', 'ثمانية عشر', 'تسعة عشر',
  ];
  static const _tens = [
    '', '', 'عشرون', 'ثلاثون', 'أربعون', 'خمسون', 'ستون', 'سبعون', 'ثمانون', 'تسعون',
  ];
  static const _hundreds = [
    '', 'مئة', 'مئتان', 'ثلاثمئة', 'أربعمئة', 'خمسمئة', 'ستمئة', 'سبعمئة', 'ثمانمئة', 'تسعمئة',
  ];

  static String spellInteger(int number) {
    if (number < 0) return 'سالب ${spellInteger(-number)}';
    if (number == 0) return 'صفر';
    if (number < 10) return _ones[number];
    if (number < 20) return _teens[number - 10];
    if (number < 100) {
      final unit = number % 10;
      final ten = number ~/ 10;
      if (unit == 0) return _tens[ten];
      return '${_ones[unit]} و${_tens[ten]}';
    }
    final hundred = number ~/ 100;
    final remainder = number % 100;
    if (remainder == 0) return _hundreds[hundred];
    return '${_hundreds[hundred]} و${spellInteger(remainder)}';
  }

  static String _verbalize(String expression) {
    final chars = expression.split('');
    var index = 0;
    final parts = <String>[];
    var expectingOperand = true;

    void skipSpaces() {
      while (index < chars.length && chars[index].trim().isEmpty) {
        index++;
      }
    }

    String readNumber() {
      var token = '';
      var sawDot = false;
      while (index < chars.length) {
        final character = chars[index];
        if (_isDigit(character)) {
          token += character;
          index++;
        } else if (character == '.' && !sawDot) {
          sawDot = true;
          token += character;
          index++;
        } else {
          break;
        }
      }
      return token;
    }

    String readWord() {
      var token = '';
      while (index < chars.length && _isLetter(chars[index])) {
        token += chars[index];
        index++;
      }
      return token;
    }

    while (index < chars.length) {
      skipSpaces();
      if (index >= chars.length) break;
      final character = chars[index];

      if (character == '-' && expectingOperand) {
        var look = index + 1;
        while (look < chars.length && chars[look].trim().isEmpty) {
          look++;
        }
        if (look < chars.length &&
            (_isDigit(chars[look]) || chars[look] == '.')) {
          index++;
          skipSpaces();
          final token = readNumber();
          if (token.isNotEmpty) {
            parts.add(spellLiteral('-$token'));
            expectingOperand = false;
          }
          continue;
        }
      }

      if ('+-*/^'.contains(character)) {
        parts.add(_operatorWord(character));
        expectingOperand = true;
        index++;
        continue;
      }
      if (character == '(') {
        parts.add('قوس مفتوح');
        expectingOperand = true;
        index++;
        continue;
      }
      if (character == ')') {
        parts.add('قوس مغلق');
        expectingOperand = false;
        index++;
        continue;
      }
      if (character == ',') {
        parts.add('فاصلة');
        expectingOperand = true;
        index++;
        continue;
      }
      if (_isDigit(character) || character == '.') {
        final token = readNumber();
        if (token.isNotEmpty) {
          parts.add(spellLiteral(token));
          expectingOperand = false;
        }
        continue;
      }
      if (_isLetter(character)) {
        final word = readWord();
        if (word.isNotEmpty) {
          parts.add(_functionWord(word));
          expectingOperand = false;
        }
        continue;
      }
      index++;
    }
    return parts.join(' ');
  }

  static String _operatorWord(String character) {
    switch (character) {
      case '+':
        return 'زائد';
      case '-':
        return 'ناقص';
      case '*':
        return 'ضرب';
      case '/':
        return 'قسمة';
      case '^':
        return 'أس';
      default:
        return character;
    }
  }

  static String _functionWord(String word) {
    switch (word) {
      case 'sin':
        return 'جيب';
      case 'cos':
        return 'جيب التمام';
      case 'tan':
        return 'ظل';
      case 'ln':
        return 'لوغاريتم طبيعي';
      case 'log':
        return 'لوغاريتم';
      case 'sqrt':
        return 'جذر';
      case 'cbrt':
        return 'جذر تكعيبي';
      case 'square':
        return 'تربيع';
      case 'nroot':
        return 'جذر نوني';
      case 'pi':
        return 'باي';
      case 'e':
        return 'إي';
      default:
        return word;
    }
  }

  static bool _isDigit(String ch) {
    final c = ch.codeUnitAt(0);
    return c >= 48 && c <= 57;
  }

  static bool _isLetter(String ch) {
    final c = ch.codeUnitAt(0);
    return (c >= 97 && c <= 122) || (c >= 65 && c <= 90);
  }
}
