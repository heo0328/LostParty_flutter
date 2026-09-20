# NEXT WORK — 파티·그룹 명령 확장성 재설계 1단계

## 현재 상태

- 기존 `release/1.0.0` 후보는 폐기했다. 브랜치는 이력용으로 보존하되 출시·`main` 병합 기준으로 사용하지 않는다.
- R1~R7·C* 구현과 운영 Rules·Indexes 게시는 완료했다. 운영 Router는 원자 Repository·어댑터를 쓴다.
- 로컬에는 생성·읽기 v2·이전 Close/Open 가드·승인 패치·listing sync·Listen 가드·orphan 공개 전환·모집 삭제→disband·캐릭터 변경 atomic OR·그룹 전용방 파티장 탈퇴 차단 등이 **코드로 들어가 있다**.
- **실기기 판정(2026-09-16 사용자 확인):** 아래 성공 항목은 사용자가 디바이스에서 확인했다. 그 밖의 보고 실패는 로컬 수정·자동 테스트 통과만으로 완료로 쓰지 않는다.
- **2026-09-21 현재 작업:** F6-B2-R3·F6-D·F6-C·F6-E의 코드·표적 검증·사용자 확인을 마쳤다. **F7 최종 대조에서 새 기능 결함이나 추가 구현 대상은 발견되지 않았고, 이미 통과한 통합 테스트는 사용자 결정에 따라 반복하지 않았다.** 현재 기능 브랜치는 최신 `dev`에 통합할 준비 상태다. `main`·release 반영은 이후 별도 결정한다.

### 실기기 확인됨 (고쳐진 것)

1. 레이드 모집방 생성
2. 그룹 생성
3. 공개 목록·레이드 현황·상세에 schemaVersion 2 모집이 보임
4. 그룹 직접 초대·수락, 검색 가입 신청·수락, 일반 그룹원 탈퇴, 그룹장 이전·이전한 기존 그룹장 탈퇴, 마지막 1인 해산
5. 초대코드 가입(사용자가 Rules 별도 게시 후 확인)
6. 수정 빌드에서 가입 신청 승인(2026-09-17 사용자 실기기 확인). 즉시 가입·재진입 후 전체 상태 검증은 별개다.
7. `이슈아이`의 수동 완료 체크 가능(2026-09-18 사용자 확인). 동일 레이드의 접근 불가 신청·정상 pending 영향 안내·체크 해제 등은 별도 회귀 항목이다.

### 실기기 복구 현황 (남은 항목 우선)

우선순위는 재현 빈도와 차단 범위다. 한 번에 하나의 승인된 묶음만 고친다.

| ID | 증상 | 비고 / 로컬에 있는 후보 수정 |
| --- | --- | --- |
| D1 | 그룹장 이전 permission-denied | **복구 확인:** 이전·기존 그룹장 탈퇴와 활성 그룹 모집 중 해산 차단 안내 실기기 통과 |
| D2 | 즉시 가입방 참가 실패 | 승인 필드·listing sync 등 앱 패치 있음. 실기기 미확인 |
| D3 | 신청 승인(수락) 실패 | 타인 `raidState` 읽기 제거 후 승인 버튼 실기기 통과. 멤버·상태 재진입 검증은 남음 |
| D4 | 신청 자체 중구난방 / 전부 실패처럼 보임 | Listen 가드·Rules/앱 불일치 혼재 가능. 원인 재분리 필요 |
| D5 | orphan: 그룹 탈퇴 후 그룹 전용방 해산 실패 | 해산 경로·문구 재확인 |
| D6 | orphan: 전체 공개(공개범위) 변경 실패 | 비멤버 파티장 그룹→공개 허용 앱 패치 있음. 실기기 미확인 |
| D7 | orphan: 참가 캐릭터 변경 권한 실패 | `validAtomicMemberCharacterChange`는 로컬 Rules에 있음. **캐릭터 OR 포함 재게시 503으로 미반영 가능** |
| D8 | orphan: 모집 삭제 → 「이 동작을 할 권한이 없습니다」 | UI를 leave→disband로 바꾼 패치 있음. 실기기 미확인 |
| D9 | 상세 `applications`/`cycles` Listen PERMISSION_DENIED 로그 | 리더·멤버만 구독하도록 가드 있음. 로그 재현 여부 재확인 |

### orphan 재현 시나리오 (D5~D8)

1. A 계정 그룹 생성  
2. B 계정 그룹 가입  
3. B 계정 그룹 전용 모집방 생성  
4. B 계정 그룹 탈퇴  
5. B가 해당 모집에서 해산 / 전체 공개 / 캐릭터 변경 / 모집 삭제 시도 → 실패

예방: 로컬은 그룹 전용방 파티장 탈퇴를 `activeGroupRaidExists`로 막도록 바꿨다. 이미 orphan인 방의 D5~D8 복구와 별개다.

### 운영 반영·배포

1. R7·초기 Rules·Indexes 게시 — **완료**
2. 생성·이전 등 Rules 재게시 — 사용자 확인으로 **게시됨**
3. 캐릭터 변경 OR를 포함한 최신 추적 Rules — F1 검증 뒤 2026-09-16 운영 `lost-party`에 게시 완료. 이전 `/test` 503 미반영 상태를 대체함
4. 실기기 회귀 — 위 **실기기 미해결** 목록을 기준으로 진행. 로컬 패치만으로 완료 표기하지 않음

## 운영 Rules 복구 커밋 슬라이스

기능 브랜치에서 Rules만 바꿀 때는 아래 순서를 지키며, 각 커밋은 단독 revert 가능한 복구 지점이다. 현재 연결된 운영 앱이 깨지지 않도록 **OR 추가·닫힌 스캐폴드**만 허용한다.

| ID | 커밋 의도 | 포함 | 단독 revert 시 | 상태 |
| --- | --- | --- | --- | --- |
| R1 | `raidStates`·`partyEvents` 경로 스캐폴드 | match 추가, 쓰기는 닫힘 | 미사용 경로만 제거 | 완료 |
| R2 | lifecycle envelope·raidState 검증 OR 추가 | 증명 Rules 이식, 구 cycle/disband 유지 | 미사용 OR만 제거 | 완료 |
| R3 | 그룹 `activeRecruitmentCount` 생성·종료 | `validInitialGroup` 키 허용, close 분기 | 구 그룹 생성 키 복원 | 완료 |
| R4 | schemaVersion 2 모집 생성 분기 | v1 생성 유지 + 원자 생성 OR | v2 생성 문만 제거 | 완료 |
| R5 | 비lifecycle raidState create·partyEvents | 가입·신청·탈퇴 등 이벤트 유형 | 미사용 create 검증 제거 | 완료 |
| R6 | Aggregate 멤버십 갱신 분기 | 가입·승인·캐릭터·자리·탈퇴·visibility OR | 미사용 update 분기 제거 | 완료 |
| C* | Router/DI·읽기·구 경로 차단·자료 초기화 | 앱 연결과 함께만 | 부분 배포·`dev` 병합 금지 | 완료 |
| R7 | legacy 미사용 validator·event 제거 | C* `allow`에서 떼어낸 함수 본문 삭제 | R7 revert | 완료 |

### C* 테스트 자료 초기화(wipe) — Firebase 경로

프로젝트: `lost-party`. Auth·계정·캐릭터는 보존하고 **파티·그룹 거래성 자료만** 삭제한다.

#### 보존 (삭제하지 않음)

- Firebase Authentication 사용자
- `authBindings/{authUid}`
- `players/{playerId}` 본문(상태·lastSeen 등)
- `players/{playerId}/weeklyRaidClaims/{claimId}` 중 `source == 'manual'`인 문서
- `players/{playerId}/characterActivity/{characterId}`
- `gameAccounts/{gameAccountId}`
- `characters/{characterId}`
- `characterIdentityClaims/{claimId}`
- `playerGameAccounts/{ownershipId}`
- `operatorAssignments/{playerId}`
- `accountVerificationChallenges/{challengeId}`, `activeAccountVerificationChallenges/{playerId}`
- `manualVerificationRequests/{requestId}`, `manualVerificationBlocks/{blockId}`
- `groups/{groupId}` 본문·`members`·가입 관계 등(그룹 자체는 유지). 다만 아래 listing·카운트 필드는 정리한다.

#### 삭제 대상 (경로)

1. **모집 Aggregate와 하위 문서**
   - `recruitments/{recruitmentId}`
   - `recruitments/{recruitmentId}/members/{playerId}`
   - `recruitments/{recruitmentId}/applications/{applicantPlayerId}`
   - `recruitments/{recruitmentId}/applications/{applicantPlayerId}/votes/{voterPlayerId}`
   - `recruitments/{recruitmentId}/slots/{slotId}` (예: `0_0`)
   - `recruitments/{recruitmentId}/cycles/{cycleKey}`

2. **공용 파티 이벤트**
   - `partyEvents/{eventId}`

3. **플레이어별 점유·구 스키마·파티 출처 이벤트·그룹 요약**
   - `players/{playerId}/raidStates/{stateId}` — **모집만 지우고 남기면 생성 시 stale delete가 필요해진다. 반드시 함께 삭제.**
   - `players/{playerId}/activeRaidAssignments/{assignmentId}`
   - `players/{playerId}/events/{eventId}` — 파티 명령 fan-out 출처만. `type == 'manualVerificationDisputeOpened'` 등 수동 인증 분쟁 이벤트는 보존해도 된다.
   - `players/{playerId}/weeklyRaidClaims/{claimId}` — 생성 테스트 레이드·주차와 겹치면 `raidState` create가 거절된다. `source == 'manual'`도 해당 캐릭터·레이드·주차면 삭제하거나 다른 레이드로 테스트한다.
   - `players/{playerId}/groupMembershipState/current` — 깨진 `activeGroupIds`/`revision`이면 그룹 생성이 deny될 수 있다. 문서 삭제 또는 `activeGroupIds: []`, `activeGroupCount: 0`, `revision: 0`으로 재작성.
   - `players/{playerId}/groupRelations/{groupId}` — 삭제된 그룹 ID 잔여는 정리한다.

4. **그룹 모집 listing·카운트**
   - `groups/{groupId}/raidListings/{recruitmentId}`
   - `groups/{groupId}` 문서 필드: `activeRecruitmentCount`를 `0`으로, `lastRecruitmentId`는 제거하거나 null로 맞춘다(그룹 문서를 통째로 지우지 않는다).

5. **wipe 후**
   - 앱을 재실행하고 공개/그룹 모집 **신규 생성**부터 회귀한다.
   - Indexes 빌드가 `Enabled`인지 콘솔에서 확인한 뒤 `partyEvents` audience 조회를 본다.

콘솔에서 컬렉션 단위로 비우거나, 테스트용 스크립트·수동 삭제로 위 경로만 처리한다. Auth·캐릭터·수동 Claim을 포함한 전체 프로젝트 삭제는 하지 않는다.

## 현재 작업 목표 — C* 전환 후 기능 복구

새 원자 구조를 되돌리지 않고, C* 전환 뒤 멈춘 그룹·파티 모집 기능을 이전 제품 계약대로 복구한다. D1~D9는 우선 장애 목록이며, 구조 전환이 공유 경로에 미친 회귀까지 함께 확인한다. 로컬 후보 패치나 자동 테스트만으로 완료 처리하지 않고 **현재 운영 Rules와 최신 앱을 사용한 실기기 성공**을 기능별 완료 기준으로 삼는다.

## 복구 원칙

1. `schemaVersion 2` 모집 Aggregate, 통합 `raidState`, 공용 `partyEvents`, 최대 8인 원자 명령을 유지한다. 구 assignment·개인 event fan-out 구조로 되돌리지 않는다.
2. 한 번에 하나의 실패 묶음만 재현한다. 실패한 Transaction의 읽기·쓰기 문서, `expectedRevision`, Rules OR 분기와 실제 Firebase 오류 단계를 확인한 뒤 수정한다.
3. Rules가 원인이라는 근거 없이 Rules를 넓히지 않는다. 앱 Write Plan·저장 Snapshot·Router 입력 불일치이면 앱에서 고친다.
4. Rules 수정이 필요한 묶음만 표적 계약과 전체 Rules Emulator 검증 후 운영 게시한다. 같은 소스 반복 게시나 503 추측 수정은 하지 않는다.
5. 이미 확인된 그룹 생성·모집 생성·v2 가시성을 각 묶음의 선행 회귀로 보존한다.
6. 기존 orphan 방 복구와 신규 orphan 생성 방지를 구분한다. 예방이 성공해도 이미 orphan인 방의 해산·공개 전환·캐릭터 변경·모집 삭제를 완료로 보지 않는다.
7. 기능 브랜치는 모든 핵심 흐름의 실기기 회귀가 끝날 때까지 `dev`·`main`에 병합하지 않는다.

## 기능 복구 범위

### 그룹

- 생성, 검색·상세·멤버 표시
- 초대·수락·거절·취소
- 가입 신청·승인·거절·차단 해제
- 초대코드 생성·공개 설정·폐기·코드 가입
- 일반 멤버 탈퇴
- 그룹장 이전 후 기존 그룹장 탈퇴
- 마지막 1인 그룹 해산
- 활성 그룹 전용 모집이 있을 때 탈퇴·해산 차단과 안내

### 파티 모집

- 공개·그룹 전용 모집 생성, 목록·현황·상세 읽기
- 신청·철회·거절·재신청
- 즉시 가입과 신청 승인
- 참가 캐릭터 변경, 빈자리 이동, 점유 자리 교환
- 일반 탈퇴·추방·가입 순서 기반 파티장 승계
- 공개↔그룹 전용 전환과 `raidListings` 동기화
- 그룹 자격 상실 멤버 정리와 orphan 방 복구
- 완료·반복 설정·수요일 06시 주차 전환·해산. 파티 전체 완료 취소는 2026-09-19 결정으로 제거 대상
- 공용 이벤트 조회와 종료된 하위 문서의 비활성 처리

## 복구 작업 단위

### F0. 실행 기준 고정과 재현 도구 정리

참고: [`PARTY_GROUP_COMMAND_SCALABILITY_REDESIGN.md`](../architecture/PARTY_GROUP_COMMAND_SCALABILITY_REDESIGN.md), [`BUG_REPORTS.md`](BUG_REPORTS.md), [`TASK-11-FIRESTORE-RULES-COMPLEXITY.md`](TASK-11-FIRESTORE-RULES-COMPLEXITY.md).

- 콘솔에 게시한 소스가 현재 추적 `firestore.rules`와 같은지 게시 시각·소스 또는 SHA-256으로 기록한다.
- 필요한 Index가 `Enabled`인지 확인한다. Index 오류와 Rules deny를 같은 증상으로 취급하지 않는다.
- 신규 schemaVersion 2 테스트 방과 기존 orphan 방을 구분해 테스트 ID·계정 역할·명령 직전 revision을 기록한다.
- 미추적 `tools/create_permission_rules_test.mjs`는 보석 도구가 아니라 현재 전체 Rules의 그룹·모집 생성 권한 검사다. 정식 C* 전체 Rules 회귀 도구 `tools/party_group_cutover_rules_test.mjs`로 이름과 범위를 정리하고 추적한다. 별도 Rules 사본 없이 루트 `firebase.json`의 추적 원본을 demo Emulator에서 사용한다.
- `firestore.rules-backup`은 구조 개선 전 로컬 백업이다. 배포 원본으로 사용하지 않으며 저장소 상태를 흐리지 않도록 ignore 대상으로 정리한다.
- 사용자가 수정한 `AGENTS.md`는 별도 문서 변경으로 보존하고, 기능 복구 코드와 같은 커밋에 섞지 않는다.

완료 조건: 운영 소스 기준, 테스트 데이터 기준, 재현 계정 역할과 자동 검사 진입점이 한 번에 식별된다.

현재 결과(2026-09-16):

