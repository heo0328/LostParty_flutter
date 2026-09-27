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

> 결과(2026-09-24): **실패·구현 원복**. 아래 설계는 실행 이력으로 보존한다.
> 권위 모집 validator와 직접 Projection validator를 구현했으나 전체 Rules CI
> `35997627746`에서 그룹 재가입 전의 기존 공개방 신청 승인부터 1,000식 한도를 넘었다.
> Projection 봉투를 더 줄이고 승인자 권한 검증은 유지한 두 번째 실행 `35998246596`도 같은
> 지점에서 실패했다. 제품 Rules·테스트 변경은 revert했고 운영 배포하지 않았다.

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

### C6. 실패 판정과 후속 결정

- 모집 문서로 참가 정책을 집중하는 방식은 그룹 재가입을 검증하기 전에 기존 공개방 승인
  흐름을 회귀시키므로 Spark 해결안으로 채택하지 않는다.
- 같은 구조에서 Projection 조건·OR 순서·target 순회를 더 줄이는 시도는 반복하지 않는다.
- C를 다시 열려면 신뢰 서버 참가 명령을 승인하거나, 현재 원자 명령·데이터 계약 자체를
  바꾸는 별도 설계를 먼저 승인해야 한다.
- 재설치 후 동일 사용자 복구와 타인 원정대 소유권 이전 후 stale 정리는 C와 원인이 다른
  하나의 상위 작업 그룹 `DE`로 관리한다. C 미해결을 명시한 상태에서도 DE의 UX·정책
  설계는 진행할 수 있지만, 아래 UX 결정 게이트를 통과하기 전에는 구현하지 않는다.

### C7. Spark 데이터 계약 대안 — 권위 Aggregate와 복구 가능한 Projection 분리

> 상태: **격리 proof 실패·채택 폐기(2026-09-27)**. Cloud Functions·Blaze를 사용하지 않는다. 기존 Rules의
> 조건을 줄이는 안이 아니라, 같은 참가 사실을 여러 문서가 각각 권위 있게 재검증하는 현재
> 중복 계약을 버전형 저장 계약으로 교체하는 안이다. 아래 proof가 통과하고 개발자가 목록·
> 상세 UX 영향을 승인하기 전에는 제품 코드·Rules·Indexes를 수정하지 않는다.

격리 Actions `36326380626`은 Transaction의 모집 단건 읽기를 proof Rules가 막은 하네스
불일치, `36326546696`은 배열 내부 `serverTimestamp()` 사용 불가로 각각 실패했다. 실제 제품
계약처럼 그룹 멤버의 단건 `get`만 허용하고, 배열 slot에는 결정적 event ID를 두며 같은
Transaction event의 `occurredAt == request.time`을 권위 가입 시각으로 삼아 두 문제를 제거했다.
그 다음 실행 `36326680954`에서 정상 그룹 직접 재가입 3-write가
`maximum of 1000 expressions`로 거절됐다. 이는 아래에 미리 정한 폐기 조건이므로 승인 4-write,
8인 크기, v2 migration과 제품 구현으로 진행하지 않는다. 이를 통과시키려고 권한·소유권·
주간 완료·그룹 접근·원자성 조건을 줄이지 않는다.

#### C7-1. 현재 병목과 변경 원칙

현재 그룹방 직접 가입은 한 Transaction에서 모집 Aggregate, membership, 개인 `raidState`,
그룹 listing과 공용 event를 함께 쓰며 각 Rules가 같은 Player·Character·slot·group·revision을
다시 검증한다. 승인 가입은 application까지 더해진다. 문서 하나의 특정 조건이 아니라 전체
요청의 중복 평가 합계가 1,000식을 넘으므로 다음 원칙으로 쓰기 책임을 줄인다.

- 참가의 권위 원본은 모집 Aggregate의 정렬된 멤버/slot과 개인 `raidState`다.
- 신청 승인에서는 pending application 전이도 같은 핵심 Transaction에 포함한다.
- 알림 누락을 막기 위해 결정적 ID의 party event도 핵심 Transaction에 유지한다.
- recruitment 하위 membership과 그룹 `raidListings`는 권위 원본이 아닌 읽기 Projection으로
  내린다. 누락·지연돼도 참가 성공, 점유, 권한과 파티 구성이 달라지면 안 된다.
- 핵심 Transaction을 여러 단계로 나누지 않는다. Aggregate만 성공하고 `raidState`가 실패하는
  부분 참가는 계속 금지한다.

