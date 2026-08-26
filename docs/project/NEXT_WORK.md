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
| 통합 기준 | **`main` = Task-068 완료 + 현재 문서 기준** | 고정 슬롯 구현과 반응형 구성판 설계 반영 |
| 완료 기능 | 고정 슬롯 쓰기·구성판·승인 점유 get | Task-068 |
| Firestore Rules | 슬롯 필드 + 점유 get **배포됨** | Firebase 프로젝트 `lost-party` |
| 현재 코드 상태 | 파티 구성판 가용 폭 600dp 이상에서 Slot Card 자체를 2열 배치 | 새 디자인 계약은 아직 미구현 |
| 다음 구현 | **Task-069 파티 구성판 반응형 그룹 배치** | 아래 현재 실행 작업만 수행 |

### Task-068 확인 완료 사항 (2026-08-26)

- 생성·즉시 가입 시 `(partyIndex, slotIndex)` 기록
- 현황 상세에 점유·빈자리 고정 Slot Card 표시
- 승인 가입 시 신청자 슬롯 점유
- 거절 동작 유지
- `slotIndex`가 없는 기존 membership은 `자리 미정`으로 표시

## 전체 작업 순서

순서는 다음과 같다. 번호가 뒤인 작업을 앞 작업과 묶어서 구현하지 않는다.

| 순서 | 작업 | 시작 조건 | 결과 |
| --- | --- | --- | --- |
| 1 | **Task-069 파티 구성판 반응형 그룹 배치** | 즉시 시작 가능 | 모바일 전체 폭 Card, 넓은 화면 파티 좌우 배치 |
| 2 | 자기 참가 캐릭터 변경·탈퇴·추방 연결 | Task-069 종료 | 자유로운 멤버십 명령 UI 완성 |
| 3 | 완료·완료 취소·종료·해산 연결 | 멤버십 명령 안정화 | 파티·회차 수명주기 완성 |
| 4 | 알림 서비스 별도 설계 | 파티 수명주기 완성 | 서버 방식과 수신 정책 결정; 즉시 구현을 의미하지 않음 |
| 5 | 상세 페이지 최근 10개 텍스트 채팅 | 멤버 권한·종료 정책 확정 | 상세 진입 멤버용 최소 채팅 |
| 6 | 빈 슬롯별 역할·직업·시너지 조건 | 슬롯 명령 안정화 | 파티장이 원하는 모집 조건 설정 |
| 7 | 전체 공개 파티 목록 조건 필터 | 슬롯 조건 저장·판정 확정 | 조건에 맞는 공개 모집 탐색 |
| 8 | 레이드 현황 공통 필터 | 공개 목록 필터 UX 확정 | 가입·신청·완료 기록에 동일한 필터 조작 제공 |
| 9 | 파티·슬롯 이동 및 파티 간 스왑 | 기본 멤버십·슬롯 안정화 | 확정 멤버 위치 조정 |
| 10 | 그룹과 그룹 전용 모집 | 핵심 파티 기능 안정화 | 그룹 기반 모집 확장 |

## 현재 실행 작업 — Task-069 파티 구성판 반응형 그룹 배치

### 목표

모집 현황 상세의 Slot Card 내용과 고정 슬롯 계산은 유지하면서 화면 폭에 따라 **Card가 아니라 파티 그룹**의 배치를 전환한다.

- 일반 바형 스마트폰: 각 Slot Card가 파티 구성판의 전체 가로 폭 사용
- 넓은 화면의 4인 파티: 1파티를 왼쪽 절반에 배치하고 오른쪽은 의도적인 여백으로 유지
- 넓은 화면의 8인 공격대: 1파티와 2파티를 좌우 절반에 배치
- 파티 내부의 Slot Card 4개는 모든 화면에서 세로 1열 유지

전체 제품 계약과 breakpoint 판단 기준은 반드시 [`../design/PARTY_COMPOSITION_RESPONSIVE_LAYOUT.md`](../design/PARTY_COMPOSITION_RESPONSIVE_LAYOUT.md)를 먼저 읽고 따른다.

