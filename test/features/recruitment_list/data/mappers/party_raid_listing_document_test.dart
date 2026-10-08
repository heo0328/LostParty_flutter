import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/data/mappers/party_raid_listing_document.dart';

void main() {
  test(
    'future private fields fail closed instead of entering a group listing',
    () {
      expect(
        () => partyRaidListingDocument(
          currentRecruitment: {
            'recruitmentId': 'room',
            'privateNotes': 'not for group readers',
          },
        ),
        throwsStateError,
      );
    },
  );

  test('final revision and explicit nulls replace stale source values', () {
    final before = <String, Object?>{
      'recruitmentId': 'room',
      'revision': 4,
      'completedAt': 'previous',
      'lastCommandId': 'previous-command',
      'memberCount': 8,
    };
    final timestamp = Object();
    final patch = <String, Object?>{
      'revision': 5,
      'completedAt': null,
      'lastCommandId': null,
      'memberCount': 7,
      'updatedAt': timestamp,
    };
    final after = partyRaidListingDocument(
      currentRecruitment: before,
      recruitmentPatch: patch,
    );
    expect(after, {...before, ...patch});
    expect(after.containsKey('sourceRevision'), isFalse);
    expect(identical(after['updatedAt'], timestamp), isTrue);
    expect(before['revision'], 4);
    expect(() => after['revision'] = 6, throwsUnsupportedError);
  });
}