#### C7-2. schemaVersion 3 권위 Aggregate

기존 `partySlots`를 Player별 권위 멤버 항목으로 확장한다. 기존 필드
`playerId/characterId/classKey/role/partyIndex/slotIndex/countedAsNonGroupMember`에 상세 화면이
필요로 하는 Character 이름·아이템 레벨·전투력·Build Snapshot·가입 주체와 결정적
`joinedEventId`를 함께 저장한다. 최대 인원 8명은 변경하지 않는다. Firestore는 배열 내부에
`serverTimestamp()`를 허용하지 않으므로 가입 시각을 클라이언트 시각으로 대체하지 않는다.
권위 가입 시각은 같은 핵심 Transaction의 `partyEvents/{joinedEventId}.occurredAt == request.time`로
보존하고, membership Projection의 `joinedAt`은 해당 event 시각으로 동기화한다.

- `memberPlayerIds`, `partySlots`, `raidStateTargets`, 인원·역할 count는 같은 순서와 크기를
  유지한다. 기존 내 현황 array query와 lifecycle target 계약을 갑자기 교체하지 않는다.
- 신규 가입 항목은 기존 `memberCount` 위치에 정확히 하나 append한다. Rules는 8개 전체를
  반복 검색하지 않고 결정된 마지막 index와 전후 크기·count만 검증한다.
- 파티장과 승인 권한은 기존 계약을 유지한다. 리더는 Aggregate의 `leaderPlayerId`, 위임 승인
  권한은 기존 membership Projection을 읽되 신규 가입자는 Projection 부재를 false로 본다.
  승인 권한 자체를 v3 Aggregate로 옮길지는 별도 proof 뒤 결정하며 임의로 제거하지 않는다.
- 문서 1MiB 한도를 안전하게 지키는지 실제 최대 8인·최대 Build Snapshot fixture의 직렬화
  크기를 측정한다. 안전 여유가 부족하면 Snapshot을 축소하지 않고 C7을 폐기한다.

#### C7-3. 가입 핵심 Transaction

직접 가입은 다음 세 문서만 원자 확정하는 것을 목표로 한다.

1. `recruitments/{id}` schema v3 Aggregate update
2. `players/{playerId}/raidStates/{characterId}_{raidId}` create
3. `partyEvents/memberJoined_{recruitmentId}_{nextRevision}` create

신청 승인은 위 세 문서에 기존 pending application update 한 건을 추가한다. Rules는 다음을
그대로 유지한다.

- active binding과 actor, 직접 가입/승인 모드 및 승인자 권한
- 모집 active 회차·revision·정원·역할·slot·동일 파티 직업 구성
- 그룹 전용방의 현재 그룹 membership과 block 정책
- active Character와 현재 owner Player
- 기존 참가·현재 주차 완료·주간 Claim 충돌
- Aggregate와 `raidState`, event, application의 Player·Character·revision 결합

membership과 listing 쓰기를 핵심 Transaction에서 뺀다는 이유로 위 조건을 클라이언트 사전
검사만 믿거나 Rules에서 삭제하지 않는다.

#### C7-4. membership Projection

schema v3 화면과 명령은 Aggregate `partySlots`를 현재 멤버·Character·역할·위치의 원본으로
사용한다. 하위 `members/{playerId}`는 구버전 읽기와 위임 승인 정보 호환을 위한 Projection으로
남긴다.

- 가입 성공 뒤 앱이 별도 멱등 sync로 membership Snapshot을 생성·갱신할 수 있다.
- Projection Rules는 현재 Aggregate의 같은 Player 항목과 정확히 일치하는 값만 허용한다.
- Projection sync 실패를 가입 실패로 되돌리지 않는다. 화면은 Aggregate로 정상 표시하고,
  다음 상세 진입·새로고침에서 같은 멱등 sync를 재시도한다.
- 탈퇴·추방 후 남은 Projection은 현재 멤버 목록으로 사용하지 않는다. 읽기는 Aggregate ID에
  포함된 항목만 채택하고, stale Projection 삭제는 별도 제한 sync로 처리한다.
- 위임 승인 권한 문서가 아직 복구되지 않았으면 false로 처리하며 권한을 추측 복원하지 않는다.

#### C7-5. 그룹 listing Projection

