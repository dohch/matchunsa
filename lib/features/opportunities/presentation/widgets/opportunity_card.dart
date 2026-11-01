import 'package:flutter/material.dart';
import 'package:matchunsa/app/theme/app_theme.dart';
import 'package:matchunsa/app/widgets/mu_motion.dart';
import 'package:matchunsa/app/widgets/mu_surface.dart';
import 'package:matchunsa/features/applications/domain/application_repository.dart';
import 'package:matchunsa/features/opportunities/domain/opportunity.dart';
import 'package:matchunsa/features/opportunities/domain/opportunity_repository.dart';
import 'package:matchunsa/features/opportunities/presentation/opportunity_detail_page.dart';

class OpportunityCard extends StatelessWidget {
  const OpportunityCard({
    super.key,
    required this.opportunity,
    this.userId,
    this.isFavorite = false,
    this.onToggleFavorite,
    this.opportunityRepository,
    this.applicationRepository,
  });

  final Opportunity opportunity;
  final String? userId;
  final bool isFavorite;
  final Future<bool> Function()? onToggleFavorite;
  final OpportunityRepository? opportunityRepository;
  final ApplicationRepository? applicationRepository;

  void _openDetail(BuildContext context) {
    Navigator.of(context).push<void>(
      MuPageTransition(
        page: OpportunityDetailPage(
          opportunity: opportunity,
          userId: userId,
          isFavorite: isFavorite,
          onToggleFavorite: onToggleFavorite,
          opportunityRepository: opportunityRepository,
          applicationRepository: applicationRepository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _clean(opportunity.title);
    final company = _clean(opportunity.company);
    final careers =
        opportunity.careers.map((career) => career.displayName).toList();
    final requirements = _clean(opportunity.requirements);
    final initials =
        (company ?? title ?? 'M').trim().substring(0, 1).toUpperCase();

    return MuScaleTap(
      onTap: () => _openDetail(context),
      child: MuSurface(
        padding: const EdgeInsets.all(20),
        onTap: () => _openDetail(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Company avatar with subtle maroon gradient.
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.maroon.withValues(alpha: 0.14),
                        AppTheme.maroon.withValues(alpha: 0.06),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: AppTheme.maroon,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(company ?? 'Convocatoria laboral',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 3),
                      Text('Oportunidad para la comunidad UNSA',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                if (onToggleFavorite != null)
                  MuFavoriteButton(
                    isFavorite: isFavorite,
                    onPressed: onToggleFavorite,
                  ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.navy.withValues(alpha: .07),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Convocatoria',
                    style: TextStyle(
                        color: AppTheme.navy,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              title ?? 'Oportunidad laboral',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontSize: 21),
            ),
            if (opportunity.academicProfile?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 5),
              Text(opportunity.academicProfile!,
                  style: Theme.of(context).textTheme.bodyMedium),
            ],
            if (requirements != null) ...[
              const SizedBox(height: 12),
              Text(
                requirements,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ] else if (title == null && company == null) ...[
              const SizedBox(height: 12),
              Text(_excerpt(opportunity.originalContent),
                  maxLines: 3, overflow: TextOverflow.ellipsis),
            ],
            if (careers.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 7,
                runSpacing: 6,
                children: careers
                    .take(4)
                    .map((career) => _Tag(label: career))
                    .toList(),
              ),
            ],
            const SizedBox(height: 15),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_clean(opportunity.location) case final location?)
                  _MetaPill(icon: Icons.location_on_outlined, label: location),
                if (opportunity.vacancies case final vacancies?)
                  _MetaPill(
                      icon: Icons.groups_2_outlined,
                      label: '$vacancies vacantes'),
                if (opportunity.closingDate case final date?)
                  _MetaPill(icon: Icons.event_outlined, label: _formatDate(date)),
                if (_clean(opportunity.cvType) case final cvType?)
                  _MetaPill(
                      icon: Icons.description_outlined, label: 'CV $cvType'),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.verified_user_outlined,
                    size: 18, color: AppTheme.navy.withValues(alpha: .7)),
                const SizedBox(width: 7),
                Expanded(
                  child: Text('Información recibida por canales institucionales',
                      style: Theme.of(context).textTheme.bodySmall),
                ),
                TextButton.icon(
                  onPressed: () => _openDetail(context),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('Ver detalles'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFF2E8E9),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(label,
            style: const TextStyle(
                color: AppTheme.maroon,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      );
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F6F8),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: AppTheme.navy.withValues(alpha: .8)),
            const SizedBox(width: 5),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
}

String? _clean(String? value) {
  final result = value?.trim();
  return result == null || result.isEmpty ? null : result;
}

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

String _excerpt(String content) {
  final normalized = content.replaceAll(RegExp(r'\s+'), ' ').trim();
  return normalized.length <= 160
      ? normalized
      : '${normalized.substring(0, 160)}…';
}
