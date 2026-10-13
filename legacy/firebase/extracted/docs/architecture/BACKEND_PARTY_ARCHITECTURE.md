# 기존 서비스 발췌 — docs/architecture/BACKEND_PARTY_ARCHITECTURE.md

원본 문서: docs/architecture/BACKEND_PARTY_ARCHITECTURE.md ([현재 문서](../../../../../docs/architecture/BACKEND_PARTY_ARCHITECTURE.md)). 분리일: 2026-10-13.
원본 전체 SHA256: 1c51099fd8dfbf3f8a5d0a8a08e7203463cbc5ab869e175219f039a7d8a33aef.
아래는 기존 Firebase 환경의 원문이다. 신규 서버의 실행 지시/배포 승인으로 사용하지 않는다. 행 범위는 분리 직전이며 링크 위치만 조정한다.

<a id="source-0001"></a>

## 발췌 1: ## 1. 목적

출처: docs/architecture/BACKEND_PARTY_ARCHITECTURE.md · 원본 7~7행 · 원문 절: ## 1. 목적.

별도 지시 전까지 Spark 무료 요금제를 유지한다. 클라이언트가 화면과 명령을 담당하고 Firestore Transaction과 Security Rules로 허용된 상태 전이를 원자적으로 반영한다. 서버 전용 권한이 필요한 변경은 현재 범위에서 제외한다.

<a id="source-0002"></a>

## 발췌 2: ## 1. 목적

출처: docs/architecture/BACKEND_PARTY_ARCHITECTURE.md · 원본 9~9행 · 원문 절: ## 1. 목적.

사용자 흐름, 반복 파티, 주차별 회차, 완료·취소·해산, 알림과 개인 레이드 히스토리의 최신 제품 기준은 `FIREBASE_PARTY_PRODUCT_FLOW.md`를 따른다. 이 문서는 그 제품 기준을 구현하기 위한 백엔드 구조를 설명한다.

<a id="source-0003"></a>

## 발췌 3: ## 1. 목적

출처: docs/architecture/BACKEND_PARTY_ARCHITECTURE.md · 원본 11~11행 · 원문 절: ## 1. 목적.

로컬 Fake 환경에서 UI와 제품 흐름을 검증하기 위해 적용했던 Firebase 전역 구현 보류 단계는 종료됐다. 이후 작업은 전체 백엔드 설계 완료를 기다리지 않고, 각 기능의 데이터 계약·권한·트랜잭션·Security Rules·테스트 범위를 먼저 확정한 뒤 단계적으로 구현한다.

<a id="source-0004"></a>

## 발췌 4: ## 1. 목적

출처: docs/architecture/BACKEND_PARTY_ARCHITECTURE.md · 원본 13~13행 · 원문 절: ## 1. 목적.

`AuthUid -> PlayerId` 최초 생성·재사용과 Security Rules의 현재 계약은 `FIREBASE_PLAYER_BINDING_CONTRACT.md`를 따른다.

<a id="source-0005"></a>

## 발췌 5: ## 2. 현재 기술 구성

출처: docs/architecture/BACKEND_PARTY_ARCHITECTURE.md · 원본 17~36행 · 원문 절: ## 2. 현재 기술 구성.

## 2. 현재 기술 구성

```text
Flutter
→ Firebase Authentication
→ Cloud Firestore
→ Flutter Firestore Transaction
→ Firestore Security Rules
```

- Firebase Authentication: AuthUid와 로그인 수명 관리
- Cloud Firestore: 모집글, 신청, 파티원, 그룹 및 초대의 실시간 읽기 모델
- Firestore Transaction: 정원, 역할별 자리, 투표 수 및 가입 상태의 동시성 보장
- Security Rules: binding, 소유권, revision과 허용된 다중 문서 변경 형태 검증
- Callable Functions·App Check 강화·FCM 서버 이벤트: 유료 플랜과 비용을 별도로 승인할 때까지 보류

