# 인증과 권한: 현재 사실과 목표 경계

기준/증거 수준은 [00](00-overview.md). 전체 Firebase 호출 위치는 [01](01-firebase-inventory.md), 데이터 키는 [02](02-firestore-data-model.md).

## 현재 인증 흐름 — 확인

`main → initializeAppServices → initializeFirebaseApp → AnonymousAuthInitializer.initialize → PlayerBindingRepositoryImpl.getOrCreate → FirestorePlayerBindingStore.getOrCreateActivePlayerId → recordAppLaunch`.

`FirebaseAnonymousAuthGateway.currentAuthUid`는 `FirebaseAuth.currentUser?.uid`를 읽는다. 기존 UID면 재사용하고 없으면 `signInAnonymously()`한다. binding 문서 ID는 UID지만 Player는 Firestore `.doc()`로 별도 생성한다. 신규 Player와 binding은 한 Transaction에서 생성한다. 기존 binding/player가 active가 아니면 거절한다. session은 `authUid`와 `playerId`를 모두 들고 Router로 전달된다.

현재 운영 소셜 sign-in/link, 자체 Access/Refresh 발급·회전, 실제 Firebase signOut 호출은 lib 전수 검색에서 발견되지 않았다. `FakeUserSession.signIn/signOut`은 in-memory Domain adapter이며 Firebase 로그인 UI가 아니다. Auth 상태 listener(`authStateChanges/idTokenChanges`)도 발견되지 않았다. 토큰 보관·재사용의 실제 플랫폼 동작은 이번에 실행 검증하지 않았다. 회원 탈퇴/계정 병합의 완성 흐름도 확인하지 못했다.

## 목표 정책 — 사용자 확정, 아직 미구현

비로그인으로 bootstrap/공개 목록·허용된 공개 상세를 이용한다. guest Player, 임시 UID, guest 서버 선호 설정/이력 저장은 만들지 않는다. 생성/신청/참가/내 현황/그룹 가입/게임 계정 인증/수동 인증/운영 기능처럼 사용자 식별이 필요한 액션에서 로그인 알럿을 표시한다. 알럿 이후 원래 액션 재개 여부는 미결정이다. 공개 필드 범위·필터·남용 방지/개인정보는 별도 결정이다.

Firebase 익명 인증은 제거 영향 분석 대상이다. `PlayerSession` 필수 생성자, Router의 고정 playerId, UID→Player lookup, app launch write, 내 구독, 가짜 user adapter 및 local data 소유 구분이 변경 지점이다. 새 Flutter 상태 모델은 미확정이며 기존 코드에서 null playerId를 억지 주입하는 것으로 해결했다고 가정하지 않는다. Apple/Google/Discord 계정은 gameAccount와 별도 신원이다.

## Rules와 Flutter 검증을 구분

현재 `firestore.rules` 함수는 `rf*` 이름으로 축약돼 있다. `rf2`는 활성 authBinding, `rf3`는 binding의 playerId, `rf4`는 활성 operator 판정이다. 권한 predicate 정의 및 각 allow는 Rules 근거이며 Repository의 동일 이름 검사만으로 서버 보장을 주장하지 않는다.

