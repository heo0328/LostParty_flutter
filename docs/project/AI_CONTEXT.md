# AI CONTEXT (2026)

> 프로젝트 전체 지도와 현재 상태의 요약이다. 행동 규칙은 `ai_rules.md`, 바로 실행할 상세 작업은 `NEXT_WORK.md`, 완료 경과는 `DEV_LOG.md`가 기준이다.

## 현재 통합 상태

- 통합 기준은 `dev`이며 `dev`와 `main`에서 직접 수정하지 않는다. 최신 `dev`에서 기존 동일 목적 브랜치를 우선 확인하고, 없으면 `feature/*`, `fix/*`, `docs/*`, `refactor/*`, `release/*` 중 작업 목적에 맞는 브랜치로 분기한다. 도구명 접두사는 새로 만들지 않는다.
- 앱은 Firebase 익명 Auth와 Player binding, 게임 계정·Character 인증, 그룹, 레이드 모집·신청·참가·회차·완료 Claim, 로컬 알림과 계정 관리 흐름을 제공한다.
- 주차 경계는 한국 수요일 오전 6시 공통 정책을 사용한다. 만료된 1회성 방은 미완료 종료되고 새 주차 점유를 막지 않으며, 반복방은 최초 접근 시 멱등하게 현재 주차로 승계된다.
- 그룹 생성·가입 신청·탈퇴·그룹장 양도·초대코드 확인/가입·마지막 1인 해산과 레이드 주요 명령은 2026-09-10 운영 Rules 및 실기기에서 확인했다.
- 수동 인증 실기기 검증은 기능 결함으로 열린 것이 아니라 다음 통합 디바이스 테스트에서 필요할 때 함께 수행한다.

## 현재 제품 축

### Character와 인증

- 앱 실행 후 내 레이드 현황 초기 로딩과 충돌하지 않게 적격 Character를 앱 수명당 한 번 갱신한다. 공통 사용 레벨 정책은 현재 1700이며 나이스단 판정과 공유한다.
- 서버 관계가 없고 로컬 인증 표시만 남은 경우 서버 불일치로 안내한다. 자동 재귀속이나 자동 로컬 삭제는 하지 않으며 앱 데이터 초기화·재인증을 기본 복구 절차로 유지한다.
- 활동 Character 8→15 저장에서 Rules 문서 접근 한도로 `permission-denied`가 발생한 문제를 작은 묶음의 차이 저장으로 보완했고, 저장·재실행·후보 반영·기존 관계 보존을 실기기에서 확인했다.
- 장비 인증 Challenge는 의도적으로 Gateway 메모리에만 두고 앱 프로세스 종료 시 함께 종료한다. 인증 진행 카드에 앱 종료 시도 종료와 인게임 즉시 조작 권장을 안내하며, 시작 시 무기·방어구 5부위 중 하나라도 미장착이면 일반 정보 실패와 구분한 전용 착용 안내를 표시한다. 자동·실기기 검증을 완료했다.
- 계약: [`../architecture/GAME_ACCOUNT_CHARACTER_FIREBASE_CONTRACT.md`](../architecture/GAME_ACCOUNT_CHARACTER_FIREBASE_CONTRACT.md), [`../architecture/GAME_ACCOUNT_VERIFICATION_CONTRACT.md`](../architecture/GAME_ACCOUNT_VERIFICATION_CONTRACT.md), [`../architecture/CHARACTER_INTERACTION_AUTO_REFRESH_CONTRACT.md`](../architecture/CHARACTER_INTERACTION_AUTO_REFRESH_CONTRACT.md)

### Character Build 무결성

