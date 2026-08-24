# Player 및 Firebase 구조 변경 사전 검토

## 1. 문서 목적

이 문서는 LOSTPARTY에 `Player` 개념과 Firebase Anonymous Authentication, Cloud Firestore를 도입하기 전에 현재 구현을 기준으로 영향 범위와 적용 방향을 정리한 설계 검토 문서다.

현재 단계의 목적은 구현 범위를 확정하는 것이 아니라 다음 구조적 결정을 분리하고 후속 논의의 기준을 만드는 것이다.

- Firebase 인증 주체와 LOSTPARTY 내부 사용자의 식별 분리
- 한 Player와 여러 Character의 관계
- 파티 공유 상태와 캐릭터 스냅샷의 저장 경계
- 파티현황 화면에 필요한 조회 모델
- 기존 Domain, Repository 및 로컬 DB를 유지하면서 단계적으로 전환할 방법

이 문서에 기록된 권장안은 구현 지시가 아니다. 별도로 `확정`이라고 표시하지 않은 제품 정책과 데이터 구조는 검토 중인 안으로 취급한다.

## 2. 검토 범위와 제외 범위

### 검토 범위

- 현재 Player와 유사한 식별 개념
- Character Domain과 Drift 저장 구조
- 모집, 지원, 가입, 파티원 및 참가 충돌 구조
- 주간 완료와 히스토리 구조
- Player 도입 시 영향받는 계층
- Firebase Anonymous Auth와 Firestore 도입 시 유지 가능한 구조
- `AuthUid`와 `PlayerId` 분리 타당성
- Current State, Snapshot, Local Preference 재분류
- 단계적 적용 순서
- 구현 전에 필요한 제품 결정

### 제외 범위

- 코드, 테스트 및 라우팅 수정
- 파일 이동 또는 리팩터링
- Firebase 패키지 추가와 프로젝트 연결
- Firestore 컬렉션 및 Security Rules 확정
- 복구키 기능 구현
- 파티현황 UI와 필터 정책 확정

## 3. 현재 구조 요약

### 3.1 Player와 유사한 현재 개념

현재 독립적인 `Player` 엔티티와 Repository는 없다.

`LocalGameAccount`는 하나의 계정에 여러 `LocalAccountCharacter`를 묶고 대표 캐릭터를 관리하지만, LOSTPARTY 사용자를 나타내는 모델은 아니다. 메인/부계정 역시 한 사람 아래의 게임 계정 구분이다.

파티 Domain에서는 다음 `userId` 계열 값이 사실상 사람 식별자로 사용된다.

- `RecruitmentState.leaderUserId`
- `RecruitmentPartyMember.userId`
- `RecruitmentApplication.applicantUserId`
- `ApplicationVote.voterUserId`
- `ActiveRaidAssignment.userId`
- `WeeklyRaidClear.userId`
- `WeeklyRaidClear.completedByUserId`

현재 실행 환경에서는 `FakeUserSession('local-user')` 값이 이 식별자 역할을 한다. 따라서 캐릭터와 별개의 사람 단위 키라는 개념은 이미 존재하지만, 이것이 Firebase Auth UID인지 LOSTPARTY 내부 ID인지는 정의되지 않았다.

관련 파일:

- `lib/features/account/domain/entities/local_game_account.dart`
- `lib/features/recruitment_list/domain/services/recruitment_runtime.dart`
- `lib/features/recruitment_list/domain/entities/recruitment_application.dart`
- `lib/features/recruitment_list/domain/entities/recruitment_aggregate.dart`
- `lib/features/recruitment_list/domain/state/recruitment_state_machine.dart`
- `lib/app/router/app_router.dart`

### 3.2 Character 모델과 로컬 저장

캐릭터는 용도별로 다음과 같이 나뉜다.

- API 목록 정보: `CharacterSummary`
- API 상세 정보: `CharacterProfile`
- 로컬 계정에 저장된 캐릭터: `LocalAccountCharacter`
- 역할별 세팅 저장본: `CharacterBuildSnapshot`

Drift에는 다음 테이블이 존재한다.

