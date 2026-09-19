# 파티·그룹 명령 확장성 재설계

## 1. 상태와 목적

- 2026-09-14 사용자 결정으로 기존 `release/1.0.0` 후보는 폐기한다. 브랜치는 비교·이력용으로만 보존하고 출시·`main` 병합 기준으로 사용하지 않는다.
- 다인 모집 해산이 최신 앱과 운영 Rules에서도 `permission-denied`로 실패했다. 해산 버튼을 숨기는 임시 UI 변경은 철회하고 기존 UI를 유지한다.
- 문제는 해산 한 건에 한정하지 않는다. 현재 일부 파티 명령은 인원수 `N`에 비례해 membership·Claim·assignment·slot·개인 event를 같은 Transaction에서 읽고 쓴다. Firestore Rules의 다중 문서 원자 작업 접근 호출 한도와 결합하면 4인·8인에서만 실패할 수 있다.
- 목표는 UI·제품 정책을 버리는 전면 재개발이 아니라 Firestore 명령 Repository, Rules, 이벤트와 Projection 책임을 인원수와 무관한 경계로 재설계하는 것이다.

### 1.1 확정된 제품·운영 결정

2026-09-14 사용자 승인으로 다음 사항은 더 이상 미정 항목이 아니다.

1. 계정·게임 계정·캐릭터 인증 자료는 보존한다. 새 스키마를 적용할 때 기존 파티·그룹·신청·회차·이벤트 테스트 자료는 초기화하며, 구 구조와 신 구조를 동시에 읽거나 쓰는 호환 계층은 만들지 않는다.
2. 해산 시 pending 신청자별 서버 이벤트를 만들지 않는다. 신청 목록은 참조하는 모집 원본이 종료 상태이면 해당 신청을 즉시 숨기고, 앱은 기기에서 한 번만 로컬 안내를 표시한다.
3. 종료된 모집의 `members`, `slots`, `applications`, 과거 회차 문서는 첫 출시에서 자동 삭제하지 않는다. 이 자료는 활성 판정에서 완전히 제외하고, 저장공간 문제가 실제로 확인될 때 운영자 정리 도구를 별도 설계한다.
4. 완료·주차 전환·해산은 온라인에서만 실행하는 단일 원자 명령이다. 오프라인 큐를 사용하지 않으며, 실패하면 서버 변경이 없고 앱 재실행·화면 재진입 시 서버 원본으로 결과를 다시 판정한다. 2026-09-19 결정으로 파티 전체 완료 취소 명령은 폐기한다.

위 결정에 따라 단계형 후처리, 구·신 스키마 dual-read, 자동 청소를 핵심 명령의 완료 조건으로 두지 않는다.

## 2. 현재 구조 위험 목록

| 영역 | 현재 증가 요인 | 영향 |
| --- | --- | --- |
| 파티 전체 완료 | 전원 membership·주간 Claim·assignment 조회, 전원 Claim·개인 event 생성, assignment 삭제 | 4·8인에서 Transaction·Rules 한도, 일부 완료·점유 잔존 위험 |
| 완료 취소(폐기 대상) | 완료 Snapshot 전원 membership·Claim·assignment 조회, Claim 삭제·assignment 복원·개인 event 생성 | 복구 복잡도와 상태 충돌 때문에 제품 기능에서 제거 |
| 다음 주차 전환 | 전원 membership·assignment 조회와 재생성·갱신, 미완료 개인 event 생성 | 반복방이 새 주차로 넘어가지 못하거나 일부 점유가 이전 주차에 남을 위험 |
| 모집 해산 | 전원 membership·assignment·slot 삭제, 신청 전체 확인, 멤버·대기자 개인 event 생성 | 현재 재현된 다인 `permission-denied`, 고아 관계 위험 |
| 자리 이동·교환 | 전원 membership 재조회·구성 계산, 이동 1건당 전원 개인 event 생성; 교환은 두 사건 fan-out | 8인에서 자리 이동만 실패하거나 중복 이벤트가 급증할 위험 |
| 참가 Character 변경 | 자리 결정을 위해 전원 membership 재조회, 변경 사건을 전원 개인 event로 복제 | 인원수에 따른 실패, 자리·직업 구성 Snapshot 불일치 위험 |
| 즉시 가입 | 기존 전원 membership 재조회, 기존 전원에게 `memberJoined` 개인 event 생성 | 방이 찰수록 가입 실패 가능성 증가 |
| 신청 승인 | 자리 결정을 위해 기존 전원 membership 재조회 | 승인 경쟁·8인 근접 상태에서 지연 및 충돌 증가 |
| 탈퇴·추방 | 핵심 변경은 대상 중심이나 전원 개인 event 생성, 파티장 탈퇴 시 후임 membership 추가 갱신 | 인원이 많을 때 정상 탈퇴·승계까지 알림 때문에 실패할 위험 |
| 그룹 전용 전환 | 확정 멤버와 pending 신청자별 그룹 membership 조회 | 인원·신청 증가 시 전환 실패, 조회 시점과 Transaction 상태 불일치 위험 |
| 그룹 해산 사전 검사 | `raidListings` 최대 20개를 순회해 recruitment를 개별 조회 | 20개 이후 활성 모집 누락, 느린 해산 판정 위험 |
| 목록·알림 읽기 | 가입 그룹별 listing 구독, Player별 복제 event 조회 | 그룹 수·이벤트 수 증가에 따른 구독·읽기 비용과 중복 동기화 |

