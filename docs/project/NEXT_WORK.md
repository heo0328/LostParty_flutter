# NEXT WORK

## 문서의 역할

이 문서는 다음 구현 작업의 단일 인수인계 기준이다. 누적 이력은 `DEV_LOG.md`, 전체 제품 규칙은 `AI_CONTEXT.md`와 architecture/product 문서를 사용한다. 작업 시작 시 실제 `git status`, `git log -3`과 대조한다.

## 현재 기준 상태

- 통합 기준 브랜치: `main` (Task-065 파티장·파티원 읽기/UI 복구까지 포함)
- 다음 구현은 최신 `main`에서 작업 브랜치 `cursor/party-join-approve-reject`를 분기해 진행한다.
- Task-050~054의 Firestore 명령·Rules·Snapshot·Player 이벤트·Drift 로컬 히스토리 기반 구현을 완료했다.
- Task-056~061에서 레이드 현황 읽기·목록 UX·읽기 전용 상세·모집 생성·인증 캐릭터 동기화·신청·철회를 완료했다.
- Task-062에서 LostParty Design System v1의 Theme·token·Bottom Navigation과 공개 모집 대표 Card 시범 적용을 완료했다.
- Task-063에서 `레이드 모집` 공개 목록을 Firestore 페이징 읽기로 전환하고 `main`에 통합했다.
- Task-064에서 파티장·파티원 표시 누락을 점검하고 다음 작업을 읽기 모델·UI 복구로 재정의했다.
- Task-065에서 파티장 표시 Snapshot·멤버 읽기 경계·공개 membership Rules(Option 1)·목록·상세 UI 복구를 완료했다.
  - 모집 문서에 `leaderCharacterNameSnapshot` / `leaderClassNameSnapshot`을 생성·캐릭터 변경·책임자 승계 시 유지한다.
  - `PartyMemberDisplay`와 `watchRecruitmentMembers`를 추가했다. UI는 표시 Snapshot만 소비한다.
  - 공개 모집 membership `get`/`list`는 active binding 사용자에게 허용한다(Option 1).
  - `레이드 모집`·`진행 중` Card와 `/raid-status/:id` 상세에 파티장·파티 구성을 표시한다.
  - 표적 테스트, `flutter analyze --no-pub`, Android 실기기 표시, `lost-party` Rules 배포를 확인했다.
  - Snapshot이 없는 기존 모집은 `정보 없음`으로 표시하고, 새 생성·캐릭터 변경·승계부터 Snapshot을 채운다.
- 승인·즉시 가입·멤버·회차는 Fake 경로를 유지한다.
- Firestore Emulator, FCM, TTL 배포와 유료 서비스 호출은 수행하지 않았다.

## 확정된 협업 역할

- Codex는 설계·계약·작업 분해·문서 정합성·인수인계를 중심으로 담당한다.
- Cursor는 주 코드 구현·빌드·표적 테스트를 중심으로 담당한다.
- 디자인 시스템의 설계·구현·시범 적용과 사용자 피드백 반영은 Codex가 담당한다. Cursor는 확정된 디자인 기준을 후속 기능 화면에 적용한다.
- Codex의 코드 수정과 Cursor의 설계 제안을 금지하지 않는다.
- 구현 중 계약 변경이 필요하면 Cursor가 임의 확장하지 않고 영향과 제안을 문서에 먼저 기록한다.
- 완료 시 코드, 테스트, 문서와 실제 Git 상태를 함께 갱신한다.

## 다음 작업 대상: 즉시 가입·승인·거절

실행 앱 Firestore 상세에 즉시 가입·승인·거절 명령을 연결한다. Fake `/recruitments/:id`와 Firestore 상세를 섞지 않는다.

### 우선 확인 파일

- `lib/features/raid_status/presentation/pages/party_read_detail_page.dart`
- `lib/features/recruitment_list/domain/repositories/party_application_command_repository.dart`
- `lib/features/recruitment_list/data/repositories/firestore_party_application_command_repository.dart`
- `lib/features/recruitment_list/data/repositories/firestore_party_join_command_repository.dart` (존재 시)
- `docs/architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md`
- `docs/product/PARTY_PARTICIPATION_RULES.md`

### 포함 범위

1. 승인형 모집: 파티장(또는 승인 권한 멤버)이 pending 신청을 승인·거절할 수 있게 Firestore 명령을 현황 상세에 연결한다.
2. 즉시 가입형 모집: 조건·배치를 만족하면 pending 없이 바로 가입하는 Firestore 명령을 연결한다.
3. 성공 후 상세·멤버 목록·신청 상태가 실시간으로 갱신되는지 확인한다.
4. Fake 상세 경로와 데이터를 섞지 않고 표적 테스트와 `flutter analyze --no-pub`로 검증한다.

### 제외 범위

- FCM과 OS 알림 권한
- Firestore TTL 정책 배포
- Cloud Functions, Blaze 전환과 결제수단 연결
- Firestore Emulator 실행
- 멤버·회차 명령 전환
- 자기 참가 캐릭터 변경·탈퇴·추방·승인 권한 변경 UI 연결
- 1파티↔2파티 자리 이동 명령
- 다른 확정 파티 사이 캐릭터 이동·스왑
- 철회 후 재신청 Transaction
- 대규모 UI 개편

## 후속 순서

1. 즉시 가입·승인·거절
2. 자기 캐릭터 변경·탈퇴·추방 등 멤버 명령과 회차 명령
3. 파티 내 자리 이동 및 다른 확정 파티 사이 이동·스왑 설계
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
