# Spark Firestore 파티 명령 계약

> 2026-09-14 확장성 재설계 착수: 이 문서는 현재 구현 계약의 근거로 유지하지만, 인원수에 비례하는 Transaction·개인 event fan-out은 [`PARTY_GROUP_COMMAND_SCALABILITY_REDESIGN.md`](PARTY_GROUP_COMMAND_SCALABILITY_REDESIGN.md)의 단계별 새 계약으로 교체한다. 새 구현에서 이 문서의 대규모 원자 처리 방식을 그대로 복제하지 않는다.

## 1. 운영 제약과 신뢰 경계

- 사용자가 별도로 지시하기 전까지 Firebase Spark 무료 요금제만 사용한다.
- Firebase와 다른 외부 서비스도 결제수단 연결, 유료 플랜 전환, 사용량 초과 과금 가능성이 있는 기능을 사용하지 않는다.
- Cloud Functions, Cloud Run, 유료 스케줄러와 유료 서버 API는 현재 명령 경로에 포함하지 않는다.
- 공유 상태 변경은 Flutter 클라이언트가 Firestore Transaction을 실행하고 Security Rules가 인증, 소유권, 현재 revision과 허용된 변경 형태를 검증한다.
- 클라이언트 조작 위험을 완전히 제거할 수 없다. 초기 서비스에서 이 위험을 수용하되, Rules로 표현 가능한 불변식은 반드시 강제한다.

