# NEXT WORK

> 다음에 바로 진행할 단일 작업 그룹의 근거·범위·순서·완료 조건만 관리한다. 완료 경과는 `DEV_LOG.md`로 이동한다.

## 현재 인계 상태

- 통합 기준은 로컬·원격이 같은 `dev`의 `a25e6c3`다. 계획 브랜치는 `codex/plan-character-build-integrity-status`다.
- 파티·그룹 membership 표시 Character의 `gemValidationSnapshot`과 그룹원 목록 행 경고는 구현·운영 반영·실기기 회귀까지 완료됐다.
- 그룹원 활동 Character 팝업은 `characterActivity` ID와 `characters`의 `ownerPlayerId + active` 조회 결과를 교집합해 표시한다. 별도 projection 컬렉션은 사용하지 않는다.
- 로컬 `CharacterBuildSnapshot`에는 보석·아크그리드 분석이 이미 있다. 서버 `characters`는 전체 Build Snapshot이 아니라 이름·직업·아이템 레벨·전투력 중심의 최소 표시 문서이며 통합 무결성 상태는 아직 없다.
- 성공한 자동·수동 계정 갱신은 이미 `CharacterMinimumDisplaySyncService`를 통해 해당 서버 Character의 아이템 레벨·전투력을 한 Transaction으로 보강한다.

## 2026-09-11 사전 크로스 체크 결과

- 운영 DI는 앱 실행 1회 갱신과 내 계정 수동 갱신에 같은 `CharacterAutoRefreshCoordinator → CharacterMinimumDisplaySyncService → FirestoreCharacterMinimumDisplaySyncGateway` 인스턴스 흐름을 연결한다.
- 최소 표시 Transaction의 현재 확인 순서는 `Auth binding → active Player → active Character/ownerPlayerId → active playerGameAccounts 소유권 → 변경값 비교 → update`다. 이번 작업은 이 순서와 읽기 수를 바꾸지 않는다.
- 그룹원 목록은 membership Rules를 먼저 통과한 화면에서만 열린다. 활동 목록 데이터 자체는 현재 `characterActivity: hasActiveBinding`, `characters: signedIn` 권한이며 이번 작업에서 Rules를 수정하지 않는다.
- 그룹 `allow update`의 해산·초대코드·가입·승인·탈퇴·이전 OR 순서와 파티 Rules는 이번 데이터 경로와 분리돼 있다.
- Character 최소 표시 Sync, 자동 갱신·나이스단, 활동 Character Rules 계약, 그룹 Rules 계약·그룹원 표시 회귀 79건을 현재 코드에서 묶어 실행해 모두 통과했다.
- 일반 인증과 수동 인증의 Character 전체 `set`이 선택 표시 필드를 소실할 수 있는 위험을 확인했다. 구현 시 두 경로의 명시적 보존을 별도 구간과 테스트로 처리한다.

## 다음 작업 그룹 — Character Build 무결성 상태와 그룹 활동 목록 표시

### 1. 최우선 목표

계정 데이터 갱신에서 산출한 Character Build 무결성 상태를 기존 서버 Character 최소 표시 문서에 함께 저장하고, 그룹원 활동 Character 목록에 `정상 / 보석 / 아크그리드 / 확인 필요` 상태를 간결하게 표시한다.

**기존 Character 갱신·인증·활동 선택, 그룹·파티·레이드 흐름에 오류를 만들지 않는 것**을 첫 번째 완료 기준으로 둔다. 그룹 상세 진입 시 새 쓰기나 Lost Ark API 호출을 만들지 않는다.

### 2. 제안 검토 결론

사용자 제안처럼 보석 전용 `gemValidationSnapshot`을 Character 문서에 추가하는 것보다, 이미 로컬 Build 분석이 가진 보석과 아크그리드를 하나의 통합 상태로 축약해 계정 갱신 때 붙이는 편이 낫다.

다만 `ERRORCHECK: CLEAN | GEM | ARKGRID` 같은 단일 문자열은 다음 문제가 있다.

- 보석과 아크그리드 오류가 동시에 있으면 하나를 잃는다.
- 미확인과 정상 상태를 구분하기 어렵다.
- 새 오류 종류를 추가할 때 기존 앱과 계약이 쉽게 깨진다.
- 어떤 역할 Build를 언제 검사했는지 알 수 없어 오래된 상태를 최신으로 오해할 수 있다.

