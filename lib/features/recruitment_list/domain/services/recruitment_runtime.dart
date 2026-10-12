abstract class UserSession {
  String? get currentUserId;
}

abstract class RecruitmentClock {
  DateTime now();
}

/// Reads time on each request so a long-lived candidate service follows resets.
class SystemRecruitmentClock implements RecruitmentClock {
  SystemRecruitmentClock({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  @override
  DateTime now() => _now();
}

abstract class RecruitmentIdGenerator {
  String nextId();
}
