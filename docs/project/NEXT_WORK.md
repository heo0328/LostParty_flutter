# NEXT WORK

## 문서의 역할

이 문서는 다음 구현 작업의 단일 인수인계 기준이다. 누적 이력은 `DEV_LOG.md`, 전체 제품 규칙은 `AI_CONTEXT.md`와 architecture/product 문서를 사용한다. 작업 시작 시 실제 `git status`, `git log -3`과 대조한다.

## 현재 기준 상태

- 통합 대상: 최신 `main`
- 작업 브랜치: `cursor/firebase-runtime-stage1`
- Task-050~054의 Firestore 명령·Rules·Snapshot·Player 이벤트·Drift 로컬 히스토리 기반 구현을 완료했다.
- Task-056(실행 앱 Firebase 읽기·이벤트 동기화 1단계)을 완료했다.
- Task-057(레이드 현황 목록·완료 기록 UX)을 완료했다.
  - `진행 중`은 레이드·KST 일정·인원·최소 조건 카드로 표시한다.
  - `신청 중`은 `승인 대기`와 `최근 처리 결과`를 나누고, 모집 종료로 닫힌 신청은 거절과 구분한다.
  - `완료 기록`은 카탈로그 표시명, 숨김·로컬 정정 메뉴, `숨긴 기록 보기` 토글을 제공한다. 숨김·정정은 서버에 전송하지 않는다.
  - 빈 목록에서도 오프라인 안내가 풀리도록 읽기 stream은 `includeMetadataChanges: true`를 사용한다.
  - `신청 중` collection group 쿼리를 위해 `match /{path=**}/applications/{applicantPlayerId}` 규칙을 추가하고 `lost-party`에 배포했다. 색인 4개는 이미 배포된 상태와 일치한다.
  - Android 실기기에서 진행 중 오프라인 안내가 사라지고 재실행 시 `PERMISSION_DENIED`가 나오지 않음을 확인했다.
- 모집 만들기·신청·승인 등 쓰기 UI는 여전히 Fake(`InMemoryRecruitmentStateRepository`)다. 여기서 만든 방은 Firestore에 저장되지 않으므로 `레이드 현황`에 나타나지 않는다. 이것은 다음 쓰기 Repository 전환 전까지 정상이다.
- 목록에서 상세로 가는 진입은 아직 연결하지 않았다.
- Firestore Emulator, FCM, TTL 배포와 유료 서비스 호출은 수행하지 않았다.

## 확정된 협업 역할

- Codex는 설계·계약·작업 분해·문서 정합성·인수인계를 중심으로 담당한다.
- Cursor는 주 코드 구현·빌드·표적 테스트를 중심으로 담당한다.
- Codex의 코드 수정과 Cursor의 설계 제안을 금지하지 않는다.
- 구현 중 계약 변경이 필요하면 Cursor가 임의 확장하지 않고 영향과 제안을 문서에 먼저 기록한다.
- 완료 시 코드, 테스트, 문서와 실제 Git 상태를 함께 갱신한다.

## Cursor 다음 작업: 레이드 현황 목록에서 상세 진입 경계

### 목표

진행 중·신청 중 목록에서 파티 상세로 들어가는 진입 경계를 만든다. Fake 쓰기 UI와 명령 Repository는 유지한다.

### 우선 확인 파일

- `lib/features/raid_status/presentation/pages/raid_status_page.dart`
- `lib/app/router/app_router.dart`
- `lib/features/recruitment_list/presentation/pages/recruitment_detail_page.dart`
- `lib/features/recruitment_list/domain/repositories/party_read_repository.dart`
- `docs/architecture/FIRESTORE_PARTY_READ_MODEL_CONTRACT.md`

### 포함 범위

1. 진행 중 카드에서 해당 모집 상세로 이동하는 진입을 만든다.
2. 신청 중 카드에서 해당 모집 상세로 이동하는 진입을 만든다.
3. 상세는 기존 Fake 쓰기 화면을 재사용하지 않고, Firestore 읽기 계약의 `watchRecruitment` 경계를 우선한다. 쓰기 명령은 연결하지 않는다.
4. 문서 누락·권한 오류·오프라인 상세 상태를 목록과 같은 읽기 계약으로 표시한다.

### 제외 범위

- FCM과 OS 알림 권한
- Firestore TTL 정책 배포
- Cloud Functions, Blaze 전환과 결제수단 연결
- Firestore Emulator 실행
- 모집·신청·승인·멤버·회차 명령의 실행 앱 Repository 전환
- 다중 파티 캐릭터 이동·스왑 명령
- 대규모 UI 개편

### 완료 조건

- 목록에서 상세로 들어가고 돌아올 때 탭 상태가 유지된다.
- 상세가 Firestore 읽기 모델을 사용하고 Fake 쓰기 화면과 데이터가 섞이지 않는다.
- `flutter analyze --no-pub`와 변경 범위 표적 테스트가 통과한다.
- 실행 화면이 바뀌면 Android 실기기 체크리스트를 제공하고 사용자가 직접 확인한다.
- 구현 파일, 검증 결과, 미연결 쓰기 명령과 다음 전환 단위를 문서에 기록한다.

## 후속 순서

1. 레이드 현황 목록에서 상세 진입 경계
2. 모집·신청·승인·멤버·회차 명령의 실행 앱 Repository 전환
3. 캐릭터 이동·스왑 예상 결과와 다중 파티 Transaction 설계
4. 그룹과 그룹 전용 모집
5. 유료 기능은 사용자가 비용과 필요성을 별도로 승인한 경우에만 재설계

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
