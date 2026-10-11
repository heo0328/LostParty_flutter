# 전체 Rules 간소화 — 세 방향 통합 설계

> 2026-10-11 최신 설계는 [운영 전체 구조 재설계안](RULES_PRODUCTION_RESTRUCTURE_DESIGN.md)이다. 아래는 이전 구현/진단 근거로 보존한다. 작은 구간별 운영 게시 계획은 재개하지 않는다.

## 사용자 요청에 따른 중단·보존 체크포인트

특정 구간을 조금씩 수정하고 매번 게시하는 현재 방식은 게시 정상화 성과가 확인되지 않아 사용자 요청으로 중단한다.
다음3-1/3-2/4는 실행 대기가 아니라 보류 목록이다. 새 지시 전 구현·실험·게시를 자동 재개하지 않는다.
원본으로 매번 되돌리지 않고 A→A+B 방식으로 누적 적용했으며 현재 후보를 성공본으로 간주하지 않는다.

| 기준 | 줄맞춤 소스 | 축약 소스 | 함수 | 최대 깊이 |
|---|---:|---:|---:|---:|
| 보존49acce8 / fd90aa93 |187865bytes|145267bytes|285|5|
| 현재3f683e9b |189056bytes|146524bytes|279|5|
| 변화 |+1191bytes|+1257bytes|-6|변화 없음|

이 보존 구간에서 인증 중복 비교/조회, 공통 권한 내부 호출, 전용 인증 호출, 전환 출력 중복,
준비 검사3곳을 정리했다. 앱으로 새로 옮긴 처리0. 2-2 표시 후보는58bytes 증가·조회/함수 감소0으로 미채택했다.
국소 검증은 통과했으나 실제 전체본 게시 정상화라는 목표는 미달이다. 테스트 수를 완료 성과로 대체하지 않는다.

마지막 게시(2026-10-10 23:43 KST): /test200·경고0, /rulesets200,
PATCH /releases/cloud.firestore400 INVALID_ARGUMENT, CLI 후속POST409 ALREADY_EXISTS.
409는 이 기록에서400 뒤 CLI fallback 결과이며 인덱스 문제의 근거가 아니다.
마지막 읽기 확인23:44 KST: 운영7a441b1f/183844bytes, ruleset6b3870e1-06c5-4544-a594-6fd8ee78e73e,
게시시각19:10 KST 유지. 사용자가 삭제한 함수11개/미정의 호출151곳이 남은 소스이며 기능 정상화 확인 상태가 아니다.
이번 기록/커밋에서는 원격 재조회·게시·복구를 수행하지 않는다.

삭제본/단독본 게시 성공은 중요한 근거지만, 현재 유효한 전체본의 반복 실패만으로 내부 compiled 크기나
특정 함수 호출이 유일 원인이라고 확정할 수 없다. 누락 함수가 있는 운영본과 기능 보존 후보는 분리해서 판단한다.
후속 재개 시 현재 방식의 효과와 전체 구조 전략을 먼저 재평가해야 하며 단순 inline/미세 삭제·재게시 반복을 기본안으로 삼지 않는다.
운영 복구 여부·완료된 앱 기능 보호·원인 증거·구조적 절감 방법을 함께 검토해야 한다. 새 설계는 이번에 착수하지 않는다.

현재 전체SHA: 3f683e9b79a17134f6d9f7643de21fd3255063f0fa6e6dadfac881790834cfe8.
생성기 경로 tools/integrate_roster_rules.mjs → rules_localization_pipeline.mjs를 함께 보존한다.
기존 로컬 검증은 기록을 재사용하고 문서/diff 및 생성 일치만 확인한다. 실기기/운영 동시성 인수는 미확인이다.
coverage의 원시 로그는 Git 제외 로컬 증거이므로 다른 checkout에는 자동 복원되지 않는다.
아래 단계별 설명은 이력이며 새 실행 지시가 아니다.


2026-10-10. 기획·설계 문서이며 구현·배포 승인이 아니다. 다음 실행 단위는 NEXT_WORK를 따른다.
기존 RULES_LOCALIZATION_EXECUTION_PLAN의 완료 내역과 실험 결과를 이어받는다. D-X1 기능 이식은 재개하지 않는다.

## 1. 목표와 확인된 기준

목표는 기존 기능과 서버 보장을 유지한 전체 Rules의 정상 게시 및 후속 변경에서의 안정성 유지다.
감소율 목표는 없다. 함수 수·소스 크기·호출 깊이는 보조 지표이며 테스트 개수로 성과를 대체하지 않는다.

- 보존 커밋49acce8, 전체 소스fd90aa93/187865bytes, 내용 기준8b39db36/145267bytes, 최대 깊이5.
- 운영8b39db36 게시 시 컴파일/생성200 뒤 활성화400, CLI fallback409. 마지막 확인 운영본36b5920e 유지.
- 테스트 프로젝트의 1순위 제거본20dfcdeb 게시 성공(경고5), 해당 함수군과 의존 함수만 담은aae06656 게시 성공(경고0).
- 두 실험은 전체 결합의 누적 복잡도/호출 구조를 우선 개선할 근거다. 특정 내부 한도 초과의 증명은 아니다.
  단독본은 allow 구성이 다르고, 정렬 전체본의 동일 프로젝트 대조는 하지 않았다.
- 현재 테스트 프로젝트는 기능 제한 진단본이다. 그 소스를 앱 운영 기준·회귀 정답으로 사용하지 않는다.
- Spark 유지. 새로운 유료 서버, 스키마 전면 교체, 이벤트 삭제, 인증 기능 삭제는 포함하지 않는다.

## 2. 실제 연결과 기존 데이터 수명

| 흐름 | 실제 구현 근거 | 보존할 계약 |
|---|---|---|
| 주차 전환 | app_router.dart의 PartyAtomicCycleCommandAdapter → FirestorePartyAtomicCommandRepository → _certifyAdvance → 최종 Transaction | 인증은 대상별 선행 Transaction, 핵심 방/전원 state/목록/이벤트는 최종 한 Transaction. private 원장을 방장에게 읽기 허용하지 않음 |
| 완료 반복방 준비 변경 | FirestorePartyAtomicMemberMutationRepository의 nextWeekPrep → PartyAtomicNextWeekCharacterChangeWritePlan | 모집·본인 member·필수 listing·characterChanged 이벤트만 쓰기. 이전/새 state·Claim·완료 이력은 쓰지 않음 |
| 화면 표시 | PartyReadDocumentMapper, GroupDocumentMapper → FirestorePartyReadRepository/FirestoreGroupReadRepository → Router에서 실제 화면 연결 | 표시 정제 실패가 권한·소유권·완료 판정을 정상값으로 바꾸지 않음 |
| 목록 조회 | FirestorePartyReadRepository._public 계열 쿼리 및 cursor/limit | 공개 범위·본인 관계·group membership 경계 유지. 로컬 처리에 필요한 비공개 자료를 추가 공개하지 않음 |

