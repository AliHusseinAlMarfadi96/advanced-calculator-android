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

  test('digit 7 before 1; ops after digit rows; equals last', () {
    final ids = Keypad.arithmeticKeyIdsInTalkBackOrder();
    expect(ids.indexOf('d7'), lessThan(ids.indexOf('d1')));
    expect(ids.indexOf('d7'), lessThan(ids.indexOf('d4')));
    expect(ids.indexOf('d4'), lessThan(ids.indexOf('d1')));
    expect(ids.indexOf('d1'), lessThan(ids.indexOf('d0')));
    expect(ids, contains('add'));
    expect(ids, contains('eq'));
    expect(ids.last, 'eq');
    expect(ids.indexOf('div'), lessThan(ids.indexOf('d7')));
    expect(ids.indexOf('mul'), greaterThan(ids.indexOf('d9')));
    expect(ids.indexOf('sub'), greaterThan(ids.indexOf('d6')));
    expect(ids.indexOf('add'), greaterThan(ids.indexOf('d0')));
    expect(ids.indexOf('eq'), greaterThan(ids.indexOf('add')));
    // Classic left-to-right digits within a row.
    expect(ids.indexOf('d7'), lessThan(ids.indexOf('d8')));
    expect(ids.indexOf('d8'), lessThan(ids.indexOf('d9')));
    expect(ids.indexOf('d1'), lessThan(ids.indexOf('d2')));
    expect(ids.indexOf('d2'), lessThan(ids.indexOf('d3')));
  });

  testWidgets('LTR keypad under RTL parent: 7 above 1, 7 left of 9; large + and =',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings();
    await settings.load();
    final history = HistoryStore();
    await history.load();
    final model = CalculatorViewModel()..attach(history);
    final speaker = ButtonSpeaker();

    await tester.binding.setSurfaceSize(const Size(400, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
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

    // Digit order: 7 above 1 (not upside-down).
    final seven = tester.getTopLeft(find.text('7'));
    final one = tester.getTopLeft(find.text('1'));
    expect(seven.dy, lessThan(one.dy));

    // LTR forced: 7 left of 9 even under RTL parent.
    final nine = tester.getTopLeft(find.text('9'));
    expect(seven.dx, lessThan(nine.dx));

    // Scientific row also LTR (sin left of cos).
    final sinPos = tester.getTopLeft(find.text('sin'));
    final cosPos = tester.getTopLeft(find.text('cos'));
    expect(sinPos.dx, lessThan(cosPos.dx));

    // Plus is tall (spans two digit rows).
    final plusText = find.text('+');
    expect(plusText, findsOneWidget);
    final plusMaterial = find
        .ancestor(of: plusText, matching: find.byType(Material))
        .first;
    final plusSize = tester.getSize(plusMaterial);
    expect(plusSize.height, greaterThanOrEqualTo(112));

    // Semantics: Arabic زائد for +.
    expect(tester.getSemantics(plusText).label, contains('زائد'));

    // Equals is a large full-width bottom bar (min height 64).
    final eqText = find.text('=');
    expect(eqText, findsOneWidget);
    final eqMaterial =
        find.ancestor(of: eqText, matching: find.byType(Material)).first;
    final eqSize = tester.getSize(eqMaterial);
    expect(eqSize.height, greaterThanOrEqualTo(64));
    expect(eqSize.width, greaterThanOrEqualTo(300));

    // Semantics label يساوي for TalkBack.
    expect(tester.getSemantics(eqText).label, contains('يساوي'));

    // Ops column on the right: × is right of 9.
    final mul = tester.getTopLeft(find.text('×'));
    expect(mul.dx, greaterThan(nine.dx));

    // Equals sits below the digit block.
    final zero = tester.getTopLeft(find.text('0'));
    final eqTop = tester.getTopLeft(eqText);
    expect(eqTop.dy, greaterThan(zero.dy));
  });
}