그룹 생성·초대·가입 신청·거절·일반 탈퇴·그룹장 이전처럼 정해진 소수 문서만 다루는 명령은 우선 보존한다. 표시를 위해 전체 멤버 목록을 한 번 읽는 행위 자체는 정상이며, **하나의 상태 변경을 위해 전원을 Transaction에서 재조회하거나 전원별 쓰기를 만드는 구간**과 구분한다.

### 2.1 현재 접근량 감사 결과

아래 수치는 Repository가 한 명령에서 직접 수행하는 문서 접근을 기준으로 한다. `N`은 확정 멤버 수, `A`는 pending 신청 수다. Rules 내부 `get/exists/getAfter`는 검증 함수의 분기와 캐시 여부에 따라 달라질 수 있으므로 이 표에 더해지며, 현재 구조를 그대로 최적화하는 근거로 사용하지 않는다.

| 명령 | 현재 Transaction 읽기 | 현재 쓰기 | 증가 분류 | 판정 |
| --- | ---: | ---: | --- | --- |
| 공개 파티 생성 | 기본 5, stale 점유 시 +1 | 기본 4, stale 정리 시 +1 | 고정 | 구조 교체 시 `raidState`로 단순화 |
| 그룹 파티 생성 | 공개 생성 + 그룹·membership 2 | 공개 생성 + listing 1 | 고정 | 보존 가능 |
| 가입 신청·철회 | 각각 약 5 / 3 | 각각 2 | 고정 | 개인 이벤트를 공용 이벤트로 교체 |
| 즉시 가입·승인 | 고정 검증 + 전원 membership 재조회 `N` | 모집·대상 membership·slot·점유·신청 및 기존 멤버 이벤트 | `N` 비례 | Aggregate 기반으로 교체 |
| 캐릭터 변경 | 기본 5~6 + 자리 판정용 전원 조회 | 대상 membership·slot·점유 1~2·모집·전원 이벤트 | `N` 비례 | 대상 중심 명령으로 교체 |
| 자리 이동·교환 | 모집 + 전원 membership `N` | 모집·대상 membership 1~2·slot 2 + 전원 이벤트 | `N` 비례 | 고정 8칸 요약 사용 |
| 탈퇴·추방·승계 | 모집·대상·필요 후임·점유·slot | 모집·대상 삭제·필요 후임 갱신 + 전원 이벤트 | 이벤트가 `N` 비례 | 핵심 상태는 고정 크기, 이벤트 1건 |
| 전체 완료 | 고정 3 + `3N` | 모집·cycle 2 + Claim 최대 `N` + assignment 최대 `N` + event `N` + listing 최대 1 | `N` 비례 | 통합 `raidState` 원자 전환 |
| 완료 취소(폐기 대상) | 고정 3 + `3N` | 모집·cycle 2 + Claim 삭제 `N` + assignment 생성 `N` + event `N` + listing 최대 1 | `N` 비례 | 신규 구조에 이식하지 않고 제거 |
| 다음 주차 전환 | 고정 3 + `2N` | 모집·cycle 최대 2 + assignment 최대 `N` + event 최대 `N` + listing 최대 1 | `N` 비례 | 통합 `raidState` 원자 전환 |
| 활성 모집 해산 | 고정 2 + member `N` + application `A` + assignment `N` + slot `N` | 모집 1 + member/assignment/slot 삭제 최대 `3N` + member/application event `N+A` + listing 최대 1 | `N+A` 비례 | 현재 재현 실패, 전면 교체 |
| 공개→그룹 전환 | 모집·책임자 + member `N` + pending `A`, 신청 조회는 현재 최대 20 | 모집·listing | `N+A`, 20건 절단 | 자격 불일치 집계 사용 |
| 그룹 해산 사전검사 | listing 최대 20 + 연결 recruitment 최대 20 | 해산 자체는 고정 소수 | 연결 수 비례, 20건 절단 | 그룹 원본 활성 모집 수 사용 |

현재 Rules에는 `activeRaidAssignments`, `weeklyRaidClaims`, Player별 `events`, 모집의 `members/slots/applications/cycles` 각각에 별도 검증 함수가 연결돼 있다. 따라서 클라이언트 접근량만 줄이고 기존 Rules 검증 그래프를 유지해서는 8인 안전성을 증명할 수 없다.

