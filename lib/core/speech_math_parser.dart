import 'expression_evaluator.dart';

sealed class SpeechInterpretation {
  const SpeechInterpretation();
}

class SpeechSuccess extends SpeechInterpretation {
  const SpeechSuccess(this.expression, this.result);
  final String expression;
  final double result;
}

class SpeechNotUnderstood extends SpeechInterpretation {
  const SpeechNotUnderstood();
}

class SpeechMathError extends SpeechInterpretation {
  const SpeechMathError(this.failure);
  final EvalFailure failure;
}

class SpeechMathParser {
  /// `memory`, when set, is prefixed onto a leading-operator phrase (`+ 5`, `ناقص خمسة`, `x5`)
  /// so the phrase continues the running total. A full expression such as `2x5` does not start
  /// with an operator after normalization and replaces that total instead.
  static SpeechInterpretation interpret(String spoken, {double? continuingFrom}) {
    final normalized = normalize(spoken);
    if (normalized.trim().isEmpty) return const SpeechNotUnderstood();
    var rest = normalized;
    var output = '';
    var sawUnknownWord = false;
    while (rest.isNotEmpty) {
      if (rest.codeUnitAt(0) <= 32) {
        output += ' ';
        while (rest.isNotEmpty && rest.codeUnitAt(0) <= 32) {
          rest = rest.substring(1);
        }
        continue;
      }
      final match = _matchReplacement(rest);
      if (match != null) {
        if (match.token.isNotEmpty) {
          output += ' ${match.token} ';
        }
        rest = rest.substring(match.length);
        continue;
      }
      final character = rest[0];
      rest = rest.substring(1);
      if (_isDigitChar(character) || '()+-*/^!%.,'.contains(character)) {
        output += character;
        continue;
      }
      if (_isLetterChar(character)) {
        sawUnknownWord = true;
        output += character;
        while (rest.isNotEmpty && _isLetterChar(rest[0])) {
          output += rest[0];
          rest = rest.substring(1);
        }
        continue;
      }
    }
    if (sawUnknownWord || _containsArabic(output)) {
      return const SpeechNotUnderstood();
    }
    final expression = _tidy(output);
    final String solvable;
    if (_isContinuation(expression)) {
      if (!_hasMathValue(expression)) return const SpeechNotUnderstood();
      solvable = ExpressionEvaluator.format(continuingFrom ?? 0) + expression;
    } else {
      if (!_hasMathValue(expression)) return const SpeechNotUnderstood();
      solvable = expression;
    }
    try {
      final value = ExpressionEvaluator.evaluate(solvable);
      return SpeechSuccess(solvable, value);
    } on EvalException catch (e) {
      switch (e.failure) {
        case EvalFailure.syntax:
          return const SpeechNotUnderstood();
        case EvalFailure.divideByZero:
        case EvalFailure.domain:
          return SpeechMathError(e.failure);
      }
    } catch (_) {
      return const SpeechNotUnderstood();
    }
  }