| 대상 | Flutter의 선행 검증/표시 | 현재 Rules의 서버 경계 | 이전 서버에서 강제할 요구 |
|---|---|---|---|
| 공개 모집/그룹 검색 | filter·캐시·본인 방 제외 | `rf199/rf201`, groups list는 active binding 필요 | 새로운 비로그인 공개 projection을 명시적으로 정의; private group/개인 필드 거절 |
| Player | UID binding 조회, lastSeenAt 기록 | self get 또는 operator, create는 binding 동시 생성 | 로그인한 내부 principal만 생성/활동 기록; guest 저장 없음 |
| 운영자 | `isCurrentPlayerOperator/loadWriteReadiness` 및 화면 분기 | `operatorAssignments` self get만, client write 금지; `rf4` | 서버에서 active 사용자/역할 재확인, 클라이언트 제공 role 불신, 역할 부여 경로 별도 설계 |
| 파티 생성/참가 | Validator, 소유 Character, occupancy, group member | 원본/member/state/event/guard/listing 관련 getAfter·ID·revision 경계 | command 단위 원자성, 로그인 actor, 소유 차수, 정원/자리/중복/주차, idempotency |
| 승인/제거/자리/캐릭터 변경 | leader 또는 `canApproveApplications`, Domain composition | 명령별 allow 및 before/after 비교 | actor별 행위 권한, 대상 scope·leader 고정석·반복 준비 상태 검증 |
| 그룹 | create/join/application/code repositories에서 binding·활성 소유 검증 | group/member/summary/relation 원자 결합·50인·50그룹·승계 | 서버 authoritative membership/role/count, 한도/초대 만료/차단과 동시성 |
| 게임 계정 | 로컬 장비 challenge 후 `_claimOwnership` | 아래 소유권 경계 한계 존재 | 서버 발급 challenge/기한/증거 재조회와 재사용 거절; trusted 소유권 이전 |
| 수동 인증 | 요청·방어·승인/강제 승인·만료 처리 | requester/owner/operator·상태·시각 검증 | 서버 workflow·권한·감사, client가 임의 승인/만료 확정하지 않도록 설계 |
| 주간 완료 | `WeeklyRaidStatusCommandRepository` 소유 상태와 영향 조회 | state/claim/멤버/방 이벤트 consistency | 원자 완료와 pending 신청 정리, 권한과 stale 관찰 검증 |

근거: [Rules](../../firestore.rules), [operator Repository](../../lib/features/operator_access/data/repositories/firestore_operator_access_repository.dart), [atomic command](../../lib/features/recruitment_list/data/repositories/firestore_party_atomic_command_repository.dart), [group runner](../../lib/features/group/data/repositories/group_command_runner.dart).

### 확인된 보안상 이전 주의점

`gameAccounts/characters/playerGameAccounts`의 read는 `request.auth != null`이다. `characterIdentityClaims`는 인증된 사용자 read/write 전체 허용이고 `playerGameAccounts` delete도 인증 여부 조건이다. 이 사실은 공개/인증 정책을 그대로 옮기면 안 되는 근거다. 다른 write predicate의 ownership 검증과 혼합해 전체 소유권 보호가 완전하다고 결론내리지 않는다. 원문 allow와 [로컬 검증 Gateway](../../lib/features/account/data/gateways/local_game_account_verification_gateway.dart)를 함께 검토해야 한다.

LocalGameAccountVerificationGateway의 challenge는 `_activeChallenge` 메모리, 시작/확인시 Lost Ark 응답 조회·장비 비교다. 신뢰 서버 challenge의 증거 검증을 Rules가 실행하는 구조가 아니다. 요청자가 관찰 결과를 위조하는 모델을 신규 서버 pytest에서 별도 거절해야 한다. 현재 구현은 이번에 수정하지 않았다.

## 신규 시작 정책과 세션 설계

사용자는 기존 Firebase 사용자·데이터를 이관하지 않고 빈 신규 서버로 시작한다고 확정했다. 기존 UID/Player/provider 연결·분실자 복구·기존 operator 승계는 제외한다. 위 표는 현재 코드 분석이며 신규 정책의 승인 목록이 아니다.

신규 user/provider identity/session, OAuth 검증·Access/Refresh·로그아웃/권한 회수·게임 소유권 재인증은 [11 인증 설계](11-auth-and-access-design.md)를 따른다. 공개 필드와 로컬 보존/격리 등 제안·미결정은 [09 결정 기록](09-migration-decisions.md)에 둔다. 기존 Firebase 실제 삭제와 Flutter 로컬 데이터 파괴적 초기화는 승인/실행하지 않았다.
