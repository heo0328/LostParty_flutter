# Task-11 Firestore Rules 복잡도 차단 — 최우선 수정

## 상태

| 항목 | 내용 |
| --- | --- |
| 발견일 | 2026-08-31 |
| 차단 범위 | **전체 `firestore.rules` 정상 배포** |
| 현재 단계 | 원인 확인 완료, 축소·분할 리팩터링 **미착수** |
| 운영 영향 | 2026-08-31 저녁 **절반 축소 프로브 Rules**가 `lost-party`에 일시 배포됨. 앱 대부분 쓰기가 거부될 수 있음 |

## 요약

Task-11a(멤버 목록·탈퇴·표시 Snapshot)와 그룹 기능 실기기 재검증은 **Rules를 정상 배포할 수 있을 때까지 진행을 멈춘다.**

원인은 Rules 문법 오류가 아니라 **단일 `firestore.rules` 파일의 컴파일/업로드 복잡도 한도**에 가깝다.

- 전체 Rules (~159KB, ~3470줄): `firebase deploy --only firestore:rules` 시 **503/409** 등 API 실패가 반복됨
- 약 **47.9%**로 함수 본문을 `return false` 스텁으로 줄인 프로브 (~76KB): **compile + release 성공** (~13초)

즉, Task-11 leave·Snapshot refresh 등 **최근 Rules 추가분이 문법만 맞다고 배포가 보장되지 않는다.**

## 2026-08-31 검증 절차 (재현)

1. 원본 `firestore.rules` 백업 (`firestore - 복사본.rules` 등 사용자 로컬 사본 권장)
2. 경로 helper·`match` 블록은 유지, 검증 함수 본문 약 **101개**를 `return false` 스텁으로 축소
3. `firebase deploy --only firestore:rules --project lost-party`
4. **Deploy complete** 확인

프로브는 **운영에 그대로 두면 안 됨**. 정상 Rules 복구 배포 전까지 그룹·파티·Claim 등 쓰기가 대부분 막힌다.

## 정상 복구 (사용자)

로컬에 백업해 둔 **전체 원본** `firestore.rules`로 되돌린 뒤:

```powershell
firebase deploy --only firestore:rules --project lost-party
```

503이 다시 나오면 Rules 축소 작업이 선행되어야 한다.

## 추정 원인

- 단일 파일에 파티·Claim·운영자·수동 인증·**그룹 membership 전체** Rules가 누적
- 그룹 leave 경로의 `removedActiveGroupId` chunk helper 등 **중첩·분기·OR 평가**가 컴파일 비용을 키움
- Firebase Rules API는 파일 크기·식 복잡도 한도를 공개하지 않으나, **절반 축소 시 성공**으로 복잡도 병목이 거의 확실함

## 수정 방향 (다음 구현 작업)

아래는 **Task-11a 마무리·`main` 병합보다 앞**에 수행한다.

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

다음 클라이언트·Rules 변경은 **코드에만 존재**하고 운영 배포는 막혀 있을 수 있다.

| 항목 | 코드 | Rules 배포 |
| --- | --- | --- |
| 일반 멤버 탈퇴 | 구현됨 | leave Rules 포함, **전체 deploy 실패 시 미반영** |
| 멤버 표시 Snapshot (`combatPowerSnapshot` 등) | 구현됨 | create/join + **self refresh update** 포함 |
| 그룹원 목록·상세 UI | 구현됨 | 읽기 Rules는 기존 Task-11과 동일 전제 |

**Rules 축소·배포 성공 → 사용자 전체 Rules 재배포 → Task-11a 실기기 재검증** 순서를 지킨다.

## 참고

- 실행 지시: [`NEXT_WORK.md`](NEXT_WORK.md)
- 작업 이력: [`DEV_LOG.md`](DEV_LOG.md) — Task-11a·Rules 프로브 항목
- 그룹 계약: [`../architecture/FIRESTORE_GROUP_MEMBERSHIP_CONTRACT.md`](../architecture/FIRESTORE_GROUP_MEMBERSHIP_CONTRACT.md)
