# NEXT WORK

## 문서의 역할

이 문서는 Codex와 Cursor가 번갈아 작업하더라도 같은 범위와 판단 기준으로 이어갈 수 있게 하는 단일 실행 지시서다.

- **현재 실행 작업**에 적힌 한 작업만 구현한다.
- **후속 작업 큐**는 순서 확인용이며 현재 작업 범위에 함께 포함하지 않는다.
- 현재 작업을 구현·자동 검증·실기기 확인·문서화·병합한 뒤 다음 항목을 현재 실행 작업으로 올린다.
- 누적 완료 이력은 `DEV_LOG.md`, 전체 현재 상태는 `AI_CONTEXT.md`, 제품·기술 계약은 관련 product/architecture/design 문서를 따른다.
- 작업 시작 시 `git status`, 현재 브랜치와 `git log -3`을 이 문서의 기준 상태와 대조한다.

## 두 AI 인계 방식

### 기본 역할

| 단계 | 주 담당 | 해야 할 일 | 다음 AI에게 남길 내용 |
| --- | --- | --- | --- |
| 계약·범위 검토 | Codex | 문서와 실제 코드·Rules 대조, 설계 충돌과 결정 필요 항목 식별 | 구현 가능한 단위, 포함·제외 범위, 보안 불변식 |
| 구현·표적 검증 | Cursor | 지시된 한 작업 단위의 코드·테스트 구현, 표적 테스트와 analyze | 변경 파일, 테스트 결과, 미해결 충돌, 실기기 확인 항목 |
| 결과 재검토 | Codex | 구현이 계약·Rules·비용 제약과 일치하는지 확인 | 수정 지시 또는 문서화·종료 승인 |
| 수정·최종 검증 | Cursor | 승인된 수정만 반영하고 최종 검증 | 최종 코드 상태와 검증 결과 |
| 문서·Git 종료 | Codex 또는 명시된 담당 | `DEV_LOG`·`AI_CONTEXT`·`NEXT_WORK` 갱신, 승인된 경우 Git 종료 | 다음 작업의 실행 지시서 |

역할은 주 담당을 뜻하며 다른 AI의 코드 수정이나 설계 제안을 금지하지 않는다. 다만 현재 단계의 산출물 없이 다음 단계까지 한 번에 진행하지 않는다.

### 매 인계 시 필수 상태 보고

다음 AI는 이전 대화 내용을 추측하지 않고 아래 항목을 저장소와 이 문서에서 확인한다. 작업을 넘기는 AI도 같은 형식으로 결과를 남긴다.

```text
현재 Task:
현재 단계: 검토 / 구현 / 재검토 / 수정 / 실기기 대기 / 종료
브랜치와 HEAD:
작업 트리 상태:
완료한 범위:
변경 파일:
실행한 검증과 결과:
남은 작업:
결정 또는 사용자 확인 필요 사항:
금지·제외 범위 재확인:
```

- Git 상태나 코드가 문서와 다르면 먼저 차이를 보고하고 임의로 덮어쓰지 않는다.
- 다른 AI가 만든 미커밋 변경은 보존한다. 현재 Task와 겹치면 diff를 읽고 이어서 작업한다.
- 설계 결정이 필요한 충돌은 구현으로 숨기지 않고 `결정 필요`로 인계한다.
- 후속 아이디어는 현재 구현에 포함하지 않고 `NEXT_WORK` 후보 또는 관련 계약 문서에 기록한다.
- 커밋·푸시·Rules 배포·유료 서비스 활성화는 사용자 지시나 현재 단계의 명시적 승인 없이 수행하지 않는다.

## 현재 기준 상태

| 구분 | 상태 | 비고 |
| --- | --- | --- |
| 통합 기준 | **`main` = Task-071까지, Task-072 문서 브랜치 진행** | 회차 완료·해산 + 알림 계약 |
| 완료 기능 | 멤버십 명령·회차 수명주기(완료/취소/전환/해산) | Task-068~071 |
| Firestore Rules | 해산·완료 후 반복 설정 포함 **배포됨** | Firebase 프로젝트 `lost-party` |
| 현재 코드 상태 | 현황 상세 회차·해산 연결, 1회성 완료 후 진행 중 「해산 대기」 | Task-071 실기기 통과 |
| 다음 구현 | **Task-073 앱 내부 알림 이벤트 schema·Rules 기반** | Task-072 병합 후 아래 현재 실행 작업만 수행 |

