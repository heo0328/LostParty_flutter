# Task-11 Firestore 그룹 생성·가입 계약

## 최신 보완 — 그룹 전투력 표시 (2026-08-31)

- Task-11a 멤버 목록·탈퇴·Snapshot은 main에 포함되어 있다. 아래 Task-11 당시 미구현/제외 기록은 과거 범위다. 사용자 확인 기준 현재 생성·초대·탈퇴·코드 가입·Rules 배포는 정상이다.
- 그룹원 목록은 membership Snapshot과 Character fallback, 상세 인증 캐릭터 목록은 각 Character의 전투력을 읽는다. 그룹 상세 진입 시 본인 활동 Character의 로컬 표시 전투력을 Character에 먼저 보강하고, 그 Character가 현재 표시 Snapshot이면 membership을 갱신한다. 활동에서 빠진 Character의 기존 Snapshot은 유지한다.
- 로컬 프로필에 전투력이 없으면 가장 최근 유효한 저장 세팅에서 복구한다. 소유권 상실·서버 ID 없음·원정대 누락 캐릭터는 후보에서 제외한다. 프로필 값이 있으면 세팅을 추가 조회하지 않는다.
- 로컬 null은 기존 membership 숫자를 삭제하지 않는다. 실제 Transaction에서 읽은 기존 숫자를 보존하며, 없는 값만으로 불필요한 갱신을 요청하지 않는다.
- 동기화 실패는 더 이상 삼키지 않는다. 목록은 저장값으로 계속 표시하고 새로고침 안내를 노출한다. Character 보강 실패와 membership 갱신은 독립 처리한다. 새로고침·멤버 상세 요청의 연타를 막는다.
- 전투력은 캐릭터별로 저장한다. 대표 전투력을 다른 인증 캐릭터에 대입하지 않는다. 로컬 데이터 자체가 없으면 소유자가 내 계정에서 캐릭터 정보를 저장해야 한다.
- Character 보강의 데이터/권한/비용 범위는 GAME_ACCOUNT_CHARACTER_FIREBASE_CONTRACT의 최신 보완을 따른다. 이번 작업은 Rules 변경·배포를 포함하지 않는다. 실기기 검증 결과는 NEXT_WORK를 따른다.

## 1. 상태와 범위

- 상태: **Task-11 구현 완료** (브랜치 `cursor/task-11-group-membership`, 커밋 `b673fdb`). `main` 병합·Codex 재검토 전
- 제품 기준: [`../product/GROUP_PRODUCT_FLOW.md`](../product/GROUP_PRODUCT_FLOW.md)
- 실행 환경: Firebase Spark, Flutter 클라이언트 Transaction, Firestore Security Rules
- 구현 범위: 그룹 생성·검색·기본 상세·직접 초대·가입 신청·초대코드 즉시 가입과 요청 처리
- 실기기(2026-08-31): 초대코드 생성·폐기·`joinCodeVisibleToMembers` 토글·코드 즉시 가입(인원 2)·생성/마지막 활동 시각 표시 확인. 멤버 목록 UI는 미구현(§10 읽기 허용만). Emulator §12.4–12.5 동시성은 미실시

이 문서는 제품 정책을 다시 결정하지 않는다. 확정된 Task-11 정책을 Firestore 경로, 명령 Transaction, Rules 불변식과 검증 시나리오로 분리한다.

다음은 Task-11에서 제외한다.

- 일반 멤버 탈퇴, 추방, 그룹장 이전·자격 상실 승계, 그룹 해산
- 그룹 레이드 생성과 공개 범위 전환
- 그룹 필터, 알림, 공지
- 일반 레이드와 사용자 데이터의 활동 시각·삭제 기반 적용
- Cloud Functions, Cloud Run, 예약 작업, 결제수단이 필요한 기능

제외 기능의 제품 정책은 확정된 상태로 제품 문서에 남긴다. 이번 데이터 모델은 후속 명령을 추가할 수 있어야 하지만 Task-11 Rules가 해당 쓰기를 미리 허용하지 않는다.

## 2. 신뢰 경계와 공통 원칙

