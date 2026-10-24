import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Compile-time backend switch, mirroring the main app's pattern.
///
///   flutter run                     → demo mode (seeded data, local login)
///   flutter run --dart-define=FIREBASE_ENABLED=true
///                                  → live Firebase Auth/Firestore/callables and Supabase announcements
class AppConfig {
  const AppConfig({
    this.firebaseEnabled = false,
    this.supabaseUrl = '',
    this.supabaseAnonKey = '',
  });

  final bool firebaseEnabled;
  final String supabaseUrl;
  final String supabaseAnonKey;

  bool get supabaseEnabled =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  factory AppConfig.load() {
    const rawUrl = String.fromEnvironment('SUPABASE_URL');
    const rawAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    final firebaseEnabled = const bool.fromEnvironment(
      'FIREBASE_ENABLED',
      defaultValue: false,
    );
    final hasBackend = firebaseEnabled || rawUrl.isNotEmpty;

    final supabaseUrl = rawUrl.isNotEmpty
        ? rawUrl
        : (hasBackend ? 'https://jvpplxlcucuzmbtbmtah.supabase.co' : '');

    final supabaseAnonKey = rawAnonKey.isNotEmpty
        ? rawAnonKey
        : (hasBackend
            ? 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp2cHBseGxjdWN1em1idGJtdGFoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODcxMjIyNTUsImV4cCI6MjEwMjY5ODI1NX0.FrYvHhZjARj-XZNC1ZgxfVa1ixJQsuMTkRRMTxCamw0'
            : '');

    return AppConfig(
      firebaseEnabled: firebaseEnabled,
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey,
    );
  }
}

final firebaseEnabledProvider = Provider<bool>(
  (ref) => ref.watch(appConfigProvider).firebaseEnabled,
);

final supabaseEnabledProvider = Provider<bool>(
  (ref) => ref.watch(appConfigProvider).supabaseEnabled,
);

final appConfigProvider = Provider<AppConfig>((ref) => AppConfig.load());