식별자는 Auth UID의 active binding으로 확정한 Player ID, characterId, raidId, recruitmentId를 사용한다.
state 문서 ID는 characterId_raidId이고 주차는 본문 cycleKey다. guard-only stub은 참가/완료 문서가 아니다.
guard는 방 revision·슬롯·주차·소유 차수에 결합한다. 인증 일부만 성공하면 guard가 남을 수 있으나 방은 전환되지 않는다.
준비 변경의 완료 이력 보존과 정상 주차 전환의 현재 state 갱신은 다르다. 과거 완료 당시 명단은 기존 이벤트 계약을 유지한다.
이전 Claim/assignment는 호환 자료이며 최신 앱만 사용한다는 사실만으로 서버의 과거 자료가 없어졌다고 간주하지 않는다.

## 3. 세 방향의 판단 원칙

### A. 중복 서버 검사 제거

같은 문자열 조건이 반복된다는 이유만으로 삭제하지 않는다. 각 삭제 후보에 아래 근거를 남긴다.

1. 불변식과 최종 책임 문서/함수.
2. 그 문서가 같은 요청에서 실제로 변경되어 해당 allow 검사를 반드시 실행하는 이유.
3. before/after의 대상 경로·actor·revision·request.time·명령 식별자가 동일하다는 연결.
4. 문서를 누락하거나 기존 문서를 재사용하거나 다른 allow로 우회할 때 거절되는 이유.

getAfter는 다른 문서의 최종 값을 읽는 것이지 그 문서의 validator를 호출하는 것이 아니다.
예를 들어 after.revision == before.revision + 1을 요구하여 실제 변경을 강제하고 정확한 관계를 묶어야
그 문서에 둔 검사 책임을 전제로 할 수 있다. 이벤트는 존재 확인만으로 충분하지 않다.
공통 함수를 만드는 것만으로 compiled 크기가 줄었다고 판단하지 않고, 실제 중복 조건 삭제를 구분한다.

### B. 표시·정제·필터의 로컬 이전

표시 복사본의 원본 동일성 보증은 줄일 수 있다. 서버는 작성 권한, 허용 키, 기본 타입/크기와 변경 가능 범위를 유지한다.
앱 Mapper가 표시 텍스트의 공백/제어문자/길이와 선택 숫자의 누락·음수·비유한 값을 처리한다.
식별자·직업 구성 키·역할·입장 자격·소유 차수·차단 여부·주차·인원수는 표시값처럼 완화하지 않는다.

로컬로 옮길 정제는 권한상 내려받을 수 있는 페이지 내 자료에만 적용한다. Rules는 필터링 엔진이 아니므로
권한 조건을 로컬 필터로 대신할 수 없다. 기존 limit/cursor와 쿼리 순서를 유지한다.
필터 결과0건이 서버 전체 결과0건을 의미하지 않도록 기존 다음 페이지 상태를 보존한다.
이미 로컬인 정렬/필터는 이번 Rules 절감에 포함하지 않는다. 쿼리 변경이 Rules를 줄이지 않으면 이번에는 변경하지 않는다.

### C. 호출·분기 단순화

인증 표식 변경 → guard-only 소비 → 정상 state 전이를 명시적으로 나눠 관련 없는 validator의 연쇄 평가를 줄인다.
분기 표식은 권한 증명이 아니다. 선택된 경로에서 실제 actor·대상·상태·revision을 검증하고 알 수 없는 상태는 거절한다.
필드가 없는 stub에 status/cycleKey를 먼저 읽어 오류를 내지 않도록 존재/타입 검사를 앞에 둔다.
함수 합치기는 반복 본문 복제와 깊이 증가를 함께 비교한다. 깊이만 줄이기 위한 무조건 inline은 하지 않는다.
스코프 이동만으로 활성화에 실패했던 실험과 이름 축약만 반복하는 접근은 재개하지 않는다.

## 4. 구체 후보와 채택 조건

아래는 검토한 코드에 기반한 구현 후보다. 조건부 항목은 동등성 확인 전 삭제 확정이 아니다.

| ID | 현재 위치/중복 후보 | 설계 | 유지 조건·부작용 |
|---|---|---|---|
| A1 | sealAuditUpdate → sealAudit의 room 재조회와 신원/형식 검사 | 같은 요청의 room을 한 번 확보해 전달. update 전용 core 불변 검사는 update에, 공통 인증 검사는 audit에 둠 | room의 before/after 불변·실시간 소유권·legacy 점유·주차 window 유지. get과 getAfter를 하나로 합치지 않음 |
| C1 | sealAdvanceIdle, bug24AdvanceCompleted, validAtomicRaidStateUpdate의 advance 분기 | 공통 명령/guard 결합과 이전 상태별 revision·완료 필드 규칙을 분리. 전환 분기 중복 제거 후보 작성 | stub→active revision1과 completed→active revision+1을 혼합하지 않음. 이전 active 전환도 보존 |
| A2 | sealPrepared, atomicAdvanceStateMatchesSlotAt, bug24CommandIncludes 및 출력 cycle/raid/difficulty 대조 | 슬롯 일치가 실제로 보장하는 필드 목록을 펼쳐 같은 경로의 중복 equality만 제거 | commandTargets 포함은 독립 원자성 보장일 수 있어 슬롯 일치만으로 삭제 불가. 최신 소유권과 guard 일치 유지 |
| A3 | bug24PrepAggregate/Pair/Member/sparkPrepRecords의 actor·시간·revision 반복 | 모집은 구성/targets/count/필수 쓰기, member는 본인·소유권·legacy 점유, 이벤트는 state/Claim 보존 담당. 각 문서에는 최소 명령 연결 유지 | 이미 분산된 검사 재이동을 성과로 계산하지 않음. member 단독·이벤트 단독·다른 명령 동반 쓰기를 막는 연결은 남김 |
| B1 | bug24PrepPair의 leaderCharacterNameSnapshot/leaderClassNameSnapshot 복사 동일성 | 준비 변경에서 표시 필드의 원본 대조를 기본 표시 계약으로 축소. 앱 Write Plan의 정상 복사는 유지 | member.playerId와 leaderPlayerId, 슬롯 classKey/role은 유지. 타인이 방장 표시를 고치는 권한은 새로 허용하지 않음 |
| B2 | validInitialGroupMember/validInvitedGroupMember 및 가입 경로의 displayCharacterNameSnapshot 대조 | 그룹 가입·초대·코드 가입별 표시명 동일성만 후보화. 공용 Mapper의 toMember 등 모든 소비 경로 정제 적용 후 제거 | displayCharacterIdSnapshot·relation 대상·차단·가입 순서·memberCount·권한은 유지. 이름 불일치/오래된 값 표시는 허용하는 계약 |
| B3 | 다른 방장 승계/생성의 이름·직업명 Snapshot 복사 대조 | B1 이후 같은 표시 전용 사용처만 확대. 검색·구성 정책에 사용되는 직업명은 따로 분류 | classNameSnapshot은 일부 경로에서 슬롯 구성 키 입력에도 쓰인다. 전체 이름 기반 일괄 삭제 금지 |
| C2 | preparation/advance/일반 변경을 중첩해 감싼 raidStates·members allow | 원자 명령 종류와 이전 상태로 일관된 분기표를 만든 뒤 기존 경로를 치환 | OR로 허용되던 합법 경로를 ternary 우선순위가 가로막지 않는지 확인. legacy·소유권 정리·개인 완료 경로 보존 |

