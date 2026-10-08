# Firestore Rules 대폭 축소 설계

최초2026-10-07, 전체 영향 재검토2026-10-08. 상태: R1 로컬 후보 검증 중, 평가 한도 회귀로 승격 보류.
운영 성공본36b5920e는10월8일11:16 KST 복원·활성SHA 확인했다. R1 원격 게시/자료 이행은 미실행이다.
운영 조사·복원은 §16, R1 구현과 재개 검증은 §17을 따른다.
§9~15는 후속 전체 영역 검토와 실행 전 게이트다. 앞선 후보를 구현 확정안으로 해석하지 않는다.

사용자 요청은 반복되는 게시 실패를 대상으로 불필요한 검증, 로컬 이관, 구조 축소를 찾는 것이다.
사용자는 **Spark 무료 유지, 앱 업데이트와 데이터 이행 허용**을 설계 전제로 선택했다.
이 선택은 이번 턴의 운영 데이터 변경·구버전 차단·배포 실행 승인이 아니다.
BUG-024 게시 차단 해결에 종속된 설계로 현재 목적 브랜치를 유지한다.

## 1. 결론과 목표

식별자 축약을 반복하는 대신 **서버가 검증해야 하는 저장 표현과 쓰기 형식의 수를 줄인다.**
같은 명령을 원본·멤버·목록·이벤트에서 다시 판정하는 구조를 정리하고,
기존 자료를 보존하면서 구버전 쓰기 경로를 종료한다. 로컬은 표시·추천·입력 안내를 담당한다.

현재 400/503의 내부 원인이 컴파일 용량 초과로 확정된 것은 아니다. 아래 작업은
실측된 Rules 규모와 유지보수 문제를 해결하는 설계이며 게시 성공은 별도 인수 조건이다.

- 구조 축소 목표: 현재 compact source 151,427 bytes 대비 **30% 이상 감소**를 잠정 목표로 둔다.
  이는 예상 절감량이나 구현 보장이 아니다. 1~2개 작은 검사 삭제로 대폭 축소 완료를 선언하지 않는다.
- 게시 여유 목표: 성공한 동일 API/V1 executable 직렬화 측정값을 이전 242,981 bytes와 비교한다.
  잠정 내부 목표는 190,000 bytes 이하이며 공식 compiled 크기와 동일하다고 단정하지 않는다.
  실제 적용 성공·경고 0·활성 source SHA 일치가 필수다. 소스 감소율로 compiled 감소율을 추정하지 않는다.
- 기능: 권한, 현재 소유권 차수, 참가/완료 배타성, 8인 원자 전환, 이전 완료 이력 보존.
- 무료 제약: Functions, Cloud Run, 결제 전환, 별도 신뢰 서버 도입은 현재 안에 포함하지 않는다.

## 2. 실제 기준과 조사 결과

기준은 `firestore.rules` SHA256 `408f163fc6bf6f06d8a7a628da2e1b2bdd2747d36936d7b2aee995c161e53793`다.
배포 경로는 `firebase.json`의 `firestore.rules`, 기본 프로젝트는 `lost-party`다.
최초 설계 당시 마지막 보존 조회는 성공본36b5920e였다. 10월8일 후속 조회에서 운영본 변경을 확인했다(§16).

`tools/rules_audit.mjs`의 로컬 정적 조사: 151,427 bytes, 함수296, match34, allow118,
최대 helper 깊이6, 정적 allow 호출 그래프 미도달 함수0, 본문 문자열 완전 중복0.
미도달0은 논리적으로 도달 불가능한 분기나 의미상 중복이 없다는 증명이 아니다.

아래 수치는 **현재 compact 함수 선언의 소스 bytes**다. 제거 가능량·실행 비용·compiled 크기가 아니다.

| 독립된 선언 위치 | 함수 수 | bytes |
|---|---:|---:|
| 최상위 공통 함수 | 108 | 46,294 |
| 모집 원본 | 27 | 13,221 |
| 모집 멤버 | 18 | 9,565 |
| raidStates | 16 | 8,624 |
| 그룹 원본 | 22 | 8,439 |
| 수동 인증 요청 | 15 | 7,448 |
| 그룹 raidListings | 12 | 5,374 |
| 그룹 멤버 | 11 | 5,322 |
| 구 assignment + weekly Claim 내부 | 4 | 2,398 |

별도 이름군 측정: `bug24/sparkPrep/seal` 25함수13,914 bytes, `de`47함수21,182 bytes,
Event17함수8,262 bytes, Listing14함수5,829 bytes. 이름군은 위 선언 위치와 겹치므로 합산하지 않는다.
모든 `de` 함수가 구데이터 전용이거나 삭제 대상이라는 뜻도 아니다.
근거: ignored `coverage/rules-audit/{source-inventory,reduction-scope-inventory}.json`.
가독본/이름 대응은 `coverage/rules-executable/review/{readable.rules,symbols.json}`이며,
실제 수정은 `tools/integrate_roster_rules.mjs`의 생성 입력/변환을 통해 수행해야 한다.

확인된 중요 사실:

1. 표시용 그룹 스펙 대조는 이미 축소됐고 당시 절감은1,053 bytes였다. 같은 일을 다시 제안하지 않는다.
2. `PartyRaidListingSyncPlan`은 원본 전체 복사를 쓰지만 lifecycle은 부분 patch,
   visibility는 최소 문서를 쓴다. Rules가 이 여러 형식을 명령별로 모두 지원한다.
3. `FirestorePartyReadRepository._toMergedPublicPage`는 listing을 직접 화면으로 변환한다.
   원본 재조회 없이 listing만 사용하는 화면이 있어 검증 삭제/참조만 저장으로 즉시 바꿀 수 없다.
4. `app_router.dart`의 실제 DI는 atomic 명령과 `FirestoreWeeklyRaidStatusCommandRepository`를 쓴다.
   하지만 `PartyRaidStateOccupancyInspector`와 개인 완료 명령은 현재도 구 Claim/assignment를 읽는다.
5. `PartyEventMapper.sharedHistoryCharacterId`는 completionTargets로 과거 완료 캐릭터를 복원한다.
   이벤트를 현재 방 상태에서만 로컬 재구성하면 캐릭터 변경 후 과거 이력이 바뀐다.
6. BUG-024의 준비 이벤트는 이전/새 state·Claim 불변 검증을 분담한다.
   이벤트가 UI 자료라는 이유만으로 그 Rules를 제거하면 보존 검사가 사라질 수 있다.

## 3. 줄일 항목과 남길 항목

| 항목 | 설계 판정 | 필요한 대체·한계 |
|---|---|---|
| 안내문, 표시 포맷, 정렬, 추천 자리, 오류 문구 | 로컬 책임 | 원래부터 로컬인 코드를 Rules 절감으로 계산하지 않음 |
| 레벨/전투력 등 표시 Snapshot의 원본과 동일성 | 추가 제거 후보, 효과 작음 | 실제 권한/자격 소비가 없는 필드만. 최소 타입·허용 키·크기와 안전한 mapper 유지 |
| 그룹 applicantStats/blockedPlayers의 표시 수치 복사 비교 | 소규모 후보 | 신청 횟수·차단 대상/주체·관계·상태 검사는 서버 유지. 관계 조회 자체가 필요하므로 읽기 절감 보장 없음 |
| 그룹 listing의 명령별 세부 검증 | 첫 구조 축소 대상 | 모든 writer를 하나의 canonical projection으로 통일하고 원본과 동등성만 검증 |
| 원본·member·event에서 동일 명령 재검증 | 책임 단일화 후보 | 필수 쓰기 결합을 입증하고 파생 문서는 검증된 원본에 정확히 결합 |
| weekly Claim/assignment의 신규 쓰기·호환 분기 | 이행 후 제거 | 최신 writer 전환, 활성 자료 이행·대조, 구버전 쓰기 서버 차단이 선행 |
| 완료/준비/고아 정리의 여러 이벤트 생성 형식 | 공통 봉투로 통일 | immutable 이력·정확한 audience·명령 provenance·완료 명단 보존 |
| 여러 target 배열의 중복 identity/멤버십 검사 | 저장 계약 변경 후보 | 하나의 canonical target 표현과 직접 조회. 모든 대상 쓰기 검사는 유지 |
| 인증 UID→Player, 운영자/그룹장/방장 권한 | 서버 유지 | 앱 조건문으로 이동하지 않음 |
| Character 현재 소유자·ownershipRevision | 서버 유지 | 클라이언트의 인증됨 boolean/오래된 snapshot을 신뢰하지 않음 |
| 타인 원장 쓰기, 중복 참가, 완료 충돌, revision, 필수 쓰기 | 서버 유지 | 위조 요청·경합·부분 요청을 앱만으로 막을 수 없음 |
| audience, groupId, visibility, member IDs, classKey, role | 표시값으로 취급 금지 | 읽기 권한·구성·명령 판정에 사용. 특히 classNameSnapshot이 classKey로 사용됨 |

현재 보석/빌드 세부 판정은 앱에 있고 Rules에는 허용필드/최소형식 위주다.
여기에 큰 검증 덩어리가 남아 있다는 근거는 없다. 명칭이 Snapshot이라는 이유로 일괄 삭제하지 않는다.

## 4. R1 — 그룹 목록 저장·검증 통일 (첫 구현 후보)

### 현재 문제와 선택

`groups/{groupId}/raidListings/{recruitmentId}`의 create/update/delete에 생성·backfill·
완료·전환·개인완료·제거·고아정리·공개범위별 검사와 필드 목록이 중복된다.
`validAtomicMemberRemovalListingUpdate`는 모집 제거 정책 자체도 재실행한다.

첫 후보는 현재 full-copy writer와 직접 목록 표시를 활용하는 **원본의 canonical 전체 복사**다.
원본에 추가될 비공개 필드까지 자동 공개하는 정책은 아니다. 현재 원본 필드의 공개범위를 확인하고
비공개 필드가 있으면 명시적 공개 projection을 사용한다. 이 검토 없이 전체 복사를 확대하지 않는다.
listing 자체 삭제나 포인터만 저장은 우선안에서 제외한다. 후자는 그룹당 원본 추가 읽기/구독,
페이지 정렬·누락·오프라인 동작까지 바뀌므로 더 큰 작업이다.

### 쓰기·읽기 계약

- 생성, 참가, 제거, 캐릭터/자리 변경, 준비 변경, 전환 등 남아야 하는 listing은
  각 WritePlan의 **최종 모집 원본**에서 같은 함수를 통해 완전 set한다. 부분 patch 혼용 종료.
- identity는 경로와 원본의 recruitmentId/groupId로 고정하고 group 공개범위를 보존한다.
- 원본의 revision을 기준으로 하고 별도 sourceRevision 중복 필드는 reader 조사 후 종료한다.
- 쓰기 Rules는 허용된 actor, 같은 원본의 실제 전환, groupId/visibility, projection 일치로 제한한다.
  `getAfter`의 lastCommandType만 보고 허용하지 않는다. before/after revision 증가와
  서버 시각, 필요한 binding을 통해 같은 요청의 원본 쓰기를 강제한다.
- 원본 전환의 권한·구성·소유권은 원본/직접 대상의 Rules가 검증한다. listing은 그 정책을 재실행하지 않는다.
- 원본 Rules에서 명령별 listing의 필수 존재·동등성 검사를 유지해 원본만 변경한 누락 요청을 거절한다.
  특히 BUG-024 준비 변경은 기존 listing 누락 시 거절하는 현재 계약을 유지한다.
  모든 명령에 무조건 누락 listing 생성/backfill을 적용하지 않는다.
  기존 8인 접근 예산을 초과하면 검사 추가로 우회하지 않고 책임 배치를 다시 설계한다.
- backfill은 원본 무변경 예외이며 현재 권한을 가진 참가자만 canonical 복사를 생성한다.
  일반 명령 branch와 분리하고 원본/멤버 권한, 종료 상태, 다른 그룹 ID 위조를 검사한다.
- delete는 종료·공개 전환 등 실제 계약별 결과를 하나의 명시적 표로 고정한다.
  반복방 완료 listing 유지, 1회성 종료 삭제, 공개 전환, 기존 지연 잔여 listing을 구분한다.
- 기존 listing을 읽는 mapper는 구형을 읽되 신규 writer는 단일 형식만 만든다.
  모든 필요한 필드가 같은지 확인한 뒤에만 기존 생성/목록 mapper를 재사용한다.

### 완료 조건과 예상 효과의 한계

대상 함수 이름군은 소스5,829 bytes(약3.8%)이며 공통 함수 호출/allow도 연결돼 있다.
전부 지울 수 없고 canonical validator가 필요하므로 순감소는 구현 후 측정한다.
R1만으로30% 축소나 게시 성공을 약속하지 않는다. 8인 권한·원자성·동등 목록이 깨지면 채택하지 않는다.
원본 기반 목록만으로 단순화하는 후속안과 혼합하지 않는다.

## 5. R2 — 구버전 쓰기 종료와 원장 이행

목적은 새 쓰기에서 `raidStates`와 legacy Claim/assignment를 함께 고려해야 하는 이유를 없애는 것이다.
단순히 legacy 이름의 Rules를 지우거나 데이터가 없다고 가정하지 않는다.

1. 로컬 call site·DI·WritePlan을 표로 고정한다. 공개APK1.1.1의 writer도 해당 태그와 대조한다.
2. 별도 승인한 운영 읽기 조사에서 schema/현재 주차/소유권 차수별 구 assignment·Claim을 집계한다.
   완료 이력과 현재 참가 차단에 필요한 자료를 구분한다. 전체 원시 개인정보를 문서에 남기지 않는다.
3. 최신 앱이 새 명령만 쓰고, 서버가 구 create/update를 거절하는 전환 조건을 만든다.
   앱 version 문자열은 위조 가능하므로 서버의 실제 허용 스키마/명령으로 차단한다.
4. 이행은 권한 있는 일회성 관리 도구를 별도 승인해 수행한다. 조회·dry-run 계획과 실제 쓰기를 분리한다.
   stable path, 현재 소유권 차수, 같은 raidId의 난이도 공유, revision을 대조한다.
   기존 유효 state가 있으면 덮어쓰지 않고 충돌 목록으로 분리한다.
5. 중단/재시작 가능한 checkpoint와 건별 전후 해시·분류를 남긴다. 처리 완료율뿐 아니라
   현재 점유/완료가 새 원장에 보존됐는지 대조한다. 복구는 신규 상태와 경합을 검사하며 역복사로 덮지 않는다.
6. 신규 legacy 쓰기가 닫힌 상태에서 마지막 잔여 자료를 확인한다. 구형 단말의 대기 쓰기도 Rules가 거절해야 한다.
7. 새 원장으로 보존이 확인된 범위에서만 legacy fallback 읽기와 검사, 더 이상 필요한 호출자가 없는 helper를 제거한다.
   원시 과거 데이터는 우선 읽기 전용 보존한다. 모든 자료를 삭제할 필요는 없다.

신규 앱 전환 안내와 짧은 쓰기 중단 구간은 이행 상세 설계에서 확정한다.
현재 허용 범위는 이행 설계이며 무공지 차단·자동 일괄 삭제를 하지 않는다.
기존 데이터를 읽을 수 있어야 한다는 요구와 구버전 앱이 계속 쓸 수 있어야 한다는 요구를 분리한다.
직접 legacy 함수는 작다. 모든 seal/BUG-024 검사까지 없어질 것으로 계산하지 않는다.
다른 방 점유·현재 완료·소유권 검사는 단일 raidState에서도 필요하다.

## 6. R3 — 원본 중심 명령과 파생 자료 검증

대폭 축소의 핵심 후보지만 R1/R2와 동시에 구현하지 않는다.

- 각 명령을 `actor / 변경 허용 필드 / 직접 대상 / 필수 동시 쓰기 / 남길 과거 상태` 표로 고정한다.
  원본에서 명령 권한과 집계 변화, 대상에서 자기 identity·상태 전이·소유권을 검증한다.
- member/listing/event는 이미 검증된 **같은 요청의 원본 전환**에 결합한다.
  원본이 대상 쓰기를 요구하고 대상이 원본을 확인하는 구조는 권한 검사의 중복과 다르다.
  양쪽 결합을 모두 지워 순환 신뢰만 남기지 않는다.
- 입장/퇴장/승계/개인 완료/소유권 정리의 공통 집계 변화는 한 번 계산·검증하되,
  actor 자격과 의미가 다른 경계는 분리한다. 공통 helper 추출만으로 compiled 감소를 주장하지 않는다.
- 모든 명령에 명시적인 단일 command type·revision·ID를 연결하고 지금의 긴 OR/fallback을
  상호 배타적 분기로 바꾼다. unknown type, 이전 marker 재사용, timestamp만 바꾼 요청은 거절한다.
- partySlots/memberPlayerIds/raidStateTargets/commandTargets의 identity 중복을 줄이는 새 구조를 검토한다.
  예: 검증된 deterministic target key→값 map으로 대상 포함을 직접 검사한다.
  중복 키 충돌·타인 대상·목표 누락을 거절하고 **전체 완료 시 최대8개 getAfter 검사 자체는 유지**한다.
  map 전환만으로 모든 항목 검사가 없어지는 것은 아니다.
- 공유 이벤트는 공통 immutable 봉투 + 명령별 최소 payload로 통일한다.
  audience와 과거 완료 character/raid/cycle는 서버 증거로 남기고, 이름·문구 렌더링은 로컬로 한다.
  `sparkPrepRecords` 같은 보존 책임은 대상/원본으로 이전해 필수 실행을 입증하기 전 제거하지 않는다.
- 그룹 관계의 양방향 복제도 후속 후보지만 그룹 최대 가입수·읽기 권한·초대 수락 근거를 잃지 않아야 한다.
  현 단계에서는 별도 그룹 재설계로 범위를 늘리지 않는다.

크기 큰 함수가 곧 불필요한 함수는 아니다. `deLeaderCleanupAggregate`,
`validPersonalCompletionRecruitmentUpdate`, `atomicValidLifecycleState`는 상위 조사 대상이며,
승계·마지막1인·완료 보존 조건을 없애서 줄이는 안은 선택하지 않는다.

## 7. 진행 순서·전환·검증

| 단계 | 산출물·종료 조건 | 실행 범위 |
|---|---|---|
| 설계(현재) | 규모/후보/경계/작업순서 문서, 사용자 제약 반영 | 로컬 읽기·문서만 |
| R1 상세 명세·로컬 후보 | 모든 listing writer/reader의 필드표, 단일 형식, 삭제/누락/구형 요청 결과표, 순감소 실측 | 구현 지시 후 로컬, 원격0 |
| R2 사전 조사·이행 명세 | 현재/공개 앱 writer, 원격 자료 분류, 차단·충돌·복구·점검 시점 확정 | 원격 조사는 대상·범위를 먼저 명시 |
| R2 로컬 이행 도구·경계 검증 | 샘플 정상/충돌/중단/재실행/구버전 대기쓰기 검증, 실행 계획 검토 가능 | 운영 쓰기0 |
| R3 단일 명령군 proof | 중복 책임 제거 또는 target 표현 하나만 변경, 크기/권한/접근 예산 비교 | 로컬 검증, 전체 이중 validator 누적 금지 |
| 최종 전환 묶음 | 앱·Rules·이행 순서의 모든 중간 상태 안전성, rollback 호환성, 최종 전체 Rules 검증 | 실행 승인 후 제한 게시/이행 |
| 운영 인수 | 경고0·활성 SHA 일치·사용자 실기기 확인·동기화 | 이전 실패본 무변경 반복 없음 |