- 사용자가 콘솔에서 직접 게시한 기준의 로컬 추적 Rules SHA-256은 `B9185B07241CC93880212616CB14C5823BD55EF7D71D8E4AC38B8D5EA0BA4DA1`, Indexes SHA-256은 `87716AC3100BC18065EBE96E1B78D09E37D21BB0E4A87BFA468B056C151EEE03`이다. 이후 실기기 재현은 이 Git 시점과 해시를 기준으로 기록한다.
- `firestore.rules-backup`은 SHA-256 `A66F8AE04AEEE633F3AD30A66A6345C974011B2A95767B3F9955A1573D17E0A7`의 구조 개선 전 로컬 백업으로 분류하고 `.gitignore`에 추가했다.
- 생성 권한 임시 도구를 `party_group_cutover_rules_test.mjs`로 정리했다. 루트 `firebase.json`과 추적 Rules를 쓰는 demo 전용 GitHub Actions 및 정적 계약 테스트를 추가했다. 운영 인증·배포 명령은 포함하지 않는다.
- 로컬 JBR 21에서 Emulator 자체는 시작됐지만 `initializeTestEnvironment`의 전체 Rules 업로드가 기존 Windows 환경 문제인 `503 Network closed for unknown reason`으로 Rules 평가 전에 종료됐다. 같은 로컬 접근은 반복하지 않으며 GitHub Actions 실행을 원격 엔진 검증 기준으로 사용한다.
- 신규 계약 테스트 2건은 통과했다. GitHub Actions 실제 실행은 기능 브랜치 커밋·push 이후 확인한다.

### F1. 그룹 쓰기 복구

참고: [`FIRESTORE_GROUP_MEMBERSHIP_CONTRACT.md`](../architecture/FIRESTORE_GROUP_MEMBERSHIP_CONTRACT.md), [`GROUP_LEADER_EXIT_DISBAND_CONTRACT.md`](../architecture/GROUP_LEADER_EXIT_DISBAND_CONTRACT.md), [`PARTY_GROUP_COMMAND_SCALABILITY_REDESIGN.md`](../architecture/PARTY_GROUP_COMMAND_SCALABILITY_REDESIGN.md).

F1 주요 흐름은 2026-09-16 실기기에서 복구 확인했다. 초대코드 가입도 사용자가 Rules 게시 후 성공을 확인했고, 활성 그룹 전용 모집이 있는 1인 그룹의 해산 차단 안내까지 확인했다. 다음 구현 대상은 F2다. 무효·폐기 코드 및 중복 가입의 이번 실기기 재검증은 최종 회귀 때 확인한다.

- 범위: 초대코드로 신규 가입하는 기존 트랜잭션 및 해당 Rules 경로만 재현·수정한다. 그룹 전용 모집과 비그룹원 표시는 F4의 별도 정책·작업으로 유지한다.
- 순서: 실제 Write Plan과 읽기/쓰기 세트를 전체 추적 Rules Emulator에 재현 → 실패한 문서·검증식/예산 확인 → 최소 수정 및 허용/거절 회귀 → Rules 계약·관련 테스트 → 변경 Rules 게시와 실기기 재확인.
- 보호: 그룹 생성·직접 초대·검색 신청/승인·그룹장 이전·탈퇴·해산은 기존 의미를 바꾸지 않는다. 가입자 외 문서를 전원 순회하거나 인원 비례 쓰기를 추가하지 않는다.
- 완료: 정상 코드는 가입 및 멤버/상태/Projection/인원수 일치, 무효·폐기 코드와 중복 가입은 안전하게 처리되고, 기존 F1 경로도 회귀하지 않음을 자동·실기기 결과로 확인한다.
- 진행 결과: 실제 가입 Write Plan을 복제한 전체 Rules Emulator에서 정상 코드 가입이 표현식 1,000개 한도로 거절됨을 재현했다(`35074490029`). 코드 가입을 먼저 평가하되 기존 그룹장 이전·탈퇴·해산 우선순위를 보존한 Rules로 `35075221872`에서 정상 가입과 F1 수명주기 회귀가 함께 통과했다. 정적 Rules·Write Plan 표적 41건도 통과했다. AI의 운영 게시 시도는 안전 심사에서 차단됐으나, 이후 사용자가 Rules를 별도로 게시하고 실기기 초대코드 가입 성공을 확인했다. 게시된 활성 소스의 해시는 별도 대조하지 않았으므로 추적 Rules SHA-256 `716FDBAF1C993444E6AF2C599328788DA0704206ED193B27F59D492EC480CDE6`과 동일하다고 단정하지 않는다. 이 초대코드 가입 회귀는 사용자 확인 기준 복구됐고, 무효·폐기 코드 및 중복 가입의 이번 실기기 재검증은 미확인이다.

우선 D1 그룹장 이전을 재현하되, 같은 `groups/{groupId}` update OR를 공유하는 일반 탈퇴·마지막 1인 해산·가입 승인도 함께 회귀한다.

검사 순서:

1. 앱이 보낸 group/membership state/relation/member 쓰기와 revision을 확인한다.
2. `validAtomicGroupRecruitmentClose/Open`이 해당 명령에서 문서를 선조회하지 않고 clean false로 빠지는지 확인한다.
3. transfer 성공 뒤 leader·member role, Player relation, membership state와 화면 갱신이 모두 일치하는지 확인한다.
4. 활성 그룹 모집이 있는 그룹장·파티장의 금지 동작은 권한 오류가 아니라 계약된 안내로 끝나는지 확인한다.

완료 조건: 그룹장 이전, 기존 그룹장 탈퇴, 일반 멤버 탈퇴, 마지막 1인 해산과 기존 그룹 생성이 실기기에서 통과한다.

현재 결과(2026-09-16, F1 주요 실기기 흐름 확인):

- 그룹장 이전은 그룹 1건과 이전·신규 그룹장 membership 2건, 일반 탈퇴와 1인 해산은 그룹·본인 membership·membership state·relation의 고정 문서만 갱신한다. 파티 인원이나 `raidListings` 수에 따른 Transaction fan-out은 사용하지 않는다.
- 앱의 1인 해산은 `activeRecruitmentCount == 0`을 검사했지만 Rules의 `validGroupDisbandUpdate`에는 같은 조건이 없었다. Rules에도 정수·0 조건을 추가해 우회 클라이언트가 활성 그룹 모집을 남기고 해산하지 못하게 했다.
- 전체 Rules Emulator 시나리오에 그룹장 이전 → 기존 그룹장 탈퇴, 일반 멤버 탈퇴, 1인 해산 성공과 활성 모집 1건일 때 해산 거절을 추가했다. GitHub Actions는 같은 demo 프로젝트에서 생성 기준선과 F1 시나리오를 각각 실행한다.
- 그룹 Rules·Write Plan·C* 기준선·Rules 경고 표적 테스트 42건과 변경 테스트 파일별 정적 분석이 통과했다. 최초 두 파일 동시 분석은 Flutter 프로세스가 출력 없이 정지해 종료했지만, 파일별 재실행은 각각 문제 0건으로 완료됐다.
- CI 실동작에서 과거 membership의 선택 Snapshot 필드 누락 평가 오류와 그룹장 이전의 Rules 표현식 1,000개 한도 초과를 발견했다. 선택 필드는 누락/null/정상 타입을 허용하고, 검증 조건을 완화하지 않은 채 그룹장 이전·role 변경 분기를 OR 앞쪽으로 옮겨 비용을 줄였다.
- GitHub Actions 실행 `35055217000`에서 전체 추적 Rules 생성 기준선과 F1 그룹 수명주기 Emulator 시나리오가 모두 통과했다. 앞선 실패 실행은 테스트 SDK API 오류와 위 두 Rules 회귀를 찾은 진단 근거로 유지한다.
- 운영 게시본 Rules SHA-256은 `A8E9D51EF6F52E2B38BAE1F72462B98F78A2DA105B1522C47152B54BBE54BA1B`이다. `firebase deploy --only firestore:rules --project lost-party` 1회 실행으로 컴파일·업로드·release가 성공했으며 Indexes 등 다른 자원은 게시하지 않았다.
- 그룹장 이전·이전 후 탈퇴·일반 탈퇴·1인 해산은 사용자 실기기 테스트에서 통과했다. 활성 그룹 전용 모집이 있는 1인 그룹의 해산 시도도 차단되고 전용 안내가 표시됨을 사용자가 확인했다.
- 해산 차단 경로의 로컬 계약 재확인: Repository는 `activeRecruitmentCount > 0`에서 `activeGroupRaidExists`를 반환하고 Rules도 그룹 해산을 `activeRecruitmentCount == 0`일 때만 허용한다. 관련 표적 테스트 49건이 통과했다. F4의 그룹장 레이드 관리가 구현되기 전에는 다른 공대장의 방을 그룹장이 직접 정리할 수 없다.

### F2. 참가 진입 복구

참고: [`PARTY_PARTICIPATION_RULES.md`](../product/PARTY_PARTICIPATION_RULES.md), [`FIRESTORE_PARTY_COMMAND_CONTRACT.md`](../architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md), [`WEEKLY_RAID_CLAIM_CONTRACT.md`](../architecture/WEEKLY_RAID_CLAIM_CONTRACT.md).

D2 즉시 가입, D3 신청 승인, D4 신청 불안정을 **신청 상태 전이 → 확정 참가 → 화면 재진입** 순서로 복구한다. 현 Router는 `FirestorePartyAtomicApplicationCommandRepository`와 `FirestorePartyAtomicJoinCommandRepository`를 실제 상세에 주입한다. 두 클래스의 오래된 “Router 미연결” 주석과 구 계약 문서의 `activeRaidAssignment` 서술을 실행 기준으로 삼지 않는다. 현재 기준은 schemaVersion 2 모집 Aggregate, Player별 `raidState`, 공용 `partyEvents`, 신청 원본 및 그룹 `raidListings`다.

#### F2-0. 생성→목록→후보→신청 계약 재정렬 (F2-A/B보다 선행)

참고: [`FIRESTORE_PARTY_READ_MODEL_CONTRACT.md`](../architecture/FIRESTORE_PARTY_READ_MODEL_CONTRACT.md), [`PARTY_PARTICIPATION_RULES.md`](../product/PARTY_PARTICIPATION_RULES.md), [`BUG_REPORTS.md`](BUG_REPORTS.md) BUG-019.

2026-09-17 실기기에서 새 공개방 신청의 `unknown` 오류, 기존 방의 타인 목록 미표시, 점유 캐릭터의 생성 후보 표시 누락과 생성 `permission-denied`가 함께 보고됐다. `BUG-019`의 확인/미확정 근거를 기준으로 아래를 **한 번에 설계하되 구현은 순서대로 검증 가능한 작은 구간으로 분리**한다. 기존 F1 그룹 흐름, 그룹 전용방 및 정상 공개방을 회귀 보호하고, 구 assignment 구조는 복원하지 않는다.

1. **증거 고정:** 실패한 신청 방과 보이지 않는 기존 방을 구분해 ID·공개/그룹·승인 방식·주차·`revision/status/visibility/manualRecruitmentEnabled/hasAvailableSlot`를 기록한다. 신청 방의 슬롯/비그룹/pending 집계, 생성 실패 캐릭터의 `raidState(status/cycleKey/recruitmentId)`와 연결 모집 상태, 실제 Firebase 오류 코드를 특정 문서로만 읽는다. 두 기기의 Player ID 구분, Router 생성 시 고정된 주차 키와 수요일 06시 전후 재진입도 확인한다. 목록 쿼리 필터로 의도대로 제외된 방인지 갱신/권한 오류인지 판정하기 전에는 필터를 넓히지 않는다.
2. **저장 불변식 복구:** 현재 공개·무그룹 초기 슬롯은 `countedAsNonGroupMember=false`인데 `nonGroupMemberCount=1`이며 신청 Repository가 Domain Aggregate 생성에서 서버 쓰기 전에 실패한다. 무그룹 방의 비그룹 집계 `0`을 기준으로 생성·가입·탈퇴/추방·캐릭터 변경·공개 범위 명령의 슬롯 Snapshot과 카운트를 대조하고, Rules 초기 생성 검증과 그룹 연결 공개방의 별도 의미를 함께 고정한다. `PartyAtomicCreateWritePlan.fromBase()` 결과를 즉시 `PartyAtomicDocumentMapper.aggregate()`로 읽는 왕복 테스트와 공개/그룹/그룹 연결 공개방 1→2명 전이 테스트를 추가한다. 기존 잘못 저장된 방은 수·소유·주차 확인 뒤 제한적 복구 또는 테스트 데이터 정리를 별도 결정하며 임의 삭제하지 않는다.
3. **후보·서버 판정 정렬:** Router의 후보 `FirestoreActiveRaidAssignmentLookup`이 구 `activeRaidAssignments`를 읽는 동안 생성/가입 명령은 `raidStates`를 쓴다. 조회를 현재 문서로 정렬하고 active/completed/이전 주차·만료 1회성·반복방·orphan 상태를 생성 `PartyCreateOccupancyGate` 및 주간 Claim 정책과 맞춘다. 생성 화면은 `candidate.canSelect`/역할 선택 가능성의 공통 결과를 사용해 동일 레이드 참가·이번 주 완료를 빨간 표시하고 선택을 막는다. 제출 직전 Transaction 재검증과 구체적 실패 안내는 유지한다.
4. **생성 permission-denied 분리:** 기존 점유의 연결 모집 `get`, stale `raidState` 교체, 신규 모집/membership/event의 각 Rules 쓰기 중 최초 실패 문서를 Emulator로 재현한다. 실제 서버 실패 단계가 확인된 경로만 앱 또는 Rules에서 최소 수정한다. 단순히 권한 분기를 넓히지 않는다.
5. **목록·신청 재검증:** 공개 목록의 현재 주차·활성·수동 모집·빈자리·타인 필터를 그대로 두고 저장값과 일치하는 방만 노출한다. 생성 결과가 read model과 Aggregate 양쪽에 유효한지 확인한 뒤 최초 신청→철회→재신청, 그룹 연결 공개방과 그룹 전용방, 즉시 가입·승인까지 진행한다. 화면 재진입과 구주차 전환도 포함한다.

완료 게이트: 새 공개/그룹 방의 생성→다른 계정 목록/상세→신청 또는 즉시 가입이 같은 원본·주차·집계를 사용하고, 점유/완료 캐릭터가 생성 전 후보에서 차단되며, 서버 경쟁 거절에는 구체적 안내가 나온다. 공개·그룹 생성, F1 그룹 수명주기, 주간 Claim, 1·2·4·8인 대표 Rules Emulator와 최대 3계정 실기기를 회귀한다. Rules 변경 시 계약/경고 검사 후 배포 정책을 별도로 적용하며 Indexes 게시·기존 운영 데이터 변경·`dev/main` 병합은 현 단계에서 제외한다.

진행(2026-09-17, 작업 브랜치 체크포인트 `887a0fb`·`6110013`): 공개·무그룹 신규 방의 초기 `nonGroupMemberCount`를 슬롯 Snapshot과 같은 `0`으로 맞췄고 가입 증분도 실제 추가 슬롯의 `countedAsNonGroupMember`를 기준으로 계산한다. Rules 초기 생성 조건과 전체 Emulator 생성 fixture를 같은 값으로 정렬했다. 생성 Write Plan→Aggregate 읽기 왕복과 공개방 1→2인 가입, 그룹 전용방 왕복을 표적 테스트로 고정했다. 생성 후보의 서버 조회를 구 `activeRaidAssignments`에서 `raidStates`로 변경하고 active 점유는 생성 명령의 `PartyCreateOccupancyGate`를 재사용한다. 생성 화면은 후보의 전체 `canSelect`를 적용한다. 직접 영향 Flutter 표적 42건, 변경 파일 정적 분석과 diff 검사는 통과했다. 전체 추적 Rules Emulator 및 F1 회귀 CI `35114485069`도 커밋 `7f8e269`에서 통과했다. CI 로그의 의도된 거절 테스트 `PERMISSION_DENIED`와 도구의 Node deprecation 경고는 Rules 컴파일 경고 수의 확인을 대신하지 않는다. 운영 게시, 기존 불일치 방 처리, 실제 방 데이터 대조와 실기기 회귀는 아직 완료하지 않았다. 기존 운영 Rules는 사용자 확인 게시본을 그대로 유지하며 새 Rules는 아직 게시하지 않았다.