`groups/{groupId}/raidListings/{recruitmentId}`는 그룹방 발견을 위한 pointer로 유지한다. 그룹
멤버 가입·Character 변경·자리 이동마다 모집 전체 Snapshot을 덮어쓰지 않는다.

- 생성 시 groupId, recruitmentId, 회차와 공개 상태 등 발견에 필요한 최소 불변 필드만 쓴다.
- 목록은 pointer ID로 실제 recruitment를 읽어 현재 인원·revision·상태를 표시한다.
- 참가 성공 직후 listing memberCount가 잠시 이전 값이어도 상세와 권위 상태는 recruitment를
  사용한다. 별도 멱등 sync가 Projection을 최신화하되 기능 권한에는 사용하지 않는다.
- 해산·그룹→공개 전환의 pointer 삭제와 반복방 회차 전환은 기존 lifecycle 원자 계약을 유지한다.
- 추가 읽기 비용은 표시 중인 문서 ID만 30개 이하 묶음으로 조회하고, 기존 최대 50개 그룹
  listener보다 무제한 listener를 늘리지 않는 방식으로 측정한다. Spark 읽기 비용이 과도하면
  이 안을 채택하지 않는다.

#### C7-6. 기존 schema v2 방 전환

신규 방만 v3로 만들고 기존 방의 재가입을 방치하지 않는다. v2→v3 전환은 참가와 분리된
멱등 migration 명령으로 먼저 수행한다.

- 모집의 기존 `memberPlayerIds/partySlots/raidStateTargets/count/leader/revision` 의미를 바꾸지
  않고 membership Snapshot을 확장 slot에 복사한다.
- migration은 참가자를 추가·삭제하거나 위치·권한·회차·그룹 count를 변경하지 않는다.
- 최대 8개 기존 membership 문서를 읽어 Snapshot 일치를 검증하되 migration 자체는 모집 한
  문서만 갱신한다. Rules 문서 접근 10개와 표현식 1,000개 한도를 proof에서 먼저 측정한다.
- 누락된 legacy membership이 있으면 추측값으로 전환하지 않고 `migrationRequired` 상태를
  반환한다. 기존 v2 방은 종전 읽기·명령을 계속 사용한다.
- migration 성공 후 가입 요청을 새 Transaction으로 다시 실행한다. migration만 성공하고
  가입이 실패해도 멤버·점유는 변하지 않으므로 부분 가입이 아니다.
- 외부에 남은 구버전 앱이 v3 방을 잘못 쓰지 않도록 최소 앱 버전·dual-read 기간과 v2 쓰기
  종료 시점을 개발자가 승인한 뒤 정한다.

#### C7-7. 영향과 회귀 대응

| 영향 | 발생 가능 문제 | 필수 대응 |
|---|---|---|
| 모집 문서 크기 증가 | 최대 Snapshot에서 1MiB 접근 | 8인 최악 fixture 크기 측정, 여유 부족 시 폐기 |
| membership 지연 | 구버전 상세·승인 UI가 멤버를 누락 | v3 dual-read와 멱등 sync를 먼저 배포, Aggregate fallback |
| listing 지연 | 그룹 목록 인원·revision이 잠시 stale | 실제 recruitment를 표시 원본으로 사용, pointer는 발견에만 사용 |
| 추가 recruitment 읽기 | Spark 읽기량 증가 | 표시 page만 batch 조회, listener/read 계측과 상한 설정 |
| v2/v3 공존 | 명령이 잘못된 저장 계약 사용 | schema별 Repository/Rules 분기와 v2 회귀 고정 |
| migration 중 실패 | 일부 Snapshot만 전환될 위험 | 모집 한 문서의 원자 update, 실패 시 v2 유지 |
| Projection 위조 | 클라이언트가 상세·listing 조작 | Aggregate와 exact-match하는 sync Rules만 허용 |
| 알림 누락 | event를 후처리하면 유실 | party event는 핵심 Transaction에 유지 |
| 배열 내부 가입 시각 | `serverTimestamp()` 사용 불가·클라이언트 시각 위조 | slot은 결정적 event ID를 저장하고 event의 `request.time`을 권위 시각으로 사용 |

#### C7-8. 구현 승인 전 proof 순서

1. 제품 파일과 분리된 proof Rules/fixture에서 v3 직접 가입 3-write와 승인 4-write를 만든다.
2. 공개·그룹 최초 가입, 탈퇴·추방 후 재가입과 신청 승인을 성공 기준으로 둔다.
3. 타인 Character, 비그룹원, block, Claim/active state, 만석, slot/count/revision/event/application
   위조와 문서 하나 누락을 모두 거절한다.
