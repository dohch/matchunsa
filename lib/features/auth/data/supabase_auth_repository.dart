import 'package:flutter/foundation.dart';
import 'package:matchunsa/features/auth/domain/auth_repository.dart';
import 'package:matchunsa/features/auth/domain/auth_user.dart';
import 'package:matchunsa/features/auth/domain/institutional_account_required_exception.dart';
import 'package:matchunsa/features/auth/domain/institutional_email_policy.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show GoTrueClientSignInProvider, OAuthProvider, SupabaseClient, User;

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  AuthUser? get currentUser => _toEligibleUser(_client.auth.currentUser);

  @override
  Stream<AuthUser?> get authStateChanges {
    return _client.auth.onAuthStateChange.asyncMap((authState) async {
      final user = authState.session?.user;
      if (user == null) return null;

      final eligibleUser = _toEligibleUser(user);
      if (eligibleUser == null) {
        await _client.auth.signOut();
        throw const InstitutionalAccountRequiredException();
      }

      return eligibleUser;
    });
  }

  @override
  Future<void> signInWithGoogle() async {
    if (!kIsWeb) {
      throw UnsupportedError(
        'El inicio con Google está habilitado solo para Web en esta etapa.',
      );
    }

    final started = await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      queryParams: const {'prompt': 'select_account'},
    );
    if (!started) {
      throw StateError('No se pudo iniciar el flujo de Google OAuth.');
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  AuthUser? _toEligibleUser(User? user) {
    final email = user?.email;
    if (user == null ||
        !InstitutionalEmailPolicy.allows(
          email: email,
          isVerified: user.emailConfirmedAt != null,
        )) {
      return null;
    }

    return AuthUser(id: user.id, email: email!.trim());
  }
}
