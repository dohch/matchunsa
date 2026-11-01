import 'package:flutter/material.dart';
import 'package:matchunsa/app/theme/app_theme.dart';
import 'package:matchunsa/app/widgets/mu_components.dart';
import 'package:matchunsa/features/admin/presentation/admin_panel_page.dart';
import 'package:matchunsa/features/applications/domain/application_repository.dart';
import 'package:matchunsa/features/applications/presentation/applications_page.dart';
import 'package:matchunsa/features/auth/domain/auth_user.dart';
import 'package:matchunsa/features/notifications/domain/notification_repository.dart';
import 'package:matchunsa/features/notifications/presentation/notifications_sheet.dart';
import 'package:matchunsa/features/opportunities/domain/opportunity_repository.dart';
import 'package:matchunsa/features/opportunities/presentation/opportunity_list_page.dart';
import 'package:matchunsa/features/profile/domain/profile_repository.dart';
import 'package:matchunsa/features/profile/presentation/professional_profile_page.dart';

class AuthenticatedShell extends StatefulWidget {
  const AuthenticatedShell({
    super.key,
    required this.user,
    required this.profileRepository,
    required this.opportunityRepository,
    required this.applicationRepository,
    required this.notificationRepository,
    required this.onSignOut,
  });

  final AuthUser user;
  final ProfileRepository profileRepository;
  final OpportunityRepository opportunityRepository;
  final ApplicationRepository applicationRepository;
  final NotificationRepository notificationRepository;
  final Future<void> Function() onSignOut;

  @override
  State<AuthenticatedShell> createState() => _AuthenticatedShellState();
}

class _AuthenticatedShellState extends State<AuthenticatedShell> {
  static const _opportunitiesIndex = 0;
  static const _favoritesIndex = 1;
  static const _applicationsIndex = 2;
  static const _profileIndex = 3;
  static const _adminIndex = 4;

  final _searchController = TextEditingController();
  int _selectedIndex = _opportunitiesIndex;
  bool _isAdmin = false;
  int _unreadNotifications = 0;
  /// Forces opportunity/favorites lists to reload when switching tabs so
  /// favorite hearts stay in sync across the IndexedStack pages.
  int _opportunityListsReloadToken = 0;

  @override
  void initState() {
    super.initState();
    _checkAdminAndNotifications();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkAdminAndNotifications() async {
    try {
      final isAdmin =
          await widget.opportunityRepository.isUserAdmin(widget.user.id);
      final notifications =
          await widget.notificationRepository.getNotifications(widget.user.id);
      final unread = notifications.where((n) => !n.isRead).length;

      if (!mounted) return;
      setState(() {
        _isAdmin = isAdmin;
        _unreadNotifications = unread;
      });
    } catch (_) {}
  }

  void _select(int index) {
    setState(() {
      if (index == _opportunitiesIndex || index == _favoritesIndex) {
        _opportunityListsReloadToken++;
      }
      _selectedIndex = index;
    });
  }

  Future<void> _signOut() async {
    try {
      await widget.onSignOut();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo cerrar la sesión.')),
      );
    }
  }