- 모든 명령은 `AuthUid -> PlayerId` active binding과 `players/{playerId}.status == active`를 요구한다.
- 클라이언트가 전달한 `playerId`를 신뢰하지 않고 Rules의 `currentPlayerId()`와 문서 경로로 호출자를 확정한다.
- 그룹 가입 주체와 membership 문서 ID는 항상 `PlayerId`다. Character ID, Game Account ID와 캐릭터명은 membership 키가 아니다.
- 한 Player가 인증한 본계정·부계정의 모든 원정대는 하나의 그룹 membership을 공유한다. 캐릭터는 검색·표시 Snapshot 또는 향후 레이드 참가 선택에만 사용한다.
- Character 이름은 변경 가능한 표시값이다. 초대 대상을 확정한 뒤에는 검색한 Character의 `ownerPlayerId`를 요청 대상 Player ID로 저장한다.
- 서버 시각은 `request.time`과 server timestamp만 사용한다.
- 기존 상태 변경 명령은 `expectedRevision`을 비교하고 성공 시 그룹 또는 관계 문서 revision을 정확히 1 증가시킨다.
- 문서 중 하나라도 최신 상태 검증에 실패하면 Transaction 전체를 실패시킨다. 부분 membership, 고아 요청과 가입 수 요약 불일치를 성공 결과로 남기지 않는다.
- Rules는 허용 필드, 호출자, 상태 전이와 `getAfter()` 관계를 최종 강제한다. UI에서 버튼을 숨기는 것은 보안 경계가 아니다.

## 3. 식별자와 문서 경로

```text
groups/{groupId}
groups/{groupId}/members/{playerId}
groups/{groupId}/joinRelations/{playerId}
groups/{groupId}/applicantStats/{playerId}
groups/{groupId}/blockedPlayers/{playerId}

players/{playerId}/groupMembershipState/current
players/{playerId}/groupRelations/{groupId}

groupJoinCodes/{normalizedCode}
```

- `groupId`는 Firestore가 발급한 불투명 문서 ID다.
- join relation은 `groupId + playerId`당 문서 하나만 사용한다. 초대와 신청을 별도 문서로 동시에 만들지 않는다.
- Player 하위 `groupRelations/{groupId}`는 내 그룹·요청 현황을 조회하기 위한 역방향 Projection이다. 그룹 하위 원본과 같은 Transaction에서만 변경한다.
- `groupMembershipState/current`는 가입 그룹 ID 배열을 보유하며 Player별 최대 50개를 Rules에서 강제하기 위한 요약 문서다.
- 초대코드는 그룹 ID와 분리된 고엔트로피 무작위 값이며 정규화된 코드 자체를 `groupJoinCodes` 문서 ID로 사용한다. 목록 읽기는 금지하고 사용자가 입력한 정확한 코드의 단건 조회만 허용한다.

## 4. 그룹 Current State

```text
groups/{groupId}
  schemaVersion: 1
  status: active | softDeleted
  name: string
  normalizedName: string
  representativeCharacterId: string
  representativeCharacterNameSnapshot: string
  normalizedRepresentativeCharacterName: string
  representativeServerNameSnapshot: string
  leaderPlayerId: string
  leaderDisplayCharacterNameSnapshot: string
  memberCount: number
  revision: number
  hasActiveJoinCode: bool
  joinCodeVisibleToMembers: bool
  lastActivityAt: timestamp
  createdAt: timestamp
  updatedAt: timestamp
  deletedAt: timestamp | null
```

### 4.1 생성 불변식

- 신규 그룹은 `status == active`, `memberCount == 1`, `revision == 1`이다.
- `leaderPlayerId == currentPlayerId()`이며 같은 Transaction 이후 `members/{leaderPlayerId}.role == leader`가 존재한다.
- 대표 Character는 호출자가 소유하며 `characters.status == active`인 서버 Character다.
- 대표 Character의 Game Account 소유 관계가 active여야 한다. 구현은 현재 인증 계약의 active `playerGameAccounts`와 Character 소유 상태를 함께 읽고 검증한다.
- 대표 Character Snapshot은 생성 시점 표시값이며 Player의 내 계정 대표 Character와 자동 연동하지 않는다.
- 직접 입력 그룹명은 trim 후 1~20자, 줄바꿈·제어문자 없음 조건을 만족한다. 미입력 시 `${representativeCharacterNameSnapshot}의 그룹`을 사용한다.
- 그룹명 중복은 허용한다.
- 생성 시 초대코드는 없다. `hasActiveJoinCode == false`다.
- 모든 생성 시각과 활동 시각은 `request.time`이다.

