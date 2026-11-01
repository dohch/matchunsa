import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matchunsa/features/auth/domain/auth_user.dart';
import 'package:matchunsa/features/profile/domain/academic_semester.dart';
import 'package:matchunsa/features/profile/domain/academic_status.dart';
import 'package:matchunsa/features/profile/domain/professional_careers.dart';
import 'package:matchunsa/features/profile/domain/professional_profile.dart';
import 'package:matchunsa/features/profile/domain/profile_repository.dart';
import 'package:matchunsa/features/profile/presentation/professional_profile_page.dart';

void main() {
  test('career and semester options match the standardized lists', () {
    expect(ProfessionalCareers.options, hasLength(52));
    expect(ProfessionalCareers.options.first, 'Arquitectura');
    expect(ProfessionalCareers.options.last, 'Marketing');
    expect(
        AcademicSemester.options, List<int>.generate(14, (index) => index + 1));
    expect(AcademicSemester.label(1), '1.er semestre');
    expect(AcademicSemester.label(2), '2.º semestre');
    expect(AcademicSemester.label(3), '3.er semestre');
    expect(AcademicSemester.label(14), '14.º semestre');
  });

  testWidgets('incomplete required fields are not saved', (tester) async {
    final repository = _FakeProfileRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: ProfessionalProfilePage(
          user: const AuthUser(id: 'user-id', email: 'student@unsa.edu.pe'),
          repository: repository,
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final saveButton = find.text('Guardar cambios');
    await tester.scrollUntilVisible(
      saveButton,
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, 1000));
    await tester.pumpAndSettle();

    expect(find.text('Ingresa tus nombres.'), findsOneWidget);
    expect(find.text('Ingresa tus apellidos.'), findsOneWidget);
    expect(find.text('Selecciona tu carrera profesional.'), findsOneWidget);
    expect(find.text('Selecciona tu situación académica.'), findsOneWidget);
    expect(repository.savedProfile, isNull);
  });

  testWidgets('existing standardized career and semester remain selected', (
    tester,
  ) async {
    const savedProfile = ProfessionalProfile(
      userId: 'user-id',
      firstNames: 'Ana',
      lastNames: 'Quispe',
      career: 'Ingeniería de Sistemas',
      academicStatus: AcademicStatus.student,
      semester: 14,
    );
    final repository = _FakeProfileRepository(initialProfile: savedProfile);

    await tester.pumpWidget(
      MaterialApp(
        home: ProfessionalProfilePage(
          user: const AuthUser(id: 'user-id', email: 'student@unsa.edu.pe'),
          repository: repository,
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ingeniería de Sistemas'), findsOneWidget);
    expect(find.text('14.º semestre'), findsOneWidget);

    final saveButton = find.text('Guardar cambios');
    await tester.scrollUntilVisible(
      saveButton,
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(repository.savedProfile?.career, 'Ingeniería de Sistemas');
    expect(repository.savedProfile?.semester, 14);
  });

  testWidgets('semester is required for students', (tester) async {
    final repository = _FakeProfileRepository(
      initialProfile: const ProfessionalProfile(
        userId: 'user-id',
        firstNames: 'Ana',
        lastNames: 'Quispe',
        career: 'Arquitectura',
        academicStatus: AcademicStatus.student,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ProfessionalProfilePage(
          user: const AuthUser(id: 'user-id', email: 'student@unsa.edu.pe'),
          repository: repository,
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final saveButton = find.text('Guardar cambios');
    await tester.scrollUntilVisible(
      saveButton,
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, 500));
    await tester.pumpAndSettle();

    expect(
        find.text('Selecciona el semestre académico actual.'), findsOneWidget);
    expect(repository.savedProfile, isNull);
  });

  testWidgets('semester remains optional for graduates', (tester) async {
    final repository = _FakeProfileRepository(
      initialProfile: const ProfessionalProfile(
        userId: 'user-id',
        firstNames: 'Ana',
        lastNames: 'Quispe',
        career: 'Arquitectura',
        academicStatus: AcademicStatus.graduate,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ProfessionalProfilePage(
          user: const AuthUser(id: 'user-id', email: 'student@unsa.edu.pe'),
          repository: repository,
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final saveButton = find.text('Guardar cambios');
    await tester.scrollUntilVisible(
      saveButton,
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(repository.savedProfile?.semester, isNull);
  });

  testWidgets('legacy out-of-list values are shown without saving them', (
    tester,
  ) async {
    final repository = _FakeProfileRepository(
      initialProfile: const ProfessionalProfile(
        userId: 'user-id',
        firstNames: 'Ana',
        lastNames: 'Quispe',
        career: 'Carrera anterior',
        academicStatus: AcademicStatus.graduate,
        semester: 15,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ProfessionalProfilePage(
          user: const AuthUser(id: 'user-id', email: 'student@unsa.edu.pe'),
          repository: repository,
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
        find.textContaining(
            'Carrera guardada anteriormente: Carrera anterior.'),
        findsOneWidget);
    expect(find.textContaining('Semestre guardado anteriormente: 15.'),
        findsOneWidget);
    expect(repository.savedProfile, isNull);
  });
}

class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository({this.initialProfile});

  final ProfessionalProfile? initialProfile;
  ProfessionalProfile? savedProfile;

  @override
  Future<ProfessionalProfile?> getForUser(String userId) async =>
      initialProfile;

  @override
  Future<ProfessionalProfile> save(ProfessionalProfile profile) async {
    savedProfile = profile;
    return profile;
  }

  @override
  Future<String> uploadCv({
    required String userId,
    required Uint8List bytes,
  }) async =>
      '$userId/cv.pdf';
}
