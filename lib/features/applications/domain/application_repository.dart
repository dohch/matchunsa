import 'package:matchunsa/features/applications/domain/job_application.dart';

abstract interface class ApplicationRepository {
  Future<List<JobApplication>> getApplications(String userId);

  Future<JobApplication?> getApplicationForOpportunity({
    required String userId,
    required String opportunityId,
  });

  Future<JobApplication> saveApplication(JobApplication application);

  Future<void> deleteApplication(String applicationId);
}
