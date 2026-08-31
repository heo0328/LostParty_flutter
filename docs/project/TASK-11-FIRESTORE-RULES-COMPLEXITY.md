# Task-11 Firestore Rules 복잡도 차단 — 열린 기술 부채

> 2026-08-31 사용자 판단: 최신 상태에서 Rules 복잡도 문제는 해결된 것으로 본다. 이 문서의 503 차단 및 R0~R6은 과거 조사·보존 기록이며 현재 실행 지시가 아니다. 현재 작업은 모집 생성 UI이며, 최적화·프로브 배포를 자동 재개하지 않는다. 원격 보존 브랜치: codex/rules-complexity-reduction @ ed02b31.

## 상태

| 항목 | 내용 |
| --- | --- |
| 발견일 | 2026-08-31 |
| 차단 범위 | **전체 `firestore.rules` 정상 배포** |
| 현재 단계 | 최근 기능 추가에 따른 복잡도 문제로 1차 정의. 1차 축소 완료, 추가 개선 계획 기록 |
| Task-11·11a 코드 | **`main`에 1차 병합 완료** (Rules 운영 반영과는 별개) |
| 운영 영향 | 2026-08-31 저녁 **절반 축소 프로브 Rules**가 `lost-party`에 일시 배포됨. 전체 원본 재배포는 **503으로 실패** 확인. 앱 대부분 쓰기가 거부될 수 있음 |
| 다음 | 아래 시작점·단계별 계획에 따라 검증 환경 확인부터 진행 |

## 현재 작업 시작점과 최신 배포 결과

- 기준 코드 커밋: **`25f88ff6f8a7be1bdf9ab7f16bbae167ee3bb9ff`** (`refactor(rules): simplify group lookup and snapshot validation`).
- 작업 브랜치: **`codex/rules-complexity-reduction`**. main에 직접 수정하지 않는다.
- 직전 통합 기준: `ea2019a`. 25f88ff에는 native 탈퇴 그룹 탐색과 Snapshot 중복 비교 제거가 포함돼 있다.
- 기준 Rules 소스 크기: **143,799 bytes**. 원본 백업 158,836 bytes와 구분한다. 소스 크기는 컴파일 복잡도의 대리 지표일 뿐 성공 기준이 아니다.
- 사용자 지시에 따라 25f88ff의 전체 Rules를 `lost-party`에 배포 시도했으나 `projects/lost-party:test` 컴파일 검사에서 **503 UNAVAILABLE**로 실패했다. 새 release는 적용되지 않았다.
- 운영의 마지막 성공 Rules 내용은 별도로 조회 확인하지 않았다. 로컬 복원과 운영 복원을 같은 상태로 기록하지 않는다.
- 로컬 Emulator는 전체 Rules뿐 아니라 최소 deny-all Rules 로딩도 `503 / Network closed for unknown reason`으로 실패했다. 운영 API 실패와 로컬 검증 환경 실패를 구분한다.
- 기준 검증: 표적 Flutter 테스트 33개, 변경 테스트 파일 analyze, JS 문법 검사 통과. 실제 Rules 허용/거절 동작과 배포 성공은 미확인이다.
- `firestore - 복사본.rules`, `firestore.before-complexity-20260831.rules.bak`는 로컬 백업으로 보존하며 커밋·배포 대상에 넣지 않는다.

## 단계별 추가 개선 계획

이번 커밋은 **작업 시작점과 실행 계획만 기록하는 문서 커밋**이다. 아래 구현을 완료했다고 간주하지 않는다. 각 단계는 변경 전에 범위를 확인하고 별도 커밋으로 남긴다.