- `game_accounts`
- `account_characters`
- `character_build_snapshots`

`account_characters.id`는 로컬 DB의 자동 증가 정수다. 다른 설치 환경과 기기에서 동일성을 보장하는 서버용 Character ID가 아니다.

현재 `CharacterBuildSnapshot`은 캐릭터와 역할별 저장본을 최신 값으로 교체하는 구조다. 파티 지원 당시의 불변 제출 스냅샷과는 수명 및 목적이 다르다.

관련 파일:

- `lib/features/account/domain/entities/character_summary.dart`
- `lib/features/account/domain/entities/character_profile.dart`
- `lib/features/account/domain/entities/character_build_snapshot.dart`
- `lib/features/account/data/local/account_database.dart`
- `lib/features/account/data/datasources/local_account_data_source.dart`
- `lib/features/account/data/repositories/account_repository_impl.dart`

### 3.3 모집, 지원, 가입 및 파티원

초기 표시 모델인 `PartyRecruitment`와 현재 명령 흐름에서 사용하는 `RecruitmentAggregate`가 함께 존재한다. 현재 라우터의 생성, 상세, 지원 및 승인 흐름은 `RecruitmentAggregate` 기반이다.

`RecruitmentAggregate`에는 다음이 포함된다.

- 모집글 ID와 제목
- 레이드 메타데이터
- 파티장 사용자 ID
- 승인 정책과 파티 구성 정책
- 현재 파티원 목록
- 사용자 ID를 키로 하는 신청 Map
- 모집 중 여부
- revision과 생성/수정 시각

신청과 파티원은 사람 ID와 Character ID를 함께 보관한다. 상태 머신은 한 사용자 ID가 같은 파티에 두 번 가입하는 것을 막는다. 이는 향후 한 Player가 파티원 한 자리를 차지한다는 규칙으로 재사용할 수 있다.

파티 생성, 지원, 철회, 승인, 투표, 캐릭터 변경과 저장 조정은 클라이언트의 `RecruitmentCommandService`가 수행한다. 현재는 In-memory Repository의 revision 비교와 실패 시 보상 처리로 동시성을 모사한다.

관련 파일:

- `lib/features/recruitment_list/domain/entities/party_recruitment.dart`
- `lib/features/recruitment_list/domain/entities/recruitment_aggregate.dart`
- `lib/features/recruitment_list/domain/entities/recruitment_application.dart`
- `lib/features/recruitment_list/domain/state/recruitment_state_machine.dart`
- `lib/features/recruitment_list/domain/services/recruitment_command_service.dart`
- `lib/features/recruitment_list/data/fakes/in_memory_recruitment_state_repository.dart`

### 3.4 완료와 히스토리

현재 완료 구조는 부분적으로만 존재한다.

- 초기 표시 모델에 `RecruitmentStatusType.completed`가 있다.
- `WeeklyRaidClear`가 캐릭터, 레이드, 주차, 모집글 및 완료 선언자를 기록한다.
- 후보 서비스는 이번 주 완료 캐릭터를 지원 대상에서 제외할 수 있다.

그러나 현재 `RecruitmentAggregate`와 상태 머신에는 다음이 없다.

- 명시적인 파티 완료 상태
- 완료 시각과 완료 선언자
- 완료 당시 파티 구성 스냅샷
- 완료 명령
- 완료 기록 조회 계약

현재 `isRecruiting == false`는 정원 충족 또는 모집 마감과 파티 완료를 구별하지 못한다. 따라서 미진행, 이번 주 완료, 전체 완료 기록을 현재 Aggregate만으로 정확히 분류할 수 없다.

관련 파일:

- `lib/features/recruitment_list/domain/entities/weekly_raid_clear.dart`
- `lib/features/recruitment_list/domain/repositories/weekly_raid_clear_repository.dart`
- `lib/features/recruitment_list/data/fakes/in_memory_weekly_raid_clear_repository.dart`
- `lib/features/recruitment_list/domain/policies/weekly_raid_reset_policy.dart`

## 4. 요구 방향과 현재 구조의 충돌