R1/R2/R3는 의존 순서이며 각각 끝날 때 무조건 게시한다는 뜻이 아니다.
구형/신형 전체 검증기를 동시에 싣는 과도기는 더 커질 수 있으므로 가장 큰 전환본까지 크기를 측정한다.
새 스키마를 쓴 뒤 옛 Rules만 복원하는 것을 rollback으로 취급하지 않는다. 구형 읽기 지원 앱,
신규쓰기 차단, 데이터 호환과 사용자 안내를 함께 검토한다. 활성 원장을 처리 도중 비워 두지 않는다.

권한 회귀는 최대8인 대표 사례와 서로 다른 상태 전이만 검사한다:

- 타인/비멤버/소유권 이전/권한 상실, 다른 groupId·roomId·target·audience 위조.
- 원본만 쓰기, listing/member/event/state 하나 누락, extra 대상, 구 revision·command 재사용.
- 준비 A→B→C 후 이전 완료 보존, 다른 방 active/현재 완료/손상 state 거절, 인증 부분 성공 후 재진입.
- 전체 완료·전환8인, 개인 완료·마지막1인 해산·승계, 빈자리 이동·교환·공개범위 전환.
- listing 누락/backfill/종료 잔여자료, 구형 문서 read, 구형 writer 거절, 이행 중복/충돌/중단 재시작.
- 한도 오류를 정상적인 권한 거절로 인정하지 않는다. request 평가1,000식, 각쓰기10/전체20 접근 한도를 함께 확인한다.

재사용할 근거: `tools/party_group_cutover_rules_test.mjs`, 기존 BUG-024 runtime/완료역할/8인/수동/개인
회귀 묶음과 관련 WritePlan/Domain 테스트. 구조 변경 후의 신규 검증은 최종 후보에 모아 실행한다.
스키마·Router/DI 영향이 있는 최종 변경은 전체 Flutter test/analyze가 필요하다.
기존110실패/분석51건 기록을 통과로 바꾸지 않고 동일 기준과 신규 회귀를 구분한다.
실기기 정상 UI 확인은 사용자가 수행한다. 이번 설계에서는 테스트를 재실행하지 않았다.

게시 실험은 별도 승인한 격리 프로젝트에서 단계별1회·자동 재시도0으로 수행한다.
컴파일 검사만 통과하면 완료가 아니다. 저장 소스와 활성 release의 SHA를 확인한다.
R1/R2의 실측이 목표에 크게 못 미치면 작은 삭제를 반복하지 않고 R3 설계의 가능성을 판정한다.
Spark 제약에서 목표를 충족하지 못하면 미달량과 필요한 제품 정책 변경을 보고한다.
신뢰 서버나 기능 축소를 자동 채택하지 않는다. 서버의 상세 400 원인은 지원용 진단 자료로 병행 보존한다.

## 8. 근거 위치와 공식 제약

- 생성: `tools/integrate_roster_rules.mjs`, `rules_executable_compact.mjs`, `rules_group_display_candidate.mjs`.
- 실제 연결: `lib/app/router/app_router.dart`.
- 목록: `lib/features/recruitment_list/data/mappers/party_raid_listing_sync.dart`, `party_atomic_write_plan.dart`,
  `data/repositories/firestore_party_read_repository.dart`, `firestore_party_raid_listing_backfill.dart`.
- 원장: `lib/features/recruitment_list/data/repositories/party_raid_state_occupancy_inspector.dart`,
  `lib/features/account/data/repositories/firestore_weekly_raid_status_command_repository.dart`.
