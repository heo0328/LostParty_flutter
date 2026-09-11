# NEXT WORK

> 다음에 바로 진행할 단일 작업 그룹의 근거·범위·순서·완료 조건만 관리한다. 완료 경과는 `DEV_LOG.md`로 이동한다.

## 현재 인계 상태

- 통합 기준은 로컬·원격이 같은 `dev`다. Character Build 무결성 상태(`buildIntegritySnapshot`)와 그룹 활동 Character 목록 표시는 구현·자동 검증 후 `dev`에 병합됐다.
- 계정 자동·수동 갱신이 Character 최소 표시 Transaction에 통합 무결성 상태를 동반한다. 그룹 상세는 기존 조회·활동 ID 교집합만 읽고 상태 Chip을 표시한다.
- 파티·그룹 membership의 `gemValidationSnapshot`은 그대로 유지한다. Rules·새 쿼리·인덱스·컬렉션은 이번 작업에서 변경하지 않았다.
- 실기기 체크리스트(정상/보석/아크그리드·재인증 보존·그룹·파티 회귀)는 병합 후 사용자 확인이 남는다.

## 다음 작업 그룹

현재 고정된 단일 구현 작업은 없다. 다음 착수 전에 사용자와 후보를 하나 고른다.

## 차후 대기

- 실기기에서 Build 무결성 상태·재인증 보존·기존 그룹/파티 보석 경고 회귀 확인
- 기존 파티·그룹 membership 보석 Snapshot을 통합 Build 상태로 바꿀지 별도 검토
- 룬·각인·카드·엘릭서 등 통합 무결성 상태 확장
- Build 별칭·직업 메모·JSON 공유: `BUILD_MEMO_SHARING.md`
- 여러 일반 딜러 직업의 실계정 확대 검증
- 서버 데이터 무결성·고아 binding/claim·복구 절차
- 직업 시너지 선택·필터: `CLASS_SYNERGY_CATALOG.md`
- `characters` Rules의 넓은 `signedIn()` 읽기·쓰기 권한 재설계(별도 승인)
