# DEV LOG (2026)

## 📌 1. 프로젝트 초기 설계

- Flutter 기반 앱 생성
- Git 연결 완료
- docs 구조 생성 (MVP.md / DEV_LOG.md)

---

## 📌 2. 개발 방식 정의

- ChatGPT → 설계 / 구조 / 작업 분해
- Cursor → 코드 생성
- 작업은 반드시 단계별 진행

---

## 📌 3. 아키텍처 결정

- MVVM 패턴 적용
- feature-first 구조 채택
- repository pattern 도입
- local → remote(Firebase) 전환 가능 구조 설계

---

## 📌 4. 레이드 데이터 설계

### RaidBase
- 레이드 공통 정보
- gateCount / difficultyIds 포함

### RaidVariation
- 실제 모집글에서 사용하는 레이드 단위
- raidId 기준 참조

---

## 📌 5. 모집글 데이터 설계

### 핵심 구조
- raidId 기반 구조
- gateProgress (start / end)
- 역할별 모집 상태 (dealer / support)
- memberSummary

### 조건
- minCombatPower
- experienceLevel (5단계 고정)

### 숙련도
- tryLevel
- clearExp
- multiClearExp
- semiExperienced
- experienced

### 시간
- raidStartAt
- maxPlayHours (null = 클리어시)
- recruitmentOpenedAt
- recruitmentClosedAt

---

## 📌 6. 데이터 관리 방식 결정

- 레이드 데이터는 앱 내부 하드코딩
- repository를 통해 접근
- UI에서 직접 접근 금지
- 추후 Firebase로 교체 가능하게 설계

---

## 📌 7. 폴더 구조 설계 및 생성

- shared/raid_master
- features/recruitment_list

구조:

- domain (entities / repositories)
- data (datasources / repositories)
- presentation (viewmodels / pages / widgets)

---

## 📌 8. 구현 완료 상태

- raid_base.dart 생성 완료
- raid_variation.dart 생성 완료
- raid_master_repository.dart 생성 완료
- local_raid_data_source.dart 생성 완료
- raid_master_repository_impl.dart 생성 완료
- party_recruitment.dart 생성 완료

---

## 📌 9. 당시 작업 기준 상태
- 당시 기준으로 모집글 리스트 기능 구현 직전 상태였음
- 다음 작업 후보로 아래 항목들을 계획했음:
  - local_recruitment_list_data_source.dart 작성
  - mock 모집글 데이터 생성
  - recruitment_list repository 구현

---

## 📌 10. 모집글 리스트 데이터 레이어 구현

다음 파일 작성 완료:

- features/recruitment_list/domain/repositories/recruitment_list_repository.dart
- features/recruitment_list/data/datasources/local_recruitment_list_data_source.dart
- features/recruitment_list/data/repositories/recruitment_list_repository_impl.dart

### 구현 내용
- RecruitmentListRepository 인터페이스 정의
- LocalRecruitmentListDataSource 구현
- mock 모집글 데이터 6개 작성
- RecruitmentListRepositoryImpl 구현
- repository → data source 연결 완료

---

## 📌 11. 테스트 작성 및 실행 확인

다음 테스트 파일 작성 완료:

- test/local_recruitment_list_data_source_test.dart
- test/recruitment_list_repository_test.dart

### 테스트 내용
- LocalRecruitmentListDataSource fetchRecruitments() 결과 검증
- mock 데이터 개수 및 필드값 검증
- recruitment status / null maxPlayHours 케이스 검증
- RecruitmentListRepositoryImpl getRecruitments() 동작 검증
- repository 결과와 data source 결과 일치 여부 검증

### 확인 사항
- flutter analyze 이후 테스트 정상 인식 확인
- 개별 테스트 실행 통과
- 전체 테스트 실행 시 기존 기본 widget_test.dart 영향 여부 별도 확인 필요

## 📌 12. 레이드 데이터 로컬 작업
- 자료 입력
- 각 레이드 데이터가 실제 인게임 데이터와 동일하게 입력되었는지 확인 완료.

---

## Task-002. Recruitment List Presentation Layer 구현

### 완료 파일
- features/recruitment_list/presentation/viewmodels/recruitment_list_view_model.dart
- features/recruitment_list/presentation/pages/recruitment_list_page.dart
- features/recruitment_list/presentation/widgets/recruitment_card.dart
- lib/main.dart
- test/widget_test.dart

### 구현 내용
- RecruitmentListViewModel 구현 완료
  - MVVM 구조 유지
  - Repository를 통해 mock 모집글 데이터 조회
  - loading / error / recruitments 상태 관리
- RecruitmentListPage 구현 완료
  - ViewModel을 통해 데이터 조회
  - 모집글 목록 화면 구성
  - mock 모집글 6개 표시
- RecruitmentCard 구현 완료
  - 모집글 제목
  - 레이드 ID 및 관문 범위
  - 리더 정보
  - 현재 인원 / 최대 인원
  - 딜러 / 서포터 모집 상태
  - 최소 전투력 / 숙련도 / 플레이 시간 표시
