import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matchunsa/features/opportunities/domain/opportunity.dart';
import 'package:matchunsa/features/opportunities/domain/opportunity_career.dart';
import 'package:matchunsa/features/opportunities/domain/opportunity_filter.dart';
import 'package:matchunsa/features/opportunities/domain/opportunity_repository.dart';
import 'package:matchunsa/features/opportunities/presentation/opportunity_detail_page.dart';
import 'package:matchunsa/features/opportunities/presentation/opportunity_list_page.dart';

void main() {
  testWidgets('shows empty state when there are no opportunities',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: OpportunityListPage(repository: _FakeRepository([]))),
    );
    await tester.pumpAndSettle();

    expect(find.text('No hay oportunidades disponibles por el momento.'),
        findsOneWidget);
  });

  testWidgets('shows an opportunity and opens its detail', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OpportunityListPage(
          repository: _FakeRepository([_opportunity]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Practicante de sistemas'), findsOneWidget);
    expect(find.text('Empresa UNSA'), findsOneWidget);
    await tester.tap(find.text('Practicante de sistemas'));
    await tester.pumpAndSettle();
    expect(find.text('Contenido original de la convocatoria'), findsOneWidget);
  });

  testWidgets('shows an error state and retry action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: OpportunityListPage(repository: _FailingRepository())),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('No se pudieron cargar'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('detail omits absent fields and shows stored content',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: OpportunityDetailPage(opportunity: _opportunity)),
    );

    expect(find.text('Practicante de sistemas'), findsOneWidget);
    expect(find.text('Empresa UNSA'), findsOneWidget);
    expect(find.text('Requisitos'), findsNothing);
    expect(find.text('Vacantes'), findsNothing);
    expect(find.text('Contenido fuente'), findsOneWidget);
  });

  testWidgets('filters by query and career matching correctly',
      (tester) async {
    final repo = _FakeRepository([
      _opportunity,
      const Opportunity(
        id: 'id-2',
        title: 'Abogado Jr',
        company: 'Estudio Legal',
        careers: [
          OpportunityCareer(
            originalName: 'Derecho',
            canonicalName: 'Derecho',
          ),
        ],
        originalContent: 'Contenido legal',
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: OpportunityListPage(
          repository: repo,
          searchQuery: 'sistemas',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Practicante de sistemas'), findsOneWidget);
    expect(find.text('Abogado Jr'), findsNothing);
  });

  test('opportunity filter entity matches career and company properly', () {
    const filter = OpportunityFilter(
      companyQuery: 'UNSA',
      career: 'Sistemas',
    );

    expect(filter.matches(_opportunity), isTrue);

    const nonMatching = OpportunityFilter(companyQuery: 'Google');
    expect(nonMatching.matches(_opportunity), isFalse);
  });
}

const _opportunity = Opportunity(
  id: 'id-1',
  title: 'Practicante de sistemas',
  company: 'Empresa UNSA',
  careers: [
    OpportunityCareer(
      originalName: 'Ing. de Sistemas',
      canonicalName: 'Ingeniería de Sistemas',
    ),
  ],
  originalContent: 'Contenido fuente',
);

class _FakeRepository implements OpportunityRepository {
  _FakeRepository(this.opportunities);
  final List<Opportunity> opportunities;
  final Set<String> favorites = {};

  @override
  Future<List<Opportunity>> getOpportunities({
    bool includeInactive = false,
  }) async =>
      includeInactive ? opportunities : opportunities.where((o) => o.isActive).toList();

  @override
  Future<void> setOpportunityActive({
    required String opportunityId,
    required bool isActive,
  }) async {}

  @override
  Future<List<String>> getFavoriteOpportunityIds(String userId) async =>
      favorites.toList();

  @override
  Future<void> addFavorite({
    required String userId,
    required String opportunityId,
  }) async =>
      favorites.add(opportunityId);

  @override
  Future<void> removeFavorite({
    required String userId,
    required String opportunityId,
  }) async =>
      favorites.remove(opportunityId);

  @override
  Future<List<Opportunity>> getFavorites(String userId) async =>
      opportunities.where((o) => favorites.contains(o.id)).toList();

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

class _FailingRepository implements OpportunityRepository {
  @override
  Future<List<Opportunity>> getOpportunities({
    bool includeInactive = false,
  }) async =>
      throw StateError('test error');

  @override
  Future<void> setOpportunityActive({
    required String opportunityId,
    required bool isActive,
  }) async =>
      throw StateError('test error');

  @override
  Future<List<String>> getFavoriteOpportunityIds(String userId) async =>
      throw StateError('test error');

  @override
  Future<void> addFavorite({
    required String userId,
    required String opportunityId,
  }) async =>
      throw StateError('test error');

  @override
  Future<void> removeFavorite({
    required String userId,
    required String opportunityId,
  }) async =>
      throw StateError('test error');

  @override
  Future<List<Opportunity>> getFavorites(String userId) async =>
      throw StateError('test error');

  @override
  Future<void> reportOpportunity({
    required String userId,
    required String opportunityId,
    required String reason,
  }) async =>
      throw StateError('test error');

  @override
  Future<List<Map<String, dynamic>>> getAdminReports() async =>
      throw StateError('test error');

  @override
  Future<void> updateReportStatus({
    required String reportId,
    required String status,
    String? adminNotes,
  }) async =>
      throw StateError('test error');

  @override
  Future<List<Map<String, dynamic>>> getAdminUsers() async =>
      throw StateError('test error');

  @override
  Future<List<Map<String, dynamic>>> getAdminSourceEmails() async =>
      throw StateError('test error');

  @override
  Future<bool> isUserAdmin(String userId) async => false;
}
