# Task-11 Firestore Rules 복잡도 차단 — 열린 기술 부채

## 상태

| 항목 | 내용 |
| --- | --- |
| 발견일 | 2026-08-31 |
| 차단 범위 | **전체 `firestore.rules` 정상 배포** |
| 현재 단계 | 원인 확인 완료, 축소·분할 리팩터링 **미착수** |
| Task-11·11a 코드 | **`main`에 1차 병합 완료** (Rules 운영 반영과는 별개) |
| 운영 영향 | 2026-08-31 저녁 **절반 축소 프로브 Rules**가 `lost-party`에 일시 배포됨. 전체 원본 재배포는 **503으로 실패** 확인. 앱 대부분 쓰기가 거부될 수 있음 |
| 다음 | **전체 기획·설계 재검토**에 반드시 포함. 구현은 재설계 지시 후 |

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
