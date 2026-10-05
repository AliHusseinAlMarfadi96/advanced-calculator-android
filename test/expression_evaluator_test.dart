import 'package:advanced_calculator/core/expression_evaluator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  double eval(String expression) => ExpressionEvaluator.evaluate(expression);

  group('ExpressionEvaluator basics', () {
    test('addition and multiplication precedence', () {
      expect(eval('2+3*4'), 14);
      expect(eval('(2+3)*4'), 20);
    });

    test('division and subtract', () {
      expect(eval('10-4/2'), 8);
      expect(eval('100/4'), 25);
    });

    test('power right-associative', () {
      expect(eval('2^3'), 8);
      expect(eval('2^3^2'), 512);
    });

    test('percent and factorial', () {
      expect(eval('50%'), 0.5);
      expect(eval('5!'), 120);
      expect(eval('0!'), 1);
    });

    test('roots and square', () {
      expect(eval('sqrt(16)'), 4);
      expect(eval('cbrt(8)'), closeTo(2, 1e-9));
      expect(eval('nroot(3, 8)'), closeTo(2, 1e-9));
      expect(eval('square(5)'), 25);
    });

    test('trig in degrees', () {
      expect(eval('sin(90)'), closeTo(1, 1e-9));
      expect(eval('cos(0)'), closeTo(1, 1e-9));
      expect(eval('tan(45)'), closeTo(1, 1e-9));
    });

    test('logs and constants', () {
      expect(eval('ln(e)'), closeTo(1, 1e-9));
      expect(eval('log(100)'), closeTo(2, 1e-9));
      expect(eval('pi'), closeTo(3.141592653589793, 1e-12));
    });

    test('format integers cleanly', () {
      expect(ExpressionEvaluator.format(25), '25');
      expect(ExpressionEvaluator.format(0), '0');
    });
  });

  group('ExpressionEvaluator errors', () {
    test('divide by zero', () {
      expect(
        () => eval('1/0'),
        throwsA(
          isA<EvalException>().having(
            (e) => e.failure,
            'failure',
            EvalFailure.divideByZero,
          ),
        ),
      );
    });

    test('domain errors', () {
      expect(
        () => eval('sqrt(-1)'),
        throwsA(
          isA<EvalException>().having(
            (e) => e.failure,
            'failure',
            EvalFailure.domain,
          ),
        ),
      );
      expect(
        () => eval('ln(0)'),
        throwsA(
          isA<EvalException>().having(
            (e) => e.failure,
            'failure',
            EvalFailure.domain,
          ),
        ),
      );
      expect(
        () => eval('171!'),
        throwsA(
          isA<EvalException>().having(
            (e) => e.failure,
            'failure',
            EvalFailure.domain,
          ),
        ),
      );
    });

    test('syntax errors', () {
      expect(
        () => eval('2+'),
        throwsA(
          isA<EvalException>().having(
            (e) => e.failure,
            'failure',
            EvalFailure.syntax,
          ),
        ),
      );
    });
  });
}
