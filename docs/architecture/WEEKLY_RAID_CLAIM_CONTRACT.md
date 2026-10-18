# 캐릭터 주간 레이드 귀속 계약

> 기존 서비스 전용 항목은 [원문·출처 기록](../../legacy/firebase/extracted/docs/architecture/WEEKLY_RAID_CLAIM_CONTRACT.md)으로 분리했다. 남은 제품/협업 문맥의 신규 서버 적용 여부는 별도 설계에서 판단한다.

> 2026-09-14 확장성 재설계 결정: 이 문서의 제품 정책은 유지하지만 신규 저장 계약은 별도 `activeRaidAssignments`와 `weeklyRaidClaims` 대신 통합 `raidState`를 사용한다. 상세 전환과 8인 원자 명령은 [`PARTY_GROUP_COMMAND_SCALABILITY_REDESIGN.md`](../../legacy/firebase/docs/architecture/PARTY_GROUP_COMMAND_SCALABILITY_REDESIGN.md)가 우선한다.

## 0. 현재 C* 저장 계약 (2026-09-18)

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/architecture/WEEKLY_RAID_CLAIM_CONTRACT.md#source-0001)로 이동했다.

## 1. 목적

이 문서는 LOSTPARTY에서 다음 세 상태를 분리하고 다시 연결하는 단일 기준이다.

1. 파티방의 현재 진행 상태
2. 캐릭터가 현재 참가 중인 파티 점유
3. 캐릭터가 이번 주 해당 레이드를 실제 완료했는지 나타내는 개인 주간 완료 귀속

기존 구현은 파티 회차 완료 이벤트와 로컬 완료 기록은 갖고 있지만, 개인 주간 완료를 서버에서 모집 제한의 최종 기준으로 강제하지 않는다. `activeRaidAssignments`가 파티 참가 충돌과 완료 후 재참가 제한을 일부 대신하면서, 파티 완료·해산·개인 정정이 서로 어긋날 수 있다.

이 계약은 개인 주간 완료 Claim을 서버 단일 기준으로 추가하고, 레이드 상세의 완료 버튼과 내 계정의 체크박스가 같은 Claim을 조작하도록 확정한다.

## 2. 핵심 용어

- **파티 회차 상태**: 모집방의 공동 진행 상태. 신규 흐름은 `active`, `completed`, `disbanded`를 사용한다. 과거 `completionCancelled`는 읽기 호환 이력으로만 취급한다.
- **활성 파티 점유**: 캐릭터가 현재 동일 레이드의 다른 활성 파티에 중복 참가하지 못하게 하는 임시 점유다.
- **주간 완료 Claim**: 한 Player가 소유한 한 Character가 한 주차의 한 `raidId`를 실제 완료했다고 선언하는 서버 기록이다.
- **개인 완료**: 일반 파티원이 레이드 상세에서 자기 참가 캐릭터만 완료 처리하거나, 내 계정에서 직접 완료 체크하는 동작이다.
- **파티 전체 완료**: 파티장 또는 공대장이 현재 회차와 완료 당시 전 파티원의 Claim을 함께 완료 처리하는 동작이다.

## 3. 최종 불변식

### 3.1 개인 완료의 단일 기준

```text
주간 완료 Claim 있음
= 내 계정 체크박스 체크
= 동일 Character·raidId·cycleKey 모집 생성·신청·가입 제한

주간 완료 Claim 없음
= 내 계정 체크박스 해제
= 다른 충돌이 없다면 모집 생성·신청·가입 가능
```

Drift와 UI 체크 상태는 서버 Claim의 Projection이며 최종 권한 근거가 아니다.

### 3.2 완료와 활성 참가의 상호 배제

```text
같은 Player·Character·raidId·cycleKey에
주간 완료 Claim과 activeRaidAssignment가 동시에 존재할 수 없다.
```

Claim을 생성하는 명령은 기존 확정 참가와 pending 신청을 함께 정리한다. 모집 생성·신청·즉시 가입·승인·참가 캐릭터 변경은 Claim이 있으면 서버에서 거절한다.

### 3.3 난이도 관계

- 완료 키는 `playerId + characterId + raidId + cycleKey`다.
- `difficultyId`는 실제 완료 이력의 부가 정보다.
- 같은 `raidId`의 노말·하드·나이트메어는 별도 주간 Claim으로 중복 생성하지 않는다.

### 3.4 상태 소유권

- 파티 회차 상태는 모집 Current State와 cycle Snapshot이 소유한다.
- 활성 파티 점유는 `activeRaidAssignments`가 소유한다.
- 개인 주간 완료는 `weeklyRaidClaims`가 소유한다.
- 파티 완료 이벤트와 알림은 발생 사실의 이력이며 Claim 자체가 아니다.
- 사용자는 자기 Claim만 수동 생성·삭제할 수 있다.
- 파티장·공대장은 파티 전체 완료 Transaction 안에서만 완료 당시 멤버의 Claim을 생성할 수 있다.

