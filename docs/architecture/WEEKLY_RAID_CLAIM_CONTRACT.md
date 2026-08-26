# 캐릭터 주간 레이드 귀속 계약

## 1. 목적

이 문서는 LOSTPARTY에서 다음 세 상태를 분리하고 다시 연결하는 단일 기준이다.

1. 파티방의 현재 진행 상태
2. 캐릭터가 현재 참가 중인 파티 점유
3. 캐릭터가 이번 주 해당 레이드를 실제 완료했는지 나타내는 개인 주간 완료 귀속

기존 구현은 파티 회차 완료 이벤트와 로컬 완료 기록은 갖고 있지만, 개인 주간 완료를 서버에서 모집 제한의 최종 기준으로 강제하지 않는다. `activeRaidAssignments`가 파티 참가 충돌과 완료 후 재참가 제한을 일부 대신하면서, 파티 완료·해산·개인 정정이 서로 어긋날 수 있다.

이 계약은 개인 주간 완료 Claim을 서버 단일 기준으로 추가하고, 레이드 상세의 완료 버튼과 내 계정의 체크박스가 같은 Claim을 조작하도록 확정한다.

## 2. 핵심 용어

- **파티 회차 상태**: 모집방의 공동 진행 상태. `active`, `completed`, `completionCancelled`, `disbanded` 등으로 관리한다.
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

```text
players/{playerId}/weeklyRaidClaims/{cycleKey_characterId_raidId}
  schemaVersion: 1
  playerId
  characterId
  raidId
  cycleKey
  difficultyId
  source: manual | partyMember | partyOwner
  sourceRecruitmentId: String?
  sourceCompletionRevision: int?
  cycleStartedAt: timestamp
  cycleEndsAt: timestamp
  completedAt: server timestamp
  updatedAt: server timestamp
```

문서 ID는 `${cycleKey}_${characterId}_${raidId}`다. Firestore Rules가 같은 값을 직접 재구성해 임의 ID와 중복 Claim을 거절할 수 있어야 한다. `cycleKey`는 `YYYY-MM-DD`, 서버 Character ID는 Firestore 자동 ID 형식인 영숫자 20자, `raidId`는 소문자 영숫자와 밑줄만 허용한다. 표시 이름은 식별 키로 사용하지 않는다.

### 기존 Claim과 멱등성

- 같은 키의 Claim이 이미 있으면 완료 처리는 성공으로 간주한다.
- 파티 전체 완료가 기존 수동 Claim을 덮어써서 출처를 잃게 해서는 안 된다.
- 최소 구현은 기존 Claim을 유지하고 없는 Claim만 생성한다.
- 출처 이력이 여러 개 필요해지면 Claim과 별도 이벤트로 보존하며 Claim 문서에 배열을 무제한 누적하지 않는다.