`normalizedName`과 `normalizedRepresentativeCharacterName`은 검색 Projection이다. 앱의 공통 정규화 함수로 Unicode NFC, 앞뒤 공백 제거, 영문 소문자화를 적용한다. Rules는 원문 길이·금지 문자·정규화 필드의 문자열 여부와 최대 길이를 제한하지만 Unicode 정규화 결과를 독립 재계산하지 못한다. 이 검색 보조값은 권한 판정이나 식별 키로 사용하지 않는다.

### 4.2 공개 읽기와 비공개 데이터

로그인한 active Player는 active 그룹의 다음 기본 정보만 읽고 검색할 수 있다.

- Group ID, 그룹명, 대표 캐릭터명·서버 Snapshot
- 그룹장 표시 캐릭터명 Snapshot
- 현재 인원, 생성·마지막 활동 시각

그룹 원본에는 전체 member Player ID 배열, 신청 금지 Player ID, 초대코드 원문을 저장하지 않는다. 멤버 목록·요청·금지 정보는 현재 그룹원 또는 해당 요청 당사자에게만 Rules가 허용한다.

soft delete 그룹은 일반 목록과 검색에서 제외한다. Task-11에는 soft delete 명령을 구현하지 않는다.

## 5. Player 단위 membership

```text
groups/{groupId}/members/{playerId}
  schemaVersion: 1
  groupId: string
  playerId: string
  role: leader | member
  joinedAt: timestamp
  joinSequence: number
  joinedBy: created | invitation | application | joinCode
  displayCharacterIdSnapshot: string
  displayCharacterNameSnapshot: string
  revision: number
  createdAt: timestamp
  updatedAt: timestamp
```

- 그룹 생성자의 `joinSequence == 1`이다.
- 신규 멤버는 가입 Transaction 시작 시 읽은 그룹의 `memberCount + 1`을 `joinSequence`로 저장한다.
- Task-11에서는 탈퇴가 없어 sequence 재사용이 발생하지 않는다. 후속 탈퇴·재가입 계약에서는 별도 단조 증가 카운터가 필요하면 그룹 문서에 추가한다.
- `displayCharacter*Snapshot`은 가입 경로에서 사용한 인증 Character의 표시 정보다. membership과 권한의 주체는 여전히 Player다.
- Character Snapshot이 오래되거나 Character 소유권이 이후 변경돼도 membership을 다른 Player로 이전하지 않는다.

```text
players/{playerId}/groupMembershipState/current
  schemaVersion: 1
  playerId: string
  activeGroupIds: list<string>
  activeGroupCount: number
  revision: number
  updatedAt: timestamp
```

- 문서가 없으면 빈 상태로 취급하며 최초 그룹 생성·가입 Transaction에서 만든다.
- `activeGroupIds`는 중복이 없고 최대 50개다.
- `activeGroupCount == activeGroupIds.size()`다.
- membership 생성 시 대상 Group ID를 정확히 하나 추가하고 revision을 1 증가시킨다. 최초 생성은 revision 1이다.
- Rules는 신규 `members/{playerId}`, 그룹의 `memberCount + 1`, Player 요약의 Group ID 추가를 `getAfter()`로 함께 확인한다.

```text
players/{playerId}/groupRelations/{groupId}
  schemaVersion: 1
  groupId: string
  playerId: string
  relation: member | invited | applied
  requestStatus: pending | accepted | rejected | cancelled | expired | blocked | null
  groupNameSnapshot: string
  displayCharacterNameSnapshot: string
  expiresAt: timestamp | null
  sourceRevision: number
  createdAt: timestamp
  updatedAt: timestamp
```

이 Projection은 내 그룹과 요청 현황 목록용이다. 원본 그룹·membership·join relation 없이 Projection만 단독 생성·변경할 수 없다. 불일치가 발견되면 화면은 권한을 확대하지 않고 원본 재조회 또는 데이터 오류 상태를 표시한다.

## 6. 초대·가입 신청 원본

