# AI CONTEXT (2026)

## 프로젝트
- LOSTPARTY
- Flutter 기반 로스트아크 레이드 모집 앱
- AI 기반 개발 (ChatGPT + Cursor)

---

## 아키텍처
- MVVM
- feature-first 구조
- repository pattern
- local → firebase 전환 고려

---

## 현재 브랜치
- feature/account-character-dashboard

---

## 완료 상태

### 구조
- 폴더 구조 생성 완료
- feature-first 구조 적용
- domain / data / presentation 분리 완료

### 레이드 데이터
- raid_base.dart 구현 완료
- raid_variation.dart 구현 완료
- local_raid_data_source.dart 구현 완료
- raid_master_repository.dart 구현 완료
- raid_master_repository_impl.dart 구현 완료

### 모집글 도메인
- party_recruitment.dart 구현 완료
- PartyRole / RecruitmentStatusType / ExperienceLevel enum 정의 완료

### recruitment_list 데이터 레이어
- recruitment_list_repository.dart 구현 완료
- local_recruitment_list_data_source.dart 구현 완료
- recruitment_list_repository_impl.dart 구현 완료
- mock 모집글 데이터 6개 작성 완료

### recruitment_list presentation layer
- recruitment_list_view_model.dart 구현 완료
- recruitment_list_page.dart 구현 완료
- recruitment_card.dart 구현 완료
- 앱 셸의 두 번째 탭에 RecruitmentListPage 연결 완료
- mock 모집글 6개 화면 표시 완료

### 앱 셸 및 내 계정
- StatefulShellRoute 기반 하단 탭 구조 적용 완료
- 첫 번째 탭은 내 계정, 두 번째 탭은 파티 모집으로 구성
- PageView 스와이프와 탭별 Navigator 스택 적용
- Android 뒤로가기와 iOS 화면 전환을 고려한 공통 라우팅 기반 구성

### Lost Ark API 기반
- Dio 공통 클라이언트와 API 설정 구현 완료
- 요청 직전에 JWT를 읽어 Authorization 헤더에 적용
- JWT는 flutter_secure_storage에 보관하며 화면과 로그에 원문을 노출하지 않음
- 토큰이 없으면 네트워크 요청을 시작하지 않고 안내 후 앱 탐색을 계속할 수 있음
- HTTP 상태, 타임아웃, 네트워크 및 응답 형식 오류를 타입으로 구분
- `GET /characters/{characterName}/siblings` 연동 완료
- DTO, JSON 변환, mapper, remote data source, repository 계층 구현 완료
- 내 계정 화면에서 대표 캐릭터명으로 원정대 캐릭터 조회 및 최소 목록 표시
- Galaxy Z Fold6 실기기에서 JWT 저장, 캐릭터 검색, 실제 API 응답 확인 완료
- 종합 상세 API의 `ArmoryProfile` 연동 완료
- 조회 캐릭터의 전투력, 아이템 레벨, 전투 레벨, 직업, 서버 표시 완료

### 캐릭터 역할별 세팅 저장 설계
- 캐릭터 기본 정보와 역할별 상세 세팅 스냅샷을 분리하여 저장
- 동일 캐릭터를 역할마다 중복 저장하지 않고 하나의 캐릭터에 여러 스냅샷 연결
- 역할은 직업이나 각인으로 자동 확정하지 않고 스냅샷 저장 시 사용자가 선택
- 서포터형 직업은 바드, 발키리, 도화가, 홀리나이트의 4개 직업
- 서포터형 직업은 `support`와 `dealer` 스냅샷을 각각 저장 가능
- 그 외 모든 직업은 딜러군으로 분류하고 `dealer` 스냅샷만 저장
- 파티 지원 시 저장된 역할별 스냅샷을 기준으로 지원 가능한 역할 결정
- 역할 판정을 위한 자동 분석은 경고 또는 추천 용도로만 사용하고 사용자 선택을 우선

### 조회 캐릭터와 대표 캐릭터
- `lookupCharacterName`: siblings 및 최초 상세 API 호출에 사용하는 조회 기준 캐릭터명
- `representativeCharacterId`: 사용자가 앱 내부에서 선택한 계정 대표 캐릭터
- Lost Ark API가 공식 대표 캐릭터를 제공한다고 가정하지 않음
- 계정 최초 등록 시 조회 캐릭터를 로컬 대표 캐릭터 기본값으로 사용할 수 있음
- 대표 캐릭터는 같은 로컬 계정 그룹의 캐릭터 중 언제든 변경 가능
- 대표 캐릭터 변경에는 쿨타임이나 API 재호출을 요구하지 않음
- 대표 캐릭터 변경은 로컬 설정만 갱신

