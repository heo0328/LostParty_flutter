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