```text
groups/{groupId}/joinRelations/{playerId}
  schemaVersion: 1
  groupId: string
  targetPlayerId: string
  kind: invitation | application
  status: pending | accepted | rejected | cancelled | expired | blocked
  requestedByPlayerId: string
  characterIdSnapshot: string
  characterNameSnapshot: string
  serverNameSnapshot: string
  characterClassNameSnapshot: string
  itemLevelSnapshot: number | null
  combatPowerSnapshot: number | null
  applicationAttempt: number
  revision: number
  createdAt: timestamp
  expiresAt: timestamp
  decidedAt: timestamp | null
  updatedAt: timestamp
```

- `targetPlayerId`는 초대 검색 Character 또는 신청 Character의 현재 `ownerPlayerId`다.
- `expiresAt == createdAt + 24시간`이다.
- pending 여부는 `status == pending && request.time < expiresAt`로 판단한다.
- 만료된 pending 문서는 읽을 때 유효 요청으로 취급하지 않는다. 재시도 Transaction이 이를 `expired` 처리하고 새 관계로 재사용할 수 있다.
- 같은 `groupId + playerId`에 유효 pending 관계가 있으면 종류가 달라도 새 요청을 만들지 않고 기존 요청을 반환한다.
- invitation의 `requestedByPlayerId`는 현재 그룹원이다. application은 대상 Player 본인이다.
- 직접 초대는 active 인증 Character의 정확한 이름 검색 결과에서 Player를 확정한다. 동명이인은 캐릭터명·서버·직업·아이템 레벨·전투력을 표시하고 Character ID로 선택한다.
- 초대와 신청의 Character Snapshot은 표시·이력용이며 Player 단위 차단을 우회하는 키로 사용하지 않는다.

### 6.1 신청 누적 횟수

```text
groups/{groupId}/applicantStats/{playerId}
  schemaVersion: 1
  groupId: string
  playerId: string
  applicationCount: number
  lastCharacterNameSnapshot: string
  lastItemLevelSnapshot: number | null
  lastCombatPowerSnapshot: number | null
  createdAt: timestamp
  updatedAt: timestamp
```

- 가입 신청을 새 pending 상태로 성공시킬 때마다 `applicationCount`를 정확히 1 증가시킨다.
- 초대와 초대코드 가입은 이 횟수에 포함하지 않는다.
- 거절·취소·만료·재신청 후에도 그룹 존속 중 초기화하지 않는다.
- Character나 Game Account를 바꿔도 같은 Player 문서를 갱신한다.

### 6.2 신청 금지

```text
groups/{groupId}/blockedPlayers/{playerId}
  schemaVersion: 1
  groupId: string
  playerId: string
  blockedByPlayerId: string
  reason: applicationRejected | manual
  characterNameSnapshot: string
  applicationCountSnapshot: number
  itemLevelSnapshot: number | null
  combatPowerSnapshot: number | null
  createdAt: timestamp
  updatedAt: timestamp
```

- 현재 그룹장만 생성·삭제할 수 있다.
- 신청 거절과 금지를 한 버튼으로 실행하면 relation의 `blocked` 전이와 block 생성을 같은 Transaction에서 처리한다.
- block이 존재하면 해당 Player의 신청, 초대, 초대 수락과 초대코드 가입을 모두 거절한다.
- 본·부계정과 Character 변경은 block을 우회하지 못한다.
- 그룹장은 금지 목록을 읽고 block 문서를 삭제해 해제한다. 해제는 이전 relation을 자동 pending 또는 accepted로 복원하지 않는다.

## 7. 초대코드

```text
groupJoinCodes/{normalizedCode}
  schemaVersion: 1
  groupId: string
  status: active
  createdByPlayerId: string
  createdAt: timestamp
  updatedAt: timestamp
```

- 그룹당 활성 코드는 최대 하나지만 코드가 없는 그룹도 정상이다.
- 코드는 최소 96비트 이상의 암호학적 난수로 생성하고 사람이 입력할 때 혼동되는 문자를 제외한 고정 길이 표기를 사용한다.
- 공백·대소문자를 정규화한 값이 문서 ID다. 코드 원문을 그룹 공개 문서에 저장하지 않는다.
- 그룹장은 `groupJoinCodes/{code}` 생성과 함께 그룹의 `hasActiveJoinCode`를 false→true로 변경한다.
- 기존 코드가 있으면 먼저 폐기해야 하며 새 코드 생성과 기존 코드 삭제를 같은 Transaction에 넣어 교체하지 않는다. 제품 흐름은 명시적인 `코드 폐기` 후 `코드 생성` 두 동작이다.
- 코드 폐기는 정확한 코드 문서 삭제와 그룹의 `hasActiveJoinCode` true→false를 같은 Transaction에서 수행한다.
- Task-11에는 그룹 해산이 없지만 후속 해산 Transaction은 활성 코드도 반드시 삭제한다.
- `joinCodeVisibleToMembers`는 화면 공개 정책만 제어한다. 직접 코드를 알고 있는 active Player의 가입 가능 여부를 바꾸지 않는다.
- 코드 문서의 list는 항상 금지한다. 단건 get은 active Player의 정확한 코드 입력에만 사용하며 응답에는 공개 그룹 기본 정보 이상을 노출하지 않는다.