### 계정 로컬 DB 기반
- Drift `game_accounts`, `account_characters` 스키마 버전 1 구현
- 메인/부계정 구분, 계정 표시명, 조회 캐릭터명 저장
- 로컬 대표 캐릭터 ID와 기본 표시 개수 6개 저장
- 대표 캐릭터가 같은 계정 소속인지 저장 계층에서 검증
- 대표 캐릭터와 표시 개수 변경은 API 호출 없이 로컬에서 처리
- siblings API 조회 성공 시 메인 계정과 전체 캐릭터를 트랜잭션 저장
- 최초 조회 캐릭터를 로컬 대표 캐릭터 기본값으로 설정
- 재조회 시 사용자가 변경한 대표 캐릭터가 목록에 남아 있으면 선택 유지
- 저장된 메인 계정과 캐릭터를 앱 시작 시 로컬 DB에서 조회
- 계정당 기본 최대 6개를 반응형 2~4열 캐릭터 그리드로 표시
- 캐릭터가 6명 미만이면 저장된 실제 캐릭터 수만 표시
- 사용자 표시 순서 설정 전에는 아이템 레벨 내림차순으로 상위 6개 표시
- 사용자 표시 순서가 있으면 사용자 설정을 아이템 레벨 정렬보다 우선
- 조회 캐릭터 상세 API의 전투력을 해당 로컬 캐릭터에 저장하여 카드에 표시
- 상세 조회 전 캐릭터의 전투력은 `-`로 표시
- siblings 재조회 시 기존 전투력, 표시 여부 및 사용자 표시 순서 보존

### 테스트
- local_recruitment_list_data_source_test.dart 작성 및 통과
- recruitment_list_repository_impl_test.dart 작성 및 통과
- flutter analyze 이후 테스트 정상 동작 확인
- API 인증 저장소, Dio 클라이언트, DTO mapper, remote data source 테스트 추가
- 내 계정 ViewModel 및 페이지 테스트 추가
- 탭 이동, 스와이프, 토큰 안내 및 토큰 비노출 widget 테스트 추가
- flutter analyze 통과
- flutter test 61개 통과

---

## 데이터 구조 핵심

### RaidBase
- raidBaseId
- name
- partySize
- gateCount
- difficultyIds

### RaidVariation
- raidId
- raidBaseId
- difficultyOrder
- difficultyLabel
- minItemLevel
- rewardGold

### PartyRecruitment
- id
- title
- raid (raidId + gateProgress)
- leader (characterName / className / role)
- memberSummary (currentCount / maxCount)
- recruitmentStatus
  - status (recruiting / closed / completed)
  - roles
    - dealer (current / target / remaining)
    - support (current / target / remaining)
- requirements
  - minCombatPower
  - experienceLevel (5단계)
- schedule
  - raidStartAt
  - maxPlayHours (null = 클리어시)
  - recruitmentOpenedAt
  - recruitmentClosedAt

---

## enum

### PartyRole
- dealer
- support

### RecruitmentStatusType
- recruiting
- closed
- completed

### ExperienceLevel
- tryLevel
- clearExp
- multiClearExp
- semiExperienced
- experienced

---

## 레이드 데이터 관리 방식
- 현재: local hardcoding
- repository 통해 접근
- UI는 데이터 소스 모름
- 추후 Firebase 교체 가능 구조

---

## 현재 상태 요약

- recruitment_list 기준 Domain / Data / Presentation Layer 1차 구현 완료
- 내 계정이 첫 화면이며 파티 모집은 두 번째 하단 탭에서 접근
- mock 모집글 6개가 RecruitmentCard 목록으로 표시됨
- UI는 ViewModel을 통해 데이터 조회
- ViewModel은 Repository를 통해 mock 데이터 조회
- Lost Ark API JWT 등록 및 안전한 로컬 보관 가능
- 대표 캐릭터명 기반 원정대 캐릭터 조회 가능
- 실제 Android 실기기 API 통신 검증 완료
- Drift 의존성은 준비됐으나 계정 API 응답의 로컬 DB 저장은 아직 구현하지 않음
- Firebase 연동은 아직 없음
- flutter analyze 통과
- flutter test 46개 통과

---

## 다음 작업

1. 대표 캐릭터 변경 및 표시 캐릭터 관리 UI 구현
2. 캐릭터 카드에서 상세 화면으로 이동하는 route 구현
3. 부계정 추가 흐름 구현
4. 역할별 스냅샷에 포함할 상세 API 필드 및 JSON 저장 범위 확정

---

## 주의 사항

- UI에서 DataSource 직접 접근 금지 (Repository만 사용)
- JWT를 소스, 문서, 로그, 테스트 결과에 기록하지 않음
- 실제 토큰은 flutter_secure_storage를 통해서만 저장
- API DTO와 Domain Entity를 mapper로 분리
- Drift 저장 계층은 아직 구현하지 않음
- 서포터형 직업 목록 변경 가능성을 고려해 한 곳에서 관리
- API 호출 간격을 코드에 고정하지 않고 설정값 또는 서버 응답 기준으로 관리
