# 신규 서버 시작 정책과 결정 기록

작성: 2026-10-13. 기준 코드: dev e24baab. 상태: **문서 설계안 v0.1**. 사용자 확정 정책과 에이전트 제안을 구분한다. [10 서버 구조](10-server-architecture.md), [11 인증·권한](11-auth-and-access-design.md), [12 첫 작업](12-first-backend-work-package.md)을 함께 읽는다.

## D01 기존 사용자·데이터 이관 없음 — 사용자 확정

FastAPI/PostgreSQL 서버는 빈 상태로 시작한다. Firebase UID/Player·게임 계정/Character·파티·그룹·신청·완료/이력·알림·운영자 배정을 import하거나 새 계정에 연결하지 않는다. 사용자는 소셜 로그인으로 신규 계정을 만들고 게임 원정대 인증과 그룹/파티 활동을 다시 시작한다.

기존 사용자 매핑·credential 증명·기기 분실 복구·고아 문서 census·변환 도구·dual-write·데이터 이전 리허설은 이번 서버 개발 완료 조건에서 제외한다. 소스 분석00~05는 기존 기능의 동작과 위험을 이해하는 근거이며 export/import 지시서가 아니다.

**실행 경계:** 이 정책은 기존 Firebase 프로젝트/Auth/Firestore/백업의 실제 삭제 승인이 아니다. 빈 신규 DB를 준비하는 실행도 backend 구현 단계에서 한다. 파괴적인 초기화·배포·운영 서비스 종료는 별도 시점에 대상과 결과를 검토해 실행한다. 이번 작업은 문서만 수정한다.

## D02 기술과 계약 소유 — 사용자 확정

Flutter 및 향후 Swift/SwiftUI, Python3/FastAPI/Pydanticv2/SQLAlchemy2/Alembic/PostgreSQL/pytest, REST+WebSocket, 기능별 모듈형 모놀리스다. Windows11/WSL2 Ubuntu/Docker Desktop/Compose 개발, Caddy와 Lightsail Linux amd64 운영을 전제로 한다. S3/FCM은 필요 시 선택한다. 초기 Cognito/Lambda/API Gateway/RDS/Redis/Kafka/Kubernetes/마이크로서비스는 제외한다.

서버·프론트 저장소를 분리한다. backend 저장소가 OpenAPI와 WS 계약의 원본을 관리하고 frontend는 승인된 version을 참조한다. GitHub Issue 후보는06에만 작성했다. 이번 문서에서 endpoint/DTO/SQL table·물리 key/DDL를 확정하거나 생성하지 않는다. 여기의 논리 개념은 backend 설계의 입력이다.

## D03 비로그인과 회원 생성 — 사용자 확정

비로그인은 실행·허용된 공개 읽기만 수행하며 guest UID/Player/회원/사용자별 서버 데이터를 만들지 않는다. 식별이 필요한 액션은 로그인 알럿을 표시하고 서버도 미인증 요청을 거절한다. Firebase Anonymous Auth와 anonymous account 대체 시스템은 만들지 않는다.

로그인 성공 후에만 신규 내부 사용자와 제공자 identity를 원자적으로 만든다. 반복/동시 첫 로그인은 같은 검증 identity에 새 사용자를 중복 생성하지 않아야 한다. OAuth 요청의 state/nonce/PKCE 거래 정보는 인증 프로토콜의 짧은 수명 검증 자료이며 guest 회원·관심/이력 자료가 아니다. 비로그인 행동 추적/guest profile로 확장하지 않는다.

## D04 공개 읽기 경계 — 설계 제안

| 행위 | 제안 기본안 | 미확정/조건 |
|---|---|---|
| 공개 모집 목록·필터/페이지 | guest 허용 | title/raid/difficulty/schedule/모집상태·자리수·참여조건 등 최소 모집 정보 |
| 공개 모집 상세 | guest 허용 | 위 상세와 슬롯의 role/class,필요한 Character 표시 Snapshot. 이름 노출 범위는 backend 계약 승인시 확인 |
| 그룹 검색/공개 요약 | guest 허용 후보 | 그룹명·대표 표시·인원 등 공개 요약에 한정. private 요청·member 전체 접근 없음 |
| 본인 그룹·내 현황·신청·완료 | 로그인 필요 | 내부 principal에 따른 자기 scope |
| 생성/신청/참가·게임 인증·운영 액션 | 로그인 필요 | 로그인 외 각 role/소유권·상태 검증 추가 |

public 응답은 allowlist로 별도 구성하고 전체 entity serialization을 사용하지 않는다. 이메일/OAuth subject/Auth UID/token·내부 운영 역할·신청자/투표·소유권 차수·차단/분쟁·private group 관계/이벤트 audience는 공개에서 제외하는 설계다. hidden/group 모집은 public list/detail에서 거절한다. internal ID의 공개 표현과 Character 이름 정책은 명세에서 결정한다.

