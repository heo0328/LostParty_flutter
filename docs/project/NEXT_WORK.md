# NEXT WORK

## 문서의 역할

이 문서는 다음 구현 작업의 단일 인수인계 기준이다. 누적 이력은 `DEV_LOG.md`, 전체 제품 규칙은 `AI_CONTEXT.md`와 architecture/product 문서를 사용한다. 작업 시작 시 실제 `git status`, `git log -3`과 대조한다.

## 현재 기준 상태

- 통합 대상: 최신 `main`
- 작업 브랜치: `cursor/character-summary-sync`
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

## 다음 작업 설계 대상: 인증 캐릭터 최소 정보 자동 동기화

모집 생성과 신청 명령은 서버 Character Snapshot의 아이템 레벨을 최종 조건으로 사용한다. 인증 이후 로컬에서 최신 정보를 조회해도 서버 Character가 갱신되지 않으면 실제 조건을 만족한 캐릭터가 명령에서 거절될 수 있다. 신청·철회 실행 앱 전환 전에 이 동기화 경계를 먼저 구현한다.

### 설계 시 고정된 런타임 사실

- Drift에는 게임 계정과 원정대 Character 기본 정보가 있으며 대표 캐릭터명으로 siblings를 다시 조회할 수 있다.
- 인증된 로컬 Character에는 서버가 발급한 `serverCharacterId`가 연결돼 있다.
- 모집 생성 Transaction은 서버 Character의 아이템 레벨을 검증하므로 로컬 값만 최신이어서는 충분하지 않다.
- 캐릭터명은 변경 가능한 표시 정보이며 서버 동기화 대상 식별은 `serverCharacterId`로 한다.
- Lost Ark API 토큰은 기기의 secure storage에만 두고 원문을 서버·로그·문서 예시에 남기지 않는다.

### 목표

`내 계정` 진입 시 제한된 주기로 원정대 최소 정보를 조회하고, 바뀐 Character 요약만 Drift와 인증된 서버 Character에 반영한다. 별도 `서버에 저장` 버튼은 만들지 않고 기존 수동 새로고침도 유지한다.

### 우선 확인 파일

- 내 계정 화면 진입과 현재 원정대 새로고침 ViewModel·Repository
- Lost Ark siblings 응답의 최소 Character 요약 Mapper
- Drift `game_accounts`, `account_characters` 갱신 경계
- 게임 계정 인증 후 서버 Character 동기화 Gateway·Repository와 Rules
- `docs/architecture/GAME_ACCOUNT_CHARACTER_FIREBASE_CONTRACT.md`

### 포함 범위

1. `내 계정`은 기존 Drift 데이터를 먼저 표시하고 백그라운드에서 원정대 최소 정보를 조회한다. 화면 진입을 네트워크 완료까지 막지 않는다.
2. 자동 조회에는 마지막 성공 시각 기준 6~24시간의 제한을 두고, 구체적인 기본 간격은 구현 전 기존 새로고침 정책과 API 사용량을 대조해 확정한다.
3. 비교 필드는 캐릭터명·아이템 레벨·캐릭터 레벨로 제한한다. 값이 바뀐 Character만 Drift에 반영하고, `serverCharacterId`가 있는 active 소유 Character만 서버에도 갱신한다.
4. 변경이 없으면 Drift·Firestore 쓰기를 생략한다. 늦게 도착한 조회가 더 최신 Snapshot을 덮지 않도록 `lastSummaryFetchedAt`을 비교한다.
5. 자동 조회 실패 시 기존 데이터를 유지한다. 수동 새로고침은 제한 시간과 관계없이 다시 시도할 수 있게 유지한다.
6. API 조회는 성공했지만 서버 반영이 실패하면 로컬 성공으로 숨기지 않고 서버 미반영 상태와 재시도 동작을 안내한다.
7. 모집 생성에서 서버 Character 정보가 오래됐거나 레벨 조건에 미달하면 자동 API 호출을 강제하지 않고 `내 계정 정보 새로고침` 안내와 재시도 경계를 제공한다.

### 제외 범위

- FCM과 OS 알림 권한
- Firestore TTL 정책 배포
- Cloud Functions, Blaze 전환과 결제수단 연결
- Firestore Emulator 실행
- 앱 실행·화면 재진입마다 제한 없는 Lost Ark API 조회
- 전체 캐릭터 종합 상세 API 자동 조회와 장비·세팅 Snapshot 갱신
- 서버에 저장하는 별도 사용자 버튼
- 이름만으로 서버 Character를 찾거나 다른 `serverCharacterId`로 재매핑하는 동작
- API에서 사라진 Character의 자동 삭제·자동 병합
- 신청·철회 명령의 실행 앱 전환
- 승인·즉시 가입·멤버·회차 명령 전환
- 대규모 UI 개편

### 완료 조건

- 변경된 최소 요약이 Drift와 동일한 `serverCharacterId`의 서버 Character에 반영되고, 변경이 없을 때 쓰기가 발생하지 않는다.
- 화면 진입 자동 조회 제한, 수동 새로고침, 부분 실패와 재시도 상태가 표적 테스트로 검증된다.
- 조회 실패와 서버 반영 실패가 기존 유효 데이터를 삭제하거나 성공으로 오인시키지 않는다.
- 모집 생성의 오래된 서버 정보 안내 경계가 검증된다.
- `flutter analyze --no-pub`와 변경 범위 표적 테스트가 통과한다.
- 실행 화면이 바뀌면 Android 실기기 체크리스트를 제공하고 사용자가 직접 확인한다.
- 동기화 간격과 최종 Rules 보장 범위를 문서에 기록한다.

## 후속 순서

1. 인증 캐릭터 최소 정보 자동 동기화
2. 신청·철회 명령의 실행 앱 전환
3. 즉시 가입·승인·거절
4. 멤버·회차 명령
5. 캐릭터 이동·스왑 예상 결과와 다중 파티 Transaction 설계
6. 그룹과 그룹 전용 모집

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
- `../architecture/GAME_ACCOUNT_CHARACTER_FIREBASE_CONTRACT.md`
- `../architecture/GAME_ACCOUNT_VERIFICATION_CONTRACT.md`
- `../product/PARTY_PARTICIPATION_RULES.md`
