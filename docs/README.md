# LOSTPARTY 문서 안내

> 기존 서비스 전용 항목은 [원문·출처 기록](../legacy/firebase/extracted/docs/README.md)으로 분리했다. 남은 제품/협업 문맥의 신규 서버 적용 여부는 별도 설계에서 판단한다.

## 현재 개발 체크포인트 — 2주 레이드 현황 (2026-10-22)

모집/내 계정/참가 현황을 **이번 주·다음 주 직접 선택**으로 확장하는 제품 기획을 채택했다. 같은 방의 주차별 참가·설정·일정·공대장을 분리하며, 기존 참가자의 다음 주 바로 참가와 충돌 복구, N 활성화 공대장의 참가·주차별 탈퇴/자동 승계·직접 위임이 포함된다. 수06시 주차 전환·해당 수10시 이후 완료, 계정3열 체크와 우측i·4/8인 자리 번호를 유지한다.

기획/시안 반영과 실제 구현은 구분한다. **F1 주차별 읽기와 F2 v2 생성/context·같은 방 주차별 상세를 구현·자동 검증했고 실서버/실기기 인수는 미확인**이다. F3 검색/일반 참가·신청/승인/거절/철회·캐릭터 변경과 그룹 캐릭터 후보 필터까지 연결·자동검증했다. F4 다음주 참가·주차별 탈퇴/승계·위임/편성·설정/공통관리를 연결·자동검증했다(설계37 §37.14, 고유93PASS·변경7파일 분석0). F5 제출표/시간조율·제안/투표/참가확인·예약상태를 독립 연결했다(설계37 §37.15, 고유130PASS·변경7파일 분석0). 사전 참가 표시 정보는 Backend112에서 구현 인계를 받았고 Flutter 연결 설계 재점검까지 마쳤다(설계37 §37.17). 새 표시 연결·실제 정상인증HTTP/기기 인수와 F6 완료는 남아 있다. Backend92에서 개발DB/API 전환·읽기구간을 인계했다. 디바이스 전 네이티브 F1~F6 설계는 설계37 §37, F1 결과는 §37.9, F2 결과는 §37.10, F3 기본 연결은 §37.11, 후보 구현은 §37.13이다. 생성은 C/N을 함께 확정하되 이후 탈퇴·위임·완료는 주차별 독립이다. 현재 정책은 [설계37](backend-migration/37-raid-scheduling-and-multi-raid-planning.md), 흐름은 [사용자 흐름 지도](feature-definitions/LOSTPARTY_CORE_USER_FLOW_OVERVIEW.md), 다음 행동/미정은 [NEXT_WORK](project/NEXT_WORK.md), 완료 이력은 [DEV_LOG](project/DEV_LOG.md)를 따른다.

## 이전 안정화 기준 (2026-10-18~19)

회원별 캐시·원정대/설정/주간 복원, 앱 수명 자동 갱신 최대2worker, [일괄 조회 연결30](backend-migration/30-scoped-storage-write-contract.md), 정적 이미지4초 진입과debug진단까지 마감·dev/main 동일 시점 반영 구간이다. 최종 검증은 전체1,662PASS/lib·test분석0이다. 실기기에서 일괄GET1회/계측요청76→29·단계시간단축과4초진입 사용자 수용을 받았다. 추가 성능 개선/애니메이션은 보류한다.

