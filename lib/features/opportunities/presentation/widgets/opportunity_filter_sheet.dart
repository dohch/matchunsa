import 'package:flutter/material.dart';
import 'package:matchunsa/app/theme/app_theme.dart';
import 'package:matchunsa/app/widgets/mu_surface.dart';
import 'package:matchunsa/features/opportunities/domain/opportunity_filter.dart';
import 'package:matchunsa/features/profile/domain/professional_careers.dart';

class OpportunityFilterSheet extends StatefulWidget {
  const OpportunityFilterSheet({
    super.key,
    required this.initialFilter,
    required this.onApply,
  });

  final OpportunityFilter initialFilter;
  final ValueChanged<OpportunityFilter> onApply;

  static Future<void> show({
    required BuildContext context,
    required OpportunityFilter currentFilter,
    required ValueChanged<OpportunityFilter> onApply,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OpportunityFilterSheet(
        initialFilter: currentFilter,
        onApply: onApply,
      ),
    );
  }

  @override
  State<OpportunityFilterSheet> createState() => _OpportunityFilterSheetState();
}

class _OpportunityFilterSheetState extends State<OpportunityFilterSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _companyController;
  late final TextEditingController _locationController;

  String? _selectedCareer;
  late OpportunityTypeFilter _type;
  late OpportunityValidityFilter _validity;
  DateTime? _closingDateStart;
  DateTime? _closingDateEnd;

  @override
  void initState() {
    super.initState();
    final f = widget.initialFilter;
    _titleController = TextEditingController(text: f.titleQuery ?? '');
    _companyController = TextEditingController(text: f.companyQuery ?? '');
    _locationController = TextEditingController(text: f.locationQuery ?? '');
    _selectedCareer = f.career;
    _type = f.type;
    _validity = f.validity;
    _closingDateStart = f.closingDateStart;
    _closingDateEnd = f.closingDateEnd;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _companyController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _clearAll() {
    setState(() {
      _titleController.clear();
      _companyController.clear();
      _locationController.clear();
      _selectedCareer = null;
      _type = OpportunityTypeFilter.all;
      _validity = OpportunityValidityFilter.activeOnly;
      _closingDateStart = null;
      _closingDateEnd = null;
    });
  }

  void _apply() {
    final filter = OpportunityFilter(
      titleQuery: _optional(_titleController.text),
      companyQuery: _optional(_companyController.text),
      career: _selectedCareer,
      locationQuery: _optional(_locationController.text),
      type: _type,
      validity: _validity,
      closingDateStart: _closingDateStart,
      closingDateEnd: _closingDateEnd,
    );

    widget.onApply(filter);
    Navigator.of(context).pop();
  }

  String? _optional(String text) {
    final t = text.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final initialDate = isStart
        ? (_closingDateStart ?? now)
        : (_closingDateEnd ?? _closingDateStart ?? now);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      helpText: isStart
          ? 'Selecciona fecha de cierre inicial'
          : 'Selecciona fecha de cierre final',
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _closingDateStart = picked;
          if (_closingDateEnd != null && _closingDateEnd!.isBefore(picked)) {
            _closingDateEnd = picked;
          }
        } else {
          _closingDateEnd = picked;
          if (_closingDateStart != null &&
              _closingDateStart!.isAfter(picked)) {
            _closingDateStart = picked;
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Grabber.
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 2),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.hairline,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            // Header.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 4),
              child: Row(
                children: [
                  const MuIconBadge(icon: Icons.tune_rounded, size: 44),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Filtros avanzados',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton(
                    onPressed: _clearAll,
                    child: const Text('Limpiar todo',
                        style: TextStyle(fontSize: 12)),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Nombre del puesto / convocatoria'),
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        hintText:
                            'Ej. Practicante, Desarrollador, Asistente...',
                        prefixIcon:
                            Icon(Icons.work_outline_rounded, size: 20),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _fieldLabel('Empresa o entidad'),
                    TextField(
                      controller: _companyController,
                      decoration: const InputDecoration(
                        hintText: 'Ej. Banco, Minera, Municipalidad...',
                        prefixIcon:
                            Icon(Icons.business_outlined, size: 20),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _fieldLabel('Carrera profesional'),
                    DropdownButtonFormField<String>(
                      key: ValueKey(_selectedCareer),
                      initialValue: _selectedCareer,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.school_outlined, size: 20),
                        hintText: 'Todas las carreras',
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Todas las carreras'),
                        ),
                        ...ProfessionalCareers.options.map(
                          (career) => DropdownMenuItem(
                            value: career,
                            child: Text(career),
                          ),
                        ),
                      ],
                      onChanged: (val) =>
                          setState(() => _selectedCareer = val),
                    ),
                    const SizedBox(height: 14),
                    _fieldLabel('Ubicación'),
                    TextField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        hintText: 'Ej. Arequipa, Lima, Remoto...',
                        prefixIcon: Icon(Icons.location_on_outlined,
                            size: 20),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _fieldLabel('Tipo de convocatoria'),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Todas'),
                          selected:
                              _type == OpportunityTypeFilter.all,
                          onSelected: (sel) {
                            if (sel) {
                              setState(
                                  () => _type = OpportunityTypeFilter.all);
                            }
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Laboral'),
                          selected:
                              _type == OpportunityTypeFilter.laboral,
                          onSelected: (sel) {
                            if (sel) {
                              setState(() =>
                                  _type = OpportunityTypeFilter.laboral);
                            }
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Prácticas'),
                          selected:
                              _type == OpportunityTypeFilter.practicas,
                          onSelected: (sel) {
                            if (sel) {
                              setState(() =>
                                  _type = OpportunityTypeFilter.practicas);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _fieldLabel('Vigencia'),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Solo vigentes'),
                          selected: _validity ==
                              OpportunityValidityFilter.activeOnly,
                          onSelected: (sel) {
                            if (sel) {
                              setState(() => _validity =
                                  OpportunityValidityFilter.activeOnly);
                            }
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Todas'),
                          selected:
                              _validity == OpportunityValidityFilter.all,
                          onSelected: (sel) {
                            if (sel) {
                              setState(() => _validity =
                                  OpportunityValidityFilter.all);
                            }
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Vencidas'),
                          selected: _validity ==
                              OpportunityValidityFilter.expiredOnly,
                          onSelected: (sel) {
                            if (sel) {
                              setState(() => _validity =
                                  OpportunityValidityFilter.expiredOnly);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _fieldLabel('Rango de fecha de cierre'),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 10),
                            ),
                            onPressed: () => _pickDate(isStart: true),
                            icon: const Icon(
                                Icons.calendar_today_outlined,
                                size: 16),
                            label: Text(
                              _closingDateStart == null
                                  ? 'Desde'
                                  : _formatDate(_closingDateStart!),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 10),
                            ),
                            onPressed: () => _pickDate(isStart: false),
                            icon:
                                const Icon(Icons.event_outlined, size: 16),
                            label: Text(
                              _closingDateEnd == null
                                  ? 'Hasta'
                                  : _formatDate(_closingDateEnd!),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                        if (_closingDateStart != null ||
                            _closingDateEnd != null)
                          IconButton(
                            tooltip: 'Borrar fechas',
                            onPressed: () => setState(() {
                              _closingDateStart = null;
                              _closingDateEnd = null;
                            }),
                            icon:
                                const Icon(Icons.close_rounded, size: 18),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Actions.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _apply,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Aplicar filtros'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppTheme.navy,
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}
