# Task-086 운영자 쓰기 차단 — 해결 기록 (2026-08-29)

> 원본 문서: `docs/project/TASK-086-OPERATOR-WRITE-BLOCKER.md` · 이동일:2026-10-13. 기존 서비스의 보관 문서이며 신규 서버의 실행 기준이 아니다.

**상태:** 해결됨 — 24시간 무응답 자동 이전만 실기기 미검증  
**브랜치:** `cursor/task-086-owner-defense` — 기능 커밋 `8c649ad`  
**Firebase 프로젝트:** `lost-party`  
**관련 Task:** Task-086 기존 소유자 24시간 방어·자동 이전·강제 인증

이 문서는 운영자 수동 인증 쓰기가 `permission-denied`로 막혔던 중지 시점과 이후 해결 결과를 함께 보존한다. 아래의 실패·원인 후보 절은 역사적 디버깅 기록이며, 현재 상태는 이 상단 해결 요약이 우선한다.

## 0. 해결 결과

- 원인: 일반 요청에는 선택 필드 `defenseOfRequestId`가 없는데 분쟁 개시·강제 인증 Rules가 이 필드에 직접 접근해 Rules 평가 오류가 발생했다.
- 수정: 분쟁 개시와 강제 인증 모두 `'defenseOfRequestId' in oldData`를 먼저 검사한다.
- 추가 수정: 승인된 요청을 화면 목록에서 숨기기 전에 요청자 로컬 GameAccount·Character 서버 ID를 연결한다. 같은 GameAccountId가 이미 있어도 누락 ID와 active 상태를 보강한다.
- 추가 기능: 방어 요청에 `방어 실패`를 추가했다. 방어 요청 종료와 신규 요청자 소유권 이전을 같은 Transaction으로 처리하며 이전 소유자에게 인증 금지는 적용하지 않는다.
- 안내: 수동 인증 완료 후 페이지 재진입이 필요하고 완료 알림은 별도로 전송되지 않으며, 반복·부정확한 요청은 운영자 판단으로 추가 인증이 제한될 수 있음을 빨간 경고로 표시한다.
- 자동 검증: 전체 `flutter test --no-pub` **488건 통과**, `flutter analyze --no-pub` 통과.
- 실기기 확인: 취소, 일반 승인, 분쟁 개시, 운영자 거절, 방어 승인, 방어 실패, 강제 인증, 즉시 소유권 이전, 기존 소유자의 레이드 Character 후보 제외, 권한 유지·상실 반영.
- 미검증: 실제 24시간 경과 후 무응답 자동 이전.
- Firestore Rules Emulator 통합 테스트는 Java 부재로 미실행했으나 수정 Rules 배포 후 위 실기기 경로가 통과했다.

---

## 이하: 해결 전 작업 중지 스냅샷

---

## 1. 요약

| 구분 | 상태 |
| --- | --- |
| 운영자 대기 목록·상세 **조회** | 동작 |
| 운영자 **취소** | **동작** (2026-08-29 후반 확인) |
| 운영자 **승인**(무소유) | `permission-denied` 보고 |
| 운영자 **분쟁 개시**(기존 소유자 있음) | `permission-denied` 보고 |
| 운영자 **강제 인증** | `permission-denied` 보고 |
| 운영자 지정·binding·players | **정상** (진단으로 확인) |
| Firestore Rules 배포 | 여러 차례 `lost-party`에 배포 완료 |
| 로컬 테스트 | `test/features/manual_verification`, `test/features/operator_access` 28건 통과 |
| Firestore Rules 통합 테스트 | **미실행** (로컬 Java 없음, Emulator 미구동) |

**핵심:** 운영자 데이터 문제가 아니다. `isActiveOperator()`와 취소용 `validManualVerificationOperatorReviewBody`(cancelled)는 통과하는데, **승인·분쟁·강제 인증 경로의 Rules 또는 Transaction 내 다른 문서 쓰기** 어딘가에서 거절된다.

---

## 2. 사용자·실기기에서 확인된 증상

### 성공

- 운영자 계정으로 `수동 인증 확인` 대기 목록 진입
- 요청 상세에서 **취소** 처리 성공

### 실패

- **승인**, **분쟁 개시(24시간 방어)**, **강제 인증** 시 Firestore `permission-denied`
- 오류 메시지(앱 최신 빌드 기준):

```text
[permission-denied] PERMISSION_DENIED: Missing or insufficient permissions.
Auth jlc1wDAtOHcTwNLH2XWLPS58gFl2
Player vqbeSI7IdPattFT066HT
binding active
players active
operatorAssignments active
클라이언트 기준 운영자 쓰기 준비 OK
```

→ 클라이언트·Rules 모두 “운영자 active”인데 **특정 쓰기 payload 또는 Transaction 내 다른 컬렉션** Rules가 거절하는 패턴.

### 역사적 맥락

- Task-085 시점: **무소유 승인·취소**는 동작했음
- Task-086·강제 인증 추가 이후: **분쟁 개시·강제 인증** 경로에서 회귀 보고
- 디버깅 중 일시적으로 “운영자 지정 확인” 일반 메시지가 보였으나, 이는 **구 앱 빌드**와 **Rules 미배포**가 겹친 혼선으로 판단