4. 8인 직전 가입과 최악 Aggregate 크기, Rules 접근 수·표현식 한도를 확인한다.
5. v2→v3 정상 migration, membership 누락, Snapshot 위조와 중복 실행을 확인한다.
6. proof가 통과한 뒤에만 개발자에게 그룹 목록의 추가 읽기·Projection 지연 UX와 앱 버전
   전환안을 제시해 승인을 받는다.
7. 승인 후 별도 구현 구간에서 dual-read → v3 Rules → v3 write → v2 migration 순으로 진행한다.

#### C7-9. 채택·폐기 조건

채택 조건:

- Functions·Blaze 없이 정상 그룹 재가입과 모든 핵심 위조 거절이 같은 Emulator 실행에서 통과
- 권위 참가 상태에 부분 성공이 없고 membership/listing 누락이 기능 권한을 바꾸지 않음
- 기존 공개·그룹 생성·신청 승인·자리/Character 변경·추방·완료·해산·반복방이 유지됨
- 문서 크기와 Spark 읽기량이 명시한 상한 안에 있음

폐기 조건:

- 핵심 3/4-write도 1,000식을 넘음
- membership/listing을 Projection으로 내려도 기존 UI·승인 권한을 안전하게 보존할 수 없음
- v2 migration이 8인 접근 한도나 위조 방지를 만족하지 못함
- 통과를 위해 권한·소유권·주간 완료·그룹 접근·원자성 조건을 완화해야 함

## 3. 작업 그룹 DE — 사용자 재인증·원정대 소유권 전환 정합성 복구

재설치 후 재인증과 타인이 사용하던 인증 원정대의 정상 이전은 모두 `현재 Character
소유 Player와 과거 신청·참가·파티장 데이터가 달라질 수 있다`는 공통 위험을 가진다.
따라서 문서·일정·브랜치에서는 하나의 작업 그룹으로 관리한다.

다만 두 상황을 같은 자동 병합으로 처리하지 않는다.

- **동일 사용자 복구:** 신뢰 가능한 로그인 연결로 기존 UID·Player를 복원하며 사회적
  데이터를 복사하거나 정리하지 않는 것이 정상이다.
- **실제 소유권 이전:** 새 Player는 다른 사용자로 취급하고 Character 소유권만 이전한다.
  이전 Player의 그룹·모집·파티장 지위·이력은 승계하지 않으며 이전 세대의 활성 상태만
  제한적으로 stale 처리한다.

### DE0. 구현 전 개발자 UX 결정 게이트

이 구간은 기술 계약만으로 화면 흐름을 확정하지 않는다. 코드·Rules·스키마를 수정하기
전에 개발자와 다음 UX를 화면 단위로 검토하고 명시적으로 확정한다.

1. 앱 최초 실행에서 `새로 시작`과 `기존 계정 복구`를 언제, 어떤 우선순위로 보여 줄지
2. 익명 사용자가 복구 제공자를 연결하는 위치, 연결 상태·해제 가능 여부와 사전 경고
3. 재설치 후 로그인 성공·취소·네트워크 실패·다른 계정 선택·credential 충돌 시 이동할 화면
4. 동일 원정대의 현재 소유자가 다른 Player일 때 `기존 사용자 복구`와 `소유권 이전`을
   어떤 설명과 추가 확인으로 구분할지
5. 이전을 실행하기 전에 승계되지 않는 항목(그룹, 파티장 지위, 신청, 알림, 과거 완료
   이력)과 stale 정리 가능성을 어떻게 고지하고 최종 확인을 받을지
6. stale 신청·참가·파티장을 어느 화면에서 발견하고, 누가 어떤 확인을 거쳐 정리할지
7. 자동으로 처리할 항목과 사용자의 명시적 선택이 필요한 항목, 취소 후 원상태 유지 방식
8. 처리 중 앱 종료·응답 유실·동시 사용·부분 실패가 발생했을 때 재진입 및 재시도 UX
9. 복구·이전 완료 뒤 어떤 Player·원정대·그룹·활성 참가 상태가 유지됐는지 보여 줄 결과 화면

UX 결정 결과에는 정상 흐름뿐 아니라 사용자 문구, 버튼, 취소 가능 시점, 로딩·중복 요청
차단, 실패별 안내, 고객 지원 또는 운영 확인이 필요한 경계를 포함한다. 개발자가 실제 사용
흐름을 승인하기 전에는 아래 데이터 설계를 구현 가능한 확정안으로 간주하지 않는다.

