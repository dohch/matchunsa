import 'package:flutter/material.dart';
import 'package:matchunsa/app/theme/app_theme.dart';
import 'package:matchunsa/app/widgets/mu_surface.dart';
import 'package:matchunsa/features/opportunities/domain/opportunity.dart';
import 'package:matchunsa/features/opportunities/domain/opportunity_repository.dart';

class ReportOpportunityDialog extends StatefulWidget {
  const ReportOpportunityDialog({
    super.key,
    required this.userId,
    required this.opportunity,
    required this.repository,
  });

  final String userId;
  final Opportunity opportunity;
  final OpportunityRepository repository;

  static Future<void> show({
    required BuildContext context,
    required String userId,
    required Opportunity opportunity,
    required OpportunityRepository repository,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => ReportOpportunityDialog(
        userId: userId,
        opportunity: opportunity,
        repository: repository,
      ),
    );
  }

  @override
  State<ReportOpportunityDialog> createState() =>
      _ReportOpportunityDialogState();
}

class _ReportOpportunityDialogState extends State<ReportOpportunityDialog> {
  final _reasonController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Describe el motivo del reporte.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.repository.reportOpportunity(
        userId: widget.userId,
        opportunityId: widget.opportunity.id,
        reason: reason,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Reporte enviado. Los administradores revisarán la información.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo enviar el reporte. Inténtalo de nuevo.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          MuIconBadge(icon: Icons.report_problem_outlined, size: 44),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Reportar incidencia',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Convocatoria: ${widget.opportunity.title ?? "Oportunidad laboral"}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            const Text(
              'Indica si hay datos erróneos, enlaces caídos o información que deba ser corregida por los moderadores.',
              style: TextStyle(fontSize: 12, color: AppTheme.gray),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _reasonController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Motivo del reporte *',
                hintText:
                    'Ejemplo: El enlace oficial de postulación está roto, la fecha de cierre es anterior...',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _isSubmitting ? null : _submit,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.send_rounded, size: 16),
          label: Text(_isSubmitting ? 'Enviando…' : 'Enviar reporte'),
        ),
      ],
    );
  }
}
