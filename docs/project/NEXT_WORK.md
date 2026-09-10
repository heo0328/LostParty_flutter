# NEXT WORK

> 다음에 바로 진행할 단일 작업 그룹의 근거·범위·순서·완료 조건만 관리한다. 완료 경과는 `DEV_LOG.md`로 이동한다.

## 현재 인계 상태

- 동일 레이드 다른 난이도 후보 회귀에서 실제 Player·서버 Character ID의 canonical assignment를 개별 `get`으로 확인하도록 연결했다.
- 현재 주차·반복방 점유는 차단하고, 과거 1회성 `incompleteEnded` assignment는 기존 replacement 정책에 따라 후보에서 허용한다.
- 표적 정책 테스트 10건과 변경 파일 analyze가 통과했고, 과거 미완료 종료 데이터가 남은 Character의 4막 모집 생성을 실기기에서 확인했다.
- Firestore Rules·스키마는 변경하지 않았다. 완료 상세는 `DEV_LOG.md`와 `BUG_REPORTS.md` BUG-012로 이동했다.

## 다음 작업 그룹 — 신청 후보의 동일 딜러 직업 구성 차단

### 목표

모집 상세의 신청 Character 후보가 현재 membership과 파티별 동일 딜러 직업 상한을 반영하게 한다. 4인 1파티에서는 방장과 같은 딜러 직업을 후보에서 제외하고, 8인 레이드에서는 다른 파티 배치 가능 여부를 기존 `PartyCompositionPolicy`로 판정한다.

### 선행 확인

- `PARTY_PARTICIPATION_RULES.md`와 `PartyCompositionPolicy`의 파티별 `maxDealersPerClassPerParty` 계약을 대조한다.
- 모집 상세가 현재 사용하는 생성용 후보 Query와 상세 membership Snapshot 연결 지점을 확인한다.

### 포함 범위

- 현재 파티원·역할·파티 위치를 반영한 신청 후보 구성 판정
- 4인 파티 동일 딜러 직업 후보 제외
- 8인 파티에서 다른 파티 배치가 가능하면 허용
- 표적 테스트와 문서 정리

### 제외 범위

- Firestore 스키마·Rules·Indexes 변경
- 그룹 membership Build Snapshot
- Build 별칭·시너지 UI
- 레이드 목록 로컬 필터·정렬

### 작업 순서

1. 상세 읽기 모델에서 현재 membership 구성 확보
2. 신청 후보 Query 또는 신청 전용 서비스에 구성 정보 전달
3. 기존 `PartyCompositionPolicy`로 후보별 배치 가능성 판정
4. 4인·8인 회귀 테스트 및 화면 연결 확인

### 중단 조건

- 현재 상세 읽기 모델만으로 membership의 직업·역할·파티 위치를 확보할 수 없는 경우
- 신청 후보 사전 판정과 최종 가입 배치 계약이 서로 다른 결과를 내는 경우

위 조건이 확인되면 구현 범위를 넓히지 않고 변경량과 대안을 사용자에게 다시 제시한다.

### 완료 조건

- 4인 파티에서 방장과 동일한 딜러 직업이 신청 후보에 나타나지 않는다.
- 8인 파티에서는 파티별 제한 안에서 다른 파티 배치 가능 후보를 과도하게 차단하지 않는다.
- 즉시 가입·승인 최종 배치와 후보 판정이 같은 정책을 사용한다.
- 자동 검증과 문서가 갱신된다.

## 차후 대기

- 수동 인증·membership Build Snapshot 실기기 확인: 다음 통합 디바이스 테스트에 포함
- 레이드 목록 내 Character 필터·인원/자리 로컬 정렬: `ACTIVITY_CHARACTER_AND_RAID_FILTER_CONTRACT.md` §14
- 그룹 membership Build Snapshot: 파티 membership 안정화 후 별도 산정
- Build 별칭·직업 메모·공유: `BUILD_MEMO_SHARING.md`
- 서버 데이터 무결성·복구 절차: 반복 사례가 확인될 때 별도 착수
