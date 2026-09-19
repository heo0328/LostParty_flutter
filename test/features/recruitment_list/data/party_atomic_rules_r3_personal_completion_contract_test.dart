import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String rules;
  late String router;
  late String commandRepository;
  late String detailPage;

  setUpAll(() {
    rules = File('firestore.rules').readAsStringSync().replaceAll('\r\n', '\n');
    router = File(
      'lib/app/router/app_router.dart',
    ).readAsStringSync().replaceAll('\r\n', '\n');
    commandRepository = File(
      'lib/features/account/data/repositories/'
      'firestore_weekly_raid_status_command_repository.dart',
    ).readAsStringSync().replaceAll('\r\n', '\n');
    detailPage = File(
      'lib/features/raid_status/presentation/pages/party_read_detail_page.dart',
    ).readAsStringSync().replaceAll('\r\n', '\n');
  });

  test('R3 신규 개인 완료는 raidState 명령 저장소로 연결한다', () {
    expect(router, contains('FirestoreWeeklyRaidStatusCommandRepository('));
    expect(commandRepository, contains("'status': 'completed'"));
    expect(commandRepository, contains("'source': 'manual'"));
    expect(commandRepository, contains('transaction.set(stateRef, {'));
  });

  test('R3 활성 참가 완료는 멤버 제거와 state 완료를 같은 transaction에 둔다', () {
    expect(commandRepository, contains('PartyAtomicMemberRemovalWritePlan('));
    expect(commandRepository, contains('transaction.delete(memberRef);'));
    expect(commandRepository, contains('transaction.update(stateRef, {'));
    expect(commandRepository, contains("'reason': 'weeklyRaidCompleted'"));
    expect(
      rules,
      contains('function validPersonalCompletionRecruitmentUpdate('),
    );
    expect(rules, contains('function validPersonalRaidStateCompletion('));
    expect(rules, contains("data.reason == 'weeklyRaidCompleted'"));
  });

  test('R3 파티장 개인 완료는 후임 membership과 리더 snapshot을 함께 검증한다', () {
    expect(rules, contains('function validPersonalCompletionSuccessor('));
    expect(rules, contains("'leaderPlayerId', 'leaderCharacterNameSnapshot',"));
    expect(rules, contains('successor.canApproveApplications == true'));
    expect(
      rules,
      contains(
        'successor.characterNameSnapshot\n'
        '          == newData.leaderCharacterNameSnapshot',
      ),
    );
    expect(
      rules,
      contains('validPersonalCompletionLeaderProjection(oldData, newData)'),
    );
  });

  test('R3 수동 생성·개인 해제와 완료 기반 신청 차단을 Rules가 검증한다', () {
    expect(rules, contains('function validManualRaidStateCreate('));
    expect(rules, contains('function validPersonalCompletedRaidStateDelete('));
    expect(
      rules,
      contains('function validLegacyAssignmentConsumedByPersonalCompletion('),
    );
    expect(rules, contains('function hasWeeklyRaidCompletionAfter('));
    expect(rules, contains('function validAtomicAdvanceRaidStateCreate('));
    expect(rules, contains('function atomicAdvanceStateMatchesSlot('));
    expect(rules, contains('&& validManualRaidStateCreate('));
    expect(rules, contains('|| validPersonalRaidStateCompletion('));
  });

  test('파티 전체 완료 취소 실행 경로는 제거하고 과거 읽기만 별도 보존한다', () {
    expect(detailPage, isNot(contains('cancelCompletionButton')));
    expect(detailPage, isNot(contains('PartyCancelCompletionCommand')));
    expect(rules, isNot(contains("'cancelCompletion'")));
  });
}
