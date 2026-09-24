# 신뢰 서버 파티 참가 명령 설계

## 1. 결정 배경과 적용 범위

BUG-022 그룹 전용방 탈퇴 후 재가입은 현재 클라이언트 Firestore Transaction의
원자성·권한 조건을 유지한 여러 Rules 비용 축소에서도 1,000식 한도를 넘었다.
listing·event 쓰기 수, OR 순서, 그룹 membership 조회와 membership·raidState target
중복 검증을 각각 줄여도 정상 재가입이 통과하지 않았으므로 같은 미세 최적화를 반복하지
않는다.

이 문서는 신뢰 서버가 파티 참가를 검증하고 Admin SDK Transaction으로 확정하는 경우의
최소 계약을 정의한다. 아직 구현·결제 플랜 변경·Functions 배포를 승인한 문서가 아니다.

포함 범위:

- 공개·그룹 전용방의 즉시 가입과 탈퇴 후 재가입
- 기존 신청을 승인해 확정 참가시키는 공통 서버 내부 처리
- 모집 Aggregate, membership, `raidState`, application, 그룹 listing과 공용 이벤트의
  단일 Transaction
- 인증, 동시성, 멱등성, 앱 전환, Rules 차단, 배포와 롤백 순서

제외 범위:

- 파티 생성·탈퇴·추방·해산·자리/Character 변경의 서버 이전
- 운영자 명령, 원정대 소유권 이전, 기존 고아 데이터 자동 정리
- 결제 계정 연결, Blaze 전환과 운영 배포의 자동 실행

## 2. 선행 결정 게이트

현재 프로젝트는 Spark 무료 범위를 전제로 하며 Functions 구성이 없다. Cloud Functions
배포에는 Blaze 요금제와 Cloud Billing 연결이 필요하다. 무료 사용량이 있더라도 호출,
컴퓨팅, 네트워크, 빌드와 Artifact Registry가 사용량 또는 저장량에 따라 과금될 수 있다.

따라서 다음 항목을 사용자가 명시적으로 승인하기 전에는 구현 브랜치를 만들거나
Functions 초기화·배포를 하지 않는다.

1. Firebase 프로젝트 `lost-party`의 Blaze 전환과 결제 계정 연결
2. 리전과 런타임, 월간 예산 알림·Cloud Run Functions 지출 상한
3. 서버 참가 명령을 먼저 적용할 범위: 직접 가입만 또는 신청 승인 포함
4. 서버 배포·앱 배포·구 클라이언트 차단의 운영 순서

Spark를 유지하는 경우 클라이언트가 작성한 command/proof 문서는 신뢰 증명이 아니며,
Rules가 같은 권한·소유권·상태 결합을 다시 검증해야 한다. 현재 한도를 피하려고 원자
쓰기를 나누는 방식도 부분 성공을 만들므로 대안으로 채택하지 않는다.

## 3. 외부 Callable 계약

서버 API는 직접 가입과 승인을 별도 entry point로 노출하되 내부의 하나의 참가 명령을
공유한다.

```text
joinPartyDirectly
  commandId: string
  recruitmentId: string
  characterId: string
  partyIndex: int
  slotIndex: int
  expectedRevision: int

approvePartyApplication
  commandId: string
  recruitmentId: string
  applicantPlayerId: string
  expectedApplicationRevision: int
  expectedRecruitmentRevision: int
```

클라이언트는 `playerId`, 역할별 인원수, 그룹원 여부, Character 소유자, listing Snapshot,
이벤트 audience와 서버 시각을 보내지 않는다. `commandId`는 재시도에도 유지하는 UUID이며
요청 본문과 actor가 달라지면 같은 ID 재사용을 거절한다.

성공 응답은 `commandId`, `recruitmentId`, 확정 `playerId`, 새 모집 revision과
`alreadyApplied`를 반환한다. 제품 오류는 인증 없음, 권한 없음, revision 충돌, 만석,
구성 불가, 그룹 자격 없음, Character 소유권/상태 오류, 주간 완료, 기존 점유와 신청 상태
충돌로 구분한다. 내부 경로·AuthUid와 다른 Player의 민감 자료는 반환하지 않는다.

## 4. 인증과 서버 검증

Callable은 Firebase Auth 토큰이 없으면 즉시 거절한다. 서버는 토큰 uid로
`authBindings/{uid}`를 읽어 active `playerId`를 결정하고 `players/{playerId}` active를
검증한다. 요청의 Player 식별자는 신뢰하지 않는다.

Transaction은 최소한 다음을 서버에서 다시 읽고 검증한다.

1. auth binding과 actor Player
2. 모집 원본과 `expectedRevision`, active 회차·정원·승인 방식
3. 대상 Character의 active 상태와 `ownerPlayerId`
4. 대상 membership 부재와 결정된 빈 slot·역할/동일 직업 구성
5. 동일 `characterId + raidId`의 active `raidState` 및 현재 주차 완료 부재
6. 그룹 전용방이면 현재 `groups/{groupId}/members/{playerId}` 존재와 block 정책
7. 승인 명령이면 승인자의 현재 승인 권한과 pending application의 revision·Snapshot
8. 그룹 원본과 listing이 필요한 경우 현재 revision·집계

