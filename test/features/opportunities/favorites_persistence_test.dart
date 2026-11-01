import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matchunsa/features/opportunities/domain/opportunity.dart';
import 'package:matchunsa/features/opportunities/domain/opportunity_career.dart';
import 'package:matchunsa/features/opportunities/domain/opportunity_repository.dart';
import 'package:matchunsa/features/opportunities/presentation/opportunity_detail_page.dart';
import 'package:matchunsa/features/opportunities/presentation/opportunity_list_page.dart';

void main() {
  group('Favorites persistence', () {
    testWidgets('marks favorite, persists in repository and survives reload',
        (tester) async {
      final repo = _RecordingFavoritesRepository([_opportunity]);

      await tester.pumpWidget(
        MaterialApp(
          home: OpportunityListPage(
            repository: repo,
            userId: 'user-1',
            showAppBar: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);

      await tester.tap(find.byTooltip('Guardar en favoritos'));
      await tester.pumpAndSettle();

      expect(repo.added, [('user-1', 'id-1')]);
      expect(repo.favorites, {'id-1'});
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);

      // Simulate leaving and re-entering the page (fresh State / app reopen).
      await tester.pumpWidget(
        MaterialApp(
          home: OpportunityListPage(
            repository: repo,
            userId: 'user-1',
            showAppBar: true,
            reloadToken: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
      expect(repo.loadFavoriteCalls, greaterThanOrEqualTo(2));
    });

    testWidgets('onlyFavorites list shows saved favorite after reloadToken',
        (tester) async {
      final repo = _RecordingFavoritesRepository([_opportunity]);
      await repo.addFavorite(userId: 'user-1', opportunityId: 'id-1');

      await tester.pumpWidget(
        MaterialApp(
          home: OpportunityListPage(
            repository: repo,
            userId: 'user-1',
            onlyFavorites: true,
            showAppBar: true,
            reloadToken: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Practicante de sistemas'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);

      await repo.removeFavorite(userId: 'user-1', opportunityId: 'id-1');

      await tester.pumpWidget(
        MaterialApp(
          home: OpportunityListPage(
            repository: repo,
            userId: 'user-1',
            onlyFavorites: true,
            showAppBar: true,
            reloadToken: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('No tienes convocatorias guardadas como favoritas.'),
        findsOneWidget,
      );
    });

    testWidgets('reverts heart when repository addFavorite fails',
        (tester) async {
      final repo = _RecordingFavoritesRepository(
        [_opportunity],
        failOnAdd: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: OpportunityListPage(
            repository: repo,
            userId: 'user-1',
            showAppBar: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Guardar en favoritos'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
      expect(find.text('No se pudo actualizar el favorito.'), findsOneWidget);
      expect(repo.favorites, isEmpty);
    });

    testWidgets('detail and list share the same favorite state after toggle',
        (tester) async {
      final repo = _RecordingFavoritesRepository([_opportunity]);

      await tester.pumpWidget(
        MaterialApp(
          home: OpportunityListPage(
            repository: repo,
            userId: 'user-1',
            showAppBar: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ver detalles'));
      await tester.pumpAndSettle();

      expect(find.byType(OpportunityDetailPage), findsOneWidget);
      await tester.tap(find.byTooltip('Guardar en favoritos'));
      await tester.pumpAndSettle();

      expect(repo.favorites, {'id-1'});
      expect(find.byIcon(Icons.favorite_rounded), findsWidgets);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    });

    testWidgets('detail reverts when save fails', (tester) async {
      final repo = _RecordingFavoritesRepository(
        [_opportunity],
        failOnAdd: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: OpportunityListPage(
            repository: repo,
            userId: 'user-1',
            showAppBar: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ver detalles'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Guardar en favoritos'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
      expect(repo.favorites, isEmpty);
    });

    test('repository records authenticated user id on add/remove', () async {
      final repo = _RecordingFavoritesRepository([_opportunity]);

      await repo.addFavorite(userId: 'auth-user-42', opportunityId: 'id-1');
      expect(repo.added, [('auth-user-42', 'id-1')]);
      expect(await repo.getFavoriteOpportunityIds('auth-user-42'), ['id-1']);
      expect(await repo.getFavoriteOpportunityIds('other-user'), isEmpty);

      await repo.removeFavorite(userId: 'auth-user-42', opportunityId: 'id-1');
      expect(repo.removed, [('auth-user-42', 'id-1')]);
      expect(await repo.getFavoriteOpportunityIds('auth-user-42'), isEmpty);
    });
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

class _RecordingFavoritesRepository implements OpportunityRepository {
  _RecordingFavoritesRepository(
    this.opportunities, {
    this.failOnAdd = false,
  });

  final List<Opportunity> opportunities;
  final bool failOnAdd;
  final Map<String, Set<String>> _favoritesByUser = {};
  final List<(String, String)> added = [];
  final List<(String, String)> removed = [];
  int loadFavoriteCalls = 0;

  Set<String> get favorites =>
      _favoritesByUser.values.fold(<String>{}, (acc, ids) => acc..addAll(ids));

  @override
  Future<List<Opportunity>> getOpportunities({
    bool includeInactive = false,
  }) async =>
      includeInactive
          ? opportunities
          : opportunities.where((o) => o.isActive).toList();

  @override
  Future<void> setOpportunityActive({
    required String opportunityId,
    required bool isActive,
  }) async {}

  @override
  Future<List<String>> getFavoriteOpportunityIds(String userId) async {
    loadFavoriteCalls++;
    return (_favoritesByUser[userId] ?? {}).toList();
  }

  @override
  Future<void> addFavorite({
    required String userId,
    required String opportunityId,
  }) async {
    added.add((userId, opportunityId));
    if (failOnAdd) {
      throw StateError('simulated supabase insert failure');
    }
    _favoritesByUser.putIfAbsent(userId, () => {}).add(opportunityId);
  }

  @override
  Future<void> removeFavorite({
    required String userId,
    required String opportunityId,
  }) async {
    removed.add((userId, opportunityId));
    _favoritesByUser[userId]?.remove(opportunityId);
  }

  @override
  Future<List<Opportunity>> getFavorites(String userId) async {
    final ids = await getFavoriteOpportunityIds(userId);
    return opportunities.where((o) => ids.contains(o.id)).toList();
  }

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
