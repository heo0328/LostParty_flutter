# DEV LOG (2026)

## 2026-09-01 그룹 전용 모집 리스트 실기기 확인

- 사용자가 그룹만 공개 생성 후 그룹원 레이드 모집 리스트 노출이 동작한다고 확인했다.
- 구현: 생성 시 `groups/{groupId}/raidListings/{recruitmentId}` 스냅샷, 공개 첫 페이지와 경로 기반 listing 합치기, listing 실패 격리, 본인 방 제외.
- 쓰지 않은 방식: `recruitments`에 `visibility==group` 쿼리, 목록 Rules의 문서별 그룹 membership `exists`.
- 남은 후속: 생성 후 공개 전환, listing 자리·상태 갱신, 기존 방 listing 보완, 탈퇴 자격 박탈, 목록 필터 UI.
- Git 종료: 기능 커밋 `61fd464`, `main` 병합 커밋 `25c3b44`. 로컬 `main`과 `origin/main`이 일치한다.

## 2026-08-31 그룹 전용 모집 목록(raidListings)

- 그룹만 공개는 공개 `recruitments` 쿼리에 없어 그룹원 모집 리스트에 안 보였다. `visibility==group`을 `recruitments`에 붙이면 목록 전체가 죽을 수 있어 쓰지 않는다.
- 생성 트랜잭션이 `groups/{groupId}/raidListings/{recruitmentId}`에 모집 스냅샷을 쓴다. 목록은 가입 그룹 경로만 읽고 공개 첫 페이지와 합친다. listing 오류는 공개 목록을 유지한다.
- listing create/list Rules와 앱 반영 후 2026-09-01 실기기에서 그룹원 모집 리스트 노출을 확인했다. listing이 없는 기존 방은 재생성 전까지 안 보일 수 있다.

## 2026-08-31 Rules 복잡도 축소 (R1·이벤트·미사용 함수)

- 사용자가 업로드 실패를 복잡도 한도로 보고 최적화를 지시했다. 브랜치 `codex/recruitment-group-link`에서 목록 수정을 유지한 채 축소했다.
- 가입 membership 네 경로의 필드·시각 검사를 `validNewGroupMemberCore`로 모았다. membership state 키 집합을 공통화하고 리더 승인 추가는 기존 add-member 검사를 재사용한다.
- `validPlayerEvent` 중첩 삼항을 유형별 검증 OR로 바꿨다. 호출되지 않는 joinCode path·수동인증 owner helper 2개를 삭제했다.
- 생성 시 그룹 exists/get은 `let`이 아니라 일반 레이드에서 단락되는 OR로 두었다. 청중 검사는 `isCurrentGroupMember` 대신 membership `exists`만 쓴다. 배포는 하지 않았다.

## 2026-08-31 모집 목록 Rules list 거부 수정

- Rules 배포 후 레이드 모집·현황이 `조회 권한을 확인하지 못했습니다`로 비었다. 생성은 되고 목록만 실패했다.
- `canReadRecruitment`에 그룹 membership `exists`가 들어가 공개 목록·내 현황 `list` 쿼리 전체가 거부되었다. 목록은 `canListRecruitment`(공개/리더/멤버 필드)로 분리했다. 재배포 전에는 운영 목록이 복구되지 않는다.

## 2026-08-31 일반/그룹 레이드 생성 연결 (B)

- 전용 브랜치 `codex/recruitment-group-link`. 생성 화면에 일반/그룹 선택을 넣고, 그룹 레이드는 가입 그룹 하나와 visibility를 실제 저장한다.
- 그룹 전용은 기본값이며 Rules에서 그룹원만 읽기·신청할 수 있다. 생성 트랜잭션은 그룹·membership을 먼저 읽는다.
- 가입 그룹이 없으면 생성을 막는다. 공개 목록에 그룹 전용 모집을 섞는 일, 생성 후 공개 전환, 탈퇴 시 자격 박탈, Rules 배포는 하지 않았다.
- 표적 테스트와 변경 파일 analyze를 통과했다. 커밋은 실기기 확인 뒤 사용자 지시로 진행한다.

## 2026-08-31 모집 생성 UI(A) 실기기 확인 및 Git 종료

- 사용자가 생성 UI·완료 표기 크기를 확인한 뒤 문서 최신화와 기능 커밋·푸시·main 머지 커밋·푸시를 지시했다. 레이드 모집 완료는 정상이다.
- A와 상세 완료 표기를 한 브랜치 `codex/recruitment-create-layout`에 포함한다. B는 다음 작업으로 남긴다. Rules·배포는 변경하지 않았다.
- 표적 테스트와 변경 파일 analyze 결과를 재사용한다. Git 완료 SHA는 실제 로그로 확인한다.

## 2026-08-31 모집 생성 간격·역할 높이 및 완료 표기

- 사용자 실기기: 레이드 모집 완료는 정상. 딜러/서포터 역할 드롭다운이 캐릭터 칸보다 낮고, 생성 폼 항목 간격이 답답했다.
- 역할 칸에 보이지 않는 플로팅 라벨 높이를 맞춰 캐릭터 선택과 같은 높이가 되게 했다. 항목 사이 세로 간격을 16에서 21로 늘렸다.
- 모집 상세 파티 구성 제목 옆에, 이번 회차 완료 후 해산 전 또는 반복방 다음주 대기일 때 `이번주 레이드완료`를 상단 모집 제목과 같은 크기·오류색으로 표시한다.

## 2026-08-31 모집 생성 UI 배치(A) 구현

- 사용자가 Rules 복잡도를 최신 상태에서 해결된 것으로 판단하고 구현을 지시했다. main 15eaf4a에서 `codex/recruitment-create-layout`을 생성했다.
- A만 구현했다. 모집 제목·자동 제목·승인 옵션은 유지하고 레이드/난이도, 최소 전투력/숙련도를 한 줄로 배치한다. 좁은 폭·큰 글꼴에서는 접는다.
- 생성 화면에서만 캐릭터와 작은 역할 드롭다운을 한 줄에 둔다. 눈에 보이는 역할 라벨은 제거하고 접근성 이름은 유지한다. 선택 가능한 역할이 둘일 때만 표시하며 유효한 선호 포지션을 선선택한다.
- 일반/그룹 선택과 groupId 저장(B), Rules·배포는 변경하지 않았다. 공용 폼의 한 줄 배치는 수정 화면에도 적용된다.
- 표적 테스트 18개 통과, 변경 파일 analyze에서 불필요 import 1건을 제거했다. 전체 테스트는 한정 UI 변경으로 실기기 전에 재실행하지 않는다. 커밋은 사용자 지시 후 진행한다.

## 2026-08-31 모집 생성 UI 다음 작업 준비 및 Git 최신화

- 사용자 요청으로 문서화만 수행하던 단계에서 준비 문서의 커밋·푸시 및 main 통합 단계로 전환했다. 단일 그룹 매칭과 기존 UI 요구를 유지하고 NEXT_WORK·AI_CONTEXT의 이전 커밋 제외 문구를 갱신했다.
- 원격 fetch 후 코드 기준 main/origin/main eeba05f 일치를 확인했다. 변경 범위는 제품·인계 문서 5개이며 기존 보존 브랜치와 Rules 사본은 유지한다.
- 다음 구현은 최신 main에서 codex/recruitment-create-layout을 생성하여 A(입력 배치·역할 선택)부터 시작한다. B(일반/그룹 선택·서버 연결)는 별도 작업으로 남긴다.
- 문서 내용 검토와 git diff --check로 검증한다. 앱 코드·의존성·Rules 변경이 없어 Flutter 테스트는 재실행하지 않는다. Git 완료 상태와 커밋 ID는 실제 로그 및 최종 보고로 확인한다.

## 2026-08-31 레이드 생성의 단일 그룹 매칭 확정

- 사용자가 그룹 가입·탈퇴가 쉬운 점을 고려해 한 레이드에 그룹 하나만 매칭하기로 최종 결정했다. 이전 다중 그룹 조건부 비용 검토는 종료했다.
- 생성 화면은 일반/그룹 선택 후 가입 그룹 하나를 드롭다운에서 선택한다. 단일 groupId를 유지하며 groupIds·다중 선택 체크박스·다대다 배정은 제외한다. 목록 필터의 복수 그룹 선택 기획은 별개로 유지한다.
- 기존 UI 배치 요청은 그대로 유지하고 제품 문서·NEXT_WORK·AI_CONTEXT를 일치시켰다. 문서만 수정했으며 코드·Rules·커밋·푸시는 변경하지 않았다.

## 2026-08-31 모집 생성 UI 우선 요청 기록

- 이전 그룹 전투력 수정은 4e4ab37, main 머지 eeba05f로 커밋·푸시 완료했고 사용자 실기기 정상 확인을 기록했다.
- 사용자가 모집 생성 UI를 다음 우선 작업으로 지정했다. 최상단 일반/그룹 선택 및 가입 그룹 드롭다운, 기존 제목 유지, 레이드/난이도·캐릭터/작은 역할·최소 전투력/숙련도 한 줄 배치, 역할 라벨/설명 제거와 유효 선호 포지션 선선택을 제품 문서와 NEXT_WORK에 반영한다.
- 다중 그룹은 비용 부담이 작으면 채택하는 조건부 요구다. 기존 단일 groupId와 public 고정 생성/목록 경로를 확인했으며 UI 선택 상태 비용과 서버 조회·권한·탈퇴 처리 비용을 분리해 검토하기로 했다. 계측 없이 비용이 작다고 확정하지 않는다.
- codex/recruitment-create-ui-plan에서 문서만 수정한다. 코드·Rules 변경, 테스트 실행, 배포·커밋·푸시는 하지 않는다. 문서 diff 및 git diff --check로 확인한다.

## 2026-08-31 그룹 전투력 표시 수정 — 실기기 확인 및 Git 종료 승인

- 기반 99a3598, codex/group-combat-power-display. 준비 이후 사용자 진행 지시로 구현했다. 사용자가 그룹원 간 전투력이 정상 표시됨을 확인하고 기능 커밋·푸시·main 머지 커밋·푸시를 승인했다.
- 로컬 프로필 전투력이 null인 경우 저장 세팅 전투력을 읽지 않는 경로를 회귀 테스트로 재현했다. active 소유 계정·서버 ID·원정대 미누락 캐릭터만 사용하며, 프로필 값이 없을 때 가장 최근 유효 저장 세팅을 읽도록 수정했다.
- 그룹 상세 인증 캐릭터 목록의 읽기 원본인 Character.combatPower를 전용 Gateway로 보강했다. 기존 최소 요약 동기화와 분리하고 추가 Lost Ark API 조회 없이 로컬 캐릭터별 값을 사용한다. active binding·Player·Character/계정 소유를 Transaction에서 확인하고 같은 값 쓰기는 생략한다.
- membership self-refresh의 null 덮어쓰기와 조용한 실패를 수정했다. 실패 안내와 저장 목록 조회를 분리하고 새로고침/상세 조회 연타를 막았다.
- 표적 테스트 21개 통과 후 active Player 검증 사례를 추가했다. 최종 전체 flutter test --no-pub 666개 통과. flutter analyze --no-pub 문제 없음. SDK sealed 타입은 테스트 더블 3곳만 사유를 적어 국소 예외 처리했다. 전체 테스트 이후 앱/테스트 동작 변경은 없으며 문서만 정리했다.
- Transaction Fake는 실제 Repository 콜백의 필드 쓰기·소유 확인·읽기 선행을 검사하며 운영 Rules/동시성을 검증한 것으로 간주하지 않는다.
- 이번 범위에서 발견한 그룹 코드의 불필요한 null 연산 분석 경고도 제거했다. Rules·인덱스·배포 설정·레이드 코드는 변경하지 않았다.
- 사용자 실기기 정상 보고로 BUG-009를 종료했다. 개별 장애 경로까지 실기기 검증했다고 주장하지 않는다. 코드 변화 없이 문서만 수정하므로 기존 전체 테스트 666개·analyze 결과를 재사용하고 git diff --check 및 병합 후 코드 일치·원격 SHA 일치를 확인한다.
- 기존 보존 브랜치 codex/rules-complexity-reduction(ed02b31)는 유지한다. main 통합에는 이 보존 계보의 Rules 정리 25f88ff와 사본도 포함되며, Git 병합은 운영 Rules 배포를 의미하지 않는다. Firebase 배포는 실행하지 않는다.

## 2026-08-31 그룹 전투력 수정 전 보존·작업 준비

- 사용자 최신 확인을 기준으로 레이드 모집·탈퇴·완료 체크, 그룹 생성·초대·탈퇴·초대코드 생성·가입, Rules 배포를 정상 상태로 정정했다. 과거 503 기록은 보존하되 현재 차단으로 취급하지 않는다.
- git status/diff/staged diff/stash 및 이력을 확인했다. 미커밋 앱 코드는 없었고 미추적 Rules 사본 2개만 있었다. 전투력 membership Snapshot·self-refresh는 3df755b에 포함되며 이후 75bedb9까지 lib 변경은 없다.
- 사본 2개의 SHA-256은 동일: 46F2B03DE4DA51FA57068CBC00429C4E15948EFCCBF335746B5FBE9ECB1A672C. 원본 파일명·내용을 유지해 ed02b31에 커밋하고 codex/rules-complexity-reduction을 origin에 푸시했다.
- 수정 준비 브랜치 codex/group-combat-power-display를 ed02b31에서 생성했다. main ea2019a는 수정·병합하지 않는다. 기능 코드·운영 Rules·Firebase 배포 설정 변경 없이 NEXT_WORK를 전투력 단일 작업으로 교체했다.
- 그룹원 목록과 상세 캐릭터 목록의 데이터 경로 불일치, self-refresh 오류 은폐를 조사 대상으로 기록했다. 실제 누락 원인은 아직 확정하지 않았다.
- 이번은 백업·문서 준비 작업이므로 Flutter analyze/test 및 실기기·배포는 실행하지 않는다. 문서 검토와 git diff --check, 최종 원격 커밋 일치 확인으로 검증한다.

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

---

## Task-009. 계정 캐릭터 관리

### 구현
- 메인 계정 헤더에서 캐릭터 관리 화면으로 이동하는 route 추가
- 계정에 저장된 전체 캐릭터의 표시 여부 변경
- 메인 화면 표시 개수를 1명부터 계정 캐릭터 수까지 조절
- 로컬 대표 캐릭터를 제한 없이 변경하고, 숨김 캐릭터를 대표로 선택하면 자동 표시
- 대표 캐릭터는 메인 화면과 관리 화면에서 항상 첫 번째로 표시
- 대표 캐릭터를 숨기면 계정 내 다른 캐릭터 중 아이템 레벨이 가장 높은 캐릭터가 대표를 승계
- 승계 대상이 숨김 상태라면 자동으로 표시하며, 대체 캐릭터가 없으면 기존 대표를 숨기지 않음
- 드래그로 캐릭터 표시 순서를 변경하고 Drift에 즉시 저장
- 관리 화면에서 돌아오면 메인 계정 그리드를 다시 로드
- 모든 관리 작업은 로컬 DB만 사용하며 Lost Ark API를 호출하지 않음

### 검증
- Drift 가시성 및 표시 순서 저장 테스트 추가
- CharacterManagementViewModel의 대표 캐릭터, 표시 개수, 재정렬 테스트 추가
- Galaxy Z Fold6에서 표시 개수, 숨김, 대표 변경, 재정렬 및 재실행 후 설정 유지 확인
- profile 빌드에서 캐릭터 목록 스크롤 버벅임이 사라진 것을 확인
- AppBar와 본문 배경을 같은 surface 색상으로 통일해 스크롤 시 색상 변화를 제거
- flutter analyze: issue 0개
- flutter test: 전체 67개 통과

### 다음 범위
- 캐릭터 카드 상세 화면 route 구현
- 부계정 추가 흐름 구현

---

## Task-010. 캐릭터 상세 응답 fixture 및 세팅 검증 기반

### 데이터 분석
- 실제 종합 상세 API 응답을 수집한 뒤 개인정보성 프로필 필드를 목 값으로 치환
- 익명화된 전체 응답 fixture를 `test/fixtures/lost_ark`에 저장
- JWT, Authorization header 및 원본 응답 파일은 저장하지 않음
- 보석 11개, 스킬, 룬, 아크패시브 및 아크그리드 구조 확인

### 검증 기반
- 보석 슬롯과 효과 스킬을 `GemSlot`으로 연결
- 피해 증가, 재사용 대기시간 감소 및 지원 효과 문장 보존
- 일반 스킬과 아크패시브/아이덴티티 스킬을 구분
- 스킬 레벨만으로 장착 여부를 판정하지 않음
- 룬이 8개가 아니면 확인 경고 생성
- 아크그리드 발동 조건과 활성 아크패시브 비교
- 질서의 해/달 14P 필수 효과 및 유물 이상 17P 효과 활성 여부 확인
- 질서의 별과 혼돈 코어는 포인트 상태만 제공하고 필수 경고에서는 제외
- 모든 경고는 안내 목적이며 파티 지원 제한과 연결하지 않음

### 검증
- fixture 기반 mapper 테스트 7개 추가
- flutter analyze: issue 0개
- flutter test: 전체 78개 통과

### 역할별 스냅샷 저장
- Drift 스키마 버전 2 적용
- `character_build_snapshots` 테이블 추가
- 캐릭터당 `dealer`, `support` 스냅샷을 각각 하나씩 저장
- 같은 역할 재저장 시 해당 역할만 최신 데이터로 교체
- 반대 역할 스냅샷은 유지
- 전체 API 원본 JSON, 아이템 레벨, 전투력, 저장 시각 및 데이터 버전 저장
- 경고 결과는 규칙 변경을 반영할 수 있도록 원본 JSON에서 다시 계산
- siblings 재조회 시 기존 캐릭터를 update해 ID와 역할별 스냅샷 유지
- 계정에서 사라진 캐릭터만 삭제하고 연결 스냅샷도 cascade 삭제
- 실제 전체 fixture를 딜러 스냅샷으로 저장하고 원문 그대로 복원하는 테스트 추가