| 단계 | 변경 대상과 방법 | 앱·데이터 영향 | 검증 및 완료 조건 |
|---|---|---|---|
| R0 검증 환경 | 최소 Rules 로딩 오류를 먼저 분리 조사. 운영을 바꾸지 않는 컴파일 검사와 Emulator 허용/거절 테스트 경로 확보 | 없음 | 최소 대조 검사 성공과 전체 Rules 검사 결과를 각각 기록. 실패 시 수정 효과를 추정해 통과 처리하지 않음 |
| R1 그룹 가입 | `validInitialGroupMember`, `validInvitedGroupMember`, `validApprovedGroupMember`, `validJoinCodeGroupMember`의 필드·타입·초기 시각 검사를 공통 부분으로 정리. 생성자/가입자/승인자, 초대/신청/코드 증명과 차단 조건은 각 경로에 유지 | Rules 중심, 스키마 유지 | 생성·초대 수락·신청 승인·코드 가입 정상 경로 및 다른 경로로 위장·금지·타인·정원 초과 거절 |
| R2 Player 요약·목록 | 본인 가입과 그룹장 승인에서 반복되는 Group ID 1개 추가·중복·50개 제한·revision 검사를 공통화. 목록 Projection의 공통 스키마와 membership 일치 검사 정리 | Rules 중심, 스키마 유지 | 49→50 성공·50→51 실패, 동시 승인, 누락/위조 Projection, 기존 문서 없는 최초 생성 검증 |
| R3 파티·그룹 수정 | `affectedKeys().hasOnly()`와 개별 불변 비교의 중복을 함수별로 검토해 제거. 필수 필드 존재·허용 필드의 값 조건은 유지 | Rules 중심, 스키마 유지 | 허용 수정 성공, 필드 추가/삭제·역할·소유자 변조 거절. 각 함수의 적용 전후 허용 범위 비교 |
| R4 이벤트 | `validPlayerEvent` 및 신청·멤버·회차 이벤트의 공통 필드/시각/revision 검사를 정리. 단순 전달 함수·중복 분류를 축소 | Rules 중심, 이벤트 형식 유지 | 기존 이벤트별 수신자·발신자·연결 상태 검증. 타인 이벤트 삽입·재전송·위조 revision 거절 |
| R5 명령 대상 명시 | 앞 단계로 부족하면 그룹 승인·탈퇴·코드 관리에 명령 종류와 대상 ID를 명시하는 계약 초안 작성. 실제 변경과 원자적 연결 검증을 함께 설계 | Repository·Rules·명령 필드 변경 가능 | **설계 검토 후 별도 착수**. 명령 문자열만으로 권한 허용 금지. 인원만 변경·membership만 변경·요약 누락 등 부분 쓰기 차단 |
| R6 표시/권한 데이터 분리 | R5 이후에도 필요할 때만 membership 권한과 표시 Snapshot, 목록용 Projection 책임 재정의 | 문서 경로·조회·이행 작업 가능 | **설계 검토 후 별도 착수**. 기존 UX·오프라인 표시·조회 비용·기존 데이터 이행 계획 확보 |

### 공통 구현 원칙

- 현재 바로 시작할 단위는 **R0**, 다음은 R1이다. 한 번에 R1~R6을 모두 구현하지 않는다.
- 공통 함수 추출, OR 분기 순서 조정, 코드 줄 수 감소가 컴파일 크기 감소를 보장하지 않는다. 결과를 비교해 효과가 없으면 근거와 함께 해당 변경을 재검토한다.
- 상태·명령 종류·필드 집합으로 경로를 먼저 구분하고 필요한 문서만 읽는 방향을 검토한다. 기존 문서 누락 시 거절 의미와 OR의 다른 정상 경로를 훼손하지 않는다.
- 권한 검사를 클라이언트로 옮기거나 `signedIn()`만 남겨 축소하지 않는다. 파일 분할·주석 제거는 가독성 작업이지 핵심 해법이 아니다.
- UI/UX, Player 단위 그룹 소속, 본·부계정 사용, 50명/50개 제한, 초대·신청·코드 가입, 신청 금지·횟수, 반복 레이드·주간 Claim·운영자 인증 정책을 보존한다.
- 인증/캐릭터의 광범위한 쓰기 권한과 그룹 탈퇴의 변경 전 membership·요약 결합 누락은 별도 보안 보완으로 추적한다. 단순화 과정에서 이 문제를 더 넓히거나 해결됐다고 기록하지 않는다.
- 함수 중복 제거로 접근 한도를 맞추기 위해 원자성 검증을 삭제하지 않는다. 반대로 단순화와 무관한 보안 정책 변경도 같은 커밋에 섞지 않는다.
- 기능을 `false`로 막은 실험 Rules는 로컬 또는 격리된 검사에만 사용한다. 운영 프로브 배포는 금지한다.
- 향후 운영 배포는 해당 시점의 사용자 명시 지시 후 실행한다. 이전 배포 지시를 후속 자동 배포 권한으로 재사용하지 않는다.

### 단계별 작업 기록 양식

각 단계 종료 시 아래 항목을 이 문서 후속 절과 DEV_LOG에 남기고, NEXT_WORK는 다음 단일 작업을 가리키도록 갱신한다.

