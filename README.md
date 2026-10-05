# الحاسبة المتقدمة (Advanced Calculator) — Android

Flutter port of the iOS Advanced Calculator. Application id: `com.alimarfadi.advancedcalculator`.

## Features

- Basic and scientific operations (power, square, sqrt, cbrt, nroot, sin/cos/tan in degrees, ln, log10, factorial 0..170, pi, e, parentheses, percent, sign toggle).
- On-device expression evaluation with divide-by-zero and domain errors.
- Persisted history (tap a row to reload). **C** clears the display only; **Clear History** confirms then deletes history.
- Keypad speech via TTS (`ar-SA` / `en-US`) when enabled.
- Voice assistant with Cancel, Pause/Resume, Save Calculation, Exit; Arabic and English spoken math; exact not-understood phrase then retry.
- Settings: Arabic/English (default Arabic), keyboard speech, assistant speech, start beep/vibration, speech rate, verbose memory, speak result after equals.
- Credits line: `تم تطوير هذا التطبيق بواسطة علي حسين المرفدي`.
- TalkBack-first: labeled buttons, live regions, RTL chrome with LTR expression/keypad.

## Build

```bash
export PATH=/home/box/sdks/flutter/bin:$PATH
export JAVA_HOME=/home/box/sdks/jdk-17
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

Release APK is signed with the local debug keystore for sideload distribution.

## Tests

Unit tests cover the expression evaluator and the speech math parser (Arabic and English phrases).

## v1.0.2

- Stronger classic LTR keypad: digits 7→1, ops on the right; tall +; full-width high-contrast = bar (min 64) with TalkBack label يساوي.
- No Wrap; scientific rows stay LTR under Arabic RTL chrome; widget test covers key order and sizes.
- Voice: speech_to_text init with Android intentLookup/noBluetooth/alwaysUseStop; listenFor/pauseFor; never onDevice; dictation mode; auto-retry + locale rotation; SpeechRecognizer Intent fallback when continuous listen fails.

## v1.0.1

- Classic LTR calculator keypad (Column/Rows, not Wrap): 7-8-9 … 0 with ÷×−+ on the right; large + spanning two rows for TalkBack.
- Voice assistant: network speech fallback, ar_SA/ar/en_US locale resolution, clearer Arabic status when Google speech services are missing, fixed onError/onStatus pause race.

## Download

Permanent public APK:

https://github.com/AliHusseinAlMarfadi96/advanced-calculator-android/releases/download/v1.0.2/AdvancedCalculator.apk
