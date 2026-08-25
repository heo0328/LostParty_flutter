# NEXT WORK

## 문서의 역할

이 문서는 다음 구현 작업의 단일 인수인계 기준이다. 누적 이력은 `DEV_LOG.md`, 전체 제품 규칙은 `AI_CONTEXT.md`와 architecture/product 문서를 사용한다. 작업 시작 시 실제 `git status`, `git log -3`과 대조한다.

## 현재 기준 상태

- 통합 대상: 최신 `main`
- 작업 브랜치: `cursor/firebase-runtime-stage1`
- Task-050~054의 Firestore 명령·Rules·Snapshot·Player 이벤트·Drift 로컬 히스토리 기반 구현을 완료했다.
- Task-056~058에서 레이드 현황 읽기·목록 UX·읽기 전용 상세 진입을 완료했다.
- Task-059 모집 생성 Firestore 전환을 완료했고 Android 실기기에서 확인했다.
  - 실행 앱의 `RecruitmentCreatePage`는 `FirestorePartyCreateRepository`를 사용한다.
  - 파티장 캐릭터는 게임 계정 인증의 `serverCharacterId`가 있을 때만 명령을 보낸다.
  - 인증된 캐릭터로 만든 방은 `레이드 현황 > 진행 중`에 나타나고, 카드에서 `/raid-status/{id}` 읽기 전용 상세로 들어간다.
  - 상세에는 수정 화면이 아직 적용되지 않았다는 안내가 표시된다.
  - 신규 모집 ID `get`이 문서 부재에서 거부되지 않도록 단건 읽기 Rules를 보완해 `lost-party`에 배포했다.
  - 모집 목록·신청·승인·멤버·회차와 Fake 상세는 여전히 `InMemoryRecruitmentStateRepository`다. 로컬 Fake로 만든 방은 Firestore 현황에 나타나지 않는다.
- Firestore Emulator, FCM, TTL 배포와 유료 서비스 호출은 수행하지 않았다.

## 확정된 협업 역할

- Codex는 설계·계약·작업 분해·문서 정합성·인수인계를 중심으로 담당한다.
- Cursor는 주 코드 구현·빌드·표적 테스트를 중심으로 담당한다.
- Codex의 코드 수정과 Cursor의 설계 제안을 금지하지 않는다.
- 구현 중 계약 변경이 필요하면 Cursor가 임의 확장하지 않고 영향과 제안을 문서에 먼저 기록한다.
- 완료 시 코드, 테스트, 문서와 실제 Git 상태를 함께 갱신한다.

## 다음 작업 설계 대상: 신청·철회 명령의 실행 앱 전환

Codex가 화면 진입 경계·계약 영향·작업 분해를 확정한 뒤 Cursor가 구현한다. 아래는 설계 시작점이며 구현 지시로 확정된 것이 아니다.

### 설계 시 고정된 런타임 사실

- 현황 상세는 Firestore 읽기 전용이며 Fake `RecruitmentDetailPage`와 경로·데이터를 섞지 않는다.
- 모집 생성만 Firestore 명령이다. 신청·철회·승인·즉시 가입은 아직 Fake다.
- 생성과 같이 신청 Character ID는 게임 계정 인증의 `serverCharacterId`여야 한다.
- 존재하지 않는 모집 단건 `get`과 `신청 중` collection group `list` Rules는 `lost-party`에 배포된 상태다.

### 목표

인증된 사용자의 신청과 본인 철회를 Firestore 신청 명령 Repository에 연결한다. 승인·즉시 가입·멤버 관리·회차는 Fake로 둔다.

### 우선 확인 파일

- `lib/features/recruitment_list/data/repositories/firestore_party_application_command_repository.dart`
- `lib/features/raid_status/presentation/pages/party_read_detail_page.dart`
- `lib/app/router/app_router.dart`
- `docs/architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md`

### 포함 범위

1. 읽기 전용 상세에서 신청 진입 경계를 정한다. Fake `RecruitmentDetailPage`의 신청 UI를 그대로 재사용하지 않는다.
2. 신청·철회 실패 유형을 명령 계약대로 화면에 전달한다.
3. 성공 후 `레이드 현황 > 신청 중` 읽기 목록이 갱신되는지 표적 테스트로 검증한다.

### 제외 범위

- FCM과 OS 알림 권한
- Firestore TTL 정책 배포
- Cloud Functions, Blaze 전환과 결제수단 연결
- Firestore Emulator 실행
- 승인·즉시 가입·멤버·회차 명령 전환
- 대규모 UI 개편

### 완료 조건

- 신청 명령의 Character ID가 서버 `serverCharacterId`를 사용한다.
- `flutter analyze --no-pub`와 변경 범위 표적 테스트가 통과한다.
- 실행 화면이 바뀌면 Android 실기기 체크리스트를 제공하고 사용자가 직접 확인한다.
- 남은 Fake 범위와 다음 전환 단위를 문서에 기록한다.

## 후속 순서

1. 신청·철회 명령의 실행 앱 전환
2. 즉시 가입·승인·거절
3. 멤버·회차 명령
4. 캐릭터 이동·스왑 예상 결과와 다중 파티 Transaction 설계
5. 그룹과 그룹 전용 모집

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
