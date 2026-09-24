# BUG-022 미완료 버그 수정 설계

## 1. 목표와 제약

이 설계는 BUG-022에서 남은 세 문제를 Firebase Spark 범위 안에서 분리해 해결한다.

1. 그룹 전용방 탈퇴·추방 후 재가입의 Rules 1,000식 초과
2. 앱 재설치 뒤 새 익명 AuthUid·PlayerId가 생겨 기존 LOSTPARTY 사용자 상태를 복구하지
   못하는 문제
3. 다른 사람이 사용하던 원정대의 소유권을 정상 이전받았을 때 이전 Player의 신청·참가
   상태가 Character에 잔존하는 문제

고정 제약:

- Cloud Functions, Admin SDK, Blaze 전환과 결제 연결은 현재 구현 범위에서 제외한다.
- 권한·Character 소유권·주간 완료·그룹 접근·원자성 조건을 삭제하지 않는다.
- 원정대 소유권만으로 두 LOSTPARTY Player를 동일인으로 간주하지 않는다.
- 이전 Player의 그룹, 파티장 지위, 알림과 과거 완료 이력을 새 Player에게 복사하지 않는다.
- 한 작업 그룹에서 재가입 Rules와 계정/소유권 스키마를 동시에 구현하지 않는다.

신뢰 서버 참가 명령은 아래 무료 범위 재설계가 보안 계약을 유지한 채 Emulator 한도를
통과하지 못하고 사용자가 결제·운영 변경을 별도로 승인한 경우에만 재검토한다.

## 2. 작업 그룹 C — Spark 재가입 Rules 통합

### C1. 원인과 설계 원칙

현재 한 가입 Transaction을 모집 update, membership create, raidState create, event create와
그룹 listing update의 Rules가 각각 긴 validator로 다시 판정한다. 공개방은 통과하지만
그룹방의 현재 membership 확인이 더해지면 요청 전체가 1,000식을 넘는다.

다음 수정은 조건을 제거하는 최적화가 아니라 검증 책임을 한 번씩만 배치하는 재설계다.

- 모집 update: 참가 명령의 권위 있는 정책 validator
- membership·raidState: 같은 모집 update 결과에 결합되는 직접 Projection validator
- event·listing: 같은 revision과 최종 모집 Snapshot에 결합되는 Projection validator

각 문서는 단독으로 쓰면 실패해야 하며, 전체 Transaction에서는 동일 정책을 여러 번
재계산하지 않아야 한다.

### C2. 모집 update의 권위 있는 검증

가입 전용 `validAtomicJoinCommand(oldData, newData)`가 다음을 한 번만 검증한다.

- active binding과 actor Player
- 기존 모집·회차 active, 수동 모집 가능, 정원과 `expected revision`
- 직접 가입이면 actor와 신규 Player 동일 및 `directJoin` 정책
- 승인 가입이면 actor의 현재 승인 권한과 pending application 전이
- 그룹 전용방이면 현재 그룹 membership과 block 정책
- 신규 Player가 이전 멤버 목록에는 없고 변경 후 정확히 한 번 추가됨
- 신규 slot의 Character·역할·위치, 역할별 count, 직업 구성과 빈자리
- Character active·현재 소유자, 동일 레이드 active 점유와 현재 주차 완료 부재
- `memberPlayerIds`, `partySlots`, `raidStateTargets`, 인원·역할·비그룹원·pending 집계
- revision `N → N+1`과 `updatedAt == request.time`

신규 Player, Character, state ID와 slot은 변경 후 Aggregate의 결정된 가입 항목에서 얻는다.
클라이언트가 별도 명령 문자열만 맞췄다는 이유로 허용하지 않는다.

### C3. 직접 Projection 결합 검증

공통 `atomicJoinEnvelope(recruitmentId, playerId, stateId)`는 전체 정책을 다시 호출하지 않고
다음 값만 확인한다.

- 요청 전 모집이 존재하고 revision이 `N`, 요청 후 `N+1`
- Player가 요청 전 멤버에 없고 요청 후 Aggregate의 신규 가입 항목과 일치
- 신규 slot·target의 Player/Character/state가 서로 일치
- 모집 `updatedAt == request.time`, lifecycle 명령 아님

membership create는 envelope과 다음 필드만 검증한다.

- 경로 Player, Character, role, party/slot 위치가 신규 slot과 일치
- `joinedAt`·`updatedAt == request.time`, 승인 권한 false
- 직접 가입/승인에 따른 `joinedBy`가 actor와 일치