---

## Task-011. 캐릭터 상세 화면 및 역할별 세팅 갱신

### 구현
- 캐릭터 카드에서 상세 화면으로 이동하는 route 연결
- 캐릭터 상세 화면에 프로필, 역할 선택, 저장 상태, 경고, 보석 및 아크그리드 결과 표시
- 바드, 발키리, 도화가, 홀리나이트는 딜러/서포터 저장 위치를 선택
- 그 외 직업은 딜러 역할을 기본값으로 사용
- `세팅 저장`/`세팅 갱신` 시 실제 `GET /armories/characters/{characterName}` 호출
- 수신한 전체 JSON을 선택 역할 스냅샷으로 저장하고 분석 결과를 다시 로드
- 같은 역할은 덮어쓰고 반대 역할 스냅샷은 유지
- 누락 토큰, 인증, 호출 제한, 네트워크 및 응답 오류 안내

### 실기기 검증
- Galaxy Z Fold6 profile 빌드 설치
- 실제 API 통신으로 딜러/서포터 데이터를 각각 저장하고 독립 유지되는 것을 확인
- 테스트 fixture는 자동 테스트에서만 사용하며 앱의 상세 갱신에는 사용하지 않음

### 검증
- 전체 armory fixture가 Repository와 Drift를 거쳐 역할 스냅샷으로 저장되는 테스트 추가
- 서포터 역할 선택 및 딜러 기본 역할 ViewModel 테스트 추가
- flutter analyze: issue 0개
- flutter test: 전체 81개 통과

### 확인된 API 특성
- 바드의 `용맹의 세레나데`, `구원의 세레나데`는 `ArmorySkills`의 독립 항목으로 제공되지 않음
- 두 이름은 능력치, 아크패시브 및 아크그리드 Tooltip 설명에만 등장
- 아이덴티티/아크패시브 스킬은 직업별 게임 기준정보로 보완 필요
- 아크그리드 발동 조건은 깨달음 1티어 계열뿐 아니라 4티어 노드 등 추가 조건을 포함할 수 있음

### 다음 작업 후보
1. 직업별 정적 게임 기준정보 JSON 스키마 확정
2. 깨달음 1티어 노드, 인게임 통칭, 역할 및 아이덴티티 스킬 기록
3. 주요 아크그리드 조합과 조건 데이터 기록
4. 정적 기준정보와 분리된 사용자 메모/선호 조합 로컬 DB 설계
5. API 응답을 먼저 분석한 뒤 저장 위치를 선택하는 미리보기 화면 구현
6. 감지 역할과 사용자 선택 역할이 다를 때 안내하되 저장은 제한하지 않음
7. 내 캐릭터와 파티 지원자가 공유하는 캐릭터 요약 카드 재구성
8. 좁은 화면 1열, 펼친 Fold6 2열을 기준으로 가용 폭 기반 반응형 배치 적용

---

## Task-010. 직업별 기준정보 확장 구현 기준 정리

### 확인한 저장소 상태
- 실제 현재 브랜치는 `main`
- 작업 시작 시 `main`과 `origin/main`이 일치하며 작업 트리는 깨끗함
- 기존 문서의 `feature/account-character-dashboard` 현재 브랜치 표기를 실제 상태에 맞게 수정

### 확정한 용어와 데이터 경계
- 직업, 깨달음 1티어 계열, 인게임 통칭, 역할 및 주요 아크그리드 조합을 서로 다른 개념으로 정의
- 직업별 게임 기준정보는 Git으로 버전 관리하는 정적 JSON 카탈로그로 관리
- 캐릭터 개인 메모는 캐릭터 공통 사용자 데이터로 저장
- 선호 조합은 캐릭터별 사용자 선택값으로 저장하고 정적 조합 정의 및 역할별 스냅샷과 분리
- 감지 역할은 안내용 분석 결과이며 사용자가 선택한 저장 역할을 우선
- 역할 불일치는 미리보기에서 안내하되 특수 세팅 저장을 제한하지 않음
- 세팅 갱신 결과는 사용자 승인 전까지 메모리에 유지하고 기존 스냅샷을 변경하지 않음

### 작업 분리 결정
- 이번 작업은 구현 전 문서 기준과 데이터 경계를 확정하는 단위
- 직업별 노드, 통칭, 아이덴티티/아크패시브 스킬 및 아크그리드 조합의 수기 입력은 아직 시작하지 않음
- 다음 작업에서 정적 카탈로그 Domain 모델과 검증 가능한 JSON 구조를 먼저 구현
- 카탈로그 구조 확정 후 한 직업의 최소 데이터를 입력해 분석 흐름을 검증하고 전체 직업 입력으로 확대

### 검증
- 문서만 변경하여 관련 Flutter 테스트 대상 없음
- 코드, 생성 파일 및 Drift 스키마 변경 없음
- 커밋 및 푸시하지 않음

---

## Task-011. 정적 게임 카탈로그 Domain 모델 및 검증

### 구현 내용
- `shared/game_catalog` 공통 영역에 정적 게임 카탈로그 Domain 모델 추가
- 직업, 지원 역할, 깨달음 1티어 계열, 아이덴티티/아크패시브 스킬, 주요 아크그리드 조합 및 코어 요구사항 구조 정의
- 카탈로그 스키마 버전과 데이터 버전을 분리
- account/recruitment feature에 의존하지 않는 카탈로그 전용 역할 타입 정의
- 중복 ID/API 직업명, 빈 필수값, 미지원 역할, 잘못된 계열 참조 및 코어 포인트 범위를 수집형 검증 결과로 반환

### 범위 제외
- 실제 직업별 노드, 통칭, 스킬 및 조합 데이터 입력
- JSON DTO, asset 등록, DataSource 및 Repository 연결
- 기존 역할 타입 통합 및 분석기 연결

### 검증
- 정적 카탈로그 검증 단위 테스트 5개 통과
- 전체 `flutter analyze`와 `flutter test`는 커밋 직전 한 번 실행 예정
- 커밋 및 푸시하지 않음

### Git 작업 절차 보완
- 모든 작업은 작업 단위별 브랜치에서 진행하도록 협업 지침에 명시
- 작업 시작 전 현재 브랜치와 작업 트리 확인을 필수화
- `main` 또는 기본 브랜치에서 직접 수정하지 않고 먼저 작업 브랜치를 생성
- Codex 작업 브랜치는 기본적으로 `codex/` 접두사를 사용

---

## Task-012. 바드 최소 JSON 카탈로그 및 asset 로딩

### 구현 내용
- 카탈로그 JSON asset 등록
- 엄격한 JSON mapper와 asset DataSource 구현
- Domain 검증을 통과한 카탈로그만 반환하는 Repository 구현
- API fixture에서 바드의 `CharacterClassName`이 한글 `바드`임을 확인
- 영문 `BARD`는 직업 별칭으로 기록
- `완벽한 화음` 서포터 계열과 `진실된 용맹` 딜러 계열 입력
- `용맹의 세레나데`, `구원의 세레나데`를 두 계열 공통 아이덴티티 스킬로 입력
- 세부 아크그리드 조합 목록은 비워 두어 1차 범위에서 제외

### 후속 기능으로 기록한 내용
- 직업별 전체 해/달/별 코어 기준정보
- 3코어 조합 통칭과 인게임 UI 숫자 순서 별칭
- 사용자 지정 선호 조합과 조합별 평가 메모
- 파티 지원자의 실제 장착 코어와 사용자 선호 조합 일치 표시

### 검증
- 실제 번들 JSON asset 로딩 포함 카탈로그 관련 테스트 8개 통과
- 전체 `flutter analyze` 통과
- 전체 `flutter test` 89개 통과

### 다음 채팅 인계
- 현재 브랜치: `codex/game-catalog-foundation`
- 다음 작업은 병합된 `main`에서 새 작업 브랜치를 먼저 생성
- 게임 카탈로그를 기존 캐릭터 세팅 분석기에 연결하고 바드 fixture로 계열 및 역할 감지를 검증
- 분석 연결 단계에서는 카탈로그 역할과 기존 스냅샷 역할을 명시적으로 변환
- 저장 전 미리보기, 사용자 메모 DB, 다른 직업 수기 입력 및 세부 아크그리드 조합은 후속 작업으로 유지

---

## Task-013. 작업 그룹 인계 문서 도입 및 main 최신화

### Git 최신화
- 원격 상태를 확인한 뒤 `codex/game-catalog-foundation`을 로컬 `main`에 fast-forward
- 게임 카탈로그 기반 커밋 `3b52088`을 다음 작업의 코드 기준으로 확정
- 문서 추가와 상태 최신화를 포함한 마지막 커밋을 원격 `main`에 푸시하는 절차로 진행

### 문서 운영 방식
- 새 작업 그룹의 실행 명세를 관리하는 `docs/NEXT_WORK.md` 추가
- `NEXT_WORK.md`는 누적 로그가 아니라 작업 그룹 종료 시 다음 작업 내용으로 교체
- 완료 이력은 `DEV_LOG.md`, 프로젝트 전체 현재 상태는 `AI_CONTEXT.md`에서 계속 관리
- 새 채팅에서는 `NEXT_WORK.md`, `AI_CONTEXT.md`, `ai_rules.md`, Git 상태 및 관련 코드를 순서대로 대조
- 문서와 실제 저장소 상태가 다르면 실제 상태를 기준으로 문서를 먼저 갱신

### 다음 작업 그룹
- 게임 카탈로그와 기존 캐릭터 세팅 분석기 연결
- 바드 fixture의 `진실된 용맹`과 `템페스트 필드`로 `딜바드` 및 `dealer` 감지 검증
- 저장 전 미리보기, 사용자 메모 DB, 다른 직업 데이터 및 카드 개편은 제외

### 검증
- `flutter analyze` 통과
- `flutter test` 89개 통과
- 애플리케이션 코드 변경 없음

---

## Task-014. 반복 작업 그룹 및 테스트 최소화 규칙 문서화

### 작업 사이클
- 새 채팅마다 문서와 Git 상태를 먼저 확인하고 코드 수정 전 작업 단위를 제시
- 승인된 첫 번째 작업 단위만 별도 브랜치에서 구현
- 구현 중에는 변경 영역과 직접 관련된 테스트만 실행
- 설계 결정, 실기기 확인 또는 외부 승인이 필요한 시점에만 중간 보고 후 대기
- 최종 커밋 직전에 전체 `flutter analyze`와 `flutter test`를 각각 한 번 실행
- 완료 문서와 다음 채팅용 `NEXT_WORK.md` 최신화를 같은 최종 커밋과 푸시에 포함

### 테스트 최소화
- 전체 테스트의 진행 중 반복 실행을 금지하고 관련 테스트 중심으로 회귀 확인
- 실기기 검증 대기 전후 코드가 같으면 전체 검증을 중복 실행하지 않음
- 순수 문서 변경은 `git diff --check`와 문서 검토를 기본 검증으로 사용

### 변경 범위
- 협업 및 인계 문서만 변경
- 애플리케이션 코드, 테스트 코드 및 의존성 변경 없음

---

## Task-015. 게임 카탈로그 기반 캐릭터 계열 및 역할 감지

### Domain 및 분석
- 카탈로그 감지 결과와 감지 상태 Domain 모델 추가
- 감지 성공, 미지원 직업, 계열 미감지 및 복수 계열 감지를 구분
- 카탈로그 버전, 직업/계열 ID, 표시 이름, 감지 역할 및 일치 노드를 결과로 제공
- `GameCatalogRole`에서 `CharacterBuildRole`로 명시적으로 변환
- 역할 enum을 독립 Domain 파일로 분리하고 기존 snapshot import 호환 유지

### 바드 연결
- 전체 armory fixture의 `진실된 용맹`으로 `딜바드`와 dealer 역할 감지
- `템페스트 필드`를 관련 패시브 근거로 기록
- `완벽한 화음`으로 `바드`와 support 역할 감지
- 감지 역할은 사용자 선택 스냅샷 역할을 변경하지 않음

### 저장 및 앱 연결
- `LocalAccountDataSource`에 `GameCatalogRepository` 주입
- 번들 카탈로그를 한 번 로드해 저장된 armory 원본 JSON 분석에 사용
- 별도 Drift 마이그레이션 없이 기존 스냅샷도 현재 카탈로그 결과를 재생성
- 앱 라우터 조립부에 asset 카탈로그 Repository 연결

### 검증
- 감지 성공, support 계열, 미지원 직업, 미감지, 모호함 및 기존 호출 호환 테스트 추가
- Repository 저장 역할 유지와 카탈로그 분석 결과 로딩 검증
- `flutter analyze` 통과
- `flutter test` 94개 통과
- UI 변경이 없어 별도 실기기 검증 불필요

## Task-016. 캐릭터 세팅 Draft/Commit 저장 경계

### Domain 및 Repository
- API 조회 결과를 저장 전 상태로 표현하는 `CharacterBuildDraft` 추가
- draft에 대상 캐릭터 ID, 원본 JSON, 프로필, 카탈로그 분석 결과 및 조회 시각 포함
- `createCharacterBuildDraft`는 원격 조회와 분석만 수행하고 로컬 DB를 변경하지 않음
- `commitCharacterBuildDraft`는 draft와 사용자 선택 역할을 받아 저장된 스냅샷을 반환
- 감지 역할과 선택 역할이 달라도 선택 역할로 commit 허용
- 기존 상세 화면 호출부는 draft 생성 직후 commit하는 호환 메서드로 유지

### 저장 안전성
- 선택 역할 스냅샷과 최신 캐릭터 프로필을 Drift 단일 트랜잭션으로 저장
- draft의 캐릭터명과 로컬 캐릭터가 일치하는지 commit 시 검증
- 선택하지 않은 반대 역할 스냅샷 유지
- 저장된 스냅샷 로딩 시 현재 번들 카탈로그로 재분석하는 기존 동작 유지

### 범위 제외
- 저장 전 미리보기 UI 및 ViewModel 상태 변경
- 역할 불일치 안내 화면
- draft 장기 보관, 사용자 메모, 카드 변경 및 다른 직업 데이터 입력

### 검증
- draft 생성 후 스냅샷과 프로필이 변경되지 않는 Repository 테스트 추가
- 원본 JSON, 프로필, 분석 결과 및 조회 시각 포함 검증
- 역할 불일치 commit, 선택 역할 저장, 반대 역할 보존 및 프로필 갱신 검증
- 관련 Repository 및 DB 테스트 15개 통과
- `flutter analyze` 통과
- `flutter test` 95개 통과
- UI 변경이 없어 별도 실기기 검증 불필요

---

## Task-017. 작업 그룹 main 최신화 규칙 추가

### 작업 종료 기준
- 기능 브랜치의 구현, 검증, 문서화, 커밋 및 푸시 이후 `main` 병합 단계를 추가
- 검증 성공한 기능 브랜치만 `main`에 병합
- 병합 결과를 원격 `main`에 푸시하고 로컬/원격 최종 커밋 일치 확인
- 충돌 해결이나 병합 과정에서 코드가 변경되면 영향 검증을 다시 실행
- 병합으로 코드가 바뀌지 않으면 기능 브랜치의 최종 검증 결과 재사용

### 검증
- 애플리케이션 코드와 의존성 변경 없음
- `git diff --check`와 문서 내용 검토로 확인

---

## Task-018. 캐릭터 세팅 저장 미리보기 UI

### ViewModel
- 세팅 조회와 저장 진행 상태를 분리하고 현재 draft와 저장 역할을 메모리에서 관리
- API 조회 성공 후에도 기존 스냅샷을 유지하고 사용자 승인 시에만 commit
- 취소 시 draft 폐기, commit 실패 시 draft 유지 및 재시도 가능
- 지원 직업의 dealer/support 선택과 일반 직업의 dealer 제한 유지
- 중복 draft 조회와 중복 commit 방지

### UI
- 캐릭터 상세 화면에 스크롤 가능한 세팅 저장 미리보기 다이얼로그 연결
- 프로필, 조회 시각, 계열 통칭, 감지 역할, 룬 및 분석 경고 표시
- 지원 직업 저장 역할 선택 제공
- 감지 역할과 선택 역할 불일치 또는 자동 감지 실패 안내
- 불일치 상태에서도 특수 세팅 저장 허용
- 취소 시 무저장, 승인 성공 후 저장 스냅샷 화면 갱신

### 검증
- ViewModel의 조회, 취소, 역할 선택 commit, 실패 유지 및 중복 방지 테스트 추가
- Widget의 좁은 화면 스크롤, 분석 표시, 불일치 안내, 취소 및 승인 테스트 추가
- 관련 ViewModel 및 Widget 테스트 9개 통과
- `flutter analyze` 통과
- `flutter test` 102개 통과

### Galaxy Z Fold6 실기기 검증
- profile 빌드 설치 및 실행 완료
- 기존 역할별 저장 세팅 표시 정상
- 세팅 갱신 후 즉시 저장되지 않고 미리보기 팝업 표시
- 프로필, 계열, 감지 역할, 룬 및 경고 표시 정상
- 접힌 화면과 펼친 화면에서 미리보기 배치와 스크롤 정상
- 역할 불일치 안내와 불일치 상태 저장 정상
- 취소 시 기존 데이터 유지, 승인 시 선택 역할만 갱신, 반대 역할 유지 확인
- 캐릭터 컬렉션 카드 크기는 이번 범위에서 변경하지 않아 기존 크기 유지

### 실기기에서 확인한 후속 문제
- 서포터 바드의 세레나데 보석은 용맹과 구원의 세레나데를 함께 강화하는 정상 필수 보석이지만 단순 스킬명 일치로는 미확인 경고가 발생할 수 있음
- 직업 또는 보석명을 분석 코드에 직접 하드코딩하지 않음
- 카탈로그에 보석 대상 별칭 또는 복합 효과 그룹과 관련 특수 스킬 ID를 데이터로 정의하는 후속 작업으로 처리

---

## Task-019. 카탈로그 기반 보석 대상 분류

