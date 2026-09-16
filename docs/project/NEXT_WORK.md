# NEXT WORK — 파티·그룹 명령 확장성 재설계 1단계

## 현재 상태

- 기존 `release/1.0.0` 후보는 폐기했다. 브랜치는 이력용으로 보존하되 출시·`main` 병합 기준으로 사용하지 않는다.
- R1~R7·C* 구현과 운영 Rules·Indexes 게시는 완료했다. 운영 Router는 원자 Repository·어댑터를 쓴다.
- 로컬에는 생성·읽기 v2·이전 Close/Open 가드·승인 패치·listing sync·Listen 가드·orphan 공개 전환·모집 삭제→disband·캐릭터 변경 atomic OR·그룹 전용방 파티장 탈퇴 차단 등이 **코드로 들어가 있다**.
- **실기기 판정(2026-09-16 사용자 확인):** Rules 게시 이후에도 아래 **실기기 확인됨**만 고쳤고, 그 밖의 보고 실패는 **아직 고쳐지지 않았다**. 로컬 수정·자동 테스트 통과만으로 완료로 쓰지 않는다.

### 실기기 확인됨 (고쳐진 것)

1. 레이드 모집방 생성
2. 그룹 생성
3. 공개 목록·레이드 현황·상세에 schemaVersion 2 모집이 보임

### 실기기 미해결 (고쳐나갈 목록)

우선순위는 재현 빈도와 차단 범위다. 한 번에 하나의 승인된 묶음만 고친다.

| ID | 증상 | 비고 / 로컬에 있는 후보 수정 |
| --- | --- | --- |
| D1 | 그룹장 이전 permission-denied | Close/Open `lastRecruitmentId` 가드가 Rules에 있음. 실기기에서 재확인 |
| D2 | 즉시 가입방 참가 실패 | 승인 필드·listing sync 등 앱 패치 있음. 실기기 미확인 |
| D3 | 신청 승인(수락) 실패 | `approvedByApprover`+`approvalCount` 패치 있음. 실기기 미확인 |
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
- 완료·완료 취소·반복 설정·수요일 06시 주차 전환·해산
- 공용 이벤트 조회와 종료된 하위 문서의 비활성 처리

## 복구 작업 단위

### F0. 실행 기준 고정과 재현 도구 정리

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

F1 후속 회귀(2026-09-16, 우선 처리): 실기기에서 그룹 생성, 직접 초대 수락, 검색 신청·수락, 일반/기존 그룹장 탈퇴, 그룹장 이전, 1인 해산은 통과했다. 초대코드 가입만 `이 그룹에 가입할 수 없습니다`로 실패한다. 이는 공통 권한 실패 안내이므로 원인을 단정하지 않는다.

- 범위: 초대코드로 신규 가입하는 기존 트랜잭션 및 해당 Rules 경로만 재현·수정한다. 그룹 전용 모집과 비그룹원 표시는 F4의 별도 정책·작업으로 유지한다.
- 순서: 실제 Write Plan과 읽기/쓰기 세트를 전체 추적 Rules Emulator에 재현 → 실패한 문서·검증식/예산 확인 → 최소 수정 및 허용/거절 회귀 → Rules 계약·관련 테스트 → 변경 Rules 게시와 실기기 재확인.
- 보호: 그룹 생성·직접 초대·검색 신청/승인·그룹장 이전·탈퇴·해산은 기존 의미를 바꾸지 않는다. 가입자 외 문서를 전원 순회하거나 인원 비례 쓰기를 추가하지 않는다.
- 완료: 정상 코드는 가입 및 멤버/상태/Projection/인원수 일치, 무효·폐기 코드와 중복 가입은 안전하게 처리되고, 기존 F1 경로도 회귀하지 않음을 자동·실기기 결과로 확인한다.
- 진행 결과: 실제 가입 Write Plan을 복제한 전체 Rules Emulator에서 정상 코드 가입이 표현식 1,000개 한도로 거절됨을 재현했다(`35074490029`). 코드 가입을 먼저 평가하되 기존 그룹장 이전·탈퇴·해산 우선순위를 보존한 Rules로 `35075221872`에서 정상 가입과 F1 수명주기 회귀가 함께 통과했다. 정적 Rules·Write Plan 표적 41건도 통과했다. 실기기 초대코드 가입은 최신 Rules 게시 후 재확인해야 하며, 현재 완료로 판정하지 않는다.

