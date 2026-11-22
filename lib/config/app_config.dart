/// Build-time configuration.
///
/// The defaults keep `flutter run` working with no extra setup. Override them
/// per build so the keys are not baked into a shared binary:
///
///   flutter run --dart-define=SUPABASE_URL=https://xxx.supabase.co \
///                --dart-define=SUPABASE_ANON_KEY=sb_publishable_xxx
class AppConfig {
  AppConfig._();

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://weeoerkjdiqpxgzaofgz.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_JPsr9LAzNblj5OIGwxumEw_wPL3VwzF',
  );

  /// Where links in auth emails return to. It has to be listed under Redirect
  /// URLs in the Supabase dashboard, and its scheme registered in the Android
  /// manifest and the iOS Info.plist.
  static const String authRedirectUrl = 'io.supabase.unifriend://auth-callback';
}
