# NEXT WORK

> 다음에 바로 진행할 단일 작업 그룹의 근거·범위·순서·완료 조건만 관리한다. 완료 경과는 `DEV_LOG.md`로 이동한다.

## 현재 인계 상태

- 통합 기준은 로컬·원격이 같은 `dev`다. 그룹 membership 보석 Snapshot 전파는 `cursor/group-membership-gem-snapshot`에서 구현·Rules 콘솔 게시·실기기 회귀 후 `dev`에 병합됐다.
- 파티·그룹 membership 표시 Character의 `gemValidationSnapshot`과 목록 행 경고는 현재 범위다. 그룹원 탭 후 활동 Character 목록의 보석 표시는 별도이며 **정의 선행**이다.
- 완료 상세는 `DEV_LOG.md`와 `CHARACTER_BUILD_INTEGRITY_CONTRACT.md`다.

## 다음 작업 그룹 — 사용자 지시 대기

차후 대기 항목 중 다음에 착수할 단일 그룹을 사용자가 지정하면 그 범위로 `NEXT_WORK`를 교체한다. 그룹 활동 Character 목록 보석 UI는 **제품·아키텍처 정의를 먼저** 확정한 뒤에만 구현 그룹으로 올린다.

## 차후 대기

- 그룹원 탭 → 활동 Character 목록의 보석 경고 표시: **구현 전에 제품·아키텍처 정의를 반드시 먼저 확정**한다. 현재는 membership 표시 Character 한 명의 `gemValidationSnapshot`만 저장·목록 행에 표시한다. 신청/표시가 A여도 같은 원정대의 B 보석 이상을 그 팝업 리스트에서 보려면, 데이터 출처(본인 로컬만 vs 서버 Snapshot), 저장 범위(활동 Character 전부인지), 자동 갱신·그룹 데이터 갱신과의 관계, UI 위치를 계약 문서로 확정한 뒤에만 착수한다. 정의 없이 코드부터 넣지 않는다.
- Build 별칭·직업 메모·JSON 공유: `BUILD_MEMO_SHARING.md`의 단계별 제품 결정을 먼저 확정
- 여러 일반 딜러 직업의 보석 판정 실계정 확대 검증
- 서버 데이터 무결성·고아 binding/claim·복구 절차: 반복 사례가 확인될 때 별도 착수
- 직업 시너지 선택·필터: `CLASS_SYNERGY_CATALOG.md`