## 8. 명령별 Transaction 계약

### 8.1 그룹 생성

읽기:

- 호출자의 active binding과 Player 상태
- 대표 Character와 Game Account의 active 소유·인증 관계
- 호출자의 `groupMembershipState/current`

쓰기:

- `groups/{newGroupId}` 생성
- 생성자 `members/{currentPlayerId}` 생성
- Player membership state에 Group ID 추가
- `players/{currentPlayerId}/groupRelations/{groupId}`를 `member`로 생성

거절:

- 인증 Character가 없거나 현재 Player 소유가 아님
- Player의 active 그룹 수가 이미 50
- 이름·Snapshot 형식 오류

### 8.2 그룹 검색과 기본 상세

- 한 검색 입력을 공통 정규화한 뒤 `normalizedName`과 `normalizedRepresentativeCharacterName`에 각각 prefix query를 실행하고 Group ID로 중복 제거한다.
- 빈 검색어는 `status == active`, `lastActivityAt desc`, 문서 ID 보조 정렬로 제한된 최신 목록을 제공할 수 있다.
- 검색 1페이지는 각 query 최대 20개이며 합친 화면 결과가 20개보다 적을 수 있다. 무제한 전체 다운로드 후 클라이언트 필터링은 금지한다.
- Rules는 `status == active` 공개 그룹만 list하도록 쿼리 조건을 요구한다.
- 기본 상세는 공개 필드만 먼저 읽는다. membership 확인 후에만 멤버·요청 관리 읽기를 시작한다.

### 8.3 직접 초대

읽기:

- 현재 그룹과 호출자 membership
- 정확한 Character 이름 검색 결과와 active 소유 Player
- 대상 membership, block, 기존 join relation

쓰기:

- `joinRelations/{targetPlayerId}`를 pending invitation으로 생성 또는 만료 relation 재사용
- 대상 Player의 `groupRelations/{groupId}`를 invited로 생성·갱신
- 그룹 `revision`, `lastActivityAt`, `updatedAt` 증가

현재 그룹원은 초대할 수 있지만 승인·금지·멤버 관리 권한은 얻지 않는다. 자기 자신, 기존 멤버, 금지 Player와 이미 유효한 관계에는 새 초대를 만들지 않는다.

### 8.4 초대 수락·거절·취소

- 수락·거절은 대상 Player만 실행한다.
- 발신자는 자기가 만든 pending invitation을 취소할 수 있고 그룹장은 모든 pending invitation을 취소할 수 있다.
- 수락은 그룹 정원 50명, 대상 Player의 그룹 수 50개, block 부재, 현재 membership 부재와 relation 만료 전을 다시 검증한다.
- 수락 성공 시 member, Player membership state와 양방향 relation을 같은 Transaction에서 `member/accepted`로 바꾸고 그룹 인원·revision을 갱신한다.
- 거절·취소는 membership을 만들지 않는다. 이미 최종 상태면 현재 결과를 반환하고 역방향 변경을 하지 않는다.

### 8.5 가입 신청

읽기:

- 그룹 active 상태와 block
- 호출자 membership과 기존 join relation
- 신청에 사용한 active 인증 Character
- applicant stats

쓰기:

- join relation을 pending application으로 생성 또는 만료·최종 relation 재사용
- Player relation을 applied로 갱신
- applicant stats의 횟수 +1
- 그룹 revision과 활동 시각 갱신

유효 pending 초대가 있으면 신청으로 덮어쓰지 않는다. 재신청 대기시간은 없지만 기존 명령이 끝난 뒤 새 Transaction으로 실행한다.

