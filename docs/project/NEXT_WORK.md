# NEXT WORK

## 문서의 역할

이 문서는 다음 구현 작업의 단일 인수인계 기준이다. 누적 이력은 `DEV_LOG.md`, 전체 제품 규칙은 `AI_CONTEXT.md`와 architecture/product 문서를 사용한다. 작업 시작 시 실제 `git status`, `git log -3`과 대조한다.

## 현재 기준 상태

- 통합 기준 브랜치: `main` (Task-063 공개 목록 페이징 읽기 전환까지 포함)
- 다음 구현은 최신 `main`에서 작업 브랜치를 분기해 진행한다.
- Task-050~054의 Firestore 명령·Rules·Snapshot·Player 이벤트·Drift 로컬 히스토리 기반 구현을 완료했다.
- Task-056~061에서 레이드 현황 읽기·목록 UX·읽기 전용 상세·모집 생성·인증 캐릭터 동기화·신청·철회를 완료했다.
- Task-062에서 LostParty Design System v1의 Theme·token·Bottom Navigation과 공개 모집 대표 Card 시범 적용을 완료했다.
- Task-063에서 `레이드 모집` 공개 목록을 Firestore 페이징 읽기로 전환하고 `main`에 통합했다.
  - `watchPublicRecruitmentFirstPage` / `loadPublicRecruitmentNextPage` Repository 경계와 불투명 cursor를 추가했다.
  - 첫 20개는 실시간 구독, 이후는 cursor 일회 조회이며 추가 페이지마다 listener를 만들지 않는다.
  - `RecruitmentListPage`는 `PartyReadRepository`와 현재 `cycleKey`를 쓰고, 카드는 `/raid-status/{id}`로 이동한다.
  - Fake `/recruitments/:id` 상세·승인·멤버·회차는 InMemory 경로를 유지한다.
  - 공개 목록 복합 인덱스에 `__name__ desc`를 반영했다. 실제 Firebase 배포 상태는 실기기에서 확인한다.
  - 표적 ViewModel/Widget 테스트와 `flutter analyze --no-pub`를 통과했다. Android 실기기 확인은 남는다.
- 승인·즉시 가입·멤버·회차는 Fake 경로를 유지한다.
- Firestore Emulator, FCM, TTL 배포와 유료 서비스 호출은 수행하지 않았다.

## 확정된 협업 역할

- Codex는 설계·계약·작업 분해·문서 정합성·인수인계를 중심으로 담당한다.
- Cursor는 주 코드 구현·빌드·표적 테스트를 중심으로 담당한다.
- 디자인 시스템의 설계·구현·시범 적용과 사용자 피드백 반영은 Codex가 담당한다. Cursor는 확정된 디자인 기준을 후속 기능 화면에 적용한다.
- Codex의 코드 수정과 Cursor의 설계 제안을 금지하지 않는다.
- 구현 중 계약 변경이 필요하면 Cursor가 임의 확장하지 않고 영향과 제안을 문서에 먼저 기록한다.
- 완료 시 코드, 테스트, 문서와 실제 Git 상태를 함께 갱신한다.

## 다음 작업 설계 대상: 즉시 가입·승인·거절 명령의 실행 앱 연결

공개 목록과 신청·철회는 Firestore에 연결됐다. 다음 단위는 책임자/승인 권한자의 승인·거절과 즉시 가입 정책의 실행 앱 전환이다.

### 설계 시 고정된 런타임 사실

- 신청·철회 명령 Repository와 Rules는 이미 있다.
- `/raid-status/:id` 상세에 신청·철회 UI가 연결되어 있다.
- 승인·거절·즉시 가입 명령 Validator·Write Plan·Repository 기반은 Task-050~052에 있다.
- Fake `/recruitments/:id` 상세의 승인 UI와 실행 앱 Firestore 상세를 섞지 않는다.
- 단일 Android 기기(Player 1개) 환경에서는 타 계정 승인 실기기 확인이 제한될 수 있다.

### 목표

읽기 현황 상세에서 승인 권한자가 pending 신청을 승인·거절하고, 즉시 가입 정책 방은 신청 없이 가입할 수 있게 실행 앱에 연결한다.

### 우선 확인 파일

- `lib/features/raid_status/presentation/pages/party_read_detail_page.dart`
- `lib/features/recruitment_list/data/repositories/firestore_party_application_command_repository.dart`
- `lib/features/recruitment_list/data/repositories/firestore_party_join_command_repository.dart`
- `docs/architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md`
- `docs/product/PARTY_PARTICIPATION_RULES.md`

### 포함 범위

1. 현황 상세에 승인·거절·즉시 가입 명령 Repository를 연결한다.
2. 권한·상태·revision 실패를 기존 신청·철회와 같은 오류 경계로 표시한다.
3. Fake 상세 승인 UI와 데이터를 섞지 않는다.
4. 표적 테스트와 가능하면 Android 실기기(또는 재설치 Player)로 검증한다.

### 제외 범위

- FCM과 OS 알림 권한
- Firestore TTL 정책 배포
- Cloud Functions, Blaze 전환과 결제수단 연결
- Firestore Emulator 실행
- 멤버·회차 명령 전환
- 철회 후 재신청 Transaction
- 대규모 UI 개편

### 완료 조건

- 승인 권한자가 pending 신청을 승인·거절할 수 있다.
- 즉시 가입 정책 방은 현황 상세에서 가입할 수 있다.
- Fake 상세와 데이터가 섞이지 않는다.
- `flutter analyze --no-pub`와 변경 범위 표적 테스트가 통과한다.
- 남은 Fake 범위와 다음 전환 단위를 문서에 기록한다.

## 후속 순서

1. 즉시 가입·승인·거절
2. 멤버·회차 명령
3. 캐릭터 이동·스왑 예상 결과와 다중 파티 Transaction 설계
4. 그룹과 그룹 전용 모집

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
