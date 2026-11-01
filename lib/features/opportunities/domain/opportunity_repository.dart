import 'package:matchunsa/features/opportunities/domain/opportunity.dart';

abstract interface class OpportunityRepository {
  Future<List<Opportunity>> getOpportunities({bool includeInactive = false});

  Future<void> setOpportunityActive({
    required String opportunityId,
    required bool isActive,
  });

  Future<List<String>> getFavoriteOpportunityIds(String userId);

  Future<void> addFavorite({
    required String userId,
    required String opportunityId,
  });

  Future<void> removeFavorite({
    required String userId,
    required String opportunityId,
  });

  Future<List<Opportunity>> getFavorites(String userId);

  Future<void> reportOpportunity({
    required String userId,
    required String opportunityId,
    required String reason,
  });

  Future<List<Map<String, dynamic>>> getAdminReports();

  Future<void> updateReportStatus({
    required String reportId,
    required String status,
    String? adminNotes,
  });

  Future<List<Map<String, dynamic>>> getAdminUsers();

  Future<List<Map<String, dynamic>>> getAdminSourceEmails();

  Future<bool> isUserAdmin(String userId);
}
