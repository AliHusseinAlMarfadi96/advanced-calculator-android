import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

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
    this.sortOrder,
    this.minHeight = 56,
  });

  final String id;
  final String title;
  final String labelKey;
  final String? hintKey;
  final String speechKey;
  final _KeyTone tone;
  final String? token;
  final _Special? special;
  final double? sortOrder;
  final double minHeight;
}

enum _Special { clear, backspace, equals, sign }

/// Classic phone-calculator keypad.
///
/// Digits read left-to-right, 7→1 top-to-bottom. Operators sit on the RIGHT.
/// Both + (tall, two rows) and = (full-width bottom bar, min 64) are large
/// easy targets. The whole keypad is forced LTR so Arabic RTL chrome never
/// reverses digit order or TalkBack swipe order. No Wrap.
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

  /// Deterministic TalkBack / layout-test order.
  /// Digits first within each row, ops on the right, = last (large bar).
  static List<String> arithmeticKeyIdsInTalkBackOrder() => const [
        'clear',
        'del',
        'sign',
        'div',
        'd7',
        'd8',
        'd9',
        'mul',
        'd4',
        'd5',
        'd6',
        'sub',
        'd1',
        'd2',
        'd3',
        'd0',
        'decimal',
        'comma',
        'add',
        'eq',
      ];

  @override
  Widget build(BuildContext context) {
    // Force LTR for the keypad only. Parent RTL Directionality must NOT flip
    // digit rows, scientific rows, or TalkBack swipe order.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final spacing = 8.0;
          final cell = ((constraints.maxWidth - spacing * 3) / 4)
              .clamp(52.0, 76.0);
          final rowHeight = cell < 56 ? 56.0 : cell;
          final equalsHeight =
              rowHeight < 64 ? 64.0 : (rowHeight > 72 ? 72.0 : rowHeight);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final row in _scientificRows()) ...[
                _buildRow(context, row, height: rowHeight, spacing: spacing),
                SizedBox(height: spacing),
              ],
              _buildRow(
                context,
                [_clear(), _backspace(), _sign(), _divide()],
                height: rowHeight,
                spacing: spacing,
              ),
              SizedBox(height: spacing),
              _buildRow(
                context,
                [_digit('7'), _digit('8'), _digit('9'), _multiply()],
                height: rowHeight,
                spacing: spacing,
              ),
              SizedBox(height: spacing),
              _buildRow(
                context,
                [_digit('4'), _digit('5'), _digit('6'), _subtract()],
                height: rowHeight,
                spacing: spacing,
              ),
              SizedBox(height: spacing),
              // Bottom digit block: 1 2 3 / 0 . , with LARGE + spanning
              // two rows on the RIGHT (classic phone calculator).
              SizedBox(
                height: rowHeight * 2 + spacing,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  textDirection: TextDirection.ltr,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        children: [
                          Expanded(
                            child: _buildRow(
                              context,
                              [_digit('1'), _digit('2'), _digit('3')],
                              height: rowHeight,
                              spacing: spacing,
                            ),
                          ),
                          SizedBox(height: spacing),
                          Expanded(
                            child: _buildRow(
                              context,
                              [
                                _digit('0'),
                                _decimal(),
                                _comma(minHeight: rowHeight),
                              ],
                              height: rowHeight,
                              spacing: spacing,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: spacing),
                    Expanded(
                      flex: 1,
                      child: _keyButton(
                        context,
                        _add(minHeight: rowHeight * 2 + spacing),
                        expand: true,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: spacing),
              // Full-width equals bar — large, high-contrast, easy to reach.
              SizedBox(
                height: equalsHeight,
                width: double.infinity,
                child: _keyButton(
                  context,
                  _equals(minHeight: equalsHeight),
                  expand: true,
                  fullWidthEquals: true,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRow(
    BuildContext context,
    List<_CalcKey> keys, {
    required double height,
    required double spacing,
  }) {
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        textDirection: TextDirection.ltr,
        children: [
          for (var i = 0; i < keys.length; i++) ...[
            if (i > 0) SizedBox(width: spacing),
            Expanded(
              flex: 1,
              child: _keyButton(context, keys[i], expand: true),
            ),
          ],
        ],
      ),
    );
  }

  Widget _keyButton(
    BuildContext context,
    _CalcKey key, {
    bool expand = false,
    bool fullWidthEquals = false,
  }) {
    final label = L10n.text(key.labelKey, settings.language);
    final speech = L10n.text(key.speechKey, settings.language);
    final hint =
        key.hintKey == null ? null : L10n.text(key.hintKey!, settings.language);
    final isEquals = key.id == 'eq';
    final isAdd = key.id == 'add';
    final button = Semantics(
      button: true,
      // Explicit Arabic/English label; equals must announce يساوي.
      label: label,
      hint: hint,
      sortKey: key.sortOrder == null
          ? null
          : OrdinalSortKey(key.sortOrder!, name: key.id),
      child: Material(
        color: _background(key.tone),
        borderRadius: BorderRadius.circular(fullWidthEquals ? 18 : 16),
        elevation: isEquals || isAdd ? 3 : 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(fullWidthEquals ? 18 : 16),
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
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: key.minHeight,
              minWidth: fullWidthEquals ? double.infinity : 0,
            ),
            child: Center(
              child: Text(
                key.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: isEquals || isAdd ? 32 : 18,
                  fontWeight: FontWeight.w800,
                  color: _foreground(key.tone),
                  letterSpacing: isEquals ? 2 : 0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (expand) return button;
    return SizedBox(height: key.minHeight, child: button);
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
        // High-contrast green for the large equals bar.
        return const Color(0xFF1DB954);
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

  List<List<_CalcKey>> _scientificRows() => [
        [
          _fn('sin', 'sin', 'key.sin', 'speak.sin', 'sin(', order: 1),
          _fn('cos', 'cos', 'key.cos', 'speak.cos', 'cos(', order: 2),
          _fn('tan', 'tan', 'key.tan', 'speak.tan', 'tan(', order: 3),
          _fn('sqrt', '√', 'key.sqrt', 'speak.sqrt', 'sqrt(', order: 4),
        ],
        [
          _fn('ln', 'ln', 'key.ln', 'speak.ln', 'ln(', order: 5),
          _fn('log', 'log', 'key.log', 'speak.log', 'log(', order: 6),
          _fn('sq', 'x²', 'key.square', 'speak.square', '^2',
              hint: 'key.square.hint', order: 7),
          _fn('pow', 'xʸ', 'key.power', 'speak.power', '^',
              hint: 'key.power.hint', order: 8),
        ],
        [
          _fn('cbrt', '∛', 'key.cbrt', 'speak.cbrt', 'cbrt(', order: 9),
          _fn('nroot', 'ⁿ√', 'key.nroot', 'speak.nroot', 'nroot(',
              hint: 'key.nroot.hint', order: 10),
          _fn('fact', 'n!', 'key.factorial', 'speak.factorial', '!',
              hint: 'key.factorial.hint', order: 11),
          _fn('pct', '%', 'key.percent', 'speak.percent', '%',
              hint: 'key.percent.hint', order: 12),
        ],
        [
          _fn('pi', 'π', 'key.pi', 'speak.pi', 'pi', order: 13),
          _fn('e', 'e', 'key.e', 'speak.e', 'e', order: 14),
          _fn('open', '(', 'key.open', 'speak.open', '(', order: 15),
          _fn('close', ')', 'key.close', 'speak.close', ')', order: 16),
        ],
      ];

  _CalcKey _clear() => const _CalcKey(
        id: 'clear',
        title: 'C',
        labelKey: 'key.clear',
        hintKey: 'key.clear.hint',
        speechKey: 'speak.clear',
        tone: _KeyTone.clear,
        special: _Special.clear,
        sortOrder: 20,
        minHeight: 56,
      );

  _CalcKey _backspace() => const _CalcKey(
        id: 'del',
        title: '⌫',
        labelKey: 'key.backspace',
        hintKey: 'key.backspace.hint',
        speechKey: 'speak.backspace',
        tone: _KeyTone.function,
        special: _Special.backspace,
        sortOrder: 21,
        minHeight: 56,
      );

  _CalcKey _sign() => const _CalcKey(
        id: 'sign',
        title: '±',
        labelKey: 'key.sign',
        hintKey: 'key.sign.hint',
        speechKey: 'speak.sign',
        tone: _KeyTone.function,
        special: _Special.sign,
        sortOrder: 22,
        minHeight: 56,
      );

  _CalcKey _divide() => _op('div', '÷', 'speak.divide', 'speak.divide', '/',
      order: 23);
  _CalcKey _multiply() =>
      _op('mul', '×', 'speak.multiply', 'speak.multiply', '*', order: 33);
  _CalcKey _subtract() =>
      _op('sub', '−', 'speak.subtract', 'speak.subtract', '-', order: 43);
  _CalcKey _add({required double minHeight}) => _op(
        'add',
        '+',
        'speak.add',
        'speak.add',
        '+',
        order: 59,
        minHeight: minHeight,
      );

  _CalcKey _digit(String value) {
    final order = switch (value) {
      '7' => 30.0,
      '8' => 31.0,
      '9' => 32.0,
      '4' => 40.0,
      '5' => 41.0,
      '6' => 42.0,
      '1' => 50.0,
      '2' => 51.0,
      '3' => 52.0,
      '0' => 53.0,
      _ => 54.0,
    };
    return _CalcKey(
      id: 'd$value',
      title: value,
      labelKey: 'key.digit.$value',
      speechKey: 'speak.digit.$value',
      tone: _KeyTone.digit,
      token: value,
      sortOrder: order,
      minHeight: 56,
    );
  }

  _CalcKey _decimal() => const _CalcKey(
        id: 'decimal',
        title: '.',
        labelKey: 'key.decimal',
        speechKey: 'speak.decimal',
        tone: _KeyTone.digit,
        token: '.',
        sortOrder: 54,
        minHeight: 56,
      );

  _CalcKey _comma({double minHeight = 56}) => _CalcKey(
        id: 'comma',
        title: ',',
        labelKey: 'key.comma',
        hintKey: 'key.comma.hint',
        speechKey: 'speak.comma',
        tone: _KeyTone.function,
        token: ',',
        sortOrder: 55,
        minHeight: minHeight,
      );

  _CalcKey _equals({required double minHeight}) => _CalcKey(
        id: 'eq',
        title: '=',
        labelKey: 'key.equals', // يساوي
        hintKey: 'key.equals.hint',
        speechKey: 'speak.equals',
        tone: _KeyTone.equals,
        special: _Special.equals,
        sortOrder: 60,
        minHeight: minHeight < 64 ? 64 : minHeight,
      );

  _CalcKey _op(
    String id,
    String title,
    String label,
    String speech,
    String token, {
    double? order,
    double minHeight = 56,
  }) =>
      _CalcKey(
        id: id,
        title: title,
        labelKey: label,
        speechKey: speech,
        tone: _KeyTone.operation,
        token: token,
        sortOrder: order,
        minHeight: minHeight,
      );

  _CalcKey _fn(
    String id,
    String title,
    String label,
    String speech,
    String token, {
    String? hint,
    double? order,
  }) =>
      _CalcKey(
        id: id,
        title: title,
        labelKey: label,
        hintKey: hint,
        speechKey: speech,
        tone: _KeyTone.function,
        token: token,
        sortOrder: order,
        minHeight: 56,
      );
}