### 카탈로그 구조
- 직업별 API 보석 대상 표시명과 관련 특수 스킬 ID를 연결하는 `gemSkillTargets` 추가
- 복합 대상 ID, 표시명, 별칭 및 하나 이상의 특수 스킬 참조 지원
- 빈 관련 스킬 목록과 같은 직업에 없는 특수 스킬 참조 검증
- 번들 카탈로그 스키마 버전 2 적용
- 바드 `세레나데 스킬`을 용맹/구원의 세레나데 복합 대상으로 등록

### 분석
- 실제 장착 스킬은 계속 `normal`로 분류
- 현재 직업의 특수 스킬 이름/별칭과 복합 보석 대상 이름/별칭을 `passiveOrIdentity` 근거로 사용
- API 아크패시브 아이콘 근거 유지
- 어느 근거에도 없는 대상만 `unknown` 경고 생성
- 직업별 문자열 조건문 없이 공통 분석기로 처리

### 검증
- 단일 특수 스킬, 바드 복합 세레나데 대상 및 실제 미확인 대상 테스트 추가
- 카탈로그 참조 무결성과 번들 데이터 로딩 테스트 추가
- 관련 카탈로그, 분석기 및 Repository 테스트 27개 통과
- `flutter analyze` 통과
- `flutter test` 106개 통과

### Galaxy Z Fold6 실기기 검증
- 실제 서포터 바드 세팅의 `세레나데 스킬` 보석 재조회
- 기존 미확인 대상 경고가 사라진 것을 확인
- 보석 목록에서 아이덴티티/아크패시브 대상으로 정상 표시 확인
- 발키리 서포터의 `신앙 스킬`도 같은 유형의 직업별 카탈로그 입력 대상으로 기록

---

## Task-020. 서버 기반 파티 모집 및 계정 그룹 아키텍처

### 제품 방향
- 내 계정 캐릭터 표시 기반 이후 실제 레이드 카탈로그와 멀티유저 파티 구성으로 개발 방향 전환
- Lost Ark API에 없는 레이드 정보를 Git 버전 관리 JSON으로 수기 입력
- 레이드 카탈로그와 모집/승인 Domain을 Firebase 연결보다 먼저 확정

### 백엔드
- Firebase Authentication, Firestore, Callable Functions 2nd gen, Transaction 및 App Check 조합 채택
- 실시간 목록/상태는 Firestore, 상태 변경 명령은 Callable Function으로 분리
- 가입 승인, 투표, 정원 및 역할별 자리는 서버 트랜잭션에서 최종 판정
- 클라이언트 제출 캐릭터 정보는 최종 신뢰하지 않고 서버 검증 스냅샷 경계 필요

### 계정 그룹
- 사용자 ID 검색, 소유자 초대 및 상대방 수락 방식
- 그룹 멤버 수 제품 제한 없음
- 무제한 확장을 위해 멤버를 그룹 문서 배열이 아닌 하위 컬렉션으로 저장
- 모집글 공개 범위에 `public`과 `groupOnly` 추가
- 그룹 전용 모집글은 목록, 상세 및 신청 시점 모두 현재 그룹 멤버십 검증
- 초기 가정은 사용자당 소유 그룹 최대 1개와 다른 그룹 다중 가입 허용이며 구현 전 변경 가능

### 문서
- `BACKEND_PARTY_ARCHITECTURE.md` 신규 작성
- 기존 MVP의 그룹 제외 규칙을 최소 계정 그룹 기능 포함으로 변경
- 애플리케이션 코드와 의존성 변경 없음

---

## Task-021. 로컬 우선 파티 모집 구현 순서 명문화

### 배경
- Firebase 연결 전에 목데이터로 모집 목록, 생성, 신청, 승인/투표, 파티 구성 및 계정 그룹 흐름을 확인할 필요가 있음
- 기존 구현 순서는 로컬 Fake Repository 이후 Firebase가 바로 이어져 로컬 UI 검증 범위가 명확하지 않았음

### 변경 내용
- 실제 레이드 데이터와 모집/승인 상태 머신 이후 Fake 다중 사용자 환경을 구성하도록 순서 명시
- 모집 목록·상세·생성, 신청, 승인·투표·파티 구성 UI를 Firebase 전에 구현하고 검증
- 계정 그룹 초대/수락과 그룹 전용 모집도 Domain·Fake·UI 및 로컬 통합 테스트를 먼저 완료
- Firebase Auth, Firestore, Callable Functions, Security Rules 및 App Check는 로컬 흐름 검증 이후 진행
- 현재 다음 작업인 레이드 정적 카탈로그 기반 구현 범위는 유지

### 검증
- 문서만 변경하며 애플리케이션 코드와 의존성은 변경하지 않음

---

## Task-022. 레이드 정적 카탈로그 기반 구현

### 구현
- `shared/raid_catalog`에 레이드 카탈로그 Domain, JSON Mapper, asset DataSource 및 Repository 추가
- 카탈로그 버전/갱신 시각과 레이드·난이도 기준정보 모델 정의
- 모집글 경계를 위한 카탈로그 버전, 레이드 ID, 난이도 ID 및 선택 관문 참조 모델 추가
- Git 버전 관리용 최소 샘플 JSON asset 추가
- 기존 `raid_master` 정적 목록과 모집 UI는 실제 데이터 전환 전까지 유지

### 검증
- 중복 ID, 필수값, 정원/관문/표시 순서/레벨/보상 범위 검증
- 카탈로그 버전 불일치, 비활성 레이드/난이도, 다른 레이드 난이도 및 관문 범위 검증
- 신규 카탈로그 테스트 9개 통과
- `flutter analyze` 통과
- `flutter test` 115개 통과
- UI와 런타임 연결 변경이 없어 실기기 검증 생략

### 다음 작업
- 신뢰 가능한 기준으로 실제 레이드 데이터를 확인하고 카탈로그에 입력
- 실제 데이터 입력 후 기존 `raid_master`와 목 모집글을 새 카탈로그 참조로 전환

---

## Task-023. 실제 레이드 데이터와 파티 편성 기준 입력

### 카탈로그
- 사용자 인게임 확인 기준 5개 레이드와 13개 난이도 입력
- 정식 이름, 상위 필터명, 레이드 별칭과 난이도 표시 별칭 추가
- 일반 골드와 캐릭터 귀속 골드를 별도 필드로 분리
- 4인/8인 구성에 맞춰 파티 수, 필수 서포터 수와 동일 딜러 직업 최대 수 정의

### 연결
- 기존 Dart 정적 레이드 목록 제거
- 기존 `RaidMasterRepository`를 검증된 JSON 카탈로그 호환 Adapter로 전환
- 6개 목 모집글을 카탈로그 버전·레이드 ID·난이도 ID 참조로 변경
- 모집 카드에 `레이드 - 난이도 (별칭)` 표시 추가

### 파티 규칙 경계
- 동일 딜러 직업 제한은 4인 파티 단위로 적용
- 딜러와 서포터가 같은 직업인 경우는 허용
- 실제 가입 판정과 8인 레이드의 양 파티 배치는 후속 모집 상태 머신에서 구현

### 검증
- 카탈로그/목 모집/호환 Repository/카드 표시 대상 테스트 21개 통과
- `flutter analyze` 통과
- `flutter test` 116개 통과
- Galaxy Z Fold6에서 5개 레이드의 `레이드 - 난이도 (별칭)` 표시 확인
- 4인 모집의 딜러 3/서포터 1, 8인 모집의 딜러 6/서포터 2 목표 표시 확인

---

## Task-024. 파티 모집 카드 한글 표기 정리

- 화면 제목, 모집 상태, 리더, 멤버, 딜러 및 서포터 표기를 한글화
- 숙련도 5단계를 `트라이 / 클경 / 다클경 / 반숙 / 숙련`으로 표시
- 시간 제한이 없을 때 기존 문서 의미에 따라 `클리어 시까지`로 표시
- 시간 제한이 있으면 `최대 시간 N시간`으로 표시
- `flutter analyze` 통과, `flutter test` 117개 통과
- Galaxy Z Fold6에서 한글 제목·상태·역할·숙련도·시간 표기와 줄바꿈 확인

---

## Task-025. 앱 공통 숫자 천 단위 표기

- 공용 `DisplayNumberFormatter` 추가
- 아이템 레벨과 전투력의 소수점 두 자리 형식을 유지하면서 천 단위 쉼표 적용
- 모집 카드의 최소 전투력에 천 단위 쉼표 적용
- 인원, 관문, 시간처럼 작은 정수도 같은 정수 포맷 규칙 사용 가능
- `flutter analyze` 통과, 대상 테스트 8개 및 전체 `flutter test` 119개 통과
- Galaxy Z Fold6에서 계정 아이템 레벨·전투력과 모집 최소 전투력의 쉼표 표기 및 카드 레이아웃 확인

---

## Task-026. 모집 조건·파티 배치·가입 승인 정책 Domain

- 레이드 카탈로그의 전체 정원, 파티 수, 서포터 수와 동일 딜러 직업 한도를 파티별 모집 규칙으로 변환
- 4인/8인 레이드의 역할별 자리와 파티별 배치를 탐색하는 순수 Domain 정책 추가
- 동일 파티의 동일 직업 딜러 중복은 거절하고 딜러·서포터 교차 역할은 허용
- 8인 레이드는 동일 직업 딜러 2명을 서로 다른 파티에 배치하고 3명째는 거절
- 파티장 전용, 파티원 1명, 정족수 승인 정책을 상태 머신에서 사용할 값 객체로 정의
- 대상 테스트 13개와 전체 `flutter test` 132개 통과, `flutter analyze` 통과
- UI와 런타임 연결 변경이 없는 순수 Domain 작업이므로 실기기 검증 생략

---

## Task-027. 신청·투표·가입 상태 머신

- 신청의 `pending / approved / rejected / withdrawn` 상태와 투표 Domain 모델 추가
- 모집 중 신청, 사용자별 중복 신청, 현재 파티원 및 역할별 자리 검증 구현
- 파티장 전용, 파티원 1명 및 정족수 정책별 투표 권한과 승인 조건 구현
- 중복 투표를 차단하고 현재 파티원에게서 나온 유효한 표만 정족수에 포함
- 승인 직전 최신 파티 구성을 재검증하고 신청 승인·멤버 추가·역할별 인원·모집 마감을 단일 결과로 변경
- 정원 경쟁으로 가입이 불가능하면 새 투표도 반영하지 않는 원자적 실패 처리
- 거절 및 신청자 본인의 철회와 완료 신청 재처리 차단 구현
- 상태 머신 대상 테스트 13개와 전체 `flutter test` 145개 통과
- UI와 런타임 연결 변경이 없는 순수 Domain 작업이므로 실기기 검증 생략

---

## Task-028. 로컬 다중 사용자 모집 환경

- 현재 사용자를 전환할 수 있는 `FakeUserSession` 추가
- 고정·이동 가능한 Fake Clock과 순차 Fake ID 생성기로 테스트 재현성 확보
- 상태 Aggregate, 공개 모집 요약 읽기 모델 및 별도 Repository 계약 추가
- revision 비교 후에만 저장하는 메모리 Fake Repository 구현
- 모집 생성·신청·철회·투표 명령을 상태 머신과 현재 사용자 세션에 연결
- 성공한 명령만 revision과 갱신 시각을 변경하고 Domain 실패는 저장 상태를 보존
- A 모집 생성 → C 가입 → B 신청 → C 승인 시나리오와 저장 충돌 검증
- 신규 대상 테스트 8개와 전체 `flutter test` 153개 통과
- UI와 런타임 연결 변경이 없는 로컬 기반 작업이므로 실기기 검증 생략

---

## Task-029. 로컬 모집 목록·상세·생성 UI

- 기존 카드 목데이터 목록을 공유 메모리 Aggregate의 공개 모집 읽기 모델로 전환
- 빈 목록 안내와 모집 만들기 진입 버튼 추가
- 대표 캐릭터를 파티장으로 사용하는 모집 생성 화면 구현
- 레이드·난이도, 파티장 역할, 최소 전투력, 숙련도, 최대 시간과 세 승인 정책 입력 지원
- 모집 Aggregate에 카탈로그 참조와 화면 표시용 모집 조건 Metadata 추가
- 모집 상세에서 레이드·조건·승인 방식과 4인/8인 파티별 현재 구성 표시
- 저장소 변경 알림을 구독해 생성과 후속 상태 변경을 목록에 즉시 반영
- 좁은 화면 입력 검증·생성·상세 Widget 테스트와 전체 `flutter test` 154개 통과
- `flutter analyze` 통과
- Galaxy Z Fold6에서 빈 목록, 전체 생성 폼, 상세 1/2파티 구성과 목록 복귀 자동 갱신 확인

---

## Task-030. `내 파티` 화면 및 Firebase 이전 작업 순서 문서화

- 하단 탐색을 `내 계정 / 파티 모집 / 내 파티`로 확장하는 제품 방향 확정
- `내 파티`에서 `참여 중 / 내가 만든 파티 / 신청 중` 상태를 구분하도록 화면 기준 명시
- pending 신청은 실제 파티 가입과 분리하고 상태 확인 및 철회 대상으로 정의
- 신청 UI → 승인·투표 UI → `내 파티` → 그룹 UI → 로컬 통합 검증 → Firebase 순서로 갱신
- `내 파티`는 별도 상태 복제가 아니라 Aggregate의 소유권·멤버십·신청 상태를 조합한 읽기 모델로 정의
- Firebase 연결은 위 로컬 화면과 실기기 흐름을 모두 검증한 뒤 새 작업 탭에서 시작

---

## Task-031. 주간 레이드 완료와 승인 후 캐릭터 교체 규칙 문서화

- KST 매주 수요일 오전 6시를 레이드 주차 경계로 정의
- 캐릭터가 한 난이도를 완료하면 같은 주차의 동일 `raidId` 전체 난이도에 귀속되도록 확정
- 승인된 파티원 누구나 완료를 선언할 수 있고 최초 한 번으로 당시 파티원 캐릭터 전체를 완료 처리
- 완료 선언은 초기 버전에서 추가 동의·투표·개별 확인 없이 즉시 확정
- 파티원은 완료 전까지 승인 역할과 파티 자리를 유지하며 조건을 만족하는 자기 캐릭터로 추가 승인 없이 교체 가능
- 캐릭터 교체 시 소유권, 역할 세팅, 입장 레벨, 주간 귀속, 선택 모집 조건과 동일 딜러 직업 제한을 원자적으로 재검증
- 최소 전투력·클리어 경험·최대 진행 시간은 미입력 시 제한 없음으로 정의
- 주간 귀속 → 신청 → 승인 UI → 캐릭터 교체 → 완료 선언 → `내 파티` → 그룹 → Firebase 순으로 작업 계획 갱신

---

## Task-032. 주간 레이드 귀속과 로컬 신청·철회 UI

- KST 매주 수요일 오전 6시 기준 주차 계산 정책과 경계 테스트 추가
- 캐릭터·레이드·주차 단위의 난이도 공유 귀속 Repository/Fake 구현
- 신청 명령에서 같은 주차 동일 레이드 완료 캐릭터를 저장 변경 없이 차단
- 모집 Metadata에 카탈로그 입장 레벨을 보존하고 최소 전투력·클리어 경험을 nullable 선택 조건으로 변경
- 저장된 역할별 세팅을 기준으로 입장 레벨, 전투력, 주간 귀속, 역할 자리와 동일 딜러 직업 조건을 후보별 판정
- 모집 상세에 지원 후보 Bottom Sheet, pending 상태 및 본인 신청 철회 UI 구현
- 검증 가능한 계정 데이터가 없는 클리어 경험은 조건을 표시하고 신청자 직접 확인 대상으로 안내
- 로컬 타 사용자 4막 노말 목 모집을 초기 목록에 추가해 앱에서 신청 흐름에 진입 가능하도록 구성
- `flutter analyze` 통과, 전체 `flutter test` 161개 통과
- Galaxy Z Fold6에서 목 모집, 제한 없음 표기, 저장 역할 후보, 신청 대기, 철회와 지원 버튼 복귀 확인

---

## Task-033. 신규 모집 가입 정책 단순화

- 신규 모집 가입 방식을 `파티장 승인 / 승인 없이 바로 가입` 두 가지로 확정
- 생성 화면에서 파티원 승인과 정족수 승인 및 정족수 입력 UI 숨김
- 즉시 가입 정책은 신청 조건과 파티 구성을 검증한 뒤 pending 없이 승인 상태와 파티원 배치를 함께 반영
- 파티원 승인과 정족수 정책은 기존 Domain 및 저장 데이터 호환을 위해 내부에 유지
- 다음 작업의 선행 정족수 정책 결정을 제거하고 파티장 승인·거절 UI로 범위 축소
- `flutter analyze` 통과, 전체 `flutter test` 163개 통과
- Galaxy Z Fold6에서 두 가입 방식만 노출, 즉시 가입 선택 및 정족수 입력 미표시 확인

---

## Task-034. 모집 생성 파티장 캐릭터 및 역할 선택

- 본계정·부계정 전체 표시 캐릭터에서 모집 파티장을 선택하고 저장된 역할을 생성 명령에 반영
- 후보별 아이템 레벨, 역할 전투력, 참가 상태와 차단 사유를 표시하고 동일 레이드 pending은 확인 후 종료
- dealer/support 복수 역할 캐릭터의 선호 포지션 저장 및 한 행 역할 전환 UI 구현
- 파티 내 캐릭터 변경에서 동일 캐릭터의 반대 역할로 직접 변경 가능하도록 수정
- 모집 삭제 시 확정 점유 해제, 종료된 신청 뒤 다른 캐릭터 재신청 흐름 보완
- 일정 확인 기능은 기획 확정 전까지 Domain을 유지하고 앱 UI와 런타임 차단에서 숨김
- 세부 후속 개선 항목을 `DETAIL_IMPROVEMENTS.md`에 분리 기록
- 관련 실기기 테스트 통과
- `flutter analyze` 통과, 전체 `flutter test` 201개 통과
# Task-Account-Management. 본계정·부계정 등록 및 관리

