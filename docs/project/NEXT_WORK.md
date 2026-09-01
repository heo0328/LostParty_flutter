# NEXT WORK

## 현재 우선 작업 — 자리·인원·상태에 맞춘 raidListings 갱신

현재 단계: **다음 작업 대기**. 직전 완료는 생성 후 `그룹만 공개 ↔ 전체 공개` 전환. 브랜치 `codex/raid-visibility-toggle`. Git SHA는 로그로 확인한다. 제품 기준은 [`../product/GROUP_PRODUCT_FLOW.md`](../product/GROUP_PRODUCT_FLOW.md) §9.

- listing은 생성·공개 범위 전환 시점 스냅샷이다. 자리·인원·방 해산 후에도 listing `status`가 남을 수 있다.
- 그룹 해산 게이트는 listing만 보지 않고 `recruitments` 원본의 그룹 전용·active 여부를 확인한다.
- `recruitments` list에 `visibility==group` 쿼리나 문서별 그룹 membership `exists`를 넣지 않는다.

### 2026-09-01 확정한 구현 기준

- 원본 모집 변경과 listing 변경은 반드시 같은 Firestore Transaction에서 원자적으로 처리한다.
- 이번 작업은 현재의 모집 Snapshot Projection 구조를 유지한다. 새 축약 listing 스키마로 마이그레이션하지 않는다.
- 그룹 전용 모집은 목록 관련 값이 바뀔 때 현재 Transaction 후 모집 Snapshot으로 listing을 생성 또는 전체 덮어쓴다. listing이 없으면 이 변경 시점에 생성해 자연 복구한다.
- 만석, 완료 취소 가능 상태, 반복 모집의 다음 주 대기처럼 다시 노출될 수 있는 상태는 listing을 유지하면서 인원·자리·회차·상태를 최신화한다.
- 전체 공개 전환과 방 해산처럼 되돌릴 수 없는 종료는 listing을 삭제한다. `completed` 문자열만으로 삭제 여부를 정하지 않는다.
- 동기화 필드는 `status`, `currentCycleStatus`, `manualRecruitmentEnabled`, `memberCount`, `maxMemberCount`, `hasAvailableSlot`, 멤버·자리 Snapshot, 회차 키·시각, 수정 가능한 카드 표시 필드, `revision`, `updatedAt`을 포함한다. 구현 시 실제 모집 스키마와 공개 카드 매퍼를 대조해 정확한 목록을 테스트로 고정한다.
- Rules는 `getAfter()`의 모집 원본과 listing 핵심 필드의 일치를 검증하도록 강화한다. 원본 이후 별도 후처리나 화면 진입 보정은 사용하지 않는다.
- 상세 계약은 [`../architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md`](../architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md) §4.2.1을 따른다.

### 구현 전 영향 범위 점검

- 즉시 가입·신청 승인
- 파티원 탈퇴·추방
- 캐릭터·자리 변경
- 모집 완료·완료 취소·다음 회차 전환
- 반복 여부와 모집 활성 상태 변경
- 모집 해산
- 카드 표시 정보 수정과 공개 범위 변경

승인 권한처럼 목록 결과에 영향을 주지 않는 변경은 제외할 수 있다. 기존 방 전체 일괄 보완, 그룹 전용 자격 박탈, 그룹 필터는 이번 작업에 포함하지 않는다.

### 직전 완료 — 생성 후 그룹만 공개 ↔ 전체 공개 전환

- 파티장 상세의 `그룹만 공개` 스위치로 `group <-> public`을 바꾼다. `groupId`는 유지한다.
- 전체 공개면 listing을 삭제하고, 다시 그룹 전용이면 현재 모집 스냅샷으로 listing을 만들거나 덮어쓴다.
- 전체 공개 → 그룹 전용은 비그룹 참가자나 유효한 비그룹 신청이 있으면 거절한다.
- 사용자 Rules 배포 후 비그룹 계정 모집에서 숨김·표시·재숨김을 확인했다. 방장 본인 방은 모집 리스트가 아니라 레이드 현황에 있다.

### 직전 완료 — 그룹장 즉시 지정 이전·후속 탈퇴·1차 해산

브랜치 `codex/group-leader-exit`. 계약 [`../architecture/GROUP_LEADER_EXIT_DISBAND_CONTRACT.md`](../architecture/GROUP_LEADER_EXIT_DISBAND_CONTRACT.md).

- 실기기: 1인 해산, 즉시 이전, 이전 후 기존 그룹장 탈퇴, 후임 그룹장의 그룹 해산.
- 초대코드는 기간 만료가 없고 원문은 세션 메모리에만 있다. 폐기 대화상자는 컨트롤러를 대화상자 수명에 맞춘다.
- 활성 그룹 레이드 해산 차단은 listing 스냅샷이 아니라 `recruitments` 원본 status로 판정한다.
- 그룹 해산은 레이드방을 자동 해산하지 않는다. 관련 Rules는 사용자가 배포했다.

### 이후 구현 순서

1. 자리·인원·상태 변경에 맞춘 `raidListings` 갱신
2. listing이 없는 기존 그룹 레이드 보완
3. 그룹 탈퇴·추방·해산 시 그룹 전용 레이드 자격 박탈과 제한적 정리
4. 위 기능과 실기기 확인을 완료한 뒤 레이드 모집·현황 그룹 필터

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
