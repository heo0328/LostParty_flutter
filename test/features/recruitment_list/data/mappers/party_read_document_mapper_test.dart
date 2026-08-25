import 'package:flutter_test/flutter_test.dart';

import 'package:lost_party/features/recruitment_list/data/dto/party_read_document_dto.dart';
import 'package:lost_party/features/recruitment_list/data/mappers/party_read_document_mapper.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_recruitment.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/recruitment_application.dart';

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
    expect(summary.metadata.raidId, 'act4');
    expect(summary.metadata.experienceLevel, ExperienceLevel.experienced);
    expect(summary.isRecruiting, isTrue);
  });

  test('marks an owned active raid for the current player', () {
    final summary = mapper.toActiveRaid(
      PartyReadDocumentDto(id: 'raid-1', data: _recruitmentData()),
      currentPlayerId: 'player-leader',
    );

    expect(summary.currentCycleKey, '2026-08-19');
    expect(summary.isOwnedByCurrentPlayer, isTrue);
    expect(summary.raidStartAt, DateTime.utc(2026, 8, 25, 12));
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
  'memberCount': 4,
  'maxMemberCount': 8,
  'revision': 3,
  'updatedAt': DateTime.utc(2026, 8, 25),
};