운영 데이터 대조 및 재현(2026-09-17): `이슈하이`의 세 방은 모두 `targetCycleKey=2026-09-09`, `continueTogether=false`, `cycleEndsAt=2026-09-16 06:00 KST`, `status=active`라 현재 주차 공개 목록 제외는 의도된 쿼리 결과다. 세 방 모두 초기 슬롯의 `countedAsNonGroupMember=false`인데 `nonGroupMemberCount=1`이라 기존 방 신청 Aggregate 실패 대상이다. 기존 방 문서의 수동 변경은 보류한다. 이전 주차 1회성 active 방/raidState를 만들고 현행 생성 명령처럼 동일 Transaction에서 stale raidState `delete`→`set`하는 Emulator 회귀 `35168119595`는 Rules 1,000식 평가 한도의 `permission-denied`로 실패했다. 이는 새 주차 생성 거부의 재현 가능한 경로다(실제 실패 캐릭터의 raidState는 아직 읽지 않았으므로 개별 사건 확정은 유보).

다음 최소 수정: (a) `raidState`가 기존 모집의 만료된 1회성 점유임을 서버 문서·주차·종료시각으로 재검증하는 **단독 원자 삭제**를 생성 전 실행하고, (b) 새 모집·membership·raidState·공용 이벤트 생성은 기존 원자 Transaction을 유지한다. 삭제와 생성 사이 앱 종료/실패 시에는 이미 만료된 점유만 제거되고 기존 모집 문서는 유지되며 사용자가 재시도할 수 있어야 한다. 동일 주차 active·반복방·주간 Claim·소유권 불명 상태는 정리하지 않는다. 동시 변경은 삭제 Transaction과 생성 Transaction에서 각각 재검증하고 경쟁 시 구체적 충돌로 반환한다. 먼저 Emulator에서 stale 단독 삭제→새 생성 성공 및 반복방/이번 주 active 삭제 거부를 고정한 뒤 Repository를 수정한다. Rules 표현식을 단순히 완화하거나 전체 모집 문서를 삭제하지 않는다.

구현 진행: 전체 Rules Emulator CI `35168309443`에서 동일 Transaction 교체 거부, 만료 1회성 `raidState` 단독 삭제→신규 모집 원자 생성 성공을 확인했다. 생성 Repository는 점유 교체 판정 시 첫 Transaction에서 stale state만 삭제하고, 두 번째 Transaction에서 인증·캐릭터·점유·주간 Claim·그룹 상태를 다시 읽고 새 모집을 생성하도록 변경했다. 현재 주차 active 및 만료 반복방 삭제 거부까지 포함한 최종 Rules/F1 회귀 CI `35168721155`가 통과했고, 변경 Repository 분석 0건·직접 영향 Flutter 표적 27건도 통과했다. 전체 `flutter test`는 17건 실패, 전체 `flutter analyze`는 기존 파일을 포함해 38건 지적을 반환해 원인 분리 전에는 전체 회귀 완료로 간주하지 않는다. 실기기 생성/신청은 미검증이다. Rules는 이 수정에서 새로 변경하지 않았으며 운영에는 앞선 초기 생성 집계 Rules 수정본도 아직 미게시다. 새 앱의 `nonGroupMemberCount=0` 생성과 새 Rules의 초기 생성 조건은 함께 적용해야 하므로 운영 게시와 새 빌드 디바이스 테스트의 시점을 조율한다.

#### F2-A. 신청 상태 전이와 실패 지점 분리

참고: [`FIRESTORE_PARTY_COMMAND_CONTRACT.md`](../architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md), [`PARTY_PARTICIPATION_RULES.md`](../product/PARTY_PARTICIPATION_RULES.md).

1. 운영 게시 Rules·인덱스와 현재 앱 빌드의 기준을 확인한다. 공개/그룹 전용 방, 직접 참가/승인 방을 구분하고 actor Player·recruitmentId·applicationId, 명령 전 `revision/status/cycleKey`와 Firebase 오류 `code`를 기록한다. “신청 실패”가 명령 Transaction, 권한 있는 읽기·Listen, 화면 갱신 중 어느 단계인지 분리한다. Listen 자체의 일반 역할별 재설계는 F3에 남긴다.
2. 신청 생성 → 본인 철회 → 재신청, 파티장 거절 → 재신청, 승인 후 탈퇴 → 재신청을 각각 `applications/{playerId}`의 같은 문서 전이로 고정한다. `pending` 중복 거절, `revision` 증가, `approvalCount` 재신청 초기화, `rejectionCount` 유지, 신청 당시 `countedAsNonGroupApplicant`와 모집의 pending 집계 증감을 확인한다. 신청 대기는 `raidState` 확정 점유를 만들지 않는다.
3. 실제 Write Plan의 모집·신청·공용 이벤트 쓰기와 `validPendingApplication`/재신청/철회/결정 Rules를 현재 전체 Rules Emulator에 재현한다. Windows 로컬 전체 Rules 업로드 503은 이미 분리된 환경 문제이므로 같은 시도를 반복하지 않고 demo 전용 GitHub Actions를 엔진 검증 경로로 사용한다. 결함이 재현된 문서와 Rules 분기만 좁게 수정한다.

현재 진행(2026-09-16): 공개방 신청→철회→재신청은 전체 Rules Emulator `35087432007`에서 통과했다. 그룹 연결 공개방에서 재신청 시 `countedAsNonGroupApplicant`가 바뀌는 경계는 `35087675480`에서 신청 update의 표현식 1,000개 한도 `PERMISSION_DENIED`로 재현했다. 재신청 허용 필드에 해당 Snapshot을 추가하되 현재 그룹 membership과 일치시켰고, 신청 update는 새 상태별 분기만 평가하도록 조정했다. 수정본 `35104429826`, 그룹 전용방의 정상/변조 재신청까지 확장한 `35104711642`의 전체 추적 Rules·F1 회귀가 통과했다. 관련 Flutter 표적 46건, 변경 테스트 파일 분석과 `git diff --check`가 통과했다. 최신 Rules SHA-256은 `AAB74C69483AE1C46AF69C3D8378F30573581AAA1FCBBB1485181BFBD31255D5`이다. 최초 운영 게시 시도는 안전 심사에서 명령 실행 전 거절됐다. 이후 사용자가 이 버전의 게시를 승인했으나 CLI 결과는 작업 중단으로 확인하지 못했다. 사용자는 현재 운영 게시 Rules와 로컬 파일의 내용이 동일함을 직접 확인했다. 따라서 소스 일치는 사용자 확인으로 기록하고, CLI 컴파일 경고 수·게시 시각·실기기 성공은 확인하지 않은 상태로 둔다. 동일 Rules의 재게시 없이 F2-A 실기기 신청→철회→재신청 결과를 먼저 받는다.

실기기 피드백: 최초 신청에서 `신청을 처리하지 못했습니다.`가 표시됐다. 원자 신청 Repository에 추가한 디버그 빌드 전용 로그로 `PartyAtomicDocumentMapper.aggregate()`의 `ArgumentError: 모집 Aggregate 집계가 올바르지 않습니다`를 확인했다. 서버 쓰기 전 저장 문서와 Domain 불변식의 불일치이며 이 신청의 Rules `permission-denied`는 아니다. 신청 쓰기·Rules·사용자 안내는 아직 변경하지 않았다. F2-0의 생성 집계 복구와 기존 방 처리 방향을 먼저 확정하고, 실패 방의 실제 저장값을 확인하기 전에는 F2-A를 완료로 처리하지 않는다.

#### F2-B. 즉시 가입과 승인 확정

참고: [`FIRESTORE_PARTY_COMMAND_CONTRACT.md`](../architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md), [`WEEKLY_RAID_CLAIM_CONTRACT.md`](../architecture/WEEKLY_RAID_CLAIM_CONTRACT.md), [`BUG_REPORTS.md`](BUG_REPORTS.md) 승인 실패 기록.

실기기 디버그 근거(2026-09-17): 가입 승인 버튼에서 모집 문서와 신청 문서 읽기는 성공했고, `FirestorePartyAtomicJoinCommandRepository._join`의 신청자 `players/{applicantPlayerId}/raidStates/{characterId}_{raidId}` `transaction.get`에서 `permission-denied`가 발생했다(실기기 10:45 KST). Rules의 raidState `get`은 `playerId == currentPlayerId()`만 허용한다. 따라서 승인 쓰기/Rules 조합은 아직 실행되지 않았으며 과거의 승인 쓰기 추정 패치를 성공으로 취급하지 않는다. 다음 최소 수정은 승인 actor가 타인 raidState를 읽지 않고, 신규 raidState `create`와 주간 Claim의 기존 서버 Rules가 중복·완료 점유를 최종 거부하도록 하는 것이다. 본인 즉시 가입은 기존 상태 조회·stale 판정을 유지한다. 먼저 Emulator에서 정상 승인 및 타인 raidState 단건 get 거부, 기존 점유/Claim 승인 거부를 재현하고 그 뒤 Repository만 좁게 변경한다. 승인 완료 후 다른 문서의 Rules 한도·권한 실패가 드러나면 동일 명령의 첫 실패 지점을 다시 로그로 확인한다.

수정·검증(2026-09-17): 승인 경로만 신청자 `raidState`의 Transaction 읽기를 생략하고 본인 즉시 가입의 읽기/충돌 판정은 유지했다. 승인자 타인 state `get` 거부·정상 승인 성공은 전체 Rules Emulator CI `35171953952`, 기존 점유와 주간 완료 시 승인 거부까지 포함한 CI `35172188208`에서 통과했다. Repository·계약 테스트 분석 0건, 직접 영향 Flutter 표적 12건 통과. **사용자가 수정 빌드의 가입 승인 성공을 실기기에서 확인했다.** 멤버·상태/신청 화면의 재진입 일관성과 즉시 가입은 별도 확인이 남았다. 현 규칙에서는 충돌 거절도 `permission-denied`로 매핑될 수 있다. 이 승인 수정에서 Rules는 변경하지 않았다.

2026-09-18 후속 판정: `니티야`의 4막 승인 실패는 삭제된 모집 원본을 참조하는 기존 `active raidState`와 연결됐다. 같은 방장·신청자 Player의 다른 Character 승인은 성공했으므로 일반 승인 전체의 권한 오류로 취급하지 않는다. 신청 단계가 기존 active 점유를 허용하고 승인에서 모호한 권한 팝업이 되는 경계는 F6-D로 분리한다. 서버 고아 문서의 수동 정리는 이번 기능 복구에서 제외한다. 상세 근거는 `BUG_REPORTS.md` 2026-09-18 항목이다.

4. 즉시 가입은 신청 문서 없이 본인 actor가, 승인은 현재 승인권자가 `pending` 신청자를 확정한다. 두 경로의 성공 결과가 모집 `partySlots/memberPlayerIds`·인원/역할/그룹 집계·revision, 대상 membership·`raidState`, 그룹 listing 전체 Snapshot, 공용 이벤트 1건에서 일치하는지 비교한다. 승인 전이는 `approvedByApprover`, `approvalCount + 1`, pending 집계 −1이며 신청 당시 그룹 집계 Snapshot을 사용한다.
5. Rules의 읽기·쓰기 순서를 따로 검증한다. 가입/승인 모두 소유 Character·주간 Claim·현재 회차·정원·역할/동일 파티 직업·기존 확정 점유·그룹 접근 권한을 Transaction에서 재판정한다. 승인자가 타인의 stale `raidState`를 지우지 않으며, 본인 즉시 가입의 stale 정리도 Rules가 허용하는 경우에만 수행한다. 다중 승인·가입 경쟁, revision 충돌, 중단 후 재시도에서 멤버·점유·이벤트·집계가 중복되지 않아야 한다.

#### F2-C. 연결 검증과 완료 게이트

참고: [`PARTY_GROUP_COMMAND_SCALABILITY_REDESIGN.md`](../architecture/PARTY_GROUP_COMMAND_SCALABILITY_REDESIGN.md), [`FIRESTORE_PARTY_READ_MODEL_CONTRACT.md`](../architecture/FIRESTORE_PARTY_READ_MODEL_CONTRACT.md).

6. 각 수정 뒤에는 기존 모집/그룹 생성과 v2 목록·현황·상세, F1 이전·탈퇴·초대코드·해산 차단을 회귀 보호한다. 표적 Domain/Write Plan/Rules 계약과 전체 Rules Emulator의 허용·거절 케이스를 먼저 통과시키고, Rules가 실제 변경됐을 때만 배포 절차를 적용한다. Indexes 게시가 새로 필요하면 별도 명시 지시를 받는다.
7. 자동 검증 후 최대 3계정 실기기에서 공개·그룹 전용 각각 신청/철회/거절/재신청/승인/즉시 가입을 확인한다. 같은 레이드 복수 pending은 허용하되 첫 확정 참가 뒤 중복 확정은 차단하고, 만석·역할/직업 충돌·주간 완료·구 회차 및 앱 재진입을 대표 경계로 확인한다. 4·8인 경계와 경쟁은 Emulator로 보강하고 8대 디바이스를 요구하지 않는다.

완료 조건: D2~D4의 실제 실패 지점과 수정 근거가 기록되고, 공개/그룹 방의 신청 상태 전이·확정 참가가 자동/실기기에서 일관되게 통과한다. 권한 오류나 재시도에서 부분 성공·중복 저장이 없고 기존 F0/F1 흐름이 유지된다. F3 Listen 전체·F4 orphan/그룹장 관리·F5 자리 조정·F6 회차 수명주기 구현은 이번 묶음에서 제외한다.

### F3. 상세 읽기와 Listen 복구

참고: [`FIRESTORE_PARTY_READ_MODEL_CONTRACT.md`](../architecture/FIRESTORE_PARTY_READ_MODEL_CONTRACT.md), [`FIRESTORE_PARTY_COMMAND_CONTRACT.md`](../architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md).

D9를 독립 묶음으로 처리한다. 공개 방문자, 신청자, 확정 멤버, 파티장별로 허용된 구독이 다르므로 화면 진입 시 실제로 연 Listener를 역할별로 대조한다.

- 신청 전체 목록은 파티장만 구독한다.
- 본인 신청은 본인 단건 경로만 구독한다.
- 구 `cycles`는 리더·확정 멤버만 읽고, v2 회차 상태는 모집 Aggregate를 기준으로 표시한다.
- 구독 권한이 없는 역할은 Listener를 시작하지 않으며 로그에 `PERMISSION_DENIED`를 남기지 않는다.

완료 조건: 네 역할의 상세 진입·이탈·재진입에서 화면과 로그가 정상이고 기존 목록·현황 가시성이 유지된다.

### F4. orphan 예방과 복구

참고: [`PARTY_GROUP_COMMAND_SCALABILITY_REDESIGN.md`](../architecture/PARTY_GROUP_COMMAND_SCALABILITY_REDESIGN.md), [`FIRESTORE_PARTY_COMMAND_CONTRACT.md`](../architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md), [`BUG_REPORTS.md`](BUG_REPORTS.md).

D5~D8을 같은 재현 시나리오로 시작한다. 사용자가 확인한 정책상 **현재 그룹장에게 그룹 전용방의 전체 공개 전환·모집 해산 두 권한만 추가**하며, 방 참가 여부는 조건이 아니다. 공대장·그룹장 역할을 합치거나 그룹장 Player ID를 모든 모집에 복제하지 않는다. 계약은 `docs/product/GROUP_PRODUCT_FLOW.md` §9.3을 따른다.

#### 조사로 확인한 기존 경계와 선행 회귀