## 3. 공통 개선 묶음

### A. 공용 이벤트 원본

- 한 사건은 파티 또는 그룹 공용 이벤트 문서 **한 건**으로 저장한다.
- `audiencePlayerIds`, `actorPlayerId`, `targetPlayerId`, `revision`, `occurredAt`으로 읽기 권한과 수신 대상을 표현한다.
- 수신 목록은 `audiencePlayerIds array-contains 현재 Player ID` 조건으로 조회하고, Rules도 같은 audience 포함 여부를 읽기 조건으로 사용한다. 쿼리와 Rules가 서로 다른 조건을 요구해 목록 전체가 거부되는 회귀를 막는다.
- Player별 문서 복제를 핵심 Transaction에서 제거한다. 개인 읽음 상태가 필요하면 이벤트 원본과 분리한 Player별 cursor/receipt로 관리한다.
- 탈퇴·추방·해산 후에도 기존 수신자가 이력을 읽을 수 있도록 이벤트 당시 audience를 권한 기준으로 사용한다.

### B. 모집 Aggregate와 구성 요약

- `recruitments/{id}`를 명령 충돌의 기준으로 유지하고 모든 변경은 `expectedRevision`을 비교한다.
- 현재 자리·역할·구성 직업을 결정적으로 표현하는 고정 최대 8칸 구성 요약을 모집 원본에 둔다.
- 가입·승인·Character 변경·자리 이동은 로컬에서 결과를 계산하되, Rules는 revision과 변경 전후 구성 요약 및 직접 대상 문서만 검증한다.
- 명령마다 전체 membership을 Transaction에서 다시 읽어 같은 구성을 재조립하지 않는다.

모집 원본의 새 요약은 최소 다음 정보를 가진다.

```text
memberCount
dealerCount
supporterCount
leaderPlayerId
partySlots[8]                // playerId, characterId, role, classKey, partyIndex, slotIndex, countedAsNonGroupMember
nonGroupMemberCount
pendingApplicationCount
pendingNonGroupApplicantCount
currentCycleKey
currentCycleStatus
completedAt?
completionRevision?
revision
```

- `partySlots`는 화면 전체 상세의 영구 대체물이 아니라 명령 판정용 고정 상한 Aggregate다. 상세 화면은 필요하면 `members`를 계속 읽는다.
- 새 명령에서 별도 `slots` 문서를 점유 원장으로 쓰지 않는다. `partySlots`가 유일한 활성 자리 원장이고 membership의 자리 필드는 화면용 Projection이다.
- 각 파티의 동일 구성 직업 제한과 딜러/서포터형 분리는 기존 `PartyCompositionPolicy`가 계산한 `classKey`를 사용한다.
- `countedAsNonGroupMember`는 현재 그룹 조회 결과가 아니라 참가 당시 `nonGroupMemberCount`에 포함했는지를 기록한다. 이후 그룹을 탈퇴한 멤버를 제거해도 과거 집계를 이중 감소시키지 않는다.
- 신청 문서도 `countedAsNonGroupApplicant`를 신청 당시 저장하고 철회·승인에서 그 값을 사용한다. 명령 시점의 새 그룹 조회 결과로 과거 pending 집계를 되돌리지 않는다.
- 가입·승인·탈퇴·추방·캐릭터 변경·자리 이동이 요약과 직접 대상 Projection을 같은 Transaction에서 함께 갱신한다.
- 공개→그룹 전환은 `nonGroupMemberCount == 0 && pendingNonGroupApplicantCount == 0`일 때만 허용한다.
- 그룹 원본에는 `activeRecruitmentCount`를 두고 그룹 모집 생성 시 증가, 종료·공개 전환 시 감소시킨다. 그룹 해산은 이 값이 0인지 검증한다.
- 집계가 음수이거나 `memberCount`와 채워진 슬롯 수가 다르면 명령을 거절하고 운영·개발 오류로 기록한다. 전체 하위 문서 순회로 즉석 복구하지 않는다.

### C. 최대 8인 제한 원자 명령