```text
단계 / 브랜치 / 시작 커밋:
변경 파일·함수:
기존 검증 → 변경 검증 및 동등성 근거:
앱·데이터·UX 영향:
소스 크기 전후 / 컴파일 결과(미측정은 미측정):
정상·거절·경쟁 조건 테스트와 미실행 항목:
배포 여부 / 실패 단계 / 운영 반영 여부:
남은 문제 / 다음 단계 / 결과 커밋:
```

문서 커밋의 자기 해시는 작성 시점에 확정되지 않으므로 Git 이력으로 식별한다. 첫 구현 단계 시작 시 이 문서 커밋의 실제 HEAD를 기록하고, 기준 코드 25f88ff와 구분한다.

### 검증 게이트와 복구

- 해당 단계의 정상·거절 경로를 Rules Emulator에서 확인하고, 표적 Flutter 테스트·관련 정적 분석·`git diff --check`를 수행한다. 문자열 계약 테스트만으로 Rules 동작 검증을 대체하지 않는다.
- 테스트 환경이 막히면 문서나 검토용 중간 커밋은 가능하지만 **검증 미완료**로 표기하고 다음 대규모 변경·배포 성공 선언을 하지 않는다.
- 기능 보존 완료는 전체 Rules 컴파일, 허가된 배포의 성공, 핵심 다중 사용자 경로 확인까지 필요하다. 503이 사라졌다는 이유만으로 보안 검증을 통과 처리하지 않는다.
- 변경 복구는 단계 커밋 단위로 검토한다. 사용자 작업·백업을 덮어쓰거나 main을 강제 초기화하지 않는다. 운영 복구가 필요하면 마지막 성공 release를 확인하고 별도 승인 후 실행한다.

## 요약

Task-11a(멤버 목록·탈퇴·표시 Snapshot) 코드는 `main`에 보존됐다. 다만 **Rules를 정상 배포할 수 있을 때까지** 해당 Rules·실기기 검증은 열린 부채다.

원인은 Rules 문법 오류가 아니라 **단일 `firestore.rules` 파일의 컴파일/업로드 복잡도 한도**에 가깝다.

- 전체 Rules (~159KB, ~3470줄): `firebase deploy --only firestore:rules` 시 **503** (사용자 재확인)
- 약 **47.9%**로 함수 본문을 `return false` 스텁으로 줄인 프로브 (~76KB): **compile + release 성공** (~13초)

즉, Task-11 leave·Snapshot refresh 등 **최근 Rules 추가분이 문법만 맞다고 배포가 보장되지 않는다.**

## 2026-08-31 검증 절차 (재현)

1. 원본 `firestore.rules` 백업 (`firestore - 복사본.rules` 등 사용자 로컬 사본 권장)
2. 경로 helper·`match` 블록은 유지, 검증 함수 본문 약 **101개**를 `return false` 스텁으로 축소
3. `firebase deploy --only firestore:rules --project lost-party`
4. **Deploy complete** 확인

프로브는 **운영에 그대로 두면 안 됨**. 정상 Rules 복구 배포 전까지 그룹·파티·Claim 등 쓰기가 대부분 막힌다.

## 정상 복구 시도 (사용자)

로컬 **전체 원본** `firestore.rules`로 되돌린 뒤:

```powershell
firebase deploy --only firestore:rules --project lost-party
```

→ **503 재현**. 업로드 대상은 복원된 전체 파일이 맞으나, 복잡도 한도로 release 실패. 운영은 직전 성공분(프로브)이 유지된다.

## 추정 원인

- 단일 파일에 파티·Claim·운영자·수동 인증·**그룹 membership 전체** Rules가 누적
- 그룹 leave 경로의 `removedActiveGroupId` chunk helper 등 **중첩·분기·OR 평가**가 컴파일 비용을 키움
- Firebase Rules API는 파일 크기·식 복잡도 한도를 공개하지 않으나, **절반 축소 시 성공**으로 복잡도 병목이 거의 확실함

## 수정 방향 (재설계 후 구현)

1. **Rules 분할·중복 제거**
   - 그룹 전용 helper를 최소화하고 OR 체인 순서·중복 `get()` 제거
   - `removedActiveGroupIdChunk*` 등 chunk helper 단순화 또는 데이터 모델 쪽으로 이동 검토
2. **배포 가능 크기 목표**
   - 프로브 성공선(~76KB)보다 여유 있게, **전체 기능을 유지한 채** compile + deploy 성공을 반복 확인
3. **증분 배포 전략**
   - 한 번에 큰 diff를 올리지 않고, 기능 단위로 Rules 변경·배포·실기기 확인
4. **계약 테스트 유지**
   - `test/features/group/data/group_rules_contract_test.dart` 등 문자열 고정 테스트를 리팩터 후에도 갱신