이미 완료한 그룹 relation 표시명·신청 통계·차단 표시 대조 제거, R1 listing 통합, C1 member-only 구형 쓰기 종료는
이 설계의 신규 절감 대상이 아니다. canonical listing의 data == room도 이번 단계에서 표시 필드별 비교로 해체하지 않는다.
전체 문서 복사는 짧은 하나의 검사이며 필드별 예외가 오히려 복잡도·불일치 경로를 늘릴 수 있다.

## 5. 기존 기능과 부작용 대응

| 위험/기존 흐름 | 가능한 부작용 | 설계상 방어 및 확인 범위 |
|---|---|---|
| 준비 변경 A→B→C, 방장/일반 멤버, 그룹/공개방 | 이미 완료한 기록 덮어쓰기, 슬롯/집계 불일치 | state/Claim 불변과 과거 완료 이벤트 유지. 필수 listing 누락은 기존대로 거절. 같은 캐릭터 역할 변경을 새로 허용하지 않음 |
| 인증 도중 네트워크 실패·재진입 | 일부 guard 잔존을 참가로 오인하거나 오래된 인증 재사용 | strict stub 분류 유지. 방 revision/slot/window 변경 시 인증 거절·재취득. 핵심 상태 부분 전환 금지 |
| 8인 주차 전환, 다른 난이도·역할의 이전 완료 | 한 명의 충돌을 건너뛰거나 정상 과거 완료를 차단 | 최대8인 및 충돌1인의 전체 원자 거절. 완료 당시 이력과 새 주차 현재 state 수명 구분 |
| 인증 후 소유권 이전·동시 참가/수동완료 | 이중 점유/완료 우회 | 최종 현재 소유권, guard 소비, live Claim 충돌 방어 유지. 인증/Claim 운영 동시성 기존 미확인은 해소 전 완료라고 하지 않음 |
| 생성·신청·승인·즉시 참가·캐릭터 변경·자리 교환 | 준비 변경 완화가 일반 참가 자격까지 확장 | 준비 변경 전용 경로 유지. 클래스/역할/정원·주간 완료/점유·원자 명령 권한 그대로 |
| 개인 완료·해제·전체 완료, 탈퇴·추방·승계·마지막1인 | 공통 dispatch 수정이 무관한 정상 경로 차단 | 직접 영향받는 경로만 회귀. 이벤트 누락·소유권 무효·guard 일부 제거·member 누락은 거절 |
| 표시값 누락/손상/다른 값 | 화면 예외, 이상한 정렬, 권한 판단에 오염 | optional display만 정제/기본값. ID·상태 오류는 불일치로 처리. 잘못된 이름을 실제 소유 인증처럼 표시하지 않음 |
| 로컬 정제 후 목록 | 표시 필터 후 빈 페이지·페이지 중복·읽기 증가 | 기존 query/cursor/limit 유지. 정렬은 받은 범위 기준. 전체 검색인 것처럼 표현하지 않음. 추가 전체 조회/listener 없음 |
| 이벤트 책임 축소 | 조작 이벤트로 완료 이력/알림 오염 | eventId/actor/audience/commandRevision/time/필수 쓰기 연결 및 불변성 유지. 이벤트 자체 삭제·로컬 전용 전환 제외 |
| 기존 자료·구버전/재설치 | legacy 소유권·완료를 무시하거나 새 writer 거절 | 같은 저장 스키마 우선. 구형 쓰기 추가 종료나 데이터 이행은 별도 명세·전환·복구가 준비된 경우에만 포함 |

표시 복사본의 서버 진실성 보장을 낮추는 것은 명시적인 계약 변화다. 정상 앱의 복사는 계속 유지하지만
수정된 클라이언트가 허용 범위 안의 다른 표시명을 쓸 수 있다. 이를 허용할 수 없는 필드는 B에서 제외한다.
동일 소스의 과거 테스트 통과 기록을 재사용하되 새로 삭제한 보안 조건의 근거로 대신하지 않는다.

## 6. 작업 구간 — 구현 범위와 확인 범위

| 구간 | 구현 범위 | 확인 범위 / 종료 조건 |
|---|---|---|
| 1-1 인증 검사 정리 | A1: room 전달과 인증 생성/갱신 공통 조건 정리. 서버/앱 스키마 불변 | 같은 방 revision, 다른 actor, window 경계, 슬롯/소유권 불일치, 기존 완료/active/stub·인증 부분 갱신. 실제 중복 제거가 없으면 채택하지 않음 |
| 1-2 전환 공통 조건 | A2+C1: 슬롯·guard·명령 공통 조건과 상태별 출력 조건 정리 | stub/이전완료/이전active 전환, 명령 대상 누락, guard 변조, 현재 완료/타방 점유. 바뀐 경계의 최소 서버 확인 |
| 2-1 준비 변경 책임 | A3: 문서별 책임표를 조건 단위로 완성하고 입증된 중복만 제거 | 모집/member/event/listing 각 누락, 이벤트 단독·재사용, state/Claim 끼워쓰기. 필수 검사 담당이 없는 조건0개 |
| 2-2 준비 변경 표시 | B1: 로컬 표시 정제 후 이름 복사 검사의 범위 축소 | 정상 복사 유지, 오래된/누락 표시, 비방장의 방장 표시 변조 거절, classKey/role 불변 |
| 3-1 그룹 멤버 표시 | B2: toMember 등 소비 경로 보강 후 이름 동일성 대조 축소 | 초대/신청/코드 가입의 권한·차단·통계·가입 순서 유지. optional 표시 손상이 전체 목록을 깨뜨리지 않음 |
| 3-2 잔여 표시·분기 통합 | B3+C2: 실제 제거 가치가 있는 표시 검사와 관련 allow 정리 | 다른 합법 경로 가로막힘·fallback 우회·누락 필드 오류 방지. 기구현 정제 중복 추가 금지 |
| 4 통합 인수 | 최종 생성기→전체 추적 Rules 동기화, 앱 연결·복구 문서 확정 | 전체본 기준 warning0·필요 서버 회귀·권한 유지. 승인된 대상 실제 게시1회·활성 SHA 확인, 이후 사용자 실기기 |

사용자가 지정한 단위까지만 실행한다. 첫 구현 범위는1-1이다. 각 구간에서 독립 후보 전체를 다시 구축하거나
새 실험 구조를 확대하지 않는다. tools/integrate_roster_rules.mjs와 기존 localized pipeline을 기준으로 수정한다.
원본 readable 변환을 수정하고 생성된 rf 번호만 직접 고치지 않는다. 줄맞춤을 보존한다.

확인은 기존 bug024_spark_seal_proof / bug024_preparation_proof / bug024_runtime_regression_runner와
관련 mapper·write plan·개인완료/그룹 count 계약 중 변경 경로만 선택한다. 전체 테스트를 매 구간 반복하지 않는다.
최종 공용 영향 범위에 따라 Flutter 전체 test/analyze 필요 여부를 결정하며 문서 단계에서는 실행하지 않는다.

## 7. 전환·복구·게시 기준

