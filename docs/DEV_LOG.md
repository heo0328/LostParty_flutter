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
- test/recruitment_list_repository_impl_test.dart

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