raidState create는 envelope과 다음 필드만 검증한다.

- 결정적 state ID, 경로 Player와 Character
- 모집 raid/cycle/difficulty, active/party/revision 1
- membership Character와 일치

Character 소유권·주간 완료·그룹 접근과 구성 정책은 모집 validator에서 이미 검증한다.
Projection validator는 같은 모집 update가 없으면 envelope에서 실패하므로 단독 위조 쓰기를
열지 않는다.

listing은 `getAfter(recruitment)`의 전체 Snapshot 및 같은 revision과 일치해야 한다. event는
결정적 ID, `memberJoined`, 같은 revision, actor·audience만 검증한다. 두 Projection이 빠진
요청은 모집 공개 범위와 정책에 따라 거절한다.

### C4. 회귀 보호와 실패 시 처리

먼저 다음 거절 fixture를 만들고 그 뒤 정상 요청을 연다.

- 모집 update 없이 membership/raidState/event/listing 단독 생성
- membership, raidState, event 또는 group listing 중 하나 누락
- 비그룹원, block 대상, 타인 Character, inactive Character
- 기존 active/completed raidState 또는 주간 Claim
- stale revision, 만석, 역할/count/slot/target/listing 위조
- 직접 가입 actor 위조, 승인 권한·application 상태 위조

허용 fixture:

- 공개방 최초 가입·탈퇴 후 재가입
- 그룹방 최초 가입·탈퇴/추방 후 재가입
- 공개/그룹 신청 승인
- 정상 초기 방 생성, 자리 이동, Character 변경, 탈퇴·추방, 2/4/8인 해산

검증 순서:

1. 현재 실패 fixture와 기존 성공 기준을 수정 전 한 번 고정한다.
2. 새 validator를 기존 allow에 연결하지 않은 상태에서 정적 계약을 작성한다.
3. 모집 validator를 연결하고 위조 recruitment update가 모두 거절되는지 확인한다.
4. Projection validator를 하나씩 연결하며 단독/누락 위조를 확인한다.
5. 전체 production Rules Emulator를 한 번 실행한다.
6. 정상 그룹 재가입이 여전히 1,000식을 넘거나 보안 거절이 열리면 제품 diff를 전부
   되돌리고 실패 근거만 기록한다. 같은 형태의 OR 순서·일부 조건 삭제를 반복하지 않는다.

### C5. 완료 조건

- 그룹방 정상 재가입과 모든 위조 거절이 같은 전체 Emulator 실행에서 통과한다.
- A1 해산, A2 추방·탈퇴와 기존 주요 파티·그룹 흐름이 회귀하지 않는다.
- Rules 컴파일 경고가 0개이고 추적 Rules만 운영에 한 번 배포한다.
- 사용자가 디바이스에서 `탈퇴 → 재가입 → 본인 탈퇴`, `추방 → 재가입`을 확인한다.

## 3. 작업 그룹 D — 재설치 후 동일 Player 복구

### D1. 원정대 인증과 사용자 복구 분리

원정대 인증은 Character 사용권을 증명하지만 과거 LOSTPARTY Player와 동일인임을 증명하지
않는다. 따라서 이미 새 익명 계정이 만들어진 뒤 원정대만 재인증한 상태에서 기존 Player를
자동 병합하지 않는다.

향후 재설치에 대비한 기본 복구 방식은 익명 Firebase 사용자를 복구 가능한 로그인
제공자 계정에 link하는 것이다. 재설치 뒤 같은 제공자로 로그인하면 같은 Firebase 사용자
UID와 기존 `authBindings/{uid}`를 사용하므로 Player·그룹·파티 이력을 이전할 필요가 없다.

### D2. 구현 범위

- 계정 화면에 `계정 복구 설정`과 연결 상태를 제공한다.
- 지원 제공자는 Android 우선 Google 로그인으로 시작하고, 플랫폼 확대 시 Apple/Email을
  별도 승인한다.
- 익명 사용자는 현재 Firebase user에 credential을 link한다. 새 Firebase user를 먼저 만든
  뒤 Player 데이터를 복사하지 않는다.
- 재설치 후에는 신규 익명 Player 생성 전에 `기존 계정으로 복구` 진입점을 제공한다.
- 동일 credential이 이미 다른 Firebase user에 연결돼 있으면 자동 병합하지 않고 명확한
  충돌 안내를 표시한다.
