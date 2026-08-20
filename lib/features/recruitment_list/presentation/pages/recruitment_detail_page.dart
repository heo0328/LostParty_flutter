import 'package:flutter/material.dart';

import '../../../../shared/formatters/display_number_formatter.dart';
import '../../domain/entities/party_recruitment.dart';
import '../../domain/entities/recruitment_aggregate.dart';
import '../../domain/policies/approval_policy.dart';
import '../../domain/repositories/recruitment_state_repository.dart';

class RecruitmentDetailPage extends StatelessWidget {
  const RecruitmentDetailPage({
    required this.recruitmentId,
    required this.repository,
    super.key,
  });
  final String recruitmentId;
  final RecruitmentStateRepository repository;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('모집 상세')),
    body: FutureBuilder<RecruitmentAggregate?>(
      future: repository.getById(recruitmentId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final aggregate = snapshot.data;
        if (aggregate == null) {
          return const Center(child: Text('모집 정보를 찾을 수 없습니다.'));
        }
        final metadata = aggregate.metadata;
        final state = aggregate.state;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              aggregate.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              '${metadata.raidName} - ${metadata.difficultyName} (${metadata.difficultyAlias})',
            ),
            Text(
              '1-${metadata.gateCount}관문 · ${state.members.length}/${state.compositionPolicy.rules.totalMembers}명',
            ),
            const Divider(height: 32),
            Text('모집 조건', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '최소 전투력 ${DisplayNumberFormatter.integer(metadata.minCombatPower)}',
            ),
            Text('숙련도 ${_experience(metadata.experienceLevel)}'),
            Text(
              '최대 시간 ${metadata.maxPlayHours == null ? '클리어 시까지' : '${metadata.maxPlayHours}시간'}',
            ),
            Text('가입 승인 ${_approval(state.approvalPolicy)}'),
            const Divider(height: 32),
            Text('파티 구성', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (
              var party = 0;
              party < state.compositionPolicy.rules.partyCount;
              party++
            ) ...[
              Text(
                '${party + 1}파티',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              for (final member in state.members.where(
                (member) => member.partyIndex == party,
              ))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    member.role == PartyRole.support
                        ? Icons.health_and_safety
                        : Icons.sports_martial_arts,
                  ),
                  title: Text(member.characterId),
                  subtitle: Text(
                    '${member.className} · ${member.role == PartyRole.support ? '서포터' : '딜러'}',
                  ),
                ),
              if (!state.members.any((member) => member.partyIndex == party))
                const Text('아직 파티원이 없습니다.'),
            ],
          ],
        );
      },
    ),
  );
  String _experience(ExperienceLevel value) => switch (value) {
    ExperienceLevel.tryLevel => '트라이',
    ExperienceLevel.clearExp => '클경',
    ExperienceLevel.multiClearExp => '다클경',
    ExperienceLevel.semiExperienced => '반숙',
    ExperienceLevel.experienced => '숙련',
  };
  String _approval(ApprovalPolicy policy) => switch (policy.mode) {
    ApprovalMode.leaderOnly => '파티장 승인',
    ApprovalMode.anyMember => '파티원 승인',
    ApprovalMode.quorum => '${policy.requiredApprovals}명 이상 동의',
  };
}
