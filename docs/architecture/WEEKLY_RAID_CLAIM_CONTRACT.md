# 캐릭터 주간 레이드 귀속 계약

> 2026-09-14 확장성 재설계 결정: 이 문서의 제품 정책은 유지하지만 신규 저장 계약은 별도 `activeRaidAssignments`와 `weeklyRaidClaims` 대신 통합 `raidState`를 사용한다. 상세 전환과 8인 원자 명령은 [`PARTY_GROUP_COMMAND_SCALABILITY_REDESIGN.md`](PARTY_GROUP_COMMAND_SCALABILITY_REDESIGN.md)가 우선한다.

## 0. 현재 C* 저장 계약 (2026-09-18)

이 절은 아래 Task-078/079 시기의 Claim·assignment 설명보다 우선한다. 아래 기존 절은 사용자 UX와 과거 데이터 호환 의도를 보존하기 위한 기록이며, 신규 명령의 저장 원장으로 해석하지 않는다.

### 0.1 단일 현재 원장

- 신규 데이터의 참가·완료 원장은 `players/{playerId}/raidStates/{characterId}_{raidId}`다.
- 현재 주차 `status == active`는 파티 참가 중, `status == completed`는 완료, 문서 부재는 둘 다 아님을 뜻한다.
- 파티 전체 완료는 `active → completed`이며 현재 주차의 파티 전체 완료를 되돌리는 공동 `완료 취소` 명령은 제공하지 않는다. 완료방 해산은 개인 `completed`를 보존한다.
- 파티 밖 수동 완료는 `status: completed`, `source: manual`인 `raidState`를 사용한다. 활성 파티에서 수동 완료하면 모집 탈퇴·필요한 승계 또는 단독 해산과 같은 Transaction에서 기존 state를 `completed`로 전환한다.
- `weeklyRaidClaims`와 `activeRaidAssignments`는 전환 전 데이터의 호환 원본이다. 신규 파티·수동 명령에서 함께 복제 쓰지 않는다.

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
- 반복방의 다음 주차 전환은 개인 해제로 이전 완료 state가 없어도 현재 membership을 기준으로 새 주차 `active` state를 생성할 수 있어야 한다. 문서가 있으면 같은 반복방의 직전 주차 state일 때만 갱신한다. 새 주차 수동 완료나 다른 모집의 active state가 이미 있으면 덮어쓰지 않고 전환 전체를 거절한다.
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

## 1. 목적

이 문서는 LOSTPARTY에서 다음 세 상태를 분리하고 다시 연결하는 단일 기준이다.

1. 파티방의 현재 진행 상태
2. 캐릭터가 현재 참가 중인 파티 점유
3. 캐릭터가 이번 주 해당 레이드를 실제 완료했는지 나타내는 개인 주간 완료 귀속

기존 구현은 파티 회차 완료 이벤트와 로컬 완료 기록은 갖고 있지만, 개인 주간 완료를 서버에서 모집 제한의 최종 기준으로 강제하지 않는다. `activeRaidAssignments`가 파티 참가 충돌과 완료 후 재참가 제한을 일부 대신하면서, 파티 완료·해산·개인 정정이 서로 어긋날 수 있다.

이 계약은 개인 주간 완료 Claim을 서버 단일 기준으로 추가하고, 레이드 상세의 완료 버튼과 내 계정의 체크박스가 같은 Claim을 조작하도록 확정한다.

## 2. 핵심 용어

- **파티 회차 상태**: 모집방의 공동 진행 상태. 신규 흐름은 `active`, `completed`, `disbanded`를 사용한다. 과거 `completionCancelled`는 읽기 호환 이력으로만 취급한다.
- **활성 파티 점유**: 캐릭터가 현재 동일 레이드의 다른 활성 파티에 중복 참가하지 못하게 하는 임시 점유다.
- **주간 완료 Claim**: 한 Player가 소유한 한 Character가 한 주차의 한 `raidId`를 실제 완료했다고 선언하는 서버 기록이다.
- **개인 완료**: 일반 파티원이 레이드 상세에서 자기 참가 캐릭터만 완료 처리하거나, 내 계정에서 직접 완료 체크하는 동작이다.
- **파티 전체 완료**: 파티장 또는 공대장이 현재 회차와 완료 당시 전 파티원의 Claim을 함께 완료 처리하는 동작이다.

