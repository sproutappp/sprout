import 'package:supabase_flutter/supabase_flutter.dart';

import '../env/env_config.dart';

/// Thin wrapper around the Supabase client.
///
/// Kept as a single choke point so that if we ever swap backends
/// (e.g. move storage to raw S3/R2, or move off Supabase entirely),
/// the rest of the app only ever talks to `SupabaseService` /
/// `AuthService` / `CirclesRepository` / `MemoriesRepository` —
/// never to the Supabase SDK directly.
class SupabaseService {
  SupabaseService._();

  static Future<void> initialize() async {
    if (!EnvConfig.isConfigured) {
      // Fail loud in debug rather than silently running with a broken
      // backend — makes the missing env.json obvious immediately.
      throw StateError(
        'Supabase is not configured. Fill env.json with SUPABASE_URL and '
        'SUPABASE_ANON_KEY, then run with '
        '`flutter run --dart-define-from-file=env.json`.',
      );
    }

    await Supabase.initialize(
      url: EnvConfig.supabaseUrl,
      anonKey: EnvConfig.supabaseAnonKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