### 8.6 신청 승인·거절·금지·해제

- 현재 그룹장만 실행한다.
- 승인은 pending·미만료 application, block 부재, 정원과 Player별 그룹 수를 다시 검증하고 초대 수락과 같은 membership 원자 쓰기를 수행한다.
- 거절은 relation을 `rejected`로 바꾸며 누적 신청 횟수를 유지한다.
- 금지는 pending application을 `blocked`로 바꾸고 block 문서를 생성한다.
- 금지 해제는 block만 삭제하고 relation 상태를 유지한다.

### 8.7 초대코드 즉시 가입

1. 사용자가 입력한 정확한 `groupJoinCodes/{normalizedCode}`를 읽는다.
2. 코드가 가리키는 active 그룹, block, membership, Player membership state를 Transaction에서 읽는다.
3. 정원과 가입 그룹 수를 다시 확인한다.
4. member와 Player membership state를 만들고 Player relation을 `member`로 갱신한다.
5. 기존 pending invitation/application이 있으면 `accepted`로 종료하되 신청 횟수는 변경하지 않는다.
6. 그룹 인원·revision·활동 시각을 갱신한다.

코드 가입은 별도 승인 없이 완료되지만 block, 정원과 50개 제한을 우회하지 않는다. 코드 폐기와 가입이 경쟁하면 Firestore Transaction 충돌 후 최신 코드 존재 여부를 다시 읽고 폐기 이후 가입을 거절한다.

## 9. 활동 시각과 보관 기반

- Task-11의 모든 성공한 상태 변경은 그룹 `lastActivityAt`과 `updatedAt`을 `request.time`으로 갱신한다.
- 단순 get/list/listener 수신은 활동 쓰기를 만들지 않는다.
- 생성·가입 기반 문서에는 모두 `groupId`, `createdAt` 또는 `occurredAt`, `updatedAt`을 둬 후속 운영자 정리에서 그룹별 대상을 찾을 수 있게 한다.
- 처리 완료된 요청은 즉시 삭제하지 않는다. 후속 정리 구현에서 최종 상태 전환 시 `expireAt = occurredAt + 3개월` 성격의 정리 기준을 추가한다.
- Task-11은 그룹 soft delete와 실제 삭제를 구현하지 않지만 그룹 원본의 `status`, `deletedAt` 필드를 예약한다. 일반 클라이언트는 이를 변경할 수 없다.
- 1개월 미활동 표기, soft delete 후 28일 보관과 수동 실제 삭제는 운영자 정리 후속 계약에서 구현한다.

## 10. Security Rules 권한표

| 경로·명령 | 일반 active Player | 현재 그룹원 | 그룹장 | 당사자 |
|---|---:|---:|---:|---:|
| active 그룹 공개 get/list | 허용 | 허용 | 허용 | 허용 |
| 멤버 목록 읽기 | 금지 | 허용 | 허용 | - |
| 그룹 생성 | 본인 가능 | - | - | - |
| 그룹 공개 필드 수정 | 금지 | 금지 | Task-11 금지 | - |
| 직접 초대 | 금지 | 허용 | 허용 | - |
| 초대 수락·거절 | 금지 | - | - | 대상만 |
| 자기 초대 취소 | 금지 | 발신 초대만 | 모든 초대 | - |
| 가입 신청 | 본인 가능 | 기존 멤버는 불가 | 기존 멤버는 불가 | 신청자만 |
| 신청 승인·거절·금지 | 금지 | 금지 | 허용 | - |
| 신청 금지 목록 읽기·해제 | 금지 | 금지 | 허용 | 금지된 본인은 존재 여부도 조회하지 않음 |
| 초대코드 생성·폐기 | 금지 | 금지 | 허용 | - |
| 초대코드 정확한 get | 허용 | 허용 | 허용 | - |
| 초대코드 list | 금지 | 금지 | 금지 | 금지 |
| 코드 가입 | 본인 가능 | 기존 멤버는 멱등 결과 | 기존 멤버는 멱등 결과 | 가입자만 |
| 탈퇴·추방·이전·해산 | Task-11 전부 금지 | 금지 | 금지 | 금지 |

Rules helper는 최소한 다음을 제공한다.

