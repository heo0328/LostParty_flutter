# NEXT WORK

> 다음에 바로 진행할 단일 작업 그룹의 근거·범위·순서·완료 조건만 관리한다. 완료 경과는 `DEV_LOG.md`로 이동한다.

## 현재 인계 상태

- 현재 브랜치는 `codex/implement-build-error-policy`, 최신 체크포인트는 `4d1b129`다. 확정 Build 오류 판정과 오류 전용 표시는 구현·자동 검증됐고 실기기에서 내 계정과 신청자 카드의 스킬 불일치 오류를 확인했다.
- 그룹원의 활동 Character 목록 팝업은 Character 문서의 로컬 `buildIntegritySnapshot`을 사용해 보석과 아크그리드 오류를 함께 표시한다.
- 실기기에서 새 모집의 파티장 본인 카드에는 같은 보석 오류가 표시되지 않았다. 구성원 카드에 소유자 예외가 있는 것이 아니라, 파티 생성 경로가 파티장 membership에 `gemValidationSnapshot`을 쓰지 않는 것이 원인이다.
- 신청은 `submittedBuildSnapshot`, 승인·직접 참가·참가 Character 변경은 membership의 `gemValidationSnapshot`을 정상 전달한다. 이 경로와 파티·그룹 권한 및 명령 순서는 회귀 보호 대상이다.

## 다음 작업 그룹 — 파티장 오류 Snapshot 보완과 참가 Character 변경 목록 표시

### 1. 목표

1. 새 파티를 만들 때 파티장 membership에도 선택한 역할의 보석 최소 요약을 저장해, 본인과 다른 사용자가 보는 파티 구성 카드에 동일한 빨간 보석 오류가 표시되게 한다.
2. 파티 상세의 `내 참가 Character 변경` 목록에서 그룹 활동 Character 팝업과 같은 기준으로 보석 및 아크그리드 확정 오류를 빨간색으로 표시한다.
3. 정상과 API·파싱 불능은 계속 비표기하고, 오류 상태를 가입 자격이나 Character 선택 차단에 사용하지 않는다.

### 2. 데이터 흐름과 경계

#### 파티 생성 리더

- `RecruitmentLeaderCandidateService`가 선택 역할에서 만든 기존 `PartyGemValidationSnapshot`을 모집 생성 화면이 `PartyCreateCommand`로 전달한다.
- `PartyCreateWritePlan`은 그 값을 새 파티장 membership의 `gemValidationSnapshot`에 기록한다. 모집 원본, assignment, group raid listing에는 중복 저장하지 않는다.
- 파티 상세 Reader와 구성원 카드의 기존 방어적 parser·`GemValidationLine`을 그대로 사용한다. 본인/타인 분기 코드는 추가하지 않는다.
- 기존 membership에 필드가 없으면 현재처럼 `null`로 읽고 카드 자체는 정상 표시한다. 이번 작업에서 기존 파티 일괄 이행이나 화면 진입 시 자동 쓰기는 하지 않는다.

#### 참가 Character 변경 목록

- 후보 조회·역할 판정·점유 및 파티 구성 필터는 현재 `RecruitmentLeaderCandidateService` 결과를 그대로 사용한다.
- 역할 후보에 서버 전송용 `PartyGemValidationSnapshot`과 별도로, 같은 로컬 `CharacterBuildSnapshot`에서 계산한 표시 전용 `BuildIntegritySnapshot`을 선택 필드로 제공한다.
- 변경 Sheet는 그룹 활동 Character 팝업과 같은 `BuildIntegrityStatusLine`을 재사용한다. 따라서 보석과 아크그리드 오류가 동시에 있으면 둘 다 보존·표시되고, 정상·review·unavailable은 빈 표시가 된다.
- 실제 변경 명령에는 지금과 같이 보석 최소 요약만 전달한다. 파티 membership에 통합 `buildIntegritySnapshot`을 추가하지 않으며 아크그리드 상태를 서버에 새로 저장하지 않는다.

### 3. 포함 범위

- 파티 생성 명령의 선택적 파티장 보석 요약과 생성 화면 연결
- 파티장 membership Write Plan 저장 및 방어적 읽기 회귀
- 로컬 참가 Character 역할 후보의 선택적 통합 Build 상태
- 참가 Character 변경 Sheet의 보석·아크그리드 오류 전용 표시
- 생성·후보 서비스·파티 상세 UI·Reader/Write Plan의 직접 영향 테스트
- 신규 파티의 본인/타인 표시와 Character 변경 실제 실행에 대한 실기기 확인

### 4. 제외 범위

- 기존 파티 membership 일괄 마이그레이션 또는 화면 진입 보정 쓰기
- 파티 membership에 `buildIntegritySnapshot` 또는 아크그리드 요약 저장
- 신청 Character 선택 Sheet 등 사용자가 요청하지 않은 다른 후보 목록 UI 확대
- 오류에 따른 모집 생성·신청·참가·Character 변경 차단
- 특수 스킬 카탈로그 추가, 판정 issue code 또는 v2 schema 변경
- Firestore 쿼리·인덱스·컬렉션·Rules 변경과 배포
- 그룹 팝업 데이터 흐름·활동 ID 교집합·표시 변경

### 5. 작업 순서

#### A. 계약 테스트 선행

- `PartyCreateCommand`의 선택 필드가 없을 때 기존 생성 결과가 같고, 있을 때 파티장 membership에 v2 보석 map이 생성되는 테스트를 추가한다.
- 후보 역할별 `BuildIntegritySnapshot`이 같은 역할의 기존 보석 요약과 동일한 로컬 분석에서 생성되는지 고정한다.
- 변경 Sheet에서 보석·아크그리드 복합 오류, 보석만, 아크그리드만, 정상·판정 불능 비표기를 고정한다.