---

## 3. 구현된 기능 범위 (코드 기준, 미커밋)

### 앱 (`lib/features/manual_verification/`)

- 분쟁 상태: `awaitingOwnerResponse`, `defended`, `transferred`
- 기존 소유자 있을 때 승인 → `_openDispute()` (요청만 update, 이벤트는 별도 best-effort)
- 강제 인증 `reviewForceApprove()` → `_claimForRequester(..., finalStatus: 'transferred', transferReviewReason: 'operatorForced')`
- 방어 승인·만료 분쟁 자동 이전·분쟁 알림 이벤트
- 운영자 상세: 승인 / 분쟁 개시 / 강제 인증 / 취소 / 인증 금지
- `OperatorWriteReadiness` 진단 + permission-denied 시 화면에 binding·player·assignment 요약 표시
- `_assertNotBlocked`: block 문서 get이 permission-denied여도 무시 (없는 문서 조회 회귀 방지)
- `_requirePlayerId`: `authBindings.status == active` 검사 추가

### Rules (`firestore.rules`)

- `manualVerificationRequests` 전체 CRUD 경계 (create·update OR 체인)
- `validManualVerificationOperatorWrite` — 운영자 쓰기 단일 진입점
- 분쟁 이벤트 `manualVerificationDisputeOpened` (`players/{id}/events`)
- Task-086 상태 전이: dispute open, defended, transfer, operator force

### 문서·테스트

- `docs/architecture/OPERATOR_AUTHORIZATION_CONTRACT.md` — Task-086 관련 보강(미커밋 diff)
- `test/features/manual_verification/**` — 도메인·UI 테스트
- `test/features/operator_access/data/operator_rules_contract_test.dart` — Rules 문자열 계약
- `tools/manual_verification_rules_test.mjs` — Emulator용 스크립트 (`npm install`은 `tools/`에서, **`tools/node_modules`는 gitignore·커밋 제외**)

---

## 4. 디버깅 중 시도한 수정 (시간순 요약)

| # | 내용 | 결과 |
| --- | --- | --- |
| 1 | `validManualVerificationOperatorForce` OR 체인 맨 앞 `get()` 호출 | 취소·분쟁에도 영향 가능 → `validManualVerificationOperatorWrite`로 통합 | 취소 성공까지 확인, 승인·분쟁은 여전히 실패 |
| 2 | `_openDispute` Transaction 분리 vs 원자 복구 | 이벤트를 Transaction 밖으로 분리·getAfter→get | 미해결 |
| 3 | `unchangedManualVerificationIdentity` 완화·expiresAt 검사 제거 | 취소에 유리 | 취소 OK |
| 4 | `reviewedAt`/`resolvedAt`의 `== request.time` 제거, `updatedAt`만 엄격 검증 | 다중 serverTimestamp Rules 불일치 가설 | 미해결 |
| 5 | `ownerResponseDeadlineAt > request.time` 제거 (기기·서버 시각 차이) | 분쟁 전용 | 미해결 |
| 6 | 강제 인증 Rules에서 `manualVerificationForceOwnerPlayerId` 서버 재조회 제거 | 클라이언트와 Rules owner 불일치 가설 | 미해결 |
| 7 | 오류 메시지에 Firebase 원문 + `OperatorWriteReadiness` 표시 | 운영자 데이터 정상 확인 | — |

**Rules 배포:** `firebase deploy --only firestore:rules --project lost-party` 다수 회 (최종 2026-08-29, `uploading rules` 확인).

---

## 5. 아직 확인되지 않은 원인 후보

우선순위 순으로, **다음 작업자가 Emulator로 검증할 항목**.

### A. 승인·강제 인증 — Transaction 다문서 쓰기

`reviewApprove`(무소유), `reviewForceApprove`는 `_claimForRequester` Transaction으로 다음을 동시에 쓴다.

- `gameAccounts/{id}`
- `characters/{id}` (복수)
- `characterIdentityClaims/{identityKey}` (복수)
- `playerGameAccounts/{playerId}_{gameAccountId}`
- `manualVerificationRequests/{requestId}`

`gameAccounts`·`characters` 등은 `allow write: if signedIn()` 이나, **`playerGameAccounts` update**는 `changesRepresentativeCharacter` 분기가 있다. ownershipLost·status만 바꿀 때 Rules가 거절하는지 **Emulator로 Transaction 단위 재현** 필요.

### B. 분쟁 개시 — 단일 `manualVerificationRequests` update

취소와 동일 컬렉션이지만 `validManualVerificationDisputeOpenBody` 필드·`affectedKeys().hasOnly(...)` 불일치 가능.

- `disputeOpenedAt` / `reviewedAt` serverTimestamp가 Rules에서 `is timestamp`를 통과하는지
- 기존 문서에 `targetGameAccountId`가 이미 있을 때 `affectedKeys` 집합
- 실제 Firestore 문서 필드와 `_createPayload` 스키마 차이(구버전 요청 문서)

### C. Rules `get()` 10회 한도 (Transaction)

