# NEXT WORK

## 기준 상태

- 기준 브랜치: `main`
- 선행 문서 브랜치: `codex/backend-party-group-architecture`
- 제품 방향: 정적 레이드 카탈로그를 기반으로 서버 검증형 파티 모집과 계정 그룹 구현
- 백엔드 기준: `BACKEND_PARTY_ARCHITECTURE.md`
- 새 작업 시작 전 문서 브랜치의 `main` 병합과 로컬/원격 `main` 일치를 확인한다.

---

## 이번 작업 그룹의 목표

Lost Ark API에서 제공하지 않는 레이드 기준정보를 수기 관리할 정적 JSON 카탈로그의 Domain 구조와 검증 규칙을 확정한다.

실제 전체 레이드 데이터를 한 번에 입력하지 않고, 기존 `RaidBase`/`RaidVariation` 구조와 모집 조건에 필요한 필드를 검토해 최소 샘플 한 개로 구조를 검증한다.

---

## 포함 범위

- 레이드 카탈로그 버전과 갱신 시각
- 레이드 ID, 표시명, 파티 정원 및 관문 수
- 난이도 ID, 표시 순서, 최소 아이템 레벨 및 보상 골드
- 활성/비활성 상태
- 관문 선택 범위 검증
- 중복 ID, 잘못된 참조, 정원/관문/레벨/보상 범위 검증
- 모집글이 참조할 `raidId`, `difficultyId`, `catalogVersion` 경계
- 최소 레이드 샘플과 Domain/Mapper/Validator 테스트

---

## 제외 범위

- 전체 레이드 수기 입력
- Firebase 프로젝트 생성 및 SDK 추가
- 모집글 작성 UI 변경
- 파티 신청과 승인 정책 구현
- 계정 그룹 구현
- 보상 계산 또는 주간 숙제 관리

---

## 결정 원칙

- JSON 카탈로그는 Git으로 버전 관리한다.
- UI와 서버는 임의 입력값이 아니라 같은 카탈로그 ID를 참조한다.
- Firebase 연결 전에 Domain과 검증 규칙을 로컬 테스트로 확정한다.
- 기존 Repository 경계를 유지하며 UI가 asset 데이터 소스를 직접 읽지 않는다.
- 실제 레이드 데이터는 구조가 확정된 후 별도 작업 단위로 입력한다.

---

## 작업 순서

1. 기존 Raid Domain, local data source와 모집글 참조 구조 확인
2. 코드 수정 없이 신규 카탈로그 작업안 제시
3. 새 기능 브랜치 생성
4. 레이드 카탈로그 Domain/Mapper/Validator 구현
5. 최소 JSON 샘플과 관련 테스트
6. 전체 analyze/test 실행
7. 필요 시 화면 영향 실기기 검증
8. 문서화, 기능 브랜치 푸시 및 `main` 병합·푸시

권장 브랜치명: `codex/raid-catalog-foundation`

---

## 완료 조건

- 레이드 기준정보의 소유와 버전 경계가 명확하다.
- 잘못된 카탈로그가 앱 또는 서버 기준정보로 사용되기 전에 거부된다.
- 모집글이 임의 정원/레벨 대신 검증된 카탈로그 ID를 참조할 수 있다.
- 관련 테스트와 전체 검증이 통과한다.
- 로컬과 원격 `main`이 같은 최종 커밋을 가리킨다.

---

## 후속 작업 순서

1. 실제 레이드 카탈로그 데이터 입력
2. 모집 조건 및 승인 정책 Domain
3. 신청·투표·가입 상태 머신과 Fake Repository
4. Firebase Auth 및 Firestore 읽기 모델
5. Callable Functions와 Transaction
6. 계정 그룹 초대/수락 및 그룹 전용 모집글
7. Security Rules와 Emulator 다중 사용자 테스트