서버는 현재 Domain/Write Plan과 같은 구성 정책을 공유하거나 서버용 순수 정책 모듈로
이식한다. 클라이언트가 계산한 count, slot, role, target 배열과 listing Map을 그대로
저장하지 않는다.

## 5. 원자 쓰기와 멱등성

한 Admin SDK Transaction에서 다음을 함께 확정한다.

- 모집 Aggregate의 멤버·slot·target·집계·revision
- `recruitments/{id}/members/{playerId}`
- `players/{playerId}/raidStates/{characterId}_{raidId}`
- 승인인 경우 application의 approved 전이와 pending 집계 감소
- 그룹 전용방이면 원본과 같은 revision의 `raidListings/{recruitmentId}`
- 결정적 ID의 `partyEvents/memberJoined_{recruitmentId}_{revision}`
- `partyCommands/{commandId}`의 actor, 요청 해시, 상태, 결과 revision

`partyCommands/{commandId}`가 같은 actor·요청 해시로 이미 complete면 문서를 다시 쓰지
않고 같은 성공 결과를 반환한다. processing 상태를 클라이언트 후속 실행에 맡기지 않는다.
Transaction 커밋 후 응답이 유실돼도 같은 `commandId` 재호출은 `alreadyApplied` 성공으로
수렴한다. revision 또는 점유 경쟁에서 진 요청은 부분 문서 없이 전체 실패한다.

## 6. 앱과 Rules 전환

Flutter에는 `firebase_functions` 의존성과 서버용 `PartyJoinCommandRepository` 구현을
추가한다. UI와 Domain result 계약은 유지하고 Router/DI만 서버 Repository로 전환한다.
Emulator와 테스트에서는 interface fake 또는 Functions Emulator를 사용한다.

전환 순서는 다음과 같다.

1. Functions와 Emulator 계약 테스트를 비연결 상태로 구현한다.
2. demo 프로젝트에서 인증·정상 가입·위조·동시성·멱등성 회귀를 통과한다.
3. 운영 Functions를 먼저 배포하되 기존 앱은 계속 기존 Repository를 사용한다.
4. 서버 Repository를 사용하는 앱을 배포하고 대표 공개/그룹 가입·승인을 확인한다.
5. 지원 최소 앱 버전과 전환 상태를 확정한 뒤에만 직접 클라이언트 가입 쓰기를 Rules에서
   닫는다. 탈퇴·추방 등 아직 클라이언트에 남은 다른 명령은 함께 닫지 않는다.

롤백은 앱 Router를 기존 Repository로 되돌리는 것이 아니라 서버 함수의 직전 검증본으로
되돌리는 것을 우선한다. 구 클라이언트 Rules를 이미 닫았다면 서버 장애 중 가입 기능은
명시적으로 일시 중단하고 보안 조건을 완화하지 않는다.

## 7. 자동·실기기 검증

자동 검증:

- 인증 없음, inactive binding/Player, 타인 Character, 그룹원 아님, block, 만석
- stale revision, 중복 membership, 기존 active/completed state·주간 Claim
- 직접 가입과 승인 각각의 정상 공개/그룹방 참가
- 동일 `commandId` 재호출, 다른 payload로 ID 재사용, 동시 두 가입/승인 경쟁
- 모집·membership·state·application·listing·event·command 결과의 전부 성공/전부 실패
- 기존 클라이언트 생성·탈퇴·추방·해산과 읽기 흐름 회귀

실기기 검증은 사용자가 수행한다. 대표 흐름은 그룹방 `탈퇴 → 같은 Character 재가입`,
추방 후 재가입, 공개방 가입, 신청 승인, 응답 유실을 가정한 재시도와 앱 재진입이다.

## 8. 완료 조건

- 결제·리전·예산 보호와 서버 전환 범위가 명시 승인된다.
- 서버가 모든 권위 값을 다시 계산하며 Admin 비밀값이 앱에 포함되지 않는다.
- 원자성·권한·주간 완료·그룹 접근·target 결합과 멱등성 테스트가 통과한다.
- 운영 Functions와 앱 전환 후 사용자가 대표 실기기 흐름을 확인한다.
- 구 클라이언트 차단은 서버·앱 안정화 이후 별도 Rules 배포로 수행한다.

## 9. 공식 운영 근거

- [Cloud Functions 시작 및 Blaze 배포 조건](https://firebase.google.com/docs/functions/get-started)
- [Cloud Functions 할당량·Blaze 및 비용 보호 안내](https://firebase.google.com/docs/functions/quotas)
- [Firebase 요금제와 Cloud Functions 무료 사용량](https://firebase.google.com/pricing)
