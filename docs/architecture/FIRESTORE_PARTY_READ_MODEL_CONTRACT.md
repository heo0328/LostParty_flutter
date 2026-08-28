# Firestore 파티 읽기 모델 계약

## 1. 목적과 적용 범위

이 문서는 `레이드 모집`, `레이드 현황 > 진행 중`, `레이드 현황 > 신청 중`에 필요한 Firestore 읽기 계약을 정의한다.

이 작업은 읽기 DTO·Mapper·Repository 경계까지 다룬다. 실행 앱 쓰기 전환 상태는 `FIRESTORE_PARTY_COMMAND_CONTRACT.md` §9를 따른다. 모집 생성·신청·철회·즉시 가입·승인·거절·방 단위 재신청·단독 모집 삭제·고정 슬롯·참가 캐릭터 변경·탈퇴·추방·회차 완료/취소/전환·다인 해산과 공개 목록·현황 상세 읽기는 Firestore로 연결됐다.

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
  leaderCharacterNameSnapshot
  leaderClassNameSnapshot
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

`leaderCharacterNameSnapshot`과 `leaderClassNameSnapshot`은 공개 목록과 진행 중 목록에서 Card별 membership 추가 조회 없이 파티장을 표시하기 위한 파생 Snapshot이다. 파티 생성 시 파티장 membership과 같은 값으로 기록하고, 파티장 캐릭터 변경과 책임자 승계 시 모집 문서와 membership을 같은 Transaction에서 갱신한다. `leaderPlayerId`는 권한 판정용이며 UI에는 노출하지 않는다.

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
  slotIndex
  joinedAt
  joinedBy
  submittedBuildSnapshotId
  itemLevelSnapshot
  combatPowerSnapshot
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

`partyIndex`는 0부터 시작하는 파티 번호이고 `slotIndex`는 해당 파티 안에서 0부터 시작하는 자리 번호다. 현재 배포 데이터와 실행 코드는 `partyIndex`만 저장하므로 같은 파티 멤버가 모두 첫 자리로 표시되는 문제가 있으며, `slotIndex`는 다음 작업에서 이행·쓰기·Rules를 함께 반영할 예정 필드다. 이행 완료 전에는 `partyIndex`만으로 실제 자리 번호를 추정하지 않는다.

4인 레이드는 `partyIndex == 0`, `slotIndex == 0..3`, 8인 레이드는 `partyIndex == 0..1`, 각 `slotIndex == 0..3`을 사용한다. `partyIndex == 0 && slotIndex == 0`은 항상 파티장이고 8인에서는 공대장을 겸한다.

