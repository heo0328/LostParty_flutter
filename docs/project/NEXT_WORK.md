# NEXT WORK

## 문서의 역할

이 문서는 다음 구현 작업의 단일 인수인계 기준이다. 누적 이력은 `DEV_LOG.md`, 전체 제품 규칙은 `AI_CONTEXT.md`와 architecture/product 문서를 사용한다. 작업 시작 시 실제 `git status`, `git log -3`과 대조한다.

## 현재 기준 상태 (꼬임 방지)

| 구분 | 상태 | 비고 |
| --- | --- | --- |
| 통합 기준 | `main` = Task-065까지 | Task-066·후속은 **main 미병합** |
| 구현 브랜치 | `cursor/party-join-approve-reject` | |
| Firestore Rules | 신청 get 수정 **배포됨** (2026-08-26) | |
| 신청·신청 리스트 | 실기기 **성공** | |
| 승인 | 실패 보고 · **보류** | 아래 우선순위가 승인보다 앞섬 |
| 거절 후 재신청 | **막힘 · 수정 예정** | 방(모집) 단위여야 함. 지금은 같은 방 재신청 불가 |
| 내 모집 삭제 | **1차 완료** (단독 방 leave 해산) | 다인 방 해산은 후속 |
| 거절 후 재신청 | **구현 완료 · Rules 배포 후 검증** | 방 단위 + N회 안내 |
| 합동 실기기 테스트 | **Step B 배포 후** | 아래 Step C |

### 사용자 확정 우선순위 (2026-08-26)

1. **내가 만든 모집방 삭제(해산)** — 테스트 정리·재현용. 먼저 넣는다.
2. **거절 기억은 방(recruitment) 단위** + **거절 후에도 재신청 가능** + UI에 **이 방에서 N회 거절** 안내.
3. 그다음 승인·거절·재신청·삭제를 **한 번에** 실기기 테스트.

승인 단독 수정은 이 순서 뒤로 미룬다. Rules를 바꾸면 배포 여부를 같은 날 문서에 적는다.

### 거절 범위 — 원인 메모 (구현 전)

- Firestore 신청 문서는 `recruitments/{id}/applications/{playerId}` **방×Player** 단위다. 캐릭터가 달라도 같은 Player면 같은 문서다.
- 현재 `apply`는 `application.exists`이면 무조건 `applicationAlreadyExists`라 **거절·철회 뒤 같은 방 재신청이 불가**하다. (의도한 제품과 불일치)
- “A의 **모든** 방에 B의 **모든** 캐릭터가 막힘”은 위 규칙만으로는 설명되지 않는다. 재신청·삭제 구현 후 재현해 분리한다. 우선은 **방 단위 재신청**을 맞춘다.

### 제품 규칙 (이번 작업에서 고정)

- 거절/재신청 이력은 **모집방(recruitmentId) 단위**. 계정·캐릭터 전역 블랙리스트 아님.
- 거절된 뒤 **같은 방에 다시 신청 가능**.
- 재신청 UI(또는 신청 전)에 **이 방에서 거절당한 횟수 N**을 알려 준다 (`rejectionCount` 활용 예정).
- 모집 “삭제”는 사용자 관점 삭제이며, 서버는 계약대로 `disbanded` 등 종료 상태(하드 삭제 아님). 1차: **파티장 단독 방**은 본인 leave로 해산. 다인 방 일괄 해산은 후속.

---

## 확정된 협업 역할

- Codex: 설계·계약·문서·인수인계.
- Cursor: 구현·빌드·표적 테스트.
- 계약 확장이 필요하면 문서에 먼저 반영하고 구현한다.
- **합동 검증·수정 끝나기 전 `main` 병합·푸시하지 않는다.**

---

## Cursor 구현 순서 (지금)

### Step A — 내 모집 삭제 (1차 완료)

- `/raid-status/{id}` 파티장에게 **모집 삭제** 버튼.
- `memberCount == 1`이면 membership `leave`로 `disbanded`.
- `memberCount > 1`이면 안내 후 거부(다인 해산은 후속).
- Rules 추가 배포 없음(기존 leave/해산 Rules 사용).

### Step B — 방 단위 재신청 + N회 거절 안내 (완료)

- `rejected`/`withdrawn`/`superseded` → 같은 문서 `pending` 갱신. `rejectionCount` 유지.
- 상세 UI: `이 방에서 N회 거절` + **다시 지원하기**.
- Rules `validApplicationReapply` 추가 → **배포 필요**.

### Step C — 합동 실기기 테스트 (지금)

기기 A=파티장, B=신청자. 경로 `/raid-status/{id}`.

1. A 방 생성 → B 신청 → A 거절 → B **같은 방** 다른/같은 캐릭터 재신청 가능 + N 안내.
2. B가 A의 **다른 방**에도 신청 가능(전역 차단 아님).
3. A **모집 삭제** → 목록/상세에서 모집 중으로 안 보임.
4. 승인·철회·즉시가입 회귀.

보고 형식:

```
[합동 테스트]
삭제: 성공/실패 — ...
거절 후 재신청: 성공/실패 — N 표시: ...
다른 방 신청: 성공/실패 — ...
승인: ...
기타:
```

---

## 이전 커밋 참고 (섞지 말 것)

1. `3cfd835` — application 없는 문서 get Rules + 인증 UI. **배포로 신청 회복.**
2. `ed7ec10` — `targetCycleKey` 클라이언트. 일반 방은 신청과 동등.
3. 승인 실패·거절 재신청·삭제는 **별 이슈**. 삭제·재신청이 우선.

## 제외 범위 (당분간)

- FCM·TTL·Functions·Blaze·Emulator
- 멤버 캐릭터 변경·추방 UI 전반, 자리 이동·스왑
- 다인 방 일괄 해산(Step A 1차 이후)
- 대규모 UI 개편

## 후속 순서

1. Step A → B → C 통과 후 Task-066 마무리 → `main` 병합
2. 멤버·회차 명령
3. 자리 이동·스왑 설계
4. 그룹 모집

## 지속 운영 제약

- 유료 플랜·결제·과금 가능 기능 금지(별도 지시 전).
- Emulator는 명시 승인 후에만.
- AuthUid·토큰·민감 ID 비노출.
- Drift native assets 임의 삭제 금지.
- 네트워크 버튼 연타 방지.

## 참고 문서

- `AI_CONTEXT.md`, `DEV_LOG.md`, `ai_rules.md`
- `../architecture/FIREBASE_PARTY_PRODUCT_FLOW.md` (해산)
- `../architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md`
- `../architecture/FIRESTORE_PARTY_READ_MODEL_CONTRACT.md`
- `../product/PARTY_PARTICIPATION_RULES.md`
