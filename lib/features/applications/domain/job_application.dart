import 'package:matchunsa/features/applications/domain/job_application_status.dart';
import 'package:matchunsa/features/opportunities/domain/opportunity.dart';

class JobApplication {
  const JobApplication({
    required this.id,
    required this.userId,
    required this.opportunityId,
    required this.status,
    this.notes,
    this.appliedAt,
    this.createdAt,
    this.updatedAt,
    this.opportunity,
  });

  final String id;
  final String userId;
  final String opportunityId;
  final JobApplicationStatus status;
  final String? notes;
  final DateTime? appliedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Opportunity? opportunity;

  JobApplication copyWith({
    String? id,
    String? userId,
    String? opportunityId,
    JobApplicationStatus? status,
    String? notes,
    DateTime? appliedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    Opportunity? opportunity,
  }) {
    return JobApplication(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      opportunityId: opportunityId ?? this.opportunityId,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      appliedAt: appliedAt ?? this.appliedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      opportunity: opportunity ?? this.opportunity,
    );
  }
}
