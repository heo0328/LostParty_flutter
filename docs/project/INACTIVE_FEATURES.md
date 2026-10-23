# 비활성 기능 대장

구현했으나 이후 제품 협의로 사용하지 않게 된 기능을 한곳에서 추적한다. 미구현 계획/일시 장애 목록과 구분하며, 코드가 남아 있다는 이유로 활성 기능으로 판단하지 않는다. 현재 사용 여부는 이 대장과 최신 제품 계약을 먼저 확인한다.

각 항목에는 결정일·사유, 비활성 범위/코드, API 경계, 보존 사항, 검증과 재검토 조건을 기록한다. 새 항목은 IF 번호를 이어 붙인다. 완전 삭제 또는 재활성화는 사용자의 별도 결정과 기존 자료·원요청 복구·공유 계약 영향 검토 후 진행한다.

## IF-001 — 이번주 미완료 종료·같은 주차 재개

| 항목 | 상태 |
|---|---|
| 결정일 | 2026-10-24, 사용자 확정 |
| 구현 이력 | F6-B 미완료 종료(설계37 §37.21), F6-C 재개(§37.23), 다일 노출 제한 e25e7ca2(§37.41) |
| 현재 | 기능 제작 후 협의로 미사용 결정. 앱 진입과 전용 신규 API 호출 비활성, 구현/계약은 보존 |
| 사유 | 드문 중단→같은 주차 재개의 조작을 줄인다. 이번주 각자 진행하면 이번주 참가를 정리하고, 이미 열린 다음주 방은 독립적으로 진행하는 UX를 채택 |
| 제품 기준 | [설계37 §37.42](../backend-migration/37-raid-scheduling-and-multi-raid-planning.md#3742-미완료-종료같은-주차-재개-비활성화-2026-10-24) |

### 앱·API 비활성 경계

- `CycleParticipationController.weeklyInterruptionEnabled`의 실제 앱 기본값은 false다. 사용자 설정/환경 변수로 켜는 기능은 없다. 실제 DI(`lib/app/backend_app.dart`)도 기본 컨트롤러를 사용한다.
- `CycleOutcomeActions`에서 `close_weekly` 버튼, `CycleResumeActions`에서 재개 제안/확인·응답 진입을 숨긴다. 다일 일정에도 표시하지 않는다. 직전 탈퇴 버튼 중앙 정렬·해산 폭은 유지한다.
- 컨트롤러 `outcome(close_weekly)`·`complete(close_weekly)`는 신규 context 조회/쓰기 전에 종료한다. 이전 preview를 가진 호출도 새 명령을 만들 수 없다. 해당 전용 GET은 `/v2/raid-rooms/{room}/command-context?command=close_weekly`, POST는 `/v2/raid-rooms/{room}/weekly-incomplete-closures`다.
- `resumePlan`·`resumePreview`·`resume`은 조회/미리보기/재검사·신규 제안/응답을 보내지 않는다. 전용 plan의 `include_resume_display=true`, POST `/v2/raid-rooms/{room}/weekly-resume-proposals`의 preview_only/생성, 재개 제안의 `/v2/raid-schedule-proposals/{id}/responses`가 대상이다. 원ACK 뒤 선택적으로 하던 재개 전용 추가 plan 조회도 생략한다.
- 일반 plan/detail 조회·일정 제안 응답은 계속 사용한다. 동일 responses 경로를 쓰더라도 일반 일정 변경 응답은 비활성 대상이 아니다. 일반 일정 UI/DTO는 target_session_ids가 있는 일정 제안만 처리하며 재개 제안과 구분한다.

### 보존 및 제외 범위

- DTO/Repository/Reader·writer·확인창·기존 다일 판정 코드를 삭제하지 않는다. 테스트의 명시적 전용 하위 클래스에서만 보존 구현을 활성화해 이전 계약 회귀를 검증한다. 실제 앱에서 이 테스트 구현을 주입하지 않는다.
- 이미 전송돼 결과가 불명확한 메모리 pending은 기존 24시간 범위에서 원 method/path/body/key/token으로 재송·ACK 확인한다. 이는 신규 기능 사용 차단의 예외인 기존 명령 복구다. 새 preview로 대체하거나 성공 여부를 읽기로 추정하지 않는다. 앱 재시작 후 새로 영속 복구하는 기능을 추가한 것은 아니다.
- 이전 stopped_incomplete 상태/제안·완료/감사 기록은 물리삭제하거나 자동 재개/완료/해산하지 않는다. 기존 읽기 전용 조회·기존 참가 정리 경로를 보존하며 새 이행 명령은 만들지 않는다.
- 주차 완료, 개인 완료 후 탈퇴, 완료 체크/해제, 일반 일정/예약, 다음주 함께하기·다음주 방 재개방(`reopen`), Issue25 리더 복구 제안은 별개다. Backend endpoint 폐기/권한 변경·DB/기존 기록 삭제는 승인 범위가 아니다.
- 현재 탈퇴/해산의 새 정책 구현은 Issue25 계약 인계 대기다. 이번 비활성화를 새 탈퇴 기능 구현 완료로 표시하지 않는다.

### 검증·후속

- outcome/resume/schedule/departure 4파일 119 mock PASS, 변경 Dart 6파일 분석0·포맷/diffcheck. 새 차단 사례3개와 기존 pending을 비활성 상태에서 원요청으로 복구하는 경계를 확인했다. 정상 완료·일정/개인 완료 후 탈퇴의 직접 기존 시험도 통과했다.
- 실서버·실기기 확인은 미실행이다. 사용자는 단일/다일·현재/다음주 상세에서 중단/재개 버튼이 안 보이고 정상 완료/일정·다음주 참가 진입이 유지되는지 확인한다. 이미 중단된 자료는 기존 표시/정리 경로를 확인하고 임의 일괄 변환하지 않는다.
- 재활성화/완전삭제 검토 시 전체 호출자·공유 응답 경로·기존 제안/기록·지원 클라이언트/원pending 수명을 확인한다. 보존 테스트나 과거 설계만 보고 자동 복원하지 않는다.
