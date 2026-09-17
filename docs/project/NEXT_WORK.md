# NEXT WORK — 파티·그룹 명령 확장성 재설계 1단계

## 현재 상태

- 기존 `release/1.0.0` 후보는 폐기했다. 브랜치는 이력용으로 보존하되 출시·`main` 병합 기준으로 사용하지 않는다.
- R1~R7·C* 구현과 운영 Rules·Indexes 게시는 완료했다. 운영 Router는 원자 Repository·어댑터를 쓴다.
- 로컬에는 생성·읽기 v2·이전 Close/Open 가드·승인 패치·listing sync·Listen 가드·orphan 공개 전환·모집 삭제→disband·캐릭터 변경 atomic OR·그룹 전용방 파티장 탈퇴 차단 등이 **코드로 들어가 있다**.
- **실기기 판정(2026-09-16 사용자 확인):** 아래 성공 항목은 사용자가 디바이스에서 확인했다. 그 밖의 보고 실패는 로컬 수정·자동 테스트 통과만으로 완료로 쓰지 않는다.

### 실기기 확인됨 (고쳐진 것)

1. 레이드 모집방 생성
2. 그룹 생성
3. 공개 목록·레이드 현황·상세에 schemaVersion 2 모집이 보임
4. 그룹 직접 초대·수락, 검색 가입 신청·수락, 일반 그룹원 탈퇴, 그룹장 이전·이전한 기존 그룹장 탈퇴, 마지막 1인 해산
5. 초대코드 가입(사용자가 Rules 별도 게시 후 확인)

### 실기기 복구 현황 (남은 항목 우선)

우선순위는 재현 빈도와 차단 범위다. 한 번에 하나의 승인된 묶음만 고친다.

| ID | 증상 | 비고 / 로컬에 있는 후보 수정 |
| --- | --- | --- |
| D1 | 그룹장 이전 permission-denied | **복구 확인:** 이전·기존 그룹장 탈퇴와 활성 그룹 모집 중 해산 차단 안내 실기기 통과 |
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

D2 즉시 가입, D3 신청 승인, D4 신청 불안정을 **신청 상태 전이 → 확정 참가 → 화면 재진입** 순서로 복구한다. 현 Router는 `FirestorePartyAtomicApplicationCommandRepository`와 `FirestorePartyAtomicJoinCommandRepository`를 실제 상세에 주입한다. 두 클래스의 오래된 “Router 미연결” 주석과 구 계약 문서의 `activeRaidAssignment` 서술을 실행 기준으로 삼지 않는다. 현재 기준은 schemaVersion 2 모집 Aggregate, Player별 `raidState`, 공용 `partyEvents`, 신청 원본 및 그룹 `raidListings`다.

#### F2-0. 생성→목록→후보→신청 계약 재정렬 (F2-A/B보다 선행)

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

구현 진행: 전체 Rules Emulator CI `35168309443`에서 동일 Transaction 교체 거부, 만료 1회성 `raidState` 단독 삭제→신규 모집 원자 생성 성공을 확인했다. 생성 Repository는 점유 교체 판정 시 첫 Transaction에서 stale state만 삭제하고, 두 번째 Transaction에서 인증·캐릭터·점유·주간 Claim·그룹 상태를 다시 읽고 새 모집을 생성하도록 변경했다. 현재 주차 active와 만료 반복방 삭제 거부를 추가한 Rules 회귀, 최종 Rules CI, 실기기 생성/신청은 아직 검증 전이다. Rules는 이 수정에서 새로 변경하지 않았으며 운영에는 앞선 초기 생성 집계 Rules 수정본도 아직 미게시다.

#### F2-A. 신청 상태 전이와 실패 지점 분리

1. 운영 게시 Rules·인덱스와 현재 앱 빌드의 기준을 확인한다. 공개/그룹 전용 방, 직접 참가/승인 방을 구분하고 actor Player·recruitmentId·applicationId, 명령 전 `revision/status/cycleKey`와 Firebase 오류 `code`를 기록한다. “신청 실패”가 명령 Transaction, 권한 있는 읽기·Listen, 화면 갱신 중 어느 단계인지 분리한다. Listen 자체의 일반 역할별 재설계는 F3에 남긴다.
2. 신청 생성 → 본인 철회 → 재신청, 파티장 거절 → 재신청, 승인 후 탈퇴 → 재신청을 각각 `applications/{playerId}`의 같은 문서 전이로 고정한다. `pending` 중복 거절, `revision` 증가, `approvalCount` 재신청 초기화, `rejectionCount` 유지, 신청 당시 `countedAsNonGroupApplicant`와 모집의 pending 집계 증감을 확인한다. 신청 대기는 `raidState` 확정 점유를 만들지 않는다.
3. 실제 Write Plan의 모집·신청·공용 이벤트 쓰기와 `validPendingApplication`/재신청/철회/결정 Rules를 현재 전체 Rules Emulator에 재현한다. Windows 로컬 전체 Rules 업로드 503은 이미 분리된 환경 문제이므로 같은 시도를 반복하지 않고 demo 전용 GitHub Actions를 엔진 검증 경로로 사용한다. 결함이 재현된 문서와 Rules 분기만 좁게 수정한다.

