import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/data/mappers/party_join_write_plan.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_gem_validation_snapshot.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_recruitment.dart';
import 'package:lost_party/shared/character_build/build_integrity_snapshot.dart';

void main() {
  test('가입 저장 계획은 모집·멤버십·확정 점유를 함께 갱신한다', () {
    final timestamp = Object();
    final validatedAt = DateTime.utc(2026, 9, 8);
    final plan = PartyJoinWritePlan.create(
      recruitmentId: 'raid-1',
      playerId: 'player-2',
      characterId: 'character-2',
      characterName: '테스트',
      className: '바드',
      itemLevel: 1700,
      combatPower: 100000,
      gemValidation: PartyGemValidationSnapshot(
        status: PartyGemValidationStatus.foreignClass,
        foreignClassGemCount: 1,
        unverifiedSameClassGemCount: 0,
        validatedAt: validatedAt,
        catalogVersion: '2026.09.08',
      ),
      buildIntegrity: _integrity(validatedAt),
      role: PartyRole.support,
      partyIndex: 1,
      slotIndex: 0,
      joinedBy: 'leader',
      raidId: 'serca',
      cycleKey: '2026-W34',
      memberCount: 7,
      memberPlayerIds: const ['leader'],
      maxMemberCount: 8,
      dealerCount: 6,
      supportCount: 1,
      revision: 4,
      serverTimestamp: timestamp,
    );

    expect(plan.recruitmentUpdate['memberPlayerIds'], ['leader', 'player-2']);
    expect(plan.recruitmentUpdate['memberCount'], 8);
    expect(plan.recruitmentUpdate['supportCount'], 2);
    expect(plan.recruitmentUpdate['hasAvailableSlot'], isFalse);
    expect(plan.recruitmentUpdate['revision'], 5);
    expect(plan.membership['partyIndex'], 1);
    expect(plan.membership['slotIndex'], 0);
    expect(plan.membership['joinedBy'], 'leader');
    expect(plan.assignment['recruitmentId'], 'raid-1');
    final gem =
        plan.membership['gemValidationSnapshot']! as Map<String, Object?>;
    expect(gem['gemValidationStatus'], 'foreignClass');
    expect(gem['foreignClassGemCount'], 1);
    expect(gem['catalogVersion'], '2026.09.08');
    expect(gem.keys, isNot(contains('tooltip')));
    final integrity =
        plan.membership['buildIntegritySnapshot']! as Map<String, Object?>;
    expect(integrity['status'], 'error');
    expect(integrity['issueCodes'], ['arkGridMinimum']);
  });

  test('과거 membership처럼 보석 Snapshot이 없어도 기본 필드는 유지한다', () {
    final plan = PartyJoinWritePlan.create(
      recruitmentId: 'raid-1',
      playerId: 'player-2',
      characterId: 'character-2',
      characterName: '테스트',
      className: '바드',
      itemLevel: 1700,
      combatPower: 100000,
      role: PartyRole.support,
      partyIndex: 0,
      slotIndex: 1,
      joinedBy: 'player-2',
      raidId: 'serca',
      cycleKey: '2026-W34',
      memberCount: 1,
      memberPlayerIds: const ['leader'],
      maxMemberCount: 8,
      dealerCount: 1,
      supportCount: 0,
      revision: 1,
      serverTimestamp: Object(),
    );
    expect(plan.membership['itemLevelSnapshot'], 1700);
    expect(plan.membership['combatPowerSnapshot'], 100000);
    expect(plan.membership['gemValidationSnapshot'], isNull);
    expect(plan.membership['buildIntegritySnapshot'], isNull);
  });

  test('승인은 신청 당시의 완전한 통합 오류 Snapshot만 membership으로 복사한다', () {
    final checkedAt = DateTime.utc(2026, 9, 8);
    final copied = PartyJoinWritePlan.copyBuildIntegrityFieldsIfComplete(
      _integrity(checkedAt).toFields(),
      parseDate: (value) => value is DateTime ? value : null,
    );

    expect(copied?['status'], 'error');
    expect(copied?['issueCodes'], ['arkGridMinimum']);
    expect(copied?['checkedAt'], checkedAt);

    final copiedFromSerializedDate =
        PartyJoinWritePlan.copyBuildIntegrityFieldsIfComplete(
          {
            ..._integrity(checkedAt).toFields(),
            'checkedAt': checkedAt.toIso8601String(),
          },
          parseDate: (value) =>
              value is String ? DateTime.tryParse(value) : null,
        );
    expect(copiedFromSerializedDate?['checkedAt'], checkedAt);

    final malformed = PartyJoinWritePlan.copyBuildIntegrityFieldsIfComplete({
      'schemaVersion': 2,
      'status': 'error',
      'issueCodes': ['arkGridMinimum'],
      'role': 'support',
    }, parseDate: (value) => value is DateTime ? value : null);
    expect(malformed, isNull);
  });
}

BuildIntegritySnapshot _integrity(DateTime checkedAt) => BuildIntegritySnapshot(
  status: BuildIntegrityStatus.error,
  issueCodes: const [BuildIntegrityIssueCode.arkGridMinimum],
  role: BuildIntegrityRole.support,
  checkedAt: checkedAt,
  catalogVersion: '2026.09.08',
);