### DE-D 단계 — 재설치 후 동일 Player 복구

#### D1. 원정대 인증과 사용자 복구 분리

원정대 인증은 Character 사용권을 증명하지만 과거 LOSTPARTY Player와 동일인임을 증명하지
않는다. 따라서 이미 새 익명 계정이 만들어진 뒤 원정대만 재인증한 상태에서 기존 Player를
자동 병합하지 않는다.

향후 재설치에 대비한 기본 복구 방식은 익명 Firebase 사용자를 복구 가능한 로그인
제공자 계정에 link하는 것이다. 재설치 뒤 같은 제공자로 로그인하면 같은 Firebase 사용자
UID와 기존 `authBindings/{uid}`를 사용하므로 Player·그룹·파티 이력을 이전할 필요가 없다.

#### D2. 구현 범위

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

#### D3. 검증

- 익명 계정에 제공자 연결 후 앱 데이터 삭제·재설치, 같은 UID/Player 복구
- 연결 전 기존 그룹·파티·완료 이력 보존
- 신규 사용자 로그인, 잘못된 제공자, 취소, 네트워크 실패와 credential 충돌
- 복구 시 새 Player·중복 authBinding이 생성되지 않음
- 기존 익명 전용 사용자의 정상 시작 흐름 보존

## 4. 작업 그룹 DE-E 단계 — 타인 원정대 소유권 이전 안전화

#### E1. 세대값 계약

GameAccount와 Character에 단조 증가하는 `ownershipRevision`을 둔다. 실제
`ownerPlayerId`가 바뀔 때만 증가하고 같은 Player 재인증에는 증가하지 않는다.

신규 application, membership과 raidState는 생성 당시 `ownerPlayerId`와
`ownershipRevision`을 Snapshot으로 저장한다. 승인·가입·Character 변경·완료는 현재
Character의 두 값과 Snapshot이 모두 같을 때만 진행한다. A→B→A 이전에서도 과거 A의
문서가 다시 활성화되지 않는다.

#### E2. 승계 금지와 지연 정리

- 새 소유자는 이전 Player의 그룹 membership, 파티장/승인 권한, 신청, 알림과 완료 이력을
  승계하지 않는다.
- 소유권 이전 Transaction에서 이전 Player의 모든 문서를 순회하지 않는다.
- 이전 revision의 pending application은 승인할 수 없고 `ownershipChanged`로 정리한다.
- stale membership은 정상 파티원 또는 파티장의 제한된 정리 명령으로 membership과 연결
  active raidState를 원자 제거한다.
- stale 파티장이면 기존 승계 규칙으로 책임자를 넘기고 마지막 1인이면 해산한다.
- 이전 Player의 stale state는 새 소유자의 현재 점유로 간주하지 않지만 감사 없이 임의
  삭제하지 않는다.

#### E3. 기존 데이터와 배포 순서

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

#### E4. 검증

- 같은 Player 재인증에서 revision 유지
- A→B 이전과 A→B→A 재이전
- revision 없는 legacy application/membership/state
- stale pending 승인 거절과 명시적 정리
- stale 일반 멤버 제거, stale 파티장 승계와 마지막 1인 해산
- 새 소유자의 정상 신규 신청·가입과 이전 Player의 명령 거절
- 타인의 그룹·모집·과거 기록 비공개 및 자동 승계 없음

## 5. 전체 실행 순서

1. C: Spark 재가입 Rules 통합 설계·구현·전체 회귀 — 실패·원복
2. C 대안은 신뢰 서버 또는 데이터 계약 변경 중 별도 사용자 결정
3. DE0: 개발자 의견을 반영해 복구·이전 UX 분기와 문구·확인·실패 복구를 확정
4. DE-D: 재설치 예방·복구용 인증 제공자 연결 및 실기기 복구 확인
5. DE-E: ownershipRevision dual-write와 stale 차단
6. DE-E: 제한 정리 명령과 legacy 종료 판단

C와 DE는 별도 작업 그룹으로 유지한다. DE 안에서도 동일 사용자 복구와 실제 소유권 이전은
각각 독립 커밋·검증·배포 체크포인트를 사용하며, 앞 단계의 완료가 다음 단계의 보안 조건을
자동으로 충족한다고 간주하지 않는다.