우선 D1 그룹장 이전을 재현하되, 같은 `groups/{groupId}` update OR를 공유하는 일반 탈퇴·마지막 1인 해산·가입 승인도 함께 회귀한다.

검사 순서:

1. 앱이 보낸 group/membership state/relation/member 쓰기와 revision을 확인한다.
2. `validAtomicGroupRecruitmentClose/Open`이 해당 명령에서 문서를 선조회하지 않고 clean false로 빠지는지 확인한다.
3. transfer 성공 뒤 leader·member role, Player relation, membership state와 화면 갱신이 모두 일치하는지 확인한다.
4. 활성 그룹 모집이 있는 그룹장·파티장의 금지 동작은 권한 오류가 아니라 계약된 안내로 끝나는지 확인한다.

완료 조건: 그룹장 이전, 기존 그룹장 탈퇴, 일반 멤버 탈퇴, 마지막 1인 해산과 기존 그룹 생성이 실기기에서 통과한다.

현재 결과(2026-09-16, 구현·자동·운영 게시 완료 / 실기기 대기):

- 그룹장 이전은 그룹 1건과 이전·신규 그룹장 membership 2건, 일반 탈퇴와 1인 해산은 그룹·본인 membership·membership state·relation의 고정 문서만 갱신한다. 파티 인원이나 `raidListings` 수에 따른 Transaction fan-out은 사용하지 않는다.
- 앱의 1인 해산은 `activeRecruitmentCount == 0`을 검사했지만 Rules의 `validGroupDisbandUpdate`에는 같은 조건이 없었다. Rules에도 정수·0 조건을 추가해 우회 클라이언트가 활성 그룹 모집을 남기고 해산하지 못하게 했다.
- 전체 Rules Emulator 시나리오에 그룹장 이전 → 기존 그룹장 탈퇴, 일반 멤버 탈퇴, 1인 해산 성공과 활성 모집 1건일 때 해산 거절을 추가했다. GitHub Actions는 같은 demo 프로젝트에서 생성 기준선과 F1 시나리오를 각각 실행한다.
- 그룹 Rules·Write Plan·C* 기준선·Rules 경고 표적 테스트 42건과 변경 테스트 파일별 정적 분석이 통과했다. 최초 두 파일 동시 분석은 Flutter 프로세스가 출력 없이 정지해 종료했지만, 파일별 재실행은 각각 문제 0건으로 완료됐다.
- CI 실동작에서 과거 membership의 선택 Snapshot 필드 누락 평가 오류와 그룹장 이전의 Rules 표현식 1,000개 한도 초과를 발견했다. 선택 필드는 누락/null/정상 타입을 허용하고, 검증 조건을 완화하지 않은 채 그룹장 이전·role 변경 분기를 OR 앞쪽으로 옮겨 비용을 줄였다.
- GitHub Actions 실행 `35055217000`에서 전체 추적 Rules 생성 기준선과 F1 그룹 수명주기 Emulator 시나리오가 모두 통과했다. 앞선 실패 실행은 테스트 SDK API 오류와 위 두 Rules 회귀를 찾은 진단 근거로 유지한다.
- 운영 게시본 Rules SHA-256은 `A8E9D51EF6F52E2B38BAE1F72462B98F78A2DA105B1522C47152B54BBE54BA1B`이다. `firebase deploy --only firestore:rules --project lost-party` 1회 실행으로 컴파일·업로드·release가 성공했으며 Indexes 등 다른 자원은 게시하지 않았다.
- 남은 완료 조건은 최신 앱으로 그룹장 이전·이전 후 탈퇴·일반 탈퇴·1인 해산과 활성 모집 중 해산 차단을 실기기 확인하는 것이다. 확인 전 F1 완료 또는 F2 시작으로 판정하지 않는다.

### F2. 참가 진입 복구

D2 즉시 가입, D3 신청 승인, D4 신청 불안정을 하나의 참가 상태 머신으로 점검한다.

검사 순서:

