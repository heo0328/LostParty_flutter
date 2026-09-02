# LOSTPARTY 문서 안내

## 문서 읽는 순서

현재 작업을 시작할 때는 다음 순서로 확인한다.

1. [`project/NEXT_WORK.md`](project/NEXT_WORK.md): 현재 기준 상태와 다음 작업
2. [`project/AI_CONTEXT.md`](project/AI_CONTEXT.md): 프로젝트 전체 현재 상태
3. [`project/ai_rules.md`](project/ai_rules.md): 작업 및 문서 관리 규칙
4. 작업 영역에 해당하는 제품 또는 아키텍처 문서

## Product

사용자가 경험하는 기능과 제품 정책을 관리한다.

- [`product/MVP.md`](product/MVP.md): 초기 제품 범위
- [`product/PARTY_PARTICIPATION_RULES.md`](product/PARTY_PARTICIPATION_RULES.md): 신청, 참가 충돌과 캐릭터 변경 규칙
- [`product/RAID_CATALOG_DATA.md`](product/RAID_CATALOG_DATA.md): 레이드 정적 카탈로그 기준
- [`product/DETAIL_IMPROVEMENTS.md`](product/DETAIL_IMPROVEMENTS.md): 후속 세부 개선 후보

## Architecture

데이터 관계, Firebase 전환 및 백엔드 구조를 관리한다.

- [`architecture/FIREBASE_PARTY_PRODUCT_FLOW.md`](architecture/FIREBASE_PARTY_PRODUCT_FLOW.md): Firebase 파티 제품 흐름의 최신 통합 기준
- [`architecture/GAME_ACCOUNT_CHARACTER_FIREBASE_CONTRACT.md`](architecture/GAME_ACCOUNT_CHARACTER_FIREBASE_CONTRACT.md): 인증 게임 계정·Character 서버 ID와 최소 정보 동기화 계약
- [`architecture/ACTIVITY_CHARACTER_AND_RAID_FILTER_CONTRACT.md`](architecture/ACTIVITY_CHARACTER_AND_RAID_FILTER_CONTRACT.md): 활동 Character 선택, 캐릭터 관리 UI와 레이드 현황 그룹원·Character 필터 계약
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

- 새 문서를 만들기 전에 기존 기준 문서에 포함할 수 있는지 확인한다.
- 현재 상태와 다음 작업은 각각 `AI_CONTEXT.md`와 `NEXT_WORK.md`에서 관리한다.
- 누적 완료 이력은 `DEV_LOG.md`에서 관리한다.
- 제품 정책과 기술 구현 초안을 한 문서에서 무분별하게 혼합하지 않는다.
- 파일을 이동할 때 저장소 전체의 경로 참조를 함께 갱신한다.
