import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/group/data/mappers/group_member_snapshot_write_plan.dart';

void main() {
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