- Cloud Functions가 없는 Spark 환경에서 원래 명령자 재접속에 의존하는 `processing → 후속 단계 → complete` 방식은 사용하지 않는다.
- 완료·취소·주차 전환·해산의 **정확성에 필요한 상태**를 현재 제품 상한인 8명 안에서 한 Firestore Transaction으로 확정한다. Transaction은 전부 성공하거나 전부 실패하므로 앱 종료 뒤 이어서 실행할 핵심 정리가 없어야 한다.
- 기존 `activeRaidAssignment`와 `weeklyRaidClaim`은 Character·레이드별 통합 `raidState`로 교체하는 방향을 기준으로 한다. `active`, `completed`, 문서 없음으로 참가 점유와 이번 주 완료를 한 문서에서 표현한다.
- 모집 원본에는 `revision`, `lastCommandId`, 명령 종류·행위자·대상 `raidState` ID를 담은 제한 크기 명령 검증 정보를 둔다. Rules는 전원 membership을 다시 조립하지 않고 Transaction 후 모집 원본과 직접 대상 문서만 검증한다.
- 완료·취소·주차 전환은 현재 회차 상태를 포함한 모집 원본·최대 8개 `raidState`·필요 listing·공용 이벤트 1건을 같은 원자 명령으로 처리한다. 활성 모집 해산은 최대 8개 `raidState` 점유를 해제하고, 완료 후 해산은 `completed` 상태를 보존한다.
- 그룹 전용 1회성 모집은 완료 순간 그룹 `activeRecruitmentCount`를 감소시키고 listing을 삭제한다. 이후 완료 화면의 마무리 해산은 이미 닫힌 그룹 집계와 listing을 다시 변경하지 않는다. 반복 모집의 이번 회차 완료는 모집이 계속 활성 상태이므로 집계를 유지한다.
- 새 명령은 별도 `cycles` 문서를 현재 상태의 권한 원장으로 쓰지 않는다. `currentCycleKey`, `currentCycleStatus`, 완료 시각·revision·완료 구성은 모집 원본에 고정하고, 과거 회차 표시는 공용 이벤트 Snapshot과 로컬 이력 Projection에서 만든다.
- 8인 최악 조건에서도 Rules 문서 접근 호출이 Transaction 전체 20회, 개별 쓰기 10회를 넘지 않는다는 Emulator 계약 테스트를 구현 전에 먼저 고정한다. 같은 경로가 캐시될 것이라고 가정해 한도를 계산하지 않는다.

#### 통합 `raidState` 계약

경로는 `players/{playerId}/raidStates/{characterId}_{raidId}`로 고정한다. 문서 부재는 해당 캐릭터·레이드에 활성 참가와 이번 주 완료가 모두 없다는 뜻이다.

필수 필드는 다음과 같다.

```text
schemaVersion
playerId
characterId
raidId
difficultyId          // 표시·이력용, 귀속 키에는 미포함
cycleKey
status                // active | completed
recruitmentId?        // 파티에서 생성된 상태일 때
source                 // party | manual
revision
updatedAt
```

- 동일 `characterId + raidId + cycleKey`에서 `active`와 `completed`는 한 문서 안에서 상호 배타적이다.
- 다른 난이도는 기존 정책대로 같은 `raidId` 귀속을 공유한다.
- 파티 완료는 `active → completed`, 다음 주차 전환은 새 `cycleKey`의 `active`, 활성 해산·탈퇴는 문서 삭제다. 동일 주차의 공동 `completed → active` 전이는 제공하지 않는다.
- 완료 후 해산은 `completed` 문서를 보존한다. 수동 체크는 `source: manual`, 파티 완료는 `source: party`로 구분하되 화면 체크와 참가 차단은 같은 상태를 읽는다.
- 별도 `activeRaidAssignments`와 `weeklyRaidClaims`를 신규 명령에서 함께 유지하지 않는다.

#### 명령 검증 봉투

모집 원본은 다음의 제한된 크기 정보를 마지막 성공 명령의 증거로 가진다.

```text
revision
lastCommandId
lastCommandType
lastCommandActorPlayerId
lastCommandTargetIds   // 최대 8개의 결정적 raidState/member 식별자
lastCommandAt
```

- 클라이언트는 읽은 `revision`을 `expectedRevision`으로 명령 계획에 사용한다. Transaction 안에서 현재 값이 다르면 아무것도 쓰지 않고 새로고침 안내를 반환한다.
- `commandId`는 한 사용자 동작 동안 안정적이며 응답 유실 후 재조회에서 성공 여부를 판정하는 키다.
- Rules는 모집 원본의 전후 상태와 각 직접 대상 문서의 `getAfter`를 검증한다. 각 대상 Rules가 다시 전원 membership·slot·character 문서를 읽지 않도록 명령 종류별 허용 필드와 상태 전이를 좁힌다.
- `lastCommandTargetIds`는 자유로운 권한 위임 목록이 아니다. 명령 타입, 현재 구성 요약, actor 권한과 정확히 일치할 때만 허용한다.

#### 새 구조 목표 예산

