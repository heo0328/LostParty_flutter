import 'package:flutter_test/flutter_test.dart';

import 'package:lost_party/features/recruitment_list/data/dto/party_read_document_dto.dart';
import 'package:lost_party/features/recruitment_list/data/mappers/party_read_document_mapper.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_read_models.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_recruitment.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/recruitment_application.dart';
import 'package:lost_party/features/recruitment_list/domain/policies/approval_policy.dart';

void main() {
  final mapper = PartyReadDocumentMapper(
    toDateTime: (value) => value as DateTime,
  );

  test('maps a public recruitment document', () {
    final summary = mapper.toPublicRecruitment(
      PartyReadDocumentDto(id: 'raid-1', data: _recruitmentData()),
    );

    expect(summary.id, 'raid-1');
    expect(summary.leaderUserId, 'player-leader');
    expect(summary.leaderCharacterName, '리더캐릭');
    expect(summary.leaderClassName, '바드');
    expect(summary.membersPerParty, 4);
    expect(summary.partyCount, 2);
    expect(summary.supportsPerParty, 1);
    expect(summary.maxDealersPerClassPerParty, 1);
    expect(summary.dealerCount, 3);
    expect(summary.supportCount, 1);
    expect(summary.maxDealerCount, 6);
    expect(summary.maxSupportCount, 2);
    expect(summary.approvalMode, ApprovalMode.leaderOnly);
    expect(summary.metadata.raidId, 'act4');
    expect(summary.metadata.experienceLevel, ExperienceLevel.experienced);
    expect(summary.isRecruiting, isTrue);
    expect(summary.status, 'active');
    expect(summary.currentCycleStatus, 'active');
    expect(summary.continueTogether, isFalse);
    expect(summary.cycleEndsAt, DateTime.utc(2026, 8, 26, 21));
    expect(summary.visibility, 'public');
    expect(summary.groupId, isNull);
    expect(summary.memberPlayerIds, {'player-leader', 'player-member'});
  });

  test('excludes leader or confirmed member rooms from the public list', () {
    final led = PartyReadDocumentDto(id: 'raid-led', data: _recruitmentData());
    expect(
      mapper.isCurrentPlayerOwnPublicRecruitment(
        led,
        currentPlayerId: 'player-leader',
      ),
      isTrue,
    );

    final memberOnly = PartyReadDocumentDto(
      id: 'raid-member',
      data: _recruitmentData()
        ..['leaderPlayerId'] = 'other-leader'
        ..['memberPlayerIds'] = <Object?>['player-1', 'player-leader'],
    );
    expect(
      mapper.isCurrentPlayerOwnPublicRecruitment(
        memberOnly,
        currentPlayerId: 'player-1',
      ),
      isTrue,
    );
    expect(
      mapper.isCurrentPlayerOwnPublicRecruitment(
        memberOnly,
        currentPlayerId: 'player-leader',
      ),
      isTrue,
    );

    final pendingOnly = PartyReadDocumentDto(
      id: 'raid-pending',
      data: _recruitmentData()
        ..['leaderPlayerId'] = 'other-leader'
        ..['memberPlayerIds'] = <Object?>['other-leader', 'other-member'],
    );
    expect(
      mapper.isCurrentPlayerOwnPublicRecruitment(
        pendingOnly,
        currentPlayerId: 'player-1',
      ),
      isFalse,
    );

    final leaderMissingFromMembers = PartyReadDocumentDto(
      id: 'raid-anomaly',
      data: _recruitmentData()
        ..['leaderPlayerId'] = 'player-1'
        ..['memberPlayerIds'] = <Object?>['other-member'],
    );
    expect(
      mapper.isCurrentPlayerOwnPublicRecruitment(
        leaderMissingFromMembers,
        currentPlayerId: 'player-1',
      ),
      isTrue,
    );

    expect(
      mapper.isCurrentPlayerOwnPublicRecruitment(
        pendingOnly,
        currentPlayerId: '',
      ),
      isFalse,
    );
  });

  test('marks an owned active raid for the current player', () {
    final summary = mapper.toActiveRaid(
      PartyReadDocumentDto(id: 'raid-1', data: _recruitmentData()),
      currentPlayerId: 'player-leader',
    );

    expect(summary.currentCycleKey, '2026-08-19');
    expect(summary.isOwnedByCurrentPlayer, isTrue);
    expect(summary.leaderCharacterName, '리더캐릭');
    expect(summary.leaderClassName, '바드');
    expect(summary.raidStartAt, DateTime.utc(2026, 8, 25, 12));
    expect(summary.status, 'active');
    expect(summary.currentCycleStatus, 'active');
    expect(summary.continueTogether, isFalse);
    expect(summary.isAwaitingDisband, isFalse);
    expect(summary.visibility, 'public');
    expect(summary.isGroupOnly, isFalse);
    expect(summary.memberPlayerIds, {'player-leader', 'player-member'});
  });

  test(
    'maps a member display document with opaque player and character ids',
    () {
      final member = mapper.toMemberDisplay(
        PartyReadDocumentDto(
          id: 'player-member',
          data: {
            'schemaVersion': 1,
            'playerId': 'player-member',
            'characterId': 'character-2',
            'characterNameSnapshot': '딜러캐릭',
            'classNameSnapshot': '블레이드',
            'role': 'dealer',
            'partyIndex': 1,
            'slotIndex': 2,
            'itemLevelSnapshot': 1710.5,
            'combatPowerSnapshot': 250000,
            'canApproveApplications': false,
            'gemValidationSnapshot': {
              'gemValidationStatus': 'foreignClass',
              'foreignClassGemCount': 1,
              'unverifiedSameClassGemCount': 0,
              'gemValidatedAt': DateTime.utc(2026, 9, 7),
              'catalogVersion': '2026.09.08',
            },
          },
        ),
      );

      expect(member.playerId, 'player-member');
      expect(member.characterId, 'character-2');
      expect(member.characterName, '딜러캐릭');
      expect(member.className, '블레이드');
      expect(member.role, PartyRole.dealer);
      expect(member.partyIndex, 1);
      expect(member.slotIndex, 2);
      expect(member.itemLevel, 1710.5);
      expect(member.combatPower, 250000);
      expect(member.gemValidation?.status.name, 'foreignClass');
      expect(member.gemValidation?.foreignClassGemCount, 1);
    },
  );

  test('tolerates missing member gem validation without blocking display', () {
    final member = mapper.toMemberDisplay(
      PartyReadDocumentDto(
        id: 'player-member',
        data: {
          'schemaVersion': 1,
          'role': 'support',
          'partyIndex': 0,
          'itemLevelSnapshot': 1700,
          'combatPowerSnapshot': 100000,
          'gemValidationSnapshot': {'gemValidationStatus': 'foreignClass'},
        },
      ),
    );
    expect(member.itemLevel, 1700);
    expect(member.combatPower, 100000);
    expect(member.gemValidation, isNull);
  });

  test('tolerates missing leader and member display snapshots', () {
    final data = _recruitmentData()
      ..remove('leaderCharacterNameSnapshot')
      ..remove('leaderClassNameSnapshot');
    final summary = mapper.toPublicRecruitment(
      PartyReadDocumentDto(id: 'raid-1', data: data),
    );
    expect(summary.leaderCharacterName, isNull);
    expect(summary.leaderClassName, isNull);

    final member = mapper.toMemberDisplay(
      PartyReadDocumentDto(
        id: 'player-member',
        data: {'schemaVersion': 1, 'role': 'support', 'partyIndex': 0},
      ),
    );
    expect(member.characterName, isNull);
    expect(member.className, isNull);
    expect(member.playerId, 'player-member');
    expect(member.characterId, isNull);
    expect(member.slotIndex, isNull);
    expect(member.itemLevel, isNull);
    expect(member.combatPower, isNull);
  });

  test('public mapper keeps unknown memberPlayerIds distinct from empty', () {
    final data = _recruitmentData()..remove('memberPlayerIds');
    final summary = mapper.toPublicRecruitment(
      PartyReadDocumentDto(id: 'raid-1', data: data),
    );
    expect(summary.memberPlayerIds, isNull);
  });

  test('maps slotIndex when present and ignores invalid values', () {
    final missing = mapper.toMemberDisplay(
      PartyReadDocumentDto(
        id: 'player-member',
        data: {'schemaVersion': 1, 'role': 'dealer', 'partyIndex': 0},
      ),
    );
    expect(missing.slotIndex, isNull);

    final invalid = mapper.toMemberDisplay(
      PartyReadDocumentDto(
        id: 'player-member',
        data: {
          'schemaVersion': 1,
          'role': 'dealer',
          'partyIndex': 0,
          'slotIndex': -1,
        },
      ),
    );
    expect(invalid.slotIndex, isNull);
  });

  test('sorts members by party then slot without inferring missing seats', () {
    const later = PartyMemberDisplay(
      playerId: 'player-later',
      characterName: '후발',
      className: '바드',
      role: PartyRole.support,
      partyIndex: 0,
      slotIndex: 2,
    );
    const first = PartyMemberDisplay(
      playerId: 'player-first',
      characterName: '리더',
      className: '블레이드',
      role: PartyRole.dealer,
      partyIndex: 0,
      slotIndex: 0,
    );
    const unknown = PartyMemberDisplay(
      playerId: 'player-unknown',
      characterName: '이전멤버',
      className: '워로드',
      role: PartyRole.dealer,
      partyIndex: 0,
    );
    const secondParty = PartyMemberDisplay(
      playerId: 'player-2',
      characterName: '2파티',
      className: '기공사',
      role: PartyRole.dealer,
      partyIndex: 1,
      slotIndex: 0,
    );

    final ordered = [later, secondParty, unknown, first]
      ..sort((left, right) => left.compareByPartySlot(right));

    expect(ordered.map((member) => member.characterName), [
      '리더',
      '후발',
      '이전멤버',
      '2파티',
    ]);
  });

  test('maps an application document without treating it as membership', () {
    final summary = mapper.toApplication(
      PartyReadDocumentDto(
        id: 'player-applicant',
        data: {
          'schemaVersion': 1,
          'recruitmentId': 'raid-1',
          'applicantPlayerId': 'player-applicant',
          'cycleKey': '2026-08-19',
          'characterId': 'character-1',
          'characterNameSnapshot': '아르카나',
          'classNameSnapshot': '아르카나',
          'requestedRole': 'dealer',
          'status': 'pending',
          'revision': 1,
          'resolutionReason': null,
          'createdAt': DateTime.utc(2026, 8, 24),
          'decidedAt': null,
          'updatedAt': DateTime.utc(2026, 8, 25),
        },
      ),
    );

    expect(summary.status, RecruitmentApplicationStatus.pending);
    expect(summary.requestedRole, PartyRole.dealer);
    expect(summary.recruitmentId, 'raid-1');
    expect(summary.revision, 1);
    expect(summary.rejectionCount, 0);
    // submittedBuildSnapshot 없으면 null
    expect(summary.itemLevel, isNull);
    expect(summary.combatPower, isNull);
  });

  test('maps submittedBuildSnapshot itemLevel and combatPower', () {
    final summary = mapper.toApplication(
      PartyReadDocumentDto(
        id: 'player-applicant',
        data: {
          'schemaVersion': 1,
          'recruitmentId': 'raid-1',
          'applicantPlayerId': 'player-applicant',
          'cycleKey': '2026-08-19',
          'characterId': 'character-1',
          'characterNameSnapshot': '아르카나',
          'classNameSnapshot': '아르카나',
          'requestedRole': 'dealer',
          'status': 'pending',
          'revision': 1,
          'createdAt': DateTime.utc(2026, 8, 24),
          'updatedAt': DateTime.utc(2026, 8, 25),
          'submittedBuildSnapshot': {
            'itemLevel': 1780.83,
            'combatPower': 123456789,
          },
        },
      ),
    );

    expect(summary.itemLevel, closeTo(1780.83, 0.01));
    expect(summary.combatPower, closeTo(123456789, 1));
  });

  test('maps optional gem validation snapshot', () {
    final summary = mapper.toApplication(
      PartyReadDocumentDto(
        id: 'player-applicant',
        data: {
          'schemaVersion': 1,
          'recruitmentId': 'raid-1',
          'applicantPlayerId': 'player-applicant',
          'cycleKey': '2026-09-02',
          'characterId': 'character-1',
          'characterNameSnapshot': '데모닉',
          'classNameSnapshot': '데모닉',
          'requestedRole': 'dealer',
          'status': 'pending',
          'revision': 1,
          'createdAt': DateTime.utc(2026, 9, 8),
          'updatedAt': DateTime.utc(2026, 9, 8),
          'submittedBuildSnapshot': {
            'itemLevel': 1780,
            'combatPower': 123456,
            'gemValidationStatus': 'foreignClass',
            'foreignClassGemCount': 1,
            'unverifiedSameClassGemCount': 0,
            'gemValidatedAt': DateTime.utc(2026, 9, 7),
            'catalogVersion': '2026.09.04',
          },
        },
      ),
    );

    expect(summary.gemValidation?.status.name, 'foreignClass');
    expect(summary.gemValidation?.foreignClassGemCount, 1);
    expect(summary.gemValidation?.catalogVersion, '2026.09.04');
  });

  test(
    'ignores incomplete gem validation fields while keeping build values',
    () {
      final summary = mapper.toApplication(
        PartyReadDocumentDto(
          id: 'player-applicant',
          data: {
            'schemaVersion': 1,
            'recruitmentId': 'raid-1',
            'applicantPlayerId': 'player-applicant',
            'cycleKey': '2026-09-02',
            'characterId': 'character-1',
            'characterNameSnapshot': '데모닉',
            'classNameSnapshot': '데모닉',
            'requestedRole': 'dealer',
            'status': 'pending',
            'revision': 1,
            'createdAt': DateTime.utc(2026, 9, 8),
            'updatedAt': DateTime.utc(2026, 9, 8),
            'submittedBuildSnapshot': {
              'itemLevel': 1780,
              'combatPower': 123456,
              'gemValidationStatus': 'foreignClass',
            },
          },
        ),
      );

      expect(summary.itemLevel, 1780);
      expect(summary.gemValidation, isNull);
    },
  );

  test('ignores malformed submittedBuildSnapshot gracefully', () {
    final summary = mapper.toApplication(
      PartyReadDocumentDto(
        id: 'player-applicant',
        data: {
          'schemaVersion': 1,
          'recruitmentId': 'raid-1',
          'applicantPlayerId': 'player-applicant',
          'cycleKey': '2026-08-19',
          'characterId': 'character-1',
          'characterNameSnapshot': '아르카나',
          'classNameSnapshot': '아르카나',
          'requestedRole': 'dealer',
          'status': 'pending',
          'revision': 1,
          'createdAt': DateTime.utc(2026, 8, 24),
          'updatedAt': DateTime.utc(2026, 8, 25),
          'submittedBuildSnapshot': 'not-a-map',
        },
      ),
    );

    // 비정상 snapshot은 null로 처리하며 예외를 던지지 않는다
    expect(summary.itemLevel, isNull);
    expect(summary.combatPower, isNull);
  });

  test('rejects an unsupported schema version', () {
    final data = _recruitmentData()..['schemaVersion'] = 2;

    expect(
      () => mapper.toPublicRecruitment(
        PartyReadDocumentDto(id: 'raid-1', data: data),
      ),
      throwsA(isA<PartyReadContractException>()),
    );
  });

  test('rejects an unknown application status', () {
    expect(
      () => mapper.toApplication(
        PartyReadDocumentDto(
          id: 'player-applicant',
          data: {
            'schemaVersion': 1,
            'recruitmentId': 'raid-1',
            'applicantPlayerId': 'player-applicant',
            'cycleKey': '2026-08-19',
            'characterId': 'character-1',
            'characterNameSnapshot': '아르카나',
            'classNameSnapshot': '아르카나',
            'requestedRole': 'dealer',
            'status': 'unknown',
            'revision': 1,
            'createdAt': DateTime.utc(2026, 8, 24),
            'updatedAt': DateTime.utc(2026, 8, 25),
          },
        ),
      ),
      throwsA(isA<PartyReadContractException>()),
    );
  });
}

