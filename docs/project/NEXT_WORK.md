# NEXT WORK

## 현재 기준

- 기준 브랜치: `dev` `b44eaed`
- A 저장·Domain·Rules부터 D3 그룹원·Character 필터까지 구현 완료
- 자동 검증: `flutter analyze --no-pub`, 전체 `flutter test --no-pub` 792개 통과
- Android 실기기에서 활동 Character 선택·저장, 선택 Character만 레이드 모집 생성 후보로 노출, 기존 순서 변경·대표 Character 변경, 완료 처리 표시 체크와 전체 흐름이 정상임을 확인했다.
- 첫 릴리즈 전에는 최신 `dev`에서 작업 브랜치를 만들고, PR 없이 검증된 브랜치를 `dev`에 직접 병합해 `origin/dev`에 푸시한다.

전체 기준 계약은 [`../architecture/ACTIVITY_CHARACTER_AND_RAID_FILTER_CONTRACT.md`](../architecture/ACTIVITY_CHARACTER_AND_RAID_FILTER_CONTRACT.md)를 따른다.

## 다음 목표

다른 그룹원의 활동 Character가 그룹 기능에 정확히 보이도록 최소 표시 Projection을 완성하고, 레이드 현황 필터의 초기화·조건부 그룹원 선택·닫기 제스처를 개선한다.

현재 본인의 Character 목록은 활동 선택으로 좁혀지지만, 다른 그룹원은 `characterActivity` owner-only 읽기 제약 때문에 인증 활성 Character 전체가 표시된다. 이는 업로드 실패로 단정하지 않고, 그룹원에게 공개할 활동 Character 최소 Projection과 읽기 경로가 아직 연결되지 않은 문제로 취급한다.

## 작업 순서

```text
A. 다른 그룹원 활동 Character Projection 계약·저장·읽기
→ B. 그룹 상세와 레이드 필터 후보 적용
→ C. 레이드 필터 UX 개선
→ D. 자동 검증과 실기기 확인
```

## A. 활동 Character 최소 Projection

포함:

- 다른 그룹원에게 공개 가능한 활동 Character의 최소 필드와 저장 위치 확정
- 활동 Character 저장 시 Projection을 같은 완료 단위로 동기화
- 현재 Player의 소유권 내부 정보와 인증 전용 데이터는 공개하지 않음
- 활동 해제·대표 변경·순서 변경 후 Projection의 추가·갱신·삭제 일관성 보장
- 기존 테스트 데이터는 캐릭터 관리에서 다시 저장하거나 명시적인 보강 경로를 거쳐 Projection 생성
- Firestore Rules와 Repository 테스트 추가

완료 조건:

- 그룹원이 다른 그룹원의 활동 Character 최소 목록만 읽을 수 있다.
- 비활동 Character는 새 Projection 후보에서 제거된다.
- 대표, 순서와 표시용 최소 정보가 활동 Character 저장 결과와 일치한다.

## B. 그룹 상세와 필터 후보 적용

포함:

- 그룹 정보 페이지의 본인·다른 그룹원 Character 목록을 활동 Character로 통일
- 레이드 현황 필터의 그룹원별 Character 후보도 같은 Projection 사용
- 기존 레이드 membership에 이미 참가한 비활동 Character는 기존 참가 기록과 필터 판정에서 유지
- Projection 누락을 인증 Character 전체 공개로 조용히 대체하지 않고, 빈 상태 또는 재저장 안내로 구분

완료 조건:

- 본인과 다른 그룹원 모두 선택한 활동 Character만 그룹 상세에 표시된다.
- 레이드 필터에서도 다른 그룹원의 활동 Character만 후보로 표시된다.
- 기존 참가·Claim·완료 Snapshot은 변경되지 않는다.

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

- 활동 Character Projection Repository·Rules 계약 테스트
- 그룹원 Character 읽기와 후보 제한 테스트
- 필터 초기화·조건부 표시·선택 정규화·드래그 닫기 위젯 테스트
- 변경 범위 표적 테스트
- `flutter analyze --no-pub`
- 저장 스키마와 여러 feature가 함께 변경되므로 최종 `flutter test --no-pub` 1회

실기기 확인:

- 사용자 A가 활동 Character를 저장한 뒤 사용자 B의 그룹 정보 페이지에 선택 Character만 표시
- 활동 Character 변경 후 다른 그룹원 화면에 추가·삭제·순서가 반영
- 레이드 현황 필터 초기화와 재진입 유지
- 그룹 공개만 선택했을 때만 그룹원 선택 표시
- 긴 필터 목록의 상단 드래그 닫기

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
