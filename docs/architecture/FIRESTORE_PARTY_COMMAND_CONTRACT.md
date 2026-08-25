# Spark Firestore 파티 명령 계약

## 1. 운영 제약과 신뢰 경계

- 사용자가 별도로 지시하기 전까지 Firebase Spark 무료 요금제만 사용한다.
- Firebase와 다른 외부 서비스도 결제수단 연결, 유료 플랜 전환, 사용량 초과 과금 가능성이 있는 기능을 사용하지 않는다.
- Cloud Functions, Cloud Run, 유료 스케줄러와 유료 서버 API는 현재 명령 경로에 포함하지 않는다.
- 공유 상태 변경은 Flutter 클라이언트가 Firestore Transaction을 실행하고 Security Rules가 인증, 소유권, 현재 revision과 허용된 변경 형태를 검증한다.
- 클라이언트 조작 위험을 완전히 제거할 수 없다. 초기 서비스에서 이 위험을 수용하되, Rules로 표현 가능한 불변식은 반드시 강제한다.

요금제 판단 근거는 Firebase 공식 [요금제 비교](https://firebase.google.com/pricing)와 [Cloud Functions 할당량 안내](https://firebase.google.com/docs/functions/quotas)다. Cloud Functions는 무료 사용량이 있더라도 Blaze 플랜과 Cloud Billing 연결을 요구하므로 현재 범위에서 제외한다.

## 2. 공통 명령 원칙

- 모든 명령은 `AuthUid -> PlayerId` active binding을 요구한다.
- 클라이언트 입력의 `PlayerId`를 신뢰하지 않고 binding으로 확정한 값만 사용한다.
- 클라이언트 시간을 상태 경계 판정에 사용하지 않고 `request.time`과 server timestamp를 사용한다.
- 기존 문서를 변경하는 명령은 `expectedRevision`을 요구하고 성공 시 정확히 1 증가시킨다.
- 문서 생성·변경·삭제와 확정 참가 점유는 한 Firestore Transaction에서 처리한다.
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

#### Transaction 쓰기

- `recruitments/{newId}` Current State 생성
- `members/{currentPlayerId}` 파티장 멤버십 생성
- `activeRaidAssignments/{characterId_raidId}` 생성
- 사용자가 철회를 확인한 신청을 `superseded`로 전환

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

#### 거절 조건

- `expectedRevision` 불일치
- 활성 회차가 아님
- 변경 후 현재 멤버가 카탈로그 입장 레벨이나 파티 정원을 위반
- 변경 후 현재 참가 캐릭터의 확정 점유를 같은 Transaction에서 새 레이드 ID로 안전하게 이전할 수 없음

레이드 ID가 바뀌는 수정은 모든 멤버의 점유 문서를 원자적으로 이전해야 한다. Security Rules로 전체 멤버의 소유권·카탈로그 조건을 충분히 강제하기 어려우므로 Spark 초기 서버 전환에서는 **레이드·난이도 변경을 제외**한다. 기존 로컬 기능은 서버 모드에서 비활성 안내를 표시한다.

### 4.3 승인 대기 신청

#### 호출 주체

- Character 소유권이 active인 신청자

#### 조건

- 모집이 `active`, `manualApproval`, 모집 활성이고 빈자리가 있음
- 신청자가 현재 멤버가 아님
- 같은 방의 승인 대기 신청이 없음
- 선택 Character가 카탈로그 입장 레벨과 모집 최소 전투력 조건을 만족
- 같은 레이드의 다른 승인 대기 신청은 허용

#### Transaction 쓰기

- `applications/{currentPlayerId}` 문서를 `pending`으로 생성
- 신청 시점의 Character·역할·아이템 레벨·전투력 Snapshot 저장

승인 대기는 확정 점유를 생성하지 않는다.

### 4.4 신청 철회

- 신청자 본인의 `pending` 문서만 `withdrawn`으로 변경한다.
- `expectedApplicationUpdatedAt` 또는 신청 revision으로 동시 승인과 경쟁을 감지한다.
- 이미 `approved`, `rejected`, `withdrawn`, `superseded`면 멱등적 현재 결과를 반환하고 멤버십을 역으로 제거하지 않는다.

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
- 역할과 `partyIndex`는 유지하고 새 Character의 소유권, 입장 레벨, 확정 점유와 현재 파티의 동일 직업 딜러 제한을 다시 검증한다.
- 기존 확정 점유 삭제, 새 확정 점유 생성, membership Character Snapshot과 모집 revision 갱신을 한 Transaction으로 처리한다.
- 다른 확정 파티에 참가 중인 Character의 이동·스왑은 로컬 최신 Projection으로 결과를 미리 계산하되, 양쪽 모집·membership·점유와 revision을 서버 Transaction에서 다시 검증하는 별도 후속 명령으로 구현한다.
- 완전 스왑 조건을 만족하지 못해 한쪽 파티 탈퇴가 동반되는 경우 예상 결과를 먼저 표시하고 사용자가 명시적으로 확인한 때에만 실행한다.
- 이 후속 명령은 Spark에서 원천 제외하지 않는다. Rules로 결합 불변식을 안전하게 강제할 수 있는지 기능 설계와 함께 검증한다.

#### 탈퇴와 추방

- 일반 참가자는 본인만 탈퇴할 수 있고 현재 책임자만 다른 참가자를 추방할 수 있다.
- membership과 확정 점유를 삭제하고 모집의 멤버 목록·역할별 인원·빈자리·revision을 함께 갱신한다.
- 책임자가 탈퇴하면 Transaction으로 직렬화된 `memberPlayerIds` 가입 순서의 첫 잔여 Player에게 책임자를 승계하고 가입 승인 권한을 부여한다.
- 마지막 책임자가 탈퇴하면 모집을 삭제하지 않고 `disbanded`로 종료하며 수동 모집을 비활성화한다.

#### 가입 승인 권한

- 현재 책임자만 다른 현재 멤버의 `canApproveApplications`를 부여하거나 회수할 수 있다.
- 책임자 자신의 고유 승인 권한은 이 명령으로 회수할 수 없다.
- membership 권한과 모집 revision을 같은 Transaction에서 갱신한다.

### 4.8 회차 수명주기

#### 완료와 Snapshot

- 현재 회차 참가자는 누구나 완료할 수 있고 최초 완료 또는 완료 취소 후 재완료만 성공한다.
- `cycles/{cycleKey}`에 완료 당시 Player·Character·역할·파티 위치 Snapshot과 완료자를 저장하고 모집의 `currentCycleStatus`, 완료자와 revision을 함께 갱신한다.
- 1회성 파티는 모집을 `completed`로 종료하고 반복 파티는 방을 `active`로 유지해 다음 회차 준비 변경을 허용한다.

#### 완료 취소

- 반복 파티 책임자만 KST 화요일 22:00, 즉 `cycleEndsAt` 8시간 전까지 취소할 수 있다.
- cycle의 `completionRevision`과 모집 revision을 함께 비교하고 취소된 완료는 같은 회차에서 다시 완료할 수 있다.
- 시간 제한은 클라이언트 안내와 별개로 Rules의 `request.time`이 최종 강제한다.

#### 반복 설정과 주차 전환

- 현재 미완료 회차의 책임자만 `continueTogether`를 변경할 수 있다.
- 각 모집은 KST 수요일 6시 기준 `cycleStartedAt`, `cycleEndsAt`과 7일 간격을 저장한다.
- 유료 스케줄러를 사용하지 않는다. 앱 실행·관련 화면 진입·명령 수행 시 만료 회차를 발견한 현재 멤버가 멱등 전환 Transaction을 실행한다.
- 미완료 회차는 `incompleteEnded` Snapshot을 생성한다. 반복 파티는 현재 구성을 다음 회차로 승계하고 1회성 파티는 종료한다.
- 지연 실행되더라도 Rules의 `request.time >= cycleEndsAt`, 연속된 다음 회차 경계와 revision 검증을 모두 통과해야 한다.

## 5. Security Rules 보장 범위

Rules는 적어도 다음을 `getAfter()`를 포함해 검증해야 한다.

- binding으로 확정한 Player만 자기 멤버십·신청·점유 문서의 허용된 변경을 요청
- 파티 생성 시 파티장 membership과 점유가 함께 존재
- membership 생성 시 일치하는 점유가 함께 존재
- `memberPlayerIds`, `memberCount`, membership 변경이 허용된 명령 형태에서 함께 이뤄짐
- 신청자는 자기 `pending -> withdrawn`, 승인자는 `pending -> approved|rejected`만 가능
- 모집 수정은 파티장만 허용하고 불변 필드와 revision 증가를 검증
- 서버 검증이 필요하지만 Rules로 안전하게 표현할 수 없는 변경은 허용하지 않음

생성 Transaction은 신규 `recruitments/{id}` 존재 여부를 `get`으로 확인한다. 문서가 없을 때 `resource.data`를 읽으면 Rules가 `permission-denied`를 내므로, 존재하지 않는 모집의 단건 `get`은 active binding만으로 허용한다. 존재하는 문서의 읽기와 `list`는 기존 `canReadRecruitment`을 유지한다.

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

## 8. 구현 분할

1. 파티 생성과 확정 참가 점유
2. 승인 대기 신청과 본인 철회
3. 즉시 가입
4. 신청 승인·거절
5. 참가 캐릭터 변경·탈퇴·추방·승인권·책임자 승계
6. 회차 완료·완료 취소·반복 설정·주차 전환과 Snapshot
7. 제목·조건·승인 방식·모집 활성 수정
8. 실행 앱을 Firestore 읽기·쓰기 Repository로 전환

각 단위는 해당 명령의 Rules, 동시 Transaction 테스트, 오류 UI와 로컬 Domain 회귀 테스트를 함께 마감한다.

## 9. 실행 앱 전환 상태

- 읽기: `레이드 현황`의 진행 중·신청 중·읽기 전용 상세는 Firestore `PartyReadRepository`를 사용한다.
- 쓰기 1단위: `레이드 모집 > 모집 생성`만 `FirestorePartyCreateRepository`로 연결한다. 성공 시 `/raid-status/{recruitmentId}` 읽기 상세로 이동한다.
- 쓰기 2단위: 읽기 전용 상세의 신청·본인 철회는 `FirestorePartyApplicationCommandRepository`로 연결한다. 신청 Character는 `serverCharacterId`다.
- 생성 명령의 `leaderCharacterId`는 Drift 로컬 ID가 아니라 게임 계정 인증으로 저장된 `serverCharacterId`다. 인증되지 않은 캐릭터는 명령을 보내지 않는다.
- 생성 Transaction의 신규 모집 `get`이 문서 부재에서 `permission-denied`가 되지 않도록, 존재하지 않는 `recruitments/{id}` 단건 읽기는 active binding만으로 허용한다. 이 Rules는 `lost-party`에 배포했다.
- Android 실기기에서 인증된 캐릭터로 생성한 방이 `진행 중`에 나타나고 읽기 전용 상세(수정 미적용 안내 포함)로 연결되는 것을 확인했다.
- `레이드 모집` 공개 목록은 Firestore 페이징 읽기(`watchPublicRecruitmentFirstPage` / `loadPublicRecruitmentNextPage`)를 사용한다. Fake 상세·승인·멤버·회차 명령은 아직 `InMemoryRecruitmentStateRepository`와 `RecruitmentCommandService`를 유지한다. 다음 전환 단위는 즉시 가입·승인·거절이다.
