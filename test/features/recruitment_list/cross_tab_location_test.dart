import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/data/membership_readers.dart';

void main() {
  test('group raid return is restricted to the original canonical group', () {
    const id = '00000000-0000-4000-8000-000000000001';
    final uri = Uri.parse(
      recruitmentFromTab(
        '/recruitments/$id?target_cycle_key=2026-11-11',
        'groups',
        groupId: id,
      ),
    );
    expect(recruitmentReturnLocation(uri), '/groups/$id/raids');
    expect(uri.queryParameters['target_cycle_key'], '2026-11-11');
    expect(
      recruitmentReturnLocation(
        Uri.parse('/recruitments/$id?return_to=groups&return_group_id=bad'),
      ),
      isNull,
    );
  });
  test(
    'cross-tab location preserves reader/anchor queries and return week',
    () {
      const room = '00000000-0000-4000-8000-000000000001';
      final location = membershipDetailLocation(room, '2026-10-14');
      for (final tab in ['account', 'raid-status']) {
        final result = Uri.parse(recruitmentFromTab(location, tab));
        expect(
          result.queryParameters['reader_profile'],
          membershipReaderProfile,
        );
        expect(result.queryParameters['target_cycle_key'], '2026-10-14');
        expect(
          recruitmentReturnLocation(result),
          tab == 'account'
              ? '/account'
              : '/raid-status?target_cycle_key=2026-10-14',
        );
      }
      final application = Uri.parse(
        recruitmentFromTab(
          '/recruitments/$room?target_cycle_key=2026-10-14',
          'raid-status',
        ),
      );
      expect(application.queryParameters.containsKey('reader_profile'), false);
      final anchor = Uri.parse(
        recruitmentFromTab(
          '$location&membership_id=anchor&cycle_member_id=cycle',
          'raid-status',
        ),
      );
      expect(anchor.queryParameters['membership_id'], 'anchor');
      expect(anchor.queryParameters['cycle_member_id'], 'cycle');
      expect(
        recruitmentReturnLocation(
          Uri.parse('$location&return_to=https://example.com'),
        ),
        isNull,
      );
      expect(
        () => recruitmentFromTab(location, 'unknown'),
        throwsFormatException,
      );
    },
  );
}