따라서 필드명은 의미가 드러나는 `buildIntegritySnapshot`으로 하고, 전체 상태와 복수 코드가 있는 작은 map을 사용한다. UI는 사용자가 원하는 짧은 한글 상태만 표시한다.

### 3. 고정 데이터 계약

`characters/{characterId}.buildIntegritySnapshot`:

```text
schemaVersion: 1
status: clean | review | error | unavailable
issueCodes: string[]
role: dealer | support
checkedAt: timestamp
catalogVersion: string | null
```

초기 허용 `issueCodes`:

```text
foreignClassGem       // error, UI: 보석
sameClassGemUnverified // review, UI: 보석 확인 필요
gemUnavailable        // review, UI: 보석 정보 없음
arkGridMinimum        // error, UI: 아크그리드
arkGridCondition      // error, UI: 아크그리드
```

판정 우선순위는 `error > review > clean`이다. 분석 자체를 신뢰할 수 없을 때만 `unavailable`이다.

- `clean`: 보석과 아크그리드 검사 모두 가능하고 확정 오류·검토 코드가 없다.
- `review`: 다른 직업 보석으로 확정할 수 없지만 동일 직업 대상 미확인 또는 보석 정보 부족이 있다.
- `error`: 다른 직업 보석, 질서의 해·달 누락/14P 미달 또는 현재 분기의 아크그리드 조건 불충족이 하나 이상 있다.
- `unavailable`: 역할 또는 분석 기반을 만들 수 없어 정상이라고 판단할 수 없다.
- `issueCodes`는 중복 없이 정해진 순서로 저장한다. 보석과 아크그리드가 동시에 잘못되면 두 코드를 모두 보존한다.
- `checkedAt`은 서버 쓰기 시각이 아니라 원본 Build Snapshot의 `capturedAt`이다.
- `role`은 실제 요약에 사용한 Build Snapshot 역할이다. 선호 역할이 있으면 해당 역할의 최신 Snapshot만 사용한다.
- 전체 Armory JSON, Tooltip, 보석명, 스킬명, 상세 포인트는 서버에 저장하지 않는다.
- 이 값은 클라이언트 표시 정보이며 소유권·인증·그룹 가입·레이드 참가 자격의 근거로 사용하지 않는다.

### 4. 갱신 시점과 데이터 흐름

```text
앱 실행 1회 갱신 또는 내 계정 수동 갱신
→ Armory 응답 분석
→ CharacterBuildSnapshot 로컬 저장
→ 같은 역할 기준 BuildIntegritySnapshot 생성
→ 기존 CharacterMinimumDisplayPatch에 포함
→ 기존 소유권 확인 Transaction에서
   itemAvgLevel + combatPower + buildIntegritySnapshot 변경분만 update
→ 그룹원 활동 Character 팝업은 기존 Character 조회에서 상태를 읽음
```

- 그룹 상세 진입·그룹원 카드 탭은 읽기만 한다.
- 서버 동기화 때문에 기존 API 요청 수나 Character별 Transaction 수를 늘리지 않는다.
- 값이 모두 같으면 기존처럼 쓰기를 생략한다. 통합 상태만 있다는 이유로 기존의 `아이템 레벨·전투력 없음 → 서버 동기화 생략`을 명령 차단 경로로 바꾸지 않는다. 현재 1700 이상 계정 갱신은 itemLevel과 함께 상태를 전달한다.
- 서버의 `checkedAt`이 요청보다 최신이면 늦게 끝난 오래된 요청은 무결성 필드를 덮지 않는다. 숫자 표시값의 기존 갱신 의미는 별도 테스트로 보존한다.
- 갱신 또는 서버 동기화 실패 시 기존 서버 상태를 지우지 않는다. 화면은 저장된 상태를 표시하고, 상태가 없으면 기존 수치만 표시한다.
- 나이스단 자동 갱신 제외, 1700 미만, 서버 ID 없음 등 현재 갱신 대상이 아닌 Character는 새 상태를 억지로 만들지 않는다. 기존 로컬 수동 Snapshot을 자동 업로드하는 범위도 이번에 추가하지 않는다.

### 5. 기존 스냅샷과의 관계

- 로컬 `CharacterBuildSnapshot`은 상세 원본이며 그대로 유지한다.
- 서버 Character의 `buildIntegritySnapshot`은 타인에게 보여줄 최소 파생 요약이다.
- 파티 신청·파티 membership·그룹 membership의 기존 `gemValidationSnapshot`은 시점 고정 및 기존 UI 호환을 위해 변경하거나 이행하지 않는다.
- 활동 Character 팝업만 새로운 통합 상태를 사용한다. 이후 파티·membership을 통합 상태로 바꾸는 작업은 별도 결정이다.

