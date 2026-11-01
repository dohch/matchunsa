import 'package:flutter/material.dart';
import 'package:matchunsa/app/theme/app_theme.dart';
import 'package:matchunsa/app/widgets/mu_empty_state.dart';
import 'package:matchunsa/app/widgets/mu_motion.dart';
import 'package:matchunsa/features/applications/domain/application_repository.dart';
import 'package:matchunsa/features/opportunities/domain/opportunity.dart';
import 'package:matchunsa/features/opportunities/domain/opportunity_filter.dart';
import 'package:matchunsa/features/opportunities/domain/opportunity_repository.dart';
import 'package:matchunsa/features/opportunities/presentation/widgets/opportunity_card.dart';
import 'package:matchunsa/features/opportunities/presentation/widgets/opportunity_filter_sheet.dart';

class OpportunityListPage extends StatefulWidget {
  const OpportunityListPage({
    super.key,
    required this.repository,
    this.userId,
    this.applicationRepository,
    this.searchQuery = '',
    this.showAppBar = true,
    this.onlyFavorites = false,
    this.pageTitle,
    this.reloadToken = 0,
  });

  final OpportunityRepository repository;
  final String? userId;
  final ApplicationRepository? applicationRepository;
  final String searchQuery;
  final bool showAppBar;
  final bool onlyFavorites;
  final String? pageTitle;

  /// Bumped by the parent shell when this page should reload favorites.
  final int reloadToken;

  @override
  State<OpportunityListPage> createState() => _OpportunityListPageState();
}

class _OpportunityListPageState extends State<OpportunityListPage> {
  List<Opportunity> _opportunities = const [];
  Set<String> _favoriteIds = {};
  bool _isLoading = true;
  String? _error;
  OpportunityFilter _filter = const OpportunityFilter();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(OpportunityListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reloadToken != oldWidget.reloadToken ||
        widget.userId != oldWidget.userId ||
        widget.onlyFavorites != oldWidget.onlyFavorites) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final uid = widget.userId;
      Set<String> favs = {};
      if (uid != null) {
        // Do not swallow favorite load errors: a silent failure leaves the UI
        // unmarked even when rows exist in opportunity_favorites.
        final favList = await widget.repository.getFavoriteOpportunityIds(uid);
        favs = favList.toSet();
      }