현재 단계에서는 별도 애플리케이션 서버보다 Firebase 구성이 개발 및 운영 비용에 적합하다. Repository 경계를 유지해 향후 별도 REST 서버로 교체할 수 있게 한다.

---


<a id="source-0006"></a>

## 발췌 6: ## 3. 신뢰 경계

출처: docs/architecture/BACKEND_PARTY_ARCHITECTURE.md · 원본 37~55행 · 원문 절: ## 3. 신뢰 경계.

## 3. 신뢰 경계

클라이언트는 다음 공유 필드를 단독 문서 쓰기로 수정할 수 없다. 허용된 Transaction 명령 형태와 Rules `getAfter()` 검증을 모두 만족해야 한다.

- 파티장 또는 공대장 PlayerId
- 가입 승인 상태
- 파티원 목록과 현재 인원
- 역할별 현재/남은 자리
- 승인/거절 투표 수
- 모집 마감 상태
- 그룹 소유자와 멤버십 상태
- 그룹 초대의 최종 수락 상태

Flutter 앱은 명령별 Firestore Transaction을 실행한다. Rules는 binding, 권한, revision, 현재 상태와 함께 변경되어야 하는 문서를 검증한다. Rules로 충분히 보장할 수 없는 명령은 Spark 범위에서 비활성한다.

Lost Ark 캐릭터 정보도 클라이언트 제출값을 최종 신뢰하지 않는다. 강제 가입 조건에 사용하려면 서버가 조회하거나 검증한 캐릭터 스냅샷이 필요하다. 서버 검증 전 단계의 조건은 참고용으로 표시한다.

---


<a id="source-0007"></a>

## 발췌 7: ## 4. 정적 레이드 카탈로그

출처: docs/architecture/BACKEND_PARTY_ARCHITECTURE.md · 원본 68~68행 · 원문 절: ## 4. 정적 레이드 카탈로그.

Flutter Domain과 Firestore Rules가 동일한 원본 카탈로그 또는 같은 원본에서 생성한 검증 산출물을 사용한다.

<a id="source-0008"></a>

## 발췌 8: ## 5. 파티 모집 데이터

출처: docs/architecture/BACKEND_PARTY_ARCHITECTURE.md · 원본 74~162행 · 원문 절: ## 5. 파티 모집 데이터.

## 5. 파티 모집 데이터

사용자·캐릭터의 신청, 확정 참가, 일정 충돌 및 캐릭터 변경에 대한 제품 규칙은 `../product/PARTY_PARTICIPATION_RULES.md`를 기준으로 한다. AuthUid는 인증과 Player binding에만 사용하고, 본계정과 부계정은 모두 같은 PlayerId 소유이며 동일 사용자를 별도 파티원으로 취급하지 않는다.

```text
recruitments/{recruitmentId}
  leaderPlayerId
  raidId
  difficultyId
  raidCatalogVersion
  status
  visibility
  groupId
  approvalPolicy
  continueTogether
  manualRecruitmentEnabled
  hasAvailableSlot
  currentCycleKey
  targetCycleKey
  conditions
  schedule
  memberCount
  maxMemberCount
  dealerCount
  supportCount
  revision
  createdAt
  updatedAt
  completedAt
  completedByPlayerId

recruitments/{recruitmentId}/members/{playerId}
  playerId
  characterId
  role
  joinedAt
  joinedBy
  submittedBuildSnapshotId
  characterChangedAt
  canApproveApplications

recruitments/{recruitmentId}/applications/{playerId}
  applicantPlayerId
  characterId
  requestedRole
  status
  submittedBuildSnapshot
  approvalCount
  rejectionCount
  createdAt
  decidedAt

recruitments/{recruitmentId}/applications/{playerId}/votes/{voterPlayerId}
  voterPlayerId
  decision
  createdAt
```

신청 문서와 투표 문서는 PlayerId를 문서 ID로 사용해 같은 사용자의 중복 신청과 중복 투표를 구조적으로 방지한다.

