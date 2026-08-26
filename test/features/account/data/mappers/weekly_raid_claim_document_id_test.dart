import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/data/mappers/weekly_raid_claim_document_id.dart';

void main() {
  test('creates a stable Firestore-safe id without path separators', () {
    final first = WeeklyRaidClaimDocumentId.create(
      cycleKey: '2026-08-26',
      characterId: 'characters/alpha',
      raidId: 'raid~hard',
    );
    final second = WeeklyRaidClaimDocumentId.create(
      cycleKey: '2026-08-26',
      characterId: 'characters/alpha',
      raidId: 'raid~hard',
    );

    expect(first, second);
    expect(first, isNot(contains('/')));
    expect(first.split('~'), hasLength(3));
  });

  test('keeps component boundaries collision resistant', () {
    final left = WeeklyRaidClaimDocumentId.create(
      cycleKey: 'a_b',
      characterId: 'c',
      raidId: 'd',
    );
    final right = WeeklyRaidClaimDocumentId.create(
      cycleKey: 'a',
      characterId: 'b_c',
      raidId: 'd',
    );

    expect(left, isNot(right));
  });
}