| 명령 | 목표 쓰기 수 | Rules 접근 목표 | 비고 |
| --- | ---: | ---: | --- |
| 전체 완료·취소 | 모집 1 + raidState `N` + listing 최대 1 + event 1 = 최대 11 | 전체 20 이하, 각 쓰기 10 이하 | `N=8`, cycle 별도 쓰기 없음 |
| 다음 주차 전환 | 모집 1 + raidState `N` + listing 최대 1 + event 1 = 최대 11 | 동일 | 이전·새 주차 혼합 금지 |
| 활성 해산 | 모집 1 + raidState 삭제 `N` + group 집계 최대 1 + event 1 = 최대 11 | 동일 | listing·하위 문서 즉시 삭제 없음 |
| 완료 후 해산 | 모집 1 + group 집계 최대 1 + event 1 = 최대 3 | 고정 | completed raidState 보존, listing 즉시 삭제 없음 |

쓰기 수가 20 미만이라는 사실만으로 승인하지 않는다. 각 Rules 쓰기가 모집 원본 하나 외의 추가 문서를 몇 번 참조하는지 명령별 계약 테스트로 측정한 뒤 구현을 연결한다.

#### 8인 Rules 접근 예산 증명

완료·취소·전환의 그룹 전용 8인 최악 조건은 다음 최대치를 넘지 않도록 Rules를 구성한다.

| 검증 위치 | 접근 | 최대 호출 |
| --- | --- | ---: |
| 모집 원본 update | actor binding 1 + 명령 대상 raidState의 `getAfter/existsAfter` 8 | 9 |
| raidState 8개 write | 각 문서가 모집 원본 `getAfter` 1회 | 8 |
| 공용 event write | 모집 원본 `getAfter` 1회 | 1 |
| group listing write | 모집 원본 `getAfter` 1회 | 1 |
| 합계 | 캐시 제외 최악값 | **19** |

- 완료·취소·전환의 개별 쓰기는 모집 원본 update의 9회가 최대이므로 개별 10회 한도 안에 남는다.
- 각 raidState Rules에서 actor binding·character·membership을 다시 읽지 않는다. actor 권한과 대상은 모집 원본의 이전 8칸 요약 및 명령 봉투를 모집 update Rules가 검증한다.
- 모집 update Rules는 최대 8개 대상을 명시적으로 검사한다. Firestore Rules에 반복문이 없으므로 `targetCount`와 고정 `target0`~`target7` 슬롯 또는 동등한 제한 구조를 사용하며, 대상 중복·빈 대상·현재 구성 외 대상을 거절한다.
- raidState Rules는 자신의 `{playerId, stateId}`가 검증된 명령 대상 중 하나이고 요청 상태 전이가 `lastCommandType`과 맞는지만 확인한다. 이로써 추가 문서 쓰기를 막는다.
- 모집 원본은 모든 명령 대상의 `getAfter/existsAfter`를 확인해 일부 raidState가 빠진 채 모집만 완료되는 것을 막는다.
- 그룹 전용 활성 해산은 모집 update가 actor binding 1 + raidState 8 + group 원본 `getAfter` 1로 개별 10회, raidState 8개가 모집 원본을 각 1회, event가 모집 원본 1회, group update가 모집 원본 1회로 **전체 20회**다. 이 경로에서는 listing을 즉시 삭제하거나 다른 문서 접근을 추가하지 않는다.
- 예산이 정확히 20인 경로에 추가 검증이 필요하면 데이터 계약을 모집 원본 안에서 검증하거나 명령을 승인하지 않고 설계를 다시 연다.
- Emulator 테스트는 Rules 캐시가 호출 수를 줄여 줄 것이라는 가정 없이 위 경로의 성공과 대상 하나 누락·추가·변조 실패를 고정한다.

### D. 종료 상태와 비핵심 자료 분리

- `members`, `slots`, `applications`와 과거 회차 자료를 해산 Transaction에서 전부 삭제하지 않는다. 모집 원본의 `completed`·`disbanded` 상태를 활성 여부의 유일한 기준으로 삼는다.
- 종료된 모집의 하위 문서는 신규 신청·승인·자리 변경·점유 판정에 참여할 수 없도록 모든 Repository와 Rules가 부모 상태를 먼저 확인한다.
- 활성 목록은 모집 원본 상태로 제외한다. 참가 신청 목록처럼 부모 조건을 쿼리에 직접 결합할 수 없는 화면은 모집 원본을 확인해 종료 항목을 자동으로 숨기고, 본인 소유의 오래된 Projection만 재진입 시 조용히 정리할 수 있다.
- 지연 정리는 저장공간 관리와 화면 Projection 정돈을 위한 비핵심 작업이다. 실패하거나 아무도 다시 접속하지 않아도 참가·완료·해산의 정확성과 사용자 행동을 막지 않아야 한다.
- 해산 시 pending 신청자 수만큼 쓰기나 이벤트를 복제하지 않는다. 신청자는 자신이 이미 알고 있는 모집 원본의 종료 상태로 결과를 확인하고 앱이 로컬 안내를 구성한다.
- 그룹 listing도 해산·그룹→공개 전환의 핵심 Transaction에서 즉시 삭제하지 않는다. listing 소비 화면이 모집 원본 상태·visibility·revision을 확인해 숨기며, 오래된 listing은 비핵심 운영 정리 대상이다.

