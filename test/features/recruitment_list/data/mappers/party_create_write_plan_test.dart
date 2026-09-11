import 'package:flutter_test/flutter_test.dart';

import 'package:lost_party/features/recruitment_list/data/mappers/party_create_write_plan.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_create_command.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_recruitment.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/recruitment_aggregate.dart';
import 'package:lost_party/features/recruitment_list/domain/policies/approval_policy.dart';
import 'package:lost_party/features/recruitment_list/domain/policies/party_composition_policy.dart';
import 'package:lost_party/shared/character_build/party_gem_validation_snapshot.dart';

void main() {
  test('creates matching recruitment, leader membership and assignment maps', () {
    final timestamp = Object();
    final plan = PartyCreateWritePlan.fromCommand(
      command: _command(),
      playerId: 'player-1',
      serverTimestamp: timestamp,
      verifiedCharacterName: '검증된캐릭터',
      verifiedClassName: '바드',
      verifiedItemLevel: 1715.25,
    );

    expect(plan.recruitment['visibility'], 'public');
    expect(plan.recruitment['groupId'], isNull);
    expect(plan.recruitment['leaderPlayerId'], 'player-1');
    expect(plan.recruitment['leaderCharacterNameSnapshot'], '검증된캐릭터');
    expect(plan.recruitment['leaderClassNameSnapshot'], '바드');
    expect(plan.recruitment['memberPlayerIds'], ['player-1']);
    expect(plan.recruitment['memberCount'], 1);
    expect(plan.recruitment['revision'], 1);
    expect(plan.recruitment['createdAt'], same(timestamp));

    expect(plan.leaderMembership['playerId'], 'player-1');
    expect(plan.leaderMembership['characterId'], 'character-1');
    expect(plan.leaderMembership['characterNameSnapshot'], '검증된캐릭터');
    expect(plan.leaderMembership['classNameSnapshot'], '바드');
    expect(plan.leaderMembership['itemLevelSnapshot'], 1715.25);
    expect(plan.leaderMembership['canApproveApplications'], isTrue);
    expect(plan.leaderMembership['partyIndex'], 0);
    expect(plan.leaderMembership['slotIndex'], 0);

    expect(plan.assignment['playerId'], 'player-1');
    expect(plan.assignment['characterId'], 'character-1');
    expect(plan.assignment['raidId'], 'act4');
    expect(plan.assignment['recruitmentId'], 'recruitment-1');
    expect(plan.assignment['role'], 'support');
  });

  test('uses the requested approval and party composition policies', () {
    final plan = PartyCreateWritePlan.fromCommand(
      command: _command(),
      playerId: 'player-1',
      serverTimestamp: Object(),
      verifiedCharacterName: '검증된캐릭터',
      verifiedClassName: '바드',
      verifiedItemLevel: 1715.25,
    );

    expect(plan.recruitment['approvalPolicy'], {
      'mode': 'leaderOnly',
      'requiredApprovals': 1,
      'leaderVoteRequired': true,
      'rejectionMode': 'anyAuthorizedMember',
    });
    expect(plan.recruitment['partyCount'], 2);
    expect(plan.recruitment['membersPerParty'], 4);
    expect(plan.recruitment['supportsPerParty'], 1);
    expect(plan.recruitment['maxMemberCount'], 8);
    expect(plan.recruitment['supportCount'], 1);
    expect(plan.recruitment['dealerCount'], 0);
  });

  test('stores the selected leader gem validation in membership only', () {
    final validatedAt = DateTime.utc(2026, 9, 12);
    final plan = PartyCreateWritePlan.fromCommand(
      command: _command(
        leaderGemValidation: PartyGemValidationSnapshot(
          status: PartyGemValidationStatus.error,
          foreignClassGemCount: 0,
          unverifiedSameClassGemCount: 0,
          validatedAt: validatedAt,
          catalogVersion: '2026.09.08',
          schemaVersion: 2,
          equippedGemCount: 11,
          unmatchedSkillGemCount: 1,
        ),
      ),
      playerId: 'player-1',
      serverTimestamp: Object(),
      verifiedCharacterName: '검증된캐릭터',
      verifiedClassName: '바드',
      verifiedItemLevel: 1715.25,
    );

    expect(plan.leaderMembership['gemValidationSnapshot'], {
      'gemValidationSchemaVersion': 2,
      'gemValidationStatus': 'error',
      'equippedGemCount': 11,
      'foreignClassGemCount': 0,
      'unmatchedSkillGemCount': 1,
      'gemValidatedAt': validatedAt,
      'catalogVersion': '2026.09.08',
    });
    expect(plan.recruitment, isNot(contains('gemValidationSnapshot')));
    expect(plan.assignment, isNot(contains('gemValidationSnapshot')));
  });

  test('stores a single group id and group visibility for group raids', () {
    final plan = PartyCreateWritePlan.fromCommand(
      command: _command(
        groupId: 'group-1',
        visibility: RecruitmentVisibility.group,
      ),
      playerId: 'player-1',
      serverTimestamp: Object(),
      verifiedCharacterName: '검증된캐릭터',
      verifiedClassName: '바드',
      verifiedItemLevel: 1715.25,
    );

    expect(plan.recruitment['groupId'], 'group-1');
    expect(plan.recruitment['visibility'], RecruitmentVisibility.group);
    expect(plan.groupRaidListing, same(plan.recruitment));
  });

  test('omits a group listing for public raids', () {
    final plan = PartyCreateWritePlan.fromCommand(
      command: _command(),
      playerId: 'player-1',
      serverTimestamp: Object(),
      verifiedCharacterName: '검증된캐릭터',
      verifiedClassName: '바드',
      verifiedItemLevel: 1715.25,
    );

    expect(plan.groupRaidListing, isNull);
  });
}

PartyCreateCommand _command({
  String? groupId,
  String visibility = RecruitmentVisibility.public,
  PartyGemValidationSnapshot? leaderGemValidation,
}) => PartyCreateCommand(
  recruitmentId: 'recruitment-1',
  title: '4막 노말',
  metadata: RecruitmentMetadata(
    catalogVersion: 'v1',
    raidId: 'act4',
    difficultyId: 'normal',
    raidName: '4막',
    difficultyName: '노말',
    difficultyAlias: '노말',
    gateCount: 3,
    minItemLevel: 1700,
    minCombatPower: null,
    experienceLevel: ExperienceLevel.experienced,
    maxPlayHours: 2,
    raidStartAt: DateTime.utc(2026, 8, 26, 12),
  ),
  leaderCharacterId: 'character-1',
  leaderCharacterName: '클라이언트캐릭터',
  leaderClassName: '클라이언트직업',
  leaderRole: PartyRole.support,
  leaderItemLevel: 1715.25,
  leaderCombatPower: 120000000,
  leaderGemValidation: leaderGemValidation,
  approvalPolicy: const ApprovalPolicy.leaderOnly(),
  compositionRules: const RecruitmentPartyRules(
    partyCount: 2,
    membersPerParty: 4,
    supportsPerParty: 1,
    maxDealersPerClassPerParty: 1,
  ),
  cycleKey: '2026-08-26',
  groupId: groupId,
  visibility: visibility,
);
