import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/app_settings.dart';
import 'models/history_store.dart';
import 'screens/calculator_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  final settings = AppSettings();
  final history = HistoryStore();
  await Future.wait([settings.load(), history.load()]);
  runApp(AdvancedCalculatorApp(settings: settings, history: history));
}

class AdvancedCalculatorApp extends StatelessWidget {
  const AdvancedCalculatorApp({
    super.key,
    required this.settings,
    required this.history,
  });

  final AppSettings settings;
  final HistoryStore history;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final darkScheme = ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF9E0A),
          brightness: Brightness.dark,
        );
        final lightScheme = ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF9E0A),
          brightness: Brightness.light,
        );
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'الحاسبة المتقدمة',
          themeMode: ThemeMode.system,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: lightScheme,
            visualDensity: VisualDensity.adaptivePlatformDensity,
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: darkScheme,
            scaffoldBackgroundColor: const Color(0xFF0D0E12),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF0D0E12),
              foregroundColor: Colors.white,
            ),
            visualDensity: VisualDensity.adaptivePlatformDensity,
          ),
          locale: Locale(settings.language.localeIdentifier),
          builder: (context, child) {
            return Directionality(
              textDirection: settings.language.isRTL
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: CalculatorScreen(settings: settings, history: history),
        );
      },
    );
  }
}