  static String commandKey(String spoken) {
    final normalized = normalize(spoken);
    final cleaned = StringBuffer();
    for (final r in normalized.runes) {
      final ch = String.fromCharCode(r);
      // approximate: treat punctuation/symbols as spaces
      final code = ch.codeUnitAt(0);
      final isPunct = (code >= 33 && code <= 47) ||
          (code >= 58 && code <= 64) ||
          (code >= 91 && code <= 96) ||
          (code >= 123 && code <= 126) ||
          ch == '؟' ||
          ch == '،' ||
          ch == '؛';
      if (isPunct) {
        cleaned.write(' ');
      } else {
        cleaned.write(ch);
      }
    }
    return cleaned.toString().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).join(' ');
  }

  static _Match? _matchReplacement(String text) {
    for (final item in _replacements) {
      final length = _prefixLength(text, item.phrase);
      if (length != null) return _Match(item.token, length);
    }
    return null;
  }

  static final List<_Pair> _replacements = () {
    const pairs = <(String, String)>[
      ('to the power of', '^'),
      ('raised to the power of', '^'),
      ('to the power', '^'),
      ('power of', '^'),
      ('raised to', '^'),
      ('divided by', '/'),
      ('divide by', '/'),
      ('multiplied by', '*'),
      ('square root of', 'sqrt'),
      ('cube root of', 'cbrt'),
      ('square root', 'sqrt'),
      ('cube root', 'cbrt'),
      ('open parenthesis', '('),
      ('close parenthesis', ')'),
      ('open parentheses', '('),
      ('close parentheses', ')'),
      ('open bracket', '('),
      ('close bracket', ')'),
      ('natural log of', 'ln'),
      ('natural log', 'ln'),
      ('square of', 'square'),
      ('sine of', 'sin'),
      ('cosine of', 'cos'),
      ('tangent of', 'tan'),
      ('what is', ''),
      ("what's", ''),
      ('whats', ''),
      ('calculate', ''),
      ('compute', ''),
      ('equals', ''),
      ('equal', ''),
      ('please', ''),
      ('times', '*'),
      ('plus', '+'),
      ('minus', '-'),
      ('power', '^'),
      ('divide', '/'),
      ('over', '/'),
      ('squared', '^2'),
      ('cubed', '^3'),
      ('factorial', '!'),
      ('percent', '%'),
      ('percentage', '%'),
      ('sine', 'sin'),
      ('cosine', 'cos'),
      ('tangent', 'tan'),
      ('point', '.'),
      ('dot', '.'),
      ('zero', '0'),
      ('one', '1'),
      ('two', '2'),
      ('three', '3'),
      ('four', '4'),
      ('five', '5'),
      ('six', '6'),
      ('seven', '7'),
      ('eight', '8'),
      ('nine', '9'),
      ('ten', '10'),
      ('eleven', '11'),
      ('twelve', '12'),
      ('thirteen', '13'),
      ('fourteen', '14'),
      ('fifteen', '15'),
      ('sixteen', '16'),
      ('seventeen', '17'),
      ('eighteen', '18'),
      ('nineteen', '19'),
      ('twenty', '20'),
      ('thirty', '30'),
      ('forty', '40'),
      ('fifty', '50'),
      ('sixty', '60'),
      ('seventy', '70'),
      ('eighty', '80'),
      ('ninety', '90'),
      ('hundred', '100'),
      ('pi', 'pi'),
      ('log', 'log'),
      ('ln', 'ln'),
      ('the', ''),
      ('of', ''),
      ('an', ''),
      ('a', ''),
      ('um', ''),
      ('uh', ''),
      ('x', '*'),
      ('euler', 'e'),
      ('e', 'e'),
      ('الى القوه', '^'),
      ('الي القوه', '^'),
      ('الجذر التكعيبي', 'cbrt'),
      ('الجذر التربيعي', 'sqrt'),
      ('جذر تكعيبي', 'cbrt'),
      ('جذر تربيعي', 'sqrt'),
      ('لوغاريتم طبيعي', 'ln'),
      ('جيب التمام', 'cos'),
      ('قسمه على', '/'),
      ('مقسوم على', '/'),
      ('الى اس', '^'),
      ('الي اس', '^'),
      ('قوس مفتوح', '('),
      ('قوس مغلق', ')'),
      ('في الميه', '%'),
      ('بالميه', '%'),
      ('ما ناتج', ''),
      ('ما هو', ''),
      ('لو سمحت', ''),
      ('من فضلك', ''),
      ('لوغاريتم', 'log'),
      ('يساوي', ''),
      ('احسب', ''),
      ('تربيع', '^2'),
      ('تكعيب', '^3'),
      ('عاملي', '!'),
      ('مضروب', '!'),
      ('القوه', '^'),
      ('زائد', '+'),
      ('زائدا', '+'),
      ('ناقص', '-'),
      ('ناقصا', '-'),
      ('قسمه', '/'),
      ('ضرب', '*'),
      ('جذر', 'sqrt'),
      ('جيب', 'sin'),
      ('جتا', 'cos'),
      ('قوه', '^'),
      ('فاصله', '.'),
      ('نقطه', '.'),
      ('ثمانيه', '8'),
      ('اثنين', '2'),
      ('اثنان', '2'),
      ('ثلاثه', '3'),
      ('اربعه', '4'),
      ('خمسه', '5'),
      ('سبعه', '7'),
      ('تسعه', '9'),
      ('عشره', '10'),
      ('صفر', '0'),
      ('واحد', '1'),
      ('ثلاث', '3'),
      ('اربع', '4'),
      ('خمس', '5'),
      ('سته', '6'),
      ('سبع', '7'),
      ('ثمان', '8'),
      ('تسع', '9'),
      ('عشر', '10'),
      ('اس', '^'),
      ('ظل', 'tan'),
      ('ظا', 'tan'),
      ('جا', 'sin'),
      ('في', '*'),
      ('على', '/'),
      ('باي', 'pi'),
      ('ست', '6'),
      ('كم', ''),
      ('هو', ''),
      ('ال', ''),
      ('ل', ''),
    ];
    final mapped = pairs
        .map((p) => _Pair(normalize(p.$1), p.$2))
        .toList()
      ..sort((a, b) => b.phrase.length.compareTo(a.phrase.length));
    return mapped;
  }();

  static int? _prefixLength(String text, String phrase) {
    if (_boundaryPrefix(text, phrase)) return phrase.length;
    if (text.startsWith('ال')) {
      final stripped = text.substring(2);
      if (_boundaryPrefix(stripped, phrase)) return phrase.length + 2;
    }
    return null;
  }

  static bool _boundaryPrefix(String text, String phrase) {
    if (!text.startsWith(phrase)) return false;
    if (text.length == phrase.length) return true;
    final next = text[phrase.length];
    if (_isLetterChar(phrase[phrase.length - 1]) && _isLetterChar(next)) {
      return false;
    }
    return true;
  }

  static String normalize(String spoken) {
    var text = spoken.toLowerCase();
    const dropping = {
      0x064B, 0x064C, 0x064D, 0x064E, 0x064F,
      0x0650, 0x0651, 0x0652, 0x0670, 0x0640,
    };
    text = String.fromCharCodes(
      text.runes.where((r) => !dropping.contains(r)),
    );
    const folds = {
      'أ': 'ا', 'إ': 'ا', 'آ': 'ا', 'ى': 'ي',
      'ؤ': 'و', 'ئ': 'ي', 'ة': 'ه',
    };
    for (final e in folds.entries) {
      text = text.replaceAll(e.key, e.value);
    }
    const digits = {
      '٠': '0', '١': '1', '٢': '2', '٣': '3', '٤': '4',
      '٥': '5', '٦': '6', '٧': '7', '٨': '8', '٩': '9',
      '۰': '0', '۱': '1', '۲': '2', '۳': '3', '۴': '4',
      '۵': '5', '۶': '6', '۷': '7', '۸': '8', '۹': '9',
      '×': '*', '÷': '/', '−': '-', '–': '-', '—': '-',
    };
    final mapped = StringBuffer();
    for (final r in text.runes) {
      final ch = String.fromCharCode(r);
      if (digits.containsKey(ch)) {
        mapped.write(digits[ch]);
      } else if (ch == 'π') {
        mapped.write(' pi ');
      } else if (ch == "'" || ch == '’') {
        continue;
      } else if ('؟?,;؛:"“”'.contains(ch)) {
        mapped.write(' ');
      } else {
        mapped.write(ch);
      }
    }
    return _replaceStandaloneX(mapped.toString());
  }

  static String _replaceStandaloneX(String text) {
    final characters = text.split('');
    for (var i = 0; i < characters.length; i++) {
      if (characters[i] != 'x' && characters[i] != 'X') continue;
      final previousIsLetter =
          i > 0 && _isLetterChar(characters[i - 1]);
      final nextIsLetter =
          i + 1 < characters.length && _isLetterChar(characters[i + 1]);
      if (!previousIsLetter && !nextIsLetter) {
        characters[i] = '*';
      }
    }
    return characters.join();
  }

  static String _tidy(String raw) {
    var text = raw.replaceAllMapped(
      RegExp(r'(\d)\s*\.\s*(\d)'),
      (m) => '${m[1]}.${m[2]}',
    );
    text = text.replaceAllMapped(
      RegExp(r'\s*([+*/^,%!\-])\s*'),
      (m) => m[1]!,
    );
    text = text.replaceAll(RegExp(r'\s+'), ' ');
    return text.trim();
  }

  static bool _hasMathValue(String expression) {
    if (expression.runes.any((r) => r >= 48 && r <= 57)) return true;
    return expression.contains('pi') || expression.contains('e');
  }

  static bool _containsArabic(String text) {
    return text.runes.any((r) => r >= 0x0600 && r <= 0x06FF);
  }

  static bool _isContinuation(String expression) {
    if (expression.isEmpty) return false;
    return '+-*/'.contains(expression[0]);
  }

  static bool _isDigitChar(String ch) {
    final c = ch.codeUnitAt(0);
    return c >= 48 && c <= 57;
  }

  static bool _isLetterChar(String ch) {
    final c = ch.codeUnitAt(0);
    return (c >= 97 && c <= 122) ||
        (c >= 65 && c <= 90) ||
        (c >= 0x0600 && c <= 0x06FF);
  }
}

class _Match {
  _Match(this.token, this.length);
  final String token;
  final int length;
}

class _Pair {
  _Pair(this.phrase, this.token);
  final String phrase;
  final String token;
}
