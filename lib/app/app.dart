import 'package:flutter/material.dart';
import 'package:matchunsa/app/router/authenticated_shell.dart';
import 'package:matchunsa/app/theme/app_theme.dart';
import 'package:matchunsa/features/applications/domain/application_repository.dart';
import 'package:matchunsa/features/auth/domain/auth_repository.dart';
import 'package:matchunsa/features/auth/presentation/auth_page.dart';
import 'package:matchunsa/features/notifications/domain/notification_repository.dart';
import 'package:matchunsa/features/opportunities/domain/opportunity_repository.dart';
import 'package:matchunsa/features/profile/domain/profile_repository.dart';

class MatchUNSAApp extends StatelessWidget {
  const MatchUNSAApp({
    super.key,
    required this.authRepository,
    required this.profileRepository,
    required this.opportunityRepository,
    required this.applicationRepository,
    required this.notificationRepository,
  });

  final AuthRepository authRepository;
  final ProfileRepository profileRepository;
  final OpportunityRepository opportunityRepository;
  final ApplicationRepository applicationRepository;
  final NotificationRepository notificationRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MatchUNSA',
      theme: AppTheme.light,
      home: AuthPage(
        repository: authRepository,
        authenticatedBuilder: (user) => AuthenticatedShell(
          user: user,
          profileRepository: profileRepository,
          opportunityRepository: opportunityRepository,
          applicationRepository: applicationRepository,
          notificationRepository: notificationRepository,
          onSignOut: authRepository.signOut,
        ),
      ),
    );
  }
}