- `hasActivePlayerBinding()`
- `groupPath(groupId)`, `groupMemberPath(groupId, playerId)`
- `isCurrentGroupMember(groupId)`, `isCurrentGroupLeader(groupId)`
- `hasGroupBlock(groupId, playerId)`
- `validGroupRevisionUpdate(oldData, newData)`
- `validMembershipStateAdd(playerId, groupId)`
- 명령별 create/update 전이 검증

Rules 검증은 다음 결합 관계를 반드시 `existsAfter/getAfter`로 확인한다.

- group 생성 ↔ leader member ↔ Player membership state ↔ Player relation
- member 추가 ↔ group memberCount +1 ↔ Player membership state Group ID +1
- join relation 변경 ↔ Player relation 동일 sourceRevision
- block 생성 ↔ 대상 relation blocked 또는 기존 최종 신청
- 코드 생성·삭제 ↔ 그룹 hasActiveJoinCode 전이

Rules 문서 접근 횟수 한도를 넘지 않도록 명령별 읽기 수를 Emulator에서 측정한다. 하나의 쓰기에 허용되는 규칙 접근 한도와 다중 문서 Transaction 전체 한도를 초과하는 설계는 기능 구현 전에 문서 구조를 다시 나눈다. 검증을 생략해 한도를 맞추지 않는다.

## 11. Repository와 UI 흐름 계약

- Domain 모델과 ViewModel은 Firestore `DocumentSnapshot`, Timestamp와 Rules 경로를 직접 노출하지 않는다.
- 그룹 첫 화면은 `내 그룹`이 기본이며 `요청 현황`을 별도 탭으로 제공한다.
- `내 그룹`은 Player `groupRelations`의 `member` Projection을 구독하고 선택한 그룹의 원본을 읽는다.
- 요청 현황은 `invited`와 `applied` 관계를 읽어 incoming invitation, 내가 신청한 내역과 그룹장에게 들어온 신청을 권한에 맞게 나눈다.
- 만료 시각이 지난 요청은 UI에서 즉시 `만료`로 표시하고, 쓰기가 필요한 정리는 다음 사용자 명령 Transaction에서 처리한다. 앱 시작마다 전체 만료 문서를 갱신하지 않는다.
- `permission-denied`, `failed-precondition`, `aborted`, `unavailable`, 데이터 계약 오류를 구분한다.
- 정원·revision·코드 폐기 경쟁은 최신 상태 새로고침과 재시도 가능한 안내를 제공한다.
- block은 개인 정보처럼 취급한다. 금지된 사용자는 구체적인 운영 정보 대신 `이 그룹에 가입할 수 없습니다` 결과만 받는다.

## 12. 자동·Emulator 검증 시나리오

### 12.1 생성과 읽기

- active 인증 Character 보유 Player의 그룹 생성 성공
- 인증 Character 없음, 타 Player Character, ownershipLost 계정으로 생성 거절
- 50번째 그룹 가입 상태에서 생성 성공, 51번째 생성 거절
- 그룹명 중복 생성 성공, 잘못된 길이·제어문자 거절
- 비회원의 공개 기본 정보 읽기 성공, 멤버·요청·금지 목록 읽기 거절
- softDeleted 그룹의 공개 list 제외

### 12.2 Player 단위 불변식

- 같은 Player의 본계정·부계정 Character로 중복 membership 생성 거절
- Character를 바꿔 재신청해도 같은 relation과 applicant stats를 사용
- 그룹 memberCount, member 문서, Player membership state 중 하나를 누락하거나 숫자를 조작한 쓰기 거절
- 두 기기가 같은 Player의 50번째·51번째 그룹 가입을 동시에 시도할 때 한도 내 결과만 성공

### 12.3 초대와 신청

- 일반 그룹원의 직접 초대 성공, 일반 멤버의 승인·금지 거절
- 동명이인 Character 선택 후 대상 Player ID가 정확히 저장됨
- 유효 초대가 있는 Player의 신청이 기존 관계를 덮어쓰지 않음
- 24시간 전 수락 성공, 정확히 만료 이후 수락 거절
- 거절·만료 후 즉시 재신청 성공 및 Player 단위 횟수 +1
- 초대·코드 가입은 신청 횟수를 증가시키지 않음
- 금지 후 본·부계정 Character를 바꾼 신청·초대·코드 가입 모두 거절, 해제 뒤 새 명령 성공

