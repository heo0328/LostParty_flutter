import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/group/domain/entities/group_member.dart';
import 'package:lost_party/features/group/domain/entities/group_member_display_snapshot.dart';
import 'package:lost_party/features/group/domain/services/group_member_display_builder.dart';

GroupMember _member({
  String? displayClassNameSnapshot,
  double? itemLevelSnapshot,
  double? combatPowerSnapshot,
}) {
  return GroupMember(
    groupId: 'group-1',
    playerId: 'player-1',
    role: GroupMemberRole.member,
    joinedAt: DateTime.utc(2026, 1, 1),
    joinSequence: 1,
    joinedBy: GroupJoinedBy.application,
    displayCharacterIdSnapshot: 'char-1',
    displayCharacterNameSnapshot: '테스트',
    displayClassNameSnapshot: displayClassNameSnapshot,
    itemLevelSnapshot: itemLevelSnapshot,
    combatPowerSnapshot: combatPowerSnapshot,
    revision: 1,
  );
}

void main() {
  group('GroupMemberDisplayBuilder.fromMember', () {
    test(
      'rejects bad snapshot and fallback numbers while cleaning fallback text',
      () {
        for (final invalid in [double.nan, double.infinity, -1.0]) {
          final display = GroupMemberDisplayBuilder.fromMember(
            member: _member(
              itemLevelSnapshot: invalid,
              combatPowerSnapshot: invalid,
            ),
            characterData: {
              'status': 'active',
              'characterClassName': '  워\n로드 ',
              'itemAvgLevel': invalid.toString(),
              'combatPower': invalid,
            },
          );
          expect(display.itemLevel, isNull);
          expect(display.combatPower, isNull);
          expect(display.className, '워 로드');
        }
        final valid = GroupMemberDisplayBuilder.fromMember(
          member: _member(),
          characterData: {'status': 'active', 'itemAvgLevel': '1,700.25'},
        );
        expect(valid.itemLevel, 1700.25);
      },
    );
    test('uses membership snapshot when present', () {
      final display = GroupMemberDisplayBuilder.fromMember(
        member: _member(
          displayClassNameSnapshot: '워로',
          itemLevelSnapshot: 1700,
          combatPowerSnapshot: 2500,
        ),
      );

      expect(display.className, '워로');
      expect(display.itemLevel, 1700);
      expect(display.combatPower, 2500);
    });

    test(
      'falls back to character document when snapshot combat power is null',
      () {
        final display = GroupMemberDisplayBuilder.fromMember(
          member: _member(
            displayClassNameSnapshot: '워로',
            itemLevelSnapshot: 1700,
          ),
          characterData: const {
            'status': 'active',
            'characterClassName': 'ignored',
            'itemAvgLevel': 1600,
            'combatPower': 2400,
          },
        );

        expect(display.className, '워로');
        expect(display.itemLevel, 1700);
        expect(display.combatPower, 2400);
      },
    );

    test('uses legacy character document when class snapshot is missing', () {
      final display = GroupMemberDisplayBuilder.fromMember(
        member: _member(),
        characterData: const {
          'status': 'active',
          'characterClassName': '도적',
          'itemAvgLevel': '1,650',
          'combatPower': '2,300',
        },
      );

      expect(display.className, '도적');
      expect(display.itemLevel, 1650);
      expect(display.combatPower, 2300);
    });
  });

  group('GroupMemberDisplaySnapshot.matchesStored', () {
    test('detects unchanged stored snapshot', () {
      const snapshot = GroupMemberDisplaySnapshot(
        className: '워로',
        itemLevel: 1700,
        combatPower: 2555,
      );

      expect(
        snapshot.matchesStored(
          storedClassName: '워로',
          storedItemLevel: 1700,
          storedCombatPower: 2555,
        ),
        isTrue,
      );
    });
  });
}