- 그룹 상세에는 연결 모집 관리 화면이 없다. 공개 모집 목록은 신청 가능한 현재 주차 방을 필터링하므로 만석·모집 일시 중단·이번 주차 완료 반복방을 관리 목록 대신 사용할 수 없다.
- `groups/{groupId}/raidListings`는 그룹원에게 읽기가 허용되고 정상 명령에서 원자 동기화되지만 과거 누락 가능성이 있다. 그룹의 `activeRecruitmentCount`가 남아도 listing만으로는 누락 방을 찾아낼 수 없다.
- 현재 원자 해산·공개 전환 Repository, Rules 및 상세 버튼은 모집 `leaderPlayerId`만 허용한다. 그룹장이 방 참가자가 아니면 기존 모집 상세의 일부 하위 자료도 읽을 수 없다. 전용 관리 카드는 모집 원본의 허용된 요약만 사용한다.
- 전체 공개 전환 뒤에도 모집 `groupId`는 남는다. 현재 `PartyAtomicWritePlan.closesActiveGroupRecruitment`와 `groupListingAction`, Rules의 `atomicClosesActiveGroupRecruitment`는 일부 경로에서 `groupId`만 보고 그룹 집계·listing을 다시 변경할 수 있다. **공개 전환 후 완료·해산·다음 명령의 이중 감소 또는 없는 listing 갱신**을 먼저 고쳐 회귀로 고정한다. `visibility == group`이며 아직 활성 집계 대상일 때만 그룹 수·listing을 변경해야 한다.
- 8인 원자 해산은 Rules 문서 접근 예산이 이미 최대치에 근접한다. 그룹장 권한을 추가하는 get/getAfter가 개별 쓰기 10회·전체 20회 또는 표현식 1,000개 한도를 넘지 않는지 실제 Emulator로 증명한다. 캐시를 가정하지 않는다.

#### 포함 범위와 순서

1. 원본 모집 기준 관리 목록의 읽기 계약을 먼저 증명한다. 기준은 `groupId == 현재 그룹 && visibility == group && status == active`로 고정한다. 그룹장만 페이지를 열고, 방당 제목·레이드·난이도·공대장·인원·반복/회차 상태를 본다. 완료된 1회성·해산·전체 공개 방은 제외하고, 이번 주 완료된 활성 반복방과 만석방은 포함한다. 목록은 페이지네이션으로 끝까지 조회하며 첫 20건만으로 전체라고 판정하지 않는다. 이 정확한 원본 쿼리에 필요한 Firestore Rules list 계약·복합 인덱스를 Emulator에서 선검증한다. Rules 비용 안에서 원본 쿼리를 안전하게 허용할 수 없다면 불완전한 `raidListings`만으로 화면을 만들지 말고, 조회 계약과 누락 복구 방안을 다시 설계한 뒤 진행한다. 인덱스 운영 게시가 필요하면 별도 명시 지시를 받는다.
2. 그룹 상세에 `그룹 레이드 관리` 버튼과 전용 화면을 연결한다. `activeRecruitmentCount > 0`인데 원본 목록이 비거나 최종 전체 건수와 다르면 불일치를 표시하고 그룹 해산 성공처럼 안내하지 않는다. 자동 카운트 재작성이나 listing 삭제로 덮지 않는다. 누락 원본/집계 복구는 정확한 모집 ID·revision을 확인할 수 있는 별도 진단 경로로 다룬다.
3. 전체 공개 전환은 현재 공대장 **또는** 해당 그룹의 현재 그룹장만, 모집이 그룹 전용·active일 때 허용한다. 기존 visibility Transaction에서 모집·그룹 활성 수·listing 삭제를 함께 확정하고 groupId 이력은 유지한다. 그룹장이 아닌 일반 그룹원과 다른 그룹장은 거절한다.
4. 모집 해산도 현재 공대장 **또는** 해당 그룹의 현재 그룹장만 그룹 전용방에서 허용한다. 그룹장 명령은 기존 최대 8명 `raidState` 해제·모집 종료·그룹 수 감소·listing 제거·공용 이벤트의 원자 계약을 그대로 충족한다. `lastCommandActorPlayerId`와 실제 호출자를 맞추되 모집 공대장·멤버십은 변경하지 않는다. 완료·주차 전환·신청 승인·자리 조정 권한은 기존 공대장 정책을 유지한다. 파티 전체 완료 취소 기능은 역할과 관계없이 제거한다.
5. 기존 orphan 방의 공대장 명령(D5~D8: 공개 전환·캐릭터 변경·모집 삭제→해산·직접 해산)을 다시 검증한다. 그룹장은 추가 두 명령만 실행한다. 그룹 전용방 공대장의 그룹 탈퇴를 막는 현행 로컬 가드는 새 구조와 과거 orphan 복구의 실기기 확인 뒤 제거 여부를 결정한다.

#### 회귀·완료 조건

- 3개 이하 계정으로 그룹장·방 공대장·일반 그룹원을 분리해 권한을 확인한다. 그룹장 이전 직후 새 그룹장만 관리할 수 있어야 하며, 그룹장이 방에 참가하지 않아도 두 명령이 가능해야 한다.
- 목록에는 활성 반복방(이번 주 완료 포함), 만석, 모집 일시 중단이 보이고 완료된 1회성·해산·전체 공개는 보이지 않는다. 그룹 해산 차단 수와 목록 전체 건수가 같거나, 불일치가 명시적으로 드러난다. 오래된 listing, 원본 누락과 20건 초과도 점검한다.
- 그룹장 공개 전환/해산 뒤 집계는 정확히 한 번 감소하고 그룹장 단독 그룹 해산이 가능하다. 전체 공개로 전환한 방은 기존 공대장이 완료·해산·다음 주차 전환을 계속할 수 있으며 그룹 집계·listing을 다시 건드리지 않는다.
- 기존 공대장 명령, 과거 orphan 방 복구, 일반 공개방 권한, 1·2·4·8인 원자 해산과 Rules 접근 한도를 표적·전체 Emulator 및 실기기로 확인한다. 완료 전까지 `dev`·`main` 통합이나 운영 배포 완료 판정을 하지 않는다.

### F5. 파티 구성 변경 회귀

참고: [`PARTY_PARTICIPATION_RULES.md`](../product/PARTY_PARTICIPATION_RULES.md), [`FIRESTORE_PARTY_COMMAND_CONTRACT.md`](../architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md), [`CHARACTER_BUILD_INTEGRITY_CONTRACT.md`](../architecture/CHARACTER_BUILD_INTEGRITY_CONTRACT.md).

2026-09-17 복구 후보: 승인 성공 직후 사용자가 자리 변경·추방·해산 실패를 보고했다. 자리 변경 Rules의 멤버 projection 갱신이 폐기된 `slots` 문서를 요구하던 불일치를 `partySlots` 전후 위치 확인으로 바꿨다. 추방은 타인 개인 `raidState`의 Transaction 읽기를 생략하고 삭제를 Rules에 검증시키며, 본인 탈퇴의 상태 읽기는 유지한다. demo 전체 Rules CI `35190655744`는 2인 이동·추방·활성 해산과 기존 그룹 회귀, `35190876922`는 점유 자리 교환·4/8인 활성 해산, `35191028614`는 완료방 해산 시 개인 완료 상태 보존, `35191866476`는 그룹 연결 방 해산의 집계·listing 정리, `35192360261`은 추방 후 직접 재가입까지 통과했다. CI fixture의 본인 제거를 `추방`이라 표기한 음성 테스트는 실제 타인 추방 테스트가 아니어서 바로잡았다. 앱 저장소와 Rules의 표적 분석·테스트는 통과했다. 최신 Rules SHA-256은 `3BA4889260B3BF74B1303E34ECFEF2B3D2A74284E59F0354A97BFC9D5D5F6FD4`다. 최초 운영 Rules 게시 시도는 안전 심사에서 명령 실행 전에 거절됐고, 사용자의 별도 명시 승인 후 `firebase deploy --only firestore:rules --project lost-party` 1회가 컴파일 경고 없이 release까지 성공했다. 다른 자원은 게시하지 않았다. 수정 디버그 APK를 데이터 유지 설치했고 **자리 변경·참가자 추방·실제 재가입 완료·참가자 있는 활성 방 해산 후 재참가 가능 상태를 사용자 실기기에서 확인했다.** 같은 테스트 시간대 `PartyAtomicJoin permission-denied` 로그가 3건 있었으나 최종 재가입은 성공했다. 당시 반복 시도나 다른 대상 방의 실패인지 확정할 자료가 없어 별도 재현 전까지 원인·복구 완료를 주장하지 않는다. 앱 재진입 후 상태·완료방·그룹 전용방의 실기기 검증은 별도다. 중단된 전체 `flutter test`를 다시 끝까지 실행한 결과 1,157건 통과·17건 실패로, 앞선 전체 실행의 실패 수와 같다. 전체 회귀 통과로 표시하지 않으며 실패 테스트의 기존 결함/신규 영향 분리는 F7에서 수행한다.

- 참가 캐릭터 변경의 membership·Aggregate slot·`raidState` 교체가 한 Transaction에서 일치한다.
- 자리 이동·교환은 같은 파티의 동일 직업 제한을 유지하고 다른 파티 이동 가능 정책을 보존한다.
- 탈퇴·추방·파티장 승계는 대상과 필요 후임만 바꾸며 그룹 listing과 공용 이벤트를 동기화한다.
- 보석·아크그리드 `buildIntegritySnapshot` 표시를 보존한다.

완료 조건: 4인과 8인 대표 구성에서 변경·이동·교환·탈퇴·추방·승계가 통과한다.

### F6. 회차 수명주기 회귀

참고: [`WEEKLY_RAID_CLAIM_CONTRACT.md`](../architecture/WEEKLY_RAID_CLAIM_CONTRACT.md), [`PARTY_GROUP_COMMAND_SCALABILITY_REDESIGN.md`](../architecture/PARTY_GROUP_COMMAND_SCALABILITY_REDESIGN.md), [`RAID_CATALOG_DATA.md`](../product/RAID_CATALOG_DATA.md), [`BUG_REPORTS.md`](BUG_REPORTS.md).

활성 해산은 타인 개인 `raidState` 읽기를 생략하고 Rules의 전원 대상·삭제 검증을 사용한다. 완료 후 해산은 기존처럼 대상 상태를 읽거나 삭제하지 않는다. 전체 완료·취소·회차 전환은 이번 수정 범위가 아니며 별도 실기기 회귀가 필요하다.

2026-09-18 후속 판정: `이슈아이`의 모든 레이드 수동 체크는 구 assignment나 해당 Character Claim 잔여가 아니라 `_loadConflictContext`의 접근 불가 그룹방 신청 부모 읽기에서 먼저 실패한다. 바로 아래 F6-B1에서 이 조회 경계만 우선 복구한다. 수동 `weeklyRaidClaims`와 새 파티 `raidState`의 별도 계약 간극·완료방 해산 후 체크 누락은 F6-B2로 유지한다.

2026-09-17 실기기 신규 회귀: 완료방 해산 후 내 계정의 완료 체크가 보이지 않는다. 또 모집 생성 첫 진입은 대표 캐릭터와 첫 레이드(4막)를 암묵적 기본값으로 사용한다. 대표 캐릭터로 이미 4막 방을 생성·참가했거나 이번 주 완료한 뒤 다시 들어오면 그 기본 조합이 생성 불가능하여 캐릭터/레이드 선택이 함께 막힌다. 캐릭터가 많은 원정대에서는 다른 캐릭터→다른 레이드→원래 대표 캐릭터 순서로 우회할 수 있지만, 캐릭터가 하나인 사용자에게는 우회 경로도 없다. 완료방 해산의 원자 Write Plan은 완료 `raidState`를 보존하지만 내 계정 체크 UI는 구 `weeklyRaidClaims`만 구독한다. 생성 페이지는 기본 레이드에서 `candidate.canSelect`가 거짓이면 대표 캐릭터를 초기 선택하지 않고, 캐릭터가 없으면 레이드 옵션을 비운다. **저장 상태 보존 테스트의 통과를 UI 완료 체크 통과로 취급하지 않는다.**

복구 설계: (1) 실기기 해당 `raidState`의 `cycleKey/status/source/recruitmentId`와 구 Claim 존재 여부를 읽기 전용으로 대조해 완료 명령·해산·표시 중 첫 불일치를 확정한다. (2) 주간 완료 읽기를 수동 Claim과 파티 `raidState`가 일관된 하나의 화면 판정으로 합치되 주차 경계·개인 체크 해제·중복 상태의 우선순위를 계약 테스트로 고정한다. 신규 명령에 구 Claim 복제 쓰기를 추가하지 않으며 파티 전체 완료 취소는 제거한다. (3) 모집 생성의 초기 레이드 선택을 비우고 대표 캐릭터를 탐색 기준으로 유지하는 사용자 제안을 우선 검토한다. 캐릭터의 역할·아이템 레벨에 맞는 레이드 목록을 보여주되, 선택 레이드가 없을 때는 저장을 불허한다. 현재 Form과 draft가 선택 레이드/난이도를 필수로 받는 구조이므로 null 초기 상태의 UI·검증·제목 생성 영향을 함께 설계한다. 대표 캐릭터가 어느 레이드에도 참가할 수 없더라도 캐릭터 변경은 가능해야 한다. **기존 생성·참가·이번 주 완료 차단을 완화하지 않고**, 선택한 레이드의 후보 재판정과 서버 최종 검증을 유지한다. (4) 기본 대표 캐릭터의 동일 레이드 생성·참가·완료 각각에서 다른 레이드 선택, 단일 캐릭터/다중 캐릭터, 레이드 미선택 저장 거절, 기존 정상 생성, 완료 후 해산 체크 유지, 반복방/주차 전환을 자동·실기기로 검증한다. 이 묶음에서 Rules 변경이 필요하다고 확인되기 전에는 재게시하지 않는다.

- 활성 방 완료, 반복방 완료, 개인 체크 해제, 반복 설정 변경, 수요일 06시 주차 전환, 활성/완료 후 해산을 검증한다. 파티 전체 완료 취소 버튼·명령이 노출되지 않고 서버에서도 거절되는지를 포함한다.
- 모집과 최대 8개 `raidState`가 전부 반영되거나 전부 미반영되는지 확인한다.
- 수동 주간 Claim과 파티 `raidState` 충돌, 종료 하위 문서의 비활성 처리와 내 계정 체크 표시를 함께 확인한다.

완료 조건: 1·2·4·8인 자동 계약과 3계정 이하 대표 실기기 시나리오가 통과한다.

#### F6 후속 실행 순서 — B1 표적 복구 확인, B2 상세 설계 대기 (2026-09-18)

두 결함을 하나의 권한 패치로 합치지 않는다. 현재 실기기에서 성공한 방 생성·신청 거절·정상 캐릭터 승인·자리 변경·추방·활성 해산은 매 단계 회귀 보호한다. 정확한 ID·시각·데이터 근거는 `BUG_REPORTS.md`의 2026-09-18 항목에만 둔다.

1. **F6-A — 첫 실패 지점 확인: 완료.** `니티야`의 4막 승인 실패는 삭제된 모집 원본을 가리키는 기존 `active raidState`와 부합한다. 같은 방장·신청자 Player의 다른 Character 승인은 실기기에서 성공했다. `이슈아이`의 모든 수동 완료 체크 실패는 별개로, 해산된 그룹 전용방의 잔존 pending 신청 부모를 `_loadConflictContext`가 읽다가 `permission-denied` 되는 지점까지 확인했다. 그룹은 `softDeleted`/멤버 0명이다. 두 서버 상태 모두 현재 보존하며 수동 정리하지 않는다. 원인 확인용 임시 단계 로그는 B1 검증 후 제거했다.
   - 참고: [`BUG_REPORTS.md`](BUG_REPORTS.md) 2026-09-18 원인별 데이터 근거, [`DEV_LOG.md`](DEV_LOG.md) F6-A 진단 이력.
