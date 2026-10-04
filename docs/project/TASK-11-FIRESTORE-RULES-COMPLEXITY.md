# Firestore Rules 복잡도 — 전면 조사와 기능 보존 설계

2026-10-05 최신: 정리 Aggregate 동일 집계 조건3곳 공통화, 실제 firestore.rules는
cd04e69e/223114bytes. CI37211831330 제한 통과·1000식0건, 기존 권한 조건 유지.
직전9654be80 수동 게시 실패는 사용자 보고. 새 수정본 게시 여부는 미확인이며 운영 요청 없음.
[검증 상세](DEV_LOG.md), [현재 작업](NEXT_WORK.md). 아래는 이전 이력이다.


2026-10-04 최신: 사용자 요청으로 수정본9654be80을 firestore.rules에 직접 반영.
소유권2문서 재조회 제거, CI37207958373 제한 통과·1000식0건. 게시 개선은 미확인.
운영 재게시 명령은 자동 승인에서 실행 전 차단되어 원격 요청0회. 수동 테스트 게시 준비 완료.
[상세](DEV_LOG.md), [현재 상태](NEXT_WORK.md). 아래는 이전 기록이다.


2026-10-04 17:21 KST 최종: 검증본3b0f492b 게시1회에서 컴파일/업로드 성공·경고0,
Release 활성화503 실패. 저장 소스는 일치하나 운영은e8baa2e4 유지. 재게시 없음.
수정·제한 검증 완료와 운영 미적용을 구분한다. [게시 진단](ROSTER_RULES_PUBLISH_DIAGNOSIS.md),
[다음 작업](NEXT_WORK.md). 아래 게시 대기 문구는 이전 기록이다.


2026-10-04 최신: CI37188270787 제한 검증 통과·원시1000식 오류0건. 검증본을
firestore.rules SHA3b0f492b로 승격했다. 게시1회/활성 소스 확인 대기이며 실기기 미확인.
[최종 근거](DEV_LOG.md), [현재 작업](NEXT_WORK.md). 아래 미채택 기록은 과거 이력이다.


2026-10-04 최신: 일반 추방/정리·승계·그룹 보호의 제한 CI는 통과했으나
일반 정리 음성5건 평가 한도가 남아 후보 미승격이다. 기존 조건의 평가 순서를 보완 중이며
운영 게시 승인1회는 유지·아직0회. [현재 계획](NEXT_WORK.md), [검증 이력](DEV_LOG.md).
아래 최신이라는 표현은 해당 시점의 과거 기록이다.


## 2026-10-04 대상 검색 후보 미채택

CI37178943702/e2aa019의66e10e0c 후보도 목록 인원 위조 시 raidStates delete1000식 실패.
표식 미소비만 한도 없이 거절되며 정상 묶음은 미실행. 실제 원본6a4 유지.
연속된 순서/검색 축소 접근이 같은 경계를 해결하지 못해 미세 패치를 중단한다.
다음은 실패하는 원자 쓰기에서 getAfter 미확정 평가와 실제 입력 오류/정책 거절을 분리하는
진단 설계다. 원인 확정 전 helper 추가 축소·권한 완화·평가 한도 조건 면제를 하지 않는다.
사용자 승인 운영 게시1회는 검증 대기이며 아직0회 수행. [상세](DEV_LOG.md).

## 2026-10-04 후속 후보 판정

b9318c1b/ec83225의 lifecycle 시각 사전 검사 및 목록 비교 순서 변경을 두 음성 사례에 검증했다.
CI37176869587: 표식 미소비는 한도 없이 거절, 목록 인원 위조는 raidStates delete1000식 잔존.
채택 조건을 완화하지 않아 후보 미반영. 정상 묶음 반복도 중단했다. 실제 원본6a4a4b52 유지.
다음은 삭제 검사의 명령 target/raidState target 검사와 fallback 비용을 기존 coverage로 분리한다.
평가 중 undefined를 문서 부재로 단정하지 않는다. legacy 추가 필드 보존 근거 없이8개 인덱스
검사를 exact-map membership으로 대체하지 않는다. [상세](DEV_LOG.md), [작업 범위](NEXT_WORK.md).

## 2026-10-04 최신 판정 — 정상 경계 복구 후보, 거절 한도는 미해결

세 번째 후보6aa8ee83/223866bytes는 CI37169644684에서 정상 추방·자리·최대8 목록,
구버전 요청·승계·중복 요청·개인완료15·peer51·마지막1인10을 통과했다.
하지만 원시 emulator 로그에 음성 요청의1000식 실패가 남아 **F의 채택 조건은 미충족**이다.
CI37170239708에서 표식 미소비/목록 인원 위조 각1건은 기준6a4/후보6aa8 모두
거절+한도 초과로 확인했다. 두 사례는 기존 문제이며 신규 회귀로 단정하지 않는다.
coverage의 표식검사2250/2283행, 목록인원일치2705행은 양쪽 모두 false를 반환했다.
따라서 검사가 사라진 것은 아니지만 모든 경로의 권한 논리·비용 검증 완료는 아니다.
실제 firestore.rules는6a4a4b52 그대로, 후보 미반영. 전체 재검증/원격 게시 없음.
세 후보 경과와 검증 범위는 [DEV_LOG 최신 기록](DEV_LOG.md), 남은 작업은 [NEXT_WORK](NEXT_WORK.md).
이하 현재/다음/정적1건이라는 표현은 각 기록 당시 상태다.

## 2026-10-04 추방 한도 — 평가 경로 계측과 단일 후보

첫 무조건 순서변경 후보 CI37169303283은 추방 전 정상자리변경에서1000식 회귀로 미채택했다.
후속 후보4410275는 validAtomicRecruitmentMemberRemoval의 기존 필수조건인
new.memberCount==old.memberCount-1을 선행guard로 둬 unrelated 자리변경에서 제거검사를 생략한다.
검증본문은 유지하며 해당함의가 없어지면 생성거절하는 정적검사를 추가했다. 최초후보를
성공한 수정으로 기록하지 않는다. 두 후보 모두 원격게시하지 않았다.


CI37169075268에서 기존 실패1건 직전/직후 ruleCoverage를 확보했다.
운영 앱 PartyAtomicMemberRemovalWritePlan과 테스트의 모집patch/member삭제/state삭제/event생성,
그룹listing/후임membership 조건부쓰기 및 lifecycle marker 소비값을 대조했다.
memberCount/구성/targets/revision/event audience·actor가 같은 의미이며 앱 코드는 변경하지 않았다.

coverage에서는 validAtomicRecruitmentJoin, validAtomicPendingApplicationUpdate,
validAtomicCharacterRevisionUpdate, validAtomicPositionAggregateUpdate 등 선행 검사 실행이 보이고,
validAtomicRecruitmentMemberRemoval은 atomicAggregateSizesMatch 호출(기준2678행)까지 진행 후
완료되지 않았다. 이는 원래 허용될 일반 제거 검사 앞의 누적 비용이 있다는 근거다.
coverage 노드 수를 정확한1000식 예산 또는 각문서별 실행비용으로 환산하지 않는다.

후보 prioritizeMemberRemoval은 모집update의 일반 OR 내 removal항만 맨앞으로 이동한다.
개인완료/마지막1인완료해산/peer정리 전용분기와 전역세대검사, 모든helper본문, 다른allow는 보존한다.
정적검사1건(변경allow1개/함수본문동일/토큰multiset동일/전용peer분기위치유지) 통과.
배포원본6a4a4b52는 그대로이며 후보는 별도coverage 경로에만 생성한다.
검증결과와 채택여부는 후속 기록을 따른다. 게시/데이터수정/dev·main병합 없음.


## 2026-10-04 전면 조사 결과 — 현행 기준선에는 미해결 기능 실패가 있다

이번에는 앱·Rules를 수정하지 않고 조사 도구/검증 입력 선택/문서만 변경했다.
사용자 승인: Spark 직접 저장 우선, Rules 서버 경계 기준선1회, Flutter 전체 회귀 제외.
**현재본을 전체 기능 정상본으로 간주하지 않는다.** 아래 실패를 분리한 뒤 간소화한다.

### A. 비교 기준 고정

| 기준 | SHA256 앞8자리 | 정규화 bytes | 의미 |
|---|---|---:|---|
| 운영/dev 68f0508 | e8baa2e4 |185937|최근 사전/사후 조회한 운영 활성본|
| 재인증 통합 초기본 |11ef3dde|227459|integratedBaseline() 재현; 간소화 전 비교|
| 사용자 백업/4453f53 |f43ea68c|224418|백업 CRLF를 LF로 바꾸면 정확히 동일|
| 캐릭터 변경 평가 순서 수정/48bb6f3 |39a7b731|224266|빈자리 변경 한도 수정과 자리 중복 제거|
| 현재/6742123 |6a4a4b52|223746|개인 완료 중복 fallback3곳 제거|

사용자 백업 raw229393bytes/SHAa2501818…는 보존했다. 파일 이름이나 과거 완료 보고 대신
위 소스와 증거를 사용한다. 소스 축소153208bytes의 /test503 실패는 별도 게시 실험이다.
정리 한도 개선(hasAll), 중복 helper 공통화, 이벤트 분기, 캐릭터 평가 순서, 개인 완료 중복 제거는
각각 생성 도구의 독립 변환으로 재현된다. 모두 한 종류의 '버그 수정'으로 합쳐 판정하지 않는다.

### B. 전수 정적 조사

[전체 경로·함수 목록](RULES_AUDIT_INVENTORY.md)은 현재 해시의 **34 match(루트 포함),
118 allow, 274 함수**를 포함한다. 모든 allow에서 호출 그래프를 따라갔으며 미도달 함수0,
공백 정규화 후 완전히 동일한 함수 본문0, 재귀0, 최대 helper 깊이6이다.
인자 이름이 다른 의미상 중복이나 논리적으로 불가능한 분기는 별도 검토 대상이다.

| 우선 조사 경로 | 도달 가능한 고유 helper 수 | 주요 부담/판정 |
|---|---:|---|
| 모집 update |62|개인 완료·소유권 정리·수명주기·신청·가입·변경·탈퇴가 연결된 OR/삼항 체인|
| 참가 member update |34|자리·캐릭터·승계·구 assignment 경로 동시 유지|
| raidState update |33|개인 완료·구세대 교체·주차 수명주기와 남은 중복 개인 완료 호출|
| 그룹 raidListing update |29|모집의 파생 상태·방장·구성·revision 동기화|
| 그룹 update / 신청 update |각27|그룹 관계 원자성 / 재신청·승인·완료 처리|
| partyEvent create |23|대상·명령 revision·원본 상태/완료 snapshot 상호 검증|