이번 계획의 기본안은 저장 스키마·식별자·필수 쓰기 유지다. 앱 정제와 정상 writer를 먼저 준비하고 Rules 대조를 줄인다.
사용자는 현재 모든 기기가 최신 작업 코드라고 확인했다. 이후 추가 앱 변경은 설치 여부를 최종 인수에서 확인한다.
캐시/오프라인 자료의 표시 정제는 재읽기에도 동일하게 적용하고, 상태 명령은 기존 서버 재검증을 유지한다.
삭제가 아니라 표시 의미만 변경된 자료를 강제로 마이그레이션하거나 과거 완료를 재작성하지 않는다.

각 구간은 변경 전후 전체 Rules/생성 입력·앱 diff·SHA·삭제 조건 목록을 남긴다.
복구는 해당 구간의 diff만 되돌리는 단위로 설계한다. 미커밋 다른 변경은 reset/일괄 덮어쓰기로 제거하지 않는다.
운영36b5920e 복귀가 최신 BUG-024 앱 기능을 지원한다는 뜻은 아니다. 복구 시 기능 호환 상태도 같이 보고한다.
테스트 진단본20dfcdeb/aae06656은 운영 복구본이 아니다. 전역 거절 Rules로 복구하지 않는다.

2026-10-10 후속 사용자 지시로 Rules 수정사항마다 검증한 전체본을1회 게시하고 결과를 확인한다.
게시 대상과 후보를 명시하고 실패 시 자동 재시도하지 않는 기존 정책은 유지한다.
게시 실패 시 동일 명령 재실행 없이 test/rulesets/releases 단계·응답·활성 소스·직전 성공 diff를 기록한다.
테스트 프로젝트의 기능 제외 성공으로 종료하지 않고 실제 기능이 포함된 최종 전체본의 운영 게시가 필요하다.
서버 검사가 약해져 성공하는 결과는 채택하지 않는다. 정상 업데이트에서도 최초 성공·경고·시간·활성 SHA를 기록한다.
자동 반복 게시/예약 모니터링은 하지 않는다.

## 8. 보고 형식과 남은 불확실성

각 구현 결과는 삭제한 조건/검사, 로컬로 옮긴 처리와 연결 파일, 전체 Rules 변화, 보존한 기능, 부작용/미확인 사항,
실제 게시 여부 순으로 보고한다. 크기는 같은 포맷끼리 비교하고 compiled 크기와 혼동하지 않는다.
채택한 제거가 없으면 성과 없음으로 명시하고 조건 복제·분기 추가로 검증 숫자만 늘리지 않는다.
필수 보안을 유지하면서 제거할 중복이 부족하면 근거와 남은 대안을 보고한다. 과거 스키마 전면 이식을 자동 재개하지 않는다.

설계 현재 상태: 함수/Writer/Mapper/DI 연결 조사와 회귀 위험 분류 완료. 개별 조건의 동등성·절감량·새 전체본 게시는
구현 구간에서 확인할 사항이다. 정상 동작을 보장했다고 선언하지 않는다. 동시성 운영 인수와 BUG-024 운영 반영도 미완료다.

