import 'dart:typed_data';

import 'package:matchunsa/features/profile/domain/academic_status.dart';
import 'package:matchunsa/features/profile/domain/profile_repository.dart';
import 'package:matchunsa/features/profile/domain/professional_profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);

  static const _cvBucket = 'professional-cvs';

  final SupabaseClient _client;

  @override
  Future<ProfessionalProfile?> getForUser(String userId) async {
    final row = await _client
        .from('profiles')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (row == null) return null;
    return _fromRow(row);
  }

  @override
  Future<ProfessionalProfile> save(ProfessionalProfile profile) async {
    final row = await _client
        .from('profiles')
        .upsert(_toRow(profile), onConflict: 'user_id')
        .select()
        .single();

    return _fromRow(row);
  }

  @override
  Future<String> uploadCv({required String userId, required Uint8List bytes}) {
    final path = '$userId/cv.pdf';
    return _client.storage.from(_cvBucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'application/pdf',
            upsert: true,
          ),
        );
  }

  Map<String, dynamic> _toRow(ProfessionalProfile profile) {
    return {
      'user_id': profile.userId,
      'first_names': profile.firstNames,
      'last_names': profile.lastNames,
      'phone': profile.phone,
      'linkedin_url': profile.linkedinUrl,
      'career': profile.career,
      'academic_status': profile.academicStatus.databaseValue,
      'semester': profile.semester,
      'skills': profile.skills,
      'cv_path': profile.cvPath,
      'faculty': profile.faculty,
      'student_code': profile.studentCode,
      'additional_info': profile.additionalInfo,
    };
  }

  ProfessionalProfile _fromRow(Map<String, dynamic> row) {
    return ProfessionalProfile(
      userId: row['user_id'] as String,
      firstNames: row['first_names'] as String,
      lastNames: row['last_names'] as String,
      phone: row['phone'] as String?,
      linkedinUrl: row['linkedin_url'] as String?,
      career: row['career'] as String,
      academicStatus: AcademicStatus.fromDatabaseValue(
        row['academic_status'] as String,
      ),
      semester: row['semester'] as int?,
      skills: List<String>.from(row['skills'] as List? ?? const []),
      cvPath: row['cv_path'] as String?,
      faculty: row['faculty'] as String?,
      studentCode: row['student_code'] as String?,
      additionalInfo: row['additional_info'] as String?,
    );
  }
}