### Task-071 확인 완료 사항 (2026-08-26)

- 회차 완료 / 완료 취소 / 다음 주 함께하기 / 다음 회차 전환 / 다인·완료 후 해산
- 1회성 완료 후 `status=completed` 방을 진행 중 **해산 대기**로 유지해 상세 재진입·해산 가능
- 완료 직후·완료 기록 탭 이벤트 sync, 하단 탭 터치 시 브랜치 루트 복귀
- Rules: `validRecruitmentDisband`, 완료 후 `continueTogether` 변경 허용 — `lost-party` 배포됨

### 열린 버그 (수정은 별도 작업)

- **BUG-002** 4인 목록 vs 8인 구성 표시 (조사 대기)
- **BUG-005** 같은 레이드 주간 재완료 미차단 (조사 대기)
- **BUG-006** 완료·해산 초기 1~2회 권한 실패 관찰

## 전체 작업 순서

순서는 다음과 같다. 번호가 뒤인 작업을 앞 작업과 묶어서 구현하지 않는다.

| 순서 | 작업 | 시작 조건 | 결과 |
| --- | --- | --- | --- |
| 1 | Task-069 파티 구성판 반응형 그룹 배치 | **완료** | 모바일 전체 폭 Card, 넓은 화면 파티 좌우 배치 |
| 2 | 자기 참가 캐릭터 변경·탈퇴·추방 연결 | **완료** | 자유로운 멤버십 명령 UI 완성 |
| 3 | 완료·완료 취소·종료·해산 연결 | **완료** | 파티·회차 수명주기 완성 |
| 4 | 알림 서비스 별도 설계 | **Task-072 완료** | Spark 앱 내부 알림 + 향후 FCM 2단계 계약 |
| 5 | **앱 내부 알림 이벤트 schema·Rules 기반** | Task-072 병합 | 공통 event model과 안전한 create/read 경계 |
| 6 | 신청·멤버십·회차 이벤트와 로컬 알림/UI | 5 완료 | foreground/재실행 앱 내부 알림 |
| 7 | 상세 페이지 최근 10개 텍스트 채팅 | 알림 최소 기능 안정화 | 상세 진입 멤버용 최소 채팅 |
| 8 | 빈 슬롯별 역할·직업·시너지 조건 | 슬롯 명령 안정화 | 파티장이 원하는 모집 조건 설정 |
| 9 | 전체 공개 파티 목록 조건 필터 | 슬롯 조건 저장·판정 확정 | 조건에 맞는 공개 모집 탐색 |
| 10 | 레이드 현황 공통 필터 | 공개 목록 필터 UX 확정 | 가입·신청·완료 기록에 동일한 필터 조작 제공 |
| 11 | 파티·슬롯 이동 및 파티 간 스왑 | 기본 멤버십·슬롯 안정화 | 확정 멤버 위치 조정 + 이동 이벤트 |
| 12 | 그룹과 그룹 전용 모집 | 핵심 파티 기능 안정화 | 그룹 기반 모집 확장 |

## Task-072 완료 결정 — 파티 이벤트 기반 알림 설계

### 목표

Spark에서 공통 파티 이벤트 기반 앱 내부 알림을 먼저 구현하고, 향후 신뢰할 수 있는 서버가 같은 이벤트를 소비해 FCM을 발송하는 2단계 구조를 확정했다.

### 포함 범위

- 사용자별 `players/{playerId}/events/{eventId}`를 비공개 알림 투영본으로 유지
- 클라이언트 자유 문구 저장 금지, 명령 Transaction·Rules로 type/수신자/Snapshot 검증
- 읽음 상태는 초기 Drift 로컬 Projection, 여러 기기 동기화는 후속
- 이벤트별 수신자·문구·딥링크·Snapshot·멱등 기준 확정
- 상세 기준: [`../architecture/PARTY_NOTIFICATION_CONTRACT.md`](../architecture/PARTY_NOTIFICATION_CONTRACT.md)

