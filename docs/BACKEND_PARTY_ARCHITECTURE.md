# Backend, Party Recruitment and Account Group Architecture

## 1. 목적

LOSTPARTY의 정적 레이드 기준정보, 멀티유저 파티 모집/신청/승인 및 계정 그룹 전용 모집글을 구현하기 위한 기준 아키텍처다.

클라이언트가 화면과 요청을 담당하고, 가입 승인과 정원 변경 같은 최종 상태 전이는 서버가 원자적으로 결정한다.

---

## 2. 권장 기술 구성

```text
Flutter
→ Firebase Authentication
→ Cloud Firestore
→ Callable Cloud Functions 2nd gen
→ Firestore Transaction
→ Firebase App Check
```

- Firebase Authentication: 앱 사용자 UID와 로그인 수명 관리
- Cloud Firestore: 모집글, 신청, 파티원, 그룹 및 초대의 실시간 읽기 모델
- Callable Cloud Functions: 모집 생성, 신청, 투표, 승인, 그룹 초대/수락 등 권한이 필요한 명령 처리
- Firestore Transaction: 정원, 역할별 자리, 투표 수 및 가입 상태의 동시성 보장
- Security Rules: 모바일 클라이언트의 직접 쓰기 제한과 읽기 권한 검증
- App Check: 변조 앱과 비정상 요청 완화
- Firebase Cloud Messaging: 후속 알림 기능에서 사용하며 초기 구현 범위에는 포함하지 않음

현재 단계에서는 별도 애플리케이션 서버보다 Firebase 구성이 개발 및 운영 비용에 적합하다. Repository 경계를 유지해 향후 별도 REST 서버로 교체할 수 있게 한다.

---

## 3. 신뢰 경계

클라이언트는 다음 서버 관리 필드를 직접 수정할 수 없다.

- 파티장 UID
- 가입 승인 상태
- 파티원 목록과 현재 인원
- 역할별 현재/남은 자리
- 승인/거절 투표 수
- 모집 마감 상태
- 그룹 소유자와 멤버십 상태
- 그룹 초대의 최종 수락 상태

Flutter 앱은 Callable Function에 명령만 전달한다. Function은 인증, 권한, 현재 상태, 정원 및 조건을 다시 확인한 후 트랜잭션으로 저장한다.

Lost Ark 캐릭터 정보도 클라이언트 제출값을 최종 신뢰하지 않는다. 강제 가입 조건에 사용하려면 서버가 조회하거나 검증한 캐릭터 스냅샷이 필요하다. 서버 검증 전 단계의 조건은 참고용으로 표시한다.

---

## 4. 정적 레이드 카탈로그

Lost Ark API가 레이드 기준정보를 제공하지 않으므로 다음 정보는 Git으로 버전 관리하는 JSON 카탈로그에 수기 입력한다.

- 레이드 ID와 표시명
- 난이도와 정렬 순서
- 관문 수와 파티 정원
- 최소 아이템 레벨
- 역할 구성 기본값
- 보상 정보
- 활성/비활성 상태와 데이터 버전

Flutter와 Functions가 동일한 원본 카탈로그 또는 같은 원본에서 생성한 산출물을 사용한다.

모집글은 임의의 레이드 속성을 신뢰하지 않고 `raidId`, `difficultyId`, `raidCatalogVersion`을 저장한다. 서버는 모집 생성 시 카탈로그를 이용해 관문, 정원 및 최소 레벨을 검증한다.

---

## 5. 파티 모집 데이터

사용자·캐릭터의 신청, 확정 참가, 일정 충돌 및 캐릭터 변경에 대한 제품 규칙은 `PARTY_PARTICIPATION_RULES.md`를 기준으로 한다. 본계정과 부계정은 모두 같은 Firebase UID 소유이며 동일 사용자를 별도 파티원으로 취급하지 않는다.

```text
recruitments/{recruitmentId}
  leaderUid
  raidId
  difficultyId
  raidCatalogVersion
  status
  visibility
  groupId
  approvalPolicy
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
  completedByUid

recruitments/{recruitmentId}/members/{uid}
  uid
  characterId
  role
  joinedAt
  joinedBy
  submittedBuildSnapshotId
  characterChangedAt

recruitments/{recruitmentId}/applications/{uid}
  applicantUid
  characterId
  requestedRole
  status
  submittedBuildSnapshot
  approvalCount
  rejectionCount
  createdAt
  decidedAt

recruitments/{recruitmentId}/applications/{uid}/votes/{voterUid}
  voterUid
  decision
  createdAt
```

신청 문서와 투표 문서는 UID를 문서 ID로 사용해 같은 사용자의 중복 신청과 중복 투표를 구조적으로 방지한다.

확정 참가 충돌은 `users/{uid}/activeRaidAssignments/{characterId_raidId}` 서버 관리 인덱스로 원자적으로 차단한다. 모집 생성, 승인 및 즉시 가입 중 최초 성공한 명령만 점유권을 얻으며 같은 캐릭터·레이드의 다른 pending 신청은 자동 종료한다. 사용자 소유의 다른 게임 계정도 같은 UID의 일정 충돌 검증 범위에 포함한다.

