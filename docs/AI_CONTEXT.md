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

## 현재 기준 브랜치
- main

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
- Drift로 메인 계정과 전체 캐릭터 기본 정보를 저장함
- 대표 캐릭터, 표시 여부, 표시 개수, 사용자 표시 순서를 로컬에서 관리함
- 대표 캐릭터는 항상 첫 번째로 표시되며, 숨김 시 아이템 레벨이 가장 높은 다른 캐릭터가 대표를 승계함
- Drift v2에서 캐릭터별 dealer/support 상세 JSON 스냅샷을 독립 저장함
- 같은 역할 갱신은 해당 스냅샷만 교체하며 계정 재조회 후에도 스냅샷을 유지함
- 캐릭터 카드에서 상세 화면으로 이동할 수 있음
- 상세 화면의 세팅 저장/갱신은 실제 종합 상세 API를 호출하며 테스트 fixture를 사용하지 않음
- 서포터형 직업은 dealer/support 저장 위치를 선택하고 두 스냅샷을 독립 유지함
- 상세 화면에서 룬, 보석 대상 스킬, 아크그리드 조건 및 포인트 경고를 표시함
- 실제 Fold6에서 딜러/서포터 세팅의 개별 저장 및 유지 확인 완료
- Galaxy Z Fold6 profile 빌드에서 캐릭터 관리 스크롤과 설정 유지 검증 완료
- AppBar와 Scaffold는 동일한 surface 배경을 사용해 스크롤 시 색상 변화가 없음
- 게임 카탈로그와 캐릭터 세팅 분석기가 연결됨
- 바드의 깨달음 1티어 노드로 `바드`/`딜바드` 계열과 support/dealer 역할을 감지함
- 감지 결과는 카탈로그 버전, 계열, 역할 및 일치 노드를 포함하며 사용자 저장 역할을 덮어쓰지 않음
- 미지원 직업, 계열 미감지 및 복수 계열 감지를 정상적인 분석 상태로 구분함
- 기존 armory 원본 JSON을 유지하고 스냅샷 로딩 시 현재 카탈로그로 분석 결과를 재생성함
- `CharacterBuildDraft`로 API 조회/분석과 승인 저장 경계를 분리함
- draft 생성은 원본 JSON, 프로필, 분석 결과 및 조회 시각을 메모리에 반환하며 로컬 DB를 변경하지 않음
- commit은 사용자가 선택한 역할을 우선하며 감지 역할이 달라도 저장을 허용함
- commit 시 선택 역할 스냅샷과 최신 프로필을 단일 트랜잭션으로 저장하고 반대 역할 스냅샷을 보존함
- 캐릭터 상세 화면의 세팅 갱신은 먼저 `CharacterBuildDraft`를 조회하고 스크롤 가능한 미리보기 다이얼로그를 표시함
- 미리보기에서 프로필, 계열 통칭, 감지 역할, 룬 및 분석 경고와 저장 역할을 확인할 수 있음
- 감지 역할과 선택 역할이 다르면 안내하지만 특수 세팅 저장을 허용함
- 취소 시 draft를 폐기하고 기존 데이터를 유지하며 승인 성공 후에만 스냅샷을 다시 로드함
- 조회와 commit 진행 상태를 분리하고 중복 요청 및 중복 저장을 방지함
- Firebase 연동은 아직 없음
- flutter analyze 통과
- flutter test 102개 통과

---

## 다음 작업

1. 카탈로그 아이덴티티 스킬로 보석 대상 스킬 분류 보완
2. 사용자 메모를 정적 기준정보와 분리해 로컬 DB에 저장
3. 캐릭터 요약 카드에 계열 통칭, 역할, 메모 및 경고 요약 표시
4. 좁은 화면 1열, 펼친 Fold6 2열 중심의 가용 폭 기반 반응형 카드 배치
5. 내 캐릭터 카드와 파티 지원자 카드의 정보 표현 통합
6. 다른 직업 카탈로그 데이터 확대
7. 부계정 추가 흐름 구현

---

## 직업별 기준정보 및 캐릭터 요약 확장 기준

### 용어
- `직업`: Lost Ark API의 `CharacterClassName`으로 식별하는 캐릭터 클래스
- `계열`: 직업별 깨달음 1티어 노드로 구분하는 세팅 분류
- `인게임 통칭`: 계열이나 주요 조합을 사용자가 부르는 표시 이름이며 API 원문 이름과 분리
- `역할`: 파티 지원 및 역할별 스냅샷 저장에 사용하는 `dealer` 또는 `support`
- `주요 아크그리드 조합`: 특정 계열과 추가 아크패시브 노드 및 코어 조건의 조합

### 데이터 소유와 저장 경계
- 직업, 깨달음 1티어 노드, 통칭, 역할, 아이덴티티/아크패시브 스킬 및 주요 아크그리드 조합은 앱에 포함된 정적 기준정보로 관리
- 정적 기준정보는 Git으로 버전 관리하는 JSON 카탈로그로 제공하고 UI와 분석기는 Repository를 통해 조회
- 캐릭터 개인 메모는 역할별 스냅샷이 아닌 캐릭터 공통 사용자 데이터로 저장
- 선호 조합은 캐릭터별 사용자 선택값으로 저장하고 정적 조합 정의와 분리
- 세팅 스냅샷 갱신, 정적 기준정보 업데이트 및 사용자 메모 수정은 서로의 데이터를 덮어쓰지 않음

