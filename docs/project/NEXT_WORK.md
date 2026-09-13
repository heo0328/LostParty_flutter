# NEXT WORK

> 다음에 바로 진행할 단일 작업 그룹의 근거·범위·순서·완료 조건만 관리한다. 완료 경과는 `DEV_LOG.md`로 이동한다.

## 현재 인계 상태

- `codex/implement-build-error-policy`의 Character Build 확정 오류 판정·오류 전용 표시와 파티 후속 보완은 구현 완료 상태다.
- 새 파티 생성 시 선택 역할의 보석 최소 요약이 파티장 membership에 저장된다. 사용자가 그룹 레이드 생성 파티장의 오류가 파티 상세에 정상 표시되는 것을 실기기에서 확인했다.
- 참가 Character 변경 목록과 신청·즉시 참가 Character 선택 목록은 같은 로컬 Build의 통합 상태로 보석·아크그리드 확정 오류만 표시한다. 표적 Widget 테스트에서 복합 오류 표시와 기존 명령 전달을 확인했다.
- 앞선 생성·후보·파티 상세 표적 테스트 63건에 이어 파티 상세 Widget 테스트 43건과 변경 파일 정적 분석이 통과했다. `firestore.rules`는 변경·배포하지 않았다.
- 구현 및 검증 상세는 `DEV_LOG.md`의 `2026-09-12 파티 Build 오류 누락 후속 작업 계획`을 따른다.
- 카탈로그 `2026.09.12`에 환수사 `야성`의 `둔갑 금술 스킬`, 가디언나이트 `드레드 로어`의 `가디언 피어`, 데모닉 `멈출 수 없는 충동`의 `블러드 제노사이드` 등록과 표적 검증을 완료했다. 상세는 `DEV_LOG.md`의 `2026-09-12 세 직업 특수 보석 대상 등록`을 따른다.
- 같은 카탈로그에 차원술사 `시간 관리자`의 `시간선 스킬` 등록과 표적 검증을 완료했다.

## 다음 작업 그룹 — 릴리즈 안정화 인증 안내·파티 통합 오류 Snapshot 보완

### 현재 진행 상태 (2026-09-13)

- A 인증 안내·전용 장비 미착용 오류와 B 파티 통합 오류 Snapshot 전파를 작업 브랜치에 구현했다.
- 파티 생성 리더, 신청·재신청, 직접 참가, 신청 승인, 참가 Character 변경의 신규 쓰기와 신청자·배정/미배정 구성원 읽기·표시를 연결했다. 과거 통합 Snapshot이 없으면 기존 보석 경고로 fallback한다.
- 표적 테스트 93건과 `test/app`, `test/features` 전체 957건이 통과했다. 전체 `flutter test`는 기존 최상위 `test/widget_test.dart`가 Firebase 기본 앱 미초기화로 9건 실패했으며, 이번 변경 경로와 분리해 기록한다.
- 전체 정적 분석은 새 오류 없이 완료됐다. 기존 저장소의 스타일 info 37건과 변경하지 않은 `party_visibility_write_plan_test.dart` 경고 1건은 이번 범위에서 수정하지 않는다.
- Rules 변경은 Character 변경 allowlist의 `buildIntegritySnapshot` 1개 추가뿐이다. 문자열 계약 검사는 통과했지만 Emulator·원격 컴파일·운영 배포와 실기기 검증은 아직 수행하지 않았다.
- 현재 브랜치의 커밋·원격 복구 지점 생성까지만 진행한다. `release/1.0.0`, `dev`, `main` 병합과 버전 확정은 별도 사용자 지시 전까지 금지한다.

### 실기기 증상과 원인