추가 모집 조건인 최소 전투력, 클리어 경험 및 최대 진행 시간은 nullable 값으로 저장한다. 값이 없으면 제한 없음이며, 카탈로그 입장 레벨과 파티 역할·직업 구성은 값과 관계없이 항상 검증한다.

### 주간 레이드 완료 기록

```text
users/{uid}/characters/{characterId}/weeklyRaidClears/{resetWeekKey_raidId}
  resetWeekKey
  raidId
  completedDifficultyId
  recruitmentId
  completedAt
  completedByUid
```

- 주차 경계는 `Asia/Seoul` 기준 매주 수요일 오전 6시다.
- 귀속은 캐릭터와 레이드 단위이며 같은 레이드의 모든 난이도가 한 주간 귀속을 공유한다.
- 승인된 파티원 누구나 완료 명령을 호출할 수 있고 최초 성공한 한 건이 파티 완료와 당시 멤버 전원의 주간 완료 기록을 하나의 트랜잭션으로 생성한다.
- 완료 이후의 중복 완료, 새 가입 승인 및 캐릭터 교체는 거절한다.

---

## 6. 모집글 공개 범위

```text
RecruitmentVisibility
  public
  groupOnly
```

### public

- 로그인 사용자에게 공개
- 목록 후보 조회 후 앱에서 캐릭터별 조건을 표시 필터링
- 신청 시 서버가 모든 조건을 다시 검증

### groupOnly

- 모집글의 `groupId`에 가입된 현재 멤버만 조회 가능
- 모집 생성자도 해당 그룹의 현재 멤버여야 함
- 목록 조회뿐 아니라 상세 조회와 신청 시점에도 멤버십을 다시 검증
- 그룹 탈퇴 또는 추방 후에는 새 조회와 신청 권한을 잃음
- 이미 파티에 가입된 사용자의 처리 정책은 파티 멤버십을 우선하며 자동 퇴장시키지 않음

Firestore Security Rules는 결과 필터가 아니므로 공개 모집글 쿼리와 그룹 전용 쿼리를 분리하고, 쿼리 조건이 읽기 규칙과 일치하도록 설계한다.

---

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
  ownerUid
  name
  status
  memberCount
  createdAt
  updatedAt

groups/{groupId}/members/{uid}
  uid
  role
  joinedAt
  invitedBy

groups/{groupId}/invites/{inviteId}
  inviterUid
  inviteeUid
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

## 9. 파티 가입 승인 정책

```text
ApprovalMode
  leaderOnly
  directJoin
  anyMember
  quorum

ApprovalPolicy
  mode
  requiredApprovals
  leaderVoteRequired
  rejectionMode
```

- `leaderOnly`: 파티장만 승인/거절
- `directJoin`: 신청 조건을 만족하면 별도 승인 없이 같은 명령에서 즉시 가입
- `anyMember`: 현재 파티원 한 명의 승인으로 가입
- `quorum`: 서로 다른 현재 파티원 N명의 승인으로 가입
- 비율 기반 동의는 파티원 수 변경에 따라 의미가 달라지므로 초기 범위에서 제외

초기 제품의 신규 모집 생성 화면은 `leaderOnly`와 `directJoin`만 제공한다. `anyMember`와 `quorum`은 기존 Domain/저장 데이터 호환을 위해 유지하지만 신규 선택지는 노출하지 않는다.

승인 Function은 인증, 승인 권한, 신청 상태, 중복 투표, 전체 정원, 역할별 자리, 가입 조건 및 승인 수를 한 트랜잭션에서 검증한다.

기준을 만족하면 같은 트랜잭션에서 신청서 승인, 멤버 생성, 전체/역할별 인원 및 모집 상태를 갱신한다.

### 승인 후 캐릭터 교체

- 현재 파티원은 완료 전까지 자기 멤버 문서의 캐릭터만 교체 요청할 수 있다.
- 승인된 역할과 파티 위치는 유지한다.
- 서버는 캐릭터 소유권, 역할 세팅, 카탈로그 입장 레벨, 주간 귀속, 선택 모집 조건 및 동일 딜러 직업 제한을 최신 값으로 재검증한다.
- 교체 후 전체 파티 구성이 유효할 때만 추가 승인 없이 한 트랜잭션으로 멤버 스냅샷을 교체한다.
- 같은 사용자의 본계정과 부계정 캐릭터를 모두 후보로 사용할 수 있다.
- 대상 캐릭터의 같은 레이드 pending 신청은 사용자 확인 후 철회와 교체를 하나의 서버 명령으로 처리한다.
- 대상 캐릭터가 다른 파티에 확정 참가 중이면 단순 교체와 구분해 `이동` 또는 양쪽 파티 조건을 모두 만족하는 `스왑` 명령으로 처리한다.
- 초기 구현은 pending 철회 후 변경을 우선하고, 확정 파티 간 이동·스왑은 다중 문서 트랜잭션과 탈퇴 정책 구현 후 제공한다.

