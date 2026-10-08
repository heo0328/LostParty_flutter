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
