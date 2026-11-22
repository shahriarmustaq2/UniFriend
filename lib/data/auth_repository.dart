import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

class AuthRepository {
  AuthRepository(this.client);

  final SupabaseClient client;

  /// On the web the browser returns to the app's own page. Elsewhere the email
  /// link opens the app through its URL scheme.
  static String? get _redirectUrl => kIsWeb ? null : AppConfig.authRedirectUrl;

  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  User? get currentUser => client.auth.currentUser;

  Future<void> signIn({required String email, required String password}) {
    return client.auth.signInWithPassword(email: email, password: password);
  }

  /// Returns `true` when a session was created immediately, `false` when the
  /// project requires the student to confirm their email address first.
  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    await client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
      emailRedirectTo: _redirectUrl,
    );
    return client.auth.currentSession != null;
  }

  /// Emails a link. Opening it signs the student in and fires a
  /// `passwordRecovery` auth event, which sends them to the new password screen.
  Future<void> sendPasswordReset(String email) {
    return client.auth.resetPasswordForEmail(email, redirectTo: _redirectUrl);
  }

  Future<void> updatePassword(String password) {
    return client.auth.updateUser(UserAttributes(password: password));
  }

  Future<void> signOut() => client.auth.signOut();
}