### 4.1 인증 ID와 사람 ID가 하나의 `userId`로 표현됨

현재 `UserSession.currentUserId`는 인증 주체와 내부 사람 식별자를 구분하지 않는다. 기존 백엔드 설계 문서 역시 모집글, 멤버, 신청 및 완료 데이터에 Firebase UID를 직접 저장하는 안을 사용한다.

Firebase UID를 파티의 영속 사람 ID로 사용하면 앱 재설치 후 새 Anonymous Auth UID를 기존 사용자에게 재연결하기 어렵다.

### 4.2 로컬 Character ID를 서버에서 사용할 수 없음

현재 파티 후보 흐름은 Drift 캐릭터 정수 ID를 문자열로 전달한다. 이 값은 DB 재생성, 재설치 및 다른 기기에서 유지되지 않으므로 Firestore의 영속 Character ID로 사용할 수 없다.

### 4.3 지원 데이터가 완전한 제출 스냅샷이 아님

현재 신청 객체는 클래스, 역할, 아이템 레벨과 전투력을 복사하므로 일부 스냅샷 성격이 있다. 하지만 제출 시각, 데이터 버전, 검증 여부, 서버 Character ID 및 상세 세팅을 포함하는 독립된 불변 모델은 없다.

### 4.4 파티 수명주기가 충분히 표현되지 않음

`isRecruiting`만으로 모집 중, 정원 충족, 모집 마감, 진행 중, 완료, 취소 및 해산을 구분할 수 없다.

### 4.5 실시간 읽기 계약이 명시적이지 않음

`RecruitmentListViewModel`은 Repository가 `Listenable`인 경우 변경 알림을 받는다. 이는 In-memory 구현에는 적합하지만 Firestore 구독을 표현하는 명시적인 Domain 계약은 아니다.

### 4.6 UI가 현재 사용자 ID를 직접 비교함

모집 상세와 수정 화면은 `commandService.currentUserId`를 파티장과 파티원 ID에 직접 비교한다. Player 도입 후에는 인증 UID가 아니라 현재 Player ID를 기준으로 권한과 참여 여부를 판단해야 한다.

관련 파일:

- `lib/features/recruitment_list/presentation/viewmodels/recruitment_list_view_model.dart`
- `lib/features/recruitment_list/presentation/pages/recruitment_detail_page.dart`
- `lib/features/recruitment_list/presentation/pages/recruitment_edit_page.dart`

## 5. 그대로 유지 가능한 구조

다음 구조와 규칙은 Firebase 도입 후에도 재사용 가능하다.

- feature-first와 Domain/Data/Presentation 분리
- Account와 Recruitment feature 경계
- Repository 추상화
- 레이드 및 게임 정적 카탈로그
- `RecruitmentAggregate`의 기본 집합 구조
- 승인 정책과 파티 구성 정책
- 사용자 중복 가입 방지 규칙
- 지원, 철회, 승인 및 투표 상태 전이의 핵심 규칙
- 주간 초기화 및 참가 충돌 정책
- optimistic revision 개념
- Fake Session, Fake Clock, Fake Repository 기반 테스트

로컬 Account DB 역시 전부 제거할 필요가 없다. API 조회 캐시, 캐릭터 표시 순서, 숨김, 선호 역할과 화면 설정은 로컬 저장을 유지할 수 있다. 단, 서버 Player 및 Character와 연결할 영속 ID가 별도로 필요하다.

## 6. 변경이 필요한 핵심 구조

### 6.1 Player Domain과 세션 경계

인증 세션과 Player 세션을 개념적으로 분리한다.

```text
AuthenticatedPrincipal
  authUid

PlayerSession
  playerId
  authUid
```

파티 Domain에는 원칙적으로 `authUid`를 저장하지 않고 `playerId`를 사용한다.

### 6.2 사람 식별 필드의 의미 명확화

권장 필드 의미는 다음과 같다.

```text
leaderUserId       -> leaderPlayerId
member.userId      -> member.playerId
applicantUserId    -> applicantPlayerId
voterUserId        -> voterPlayerId
completedByUserId  -> completedByPlayerId
```