### 제외 범위

- 코드는 수정하지 않았고 FCM / TTL / 유료 서비스를 배포하지 않았다.
- 채팅·필터·슬롯 조건·기존 명령 UI와 BUG-002/005/006은 변경하지 않았다.

### 완료 조건

- 문서 정합성 및 `git diff --check` 확인 후 문서 브랜치를 `main`에 병합한다.

## 현재 실행 작업 — Task-073 앱 내부 알림 이벤트 schema·Rules 기반

### 이번 인계의 시작 상태

| 항목 | 기준 |
| --- | --- |
| 시작 브랜치 | Task-072 문서 브랜치가 `main`에 병합된 최신 `main` |
| 새 작업 브랜치 | 구현 담당이 `cursor/party-notification-event-foundation` 등 작업 전용 브랜치 생성 |
| 현재 단계 | Task-072 문서 재검토 후 Task-073 구현 전 검토 |
| 앱 동작 기준 | 완료 계열 3종 Player Event sync는 유지, 알림 UI는 없음 |
| 배포 기준 | 현재 Rules는 Task-071까지 배포됨. Task-073 Rules는 자동 배포하지 않음 |
| 실기기 | Task-073 기반 단계에서는 필수 아님. 명령 연결·UI 단계에서 별도 수행 |

### 목표

기존 완료 계열 Player Event와 하위 호환되는 공통 알림 이벤트 모델을 만들고, 다른 Player 경로에 자유 쓰기를 열지 않는 유형별 Security Rules 기반을 구현한다.

### 포함 범위

- 이벤트 type/DTO/mapper와 안정적 event ID 생성 경계
- 자기 Player Event의 제한된 최근 query Repository
- 신청·멤버십 이벤트 create를 허용하기 위한 유형별 Rules와 Rules 테스트
- 기존 완료 이벤트·Drift 완료 히스토리 회귀 검증

### 반드시 유지할 설계 불변식

- 알림은 성공한 파티 명령의 결과이며 파티 상태 변경의 근거가 아니다.
- 경로는 기존 `players/{recipientPlayerId}/events/{eventId}`를 유지한다.
- 현재 Player만 자기 이벤트를 읽고, 다른 Player의 이벤트 목록은 읽을 수 없다.
- 일반적인 `allow create`를 열지 않는다. 이벤트 type마다 호출자·상태 전이·수신자·필드·시간·revision을 Rules가 검증해야 한다.
- 이벤트에 완성된 자유 문구, AuthUid, FCM 토큰이나 자격 증명을 저장하지 않는다.
- 기존 `partyCompleted`, `partyCompletionCancelled`, `partyIncompleteEnded`와 `PartyEventSyncService`의 완료 히스토리 동작을 깨지 않는다.
- 여러 수신자에게 생성된 같은 논리 사건은 같은 안정적 event ID를 사용한다.
- FCM, OS 알림, 읽음 상태와 UI는 이번 Task에서 구현하지 않는다.

### 구현 전에 먼저 확인할 실제 코드

| 영역 | 확인 파일 | 확인 목적 |
| --- | --- | --- |
| 기존 event ID·payload | `lib/features/recruitment_list/data/mappers/party_event_write_plan.dart` | 완료 계열 하위 호환과 공통 필드 경계 |
| 완료 이벤트 Transaction | `lib/features/recruitment_list/data/repositories/firestore_party_cycle_command_repository.dart` | 상태 변경과 이벤트 동시 기록 방식 |
| 이벤트 sync | `lib/features/raid_status/data/services/firestore_party_event_sync_service.dart` | 완료 3종 외 type 처리 분리 지점 |
| Domain 경계 | `lib/features/raid_status/domain/services/party_event_sync_service.dart` | 기존 완료 히스토리 계약 보존 |
| 로컬 완료 기록 | `lib/features/account/data/local/account_database.dart` | 알림 receipt와 혼합하면 안 되는 이유 확인 |
| 신청 명령 | `firestore_party_application_command_repository.dart` | 신청·철회 상태 전이와 revision |
| 가입·승인 명령 | `firestore_party_join_command_repository.dart` | 승인·즉시 가입 수신자 검증 근거 |
| membership 명령 | `firestore_party_membership_command_repository.dart` | 탈퇴·추방 전후 멤버 기준 |
| Rules | `firestore.rules`의 `validCycleEvent`, `/players/{playerId}/events` | 현재 허용 범위와 유형별 확장 위치 |