## 3. 최종 불변식

### 3.1 개인 완료의 단일 기준

```text
주간 완료 Claim 있음
= 내 계정 체크박스 체크
= 동일 Character·raidId·cycleKey 모집 생성·신청·가입 제한

주간 완료 Claim 없음
= 내 계정 체크박스 해제
= 다른 충돌이 없다면 모집 생성·신청·가입 가능
```

Drift와 UI 체크 상태는 서버 Claim의 Projection이며 최종 권한 근거가 아니다.

### 3.2 완료와 활성 참가의 상호 배제

```text
같은 Player·Character·raidId·cycleKey에
주간 완료 Claim과 activeRaidAssignment가 동시에 존재할 수 없다.
```

Claim을 생성하는 명령은 기존 확정 참가와 pending 신청을 함께 정리한다. 모집 생성·신청·즉시 가입·승인·참가 캐릭터 변경은 Claim이 있으면 서버에서 거절한다.

### 3.3 난이도 관계

- 완료 키는 `playerId + characterId + raidId + cycleKey`다.
- `difficultyId`는 실제 완료 이력의 부가 정보다.
- 같은 `raidId`의 노말·하드·나이트메어는 별도 주간 Claim으로 중복 생성하지 않는다.

### 3.4 상태 소유권

- 파티 회차 상태는 모집 Current State와 cycle Snapshot이 소유한다.
- 활성 파티 점유는 `activeRaidAssignments`가 소유한다.
- 개인 주간 완료는 `weeklyRaidClaims`가 소유한다.
- 파티 완료 이벤트와 알림은 발생 사실의 이력이며 Claim 자체가 아니다.
- 사용자는 자기 Claim만 수동 생성·삭제할 수 있다.
- 파티장·공대장은 파티 전체 완료 Transaction 안에서만 완료 당시 멤버의 Claim을 생성할 수 있다.

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

## 5. 사용자 완료 경로

### 5.0 현재 구현 기준 — Task-078 완료

2026-08-27 `main`의 구현 범위는 다음과 같다.

- 내 계정 체크박스가 개인 주간 완료 Claim의 생성·삭제 UI다.
- 체크 전에 동일 `playerId + characterId + raidId + cycleKey`의 활성 점유와 승인 대기 신청 영향을 조회한다.
- 영향이 있으면 파티명, 탈퇴 여부, 책임자 승계 대상 또는 단독 해산, 종료할 신청 건수를 먼저 보여주고 사용자의 명시적 확인을 받는다.
- 확인 후 아래 상태 변경을 하나의 Firestore Transaction으로 처리한다.

```text
membership 제거
+ activeRaidAssignment 제거
+ 모집 memberCount/dealerCount/supportCount/hasAvailableSlot/revision 갱신
+ 필요 시 leaderPlayerId와 책임자 표시 Snapshot 승계
+ 단독 책임자라면 모집 해산
+ 동일 캐릭터·동일 레이드·동일 주차 pending 신청 종료
+ 본인 weeklyRaidClaim 생성
+ 남은 파티원에게 완료 사유 memberLeft 이벤트 생성
```

- 일반 멤버가 탈퇴할 때 기존 책임자의 `leaderCharacterNameSnapshot`과 `leaderClassNameSnapshot`은 그대로 보존한다.
- 책임자가 탈퇴하면 `memberPlayerIds`의 다음 멤버와 그 membership Snapshot으로 책임자를 승계한다.
- 같은 캐릭터라도 다른 `raidId`의 신청은 종료하지 않는다.
- 확인창에서 취소하면 위 문서 중 어느 것도 변경하지 않는다.
- Claim을 해제해도 이전 membership과 신청은 복구하지 않는다.
- 완료 탈퇴 전에 `approved`였던 application은 이력 문서로 남는다. Claim 해제 후 같은 방에 다시 신청할 때 현재 membership이 없다면 그 문서를 새 `revision`의 `pending`으로 재사용한다.