실제 명칭 변경 시점은 별도 작업으로 정한다. 우선 문서와 테스트에서 각 ID의 의미를 확정해야 한다.

### 6.3 서버 영속 Character ID

Drift row ID와 별개의 서버 생성 Character ID가 필요하다.

```text
Player
  Characters
    characterId
    serverName
    characterName
    className
    currentProfile
```

캐릭터명 변경 가능성과 Lost Ark API의 안정적인 캐릭터 식별자 제공 여부가 확인되지 않았으므로, 서버명과 캐릭터명 조합을 영속 ID로 확정하는 것은 보류한다.

### 6.4 명시적인 파티 수명주기

검토 가능한 초기 상태 예시는 다음과 같다.

```text
recruiting
formed
inProgress
completed
cancelled
```

정확한 상태와 전이 권한은 제품 결정이 필요하다. 최소한 모집 마감과 레이드 완료는 별개 상태여야 한다.

### 6.5 파티현황 조회 모델

기존 공개 모집 목록과 별도로 다음 조회 계약이 필요하다.

- 현재 Player가 참가한 미완료 파티
- 선택된 여러 Player가 모두 참가한 파티
- 이번 주 완료 파티
- 전체 완료 기록

다중 Player 교집합 필터는 Firestore 단일 쿼리만으로 일반화하기 어렵다. 예상 Player 수와 기록 규모에 따라 서버 읽기 모델, 제한된 인덱스 또는 클라이언트 교집합 중 하나를 선택해야 한다. 이 판단은 현재 단계에서는 권장 검토사항이며 확정안이 아니다.

## 7. 추천 데이터 모델 방향

다음 구조는 Auth UID와 Player ID 분리를 설명하기 위한 권장 초안이다. 컬렉션명과 세부 필드는 확정되지 않았다.

```text
authBindings/{authUid}
  playerId
  status
  linkedAt

players/{playerId}
  displayName
  representativeCharacterId
  status
  createdAt
  updatedAt

players/{playerId}/characters/{characterId}
  serverName
  characterName
  className
  currentProfile
  currentBuilds
  verifiedAt
  updatedAt
```

`authBindings`는 클라이언트가 임의 변경하지 못하는 서버 관리 데이터여야 한다. 최초 Anonymous Auth 진입 시 서버 명령이 Player를 생성하고 연결하는 구조를 권장한다.

파티 데이터 권장 초안:

```text
recruitments/{recruitmentId}
  leaderPlayerId
  raidMetadata
  status
  counts
  revision
  createdAt
  updatedAt
  completedAt
  completedByPlayerId

recruitments/{recruitmentId}/members/{playerId}
  playerId
  characterId
  submittedCharacterSnapshot
  role
  partyIndex
  joinedAt

recruitments/{recruitmentId}/applications/{playerId}
  applicantPlayerId
  characterId
  submittedCharacterSnapshot
  requestedRole
  status
  createdAt
  decidedAt

recruitments/{recruitmentId}/applications/{playerId}/votes/{voterPlayerId}
  voterPlayerId
  decision
  createdAt
```

지원 또는 가입 당시의 캐릭터 정보는 다음과 같은 별도 불변 값 객체로 저장하는 방향을 권장한다.

```text
CharacterSubmissionSnapshot
  characterId
  characterName
  serverName
  className
  role
  itemLevel
  combatPower
  buildDataVersion
  capturedAt
  verificationStatus
```

## 8. 데이터 성격 재분류

### Current State

여러 사용자가 같은 값을 보거나 서버가 최신 상태를 판정해야 하는 데이터다.

- Player 상태와 Auth binding
- Player 소유 Character와 현재 검증 정보
- 모집글과 현재 파티 상태
- 파티장 및 현재 파티원
- 신청과 승인 상태
- 활성 레이드 참가 배정
- 주간 레이드 완료 상태
- 파티 유지, 진행 및 완료 상태

### Snapshot

특정 행동 시점의 값을 이후 변경과 무관하게 보존하는 데이터다.

