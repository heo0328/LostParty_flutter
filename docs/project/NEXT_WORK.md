# NEXT WORK

## 문서의 역할

이 문서는 다음 구현 작업의 단일 인수인계 기준이다. 누적 이력은 `DEV_LOG.md`, 전체 제품 규칙은 `AI_CONTEXT.md`와 architecture/product 문서를 사용한다. 작업 시작 시 실제 `git status`, `git log -3`과 대조한다.

## 현재 기준 상태

- 통합 대상: 최신 `main`
- 완료 기능 브랜치: `codex/party-events-local-history`
- Task-050~054의 Firestore 명령·Rules·Snapshot·Player 이벤트·Drift 로컬 히스토리 기반 구현을 완료했다.
- Task-054 검증: 로컬 DB·이벤트·회차 저장 계획 테스트 30개, `flutter analyze --no-pub`, `git diff --check` 통과
- Firestore Emulator, 신규 Rules 배포, FCM, TTL 배포와 유료 서비스 호출은 수행하지 않았다.
- 실행 앱은 아직 `lib/app/router/app_router.dart`에서 `InMemoryRecruitmentStateRepository`를 생성한다.
- Firestore Repository와 `FirestorePartyEventSyncService`는 앱 런타임 및 최종 화면에 연결되지 않았다.
- `레이드 현황`의 `진행 중 / 신청 중 / 완료 기록`은 최소 빈 화면이다.

## 확정된 협업 역할

- Codex는 설계·계약·작업 분해·문서 정합성·인수인계를 중심으로 담당한다.
- Cursor는 주 코드 구현·빌드·표적 테스트를 중심으로 담당한다.
- Codex의 코드 수정과 Cursor의 설계 제안을 금지하지 않는다.
- 구현 중 계약 변경이 필요하면 Cursor가 임의 확장하지 않고 영향과 제안을 문서에 먼저 기록한다.
- 완료 시 코드, 테스트, 문서와 실제 Git 상태를 함께 갱신한다.

## Cursor 다음 작업: 실행 앱 Firebase 전환 1단계

### 목표

실행 앱에서 Firebase 파티 읽기와 Player 이벤트 로컬 동기화를 사용할 Composition Root를 구성하고, `레이드 현황` 세 내부 페이지가 실제 읽기 상태를 표현할 기반을 만든다.

### 우선 확인 파일

- `lib/app/router/app_router.dart`
- `lib/features/raid_status/presentation/pages/raid_status_page.dart`
- `lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart`
- `lib/features/recruitment_list/domain/repositories/party_read_repository.dart`
- `lib/features/raid_status/data/services/firestore_party_event_sync_service.dart`
- `lib/features/account/data/local/account_database.dart`
- `docs/architecture/FIRESTORE_PARTY_READ_MODEL_CONTRACT.md`
- `docs/architecture/FIRESTORE_PARTY_EVENT_CONTRACT.md`

### 포함 범위

1. Composition Root에서 `FirebaseFirestore`, `FirebaseAuth`, `AccountDatabase`를 재사용해 읽기 Repository와 이벤트 동기화 서비스를 구성한다.
2. 기존 Fake 모집 UI를 즉시 전부 제거하지 않고 Firebase 전환 경계를 분리한다.
3. Player binding 완료 후와 `레이드 현황` 진입 시 이벤트 동기화를 멱등 실행한다.
4. `진행 중`은 `watchActiveRaids`, `신청 중`은 `watchApplications`, `완료 기록`은 Drift `raidHistoryEntries`를 읽는 ViewModel/표현 모델 경계를 만든다.
5. loading, 빈 상태, `isFromCache`, 기존 성공 데이터가 있는 후속 오류를 읽기 계약대로 구분한다.
6. 로그인·binding 준비 전에는 Player 전용 쿼리를 시작하지 않는다.

### 로컬 Projection 최소 정책

- 서버 파티 Current State가 최종 진실이며 로컬은 표시·후보 계산용 Projection이다.
- Firestore SDK 캐시를 1차 파티 Projection으로 사용하고 완료 히스토리만 Drift에 영속 저장한다.
- 별도 파티 Current State Drift 복제는 이번 단계에서 추가하지 않는다.
- 목록·상세·알림 진입과 stream 재연결이 최신화 계기다.
- 오프라인 서버 명령을 로컬 큐에 적재하지 않는다. 연결 회복과 최신 revision 확인 후 다시 실행한다.
- Auth Player가 바뀌면 이전 Player의 메모리 Projection과 구독을 폐기하고 로컬 히스토리는 `playerId`로 분리한다.

### 제외 범위

- FCM과 OS 알림 권한
- Firestore TTL 정책 배포
- Cloud Functions, Blaze 전환과 결제수단 연결
- Firestore Emulator 실행
- 다중 파티 캐릭터 이동·스왑 명령
- 전체 쓰기 UI의 한 번에 전환
- 대규모 UI 개편

### 완료 조건

- Composition Root가 중복 DB/Firebase 인스턴스를 만들지 않는다.
- 세 페이지의 loading·빈 상태·데이터·오프라인·오류 경계를 Widget 또는 ViewModel 테스트로 검증한다.
- 이벤트 재동기화가 기록을 중복 생성하지 않고 hidden·local override를 유지한다.
- Fake 기반 기존 모집 흐름의 회귀 범위가 명확하고 관련 표적 테스트가 통과한다.
- `flutter analyze --no-pub`와 변경 범위 표적 테스트가 통과한다.
- 실행 화면이 바뀌면 Android 실기기 체크리스트를 제공하고 사용자가 직접 확인한다.
- 구현 파일, 검증 결과, 미연결 명령과 다음 전환 단위를 문서에 기록한다.

## 후속 순서

1. 실행 앱 Firebase 읽기·이벤트 동기화 전환 1단계
2. 레이드 현황 실제 목록·상세와 로컬 완료 기록 UX
3. 모집·신청·승인·멤버·회차 명령의 실행 앱 Repository 전환
4. 캐릭터 이동·스왑 예상 결과와 다중 파티 Transaction 설계
5. 그룹과 그룹 전용 모집
6. 유료 기능은 사용자가 비용과 필요성을 별도로 승인한 경우에만 재설계

## 지속 운영 제약

- 별도 지시 전까지 외부 서비스의 유료 플랜·결제수단·초과 과금 가능 기능을 사용하지 않는다.
- Emulator Suite는 사용하지 않는다. 필요하면 목적·발견할 실패·종료 조건을 제시하고 명시적 승인을 받는다.
- 실기기 흐름을 대신하기 위한 무의미한 전체 테스트 반복을 하지 않는다.
- AuthUid, API 토큰과 민감한 식별자를 UI·로그·문서 예시에 노출하지 않는다.

## 참고 문서

- `AI_CONTEXT.md`
- `DEV_LOG.md`
- `ai_rules.md`
- `../architecture/FIREBASE_PARTY_PRODUCT_FLOW.md`
- `../architecture/FIRESTORE_PARTY_READ_MODEL_CONTRACT.md`
- `../architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md`
- `../architecture/FIRESTORE_PARTY_EVENT_CONTRACT.md`
- `../product/PARTY_PARTICIPATION_RULES.md`
