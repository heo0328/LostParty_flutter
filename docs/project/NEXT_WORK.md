# NEXT WORK

## 문서의 역할

이 문서는 다음 구현 작업의 단일 인수인계 기준이다. 누적 이력은 `DEV_LOG.md`, 전체 제품 규칙은 `AI_CONTEXT.md`와 architecture/product 문서를 사용한다. 작업 시작 시 실제 `git status`, `git log -3`과 대조한다.

## 현재 기준 상태

| 구분 | 상태 | 비고 |
| --- | --- | --- |
| 통합 기준 | `main` = Task-065까지 | |
| 구현 브랜치 | `cursor/party-join-approve-reject` (Task-066) | **실기기 핵심 흐름 통과** |
| Firestore Rules | 신청 get + 재신청 Rules **배포됨** | |
| `main` 병합 | **사용자 승인 대기** | 아래 확인됨 목록 기준 |

### Task-066 실기기 확인됨 (2026-08-26)

- 거절 시 N회 안내 · **다시 신청** · **캐릭터 재선택** 가능
- 단독 방 **모집 삭제** 정상
- **승인** 정상
- **신청 철회** 정상
- **미승인(즉시 가입) 방** 가입 정상
- 신청·신청 리스트 (Rules 배포 이후) 정상

### 아직 후속인 것

- 다인 방 일괄 해산
- 멤버 캐릭터 변경·탈퇴·추방 UI 연결
- 회차 명령, 자리 이동·스왑
- FCM·TTL·Functions·Blaze·Emulator

## 확정된 협업 역할

- Codex: 설계·계약·문서·인수인계.
- Cursor: 구현·빌드·표적 테스트.
- 계약 변경이 필요하면 문서에 먼저 반영한다.

## 다음 작업

1. 사용자 지시 시 Task-066 브랜치를 **`main`에 병합·푸시**한다.
2. 이후: 자기 캐릭터 변경·탈퇴·추방 등 멤버 명령과 회차 명령.
3. 파티 내 자리 이동 및 확정 파티 간 이동·스왑 설계.
4. 그룹과 그룹 전용 모집.

## 제외 범위 (당분간)

- FCM·TTL·Functions·Blaze·Emulator
- 다인 방 일괄 해산
- 대규모 UI 개편

## 지속 운영 제약

- 유료 플랜·결제·과금 가능 기능 금지(별도 지시 전).
- Emulator는 명시 승인 후에만.
- AuthUid·토큰·민감 ID 비노출.
- Drift native assets 임의 삭제 금지.
- 네트워크 버튼 연타 방지.

## 참고 문서

- `AI_CONTEXT.md`, `DEV_LOG.md`, `ai_rules.md`
- `../architecture/FIREBASE_PARTY_PRODUCT_FLOW.md`
- `../architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md`
- `../architecture/FIRESTORE_PARTY_READ_MODEL_CONTRACT.md`
- `../product/PARTY_PARTICIPATION_RULES.md`
