# 기존 서비스 발췌 — docs/architecture/WEEKLY_RAID_CLAIM_CONTRACT.md

원본 문서: docs/architecture/WEEKLY_RAID_CLAIM_CONTRACT.md ([현재 문서](../../../../../docs/architecture/WEEKLY_RAID_CLAIM_CONTRACT.md)). 분리일: 2026-10-13.
원본 전체 SHA256: bb5f4246baf57b7fd1b4ccd1153e3a3652826c629f5b780ec82c867f8f8dc9ac.
아래는 기존 Firebase 환경의 원문이다. 신규 서버의 실행 지시/배포 승인으로 사용하지 않는다. 행 범위는 분리 직전이며 링크 위치만 조정한다.

<a id="source-0001"></a>

## 발췌 1: ## 0. 현재 C* 저장 계약 (2026-09-18)

출처: docs/architecture/WEEKLY_RAID_CLAIM_CONTRACT.md · 원본 5~128행 · 원문 절: ## 0. 현재 C* 저장 계약 (2026-09-18).

## 0. 현재 C* 저장 계약 (2026-09-18)

이 절은 아래 Task-078/079 시기의 Claim·assignment 설명보다 우선한다. 아래 기존 절은 사용자 UX와 과거 데이터 호환 의도를 보존하기 위한 기록이며, 신규 명령의 저장 원장으로 해석하지 않는다.

### 0.1 단일 현재 원장

- 신규 데이터의 참가·완료 원장은 `players/{playerId}/raidStates/{characterId}_{raidId}`다.
- 현재 주차 `status == active`는 파티 참가 중, `status == completed`는 완료, 문서 부재는 둘 다 아님을 뜻한다.
- 파티 전체 완료는 `active → completed`이며 현재 주차의 파티 전체 완료를 되돌리는 공동 `완료 취소` 명령은 제공하지 않는다. 완료방 해산은 개인 `completed`를 보존한다.
- 파티 밖 수동 완료는 `status: completed`, `source: manual`인 `raidState`를 사용한다. 활성 파티에서 수동 완료하면 모집 탈퇴·필요한 승계 또는 단독 해산과 같은 Transaction에서 기존 state를 `completed`로 전환한다.
- `weeklyRaidClaims`와 `activeRaidAssignments`는 전환 전 데이터의 호환 원본이다. 신규 파티·수동 명령에서 함께 복제 쓰지 않는다.

#### BUG-024 인증 확장 (2026-10-07)

주차 전환 전 단건 인증은 기존 state에 여덟 `guard*` 필드만 추가하거나, state가 없으면
신원·소유권 차수와 인증 필드만 있는 정확한 availability-only stub을 저장한다.
stub에는 `status/source/cycleKey/revision`이 없으며 참가·완료 원장으로 해석하지 않는다.
현재 소유권 검증은 별도로 유지한다. 손상 자료를 stub으로 간주하지 않는다.
정확한 필드와 전환 불변식은 [Spark C 계약](../../../docs/architecture/RECURRING_CYCLE_SPARK_ALTERNATIVE_DESIGN.md)을 따른다.

기존 개인 완료·참가 명령은 원래 권한·점유 검사를 통과한 경우에만 stub을 정상 state로 대체하거나
인증 여덟 필드를 전부 제거한다. 일부 표식 제거·변조는 금지한다. 현재 주차 equality query는
cycleKey 없는 stub을 반환하지 않는다. 관찰 토큰에는 인증 필드도 포함해 확인 이후 변경을 감지한다.
legacy Claim 신규 생성은 현재 소유권 차수를 검증한다. 차수 누락은 실제 현재 차수0일 때만 허용하며,
이전 차수 자료의 호환 읽기와 해제 계약은 유지한다.

### 0.2 화면 판정과 과거 데이터 호환

동일 Character·raidId의 **현재 주차** 상태는 Claim 객체로 억지 변환하지 않고 `none | active | completed | legacyCompleted | legacyActive | inconsistent`인 별도 Projection으로 판정한다. `raidState` 문서 ID에는 주차가 없으므로 반드시 문서의 `cycleKey`가 현재 주차인지 확인하며, 이전 주차 state는 현재 체크·참가 제한에 사용하지 않는다.

