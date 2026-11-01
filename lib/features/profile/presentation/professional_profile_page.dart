import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:matchunsa/app/theme/app_theme.dart';
import 'package:matchunsa/app/widgets/mu_empty_state.dart';
import 'package:matchunsa/app/widgets/mu_motion.dart';
import 'package:matchunsa/app/widgets/mu_surface.dart';
import 'package:matchunsa/features/auth/domain/auth_user.dart';
import 'package:matchunsa/features/profile/domain/academic_semester.dart';
import 'package:matchunsa/features/profile/domain/academic_status.dart';
import 'package:matchunsa/features/profile/domain/professional_careers.dart';
import 'package:matchunsa/features/profile/domain/professional_faculties.dart';
import 'package:matchunsa/features/profile/domain/profile_repository.dart';
import 'package:matchunsa/features/profile/domain/professional_profile.dart';

class ProfessionalProfilePage extends StatefulWidget {
  const ProfessionalProfilePage({
    super.key,
    required this.user,
    required this.repository,
    required this.onSignOut,
    this.showAppBar = true,
  });

  final AuthUser user;
  final ProfileRepository repository;
  final Future<void> Function() onSignOut;
  final bool showAppBar;

  @override
  State<ProfessionalProfilePage> createState() =>
      _ProfessionalProfilePageState();
}

class _ProfessionalProfilePageState extends State<ProfessionalProfilePage> {
  static const _maxCvBytes = 10 * 1024 * 1024;

  final _formKey = GlobalKey<FormState>();
  final _firstNamesController = TextEditingController();
  final _lastNamesController = TextEditingController();
  final _phoneController = TextEditingController();
  final _linkedinController = TextEditingController();
  final _skillController = TextEditingController();
  final _studentCodeController = TextEditingController();
  final _additionalInfoController = TextEditingController();

