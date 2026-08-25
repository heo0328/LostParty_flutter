# NEXT WORK

## 문서의 역할

이 문서는 다음 구현 작업의 단일 인수인계 기준이다. 누적 이력은 `DEV_LOG.md`, 전체 제품 규칙은 `AI_CONTEXT.md`와 architecture/product 문서를 사용한다. 작업 시작 시 실제 `git status`, `git log -3`과 대조한다.

## 현재 기준 상태

- 통합 대상: 최신 `main`
- 작업 브랜치: `cursor/firebase-runtime-stage1`
- Task-050~054의 Firestore 명령·Rules·Snapshot·Player 이벤트·Drift 로컬 히스토리 기반 구현을 완료했다.
- Task-056(실행 앱 Firebase 읽기·이벤트 동기화 1단계)을 완료했다.
- Task-057(레이드 현황 목록·완료 기록 UX와 읽기 규칙 보강)을 완료했다.
- Task-058(레이드 현황 목록에서 읽기 전용 상세 진입)을 완료했다.
  - 진행 중·신청 중 카드는 `/raid-status/:recruitmentId`로 들어가며, 뒤로 가면 탭 상태가 유지된다.
  - 상세는 `watchRecruitment`의 `PartyReadDetailSnapshot`만 사용하고 Fake `RecruitmentDetailPage`와 경로·데이터를 섞지 않는다.
  - loading·문서 누락·권한 오류·오프라인 안내를 목록과 같은 읽기 계약으로 표시한다. 쓰기 버튼은 없다.
- 모집 만들기·신청·승인 등 쓰기 UI는 여전히 Fake(`InMemoryRecruitmentStateRepository`)다. 여기서 만든 방은 Firestore에 저장되지 않으므로 `레이드 현황`에 나타나지 않는다.
- Firestore Emulator, FCM, TTL 배포와 유료 서비스 호출은 수행하지 않았다.

## 확정된 협업 역할

- Codex는 설계·계약·작업 분해·문서 정합성·인수인계를 중심으로 담당한다.
- Cursor는 주 코드 구현·빌드·표적 테스트를 중심으로 담당한다.
- Codex의 코드 수정과 Cursor의 설계 제안을 금지하지 않는다.
- 구현 중 계약 변경이 필요하면 Cursor가 임의 확장하지 않고 영향과 제안을 문서에 먼저 기록한다.
- 완료 시 코드, 테스트, 문서와 실제 Git 상태를 함께 갱신한다.

## Cursor 다음 작업: 모집·신청 명령의 실행 앱 Repository 전환

### 목표

레이드 모집 쓰기 경로를 Fake에서 Firestore 명령 Repository로 전환하기 시작한다. 한 번에 전 명령을 옮기지 않고, 생성과 신청처럼 현황 읽기와 맞물리는 단위부터 연결한다.

### 우선 확인 파일

- `lib/app/router/app_router.dart`
- `lib/features/recruitment_list/data/fakes/in_memory_recruitment_state_repository.dart`
- `lib/features/recruitment_list/data/repositories/`
- `docs/architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md`
- `docs/architecture/FIRESTORE_PARTY_READ_MODEL_CONTRACT.md`

### 포함 범위

1. 전환 단위와 Fake 잔존 범위를 문서에 먼저 확정한다.
2. 확정된 단위의 Composition Root를 Firestore 명령 Repository로 교체한다.
3. 생성된 방이 `레이드 현황 > 진행 중` 읽기 목록에 나타나는지 표적 테스트로 검증한다.
4. 실패 유형과 권한 오류를 기존 명령 계약대로 화면에 전달한다.

### 제외 범위

- FCM과 OS 알림 권한
- Firestore TTL 정책 배포
- Cloud Functions, Blaze 전환과 결제수단 연결
- Firestore Emulator 실행
- 다중 파티 캐릭터 이동·스왑 명령
- 대규모 UI 개편

### 완료 조건

- Fake 쓰기와 Firestore 읽기가 같은 모집 ID를 공유하는 경계가 문서와 코드에서 일치한다.
- `flutter analyze --no-pub`와 변경 범위 표적 테스트가 통과한다.
- 실행 화면이 바뀌면 Android 실기기 체크리스트를 제공하고 사용자가 직접 확인한다.
- 구현 파일, 검증 결과, 남은 Fake 범위와 다음 전환 단위를 문서에 기록한다.

## 후속 순서

1. 모집·신청·승인·멤버·회차 명령의 실행 앱 Repository 전환
2. 캐릭터 이동·스왑 예상 결과와 다중 파티 Transaction 설계
3. 그룹과 그룹 전용 모집
4. 유료 기능은 사용자가 비용과 필요성을 별도로 승인한 경우에만 재설계

## 지속 운영 제약

- 별도 지시 전까지 외부 서비스의 유료 플랜·결제수단·초과 과금 가능 기능을 사용하지 않는다.
- Emulator Suite는 사용하지 않는다. 필요하면 목적·발견할 실패·종료 조건을 제시하고 명시적 승인을 받는다.
- 실기기 흐름을 대신하기 위한 무의미한 전체 테스트 반복을 하지 않는다.
- AuthUid, API 토큰과 민감한 식별자를 UI·로그·문서 예시에 노출하지 않는다.
- Android Drift(`sqlite3` native assets) 빌드 산출물을 임의로 삭제하지 않는다. 정리 후엔 전체 재설치(`flutter run`)가 필요하다.

## 참고 문서

- `AI_CONTEXT.md`
- `DEV_LOG.md`
- `ai_rules.md`
- `../architecture/FIREBASE_PARTY_PRODUCT_FLOW.md`
- `../architecture/FIRESTORE_PARTY_READ_MODEL_CONTRACT.md`
- `../architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md`
- `../architecture/FIRESTORE_PARTY_EVENT_CONTRACT.md`
- `../product/PARTY_PARTICIPATION_RULES.md`
