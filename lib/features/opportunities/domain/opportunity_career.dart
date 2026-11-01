class OpportunityCareer {
  const OpportunityCareer({
    required this.originalName,
    this.canonicalName,
  });

  final String originalName;
  final String? canonicalName;

  String get displayName {
    final canonical = canonicalName?.trim();
    if (canonical == null || canonical.isEmpty || canonical == originalName) {
      return originalName;
    }
    return '$canonical (correo: $originalName)';
  }
}