파일명만 적힌 Repository는 `lib/features/recruitment_list/data/repositories/` 아래에서 확인한다.

### 권장 산출물 구조

구현 담당은 기존 feature-first 구조와 이름을 우선하며, 아래는 책임 경계 기준이지 파일명을 강제하는 지시는 아니다.

1. 공통 Party Event Domain/DTO
   - 지원 event type과 필수·선택 Snapshot을 타입으로 구분
   - 알 수 없는 미래 type을 완료 히스토리 sync 전체 실패로 만들지 않는 경계 검토
2. event ID·write plan
   - 기존 완료 ID 형식을 보존
   - 신청/application revision과 모집/recruitment revision의 기준을 혼합하지 않음
3. Player Event 읽기 Repository
   - 현재 Player 자기 경로만 사용
   - `occurredAt desc`와 작은 limit을 받을 수 있는 인터페이스
   - UI, unread 계산과 Drift 저장은 연결하지 않음
4. Security Rules 기반
   - 기존 `validCycleEvent` 유지
   - 후속 명령 연결에서 재사용할 유형별 validator 또는 명확한 분기
   - 허용 필드 `keys().hasOnly`, recipient, actor, request time과 revision 검증

### 단계별 실행 지시

#### 1단계 — Codex 검토

- 위 파일과 세 알림 계약 문서를 실제 코드와 대조한다.
- Task-073만으로 Rules에서 검증 가능한 event type과, 실제 명령 Transaction 연결 없이는 검증할 수 없는 type을 구분한다.
- 특히 신청 이벤트가 파티장만 수신하는 현재 결정과 `canApproveApplications` 전체 확장 미확정을 구분한다.
- 구조 선택이 계약을 바꿀 정도면 코드 수정 전에 사용자에게 결정 사항을 보고한다.

#### 2단계 — Cursor 구현

- 공통 event model, mapper/write plan과 제한된 읽기 Repository를 구현한다.
- Rules는 실제 상태 전이를 검증할 수 있는 기반만 추가한다. 아직 명령 Repository가 이벤트를 쓰지 않는데 허용 규칙만 넓게 열어 두지 않는다.
- 신청·멤버십·회차 명령 전체에 이벤트 쓰기를 동시에 연결하지 않는다.
- 변경 영역의 단위 테스트를 먼저 실행한다.

#### 3단계 — Codex 재검토

- 다른 Player 경로에 위조 이벤트를 만들 수 있는 일반 create 구멍이 없는지 확인한다.
- 기존 완료 이벤트 필드와 ID, sync와 Drift 히스토리 회귀 여부를 확인한다.
- query가 현재 Player 경로, 정렬, limit 경계를 지키는지 확인한다.
- 계약과 다른 부분은 파일·근거·수정 범위를 구체적으로 Cursor에 돌려준다.

#### 4단계 — Cursor 수정·최종 검증

- 재검토에서 승인된 수정만 반영한다.
- 표적 테스트와 `flutter analyze --no-pub`를 최종 코드 상태에서 실행한다.
- Emulator 사용은 별도 승인 대상이다. 승인 없이 Emulator 기반 Rules 테스트나 Firebase 배포를 실행하지 않는다.

#### 5단계 — 종료 인계

- 실제 변경·검증 결과를 `DEV_LOG.md`에 기록한다.
- `AI_CONTEXT.md`에는 새 현재 상태만 추가한다.
- `NEXT_WORK.md`는 다음 한 작업, 즉 신청 이벤트 연결 단위의 실행 지시서로 교체한다.
- 커밋·푸시·`main` 병합은 사용자 지시와 `ai_rules.md`의 종료 절차를 따른다.

### 예상 변경 영역

