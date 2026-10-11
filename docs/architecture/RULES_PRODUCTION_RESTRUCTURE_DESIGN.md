# 운영 Rules 전체 구조 재설계안

2026-10-11. **B1+A2 전체 기능 후보 테스트 게시 성공·활성SHA 일치. 운영 전환 대기.** 최신 결과는 §14와 NEXT_WORK다.
기존 세 방향 설계의 작은 수정 순서를 대체한다. Spark 유지, 기존 기능 보존, 감소율 목표 없음.

## 1. 결론과 적용 방식

운영 적용의 우선안은 **현재 저장 경로·쓰기 계약을 유지한 전체 검증 구조 통합**이다.
각 기능에서 조금씩 문구를 삭제하고 운영 게시하는 흐름을 중단한다. 문서별 공통 검사를 진입점으로 모으고,
명령별 함수에는 달라지는 권한/상태 전이만 남긴다. 조건별 책임을 확정할 수 있을 때만 문서간 재검사를 제거한다.
하나의 기능 보존 전체 후보를 만들어 테스트 프로젝트 게시와 핵심 보안 검증을 확인한 뒤 운영으로 옮긴다.
그룹 기능을 삭제한 진단본이나 false 분기를 운영에 이식하는 계획이 아니다.

이 안의 게시 성공은 아직 입증되지 않았다. 설계로 확정한 것은 변경 원칙/대상/전환 절차이며,
전체 후보의 절감량·내부 실행 크기·실제 게시 성공은 구현 후 판정한다. 성공하지 않은 안을 완성이라고 부르지 않는다.

## 2. 기준과 진단 해석

| 자료 | 의미 | 적용 가능 여부 |
|---|---|---|
| e913f1a 커밋의 전체3f683e9b |189056bytes·279함수·깊이5. 활성화400/fallback409 실패|기능 보존 재설계 출발점|
| 이전49acce8 전체fd90aa93 |187865bytes·285함수·깊이5|회귀 비교/누적 변경 평가용|
| 인증군 제거20dfcdeb/단독aae06656 |테스트 게시 성공|진단만|
| 다른 그룹8함수 제거e64f152d |178185bytes·활성화200·활성SHA일치, 경고11|진단만, 기능 제외 상태|
| 운영 마지막 확인7a441b1f |사용자 삭제11함수·미정의 호출151곳|정상 기능 기준/복구 후보로 사용 금지|
| 과거 정상36b5920e |BUG-024 인증 확장 이전 게시 성공본|현재 앱 호환 확인 없는 자동 복구 금지|

서로 다른 함수군을 덜어내도 성공한다는 결과를 전체 조합 부담을 줄이는 설계의 근거로 삼는다.
10871bytes가 정확한 초과량이거나 그만큼 줄이면 반드시 성공한다는 뜻은 아니다.
함수 수/호출 깊이만 보지 않고 중복 본문·분기·상속 범위와 전체 원격 결과를 본다.
Firebase 공식 문서는 중첩식/범위 복제와 컴파일 실행 크기를 게시 실패 요인으로 설명한다.
소스 크기와 compiled 크기는 다르며 우리 실패 응답에는 정확한 내부 크기가 없다.
근거: https://firebase.google.com/docs/rules/rules-language#expression_complexity_and_compiler_limits

## 3. 세 가지 적용안 비교

| 안 | 앱/데이터 영향 | 선택 |
|---|---|---|
| A. 기존 스키마에서 공통 진입점·명령별 검사 통합 |기본적으로 앱/데이터 이행 없음. 권한 결과 보존|우선 구현안|
| B. 표시/파생 자료의 쓰기 계약 자체 축소 |Mapper/Writer/조회 수정, 일부 기존 데이터 호환 필요|A의 실제 부족이 확인되면 별도 승인할 대안|
| C. 신뢰 서버 명령 처리/DB 분리/기능 삭제 |비용·권한·배포·데이터 구조 또는 제품 기능 변경|Spark/현재 범위에서 제외|

Rules 파일을 여러 파일로 나눠 합치는 것만으로 총 컴파일 부담이 사라지지 않는다.
전체 inline, 같은 scope 이동 실험, 구문 압축 재반복, 기존 D-X1 실험 구조의 기능 이식도 기본안이 아니다.
기존 누적본을 출발점으로 하되 공통 인증 직접식으로 늘어난 부분은 최종 구조에 맞춰 검토한다.
무조건 원본 복귀나 무조건 누적 보존 대신 변경별 동등성과 전체 비용을 근거로 채택한다. 기존 파일은 보존한다.

## 4. 목표 구조와 구체 교체 대상

각 문서 쓰기는 **공통 형식/신원 검사 → 명령 구분 → 해당 상태 전이/원자 연결**을 거친다.
공통 검사 밖으로 빠지는 별도 allow가 있으면 공통 게이트가 무력화되므로 겹치는 match까지 확인한다.
미지정 명령은 거절한다. marker는 분류용이지 권한 증명이 아니다.
함수는 필요한 공통 경계만 유지하며 wrapper→wrapper→validator 사슬은 제거한다.
명령 validator가 다른 명령 validator를 부르지 않고 필요한 상태/문서를 명시적으로 전달한다.
문서별 helper scope를 사용하되 앞서 실패한 scope-only 변환을 다시 성과로 계산하지 않는다.

### A1. 그룹 가입 전체 검증 통합