아직 구현하지 않은 범위:

- 레이드 상세의 일반 멤버 `내 캐릭터 완료` 버튼
- 기존 completed 방의 assignment 정리 및 데이터 이행

Task-079 E 당시 책임자 `파티 전체 완료`·반복 파티 제한적 전체 완료 취소·`partyOwner` Claim·assignment 정리까지 연결됐다. 이후 2026-09-19 결정으로 전체 완료 취소는 폐기 대상이 됐다. 아래 5.1의 전체 완료 UX는 유지하고 5.2는 별도 연결 단위다.

### 5.1 파티장·공대장 — 파티 전체 완료

레이드 상세에서 `파티 전체 완료`를 실행한다.

결과:

1. 파티 회차를 `completed`로 변경한다.
2. 완료 당시 membership Snapshot을 고정한다.
3. Snapshot 전원의 개인 주간 완료 Claim을 생성한다.
4. Snapshot 전원의 `activeRaidAssignment`를 삭제한다.
5. 완료 이벤트와 알림을 생성한다.
6. 전원의 내 계정 체크박스가 서버 동기화 후 체크된다.

일반 파티원은 파티 전체 완료 명령을 실행할 수 없다.

### 5.2 일반 파티원 — 내 캐릭터 완료

레이드 상세에서 `내 캐릭터 완료`를 실행한다.

결과:

1. 본인의 membership을 제거한다.
2. 본인의 `activeRaidAssignment`를 삭제한다.
3. 파티 인원·역할 수·빈 슬롯·revision을 갱신한다.
4. 같은 캐릭터·레이드·주차의 pending 신청을 종료한다.
5. 본인의 주간 완료 Claim을 생성한다.
6. 남은 파티원에게 `weeklyRaidCompleted` 사유의 탈퇴 이벤트를 생성한다.
7. 파티 회차는 계속 `active`다.

이 UX의 레이드 상세 버튼 연결은 후속 작업이다. Task-078에서는 같은 상태 전이를 내 계정 체크박스에서 실행하는 경로를 먼저 구현했다.

### 5.3 내 계정 — 수동 완료

LOSTPARTY 밖에서 레이드를 완료했거나 사용자가 직접 기록하려는 경우 캐릭터별 체크박스를 선택한다.

- 활성 파티와 pending 신청이 없으면 Claim만 생성한다.
- 동일 캐릭터·레이드의 활성 파티가 있으면 즉시 처리하지 않고 영향을 안내한다.
- 사용자가 `탈퇴하고 완료 처리`를 확인하면 개인 완료와 같은 Transaction을 실행한다.
- pending 신청만 있으면 철회 대상 수를 안내하고 확인 후 함께 종료한다.

### 5.4 파티장·공대장의 개인 완료

파티장·공대장은 레이드 상세의 완료 동작이 항상 `파티 전체 완료`다. 자기만 완료하려면 내 계정 체크박스를 사용한다.

내 계정에서 개인 완료할 때:

- 남은 멤버가 있으면 다음 책임자를 결정해 권한을 승계한 뒤 탈퇴·Claim 생성을 처리한다.
- 혼자라면 파티를 해산하고 Claim을 생성한다.
- 확인창에 승계 대상 또는 해산 결과를 명시한다.

## 6. 내 계정 체크박스

### 표시

- 캐릭터별 주간 레이드 목록에 체크박스를 제공한다.
- 서버 Claim을 구독 또는 동기화해 체크 상태를 표시한다.
- 오프라인 캐시는 사용할 수 있으나 서버 확인 전 명령 가능 여부를 확정하지 않는다.
- 파티 완료로 생성된 Claim과 수동 Claim은 같은 체크박스로 표시한다.

### 체크

```text
체크박스 선택
→ 서버 Claim·활성 점유·pending 신청 확인
→ 영향이 없으면 Claim 생성
→ 영향이 있으면 확인창
→ 확인 시 탈퇴/신청 종료/Claim 생성을 원자적으로 실행
```