---

## 10. 목록 노출과 신청 검증

목록은 Firestore에서 인덱스 가능한 넓은 후보를 조회한다.

```text
status == recruiting
visibility == public
raidId == selectedRaidId
startAt >= now
```

그룹 전용 목록은 사용자의 현재 그룹 ID별 쿼리 또는 서버가 제공하는 읽기 모델로 조회한다.

아이템 레벨, 역할 자리, 숙련도 및 캐릭터별 지원 가능 여부는 앱에서 표시 필터링할 수 있지만, 신청 성공을 보장하지 않는다. 서버가 신청 시 최신 모집 상태와 검증된 캐릭터 스냅샷으로 다시 판정한다.

---

## 11. Callable Function 명령 경계

초기 명령 목록:

- `createRecruitment`
- `updateRecruitment`
- `closeRecruitment`
- `applyToRecruitment`
- `withdrawApplication`
- `voteOnApplication`
- `changePartyCharacter`
- `movePartyCharacter`
- `swapPartyCharacters`
- `completeRecruitment`
- `leaveParty`
- `createGroup`
- `inviteToGroup`
- `respondToGroupInvite`
- `leaveGroup`
- `removeGroupMember`

읽기 모델은 Firestore 실시간 리스너를 사용하고, 상태를 변경하는 명령은 Function을 사용한다.

---

## 12. Security Rules 기준

- 인증된 사용자만 허용된 범위 읽기 가능
- 사용자는 자신의 공개 프로필만 제한적으로 수정 가능
- 모집글의 서버 관리 필드 직접 쓰기 금지
- 파티 멤버, 신청 승인, 투표 집계 직접 쓰기 금지
- 그룹 소유자, 멤버 및 초대 상태 직접 쓰기 금지
- groupOnly 모집글은 현재 그룹 멤버만 읽기 가능
- Functions 서버 SDK의 쓰기는 Function 내부 인증/권한 검사와 IAM으로 보호
- Rules와 Function은 Emulator Suite에서 함께 테스트

---

## 13. 구현 단계

```text
1. 레이드 정적 카탈로그 구조와 검증 규칙
2. 실제 레이드 카탈로그 데이터 입력
3. 모집 조건과 가입 승인 정책 Domain 모델
4. 신청·투표·가입 상태 머신
5. FakeUserSession, Fake Repository, Fake Clock/ID 기반 다중 사용자 환경
6. 로컬 모집 목록과 상세 UI
7. 로컬 모집 생성 UI
8. 로컬 신청 UI
9. 로컬 승인·투표·파티 구성 UI
10. 승인 후 캐릭터 교체 Domain과 UI
11. 파티 완료 선언과 주간 레이드 완료 Domain 및 UI
12. 하단 `내 파티` 탭과 창설·가입·신청 중 파티 조회 UI
13. 계정 그룹 Domain, Fake Repository 및 그룹 UI
14. 공개/그룹 전용 모집과 `내 파티`를 포함한 로컬 통합 시나리오 테스트 및 실기기 검증
15. Firebase 프로젝트와 Authentication
16. Firestore 읽기 모델
17. Callable Functions 명령과 Transaction
18. Security Rules 및 Emulator 다중 사용자 테스트
19. Firebase 연결 후 다중 계정 실기기 테스트
20. App Check
21. 후속 알림
```

Firebase 연결 전에는 모집 생성·신청·교체 규칙을 자동화 테스트로 검증한다. 승인 화면의 실제 다중 사용자 실기기 검증은 Firebase Authentication과 서버 명령 연결 후 진행한다. 동일 계정 캐릭터를 서로 다른 사용자처럼 사용하는 로컬 실기기 시나리오는 만들지 않는다. 로컬 단계와 Firebase 단계는 같은 Domain 및 Repository 계약을 사용하고 구현체만 교체한다.

`내 파티`는 별도 서버 상태를 복제하지 않고 현재 사용자의 모집 소유권, 승인된 멤버십 및 pending 신청을 조합한 읽기 모델이다. 화면에서는 `참여 중 / 내가 만든 파티 / 신청 중`을 구분하며, pending 신청은 승인된 멤버십으로 취급하지 않는다. 이 조회 계약도 로컬 Fake에서 먼저 확정한 뒤 Firestore 읽기 모델로 교체한다.

각 단계는 독립 작업 그룹으로 나눌 수 있지만, 서로 강하게 연결된 Domain·상태 머신·UI는 같은 채팅에서 이어서 작업해 문서 재탐색 비용을 줄인다. 실물 디바이스 확인이 필요한 작업은 최신 APK를 빌드할 수 있는 정확한 브랜치와 테스트 체크리스트를 사용자에게 전달하고, 사용자가 직접 빌드·설치해 결과를 회신한다.

