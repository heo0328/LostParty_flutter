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
- feature/lost-ark-api-client

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

### 테스트
- local_recruitment_list_data_source_test.dart 작성 및 통과
- recruitment_list_repository_impl_test.dart 작성 및 통과
- flutter analyze 이후 테스트 정상 동작 확인
- API 인증 저장소, Dio 클라이언트, DTO mapper, remote data source 테스트 추가
- 내 계정 ViewModel 및 페이지 테스트 추가
- 탭 이동, 스와이프, 토큰 안내 및 토큰 비노출 widget 테스트 추가
- flutter analyze 통과
- flutter test 46개 통과

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

1. 실제 siblings 응답을 기준으로 계정 및 캐릭터 로컬 DB 스키마 설계
2. Drift table / DAO / local data source 구현
3. API 조회 결과와 마지막 갱신 시각 저장 정책 정의 및 구현
4. 계정 화면 상세 UI에 필요한 추가 Lost Ark API endpoint와 DTO 범위 결정
5. 이후 모집글 mock 데이터와 raid master 데이터의 raidId 정합성 확인

---

## 주의 사항

- UI에서 DataSource 직접 접근 금지 (Repository만 사용)
- JWT를 소스, 문서, 로그, 테스트 결과에 기록하지 않음
- 실제 토큰은 flutter_secure_storage를 통해서만 저장
- API DTO와 Domain Entity를 mapper로 분리
- Drift 저장 계층은 아직 구현하지 않음