1. 앱 프로세스를 종료하면 진행 중인 장비 인증 Challenge가 남은 시간과 관계없이 종료된다. Challenge를 메모리에만 두는 현재 정책은 유지하되, 사용자가 장비를 해제하기 전에 이 수명을 알 수 있도록 진행 카드에 명시해야 한다.
2. 인증 시작 시 무기·방어구 5부위 중 하나라도 미장착이면 Gateway가 `FormatException`을 발생시키지만, 화면이 이를 다른 형식 오류와 합쳐 `캐릭터 또는 장비 정보를 처리할 수 없습니다.`로 표시한다. 사용자가 바로 해결할 수 있는 전용 장비 착용 안내가 필요하다.
3. 신청·즉시 참가·Character 변경 후보는 로컬 `BuildIntegritySnapshot`으로 보석·아크그리드 복합 오류를 표시하지만, `_ApplySelection`과 파티 명령은 `PartyGemValidationSnapshot`만 전달한다. 신청 `submittedBuildSnapshot`과 파티 membership도 보석 요약만 저장·읽으므로 아크그리드·아크패시브 오류가 신청자 카드와 참가 후 구성원 카드에서 사라진다.

### 작업 순서

#### A. 인증 Challenge 수명·장비 준비 안내

1. 인증 진행 카드에 `앱이 종료되면 남은 시간과 관계없이 현재 인증 시도가 종료됩니다.`를 표시한다.
2. 같은 카드에 `원정대 인증은 인게임에서 장비를 바로 조작할 수 있는 상황에서 진행하는 것을 권장합니다.`를 표시한다.
3. 무기·방어구 5부위 미착용을 일반 `FormatException`과 구분할 수 있는 전용 시작 오류로 전달한다.
4. 전용 오류에는 `인증을 시작하려면 무기와 방어구 5부위를 모두 착용한 뒤 다시 시도해 주세요.`를 표시한다. API 응답 자체의 누락·손상에는 기존 일반 안내를 유지한다.
5. 무작위 지정 부위, 10분 만료, 같은 앱 프로세스의 화면 재진입 복원과 앱 재실행 후 새 인증 시작은 변경하지 않는다.
6. 진행 카드의 두 안내와 장비 미착용 문구를 Widget 테스트로 고정하고, 완전 장착 시 기존 challenge 생성 회귀를 확인한다.

구현 경계:

- `GameAccountVerificationGateway` 계약에 시작 실패 사유를 나타내는 전용 오류 타입을 두고 `incompleteEquipment`를 정의한다. `FormatException.message` 문자열 비교로 분기하지 않는다.
- `LocalGameAccountVerificationGateway.start()`는 roster 불일치·응답 손상과 6부위 미착용을 분리한다. 6부위 중 누락된 부위가 있으면 challenge를 만들거나 기존 challenge를 교체하지 않고 전용 오류를 반환한다.
- `GameAccountVerificationPage._run()`은 전용 오류를 `FormatException`보다 먼저 처리한다. 인증 진행 카드의 수명 안내는 challenge가 있을 때만 표시하고, 시작 전 기본 화면과 인증 성공 후 메시지는 바꾸지 않는다.
- 새 `local_game_account_verification_gateway_test.dart`에서 완전 장착 성공, 1개/복수 부위 누락, 잘못된 `ArmoryEquipment` 구조를 분리한다. 기존 `game_account_verification_page_test.dart`는 전용 착용 문구, 일반 형식 오류 문구, 진행 카드의 두 안내와 같은 프로세스 재진입을 각각 고정한다.

#### B. 신청·membership 통합 오류 Snapshot 전파

1. 기존 보석 상세 요약은 구버전 호환과 상세 개수 표시를 위해 유지하고, 별도 `buildIntegritySnapshot` 최소 map을 dual-write한다.
2. 파티 생성 리더, 신청, 직접 참가, 신청 승인, 참가 Character 변경의 모든 신규 쓰기에 선택 역할의 `BuildIntegritySnapshot`을 전달한다.
3. 신청은 `submittedBuildSnapshot.buildIntegritySnapshot`, membership은 `buildIntegritySnapshot`에 저장한다. 승인 시 신청 Snapshot을 그대로 복사하고 직접 참가·생성·변경은 최신 로컬 Build에서 계산한다.
4. 신청자·파티 구성원 읽기 모델은 새 map을 방어적으로 파싱해 `BuildIntegrityStatusLine`을 사용한다. 과거 문서, 누락·불완전·알 수 없는 schema는 오류 표시만 생략하고 카드와 명령은 유지한다.
5. Character 변경 Rules의 `affectedKeys`에 `buildIntegritySnapshot`만 추가한다. 신청/멤버 생성 Rules는 현재 필드 allowlist가 없지만 기존 소유권·역할·점유·Claim·파티 구성 조건이 그대로 유지되는지 계약 테스트로 고정한다.