- 이력: `lib/features/recruitment_list/data/mappers/party_event_mapper.dart`.
- 기존 계약: `PARTY_GROUP_COMMAND_SCALABILITY_REDESIGN.md`, `RECURRING_CYCLE_SPARK_ALTERNATIVE_DESIGN.md`.
- 현재 새 설계는 기존 계약을 즉시 변경하지 않는다. 구현 단계에서 선택한 변경만 해당 계약에 반영한다.
- [공식 크기·평가·접근 제한](https://firebase.google.com/docs/firestore/quotas#security_rules).
- [getAfter와 원자 쓰기 검증](https://firebase.google.com/docs/firestore/security/rules-conditions).
- [쿼리의 Rules는 결과 필터가 아님](https://firebase.google.com/docs/firestore/security/rules-query).
- [필드 허용 목록·diff·타입 검사](https://firebase.google.com/docs/firestore/security/rules-fields).

파일 분리 후 하나로 합치는 것은 유지보수 개선이며 단일 게시본 한도 해결이 아니다.
클라이언트 자체 검사를 공유 데이터의 서버 권한 검사 대신 사용하지 않는다.

## 9. 2026-10-08 재검토 범위·기존 버그와의 관계

이번 검토는 추적본408f163f의 전체34 match(루트 포함), 허용 조건이 있는33개 경로,
118 allow의 경계를 기준으로 영역을 분류하고, 관련 앱 DI/Repository/mapper와 계약을 대조했다.
모든 함수의 의미 동등성을 증명한 보안 감사나 운영 데이터 전수 조사가 아니다.
서버 활성 상태·실기기·새 후보의 크기/권한은 이번 턴에서 재검증하지 않았다.
앞선 audit 수치는 같은 SHA에서 확보한 결과를 재사용했다.

### 버그·회귀·후속 과제의 구분

| 대상 | 현 상태와 원인 근거 | 축소 작업에서 지킬 완료 조건 |
|---|---|---|
| BUG-024 완료 반복방 준비 변경 | 수정 전 atomic 경로가 active state만 허용해 completed도 notFound. 현재 전용 앱/Rules는 구현됐으나 운영 활성화 실패 | 완료 상태에서 본인 A→B→C 변경, 이번 주 완료 캐릭터 선택, 유효 빈자리 이동. 이전/새 state·Claim·완료 시각·당시 명단 보존 |
| BUG-024 이후 다음 주 전환 | 준비 변경은 예약/점유가 아님. 전환 시 현재 소유권·점유·완료 재검증 필요 | 최신 구성으로 최대8인 한 번에 전환. 한 명이라도 충돌하면 방/모든 state 불변. 인증 일부만 남은 재진입도 안전 |
| BUG-023 전체 완료 실패 | 변경 writer의 role 누락. 실제 두 방 완료 성공으로 종료 | role 저장과 허용된 과거 누락 보완 유지. role 불일치/타인·다른 방 기록을 자동 수선하지 않음 |
| BUG-022 그룹 count/추방 listing/만료1회성 | 각 수정·실기기 성공 이력 있음 | activeRecruitmentCount·멤버 제거·종료된 원장 재사용 보호 유지. 원본/복제 revision을 혼동하지 않음 |
| 기존 자리 이동 한도 실패 | 기존 validator 직접 dispatch로 보완 | R3 공통화가 긴 OR 전체 평가를 부활시키지 않도록8인 경계 확인 |
| 소유권 이전 후 활성 고아 관계·기존 Player 복구 | 별도 미완료 후속 설계 | Rules 축소로 해결됐다고 기록하지 않음. 기존 정리 기능과 구별, 자동 관계 승계/전체 삭제 없음 |
| 같은 직업 자리 교환 관찰 | 재가입 뒤 성공, 원인 미확정 | 재발 시 조사할 항목 유지. 추측 수정/기능 삭제의 근거로 사용하지 않음 |

**종료는 세 개의 게이트다:** 구조 축소/회귀 검증 → 최종 Rules 운영 활성화 →
두 실제 방의 사용자 준비 변경·다른 기기 반영·과거 이력·다음 주 전환/전체 완료 확인.
게시 성공만으로 BUG-024를 닫거나, 소스 감소만으로 게시 장애를 닫지 않는다.
축소가 오래 걸려도 정상 기능을 끄는 임시 Rules나 새 앱만 먼저 운영 배포하지 않는다.

## 10. 전체 데이터 영역의 책임·앱 영향 지도

경로는 `/databases/{database}/documents` 아래다. P=`players/{playerId}`,
R=`recruitments/{recruitmentId}`, G=`groups/{groupId}`로 줄여 썼다.
`유지`는 현재 기능의 계약을 유지한다는 판단이지 현재 모든 Rules가 충분히 안전하다는 인증이 아니다.

| 영역/경로 | 현재 앱 연결·읽기/쓰기 책임 | 축소·로컬화 판단 | 잘못 줄였을 때 영향·필수 보호 |
|---|---|---|---|
| authBindings, players | FirestorePlayerBindingStore, PlayerBindingRepositoryImpl. 본인 binding get/초기 Player와 원자 생성, 운영자 list, lastSeen 갱신 | 핵심 유지. lastSeen backfill은 기존 자료 조사 뒤 별도 종료 후보 | 다른 Player 연결, 새 가입 실패, 운영 화면 누락. binding list/update 금지와 생성 결합 보존 |
| operatorAssignments | 본인 권한 get, 관리자가 배치한 운영자 상태 참조, 클라이언트 쓰기 거절 | 로컬화/삭제 제외 | UI 운영자 플래그만으로 수동 승인 가능해지는 것 방지 |
| gameAccounts, characters, characterIdentityClaims, playerGameAccounts | LocalGameAccountVerificationGateway가 원격 식별자 재사용·소유권 차수·Character·양쪽 관계 저장. 대표 캐릭터 동기화 | identity/차수/대표 소유·cooldown 유지. 기존 신뢰 한계는 아래 별도 기록 | 재인증 때 새 ID로 중복 생성, 다른 사람 관계 승계, 후보·대표 캐릭터 손실 |
| accountVerificationChallenges, activeAccountVerificationChallenges | Rules 전면 거절, 현재 장비 challenge는 앱 메모리 | 이미 로컬. deny 블록 삭제를 절감 주력으로 삼지 않음 | 존재하지 않는 서버 검증을 있다고 오인하거나 미래 catch-all이 허용하지 않게 유지 |
| manualVerificationRequests, manualVerificationBlocks | FirestoreManualVerificationRepository. 요청·운영 검토·방어·기한 이전, requester/operator별 조회 | 유지. 수동 인증 기능 제거는 현재 승인 범위 밖 | 인증 금지 우회,24시간 방어 소실,중복 이전. 서버 시각·상태·이전 owner 결합 보존 |
| P/events | 수동 인증 분쟁 알림, 권한/기한 payload 검증 | partyEvents와 같은 이름의 알림이라고 일괄 삭제 금지 | 이전 소유자 방어 안내 소실, 타인 알림 주입·열람 |
| P/characterActivity | FirestoreActivityCharactersRepository. 본인 쓰기, 활성 binding 읽기, 타 화면 후보 공급 | 서버 저장 유지. 로컬 선택 초안·정렬만 로컬 | 타 기기/그룹 후보 누락, 대표가 활동목록에서 빠짐,15인 저장 접근한도 회귀 |
| P/activeRaidAssignments | 신규 create/update 거절, 기존 점유 읽기/개인완료·stale 삭제 호환 | R2 이행 후 호환 제거 후보 | 기존 활성 점유를 잃어 이중 참가하거나 다른 방 점유를 삭제 |
| P/weeklyRaidClaims | 현재도 점유 inspector/개인완료가 읽고 Rules는 수동 Claim 생성·삭제를 허용 | 신규 writer 사용 여부와 자료 이행 후 폐쇄 | 같은 주차 재참가 허용, 개인완료 해제 불가, 구단말이 계속 구원장 생성 |
| P/raidStates | 현재 참가·완료·stub·전환 원장, 본인/허용 명령별 접근 | 유지. R2 후 중복 자료 경유만 제거 | 두 방 참가,완료 덮어쓰기,타인 private 원장 노출,부분8인 전환 |
| P/groupMembershipState | 가입수·activeGroupIds, 목록 구독 경로 제공 | 유지. 캐시로 권한 원장 대체 금지 |50개 제한 경쟁,그룹 목록/모집 목록 누락 |
| P/groupRelations | FirestoreGroupReadRepository의 내그룹·요청 목록 | 표시 Snapshot 대조 소규모 축소 후보, ID/status/sourceRevision 유지 | 초대/가입 현황 누락·유령그룹·다른 그룹으로 링크 변경 |
| partyEvents | audience 쿼리→PartyEventMapper→Drift 이력/receipt | 문구·배지·읽음 로컬 유지, immutable 사건 증거는 서버 유지 | 재설치/다른 기기 이력 소실, A→B 변경이 과거 완료자로 소급, 수신자 유출 |
| R 원본 | 공개/본인 get/list와 atomic 명령 원본. revision/구성/권한/주차/집계 | R3 책임 단일화 대상 | 단독 원본 변경,정원·직업·역할·주차 위조. 쿼리 필드/인덱스도 함께 검토 |
| R/members | 상세 표시·승인권·직접 대상 변경/삭제 | 파생 표시와 권한 필드를 분리. 통째 로컬화/삭제 제외 | 상세 명단 불일치·타인 승인권 변경·승계 실패 |
| R/applications | 신청/재신청/철회/승인/거절,Player ID당 문서1개 | 공통 상태전이 후보, 로컬 전용 제외 | 중복 신청·만료/완료 신청 승인·pending count 불일치 |
| R/applications/votes | 구형 읽기 허용, 신규 쓰기 거절 | 이미 폐쇄된 쓰기. 읽기 호환은 소비·자료 조사 후 종료 | 과거 상세 접근 실패. 작은 deny 블록 삭제는 대폭 축소 효과 없음 |
| R/slots, R/cycles | 구형 읽기, 신규 쓰기 거절. 현재 원본 partySlots/공유이력 사용 | 이행 후 읽기 제거 후보, 자동 데이터 삭제 없음 | 구형 자료 화면 누락·과거 회차 소실 |
| G 원본 | 생성·명칭·가입/탈퇴·승계·soft delete·activeRecruitmentCount | 집계·책임자·검색 경계 유지 | 활성 모집 중 그룹 해산,가입수/정원 경쟁,검색 누락 |
| G/members | 그룹원만 list,초대/승인/코드별 create,대표표시 갱신·승계·탈퇴 | 표시용 원본 대조 일부는 이미 제거. 추가효과 작음 | 그룹장 role 분리,소유권 상실한 대표를 자격으로 오인 |
| G/raidListings | 그룹원 list→모집 카드 직접 변환. full/partial/minimal writer 혼용 | R1 통일. 포인터화는 별도 읽기 비용·조회 설계 필요 | 빈자리/주차/완료 상태 지연,누락 방 재노출,공개 전환 잔류 |
| G/joinRelations | 초대/신청/코드 수락,본인 get·그룹원 list | 상태전이 유지, 표시값 중복만 조사 | 거절·만료 요청 재사용,금지 사용자 가입,relation/member 분리 |
| G/applicantStats | 본인/그룹장 get·그룹장 list,신청 시 누적 | 이름/스펙 표시 대조 후보. applicationAttempt 유지 | Character 바꿔 신청횟수 초기화,관리 이력 위조 |
| G/blockedPlayers | 그룹장 관리,가입 제한 | 표시 수치 대조만 후보. ID/권한/차단 유지 | 캐릭터 변경으로 차단 우회,차단 목록 유출 |
| groupJoinCodes | ID를 아는 active binding get, list 금지,그룹 상태와 코드 생성/삭제 결합 | 유지. 코드 형식 UX만 로컬 | 무효 코드 가입,코드 열거,폐기와 그룹 flag 불일치 |
| recursive applications list | collectionGroup('applications')의 본인·현재 주차 조회, mapper 이후 approved 제외 | 상위 개별 get/list와 함께 유지·검증 | 재귀 allow가 다른 경로의 제약을 우회하거나 본인 신청목록이 전부 거절 |

### 인증 신뢰 경계의 정정

현재 Rules의 `gameAccounts` 생성/변경은 signedIn+차수 관계 검사이고,
`characterIdentityClaims`는 signedIn read/write이며 `playerGameAccounts`도 대표 변경 이외에는
넓은 signedIn 경로가 있다. 장비 API 검증은 `LocalGameAccountVerificationGateway`가 수행한다.
따라서 현재 앱을 **게임 소유 증명까지 신뢰 서버가 검증하는 구조**로 설명하면 안 된다.
파티 Rules가 현재 저장된 소유권/차수를 대조한다는 사실과 그 원장의 생성 신뢰 수준은 별개다.
`GAME_ACCOUNT_VERIFICATION_CONTRACT.md` §10의 서버 전용 원칙과 초기 Spark 예외는
현재 구현 기준으로 구분해 읽는다. 향후 보강은 별도 과제이며 이번 축소에서 더 넓히지 않는다.

### 확인한 실행 근거

위 표는 가독본의 match/allow 및 `lib/app/router/app_router.dart`와 다음 경로를 대조했다.
기존 source audit의 전체 allow 목록은 같은 SHA에서 재사용했고 검사 실행 통과를 새로 주장하지 않는다.

- `lib/features/player/data/datasources/firestore_player_binding_store.dart`
- `lib/features/account/data/gateways/local_game_account_verification_gateway.dart`
- `lib/features/account/data/repositories/firestore_activity_characters_repository.dart`
- `lib/features/account/data/repositories/firestore_weekly_raid_status_command_repository.dart`
- `lib/features/manual_verification/data/firestore_manual_verification_repository.dart`
- `lib/features/group/data/repositories/firestore_group_{read,join_command,application_command,join_code_command}_repository.dart`
- `lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart`
- `lib/features/recruitment_list/data/repositories/party_raid_state_occupancy_inspector.dart`
- `lib/features/raid_status/data/services/firestore_party_event_sync_service.dart`
- `lib/features/recruitment_list/data/mappers/{party_atomic_write_plan,party_raid_listing_sync,party_event_mapper}.dart`

공개v1.1.1의 app_router도 atomic writer와 WeeklyRaidStatusCommand를 연결했다.
따라서 공개판이 모두 legacy 쓰기를 한다고 가정하지 않는다. 더 오래된 앱과 명령별 경로,
실제 자료 잔존은 아직 미확인이며 R2 사전 조사에서 확정한다.

## 11. 로컬 이관·삭제의 제품 판단

아래는 구현 전 후보 판정이며 기능 폐지의 실행 승인이 아니다.

| 판단 | 구체 대상 | 사용자 영향·채택 조건 |
|---|---|---|
| 로컬 유지 | 검색/정렬, 후보 추천, 입력 안내, Build 오류 계산, 읽음 receipt, 표시 설정 | 대부분 이미 로컬. Rules 축소 실적에 중복 산정하지 않음. 재설치 시 설정/읽음이 초기화되는 정책 명시 |
| 조건부 로컬 이관 | 표시만을 위한 이름/레벨/전투력의 원본 동일성 대조 | 정상 앱은 기존 값을 저장. 변조 앱의 표시 오정보를 허용하게 되는 계약 변경이며 동등 리팩터링이 아님. 권한/입장 조건에 쓰이지 않는지 확인 |
| 삭제 후보 | 동일 projection의 명령별 검증, 다른 필수 write에서 확실히 실행하는 중복 검사 | 화면 기능 유지. 단독/누락/추가 write가 거절됨을 증명해야 함 |
| 이행 후 삭제 후보 | legacy 신규 write, 구형 target 변환, 호출자가 없어진 fallback/helper | 구형 앱 일부 조작 거절. 업데이트 안내·자료 이행 필요. 기존 자료 열람과 구별 |
| 현재 기능 삭제 미채택 | 활동 Character 동기화, 그룹 목록, 개인 완료, 신청제, 초대/코드, 수동 인증, 권한 승계 | 현재 주요 기능을 잃음. 대폭 축소 목표 미달이어도 자동 폐지하지 않음 |
| 로컬화 미채택 | 공유 완료 이력, 소유권, membership, 차단, 공유 정원/집계, 주간 점유 | 다기기 동기화와 위조 요청 보호를 잃음. 로컬 확인은 서버 검증을 대체하지 않음 |

제품 기능을 삭제하지 않고도 저장의 중복 표현·쓰기 호환·검증 책임을 줄일 여지는 있다.
다만 실측 전 반감 등을 약속하지 않는다.30%/190000bytes는 잠정 목표이며 미달량과 근거를 보고한다.
그룹·인증·전체 완료의 폐지를 용량 대책으로 임의 선택하지 않는다.

## 12. 부작용 목록과 대책

| 변경 후보 | 예상 부작용 | 구현 전/채택 시 대책 |
|---|---|---|
| listing 전체 set | 옛 원본 복사가 최신 모집을 덮어씀, serverTimestamp/숫자 increment 미해결 값 혼입 | Transaction의 최신 원본+확정 patch로 조립, getAfter 일치. 로컬 cache를 원본으로 쓰지 않음 |
| listing 형식 통일 | sourceRevision 의존 reader 오류, 주최자/만석/다음 주 표시 변화 | 모든 reader 필드표·구자료 읽기·revision 의미 확정. 근거 없이 필드 이름을 일괄 통일하지 않음 |
| 전체 projection | 미래 비공개 필드까지 그룹에 복제, 통신/저장량 증가 | 현재 독자 범위·필드 분류 후 전체/공개 projection 선택. 새 필드 자동 유입 금지 |
| listing 포인터화 | 원본 N건 읽기·listener 증가, 권한 거절/누락으로 카드 소실, 무료 사용량 증가 | R1 제외. 별도 채택 시 페이지/그룹 상한·구독수·cache·실패표시·읽기 예산 비교 |
| 공통 validator | 다른 명령이 허용 분기로 진입, 평가식/호출 깊이 증가, 과거1000식 회귀 | 명시 dispatch·명령별 허용 차이. source bytes와 실행 비용을 모두 비교 |
| 이벤트 통일 | 당시 Character 소실, 중복 알림, 타인 수신 누락/유출 | 당시 payload 불변 저장, audience/서버 명령 근거, 안정 eventID와 기존 receipt 호환 |
| member 표시 로컬화 | 기기마다 이름/Build 경고 차이, 신청 당시와 현재 값 혼동 | 신청 Snapshot과 현재 정보 구별. 공유 승인 판단에 필요한 정보 보존 |
| legacy 종료 | 구APK 조작 거절, 최신 앱도 fallback 제거 순서 오류로 이중 참가 | 실제 writer별 호환표, 서버 구write 폐쇄, 원장 이행 확인 선행 |
| raidState 이행 | 정상 새state 덮어쓰기, 난이도 간 이중 참가, ownershipLost 부활 | player/character/raid/cycle/소유권 차수 고정, 충돌 격리. 임의 우선순위 덮어쓰기 금지 |
| target 배열→map | 키 충돌·순서 소실·빈/중복 대상·identity 불일치 | 결정적ID·유일성 증명, UI 순서 별도 계약.8인 전체 write 결합 유지 |
| 그룹 관계 축소 | 내부 query 권한 거절, 가입상한/activeRecruitmentCount 불일치 | get/list/collectionGroup 별도 평가. Rules는 결과 필터가 아님 |
| cache/재진입 | offline 구schema, listener 구binding, 중복 처리 | pending을 성공으로 표시하지 않음, 재연결 후 조회, session/player별 로컬 키 유지 |
| 초기화 설정 | 테스트 요일·시간 혼입으로 주간 자료 오변환 | 미커밋 raid_cycle_schedule.dart 제외. 운영KST 수요일06시와 테스트 clock 분리 |

## 13. 게시가 계속 실패할 때의 대응 설계

우선 source 크기, 원격 검사 결과, Ruleset 저장, release 활성화, 실행 시 권한/한도 오류를
각각 기록한다. 함수 수와 줄 수만 줄어도 compiled가 줄지 않을 수 있고, 평가비용은 더 커질 수 있다.

| 실패 지점/결과 | 다음 판단·조치 | 금지할 대응 |
|---|---|---|
| 로컬 최소 Rules도 로드 실패 | HTTP/2·JVM 언어·Emulator 환경을 기준본과 분리. 과거 해결 기록 재사용 | 후보 정책 오류로 오인해 조건 삭제 |
| 원격 test 문법/경고 | 정확한 행·함수·생성 원본을 수정 후보에 연결,경고0 확인 전 게시 중단 | 경고 무시,콘솔 임시 소스를 배포 원본으로 승격 |
| test503 | 서버 검사 단계 실패로 기록. 컴파일 성공/용량초과를 주장하지 않음 | 같은 전체deploy 자동 재시도 |
| rulesets 실패/응답유실 | 저장 여부는 제한 조회로 판별,같은SHA와 요청 시각 대조 | 새Ruleset을 연속 생성 |
| PATCH400/503,후속409 | 최초PATCH 원문 보존,활성 release/source 확인. 409를 중복 파일 문제로 오인하지 않음 | 정상Release/과거Ruleset 삭제,보안검사 완화 |
| 후보 실패·동일 환경 기준 성공 | 후보 내용 의존으로 분류. 다음 단일 구조 차이와 로컬 동등성 증거를 준비 | 성공본까지 실패한다고 보고 환경만 탓하기 |
| 기준도 실패 | 크기 변환 실험 중단. 요청·서비스·대상·통신과 공식 장애/지원자료 확인 | 더 많은 기능을 제거하며 실험 계속 |
| 활성화200·source일치 | 게시 게이트만 통과. 동일V1 executable과 기능 회귀,실기기 게이트를 별도 기록 | BUG-024 해결·권한무결성을 자동 완료 처리 |
| 실제 활성소스 불일치/조회불가 | 상태불명으로 멈춤,앱 출시/이행 보류 | old/new 어느 쪽이라고 추정하고 다음 쓰기 |

각 원격 실험은 후보SHA·대상 프로젝트·단계별 횟수·자동재시도0·사후조회 범위를 명세한다.
승인된 대상의 단계별 test/create/PATCH 각1회로 하고 CLI의 catch-all create fallback을 반복하지 않는다.
첫 실패 시 중단하며 실패 후 조회는 진단이다. 기존 승인된 시도 예산은 모두 소진됐고 이번 원격 예산은0이다.
큰 폭의 의미상 동등 축소에도 같은 실패가 남으면 프로젝트/Ruleset/시각/요청·응답/성공기준/해시를
묶어 Firebase 지원에 전달할 자료를 만든다. 문의 전송은 별도 지시 후 수행한다.
실패 executable 미확보 상태에서 지원 답변 없이 정확한 compiled 초과 수치를 만들어내지 않는다.

R1 순감소가 작다는 이유로 운영에 여러 축소본을 순차 게시하지 않는다.
R1/R2/R3의 로컬 결과를 모아 최종 전환본을 검증하고, 격리 활성화에 성공한 전체본만 운영 후보로 삼는다.
필요한 중간 전환본도 게시 가능해야 하므로 최종본 하나의 성공만으로 이행 착수를 허용하지 않는다.

## 14. 앱·Rules·자료 이행의 중간 상태와 복구

공개v1.1.1은 이미 atomic 경로를 쓰므로 전체 구버전을 하나로 분류하지 않는다.
실제 명령별 `기존앱+기존Rules / 새앱+기존Rules / 기존앱+새Rules / 새앱+새Rules` 결과를 표로 고정한다.
특히 준비 변경은 새앱만으로 활성화하지 않는다. 서버 게시 실패 중에는 기존 호환 동작을 유지하고
해당 새 명령을 실패/업데이트 필요 상태로 명확히 안내한다.

1. **준비:** 읽기전용 데이터 분류·백업·충돌표,새앱 구/신 자료 읽기,모든 중간 Rules 크기와 격리 검증.
2. **쓰기 동결 필요성 확정:** R2 대상 옛 원장·새 원장·관련 파티 명령의 경합을 막는 전환이 필요하다.
   클라이언트 공지만으로 동결됐다고 판단하지 않는다. 별도 승인한 제한된 서버 Rules 전환이
   실제 활성화되는지 확인한다. 동결 Rules조차 게시되지 않으면 **데이터 이행을 시작하지 않는다.**
3. **이행:** 동결 상태에서 현재 소유권/주차/점유를 다시 읽고 조건부·멱등 변환한다.
   건수와 상태별 의미를 대조하며 알 수 없는 자료는 격리한다. 기존 운영자료를 통째 초기화하지 않는다.
4. **최종 활성화:** 최종 Rules source SHA와 새앱 호환을 확인한 뒤 새 명령을 연다.
   legacy write는 서버에서 닫힌 채 유지한다. UI 버전값을 신뢰한 차단에 의존하지 않는다.
5. **활성화 실패:** 이행 전이면 기존 상태 유지. 이행 후이면 쓰기 동결을 유지하고 원인/복구 계획을 보고한다.
   옛 Rules만 복원해 구writer가 혼합 자료를 쓰게 만들지 않는다. 불가피한 이용 중단은 사전 안내하고 승인받는다.
6. **복구:** 새자료 발생 전의 검증된 backup 복원과 새자료 발생 후의 보상 변환을 구분한다.
   source SHA·스키마·앱 버전·checkpoint를 한 복구 단위로 보존한다. 자동 강제복원/일괄 삭제 없음.

스키마 이행이 필요 없는 R1은 위 동결 절차를 무조건 강요하지 않는다. 구writer와 충돌하는
필드 계약을 바꾸는 경우에만 앱 전환·기존 요청 거절 정책을 별도 명시한다.
Firestore 이행을 위한 관리 권한은 구현 전에 확인해야 하며 Spark 무료가 관리 SDK 인증을 대신하지 않는다.
이행 도구·백업의 민감 원문은 Git에 넣지 않고 접근 제한된 위치에 보존한다.

## 15. 실행 전 결정 목록·보고와 이번 기록의 한계

현재 확정: 구현하지 않음,문서 커밋·작업브랜치 push,무료 유지,앱 업데이트/이행을 설계에 허용.
현재 미확정: 실제 legacy 자료 잔존량,모든 명령의 구APK 쓰기 호환,필드별 순수표시 여부,
R1 공개projection 최종 필드표,단계별 실측 순감소,compiled 내부크기,허용 가능한 이행 중단시간.
이것을 해결된 사실로 표기하지 않는다. 원격 조사·운영 전환·게시·기능 폐지는 이번에 실행하지 않는다.

첫 구현 지시를 받으면 R1의 필드/상태 표를 먼저 확정하고 해당 단위만 구현한다.
첫 비교에서 효과가 작거나 접근한도 회귀가 발생하면 근거를 보고하고 같은 미세 변환을 반복하지 않는다.
R2/R3는 각각 명세·동등성·전환 검토 후 별도 단위로 진행한다. 보호 조건을 없애 목표 수치에 맞추지 않는다.

문서 검증은 링크/상태/내용·git diff --check,비문서 파일SHA 보존 확인이다.
이번에는 Flutter/Emulator/게시를 재실행하지 않는다. 신규 사용자 흐름 없음·실기기 미확인이다.
기존110테스트 실패/51분석 항목은 이전 기준 기록이며 현재 새로 측정한 수치가 아니다.
진행 중 기능브랜치의 문서 복구 지점만 커밋·push하고 dev/main은 BUG-024 인수 전 통합하지 않는다.

## 16. 첫 구간 — 기준 확정 조사 (2026-10-08)

사용자의 첫 구간 착수 지시는 직전 브리핑의 1구간인 기준 확정으로 적용한다.
R1 목록 통합 구현과 구분한다. 코드·Rules·운영 자료 변경 없이 현재 기준과 다음 구현의 진입 조건을 확정한다.
로컬 기준87a1b47, 현재/원격 작업브랜치 일치. dev/main은 원격 조회에서도e4f8e0f다.
기존 초기화 파일·firestore2.rules·scope 후보 도구/테스트는 보존한다.

### 16.1 운영본 불일치 — 우선 확인 사항

후속 결과: 사용자 `1회 진행` 승인으로10월8일11:16 KST 기존 성공본 복원을 완료했다.
사전해시확인→PATCH1회200→사후활성36b5920e/134301bytes일치.
updateTime2026-10-08T02:16:46.593197Z,승인1/1소진·재시도/자료쓰기0.
아래는 발견·복원준비 이력이다. 현재는 전체차단이 아니며 BUG-024 신규 기능은 여전히 미반영이다.

10월8일10:24 KST, lost-party의 release와 그 ruleset source를 GET으로 조회했다.

| 항목 | 조회 결과 |
|---|---|
| 대상 | lost-party / (default), release cloud.firestore |
| 활성 Ruleset | 62ddc2ca-e98e-460f-85eb-70f1a7a8533d |
| release updateTime | 2026-10-07T13:42:04.272521Z = 10월7일22:42 KST |
| 소스 | 163 bytes, SHA256 ecf30f940747dcc3c5ba4993093e9a11ac9fc5df7e14b2a1512d2446923d84eb |
| 내용 | 재귀 전체 경로에 allow read, write: if false |
| 로컬 대조 | 미추적 firestore2.rules와 SHA 일치. 배포 원본 firestore.rules는408f163f 유지 |

따라서 현재 운영은 기존 성공본36b5920e가 유지된 상태가 아니라 **클라이언트 전체 접근 거절**이다.
앱의 새 서버 읽기·쓰기는 거절되며 이미 저장된 로컬 캐시가 보이는 현상과 구분해야 한다.
관리 인증으로 수행한 이번 데이터 조회 성공은 일반 앱의 Rules 통과 증거가 아니다.
이번 에이전트 작업에서 게시/복원한 것은 아니다. 사용자는 전체 차단이 **의도한 상태가 아니라고 확인**했다.
변경 주체는 미확인이다. 운영 복구를 구조 축소보다 우선할 별도 작업으로 올리되 자동 게시하지 않는다.
10:27 KST 기존 성공 Ruleset26621a37-ae16-45c4-9858-f10380439e28을 GET200으로 재확인했고,
134301bytes/SHA36b5920e7677b395192e47e05daeea1eec4512beaf19250bf6c5a82eff352e3d로
보존본과 일치했다. 신규 Ruleset을 만들지 않고 기존 성공본을 복원할 수 있는 대상이 존재한다.
복원 명세는 release cloud.firestore 사전GET/source 확인 → 기존 성공 Ruleset을 가리키도록
PATCH 최대1회 → 사후GET/source SHA 확인이다. test/create/fallback/자동재시도/데이터쓰기0회.
사전 활성본이 이번163bytes와 다르면 다른 변경과 경합할 수 있어 실행하지 않고 다시 판단한다.
AGENTS.md §5의 실패 후 새 지시 조건에 따라 실제 PATCH는 후속 실행 지시를 받은 뒤 수행한다.
복원은 BUG-023까지의 기존 기능용이며 BUG-024 준비/인증 확장용이 아니다. 새 작업본 앱의
BUG-024 신규 명령은 여전히 서버에서 거절될 수 있어 정상 복구와 BUG-024 종료를 구분한다.
자료23건의 전체 무결성 검증이나 현재 작업본 전체 호환을 복원 근거로 주장하지 않는다.
이전 실패본408f163f를 반복 게시하지 않는다.
작은 deny-all 활성화는 큰 기능본의 게시 가능성이나 400 원인을 증명하지 않는다.

### 16.2 구 원장 잔존 자료의 제한 조회

Firestore runQuery의 읽기 전용 collectionGroup 요청3회. 각 경로 limit201,
선택 필드는 status/cycleKey/ownershipRevision만이며 원본 ID·문서 원문은 저장하지 않았다.
상한에 도달한 경로가 없어 이번 조회 시점의 해당 collectionGroup 결과는 잘리지 않았다.
경로가 players/{id}/{collection}/{id}에 해당하는지도 메모리에서 검사했고 예외0건이다.
이 세 조회는 동일 시점의 원자 스냅샷이 아니며 미래 새 자료가 생기지 않는다는 보증도 아니다.

| collectionGroup | 관측 건수 | 상태/필드 집계 | 판정 |
|---|---:|---|---|
| activeRaidAssignments | 0 | 상한 미도달 | 현재 이행할 관측 자료 없음. 영구 미사용 증거는 아님 |
| weeklyRaidClaims | 0 | 상한 미도달 | 현재 이행할 관측 자료 없음. 읽기 제거와 별개 |
| raidStates | 23 | completed19, active4; ownershipRevision 존재17/부재6 | 현재 원장은 보존. 부재6건을 손상/삭제 대상으로 단정하지 않음 |

cycleKey별 건수는2026-09-29:8, 2026-10-06:8, 2026-09-23:5, 2026-09-28:1,
2026-09-16:1이다. 운영 기본 주차 경계는 KST 수요일06시지만 테스트 시점·과거 설정으로 생성된
자료일 수 있으므로 문자열을 현재 주차로 자동 치환하지 않는다. 개별 소유자/원본 모집과의
유효성 교차검증은 하지 않았으며23건을 모두 현재 유효한 점유라고 해석하지 않는다.

이 결과로 R2는 대량 이행을 필수 작업으로 가정하지 않는다. 전환 직전 재조회에서도 구 자료가0이고
신규 구쓰기 차단·호환 앱 준비가 확인되면 **변환 쓰기0건인 전환**을 선택할 수 있다.
반대로 새 구자료가 발견되면 해당 범위의 충돌 분류와 이행 명세부터 적용한다.
현재 deny-all 상태를 이행 동결 승인으로 재해석하지 않는다.
근거: ignored coverage/bug024/baseline-readonly-result.json. 조회 도구도 coverage에만 보존했다.

### 16.3 공개 태그별 실제 연결과 제거 제한

태그 소스의 app_router와 개인 완료 명령/읽기 Repository를 직접 대조했다.
태그와 실행 중 APK의 일치·현재 설치 비율은 미확인이다. 아래 표는 코드 연결 근거다.

| 소스 기준 | 파티 명령 기본 DI | 개인 완료 기본 쓰기 | 주간 상태 읽기 |
|---|---|---|---|
| v1.0.0 / 0c93b34 | Atomic 생성·신청·참가·멤버 변경/제거·공개범위, AtomicCycleAdapter | WeeklyRaidStatusCommand의 raidStates set, 구 Claim/assignment 삭제 호환 | raidStates + weeklyRaidClaims + activeRaidAssignments |
| v1.1.0 / 8405555 | 같은 Atomic 계열 | 같은 새 원장·구 삭제 호환 | 동일3경로 |
| v1.1.1 / 6f3876e | 같은 Atomic 계열 | 같은 새 원장·구 삭제 호환 | 동일3경로 |
| 작업본 / 87a1b47 | Atomic 계열 + BUG-024 준비/인증 확장 | stub·소유권 호환이 추가된 새 원장 명령 | 동일3경로 |

기존 FirestoreWeeklyRaidClaimRepository도 router에서 생성되지만 개인 완료 명령 기본 주입은
FirestoreWeeklyRaidStatusCommandRepository다. 클래스가 존재한다는 이유로 실제 legacy writer로 세지 않는다.
테스트/대체 주입·예전 개발 APK·변조 클라이언트는 이 표로 사용 종료를 입증할 수 없다.
현재 Rules의 legacy 신규 쓰기 허용 여부와 실제 배포 APK의 소비를 별도 확인해야 한다.

중요한 추가 발견: FirestoreWeeklyRaidStatusRepository는3개 스트림 결과를 모두 기다린 뒤 상태를 낸다.
빈 legacy 조회도 서버에서 거절되면 오류를 전달하므로 **자료0건 ≠ 읽기 Rules 제거 가능**이다.
PartyRaidStateOccupancyInspector도 구 Claim/assignment를 transaction.get한다.
R2에서는 최신 앱의 명령/상태 reader를 함께 전환하고, 구앱을 지원하는 기간의 빈 조회 권한은
별도로 유지하거나 업데이트 필요 상태를 정의한다. 신규 쓰기 폐쇄와 읽기 폐쇄를 묶지 않는다.

### 16.4 R1 구현 전 고정한 연결 범위

| 명령군 | 현재 listing 방식 | 다음 구간에서 보존할 조건 |
|---|---|---|
| atomic 생성 | 생성 시 listing 저장 | 그룹 공개범위·원본 생성·그룹 count 결합 |
| 참가/승인·캐릭터/자리 변경 | PartyRaidListingTx의 최종 원본 복사 | snapshot 대신 transaction 최신 원본, 원자성·8인 한도 |
| BUG-024 준비 변경 | 같은 동기화 계열, 기존 listing 필요 | listing 누락을 자동 생성으로 바꾸지 않음 |
| lifecycle | 일반 부분patch; advanceCycle은 원본+patch 복사 후 sourceRevision | 반복 완료 유지/전환, 해산·1회성 종료 삭제 구분 |
| 탈퇴/추방 | MemberRemovalWritePlan의 필드별 patch | BUG-022 멤버·정원·후임 이름 및 revision 반영 |
| 공개범위 전환 | group 전환 최소6필드 set, public 전환 delete | 직접 카드 reader가 소비할 필드와 공개 범위 |
| 개인 완료·소유권 정리 | 별도 partial update/delete | 마지막1인·승계·완료 이력·group count |
| backfill | 원본 복사 set, 원본 변경 없는 예외 | 기존 참가자 권한/누락/종료 상태와 일반 명령 분리 |

직접 listing을 카드로 읽는 FirestorePartyReadRepository는 손상/필수필드 누락 mapping 예외를 건너뛴다.
따라서 최소6필드 writer와 full writer 혼용은 필드별 reader 표로 확인해야 하며,
단순히 Rules만 canonical full-copy 조건으로 바꾸면 구 writer의 정상 조작이 거절될 수 있다.
이번에는 모든 필드의 공개성을 확정하거나 canonical writer를 구현하지 않았다.
R1 다음 시작 산출물은 명령별 before/after/필수쓰기와 reader 필드표다.

### 16.5 구간 판정과 후속 실행 경계

- 확인 완료: 운영 활성 소스, 로컬 실패 기준, 공개3태그 기본 DI/원장 경로,
  구 원장0건/새 원장23건, legacy 읽기 폐쇄의 명확한 앱 오류 위험, R1 연결 범위.
- 사용자 확인 완료: 전체 차단은 의도하지 않은 상태. 후속1회승인으로 기존 성공본 복원·활성해시 확인 완료.
- 다음 로컬 구간: R1 필드/책임표 확정 후 단일 projection 후보 구현. R2/R3 동시 착수하지 않음.
- 원격 게시·자료 이행: 기준조사에서는0회, 후속복원은승인PATCH1회완료. 자료이행0회. 추가재시도없음.
- 새 기능/실기기: 없음. BUG-024 미종료. 기존110실패/51분석 기록을 이번 결과로 재측정하지 않음.
- R2 진입 시 추가 확인: 실제 배포 단말 범위, 구writer 차단, 직전 잔존량, ownershipRevision 부재의 의미.
  큰 이행을 생략할 수 있는 근거는 확보했지만 legacy 검사를 지금 제거하는 승인은 아니다.

## 17. R1 로컬 후보와 재개 검증 (2026-10-08)

### 공개 전환·종료 count 책임 보완 — 최신 체크포인트

기존 후보의 실제 client Transaction에서 group→public 전환이 그룹 close Rules에 거절됐다.
close는 lifecycle/개인완료만 허용했지만 앱은 공개 전환에도 감소를 요청했다.
별도로 AtomicCommand·개인 마지막1인·완료 소유권 정리는 groupId만으로 감소했으며,
공개방에 groupId를 보존하는 계약과 충돌했다. 앱만 변경하면 원본 Rules도 감소를 요구하여 종료가 막힌다.

| 전이 | 그룹 count·목록 책임 |
|---|---|
| group→public | 현재 count N→N-1, 목록 삭제를 원본 전환과 결합 |
| public→group | 현재 count N→N+1, canonical 목록 생성과 결합 |
| 공개방 완료/해산/만료/개인 마지막1인 | groupId가 남아도 count Snapshot 보존, 그룹/목록 쓰기 없음 |
| 그룹 일회성 완료/해산/만료/개인 마지막1인 | 현재 그룹 count N→N-1과 삭제, 생성 당시 Snapshot 차이 허용 |
| 그룹 반복 회차완료 | count 유지, canonical 목록 유지 |
| 일회성 완료 뒤 해산 | 이미 닫힌 count 유지; 반복 완료 뒤 해산은 한 번 감소 |
| 마지막 완료1인 소유권 정리 | active+group일 때만 감소, 완료 raidState·member Snapshot 보존 |

후보는 기존 현재 집계 검사를 전역으로 옮겨 lifecycle/개인완료가 공유한다.
그룹 close는 전이 전 active+group 및 같은 요청의 원본 revision/time을 요구하여
종료 원본을 재사용한 감소를 차단한다. 공개 전환은 실제 그룹 전후 count에 결합한다.
공개/이미 종료 방의 count 감소를 다시 요구하지 않도록 앱 세 writer의 조건을 맞췄다.

그룹 count 쓰기를 누락한 해산 요청은 기존 긴 OR 경로에서 1,000식 오류를 냈다.
현재 시각의 명시적인 complete/advanceCycle/disband/incompleteEnd는 lifecycle로 직접 분기한다.
슬롯은 lifecycle의 원본 동일성 검사로 보존하고, 완료 마지막1인 해산은 별도 member/state/event
보존 검사를 유지한다. 다른 명령을 시도해 권한을 얻는 fallback을 제거한 것이며 보호 삭제가 아니다.

검증: tools/rules_group_count_proof.mjs 22건(공개4종 종료·그룹 감소/누락/이중감소,
과거 Snapshot 차이, 완료 후 해산, 소유권 상실 후 정리, 양방향 공개전환/누락,
다른 모집 count가 남은 상태의 종료 원본 재사용 거절). 위조 요청은 실제 permission-denied와
전후 문서 불변을 확인하며 평가 한도 오류는 통과로 세지 않는다.
목록34·완료역할27·개인완료15건 회귀 통과. Flutter19건/분석4파일/생성기check/문법/diff 통과.
초기 재현 fixture의 소유권 차수·누락 난이도를 실제 앱 형식으로 맞췄고,
개인완료가 참조하는 집계 함수의 로컬 범위 오류는 전역 공유로 수정 후 통과했다.
로그: coverage/rules-listing/group-count-before.log, group-count-final.log, count-final-regression.log.

최신후보17471d0f4bff19595c90ddb43c28766cbf976d77ba9d0adc0736ff59f4a93667,
148725bytes. 직전147985보다740bytes 증가, 추적151427 대비2702bytes(약1.78%) 감소.
이번은 기능 보존 결함 보완으로, 대폭 축소 실적으로 포장하지 않는다.
추적408f163f/운영 유지·원격0. 원격 컴파일 경고/활성화는 이번에 확인하지 않았다.

부작용/인수: 기존 잘못된 이중감소를 기대하는 구버전 앱은 후보에서 거절될 수 있으므로
앱/Rules 전환을 함께 설계해야 한다. 공개 잔여목록을 개인완료/소유권 정리가 자동 삭제하지 않게
통일했으며 과거 잔여자료는 별도 이행 대상이다. 이미 어긋난 운영 집계를 자동 보정하지 않는다.
완료 후 목록 삭제·공개/그룹 전환·내 계정 마지막1인 완료·소유권 정리는 최종 앱 전환 뒤 사용자
실기기 확인 항목이다. 현재 운영 Rules와 이 앱 진행본을 조합해 인수를 시작하지 않는다.
아래 writer 정리 당시의 미확인 count 항목은 이 결과로 갱신하며 나머지 R1 인수 잔여는 유지한다.


### writer 수명 계약 정리 — 2026-10-08 후속

목표는 여러 listing 형식의 중복 검증 제거다. 실제 운영 Router는 atomic create/join/
membership mutation+removal/visibility/cycle adapter를 사용한다. 구 non-atomic Repository는
생성자 선언만 남아 있고 Router 연결은 없다. 이번에는 그 전체 삭제로 범위를 넓히지 않았다.
3개 WritePlan에서 실제 호출 없는 lifecycle listingPatch/AfterRecruitmentChange, removal listingPatch,
visibility의6필드 listingDocument를 제거했다(구현54행). visibility는 검증된 이진 전환 결과로
delete 또는 canonical set을 실행한다. sourceRevision을 새로 만드는 atomic 목록 API는 남지 않는다.
원본 patch에서 최종 전체문서를 만드는 helper 하나를 실제 Repository와 테스트가 사용한다.

| 실제 writer | 목록 쓰기와 누락 전제 | 읽기·권한/수명 책임 |
|---|---|---|
| AtomicCreate → membership plan | 그룹 생성 시 canonical set | 신규 원본·참가자·그룹 count와 원자 생성 |
| AtomicJoin | group이면 shared sync set, 누락 생성 가능 | 원본/신청/Character/state/목록 등 read 후 write, 원본 참가 검증 |
| AtomicMemberMutation active 변경·자리 | group이면 shared sync set | 본인 active 참가자는 그룹 탈퇴 뒤 blind write 가능, 그룹 read 확대 없음 |
| AtomicMemberMutation nextWeekPrep | 기존 목록 필수, shared sync set | transaction read와 snapshot.exists 검사 + 원본 준비 결합 |
| AtomicMemberRemoval | group이면 최종 원본 set | 목록 read 없이 쓰며 create 제한으로 누락 시 전체 거절; 승계 포함 |
| AtomicVisibility | group 전환 set, public 전환 delete | 원본·그룹·리더 membership read, groupId 유지, 기존 집계 권한 유지 |
| AtomicCommand complete/advance | 반복방 유지 set, 일회성 종료 delete | 실제 Timestamp 변환 완료한 원본 patch를 복사; 기존목록 필수 경로 유지 |
| AtomicCommand disband/incompleteEnd | group 목록 delete | 원본/그룹 count/state/event 원자 처리, 완료 후 해산 count 중복 감소 방지 |
| CycleAdapter recurrence | group이면 canonical set | 리더·revision·active 방 조건, 완료 회차의 누락목록 생성은 후보가 거절 |
| WeeklyRaidStatus personalComplete | 그룹 잔류자 있으면 set, 마지막1인은 delete | 원본·member·state와 원자 처리, 누락 허용 확대 없음 |
| CompletedOwnershipCleanup | 잔류자 set, 마지막 해산 delete | 기존 observation/revision·후임·원본 검사 보존 |
| Backfill | missing만 set, 기존 partial은 건드리지 않음 | 현재 그룹 참가자, 원본 불변, status=active, cycle disband 제외 |

**종료 후 재생성 보완:** 기존 backfill은 status=completed까지 조회하고 disbanded만 제외하여,
일회성 완료로 삭제한 listing을 다시 만들 수 있었다. 장기 계약의 되돌릴 수 없는 종료 삭제에 맞춰
앱 조회/transaction 재확인과 후보 Rules의 backfill을 status=active로 통일했다.
반복방은 status=active/currentCycleStatus=completed이므로 다음 주 대기 목록 복구를 유지한다.
추적 Rules·운영은 바뀌지 않으며 앱/후보를 함께 전환해야 한다.

검증: Flutter 직접 영향33건·변경10파일 analyze 통과. 목록 proof는 종료2건과 공개/종료 경합2건을
추가한34건 통과. 경합에서는 읽기 뒤 원본 전환을 admin fixture로 주입하여 old payload가
permission-denied로 거절되고 재진입이 쓰기를 생략함을 확인했다. 명령 자체의 권한을 admin으로
검증한 것은 아니다. 자동 retry 성공을 기대한 최초 테스트는 실패했고 실제 거절 경계로 바로잡았다.
기존5개 suite의 명령 검증 본문은 변경하지 않았으므로 재실행하지 않았다.

최신 검토후보98e0bbdce15eb527134513abe21b045b219b15ed694d1d8a54c049d2ecd7efda,
147985bytes. 직전보다3bytes 감소, 추적151427 대비3442bytes(약2.27%) 감소다.
앱54행 제거를 Rules54행 감소로 계산하지 않는다. 대폭 감소는 아직 달성하지 못했다.
로그: coverage/rules-listing/writer-flutter.log, writer-analyze.log, writer-listing-confirmed.log.

**남은 차이와 영향:** public-linked 방의 lifecycle은 목록 action=none이므로 과거 잔여목록을
자동 삭제하지 않는다. personalComplete 마지막1인/ownership 해산은 groupId가 있으면 삭제한다.
또 closesActiveGroupRecruitment는 visibility 아닌 groupId를 기준으로 count를 줄인다.
이는 이번 API 제거 전부터의 차이이며 공개전환 뒤 종료의 count 계약을 따로 검증해야 한다.
무조건 삭제/그룹 count 수정을 함께 적용하지 않았다. backfill 한 방 실패가 반복 전체를 중단하는
기존 동작도 유지한다. 무한재시도·일괄 복구를 추가하지 않는다. 중첩 필드와 실제 과거자료,
앱/Rules 혼합 전환, R1 최종 승인·게시 인수는 아직 미완료다.

### 목록 전용 권한·backfill 책임표 검증

6c71c5bf 후보를 그대로 사용한 `tools/rules_listing_boundary_proof.mjs`의30건이 통과했다.
대상은 demo-party-group-cutover/localhost:8080뿐이며 운영/원격 API 요청은 없다.
Router는 기본 Firestore repository일 때 backfill을 연결한다. 목록 ViewModel 시작 시 호출되며,
repository는 본인 참가 원본 최대50건을 조회한 뒤 transaction에서 원본→목록 순서로 다시 읽고
목록이 없는 경우에만 canonical set한다. 원본 revision을 올리지 않는다. 테스트는 이 읽기/쓰기
순서의 재진입·경쟁과 별도의 위조 직접쓰기를 검증하며 실제 Dart/UI 실행 검증을 대신하지 않는다.

| 경계 | 요청·결과 | 책임 |
|---|---|---|
| 구형 목록 읽기 | 현재 그룹원은 부분 필드/sourceRevision 목록 get/list 가능; 외부인·미인증은 거절 | 기존 그룹 읽기 범위 유지 |
| 목록 단독쓰기 | 원본 없이 revision 증가/동일 전체덮어쓰기/삭제 모두 거절 | 기존 목록 변경은 같은 요청의 원본 변경 필요 |
| backfill 주체 | 현재 그룹원+원본 참가자만 누락 생성; 비참가 그룹원/외부인/미인증/그룹 탈퇴 참가자 거절 | `r1ListingBackfill`의 그룹/참가 이중 조건 |
| 경로·내용 | 다른 그룹 경로·groupId 위조·원본 없는 ID·제목/revision 위조·부분복사 거절 | source 경로와 groupId 및 전체값 일치 |
| 새 필드 | listing에만 추가하거나 원본에도 존재하는 미허용 top-level 필드 모두 거절 | Dart 필드표에서 생성된 Rules hasOnly |
| 수명 | 공개방·status 해산·cycle 해산 복사 거절; 완료 회차 대기방은 누락 생성 허용 | 기존 backfill 예외 유지 |
| 재진입 | 기존 부분 목록과 정상 목록 모두 수정하지 않음 | Dart와 같은 read-before-create 순서 |
| 오래된 snapshot | 원본 변경 이전 payload 거절, 새 transaction은 최신 원본 복사 | source 불변·getAfter 일치 |
| 동시 누락 생성 | 두 참가자가 missing을 읽은 뒤 경쟁; 하나 생성, 하나 재시도 후 existing 반환 | Firestore transaction precondition, 원본 revision 무변경 |

거절은 `assertRulesDenied`로 평가/접근 한도 오류와 구분했다. 매 요청 전후 원본/목록/위조 대상
문서를 비교해 불변을 확인했다. 최종 정상·경쟁 요청은 source와 listing의 전체 일치도 확인했다.
최초 실행은 테스트 보조 함수가 Rules-disabled callback의 반환값을 전달하지 않아 중단됐다.
명시적 반환값 보존으로 고친 최종 실행30건만 완료 근거로 삼는다. Rules·앱 수정은 필요하지 않았다.

부작용·한계: 기존 부분 listing은 backfill 재진입으로 자동 교정되지 않는다. 허용표 밖 필드가
원본에 있으면 정상 앱의 canonical writer도 거절한다. 현재 backfill은 방별 실패를 분리하지 않아
이런 실패 하나가 뒤쪽 방의 보완까지 중단하며 ViewModel에서 예외를 삼킨다. 전체 writer 인수에서
검토할 기존 처리다. top-level 허용표는 중첩 map/list 필드의 안전성을 증명하지 않는다.
completed/incompleteEnded 같은 되돌릴 수 없는 종료와 backfill의 계약 정합성, lifecycle/공개전환과
backfill 사이의 경쟁, 과거 실제 자료와 구버전 앱 혼합은 이번30건의 검증 범위 밖이다.
후보 source147988bytes/기준 대비2.27% 감소는 그대로이며 원격 compiled 크기·게시 성공은 미확인이다.
실행: 후보 생성 후 로컬 Emulator에서 R1_LISTING=1 및 PARTY_RULES_FILE=coverage/rules-listing/candidate.rules로
위 proof를 Node 실행한다. 최종 로그: coverage/rules-listing/listing-boundaries-final.log.
이전5개 suite·active-listing3건은 동일 Rules이므로 재실행하지 않았다. R1 전체 완료 판정은 보류한다.

### 최신: active 대안의 공통 결합 게이트

후보6c71c5bf2acd54368463689edc7a569cf4a6fe22aa6e545a15f5068a506533c8는147988bytes다.
추적151427 대비3439bytes(약2.27%) 감소. 변경은 검토용 생성기에만 있으며 추적408f163f 유지다.
기존에는 참가/캐릭터/자리/공개전환 각 대안에서 목록 결합이 실패해도 다음 대안을 평가했다.
신청카운터 분기는 그대로 두고 나머지4개 대안을 `목록결합 && (참가 || 캐릭터 || 자리 || 공개전환)`으로
묶었다. listing 쓰기 누락이면 내부 명령 대안을 평가하지 않는다. 검사를 다른 문서로 옮기지 않았다.

참가/캐릭터/자리는 atomicActiveV2Recruitment에서 기존 status=active를 요구하고 허용 필드에
status/visibility가 없어 이를 보존한다. 따라서 공통 transition 검사는 기존 initial-copy 검사와 같다.
공개전환은 기존 transition 검사를 그대로 공유한다. 신청카운터 예외와 lifecycle/준비/개인완료/
소유권정리의 별도 결합은 유지한다. 원본 명령 권한·소유권 차수·원자성 조건 삭제는 없다.

- 목록 누락과 슬롯 소유권 차수999 위조를 일반 permission-denied로 거절했다. 한도/service-call
  오류를 통과로 세지 않는 assertion을 사용하며 모집/기존 상태 불변·새 상태 없음도 확인했다.
- 기존8인 제자리 교체·stub 교체·빈자리 이동 및 점유/범위/타 슬롯/타 target/멤버불일치 등 거절 통과.
- 준비30·완료역할27·수동22·개인15와 그룹 신청의 목록쓰기 예외·승인·8인 제거 후 재참가3건 통과.
- 새 그룹 fixture 최초 실행은 원정대 소유권 문서 누락으로 setup 생성부터 실패했다. 추적 기준에서도
  동일 실패를 확인한 뒤 기존 캐릭터 fixture와 같은 권위자료를 보완했다. 실제 그룹 신청의 회귀가 아니었다.
- 기본 생성기 check·차분 모델1건·문법 검사·diff check 통과. Dart 무변경으로 Flutter는 반복하지 않았다.

새 부작용: 잘못된 목록 요청이 원본 명령 대안보다 먼저 거절되어 로그의 최초 실패 위치가 달라진다.
허용하려던 명령의 권한은 보존하며 신청만 수행하면 목록의 신청카운터가 즉시 갱신되지 않는 기존 예외도 유지한다.
배포/컴파일 서버 요청0회. compiled 크기·운영 경고·게시 성공을 확인한 것이 아니다.
다음은 목록 단독쓰기/다른 그룹 위조/허용필드/backfill/누락/재진입 검증이다. 아래 저장계약의
구버전 혼합·허용표 밖 필드·payload 증가·public-linked 목록 및 전체 writer 인수는 여전히 남는다.
R1 전체 완료·추적본 승격·APK 인수·dev/main 통합은 보류한다.
근거: coverage/rules-listing/factored-placement.log, factored-all.log,
factored-active-listing-roster.log. 실패 대조는 factored-active-listing.log와 baseline-active-listing.log.

아래는 이전 후보 이력이다.

### 후속: 변경 슬롯 평가 비용 분리

단일 요청 전 Rules 재로드로 setup coverage를 제외했다. 정상/타 슬롯 위조 각 요청을
기준과 후보에서 대조했으며 정상 요청의 슬롯 검사 경로는 같았다. 후보에 목록 결합14 expression
sample이 추가됐다. coverage sample 합계는 공식1,000식 budget 수치로 해석하지 않는다.
거절 요청은 평가 순서/조기 종료가 달라 단순 sample 차이를 순수 비용으로 계산하지 않았다.

기존에는8개 위치마다 before 전체 목록을 검색했다. 후속 후보는
after.partySlots.removeAll(before.partySlots)로 변경 슬롯을 한 번 추출하고 기존
deSlotMemberGeneration을 각 변경 슬롯에 적용한다. 동일 목록 허용·8인 상한·각 슬롯과
membership의 player/character/ownershipRevision 비교를 유지하며 서버 검사를 로컬로 옮기지 않는다.
차분 모델은 순서/중복/제거/빈 목록/8·9개 경계와 임의 membership 허용 여부를 대조해 통과했다.
이 모델 검증은 Emulator의 실제 권한 검증을 대체하지 않는다.

후보7b2fe1da829b532dae82743d7b7b03c29822f278b64d732f0cb629a3ad4a8b93는148088bytes,
기준 대비3339bytes(약2.21%) 감소다. 기존 캐릭터/자리 suite 통과, 준비30·완료역할27·수동22·개인15 통과.
추가한 omitListing 부정 요청에서는1,000식 한도 오류가 남았다. forgedGeneration 신규 사례는
그 앞 실패로 실행되지 않았으므로 미검증이다. 목록 결합을 각 명령검사 앞에 둔87f38004는 실패하여 제외했다.
R1 완료·게시 가능성을 주장하지 않는다. 다음은 누락 요청을 싼 게이트에서 정상 거절하도록 책임을 설계하는 일이다.
근거: coverage/rules-listing/probe-{baseline,candidate} 및 *-positive,
changed-slots-placement.log, changed-slots-all.log, listing-first-placement.log.
추적Rules·운영자료·Dart 앱 추가 변경 없음. 아래는 이전 후보 이력이다.

### 판정

**R1 미완료·후보 승격 보류.** 시작 HEAD4c091fa, 브랜치fix/recurring-next-week-character-change.
canonical writer와 후보 생성 경로를 연결했지만 모든 회귀가 통과하지 않았다.
이 커밋은 검토/복구용 진행본이다. 현재 운영 Rules와 함께 앱을 배포하거나 실기기 인수를 시작하지 않는다.

기본 생성기의 `--check`는 여전히 추적408f163f와 일치한다. `--listing-candidate`만
ignored coverage/rules-listing에 후보를 만든다. 최종 보존 후보a190ad6313f525b9211d957d4900e75bc5b3e5b4daf0b4ac365e0cb689a4696c,
148053bytes: 기준151427 대비3374bytes(약2.23%) 감소. compiled 크기·원격 경고·게시 가능성은 미측정이다.
R1만으로30% 감소 또는 게시 장애 해결을 달성한 것이 아니다.

### 저장 계약과 실제 연결

`party_raid_listing_document.dart`가 현재 원본57개 top-level 필드를 명시한다.
새 필드는 자동 노출하지 않고 StateError로 거절한다. 최종 원본+실제 patch를 합쳐 전체 set하며
sourceRevision은 새 목록에 만들지 않는다. 기존 reader는 수정하지 않았다.
이 허용표는 필드 단위 공개범위의 출발점이며 모든 과거 원본의 실측/이행을 완료한 표가 아니다.

| 필드군 | 포함 내용 | 역할·주의 |
|---|---|---|
| 식별·공개범위 | schema/recruitment/group/visibility, leader/member IDs | 그룹원 목록 읽기 범위 유지. 이름만 표시값이고 ID/범위는 권한자료 |
| 카드·조건 | title, raid/difficulty/catalog snapshots, 레벨/전투력, 경험/시간 | 원본 없이 listing을 카드로 읽는 기존 mapper에 필요 |
| 구성·주차 | slots, 인원/역할 count, cycle key/status/window, continueTogether | 자리·참가·완료 정책 자료. 로컬 권한 검증으로 이관하지 않음 |
| 원자 명령 | revision, targets, lastCommand*, ownershipCleanup, group count | 원본과 같은 요청에 결합하기 위한 복사. 과거 완료 이력을 재구성하지 않음 |
| 수명·시각 | created/updated/completed 시각, 완료자, 신청 count | null도 그대로 보존. 신청 count만 바꾸는 기존 명령은 목록 의무를 추가하지 않음 |

| 연결한 writer | 후보에서 달라지는 쓰기 | 남은 검토/위험 |
|---|---|---|
| atomic 생성·참가/승인 | membership plan/shared listing sync의 공통 복사 | 신규 필드 허용표와 모든 writer 경계 추가 검증 필요 |
| 캐릭터·자리/준비 변경 | 공통 sync, 그룹을 떠난 active 참가자는 원본 권한에 의한 blind listing write | 기존 group 읽기권한을 새로 부여하지 않음. 준비 변경은 기존 listing 필요. 평가 한도 회귀 남음 |
| lifecycle | 부분 update 대신 최종 원본 set | 반복 완료 유지/주차 전환; 1회성 종료·해산 삭제. public-linked 과거 잔여 목록 처리 미확인 |
| 제거·개인 완료·소유권 정리 | composition 부분 patch 대신 최종 원본 set | 마지막1인 삭제/승계 보존이 목표. 신규 생성과 missing 계약을 별도로 검사해야 함 |
| 공개범위 전환 | group 전환 최소6필드 대신 전체 원본 set, public 전환 delete | 구버전6필드 쓰기는 새 후보에서 거절될 수 있음 |
| 반복 설정·backfill | 반복 설정에 목록 복사 추가, backfill 공통 writer | 반복 설정 시 추가 쓰기 발생. backfill은 원본 불변·현재 그룹 참가자만 허용 |

현재 사용되지 않는 lifecycle listingPatch API와 구 sourceRevision 테스트 일부는 남아 있다.
이것을 모두 통일했다고 판정하지 않는다. 후보 채택 전 호출자/테스트 정리와 전체 write 책임표를 끝낸다.

### Rules 책임과 실패에서 확인한 점

listing은 groupId/visibility/허용 키·원본 전체 일치와 실제 revision+1/server time을 확인한다.
기존 모집 권한 검증을 listing에서 다시 실행하지 않는다. 원본 무변경 생성은 참가자 backfill로 분리한다.
원본의 기존 준비/개인완료/소유권정리 결합은 재사용하고, 결합이 없던 명령 분기에만 목록 의무를 추가했다.
기존 목록 필수 명령에서 set으로 누락을 조용히 복구하지 않도록 listing create 경로도 제한했다.
하지만 이 정책 전체의 정상/누락/위조 검증은 아직 끝나지 않았다.

1. 첫 후보aeae3d0e(147910bytes)는 원본 update 전체에 공통 diff/기존 listing 조회를 추가했다.
   8인 완료 준비에서 service-call 오류, 변경/개인완료에서1,000식 오류가 발생했다.
2. 기존 결합을 반복하지 않고 분기별로 필요한 검사만 추가한f6dc4374(148128bytes)에서
   8인 준비→전환→완료가 통과했다. 캐릭터 제자리 변경은 통과했지만 빈자리 이동이 한도에 걸렸다.
3. 유지/삭제 검사를 분리한 최종a190ad63에서 준비/인증30·완료역할27·개인완료15건 통과.
   캐릭터/자리 suite의 다른 slot 변조 거절에서 한도 오류가 남았다. 일반 permission-denied로 통과 처리하지 않았다.
4. 동일 fixture를 추적408f163f로 실행하면 제자리/stub/빈자리 이동과 거절 경계 모두 통과했다.
   따라서 이번 차단을 localhost 통신 장애로 처리하지 않는다.
5. 별도cc6e5434는 동일 OR 대안에서 캐릭터/자리 검사를 앞세웠지만 초기 참가 단계에서 한도 오류가 났다.
   실효성이 없어 제외하고a190ad63으로 되돌렸다. 권한 조건 삭제·원격 실험은 하지 않았다.

다음은 단순 helper 축약/순서 변경 반복이 아니라 **명령별 필수 쓰기와 평가 책임의 재설계**다.
특히 새 결합을 다른 문서로 이동하려면 그 문서 쓰기가 원본에서 강제되는 근거가 필요하다.
R1 범위에서 안전한 예산을 확보할 수 없으면 R3 선행 필요성을 별도 설계로 명시해야 한다.
소스 감소와 실행 평가 예산은 별개의 제약이다.

### 검증·부작용·미완료 게이트

- 사용자 localhost 필터 해제 후 HTTP/1·HTTP/2 4건 모두 정상. 시스템 보안 설정은 에이전트가 변경하지 않았다.
- Flutter 저장 계획/공통 writer 표적27건 통과. 중단 직전11파일 분석에 이어 추가4파일 분석 통과.
- manual completion22건은 최초후보에서 통과했다. 이후 변경한 원본 목록 결합 분기를 소비하지 않으므로 반복 실행하지 않았다.
- 전체 Flutter는 후보 채택 전이므로 재실행하지 않았다. 이전 전체110실패/분석51건 기록을 해결로 바꾸지 않는다.
- Rules runtime coverage 내보내기는 최초 실행에서 대용량 문자열 직렬화 실패가 발생했다.
  후속 실행은 명시적 RULES_SKIP_COVERAGE로 생략하고 실제 assertion 결과와 로그를 보존했다. coverage 확보를 주장하지 않는다.
- 기존 부분 patch APK와 새 Rules의 혼합은 쓰기 거절을 만들 수 있다. 반대로 새 full-copy 앱을 현재 운영 Rules에
  먼저 내보내면 개인완료/제거 등 기존 필드제한에 걸릴 수 있다. 앱/Rules 전환 순서·호환 인수는 미완료다.
- 과거 원본에 허용표 밖 필드가 있으면 정상 명령도 로컬에서 거절된다. top-level 허용표는 중첩 필드의 개인정보 검토를 대신하지 않는다.
- 전체 복사에 따른 쓰기 payload 증가, 반복 설정의 추가 쓰기, 기존 sourceRevision 없는 목록 읽기,
  public-linked 잔여 목록, 누락 listing/단독쓰기/타 그룹 위조/backfill/경합과 모든 관련 writer는 최종 인수 전 남은 항목이다.
- 데이터 이행·운영 요청·Rules 게시0회. 추적Rules와 기존 사용자4파일 해시 보존. dev/main 통합 없음.

로컬 근거는 coverage/rules-listing의 first-run, revised-runtime-all, revised-completion,
revised-personal, revised-placement-2, baseline-placement, reordered-placement, flutter-tests 로그다.
후보 생성 코드와 fixture 조정은 검토용 체크포인트에 포함하며 원시 로그는 ignored 상태로 둔다.


## 18. R2 로컬 의존성·축소 실측과 중단 후 복구 점검 (2026-10-08)

### 복구 기준과 조사 범위

사용자는 약1시간 진행 후 앱 종료/재실행에서 대화가 사라졌다고 보고했다.
현재 Git/reflog/원격 작업브랜치는1ed0bbe로 일치했고 기존 사용자4파일 외 신규 미커밋 변경은 없었다.
coverage/rules-listing 최신 실행 기록은16:23 KST의 직전 집계22건까지다.
오늘17:30의 해당 저장소 로컬 세션2개는 metadata/response/event 각1개만 기록돼 있으며
저장된 tool 실행/완료 기록은 확인하지 못했다. 이 사실만으로 대화 삭제·저장 실패의 원인을 확정할 수 없다.
조회 시 Java/Node/Dart 프로세스는 없었다. 앱 자체의 종료 원인·소실 대화 복구는 미확인이다.
이번은 로컬 조사/정적 계산이며 앱·Rules 배포·자료변경·Emulator·전체Flutter 재실행은0회다.

### 실제 연결과 위험

| 흐름/근거 | 현재 의존성 | 성급히 제거하면 생기는 문제 | 필요한 전환 |
|---|---|---|---|
| app_router209~235, MyAccountViewModel446 | 기본 command는 WeeklyRaidStatusCommand, 기본 read는 WeeklyRaidStatusRepository | 클래스 이름만 보고 구 Claim Repository 전체 삭제 시 주입/fallback 계약 단절 | 기본/주입 경로와 소비 메서드 구분 |
| WeeklyRaidStatusRepository33~135 | state/Claim/assignment 세 stream이 모두 준비돼야 결과 emit | 구자료0건이어도 get/list 거절 시 현황 오류 | 새 reader 선행, 구버전 읽기 유지 |
| AtomicCreate298~316 | 현재 주차 Claim 직접 읽고 소유권 분류 | 조회 거절 또는 유효완료 무시 | 이행 후 단일 state 기반 완료 판정 |
| OccupancyInspector36~95, AtomicApplication118/Join290/MemberMutation172 | Claim 완료·assignment 충돌·소유권 차수 확인 | 신청/승인/변경 실패 또는 완료 캐릭터 재참가 허용 | 공용 inspector의 단일 원장 계약을 먼저 고정 |
| WeeklyRaidStatusCommand123/304/649 | 완료/고아정리/완료해제에서 구자료 읽기,381/583/695에서 삭제 | 쓰기 전면 금지 시 구자료가 있는 요청만 실패 | 소비 삭제는 호환 기간 유지하거나 이행 후 앱 의존 제거 |
| Rules sealAudit/deBlockingClaim/deManualAssignmentAvailable/bug24AssignmentAvailable/bug24PrepStates | 구자료 점유/완료 및 준비 중 불변 대조 | collection match만 없애도 교차 get/exists 검사는 남음 | 단일원장 보존 근거 후 호출 단위 제거 |

공개v1.1.1의 WeeklyRaidStatusRepository는 현재와 diff0이며 동일 세 경로를 읽는다.
해당 태그 OccupancyInspector에도 Claim/assignment 조회가 존재한다.
현재 Router의 atomic application/join/member/visibility/create 연결은 유지되며 구버전=legacy writer라는
일괄 분류는 틀리다. 앱 버전 문자열 검사는 서버 차단 증거로 사용하지 않는다.

### 재현 가능한 정적 크기 계산

실행: node tools/rules_legacy_size_audit.mjs. 입력은 R1 가독본이며 compactor 결과가
17471d0f/148725bytes인지 먼저 강제 확인한다. 입력이 달라지면 중단한다.
두 legacy match의 get/list 조건을 그대로 두고 write=false로 가정한 문자열을 메모리에서만 계산한다.
함수 이름 중복을 거절하고 최대400회 이내에 신규 미참조 함수만 제거한다. Rules 파일을 쓰지 않는다.

| 계산 | bytes | 의미 |
|---|---:|---|
| R1 기준 |148725| 실제 현재 검토후보 |
| 구원장 write 금지 가정 |145575| 컴파일/권한/이행 검증 전 정적 추정 |
| 추가 감소 |3150| R1 대비 약2.12%, 추적151427 대비 누적5852/약3.86% |

제거 가정은 assignment 소비/고아삭제2함수, Claim 생성/삭제2함수와 신규 미참조 sealBlocksClaimAt이다.
assignment의 create/update는 이미false여서 신규쓰기 차단만으로 큰 절감이 생기지 않는다.
기준부터 미참조인 atomicHasGroupId는 별도 보고하고 R2 감소량에 포함하지 않았다.
이는 이전 R1 변경에서 호출이 사라진 함수로 최종 승격 전 경고0 게이트에서 정리해야 한다.
계산 뒤에도 assignmentPath/weeklyRaidClaimPath 선언·호출17개가 남는다. 이 수는 문서 접근 횟수가 아니다.
정적 문자열 참조 검사는 보수적 크기 계산일 뿐 도달성/권한 동등성 또는 compiled 크기 증명이 아니다.

결론: R2 직접 쓰기 validator 제거만으로 대폭 축소는 불가능하다. 작은 삭제·검증을 반복하지 않는다.
R2 운영 전환은 자료/호환 게이트와 함께 보류하고, 다음 단일 설계에서 §6 R3의 명령별 중복 검증을
크기·필수쓰기 책임으로 분해한다. 명시적 명령 분기, member/event의 원본 결합이 우선 조사 대상이다.
기존 count/목록/개인완료 보호를 유지하며 순환 신뢰만 남기는 삭제는 금지한다.

### R1 잔여 인수 고정

| 항목 | 판정 | 완료 근거 |
|---|---|---|
| 중첩 필드 그룹 노출 | 미확인 | 원본57필드 각각의 nested payload·그룹원 읽기 계약 대조 |
| 허용표 밖 과거 필드 | 이행 조사 필요 | 승인된 범위의 실제 자료 분류; 신규 unknown 필드는 계속 거절 |
| 구형 부분목록·공개 잔여목록 | 이행 필요 | 정상 명령/별도 정리 책임 분리; 자동 전체삭제 금지 |
| backfill 한 방 오류가 이후 방 중단 | 수정 필요 | 오류 분류·방별 진행/보고 계약; 무한재시도 금지 |
| 앱/Rules 혼합버전 | 전환 설계 필요 | 새 writer 허용·구 writer 거절·복구 순서의 게시 가능한 중간본 |
| atomicHasGroupId 미참조 | 정리 필요 | 후보 생성기에서 제거·정적 호출 검사, 최종 원격경고0 |
| 실기기/운영 게시 | 보류 | 최종 후보 승격과 새 게시 지시 후 수행 |

### 재개 시 작업 운영

대화에만 판단을 쌓지 않고 조사/계산/검증의 작은 완료 단위마다 파일에 근거를 남긴다.
장시간 실행은 제한 시간·종료 코드·출력 파일을 명시하고, 진행 중 상태와 완료를 구분한다.
기존 로그를 덮어쓰는 suites.json 하나만 완료 증거로 사용하지 않는다.
현재 실행에는 대용량 coverage 출력, 전체 회귀, 무한대기 또는 Firebase 원격 요청이 필요하지 않다.

## 19. R3 명령 책임 조사와 단일 후보 선정 (2026-10-08)

### 판정과 측정 범위

기준 커밋4863537, R1 가독본과17471d0f/148725bytes를 대조했다. 다음 로컬 구현 후보는
**완료된 반복 모집의 소유권 정리 3종(participant/peer/leader)의 원본 검증 통합**이다.
마지막1인 해산은 별도 lifecycle 경계이므로 포함하지 않는다. 앱 스키마/기능 삭제가 아닌
명령별 공통 구조 통합부터 검증하며, 효과가 작으면 대폭 축소 완료로 채택하지 않는다.

읽기전용 `tools/rules_cleanup_design_audit.mjs`는 baseline SHA를 고정하고 메모리에서만
동일한 room 조건·targetIndex 범위·revision 전환 조건을 공통 함수로 치환한다.
Rules 파일을 만들거나 수정하지 않으며 Firebase 호출도 하지 않는다.

| 비교 | 가독 함수 본문 bytes | 해석 |
|---|---:|---|
| cleanup 원본 검증 3개 | 7439 | 세 명령의 실제 공통 조건과 상이한 권한 확인 |
| 활성 캐릭터 변경 원본/member/placement 3개 | 4555 | 소유권·raidState·점유가 분산되어 단순 제거 불가 |
| lifecycle event/payload/target 검사 4개 | 3251 | 이벤트 payload와 과거 audience 보호는 고유 책임 |

위 수치는 후보군의 **선택한 함수 묶음 면적**이지 전체 명령군 크기나 제거 가능량이 아니다.
세 묶음 중 cleanup의 확인된 중복 면적과 계약 분리 가능성이 가장 커 우선 선정했다.
저장소 전체의 최대 절감 명령군임을 입증한 것은 아니다.

공통 조건만 추출한 정적 계산은148725→148099bytes, 순감소626bytes(0.42%)다.
함수 추가 비용까지 포함하며 R2 제거 가정과 합산하지 않는다. 계산 결과를 R1 후보에 적용하지 않았다.
전체 원본 검증 통합의 순감소량은 아직 미측정이다. 따라서 단순 helper 추출만을 위한 구현은
별도 완료 구간으로 진행하지 않고 다음 통합 후보 안에서 비교한다.
compiled 크기·평가식 수·문서 접근 수·게시 성공 여부는 이 계산으로 알 수 없다.

### 원본과 파생 문서 책임표

근거는17471d0f 생성 입력 `coverage/rules-listing/readable.rules`의 아래 함수명이다.
가독본은 재생성되므로 행 번호보다 함수명을 기준으로 찾는다.

| 명령 | 원본의 actor/필드/필수 결과 | 파생 문서의 고유 책임·이동 금지 조건 |
|---|---|---|
| participant 정리 | `deCleanupAggregate`: 본인 또는 현 소유권을 가진 책임자; aggregate/명령 필드만 변경; 대상 소유권 차수 증가, member 부재, group listing 전체 일치, 정해진 event 강제 | `deCleanupMemberDelete`: 동일 전환·대상 player/character·원본에서 제외. raidState 불변은 원본에서 검사 |
| peer 정리 | `dePeerCleanupAggregate`: 현 소유권의 참가자, 기존 책임자의 소유권 변경; 같은 aggregate 허용필드; **대상 member 사전 존재와 사후 부재**, listing/event 강제 | `dePeerCleanupMemberDelete`: 대상 소유권 변경과 raidState 불변을 여기서 검사. 사전 존재 검사를 제거하면 delete 없이 통과할 수 있어 이 검사를 source에서 생략하는 근거가 사라짐 |
| leader 정리 | `deLeaderCleanupAggregate`: 현 소유권 참가자, 대상은 이전 책임자; 첫 잔존 슬롯으로 승계; leader snapshot 필드 추가 허용; 후임 member의 승인권 true/현재 timestamp; 대상 member 부재, listing/event 강제 | `deLeaderCleanupMemberDelete`: 대상 일치·raidState 불변. `deLeaderSuccessorUpdate`: 후임의 현 소유권·이름/직업 snapshot·승인권/시각 외 수정 금지. 원본의 후임 playerId 검사만으로 대체 불가 |
| 활성 참가·캐릭터 변경·자리 이동 | revision/집계/허용필드와 `deChangedSlotGenerations`의 변경 슬롯 member 결합 | `deSlotMemberGeneration`은 player/character/ownershipRevision 일치만 확인. 역할·자리·시각의 모든 쓰기를 강제한다고 해석하면 안 됨. member의 placement/raidState/승인권 검사를 일괄 삭제하지 않음 |
| lifecycle 이벤트 | lifecycle 원본 검증과 event target/payload 검증 분리 | `atomicIsLifecycleCommand`는 명령 종류만 판정. `validAtomicLifecyclePartyEvent`만으로 이전 revision 대비 신규 전환·event 경로 ID 결합을 보장한다고 가정하지 않음 |
| 일반 membership 이벤트 | 생성/참가/신청/변경/제거를 넓은 event validator가 처리 | `validAtomicMembershipPartyEvent`의 형식 검사를 원본 권한 검사와 중복이라고 판정할 수 없음. 독립 위조 요청과 각 원본 writer의 결합을 별도 입증해야 함 |

정리 event는 `partyEvents/{eventId}`의 세 전용 create 함수에서 경로 ID·동일 원본 전환·정규 event map
전체 일치를 요구한다. 원본도 같은 map의 사후 존재를 요구한다. 원본은 revision+1,
expectedRevision, 현재 actor/time을 확인하므로 event 단독쓰기와 원본 재사용 거절을 보존해야 한다.
모든 공통화가 이 양방향 결합을 유지해야 한다. `!existsAfter`는 이미 없던 문서에도 참이므로
이를 무조건 'delete 쓰기 강제'로 부르지 않는다. leader와 participant는 이 차이를 다음 회귀에서 다룬다.
일반 이벤트의 결합은 미입증 사항이며 이번 조사만으로 악용 가능성이 확정된 버그라고 보고하지 않는다.

### 다음 구현 후보의 구체적 구조

1. 원본 진입은 정리 명령 세 종류를 명시적으로 분기한다. 다른 lifecycle/개인완료/준비 명령을
   fallback OR로 섞지 않는다. 기존 dispatch의 우선순위와 거절 경계를 먼저 고정한다.
2. 공통 원본 함수가 상태(schema2/active/completed/recurring),2~8인,revision/actor/time,
   target 범위, 집계 결과, member 사후 부재와 listing/event 결합을 한 번 표현한다.
3. 종류별 함수는 actor 허용 범위, command key 집합, source 변경 key 집합, 소유권 검사 위치,
   후임/책임자 조건만 담당한다. **세 종류의 허용 key를 하나의 넓은 합집합으로 허용하지 않는다.**
4. event payload는 기존 schema1과 각 종류별 정확한 key 집합을 유지한다. 읽기 audience는
   명령 전 memberPlayerIds이며 제거된 사람의 기존 이력 조회를 유지한다. payload 축소나 로컬 이력 대체는 제외한다.
5. member delete와 후임 update에만 있는 검사는 유지한다. 원본 쪽으로 이전하려면
   기존 정상/누락자료 동작, 필수 쓰기,문서 접근 예산을 먼저 비교한다. 검사 이전 자체를 감소량으로 가정하지 않는다.

실제 writer는 `firestore_completed_ownership_cleanup_repository.dart`의 `_execute`:
모집 revision 확인→재시도 receipt 확인→관찰값 재확인→모집 patch/member delete/
leader이면 successor update/group이면 listing set/event set을 같은 transaction에 넣는다.
`CompletedOwnershipCleanup`이 종류/command/event를 생성하고 로컬 journal은 재시도 관찰값을 보관한다.
Router의 RaidStatus/PartyReadDetail 연결과 recovery UI가 있으므로 죽은 코드가 아니다.
서버 권한을 로컬로 옮기지 않는다. 로컬에는 기존 결과 계산·관찰값·재시도 안내를 유지한다.
이 구간에서 없어지는 사용자 기능, 신규 데이터 이행, 구버전 차단은 없다.

### 회귀·부작용과 채택 기준

| 위험 | 다음 후보의 최소 검증 |
|---|---|
| 과도한 공통화로 타인이 정리 | 세 종류 actor 위조·관찰 차수 위조·다른 대상 player/character 거절 |
| 고아 member/raidState 검사 우회 | member 삭제 누락, 이미 없는 member, 완료 기록 수정/삭제 동반 요청을 기존 기준과 대조; unique 검사 삭제 금지 |
| 잘못된 승계/승인권 확대 | 첫 잔존 슬롯 외 승계, 후임 update 누락, snapshot 위조·다른 member 변경 거절 |
| listing/event 누락 또는 과거 명령 재사용 | group listing 누락/다른 그룹/다른 source, event 누락/ID·audience 위조, 단독 event·revision 재사용 거절 |
| 공통 함수 호출로 실행 예산 증가 | 8인 대표 정상 요청과 위조/누락 요청을 각각 평가; 한도 오류로 실패한 요청을 정상 권한 거절로 세지 않음 |
| BUG-022~024 재발 | 제거 후 listing, 역할 구성, 완료 후 다음 주 준비 경계를 변경된 공유 함수 범위에 맞춰 재검증 |
| 재진입 이중 제거 | 같은 receipt의 재시도·다른 revision 경합에서 추가 감소 없음; 앱 journal/receipt 계약 유지 |

다음 구간은 로컬 후보 하나와 해당 서버 경계까지만 진행한다. 결과는 전후 bytes/SHA, 정상·거절,
평가 오류, 미확인 compiled 효과를 구분한다. 순감소가 작거나 예산 회귀가 생기면 후보를 승격하지 않고
실패 근거를 남긴다. 동일 순서 변경을 반복하지 않는다. 롤백은17471d0f 생성 경로를 유지하며
통합 변환을 적용하지 않는 것으로 한다. 추적Rules408f163f 및 운영 성공본은 건드리지 않는다.

이번 검증은 계산 도구의 SHA/치환 assertion·실행과 diff 검토다. Flutter/Emulator 재실행 없음.
새 기능 동작은 없고 기존 앱·Rules 입력을 보존했다. 실기기와 원격 컴파일·게시 미확인,
Firebase 원격 요청0. §18의 R1 중첩필드/과거자료/backfill/혼합버전/미참조함수 인수는 여전히 남는다.

## 20. R3 정리 통합 후보 구현·미채택 (2026-10-08)

기준11c611b에서 `tools/rules_cleanup_candidate.mjs`로 정리 원본3종의 공통 상태/범위/
집계/member 부재/listing/event 검증을 한 함수로 묶었다. 종류별 actor·key·소유권·승계
검사와 member/event/state 함수는 유지했다. 정적2건에서 다른 함수 본문 전체 동일과
allow 호출 위치·순서 보존을 확인했다. 실제 앱·추적Rules·R1 생성 pipeline에는 연결하지 않았다.

후보87edb51493004c826ea57deb110edbb8faaf07a6543cbcb9cec82620ea2a1097:
148725→147542bytes, 순감소1183bytes(0.80%). compiled 크기나 게시 효과는 미확인이다.
**실행 한도 회귀로 미채택**하며 대폭 축소 완료가 아니다. 후보는 재현 도구로만 남긴다.

기존 cleanup proof 두 개에 R1 전체 원본 listing 저장과 revision 기대를 연결했다.
R3 모드는 `assertRulesDenied`로 한도 오류를 일반 거절 성공으로 세지 않는다.
실제 앱 `_execute`와 동일한 patch를 source/listing에 쓰며 예전 fixture 모드도 유지한다.
영어 JVM의 로컬 Emulator1.22.0/demo-party-group-cutover에서 동일 fixture를 대조했다.

| 검증 | R1 기준17471d0f | 통합 후보87edb514 |
|---|---|---|
| 최대8인에서 peer6명 순차 정리 | 각 명령 성공 | 각 명령 성공 |
| 이어지는 leader 승계 | 평가식1000 한도 실패 | 같은 한도 실패 |
| 활성 kick/leave, 이전 소유자 본인 정리 | 3건 통과 | 3건 통과 |
| returned owner / newer-room state / absent state | 3건 통과 | **3건 한도 실패: 신규 회귀** |
| leader removal 및 후속 advance를 포함한 복합 사례 | 한도 실패 | 한도 실패 |
| 위조/누락/경합 전체 | 정상 게이트 실패로 미실행 | 정상 게이트 실패로 미실행 |

leader removal 복합 사례는 정리·재시도·후속 advance 중 정확한 실패 연산을 아직 분리하지 않았다.
기준본도 실패했다고 R1 기능 전체의 실제 앱 장애를 확정하지 않는다. fixture와 원본 명령을
분리해서 확인해야 한다. 반면 세 단순 사례의 기준 통과/후보 실패는 채택 거절의 충분한 근거다.

설계의 정리 전용 dispatch도 한 번 대조했다(f64428ed/147601bytes).
기존 OR에서 신선한 participant/leader 정리만 분리하고 peer 분기를 유지했으나 첫 peer부터
한도 실패하여 제외했다. 실행 종류를 동적으로 계산하는 분기 비용과 공통 helper 비용을
서버 표현식 수로 아직 분리 계측하지 않았으므로 원인을 단정하지 않는다. 같은 순서 실험은 중단한다.
최종 도구는87edb514를 재생성하며 dispatch 변형은 채택하지 않는다.

근거: ignored `coverage/rules-cleanup/{candidate-test,baseline-test,participant-test,
participant-baseline-test,dispatched-test}.log` 및 manifest. 핵심 결과는 위 표로 추적 문서에 보존했다.
최초 Java 인자 quoting/샌드박스 루프백 실패는 수정하여 Emulator가 정상 실행된 뒤 측정했다.
검증 후 이번 Emulator를 종료했다. 원격 Firebase 요청0, 실기기 미실행, Flutter 무변경으로 미실행.
기존 사용자4파일·추적408f163f·R1후보17471d0f는 보존했다.

다음은 구현 확장이 아니라 **기준본 cleanup 실패 연산·평가 비용 분리 진단** 한 구간이다.
정리 직후/receipt/advance를 구분하고 한 단순 사례의 기준/후보 비용을 제한된 로그로 비교한다.
전체 coverage 대용량 수집·전체 suite 반복·권한 삭제·동일 분기 재시도는 하지 않는다.
새 명령 통합을 계속할지 더 큰 데이터 계약 전환으로 갈지는 해당 근거 후 판단한다.

## 21. R3 실패 연산 분리·fixture 계약 대조 (2026-10-08)

기준8987bc5. 이번은 진단만 수행했으며 앱/Rules/후보 생성기를 변경하지 않았다.
`tools/rules_cleanup_diagnosis.mjs`는 demo Emulator만 사용하고 각 연산 직전 동일 Rules를
다시 로드한다.90초 종료 상한·연산별 결과 즉시 저장·선택적 보고서8MiB 상한을 둔다.
`roster_peer_cleanup_proof.mjs`에 진단 전용 진입점을 추가해 전체 suite 재실행을 피했다.
진단 exit0은 관찰 완료이며, JSON의 passed:false를 통과로 세지 않는다.

### 최초 실패와 실제 writer 차이

| 분리한 작업 | 결과와 판정 |
|---|---|
| 기준본 일반 participant 정리 write | 성공 |
| 같은 명령 receipt 재조회 | 성공, already-applied |
| 이어지는 advance write | permission-denied. 이번 단일 연산 결과에는1000식 메시지 없음 |
| 기준본 peer6회 정리 뒤 leader 승계 write | source update에서1000식 한도 실패 |
| 멤버 차수만 정합화한 같은 leader 승계 | 동일1000식 실패. 차수 불일치만으로 설명되지 않음 |
| returned-owner 단일 정리, 기준/후보 | 기준 성공 / 후보 source update1000식 실패 |
| 멤버 차수를 정합화한 returned-owner, 기준/후보 | 기준 성공 / 후보1000식 실패 유지 |

§20의 'leader removal 복합 사례 실패'를 '일반 정리 자체 실패'로 해석하지 않는다.
이번 분리에서 정리와 receipt는 성공했고 최초 실패 연산은 advance였다.
과거 복합 실행의 한도 오류와 이번 재로드 후 단일 연산의 일반 거절을 같은 오류라고 단정하지 않는다.

현재 테스트 seed는 source.partySlots와 raidState 차수를1로 올리지만 member 차수를 갱신하지 않아
모든8명에서 slotGeneration1/memberGeneration0이다. 실제 `_inspect`는 이 불일치를
정리 write 전에 거절한다(`firestore_completed_ownership_cleanup_repository.dart`의 member 조회 직후).
진단의 `R3_ALIGN_FIXTURE=1`은 **로컬 demo 자료의 member 차수만** 슬롯과 맞춘 대조다.
이 보정 후에도 returned-owner 회귀와 승계 한도 실패가 유지되므로 fixture 문제만으로 면책하지 않는다.

advance fixture `roster_ownership_rules_proof.mjs:lifecycle`는 바로 transaction을 실행한다.
실제 `FirestorePartyAtomicCommandRepository.execute`는 `_certifyAdvance`를 먼저 호출해 각 대상에
guardRoomRevision/cycle/slot 인증을 기록한다. Rules `bug24AdvanceCompleted→sealPrepared`가
이를 요구하지만 옛 fixture는 그 절차를 생략했다. 따라서 이 advance 실패를 최신 앱의
전환 기능이 깨졌다는 근거로 쓰지 않는다. 이번에는 인증을 우회하거나 Rules를 완화하지 않았다.
실제 앱의 정리 transaction은 target/member/authority와 후임을 추가 조회하고 관찰값을 비교한다.
proof는 그 사전 검사를 모두 재현하지 않으므로 서버 경계 대조와 앱 end-to-end 판정을 구분한다.

### 평가 비용의 확인 범위

동일 returned-owner 입력·동일 환경에서 기준17471d0f는 통과하고 후보87edb514는
recruitment update의1000식 한도를 초과한다. member 차수 정합화 후에도 결과가 같다.
이것이 이번에 확보한 실행 비용 근거이며 정확한 식 수/증가분은 확보하지 못했다.

정적 경로 차이는 기존 aggregate1층→공통aggregate+종류별policy2층, policy 인자4개 전달,
participant 정상 경로에서 policy/listing/event를 고르는 kind 조건3곳 추가다.
검사식의 공통화가 source bytes를 줄여도 요청당 평가량을 줄인다는 보장은 없다.
이 정적 차이를 공식 실행식3개 증가나 전체 원인으로 단정하지 않는다.

단일 요청 뒤 ruleCoverage도8MiB를 넘어 수집을 중단했다. 제한을 늘리거나 대용량 원문을 저장하지 않았다.
최초 수집 예외 뒤 Node 종료 assertion도 관찰되어, 결과를 보고서보다 먼저 저장하고
보고서는 기본 비활성으로 바꿨다. 이후 단계 분리 실행은 정상 종료했다.
정확한 함수별 실행수·문서 접근수·compiled 크기·원격 게시 효과는 미확인으로 남긴다.

근거 파일은 ignored `coverage/rules-cleanup/diagnosis/`의 baseline-stages,
baseline-peer,aligned-peer,baseline-returned,candidate-returned,
aligned-baseline-returned,aligned-candidate-returned JSON이다.
재현은 R1_LISTING/R3_CLEANUP/ROSTER_TRACKED_RULES=1, ROSTER_COMPLEXITY_RULES_FILE와
R3_READABLE에 해당 기준/후보 경로, R3_DIAGNOSIS_LABEL에 결과 이름을 지정한다.
returned 비교는 R3_DIAGNOSIS_CASE=returned, 차수 대조는 R3_ALIGN_FIXTURE=1이다.
일반 연산은 새 진단 도구, peer 승계는 기존 peer proof의 진단 진입점을 사용한다.

### 다음 접근의 결정

소규모 helper 추출/명령 분기 순서 변경은 계속 중단한다.87edb514는 미채택 유지다.
다음 단일 구간은 **기존 불변 partyEvent를 이용한 정리 명령 검증 책임 재배치 설계**다.
새 collection을 추가하는 것으로 가정하지 않고, source가 해당 event의 신규 생성을 강제하고
event가 source before/after와 대상 권한을 검증하는 구조의 순감소/접근 비용을 먼저 계산한다.
event 재사용·단독쓰기·member 누락·후임 미갱신 차단을 입증하지 못하면 그 안도 제외한다.
member에만 있는 완료기록/소유권 검사를 임의로 옮기지 않는다. 이는 새 구현 승격 결정이 아니다.
큰 감소가 가능한지 평가하는 설계 구간이며 감소율이나 게시 성공을 선약하지 않는다.

기준 승계 실패는 별도 미해결 인수 경계로 유지하고 새 설계의 회귀 조건에 포함한다.
옛 fixture의 차수·advance 인증 계약 정합화도 후속 구현 검증 전에 필요하다.
운영/격리 Firebase 요청0, 앱/실기기 변경0. 이번 Emulator 종료, 입력3개 SHA와 사용자4파일 보존.

## 22. R3 기존 event 검증 책임 재배치 설계·미채택 (2026-10-08)

기준 ec89bfd, R1 가독본/축약본17471d0f. 정리 participant/peer/leader3종만 조사했다.
앱·Rules·생성 pipeline을 바꾸지 않고 `tools/rules_cleanup_event_design_audit.mjs`에서
메모리 안의 두 설계안을 계산했다. 배포 가능한 후보나 권한 동등성 검증 결과가 아니다.

### 결론과 정적 크기

| 안 | 축약 소스 bytes | 기준148725 대비 |
|---|---:|---:|
| 원본은 신규 event+전체 canonical map 확인, event는 기존 aggregate 검증 수행 | 149065 | 340 증가 |
| 원본은 신규 event+동일 모집 ID/정확한 event type 확인, canonical map은 event만 확인 | 149143 | 418 증가 |

첫 계산 SHA20ae6680d4ee44ae856adcfe68ebdbcb7c2ca7b43d79c6dd8230049067373f8d,
두 번째ad7cbc0285fef569b82b50857e72f5c74eae71a9a6dba22367af0f88f6cac0d2.
대상 aggregate의 event 조회 꼬리를 제거하고 event create의 transition 호출을 해당 aggregate
정책 호출로 대체했다. source에는 신규 event 결합 함수를 남긴다. member/state/listing 고유
검사와 기존 source 분기 호출 위치는 유지한다. 작은 envelope도 경로·type 결합 코드 때문에
더 작지 않았다. 이는 두 구체적인 안의 실측이며 모든 가능한 재설계의 하한이라는 뜻은 아니다.

**양을 줄이는 구현으로 미채택한다.** 기존 aggregate 검사는 event에 중복 구현되어 있던 것이
아니라 source에만 있었다. 위치를 옮겨도 본문은 없어지지 않는다. source 평가량 분산 가능성과
compiled 크기 변화는 미확인이며 이를 게시 해결 근거로 삼지 않는다. R3 helper/분기/단순 위치
이동 실험은 여기서 닫고, 다음에는 큰 저장·명령 계약을 없앨 수 있는 범위를 먼저 선정한다.

### 책임과 필수 동시 쓰기

| 경계 | 유지해야 할 책임 | 누락·위조 시 판단 |
|---|---|---|
| source update | 기존 바깥 분기/슬롯 차수 검사, 해당 lastCommandId event의 이전 부재와 요청 후 존재, 같은 모집·정확한 전용 type 결합 | 과거 event 재사용과 다른 방 event로 승인 불가 |
| event create | source get/getAfter, revision+1·현재 actor/time·명령 type, 기존 aggregate 전체, canonical payload 및 경로 eventId 일치 | event 단독 생성은 source revision 불변으로 거절해야 함 |
| target member delete | source 전후와 대상 player/character 결합; peer의 대상 소유권 변경·완료 state 보존, leader의 완료 state 보존 | member 검사를 source/event에 있다고 추정하여 제거하지 않음 |
| successor member update | 현재 소유권, 기존 character 및 이름/직업 Snapshot 결합, 승인권한/time만 변경 | source/event의 후임 ID·canApprove/time 확인과 함께 필요 |
| group listing | 최종 source와 동일한 canonical 문서 | revision이 바뀌므로 이전 listing 재사용으로는 통과 불가 |
| raidState | 완료 기록과 기존 상태를 그대로 보존 | 정리 명령이 완료 기록을 삭제·덮어쓰는 기능으로 바뀌면 안 됨 |

두 문서가 서로 getAfter를 읽는 구조는 정책 함수의 재귀 호출을 의미하지 않는다. 다만 데이터
연결만으로 안전성이 자동 입증되지는 않는다. 신규 생성 강제와 전용 create 분기/원본 전이
검사를 함께 유지해야 한다. 일반 event validator의 권한을 정리 명령에 재사용하지 않는다.
현재 장기 계약은 event를 명령 결과로 정의한다. 향후 채택하려면 검증 책임 변경을 계약에
명시해야 하며, 이번 미채택 설계 때문에 기존 계약 자체를 바꾸지는 않는다.

### 누락과 재시도의 중요한 한계

- event 단독/다른 방/다른 type/다른 command ID/과거 revision은 위 연결에서 거절하도록 설계했다.
  기존 event update/delete 거절은 유지한다. 이미 성공한 재시도는 앱의 receipt 조회로 종료해야 하며,
  기존 event를 다시 set하는 새 transaction을 허용하는 방식으로 멱등성을 구현하지 않는다.
- peer는 member의 exists(before)와 !existsAfter를 둘 다 요구하므로 실제 삭제 검사가 실행된다.
  participant/leader는 !existsAfter만으로 이미 없는 member도 만족한다. participant는 source에
  완료 state 검사가 있지만 leader의 state 검사는 member delete에만 있다. 따라서 **이미 없는
  leader member의 경우 state 검사가 반드시 실행된다고 주장할 수 없다.** 실제 앱 `_inspect`는
  member 존재/차수 정합을 먼저 요구하므로 앱 정상 흐름과 악의적 직접 요청을 구분한다.
- successor의 after.canApprove=true/updatedAt=request.time은 일반적인 쓰기 누락을 막는 조건이나
  실제 successor update 경로의 소유권/Snapshot 검증을 무조건 대체하지 않는다. 이미 조건을
  만족하는 데이터·같은 요청의 다른 허용 경로까지 포함한 위조 테스트 없이는 필수 update를
  완전히 입증했다고 하지 않는다. 이 한계는 위치 이동으로 해결되지 않는다.
- 같은 expectedRevision의 동시 명령은 정확한 source 전후 revision 결합으로 한 번만 적용해야 한다.
  이들 항목은 이번 **설계상의 검증 조건**이며 새 Emulator 테스트 통과 실적이 아니다.

### 8인 접근·평가 비용과 앱 영향

정리3종은 매 요청 대상1명이며 8인을 한 번에 정리하는 명령으로 바꾸지 않는다.
event가 aggregate 전체를 실행하면 기존 source before/after 조회2회 위에 다음 접근이 추가된다.
캐시를 가정하지 않는 호출식 수준의 부분 합계이며 실제 전체 실행 횟수는 미측정이다.

| 그룹방 정상 경로 | binding/currentPlayerId 호출을 제외한 event 쪽 접근식 |
|---|---|
| participant, 현재 leader가 정리, state 존재 | source2+actor character/account2+target character/account2+member after1+state exists/get/getAfter3+listing1 = 11 |
| peer | source2+actor2+기존 leader 소유권2+target member exists/existsAfter2+listing1 = 9 |
| leader | source2+actor2+target2+successor getAfter2+target member after1+listing1 = 10 |

hasActiveBinding의 exists/get 및 여러 currentPlayerId 조회는 위 수에 추가된다. 같은 경로 캐시를
기대하지 않는 프로젝트 개별쓰기10/전체20 예산을 이 설계로 입증할 수 없다. 실제 서버의 캐시
효과를 제외한 보수적 계산이므로 '실행 시 무조건 같은 횟수로 실패'라는 단정도 하지 않는다.
source의 신규 event exists/getAfter와 member/listing 검증도 transaction 전체에 남는다.
1000식 한도는 위치만 옮겨 해결된다고 할 수 없고 기존 기준 승계 실패는 계속 미해결이다.

현재 앱 writer는 source+target member delete+group listing+event, leader면 successor update를
하나의 transaction으로 쓴다. 새 컬렉션·비동기 후처리·추가 네트워크 명령은 이 안에 없다.
하지만 채택하면 event 검증 실패가 정리 전체를 막아 재인증 후 고아 관계 정리가 계속 실패할 수 있다.
이벤트 읽기/audience·로컬 receipt/history는 유지하며 로컬로 권한을 이전하거나 기능을 삭제하지 않는다.
이번 미채택으로 사용자 앱 기능·데이터·운영 Rules에 새 영향은 없다.

### 검증·후속 범위

계산 도구는 입력 SHA를 고정하고 변경 대상 외 함수 동일성·allow 선언 동일성을 assertion으로
확인한다. Node 실행/문법·diff 검토만 수행했다. Rules 파일 생성0, Emulator/Flutter/원격 요청0.
compiler 경고·compiled 크기·실행 한도·실기기·게시 성공은 미확인이다.

다음 제안은 **전체 명령·저장 계약의 대규모 삭제 가능량 선정** 한 설계 구간이다.
명령군별 전용/공유 함수 크기를 나눠 보안 검사를 통째로 삭제하는 가상치와 구분하고,
서버 중복 Snapshot/구형 쓰기 계약/표시 전용 필드를 없앨 때 실제 함께 제거되는 코드와
앱/이행/읽기 호환 비용을 비교한다. 하나의 전환을 선정하거나 대폭 감소 근거 부족을 명시한다.
이 제안은 기능 삭제 승인이나 다음 구현 착수를 뜻하지 않는다. R1 인수 잔여(§18), fixture 정합화,
기준 승계 실패, BUG-024 운영 미반영은 그대로 남는다. 작은 정리 함수 실험을 다시 열지 않는다.

## 23. 전체 저장·명령 계약의 축소 가능량 선정 (2026-10-08)

기준09bfccd/R1 17471d0f, 앱·Rules·운영 변경 없는 조사다. 재현 도구는
`tools/rules_contract_size_audit.mjs`이며 입력 SHA를 고정하고 메모리 안에서만 분석한다.
**30% 대폭 축소를 뒷받침하는 구현안은 이번에도 확보하지 못했다.** 권한 검사까지 제거한
가상 수치를 절감량으로 제시하지 않는다. 아래의 구형 쓰기 폐쇄는 유효한 후속 후보지만
대폭 축소나 게시 실패 해결을 대신하는 완료 조건이 아니다.

### 측정 방법과 전체 규모

R1은148725bytes/291함수/118allow이고 함수 선언은128506bytes다. 정적 미도달은
기존에 기록한 atomicHasGroupId1개뿐이다. 원래 추적본151427bytes의30% 감소 목표를
만족하려면105998bytes 이하, 즉 현재 R1에서 **추가42727bytes**가 줄어야 한다.
일괄 dead-code 삭제나 표시 검증 몇 개로 도달할 규모가 아니다.

allow에서 호출 그래프를 따라 특정 저장 경로의 쓰기만 참조하는 함수와 다른 allow도 사용하는
함수를 구분했다. '전용'은 그 경로를 통째로 닫았을 때 호출자가 없어지는 선언이며, 기능을
보존한 채 지워도 된다는 뜻이 아니다. 값은 고정된 현재 식별자의 선언 크기이고 allow/대체 검사
크기는 제외했다. 공유 열과 별도 target 표는 중복되므로 더하지 않는다.

| 저장·명령 계약 | 전용 함수 bytes | 공유 함수 bytes | 큰 삭제를 바로 채택하지 않는 이유 |
|---|---:|---:|---|
| 모집 member 쓰기 | 10615 | 7964 | 참가·캐릭터·자리·승계·승인권한·소유권·완료 보호를 다른 곳에서 다시 구현해야 함 |
| 공용 partyEvent 쓰기 | 5519 | 5517 | 과거 완료 이력·audience와 준비 변경의 state/Claim 보존 책임이 있음 |
| 구 assignment/Claim 쓰기 | 2760 | 1722 | 기존 reader와 개인 완료의 소비 삭제 계약이 남음; §18 실제 폐쇄 계산3150bytes와 측정 범위가 다름 |
| R1 group listing 쓰기 | 2324 | 554 | 그룹 목록이 listing으로 직접 표시됨; 전부 없애면 reader/쿼리 전환 필요 |
| 그룹 member/joinRelation/Player relation/membershipState 쓰기 | 15111 | 1534 | 가입·신청·초대·그룹 수 제한·권한·양방향 조회·승계가 포함된 전체 정책군 |
| 수동 인증 request/block 쓰기 | 7868 | 637 | 운영 검토·분쟁·방어·소유권 이전의 실제 기능이며 단순 표시 검증이 아님 |

target/slot 탐색과 event 대상 대조8함수는3387bytes다. 이 중 일부가 member 전용과 겹치므로
member+이8함수의 합집합은13548bytes(현재 전체 약9.11%)다. 이 수치는 해당 선언을 전부
제거하는 극단적인 경계일 뿐, source 안에 섞인 다른 코드까지 포함한 재설계 전체 상한이나
실제 순감소가 아니다. 대체 validator·map 형식/동일성·필수 대상 검증을 넣으면 더 줄어든다.

### 실제 축소 가정 두 개

| 가정 | 계산 결과 | 필요한 전환과 판정 |
|---|---|---|
| 구형 validMemberCharacterChange allow 경로만 false로 닫고 새로 미참조인4함수 제거 | 148725→146125,2600bytes/약1.75% 감소 | 후속 로컬 후보로 선정. 앱 전환/회귀 검증 전 적용 금지 |
| applicantStats/blockedPlayers의 표시 Snapshot 원본 대조6개 제거 | 148725→148389,최대336bytes/약0.23% 감소 | 단독 작업으로 미선정. 타입·범위 대체 비용 전 낙관적 수치 |

첫 가정에서 제거되는 선언은 validMemberCharacterChange, recruitmentSlotPath,
recruitmentFirstPartySlotPath, recruitmentSecondPartySlotPath다. 단순 선언합과 달리 전체
소스를 다시 축약한 차이이므로 이후 함수/로컬 식별자 길이 변화도 포함한다. baseline의 기존
미참조 함수는 남겨 이번 감소량에 섞지 않았다. §18의3150과는 다른 가정이며 두 변환을 함께
측정하지 않았으므로 합산 감소량을 확정하지 않는다. 허용 요청 집합이 달라지는 전환이다.

표시6개는 신청통계의 lastCharacterName/lastItemLevel/lastCombatPower와 차단이력의
characterName/itemLevel/combatPower 복사 비교다. applicationCountSnapshot, 차단 주체·대상·
사유·관계상태·신청횟수는 유지한다. 값 대조만 없애면 자유로운 값/타입이 들어갈 수 있으므로
최소 타입·길이/범위와 mapper 방어가 필요하다. 이름을 현재 Character에서만 복원하면 당시
이력의 의미가 달라지고, 관계 문서가 재사용되면 과거 표시를 복구할 수도 없다. 전부 로컬 저장으로
옮기면 다른 기기·재설치 후 기록이 없어지므로 기능 동등한 큰 축소안으로 보지 않는다.

### 큰 저장 전환의 기능·이행 비용

| 검토안 | 보존해야 하는 계약/부작용 | 판정 |
|---|---|---|
| source의 canonical 참가자 map으로 member/slot/target 중복 축소 | 현재 members 상세 구독·승인권한·Snapshot·정리 사전조회까지 변경. map key/playerId 결합과 슬롯 유일성/직업·역할/차수/8인 상한을 서버에 남겨야 함. source 전체 갱신 충돌과 문서 크기 증가 가능 | 순감소 미입증, 구현 선정 보류 |
| raidStateTargets/commandTargets를 canonical key 집합으로 통일 | 대상1명 개인완료, 전체8명 완료/advance, 빈 대상 해산의 차이를 보존. 현재 허용하는 target 부분 identity와 신규 정확한 map 계약은 자동 동등하지 않음 | 단독 탐색8함수3387bytes 전부를 절감으로 계산 금지 |
| partyEvents를 현재 source로부터 로컬 복원 | 캐릭터 변경·멤버 탈퇴 후 과거 완료 캐릭터가 달라짐. 준비 변경의 원장 불변 검사도 사라질 수 있음 | 미채택, immutable 완료 Snapshot 유지 |
| raidListings 제거 후 원본 조회 | 그룹별 허용 쿼리·페이지 결합·정렬·오프라인·읽기 수 및 인덱스 재설계. 포인터 목록도 쓰기 검사는 남음 | R1보다 큰 효과 미입증, 미선정 |
| 그룹 관계 문서 통합 | Player별 내 그룹 목록·가입 제한·그룹별 요청함/멤버 조회를 동시에 충족해야 함. collection-group 쿼리/인덱스/읽기권한/원자 가입·탈퇴·해산 전환 필요 |15111bytes 전체를 중복 저장 비용으로 오인하지 않음, 미선정 |
| 수동 인증·분쟁을 로컬 이관/삭제 | 클라이언트가 타인 소유권·분쟁 종료를 결정하게 됨. 기능 삭제와 신뢰 모델 변경 필요 | 현재 기능 보존/Spark 전제에서 제외 |

member를 source로 옮길 경우 현재 Rules의 공개/그룹/본인 member 읽기 경계와 source 읽기 경계를
다시 대조해야 한다. 종료·고아 member의 본인 조회와 원본 부재 상황도 포함한다. R1은 source
전체를 listing에 복사하므로 새 상세 map이 목록을 통해 추가 노출되는지도 함께 검토해야 한다.
일부 Snapshot이 화면에 표시되지 않는 것과 서버 읽기 권한이 비공개인 것은 다른 문제다.

로컬에 둘 수 있는 것은 표시 포맷·정렬·추천·입력 피드백·UI용 빌드 계산이다. 이미 로컬인 것은
절감으로 계산하지 않는다. role/classKey, owner/ownershipRevision, member IDs/audience,
approval 권한, raidState 점유/완료, revision/필수 쓰기는 서버에 유지한다.

### 후속 단일 후보: 구형 멤버 캐릭터 변경 쓰기 폐쇄

실제 Router(app_router.dart:513)는 PartyAtomicMembershipCommandAdapter를 통해 atomic
mutation/removal에 연결된다. 구 FirestorePartyMembershipCommandRepository는 클래스 선언만
확인됐으며 현재 Router 연결은 없다. 다만 이 사실만으로 Rules fallback이 불필요하다고 확정하지 않는다.
기존 member allow의 우선 분기는 **characterId가 달라지는지**로 나뉘고 현재 앱 mutation은
같은 캐릭터의 역할만 달라지는 요청도 받는다. 동일 character의 역할 변경이 어느 검사를 통과하는지
명시적으로 확인해야 하며, 이 조사만으로 새 앱 버그나 정상 동작을 단정하지 않는다.

후속 범위는 R1을 기반으로 해당 fallback 한 경로만 닫은 로컬 후보와 최소 서버 경계 검증이다.
기존 앱·추적Rules에는 승격하지 않는다. 다른 세대 helper, legacy 원장 read/delete, 준비/인증,
소유권 정리, listing을 함께 변경하지 않는다. 새 schema3/참가자map 전환도 이번에 시작하지 않는다.

회귀 게이트:
1. 기준/후보에서 active 캐릭터 변경, 같은 캐릭터 역할만 변경, 완료방 다음 주 준비를 분리한다.
2. 자리 이동·승계/개인완료가 쓰는 member 경로와 신규 가입/생성 연결을 보존한다.
3. 구형 non-atomic 직접 요청은 거절하고, 현재 원본/원장 동시 쓰기 누락·타인 요청은 일반 권한 거절이어야 한다.
4. 동일 역할 요청이 기준부터 실패하거나 기존 정상 요청에 회귀가 있으면 이 후보를 승격하지 않고
   실패 경로를 기록한다. 검사를 약화하거나 unrelated 버그 수정을 합치지 않는다.
5. 과거 source/member/slotLedgerVersion 자료와 공개1.1.1 writer 영향을 대조한다. 구자료가 없어도
   구버전 종료를 버전 문자열로 강제하지 않으며 실제 허용 요청 계약으로 구분한다.

전환 시 최신 앱이 기존 자료를 읽고 새 요청만 쓰는 상태를 먼저 준비한다. 운영 구자료 분류·이행은
별도 승인 없이는 실행하지 않는다. 이번 안은 데이터 삭제가 없으나 구형 앱의 변경 요청이 거절될
수 있다. 게시 실패 시 현재 활성본 유지/확인, 자동 재시도0. 롤백은 기능 브랜치 후보 폐기이고,
운영 적용 이후에는 새 스키마 쓰기 여부를 확인한 뒤 직전 Rules 복원을 별도로 판단한다.

### 완료 범위와 남은 문제

계산 도구의 SHA·구문 구조·호출 그래프·단일 치환 assertion, Node 문법과 diff를 확인했다.
앱 기능 추가/변경0, Rules 생성/Emulator/Flutter/실기기/원격 Firebase 요청0이다.
원본과 기존 사용자4파일을 보존했다. 계산은 source 크기이며 compiled·실행 예산·게시 효과를
증명하지 않는다. R1 인수 잔여·기준 승계1000식·fixture 차수/인증·BUG-024 운영 미반영은 남는다.
다음 작은 폐쇄 후보를 진행하더라도 전체 축소 목표 미달을 별도 미완료로 계속 표시한다.

## 24. 호출 깊이 조사와 전체 계획 보정 (2026-10-08)

사용자가 최초 기획과의 정합성 검토 후 호출 깊이 조사·축소 방안을 추가 요청했다.
`tools/rules_call_depth_audit.mjs`로 추적본408f163f, R1 17471d0f, 미채택 R3 87edb514의
가독본을 각각 재축약해 SHA를 확인한 뒤 allow에서 연결되는 사용자 함수 호출 그래프를 조사했다.
allow 자체와 get/getAfter 같은 내장 함수는 깊이에 포함하지 않는다. 분기 중 가장 긴 정적
경로이며 실제 요청별 실행 식 수·compiled 트리 크기를 측정한 결과가 아니다.

| 대상 | 전체 최대 깊이 | 소유권 정리 aggregate 깊이 |
|---|---:|---:|
| 추적본408f163f | 6 | 4 |
| R1 검토본17471d0f | 6 | 4 |
| 미채택 통합87edb514 | 6 | 5 |

최장 경로 두 개는 세 입력에서 같다.

```text
validPersonalCompletionRecruitmentUpdate
 → validPersonalLastMemberCompletion
 → personalCompletionTargetsCurrentPlayer
 → personalCompletionCommandMarker → currentPlayerId → bindingPath

validAtomicGroupRecruitmentClose
 → validAtomicGroupRecruitmentCloseBody
 → personalCompletionTargetsCurrentPlayer
 → personalCompletionCommandMarker → currentPlayerId → bindingPath
```

2026-10-08 확인한 [공식 제한표](https://firebase.google.com/docs/firestore/quotas#security_rules)는
함수 호출 깊이20을 명시한다. 현재 정적6단계는 이에 근접하지 않는다. 따라서 호출 깊이 초과를
기존 활성화400/후속409·503의 원인으로 확정하지 않는다. 게시 단계 오류, 런타임1000식,
문서 접근 한도는 구분한다. 가장 깊은 함수가 실제 실패한 함수라는 근거도 없다.

반면 §21의 기준/통합 대조는 정리4→5단계와 함께 kind 분기·인자 전달이 추가되고 정상 요청이
1000식으로 실패했음을 보여 준다. 이것은 후보의 비용 회귀 근거지만 깊이1단계 증가만의
효과를 분리한 실험은 아니다. 전체 최대 깊이가 같은6이라고 실행 비용도 같다고 볼 수 없다.

### 깊이 감소 방안과 채택 조건

| 방안 | 예상 정적 효과 | 보존/실패 조건 |
|---|---|---|
| personalCompletionCommandMarker를 유일 호출자인 personalCompletionTargetsCurrentPlayer 안에 합치기 | 위 두 경로 각각6→5 예상 | 현재 호출1곳 확인. keys/type/actor/target 크기 검사·단락평가 순서를 보존. 합친 뒤 다른 경로 포함 최대값 재계산 필요 |
| validAtomicGroupRecruitmentCloseBody를 유일 호출자인 Close에 합치기 | 그룹 close 경로1단계 감소 예상 | existsAfter 선행 조건과 데이터 부재 거절, get/getAfter 시점·인자/let 제한 보존. 개인완료 경로는 이 변경만으로 줄지 않음 |
| actor/binding 관찰값을 명령 validator 내에서 한 번 확보하여 순수 비교에 전달 | 반복 currentPlayerId 경로의 호출 감소 가능 | request.auth 부재·inactive binding·다른 actor 위조 거절 유지. 파라미터/let/호출 복잡도와 전체 소스 증가 가능하므로 전역 일괄 변경 금지 |
| canonical target 표현으로 identity/자리 포함 여부를 직접 검사 | 반복 탐색 감소 후보, 깊이 감소 보장 없음 | 키 충돌·중복 자리·role/classKey·차수 검증, 필수8개 상태 쓰기 유지. 기존 R3 저장 계약 전환의 일부로만 검토 |

앞의 두 개는 함수 본문을 여러 곳에 복제하는 전역 inline과 다르다. 단일 호출 보조 함수의
경계를 없애는 한정안이며 아직 구현·정적 변환·서버 검증하지 않았다. 작은 depth 최적화를
대폭 축소의 주 계획으로 다시 승격하지 않는다. bindingPath를 모든 위치에 풀어 쓰는 방식은
중복 소스가 늘 수 있어 우선안에서 제외한다. kind 통합/분기 순서 재실험도 다시 열지 않는다.

### 깊이와 별도로 봐야 하는 반복 호출

다음6함수는 같은 하위 helper 호출문이 각각8곳 있다. 정적 호출 위치 수이며 실제 실행8회를
뜻하지 않는다. 인원수·단락평가·분기에 따라 실행 수는 달라진다.

- atomicAllEventTargetsMatch → atomicEventTargetMatches
- atomicAdvanceStateMatchesSlot → atomicAdvanceStateMatchesSlotAt
- atomicAllExpectedTargetsMatch → atomicExpectedTargetMatches
- atomicAllTargetsMatch → atomicTargetMatchesTransition
- deChangedSlotGenerations → deChangedSlotGenerationAt
- atomicPositionInSlots → atomicPositionSlotAt

이 중 event 대상/자리 identity 탐색은 canonical 표현 통일로 줄일 후보이고, 완료/전환의
필수 raidState getAfter 검증은8인 보호의 핵심이므로 횟수만 줄이려고 생략하지 않는다.
R1의 변경 슬롯만 검사하는 최적화는 이미 적용된 결과라 새 성과로 다시 계산하지 않는다.

### 실행 계획 정정

§23의2600bytes fallback 폐쇄를 다음 핵심 구현으로 바로 진행하는 순서는 재검토한다.
최초 §7의 '작은 삭제 반복 대신 구조 전환 가능성 판정'에 맞춰 **전체 전환 계획 확정**을
다음 구간으로 둔다. 목록 인수 잔여, 구형 쓰기 종료, canonical target/명령 책임 전환과
위 깊이 보조안을 한 표에서 의존성·순감소·동등성·부작용·게시 가능 중간본 기준으로 판단한다.
깊이, 소스 bytes, 반복 호출 구조, 실행 한도/권한 결과, 원격 컴파일/활성화를 독립 지표로 둔다.
예상 효과가 입증되지 않은 안은 후보로 남기고 확정 절감량에 더하지 않는다.

이번 완료는 조사·설계 기록뿐이다. 도구 입력 SHA/재귀 방지/괄호 assertion·Node 문법·diff 확인,
기존 분석/실패 근거 재사용. 앱/Rules 변경·Emulator 재실행·운영 API/게시0. 공식 문서 웹 조회만 수행.
BUG-024·기준 승계 실패·R1 잔여·대폭 축소/최종 게시 인수는 계속 미완료다.

## 25. 깊이 개선을 포함한 잔여 구간 실행 계획 (2026-10-08)

사용자가 남은 구간에 §24의 조사·개선 방안을 함께 적용하도록 지시했다. 이번 구간은
전체 실행 순서 확정이며 실제 앱/Rules 구현은 하지 않았다. 작은 개선 하나를 끝낼 때마다
별도 주 계획으로 교체하지 않고 아래 진행표의 상태만 갱신한다. Spark 무료, 기존 기능·권한·
완료 이력 보존, 앱 업데이트/자료 이행 허용이라는 최초 제약은 유지한다.

### 기준과 결과 기록

추적408f163f/151427bytes, R1 17471d0f/148725bytes, 최대 사용자 함수 깊이6을 기준으로 한다.
미채택87edb514와 event 이동안은 누적 후보에 합치지 않는다. 지금 검증된 후보의 순감소는
2702bytes(약1.78%)이고 R1 전체 인수도 끝나지 않았다. 추가42727bytes 감소 경로는 아직
입증되지 않았다.2600/3150bytes 가정이나 함수 선언 크기를 더해 목표 달성률로 보고하지 않는다.

각 구간 기록은 다음6칸을 고정한다: **입력/출력 SHA·소스 bytes / 명령별 깊이 /
반복 호출 변화 / 정상·위조·누락 결과 / 평가식·문서접근 근거 / 게시·실기기 상태**.
정확한 실행 수를 얻지 못하면 미측정으로 쓰고 정적 호출 수로 대신하지 않는다. 코드가
바뀌지 않은 기존 검증은 재사용한다. 최종 후보가 바뀌면 영향받는 서버 경계만 다시 확인한다.

### 순서와 구간별 완료 조건

| 구간 | 실제 작업·연결할 개선 | 종료 조건 / 다음 구간에 넘길 것 |
|---|---|---|
| A1 검증 기준 정합화 | 옛 cleanup fixture의 member 차수와 advance 사전 인증을 실제 writer에 맞춘다. R1 정상/실패 연산을 분리한다 | 현재 앱 계약과 맞는 fixture, 기준 실패와 신규 회귀 구분. R3 실패 후보의 재검증·재채택은 제외 |
| A2 R1 남은 안전성 |57필드 중첩 공개범위, 과거/누락/종료 목록, backfill 한 방 실패의 전파를 정리한다. 미참조 helper는 생성 입력에서 정리한다 | 방별 오류 분류·진행/보고 계약, 정상 그룹 목록/개인 완료/공개 전환 보호. 원격 실자료 항목은 E에 명시적으로 이관 |
| B 호출 구조 개선 | marker→유일 호출자 통합을 먼저 대조한다. 필요 시 close-body도 별도 변경으로 합친다. actor 조회 재사용은 반복 호출 근거가 있는 경로에만 적용 | 새 최장 경로·소스 크기 측정, 개인 마지막1인/그룹 count/타인·inactive binding/문서 부재 회귀 없음. 소스 증가·실행 회귀가 있으면 해당 변환 제외 |
| C 구형 쓰기 계약 종료 | member 캐릭터 변경 fallback 폐쇄2600bytes 가정을 검증한다. 별도 R2 작업으로 legacy read·소비delete 의존을 정리하고 폐쇄/이행안을 완성한다 | 동일 캐릭터 역할 변경·준비 변경 보존. 현재/공개앱별 허용 요청표, 데이터0건/잔존/충돌별 전환안. 구 원장 읽기·삭제를 함께 성급히 닫지 않음 |
| D 저장 표현·명령 책임 단순화 | canonical target 표현 하나를 우선 설계·proof한다. identity/자리 탐색과 중복 target 표현을 줄이고 필수 상태 검사는 유지한다 | 대체 validator까지 포함한 순감소·8인 권한/접근/평가 결과. 효과 부족이면 다른 helper 실험을 이어 붙이지 않고 전체 목표 미달/정책 선택 보고 |
| E 최종 앱·Rules·이행 묶음 | 채택된 변경만 생성 pipeline과 앱 writer/reader에 연결한다. 구·신 자료 호환, 목록 잔여자료, 이행 checkpoint/복구와 중간 게시본을 확정한다 | 네 가지 앱/Rules 조합표, 실제 자료 조사 범위, 충돌 처리, 최종 정적/자동 검증·경고 게이트. 공개앱 설치 및 운영 이행은 별도 실행 경계 |
| F 게시·운영 인수 | 최신 대상/소스 확인 후 승인된 격리 검증과 운영 적용, 활성 source 일치·사용자 실기기 인수 | 최초 실패 시 중단/진단·새 지시 전 재시도0. BUG-022/023 보존·BUG-024 완료, 최종 dev 동기화 후 전체 종료 |

A1에서 확인되는 기준 승계1000식이나 이미 없는 leader member의 완료 state 보호 문제는
결함 목록을 닫기 위한 독립 최소 수정 단위로 나눈다. fixture 보정만으로 권한을 완화하거나
실패를 정상으로 바꾸지 않는다. 해결 전 관련 기능의 통합/게시 인수는 통과 처리하지 않는다.
A2의 실제 운영 자료 점검은 로컬 샘플 검증으로 대체하지 않는다. 원격 조사 전에는 E의
차단 조건으로 남기며, 자료 이행이 필요 없다는 가정을 자동 채택하지 않는다.

B와 C는 보조 축소이며 D의 대폭 감소 가능성을 대신하지 않는다. D는 아직 구체적인
구현안 채택이 아니라 **하나의 canonical target 계약을 완성해 가능성을 판정할 구간**이다.
member 상세 전체 병합·그룹 관계 재설계·인증 기능 삭제는 D에 함께 넣지 않는다.
명령 type 분리와 target 모델은 기존 source/대상 양방향 결합을 유지해야 한다.

### 깊이 개선의 적용·제외 기준

- 단일 호출 helper를 합칠 때 명령 marker의 허용 키·actor·revision·시각·대상 크기 검사를 보존한다.
  group close는 existsAfter 선행 보호와 부재 문서 접근 동작을 확인한다. 단순히 깊이가 낮아졌다고 채택하지 않는다.
- 기존 최대6 이하를 기본 비교 기준으로 삼되 전체값뿐 아니라 변경 경로의4→5 같은 증가도 보고한다.
  B의 marker 합치기는 해당 두 경로6→5 예상일 뿐 최종 전체값을 미리 확정하지 않는다.
- actor/binding 관찰값은 같은 요청의 인증된 값을 사용한다. 외부 전달 playerId를 신뢰하는 최적화 금지.
  모든 함수 인자를 늘리는 전역 변경이나 bindingPath 본문의 전역 복제는 하지 않는다.
- D에서 줄일 것은 identity/자리의 반복 탐색과 중복 저장·검증이다. 최대8인의 필수 getAfter,
  소유권/완료/중복 참가/후임 검사를 줄이는 것은 개선으로 인정하지 않는다.
- 코드가 짧아져도 정상 요청에서1000식 오류가 발생하면 제외한다. 거절 사례의 한도 오류도
  일반 권한 거절 통과로 세지 않는다. 대용량 coverage 재수집 대신 제한된 연산별 근거를 사용한다.

### 앱·Rules 전환 순서와 복구

| 조합/시점 | 확정해야 할 동작 |
|---|---|
| 기존 앱+현재 운영 Rules | 기존 기능 기준 유지. 새 준비 변경이 이미 제공된다고 안내하지 않음 |
| 새 앱+현재 운영 Rules | 기존 호환 읽기 유지, 새 형식 전용 쓰기를 성공 가능한 것처럼 노출하지 않음 |
| 기존 앱+새 Rules | 종료할 구형 요청을 서버 계약으로 거절. 오류 안내·업데이트 경로와 필수 기능 영향 명시 |
| 새 앱+새 Rules | 채택 명령 전체와 구/신 자료 읽기·재진입·완료 이력 보존 검증 |
| 전환 Rules 활성화 전 | 데이터 쓰기 이행 시작 금지. 각 중간본 크기/권한/실제 게시 가능성 확인 |
| 자료 이행 후 활성화 실패 | 쓰기 제한/복구 계약 유지. 옛 Rules만 무조건 복원하거나 새 자료를 역복사하지 않음 |

이행이 필요한 경우 승인된 자료 분류→동결 필요성 판정→전환본 활성 확인→조건부/멱등 이행→
전후 상태 대조→최종 활성화 순서를 따른다. 구자료0건이라도 최신 조회와 신규 구쓰기 차단을
확인한 뒤0건 전환을 기록한다. 새 schema가 필요 없는 B만으로 불필요한 이행을 만들지 않는다.
읽기 원장과 UI 문구만 로컬로 옮겨 서버 권한/과거 이력을 없애는 안은 제외한다.

다음 착수는 **A1 검증 기준 정합화** 한 구간이다. 그 결과로 기준 승계 문제의 수정 단위를
확정하고 A2 이후를 이어간다. 이번 계획 기록의 검증은 문서 대조·diff 검사이며 앱/Rules/
운영 자료 무변경, Flutter/Emulator/원격 게시0이다. 전체 기획 완료나 게시 문제 해결로 판정하지 않는다.
