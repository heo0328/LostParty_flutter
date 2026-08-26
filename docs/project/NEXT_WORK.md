# NEXT WORK

## 문서의 역할

이 문서는 다음 구현 작업의 단일 인수인계 기준이다. 누적 이력은 `DEV_LOG.md`, 전체 제품 규칙은 `AI_CONTEXT.md`와 architecture/product 문서를 사용한다. 작업 시작 시 실제 `git status`, `git log -3`과 대조한다.

## 현재 기준 상태 (꼬임 방지용 한 장 요약)

| 구분 | 상태 | 비고 |
| --- | --- | --- |
| 통합 기준 | `main` = Task-065까지 | Task-066은 **아직 main 미병합** |
| 구현 브랜치 | `cursor/party-join-approve-reject` | HEAD 예: `ed7ec10` |
| Firestore Rules (서버) | **배포됨** (2026-08-26) | `canGetRecruitmentApplication` 포함. 신청 get 수정이 여기에 있음 |
| 신청(지원하기) | **실기기에서 성공 확인됨** | Rules 배포 후 신청·신청 리스트 OK |
| 승인 | **실패 보고됨 · 미수정** | 신청 수정과 **별개 경로**. 다음 수정 대상 |
| 거절 / 철회 / 즉시가입 | **아직 실기기 미확인 또는 미보고** | 아래 체크리스트 |

### 커밋을 섞지 말 것

1. `3cfd835` — 없는 application **get** Rules + 인증 UI 복원 등. **Rules 배포로 신청이 풀린 핵심.**
2. `ed7ec10` — 신청/즉시가입에 `targetCycleKey` 사용·문서. `current == target`인 일반 방에서는 신청 동작과 **동일**. 이미 되는 신청을 되돌리지 않음.
3. **승인 실패는 위 두 커밋의 “미배포” 문제가 아님.** 승인 Transaction·Rules는 신청 create와 다름. 다음 Cursor 작업은 승인부터.

코드만 고치고 Rules를 안 올리면 다시 꼬인다. Rules를 바꿀 때는 배포 여부를 이 문서와 `DEV_LOG`에 같은 날 적는다.

## 확정된 협업 역할

- Codex: 설계·계약·작업 분해·문서 정합성·인수인계.
- Cursor: 주 코드 구현·빌드·표적 테스트.
- 계약 변경이 필요하면 Cursor가 임의 확장하지 않고 문서에 먼저 기록한다.
- 완료 시 코드, 테스트, 문서와 실제 Git 상태를 함께 갱신한다.
- **2기기 검증·승인 수정이 끝나기 전까지 `main` 병합·푸시하지 않는다.**

---

## 지금 사용자가 할 테스트 (우선순위)

앱은 브랜치 `cursor/party-join-approve-reject` 기준이면 된다. Rules는 이미 서버에 있다.  
**신청을 처음부터 전부 반복할 필요는 없다.** (이미 OK로 기록됨)

경로: Fake `/recruitments/:id`가 아니라 **`/raid-status/{id}`**.  
기기 A = 파티장, 기기 B = 다른 Auth/Player 신청자.

### 1순위 — 승인 (지금 막힌 구간)

1. 기기 A: 승인형(`파티장 승인`) 모집 생성 → 상세 진입.
2. 기기 B: 같은 방 **지원하기** → 성공·신청 리스트에 뜨는지 확인 (이미 됐으면 스킵 가능).
3. 기기 A: `가입 신청 관리`에서 해당 pending → **승인**.
4. **기록할 것**
   - 성공이면: 토스트 `가입 신청을 승인했습니다.` / B가 파티 구성에 보이는지 / pending이 줄었는지.
   - 실패면: **토스트 문구 전문** (예: 권한·구성·소유권·revision 등). 가능하면 A/B 중 어느 기기인지.

→ 결과만 알려주면 Cursor는 **승인만** 이어서 수정한다. 신청 Rules를 다시 건드리지 않는다.

### 2순위 — 같은 승인형에서 거절·철회

1. (새 신청 후) 기기 A **거절** → pending 제거, B 상태 거절됨.
2. (새 신청 pending 중) 기기 B **신청 철회** → `신청을 철회했습니다.`

