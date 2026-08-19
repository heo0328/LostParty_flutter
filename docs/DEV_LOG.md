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

---

## Task-007. 캐릭터 역할별 세팅 저장 설계

### 설계 원칙
- 캐릭터 기본 정보와 역할별 상세 세팅을 분리하여 저장
- 동일 캐릭터를 역할별로 중복 생성하지 않음
- 하나의 캐릭터에 `dealer` 또는 `support` 역할별 스냅샷을 연결
- 직업과 역할을 분리하며 최종 역할은 사용자가 스냅샷 저장 시 선택
- 각인 등 상세 데이터 분석은 역할 추천이나 경고에만 사용
- 자동 분석 결과보다 사용자의 명시적 선택을 우선

### 직업 분류
- 서포터형 직업: 바드, 발키리, 도화가, 홀리나이트
- 서포터형 직업은 `support`와 `dealer` 스냅샷을 각각 저장 가능
- 위 4개 직업을 제외한 모든 직업은 딜러군으로 분류
- 딜러군 직업은 `dealer` 스냅샷만 저장
- 서포터형 직업 목록은 변경 가능성을 고려하여 한 곳에서 관리

### 캐릭터 기본 정보
`Character`

- 캐릭터명
- 서버명
- 직업
- 전투 레벨
- 아이템 레벨
- 기본 정보 마지막 갱신 시각

### 역할별 세팅 스냅샷
`CharacterBuildSnapshot`

- 대상 캐릭터 ID
- 역할: `dealer` 또는 `support`
- 장비
- 각인
- 보석
- 카드
- 전투 특성
- 역할 판정 및 파티 지원에 필요한 상세 정보
- 스냅샷 저장 시각

검색과 비교에 필요한 값은 구조화된 컬럼으로 저장하고, 상세 API 원본 응답은 JSON으로 함께 보존하는 방식을 검토한다.

### 데이터 갱신 흐름
1. 사용자가 게임에서 저장하려는 세팅을 적용한다.
2. 앱에서 해당 캐릭터의 데이터 갱신을 실행한다.
3. 서포터형 직업은 `서포터 세팅` 또는 `딜러 세팅`을 선택한다.
4. 딜러군 직업은 별도 역할 선택 없이 딜러 세팅으로 갱신한다.
5. 앱이 현재 캐릭터 상세 데이터를 API로 조회한다.
6. 선택된 역할의 스냅샷을 신규 저장하거나 최신 데이터로 교체한다.
7. 다른 역할도 저장하려면 게임 내 세팅을 변경한 뒤 다시 갱신한다.
8. API 호출 간격은 고정된 10초 값이 아닌 설정 또는 서버 응답 기준으로 관리한다.
9. `429 Too Many Requests` 응답을 별도로 처리한다.

### 파티 지원 연계
`PartyApplication`

- 모집글 ID
- 캐릭터 ID
- 역할별 스냅샷 ID
- 지원 역할

동작 원칙:

- `dealer` 스냅샷이 있으면 딜러 모집에 지원 가능
- `support` 스냅샷이 있으면 서포터 모집에 지원 가능
- 두 스냅샷이 있는 서포터형 캐릭터는 양쪽 모집에 선택적으로 지원 가능
- 해당 역할의 스냅샷이 없으면 먼저 해당 세팅 저장을 안내

### 구현 전 확정 항목
- 역할별 스냅샷에 포함할 Lost Ark API endpoint와 필드
- 구조화 컬럼과 원본 JSON의 저장 범위
- 스냅샷 유효기간과 갱신 필요 표시 기준
- 파티 지원 당시 스냅샷을 고정할지 최신 스냅샷을 참조할지
- API 호출 간격과 `429` 재시도 정책

### 현재 범위
- 설계 내용만 확정 및 문서화
- Drift table, DAO, local data source는 아직 구현하지 않음
- 파티 지원 기능은 아직 구현하지 않음

