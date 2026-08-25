# Firestore 파티 읽기 모델 계약

## 1. 목적과 적용 범위

이 문서는 `레이드 모집`, `레이드 현황 > 진행 중`, `레이드 현황 > 신청 중`에 필요한 Firestore 읽기 계약을 정의한다.

이 작업은 읽기 전용 DTO·Mapper·Repository 경계까지 다룬다. 실행 앱 쓰기 전환 상태는 `FIRESTORE_PARTY_COMMAND_CONTRACT.md` §9를 따른다. 모집 생성·신청·철회는 Firestore 명령으로 연결됐으며, 승인·멤버·회차와 `레이드 모집` 공개 목록 UI는 아직 Fake다. `watchPublicRecruitments` Repository는 있으나 실행 앱 목록에 미연결이다.

`완료 기록`은 개인 로컬 기록이 단일 기준이므로 이 계약의 Firestore 목록 쿼리에 포함하지 않는다.

## 2. 기준 식별자와 시간

- 인증은 `AuthUid`, 파티 조회와 권한 판정은 binding으로 확정한 `PlayerId`를 사용한다.
- `cycleKey`는 `Asia/Seoul` 매주 수요일 06:00 기준 시작일을 `yyyy-MM-dd`로 저장한다.
- 서버 공유 시간은 Firestore Timestamp로 저장하고 서버 시간을 기준으로 한다.
- 모든 읽기 모델은 `schemaVersion == 1`을 요구하고 알 수 없는 버전을 정상 데이터로 유출하지 않는다.

## 3. 모집 Current State

```text
recruitments/{recruitmentId}
  schemaVersion: 1
  title
  leaderPlayerId
  memberPlayerIds[]
  raidCatalogVersion
  raidId
  difficultyId
  raidNameSnapshot
  difficultyNameSnapshot
  difficultyAliasSnapshot
  gateCount
  minItemLevel
  minCombatPower
  experienceLevel
  maxPlayHours
  raidStartAt
  status
  visibility
  groupId
  approvalPolicy
  continueTogether
  manualRecruitmentEnabled
  hasAvailableSlot
  currentCycleKey
  targetCycleKey
  memberCount
  maxMemberCount
  revision
  createdAt
  updatedAt
```

`memberPlayerIds`는 `members` 서브컬렉션의 서버 관리 파생 필드다. 별도의 내 파티 문서를 복제하지 않고 `array-contains playerId`로 확정 참가 방을 실시간 조회하기 위해 둔다. 클라이언트는 이 필드를 직접 쓰지 못한다.

`raidNameSnapshot`과 난이도 표시 Snapshot은 카탈로그 갱신 후에도 기존 모집의 표시 의미를 보존한다. 신청 조건 검증은 ID와 버전 기준 카탈로그를 다시 사용한다.

## 4. 멤버와 신청

```text
recruitments/{recruitmentId}/members/{playerId}
  schemaVersion: 1
  playerId
  characterId
  characterNameSnapshot
  classNameSnapshot
  role
  partyIndex
  joinedAt
  joinedBy
  submittedBuildSnapshotId
  characterChangedAt
  canApproveApplications
  updatedAt

recruitments/{recruitmentId}/applications/{playerId}
  schemaVersion: 1
  recruitmentId
  applicantPlayerId
  cycleKey
  characterId
  characterNameSnapshot
  classNameSnapshot
  requestedRole
  submittedBuildSnapshot
  status
  resolutionReason
  approvalCount
  rejectionCount
  createdAt
  decidedAt
  updatedAt
```

신청 문서 ID는 `PlayerId`로 유지해 같은 방에 한 사용자의 중복 신청을 구조적으로 차단한다. `recruitmentId`, `applicantPlayerId`, `cycleKey`, `updatedAt`은 collection group 조회와 오프라인 정렬을 위한 명시적 필드다.

## 5. 화면별 쿼리

### 레이드 모집—공개

```text
collection: recruitments
where schemaVersion == 1
where visibility == public
where status == active
where manualRecruitmentEnabled == true
where hasAvailableSlot == true
where targetCycleKey == currentCycleKey
orderBy updatedAt desc
```

