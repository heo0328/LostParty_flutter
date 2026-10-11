# LOSTPARTY 문서 안내

## 이번 변경과 테스트 안내

- [원정대 재인증 변경 안내](project/ROSTER_REAUTH_CHANGE_GUIDE.md): 사용자 관점의 새 기능과 Rules 변경 근거. 테스트 목록은 채팅에서 안내.


## 문서 읽는 순서

현재 작업을 시작할 때는 다음 순서로 확인한다.

1. [`../AGENTS.md`](../AGENTS.md): AI가 자동 적용할 작업 시작·설계·회귀·Git·배포 게이트
2. [`project/ai_rules.md`](project/ai_rules.md): 협업·아키텍처·검증의 상세 규칙
3. [`project/NEXT_WORK.md`](project/NEXT_WORK.md): 바로 진행할 단일 작업 그룹
4. [`project/AI_CONTEXT.md`](project/AI_CONTEXT.md): 프로젝트 전체 지도와 상태 요약
5. 작업 영역에 해당하는 제품 또는 아키텍처 문서

위 문서는 선택 참고가 아니라 수정 전 필수 확인 순서다. 저장소 루트의 `AGENTS.md`가 이 순서를 자동 작업 절차로 규정한다. Firestore Rules 변경 시에는 `project/TASK-11-FIRESTORE-RULES-COMPLEXITY.md`와 관련 Rules 계약 테스트까지 확인하고, 실제 기능 브랜치가 생성됐는지 `git branch --show-current`로 검증한 뒤 작업한다.

## Product

사용자가 경험하는 기능과 제품 정책을 관리한다.

- [`product/MVP.md`](product/MVP.md): 초기 제품 범위
- [`product/PARTY_PARTICIPATION_RULES.md`](product/PARTY_PARTICIPATION_RULES.md): 신청, 참가 충돌과 캐릭터 변경 규칙
- [`product/RAID_CATALOG_DATA.md`](product/RAID_CATALOG_DATA.md): 레이드 정적 카탈로그 기준
- [`product/DETAIL_IMPROVEMENTS.md`](product/DETAIL_IMPROVEMENTS.md): 후속 세부 개선 후보
- [`product/CLASS_SYNERGY_CATALOG.md`](product/CLASS_SYNERGY_CATALOG.md): 30개 직업·특성별 시너지 원본, 코드 사용법과 신청자 스펙 표시 비용 검토
- [`product/BUILD_MEMO_SHARING.md`](product/BUILD_MEMO_SHARING.md): 직업·깨달음·질서 해달별 계층 메모, 파티 카드 표시와 JSON/서버 공유 구상

## Feature Definitions

사용자가 앱을 사용하는 전체 흐름과 여러 기능 영역의 연결을 관리한다.

- [`feature-definitions/README.md`](feature-definitions/README.md): 기능 정의 문서의 범위와 목록
- [`feature-definitions/LOSTPARTY_CORE_USER_FLOW_OVERVIEW.md`](feature-definitions/LOSTPARTY_CORE_USER_FLOW_OVERVIEW.md): 게임 계정·원정대 인증부터 일반 레이드, 그룹과 그룹 전용방까지 이어지는 핵심 사용자 흐름 통합 지도

## Architecture

- [운영 Rules 전체 구조 재설계](architecture/RULES_PRODUCTION_RESTRUCTURE_DESIGN.md): §14 B1+A2 전체 기능본 테스트 게시 성공·활성SHA일치. 그룹 표시 검증 로컬 이전/중복 분기 통합 완료, 운영 lost-party도 14:17 KST 게시 성공·활성SHA일치. 실기기 인수 대기.

- [전체 Rules 세 방향 간소화 설계](architecture/RULES_SIMPLIFICATION_THREE_TRACK_DESIGN.md): 최신 후속 설계. 중복 검사·표시 로컬 이전·호출 단순화, 기존 기능/부작용/회귀와 구간별 범위. 사용자 요청으로 구간별 수정 중단·보존. 게시 정상화 미완료; 중단 체크포인트 참조.

- [Rules 책임 축소·로컬 이전 실행 계획](architecture/RULES_LOCALIZATION_EXECUTION_PLAN.md): 현재 실행 기준. 감소율 목표 없이 작은 단위별로 진행한다. 3-2 로컬 완료. 운영 게시1회는 컴파일 성공 후 활성화400/CLI fallback409로 실패, 기존 활성본 유지. 현재 순서는 NEXT_WORK를 따른다.

- [Firestore Rules 대폭 축소 설계](architecture/FIRESTORE_RULES_REDUCTION_DESIGN.md): Spark 무료 유지와 양·복잡도·깊이 축소. C1 로컬 기준, D 조건부 후보는 누적4.35% 감소로 목표 미달. 단일 명단 설계(§36), 완료(§37), 생성·참가(§38), 캐릭터/역할 변경(§39), 재배치 호환(§40). 개인완료/마지막1인 통합(§41). 전체완료 상태 통합(§42), 준비 변경 기본 경계331건 검증(§43), 준비 배치 추가25건(§44), 인증/advance414건 검증(§45), 인증 stub 참가 교체463건 검증(§46), Claim 결합 후보520건 검증·동시 요청1건 미완료(§47), 원인 분리 조사 완료·운영 동시성 미확인(§48), 일반 변경 대상 stub 교체572건 검증(§49), active 개인완료 인증 보존39건·누적611건(§50), 파티 밖 stub 수동완료681건 검증(§51), 다음 일반 수동완료 생성·이전 소유 차수 교체, 전체 D-X1 진행 중. 운영 게시·최종 인수 미완료.

