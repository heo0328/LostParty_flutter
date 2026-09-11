# NEXT WORK

> 다음에 바로 진행할 단일 작업 그룹의 근거·범위·순서·완료 조건만 관리한다. 완료 경과는 `DEV_LOG.md`로 이동한다.

## 현재 인계 상태

- 통합 기준은 로컬·원격이 같은 `dev`다. Character Build 무결성 상태(`buildIntegritySnapshot`)와 그룹 활동 Character 목록 표시는 구현·자동 검증·실기기 확인까지 완료됐다.
- 계정 자동·수동 갱신이 Character 최소 표시 Transaction에 통합 무결성 상태를 동반한다. 그룹 상세는 기존 조회·활동 ID 교집합만 읽고 상태 Chip을 표시한다.
- 파티·그룹 membership의 `gemValidationSnapshot`은 그대로 유지한다. Rules·새 쿼리·인덱스·컬렉션은 변경하지 않았다.

## 다음 작업 그룹 — Character Build 오류·상태 표기 재정의 (협의 우선)

### 1. 최우선 목표

현재 구현된 Character Build 무결성·보석 관련 **오류·검토 표기의 의미와 명확성**을 제품 관점에서 재정의한다. 구현 코드 수정은 협의로 표기 계약이 확정된 뒤에만 한다.

### 2. 왜 지금인가

- 실기기에서 통합 상태 표시 자체는 통과했다.
- 다만 `보석` / `아크그리드` / `보석 확인 필요` / `보석 정보 없음` / `확인 불가` 등이 사용자에게 어떤 심각도와 행동 유도로 읽혀야 하는지 추가 토의가 필요하다.
- 저장 스키마(`status`·`issueCodes`)와 UI 문구·색·노출 위치가 한 번에 섞이면 회귀가 커지므로 **정의·협의를 제1 작업**으로 고정한다.

### 3. 포함 범위 (이번 단계)

- 표기 대상 화면 목록 정리(내 계정, 파티 카드/membership, 그룹원 목록 행, 그룹 활동 Character 목록 등)
- 각 상태·issue code의 의도된 의미, 심각도(오류 vs 검토 vs 정보 부족), 권장 문구·색·노출 여부
- `gemValidationSnapshot`(보석 전용)과 `buildIntegritySnapshot`(통합)의 표기 역할 구분
- 확정 결과를 `CHARACTER_BUILD_INTEGRITY_CONTRACT.md`와 `NEXT_WORK.md` 구현 구간에 반영할 초안

### 4. 제외 범위

- 협의 전 UI·mapper·저장 스키마·Rules 변경
- membership 보석 Snapshot을 통합 상태로 이행하는 구현
- 룬·각인·카드·엘릭서 등 새 판정 종류 추가

### 5. 완료 조건 (협의 단계)

- 사용자와 표기 재정의 결론이 문서에 기록된다.
- 구현이 필요하면 별도 작업 그룹으로 범위·순서·회귀 목록을 새로 잡는다. 정의만으로 끝나면 이 그룹을 닫고 차후 대기로 옮긴다.

## 차후 대기

- 기존 파티·그룹 membership 보석 Snapshot을 통합 Build 상태로 바꿀지 별도 검토
- 룬·각인·카드·엘릭서 등 통합 무결성 상태 확장
- Build 별칭·직업 메모·JSON 공유: `BUILD_MEMO_SHARING.md`
- 여러 일반 딜러 직업의 실계정 확대 검증
- 서버 데이터 무결성·고아 binding/claim·복구 절차
- 직업 시너지 선택·필터: `CLASS_SYNERGY_CATALOG.md`
- `characters` Rules의 넓은 `signedIn()` 읽기·쓰기 권한 재설계(별도 승인)