확인 문구 기본안:

> 현재 `{캐릭터명}` 캐릭터로 `{파티명}`에 참가 중입니다. 이 레이드를 완료 처리하면 해당 파티에서 탈퇴하고, 같은 주차에는 동일 레이드 모집에 참가할 수 없습니다.

버튼:

- `취소`
- `탈퇴하고 완료 처리`

### 체크 해제

```text
체크박스 해제
→ 본인의 Claim 삭제
→ 남은 active 참가 근거가 없으면 동일 레이드 모집 생성·신청·가입 다시 허용
```

- 파티 공동 완료 Snapshot은 변경하지 않는다.
- 다른 파티원의 Claim을 변경하지 않는다.
- 이전 파티에 자동 재가입하지 않는다.
- 해산된 파티를 복구하지 않는다.
- 체크 해제 뒤 active 참가 근거가 남지 않으면 즉시 새 파티에 들어갈 수 있으므로 사용자의 명시적 확인을 받는다. active 참가 근거가 함께 남아 있으면 참가 상태를 유지하고 새 파티 진입은 계속 막는다.

## 7. 활성 파티와 pending 신청 처리

### 확정 참가 중 완료 체크

완료 Claim 생성 전에 현재 `activeRaidAssignment`와 membership을 확인한다.

- 일반 파티원: 탈퇴 후 Claim 생성
- 책임자: 승계 또는 단독 해산 후 Claim 생성
- 8인 풀방에서 한 명이 완료하면 기존 슬롯은 빈자리로 유지하며 다른 멤버를 당기지 않는다.
- 모집은 빈자리와 수동 모집 설정을 기준으로 다시 노출할 수 있다.

### pending 신청

- 같은 Character·raidId·cycleKey의 pending 신청은 Claim 생성과 함께 `superseded` 또는 완료 전용 종료 사유로 전환한다.
- 완료 Claim이 생긴 뒤 기존 pending이 승인될 수 없어야 한다.
- 승인 Transaction도 신청자 Claim을 다시 확인한다.
- 완료로 종료된 신청은 `status: superseded`, `resolutionReason: weeklyRaidCompleted`로 기록한다.
- 과거 `approved` application은 membership과 동일하지 않다. 현재 `memberPlayerIds`에 없으면 Claim 해제 후 같은 문서를 `pending`으로 갱신해 재신청할 수 있다.

### 이벤트

개인 완료로 파티에서 빠진 경우 남은 멤버에게 일반 탈퇴와 구분되는 이벤트를 보낸다.

```text
type: memberLeft
reason: weeklyRaidCompleted
```

UI 문구 기본안:

> `{캐릭터명}님이 레이드 완료 처리로 파티에서 탈퇴했습니다.`

## 8. 명령별 Claim 강제 검증

다음 명령은 대상 Character의 현재 `raidId + cycleKey` Claim이 없어야 한다.

| 명령 | 검증 시점 | 실패 결과 |
| --- | --- | --- |
| 모집 생성 | 생성 Transaction | `weeklyRaidAlreadyCompleted` |
| 가입 신청 | application 생성/재신청 Transaction | `weeklyRaidAlreadyCompleted` |
| 즉시 가입 | membership 생성 Transaction | `weeklyRaidAlreadyCompleted` |
| 신청 승인 | 승인 Transaction에서 재검증 | `weeklyRaidAlreadyCompleted` |
| 참가 캐릭터 변경 | 새 Character 점유 전 | `weeklyRaidAlreadyCompleted` |

후보 UI의 로컬 사전 필터는 안내용이다. 최종 거절은 Firestore Transaction과 Security Rules가 담당한다.

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

## 10. 파티 완료 확정과 해산

### 파티 전체 완료 취소 폐기

