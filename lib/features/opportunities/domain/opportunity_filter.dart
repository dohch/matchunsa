import 'package:matchunsa/features/opportunities/domain/opportunity.dart';

enum OpportunityTypeFilter {
  all,
  laboral,
  practicas,
}

enum OpportunityValidityFilter {
  all,
  activeOnly,
  expiredOnly,
}

class OpportunityFilter {
  const OpportunityFilter({
    this.titleQuery,
    this.companyQuery,
    this.career,
    this.locationQuery,
    this.type = OpportunityTypeFilter.all,
    this.validity = OpportunityValidityFilter.activeOnly,
    this.closingDateStart,
    this.closingDateEnd,
  });

  final String? titleQuery;
  final String? companyQuery;
  final String? career;
  final String? locationQuery;
  final OpportunityTypeFilter type;
  final OpportunityValidityFilter validity;
  final DateTime? closingDateStart;
  final DateTime? closingDateEnd;

  bool get isEmpty =>
      (titleQuery == null || titleQuery!.trim().isEmpty) &&
      (companyQuery == null || companyQuery!.trim().isEmpty) &&
      (career == null || career!.trim().isEmpty) &&
      (locationQuery == null || locationQuery!.trim().isEmpty) &&
      type == OpportunityTypeFilter.all &&
      validity == OpportunityValidityFilter.activeOnly &&
      closingDateStart == null &&
      closingDateEnd == null;

  int get activeFiltersCount {
    int count = 0;
    if (titleQuery != null && titleQuery!.trim().isNotEmpty) count++;
    if (companyQuery != null && companyQuery!.trim().isNotEmpty) count++;
    if (career != null && career!.trim().isNotEmpty) count++;
    if (locationQuery != null && locationQuery!.trim().isNotEmpty) count++;
    if (type != OpportunityTypeFilter.all) count++;
    if (validity != OpportunityValidityFilter.activeOnly) count++;
    if (closingDateStart != null || closingDateEnd != null) count++;
    return count;
  }

  OpportunityFilter copyWith({
    String? titleQuery,
    String? companyQuery,
    String? career,
    String? locationQuery,
    OpportunityTypeFilter? type,
    OpportunityValidityFilter? validity,
    DateTime? closingDateStart,
    DateTime? closingDateEnd,
    bool clearTitleQuery = false,
    bool clearCompanyQuery = false,
    bool clearCareer = false,
    bool clearLocationQuery = false,
    bool clearClosingDates = false,
  }) {
    return OpportunityFilter(
      titleQuery: clearTitleQuery ? null : (titleQuery ?? this.titleQuery),
      companyQuery:
          clearCompanyQuery ? null : (companyQuery ?? this.companyQuery),
      career: clearCareer ? null : (career ?? this.career),
      locationQuery:
          clearLocationQuery ? null : (locationQuery ?? this.locationQuery),
      type: type ?? this.type,
      validity: validity ?? this.validity,
      closingDateStart: clearClosingDates
          ? null
          : (closingDateStart ?? this.closingDateStart),
      closingDateEnd:
          clearClosingDates ? null : (closingDateEnd ?? this.closingDateEnd),
    );
  }

  bool matches(Opportunity opportunity) {
    if (titleQuery != null && titleQuery!.trim().isNotEmpty) {
      final t = (opportunity.title ?? '').toLowerCase();
      if (!t.contains(titleQuery!.trim().toLowerCase())) return false;
    }

    if (companyQuery != null && companyQuery!.trim().isNotEmpty) {
      final c = (opportunity.company ?? '').toLowerCase();
      if (!c.contains(companyQuery!.trim().toLowerCase())) return false;
    }

    if (career != null && career!.trim().isNotEmpty) {
      final targetCareer = career!.trim().toLowerCase();
      final hasCareer = opportunity.careers.any((c) {
        final orig = c.originalName.toLowerCase();
        final canon = c.canonicalName?.toLowerCase() ?? '';
        return orig.contains(targetCareer) ||
            canon.contains(targetCareer) ||
            targetCareer.contains(canon);
      });
      if (!hasCareer) return false;
    }

    if (locationQuery != null && locationQuery!.trim().isNotEmpty) {
      final loc = (opportunity.location ?? '').toLowerCase();
      if (!loc.contains(locationQuery!.trim().toLowerCase())) return false;
    }

    if (type != OpportunityTypeFilter.all) {
      final fullText =
          '${opportunity.title ?? ''} ${opportunity.originalContent}'
              .toLowerCase();
      if (type == OpportunityTypeFilter.practicas) {
        final isPractica = fullText.contains('práctica') ||
            fullText.contains('practica') ||
            fullText.contains('practicante');
        if (!isPractica) return false;
      } else if (type == OpportunityTypeFilter.laboral) {
        final isLaboral = fullText.contains('laboral') ||
            fullText.contains('empleo') ||
            fullText.contains('asistente') ||
            fullText.contains('analista') ||
            fullText.contains('coordinador') ||
            fullText.contains('supervisor') ||
            fullText.contains('especialista');
        if (!isLaboral) return false;
      }
    }

    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    if (validity == OpportunityValidityFilter.activeOnly) {
      if (opportunity.closingDate != null) {
        final closeDate = DateTime(
          opportunity.closingDate!.year,
          opportunity.closingDate!.month,
          opportunity.closingDate!.day,
        );
        if (closeDate.isBefore(today)) return false;
      }
    } else if (validity == OpportunityValidityFilter.expiredOnly) {
      if (opportunity.closingDate == null) return false;
      final closeDate = DateTime(
        opportunity.closingDate!.year,
        opportunity.closingDate!.month,
        opportunity.closingDate!.day,
      );
      if (!closeDate.isBefore(today)) return false;
    }

    if (closingDateStart != null) {
      if (opportunity.closingDate == null) return false;
      final closeDate = DateTime(
        opportunity.closingDate!.year,
        opportunity.closingDate!.month,
        opportunity.closingDate!.day,
      );
      final startDate = DateTime(
        closingDateStart!.year,
        closingDateStart!.month,
        closingDateStart!.day,
      );
      if (closeDate.isBefore(startDate)) return false;
    }

    if (closingDateEnd != null) {
      if (opportunity.closingDate == null) return false;
      final closeDate = DateTime(
        opportunity.closingDate!.year,
        opportunity.closingDate!.month,
        opportunity.closingDate!.day,
      );
      final endDate = DateTime(
        closingDateEnd!.year,
        closingDateEnd!.month,
        closingDateEnd!.day,
      );
      if (closeDate.isAfter(endDate)) return false;
    }

    return true;
  }
}