이 숫자는 실행 횟수·Firestore 문서 접근 수·컴파일 AST 크기가 아니다. 동일 get 경로의 캐시,
짧은 회로 평가, 분기별 실행을 고려해야 한다. 소스 줄 수 목표나 임의 축소율을 완료 기준으로 삼지 않는다.

### C. 기능별 경계와 로컬 이전 판정

| 영역/문서 | 실제 연결/상태 | Rules에 남길 것 / 간소화 방향 |
|---|---|---|
| authBindings, players, operatorAssignments |Player 인증 바인딩·활동, Router 운영자 저장소|본인 식별/운영자 권한/변경 필드 보호 유지. 표시·최종접속 UX만 로컬|
| gameAccounts, characters, identityClaims, playerGameAccounts |로컬 장비 인증 Gateway→원격 데이터 동기화|세대·owner 일치 유지. 장비 판정은 이미 로컬이며 추가 절감원이 아님|
| accountVerificationChallenges, activeAccountVerificationChallenges |현재 클라이언트 쓰기 거절, 향후 서버 계약|거절 경로 유지. 사용하지 않는 실제 함수는 발견되지 않음|
| manualVerificationRequests, manualVerificationBlocks |FirestoreManualVerificationRepository/운영자|승인·분쟁·요청자/운영자 권한 유지; 만료 취소의 계약 불일치 별도 해결|
| recruitments, members, applications/votes |Router atomic 저장소→전용 create/join/application/member mutation/removal→Write Plan|점유·직업/역할·승인·참가 세대·revision·원자성은 로컬 단독 이전 불가|
| recruitments/slots |구 원장 읽기만, 쓰기 false|현재 기능 삭제 수단으로 활용하지 않음|
| recruitments/cycles, raidStates, weeklyRaidClaims, activeRaidAssignments |Cycle adapter/weekly status command 저장소, 현재·구세대 공존|완료/재승계/점유와 과거 기록 보호 유지. legacy 제거는 데이터/앱 호환 증거 없으므로 보류|
| partyEvents, players/events |공용 원자 이벤트/구 이벤트 읽기·일부 생성|audience·actor·revision·발생 조건 유지. 이벤트 문자열/표시는 로컬|
| groups, members, groupMembershipState, groupRelations |그룹 create/join/application/joinCode 저장소|책임자/정원/역방향 관계·count·탈퇴/해산 동기화 유지|
| group raidListings |모집 명령이 같은 transaction에서 갱신|화면용이어도 모집 가시성과 접근에 영향. 로컬만 갱신하거나 원자 검사 삭제 불가|
| joinRelations, applicantStats, blockedPlayers, groupJoinCodes |그룹 가입/코드·차단 경계|권한·중복가입·통계/관계 일치 유지. 입력 안내만 로컬|
| characterActivity |활동 캐릭터 저장소|본인 쓰기/소유권/형식 유지, 그룹 필터·정렬·표시는 이미 앱 수행|
| collection-group applications |본인 신청 조회|쿼리/본인 조건 유지. 로컬 필터로 권한 대체 금지|

앱 연결 근거: app_router.dart의 FirestorePartyAtomicCommandRepository, cycle adapter,
FirestoreWeeklyRaidStatusCommandRepository, 그룹/수동 인증 저장소. 캐릭터 변경은
firestore_party_atomic_member_mutation_repository의 모집/member/character/이전state 읽기 후
공용 배치 판정→Write Plan→모집/member/state/event 원자 쓰기다. 개인 완료도 같은 원자 경계를 유지한다.

**현재 확인된 안전한 대규모 로컬 이전 후보는 없다.** 보석·전투력 상세 판정/표시·정렬·장비 인증은
이미 앱에서 수행한다. Snapshot의 타입/변경 가능 필드/권한 검사까지 없애면 변조로 공유 데이터가
깨질 수 있다. 로컬에서 검사한다는 사실만으로 Rules 중복으로 분류하지 않는다.

추가로 현재 원정대 인증은 신뢰 서버의 장비 증명을 Rules가 검증하는 구조가 아니다.
gameAccounts 쓰기는 signedIn+세대 일관성을 검사하며 장비 인증 성공 자체를 증명하지 않는다.
이는 기존 Spark 계약의 신뢰 한계이고 이번 간소화로 새로 발생한 결함은 아니다. 세대 테스트 통과를
악의적 소유권 탈취 방어 완료로 확대하지 않는다. 이를 강화하려면 별도 신뢰 서버 설계가 필요하다.

### D. 기준선1회 검증과 실패 분류