  AcademicStatus? _academicStatus;
  String? _career;
  String? _legacyCareer;
  String? _faculty;
  int? _semester;
  int? _legacySemester;
  bool _clearLegacySemester = false;
  List<String> _skills = [];
  String? _cvPath;
  String? _loadError;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingCv = false;
  bool _isSigningOut = false;
  bool _hasProfile = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _firstNamesController.dispose();
    _lastNamesController.dispose();
    _phoneController.dispose();
    _linkedinController.dispose();
    _skillController.dispose();
    _studentCodeController.dispose();
    _additionalInfoController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final profile = await widget.repository.getForUser(widget.user.id);
      if (!mounted) return;
      if (profile != null) _applyProfile(profile);
      setState(() {
        _hasProfile = profile != null;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = 'No se pudo cargar tu perfil. Inténtalo nuevamente.';
        _isLoading = false;
      });
    }
  }

  void _applyProfile(ProfessionalProfile profile) {
    _firstNamesController.text = profile.firstNames;
    _lastNamesController.text = profile.lastNames;
    _phoneController.text = profile.phone ?? '';
    _linkedinController.text = profile.linkedinUrl ?? '';
    _studentCodeController.text = profile.studentCode ?? '';
    _additionalInfoController.text = profile.additionalInfo ?? '';
    _career = ProfessionalCareers.options.contains(profile.career)
        ? profile.career
        : null;
    _legacyCareer = _career == null ? profile.career : null;
    _faculty = profile.faculty ??
        (_career != null
            ? ProfessionalFaculties.facultyForCareer(_career!)
            : null);
    _semester = AcademicSemester.options.contains(profile.semester)
        ? profile.semester
        : null;
    _legacySemester =
        profile.semester != null && _semester == null ? profile.semester : null;
    _clearLegacySemester = false;
    _academicStatus = profile.academicStatus;
    _skills = List<String>.of(profile.skills);
    _cvPath = profile.cvPath;
  }

  Future<void> _saveProfile() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final savedProfile = await widget.repository.save(
        ProfessionalProfile(
          userId: widget.user.id,
          firstNames: _firstNamesController.text.trim(),
          lastNames: _lastNamesController.text.trim(),
          phone: _optionalValue(_phoneController.text),
          linkedinUrl: _optionalValue(_linkedinController.text),
          career: _career!,
          faculty: _faculty,
          studentCode: _optionalValue(_studentCodeController.text),
          additionalInfo: _optionalValue(_additionalInfoController.text),
          academicStatus: _academicStatus!,
          semester: _semester ??
              (_academicStatus == AcademicStatus.student || _clearLegacySemester
                  ? null
                  : _legacySemester),
          skills: List<String>.unmodifiable(_skills),
          cvPath: _cvPath,
        ),
      );

      if (!mounted) return;
      _applyProfile(savedProfile);
      setState(() => _hasProfile = true);
      _showMessage('Perfil guardado correctamente.');
    } catch (_) {
      if (mounted) {
        _showMessage('No se pudo guardar el perfil. Inténtalo nuevamente.');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }


  Future<void> _pickAndUploadCv() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      dialogTitle: 'Selecciona tu currículum en PDF',
    );
    if (file == null || !mounted) return;

    final fileSize = file.lengthSync() ?? await file.length();
    if (file.extension?.toLowerCase() != 'pdf' ||
        fileSize == null ||
        fileSize > _maxCvBytes) {
      _showMessage('Selecciona un PDF de hasta 10 MB.');
      return;
    }

    setState(() => _isUploadingCv = true);
    try {
      final bytes = await file.readAsBytes();
      final hasPdfSignature =
          bytes.length >= 5 && String.fromCharCodes(bytes.take(5)) == '%PDF-';
      if (!hasPdfSignature) {
        _showMessage('El archivo seleccionado no parece ser un PDF válido.');
        return;
      }

      final path = await widget.repository.uploadCv(
        userId: widget.user.id,
        bytes: bytes,
      );
      if (!mounted) return;
      setState(() => _cvPath = path);
      _showMessage('CV cargado. Guarda los cambios para asociarlo al perfil.');
    } catch (_) {
      if (mounted) {
        _showMessage('No se pudo cargar el CV. Inténtalo nuevamente.');
      }
    } finally {
      if (mounted) setState(() => _isUploadingCv = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _isSigningOut = true);
    try {
      await widget.onSignOut();
    } catch (_) {
      if (mounted) {
        _showMessage('No se pudo cerrar la sesión. Inténtalo nuevamente.');
      }
    } finally {
      if (mounted) setState(() => _isSigningOut = false);
    }
  }

  String? _validateRequired(String? value, String label) {
    if (value == null || value.trim().isEmpty) return 'Ingresa $label.';
    return null;
  }

  String? _validatePhone(String? value) {
    final phone = value?.trim() ?? '';
    if (phone.isEmpty) return null;
    if (!RegExp(r'^[0-9+()\s-]{7,20}$').hasMatch(phone)) {
      return 'Ingresa un número de teléfono válido.';
    }
    return null;
  }

  String? _validateStudentCode(String? value) {
    final code = value?.trim() ?? '';
    if (code.isEmpty) return null;
    if (!RegExp(r'^[a-zA-Z0-9]{5,15}$').hasMatch(code)) {
      return 'Ingresa un código universitario válido (5-15 caracteres).';
    }
    return null;
  }

  String? _validateLinkedin(String? value) {
    final link = value?.trim() ?? '';
    if (link.isEmpty) return null;
    final uri = Uri.tryParse(link);
    final host = uri?.host.toLowerCase();
    final isLinkedinHost =
        host == 'linkedin.com' || host?.endsWith('.linkedin.com') == true;
    if (uri == null || uri.scheme != 'https' || !isLinkedinHost) {
      return 'Ingresa un enlace https://www.linkedin.com válido.';
    }
    return null;
  }

  String? _validateSemester(int? semester) {
    if (_academicStatus == AcademicStatus.student && semester == null) {
      return 'Selecciona el semestre académico actual.';
    }
    return null;
  }

  void _addSkill() {
    final skill = _skillController.text.trim();
    if (skill.isEmpty) return;
    if (_skills
        .any((existing) => existing.toLowerCase() == skill.toLowerCase())) {
      _showMessage('Esa habilidad ya está en la lista.');
      return;
    }
    setState(() {
      _skills = [..._skills, skill];
      _skillController.clear();
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String? _optionalValue(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('Perfil profesional'),
              actions: [
                TextButton.icon(
                  onPressed: _isSigningOut ? null : _signOut,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Cerrar sesión'),
                ),
                const SizedBox(width: 8),
              ],
            )
          : null,
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) return const MuLoading();
    if (_loadError != null) {
      return MuErrorState(message: _loadError!, onRetry: _loadProfile);
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: Form(
          key: _formKey,
          child: ListView(
            // ignore: deprecated_member_use
            cacheExtent: 3000.0,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
            children: [
              MuFadeSlide(
                child: MuSurface(
                  padding: const EdgeInsets.all(22),
                  child: Row(
                    children: [
                      // Avatar with maroon gradient ring.
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppTheme.brandGradient,
                        ),
                        child: CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.white,
                          child: const Icon(Icons.person_outline_rounded,
                              color: AppTheme.maroon, size: 30),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Perfil profesional',
                                style:
                                    Theme.of(context).textTheme.headlineSmall),
                            const SizedBox(height: 4),
                            Text(
                              _hasProfile
                                  ? 'Revisa y actualiza tu información.'
                                  : 'Completa tu información para presentar mejor tu experiencia.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _section(
                context,
                title: 'Datos personales',
                children: [
                  _responsivePair(
                    _textField(
                      controller: _firstNamesController,
                      label: 'Nombres *',
                      validator: (value) =>
                          _validateRequired(value, 'tus nombres'),
                      textCapitalization: TextCapitalization.words,
                    ),
                    _textField(
                      controller: _lastNamesController,
                      label: 'Apellidos *',
                      validator: (value) =>
                          _validateRequired(value, 'tus apellidos'),
                      textCapitalization: TextCapitalization.words,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _responsivePair(
                    _textField(
                      initialValue: widget.user.email,
                      label: 'Correo institucional',
                      readOnly: true,
                      helperText: 'Vinculado a tu cuenta de Supabase Auth.',
                    ),
                    _textField(
                      controller: _studentCodeController,
                      label: 'Código universitario (opcional)',
                      keyboardType: TextInputType.text,
                      validator: _validateStudentCode,
                      helperText: 'Identificador oficial UNSA.',
                    ),
                  ),
                  const SizedBox(height: 16),
                  _responsivePair(
                    _textField(
                      controller: _phoneController,
                      label: 'Teléfono (opcional)',
                      keyboardType: TextInputType.phone,
                      validator: _validatePhone,
                    ),
                    _textField(
                      controller: _linkedinController,
                      label: 'LinkedIn (opcional)',
                      keyboardType: TextInputType.url,
                      validator: _validateLinkedin,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _section(
                context,
                title: 'Información académica',
                children: [
                  _responsivePair(
                    DropdownButtonFormField<String>(
                      key: ValueKey(_career),
                      initialValue: _career,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Carrera profesional *',
                      ),
                      hint: const Text('Selecciona tu carrera'),
                      items: ProfessionalCareers.options
                          .map((career) => DropdownMenuItem(
                                value: career,
                                child: Text(career),
                              ))
                          .toList(),
                      onChanged: (career) => setState(() {
                        _career = career;
                        _legacyCareer = null;
                        if (career != null && _faculty == null) {
                          _faculty =
                              ProfessionalFaculties.facultyForCareer(career);
                        }
                      }),
                      validator: (career) => career == null
                          ? 'Selecciona tu carrera profesional.'
                          : null,
                    ),
                    DropdownButtonFormField<String>(
                      key: ValueKey(_faculty),
                      initialValue: _faculty,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Facultad (opcional)',
                      ),
                      hint: const Text('Selecciona tu facultad'),
                      items: ProfessionalFaculties.options
                          .map((faculty) => DropdownMenuItem(
                                value: faculty,
                                child: Text(faculty),
                              ))
                          .toList(),
                      onChanged: (faculty) =>
                          setState(() => _faculty = faculty),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<AcademicStatus>(
                    key: ValueKey(_academicStatus),
                    initialValue: _academicStatus,
                    decoration: const InputDecoration(
                      labelText: 'Situación académica *',
                    ),
                    isExpanded: true,
                    hint: const Text('Selecciona una opción'),
                    items: AcademicStatus.values
                        .map((status) => DropdownMenuItem(
                              value: status,
                              child: Text(status.label),
                            ))
                        .toList(),
                    onChanged: (status) =>
                        setState(() => _academicStatus = status),
                    validator: (status) => status == null
                        ? 'Selecciona tu situación académica.'
                        : null,
                  ),
                  if (_legacyCareer != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Carrera guardada anteriormente: $_legacyCareer. '
                      'Selecciona una opción de la lista para actualizarla.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          key: ValueKey('${_academicStatus?.name}:$_semester'),
                          initialValue: _semester,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: _academicStatus == AcademicStatus.student
                                ? 'Semestre académico *'
                                : 'Semestre académico (opcional)',
                          ),
                          hint: const Text('Selecciona un semestre'),
                          items: AcademicSemester.options
                              .map((semester) => DropdownMenuItem(
                                    value: semester,
                                    child:
                                        Text(AcademicSemester.label(semester)),
                                  ))
                              .toList(),
                          onChanged: (semester) => setState(() {
                            _semester = semester;
                            _legacySemester = null;
                            _clearLegacySemester = false;
                          }),
                          validator: _validateSemester,
                        ),
                      ),
                      if (_academicStatus != AcademicStatus.student &&
                          (_semester != null || _legacySemester != null))
                        IconButton(
                          tooltip: 'Quitar semestre',
                          onPressed: () => setState(() {
                            _semester = null;
                            _legacySemester = null;
                            _clearLegacySemester = true;
                          }),
                          icon: const Icon(Icons.clear),
                        ),
                    ],
                  ),
                  if (_legacySemester != null && _semester == null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Semestre guardado anteriormente: $_legacySemester. '
                      'Puedes elegir uno del 1 al 14 o quitar el valor anterior.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              _section(
                context,
                title: 'Información profesional',
                children: [
                  TextField(
                    controller: _skillController,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'Habilidad o conocimiento',
                      hintText: 'Por ejemplo: análisis de datos',
                      suffixIcon: IconButton(
                        tooltip: 'Agregar habilidad',
                        onPressed: _addSkill,
                        icon: const Icon(Icons.add),
                      ),
                    ),
                    onSubmitted: (_) => _addSkill(),
                  ),
                  if (_skills.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final skill in _skills)
                          InputChip(
                            label: Text(skill),
                            onDeleted: () => setState(
                              () => _skills = _skills
                                  .where((item) => item != skill)
                                  .toList(),
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _additionalInfoController,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Información profesional adicional (opcional)',
                      hintText:
                          'Resumen personal, metas profesionales o áreas de especialización.',
                      helperText:
                          'Información visible para convocatorias y oportunidades.',
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _cvPath == null
                              ? 'Currículum vitae PDF (opcional)'
                              : 'CV cargado: ${_cvPath!.split('/').last}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: _isUploadingCv ? null : _pickAndUploadCv,
                        icon: const Icon(Icons.upload_file),
                        label:
                            Text(_cvPath == null ? 'Subir PDF' : 'Reemplazar'),
                      ),
                    ],
                  ),
                  if (_isUploadingCv) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    'PDF de hasta 10 MB. El archivo se guarda en un bucket privado.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _isSaving || _isUploadingCv ? null : _saveProfile,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_isSaving ? 'Guardando…' : 'Guardar cambios'),
                ),
              ),
              if (_isSaving) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return MuSurface(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.maroon.withValues(alpha: 0.12),
                      AppTheme.maroon.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(_sectionIcon(title),
                    size: 19, color: AppTheme.maroon),
              ),
              const SizedBox(width: 11),
              Expanded(
                  child: Text(title,
                      style: Theme.of(context).textTheme.titleLarge)),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  IconData _sectionIcon(String title) => switch (title) {
        'Datos personales' => Icons.badge_outlined,
        'Información académica' => Icons.school_outlined,
        _ => Icons.workspace_premium_outlined,
      };

  Widget _responsivePair(Widget first, Widget second) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620) {
          return Column(
            children: [first, const SizedBox(height: 16), second],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: 16),
            Expanded(child: second),
          ],
        );
      },
    );
  }

  Widget _textField({
    TextEditingController? controller,
    String? initialValue,
    required String label,
    String? helperText,
    bool readOnly = false,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      initialValue: initialValue,
      readOnly: readOnly,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
      ),
    );
  }
}
