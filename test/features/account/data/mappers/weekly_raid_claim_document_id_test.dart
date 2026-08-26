import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/data/mappers/weekly_raid_claim_document_id.dart';

void main() {
  test('creates a stable Firestore-safe id without path separators', () {
    final first = WeeklyRaidClaimDocumentId.create(
      cycleKey: '2026-08-26',
      characterId: 'AbCdEfGhIjKlMnOpQrSt',
      raidId: 'raid_hard',
    );
    final second = WeeklyRaidClaimDocumentId.create(
      cycleKey: '2026-08-26',
      characterId: 'AbCdEfGhIjKlMnOpQrSt',
      raidId: 'raid_hard',
    );

    expect(first, second);
    expect(first, isNot(contains('/')));
    expect(first, '2026-08-26_AbCdEfGhIjKlMnOpQrSt_raid_hard');
  });

  test('rejects ids that Rules cannot reconstruct safely', () {
    expect(
      () => WeeklyRaidClaimDocumentId.create(
        cycleKey: '2026-08-26',
        characterId: 'character_with_separator',
        raidId: 'raid_hard',
      ),
      throwsArgumentError,
    );
  });
}