pending 신청자의 로컬 안내 키는 `recruitmentId + terminalRevision + terminalStatus`로 고정한다. 같은 기기에서는 이 키를 receipt로 저장해 한 번만 표시하고, 재설치·다른 기기에서 다시 보이는 것은 초기 제품 범위에서 허용한다. 안내 표시 실패나 receipt 저장 실패는 해산 결과에 영향을 주지 않는다.

### E. 집계값으로 연결 순회 제거

- 공개→그룹 전용 전환은 전원 조회 대신 모집 Aggregate의 그룹 자격 불일치 수·pending 불일치 수를 사용한다.
- 그룹 해산은 그룹 원본의 활성 그룹 모집 수 또는 동등한 Projection을 기준으로 판정한다.
- 집계값 변경은 해당 가입·탈퇴·신청·공개범위 명령과 함께 revision으로 보호한다.

### F. 공용 이벤트 저장 계약

파티 이벤트는 `partyEvents/{eventId}`, 그룹 이벤트는 `groupEvents/{eventId}`에 사건당 한 건을 둔다. 이벤트는 핵심 상태의 결과이지 권한이나 상태 전이의 원인이 아니다.

```text
schemaVersion
eventId
scopeType                 // party | group
scopeId                   // recruitmentId | groupId
type
commandId
commandRevision
actorPlayerId
targetPlayerId?
audiencePlayerIds         // 파티 최대 8명, 그룹은 해당 명령의 제한된 대상만
snapshot                  // UI 문구에 필요한 허용 필드만
occurredAt
```

- 읽기는 `audiencePlayerIds array-contains currentPlayerId` 쿼리와 같은 조건의 Rules를 사용한다.
- 읽음 여부는 로컬 receipt/cursor로 두며 공용 이벤트를 수정하지 않는다.
- 핵심 명령의 이벤트 쓰기가 실패하면 같은 Transaction 전체가 실패한다. 단, pending 신청자 로컬 파생 안내와 비핵심 청소는 이벤트 audience에 포함하지 않는다.
- 첫 출시에서 서버 TTL·자동 삭제를 사용하지 않는다. 조회는 cursor와 작은 limit으로 제한한다.

## 4. 기능별 개선안

| 기능 묶음 | 개선안 |
| --- | --- |
| 즉시 가입·승인 | 모집 구성 요약에서 빈자리와 직업 중복을 판정하고 대상 membership·slot·assignment만 쓴다. 가입 사건은 공용 이벤트 1건으로 기록한다. |
| Character 변경·자리 이동·교환 | 구성 요약의 대상 1~2칸만 revision과 함께 변경한다. membership·slot도 대상 1~2명만 갱신하고 공용 이벤트는 실제 사건 수만큼 1~2건 기록한다. |
| 탈퇴·추방·파티장 승계 | 대상과 필요 시 후임 한 명만 변경한다. 구성 요약에서 후임을 결정하고 공용 이벤트 1건을 남긴다. 그룹 listing을 포함해 일반 제거 최대 5건, 파티장 승계 최대 6건의 쓰기로 제한하며 기존 파티장 개인 탈퇴·자동 승계 제품 정책을 유지한다. |
| 전체 완료 | 모집 원본의 회차 상태와 최대 8개 `raidState`를 한 Transaction에서 `completed`로 확정한다. 기존 assignment 삭제와 Claim 생성을 두 종류 문서로 나누지 않는다. |
| 완료 취소 | 제품 기능에서 제거한다. 기존 명령·UI·Rules create/update 허용은 폐쇄하고 과거 이벤트 읽기 호환만 유지한다. |
| 다음 주차 전환 | 모집 원본과 최대 8개 `raidState`의 `cycleKey`·상태를 한 Transaction으로 전환한다. 이전·새 주차 혼합 상태를 만들지 않는다. |
| 모집 해산 | 모집 원본을 `disbanded`로 확정하고 활성 `raidState`만 최대 8건 해제한다. membership·slot·application·group listing은 즉시 삭제하지 않으며 부모 종료 상태로 기능에서 제외한다. 완료 후 마무리 해산은 `completed` `raidState`를 보존한다. |
| 그룹 전용 전환 | 그룹 자격 집계값이 0일 때만 전환하고 listing은 모집 원본의 동일 revision Projection으로 갱신한다. |
| 그룹 해산 | 활성 모집 집계가 0이고 pending 관계·초대코드 조건을 만족할 때만 종료한다. 연결 모집 최대 20개 순회를 제거한다. |
| 목록·알림 | 그룹별 개별 구독과 Player별 이벤트 복제를 공통 조회 가능한 Projection·공용 이벤트와 cursor로 대체한다. 화면용 전체 멤버 조회는 유지한다. |