1. 현재 주차 `raidState.completed`이면 `completed`다.
2. 현재 주차 `raidState.active`이면 `active`다.
3. 현재 주차 `raidState`가 없고 구 `weeklyRaidClaim`만 있으면 `legacyCompleted`다.
4. 현재 주차 `raidState`가 없고 구 `activeRaidAssignment`만 있으면 `legacyActive`다.
5. 현재 주차 state와 구 Claim 또는 assignment가 동시에 있으면 내용이 같아 보여도 `inconsistent`다. 이는 진단·정리 경로를 선택하기 위한 상태이며 사용자 개인 완료 해제를 영구 차단하는 상태가 아니다.
6. 어느 현재 주차 원장도 없으면 `none`이다.

`completed`와 `legacyCompleted`는 내 계정 체크박스를 체크하고, `active`와 `legacyActive`는 참가 중 영향 안내 대상으로 사용한다. `inconsistent`에서도 현재 주차의 본인 소유 완료 근거가 하나라도 있으면 체크 상태와 개인 해제 동작을 제공한다. 해제는 검증된 본인 완료 근거만 제한된 Transaction으로 제거하고, 함께 존재하는 active state·assignment·membership은 보존해 해제 뒤 미체크 + 참가 중으로 표시한다. 완료 근거 없이 active 근거만 겹치면 미체크 + 참가 중으로 표시한다. 소유권·Character·raidId·cycleKey를 검증할 수 없는 손상 문서는 임의 삭제하지 않고 구체적인 복구 안내를 반환한다. 구 Claim과 assignment는 일괄 마이그레이션 없이 호환 읽기·해제 및 이 제한된 수렴 경로에만 사용한다.

읽기 Projection과 쓰기 명령은 내부 구현 단계로 나눌 수 있지만 사용자에게 노출하는 완료 기능은 하나의 UX 단위다. `raidState`를 표시하면서 대응 쓰기 명령이 준비되지 않았다는 이유로 체크박스를 읽기 전용으로 만들지 않는다. 새 원장 쓰기가 준비되지 않았다면 해당 중간 상태를 운영에 게시하지 않고, 표시·수동 완료·개인 해제를 함께 연결한 뒤 검증한다. `inconsistent`라는 분류만으로 체크박스를 비활성화하지 않으며, 실제 문서의 소유권·식별자를 검증해 안전한 개인 완료/해제 명령 또는 구체적인 복구 경로로 연결한다.

이 Projection은 원장 상태를 공통 해석하는 값이지 모든 화면의 행동 정책을 하나로 합치는 객체가 아니다. 모집 후보는 `active/legacyActive`의 연결 모집이 종료·만료·고아인지 기존 `PartyCreateOccupancyGate`로 추가 판정하고, 내 계정은 실제 탈퇴·승계·단독 해산 영향을 별도로 계산한다. stale 판정과 개인 완료 영향 계산을 체크박스 표시 조건에 섞지 않는다.

### 0.3 명령 분리

- **내 계정 수동 완료**는 자기 Character 한 명만 대상으로 한다. 활성 참가 중이면 영향 안내 뒤 본인 membership 제거, 필요 시 파티장 승계 또는 단독 해산, 본인 `raidState` 완료 전환을 하나의 핵심 Transaction에서 처리한다.
- **모집 상세 파티 전체 완료**는 파티장·공대장이 현재 Aggregate의 모든 `raidState`를 `completed`로 바꾸는 기존 원자 lifecycle 명령이다. 내 계정 수동 완료의 참가 차단 조건을 이 명령에 적용하지 않는다.
- 개인 체크 해제는 출처와 관계없이 자기 완료 state와 호환 완료 Claim만 제거하고 모집의 공동 완료 Snapshot은 바꾸지 않는 기존 UX를 유지한다. 둘이 함께 존재하면 한 번의 사용자 동작으로 검증된 두 완료 근거를 함께 정리한다. active state·assignment·membership이 함께 있으면 이를 보존한다. 개인 해제는 과거 파티를 복원하지 않으며 공동 완료 취소 명령도 발생시키지 않는다.
- 반복방의 다음 주차 전환은 현재 membership을 기준으로 대상별 Rules 인증 후 전원 `active`를 원자 확정한다. 기록 없음은 인증 stub을 거치며, 유효한 이전 주차 완료는 다른 방·역할·난이도 기록도 현재 슬롯으로 전환할 수 있다. 같은 방의 유효한 active 전환도 유지한다. 새 주차 완료·다른 방의 활성 점유·소유권 불일치·미확인 기록은 덮어쓰지 않고 핵심 전환 전체를 거절한다. 준비 변경은 기존 완료 기록과 이벤트를 보존한다. 정상 전환에서 통합 state는 갱신되며 과거 완료 명단은 완료 당시 이벤트로 보존한다.
- 정상적인 현재 상태와 과거 데이터 불일치를 같은 권한 오류로 표시하지 않는다.

