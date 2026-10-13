# BUG-024 서버 트랜잭션 후속 설계

> 원본 문서: `docs/architecture/RECURRING_CYCLE_SERVER_TRANSACTION_DESIGN.md` · 이동일:2026-10-13. 기존 서비스의 보관 문서이며 신규 서버의 실행 기준이 아니다.

2026-10-07. 상태: 설계 후 구현 진행 지시를 받았으나 **사용자 Spark 유지 결정으로 서버안 중단**.
기존 목적 브랜치 `fix/recurring-next-week-character-change`를 재사용한다.
[준비 변경의 제품·저장 계약](RECURRING_NEXT_WEEK_CHARACTER_CHANGE_DESIGN.md)은 유지한다.
설계 승인은 기존 계획 §5의 구조 변경 제외를 서버 처리 설계에 한해 확장했다.
이후 구현 진행 지시를 받았지만 결제 연결·유료 플랜 전환까지 승인받은 것으로 해석하지 않는다.

## 구현 착수 전 확인한 운영 전제 — 결정 필요

2026-10-07 운영 API를 읽기 전용으로 조회했다. Firestore는 `asia-northeast3`의 Native DB이며,
Cloud Billing 응답은 `billingEnabled=false`다. Functions v2 목록 조회는 API 미사용/비활성 403으로
실패했다. 이것은 Functions 목록이 비어 있다는 확인이 아니다. API 활성화·결제 연결·배포는 하지 않았다.