2. **F6-B1 — 수동 체크 장애의 최소 복구: 완료.** 접근 불가·종료된 방의 pending 신청이 다른 레이드의 수동 완료를 막지 않도록 신청 이력 조회/분류만 수정한다. 부모 모집 `get`이 `permission-denied`인 신청은 현재 수동 완료 명령에서 조작 가능한 대상으로 간주하지 않고 **그 신청만 건너뛴다**. 다른 Firebase 오류·정상적으로 읽히는 현재 주차 신청은 건너뛰지 않는다. 접근 가능한 같은 레이드 pending 신청의 영향 안내·기존 철회/정리 흐름은 유지한다. 건너뛴 신청을 서버에서 자동 삭제·거절·철회하지 않으며, 이후 승인 시 Claim 존재를 Rules가 최종 거부한다. Rules와 서버 데이터는 변경하지 않았다.
   - 완료 근거: 부모 모집 읽기의 `permission-denied`만 해당 신청을 제외하는 최소 변경과 표적 테스트 8건·변경 파일 분석 통과. 사용자가 `이슈아이` 수동 체크·해제, 완료 상태에서 동일 레이드 모집 캐릭터 선택 차단, 정상 pending 신청 1건 안내 및 실제 취소를 확인했다. 다른 Firebase 오류 전파는 자동 테스트, Claim 존재 시 승인 거절은 기존 Rules Emulator 계약으로 보호한다. 임시 단계 로그는 제거했다. 주차 전환과 새 `raidState` 통합은 B2/F7 범위이며 B1 완료를 F6 전체 완료로 확장하지 않는다.
   - 참고: [`WEEKLY_RAID_CLAIM_CONTRACT.md`](../architecture/WEEKLY_RAID_CLAIM_CONTRACT.md) §3·§5·§6, [`BUG_REPORTS.md`](BUG_REPORTS.md) 2026-09-18, [`DEV_LOG.md`](DEV_LOG.md) F6-A/B1 기록, `tools/party_group_cutover_rules_test.mjs`의 Claim 존재 시 승인 거절 계약.
   - 적용 경계: `FirestoreWeeklyRaidClaimRepository._loadConflictContext`의 pending 신청별 `recruitmentRef.get()`만 좁게 처리했다. 조회 쿼리·Character/주차 필터와 `createManualClaim` Transaction의 정상 대상 쓰기 집합은 그대로 두고, 사전 영향 확인(`inspectManualClaimImpact`)과 실제 체크(`createManualClaim`)가 같은 분류 함수를 계속 사용한다.
   - 검증 경계: 접근 불가 부모의 예외가 **그 신청 하나만** 제외되고 `unavailable` 등 다른 예외는 기존 실패로 남는 것을 신규 테스트로 고정했다. 읽을 수 있는 동일 레이드 신청의 안내·취소는 실기기에서 확인했다. Claim 이후 승인은 기존 Rules의 `hasWeeklyRaidClaimAfter` 계약이 최종 거부한다. 새 `raidState` 점유와 완료 표시의 통합은 B2로 분리한다.
3. **F6-B2 — 주간 상태/체크 표시 통합: B2-A 중간 상태 회귀 확인, 완료 UX 복구 우선.** 수동 `weeklyRaidClaims`와 파티 `raidState`가 생성·신청 후보, 수동 체크/해제, 완료방 해산 후 내 계정 표시에서 일관되게 해석되도록 계약을 설계한다. 기존 활성 참가 시 탈퇴·승계·pending 신청 안내, `source: manual/party`, 다른 난이도의 같은 `raidId`, 수요일 06시를 보존한다. 파티 전체 완료 취소는 제거하고 새 파티 명령에 구 Claim 복제 쓰기를 추가하지 않는다. **내 계정 수동 체크의 참가 중 영향 확인·탈퇴와 모집 상세의 파티 전체 완료는 서로 다른 명령**이지만, 사용자에게 제공하는 완료 사이클은 아래 F6-B2-R의 하나의 인수 단위로 검증한다.
   - 참고: [`WEEKLY_RAID_CLAIM_CONTRACT.md`](../architecture/WEEKLY_RAID_CLAIM_CONTRACT.md) §3.2·§5.3·§5.4·§6·§11·§12, [`FIRESTORE_PARTY_COMMAND_CONTRACT.md`](../architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md), [`BUG_REPORTS.md`](BUG_REPORTS.md) 완료방 해산 체크 누락 기록.
   - 확인된 실제 간극: 운영 Router의 파티 완료는 `PartyAtomicCycleCommandAdapter → FirestorePartyAtomicCommandRepository`로 연결되어 최대 8명의 `raidState`를 `active → completed`로 바꾼다. 반면 내 계정 표시·수동 체크는 `FirestoreWeeklyRaidClaimRepository`의 구 `weeklyRaidClaims/activeRaidAssignments`만 사용한다. 따라서 완료방 해산 후 체크 누락과 활성 `raidState`가 있어도 수동 체크 가능한 현상은 같은 전환 미완료에서 발생한다. 구 `FirestorePartyCycleCommandRepository`의 Claim 쓰기를 운영 기준으로 되살리지 않는다.

   **B2-A — 현재 주차 읽기 Projection**

   1. 본인 `raidStates`를 읽는 Repository/Mapper를 만들고 내 계정·모집 후보가 동일한 **주간 상태 Projection**을 사용하게 한다. active state를 완료 전용 `WeeklyRaidClaim`으로 변환하지 않고 `none/active/completed/legacyActive/legacyCompleted/inconsistent`를 명시한다. Rules는 현재 Player의 자기 하위 list만 열고 타인 list를 계속 거절한다. 현재 주차 제한은 Repository 쿼리와 Projection의 `cycleKey` 검증으로 강제한다.
   2. `completed state → 완료`, `active state → 참가 중`, state 없음 + 구 Claim → 호환 완료, state 없음 + 구 assignment → 호환 참가 순으로 합친다. 현재 주차 state와 legacy 문서가 동시에 있으면 내용이 같아 보여도 `inconsistent`로 반환한다. 한쪽 해제 뒤 다른 기록이 다시 체크·점유로 나타나는 회귀를 막기 위해 자동 병합·부분 삭제하지 않는다.
   3. 문서 ID에 주차가 없으므로 모든 판정에서 state의 `cycleKey`를 검증한다. 완료방 해산이 현재 주차 completed state를 보존한 뒤 내 계정 체크가 유지되고, 이전 주차 state는 현재 체크·참가 제한에 영향을 주지 않는 것을 고정한다.
   4. Projection은 저장 원장 해석만 공유한다. 모집 생성·신청 후보의 active 상태는 기존 `FirestoreActiveRaidAssignmentLookup`/`PartyCreateOccupancyGate`가 수행하는 연결 모집 종료·만료·고아 판정을 보존하고, 내 계정은 탈퇴·승계·단독 해산 영향 계산을 별도로 유지한다. 공통 타입 도입을 이유로 두 UX의 정책을 하나의 boolean으로 축약하지 않는다.
   5. 구현은 `Projection 타입·순수 병합 테스트 → 본인 list Rules 계약 → Repository 읽기 → 내 계정 표시 연결 → 모집 후보 연결 및 기존 점유 게이트 회귀` 순서로 나눠 각 단계 diff를 검토한다.

   **B2-A 구현 상태 정정(2026-09-19):** 읽기 Projection·Rules·Router 연결과 자동 검증은 완료했지만, 대응 쓰기 명령 없이 `raidState` 체크박스를 읽기 전용으로 노출한 것은 기존 해제 UX를 깨뜨린 회귀다. 사용자의 운영 게시·실기기 확인에서 이 문제가 드러났으므로 B2-A를 독립 완료 또는 게시 가능한 단계로 취급하지 않는다. 기존 `canToggle` 차단 테스트는 제품 계약이 아니라 제거·대체해야 할 회귀 근거다.

   **F6-B2-R — 완료 UX 복구: 현재 최우선 작업 구간**

   하나의 사용자 흐름은 `파티 전체 완료 → 완료 기록 → 완료방 해산 → 내 계정 체크 유지 → 본인 체크 해제 → 동일 레이드 재참가 가능`이다. 내부 코드는 아래처럼 나누되 전체 흐름이 통과하기 전에는 어느 중간 구간도 운영 완료로 판정하지 않는다.

   1. **R1 전체 완료 권한 경계:** 현재 앱 Repository가 `complete/advanceCycle`에서 모든 대상의 private `raidState`를 직접 읽는 구조를 제거한다. 당시 함께 수정된 `cancelCompletion` 경로는 제품 폐기 대상이며 R1의 완료·주차 전환 개선은 그대로 유지한다. 모집 Aggregate의 고정 대상과 Rules의 각 update·`getAfter` 검증으로 1·2·4·8인의 상태가 전부 반영되거나 전부 거절되게 한다. 해산에서 이미 적용한 타인 private read 제거 원칙을 완료 명령에도 맞추되, 대상 누락·추가·stale revision·비공대장은 계속 거절한다. 각 state 쓰기마다 전체 대상을 다시 검사하는 `8×8` Rules 평가나 인원수 비례 이벤트 복제는 도입하지 않는다.
      - **로컬 구현 완료(2026-09-19):** 원자 lifecycle Repository에서 대상 `raidState`의 `transaction.get()`과 클라이언트 문서 사전 판정을 제거했다. 인증 binding·모집 Aggregate·필요 시 그룹 원본만 읽으며, 모집 대상 일치와 각 state 전이는 기존 Write Plan·Rules가 검증한다. Repository·Write Plan·lifecycle Rules·확장성 계약 표적 테스트 25건과 변경 파일 분석이 통과했다. Rules·이벤트 형식·운영 Firebase는 변경하지 않았다. 실제 인증 클라이언트의 공개·그룹 1·2·4·8인 실행은 R4 완료 게이트로 남긴다.
   2. **R2 공용 완료 이벤트와 기록:** Player별 이벤트 fan-out은 되살리지 않는다. 공용 이벤트 한 건에 공통 `raidId/difficultyId/cycleKey`와 최대 8명의 `playerId/characterId` 완료 대상 Snapshot을 넣고, 수신자는 자기 대상을 선택해 완료 기록을 생성한다. Rules allowlist·대상 일치·최대 8명·이벤트 재전송 거절을 검증한다. 필드 누락을 조용히 성공 처리하는 기존 sync 테스트를 완료 기록 생성/누락 거절 테스트로 보강한다.
      - **완료(2026-09-19):** lifecycle 이벤트 schemaVersion 2의 완료 이벤트에 공통 레이드 정보와 `completionTargets`를 기록한다. 당시 구현한 완료 취소 이벤트 생성 분기는 제거 대상이며 과거 이벤트 읽기만 유지한다. Rules는 모집 `partySlots`와 audience·대상 배열을 최대 8개까지 같은 순서로 검증하고 문서 추가 조회는 하지 않는다. 기존 schemaVersion 1은 구 앱 호환 create만 유지한다. Event Mapper가 현재 Player의 Character를 선택하고 sync가 그 값을 Drift 완료 기록에 사용한다. 관련 Flutter 표적 63건, 변경 파일 분석, JS 문법과 diff 검사가 통과했다. 로컬 demo Emulator는 기존과 같은 Rules 로딩 503으로 중단됐지만 작업 브랜치 GitHub Actions `35417265039`에서 1·2·4·8인 lifecycle, 완료 대상 누락·Character 위조 거절을 포함한 격리 Rules 검증이 통과했다. 운영 Rules는 게시하지 않았고 실제 앱 전체 사이클은 R4에 남긴다.
   3. **R3 완료 조작 UX 복구:** 먼저 모집 상세의 `전체 완료 취소` 버튼과 신규 호출 경로를 제거하고, Domain/Adapter/Write Plan/Rules의 `cancelCompletion` 허용 분기를 폐쇄한다. 과거 `completionCancelled` 이벤트·Drift 기록의 읽기 Mapper는 호환용으로 유지한다. 이어서 `active`는 미체크와 오른쪽 참가 안내 아이콘을 함께 표시하고 체크박스 선택은 영향 확인 후 B2-C 개인 완료 명령으로 연결한다. `completed`는 체크와 완료 안내 아이콘을 함께 표시하고 본인이 해제할 수 있게 B2-B/D 자기 state 삭제 명령으로 연결한다. 안내 아이콘은 조작을 설명할 뿐 체크박스를 비활성화하는 조건이 아니다. `inconsistent`도 일괄 차단하지 않는다. 본인·Character·raidId·현재 cycle이 검증된 완료 근거가 있으면 체크 표시와 해제 경로를 제공하고, 완료 근거만 제한적으로 정리하며 active 참가 근거는 보존한다. 소유권이나 식별자가 검증되지 않는 손상 데이터만 임의 변경 없이 구체적인 복구 안내로 보낸다.

      **R3 과거 중단·재개 이력(2026-09-19, 현재 완료)**

      - 브랜치는 `feature/party-group-command-redesign`, 최신 커밋은 `b5769bf fix: bound personal completion rule evaluation`이다. 로컬·`origin/feature/party-group-command-redesign`은 같은 커밋이고 작업 트리는 깨끗하다. R3 변경은 `dev/main`에 반영되지 않았으며 운영 Rules도 게시하지 않았다.
      - R3 복구 구현은 `dfe0440`, 개인 완료 Rules 우선순위 조정은 `e660c4c`, 개인 완료 명령 표식과 마지막 1인 전용 Rules 경량화는 `b5769bf`에 각각 추적·푸시됐다. 과거 미커밋 초안을 다시 찾거나 되살리지 말고 이 커밋부터 이어간다.
      - `b5769bf`는 기존 Aggregate의 `lastCommand*`에 `personalComplete` 명령 표식을 기록한다. 마지막 1인 모집 갱신과 membership 삭제는 이 표식을 사용하는 전용 검증 경로로 분리했으며 새 문서, Player별 이벤트 fan-out, 타인 private state 선읽기는 추가하지 않았다.
      - GitHub Actions `35443055507`에서 Rules 컴파일, 개인 수동 완료·해제, 개인 해제로 빠진 반복방 state의 다음 주차 재생성, 공개방 마지막 1인 완료·해산, 그룹방 마지막 1인 완료·listing/활성 수 정리까지 통과했다.
      - `b5769bf` CI는 다인방 검증 준비 중 가입자의 `applicationTxn(..., 'apply')`에서 application create·recruitment update·party event create가 함께 평가되며 `maximum of 1000 expressions`에 도달했다. 원인은 모든 모집 update가 무거운 개인 완료 상세 검증을 먼저 평가한 것이며, 단순 OR 순서 변경으로 해결하지 않았다.
      - 후속 커밋 `4abdb89 fix: gate personal completion rule evaluation`에서 `lastCommandType == personalComplete`, actor와 단일 target을 확인하는 값싼 `personalCompletionCommandMarker`를 모집 update의 선행 게이트로 추가했다. 표식이 맞을 때만 개인 완료 상세 검증을 호출하며 정상 신청·승인·가입·자리 변경·추방·해산의 기존 검증은 완화하지 않았다.
      - GitHub Actions `35448981992`가 전체 통과했다. Rules 컴파일, 정상 신청·철회·재신청·승인, 일반 멤버 개인 완료, 파티장 개인 완료 후 승계, 위조 후임 Snapshot 거절, 마지막 1인·그룹 마지막 1인 완료, 자리 변경·추방·재가입, 2·4·8인 해산, 그룹 생성·가입·승계·탈퇴·해산 회귀를 확인했다.
      - 당시 R3 코드·Rules 자동 검증은 완료했고 SHA-256 `11593015457B155BCE11FEC2D185DEB039D49F62F1C10C70DFEC24012EDA5857`의 추적 Rules 게시 시도는 원격 컴파일 `/test`의 HTTP 503으로 실패했다. 이후 사용자가 Rules를 별도로 게시하고 정상 데이터의 R4 실기기 흐름을 확인했으므로 이 항목은 현재 재개 지시가 아니라 장애 이력이다.

      **R3 재개 순서**

      1. 현재 미커밋 diff와 신규 파일을 보존한 채 R3 계약별 변경표를 다시 만들고, 위 확정 승계 Rules 결함을 먼저 수정한다.
      2. B2-B/C/D의 Write Plan·Repository·Router/DI·Projection·Rules가 같은 식별자와 원자 경계를 쓰는지 대조한다. 반복방 다음 주차와 legacy/불일치 경계가 초안에 실제 구현됐는지도 코드 근거로 판정하고 누락만 보완한다.
      3. 코드 포맷, JS 문법, `git diff --check` 후 개인 수동 체크/해제, 일반 멤버·파티장·마지막 1인 완료, 그룹 전용방, 완료 취소 미노출·서버 거절의 표적 Flutter/Rules 계약 테스트를 실행한다.
      4. 변경 범위가 Router·공용 Domain·Rules에 걸치므로 변경 파일 분석과 전체 `flutter analyze`, 전체 `flutter test`를 최종 상태에서 한 번 실행한다. 실패는 이번 변경 회귀와 기존 결함을 근거로 분리해 기록한다.
      5. 로컬 Emulator 503이 계속되면 같은 실패를 반복하지 않고, 검증 가능한 커밋을 작업 브랜치에 남긴 뒤 기존 demo Rules CI로 1·2·4·8인 및 거부 사례를 확인한다. CI 전이나 실패 상태에서는 운영 Rules를 게시하지 않는다.
      6. 자동 검증과 문서 기록이 끝난 후에만 R3 코드·Rules·테스트를 한 검증 단위로 커밋·작업 브랜치 푸시한다. 사용자는 그 뒤 R4 체크리스트로 실기기를 수동 확인한다. 실기기 설치·조작은 에이전트가 수행하지 않는다.

      **R3 구현 상태(2026-09-20): 코드·Rules·정상 데이터 실기기 검증 완료.** 파티장 개인 완료의 후임 membership·리더 Snapshot 검증을 보완했다. 파티 밖 수동 `raidState` 완료·해제, 활성 참가자의 탈퇴/승계/마지막 1인 해산과 완료 원자 전환, 그룹 listing·활성 수 정리, 완료 기반 생성·신청·승인 차단을 같은 계약으로 연결했다. 개인 완료 이벤트는 일반 탈퇴와 구분하도록 `reason=weeklyRaidCompleted`를 기록하되 공용 이벤트 한 건 원칙을 유지한다. 반복방은 개인이 이전 완료 state를 지웠더라도 현재 `partySlots`를 근거로 다음 주차 active state를 upsert하며, 현재 시간은 새 주차 시작 이상·종료 미만이어야 한다. 새 주차 수동 완료나 다른 모집 state는 Rules가 덮어쓰기를 거절한다. 삭제된 모집을 참조하는 기존 고아 state는 R3 정상 흐름이 아니라 F6-D 복구 대상으로 분리한다.

      파티 전체 완료 취소의 신규 UI·Domain·Adapter·Write Plan·Rules 실행 경로는 제거했고 과거 이벤트 읽기만 유지했다. 개인 완료·해제 및 lifecycle 표적 Flutter/정적 Rules 계약은 통과했으며 핵심 변경 13개 파일 분석은 0건이다. 전체 분석은 기존 파일을 포함한 50건, 전체 테스트는 계약 테스트 갱신 전 실행 기준 1,183건 통과·13건 실패였다. 이번 작업의 낡은 legacy assignment 문자열 기대는 현재 제한적 자기 정리 계약으로 갱신해 단독 통과했으며, 기존 활동 Character Rules 문자열·Firebase 기본 앱 미초기화 위젯 등 기준선 실패를 전체 성공으로 숨기지 않는다. 로컬 Emulator는 Android Studio JBR 21로 기동했으나 Rules 로딩 단계의 기존 HTTP 503으로 실행되지 않았다. demo CI `35448981992`에서 추적 Rules 전체 회귀가 통과했지만 운영 게시와 실기기 수동 검증 전에는 B2 전체 완료로 판정하지 않는다.

   4. **R4 한 사이클 검증: 정상 데이터 흐름 완료, 고아 상태는 F6-D로 분리.** 현재 자동 검증에서 확인한 정상 흐름을 인원수별로 다시 반복하지 않는다. Rules 접근·표현식 예산의 인원 확장 검증은 최대치 8인 대표 사례 하나를 기준으로 하고, 마지막 1인 해산·책임자 승계·권한/위조 거절처럼 상태 전이가 다른 최소 사례만 별도로 유지한다. 사용자는 디바이스 2기로 `완료 → 완료방 해산 → 내 계정 체크 유지 → 본인 체크 해제 → 재참가 가능`과 개인 완료·승계 대표 흐름을 수동 확인했다. 반복방은 공동 완료 취소 없이 다음 주차에 현재 membership으로 새 active 상태를 구성해야 한다. 다만 삭제된 모집을 참조하는 기존 `active raidState` 한 건은 참가 표시·수동 완료·신청 승인 불일치를 일으켰으며 정상 R4 회귀가 아니라 F6-D 고아 복구 대상으로 확정했다.

   **회귀 보호:** 기존 1인 완료, 자리 이동·교환, 추방·재가입, 활성 해산, 그룹 전용 listing/활성 수, 정상 신청 승인, B1 pending 신청 처리와 수요일 06시 주차 경계를 보존한다. Rules가 바뀌면 전체 추적 Rules CI·경고 확인 후 별도 게시 절차를 따르며, 실기기 설치·조작은 사용자가 수행한다.

   **B2-B — 파티 밖 수동 체크·해제**

   1. 신규 수동 완료는 구 Claim 대신 `source: manual`, `status: completed`, `recruitmentId: null`, `revision: 1`인 raidState를 생성한다. 같은 주차 수동 state 체크는 멱등이며 다른 난이도도 같은 `raidId` 키를 공유한다. legacy active assignment가 남아 있으면 이를 덮어쓰지 않고 불일치로 거절한다.
   2. 자기 completed state는 출처와 관계없이 개인 체크 해제할 수 있고, state가 없고 구 Claim만 있으면 기존 Claim 해제를 호환 경로로 유지한다. completed state와 구 Claim이 함께 있으면 한 번의 해제 명령으로 검증된 본인·현재 주차 완료 근거를 함께 제거한다. active state/assignment가 완료 근거와 함께 있으면 완료 근거만 제거하고 참가 근거는 보존한다. 소유권·Character·raidId·cycleKey가 맞지 않는 문서는 임의 삭제하지 않는다.
   3. completed state를 먼저 원자 확정해 이후 승인·즉시 가입·생성·캐릭터 변경을 서버에서 거절한다. 같은 레이드 pending 수는 무제한일 수 있으므로 전부를 핵심 Transaction에 넣지 않고, UI Projection에서 즉시 무효 처리한 뒤 비핵심 정리 경로로 `superseded/weeklyRaidCompleted`를 반영한다. application Rules의 구 Claim 전용 조건을 통합 state 기준으로 정렬하되 신청자 개인 state를 파티장에게 노출하지 않는다.

   **B2-C — 활성 참가 중 개인 완료**

   1. 내 계정에서만 영향 확인 후 `탈퇴하고 완료 처리`를 실행한다. 일반 멤버는 Aggregate/membership/목표 slot 제거와 본인 state 완료 전환, 파티장은 후임 승계, 마지막 1인은 모집 해산과 state 완료 보존을 한 Transaction에서 처리한다. 이때 state는 `source: manual`로 바꾸고 기존 `recruitmentId`를 원인 추적·Rules 검증용으로 보존하며 revision을 증가시킨다.
   2. 기존 `PartyAtomicMemberRemovalWritePlan`의 인원·역할·slot·그룹 listing·승계 계산을 공통 정책으로 재사용하되, 일반 탈퇴의 state 삭제를 그대로 호출한 뒤 별도 완료 쓰기를 덧붙이지 않는다. 개인 완료 전용 Write Plan/Rules 분기로 원자성을 증명한다.
   3. 모집 상세의 `파티 전체 완료`는 기존 lifecycle 명령을 그대로 사용한다. 활성 참가를 발견했다는 이유로 이 명령을 차단하거나 수동 완료 안내를 띄우지 않는다.

   **B2-D — 해제·반복방·호환 경계**

   1. `source: manual/party` 모두 개인 체크 해제는 자기 completed state만 삭제하고 공동 완료 Snapshot은 바꾸지 않는다. 파티 전체 완료 취소 명령·버튼·Rules 허용은 제거하고 과거 `completionCancelled` 이벤트 읽기만 유지한다.
   2. 반복방의 다음 주차 전환은 개인 해제로 이전 state가 없어도 현재 membership을 기준으로 새 주차 active state를 생성할 수 있게 Write Plan과 Rules를 확장한다. 기존 문서는 같은 반복방의 직전 주차 state일 때만 갱신하며, 새 주차 수동 완료나 다른 모집의 active state는 덮어쓰지 않고 명령 전체를 거절한다. 그렇지 않으면 개인 해제가 방을 영구 정지시키거나 반대로 실제 완료·참가를 소실시키므로 완료 조건으로 인정하지 않는다.
   3. 과거 Claim·assignment는 bulk migration 없이 fallback 읽기·해제만 유지한다. 신규 명령이 legacy 원장과 state를 dual-write하지 않는다. 불일치는 진단 상태로 유지하되, 본인 소유와 현재 주차 식별이 증명되는 완료 근거는 체크박스 한 번으로 제한적으로 수렴시킨다. 증명할 수 없는 손상 데이터만 별도 안전 복구 백로그로 보낸다.

   **회귀·완료 기준**

   - 자동: 실기기로 안전하게 확인하기 어려운 Rules 권한·위조 요청·원자성·주차 경계와 최대 8인 표현식 예산만 검증한다. 인원수별 동일 흐름은 8인 대표 사례로 통합하고, 마지막 1인·책임자 승계처럼 상태 전이가 다른 경우만 최소 사례로 둔다. 정상 UI·UX와 pending 0·1·다수 같은 반복 조합은 디바이스 결과와 코드 검토로 확인하며 자동 테스트를 관성적으로 늘리지 않는다.
   - 보존: 기존 방 생성·신청·승인·즉시 가입·캐릭터 변경의 완료 차단, 자리 변경·추방·활성 해산, 그룹 listing/집계, B1의 접근 불가 신청 처리와 정상 pending 취소를 보호한다.
   - 실기기: 사용자가 수동 체크/해제, 참가 중 영향 안내와 탈퇴·승계/단독 해산, 파티 전체 완료 후 체크 유지, 완료 취소 미노출, 반복방 다음 주차 대표 흐름을 확인한다. 에이전트는 설치·조작하지 않는다.
   - Rules가 변경되므로 전체 B2 자동 검증과 경고 확인 전에는 운영 게시하지 않는다. 운영 게시·실기기 확인 전 B2 완료나 `dev/main` 통합으로 표시하지 않는다.

   **페이지·역할별 UX 회귀 보호**

   | 사용자 위치 | 보존할 정상 흐름 | 새 구조에서 막아야 할 회귀 |
   | --- | --- | --- |
   | 내 계정 / 일반 사용자 | 미참가 Character 수동 체크·해제, 완료 시 체크 유지, 완료·해제 후 같은 레이드 흐름 반복 | active 참가를 무시한 중복 완료, 소유권 미확인 legacy 자동 삭제, 과거 cycle 표시, 불일치 분류만으로 개인 해제 차단 |
   | 내 계정 / 참가자 | 영향 안내 확인 후 탈퇴와 개인 완료, 파티장이면 승계, 마지막 1인이면 해산 | 일반 탈퇴로 state를 먼저 삭제한 뒤 완료가 따로 실패하는 부분 저장 |
   | 모집 상세 / 공대장 | 전원 파티 완료, 완료방 해산, 반복방 다음 주차 유지 | 개인 수동 완료의 active 차단을 전원 완료에 적용, 폐기된 완료 취소 버튼·명령 잔존 |
   | 반복방 / 공대장·파티원 | 새 주차 진입 시 완료 체크 초기화와 현재 멤버 active 재구성 | 개인 해제로 state가 빠진 멤버 때문에 전환 전체 실패 |
   | 모집 생성·신청 / 일반 사용자 | completed 비활성, active 참가 안내, pending 복수 신청 | 오래된 pending 정리 수에 비례한 핵심 Transaction, 상태 충돌을 일반 권한 오류로만 표시 |
   | 승인 / 공대장 | 정상 신청 승인, 이미 참가·완료된 신청은 서버 최종 거절 | 타인 private state 조회 허용, 모든 권한 오류를 신청자 문제로 단정, 자동 거절. 전용 게이트를 충족하면 `신청자의 참가 데이터에 오류가 있어 승인할 수 없습니다. 해당 신청을 거절해 주세요.`와 명시적 거절 선택을 제공 |

   B2 구현 중 위 표의 다른 페이지를 편의상 같은 ViewModel 조건으로 묶지 않는다. 특히 내 계정 개인 명령과 모집 상세 공동 명령, 표시 Projection과 서버 최종 권한 검증은 각각 독립 테스트를 둔다.

   **구현 순서:** B2-A Projection 타입·읽기·본인 list Rules → R1 다인 완료 권한 경계 → R2 공용 완료 이벤트 → R3 체크박스 개인 완료·해제 명령 → R4 실제 앱 전체 사이클 검증. B2-A·R1·R2·R3와 정상 데이터 R4를 완료했다. 삭제된 모집을 참조하는 과거 고아 state는 B2 정상 완료 사이클과 구분해 F6-D에서 복구한다.
