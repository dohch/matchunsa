import 'package:flutter_test/flutter_test.dart';
import 'package:matchunsa/features/applications/domain/job_application.dart';
import 'package:matchunsa/features/applications/domain/job_application_status.dart';
import 'package:matchunsa/features/notifications/domain/notification_type.dart';
import 'package:matchunsa/features/notifications/domain/user_notification.dart';
import 'package:matchunsa/features/opportunities/domain/opportunity.dart';
import 'package:matchunsa/features/opportunities/domain/opportunity_career.dart';
import 'package:matchunsa/features/opportunities/domain/opportunity_filter.dart';
import 'package:matchunsa/features/profile/domain/professional_faculties.dart';

void main() {
  group('JobApplication and Status tests', () {
    test('JobApplicationStatus parsing and database values', () {
      expect(
        JobApplicationStatus.fromDatabaseValue('pendiente'),
        JobApplicationStatus.pendiente,
      );
      expect(
        JobApplicationStatus.fromDatabaseValue('postulada'),
        JobApplicationStatus.postulada,
      );
      expect(
        JobApplicationStatus.fromDatabaseValue('en evaluacion'),
        JobApplicationStatus.enEvaluacion,
      );
      expect(
        JobApplicationStatus.fromDatabaseValue('seleccionada'),
        JobApplicationStatus.seleccionada,
      );
      expect(
        JobApplicationStatus.fromDatabaseValue('no seleccionada'),
        JobApplicationStatus.noSeleccionada,
      );
      expect(
        JobApplicationStatus.pendiente.databaseValue,
        'pendiente',
      );
    });

    test('JobApplication copyWith works correctly', () {
      const app = JobApplication(
        id: 'app-1',
        userId: 'user-1',
        opportunityId: 'opp-1',
        status: JobApplicationStatus.pendiente,
        notes: 'Nota inicial',
      );

      final updated = app.copyWith(
        status: JobApplicationStatus.postulada,
        notes: 'Postulación enviada',
      );

      expect(updated.id, 'app-1');
      expect(updated.status, JobApplicationStatus.postulada);
      expect(updated.notes, 'Postulación enviada');
    });
  });

  group('OpportunityFilter advanced matching', () {
    final opportunity = Opportunity(
      id: 'opp-1',
      title: 'Desarrollador Flutter Jr',
      company: 'Tech UNSA',
      location: 'Arequipa',
      closingDate: DateTime.now().add(const Duration(days: 10)),
      careers: const [
        OpportunityCareer(
          originalName: 'Ingeniería de Sistemas',
          canonicalName: 'Ingeniería de Sistemas',
        ),
      ],
      originalContent: 'Convocatoria laboral para puesto de programador',
    );

    test('matches title, company, location, career', () {
      const filter = OpportunityFilter(
        titleQuery: 'flutter',
        companyQuery: 'tech',
        locationQuery: 'arequipa',
        career: 'Sistemas',
        type: OpportunityTypeFilter.laboral,
        validity: OpportunityValidityFilter.activeOnly,
      );

      expect(filter.matches(opportunity), isTrue);
    });

    test('rejects non-matching attributes', () {
      const filterWrongLocation = OpportunityFilter(
        locationQuery: 'Cusco',
      );
      expect(filterWrongLocation.matches(opportunity), isFalse);

      const filterWrongType = OpportunityFilter(
        type: OpportunityTypeFilter.practicas,
      );
      expect(filterWrongType.matches(opportunity), isFalse);
    });

    test('detects active filters count and clear flags', () {
      final filter = const OpportunityFilter().copyWith(
        titleQuery: 'Desarrollador',
        companyQuery: 'Tech',
      );
      expect(filter.activeFiltersCount, 2);

      final cleared = filter.copyWith(clearTitleQuery: true);
      expect(cleared.activeFiltersCount, 1);
      expect(cleared.titleQuery, isNull);
      expect(cleared.companyQuery, 'Tech');
    });
  });

  group('Notifications tests', () {
    test('NotificationType parsing and values', () {
      expect(
        NotificationType.fromDatabaseValue('new_opportunity'),
        NotificationType.newOpportunity,
      );
      expect(
        NotificationType.fromDatabaseValue('closing_soon'),
        NotificationType.closingSoon,
      );
      expect(
        NotificationType.newOpportunity.databaseValue,
        'new_opportunity',
      );
    });

    test('UserNotification copyWith update isRead', () {
      const notif = UserNotification(
        id: 'n-1',
        userId: 'u-1',
        title: 'Nueva oportunidad',
        message: 'Convocatoria publicada',
        type: NotificationType.newOpportunity,
        isRead: false,
      );

      final readNotif = notif.copyWith(isRead: true);
      expect(readNotif.isRead, isTrue);
      expect(readNotif.title, 'Nueva oportunidad');
    });
  });

  group('ProfessionalFaculties tests', () {
    test('suggests canonical faculties for common careers', () {
      expect(
        ProfessionalFaculties.facultyForCareer('Ingeniería de Sistemas'),
        'Facultad de Ingeniería de Producción y Servicios',
      );
      expect(
        ProfessionalFaculties.facultyForCareer('Derecho'),
        'Facultad de Derecho',
      );
      expect(
        ProfessionalFaculties.facultyForCareer('Medicina'),
        'Facultad de Medicina',
      );
      expect(
        ProfessionalFaculties.facultyForCareer('Arquitectura'),
        'Facultad de Arquitectura y Urbanismo',
      );
    });
  });
}
