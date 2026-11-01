import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:matchunsa/app/app.dart';
import 'package:matchunsa/features/applications/domain/application_repository.dart';
import 'package:matchunsa/features/applications/domain/job_application.dart';
import 'package:matchunsa/features/auth/domain/auth_repository.dart';
import 'package:matchunsa/features/auth/domain/auth_user.dart';
import 'package:matchunsa/features/notifications/domain/notification_repository.dart';
import 'package:matchunsa/features/notifications/domain/user_notification.dart';
import 'package:matchunsa/features/opportunities/domain/opportunity_repository.dart';
import 'package:matchunsa/features/opportunities/domain/opportunity.dart';
import 'package:matchunsa/features/profile/domain/profile_repository.dart';
import 'package:matchunsa/features/profile/domain/professional_profile.dart';

void main() {
  testWidgets('MatchUNSA startup screen is available',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MatchUNSAApp(
        authRepository: _FakeAuthRepository(),
        profileRepository: _FakeProfileRepository(),
        opportunityRepository: _FakeOpportunityRepository(),
        applicationRepository: _FakeApplicationRepository(),
        notificationRepository: _FakeNotificationRepository(),
      ),
    );
    await tester.pump();

    expect(find.text('MatchUNSA'), findsOneWidget);
  });
}

class _FakeAuthRepository implements AuthRepository {
  const _FakeAuthRepository();

  @override
  AuthUser? get currentUser => null;

  @override
  Stream<AuthUser?> get authStateChanges => Stream.value(null);

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> signOut() async {}
}

class _FakeProfileRepository implements ProfileRepository {
  const _FakeProfileRepository();

  @override
  Future<ProfessionalProfile?> getForUser(String userId) async => null;

  @override
  Future<ProfessionalProfile> save(ProfessionalProfile profile) async =>
      profile;

  @override
  Future<String> uploadCv({
    required String userId,
    required Uint8List bytes,
  }) async =>
      '$userId/cv.pdf';
}

class _FakeOpportunityRepository implements OpportunityRepository {
  const _FakeOpportunityRepository();

  @override
  Future<List<Opportunity>> getOpportunities({
    bool includeInactive = false,
  }) async =>
      const [];

  @override
  Future<void> setOpportunityActive({
    required String opportunityId,
    required bool isActive,
  }) async {}

  @override
  Future<List<String>> getFavoriteOpportunityIds(String userId) async =>
      const [];

  @override
  Future<void> addFavorite({
    required String userId,
    required String opportunityId,
  }) async {}

  @override
  Future<void> removeFavorite({
    required String userId,
    required String opportunityId,
  }) async {}

  @override
  Future<List<Opportunity>> getFavorites(String userId) async => const [];

  @override
  Future<void> reportOpportunity({
    required String userId,
    required String opportunityId,
    required String reason,
  }) async {}

  @override
  Future<List<Map<String, dynamic>>> getAdminReports() async => const [];

  @override
  Future<void> updateReportStatus({
    required String reportId,
    required String status,
    String? adminNotes,
  }) async {}

  @override
  Future<List<Map<String, dynamic>>> getAdminUsers() async => const [];

  @override
  Future<List<Map<String, dynamic>>> getAdminSourceEmails() async => const [];

  @override
  Future<bool> isUserAdmin(String userId) async => false;
}

class _FakeApplicationRepository implements ApplicationRepository {
  const _FakeApplicationRepository();

  @override
  Future<List<JobApplication>> getApplications(String userId) async => const [];

  @override
  Future<JobApplication?> getApplicationForOpportunity({
    required String userId,
    required String opportunityId,
  }) async =>
      null;

  @override
  Future<JobApplication> saveApplication(JobApplication application) async =>
      application;

  @override
  Future<void> deleteApplication(String applicationId) async {}
}

class _FakeNotificationRepository implements NotificationRepository {
  const _FakeNotificationRepository();

  @override
  Future<List<UserNotification>> getNotifications(String userId) async =>
      const [];

  @override
  Future<void> markAsRead(String notificationId) async {}

  @override
  Future<void> markAllAsRead(String userId) async {}

  @override
  Future<int> syncNotifications(String userId) async => 0;
}