현재 진행(2026-09-16): 공개방 신청→철회→재신청은 전체 Rules Emulator `35087432007`에서 통과했다. 그룹 연결 공개방에서 재신청 시 `countedAsNonGroupApplicant`가 바뀌는 경계는 `35087675480`에서 신청 update의 표현식 1,000개 한도 `PERMISSION_DENIED`로 재현했다. 재신청 허용 필드에 해당 Snapshot을 추가하되 현재 그룹 membership과 일치시켰고, 신청 update는 새 상태별 분기만 평가하도록 조정했다. 수정본 `35104429826`, 그룹 전용방의 정상/변조 재신청까지 확장한 `35104711642`의 전체 추적 Rules·F1 회귀가 통과했다. 관련 Flutter 표적 46건, 변경 테스트 파일 분석과 `git diff --check`가 통과했다. 최신 Rules SHA-256은 `AAB74C69483AE1C46AF69C3D8378F30573581AAA1FCBBB1485181BFBD31255D5`이다. 최초 운영 게시 시도는 안전 심사에서 명령 실행 전 거절됐다. 이후 사용자가 이 버전의 게시를 승인했으나 CLI 결과는 작업 중단으로 확인하지 못했다. 사용자는 현재 운영 게시 Rules와 로컬 파일의 내용이 동일함을 직접 확인했다. 따라서 소스 일치는 사용자 확인으로 기록하고, CLI 컴파일 경고 수·게시 시각·실기기 성공은 확인하지 않은 상태로 둔다. 동일 Rules의 재게시 없이 F2-A 실기기 신청→철회→재신청 결과를 먼저 받는다.

실기기 피드백: 최초 신청에서 `신청을 처리하지 못했습니다.`가 표시됐다. 원자 신청 Repository에 추가한 디버그 빌드 전용 로그로 `PartyAtomicDocumentMapper.aggregate()`의 `ArgumentError: 모집 Aggregate 집계가 올바르지 않습니다`를 확인했다. 서버 쓰기 전 저장 문서와 Domain 불변식의 불일치이며 이 신청의 Rules `permission-denied`는 아니다. 신청 쓰기·Rules·사용자 안내는 아직 변경하지 않았다. F2-0의 생성 집계 복구와 기존 방 처리 방향을 먼저 확정하고, 실패 방의 실제 저장값을 확인하기 전에는 F2-A를 완료로 처리하지 않는다.

#### F2-B. 즉시 가입과 승인 확정

4. 즉시 가입은 신청 문서 없이 본인 actor가, 승인은 현재 승인권자가 `pending` 신청자를 확정한다. 두 경로의 성공 결과가 모집 `partySlots/memberPlayerIds`·인원/역할/그룹 집계·revision, 대상 membership·`raidState`, 그룹 listing 전체 Snapshot, 공용 이벤트 1건에서 일치하는지 비교한다. 승인 전이는 `approvedByApprover`, `approvalCount + 1`, pending 집계 −1이며 신청 당시 그룹 집계 Snapshot을 사용한다.
5. Rules의 읽기·쓰기 순서를 따로 검증한다. 가입/승인 모두 소유 Character·주간 Claim·현재 회차·정원·역할/동일 파티 직업·기존 확정 점유·그룹 접근 권한을 Transaction에서 재판정한다. 승인자가 타인의 stale `raidState`를 지우지 않으며, 본인 즉시 가입의 stale 정리도 Rules가 허용하는 경우에만 수행한다. 다중 승인·가입 경쟁, revision 충돌, 중단 후 재시도에서 멤버·점유·이벤트·집계가 중복되지 않아야 한다.

#### F2-C. 연결 검증과 완료 게이트