확정 참가 충돌은 `players/{playerId}/activeRaidAssignments/{characterId_raidId}` 서버 관리 인덱스로 원자적으로 차단한다. 모집 생성, 승인 및 즉시 가입 중 최초 성공한 명령만 점유권을 얻으며 같은 캐릭터·레이드의 다른 승인 대기 신청은 자동 종료한다. 사용자 소유의 다른 게임 계정도 같은 PlayerId의 일정 충돌 검증 범위에 포함한다.

추가 모집 조건인 최소 전투력, 클리어 경험 및 최대 진행 시간은 nullable 값으로 저장한다. 값이 없으면 제한 없음이며, 카탈로그 입장 레벨과 파티 역할·직업 구성은 값과 관계없이 항상 검증한다.

### 파티 회차 완료와 개인 레이드 기록

```text
recruitments/{recruitmentId}/cycles/{cycleKey}
  status
  completedAt
  completedByPlayerId
  completionRevision
  completedMemberSnapshot
```

- 주차 경계는 `Asia/Seoul` 기준 매주 수요일 오전 6시다.
- 파티장 또는 공대장만 파티 전체 완료 명령을 호출할 수 있고 최초 성공한 한 건이 회차 완료, 당시 참가자 Snapshot, 전원의 `partyOwner` Claim·점유 해제와 사용자별 완료 이벤트를 하나의 트랜잭션으로 생성한다.
- 일반 파티원은 별도 개인 완료 명령으로 본인 탈퇴와 본인 Claim만 처리하며 방 회차를 완료시키지 않는다.
- 파티 전체 완료는 같은 주차에서 공동 취소하지 않는다. 잘못된 표시는 각 사용자가 자기 완료 기록만 해제하며, 반복 파티는 수요일 06시 새 회차 전환에서 현재 membership을 기준으로 참가 상태를 다시 구성한다.
- 서버 파티 회차 상태와 개인 캐릭터 Claim은 분리한다. 파티 전체 완료는 출처가 연결된 개인 완료를 생성하지만 책임자가 이를 전원 삭제하거나 과거 점유를 복원하는 명령은 제공하지 않는다.
- 현재 주차 개인 완료의 권위 원본은 서버 Claim이며 내 계정 체크박스와 모집 제한이 함께 사용한다. Drift 완료 히스토리의 표시 보정은 별도 로컬 Projection이다.
- 개인 주간 완료는 서버 Claim으로 관리하고 모집 생성·신청·가입·교체의 최종 강제 판정 근거로 사용한다. 상세 계약은 [`WEEKLY_RAID_CLAIM_CONTRACT.md`](../../../../../docs/architecture/WEEKLY_RAID_CLAIM_CONTRACT.md)를 따른다.
- 완료 및 기타 사용자 알림 이벤트는 28일 보관 후 TTL 삭제한다.
- 완료되지 않은 회차가 수요일 오전 6시에 도달하면 `incompleteEnded`로 종료하고 당시 참가자에게 미완료 종료 이벤트를 생성한다.
- 미완료 종료된 1회성 파티는 자동 종료하고, 반복 파티는 현재 구성을 새 회차로 승계한다.
- 종료된 1회성 파티 원본과 회차 Snapshot은 28일 후 삭제하지만 반복 파티방 Current State는 해산할 때까지 유지한다.

---


<a id="source-0009"></a>

## 발췌 9: ### groupOnly

출처: docs/architecture/BACKEND_PARTY_ARCHITECTURE.md · 원본 185~185행 · 원문 절: ### groupOnly.

Firestore Security Rules는 결과 필터가 아니므로 공개 모집글은 `recruitments`의 `visibility==public` 쿼리로 읽고, 그룹 전용 목록은 `groups/{groupId}/raidListings`처럼 경로에 그룹 ID가 있는 Projection만 `list`한다. `recruitments` list 규칙에 문서별 그룹 membership `exists`를 넣지 않는다.

<a id="source-0010"></a>

## 발췌 10: ## 7. 계정 그룹

출처: docs/architecture/BACKEND_PARTY_ARCHITECTURE.md · 원본 189~239행 · 원문 절: ## 7. 계정 그룹.