1. 신청 생성·철회·거절·재신청의 application `status/revision/approvalCount/rejectionCount` 전이를 고정한다.
2. 즉시 가입과 승인 모두 같은 membership·`raidState`·Aggregate·listing 불변식을 만드는지 비교한다.
3. 승인 사유 `approvedByApprover`, `approvalCount + 1`, 대상 membership 존재와 listing 전체 Snapshot sync가 Rules와 일치하는지 확인한다.
4. 본인 stale `raidState` 정리와 타인 승인 경로를 분리하고, 승인자가 타인의 stale state를 삭제하지 않게 한다.
5. 실패 후 재시도에서 중복 멤버·중복 이벤트·집계 증가가 생기지 않는지 확인한다.

완료 조건: 공개/그룹 방 각각에서 신청·철회·재신청·거절·승인·즉시 가입이 실기기에서 일관되게 통과한다.

### F3. 상세 읽기와 Listen 복구

D9를 독립 묶음으로 처리한다. 공개 방문자, 신청자, 확정 멤버, 파티장별로 허용된 구독이 다르므로 화면 진입 시 실제로 연 Listener를 역할별로 대조한다.

- 신청 전체 목록은 파티장만 구독한다.
- 본인 신청은 본인 단건 경로만 구독한다.
- 구 `cycles`는 리더·확정 멤버만 읽고, v2 회차 상태는 모집 Aggregate를 기준으로 표시한다.
- 구독 권한이 없는 역할은 Listener를 시작하지 않으며 로그에 `PERMISSION_DENIED`를 남기지 않는다.

완료 조건: 네 역할의 상세 진입·이탈·재진입에서 화면과 로그가 정상이고 기존 목록·현황 가시성이 유지된다.

### F4. orphan 예방과 복구

D5~D8을 같은 재현 시나리오로 시작하되 명령은 하나씩 검증한다.

1. 그룹 전용방 파티장의 그룹 탈퇴 예방 차단
2. 이미 orphan인 방의 전체 공개 전환
3. orphan 방의 참가 캐릭터 변경
4. orphan 방의 모집 삭제 UI가 실제로 원자 disband를 호출
5. orphan 방의 직접 해산

각 명령은 파티장 소유권을 모집 membership으로 판정하고, 더 이상 존재하지 않는 그룹 membership을 성공 조건으로 요구하지 않는다. 다만 그룹으로 되돌리거나 그룹 listing을 새로 만드는 동작은 현재 그룹 자격을 계속 요구한다.

완료 조건: 신규 orphan 생성이 차단되고, 기존 orphan 방에서 공개 전환·캐릭터 변경·모집 삭제·직접 해산이 각각 실기기에서 성공한다.

### F5. 파티 구성 변경 회귀

- 참가 캐릭터 변경의 membership·Aggregate slot·`raidState` 교체가 한 Transaction에서 일치한다.
- 자리 이동·교환은 같은 파티의 동일 직업 제한을 유지하고 다른 파티 이동 가능 정책을 보존한다.
- 탈퇴·추방·파티장 승계는 대상과 필요 후임만 바꾸며 그룹 listing과 공용 이벤트를 동기화한다.
- 보석·아크그리드 `buildIntegritySnapshot` 표시를 보존한다.

완료 조건: 4인과 8인 대표 구성에서 변경·이동·교환·탈퇴·추방·승계가 통과한다.

### F6. 회차 수명주기 회귀

- 활성 방 완료, 반복방 완료, 완료 취소, 반복 설정 변경, 수요일 06시 주차 전환, 활성/완료 후 해산을 검증한다.
- 모집과 최대 8개 `raidState`가 전부 반영되거나 전부 미반영되는지 확인한다.
- 수동 주간 Claim과 파티 `raidState` 충돌, 종료 하위 문서의 비활성 처리와 내 계정 체크 표시를 함께 확인한다.

완료 조건: 1·2·4·8인 자동 계약과 3계정 이하 대표 실기기 시나리오가 통과한다.

### F7. 최종 통합 판정

- F1~F6의 최종 코드 상태에서 표적 테스트, 전체 Rules 계약·Emulator, `flutter analyze`, 전체 `flutter test`를 한 번 실행한다.
- 실기기 체크리스트는 공개/그룹 방과 정상/orphan 데이터를 포함해 한 번 최종 회귀한다.
- 미해결 항목이 있으면 기능 브랜치를 유지하며 `dev`·`main`·release를 움직이지 않는다.
- 전부 통과한 뒤 문서 완료 이력을 `DEV_LOG`로 옮기고 최신 `dev`에 통합한다. 새 release는 그 이후 별도 결정한다.

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
