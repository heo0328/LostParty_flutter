# NEXT WORK

## 현재 단계

A 저장·Domain·Rules를 완료했다. 활동 Character는 `players/{playerId}/characterActivity/{characterId}` 문서로 저장한다. Character 인증·소유권 문서는 이 명령으로 쓰지 않는다.

현재 실행 단위는 **B 캐릭터 관리 UI** 다. A가 `main`에 통합된 뒤 시작한다. B 완료 전에 C 이후 코드를 수정하지 않는다.

전체 계약은 [`../architecture/ACTIVITY_CHARACTER_AND_RAID_FILTER_CONTRACT.md`](../architecture/ACTIVITY_CHARACTER_AND_RAID_FILTER_CONTRACT.md)를 따른다.

## 작업 순서

```text
A 저장·Domain·Rules (완료)
→ B 캐릭터 관리 UI (현재)
→ C1 레이드 후보 적용
→ C2 그룹 후보·전투력 적용
→ D1 그룹 전용 자격 박탈
→ D2 진행 중 기본 필터·페이징
→ D3 그룹원·Character 필터
→ E 실기기·회귀 확인
```

## 현재 작업 단위 B — 캐릭터 관리 UI

A의 `ActivityCharactersRepository`만 사용한다. 레이드·그룹 후보 소비 경로는 바꾸지 않는다.

포함:

- 인증 원정대 전체의 Character명 중심 선택 카드와 `선택 수 / 전체 수`
- 선택·해제·대표·순서·표시 개수를 로컬 초안에 즉시 반영하고 `저장`에서 한 번만 서버에 쓴다
- 대표 Character 선택 비활성화, 마지막 1명 해제 차단, 0명 저장 요청 거부
- 선택된 Character만 대표 지정·드래그 순서 목록에 표시
- 기존 표시 여부 체크박스 제거
- 메인 화면 표시 개수를 1~활동 Character 수로 제한하고, 활동 수가 줄어들면 표시 개수를 자동 축소
- 저장 중 중복 요청 차단, 실패 시 서버 미반영 안내
- `SaveActivityCharactersCommand.ownedCharacterIds`에 본·부계정의 서버 Character ID를 모두 넣는다
- ViewModel·관련 Widget 테스트

제외:

- 레이드 생성·신청·참가 Character 변경 후보 교체
- 그룹 Snapshot·그룹원 목록·전투력 보강 범위 변경
- 레이드 현황 필터
- Rules 배포와 테스트 데이터 실제 삭제

완료 조건:

- 캐릭터 관리 화면이 전체 선택 → 대표·순서 → 표시 개수 → 취소·저장 흐름을 따른다.
- 대표 해제와 마지막 1명 해제가 UI에서 막히고, 0명 저장은 요청 자체가 나가지 않는다.
- 저장 성공 후에만 서버·재진입 상태가 바뀐다.

## 확정된 제품 기준

### 활동 Character

- 인증 원정대 전체는 검색·인증·소유권을 위해 유지한다.
- 활동 Character만 새 레이드·그룹 후보와 일반 전투력 동기화에 사용한다.
- 최소 1명이며 대표 Character는 항상 활동 상태다.
- 대표 Character의 활동 선택은 비활성화하고 마지막 1명 해제를 로컬에서 막는다.
- 0명 상태는 저장 요청 전, Repository와 Rules에서 다시 거절한다.
- 기존 참가 Character를 비활성화해도 membership·Claim·완료 기록은 유지한다.
- 과거 사용자 데이터 자동 마이그레이션은 하지 않는다.
- 테스트 데이터는 캐릭터 관리에서 다시 저장하면 활동 문서가 만들어진다. 기존 Character·소유권 문서는 삭제하지 않는다.

### 캐릭터 관리 화면

- 상단: 전체 인증 원정대의 Character명 중심 선택 카드와 선택 수
- 중단: 선택된 Character만 대표 지정·드래그 순서 관리
- 하단: 메인 화면 표시 개수와 변경 취소·저장
- 선택은 로컬 초안에 즉시 반영하고 서버에는 저장 시 한 번 반영한다.

### 레이드 현황 진행 중 필터

- `진행 중 / 신청 중 / 완료 기록` 전환과 목록 사이에 `레이드 필터: 모든 레이드`를 둔다.
- 공개 조건 기본값은 전체·일반 공개·그룹 공개가 모두 체크된 상태다.
- 일반·그룹 공개가 모두 해제되려 하면 전체로 복귀한다.
- 레이드와 난이도는 차원 내부 OR, 차원 사이는 AND다.
- 그룹원 필터에서 현재 Player는 제외한다.
- 한 사용자의 복수 Character는 OR, 서로 다른 사용자는 AND다.
- 필터는 서버 20개 페이징 결과에 로컬로 적용하고 다음 페이지가 있으면 개수를 `현재 N개`로 표시한다.

### 그룹 전용 자격 상실 정리

- 그룹장뿐 아니라 해당 레이드에 정상 참가 중인 유효 그룹원도 정리를 요청할 수 있다.
- 서버는 요청자 자격과 대상의 실제 그룹 자격 상실을 같은 원자 작업에서 재검증한다.
- 전체 공개 상태인 그룹 연결 레이드는 그룹 탈퇴만으로 기존 참가 자격을 박탈하지 않는다.

## 보존 지점

- A 저장 구현 브랜치: `cursor/activity-character-storage-801c`.
- 문서 설계 시작 기준: `main` `9a58457`, 브랜치 `codex/activity-character-contract`.
- 기존 보존 브랜치 `codex/rules-complexity-reduction` / `ed02b31` 및 Rules 사본 2개는 유지한다.
- 그룹 전투력 수정 `4e4ab37` / 통합 `eeba05f`, 모집 UI 준비 문서 `15eaf4a`, 그룹 레이드 연결 `61fd464` / 통합 `25c3b44`를 유지한다.
- 실제 구현 전에 git status·브랜치·HEAD를 확인하고 다른 미커밋 변경을 보존한다.
