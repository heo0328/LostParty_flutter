import 'package:flutter/material.dart';

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
    return Card(
      key: ValueKey(recruitment.id),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                recruitment.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '${metadata.raidName} - ${metadata.difficultyName} (${metadata.difficultyAlias}) · 1-${metadata.gateCount}관문',
              ),
              const SizedBox(height: 8),
              Text(
                '멤버 ${recruitment.memberCount}/${recruitment.maxMemberCount} · ${metadata.minCombatPower == null ? '전투력 제한 없음' : '최소 전투력 ${DisplayNumberFormatter.integer(metadata.minCombatPower!)}'}',
              ),
              const SizedBox(height: 4),
              Text(
                metadata.experienceLevel == null
                    ? '클리어 경험 제한 없음'
                    : '숙련도 ${_experience(metadata.experienceLevel!)}',
                style: Theme.of(context).textTheme.bodySmall,
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
