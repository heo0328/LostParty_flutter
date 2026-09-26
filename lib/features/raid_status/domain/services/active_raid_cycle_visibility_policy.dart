import '../../../recruitment_list/domain/entities/party_read_models.dart';

enum ActiveRaidCycleState {
  current,
  expiredRecurring,
  expiredOneShot,
  ended,
}

class ActiveRaidCycleVisibilityPolicy {
  const ActiveRaidCycleVisibilityPolicy();

  ActiveRaidCycleState classify(
    ActiveRaidSummary raid, {
    required DateTime now,
  }) {
    if (raid.status == 'disbanded' || raid.status == 'incompleteEnded') {
      return ActiveRaidCycleState.ended;
    }

    // 1회성 완료방은 기존 해산 UX를 위해 진행 중 목록에 유지한다.
    if (raid.status == 'completed') return ActiveRaidCycleState.current;
    if (raid.status != 'active') return ActiveRaidCycleState.ended;

    final cycleEndsAt = raid.cycleEndsAt;
    if (cycleEndsAt == null || now.toUtc().isBefore(cycleEndsAt.toUtc())) {
      return ActiveRaidCycleState.current;
    }
    return raid.continueTogether
        ? ActiveRaidCycleState.expiredRecurring
        : ActiveRaidCycleState.expiredOneShot;
  }

  bool isVisible(ActiveRaidCycleState state) =>
      state == ActiveRaidCycleState.current ||
      state == ActiveRaidCycleState.expiredRecurring;
}
