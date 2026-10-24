import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/theme/theme_controller.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.load();

  if (config.firebaseEnabled) {
    if (DefaultFirebaseOptions.isPlaceholder) {
      runApp(const _FirebaseConfigError());
      return;
    }
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  if (config.supabaseEnabled) {
    try {
      await Supabase.initialize(
        url: config.supabaseUrl,
        publishableKey: config.supabaseAnonKey,
      );
    } catch (e) {
      debugPrint('[admin] Supabase initialization failed: $e');
    }
  }

  final preferences = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        initialThemeModeProvider.overrideWithValue(
          themeModeFromPreference(preferences.getString('theme_mode')),
        ),
      ],
      child: const PalengkeGoApp(),
    ),
  );
}

class _FirebaseConfigError extends StatelessWidget {
  const _FirebaseConfigError();

  @override
  Widget build(BuildContext context) => const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Firebase mode requires real configuration.\n\n'
                'Run `flutterfire configure` in this project to generate '
                'lib/firebase_options.dart, then rebuild with '
                '--dart-define=FIREBASE_ENABLED=true.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
}
