import 'package:matchunsa/features/opportunities/domain/opportunity.dart';
import 'package:matchunsa/features/opportunities/domain/opportunity_career.dart';
import 'package:matchunsa/features/opportunities/domain/opportunity_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseOpportunityRepository implements OpportunityRepository {
  SupabaseOpportunityRepository(this._client);

  final SupabaseClient _client;

  static const _opportunitySelect =
      'id,title,company,academic_profile,location,closing_date,vacancies,'
      'requirements,desired_knowledge,functions,additional_information,'
      'application_url,application_email,application_phone,cv_type,is_active,'
      'original_content,'
      'opportunity_careers(career_name,original_career_name)';

  @override
  Future<List<Opportunity>> getOpportunities({
    bool includeInactive = false,
  }) async {
    var query = _client.from('opportunities').select(_opportunitySelect);

    if (!includeInactive) {
      query = query.eq('is_active', true);
    }

    final rows = await query.order('closing_date',
        ascending: true, nullsFirst: false);

    return rows.map(_fromRow).toList(growable: false);
  }

  @override
  Future<void> setOpportunityActive({
    required String opportunityId,
    required bool isActive,
  }) async {
    await _client
        .from('opportunities')
        .update({'is_active': isActive})
        .eq('id', opportunityId);
  }

  @override
  Future<List<String>> getFavoriteOpportunityIds(String userId) async {
    final rows = await _client
        .from('opportunity_favorites')
        .select('opportunity_id')
        .eq('user_id', userId);

    return rows
        .map((row) => row['opportunity_id'] as String?)
        .whereType<String>()
        .toList(growable: false);
  }

  @override
  Future<void> addFavorite({
    required String userId,
    required String opportunityId,
  }) async {
    // Use insert (not upsert): opportunity_favorites is granted
    // select/insert/delete only. PostgREST upsert needs UPDATE privileges
    // and an UPDATE RLS policy, which this table intentionally does not have.
    try {
      await _client.from('opportunity_favorites').insert({
        'user_id': userId,
        'opportunity_id': opportunityId,
      });
    } on PostgrestException catch (error) {
      // Idempotent: already favorited by this user.
      if (error.code == '23505') return;
      rethrow;
    }
  }

  @override
  Future<void> removeFavorite({
    required String userId,
    required String opportunityId,
  }) async {
    await _client
        .from('opportunity_favorites')
        .delete()
        .eq('user_id', userId)
        .eq('opportunity_id', opportunityId);
  }

  @override
  Future<List<Opportunity>> getFavorites(String userId) async {
    final favoriteIds = await getFavoriteOpportunityIds(userId);
    if (favoriteIds.isEmpty) return const [];

    final rows = await _client
        .from('opportunities')
        .select(_opportunitySelect)
        .inFilter('id', favoriteIds)
        .order('closing_date', ascending: true, nullsFirst: false);

    return rows.map(_fromRow).toList(growable: false);
  }

  @override
  Future<void> reportOpportunity({
    required String userId,
    required String opportunityId,
    required String reason,
  }) async {
    await _client.from('opportunity_reports').insert({
      'user_id': userId,
      'opportunity_id': opportunityId,
      'reason': reason.trim(),
      'status': 'pending',
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getAdminReports() async {
    final rows = await _client
        .from('opportunity_reports')
        .select(
          'id,user_id,opportunity_id,reason,status,admin_notes,created_at,resolved_at,'
          'opportunities(title,company)',
        )
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Future<void> updateReportStatus({
    required String reportId,
    required String status,
    String? adminNotes,
  }) async {
    final updateData = <String, dynamic>{
      'status': status,
      if (adminNotes != null) 'admin_notes': adminNotes.trim(),
      if (status == 'resolved' || status == 'dismissed')
        'resolved_at': DateTime.now().toUtc().toIso8601String(),
    };

    await _client
        .from('opportunity_reports')
        .update(updateData)
        .eq('id', reportId);
  }

  @override
  Future<List<Map<String, dynamic>>> getAdminUsers() async {
    final rows = await _client
        .from('profiles')
        .select()
        .order('updated_at', ascending: false);

    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Future<List<Map<String, dynamic>>> getAdminSourceEmails() async {
    final rows = await _client
        .from('source_emails')
        .select()
        .order('received_at', ascending: false);

    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Future<bool> isUserAdmin(String userId) async {
    final row = await _client
        .from('app_admins')
        .select('user_id')
        .eq('user_id', userId)
        .maybeSingle();

    return row != null;
  }

  Opportunity _fromRow(Map<String, dynamic> row) {
    final careerRows = row['opportunity_careers'] as List? ?? const [];
    final careers = careerRows
        .whereType<Map>()
        .map((careerRow) => Map<String, dynamic>.from(careerRow))
        .map(_careerFromRow)
        .whereType<OpportunityCareer>()
        .toList(growable: false);

    return Opportunity(
      id: row['id'] as String,
      title: _optionalString(row['title']),
      company: _optionalString(row['company']),
      careers: careers,
      originalContent: row['original_content'] as String,
      academicProfile: _optionalString(row['academic_profile']),
      location: _optionalString(row['location']),
      closingDate: _date(row['closing_date']),
      vacancies: _integer(row['vacancies']),
      requirements: _optionalString(row['requirements']),
      desiredKnowledge: _optionalString(row['desired_knowledge']),
      functions: _optionalString(row['functions']),
      additionalInformation: _optionalString(row['additional_information']),
      applicationUrl: _optionalString(row['application_url']),
      applicationEmail: _optionalString(row['application_email']),
      applicationPhone: _optionalString(row['application_phone']),
      cvType: _optionalString(row['cv_type']),
      isActive: (row['is_active'] as bool?) ?? true,
    );
  }

  OpportunityCareer? _careerFromRow(Map<String, dynamic> row) {
    final originalName = _optionalString(row['original_career_name']);
    if (originalName == null) return null;

    return OpportunityCareer(
      originalName: originalName,
      canonicalName: _optionalString(row['career_name']),
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