현행 groups/{groupId}/members 생성은 validInitialGroupMember/validInvitedGroupMember/
validApprovedGroupMember/validJoinCodeGroupMember 네 경로가 validNewGroupMemberCore와
validGroupMemberOptionalNumberFields를 각각 호출한다. Core가 다시 DocumentKeys를 호출한다.

- member create 진입점에서 허용 키·schema/groupId/playerId·revision1·생성/가입/수정 시각·표시 형식을 한 번 검사한다.
- joinedBy(created/invitation/application/joinCode)를 정확히 구분한 후 방식별 actor·권한·관계·순서만 검사한다.
- created의 본인 leader, invitation의 본인 수락, application의 그룹장 대리 승인, joinCode의 본인 가입을 혼합하지 않는다.
- 공통 active 조건을 임의 강화하지 않는다. created는 현재 hasActiveBinding 경계이며 나머지 player 활성 조건 차이를 그대로 유지한다.
- 기존 네 함수의 중복 Core/Optional 호출과 Core→DocumentKeys wrapper는 새 게이트에 통합되어 없어질 대상이다.
- 관계 결정은 invitation/application/joinCode의 공통 diff/revision/시각을 가능한 교집합에만 한 번 배치한다.
  가입코드 수락이 기존 초대/신청 결정 OR와 겹칠 수 있으므로 단순 첫 분기 우선 ternary로 바꾸지 않는다.
- pending 관계도 공통 키/상태/만료/비회원/차단 검사는 하나, 초대자/신청자·신청 횟수만 별도 조건으로 구성한다.
- groupRelations는 이미 공통 게이트가 일부 통합돼 있으므로 재작업 성과로 세지 않는다.

기능 보존 대상: 생성, 초대/신청/재신청/취소/만료/거절/승인, 코드 가입·폐기,
그룹원 목록, 본인 탈퇴, 방장 이전/해산, 차단/해제. 삭제 실험8개 함수 기능을 모두 복원한 전체 후보여야 한다.

### A2. 그룹 문서 update의 명령 분기 통합

현행 그룹 update에는 가입/승인/탈퇴/승계/해산/코드/활성 모집 변경의 OR와 중복 진입이 섞여 있다.
validGroupJoinCommandUpdate가 여러 진입점에 등장한다. 먼저 각 경로의 허용 필드/상태/actor 교집합을 표로 만들고
가입 인원 증가 경로를 한 분기로 묶는다. 승인 권한과 본인 가입 권한은 그 내부에서 보존한다.
활성 모집 카운터 증감은 close/open 공통 키·시간·revision을 한 번 검사하고 서로 다른 상태 전이만 분리한다.
validAtomicGroupRecruitmentCloseBody의 공개 전환/전체 종료/개인 마지막1인 종료는 서로 다른 합법 상태이므로 보존한다.
인원수/활성 모집수는 가입한도·해산 금지에 쓰이므로 로컬 표시 계산으로 대체하지 않는다.

### A3. 파티 명령·raidState 진입 구조 통합

모집 update, members update, raidStates update의 긴 중첩 allow를 명령 책임표에 따라 교체한다.
준비 변경, 인증만 갱신, guard-only 소비, active 변경, 완료, 소유권 이전/정리는 별도 의미다.
공통 필드 검사와 명령 validator의 중복은 통합하되 없는 필드에 접근하기 전에 상태를 구분한다.
기존 개인 완료 우선 분기로 평가 한도를 피한 이력을 보존하며 다시 뒤의 fallback으로 밀지 않는다.
현재/과거 guard·완료·active·타방/이전 소유 차수·manual의 유효 경로를 정의한 뒤 OR 동등성을 확인한다.
공통 검사라고 가정한 것을 모든 상태에 적용해 구형/누락 자료를 거절하는 변경은 금지한다.
8인 전환의 인증 선행 transaction과 핵심 최종 원자 transaction은 유지한다.

### 검사 책임표 — 삭제 승인 근거

| 기록 | 최종 책임 | 다른 기록에 남길 최소 연결 |
|---|---|---|
| 모집 원본 |actor·명령·슬롯/정원/구성·revision·전이|변경 대상 state/member/event/listing과 정확한 연결|
| raidState |경로 소유자·live ownership·점유/완료·guard·상태 전이|모집 명령/대상/주차/revision 연결|
| 그룹 원본 |방장·인원/활성 모집 집계·그룹 상태|회원/모집의 실제 변경과 연결|
| group member |member 신원/역할/가입 권한·순서|관계 수락/그룹 증분/본인 요약 연결|
| joinRelation |초대/신청 결정·actor·만료·불변식|승인 시 member, 차단 시 block의 필수 쓰기|
| membershipState |본인 그룹 수 한도·집합 변화|정확한 그룹 membership 변화|
| partyEvent |이벤트 불변·대상/주체/명령 결합, 현재 준비의 state/Claim 보존|실제 명령 revision/시각과 일치|
| listing/관계 projection |읽기 공개 범위·신원·최소 형식|원본 연결 및 필요한 원자 갱신|

위 표만으로 삭제하지 않는다. 각 삭제는 담당 함수·경로·before/after·변경 강제식·다른 allow 우회 여부를 근거로 기록한다.
getAfter는 해당 validator가 실행됐다는 증명이 아니다. 실제 생성/삭제/revision 변화와 전체 요청 결합을 확인한다.
공식 getAfter/접근 한도: https://firebase.google.com/docs/firestore/security/rules-conditions

## 5. 로컬로 옮길 것과 유지할 것

기존 표시 정제/정렬을 신규 절감으로 세지 않는다. 우선안 A는 서버 구조 통합이며 로컬 이전 효과를 약속하지 않는다.

