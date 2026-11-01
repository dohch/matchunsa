enum AcademicStatus {
  student('student', 'Estudiante'),
  graduate('graduate', 'Egresado'),
  bachelor('bachelor', 'Bachiller');

  const AcademicStatus(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  static AcademicStatus fromDatabaseValue(String value) {
    return AcademicStatus.values.firstWhere(
      (status) => status.databaseValue == value,
    );
  }
}
