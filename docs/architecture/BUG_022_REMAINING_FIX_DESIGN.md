# BUG-022 미완료 버그 수정 설계

> 최신 실행 기준은 §3–4의 원정대 재인증 격리 설계다. §1–2는 과거 문제 분리와
> 재가입 검토 이력이며, 기존 사용자 복구를 이번 구현 범위로 해석하지 않는다.

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

## 3. DE 최신 결정 — 원정대 재인증 후 정상 사용 보장 (2026-09-29)

이 절은 이전 DE의 로그인 복구·Player 복원 계획을 대체한다. **설계 승인·구현 미착수** 상태다.
사용자는 과거 사용자의 관계 승계보다, 새 사용자가 인증한 원정대를 과거 데이터의 영향 없이
사용하는 UX를 선택했다. 자동 장비 인증과 운영자 수동 인증의 기존 절차는 유지한다.

### 3.1 확정된 제품 범위

- 새 Player는 인증한 원정대로 모집 생성·신청·가입·참가 Character 변경을 정상 수행한다.
- 이전 Player의 그룹 가입·그룹장/공대장 권한·신청·완료 체크·과거 이력은 승계하지 않는다.
- 이전 관계 정리 완료를 새 Player의 사용 전제로 두지 않는다. 새 사용자에게 이전 사용자
  조사, 복구 요청, 과거 방 방문이나 정리 작업을 요구하지 않는다.
- 다른 원정대와 정상 그룹 관계, 과거 완료 이력은 보존한다. 원정대 이전만으로 이전
  Player를 삭제하거나 그룹에서 자동 탈퇴시키지 않는다.
- 이전 방에 남은 무효 참가·신청은 제한된 별도 정리 대상으로 다룬다. 새 사용자만 정상이고
  기존 방이 영구적으로 막히는 상태는 완료가 아니다.
- Google 연결·기존 Player 복구·전체 관계 복사·그룹의 원정대 단위 재설계·일괄 운영 데이터
  삭제·서버 스케줄러는 제외한다. 과거 로그인 복구안은 별도 대안으로 보류한다.

### 3.2 코드에서 확인한 현재 사실과 추적 지도

아래는 코드 확인 사실이다. 전체 명령의 소유권 변경 회귀나 공격 내성을 검증한 결과가 아니다.

| 흐름 | 현재 연결/읽기·쓰기 | 후속 설계 책임 |
|---|---|---|
| 앱 세션 | bootstrap의 AnonymousAuthInitializer → PlayerBindingRepositoryImpl → authBindings/players | 새 Player를 과거 Player에 재연결하지 않음 |
| 자동 인증 | Router의 LocalGameAccountVerificationGateway → 앱 메모리 장비 challenge/API 판정 → _claimOwnership Transaction | binding·identity claim·기존 계정/Character 읽기 후 소유자 갱신, 이전 playerGameAccounts를 ownershipLost로 변경. 여기서는 과거 파티를 순회하지 않음 |
| 수동 인증 | Router의 FirestoreManualVerificationRepository → 승인/방어 실패/강제 이전/만료 확정 경로 | 공통 소유권 반영 경로와 모든 호출부에서 같은 변경 차수 계약 적용. 기존 승인·방어 정책 보존 |
| 생성·신청·가입·변경 | Router의 FirestorePartyAtomicCreate/Application/Join, PartyAtomicMembershipCommandAdapter → mutation/removal Repository | 후보 UI와 최종 Transaction의 소유권/점유 판단 일치, 최종 Rules 경계 대조 |
| 현재 점유 | PartyRaidStateOccupancyInspector → players/{playerId}/raidStates/{characterId}_{raidId}, active이면 연결 모집 읽기 | 현재 Player 경로만 읽음. 이전 Player의 state가 모든 신규 가입을 막는다고 단정하지 않음. 실제 충돌 경로 재현 필요 |
| 완료·반복 회차 | Router의 PartyAtomicCycleCommandAdapter → FirestorePartyAtomicCommandRepository 및 Write Plan | 대상 멤버·소유권·완료·주차·listing·마커 전이를 추적하고 stale 대상 처리 연결 |
| 기존 고아 정리 | 방 부재/종료/주차 기준으로 본인 active state 정리 | 방은 정상이고 Character 소유자만 바뀐 경우와 구분 |
| 그룹 관계 | Player 기준 membership/역방향 관계 | 새 Player에 복사하지 않음. 레이드 정리가 그룹 가입 삭제로 확대되지 않음 |

현재 authBindings update/delete는 Rules에서 금지한다. 반면 gameAccounts, characters,
characterIdentityClaims의 read/write는 signedIn 기준으로 넓게 허용되어 있다. 장비 인증
성공 판단은 앱에서 한다. 따라서 ownershipRevision 추가만으로 위조 방지까지 완료했다고
주장하지 않는다. 이번 기능이 변경하는 서버 경계의 최소 검증과 기존 신뢰 한계를 분리한다.
별도 신뢰 서버 도입이나 인증 구조 전면 변경이 필요하다고 판명되면 범위를 임의 확장하지
않고 설계 결정 항목으로 보고한다.

### 3.3 판별·저장 계약 방향 — DE1에서 확정할 기술 가설

- GameAccount와 소속 Character에 ownershipRevision을 기록한다. 같은 Player의 재인증은
  유지하고 실제 ownerPlayerId 변경 때만 증가한다. A→B→A에서도 이전 세대를 재사용하지 않는다.
- 신청, 모집 Aggregate의 참가 슬롯, membership Projection, raidState에 필요한 소유자/차수
  Snapshot을 정의한다. 실제 권위 데이터와 Projection을 구분해 중복 검증·불필요한 쓰기를 피한다.
- 승인·신규 가입·Character 변경·완료·반복 회차에서 현재 Character 소유자/차수와 대상
  Snapshot을 비교한다. 삭제·탈퇴는 소유권 상실 때문에 영구 차단되지 않는 별도 제한 경로를 둔다.
- 새 Player의 상태는 새 Player 경로를 기준으로 한다. 이전 Player의 active/completed 상태를
  복사하지 않는다. 같은 Player가 나중에 재취득한 경우 자신의 구세대 state도 정상 점유로
  재활성화하지 않는다. 과거 이력과 현재 동작을 제약하는 state의 수명을 구분한다.
- legacy 필드 부재를 최신 소유권으로 무조건 간주하지 않는다. 초기 차수/소유자 일치 조건,
  이전 전환 기록이 없는 데이터의 판단 불가 상태, 안전한 단건 복구 기준을 DE1에서 고정한다.
  운영 일괄 backfill은 이번 승인에 포함되지 않는다.
- 인증 Transaction에서 전체 모집·신청을 조회하지 않는다. 인증 경로의 읽기 완료 후 쓰기,
  경쟁 재인증 시 revision 재검증, 부분 Character 이전 방지와 응답 유실 후 재시도를 설계한다.
- 구버전 클라이언트의 필드 누락/덮어쓰기로 차수가 소실되지 않도록 Rules 및 앱 전환 순서를
  확정한다. 구버전 거절 시 업데이트 안내와 기존 읽기 범위를 정의한다.

### 3.4 기존 방 정리 UX와 권한 방향

- 상세 또는 해당 명령에서 소유권 변경이 확정되면 `소유권이 변경된 캐릭터의 참가 정보가
  남아 있습니다.`와 `참가 정보 정리`를 제시한다. 조회 실패/권한 오류/오프라인은 `확인할 수
  없습니다. 다시 시도해 주세요.`로 구분하며 stale이나 삭제 근거로 사용하지 않는다.
- 일반 참가자 제거는 현 공대장의 제한 정리를 기본으로 설계한다. 공대장 자체가 stale이면
  유효한 기존 참가자가 기존 승계 정책을 실행할 수 있도록 한다. 공대장 권한 전체를 주지 않는다.
- 기존 소유자가 자기 관계를 정리하는 경로와 마지막 1인 방의 정리 권한을 별도로 검토한다.
  호출 가능한 사용자가 전혀 없는 데이터는 무제한 권한을 열지 않고 운영 진단 대상으로 남긴다.
- pending 신청은 stale 상태에서 승인하지 않으며 승인 가능한 기존 사용자의 단건 정리로
  종료한다. 새 소유자가 이전 사용자의 신청 목록을 읽거나 대신 관리하지 않는다.
- 정리 전 대상·자리 제거·승계/해산 결과를 확인받고 요청 중 중복 동작을 막는다. 취소는
  쓰기 전 가능하다. 결과 불명은 성공/실패를 단정하지 않고 재조회 후 같은 대상 기준으로 재시도한다.
- 모집 Aggregate, 연결 membership/state, 인원수·listing·lifecycle 마커의 필요한 갱신을
  기존 원자 명령 경계에 맞춘다. 정상 자리 이동·재가입 등으로 대상이 달라졌으면 중단·재조회한다.
- 반복방은 무효 참가를 다음 주에 재생성하지 않는다. 정리가 필요한 기존 방은 정리→기존
  회차 처리 순으로 수렴시키며 새 소유자의 다른 방 이용과 결합하지 않는다.

### 3.5 사이드 이펙트 대응·검증 행렬

| 위험/발생 조건 | 방어 지점 | 검증·완료 근거 |
|---|---|---|
| 이전 방의 자리 잔존 | stale 참가 표시/제한 정리 | 새 소유자 신규 참가와 기존 방 자리 회복을 각각 확인 |
| stale 공대장으로 방 정지 | 기존 승계 정책/마지막 1인 해산 | 다른 참가자의 이후 완료·탈퇴 가능, 잘못된 권한 승계 없음 |
| 오래된 신청 승인 | 최종 Transaction·Rules 소유자/차수 | 인증 직전/직후 승인 경쟁 시 오래된 신청 승인 거절 |
| 반복방 과거 참가 부활 | advanceCycle 대상 판정 | 경계 전후 이전, completed→다음 주 active에서 구세대 제외 |
| A→B→A 구세대 재활성 | ownershipRevision | 사용자 ID가 같아져도 과거 신청/state 재사용 불가 |
| 새 데이터 오삭제 | 대상 사용자/Character/방/revision 재검증 | 정리와 재가입·자리 변경·완료 경쟁, 실패 시 부분 쓰기 없음 |
| 다른 원정대·그룹 손상 | 대상 관계 한정 | A/B 원정대 중 A만 이전, B와 Player 그룹 관계 보존 |
| 과거 기록·주간 체크 오승계 | 현재 state와 이력 분리 | 새 사용자는 이전 체크 없음, 과거 기록 삭제 없음 |
| 이전 기기 캐시 | 표시 갱신/최종 서버 권한 | 오래된 화면에서 신규 신청·변경 거절, 정리 경로는 유지 |
| legacy/구버전 차수 유실 | 명시 호환 규칙/서버 검증 | 필드 부재·부적합 타입·차수 감소·누락 갱신 검사 |
| Rules 비용 폭증 | 상수/최대 8인 제한 조회 | 최대 8인 대표 서버 검증, 각 state에서 전체 대상을 재검사하지 않음 |
| 인증·정리 중 앱 종료 | 재조회·멱등 재시도 | 응답 유실·중복 요청 후 한 결과로 수렴 |
| 자동/수동 인증 차이 | 공통 소유권 전이 계약 | 수동 방어/강제/만료 이전 및 같은 소유자 재인증 모두 대조 |

서버 경계 자동 검증은 위조 요청·동시성·원자성·legacy·8인 한도에 집중한다. 정상 UI
실기기는 사용자가 수행한다. 기존 그룹방 탈퇴·추방·재가입, Character 변경·자리 이동,
반복방 목록·주간 완료·주차 전환, 기존 부모 부재 고아 정리를 회귀 보호 대상으로 둔다.

## 4. 단일 브랜치 작업 단계와 완료 조건

설계 문서만 dev에 반영한 다음 `fix/roster-reauth-isolation`에서 다음 단계를 수행한다.
개발·자동 검증·사용자 실기기·회귀 대응·문서는 완료까지 이 브랜치에 고정한다. 다른 브랜치
전환, 중간 dev 병합, 별도 구현 브랜치 분기를 금지한다. 단계별 커밋·push는 같은 브랜치만 사용한다.

1. **DE1 조사·계약 확정:** 실제 충돌 최소 사례, 권위 데이터/호출 경로/Rules 순서, 차수와
   legacy 계약, 정리 권한·UX·앱 전환표를 확정한다. §3의 기술 가설을 검증 없이 코드화하지 않는다.
2. **DE2 소유권 판별 기반:** 자동·수동 인증 경로와 Snapshot을 연결한다. 같은 소유자,
   실제 이전, 재이전, 동시 인증과 legacy의 최소 서버 검증으로 기반을 확인한다.
3. **DE3 신규 이용·과거 효력 차단:** 생성/신청/승인/가입/변경/완료/반복방에 일관된 정책을
   연결한다. 새 사용자 이용이 과거 전체 정리를 기다리지 않음을 확인한다.
4. **DE4 제한 정리:** 신청·일반 참가·공대장·마지막 1인과 실패/재시도 UX를 연결한다.
   다른 멤버·원정대·그룹 관계 보존, listing/state 원자성을 확인한다.
5. **DE5 기능 섹션 검증:** 직접 영향 테스트와 Rules 8인/위조/경쟁 검증, 변경 범위에 필요한
   최종 전체 test/analyze, 사용자 실기기와 발견 회귀를 같은 브랜치에서 종료한다.
6. **완료 기록 후 통합:** 새 흐름/보존 흐름/미확인 항목/운영 Rules 상태를 구분해 기록한다.
   개발·테스트 종료 전 통합하지 않는다. main 반영은 이번 문서 승인 범위가 아니다.

기존 전체 검사 22건 실패·analyze 51건은 미해결 기준으로 보존한다. 이번 기능 직접 영향
실패는 구현 검증 전에 분류하고, 관련 없는 실패는 근거와 함께 분리한다. 기존 실패가 새 회귀
면제 조건은 아니다. 전체 검사를 중간마다 반복하지 않는다.

이번 문서 작업은 내용 대조와 git diff --check만 실행한다. 이후 Rules 변경 섹션의 운영
반영은 AGENTS.md의 검증·대상 확인·1회 배포·실패 시 중단 규칙을 따른다. **Git 브랜치
분리는 Firebase 운영 환경 격리가 아니다.** 운영 데이터로 파괴적 회귀를 재현하지 않으며,
서버 경계는 Emulator/CI에서 먼저 검증하고 실기기 검증용 표본은 사용자가 준비한다.

## 5. DE1 조사 결과와 구현 기준 (2026-09-29)

상태: 코드 경로 조사·계약 구체화. 아래 재현표는 **코드로 도출한 검증 시나리오**이며
실기기/Emulator에서 새로 재현했다는 뜻이 아니다. DE2 진입 시 최소 서버 proof가 필요하다.

### 5.1 실제 경로와 충돌 후보

| 대상 | 근거 | 판정과 최소 시나리오 |
|---|---|---|
| 새 B의 별도 모집 생성/가입 | PartyRaidStateOccupancyInspector는 B의 raidStates만 조회, create도 동일 Player 경로 사용 | A의 state만으로 B가 막히는 것은 현재 코드에서 입증되지 않음. A active→B 인증→별도 방 생성/가입으로 확인 |
| 이전 방의 자리 | Aggregate의 memberCount/partySlots는 인증 시 변경 안 됨, join은 capacity를 먼저 검사 | 이전 방이 만석이면 자리가 남아 거절될 수 있음. 정상 만석·직업·그룹 자격 조건을 우회해서는 안 됨 |
| A→B→A | state 키는 Player+Character+raid, 판정은 주차/상태/부모 방 중심 | A 재취득 시 구세대 active/completed가 현재 제약으로 다시 사용될 수 있음 |
| 신청 승인 | atomic join은 applicant Character의 ownerPlayerId를 검사 | A→B 직후 A 신청은 이미 ownershipLost로 거절. A로 돌아온 뒤 오래된 신청까지 구별할 차수는 없음 |
| 전체 완료/반복 전환 | FirestorePartyAtomicCommandRepository는 binding·모집·필요 group count를 읽고 명령을 구성. Character 조회 없음 | 남은 슬롯으로 이전 Player state를 complete/advance할 가능성. 현재 Rules의 lifecycle/advance state 검증에도 현재 소유자 대조가 없음 |
| 기존 고아 정리 | validAtomicStaleRaidStateDelete는 본인 active state와 부모 부재/종료 판정 | 부모가 정상인 소유권 변경 사례는 기존 정리 사유가 아님 |
| 기존 탈퇴/추방 | removal Write Plan은 status/currentCycleStatus 모두 active 요구, 후임은 남은 첫 슬롯 | completed 반복방과 stale 첫 후임은 그대로 재사용 불가. 제한된 별도 정리 사유가 필요 |