Map<String, Object?> _recruitmentData() => {
  'schemaVersion': 1,
  'title': '4막 노말',
  'leaderPlayerId': 'player-leader',
  'leaderCharacterNameSnapshot': '리더캐릭',
  'leaderClassNameSnapshot': '바드',
  'raidCatalogVersion': 'v1',
  'raidId': 'act4',
  'difficultyId': 'normal',
  'raidNameSnapshot': '4막',
  'difficultyNameSnapshot': '노말',
  'difficultyAliasSnapshot': '노말',
  'gateCount': 3,
  'minItemLevel': 1700,
  'minCombatPower': 100000000,
  'experienceLevel': 'experienced',
  'maxPlayHours': 2,
  'raidStartAt': DateTime.utc(2026, 8, 25, 12),
  'status': 'active',
  'manualRecruitmentEnabled': true,
  'hasAvailableSlot': true,
  'currentCycleKey': '2026-08-19',
  'currentCycleStatus': 'active',
  'continueTogether': false,
  'cycleEndsAt': DateTime.utc(2026, 8, 26, 21),
  'memberCount': 4,
  'maxMemberCount': 8,
  'membersPerParty': 4,
  'partyCount': 2,
  'supportsPerParty': 1,
  'dealerCount': 3,
  'supportCount': 1,
  'memberPlayerIds': <Object?>['player-leader', 'player-member'],
  'approvalPolicy': {
    'mode': 'leaderOnly',
    'requiredApprovals': 1,
    'leaderVoteRequired': true,
    'rejectionMode': 'anyAuthorizedMember',
  },
  'revision': 3,
  'updatedAt': DateTime.utc(2026, 8, 25),
};