- 작업 브랜치: `codex/account-management`
- 기존 Drift 다계정 스키마를 유지하면서 부계정 스냅샷 추가 저장 흐름 구현
- 계정 캐릭터 중복을 기준으로 동일 게임 계정 재등록 방지
- 본계정 승격 시 기존 본계정을 부계정으로 원자 전환하여 본계정 유일성 보장
- 내 계정 화면에 전체 계정 목록, 본계정/부계정 표시, 추가·표시명 수정·본계정 전환 UI 추가
- 각 계정에서 기존 대표 캐릭터 및 표시 캐릭터 관리 화면으로 이동하도록 라우팅 확장
- 데이터 계층의 계정 생성·중복·본계정 전환 규칙 테스트 추가
- `flutter analyze` 통과, 전체 `flutter test` 209개 통과
- 실제 API와 화면 크기별 실기기 검증은 `NEXT_WORK.md` 체크리스트로 이관
- 부계정 등록 다이얼로그의 입력 컨트롤러를 다이얼로그 State가 소유하도록 수정해 닫힘 애니메이션 중 조기 dispose로 발생하던 Flutter 위젯 트리 assertion을 해결
- 부계정 등록부터 다이얼로그 종료 및 목록 갱신까지 재현하는 위젯 회귀 테스트 추가
- 사용자 실기기 체크리스트 전체 통과
- 부계정 삭제 버튼과 확인 다이얼로그 추가; 저장 세팅, 캐릭터, 계정 순서의 명시적 연쇄 삭제 구현
- 빈 계정 표시명은 사용 가능한 `부계정N`으로 자동 지정하고 사용자 지정 표시명 중복은 거부

---

## Task-035. 아이템 레벨 기반 레이드 선택 및 모집 수정 기반

- 저장 세팅 아이템 레벨과 활성 카탈로그를 기준으로 입장 가능한 레이드·난이도를 계산하는 공용 정책 추가
- 입장 가능한 난이도를 `displayOrder`로 정렬하고 최고 난이도를 기본 선택하도록 모집 생성 화면 연결
- 파티장 캐릭터 또는 저장 역할 변경 시 레이드·난이도 선택지와 후보 유효성을 즉시 재검증
- 모집 상세에 파티장 전용 레이드·난이도 수정, 변경 영향 확인 및 낙관적 revision 저장 명령 추가
- 모집 생성·신청·캐릭터 변경 시 참가자의 아이템 레벨 스냅샷을 보존하고 수정 후 입장 레벨 미달 참가자에 경고 표시
- 레이드 변경 시 로컬 확정 참가 점유도 새 레이드·난이도로 교체하고 실패 시 기존 점유로 복구
- 파티장과 확정 파티원에게 수동 알림 버튼, 확인 알럿 및 전송 중 중복 방지 상태 추가
- 실제 FCM 서버 미연결 상태에서는 전송 성공으로 표시하지 않고 Firebase 연결 후 사용 가능함을 안내
- 공용 정책, 모집 수정 및 수동 알림 위젯 회귀 테스트 추가
- `flutter analyze` 및 전체 `flutter test` 통과
- 사용자 1인 로컬 실기기에서 레이드 자동 선택, 모집 수정, 입장 불가능 표시 및 수동 알림 버튼 흐름을 확인했으며 눈에 띄는 이상 없음
- 실제 다중 사용자 동기화와 FCM 전달은 Firebase 연결 이후 별도 검증

---

## Task-036. 전투력 표시와 자동 모집 제목

- 모집 생성, 지원 및 파티 내 캐릭터 변경 후보의 아이템 레벨·전투력 표시 모델 통일
- 큰 숫자의 소수점을 버리고 천 단위 쉼표를 적용하는 공용 포매터 연결
- 최소 전투력 빈 값과 `0`을 제한 없음으로 정규화
- 난이도 별칭, 숙련도와 최소 전투력을 조합한 자동 모집 제목 구현
- 수동 제목 보존과 빈 제목 저장 시 자동 제목 적용 규칙 구현
- 관련 자동 테스트와 정적 분석 통과 후 `main` 병합 및 원격 푸시 완료

---

## Task-037. 전체 모집 수정과 공통 텍스트 입력 UX

- 모집 생성·수정 공용 Draft와 폼 구현
- 제목, 레이드, 난이도, 숙련도, 최소 전투력과 가입 승인 방식 전체 수정 지원
- 제목, 모집 Metadata와 가입 승인 정책을 revision 기반 통합 명령으로 저장
- 파티장, 확정 파티원과 pending 신청자의 변경 영향을 저장 전에 표시
- 수정 화면에도 파티장 아이템 레벨 기반 레이드·난이도 필터 적용
- 편집 중 빈 제목을 유지하고 빈 상태로 저장할 때만 자동 제목 적용
- 값이 있는 단일행 텍스트·숫자 입력에 공통 전체 지우기(X) 동작 적용
- 관련 자동 검증과 Android 실기기 검증 통과
- 기능 커밋 `e8293e0`, 병합 커밋 `414b301`으로 `main` 및 `origin/main` 반영 완료

---

## Task-038. 대형 재설계 기준 상태 준비

- 기존 후속 작업인 최근 레이드 조건 기억을 재설계 승인 전까지 보류
- 지원 화면에는 재사용할 레이드 조건 선택이 없다는 기존 범위 불일치 기록
- Firebase 다중 사용자 전환을 포함해 제품 목표, 소유권, 상태 전이, 저장 기준과 마이그레이션 범위를 다시 산정하기로 결정
- 다음 설계 승인 전에는 코드 구현과 기능 브랜치를 시작하지 않는 기준 확정

---

## Task-039. Firebase 초기 연결 기준 상태 준비

- Firebase 프로젝트 `lost-party`와 FlutterFire CLI를 이용한 플랫폼 연결 설정 반영
- Android 패키지 `com.example.lost_party`와 Firebase 앱 등록 정보 일치 확인
- Android Google Services Gradle Plugin, `google-services.json`, `firebase.json` 및 `firebase_options.dart` 반영
- 생성 Firebase 옵션이 정적 분석 가능한 상태가 되도록 `firebase_core`까지만 초기 의존성에 포함
- Anonymous Auth 실행, Firestore Repository, Player binding, Security Rules 및 파티 데이터 전환은 후속 설계 범위로 유지
- 현재 코드 기준 Player/Firebase 구조 변경 영향과 Firebase 초기 연결 상태를 별도 문서로 기록
- 다음 단계는 Firebase 적용과 메인 파티현황 개편의 제품 정책, 데이터 소유권, 상태 전이 및 작업 단위를 작업 지시서로 확정하는 것

---

## Task-040. Firebase 단계적 구현 전환 문서 정리

- 로컬 Fake 환경에서 제품 흐름과 UI를 검증하기 위해 적용했던 Firebase 전역 구현 보류 단계 종료
- 전체 백엔드 기술 설계 완료를 기다리지 않고 기능 단위 계약과 검증 범위를 먼저 확정한 뒤 단계적으로 구현하는 기준으로 전환
- `NEXT_WORK.md`, `AI_CONTEXT.md`, `FIREBASE_PARTY_PRODUCT_FLOW.md`, `BACKEND_PARTY_ARCHITECTURE.md`의 착수 조건과 구현 순서 통일
- 첫 구현 단위를 Firebase Core 부트스트랩과 Anonymous Auth 준비·실패 진입 정책으로 지정
- 계약이 없는 후속 서버 기능만 보류하고, 계약이 준비된 기능은 독립 브랜치에서 구현·검증하도록 기준 변경

---

## Task-041. Firebase Core 앱 부트스트랩

- 작업 브랜치: `codex/firebase-core-bootstrap`
- 앱 진입 전에 플랫폼별 Firebase 옵션으로 `Firebase.initializeApp()`을 실행하는 외곽 부트스트랩 추가
- 초기화 성공 전에는 기존 `MyApp`, Drift 데이터베이스와 Fake 파티 런타임을 생성하지 않도록 경계 분리
- 초기화 대기 화면과 오류 상세를 노출하지 않는 실패 안내 및 재시도 동작 구현
- 초기화 함수를 주입해 Firebase 런타임 없이 대기·성공·실패·재시도를 검증하는 위젯 테스트 추가
- `flutter analyze` 통과, 전체 `flutter test` 225개 통과
- 사용자가 최신 브랜치를 Android 실기기에서 실행해 Firebase 초기화 후 기존 내 계정과 저장 캐릭터 데이터가 정상 표시되는 것을 확인
- 초기화 실패·재시도는 주입형 위젯 테스트로 검증했으며 정상 진입 실기기 검증과 함께 작업 완료

---

## Task-042. Firebase Anonymous Auth 부트스트랩

- 작업 브랜치: `codex/firebase-anonymous-auth`
- `firebase_auth` 의존성과 Android·Apple·Windows 플랫폼 플러그인 등록 반영
- Firebase Core 초기화 뒤 현재 인증 사용자를 확인하고 기존 사용자가 있으면 재로그인 없이 재사용
- 현재 사용자가 없을 때만 `signInAnonymously()`를 실행하고 인증 완료 전 기존 앱 생성을 지연
- 인증 실패 또는 로그인 결과 누락을 공용 부트스트랩 실패·재시도 흐름으로 전달
- Auth UID를 사용자 화면과 로그에 노출하지 않고 Player binding은 다음 작업으로 분리
- Fake Auth Gateway 기반 기존 사용자 재사용, 최초 로그인, 실패 및 결과 누락 테스트 추가
- `flutter analyze` 통과, 전체 `flutter test` 229개 통과
- Android 실기기에서 최초 익명 로그인, 기존 앱 진입, 기존 캐릭터 데이터 유지와 앱 재실행 확인 완료
- Firebase Console에서 익명 사용자 생성과 재실행 시 불필요한 사용자 추가가 없는 것을 확인해 실기기 검증 통과

---

## Task-043. Firebase Player binding

- 작업 브랜치: `codex/firebase-player-binding`
- `FIREBASE_PLAYER_BINDING_CONTRACT.md`에 `AuthUid -> PlayerId` 최소 데이터 계약, 최초 생성·재사용, 실패 및 Rules 경계 확정
- `cloud_firestore` 의존성과 Android·Apple·Windows 플랫폼 플러그인 등록 반영
- `PlayerSession`, Player binding Repository와 Firestore Store 경계 추가
- `authBindings/{authUid}`와 `players/{playerId}`를 하나의 Firestore Transaction에서 최초 생성하고 기존 binding은 active Player 검증 후 재사용
- Player binding 완료 전 기존 앱 생성을 지연하고 실패를 공용 부트스트랩 재시도 흐름으로 전달
- 자기 AuthUid의 최초 문서 쌍 생성과 단건 읽기만 허용하고 목록·수정·삭제·기존 Player 임의 연결을 차단하는 `firestore.rules` 추가
- Firebase CLI 15.28.1에서 Rules 컴파일 성공 및 `lost-party` 프로젝트 배포 완료
- PlayerSession과 Repository 단위 테스트 추가, `flutter analyze` 통과 및 전체 `flutter test` 234개 통과
- Android 실기기에서 최초 Player와 binding 문서 쌍 생성, 연결 ID 일치 및 기존 Drift 데이터 유지 확인
- 앱 재실행 시 동일 binding을 재사용하고 불필요한 Player 문서가 추가되지 않는 것을 확인해 실기기 검증 통과

---

## Task-044. 게임 계정·캐릭터 식별자와 로컬 소유 인증

- 작업 브랜치: `codex/server-account-character-contract`
- Firestore `GameAccountId`·`CharacterId` 계약과 Drift v4~v6 마이그레이션을 추가했다.
- 장비 6부위 중 1~3개를 무작위 지정하고 10분 안에 해제된 장비와 나머지 스냅샷을 비교하는 클라이언트 인증을 구현했다.
- 가등록 계정 선택과 캐릭터명 직접 입력을 모두 지원하며, 직접 입력 인증 성공 시 로컬 계정을 즉시 생성한다.
- 인증 성공 시 Firestore Transaction으로 소유권을 가져오고 이전 등록자의 로컬 상태를 `ownershipLost`로 동기화한다.
- 인증 완료 배지, 소유권 상실 안내·파티 사용 차단, 원정대에서 사라진 캐릭터의 경고·수동 삭제를 구현했다.
- 유료 서비스 미사용 결정에 따라 Cloud Functions 프로토타입과 관련 에뮬레이터 구성을 최종 브랜치에서 제거했다.
- 초기 단계의 클라이언트 조작 위험을 명시적으로 수용하고 Lost Ark API 토큰은 디바이스 보안 저장소에만 유지한다.
- 관련 표적 테스트 40개와 `flutter analyze`가 통과했고 Android 실기기에서 캐릭터 인증 성공을 사용자가 확인했다.
- 다음 작업은 하단 4탭과 설정 화면의 인증 진입 구조를 설계한 뒤 별도 작업 단위로 진행한다.
- 회고: 비용 제약을 먼저 확인하지 않은 서버 설계와 목적이 불명확한 에뮬레이터 오류 추적이 낭비를 만들었다. 이후에는 설계 전에 비용, 검증 목적과 중단 기준을 문서화한다.

---

## Task-045. 앱 셸 정보 구조 복원 및 확정

- 과거 사용자 논의와 Git 이력을 대조해 하단 탭과 내부 페이지 계층이 평탄화된 문서 충돌을 확인했다.
- 하단 탭을 `레이드 현황 / 내 계정 / 레이드 모집 / 설정` 순서로 확정했다.
- 첫 화면 `레이드 현황` 안에서 상단 페이지 전환으로 `진행 중 / 신청 중 / 완료 기록`을 구분한다.
- 내가 만들었거나 가입이 확정된 방은 `진행 중`, 승인 대기 신청은 `신청 중`, 이번 주 완료와 과거 히스토리는 `완료 기록`에서 관리한다.
- 기존 파티 모집 목록·신청·생성 화면은 세 번째 `레이드 모집` 탭의 역할로 유지한다.
- 게임계정 인증과 API 토큰 관리는 네 번째 `설정` 탭으로 이동하되 내 계정의 상태 기반 복구 진입점과 같은 화면을 공유한다.
- 다음 구현 범위는 앱 셸·라우팅과 최소 진입 화면으로 제한하고 실제 Firestore 읽기 모델은 후속 작업으로 분리한다.

---

## Task-046. 4탭 앱 셸과 설정 진입 구조

- 작업 브랜치: `codex/app-shell-navigation`
- StatefulShellRoute를 `레이드 현황 / 내 계정 / 레이드 모집 / 설정` 4개 branch로 확장했다.
- 레이드 현황에 `진행 중 / 신청 중 / 완료 기록` TabBarView와 읽기 모델 없는 최소 빈 상태를 추가했다.
- 하단 branch를 IndexedStack으로 구성해 탭별 Navigator 상태를 보존하고 레이드 현황 상단 스와이프와 충돌하지 않게 했다.
- 설정 탭에 기존 게임계정 인증과 API 토큰 화면의 진입점을 추가했고 내 계정의 상태 기반 복구 진입점은 유지했다.
- 초기 탭, 4탭 이동, 상단 스와이프, branch 상태 보존, 설정 뒤로가기와 탭 재선택 루트 복귀를 Widget 테스트 6개로 검증했다.
- `flutter analyze` 통과, 전체 `flutter test` 252개 통과.
- Android 실기기 확인을 사용자가 완료했다.
- API 토큰 삭제 전에 계정 데이터 조회·게임계정 인증 등이 정상 작동하지 않음을 알리는 확인창을 추가했고, 취소·확정·삭제 후 미등록 상태를 Widget 테스트로 검증했다.
- 커밋 `84769f8`, 병합 커밋 `23af0b3`으로 기능 브랜치와 `main`에 반영하고 모두 원격 푸시했다.

---

## Task-047. Firestore 파티 읽기 모델 계약과 Repository 경계

- 작업 브랜치: `codex/firestore-party-read-model`
- `FIRESTORE_PARTY_READ_MODEL_CONTRACT.md`에 공개 모집, 내 진행 중 레이드, 내 신청 중 목록의 스키마·쿼리·권한·인덱스를 정의했다.
- 내 파티 복제 문서를 두지 않고 서버 관리 `memberPlayerIds`로 membership 실시간 쿼리를 구성했다.
- Firestore 타입을 Domain에 노출하지 않는 읽기 Entity, Repository, DTO, Mapper와 실시간 Firestore Repository를 추가했다.
- 공개 목록·자기 membership·자기 신청 읽기만 허용하고 파티 관련 클라이언트 쓰기를 금지하는 Rules 초안과 복합 인덱스를 추가했다.
- 파티 서버 쓰기 명령이 없는 상태에서 로컬 생성 후 목록이 사라지는 모순을 피하기 위해 실행 앱의 Repository 교체는 보류했다.
- Firestore Emulator 검증과 Rules·인덱스 배포는 수행하지 않고 서버 명령·다중 사용자 권한 작업 단계로 보류했다.

---

## Task-048. Spark Firestore 파티 명령 계약

- 작업 브랜치: `codex/firebase-party-commands-contract`
- 별도 지시 전까지 Firebase와 다른 외부 서비스의 유료 플랜·결제수단·과금 가능 기능을 사용하지 않는 전역 운영 원칙을 확정했다.
- Cloud Functions가 Blaze 요금제를 요구하는 현재 정책과 충돌하므로 Callable Functions 전제를 제거했다.
- `FIRESTORE_PARTY_COMMAND_CONTRACT.md`에 파티 생성·수정·신청·철회·즉시 가입·승인·거절의 클라이언트 Transaction, Rules, 점유, revision, 오류·재시도 계약을 정의했다.
- Spark에서 Rules로 충분히 강제하기 어려운 레이드·난이도 수정은 초기 서버 전환 범위에서 제외하고 `unsupportedOnSpark`로 구분한다.
- Firestore Emulator, Rules 배포, 유료 서비스 호출은 수행하지 않았다.

---

## Task-049. Firestore 파티 생성과 확정 참가 점유