- 깨달음·아크그리드 질서 해/달 14P·보석 Tooltip 직업을 기본 검사한다. 별과 혼돈은 필수 판정에서 제외한다.
- 2026-09-12 제품 합의에서 빨간 확정 오류를 `보석 11개 미만`, `타 직업 보석`, `API 스킬·등록 특수 스킬 양쪽에 없는 보석`, `질서 해·달 누락/각 14P 미만`, `아크그리드 요구 아크패시브 불충족`으로 고정했다. 카탈로그 미등록은 중립 사유가 아니며 사용자가 정상 특수 스킬을 점진적으로 추가한다. API·Tooltip 자체의 정보 부족만 중립이다.
- 확정 오류 v2의 아이콘 fallback 제거와 오류 전용 표시 보정을 구현·자동 검증했다. 정상 근거는 `ArmorySkills OR 승인 카탈로그`로 제한하고 정상·판정 불능은 비표기, 확정 오류만 빨간색으로 표시한다. 복수 캐릭터 진단 도구도 OS 임시 원본 저장과 미등록 후보 추출을 지원한다.
- 카탈로그 `2026.09.12`에는 사용자 확인을 거쳐 환수사 `야성`의 `둔갑 금술 스킬`, 가디언나이트 `드레드 로어`의 `가디언 피어`, 데모닉 `멈출 수 없는 충동`의 `블러드 제노사이드`를 정상 특수 보석 대상으로 추가했다.
- 같은 카탈로그에 차원술사 `시간 관리자`의 `시간선 스킬`도 사용자 확인 정상 대상으로 추가했다.
- 27직업 108캐릭터의 실제 API 표본을 추가 교차검증해 카탈로그 `2026.09.12.2`를 30직업의 현재 깨달음 1티어 분기로 확장했다. `ArmorySkills`에 없고 Tooltip 직업이 일치한 특수 보석만 등록했으며, 인파이터의 브레이커 보석과 데빌헌터의 바드 보석 표본은 타 직업 오류로 유지한다.
- 실기기에서 확인한 새 파티장 membership의 보석 Snapshot 누락과 참가 Character 변경 목록의 통합 표시 누락을 보완했다. 새 파티장에는 기존 보석 최소 요약을 저장하고 변경 목록은 로컬 통합 상태로 보석·아크그리드 오류를 함께 표시한다. 표적 테스트 63건과 변경 파일 분석이 통과했고 Rules·권한·점유 순서는 변경하지 않았다. 사용자가 그룹 레이드 생성 파티장의 오류 표시를 실기기에서 확인해 기능 구현을 완료 판정했다.
- 신청·즉시 참가 Character 선택 목록에도 같은 로컬 통합 오류 표시를 적용했다. 과거 파티 마이그레이션은 현재 단독 테스트 단계에서 불필요하다는 사용자 결정으로 제외했다.
- 릴리즈 실기기에서 확인한 후보의 아크그리드·아크패시브 오류 전달 누락을 보완했다. 기존 보석 전용 Snapshot을 유지하면서 통합 `buildIntegritySnapshot`을 신청·membership에 dual-write하고, 승인 시 신청 당시 값을 복사하며 과거 문서는 기존 보석 경고로 호환한다. 운영 활성 Rules와 로컬 소스 일치 및 실기기 지속 표시를 확인했다.
- 계약: [`../architecture/CHARACTER_BUILD_INTEGRITY_CONTRACT.md`](../architecture/CHARACTER_BUILD_INTEGRITY_CONTRACT.md)

### 그룹과 레이드

- 그룹 membership·초대코드·그룹장 이전/해산 계약과 레이드 명령·읽기·주간 Claim 계약이 구현돼 있다.
- 진행 중 레이드 카드의 방별 unread 배지는 레이드 현황 탭 재선택 갱신으로 보완했다. 모든 방의 실시간 Listener는 추가하지 않았다.
- 8인 공격대 자리 이동과 점유 자리 교환, 동일 파티 중복 직업 교환 차단은 구현됐고 실기기에서 확인했다. Character 변경 자동 이동·파란 안내 제거와 알림의 일부 실기기 확인은 남아 있다.
- 기존 `release/1.0.0` 후보는 다인 명령 확장성 결함으로 폐기하고 이력용으로만 보존한다. 현재 우선 작업은 `BUG-018` 단일 보정이 아니라 파티·그룹 Firestore 명령, Player별 이벤트 fan-out과 Rules 접근 구조의 재설계다. 서버 후처리 단계는 사용하지 않고 현재 최대 8인의 핵심 상태를 제한된 원자 명령으로 확정하며, assignment·주간 Claim은 통합 `raidState`로 교체하는 방향이다. 종료 하위 문서 정리는 정확성과 분리한다. 기준: [`../architecture/PARTY_GROUP_COMMAND_SCALABILITY_REDESIGN.md`](../architecture/PARTY_GROUP_COMMAND_SCALABILITY_REDESIGN.md)
- 계약: [`../architecture/FIRESTORE_GROUP_MEMBERSHIP_CONTRACT.md`](../architecture/FIRESTORE_GROUP_MEMBERSHIP_CONTRACT.md), [`../architecture/GROUP_LEADER_EXIT_DISBAND_CONTRACT.md`](../architecture/GROUP_LEADER_EXIT_DISBAND_CONTRACT.md), [`../architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md`](../architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md), [`../architecture/WEEKLY_RAID_CLAIM_CONTRACT.md`](../architecture/WEEKLY_RAID_CLAIM_CONTRACT.md)

