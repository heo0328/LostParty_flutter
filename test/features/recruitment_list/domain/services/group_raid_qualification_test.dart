import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/domain/services/group_raid_qualification.dart';

void main() {
  test('그룹 전용 레이드에서 그룹을 떠난 Player만 자격을 잃는다', () {
    expect(
      GroupRaidQualification.lostPlayerIds(
        isGroupOnlyRaid: true,
        raidMemberPlayerIds: ['player-1', 'player-2'],
        currentGroupMemberPlayerIds: {'player-1'},
      ),
      {'player-2'},
    );
  });

  test('전체 공개 그룹 연결 레이드는 그룹 탈퇴만으로 자격을 잃지 않는다', () {
    expect(
      GroupRaidQualification.isGroupOnlyRaid(
        visibility: 'public',
        groupId: 'group-1',
      ),
      isFalse,
    );
    expect(
      GroupRaidQualification.lostPlayerIds(
        isGroupOnlyRaid: false,
        raidMemberPlayerIds: ['player-1', 'player-2'],
        currentGroupMemberPlayerIds: {'player-1'},
      ),
      isEmpty,
    );
  });

  test('활동 Character 해제는 그룹 자격 상실로 보지 않는다', () {
    expect(
      GroupRaidQualification.hasLostQualification(
        isGroupOnlyRaid: true,
        isCurrentGroupMember: true,
      ),
      isFalse,
    );
  });

  test('그룹원 목록을 못 읽으면 호출자만 자격 상실로 표시한다', () {
    expect(
      GroupRaidQualification.lostPlayerIdsWhenGroupUnreadable(
        isGroupOnlyRaid: true,
        currentPlayerId: 'player-2',
      ),
      {'player-2'},
    );
    expect(
      GroupRaidQualification.lostPlayerIdsWhenGroupUnreadable(
        isGroupOnlyRaid: false,
        currentPlayerId: 'player-2',
      ),
      isEmpty,
    );
  });
}
