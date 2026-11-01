import 'package:flutter/material.dart';
import 'package:matchunsa/app/theme/app_theme.dart';
import 'package:matchunsa/features/applications/domain/job_application.dart';
import 'package:matchunsa/features/applications/domain/job_application_status.dart';
import 'package:matchunsa/features/opportunities/domain/opportunity.dart';
import 'package:url_launcher/url_launcher.dart';

class ApplicationDialog extends StatefulWidget {
  const ApplicationDialog({
    super.key,
    required this.userId,
    required this.opportunity,
    this.existingApplication,
    required this.onSave,
    this.onDelete,
  });

  final String userId;
  final Opportunity opportunity;
  final JobApplication? existingApplication;
  final Future<void> Function(JobApplication) onSave;
  final Future<void> Function(String)? onDelete;

  static Future<void> show({
    required BuildContext context,
    required String userId,
    required Opportunity opportunity,
    JobApplication? existingApplication,
    required Future<void> Function(JobApplication) onSave,
    Future<void> Function(String)? onDelete,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => ApplicationDialog(
        userId: userId,
        opportunity: opportunity,
        existingApplication: existingApplication,
        onSave: onSave,
        onDelete: onDelete,
      ),
    );
  }

  @override
  State<ApplicationDialog> createState() => _ApplicationDialogState();
}

class _ApplicationDialogState extends State<ApplicationDialog> {
  late JobApplicationStatus _status;
  late final TextEditingController _notesController;
  bool _isSaving = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _status = widget.existingApplication?.status ?? JobApplicationStatus.postulada;
    _notesController = TextEditingController(
      text: widget.existingApplication?.notes ?? '',
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    try {
      final app = JobApplication(
        id: widget.existingApplication?.id ?? '',
        userId: widget.userId,
        opportunityId: widget.opportunity.id,
        status: _status,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        appliedAt: widget.existingApplication?.appliedAt ?? DateTime.now(),
        opportunity: widget.opportunity,
      );

      await widget.onSave(app);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.existingApplication == null
              ? 'Postulación registrada correctamente.'
              : 'Postulación actualizada.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo guardar la postulación. Inténtalo de nuevo.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleDelete() async {
    if (widget.existingApplication == null || widget.onDelete == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar seguimiento?'),
        content: const Text(
          'Se eliminará este registro de tus postulaciones guardadas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      await widget.onDelete!(widget.existingApplication!.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seguimiento eliminado.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo eliminar el seguimiento.')),
      );
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  Future<void> _openExternalLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el enlace oficial.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.opportunity.title ?? 'Convocatoria laboral';
    final company = widget.opportunity.company ?? 'Entidad convocante';
    final hasUrl = widget.opportunity.applicationUrl != null &&
        widget.opportunity.applicationUrl!.trim().isNotEmpty;

    return AlertDialog(
      insetPadding: const EdgeInsets.all(20),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.maroon.withValues(alpha: 0.14),
                  AppTheme.maroon.withValues(alpha: 0.06),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.assignment_turned_in_outlined,
                color: AppTheme.maroon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.existingApplication == null
                      ? 'Registrar postulación'
                      : 'Actualizar postulación',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  '$title • $company',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: AppTheme.gray),
                ),
              ],
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasUrl) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.navy.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppTheme.navy.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 16, color: AppTheme.navy),
                          SizedBox(width: 6),
                          Text(
                            'Enlace oficial de postulación',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.navy,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'MatchUNSA no envía tu postulación automáticamente; te redirige al portal oficial para postularte y registrar aquí tu seguimiento.',
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () =>
                            _openExternalLink(widget.opportunity.applicationUrl!),
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('Abrir portal de postulación'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              const Text(
                'Estado de tu postulación:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: JobApplicationStatus.values.map((status) {
                  final isSelected = _status == status;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? status.color
                          : status.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isSelected
                            ? status.color
                            : status.color.withValues(alpha: 0.25),
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => setState(() => _status = status),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(status.icon,
                                size: 15,
                                color:
                                    isSelected ? Colors.white : status.color),
                            const SizedBox(width: 6),
                            Text(
                              status.label,
                              style: TextStyle(
                                color: isSelected ? Colors.white : AppTheme.navy,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notas personales (opcional)',
                  hintText:
                      'Ej. Envié CV por correo el 01/11, entrevista agendada...',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.existingApplication != null && widget.onDelete != null)
          TextButton(
            onPressed: _isSaving || _isDeleting ? null : _handleDelete,
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
            child: const Text('Eliminar'),
          ),
        TextButton(
          onPressed: _isSaving || _isDeleting
              ? null
              : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _isSaving || _isDeleting ? null : _handleSave,
          child: Text(_isSaving ? 'Guardando…' : 'Guardar'),
        ),
      ],
    );
  }
}
