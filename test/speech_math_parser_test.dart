import 'package:advanced_calculator/core/speech_math_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SpeechMathParser Arabic', () {
    test('5 في 5 = 25', () {
      final result = SpeechMathParser.interpret('5 في 5');
      expect(result, isA<SpeechSuccess>());
      final success = result as SpeechSuccess;
      expect(success.result, 25);
    });

    test('5 أس 5 = 3125', () {
      final result = SpeechMathParser.interpret('5 أس 5');
      expect(result, isA<SpeechSuccess>());
      final success = result as SpeechSuccess;
      expect(success.result, 3125);
    });

    test('جذر 16 = 4', () {
      final result = SpeechMathParser.interpret('جذر 16');
      expect(result, isA<SpeechSuccess>());
      final success = result as SpeechSuccess;
      expect(success.result, 4);
    });

    test('خمسة زائد ثلاثة', () {
      final result = SpeechMathParser.interpret('خمسة زائد ثلاثة');
      expect(result, isA<SpeechSuccess>());
      expect((result as SpeechSuccess).result, 8);
    });

    test('قسمة على', () {
      final result = SpeechMathParser.interpret('عشرة قسمة على اثنين');
      expect(result, isA<SpeechSuccess>());
      expect((result as SpeechSuccess).result, 5);
    });
  });

  group('SpeechMathParser English', () {
    test('5 times 5 = 25', () {
      final result = SpeechMathParser.interpret('5 times 5');
      expect(result, isA<SpeechSuccess>());
      expect((result as SpeechSuccess).result, 25);
    });

    test('5 to the power of 5 = 3125', () {
      final result = SpeechMathParser.interpret('5 to the power of 5');
      expect(result, isA<SpeechSuccess>());
      expect((result as SpeechSuccess).result, 3125);
    });

    test('square root of 16', () {
      final result = SpeechMathParser.interpret('square root of 16');
      expect(result, isA<SpeechSuccess>());
      expect((result as SpeechSuccess).result, 4);
    });

    test('2x5 multiplication shorthand', () {
      final result = SpeechMathParser.interpret('2x5');
      expect(result, isA<SpeechSuccess>());
      expect((result as SpeechSuccess).result, 10);
    });
  });

  group('SpeechMathParser continuation and rejection', () {
    test('leading operator continues from memory', () {
      final result =
          SpeechMathParser.interpret('+ 5', continuingFrom: 10);
      expect(result, isA<SpeechSuccess>());
      expect((result as SpeechSuccess).result, 15);
    });

    test('unknown words are not understood', () {
      final result = SpeechMathParser.interpret('hello world');
      expect(result, isA<SpeechNotUnderstood>());
    });
  });
}