[CI37135392373](https://github.com/heo0328/LostParty_flutter/actions/runs/37135392373):
현재6a4a4b52 고정, 독립12 suite를 끝까지 수집했다. 일부 suite 실패 후에도 다음 suite 실행.
**10 suite 정상 종료/2 실패. 전체 성공 판정 아님.** 전체 Flutter 회귀는 실행하지 않았다.

| suite | 결과 |
|---|---|
| 일반 파티/그룹 cutover |PASS 로그25건 후 추방 한도 실패, 후속 구간 미도달|
| 그룹 이전·탈퇴·해산 |20건 통과|
| 활동 캐릭터 |suite 정상 종료/완료 메시지; PASS 형식이 아니므로 건수 합산 제외|
| 운영자 수동 인증 |정상 취소·분쟁 열기 후 만료 취소의 거절 기대 실패|
| 소유권 세대 |15건 통과 (A→B→A/동시성/위조/원자성)|
| 참가/점유 |11건/22건 통과|
| 수동 완료/참가 중 개인 완료 |22건/15건 통과|
| 이전 소유자 peer 정리·승계 |51건 통과 (최대8 연쇄 정리→승계→주차 전환 포함)|
| 마지막1인/고아 정리 |10건/15건 통과|

**거절 테스트 해석 한계:** 정상 종료한 group_leave/manual_completion/occupancy/orphan_cleanup
로그에도1000식 한도 메시지가 각각1/20/1/10회 나타난다(로그 문구 수이며 요청 수 아님).
기존 assertFails는 논리적권한거절과 한도초과거절을 구별하지 않는다. 따라서 suite 통과를
모든 거절 경로의 비용 여유/권한논리 검증 완료로 확대하지 않는다. 전수 재실행은 하지 않고
각 후보 영향 경계에서 의도한 거절조건·평가coverage를 확인하도록 완료 조건에 추가한다.
이는 기존 검증의 관측 한계이며 새Rules 회귀로 단정하지 않는다.

PASS 로그 합206은 서로 다른 suite의 로그 수이지 모든 제품 조합206개의 완전 검증을 뜻하지 않는다.
일반 cutover가 중단된 뒤의 전체 완료/반복방/각종 거절 조합은 다른 suite와 겹치는 부분만 확인됐으며
미도달 구간 전체를 통과로 표시하지 않는다. 특히 자동 장비 인증 성공 증명·수동 인증 전체 승인/분쟁
및 모든118 allow의 정상/거절 조합을 자동으로 망라한 것은 아니다. 정적 목록 완전성과 실행 커버리지를 구분한다.

1. **기능 실패: 주차 표식 이후 일반 추방.** 원래 통과해야 하는 요청이 1000식 한도에 도달한다.
   부분 저장을 허용하거나 기대를 assertFails로 바꾸지 않았다.
   [원인 비교CI37135757931](https://github.com/heo0328/LostParty_flutter/actions/runs/37135757931):
   같은 fixture·명령에서 운영e8baa2e 성공, 통합11ef3dde/백업f43ea68c/현재6a4a4b52 모두 실패.
   최근 간소화 이전 통합본부터 존재하는 미해결 실패로 분류한다. 통합 내 정확한 최초 커밋과
   최다 비용 함수까지 확정한 것은 아니다. 실패 행은 모집update/raidState delete 등으로,
   도달 한도 위치를 원인 함수로 단정하지 않는다. 기존 A2-B 사용자 통과를 취소하거나 모든 추방 실패로 확대하지 않는다.
2. **기준 불일치: 운영자의 만료 pendingProof 취소.** 테스트는 거절을 기대하지만 실제 허용된다.
   운영/dev와 현재의 해당match 및 도달 helper19개가 완전히 같다. 최근 재인증/간소화 회귀가 아니다.
   만료 후 승인과 만료 후 취소를 구분한 명시 계약이 충분하지 않으므로 테스트/Rules 중 하나를 임의 교정하지 않는다.
   별도 제품 정책 확정이 필요하며 현재는 테스트 기대·기존 동작 불일치로 기록한다.

검증 준비 변경: 후보 생성 대신 고정 원본 옵션, 기존 full fixture에 누락된 gameAccount 권한 문서,
manual test의 SDK context.firestore() 사용, demo project 선택만 보완했다. 기대값 변경 없음.
신규 workflow는 기본 브랜치 미등록404로 실행되지 않아 기존 workflow 범위를 확장했다.
최초 좁은 진단 실행37135700673은 얕은 checkout의 과거객체 의존 제거를 위해 취소,
해시 확인한 기존 fixture/생성 체인으로37135757931을 실행했다. 전체 기준선 재실행 없음.

### E. 간소화 후보의 우선순위와 채택 조건

| 순서 | 후보 | 근거/기대 효과 | 위험·검증/채택 조건 |
|---|---|---|---|
|0|현재 추방 실패의 비용 분리와 최소 복구 설계|기능 정상 기준 없이는 간소화 회귀 판별 불가|아래 단일 구간을 먼저 수행. 기능 복구와 일반 리팩터링 diff 분리|
|1|명령별 불필요한 OR 평가 축소|모집62/member34/state33 helper 연결; 일반 명령 앞에 다른 명령 검사 존재|현재 요청의 형태·revision·시각으로 구분되는 경우만. 과거 lastCommandType 단독 분기 금지|
|2|raidState 개인 완료 중복 fallback|validator의 affectedKeys가 ownershipRevision 변경을 금지하며 active→completed/manual을 강제|앞쪽 분기 함의와 누락/null/잘못된타입을 포함한 동등성 증명 후 별도후보; 추방 복구와 섞지 않음|
|3|동일 경로 읽기·세대 검사 인자 재사용|deManualCurrentOwnership에서 character/account를 읽고 deCurrentOwnership가 같은 경로 재조회|캐시 때문에 접근 수 절감은 미확정. 함수 깊이·짧은 회로·누락문서 거절 보존, 실제 평가 비교|
|4|legacy/신규 경로 분리|member update에 atomic/구 assignment 캐릭터 변경 공존|구버전과 실제 legacy 데이터 조사 전 삭제 금지. 명시 schema로 안전하게 분리될 때만|
|5|파생 상태/명령 envelope 구조 조정|모집/listing/event 상호 검증이 큰 코드 비중|앱·스키마·구버전 영향 크므로 이번 동등 간소화 제외, 필요 근거만 후속 제안|

snapshot 타입검사 삭제, 소유권/점유/원자성 로컬 이전, 전체멤버 검사의 한 문서 집중,
함수명/공백 축소 반복은 채택하지 않는다. 파일 분리는 유지보수 효과이며 같은 ruleset의
컴파일 한도를 자동 해결하지 않는다. 정적 공통화가 컴파일 크기를 줄였다고 주장하지 않는다.

### F. 다음 단일 구현 준비 구간 — 추방 비용 원인 확정

입력: 고정6a4a4b52와 원인 비교의 동일fixture. 일반 추방 transaction은 모집/member/state/event를
같이 변경하고 이전 lifecycle marker를 소비한다. 운영 앱 member removal Write Plan과 테스트의
변경 필드/표식 소비/읽기순서를 먼저 필드별 대조한다.

1. 기존 실패1건에 문서별 ruleCoverage를 붙여 모집update/member delete/state delete/event create의
   평가 경로를 기록한다. 토큰/노드 합을 정확한 expression 수로 오인하지 않는다.
2. 검증 함수 본문·권한을 유지하면서 일반 제거 validator가 무관한 고비용 lifecycle/cleanup 분기보다
   먼저 선택되도록 하는 후보를 하나만 설계한다. 필요하다면 현재 변경 필드와 명령 소비 조건으로
   안전한 guard를 둔다. 클라이언트 제공 marker만 신뢰하거나 새 저장 필드를 추가하지 않는다.
3. assertFails만으로 거절 통과를 선언하지 않고, 영향받는 음성 사례의 한도 초과 여부와 실제 거절조건을 구분한다.
   실패 재현+최대8 일반 추방/본인탈퇴+책임자 승계+마지막1인+표식 미소비/위조/부분쓰기 거절을
   같은 기준으로 비교한다. 소유권정리/개인완료/주차전환은 변경allow와 겹치는 최소 경계만 실행한다.
4. 신규 허용 또는 정상 거절 회귀/평가 한도 실패가 있으면 후보 미채택. 스키마 변경이 필요하면
   구현을 확장하지 않고 재설계한다. 성공본만 독립 기능 복구 커밋으로 만들고 이후 일반 간소화 시작.

이번 조사에서 위 구현은 실행하지 않았다. 전체 기준선의 실패가 남아 있으므로 현행 전체기능 검증완료,
Rules 간소화 완료, 실기기 준비완료 또는 게시503 해결로 보고하지 않는다. 원격 게시 별도 승인 필요.


## 2026-10-04 개인 완료 중복 호출 축소

앞쪽 전용 분기로만 성공 가능한 개인 완료의 후순위 호출3곳 제거. 함수 본문 그대로,
CI37132447511 기존본15/후보15 결과 동일. 최종223746bytes/SHA6a4a4b52….
생성 결과·CI 후보 일치. 컴파일 경고 미관찰. 컴파일 크기·503 해결은 미확인,
추가 게시 없음. [근거/제한 검증](DEV_LOG.md).

## 2026-10-03 추가 최소 수정 — Character 변경 평가 순서

members update의 중복 자리 검사 제거와 캐릭터 변경/방장 승계 검증 순서 조정만 채택했다.
변경 슬롯 추출 후보는 한도 실패를 해결하지 못해 미채택. CI37124237550에서 후보 배치11,
참가11, 정리/승계51, 해산10 결과 통과. 원본 함수 본문·권한·저장 계약 보존.
최종224266 bytes/SHA39a7b73168a6c236340bb91dffb58682fde5c9f85bdcb452c42ddc7637ad838b.
생성/CI 후보 일치 및 정적10건 통과. 컴파일 경고 미관찰, 원격 게시/503 해결은 미확인.
[계측·검증 상세](DEV_LOG.md). 아래 f43ea68c는 보존된 이전 기준이다.


## 2026-10-03 최종 반영 — 정리 한도 수정과 제한 비교 통과

3구간 연속 진행 승인에 따라 기존 슬롯 보존 검사 비용을 줄였다. 기존 helper는 삭제 후 남은
동일 슬롯도 8개 인덱스별 hasAny로 확인했다. 최대8 제한 안에서 hasAll을 먼저 평가하고,
새/변경 슬롯은 기존 membership 차수 검사를 그대로 실행하도록 했다. 권한 조건 삭제가 아니다.
단독 수정 후보가 기존 실패 사례를 통과해 이 전역 검사 비용을 줄이는 수정의 효과를 확인했다.
정확한 절감 표현식 수나 다른 모든 경로의 예산까지 계측한 것은 아니다.

- CI37107454891: 생성 문자열의 불필요한 +로 컴파일 실패. 11ca675에서 해당 문자만 교정.
- [CI37107631737](https://github.com/heo0328/LostParty_flutter/actions/runs/37107631737):
  수정/중복제거/이벤트분기 세 후보 각각 정리51+마지막1인10=61건 통과(총183회).
  최대8인 연쇄정리6회→방장승계→주차전환, 재시도/동시요청, 재이전, 누락·변조 원자 거절,
  다른 state/완료 이력/그룹 관계 보존 포함. 세 후보 결과 이름/통과 결과도 동일 대조했다.
- [CI37107959996](https://github.com/heo0328/LostParty_flutter/actions/runs/37107959996):
  최종 후보 참가11건 통과. 신규/legacy 생성·신청·승인, A→B→A 옛 승인 거절,
  최대8인 자리교환 차수 보존과 membership 없는 차수 위조 거절. 정리 묶음 반복 없음.
- 두 성공 CI의 최종 후보 SHA256은
  f43ea68c10658121206581b10730706f68f5cf524e4dc8543840352242ee0500이며
  배포 원본 firestore.rules와 완전 일치한다. 컴파일 경고 미관찰. 음성 사례 런타임
  permission-denied/진단 listener 경고는 컴파일 경고와 구분한다.
- 227459→224418 bytes, 함수279→274, 정적 helper 최대깊이6 유지.
  소스/중복 감소이며 컴파일된 크기 또는 게시503 해결을 주장하지 않는다.
- Node 정적7건, Flutter Rules 정적 계약3건, 생성 일치와 git diff --check 통과.
  최종 생성 도구는 과거 fixture의 통합본을 재구성해 3변환을 적용하며 비교 기준도 재현 가능하다.

일반/peer 소유권·state 비교를 공통화하고 방장 전용 비교는 보존했다. 이벤트3종만 독점 분기,
모집/member/listing 기존 분기와 스키마/앱은 유지했다. 전체 회귀와 실기기는 미실행.
운영 게시·dev/main 병합은 제외했고 운영 활성화503/로컬HTTP2 장애는 별도 미해결이다.
중단된 마지막 정적 검사는 승인 검토 사용량 한도로 실행되지 않았고, 사용자 재개 후3건 통과했다.

## 2026-10-03 제한 CI — 기준본 최대8인 정리 평가 한도 실패

사용자 재개 승인으로 dfd79fa의 기존 workflow에서 ownership-leader/complexity-comparison만
실행했다. [CI37106260020](https://github.com/heo0328/LostParty_flutter/actions/runs/37106260020)는
실제 demo 에뮬레이터까지 정상 도달했으며 로컬 HTTP/2 장애는 재현하지 않았다.
정적6건/생성 일치는 통과했지만 baseline/cleanup-peer 첫 시나리오가 실패했다.

- 기준본 SHA11ef3dde97ac202f488d1a12d861c2cf20c13e50ef9c5c3e1dc45e1fdc3af151.
- 시나리오: peer maximum six removals then leader succession and advance.
- 모집 update L4631에서 maximum of 1000 expressions. 내부 실패 보고는 L2507
  dePeerCleanupEvent의 event map 구성 지점이다. member delete/listing/event 오류도 함께 기록됐다.
  한도 도달 위치만으로 그 함수가 과도 비용의 원인이라고 확정하지 않는다.
- 시나리오 내부 각 반복 단계 로그는 없어 몇 번째 정리인지 확정하지 않는다. 시나리오 통과0건이며
  기준본 실패 시 중단 계약에 따라 last-member/두 후보를 실행하지 않았다.
- 기존 통합 게시 경계40건은 generation/last-member/orphan이었다. 이번 peer 연쇄 검사는
  그 묶음과 다르므로 과거 통과를 취소하거나 이번 실패를 개선 후보의 회귀로 해석하지 않는다.
- 전역 deChangedSlotGenerations 8칸 검사와 누적 정리 validator 결합 비용은 후속 조사 후보다.
  삭제/우회하지 않았고 인과 비교나 최소 수정은 아직 수행하지 않았다.
- 런타임 진단 listener의 ArrayIndexOutOfBoundsException 경고가 함께 있다. 이는 컴파일
  경고와 구분하며 평가식1000 오류를 숨기지 않는다. 컴파일 경고는 관찰되지 않았다.

결과 artifact는 coverage/roster-complexity/ci-37106260020에 확보했다. 같은 CI 재실행 없음.
운영/배포 원본/앱 무변경, dev/main 미반영. 다음은 기준본 명령 비용 분리 설계 후 필요한 표적 검사다.
운영 활성화503의 원인이 이 런타임 한도라는 근거는 없으며 두 장애를 구분한다.

## 2026-10-03 복잡도 개선 후보 — 로컬 실행 차단, 채택 보류

사용자가 중복 제거와 안전한 분기 축소를 승인했다. 운영 게시·원격 비교·dev/main 병합은 제외한다.
503 원인 해결과 구조 개선은 별개다. 배포 원본은 SHA `11ef3dde…`로 유지했다.

### 후보와 코드 근거

`tools/roster_complexity_candidate.mjs`는 누적 생성 결과 뒤 적용하는 별도 변환이다.
`integrate_roster_rules.mjs --complexity-candidates`는 coverage/roster-complexity에만
baseline/deduplicated/dispatched를 생성한다. 기본 생성과 --check는 기존 배포 원본을 유지한다.
과거 fixture와 후보 생성 체인은 변경하지 않았다. 추정 미사용 함수 삭제는 하지 않았다.

| 후보 | 소스 bytes | 함수 수 | 정적 최대 helper 깊이 | 상태 |
| --- | ---: | ---: | ---: | --- |
| 기준본 | 227459 | 279 | 6 | 배포 원본 유지 |
| 동일 검사 공통화 | 224298 | 274 | 6 | 정적 대조 통과, 실행 미확인 |
| 이벤트 분기 추가 | 224358 | 274 | 6 | 정적 대조 통과, 실행 미확인 |

1단계는 ownershipChanged/stateUnchanged 두 검사의 leader/peer 복제와 peer composition
복제를 제거한다. 원본 본문이 같지 않으면 변환 자체를 실패시킨다. leader composition은
공통 비교를 호출하고 leaderPlayerId/이름/직업 Snapshot 비교를 추가로 유지한다.
동일 조건의 평가 순서와 공통 호출이 바뀌므로 정적 동등성만으로 실행 비용 동등성을 주장하지 않는다.

### Write Plan → Rules 경로 판단

Router의 두 FirestoreCompletedOwnershipCleanupRepository 연결 → transaction의 binding,
모집/member/character/gameAccount 조회 → CompletedOwnershipCleanup의 모집 patch,
member 삭제/후임 변경, listing patch, event 원자 저장을 기준으로 대조했다.
정리는 기존 완료 state를 승계하지 않으며 원정대·그룹 관계와 과거 기록 보존 검사는 유지한다.

| 쓰기 경로 | 실제 계약과 신규성 | 이번 결정 |
| --- | --- | --- |
| 모집 update | cleanup patch가 revision+1, expectedRevision, lastCommandId/type/actor/at를 저장. 일반 membership/lifecycle와 marker 보존·소진 경로 혼재 | 기존 OR/분기 유지. 종류만으로 독점 분기하지 않음 |
| member update | 승계 권한 변경 외에도 별도 승인 권한 변경 가능. 방장 정리 후 marker가 남은 독립 변경을 기존 proof가 보호 | 기존 분기 유지 |
| member delete | 일반/peer/방장 정리와 개인 완료·일반 탈퇴/추방 혼재 | 현재 문서별 검증 분담 유지 |
| group raidListing update | 정리 patch와 일반 목록/회차/공개 범위 경로 공유 | 기존 분기 유지 |
| partyEvent create | 세 ownership 이벤트는 membership의 9개 종류 및 lifecycle 종류와 서로 배타적 | 세 종류만 직접 분기 후보. 나머지 OR 유지 |

이벤트 후보는 기존 cleanup validator의 before/after revision, expectedRevision, actor,
request.time 및 정확한 event/command 비교를 그대로 호출한다. 새 명령 ID != 이전 ID라는
추가 정책은 만들지 않는다. 잘못된 요청이 다른 이벤트 validator로 우회 가능한지 서버 검사 후 채택한다.
소유권/승계/마지막 1인 정책과 앱 스키마·인터페이스는 변경하지 않았다.

### 검증 결과와 다음 게이트

후속 로컬 진단: 8080 리스너 없음/관련 proxy·GRPC 환경변수 없음 확인. 별도8088 포트와
한 줄짜리 전체 거절 Rules로 기동해도 gRPC/HTTP2 protocol error 및 HTTP503이 재현됐다.
Firestore/Java를 제외한 Node24 자체 HTTP/2 서버·클라이언트의 단일 프로세스 loopback
대조에서도 ERR_HTTP2_ERROR가 발생했다. 따라서 현재 로컬 실패는 통합 Rules 크기/권한
검증에서 발생한 것으로 볼 수 없다. 원인은 실행 환경의 HTTP/2 경로로 좁혔으나 OS/Node/
네트워크 차단 구성 중 구체적 주체는 미확정이다. 운영 Release503과 동일 원인이라고 단정하지 않는다.
진단 스크립트는 coverage/roster-complexity/transport에 보존했고 프로세스 종료했다.
방화벽/프록시/보안 설정 변경과 같은 실험 반복은 하지 않았다. 사용자는 격리 CI 확대 대신
로컬 진단 결과 기록 후 보류를 선택했다. 새 지시 전 추가 진단/서버 검증/후보 채택을 진행하지 않는다.

- Node 정적 계약 6건 통과: 본문/allow 보존, 방장 비교 보존, 생성원본 변경 시 실패,
  이벤트 한 경로 변경, 종류 배타성, 정적 호출 그래프. 이는 Rules 컴파일/권한 검사가 아니다.
- 생성 결과 일치와 JS 문법, diff 검사 통과. 소스 감소는 컴파일 결과 크기 감소를 뜻하지 않는다.
- 과거 Rules 사후 주입 실패를 반복하지 않으려고 JDK21/emulator1.22.0 시작 시 --rules로
  기준본을 로딩했다. sandbox loopback 제한은 권한 확장 실행으로 해소하여 기동했다.
  실제 첫 비인증 요청은 gRPC INTERNAL/RST_STREAM, HTTP 읽기 대조는
  503 Network closed for unknown reason. permission-denied 판정 전 실패이며 후보는 실행하지 않았다.
  프로세스 종료. 운영 API 요청/배포와 원격 CI는 실행하지 않았다.
- 새 후보의 컴파일 경고 0개, 최대 8인 평가 한도, 실제 허용/거절 동등성은 미확인이다.

다음 검증 도구는 `tools/roster_complexity_differential.mjs`다. 정상 로컬 demo 에뮬레이터에서
기준본 → 공통화 → 이벤트 분기 순으로 같은 cleanup-peer/last-member 제한 묶음을 실행한다.
첫 실패에서 중단하며 전체 회귀는 실행하지 않는다. 기존 proof에 원본 경로 override를 연결했고
이 모드에서만 알 수 없는 명령/다른 정리 이벤트 종류/잔존 marker로 event 재생성 거절을 추가했다.
기존 8인 정리·승계·전환, 재이전, 누락 쓰기와 상태/그룹 보존 검사를 재사용한다.
새 비교 도구의 문법은 확인했으나 실행 결과는 아직 없다. 로컬 환경 복구 또는 별도 검증 환경
결정 전 배포 원본으로 승격하지 않는다. 런타임 검증 실패를 권한 완화로 해결하지 않는다.

## 2026-10-03 원정대 재인증 통합본 게시

추가 사용자 승인 14:37 재게시: 원격 컴파일/Ruleset 생성은 성공했고 Release PATCH가 503,
CLI 자동 create fallback은409. 최근5개 저장본 통합 소스 일치/활성 소스 불변을 확인했다.
근본 원인 미확정. [진단 상세](ROSTER_RULES_PUBLISH_DIAGNOSIS.md)를 최신 기준으로 따른다.

사용자 지시로 전체 회귀는 생략. 통합본 정적 계약 3건 및 최종 소스 demo 경계 40건 통과.
demo 컴파일 경고 미관찰. 운영 1회는 `/test` HTTP 503으로 실패하고 rulesets/releases에
도달하지 않았다. 활성 소스·ruleset은 전후 동일함을 직접 확인했다. 재시도하지 않았으며
503을 소스 복잡도 확정 근거로 사용하지 않는다. SHA·CI·실패 상세는 DEV_LOG 최신 기록 참조.

## 2026-09-29 BUG-017 Character 변경 배치 검증

- 슬롯별 반복 검사를 추가한 최초 CI `36544333862`에서 8인 Character 변경이 1,000식
  한도를 넘었다. 대상 제외 목록의 정확한 동등성 비교로 전환한 `36544797646`은
  제자리 변경을 통과했지만 빈자리 이동에서 추가 평가 비용으로 실패했다.
- Character 변경 membership의 신규/이전 target 8칸 순회를 현재 두 필드 맵의 직접
  비교로 교체하고 타인 target 목록 보존도 검증했다. 문서 조회·쓰기 수와 다른 명령의
  전역 target helper는 바꾸지 않았다. 요청자를 배열 마지막에 둔 최대 8인 표적 검사와
  최종 `243a6ee`의 전체 CI `36545232145`가 성공했다. Rules 컴파일 경고는 관찰되지 않았다.
- 운영 배포는 자동 승인 검토가 명시 게시 승인 부족으로 실행 전에 거절했다.
  실제 원격 배포 요청은 없고 우회하지 않았다. 이후 사용자가 직접 Rules를 게시하고
  디바이스 3대로 시험한 캐릭터 변경 성공을 보고했다. 만석 흐름은 실기기 미확인이며
  운영 활성 소스·해시는 독립 대조하지 않았다. 현재는 추가 게시 승인 대기 상태가 아니다.
  검증 Rules 해시와 상세 결과는 DEV_LOG 최신 BUG-017 기록을 따른다.

## 2026-09-29 A3 재현 전제 정정

기존 production fixture는 leaderOnly 방에서 직접 재가입 성공을 기대했다. 실제 앱과
Rules는 directJoin만 허용한다. 승인형 거절을 유지하고 정상 정책 fixture로 교정한
`5874862`의 CI `36464308075`에서 전체 추적 Rules 및 그룹 이전·탈퇴·해산이 통과했다.
제품 Rules 변경 없이 정상 직접 가입·재가입·8인 경계·그룹 신청 승인을 확인했으므로
아래의 production 정상 재가입 한도 확정 판정은 철회한다. C/C7 실험의 당시 실패 이력은
유지하며 운영 게시 성공이나 모든 거절 경로의 비용 해결로 확대하지 않는다.

## 2026-09-27 C7 v3 직접 재가입 격리 proof — 3-write 한도 초과로 폐기

- 운영 `firestore.rules`와 앱 코드를 수정하지 않고 별도 `party_join_v3_proof.rules`에 그룹 직접 재가입의 3-write 권위 Transaction을 구성했다. 모집 Aggregate·개인 `raidState`·결정적 party event를 모두 요구하고 비그룹원·block·타인 Character·주간 Claim·자리/count 위조·핵심 문서 누락을 거절하는 fixture를 추가했다.
- 중단 지점 재검수에서 신규 append만 확인하고 기존 `memberPlayerIds/partySlots/raidStateTargets` 앞부분 보존을 강제하지 않은 proof 보안 누락을 발견했다. 최대 8개 기존 항목의 exact preservation helper와 기존 slot/target 변조 거절 사례를 추가한 뒤 JS 문법과 `git diff --check`를 통과했다.
- 저장소 JDK 21로 격리 Firestore Emulator 자체는 기동했지만 `initializeTestEnvironment`의 proof Rules 로딩 단계에서 HTTP 503 `Network closed for unknown reason`가 발생했다. 시나리오 실행 전의 기존 Windows 환경 실패이므로 Rules 허용·거절 또는 1,000식 결과로 해석하지 않으며 같은 로컬 명령을 반복하지 않는다.
- Actions `36326380626`의 모집 단건 읽기 차단과 `36326546696`의 배열 내부 `serverTimestamp()` 제약은 proof 하네스 문제로 확인해 실제 제품 계약에 맞게 교정했다. slot에는 결정적 event ID를 저장하고 같은 Transaction event의 `occurredAt == request.time`을 권위 가입 시각으로 유지한다.
- 교정 후 Actions `36326680954`에서 정상 그룹 직접 재가입 3-write 자체가 `maximum of 1000 expressions`로 거절됐다. C7의 사전 폐기 조건에 해당하므로 승인 4-write·8인·migration proof와 제품 구현을 진행하지 않는다. 운영 Rules·앱·데이터는 변경하거나 배포하지 않았다.

## 2026-09-27 F6-H 원격 회귀와 기존 그룹 재가입 한도 분리

- 작업 브랜치 커밋 `80654d9`로 Actions `36318200515`를 실행했다. 추적 `firestore.rules`는 경고 없이 컴파일됐고, 기존 생성·신청·승인·자리 이동·추방·탈퇴·완료·해산 흐름과 F6-H의 lifecycle 마커 미소진 거절, 소진 후 자리 이동·추방·신청 성공은 모두 통과했다.
- 실행은 이후의 기존 `그룹방 탈퇴 후 직접 재가입`에서 `maximum of 1000 expressions`로 실패했다. 이는 F6-H보다 앞서 별도 C 과제로 기록한 동일 실패이며, 마지막 성공 실행 `35948873935`에는 해당 재현 케이스가 아직 없었다. 재현 케이스 추가 이후 실행들은 같은 한도에서 계속 실패했다.
- F6-H 변경 때문에 정상 흐름이 새로 깨졌다는 근거는 없지만, 저장소의 전체 Rules 회귀가 성공하지 않았으므로 운영 Rules는 게시하지 않는다. 이 실패를 숨기려고 재가입 케이스를 삭제·완화하거나 H1 권한 조건을 줄이지 않는다.
- 다음 결정은 별도 재가입 C의 신뢰 서버/데이터 계약 재설계를 먼저 수행할지, 또는 현재 알려진 실패를 격리한 별도의 배포 게이트를 명시적으로 승인할지다. 어느 쪽도 현재 F6-H 범위에서 임의 적용하지 않는다.

## 2026-09-27 F6-H lifecycle 마커 소진 로컬 Emulator 로딩 실패

- 반복방 `advanceCycle` 뒤 정상 멤버 명령이 지속된 lifecycle 마커 때문에 거절되는 문제를 수정하고, production Rules 회귀에 마커 미소진 거절과 소진 후 자리 이동·추방·신청 성공을 추가했다.
- 저장소의 Temurin JDK 21로 Firestore Emulator는 정상 기동했으나 `initializeTestEnvironment`가 추적 `firestore.rules`를 로드하는 단계에서 HTTP 503 `Network closed for unknown reason`를 반환했다. 테스트 시나리오 평가 전 실패이며 Rules 허용·거절이나 표현식 1,000개 한도 결과는 확보되지 않았다.
- 같은 Windows 로컬 명령은 반복하지 않는다. 다음 검증은 현재 작업 브랜치 체크포인트를 원격에 올린 뒤 기존 격리 GitHub Actions 전체 회귀로 수행한다. CI 통과 전에는 Rules 게시·F6-H 완료·`dev` 통합으로 판정하지 않는다.

## 2026-09-24 BUG-022 그룹방 재가입 표현식 한계

- 그룹방 탈퇴 후 직접 재가입은 모집·membership·raidState·공용 이벤트·그룹 listing을 원자 갱신하며 production Rules에서 1,000식 한도를 넘는다. 공개방의 같은 재가입과 그룹방 탈퇴까지는 통과한다.
- listing/event 쓰기 제거, 그룹 membership 조회 축소, 관련 match의 가입 분기 선별은 효과가 없었다. membership과 raidState가 공유하는 target 결합 검증도 raidState 한쪽 제거(`35992417272`), 양쪽을 마지막 인덱스 정렬 검증으로 교체(`35993347464`)했으나 정상 재가입은 동일하게 실패했다. 각 변경의 단독/누락/target·순서 위조 거절은 유지됐지만 비용 절감 효과가 없어 모두 되돌렸다.
- 모집 update를 권위 참가 validator로 만들고 membership·raidState·event·listing을 직접 Projection 검증으로 축소한 전체 재설계도 실패했다. 첫 실행 `35997627746`과 Projection 봉투를 더 줄인 `35998246596` 모두 그룹 재가입 전의 기존 공개방 신청 승인에서 1,000식 한도를 넘었다. 승인자 권한을 포함한 보안 조건은 완화하지 않았고 두 구현은 revert했다.
- 신규 생성·수동 완료·그룹 신청 승인·코드 가입·공개방 재가입·자리 이동·추방/탈퇴·2/4/8인 해산과 BUG-022 A1/A2는 각 실패 실행에서 정상 재가입 직전까지 통과했다. 따라서 무관한 기존 흐름을 완화하거나 다시 작성하지 않는다.
- 다음 단계는 미세 Rules 최적화가 아니라 신뢰 서버 참가 명령 또는 원자 명령·데이터 계약 재설계다. 원자 쓰기 분리나 권한·소유권·주간 완료·그룹 접근·target 결합 삭제는 허용하지 않는다. 전환·멱등성·구버전 호환·배포 순서를 설계한 뒤 별도 승인된 작업 그룹으로 진행한다.

## 2026-09-21 BUG-021 그룹 신청 승인 표현식 예산 복구

- demo CI `35562516961`에서 membership 문서가 없는 최초 신청 승인부터 Firestore Rules `maximum of 1000 expressions`로 실패해 Player별 고아 데이터가 아닌 공통 승인 경로 회귀로 확정했다.
- `joinRelations`, `members`, `groupMembershipState`, Player `groupRelations`, `groups`에서 application 승인 validator를 actor·kind·status·joinedBy·memberCount의 값싼 guard 뒤 앞쪽으로 옮겼다. 권한 조건, Transaction 문서 수와 저장 스키마는 변경하지 않았다.
- 표적 정적 계약 5건과 Actions `35565203228`의 전체 추적 Rules 회귀가 통과했다. 최초 membership 생성 승인, revision 14의 빈 membership 갱신 승인, 초대코드 가입, 그룹장 이전·탈퇴·해산을 같은 실행에서 확인했다.
- 추적 Rules SHA-256은 `907302E0747A28FFFB581DB295E60633C04811EF33E6AE3F161EA5A6CB5B0FD6`다. 사용자가 운영 Rules를 게시한 뒤 기존 승인 실패 Player 2명 모두 정상 승인됨을 확인했다. AI는 콘솔 활성 소스 해시를 독립 대조하지 않았으며 작업 브랜치는 `dev`에 fast-forward 통합했다.

## 2026-09-21 F8-A 고아 application 단건 삭제 검증

- 현재 Player가 신청자인 application만, 부모 모집 없음 또는 `completed/disbanded/incompleteEnded`일 때 단건 삭제하도록 허용했다. 활성 부모와 타인 신청은 계속 거절한다.
- 모집 Aggregate·membership·`raidState`·주간 완료·이벤트 쓰기를 추가하지 않아 인원수 비례 조회나 fan-out이 없다. 삭제 판정은 부모 모집 경로 한 건만 확인한다.
- GitHub Actions demo Emulator `35529627164`에서 신규 허용·거절 사례와 기존 파티·그룹 회귀가 통과했다. Actions의 Node/setup-java 안내는 Rules 컴파일 경고가 아니다.
- 추적 Rules SHA-256은 `6691D744E2D816D2618F1C8B2C8EFF7CB1C607F09CC238A11AE955C57583310B`다. 사용자가 Firebase 콘솔에서 Rules를 직접 게시했고 실기기 고아 신청 삭제 성공을 확인했다. AI는 활성 소스 해시를 독립 대조하지 않았다.

## 2026-09-20 F6-D5 신청 state 최종 차단 검증

- application create/reapply의 기존 완료 검사를 exact `raidState` 부재와 legacy Claim 부재로 분리했다. state가 남은 요청은 상태 내용을 반복 검사하지 않고 단건 `existsAfter`에서 먼저 거절하므로 부모 모집 N+1 조회, 인원수 비례 검증과 Player 이벤트 fan-out을 추가하지 않는다.
- 신청 create와 철회 후 reapply 모두 state 잔존 거절, state 제거 후 기존 정상 흐름 성공을 demo 시나리오로 고정했다. 즉시 가입은 기존 `raidState` create 계약이 최종 점유 경쟁을 거절하며 중복 Rules 조회를 추가하지 않았다.
- JS 문법, 정적 Rules 계약, 관련 Flutter 표적 테스트와 변경 파일 분석이 통과했다. 작업 브랜치 Actions `35494192803`에서 전체 추적 Rules 및 기존 그룹 이전·탈퇴·해산 회귀가 통과했다. Actions의 Node/setup-java 주석은 Rules 컴파일 경고가 아니다.
- 추적 Rules SHA-256은 `9228699FEB79F2F41AC782B8E4F98FF6AEE1F94248354B954CEF503AB2B65B0C`다. 운영 `lost-party`에 Rules만 1회 게시 시도했으나 원격 컴파일 `projects/lost-party:test`가 HTTP 503 `UNAVAILABLE`을 반환했다. `/rulesets` 업로드와 `/releases` 반영에는 도달하지 않아 운영 Rules는 갱신되지 않았으며 같은 명령을 반복하지 않는다.

## 2026-09-20 F6-D 단건 고아 참가 기록 정리 검증

- 기존 `validAtomicStaleRaidStateDelete`를 유지하고 구 `activeRaidAssignments`에는 현재 바인딩 Player 본인, 정확한 문서 ID, active 상태, 연결 모집 없음 또는 기존 stale 모집일 때만 허용하는 delete 분기 하나를 추가했다. 생성·수정, 타인 정리, 정상 활성 모집 정리는 계속 닫혀 있다.
- demo Rules 시나리오는 모집 원본 없음인 본인 `raidState`+구 assignment 원자 삭제 성공, 타인 삭제 거절, 정상 활성 모집 삭제 거절의 대표 사례만 추가했다. 인원수별 반복이나 Player 이벤트 fan-out은 추가하지 않았다.
- JS 문법, Rules 문자열 계약, 관련 ViewModel 테스트 9건과 변경 Dart 파일 정적 분석이 통과했다. 로컬 Emulator는 이미 확인된 Windows Rules 로딩 503을 반복하지 않았으며, 작업 브랜치 Actions `35454451057`의 demo Emulator에서 전체 추적 Rules와 기존 그룹 이전·탈퇴·해산 회귀까지 통과했다. Actions의 Node/setup-java 주석은 Rules 컴파일 경고가 아니다.
- 변경 Rules SHA-256은 `716402EF95051F6F07B799F275431B9A89718E7BA713A07EEEFB147FDCDCCC94`다. 이후 사용자가 Firebase 콘솔에서 Rules를 한 차례 게시했다고 확인했으나 AI가 활성 소스 해시를 직접 대조하지 않았다. 이전 주차 고아와 신청 create/reapply 최종 차단 설계가 추가됐으므로 후속 Rules 변경이 생기면 같은 검증 게이트 뒤 다시 게시해야 하며, 실기기 확인 전에는 F6-D 완료로 판정하지 않는다.

## 2026-09-19 F6-B2-A 본인 주간 상태 list 검증

- `players/{playerId}/raidStates`와 구 `activeRaidAssignments`의 list를 현재 바인딩 Player 본인에게만 열고 구 assignment 쓰기는 계속 닫았다.
- demo Rules Emulator 시나리오에 본인 현재 주차 list 성공과 타 Player list 거절을 추가했다. Android Studio JBR 21로 Emulator는 기동했으나 추적 `firestore.rules` 로딩이 기존 Windows 환경과 같은 `503 Network closed for unknown reason`로 중단돼 시나리오 평가에 도달하지 못했다.
- 문자열 계약·JS 문법·Flutter 표적 테스트에 더해 작업 브랜치 GitHub Actions `35412398666`의 demo Emulator에서 전체 추적 Rules 회귀와 본인 현재 주차 list 허용·타 Player list 거절이 통과했다.
- 승인 후 SHA-256 `51146C8DF8B12493AE5B3DACAD47D533A74D242C25F57930FAAA49BF2E0280CC`의 `firestore.rules`만 운영 `lost-party`에 1회 게시 시도했다. 원격 컴파일 `projects/lost-party:test`가 HTTP 503 `UNAVAILABLE`을 반환해 `/rulesets` 업로드와 `/releases` 반영에는 도달하지 않았다. 운영 Rules는 갱신되지 않은 상태로 판정하며 같은 명령을 반복하지 않는다.
- 이후 사용자가 Firebase 콘솔에서 Rules를 별도로 게시했다고 확인했다. AI는 활성 게시 소스와 로컬 SHA-256을 직접 대조하지 않았으므로 내용 일치는 단정하지 않는다. 게시 후 실기기에서 확인된 다인 전체 완료 권한 실패는 Rules 컴파일 실패가 아니라 앱이 타인 private `raidState`를 선조회하는 구조와 일치하며, 완료 기록 누락·체크박스 비활성은 각각 이벤트 Payload와 UI 명령 연결 문제로 분리한다.

## 2026-09-19 F6-B2-R2 공용 완료 이벤트 검증

- lifecycle event schemaVersion 2의 완료·완료 취소 Payload에 공통 `raidId/difficultyId/cycleKey`와 최대 8개 `completionTargets`를 추가했다. Rules는 한 번 읽은 변경 후 모집의 `partySlots`와 audience·Player·Character를 인덱스별로 비교하며, 대상별 추가 문서 조회나 Player 이벤트 fan-out은 추가하지 않았다.
- schemaVersion 1 lifecycle event create는 구 앱 호환을 위해 기존 필드 계약으로 유지하고, 새 schemaVersion 2 완료 이벤트의 대상 누락·Character 위조는 거절하도록 demo 시나리오를 추가했다.
- Dart 표적·정적 계약과 JS 문법은 통과했다. 기존 Android Studio JBR로 실행한 로컬 demo Emulator는 Rules 로딩 단계에서 `503 Network closed for unknown reason`가 발생했지만, 작업 브랜치 GitHub Actions `35417265039`의 격리 Emulator에서는 Rules 컴파일·로딩과 1·2·4·8인 lifecycle, 완료 대상 누락·Character 위조 거절이 모두 통과했다. Actions의 Node 20/setup-java v4 deprecation 표시는 Rules 경고가 아니다. 운영 Rules는 게시하지 않았다.

## 2026-09-13 파티 통합 오류 Snapshot allowlist 배포 시도

- 작업 브랜치 `codex/plan-release-stabilization-fixes`의 추적 커밋 `8b4d5ce`는 파티 Character 변경의 `affectedKeys`에 표시용 `buildIntegritySnapshot` 1개만 추가한다. 관련 문자열 계약 테스트 2건은 통과했다.
- `firebase.json`의 배포 원본 `firestore.rules`와 대상 `lost-party`를 확인한 뒤 실제 배포를 한 번 실행했다.
- Firebase Rules 원격 컴파일 `projects/lost-party:test` 단계에서 HTTP 503이 발생했다. `/rulesets` 업로드와 `/releases` 반영에는 도달하지 않았으므로 운영 Rules는 갱신되지 않은 상태로 판정한다.
- 컴파일 성공과 경고 0개도 확인하지 못했다. 기존 장애 대응 원칙에 따라 같은 명령을 즉시 재시도하지 않으며, 사용자에게 실패 단계를 공유한 뒤 새 지시가 있을 때만 재시도한다.
- 후속 확인에서 동일 조건의 테스트 프로젝트는 콘솔 게시에 성공했고, 운영 프로젝트로 돌아오자 오류 문구가 사라졌다. 로컬 Rules를 다시 붙여 넣었을 때 변경점이 없어 게시 버튼이 비활성화됐으며 실기기 기능도 정상 동작했다.
- 이 간헐적 503에는 앱 코드·Rules 축소 같은 1차 대응을 하지 않는다. 같은 현상이 재발하면 동일 조건 테스트 프로젝트 게시 성공 여부를 먼저 대조한 뒤 `/test`, `/rulesets`, `/releases` 실패 단계를 분리한다.

## 2026-09-10 Rules 게시 경고 재점검

### 2026-09-14 다인 해산 수정본의 교차 프로젝트 `/rulesets` 503

- 커밋 `a5a28d6`의 Rules는 운영 `/test`에서 HTTP 200·컴파일 성공·경고 0건을 확인했지만 `/rulesets` POST가 HTTP 503으로 실패했다. Release 갱신에는 도달하지 않았다.
- 동일 소스를 별도 테스트 프로젝트 Firebase 콘솔에 게시해도 반복적으로 503이 발생했다. 운영 프로젝트 IAM·데이터·Auth 상태보다 현재 Rules 소스 형태 또는 Firebase Ruleset 저장 서비스의 공통 처리 문제를 우선한다.
- 직전 콘솔 게시 성공 기준 `c4344e6`과 현재 Rules의 기능 diff는 `validPlayerEvent` 한 곳이다. 함수 수는 199개로 같고, dispatcher의 type guard 목록 확장으로 소스가 약 578자 증가했다. 공개되지 않은 컴파일 산출물 크기를 측정한 값은 아니므로 단순 파일 용량 한계로 확정하지 않는다.
- 1차 대응은 권한·validator를 제거하지 않고 dispatcher를 짧은 우선순위 OR로 축소한다. `partyDisbanded` lifecycle을 cycle보다 먼저 두고 수동 인증 validator는 명시 type guard 뒤에 호출해 무관한 문서 조회를 막는다.
- compact 소스는 테스트 프로젝트에 먼저 게시한다. 실패하면 같은 시점에 직전 성공 기준 `c4344e6`을 A/B 대조한다. 둘 다 실패하면 외부 서비스 장애로 분류하고 추가 축소·반복 게시를 멈춘다. 기준본만 성공하면 R4 이벤트 Rules 중복 축소를 별도 작업으로 연다.
- compact dispatcher는 6행으로 구현했고 함수 수 199개를 유지했다. 직전 성공 기준과의 기능 diff는 dispatcher 1곳의 4행 추가·3행 삭제뿐이다. 표적 18건, 경고 계약 3건과 전체 Rules 로컬 Emulator 컴파일·기동이 통과했으며 원격 Ruleset 저장은 테스트 프로젝트 게시 전이라 미확인이다.

- 사용자가 Firebase 콘솔에 게시된 소스를 `firestore-web.rules`로 복사해 로컬 원본과 대조했다. 두 파일은 모두 3,785행이며 차이는 `groups/{groupId}` update에서 `validGroupDisbandUpdate`의 평가 순서 8행뿐이다. 콘솔본은 해산 판정이 마지막인 이전 게시본이고, 로컬 원본은 실제 1인 그룹 해산 오류를 보완해 가입·승인보다 앞에 둔 버전이다.
- 콘솔과 CLI에 표시된 경고 9개는 두 소스에 공통으로 존재한다. 따라서 최근 해산 순서 변경이나 주차 전환 기능이 새로 만든 경고가 아니다.
- 경고 원인은 미사용 `validRecruitmentJoin` 인자 1개, `null`과 string을 섞은 대표 Character·수동 인증 판정 3개, 생성 시 map 인자에 `null`을 전달한 membership·그룹 join relation·applicant stats 경로 5개다.
- 동일 소스가 원격 `projects/lost-party:test`에서 503을 반환하다가 컴파일에 성공했고, 콘솔 게시도 장시간 뒤 성공했다. 그러므로 이 사건에서 503을 경고의 직접 결과나 특정 기능의 오류로 확정하지 않는다. `compiled successfully`와 게시 성공은 문법 유효성을 뜻하지만, 경고를 방치할 근거로도 사용하지 않는다.
- 수정 원칙은 기능·스키마·허용/거절 조건을 삭제하지 않는 타입 명확화다. 생성 경로는 빈 목록·0·`request.time`을, 수정 경로는 기존 문서 값을 전달한다. nullable 계정 ID 반환은 존재·활성·소유 여부의 boolean 판정으로 바꾸고, 미사용 인자는 호출부와 함께 제거한다.
- `firestore-web.rules`는 게시본 증거로 수정하지 않고 Git 제외한다. 유일한 배포 원본은 `firebase.json`의 `firestore.rules`다.
- 로컬 검증: 그룹·활동 Character·운영자 인증·주차 전환 계약 테스트 43개와 경고 재발 방지 테스트 3개가 통과했다. 게시본 Snapshot의 정규화 SHA-256 `F9F3792E692DCC8E5DE5063E25842629E1CBFF58805FB815C74173E7C799538A`가 대조 전후 동일함을 확인했다.
- 원격 검증: 2026-09-10 사용자가 `firebase deploy --only firestore:rules --project lost-party --dry-run`을 실행해 `rules file firestore.rules compiled successfully`와 `Dry run complete`를 확인했다. 기존 미사용 인자·nullable string/map 경고 9개는 다시 출력되지 않았고 503도 재현되지 않았다. 실제 Ruleset 업로드·Release 반영은 아직 수행하지 않았다.
- 완료 조건은 관련 계약 테스트 통과, `git diff --check`, 원격 컴파일 경고 0개, 사용자가 수행한 Rules 배포의 `released rules ... to cloud.firestore`와 `Deploy complete` 확인이다. 배포 전에는 운영 반영 또는 503 해결 완료로 기록하지 않는다.
- 2026-09-10 운영 반영 후 실기기에서 그룹·레이드의 주요 쓰기와 이전 주차 점유 교체가 통과해 게시본이 실제 적용된 것을 기능 동작으로도 확인했다. 단, 1인 그룹 해산은 판정 순서를 앞당긴 뒤에도 permission-denied가 재현됐다. 따라서 이 실패를 Rules 전체 게시 실패나 503의 결과로 취급하지 않으며, 해산 전용 네 문서 Transaction의 조건 불일치로 별도 진단한다.
- 같은 날 현재 Rules 재배포를 한 번 실행했을 때 CLI는 컴파일 성공 후 Ruleset 생성 API에서 503으로 종료됐으나, Firebase 콘솔 최신 게시 시각은 요청 시각인 14:20으로 갱신됐다. Ruleset 생성이 서버에서 완료된 뒤 CLI 응답만 실패한 사례로 기록한다. 이후 동일 현상은 즉시 반복 배포하지 않고 콘솔의 활성 게시 시각과 소스 일치 여부를 먼저 확인한다.
- 후속 1인 해산 수정본은 해산 판정을 `groups` update의 첫 분기로 이동했고 표적 테스트 43건이 통과했다. 이 수정본의 배포 시도는 Ruleset 생성이 아니라 원격 컴파일 `/test` 단계에서 503으로 끝났으므로 운영 반영되지 않은 상태로 분리 기록한다. 503의 발생 위치를 무시하고 콘솔 시각만으로 동일하게 판정하지 않는다.
- 콘솔에 새 게시 기록이 없음을 확인한 뒤 동일 수정본을 재시도했고, 이번에는 원격 컴파일·Ruleset 업로드·Cloud Firestore Release가 모두 성공해 `Deploy complete`로 종료됐다. 1인 해산 우선순위 수정본의 운영 반영은 이 성공 로그를 기준으로 확정한다.
- 운영 반영 후 신규 1인 그룹 해산이 실기기에서 정상 완료됐다. 해산 update를 첫 분기로 평가한 수정의 운영 회귀 검증을 통과했으며, 이 해산 permission-denied 이슈는 종료한다.

> 현재 상태 정정(2026-09-01): 아래 프로브는 503 원인 확인을 위한 1회성 테스트였다. 이후 원복한 Rules에 추가 수정 작업을 진행해 정상 배포했고, 레이드 모집·탈퇴·완료 체크와 그룹 생성·초대·탈퇴·초대코드·가입·그룹 전용 모집 목록을 실기기에서 확인했다. 프로브 Rules가 현재 운영에 남아 있거나 Rules 배포가 현재 차단된 것으로 취급하지 않는다. 아래 내용은 당시 진단 이력으로만 보존한다.

> 2026-08-31 사용자 지시: 그룹 레이드 Rules 업로드가 복잡도 한도로 막히는 것으로 보고 최적화를 재개한다. 운영 프로브 배포는 하지 않는다. 원격 보존 브랜치: codex/rules-complexity-reduction @ ed02b31.

## 상태

| 항목 | 내용 |
| --- | --- |
| 발견일 | 2026-08-31 |
| 차단 범위 | **전체 `firestore.rules` 정상 배포** |
| 현재 단계 | **종료된 진단 이력**. 이후 원복·추가 수정·정상 배포·실기기 확인 완료 |
| Task-11·11a 코드 | **`main`에 1차 병합 완료** (Rules 운영 반영과는 별개) |
| 운영 영향 | 프로브는 1회성 테스트였고 이후 원복·추가 수정·정상 배포됨. 현재 영향 없음 |
| 다음 | 현재 실행 작업 없음. 아래 계획은 당시 기록으로만 보존 |

## 현재 작업 시작점과 최신 배포 결과

- 기준 코드 커밋: **`25f88ff6f8a7be1bdf9ab7f16bbae167ee3bb9ff`** (`refactor(rules): simplify group lookup and snapshot validation`).
- 작업 브랜치: **`codex/rules-complexity-reduction`**. main에 직접 수정하지 않는다.
- 직전 통합 기준: `ea2019a`. 25f88ff에는 native 탈퇴 그룹 탐색과 Snapshot 중복 비교 제거가 포함돼 있다.
- 기준 Rules 소스 크기: **143,799 bytes**. 원본 백업 158,836 bytes와 구분한다. 소스 크기는 컴파일 복잡도의 대리 지표일 뿐 성공 기준이 아니다.
- 사용자 지시에 따라 25f88ff의 전체 Rules를 `lost-party`에 배포 시도했으나 `projects/lost-party:test` 컴파일 검사에서 **503 UNAVAILABLE**로 실패했다. 새 release는 적용되지 않았다.
- 운영의 마지막 성공 Rules 내용은 별도로 조회 확인하지 않았다. 로컬 복원과 운영 복원을 같은 상태로 기록하지 않는다.
- 로컬 Emulator는 전체 Rules뿐 아니라 최소 deny-all Rules 로딩도 `503 / Network closed for unknown reason`으로 실패했다. 운영 API 실패와 로컬 검증 환경 실패를 구분한다.
- 기준 검증: 표적 Flutter 테스트 33개, 변경 테스트 파일 analyze, JS 문법 검사 통과. 실제 Rules 허용/거절 동작과 배포 성공은 미확인이다.
- `legacy/firestore - 복사본.rules`, `legacy/firestore.before-complexity-20260831.rules.bak`는 로컬 백업으로 보존하며 배포 대상에 넣지 않는다.

## 단계별 추가 개선 계획

이번 커밋은 **작업 시작점과 실행 계획만 기록하는 문서 커밋**이다. 아래 구현을 완료했다고 간주하지 않는다. 각 단계는 변경 전에 범위를 확인하고 별도 커밋으로 남긴다.

| 단계 | 변경 대상과 방법 | 앱·데이터 영향 | 검증 및 완료 조건 |
|---|---|---|---|
| R0 검증 환경 | 최소 Rules 로딩 오류를 먼저 분리 조사. 운영을 바꾸지 않는 컴파일 검사와 Emulator 허용/거절 테스트 경로 확보 | 없음 | 최소 대조 검사 성공과 전체 Rules 검사 결과를 각각 기록. 실패 시 수정 효과를 추정해 통과 처리하지 않음 |
| R1 그룹 가입 | `validInitialGroupMember`, `validInvitedGroupMember`, `validApprovedGroupMember`, `validJoinCodeGroupMember`의 필드·타입·초기 시각 검사를 공통 부분으로 정리. 생성자/가입자/승인자, 초대/신청/코드 증명과 차단 조건은 각 경로에 유지 | Rules 중심, 스키마 유지 | 생성·초대 수락·신청 승인·코드 가입 정상 경로 및 다른 경로로 위장·금지·타인·정원 초과 거절 |
| R2 Player 요약·목록 | 본인 가입과 그룹장 승인에서 반복되는 Group ID 1개 추가·중복·50개 제한·revision 검사를 공통화. 목록 Projection의 공통 스키마와 membership 일치 검사 정리 | Rules 중심, 스키마 유지 | 49→50 성공·50→51 실패, 동시 승인, 누락/위조 Projection, 기존 문서 없는 최초 생성 검증 |
| R3 파티·그룹 수정 | `affectedKeys().hasOnly()`와 개별 불변 비교의 중복을 함수별로 검토해 제거. 필수 필드 존재·허용 필드의 값 조건은 유지 | Rules 중심, 스키마 유지 | 허용 수정 성공, 필드 추가/삭제·역할·소유자 변조 거절. 각 함수의 적용 전후 허용 범위 비교 |
| R4 이벤트 | `validPlayerEvent` 및 신청·멤버·회차 이벤트의 공통 필드/시각/revision 검사를 정리. 단순 전달 함수·중복 분류를 축소 | Rules 중심, 이벤트 형식 유지 | 기존 이벤트별 수신자·발신자·연결 상태 검증. 타인 이벤트 삽입·재전송·위조 revision 거절 |
| R5 명령 대상 명시 | 앞 단계로 부족하면 그룹 승인·탈퇴·코드 관리에 명령 종류와 대상 ID를 명시하는 계약 초안 작성. 실제 변경과 원자적 연결 검증을 함께 설계 | Repository·Rules·명령 필드 변경 가능 | **설계 검토 후 별도 착수**. 명령 문자열만으로 권한 허용 금지. 인원만 변경·membership만 변경·요약 누락 등 부분 쓰기 차단 |
| R6 표시/권한 데이터 분리 | R5 이후에도 필요할 때만 membership 권한과 표시 Snapshot, 목록용 Projection 책임 재정의 | 문서 경로·조회·이행 작업 가능 | **설계 검토 후 별도 착수**. 기존 UX·오프라인 표시·조회 비용·기존 데이터 이행 계획 확보 |

### 공통 구현 원칙

- 현재 바로 시작할 단위는 **R0**, 다음은 R1이다. 한 번에 R1~R6을 모두 구현하지 않는다.
- 공통 함수 추출, OR 분기 순서 조정, 코드 줄 수 감소가 컴파일 크기 감소를 보장하지 않는다. 결과를 비교해 효과가 없으면 근거와 함께 해당 변경을 재검토한다.
- 상태·명령 종류·필드 집합으로 경로를 먼저 구분하고 필요한 문서만 읽는 방향을 검토한다. 기존 문서 누락 시 거절 의미와 OR의 다른 정상 경로를 훼손하지 않는다.
- 권한 검사를 클라이언트로 옮기거나 `signedIn()`만 남겨 축소하지 않는다. 파일 분할·주석 제거는 가독성 작업이지 핵심 해법이 아니다.
- UI/UX, Player 단위 그룹 소속, 본·부계정 사용, 50명/50개 제한, 초대·신청·코드 가입, 신청 금지·횟수, 반복 레이드·주간 Claim·운영자 인증 정책을 보존한다.
- 인증/캐릭터의 광범위한 쓰기 권한과 그룹 탈퇴의 변경 전 membership·요약 결합 누락은 별도 보안 보완으로 추적한다. 단순화 과정에서 이 문제를 더 넓히거나 해결됐다고 기록하지 않는다.
- 함수 중복 제거로 접근 한도를 맞추기 위해 원자성 검증을 삭제하지 않는다. 반대로 단순화와 무관한 보안 정책 변경도 같은 커밋에 섞지 않는다.
- 기능을 `false`로 막은 실험 Rules는 로컬 또는 격리된 검사에만 사용한다. 운영 프로브 배포는 금지한다.
- 향후 운영 배포는 해당 시점의 사용자 명시 지시 후 실행한다. 이전 배포 지시를 후속 자동 배포 권한으로 재사용하지 않는다.

### 단계별 작업 기록 양식

각 단계 종료 시 아래 항목을 이 문서 후속 절과 DEV_LOG에 남기고, NEXT_WORK는 다음 단일 작업을 가리키도록 갱신한다.

```text
단계 / 브랜치 / 시작 커밋:
변경 파일·함수:
기존 검증 → 변경 검증 및 동등성 근거:
앱·데이터·UX 영향:
소스 크기 전후 / 컴파일 결과(미측정은 미측정):
정상·거절·경쟁 조건 테스트와 미실행 항목:
배포 여부 / 실패 단계 / 운영 반영 여부:
남은 문제 / 다음 단계 / 결과 커밋:
```

문서 커밋의 자기 해시는 작성 시점에 확정되지 않으므로 Git 이력으로 식별한다. 첫 구현 단계 시작 시 이 문서 커밋의 실제 HEAD를 기록하고, 기준 코드 25f88ff와 구분한다.

### 검증 게이트와 복구

- 해당 단계의 정상·거절 경로를 Rules Emulator에서 확인하고, 표적 Flutter 테스트·관련 정적 분석·`git diff --check`를 수행한다. 문자열 계약 테스트만으로 Rules 동작 검증을 대체하지 않는다.
- 테스트 환경이 막히면 문서나 검토용 중간 커밋은 가능하지만 **검증 미완료**로 표기하고 다음 대규모 변경·배포 성공 선언을 하지 않는다.
- 기능 보존 완료는 전체 Rules 컴파일, 허가된 배포의 성공, 핵심 다중 사용자 경로 확인까지 필요하다. 503이 사라졌다는 이유만으로 보안 검증을 통과 처리하지 않는다.
- 변경 복구는 단계 커밋 단위로 검토한다. 사용자 작업·백업을 덮어쓰거나 main을 강제 초기화하지 않는다. 운영 복구가 필요하면 마지막 성공 release를 확인하고 별도 승인 후 실행한다.

## 요약

Task-11a(멤버 목록·탈퇴·표시 Snapshot) 코드는 `main`에 보존됐다. 다만 **Rules를 정상 배포할 수 있을 때까지** 해당 Rules·실기기 검증은 열린 부채다.

원인은 Rules 문법 오류가 아니라 **단일 `firestore.rules` 파일의 컴파일/업로드 복잡도 한도**에 가깝다.

- 전체 Rules (~159KB, ~3470줄): `firebase deploy --only firestore:rules` 시 **503** (사용자 재확인)
- 약 **47.9%**로 함수 본문을 `return false` 스텁으로 줄인 프로브 (~76KB): **compile + release 성공** (~13초)

즉, Task-11 leave·Snapshot refresh 등 **최근 Rules 추가분이 문법만 맞다고 배포가 보장되지 않는다.**

## 2026-08-31 검증 절차 (재현)

1. 원본 `firestore.rules` 백업 (`legacy/firestore - 복사본.rules` 등 사용자 로컬 사본 권장)
2. 경로 helper·`match` 블록은 유지, 검증 함수 본문 약 **101개**를 `return false` 스텁으로 축소
3. `firebase deploy --only firestore:rules --project lost-party`
4. **Deploy complete** 확인

프로브는 **운영에 그대로 두면 안 됨**. 정상 Rules 복구 배포 전까지 그룹·파티·Claim 등 쓰기가 대부분 막힌다.

## 정상 복구 시도 (사용자)

로컬 **전체 원본** `firestore.rules`로 되돌린 뒤:

```powershell
firebase deploy --only firestore:rules --project lost-party
```

→ **503 재현**. 업로드 대상은 복원된 전체 파일이 맞으나, 복잡도 한도로 release 실패. 운영은 직전 성공분(프로브)이 유지된다.

## 추정 원인

- 단일 파일에 파티·Claim·운영자·수동 인증·**그룹 membership 전체** Rules가 누적
- 그룹 leave 경로의 `removedActiveGroupId` chunk helper 등 **중첩·분기·OR 평가**가 컴파일 비용을 키움
- Firebase Rules API는 파일 크기·식 복잡도 한도를 공개하지 않으나, **절반 축소 시 성공**으로 복잡도 병목이 거의 확실함

## 수정 방향 (재설계 후 구현)

1. **Rules 분할·중복 제거**
   - 그룹 전용 helper를 최소화하고 OR 체인 순서·중복 `get()` 제거
   - `removedActiveGroupIdChunk*` 등 chunk helper 단순화 또는 데이터 모델 쪽으로 이동 검토
2. **배포 가능 크기 목표**
   - 프로브 성공선(~76KB)보다 여유 있게, **전체 기능을 유지한 채** compile + deploy 성공을 반복 확인
3. **증분 배포 전략**
   - 한 번에 큰 diff를 올리지 않고, 기능 단위로 Rules 변경·배포·실기기 확인
4. **계약 테스트 유지**
   - `test/features/group/data/group_rules_contract_test.dart` 등 문자열 고정 테스트를 리팩터 후에도 갱신

## Task-11a와의 관계

| 항목 | 코드 (`main`) | Rules 배포 |
| --- | --- | --- |
| 일반 멤버 탈퇴 | 구현됨 | leave Rules 포함, **전체 deploy 실패로 미반영** |
| 멤버 표시 Snapshot | 구현됨 | create/join + **self refresh update** 포함, 미반영 |
| 그룹원 목록·상세 UI | 구현됨 | 읽기 Rules는 기존 Task-11과 동일 전제 |

재설계 후: **Rules 축소·배포 성공 → Task-11a 실기기 재검증** 순서를 권장한다.

## 2026-08-31 후속 — Rules만 1차 축소, 배포 미실행

- 사용자 지시로 원본을 `legacy/firestore.before-complexity-20260831.rules.bak`에 별도 복사하고 SHA-256 일치를 확인했다. 기존 사용자 사본은 수정하지 않았다.
- `removedActiveGroupId`의 5개 chunk 및 50개 위치 탐색을 Firebase Rules 기본 `List.removeAll()`로 대체했다. 제거 결과가 정확히 하나일 때만 `[0]`에 접근한다.
- 앱 요청·Firestore 저장 스키마·나머지 권한 검사는 변경하지 않았다. 오래된 생성 스크립트와 템플릿도 같은 native helper로 맞춰 재생성 시 복잡도가 돌아오지 않게 했다.
- 실제 파일 크기: 158,836 → 144,042 bytes (약 9.3% 감소). 컴파일 결과 크기 감소를 측정한 값은 아니다.
- 표적 Flutter 테스트 32개 통과. Emulator 테스트에 50개 그룹의 chunk 경계 10개 위치 탈퇴와 두 ID 제거·변경 없음·ID 삽입 거절을 추가했다.
- 전체 Rules의 Emulator 로딩은 `503 / Network closed for unknown reason`으로 실패했다. 최소 deny-all Rules 대조 검사도 동일하게 실패해 로컬 검증 환경 문제를 별도로 남긴다. 동작 테스트는 시작되지 않았으며, 이 실패를 수정 Rules 복잡도의 증거로 사용하지 않는다.
- 서버 배포·운영 데이터 변경·커밋은 하지 않았다. 배포 성공과 실기기 정상 작동은 미확인이다.
- 공식 연산: https://firebase.google.com/docs/reference/rules/rules.List#removeAll

## 2026-08-31 복잡도 개선 브랜치 커밋 범위

- 브랜치: `codex/rules-complexity-reduction` (main과 분리).
- 위 native 탈퇴 탐색 축소와 표시 Snapshot 갱신 중복 제거만 포함한다. 앱 코드·요청·저장 스키마 변경 없음.
- 표시 갱신의 11개 개별 불변 비교를 기존 `affectedKeys().hasOnly()`로 통합했다. `oldData.keys().hasAll()`로 필수 필드 누락도 계속 거절한다. 호출자·Player/Group ID·직업·숫자 타입·서버 시각 검증은 유지한다.
- 최종 Rules 소스: 143,799 bytes. 백업 158,836 bytes 대비 약 9.5% 감소이며 컴파일 결과 크기는 미측정이다.
- 최종 표적 Flutter 테스트 33개 통과. 정적 문자열 계약·쓰기 계획 검증이며 실제 Rules 허용/거절 검증을 대체하지 않는다.
- 보호 필드 변경·삭제, 새로운 권한 필드 삽입, 타인의 Snapshot 갱신 거절 시나리오를 Emulator 스크립트에 추가했다. Emulator 로딩 환경 문제로 실행 통과를 주장하지 않는다.
- 그룹 탈퇴 전 membership 존재 검증, 요약 변경의 원자적 결합 검증, 계정·캐릭터 쓰기 권한 축소는 별도 보안 보완 작업이다. 이번 최적화로 해결됐다고 간주하지 않는다.
- 백업 2개는 로컬 보존하고 커밋 대상에서 제외한다. 배포·main 병합·푸시는 이번 지시에 포함하지 않는다.

### 관련 문서

- 실행 지시: [`NEXT_WORK.md`](NEXT_WORK.md)
- 작업 이력: [`DEV_LOG.md`](DEV_LOG.md) — Task-11a·Rules 프로브 항목
- 그룹 계약: [`../architecture/FIRESTORE_GROUP_MEMBERSHIP_CONTRACT.md`](../architecture/FIRESTORE_GROUP_MEMBERSHIP_CONTRACT.md)
