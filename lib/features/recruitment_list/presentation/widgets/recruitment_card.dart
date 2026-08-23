import 'package:flutter/material.dart';

import '../../../../shared/formatters/display_number_formatter.dart';
import '../../domain/entities/party_recruitment.dart';

class RecruitmentCard extends StatelessWidget {
  final PartyRecruitment recruitment;

  const RecruitmentCard({super.key, required this.recruitment});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      key: ValueKey(recruitment.id),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    recruitment.title,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 12),
                _StatusBadge(status: recruitment.recruitmentStatus.status),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${recruitment.raid.raidName} - '
              '${recruitment.raid.difficultyName} '
              '(${recruitment.raid.difficultyAlias}) · '
              '${recruitment.raid.gateProgress.startGate}-'
              '${recruitment.raid.gateProgress.endGate}관문',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '리더: ${recruitment.leader.characterName} '
              '(${recruitment.leader.className})',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '멤버 '
                    '${recruitment.memberSummary.currentCount}/'
                    '${recruitment.memberSummary.maxCount}',
                  ),
                ),
                Expanded(
                  child: Text(
                    '딜러 '
                    '${recruitment.recruitmentStatus.roles.dealer.currentCount}/'
                    '${recruitment.recruitmentStatus.roles.dealer.targetCount}',
                  ),
                ),
                Expanded(
                  child: Text(
                    '서포터 '
                    '${recruitment.recruitmentStatus.roles.support.currentCount}/'
                    '${recruitment.recruitmentStatus.roles.support.targetCount}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '최소 전투력 ${DisplayNumberFormatter.integer(recruitment.requirements.minCombatPower)} '
              '/ 숙련도 ${_experienceLabel(recruitment.requirements.experienceLevel)}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  String _experienceLabel(ExperienceLevel level) {
    return switch (level) {
      ExperienceLevel.tryLevel => '트라이',
      ExperienceLevel.clearExp => '클경',
      ExperienceLevel.multiClearExp => '다클경',
      ExperienceLevel.semiExperienced => '반숙',
      ExperienceLevel.experienced => '숙련',
    };
  }
}

class _StatusBadge extends StatelessWidget {
  final RecruitmentStatusType status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: _backgroundColor(colorScheme),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          _label,
          style: TextStyle(
            color: _foregroundColor(colorScheme),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  String get _label {
    return switch (status) {
      RecruitmentStatusType.recruiting => '모집 중',
      RecruitmentStatusType.closed => '모집 마감',
      RecruitmentStatusType.completed => '완료',
    };
  }

  Color _backgroundColor(ColorScheme colorScheme) {
    return switch (status) {
      RecruitmentStatusType.recruiting => colorScheme.primaryContainer,
      RecruitmentStatusType.closed => colorScheme.surfaceContainerHighest,
      RecruitmentStatusType.completed => colorScheme.secondaryContainer,
    };
  }

  Color _foregroundColor(ColorScheme colorScheme) {
    return switch (status) {
      RecruitmentStatusType.recruiting => colorScheme.onPrimaryContainer,
      RecruitmentStatusType.closed => colorScheme.onSurfaceVariant,
      RecruitmentStatusType.completed => colorScheme.onSecondaryContainer,
    };
  }
}