### 변경 대상

- `lib/features/raid_status/presentation/pages/party_read_detail_page.dart`
  - `_PartyCompositionSection`
  - `_SlotCardGrid`
  - 필요한 경우 파티 제목과 Grid를 묶는 작은 private Widget
- `test/features/raid_status/presentation/party_read_detail_page_test.dart`
  - 좁은·넓은 4인/8인 레이아웃 위젯 테스트

새 파일이나 공통 Widget 추출은 현재 파일 안에서 읽기 어려워질 때만 최소화하여 사용한다.

### 구현 순서

1. 기존 `PartySlotBoard`와 `_PartyCompositionSection`의 파티·슬롯 생성 순서를 유지한다.
2. 파티 제목과 해당 파티의 Slot Card 4개를 하나의 파티 그룹으로 묶는다.
3. 파티 그룹에 주어진 실제 `LayoutBuilder.maxWidth`로 좁은/넓은 레이아웃을 결정한다.
4. 좁은 화면에서는 파티 그룹을 세로 1열로 배치한다.
5. 넓은 화면에서는 동일 폭의 두 파티 열을 만든다.
6. 4인 파티는 왼쪽 열만 사용하고 오른쪽에 빈 Card나 안내를 추가하지 않는다.
7. 8인 공격대는 1파티를 왼쪽, 2파티를 오른쪽에 배치한다.
8. `_SlotCardGrid`의 Card 2열 분기를 제거하고 항상 파티 열 전체 폭의 세로 1열로 표시한다.
9. `자리 미정` 영역은 파티 열 밖에서 두 파티 아래 구성판 전체 폭을 유지한다.
10. 표적 위젯 테스트와 `flutter analyze`를 실행한 뒤 바형 스마트폰·펼친 폴드 실기기 확인 항목을 사용자에게 전달한다.

### 구현 기준

- 기기 종류, 플랫폼명 또는 폴더블 모델명을 분기 조건으로 사용하지 않는다.
- 초기 breakpoint 후보는 실제 가용 폭 `720dp`다.
- 단일 breakpoint를 우선 사용하며 검증 없이 여러 breakpoint나 폴더블 패키지를 추가하지 않는다.
- Card 내부 표시 내용, 역할 배지, 빈자리 문구와 스타일 token은 변경하지 않는다.
- 화면 회전·분할 화면처럼 가용 폭이 바뀌면 현재 제약에 따라 다시 배치되어야 한다.
- 시각적 배치가 바뀌어도 읽기·포커스 순서는 `1파티 1~4번 → 2파티 1~4번 → 자리 미정`을 유지한다.
- 고정 높이를 추가하지 않으며 큰 글자와 긴 캐릭터명의 기존 동작을 훼손하지 않는다.

### 제외 범위

- 자기 캐릭터 변경·탈퇴·추방 버튼 또는 Repository 연결
- 완료·종료·해산 명령
- 파티·슬롯 이동과 스왑
- 빈 슬롯의 역할·직업·시너지 조건
- 채팅, 알림과 필터
- `PartySlotBoard`, membership, Firestore 문서와 Rules 변경
- 기존 membership의 `slotIndex` 일괄 rewrite
- Slot Card의 색상·타이포그래피·정보 구조 재디자인

### 자동 검증

최소 다음 케이스를 `party_read_detail_page_test.dart`에 추가하거나 동등한 테스트로 증명한다.

1. breakpoint 미만 4인: 파티 1열, Slot Card 4개 전체 폭
2. breakpoint 미만 8인: 1파티 다음 2파티 세로 배치
3. breakpoint 이상 4인: 1파티 왼쪽 절반, Slot Card는 파티 내부 1열
4. breakpoint 이상 8인: 1파티와 2파티 좌우 동일 폭
5. 넓은 화면에서도 Slot과 파티의 의미 순서 유지
6. `자리 미정`은 파티 그룹 아래 전체 폭 유지
7. 기존 로딩·실패·캐시 안내 회귀 없음

