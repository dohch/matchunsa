import 'package:flutter_test/flutter_test.dart';
import 'package:matchunsa/features/auth/domain/institutional_email_policy.dart';

void main() {
  group('InstitutionalEmailPolicy', () {
    test('accepts a verified UNSA address', () {
      expect(
        InstitutionalEmailPolicy.allows(
          email: 'student@unsa.edu.pe',
          isVerified: true,
        ),
        isTrue,
      );
    });

    test('rejects an unverified UNSA address', () {
      expect(
        InstitutionalEmailPolicy.allows(
          email: 'student@unsa.edu.pe',
          isVerified: false,
        ),
        isFalse,
      );
    });

    test('rejects addresses outside the institutional domain', () {
      expect(
        InstitutionalEmailPolicy.allows(
          email: 'student@example.com',
          isVerified: true,
        ),
        isFalse,
      );
    });
  });
}