## 5. 예상 버그와 필수 보완

### 동시성·중복

- 오래된 revision으로 성공하거나 서로 다른 두 명이 같은 슬롯을 차지하는 문제
- 앱 재시도에서 동일 이벤트·Claim·assignment가 중복 생성되는 문제
- 대응: 모든 명령에 `expectedRevision`, 전환 명령에 안정적인 `commandId`, 문서 ID의 결정성, 동일 명령 재실행 결과 고정

### 앱 종료·응답 유실

- Transaction 제출 전 앱 종료: 서버 변경 없음
- Transaction 커밋 후 응답 수신 전 앱 종료: 서버는 이미 전체 상태를 확정했지만 클라이언트가 성공을 기억하지 못하는 상태
- 대응: 다음 실행에서 모집 `status`, `revision`, `lastCommandId`를 읽어 결과를 자동 판정한다. 장기 `processing`, 수동 복구 버튼과 다른 참가자의 재접속을 완료 조건으로 두지 않는다.
- 핵심 명령은 오프라인 큐에 맡기지 않는다. 온라인 Transaction 실패 시 서버는 변경되지 않았음을 안내하고 현재 Snapshot을 다시 읽는다.

### 잔존 하위 문서

- 종료된 모집의 과거 membership·slot·application이 직접 조회되어 유령 참가·신청으로 보이는 문제
- 오래된 application 수만큼 해산 후처리를 다시 만들어 명령 크기가 증가하는 문제
- 대응: 모집 원본 상태 우선의 읽기 모델과 Rules, 종료 항목 자동 숨김, 본인 Projection 지연 정리. 잔존 문서는 점유·완료 판정의 근거로 사용하지 않는다.
- 첫 출시에서는 자동 삭제를 실행하지 않는다. 운영자 정리 도구는 저장량 문제가 확인된 뒤 별도 승인 작업으로 둔다.

### 완료·주간 Claim

- 완료 직후 다른 방 참가 허용, 취소 중 이중 점유, 다음 주차 assignment 혼합
- 대응: 별도 Claim·assignment를 통합 `raidState`로 바꾸고 상태 전이를 같은 원자 명령과 계약 테스트로 고정

### 이벤트·알림

- 탈퇴·해산 뒤 수신자가 이벤트를 못 읽거나 반대로 비수신자가 읽는 문제
- 읽음 처리 cursor가 새 이벤트를 건너뛰는 문제
- 기존 Player event와 신규 공용 event가 중복 노출되는 문제
- 대응: 이벤트 당시 audience 기반 Rules, `(occurredAt, eventId)` 정렬 cursor, 구 이벤트 테스트 데이터 초기화, 중복 제거 키. 해산 pending 신청자는 공용 이벤트 audience에 넣지 않고 모집 원본 종료를 확인한 로컬 1회 안내로 처리한다.

### 구성·자리

- 모집 Aggregate 구성 요약과 membership·slot Projection 불일치
- 딜러/서포터형 동일 직업 구분, 파티별 동일 구성 직업 제한, 빈자리·교환 판정 회귀
- 대응: 기존 `PartyCompositionPolicy`를 단일 계산기로 유지하고 Write Plan·Rules·읽기 Projection이 같은 결과를 계약 테스트로 공유

### 그룹 연결

- 그룹 탈퇴 후 그룹 전용 모집 자격 집계가 줄지 않거나 전체 공개 모집까지 잘못 차단하는 문제
- listing과 recruitment revision이 달라 그룹 목록이 오래된 상태로 보이는 문제
- 대응: 그룹 자격 변화 명령별 집계 갱신표, listing 원본 revision 일치, 공개/그룹 경계 회귀 테스트

### 과거 데이터·릴리즈 폐기

- 공개 출시본은 없으므로 사용자 데이터 마이그레이션을 기본 전제로 삼지 않는다.
- 계정·게임 계정·캐릭터 인증 자료는 보존하고, 기존 파티·그룹·신청·회차·이벤트 테스트 자료는 새 스키마 전환 시 초기화한다. 구·신 스키마 동시 호환은 하지 않는다.
- `release/1.0.0` 브랜치는 삭제하지 않지만 출시 후보·병합 기준에서 제외한다.

## 6. 작업 순서