실행 기준:

```text
flutter test test/features/raid_status/presentation/party_read_detail_page_test.dart
flutter analyze
```

순수 UI 변경이므로 위 표적 테스트와 analyze가 통과하고 실기기 확인을 완료하면 전체 `flutter test`는 생략할 수 있다. 관련 범위 밖의 코드까지 변경했다면 영향에 맞춰 전체 테스트를 실행한다.

### 실기기 확인

- 바형 스마트폰 세로: Card가 구성판 가로 폭을 충분히 사용
- 바형 스마트폰 가로: 가용 폭에 따른 자연스러운 전환
- 펼친 폴드 4인: 1파티가 왼쪽 절반, 오른쪽에 불필요한 UI 없음
- 펼친 폴드 8인: 1파티와 2파티가 좌우로 명확히 구분
- 폴드 분할 화면: 실제 폭이 줄면 좁은 레이아웃으로 복귀
- 긴 캐릭터명과 파티장·공대장·역할 배지가 잘리거나 심하게 겹치지 않음

### 완료 조건

- 디자인 계약의 좁은·넓은 4인/8인 배치가 구현됨
- Slot Card는 모든 화면에서 파티 내부 1열을 유지함
- 파티 데이터, 슬롯 계산, 가입·승인 동작에 변화가 없음
- 표적 위젯 테스트와 `flutter analyze` 통과
- 사용자에게 실기기 확인 항목을 전달하고 확인 결과를 반영함
- `DEV_LOG.md`와 `AI_CONTEXT.md`에 실제 완료 내용과 검증 결과 반영
- `NEXT_WORK.md`의 현재 실행 작업을 후속 작업 2번으로 교체
- 기능 브랜치 커밋·푸시 후 `main` 병합·푸시 및 로컬/원격 일치 확인

## 후속 작업별 범위 메모

### 2. 멤버십 명령 UI

- 자기 참가 캐릭터 변경은 기존 `(partyIndex, slotIndex)`를 유지한다.
- 탈퇴·추방 후 남은 멤버를 자동으로 앞자리로 당기지 않는다.
- 기존 `PartyMembershipCommandRepository`와 검증·쓰기 계획을 실행 앱 상세 화면에 연결한다.
- 파티장 단독 모집 삭제와 다인 방 해산을 혼동하지 않는다.

### 3. 파티·회차 수명주기

- 완료, 완료 취소, 반복 파티의 주차 전환, 종료와 다인 방 해산을 구분한다.
- 각 동작의 권한·확인 알림창·현재 참가자 Snapshot·로컬 완료 기록 동기화를 기존 계약에 맞춘다.
- 이 작업이 끝나기 전에 알림·채팅·필터 구현으로 넘어가지 않는다.

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

- 빈 슬롯 조건의 저장·판정 계약을 먼저 확정한다.
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

현재 Task-069에서 읽어야 할 문서:

1. [`../design/PARTY_COMPOSITION_RESPONSIVE_LAYOUT.md`](../design/PARTY_COMPOSITION_RESPONSIVE_LAYOUT.md)
2. [`../product/DETAIL_IMPROVEMENTS.md`](../product/DETAIL_IMPROVEMENTS.md)
3. [`ai_rules.md`](ai_rules.md)

후속 파티 명령 작업에서 추가로 읽을 문서:

- [`../architecture/FIREBASE_PARTY_PRODUCT_FLOW.md`](../architecture/FIREBASE_PARTY_PRODUCT_FLOW.md)
- [`../architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md`](../architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md)
- [`../architecture/FIRESTORE_PARTY_READ_MODEL_CONTRACT.md`](../architecture/FIRESTORE_PARTY_READ_MODEL_CONTRACT.md)
- [`../product/PARTY_PARTICIPATION_RULES.md`](../product/PARTY_PARTICIPATION_RULES.md)
- [`AI_CONTEXT.md`](AI_CONTEXT.md)
- [`DEV_LOG.md`](DEV_LOG.md)
