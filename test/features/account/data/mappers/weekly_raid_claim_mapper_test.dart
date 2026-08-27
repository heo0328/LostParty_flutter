import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/data/dtos/weekly_raid_claim_dto.dart';
import 'package:lost_party/features/account/data/mappers/weekly_raid_claim_mapper.dart';
import 'package:lost_party/features/account/domain/entities/weekly_raid_claim.dart';

void main() {
  final mapper = WeeklyRaidClaimMapper(
    toDateTime: (value) => value! as DateTime,
  );

  test('maps the server claim contract', () {
    final claim = mapper.map(
      WeeklyRaidClaimDto.fromMap({
        'schemaVersion': 1,
        'playerId': 'player-1',
        'characterId': 'AbCdEfGhIjKlMnOpQrSt',
        'raidId': 'serca',
        'cycleKey': '2026-08-26',
        'difficultyId': 'hard',
        'source': 'partyMember',
        'sourceRecruitmentId': 'recruitment-1',
        'sourceCompletionRevision': 4,
        'completedAt': DateTime.utc(2026, 8, 27),
        'updatedAt': DateTime.utc(2026, 8, 27),
        'cycleStartedAt': DateTime.utc(2026, 8, 25, 21),
        'cycleEndsAt': DateTime.utc(2026, 9, 1, 21),
      }),
      documentId: '2026-08-26_AbCdEfGhIjKlMnOpQrSt_serca',
    );

    expect(claim.source, WeeklyRaidClaimSource.partyMember);
    expect(claim.raidId, 'serca');
    expect(claim.sourceCompletionRevision, 4);
  });

  test('maps a float sourceCompletionRevision from Firestore', () {
    final claim = mapper.map(
      WeeklyRaidClaimDto.fromMap({
        'schemaVersion': 1,
        'playerId': 'player-1',
        'characterId': 'AbCdEfGhIjKlMnOpQrSt',
        'raidId': 'serca',
        'cycleKey': '2026-08-26',
        'difficultyId': 'hard',
        'source': 'partyOwner',
        'sourceRecruitmentId': 'recruitment-1',
        'sourceCompletionRevision': 3.0,
        'completedAt': DateTime.utc(2026, 8, 27),
        'updatedAt': DateTime.utc(2026, 8, 27),
        'cycleStartedAt': DateTime.utc(2026, 8, 25, 21),
        'cycleEndsAt': DateTime.utc(2026, 9, 1, 21),
      }),
      documentId: '2026-08-26_AbCdEfGhIjKlMnOpQrSt_serca',
    );

    expect(claim.sourceCompletionRevision, 3);
  });

  test('rejects an unknown source', () {
    expect(
      () => mapper.map(
        WeeklyRaidClaimDto.fromMap({
          'schemaVersion': 1,
          'playerId': 'player-1',
          'characterId': 'AbCdEfGhIjKlMnOpQrSt',
          'raidId': 'serca',
          'cycleKey': '2026-08-26',
          'difficultyId': 'hard',
          'source': 'clientText',
          'completedAt': DateTime.utc(2026, 8, 27),
          'updatedAt': DateTime.utc(2026, 8, 27),
          'cycleStartedAt': DateTime.utc(2026, 8, 25, 21),
          'cycleEndsAt': DateTime.utc(2026, 9, 1, 21),
        }),
        documentId: '2026-08-26_AbCdEfGhIjKlMnOpQrSt_serca',
      ),
      throwsFormatException,
    );
  });

  test('rejects a document id that does not match the claim identity', () {
    expect(
      () => mapper.map(
        WeeklyRaidClaimDto.fromMap({
          'schemaVersion': 1,
          'playerId': 'player-1',
          'characterId': 'AbCdEfGhIjKlMnOpQrSt',
          'raidId': 'serca',
          'cycleKey': '2026-08-26',
          'difficultyId': 'hard',
          'source': 'manual',
          'completedAt': DateTime.utc(2026, 8, 27),
          'updatedAt': DateTime.utc(2026, 8, 27),
          'cycleStartedAt': DateTime.utc(2026, 8, 25, 21),
          'cycleEndsAt': DateTime.utc(2026, 9, 1, 21),
        }),
        documentId: '2026-08-26_AbCdEfGhIjKlMnOpQrSt_behemoth',
      ),
      throwsFormatException,
    );
  });
}
