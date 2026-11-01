import 'package:matchunsa/features/opportunities/domain/opportunity_career.dart';

class Opportunity {
  const Opportunity({
    required this.id,
    required this.careers,
    required this.originalContent,
    this.title,
    this.company,
    this.academicProfile,
    this.location,
    this.closingDate,
    this.vacancies,
    this.requirements,
    this.desiredKnowledge,
    this.functions,
    this.additionalInformation,
    this.applicationUrl,
    this.applicationEmail,
    this.applicationPhone,
    this.cvType,
    this.isActive = true,
  });

  final String id;
  final String? title;
  final String? company;
  final List<OpportunityCareer> careers;
  final String originalContent;
  final String? academicProfile;
  final String? location;
  final DateTime? closingDate;
  final int? vacancies;
  final String? requirements;
  final String? desiredKnowledge;
  final String? functions;
  final String? additionalInformation;
  final String? applicationUrl;
  final String? applicationEmail;
  final String? applicationPhone;
  final String? cvType;
  final bool isActive;
}
