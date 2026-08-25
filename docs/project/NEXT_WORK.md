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
- Firestore 전환 점검에서 기존 Fake 화면에는 있던 파티장·파티원 정보가 실행 목록·상세 읽기 모델과 UI에 이관되지 않은 것을 확인했다.
  - `레이드 모집`과 `진행 중` Card에는 파티장 캐릭터명·직업이 표시되지 않는다.
  - `/raid-status/:id` 상세는 모집 문서만 읽어 전체 파티원과 파티 배치를 표시하지 않는다.
  - membership에는 캐릭터명·직업·역할·파티 위치·아이템 레벨·전투력 Snapshot이 저장되지만 읽기 DTO·Repository·공개 권한 계약이 없다.
- Firestore Emulator, FCM, TTL 배포와 유료 서비스 호출은 수행하지 않았다.

## 확정된 협업 역할

- Codex는 설계·계약·작업 분해·문서 정합성·인수인계를 중심으로 담당한다.
- Cursor는 주 코드 구현·빌드·표적 테스트를 중심으로 담당한다.
- 디자인 시스템의 설계·구현·시범 적용과 사용자 피드백 반영은 Codex가 담당한다. Cursor는 확정된 디자인 기준을 후속 기능 화면에 적용한다.
- Codex의 코드 수정과 Cursor의 설계 제안을 금지하지 않는다.
- 구현 중 계약 변경이 필요하면 Cursor가 임의 확장하지 않고 영향과 제안을 문서에 먼저 기록한다.
- 완료 시 코드, 테스트, 문서와 실제 Git 상태를 함께 갱신한다.

## 다음 작업 설계 대상: 파티장·파티원 읽기 모델과 목록·상세 UI 복구

기존 Fake 모집 Card와 상세에는 파티장 및 파티 구성 정보가 있었지만 Firestore 실행 화면 전환 과정에서 빠졌다. 명령 기능을 더 연결하기 전에 사용자가 모집 주체와 현재 파티 구성을 판단할 수 있도록 읽기 계약과 UI를 먼저 복구한다.

### 설계 시 고정된 런타임 사실

- 모집 문서에는 `leaderPlayerId`만 있고 파티장 캐릭터 표시 Snapshot은 없다.
- membership에는 `characterNameSnapshot`, `classNameSnapshot`, `role`, `partyIndex`, `itemLevelSnapshot`, `combatPowerSnapshot`이 이미 저장된다.
- 현재 `PartyReadRepository.watchRecruitment`는 모집 문서 한 건만 반환하며 멤버 목록 읽기 경계가 없다.
- 현재 Rules는 방의 확정 멤버만 전체 membership 목록을 읽을 수 있다. 공개 모집 상세 방문자에게 보여 줄 안전한 멤버 요약의 공개 범위를 먼저 확정해야 한다.
- AuthUid·PlayerId는 UI에 노출하지 않고 캐릭터 표시 정보만 제공한다.
- Fake `/recruitments/:id` 상세 데이터와 실행 앱 Firestore 상세 데이터를 섞지 않는다.

### 목표

`레이드 모집`과 `진행 중` 목록에서 파티장을 식별하고, Firestore 상세에서 현재 모든 파티원의 필수 정보와 파티 배치를 확인할 수 있게 한다.

### 우선 확인 파일

- `lib/features/raid_status/presentation/pages/party_read_detail_page.dart`
- `lib/features/raid_status/presentation/pages/raid_status_page.dart`
- `lib/features/recruitment_list/presentation/widgets/local_recruitment_card.dart`
- `lib/features/recruitment_list/domain/entities/party_read_models.dart`
- `lib/features/recruitment_list/domain/entities/recruitment_aggregate.dart`
- `lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart`
- `lib/features/recruitment_list/data/mappers/party_read_document_mapper.dart`
- `docs/architecture/FIRESTORE_PARTY_READ_MODEL_CONTRACT.md`
- `docs/product/PARTY_PARTICIPATION_RULES.md`

### 포함 범위

1. 목록 조회 한 번으로 파티장 캐릭터명·직업을 표시할 수 있도록 모집 Current State에 안전한 파티장 표시 Snapshot을 추가하고 생성·캐릭터 변경·책임자 승계 시 정합성 유지 방식을 정의한다. Card마다 membership을 따로 조회하는 N+1 구조는 사용하지 않는다.
2. `레이드 모집` 대표 Card와 `진행 중` Card에 같은 파티장 표시 규칙을 적용한다. 본인 방의 `내가 만든 방` 표시는 보조 배지로 유지할 수 있다.
3. membership 읽기 DTO·Mapper·Repository stream을 추가하고 상세 진입 시 모집과 전체 파티원을 함께 구독한다.
4. 상세의 파티 구성은 파티 번호와 자리 기준으로 나누고 각 멤버에 `캐릭터명 · 직업 · 전투력 · 아이템 레벨 · 딜러/서포터`를 표시한다. 값이 없으면 숨기거나 `정보 없음`으로 안전하게 처리한다.
5. 공개 상세 방문자에게 필요한 멤버 표시 필드만 읽도록 Rules 또는 공개 전용 요약 모델을 결정한다. PlayerId, 권한 플래그와 내부 식별자는 공개 UI에 노출하지 않는다.
6. Fake 상세와 Firestore 데이터를 섞지 않고 Mapper·Repository·Card·상세 Widget 표적 테스트와 `flutter analyze --no-pub`로 검증한다.

### 제외 범위

- FCM과 OS 알림 권한
- Firestore TTL 정책 배포
- Cloud Functions, Blaze 전환과 결제수단 연결
- Firestore Emulator 실행
- 즉시 가입·승인·거절 명령 연결
- 멤버·회차 명령 전환
- 자기 참가 캐릭터 변경·탈퇴·추방·승인 권한 변경 UI 연결
- 1파티↔2파티 자리 이동 명령
- 다른 확정 파티 사이 캐릭터 이동·스왑
- 철회 후 재신청 Transaction
- 대규모 UI 개편

### 완료 조건

- `레이드 모집`과 `진행 중` Card에서 파티장 캐릭터명과 직업을 확인할 수 있다.
- 상세에서 현재 모든 파티원을 파티 배치별로 확인할 수 있다.
- 각 파티원은 캐릭터명·직업·전투력·아이템 레벨·딜러/서포터 역할을 표시한다.
- 공개 상세와 확정 멤버 상세의 읽기 권한 및 노출 필드가 Rules와 문서에서 일치한다.
- Fake 상세와 데이터가 섞이지 않는다.
- `flutter analyze --no-pub`와 변경 범위 표적 테스트가 통과한다.
- Android 실기기에서 목록과 상세 표시를 확인하고, 불가능하면 미검증 사유를 문서에 남긴다.

## 후속 순서

1. 파티장·파티원 읽기 모델과 목록·상세 UI 복구
2. 즉시 가입·승인·거절
3. 자기 캐릭터 변경·탈퇴·추방 등 멤버 명령과 회차 명령
4. 파티 내 자리 이동 및 다른 확정 파티 사이 이동·스왑 설계
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