- 작업 브랜치: `codex/firestore-party-create`
- 파티 생성 명령과 오류 계약, Repository 경계, 입력 Validator를 추가했다.
- active binding에서 PlayerId를 확정하고 서버 Character의 active 소유권·입장 레벨을 다시 검증한다.
- `recruitments/{id}`, `members/{leaderPlayerId}`, `activeRaidAssignments/{characterId_raidId}`를 한 Firestore Transaction에서 생성한다.
- 모집 ID 중복과 기존 확정 참가 점유를 저장 전에 차단하고 Firebase 권한·일시 오류를 Domain 실패로 변환한다.
- Rules에서 파티장 membership과 점유가 함께 생성되고 Character 소유권·파생 필드가 일치하는 초기 생성 형태만 허용하는 초안을 추가했다.
- 저장 계획과 입력 검증 표적 테스트 5개, `flutter analyze --no-pub`가 통과했다.
- Firestore Emulator, Rules 배포, 실행 앱 Repository 교체는 수행하지 않았다.

---

## Task-050. Firestore 승인 대기 신청과 본인 철회

- 작업 브랜치: `codex/firestore-party-applications`
- 신청·철회 명령, Repository 경계와 입력 Validator를 추가했다.
- 신청 시 active binding, 모집 상태·승인 방식·빈자리·기존 멤버·중복 신청·Character 소유권·입장 레벨을 Transaction에서 재검증한다.
- 승인 대기 신청은 application 문서만 생성하고 membership과 확정 참가 점유를 만들지 않는다.
- 본인의 `pending` 신청만 expected revision 일치 시 `withdrawn`으로 전환한다.
- Rules에서 본인의 최초 pending 생성과 `pending -> withdrawn` 허용 필드만 변경하는 형태를 제한했다.
- 저장 계획·입력 검증 표적 테스트 4개와 `flutter analyze --no-pub`가 통과했다.
- Firestore Emulator, Rules 배포, 실행 앱 Repository 교체는 수행하지 않았다.

---

## Task-051. Firestore 즉시 가입과 신청 승인·거절

- 작업 브랜치: `codex/firestore-party-join-approval`
- 즉시 가입, 신청 승인과 거절 명령·Repository 경계·입력 Validator를 추가했다.
- 즉시 가입은 `directJoin` 모집에서 pending 신청을 만들지 않고 멤버십·확정 참가 점유·모집 인원과 revision을 단일 Transaction으로 갱신한다.
- 승인은 파티장 권한, pending 신청과 양쪽 revision, Character 소유권, 확정 참가 점유와 최신 파티 배치를 다시 확인한 뒤 신청·멤버십·점유·모집을 함께 갱신한다.
- 거절은 권한과 revision을 확인한 뒤 pending 신청만 `rejected`로 종료하며 멤버십과 점유를 만들지 않는다.
- 모집 revision과 Transaction에서 다시 읽은 기존 멤버 문서를 결합해 동시 가입 시 오래된 파티 배치가 저장되지 않도록 했다.
- Rules에 모집 가입 갱신, 일반 멤버십·점유 생성과 승인자 신청 결정을 허용하는 결합 불변식을 추가했다.
- 저장 계획·입력 검증 표적 테스트 3개와 `flutter analyze --no-pub`가 통과했다.
- 실행 앱 Repository 교체, Firestore Emulator, Rules 배포와 외부 유료 서비스 호출은 수행하지 않았다.

---

## Task-052. Firestore 확정 파티원 관리

- 작업 브랜치: `codex/firestore-party-membership-management`
- 참가 캐릭터 변경, 본인 탈퇴, 책임자 추방과 가입 승인 권한 변경 명령·Repository·입력 Validator를 추가했다.
- 캐릭터 변경은 역할과 파티 자리를 유지하면서 새 Character 소유권·입장 레벨·점유·같은 파티의 동일 직업 딜러 제한을 재검증하고 기존·신규 점유와 membership을 한 Transaction으로 교체한다.
- 탈퇴·추방은 membership과 점유를 제거하고 모집 인원·빈자리·revision을 함께 갱신한다.
- 책임자 탈퇴 시 Transaction으로 유지되는 `memberPlayerIds` 가입 순서의 첫 잔여 멤버에게 책임자와 승인 권한을 승계하며, 마지막 멤버라면 모집을 `disbanded`로 종료한다.
- 책임자만 다른 현재 멤버의 가입 승인 권한을 부여·회수할 수 있도록 제한했다.
- 다른 확정 파티 사이의 Character 이동·스왑은 이번 단일 파티 명령 범위에서 분리하되 Spark에서 원천 제외하지 않고, 로컬 예상 결과와 양쪽 파티 서버 Transaction을 결합하는 후속 명령으로 정의했다.
- 파티 서버 상태는 최종 진실, 로컬 데이터는 표시·후보 계산용 Projection으로 구분하고 목록·알림·상세 진입 시 최신화한 뒤 명령 시 서버가 revision과 조건을 재검증하는 기준을 읽기 계약에 기록했다.
- Firestore 영속 캐시와 별도 Drift Projection 중 실제 저장 위치, 보존·계정 전환·오프라인 정책은 실행 앱 Repository 전환 전 확정할 후속 설계로 남겼다.
- Rules에 Character 점유 교체, 멤버 제거, 책임자 승계와 승인 권한 변경의 결합 불변식을 추가했다.
- 저장 계획·입력 검증 표적 테스트 5개와 `flutter analyze --no-pub`가 통과했다.
- 실행 앱 Repository 교체, Firestore Emulator, Rules 배포와 외부 유료 서비스 호출은 수행하지 않았다.

---

## Task-053. Firestore 회차 수명주기

- 작업 브랜치: `codex/firestore-party-cycle-lifecycle`
- KST 수요일 오전 6시 기준 회차 경계와 화요일 22시 완료 취소 마감을 계산하는 순수 정책을 추가했다.
- 파티 완료, 반복 파티 완료 취소·재완료, 반복 설정과 만료 회차 전환 명령·Repository·Validator를 추가했다.
- 완료와 미완료 종료 시 `cycles/{cycleKey}`에 당시 참가자 Snapshot을 저장하고 모집 상태와 revision을 같은 Transaction에서 갱신한다.
- 1회성 완료·미완료 회차는 종료하고 반복 파티는 현재 구성을 연속된 다음 회차로 승계한다.
- 유료 스케줄러 대신 앱 동기화 시 현재 멤버가 멱등 전환을 실행하며, Rules가 서버 시간·7일 경계·revision을 최종 검증한다.
- 회차 정책·Validator·저장 계획과 파티 생성 회귀 표적 테스트 12개 및 `flutter analyze --no-pub`가 통과했다.
- 실행 앱 Repository 연결, 사용자 이벤트, 로컬 히스토리, Firestore Emulator, Rules 배포와 외부 유료 서비스 호출은 수행하지 않았다.

---

## Task-054. Player 이벤트와 로컬 히스토리

- 작업 브랜치: `codex/party-events-local-history`
- 회차 완료·미완료 종료·완료 취소 Transaction이 대상 Player별 Firestore 이벤트를 함께 생성하도록 연결했다.
- 이벤트는 안정적인 ID, 회차 revision, Character Snapshot, 서버 발생 시각과 28일 만료 시각을 포함한다.
- Rules에서 해당 회차가 같은 요청에서 변경됐고 대상 Player와 event revision이 Snapshot에 일치할 때만 이벤트 생성을 허용한다.
- Drift schema v7에 `raidHistoryEntries`를 추가하고 이벤트 ID 기반 멱등 동기화, 숨김·재표시와 로컬 완료 정정을 구현했다.
- 재동기화는 서버 상태를 갱신하되 사용자의 숨김과 로컬 정정을 유지한다.
- active Player 이벤트를 시간순으로 읽어 로컬 DB에 반영하는 동기화 서비스를 추가했다.
- 로컬 DB·이벤트·회차 저장 계획 표적 및 회귀 테스트 30개와 `flutter analyze --no-pub`가 통과했다.
- 실행 앱 화면 연결, FCM, TTL 배포, Emulator와 외부 유료 서비스 호출은 수행하지 않았다.

---

## Task-055. Codex·Cursor 역할 전환과 구현 인수인계 문서 정리

- Codex는 설계·계약·작업 분해·문서 정합성·인수인계, Cursor는 주 코드 구현·빌드·표적 테스트를 중심으로 담당하도록 역할을 갱신했다.
- 어느 도구도 코드 수정 또는 설계 제안이 금지되는 구조는 아니며, 계약 변경은 문서에 영향과 제안을 먼저 남기도록 했다.
- `NEXT_WORK.md`를 누적 과거 상태에서 Cursor가 바로 사용할 실행 앱 Firebase 전환 1단계 인수인계 문서로 교체했다.
- 다음 작업의 목표, 확인 파일, 포함·제외 범위, 로컬 Projection 최소 정책과 완료 조건을 명시했다.
- `AI_CONTEXT.md`의 현재 인계 기준을 과거 인계 기록보다 우선하도록 분리하고 오래된 현재 브랜치 표현을 과거 이력으로 정정했다.
- 문서 색인에 Firestore 읽기·명령·이벤트 계약을 추가했다.

---

## Task-056. 실행 앱 Firebase 읽기·이벤트 동기화 전환 1단계

- 작업 브랜치: `cursor/firebase-runtime-stage1`
- `AppBootstrap`을 제네릭화하고 `initializeAppServices`가 `PlayerSession`을 반환하도록 바꿔 Composition Root에 PlayerId를 전달했다.
- `FirestorePartyReadRepository`와 `PartyEventSyncService`를 레이드 현황에 연결하고, 테스트용 Fake 주입 경계를 유지했다.
- `진행 중`은 `watchActiveRaids`, `신청 중`은 `watchApplications`, `완료 기록`은 Drift `loadRaidHistory` + 멱등 이벤트 동기화 ViewModel로 구성했다.
- loading·빈 상태·캐시·오류·로컬 조회 실패를 구분해 표시하고, 로컬 DB 실패 시 동기화를 생략한다.
- Android에서 `libsqlite3.so`(native assets) 누락으로 완료 기록이 실패하던 문제를 전체 재설치로 해소했다.
- 표적 ViewModel/Widget 테스트와 Android 실기기 세 탭 검증을 통과했다.
- Fake 기반 모집·신청 쓰기 UI와 명령 Repository 실행 앱 전환, Emulator, FCM, TTL 배포는 범위 밖이다.

---

## Task-057. 레이드 현황 목록·완료 기록 UX와 읽기 규칙 보강

- 작업 브랜치: `cursor/firebase-runtime-stage1`
- `진행 중` 카드를 레이드·난이도·관문, KST 시작 일정, 인원/남은 자리, 최소 조건 중심으로 표시한다. 시작 시각이 없으면 `시작 시간 미정`이다.
- `신청 중`은 `승인 대기`와 `최근 처리 결과`를 나누고, `superseded` + `recruitmentClosed`는 거절과 구분해 안내한다.
- `완료 기록`에 카탈로그 표시명, 숨김·로컬 정정 메뉴, `숨긴 기록 보기` 토글을 연결했다. 숨김·정정은 Drift에만 남고 재동기화해도 유지된다.
- 빈 목록에서 오프라인 안내가 풀리지 않던 문제를 `snapshots(includeMetadataChanges: true)`로 수정했다.
- `신청 중` collection group 쿼리가 중첩 경로 규칙만으로는 거부되던 문제를 `match /{path=**}/applications/{applicantPlayerId}` `list` 규칙으로 보완하고 `lost-party`에 배포했다.
- 읽기·이벤트 계약 문서에 메타데이터 구독, collection group 규칙, 완료 기록 화면 연결을 반영했다.
- `flutter analyze --no-pub`과 전체 테스트 312개가 통과했다.
- Android 실기기에서 진행 중 탭의 오프라인 안내가 사라지고, 재실행 시 `PERMISSION_DENIED` 로그가 더 이상 나오지 않음을 확인했다.
- 모집 만들기 등 쓰기 UI는 여전히 Fake이므로 만든 방은 레이드 현황에 나타나지 않는다. 목록→상세 진입은 다음 작업이다.

---

## Task-058. 레이드 현황 목록에서 읽기 전용 상세 진입

- 작업 브랜치: `cursor/firebase-runtime-stage1`
- `watchRecruitment`이 `PartyReadDetailSnapshot`으로 문서 누락과 `isFromCache`를 함께 전달하도록 읽기 계약을 맞췄다.
- 진행 중·신청 중 카드는 레이드 현황 Navigator의 `/raid-status/:recruitmentId`로 들어가 탭 상태를 유지한다.
- `PartyReadDetailPage`는 Firestore 읽기만 표시하고 Fake `RecruitmentDetailPage`의 신청·수정 버튼을 연결하지 않는다.
- loading·누락·권한 오류·오프라인 안내를 목록과 같은 문구로 표시한다.
- ViewModel/Widget 표적 테스트와 전체 테스트 323개, `flutter analyze --no-pub`이 통과했다.
- 쓰기 Repository 전환 전까지 로컬에서 만든 방은 이 상세에도 없다.

---

## Task-059. 모집 생성 명령의 실행 앱 Firestore 전환

- 작업 브랜치: `cursor/firebase-runtime-stage1`
- 실행 앱 모집 생성만 `FirestorePartyCreateRepository`에 연결하고, 목록·신청·승인·멤버·회차·Fake 상세는 InMemory 경로를 유지했다.
- 파티장 Character ID는 게임 계정 인증의 `serverCharacterId`를 사용한다. 없으면 명령을 보내지 않고 인증 안내를 표시한다.
- 생성 성공 시 Fake 상세 대신 `/raid-status/{recruitmentId}` 읽기 상세로 이동한다.
- Fake 생성 흐름 회귀와 Firestore 생성 경로 표적 테스트를 통과했다. 전체 테스트 325개, `flutter analyze --no-pub` 통과.
- 인증되지 않은 로컬 캐릭터로 만든 방은 여전히 Firestore 현황에 나타나지 않는다.
- 인증된 캐릭터로 생성이 `permission-denied` 되던 원인은 캐릭터 인증이 아니라, 신규 모집 ID에 대한 `get`이 없는 문서의 `resource.data`를 읽어 거부된 것이다. 존재하지 않는 모집 단건 `get`은 active binding만 요구하도록 Rules를 수정하고 `lost-party`에 배포했다.
- Android 실기기에서 인증된 캐릭터로 모집 생성, `진행 중` 목록 표시, 읽기 전용 상세 진입, 수정 화면 미적용 안내까지 확인했다.

---

## Task-060. 인증 캐릭터 최소 정보 자동 동기화

- 작업 브랜치: `cursor/character-summary-sync`
- `CharacterSummarySyncService`와 `FirestoreCharacterSummarySyncGateway`를 추가했다.
- `내 계정` 진입 시 기존 Drift를 먼저 표시하고, 마지막 성공 시각 기준 1분이 지나면 siblings 최소 요약을 백그라운드 조회한다.
- 변경된 캐릭터명·아이템 레벨·캐릭터 레벨만 Drift에 쓰고, active 소유·`serverCharacterId`가 있는 Character만 Firestore에 반영한다. 변경이 없으면 앱 서버 전송을 생략한다.
- 수동 새로고침은 제한과 무관하며, 네트워크 진행 중 버튼을 비활성한다. 서버 반영 실패는 로컬 성공으로 숨기지 않는다.
- 모집 생성 `invalidCharacter` 메시지에 내 계정 새로고침 안내를 추가했다.
- 조회 캐릭터명 입력란에 메인 계정 대표 캐릭터명을 비어 있을 때 자동 채운다.
- 표적 동기화 서비스·계정 ViewModel/Page·모집 생성 테스트와 `flutter analyze --no-pub`를 통과했다.
- Android 실기기에서 자동 조회, 아이템 레벨 변경 반영, 로컬·서버 불일치 시 새로고침 안내와 갱신 후 모집 생성을 확인했다.
- Rules 필드 단위 강화는 후속 작업으로 남긴다.

---

## Task-061. 신청·철회 명령의 실행 앱 Firestore 전환

- 작업 브랜치: `cursor/party-application-commands`
- `/raid-status/:recruitmentId` 상세에 `FirestorePartyApplicationCommandRepository`와 리더 후보 서비스를 연결했다.
- 신청은 인증된 `serverCharacterId`만 사용하고, 본인 pending 신청은 `revision`으로 철회한다.
- `PartyApplicationSummary.revision`과 `PublicRecruitmentSummary.currentCycleKey`, `watchMyApplication` 읽기 경계를 추가했다.
- Fake 모집 상세(`/recruitments/:id`) UI는 재사용하지 않았다.
- 표적 상세·mapper·현황 테스트와 `flutter analyze --no-pub`를 통과했다.
- 단일 Android 기기(Player 1개)라 타 계정 신청·철회 실기기는 보류했다. 본인 방 신청은 `alreadyMember`로 거절되는 것을 확인했다.
- 철회 후 재신청 Transaction과 공개 목록 UI 연결은 후속으로 남긴다.

---

## Task-062. LostParty Design System v1 기반과 대표 Card 시범 적용

- 작업 브랜치: `codex/design-system-v1-doc`
- `Soft Lavender Gaming Utility` 방향과 Light Theme의 Color·Spacing·Radius token을 확정했다.
- 기존 `main.dart`의 `deepPurple` seed 직접 구성을 `AppTheme.light`로 분리했다.
- Neutral Background와 흰색 Surface, muted purple Primary, 약한 Card border, 버튼 계층의 기본 Theme을 적용했다.
- 기존 Material 3 Bottom Navigation 구조를 유지하면서 흰색 Surface, Lavender 선택 Pill과 선택·비선택 색상 규칙을 연결했다.
- `PublicRecruitmentSummary` 기반 공개 모집 Card를 대표 컴포넌트로 지정하고 제목·모집 상태·난이도·시작 시간·멤버/남은 자리·최소 조건의 정보 계층을 적용했다.
- Theme과 대표 Card 표적 테스트 3개 및 `flutter analyze --no-pub`가 통과했다.
- 기존 `widget_test.dart`는 Router가 테스트 주입과 무관하게 Firebase 기본 인스턴스를 생성하는 기존 결합으로 실패했으며 디자인 범위에서 Router를 변경하지 않았다.
- 사용자가 시범 디자인 방향을 확인하고 승인했다. 전체 화면 일괄 리디자인은 하지 않으며 후속 기능 작업에서 점진적으로 확장한다.