4. **F6-C — 모집 생성 초기 선택 교착 해소: 완료.** 첫 진입에서 레이드를 자동 선택하지 않고 대표 캐릭터를 탐색 기준으로 둔다. 레이드·난이도 미선택 저장은 차단하되, 기본 4막이 불가능해도 다른 레이드와 Character 변경에 접근 가능해야 한다. null 레이드의 Form/draft/자동 제목·역할 변경/재진입, 단일·다중 Character와 기존 정상 생성을 자동·실기기로 검증한다. 점유·완료·레벨·역할 및 서버 최종 거절은 완화하지 않는다.
   - **착수 전 실제 코드 확인(2026-09-20):** `RecruitmentCreatePage._load`는 첫 active raid/difficulty를 읽은 뒤 대표 Character의 eligible 목록에서 같은 raid 또는 첫 항목을 다시 선택하고, `_raid/_difficulty`와 draft를 즉시 채운다. `RecruitmentForm`도 non-null `selectedRaid/selectedDifficulty`를 요구한다. 따라서 F6-C는 아직 구현되지 않았으며 단순 기본값 제거만으로 끝나지 않는다. Form의 미선택 표현, raid 선택 전 후보·역할 변경, 저장 검증과 자동 제목을 함께 null-safe하게 설계해야 한다.
   - **변경 경계:** 후보의 점유·완료·아이템 레벨·역할 판정과 생성 Repository/Rules는 바꾸지 않는다. 화면 초기 선택과 Form 상태만 수정하고, 사용자가 레이드를 선택한 뒤에는 기존 후보 재조회·난이도 선택·제목 생성·저장 명령을 재사용한다.
   - **최소 완료 기준:** 기본 대표 Character가 첫 레이드를 생성/완료해도 화면 진입 직후 Character와 레이드 선택 UI가 모두 조작 가능해야 한다. 레이드 미선택 저장은 구체적으로 차단하고, 생성 가능한 다른 레이드 선택 또는 다른 Character 변경 후 정상 생성 가능해야 한다. 사용자가 이 UX를 실기기로 확인하며 동일 정상 UI 자동 반복은 하지 않는다.
   - **구현 결과(2026-09-20):** Form의 레이드·난이도를 nullable 미선택 상태로 열고 대표 Character 후보는 특정 레이드 점유·완료 조건을 적용하지 않은 탐색용 조회로 구성한다. 레이드 선택 시에만 기존 후보 재조회와 제한 판정을 실행하고 자동 제목을 생성한다. 미선택 저장 안내, 선택 전 Character 접근, 선택 후 동일 레이드 차단과 기존 생성 저장을 포함한 Widget 19건 및 변경 파일 분석이 통과했다. Repository·Rules·점유/완료 정책은 변경하지 않았다.
   - **실기기 완료 근거(2026-09-21):** 사용자가 첫 진입의 선택 부분이 정상 작동함을 확인하고 기능 완료를 승인했다. 동일 정상 UI 자동 검증은 반복하지 않는다.
   - 참고: [`RAID_CATALOG_DATA.md`](../product/RAID_CATALOG_DATA.md), [`PARTY_PARTICIPATION_RULES.md`](../product/PARTY_PARTICIPATION_RULES.md), [`BUG_REPORTS.md`](BUG_REPORTS.md) 기본 4막 교착 기록.
