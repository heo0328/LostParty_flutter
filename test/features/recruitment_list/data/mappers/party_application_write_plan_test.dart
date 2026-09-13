import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/data/mappers/party_application_write_plan.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_application_command.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_recruitment.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_gem_validation_snapshot.dart';
import 'package:lost_party/shared/character_build/build_integrity_snapshot.dart';

void main() {
  test('pending application does not create membership or assignment data', () {
    final timestamp = Object();
    final data = PartyApplicationWritePlan.create(
      command: const PartyApplyCommand(
        recruitmentId: 'raid-1',
        characterId: 'char-1',
        requestedRole: PartyRole.dealer,
        cycleKey: '2026-08-26',
        combatPower: 100,
      ),
      playerId: 'player-1',
      characterName: '캐릭터',
      className: '아르카나',
      itemLevel: 1710,
      serverTimestamp: timestamp,
    );
    expect(data['status'], 'pending');
    expect(data['revision'], 1);
    expect(data['applicantPlayerId'], 'player-1');
    expect(data.containsKey('memberPlayerIds'), isFalse);
    expect(data.containsKey('assignment'), isFalse);
  });

  test('withdraw only describes the allowed state transition fields', () {
    final timestamp = Object();
    final data = PartyApplicationWritePlan.withdraw(
      nextRevision: 2,
      serverTimestamp: timestamp,
    );
    expect(
      data.keys,
      unorderedEquals([
        'status',
        'resolutionReason',
        'revision',
        'decidedAt',
        'updatedAt',
      ]),
    );
    expect(data['status'], 'withdrawn');
    expect(data['revision'], 2);
  });

  test('신청 Snapshot에는 원문 없이 최소 보석 검증 필드만 저장한다', () {
    final validatedAt = DateTime.utc(2026, 9, 8);
    final data = PartyApplicationWritePlan.create(
      command: PartyApplyCommand(
        recruitmentId: 'raid-1',
        characterId: 'char-1',
        requestedRole: PartyRole.dealer,
        cycleKey: '2026-09-02',
        gemValidation: PartyGemValidationSnapshot(
          status: PartyGemValidationStatus.error,
          foreignClassGemCount: 1,
          unverifiedSameClassGemCount: 0,
          validatedAt: validatedAt,
          catalogVersion: '2026.09.04',
          schemaVersion: 2,
          equippedGemCount: 9,
          unmatchedSkillGemCount: 2,
        ),
        buildIntegrity: _integrity(validatedAt),
      ),
      playerId: 'player-1',
      characterName: '캐릭터',
      className: '아르카나',
      itemLevel: 1710,
      serverTimestamp: Object(),
    );

    final snapshot = data['submittedBuildSnapshot']! as Map<String, Object?>;
    expect(snapshot['gemValidationSchemaVersion'], 2);
    expect(snapshot['gemValidationStatus'], 'error');
    expect(snapshot['equippedGemCount'], 9);
    expect(snapshot['foreignClassGemCount'], 1);
    expect(snapshot['unmatchedSkillGemCount'], 2);
    expect(snapshot['gemValidatedAt'], validatedAt);
    expect(snapshot['catalogVersion'], '2026.09.04');
    final integrity =
        snapshot['buildIntegritySnapshot']! as Map<String, Object?>;
    expect(integrity['status'], 'error');
    expect(integrity['issueCodes'], ['arkGridMinimum']);
    expect(snapshot.keys, isNot(contains('tooltip')));
    expect(snapshot.keys, isNot(contains('gems')));
    expect(snapshot.keys, isNot(contains('rawJson')));
  });

  test('reapply resets pending fields without touching rejectionCount', () {
    final timestamp = Object();
    final data = PartyApplicationWritePlan.reapply(
      command: const PartyApplyCommand(
        recruitmentId: 'raid-1',
        characterId: 'char-2',
        requestedRole: PartyRole.support,
        cycleKey: '2026-08-26',
        combatPower: 90,
      ),
      characterName: '재신청',
      className: '바드',
      itemLevel: 1700,
      nextRevision: 3,
      serverTimestamp: timestamp,
    );
    expect(data['status'], 'pending');
    expect(data['revision'], 3);
    expect(data['approvalCount'], 0);
    expect(data['characterId'], 'char-2');
    expect(data.containsKey('rejectionCount'), isFalse);
    expect(data.containsKey('createdAt'), isFalse);
  });
}

BuildIntegritySnapshot _integrity(DateTime checkedAt) => BuildIntegritySnapshot(
  status: BuildIntegrityStatus.error,
  issueCodes: const [BuildIntegrityIssueCode.arkGridMinimum],
  role: BuildIntegrityRole.dealer,
  checkedAt: checkedAt,
  catalogVersion: '2026.09.04',
);