상세의 파티원 필수 표시는 `characterNameSnapshot`, `classNameSnapshot`, `role`, `partyIndex`, `slotIndex`, `itemLevelSnapshot`, `combatPowerSnapshot`을 사용한다. `playerId`, `joinedBy`, `canApproveApplications`와 내부 식별자는 공개 표시 정보가 아니다. Snapshot 값이나 이행 전 `slotIndex`가 없을 수 있는 데이터는 계약 오류로 전체 상세를 막지 않고 `정보 없음` 또는 명시적인 이행 필요 상태로 처리한다.

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
orderBy documentId desc
limit 20
```

그룹 전용 모집은 공개 쿼리와 합치지 않고 현재 그룹 ID별 쿼리로 분리한다.

#### 현재 사용자의 방 제외 — Task-082 확정

- 공개 탐색에서는 `leaderPlayerId == currentPlayerId`이거나 `memberPlayerIds`에 현재 PlayerId가 포함된 `active` 모집을 제외한다. 정상 데이터에서 책임자는 멤버 배열에도 포함되지만 데이터 이상과 계약 명확성을 위해 두 조건을 모두 검사한다.
- 신청 문서만 `pending`인 모집은 공개 목록에 유지한다. 승인되어 membership이 생성되면 제외하며 `rejected`·`withdrawn` 모집도 나머지 공개 조건을 만족하면 유지한다. 신청 상태 표시는 별도 UI 범위다.
- Firestore는 `memberPlayerIds array-not-contains currentPlayerId` 쿼리를 제공하지 않으므로 서버 쿼리에는 부정 조건을 추가하지 않는다. Repository의 data 계층에서 원문 `leaderPlayerId`·`memberPlayerIds`를 검사하고 제외한 뒤 공개 Domain 모델로 변환한다.
- `memberPlayerIds` 전체를 `PublicRecruitmentSummary` 또는 presentation 계층에 새로 노출하지 않는다. Rules는 쿼리 결과 필터가 아니며 이번 작업에서 변경하지 않는다.
- 가입 승인, 탈퇴, 책임자 승계가 첫 페이지 snapshot에 반영되면 같은 제외 판정을 다시 적용한다. 진행 중 목록은 기존의 책임자/멤버 쿼리를 그대로 단일 기준으로 사용한다.

#### 공개 목록 페이징

- 페이지 크기 20은 필터 전 Firestore 문서 수 기준으로 고정한다. 내 방 제외 후 화면 항목이 20개보다 적을 수 있다.
- 첫 페이지는 위 쿼리를 `includeMetadataChanges: true`로 실시간 구독한다.
- 다음 페이지는 마지막 문서 cursor에 `startAfter`를 적용해 같은 필터·정렬로 20개를 일회성 조회한다.
- 추가 페이지마다 listener를 만들지 않는다. 최신 첫 페이지만 실시간이며 이전 항목은 사용자가 불러온 시점의 결과다.
- `updatedAt`이 같은 문서 사이에서도 페이지 순서가 바뀌지 않도록 문서 ID desc를 보조 정렬로 사용한다.
- 페이지 결과는 항목, Repository 전용 다음 cursor, `hasMore`, 캐시 여부를 포함한다. Firestore `DocumentSnapshot` 타입은 data 계층 밖으로 노출하지 않는다.
- 소비자는 `recruitmentId`로 페이지를 병합하고 같은 ID가 있으면 최신 첫 페이지 snapshot을 우선한다.
- 추가 결과가 페이지 크기보다 작거나 다음 cursor가 없으면 `hasMore == false`다.
- 첫 페이지 항목의 내용만 바뀌고 ID 집합이 같으면 추가 페이지를 유지한다. 새 모집 유입·필터 제외 등으로 첫 페이지 ID 집합이 바뀌면 사라진 이유를 안전하게 구분할 수 없으므로 추가 페이지와 cursor를 초기화하고 새 경계에서 다시 조회한다.
- 명시적 새로고침은 첫 페이지 listener와 추가 페이지, cursor, 추가 오류를 모두 초기화한다.
- 다음 페이지는 별도 `더 보기` 버튼이 아니라 기존 목록 하단 240px 접근 시 자동 로딩한다. 추가 조회가 실패한 경우에만 하단 `다시 시도` 버튼을 표시한다.
- 내 방 제외 결과가 0개이고 다음 cursor가 있어 목록에 스크롤 영역이 생기지 않으면 시작 또는 갱신 한 번당 최대 3페이지까지 자동 보충한다. 3페이지 뒤에도 표시 항목이 없고 `hasMore == true`이면 무제한 연속 읽기를 하지 않는다.
- 필터 후 첫 페이지 ID 집합이 바뀌면 추가 페이지와 cursor를 초기화한다. 첫 페이지와 추가 페이지는 같은 제외 판정을 사용한다.

### 레이드 현황—진행 중

다음 두 실시간 쿼리를 ID로 합친다.

1. `leaderPlayerId == currentPlayerId`, `status in [active, completed]`
2. `memberPlayerIds array-contains currentPlayerId`, `status in [active, completed]`

`completed`는 1회성 회차 완료 후 해산 전 방을 다시 열어 해산하기 위한 것이다. 공개 모집 목록은 `active`만 유지한다. `disbanded`·`incompleteEnded`는 진행 중에 넣지 않는다.

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

### 모집 상세—현재 파티원

상세 진입 시 모집 문서와 `recruitments/{recruitmentId}/members`를 각각 실시간 구독한다. 슬롯 이행 후 멤버는 `partyIndex`, `slotIndex` 순서로 안정 정렬하며, 4인 파티와 공격대 모두 정원 전체의 점유·빈 슬롯을 구분한다. 현재처럼 가입 멤버만 나열하지 않고 빈 슬롯도 표시 전용 모델에서 생성해 Card/Cell로 렌더링한다. 공개 상세 방문자에게는 위에서 정의한 필수 표시 Snapshot만 노출하고 권한·내부 식별 정보는 UI에 전달하지 않는다.

현재 Rules는 확정 멤버만 전체 membership 목록을 읽을 수 있으므로 구현 전에 다음 중 하나를 선택하고 Rules·Repository·테스트를 함께 갱신한다.

1. 공개 모집의 membership 목록 읽기를 허용하되 Domain DTO와 UI에서 공개 필드만 소비한다.
2. 공개 필드만 담은 별도 멤버 요약 읽기 모델을 두고 private membership은 기존 권한을 유지한다.

공개 문서의 모든 필드는 클라이언트에서 기술적으로 읽힐 수 있으므로 민감하거나 권한 전용인 필드를 숨겨야 한다면 2안을 사용한다.

**확정(Option 1):** 공개 모집의 membership `get`/`list`는 active binding 사용자에게 허용한다. `PartyMemberDisplay`와 UI는 `characterNameSnapshot`, `classNameSnapshot`, `role`, `partyIndex`, `slotIndex`, `itemLevelSnapshot`, `combatPowerSnapshot`만 소비하고 PlayerId·권한 플래그는 presentation에 노출하지 않는다. Lost Ark 프로필성 표시 정보와 레이드 참가 구성은 극비 비밀이 아니며, AuthUid·API JWT·권한 식별자만 별도로 보호한다.

## 6. Repository 경계

읽기 계약은 기존 쓰기 중심 `RecruitmentStateRepository`에 추가하지 않는다.

```text
PartyReadRepository
  watchPublicRecruitmentFirstPage(cycleKey, currentPlayerId, limit = 20)
  loadPublicRecruitmentNextPage(cycleKey, currentPlayerId, limit = 20, cursor)
  watchActiveRaids(playerId)
  watchApplications(playerId, cycleKey)
  watchRecruitment(recruitmentId)
  watchRecruitmentMembers(recruitmentId)