요금제 판단 근거는 Firebase 공식 [요금제 비교](https://firebase.google.com/pricing)와 [Cloud Functions 할당량 안내](https://firebase.google.com/docs/functions/quotas)다. Cloud Functions는 무료 사용량이 있더라도 Blaze 플랜과 Cloud Billing 연결을 요구하므로 현재 범위에서 제외한다.

## 2. 공통 명령 원칙

개인 캐릭터의 주간 레이드 완료와 명령 차단 기준은 [`WEEKLY_RAID_CLAIM_CONTRACT.md`](WEEKLY_RAID_CLAIM_CONTRACT.md)를 따른다. Claim 구현 이후 모집 생성·즉시 가입·승인·참가 캐릭터 변경은 같은 `playerId + characterId + raidId + cycleKey` Claim 부재를 Transaction과 Rules에서 함께 검증해야 한다.

- 모든 명령은 `AuthUid -> PlayerId` active binding을 요구한다.
- 클라이언트 입력의 `PlayerId`를 신뢰하지 않고 binding으로 확정한 값만 사용한다.
- 클라이언트 시간을 상태 경계 판정에 사용하지 않고 `request.time`과 server timestamp를 사용한다.
- 기존 문서를 변경하는 명령은 `expectedRevision`을 요구하고 성공 시 정확히 1 증가시킨다.
- 문서 생성·변경·삭제, 확정 참가 점유와 관련 Claim 변경은 명령별 계약에 따라 한 Firestore Transaction에서 처리한다.
- 주차는 `Asia/Seoul` 수요일 06:00 기준 `cycleKey`를 사용하고 Rules에서 실행 시각과 단순 비교 가능한 기간 필드를 함께 저장한다.
- 실패한 Transaction은 일부 상태를 남기지 않는다. Firestore 재시도 후에도 실패하면 사용자에게 최신 상태 새로고침을 안내한다.

## 3. 확정 참가 점유

```text
players/{playerId}/activeRaidAssignments/{characterId_raidId}
  schemaVersion: 1
  playerId
  characterId
  raidId
  recruitmentId
  cycleKey
  role
  createdAt
  updatedAt
```

- 문서 ID는 안정적으로 정규화한 `characterId_raidId`다.
- 모집 생성, 즉시 가입, 신청 승인은 점유 문서가 없을 때만 성공한다.
- 점유 생성과 멤버십 생성은 항상 같은 Transaction에 포함한다.
- 동시 승인 경쟁은 같은 점유 문서에 대한 Firestore Transaction 충돌로 직렬화한다.
- 다른 방의 승인 대기 신청 자동 종료는 점유 정확성의 필수 조건이 아니다. Spark 단계에서는 현재 Transaction이 알고 있는 신청만 정리하고 나머지는 후속 로컬 명령으로 `superseded`처리할 수 있다.

## 4. 명령별 계약

### 4.1 파티 생성

#### 호출 주체

- active binding이 있는 사용자
- 선택 Character의 현재 소유 Player가 호출자와 일치

#### Transaction 읽기

- Character와 GameAccount 소유 관계
- 대상 `activeRaidAssignment`
- 사용자가 확인한 동일 레이드 승인 대기 신청
- 그룹 레이드면 대상 그룹 원본과 생성자의 현재 membership

#### Transaction 쓰기

- `recruitments/{newId}` Current State 생성
- `members/{currentPlayerId}` 파티장 멤버십 생성
- `activeRaidAssignments/{characterId_raidId}` 생성
- `visibility==group`이고 `groupId`가 있으면 같은 스냅샷을 `groups/{groupId}/raidListings/{newId}`에 생성
- 사용자가 철회를 확인한 신청을 `superseded`로 전환

파티장 membership은 생성 화면에서 선택한 역할의 `gemValidationSnapshot`이 있으면 함께 기록한다. 이는 기존 가입·승인·Character 변경 경로와 같은 보석 최소 요약이며, 모집 원본·점유·그룹 listing에는 복제하지 않는다. 과거 membership의 필드 부재는 허용하고 자동 이행 쓰기는 하지 않는다.

#### 성공 불변식

- `leaderPlayerId == currentPlayerId`
- `memberPlayerIds == [currentPlayerId]`, `memberCount == 1`
- 파티장 membership와 확정 점유가 모두 존재
- 신규 모집은 `revision == 1`, `status == active`

### 4.2 모집 수정

#### 호출 주체

- 현재 `leaderPlayerId`만 호출 가능

#### 허용 변경

- 제목, 레이드·난이도, 숙련도, 최소 전투력, 최대 진행 시간
- 승인 방식 `manualApproval <-> directJoin`
- 모집 수동 활성 상태
- 그룹 레이드의 `visibility` `group <-> public`. `groupId`는 유지한다. 그룹 전용이면 현재 모집 스냅샷으로 `raidListings`를 만들거나 덮어쓰고, 전체 공개면 listing을 삭제한다. 전체 공개→그룹 전용은 비그룹 멤버나 비그룹 pending 신청이 있으면 거절한다.

#### 거절 조건

- `expectedRevision` 불일치
- 활성 회차가 아님
- 변경 후 현재 멤버가 카탈로그 입장 레벨이나 파티 정원을 위반
- 변경 후 현재 참가 캐릭터의 확정 점유를 같은 Transaction에서 새 레이드 ID로 안전하게 이전할 수 없음

레이드 ID가 바뀌는 수정은 모든 멤버의 점유 문서를 원자적으로 이전해야 한다. Security Rules로 전체 멤버의 소유권·카탈로그 조건을 충분히 강제하기 어려우므로 Spark 초기 서버 전환에서는 **레이드·난이도 변경을 제외**한다. 기존 로컬 기능은 서버 모드에서 비활성 안내를 표시한다.

### 4.2.1 그룹 전용 raidListings 동기화 계약

2026-09-01 사용자 합의에 따라 `groups/{groupId}/raidListings/{recruitmentId}`는 생성·공개 범위 전환 시점에만 쓰는 임시 Snapshot이 아니라, 그룹 전용 모집 목록을 위한 동기화 Projection으로 관리한다.

#### 원자성 및 단일 기준

**현재 원자 참가자 제거 경로의 적용 범위(2026-09-29, A2-B):** 아래 전체 Snapshot
동기화는 장기 기준이다. 현재 운영 Router의 `PartyAtomicMemberRemovalWritePlan` 경로는
동일 Transaction의 기존 listing `update`에 원본 patch의 `memberPlayerIds`, `partySlots`,
`raidStateTargets`, `memberCount`, `dealerCount`, `supportCount`, `nonGroupMemberCount`,
`hasAvailableSlot`을 전달하며, 방장 승계 시 leader ID·이름·직업도 전달한다.
정렬 시각은 함께 갱신하고 원본 revision은 `sourceRevision`으로 기록한다. listing 자체
revision·회차·모집 설정은 변경하지 않는다. 이 경로는 listing 누락 시 생성하지 않으며
제거 전체가 실패한다. 별도 조회·비동기 보정·일괄 backfill을 추가하지 않는다.
Rules는 확장 patch의 구성 값과 원본 변경 후 값을 비교하되 구버전 앱의 기존
memberCount/sourceRevision/updatedAt 세 필드 요청도 종전대로 허용한다. 이 구버전 경로는
잔존 구성을 복구하지 않으며 앱 전환 전까지 결함이 남을 수 있다. A2-B 운영 반영 상태는
`NEXT_WORK.md`를 따른다.

- `recruitments/{recruitmentId}`가 원본이며 listing은 독립적인 제품 상태나 권한 기준이 아니다.
- 원본의 목록 노출 관련 필드를 변경하는 명령은 같은 Firestore Transaction에서 listing도 생성·덮어쓰기·삭제한다. 원본 커밋 후 별도 후처리, 화면 진입 시 보정, 실패를 삼키는 비동기 동기화는 사용하지 않는다.
- 그룹 전용 모집인데 listing이 없으면 해당 모집을 변경하는 Transaction에서 현재 원본의 Transaction 후 상태로 listing을 생성한다. 이것은 변경된 방의 자연 복구이며, 변경되지 않은 기존 방의 일괄 보완을 대신하지 않는다.
- Rules는 `getAfter(recruitmentPath(recruitmentId))`를 기준으로 listing 문서가 원본 Snapshot과 `diff` 없이 일치하는지 검증한다. 생성 직후 listing은 revision 1과 파티장만 허용하고, 이후 덮어쓰기는 원본 revision +1과 같은 Transaction의 `updatedAt`을 요구한다. 리더가 아닌 즉시 가입·승인·탈퇴도 원본을 바꾸는 같은 Transaction에서 listing을 쓸 수 있다.

#### 동기화 필드

이번 작업은 listing을 축약 스키마로 마이그레이션하지 않고 현재 모집 스냅샷 구조를 유지한다. 최소한 다음 값은 원본의 Transaction 후 상태와 같아야 한다.

- 노출 상태: `status`, `currentCycleStatus`, `manualRecruitmentEnabled`, `visibility`, `groupId`
- 인원과 자리: `memberCount`, `maxMemberCount`, `hasAvailableSlot`, 목록 매퍼가 사용하는 멤버·자리 Snapshot
- 회차: `currentCycleKey`, 대상 회차 키, 회차 시작·종료 시각
- 카드 표시: 제목, 레이드·난이도, 시작 일정, 최소 조건 등 수정 가능한 공개 카드 필드
- 충돌과 정렬: `revision`, `updatedAt`

구현 시 실제 모집 스키마와 `PublicRecruitmentSummary` 매퍼를 대조해 정확한 필드 목록을 write plan 및 Rules 테스트에 고정한다. 일부 필드만 수동 패치해 나머지 Snapshot을 오래된 값으로 남기지 않는다.

#### 상태별 동작

| 원본의 Transaction 후 상태 | listing 동작 | 이유 |
|---|---|---|
| `visibility == group`이고 되돌릴 수 있는 모집 수명 안에 있음 | 현재 원본 Snapshot으로 생성 또는 전체 덮어쓰기 | 변경 시 누락 listing 자연 복구 및 stale 필드 방지 |
| 만석, `hasAvailableSlot == false` | 유지·갱신 | 탈퇴나 다음 회차에서 다시 노출될 수 있음 |
| 회차 완료 또는 반복 모집의 다음 주 대기 | 유지·갱신 | 반복 모집은 다음 주차 전환으로 다시 열릴 수 있음 |
| 전체 공개로 전환 | 삭제 | 공개 `recruitments` 쿼리가 단일 목록 경로가 됨 |
| 방 해산 등 되돌릴 수 없는 종료 | 삭제 | 다시 노출될 수 없고 stale active 오인을 제거함 |

`completed`라는 문자열만으로 삭제하지 않는다. 반복 모집의 다음 주차 재노출 가능성과 1회성 모집의 해산 상태를 함께 판정한다. 같은 주차의 파티 전체 완료 취소는 제공하지 않는다.

#### 영향 명령과 제외 범위

최소 점검 대상은 즉시 가입·신청 승인, 파티원 탈퇴·추방, 캐릭터·자리 변경, 모집 완료, 다음 회차 전환, 반복 여부 변경, 모집 해산, 카드 표시 정보 수정, 공개 범위 변경이다. 승인 권한 토글처럼 listing의 노출·정렬·카드 값에 영향을 주지 않는 변경은 원본 revision 정책을 확인한 뒤 동기화 대상에서 제외할 수 있다.

- 과거 그룹 전용 모집 전체를 `recruitments`에서 검색해 listing을 만드는 일괄 보완은 이 동기화 작업에 포함하지 않는다. 참가 중인 방의 listing 누락 보완은 별도 작업에서 모집 revision을 올리지 않는 listing create로 처리한다.

### 4.3 승인 대기 신청

#### 호출 주체

- Character 소유권이 active인 신청자

#### 조건

- 모집이 `active`, `manualApproval`, 모집 활성이고 빈자리가 있음
- 신청자가 현재 멤버가 아님
- 같은 방의 승인 대기 신청이 없음
- 선택 Character가 카탈로그 입장 레벨과 모집 최소 전투력 조건을 만족
- 같은 레이드의 다른 승인 대기 신청은 허용

#### 최소 전투력 판정 계약

- 현재 최소 전투력은 모집 생성 시 정해지고, 실제 앱에는 생성 후 모집 조건 수정 기능이 연결되어 있지 않다. 따라서 이번 계약에서는 신청 대기 중 제한 변경을 다루지 않는다. 모집 수정 기능을 추가할 때 기존 pending 신청과 참가 멤버의 처리 정책을 별도로 정한다.
- 변조 클라이언트와 권위 있는 서버 전투력 검증은 현재 범위에서 고려하지 않는다. 전투력을 속여 제한 모집에 참가할 실익이 낮고 외부 배포된 구버전도 없는 현재 단계에서는 정상 앱 UX 보호만 완료 기준으로 삼는다. 신청자 앱이 계정 갱신으로 보유한 선택 역할의 Build Snapshot 전투력을 판정 기준으로 사용한다.
- 제한이 설정된 모집은 전투력 Snapshot이 없거나 제한보다 낮은 Character/역할을 신청 후보에서 선택할 수 없다. 신청·재신청 버튼 실행 직전에도 현재 모집 Aggregate의 `minCombatPower`와 제출할 Snapshot을 다시 비교해 application 쓰기 전에 차단한다.
- 즉시 가입과 참가 Character 변경도 같은 신청자 본인 Snapshot 판정을 적용해 신청 경로 우회를 허용하지 않는다. 모집 생성자의 초기 Character가 자신이 입력한 최소 전투력을 만족해야 하는지는 이번 범위에서 새로 강제하지 않고 기존 동작을 유지한다.
- 공대장은 신청자의 최신 private 데이터를 추가 조회하지 않는다. 정상 신규 신청은 신청자 단계에서 먼저 걸러진다. 다만 과거 신청과 UI 우회를 막기 위해 approval Transaction은 이미 읽는 application의 `submittedBuildSnapshot.combatPower`와 모집 원본의 고정 제한만 비교한다. Snapshot이 없거나 제한 미달이면 승인을 거절하되 신청은 `pending`으로 유지하고 자동 거절하지 않는다.
- 이 판정은 신청자 정상 앱 흐름의 실수 방지 계약이다. 서버 전투력 동기화, 위변조 방지와 Rules 최종 강제는 별도 요구가 생길 때 새 계약으로 설계한다.

#### Transaction 쓰기

- `applications/{currentPlayerId}` 문서를 `pending`으로 생성
- 신청 시점의 Character·역할·아이템 레벨·전투력 Snapshot 저장

승인 대기는 확정 점유를 생성하지 않는다.

#### 거절·철회·superseded 후 재신청

- 같은 방·같은 Player 문서가 `rejected` / `withdrawn` / `superseded`이면 **새 문서를 만들지 않고** 해당 문서를 다시 `pending`으로 갱신한다.
- 이전 승인 후 탈퇴해 현재 `memberPlayerIds`에 없는 Player의 application이 `approved`로 남아 있어도 같은 문서를 `pending`으로 갱신해 재신청할 수 있다. `memberPlayerIds`에 실제로 남아 있으면 기존 멤버 검증이 먼저 거절한다.
- `rejectionCount`는 유지한다(거절 누적 안내). `approvalCount`는 0으로 초기화한다.
- Character·역할·빌드 Snapshot과 `cycleKey`는 재신청 시점으로 교체하고 `revision`을 1 증가시킨다.
- `pending`이 이미 있으면 중복 신청으로 거절한다. `approved`는 현재 membership이 남아 있으면 재신청하지 않으며, 탈퇴로 membership이 제거된 경우에만 위 기준으로 재사용한다.
- 거절 이력은 **모집방(recruitmentId) 단위**이며 다른 방으로 전파하지 않는다.

### 4.4 신청 철회

- 신청자 본인의 `pending` 문서만 `withdrawn`으로 변경한다.
- `expectedApplicationUpdatedAt` 또는 신청 revision으로 동시 승인과 경쟁을 감지한다.
- 이미 `approved`, `rejected`, `withdrawn`, `superseded`면 멱등적 현재 결과를 반환하고 멤버십을 역으로 제거하지 않는다.

#### 승인 대기 고아 신청 정리

- 신청자 본인은 부모 모집이 존재하지 않거나 부모 상태가 `completed`, `disbanded`, `incompleteEnded`일 때에만 자기 `applications/{playerId}` 문서를 삭제할 수 있다.
- `active` 모집의 신청은 상태와 무관하게 이 삭제 경로를 사용할 수 없다. `pending`이면 기존 철회를 사용하고 처리 결과는 모집 단위 재신청 이력으로 유지한다.
- Rules가 현재 binding, 문서의 `applicantPlayerId/recruitmentId`, 삭제 시점의 부모 존재·상태를 검증한다. 클라이언트가 부모를 읽지 못했다는 사실만으로 고아로 간주하지 않는다.
- 이 명령은 application 한 건만 삭제한다. 모집 Aggregate, membership, `raidState`, 주간 완료와 이벤트를 함께 쓰지 않는다.

### 4.5 즉시 가입

신청과 확정 참가를 한 Transaction으로 처리한다. 중간 `pending` 문서를 만들지 않는다.

#### Transaction 읽기

- 모집과 revision, 정원·역할별 자리
- Character·GameAccount 소유권
- 확정 참가 점유

#### Transaction 쓰기

- `members/{currentPlayerId}` 생성
- `memberPlayerIds`, 전체·역할별 인원과 `hasAvailableSlot` 갱신
- `activeRaidAssignment` 생성
- 모집 revision 1 증가

정원·역할·동일 딜러 직업 제한을 Transaction 재시도 마다 다시 계산한다.

### 4.6 신청 승인·거절

#### 호출 주체

- 현재 파티장 또는 `canApproveApplications == true`인 현재 멤버

#### 거절

- `pending` 신청을 `rejected`로 변경하고 `decidedAt`, `updatedAt`을 server timestamp로 저장한다.
- 멤버십과 확정 점유는 생성하지 않는다.

#### 승인

- 모집, 신청, 신청 Character 소유권, 정원·역할, 확정 점유를 다시 읽는다.
- 신청을 `approved`로 변경하고 membership·확정 점유를 생성하며 모집 인원·파생 필드·revision을 갱신한다.
- 점유 문서 생성 경쟁에서 신 승인만 성공하고 나머지는 `participationConflict`로 실패한다.

### 4.7 확정 파티원 관리

#### 참가 캐릭터 변경

- 현재 멤버 본인만 자기 소유 Character로 변경할 수 있다.
- 기본은 `partyIndex`와 `slotIndex` 유지이며 8인 예외는 아래 배치 규칙을 따른다. 역할은 유지하거나 배치 후 역할 정원과 전체 구성 조건을 만족할 때 dealer↔support로 변경할 수 있다.
- 다른 Character뿐 아니라 같은 Character의 저장된 반대 역할 설정도 허용한다.
- 새 Character의 소유권, 입장 레벨, 확정 점유, 역할별 자리와 현재 파티의 동일 직업 딜러 제한을 다시 검증한다.
- 변경 후보 조회와 최종 변경 Transaction은 새 Character의 기존 `raidState`를 같은 점유 판정으로 분류해야 한다. 후보 단계에서 교체 가능으로 표시한 종료 모집 연결 state를 최종 명령이 단순 존재 여부만으로 `participationConflict` 처리해서는 안 된다.
- 새 Character가 현재 유효한 다른 모집에 참가 중이면 기존처럼 `participationConflict`로 거절한다. 만료됐지만 다음 회차 승계 대상인 반복방도 회차 조정 전에는 유효 점유로 보며, 현재 주차 완료 state는 기존 `weeklyRaidCompleted` 차단을 유지한다.
- `active` state가 존재하지만 연결 모집이 없거나 `completed`, `disbanded`, `incompleteEnded`여서 기존 점유 정책상 고아로 판정되면 캐릭터 변경 Transaction은 아무 문서도 쓰지 않고 정확한 `playerId/characterId/raidId/cycleKey/recruitmentId/revision`을 포함한 명시적 고아 결과를 반환한다.
- 화면은 기존 단일 고아 참가 정리 명령과 확인 대화상자를 재사용한다. 정리는 서버에서 같은 state와 부모 모집 상태를 다시 검증하고, 성공 뒤 캐릭터 변경을 자동 재실행하지 않는다. 사용자가 다시 선택·실행하면 변경 Transaction이 모든 조건을 새로 검증한다.
- 모집 연결이 불명확하거나 읽은 state와 정리 대상 식별자가 일치하지 않는 경우에는 자동 덮어쓰기·삭제하지 않고 상태 불일치로 거절한다. 종료된 모집 전체 검색, Player 전체 순회와 과거 데이터 일괄 migration은 이 흐름에 포함하지 않는다.
- 변경 후보 목록은 소유자 기기의 로컬 통합 Build 상태로 보석·아크그리드 확정 오류를 안내할 수 있다. 이 표시는 선택을 차단하지 않고 서버 계약에는 기존 보석 최소 요약만 전달한다.
- 다른 Character 변경은 기존 확정 점유 삭제와 새 점유 생성을, 같은 Character 역할 변경은 기존 점유의 역할 갱신을 사용한다. membership Snapshot·role, 모집 역할별 집계와 revision을 같은 Transaction에서 갱신한다.
- 다른 확정 파티에 참가 중인 Character의 이동·스왑은 로컬 최신 Projection으로 결과를 미리 계산하되, 양쪽 모집·membership·점유와 revision을 서버 Transaction에서 다시 검증하는 별도 후속 명령으로 구현한다.
- 완전 스왑 조건을 만족하지 못해 한쪽 파티 탈퇴가 동반되는 경우 예상 결과를 먼저 표시하고 사용자가 명시적으로 확인한 때에만 실행한다.
- 이 후속 명령은 Spark에서 원천 제외하지 않는다. Rules로 결합 불변식을 안전하게 강제할 수 있는지 기능 설계와 함께 검증한다.

#### 탈퇴와 추방

- 일반 참가자는 본인만 탈퇴할 수 있고 현재 책임자만 다른 참가자를 추방할 수 있다.
- membership과 확정 점유를 삭제하고 모집의 멤버 목록·역할별 인원·빈자리·revision을 함께 갱신한다.
- 책임자가 탈퇴하면 Transaction으로 직렬화된 `memberPlayerIds` 가입 순서의 첫 잔여 Player에게 책임자를 승계하고 가입 승인 권한을 부여한다.

#### 그룹 전용 자격 상실 정리

- 그룹 탈퇴·추방은 레이드 membership을 자동 삭제하지 않는다.
- 현재 `visibility==group`인 레이드에서만 그룹 membership이 없는 참가자를 자격 상실로 본다.
- 전체 공개 상태인 그룹 연결 레이드는 그룹 탈퇴만으로 참가 자격을 잃지 않는다.
- 활동 Character 해제는 이 자격 상실과 같지 않다.
- 같은 방에 남은 유효 그룹원(그룹장 포함)이 제한적 정리를 요청할 수 있다. 일반 추방 권한을 모든 멤버에게 주지 않는다.
- Transaction은 요청자의 현재 레이드·그룹 membership과 대상의 그룹 membership 부재, 모집 revision을 같은 작업에서 재검증한 뒤에만 membership·점유를 삭제한다.
- 마지막 책임자가 탈퇴하면 모집을 삭제하지 않고 `disbanded`로 종료하며 수동 모집을 비활성화한다.

#### 가입 승인 권한

- 현재 책임자만 다른 현재 멤버의 `canApproveApplications`를 부여하거나 회수할 수 있다.
- 책임자 자신의 고유 승인 권한은 이 명령으로 회수할 수 없다.
- membership 권한과 모집 revision을 같은 Transaction에서 갱신한다.

#### 고정 슬롯 배치

- `partyIndex`는 파티 번호, `slotIndex`는 파티 내부 자리 번호로 분리하고 두 값의 조합을 모집 안에서 유일하게 유지한다.
- 파티 생성 시 책임자를 `partyIndex == 0`, `slotIndex == 0`에 배치한다. 8인 레이드에서도 이 자리가 파티장 겸 공대장이다.
- 가입·승인은 현재 멤버의 자리를 재배치하지 않고 역할·직업 구성 조건을 만족하는 빈 슬롯 하나를 결정해 membership에 기록한다.
- 탈퇴·추방으로 빈자리가 생겨도 남은 멤버를 자동 이동하지 않는다. 자리 이동과 스왑은 별도 명령과 revision 검증으로 처리한다.
- `slotLedgerVersion: 2` 모집을 해산할 때는 모든 membership에 대응하는 슬롯 Claim을 membership·assignment·필요 group listing과 같은 Transaction에서 삭제한다. 해산된 모집 아래에 점유 Claim을 남기지 않는다. 슬롯 원장 도입 전 모집은 Claim 부재를 정상으로 취급한다.
- 현재 배포된 `partyIndex` 전용 membership은 신규 가입 명령을 전환하기 전에 결정적인 규칙으로 `slotIndex`를 채워야 한다. 문서 순회 순서처럼 실행마다 달라질 수 있는 값은 이행 기준으로 사용하지 않는다.
- 향후 빈 슬롯의 역할·직업군·시너지 요청 조건은 membership과 분리한 슬롯 요구조건으로 저장하고 가입 시 Transaction과 Rules가 함께 검증한다.

#### 8인 Character 변경 배치와 공대 자리 조정

- 파티는 직업 중복과 시너지를 판정하는 4인 단위이고, 공격대는 한 개 이상의 파티를 묶은 레이드 참가 단위다. 현재 구현 범위는 4인 1파티와 8인 2파티다.
- 구성 직업 키는 정규 직업과 역할을 결합한다. 같은 역할의 깨달음 분기는 같은 직업으로 보고, 딜러형과 서포터형은 서로 다른 구성 직업으로 본다. 따라서 전투 태세/고독한 기사 워로드는 같은 딜러 워로드이고 딜러/서포터 발키리·바드는 서로 다른 키다.
- 신규 신청·가입은 기존처럼 각 파티에 같은 구성 직업이 없도록 배치한다. 확정 멤버의 Character 변경은 제자리, 다른 파티의 유효한 빈자리, 한 명과의 단순 교환 가능성 순서로 검사한다.
- 유효한 빈자리가 있으면 변경 대상 한 명만 결정적 첫 슬롯으로 이동한다. 전체 공격대를 자동 재배치하지 않는다.
- 빈자리는 없지만 다른 파티의 일반 멤버 한 명과 자리를 바꾸면 양쪽 파티가 정상인 경우 Character 변경은 현재 자리에서 허용한다. 교환은 자동 실행하지 않고 현재 중복 카드에 `동일 직업 · 자리 조정 필요` 비차단 안내를 표시한다.
- 제자리·빈자리·단일 교환 어느 방식으로도 정상 구성이 불가능하면 변경을 거절한다. 4인은 다른 파티가 없어 기존 제자리 판정을 유지한다.
- 구성 안내는 membership 현재 값에서 파생하며 별도 boolean으로 저장하지 않는다. 빨간 Build 오류와 동시에 표시할 수 있고 공대장 조정 후 자동으로 사라진다.
- `leaderPlayerId`만 자리 조정 명령을 실행한다. 공대장 고정석 `0:0`은 이동·교환하지 않는다. 빈 슬롯이면 한 membership을 이동하고 점유 슬롯이면 두 membership의 위치만 원자적으로 교환한다.
- 순수 자리 조정은 Character·role·Build Snapshot·assignment·Claim을 변경하지 않는다. recruitment revision과 필요 group listing을 함께 갱신하고 기존 알림 계약대로 `memberMoved` 이벤트를 명령 직전 확정 멤버에게 기록한다.

#### 슬롯 점유 원장

> 아래 별도 slots 원장은 이전 스키마 계약이다. 현재 schemaVersion 2는
> PARTY_GROUP_COMMAND_SCALABILITY_REDESIGN의 Aggregate.partySlots를 원장으로 사용한다.
> BUG-017 복원도 이 최대 8칸에서 배치를 계산하며 전원 membership 재조회나 별도 slots
> 문서를 만들지 않는다. 캐릭터 변경과 자동 빈자리 이동은 하나의 characterChanged
> 공용 이벤트로 기록하고 별도 이동 이벤트를 만들지 않는다.

- 신규 모집부터 `slotLedgerVersion: 2`와 `recruitments/{recruitmentId}/slots/{partyIndex}_{slotIndex}` 최소 Claim을 필수로 사용한다.
- 슬롯 문서는 `{playerId, partyIndex, slotIndex, updatedAt}`만 저장한다. 문서 ID와 두 index가 일치해야 하고, 같은 원자적 명령의 membership 위치와 `playerId`가 일치해야 한다.
- 역할 정원·동일 딜러 직업·변경 배치는 Transaction이 다시 읽은 최신 membership을 앱의 공용 Domain 정책으로 계산한다. Rules는 전체 파티 조합을 재계산하지 않고 권한·revision·변경 필드·Claim 연결만 검증한다.
- 생성은 리더 슬롯 생성, 가입은 빈 슬롯 생성, 탈퇴는 점유 슬롯 삭제, 이동은 이전 슬롯 삭제+새 슬롯 생성, 교환은 두 슬롯 점유자 교환으로 구성한다.
- 슬롯 원장이 없는 과거 모집을 일반 사용자 요청으로 부분 bootstrap하지 않는다. 해당 모집의 기존 명령은 보존하되 위치 변경만 거절한다. 관리자 migration은 실제 운영 데이터 이관이 필요해질 때 별도 승인·백업·검증 단위로 수행한다.
- Character 변경과 빈자리 이동이 함께 일어나면 기존 `memberCharacterChanged` 이벤트에 이전/새 파티·슬롯을 포함하고 별도 이동 이벤트를 중복 생성하지 않는다.
- Rules는 본인 Character 변경과 공대장 자리 조정을 별도 경로로 구분한다. 한 명 이동 또는 두 명의 정확한 슬롯 교환, 제한된 affected keys와 recruitment revision을 검증하며 기존 소유권·Player 중복·점유·Claim 조건을 완화하지 않는다.
- 16인, 연쇄 이동, 자동 시너지 최적화와 파티별 별도 파티장 권한은 현재 범위가 아니다. 향후 실제 레이드가 추가될 때 `partyCount` 기반 확장을 다시 검증한다.

### 4.8 회차 수명주기

#### 완료와 Snapshot

- 파티장·공대장만 파티 전체 완료를 실행할 수 있다. 일반 멤버는 별도 `내 캐릭터 완료`로 본인 탈퇴와 본인 Claim만 처리한다.
- `cycles/{cycleKey}`에 완료 당시 Player·Character·역할·파티 위치 Snapshot과 완료자를 저장하고 모집의 `currentCycleStatus`, 완료자와 revision을 함께 갱신한다.
- 1회성 파티는 모집을 `completed`로 종료하고 반복 파티는 방을 `active`로 유지해 다음 회차 준비 변경을 허용한다.
- 전체 완료는 Snapshot 전원의 `partyOwner` Claim 생성과 active assignment 삭제를 같은 Transaction에서 처리한다.

#### 완료 확정

- 2026-09-19 결정으로 같은 주차의 파티 전체 완료 취소 명령은 제공하지 않는다.
- 공대장이 완료한 회차는 그대로 보존하며 각 사용자는 내 계정에서 자기 완료 체크만 해제할 수 있다.
- 개인 해제는 공동 Snapshot·membership·다른 사용자 완료를 변경하거나 과거 참가 상태를 복원하지 않는다.
- 반복 파티는 수요일 06시 다음 주차 전환에서 현재 membership을 기준으로 새 참가 상태를 구성한다.

#### 반복 설정과 주차 전환

- 현재 미완료 회차의 책임자만 `continueTogether`를 변경할 수 있다.
- 각 모집은 KST 수요일 6시 기준 `cycleStartedAt`, `cycleEndsAt`과 7일 간격을 저장한다.
- 유료 스케줄러를 사용하지 않는다. 앱 실행·관련 화면 진입·명령 수행 시 만료 회차를 발견한 현재 멤버가 멱등 전환 Transaction을 실행한다.
- 미완료 회차는 `incompleteEnded` Snapshot을 생성한다. 반복 파티는 현재 구성을 다음 회차로 승계하고 1회성 파티는 종료한다.
- 지연 실행되더라도 Rules의 `request.time >= cycleEndsAt`, 연속된 다음 회차 경계와 revision 검증을 모두 통과해야 한다.

#### 만료 방 발견과 1회성 미완료 종료

- 만료 여부만으로 반복방과 1회성 방을 같은 명령으로 처리하지 않는다. `status == active && cycleEndsAt <= now`인 방을 발견하면 `continueTogether == true`는 기존 다음 회차 전환만 실행하고, `continueTogether == false`는 1회성 미완료 종료만 실행한다.
- 1회성 미완료 종료는 화면에 보이거나 사용자가 접근한 모집 한 건만 대상으로 하는 멱등 Transaction이다. 전체 모집·그룹을 순회하는 스캔, 유료 스케줄러, Cloud Functions와 운영 데이터 일괄 migration은 도입하지 않는다.
- Transaction은 모집을 다시 읽고 `schemaVersion == 2`, 모집·현재 회차의 `active` 상태, `continueTogether == false`, `request.time >= cycleEndsAt`, 예상 `revision/currentCycleKey`를 모두 검증한다. 요청 중 반복 설정이나 revision이 바뀌면 거절 또는 재시도하며 반복방을 `incompleteEnded`로 바꾸지 않는다.
- 성공 시 모집의 `status/currentCycleStatus`를 `incompleteEnded`로 바꾸고 모집 활성·빈자리 표식을 끄며 revision과 명령 표식을 한 번만 증가시킨다. 참가자 구성 Snapshot과 모집 원본은 보존하고 자동 완료·해산·소유권 이전으로 바꾸지 않는다.
- 그룹 전용방이면 같은 Transaction에서 해당 `raidListings/{recruitmentId}`를 삭제하고, Transaction이 다시 읽은 현재 그룹의 `activeRecruitmentCount`를 `N -> N-1`로 갱신한다. 방 생성 당시 count나 모집 Snapshot count를 사용하지 않는다. 공개방은 그룹 문서를 쓰지 않는다.
- 이 명령은 참가자별 `players/{playerId}/raidStates/{stateId}`를 읽기 전제, 생성, 갱신 또는 삭제하지 않는다. 모집에 저장된 `raidStateTargets`는 당시 구성의 감사 Snapshot으로 그대로 보존한다.
- 대상 `raidState`가 이미 없거나, 같은 결정적 경로가 이후 주차·다른 모집에 재사용돼 현재 `recruitmentId/cycleKey`가 달라도 미완료 종료를 막지 않는다. 특히 다른 모집이 소유한 현재 상태를 과거 방 종료가 삭제하거나 덮어써서는 안 된다.
- 미완료 종료 이력은 대상자가 자기 기록을 만들 수 있는 공용 lifecycle 이벤트 한 건으로 발행한다. Player별 이벤트 fan-out을 추가하지 않는다.
- 명령 실행 주체는 기존 계약대로 만료 회차를 발견한 현재 멤버로 제한한다. Rules는 행위자가 임의 종료 상태를 고르는 것을 허용하지 않고 위 고정 전이와 쓰기 집합만 검증한다.
- 이미 `completed`, `disbanded`, `incompleteEnded`인 방은 변경하지 않는다. 기존 완료·해산·추방·자리 변경·반복방 다음 회차 전환의 권한, 판단 조건과 쓰기 순서는 이 명령 때문에 완화하거나 재정의하지 않는다.

## 5. Security Rules 보장 범위

Rules는 적어도 다음을 `getAfter()`를 포함해 검증해야 한다.

- binding으로 확정한 Player만 자기 멤버십·신청·점유 문서의 허용된 변경을 요청
- 파티 생성 시 파티장 membership과 점유가 함께 존재
- membership 생성 시 일치하는 점유가 함께 존재
- `memberPlayerIds`, `memberCount`, membership 변경이 허용된 명령 형태에서 함께 이뤄짐
- 신청자는 자기 `pending -> withdrawn`, 승인자는 `pending -> approved|rejected`만 가능
- 모집 수정은 파티장만 허용하고 불변 필드와 revision 증가를 검증
- 서버 검증이 필요하지만 Rules로 안전하게 표현할 수 없는 변경은 허용하지 않음

생성 Transaction은 신규 `recruitments/{id}` 존재 여부를 `get`으로 확인한다. 문서가 없을 때 `resource.data`를 읽으면 Rules가 `permission-denied`를 내므로, 존재하지 않는 모집의 단건 `get`은 active binding만으로 허용한다. 존재하는 문서의 단건 읽기는 `canReadRecruitment`, `recruitments` 목록은 `canListRecruitment`를 사용한다. 그룹만 공개 목록은 `groups/{groupId}/raidListings`에서 경로의 그룹원만 `list`하며, `recruitments` list 규칙에 그룹 membership `exists`를 넣지 않는다. 그룹 listing 생성·덮어쓰기는 같은 Transaction의 `getAfter` 모집 Snapshot과 문서 `diff`가 없어야 한다. listing 삭제는 전체 공개 전환 또는 방 해산처럼 되돌릴 수 없는 종료에서만 허용한다.

Rules 상세 구현·배포는 명령별 작업 브랜치에서 진행한다. Firestore Emulator는 사용하지 않는다. Rules 배포 전 검증 방법은 별도로 합의한다.

## 6. 오류 계약

```text
unauthenticated
playerBindingMissing
permissionDenied
notFound
revisionConflict
ownershipLost
invalidCharacter
catalogMismatch
participationConflict
scheduleConflict
capacityFull
roleCapacityFull
duplicateClass
applicationAlreadyExists
applicationNotPending
unsupportedOnSpark
temporarilyUnavailable
unknown
```

- 유저 메시지에 Firestore 경로, AuthUid, PlayerId, 내부 exception을 노출하지 않는다.
- `revisionConflict`, 정원·점유 경쟁은 최신 상태를 다시 읽고 사용자가 재시도하게 한다.
- Spark에서 안전하게 지원하지 않는 레이드·난이도 수정은 `unsupportedOnSpark`로 명시한다.

## 7. 멱등성과 재시도

- 생성은 클라이언트가 생성한 충분히 무작위한 `recruitmentId`를 요청 ID로 사용한다. 같은 ID의 완료된 생성 재시도는 기존 결과를 반환한다.
- 신청은 `applications/{playerId}` 고정 ID로 중복 생성을 방지한다.
- 철회·거절는 이미 같은 최종 상태면 성공으로 간주할 수 있다.
- 승인·즉시 가입은 membership과 점유가 모두 일치하는 경우에만 기존 성공 결과를 반환한다.
- 후속 알림 이벤트는 성공한 명령의 같은 Transaction에서 기록하며 명령 revision과 event type으로 안정적인 ID를 만든다. 클라이언트가 다른 Player 경로에 자유 형식 알림을 쓰는 권한은 허용하지 않는다. 이벤트별 수신자와 Rules 기준은 [`PARTY_NOTIFICATION_CONTRACT.md`](PARTY_NOTIFICATION_CONTRACT.md)를 따른다.

## 8. 구현 분할

1. 파티 생성과 확정 참가 점유
2. 승인 대기 신청과 본인 철회
3. 즉시 가입
4. 신청 승인·거절
5. 참가 캐릭터 변경·탈퇴·추방·승인권·책임자 승계
6. 회차 완료·반복 설정·주차 전환과 Snapshot
7. 제목·조건·승인 방식·모집 활성 수정
8. 실행 앱을 Firestore 읽기·쓰기 Repository로 전환

각 단위는 해당 명령의 Rules, 동시 Transaction 테스트, 오류 UI와 로컬 Domain 회귀 테스트를 함께 마감한다.

## 9. 실행 앱 전환 상태

- 읽기: `레이드 현황`의 진행 중·신청 중·읽기 전용 상세는 Firestore `PartyReadRepository`를 사용한다.
- 쓰기 1단위: `레이드 모집 > 모집 생성`만 `FirestorePartyCreateRepository`로 연결한다. 성공 시 `/raid-status/{recruitmentId}` 읽기 상세로 이동한다.
- 쓰기 2단위: 읽기 전용 상세의 신청·본인 철회는 `FirestorePartyApplicationCommandRepository`로 연결한다. 신청 Character는 `serverCharacterId`다.
- 쓰기 3단위: 상세의 즉시 가입·승인·거절·방 단위 재신청은 Firestore 명령으로 연결했고 합동 실기기 검증을 통과했다. 단독 멤버 모집 삭제도 연결했다.
- 생성 명령의 `leaderCharacterId`는 Drift 로컬 ID가 아니라 게임 계정 인증으로 저장된 `serverCharacterId`다. 인증되지 않은 캐릭터는 명령을 보내지 않는다.
- 생성 Transaction의 신규 모집 `get`이 문서 부재에서 `permission-denied`가 되지 않도록, 존재하지 않는 `recruitments/{id}` 단건 읽기는 active binding만으로 허용한다. 이 Rules는 `lost-party`에 배포했다.
- Android 실기기에서 인증된 캐릭터로 생성한 방이 `진행 중`에 나타나고 읽기 전용 상세(수정 미적용 안내 포함)로 연결되는 것을 확인했다.
- `레이드 모집` 공개 목록은 Firestore 페이징 읽기(`watchPublicRecruitmentFirstPage` / `loadPublicRecruitmentNextPage`)를 사용한다.
- 고정 슬롯 구성판과 참가 캐릭터 변경·탈퇴·추방은 현황 상세에 연결됐다.
- 회차 완료·반복 설정·주차 전환·다인 해산은 현황 상세에 연결됐다. 기존 완료 취소 연결은 제거 대상으로 분류한다. Rules에 해산·완료 후 반복 설정 변경을 허용하는 식을 추가했으며 **배포 후** 실기기에서 확인한다.
- 상세 라우트는 `ValueKey(recruitmentId)`와 ViewModel 재구독으로 id 변경 시 이전 방 State가 남지 않게 한다.
