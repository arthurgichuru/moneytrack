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
    return MaterialApp(
      title: 'MoneyTrack',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00695C)),
        useMaterial3: true,
        cardTheme: const CardThemeData(elevation: 1),
      ),
      home: const FundsListScreen(),
    );
  }
}