조사 파일: Router의 실제 Atomic Repository 연결, PartyRaidStateOccupancyInspector,
FirestorePartyAtomicCreate/Join/MemberMutation/MemberRemoval/CommandRepository,
PartyAtomicMemberRemovalWritePlan 및 firestore.rules의 validAtomicLifecycleUpdate,
validAtomicAdvanceRaidStateCreate, validAtomicRaidStateUpdate, validAtomicStaleRaidStateDelete.
자동 인증은 _claimOwnership, 수동 인증은 _claimForRequester와 호출부(승인·강제·방어 실패·
만료 확정)를 함께 변경 대상으로 한다. 기존 구 Repository만 고쳐 실제 Router를 놓치지 않는다.

### 5.2 권위 데이터와 차수 규칙

- GameAccount의 ownerPlayerId/ownershipRevision을 소유권 전이 기준으로 하고 Character에
  같은 차수를 반영한다. 원정대 전체 이전은 기존 인증 Transaction에 포함한다.
- 신규 원정대의 시작 차수는 1. 필드 없는 계정은 legacy 차수 0으로 해석한다. 같은 소유자
  재인증은 0 또는 기존 차수를 유지하고 실제 이전은 +1한다. 음수·비정수·계정/Character의
  불일치는 unknown으로 거절하며 임의로 현재 값에 맞춰 고치지 않는다.
- 신규 신청·참가·개인 state에는 현재 차수를 저장한다. Player 값은 기존 playerId를 활용하고
  소유자 필드를 불필요하게 중복 추가하지 않는다. Aggregate 슬롯이 참가의 권위 원장이고
  members/listing은 이를 투영한다. 승인 시 제출 당시 차수를 현재 값으로 덮어쓰지 않는다.
- 공용 판정 결과를 current / ownershipChanged / unknown으로 구분한다. Player 또는 차수
  불일치는 ownershipChanged, 읽기 실패·손상·필수 문서 부재는 unknown이다. unknown은 삭제 근거가 아니다.
- Snapshot 필드 없는 과거 관계는 현재 소유자 일치와 계정/Character 모두 legacy 0일 때만
  기존 동작을 허용한다. 차수 1 이상 계정의 차수 없는 관계는 legacy 관계로 구분해 정상 참가로
  사용하지 않는다. 정리할 때는 대상 관계/원정대 일치까지 증명해야 한다.
- 이 방식은 차수 도입 이후 A→B→A를 구분한다. **도입 이전에 이미 끝난 A→B→A의 과거 차수는
  복원할 수 없다.** 이전 로그가 없는 데이터를 완전 자동 판정했다고 주장하지 않는다.
- completed state의 과거 이력은 삭제하지 않는다. 재취득한 구세대 state는 현재 점유/완료
  판정에서 제외하고 새 활동으로 대체할 때 정확한 이전 버전을 검증한다. 로컬/공용 완료
  이벤트는 보존하며 새 사용자에게 복사하지 않는다.

### 5.3 정리 권한·명령 경계

- 신규 명령은 ownershipChanged 사유의 제한 정리로 분리한다. 정상 leave/kick과
  lostGroupQualification의 기존 권한을 넓히지 않는다.
- 일반 stale 참가: 본인의 이전 관계 또는 유효한 현 공대장이 정리 가능. stale 공대장:
  유효한 기존 참가자가 정리하며 유효한 후임 중 기존 가입 순서상 첫 사람을 선정한다.
- 마지막 1인 stale 방: 그 슬롯의 기존 Player가 본인 관계 해산 가능. 새 소유자나 외부인은
  이전 방 권한을 얻지 않는다. 호출 가능한 기존 사용자가 없는 방은 추후 운영 진단 대상으로
  남기되 새 소유자의 별도 모집 이용에 영향을 주지 않는다.
- 여러 stale 참가자가 있으면 일반 stale 대상을 먼저 단건 정리하고 공대장을 마지막에
  처리하는 방향으로 비용을 제한한다. 유효 후임이 없으면 임의 stale 후임 승계는 금지한다.
  전원 stale/무응답 방은 자동 대량 해산하지 않으며 운영 진단 범위로 분리한다.
- active 회차 정리: Aggregate 슬롯·member·연결 active state·인원/역할 count·그룹 listing과
  필요한 마커를 같은 Transaction에서 반영. 해당 state가 이미 다른 방/새 차수이면 삭제하지 않는다.
- completed 반복방 정리: 다음 주 참가 대상 슬롯/member/listing만 제거하며 개인 completed
  state와 완료 이벤트는 보존한다. 마지막 1인이면 기존 완료방 해산 정책으로 count를 닫는다.
- private state를 타인 클라이언트가 읽도록 열지 않는다. 서버 Rules가 삭제 대상 기존 데이터와
  변경 후 Aggregate를 대조한다. state 부재/교체 시 처리와 접근 예산은 DE2 서버 proof로 확정한다.
- 명령 입력에는 모집 ID, 예상 Aggregate revision, 대상 Player/Character, 관찰한 소유권 차수,
  commandId를 포함한다. 요청 값을 믿지 않고 최신 Character/슬롯과 다시 대조한다.
- 상태 불명·경쟁 변경은 재조회 안내, 이미 같은 정리가 적용된 재시도는 성공 수렴으로 처리한다.
  단순 notFound만으로 성공 판정하지 않는다. 파티 이벤트는 기존 공용 이벤트 구조를 재사용한다.

### 5.4 읽기 → 검증 → 쓰기 및 호환 전환

- 일반 이용 명령: binding·대상 모집·Character/소유권·허용된 본인 state·필요 그룹 관계 읽기
  → 공용 소유권 판정과 기존 구성/점유 검증 → Write Plan → 원자 쓰기 → Rules에서 최종 검증.
- lifecycle: 대상 최대 8명의 Character를 읽어 판별 후 정상 대상만 남은 Aggregate로 기존 명령 실행.
  stale 발견 시 그 상태로 complete/advance하지 않고 제한 정리를 안내한다. 읽기 실패 시 중단한다.
  개별 정리 뒤 재조회하므로 정리와 lifecycle을 무제한 하나의 Transaction으로 묶지 않는다.
- 모든 조회는 쓰기 전에 끝낸다. 후보 화면 판정은 안내이며 최종 Transaction이 다시 판정한다.
  목록 전체에서 방마다 Character를 추가 조회하는 N+1 방식은 도입하지 않는다.
- 구버전 set/merge가 차수를 없애거나 낮추는 것을 Rules로 거절해야 한다. 필드 추가 전용 준비
  단계와 활성 전환을 분리하고 같은 필드의 여러 임시 표현을 만들지 않는다.
- 운영 전환은 신규 명령 Snapshot과 lifecycle/정리 경로가 모두 연결된 앱/Rules를 하나의 기능
  섹션으로 검증한 후 진행한다. DE2만 운영 배포하여 기존 앱만 사용하는 방을 먼저 막지 않는다.
  구버전 거절 시 업데이트 안내를 준비하고 구버전 읽기 호환을 유지한다.
- 현재 signedIn 소유권 쓰기 허용의 한계는 별도 공개된 제한이다. 이번 변경에서는 타입·차수
  감소/누락·원정대/Character 전이 일관성을 검사하되 장비 인증의 서버 증명까지 구현했다고 하지 않는다.

### 5.5 구현 전 proof와 남은 불확실성

1. 8인 complete/advance의 Character 검사 추가 후 Rules 접근/평가 비용을 측정한다. 기존 8×8
   재검사로 돌아가지 않는다. 실패하면 데이터를 임의 삭제하거나 소유권 검사를 빼지 않는다.
2. 타인 private state를 읽지 않는 stale 정리가 새 차수 state를 지우지 않는지 검사한다.
3. completed 반복방에서 개인 체크·과거 이벤트를 보존하며 참가 대상만 정리하는 계약을 검사한다.
4. 현재 앱 상태에서 A→B 신규 이용 충돌을 실제로 재현한다. 재현되지 않으면 신규 버그라고
   만들지 않고 lifecycle·재이전 등 확인된 위험의 회귀 보호로 기록한다.
5. 서버 proof 전에는 DE1의 비용·Rules 구현 가능성까지 검증 완료로 판정하지 않는다.
   위 proof는 DE2 첫 구간이며 결과에 따라 설계를 보완한 뒤 기능 연결을 진행한다.

## 6. DE2 최소 서버 proof 결과 (2026-09-29)

**부분 통과 · 8인 advanceCycle 차단으로 DE2 미완료.** production firestore.rules와 앱 코드는
변경하지 않았다. tools/roster_ownership_rules_proof.mjs가 추적 Rules를 읽고 demo Emulator
메모리 안에서만 후보를 구성한다. 운영 배포용 Rules가 아니다.

