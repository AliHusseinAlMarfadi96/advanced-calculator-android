import 'package:advanced_calculator/models/app_settings.dart';
import 'package:advanced_calculator/models/calculator_view_model.dart';
import 'package:advanced_calculator/models/history_store.dart';
import 'package:advanced_calculator/services/button_speaker.dart';
import 'package:advanced_calculator/widgets/keypad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('digit 7 appears before digit 1 and plus is in arithmetic order', () {
    final ids = Keypad.arithmeticKeyIdsInTalkBackOrder();
    expect(ids.indexOf('d7'), lessThan(ids.indexOf('d1')));
    expect(ids.indexOf('d7'), lessThan(ids.indexOf('d4')));
    expect(ids.indexOf('d4'), lessThan(ids.indexOf('d1')));
    expect(ids.indexOf('d1'), lessThan(ids.indexOf('d0')));
    expect(ids, contains('add'));
    expect(ids.last, 'add');
    // Classic right-column ops after their digit rows.
    expect(ids.indexOf('div'), lessThan(ids.indexOf('d7')));
    expect(ids.indexOf('mul'), greaterThan(ids.indexOf('d9')));
    expect(ids.indexOf('sub'), greaterThan(ids.indexOf('d6')));
    expect(ids.indexOf('add'), greaterThan(ids.indexOf('d0')));
  });

  testWidgets('plus key is large and labeled for TalkBack (زائد)', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings();
    await settings.load();
    final history = HistoryStore();
    await history.load();
    final model = CalculatorViewModel()..attach(history);
    final speaker = ButtonSpeaker();

    // Match phone-ish viewport; keypad scrolls like the real calculator screen.
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        // Parent RTL must not flip keypad digit order.
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Keypad(model: model, speaker: speaker, settings: settings),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final plusText = find.text('+');
    expect(plusText, findsOneWidget);

    // Hit target is the Material around +, which spans two digit rows.
    final plusMaterial = find.ancestor(
      of: plusText,
      matching: find.byType(Material),
    ).first;
    final plusSize = tester.getSize(plusMaterial);
    expect(plusSize.height, greaterThanOrEqualTo(112));

    // Semantics: Arabic spoken label "زائد".
    final semantics = tester.getSemantics(plusText);
    expect(semantics.label, contains('زائد'));

    // Digit 7 is above digit 1 visually (not upside-down).
    final seven = tester.getTopLeft(find.text('7'));
    final one = tester.getTopLeft(find.text('1'));
    expect(seven.dy, lessThan(one.dy));

    // Keypad forces LTR: 7 is left of 9 even under RTL parent.
    final nine = tester.getTopLeft(find.text('9'));
    expect(seven.dx, lessThan(nine.dx));
  });
}