| 대상 | 판단과 제품 영향 |
|---|---|
| 이름·직업 표시·레벨/전투력 정제 |로컬 담당 가능. ID/slot classKey/role에는 적용 불가. GroupDocumentMapper 기존 정제 재사용|
| 표시 원본 동일성 |표시 진실성 완화가 허용되고 함수/조회 묶음이 실제 사라질 때만 채택. 단순 비교2→타입4였던2-2는 재개 안 함|
| 목록 정렬/편의 필터 |권한상 읽을 수 있는 현재 페이지 안에서 로컬. query/cursor/limit 유지, 전체 다운로드로 확장하지 않음|
| applicantStats.applicationCount |현재 재신청 계약/차단 snapshot과 연결. 단순 UI 수치로 보고 삭제 불가|
| memberCount/activeRecruitmentCount/activeGroupIds |한도/가입/해산 권한에 사용. 서버 유지|
| auth binding/player/소유권/차단/점유/주차 |서버 유지. 로컬 검증만으로 대체하지 않음|
| 완료 이력/공유 이벤트 |다른 기기·사용자에게 필요. 로컬 전용 전환/삭제 제외|

대안 B는 표시 projection의 권한 필드와 표시 payload를 분리하고 한정된 형식 계약으로 처리하는 안이다.
현 스키마에 새 스키마를 더해 양쪽 validator를 영구 유지하면 오히려 늘어난다. B 착수 전 읽기/쓰기 전환,
과거 데이터 수량·손상/누락·오프라인 쓰기·이행 비용과 구버전 종료를 별도로 확정한다. 현재는 미승인 후보다.

## 6. 실제 앱 연결과 보존 범위

- app_router.dart의 FirestoreGroupCreate/Join/Application/JoinCode Repository와 GroupReadRepository 연결 유지.
- group_create_write_plan.dart는 group/member/membershipState/memberRelation 네 문서를 원자 생성한다.
- group_join_write_plan.dart, group_application_write_plan.dart, group_join_code_write_plan.dart의 transaction 묶음 유지.
- 그룹장은 대상 private membershipState를 읽지 않고 union/increment로 쓰므로 새 설계도 private read를 요구하지 않는다.
- group_active_recruitment_write_plan.dart의 증감과 해산 차단 보존.
- FirestorePartyAtomicCommandRepository._certifyAdvance와 PartyAtomicMemberMutationWritePlan의 준비/전환 분리 유지.
- FirestoreGroupReadRepository는 본인 groupRelations, 그룹 joinRelations/members를 조회한다. 앱에서 필터한다는 이유로 읽기 권한 확대 금지.
- PartyReadDocumentMapper의 _softString은 상태/ID에도 사용된다. 표시 정제 변경 시 전용 경로만 수정한다.

## 7. 부작용과 방어

| 위험 | 확인/대처 |
|---|---|
| 공통 게이트로 과거 정상 문서 거절 |create/update 분리, optional 필드·구형 차수·재가입·오래된 요청 기준 보존|
| 분기 우선순위가 다른 합법 OR 경로 차단 |기존 허용 집합 대조, 중복 분기는 먼저 합집합 의미를 명시|
| 본인/방장 대리 승인 혼동 |actor별 정상/위조·타인 private read 불가 확인|
| 재사용 이벤트/인증/동시 가입 |revision·request.time·대상 ID·실제 변경 강제 유지, 부분 쓰기 전부 거절|
| 공통 함수 인자 사전 조회로 접근 증가 |선택하지 않은 분기의 get/getAfter를 공통 let에 미리 넣지 않음|
| 전환의1000식/문서 접근 한도 |8인 대표 사례 및 거절 경계 확인. 캐시를 추정해 통과 판정하지 않음|
| 표시 완화로 사칭/손상 값 노출 |변경 주체 제한·타입/길이·로컬 정제·권한 식별자와 표시 분리|
| 테스트 성공/운영 실패 차이 |같은 원본SHA/config/path·명시 프로젝트·활성SHA 확인; 운영 실패 자동 반복 금지|

## 8. 구현 단위와 확인 단위

작은 함수 하나마다 게시하지 않는다. 아래는 하나의 전체 후보 완성 작업의 내부 단계다.
각 단계 종료가 채팅 종료/사용자 재승인 요구를 뜻하지 않는다. 후속 사용자 요청으로 구현 승인을 받았다.

| 단계 | 구현 범위 | 확인 범위/판정 |
|---|---|---|
|1 책임 명세 확정|문서별 allow와 공통 조건/예외, 삭제할 wrapper/중복 호출을 하나의 표로 고정|삭제 책임 공백0·기능 목록 누락0. 제거 근거 없으면 코딩 전에 범위 정정|
|2 전체 후보 구현|A1+A2+A3의 공통 게이트·분기를 누적 전체본에 통합|생성 재현·정의/호출 일치·고아 함수 제거·줄맞춤. 기능 제외false와 전체허용 없음|
|3 핵심 회귀|코드는 추가 확대하지 않음|그룹 생성/초대/신청/코드/승계/해산, 파티 준비/인증/완료/정리의 직접 영향·위조·누락·8인 경계|
|4 테스트 게시|경고0인 기능 포함 전체 후보를 rules-test-1-81e31에1회|활성화 성공·활성SHA 일치. 실패 시 단계·응답·직전 성공 비교 후 보고, 재시도 금지|
|5 운영 전환|테스트 통과 동일 내용의 firestore.rules를 lost-party에1회|운영 활성SHA/시각, 사용자 실기기 인수·기존 흐름 보존|

