abstract final class ProfessionalFaculties {
  static const options = <String>[
    'Facultad de Administración',
    'Facultad de Agronomía',
    'Facultad de Arquitectura y Urbanismo',
    'Facultad de Ciencias Biológicas',
    'Facultad de Ciencias de la Educación',
    'Facultad de Ciencias Histórico Sociales',
    'Facultad de Ciencias Naturales y Formales',
    'Facultad de Contabilidad y Finanzas',
    'Facultad de Derecho',
    'Facultad de Economía',
    'Facultad de Enfermería',
    'Facultad de Filosofía y Humanidades',
    'Facultad de Geología, Geofísica y Minas',
    'Facultad de Ingeniería Civil',
    'Facultad de Ingeniería de Procesos',
    'Facultad de Ingeniería de Producción y Servicios',
    'Facultad de Medicina',
    'Facultad de Psicología, Relaciones Industriales y Ciencias de la Comunicación',
  ];

  static String? facultyForCareer(String career) {
    final c = career.toLowerCase().trim();
    if (c.contains('arquitectura')) return 'Facultad de Arquitectura y Urbanismo';
    if (c.contains('ambiental') ||
        c.contains('industrias alimentarias') ||
        c.contains('materiales') ||
        c.contains('metalúrgica') ||
        c.contains('química')) {
      return 'Facultad de Ingeniería de Procesos';
    }
    if (c.contains('sistemas') ||
        c.contains('telecomunicaciones') ||
        c.contains('eléctrica') ||
        c.contains('electrónica') ||
        c.contains('industrial') ||
        c.contains('mecánica')) {
      return 'Facultad de Ingeniería de Producción y Servicios';
    }
    if (c.contains('minas') || c.contains('geofísica') || c.contains('geológica')) {
      return 'Facultad de Geología, Geofísica y Minas';
    }
    if (c.contains('civil') || c.contains('sanitaria')) {
      return 'Facultad de Ingeniería Civil';
    }
    if (c.contains('derecho')) return 'Facultad de Derecho';
    if (c.contains('educación')) return 'Facultad de Ciencias de la Educación';
    if (c.contains('filosofía') ||
        c.contains('literatura') ||
        c.contains('artes')) {
      return 'Facultad de Filosofía y Humanidades';
    }
    if (c.contains('antropología') ||
        c.contains('historia') ||
        c.contains('sociología') ||
        c.contains('trabajo social') ||
        c.contains('turismo')) {
      return 'Facultad de Ciencias Histórico Sociales';
    }
    if (c.contains('psicología') ||
        c.contains('relaciones industriales') ||
        c.contains('comunicación')) {
      return 'Facultad de Psicología, Relaciones Industriales y Ciencias de la Comunicación';
    }
    if (c.contains('agronomía')) return 'Facultad de Agronomía';
    if (c.contains('biología') || c.contains('nutrición') || c.contains('pesquera')) {
      return 'Facultad de Ciencias Biológicas';
    }
    if (c.contains('enfermería')) return 'Facultad de Enfermería';
    if (c.contains('medicina')) return 'Facultad de Medicina';
    if (c.contains('computación') ||
        c.contains('física') ||
        c.contains('matemáticas') ||
        c.contains('química')) {
      return 'Facultad de Ciencias Naturales y Formales';
    }
    if (c.contains('administración') ||
        c.contains('banca') ||
        c.contains('gestión') ||
        c.contains('marketing')) {
      return 'Facultad de Administración';
    }
    if (c.contains('contabilidad') || c.contains('finanzas')) {
      return 'Facultad de Contabilidad y Finanzas';
    }
    if (c.contains('economía')) return 'Facultad de Economía';
    return null;
  }
}
