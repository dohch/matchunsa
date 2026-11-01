import 'package:flutter/material.dart';
import 'package:matchunsa/app/theme/app_theme.dart';
import 'package:matchunsa/app/widgets/mu_motion.dart';
import 'package:matchunsa/app/widgets/mu_surface.dart';
import 'package:matchunsa/features/applications/domain/application_repository.dart';
import 'package:matchunsa/features/applications/domain/job_application.dart';
import 'package:matchunsa/features/applications/presentation/widgets/application_dialog.dart';
import 'package:matchunsa/features/opportunities/domain/opportunity.dart';
import 'package:matchunsa/features/opportunities/domain/opportunity_repository.dart';
import 'package:matchunsa/features/opportunities/presentation/widgets/report_opportunity_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

class OpportunityDetailPage extends StatefulWidget {
  const OpportunityDetailPage({
    super.key,
    required this.opportunity,
    this.userId,
    this.isFavorite = false,
    this.onToggleFavorite,
    this.opportunityRepository,
    this.applicationRepository,
  });

  final Opportunity opportunity;
  final String? userId;
  final bool isFavorite;
  final Future<bool> Function()? onToggleFavorite;
  final OpportunityRepository? opportunityRepository;
  final ApplicationRepository? applicationRepository;

  @override
  State<OpportunityDetailPage> createState() => _OpportunityDetailPageState();
}