## 4. Firestore 권장 모델

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/architecture/WEEKLY_RAID_CLAIM_CONTRACT.md#source-0002)로 이동했다.

## 5. 사용자 완료 경로

### 5.0 현재 구현 기준 — Task-078 완료

2026-08-27 `main`의 구현 범위는 다음과 같다.

- 내 계정 체크박스가 개인 주간 완료 Claim의 생성·삭제 UI다.
- 체크 전에 동일 `playerId + characterId + raidId + cycleKey`의 활성 점유와 승인 대기 신청 영향을 조회한다.
- 영향이 있으면 파티명, 탈퇴 여부, 책임자 승계 대상 또는 단독 해산, 종료할 신청 건수를 먼저 보여주고 사용자의 명시적 확인을 받는다.

```text
membership 제거
+ activeRaidAssignment 제거
+ 모집 memberCount/dealerCount/supportCount/hasAvailableSlot/revision 갱신
+ 필요 시 leaderPlayerId와 책임자 표시 Snapshot 승계
+ 단독 책임자라면 모집 해산
+ 동일 캐릭터·동일 레이드·동일 주차 pending 신청 종료
+ 본인 weeklyRaidClaim 생성
+ 남은 파티원에게 완료 사유 memberLeft 이벤트 생성
```

- 일반 멤버가 탈퇴할 때 기존 책임자의 `leaderCharacterNameSnapshot`과 `leaderClassNameSnapshot`은 그대로 보존한다.
- 책임자가 탈퇴하면 `memberPlayerIds`의 다음 멤버와 그 membership Snapshot으로 책임자를 승계한다.
- 같은 캐릭터라도 다른 `raidId`의 신청은 종료하지 않는다.
- 확인창에서 취소하면 위 문서 중 어느 것도 변경하지 않는다.
- Claim을 해제해도 이전 membership과 신청은 복구하지 않는다.
- 완료 탈퇴 전에 `approved`였던 application은 이력 문서로 남는다. Claim 해제 후 같은 방에 다시 신청할 때 현재 membership이 없다면 그 문서를 새 `revision`의 `pending`으로 재사용한다.

아직 구현하지 않은 범위:

- 레이드 상세의 일반 멤버 `내 캐릭터 완료` 버튼
- 기존 completed 방의 assignment 정리 및 데이터 이행

Task-079 E 당시 책임자 `파티 전체 완료`·반복 파티 제한적 전체 완료 취소·`partyOwner` Claim·assignment 정리까지 연결됐다. 이후 2026-09-19 결정으로 전체 완료 취소는 폐기 대상이 됐다. 아래 5.1의 전체 완료 UX는 유지하고 5.2는 별도 연결 단위다.

### 5.1 파티장·공대장 — 파티 전체 완료

레이드 상세에서 `파티 전체 완료`를 실행한다.

결과:

1. 파티 회차를 `completed`로 변경한다.
2. 완료 당시 membership Snapshot을 고정한다.
3. Snapshot 전원의 개인 주간 완료 Claim을 생성한다.
4. Snapshot 전원의 `activeRaidAssignment`를 삭제한다.
5. 완료 이벤트와 알림을 생성한다.
6. 전원의 내 계정 체크박스가 서버 동기화 후 체크된다.

일반 파티원은 파티 전체 완료 명령을 실행할 수 없다.

### 5.2 일반 파티원 — 내 캐릭터 완료

레이드 상세에서 `내 캐릭터 완료`를 실행한다.

결과:

1. 본인의 membership을 제거한다.
2. 본인의 `activeRaidAssignment`를 삭제한다.
3. 파티 인원·역할 수·빈 슬롯·revision을 갱신한다.
4. 같은 캐릭터·레이드·주차의 pending 신청을 종료한다.
5. 본인의 주간 완료 Claim을 생성한다.
6. 남은 파티원에게 `weeklyRaidCompleted` 사유의 탈퇴 이벤트를 생성한다.
7. 파티 회차는 계속 `active`다.

이 UX의 레이드 상세 버튼 연결은 후속 작업이다. Task-078에서는 같은 상태 전이를 내 계정 체크박스에서 실행하는 경로를 먼저 구현했다.

### 5.3 내 계정 — 수동 완료

LOSTPARTY 밖에서 레이드를 완료했거나 사용자가 직접 기록하려는 경우 캐릭터별 체크박스를 선택한다.

