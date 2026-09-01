# NEXT WORK

## 현재 우선 작업 — 생성 후 그룹만 공개 ↔ 전체 공개 전환

현재 단계: **착수**. 직전 작업(그룹장 즉시 이전·1차 해산)은 실기기 확인 후 `codex/group-leader-exit`에 커밋한다. 제품 기준은 [`../product/GROUP_PRODUCT_FLOW.md`](../product/GROUP_PRODUCT_FLOW.md) §9.

- 그룹 레이드는 생성 시 `그룹만 공개`가 기본값이다. 파티장이 이후 `그룹만 공개`를 끄면 전체 공개, 다시 켜면 그룹 전용이 되어야 한다.
- 전체 공개로 바꿔도 `groupId`는 유지한다.
- 전체 공개 → 그룹 전용은 비그룹 참가자나 유효한 비그룹 신청이 있으면 거절한다.
- 그룹 전용 목록은 `raidListings` Projection이다. 공개로 바꿀 때 listing을 제거하고, 다시 그룹 전용으로 바꿀 때 listing을 만들어야 한다. 현재 Rules는 listing `update, delete: if false`다.
- `recruitments` list에 `visibility==group` 쿼리나 문서별 그룹 membership `exists`를 넣지 않는다.

### 직전 완료 — 그룹장 즉시 지정 이전·후속 탈퇴·1차 해산

브랜치 `codex/group-leader-exit`. 계약 [`../architecture/GROUP_LEADER_EXIT_DISBAND_CONTRACT.md`](../architecture/GROUP_LEADER_EXIT_DISBAND_CONTRACT.md).

- 실기기: 1인 해산, 즉시 이전, 이전 후 기존 그룹장 탈퇴, 후임 그룹장의 그룹 해산.
- 초대코드는 기간 만료가 없고 원문은 세션 메모리에만 있다. 폐기 대화상자는 컨트롤러를 대화상자 수명에 맞춘다.
- 활성 그룹 레이드 해산 차단은 listing 스냅샷이 아니라 `recruitments` 원본 status로 판정한다.
- 그룹 해산은 레이드방을 자동 해산하지 않는다. Rules 배포는 별도 지시.

### 이후 구현 순서

1. 생성 후 `그룹만 공개 ↔ 전체 공개` 전환
2. 자리·인원·상태 변경에 맞춘 `raidListings` 갱신. 지금은 생성 스냅샷만 있고 방 해산 후에도 listing `status`가 남을 수 있다. 그룹 해산 게이트는 모집 원본을 확인한다.
3. listing이 없는 기존 그룹 레이드 보완
4. 그룹 탈퇴·추방·해산 시 그룹 전용 레이드 자격 박탈과 제한적 정리
5. 위 기능과 실기기 확인을 완료한 뒤 레이드 모집·현황 그룹 필터

### 필터 착수 게이트

- 필터 기획은 이미 [`../product/GROUP_PRODUCT_FLOW.md`](../product/GROUP_PRODUCT_FLOW.md) §8과 §15에 기록되어 있다.
- **필터 구현 직전 별도의 재확인·검토 단계를 반드시 거친다. 검토 완료 전에는 필터 코드를 수정하지 않는다.**
- 재검토에서 필터의 정의, 적용 화면, 포함 범위, 제외 범위, 복수 선택 의미, 기본값, 화면 간 공유, 앱 재시작 후 복원, 탈퇴·추방·해산 시 무효 선택 정리와 완료 조건을 다시 확정한다.
- 해당 문서와 당시 최신 모집 목록 Repository·레이드 현황 구조를 대조하고, 데이터 경계·로컬 상태 저장·테스트 계약을 확인한다.
- 기존 기획과 최신 코드가 충돌하거나 정의가 부족하면 사용자 검토를 거쳐 문서를 먼저 보완한 뒤 구현 작업 단위를 새로 확정한다.
- 필터는 표시 결과만 좁히며 조회·신청·참가 권한을 변경하지 않는다.

## 보존 지점

- 기존 보존 브랜치 codex/rules-complexity-reduction / ed02b31 및 Rules 사본 2개는 유지한다.
- 그룹 전투력 수정 4e4ab37 / 통합 eeba05f, 모집 UI 준비 문서 15eaf4a, 그룹 레이드 연결 61fd464 / 통합 25c3b44.
- 실제 시작 전에 git status·브랜치·HEAD를 확인하고 다른 미커밋 변경을 보존한다.