최종 테스트 커밋 570108c, CI [36581670667](https://github.com/heo0328/LostParty_flutter/actions/runs/36581670667)
결과는 failure다. 독립 시나리오의 일부 PASS를 전체 성공으로 바꾸지 않는다.

| 시나리오 | 추적 Rules | 단건 state 소유권 후보 |
|---|---|---|
| 정상 8인 complete (실제 v2 완료 이벤트) | 성공 | 성공 |
| 마지막 멤버 Character 소유자 변경 뒤 complete | 기존 참가를 그대로 완료시킴 | 원자 거절, Aggregate/8개 state 보존 |
| A→B→A 차수 변경 뒤 complete | 기존 참가를 그대로 완료시킴 | 원자 거절, Aggregate/8개 state 보존 |
| 정상 8인 advanceCycle | 표현식 1,000개 한도 실패 | 실패, 후보만의 회귀로 단정하지 않음 |
| 타인 private state 직접 get/delete | 거절 | 거절 |
| 기존 공대장이 stale 일반 멤버 단건 제거 | 성공, private state 클라이언트 조회 없음 | 성공 |
| 대상 state가 다른 정상 방을 가리킨 경우 예전 방 제거 | 원자 거절, 교체 state 보존 | 동일 |
| completed 반복방에서 기존 제거 명령 | 거절, 완료 상태 보존 | 동일, 새 제한 명령 필요 |
| 같은 Character를 새 Player가 인증한 상태에서 별도 방 생성 | 성공, 이전 방/state 보존 | 동일 |

마지막 사례는 서로 다른 Player/binding을 사용한다. 인증 자체는 fixture로 주입했으므로
장비 API/수동 승인 UI 검증이나 신규 신청·가입·Character 변경 전체 통과로 확대하지 않는다.
새 사용자를 기존 방에 강제 가입시키거나 기존 그룹 자격을 우회하지 않는다.

### 6.1 시도와 기준 보정

- 36580261694: fixture의 difficultyId 누락. 실제 생성 Write Plan은 해당 필드를 저장하므로
  fixture를 보완했다. 소유권 후보 실패로 취급하지 않는다.
- 36580532025: 정상 8인 complete 통과 후 테스트 callback 결과 반환 누락으로 중단.
  테스트 유틸리티 수정이며 제품 수정이 아니다.
- 36580835138: 기본 complete/소유권 변경 허용을 확인하고 baseline advanceCycle 한도에서 중단.
- 36581337818: 사례를 독립 실행하여 Aggregate에서 8개 Character를 검사하는 후보가 정상
  complete까지 한도에 걸리는 것을 확인. 동일 접근을 반복하지 않고 이 후보는 채택하지 않는다.
- 36581670667: 각 state update가 자기 Character 하나의 소유자/차수만 검사하는 방식으로 변경.
  complete는 실제 앱 Write Plan의 schemaVersion 2/completionTargets 이벤트와 대조했다.
  정상 완료·stale 거절은 통과하나 baseline과 후보의 advanceCycle 실패는 유지한다.

### 6.2 다음 단일 구간과 남은 범위

1. **DE2-B:** 새 소유권 조건을 추가하기 전 8인 advanceCycle의 읽기/식 평가 경로를 추적한다.
   atomicCommandIncludes/atomicAdvanceStateMatchesSlot의 반복과 실제 Write Plan 입력을 대조하고,
   기존 단일 상태 재생성 테스트와 최대 8인 동시 전환의 차이를 확인한다.
2. 해당 명령에 한정한 검증 비용 개선 후보를 demo proof에서 먼저 비교한다. 역할/Character/
   target 결합·원자성 조건을 없애거나 8인을 줄여 통과시키지 않는다. proof 통과 전 운영 소스에 이식하지 않는다.
3. 단건 state 후보는 기존 update에만 적용했다. 누락 state create, legacy 필드 부재, 변경 차수
   위조/감소, 승인·가입·변경 Snapshot, 자동/수동 인증 원자성은 아직 미검증이다.
4. group listing 포함 8인 lifecycle, stale 공대장/전원 stale/마지막 1인, completed 반복방의
   새 정리 명령, 실제 동시 요청과 사용자 실기기도 미확인이다. 순차 충돌 fixture를 실제 경쟁 테스트로 표현하지 않는다.
5. 판별·정리 비용 경계를 통과한 뒤 DE2 기반 코드에 착수한다. dev/main 통합과 운영 배포는 하지 않는다.

## 7. DE2-B 비용 비교 결과 (2026-09-30) — 채택 보류

현재 브랜치 fix/roster-reauth-isolation을 유지하고 앱/production Rules는 수정하지 않았다.
운영 배포 없음. 아래 변경은 tools의 demo Rules 문자열 후보에만 적용했다.

- CI 36606500265 (8944714): 명령 대상 8회 함수 순회를 playerId/stateId 두 필드 맵의
  정확한 목록 포함 비교로 변경하고 최대 8개 제한 유지. 정상 advanceCycle은 여전히 실패했다.
- CI 36606825983 (af45781): 사용자 슬롯 인덱스를 찾은 뒤 Character/role을 한 번 대조하는
  후보로 바꾸고 그룹 listing·해산·target 위조를 추가했다. 공개/그룹 advanceCycle 실패 유지.
- CI [36607243281](https://github.com/heo0328/LostParty_flutter/actions/runs/36607243281)
  (a0795c5): 개인 완료 source guard와 lifecycle 우선 분기로 무관한 validator 평가를
  분리했다. 정상 공개/그룹 advanceCycle 실패 유지. 이 후보도 운영 채택하지 않는다.

검증의 advanceCycle 쓰기를 실제 _advanceRaidState의 set(merge:true), schemaVersion/
Player/Character/raid/difficulty/role 필드와 대조해 정렬했다. 기존 baseline 한도 실패는
관찰 결과로 명시하고 후보 정상 통과 조건과 구분한다. baseline 실패를 정상화했다고 하지 않는다.

### 7.1 확인 범위

- 후보의 정상 8인 complete, 소유자 변경·A→B→A complete 원자 거절은 계속 통과했다.
- 그룹 8인 complete와 listing revision/status, 8인 해산의 state 삭제도 통과했다.
- 신규 Player의 동일 Character 별도 방 생성, private state 직접 읽기/삭제 거절,
  기존 공대장 단건 정리와 다른 방 state 보호는 유지했다.
- role/Character/target Player/target state 위조, 마지막 state 쓰기 누락에서 원자 거절을
  관찰했다. **정상 advanceCycle 자체가 실패하므로 이 거절만으로 해당 보안 조건이 올바르게
  작동한다고 인정하지 않는다.** 정상 통과 후보 확보 뒤 대조 검증해야 한다.
- 정상 공개/그룹 8인 advanceCycle은 모두 실패했다. 완료/해산 통과를 주차 전환이나
  소유권 이전 기능 완료로 확대하지 않는다.

### 7.2 가설 변경과 다음 단일 진단

조회 함수 반복이 비용 기여 후보인 것은 맞지만 이를 바꾸어도 같은 오류가 남았다.
1,000식 메시지만으로 해당 함수가 유일한 원인이라고 확정하지 않는다. 정상 전환의 다른
조건 불일치 뒤 fallback 평가가 누적되는 가능성을 포함해 진단한다. 더 이상 동일 helper
미세 최적화를 반복하거나 조건 삭제·범용 권한 완화로 통과시키지 않는다.

다음은 **DE2-B2 개별 조건 진단**이다. demo에서 runtime-shaped 전후 문서와 state의 필수 필드,
주차/시간 경계·삭제 sentinel 결과를 점검하고, lifecycle shape/state/target 결합/state update/
listing/event 각 validator의 첫 실패를 별도 진단으로 분리한다. 진단용 약화 Rules가 필요하면
별도 이름의 메모리 실험으로 격리하고 제품 후보나 보안 통과 결과로 사용하지 않는다.
최초 실패 조건 또는 구체 평가 병목이 입증된 뒤에만 다음 수정 후보를 만든다.

현재 proof는 미해결 후보를 재현하기 위해 CI failure를 유지한다. 테스트 삭제·거절 기대값으로
교체해 녹색으로 만들지 않는다. 일반 full 회귀와 선택형 ownership-proof를 구분한다.

## 8. DE2-B2 개별 조건 분리 진단 (2026-09-30)

진단 CI [36609173357](https://github.com/heo0328/LostParty_flutter/actions/runs/36609173357),
테스트 checkpoint 099a4ed에서 다음 **11개 개별 predicate 모두 true**를 확인했다.
actor, shape, state, incompleteShape, targets, groupCount, aggregateAll,
commandIncludes, slotMatch, stateUpdate, event.

- 도구: tools/roster_lifecycle_predicate_diagnosis.mjs. 추적 Rules 함수는 바꾸지 않고 demo
  Emulator 메모리에 진단 전용 dePredicateProbes 경로를 추가한다. 운영 소스/프로젝트에는 없다.
- 8인 공개 반복방의 마지막 참가자(stateUpdate/slotMatch)와 전체 Aggregate/targets를 검사했다.
  oldCycle 2026-09-16, nextCycle 2026-09-23, 종료/시작 2026-09-22T21:00Z,
  nextEnds 2026-09-29T21:00Z, 요청 시각 2026-09-29T18:03Z로 시간 경계가 맞았다.
- 이전/다음 state의 필수 schema/player/Character/raid/difficulty/role/revision 필드와
  completedAt 부재를 기록했다. 완료 날짜 삭제 후 active 전환 모양을 대조했다.
- probe는 신뢰 fixture로 전환 후 Aggregate/state를 미리 준비하고 단일 조건을 평가한다.
  request.time 관련 필드는 probe 요청의 serverTimestamp로 맞춘다. 이 준비는 실제 원자 거래의
  검증을 대신하지 않으며 구체 write set의 getAfter 평가 비용·경쟁·오프라인을 재현하지 않는다.
- CI success는 진단 실행과 개별 판정 확인 성공이다. 실제 8인 advanceCycle/운영 Rules의
  해결이나 보안 회귀 전체 성공이 아니다. 테스트 종료 시 결과를 요약하며 향후 predicate 하나라도
  true가 아니면 진단도 실패 종료하도록 명시적 assertion을 추가했다.

### 8.1 판단과 다음 검증 경계

이번 fixture에서는 특정 shape/state/시간/마지막 slot 조건 자체가 false인 근거를 찾지 못했다.
따라서 그 조건을 삭제하거나 완화할 이유가 없다. 같은 원자 write set에서 남는 1,000식 실패와
개별 조건 true의 차이는 **거래 내 누적 검증 비용 또는 결합 평가 경로** 조사로 좁힌다.
정확한 식 수나 특정 helper의 독점 원인까지 측정했다고 주장하지 않는다.

다음 단일 작업은 DE2-B3이다. 동일 8인·동일 원자 write set·동일 before/after를 유지한 상태에서
모집 Aggregate / 개별 raidState / 공용 이벤트 / 그룹 listing 경계를 격리한 진단 변형으로
누적 비용의 주요 위치를 찾는다. 진단용 허용은 임시 메모리 Rules로만 격리하고 최종 후보에는
남기지 않는다. 조건별 역할/소유권/target 연결 검증의 책임을 보존한 최종 후보에서 정상과
위조·누락의 대조를 다시 통과해야 비용 개선으로 인정한다. 데이터 스키마/공용 계약 변경이
필요해지면 이 근거로 설계를 먼저 갱신하며 현재 증거 없이 구조를 바꾸지 않는다.

## 9. DE2-B3 실제 원자 거래 경계 진단 (2026-09-30)

진단은 `tools/roster_lifecycle_boundary_diagnosis.mjs`에서 추적 Rules를 읽고 demo Emulator
메모리에만 변형을 적용했다. 앱·운영 Rules·쓰기 스키마는 변경하지 않았다.

### 9.1 실패 위치

CI [36610449568](https://github.com/heo0328/LostParty_flutter/actions/runs/36610449568),
ddd351f의 동일 8인 advanceCycle + 그룹 listing 원자 거래 결과:

| 남긴 검증 | 결과 |
|---|---|
| 원본 전체 | 1,000식 한도 실패 |
| 모집 Aggregate만 제외, 나머지 전체 | 허용 |
| Aggregate만 유지 | 1,000식 한도 실패 |
| state/event/listing 각각만 제외 | 모두 1,000식 한도 실패 |
| state/event/listing 각각만 유지, 전체 허용 대조군 | 모두 허용 |

따라서 이 fixture의 실패는 모집 update 평가 경로로 좁혀진다. state·event·listing 검증이
합산돼서만 실패한다는 가설은 지지하지 않는다. 경계 제외는 원인 진단이며 배포 후보가 아니다.

### 9.2 모집 검증 직접 분기

CI [36697760555](https://github.com/heo0328/LostParty_flutter/actions/runs/36697760555),
0459649에서 주차 전환 요청만 ternary로 직접 분기했다. 다른 명령은 기존 update 분기를
유지하고 나머지 문서 Rules와 실제 쓰기 묶음은 그대로 뒀다.

- `validAtomicLifecycleUpdate` 전체 직접 호출: **허용**.
- targets 제외 나머지 조건, targets 전체, 첫 target, 마지막 target, 허용 대조군: 모두 허용.
- 허용 후 모집 revision/주차, 8개 state의 active/주차, listing sourceRevision을 확인했다.
- 전체 validator를 유지한 직접 분기도 통과했으므로 target 결합·역할·권한 조건을 삭제할
  근거가 없다. 과거의 OR 앞부분 guard 추가와 이번 배타적 분기는 다른 접근이다.
- 특정 fallback 함수의 정확한 비용/식 수는 측정하지 않았다. 정상 거래 한 건 성공을
  위조·누락·구버전·소유권 후보까지 검증된 수정으로 확대하지 않는다.

동일 실행 대조 CI [36698068865](https://github.com/heo0328/LostParty_flutter/actions/runs/36698068865),
80d05e5에서도 원본은 expression-limit, 전체 직접 분기와 대조군은 allowed였다.
이 결과를 assertion으로 고정했다. CI success는 진단 결과 확인이며 제품 수정 완료가 아니다.
거절 거래의 전체 데이터 불변도 확인했다. Rules 컴파일 경고는 관찰되지 않았으며
GitHub Action/Node deprecation 경고와 구분한다.

다음은 이 직접 분기만을 최소 후보로 삼아
누락·위조 거절과 기존 명령 회귀를 검증하는 DE2-B4다. 기존 실패 후보의 target/slot 미세
최적화를 함께 이식하지 않는다. 운영 소스 수정·배포는 proof 검증 이후 별도 구간이다.

## 10. DE2-B4 보안·회귀 proof 결과 (2026-09-30) — 직접 분기 후보 채택 불가

`tools/roster_dispatch_rules_proof.mjs`는 추적 원본의 모집 update 앞에 advanceCycle
ternary만 추가했다. legacy 누락 marker는 `map.get` 기본값으로 기존 분기에 보내고,
그 외 validator·target/slot helper는 그대로 유지했다. 소유권 결합 후보는 기존 단건 state
검사만 추가했다. 진단용 allow-true나 조건 생략은 포함하지 않았다.

### 10.1 대조 결과

| 검증 | 직접 분기 후보 8272fd3 / CI 36698759925 | 원본 대조 25b1058 / CI 36699127414 |
|---|---|---|
| 정상 8인 그룹 주차 전환 + listing/event | 통과 | 기존 B3 한도 실패 근거 유지; 반복하지 않음 |
| 역할/Character/target Player/target state 위조, 마지막 state 누락, 비방장 요청 | 거절, 모집·8 state·listing·event 불변 | 이번에 반복하지 않음 |
| 이전 ownership 필드와 command marker 없는 fixture 전환 | 통과(직접 분기만) | 미실행 |
| 정상 8인 그룹 전체 완료 | **1,000식 실패** | **통과** |
| 기존 cutover 회귀 | **마커 소진 후 추방에서 1,000식 실패**, 이후 미실행 | **전체 통과** |
| 단건 소유권 결합 정상 8인 전환 / 이전 소유자·A→B→A 전환 | 정상 통과 / 원자 거절 | 소유권 검사가 없는 직접 분기 후보에서는 둘 다 허용됨 |

- 후보 CI [36698759925](https://github.com/heo0328/LostParty_flutter/actions/runs/36698759925)는
  **failure**, 원본 대조 CI [36699127414](https://github.com/heo0328/LostParty_flutter/actions/runs/36699127414)는 success다.
  원본 success를 후보 전체 성공으로 읽지 않는다.
- 원본은 같은 그룹 fixture의 완료, 기존 마커 소진·추방·신청·재가입·해산·BUG-017 변경과
  그룹 listing 검사까지 통과했다. 따라서 완료·추방 실패는 이번 후보의 회귀로 판정한다.
- 소유권 결합 후보의 정상 complete가 실패한 상태에서 출력된 stale complete 거절은
  보안 통과 근거에서 제외한다. 25b1058에서 명령별 정상 통과 후에만 해당 거절 검사를
  실행하도록 고쳤다. 변경 없는 후보를 재실행하지 않았다.
- legacy 검사는 필드 없는 이전 상태에서 전환되는 제한 사례다. 구버전 앱 전체 호환이나
  ownership 필드 없는 데이터의 새 소유권 검사 정책 완료가 아니다.
- 다른 명령의 원래 식을 보존했더라도 외부 분기 추가가 평가 예산에 영향을 준다는 근거다.
  정확한 식 수·컴파일러 내부 원인은 아직 측정하지 않았다. map.get 한 줄만 원인으로 단정하지 않는다.

### 10.2 다음 설계 경계

DE2-B4 검증 수행은 마쳤으나 **후보 수용 조건은 실패**했다. 운영 Rules·앱은 수정하지 않는다.
다음 DE2-B5는 모집 update의 명령 선택 구조를 설계부터 재검토한다. 외부 ternary/OR를 계속
덧붙이지 않고 기존 분기 내부의 중복 판정·명령 구분과 fallback 필요성을 먼저 추적한다.
complete·추방·가입·변경의 허용 조건을 보존하고 legacy/missing/null 마커를 명시한 표와
최소 수정 위치를 확정한 뒤 demo 후보를 만든다. 다른 정상 문서 validator를 전면 재작성하거나
권한 조건을 삭제하지 않는다. 기존 소유권 이행·missing-state create·동시성·실기기는 여전히 후속 범위다.

## 11. DE2-B5 명령 선택과 최소 후보 설계 (2026-09-30)

### 11.1 확인한 실제 계약

Router의 `PartyAtomicCycleCommandAdapter`는 lifecycle을 `FirestorePartyAtomicCommandRepository`에
위임한다. 반복 설정은 Adapter의 `setRecurrence`가 binding → 모집 조회 → revision/공대장/상태
확인 후 `PartyCycleWritePlan.recurrence`의 세 필드만 update한다. lifecycle Write Plan은
모집 marker/revision과 state·event·그룹 listing을 같은 거래로 저장한다.
일반 명령의 `party_atomic_lifecycle_marker_patch.dart`는 이전 lifecycle marker를 null/빈 targets로 소진한다.

| 요청 | 모집 Rules 경로 및 보존할 조건 | marker 주의 |
|---|---|---|
| 개인 완료 | personalCompletionCommandMarker → 개인 완료 validator | personalComplete, actor/단일 target 필수 |
| 반복 설정 | validRecurrenceChange | 이전 marker 유지; null뿐 아니라 advanceCycle/complete도 남을 수 있음 |
| 주차 전환·전체 완료·미완료 종료·해산 | validAtomicLifecycleUpdate | 명령/actor/revision/시간/targets 및 group count 검증 유지 |
| 신청 수 변경 | validAtomicPendingApplicationUpdate | 이전 lifecycle이면 소진, 아니면 보존 |
| 가입·승인 | validAtomicRecruitmentJoin와 관련 문서 Rules | 멤버 +1, 정원·state·membership·event·listing 결합 유지 |
| Character/자리 변경 | CharacterRevision/PositionAggregate validator와 관련 문서 Rules | 마커 소진/보존, 멤버 목록·정원·배치 계약 유지 |
| 추방·탈퇴 | MemberRemoval validator와 관련 문서 Rules | 멤버 -1, 본인/공대장, 승계·state 삭제·listing 결합 유지 |
| 공개 범위 변경 | VisibilityChange validator | 마커 소진/보존, 그룹과 외부 멤버/신청 제한 유지 |

모집 update는 위 validator들의 OR다. marker는 마지막 명령 흔적이기도 하므로 단독 selector로
전체 OR를 대체할 수 없다. 예를 들어 advanceCycle 직후 반복 설정은 marker를 유지하면서
revision만 증가시키므로 lifecycle이 아닌 recurrence 경로를 계속 허용해야 한다.
필드 누락을 null과 동치로 강제하거나 새로운 marker enum으로 기존 요청을 일괄 거절하지 않는다.

### 11.2 이번 최소 실험: 기존 recurrence 조건의 평가 순서만 변경

`firestore.rules`의 `validRecurrenceChange`(현재 1300행)는 인증/binding·공대장·상태를 먼저
평가한 다음 affectedKeys가 continueTogether/revision/updatedAt에 한정되는지 검사한다.
정상 lifecycle/추방 요청은 이 키 조건에서 제외되지만 그 전 인증·상태 평가를 거친다.

demo 후보에서는 **이미 존재하는 affectedKeys.hasOnly 조건을 이 함수 맨 앞으로 이동**한다.
모집 update OR, 다른 함수, 타입·권한·시간·revision 조건, 쓰기 묶음은 그대로 둔다.
새 전역 guard나 ternary·helper를 추가하지 않는다. 모든 원래 AND 조건을 한 번씩 유지하므로
정상 구조의 recurrence 요청에 대한 허용 정책은 같다. 키가 다른 요청의 불필요한 인증 평가를
피할 수 있다는 것은 기술 가설이며, 실제 비용 절감/한도 통과는 아직 검증 전이다.

missing/null/알 수 없는 marker를 가진 recurrence 요청은 기존 함수가 marker를 참조하지
않았으므로 그 특성을 유지한다. 반대로 일반 명령의 missing marker를 새로 복구하거나 허용하지 않는다.
손상 문서/미인증 요청의 평가 오류가 false로 바뀔 수 있어도 새 허용을 만들면 안 된다.

### 11.3 회귀와 중단 기준

1. recurrence 자체의 null/누락/이전 lifecycle/알 수 없는 marker 보존, 공대장 성공,
   비방장 거절·허용되지 않은 필드 동시 변경 거절을 검사한다.
2. 정상 8인 주차 전환·전체 완료 및 기존 cutover 회귀(마커 소진 후 추방 포함)를 대조한다.
   기존 실패 후보의 외부 분기나 target/slot 최적화는 합치지 않는다.
3. 정상 전환 통과 시에만 기존 위조/누락/비방장과 원자성 검사를 인정한다. 소유권 결합은 별도다.
4. 이 단일 후보가 실패하면 같은 순서 변경을 다른 함수로 연쇄 확대하지 않는다. 결과를 기록하고
   측정 근거를 추가할 다음 진단을 정한다. 운영 이식·배포·앱/스키마 변경은 이번 범위에서 제외한다.

### 11.4 단일 후보 결과와 후속 판단

5921dfb / CI [36700305266](https://github.com/heo0328/LostParty_flutter/actions/runs/36700305266)는
**failure**다. recurrence marker 보존·비방장/추가 필드 거절과 기존 cutover 회귀 전체는
통과했고 전환 후 추방도 보존됐다. 그러나 정상 8인 그룹 advanceCycle은 단독 후보와
소유권 결합 모두 1,000식 실패다. 따라서 비용 개선 후보로 채택하지 않는다.
정상 전환 게이트 실패로 이후 전환 위조·소유권 거절 및 별도 8인 그룹 전체 완료 사례는
실행하지 않았다. cutover 통과를 이 미실행 사례까지 확대하지 않는다.

DE2-B5의 명령별 계약·최소 위치·검증 순서 설계와 한 차례 실험은 완료했으나 해결은 아니다.
다음 DE2-B6는 **측정 자료 확보만** 진행한다. demo Emulator의 평가 추적/coverage 제공 여부와
자료의 의미를 확인하고, 원본 및 성공했던 lifecycle 직접 분기의 같은 8인 요청에서
어떤 식/함수가 평가되는지 수집한다. 자료가 정확한 식 수를 제공하지 않으면 호출/평가 관찰과
예산 추정을 구분한다. 직접 분기는 비교 자료이며 이미 발견된 회귀 때문에 배포 후보가 아니다.
측정 인터페이스가 없거나 자료가 부족하면 그 한계를 보고하며 또 다른 미세 후보를 추가하지 않는다.

## 12. DE2-B6 평가 자료 수집

Firebase 공식 [Rules coverage 안내](https://firebase.google.com/docs/firestore/security/test-rules-emulator)의
demo 프로젝트 `:ruleCoverage` JSON을 사용한다. 원본과 B3 직접 분기만 같은 8인 그룹 전환으로
측정한다. 직접 분기는 B4 회귀로 폐기된 비교 자료이며 운영 후보가 아니다.

`roster_lifecycle_boundary_diagnosis.mjs --coverage`는 seed와 사전 검사 완료 후 before,
거래 성공/실패 직후 사후 검사 전에 after를 저장한다. 따라서 준비 요청은 누적 값의 차이에서
제외한다. 각 Rules 원문·SHA-256·결과·측정 구간을 함께 저장하며 CI artifact의 보관 기간은 30일이다.
보고서는 식의 평가 횟수/값을 제공한다. 차이의 합을 단일 write의 1,000식 예산과 같다고 해석하지
않으며, 성공/실패 거래의 평가 중단·여러 문서·재시도 가능성을 구분한다. 결과 판독 전 새 후보 없음.

### 12.1 확보한 근거

0ed6c26 / CI [36704079227](https://github.com/heo0328/LostParty_flutter/actions/runs/36704079227)는
측정 성공이다. firebase-tools 15.29.0, Firestore Emulator 1.22.0에서 원본은 expression-limit,
직접 분기는 allowed를 재확인했다. 기능 해결/보안 회귀 통과를 뜻하지 않는다.
artifact `roster-lifecycle-coverage`에는 두 variant의 before/after JSON·Rules·manifest가 있다.
로컬 사본은 무시 경로 `coverage/de2-b6-36704079227/`에 보관했다.

- baseline Rules SHA-256: `e8baa2e4824d9200ab8a76fe07d7155578ba6982ca9b29941b9b7f55a6b3b1a5`
- directFull Rules SHA-256: `da8ca47553ea64f37cda484dacaf5c75cc7379e4d3f9283fd8c4f7ba70cb670a`
- 재판독: `node tools/roster_lifecycle_coverage_summary.mjs <artifact-directory>`.
  before/after의 원문 일치·manifest 해시·sourcePosition 중복·선택 식의 값별 count 감소를 검사하고
  sourcePosition별 반환값 차이를 `summary.json`으로 저장한다. 다른 소스 버전에는 위치를 재대조한다.

### 12.2 목표 거래 구간의 관찰

아래는 준비 요청을 차감한 **반환값 관찰 횟수**다. `증가 없음`은 미호출을 뜻하지 않는다.
line은 artifact Rules 기준이며 직접 분기 전 함수들은 두 소스의 위치가 같다.

| 식/호출 위치 | 원본 | 직접 분기 |
|---|---|---|
| recurrence 반환 L1301 | false 1, undefined 1 | 증가 없음 |
| target state match 반환 L1361 | true 7, undefined 1 | true 8 |
| target transition 반환 L1369 | true 7, undefined 1 | true 8 |
| target index 0 호출 L1385 | true 1, undefined 1 | true 1 |
| target index 1–6 호출 L1386–1391 | 각 true 1 | 각 true 1 |
| target index 7 호출 L1392 | 증가 없음 | true 1 |
| all targets 반환 L1380 | 증가 없음 | true 1 |
| lifecycle actor/shape/state/incomplete shape 호출 L1507–1510 | 각 true 1, undefined 1 | 각 true 1 |
| lifecycle 반환 L1506 / group count 호출 L1512 | 증가 없음 | 각 true 1 |
| raidState update 반환 L1575 | 증가 없음 | true 8 |

원본은 동일 8인 데이터에서 target index 0–6의 true 반환까지 관찰되고 index 7의 완료 반환이
남지 않는다. 직접 분기는 같은 검증을 모두 통과한다. B3의 실제 write 경계 결과와 함께 보면
**모집 Aggregate의 기존 명령 선택 경로 + 전체 target 검사 누적 비용**이 우선 조사 지점이다.
8번째 참가자 데이터가 유효하지 않다는 증거가 아니며 target 검사만이 유일한 비용 원인이라고도
확정하지 않는다. 원본 거절 시 모집/state/listing snapshot 불변, 비교 성공 시 8state/주차/listing
revision을 확인했다. 이번 측정 도구의 snapshot에는 event가 없으므로 event 원자성까지 확대하지 않는다.

### 12.3 해석 한계와 다음 변경 근거

- 보고서는 시간순 trace/요청별 예산 계측기가 아니다. 하위 식과 상위 식이 중첩되며 거래의 get과
  여러 write가 함께 포함된다. `undefined`, 빈 value와 반환 누락을 단독으로 권한 거절·미호출·정확한
  초과 위치로 해석하지 않는다. 총 count를 합산해 1,000식 또는 절감량으로 보고하지 않는다.
- 직접 분기는 baseline보다 더 많은 후속 검사를 완료한다. 두 전체 count의 단순 대소는 성능 비교가 아니다.
- 다음 DE2-B7은 기존 외부 명령 분기를 유지하면서 target 검사 내부의 반복 명령 판별을 줄일 수 있는지
  계약과 코드로 설계한다. 현재 L1369–1375/L1361–1365는 매 target마다 disband/complete/advanceCycle를
  판별한다. 명령별 기대 상태 선택과 8개 대상 검사를 분리하는 방향을 검토하되, 한도 개선은 미검증이다.
- 허용 조건(대상 목록 동일성·개수·각 state의 모집/주차/상태, disband 삭제, incompleteEnd 빈 목록),
  권한·원자성은 삭제하지 않는다. 기존 실패한 외부 분기·맵 직접 비교·슬롯 조회 후보를 합치지 않는다.
  설계가 성립할 때만 단일 demo 후보로 정상 8인 전환/완료와 기존 cutover(전환 후 추방 포함)를 우선 확인한다.
  정상 전환 통과 후 위조/누락/비방장·소유권 결합을 검증한다. 실패하면 원문/coverage와 대조해 보고한다.

DE2-B6는 자료 확보와 한계 기록 완료다. 운영 Rules·앱·배포·실기기·소유권 구현은 진행하지 않았다.

## 13. DE2-B7 target 명령 판별 분리 설계

Router → PartyAtomicCycleCommandAdapter → FirestorePartyAtomicCommandRepository의 실제 연결을
재확인했다. binding/모집 및 필요한 그룹을 읽고 모집·최대 8state·event·listing을 원자 저장한다.
이번에는 이 경로·데이터·조회/쓰기 수·모집 allow update OR를 변경하지 않는다.

### 13.1 단일 demo 후보

`atomicAllTargetsMatch`의 기존 개수/빈 목록 조건 다음에서 complete/advanceCycle만 선택한다.
선택한 기대 상태 문자열(completed/active)을 8개 대상 검사에 전달한다. 대상마다 같은 명령을
다시 비교하지 않고, 기존과 같은 getAfter 대상의 recruitmentId/cycleKey/status 세 값을 검증한다.
disband/incompleteEnd 및 나머지 명령은 원래 target 검사 8개를 그대로 호출한다.
수정 범위는 이 helper와 complete/advance 전용 helper뿐이며 원본 firestore.rules는 유지한다.

| 경계 | 보존 방식 |
|---|---|
| complete / advanceCycle | 기대 status만 한 번 선택; 0–7 모든 유효 target의 모집·주차·상태 대조 |
| disband | 원래 existsAfter 부재 검사; 완료방 빈 목록 예외 유지 |
| incompleteEnd | 원래 빈 목록/shape 정책; 비어 있지 않은 목록을 새로 허용하지 않음 |
| 8 초과/목록 위조/누락 쓰기 | 기존 개수·shape의 target 동일성, 각 state 검사를 유지 |
| 반복 설정·가입·변경·추방 | 외부 OR 및 marker 소진/보존 함수 무변경 |
| 과거/누락 marker | complete/advance 요청에서만 분리; 기존 fallback을 대체하지 않음 |

권한 완화 없이 반복 명령 판별을 줄인다는 기술 가설이다. 함수 호출/컴파일 비용 때문에 실제
예산이 줄지 않을 수 있으므로 한도 해결을 가정하지 않는다. B4 외부 분기·B5 recurrence 순서·
이전 맵/슬롯 최적화를 결합하지 않는다.

### 13.2 검증·중단 기준

- 기존 cutover 전체와 정상 8인 그룹 전환·전체 완료를 독립 검사한다. 전환 실패 때문에 완료
  검사를 생략하지 않는다. cutover에는 해산·marker 소진 후 추방·기존 참가 변경이 포함된다.
  미완료 종료는 기존 cutover에 직접 사례가 없어 별도로 정상 빈 targets/비정상 nonempty targets를 검사한다.
- 위 정상 게이트 통과 후에만 역할/Character/target/state 누락·status/주차/모집 위조·비방장 거절,
  모집/state/listing/event snapshot 불변 및 제한 legacy 전환을 검사한다.
- plain 후보의 회귀·보안 통과 후 기존 단건 ownership 검사 결합을 검사한다. 정상 명령 통과 전의
  stale/A→B→A 거절은 보안 성공으로 인정하지 않는다.
- 전환 요청 before/after coverage와 후보 원문을 demo artifact로 보관한다. 실패하면 이 자료와
  B6를 대조하고 단일 후보를 폐기한다. 같은 구간에서 다른 후보를 연쇄 추가하지 않는다.
- 운영 수정·배포·dev/main 병합·실기기 자동 실행은 제외한다. 기존 Flutter 실패 기준과 사용자
  초기화 설정 변경은 보존한다.

### 13.3 주 검증 결과 — demo 채택, 운영 이식 전

611abc6 / CI [36705703747](https://github.com/heo0328/LostParty_flutter/actions/runs/36705703747)는
**success**다. 실패한 외부 분기를 재사용하지 않은 단일 후보로 다음을 확인했다.

| 검사 | 결과와 범위 |
|---|---|
| 정상 8인 그룹 주차 전환·전체 완료 | 단독 후보/단건 소유권 결합 모두 성공; 8state·listing revision·event 증가 확인 |
| 기존 cutover 전체 | 단독 후보 성공; marker 소진 후 추방, 그룹 탈퇴/추방/재가입, Character 이동, 해산 등 유지 |
| 전환 위조 9종 | 역할·Character·state 누락·target Player/state·비방장·state status/주차/모집 ID 거절, snapshot 불변 |
| 완료 위조 4종 | state 누락·status/주차/모집 ID 거절, snapshot 불변 |
| 제한 legacy | 소유권 필드 및 이전 marker가 없는 자료의 단독 후보 전환 성공 |
| stale / A→B→A | 단독 후보는 기존처럼 허용. 소유권 결합은 전환·완료 모두 원자 거절 |

위 snapshot은 모집·참가 state·listing·공용 event를 포함한다. 소유권 변경은 admin fixture 주입이며
실제 인증·동시 경쟁·계정 복구 검증이 아니다. 소유권 결합의 전체 cutover/legacy 이행은 통과로
확대하지 않는다. missing-state create 소유권 검사는 아직 추가하지 않았다.

artifact `roster-targets-coverage`(30일), 로컬 `coverage/de2-b7-36705703747/`에 두 후보의
원문·전후 coverage·manifest를 보관했다. 원문 일치 및 SHA-256을 대조했고 target state match는
각 8회 true, all expected targets/lifecycle은 각 1회 true, raidState update는 8회 true였다.
정확한 예산 잔여량이나 식 절감 수는 측정하지 않았다.

- 단독 후보 SHA-256: `b5fc17df5d0902be361a309b12a1b76385ee872f2b453b896f36ac9465d294ef`
- 소유권 결합 SHA-256: `5bcff8c10225904d64f2ab5aec1cc9193fdc92336222b5c23187468ea2b24a4d`

Rules 컴파일 경고는 관찰되지 않았다. Actions/Node 자체 deprecated 안내는 Rules 경고와 구분한다.
현재 추적 firestore.rules와 운영 Rules는 그대로다. **8인 전환 한도 차단의 해결 후보를 확보한 것**이며
제품 반영·DE 전체 완료는 아니다. 후속 DE2-C는 이 후보를 demo 기반으로 누락 state 재생성 및
legacy 0/현재 소유자/참가 Snapshot 차수 판별을 검증한다. §5.2 계약을 유지하고 인증 차수 생성·
참가 Snapshot·완료 반복방 정리·동시성·실기기는 이후 연결한다.

추가 경계: 기존 cutover에 미완료 종료 직접 사례가 없음을 확인하여 후보 Rules는 바꾸지 않고
5bb02c2 / CI [36706232887](https://github.com/heo0328/LostParty_flutter/actions/runs/36706232887)에서
해당 두 사례만 실행했다. 8인 그룹의 일반 멤버가 지난 1회성 방을 incompleteEnd하면 기존
8state를 보존하고 listing 삭제·그룹 count 감소·event 생성을 원자 반영했다. 비어 있지 않은
targets 요청은 모집/state/listing/event/group snapshot 불변으로 거절됐다. 전체 검사를 반복하지 않았다.
DE2-B7 설계·단일 후보 검증은 완료이며 다음 DE2-C의 demo 기반으로 채택한다.

## 14. DE2-C 누락 state·legacy 판별 설계

실제 Router의 atomic cycle Adapter/Repository와 Write Plan을 재확인했다. advance는 슬롯에서
state 내용을 구성해 merge set하며, 개인 완료 후 state가 없는 경우에도 같은 경로로 재생성한다.
현재 Write Plan에는 ownershipRevision이 없다. 이번에는 demo 요청에만 참가 슬롯의 차수를
전달하며 제품 코드는 아직 바꾸지 않는다.

- B7 target 후보를 그대로 재사용한다. 각 state create/update에서 Character와 연결 GameAccount의
  현재 ownerPlayerId·차수를 대조한다. 없는 차수만 0으로 해석하며 null/문자열/음수는 거절한다.
- 현재 소유자와 계정/Character 차수 일치, state 차수 일치 및 참가 슬롯 차수 일치가 필요하다.
  차수 없는 관계는 둘 다 legacy 0인 경우에만 허용한다. 필수 문서 부재는 unknown으로 거절한다.
- lifecycle 중 partySlots를 변경하지 못하도록 원본 슬롯 목록 보존을 요구한다. advance의 기존
  슬롯 매칭에 차수 비교를 추가하고 complete에도 슬롯 매칭을 적용한다. state update의 기존
  affectedKeys 제한을 유지해 이미 저장된 차수의 변경·삭제·자동 승격을 막는다.
- 정상 최대 8인에서 create/update 혼합(마지막 참가자 누락) 및 전체 완료·legacy 전환을 먼저
  확인한다. 모두 성공한 경우에만 누락 create의 stale/A→B→A/차수 위조, update 차수 변경,
  계정/Character 불일치·필수 문서 부재와 슬롯 동시 위조의 원자 거절을 보안 근거로 인정한다.
- Character 8건 외에 GameAccount 최대 8건의 Rules 접근이 추가된다. 접근/표현식 예산은
  미검증이며 실패하면 조건을 삭제하지 않고 실패 지점과 더 좁은 다음 설계를 기록한다.
- 인증 소유권 문서의 넓은 기존 write 권한은 별도 신뢰 한계다. 이번 fixture는 인증 완료 상태를
  주입하며 인증 위조 방지·경쟁 이전·이력 복원까지 완료했다고 표현하지 않는다. 운영 이식/배포 없음.

### 14.1 결과와 남은 범위

0c3fb67 / CI [36721590205](https://github.com/heo0328/LostParty_flutter/actions/runs/36721590205)는 success.
정상 3건(8인 create/update 혼합 전환·전체 완료·legacy 0 혼합 전환)과 원자 거절 16건을 통과했다.
create는 마지막 참가자 state만 누락시켜 가장 뒤 슬롯 매칭과 기존 7개 update를 함께 검증했다.
거절은 소유자 변경/A→B→A, Character/계정 부재, 계정 차수 불일치, null/음수/문자열 차수,
참가 Snapshot 누락, lifecycle 슬롯 차수 변경, 새 state 차수 위조/감소/누락 및 기존 state 차수
위조/감소/삭제다. 거절 전후 모집·8state(부재 포함)·listing·event snapshot을 대조했다.

후보 SHA-256: `773cde2a9d2e78fe2e4b568fdf00bebe8de3c5016b364d41e535056d1e786585`.
artifact `roster-legacy-candidate`(30일), 로컬 `coverage/de2-c-36721590205/`에 원문을 보관했다.
B7 변환 함수를 공유 도구로 분리했고 정규화 소스의 B7 해시가 §13과 동일함을 확인했다.
Windows CRLF로 로컬 문자열 hook 비교가 실패한 것은 정규화 대조로 분리했으며 운영 파일은 바꾸지 않았다.

이 결과는 정상 fixture의 create/update·legacy 판별 proof 완료다. 다음을 완료로 확대하지 않는다.
- 전체 state 동시 누락, 실제 개인 완료 UI 이후 재진입, 동시 소유권 이전·응답 유실, 실기기.
- 인증 Transaction이 계정/Character 차수를 생성·보존하는 구현, 신청/가입/변경 Snapshot 연결.
- 변경 후보 전체 cutover 재검증과 운영 컴파일/배포. B7의 이전 통과는 이번 소유권 조건 전체 회귀를 대신하지 않는다.
- 현재 넓은 소유권 문서 write 권한의 서버 인증 보안. 이번 fixture의 ownership은 admin 주입이다.

다음 DE2-D는 §5.3의 **completed 반복방 stale 일반 참가자 제한 정리**를 설계하고 demo proof한다.
기존 제거 명령이 완료방에서 거절된 §6의 사례를 출발점으로, 완료 state/event 보존·다음 주 슬롯
제거·목록 동기화·권한/최신 차수 재검증·재시도를 확정한다. 일반 멤버 대표 사례부터 시작하며
stale 공대장/마지막 1인·전체 인증 구현을 같은 구간에 합치지 않는다. 제품 이식·배포는 계속 제외한다.

## 15. DE2-D 완료 반복방 일반 참가자 정리 — 구현 전 demo 계약

코드 사실: `PartyAtomicMemberRemovalWritePlan`은 currentCycleStatus active만 허용하며,
`FirestorePartyAtomicMemberRemovalRepository.remove`는 대상 raidState도 삭제한다.
Rules의 `validAtomicRecruitmentMemberRemoval` 역시 active 주차를 요구한다. 완료방에 이를
그대로 확대하면 완료 이력 삭제 위험이 있으므로 기존 탈퇴/추방 조건은 변경하지 않는다.

이번 후보는 DE2-C를 기반으로 한 별도 `cleanupCompletedOwnership` 명령이다. 제품 연결 전
기술 가설이며 tools에서 생성한 demo Rules로만 검증한다.

- 대상: schema 2, active 모집/ completed 주차, continueTogether true, 2–8명 중 일반 참가자 1명.
  공대장·마지막 1인은 거절한다. 과거 형태 listing의 호환 검증은 이번 후보에서 제외한다.
- 권한: 대상 관계의 기존 Player 본인 또는 현재 슬롯 소유권이 유효한 공대장. 일반 제3자 거절.
  대상 Character와 GameAccount의 현재 소유자/정수 차수가 일치하고 참가 Snapshot보다 차수가
  증가했을 때만 정리한다. A→B→A도 증가 차수로 판별한다. 누락 문서/불일치/음수는 unknown 거절.
- 입력: commandId, expectedRevision, targetIndex, actorIndex, observedOwnershipRevision.
  index는 조회 비용을 줄이는 힌트일 뿐이며 원본 슬롯과 Player를 대조한다. 예상 revision과
  현재 차수를 서버에서 재검증한다. 원본 목록에서 정확히 대상만 제거하고 남은 순서를 보존한다.
- 쓰기: 모집 구성/카운터/revision/명령 표식, 대상 member 삭제, 그룹 listing 동일 구성,
  전용 불변 event 생성. raidState와 완료 이벤트는 쓰지 않는다. 서버도 대상 state의 전후 동일성을
  검사하여 본인에게 별도 삭제 권한이 있더라도 같은 정리 요청에서 삭제/변조하지 못하게 한다.
  state가 이미 다른 방/차수로 바뀌었거나 없으면 그 상태 그대로 보존한다.
- 원자성: 모집 검사에서 member 부재·listing 결과·event를 요구한다. 각 projection 검사는
  같은 요청의 모집 revision 증가 및 명령 표식을 요구한다. 기존 lifecycle 조건은 보존한다.
  모든 참가자의 개인 state를 순회하지 않고 대상 1건만 Rules에서 확인한다.
- 재시도: 대상이 남아 있으면 정상 거래를 시도한다. 없으면 기존 event의 commandId·원본 revision·
  대상·관측 차수·actor가 모두 일치하는 경우에만 이미 처리됨으로 반환한다. event 부재/조회 실패는
  성공이 아니다. 첫 요청에서 존재하지 않는 event를 읽으면 기존 audience read가 거절하므로
  초기 event 조회를 전제하지 않는다. 다른 요청이 같은 대상을 제거하면 충돌로 처리한다.
- 검증: 정상 최대 8인 완료방에서 공대장/본인 정리, 기록 보존, 동일 요청 재시도와 재이전,
  다른 방 state 보존을 먼저 확인한다. 이후 정상 소유자·unknown·stale revision/관측 차수·
  제3자·stale 공대장·부분 쓰기·잔여 슬롯/완료 state 변조의 원자 거절을 확인한다.
  실제 동시 실행 대신 낡은 관측값 거절을 구분하며, 접근/평가 한도는 CI 결과로 판단한다.
  실패 시 보호 조건을 제거하지 않고 해당 경계와 다음 구간을 기록한다.

### 15.1 결과와 미확인 경계

8c284e1 / CI [36724586757](https://github.com/heo0328/LostParty_flutter/actions/runs/36724586757)는
22건 통과했다. 이후 코드 검토에서 unknown 소유자의 null/빈 문자열과 정수 타입 방어를 명시하고,
기존 활성방 제거 경로 회귀를 추가했다. 최종 9dd6d2b / CI
[36725053530](https://github.com/heo0328/LostParty_flutter/actions/runs/36725053530)는 **26건 전부 통과**다.

- 정상 5건: 8인 완료 반복방의 유효 공대장/기존 본인 정리, A→B→A 관계 정리,
  다른 방/차수로 교체된 state 보존, state 부재 유지. 슬롯/member/listing 동기화와
  원본 8개 state·기존 이벤트·그룹 문서/멤버 보존을 대조했다.
- 각 정상 사례에서 동일 요청 재시도는 무변경 성공, 관측 차수가 다른 재시도는 성공으로 처리하지 않았다.
  공대장 정리 후 남은 7명의 advanceCycle도 성공했고 제거된 대상의 completed state는 유지됐다.
- 기존 경로 2건: 최대 8인 활성 그룹방의 정상 추방·본인 탈퇴가 해당 후보에서도 성공했다.
  제거 대상 active state만 삭제되고 다른 참가자의 state와 그룹 멤버 관계는 보존됐다.
- 원자 거절 19건: 정상 소유자, Character/계정 부재, 계정 차수 불일치, null/빈 소유자,
  stale 공대장, 낡은 revision/차수, 실제 제3자, 공대장 대상, member/listing/event 누락,
  listing count/event 대상/잔여 슬롯 위조, 대상 state 삭제/변조. 모집·원본 8state·member·listing·
  event·group/groupMembers snapshot이 유지됐다. 제3자도 모집 읽기 성공 후 쓰기 거절을 확인했다.

최종 후보 SHA-256: `f0d76be0e1740b69bd1f97cb52a81b8888c1f18ec0277ba4a9a8ccfdfd8bf5c6`.
artifact `roster-cleanup-candidate`(30일), 로컬 `coverage/de2-d-36725053530/`에 후보와 결과를 보관했다.
DE2-C 변환을 공유 함수로 추출했으며 §14 해시 동일성을 확인했다. 변경된 것은 tools/demo workflow와
문서뿐이다. 운영 Rules·앱·초기화 설정·데이터·배포는 건드리지 않았다.

한계: 실제 경쟁 Transaction/네트워크 응답 유실/앱 종료는 실행하지 않았고 낡은 입력 거절과
동일 요청 재호출만 검증했다. 실제 인증은 admin 주입이며 넓은 소유권 write 권한 문제는 그대로다.
전체 cutover, legacy listing, public 완료방, 복수 stale/마지막 1인, 실제 실기기·제품 연결은 미확인이다.
이번 후보의 접근/평가 한도는 대표 사례 성공으로만 확인했으며 정확한 사용량/여유 예산은 측정하지 않았다.

다음 DE2-E는 stale 공대장 정리·유효 후임 승계의 설계와 demo proof다. §5.3의 일반 stale 선행 정리
방향과 실행 권한을 대조해야 한다. 공대장까지 stale이면 일반 멤버가 다른 stale 일반 멤버를 정리할
권한은 이번 후보에 없으므로, 선행 정리가 항상 가능하다고 가정하지 않는다. 유효한 가입순 후임
판별과 서버 비용을 먼저 설계하며 권한을 임의로 넓히지 않는다. 마지막 1인 해산은 별도 후속 경계다.

## 16. DE2-E stale 공대장 승계 — 구현 전 demo 설계

2026-10-01 조사: 실제 Router의 `PartyAtomicMembershipCommandAdapter`는 remove Repository로
연결되며 Write Plan은 가입순 배열의 남은 첫 슬롯을 후임으로 선택한다. 기존 정책은 소유권 유효성을
고려하지 않는다. 소유권 정리에 한해 첫 **유효한** 후임을 선택하되 정상 탈퇴·그룹 자격 상실 경로는
수정하지 않는다. 공대장이 stale인 상태에서 다른 stale 일반 참가자의 선행 정리를 요구하면 호출자가
없을 수 있으므로, 그 선행 정리는 성공 전제가 아니다.

- 별도 `cleanupCompletedLeaderOwnership` 명령: 완료 반복방 2–8명, 공대장 한 명 제거.
  유효한 기존 참가자만 호출하고 후임도 현재 소유권이 유효해야 한다. 새 원정대 소유자에게 방 권한을
  주지 않는다. 이전 공대장 차수 증명·모집 expectedRevision을 다시 검증한다.
- 후임 앞의 슬롯은 기존 공대장이거나 최신 계정/Character와 차수가 일치하는 ownershipChanged로
  증명해야 한다. 단순 `!current`는 unknown까지 포함하므로 사용하지 않는다. unknown 앞순번,
  전원 stale, 유효 후임 부재는 정리를 거절한다. 앞순번 stale 슬롯은 이번 명령에서 삭제하지 않는다.
- 모집 구성과 listing·후임 이름/직업 Snapshot·승인 권한 member·전용 event를 같은 거래로 갱신한다.
  후임 Snapshot은 기존 member에서 가져오고 멤버 권한 갱신 Rules에서 원본과 대조한다.
  대상 개인 state의 전후 동일성 검사는 대상 member 삭제 Rules에 배치하고 전체 state는 조회하지 않는다.
  기존 그룹장/그룹 멤버십·완료 이력·자리는 그대로 보존한다. 공대장 고정석 이동은 포함하지 않는다.
- 요청은 DE2-D 입력에 successorIndex와 앞순번 관측 차수 목록을 추가한다. 이벤트에 후임 Player를
  기록하며 재시도 시 동일 대상·후임·revision·관측값의 기존 이벤트가 있을 때만 이미 처리됨이다.
- 비용 가설: 첫 잔여 참가자가 유효하면 소유권 검사는 대상/호출자/후임으로 제한된다. 마지막
  슬롯만 유효한 최대 8인에서는 앞순번 6명의 Character/계정 조회가 늘어 단일 쓰기 접근 한도에
  걸릴 위험이 있다. 배열 순회를 각 projection에서 반복하지 않고 모집 검증 한 곳에서만 실행한다.
  정상 최소 승계와 최대 탐색 경계를 별도 기록하며, 한도 실패를 권한 거절 성공으로 취급하지 않는다.
- 회귀 보호: DE2-D 일반 참가자 정리·활성방 탈퇴/추방, 완료 및 승계 후 주차 전환.
  위조 후임/이름/승인권한·부분 쓰기·stale actor·unknown 앞순번·낡은 revision을 원자 거절한다.
  최대 탐색 실패 시 보호 조건 삭제나 후임 임의 선택을 하지 않고 다음 비용 설계 과제로 남긴다.
  제품 앱/운영 Rules·배포·실기기·마지막 1인 해산은 이번 범위가 아니다.

### 16.1 최초 proof 결과 — 정상 승계 평가 한도로 차단

89ffd8d / CI [36748905075](https://github.com/heo0328/LostParty_flutter/actions/runs/36748905075)는
**26건 통과·신규 정상 승계 1건 실패, 전체 failure**다. DE2-D의 일반 참가자 정리·완료 이력 보존·
재시도·주차 전환·기존 활성방 탈퇴/추방·위조 원자 거절은 새 후보에서도 통과했다.
그러나 첫 잔여 참가자와 호출자가 같은 정상 8인 공대장 승계 거래에서 PERMISSION_DENIED와
`maximum of 1000 expressions`가 발생했다. 모집 update(L4343), 후임 member update(L4387),
listing update(L4593)에 한도 메시지, 대상 member delete/event create에는 evaluation error가
기록됐다. 이 행 번호는 아래 artifact의 생성 Rules 기준이다.

정상 승계 자체가 실패했으므로 승계 후 주차 전환·승계 재시도, 신규 위조 거절 12건과 마지막
순번만 유효한 최대 탐색 사례는 실행되지 않았다. **최대 8인 소유권 문서 접근 한도 실패를
재현했다고 해석하지 않는다.** 지금 확인한 것은 첫 후임 정상 거래의 평가 한도 오류이며,
어떤 조건/문서가 최초 원인인지 또는 먼저 false가 난 뒤 fallback 평가에서 한도를 소진했는지는
미확정이다. 기존 26건의 통과를 신규 승계 성공으로 확대하지 않는다.

후보 SHA-256: `13064f90bcd2d111943036a62bcf9d26f553733db43b7249d8424bedac5a34c5`.
artifact `roster-leader-candidate`(30일), 로컬 `coverage/de2-e-36748905075/`에 원문/결과를 보관했다.
DE2-D 생성 해시는 §15.1과 동일하며 proof harness만 확장해 회귀 검증을 재사용했다.
JS 문법·생성 hook/해시·git diff --check를 확인했다. CI 1회 이후 동일 재시도·보호 조건 삭제·
운영 수정/배포는 하지 않았다. 기존 사용자 초기화 설정 변경도 보존했다.

다음 DE2-E2는 실패한 정상 승계 **단일 거래**의 coverage 전후 차이 및 쓰기 경계 진단이다.
fixture 준비 트래픽을 제외하고 모집/후임/member delete/listing/event의 첫 실패 조건을 분리한다.
최초 조건 불일치와 순수 평가 비용을 구분한 후 그 원인만 최소 보정한다. 조건을 제거한 진단 후보는
운영 후보로 사용하지 않는다. 정상 승계가 통과한 뒤에만 신규 위조 거절과 최대 탐색을 재개한다.
전원 조회를 여러 쓰기에서 반복하거나 단순 부정 판정으로 unknown을 건너뛰는 우회는 금지한다.

### 16.2 DE2-E2 진단 실행 계획

동일 E Rules 소스/동일 정상 거래의 준비 완료 직후와 요청 직후 coverage를 저장한다.
기존 26건 회귀는 skipRegression 옵션으로 생략하고 본 후보를 바꾸지 않은 채 단일 실패만 계측한다.
집계 count/value 변화로 최초 false 또는 반환 누락 구간을 찾는다. 정확한 전체 평가 식 수로
해석하지 않는다. 계측 결과를 확보한 뒤 해당 구간만 보정하거나 쓰기 경계 진단을 추가한다.

첫 계측 ff89505/CI 36827641598: 모집의 소유권·순서·변경 목록·인원·member 부재·listing 대조까지
true가 관측됐고 마지막 event 대조의 완료 반환은 없었다. 정확한 식 수는 미측정이다.
호출자와 후임 index가 같으면 이미 통과한 동일 슬롯 소유권 검사를 재사용하고, 후임 앞순번까지만
검사하도록 단락 평가를 적용하는 최소 후보를 비교한다. 유효성 조건·쓰기·권한은 제거하지 않는다.

### 16.3 DE2-E2 결과 — 첫 유효 후임 승계 정상화, 최대 탐색은 미해결

1e28bf8 / CI [36827919490](https://github.com/heo0328/LostParty_flutter/actions/runs/36827919490)는
**39건 통과·최대 탐색 1건 실패**다. 동일 요청의 중복 소유권 확인과 후임 뒤 슬롯 확인을 생략하는
동등 조건 보정으로 첫 유효 후임 정상 승계가 통과했다. 권한 조건을 제거하거나 운영 Rules를 수정하지 않았다.

- 기존 DE2-D 회귀 26건 통과. 후보 Rules가 변경되어 직접 영향 검증을 다시 수행했다.
- 신규 정상 1건: 8인 완료 반복방의 stale 공대장 제거 → 첫 유효 후임 승인권한/모집/listing
  Snapshot 승계 → 동일 요청 재시도 무변경 → 남은 7명 주차 전환까지 통과했다.
  원본 완료 state·기존 이벤트·그룹 문서/멤버 관계를 보존했고 다른 후임으로 재시도하면 거절했다.
- 신규 원자 거절 12건: 뒤순번 후임 임의 선택, stale 호출자, 앞순번 unknown, 낡은 revision/차수,
  후임 이름/승인 권한 위조, member/후임/listing/event 누락, listing 방장 불일치.
  해당 거절 전후 모집·8state·member·listing·event·group/groupMembers를 대조했다.
- **정상 최대 탐색 실패:** 이전 공대장과 앞순번 일반 참가자 6명은 stale, 마지막 슬롯만 유효한
  8인 방에서 평가 한도 오류가 재현됐다. 실패 전후 snapshot 동일성을 확인했다. 이 실패는 보안
  거절 성공이 아니며 승계 전체 완료/운영 채택 조건을 충족하지 않는다. 문서 접근 한도와 정확한
  최초 소진 지점은 추가 계측 전 확정하지 않는다.

최종 후보 SHA-256: `b411a0a1366a77be7ee95640c471ea794e736dcd251c5aea929d886b9891ccc0`.
최초 계측 `coverage/de2-e2-36827641598/`(변경 전 E 해시 동일), 보정 결과
`coverage/de2-e2-36827919490/`, 원격 artifact `roster-leader-candidate`(30일)에 보관했다.
첫 계측에서 대상/후임/앞순번/목록 조건 true가 관측되고 최종 이벤트 대조 반환이 없었던 사실과
보정 후 같은 정상 사례가 통과한 결과가 누적 비용 원인을 뒷받침한다. 모든 쓰기별 정확한 비용이나
기존 실패의 모든 evaluation error 원인을 개별 확정한 것은 아니다.

다음 DE2-E3는 **복수 stale 앞순번의 유효 후임 선택 비용 설계**다. 단일 모집 검사에 최신
Character/계정 검증을 몰아넣은 구조의 최대 경계를 계측하고, 기존 단건 정리 권한을 임의로
넓히지 않는 제한 원자 검증 분담 방안을 검토한다. stale 증명 없는 건너뛰기·unknown 제거·
새 소유자 권한 승계·인증 때 모든 방 순회는 허용하지 않는다. 같은 단락 평가 조정을 반복하지 않는다.
실제 인증 구현, 호출자와 후임이 서로 다른 정상 사례, legacy/public, 실기기와 마지막 1인은 미확인이다.

## 17. DE2-E3 — 최대 후임 탐색 계측·분담 실험 종료, 최대 경계 미해결

E2 후보 Rules는 유지하고 `leader-max-diagnosis` 실행 범위를 추가한다. 마지막 슬롯만 현재
소유자인 8인 방에서 한 번의 승계 요청 전후 ruleCoverage와 실패 시 전체 snapshot 동일성을
확인한다. 기존 39건을 반복하지 않는다. coverage 반환 조건은 식의 정확한 개수나 문서 접근
횟수가 아니므로 최초 관측 중단 위치와 실제 오류를 구분한다.

계측 후 제한 원자 검증 분담 후보를 설계한다. 이미 필수인 대상 member 삭제·후임 member
갱신·event 생성에 앞순번 stale 검증을 나누는 방향을 검토하되, 모집 validator가 해당 쓰기를
강제하는지와 기존 OR 허용 경로로 분담 검사를 우회할 수 있는지 먼저 확인한다. 전체 거래의
문서 접근 한도는 validator 분리만으로 줄지 않는다. 최신 Character/계정 차수·첫 유효 후임·
unknown 거절·대상 완료 이력 보존을 줄이지 않으며 결과 확인 전 채택하지 않는다.

### 17.1 계측 결과와 분담 후보 계약

bc82548 / CI 36828924578: E2와 동일 해시의 최대 단일 요청은 1,000식 오류로 실패했고
snapshot은 불변이다. coverage 차이에서 `deLeaderPriorAt` 인덱스 0–4는 true이며 5–6의
반환은 관측되지 않았다. 따라서 앞순번 탐색 도중 한도 소진으로 좁혔다. 정확한 식 수와
문서 접근 횟수는 측정되지 않았으며 모든 오류가 접근 한도 때문이라고 단정하지 않는다.

분담 후보는 기존 E2 생성기를 보존하는 별도 demo 변환으로 둔다.
- 모집: 호출자/후임 현재 소유권, 대상 stale, 원자 구성·후임 권한/listing/event 필수 확인 유지.
- 대상 member 삭제: 앞순번 인덱스 0–2와 대상 완료 state 불변 확인.
- 후임 member 갱신: 앞순번 인덱스 3–4 확인, 이름/직업 snapshot 및 권한 변경 범위 유지.
- event 생성: 앞순번 인덱스 5–6 확인, 정확한 event 계약 유지.
- 각 검사에서 후임 이후·삭제 대상만 제외한다. 앞선 정상 소유자 또는 unknown은 건너뛰지 못한다.
- 이 명령의 member 삭제/갱신과 event 생성은 전용 분기를 사용해 기존 OR 허용 경로로
  분담 검사를 우회하지 못하게 한다. 다른 명령은 기존 validator를 유지한다.

먼저 최대 사례만 실행한다. 통과 시 영향받는 기존 회귀와 각 분담 구간의 정상/unknown
건너뛰기·차수 위조·부분 쓰기·호출자/후임 분리 사례를 검증한다. 실패하면 같은 분담 방식의
미세 조정을 반복하지 않고 전체 거래 비용/별도 신뢰 경계 필요성을 후속 설계로 기록한다.

### 17.2 분담 후보 결과 — 미채택

995e3f8 / CI 36829347691도 최대 정상 요청 1건 실패다. 후보 SHA-256은
`a08641b8188dcd3d2f6fe7f506fd0a18eee7633a1c532b4e90abaf60dd0de0f3`.
coverage에서 분담한 인덱스 0–5는 true, 6은 undefined로 관측됐다. 로그에는 1,000식 한도와
`gameAccounts/de-account-player-extra-5`의 get Service call error가 함께 있다. 이 문서는
fixture에서 생성했지만 정확한 문서 접근 횟수/Service call error의 내부 원인은 미확정이다.
따라서 분담만으로 전체 요청 경계를 해결했다고 볼 수 없다. 실패 후 전체 snapshot은 불변이다.
최대 정상 요청이 실패했으므로 이 후보의 위조 거절을 보안 통과로 취급하거나 회귀 39건을
재실행하지 않았다. 기존 E2 소스/통과 결과는 그대로 보존된다.

코드 검토로 발견한 추가 위험(실행 재현은 아직 하지 않음):
- 모집의 `!existsAfter(targetMember)`만으로는 삭제 쓰기 자체를 강제하지 못한다. 이미 문서가
  없으면 그 문서에 나눈 검사도 실행되지 않을 수 있다. 존재 전제 또는 다른 필수 쓰기로 묶는
  설계가 필요하며, 현재 후보를 안전한 정리 명령으로 채택할 수 없다.
- 후임 갱신 전용 분기가 after의 lastCommandType만 보므로 승계 뒤 그 마커가 남은 상태에서
  독립 권한 변경까지 가로막을 수 있다. 실제 새 원자 명령과 잔존 마커를 구분해야 한다.

동일 분담 방식의 미세 조정은 중단한다. 다음 DE2-E4는 현재 Character와 gameAccount를
매 슬롯 읽는 구조 대신, 인증된 슬롯의 원정대 식별자와 소유권 원장으로 판별할 수 있는지
조사·설계한다. 원장 단일화는 미검증 가설이며 Character 연결 불변성·인증 부분 실패·legacy
처리의 근거 없이 조회를 삭제하지 않는다. 불가능하면 제한 다단계 정리/신뢰 서버 방안을
비교하고 권한 또는 인프라 변경은 별도 사용자 결정으로 남긴다. 신규 사용자 이용은 어느
경우에도 이전 방 정리에 종속시키지 않는다.

산출물: 각 CI의 `roster-leader-candidate` artifact(30일), 로컬
`coverage/de2-e3-36828924578/`, `coverage/de2-e3-36829347691/`에 후보/결과/전후 coverage.
JS 문법·생성 hook·diff 검토·git diff --check를 수행했다. 운영 파일/배포/실기기 변경 없음.
DE2-E3의 계측·설계 실험 구간을 종료하지만 최대 승계 문제 및 제품 기능은 미완료다.

## 18. DE2-E4 — 재설계: 제한 단건 정리 후 승계 (제안, 구현 전)

### 18.1 코드 대조 결과

이번 구간은 조사·설계만 수행했다. 아래 사실은 현재 추적 코드 기준이며 운영 활성 소스의
독립 대조나 새 emulator 검증 결과가 아니다.

- 실제 Router(`lib/app/router/app_router.dart:355–370`)는 자동 인증에
  `LocalGameAccountVerificationGateway`, 수동 인증에 `FirestoreManualVerificationRepository`를 연결한다.
- 자동 `_claimOwnership`(163행부터)은 binding→identity claims→기존 account→모든 저장 Character를
  읽고 account/Character/claim/playerGameAccounts를 같은 Transaction에서 쓴다. 기존 ID를
  재사용하고 API에서 빠진 Character도 이전 소유자를 갱신하지만 ownershipRevision은 아직 없다.
- 수동 `_claimForRequester`(776행부터)는 claim/account 불일치와 이전 소유자를 재검사한 뒤 같은
  종류의 문서를 원자 갱신한다. 호출부 458/539/718/1058행도 후속 구현 대상이다. 두 인증의
  전체 set이 추가할 차수 필드를 누락하지 않도록 함께 변경해야 한다.
- 실제 `firestore.rules:3964–3977`은 account/Character/identity claim에 signedIn 쓰기를 허용한다.
  문서의 단일 소유권 원장 의도와 달리 Character.gameAccountId의 서버 불변성이 보장되지 않는다.
  기존 인증이 원자적으로 쓰는 사실과 악의적 직접 쓰기까지 차단하는 보장은 구분한다.
- `PartyAggregateSlot` 및 Character 변경 Write Plan은 gameAccountId/ownershipRevision을 보관하지
  않는다. 변경 시 replacement 슬롯을 재구성하므로 필드 추가만 하고 writer를 그대로 두면 유실된다.
- DE2-E3의 8인 검사는 최대 8 Character+8 account를 읽는다. 다른 원정대인 최악 조건에서
  인증 binding/방/member/state/listing/event도 필요하다. 각 쓰기별 호출과 전체 요청의 cache
  제외 여부는 emulator로 별도 확인해야 하며 coverage는 정확한 비용 계측기가 아니다.

### 18.2 대안 비교와 권고

| 대안 | 장점 | 필요한 계약 변경·한계 | 판정 |
|---|---|---|---|
| 원정대 문서만 읽기 | 소유권 조회 최대 16→8개 문서 후보 | 검증된 슬롯의 원정대 ID, Character 연결 불변, 차수 전이 보호, 삭제/보관 및 legacy 이행이 선행. 현재 Character 부재/불일치를 unknown으로 보는 계약과 동등하지 않음 | 즉시 채택 안 함 |
| 한 명씩 제한 정리 후 승계 | 현재 Character+account 대조 및 unknown 거절 유지, 한 명령의 대상 수 고정 | stale 방장일 때 유효 참가자가 다른 stale 일반 참가자를 정리할 제한 권한 필요. 전체 과정은 여러 거래 | **권고, 사용자 결정 필요** |
| 신뢰 서버에서 한 번에 처리 | 서버에서 조회·원자 처리 가능성 | 서버 인증 명령·인프라·배포/운영 범위 추가, 별도 비용/설계 검토 필요 | 현재 범위에서 채택 안 함 |

원정대 단독 판별은 단순 성능 보정이 아니다. 인증 시 Character/원정대 연결을 검증해 봉인하고
모든 이후 writer에서 유지해도, Character 단독 부재를 조회 없이 감지할 수 없다. 이를 표시용
projection 부재로 새로 해석할지, 기존 unknown 계약을 유지할지는 별도 결정이다. 과거 슬롯에
현재 차수를 복사하는 backfill은 과거 관계를 부활시킬 수 있으므로 금지한다. 이 복잡성을
이번 승계 실패의 우회책으로 도입하지 않는 것이 권고 이유다.

### 18.3 제안 명령과 권한의 정확한 변경점

§5.3의 일반 stale 대상은 본인 또는 유효 공대장만 정리한다. **다음 예외만 추가 제안**한다.
현재 공대장도 ownershipChanged이고 호출자가 현재 방의 유효한 참가자인 경우, 호출자는
다른 일반 참가자 한 명의 ownershipChanged 관계를 정리할 수 있다. 정상 참가자 추방·자리
변경·완료 체크 변경·그룹 권한은 얻지 않는다. 새 소유자가 이전 방의 참가자가 아니라면
이 명령을 호출할 수 없다. 이 예외는 아직 승인/구현되지 않았다.

- 입력: roomId/expectedRevision/commandId, actor·target·leader의 슬롯 식별자 및 관찰 차수.
  클라이언트의 위치/차수/판정은 증거가 아니며 서버가 저장 슬롯과 최신 문서로 재검사한다.
- 전제: 완료된 반복방, 2–8인, 현재 유효 호출자, 대상은 일반 참가자, 방장과 대상 모두 확정 stale.
  Character/account 불일치·부재·조회 실패는 unknown으로 중단한다. 차수 감소나 같은 차수의
  소유자 불일치를 정상 이전으로 간주하지 않는다. A→B→A에서도 참가 당시 차수로 판별한다.
- 쓰기: 대상 하나의 슬롯/member와 구성 count/listing, 명령 event를 한 Transaction에서 갱신한다.
  대상 completed state·과거 event·그룹 관계는 그대로 둔다. 다른 방/새 차수 state를 삭제하지 않는다.
- 일반 정리 후 방장을 정리할 때는 **남은 첫 일반 참가자만** 후임 후보로 사용한다. 유효하면
  기존 승계 명령의 후임/member/listing/event를 원자 갱신한다. 앞사람이 stale이면 그 사람부터
  단건 정리하고 unknown이면 멈춘다. 뒤의 유효 후보를 한 요청에서 끝까지 탐색하지 않는다.
- 기존 가입 순서는 배열 위치가 아닌 현재 Aggregate의 보존된 순서를 따른다. 자리 이동으로
  파티 위치가 바뀌어도 살아 있는 참가자의 순서·캐릭터·역할은 정리 과정에서 재배치하지 않는다.
- 최대 8인 중 마지막 한 명만 유효한 사례는 일반 stale 6명 정리+stale 방장 승계 **최대 7거래**.
  방장이 아닌 정상 참가자를 제거하지 않는다. 전원 stale/유효 호출자 없음은 기존 운영 진단 범위다.
  새 사용자의 새 방 생성·신청·가입에는 이 이전 방 정리 완료를 요구하지 않는다.

### 18.4 비용 예산과 저장 경계 (예측, 통과 수치 아님)

| 항목 | 종전 최대 승계 | 제안 일반 단건 | 마지막 승계 |
|---|---|---|---|
| 소유권 검증 대상 | 최대 8명 | 호출자·대상·방장 3명 | 호출자·방장·첫 후임 최대 3명 |
| Character/account 고유 문서 상한 | 16 | 6 | 6 (호출자=후임이면 4) |
| 부수 문서 종류 | binding/room/대상 member/후임 member/state/listing/event | binding/room/대상 member/state/listing/event | 종전과 동일 |
| 거래의 고유 경로 설계 상한 | 23 | 12 | 13 |

표는 그룹 완료방에서 before/after를 같은 경로로 센 설계상 합계이며 Rules 접근 호출수와
동일하지 않다. get/getAfter/exists/existsAfter, Rules 내부 호출·분기, 부수 쓰기의 검사를 따로
예산화해야 한다. 일반 단건에서도 소유권 6개를 Aggregate에 모두 몰면 쓰기당 한도를 넘을
수 있으므로 다음 최소 proof에서 분담과 접근 호출을 확정한다. 예상만으로 통과 선언하지 않는다.

분담을 사용한다면 Aggregate가 대상 member의 **변경 전 존재와 변경 후 부재**를 강제하고,
member 삭제는 대상 stale·state 불변을, Aggregate는 호출자 current·방장 stale·정확한 구성을
검증하는 식으로 책임을 한정한다. 대상 member가 이미 없으면 이 경로를 거절해 누락 쓰기로
검사를 생략하지 못하게 한다. 해당 손상 데이터는 별도 진단이며 자동 복구하지 않는다.
전용 분기는 잔존 lastCommandType만 보지 않고 새 revision/commandId 및 서버 시각의 실제
전이를 구분한다. 일반 권한 갱신을 막거나 기존 OR 경로로 정리 검증을 우회하면 채택하지 않는다.

### 18.5 중간 실패·동시성·UX

- 유효한 기존 참가자에게 정리 대상/승계 가능 상태를 보여 주고 한 번의 확인으로 제한 정리를
  시작하는 UX를 제안한다. 새 원정대 인증 사용자에게 과거 방 조사나 정리를 요구하지 않는다.
- 각 성공 거래는 독립적으로 유효한 상태다. 중간 실패 시 이전 성공을 되돌리거나 정상 참가를
  지우지 않는다. 남은 대상과 중단 사유를 표시하고 다시 조회한 뒤 재시도한다.
- 전체 7거래의 all-or-nothing을 약속하지 않는다. 기존 방장 표시는 최종 승계까지 남을 수 있다.
  stale/unknown 상태에서 주간 완료·다음 주 재참가를 실행하지 않는 서버 검증은 계속 필요하다.
- 거래마다 commandId와 expectedRevision을 새로 사용한다. 응답 유실은 정확한 기존 event의
  대상·호출자·차수·revision을 대조해 같은 요청만 성공 수렴시킨다. 단순 대상 부재는 성공 아님.
- 두 기기 정리/인증/완료/승인 경합은 최신 소유권과 revision을 다시 확인한다. 변경된 관계는
  재조회하고 새 데이터를 지우지 않는다. 앱 종료 후 방 데이터와 event가 재개의 근거다.
- 1회 실행은 시작 시 보인 대상과 최대 7거래로 제한한다. 중간에 다른 변경이 끼면 중단·재조회하며
  계속 추가되는 대상을 무제한 처리하지 않는다. 로그/안내는 부분 성공과 전체 완료를 구분한다.

### 18.6 다음 최소 proof와 결정 게이트

**필요한 사용자 결정:** stale 공대장이 있는 완료 반복방에서 유효한 기존 일반 참가자에게
다른 stale 일반 참가자 한 명의 제한 정리 권한을 허용할 것인가. 허용 전 Rules/앱을 수정하지 않는다.
이는 정상 추방 권한의 확대나 새 소유자의 이전 방 접근 허용이 아니다.

승인되면 최대 8인·마지막 참가자만 유효한 하나의 정상 연쇄를 먼저 demo에서 검증한다.
정상 통과 후 같은 후보에서 정상/unknown 대상 삭제, 유효 방장 우회, 외부 호출자, 차수 위조,
누락 member·event·listing, 잔존 마커의 일반 명령 방해, 응답 유실·두 기기 충돌을 표적 검증한다.
호출자와 후임이 다른 정상 승계는 별도 권한 경계로 포함한다. 기존 D/E2 회귀는 실제 변경된
후보에만 영향 검증하고, 정상 실패를 위조 거절 성공으로 계산하지 않는다.
제품 인증 차수·Snapshot/UI·활성방/마지막 1인·운영 배포는 이 최소 proof와 구분한다.
이번은 문서 내용 대조와 git diff --check만 수행하며 기존 22 실패/analyze 51건은 보존한다.

## 19. DE2-E5 — 제한 정리 후 승계 demo 실행

사용자가 §18 제안에 이어 다음 구간 진행을 지시하여 제한 권한 예외를 포함한 demo proof에
착수한다. 운영 Rules/앱 반영은 포함하지 않는다. 완료 반복방의 stale 방장·stale 일반 대상·
current 기존 호출자만 허용하는 별도 명령을 추가하고 기존 D의 본인/유효 방장 정리는 유지한다.
대상 stale/state 불변 검증은 필수 member 삭제에서, actor current/leader stale 및 구성은
Aggregate에서 검사한다. 삭제 전 존재를 강제하며 새 revision 전이에만 전용 분기를 적용한다.
승계는 E2 후보를 기반으로 첫 잔여 참가자만 허용하고 전체 앞순번 탐색을 제거한다.
최대 연쇄가 먼저 성공해야 위조/원자성 검증을 의미 있는 결과로 기록한다. 인증 소유권은
admin fixture로 준비하며 실제 자동·수동 인증의 서버 증명까지 검증한 것으로 확대하지 않는다.

### 19.1 최초 결과와 직접 영향 보완

 d98a945 / CI 36831457106은 최대 6명 정리+승계+주차 전환 및 위조/부분 쓰기 14건이
통과했다. 동시 중복 요청은 하나의 permission-denied로 Promise.all이 실패했고, 서로 다른
호출자/후임 승계는 1,000식 한도로 실패했다. 기존 D 회귀는 이 두 실패로 아직 실행하지 않았다.

동시 요청은 SDK가 Rules 거절을 자동 재시도한다고 가정하지 않고, 결과 수집 뒤 정확한
command event를 재조회하는 명시 재시도 경계로 보완한다. 두 거래의 최초 room 읽기를 맞추며
revision이 한 번만 증가하고 다른 차수의 재시도는 성공으로 취급되지 않는지 확인한다.
다른 후임의 소유권 검증은 Aggregate가 필수로 요구하는 후임 member 갱신 validator로 옮긴다.
최대 대상 수/첫 잔여 후임 정책/소유권 검사 자체는 유지한다. stale 후임·후임 쓰기 누락과
뒤순번 선택 거절, 중간 unknown 뒤 재개, 조회 후 호출자 소유권 변경도 직접 영향 검증에 포함한다.

### 19.2 재개 결과 — 최소 demo proof 통과

사용량 한도로 자동 승인 검토가 완료되지 않아 이전 커밋·push·CI 명령은 실행되지 않았다.
사용자의 재개 지시 후 로컬 diff를 보존한 채 4af81d9로 커밋·push하고 CI 36838000885를
실행했다. **신규 22건 + 기존 D 회귀 26건 = 48건 모두 통과**했다.
후보 SHA-256: `75259f0638f7c3ec14bf6210655a0fbc3a9d66329301d988f9cb3ba8dba83f02`.

- 최대 8인: 일반 stale 6명 단건 제거→stale 방장 제거/마지막 참가자 승계→주차 전환 성공.
  완료 state·그룹 관계·기존 event 보존, listing 일치와 각 정리의 동일 요청 재시도 확인.
- 정상/unknown 대상, 정상/unknown 방장, stale 호출자, 외부 호출자, 낡은 차수/revision,
  member 부재/누락·event/listing 누락·잔여 슬롯 변조·완료 state 삭제 등 14건 원자 거절.
- 동시 중복 요청 후 정확한 명령 재시도는 한 번의 revision 증가로 수렴했다. SDK 자동 재시도만
  기대하지 않으며 permission-denied/aborted 뒤 event 대조는 앱 구현에도 필요하다.
- 호출자와 첫 후임이 다른 승계 및 이후 방장의 일반 승인 권한 변경 성공. stale 후임·후임
  쓰기 누락·뒤순번 후임 선택 거절. 부분 정리 뒤 unknown으로 중단하고 재조회 후 재개 성공.
- 모집을 읽은 후 호출자의 소유권을 바꾸는 순서 제어에서 정리가 거절되고 방 데이터는 불변.
  이는 한 종류의 경쟁 경계이며 인증/승인/완료의 모든 동시 조합 통과를 뜻하지 않는다.
- 기존 D 26건: active leave/kick, 본인/유효 방장/재취득 소유자 정리, 다른 방·부재 state 보존,
  기존 위조 거절 및 정리 후 전환을 같은 최종 후보에서 통과했다.

비용은 앞선 8명 전체 순회 대신 요청당 최대 3명의 소유권 대조로 제한했다. 일반 정리
Aggregate는 호출자/방장(4 소유권 문서), 필수 대상 삭제는 대상(2 문서)+완료 state 보존을 맡는다.
승계 Aggregate는 호출자/방장, 필수 후임 갱신은 후임 소유권을 맡는다. 그룹방 일반 정리는
4 writes, 승계는 5 writes이며 부분 쓰기는 허용하지 않는다. 현재 최대 fixture에서 요청이
통과한 근거를 확보했지만 Rules 엔진의 정확한 식/문서 접근 호출수는 측정하지 않았다.

검증 산출물은 CI의 `roster-leader-candidate` artifact(30일)와 로컬
`coverage/de2-e5-36838000885/`에 보관했다. Rules 컴파일 경고는 로그에서 관찰되지 않았다.
Actions/Node 의존성 deprecation 경고는 Rules 경고와 구분한다. JS 문법·생성 hook·diff 검토와
`git diff --check`를 수행했고 Flutter/실기기/운영 배포는 수행하지 않았다.

**판정:** DE2-E5 제한 단건 정리/첫 후임 승계 최소 서버 proof 완료. 이전 E3의 한 거래 최대
탐색 후보는 계속 미채택이며 제품 인증/UI 구현 완료가 아니다. 다음 DE2-F는 완료 반복방의
마지막 1인 stale 본인 정리·해산 경계를 기존 정책과 대조하여 설계/최소 proof로 확인한다.

### 20. DE2-F 마지막 1인 완료방 해산 — 조사와 검증 계획

2026-10-01: 사용자는 실기기 테스트 전 남은 구간의 순차 진행을 승인했다. 브랜치 고정은 유지한다.
현재 코드의 `disband`는 이전 공대장 Player 권한으로 실행하며 Character 소유권 이전과 독립적이다.
완료 회차에서는 commandTargets를 비우고 state를 보존한다. active 상태의 반복 모집은 그룹 count를
한 번 감소시키고 listing을 삭제한다. 따라서 마지막 1인 정리에 새 권한을 추가하기보다 이 경로를
우선 재사용한다. 정상 공대장의 일반 해산 권한도 유지한다.

- stale 정리 안내는 현재 소유권과 관찰 차수를 재조회한 뒤 제공한다. unknown을 stale로 판정하지 않는다.
  일반 해산 자체는 소유권 판정과 독립적이므로 current/unknown 공대장의 명시적 해산까지 금지하지 않는다.
- 마지막 슬롯과 member, 완료 state, 과거 event, 그룹 membership은 해산 이력으로 보존한다.
  state가 부재하거나 다른 방/차수로 교체되어 있어도 건드리지 않는다.
- 서버 proof는 E5 후보를 그대로 사용하여 정상 해산, 외부 새 소유자 거절, 부분 쓰기,
  낡은 revision과 중복 해산을 확인한다. 이미 해산된 방의 재시도는 정확한 command/event 대조 후
  성공 처리하며 다른 commandId의 중복 요청은 새 해산으로 처리하지 않는다.
- 기존 validator는 group count를 강제하지만 event/listing 보존·원자성은 실제 거절 검증 전까지
  입증된 것으로 간주하지 않는다. 누락 허용이 발견되면 해당 경계만 보강한 후보를 설계한다.
- 인증 차수/앱 연결은 이 proof 이후 순차 진행한다. 운영 Rules 및 제품 완료를 뜻하지 않는다.

#### 20.1 기존 경로 결과와 최소 보강

afaede0 / CI 36839657706: 10건 중 7건 통과, 3건 실패. completed/부재/교체 state 보존 해산,
정확한 이벤트 재시도, group 누락·낡은 revision·외부 새 소유자·해산 재쓰기 거절은 통과했다.
listing 삭제 누락, event 누락, completed state 동시 삭제는 허용됐다. 기존 앱 정상 거래에는
없는 변형이며, 서버 원자 계약의 빈틈으로 확인했다.

최소 후보는 **마지막 1인 completed 회차의 disband**에만 기존 허용식 앞에 추가 guard를 둔다.
기존 공대장 권한/해산 validator는 모두 유지하고, 변경 필드 제한·단일 기존 슬롯/member 보존·
state 동일성(부재 포함)·그룹 listing 부재·새 정확한 disband event를 강제한다. 이를 OR 대안으로
추가하지 않아 옛 허용식으로 우회할 수 없게 한다. 다른 인원/활성 회차는 기존 경로 그대로다.
일반 해산은 current/unknown 소유권에서도 기존 공대장 권한으로 허용하며 stale 전용 권한을 만들지 않는다.

f56c48e / CI 36840112755: guard 뒤 전체 기존 허용식을 평가하면 state가 있는 정상 사례에서
1,000식 한도에 도달했다(부재 state만 통과). 다음 후보는 해당 명령만 기존 lifecycle validator로
직접 분기한다. guard와 lifecycle 검사는 모두 유지하고, 무관한 멤버/신청 validator 탐색만 제외한다.
다른 명령은 원래 허용식을 유지한다. 정상 실패 상태에서 위조 거절 검증은 실행하지 않았다.

#### 20.2 최종 결과

e7f447e / CI 36840397200에서 10/10 통과. 완료/부재/교체 state 보존, 이력/member/그룹 관계 보존,
정확한 이벤트 재시도, group/listing/event 누락·완료 state 삭제·낡은 revision·외부 새 소유자·
중복 해산 쓰기 거절을 확인했다. E5 기존 후보는 수정하지 않았다. 새 guard는 마지막 1인 completed
disband에만 적용되며 전체 기존 회귀는 제품 이식 최종 단계에 수행한다. 생성 Rules SHA256:
`0857df904122b5925afc7aa0fb4417104cfd58518c1a4631b14eaee98e5166f7`.
Rules 컴파일 경고 미관찰(별도 Node/Actions 경고 있음). 제품/운영 Rules는 아직 변경하지 않았다.

### 21. DE2-G 실제 인증 차수 저장 설계

F 서버 경계를 마친 뒤 실제 Router가 사용하는 자동 `_claimOwnership`과 수동 `_claimForRequester`에
같은 순수 소유권 전이 정책을 연결한다. 수동 승인·강제·방어 실패·만료 확정은 공통 함수 경유를 유지한다.

1. transaction에서 읽은 GameAccount가 없으면 1, 기존 필드가 없으면 0, 같은 owner이면 현재 차수,
   다른 owner이면 +1한다. 기존 계정의 owner 부재/손상, 차수 null/음수/비정수는 복구 추정 없이 거절한다.
2. 기존 Character를 쓰기 전에 GameAccount ID·이전 owner·차수 일치를 검사한다. 참조된 계정이 없는데
   기존 Character가 남은 경우도 새 계정으로 오인하지 않는다. 없는 신규 Character만 생성 가능하다.
3. GameAccount와 모든 기존/새 Character에 같은 차수를 기록한다. API 목록에서 사라진 Character도
   기존 missingFromLatestRoster 정책과 함께 차수를 반영한다. 표시 필드와 다른 계정은 변경하지 않는다.
4. 전이 계산은 transaction 재실행마다 최신 계정 Snapshot으로 수행한다. 같은 owner 재시도는 차수를
   올리지 않고 A→B→A는 1→2→3으로 증가한다. 실제 Auth 복구/그룹 권한 이전은 추가하지 않는다.
5. 검증은 일반 인증 UI 중복 테스트보다 legacy/잘못된 차수/불일치/재이전 정책 경계를 우선한다.
   동시 인증 서버 검증은 Rules 차수 계약과 함께 수행한다. 앱의 순수 정책 통과를 서버 강제 보장으로
   기록하지 않는다. 기존 22 실패/51 analyze 항목 중 해당 인증 경로 영향은 구현 검증 전에 분류한다.
6. 이 단계만 빌드해 실기기 완료 판정하지 않는다. 참가 Snapshot 저장·읽기/Rules 전환을 함께 마친 뒤
   디바이스 테스트를 전달한다. 현재 운영 Rules의 넓은 인증 쓰기 권한을 보안 완료로 표현하지 않는다.

#### 21.1 인증 차수 서버 경계 (G2)

G 앱 정책 4건+기존 인증 시작 3건 및 변경 파일 analyze 통과. 다음 demo 후보는 GameAccount
create 차수 1, update 동일 owner 차수 유지/다른 owner +1을 강제한다. legacy 양쪽 필드 없음은
0으로 해석하지만 소유권 이전에서 차수 누락은 거절한다. 이미 차수가 저장된 문서는 필드 삭제를
허용하지 않는다. Character는 getAfter(GameAccount)의 owner/차수와 일치하고 기존 계정 ID를 유지한다.
일반 Character 표시 갱신은 소유권을 바꾸지 않는 한 기존 legacy 누락 필드를 유지할 수 있다.
계정/Character 삭제 후 차수를 재설정하는 우회는 차단한다(실제 인증 경로는 삭제하지 않는다).

이는 기존 signedIn 인증 쓰기 경계 안에서 데이터 전이만 보강한다. Spark 로컬 장비 판정의 진위나
수동 운영자 승인 자체를 서버가 새로 검증한다는 의미가 아니다. 해당 기존 신뢰 한계는 유지한다.
Rules는 Character마다 계정 한 건만 참조하며 전체 Character 목록 순회 검사를 추가하지 않는다.
인증 앱은 모든 Character를 같은 transaction으로 갱신한다. 서버는 미갱신 Character를 현재 소유권으로
인정하지 않는 후속 사용 검증과 함께 방어한다. 동시 인증과 중복 동일 owner 재시도, A→B→A 및
차수·owner 불일치 거래의 원자 거절을 최대 8 Character fixture에서 확인한다.

G2 첫 실행(9a5658e / CI 36841529052)은 전체 실패. test helper가 withSecurityRulesDisabled의
반환값을 Snapshot으로 오인해 undefined를 반환했다. 출력된 거절 PASS도 전후 데이터 보존을 검증한
근거로 사용하지 않는다. Snapshot을 명시 저장/검사하도록 수정한다. 동시 인증은 Rules가 낡은 전이를
permission-denied로 거절할 수 있으므로 모든 요청의 즉시 성공을 요구하지 않는다. 최소 한 거래 성공,
계정/Character 일관성, 거절 사유 제한, 사용자 명시 재시도에 해당하는 최신 상태 전이를 검증한다.
permission-denied를 앱이 자동 무한 재시도하도록 바꾸지 않는다.

527ea62 / CI 36874438459 최종 15/15 통과. 정상/legacy/재이전, 차수 누락·감소·불일치 거절,
8 Character 거래의 원자성, 삭제로 차수 초기화 거절, 경쟁 거절 후 재시도와 동일 owner 멱등성을 확인했다.
8 Character는 대표 검증 fixture이며 원정대 최대 캐릭터 수를 8로 제한한 것이 아니다.
후보 SHA256 `26a9aa103ff05ff7aa4d3202c68f0733a18c393b8b51b81c3e2da94e570b3097`.
제품 Rules 이식 및 실제 장비/수동 인증 거래의 실기기 통과를 의미하지 않는다.

### 22. DE2-H 참가 Snapshot 연결 순서

G2 검증 후 H1에서 Domain/Mapper/Write Plan의 차수 보존부터 연결한다. 슬롯의 선택 필드
ownershipRevision은 누락과 명시 값 0을 구분해 읽고 그대로 저장한다. null/음수/비정수는 손상으로
거절한다. 기존 legacy 슬롯을 자리를 이동했다는 이유로 현재 차수로 바꾸지 않는다.
신규 생성·가입·참가 Character 변경에는 호출 Repository가 검증한 차수를 전달하며 member/state/slot에
같은 값을 기록한다. 다른 원정대 Character로 바꾸면 새 Character의 차수를 사용한다. 자리 교환은
양쪽 각자의 차수를 유지하고, 다음 주 state 재생성은 참가 당시 슬롯 차수를 그대로 사용한다.
신청은 제출 당시 차수를 별도로 기록하고 승인은 이를 현재 차수와 대조한 뒤 가입에 전달한다.

H2는 실제 Router가 쓰는 Atomic Repository와 후보/점유 읽기 흐름에 최신 계정-Character 확인을
연결한다. A→B→A의 이전 active/completed 상태가 신규 이용을 막지 않게 하되 과거 이벤트는 보존한다.
구세대 state 대체는 정확한 이전 버전과 현재 소유권을 검증하는 원자 쓰기로 한정한다. 다른 방 정리를
선행 조건으로 두지 않는다. 승인자는 신청자 private state를 읽지 않는 기존 계약을 유지한다.

H3에서 생성·신청·가입·변경·개인 완료/점유·lifecycle Rules에 차수 일치와 변경 불가 경계를 연결한다.
H1만으로 기능을 활성화하거나 신규 인증 차수에 누락 Snapshot 쓰기를 허용하지 않는다. 운영 배포와
사용자 실기기 전달은 전체 연결·회귀 검증 후 수행한다. 보호 목록은 기존 생성/그룹 가입/캐릭터 변경/
자리 이동·탈퇴·추방·완료·반복 전환과 legacy 누락 데이터다. 정상 UI 반복 자동 테스트 대신 차수
유실·재승인·재취득·원자성·최대 인원 서버 경계를 검증한다.

#### 22.1 H3 서버 연결의 첫 경계

신규 member/state는 현재 소유권과 차수가 일치해야 한다. state와 member, 초기 slot과 member의
차수도 같아야 한다. 신청은 applicantPlayerId로 현재 소유권을 검증하고 승인에서는 이전 pending
신청의 Character/차수를 가입 member와 대조한다. 재신청/캐릭터 변경의 필드 허용 목록만 확장한다.

Aggregate에서 슬롯 차수만 위조해 과거 관계를 되살리는 것을 막기 위해 바뀐 슬롯에 한해서
getAfter(member)의 Character/차수를 대조한다. 그대로 남은 슬롯은 기존 list의 정확한 map 포함 여부로
통과시키고 Character를 전원 재조회하지 않는다. 자리 이동은 member의 차수 불변 계약을 재사용한다.
최대 8 슬롯의 단순 비교 비용은 새 후보에서 확인해야 하며 기존 E5 최대 경계를 미검증으로 확대하지 않는다.
H3 첫 proof는 생성·신청·승인과 슬롯/차수 위조를 먼저 확인한다. 구세대 state 대체와 수동 완료·점유/UI는
그 다음 연결로 구분하며, 이 중간 후보를 운영에 배포하지 않는다.
public/legacy 전체 조합, 실제 인증 차수 보호·Snapshot 작성·앱 연결과 운영 전환은 별도 남는다.

H3 최초 CI 36876958794는 Rules 컴파일 단계에서 실패하여 시나리오 결과가 없다.
원인은 생성기의 trailing-space 검색이 줄바꿈된 모집 update를 놓치고 하위 member부터 그룹까지
감싼 것이다. 정확한 줄 시작과 첫 세미콜론 경계로 제한하고, 최대 8인 정상 자리 교환을 추가한다.
운영 Rules는 변경하지 않으며 수정 후보의 서버 검증 후 다음 연결을 진행한다.

H3 de88e8b / CI 36883705580은 컴파일 수정 후 10건 통과, 정상 8인 교환 1건은 1,000식 초과로 실패했다.
member update가 캐릭터 변경 validator를 먼저 평가하는 비용을 확인했다. 위치 필드만 변경한 요청은
기존 validMemberPositionChange를 먼저 평가하는 후보로 비교한다. 기존 검증 조건은 제거하지 않는다.
최대 정상 사례 실패 상태이므로 해당 후보를 운영 채택하거나 H3 완료로 처리하지 않는다.

H3 참가 경계 후보 84f5ad1 / CI 36884163312는 11/11 통과했다. 정상 차수 1 및 legacy 생성·신청·승인,
누락/0/미래 차수 거절, A→B→A의 오래된 승인 거절과 명시 재신청, 최대 8인 자리 교환의 차수 보존,
member 변경 없는 slot 차수 위조 원자 거절을 확인했다. 평가 순서만 바꿔 기존 validator를 보존했다.
후보 SHA256 `21914c4106dd7a61282876647a6fd9e1fcb415e8055ba32d83a7675ccc83f43f`.
이 결과는 구세대 state 대체, 모든 Character 변경 조합, E5 전체 결합 회귀 또는 운영 배포 완료가 아니다.

#### 22.2 다음 H3 구세대 점유 대체의 저장 경계

현재 inspector는 state 식별자·주차·부모 모집 상태만 판정한다. Rules의 신청/재신청은 state 존재 자체로
거절하고 weeklyRaidClaims도 차수 없이 존재만 검사한다. 따라서 새 계정 B의 별도 Player 경로뿐 아니라
A→B→A의 같은 Player 재취득을 검증해야 한다. 기존 상태를 먼저 삭제하는 우회는 사용하지 않는다.

- 서버가 현재 계정/Character 소유권을 검증한 차수보다 낮은, 유효한 정수 차수의 같은 Player/Character/
  raid state만 대체 대상으로 한다. 누락은 legacy 0, null/음수/비정수/미래 차수는 unknown으로 거절한다.
- 신규 참가의 기존 member/slot/state/aggregate/event 원자 조건을 그대로 적용한다. 승인자는 신청자
  private state를 조회하지 않는다. Rules는 resource의 최신 상태를 검증하고 클라이언트가 본 낡은 값에
  의존하지 않는다. 같은 차수의 활성/완료 state 덮어쓰기는 계속 거절한다.
- 신청만 할 때는 구세대 state를 삭제하지 않는다. 가입 확정 시에만 신규 차수 state로 대체한다.
  과거 room/member/event와 무관한 원정대·그룹 관계는 그대로 둔다.
- 구세대 weekly claim은 이용 제한 근거에서 제외하되 이력 문서를 삭제하지 않는다. 손상 차수와
  동일 차수의 claim은 허용으로 해석하지 않는다. 수동 완료의 필드 허용/권한 연결도 함께 확인한다.
- 완료 조건: active/completed/legacy 대체 성공, 동일·미래·손상 차수 거절, 승인 경쟁·부분 쓰기 원자 거절,
  과거 room/event 보존을 demo에서 먼저 확인한 뒤 실제 점유 조회 및 요청/Write Plan에 연결한다.
  소유권 조회 실패만으로 state를 없다고 처리하지 않는다. 운영 파일 이식·실기기는 전체 연결 후다.

#### 22.3 H3 구세대 점유 서버 proof 결과 (2026-10-02)

7165fec / CI 36886677940의 13건 통과 후, 필수 쓰기 누락 4건을 추가한 072df61 /
CI 36965088067은 17/17 통과했다. 후보 SHA256:
`1e492574901ec7a0ffe44a687de655e82c34286d178d7203a933a8c8cd044ae9`.

- 현재 계정/Character 차수 3 아래의 active/completed/legacy 0 state 대체를 확인했다.
  기존 room/event/weekly claim은 보존한다. 신규 state revision은 기존 생성 계약대로 1이며
  ownershipRevision과 함께 새 참가를 구분한다. 원정대 인증 자체를 이 proof에서 재실행한 것은 아니다.
- 신청 시 구세대 state를 보존하고 승인 시 원자 대체한다. 승인자의 private state get은 거절된다.
- 같은 차수/미래/null/음수/비정수 state, 동일/null 차수 claim은 신규 이용으로 덮어쓰지 못한다.
- room/member/state/event 각 누락 거래, 기존 room/event를 재사용하는 state 단독 대체는 원자 거절된다.
  같은 구세대 state를 대상으로 경쟁하는 두 신규 모집은 하나만 저장된다.
- 서버 신규 대체 경로는 기존 참가 생성 validator, 최신 소유권과 차수, 새 이벤트 및 room revision 증가를
  함께 요구한다. 운영 firestore.rules는 무변경이며 demo 후보에만 반영했다.

잔여: 신청 이후 소유권 변경/점유 변경과 승인 경쟁 결합, 직접 가입 및 Character 변경의 구세대 대체,
수동 완료, H3 후보와 기존 lifecycle/정리 전체 결합 회귀는 별도 검증 대상이다.
다음 앱 연결은 공통 inspector와 별도 create 점유 판정을 같은 소유권 정책에 맞춘다.
조회 실패/손상은 unknown으로 거절하고 구세대 데이터는 선삭제하지 않는다. weekly claim 읽기도
같은 판정을 사용한다. 후보 목록·수동 완료·반복방 정리 UI·운영 이식까지 완료로 확대하지 않는다.

#### 22.4 H3 생성·신청·가입 앱 연결 (2026-10-02)

실제 app_router.dart가 주입하는 Atomic Create/Application/Join Repository에 연결했다.
PartyOwnershipRecordPolicy는 권위 소유권 current, 정확한 Player/Character/raid 식별자와 차수를
확인한다. state는 유효한 주차/상태/문서 revision도 요구한다. claim은 요청 주차 일치가 필요하다.
손상/미래 차수와 권위 불명은 unknown이며 정리나 이용 허용의 근거가 아니다.

- Create는 구세대 state를 판정 입력에서 제외하고 기존 원자 Write Plan의 set으로 대체한다.
  구세대 state가 가리킨 과거 방을 선조회/선삭제하지 않는다. 같은 모집 ID 재사용은 충돌로 거절한다.
- Application 및 본인 Join은 기존 inspector에 동일 transaction에서 읽은 소유권을 전달한다.
  구세대 state는 삭제 없이 보존하며 최종 가입 set에서만 교체된다. 자기 weekly claim도 판정한다.
- Approver는 신청자 state/claim을 조회하지 않는다. 기존 신청 차수 대조 및 서버 최종 판정 유지.
- 현재 차수의 기존 주차/고아 판정은 기존 정책을 사용한다. Character 변경은 이번 선택 인자를
  전달하지 않아 기존 동작을 유지하며 별도 서버 경계 검증 뒤 연결한다.

정책 테스트 신규 3건+기존 소유권 4건 통과, 변경 파일 6개 analyze 무결함, diff check 통과.
이는 Domain 경계 및 실제 연결 코드 검증이며 Repository 거래의 모든 조합이나 실기기 통과가 아니다.
다음은 직접 가입/승인 경쟁과 Character 변경 대체 서버 경계, 후보 목록·개인 완료 및 lifecycle 연결이다.
운영 Rules는 이전 상태이므로 현재 중간 앱 빌드로 기능을 검증하거나 배포하지 않는다.

H3 추가 경계 CI 36965944125는 직접 가입/점유 변경 거절 등 20건 통과, 최대 8인 Character 변경 1건 실패다.
변경 validator에 남은 차수 미구분 weekly completion 검사와 1,000식 초과가 확인됐다.
해당 claim 검사를 동일 차수 정책으로 정렬한 뒤 평가 비용을 재확인한다. 소유권 변경 거절 사례도
클라이언트 사전 거절 대신 같은 owner 재취득 차수 3→5를 사용해 실제 서버 거절을 검증한다.

#### 22.5 H3 직접 가입·승인 시점 변경·8인 Character 변경 proof

063132c / CI 36966140325에서 21/21 통과. 후보 SHA256 `62167b732ce1d2f7d5a8c4d37938734241f59a54456b0b2a9172751429fb0a52`.
직접 가입의 과거 state 대체, 신청 후 차수 3→5 재취득 또는 현재 차수 state 등장 시 승인 거래의
원자 거절, 마지막 슬롯 요청자를 둔 최대 8인 Character 변경의 구세대 completed state 대체를 확인했다.
Character 변경은 과거 room/event/claim 보존과 새 state 하나만 남는 결과를 검증했다.

최초 880195a의 Character 변경 실패에서는 조건 거절 뒤 fallback 평가가 1,000식에 도달했다.
기존 validAtomicMemberCharacterChange의 weekly completion 검사를 deBlockingClaim으로 정렬하자
정상 요청이 통과했다. 추가 권한 완화·별도 비용 우회는 하지 않았다. 최초 소유권 변경 사례의
클라이언트 사전 거절 PASS는 서버 근거에서 제외하고 최종 실행의 재취득 서버 거절로 대체한다.

이 proof는 최대 8인 공개방의 제자리/동일 역할 Character 변경이다. 그룹 listing 결합·다른 파티 이동·
교환 전체 조합이나 실제 앱/실기기 결과로 확대하지 않는다. 앞선 17건도 후보 변경 영향 확인을 위해
같은 실행에서 재검증했다. 실제 동시 승인-인증의 모든 실행 순서를 전수 검증한 것은 아니다.
다음은 Character 변경 inspector에 최신 소유권을 전달하고 후보 목록·수동 완료의 읽기/쓰기와 연결한다.
현재 참가 자체가 구세대일 때 변경으로 부활하지 않는 경계도 해당 연결 전에 조사한다.

§22.6 현재 참가 부활 방지: 조사 결과 변경 전 member의 차수를 현재 소유권과 대조하지 않았다.
새 Character 검증만으로는 과거 참가를 변경으로 부활시킬 수 있으므로 기존 member도 current여야 한다.
기존 슬롯/멤버 차수 1, 현재 소유권 3인 최대 8인 사례를 거절하고 정상 8인 변경 보존을 demo에서 검증한다.
통과 후 실제 변경 Repository도 이전 Character/계정/member/state를 대조하며 후보 조회는 공통 정책과 맞춘다.

#### 22.6 결과 및 후보 목록 연결 설계 (2026-10-02)

최종 6146fef / CI 36966679938 22/22 통과. 후보 SHA256 `662309a35a5f259a7ce0f06f242b7c4b754025913560c141975c54513ff3e4d8`.
이전 member가 current인지 검사하는 공통 member update guard로 legacy fallback도 보호한다.
정상 최대 8인 변경과 이전 member/slot/state가 구세대인 변경의 원자 거절을 확인했다.
실제 MemberMutation Repository는 이전 Character/계정/member/state를 transaction 안에서 확인한다.
새 Character inspector에 이미 검증한 소유권을 전달해 구세대 점유 대체를 연결했다.
변경 Repository analyze 무결함, diff check 통과. 기존 정책 테스트 7건은 정책 무변경으로 재사용한다.

후보 목록 조사: app_router가 사용하는 Application/Leader 후보 서비스는 WeeklyRaidStatusRepository의
첫 결과와 FirestoreActiveRaidAssignmentLookup를 함께 사용한다. completed projection이 있으면
단건 lookup을 호출하기 전에 완료 사유가 결정된다. lookup만 바꾸면 해결되지 않는다.
WeeklyRaidStatusProjector의 입력은 raidStates/weeklyRaidClaims/activeRaidAssignments 세 종류이며
현재 record/projection에는 ownershipRevision이 없다. 합친 projection에서 차수를 추측하지 않는다.

다음 단일 구간은 후보/주간 현황 공통 읽기다.
1. 원본 문서의 경로·식별자·차수 검증과 현재 Character/계정 대조를 projection 이전에 수행한다.
   같은 owner의 과거 차수는 제외, 현재 차수는 유지, 손상/조회 실패는 오류로 전파한다.
   다른 owner의 확정된 과거 관계와 unknown을 구분하며 소유권 차수만으로 unrelated record를 숨기지 않는다.
2. 같은 Character/계정의 중복 조회를 한 평가 안에서 공유하되 무기한 캐시하지 않는다.
   소유권 변경 시 갱신, 빠르게 연속 도착한 snapshot 순서 역전, cancel 후 emit을 설계한다.
3. assignmentLookup도 같은 판정으로 맞춘다. 현재 정상 상태의 완료/진행 중/고아 표시는 보존한다.
4. 단순 정상 UI 반복 검증 대신 과거/현재 혼합·손상·A→B→A 및 비동기 갱신 순서 경계를 검증한다.

후보 목록·수동 완료·lifecycle/정리 UI·전체 회귀·운영 Rules 이식·실기기는 여전히 미완료다.
이번 구간에 공통 주간 현황 스트림을 부분 변경하지 않았다. 전용 브랜치 고정과 운영 배포 제외 유지.
