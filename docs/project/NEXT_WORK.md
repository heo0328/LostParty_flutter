# NEXT WORK

## 문서의 역할

이 문서는 다음 구현 작업의 단일 인수인계 기준이다. 누적 이력은 `DEV_LOG.md`, 전체 제품 규칙은 `AI_CONTEXT.md`와 architecture/product 문서를 사용한다. 작업 시작 시 실제 `git status`, `git log -3`과 대조한다.

## 현재 기준 상태

- 통합 대상: 최신 `main`
- 작업 브랜치: `cursor/party-application-commands`
- Task-050~054의 Firestore 명령·Rules·Snapshot·Player 이벤트·Drift 로컬 히스토리 기반 구현을 완료했다.
- Task-056~059에서 레이드 현황 읽기·목록 UX·읽기 전용 상세·모집 생성 Firestore 전환을 완료했다.
- Task-060 인증 캐릭터 최소 정보 자동 동기화를 완료했고 Android 실기기에서 확인했다.
  - `내 계정` 진입 시 Drift를 먼저 표시하고, 마지막 성공 기준 1분이 지나면 siblings 최소 요약을 백그라운드 조회한다.
  - 변경된 캐릭터명·아이템 레벨·캐릭터 레벨만 Drift·active `serverCharacterId` Firestore에 반영한다. 변경이 없으면 앱 서버 전송을 생략한다.
  - 수동 `계정 데이터 불러오기`는 제한과 무관하며 요청 중 연타를 막고, 조회란에 메인 대표 캐릭터명을 자동 채운다.
  - 모집 생성의 오래된·미달 서버 Character 안내에 내 계정 새로고침을 안내한다.
- 모집 목록·신청·승인·멤버·회차와 Fake 상세는 여전히 `InMemoryRecruitmentStateRepository`다. 로컬 Fake로 만든 방은 Firestore 현황에 나타나지 않는다.
- Firestore Emulator, FCM, TTL 배포와 유료 서비스 호출은 수행하지 않았다.

## 확정된 협업 역할

- Codex는 설계·계약·작업 분해·문서 정합성·인수인계를 중심으로 담당한다.
- Cursor는 주 코드 구현·빌드·표적 테스트를 중심으로 담당한다.
- Codex의 코드 수정과 Cursor의 설계 제안을 금지하지 않는다.
- 구현 중 계약 변경이 필요하면 Cursor가 임의 확장하지 않고 영향과 제안을 문서에 먼저 기록한다.
- 완료 시 코드, 테스트, 문서와 실제 Git 상태를 함께 갱신한다.

## 다음 작업 설계 대상: 신청·철회 명령의 실행 앱 전환

모집 생성은 Firestore 명령이다. 신청·철회는 아직 Fake 경로라 읽기 전용 현황 상세와 데이터가 섞이지 않도록, 인증된 `serverCharacterId`로 Firestore 신청 명령 Repository에 연결한다.

### 설계 시 고정된 런타임 사실

- 현황 상세는 Firestore 읽기 전용이며 Fake `RecruitmentDetailPage`와 경로·데이터를 섞지 않는다.
- 모집 생성만 Firestore 명령이다. 신청·철회·승인·즉시 가입은 아직 Fake다.
- `FirestorePartyApplicationCommandRepository` 등 신청 명령 Repository 구현은 이미 존재할 수 있으며, 실행 앱 화면 연결이 남은 경계다.
- 신청 Character ID는 게임 계정 인증의 `serverCharacterId`여야 한다.
- 서버 Character Snapshot 아이템 레벨이 최종 조건이다. 로컬만 최신이면 거절될 수 있으므로 Task-060 동기화·새로고침 안내를 유지한다.
- 존재하지 않는 모집 단건 `get`과 `신청 중` collection group `list` Rules는 `lost-party`에 배포된 상태다.

### 목표

인증된 사용자의 신청과 본인 철회를 Firestore 신청 명령 Repository에 연결한다. 승인·즉시 가입·멤버 관리·회차는 Fake로 둔다.

### 우선 확인 파일

- `lib/features/recruitment_list/data/repositories/firestore_party_application_command_repository.dart`
- `lib/features/raid_status/presentation/pages/party_read_detail_page.dart`
- `lib/app/router/app_router.dart`
- `docs/architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md`
- `docs/architecture/FIRESTORE_PARTY_READ_MODEL_CONTRACT.md`

### 포함 범위

1. 읽기 전용 상세에서 신청 진입 경계를 정한다. Fake `RecruitmentDetailPage`의 신청 UI를 그대로 재사용하지 않는다.
2. 신청·철회 실패 유형을 명령 계약대로 화면에 전달한다.
3. 신청 Character는 `serverCharacterId`만 사용하고, 미인증·레벨 미달·오래된 서버 정보는 내 계정 새로고침 안내와 함께 막는다.
4. 성공 후 `레이드 현황 > 신청 중` 읽기 목록이 갱신되는지 표적 테스트로 검증한다.
5. 네트워크 요청 버튼은 진행 중 연타·중복 요청을 막는다.

### 제외 범위

- FCM과 OS 알림 권한
- Firestore TTL 정책 배포
- Cloud Functions, Blaze 전환과 결제수단 연결
- Firestore Emulator 실행
- 승인·즉시 가입·멤버·회차 명령 전환
- 대규모 UI 개편

### 완료 조건

- 신청 명령의 Character ID가 서버 `serverCharacterId`를 사용한다.
- 본인 철회가 pending 신청에만 적용되고, 이미 종료된 상태는 멱등적으로 처리된다.
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
- Lost Ark API·Firestore 등 네트워크 요청을 시작하는 버튼은 요청 진행 중 비활성 또는 동일 동작 무시로 연타·중복 요청을 막는다. 화면마다 예외를 두지 않는 공통 UI 규칙이다.

## 참고 문서

- `AI_CONTEXT.md`
- `DEV_LOG.md`
- `ai_rules.md`
- `../architecture/FIREBASE_PARTY_PRODUCT_FLOW.md`
- `../architecture/FIRESTORE_PARTY_READ_MODEL_CONTRACT.md`
- `../architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md`
- `../architecture/FIRESTORE_PARTY_EVENT_CONTRACT.md`
- `../architecture/GAME_ACCOUNT_CHARACTER_FIREBASE_CONTRACT.md`
- `../architecture/GAME_ACCOUNT_VERIFICATION_CONTRACT.md`
- `../product/PARTY_PARTICIPATION_RULES.md`