- 지원 당시 캐릭터 및 역할별 세팅
- 승인 당시 제출 정보
- 완료 당시 파티원 및 캐릭터 구성
- 모집 생성 당시 레이드 카탈로그 버전과 표시 메타데이터

현재 캐릭터 정보가 갱신되어도 기존 신청과 완료 기록의 Snapshot은 자동 갱신하지 않는다.

### Local Preference

다른 사용자와 공유할 필요가 없고 서버 권한 판정에 사용하지 않는 데이터다.

- 캐릭터 카드 표시 여부와 순서
- 선호 역할
- 파티현황 필터와 정렬
- 현재 선택 탭
- 접힘 및 펼침 상태

대표 캐릭터는 표시용이라는 점은 확정 방향이지만, 여러 기기에서 동기화할지에 따라 Player 프로필 설정 또는 Local Preference가 될 수 있으므로 저장 위치는 추가 결정이 필요하다.

### Static Reference

- 게임 카탈로그
- 레이드 카탈로그
- 역할 및 파티 구성 기준

## 9. Firebase 도입 영향

### 유지 가능한 부분

- Domain 엔티티와 정책
- 상태 머신과 자동화 테스트
- Repository 경계
- 로컬 Fake 구현
- 정적 카탈로그
- ViewModel 계층

### 변경 또는 추가가 필요한 부분

1. 앱 시작 시 Firebase 초기화와 Anonymous Auth 부트스트랩
2. `authUid -> playerId` binding 조회 또는 생성
3. Fake Session과 Firebase/Player Session 조립 분리
4. Firestore 실시간 목록 및 상세 구독 계약
5. Callable Function 기반 명령 계약
6. 서버 Transaction으로 모집, 승인, 인원, 참가 배정 및 완료 원자성 보장
7. Drift 캐릭터와 서버 Character ID 연결
8. Security Rules와 Functions에서 Auth UID와 Player ID binding 검증

현재 `RecruitmentCommandService`는 로컬 Fake와 Domain 테스트 자산으로 유지할 수 있다. 운영 환경의 쓰기는 동일한 Domain 규칙을 서버에서 검증하는 Callable Function 구현으로 교체하는 것이 안전하다.

## 10. AuthUid와 PlayerId 분리 판단

현재 코드 기준으로 분리하는 것이 타당하다.

근거:

- 파티 Domain은 이미 캐릭터와 별개의 문자열 사람 ID를 사용한다.
- 상태 머신은 ID의 발급 주체를 알 필요가 없다.
- Firestore 문서 ID와 Security Rules가 아직 실제 구현으로 고정되지 않았다.
- Anonymous Auth UID를 영속 Player ID로 사용하면 복구 및 재연결 구조가 제한된다.
- 지금 분리하면 기존 Domain을 유지하면서 세션과 저장 구현체를 단계적으로 교체할 수 있다.

복구 기능 자체는 현재 구현하지 않더라도 `AuthUid`와 `PlayerId` 사이의 간접 연결을 데이터 구조에 포함하는 것을 권장한다.

## 11. 단계별 적용 순서

1. `AuthUid`, `PlayerId`, 서버 `CharacterId`, 로컬 DB row ID의 용어와 책임 확정
2. Firebase 없이 Player Domain과 Player Session 계약 도입
3. 파티 Domain의 `userId` 의미를 Player ID로 명확화
4. Drift 캐릭터와 연결할 서버 Character ID 설계
5. 현재 캐릭터 저장본과 파티 제출 Snapshot 분리
6. 파티 모집, 유지, 진행, 완료 및 취소 상태 확정
7. 파티현황과 다중 Player 필터의 Query/Repository 계약을 Fake로 검증
8. 데이터 계약 확정 후 첫 탭 파티현황, 두 번째 탭 내 계정 구조 적용
9. Firebase Anonymous Auth와 Player binding 도입
10. Firestore 실시간 읽기 구현
11. 생성, 지원, 승인, 캐릭터 변경, 완료 명령을 단계적으로 Callable Function으로 이전
12. Security Rules와 Emulator에서 다중 사용자 및 동시성 검증