단계2의 결과는 실제 삭제 서버 검사/함수/중복 본문, 로컬 이전, 전체 바이트·깊이와 함께 보고한다.
함수 수만 줄거나 몇 바이트만 줄인 것으로 전체 작업을 완료하지 않는다. 목표 감소율/바이트 임계치를 임의로 만들지 않는다.
기존 동일 소스 검증은 재사용한다. UI 정상 흐름은 사용자 실기기, 서버 위조/원자성은 자동 검증으로 분리한다.
전체 Flutter test/analyze는 실제 앱/공용 계약 변경 시 영향에 따라 판단하고 Rules-only이면 반복하지 않는다.

## 9. 운영 전환과 복구

A의 채택 전제는 저장 경로/필드/Writer 불변이다. 충족하면 데이터 이행·앱 재설치 없이 Rules 전환이 가능하다.
이는 구현 결과로 재확인해야 하며, schema/Writer 변경 발견 시 A 범위에서 몰래 확장하지 않는다.
테스트 게시 전 전용 계정·합성 fixture만 사용한다. 운영 자료를 복제하거나 테스트 진단본으로 실기기 연결하지 않는다.
운영 전환 직전에 활성 소스를 읽어 마지막7a441b1f와 달라졌는지 확인하고 변경됐으면 덮어쓰기 전에 차이를 검토한다.
배포는 Rules만 수행한다. Indexes/Functions/Hosting/요금제/운영 데이터 변경은 포함하지 않는다.

운영 실패 시 활성본을 확인하고 추가 게시하지 않는다. 성공 후 앱 회귀가 생기면 실행한 후보와 실패 요청을 먼저 확인한다.
복구용 소스는 현재 앱과 호환되는 기능 포함본으로 테스트 게시/검증한 것을 준비해야 한다.
현재7a441b1f는 기능 정상 기준이 아니고36b5920e도BUG-024 호환이 미확인이므로 자동 rollback 대상으로 지정하지 않는다.
호환 복구본이 없으면 전환 전 이 한계를 명시하고 별도 복구 결정을 받아야 한다. 임의 전체거절/기능 삭제로 대체하지 않는다.

최종 완료는 운영 기능 포함본 게시 성공·경고0·활성SHA일치와 사용자 인수다.
장래 게시 안정성은 이후 실제 수정의 정상 게시 결과로 확인하며 검증을 위한 반복 게시를 만들지 않는다.

## 10. 현재 완료·미완료 구분

완료: 대안 비교, 우선 구조안, 실제 코드 대상, 책임·부작용·전환·검증·복구 설계.
미완료: 조건별 전체 동등성 표 확정, 전체 후보 구현, 정량 절감·컴파일 실행 크기, 테스트/운영 게시, 실기기.
A의 일부 구체 중복은 코드로 확인했지만 A 전체가 충분한 크기를 줄일지는 아직 알 수 없다.
A 전체 후보도 실패하면 같은 미세 치환을 재개하지 않는다. 그 결과를 근거로 B의 저장 책임 축소 또는 제약 변경을 다시 결정한다.
위 완료·미완료 구분은 구현 착수 전 기준이다. 이후 결과는 §12를 따른다. 기존 보존 커밋e913f1a·전체3f683e9b와 미추적 자료를 유지한다.

## 11. 구현 착수 — 공통 책임 확정

사용자가 구현을 승인했다. 전체 후보 검증/테스트 게시까지 진행하며 내부 단계마다 운영 게시하지 않는다.
공통 이동은 동일 문서의 모든 해당 허용 경로가 원래 요구하던 조건의 교집합만 대상으로 한다.
그룹 member create의 Core/Optional은4경로 공통, 관계 결정의 diff/revision/시각은3경로 공통이다.
그룹 update의 revision/updatedAt은 일반·모집 증감 모두 공통이며 lastActivityAt은 일반 경로에만 적용한다.
파티 member create는2경로 모두 schema/playerId/joinedAt/updatedAt/현재 소유권/binding을 요구한다.
이동 후 단독 validator에 의존하는 다른 caller가 없는지 검사한다. 다른 문서 validator 실행을 가정한 검사 삭제는 하지 않는다.
파티 update의 우선순위와 누락 필드 동작은 보존하고 긴 분기 사슬을 그대로 중복 복제하지 않는다.

## 12. A 구현 결과 — 2026-10-11

전체 기능 후보 `5f41579134f967934b3b58759d10bc60905ff0e7186049c2594500bfe02849a5`.
줄맞춤 포함189056→185651bytes(-3405), 식별자 압축 원본146524→144329bytes(-2195).
함수 정의279→277. 최대 호출 깊이는 이번 후보에서 재측정하지 않았으므로 감소 성과로 보고하지 않는다.
앱 Writer·저장 스키마·조회·로컬 처리 변경 없음. 실제 게시 결과로 채택을 판정하며 절감량을 성공으로 대체하지 않는다.

