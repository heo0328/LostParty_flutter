# NEXT WORK

## 문서의 역할

이 문서는 다음 구현 작업의 단일 인수인계 기준이다. 누적 이력은 `DEV_LOG.md`, 전체 제품 규칙은 `AI_CONTEXT.md`와 architecture/product 문서를 사용한다. 작업 시작 시 실제 `git status`, `git log -3`과 대조한다.

## 현재 기준 상태

- 통합 기준 브랜치: `main` (Task-065까지 포함)
- 현재 구현 브랜치: `cursor/party-join-approve-reject` (Task-066)
- Task-066 코드·표적 테스트는 이 브랜치에 커밋한다. **2기기 실기기 검증과 수정이 끝나기 전까지 `main`에 병합하지 않는다.**
- Task-065에서 파티장·파티원 읽기/UI 복구를 완료하고 `main`에 통합했다.
- Task-066에서 즉시 가입·승인·거절을 현황 상세에 1차 연결했다.
  - `PublicRecruitmentSummary.approvalMode`와 `watchRecruitmentApplications`를 추가했다.
  - `PartyReadDetailPage`에 `FirestorePartyJoinCommandRepository`를 연결했다.
  - 승인형: 파티장 pending 승인·거절. 즉시 가입형: `joinDirectly`.
  - 표적 테스트와 `flutter analyze --no-pub`은 통과했다.
- 멤버·회차와 Fake `/recruitments/:id` 상세는 Fake 경로를 유지한다.
- Firestore Emulator, FCM, TTL 배포와 유료 서비스 호출은 수행하지 않았다.

## 확정된 협업 역할

- Codex는 설계·계약·작업 분해·문서 정합성·인수인계를 중심으로 담당한다.
- Cursor는 주 코드 구현·빌드·표적 테스트를 중심으로 담당한다.
- 구현 중 계약 변경이 필요하면 Cursor가 임의 확장하지 않고 영향과 제안을 문서에 먼저 기록한다.
- 완료 시 코드, 테스트, 문서와 실제 Git 상태를 함께 갱신한다.

## Task-066 상태: 2기기 실기기 검증 대기

코드 연결은 브랜치에 반영됐으나, 사용자는 디바이스를 하나 더 준비해 **2기기**로 검증한 뒤 수정 지시를 다시 내린다. 검증·수정 전에는 `main` 병합을 하지 않는다.

### 남아 있는 실기기 테스트 체크리스트

단일 기기만으로는 타 Player 신청·승인·즉시 가입을 충분히 확인할 수 없다. 아래는 **Android 기기 2대**(서로 다른 Auth/Player) 기준이다.

#### A. 승인형 모집 (`파티장 승인`)

1. 기기 A(파티장): 승인형 모집 생성 → `/raid-status/{id}` 상세 진입
2. 기기 B(신청자): 같은 방 상세 → **지원하기** → 캐릭터 선택
   - 기대: `가입을 신청했습니다.` / 신청자 화면에 승인 대기·철회
3. 기기 A: 상세 `가입 신청 관리`에 pending 표시 → **승인**
   - 기대: 성공 안내, 신청자가 파티 구성에 추가, pending 감소
4. (별도 신청으로) 기기 A에서 **거절**
   - 기대: pending 제거, 신청자 상태가 거절됨으로 갱신
5. 기기 B: pending 중 **신청 철회**
   - 기대: `신청을 철회했습니다.`

#### B. 즉시 가입형 (`승인 없이 바로 가입`)

1. 기기 A: 즉시 가입형 모집 생성
2. 기기 B: **바로 가입** → 캐릭터 선택
   - 기대: `파티에 참가했습니다.` / pending 없이 파티 구성 반영
3. 기기 A: 해당 방에 승인·거절 UI가 불필요하게 동작하지 않는지 확인

#### C. 공통

- 경로가 Fake `/recruitments/:id`가 아니라 `/raid-status/{id}`인지
- 목록·상세의 파티장·파티원 표시가 유지되는지
- 본인 방에는 지원하기가 안 나오고, 파티장에게만 신청 관리가 보이는지
- 관찰된 버그·어색한 UX는 재작업 지시 전에 사용자 메모로 남긴다

### 다음 Cursor 재개 조건

- 사용자가 2기기 테스트 결과와 수정할 점을 지시한 뒤 이 브랜치에서 이어서 수정한다.
- 수정·재검증이 끝나기 전까지 `main` 병합·푸시하지 않는다.

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

1. Task-066 2기기 실기기 검증·수정 → `main` 병합
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
