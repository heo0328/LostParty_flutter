import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/group/data/mappers/group_member_snapshot_write_plan.dart';

void main() {
  test('로컬 전투력이 없어도 저장된 서버 전투력을 지우지 않는다', () {
    final patch = GroupMemberSnapshotWritePlan.selfRefresh(
      className: '바드',
      itemLevel: 1720,
      storedItemLevel: 1700,
      storedCombatPower: 2555,
      serverTimestamp: 'SERVER_TIME',
    );
    expect(patch['combatPowerSnapshot'], 2555);
    expect(patch['itemLevelSnapshot'], 1720);
    final empty = GroupMemberSnapshotWritePlan.selfRefresh(
      className: '바드',
      serverTimestamp: 'SERVER_TIME',
    );
    expect(empty['combatPowerSnapshot'], isNull);
  });
  test('selfRefresh writes display snapshot fields only', () {
    final patch = GroupMemberSnapshotWritePlan.selfRefresh(
      className: '워로',
      itemLevel: 1700,
      combatPower: 2555,
      serverTimestamp: 'SERVER_TIME',
    );

    expect(patch['displayClassNameSnapshot'], '워로');
    expect(patch['itemLevelSnapshot'], 1700);
    expect(patch['combatPowerSnapshot'], 2555);
    expect(patch['updatedAt'], 'SERVER_TIME');
    expect(patch.keys, hasLength(4));
  });
}
