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
3. 캐릭터 변경 OR 포함 Rules 재게시 — `/test` **503** 실패, 업로드·release 미도달. **지시 후 1회만** 재시도
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

## 이번 작업 목표

구현 전에 각 명령의 실제 Firestore 읽기·쓰기와 Rules `get/exists/getAfter` 의존을 수치화하고, 최대 8인 제한 원자 명령·통합 `raidState`·공용 이벤트와 모집 Aggregate 계약을 확정한다.

## 포함 범위

1. 파티 생성·신청·가입·승인·탈퇴·추방·승계·Character 변경·자리 이동·완료·취소·주차 전환·해산의 접근량 표 작성
2. 그룹 생성·가입·탈퇴·그룹장 이전·해산·그룹 전용 모집 연결의 접근량 표 작성
3. 1·2·4·8인별 쓰기 수와 Rules 접근 한도 위험 구간 분류
4. 파티·그룹 공용 이벤트 원본, audience와 개인 읽음 cursor 계약 확정
5. 모집 Aggregate 구성 요약과 `expectedRevision`·`lastCommandId` 기반 명령 계약 확정
6. assignment·주간 Claim을 대체할 통합 `raidState`와 8인 완료·취소·전환·해산 원자 명령 계약 확정
7. 앱 종료·응답 유실 후 서버 결과 자동 판정과 종료된 membership·slot·application 지연 정리 계약 확정
8. 확정된 개인 event·개발 테스트 데이터 초기화 범위와 무호환 전환 계약 기록

## 제외 범위

- 이번 1단계에서 Repository·Rules·Firestore 스키마 구현
- 기존 `release/1.0.0`, `dev`, `main` 병합·이동·배포
- 해산 기능만을 위한 추가 임시 Rules 또는 UI 우회
- Cloud Functions·유료 서버 도입

## 현재 브랜치와 구현 착수 게이트

- 2026-09-14 현재 통합 기준 `dev`와 `origin/dev`는 `aab6b41`로 일치한다.
- 현재 설계 브랜치는 최신 `dev`에서 분기한 `docs/party-group-command-redesign`이다. 이 브랜치에서는 접근량 감사와 계약 문서만 다루며 Repository·Rules를 수정하지 않는다.
- `main`과 폐기된 `release/1.0.0`은 현재 구조개선에 병합하지 않는다.
- 현재 문서 변경을 검토·커밋하기 전에는 Repository·스키마·Rules 구현을 시작하지 않는다.
- 문서 설계가 승인되면 `feature/party-group-command-redesign`을 최신 `dev`에서 분기한다. 부분 스키마 전환은 `dev`에 병합하지 않고, 기능 브랜치에서 전체 읽기·쓰기·Rules·Router 전환과 초기화 절차를 검증한 뒤 한 번에 통합한다.
- 설계 문서는 로컬 `dev`에 통합됐고 구조개선 기능 브랜치를 시작했다. 다만 첫 Rules 엔진 검증 전에는 운영 Repository·Rules·Router/DI 전환을 시작하지 않는다.

## 확정 결정

- 계정·캐릭터 인증 자료는 보존하고 기존 파티·그룹 거래성 테스트 자료는 새 스키마 전환 때 초기화한다. 구·신 스키마 호환 계층은 만들지 않는다.
- 해산 pending 신청자별 서버 이벤트는 만들지 않는다. 모집 원본 종료 확인으로 숨기고 로컬 1회 안내를 표시한다.
- 종료 하위 문서는 첫 출시에서 자동 정리하지 않으며 활성 판정에서만 완전히 제외한다.
- 완료·취소·주차 전환·해산은 온라인 전용 원자 명령이고 오프라인 큐를 사용하지 않는다.

## 회귀 보호 목록

- 모집 생성, 신청·철회·거절·승인·즉시 가입
- 파티장 탈퇴와 가입 순서 기반 후임 승계
- 일반 탈퇴·추방 후 재신청
- 파티별 동일 구성 직업 제한과 딜러/서포터형 구분
- 빈자리 이동·점유 자리 교환·중복 직업 안내
- 주간 완료 체크, 완료 취소, 반복방 수요일 06시 전환
- 공개·그룹 전용 목록과 그룹 자격 상실 정리
- 그룹 생성·가입·탈퇴·그룹장 이전·마지막 1인 해산
- 보석·아크그리드 통합 오류 Snapshot 표시

## 작업 순서