- AuthUid, 토큰과 provider 식별자는 일반 화면·로그·Firestore 공개 문서에 노출하지 않는다.

이미 재설치해 기존 익명 credential을 잃은 사용자는 자동 복구할 수 없다. 기존 Player
재연결은 별도 운영자 신원 확인 절차가 마련되기 전까지 지원하지 않으며 원정대 인증으로
우회하지 않는다.

### D3. 검증

- 익명 계정에 제공자 연결 후 앱 데이터 삭제·재설치, 같은 UID/Player 복구
- 연결 전 기존 그룹·파티·완료 이력 보존
- 신규 사용자 로그인, 잘못된 제공자, 취소, 네트워크 실패와 credential 충돌
- 복구 시 새 Player·중복 authBinding이 생성되지 않음
- 기존 익명 전용 사용자의 정상 시작 흐름 보존

## 4. 작업 그룹 E — 타인 원정대 소유권 이전 안전화

### E1. 세대값 계약

GameAccount와 Character에 단조 증가하는 `ownershipRevision`을 둔다. 실제
`ownerPlayerId`가 바뀔 때만 증가하고 같은 Player 재인증에는 증가하지 않는다.

신규 application, membership과 raidState는 생성 당시 `ownerPlayerId`와
`ownershipRevision`을 Snapshot으로 저장한다. 승인·가입·Character 변경·완료는 현재
Character의 두 값과 Snapshot이 모두 같을 때만 진행한다. A→B→A 이전에서도 과거 A의
문서가 다시 활성화되지 않는다.

### E2. 승계 금지와 지연 정리

- 새 소유자는 이전 Player의 그룹 membership, 파티장/승인 권한, 신청, 알림과 완료 이력을
  승계하지 않는다.
- 소유권 이전 Transaction에서 이전 Player의 모든 문서를 순회하지 않는다.
- 이전 revision의 pending application은 승인할 수 없고 `ownershipChanged`로 정리한다.
- stale membership은 정상 파티원 또는 파티장의 제한된 정리 명령으로 membership과 연결
  active raidState를 원자 제거한다.
- stale 파티장이면 기존 승계 규칙으로 책임자를 넘기고 마지막 1인이면 해산한다.
- 이전 Player의 stale state는 새 소유자의 현재 점유로 간주하지 않지만 감사 없이 임의
  삭제하지 않는다.

### E3. 기존 데이터와 배포 순서

1. revision 필드와 legacy 판정 계약을 먼저 문서·Domain에 추가한다.
2. 같은 Player 재인증과 실제 소유권 이전의 revision 전이를 Emulator로 고정한다.
3. 신규 application/membership/raidState에 Snapshot을 dual-write한다.
4. 읽기·승인·가입 명령에서 최신 revision을 판정하되 legacy 문서는 현재 소유자가 같고
   초기 revision인 경우만 허용한다.
5. stale 신청·일반 멤버·파티장 정리 명령을 각각 별도 구현한다.
6. 새 앱과 Rules를 함께 배포한 뒤 신규 데이터가 충분히 전환된 시점에 legacy 허용 종료를
   별도 결정한다.

기존 운영 데이터의 일괄 수정은 하지 않는다. backfill 필요성은 읽기 전용 영향 집계 후
별도 승인한다.

### E4. 검증

- 같은 Player 재인증에서 revision 유지
- A→B 이전과 A→B→A 재이전
- revision 없는 legacy application/membership/state
- stale pending 승인 거절과 명시적 정리
- stale 일반 멤버 제거, stale 파티장 승계와 마지막 1인 해산
- 새 소유자의 정상 신규 신청·가입과 이전 Player의 명령 거절
- 타인의 그룹·모집·과거 기록 비공개 및 자동 승계 없음

## 5. 전체 실행 순서

1. C: Spark 재가입 Rules 통합 설계·구현·전체 회귀
2. C 운영 Rules 배포와 사용자 실기기 확인
3. D: 재설치 예방·복구용 인증 제공자 연결
4. D 실기기에서 재설치 복구 확인
5. E: ownershipRevision dual-write와 stale 차단
6. E 제한 정리 명령과 legacy 종료 판단

C, D, E는 각각 별도 작업 그룹과 커밋·검증·배포 단위로 유지한다. 앞 단계의 완료가 다음
단계의 보안 조건을 자동으로 충족한다고 간주하지 않는다.