- main.dart 연결 완료
  - 앱 시작 화면을 RecruitmentListPage로 변경
- widget_test 수정 완료
  - counter 테스트를 모집글 목록 표시 테스트로 변경

### 검증 결과
- flutter analyze 통과
- flutter test 통과
- 전체 테스트 12개 통과

---

## Task-003. 문서 최신화

### 수정 파일
- docs/AI_CONTEXT.md
- docs/DEV_LOG.md

### 반영 내용
- 현재 브랜치를 feature/recruitment-list-ui 기준으로 정리
- Recruitment List Presentation Layer 완료 상태 반영
- main.dart에서 RecruitmentListPage 실행 상태 반영
- widget_test가 모집글 목록 표시 테스트로 변경된 상태 반영
- flutter analyze 통과 상태 반영
- flutter test 12개 통과 상태 반영
- 다음 작업 후보를 현재 구현 이후 단계로 갱신

### 현재 기준
- 코드 변경 없음
- MVP.md 변경 없음
- ai_rules.md 변경 없음

---

## Task-004. Lost Ark API 로컬 저장 기반 준비

### 추가 의존성
- drift
- drift_flutter
- drift_dev (개발용 코드 생성)

### 사용 목적과 선택 이유
- 계정과 여러 캐릭터의 관계, 마지막 API 갱신 시각, 자동 갱신 설정을 SQLite에 구조화하여 저장
- 장비, 스킬, 각인, 카드, 보석 등 크고 변경 가능성이 있는 상세 API 응답은 JSON으로 함께 보존
- 타입 안전한 쿼리, 트랜잭션, 스키마 버전 및 마이그레이션을 지원하여 단순 JSON 파일보다 안정적인 로컬 데이터 관리 가능
- 기존 MVVM 및 Repository 구조 안에서 저장 구현을 교체하거나 테스트하기 쉬움

### 현재 범위
- 로컬 DB 사용을 위한 의존성만 추가
- DB 테이블, DAO, DataSource 및 Repository 연동은 아직 구현하지 않음
- 실제 저장 구조는 Lost Ark API DTO 범위가 확정된 뒤 구현 예정

---

## Task-005. 앱 셸 및 공통 내비게이션 기반

### 구현 내용
- StatefulShellRoute 기반 하단 탭 구조 적용
- 첫 번째 탭을 내 계정, 두 번째 탭을 파티 모집으로 구성
- PageView 스와이프와 하단 탭 선택 상태 동기화
- 탭별 Navigator 스택과 공통 뒤로가기 기반 구성
- 기존 RecruitmentListPage를 두 번째 탭에 유지

---

## Task-006. Lost Ark API 인증 및 통신 기반

### 인증
- 사용자가 앱에서 Lost Ark JWT를 직접 등록, 변경, 삭제할 수 있는 화면 구현
- flutter_secure_storage로 JWT 보관
- 저장된 JWT 원문을 입력창, 상태 화면 및 로그에 다시 노출하지 않음
- 토큰이 없으면 요청을 시작하지 않고 안내 다이얼로그 표시
- 안내를 닫은 뒤에도 앱의 다른 화면을 계속 탐색할 수 있도록 구성

### 공통 API 클라이언트
- Dio 기반 Lost Ark API 공통 클라이언트 구현
- API base URL과 connect/send/receive timeout 설정
- 요청 직전에 토큰을 읽어 Authorization 헤더 적용
- 401, 404, 429, 5xx, timeout, network, invalid response 오류 분류
- 진단 로그에는 HTTP method와 status만 남기고 URL, header, JWT 제외

### 원정대 캐릭터 조회
- `GET /characters/{characterName}/siblings` endpoint 연동
- DTO와 json_serializable 생성 코드 구성
- API DTO에서 Domain Entity로 변환하는 mapper 구현
- remote data source와 AccountRepository 구현체 연결
- 내 계정 ViewModel에서 조회, 로딩, 결과 및 오류 상태 관리
- 내 계정 화면에서 대표 캐릭터명 입력 후 원정대 캐릭터 목록 표시

### 플랫폼 설정
- Android 인터넷 권한 및 secure storage를 위한 최소 SDK/백업 설정 반영
- iOS Keychain 사용을 위한 entitlements 연결
- flutter_secure_storage 플러그인 등록 파일 반영

### 검증
- Galaxy Z Fold6(SM_F956N) 실기기 빌드 및 설치 성공
- 사용자가 앱에 JWT를 직접 입력한 뒤 저장 동작 확인
- 실제 캐릭터명 검색과 Lost Ark API 응답 표시 확인
- 저장소 민감정보 검사 결과 실제 JWT 없음
- flutter analyze: issue 0개
- flutter test: 전체 46개 통과

### 현재 범위
- siblings 응답은 화면에 표시하지만 Drift 로컬 DB에는 아직 저장하지 않음
- 추가 캐릭터 상세 endpoint 및 계정 상세 화면은 다음 작업 범위
