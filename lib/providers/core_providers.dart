import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_repository.dart';
import '../data/errors.dart';
import '../data/remote_rows.dart';
import '../data/row_store.dart';
import '../models/profile.dart';

/// The single shared Supabase client, initialised in `main()`.
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

/// Loaded in `main()`, so that everything else can read it synchronously.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Overridden in main()'),
);

final remoteRowsProvider = Provider<RemoteRows>(
  (ref) => SupabaseRemoteRows(ref.watch(supabaseClientProvider)),
);

/// The one store every table is read and written through. It asks for the user
/// id at call time, so it lives as long as the app and never holds on to a user.
final rowStoreProvider = Provider<RowStore>((ref) {
  final store = RowStore(
    remote: ref.watch(remoteRowsProvider),
    prefs: ref.watch(sharedPreferencesProvider),
    currentUserId: () => ref.read(currentUserIdProvider),
  );
  ref.onDispose(store.dispose);
  return store;
});

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseClientProvider)),
);

/// Authoritative session state. The router redirects off this, so a token that
/// expires mid-session sends the student back to login instead of leaving the
/// app on a screen that can no longer read anything.
final authStateProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges,
);

/// `main()` waits for Supabase to restore the session, so until the stream has
/// reported anything the client already knows who is signed in.
final currentUserProvider = Provider<User?>((ref) {
  final auth = ref.watch(authStateProvider);
  if (auth.hasValue) return auth.value?.session?.user;
  return ref.read(authRepositoryProvider).currentUser;
});

/// Who the data on screen belongs to. Providers holding a student's rows watch
/// this rather than the user object, which is replaced on every token refresh.
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(currentUserProvider.select((user) => user?.id));
});

final profileProvider = AsyncNotifierProvider<ProfileNotifier, Profile?>(
  ProfileNotifier.new,
);

/// The student's own row in `profiles`: name, targets and current semester.
class ProfileNotifier extends AsyncNotifier<Profile?> {
  RowStore get _store => ref.read(rowStoreProvider);

  @override
  Future<Profile?> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return null;
    final rows = await ref
        .read(rowStoreProvider)
        .fetch('profiles', orderColumn: 'id');
    return rows.isEmpty ? null : Profile.fromMap(rows.first);
  }

  Future<void> _put(Map<String, dynamic> values) async {
    final row = await _store.put('profiles', _store.requireUserId(), values);
    state = AsyncData(Profile.fromMap(row));
  }

  /// Writes the name to both the profile row and the auth metadata, so any
  /// other client reading `user_metadata` agrees.
  Future<void> rename(String name) async {
    final trimmed = name.trim();
    await _put({'full_name': trimmed});
    final auth = ref.read(supabaseClientProvider).auth;
    final user = auth.currentUser;
    if (user == null) return;
    try {
      await auth.updateUser(
        UserAttributes(data: {...?user.userMetadata, 'full_name': trimmed}),
      );
    } catch (error) {
      // The profile row is what the app shows, and it is saved. The metadata
      // is only a fallback, so it can wait for the next rename.
      if (!isNetworkFailure(error)) rethrow;
    }
  }

  Future<void> setStudyGoal(int minutes) =>
      _put({'weekly_study_goal_minutes': minutes});

  /// Passing `null` removes the budget.
  Future<void> setMonthlyBudget(double? amount) =>
      _put({'monthly_budget': amount});

  Future<void> setCurrentSemester(String? semesterId) =>
      _put({'current_semester_id': semesterId});
}

/// What the greeting renders, resolved from the profile row first and the auth
/// metadata second.
final displayNameProvider = Provider<String>((ref) {
  final user = ref.watch(currentUserProvider);
  final profile = ref.watch(profileProvider).value;
  return resolveDisplayName(
    profileName: profile?.fullName,
    authName: user?.userMetadata?['full_name'] as String?,
    email: user?.email,
  );
});

final displayInitialProvider = Provider<String>((ref) {
  final name = ref.watch(displayNameProvider);
  return name.isEmpty ? 'S' : name[0].toUpperCase();
});

/// Signs out and wipes this student's saved data from the device, so the next
/// person using the phone cannot find it.
final signOutAction = Provider<Future<void> Function()>((ref) {
  return () async {
    final user = ref.read(currentUserIdProvider);
    try {
      await ref.read(authRepositoryProvider).signOut();
    } catch (error) {
      // The session is removed locally before the server is told, so being
      // offline does not stop the sign-out.
      if (!isNetworkFailure(error)) rethrow;
    }
    if (user != null) await ref.read(rowStoreProvider).clearUser(user);
  };
});

/// True from opening a password reset link until a new password is saved. While
/// it is set, the router holds the student on the new password screen.
final passwordRecoveryProvider =
    NotifierProvider<PasswordRecoveryNotifier, bool>(
      PasswordRecoveryNotifier.new,
    );

class PasswordRecoveryNotifier extends Notifier<bool> {
  @override
  bool build() {
    ref.listen(authStateProvider, (_, next) {
      if (next.value?.event == AuthChangeEvent.passwordRecovery) state = true;
    }, fireImmediately: true);
    ref.listen(currentUserIdProvider, (_, user) {
      if (user == null) state = false;
    });
    return false;
  }

  void finish() => state = false;
}
