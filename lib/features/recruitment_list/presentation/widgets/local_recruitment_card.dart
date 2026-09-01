import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/formatters/display_number_formatter.dart';
import '../../domain/entities/party_recruitment.dart';
import '../../domain/entities/recruitment_aggregate.dart';

class LocalRecruitmentCard extends StatelessWidget {
  const LocalRecruitmentCard({
    required this.recruitment,
    required this.onTap,
    super.key,
  });

  final PublicRecruitmentSummary recruitment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final metadata = recruitment.metadata;
    final theme = Theme.of(context);
    return Card(
      key: ValueKey(recruitment.id),
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xxs,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.large),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      recruitment.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    alignment: WrapAlignment.end,
                    children: [
                      if (recruitment.isGroupOnly) const _GroupBadge(),
                      _StatusBadge(isRecruiting: recruitment.isRecruiting),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  _DifficultyChip(label: metadata.difficultyName),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      '${metadata.raidName} · 1-${metadata.gateCount}관문',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    _leaderName(recruitment),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${_memberLabel(recruitment)} · ${_requirementLabel(metadata)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isRecruiting});

  final bool isRecruiting;

  @override
  Widget build(BuildContext context) {
    final recruiting = isRecruiting;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: recruiting
            ? AppColors.successContainer
            : AppColors.warningContainer,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.small)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xxs,
        ),
        child: Text(
          recruiting ? '모집 중' : '완료',
          style: TextStyle(
            color: recruiting ? AppColors.success : AppColors.warning,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _GroupBadge extends StatelessWidget {
  const _GroupBadge();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.primarySubtle,
      borderRadius: BorderRadius.all(Radius.circular(AppRadius.small)),
    ),
    child: Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      child: Text(
        '그룹',
        style: TextStyle(
          color: AppColors.primaryStrong,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

class _DifficultyChip extends StatelessWidget {
  const _DifficultyChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: AppColors.primarySubtle,
      borderRadius: BorderRadius.all(Radius.circular(AppRadius.small)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.primaryStrong,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

String _memberLabel(PublicRecruitmentSummary recruitment) {
  final remaining = recruitment.maxMemberCount - recruitment.memberCount;
  return '멤버 ${recruitment.memberCount}/${recruitment.maxMemberCount} · '
      '${remaining > 0 ? '남은 자리 $remaining' : '자리 마감'}';
}

String _leaderName(PublicRecruitmentSummary recruitment) {
  final name = recruitment.leaderCharacterName?.trim();
  if (name == null || name.isEmpty) {
    return '파티장 정보 없음';
  }
  return name;
}

String _requirementLabel(RecruitmentMetadata metadata) {
  return '${metadata.minCombatPower == null ? '전투력 제한 없음' : '최소 전투력 ${DisplayNumberFormatter.integer(metadata.minCombatPower!)}'} · '
      '${metadata.experienceLevel == null ? '숙련도 제한 없음' : '숙련도 ${_experience(metadata.experienceLevel!)}'}';
}

String _experience(ExperienceLevel level) => switch (level) {
  ExperienceLevel.tryLevel => '트라이',
  ExperienceLevel.clearExp => '클경',
  ExperienceLevel.multiClearExp => '다클경',
  ExperienceLevel.semiExperienced => '반숙',
  ExperienceLevel.experienced => '숙련',
};