| 구간 | 변경·삭제 근거 | 보존 경계 |
|---|---|---|
|A1 member create|4경로의 Core/Optional 반복을 진입점1회로 통합, single-use Core wrapper 삭제|created binding, invitation 본인, application 방장 대리, joinCode 본인/Character 소유권|
|A1 관계 pending|invitation/application validator2개를 공통 pending 진입점1개로 통합|actor·신청 횟수·차단·만료·projection 연결. application 재신청에서 과거 applicationAttempt 누락 허용 유지|
|A1 관계 결정|3경로의 diff/revision/시각을 진입점1회로 통합|초대/신청/코드 결정의 기존 OR 합집합 보존|
|A2 group update|10경로 revision/updatedAt 공통, 일반8경로 lastActivityAt 공통. 같은 join validator의 중복 진입 삭제|모집 증감에는 lastActivityAt 조건을 추가하지 않음. 가입/승계/해산/코드 권한 보존|
|A3 party member create|2경로의 schema/playerId/시각/현재 소유권/binding 공통|생성/승인 actor 및 원자 문서 연결 보존|
|A3 모집 update|앞 lifecycle dispatch가 소비한 뒤 성공할 수 없는 lifecycle 호출2곳 제거|atomicIsLifecycleCommand + atomicValidLifecycleShape.lastCommandAt이 앞 분기 조건을 함의. 개인 완료 최우선/마지막1인 예외 유지|
|A3 raidState update|앞 manual/older-state 분기와 같은 뒤쪽 manual 생성 검사 제거|이전 소유 차수의 manual 경로는 앞 분기에서 그대로 처리. guard·전환·완료/교체 우선순위 유지|

다른 문서의 validator 실행을 추정해 권한 검사를 삭제하지 않았다. 권한 검사 종류 자체의 폐기와 로컬 이전은0이다.
모든 파티 분기를 새 dispatch로 전면 교체한 것은 아니다. 교집합/도달 불가능성이 확인된 부분만 통합했고,
누락 필드·개인 완료·이전 소유 차수 등 서로 다른 경계는 유지했다. 효과 부족 시 같은 작은 치환 반복으로 돌아가지 않는다.

생성 파이프라인에 변환을 연결했고 독립 후보와 재생성 SHA 일치를 확인했다.
변환 초안의 잘못된 match 선택으로 파티 공통 조건이 그룹에 들어간 오류는 로컬 검증에서 발견·수정했다. 그 초안은 게시하지 않았다.
그룹 생성4방식/관계 pending·결정/누락 횟수 재신청의 기준본 대조, 위조 필드·actor·시각 거절을 확인했다.
기준본 그룹 member 위조 거절은 평가 한도 오류를 포함했고 최종 후보는 같은 요청을 한도 오류 없이 거절했다.
그룹 모집 집계, 탈퇴·승계·해산, 반복방 준비/인증·8인 전환·완료 경계도 로컬 확인했다.
문자열 이름을 검사하는 기존 Dart Rules 계약은 압축 함수명 이전 형식이므로 통과를 주장하지 않으며 실제 Emulator 권한 검증으로 확인했다.
실기기, 운영 반영, 향후 게시 안정성, 정확한 compiled 크기는 미확인이다.

근거는 `coverage/rules-production-restructure/`의 before/readable/candidate, group-create/group-count/group-leave/seal 로그와 원격 게시 로그다.

### 테스트 게시 판정

2026-10-11 00:33 KST 테스트 프로젝트에 실제1회 게시: /test200 응답{}·경고0, /rulesets200,
PATCH /releases/cloud.firestore400 INVALID_ARGUMENT, CLI fallback POST /releases409 ALREADY_EXISTS.
활성SHA e64f152d와 updateTime2026-10-10T15:11:11.866137Z 유지 확인. 운영 게시0.
그 전 CLI1회는 설정의 폴더 밖 경로 때문에 로컬에서 중단됐고 /test·rulesets·release 요청이 없었다.
`local-config-error.log`와 실제 `deploy.log`를 분리해 보존한다.

**A 공통 통합 후보로 게시 문제 해결 실패.** 전체 구조 축소 방향 자체를 반증하는 결과는 아니며,
이번 교집합 통합·중복 분기 제거만으로는 충분하지 않다는 결과다. 실패 내부 compiled 크기는 여전히 미공개다.
검증하지 않은 정상 함수 삭제/추가 치환/재게시/운영 전환을 자동 진행하지 않는다.
다음 판단은 B의 표시·파생 쓰기 계약을 실제로 축소할 범위와 앱/기존 데이터 전환 비용 검토 여부다.
이번 결과는 구현한 공통 통합 후보의 실패이며 A의 모든 분기 재구성을 완료·배제했다는 의미가 아니다.
다음 설계 판단에서 미구현 A 범위와 B의 실제 제거 대상·권한 책임·앱 영향을 비교해야 한다.

## 13. 후속 비교 및 다음 구현 설계 — 2026-10-11

사용자의 후속 진행 요청으로 실제 남은 검사를 조사했다. 이번 절은 설계이며 기능 코드/Rules/원격은 변경하지 않았다.
기준은 실패 후보5f415791이다. **다음 권고 범위는 B1 그룹 표시 검증 로컬 이전 + A2 잔여 그룹 수정 분기 통합**이다.
작은 조건 하나를 바꿀 때마다 게시하지 않고 이 범위의 기능 포함 전체 후보를 만든다.
큰 폭의 순감소나 게시 성공은 아직 입증되지 않았다. 아래 삭제 후보 수를 실측 성과로 보고하지 않는다.

### 13.1 비교 결과

