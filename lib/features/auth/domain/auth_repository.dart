import 'package:matchunsa/features/auth/domain/auth_user.dart';

abstract interface class AuthRepository {
  AuthUser? get currentUser;

  Stream<AuthUser?> get authStateChanges;

  Future<void> signInWithGoogle();

  Future<void> signOut();
}