1. 현재 명령·Rules 접근량을 코드 근거와 함께 표로 작성한다.
2. 위험 구간을 개인 event fan-out, 전체 membership 재조회, 전원 Projection 동시 갱신, 연결 문서 순회로 묶는다.
3. 8인 원자 명령, 통합 `raidState`, 모집 Aggregate와 `lastCommandId` 계약 초안을 작성한다.
4. 공용 이벤트의 audience 조회·Rules 조건과 종료 하위 문서의 읽기 차단·지연 정리 계약을 작성한다.
5. 기능별 전환 순서와 자동·실기기 검증표를 확정한다.
6. 문서 승인 후 단일 구조개선 기능 브랜치에서 Rules 예산 증명부터 시작하고, 전체 전환 전에는 `dev`에 부분 병합하지 않는다.

6번의 첫 Rules 예산 증명은 GitHub Actions 실행 `34848336222`에서 통과했다. 비연결 Domain·Repository 계약으로 통합 `raidState`, 최대 8칸 Aggregate, 제한 명령 봉투, 응답 유실 판정과 Repository 인터페이스를 추가했다. Firestore Aggregate 매퍼와 완료·취소·주차 전환·해산 Write Plan도 추가해 비그룹 8인 완료 10건, 그룹 8인 일반 수명주기 11건, 그룹 모집을 닫는 1회성 완료·활성 해산 12건과 완료 후 해산 2건의 제한된 쓰기 및 대상·revision 불변식을 표적 테스트로 고정했다. 반복방 완료·취소, 미완료 주차 전환, 1회성 완료와 완료 후 해산을 구분한 보강 Rules도 Actions 실행 `34851122346`에서 재통과했다. 비연결 Firestore Repository와 생성·가입·신청·재신청·철회·승인, 캐릭터 변경·빈자리 이동·점유 자리 교환, 탈퇴·추방·가입 순서 기반 파티장 승계의 고정 크기 Write Plan까지 완료했다. 그룹 자격 집계는 슬롯과 신청 문서에 각각 집계 당시 Snapshot을 저장해 이후 그룹 탈퇴가 과거 집계를 훼손하지 않게 했고, 공개↔그룹 전환을 Aggregate 집계와 그룹 `activeRecruitmentCount`만으로 계획한다. 1회성 그룹 모집은 완료 순간 활성 수와 listing을 닫고 이후 화면 마무리 해산에서는 이중 감소하지 않도록 Repository와 격리 Rules 증명을 보완했으며 Actions 실행 `34857997972`에서 1·2·4·8인 시나리오가 통과했다. 탈퇴·추방·그룹 자격 상실 정리는 전원 조회 없이 대상·필요 후임·`raidState`·그룹 membership 직접 문서만 읽는 비연결 Firestore Repository까지 추가했다.

생성·신청·재신청·철회, 즉시 가입·승인·거절, 캐릭터 변경·자리 이동의 비연결 Firestore 원자 Repository도 추가했다. 신청 거절은 pending 집계를 줄이는 `PartyAtomicApplicationRejectWritePlan`을 쓰고, 재신청은 기존 `.apply` 계획으로 pending을 다시 올린다. 생성·가입은 `raidState` 점유와 주간 완료를 확인하며 assignment·Claim·slots·개인 event·전원 `members.get`을 사용하지 않는다. 계약 테스트는 운영 Router 미연결을 고정한다.

공개↔그룹 전환의 비연결 원자 Repository와 그룹 해산의 `activeRecruitmentCount` 게이트도 추가했다. 그룹 생성은 `activeRecruitmentCount: 0`으로 시작하고, 해산은 `raidListings` 최대 20건 순회 대신 `GroupActiveRecruitmentWritePlan.validateDisband`만 사용한다. 운영 Rules와 Router/DI·`partyEvents` 읽기 전환은 Rules 복구 슬라이스 R1~R6를 먼저 쌓은 뒤, 구 경로 차단과 앱 연결(C*)을 한 묶음으로 수행한다.

`party-scalability-proof.yml`은 기능 브랜치의 관련 증명 파일 push와 수동 실행에만 연결한다. Ubuntu·JDK 21·demo 프로젝트 Emulator와 전용 설정·Rules만 사용하며 운영 Firebase 인증·배포는 수행하지 않는다.

```powershell
firebase emulators:exec --only firestore --project demo-party-scalability "node tools/party_scalability_rules_test.mjs"
```

## 완료 조건

- 모든 파티·그룹 명령이 고정 크기·인원 비례·연결 수 비례 중 하나로 분류된다.
- 1·2·4·8인에서 위험한 명령과 그 원인이 누락 없이 기록된다.
- 공용 이벤트, 구성 Aggregate, revision, 통합 `raidState`, 8인 원자 명령과 앱 종료 후 결과 판정 계약이 구현 가능한 수준으로 확정된다.
- 비핵심 하위 문서 정리 실패가 사용자 흐름과 데이터 정확성을 막지 않는다는 것이 읽기·Rules 계약으로 증명된다.
- 각 구현 단계의 영향 기능과 자동·실기기 검증 범위가 정해진다.
- 코드 구현 없이 문서 검토 상태로 사용자 승인을 받는다.
