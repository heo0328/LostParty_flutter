# LOSTPARTY 문서 안내

> 기존 서비스 전용 항목은 [원문·출처 기록](../legacy/firebase/extracted/docs/README.md)으로 분리했다. 남은 제품/협업 문맥의 신규 서버 적용 여부는 별도 설계에서 판단한다.

## 백엔드 이전 사전 분석

- [빈 데이터 신규 서버 정책·설계](backend-migration/09-migration-decisions.md): 기존 사용자/데이터 이관 없음 확정. 10 서버 구조·11 인증/권한·12 첫 구현 패키지 연결. endpoint/DTO/SQL 최종 계약은 별도 backend 저장소가 소유한다.

- [백엔드 이전 분석 문서 지도](backend-migration/00-overview.md): dev e24baab 기준 Firebase 호출 전수·Firestore 모델·인증/권한·구독·화면·API 기능 요구·위험·단계 계획 9문서. 분석/문서화 전용이며 서버 endpoint/SQL schema·운영 데이터/배포 상태를 확정하지 않는다.

## 기존 서비스 레거시

- [기존 문서 보관 지도](../legacy/firebase/README.md): 전용 문서 이동 및 혼합 문서 발췌 목록.
- [문서·항목 출처 대장](../legacy/firebase/PROVENANCE.md): 원본 파일·절·행 범위와 내용 hash.
- [링크 정정 기록](../legacy/firebase/LINK_REPAIRS.md): 이동 경로와 기존 상대경로 정정.

보관 자료는 과거 기능·구현 근거다. 새 서버의 실행 기준은 위 백엔드 문서이며 이번에 작성한 backend-migration 파일은 이동하지 않았다.

## 이번 변경과 테스트 안내

- [현재 다음 작업](project/NEXT_WORK.md): Firebase 실행 코드·SDK·플랫폼 설정 최종 제거 조사와 회귀 보호 기준.
- [파일별 테스트 전환 대장](project/TEST_TRANSITION_INVENTORY.md): Firebase 테스트 제거 근거와 공통 검증 보존·안정화 결과. 전체1134테스트 통과, 수동4항목 통과; 완료 이력은 DEV_LOG.



## 문서 읽는 순서

현재 작업을 시작할 때는 다음 순서로 확인한다.

1. [`../AGENTS.md`](../AGENTS.md): AI가 자동 적용할 작업 시작·설계·회귀·Git·배포 게이트
2. [`project/ai_rules.md`](project/ai_rules.md): 협업·아키텍처·검증의 상세 규칙
3. [`project/NEXT_WORK.md`](project/NEXT_WORK.md): 바로 진행할 단일 작업 그룹
4. [`project/AI_CONTEXT.md`](project/AI_CONTEXT.md): 프로젝트 전체 지도와 상태 요약
5. 작업 영역에 해당하는 제품 또는 아키텍처 문서


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