1. 모든 파티·그룹 명령의 현재 읽기·쓰기·Rules 접근을 표로 고정하고 1·2·4·8인 예상량을 기록한다.
2. `raidState` 통합 계약과 완료·취소·주차 전환·해산의 8인 최악 Transaction 쓰기·Rules 접근량을 먼저 설계한다.
3. 모집 Aggregate 구성 요약, revision·`lastCommandId`와 제한 크기 명령 검증 계약을 설계한다.
4. 공용 이벤트 원본·audience·읽음 cursor 계약을 설계하고 기존 개인 event 의존 화면을 목록화한다.
5. 종료된 모집의 membership·slot·application을 읽는 모든 화면·명령을 조사하고 부모 상태 우선 및 지연 정리 계약을 확정한다.
6. 가입·승인 → Character 변경·자리 이동 → 탈퇴·승계 순으로 고정 크기 명령으로 전환한다.
7. 완료·취소·주차 전환·해산을 제한된 원자 명령으로 전환한다.
8. 그룹 자격·활성 모집 집계를 도입해 전원·연결 모집 순회를 제거한다.
9. Rules를 기능 단위로 축소하고 각 단계마다 이전 정상 흐름을 회귀 검증한다.
10. 자동 Emulator에서 1·2·4·8인, 공개·그룹, 정상·충돌·앱 종료 후 재조회·재시도를 검증한 뒤 새 릴리즈 후보를 만든다.

### 구현 브랜치와 전환 단위

설계 문서를 먼저 `dev`에 반영한 뒤 최신 `dev`에서 `feature/party-group-command-redesign` 하나를 만든다. 구·신 스키마를 동시에 운영하지 않으므로 `raidState` 읽기만 먼저 바꾸거나 일부 명령만 새 스키마로 바꾼 상태를 `dev`에 병합하지 않는다.

기능 브랜치 안에서는 다음 순서로 의미별 복구 커밋을 남긴다.

1. 8인 완료·취소·전환·그룹 해산의 Rules 접근 예산을 증명하는 계약 테스트와 비연결 새 schema/Domain
2. 모집 Aggregate·공용 이벤트·통합 `raidState` Write Plan과 Repository 구현(아직 운영 Router/DI 미전환)
3. 생성·신청·가입·승인, 캐릭터 변경·자리 이동·탈퇴·추방·승계 전환
4. 완료·취소·주차 전환·해산과 그룹 활성 모집 집계 전환
5. 모든 읽기 경로, 종료 Projection 숨김, 로컬 1회 안내를 새 구조로 일괄 연결
6. 구 파티·그룹 테스트 자료 초기화 절차 검증, 전체 회귀와 실기기 전환 확인

첫 Rules 예산 증명이 실패하면 앱 연결을 시작하지 않고 설계를 다시 연다. 전체 Router/DI·Rules·읽기/쓰기 전환과 테스트 데이터 초기화 절차가 함께 검증된 뒤에만 기능 브랜치를 `dev`에 병합한다. `main`과 새 release 브랜치는 그 이후 안정화 판정 때만 움직인다.

### 자동·실기기 검증 경계

- 자동: 각 명령의 성공·권한 거절·오래된 revision·중복 commandId·1/2/4/8인 Rules 접근 한도, 동일 슬롯 경쟁, 동일 raidState 충돌, 앱 응답 유실 후 재조회 결과를 검증한다.
- 자동: 종료 모집의 stale member/slot/application이 목록·승인·가입·완료 판정에 사용되지 않음을 검증한다.
- 실기기: 3개 이하 계정으로 공개/그룹 방 생성, 신청·승인·즉시 가입, 자리 교환, 파티장 탈퇴·승계, 완료·취소·주차 전환·해산, 재실행 후 상태를 확인한다.
- 회귀: 그룹 생성·탈퇴·그룹장 이전·마지막 1인 해산, 캐릭터 인증·활동 캐릭터 저장, 보석·아크그리드 오류 Snapshot 표시를 보존한다.

## 7. 완료 조건

- 일반 명령은 직접 대상 수만큼만 접근하고, 전체 명령은 현재 최대 8인 경계 안에서 단일 Transaction으로 끝난다.
- 8인 전체 완료·취소·주차 전환·활성 해산이 Rules 전체 20회·개별 쓰기 10회 접근 한도를 캐시 가정 없이 통과한다.
- 파티 1·2·4·8인 자동 테스트가 모두 존재하고 같은 결과를 보장한다.
- 앱 종료 시 핵심 상태는 전부 반영 또는 전부 미반영이며, 재실행 후 `lastCommandId`로 결과를 자동 복구한다.
- 종료 후 남은 하위 문서가 활성 목록·신청·점유·주간 완료 판정에 영향을 주지 않는다.
- 생성·신청·승인·즉시 가입·탈퇴·추방·승계·Character 변경·자리 이동·완료·취소·주차 전환·해산과 그룹 연결 흐름을 모두 회귀 확인한다.
- Rules 경고 0개, 전체 Rules 컴파일, 허가된 배포와 3개 이하 실기기의 대표 사용자 흐름을 통과한다.
- 이후에만 새 릴리즈 브랜치와 버전을 만든다.

## 8. 제외 범위

- UI 디자인 전면 개편
- Character Build·보석·아크그리드 판정 재작성
- 레이드·직업 카탈로그 변경
- 유료 서버·Cloud Functions 도입은 별도 사용자 결정 전까지 제외