  Future<void> _showMobileSearch() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Buscar oportunidades'),
        content: TextField(
          controller: _searchController,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: 'Puesto, empresa o carrera',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Listo'),
          ),
        ],
      ),
    );
  }

  Future<void> _showNotifications() async {
    await NotificationsSheet.show(
      context: context,
      userId: widget.user.id,
      notificationRepository: widget.notificationRepository,
      opportunityRepository: widget.opportunityRepository,
    );
    _checkAdminAndNotifications();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      OpportunityListPage(
        repository: widget.opportunityRepository,
        userId: widget.user.id,
        applicationRepository: widget.applicationRepository,
        searchQuery: _searchController.text,
        showAppBar: false,
        reloadToken: _opportunityListsReloadToken,
      ),
      OpportunityListPage(
        repository: widget.opportunityRepository,
        userId: widget.user.id,
        applicationRepository: widget.applicationRepository,
        searchQuery: _searchController.text,
        showAppBar: false,
        onlyFavorites: true,
        reloadToken: _opportunityListsReloadToken,
      ),
      ApplicationsPage(
        userId: widget.user.id,
        repository: widget.applicationRepository,
        showAppBar: false,
      ),
      ProfessionalProfilePage(
        user: widget.user,
        repository: widget.profileRepository,
        onSignOut: widget.onSignOut,
        showAppBar: false,
      ),
      if (_isAdmin)
        AdminPanelPage(
          user: widget.user,
          repository: widget.opportunityRepository,
          showAppBar: false,
        ),
    ];

    final effectiveIndex =
        _selectedIndex >= pages.length ? _opportunitiesIndex : _selectedIndex;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final wide = constraints.maxWidth >= 1160;
          final showInfoRail = constraints.maxWidth >= 1440;

          return Column(
            children: [
              _TopBar(
                user: widget.user,
                searchController: _searchController,
                compact: compact,
                unreadNotifications: _unreadNotifications,
                isAdmin: _isAdmin,
                onSearchChanged: (_) => setState(() {}),
                onMobileSearch: _showMobileSearch,
                onNotifications: _showNotifications,
                onSelectIndex: _select,
                onSignOut: _signOut,
              ),
              Expanded(
                child: Row(
                  children: [
                    if (!compact)
                      _SideNavigation(
                        user: widget.user,
                        selectedIndex: effectiveIndex,
                        expanded: wide,
                        isAdmin: _isAdmin,
                        onSelect: _select,
                        onSignOut: _signOut,
                      ),
                    Expanded(
                      child: ColoredBox(
                        color: AppTheme.canvas,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 960),
                            child: IndexedStack(
                              index: effectiveIndex,
                              children: pages,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (showInfoRail && effectiveIndex == _opportunitiesIndex)
                      _InfoRail(
                        user: widget.user,
                        isAdmin: _isAdmin,
                        onOpenProfile: () => _select(_profileIndex),
                        onOpenFavorites: () => _select(_favoritesIndex),
                        onOpenApplications: () => _select(_applicationsIndex),
                        onOpenAdmin: () => _select(_adminIndex),
                      ),
                  ],
                ),
              ),
              if (compact)
                NavigationBar(
                  selectedIndex: effectiveIndex,
                  onDestinationSelected: _select,
                  destinations: [
                    const NavigationDestination(
                      icon: Icon(Icons.work_outline_rounded),
                      selectedIcon: Icon(Icons.work_rounded),
                      label: 'Inicio',
                    ),
                    const NavigationDestination(
                      icon: Icon(Icons.favorite_border_rounded),
                      selectedIcon: Icon(Icons.favorite_rounded),
                      label: 'Favoritos',
                    ),
                    const NavigationDestination(
                      icon: Icon(Icons.fact_check_outlined),
                      selectedIcon: Icon(Icons.fact_check_rounded),
                      label: 'Postulaciones',
                    ),
                    const NavigationDestination(
                      icon: Icon(Icons.person_outline_rounded),
                      selectedIcon: Icon(Icons.person_rounded),
                      label: 'Mi perfil',
                    ),
                    if (_isAdmin)
                      const NavigationDestination(
                        icon: Icon(Icons.shield_outlined),
                        selectedIcon: Icon(Icons.shield_rounded),
                        label: 'Admin',
                      ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.user,
    required this.searchController,
    required this.compact,
    required this.unreadNotifications,
    required this.isAdmin,
    required this.onSearchChanged,
    required this.onMobileSearch,
    required this.onNotifications,
    required this.onSelectIndex,
    required this.onSignOut,
  });

  final AuthUser user;
  final TextEditingController searchController;
  final bool compact;
  final int unreadNotifications;
  final bool isAdmin;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onMobileSearch;
  final VoidCallback onNotifications;
  final ValueChanged<int> onSelectIndex;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.94),
      elevation: 0,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppTheme.hairline)),
        ),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 68,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 24),
              child: Row(
                children: [
                  _Brand(compact: compact),
                  if (!compact) ...[
                    const SizedBox(width: 34),
                    Expanded(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: MuSearchField(
                          controller: searchController,
                          onChanged: onSearchChanged,
                          hintText: 'Buscar puestos, empresas o carreras',
                        ),
                      ),
                    ),
                  ],
                const Spacer(),
                if (compact)
                  IconButton(
                    tooltip: 'Buscar',
                    onPressed: onMobileSearch,
                    icon: const Icon(Icons.search_rounded),
                  ),
                Badge(
                  isLabelVisible: unreadNotifications > 0,
                  label: Text('$unreadNotifications'),
                  child: IconButton.filledTonal(
                    tooltip: 'Notificaciones',
                    onPressed: onNotifications,
                    icon: const Icon(Icons.notifications_none_rounded),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  tooltip: 'Cuenta y navegación',
                  onSelected: (value) {
                    if (value == 'profile') onSelectIndex(3);
                    if (value == 'favorites') onSelectIndex(1);
                    if (value == 'applications') onSelectIndex(2);
                    if (value == 'admin') onSelectIndex(4);
                    if (value == 'signout') onSignOut();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'profile',
                      child: ListTile(
                        leading: Icon(Icons.person_outline_rounded),
                        title: Text('Perfil profesional'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'favorites',
                      child: ListTile(
                        leading: Icon(Icons.favorite_outline_rounded),
                        title: Text('Convocatorias favoritas'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'applications',
                      child: ListTile(
                        leading: Icon(Icons.fact_check_outlined),
                        title: Text('Mis postulaciones'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    if (isAdmin)
                      const PopupMenuItem(
                        value: 'admin',
                        child: ListTile(
                          leading: Icon(Icons.shield_outlined,
                              color: AppTheme.maroon),
                          title: Text('Panel administrativo',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'signout',
                      child: ListTile(
                        leading: Icon(Icons.logout_rounded),
                        title: Text('Cerrar sesión'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTheme.maroon.withValues(alpha: .1),
                    child: Text(
                      _initials(user.email),
                      style: const TextStyle(
                        color: AppTheme.maroon,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppTheme.maroon,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.workspaces_rounded, color: Colors.white),
        ),
        if (!compact) ...[
          const SizedBox(width: 10),
          RichText(
            text: const TextSpan(
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              children: [
                TextSpan(text: 'Match', style: TextStyle(color: AppTheme.navy)),
                TextSpan(
                    text: 'UNSA', style: TextStyle(color: AppTheme.maroon)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _SideNavigation extends StatelessWidget {
  const _SideNavigation({
    required this.user,
    required this.selectedIndex,
    required this.expanded,
    required this.isAdmin,
    required this.onSelect,
    required this.onSignOut,
  });

  final AuthUser user;
  final int selectedIndex;
  final bool expanded;
  final bool isAdmin;
  final ValueChanged<int> onSelect;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: expanded ? 248 : 84,
      color: AppTheme.canvas,
      padding:
          EdgeInsets.fromLTRB(expanded ? 18 : 10, 20, expanded ? 18 : 10, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (expanded) ...[
            _AccountSummary(user: user),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.only(left: 12, bottom: 8),
              child: Text(
                'NAVEGACIÓN',
                style: TextStyle(
                  color: AppTheme.gray,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
          _NavItem(
            icon: Icons.work_outline_rounded,
            selectedIcon: Icons.work_rounded,
            label: 'Inicio',
            selected: selectedIndex == 0,
            expanded: expanded,
            onTap: () => onSelect(0),
          ),
          const SizedBox(height: 6),
          _NavItem(
            icon: Icons.favorite_border_rounded,
            selectedIcon: Icons.favorite_rounded,
            label: 'Favoritos',
            selected: selectedIndex == 1,
            expanded: expanded,
            onTap: () => onSelect(1),
          ),
          const SizedBox(height: 6),
          _NavItem(
            icon: Icons.fact_check_outlined,
            selectedIcon: Icons.fact_check_rounded,
            label: 'Mis postulaciones',
            selected: selectedIndex == 2,
            expanded: expanded,
            onTap: () => onSelect(2),
          ),
          const SizedBox(height: 6),
          _NavItem(
            icon: Icons.person_outline_rounded,
            selectedIcon: Icons.person_rounded,
            label: 'Perfil profesional',
            selected: selectedIndex == 3,
            expanded: expanded,
            onTap: () => onSelect(3),
          ),
          if (isAdmin) ...[
            const SizedBox(height: 6),
            _NavItem(
              icon: Icons.shield_outlined,
              selectedIcon: Icons.shield_rounded,
              label: 'Panel admin',
              selected: selectedIndex == 4,
              expanded: expanded,
              onTap: () => onSelect(4),
            ),
          ],
          const Spacer(),
          if (expanded)
            TextButton.icon(
              onPressed: onSignOut,
              icon: const Icon(Icons.logout_rounded, size: 19),
              label: const Text('Cerrar sesión'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.navy,
                alignment: Alignment.centerLeft,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.expanded,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppTheme.maroon : AppTheme.navy;
    return Tooltip(
      message: expanded ? '' : label,
      child: Material(
        color: selected
            ? AppTheme.maroon.withValues(alpha: .09)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: expanded ? 14 : 0, vertical: 12),
            child: Row(
              mainAxisAlignment:
                  expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                Icon(selected ? selectedIcon : icon, color: foreground),
                if (expanded) ...[
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: foreground,
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountSummary extends StatelessWidget {
  const _AccountSummary({required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.navy.withValues(alpha: .1),
              foregroundColor: AppTheme.navy,
              child: Text(_initials(user.email)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                user.email,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.navy,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRail extends StatelessWidget {
  const _InfoRail({
    required this.user,
    required this.isAdmin,
    required this.onOpenProfile,
    required this.onOpenFavorites,
    required this.onOpenApplications,
    required this.onOpenAdmin,
  });

  final AuthUser user;
  final bool isAdmin;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenFavorites;
  final VoidCallback onOpenApplications;
  final VoidCallback onOpenAdmin;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 24, 22, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Tu espacio MatchUNSA',
              style: TextStyle(
                color: AppTheme.navy,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppTheme.maroon.withValues(alpha: .09),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(Icons.campaign_outlined,
                          color: AppTheme.maroon),
                    ),
                    const SizedBox(height: 14),
                    const Text('Convocatorias de UDEEG',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, color: AppTheme.navy)),
                    const SizedBox(height: 6),
                    const Text(
                      'Consulta oportunidades laborales recibidas desde los canales institucionales de la UNSA.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.bookmark_border_rounded,
                        color: AppTheme.maroon),
                    const SizedBox(height: 12),
                    const Text('Convocatorias guardadas',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, color: AppTheme.navy)),
                    const SizedBox(height: 6),
                    const Text(
                      'Revisa tus favoritas y postúlate a las mejores oportunidades.',
                    ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: onOpenFavorites,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: const Text('Ver favoritas'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.assignment_turned_in_outlined,
                        color: AppTheme.navy),
                    const SizedBox(height: 12),
                    const Text('Tus postulaciones',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, color: AppTheme.navy)),
                    const SizedBox(height: 6),
                    const Text(
                      'Lleva el registro del estado de cada postulación.',
                    ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: onOpenApplications,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: const Text('Ver postulaciones'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.person_search_outlined,
                        color: AppTheme.navy),
                    const SizedBox(height: 12),
                    const Text('Completa tu perfil',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, color: AppTheme.navy)),
                    const SizedBox(height: 6),
                    Text(user.email,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: onOpenProfile,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: const Text('Ver perfil profesional'),
                    ),
                  ],
                ),
              ),
            ),
            if (isAdmin) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.shield_outlined,
                          color: AppTheme.maroon),
                      const SizedBox(height: 12),
                      const Text('Gestión Administrativa',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppTheme.navy)),
                      const SizedBox(height: 6),
                      const Text(
                        'Modera convocatorias, revisa incidencias y correos de origen.',
                      ),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: onOpenAdmin,
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: const Text('Abrir panel admin'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _initials(String email) {
  final name = email.split('@').first.replaceAll(RegExp(r'[._-]+'), ' ').trim();
  final parts = name.split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
  final initials = parts.take(2).map((part) => part[0].toUpperCase()).join();
  return initials.isEmpty ? 'U' : initials;
}
