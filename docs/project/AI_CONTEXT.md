# AI CONTEXT (2026)

> 프로젝트 전체 지도와 현재 상태의 요약이다. 행동 규칙은 `ai_rules.md`, 바로 실행할 상세 작업은 `NEXT_WORK.md`, 완료 경과는 `DEV_LOG.md`가 기준이다.

## 현재 통합 상태

- 통합 기준은 `dev`이며 기능 작업은 최신 `dev`에서 도구별 접두사 브랜치로 분기한다. Cursor는 `cursor/*`, Codex는 `codex/*`다. 단계 작업은 기능 브랜치에 복구 지점을 푸시하고, 섹션 검증·문서 정리 후 `dev`에 병합한다.
- 앱은 Firebase 익명 Auth와 Player binding, 게임 계정·Character 인증, 그룹, 레이드 모집·신청·참가·회차·완료 Claim, 로컬 알림과 계정 관리 흐름을 제공한다.
- 주차 경계는 한국 수요일 오전 6시 공통 정책을 사용한다. 만료된 1회성 방은 미완료 종료되고 새 주차 점유를 막지 않으며, 반복방은 최초 접근 시 멱등하게 현재 주차로 승계된다.
- 그룹 생성·가입 신청·탈퇴·그룹장 양도·초대코드 확인/가입·마지막 1인 해산과 레이드 주요 명령은 2026-09-10 운영 Rules 및 실기기에서 확인했다.
- 수동 인증 실기기 검증은 기능 결함으로 열린 것이 아니라 다음 통합 디바이스 테스트에서 필요할 때 함께 수행한다.

## 현재 제품 축

### Character와 인증

- 앱 실행 후 내 레이드 현황 초기 로딩과 충돌하지 않게 적격 Character를 앱 수명당 한 번 갱신한다. 공통 사용 레벨 정책은 현재 1700이며 나이스단 판정과 공유한다.
- 서버 관계가 없고 로컬 인증 표시만 남은 경우 서버 불일치로 안내한다. 자동 재귀속이나 자동 로컬 삭제는 하지 않으며 앱 데이터 초기화·재인증을 기본 복구 절차로 유지한다.
- 계약: [`../architecture/GAME_ACCOUNT_CHARACTER_FIREBASE_CONTRACT.md`](../architecture/GAME_ACCOUNT_CHARACTER_FIREBASE_CONTRACT.md), [`../architecture/GAME_ACCOUNT_VERIFICATION_CONTRACT.md`](../architecture/GAME_ACCOUNT_VERIFICATION_CONTRACT.md), [`../architecture/CHARACTER_INTERACTION_AUTO_REFRESH_CONTRACT.md`](../architecture/CHARACTER_INTERACTION_AUTO_REFRESH_CONTRACT.md)

### Character Build 무결성

- 깨달음·아크그리드 질서 해/달 14P·보석 Tooltip 직업을 기본 검사한다. 별과 혼돈은 필수 판정에서 제외한다.
- 같은 직업의 대상 미확인은 중립 안내, 다른 직업 보석만 빨간 경고다. 모든 직업의 최적 Build를 선행 수기 입력하거나 AI 분석을 앱에 탑재하지 않는다.
- 신청자 Snapshot과 카드, 파티 membership·구성원 카드까지 최소 무결성 필드를 반영했다. 그룹 membership 전파는 구현 완료 후 Rules 배포·실기기 확인 대기 중이다.
- 계약: [`../architecture/CHARACTER_BUILD_INTEGRITY_CONTRACT.md`](../architecture/CHARACTER_BUILD_INTEGRITY_CONTRACT.md)

### 그룹과 레이드

- 그룹 membership·초대코드·그룹장 이전/해산 계약과 레이드 명령·읽기·주간 Claim 계약이 구현돼 있다.
- 진행 중 레이드 카드의 방별 unread 배지는 레이드 현황 탭 재선택 갱신으로 보완했다. 모든 방의 실시간 Listener는 추가하지 않았다.
- 계약: [`../architecture/FIRESTORE_GROUP_MEMBERSHIP_CONTRACT.md`](../architecture/FIRESTORE_GROUP_MEMBERSHIP_CONTRACT.md), [`../architecture/GROUP_LEADER_EXIT_DISBAND_CONTRACT.md`](../architecture/GROUP_LEADER_EXIT_DISBAND_CONTRACT.md), [`../architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md`](../architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md), [`../architecture/WEEKLY_RAID_CLAIM_CONTRACT.md`](../architecture/WEEKLY_RAID_CLAIM_CONTRACT.md)

## 차후 제품 후보

- 직업·깨달음·질서 해/달/별 계층 메모, `망소빙` 같은 Build 별칭과 버전형 JSON 공유: [`../product/BUILD_MEMO_SHARING.md`](../product/BUILD_MEMO_SHARING.md)
- 직업 시너지 선택·필터: [`../product/CLASS_SYNERGY_CATALOG.md`](../product/CLASS_SYNERGY_CATALOG.md)
- 진행 중 내 Character 필터와 진행 중/레이드 모집의 참가 인원 로컬 정렬·남은 자리 2차 필터는 구현·실기기 확인했다. 계약: [`../architecture/ACTIVITY_CHARACTER_AND_RAID_FILTER_CONTRACT.md`](../architecture/ACTIVITY_CHARACTER_AND_RAID_FILTER_CONTRACT.md) §14
- 서버 데이터 무결성·복구 절차와 고아 binding/claim 점검은 재현 빈도가 높아질 때 별도 착수한다.
- FCM, 유료 서비스, 서버 상시 스케줄러는 별도 승인 전까지 제외한다.

## 문서와 운영 주의

- Firestore Rules 변경 섹션은 로컬 검증 후 AI가 실제 배포를 한 번만 시도한다. 실패하면 반복 배포·기능 삭제를 멈추고 실패 단계와 콘솔 활성 소스를 먼저 조사하며, 재시도는 사용자의 새 지시가 있을 때만 한 번 수행한다.
- CLI 503은 실패 단계(`/test`, `/rulesets`, `/releases`)와 콘솔 활성 게시본을 함께 확인한다. 503만으로 Rules 복잡도나 특정 기능을 원인으로 확정하거나 기능을 제거하지 않는다.
- Firebase 콘솔 복사본은 로컬 대조 자료일 뿐 배포 원본은 `firebase.json`이 지정한 `firestore.rules`다.
- 상세 완료 이력은 [`DEV_LOG.md`](DEV_LOG.md), Rules 장애·경고 이력은 [`TASK-11-FIRESTORE-RULES-COMPLEXITY.md`](TASK-11-FIRESTORE-RULES-COMPLEXITY.md)를 따른다.

## 다음 작업

현재 단일 작업은 [`NEXT_WORK.md`](NEXT_WORK.md)의 그룹 membership 보석 검증 Snapshot 전파다. 파티 신청·membership에서 검증된 다섯 필드 계약을 그룹 생성·가입·본인 표시 갱신과 그룹원 카드까지 확장하되, Build 별칭·개인 메모·공유는 포함하지 않는다.