      final opportunities = await widget.repository.getOpportunities();
      if (!mounted) return;
      setState(() {
        _favoriteIds = favs;
        _opportunities = widget.onlyFavorites
            ? opportunities.where((o) => favs.contains(o.id)).toList()
            : opportunities;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error =
            'No se pudieron cargar las oportunidades. Inténtalo nuevamente.';
        _isLoading = false;
      });
    }
  }

  Future<bool> _toggleFavorite(Opportunity opp) async {
    final uid = widget.userId;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inicia sesión para guardar favoritos.')),
      );
      return false;
    }

    final isFav = _favoriteIds.contains(opp.id);
    setState(() {
      if (isFav) {
        _favoriteIds.remove(opp.id);
        if (widget.onlyFavorites) {
          _opportunities =
              _opportunities.where((o) => o.id != opp.id).toList();
        }
      } else {
        _favoriteIds.add(opp.id);
      }
    });

    try {
      if (isFav) {
        await widget.repository.removeFavorite(
          userId: uid,
          opportunityId: opp.id,
        );
      } else {
        await widget.repository.addFavorite(
          userId: uid,
          opportunityId: opp.id,
        );
      }
      return true;
    } catch (_) {
      if (!mounted) return false;
      // Revert on error
      setState(() {
        if (isFav) {
          _favoriteIds.add(opp.id);
          if (widget.onlyFavorites &&
              !_opportunities.any((o) => o.id == opp.id)) {
            _opportunities = [..._opportunities, opp];
          }
        } else {
          _favoriteIds.remove(opp.id);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo actualizar el favorito.'),
        ),
      );
      return false;
    }
  }

  void _openFilterSheet() {
    OpportunityFilterSheet.show(
      context: context,
      currentFilter: _filter,
      onApply: (newFilter) {
        setState(() => _filter = newFilter);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.pageTitle ??
        (widget.onlyFavorites
            ? 'Convocatorias favoritas'
            : 'Oportunidades laborales');

    return Scaffold(
      appBar: widget.showAppBar ? AppBar(title: Text(title)) : null,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const MuLoading();
    }
    if (_error case final error?) {
      return MuErrorState(message: error, onRetry: _load);
    }

    final query = widget.searchQuery.trim().toLowerCase();
    final visibleOpportunities = _opportunities.where((opportunity) {
      // 1. Text search query
      if (query.isNotEmpty) {
        final searchable = [
          opportunity.title,
          opportunity.company,
          opportunity.academicProfile,
          opportunity.location,
          opportunity.requirements,
          ...opportunity.careers.map((career) => career.displayName),
        ].whereType<String>().join(' ').toLowerCase();
        if (!searchable.contains(query)) return false;
      }

      // 2. Advanced filters
      if (!_filter.matches(opportunity)) return false;

      return true;
    }).toList(growable: false);

    return RefreshIndicator(
      onRefresh: _load,
      child: Column(
        children: [
          if (!widget.showAppBar) _pageHeading(context),
          if (_filter.activeFiltersCount > 0) _activeFilterChips(),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 940),
                child: visibleOpportunities.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(24),
                        children: [
                          const SizedBox(height: 60),
                          MuEmptyState(
                            icon: widget.onlyFavorites
                                ? Icons.favorite_border_rounded
                                : Icons.search_off_rounded,
                            title: widget.onlyFavorites
                                ? 'Aún no tienes favoritas'
                                : 'Sin resultados',
                            message: widget.onlyFavorites
                                ? 'No tienes convocatorias guardadas como favoritas.'
                                : (_filter.activeFiltersCount > 0 ||
                                        query.isNotEmpty
                                    ? 'No encontramos convocatorias con los filtros aplicados.'
                                    : 'No hay oportunidades disponibles por el momento.'),
                            action: _filter.activeFiltersCount > 0
                                ? FilledButton.tonalIcon(
                                    onPressed: () => setState(
                                        () => _filter = const OpportunityFilter()),
                                    icon: const Icon(Icons.clear_all_rounded),
                                    label: const Text('Limpiar filtros'),
                                  )
                                : null,
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
                        itemCount: visibleOpportunities.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final opp = visibleOpportunities[index];
                          final isFav = _favoriteIds.contains(opp.id);
                          return MuStaggeredEntrance(
                            index: index,
                            child: OpportunityCard(
                              opportunity: opp,
                              userId: widget.userId,
                              isFavorite: isFav,
                              onToggleFavorite: () => _toggleFavorite(opp),
                              opportunityRepository: widget.repository,
                              applicationRepository:
                                  widget.applicationRepository,
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pageHeading(BuildContext context) {
    final title = widget.pageTitle ??
        (widget.onlyFavorites
            ? 'Convocatorias favoritas'
            : 'Oportunidades laborales');
    final subtitle = widget.onlyFavorites
        ? 'Tus oportunidades guardadas para postular o consultar más tarde.'
        : 'Explora convocatorias recibidas de canales oficiales UNSA.';

    final count = _filter.activeFiltersCount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 3),
                Text(subtitle),
              ],
            ),
          ),
          if (!widget.onlyFavorites) ...[
            const SizedBox(width: 10),
            Badge(
              isLabelVisible: count > 0,
              label: Text('$count'),
              child: FilledButton.tonalIcon(
                onPressed: _openFilterSheet,
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: const Text('Filtros'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _activeFilterChips() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Text(
              'Filtros:',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.gray),
            ),
            const SizedBox(width: 8),
            if (_filter.titleQuery != null)
              _chip('Puesto: ${_filter.titleQuery}', () {
                setState(() => _filter = _filter.copyWith(clearTitleQuery: true));
              }),
            if (_filter.companyQuery != null)
              _chip('Empresa: ${_filter.companyQuery}', () {
                setState(
                    () => _filter = _filter.copyWith(clearCompanyQuery: true));
              }),
            if (_filter.career != null)
              _chip('Carrera: ${_filter.career}', () {
                setState(() => _filter = _filter.copyWith(clearCareer: true));
              }),
            if (_filter.locationQuery != null)
              _chip('Lugar: ${_filter.locationQuery}', () {
                setState(
                    () => _filter = _filter.copyWith(clearLocationQuery: true));
              }),
            if (_filter.type != OpportunityTypeFilter.all)
              _chip(
                  _filter.type == OpportunityTypeFilter.laboral
                      ? 'Laboral'
                      : 'Prácticas', () {
                setState(
                    () => _filter = _filter.copyWith(type: OpportunityTypeFilter.all));
              }),
            if (_filter.validity != OpportunityValidityFilter.activeOnly)
              _chip(
                  _filter.validity == OpportunityValidityFilter.expiredOnly
                      ? 'Vencidas'
                      : 'Todas (vigentes y vencidas)', () {
                setState(() => _filter =
                    _filter.copyWith(validity: OpportunityValidityFilter.activeOnly));
              }),
            if (_filter.closingDateStart != null ||
                _filter.closingDateEnd != null)
              _chip('Rango de fecha', () {
                setState(
                    () => _filter = _filter.copyWith(clearClosingDates: true));
              }),
            TextButton(
              onPressed: () =>
                  setState(() => _filter = const OpportunityFilter()),
              child: const Text('Limpiar todos', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, VoidCallback onDeleted) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InputChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        onDeleted: onDeleted,
        deleteIconColor: AppTheme.maroon,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
