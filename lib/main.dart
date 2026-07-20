import 'package:flutter/material.dart';

import 'dependency_injection.dart';
import 'screens/funds_list_screen.dart';
import 'services/supabase_service.dart';

/// App entry point. Order matters:
///  1. ensureInitialized — required before any async work pre-runApp.
///  2. SupabaseService.init — a no-op today, real client init in iteration 2.
///  3. DI.init — builds repositories and controllers exactly once.
///  4. runApp — by now every screen can safely read DI.* fields.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.init();
  DI.init();
  runApp(const MoneyTrackApp());
}

/// Root widget: theme + home route. Deliberately thin — all state lives
/// in controllers, all UI in screens.
class MoneyTrackApp extends StatelessWidget {
  const MoneyTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Binance-style light theme: white surfaces, black text, a gold accent,
    // and green/red for gains/losses (the pill colours live in the screens).
    const gold = Color(0xFFF0B90B);
    return MaterialApp(
      title: 'MoneyTrack',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: gold,
          brightness: Brightness.light,
        ).copyWith(surface: Colors.white),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        cardTheme: const CardThemeData(elevation: 1),
      ),
      home: const FundsListScreen(),
    );
  }
}
