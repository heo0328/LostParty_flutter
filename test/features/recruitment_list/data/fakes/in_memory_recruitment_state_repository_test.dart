import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/data/fakes/in_memory_recruitment_state_repository.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_recruitment.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/recruitment_aggregate.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/recruitment_application.dart';
import 'package:lost_party/features/recruitment_list/domain/policies/approval_policy.dart';
import 'package:lost_party/features/recruitment_list/domain/policies/party_composition_policy.dart';
import 'package:lost_party/features/recruitment_list/domain/state/recruitment_state_machine.dart';

void main() {
  test('revision이 일치하는 변경만 저장한다', () async {
    final repository = InMemoryRecruitmentStateRepository();
    final initial = _aggregate();
    await repository.create(initial);

    final first = await repository.updateIfRevision(
      recruitmentId: initial.id,
      expectedRevision: 0,
      nextState: initial.state,
      updatedAt: DateTime.utc(2026, 8, 20, 0, 1),
    );
    final stale = await repository.updateIfRevision(
      recruitmentId: initial.id,
      expectedRevision: 0,
      nextState: initial.state,
      updatedAt: DateTime.utc(2026, 8, 20, 0, 2),
    );

    expect(first!.revision, 1);
    expect(stale, isNull);
    expect((await repository.getById(initial.id))!.revision, 1);
    expect(
      (await repository.getById(initial.id))!.updatedAt,
      DateTime.utc(2026, 8, 20, 0, 1),
    );
  });

  test('모집 중인 공개 읽기 모델만 최신 갱신 순으로 반환한다', () async {
    final repository = InMemoryRecruitmentStateRepository();
    await repository.create(_aggregate(id: 'old'));
    await repository.create(
      _aggregate(id: 'new', updatedAt: DateTime.utc(2026, 8, 20, 1)),
    );
    await repository.create(_aggregate(id: 'closed', isRecruiting: false));

    final summaries = await repository.getPublicRecruitments();

    expect(summaries.map((summary) => summary.id), ['new', 'old']);
    expect(summaries.first.memberCount, 1);
    expect(summaries.first.maxMemberCount, 4);
  });
}

RecruitmentAggregate _aggregate({
  String id = 'recruitment',
  DateTime? updatedAt,
  bool isRecruiting = true,
}) {
  final timestamp = updatedAt ?? DateTime.utc(2026, 8, 20);
  return RecruitmentAggregate(
    id: id,
    title: '테스트 모집',
    metadata: _metadata,
    state: RecruitmentState(
      leaderUserId: 'leader',
      approvalPolicy: const ApprovalPolicy.anyMember(),
      compositionPolicy: _compositionPolicy,
      members: const [
        RecruitmentPartyMember(
          userId: 'leader',
          characterId: 'leader-character',
          className: '바드',
          role: PartyRole.support,
          partyIndex: 0,
        ),
      ],
      isRecruiting: isRecruiting,
    ),
    revision: 0,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

const _compositionPolicy = PartyCompositionPolicy(
  RecruitmentPartyRules(
    partyCount: 1,
    membersPerParty: 4,
    supportsPerParty: 1,
    maxDealersPerClassPerParty: 1,
  ),
);

const _metadata = RecruitmentMetadata(
  catalogVersion: 'test',
  raidId: 'serca',
  difficultyId: 'normal',
  raidName: '세르카',
  difficultyName: '노말',
  difficultyAlias: '노르카',
  gateCount: 2,
  minItemLevel: 1710,
  minCombatPower: 200000,
  experienceLevel: ExperienceLevel.clearExp,
  maxPlayHours: 3,
);