---

## Task-063. 레이드 모집 공개 목록 Firestore 페이징 읽기 전환

- 작업 브랜치: `cursor/public-recruitment-list`
- `PartyReadRepository`에 `watchPublicRecruitmentFirstPage`와 `loadPublicRecruitmentNextPage`를 추가하고 제한 없는 `watchPublicRecruitments`를 제거했다.
- 첫 페이지는 `updatedAt desc` + 문서 ID desc, `limit(20)` 실시간 구독이고, 다음 페이지는 불투명 cursor의 일회 조회다.
- ViewModel은 `recruitmentId`로 병합하고, 첫 페이지 ID 집합 변경 시 추가 페이지를 초기화하며, 명시적 새로고침으로 listener·cursor·추가 오류를 리셋한다.
- `RecruitmentListPage`는 실행 앱에서 `PartyReadRepository`와 현재 `cycleKey`를 사용한다. 카드 탭은 `/raid-status/{id}`로 이동하고 Fake `/recruitments/:id`와 데이터를 섞지 않는다.
- loading·빈 목록·캐시·첫 페이지 오류·추가 loading·추가 오류·마지막 페이지 경계를 표적 ViewModel/Widget 테스트로 검증했다.
- `firestore.indexes.json` 공개 목록 인덱스에 `__name__ desc`를 추가했다. 실제 배포 확인과 Android 실기기 검증은 남긴다.
- Fake 상세·승인·멤버·회차는 InMemory 경로를 유지한다.
- `flutter analyze --no-pub`과 표적 테스트가 통과했다.
- 최신 `main`을 작업 브랜치에 merge한 뒤, Task-063을 `main`에 통합해 다음 작업의 기초를 `main`으로 맞췄다.

---

## Task-064. 파티장·파티원 표시 누락 점검과 다음 작업 재정의

- 작업 브랜치: `codex/document-party-leader-members`
- 기존 Fake 모집 Card에는 파티장 캐릭터명·직업이, Fake 상세에는 파티별 멤버 구성과 자기 캐릭터 변경 진입점이 있었음을 확인했다.
- Firestore 실행 화면의 `PublicRecruitmentSummary`와 `ActiveRaidSummary`는 파티장 PlayerId만 보유하며, 현재 공개 모집·진행 중 Card와 현황 상세에는 파티장 표시가 없다.
- Firestore membership에는 캐릭터명·직업·역할·파티 위치·아이템 레벨·전투력 Snapshot이 저장되지만 읽기 계약 문서에는 아이템 레벨·전투력이 빠져 있었고, 멤버 DTO·Repository stream·상세 UI가 구현되지 않았다.
- 현재 Rules는 확정 멤버만 전체 membership 목록을 읽을 수 있어 공개 상세 방문자에게 파티 구성을 보여 주려면 안전한 공개 필드와 읽기 구조를 먼저 결정해야 한다.
- 파티장 표시는 Firestore 전환 중 누락, 전체 파티원 표시는 읽기 계약·권한·UI 이관 누락으로 분류했다. 자기 캐릭터 변경과 멤버 관리는 기반 구현 후 실행 연결 대기, 파티 내 자리 이동과 다른 파티 사이 이동·스왑은 별도 후속 설계로 구분했다.
- 다음 작업을 파티장 표시 Snapshot, 멤버 읽기 경계, 공개 권한과 목록·상세 UI 복구로 변경하고 즉시 가입·승인·거절을 그 다음 순서로 이동했다.
- 문서만 변경했으므로 Flutter 검증은 실행하지 않고 `git diff --check`와 문서 간 정합성 검토로 검증한다.

---

## Task-065. 파티장·파티원 읽기 모델과 목록·상세 UI 복구

- 작업 브랜치: `cursor/party-leader-members-read`
- 공개 membership 읽기는 Option 1로 확정했다. Rules에서 공개 모집 membership `get`/`list`를 active binding에 허용하고 Domain/UI는 표시 Snapshot만 소비한다.
- 모집 Current State에 `leaderCharacterNameSnapshot` / `leaderClassNameSnapshot`을 추가하고 생성·파티장 캐릭터 변경·책임자 승계 시 같은 Transaction에서 유지한다.
- `PartyMemberDisplay`, `watchRecruitmentMembers`, Mapper 소프트 Snapshot 파싱을 추가했다. 누락 Snapshot은 전체 실패 대신 `정보 없음`으로 표시한다.
- `레이드 모집` Card·`진행 중` Card·`/raid-status/:id` 상세에 파티장과 파티별 구성을 표시한다.
- 표적 Mapper·WritePlan·Card·상세·현황 테스트와 `flutter analyze --no-pub`을 통과했다.
- Android 실기기에서 목록·상세 파티장·파티원 표시를 확인했다.
- `firebase deploy --only firestore:rules --project lost-party`로 Option 1 포함 Rules 전체를 배포했고 Console에서 `canReadPublicRecruitmentMembers`를 확인했다.

---

## Task-066. 즉시 가입·승인·거절 실행 앱 연결

- 작업 브랜치: `cursor/party-join-approve-reject` (`main`의 Task-065 병합 커밋에서 분기)
- `PublicRecruitmentSummary.approvalMode`와 Mapper 매핑을 추가했다.
- `watchRecruitmentApplications`로 방의 신청 목록을 구독한다.
- `PartyReadDetailPage`에 `FirestorePartyJoinCommandRepository`를 연결했다.
  - `directJoin`: 바로 가입(`joinDirectly`)
  - `leaderOnly`: 지원하기·철회 유지, 파티장 pending 승인·거절
- 표적 상세·Mapper 테스트와 `flutter analyze --no-pub`을 통과했다.
- Android 2기기 실기기 검증은 대기 중이다. 사용자는 추가 디바이스로 테스트한 뒤 수정 지시를 다시 내린다.
- **2기기 검증·수정 완료 전까지 `main`에 병합하지 않는다.** 체크리스트는 `NEXT_WORK.md`에 둔다.

### Task-066 1차 실기기 피드백 대응 (브랜치 전용)

- 증상: 재시작 후 지원 시 `신청 권한을 확인하지 못했습니다`, 인증 캐릭터 목록 토스트, 인증 직후 미반영 추정, 인증 진행 UI 재진입 소실.
- Rules: `recruitmentApplicationPath` + `canGetRecruitmentApplication`으로 **없는 application 문서 get**을 허용. 공개 membership 읽기 헬퍼는 유지.
- 앱: Gateway `activeChallenge`로 인증 진행 UI 복원, 인증 바인딩 후 `loadAccounts` 재조회, 신청 후보 없음 메시지 분리.
- **Rules는 사용자/운영자가 `firebase deploy --only firestore:rules`로 재배포해야 신청이 풀린다.** `main` 병합은 재검증 후.

### Task-066 Rules 재배포·재시도 (2026-08-26)

- `firebase deploy --only firestore:rules --project lost-party`로 `canGetRecruitmentApplication` 포함 Rules를 배포했다.
- 배포 전에도 동일 메시지가 났다면 미배포가 원인이었을 가능성이 크다.
- 추가로 신청/즉시가입에 `targetCycleKey`를 쓰도록 클라이언트를 보강했다.

### Task-066 실기기 현황 정리 (꼬임 방지, 2026-08-26)

- **확인됨:** Rules 배포 후 신청(지원하기)·신청 리스트 표시 성공.
- **실패·미수정:** 파티장 **승인**. 신청 get Rules와 별개.
- **미확인:** 거절·철회·즉시가입.
- 브랜치 `cursor/party-join-approve-reject` (`3cfd835` Rules/인증 UX, `ed7ec10` targetCycleKey). `main` 미병합.
- 사용자가 지금 할 테스트·보고 형식은 `NEXT_WORK.md` 「지금 사용자가 할 테스트」에만 둔다.

### Task-066 우선순위 재정의 (2026-08-26 오후)

- 사용자: 거절 후 B의 전 캐릭터가 A의 전 방에 막히는 체감 → **방 단위** 거절 기억 + **재신청 허용** + **N회 거절 안내**가 필요. 합동 테스트는 기능 추가 후.
- **구현 순서:** (A) 내 모집 삭제/해산 → (B) 방 단위 재신청·N회 안내 → (C) 합동 실기기. 승인 단독 수정은 뒤로.
- 기술 메모: 같은 방 재신청 불가는 `apply`의 `application.exists` 거부에 해당. 전역 차단은 재현·분리 예정.

### Task-066 Step A — 내 모집 삭제 1차 (2026-08-26)

- `/raid-status/{id}`에 파티장 **모집 삭제** 연결. 단독 멤버면 membership `leave`로 `disbanded`.
- 다인 방은 아직 해산 불가 안내. Rules 추가 배포 없음.
- 다음: Step B 거절 후 재신청·N회 안내. `main` 미병합.

### Task-066 Step B — 방 단위 재신청 (2026-08-26)

- 거절·철회·superseded 후 같은 `applications/{playerId}`를 `pending`으로 재신청. `rejectionCount` 유지.
- Rules `validApplicationReapply` + 상세 N회 거절·다시 지원하기 UI.
- **Rules 재배포 후** Step C 합동 테스트. `main` 미병합.

### Task-066 Step C 합동 실기기 통과 (2026-08-26)

- 확인: N회 거절 안내·재신청·캐릭터 재선택, 단독 모집 삭제, 승인, 철회, 즉시 가입.
- 브랜치 `cursor/party-join-approve-reject`. **`main` 병합은 사용자 지시 대기.**
- 후속: 다인 해산, 멤버·회차 명령 등 (`NEXT_WORK.md`).

### Task-066 `main` 병합 (2026-08-26)

- `cursor/party-join-approve-reject`를 `main`에 병합·푸시했다.
- 통합 기준은 Task-066(가입·승인·거절·재신청·즉시가입·단독 삭제)까지.
- 다음 작업은 멤버 명령·회차 명령부터 (`NEXT_WORK.md`).

---

## Task-067. 파티 고정 슬롯 구성판과 최종 후속 채팅 요구사항 문서화

- 작업 브랜치: `codex/docs-party-slots-chat`
- 현재 membership의 `partyIndex`는 파티 번호만 나타내며 상세 UI가 이를 자리 번호 계산에 사용해 같은 파티 멤버가 모두 `1자리`로 표시되는 원인을 확인했다.
- `partyIndex`와 파티 내부 `slotIndex`를 분리하고 4인·8인 정원 전체의 점유·빈 슬롯을 Card/Cell 구성판으로 표시하는 방향을 확정했다.
- `1파티 1번`은 4인 파티장, 8인 파티장 겸 공대장 자리로 고정하고 캐릭터 변경은 자리를 유지하며 탈퇴·추방 후 자동 당김 배치를 하지 않는 원칙을 기록했다.
- 빈 슬롯은 우선 `현재 별도 참가 조건 없음`을 표시하고 향후 역할·직업군·시너지 요청 조건을 membership과 분리해 확장한다.
- 파티 상세 멤버 전용 최근 10개 텍스트 채팅은 모든 핵심 파티·슬롯·그룹 기능 이후 가장 마지막에 구현한다. 상세 화면에서만 `limit(10)` 실시간 구독하고 목록·다른 탭에서는 읽지 않는 최소 비용 원칙을 기록했다.
- 문서만 변경했으므로 Flutter 검증은 실행하지 않고 `git diff --check`와 문서 간 정합성 검토로 검증한다.

---

## Task-068. 고정 슬롯 쓰기·구성판·승인 점유 get (2026-08-26)

- 작업 브랜치: `cursor/party-fixed-slots`
- 생성은 `(partyIndex: 0, slotIndex: 0)`, 즉시 가입·승인은 기존 멤버를 재배치하지 않고 빈 슬롯만 배정한다.
- `slotIndex`가 없는 기존 방은 가입 계산 시 리더·`joinedAt`·`playerId`로 점유를 결정적으로 추정하고, UI에서는 자리 미정으로 표시한다.
- 현황 상세에 정원 전체 점유·빈 슬롯 Card 구성판을 연결했다(좁은 화면 1열, 너비 600+ 2열).
- Rules: 생성·가입 `slotIndex` 검증, 캐릭터 변경 시 자리 유지, 승인용 신청자 점유 문서 get 허용.
- 실기기: 즉시 가입·승인 통과. 거절은 기존과 동일.
- 표적 테스트(구성 정책·쓰기 계획·매퍼·구성판·상세)와 변경 파일 `flutter analyze` 통과.
- 다음: 멤버 명령(캐릭터 변경·탈퇴·추방) 실행 앱 연결 (`NEXT_WORK.md`).

---

## Task-069. 파티 구성판 반응형 그룹 배치 (2026-08-26)

- 작업 브랜치: `cursor/party-composition-responsive-layout`
- Slot Card 2열을 제거하고 가용 폭 기준 **파티 그룹** 배치로 전환했다. 좁은 화면은 세로 1열, 넓은 화면은 1·2파티 좌우.
- 실기기에서 펼친 폴드가 미달하던 후보 `720dp`를 `600dp`로 조정했다.
- 넓은 8인에서 같은 자리 좌우 Slot Card 높이를 `IntrinsicHeight`로 맞췄다.
- 표적 위젯 테스트와 `flutter analyze` 통과. 바형·폴드 실기기 디자인 통과.
- 다음: 자기 참가 캐릭터 변경·탈퇴·추방 (`NEXT_WORK.md` Task-070).

---

## Task-070. 자기 참가 캐릭터 변경·탈퇴·추방 (2026-08-26)

- 작업 브랜치: `cursor/party-membership-commands`
- 현황 상세에 `changeCharacter` / `leave` / `kick`을 연결했다. 캐릭터 변경은 역할과 `(partyIndex, slotIndex)`를 유지한다.
- 탈퇴·추방 후 남은 멤버를 앞자리로 당기지 않는다. 다인 해산은 범위 밖이며 단독 모집 삭제만 1인일 때 유지한다.
- `PartyMemberDisplay`에 표시하지 않는 `playerId`·`characterId`를 두어 명령 대상 식별에 쓴다.
- BUG-001: 상세 `recruitmentId` 변경 시 State가 남는 문제를 `ValueKey`와 ViewModel `restart`/`didUpdateWidget`으로 수정했다. 정상 스텝 실기기 통과 후 종료 기록만 `BUG_REPORTS.md`에 남김.
- 표적 테스트·`flutter analyze` 통과. 실기기에서 변경·탈퇴·추방 통과.
- 다음: 완료·완료 취소·종료·해산 (`NEXT_WORK.md` Task-071).

---

## Task-071. 완료·완료 취소·종료·해산 (2026-08-26)

- 작업 브랜치: `cursor/party-cycle-lifecycle`
- 현황 상세에 `complete` / `cancelCompletion` / `setRecurrence` / `advance` / `disband`를 연결했다.
- Rules에 다인·완료 후 해산(`validRecruitmentDisband`)과 완료 후 반복 설정 변경을 추가했고 `lost-party`에 배포했다.
- 1회성 완료 후 진행 중 목록에 `status in [active, completed]`로 **해산 대기**를 남겨 상세 재진입·해산이 가능하게 했다.
- 완료 직후·완료 기록 탭 이벤트 sync, 하단 탭 터치 시 브랜치 루트 복귀를 보강했다.
- 표적 테스트·analyze 통과. 실기기에서 완료·해산·해산 대기 목록 확인.
- 열린 이슈: BUG-002, BUG-005(주간 재완료 미차단), BUG-006(초기 권한 실패 관찰).
- 다음: 알림 서비스 별도 설계 (`NEXT_WORK.md` Task-072).

---

## Task-072. 파티 이벤트 기반 앱 내부 알림·FCM 확장 설계 (2026-08-26)

- 작업 브랜치: `codex/notification-event-design`
- 실제 Party Event, application, membership, read model, Drift v7 히스토리와 Firestore Rules를 문서 계약과 대조했다.
- Spark에서는 `players/{playerId}/events/{eventId}`를 사용자별 비공개 알림 투영본으로 확장하고, 앱 내부 알림을 먼저 구현하기로 결정했다.
- 알림은 성공한 파티 명령의 파생 정보이며 자유 문구를 저장하지 않는다. 명령 Transaction과 유형별 Rules가 상태 전이·수신자·Snapshot·event ID를 검증한다.
- 초기 읽음 상태는 event ID별 Drift 로컬 Projection으로 두고 여러 기기 동기화는 후속으로 보류했다. 완료 히스토리의 숨김·로컬 정정 필드는 읽음 상태로 재사용하지 않는다.
- 가입 신청부터 해산까지 이벤트별 행위자·수신 대상·표시 문구·이동 목적지·제외 대상·Snapshot·중복 방지 기준을 `PARTY_NOTIFICATION_CONTRACT.md`에 기록했다.
- 향후 신뢰 서버가 같은 Player Event를 검증하고 방별 설정·토큰을 확인해 FCM을 전달하는 확장 지점을 정의했다. Flutter의 토큰 조회·FCM 직접 호출·자격 증명 포함은 금지했다.
- 코드, Firestore Rules와 Firebase 배포는 변경하지 않았다. 문서 정합성과 `git diff --check`로 검증한다.
- Codex와 Cursor가 교대로 작업할 때 대화 맥락 없이도 이어갈 수 있도록 `NEXT_WORK.md`를 실행 지시서 형식으로 보강했다. 공통 인계 상태 양식, 단계별 담당, Task-073 코드 확인 지점·불변식·산출물·검증 체크리스트·중단 조건을 추가했다.
- 다음: Task-073 공통 알림 이벤트 schema·Rules 기반.

---

## Task-073. 앱 내부 알림 이벤트·로컬 UI (2026-08-27)