```

- `watchRecruitment`은 `PartyReadDetailSnapshot`을 반환한다. 문서 누락은 `item == null`이고, 캐시 여부는 목록과 같이 `isFromCache`로 전달한다. 누락을 권한 오류와 구분하려면 존재하지 않는 모집의 단건 `get`이 active binding만으로 허용되어야 한다.
- `watchRecruitmentMembers`는 파티 표시 전용 DTO 목록과 캐시 여부를 반환한다. Firestore membership 원문이나 PlayerId를 presentation 계층에 노출하지 않는다.
- `레이드 현황`과 공개 모집 목록은 `/raid-status/:recruitmentId` Firestore 현황 상세로 들어간다. 이 상세에는 신청·철회 명령이 연결되어 있으며 Fake `RecruitmentDetailPage`와 경로·데이터를 섞지 않는다.
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
- 다음 페이지를 불러오는 동안 기존 목록을 유지하고 하단 loading을 표시한다. 추가 요청 진행 중 같은 요청은 무시한다.
- 다음 페이지 조회가 실패하면 기존 목록을 유지하고 하단 오류와 재시도를 표시한다. 첫 페이지 전체 오류와 혼합하지 않는다.
- 마지막 페이지에서는 추가 요청과 하단 loading을 중단한다.

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
- 비공개 멤버·신청 정보는 해당 방의 현재 멤버 또는 해당 신청자만 읽을 수 있다. 공개 모집의 membership 목록 읽기는 Option 1에 따라 active binding 사용자에게 허용하며, Domain/UI는 표시 Snapshot만 소비한다.
- 모집 생성·신청·철회·즉시 가입·승인·거절·재신청·단독 모집 삭제·고정 슬롯·참가 캐릭터 변경·탈퇴·추방·회차 완료/취소/전환·다인 해산은 허용된 클라이언트 Transaction과 Rules를 사용한다.
- `신청 중` collection group 쿼리는 중첩 경로 규칙이 적용되지 않으므로 `match /{path=**}/applications/{applicantPlayerId}` 재귀 와일드카드 규칙이 반드시 필요하다. 이 규칙은 `list`만 허용하고 `resource.data.applicantPlayerId == currentPlayerId()`로 본인 신청에 한정한다. 단건 조회와 방 멤버의 신청 열람은 기존 중첩 경로 규칙이 계속 담당한다.
- 모집 단건 `get`은 문서가 없으면 active binding만으로 허용하고, 문서가 있으면 `canReadRecruitment`을 적용한다. `list`는 존재하는 문서만 다루므로 기존 공개·멤버 조건을 유지한다. 생성 Transaction과 상세의 문서 누락 상태가 이 분기를 사용한다.
- Rules와 쿼리는 Emulator Suite에서 공개 목록, 자기 멤버십, 자기 신청, 타인 비공개 데이터 차단을 같이 검증한 후 배포한다.

## 9. 필요 인덱스

- `recruitments`: `visibility, status, manualRecruitmentEnabled, hasAvailableSlot, targetCycleKey, schemaVersion, updatedAt desc`와 문서 ID desc 안정 정렬
- `recruitments`: `leaderPlayerId, status, schemaVersion`
- `recruitments`: `memberPlayerIds array-contains, status, schemaVersion`
- `applications` collection group: `applicantPlayerId, cycleKey, schemaVersion, updatedAt desc`

인덱스는 실제 Repository 쿼리와 동일한 필드·정렬 순서로 `firestore.indexes.json`에 반영한다. 기존 4개 복합 인덱스는 `lost-party`에 배포되어 있다. 공개 목록에 문서 ID 보조 정렬을 추가한 최종 쿼리는 구현 시 로컬 인덱스 정의와 실제 프로젝트 배포 상태를 다시 확인한다.

## 10. 전환 조건

실행 앱의 목록을 Firestore Repository로 전환하려면 다음이 모두 필요하다.

1. 파티 생성·신청·철회·승인 서버 명령이 같은 스키마를 쓴다.
2. `memberPlayerIds`와 카운트 파생 필드를 서버 Transaction이 원자적으로 갱신한다.
3. Security Rules와 복합 인덱스가 Emulator 검증을 통과한다.
4. 기존 로컬 생성·수정 데이터의 이행 또는 폐기 정책을 확정한다.
5. 다중 사용자 실기기 시나리오를 통과한다.
