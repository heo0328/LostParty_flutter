import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/data/mappers/party_application_write_plan.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_application_command.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_recruitment.dart';

void main() {
  test('pending application does not create membership or assignment data', () {
    final timestamp = Object();
    final data = PartyApplicationWritePlan.create(
      command: const PartyApplyCommand(recruitmentId: 'raid-1', characterId: 'char-1', requestedRole: PartyRole.dealer, cycleKey: '2026-08-26', combatPower: 100),
      playerId: 'player-1', characterName: '캐릭터', className: '아르카나', itemLevel: 1710, serverTimestamp: timestamp,
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