- 작업 브랜치: `cursor/party-notification-event-foundation`
- 공통 `PartyEvent` / write plan / mapper와 자기 Player Event 읽기 Repository를 추가했다.
- Rules에 신청·멤버십·`partyDisbanded` 유형별 create 검증을 넣고 `lost-party`에 배포했다. 일반 create는 열지 않았다.
- 신청·멤버십·해산 명령 Transaction에 이벤트를 연결했다. `partyEnded`·`memberMoved`는 보류했다.
- Drift v8 `partyNotificationReceipts`와 unread 집계, 현황 AppBar 알림 아이콘·목록 UI·문구 템플릿을 추가했다.
- 다인 해산이 실패하던 원인을 Transaction에서 `get`/`delete` 교차 호출로 확인했다. 모든 읽기 후 쓰기로 수정했고 실기기에서 다인 해산이 정상 동작했다.
- FCM·OS 알림·Emulator·유료 서비스는 제외했다.
- Task-073은 `main`에 병합됨. 이후 제품 우선순위 재검토로 상세 채팅은 후순위로 이동했다.

---

## Task-074. 개인 주간 레이드 Claim 계약 문서화 (2026-08-27)

- 작업 브랜치: `codex/weekly-raid-claim-contract`
- 파티 회차 상태, 활성 참가 점유와 개인 캐릭터 주간 완료를 분리하고 서버 Claim을 내 계정 체크박스와 모집 제한의 단일 기준으로 확정했다.
- 파티장·공대장 완료는 당시 구성원 전체 완료, 일반 멤버 완료는 본인 탈퇴와 본인 완료, 내 계정 수동 체크는 앱 밖 완료까지 같은 Claim으로 처리하도록 정리했다.
- Claim을 수동 체크할 때 활성 참가 방이 있으면 명시적 확인 후 탈퇴·점유 해제·pending 종료·Claim 생성을 하나의 Transaction으로 처리한다.
- 체크 해제는 본인의 Claim만 삭제하며 과거 membership·파티·다른 구성원 Claim을 복구하거나 변경하지 않는다.
- 같은 `playerId + characterId + raidId + cycleKey`의 Claim과 활성 점유가 공존할 수 없고, 생성·신청·즉시 가입·승인·캐릭터 변경이 서버에서 Claim을 재검증하도록 계약했다.
- [`../architecture/WEEKLY_RAID_CLAIM_CONTRACT.md`](../architecture/WEEKLY_RAID_CLAIM_CONTRACT.md)를 새 기준 문서로 추가하고 `NEXT_WORK.md`의 다음 구현을 Task-075 읽기 기반 A로 분해했다.
- BUG-005는 이 작업에 흡수하고, 현재 재현되지 않는 BUG-002·006은 재발 시 다시 여는 조건으로 종료 간주했다.
- 코드, Firestore Rules와 Firebase 배포는 변경하지 않았다.

---

## Task-075. 개인 주간 레이드 Claim 기반 A (2026-08-27)

- 작업 브랜치: `codex/weekly-raid-claim-foundation`
- `WeeklyRaidClaim` Domain·DTO·mapper와 현재 Player·현재 주차 전용 Firestore stream Repository를 추가했다.
- 문서 ID는 `cycleKey`, `characterId`, `raidId`를 각각 UTF-8 base64url(no padding)로 인코딩해 `~`로 연결하도록 확정하고 안정성 테스트를 추가했다.
- 내 계정 캐릭터 Card에 입장 가능한 활성 레이드 중 골드 기준 기본 3개를 읽기 전용 체크박스로 표시한다. Claim이 있으면 체크되고 같은 raidId의 난이도는 중복 표시하지 않는다.
- Drift 완료 히스토리·Party Event·기존 InMemory `WeeklyRaidClearRepository`는 변경하거나 Claim 저장소와 합치지 않았다.
- `firestore.rules`에 자기 Player `weeklyRaidClaims` get/list만 허용하고 create/update/delete는 닫았다. 사용자가 Firebase 프로젝트 `lost-party`에 배포했다.
- Firebase 의존 Repository/Gateway를 앱 생성자에서 주입할 수 있게 해 미초기화 위젯 테스트 회귀를 제거했다.
- 기존 테스트의 깨진 한글 기대 문자열 두 건을 실제 제품 문구로 복구했다.
- Claim 표적 테스트 6개, 내 계정 기존 테스트, 앱 위젯 테스트, 전체 `flutter test --no-pub` 421개와 `flutter analyze --no-pub`가 통과했다.
- Claim create/delete, 모집 제한, 활성 파티 탈퇴와 pending 종료 및 개인/전체 완료 변경은 제외했다.
- 실기기에서 새 주간 레이드 표현, 기존 계정 기능과 카드 레이아웃이 정상임을 확인했다. 현재 Claim이 없어 체크박스는 모두 미체크이며 읽기 전용으로 조작되지 않는다.

---

## Task-076. 개인 주간 레이드 Claim 기반 B (2026-08-27)

- 작업 브랜치: `codex/weekly-raid-claim-manual`
- 내 계정 체크박스에서 자기 수동 Claim create/delete를 확인창과 함께 실행하고, 처리 중 같은 항목의 중복 입력을 막는다.
- 활성 assignment 또는 pending 신청이 있으면 상태를 변경하지 않고 사유를 안내한다. 자동 탈퇴·신청 종료는 후속 D 범위다.
- Claim 문서 ID를 Rules가 재구성 가능한 `${cycleKey}_${characterId}_${raidId}`로 교정하고, 읽기 mapper도 문서 ID와 내용의 일치를 검증한다.
- Rules는 본인 Player·소유 Character·현재 7일 주차·수동 source·서버 timestamp·허용 필드·결정적 ID를 검증한다.
- Claim과 신청/assignment의 경쟁 생성을 막기 위해 신청·가입·캐릭터 변경 Rules에 Claim 부재 검사를 최소 선반영했다. 전체 UI 오류 매핑은 Task-077 C에서 완성한다.
- 전체 `flutter test` 424개, `flutter analyze`, Firebase Rules dry-run compile이 통과했다. 사용자가 Rules를 배포했다.
- Android 실기기에서 수동 체크·해제, 앱 종료 후 재실행 상태 유지, 참가 중 동일 레이드 모집 생성 차단과 pending 신청 상태의 체크 차단을 확인했다.
- 파티 완료 후 참가자 Claim 자동 생성은 아직 연결하지 않았으며 Task-079 E 범위다.

---

## Task-077. 개인 주간 레이드 Claim 기반 C (2026-08-27)

- 작업 브랜치: `codex/weekly-raid-claim-recruitment-guards`
- Claim이 있는 캐릭터를 동일 `raidId`의 모집 생성·신청·즉시 가입·참가 캐릭터 변경 후보에서 비활성화하고, 각 명령 Transaction과 Rules가 Claim 부재를 최종 재검증한다.
- 실기기 검증 중 발견된 참가 캐릭터 역할 고정 회귀를 수정했다. 파티 내 역할별 자리와 전체 구성이 허용하면 dealer↔support 변경 및 같은 캐릭터의 반대 역할 설정을 허용한다.
- 역할 변경은 membership, active assignment, 모집 `dealerCount`·`supportCount`를 같은 Transaction에서 갱신한다.
- 레이드 상세에 전체 및 파티별 딜러·서포터 현재/정원을 표시한다. 전체는 모집 집계, 파티별 값은 실제 슬롯 배치를 기준으로 한다.
- 전체 테스트 429개와 `flutter analyze`, Rules dry-run을 통과했고 사용자가 Rules 배포와 Android 실기기 검증을 완료했다.
- `main` 반영 커밋: `0f43463`.

---

## Task-078. 개인 주간 레이드 Claim 기반 D (2026-08-27)

- 작업 브랜치: `codex/weekly-raid-claim-completion-flow`
- 내 계정 체크 전에 동일 Character·raidId·cycleKey의 활성 파티와 pending 신청 영향을 조회하고, 파티명·탈퇴·책임자 승계·단독 해산·신청 종료 건수를 확인창에 표시한다.
- 사용자 확인 후 membership 제거, assignment 삭제, 모집 인원·역할·빈자리·revision 갱신, 필요 시 책임자 승계 또는 단독 해산, 동일 레이드 pending 종료, 본인 Claim 생성과 완료 사유 `memberLeft` 이벤트를 한 Transaction으로 처리한다.
- 일반 멤버 탈퇴에서는 기존 책임자 표시 Snapshot을 보존하고, 책임자 탈퇴에서는 다음 membership Snapshot으로 책임자를 승계한다.
- 완료 종료 신청은 `status: superseded`, `resolutionReason: weeklyRaidCompleted`로 기록하며 같은 캐릭터의 다른 raidId 신청은 유지한다.
- Claim 해제는 과거 파티·신청을 복구하지 않는다. 과거 `approved` application이 남아 있어도 현재 membership이 없다면 같은 문서를 새 revision의 `pending`으로 갱신해 동일 방 재신청을 허용한다.
- Rules 배포와 실기기에서 일반 멤버 탈퇴, 책임자 승계, 단독 해산, pending 종료, 취소 무변경, 완료 사유 알림, Claim 해제 후 재신청을 확인했다.
- 구현 커밋 `ec0def8`, 종료 문서 커밋 `efed5a3`으로 `main`과 `origin/main`에 반영됐다.
- 레이드 상세의 일반 멤버 개인 완료 버튼과 파티장 전체 완료·전원 Claim은 Task-079 E 이후 범위다.

---

## Task-079 사전 설계. 반복 파티 전체 완료 취소 확정 (2026-08-27)

- 반복 파티도 일반 파티와 같은 완료 흐름을 따르되 방과 membership은 다음 회차 준비를 위해 유지한다.
- 책임자의 파티 전체 완료는 당시 전원의 `partyOwner` Claim 생성과 active assignment 해제를 회차 완료와 함께 처리한다.
- 반복 파티 책임자는 KST 화요일 22:00 전, 완료 Snapshot과 현재 membership·책임자·역할·슬롯 및 전원의 해당 Claim이 그대로인 경우에만 전체 완료를 취소할 수 있다.
- 취소는 같은 `sourceRecruitmentId + sourceCompletionRevision`의 `partyOwner` Claim 전원 삭제, assignment 전원 복원, 회차 복구와 취소 이벤트를 하나의 Transaction으로 처리한다.
- 완료 후 Claim 직접 해제, 구성·책임자·역할·슬롯 변경 또는 다른 참가 충돌이 하나라도 있으면 부분 병합하지 않고 전체 취소를 거절한다. 다음 회차 준비 변경은 가능하지만 그 시점부터 이전 완료 취소는 포기한다.
- 책임자는 `manual` 또는 일반 멤버의 `partyMember` Claim을 삭제할 수 없다. 수요일 오전 6시 이후에는 이전 회차를 취소하지 않는다.
- 기존의 부분 병합 복원과 `구성 점검 필요` 전환안은 Claim 기반 초기 구현에서 폐기했다.
- 코드는 변경하지 않았으며 Task-079는 전체 완료·전체 취소 각각의 최대 8인 Transaction과 Security Rules 접근 예산을 계산한 뒤 시작한다.

---

## Task-079. 개인 주간 완료 Claim 기반 E (2026-08-27)

- 작업 브랜치: `cursor/task-079-party-complete-claims`
- 책임자 전용 `파티 전체 완료`로 회차 completed·Snapshot 전원 `partyOwner` Claim 멱등 생성·assignment 전원 삭제·완료 이벤트를 한 Transaction에 연결했다.
- 반복 파티 전체 완료 취소는 Snapshot·membership·책임자·역할·슬롯과 해당 `partyOwner` Claim이 그대로일 때만 Claim 삭제·assignment 복원·회차 복구를 원자적으로 처리한다.
- Rules는 leader-only 완료, `partyOwner` Claim create/delete, 완료 시 assignment 삭제, 취소 시 assignment 복원을 추가했다. membership 일치로 character 소유 get 없이 접근 약 12회(한도 20)를 유지한다.
- UI는 `파티 전체 완료` 라벨과 책임자 전용 표시, 계약 안내 문구를 반영했다.
- 표적 테스트 36개와 `flutter analyze --no-pub` 통과. Rules는 `lost-party`에 배포했다.
- 다중 기기 실기기 검증과 기존 completed 방 assignment 정리는 Task-080 F로 이관했다.

---

## Task-081. 내 계정 주간 레이드 표시 설정 (2026-08-28)

- 작업 브랜치: `cursor/task-081-weekly-raid-display`
- Drift schema 9에 캐릭터별 주간 레이드 표시 설정(`displayCount`, `raidIdsCsv`)을 추가하고 Claim과 분리된 로컬 Repository로 저장한다.
- 기본(미설정)은 골드 추천 상위 3개를 입장 레벨 내림차순으로 표시한다. 사용자 설정이 있으면 선택·순서를 존중하고 자동 추천으로 덮어쓰지 않는다.
- 캐릭터별 수정 UI(0~5·선택 수 일치 시 저장·기본값)와 원정대 일괄 표시 개수 적용을 추가했다. 일괄 적용 시 입장 불가 레이드는 캐릭터별로 자동 축소한다.
- 제품 결정을 반영해 접기/더보기 UI는 제거했고, 선택 개수만큼 항상 표시한다. 고정 높이 Grid overflow를 피하기 위해 캐릭터 카드는 내용 높이 `Wrap` 배치로 바꿨다.
- 계정 헤더는 계정명 단독 줄 + 배지·n/n·아이콘 + `원정대 주간레이드수정` 버튼으로 정리했다.
- 표적 테스트(projector·ViewModel·page) 통과. 에뮬레이터 overflow 수정과 실기기 UI를 확인했다.
- 계약 문서 `FIREBASE_PARTY_PRODUCT_FLOW` §17·`WEEKLY_RAID_CLAIM_CONTRACT` §15를 접기 제거·일괄 개수 반영으로 갱신했다.
- `main` 반영 커밋: `46506e9`.

---

## Task-080. 개인 주간 완료 Claim 기반 F (2026-08-28)

- 작업 브랜치: `cursor/task-080-claim-foundation-f`
- 모집 게이트·후보 UI를 서버 Claim만 보도록 정리하고 로컬 `WeeklyRaidClear` OR을 제거했다.
- E 이전 orphan `activeRaidAssignment`는 Claim으로 바꾸지 않고, 모집 completed/disbanded 또는 cycle completed일 때 본인 점유만 Rules·파티 상세 self-heal로 삭제한다.
- 내 계정 주간 레이드 이름 탭으로 체크 토글을 연결했다.
- 반복 파티 완료 후 다음주 참가 캐릭터 변경은 membership만 갱신한다(이번 주 Claim·새 assignment 없음). 변경 시 전체 완료 취소 포기 안내, 취소 거절 시 구성 변경 문구를 넣했다.
- 재완료 때 이전 Snapshot 캐릭터의 같은 방 `partyOwner` Claim orphan을 정리한다. cycle `completionRevision`은 num을 허용한다.
- 정상 완료·1차 실수 복원 실기기를 확인했다. 의도적 복잡 꼬임은 **BUG-007**로 `BUG_REPORTS.md`에 보류 기록하고, 앱 심화 업그레이드 시 대응한다.
- 일반 멤버 `내 캐릭터 완료` 버튼은 별도 단위로 둔다.
- 표적 테스트·analyze 통과. Rules는 사용자가 `lost-party`에 재배포했다.
- `main` 반영: 구현 `3726be8`, 병합 `c45dba2`.
- 다음 실행: Task-082 레이드 모집에서 내 모집 제외.

---

## Task-082. 레이드 모집에서 내 모집 제외 (2026-08-28)

- 작업 브랜치: `cursor/task-082-exclude-own-recruitments`
- 공개 Firestore 쿼리는 유지하고, data 계층에서 `leaderPlayerId` 또는 `memberPlayerIds`에 현재 Player가 있는 `active` 방을 제외한다. `memberPlayerIds`는 Domain에 새로 노출하지 않는다.
- 신청만 `pending`인 방은 공개 목록에 남긴다. 필터 전 페이지 크기 20을 유지하고, 필터 후 빈 첫 화면은 시작·갱신당 최대 3페이지까지 자동 보충한다.
- 빈 목록 문구로 공개 탐색과 레이드 현황의 역할을 안내한다. Rules는 변경하지 않는다.
- 표적 테스트·analyze 통과. 실기기(1대)에서 내가 만든 방 제외, pending 신청 유지, 현황 목록 정상을 확인했다. 다른 Player 방의 확정 멤버 제외는 2인 환경이 없어 실기기 미실시(같은 함수 테스트로 고정).
- `main` 반영: `6597d7a`.
- 다음 실행: Task-083 운영자 계정 권한 기반 설계.

---

## Task-083. 운영자 계정 권한 기반 설계 (2026-08-28)

- `OPERATOR_AUTHORIZATION_CONTRACT.md`를 추가해 `PlayerId` 기반 운영자 지정과 일반 사용자 권한 분리를 확정했다.
- 사용자가 게임 계정별 짧은 코드를 인게임 일반 채팅에 입력하고 전체 화면을 오픈카톡으로 제출하는 운영자 수동 인증 흐름을 정했다.
- 운영자 판정은 승인·취소·인증 금지로 나누고 Player·대상 GameAccount별 요청 횟수를 판단 자료로 사용한다.
- 기존 active 소유자가 있으면 24시간 재인증 기회를 주며, 방어 성공 시 신규 요청자의 해당 계정 인증을 금지하고 무응답이면 추가 운영 승인 없이 자동 이전한다.
- Spark에는 예약 실행 서버가 없으므로 만료 결과는 자동 확정하되 실제 이전 Transaction은 기한 후 최초 안전한 앱·운영자 접근에서 멱등 반영한다.
- `players.lastSeenAt` 최신값만 새 앱 실행당 한 번 기록하고 운영자 사용자 목록은 접속 기록 없음·오래된 접속순으로 조회한다.
- 로컬 전용 대표 캐릭터·미인증 계정은 추가 업로드하지 않으며 서버에서 대표를 정할 수 없으면 `대표 캐릭터 지정 안 됨`으로 표시한다.
- 사용자 삭제·삭제 대기·강제 삭제와 앱 재설치 우회 차단은 보류했다.
- 다음 구현: Task-084 운영자 권한·마지막 접속 기반.