class _OpportunityDetailPageState extends State<OpportunityDetailPage> {
  late bool _isFavorite;
  JobApplication? _application;
  bool _isLoadingApplication = false;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.isFavorite;
    _loadApplication();
  }

  Future<void> _loadApplication() async {
    final uid = widget.userId;
    final repo = widget.applicationRepository;
    if (uid == null || repo == null) return;

    setState(() => _isLoadingApplication = true);
    try {
      final app = await repo.getApplicationForOpportunity(
        userId: uid,
        opportunityId: widget.opportunity.id,
      );
      if (!mounted) return;
      setState(() {
        _application = app;
        _isLoadingApplication = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingApplication = false);
    }
  }

  Future<void> _toggleFavorite() async {
    final previous = _isFavorite;
    setState(() => _isFavorite = !_isFavorite);
    final callback = widget.onToggleFavorite;
    if (callback == null) return;
    final saved = await callback();
    if (!saved && mounted) {
      setState(() => _isFavorite = previous);
    }
  }

  void _openApplicationDialog() {
    final uid = widget.userId;
    final repo = widget.applicationRepository;
    if (uid == null || repo == null) return;

    ApplicationDialog.show(
      context: context,
      userId: uid,
      opportunity: widget.opportunity,
      existingApplication: _application,
      onSave: (app) async {
        await repo.saveApplication(app);
        await _loadApplication();
      },
      onDelete: (id) async {
        await repo.deleteApplication(id);
        if (mounted) setState(() => _application = null);
      },
    );
  }

  void _openReportDialog() {
    final uid = widget.userId;
    final repo = widget.opportunityRepository;
    if (uid == null || repo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inicia sesión para reportar una incidencia.'),
        ),
      );
      return;
    }

    ReportOpportunityDialog.show(
      context: context,
      userId: uid,
      opportunity: widget.opportunity,
      repository: repo,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        title: const Text('Convocatoria laboral'),
        actions: [
          if (widget.onToggleFavorite != null)
            MuFavoriteButton(
              isFavorite: _isFavorite,
              onPressed: () async {
                await _toggleFavorite();
                return true;
              },
            ),
          if (widget.opportunityRepository != null && widget.userId != null)
            IconButton(
              tooltip: 'Reportar incidencia',
              onPressed: _openReportDialog,
              icon: const Icon(Icons.flag_outlined),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
            children: [
              _hero(context),
              if (widget.applicationRepository != null &&
                  widget.userId != null) ...[
                const SizedBox(height: 16),
                _applicationStatusBanner(context),
              ],
              if (widget.opportunity.careers.isNotEmpty)
                _section(
                  context,
                  'Formación profesional',
                  widget.opportunity.careers
                      .map((career) => career.displayName)
                      .join('\n'),
                  icon: Icons.school_outlined,
                ),
              if (_clean(widget.opportunity.academicProfile) case final value?)
                _section(context, 'Perfil académico', value,
                    icon: Icons.badge_outlined),
              if (_clean(widget.opportunity.location) case final value?)
                _section(context, 'Lugar', value,
                    icon: Icons.location_on_outlined),
              if (widget.opportunity.closingDate case final date?)
                _section(context, 'Fecha de cierre', _formatDate(date),
                    icon: Icons.event_outlined),
              if (widget.opportunity.vacancies case final vacancies?)
                _section(context, 'Vacantes', '$vacancies',
                    icon: Icons.groups_2_outlined),
              if (_clean(widget.opportunity.requirements) case final value?)
                _section(context, 'Requisitos', value,
                    icon: Icons.checklist_rounded),
              if (_clean(widget.opportunity.desiredKnowledge) case final value?)
                _section(context, 'Conocimientos deseables', value,
                    icon: Icons.lightbulb_outline_rounded),
              if (_clean(widget.opportunity.functions) case final value?)
                _section(context, 'Funciones', value,
                    icon: Icons.work_outline_rounded),
              if (_clean(widget.opportunity.additionalInformation)
                  case final value?)
                _section(context, 'Información adicional', value,
                    icon: Icons.info_outline_rounded),
              if (_clean(widget.opportunity.applicationUrl) case final value?)
                _applicationLink(context, value),
              if (_clean(widget.opportunity.applicationEmail) case final value?)
                _section(context, 'Correo de postulación', value,
                    icon: Icons.mail_outline_rounded),
              if (_clean(widget.opportunity.applicationPhone) case final value?)
                _section(context, 'Teléfono de contacto', value,
                    icon: Icons.phone_outlined),
              if (_clean(widget.opportunity.cvType) case final value?)
                _section(context, 'Tipo de CV solicitado', value,
                    icon: Icons.description_outlined),
              _section(
                context,
                'Contenido original de la convocatoria',
                widget.opportunity.originalContent,
                icon: Icons.article_outlined,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _applicationStatusBanner(BuildContext context) {
    final app = _application;
    final statusColor = app?.status.color ?? AppTheme.navy;

    return MuSurface(
      color: app == null
          ? Colors.white
          : statusColor.withValues(alpha: 0.04),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              app?.status.icon ?? Icons.assignment_outlined,
              color: statusColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  app == null
                      ? 'Seguimiento de postulación'
                      : 'Estado: ${app.status.label}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: statusColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  app == null
                      ? '¿Postulaste a esta convocatoria? Registra tu estado para darle seguimiento.'
                      : (app.notes != null && app.notes!.isNotEmpty
                          ? 'Nota: ${app.notes}'
                          : 'Puedes actualizar el estado conforme avance el proceso.'),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (_isLoadingApplication)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            FilledButton.tonal(
              onPressed: _openApplicationDialog,
              child: Text(
                app == null ? 'Registrar' : 'Actualizar',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  Widget _hero(BuildContext context) {
    final company = _clean(widget.opportunity.company);
    final title = _clean(widget.opportunity.title);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.softShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.22)),
                  ),
                  child: Center(
                    child: Text(
                      (company ?? 'M').substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 22),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    company ?? 'Convocatoria laboral',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                const Icon(Icons.verified_outlined, color: Colors.white70),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              title ?? 'Oportunidad laboral',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 15),
            Wrap(
              spacing: 9,
              runSpacing: 9,
              children: [
                if (_clean(widget.opportunity.academicProfile)
                    case final value?)
                  _detailPill(context, Icons.school_outlined, value),
                if (_clean(widget.opportunity.location) case final value?)
                  _detailPill(context, Icons.location_on_outlined, value),
                if (widget.opportunity.closingDate case final date?)
                  _detailPill(context, Icons.event_outlined, _formatDate(date)),
                if (widget.opportunity.vacancies case final count?)
                  _detailPill(
                      context, Icons.groups_2_outlined, '$count vacantes'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailPill(BuildContext context, IconData icon, String label) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Widget _applicationLink(BuildContext context, String value) {
    final uri = Uri.tryParse(value);
    final canOpen = uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: MuSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const MuIconBadge(icon: Icons.link_rounded, size: 40),
                const SizedBox(width: 12),
                Text('Enlace oficial de postulación',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            SelectableText(value),
            const SizedBox(height: 8),
            const Text(
              'Nota de transparencia: Este enlace te llevará al sitio web externo oficial de la entidad convocante para realizar tu postulación.',
              style: TextStyle(fontSize: 12, color: AppTheme.gray),
            ),
            if (canOpen) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () async {
                  final opened = await launchUrl(uri);
                  if (!opened && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('No se pudo abrir el enlace de postulación.'),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.open_in_new),
                label: const Text('Abrir portal de postulación'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String? _clean(String? value) {
  final result = value?.trim();
  return result == null || result.isEmpty ? null : result;
}

Widget _section(BuildContext context, String title, String body,
        {IconData? icon}) =>
    Padding(
      padding: const EdgeInsets.only(top: 16),
      child: MuSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: AppTheme.maroon),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(title,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SelectableText(body, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
