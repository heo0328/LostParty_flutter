import 'package:flutter_test/flutter_test.dart';

import 'package:lost_party/features/recruitment_list/domain/entities/party_create_command.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_recruitment.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/recruitment_aggregate.dart';
import 'package:lost_party/features/recruitment_list/domain/policies/approval_policy.dart';
import 'package:lost_party/features/recruitment_list/domain/policies/party_composition_policy.dart';
import 'package:lost_party/features/recruitment_list/domain/services/party_create_command_validator.dart';

void main() {
  const validator = PartyCreateCommandValidator();

  test('accepts a valid create command', () {
    expect(validator.validate(_command()), isNull);
  });

  test('rejects a path-like recruitment id', () {
    expect(
      validator.validate(_command(recruitmentId: 'invalid/id')),
      PartyCreateFailure.invalidRequest,
    );
  });

  test('rejects a leader below the catalog item level', () {
    expect(
      validator.validate(_command(leaderItemLevel: 1699.99)),
      PartyCreateFailure.invalidRequest,
    );
  });

  test('rejects group visibility without a group id', () {
    expect(
      validator.validate(
        _command(visibility: RecruitmentVisibility.group),
      ),
      PartyCreateFailure.invalidRequest,
    );
  });

  test('accepts a group raid with a group id', () {
    expect(
      validator.validate(
        _command(groupId: 'group-1', visibility: RecruitmentVisibility.group),
      ),
      isNull,
    );
  });

  test('accepts a public group raid that keeps its group id', () {
    expect(
      validator.validate(
        _command(groupId: 'group-1', visibility: RecruitmentVisibility.public),
      ),
      isNull,
    );
  });
}

PartyCreateCommand _command({
  String recruitmentId = 'recruitment-1',
  double leaderItemLevel = 1710,
  String? groupId,
  String visibility = RecruitmentVisibility.public,
}) => PartyCreateCommand(
  recruitmentId: recruitmentId,
  title: '4막 노말',
  metadata: const RecruitmentMetadata(
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
    maxPlayHours: null,
  ),
  leaderCharacterId: 'character-1',
  leaderCharacterName: '캐릭터',
  leaderClassName: '바드',
  leaderRole: PartyRole.support,
  leaderItemLevel: leaderItemLevel,
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
