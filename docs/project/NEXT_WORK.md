# NEXT WORK

## 문서의 역할

이 문서는 Cursor가 다음 구현 작업과 이후 순서를 판단하는 단일 인수인계 기준이다.

- **현재 실행 작업**에 적힌 한 작업만 구현한다.
- **후속 작업 큐**는 순서 확인용이며 현재 작업 범위에 함께 포함하지 않는다.
- 현재 작업을 구현·자동 검증·실기기 확인·문서화·병합한 뒤 다음 항목을 현재 실행 작업으로 올린다.
- 누적 완료 이력은 `DEV_LOG.md`, 전체 현재 상태는 `AI_CONTEXT.md`, 제품·기술 계약은 관련 product/architecture/design 문서를 따른다.
- 작업 시작 시 `git status`, 현재 브랜치와 `git log -3`을 이 문서의 기준 상태와 대조한다.

## 현재 기준 상태

| 구분 | 상태 | 비고 |
| --- | --- | --- |
| 통합 기준 | **`main` = Task-070까지** | 멤버십 명령 + 상세 id 재구독 |
| 완료 기능 | 고정 슬롯·반응형 구성판·캐릭터 변경·탈퇴·추방 | Task-068~070 |
| Firestore Rules | 슬롯·멤버십 관련 **배포됨** (추가 Rules 없음) | Firebase 프로젝트 `lost-party` |
| 현재 코드 상태 | 현황 상세에서 변경·탈퇴·추방·단독 삭제 연결 | Task-070 실기기 통과 |
| 다음 구현 | **Task-071 완료·완료 취소·종료·해산** | 아래 현재 실행 작업만 수행 |

### Task-070 확인 완료 사항 (2026-08-26)

- 자기 참가 캐릭터 변경: 역할·`(partyIndex, slotIndex)` 유지
- 본인 탈퇴: 다인 방 잔여 자리 비당김, 책임자 탈퇴 시 승계
- 책임자 추방: 확인 후 membership·점유 제거
- 단독 모집 삭제는 1인일 때만 (기존 연결 유지)
- BUG-001: 상세 `recruitmentId` 변경 시 `ValueKey`·`restart`로 구독 재연결 (종료)

### 열린 버그 (수정은 별도 작업)

- `BUG_REPORTS.md`의 **BUG-002**(4인 목록 vs 8인 구성 표시). Task-071과 묶지 않는다.

## 전체 작업 순서

순서는 다음과 같다. 번호가 뒤인 작업을 앞 작업과 묶어서 구현하지 않는다.

| 순서 | 작업 | 시작 조건 | 결과 |
| --- | --- | --- | --- |
| 1 | Task-069 파티 구성판 반응형 그룹 배치 | **완료** | 모바일 전체 폭 Card, 넓은 화면 파티 좌우 배치 |
| 2 | 자기 참가 캐릭터 변경·탈퇴·추방 연결 | **완료** | 자유로운 멤버십 명령 UI 완성 |
| 3 | **완료·완료 취소·종료·해산 연결** | Task-070 종료 | 파티·회차 수명주기 완성 |
| 4 | 알림 서비스 별도 설계 | 파티 수명주기 완성 | 서버 방식과 수신 정책 결정; 즉시 구현을 의미하지 않음 |
| 5 | 상세 페이지 최근 10개 텍스트 채팅 | 멤버 권한·종료 정책 확정 | 상세 진입 멤버용 최소 채팅 |
| 6 | 빈 슬롯별 역할·직업·시너지 조건 | 슬롯 명령 안정화 | 파티장이 원하는 모집 조건 설정 |
| 7 | 전체 공개 파티 목록 조건 필터 | 슬롯 조건 저장·판정 확정 | 조건에 맞는 공개 모집 탐색 |
| 8 | 레이드 현황 공통 필터 | 공개 목록 필터 UX 확정 | 가입·신청·완료 기록에 동일한 필터 조작 제공 |
| 9 | 파티·슬롯 이동 및 파티 간 스왑 | 기본 멤버십·슬롯 안정화 | 확정 멤버 위치 조정 |
| 10 | 그룹과 그룹 전용 모집 | 핵심 파티 기능 안정화 | 그룹 기반 모집 확장 |

## 현재 실행 작업 — Task-071 완료·완료 취소·종료·해산

### 목표

현황 상세(`/raid-status/:id`)에 회차·방 수명주기 명령을 연결한다.

- 회차 완료 / 완료 취소
- 반복 파티의 주차 전환·미완료 종료 구분
- 다인 방 해산 (단독 모집 삭제와 혼동 금지)

기존 `PartyCycleCommandRepository`(`complete` / `cancelCompletion` / `setRecurrence` / `advance`)와 WritePlan·Rules·Player 이벤트를 재사용한다.

### 변경 대상 (예상)