## 7. 계정 그룹

사용자가 앱 사용자 ID를 검색해 다른 사용자를 초대하고, 상대방이 수락하면 그룹 멤버가 된다.

초기 제품 정책:

- 한 사용자는 자신이 소유하는 그룹을 최대 1개 생성 가능
- 사용자는 다른 사용자의 그룹 여러 개에 가입 가능
- 그룹 멤버 수에는 제품 제한을 두지 않음
- 그룹 멤버를 단일 문서 배열에 저장하지 않고 하위 컬렉션으로 저장
- 그룹명은 검색 식별자가 아니며 초대 대상은 고유 사용자 ID로 검색
- 사용자 ID 검색 결과에는 최소 공개 프로필만 노출

한 사용자당 소유 그룹 수와 다중 그룹 가입 정책은 구현 전 변경 가능한 제품 결정이다.

```text
groups/{groupId}
  ownerPlayerId
  name
  status
  memberCount
  createdAt
  updatedAt

groups/{groupId}/members/{playerId}
  playerId
  role
  joinedAt
  invitedBy

groups/{groupId}/invites/{inviteId}
  inviterPlayerId
  inviteePlayerId
  status
  createdAt
  expiresAt
  decidedAt
```

그룹 역할의 초기 범위:

```text
GroupRole
  owner
  member
```

관리자 역할과 세부 권한은 실제 요구가 생기기 전에는 추가하지 않는다.

---


<a id="source-0011"></a>

## 발췌 11: ## 8. 그룹 초대 상태

출처: docs/architecture/BACKEND_PARTY_ARCHITECTURE.md · 원본 240~273행 · 원문 절: ## 8. 그룹 초대 상태.

## 8. 그룹 초대 상태

```text
pending
→ accepted
→ declined
→ cancelled
→ expired
```

### inviteToGroup

서버가 다음을 검증한다.

- 호출자가 그룹 소유자인가
- 대상 사용자가 존재하는가
- 자기 자신을 초대하지 않는가
- 이미 멤버가 아닌가
- 동일 그룹의 유효한 pending 초대가 없는가

### respondToGroupInvite

서버 트랜잭션이 다음을 처리한다.

- 호출자가 실제 초대 대상인가
- 초대가 pending이고 만료되지 않았는가
- 수락 시 멤버 문서 생성
- 그룹 memberCount 증가
- 초대 상태 accepted 변경

그룹 인원 제한은 없지만 Firestore 안전 한도와 비용을 위해 멤버 목록은 페이지 단위로 조회한다.

---


<a id="source-0012"></a>

## 발췌 12: ## 10. 목록 노출과 신청 검증

출처: docs/architecture/BACKEND_PARTY_ARCHITECTURE.md · 원본 317~317행 · 원문 절: ## 10. 목록 노출과 신청 검증.

목록은 Firestore에서 인덱스 가능한 넓은 후보를 조회한다. 파티방 상태와 주차별 회차 상태를 분리하고, 반복 파티 완료 후 모집은 다음 회차를 대상으로 한다.

<a id="source-0013"></a>

## 발췌 13: ## 11. Firestore Transaction 명령 경계

출처: docs/architecture/BACKEND_PARTY_ARCHITECTURE.md · 원본 336~366행 · 원문 절: ## 11. Firestore Transaction 명령 경계.

## 11. Firestore Transaction 명령 경계

초기 명령 목록:

- `createRecruitment`
- `updateRecruitment`
- `setRecruitmentEnabled`
- `setContinueTogether`
- `applyToRecruitment`
- `withdrawApplication`
- `voteOnApplication`
- `setApprovalPermission`
- `removePartyMember`
- `changePartyCharacter`
- `movePartyCharacter`
- `swapPartyCharacters`
- `completeRecruitment`
- `cancelRecruitmentCompletion`
- `leaveParty`
- `disbandParty`
- `transitionWeeklyCycle`
- `createGroup`
- `inviteToGroup`
- `respondToGroupInvite`
- `leaveGroup`
- `removeGroupMember`

