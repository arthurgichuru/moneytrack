/// Placeholder for iteration 2.
///
/// When we wire up Supabase, this class becomes the single owner of the
/// Supabase client: it reads SUPABASE_URL / SUPABASE_ANON_KEY from the
/// environment (.env), calls `Supabase.initialize(...)` once at startup,
/// and exposes the client to the Supabase* repository implementations.
///
/// Keeping it as a separate service (instead of initialising Supabase in
/// main.dart) means repositories can be unit-tested with a mock service.
class SupabaseService {
  /// Iteration 2 will look roughly like:
  ///
  /// ```dart
  /// static Future<void> init() async {
  ///   await Supabase.initialize(
  ///     url: const String.fromEnvironment('SUPABASE_URL'),
  ///     anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
  ///   );
  /// }
  ///
  /// SupabaseClient get client => Supabase.instance.client;
  /// ```
  static Future<void> init() async {
    // No-op in iteration 1 — dummy repositories need no backend.
  }
}
