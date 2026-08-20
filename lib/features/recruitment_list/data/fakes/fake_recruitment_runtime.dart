import '../../domain/services/recruitment_runtime.dart';

class FakeUserSession implements UserSession {
  FakeUserSession([this.currentUserId]);

  @override
  String? currentUserId;

  void signIn(String userId) => currentUserId = userId;
  void signOut() => currentUserId = null;
}

class FakeRecruitmentClock implements RecruitmentClock {
  FakeRecruitmentClock(this.currentTime);

  DateTime currentTime;

  @override
  DateTime now() => currentTime;

  void advance(Duration duration) {
    currentTime = currentTime.add(duration);
  }
}

class SequentialRecruitmentIdGenerator implements RecruitmentIdGenerator {
  SequentialRecruitmentIdGenerator({this.prefix = 'recruitment', int start = 1})
    : _nextValue = start;

  final String prefix;
  int _nextValue;

  @override
  String nextId() => '$prefix-${_nextValue++}';
}