읽기 모델은 Firestore 실시간 리스너를 사용하고, 상태를 변경하는 명령은 `FIRESTORE_PARTY_COMMAND_CONTRACT.md`의 클라이언트 Transaction 계약을 따른다.

---


<a id="source-0014"></a>

## 발췌 14: ## 12. Security Rules 기준

출처: docs/architecture/BACKEND_PARTY_ARCHITECTURE.md · 원본 367~379행 · 원문 절: ## 12. Security Rules 기준.

## 12. Security Rules 기준

- 인증된 사용자만 허용된 범위 읽기 가능
- 사용자는 자신의 공개 프로필만 제한적으로 수정 가능
- 모집글 파생 필드는 명령별 Transaction과 `getAfter()` 조건을 만족할 때만 쓰기 가능
- 파티 멤버십, 신청 상태와 확정 점유는 인증된 호출 주체와 허용된 상태 전이를 모두 검증
- 그룹 소유자, 멤버 및 초대 상태 직접 쓰기 금지
- groupOnly 모집글은 현재 그룹 멤버만 읽기 가능
- 서버 전용 권한이 필요한 명령은 Spark 범위에서 금지
- Firestore Emulator는 사용하지 않으며 Rules 배포 전 검증 방법은 별도 합의

---


<a id="source-0015"></a>

## 발췌 15: ## 13. 기능 단위 설계와 단계적 구현 순서

출처: docs/architecture/BACKEND_PARTY_ARCHITECTURE.md · 원본 380~402행 · 원문 절: ## 13. 기능 단위 설계와 단계적 구현 순서.

## 13. 기능 단위 설계와 단계적 구현 순서

```text
1. Firebase Core 초기화와 Anonymous Auth 부트스트랩 정책
2. AuthUid와 PlayerId binding
3. GameAccountId·CharacterId 데이터 계약과 서버 Character 소유 검증
4. 파티방, 주차별 회차, 완료 Snapshot과 다음 회차 준비 구성
5. 사용자별 이벤트, 전체·방별 알림 설정과 28일 TTL
6. Firestore 실시간 읽기 모델과 인덱스
7. Spark 클라이언트 Transaction 명령
8. Security Rules 및 다중 사용자·동시성 테스트
9. 로컬 레이드 히스토리와 캐릭터별 표시 설정 연결
10. Firebase 연결 후 다중 계정·다중 디바이스 실기기 테스트
11. App Check
12. 후속 평가와 확장 알림
```

기존 로컬 Domain, 상태 머신, Fake Session과 Repository 테스트는 Firebase 서버 규칙의 기준 자산으로 유지한다. 승인 화면의 실제 다중 사용자 실기기 검증은 Firebase Authentication과 서버 명령 연결 후 진행한다. 동일 계정 캐릭터를 서로 다른 사용자처럼 사용하는 로컬 실기기 시나리오는 만들지 않는다.

`내 파티`는 별도 서버 상태를 복제하지 않고 현재 Player의 모집 소유권, 승인된 멤버십 및 승인 대기 신청을 조합한 읽기 모델이다. 화면에서는 `참여 중 / 내가 만든 파티 / 신청 중`을 구분하며, 승인 대기 신청은 승인된 멤버십으로 취급하지 않는다.

각 단계는 관련 계약과 검증 범위를 해당 구현 브랜치에서 먼저 확정하고 독립적으로 병합할 수 있는 크기로 진행한다. 전체 단계의 상세 설계가 끝날 때까지 구현을 보류하지 않으며, 아직 계약이 없는 후속 기능만 구현하지 않는다. 서로 강하게 연결된 Domain·상태 머신·UI는 같은 작업 흐름에서 이어서 다룬다. 실물 디바이스 확인이 필요한 작업은 최신 APK를 빌드할 수 있는 정확한 브랜치와 테스트 체크리스트를 사용자에게 전달하고, 사용자가 직접 빌드·설치해 결과를 회신한다.