- `lib/features/raid_status/presentation/pages/party_read_detail_page.dart`
- 필요 시 ViewModel·확인 다이얼로그용 private Widget
- `FirestorePartyCycleCommandRepository` 앱 DI/라우터 연결
- 표적 위젯/ViewModel 테스트
- Drift 완료 기록 동기화는 기존 이벤트 동기화 경로를 확인·재사용

### 구현 기준

- 완료·완료 취소·종료·해산의 권한·확인 알림창을 제품 계약에 맞춘다.
- 1회성 완료 후 해산과 반복 파티의 `continueTogether`·주차 전환을 구분한다.
- 현재 참가자 Snapshot·로컬 완료 기록 동기화를 기존 이벤트 계약에 맞춘다.
- 네트워크 버튼 연타 방지.
- AuthUid·PlayerId·민감 ID를 UI·토스트에 노출하지 않는다.

### 제외 범위

- 알림함·FCM·서버 알림 설계 구현
- 채팅·필터·빈 슬롯 조건
- 파티·슬롯 이동과 스왑
- 멤버십 명령(변경·탈퇴·추방) 재작업
- 구성판 레이아웃 재작업
- BUG-002 조사/수정

### 자동 검증

```text
flutter test (표적: 상세·회차 관련)
flutter analyze
```

### 완료 조건

- 현황 상세에서 완료·완료 취소·종료/해산이 동작하고 실기기 확인
- 표적 테스트·analyze 통과
- `DEV_LOG.md`·`AI_CONTEXT.md`·본 문서 갱신 후 `main` 병합

## 후속 작업별 범위 메모

### 4. 알림 서비스 별도 설계

- 가입·탈퇴·승인·추방·완료·종료·해산 이벤트는 향후 알림 원본으로 유지한다.
- 핵심 파티 흐름 완료 후 Cloud Functions, 별도 서버 또는 구현 보류를 비교한다.
- 서버 방식 확정 전에는 앱 내부 알림함이나 FCM을 임시 구현하지 않는다.
- 유료 플랜·결제·과금 가능 기능은 사용자 별도 지시 없이 활성화하지 않는다.

### 5. 상세 채팅

- 상세에 진입한 현재 멤버만 최근 메시지 약 10개를 읽고 전송한다.
- `createdAt desc`, `limit(10)`만 구독하고 화면 이탈 시 listener를 해제한다.
- 이미지·파일·읽음 상태·목록 미리보기·채팅 FCM은 초기 범위에서 제외한다.
- 메시지 길이, 연속 전송, 서버 timestamp, 멤버 Rules와 완료·해산 후 접근 정책을 구현 전에 확정한다.

### 6~8. 조건과 필터

- 빈 슬롯 조건 문서·저장·판정 계약을 먼저 확정한다.
- 전체 공개 목록 필터는 같은 역할·직업·시너지 판정 기준을 사용한다.
- 레이드 현황의 진행 중·신청 중·완료 기록은 공개 목록과 같은 필터 표현·조작을 재사용한다.
- UI와 필터 값 객체는 재사용할 수 있지만 Firestore query와 Drift 완료 기록 Repository를 하나로 합치지 않는다.

## 지속 운영 제약

- 유료 플랜·결제·과금 가능 기능 금지(별도 지시 전)
- Emulator는 명시 승인 후에만 사용
- AuthUid·토큰·민감 ID 비노출
- Drift native assets 임의 삭제 금지
- 네트워크 버튼 연타·중복 요청 방지
- 계약 변경이 필요하면 코드보다 문서를 먼저 수정
- 한 작업 그룹에 후속 기능을 끼워 넣지 않음

## 참고 문서

현재 Task-071에서 읽어야 할 문서:

1. [`../architecture/FIREBASE_PARTY_PRODUCT_FLOW.md`](../architecture/FIREBASE_PARTY_PRODUCT_FLOW.md)
2. [`../architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md`](../architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md)
3. [`../architecture/FIRESTORE_PARTY_EVENT_CONTRACT.md`](../architecture/FIRESTORE_PARTY_EVENT_CONTRACT.md)
4. [`../product/PARTY_PARTICIPATION_RULES.md`](../product/PARTY_PARTICIPATION_RULES.md)
5. [`ai_rules.md`](ai_rules.md)

열린 결함:

- [`BUG_REPORTS.md`](BUG_REPORTS.md)

추가로:

- [`../architecture/FIRESTORE_PARTY_READ_MODEL_CONTRACT.md`](../architecture/FIRESTORE_PARTY_READ_MODEL_CONTRACT.md)
- [`AI_CONTEXT.md`](AI_CONTEXT.md)
- [`DEV_LOG.md`](DEV_LOG.md)
- [`../product/DETAIL_IMPROVEMENTS.md`](../product/DETAIL_IMPROVEMENTS.md)