#### B. 파티 생성 리더 전파

- 생성 화면 → `PartyCreateCommand` → `PartyCreateWritePlan.leaderMembership`만 최소 변경한다.
- Repository의 Character 소유권·입장 레벨·점유·신청 철회 확인과 Transaction 읽기/쓰기 순서를 변경하지 않는다.

#### C. 참가 Character 변경 목록 표시

- 후보 역할 옵션에 선택적 통합 상태를 추가하고 기존 `gemValidation` 전달을 유지한다.
- `_ChangeCharacterCandidateSheet`의 기존 이름·원정대·직업·역할 정보 아래에 공용 오류 행을 추가한다. 같은 오류를 보석 전용 행과 중복 표시하지 않는다.
- 선택, 취소, 로딩, 변경 가능 후보 없음 및 실제 Character 변경 명령은 기존 동작을 유지한다.

#### D. 회귀 검증과 문서

- 포맷·`git diff --check` 후 생성/Write Plan, 후보 서비스, 파티 상세, Reader와 직접 영향 테스트를 한 번 묶어 실행한다.
- 변경 파일 `flutter analyze`를 실행한다. 공용 Domain 영향이 예상보다 넓으면 전체 `flutter test`를 한 번 실행하고 기존 기준 실패와 신규 실패를 분리한다.
- `firestore.rules` diff가 없음을 확인한다. 예상 밖 Rules 변경이 필요하면 구현을 멈추고 별도 설계·배포 승인을 받는다.
- 자동 검증 후 아래 실기기 체크리스트를 한 번 수행하고 결과를 `DEV_LOG.md`에 기록한다.

### 6. 회귀 보호 목록

1. 파티 생성의 소유 Character 확인, active assignment/Claim 충돌, 동일 레이드 신청 철회 확인과 생성 Transaction 원자성을 유지한다.
2. 파티장 `partyIndex 0`, `slotIndex 0`, 승인권과 모집 인원·역할 집계를 유지한다.
3. 공개/그룹 모집 생성 및 group raid listing Projection은 기존과 동일하다.
4. 신청자 Snapshot, 신청 승인 복사, 직접 참가와 참가 Character 변경의 기존 `gemValidationSnapshot` 전달을 유지한다.
5. 구성원 카드에는 본인/타인 예외 없이 Snapshot이 있으면 오류를 표시하고, 과거·누락·손상 map은 카드 전체를 깨뜨리지 않는다.
6. Character 변경 후보의 소유권, 레벨, 점유, 같은 직업 딜러 제한, 역할 여유, 같은 Character 반대 역할과 다음 주차 준비 규칙을 유지한다.
7. 변경 목록의 오류는 안내만 하며 후보 필터·정렬·선택 결과에 영향을 주지 않는다.
8. 그룹원 목록과 활동 Character 팝업의 조회 횟수, 활동 ID 교집합 및 기존 보석·아크그리드 표시를 변경하지 않는다.
9. 정상·review·unavailable은 추가 문구 없이 유지하고 확정 오류만 빨간색으로 표시한다.
10. 보석과 아크그리드가 동시에 오류면 변경 목록에 두 영역을 모두 표시하며 같은 보석 오류를 중복 표시하지 않는다.

### 7. 실기기 체크리스트

1. 스킬 불일치 또는 보석 부족 Character로 새 파티를 만들면 파티장 본인 카드에 빨간 보석 오류가 보인다.
2. 다른 계정이 같은 파티 상세를 열어도 파티장 카드의 같은 오류가 보인다.
3. 기존 `gemValidationSnapshot` 없는 파티를 열어도 카드와 파티 기능은 정상이다.
4. 참가 Character 변경 목록에서 보석 오류와 아크그리드 오류가 각 조건에 맞게 표시되고, 복합 오류는 둘 다 보인다.
5. 정상 Character와 원본 정보 부족 Character에는 상태 문구가 없다.
6. 오류가 있는 Character도 선택 가능하고 실제 변경이 성공하며, 변경 후 구성원 카드에는 기존 보석 최소 요약이 반영된다.
7. 공개/그룹 파티 생성, 신청·승인·직접 참가·Character 변경·탈퇴 및 그룹 팝업의 기존 정상 흐름을 확인한다.

### 8. 완료 조건

- 새 파티장 membership에 선택 역할의 보석 v2 최소 요약이 저장되고 본인·타인 카드에 동일하게 표시된다.
- 참가 Character 변경 목록이 로컬 통합 상태로 보석·아크그리드 확정 오류만 표시한다.
- 과거 누락 데이터, 정상 및 판정 불능 Character가 회귀 없이 방어적으로 동작한다.
- 기존 파티/그룹 권한, 명령 순서, 점유·구성 정책과 Rules가 변경되지 않는다.
- 자동 검증과 실기기 결과, Rules 변경·배포 없음이 문서에 기록된다.

## 차후 대기

- 기존 파티 membership 보석 Snapshot 이행 여부
- 신청 Character 선택 Sheet 등 다른 로컬 후보 목록의 통합 Build 표시 확대 여부
- 딜러 직업·깨달음 분기별 특수 보석 대상의 점진적 카탈로그 추가
- 룬·각인·카드·엘릭서 등 통합 무결성 상태 확장
- Build 별칭·직업 메모·JSON 공유: `BUILD_MEMO_SHARING.md`
- 서버 데이터 무결성·고아 binding/claim·복구 절차
- 직업 시너지 선택·필터: `CLASS_SYNERGY_CATALOG.md`
- `characters` Rules의 넓은 `signedIn()` 읽기·쓰기 권한 재설계
