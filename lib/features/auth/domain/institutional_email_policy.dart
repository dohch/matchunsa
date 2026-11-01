abstract final class InstitutionalEmailPolicy {
  static bool allows({required String? email, required bool isVerified}) {
    if (!isVerified || email == null) return false;

    return RegExp(r'^[^@]+@unsa[.]edu[.]pe$', caseSensitive: false)
        .hasMatch(email.trim());
  }
}