- [완료 반복방의 다음 주 캐릭터 변경 설계](architecture/RECURRING_NEXT_WEEK_CHARACTER_CHANGE_DESIGN.md): BUG-024 원인·완료 기록 보존·준비 변경/전환 경계. Spark C 제한 회귀 통과 후 원격 활성화400으로 운영 반영 보류.
- [반복방 서버 트랜잭션 후속 설계](architecture/RECURRING_CYCLE_SERVER_TRANSACTION_DESIGN.md): 준비 변경·주차 전환의 서버 권한, 원자성, 재진입과 전환 순서. Spark 무료 유지 결정으로 중단한 대안.

- [반복방 Spark 무료 대안 재설계](architecture/RECURRING_CYCLE_SPARK_ALTERNATIVE_DESIGN.md): 현재 실행 기준. C 상태 확장 상세 설계·격리된 8인 선행 검증25/25 통과. 앱 호환 구현·운영 도입은 남음.

데이터 관계, Firebase 전환 및 백엔드 구조를 관리한다.

- [`architecture/FIREBASE_PARTY_PRODUCT_FLOW.md`](architecture/FIREBASE_PARTY_PRODUCT_FLOW.md): Firebase 파티 제품 흐름의 최신 통합 기준
- [`architecture/GAME_ACCOUNT_CHARACTER_FIREBASE_CONTRACT.md`](architecture/GAME_ACCOUNT_CHARACTER_FIREBASE_CONTRACT.md): 인증 게임 계정·Character 서버 ID와 최소 정보 동기화 계약
- [`architecture/ACTIVITY_CHARACTER_AND_RAID_FILTER_CONTRACT.md`](architecture/ACTIVITY_CHARACTER_AND_RAID_FILTER_CONTRACT.md): 활동 Character 선택, 캐릭터 관리 UI와 레이드 현황 그룹원·Character 필터 계약
- [`architecture/CHARACTER_INTERACTION_AUTO_REFRESH_CONTRACT.md`](architecture/CHARACTER_INTERACTION_AUTO_REFRESH_CONTRACT.md): 교류 행동 기반 자동 갱신, 나이스단 예외, 서포터 역할 판별과 단계별 작업 계약
- [`architecture/CHARACTER_BUILD_INTEGRITY_CONTRACT.md`](architecture/CHARACTER_BUILD_INTEGRITY_CONTRACT.md): 깨달음·아크그리드 최소 조건, 보석 직업 교차검증과 표시·Snapshot 경계
- [`architecture/GAME_ACCOUNT_VERIFICATION_CONTRACT.md`](architecture/GAME_ACCOUNT_VERIFICATION_CONTRACT.md): 게임 계정 장비 인증과 소유권 계약
- [`architecture/BACKEND_PARTY_ARCHITECTURE.md`](architecture/BACKEND_PARTY_ARCHITECTURE.md): 기존 백엔드·파티·그룹 설계
- [`architecture/PLAYER_FIREBASE_MIGRATION_REVIEW.md`](architecture/PLAYER_FIREBASE_MIGRATION_REVIEW.md): Player 식별자와 Firebase 전환 영향 검토
- [`architecture/FIRESTORE_PARTY_READ_MODEL_CONTRACT.md`](architecture/FIRESTORE_PARTY_READ_MODEL_CONTRACT.md): 파티 목록·현황 읽기와 오프라인 상태 계약
- [`architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md`](architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md): Spark Firestore 파티 명령과 Rules 계약
- [`architecture/FIRESTORE_PARTY_EVENT_CONTRACT.md`](architecture/FIRESTORE_PARTY_EVENT_CONTRACT.md): Player 이벤트와 Drift 로컬 히스토리 계약
- [`architecture/PARTY_NOTIFICATION_CONTRACT.md`](architecture/PARTY_NOTIFICATION_CONTRACT.md): Spark 앱 내부 알림과 향후 FCM의 공통 파티 이벤트 계약
- [`architecture/WEEKLY_RAID_CLAIM_CONTRACT.md`](architecture/WEEKLY_RAID_CLAIM_CONTRACT.md): 캐릭터 개인 주간 완료 Claim, 파티 점유와 완료 체크박스 계약
- [`architecture/OPERATOR_AUTHORIZATION_CONTRACT.md`](architecture/OPERATOR_AUTHORIZATION_CONTRACT.md): 운영자 권한, 수동 게임 계정 인증, 사용자 확인과 마지막 접속 계약
- [`architecture/FIRESTORE_GROUP_MEMBERSHIP_CONTRACT.md`](architecture/FIRESTORE_GROUP_MEMBERSHIP_CONTRACT.md): Task-11 그룹 생성·Player 단위 가입·초대코드와 Rules 계약
- [`architecture/GROUP_LEADER_EXIT_DISBAND_CONTRACT.md`](architecture/GROUP_LEADER_EXIT_DISBAND_CONTRACT.md): 그룹장 즉시 지정 이전·후속 탈퇴·1인 해산과 보관 계약
- [`architecture/PARTY_GROUP_COMMAND_SCALABILITY_REDESIGN.md`](architecture/PARTY_GROUP_COMMAND_SCALABILITY_REDESIGN.md): 인원수 비례 파티·그룹 명령, 공용 이벤트·Aggregate·통합 raidState·8인 제한 원자 명령 재설계
- [`architecture/TRUSTED_PARTY_JOIN_COMMAND_DESIGN.md`](architecture/TRUSTED_PARTY_JOIN_COMMAND_DESIGN.md): BUG-022 그룹방 재가입을 위한 신뢰 서버 참가 명령, 멱등성·전환·배포 결정 게이트
- [`architecture/BUG_022_REMAINING_FIX_DESIGN.md`](architecture/BUG_022_REMAINING_FIX_DESIGN.md): BUG-022 미완료 재가입·재설치 복구·원정대 이전을 Spark 범위에서 분리한 실행 설계
- [`architecture/GITHUB_ANDROID_RELEASE_PIPELINE.md`](architecture/GITHUB_ANDROID_RELEASE_PIPELINE.md): 정식 Android ID·영구 서명키·태그 기반 APK GitHub Release 자동화 계약