구현 경계:

- 후보 서비스가 이미 역할별로 계산한 `BuildIntegritySnapshot?`을 `_ApplySelection`과 `PartyApplyCommand`, `PartyDirectJoinCommand`, `PartyChangeCharacterCommand`, `PartyCreateCommand`에 nullable 필드로 그대로 운반한다. 명령 Repository에서 Armory를 다시 조회하거나 상태를 재계산하지 않는다.
- `PartyApplicationWritePlan.create/reapply()`는 기존 flat 보석 필드를 유지하면서 `submittedBuildSnapshot.buildIntegritySnapshot`에 통합 map을 추가한다. 기존 신청의 철회·거절·승인 상태 전이는 이 Snapshot을 수정하지 않는다.
- `PartyCreateWritePlan`, `PartyJoinWritePlan`, `PartyMembershipWritePlan.changeCharacter()`는 membership 최상위 `buildIntegritySnapshot`을 기록한다. 승인 참가에서는 신청 당시 nested map을 방어적으로 복사하고, 직접 참가·파티장 생성·Character 변경에서는 선택 당시 로컬 값을 사용한다.
- `PartyReadDocumentMapper`, `PartyApplicationSummary`, `PartyMemberDisplay`에 nullable 통합 상태를 추가한다. `BuildIntegritySnapshot.tryFromFields()`가 `null`을 반환하는 과거·손상·미지원 schema에서는 통합 경고만 생략하고 기존 `gemValidation`과 카드 본문은 유지한다.
- 신청자 카드와 배정/미배정 구성원 카드는 통합 상태가 있으면 `BuildIntegrityStatusLine`을 사용한다. 정상·review·unavailable은 기존처럼 비표기하고 확정 오류만 빨간색으로 표시한다. 통합 상태가 없을 때는 기존 보석 경고를 fallback으로 유지해 구버전 문서의 표시가 사라지지 않게 한다.
- 파티 Character 변경 Rules allowlist 외의 Rules 조건과 그룹 Rules는 수정하지 않는다. 새 필드는 표시용 클라이언트 Snapshot이며 참가 허용·거절 판정에 사용하지 않는다.

### 구현 커밋 구간

1. `fix: clarify local verification guidance` — 인증 전용 오류, 안내 UI와 인증 표적 테스트만 포함한다. Rules·파티 모델은 건드리지 않는다.
2. `feat: propagate party build integrity snapshot` — 후보 선택·명령·Write Plan·승인 복사·읽기 모델·카드와 관련 테스트를 한 계약 단위로 연결한다.
3. `test: validate party build integrity rules` — Character 변경 Rules allowlist와 Rules 계약 테스트를 함께 반영한다. Rules 파일을 바꾸는 커밋은 앱 코드 커밋과 분리해 배포 대상을 명확히 한다.
4. `docs: record release stabilization verification` — 자동·Rules·실기기 결과와 남은 항목을 기록한다. 검증 전에는 완료로 쓰지 않는다.

각 구간은 현재 릴리즈 안정화 작업 브랜치에 순서대로 쌓고 원격에 복구 지점을 남긴다. 구현·검증 중에는 `dev`, `main`, `release/1.0.0`을 이동하지 않는다. 최종 릴리즈 브랜치 흡수와 버전 확정은 별도 사용자 지시에 따른다.

### 회귀 보호 목록

