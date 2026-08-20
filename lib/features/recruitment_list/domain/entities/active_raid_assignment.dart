class RaidParticipationSchedule {
  RaidParticipationSchedule({required this.startAt, this.expectedEndAt}) {
    final endAt = expectedEndAt;
    if (endAt != null && !endAt.isAfter(startAt)) {
      throw ArgumentError.value(
        endAt,
        'expectedEndAt',
        '예상 종료 시각은 시작 시각보다 뒤여야 합니다.',
      );
    }
  }

  final DateTime startAt;
  final DateTime? expectedEndAt;

  bool get hasKnownEnd => expectedEndAt != null;
}

class ActiveRaidAssignment {
  ActiveRaidAssignment({
    required this.userId,
    required this.characterId,
    required this.raidId,
    required this.difficultyId,
    required this.recruitmentId,
    required this.schedule,
  }) {
    _requireNotBlank(userId, 'userId');
    _requireNotBlank(characterId, 'characterId');
    _requireNotBlank(raidId, 'raidId');
    _requireNotBlank(difficultyId, 'difficultyId');
    _requireNotBlank(recruitmentId, 'recruitmentId');
  }

  final String userId;
  final String characterId;
  final String raidId;
  final String difficultyId;
  final String recruitmentId;
  final RaidParticipationSchedule schedule;

  String get characterRaidKey => '$userId::$characterId::$raidId';

  static void _requireNotBlank(String value, String fieldName) {
    if (value.trim().isEmpty) {
      throw ArgumentError.value(value, fieldName, '빈 값일 수 없습니다.');
    }
  }
}
