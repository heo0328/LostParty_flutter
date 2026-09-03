# NEXT WORK

## 현재 기준

- 활동 Character 저장·그룹원 목록·레이드 현황 필터 UX(C)까지 구현하고 Android 실기기에서 확인했다.
- 그룹원 활동 Character는 Projection 컬렉션 없이 `characterActivity` 목록과 Character 표시 문서를 쓴다.
- 첫 릴리즈 전에는 최신 `dev`에서 작업 브랜치를 만들고, PR 없이 검증된 브랜치를 `dev`에 직접 병합해 `origin/dev`에 푸시한다.

전체 기준 계약은 [`../architecture/ACTIVITY_CHARACTER_AND_RAID_FILTER_CONTRACT.md`](../architecture/ACTIVITY_CHARACTER_AND_RAID_FILTER_CONTRACT.md)를 따른다.

## 다음 목표

이 단위(활동 Character 공개 경로 + 필터 UX)는 실기기 확인까지 완료됐다. 다음 작업은 별도 지시가 있으면 그때 잡는다.

## 작업 순서

```text
완료
```

## A·B 완료 메모 (Projection 대신 활동 목록)

별도 Projection 컬렉션은 Rules 복잡도 때문에 채택하지 않는다. 그룹 상세·필터는 `characterActivity` ID와 `characters` 표시 문서를 조합하고, 활동 문서가 없으면 빈 목록을 둔다. 그룹원 목록이 동작하려면 `characterActivity` `get`/`list`가 `hasActiveBinding()`인 Rules가 실제로 배포되어야 한다. CLI 503이면 콘솔 표시와 무관하게 새 Rules는 적용되지 않은 것으로 본다.

## C. 레이드 현황 필터 UX 개선

포함:

- 필터 창 상단에 `초기화` 동작 제공
- 초기화 시 공개 조건은 전체, 레이드·난이도·그룹·그룹원·Character 선택은 해제하고 저장 상태에도 반영
- 그룹 관련 선택 UI는 공개 조건이 `그룹 공개만` 선택된 경우에만 표시
- `전체` 또는 `일반 공개`가 포함된 상태에서는 그룹·그룹원·Character 선택 UI를 숨김
- 숨겨진 그룹 관련 선택값이 실제 필터 조건으로 남지 않도록 선택 상태 정규화
- 긴 필터 목록에서도 상단 드래그 영역을 쉽게 잡아 아래로 끌어 닫을 수 있도록 고정된 헤더/드래그 영역 확보
- 스크롤과 닫기 제스처가 충돌하지 않도록 위젯 테스트 추가

완료 조건:

- 초기화 한 번으로 모든 필터가 기본값으로 돌아가고 재진입 후에도 기본값이 유지된다.
- 그룹 공개만 선택했을 때만 참여 그룹원 선택 영역이 보인다.
- 필터 내용이 화면 상단까지 길어져도 상단의 충분한 영역을 아래로 드래그해 닫을 수 있다.

## D. 검증

자동 검증:

- 활동 Character 저장·목록 Rules 계약 테스트
- 그룹원 Character 읽기와 후보 제한 테스트
- 필터 초기화·조건부 표시·선택 정규화·드래그 닫기 위젯 테스트
- 변경 범위 표적 테스트
- `flutter analyze --no-pub`
- 저장 스키마와 여러 feature가 함께 변경되므로 최종 `flutter test --no-pub` 1회

실기기 확인 (2026-09-03 Android):

- 사용자 A가 활동 Character를 저장한 뒤 사용자 B의 그룹 정보 페이지에 선택 Character만 표시 — 통과
- 내 계정 활동 Character 저장 — 통과
- 레이드 현황 필터 초기화와 재진입 유지 — 통과
- 그룹 공개만 선택했을 때만 그룹원 선택 표시 — 통과
- 긴 필터 목록의 상단 드래그 닫기 — 통과

## 제외 범위

- 모집 목록·신청 중·완료 기록 필터 추가
- 활동 Character 해제에 따른 기존 레이드 자동 탈퇴
- 기존 Claim·assignment·완료 Snapshot 변경
- 인증 원정대·소유권 계약 변경
- 전체 과거 사용자 자동 마이그레이션
- 첫 릴리즈 전 PR 생성

## 시작 전 확인

- 현재 문서 브랜치의 변경을 먼저 커밋·`dev` 직접 병합·푸시해 기준 문서를 확정한다.
- 새 구현은 최신 `dev`와 `origin/dev`가 같은지 확인한 뒤 별도 작업 브랜치에서 시작한다.
- 기존 보존 브랜치와 Rules 사본은 삭제하지 않는다.
