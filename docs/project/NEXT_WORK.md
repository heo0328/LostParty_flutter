# NEXT WORK

> 다음에 바로 진행할 단일 작업 그룹의 근거·범위·순서·완료 조건만 관리한다. 완료 경과는 `DEV_LOG.md`로 이동한다.

## 현재 인계 상태

- `codex/party-membership-build-snapshot`에서 승인·직접 참가·참가 Character 변경의 Build 무결성 Snapshot을 파티 membership과 구성원 카드까지 전파했다.
- 표적·영향 자동 검증 69건과 변경 파일 analyze(기존 info lint만)가 통과했다.
- Character 변경 Rules allowlist에 `gemValidationSnapshot`을 추가했다. 2026-09-10 최신 Rules 실제 배포에서 원격 컴파일·Ruleset 업로드·Release와 `Deploy complete`를 확인했다. 다음 통합 디바이스 테스트에서 수동 인증과 함께 확인한다.
- 완료 상세는 `DEV_LOG.md`와 `CHARACTER_BUILD_INTEGRITY_CONTRACT.md`로 이동했다.

## 다음 작업 그룹 — 레이드 목록 로컬 필터·정렬

### 목표

진행 중 필터 최하단에 내 Character 다중 선택을 두고, 진행 중/레이드 모집 목록을 참가 인원·남은 자리 적은 순/많은 순으로 로컬 정렬한다. 서버 스키마·Rules·Indexes는 변경하지 않는다.

### 선행 확인

- `ACTIVITY_CHARACTER_AND_RAID_FILTER_CONTRACT.md` §14와 현재 레이드 현황·모집 목록 필터 UI를 대조한다.
- 받은 원본 목록 병합 지점과 기존 공개 조건·레이드·난이도 필터 순서를 확인한다.

### 포함 범위

- 진행 중: 내 Character 다중 선택 필터(최하단)
- 진행 중/레이드 모집: 참가 인원·남은 자리 적은 순/많은 순 로컬 안정 정렬
- 원본 병합 후 클라이언트 필터·정렬만 적용
- 표적 테스트와 문서 정리

### 제외 범위

- Firestore 스키마·Rules·Indexes·쿼리 변경
- 그룹 membership Build Snapshot
- Build 별칭·시너지 UI

### 작업 순서

상세 A~E는 `ACTIVITY_CHARACTER_AND_RAID_FILTER_CONTRACT.md` §14.5를 따른다.

### 중단 조건

- 서버 쿼리·Index 없이는 목록 순서를 맞출 수 없다고 판정되는 경우
- 기존 필터·페이징 계약을 깨야만 구현 가능한 경우

위 조건이 확인되면 구현 범위를 넓히지 않고 변경량과 대안을 사용자에게 다시 제시한다.

### 완료 조건

- 내 Character 필터와 인원·자리 정렬이 로컬에서만 동작한다.
- 기존 공개 조건·레이드·난이도 필터와 페이징 계약이 유지된다.
- 자동 검증과 문서가 갱신된다. 실기기 확인은 다음 통합 디바이스 테스트에 묶을 수 있다.

## 차후 대기

- 수동 인증·membership Build Snapshot 실기기 확인: 다음 통합 디바이스 테스트에 포함
- 그룹 membership Build Snapshot: 파티 membership 안정화 후 별도 산정
- Build 별칭·직업 메모·공유: `BUILD_MEMO_SHARING.md`
- 서버 데이터 무결성·복구 절차: 반복 사례가 확인될 때 별도 착수
