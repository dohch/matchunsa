import 'package:matchunsa/features/applications/domain/application_repository.dart';
import 'package:matchunsa/features/applications/domain/job_application.dart';
import 'package:matchunsa/features/applications/domain/job_application_status.dart';
import 'package:matchunsa/features/opportunities/domain/opportunity.dart';
import 'package:matchunsa/features/opportunities/domain/opportunity_career.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseApplicationRepository implements ApplicationRepository {
  SupabaseApplicationRepository(this._client);

  final SupabaseClient _client;

  static const _selectQuery =
      'id,user_id,opportunity_id,status,notes,applied_at,created_at,updated_at,'
      'opportunities('
      'id,title,company,academic_profile,location,closing_date,vacancies,'
      'requirements,desired_knowledge,functions,additional_information,'
      'application_url,application_email,application_phone,cv_type,is_active,'
      'original_content,'
      'opportunity_careers(career_name,original_career_name)'
      ')';

  @override
  Future<List<JobApplication>> getApplications(String userId) async {
    final rows = await _client
        .from('job_applications')
        .select(_selectQuery)
        .eq('user_id', userId)
        .order('updated_at', ascending: false);

    return rows.map(_fromRow).toList(growable: false);
  }

  @override
  Future<JobApplication?> getApplicationForOpportunity({
    required String userId,
    required String opportunityId,
  }) async {
    final row = await _client
        .from('job_applications')
        .select(_selectQuery)
        .eq('user_id', userId)
        .eq('opportunity_id', opportunityId)
        .maybeSingle();

    if (row == null) return null;
    return _fromRow(row);
  }

  @override
  Future<JobApplication> saveApplication(JobApplication application) async {
    final payload = <String, dynamic>{
      'user_id': application.userId,
      'opportunity_id': application.opportunityId,
      'status': application.status.databaseValue,
      'notes': _optionalString(application.notes),
      'applied_at': (application.appliedAt ?? DateTime.now())
          .toUtc()
          .toIso8601String(),
    };

    final row = await _client
        .from('job_applications')
        .upsert(payload, onConflict: 'user_id,opportunity_id')
        .select(_selectQuery)
        .single();

    return _fromRow(row);
  }

  @override
  Future<void> deleteApplication(String applicationId) async {
    await _client.from('job_applications').delete().eq('id', applicationId);
  }

  JobApplication _fromRow(Map<String, dynamic> row) {
    Opportunity? opportunity;
    if (row['opportunities'] is Map) {
      final oppMap = Map<String, dynamic>.from(row['opportunities'] as Map);
      final careerRows = oppMap['opportunity_careers'] as List? ?? const [];
      final careers = careerRows
          .whereType<Map>()
          .map((c) => Map<String, dynamic>.from(c))
          .map((c) {
            final orig = _optionalString(c['original_career_name']);
            if (orig == null) return null;
            return OpportunityCareer(
              originalName: orig,
              canonicalName: _optionalString(c['career_name']),
            );
          })
          .whereType<OpportunityCareer>()
          .toList(growable: false);

      opportunity = Opportunity(
        id: oppMap['id'] as String,
        title: _optionalString(oppMap['title']),
        company: _optionalString(oppMap['company']),
        careers: careers,
        originalContent: (oppMap['original_content'] as String?) ?? '',
        academicProfile: _optionalString(oppMap['academic_profile']),
        location: _optionalString(oppMap['location']),
        closingDate: _date(oppMap['closing_date']),
        vacancies: _integer(oppMap['vacancies']),
        requirements: _optionalString(oppMap['requirements']),
        desiredKnowledge: _optionalString(oppMap['desired_knowledge']),
        functions: _optionalString(oppMap['functions']),
        additionalInformation:
            _optionalString(oppMap['additional_information']),
        applicationUrl: _optionalString(oppMap['application_url']),
        applicationEmail: _optionalString(oppMap['application_email']),
        applicationPhone: _optionalString(oppMap['application_phone']),
        cvType: _optionalString(oppMap['cv_type']),
        isActive: (oppMap['is_active'] as bool?) ?? true,
      );
    }

    return JobApplication(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      opportunityId: row['opportunity_id'] as String,
      status: JobApplicationStatus.fromDatabaseValue(row['status'] as String),
      notes: _optionalString(row['notes']),
      appliedAt: _date(row['applied_at']),
      createdAt: _date(row['created_at']),
      updatedAt: _date(row['updated_at']),
      opportunity: opportunity,
    );
  }

  String? _optionalString(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  int? _integer(Object? value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  DateTime? _date(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return DateTime.tryParse(value);
  }
}