- `lib/features/recruitment_list/...`의 Party Event model/mapper 또는 별도 공통 경계
- `lib/features/raid_status/...`의 Player Event 읽기 Repository 경계
- `firestore.rules`
- 기존 `party_event_write_plan_test.dart`와 신규 event mapper/Repository 표적 테스트
- 관련 아키텍처 및 프로젝트 인계 문서

이 목록 밖의 라우팅, 알림 UI, Drift schema, 기존 파티 화면을 변경해야 한다면 범위 확장으로 간주하고 먼저 보고한다.

### 제외 범위

- 명령 Repository 전체에 모든 이벤트를 한 번에 연결
- Drift 알림 receipt migration과 알림 아이콘·목록 UI
- FCM, OS 알림 권한, TTL 배포와 유료 서비스
- 채팅·필터·슬롯 조건 및 열린 버그 수정

### 완료 조건

- 임의 문구·임의 수신자 이벤트가 Rules에서 거절됨
- 허용된 명령 상태 전이와 정확한 수신자의 이벤트만 생성 가능함
- 기존 완료 히스토리 동기화가 유지됨
- 관련 테스트와 `flutter analyze` 통과 후 후속 명령별 이벤트 연결 작업을 분리함

### 검증 체크리스트

- [ ] 기존 완료 계열 event ID와 payload 테스트 통과
- [ ] 알 수 없는 event type 처리 경계가 기존 완료 sync를 깨지 않음
- [ ] 자기 Player Event 읽기와 다른 Player 경로 비노출이 코드·Rules에 명확함
- [ ] 허용 필드 밖 자유 문구·민감 필드를 Rules가 허용하지 않음
- [ ] 임의 recipient·actor·revision으로 단독 이벤트 생성할 수 있는 일반 규칙이 없음
- [ ] 최근 query가 정렬과 limit을 가짐
- [ ] 관련 표적 테스트 통과
- [ ] `flutter analyze --no-pub` 통과
- [ ] Emulator·Rules 배포·FCM·TTL을 실행하지 않음

### 즉시 중단하고 결정 받아야 하는 경우

- 수신자 전원 이벤트 생성을 Rules만으로 강제하기 위해 별도 공통 outbox가 필요해지는 경우
- 신청 알림을 파티장 외 모든 승인권자에게 보내야 구현이 성립하는 경우
- 기존 완료 event schema 또는 event ID를 깨는 migration이 필요한 경우
- 다른 Player 이벤트 create를 안전하게 제한할 수 없어 서버가 선행되어야 하는 경우
- Firestore Transaction/Rules 접근 한도 때문에 최대 8인 수신을 같은 명령에서 처리할 수 없는 경우
- Emulator, Rules 배포, Blaze, Cloud Functions 또는 외부 서버가 필요해지는 경우

## 후속 작업별 범위 메모

### 7. 상세 채팅

- 상세에 진입한 현재 멤버만 최근 메시지 약 10개를 읽고 전송한다.
- `createdAt desc`, `limit(10)`만 구독하고 화면 이탈 시 listener를 해제한다.
- 이미지·파일·읽음 상태·목록 미리보기·채팅 FCM은 초기 범위에서 제외한다.
- 메시지 길이, 연속 전송, 서버 timestamp, 멤버 Rules와 완료·해산 후 접근 정책을 구현 전에 확정한다.

### 8~10. 조건과 필터

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

현재 Task-073에서 읽어야 할 문서:

1. [`../architecture/PARTY_NOTIFICATION_CONTRACT.md`](../architecture/PARTY_NOTIFICATION_CONTRACT.md)
2. [`../architecture/FIRESTORE_PARTY_EVENT_CONTRACT.md`](../architecture/FIRESTORE_PARTY_EVENT_CONTRACT.md)
3. [`../architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md`](../architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md)
4. [`../architecture/FIREBASE_PARTY_PRODUCT_FLOW.md`](../architecture/FIREBASE_PARTY_PRODUCT_FLOW.md)
5. [`ai_rules.md`](ai_rules.md)

열린 결함:

- [`BUG_REPORTS.md`](BUG_REPORTS.md)

추가로:

- [`AI_CONTEXT.md`](AI_CONTEXT.md)
- [`DEV_LOG.md`](DEV_LOG.md)
