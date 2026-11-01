import 'package:flutter/material.dart';
import 'package:matchunsa/app/app.dart';
import 'package:matchunsa/core/config/supabase_config.dart';
import 'package:matchunsa/features/applications/data/supabase_application_repository.dart';
import 'package:matchunsa/features/auth/data/supabase_auth_repository.dart';
import 'package:matchunsa/features/notifications/data/supabase_notification_repository.dart';
import 'package:matchunsa/features/opportunities/data/supabase_opportunity_repository.dart';
import 'package:matchunsa/features/profile/data/supabase_profile_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.projectUrl,
    publishableKey: SupabaseConfig.publishableKey,
  );

  final supabaseClient = Supabase.instance.client;
  runApp(
    MatchUNSAApp(
      authRepository: SupabaseAuthRepository(supabaseClient),
      profileRepository: SupabaseProfileRepository(supabaseClient),
      opportunityRepository: SupabaseOpportunityRepository(supabaseClient),
      applicationRepository: SupabaseApplicationRepository(supabaseClient),
      notificationRepository: SupabaseNotificationRepository(supabaseClient),
    ),
  );
}