### 0.4 원자성·후처리 경계

- 참가 중 수동 완료의 모집 Aggregate, membership, 후임 권한, 본인 `raidState`와 핵심 이벤트는 한 Transaction에서 확정한다.
- 같은 레이드 pending 신청 수는 파티 최대 인원 8명과 무관하게 늘어날 수 있으므로 모든 신청 종료를 핵심 Transaction에 넣지 않는다. 완료 `raidState`를 먼저 원자 확정해 이후 승인·즉시 가입·생성·캐릭터 변경을 서버에서 최종 거절하고, 남은 pending 표시는 별도 비핵심 정리 또는 읽기 Projection으로 무효 처리한다.
- 신청 정리 지연이 두 번째 참가를 허용해서는 안 되며, 신청자 개인 상태를 파티장에게 공개하지 않는다. 승인 시 state 충돌은 Rules의 최종 검증으로 막는다. 승인 명령이 `permissionDenied`로 끝난 뒤에도 서버 Snapshot 기준으로 같은 모집·신청 revision, pending 상태와 승인 권한이 유지될 때만 `신청자의 참가 데이터에 오류가 있어 승인할 수 없습니다. 해당 신청을 거절해 주세요.`와 명시적 거절 선택을 제공한다. 캐시 상태이거나 전제가 달라졌으면 신청자 오류로 단정하지 않고 기존 상태 변경·권한 실패로 처리한다.
- 서버 상태가 완료된 뒤 표시만 늦는 것은 재구독으로 복구할 수 있지만, 핵심 상태 일부만 저장된 채 앱 재실행을 요구하는 구조는 허용하지 않는다.

### 0.5 state 출처와 전이

- 파티 밖 수동 완료 신규 state는 `source: manual`, `status: completed`, `recruitmentId: null`, `revision: 1`이다.
- 활성 파티에서 개인 완료로 전환한 state는 현재 방에서 유래한 사실을 추적할 수 있게 `source: manual`, `status: completed`로 바꾸되 기존 `recruitmentId`를 원인·Rules 검증용으로 보존하고 revision을 증가시킨다.
- 파티 전체 완료는 `source: party`를 유지한다. 같은 주차의 `party completed`를 공동 명령으로 `active`로 되돌리지 않는다. 반복방은 수요일 06시 다음 주차 전환에서 현재 membership을 기준으로 새 `active`를 구성한다.
- 위 출처 차이는 감사·전이 검증용이며, 현재 주차 `completed`의 체크 표시와 동일 레이드 참가 차단 의미는 같다.

### 0.6 완료 UX의 단일 인수 단위

다음 흐름은 여러 Repository와 화면을 지나더라도 하나의 사용자 완료 사이클이다.

```text
공대장의 파티 전체 완료
→ 모든 현재 멤버의 raidState를 completed로 원자 전환
→ 공용 완료 이벤트 한 건으로 각 수신자의 완료 기록 생성
→ 완료방 해산 후에도 개인 completed state와 완료 기록 유지
→ 내 계정에서 체크 상태와 참가/완료 안내 표시
→ 본인이 체크를 해제하면 자기 completed state만 제거
→ 동일 레이드 모집 생성·신청·가입 다시 허용
```

