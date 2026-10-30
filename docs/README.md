# LOSTPARTY 문서 안내

## 작업 시작과 문서 역할

1. [AGENTS](../AGENTS.md): 설계 선행 조건·기능 완료·브랜치/커밋·권한의 핵심 기준
2. [ai_rules](project/ai_rules.md): 상세 구현/검증·협업 절차
3. [NEXT_WORK](project/NEXT_WORK.md): 현재 진행할 파트와 유효 후속
4. [AI_CONTEXT](project/AI_CONTEXT.md): 현재 영역별 상태와 기준 문서 연결
5. 해당 제품/계약: 사용자가 확정한 의도·UX·데이터/권한 정책. 실행계획의 선행 조건이며 계획으로 변경하지 않음

## 현재 개발의 고정 전제

현재 1인 개발이며 Firebase 구현을 제거하고 자체 Python Backend·단일 Google 로그인으로 회원을 구분한다. 관련 앱/Backend 구현 후 테스트하며 베타 직전 개발자료를 비우고 베타 이후 자료는 보존한다. [정책09 D08](backend-migration/09-migration-decisions.md#d08-개발--베타--운영-데이터-수명--사용자-확정). 실제 삭제/배포는 별도 실행 지시가 필요하다.

## 기능·기술 계약 지도

- [그룹 제품 흐름](product/GROUP_PRODUCT_FLOW.md)·[그룹 연결 설계39](backend-migration/39-group-flutter-integration-design.md): 전체 UX·기존 구현/현재 서버·미연결/미제공·단계별 완료 조건.

- [모집·일정 통합37](backend-migration/37-raid-scheduling-and-multi-raid-planning.md): 최신 두 주차/단일 기본 출발·조기조율·번호·신청메모 계약. [현재 구현·기기 인수표](backend-migration/37-raid-scheduling-and-multi-raid-planning.md#recruitment-status-20261027)에서 통과·남은 경계·베타 이후 개선을 구분한다.
- [비활성 기능](project/INACTIVE_FEATURES.md): IF-001/002/003의 제품 제외·실제 차단 상태 구분
- [계정/캐시/복원30](backend-migration/30-scoped-storage-write-contract.md), [등록19](backend-migration/19-account-registration-flutter-contract.md), [키25](backend-migration/25-member-lostark-key-request.md), [인증36](backend-migration/36-roster-ownership-dispute-flutter-design.md)
- [한도34](backend-migration/34-member-limits-and-room-restrictions.md)·[통계35](backend-migration/35-weekly-member-and-group-statistics.md)·[분야별 요청32](backend-migration/32-backend-domain-prework-requests.md)
- [계정 후속14](backend-migration/14-my-account-flutter-integration-plan.md)·[DB 검토24](backend-migration/24-database-design-review.md)·[백엔드 문서목록](backend-migration/00-overview.md)
- Penpot03 작업 중/02 구현 완료, 메인 보드·섹션별 하위 보드 수정과 완료 후 동일 보드 이동은 [디자인 공통 지침](design/LOSTPARTY_DESIGN_SYSTEM_V1_REQUEST.md#penpot-작업완료-화면-관리-공통-지침)을 따른다. 과거 시안 식별자/운영 이력은 설계37 §37.65.

완료/검증 이력은 [DEV_LOG](project/DEV_LOG.md), 버그는 [BUG_REPORTS](project/BUG_REPORTS.md), 지시문 감사는 [보고서](project/INSTRUCTION_AUDIT_2026-10-25.md). 과거 Firebase 기술/배포 자료는 [레거시 지도](../legacy/firebase/README.md)에 보관하며 신규 실행 지시로 재사용하지 않는다.

## Product

사용자가 경험하는 기능과 제품 정책을 관리한다.

- [`product/MVP.md`](product/MVP.md): 초기 제품 범위
- [`product/PARTY_PARTICIPATION_RULES.md`](product/PARTY_PARTICIPATION_RULES.md): 신청, 참가 충돌과 캐릭터 변경 규칙
- [`product/RAID_CATALOG_DATA.md`](product/RAID_CATALOG_DATA.md): 레이드 정적 카탈로그 기준
- [`product/DETAIL_IMPROVEMENTS.md`](product/DETAIL_IMPROVEMENTS.md): 차후 수정안 통합 대장(현재 유지/변경 목표·확정/보류·담당·완료 조건)
- [`product/CLASS_SYNERGY_CATALOG.md`](product/CLASS_SYNERGY_CATALOG.md): 30개 직업·특성별 시너지 원본, 코드 사용법과 신청자 스펙 표시 비용 검토
- [`product/BUILD_MEMO_SHARING.md`](product/BUILD_MEMO_SHARING.md): 직업·깨달음·질서 해달별 계층 메모, 파티 카드 표시와 JSON/서버 공유 구상

## Feature Definitions

사용자가 앱을 사용하는 전체 흐름과 여러 기능 영역의 연결을 관리한다.

- [`feature-definitions/README.md`](feature-definitions/README.md): 기능 정의 문서의 범위와 목록
- [`feature-definitions/LOSTPARTY_CORE_USER_FLOW_OVERVIEW.md`](feature-definitions/LOSTPARTY_CORE_USER_FLOW_OVERVIEW.md): 게임 계정·원정대 인증부터 일반 레이드, 그룹과 그룹 전용방까지 이어지는 핵심 사용자 흐름 통합 지도

## Architecture

- [개발 품질·데이터 흐름·UX 기준](architecture/DEVELOPMENT_QUALITY_AND_UX_STANDARD.md): 사용자 이해를 우선하는 패턴/책임·API/캐시·비동기/검증 기준, 대표 코드 검토와 서비스 복구 릴리즈 후 main 기준 최적화 검토 안내.

- [Google 로그인 연동 정책](architecture/GOOGLE_LOGIN_CONTRACT.md): Android 신규 Backend 인증, 비로그인 로컬 기능 보존, 로그인 유지·접근 제어 및 계약 인계 게이트.








- [`architecture/ACTIVITY_CHARACTER_AND_RAID_FILTER_CONTRACT.md`](architecture/ACTIVITY_CHARACTER_AND_RAID_FILTER_CONTRACT.md): 활동 Character 선택, 캐릭터 관리 UI와 레이드 현황 그룹원·Character 필터 계약
- [`architecture/CHARACTER_INTERACTION_AUTO_REFRESH_CONTRACT.md`](architecture/CHARACTER_INTERACTION_AUTO_REFRESH_CONTRACT.md): 교류 행동 기반 자동 갱신, 나이스단 예외, 서포터 역할 판별과 단계별 작업 계약
- [`architecture/CHARACTER_BUILD_INTEGRITY_CONTRACT.md`](architecture/CHARACTER_BUILD_INTEGRITY_CONTRACT.md): 깨달음·아크그리드 최소 조건, 보석 직업 교차검증과 표시·Snapshot 경계
- [`architecture/GAME_ACCOUNT_VERIFICATION_CONTRACT.md`](architecture/GAME_ACCOUNT_VERIFICATION_CONTRACT.md): 게임 계정 장비 인증과 소유권 계약
- [`architecture/BACKEND_PARTY_ARCHITECTURE.md`](architecture/BACKEND_PARTY_ARCHITECTURE.md): 기존 백엔드·파티·그룹 설계
- [`architecture/WEEKLY_RAID_CLAIM_CONTRACT.md`](architecture/WEEKLY_RAID_CLAIM_CONTRACT.md): 캐릭터 개인 주간 완료 Claim, 파티 점유와 완료 체크박스 계약
- [`architecture/OPERATOR_AUTHORIZATION_CONTRACT.md`](architecture/OPERATOR_AUTHORIZATION_CONTRACT.md): 운영자 권한, 수동 게임 계정 인증, 사용자 확인과 마지막 접속 계약
- [`architecture/GROUP_LEADER_EXIT_DISBAND_CONTRACT.md`](architecture/GROUP_LEADER_EXIT_DISBAND_CONTRACT.md): 그룹장 즉시 지정 이전·후속 탈퇴·1인 해산과 보관 계약
- [`architecture/GITHUB_ANDROID_RELEASE_PIPELINE.md`](architecture/GITHUB_ANDROID_RELEASE_PIPELINE.md): 정식 Android ID·영구 서명키·태그 기반 APK GitHub Release 자동화 계약

## Integrations

외부 서비스 연결과 API 기준을 관리한다.

- [`integrations/LOST_ARK_API.md`](integrations/LOST_ARK_API.md): Lost Ark API 연동 기준

## Project

현재 작업 상태, 개발 이력과 작업 규칙을 관리한다.

- [`project/NEXT_WORK.md`](project/NEXT_WORK.md): 다음 작업의 단일 기준
- [`project/INACTIVE_FEATURES.md`](project/INACTIVE_FEATURES.md): 구현 후 협의로 사용하지 않는 기능과 비활성·보존 경계
- [`project/AI_CONTEXT.md`](project/AI_CONTEXT.md): 프로젝트 전체 현재 상태
- [`project/DEV_LOG.md`](project/DEV_LOG.md): 완료 작업 누적 이력
- [`project/BUG_REPORTS.md`](project/BUG_REPORTS.md): 실기기·사용 중 발견 버그와 조사 메모
- [`project/ai_rules.md`](project/ai_rules.md): AI 협업 및 작업 규칙

## Design

UI 방향, 디자인 시스템과 시각적 적용 기준을 관리한다.

- [`design/LOSTPARTY_DESIGN_SYSTEM_V1_REQUEST.md`](design/LOSTPARTY_DESIGN_SYSTEM_V1_REQUEST.md): Soft Lavender 기반 Design System v1 설계 요청과 단계적 적용 기준
- [`design/PARTY_COMPOSITION_RESPONSIVE_LAYOUT.md`](design/PARTY_COMPOSITION_RESPONSIVE_LAYOUT.md): 바형 스마트폰·폴드·태블릿의 파티 구성판 반응형 배치 계약

## 관리 원칙

- 양쪽 저장소의 문서 역할·갱신·이관은 [공통 문서 운영 원본](https://github.com/heo0328/lostparty-backend/blob/c1fa205db709f97c1d34817c4417b84144a5dde3/docs/engineering/collaboration/api-collaboration.md#shared-document-operation)을 참조한다. 소비 기준은 Backend 문서 커밋 `c1fa205d`이며, 후속 공통 변경은 [Issue29](https://github.com/heo0328/lostparty-backend/issues/29) 등 관련 Issue에서 양측 영향을 확인한 뒤 고정 참조를 갱신한다. Flutter의 현재 분류·DETAIL_IMPROVEMENTS·legacy/history는 유지한다.
- 작업 시작/설계·완료·Git의 실행 기준은 [AGENTS](../AGENTS.md)이며 상세 절차는 ai_rules다. 확정 제품/개발 정책을 실행계획이 덮지 못한다. '더 안전해 보인다'는 이유로 임의의 운영 전환/호환 단계를 추가하지 않는다.
- NEXT_WORK는 현재 파트/유효 후속, AI_CONTEXT는 현재 지도/핵심 상태만 유지한다. 완료/해소된 대기·폐기 계획은 DEV_LOG/history로 옮기고 기존 문구를 교체한다. 이 지도에 버전/검증 수치/실행 대기를 중복 기록하지 않는다.
- 문서·지침·버그기록·UI 보완은 진행 중 대단원 브랜치에서 처리한다. 한 파트 완료 시 커밋/푸시하며 질문/댓글/한 줄 변경마다 커밋하지 않는다. 통합은 별도 시점이다.
- 문서/절을 이동할 때 상대 링크와 출처를 보존한다. 현재 정책과 당시 구현 이력을 구분한다.
