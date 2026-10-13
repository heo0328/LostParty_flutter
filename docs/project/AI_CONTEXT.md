# AI CONTEXT (2026)

## 최신 — 기존 서비스 문서 보관 정리 (2026-10-13)

사용자 요청으로 Firebase 전용 문서26개를 루트 legacy/firebase/docs에 이동하고 혼합 문서28개의 관련 항목을 extracted에 출처와 함께 분리했다. 일부 지침/과거 실행 문맥은 additional 발췌로 이어진다. 로컬 Notion 발췌는 private 추적 제외를 유지한다. [보관 지도](../../legacy/firebase/README.md)와 [출처 대장](../../legacy/firebase/PROVENANCE.md)을 따른다. 이번 신규 서버 backend-migration13문서는 내용·위치 모두 유지했고 앱/Rules/설정·운영 데이터/배포 변경은 없다. 현재 문서 브랜치 미커밋·dev 미반영·push/merge 없음.

> 기존 서비스 전용 항목은 [원문·출처 기록](../../legacy/firebase/extracted/docs/project/AI_CONTEXT.md)으로 분리했다. 남은 제품/협업 문맥의 신규 서버 적용 여부는 별도 설계에서 판단한다.

## 최신 — 빈 데이터 신규 서버 설계 (2026-10-13)

사용자가 기존 Firebase 사용자·데이터 이관 없이 새 서버를 빈 상태로 시작한다고 확정했다. [09 결정 기록](../backend-migration/09-migration-decisions.md),10 모듈형 모놀리스/원자명령,11 신규 OAuth·자체session/인가,12 첫backend 작업 패키지를 작성한다. 기존9분석문서의linking/export/import 계획을 제거·재분류했다. 기존Firebase 실제삭제/Flutter로컬파괴적초기화·backend/API/DDL구현·배포는미실행이다. user/identity/gameownership 분리·guest회원없음은기준이며publicfield/token수명/로컬보존/제공자등록은제안/미확정이다. 현재docs/backend-migration-analysis 유지·문서미커밋/push·dev미반영. 상세는09~12/NEXT_WORK를따른다.

## 현재 — 백엔드 이전 사전 분석 문서 (2026-10-13)

dev e24baab에서 docs/backend-migration-analysis를 분기하여 [9문서](../backend-migration/00-overview.md)를 작성한다. 실제 Firebase62파일·snapshot21호출·복합index16선언과 Router/Writer/Rules를 코드 근거로 조사한다. Flutter/향후 Swift + FastAPI/PostgreSQL, guest UID/회원 없는 공개 읽기·OAuth 자체 token은 이번 사용자 목표 정책이며 아직 구현되지 않았다. 중단한 fix/party-participation-consistency f3836dd의 변경은 포함하지 않는다. 원격 Firebase/데이터/배포 미조회·미변경, 앱 코드/설정 변경 없음. API/SQL 구현과 실제 Issues 생성·커밋/push/merge는 제외한다. 아래 운영 인수/재설계 문구는 이전 이력이다. 상세/미확인 범위는 분석 문서와 NEXT_WORK를 따른다.

## 현재 제품 축

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/AI_CONTEXT.md#source-0009)로 이동했다.

## 차후 제품 후보

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/AI_CONTEXT.md#source-0010)로 이동했다.

## 문서와 운영 주의

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/AI_CONTEXT.md#source-0011)로 이동했다.


기존 실행/상태 이력의 추가 발췌: [출처 기록](../../legacy/firebase/extracted/additional/docs/project/AI_CONTEXT.md).
# 최신 Git 통합 상태 (2026-10-13)

사용자 후속 지시로 신규 서버 분석·설계와 기존 자료 보관 문서를 커밋하여 dev에 통합하고 원격 dev에 반영한다. 아래 미커밋·dev 미반영 표기는 이전 단계의 상태 기록이다. 앱 코드·설정·배포 변경은 포함하지 않으며 기존 로컬 실험·백업은 보존한다.