- 활성 파티와 pending 신청이 없으면 Claim만 생성한다.
- 동일 캐릭터·레이드의 활성 파티가 있으면 즉시 처리하지 않고 영향을 안내한다.
- 사용자가 `탈퇴하고 완료 처리`를 확인하면 개인 완료와 같은 Transaction을 실행한다.
- pending 신청만 있으면 철회 대상 수를 안내하고 확인 후 함께 종료한다.

### 5.4 파티장·공대장의 개인 완료

파티장·공대장은 레이드 상세의 완료 동작이 항상 `파티 전체 완료`다. 자기만 완료하려면 내 계정 체크박스를 사용한다.

내 계정에서 개인 완료할 때:

- 남은 멤버가 있으면 다음 책임자를 결정해 권한을 승계한 뒤 탈퇴·Claim 생성을 처리한다.
- 혼자라면 파티를 해산하고 Claim을 생성한다.
- 확인창에 승계 대상 또는 해산 결과를 명시한다.

## 6. 내 계정 체크박스

### 표시

- 캐릭터별 주간 레이드 목록에 체크박스를 제공한다.
- 서버 Claim을 구독 또는 동기화해 체크 상태를 표시한다.
- 오프라인 캐시는 사용할 수 있으나 서버 확인 전 명령 가능 여부를 확정하지 않는다.
- 파티 완료로 생성된 Claim과 수동 Claim은 같은 체크박스로 표시한다.

### 체크

```text
체크박스 선택
→ 서버 Claim·활성 점유·pending 신청 확인
→ 영향이 없으면 Claim 생성
→ 영향이 있으면 확인창
→ 확인 시 탈퇴/신청 종료/Claim 생성을 원자적으로 실행
```

확인 문구 기본안:

> 현재 `{캐릭터명}` 캐릭터로 `{파티명}`에 참가 중입니다. 이 레이드를 완료 처리하면 해당 파티에서 탈퇴하고, 같은 주차에는 동일 레이드 모집에 참가할 수 없습니다.

버튼:

- `취소`
- `탈퇴하고 완료 처리`

### 체크 해제

```text
체크박스 해제
→ 본인의 Claim 삭제
→ 남은 active 참가 근거가 없으면 동일 레이드 모집 생성·신청·가입 다시 허용
```

- 파티 공동 완료 Snapshot은 변경하지 않는다.
- 다른 파티원의 Claim을 변경하지 않는다.
- 이전 파티에 자동 재가입하지 않는다.
- 해산된 파티를 복구하지 않는다.
- 체크 해제 뒤 active 참가 근거가 남지 않으면 즉시 새 파티에 들어갈 수 있으므로 사용자의 명시적 확인을 받는다. active 참가 근거가 함께 남아 있으면 참가 상태를 유지하고 새 파티 진입은 계속 막는다.

## 7. 활성 파티와 pending 신청 처리

### 확정 참가 중 완료 체크

완료 Claim 생성 전에 현재 `activeRaidAssignment`와 membership을 확인한다.

- 일반 파티원: 탈퇴 후 Claim 생성
- 책임자: 승계 또는 단독 해산 후 Claim 생성
- 8인 풀방에서 한 명이 완료하면 기존 슬롯은 빈자리로 유지하며 다른 멤버를 당기지 않는다.
- 모집은 빈자리와 수동 모집 설정을 기준으로 다시 노출할 수 있다.

### pending 신청

- 같은 Character·raidId·cycleKey의 pending 신청은 Claim 생성과 함께 `superseded` 또는 완료 전용 종료 사유로 전환한다.
- 완료 Claim이 생긴 뒤 기존 pending이 승인될 수 없어야 한다.
- 승인 Transaction도 신청자 Claim을 다시 확인한다.
- 완료로 종료된 신청은 `status: superseded`, `resolutionReason: weeklyRaidCompleted`로 기록한다.
- 과거 `approved` application은 membership과 동일하지 않다. 현재 `memberPlayerIds`에 없으면 Claim 해제 후 같은 문서를 `pending`으로 갱신해 재신청할 수 있다.

### 이벤트

개인 완료로 파티에서 빠진 경우 남은 멤버에게 일반 탈퇴와 구분되는 이벤트를 보낸다.

```text
type: memberLeft
reason: weeklyRaidCompleted
```

UI 문구 기본안:

> `{캐릭터명}님이 레이드 완료 처리로 파티에서 탈퇴했습니다.`

## 8. 명령별 Claim 강제 검증

다음 명령은 대상 Character의 현재 `raidId + cycleKey` Claim이 없어야 한다.

| 명령 | 검증 시점 | 실패 결과 |
| --- | --- | --- |
| 모집 생성 | 생성 Transaction | `weeklyRaidAlreadyCompleted` |
| 가입 신청 | application 생성/재신청 Transaction | `weeklyRaidAlreadyCompleted` |
| 즉시 가입 | membership 생성 Transaction | `weeklyRaidAlreadyCompleted` |
| 신청 승인 | 승인 Transaction에서 재검증 | `weeklyRaidAlreadyCompleted` |
| 참가 캐릭터 변경 | 새 Character 점유 전 | `weeklyRaidAlreadyCompleted` |


