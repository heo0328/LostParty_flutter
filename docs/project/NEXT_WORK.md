# NEXT WORK

## 문서의 역할

이 문서는 다음 구현 작업의 단일 인수인계 기준이다. 누적 이력은 `DEV_LOG.md`, 전체 제품 규칙은 `AI_CONTEXT.md`와 architecture/product 문서를 사용한다. 작업 시작 시 실제 `git status`, `git log -3`과 대조한다.

## 현재 기준 상태

- 통합 대상: 최신 `main`
- 작업 브랜치: `cursor/public-recruitment-list`
- Task-050~054의 Firestore 명령·Rules·Snapshot·Player 이벤트·Drift 로컬 히스토리 기반 구현을 완료했다.
- Task-056~060에서 레이드 현황 읽기·목록 UX·읽기 전용 상세·모집 생성·인증 캐릭터 최소 정보 동기화를 완료했다.
- Task-061 신청·철회 명령의 실행 앱 연결을 완료했다.
  - `/raid-status/:id` 읽기 전용 상세에 `FirestorePartyApplicationCommandRepository`를 연결했다.
  - 신청 Character는 인증된 `serverCharacterId`만 사용하며, 후보 선택은 `RecruitmentLeaderCandidateService`를 재사용한다.
  - 본인 pending 신청은 `revision`으로 철회하고, 요청 중 버튼을 비활성한다.
  - Fake `/recruitments/:id` 상세 UI는 그대로 두며 데이터를 섞지 않는다.
  - 단일 Android 기기(Player 1개)라 타 계정 신청·철회 실기기 확인은 보류했다. 표적 테스트로 검증했다.
- `레이드 모집` 탭 공개 목록은 여전히 `InMemoryRecruitmentStateRepository` Fake다. `watchPublicRecruitments`는 Repository에 있으나 UI에 미연결이다.
- 승인·즉시 가입·멤버·회차는 Fake 경로를 유지한다.
- Firestore Emulator, FCM, TTL 배포와 유료 서비스 호출은 수행하지 않았다.

## 확정된 협업 역할

- Codex는 설계·계약·작업 분해·문서 정합성·인수인계를 중심으로 담당한다.
- Cursor는 주 코드 구현·빌드·표적 테스트를 중심으로 담당한다.
- Codex의 코드 수정과 Cursor의 설계 제안을 금지하지 않는다.
- 구현 중 계약 변경이 필요하면 Cursor가 임의 확장하지 않고 영향과 제안을 문서에 먼저 기록한다.
- 완료 시 코드, 테스트, 문서와 실제 Git 상태를 함께 갱신한다.

## 다음 작업 설계 대상: 레이드 모집 공개 목록 Firestore 읽기 전환

신청·철회는 현황 상세에 연결됐지만, 공개 모집을 고르려면 `레이드 모집` 탭이 서버 목록을 보여야 한다. 현재는 Fake 시드만 쓰므로 재설치·다른 Player에서는 서버에 있는 방이 보이지 않는다.

### 설계 시 고정된 런타임 사실

- `FirestorePartyReadRepository.watchPublicRecruitments(cycleKey:)`가 이미 있다.
- 공개 목록 필터는 `visibility == public`, `status == active`, `manualRecruitmentEnabled`, `hasAvailableSlot`, `targetCycleKey == cycleKey`다.
- 카드 탭 시 `/raid-status/{id}` 읽기 전용 상세로 들어가면 신청·철회가 가능하다.
- Fake `/recruitments/:id` 상세와 데이터를 섞지 않는다.
- 모집 생성은 이미 Firestore이며 성공 시 현황 상세로 이동한다.

### 목표

`레이드 모집` 탭을 `watchPublicRecruitments`에 연결해 현재 주차 공개·모집 중 방을 실시간으로 표시하고, 선택 시 Firestore 읽기 상세로 진입한다.

### 우선 확인 파일

- `lib/features/recruitment_list/presentation/pages/recruitment_list_page.dart`
- `lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart`
- `lib/app/router/app_router.dart`
- `docs/architecture/FIRESTORE_PARTY_READ_MODEL_CONTRACT.md`
- `docs/architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md` §9

### 포함 범위

1. `RecruitmentListPage`를 Firestore 공개 목록 stream에 연결한다. InMemory Fake 목록을 실행 앱 기본 경로에서 제거한다.
2. loading·빈 목록·캐시·오류 상태를 현황 목록과 같은 계약으로 표시한다.
3. 카드 선택 시 `/raid-status/{recruitmentId}`로 이동한다. Fake 상세로 보내지 않는다.
4. 모집 생성 진입은 유지한다.
5. 표적 테스트와 필요 시 Rules/인덱스 누락을 확인한다.

### 제외 범위

- FCM과 OS 알림 권한
- Firestore TTL 정책 배포
- Cloud Functions, Blaze 전환과 결제수단 연결
- Firestore Emulator 실행
- 승인·즉시 가입·멤버·회차 명령 전환
- Fake 상세 UI 전면 제거(경로만 분리 유지 가능)
- 대규모 UI 개편

### 완료 조건

- 서버에 있는 현재 주차 공개 모집이 `레이드 모집` 탭에 나타난다.
- 카드에서 읽기 전용 상세로 들어가 신청 흐름 이어진다.
- `flutter analyze --no-pub`와 변경 범위 표적 테스트가 통과한다.
- Android 실기기에서 공개 목록·상세 진입을 확인한다.
- 남은 Fake 범위와 다음 전환 단위를 문서에 기록한다.

## 후속 순서

1. 레이드 모집 공개 목록 Firestore 읽기 전환
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
