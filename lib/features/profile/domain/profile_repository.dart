import 'dart:typed_data';

import 'package:matchunsa/features/profile/domain/professional_profile.dart';

abstract interface class ProfileRepository {
  Future<ProfessionalProfile?> getForUser(String userId);

  Future<ProfessionalProfile> save(ProfessionalProfile profile);

  Future<String> uploadCv({required String userId, required Uint8List bytes});
}