그룹 전용 모집은 공개 쿼리와 합치지 않고 현재 그룹 ID별 쿼리로 분리한다.

### 레이드 현황—진행 중

다음 두 실시간 쿼리를 ID로 합친다.

1. `leaderPlayerId == currentPlayerId`, `status == active`
2. `memberPlayerIds array-contains currentPlayerId`, `status == active`

두 쿼리에 모두 들어온 방은 `recruitmentId`로 중복 제거한다. `raidStartAt`이 있는 방을 먼저 오는 순서로 표시하고 같으면 `updatedAt desc`, `recruitmentId`로 안정 정렬한다.

### 레이드 현황—신청 중

```text
collectionGroup: applications
where schemaVersion == 1
where applicantPlayerId == currentPlayerId
where cycleKey == currentCycleKey
orderBy updatedAt desc
```

`pending`은 목록 상단에 표시하고 `rejected`, `withdrawn`, `superseded`는 최근 처리 결과로 구분한다. 모집 종료로 닫힌 신청은 `superseded` 상태와 `resolutionReason == recruitmentClosed`로 구분한다. `approved`는 확정 참가로 전환되므로 신청 중 목록에 남기지 않고 진행 중 membership을 기준으로 한다.

## 6. Repository 경계

읽기 계약은 기존 쓰기 중심 `RecruitmentStateRepository`에 추가하지 않는다.

```text
PartyReadRepository
  watchPublicRecruitments(cycleKey)
  watchActiveRaids(playerId)
  watchApplications(playerId, cycleKey)
  watchRecruitment(recruitmentId)
```

- `watchRecruitment`은 `PartyReadDetailSnapshot`을 반환한다. 문서 누락은 `item == null`이고, 캐시 여부는 목록과 같이 `isFromCache`로 전달한다. 누락을 권한 오류와 구분하려면 존재하지 않는 모집의 단건 `get`이 active binding만으로 허용되어야 한다.
- `레이드 현황`의 진행 중·신청 중 목록은 `/raid-status/:recruitmentId` 읽기 전용 상세로 들어가며, Fake 쓰기 `RecruitmentDetailPage`와 경로·데이터를 섞지 않는다.
- Domain Entity는 Firestore 타입을 import하지 않는다.
- Firestore Timestamp·DocumentSnapshot 변환은 data 계층에서 종료한다.
- 문서 누락은 상세 조회에서 `null`, 목록에서 제외로 처리한다.
- 필수 필드 누락, 잘못된 enum·시간·숫자, 알 수 없는 스키마 버전은 데이터 계약 오류로 구분한다.
- Repository는 실시간 Stream을 제공하고 소비자가 dispose할 때 리스너를 해제한다.

## 7. 로딩·오류·오프라인

- 첫 snapshot 전까지 loading을 표시한다.
- 첫 snapshot이 빈 목록이면 빈 상태로 표시한다.
- `permission-denied`는 세션 또는 권한 준비 오류, `unavailable`은 일시적 연결 오류, Mapper 실패는 데이터 계약 오류로 구분한다.
- Firestore 로컬 캐시 snapshot은 정상 목록으로 제공하되 `isFromCache`를 읽기 상태에 함께 전달해 UI가 오프라인 안내를 표시할 수 있게 한다.
- `isFromCache`를 UI에 노출하므로 모든 읽기 stream은 `snapshots(includeMetadataChanges: true)`로 구독한다. 목록이 비어 있으면 캐시에서 서버로 바뀔 때 문서 집합이 동일해 메타데이터 변화만 발생하고, 이 옵션이 없으면 오프라인 안내가 사라지지 않는다.
- 기존 성공 목록이 있는 상태에서 후속 stream 오류가 발생하면 목록을 즉시 지우지 않고 오류 상태를 함께 표시한다.

### 7.1 로컬 Projection과 최신화 기준