5. **F6-D — 고아 참가 복구와 신청/승인 경계 보완: 다음 구현 구간.** 기존 `active raidState`가 있어도 신청은 pending으로 접수되고 승인에서 Rules update 거부가 모호한 권한 팝업이 되는 흐름을 아래 순서로 분리한다. 정상 참가·완료 경로와 고아 데이터 정리를 한 조건문으로 합치지 않는다.
   1. **D1 단건 판정:** 내 계정에서 active 상태를 조작할 때 본인 state의 식별자·현재 주차·revision을 검증하고 연결 모집을 단건 조회한다. 모집이 없거나 `PartyCreateOccupancyGate`의 stale 상태이면 `orphanActive`로 반환한다. 실제 활성 모집·멤버면 기존 탈퇴/승계/마지막 1인 해산 후 완료 흐름을 유지한다.
   2. **D2 사용자 복구:** `orphanActive`에는 존재하지 않는 새로고침을 안내하지 않고 `종료되거나 삭제된 파티의 참가 기록이 남아 있습니다.`와 `참가 기록 정리`를 제공한다. 명시적 확인 뒤 본인의 orphan `raidState`만 삭제하며, 같은 키의 legacy assignment가 있으면 동일 식별자·cycle·recruitmentId가 검증될 때만 함께 원자 삭제한다. 완료 state·Claim·다른 레이드·Character·신청은 변경하지 않는다. 정리 후 실시간 Projection이 `none`이 되면 사용자가 수동 완료 여부를 다시 선택한다.
   3. **D3 Rules 경계:** 현재 Rules의 `validAtomicStaleRaidStateDelete`가 모집 원본 부재와 종료·완료·만료 상태에 한해 본인 active party state 삭제를 허용하는 계약을 재사용한다. legacy assignment 동시 삭제가 필요할 때만 같은 고아 조건의 좁은 delete OR를 추가한다. 활성 모집, 타 Player, 식별자·recruitmentId 위조, completed state 삭제는 이 명령으로 거절한다. 목록 N+1 조회·서버 후처리·Player별 이벤트 fan-out은 추가하지 않는다.
   4. **D4 이전 주차 고아 확장:** `inspectManualClaimImpact`의 cycle 불일치 즉시 실패를 base identity 검증과 수명 판정으로 분리한다. 이전 주차 active + 모집 없음/종료/완료/만료 비반복방은 `historicalOrphanActive`로 반환하되 현재 Projection의 느낌표는 만들지 않는다. 정리 명령에는 현재 주차가 아니라 관찰한 state cycleKey·revision·recruitmentId를 전달한다. 이 exact-state 분류를 완료 체크뿐 아니라 같은 고정 경로를 쓰는 모집 생성·신청·즉시 가입의 공통 판정으로 재사용한다. 정상 활성 반복방은 승계/참가 충돌로 유지하고, 이전 주차 completed는 고아 정리와 분리된 정상 rollover 경로로 보존한다.
   5. **D5 신청자 사전 차단:** 후보 목록의 현재 주차 표시를 N+1 부모 조회로 확장하지 않는다. 신청·재신청·즉시 가입 Transaction이 본인 exact `raidState`를 읽고 `PartyCreateOccupancyGate`와 같은 수명 판정을 사용한다. 정상 active는 `동일 레이드 참가 중`, 현재/이전 주차 active 고아는 `참가 기록 정리 필요`, 현재 completed는 `이번 주 완료`로 저장 전에 반환한다. 고아는 자동 삭제·자동 재신청하지 않는다. 이전 주차 completed만 정상 rollover 정책으로 안전하게 제거/교체한 뒤 진행하며 active 고아와 같은 분기로 합치지 않는다. Rules의 application create/reapply에도 최종 `raidState` 부재 조건을 추가해 앱 선검사 뒤 경쟁을 차단한다.
   6. **D6 승인자 안내와 명시적 거절:** 승인자는 타인의 private `raidState`를 읽거나 정리하지 않는다. 과거 pending 또는 신청 뒤 상태 변경으로 승인 Rules가 거절되고, 화면상 pending·승인 권한·revision 전제가 유지되는 경우 `신청자의 참가 데이터에 오류가 있어 승인할 수 없습니다. 해당 신청을 거절해 주세요.` 대화상자와 `닫기`/`신청 거절`을 제공한다. `신청 거절`은 기존 bounded reject Transaction만 재사용하며 자동 거절은 금지한다. 일반 인증·Rules 게시본 불일치 가능성이 있는 모든 permission 오류를 데이터 오류로 확정하지 않도록 적용 조건을 승인 경로의 보존된 전제로 제한한다.
      - **전용 안내 게이트:** 승인 명령 자체가 `permissionDenied`로 끝났고, 실패 직후 모집과 신청 목록이 모두 서버 Snapshot이며 같은 `recruitmentId`·모집 revision을 유지하고 대상 신청도 같은 application revision의 `pending`이고 현재 사용자의 승인 가능 상태가 유지될 때만 전용 대화상자를 연다. 신청 목록 Snapshot의 캐시 여부를 화면 상태에 보존해 오프라인 캐시를 최신 pending으로 오인하지 않는다. 하나라도 달라졌으면 상태 변경 또는 기존 일반 실패 안내로 끝내고 거절 동작을 제안하지 않는다.
      - **명시적 거절:** `닫기`는 아무 데이터도 바꾸지 않는다. `신청 거절`은 대화상자에 사용한 동일 모집·신청 revision으로 기존 `reject` 명령을 한 번 호출한다. 그 사이 상태가 바뀌면 기존 `revisionConflict`·`applicationNotPending`·권한 실패를 그대로 표시하고 신청을 임의 변경하지 않는다.
      - **변경 경계:** `PartyJoinFailure`와 승인·거절 Repository, Firestore Rules, applicant private state 읽기, 신청 데이터 스키마는 변경하지 않는다. 상세 화면에 신청 목록 Snapshot의 캐시 여부를 보존하고 승인 실패 분기와 대화상자를 연결하는 범위만 수정한다. 즉시 가입의 `permissionDenied`, 정상 승인·일반 거절·네트워크 실패는 기존 문구와 흐름을 유지한다.
      - **회귀 보호:** 정상 승인 성공, 기존 거절 성공, 전용 안내에서 닫기, 전용 안내에서 거절 성공, 대화상자 이후 revision 변경으로 거절 실패, 게이트를 충족하지 않는 일반 `permissionDenied`를 구분한다. 동일 UI를 실기기와 자동으로 반복하지 않고 위 분기만 표적 Widget 테스트로 검증한 뒤 사용자가 과거 pending 대표 1건을 수동 확인한다.
   7. **D7 최소 검증:** Rules는 모집 원본 없음인 본인 orphan state 정리 성공, 활성 모집·타인·위조·completed 거절, legacy assignment 동시 정리와 raidState 잔존 신청 거절만 자동 검증한다. 실기기는 현재 주차 고아 1건, 이전 주차 고아 1건, 정상 active/반복방 대표 1건만 확인한다. 신청자에서는 `신청 차단 → 정리 → 재신청`, 방장에서는 과거 pending 승인 실패 안내 → 명시적 거절을 확인한다. 이전 주차 completed는 오류 안내 없이 현재 주차 완료·생성·신청이 가능해야 한다. 기존 방 생성·신청·승인·즉시 가입·자리 변경·추방·해산·완료/해제 및 그룹 흐름을 회귀 보호한다.

   **D1~D3 구현 상태(2026-09-20): 코드·자동 검증 및 현재 주차 단건 복구 실기기 확인 완료.** 내 계정의 수동 완료 영향 확인이 연결 모집 없음 또는 종료·완료·만료 상태를 단건 판정해 `orphanedParticipation`으로 분리하고, 별도 확인창의 `참가 기록 정리` 명령이 관찰한 Player·Character·raid·cycle·recruitmentId·revision을 Transaction에서 다시 검증한다. 성공 시 본인 active party `raidState`와 동일한 구 assignment만 원자 삭제하며 완료 기록·신청·다른 상태는 변경하지 않는다. Rules는 기존 stale state 삭제 계약을 재사용하고 구 assignment에 같은 본인·고아 조건의 delete만 추가했다. 정상 활성 모집과 타인 정리는 거절하는 demo 대표 시나리오를 추가했으며, JS 문법·변경 파일 정적 분석·표적 Flutter 9건과 작업 브랜치 demo Rules Emulator Actions `35454451057`이 통과했다. 사용자가 Rules를 콘솔에서 게시하고 현재 주차 고아의 느낌표·명시적 정리·실제 삭제를 확인했다. 운영 활성 소스 해시는 AI가 독립 대조하지 않았다. 이후 발견된 이전 주차 고아와 신청 최종 차단은 D4·D5에서 구현·검증했다.

   **D4 구현 상태(2026-09-20): 코드·표적 자동 검증 및 이전 주차 고아 실기기 확인 완료.** 고정 `raidState`의 수명 판정을 공용 `PartyCreateOccupancyGate.classifyExistingRaidState`로 분리해 현재/이전 주차 active 고아, 유효 참가 충돌, 현재/이전 주차 completed를 구별한다. 내 계정 완료 사전 확인은 이전 주차 active가 모집 없음·종료·완료·만료 1회성일 때만 현재 느낌표 없이 `지난 주차의 종료된 파티 참가 기록` 정리를 안내하며, 정리 명령에는 관찰한 state cycleKey·revision·recruitmentId를 전달한다. 유효 반복방은 정리하지 않는다. 이전 주차 completed는 고아 정리로 보내지 않고 수동 완료 및 모집 생성에서 기존 completed 문서를 본인 delete 계약으로 정리한 뒤 현재 주차 쓰기를 재시도한다. Rules는 변경하지 않았고 운영 배포도 하지 않았다. 공용 분류·기존 점유·ViewModel 표적 테스트 21건과 변경 파일 분석이 통과했고, 사용자가 과거 고아 완료 데이터 정리가 정상 작동함을 확인했다.

   **D5 착수 설계(2026-09-20): 구현 전 연결점 확인 완료.** 운영 Router는 모집 상세의 신청·재신청을 `FirestorePartyAtomicApplicationCommandRepository`, 즉시 가입을 `FirestorePartyAtomicJoinCommandRepository`에 직접 연결한다. 구 `RecruitmentCommandService`나 레거시 신청 Repository는 수정 대상이 아니다. 다음 구현은 아래 경계만 한 검증 단위로 다룬다.

   1. 신청·재신청과 본인 즉시 가입 Transaction에서 정확한 `characterId + raidId` state를 읽고, active일 때 참조 모집 한 건만 추가 조회해 D4의 공용 수명 판정을 호출한다. 정상 active/유효 반복방은 참가 충돌, current completed는 주간 완료, current·historical orphan active는 정리 필요로 구분한다. 후보 목록 전체의 부모 모집 N+1 조회나 승인자의 타인 state 읽기는 추가하지 않는다.
   2. orphan 결과에는 관찰한 Character·raid·cycle·recruitmentId·revision을 함께 반환한다. 모집 상세는 기존 `WeeklyRaidClaimCommandRepository.cleanupOrphanParticipation`을 주입받아 `참가 기록 정리`를 명시적으로 선택할 수 있게 하며, 성공 후 신청·즉시 가입을 자동 재실행하지 않는다. 현재 주차 후보의 기존 참가/불일치 표시는 완화하지 않고, 현재 목록에 나타나지 않는 이전 주차 고아도 버튼 실행 시 같은 복구 UX로 수렴시킨다.
   3. historical completed는 create와 같은 최대 2회 bounded Transaction으로 기존 completed state만 먼저 삭제하고 모든 조건을 다시 읽어 원래 명령을 실행한다. active orphan 자동 삭제, 자동 신청, 신청 문서 수정은 하지 않는다.
   4. application create/reapply Rules는 최종 상태에서 해당 applicant의 exact `raidState`가 존재하지 않아야 한다. 기존 completed Claim/state 검사와 병행하되 정상 신청·철회·재신청의 현재 조건, 그룹 분류와 표현식 예산을 완화하지 않는다. direct join은 기존 raidState create 계약이 점유 경쟁을 최종 거절하는지 계약 테스트로 고정하고 불필요한 중복 Rules 조회를 추가하지 않는다.
   5. D5 자동 검증은 공용 수명 분기와 Rules의 `state 잔존 신청 거절/정리 후 신청 성공` 대표 사례만 추가한다. 신청·재신청·즉시 가입의 정상 UI는 동일 결과 자동 테스트를 반복하지 않고 구현 종료 뒤 사용자가 디바이스 2기로 `차단 → 명시적 정리 → 다시 신청/가입`을 확인한다. 승인 실패 안내·명시적 거절은 D6 범위로 남긴다.

   **D5 구현 상태(2026-09-20): 코드·Rules·자동 검증 완료, 신청 실기기 확인 완료.** 신청·재신청과 본인 즉시 가입은 exact state와 연결 모집 한 건을 공용 수명 판정으로 분류한다. 정상 active/유효 반복방은 참가 충돌, current completed는 주간 완료, current·historical orphan active는 관찰 식별자를 포함한 정리 필요 결과로 반환한다. 모집 상세는 기존 단건 정리 Repository를 재사용해 사용자가 `참가 기록 정리`를 명시적으로 선택하게 하며 성공 뒤 원래 신청·가입을 자동 재실행하지 않는다. historical completed는 최대 2회 Transaction 중 첫 회에서 기존 state만 삭제하고 두 번째 회에서 모든 조건을 다시 읽어 신청·즉시 가입을 수행한다. application create/reapply Rules는 최종 exact state 부재와 legacy Claim 부재를 함께 요구한다. 승인자의 타인 state 읽기와 D6 안내는 변경하지 않았다. 표적 Rules/수명 판정 13건, 모집 상세 46건, 변경 파일 정적 분석과 JS 문법·diff 검사가 통과했고 demo 전체 Rules Actions `35494192803`도 통과했다. 추적 Rules SHA-256은 `9228699FEB79F2F41AC782B8E4F98FF6AEE1F94248354B954CEF503AB2B65B0C`다. CLI 게시 1회는 원격 컴파일 `/test`의 HTTP 503으로 실패했으나, 이후 사용자가 콘솔에서 Rules를 직접 게시했다고 확인했다. AI가 운영 활성 소스 해시를 독립 대조하지는 않았다. 사용자 실기기에서는 현재 주차 고아의 느낌표·정리와 이전 주차 고아의 신청 시 안내·명시적 정리·실제 state 삭제가 모두 확인됐다. 정리 성공 뒤 신청은 자동 실행되지 않으며 사용자가 다시 신청한다. 본인 즉시 가입의 같은 UX는 아직 별도 실기기 확인 전이다.

   **D6 구현 상태(2026-09-20): 통과.** 승인 `permissionDenied` 뒤에도 모집 상세와 신청 목록이 모두 서버 Snapshot이고, 같은 모집·신청 revision의 pending 및 현재 승인 권한이 유지될 때만 전용 안내를 연다. `닫기`는 쓰지 않고 `신청 거절`은 대화상자에 사용한 revision으로 기존 reject 명령만 호출한다. 신청 목록 캐시 여부를 화면 상태에 보존해 캐시·상태 변경·일반 권한 실패에는 기존 안내를 유지한다. `PartyJoinFailure`, 승인·거절 Repository, Rules, 스키마와 타인 private state 읽기는 변경하지 않았다. 모집 상세 Widget 테스트 49건과 변경 파일 정적 분석이 통과했고 정상 재신청·승인도 실기기에서 확인했다. 정상 흐름은 신청 전에 고아를 정리하므로 전용 대화상자를 실기기에서 재현하려면 pending 생성 뒤 콘솔로 고아를 인위 생성해야 한다. 사용자는 이 조작 테스트를 생략하고 방어 경로 자동 검증을 근거로 D6를 통과 처리했다. 향후 실제 제보에서 승인 실패 뒤 이 전용 안내·명시적 거절이 동작하지 않으면 공대장 측 대응 회귀로 판정한다.

   **과거 재현과 해결(2026-09-20):** 다른 Player의 `players/Grn71r8G1pvCEvLAtpVB/raidStates/hTfsqNxwHm5Oo4GL8zcK_kazeros_act4`는 이전 주차 active state라 현재 Projection의 느낌표에는 나타나지 않았고, 초기 구현에서는 쓰기 경로를 점유했다. D4·D5는 연결 모집의 missing/stale 여부를 Transaction에서 다시 검증한 경우에만 정리를 허용한다. 사용자가 같은 유형의 이전 주차 고아로 신청했을 때 안내와 실제 삭제가 정상 작동함을 확인했으므로 이 재현은 해결 근거로 보존한다.

   **현재 주차 해결 근거:** `players/kVn6KZwZQO6or3BjNYqX/raidStates/xseSyVxZXWhKYxlZEucb_kazeros_act4`가 존재하지 않는 모집 `td904kw3PEgWI1GwIfUP`을 참조해 참가 느낌표와 승인 실패를 일으킨 과거 재현을 D1~D3의 기준 데이터로 사용했다. 구현 후 사용자가 현재 주차 고아의 느낌표와 명시적 정리를 확인했다. 다른 Character·raid의 해산방 pending 신청 두 건은 이 증상의 직접 원인이 아니며 아래 운영 정리 백로그에 남긴다.
   - 참고: [`FIRESTORE_PARTY_COMMAND_CONTRACT.md`](../architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md), [`PARTY_PARTICIPATION_RULES.md`](../product/PARTY_PARTICIPATION_RULES.md), [`BUG_REPORTS.md`](BUG_REPORTS.md) `니티야` 고아 점유 기록.

