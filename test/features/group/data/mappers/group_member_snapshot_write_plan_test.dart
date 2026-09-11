import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/group/data/mappers/group_member_snapshot_write_plan.dart';
import 'package:lost_party/shared/character_build/party_gem_validation_snapshot.dart';

void main() {
  final storedGem = PartyGemValidationSnapshot(
    status: PartyGemValidationStatus.sameClassTargetUnverified,
    foreignClassGemCount: 0,
    unverifiedSameClassGemCount: 1,
    validatedAt: DateTime.utc(2026, 9, 1),
    catalogVersion: '2026.09.08',
  );
  final localGem = PartyGemValidationSnapshot(
    status: PartyGemValidationStatus.foreignClass,
    foreignClassGemCount: 2,
    unverifiedSameClassGemCount: 0,
    validatedAt: DateTime.utc(2026, 9, 10),
    catalogVersion: '2026.09.08',
  );

  test('로컬 전투력이 없어도 저장된 서버 전투력을 지우지 않는다', () {
    final patch = GroupMemberSnapshotWritePlan.selfRefresh(
      className: '바드',
      itemLevel: 1720,
      storedItemLevel: 1700,
      storedCombatPower: 2555,
      storedGemValidation: storedGem,
      serverTimestamp: 'SERVER_TIME',
    );
    expect(patch['combatPowerSnapshot'], 2555);
    expect(patch['itemLevelSnapshot'], 1720);
    expect(patch['gemValidationSnapshot'], storedGem.toFields());
    final empty = GroupMemberSnapshotWritePlan.selfRefresh(
      className: '바드',
      serverTimestamp: 'SERVER_TIME',
    );
    expect(empty['combatPowerSnapshot'], isNull);
    expect(empty['gemValidationSnapshot'], isNull);
  });

  test('selfRefresh writes display snapshot fields only', () {
    final patch = GroupMemberSnapshotWritePlan.selfRefresh(
      className: '워로',
      itemLevel: 1700,
      combatPower: 2555,
      gemValidation: localGem,
      serverTimestamp: 'SERVER_TIME',
    );

    expect(patch['displayClassNameSnapshot'], '워로');
    expect(patch['itemLevelSnapshot'], 1700);
    expect(patch['combatPowerSnapshot'], 2555);
    expect(patch['gemValidationSnapshot'], localGem.toFields());
    expect(patch['updatedAt'], 'SERVER_TIME');
    expect(patch.keys, hasLength(5));
  });

  test('로컬 보석 요약이 없으면 서버 요약을 유지한다', () {
    final patch = GroupMemberSnapshotWritePlan.selfRefresh(
      className: '바드',
      itemLevel: 1720,
      combatPower: 2600,
      storedGemValidation: storedGem,
      serverTimestamp: 'SERVER_TIME',
    );
    expect(patch['gemValidationSnapshot'], storedGem.toFields());
  });
}