## Task-11a와의 관계

| 항목 | 코드 (`main`) | Rules 배포 |
| --- | --- | --- |
| 일반 멤버 탈퇴 | 구현됨 | leave Rules 포함, **전체 deploy 실패로 미반영** |
| 멤버 표시 Snapshot | 구현됨 | create/join + **self refresh update** 포함, 미반영 |
| 그룹원 목록·상세 UI | 구현됨 | 읽기 Rules는 기존 Task-11과 동일 전제 |

재설계 후: **Rules 축소·배포 성공 → Task-11a 실기기 재검증** 순서를 권장한다.

## 2026-08-31 후속 — Rules만 1차 축소, 배포 미실행

- 사용자 지시로 원본을 `firestore.before-complexity-20260831.rules.bak`에 별도 복사하고 SHA-256 일치를 확인했다. 기존 사용자 사본은 수정하지 않았다.
- `removedActiveGroupId`의 5개 chunk 및 50개 위치 탐색을 Firebase Rules 기본 `List.removeAll()`로 대체했다. 제거 결과가 정확히 하나일 때만 `[0]`에 접근한다.
- 앱 요청·Firestore 저장 스키마·나머지 권한 검사는 변경하지 않았다. 오래된 생성 스크립트와 템플릿도 같은 native helper로 맞춰 재생성 시 복잡도가 돌아오지 않게 했다.
- 실제 파일 크기: 158,836 → 144,042 bytes (약 9.3% 감소). 컴파일 결과 크기 감소를 측정한 값은 아니다.
- 표적 Flutter 테스트 32개 통과. Emulator 테스트에 50개 그룹의 chunk 경계 10개 위치 탈퇴와 두 ID 제거·변경 없음·ID 삽입 거절을 추가했다.
- 전체 Rules의 Emulator 로딩은 `503 / Network closed for unknown reason`으로 실패했다. 최소 deny-all Rules 대조 검사도 동일하게 실패해 로컬 검증 환경 문제를 별도로 남긴다. 동작 테스트는 시작되지 않았으며, 이 실패를 수정 Rules 복잡도의 증거로 사용하지 않는다.
- 서버 배포·운영 데이터 변경·커밋은 하지 않았다. 배포 성공과 실기기 정상 작동은 미확인이다.
- 공식 연산: https://firebase.google.com/docs/reference/rules/rules.List#removeAll

## 2026-08-31 복잡도 개선 브랜치 커밋 범위

- 브랜치: `codex/rules-complexity-reduction` (main과 분리).
- 위 native 탈퇴 탐색 축소와 표시 Snapshot 갱신 중복 제거만 포함한다. 앱 코드·요청·저장 스키마 변경 없음.
- 표시 갱신의 11개 개별 불변 비교를 기존 `affectedKeys().hasOnly()`로 통합했다. `oldData.keys().hasAll()`로 필수 필드 누락도 계속 거절한다. 호출자·Player/Group ID·직업·숫자 타입·서버 시각 검증은 유지한다.
- 최종 Rules 소스: 143,799 bytes. 백업 158,836 bytes 대비 약 9.5% 감소이며 컴파일 결과 크기는 미측정이다.
- 최종 표적 Flutter 테스트 33개 통과. 정적 문자열 계약·쓰기 계획 검증이며 실제 Rules 허용/거절 검증을 대체하지 않는다.
- 보호 필드 변경·삭제, 새로운 권한 필드 삽입, 타인의 Snapshot 갱신 거절 시나리오를 Emulator 스크립트에 추가했다. Emulator 로딩 환경 문제로 실행 통과를 주장하지 않는다.
- 그룹 탈퇴 전 membership 존재 검증, 요약 변경의 원자적 결합 검증, 계정·캐릭터 쓰기 권한 축소는 별도 보안 보완 작업이다. 이번 최적화로 해결됐다고 간주하지 않는다.
- 백업 2개는 로컬 보존하고 커밋 대상에서 제외한다. 배포·main 병합·푸시는 이번 지시에 포함하지 않는다.

### 관련 문서

- 실행 지시: [`NEXT_WORK.md`](NEXT_WORK.md)
- 작업 이력: [`DEV_LOG.md`](DEV_LOG.md) — Task-11a·Rules 프로브 항목
- 그룹 계약: [`../architecture/FIRESTORE_GROUP_MEMBERSHIP_CONTRACT.md`](../architecture/FIRESTORE_GROUP_MEMBERSHIP_CONTRACT.md)
