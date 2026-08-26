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
        'characterId': 'character-1',
        'raidId': 'serca',
        'cycleKey': '2026-08-26',
        'difficultyId': 'hard',
        'source': 'partyMember',
        'sourceRecruitmentId': 'recruitment-1',
        'sourceCompletionRevision': 4,
        'completedAt': DateTime.utc(2026, 8, 27),
        'updatedAt': DateTime.utc(2026, 8, 27),
      }),
      documentId: 'claim-1',
    );

    expect(claim.source, WeeklyRaidClaimSource.partyMember);
    expect(claim.raidId, 'serca');
    expect(claim.sourceCompletionRevision, 4);
  });

  test('rejects an unknown source', () {
    expect(
      () => mapper.map(
        WeeklyRaidClaimDto.fromMap({
          'schemaVersion': 1,
          'playerId': 'player-1',
          'characterId': 'character-1',
          'raidId': 'serca',
          'cycleKey': '2026-08-26',
          'difficultyId': 'hard',
          'source': 'clientText',
          'completedAt': DateTime.utc(2026, 8, 27),
          'updatedAt': DateTime.utc(2026, 8, 27),
        }),
        documentId: 'claim-1',
      ),
      throwsFormatException,
    );
  });
}