- 파티 전체 완료 명령은 공대장이 타인의 private `raidState`를 직접 읽지 않는다. 모집 Aggregate의 최대 8개 대상과 Rules의 `getAfter` 검증으로 전부 반영 또는 전부 거절을 보장한다.
- Rules 검증은 모집 Aggregate 갱신에서 최대 8개 대상을 한 번 확인하고, 각 `raidState`·공용 이벤트 쓰기에서는 자기 대상만 상수 비용으로 검증한다. 8개 state 각각에서 전체 8개 대상을 다시 검사하는 `8×8` 검증, 재귀 호출과 인원수 비례 이벤트 fan-out을 금지한다.
- 공용 이벤트는 Player별 이벤트를 복제하지 않는다. 대신 공통 `raidId/difficultyId/cycleKey`와 최대 8명의 `playerId/characterId` 완료 대상을 제한된 Snapshot으로 보존해 각 수신자가 자기 완료 기록을 만들 수 있게 한다.
- `active` 상태의 체크박스 오른쪽 안내 아이콘은 참가 중임을 설명한다. 안내 아이콘 때문에 체크박스 자체를 제거하거나 비활성화하지 않으며, 선택 시 기존 영향 확인 뒤 탈퇴·승계 또는 마지막 1인 해산과 개인 완료를 원자 실행한다.
- `completed` 상태는 체크된 상태로 표시하고 본인이 해제할 수 있다. 개인 해제는 모집의 공동 완료 Snapshot·다른 멤버 상태·해산된 방을 변경하지 않는다.
- 내 계정 체크는 서버의 돌이킬 수 없는 판정이 아니라 사용자가 이번 주 레이드 흐름을 관리하는 개인 UX다. `방 생성 → 완료 → 개인 체크 해제 → 다시 방 생성 → 완료 → 다시 해제`는 허용되는 정상 흐름이다. 공대장의 실수로 전체 완료된 경우에도 일반 참가자는 자기 체크를 해제할 수 있어야 한다.
- 완료 근거와 참가 근거가 동시에 있는 불일치 상태에서도 개인 해제는 완료 근거만 제거하고 참가 근거를 남긴다. 이때 동일 레이드 재참가·생성 가능 여부는 남아 있는 active 참가 상태로 다시 판정한다.
- 위 흐름은 내부적으로 나눠 구현할 수 있지만 `2인 이상 전체 완료 → 완료 기록 → 완료방 해산 → 체크 유지 → 본인 해제 → 재참가 가능`이 모두 통과하기 전에는 기능 완료·운영 안정화로 판정하지 않는다.

### 0.7 고아 active 참가 기록 복구

`raidState.status == active`, `source == party`인데 `recruitmentId`가 가리키는 모집 원본이 없거나 이미 종료·완료·만료된 경우는 실제 참가가 아니라 **고아 참가 기록**이다. 현재 주차 Projection이 문서 하나만 보고 이를 정상 `active`로 표시하더라도 수동 완료 명령은 존재하지 않는 모집의 탈퇴·승계·해산을 수행할 수 없으므로 완료 전환으로 우회하지 않는다.

- 내 계정의 체크 시도 또는 참가 안내 상세에서 고아 상태가 확인되면 `새로고침`을 요구하지 않는다. `종료되거나 삭제된 파티의 참가 기록이 남아 있습니다.`라고 원인을 알리고 `참가 기록 정리`를 별도 동작으로 제공한다.
- 정리 명령은 현재 바인딩 Player 본인의 정확한 `characterId + raidId` 문서만 대상으로 한다. 문서 ID·Player·Character·raidId·현재 cycle, `status: active`, `source: party`, 관찰한 `revision/recruitmentId`를 다시 검증한다.
- 서버는 연결 모집이 없거나 기존 stale 판정(`completed`, `disbanded`, `incompleteEnded`, 완료 회차, 만료된 비반복방)에 해당할 때만 삭제를 허용한다. 연결 모집이 여전히 활성이고 Player가 멤버라면 정상 참가로 취급해 정리를 거절한다.
- 같은 키의 구 `activeRaidAssignment`가 존재하면 동일 Player·Character·raidId·cycleKey·recruitmentId를 검증한 경우에만 같은 원자 명령에서 함께 삭제한다. 완료 `raidState`, `weeklyRaidClaim`, 다른 Character·raid의 신청과 상태는 건드리지 않는다.
- 정리 성공 후 Projection은 `none`으로 수렴하고 사용자는 필요하면 수동 완료를 새로 체크한다. 정리 동작 자체가 완료 기록을 만들거나 pending 신청을 자동 변경하지 않는다.
- 모집 신청 화면은 고아 active 상태를 일반 `신청 가능`으로 통과시키지 않는다. 신청자가 먼저 자기 기록을 정리하도록 안내하고, 승인자는 타인의 private state를 읽거나 대신 삭제하지 않는다. 경쟁 상황의 승인 서버 거절은 계속 최종 방어선으로 남긴다.
- 목록 전체에서 부모 모집을 추가 조회하는 N+1 검사는 도입하지 않는다. 정밀 판정은 사용자가 해당 상태를 조작하거나 상세 안내를 여는 시점의 단건 명령에서 수행한다.

