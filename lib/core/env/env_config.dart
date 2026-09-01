/// Reads build-time config injected via `--dart-define-from-file=env.json`.
///
/// Run the app with:
///   flutter run --dart-define-from-file=env.json
///
/// Fill env.json with your real Supabase project values before running.
/// Never commit real keys — env.json should stay out of version control
/// (the anon key is safe client-side by design, but keep the habit anyway).
class EnvConfig {
  EnvConfig._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