| 후보 | 실제 제거 가능한 책임/구조 | 비용과 판단 |
|---|---|---|
|A2 그룹 수정 분기|가입 증가의 공통 diff/count 한도와 actor별 차이를 합치고 JoinCommand→Activity/MemberJoin 호출 사슬 제거|스키마/앱 쓰기 불변. B1과 함께 구현할 후보|
|A3 모집/member/raidState 전면 dispatch|현재 validator가 여러 allow 분기에 반복 등장. 호출 위치가 줄 수 있으나 validator 본문 폐기 근거는 아직 부족|개인 완료 우선·guard·이전 소유 차수 겹침의 동등성 표가 미완료. B1 구현에 섞지 않음|
|B1 기존 그룹 필드의 표시 검증 폐기|순수 표시 타입/길이/원본 동일성 검사와 OptionalNumberFields helper를 실제 제거, 로컬 해석으로 대체|스키마·쿼리·Writer 필드 유지. 신규 구현 우선|
|B2 표시 payload map 신설|여러 top-level 키를 한 map으로 묶을 수 있음|기존 필드와 새 map 동시 지원은 검사 증가 위험. B1은 map 없이 가능하므로 지금 신설하지 않음|
|B3 groupRelations/raidListings 삭제|해당 문서 validator 전체 제거 가능성이 있음|내 그룹/초대 탐색·그룹 전용 목록 읽기 경로를 바꿔야 함. 읽기 증가와 누락/공개 범위 영향이 크므로 이번 제외|

이미 구현된 표시 원본 대조 제거·로컬 정렬/정제는 신규 성과에서 제외한다.
`r1ListingCopy`는 현재 원본 전체 동등성1회와 키 제한이다. 이를 없애고 필드별 비교를 재도입하는 것은 채택하지 않는다.
`groupRelations`는 단순 표시 캐시가 아니라 `watchMyGroups`/`watchMyRequests`의 탐색 시작점이다.
전체 다운로드 후 로컬 필터로 바꾸거나 관계·목록 읽기 권한을 열어 삭제를 대신하지 않는다.

### 13.2 B1 필드·함수 책임표

동일 경로/필드명을 유지한다. 정상 앱은 기존 Snapshot을 계속 저장하고 다른 기기도 같은 값을 읽는다.
로컬 전용 저장으로 바꾸는 것이 아니라 **값의 표시 적합성 판단을 서버에서 앱으로 이동**한다.

| 문서/함수 | 서버에서 없앨 표시 검사 | 유지할 서버 경계/앱 변경 |
|---|---|---|
|group member / validGroupMemberOptionalNumberFields|표시 class의 string/nonempty, 선택 itemLevel/combatPower의 number/null, gem의 map/null. helper 정의와 create/selfRefresh 호출을 함께 제거|허용 키·Player/Group/Character ID·role·joinedBy·revision·시각·actor·가입 원자성 유지. toMember의 표시 숫자/직업을 tolerant parser로 변경|
|group member 생성4경로|표시 캐릭터명의 타입과 group/relation/Character 이름 일치 비교|displayCharacterIdSnapshot과 소유권/관계 Character ID 일치는 유지. 이름은 기본 문구로 표시 가능하게 변경|
|groups / validInitialGroup·validGroupLeaderTransferUpdate|대표 캐릭터/서버/방장 표시명 형식과 표시명 간 동일성 비교|그룹 name 및 검색용 정규화 필드 계약, 대표 Character ID/소유권, leaderPlayerId/인원/승계 원자성 유지|
|joinRelations / validGroupPendingJoinRelation|characterNameSnapshot/serverNameSnapshot/characterClassNameSnapshot 문자열 검사|characterIdSnapshot·대상/requester·kind/status·만료·신청 횟수·revision·차단·member 연결 유지. toJoinRelation 표시 parser 변경|
|groupRelations / validGroupRelationProjectionKeys|groupNameSnapshot/displayCharacterNameSnapshot 타입·길이|소유 Player·그룹 존재·relation/requestStatus·expiresAt/sourceRevision·쓰기 actor·키 제한 유지. 기존 _displayText 재사용|
|applicantStats / validGroupApplicantStatsWrite|lastCharacterNameSnapshot 타입/길이·표시 숫자 타입|null 처리 기존 _displayNumber 재사용. applicationCount 증가와 신청 결합 유지|
|blockedPlayers / validGroupBlockCreate|characterNameSnapshot 타입/길이·표시 숫자 타입|차단 actor/대상/reason/applicationCountSnapshot 및 관계 상태 유지. 차단 효력은 표시와 무관|

이름에 Snapshot이 붙어 있어도 모두 표시 전용은 아니다. **파티 classNameSnapshot은 제외**한다.
현재 Rules에서 member.classNameSnapshot으로 slot.classKey를 구성하며 앱 자리 정책에도 연결된다.
파티 role/classKey/정원, Character 소유권, joinSequence, 모든 count/status/ID/revision/시간은 B1 대상이 아니다.
표시 형식이 잘못된 자료를 허용해도 역할/상태/차단/가입 자격이 달라져서는 안 된다.
보존 대상 validator 전체를 삭제하지 않는다. 위 표에서 전체 삭제할 수 있는 함수는 OptionalNumberFields이며 나머지는 표시 조건만 제거한다.

### 13.3 실제 앱 연결과 부작용

기준 파일(저장소 상대 경로):

