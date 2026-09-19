import '../../domain/entities/weekly_raid_status_projection.dart';

class WeeklyRaidStatusItem {
  const WeeklyRaidStatusItem({
    required this.raidId,
    required this.difficultyId,
    required this.label,
    required this.isCompleted,
    this.statusKind,
    this.hasActiveEvidence = false,
    this.hasCompletedEvidence = false,
  });

  final String raidId;
  final String difficultyId;
  final String label;
  final bool isCompleted;
  final WeeklyRaidStatusKind? statusKind;
  final bool hasActiveEvidence;
  final bool hasCompletedEvidence;

  bool get canToggle =>
      statusKind != WeeklyRaidStatusKind.inconsistent ||
      hasActiveEvidence ||
      hasCompletedEvidence;

  String? get statusMessage => switch (statusKind) {
    WeeklyRaidStatusKind.active ||
    WeeklyRaidStatusKind.legacyActive => '현재 참가 중인 레이드입니다.',
    WeeklyRaidStatusKind.completed => '완료 처리된 레이드입니다.',
    WeeklyRaidStatusKind.inconsistent => '레이드 참가·완료 상태 확인이 필요합니다.',
    _ => null,
  };
}
