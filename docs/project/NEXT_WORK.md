# NEXT WORK

## 문서의 역할

이 문서는 다음 구현 작업의 단일 인수인계 기준이다. 누적 이력은 `DEV_LOG.md`, 전체 제품 규칙은 `AI_CONTEXT.md`와 architecture/product 문서를 사용한다. 작업 시작 시 실제 `git status`, `git log -3`과 대조한다.

## 현재 기준 상태

| 구분 | 상태 | 비고 |
| --- | --- | --- |
| 통합 기준 | **`main` = Task-068까지** | 고정 슬롯 쓰기·구성판·승인 점유 get |
| Firestore Rules | 슬롯 필드 + 점유 get **배포됨** | `lost-party` |
| 직전 브랜치 | `cursor/party-fixed-slots` | `main`에 병합됨 |

### Task-068 실기기 확인됨 (2026-08-26)

- 생성·즉시 가입 시 `slotIndex` 기록
- 현황 상세 고정 슬롯 Card(점유·빈자리)
- 승인 가입(신청자 점유 get Rules 수정 후)
- 거절은 기존과 동일하게 동작

## 확정된 협업 역할

- Codex: 설계·계약·문서·인수인계.
- Cursor: 구현·빌드·표적 테스트.
- 계약 변경이 필요하면 문서에 먼저 반영한다.

## 다음 작업

1. **자기 참가 캐릭터 변경 · 탈퇴 · 추방** 등 멤버 명령 UI/실행 앱 연결
   - 캐릭터 변경은 기존 `partyIndex`·`slotIndex`를 유지한다.
   - 탈퇴·추방 후 남은 멤버를 자동으로 앞자리로 당기지 않는다.
2. **회차 완료 · 완료 취소 · 종료 · 해산** 명령 연결
   - 반복 파티의 주차 전환과 다인 방 일괄 해산을 포함한다.
3. **알림 서비스 별도 설계**
   - 멤버십과 회차 상태가 안정된 뒤 서버 방식, 이벤트, 수신 대상, 전체·방별 설정과 OS 권한을 함께 결정한다.
   - 현재 파티 이벤트는 향후 앱 내부 알림함과 FCM 발송의 공통 원본으로 사용할 수 있게 유지한다.
   - 서버 방식이 확정되기 전에는 앱 내부 알림함이나 FCM 발송을 선행 구현하지 않는다.
   - 유료 플랜 금지 제약 안에서 Cloud Functions, 별도 서버 또는 구현 보류를 비교한다.
4. **파티 상세의 멤버 전용 최근 10개 텍스트 채팅**
5. **빈 슬롯별 원하는 역할·직업군·시너지 조건의 제품 계약과 설정 UI**
6. **전체 공개 파티 목록의 모집 조건 필터**
   - 빈 슬롯 조건과 같은 판정 기준을 사용한다.
7. **레이드 현황 공통 필터**
   - 가입한 파티, 신청한 파티와 완료 기록에 같은 필터 UI를 적용한다.
8. 파티 내 자리 이동 및 확정 파티 간 이동·스왑 설계
9. 그룹과 그룹 전용 모집

### 슬롯·이행 잔여 메모

- 신규 생성·가입은 `(partyIndex, slotIndex)`를 저장한다.
- `slotIndex`가 없는 기존 membership은 구성판에서 **자리 미정**으로 표시한다. 가입 계산 시에는 리더·`joinedAt`·`playerId` 순으로 점유를 추정하되 기존 문서를 자동 rewrite하지 않는다.
- 빈 슬롯 조건 UI와 자리 이동 명령은 후속 작업이다.

### 상세 채팅 범위

- 멤버십과 회차 종료·해산이 안정된 뒤 구현한다. 알림 서버 결정이 채팅의 필수 선행 조건은 아니다.
- 파티 상세에 진입한 현재 멤버만 최근 메시지 약 10개를 실시간으로 읽고 쓸 수 있다.
- 표시 내용은 캐릭터명 또는 표시 ID와 짧은 텍스트이며 이미지·파일·읽음 상태·푸시 알림은 초기 범위에서 제외한다.
- 메시지는 개별 문서로 저장하고 `createdAt desc`, `limit(10)`만 구독한다. 상세 화면 이탈 시 listener를 해제하며 목록·다른 탭에서는 읽지 않는다.
- 메시지 길이와 연속 전송을 제한하고 서버 timestamp, 멤버 권한 Rules, 파티 완료·해산 후 접근 정책을 구현 전에 확정한다.

## 제외 범위 (당분간)

- FCM·TTL·Functions·Blaze·Emulator
- 대규모 UI 개편
- 멤버십과 회차 종료·해산보다 알림·채팅·필터를 먼저 구현하는 작업
- 기존 방 membership에 `slotIndex`를 일괄 rewrite하는 마이그레이션 배치

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
- `../product/DETAIL_IMPROVEMENTS.md`