### 조회 캐릭터와 대표 캐릭터 구분
- API 조회를 시작할 때 입력한 캐릭터는 `조회 캐릭터`로 정의
- Lost Ark API 응답에서 공식 대표 캐릭터를 얻었다고 간주하지 않음
- 앱의 `대표 캐릭터`는 로컬 계정 그룹 안에서 사용자가 직접 선택
- 최초 등록 시 조회 캐릭터를 대표 캐릭터 기본값으로 사용할 수 있음
- 대표 캐릭터는 같은 계정 그룹 내에서 횟수 및 시간 제한 없이 변경 가능
- 대표 캐릭터 변경은 API 호출 없이 로컬 `representativeCharacterId`만 갱신
- 실제 선택 UI와 Drift 저장은 계정 로컬 저장 구현 단계에서 추가

---

## Task-008. 조회 캐릭터 프로필 및 계정 DB 기반

### 상세 프로필
- `GET /armories/characters/{characterName}`의 `ArmoryProfile` 연동
- 캐릭터명, 서버, 직업, 전투 레벨, 아이템 레벨, 전투력 DTO 구성
- 쉼표가 포함된 아이템 레벨과 전투력을 숫자 Domain 값으로 변환
- API 입력 캐릭터를 `대표 캐릭터`가 아닌 `조회 캐릭터`로 화면에 표시
- Galaxy Z Fold6 실제 API 호출에서 전투력 표시 확인

### Drift 스키마 버전 1
- `game_accounts` 테이블 추가
- `account_characters` 테이블 추가
- 메인/부계정 구분과 조회 캐릭터명 저장
- 로컬 대표 캐릭터 ID 저장
- 계정당 기본 표시 개수 6개 저장
- 캐릭터 표시 여부와 표시 순서 컬럼 준비
- 계정 삭제 시 소속 캐릭터 cascade 삭제
- 동일 계정의 서버명과 캐릭터명 조합 중복 방지

### 로컬 정책
- 대표 캐릭터는 같은 계정 소속 캐릭터만 지정 가능
- 대표 캐릭터 변경에는 API 호출이나 쿨타임 없음
- 표시 개수는 1개 이상으로 변경 가능
- 역할별 상세 스냅샷 테이블은 상세 필드 확정 후 추가

### 검증
- 상세 프로필 remote data source 및 mapper 테스트 추가
- Drift 인메모리 DB 테스트 4개 추가
- flutter analyze: issue 0개
- flutter test: 전체 55개 통과

### 다음 연결 범위
- siblings 결과를 `game_accounts`, `account_characters`에 트랜잭션 저장 완료
- 최초 조회 캐릭터를 대표 캐릭터 기본값으로 설정 완료
- 재조회 시 사용자가 변경한 대표 캐릭터 선택 유지
- Repository의 원격 조회 성공 결과를 LocalDataSource로 전달하도록 연결
- 앱 생명주기에서 AccountDatabase 생성 및 종료 관리
- widget 테스트는 인메모리 DB를 주입하여 파일 DB 중복 사용 방지
- 저장된 계정 데이터를 앱 시작 시 메인 화면에 표시 완료
- 기본 최대 6개 캐릭터를 화면 폭에 따라 2~4열 그리드로 표시
- 6명 미만 계정은 실제 저장된 캐릭터 수만 표시
- 사용자 설정 전 아이템 레벨 내림차순으로 상위 6개 표시
- 사용자 표시 순서가 저장되면 해당 순서를 우선 적용
- 조회 캐릭터의 상세 전투력을 로컬 캐릭터 데이터에 저장
- siblings 재조회 시 기존 전투력, 표시 여부 및 표시 순서 보존
- 대표 캐릭터 카드에 별표 표시
- 최상단 토큰 상태 및 설정 영역 구성
- 대표 캐릭터 변경 및 표시 캐릭터 관리 UI 구현
- 부계정 추가 흐름 구현