한 Transaction에 쓰기가 많을 때 Rules 평가 `get()` 합이 10을 넘으면 전체가 `permission-denied`로 보인다. 취소는 단일 update라 통과, 승인 Transaction만 실패하는 패턴과 일치할 수 있다.

### D. 앱·Rules 버전 불일치

Rules만 배포하고 앱을 재빌드하지 않으면 구 메시지·구 payload가 남는다. 최신 진단 UI가 보이면 앱은 어느 정도 맞춰진 상태.

### E. 배포 대상 프로젝트

앱 `firebase_options`와 `firebase deploy --project lost-party` 일치는 확인됨. 다른 Firestore DB `(default)` 외 인스턴스는 사용하지 않음.

---

## 6. 현재 Rules 구조 (운영자 update 요약)

`manualVerificationRequests` `allow update`:

```text
validManualVerificationRequesterCancel
|| validManualVerificationReissue
|| validManualVerificationOperatorWrite
|| validManualVerificationDisputeTransfer
```

`validManualVerificationOperatorWrite`:

- `isActiveOperator()`
- `newData.reviewedByOperatorPlayerId == currentPlayerId()`
- `newData.updatedAt == request.time`
- `newData.status != 'transferred'` → review / disputeOpen / disputeDefended body
- `newData.status == 'transferred'` → force body (owner 서버 lookup 제거된 상태)

**취소가 통과한다는 것은** 위 공통 조건 + `validManualVerificationOperatorReviewBody`(cancelled)는 **프로덕션 데이터에서 성립**한다는 뜻이다.

---

## 7. 변경 파일 (git status 기준, 2026-08-29)

### 수정됨 (M)

- `firestore.rules`, `firestore.indexes.json`
- `lib/features/manual_verification/**` (신규 디렉터리는 `??`)
- `lib/features/operator_access/**`
- `lib/app/router/app_router.dart`, `lib/app/shell/app_shell.dart`
- `lib/features/settings/presentation/pages/settings_page.dart`
- `docs/architecture/OPERATOR_AUTHORIZATION_CONTRACT.md`
- `docs/project/DEV_LOG.md`, `NEXT_WORK.md`, `AI_CONTEXT.md`
- 관련 테스트

### 미추적 (??)

- `lib/features/manual_verification/` (전체)
- `lib/features/operator_access/domain/entities/operator_write_readiness.dart`
- `test/features/manual_verification/`
- `tools/` (Rules Emulator 테스트용, `node_modules` 포함 — **커밋 제외 권장**)

---

## 8. 작업 재개 시 권장 순서

1. **Firestore Emulator + Rules unit test** (`tools/manual_verification_rules_test.mjs` 확장)
   - 운영자 seed → cancel / dispute open / approved / force 각각 단독 update
   - 이어서 `_claimForRequester`와 동일 필드집합의 Transaction 시뮬레이션

2. **실패 경로 한정 재현**
   - 무소유 **승인**만
   - 기존 소유자 **분쟁 개시**만
   - **강제 인증**만  
   각각 Firebase Console Rules Playground 또는 Emulator로 `resource`/`request.resource` 덤프

3. **Rules vs 클라이언트 diff**
   - 실패한 요청 문서 id 하나를 Console에서 export
   - `reviewApprove` / `_openDispute` / `_claimForRequester`가 쓰는 필드와 `affectedKeys().hasOnly` 대조

4. **Transaction 분해 실험** (임시)
   - 무소유 승인을 request update만 먼저 허용해 보고, gameAccounts 쓰기를 단계적으로 추가해 **어느 문서에서 deny 나는지** 이진 탐색

5. **계약 정합**
   - `OPERATOR_AUTHORIZATION_CONTRACT.md` §9 Task-086과 구현·Rules 최종 대조 후 커밋

6. **Git**
   - 블로커 해소 전 `main` 병합 보류
   - `tools/node_modules`는 `.gitignore` 또는 커밋 제외

---

## 9. 명시적 비범위 (이번 중지 시점)

- 운영자 Console 재지정 반복 요청 (데이터는 진단상 정상)
- Callable / Admin SDK 도입
- FCM 분쟁 알림
- 사용자 삭제·강제 삭제

---

## 10. 관련 문서

- [`OPERATOR_AUTHORIZATION_CONTRACT.md`](../../../../docs/architecture/OPERATOR_AUTHORIZATION_CONTRACT.md)
- [`BUG_REPORTS.md`](../../../../docs/project/BUG_REPORTS.md) — BUG-008
- [`NEXT_WORK.md`](../../../../docs/project/NEXT_WORK.md) — Task-086 중지 상태
- [`DEV_LOG.md`](../../../../docs/project/DEV_LOG.md) — Task-086 중지 항목

---

## 11. 해결 전 한 줄 결론 (역사 기록)

당시에는 운영자 취소를 제외한 쓰기가 막혀 작업을 중단했다. 이후 선택 필드 접근 Rules 오류를 수정·배포해 운영자 쓰기와 소유권 이전 경로를 실기기에서 확인했고 BUG-008을 종료했다. 현재 남은 검증은 실제 24시간 무응답 자동 이전뿐이다.
