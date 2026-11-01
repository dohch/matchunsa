import 'package:flutter/material.dart';
import 'package:matchunsa/app/theme/app_theme.dart';
import 'package:matchunsa/app/widgets/mu_components.dart';
import 'package:matchunsa/app/widgets/mu_empty_state.dart';
import 'package:matchunsa/app/widgets/mu_motion.dart';
import 'package:matchunsa/app/widgets/mu_surface.dart';
import 'package:matchunsa/features/auth/domain/auth_user.dart';
import 'package:matchunsa/features/opportunities/domain/opportunity.dart';
import 'package:matchunsa/features/opportunities/domain/opportunity_repository.dart';

class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({
    super.key,
    required this.user,
    required this.repository,
    this.showAppBar = false,
  });

  final AuthUser user;
  final OpportunityRepository repository;
  final bool showAppBar;

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _isCheckingAdmin = true;
  bool _isAdmin = false;

  List<Opportunity> _opportunities = const [];
  List<Map<String, dynamic>> _sourceEmails = const [];
  List<Map<String, dynamic>> _reports = const [];
  List<Map<String, dynamic>> _users = const [];

  bool _isLoadingData = false;
  String? _error;
  String _oppSearch = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _checkAdminAndLoad();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkAdminAndLoad() async {
    setState(() {
      _isCheckingAdmin = true;
      _error = null;
    });

    try {
      final isAdmin = await widget.repository.isUserAdmin(widget.user.id);
      if (!mounted) return;
      setState(() {
        _isAdmin = isAdmin;
        _isCheckingAdmin = false;
      });

      if (isAdmin) {
        await _loadAllData();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isCheckingAdmin = false;
        _isAdmin = false;
        _error = 'Error verificando permisos de administrador.';
      });
    }
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoadingData = true);
    try {
      final results = await Future.wait([
        widget.repository.getOpportunities(includeInactive: true),
        widget.repository.getAdminSourceEmails(),
        widget.repository.getAdminReports(),
        widget.repository.getAdminUsers(),
      ]);

      if (!mounted) return;
      setState(() {
        _opportunities = results[0] as List<Opportunity>;
        _sourceEmails = results[1] as List<Map<String, dynamic>>;
        _reports = results[2] as List<Map<String, dynamic>>;
        _users = results[3] as List<Map<String, dynamic>>;
        _isLoadingData = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingData = false;
        _error = 'No se pudieron cargar todos los datos administrativos.';
      });
    }
  }

  Future<void> _toggleOpportunityActive(Opportunity opp) async {
    final newStatus = !opp.isActive;
    try {
      await widget.repository.setOpportunityActive(
        opportunityId: opp.id,
        isActive: newStatus,
      );
      if (!mounted) return;
      setState(() {
        _opportunities = _opportunities
            .map((o) => o.id == opp.id ? _copyOpportunity(o, newStatus) : o)
            .toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newStatus
              ? 'Convocatoria activada.'
              : 'Convocatoria desactivada/ocultada.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo cambiar el estado.')),
      );
    }
  }

  Opportunity _copyOpportunity(Opportunity o, bool isActive) {
    return Opportunity(
      id: o.id,
      title: o.title,
      company: o.company,
      careers: o.careers,
      originalContent: o.originalContent,
      academicProfile: o.academicProfile,
      location: o.location,
      closingDate: o.closingDate,
      vacancies: o.vacancies,
      requirements: o.requirements,
      desiredKnowledge: o.desiredKnowledge,
      functions: o.functions,
      additionalInformation: o.additionalInformation,
      applicationUrl: o.applicationUrl,
      applicationEmail: o.applicationEmail,
      applicationPhone: o.applicationPhone,
      cvType: o.cvType,
      isActive: isActive,
    );
  }

  Future<void> _updateReport(String reportId, String status) async {
    final notesController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(status == 'resolved'
            ? 'Resolver incidencia'
            : 'Desestimar incidencia'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Notas administrativas (opcional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await widget.repository.updateReportStatus(
        reportId: reportId,
        status: status,
        adminNotes: notesController.text.trim().isEmpty
            ? null
            : notesController.text.trim(),
      );
      await _loadAllData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incidencia actualizada.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo actualizar la incidencia.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: widget.showAppBar
          ? AppBar(title: const Text('Panel Administrativo'))
          : null,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isCheckingAdmin) {
      return const MuLoading();
    }

    if (!_isAdmin) {
      return MuEmptyState(
        icon: Icons.gpp_bad_outlined,
        title: 'Acceso restringido',
        message:
            'Este módulo está reservado únicamente para administradores autorizados de MatchUNSA.',
        action: OutlinedButton.icon(
          onPressed: _checkAdminAndLoad,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Volver a comprobar'),
        ),
      );
    }

    return Column(
      children: [
        _adminHeader(),
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            tabs: [
              Tab(
                icon: const Icon(Icons.work_outline_rounded, size: 20),
                text: 'Convocatorias (${_opportunities.length})',
              ),
              Tab(
                icon: const Icon(Icons.mark_email_read_outlined, size: 20),
                text: 'UDEEG Recibidos (${_sourceEmails.length})',
              ),
              Tab(
                icon: const Icon(Icons.report_problem_outlined, size: 20),
                text: 'Incidencias (${_reports.length})',
              ),
              Tab(
                icon: const Icon(Icons.people_outline_rounded, size: 20),
                text: 'Usuarios (${_users.length})',
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoadingData
              ? const MuLoading()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _tabOpportunities(),
                    _tabSourceEmails(),
                    _tabReports(),
                    _tabUsers(),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _adminHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const MuIconBadge(icon: Icons.shield_outlined, size: 46),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Panel de Administración MatchUNSA',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.navy,
                      ),
                    ),
                    Text(
                      'Gestión y moderación segura protegida con políticas RLS.',
                      style: TextStyle(fontSize: 12, color: AppTheme.gray),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Actualizar datos',
                onPressed: _loadAllData,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                _error!,
                style: TextStyle(color: Colors.red.shade900, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tabOpportunities() {
    final filtered = _oppSearch.trim().isEmpty
        ? _opportunities
        : _opportunities.where((o) {
            final t = '${o.title ?? ''} ${o.company ?? ''}'.toLowerCase();
            return t.contains(_oppSearch.trim().toLowerCase());
          }).toList();

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        TextField(
          onChanged: (val) => setState(() => _oppSearch = val),
          decoration: const InputDecoration(
            hintText: 'Buscar convocatorias por puesto o empresa...',
            prefixIcon: Icon(Icons.search_rounded),
            isDense: true,
          ),
        ),
        const SizedBox(height: 14),
        ...filtered.asMap().entries.map((entry) {
          final opp = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: MuStaggeredEntrance(
              index: entry.key,
              child: MuSurface(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: opp.isActive
                            ? AppTheme.navy.withValues(alpha: 0.1)
                            : AppTheme.hairline,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        opp.isActive
                            ? Icons.check_circle_outline_rounded
                            : Icons.visibility_off_outlined,
                        color: opp.isActive ? AppTheme.navy : AppTheme.gray,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            opp.title ?? 'Convocatoria laboral',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              decoration: opp.isActive
                                  ? null
                                  : TextDecoration.lineThrough,
                              color: opp.isActive
                                  ? AppTheme.navy
                                  : AppTheme.gray,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${opp.company ?? "Empresa"} • ${opp.careers.map((c) => c.displayName).join(", ")}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    MuStatusChip(
                      label: opp.isActive ? 'Activa' : 'Oculta',
                      color: opp.isActive
                          ? const Color(0xFF1B8A5A)
                          : const Color(0xFFB3261E),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: opp.isActive,
                      activeThumbColor: AppTheme.maroon,
                      onChanged: (_) => _toggleOpportunityActive(opp),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _tabSourceEmails() {
    return ListView.separated(
      padding: const EdgeInsets.all(18),
      itemCount: _sourceEmails.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final email = _sourceEmails[index];
        final subject = email['subject'] ?? 'Sin asunto';
        final sender = email['sender_email'] ?? 'UDEEG';
        final receivedAt = email['received_at'];
        final status = email['processing_status'] ?? 'pending';
        final body = email['original_body'] ?? '';

        final isProcessed = status == 'processed';

        return MuSurface(
          padding: EdgeInsets.zero,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              shape: const Border(),
              leading: Icon(
                isProcessed
                    ? Icons.check_circle_rounded
                    : Icons.error_outline_rounded,
                color: isProcessed
                    ? const Color(0xFF1B8A5A)
                    : const Color(0xFFB3261E),
              ),
              title: Text(subject,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                '$sender • $status • ${_formatRawDate(receivedAt)}',
                style: const TextStyle(fontSize: 12, color: AppTheme.gray),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Contenido original recibido:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppTheme.canvas,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SelectableText(
                          body,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _tabReports() {
    if (_reports.isEmpty) {
      return const MuEmptyState(
        icon: Icons.report_problem_outlined,
        title: 'Sin incidencias',
        message: 'No hay incidencias ni reportes registrados.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(18),
      itemCount: _reports.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final r = _reports[index];
        final id = r['id'] as String;
        final reason = r['reason'] ?? '';
        final status = r['status'] ?? 'pending';
        final createdAt = r['created_at'];
        final opp = r['opportunities'] as Map?;
        final oppTitle = opp?['title'] ?? 'Convocatoria';
        final adminNotes = r['admin_notes'];

        final statusColor = status == 'pending'
            ? const Color(0xFFB26A00)
            : status == 'resolved'
                ? const Color(0xFF1B8A5A)
                : AppTheme.gray;

        return MuSurface(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  MuStatusChip(label: status.toUpperCase(), color: statusColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      oppTitle,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    _formatRawDate(createdAt),
                    style: const TextStyle(fontSize: 11, color: AppTheme.gray),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text('Motivo: $reason'),
              if (adminNotes != null) ...[
                const SizedBox(height: 6),
                Text('Nota admin: $adminNotes',
                    style: const TextStyle(
                        fontSize: 12, fontStyle: FontStyle.italic)),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (status == 'pending') ...[
                    OutlinedButton(
                      onPressed: () => _updateReport(id, 'dismissed'),
                      child: const Text('Desestimar'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => _updateReport(id, 'resolved'),
                      child: const Text('Resolver'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tabUsers() {
    return ListView.separated(
      padding: const EdgeInsets.all(18),
      itemCount: _users.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final u = _users[index];
        final name = '${u['first_names'] ?? ''} ${u['last_names'] ?? ''}';
        final career = u['career'] ?? 'Sin carrera';
        final faculty = u['faculty'] ?? 'Sin facultad';
        final studentCode = u['student_code'] ?? 'Sin código';
        final phone = u['phone'] ?? 'Sin teléfono';
        final status = u['academic_status'] ?? '';
        final hasCv = u['cv_path'] != null;

        return MuSurface(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
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
                child: Center(
                  child: Text(
                    name.trim().isEmpty ? 'U' : name.trim()[0].toUpperCase(),
                    style: const TextStyle(
                      color: AppTheme.maroon,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.trim().isEmpty ? 'Usuario UNSA' : name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$career • $faculty',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      'Código: $studentCode • Tel: $phone • Estado: $status',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (hasCv)
                const Tooltip(
                  message: 'Tiene CV en PDF registrado',
                  child: Icon(Icons.picture_as_pdf_outlined,
                      color: Color(0xFFB3261E), size: 20),
                ),
            ],
          ),
        );
      },
    );
  }

  static String _formatRawDate(Object? value) {
    if (value is! String || value.trim().isEmpty) return '-';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
  }
}