6. 각 수정 뒤에는 기존 모집/그룹 생성과 v2 목록·현황·상세, F1 이전·탈퇴·초대코드·해산 차단을 회귀 보호한다. 표적 Domain/Write Plan/Rules 계약과 전체 Rules Emulator의 허용·거절 케이스를 먼저 통과시키고, Rules가 실제 변경됐을 때만 배포 절차를 적용한다. Indexes 게시가 새로 필요하면 별도 명시 지시를 받는다.
7. 자동 검증 후 최대 3계정 실기기에서 공개·그룹 전용 각각 신청/철회/거절/재신청/승인/즉시 가입을 확인한다. 같은 레이드 복수 pending은 허용하되 첫 확정 참가 뒤 중복 확정은 차단하고, 만석·역할/직업 충돌·주간 완료·구 회차 및 앱 재진입을 대표 경계로 확인한다. 4·8인 경계와 경쟁은 Emulator로 보강하고 8대 디바이스를 요구하지 않는다.

완료 조건: D2~D4의 실제 실패 지점과 수정 근거가 기록되고, 공개/그룹 방의 신청 상태 전이·확정 참가가 자동/실기기에서 일관되게 통과한다. 권한 오류나 재시도에서 부분 성공·중복 저장이 없고 기존 F0/F1 흐름이 유지된다. F3 Listen 전체·F4 orphan/그룹장 관리·F5 자리 조정·F6 회차 수명주기 구현은 이번 묶음에서 제외한다.

### F3. 상세 읽기와 Listen 복구

D9를 독립 묶음으로 처리한다. 공개 방문자, 신청자, 확정 멤버, 파티장별로 허용된 구독이 다르므로 화면 진입 시 실제로 연 Listener를 역할별로 대조한다.

- 신청 전체 목록은 파티장만 구독한다.
- 본인 신청은 본인 단건 경로만 구독한다.
- 구 `cycles`는 리더·확정 멤버만 읽고, v2 회차 상태는 모집 Aggregate를 기준으로 표시한다.
- 구독 권한이 없는 역할은 Listener를 시작하지 않으며 로그에 `PERMISSION_DENIED`를 남기지 않는다.

완료 조건: 네 역할의 상세 진입·이탈·재진입에서 화면과 로그가 정상이고 기존 목록·현황 가시성이 유지된다.

### F4. orphan 예방과 복구

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
4. 모집 해산도 현재 공대장 **또는** 해당 그룹의 현재 그룹장만 그룹 전용방에서 허용한다. 그룹장 명령은 기존 최대 8명 `raidState` 해제·모집 종료·그룹 수 감소·listing 제거·공용 이벤트의 원자 계약을 그대로 충족한다. `lastCommandActorPlayerId`와 실제 호출자를 맞추되 모집 공대장·멤버십은 변경하지 않는다. 완료·완료 취소·주차 전환·신청 승인·자리 조정 권한은 기존 공대장 정책을 유지한다.
5. 기존 orphan 방의 공대장 명령(D5~D8: 공개 전환·캐릭터 변경·모집 삭제→해산·직접 해산)을 다시 검증한다. 그룹장은 추가 두 명령만 실행한다. 그룹 전용방 공대장의 그룹 탈퇴를 막는 현행 로컬 가드는 새 구조와 과거 orphan 복구의 실기기 확인 뒤 제거 여부를 결정한다.

#### 회귀·완료 조건

- 3개 이하 계정으로 그룹장·방 공대장·일반 그룹원을 분리해 권한을 확인한다. 그룹장 이전 직후 새 그룹장만 관리할 수 있어야 하며, 그룹장이 방에 참가하지 않아도 두 명령이 가능해야 한다.
- 목록에는 활성 반복방(이번 주 완료 포함), 만석, 모집 일시 중단이 보이고 완료된 1회성·해산·전체 공개는 보이지 않는다. 그룹 해산 차단 수와 목록 전체 건수가 같거나, 불일치가 명시적으로 드러난다. 오래된 listing, 원본 누락과 20건 초과도 점검한다.
- 그룹장 공개 전환/해산 뒤 집계는 정확히 한 번 감소하고 그룹장 단독 그룹 해산이 가능하다. 전체 공개로 전환한 방은 기존 공대장이 완료·해산·다음 주차 전환을 계속할 수 있으며 그룹 집계·listing을 다시 건드리지 않는다.
- 기존 공대장 명령, 과거 orphan 방 복구, 일반 공개방 권한, 1·2·4·8인 원자 해산과 Rules 접근 한도를 표적·전체 Emulator 및 실기기로 확인한다. 완료 전까지 `dev`·`main` 통합이나 운영 배포 완료 판정을 하지 않는다.

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