### 분석과 역할 선택
- 깨달음 1티어 노드와 직업별 기준정보로 계열 및 역할을 감지
- 감지 역할은 추천과 경고를 위한 분석 결과이며 저장 역할을 자동 확정하지 않음
- 실제 저장 위치는 사용자가 선택한 역할을 우선
- 감지 역할과 선택 역할이 다르면 미리보기에서 안내하고 특수 세팅 저장은 허용
- API에서 새 세팅을 조회한 뒤 메모리에서 분석하고, 사용자 승인 전에는 기존 로컬 스냅샷을 변경하지 않음

### 카드와 반응형 화면
- 캐릭터 요약 카드는 캐릭터명, 직업, 계열 통칭, 역할, 개인 메모, 선호 조합 및 경고 요약을 공통 표현 대상으로 사용
- 내 캐릭터와 파티 지원자는 동일한 요약 표현 모델을 사용하되 각 기능의 도메인 데이터는 분리
- 좁은 화면은 1열, 펼친 Fold 화면은 2열을 중심으로 기기 종류가 아닌 실제 가용 폭으로 열 수를 결정

### 단계별 입력 원칙
- 첫 구현 단계에서는 정적 기준정보의 구조와 검증 규칙을 먼저 구현
- 직업별 노드, 통칭, 스킬 및 조합의 수기 입력은 카탈로그 구조가 확정된 뒤 별도 작업 단위로 진행
- 수기 입력은 우선 한 직업의 최소 샘플로 구조와 분석 흐름을 검증한 다음 전체 직업으로 확대

### 정적 카탈로그 Domain 구현 상태
- `shared/game_catalog`에 feature와 독립적인 정적 카탈로그 Domain 모델 구현 완료
- 카탈로그 버전, 직업, 계열, 특수 스킬, 주요 아크그리드 조합 및 코어 요구사항 모델 정의 완료
- 기존 account/recruitment 역할 타입은 변경하지 않고 카탈로그 전용 역할 타입을 사용하며 실제 분석 연결 단계에서 명시적으로 변환
- 스키마 버전, 필수 문자열, 중복 식별자, 지원 역할, 계열 참조 및 코어 포인트 범위 검증 구현 완료
- JSON asset 로딩 계층과 바드 최소 데이터까지 구현했으며 다른 직업 데이터는 아직 입력하지 않음

### 바드 1차 카탈로그 데이터
- Lost Ark API의 직업명은 fixture에서 확인된 한글 `바드`를 사용하고 영문 `BARD`는 별칭으로 저장
- 기본 역할은 `support`, 지원 역할은 `dealer`와 `support`
- `완벽한 화음`은 통칭 `바드`, 역할 `support`, 관련 추가 노드는 `세레나데 코드`
- `진실된 용맹`은 통칭 `딜바드`, 역할 `dealer`, 관련 추가 노드는 `템페스트 필드`
- `용맹의 세레나데`와 `구원의 세레나데`는 두 계열이 공통으로 사용하는 아이덴티티 스킬로 분류
- 세부 아크그리드 코어 조합은 1차 카탈로그에 입력하지 않음

### 아크그리드 상세 조합 후속 범위
- 1차 앱에서는 계열/추가 노드 발동 조건과 14P 최소 효과 및 유물 이상 17P 효과만 검증
- 직업별 전체 해/달/별 코어 수기 입력은 앱 1차 완성 이후 진행
- 사용자가 3코어 조합을 선택해 통칭과 숫자 순서 별칭을 지정하는 기능은 후속 범위
- 조합별 개인 메모와 지원자 장착 조합 일치 표시는 후속 범위
- 정적 코어 기준정보, 실제 장착 코어에서 계산한 일치 결과 및 사용자 메모를 서로 분리

### 다음 채팅 인계
- 바드 카탈로그 기반 계열 및 역할 감지 구현 완료
- 다음 채팅은 `docs/NEXT_WORK.md`를 먼저 확인하고 병합된 최신 `main`에서 새 작업 브랜치를 생성해 시작
- 다음 첫 단위는 카탈로그 아이덴티티/아크패시브 스킬을 이용한 보석 대상 분류 보완
- API 장착 스킬과 정적 특수 스킬의 카테고리 경계를 유지하며 경고 정확도를 개선
- 사용자 메모, 카드 변경 및 다른 직업 카탈로그 입력은 다음 첫 단위에 포함하지 않음

---

## 주의 사항

- UI에서 DataSource 직접 접근 금지 (Repository만 사용)
- JWT를 소스, 문서, 로그, 테스트 결과에 기록하지 않음
- 실제 토큰은 flutter_secure_storage를 통해서만 저장
- API DTO와 Domain Entity를 mapper로 분리
- Drift 저장 계층은 구현됐으며 스키마 변경 시 migration과 생성 코드 갱신 필요
- 서포터형 직업 목록 변경 가능성을 고려해 한 곳에서 관리
- 직업별 기준정보는 앱에 포함된 버전 관리 JSON, 사용자 메모는 로컬 DB로 분리
- 수기 기준정보를 `ArmorySkills`에 합쳐 장착 스킬로 오인하지 말고 별도 카테고리로 참조
- 아크그리드 조건은 깨달음 1티어 계열과 추가 활성 노드를 각각 검증
- API 호출 간격을 코드에 고정하지 않고 설정값 또는 서버 응답 기준으로 관리