### 6. 포함 범위

- 공용 `BuildIntegritySnapshot` 값 객체, 상태·issue code와 방어적 parser
- 기존 `CharacterBuildAnalysis`에서 통합 요약을 만드는 순수 mapper
- `CharacterMinimumDisplayPatch`와 기존 Firestore Gateway에 선택 필드 추가
- 같은 기존 Transaction에서 변경분만 update, 동일값 no-op, 최신 `checkedAt` 보호
- `GroupRequestCharacter`의 nullable 통합 상태와 Character mapper 연결
- 그룹 활동 Character bottom sheet의 짧은 상태 표시
- 기존 Character 재인증·수동 인증 시 `combatPower`와 `buildIntegritySnapshot` 보존
- Router는 기존 최소 표시 Sync 연결을 그대로 사용하며 신규 DI를 추가하지 않음
- 관련 Domain/mapper/Gateway/Coordinator/인증/UI 및 영향 회귀 테스트
- 제품·아키텍처·완료 이력 문서 최신화

### 7. 제외 범위

- 기존 파티·그룹 membership `gemValidationSnapshot` 교체·마이그레이션
- 룬 오류, 각인, 카드, 엘릭서 등 새 판정 종류
- 보석·아크그리드 판정 알고리즘과 게임 카탈로그 자체 수정
- 전체 Armory 또는 Build 상세의 서버 저장
- 그룹 상세 진입 시 API 호출·쓰기·자동 최신화
- 별도 projection 컬렉션, 새 쿼리, 인덱스, 백필
- 활동 Character 선택·대표 Character·표시 순서 정책 변경
- Character Rules의 기존 광범위한 `signedIn()` 권한 보안 부채 해결
- 그룹·파티·레이드 명령과 membership 저장 구조 변경

### 8. 사전에 확인한 버그 위험과 대비

1. **복수 오류 손실**: 단일 enum 대신 `issueCodes` 목록으로 보석+아크그리드를 함께 저장한다.
2. **미확인을 정상으로 표시**: 분석 불가와 보석 미확인을 `unavailable/review`로 분리하고 `clean` 조건을 엄격히 둔다.
3. **역할 불일치**: 아이템 레벨·전투력에 쓰는 기존 display Snapshot 선택을 재사용한다. 선호 역할과 갱신 역할이 다르고 저장된 선호 역할 Snapshot이 없으면 무결성 상태를 쓰지 않는다.
4. **늦은 응답의 최신값 역전**: `checkedAt`을 비교해 오래된 Snapshot이 최신 무결성 상태를 덮지 못하게 한다.
5. **실패 시 정상값 삭제**: null/분석 실패/동기화 실패는 기존 map을 삭제하지 않는다.
6. **구버전 문서 파싱 실패**: 필드 부재·null·불완전 map·알 수 없는 코드/상태는 무결성 정보만 null로 낮추고 Character 행을 유지한다.
7. **재인증 시 필드 소실**: 현재 일반 인증과 수동 인증 두 경로가 Character 문서를 merge 없이 `set`한다. 두 경로에서 기존 `combatPower`와 유효한 `buildIntegritySnapshot`을 명시적으로 보존하고 회귀 테스트를 추가한다.
8. **불필요한 쓰기·비용 증가**: 기존 최소 표시 Transaction에 포함하고 전체 값이 같으면 `updatedAt`도 쓰지 않는다.
9. **활동 해제 Character 노출**: 상태 유무와 무관하게 기존 `characterActivity` ID 교집합을 최종 노출 조건으로 유지한다.
10. **기존 명령 차단**: 무결성 상태는 표시 전용이며 Validator·Rules·가입/참가 명령 조건에서 읽지 않는다.
11. **오래된 앱 호환**: 기존 앱의 부분 `update`는 새 필드를 건드리지 않는다. 전체 `set` 경로는 위 보존 규칙으로 보호한다.
12. **UI 오버플로**: 기존 한 줄 subtitle에 문자열을 이어 붙이지 않고 보조 행/Chip으로 분리해 좁은 폭을 테스트한다.
13. **공용 후보 모델의 간접 영향**: `GroupRequestCharacter`는 그룹 초대 검색과 레이드 현황 필터도 사용한다. nullable 상태 추가는 기존 필수 생성값·정렬·필터·동등성 판단에 참여시키지 않고 그룹 활동 목록 UI에서만 소비한다.
14. **그룹/파티 Rules 순서 회귀**: `groups` update OR 순서, membership/join relation Rules, 파티 membership Rules와 `firestore.rules` 자체를 수정하지 않는다. 관련 Rules 계약 테스트를 그대로 회귀 실행한다.
15. **선택 정보가 핵심 동기화를 실패시키는 문제**: 상태 mapper/parser는 예외를 밖으로 던지지 않고 nullable 결과를 반환한다. 통합 상태 직렬화 실패만으로 기존 itemLevel·combatPower 동기화 또는 향후 명령 진행을 실패시키지 않는다.