## Integrations

외부 서비스 연결과 API 기준을 관리한다.

- [`integrations/FIREBASE_INITIAL_SETUP_REVIEW.md`](integrations/FIREBASE_INITIAL_SETUP_REVIEW.md): Firebase 프로젝트와 플랫폼 초기 연결 확인
- [`integrations/LOST_ARK_API.md`](integrations/LOST_ARK_API.md): Lost Ark API 연동 기준

## Project

현재 작업 상태, 개발 이력과 작업 규칙을 관리한다.

- [`project/NEXT_WORK.md`](project/NEXT_WORK.md): 다음 작업의 단일 기준
- [`project/AI_CONTEXT.md`](project/AI_CONTEXT.md): 프로젝트 전체 현재 상태
- [`project/DEV_LOG.md`](project/DEV_LOG.md): 완료 작업 누적 이력
- [`project/BUG_REPORTS.md`](project/BUG_REPORTS.md): 실기기·사용 중 발견 버그와 조사 메모
- [`project/ai_rules.md`](project/ai_rules.md): AI 협업 및 작업 규칙

## Design

UI 방향, 디자인 시스템과 시각적 적용 기준을 관리한다.

- [`design/LOSTPARTY_DESIGN_SYSTEM_V1_REQUEST.md`](design/LOSTPARTY_DESIGN_SYSTEM_V1_REQUEST.md): Soft Lavender 기반 Design System v1 설계 요청과 단계적 적용 기준
- [`design/PARTY_COMPOSITION_RESPONSIVE_LAYOUT.md`](design/PARTY_COMPOSITION_RESPONSIVE_LAYOUT.md): 바형 스마트폰·폴드·태블릿의 파티 구성판 반응형 배치 계약

## 관리 원칙

- AI의 핵심 실행 게이트는 루트 `AGENTS.md`, 상세 행동 정책은 `project/ai_rules.md`에서 관리한다. 두 문서가 다르면 더 안전한 규칙을 우선 적용하고 같은 작업에서 정합성을 바로잡는다.
- 새 문서를 만들기 전에 기존 기준 문서에 포함할 수 있는지 확인한다.
- 기록 우선순위는 사용자 최신 지시 → `AGENTS.md` → `ai_rules.md` → `NEXT_WORK.md` → `AI_CONTEXT.md` → 기능별 계약 문서 → `DEV_LOG.md`의 과거 이력 순이다. 최신 지시가 안전·권한·배포 규칙과 충돌하면 예외 범위를 확인한 뒤 진행한다.
- 현재 상태와 다음 작업은 각각 `AI_CONTEXT.md`와 `NEXT_WORK.md`에서 관리한다.
- 작업 구간 완료 시 `NEXT_WORK.md`와 `AI_CONTEXT.md`의 완료 상세를 `DEV_LOG.md`로 이동한다.
- `AI_CONTEXT.md`에는 전체 작업의 제목·핵심 상태·상세 문서 연결만 남기고, `NEXT_WORK.md`에는 바로 진행할 작업의 상세 근거와 순서만 둔다.
- 누적 완료 이력은 앱 전체 개발 현황을 추적할 수 있도록 `DEV_LOG.md`에서 상세·간략 기록을 병행해 꼼꼼히 관리한다.
- 제품 정책과 기술 구현 초안을 한 문서에서 무분별하게 혼합하지 않는다.
- 파일을 이동할 때 저장소 전체의 경로 참조를 함께 갱신한다.
