import 'package:matchunsa/features/profile/domain/academic_status.dart';

class ProfessionalProfile {
  const ProfessionalProfile({
    required this.userId,
    required this.firstNames,
    required this.lastNames,
    required this.career,
    required this.academicStatus,
    this.phone,
    this.linkedinUrl,
    this.semester,
    this.skills = const [],
    this.cvPath,
    this.faculty,
    this.studentCode,
    this.additionalInfo,
  });

  final String userId;
  final String firstNames;
  final String lastNames;
  final String career;
  final AcademicStatus academicStatus;
  final String? phone;
  final String? linkedinUrl;
  final int? semester;
  final List<String> skills;
  final String? cvPath;
  final String? faculty;
  final String? studentCode;
  final String? additionalInfo;
}