- `lib/app/router/app_router.dart`: 기존 FirestoreGroupRead/Create/Join/Application/JoinCode Repository DI 유지.
- `lib/features/group/data/mappers/group_document_mapper.dart`: toPublicSummary/toMember/toJoinRelation의 표시 전용 필드만 `_displayText`/`_displayNumber`/`_softGemValidation` 계열로 전환. 공용 `_string`을 느슨하게 바꾸지 않음.
- `lib/features/group/domain/services/group_member_display_builder.dart`: Character fallback의 `_parseNumeric`도 비유한/음수 차단, 직업 fallback도 같은 표시 정제 적용. Mapper만 수정하면 fallback에서 잘못된 값이 다시 나타남.
- `lib/features/group/data/mappers/group_member_write_fields.dart`, `group_member_snapshot_write_plan.dart`: 기존 null일 때 저장값 보존과 보석 요약 쓰기 유지. 표시 필드 삭제/새 스키마/새 document 추가 없음.
- `lib/features/group/data/mappers/group_application_write_plan.dart`: 승인·차단 Snapshot 복사 유지. 캐릭터 ID와 신청 횟수는 parser 완화 대상 아님.
- `lib/features/group/data/repositories/firestore_group_join_command_repository.dart`: 방장 승계 표시명은 incoming member에서 가져옴. fallback 문구가 쓰여도 leader ID/승계 판단은 그대로 유지.
- `lib/features/group/data/repositories/firestore_group_read_repository.dart`: 현재 조회·페이지·구독·Character 보강 유지. 추가 get/listener 없음.

표시 정책: 이름 누락/비문자열/공백은 기존 기본 문구, 직업은 기존 '-' 또는 유효 Character fallback,
숫자 오류/음수/비유한은 null, 잘못된 보석 요약은 null. 정상 값과 과거 null의 의미는 유지한다.
표시용 문자열만 제어문자 제거/trim/256코드포인트 제한을 재사용한다. ID·상태·검색키에는 적용하지 않는다.

**행동 변화:** 권한 있는 쓰기 주체가 이름/레벨 등 잘못된 표시값을 저장해도 해당 형식만을 이유로 서버가 거절하지 않는다.
앱은 이를 안전한 표시로 바꾸지만 실제 게임 정보의 진실성을 보증하지 않는다. 다른 사용자의 문서 쓰기는 계속 거절한다.
문서 크기·전송량이 로컬 정제로 줄어드는 것은 아니다. 표시 필드를 무제한 payload map으로 확장하지 않고 기존 최상위 키 제한을 유지한다.
반드시 파서가 보완된 앱을 먼저 사용한 다음 Rules를 바꾼다. 사용자의 모든 기기 최신 코드 사용 답변은 과거 시점이므로 전환 시 새 파서 포함 여부를 확인한다.
기존 문서 일괄 이행은 불필요하고 구형 정상 Writer도 같은 필드로 쓸 수 있다. 구형 Reader가 비정상 표시값에서 실패하는 위험은 남는다.

### 13.4 A2 잔여 분기 설계

현재 `validGroupJoinCommandUpdate`는 Activity 또는 MemberJoin을 호출하고, 별도로 LeaderApprove가 인원 증가를 검사한다.
다음 명령 구분은 새 저장 marker 없이 기존 before/after 필드로 한다.

1. activeRecruitmentCount 변경: 기존 close/open 전용 경계 유지. lastActivityAt 일반 게이트를 적용하지 않음.
2. memberCount +1: 공통 허용 키·50명 상한·active 조건을 한 번 검사. 방장 대리 승인과 본인 가입의 actor/관계 조건은 OR 합집합으로 유지.
3. memberCount -1: 마지막 해산과 일반 탈퇴의 상태 차이를 보존.
4. leaderPlayerId 변경: 승계2member와 후속 탈퇴 계약 유지.
5. 코드 플래그/가시성 변경: 현재 허용 키/코드 문서 연결 유지.
6. revision/lastActivityAt/updatedAt만 변경: 기존 Activity 허용 actor를 유지. 필드 변화가 없는 요청도 현재 허용 집합과 비교.

특히 기존 LeaderApprove가 직접 요구하지 않는 새 대상 member 검사 등을 최적화 명목으로 덧붙이지 않는다.
반대로 본인 가입에 필요한 member/관계 검사를 방장 분기와 합치면서 잃지 않는다.
삭제 후보는 Activity/MemberJoin/JoinCommand/LeaderApprove의 중복 본문과 wrapper이며,
실제 완전 삭제 함수 수는 새 공통 진입점의 크기까지 포함해 구현 후 보고한다.

### 13.5 구현 범위와 확인 범위

| 내부 단계 | 구현 범위 | 확인 범위 |
|---|---|---|
|1 로컬 표시 해석|그룹 Mapper와 DisplayBuilder 보완, 기존 Writer/DI 유지|정상/누락/틀린 타입/제어문자/음수·비유한/잘못된 gem/Character fallback. 보안 ID·role·상태는 계속 오류|
|2 서버 책임 축소|B1 표의 표시 검사 및 전용 helper 제거, A2 그룹 수정 통합, 생성 도구 동기화|허용 키·타인 쓰기·역할/상태/인원/차단/부분 쓰기 거절. 가입4방식·방장 이전/해산의 기존 경계 보존|
|3 전체 후보 확인|누적 전체본의 순감소·삭제 정의/호출·깊이·경고 확인|기존 확인을 재사용하고 실제 변경 경계만 검증. 새 표시정제 계약과 보안 결과를 분리|
|4 게시 판정|검증된 전체본을 테스트 프로젝트에1회|활성화와SHA 확인. 실패 시 재시도 없이 기록. 운영은 기존§9 전환 조건 적용|

각 내부 단계에서 채팅을 끊거나 별도 게시하지 않는다. 결과는 삭제한 검사/helper, 로컬 이전, 전체 순감소와 실제 게시로 보고한다.
이번 설계만으로 순감소 바이트·내부 compiled 크기·게시 성공을 확정하지 않는다.
B1+A2가 충분하다는 근거 없이 이후 A3를 계속 자동 확장하는 것도 금지한다. 다음 비교 대상과 미확인 범위를 보고한다.