콘솔에서 삭제된 모집을 참조하는 다수의 고아 신청·상태를 일괄 정리하는 운영 도구는 이 사용자 명령과 분리한다. 사용자 복구 기능은 본인 단건 상태를 안전하게 수렴시키는 기능이며 전체 데이터 정리나 관리자 권한을 대신하지 않는다.

#### 현재 주차와 이전 주차의 표시·복구 구분

`raidState` 문서 ID에는 주차가 없으므로 같은 Character·raidId의 이전 주차 문서도 현재 명령이 쓰려는 경로를 점유할 수 있다. 화면 표시와 쓰기 전 검증의 책임을 다음처럼 분리한다.

- **현재 주차 active 고아**: 현재 Projection에는 참가 경고를 표시한다. 완료 체크나 신청 시 `종료되거나 삭제된 파티의 참가 기록이 남아 있습니다.`와 `참가 기록 정리`를 제공한다.
- **이전 주차 active 고아**: 현재 주차 참가가 아니므로 내 계정의 현재 참가 느낌표를 표시하지 않는다. 완료 체크·신청·즉시 가입처럼 같은 문서 경로를 쓰기 직전 단건 조회에서 발견하면 `지난 주차의 종료된 파티 참가 기록이 남아 있습니다.`라고 안내하고 같은 정리 명령을 제공한다. 모집 생성은 동일 식별자와 연결 모집의 부재·종료를 Transaction에서 다시 증명한 stale state에 한해 기존 생성 재시도 계약으로 교체할 수 있으며, 유효 반복방이나 판정 불능 state에는 적용하지 않는다.
- 정리 명령은 UI가 요청한 현재 주차가 아니라 **실제로 관찰한 state의 cycleKey·revision·recruitmentId**를 전달하고 Transaction에서 다시 검증한다. 정리 뒤 현재 주차 완료나 신청을 자동 실행하지 않으며 사용자가 원래 동작을 다시 선택한다.
- **이전 주차 completed**는 고아 active가 아니다. 현재 화면에서 완료·참가로 표시하지 않고, 새 주차 쓰기에서 기존 주차 전환 계약에 따라 안전하게 교체한다. 이를 `참가 기록 정리`로 안내하거나 고아 오류로 삭제하지 않는다.
- **이전 주차 active지만 연결된 반복방이 여전히 유효한 경우**도 고아가 아니다. 먼저 반복방 주차 승계 또는 정상 참가 충돌로 처리하며 과거 cycleKey만으로 삭제하지 않는다.

따라서 `cycleKey != currentCycleKey`는 즉시 `stateInconsistent`로 끝낼 조건이 아니다. 먼저 base identity(Player·Character·raidId·status·source)를 확인하고, active면 연결 모집과 반복 여부를 판정한 뒤 `historicalOrphanActive`, 정상 반복 참가 또는 손상 데이터로 분리한다. 소유권·식별자·모집 수명을 증명하지 못한 문서는 계속 `안전하게 정리할 수 없음`으로 남긴다.

#### 신청자와 승인자의 비대칭 UX