- 파티 Current State의 최종 진실 공급원은 Firestore이며 로컬 데이터는 목록 표시, 후보 계산과 예상 결과 안내를 위한 Projection이다.
- 모집 목록 조회, 신청·가입·승인 결과 수신, 관련 알림 진입과 파티 상세 진입 시 서버 snapshot을 받아 로컬 Projection을 최신화한다.
- 내가 확정 가입한 파티의 캐릭터 변경·이동·스왑 후보는 마지막으로 최신화된 로컬 Projection을 기반으로 계산한다.
- 사용자가 명령을 확정하면 로컬 판정을 최종 권한으로 사용하지 않는다. 서버 Transaction이 관련 파티 revision과 조건을 다시 읽고 검증하며, 충돌하면 어떤 파티도 일부 변경하지 않고 최신 snapshot을 다시 동기화한다.
- 알림은 최신화 계기일 뿐 데이터 변경의 단일 진실 공급원이 아니다. 알림을 놓쳐도 화면 진입과 stream 재연결로 복구할 수 있어야 한다.
- Firestore SDK 영속 캐시만 사용할지 Drift에 별도 파티 Projection을 저장할지, 캐시 보존 기간·삭제·계정 전환·오프라인 명령 정책은 실행 앱 Repository 전환 전에 별도 설계로 확정한다.

## 8. Security Rules 원칙

- 모든 조회는 유효한 `AuthUid -> PlayerId` binding을 요구한다.
- `public` 모집은 로그인된 사용자가 계약된 공개 쿼리로 목록·상세를 읽을 수 있다.
- `groupOnly` 모집은 해당 그룹 멤버만 읽을 수 있다. 그룹 멤버십 계약 전에는 실행 앱에 연결하지 않는다.
- 비공개 멤버·신청 정보는 해당 방의 현재 멤버 또는 해당 신청자만 읽을 수 있다.
- 모집 생성은 허용된 생성 Transaction과 Rules만 사용한다. 신청·멤버·회차 쓰기는 실행 앱에 아직 연결하지 않는다.
- `신청 중` collection group 쿼리는 중첩 경로 규칙이 적용되지 않으므로 `match /{path=**}/applications/{applicantPlayerId}` 재귀 와일드카드 규칙이 반드시 필요하다. 이 규칙은 `list`만 허용하고 `resource.data.applicantPlayerId == currentPlayerId()`로 본인 신청에 한정한다. 단건 조회와 방 멤버의 신청 열람은 기존 중첩 경로 규칙이 계속 담당한다.
- 모집 단건 `get`은 문서가 없으면 active binding만으로 허용하고, 문서가 있으면 `canReadRecruitment`을 적용한다. `list`는 존재하는 문서만 다루므로 기존 공개·멤버 조건을 유지한다. 생성 Transaction과 상세의 문서 누락 상태가 이 분기를 사용한다.
- Rules와 쿼리는 Emulator Suite에서 공개 목록, 자기 멤버십, 자기 신청, 타인 비공개 데이터 차단을 같이 검증한 후 배포한다.

## 9. 필요 인덱스

- `recruitments`: `visibility, status, manualRecruitmentEnabled, hasAvailableSlot, targetCycleKey, schemaVersion, updatedAt desc`
- `recruitments`: `leaderPlayerId, status, schemaVersion`
- `recruitments`: `memberPlayerIds array-contains, status, schemaVersion`
- `applications` collection group: `applicantPlayerId, cycleKey, schemaVersion, updatedAt desc`

인덱스는 실제 Repository 쿼리와 동일한 필드·정렬 순서로 `firestore.indexes.json`에 반영한다. 위 4개 복합 인덱스는 `lost-party`에 배포되어 있다.

## 10. 전환 조건

실행 앱의 목록을 Firestore Repository로 전환하려면 다음이 모두 필요하다.

1. 파티 생성·신청·철회·승인 서버 명령이 같은 스키마를 쓴다.
2. `memberPlayerIds`와 카운트 파생 필드를 서버 Transaction이 원자적으로 갱신한다.
3. Security Rules와 복합 인덱스가 Emulator 검증을 통과한다.
4. 기존 로컬 생성·수정 데이터의 이행 또는 폐기 정책을 확정한다.
5. 다중 사용자 실기기 시나리오를 통과한다.