[기존 명령 계약 §1](FIRESTORE_PARTY_COMMAND_CONTRACT.md)은 별도 지시 전 Spark만 사용하고
결제수단 연결·유료 플랜·초과 과금 가능 기능·Functions를 제외한다.
[기존 신뢰 서버 설계 §2](TRUSTED_PARTY_JOIN_COMMAND_DESIGN.md)도 Blaze/결제 및 운영 전제 결정을 요구한다.
Cloud Functions는 로컬 에뮬레이션과 달리 운영 배포에 Blaze가 필요하다.
[Firebase 공식 조건](https://firebase.google.com/docs/functions/get-started).

이 비용 전제를 후속 설계 승인 전에 해소하지 못한 것은 설계의 누락이다.
설계 승인과 일반 구현 진행 지시를 유료 전환 승인으로 취급하지 않는다.
사용자는 Spark 무료 유지·현재 서버안 중단·무료 대안 재설계를 선택했다.
[무료 대안 설계](RECURRING_CYCLE_SPARK_ALTERNATIVE_DESIGN.md)가 현재 기준이다.
선택은 Blaze 도입을 전제로 한 로컬 구현·검증(운영 설정·배포 별도) 또는 Spark 유지와 무료 범위 재설계다.
Spark 유지 시 클라이언트 proof를 신뢰하거나 권한 검사를 완화하는 방식은 대안으로 사용하지 않는다.

## 전환 근거와 검증 한계

추적 후보 `013051c`의 Rules는 운영에 게시하지 않았다. 현재 후보는 배포 불가다.
[Actions 37570086691](https://github.com/heo0328/LostParty_flutter/actions/runs/37570086691)에서
BUG-024 30개 중 22개 성공, 8개 실패했다. 기록 없는 대상의 8인 준비·연속 변경은 진행되지만
전환에서 접근 오류가 발생한다. 완료 기록이 있는 대상은 준비 변경 단계에서도 접근 오류가 발생한다.
실패한 정상 시나리오를 권한 거절 성공으로 집계하지 않는다.
BUG-023 회귀 검증의 기존 normal-advance도 실패했고, 기존 8인 제자리 캐릭터 변경 성공 후 7인 빈자리 fixture로 넘어가
빈자리 이동에서 1000식 평가 한도에 걸렸다. 따라서 다음 구현은 이 회귀를 함께 해소해야 한다.

[격리 진단 37569949642](https://github.com/heo0328/LostParty_flutter/actions/runs/37569949642)은
실제 대상의 legacy 점유/Claim 경로를 진단용 공통 경로로 대체해 고유 문서 접근만 줄였다.
원본·점유만 공유·Claim만 공유는 실패하고 둘 다 공유한 경우에만 첫 8인 전환·전체 완료가 성공했다.
이는 문서 접근 예산이 병목이라는 근거다. 정확한 실제 접근 횟수를 측정한 것은 아니다.
진단 Rules는 실제 대상의 점유/Claim을 보호하지 않으므로 제품 수정안으로 사용할 수 없다.

Rules는 원자 요청 전체와 각 쓰기에 문서 접근 제한을 적용한다.
서버 SDK는 Rules를 거치지 않으므로 서버에서 권한과 불변식을 직접 검증해야 한다.
[공식 Rules 문서](https://firebase.google.com/docs/firestore/security/rules-conditions).

## 범위와 현재 연결

서버 처리 대상은 **완료 반복방 준비 캐릭터 변경과 advanceCycle** 두 가지다.
완료 대상의 준비 변경도 한도 실패했으므로 전환만 옮기는 안은 충분하지 않다.
진행 중 캐릭터 변경·자동 이동·전체 완료·해산·반복 설정·모집/신청/즉시 참가는 기존 계약을 유지한다.
복구키, 고아 관계 일괄 정리, 자동 참가자 제거, 완료 취소, 데이터 일괄 이전은 제외한다.

현재 `lib/app/router/app_router.dart`는 `FirestorePartyAtomicCommandRepository`와
`PartyAtomicCycleCommandAdapter`, `FirestorePartyAtomicMemberMutationRepository`를 조립한다.
cycle adapter는 슬롯으로 targets를 만들고 클라이언트의 다음 주차 창을 envelope에 넣는다.
atomic Repository는 authBindings·모집을 읽지만 전환 대상 state는 읽지 않고 upsert한다.
새 서버는 이 클라이언트 정보를 권한의 근거로 사용하지 않는다.
로컬 firebase.json에는 Functions 설정이 없고 pubspec에는 cloud_functions/App Check 연결이 없다.
운영 DB 리전·결제 연결은 위 착수 전 확인 결과를 따른다. Functions 목록·할당량·IAM 상태는 미확인이다.

## 명령 경계와 앱 연결

Firebase callable의 두 동작을 구현 대상으로 한다. 이름은 구현 시 충돌 확인 후 확정한다.

| 동작 | 최소 입력 | 서버 판단 |
|---|---|---|
| prepareCharacterChange | requestId, recruitmentId, expectedRevision, expectedCycleKey, 기존 characterId, 새 characterId, 선택 role/자리 | 본인 membership, 완료 반복방 여부, 소유권·자격·구성·점유 |
| advanceCycle | requestId, recruitmentId, expectedRevision, expectedCycleKey, 요청 nextCycleKey | 방장 권한, 현재 슬롯 전체, 서버 현재 주차, 최신 소유권·점유 |

추가 필드·잘못된 형식·중복 대상·8인 초과는 거절한다. actorPlayerId, targets, 시간,
소유권 차수, 완료 상태, 쓰기 patch를 클라이언트가 결정하도록 허용하지 않는다.
인증 UID에서 활성 authBindings의 playerId를 얻고 실제 참가자/방장 권한을 검증한다.
익명 로그인도 이 검증을 그대로 사용한다. App Check는 사용자 권한 검사를 대체하지 않는다.
[callable 인증 계약](https://firebase.google.com/docs/functions/callable).

공개 Domain 명령/결과 인터페이스는 유지하고 data adapter와 Router DI에서 연결한다.
advanceCycle은 서버로 보내며 반복하지 않는 방의 incompleteEnd는 기존 경로를 보존한다.
캐릭터 변경은 조회 시점의 목적과 revision을 고정해 준비 요청을 서버로 보낸다.
진행 중 요청은 기존 경로를 유지하되 상태가 바뀌면 충돌로 종료한다. 준비/진행 모드로 자동 재실행하지 않는다.
서버도 모드·revision을 새로 읽어 확인한다. 네트워크/서버 실패 시 직접 Firestore 쓰기로 우회하지 않는다.
findAggregate와 실시간 구독은 기존 읽기를 유지하며 callable 응답 후 구독/재조회로 최신 상태를 표시한다.

## 트랜잭션의 읽기·검증·쓰기

모든 참조는 서버의 canonical ID 함수로 생성하며 모든 읽기를 쓰기보다 먼저 수행한다.
타임스탬프와 주차 창은 서버 시계로 계산한다. 운영 경계는 KST 수요일 06:00, 7일이며
Dart 정책과 공통 경계 fixture로 일치시킨다. 클라이언트 테스트 초기화 설정은 운영 서버에 전파하지 않는다.
현재 회차보다 늦은 서버 현재 회차로만 전환하며 미래 주차·동일 주차·이미 지난 요청은 거절한다.
현재 active 회차의 정상 넘김과 completed 회차 넘김은 기존 계약대로 각각 처리한다.

| 동작 | 읽기 집합 | 원자 쓰기 집합 |
|---|---|---|
| 준비 변경 | binding, 모집, 본인 membership, 이전/새 캐릭터와 계정 소유권, 이전/새 state·현 회차 Claim, 새 대상 legacy 점유, 필수 목록, 영수증/이벤트 | 모집 구성·다음 targets·인원/방장 캐릭터 표시, 본인 membership, 기존 필수 목록, characterChanged 이벤트, 영수증 |
| 전환 | binding, 모집, 최신 슬롯 최대 8개의 membership·캐릭터·계정·state·대상 주차 Claim·legacy 점유, 필수 목록, 영수증/이벤트 | 모집 회차·명령 표식, 현재 슬롯의 state, 기존 필수 목록, cycleAdvanced 이벤트, 영수증 |

슬롯과 membership의 player/character/role/ownershipRevision 일치, 중복 부재와 최대 8인을 검사한다.
필수 그룹 목록은 원본의 기존 revision·식별자·구성과 일치해야 하며 없거나 불일치하면 전체 거절한다.
새 목록을 만들거나 타인 슬롯을 자동 교환하지 않는다. 공용 목록 writer의 다른 명령은 변경하지 않는다.
서버 검증기와 서버 Write Plan은 읽은 snapshot에서만 값을 만들고 임의 patch를 받지 않는다.
읽기 수는 최대 8인으로 제한하며 전체 컬렉션 조회나 다른 방 일괄 탐색은 하지 않는다.

준비 변경은 본인 한 명만 바꾼다. 공대장 고정석·본인의 유효 빈자리 이동·레벨/전투력/역할 구성
제한을 유지하고 동일 캐릭터의 역할만 변경하는 기능은 추가하지 않는다.
이전 state가 없는 A→B→C도 현재 membership과 이전/새 소유권을 검증해 허용한다.
이번 주 완료만으로 새 후보를 제외하지 않지만 유효한 활성 점유·미확인 데이터는 거절한다.
state/Claim에는 어떤 쓰기도 생성하지 않고 완료 시각·완료자·완료 이벤트를 보존한다.
다음 주 독점 예약을 생성하지 않는다.

전환 대상별 처리는 다음과 같다. 한 명이라도 실패하면 방·목록·state 전체가 변경되지 않는다.

| 현재 대상 state | 처리 |
|---|---|
| 없음 | 검증된 현재 슬롯으로 새 주차 active state 생성 |
| 같은 방의 이전 주차 active | 기존 정상 전환 유지. 최신 소유권/점유를 다시 검사 |
| 유효한 이전 주차 completed | 같은/다른 방·역할·난이도라도 현재 슬롯의 방·역할·난이도로 전환 |
| 현재/미래 주차 completed 또는 현재 주차 Claim | 거절. 완료를 지우거나 Claim을 소비하지 않음 |
| 다른 방의 유효 active 또는 유효 legacy 점유 | 거절. 자동 정리·가져오기 없음 |
| 소유권 불일치·식별자/출처/주차 해석 불가 | 거절. 미확인 데이터를 정상으로 추정하지 않음 |

완료 기록의 유효성은 canonical character/raid/state ID, schema, source, revision, cycle 및
현재 소유권 차수로 판정한다. party 완료의 역할은 검증하며 실제 manual 완료 스키마의 역할 생략은
허용된 계약으로 처리한다. 과거 차수 자료는 기존 소유권 정책으로 분류하며 다른 사람 기록을 덮어쓰지 않는다.
새 state는 현재 슬롯의 ownershipRevision과 역할을 저장해 BUG-023 완료 조건을 보존한다.
통합 state는 정상 주차 전환에서 갱신되지만 과거 완료 당시 명단을 담은 이벤트는 유지한다.
기존 완료 명령 표식은 전환 규약대로 소비하며 과거 완료 이벤트는 삭제하지 않는다.

## 재진입·경합·오류

서버 전용 `partyCommandReceipts`를 최소 추가 데이터로 제안한다. client get/list/write는 모두 금지한다.
키는 UID가 아닌 안정된 playerId·operation·requestId를 안전하게 인코딩/해시해 구성한다.
operation, recruitmentId, actorPlayerId, 정규화 입력 fingerprint, 적용 revision, 결과와 서버 시각을 저장한다.
한 영수증과 업무 데이터/이벤트를 같은 transaction에 쓴다. requestId와 payload 크기를 제한한다.
기존 이벤트는 업무 이력으로 유지하며 변경하지 않는다. 영수증 삭제/TTL은 이번 구현에 포함하지 않는다.

인증·현재 binding과 호출 자격을 먼저 확인한 뒤 동일 입력의 영수증만 재사용한다.
같은 ID의 다른 입력은 invalidRequest로 거절한다. 적용 후 권한 상실 시 재호출은 권한 오류로 종료한다.
방이 더 진행됐더라도 이미 적용한 요청을 다시 쓰지 않는다. 성공 응답 유실 후 같은 ID 재시도도 1회만 적용된다.
기존 lastCommandId만으로 이후 revision의 중복을 판정하지 않는다.

소유권 이전·다른 방 점유/Claim 생성·준비 변경·전환·완료·해산은 관련 문서의 transaction 경합으로 처리한다.
문서 부재도 transaction 안에서 읽어 생성 경합을 감지한다. 자동 재시도 시 같은 전제조건을 다시 검사하며
방 revision/모드가 바뀌면 사용자 재조회로 종료한다. 서버 callback 안에서 외부 호출/로그성 쓰기는 하지 않는다.
[트랜잭션 재시도와 읽기 순서](https://firebase.google.com/docs/firestore/manage-data/transactions).

오류는 unauthenticated, bindingMissing, unauthorized, notFound, revisionConflict, cycleMismatch,
ownershipLost, occupied, stateInconsistent, invalidRequest, temporarilyUnavailable로 구분해 기존 결과로 매핑한다.
필요한 세부 reason만 추가하고 개인정보/다른 방 전체 자료는 반환하지 않는다.
로그에는 requestId·동작·단계·오류/재시도·revision을 기록하며 토큰과 개인 문서 원문은 제외한다.

## Rules·보안·구버전 영향

서버 Admin SDK의 우회 권한을 전제로 모든 정책을 서버 테스트로 검증하고 전용 서비스 계정의 IAM을 제한한다.
임의 경로를 쓰는 범용 callable이나 앱에 Admin 자격증명을 주는 방식은 사용하지 않는다.
새 callable에는 인증과 App Check 검증을 적용한다. 현재 로컬 App Check 연결이 없으므로 실제 앱 등록,
개발용 provider와 출시 앱 토큰 수신을 검증한 뒤 새 callable enforcement를 켜는 순서를 구현 계획에 포함한다.
기존 앱 전체의 App Check 강제 전환은 이번 범위가 아니다.
[Functions App Check 설정](https://firebase.google.com/docs/app-check/cloud-functions).

클라이언트 Rules에서는 준비 구성 변경과 advanceCycle을 서버 전용으로 막는다.
원본·membership·state·목록·이벤트의 기존 generic/legacy OR 분기를 포함해 직접 쓰기 우회가 없는지 검사한다.
단독 위조 state·이벤트·receipt도 거절한다. 개인 수동 완료와 기존 활성 변경의 정당한 쓰기는 보존한다.
다음 구현의 기준은 검증된 운영 Rules와 그 생성 소스다. 배포 불가 후보의 복잡한 허용 분기를 그대로
쌓지 않고 서버 전용 경계와 기존 정상 기능을 함께 검증한다. 접근 한도 해결을 위해 권한 검사를 삭제하지 않는다.

구버전 앱은 서버 전용 전환을 직접 호출하지 못하므로 Rules 전환 후 기존 advanceCycle 요청이 거절된다.
모든 전환을 서버로 이동하는 데 따른 명시적 호환성 영향이다. 새 앱에는 업데이트/재조회 안내를 넣는다.
구버전까지 즉시 같은 안내가 가능하다고 가정하지 않는다. 출시 안내와 새 APK 제공 후 전환해야 한다.
준비 기능을 임시 비활성화할 때도 기존 직접 쓰기 우회 권한을 다시 열지 않는다.

## 구현 단계와 종료 기준

1. 이 설계로 서버 두 명령·영수증·App Check/구버전 영향을 구현 범위로 확정한다.
   구현 전 DB 리전, 지원 runtime, 원격 Functions 충돌, 결제/할당량·서비스 계정을 확인한다.
2. 서버 validator/Write Plan과 Auth·Functions·Firestore emulator 연결을 구현한다.
   기존 앱 active 흐름을 건드리기 전 공통 정책 fixture와 8인 서버 경계를 검증한다.
3. Dart adapter/Router DI를 연결하고 서버 전용 Rules를 생성한다. 기존 후보의 normal-advance/빈자리 이동
   실패를 새 경로·기존 경로에서 각각 해소하며 BUG-023 전체 완료를 회귀 보호한다.
4. 정상·위조·부분 쓰기·중복·응답 유실·소유권/Claim/점유 경합·missing listing·권한 상실·주차 경계를 검증한다.
   대표 8인에서 기록 없음/같은 방 완료/다른 방·역할·난이도/manual 완료를 전환 후 전체 완료까지 검사한다.
   서버 검증은 실제 callable 인증 경계를 포함한다. Admin fixture 쓰기 성공을 권한 검증으로 대체하지 않는다.
5. Functions 배포는 AGENTS §5에 따른 별도 현재 시점 지시 후에만 수행한다. Rules도 생성 일치·계약·회귀·
   경고 0개와 배포 대상/추적본을 확인한 뒤 최신본 한 번만 시도한다. 실패 시 재배포 없이 진단한다.
   Functions 준비→새 앱 제공→서버 전용 Rules 전환의 순서와 장애 시 중단 지점을 출시 전에 확정한다.
6. 사용자가 두 실제 방에서 변경·기기 간 반영·완료 보존·다음 주 전체 완료를 확인한 뒤 버그를 종료하고
   최종 문서·검증 결과를 dev에 통합한다. 현재 설계 완료는 BUG-024 해결 완료가 아니다.

이 서버안은 중단했다. 함수 코드/의존성/Functions 초기화·배포·결제 연결을 진행하지 않는다.