### 3순위 — 즉시 가입형

1. 기기 A: `승인 없이 바로 가입` 모집 생성.
2. 기기 B: **바로 가입** → `파티에 참가했습니다.` / 멤버 반영.
3. 기기 A: 승인·거절 UI가 불필요하게 안 뜨는지.

### 확인만 하면 되는 것 (회귀)

- 목록·상세 파티장·파티원 표시 유지.
- 본인 방에는 지원하기 없음, 파티장에게만 신청 관리.

### 굳이 다시 안 해도 되는 것

- Rules 재배포 (이미 완료).
- “신청 권한 확인 실패”만 재현하려고 앱 재시작 반복.
- `targetCycleKey` 클라이언트 변경이 신청을 깨는지 의심하는 장기 회귀 (일반 방에서는 동등).

### 결과 보고 형식 (복붙용)

```
[Task-066 실기기]
브랜치/빌드: cursor/party-join-approve-reject (또는 커밋 짧게)
승인: 성공 / 실패 — 토스트: "..."
거절: 미실시 / 성공 / 실패 — 토스트: "..."
철회: 미실시 / 성공 / 실패 — 토스트: "..."
즉시가입: 미실시 / 성공 / 실패 — 토스트: "..."
기타:
```

---

## Task-066 코드 상태 (참고)

- `PublicRecruitmentSummary.approvalMode`, `watchRecruitmentApplications`
- 상세에 `FirestorePartyJoinCommandRepository` (승인·거절·즉시가입)
- 신청 get Rules + 인증 진행 UI 복원 + 신청 시 `targetCycleKey`
- 멤버·회차와 Fake `/recruitments/:id`는 Fake 유지
- Emulator / FCM / TTL / 유료 기능 미사용

### 제외 범위

- FCM·OS 알림, TTL 배포, Cloud Functions·Blaze, Emulator
- 멤버·회차 명령 전환, 캐릭터 변경·탈퇴·추방·승인 권한 변경 UI
- 파티 자리 이동·스왑, 철회 후 재신청 Transaction, 대규모 UI 개편

## 다음 Cursor 재개 조건

- 사용자가 위 **결과 보고**를 주면, **승인(및 보고된 실패만)** 수정한다.
- 승인 수정 시 Rules를 바꾸면 **같은 응답에 배포 여부**를 적고, 필요 시 즉시 `firebase deploy --only firestore:rules` 한다.
- 검증·수정 끝나기 전 `main` 병합·푸시하지 않는다.

## 후속 순서

1. Task-066 승인·거절·철회·즉시가입 실기기 통과 → `main` 병합
2. 자기 캐릭터 변경·탈퇴·추방 등 멤버·회차 명령
3. 파티 내 자리 이동 및 확정 파티 간 이동·스왑 설계
4. 그룹과 그룹 전용 모집

## 지속 운영 제약

- 별도 지시 전까지 외부 유료 플랜·결제수단·초과 과금 가능 기능을 사용하지 않는다.
- Emulator는 목적·실패·종료 조건을 제시하고 명시 승인 후에만.
- 실기기를 대체하는 무의미한 전체 테스트 반복을 하지 않는다.
- AuthUid·API 토큰·민감 식별자를 UI·로그·문서 예시에 노출하지 않는다.
- Android Drift native assets를 임의 삭제하지 않는다.
- 네트워크 요청 버튼은 진행 중 비활성 또는 동일 동작 무시.

## 참고 문서

- `AI_CONTEXT.md`
- `DEV_LOG.md`
- `ai_rules.md`
- `../architecture/FIREBASE_PARTY_PRODUCT_FLOW.md`
- `../architecture/FIRESTORE_PARTY_READ_MODEL_CONTRACT.md`
- `../architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md`
- `../architecture/FIRESTORE_PARTY_EVENT_CONTRACT.md`
- `../architecture/GAME_ACCOUNT_CHARACTER_FIREBASE_CONTRACT.md`
- `../architecture/GAME_ACCOUNT_VERIFICATION_CONTRACT.md`
- `../product/PARTY_PARTICIPATION_RULES.md`