### 12.4 코드와 동시성

- 코드 없는 그룹 정상 동작
- 그룹장 생성·폐기 성공, 일반 멤버 생성·폐기 거절
- 그룹당 두 코드 동시 생성에서 하나만 성공
- 폐기한 코드 get/가입 거절, 새 코드 생성 후 기존 코드 계속 거절
- 코드 가입과 폐기가 동시에 실행될 때 폐기 이후 고아 membership이 생기지 않음
- 남은 한 자리 코드 가입 두 건 경쟁에서 한 건만 성공
- Player의 남은 한 그룹 자리로 서로 다른 그룹 코드 가입이 경쟁할 때 한 건만 성공

### 12.5 요청 처리와 멱등성

- 대상만 초대 수락·거절 가능
- 발신자는 자기 초대만, 그룹장은 모든 초대 취소 가능
- 그룹장만 신청 승인·거절·금지·해제 가능
- 두 기기의 동일 승인·수락 재시도에서 membership 한 개, 인원 +1 한 번만 반영
- 승인과 신청 취소, 승인과 금지, 수락과 코드 폐기 경쟁에서 부분 상태 없음
- Transaction 네트워크 재시도 후 같은 최종 결과를 반환하고 applicant count를 중복 증가시키지 않음

### 12.6 쿼리와 비용

- 그룹명·대표 캐릭터명 prefix query가 같은 Group ID를 중복 표시하지 않음
- query에 필요한 `status` 조건이 없으면 Rules가 list를 거절
- 초대코드 collection list와 임의 전체 스캔 거절
- 내 그룹·요청 Projection query가 타 Player의 비공개 관계를 반환하지 않음
- 명령별 Rules 문서 접근 횟수와 Firestore 복합 인덱스 요구사항 확인

필요한 복합 인덱스는 Repository 쿼리와 함께 `firestore.indexes.json`에 고정한다.

- `groups`: `status + normalizedName + documentId`
- `groups`: `status + normalizedRepresentativeCharacterName + documentId`
- `groups`: `status + lastActivityAt desc + documentId`
- Player 하위 `groupRelations`: `relation + updatedAt desc`
- 그룹 하위 `joinRelations`: `kind + status + createdAt`
- 인증 Character 정확한 이름 검색: 현재 Character 검색 계약의 상태·이름 필드 조합

구현에서 실제 정렬 또는 query 조건을 변경하면 인덱스만 임의로 추가하지 않고 이 절과 Rules의 list 조건을 함께 갱신한다.

## 13. 구현 완료 조건

- Domain/DTO/mapper/Repository가 이 문서 경계를 따르고 Player 단위 테스트를 통과한다.
- `firestore.rules`와 `firestore.indexes.json` 변경이 Emulator 통합 테스트를 통과한다.
- 전체 `flutter test`와 `flutter analyze`가 통과한다.
- 최소 두 Player·두 기기에서 초대, 신청 승인, 코드 가입과 동시성 핵심 경로를 확인한다.
- Rules 배포는 사용자 지시에 따라 별도로 수행한다. 앱 기능을 배포된 Rules보다 먼저 실사용 경로에 노출하지 않는다.
- 문서·코드·Rules가 일치하는지 Codex 재검토 후 다음 작업으로 이동한다.

## 14. Cursor 구현 단위

Task-11 전체를 한 번에 연결하지 않고 아래 순서로 각각 표적 테스트가 가능한 커밋 단위로 진행한다.

1. **기반·생성·읽기:** Domain/DTO, 그룹 생성, Player membership state, 내 그룹·검색·기본 상세, 생성 Rules와 query 인덱스
2. **초대·신청:** Character 검색, join relation과 Player Projection, 수락·거절·취소, applicant stats, 관련 Rules
3. **신청 관리:** 그룹장 승인·거절·금지·해제, 정원 및 Player 50개 경쟁 처리
4. **초대코드:** 생성·폐기·표시 정책·정확한 코드 조회·즉시 가입과 폐기 경쟁
5. **통합 검증·UI 정리:** 요청 현황, 오류 매핑, Emulator 동시성, 전체 테스트와 analyze

각 단위에서 다음 단계의 쓰기를 미리 허용하지 않는다. 현재 단위의 Rules와 Repository 테스트가 통과한 뒤 다음 단위로 이동한다.