- 2026-09-19 제품 결정으로 반복방을 포함한 파티 전체 완료 취소 기능을 제공하지 않는다.
- 파티 전체 완료는 이번 주차의 확정 기록이며 방 전체를 이전 참가 상태로 복원하지 않는다.
- 잘못된 완료 표시는 각 사용자가 내 계정에서 자기 체크만 해제해 정정한다. 이 동작은 다른 파티원의 완료, 공동 Snapshot, membership 또는 과거 방을 변경하지 않는다.
- `다음 주도 함께하기` 방은 완료 당시 구성을 보존하고 수요일 06시 새 주차 전환에서 새 `active` 상태를 구성한다. 현재 주차를 되돌렸다가 다시 완료하는 중간 상태를 만들지 않는다.
- 기존 `cancelCompletion` 명령·버튼·Rules 허용 분기는 제거 대상이다. 과거 `completionCancelled` 이벤트와 로컬 히스토리는 데이터 표시 호환을 위해 읽기만 유지한다.

### 해산

- 해산은 membership과 active assignment를 제거한다.
- 해산은 개인 주간 완료 Claim을 삭제하지 않는다.
- 해산된 파티는 복구하지 않는다.
- 사용자는 체크박스 해제로 자기 Claim만 제거할 수 있다.
- 같은 조건 재사용이 필요하면 새 `recruitmentId`로 모집을 만든다.

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

## 12. 현재 구현과 남은 간격

1. Drift `raidHistoryEntries.localStatusOverride`는 표시 정정일 뿐 모집 제한의 서버 근거가 아니다.
2. 기존 완료 이벤트는 개인 Claim과 별도 이력이므로 삭제하거나 Claim으로 직접 재사용하면 안 된다.
3. 레이드 상세 일반 멤버 `내 캐릭터 완료` 버튼은 아직 연결하지 않았다.
4. Task-080 F: 로컬 `WeeklyRaidClear`는 모집 게이트에서 **폐기**한다. 서버 Claim만 완료 근거다.
5. Task-080 F: E 이전 completed·해산 대기 방에 남은 `activeRaidAssignment`는 Claim으로 변환하지 않는다. 해당 모집이 `completed`/`disbanded`(또는 `currentCycleStatus == completed`)이고 assignment의 `recruitmentId`·`raidId`가 일치하면 **본인 점유만** 삭제한다.

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

## 14. UX 요약

| 위치 | 사용자 | 동작 | 결과 |
| --- | --- | --- | --- |
| 레이드 상세 | 파티장·공대장 | `파티 전체 완료` | 회차 완료 + 완료 당시 전원 Claim |
| 레이드 상세 | 일반 파티원 | `내 캐릭터 완료` | 본인 탈퇴 + 본인 Claim, 회차 active 유지 |
| 내 계정 | 본인 | 체크박스 선택 | 필요 시 탈퇴·신청 종료 후 본인 Claim |
| 내 계정 | 본인 | 체크박스 해제 | 본인 Claim 삭제, 이전 파티 자동 복귀 없음 |

## 15. 구현 전 추가 확인 항목

1. 내 계정에서 캐릭터별로 표시할 기본 레이드 개수와 정렬은 기존 0~5개·기본 3개 정책을 유지한다. Task-081에서 캐릭터별 선택·원정대 일괄 개수·로컬 Drift 저장을 구현했다. 접기 UI는 쓰지 않으며 선택 개수만큼 항상 표시한다. 기본 표시 순서는 입장 레벨 내림차순이다.
2. 파티장·공대장 구분이 현재 `leaderPlayerId` 하나뿐인 구조에서 동일 명령으로 충분한지
3. Claim 문서 ID escape/hash 규칙
4. 파티 전체 완료·취소 Transaction의 Rules 접근 수 — Task-079에서 membership 공유 검증으로 약 12회(한도 20)로 확정
5. ~~기존 수동 로컬 `WeeklyRaidClear` 데이터를 서버로 이행할지 폐기할지~~ → **폐기(Claim-only)**. Task-080 F
6. ~~기존 completed 방의 active assignment를 언제 안전하게 정리할지~~ → **본인 점유 self-heal**(모집 completed/disbanded 또는 cycle completed, recruitmentId·raidId 일치). Claim으로 변환하지 않음. Task-080 F
7. 개인 완료 후 남은 파티의 모집 자동 노출 조건
8. Claim 체크 해제 확인 문구와 오작동 방지 UX

