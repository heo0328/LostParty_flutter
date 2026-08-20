import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/data/fakes/fake_recruitment_runtime.dart';

void main() {
  test('사용자, 시간과 ID를 결정적으로 제어한다', () {
    final session = FakeUserSession();
    final clock = FakeRecruitmentClock(DateTime.utc(2026, 8, 20));
    final ids = SequentialRecruitmentIdGenerator();

    session.signIn('user-a');
    clock.advance(const Duration(minutes: 5));

    expect(session.currentUserId, 'user-a');
    expect(clock.now(), DateTime.utc(2026, 8, 20, 0, 5));
    expect(ids.nextId(), 'recruitment-1');
    expect(ids.nextId(), 'recruitment-2');

    session.signOut();
    expect(session.currentUserId, isNull);
  });
}