### 9. 세부 작업 순서

#### A. 순수 계약과 판정 mapper

- `BuildIntegritySnapshot`, status, issue code를 공용 Character Build 영역에 추가한다.
- 보석 요약, 아크그리드 최소 조건, 분기 조건에서 issue code를 만드는 mapper를 작성한다.
- 복수 오류, review, clean, unavailable 및 역할·시각·카탈로그 버전을 테스트로 고정한다.

#### B. 기존 계정 갱신 Transaction 확장

- `CharacterMinimumDisplayPatch`에 nullable 통합 상태를 추가하되 기존 숫자 표시값의 조기 종료·명령 성공 의미를 유지한다. 통합 상태는 성공한 계정 갱신의 기존 최소 표시 update에 동반한다.
- `CharacterMinimumDisplaySyncService`가 기존 display Snapshot과 같은 역할 Snapshot으로 요약을 만든다.
- Firestore Gateway가 숫자와 통합 상태를 같은 Transaction에서 비교·갱신한다.
- 동일값, 오래된 `checkedAt`, null 보존, 소유권 거절과 prefetch 동기화 실패 의미를 기존 테스트에 추가한다.

#### C. Character 전체 set 보존

- 일반 게임 계정 인증과 수동 인증의 Character `set` 경로 두 곳을 확인한다.
- 재인증 시 서버 식별·프로필 필드는 현재 값으로 갱신하되 기존 `combatPower`와 유효한 `buildIntegritySnapshot`을 보존한다.
- 신규 Character, 기존 선택 필드가 없는 Character, 손상된 map, 소유권 변화 경로를 테스트한다.

#### D. 그룹 활동 Character 읽기·UI

- `GroupRequestCharacter`에 nullable 통합 상태를 추가한다.
- 기존 `ownerPlayerId + status` query, 레벨 정렬, 활동 ID 교집합을 바꾸지 않고 map만 방어적으로 읽는다.
- 팝업 행은 `error`일 때 `보석`, `아크그리드`를 각각 표시하고, `review`는 중립 `보석 확인 필요`, `clean`은 추가 표시 없음으로 한다.
- 두 오류 동시 표시, 구버전/손상 문서, 빈 목록, 조회 오류, 중복 탭과 좁은 폭을 테스트한다.

#### E. 최종 회귀·문서·Git

- 아래 자동 검증과 실기기 체크리스트를 한 번씩 수행한다.
- 새 흐름, 보존 확인한 기존 흐름, 미확인 항목을 `DEV_LOG.md`에 분리해 기록한다.
- 기능 브랜치 검증 후 `dev`에 병합·푸시하고 로컬/원격 일치와 깨끗한 작업 트리를 확인한다.

### 10. 자동 검증 계획

- Domain mapper: clean/review/error/unavailable, 보석+아크그리드 복수 오류, 순서·중복 제거
- Snapshot parser: 필드 부재/null/불완전 타입/알 수 없는 코드/음수 버전/역할 오류
- Minimum sync: 기존 숫자 없음 생략 의미 유지, 같은 Transaction 동반, 동일값 no-op, stale write 거절, null 보존
- Coordinator: 자동 prefetch 성공, 서버 동기화 실패 시 로컬 성공 유지·TTL 미저장, 기존 command 실패 의미 불변
- 인증: 일반·수동 재인증에서 `combatPower`와 통합 상태 보존, 신규 문서 정상 생성
- 그룹 Repository/ViewModel: 기존 query·정렬·활동 교집합·비활동 제외 불변
- UI: 정상 숨김, review 중립, 보석/아크그리드 오류 및 동시 오류, 구버전 행 유지, 360px 오버플로 없음
- 영향 회귀: 앱 실행 1회 갱신, 수동 갱신, 나이스단 제외, Character 인증·활동 선택, 그룹 생성·가입·탈퇴·이전·해산, 파티·그룹 membership 기존 보석 표시
- `git diff --check`, 변경 파일 analyze, 최종 전체 `flutter test`, 전체 `flutter analyze`에서 기존 기준 대비 신규 문제 없음

