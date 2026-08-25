import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/formatters/display_number_formatter.dart';
import '../../../../shared/formatters/korea_time_formatter.dart';
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
        vertical: AppSpacing.xs,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.large),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
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
                  const _RecruitingBadge(),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _DifficultyChip(label: metadata.difficultyName),
                  Text(
                    '${metadata.raidName} · 1-${metadata.gateCount}관문',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              _InfoLine(
                icon: Icons.schedule_outlined,
                text: metadata.raidStartAt == null
                    ? '시작 시간 미정'
                    : KoreaTimeFormatter.dayAndTime(metadata.raidStartAt!),
              ),
              const SizedBox(height: AppSpacing.xs),
              _InfoLine(
                icon: Icons.groups_outlined,
                text: _memberLabel(recruitment),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${metadata.minCombatPower == null ? '전투력 제한 없음' : '최소 전투력 ${DisplayNumberFormatter.integer(metadata.minCombatPower!)}'} · '
                '${metadata.experienceLevel == null ? '숙련도 제한 없음' : '숙련도 ${_experience(metadata.experienceLevel!)}'}',
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

  String _experience(ExperienceLevel level) => switch (level) {
    ExperienceLevel.tryLevel => '트라이',
    ExperienceLevel.clearExp => '클경',
    ExperienceLevel.multiClearExp => '다클경',
    ExperienceLevel.semiExperienced => '반숙',
    ExperienceLevel.experienced => '숙련',
  };
}

class _RecruitingBadge extends StatelessWidget {
  const _RecruitingBadge();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.successContainer,
      borderRadius: BorderRadius.all(Radius.circular(AppRadius.small)),
    ),
    child: Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      child: Text(
        '모집 중',
        style: TextStyle(
          color: AppColors.success,
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

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 16, color: AppColors.textSecondary),
      const SizedBox(width: AppSpacing.smallGap),
      Expanded(
        child: Text(
          text,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
      ),
    ],
  );
}

String _memberLabel(PublicRecruitmentSummary recruitment) {
  final remaining = recruitment.maxMemberCount - recruitment.memberCount;
  return '멤버 ${recruitment.memberCount}/${recruitment.maxMemberCount} · '
      '${remaining > 0 ? '남은 자리 $remaining' : '자리 마감'}';
}