6. **F6-E — 최소 전투력 신청 제한 실동작: F6-C와 분리된 후속 코드 구간.** 착수 시점에는 `minCombatPower`가 생성 원본·목록·상세·신청 Snapshot에 저장·표시되어도 운영 후보 query와 원자 명령이 일관되게 강제하지 않는 연결 공백이 있었다. 현재 코드 연결은 완료했고 실기기 UX 확인을 대기한다.
   - **판정 주체:** 신청자 본인 클라이언트가 계정 갱신으로 보유한 선택 역할 Build Snapshot의 전투력을 사용한다. 변조 데이터, 서버 권위 전투력 저장과 Rules 기반 위변조 방지는 고려하지 않는다.
   - **신청 UX:** 제한 미달 또는 전투력 정보 없음인 Character/역할은 후보에서 사유와 함께 선택 불가로 표시한다. 신청·재신청 실행 직전 현재 모집 Aggregate의 고정 `minCombatPower`와 제출 Snapshot을 다시 비교하고 application 쓰기 전에 거절한다.
   - **우회 차단:** 신청 문서가 없는 즉시 가입과 참가 Character 변경에도 동일 판정을 적용한다. 공대장 승인 시 신청자의 private 데이터를 새로 읽지 않으며 Rules와 승인 원자 명령에 권위 검증을 추가하지 않는다.
   - **현재 제외:** 실제 앱에 모집 조건 수정 기능이 없으므로 제한 상향·하향 뒤 기존 pending 신청과 파티원 처리 정책은 정하지 않는다. 모집 수정 기능을 구현할 때 별도 계약으로 결정한다. 생성자가 자신의 전투력보다 높은 제한을 입력하는 기존 동작도 이번 작업에서 새로 변경하지 않는다.
   - **변경 예상 위치:** 상세 후보 query/서비스, 신청·재신청 Repository 사전 검증, 즉시 가입 및 Character 변경 사전 검증, 실패 사유·표적 테스트다. Firestore 스키마·Rules·공용 이벤트·인원수 비례 조회는 변경하지 않는다.
   - **회귀 보호:** 제한 없음 모집, 정확히 최소값과 초과 Character, 미달·null 전투력, 신청·재신청·즉시 가입·Character 변경을 구분한다. 기존 아이템 레벨·점유·완료·역할·동일 파티 직업·고아 복구 조건은 그대로 먼저 또는 함께 만족해야 한다.
   - 참고: [`FIRESTORE_PARTY_COMMAND_CONTRACT.md`](../architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md) 4.3 최소 전투력 판정 계약, [`MVP.md`](../product/MVP.md) 모집글 작성/지원.

   **구현 전 실제 연결·충돌 조사(2026-09-21):**

   1. 운영 Router의 모집 상세는 과거 `RecruitmentApplicationCandidateService`가 아니라 생성 화면과 공유하는 `RecruitmentLeaderCandidateService`를 사용한다. 과거 서비스에는 최소 전투력 후보 판정이 있으나 운영 상세의 `RecruitmentLeaderCandidateQuery`에는 `minCombatPower`가 없으므로 현재 신청·즉시 가입·Character 변경 후보에는 실제 차단이 적용되지 않는다.
   2. `FirestorePartyAtomicApplicationCommandRepository`는 모집 원본과 Character의 입장 레벨·소유권·점유를 확인하지만 `command.combatPower`와 모집 제한을 비교하지 않는다. `FirestorePartyAtomicJoinCommandRepository`도 즉시 가입 또는 신청 Snapshot의 전투력을 membership에 복사할 뿐 제한을 검사하지 않는다. `FirestorePartyAtomicMemberMutationRepository` 역시 변경 Character 전투력을 저장만 한다.
   3. 모집 생성자의 기존 제한 검사는 그대로 둔다. F6-E는 모집 생성·수정, 전투력 산식, 계정 갱신과 Build Snapshot 생성, Firestore Rules·스키마·이벤트·인원 집계를 변경하지 않는다.
   4. 앱의 물리적·기술적 변조는 대응하지 않는다. 전투력을 속여 제한 모집에 참가할 실익이 낮고 현재 외부 배포된 구버전도 없으므로, 변조·구버전 우회를 위한 서버 권위 검증은 F6-E 완료 조건이 아니다.

   **확정 구현 설계:**

   1. `제한 없음 / 충족 / 정보 없음 / 미달`을 구분하는 단일 Domain 판정 정책을 둔다. 제한과 전투력이 같으면 충족이며, 제한이 있을 때 전투력 `null`은 미달과 같은 차단 대상이지만 사용자 문구는 `전투력 정보 없음`으로 구분한다.
   2. 운영 상세의 신청·즉시 가입과 Character 변경 후보 query에 모집의 `minCombatPower`를 전달한다. `RecruitmentLeaderCandidateService`는 선택 역할 Build Snapshot의 전투력으로 역할별 거절 사유를 만들며, F6-C의 레이드 미선택 탐색과 모집 생성 후보에는 이 제한을 새로 적용하지 않는다.
   3. UI 후보 차단만 신뢰하지 않는다. 신청·재신청 Transaction은 현재 모집 Aggregate 제한과 `PartyApplyCommand.combatPower`, 즉시 가입은 `PartyDirectJoinCommand.combatPower`, Character 변경은 `PartyChangeCharacterCommand.combatPower`를 쓰기 직전에 같은 정책으로 다시 비교한다. 기존 인증·모집 상태·revision·Character 소유권·입장 레벨·점유/완료·고아 판정·파티 구성 검증의 순서와 결과를 재작성하지 않고 기존 쓰기 계획 직전의 추가 게이트로 둔다.
   4. 승인 Transaction은 신청자의 private Character/`raidState`를 추가 조회하지 않는다. 이미 읽는 모집의 고정 제한과 application `submittedBuildSnapshot.combatPower`만 비교한다. 제한 미달 또는 Snapshot 누락이면 승인만 거절하고 신청은 `pending`으로 유지해 공대장이 기존 거절 버튼을 선택할 수 있게 한다. 과거 미달 신청도 같은 방식으로 차단하며 자동 거절·자동 삭제하지 않는다.
   5. `PartyApplicationFailure`, `PartyJoinFailure`, `PartyMembershipFailure`에 최소 전투력 미충족을 일반 `invalidCharacter`와 구분한 결과를 추가한다. 신청자에게는 최소 전투력 미달/정보 없음 안내를, 공대장에게는 `신청 캐릭터가 최소 전투력을 충족하지 않아 승인할 수 없습니다. 신청을 거절해 주세요.`를 표시한다. 이 결과는 D6의 `permissionDenied` 기반 고아 승인 복구 안내로 보내지 않는다.
   6. 승인 목록에서는 application Snapshot과 모집 제한만으로 미달·정보 없음 상태를 표시하고 승인 버튼만 비활성화한다. 거절 버튼은 유지한다. 제한을 충족한 정상 신청과 제한 없는 방의 기존 승인 UX는 그대로 둔다.

   **회귀 위험과 보호 기준:**

   - 전투력 제한 때문에 기존 `weeklyRaidCompleted`, `participationConflict`, `orphanedParticipation`, `stateInconsistent`, revision 충돌과 파티 구성 실패가 일반 전투력 오류로 덮이지 않게 한다. 후보 UI의 선차단과 Transaction 최종 게이트를 분리하되 서버 쓰기 전 기존 상태 검증은 보존한다.
   - 제한이 없는 방은 `combatPower == null`도 지금처럼 신청·즉시 가입·승인·Character 변경이 가능해야 한다. 제한값과 정확히 같은 전투력도 허용한다.
   - 이미 확정 참가한 미달 멤버를 자동 추방하거나 기존 membership을 수정하지 않는다. 이후 Character 변경 대상만 현재 제한을 만족해야 한다.
   - 다음 주 함께하기 상태의 Character 변경에도 같은 모집 제한을 적용하되, 완료 기록 유지와 다음 주 준비 예외는 변경하지 않는다.
   - 비교는 기존 Aggregate와 command/application Snapshot만 사용하므로 추가 Firestore 문서 읽기, 인원수 비례 호출, 개인 이벤트 fan-out과 Rules 배포가 없어야 한다.

   **최소 검증:** Domain 판정의 제한 없음·정확한 경계·미달·정보 없음, 운영 후보의 역할별 차단, 신청/재신청·즉시 가입·승인·Character 변경의 쓰기 직전 대표 게이트, 제한 없는 기존 흐름과 D6 승인 오류 분리를 표적으로 검증한다. 동일 UI 자동 반복은 하지 않으며 사용자는 실기기 두 대로 `미달 신청 차단`과 `충족 신청 → 승인`, 필요하면 즉시 가입 또는 Character 변경 대표 한 건만 확인한다. Rules가 바뀌지 않으므로 Emulator·운영 게시를 수행하지 않는다.

   **완료 상태(2026-09-21):** 단일 Domain 정책, 운영 후보 query, 신청·즉시 가입/승인·Character 변경 Transaction 게이트를 연결했다. 미달/정보 없음 신청은 승인만 비활성화하고 거절은 유지한다. 변경 파일 분석과 Domain·후보·상세 Widget·Repository 연결 계약 표적 테스트를 통과했고, 사용자가 실기기에서 미달 신청 차단·충족 신청 승인·미달 Character 변경 차단을 모두 확인했다.

D6·F6-C·F6-E는 코드·표적 검증·실기기 근거로 닫았다. 다음 F7에서 본인 즉시 가입의 D5 복구 UX, 문서의 과거 미확인 표기, 최종 회귀를 한 번 정리한다. 운영 Rules 활성 소스 대조는 별도 미확인 근거로 남기며, F7 전에는 `dev/main` 통합과 릴리즈를 보류한다.

#### 후속 백로그 — 안전한 테스트 데이터 정리 도구 (F6 범위 밖)

참고: [`BUG_REPORTS.md`](BUG_REPORTS.md) 고아 `raidState`와 콘솔 단독 삭제 이력, [`PARTY_GROUP_COMMAND_SCALABILITY_REDESIGN.md`](../architecture/PARTY_GROUP_COMMAND_SCALABILITY_REDESIGN.md) 원자 명령·후처리 경계.

사용자가 콘솔에서 모집 문서를 단독 삭제하면 개인 점유·신청 참조가 남을 수 있다. 전체 Firebase 초기화는 이번 복구 방법이 아니다. F6-D는 본인이 화면에서 마주친 단일 고아 참가 상태만 서버 재검증 후 복구한다. 여러 Player·Character의 고아 상태와 해산·삭제된 부모 아래 남은 pending 신청을 찾고 일괄 정리하는 운영 도구는 별도 작업으로 유지한다. 연결 문서 목록의 읽기 전용 진단, 대상별 백업·미리보기, 명시적 확인, 제한된 정리와 사후 무결성 검사를 설계하며 그룹·인증·Character 등 무관한 데이터는 지우지 않는다.

### F7. 최종 통합 판정

참고: [`PARTY_GROUP_COMMAND_SCALABILITY_REDESIGN.md`](../architecture/PARTY_GROUP_COMMAND_SCALABILITY_REDESIGN.md), [`BUG_REPORTS.md`](BUG_REPORTS.md), [`DEV_LOG.md`](DEV_LOG.md), [`TASK-11-FIRESTORE-RULES-COMPLEXITY.md`](TASK-11-FIRESTORE-RULES-COMPLEXITY.md).

- F1~F6 리메이크의 각 단계에서 이미 통과한 표적 자동·Rules Emulator·실기기 UX 검증을 다시 반복하지 않는다.
- F7은 최종 코드·Git·문서 상태를 대조하고, 과거 미확인 표기와 실제로 남은 항목만 분리한다. 코드가 바뀌지 않았다면 전체 `flutter test`·전체 `flutter analyze`·전체 Rules Emulator·실기기 통합 회귀를 새로 실행하지 않는다.
- 본인 즉시 가입 D5 고아 복구 UX처럼 아직 확인되지 않은 독립 항목만 필요한 최소 실기기 확인으로 남긴다.
- 미해결 항목이 있으면 기능 브랜치를 유지하며 `dev`·`main`·release를 움직이지 않는다.
- 남은 항목을 확인한 뒤 문서 완료 이력을 `DEV_LOG`로 옮기고 최신 `dev`에 통합한다. 새 release는 그 이후 별도 결정한다.

**F7 대조 결과(2026-09-21):**

- 본인 즉시 가입은 `FirestorePartyAtomicJoinCommandRepository.joinDirectly`가 D5의 공용 점유 판정을 통해 현재/이전 주차 고아를 `orphanedParticipation`으로 반환하고, 모집 상세가 일반 신청과 같은 `_offerOrphanCleanup`으로 연결한다. 정리 후 즉시 가입을 자동 재실행하지 않는 기존 계약도 유지한다.
- D5 수명 판정·Rules 경계는 기존 표적 검증과 demo Actions `35494192803`에서 통과했고, 신청 경로의 같은 정리 UX는 사용자가 실기기에서 확인했다. 즉시 가입 전용 통합 테스트는 반복하지 않는다.
- 과거 전체 Flutter 실패 17/13건과 Rules CLI 503은 `DEV_LOG`의 당시 진단 이력으로 유지한다. F7에서 재실행하거나 현재 기능 결함으로 재분류하지 않았다.
- 운영 Rules 활성 소스 해시는 AI가 독립 대조하지 않은 운영 근거로 남긴다. 이후 Rules를 바꾸지 않았고 Rules 의존 실기기 흐름이 통과했으므로 `dev` 통합을 막는 신규 결함으로 보지 않는다.
- 현재 브랜치는 `dev` 시점을 포함하며 `dev` 전용 미병합 커밋은 없다. `main`의 별도 merge 커밋은 이 기능 브랜치의 통합 기준이 아니며 `main`·release 단계에서 별도 대조한다.

## 실패 조사 시 필수 근거

각 실패마다 아래만 기록하고 추측 패치를 시작하지 않는다.

```text
기능 / 계정 역할 / recruitmentId 또는 groupId
명령 직전 schemaVersion·revision·status·visibility
앱이 계획한 읽기·쓰기 문서 경로
Firebase 오류 code·단계와 첫 실패 로그
관련 Rules 허용 분기와 get/exists/getAfter 수
같은 빌드에서 보존 확인한 선행 정상 흐름
```

## 제외 범위

- 원자 Aggregate·`raidState` 구조 폐기 또는 legacy 쓰기 복원
- Cloud Functions·유료 서버 도입
- 16인 공격대 선행 구현
- 파티·그룹과 무관한 UI 개편
- 실기기 근거 없이 D1~D9를 완료 처리
- 복구가 끝나기 전 `dev`·`main` 통합 또는 release 생성

## 현재 설계 단계 완료 조건

- D1~D9와 이전 정상 기능을 빠짐없이 복구 묶음 F1~F6에 배치한다.
- 각 묶음의 원인 조사 순서, 수정 경계, 자동·실기기 완료 조건이 정의된다.
- 미추적 백업·Rules 테스트의 용도를 분류한다.
- 기능 코드와 Rules를 수정하지 않은 상태로 사용자 승인을 받는다.