## 5. 사용자 완료 경로

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
→ 동일 레이드 모집 생성·신청·가입 다시 허용
```

- 파티 공동 완료 Snapshot은 변경하지 않는다.
- 다른 파티원의 Claim을 변경하지 않는다.
- 이전 파티에 자동 재가입하지 않는다.
- 해산된 파티를 복구하지 않는다.
- 체크 해제 후 즉시 새 파티에 들어갈 수 있으므로 사용자의 명시적 확인을 받는다.

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

후보 UI의 로컬 사전 필터는 안내용이다. 최종 거절은 Firestore Transaction과 Security Rules가 담당한다.

## 9. 원자적 Transaction

개인 완료로 활성 파티에서 나오는 명령은 최소 다음을 하나의 Transaction으로 처리한다.

```text
membership 제거
+ activeRaidAssignment 삭제
+ pending 신청 종료
+ 모집 memberCount/roleCount/hasAvailableSlot/revision 갱신
+ 필요 시 책임자 승계 또는 단독 해산
+ weeklyRaidClaim 생성
+ Player Event 생성
```

일부만 성공하는 상태는 허용하지 않는다.

파티 전체 완료는 최소 다음을 하나의 Transaction으로 처리한다.

```text
cycle completed Snapshot 생성/갱신
+ 모집 currentCycleStatus/revision 갱신
+ 완료 당시 전원의 weeklyRaidClaim 생성
+ 전원의 activeRaidAssignment 삭제
+ 완료 당시 전원의 Player Event 생성
```

현재 최대 8인에서 Firestore Transaction 쓰기 수와 Security Rules document access 한도를 구현 전에 계산한다. Spark 클라이언트 Transaction으로 안전하게 검증할 수 없으면 구현을 넓히지 않고 서버 선행 여부를 다시 결정한다.

## 10. 파티 완료 취소와 해산

### 완료 취소

파티 완료와 개인 Claim은 분리한다. 공동 완료를 취소하더라도 개인 Claim을 자동 삭제하지 않는다.

- 완료 취소는 파티 회차를 다시 진행 가능한 상태로 복구하는 공동 명령이다.
- 각 사용자의 실제 완료 Claim은 내 계정 체크박스에서만 해제한다.
- 완료 취소 때문에 실제 완료한 사용자의 Claim을 다른 사람이 삭제할 수 없다.

완료 취소 권한과 유지 여부는 Claim 기반 흐름 구현 후 다시 확정한다. 개인 재참가 복구를 위해 공동 완료 취소가 반드시 필요한 것은 아니다.

### 해산

- 해산은 membership과 active assignment를 제거한다.
- 해산은 개인 주간 완료 Claim을 삭제하지 않는다.
- 해산된 파티는 복구하지 않는다.
- 사용자는 체크박스 해제로 자기 Claim만 제거할 수 있다.
- 같은 조건 재사용이 필요하면 새 `recruitmentId`로 모집을 만든다.

## 11. Security Rules

### 자기 수동 완료

- active Auth binding의 Player만 자기 경로의 Claim을 생성·삭제한다.
- Claim의 Character가 현재 Player 소유의 active Character인지 검증한다.
- `cycleKey`와 `raidId` 형식을 검증한다.
- 자유로운 다른 Player Claim 쓰기를 허용하지 않는다.

### 파티 전체 완료

- 호출자가 현재 파티장·공대장인지 검증한다.
- 수신 Player가 완료 Snapshot 멤버인지 검증한다.
- Claim의 Character·raidId·cycleKey가 해당 membership과 cycle에 일치해야 한다.
- 같은 Transaction의 cycle 완료 상태 전이와 서버 시간을 검증한다.

### 개인 완료와 탈퇴

- 호출자와 Claim의 Player가 같아야 한다.
- 같은 Transaction에서 본인의 membership과 assignment가 제거돼야 한다.
- 책임자라면 승계 또는 단독 해산 불변식을 검증한다.
- 모집 count와 `memberPlayerIds`가 함께 갱신돼야 한다.

## 12. 현재 구현과 충돌하는 지점

1. 실행 앱의 `WeeklyRaidClearRepository`는 InMemory 기반이며 Firestore Claim과 연결되지 않았다.
2. Drift `raidHistoryEntries.localStatusOverride`는 표시 정정일 뿐 모집 제한의 서버 근거가 아니다.
3. Firestore 모집 생성·신청·가입·승인·캐릭터 변경은 주간 Claim을 최종 검증하지 않는다.
4. 현재 파티 완료는 일반 멤버도 실행할 수 있으며 Claim을 생성하지 않는다.
5. 현재 파티 완료 후 active assignment가 해산까지 남아 개인 재모집을 막을 수 있다.
6. 내 계정의 캐릭터별 주간 레이드 체크박스가 현재 UI에서 빠져 있다.
7. 기존 완료 이벤트는 개인 Claim과 별도 이력이므로 삭제하거나 Claim으로 직접 재사용하면 안 된다.
8. BUG-005의 같은 주차 재완료 미차단은 Claim 서버 강제 부재와 직접 연결된다.

## 13. 구현 작업 분해

### 단계 A — Claim 계약·Domain·읽기 기반

- Firestore 경로·문서 ID·Domain·Repository 계약
- 현재 Player의 이번 주 Claim 읽기
- 내 계정 체크박스의 읽기 전용 표시
- 기존 Drift 히스토리와 역할 분리 테스트

### 단계 B — 수동 체크·해제

- 활성 참가나 pending이 없는 Character의 Claim create/delete
- 본인 소유·주차·raidId Rules
- 다중 기기 체크 상태 동기화

### 단계 C — 모집 제한 강제

- 생성·신청·즉시 가입·승인·캐릭터 변경 Transaction에서 Claim 재검증
- 후보 UI 안내와 서버 오류 매핑
- BUG-005 회귀 테스트

### 단계 D — 활성 참가 중 개인 완료

- 영향 확인 UI
- 일반 멤버 탈퇴 + pending 종료 + Claim 생성
- 책임자 승계/단독 해산
- 완료 사유 탈퇴 이벤트

### 단계 E — 파티 전체 완료

- 완료 권한을 파티장·공대장으로 제한
- Snapshot 전원의 Claim 멱등 생성
- active assignment 전원 해제
- 체크박스와 완료 이벤트 동기화

### 단계 F — 이행·실기기 검증

- 기존 완료 이벤트·로컬 정정 데이터 표시 정책
- 기존 completed·해산 대기 방과 assignment 정리 정책
- 수동 완료, 개인 완료, 전체 완료, 해제와 재모집을 2기기에서 검증

각 단계는 별도 검토·구현·검증·문서화가 가능한 작업 그룹으로 유지한다.

## 14. UX 요약

| 위치 | 사용자 | 동작 | 결과 |
| --- | --- | --- | --- |
| 레이드 상세 | 파티장·공대장 | `파티 전체 완료` | 회차 완료 + 완료 당시 전원 Claim |
| 레이드 상세 | 일반 파티원 | `내 캐릭터 완료` | 본인 탈퇴 + 본인 Claim, 회차 active 유지 |
| 내 계정 | 본인 | 체크박스 선택 | 필요 시 탈퇴·신청 종료 후 본인 Claim |
| 내 계정 | 본인 | 체크박스 해제 | 본인 Claim 삭제, 이전 파티 자동 복귀 없음 |

## 15. 구현 전 추가 확인 항목

1. 내 계정에서 캐릭터별로 표시할 기본 레이드 개수와 정렬은 기존 0~5개·기본 3개 정책을 유지할지
2. 파티장·공대장 구분이 현재 `leaderPlayerId` 하나뿐인 구조에서 동일 명령으로 충분한지
3. Claim 문서 ID escape/hash 규칙
4. 파티 전체 완료 Transaction의 최대 읽기·쓰기·Rules 접근 수
5. 기존 수동 로컬 `WeeklyRaidClear` 데이터를 서버로 이행할지 폐기할지
6. 기존 completed 방의 active assignment를 언제 안전하게 정리할지
7. 개인 완료 후 남은 파티의 모집 자동 노출 조건
8. Claim 체크 해제 확인 문구와 오작동 방지 UX

