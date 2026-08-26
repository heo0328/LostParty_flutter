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
| 통합 기준 | **`main` = Task-069까지** | 구성판 반응형 그룹 배치 |
| 완료 기능 | 고정 슬롯 + 반응형 구성판 | Task-068·069 |
| Firestore Rules | 슬롯 필드 + 점유 get **배포됨** | Firebase 프로젝트 `lost-party` |
| 현재 코드 상태 | 가용 폭 600dp+에서 파티 그룹 좌우, Slot Card는 1열·같은 자리 높이 맞춤 | Task-069 실기기 통과 |
| 다음 구현 | **Task-070 자기 참가 캐릭터 변경·탈퇴·추방** | 아래 현재 실행 작업만 수행 |

### Task-069 확인 완료 사항 (2026-08-26)

- Slot Card 2열 제거, 파티 그룹 기준 좁은/넓은 레이아웃
- breakpoint `600dp` (펼친 폴드 가용 폭 반영)
- 넓은 8인: 같은 자리 좌우 Slot Card `IntrinsicHeight` 높이 맞춤
- 바형·폴드 실기기 디자인 통과

## 전체 작업 순서

순서는 다음과 같다. 번호가 뒤인 작업을 앞 작업과 묶어서 구현하지 않는다.

| 순서 | 작업 | 시작 조건 | 결과 |
| --- | --- | --- | --- |
| 1 | Task-069 파티 구성판 반응형 그룹 배치 | **완료** | 모바일 전체 폭 Card, 넓은 화면 파티 좌우 배치 |
| 2 | **자기 참가 캐릭터 변경·탈퇴·추방 연결** | Task-069 종료 | 자유로운 멤버십 명령 UI 완성 |
| 3 | 완료·완료 취소·종료·해산 연결 | 멤버십 명령 안정화 | 파티·회차 수명주기 완성 |
| 4 | 알림 서비스 별도 설계 | 파티 수명주기 완성 | 서버 방식과 수신 정책 결정; 즉시 구현을 의미하지 않음 |
| 5 | 상세 페이지 최근 10개 텍스트 채팅 | 멤버 권한·종료 정책 확정 | 상세 진입 멤버용 최소 채팅 |
| 6 | 빈 슬롯별 역할·직업·시너지 조건 | 슬롯 명령 안정화 | 파티장이 원하는 모집 조건 설정 |
| 7 | 전체 공개 파티 목록 조건 필터 | 슬롯 조건 저장·판정 확정 | 조건에 맞는 공개 모집 탐색 |
| 8 | 레이드 현황 공통 필터 | 공개 목록 필터 UX 확정 | 가입·신청·완료 기록에 동일한 필터 조작 제공 |
| 9 | 파티·슬롯 이동 및 파티 간 스왑 | 기본 멤버십·슬롯 안정화 | 확정 멤버 위치 조정 |
| 10 | 그룹과 그룹 전용 모집 | 핵심 파티 기능 안정화 | 그룹 기반 모집 확장 |

## 현재 실행 작업 — Task-070 자기 참가 캐릭터 변경·탈퇴·추방

### 목표

현황 상세(`/raid-status/:id`)에 확정 멤버 명령을 연결한다.

- 자기 참가 캐릭터 변경: 기존 `(partyIndex, slotIndex)` 유지
- 본인 탈퇴: 단독 모집 삭제와 구분. 책임자 탈퇴 시 승계·마지막 멤버면 `disbanded`
- 책임자 추방: 확인 후 대상 membership·점유 제거. 남은 멤버 자동 당김 배치 없음

기존 `PartyMembershipCommandRepository`(`changeCharacter` / `leave` / `kick`)와 WritePlan·Rules를 재사용한다.

### 변경 대상 (예상)

- `lib/features/raid_status/presentation/pages/party_read_detail_page.dart`
- 필요 시 후보 선택 시트·확인 다이얼로그용 작은 private Widget
- 표적 위젯/ViewModel 테스트

Fake `recruitment_detail_page`의 캐릭터 변경 UX를 참고하되 Firestore 상세와 데이터를 섞지 않는다.

### 구현 기준

- 캐릭터 변경은 역할과 자리를 유지하고 소유권·입장 레벨·점유·동일 직업 딜러 제한을 재검증한다.
- 탈퇴·추방 후 남은 멤버를 앞자리로 당기지 않는다.
- 파티장 단독 모집 삭제(이미 연결됨)와 다인 방 해산을 혼동하지 않는다. 다인 해산은 회차 작업 범위다.
- 네트워크 버튼 연타 방지.
- AuthUid·PlayerId·민감 ID를 UI·토스트에 노출하지 않는다.

### 제외 범위

- 완료·완료 취소·종료·다인 해산
- 승인권 부여/회수(별도 지시 전 범위 밖이면 넣지 않음; 필요 시 문서에 먼저 명시)
- 파티·슬롯 이동과 스왑
- 알림·채팅·필터·빈 슬롯 조건
- 구성판 레이아웃 재작업
- membership `slotIndex` 일괄 rewrite

### 자동 검증

```text
flutter test (표적: 상세·멤버십 관련)
flutter analyze
```

### 완료 조건

- 현황 상세에서 캐릭터 변경·탈퇴·추방이 동작하고 실기기 확인
- 자리 유지·비당김 원칙 준수
- 표적 테스트·analyze 통과
- `DEV_LOG.md`·`AI_CONTEXT.md`·본 문서 갱신 후 `main` 병합

## 후속 작업별 범위 메모

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

현재 Task-070에서 읽어야 할 문서:

1. [`../architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md`](../architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md)
2. [`../product/PARTY_PARTICIPATION_RULES.md`](../product/PARTY_PARTICIPATION_RULES.md)
3. [`../architecture/FIREBASE_PARTY_PRODUCT_FLOW.md`](../architecture/FIREBASE_PARTY_PRODUCT_FLOW.md)
4. [`../product/DETAIL_IMPROVEMENTS.md`](../product/DETAIL_IMPROVEMENTS.md)
5. [`ai_rules.md`](ai_rules.md)

추가로:

- [`../architecture/FIRESTORE_PARTY_READ_MODEL_CONTRACT.md`](../architecture/FIRESTORE_PARTY_READ_MODEL_CONTRACT.md)
- [`AI_CONTEXT.md`](AI_CONTEXT.md)
- [`DEV_LOG.md`](DEV_LOG.md)
- [`../design/PARTY_COMPOSITION_RESPONSIVE_LAYOUT.md`](../design/PARTY_COMPOSITION_RESPONSIVE_LAYOUT.md) (구성판은 유지, 레이아웃 재작업 금지)
