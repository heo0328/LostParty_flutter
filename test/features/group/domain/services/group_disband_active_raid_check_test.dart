import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/group/domain/services/group_disband_active_raid_check.dart';

void main() {
  const listing = {'visibility': 'group', 'status': 'active'};

  test('listing이 활성이어도 모집이 해산되면 그룹 해산을 막지 않는다', () {
    expect(
      isBlockingActiveGroupRaid(
        groupId: 'group-1',
        listing: listing,
        recruitment: {
          'visibility': 'group',
          'groupId': 'group-1',
          'status': 'disbanded',
        },
      ),
      isFalse,
    );
  });

  test('모집이 아직 활성 그룹 전용이면 해산을 막는다', () {
    expect(
      isBlockingActiveGroupRaid(
        groupId: 'group-1',
        listing: listing,
        recruitment: {
          'visibility': 'group',
          'groupId': 'group-1',
          'status': 'active',
        },
      ),
      isTrue,
    );
  });

  test('모집이 없거나 전체 공개로 바뀌면 해산을 막지 않는다', () {
    expect(
      isBlockingActiveGroupRaid(
        groupId: 'group-1',
        listing: listing,
        recruitment: null,
      ),
      isFalse,
    );
    expect(
      isBlockingActiveGroupRaid(
        groupId: 'group-1',
        listing: listing,
        recruitment: {
          'visibility': 'public',
          'groupId': 'group-1',
          'status': 'active',
        },
      ),
      isFalse,
    );
  });
}
