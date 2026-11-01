import 'package:flutter/material.dart';
import 'package:matchunsa/app/theme/app_theme.dart';
import 'package:matchunsa/app/widgets/mu_components.dart';
import 'package:matchunsa/app/widgets/mu_empty_state.dart';
import 'package:matchunsa/app/widgets/mu_motion.dart';
import 'package:matchunsa/app/widgets/mu_surface.dart';
import 'package:matchunsa/features/applications/domain/application_repository.dart';
import 'package:matchunsa/features/applications/domain/job_application.dart';
import 'package:matchunsa/features/applications/domain/job_application_status.dart';
import 'package:matchunsa/features/applications/presentation/widgets/application_dialog.dart';
import 'package:matchunsa/features/opportunities/presentation/opportunity_detail_page.dart';

class ApplicationsPage extends StatefulWidget {
  const ApplicationsPage({
    super.key,
    required this.userId,
    required this.repository,
    this.showAppBar = false,
  });

  final String userId;
  final ApplicationRepository repository;
  final bool showAppBar;

  @override
  State<ApplicationsPage> createState() => _ApplicationsPageState();
}

class _ApplicationsPageState extends State<ApplicationsPage> {
  List<JobApplication> _applications = const [];
  bool _isLoading = true;
  String? _error;
  JobApplicationStatus? _filterStatus;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final list = await widget.repository.getApplications(widget.userId);
      if (!mounted) return;
      setState(() {
        _applications = list;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar tus postulaciones. Inténtalo nuevamente.';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveApplication(JobApplication app) async {
    await widget.repository.saveApplication(app);
    await _load();
  }

  Future<void> _deleteApplication(String id) async {
    await widget.repository.deleteApplication(id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: widget.showAppBar
          ? AppBar(title: const Text('Mis postulaciones'))
          : null,
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

    final filtered = _filterStatus == null
        ? _applications
        : _applications.where((a) => a.status == _filterStatus).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 940),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 40),
            children: [
              _heading(),
              const SizedBox(height: 16),
              _statusChips(),
              const SizedBox(height: 16),
              if (filtered.isEmpty)
                _emptyState()
              else
                ...filtered.asMap().entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: MuStaggeredEntrance(
                      index: entry.key,
                      child: _ApplicationCard(
                        application: entry.value,
                        onEdit: () => ApplicationDialog.show(
                          context: context,
                          userId: widget.userId,
                          opportunity: entry.value.opportunity!,
                          existingApplication: entry.value,
                          onSave: _saveApplication,
                          onDelete: _deleteApplication,
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heading() {
    return MuSurface(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          const MuIconBadge(
            icon: Icons.fact_check_outlined,
            size: 52,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Seguimiento de postulaciones',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Lleva el control de tus oportunidades: actualiza estados y guarda notas de cada postulación.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            label: Text('Todas (${_applications.length})'),
            selected: _filterStatus == null,
            onSelected: (selected) {
              if (selected) setState(() => _filterStatus = null);
            },
          ),
          const SizedBox(width: 8),
          ...JobApplicationStatus.values.map((status) {
            final count =
                _applications.where((a) => a.status == status).length;
            final isSelected = _filterStatus == status;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                avatar: Icon(status.icon,
                    size: 14,
                    color: isSelected ? Colors.white : status.color),
                label: Text('${status.label} ($count)'),
                selected: isSelected,
                selectedColor: status.color,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.navy,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (selected) {
                  setState(() => _filterStatus = selected ? status : null);
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return MuEmptyState(
      icon: Icons.assignment_late_outlined,
      title: _filterStatus == null
          ? 'Sin postulaciones aún'
          : 'Sin postulaciones con ese estado',
      message: _filterStatus == null
          ? 'Aún no has registrado ninguna postulación. Encuentra convocatorias en Inicio y pulsa "Registrar postulación".'
          : 'No tienes postulaciones con estado "${_filterStatus!.label}".',
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({
    required this.application,
    required this.onEdit,
  });

  final JobApplication application;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final opp = application.opportunity;
    final title = opp?.title ?? 'Convocatoria';
    final company = opp?.company ?? 'Entidad convocante';
    final status = application.status;

    return MuScaleTap(
      onTap: () {
        if (opp != null) {
          Navigator.of(context).push<void>(
            MuPageTransition(
              page: OpportunityDetailPage(opportunity: opp),
            ),
          );
        }
      },
      child: MuSurface(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.navy.withValues(alpha: 0.12),
                        AppTheme.navy.withValues(alpha: 0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Center(
                    child: Text(
                      company.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: AppTheme.navy,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(company,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                MuStatusChip(
                  label: status.label,
                  color: status.color,
                  icon: status.icon,
                ),
              ],
            ),
            if (application.notes != null &&
                application.notes!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.canvas,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.sticky_note_2_outlined,
                        size: 16, color: AppTheme.gray),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        application.notes!,
                        style: const TextStyle(
                            fontSize: 13, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (application.updatedAt != null)
                  Text(
                    'Actualizado: ${_formatDate(application.updatedAt!)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                else
                  const SizedBox.shrink(),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Cambiar estado / notas'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}