- 인증: 가등록/직접 입력 시작, 완전 장착/6부위 중 일부 미착용, 10분 만료, 지정 부위 미해제, 비지정 부위 변경, 성공 후 로컬 ID binding, 같은 프로세스 재진입과 앱 재실행 후 새 시도
- 파티 후보: 정상·판정 불능 비표기, 보석/아크그리드 단독 오류와 복합 오류 표시, 오류 Character도 기존처럼 선택 가능
- 신청: 최초 신청·철회·재신청, 파티장 승인·거절, 신청 당시 Snapshot 불변성
- membership: 공개/그룹 파티장 생성, 직접 참가, 승인 참가, Character/역할 변경, 과거 null Snapshot 읽기
- 기존 서버 계약: Character 소유권, 활동 Character, 동일 레이드 Claim/assignment, 역할·동일 직업 구성, 그룹 공개 범위와 listing 쓰기 순서

### 제외 범위

- 인증 Challenge의 기기 영속 저장·재시작 복원, Firestore 저장과 Firebase Functions 전환
- 전체 Armory JSON·보석 Tooltip·장비 Tooltip의 서버 업로드
- 기존 신청·membership 문서의 일괄 마이그레이션
- Build 오류를 참가 자격 차단 조건으로 변경
- 그룹 membership Snapshot 재설계. 그룹은 이미 Character의 서버 `buildIntegritySnapshot`을 표시하는 현재 경계를 유지한다.

### 완료 조건

- 진행 카드가 앱 종료 시 인증 시도 종료와 인게임 즉시 조작 권장을 명확히 알린다.
- 6부위가 모두 장착되지 않은 시작 실패는 일반 정보 확인 실패와 구분되어 사용자가 취할 조치를 안내한다.
- 신청 전 후보에서 보인 보석·아크그리드 확정 오류가 신청자 카드와 승인/직접 참가/Character 변경 후 구성원 카드에서도 같은 의미로 표시된다.
- 과거 문서와 구버전 보석 요약 호환, 기존 인증 성공·파티 권한·점유·구성 흐름을 보존한다.
- 표적·영향 회귀와 변경 파일 정적 분석을 통과한다. Rules 변경은 계약 검사·경고 0개를 확인한 최신 추적본만 운영에 한 번 배포하고 실기기 재검증한다.

자동 구현·검증은 완료했다. 최종 완료 판정에는 Rules 원격 컴파일 경고 0개·허가된 운영 배포 성공과 위 실기기 항목 확인이 남아 있다.

### 검증 실행 묶음

1. 문서·각 커밋 공통: 포맷, `git diff --check`, 변경 diff 검토
2. 인증 구간: Gateway 테스트와 `game_account_verification_page_test.dart`
3. 파티 Domain/저장 구간: application/create/join/membership Write Plan, read mapper, 후보·명령 Repository 표적 테스트
4. 파티 UI 구간: 신청, 직접 참가, 승인, 공개/그룹 파티장, Character 변경과 과거 null 문서 Widget 테스트
5. Rules 구간: 파티 Rules 문자열 계약과 Emulator 계약, 컴파일 경고 0개 확인
6. 최종 영향 검증: 계정 인증 전체, 파티 모집·상세·주차/Claim·그룹 연결 영향 테스트, 변경 파일 `flutter analyze`; 저장 schema와 공용 Domain 영향이 넓으므로 전체 `flutter test`와 전체 `flutter analyze` 결과도 별도 기록
7. 실기기: 인증 안내/미착용 문구, 아크그리드 단독 오류 신청·승인·직접 참가·Character 변경, 기존 정상·보석 오류 캐릭터와 공개/그룹 파티 흐름

## 차후 후보

- 앱을 종료하지 않은 채 수요일 06:00 KST 주차 경계를 통과할 때 Router 생성 시 계산된 `currentCycleKey`가 자동 갱신되는지 확인하고, 필요하면 앱 수명주기 기반 재계산을 안정화한다.
- 딜러 직업·깨달음 분기별 특수 보석 대상의 점진적 카탈로그 추가(상시 운영)
- 룬·각인·카드·엘릭서 등 통합 무결성 상태 확장
- Build 별칭·직업 메모·JSON 공유: `BUILD_MEMO_SHARING.md`
- 서버 데이터 무결성·고아 binding/claim·복구 절차
- 직업 시너지 선택·필터: `CLASS_SYNERGY_CATALOG.md`
- `characters` Rules의 넓은 `signedIn()` 읽기·쓰기 권한 재설계