2026-10-19 원정대 인증·분쟁V2는 `feature/roster-ownership-dispute`·[Issue15](https://github.com/heo0328/lostparty-backend/issues/15)의 D1~D4 코드/자동 검증 완료다(D4 직접 영향68고유PASS·변경18파일분석0). 공통 상단 안내와 기존 인증 화면을 연결했으며 사용자 승인으로 현재 구현 구간을 마감하고 구현 43cd4e9를 dev에 병합·푸시했다. Backend 작업으로 불가능한 실서버/디바이스 인수는 차후 후속으로 이관했다. 최종 통합 커밋은 DEV_LOG를 따른다. 기존 V1 미완료 요청은 보존한다. 최소 UI 추가 기준은 [설계36](backend-migration/36-roster-ownership-dispute-flutter-design.md), 수동 체크/다음 작업은 [NEXT_WORK](project/NEXT_WORK.md), 상태는 [AI_CONTEXT](project/AI_CONTEXT.md), 결과/미확인은 [DEV_LOG](project/DEV_LOG.md)를 따른다. 기존 캐릭터 일괄 조회/상세 갱신은 유지하며 추가 Backend구현을재요청하지않는다. 아래 과거 단계별 수치/대기는 당시 기록이다.

## 주간 이용 통계 설계

[사용자·그룹 주간 통계35](backend-migration/35-weekly-member-and-group-statistics.md): KST수요일06시 주차별 공개/그룹 이용·완료/미완료종료·함께하기 집계 요구. 수동체크 제외, 주중 고유 참가·미완료 회차 마감·마감 시 함께하기 기준 확정·미구현.

## 사용자별 이용 한도 설계

[한도·방 제한34](backend-migration/34-member-limits-and-room-restrictions.md): 계정별 그룹/모집 한도·감소 시 진행 제한과 탈퇴/추방 회복. BM은 미도입이며 현재 그룹장 정원15/가입5/참가 모집 합산10을 기본값으로 확정했다.

## Backend 선행 API 분야별 요청

#13의 개인표6ecb81d·계정UI4198f1a는 사용자 정상 확인 완료다. 생성/기본상세 v1 연결·시간/입장 정책은 선행 복구17f8675에 보관했고 인증 회원 목록은 v2검색으로 연결했고 비로그인 기존 Pending은 유지한다. F1 target 본인목록·기본 읽기상세는 v2로 연결됐다. 구간별 문서·코드·테스트를 커밋·작업 브랜치 푸시로 보관하며 dev 통합/실기기 전체 인수는 아직 아니다. F2로 실제생성/상세 DI를 v2로 전환했다. F4 다음주 참가·주차별 관리까지 마쳤고 F5 일정/예약을 독립 연결했고 사전 참가 시간표시 보완 → F6 완료/통합 순서로 진행한다. 상세 상태와 검증 근거는 [AI_CONTEXT](project/AI_CONTEXT.md)·[NEXT_WORK](project/NEXT_WORK.md)·[DEV_LOG](project/DEV_LOG.md)를 따른다.

- [이전 축소 1차 계획 기록38](backend-migration/38-account-availability-and-role-power-phase1.md): 폐기된 범위의 변경 이력. 현재 통합 목표와 UI 선행/계약 대조는 설계37 §24/NEXT_WORK를 따른다.

- [모집 시간·역할별 전투력·그룹 범위·다중 레이드 요구37](backend-migration/37-raid-scheduling-and-multi-raid-planning.md): 모집·일정의 현재 제품 계약과 디자인/Backend 인계, 개인표 구현 및 모집 후속 범위를 관리한다.

[요청32·분야/순서 인덱스](backend-migration/32-backend-domain-prework-requests.md): #10 카탈로그/주차 → #11 주간 상태·#12 그룹 → #13 모집/파티. #10/#11 첫 구간 인계를 수신했고 [주간 체크박스 연결33](backend-migration/33-weekly-raid-flutter-integration.md)을 구현했다. 전체1622PASS·분석0, 실제 서버 쓰기/기기 확인은 대기다. #12/#13 후속과 미확정 정책은 해당 기능만 분리하고 현재 개발환경/자료를 유지한다.

## 최신 연결 — 회원 화면·관리·서버 복원

[회원 화면·관리 진입·서버 복원 설계](backend-migration/30-scoped-storage-write-contract.md#회원-화면관리-진입서버-복원-연결-설계-2026-10-17): 로그인 회원 저장 정보 복원과 자동 provider 실행을 분리하고 기존 관리 버튼·이름 옆 인증 버튼을 연결한다. **R1/R2 연결·전체1,596PASS/분석0 완료**, 새 화면 실기기 확인 대기. Backend110번째 기준 추가 서버 대기 없음. 구현 존재와 기본 화면 접근 가능은 구분한다. 현재 실행 순서/검증은 [NEXT_WORK](project/NEXT_WORK.md)를 따른다.

## 현재 채택한 등록·인증 UX

[정책09 D10](backend-migration/09-migration-decisions.md)·[핵심 흐름 지도](feature-definitions/LOSTPARTY_CORE_USER_FLOW_OVERVIEW.md): 비로그인 기본 로컬 검색, 로그인 미인증 조회용 서버 저장, 현재 소유 인증 후 상세/전투력·선택 후 활동. Flutter R1 전체1542PASS/분석0, Backend D10 power/cache 보완59b8c23·256PASS/현재8000 반영 보고. **기존 캐릭터 관리 화면의 현재 서버 연결·초기 대표1회/공통1700·인증 후 전환 완료**, 최종 전체1560PASS/분석0. 별도 선택/복구 화면 없음. [연결 인계](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6209931176). 기본flag OFF 유지. 실제 소유 증거/실기기 인수는 별도 미확인. [Issue8 최종 대조](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6209491349)·[작업 순서](project/NEXT_WORK.md). 현재 환경/개발자료를 유지한다.

## 백엔드 이전 사전 분석

- [Flutter 제품 설정·UX 공유 기준](backend-migration/31-app-product-policy-handoff.md): 기능/UX 유지·Firebase 전용 구현 제거, Backend에 필요한 설정 의미·연결/미완료 범위만 공유. D 별도 저장 연결은 철회·원래 연결 복구, 현재 환경/개발자료로 개발 계속. 최신 검증은 NEXT_WORK.

- [회원·환경별 캐시 저장·writer 분리 계약](backend-migration/30-scoped-storage-write-contract.md): S1~S3/A1/A2/B를 C 앱 수명/회원 주목록·진행 UI에 연결. schema3/기기 schema13 보존, 기본 flag OFF. 현재 환경에서 개발 계속, 별도 빈 환경·기초 재인수 선행 절차 철회.

- [회원·환경별 서버 캐릭터 연결 설계](backend-migration/29-scoped-character-identity-design.md): 실제 mapping/writer 조사·출처와 ID/세대 연결 계약, Backend L1a 기반/L1b 상태 읽기 구현 인계·live 퇴역 비활성 범위.

- [원정대 인증 클라이언트·화면 연결](backend-migration/28-verification-client-preparation.md): 인증4경로·대상 ID 전달/인증 성공 후 기존 관리 화면 연결 완료. 최신 전체1560PASS/분석0, 실제 소유·실기기 인수는 미확인.

- [대표 캐릭터 빠른 선택 UX](backend-migration/27-representative-quick-selection-ux.md): 파스텔 왕관·확인 알럿/취소좌·변경우. Backend 대표 API P2 소비·Flutter E1 왕관/확인/쓰기/복구 연결, 활동 전체 편집은 기존 관리 화면의 현재 서버 연결 완료.

- [원정대 캐릭터 변경·소멸 이력·이름 재사용 설계](backend-migration/26-roster-character-lifecycle-design.md): 사용자 정책·Backend 공식 조사 수신/증거 보류, 신규 ID/기존 파티 보존. L1 착수 범위는29/Issue8 최신 요청 참조.

- [회원별 Lost Ark API 키 서버 저장·호출 전환 요청](backend-migration/25-member-lostark-key-request.md): 회원키 등록/복원·기기저장·호출제한 UX 연결, Backend9e1a255b 소비·자동 검증/현재 기능 사용자 확인 완료.

- [전체 데이터베이스 설계 재점검](backend-migration/24-database-design-review.md): Backend19개/Flutter8개테이블·저장소/회원ID/복원경계·로컬삭제정합성재현과다음설계결정.

- [나이스단 자동 갱신 설계·기존 구조 조사](backend-migration/23-nice-group-auto-refresh-design.md): 활성 전체 상세1회/나이스단OFF 예외·B 실행/C 앱 수명·회원 주목록·진행 화면 연결 완료. D 정리 완료, 현재 환경에서 개발 계속·실제 소유 증거가 필요한 전체 인수는 별도 미확인이다.

- [Flutter 전투력 연결 계약](backend-migration/22-character-combat-power-flutter-contract.md): 소비39188d5·Strict DTO·단일 요청복구·서버/로컬 카드·회원격리·인수 범위.

- [전투력 수집·갱신 Backend 요청](backend-migration/21-character-combat-power-backend-request.md): Issue5, 미인증/인증 등록 캐릭터 전투력 캐시·대상 갱신과 서버/로컬 표시 연결 범위.

- [빈 이름 자동 표시](backend-migration/20-account-auto-label-contract.md): 미입력은 본·부계정 위치로 계산, 직접 입력 이름은 그대로 표시.

- [Flutter 서버 등록 관리 연결](backend-migration/19-account-registration-flutter-contract.md): preview/등록 CRUD·멱등/세션 경계·Router 연결과 사용자 인수 항목.

- [서버 등록 관리 후속 제안](backend-migration/18-account-registration-integration-proposal.md): 신규 Backend 이슈 #4의 실 API 검증·Flutter 연동 인계 제안. #3 완료 근거를 재사용한다.
- [등록 관리 Backend 요청](backend-migration/17-account-registration-backend-request.md): Flutter 조회 결과 인계·기존 등록 API 소비·서버/provider 테스트 준비와 필요한 보완 요청.
- [현재 Flutter 서버계정 조회](backend-migration/16-account-read-flutter-contract.md): 기본프로젝트실행경로·고정계약·서버/로컬분리·API카드인수.


- [내 계정 테스트 준비](backend-migration/15-my-account-test-readiness.md): Backend 결과·직접 smoke·자동/사용자/provider 검증 범위와 현재 제한.
- [내 계정 Flutter 연결 계획](backend-migration/14-my-account-flutter-integration-plan.md): 초기 연결 계획과 최신 후속 대장. 인증 화면·자동 갱신/복원 코드 완료, 기존 관리/활동·대표 연결 완료와 실환경 인수·별도 후속을 구분.
- [내 계정 Backend 1차 작업 지시서](backend-migration/13-my-account-backend-phase1-request.md): 등록/캐릭터 조회·장비 인증·활동/대표 선택 API 및 서버 검증·인계 요청. 계약 경로/DDL는 Backend 검토 전 제안.

- [빈 데이터 신규 서버 정책·설계](backend-migration/09-migration-decisions.md): 기존 자료 승계 없음·현재 개발/베타 전 전체 초기화/베타→운영 자료 보존 정책 확정. 10 서버 구조·11 인증/권한·12 첫 구현 패키지 연결. endpoint/DTO/SQL 최종 계약은 별도 backend 저장소가 소유한다.

- [백엔드 이전 분석 문서 지도](backend-migration/00-overview.md): dev e24baab 기준 Firebase 호출 전수·Firestore 모델·인증/권한·구독·화면·API 기능 요구·위험·단계 계획 9문서. 분석/문서화 전용이며 서버 endpoint/SQL schema·운영 데이터/배포 상태를 확정하지 않는다.

## 기존 서비스 레거시

- [기존 문서 보관 지도](../legacy/firebase/README.md): 전용 문서 이동 및 혼합 문서 발췌 목록.
- [문서·항목 출처 대장](../legacy/firebase/PROVENANCE.md): 원본 파일·절·행 범위와 내용 hash.
- [링크 정정 기록](../legacy/firebase/LINK_REPAIRS.md): 이동 경로와 기존 상대경로 정정.

보관 자료는 과거 기능·구현 근거다. 새 서버의 실행 기준은 위 백엔드 문서이며 이번에 작성한 backend-migration 파일은 이동하지 않았다.

## 이번 변경과 테스트 안내

- [현재 다음 작업](project/NEXT_WORK.md): 현재 환경·개발자료로 개발 계속. 기존 관리/인증 전환 연결 후 실제 소유 조건과 연동 확인 순서. 기본 flag OFF.
- [파일별 테스트 전환 대장](project/TEST_TRANSITION_INVENTORY.md): Firebase 테스트 제거 근거와 공통 검증 보존·안정화 결과. 제거 구간1134테스트와 조회 연결1159테스트 통과, 조회 사용자1·2·4 통과. 등록자료가 필요한3번은 후속 인수; 상세 이력은 DEV_LOG.



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