로그인 후 자동 쓰기 재실행은 기본적으로 하지 않는 설계다. 같은 화면으로 복귀해 사용자가 다시 확인하고, 재실행 시 최신 상태를 다시 읽는다. 이 문장은 사용자 최종 승인 전 제안이며 로그인 알럿 자체는 확정 요구다.

## D05 로컬 데이터 — 파괴적 초기화 미승인, 격리 제안

기존 Drift 계정·빌드·filter·읽음 설정을 삭제할지 유지할지는 사용자 결정이 남아 있다. 서버 이관 없음과 기기 데이터 삭제는 별개다. 이번 문서의 안전한 전환 기본안은 로컬 원본 보존 + server environment/principal 구분이다.

Firebase server IDs/주간 상태/party history receipts/group 관계/cleanup journal은 새 서버에 authoritative 데이터로 보내지 않는다. 과거 journal을 새 서버로 자동 replay하지 않는다. 로그인한 신규 계정의 과거 서버 ID가 아닌 fresh 조회/게임 인증으로 새 관계를 만든다. build/local preference를 재사용할 경우 표시/입력 후보 자료로만 쓰고 ownership·완료·운영 권한으로 인정하지 않는다.

local namespace 변경/보관/archive/삭제 구현·앱 schema migration은 frontend 작업에서 정책 결정 후 작성한다. 현재 `raid_cycle_schedule.dart` 등 앱 코드를 수정하지 않는다.

## D06 신규 서버 기본 설계안

- 내부 사용자 ID와 소셜 identity,게임 원정대/Character identity는 분리한다. 표시명·email·원정대명으로 사용자 자동 병합하지 않는다.
- 게임 소유권은 서버 challenge로 재인증한다. 기존 Firebase 소유권은 인정하지 않는다. 새 서버에서 발생하는 이후 소유권 이전은 소유 차수를 증가시켜 과거 참가/완료/권한과 구분한다.
- 운영자는 기존 Firebase assignment를 승계하지 않는다. 첫 운영자 부여는 별도 운영 절차로 검증한 신규 계정에 수행하며 공개 API self-promotion을 두지 않는다.
- 파티/그룹/주간 상태는 server authoritative 명령이다. role·actor·count·event audience를 클라이언트가 확정해 보내지 않는다. 기존8인/50인/50그룹과 주차 규칙은 기능 기준으로 유지하는 설계이며 변경하려면 별도 제품 결정이다.
- access/refresh·세션·public fields/로컬 설정 정책의 제안과 미결정은11/12에서 관리한다. 설계 문서 작성이 배포·코드 구현 승인이 아니다.

## 남은 결정과 backend 조사 항목

| ID | 결정/확인 필요 | 이번 설계의 취급 |
|---|---|---|
| O01 | Discord/Google/Apple 제공자 등록·우선순위·모바일 redirect/client registration | 세 제공자 adapter interface를 설계하되 첫 실제 통합은 등록 가능한 제공자1개. 전부 검증 전 완료 주장 금지 |
| O02 | public Character 이름/그룹 공개 요약 범위 | D04의 최소 공개 제안,확정 API 계약 전에 검토 |
| O03 | 기존 로컬 build/계정/설정 유지/보관/삭제 | 삭제 없이 보존·격리 제안,실제 초기화 없음 |
| O04 | Lost Ark API credential 운영 | 현재 local 사용자JWT를 유지할지 server credential로 전환할지 미결정. 비밀을 공개 client/server 로그에 복사하지 않음 |
| O05 | 신규 사용자 탈퇴/정지·데이터 수명,세션수/TTL |11 제안 기준을 backend에서 검토. 과거 Firebase 보존 의무를 신규 서비스 retention으로 혼합하지 않음 |
| O06 | dev 기준과 별도 branch 기능 채택 | 현재 dev 계약을 기준. 중단 branch 자동 merge/채택 없음 |
| O07 | 신규 운영 전환 시 구버전 종료·Firebase 실제 삭제 | 운영 시점 별도 승인. 신구 사용자는 별도 세계이며 데이터 rollback/승계 약속 없음 |

## 완료·비실행 기록

초기화 정책·권한 경계·서버 module/인증 흐름·첫 구현 게이트를 문서화한다. 링크/명칭·이전 이관 제안 제거·diff 및 비문서 SHA를 확인한다. 서버/API/SQL·Firebase 삭제·운영 조회/배포·실기기·실제 Issues 생성 없음. 문서 branch는 유지하고 이번 요청에 commit/push/merge는 포함하지 않는다.