---

## Task-084 후속 설계. 대표 Character 서버 동기화 (2026-08-28)

- 실기기에서 운영자 `사용자 확인` 진입과 목록 표시를 확인했다.
- 기존 구현은 운영자 read model의 `representativeCharacterName`을 null로 두고 대표 선택은 Drift에만 저장해, 대표 Character가 있는 사용자도 `대표 캐릭터 지정 안 됨`으로 표시됐다.
- active 서버 소유 관계가 있는 계정은 `playerGameAccounts`에 서버 `representativeCharacterId`와 서버 갱신 시각을 동기화한다. 로컬 정수 ID와 미인증 계정 데이터는 업로드하지 않는다.
- 대표 변경은 GameAccount별 5분에 한 번만 성공하며 UI와 Firestore Rules 양쪽에서 제한한다. Rules는 현재 active 소유자, 같은 계정의 active Character, 값 변경, `request.time`을 검증한다.
- 같은 Character 재선택과 저장 중 연속 터치는 쓰기를 만들지 않고, 서버 저장 성공 뒤에만 로컬 대표 선택을 반영한다. 오프라인 변경은 거절한다.
- 기존 로컬 대표는 대응하는 active 서버 Character가 있을 때 계정당 한 번 보강하고 그 시점부터 5분 제한을 적용한다.
- 운영자 목록은 대표가 여러 계정이면 `Character명 외 N개`, 상세는 GameAccount별 대표 Character를 표시한다.
- `RepresentativeCharacterSyncGateway`와 Firestore 구현을 추가해 active 소유 계정의 대표 Character를 서버에서 읽고 Transaction으로 변경한다.
- 내 계정 진입 시 계정별 한 번 로컬 대표를 서버에 보강하거나 기존 서버 대표를 로컬에 조정한다. 캐릭터 관리에서는 서버 저장 성공 뒤에만 로컬 대표를 변경한다.
- Rules는 현재 active 소유자, 같은 GameAccount의 active Character, 실제 값 변경, `request.time`, 이전 변경 후 5분 경과를 검증한다. 해당 Rules는 2026-08-28 Firebase `lost-party`에 배포했다.
- UI는 저장 중 중복 터치와 쿨다운 중 변경을 막고 남은 시간을 표시한다. 운영자 목록은 `Character명 외 N개`, 상세는 계정별 대표 Character를 표시한다.
- 전체 `flutter test` 464건과 `flutter analyze`를 통과했다.
- 실물 기기의 최초 보강·5분 차단·재실행 유지·운영자 목록·상세·일반 Player 차단 확인은 사용자가 수행한다. AI는 확인 항목만 전달하고 기기 조회·설치·실행을 하지 않는다.
- Task-084 운영자 기반 구현은 `d31ce01`, 대표 동기화 준비 문서는 `a7ee7ed`에 반영됐다. `a7ee7ed`에서 `codex/task-084-representative-character-sync`를 생성했다.
- 대표 Character 동기화 구현을 `f15c1b6`으로 작업 브랜치에 커밋했다. 사용자 지시에 따라 브랜치는 실물 기기 테스트와 분리해 `main`에 병합·푸시하고, 해당 테스트는 Task-085 시작 전 필수 게이트로 유지한다.

---

## Task-084b. 대표 초회 보강과 사용자 변경 분리 (2026-08-29)

- 작업 브랜치: `cursor/representative-seed-reconcile`
- 초회 보강은 `representativeCharacterId`만 쓰고 `updatedAt`을 남기지 않아 5분 제한을 시작하지 않는다.
- 사용자가 캐릭터 관리에서 대표를 바꿀 때만 `updatedAt`을 기록하고 5분을 적용한다.
- Drift schema 10에 계정당 서버 대표 맞춤 기록을 추가해, 내 계정 재진입·탭 전환에서 Firestore GET/SET을 생략한다.
- Rules에 `validRepresentativeCharacterSeed`를 추가했다. 사용자가 Firebase `lost-party`에 재배포했다(2026-08-29).
- 표적 테스트와 `flutter analyze`를 통과했다.
- 실기기: 5분 타이머 UI는 정상. 탭 전환 통신은 로그를 보지 않아 화면 확인을 생략하고, 로컬 맞춤 기록 skip 테스트로 대체했다.
- Git 종료: 기능 브랜치를 `main`에 병합하고 원격과 맞춘다.

---

## Task-085. 수동 인증 요청과 운영자 1차 판정 (2026-08-29)

- 작업 브랜치: `cursor/task-085-manual-verification`
- 사용자는 설정에서 게임 계정·증명 캐릭터를 고르고 `LP-` 코드를 받아 인게임 일반 채팅 전체 화면을 운영자 오픈카톡으로 보낸다. 스크린샷은 Firestore에 올리지 않는다.
- 운영자 `수동 인증 확인`에서 대기 요청을 오래된 순으로 보고 승인·취소·인증 금지를 처리한다.
- 승인 시 Lost Ark API roster를 다시 조회하고, 기존 active 소유자가 없을 때만 GameAccount 전체 소유를 요청자에게 확정한다.
- 085 결정: 기존 소유자가 있으면 `existingOwner`로 거절하고 `awaitingOwnerResponse`는 열지 않는다.
- Rules·인덱스를 추가했고, 사용자가 Firebase `lost-party`에 배포했다(2026-08-29).
- 코드 발급 시 없는 인증 금지 문서 get이 permission-denied로 거절되던 문제를 고쳤다. Rules 재배포가 필요하다.
- 내 요청 목록이 `createdAt` 복합 인덱스 구독 실패로 코드가 사라지던 문제를, 단일 필드 조회 후 클라이언트 정렬로 고쳤다.
- 재발급 UI는 제거했다. 새 코드는 요청 취소 후 다시 발급한다.
- 수동 인증 안내에 운영자 오픈채팅방 링크를 연결했다.
- 진행 중 요청은 로컬 게임 계정(원정대) 단위로만 하나 허용한다. 같은 계정의 다른 캐릭터 중복 요청은 거절한다.
- 발급 문서에 null 필드를 넣어 Rules가 거절하던 문제와, 목록 구독이 매 빌드마다 끊기던 문제를 고쳤다. 취소된 요청은 내 요청 목록에 올리지 않는다.
- 운영자 대기 목록은 복합 인덱스 없이 status만 조회한 뒤 오래된 순으로 정렬한다.
- 표적 테스트와 `flutter analyze --no-pub`을 통과했다.
- 커밋은 사용자 지시 시.

---

## Task-086. 기존 소유자 방어·자동 이전·강제 인증 (2026-08-29)

- 작업 브랜치: `cursor/task-086-owner-defense`, 기능 커밋 `8c649ad`
- 구현: 분쟁 상태(`awaitingOwnerResponse`·`defended`·`transferred`), 분쟁 개시, 방어 승인, 기한 후 자동 이전, 운영자 강제 인증, 분쟁 알림 이벤트, 운영자 UI
- Rules·인덱스: `lost-party`에 여러 차례 배포. 최종 Rules는 `validManualVerificationOperatorWrite` 단일 진입점
- Rules 차단 원인: 선택 필드 `defenseOfRequestId`가 없는 일반 요청에서 필드를 직접 읽어 Rules 평가 오류가 발생했다. 존재 여부를 먼저 검사하도록 수정했다.
- 승인 결과를 활성 요청 목록 필터 전에 처리해 요청자 로컬 GameAccount·Character 서버 ID를 연결하고, 같은 GameAccountId의 누락 매핑도 보강한다.
- 수동 인증 화면에 완료 후 재진입·별도 완료 알림 없음·반복/부정확 요청 제한 가능성을 빨간 경고로 표시한다.
- `방어 실패`를 추가했다. 방어 요청은 `ownerDefenseFailed`로 종료하고 신규 요청자에게 즉시 이전하며 기존 소유자에게 자동 인증 금지는 적용하지 않는다.
- 로컬: 전체 `flutter test --no-pub` 488건 통과, `flutter analyze --no-pub` 통과
- 실기기:
  - **동작:** 취소, 일반 승인, 분쟁 개시, 운영자 거절, 방어 승인, 방어 실패, 강제 인증
  - **동작:** 즉시 소유권 이전, 기존 소유자의 레이드 Character 후보 제외, 거절·방어 승인 시 기존 권한 유지
  - **미검증:** 실제 24시간 무응답 후 자동 이전
- BUG-008은 수정·Rules 배포·실기기 확인 후 종료. 해결 경과는 [`TASK-086-OPERATOR-WRITE-BLOCKER.md`](TASK-086-OPERATOR-WRITE-BLOCKER.md)에 보존한다.

---
# 2026-08-30 그룹 제품 흐름 문서화

- 하단 4개 탭을 유지하며 설정 탭을 그룹 탭으로 교체하고, 설정은 내 계정 상단에서 진입하는 방향을 확정했다.
- 그룹 생성·대표 캐릭터·초대·가입 신청·초대코드 즉시 가입, 그룹장/일반 멤버 권한과 승계, 단일 그룹 레이드와 공개 범위 전환, 복수 그룹 목록 필터를 제품 문서에 정리했다.
- 그룹 이력은 `groupId + occurredAt + expireAt`으로 3개월 보관하고, 1개월 미활동 표시·soft delete 후 28일·Spark 운영자 수동 정리 방향을 기록했다.
- 같은 데이터 정리 기반을 일반 레이드와 사용자 데이터에 후속 적용하되 현재 코드·Rules에는 반영하지 않는다.
- 기준 문서: [`../product/GROUP_PRODUCT_FLOW.md`](../product/GROUP_PRODUCT_FLOW.md)

---

## Task-11. 그룹 생성·가입 Firestore/Rules 계약 분리 (2026-08-31)

- 확정된 그룹 제품 정책을 [`../architecture/FIRESTORE_GROUP_MEMBERSHIP_CONTRACT.md`](../architecture/FIRESTORE_GROUP_MEMBERSHIP_CONTRACT.md)로 분리했다.
- 그룹 membership, 활성 관계 요청, 누적 신청 횟수와 신청 금지를 모두 `groupId + playerId` 단위로 고정했다. Character는 검색·표시 Snapshot과 향후 레이드 선택에만 사용한다.
- `groups`, 멤버·요청·통계·금지 하위 문서, Player별 membership state·관계 Projection, 정확한 초대코드 조회 경로를 정의했다.
- 그룹 50명과 Player별 50개 그룹 제한을 그룹 인원·Player 그룹 ID 요약·membership의 같은 Transaction 및 Rules `getAfter()`로 강제한다.
- 그룹 생성, 초대·신청, 수락·승인·거절·금지, 초대코드 생성·폐기·즉시 가입의 상태 전이와 동시성 실패 조건을 확정했다.
- Task-11에서 탈퇴·추방·이전·해산·그룹 레이드·알림·공지는 제외하고 해당 쓰기를 Rules가 미리 허용하지 않도록 했다.

---

## Task-11. 그룹 생성·가입 구현과 부분 실기기 (2026-08-31)

- 작업 브랜치: `cursor/task-11-group-membership`, 기능 커밋 `b673fdb`
- 구현: `lib/features/group` Domain/DTO/WritePlan/Firestore Repository·Rules·인덱스, 4번째 탭 `그룹`, 설정은 내 계정 톱니 진입
- Unit 1~5: 생성·내 그룹·검색·상세, 초대·신청·수락/거절/취소, 그룹장 승인·거절·금지, 초대코드 생성·폐기·공개·즉시 가입, 오류 매핑·요청 현황
- 자동 검증: 그룹 표적 테스트·`flutter analyze --no-pub` 통과 (구현 당시 그룹 137건 수준)
- 실기기 확인(사용자):
  - **동작:** 초대코드 생성, 폐기, 멤버에게 코드 표시 토글
  - **동작:** 코드로 즉시 가입, 그룹 인원 2명 표시
  - **동작:** 생성 시각·마지막 활동 시각 표시
  - **미구현 UI:** 그룹원 목록(카드·상세). Rules는 그룹원 list 허용이나 화면 미연결
  - **계약 제외:** 탈퇴 버튼 없음 → 연속 시나리오 검증이 막힘
- Emulator §12.4–12.5 동시성·Codex 재검토·`main` 병합은 미실시
- 다음 실행: 멤버 목록 UI + 일반 멤버 탈퇴(실기기 연속 검증용), 이후 재검토·병합

---

## Task-11a. 그룹 멤버 목록·탈퇴·표시 Snapshot (2026-08-31)

- 작업 브랜치: `cursor/task-11-group-membership` (Task-11 `b673fdb` 위, 문서·커밋 시점 미병합)
- 구현 범위:
  - 그룹 상세 **멤버 목록 UI**: 그룹장 우선·`joinSequence` 정렬, 카드에 직업·아이템 레벨·전투력
  - 멤버 탭 → 인증 캐릭터 bottom sheet
  - **일반 멤버 탈퇴**: `GroupLeaveWritePlan`, Repository leave 명령, Rules(로컬)
  - **표시 Snapshot**: `displayClassNameSnapshot`, `itemLevelSnapshot`, `combatPowerSnapshot` — 생성·가입·코드 가입 시 저장
  - **본인 Snapshot self-refresh**: 그룹 상세 진입 시 로컬 캐릭터와 비교해 membership만 갱신 (`validGroupMemberSelfSnapshotRefresh`)
  - **전투력 표시**: 타 그룹원은 서버 membership Snapshot을 읽음. 로컬 roster만으로 UI 보강하던 경로 제거
  - Read: `GroupMemberDisplayBuilder`, `loadGroupMembers` + character doc batch get
  - Write lookup: `GroupLocalMemberDisplayLookup` (가입·refresh 쓰기 전용)
- 자동 검증: 그룹 표적 테스트·widget 테스트 포함 ~159건 통과 (구현 시점), `flutter analyze` 통과
- **1차 종료:** 사용자 지시로 `main` 병합·푸시. 전체 기획·설계 재검토 기간에 들어간다.
- **열린 부채:**
  - Firestore Rules **전체 deploy 실패(503)** — leave·self-refresh Rules가 운영에 없을 수 있음
  - Task-11a 실기기(멤버 전투력·타인 Snapshot·탈퇴·재가입) 미실시
- 제외 유지: 그룹장 이전·해산·추방·그룹 레이드·알림·공지

---

## Task-11-R. Firestore Rules 복잡도 차단 (2026-08-31)

- 증상: `firebase deploy --only firestore:rules --project lost-party` 시 전체 Rules (~159KB, ~3470줄)에서 **503/409** 등 API 실패 반복
- 프로브: 검증 함수 본문 ~101개를 `return false` 스텁, `match`·경로 helper 유지 → **~76KB(47.9%)에서 compile·release 성공** (~13초)
- 결론: 문법 오류가 아니라 **단일 Rules 파일 컴파일·업로드 복잡도 한도**에 가깝다. Task-11 leave·Snapshot refresh 추가분도 동일 제약
- 운영 주의: 2026-08-31 저녁 **절반 프로브 Rules가 `lost-party`에 배포됐을 수 있음** → 대부분 쓰기 거부. 전체 원본 재배포는 503으로 실패 확인(사용자)
- 상태: Task-11·11a **코드는 `main`에 보존**. Rules 축소는 **재설계 후 열린 기술 부채**로 유지
- 상세: [`TASK-11-FIRESTORE-RULES-COMPLEXITY.md`](TASK-11-FIRESTORE-RULES-COMPLEXITY.md)

---

## Task-11·11a 1차 마무리와 재설계 대기 (2026-08-31)

- 사용자는 Task-11·11a를 **1차 완료**로 보고 전체 기획·설계를 다시 가져온다.
- Git: `cursor/task-11-group-membership` → `main` 병합·원격 푸시.
- 구현 AI는 새 설계 지시 전까지 추가 기능 구현을 시작하지 않는다.
- 재설계에 반드시 남길 항목: Rules 복잡도(503), 운영 프로브 Rules 잔존 가능, 11a 실기기 미완, Task-12 후보.

## Rules 복잡도 개선 1차 (2026-08-31)

- 별도 `codex/rules-complexity-reduction` 브랜치에서 원본 백업 후 탈퇴 그룹 탐색을 native List 연산으로 바꾸고 표시 Snapshot 갱신의 중복 비교를 제거했다.
- 필수 필드 존재와 허용 변경 필드, 호출자·식별자·값 타입 검사를 유지했다. 앱·스키마 변경 없이 Rules 소스 158,836 → 143,799 bytes.
- 관련 정적 계약 테스트와 Emulator 회귀 시나리오를 보강했다. 최종 표적 Flutter 테스트 33개 통과. 실제 Emulator 검증은 최소 Rules 대조 검사부터 로딩 503으로 막혀 미완료다.
- 사용자 지시에 따라 개선 내용만 기능 브랜치에 커밋한다. 배포·병합·푸시는 하지 않으며 원본 백업은 로컬에 보존한다.

## Rules 추가 개선 시작점·실행 계획 기록 (2026-08-31)

- 1차 개선 커밋 `25f88ff` 이후 사용자가 전체 Rules 배포를 지시했다. `lost-party:test` 컴파일 검사에서 503으로 실패해 새 Rules는 운영 반영되지 않았다.
- 이 커밋을 추가 개선의 기준 코드로 고정하고 같은 전용 브랜치에서 문서 계획을 기록한다. 이번에는 Rules·앱 코드 변경 없음.
- R0 검증 환경, R1 그룹 가입, R2 Player 요약·목록, R3 수정 검사, R4 이벤트, R5 명령 대상 명시, R6 표시/권한 데이터 분리 순으로 변경 대상·검증 기준을 정의했다. R5~R6은 설계 검토 후 별도 착수한다.
- 각 단계는 정상/거절 동작과 기능 보존 근거를 기록하고 독립 커밋으로 관리한다. 시험용 Rules의 운영 배포, 사용자 백업 변경, 무단 병합·푸시는 제외한다.