- 신청 후보 목록은 현재 주차 Projection만으로 표시하므로 이전 주차 고아를 현재 참가 느낌표로 만들지 않는다. 대신 신청자가 신청 버튼을 누르면 본인 exact `raidState`를 Transaction에서 읽고 연결 모집을 단건 확인한다.
- 정상 active는 `동일 레이드 참가 중`, 현재/이전 주차 active 고아는 `종료된 파티의 참가 기록 정리 필요`, 현재 주차 completed는 `이번 주 동일 레이드 완료`로 신청 저장 전에 구분한다. 고아 상태를 신청 Transaction에서 자동 삭제하지 않는다.
- 이전 주차 completed는 오류가 아니므로 기존 주차 전환 정책에 따라 applicant 본인 쓰기에서 안전하게 치운 뒤 신청을 진행할 수 있어야 한다. active 고아의 명시적 정리와 같은 코드 경로로 합치지 않는다.
- Security Rules도 신청 create/reapply의 최종 상태에서 같은 Character·raidId의 `raidState`가 남아 있으면 pending 저장을 허용하지 않는다. 앱의 구체적 안내는 UX이고 Rules는 경쟁 상황의 최종 방어선이다.
- 승인자는 신청자의 private `raidState`를 읽거나 대신 정리하지 않는다. 새 신청은 신청 단계에서 차단하지만, 과거 pending 또는 신청 후 상태 변경은 승인 Rules에서 최종 거절될 수 있다.
- 승인 시 `permission-denied`가 발생했고 화면상 신청이 여전히 pending이며 승인 권한·revision 전제도 유지되는 경우 `신청자의 참가 데이터에 오류가 있어 승인할 수 없습니다. 해당 신청을 거절해 주세요.`를 표시하고 `닫기`와 `신청 거절`을 제공한다. 거절 버튼은 기존 bounded reject Transaction을 재사용한다.
- 자동 거절은 하지 않는다. Firebase의 `permission-denied`에는 신청자 상태 충돌 외 Rules·게시본 불일치도 포함될 수 있으므로 사용자의 명시적 거절 선택 없이 신청 상태를 변경하지 않는다. 거절도 revision 충돌이면 부분 변경 없이 최신 상세를 다시 읽는다.


<a id="source-0002"></a>

## 발췌 2: ## 4. Firestore 권장 모델

출처: docs/architecture/WEEKLY_RAID_CLAIM_CONTRACT.md · 원본 189~219행 · 원문 절: ## 4. Firestore 권장 모델.

## 4. Firestore 권장 모델

```text
players/{playerId}/weeklyRaidClaims/{cycleKey_characterId_raidId}
  schemaVersion: 1
  playerId
  characterId
  raidId
  cycleKey
  difficultyId
  source: manual | partyMember | partyOwner
  sourceRecruitmentId: String?
  sourceCompletionRevision: int?
  cycleStartedAt: timestamp
  cycleEndsAt: timestamp
  completedAt: server timestamp
  updatedAt: server timestamp
```

문서 ID는 `${cycleKey}_${characterId}_${raidId}`다. Firestore Rules가 같은 값을 직접 재구성해 임의 ID와 중복 Claim을 거절할 수 있어야 한다. `cycleKey`는 `YYYY-MM-DD`, 서버 Character ID는 Firestore 자동 ID 형식인 영숫자 20자, `raidId`는 소문자 영숫자와 밑줄만 허용한다. 표시 이름은 식별 키로 사용하지 않는다.

- `source == partyOwner`의 `sourceRecruitmentId`와 `sourceCompletionRevision`은 과거 전체 완료 출처를 식별하는 호환 메타데이터다. 신규 공동 완료 취소 명령에는 사용하지 않는다.
- 책임자는 출처와 관계없이 다른 사용자의 완료 Claim을 삭제할 수 없다.

### 기존 Claim과 멱등성

- 같은 키의 Claim이 이미 있으면 완료 처리는 성공으로 간주한다.
- 파티 전체 완료가 기존 수동 Claim을 덮어써서 출처를 잃게 해서는 안 된다.
- 최소 구현은 기존 Claim을 유지하고 없는 Claim만 생성한다.
- 출처 이력이 여러 개 필요해지면 Claim과 별도 이벤트로 보존하며 Claim 문서에 배열을 무제한 누적하지 않는다.