각 단계는 독립적인 검토, 구현 및 테스트가 가능한 작업 단위로 분리한다. Player와 식별자 경계를 확정하기 전에 UI부터 변경하지 않는다.

## 12. 구현 전 추가 결정사항

### 제품 기획이 필요한 사항

- Player 공개 표시명 및 검색용 고유 ID 제공 여부
- 한 Player가 같은 파티에 여러 Character로 참가할 수 있는지
- 대표 캐릭터 설정의 서버 동기화 여부
- 여러 Lost Ark 계정을 한 Player에 묶는 기준
- 캐릭터 이름 변경 시 동일 캐릭터 추적 방법
- 캐릭터 소유 검증 수준과 갱신 주기
- 모집 마감, 파티 형성, 진행, 완료, 취소 및 해산의 상태 정의
- 완료 선언 권한과 완료 취소 또는 정정 정책
- 완료 당시 멤버와 중도 이탈자 처리
- 이번 주 완료 분류가 파티 완료 기준인지 캐릭터 귀속 기준인지
- 전체 완료 기록의 보존 및 삭제 정책
- 다중 Player 필터에 pending 신청자를 포함할지
- 필터 대상 Player를 친구, 그룹, 최근 참가자 중 어디서 가져올지
- 복구키의 발급, 보관, 만료, 회수 및 재사용 정책
- 복구 후 이전 Auth UID 처리와 복수 Auth UID 연결 허용 여부
- 오프라인 읽기 및 쓰기 허용 범위

### 코드 구조를 기준으로 결정 가능한 사항

- Auth UID와 Player ID를 분리한다.
- 대표 캐릭터를 사람 식별자로 사용하지 않는다.
- 파티 Domain에는 Auth UID 대신 Player ID를 저장한다.
- Drift 자동 증가 캐릭터 ID를 서버 Character ID로 사용하지 않는다.
- Account 로컬 데이터와 파티 서버 상태의 Repository 경계를 유지한다.
- 기존 파티 Aggregate, 정책과 상태 머신은 재사용한다.
- 제출 Snapshot과 현재 Character 상태는 별도 모델로 관리한다.
- 모집 마감과 파티 완료는 별도 상태로 관리한다.
- 운영 명령의 원자성은 서버 Transaction으로 보장한다.
- Firestore 실시간 읽기는 명시적인 구독 계약으로 표현한다.
- 기존 Fake Repository와 상태 머신 테스트를 Firebase 전환 후에도 유지한다.

## 13. 기존 문서와의 관계

`docs/architecture/BACKEND_PARTY_ARCHITECTURE.md`는 Firebase UID를 파티의 사용자 식별자와 Firestore 하위 문서 ID로 직접 사용하는 전제를 포함한다. 이 전제는 본 문서의 `AuthUid`와 `PlayerId` 분리 권장안과 충돌한다.

현재 단계에서는 기존 문서를 수정하지 않는다. 다음 순서로 문서를 정리한다.

1. 본 검토 문서에서 식별자와 제품 정책을 논의한다.
2. 확정된 결정에 따라 `BACKEND_PARTY_ARCHITECTURE.md`의 UID 기반 스키마를 Player ID 기반으로 갱신한다.
3. 확정된 현재 상태만 `../project/AI_CONTEXT.md`에 요약한다.
4. 실제 구현 작업 단위가 결정되면 `../project/NEXT_WORK.md`에 첫 작업 범위와 완료 조건을 기록한다.

## 14. 현재 결론

Firebase 연결 전에 다음 네 가지 경계를 먼저 확정해야 한다.

1. `AuthUid`와 `PlayerId`
2. 서버 영속 `CharacterId`
3. 파티 수명주기와 완료 상태
4. 현재 Character 정보와 행동 시점 Snapshot

이 경계를 먼저 정하면 기존 Domain, 정책, 상태 머신, Repository 및 로컬 캐시를 대규모로 폐기하지 않고 Firebase 구현체를 단계적으로 추가할 수 있다.
