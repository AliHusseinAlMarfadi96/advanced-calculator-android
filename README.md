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
