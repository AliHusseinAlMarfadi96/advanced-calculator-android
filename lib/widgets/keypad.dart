import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/app_settings.dart';
import '../models/calculator_view_model.dart';
import '../services/button_speaker.dart';

enum _KeyTone { digit, operation, function, clear, equals }

class _CalcKey {
  const _CalcKey({
    required this.id,
    required this.title,
    required this.labelKey,
    required this.speechKey,
    required this.tone,
    this.hintKey,
    this.token,
    this.special,
  });

  final String id;
  final String title;
  final String labelKey;
  final String? hintKey;
  final String speechKey;
  final _KeyTone tone;
  final String? token;
  final _Special? special;
}

enum _Special { clear, backspace, equals, sign }

class Keypad extends StatelessWidget {
  const Keypad({
    super.key,
    required this.model,
    required this.speaker,
    required this.settings,
  });

  final CalculatorViewModel model;
  final ButtonSpeaker speaker;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final keys = _keys();
    return Directionality(
      textDirection: TextDirection.ltr,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final spacing = 8.0;
          final cols = 4;
          final width = (constraints.maxWidth - spacing * (cols - 1)) / cols;
          final height = width.clamp(48.0, 64.0);
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final key in keys)
                SizedBox(
                  width: width,
                  height: height,
                  child: _keyButton(context, key),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _keyButton(BuildContext context, _CalcKey key) {
    final label = L10n.text(key.labelKey, settings.language);
    final speech = L10n.text(key.speechKey, settings.language);
    final hint =
        key.hintKey == null ? null : L10n.text(key.hintKey!, settings.language);
    return Semantics(
      button: true,
      label: label,
      hint: hint,
      child: Material(
        color: _background(key.tone),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            if (key.special == _Special.equals) {
              await model.equals();
              await _speakEqualsResult(buttonSpeech: speech);
            } else {
              await speaker.speak(
                speech,
                languageCode: settings.language.speechLocale,
                enabled: settings.keyboardSpeech,
                rate: settings.speechRate,
              );
              _perform(key);
            }
          },
          child: Center(
            child: Text(
              key.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _foreground(key.tone),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _speakEqualsResult({required String buttonSpeech}) async {
    final succeeded = model.failure == null && model.resultText.isNotEmpty;
    if (settings.speakResultAfterEquals && succeeded) {
      final sentence = L10n.text('voice.resultSpoken', settings.language)
          .replaceAll('%@', model.resultText);
      final phrase =
          settings.keyboardSpeech ? '$buttonSpeech. $sentence' : sentence;
      await speaker.speak(
        phrase,
        languageCode: settings.language.speechLocale,
        enabled: true,
        rate: settings.speechRate,
      );
    } else {
      await speaker.speak(
        buttonSpeech,
        languageCode: settings.language.speechLocale,
        enabled: settings.keyboardSpeech,
        rate: settings.speechRate,
      );
    }
  }

  void _perform(_CalcKey key) {
    switch (key.special) {
      case _Special.clear:
        model.clearDisplay();
      case _Special.backspace:
        model.backspace();
      case _Special.equals:
        model.equals();
      case _Special.sign:
        model.toggleSign();
      case null:
        if (key.token != null) model.input(key.token!);
    }
  }

  Color _background(_KeyTone tone) {
    switch (tone) {
      case _KeyTone.digit:
        return const Color(0xFF2B303A);
      case _KeyTone.function:
        return const Color(0xFF1C3D61);
      case _KeyTone.operation:
        return const Color(0xFFFF9E0A);
      case _KeyTone.clear:
        return const Color(0xFFEB4038);
      case _KeyTone.equals:
        return const Color(0xFF2EC761);
    }
  }

  Color _foreground(_KeyTone tone) {
    switch (tone) {
      case _KeyTone.operation:
      case _KeyTone.equals:
        return Colors.black;
      default:
        return Colors.white;
    }
  }

  List<_CalcKey> _keys() => [
        _fn('sin', 'sin', 'key.sin', 'speak.sin', 'sin('),
        _fn('cos', 'cos', 'key.cos', 'speak.cos', 'cos('),
        _fn('tan', 'tan', 'key.tan', 'speak.tan', 'tan('),
        _fn('sqrt', '√', 'key.sqrt', 'speak.sqrt', 'sqrt('),
        _fn('ln', 'ln', 'key.ln', 'speak.ln', 'ln('),
        _fn('log', 'log', 'key.log', 'speak.log', 'log('),
        _fn('sq', 'x²', 'key.square', 'speak.square', '^2', hint: 'key.square.hint'),
        _fn('pow', 'xʸ', 'key.power', 'speak.power', '^', hint: 'key.power.hint'),
        _fn('cbrt', '∛', 'key.cbrt', 'speak.cbrt', 'cbrt('),
        _fn('nroot', 'ⁿ√', 'key.nroot', 'speak.nroot', 'nroot(', hint: 'key.nroot.hint'),
        _fn('fact', 'n!', 'key.factorial', 'speak.factorial', '!', hint: 'key.factorial.hint'),
        _fn('pct', '%', 'key.percent', 'speak.percent', '%', hint: 'key.percent.hint'),
        _fn('pi', 'π', 'key.pi', 'speak.pi', 'pi'),
        _fn('e', 'e', 'key.e', 'speak.e', 'e'),
        _fn('open', '(', 'key.open', 'speak.open', '('),
        _fn('close', ')', 'key.close', 'speak.close', ')'),
        const _CalcKey(
          id: 'clear',
          title: 'C',
          labelKey: 'key.clear',
          hintKey: 'key.clear.hint',
          speechKey: 'speak.clear',
          tone: _KeyTone.clear,
          special: _Special.clear,
        ),
        const _CalcKey(
          id: 'del',
          title: '⌫',
          labelKey: 'key.backspace',
          hintKey: 'key.backspace.hint',
          speechKey: 'speak.backspace',
          tone: _KeyTone.function,
          special: _Special.backspace,
        ),
        const _CalcKey(
          id: 'sign',
          title: '±',
          labelKey: 'key.sign',
          hintKey: 'key.sign.hint',
          speechKey: 'speak.sign',
          tone: _KeyTone.function,
          special: _Special.sign,
        ),
        _op('div', '÷', 'speak.divide', 'speak.divide', '/'),
        _digit('7'),
        _digit('8'),
        _digit('9'),
        _op('mul', '×', 'speak.multiply', 'speak.multiply', '*'),
        _digit('4'),
        _digit('5'),
        _digit('6'),
        _op('sub', '−', 'speak.subtract', 'speak.subtract', '-'),
        _digit('1'),
        _digit('2'),
        _digit('3'),
        _op('add', '+', 'speak.add', 'speak.add', '+'),
        _digit('0'),
        const _CalcKey(
          id: 'decimal',
          title: '.',
          labelKey: 'key.decimal',
          speechKey: 'speak.decimal',
          tone: _KeyTone.digit,
          token: '.',
        ),
        const _CalcKey(
          id: 'comma',
          title: ',',
          labelKey: 'key.comma',
          hintKey: 'key.comma.hint',
          speechKey: 'speak.comma',
          tone: _KeyTone.function,
          token: ',',
        ),
        const _CalcKey(
          id: 'eq',
          title: '=',
          labelKey: 'key.equals',
          hintKey: 'key.equals.hint',
          speechKey: 'speak.equals',
          tone: _KeyTone.equals,
          special: _Special.equals,
        ),
      ];

  _CalcKey _digit(String value) => _CalcKey(
        id: 'd$value',
        title: value,
        labelKey: 'key.digit.$value',
        speechKey: 'speak.digit.$value',
        tone: _KeyTone.digit,
        token: value,
      );

  _CalcKey _op(
    String id,
    String title,
    String label,
    String speech,
    String token,
  ) =>
      _CalcKey(
        id: id,
        title: title,
        labelKey: label,
        speechKey: speech,
        tone: _KeyTone.operation,
        token: token,
      );

  _CalcKey _fn(
    String id,
    String title,
    String label,
    String speech,
    String token, {
    String? hint,
  }) =>
      _CalcKey(
        id: id,
        title: title,
        labelKey: label,
        hintKey: hint,
        speechKey: speech,
        tone: _KeyTone.function,
        token: token,
      );
}
