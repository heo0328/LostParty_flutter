abstract class UserSession {
  String? get currentUserId;
}

abstract class RecruitmentClock {
  DateTime now();
}

abstract class RecruitmentIdGenerator {
  String nextId();
}