## 9. 원자적 Transaction

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/architecture/WEEKLY_RAID_CLAIM_CONTRACT.md#source-0005)로 이동했다.

## 10. 파티 완료 확정과 해산

### 파티 전체 완료 취소 폐기

- 2026-09-19 제품 결정으로 반복방을 포함한 파티 전체 완료 취소 기능을 제공하지 않는다.
- 파티 전체 완료는 이번 주차의 확정 기록이며 방 전체를 이전 참가 상태로 복원하지 않는다.
- 잘못된 완료 표시는 각 사용자가 내 계정에서 자기 체크만 해제해 정정한다. 이 동작은 다른 파티원의 완료, 공동 Snapshot, membership 또는 과거 방을 변경하지 않는다.
- `다음 주도 함께하기` 방은 완료 당시 구성을 보존하고 수요일 06시 새 주차 전환에서 새 `active` 상태를 구성한다. 현재 주차를 되돌렸다가 다시 완료하는 중간 상태를 만들지 않는다.

### 해산

- 해산은 membership과 active assignment를 제거한다.
- 해산은 개인 주간 완료 Claim을 삭제하지 않는다.
- 해산된 파티는 복구하지 않는다.
- 사용자는 체크박스 해제로 자기 Claim만 제거할 수 있다.
- 같은 조건 재사용이 필요하면 새 `recruitmentId`로 모집을 만든다.

## 11. Security Rules

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/architecture/WEEKLY_RAID_CLAIM_CONTRACT.md#source-0007)로 이동했다.

## 12. 현재 구현과 남은 간격

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/architecture/WEEKLY_RAID_CLAIM_CONTRACT.md#source-0008)로 이동했다.

## 13. 구현 작업 분해

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/architecture/WEEKLY_RAID_CLAIM_CONTRACT.md#source-0009)로 이동했다.

## 내 계정 i 표시 — 참가 관계 기준 (2026-10-17 사용자 재확인)

체크는 해당 주차 완료 여부, i는 캐릭터가 현재 참가하고 있는 모집방 관계를 나타낸다. 미완료 대기/진행, 이번 주 완료 후 해산 전, 다음 주도 함께하기로 유지 중인 방에는 완료 체크와 독립적으로 i를 표시한다. 해산/탈퇴로 관계가 종료되면 과거 파티 완료 근거가 남아 있어도 i를 표시하지 않는다. 통신 중/수동 완료/파티 완료 source만으로 i를 추가하지 않는다. 현재 참가 관계와 주간 점유/완료 snapshot은 별도 데이터이며 과거 기록으로 현재 관계를 추정하지 않는다.

## 14. UX 요약

| 위치 | 사용자 | 동작 | 결과 |
| --- | --- | --- | --- |
| 레이드 상세 | 파티장·공대장 | `파티 전체 완료` | 회차 완료 + 완료 당시 전원 Claim |
| 레이드 상세 | 일반 파티원 | `내 캐릭터 완료` | 본인 탈퇴 + 본인 Claim, 회차 active 유지 |
| 내 계정 | 본인 | 체크박스 선택 | 필요 시 탈퇴·신청 종료 후 본인 Claim |
| 내 계정 | 본인 | 체크박스 해제 | 본인 Claim 삭제, 이전 파티 자동 복귀 없음 |

## 15. 구현 전 추가 확인 항목

1. 내 계정에서 캐릭터별로 표시할 기본 레이드 개수와 정렬은 기존 0~5개·기본 3개 정책을 유지한다. Task-081에서 캐릭터별 선택·원정대 일괄 개수·로컬 Drift 저장을 구현했다. 접기 UI는 쓰지 않으며 선택 개수만큼 항상 표시한다. 기본 표시 순서는 입장 레벨 내림차순이다.
2. 파티장·공대장 구분이 현재 `leaderPlayerId` 하나뿐인 구조에서 동일 명령으로 충분한지
3. Claim 문서 ID escape/hash 규칙
5. ~~기존 수동 로컬 `WeeklyRaidClear` 데이터를 서버로 이행할지 폐기할지~~ → **폐기(Claim-only)**. Task-080 F
6. ~~기존 completed 방의 active assignment를 언제 안전하게 정리할지~~ → **본인 점유 self-heal**(모집 completed/disbanded 또는 cycle completed, recruitmentId·raidId 일치). Claim으로 변환하지 않음. Task-080 F
7. 개인 완료 후 남은 파티의 모집 자동 노출 조건
8. Claim 체크 해제 확인 문구와 오작동 방지 UX