공식 근거(2026-10-10 확인): [getAfter·원자 쓰기 조건](https://firebase.google.com/docs/firestore/security/rules-conditions),
[Rules와 쿼리의 권한 관계](https://firebase.google.com/docs/firestore/security/rules-query).
기존 장기 계약: RECURRING_CYCLE_SPARK_ALTERNATIVE_DESIGN, WEEKLY_RAID_CLAIM_CONTRACT,
FIRESTORE_PARTY_COMMAND_CONTRACT, FIRESTORE_PARTY_READ_MODEL_CONTRACT. 충돌 시 새 기능 완화로 임의 해석하지 않는다.


## 9. 1-1 구현 결과 (2026-10-10)

로컬 구현·표적 검증 완료. 운영 게시 안정화는 미확인이다.

- 삭제한 서버 검사: sealAuditUpdate의 playerId/characterId/raidId before==after 비교3개.
  affectedKeys.hasOnly는 이 세 키의 추가/삭제/변경을 이미 금지하고 sealAudit는 결과 ID와 경로/슬롯을 검증한다.
- 제거한 중복 조회 표현: active 이전 상태의 difficulty/role에서 room 재조회2곳. update에서 한 번 읽은
  room을 sealAudit에도 전달한다. create도 같은 경로의 room을 직접 전달한다. getAfter의 room 불변 검사는 유지한다.
- ownershipRevision은 runtime 변환에서 변경 허용 키이며 이전 차수 stub 갱신을 지원한다.
  따라서 그 비교/예외와 live ownership 검사는 제거하지 않았다. 원래 seal 생성 함수만 보고4개 모두 중복으로
  분류했던 초기 판단은 최종 생성본/runtime 대조에서 정정했다. 잘못된 후보는 생성 anchor에서 중단돼 추적본에 반영되지 않았다.
- 로컬로 옮긴 처리: 이번 단위에는 없음. 새 기능/스키마·앱 Transaction 변경 없음.
- 같은 포맷 전체187865→187758bytes(-107), compact145267→145168bytes(-99), 함수285·깊이5 유지.
  최신 전체 SHA e4a6c4cc5d3fbf45757be840b37d951c726b8a31c87bc1d8b2f28ca202325afb.
  compact SHA e0e574a8b298da46ab9a07e38d6acec780b9159c9b3fee0f2520d27345e1507b.
  호출 캐시/컴파일 내부 절감량이나 게시 성공을 이 수치로 추정하지 않는다.
- 생성 경로: bug024_spark_seal_candidate의 simplifyAvailabilityAudit를 localized pipeline 마지막에 적용.
  역사적 baseline 생성/검사 SHA는 유지한다. readable 대조에서 변경 함수는 sealAudit/Update 두 개뿐이며
  나머지 변경은 create allow의 room 인자 전달 한 곳이다. 줄맞춤/생성 일치/preflight/diff 확인 통과.
- 서버 확인: 최신 전체본을 demo 에뮬레이터에 로드해 인증 관련23개 시나리오 통과.
  정상 completed/active/stub 인증과8인 전환, 위조/비방장/주차/Claim/legacy 점유, 완료 필드 보존,
  식별자3개 변조·소유 차수 변경/삭제·잘못된 누락 차수 복구 거절, 이전 차수 stub 정상 갱신 포함.
- 첫 검증은 R1_LISTING 설정 누락으로 준비 단계의 canonical listing 계약이 맞지 않았다.
  기존 지원 설정R1_LISTING=1로 바로잡은 뒤 통과했다. 이를 Rules 회귀나 통과 수에 포함하지 않는다.
  초기 에뮬레이터 소켓 권한 오류는 로컬 권한 실행으로 해소했다. 앱 코드를 수정해 우회하지 않았다.
- 근거 coverage/rules-audit-simplification: before.rules/before-readable.rules, preflight.json,
  fixture-mismatch-results.json, test.log/results.json, emulator.log. BUG024_RULES_FILE=firestore.rules,
  BUG024_RUNTIME=1, R1_LISTING=1, BUG024_FILTER='audit|forged|same-room active normal'.
- 미확인: 실제 원격 컴파일 경고/게시·실기기·운영 동시성. 원격 API/게시 없음.
  다음1-2에서는 guard/슬롯/명령 연결의 중복과 상태별 전환을 다룬다. 1-1의 작은 감소를 목표 달성으로 보고하지 않는다.


## 10. 1-1 운영 게시 결과 (2026-10-10 18:58 KST)

사용자 지시로 전체e4a6c4cc를 lost-party에 --only firestore:rules --non-interactive --debug로1회 게시했다.
생성 일치/preflight 재확인 후 진행. /test200 응답{}·경고0(5.457초), /rulesets200,
release PATCH400, CLI 내부 create fallback409, exit1. 수동 재시도 없음.
사후 활성 SHA36b5920e·ruleset26621a37-ae16-45c4-9858-f10380439e28·updateTime2026-10-08T02:16:46.593197Z 유지.
이번107bytes 축소로 게시 문제가 해결되지 않았다. 컴파일은 통과했으나 활성화 실패가 그대로 재현됐다.
운영 기능 변경 없음. 원인 내부 한도는 여전히 미확정, 다음1-2에서 계획한 기능 보존 간소화를 진행할 근거로 남긴다.
근거 coverage/rules-audit-simplification/publication/{before.json,before.rules,deploy.log,after.json,result.json}.
최신 방침: 이후 Rules 수정 구간마다 검증한 전체본 게시1회·결과/활성 소스 확인, 실패 후 즉시 반복 금지.


## 사용자 직접 게시본 확인 (2026-10-10 19:10 KST 게시)

운영 활성 소스 GET에서 ruleset6b3870e1-06c5-4544-a594-6fd8ee78e73e,
SHA7a441b1f64a3a20122721910b11594d83167eadc6a4c44c16d77395225a1a467/183844bytes 확인.
updateTime2026-10-10T10:10:33.793870Z. 이전36b5920e 유지 상태는 이 게시 이전의 이력이다.
로컬e4a6c4cc 대비3914bytes 감소. 공백 정규화 대조에서 함수 정의11개 삭제 외 의미 있는 텍스트 차이는 없다.
삭제: signedIn(rf0), operatorAssignmentPath(rf3), hasActiveBinding(rf4), isActiveOperator(rf6),
isCurrentPlayerActive(rf23), isCurrentGroupMember(rf24), isActiveGroupLeader(rf25), canApproveApplications(rf27),
sealAvailableBefore(rf31), sealAudit(rf32), sealAuditUpdate(rf33).
삭제 함수 호출151곳이 남아 있다(rf4 85곳 등). 원격 활성화 성공은 확인했으나 정상 기능을 보존한 최적화본이 아니다.
해당 호출을 평가하는 인증/조회/쓰기 경로에서 오류·거절이 발생할 수 있다. 실제 앱 요청은 이번 조사에서 실행하지 않았다.
함수 호출 결과를 let에 넣거나 return하는 것은 함수 자체를 변수로 다루거나 반환하는 것과 다르다.
이번 성공만으로 정상 함수 호출 문법이 게시 실패의 원인이라고 결론내리지 않는다.
정의 삭제가 전체 호출 그래프/컴파일 결과를 바꿨다는 비교 근거로 보존하고, 보안 조건을 유지한 대체 구현을 검토해야 한다.
자동 복구/재배포·로컬 전체본 덮어쓰기 없음. 근거 coverage/rules-user-published/{active.json,active.rules,content.diff,comparison.json}.


## 버전2 문법과 사용자 삭제 성공 대조 (2026-10-10)

사용자 제시 https://hellose7.tistory.com/110 의 함수 규칙을 공식 rules-language/rules-conditions와 대조했다.
삭제 전 로컬 전체e4a6c4cc의285함수 정적 확인: let 최대6, 인수 최대6, 사용자 함수 깊이5,
재귀0, 반복문0, 단일 return 위반0, 미정의 rf 호출0. 근거 coverage/rules-user-published/v2-static-audit.json.
기존 운영 성공본36b5920e와 사용자 성공본7a441b1f도 rules_version='2'여서 이번에 버전2로 바뀐 것은 아니다.
함수 호출 결과를 let/return에 쓰는 방식은 공식 예제에서도 사용한다. 조사한 항목의 문법 위반은 발견하지 못했다.
공식 문서 간 호출 깊이 표기가20/10으로 다르지만 현재5는 어느 쪽도 초과하지 않는다.

공식 https://firebase.google.com/docs/rules/rules-language 의 Expression complexity and compiler limits 절은
중첩 표현식·중복 scope tree로503, compiled executable 크기 초과로400이 발생할 수 있음을 설명한다.
컬렉션 전용 helper의 scope 제한, 거대한 조건 분리, 중복 schema 검사 통합을 권고한다.
이 설명과 사용자 삭제 성공은 총 소스 바이트만이 아니라 함수 가시 범위·호출 그래프·중첩 식의 컴파일 비용을
우선 조사할 근거다. 이전 scope-only 실패 실험은 재시도하지 않고 변경 대상/실제 호출 연결을 다시 구분한다.
사용자 삭제본은11개 정의 삭제로151개 호출이 미정의가 됐으므로 정상 실행 그래프의 비용 감소와
미정의 경로 처리에 따른 컴파일 결과 변화를 분리해야 한다. 특정 문법 또는 특정 함수 단독 결함으로 확정하지 않는다.
다음 후보는 삭제11개 중 공통 권한 함수와 전용 인증 함수를 분리하고, 정의/호출을 모두 유효하게 유지하며
같은 보안 조건을 직접식·제한된 scope로 대체하는 비교안을 설계하는 것이다. 이번 조사에서 구현/게시 없음.


## 직접 조건식 중심 구조 — 사용자 후속 지시 적용

이번 구현 단위는 공통 인증·권한 helper 평탄화다. 사용자 삭제 성공을 근거로 기존1-2보다 우선한다.
기준은 함수가 누락된 운영본이 아니라 보안 검사가 온전히 있는 로컬e4a6c4cc다.

- hasActiveBinding/currentPlayerId/isActiveOperator/isCurrentPlayerActive/isCurrentGroupMember/
  isActiveGroupLeader/canApproveApplications의 내부 사용자 함수 호출을 경로·조건 직접식으로 바꾼다.
- signedIn의 한 줄 조건은 호출 위치에 직접 사용하고 미사용이 된 경로 helper만 제거한다.
- 90개 이상 호출되는 binding 검사를 모든 caller에 복사하지 않는다. 공유 권한 경계 함수는 유지하지만
  그 함수 내부에서 다시 사용자 helper를 호출하는 연결은 없앤다. built-in get/exists는 필수 데이터 확인이다.
- null 인증/없는 binding, inactive binding/player/operator, 다른 그룹원/리더, 승인 대리인의 분기를 보존한다.
  기존 OR 허용 조건과 검사 순서를 유지하고 optional 값에 기본 허용을 넣지 않는다.
- 함수 내부 direct path의 중복 문자열로 소스가 늘 수 있다. 이는 삭제 검사가 없는 구조 변경으로 보고한다.
  수치 목표로 권한을 제거하지 않는다. 깊이·호출 연결·전체 크기·실제1회 게시 결과를 함께 판정한다.
- 이번 범위에서 sealAudit/Update의 보안/주차 로직, 앱·스키마·읽기 권한은 바꾸지 않는다.
  후속은 전용 인증 helper와 전환의 연결 정리, 나머지 준비/표시 이전 순서다.
- 확인: 변경 helper의 사용자 호출0, undefined 호출0, 전체 생성 일치, 원래 조건과의 동등성,
  인증/그룹/운영자 권한 허용·거절 및 기존8인 인증 흐름의 직접 영향 확인. 로컬 완료 후 운영1회 게시.
- 현재 운영 누락 함수로 인한 위험을 숨기지 않는다. 후보 게시가 실패하면 기존 활성본을 확인하고
  임의 추가 복구 게시 없이 사용자에게 상태와 필요한 복구 결정을 보고한다.


### 공통 권한 직접식 후보의 비용 검토

7개 공통 함수 내부 사용자 함수 호출 표현27개를0개로 교체. signedIn/operatorAssignmentPath 정의2개 제거.
bindingPath는 다른 경로에서5곳 사용하므로 유지하며 미정의 호출을 남기지 않는다.
전체187758→189196bytes(+1438), compact145168→146628(+1460), 전체 최대깊이5 유지.
추가된 바이트는 권한 연결을 없애기 위해 직접 적은 경로·동일 조건이다. 새로운 권한 검사는 없고 삭제된 보안 조건도 없다.
직전 소스 크기 상한145267은 성과 목표가 아닌 로컬 증가 경보였다. 사용자 지시의 호출 최소화 실험에 따라
명시적 비용 검토 후146628로 갱신한다. 이 예외를 향후 조건 추가의 여유로 쓰지 않는다.
정확한 효과는 실제 전체본 게시에서 판정하며 내부 compiled 크기가 줄었다고 추정하지 않는다.


### 직접식 공통 권한 구현·로컬 검증

로컬4987ed9ccecf4d4275660ab655e759c89ec47968e9d462b69a351fd32f453dcc,
189196bytes, compact c41af5cc/146628bytes. 함수285→283, 전체 최대깊이5 유지.
각 공통 함수 내부에서는 사용자 함수 없이 get/exists와 직접 경로·조건으로 판정한다.
signedIn은 request.auth != null로 치환, operatorAssignmentPath는 미사용이 되어 삭제했다.
나머지 함수 본문/allow 조건은 signedIn의 동일 식 치환 외 불변임을 대조했다.

새로 삭제한 서버 보안 검사0, 로컬로 옮긴 처리0. 이번 성과는 내부 호출27곳 제거와 wrapper2개 삭제다.
공유 권한 경계는 유지해90개 이상의 caller에 긴 조건을 복제하지 않는다.
처음에는 bindingPath도 미사용 후보로 봤으나 다른 참조5곳이 남아 삭제하지 않았다.

변경 전후 전체 readable 소스에 테스트 전용 read probe를 추가해12종 권한 상태를 대조했다.
로그인 없음/연결 없음·비활성/활성, player 없음·비활성, operator 없음·비활성,
그룹 비회원/비리더, 승인 대리/권한 없음, 거절 경로와 OR true 대체 경로의 허용 결과가 동일했다.
probe 경로는 배포 소스에 포함하지 않는다. 이 검증은 canApproveApplications의 기존 caller 의존도도 보존하며
함수 단독 판정에 새로 active 조건을 추가하거나 없애지 않았다.
최종 compact 후보의 기존 인증 관련23개 시나리오도 통과했다(8인, stub/완료/active, 소유권/위조/Claim 경계).
undefined 함수 호출0, 생성 일치/preflight/diff 확인. 앱/스키마/Router 변경0으로 Flutter 전체검증은 반복하지 않았다.
근거 coverage/rules-auth-direct/{structure.json,depth.json,auth-results.json,results.json,auth-test.log,regression.log}.
실기기 정상 흐름과 운영 동시성은 미확인이다. 원격 게시 결과는 별도 기록한다.


### 직접식 전체본 운영 게시 — 실패 (2026-10-10 20:57 KST)

사용자 수정마다1회 게시 지시에 따라4987ed9c를 lost-party에1회 시도했다.
컴파일200 응답{}·경고0(4.612초), 생성200, 활성화PATCH400 INVALID_ARGUMENT,
CLI 내부 create fallback409 ALREADY_EXISTS, CLI exit1. 재시도 없음.
사후 active7a441b1f/183844bytes, ruleset6b3870e1-06c5-4544-a594-6fd8ee78e73e와19:10 게시 시각 유지.
운영은 여전히 사용자가11개 함수를 삭제한 상태이므로 기능 인수 불가·미정의 호출 영향 주의 상태다.
새 후보가 검증을 통과했다는 사실로 운영의 누락을 복구했다고 보고하지 않는다.

결론: 공통 권한7개 함수 내부 호출 제거만으로 활성화 문제는 해결되지 않았다.
따라서 일반적인 함수간 호출 자체가 단독 원인이라고 해석하지 않는다. 전용 인증/전환의 조건 조합·전체 컴파일 비용은 남아 있다.
전체 호출 최소화 작업 중 첫 공통 권한 단위만 완료했으며 전체 구조 변경·정상화 완료가 아니다.
다음은 sealAudit/Update/AvailableBefore와 전환 호출 연결의 직접식 비교 또는 정상 운영본 복구 판단이다.
같은 후보 재시도, 다른 기능 임의 삭제, 자동 복구 게시 없음. 근거 coverage/rules-auth-direct/publication.


## 다음 구현 — 주차 인증·전환 호출 연결 정리

현재 기준4987ed9c의7개 권한 평탄화는 보존한다. 이번 범위는 주차 인증/전환에 한정한다.
sealAuditUpdate→sealAudit를 하나의 인증 함수로 통합하고 create/update 여부는 Rules 호출부의 상수로 전달한다.
create에는 실제 신규 data를 before 인자로도 넘겨 null sentinel을 쓰지 않는다. update만 이전 기록 불변/허용 상태를 검사한다.
sealAvailableBefore와 bug24CommandIncludes의 짧은 조건은 실제 호출부에 옮기고 정의를 제거한다.
sealPrepared의 슬롯 일치는 직접식으로 바꾸며 index 경계·소유 차수·role·character/player 일치를 모두 유지한다.
전환에서 lastCommandType=='advanceCycle'이 이미 포함하는 lifecycle enum 검사를 해당2경로에서만 제거한다.
인증 경로의 방/assignment/Claim 경로 wrapper 호출은 직접 경로로 바꾸고 Claim ID 조합은 동일하게 유지한다.
이전/현재 완료·stub·활성 상태, guard 일부 변경/누락·중복 인증·소유권 이전,8인 전환과 Claim 충돌을 확인한다.
앱/스키마/다른 준비·표시 흐름 변경 없음. 검증된 전체본으로 운영 게시1회. 실패 시 추가 게시/자동복구 없음.


### 주차 인증·전환 호출 정리 결과 — 2026-10-10 21:05 KST

구현: sealAuditUpdate를 sealAudit에 통합하고 sealAvailableBefore/bug24CommandIncludes는
호출 위치의 직접 조건식으로 바꿨다. sealPrepared의 슬롯 검사와 인증/전환의 문서 경로도 직접 표현한다.
삭제 정의3개, 사용자 함수 호출 표현1026→1012(-14), advanceCycle과 중복되는 lifecycle 판정2개 제거.
로컬로 옮긴 처리0, 앱/스키마 변경0. 핵심 권한·Claim 충돌·소유 차수·슬롯 연결 검사는 보존했다.
create/update는 Rules 호출부 상수로 구분하며 update의 이전 기록 검사식을 그대로 유지한다.

전체 e9287f2c95362a1cfb7245b7aef784d257b879104f4d26e01318c498b4bf7dfa/189882bytes,
직전4987ed9c 대비+686bytes. compact f1d80871/147270bytes(+642), 함수283→280, 최대깊이5 유지.
직접 표현으로 호출 연결을 줄이는 비용을 검토해 로컬 증가 경보를147270으로 갱신했다.
소스 감소 또는 compiled 크기 감소로 보고하지 않으며, 이 수치는 게시 성공의 근거가 아니다.

보존 확인: 8인 준비→인증→전환→완료, 없는 stub/같은 방·다른 방·수동 완료/활성 상태,
Claim 동시 생성과 위조·소유권 변경·구형 stub 승격·guard 일부 제거 거절 등 관련32개 통과.
미정의 호출0, 이전 update 검사식 보존, 생성/preflight/diff 확인 완료. Flutter 전체검증은 앱 변경 없어 생략.
실기기 정상 흐름과 운영 동시성 인수는 미확인이다. 근거 coverage/rules-seal-direct의
structure.json/depth.json/results.json/preflight.json 및 test.log.

운영 lost-party 전체본 게시1회: /test200·응답{}·경고0, /rulesets200,
/releases/cloud.firestore PATCH400 INVALID_ARGUMENT, CLI 내부 fallback POST409 ALREADY_EXISTS, exit1.
사후 활성7a441b1f/183844bytes와 ruleset6b3870e1-06c5-4544-a594-6fd8ee78e73e,
19:10 KST 게시 시각 유지. 재시도/복구 게시 없음. 근거 coverage/rules-seal-direct/publication.
사용자 삭제본의 미정의 호출151곳은 운영에 남아 있으며 기능 정상화를 확인한 상태가 아니다.

판정: 공통 권한에 이어 이번 전용 호출 연결 제거도 전체본 활성화를 해결하지 못했다.
함수 호출 횟수만으로 원인을 확정하거나 같은 직접식 치환/게시를 반복하지 않는다.
이번 변경은 로컬 구조 정리이며 운영 정상화·전체1-2 완료가 아니다.
다음1-2 잔여는 guard/슬롯/명령의 중복 조건과 상태별 allow 분기를 실제로 줄일 수 있는지
기존 쓰기 계약과 대조하는 것이다. 단순 inline 확대 대신 중복 검사·분기 제거 가능성을 우선 판정하고,
핵심 권한/원자성 조건을 제거하거나 미정의 함수를 남기지 않는다.

## 1-2 이어서 구현 — 전환 출력 검사 통합

기준 e9287f2c의 누적 변경을 유지한다. sealAdvanceIdle/bug24AdvanceCompleted를 sealAdvance로 합치고
호출부의 고정 boolean으로 strict stub과 이전 completed를 구분한다. 각 기존 상태 전용 검사를 먼저 수행하고
방 명령·시각·출력 신원/상태/주차/난이도·commandTargets 검사를 한 곳에서 수행한다.
완료 분기의 ownershipRevision 동등 비교는 affectedKeys.hasOnly가 키의 추가/삭제/변경을 모두 금지하므로 제거한다.
strict stub의 revision1, completed의 revision+1/완료 필드 제거, live ownership 및 guard 검사는 유지한다.
기존 active→active/완료·일반 참가 fallback은 변경하지 않는다. 앱·스키마 변경 없음.
확인은 8인 stub/같은·다른·수동 완료/active 전환, 명령 대상 누락·인증 변조·소유 차수 변경 거절이다.
변경 후 전체본의 생성 일치/미정의 호출/표적 서버 경계를 확인하고 운영 게시 정확히1회. 실패 후 재시도 없음.


### 1-2 전환 출력 통합 구현 (2026-10-10)

직전 e9287f2c 위에 누적 적용했다. sealAdvanceIdle/bug24AdvanceCompleted를 sealAdvance로 통합해
방 명령/시각, 출력 ID·schema/status/source·주차/raid/difficulty·updatedAt·명령 대상 검사 본문을 공유한다.
Rules 호출부 상수 true/false로 상태별 검사를 먼저 선택하며 클라이언트가 분기를 선택하지 않는다.
completed의 ownershipRevision 동등 비교1개는 변경 허용 키 목록에서 이미 보호되어 삭제했다.
완료 분기의 guard 불변과 ownershipRevision 키 추가/삭제/변경 금지, stub의 strict 키/revision1,
완료의 revision+1/완료필드 제거는 유지한다. 앱/로컬 이전0, 다른 함수 본문 불변 확인.

전체 2ba47bd82a0d307fea251452bb947ee09a94616d2f495a45155d9813094ab9a7/189115bytes,
직전189882 대비767bytes 감소. compact56513d0f/146583bytes(-687), 함수280→279·최대깊이5 유지.
기존 두 allow 호출의 인자만 교체하고 다른 전환/참가 fallback은 보존한다.
8인 stub/같은·다른·수동 완료/active 전환, 위조·Claim·소유권·부분 guard 경계32개 통과.
미정의 호출0, 생성/preflight/diff 검증 통과. 로컬 Java 인수 따옴표 오류는 실행 명령만 고쳐 해소했다.
실기기와 운영 동시성 인수는 미확인. 증거 coverage/rules-advance-shared.
이번 범위는1-2 전환 출력 중복 정리이며 이후 active 경로 전체 재작성은 하지 않았다.


운영 게시1회(23:38 KST): 컴파일200/경고0·Ruleset생성200, 활성화PATCH400 INVALID_ARGUMENT,
CLI 후속POST409 ALREADY_EXISTS. 활성7a441b1f/183844bytes·19:10 KST 유지. 추가 게시/복구 없음.
따라서 이번 중복 본문 감소도 게시 정상화에는 부족했다. 내부 compiled 크기는 미확인이다.
commandTargets 검사는 원자성 보호이므로 슬롯 검사와 중복으로 보고 삭제하지 않았다.
active 경로의 기존 난이도/역할 불변 조건도 완료 기록 전환과 달라 무리하게 합치지 않았다.
1-2에서 안전하게 확인한 전환 출력 통합까지 로컬 완료. 다음은2-1 준비 변경의 문서별 중복 검사 책임 정리다.
운영의 사용자 함수 삭제본은 그대로이며 미정의 호출151곳의 기능 영향은 해결되지 않았다.

## 2-1 구현 전 책임 판정

모집 Aggregate는 구성/targets/count, 필수 신규 이벤트/멤버/그룹 목록 연결을 책임진다.
멤버는 본인·이전/새 캐릭터의 현재 소유권·legacy 점유를, 이벤트는 이전/새 state·Claim 보존을 책임진다.
이벤트의 room 시각/revision/cycle, 멤버의 room revision/updatedAt과 character 변경 검사는
다른 allow·단독 쓰기와의 결합을 보장하므로 이번에는 삭제하지 않는다. getAfter만으로 다른 validator 실행을 추정하지 않는다.

안전한 삭제3개: sparkPrepRecords/bug24PrepMember의 직접 hasActiveBinding은 동일 AND의 bug24PrepState가
동일 요청 인증을 검사한다. bug24PrepPair의 oldMember.playerId==member.playerId는
member.diff(oldMember).affectedKeys().hasOnly가 playerId 추가/삭제/변경을 금지하고 현재 member.playerId도 actor와 비교한다.
그 외 조건·순서, 필수 문서 연결, 앱/스키마/표시 계약은 보존한다. 실제 절감이 작음을 명시한다.
정상8인 준비와 필수 문서 누락·단독 이벤트·비활성 인증·ID 변경·state/Claim 끼워쓰기 거절을 확인한다.
검증 후 누적 전체본을1회 게시하고 실패하면 재시도하지 않는다.


### 2-1 로컬 구현 결과

직전2ba47bd8에 누적 적용. 중복 인증 호출2개·멤버 ID 동등 비교1개 제거.
문서별 시간/revision/actor·필수 쓰기 연결은 유지했다. 다른 함수 본문은 불변이다.
전체3f683e9b/189056bytes(-59), compact e8c13d7b/146524bytes(-59), 함수279·깊이5 유지.
로컬 이전0, 앱/스키마 변경0. 이 범위의 대폭 절감 근거는 없으며 작은 정리로 분류한다.

8인 반복 준비와 state/Claim 보존, 모집/member/listing/event 누락, 권한/슬롯/완료 변조,
state 삭제/끼워쓰기, inactive binding, 멤버 ID 변경, 단독 이벤트/재사용 거절15개 통과.
별도 기존 Claim 보존·삭제 끼워쓰기 경계1개 통과. 생성/preflight/diff 검증 완료.
실기기와 운영 동시성 인수는 미확인. 앱 코드 무변경으로 Flutter 전체검증은 반복하지 않았다.
증거 coverage/rules-prep-dedup/{structure.json,results.json,claim/results.json,preflight.json}.

23:43 KST 운영1회 게시: 컴파일200/경고0·생성200 후 활성화400 INVALID_ARGUMENT/CLI fallback409 ALREADY_EXISTS 실패. 활성7a441b1f 유지, 재시도/복구 없음.
게시 정상화 미완료. 2-1에서 문서간 검사 대폭 제거는 안전 근거가 없어 미채택했다. 다음2-2 표시 복사 대조의 로컬 이전을 진행한다.


## 2-2 판정 — 표시 원본 대조 완화 미채택

현재3f683e9b 누적본을 기준으로 실제 writer/read mapper/명령 연결을 조사했다.
PartyAtomicMemberMutationWritePlan은 방장 본인일 때만 membership의 이름/직업 표시를 모집에 복사한다.
PartyReadDocumentMapper의 목록/상세는 _softString으로 누락·타입 오류·공백을 null/trim 처리한다.
현재 _softString에는 제어문자 제거/길이 제한이 없으므로 완화 시 표시 전용 정제 보강이 필요하다.
이 helper는 status/groupId 등에도 사용되어 일괄 정제 변경은 금지하고 표시 필드만 분리해야 한다.
PartyAtomicDocumentMapper.aggregate는 방장 Snapshot을 명령 권한/구성에 사용하지 않으며 슬롯의 classKey/role을 사용한다.
실제 Router는 FirestorePartyAtomicMemberMutationRepository를 연결하고 read Repository는 위 mapper를 사용한다.

검토 후보는 bug24PrepPair 방장 분기의 이름·직업명 원본 비교2개만 문자열 타입/최대256자 검사로 바꾸는 것이다.
비방장의 기존 값 불변 분기와 모든 식별자/role/classKey/구성·필수 쓰기는 보존하는 안으로 비교했다.
이 후보는 비교2개를 제거하지만 타입/길이4개를 추가한다. 전체189056→189114bytes(+58),
compact146524→146582bytes(+58). 함수/호출 깊이·문서 조회 제거0. 근거 coverage/rules-prep-display-review/comparison.json.

이 변화가 내부 compiled 크기를 줄인다고 입증하지 못했다. 현재는 member를 권한/슬롯/소유권 검사에 계속 읽으므로
표시 대조를 없애도 문서 읽기가 사라지지 않는다. 서버 진실성 보장을 낮추고 앱 정제를 추가할 비용에 비해
게시 정상화를 위한 구조 절감 근거가 없다. 따라서 설계§8의 제거 가치 판정에 따라 미채택한다.
이는 로컬 이전 완료가 아니다. 실제 삭제/이전/Rules 감소0, 앱/Rules 파일 수정0, 테스트/게시0.
기존 누적3f683e9b를 유지한다. 기존 정상 writer/권한 계약은 변경하지 않았다. 실기기 추가 검증 없음.
다음3-1 그룹 멤버 표시도 후보 단계에서 조회/함수/분기 감소가 있는지 먼저 판정하고,
같은 타입/길이 검사 치환만으로 끝나는 안은 자동 구현/게시하지 않는다.


## 2026-10-11 전체 총량 가설 — 다른 함수군 삭제 게시 성공

사용자 지시로 국소 최적화 대신 별도 함수군 삭제 진단을 테스트 프로젝트 rules-test-1-81e31에서1회 수행했다.
기준은 보존e913f1a의 전체3f683e9b/189056bytes. 원본 Rules·운영 프로젝트는 수정하지 않았다.
이전 인증 삭제군과 다른 그룹 관련 함수 중 본문이 큰8개를 골랐다:
- validInitialGroup
- validAtomicGroupRecruitmentCloseBody
- validGroupBlockCreate
- validGroupApplicantStatsWrite
- validJoinCodeGroupMember
- validApprovedGroupMember
- validGroupPendingJoinRelation
- validGroupJoinRelationDecision
정의8개를 삭제하고 남은 호출10곳을 false로 치환했다. 미정의 호출을 남기는 실험이 아니며 해당 기능 경로는 비활성화된다.
전체178185bytes(-10871), 후보e64f152d32cf4b107579f08721da990fee1b42bcd92321fa811ca4477df7a650.
컴파일200·생성200·활성화PATCH200, CLI exit0. 원격 경고11개. 경고는 로컬 result.json에 보존한다.
00:11 KST 활성 SHA 일치, ruleset e149d7e4-336a-4f3c-86bc-e8cef09bba36 확인.

판정: 이전 의심 인증 함수군을 유지해도 다른 함수군을 제거하면 게시된다. 특정 인증 함수 자체보다
전체 조합의 총량/컴파일 복잡도 부담이라는 설명을 추가로 지지한다. 정확한 내부 한도/compiled 크기는 미측정이다.
이는 기능 보존 수정본이 아니라 사용자 승인 진단본이다. 테스트 프로젝트는 이제 이 기능 제외본이 활성 상태다.
기능 테스트·운영 배포·자동 복구·재시도 없음. 운영 활성본은 이번 재조회하지 않았다.
근거 coverage/rules-group-removal/{build.mjs,manifest.json,firebase.json,deploy.log,before.json,after.json,result.json}.
이 결과로 기존 작은 수정 계획을 자동 재개하지 않는다. 후속 설계는 전체 구조 부담 감소를 기준으로 재판단한다.