## 차후 제품 후보

- Character Build 오류·상태 정의, 기본 판정, 파티 생성 리더 Snapshot 및 참가 Character 변경 목록 표시 보완은 완료됐다.
- 기존 membership 보석 Snapshot을 통합 Build 상태로 이행할지 여부는 별도 후보다.
- 약 60개 직업·분기의 특수 보석 카탈로그 조사는 캐릭터명 기반 진단 도구와 사용자 승인을 반복하는 상시 관리 작업이다. 절차는 [`../integrations/LOST_ARK_API.md`](../integrations/LOST_ARK_API.md)를 따른다.
- 직업·깨달음·질서 해/달/별 계층 메모, `망소빙` 같은 Build 별칭과 버전형 JSON 공유: [`../product/BUILD_MEMO_SHARING.md`](../product/BUILD_MEMO_SHARING.md)
- 직업 시너지 선택·필터: [`../product/CLASS_SYNERGY_CATALOG.md`](../product/CLASS_SYNERGY_CATALOG.md)
- 진행 중 내 Character 필터와 진행 중/레이드 모집의 참가 인원 로컬 정렬·남은 자리 2차 필터는 구현·실기기 확인했다. 계약: [`../architecture/ACTIVITY_CHARACTER_AND_RAID_FILTER_CONTRACT.md`](../architecture/ACTIVITY_CHARACTER_AND_RAID_FILTER_CONTRACT.md) §14
- 테스트 데이터의 고아 `raidState`/신청 참조를 안전하게 진단·정리하는 도구는 별도 후속 작업이다. 모집 원본만 콘솔에서 단독 삭제하거나 Firebase 전체를 초기화하지 않는다. 실행 순서는 [`NEXT_WORK.md`](NEXT_WORK.md)의 F6 범위 밖 백로그를 따른다.
- FCM, 유료 서비스, 서버 상시 스케줄러는 별도 승인 전까지 제외한다.

## 문서와 운영 주의

- Firestore Rules 변경 섹션은 로컬 검증 후 AI가 실제 배포를 한 번만 시도한다. 실패하면 반복 배포·기능 삭제를 멈추고 실패 단계와 콘솔 활성 소스를 먼저 조사하며, 재시도는 사용자의 새 지시가 있을 때만 한 번 수행한다.
- CLI 503은 실패 단계(`/test`, `/rulesets`, `/releases`)와 콘솔 활성 게시본을 함께 확인한다. 503만으로 Rules 복잡도나 특정 기능을 원인으로 확정하거나 기능을 제거하지 않는다.
- Firebase 콘솔 복사본은 로컬 대조 자료일 뿐 배포 원본은 `firebase.json`이 지정한 `firestore.rules`다.
- 상세 완료 이력은 [`DEV_LOG.md`](DEV_LOG.md), Rules 장애·경고 이력은 [`TASK-11-FIRESTORE-RULES-COMPLEXITY.md`](TASK-11-FIRESTORE-RULES-COMPLEXITY.md)를 따른다.

## 다음 작업

현재는 파티·그룹 명령 재설계 후 F6 회귀 복구 단계다. F6-B1은 실기기 확인까지 완료했다. F6-B2-R1은 타인 private `raidState` 선읽기를 제거했고, R2는 공용 이벤트 한 건에 최대 8명의 완료 대상을 담아 수신자별 기록을 만드는 코드·Rules를 구현해 정적 검증을 통과했다. 로컬 Rules Emulator는 기존 503으로 동작 시나리오 전에 중단돼 R2 Rules CI가 남아 있으며, 체크박스 명령을 복구하는 R3와 전체 사이클 R4도 미완료다. **완료 기준은 `파티 전체 완료 → 완료 기록 → 완료방 해산 → 내 계정 체크 유지 → 본인 해제 → 재참가 가능` 하나의 인수 단위**다. 공용 이벤트 한 건과 최대 8인 원자 명령을 유지하고 `8×8` 검증·이벤트 fan-out을 금지한다. 세부 설계와 회귀 기준은 [`NEXT_WORK.md`](NEXT_WORK.md) F6-B2-R 및 [`../architecture/WEEKLY_RAID_CLAIM_CONTRACT.md`](../architecture/WEEKLY_RAID_CLAIM_CONTRACT.md) §0.6을 따른다. 이 전체 UX가 자동·실기기에서 통과하기 전 B2 완료·`dev/main` 통합·릴리즈는 보류한다.