## 14. B1+A2 구현 결과 — 2026-10-11

사용자 구현 승인 후 전체 후보 `f7ce11cf23b740f301efb0f5ceb837fa85ac625efeaee66172613d5af8dc2e55`를 생성했다.
직전185651→181935bytes(-3716), compact144329→141491bytes(-2838), 함수277→272, 최대 호출 깊이5 유지.
최초 보존e913f1a의189056bytes 대비 누적7121bytes 감소다. compiled 크기나 게시 성공 임계치를 뜻하지 않는다.

- 서버에서 제거: §13.2의 그룹 표시 형식/동일성 검사, `validGroupMemberOptionalNumberFields` 정의·2호출,
  표시 갱신의 과거 필수키에서 표시명1개. 보안 필드 필수키는 유지한다.
- 구조에서 제거: `validGroupActivityUpdate`, `validGroupMemberJoinUpdate`, `validGroupLeaderApproveUpdate`를 기존 JoinCommand에 합쳤다.
  모집 증감 wrapper2개는 `validGroupRecruitmentCountUpdate`1개로 통합했다. close/open body OR는 보존했다.
- 로컬 이전: GroupDocumentMapper의 공개/멤버/관계 표시 해석을 tolerant하게 변경하고 GroupDisplayValue로 정제 공통화.
  GroupMemberDisplayBuilder의 Character 대체값도 같은 음수·비유한/문자 정제를 거친다.
- 앱 Writer/저장 스키마/조회·DI/파티 classKey·role 불변. 기존 별도 raid_cycle_schedule 변경은 이번 작업 대상이 아니다.

인원수가 누락된 과거 그룹의 활동 갱신이 새 공통 분기에서 거절되지 않도록 count 필드 변경 여부를 먼저 판정한다.
표시명 누락 신규 member의 본인 표시 갱신도 가능하며 타인/역할 변경은 거절한다.
기준본의 보안 결과와 새 표시 허용 계약은 분리했다. 잘못된 표시 숫자·이름·직업·보석 형식은 후보에서 허용하되,
위조 player/Character ID·추가 키·시각·actor는 거절한다. 표시값의 진실성 보장은 하지 않는다.

로컬 검증: 변경 Mapper/DisplayBuilder/기존 Writer 표적 테스트, 변경 앱 파일 정적 분석,
그룹 생성·관계·재신청/가입·활동 분기 대조, 최대50명·누락 필드·권한/추가키/시각·표시갱신,
그룹 모집 집계22사례와 기존 탈퇴/승계/해산 경계. 생성 재현·preflight·diff 확인.
기존 테스트의 표시 숫자 예외 기대1곳은 null 계약으로 갱신했고 Mapper 재실행 통과했다.
실기기 정상 흐름은 미확인. 테스트 프로젝트용이므로 현재 사용 기기에 새 파서가 설치됐다고 가정하지 않는다.
근거: `coverage/rules-group-display/`의 before/candidate/readable·검증 로그·preflight 및 게시 기록.

### 실제 게시 결과

2026-10-11 13:57 KST `rules-test-1-81e31`에1회 게시 성공.
원격 /test200 응답{}·경고0, /rulesets200, PATCH /releases/cloud.firestore200.
활성 ruleset `911a10f2-b9b1-4908-a707-a917f692d95c`, updateTime `2026-10-11T04:57:41.847278Z`.
13:58 KST 활성 소스를 다시 읽어 전체SHA f7ce11cf…와181935bytes 일치를 확인했다.
기능 제외/미정의 함수 진단본이 아닌 전체 후보 성공이다. 성공 임계 크기나 내부 컴파일 원인은 확정하지 않는다.
한 번의 게시 성공은 향후 모든 수정의 안정성을 보장하지 않는다. 추가 안정성 실험을 위한 반복 게시도 하지 않는다.

운영은 이번에 변경하지 않았다. 다음은 새 파서 포함 앱 사용 확인, 운영 활성 소스 읽기/차이 검토,
§9의 복구 방안 결정 후 동일SHA 운영1회 게시다. 기존 불완전 운영본/과거 비호환 가능본을 자동 복구본으로 지정하지 않는다.
최신 그룹 contract는 로컬 구현 기준이며 운영 기능 인수 전에는 운영 정상화 완료로 보고하지 않는다.

### 운영 전환 결과 — 2026-10-11 14:17 KST

사용자가 성공본 커밋 후 운영 게시를 명시 지시하여 bca158d로 보존하고 lost-party에1회 게시했다.
사전 활성7a441b1f가 마지막 확인과 동일함을 확인·보존했다. /test200 응답{}, 경고0, /rulesets200, PATCH /releases200.
활성 ruleset2419f77b-9535-479a-a519-3ddd8f7a6005, updateTime2026-10-11T05:17:14.085611Z.
재조회 SHA256 f7ce11cf23b740f301efb0f5ceb837fa85ac625efeaee66172613d5af8dc2e55/181935bytes로 로컬·테스트 성공본과 일치.
운영 게시 성공은 확인됐고 실기기 기능 인수/새 파서 설치는 미확인이다. 과거본 자동 rollback은 수행하지 않았다.
근거 coverage/rules-group-display-production/의 deploy.log, active-before/after.json·rules. push/merge/dev 반영 없음.