<a id="source-0003"></a>

## 발췌 3: ### 5.0 현재 구현 기준 — Task-078 완료

출처: docs/architecture/WEEKLY_RAID_CLAIM_CONTRACT.md · 원본 229~229행 · 원문 절: ### 5.0 현재 구현 기준 — Task-078 완료.

- 확인 후 아래 상태 변경을 하나의 Firestore Transaction으로 처리한다.

<a id="source-0004"></a>

## 발췌 4: ## 8. 명령별 Claim 강제 검증

출처: docs/architecture/WEEKLY_RAID_CLAIM_CONTRACT.md · 원본 392~392행 · 원문 절: ## 8. 명령별 Claim 강제 검증.

후보 UI의 로컬 사전 필터는 안내용이다. 최종 거절은 Firestore Transaction과 Security Rules가 담당한다.

<a id="source-0005"></a>

## 발췌 5: ## 9. 원자적 Transaction

출처: docs/architecture/WEEKLY_RAID_CLAIM_CONTRACT.md · 원본 394~421행 · 원문 절: ## 9. 원자적 Transaction.

## 9. 원자적 Transaction

개인 완료로 활성 파티에서 나오는 명령은 최소 다음을 하나의 Transaction으로 처리한다.

```text
membership 제거
+ activeRaidAssignment 삭제
+ pending 신청 종료
+ 모집 memberCount/roleCount/hasAvailableSlot/revision 갱신
+ 필요 시 책임자 승계 또는 단독 해산
+ weeklyRaidClaim 생성
+ Player Event 생성
```

일부만 성공하는 상태는 허용하지 않는다.

파티 전체 완료는 최소 다음을 하나의 Transaction으로 처리한다.

```text
cycle completed Snapshot 생성/갱신
+ 모집 currentCycleStatus/revision 갱신
+ 완료 당시 전원의 weeklyRaidClaim 생성
+ 전원의 activeRaidAssignment 삭제
+ 완료 당시 전원의 Player Event 생성
```

현재 최대 8인에서 Firestore Transaction 쓰기 수와 Security Rules document access 한도를 구현 전에 계산한다. Spark 클라이언트 Transaction으로 안전하게 검증할 수 없으면 구현을 넓히지 않고 서버 선행 여부를 다시 결정한다.


<a id="source-0006"></a>

## 발췌 6: ### 파티 전체 완료 취소 폐기

출처: docs/architecture/WEEKLY_RAID_CLAIM_CONTRACT.md · 원본 430~430행 · 원문 절: ### 파티 전체 완료 취소 폐기.

- 기존 `cancelCompletion` 명령·버튼·Rules 허용 분기는 제거 대상이다. 과거 `completionCancelled` 이벤트와 로컬 히스토리는 데이터 표시 호환을 위해 읽기만 유지한다.

<a id="source-0007"></a>

## 발췌 7: ## 11. Security Rules

출처: docs/architecture/WEEKLY_RAID_CLAIM_CONTRACT.md · 원본 440~462행 · 원문 절: ## 11. Security Rules.

## 11. Security Rules

### 자기 수동 완료

- active Auth binding의 Player만 자기 경로의 Claim을 생성·삭제한다.
- Claim의 Character가 현재 Player 소유의 active Character인지 검증한다.
- `cycleKey`와 `raidId` 형식을 검증한다.
- 자유로운 다른 Player Claim 쓰기를 허용하지 않는다.

### 파티 전체 완료

- 호출자가 현재 파티장·공대장인지 검증한다.
- 수신 Player가 완료 Snapshot 멤버인지 검증한다.
- Claim의 Character·raidId·cycleKey가 해당 membership과 cycle에 일치해야 한다.
- 같은 Transaction의 cycle 완료 상태 전이와 서버 시간을 검증한다.

### 개인 완료와 탈퇴

- 호출자와 Claim의 Player가 같아야 한다.
- 같은 Transaction에서 본인의 membership과 assignment가 제거돼야 한다.
- 책임자라면 승계 또는 단독 해산 불변식을 검증한다.
- 모집 count와 `memberPlayerIds`가 함께 갱신돼야 한다.