중간 A~D에서는 테스트 코드를 함께 작성하고 코드 포맷·diff 검토만 한다. 공용 인터페이스 변경으로 다음 단계의 컴파일 기반 확인이 꼭 필요할 때만 가장 좁은 테스트를 한 번 먼저 실행한다.

### 11. 실기기 체크리스트

1. 정상 Build 계정 갱신 후 그룹 활동 목록에 추가 오류 표시가 없다.
2. 다른 직업 보석 Character는 `보석`, 아크그리드 최소/조건 불충족 Character는 `아크그리드`가 표시된다.
3. 두 문제가 동시에 있는 Character는 두 상태가 모두 표시된다.
4. 동일 직업 대상 미확인은 빨간 오류가 아니라 중립 `보석 확인 필요`다.
5. 소유자 기기에서 갱신한 뒤 상대 기기의 기존 그룹 상세 재조회로 상태가 보인다. 상대 기기는 쓰기나 API 호출을 하지 않는다.
6. 갱신 실패·미지원·나이스단 제외 Character는 과거 정상 상태를 임의로 지우거나 새 `clean`으로 바꾸지 않는다.
7. 계정 재인증·수동 인증 후 전투력과 무결성 상태가 사라지지 않는다.
8. 활동 해제 Character는 그룹 활동 목록에서 빠지지만 기존 레이드 membership·Claim은 유지된다.
9. 그룹 생성·가입 신청/승인·초대 수락·코드 가입·탈퇴·그룹장 이전·해산과 기존 파티/그룹 보석 경고가 동일하게 동작한다.

### 12. 완료 조건

- 계정 갱신 성공 시 기존 Character 최소 표시 Transaction에 통합 무결성 상태가 함께 반영된다.
- 그룹 활동 Character 목록에서 정상, 보석, 아크그리드, 복수 오류와 확인 필요 상태가 정확히 구분된다.
- 단일 오류 문자열의 정보 손실, 역할 불일치, 오래된 응답 역전, 재인증 필드 소실을 테스트로 차단한다.
- 새 API 호출·Transaction·쿼리·인덱스·컬렉션·Rules 변경 없이 구현된다. 불가능하다고 확인되면 범위를 넓히지 않고 다시 협의한다.
- 기존 Character·그룹·파티·레이드 회귀, 최종 자동 검증과 실기기 체크리스트가 통과한다.
- 문서 정리 후 기능 브랜치가 `dev`에 병합·푸시되고 로컬·원격 `dev`가 일치한다.

### 13. 남는 기존 제약

- 현재 운영 Rules의 `characters`는 `signedIn()` 사용자에게 넓게 열려 있다. Repository가 소유권을 확인하지만 서버 Rules가 통합 상태의 진위를 보장하지는 않는다. 이번 표시 기능과 권한 재설계를 섞지 않는다.
- 이미 배포된 구버전 앱이 merge 없는 재인증 `set`을 실행하면 선택 표시 필드를 지울 수 있다. 새 버전의 두 인증 경로는 이를 보존하고, 지워진 상태는 다음 성공한 새 버전 계정 갱신에서 복구한다. 이 위험을 완전히 막으려면 별도 Rules/서버 쓰기 권한 작업이 필요하다.
- `characterActivity`와 `characters`는 현재 그룹원 전용 서버 읽기가 아니다. 화면 진입은 그룹 membership으로 제한하지만 데이터 권한을 그룹 단위로 재설계하지 않는다.

## 차후 대기

- 기존 파티·그룹 membership 보석 Snapshot을 통합 Build 상태로 바꿀지 별도 검토
- 룬·각인·카드·엘릭서 등 통합 무결성 상태 확장
- Build 별칭·직업 메모·JSON 공유: `BUILD_MEMO_SHARING.md`
- 여러 일반 딜러 직업의 실계정 확대 검증
- 서버 데이터 무결성·고아 binding/claim·복구 절차
- 직업 시너지 선택·필터: `CLASS_SYNERGY_CATALOG.md`
