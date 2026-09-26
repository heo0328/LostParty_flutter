import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/raid_status/domain/services/active_raid_cycle_visibility_policy.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_read_models.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/recruitment_aggregate.dart';

void main() {
  const policy = ActiveRaidCycleVisibilityPolicy();
  final now = DateTime.utc(2026, 9, 25);

  test('현재·만료 반복·만료 1회성·종료 상태를 구분한다', () {
    expect(
      policy.classify(
        _raid(cycleEndsAt: DateTime.utc(2026, 9, 30)),
        now: now,
      ),
      ActiveRaidCycleState.current,
    );
    expect(
      policy.classify(
        _raid(
          continueTogether: true,
          cycleEndsAt: DateTime.utc(2026, 9, 23),
        ),
        now: now,
      ),
      ActiveRaidCycleState.expiredRecurring,
    );
    expect(
      policy.classify(
        _raid(cycleEndsAt: DateTime.utc(2026, 9, 23)),
        now: now,
      ),
      ActiveRaidCycleState.expiredOneShot,
    );
    expect(
      policy.classify(
        _raid(
          status: 'incompleteEnded',
          cycleEndsAt: DateTime.utc(2026, 9, 23),
        ),
        now: now,
      ),
      ActiveRaidCycleState.ended,
    );
  });

  test('완료방과 종료 시각이 없는 과거 문서는 기존 표시를 보존한다', () {
    expect(
      policy.isVisible(
        policy.classify(_raid(status: 'completed'), now: now),
      ),
      isTrue,
    );
    expect(
      policy.isVisible(policy.classify(_raid(), now: now)),
      isTrue,
    );
  });
}

ActiveRaidSummary _raid({
  String status = 'active',
  bool continueTogether = false,
  DateTime? cycleEndsAt,
}) => ActiveRaidSummary(
  id: 'raid',
  title: 'raid',
  leaderPlayerId: 'leader',
  metadata: const RecruitmentMetadata(
    catalogVersion: 'test',
    raidId: 'raid',
    difficultyId: 'normal',
    raidName: '레이드',
    difficultyName: '노말',
    difficultyAlias: '노말',
    gateCount: 1,
    minItemLevel: 0,
    minCombatPower: null,
    experienceLevel: null,
    maxPlayHours: null,
  ),
  currentCycleKey: '2026-09-23',
  memberCount: 1,
  maxMemberCount: 4,
  revision: 1,
  updatedAt: DateTime.utc(2026, 9, 23),
  isOwnedByCurrentPlayer: true,
  status: status,
  continueTogether: continueTogether,
  cycleEndsAt: cycleEndsAt,
);