<a id="source-0008"></a>

## 발췌 8: ## 12. 현재 구현과 남은 간격

출처: docs/architecture/WEEKLY_RAID_CLAIM_CONTRACT.md · 원본 463~470행 · 원문 절: ## 12. 현재 구현과 남은 간격.

## 12. 현재 구현과 남은 간격

1. Drift `raidHistoryEntries.localStatusOverride`는 표시 정정일 뿐 모집 제한의 서버 근거가 아니다.
2. 기존 완료 이벤트는 개인 Claim과 별도 이력이므로 삭제하거나 Claim으로 직접 재사용하면 안 된다.
3. 레이드 상세 일반 멤버 `내 캐릭터 완료` 버튼은 아직 연결하지 않았다.
4. Task-080 F: 로컬 `WeeklyRaidClear`는 모집 게이트에서 **폐기**한다. 서버 Claim만 완료 근거다.
5. Task-080 F: E 이전 completed·해산 대기 방에 남은 `activeRaidAssignment`는 Claim으로 변환하지 않는다. 해당 모집이 `completed`/`disbanded`(또는 `currentCycleStatus == completed`)이고 assignment의 `recruitmentId`·`raidId`가 일치하면 **본인 점유만** 삭제한다.


<a id="source-0009"></a>

## 발췌 9: ## 13. 구현 작업 분해

출처: docs/architecture/WEEKLY_RAID_CLAIM_CONTRACT.md · 원본 471~515행 · 원문 절: ## 13. 구현 작업 분해.

## 13. 구현 작업 분해

### 단계 A — Claim 계약·Domain·읽기 기반

- Firestore 경로·문서 ID·Domain·Repository 계약
- 현재 Player의 이번 주 Claim 읽기
- 내 계정 체크박스의 읽기 전용 표시
- 기존 Drift 히스토리와 역할 분리 테스트

### 단계 B — 수동 체크·해제

- 활성 참가나 pending이 없는 Character의 Claim create/delete
- 본인 소유·주차·raidId Rules
- 다중 기기 체크 상태 동기화

### 단계 C — 모집 제한 강제

- 생성·신청·즉시 가입·승인·캐릭터 변경 Transaction에서 Claim 재검증
- 후보 UI 안내와 서버 오류 매핑
- BUG-005 회귀 테스트

### 단계 D — 활성 참가 중 개인 완료

- 영향 확인 UI
- 일반 멤버 탈퇴 + pending 종료 + Claim 생성
- 책임자 승계/단독 해산
- 완료 사유 탈퇴 이벤트

### 단계 E — 파티 전체 완료 — **완료 (Task-079)**

- 완료 권한을 파티장·공대장으로 제한
- Snapshot 전원의 Claim 멱등 생성
- active assignment 전원 해제
- 체크박스와 완료 이벤트 동기화
- 반복 파티의 제한적 전체 완료 취소(당시 구현, 2026-09-19 폐기 결정)

### 단계 F — 이행·실기기 검증 — **Task-080 (진행)**

- Drift 히스토리 정정은 표시 전용 유지. 로컬 `WeeklyRaidClear`는 게이트에서 폐기(Claim-only)
- completed/해산 대기 orphan assignment: Claim 미생성, 본인 점유 self-heal 삭제(Rules + 클라이언트)
- 수동 완료, 개인 완료, 전체 완료, 해제와 재모집을 2기기에서 검증
- 다레이드(표기 4~5) Claim 체크 검증

각 단계는 별도 검토·구현·검증·문서화가 가능한 작업 그룹으로 유지한다.


<a id="source-0010"></a>

## 발췌 10: ## 15. 구현 전 추가 확인 항목

출처: docs/architecture/WEEKLY_RAID_CLAIM_CONTRACT.md · 원본 530~530행 · 원문 절: ## 15. 구현 전 추가 확인 항목.

4. 파티 전체 완료·취소 Transaction의 Rules 접근 수 — Task-079에서 membership 공유 검증으로 약 12회(한도 20)로 확정
