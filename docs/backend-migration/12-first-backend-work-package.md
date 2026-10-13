# 첫 백엔드 구현 작업 패키지 제안

상태: 실행 준비용 설계안. 이번 작업에서 backend 저장소·코드·DB·API·Issues를 생성하지 않았다. [09 결정](09-migration-decisions.md), [10 구조](10-server-architecture.md), [11 인증](11-auth-and-access-design.md)을 입력으로 사용한다.

## 첫 완료 단위: 신규 인증과 공개 읽기 기반

사용자는 guest로 실행·공개 모집 조회를 할 수 있다. 소셜 로그인 성공 후 신규 user/session이 생성되고, protected action은 서버에서 거절하거나 허용한다. 빈 DB에서 시작하며 테스트 fixture는 격리된 환경에만 만든다. 파티·그룹 쓰기 전체를 첫 단위에 넣지 않는다.

## 구현 전 입력과 결정

- 별도 백엔드 저장소의 위치·이름과 실행 환경. Flutter 저장소에 서버 코드를 만들지 않는다.
- 첫 실제 OAuth 제공자 1개의 등록, client/redirect/domain과 test credential 접근. 다른 제공자는 adapter 확장 요구로 남기고 미통합을 명시한다.
- Access/Refresh/session의 수명·회전·재사용 감지·복구·동시 기기 정책, public 최소 필드, error/version 계약.
- PostgreSQL 논리·물리 모델과 Alembic 최초 revision. 실제 SQL·API 계약은 backend 저장소에서 설계한다.
- Flutter의 guest bootstrap/session, local cache·journal 격리와 로그인 후 재개 방식은 별도 frontend 작업이다. 기존 local data 삭제는 승인되지 않았다.

## 포함

1. 모듈형 모놀리스 기본 구조, Compose의 API/PostgreSQL 개발 환경, 설정·secret·health/readiness와 pytest DB fixture 전략.
2. backend OpenAPI 원본과 별도 WS 계약의 소유·version 원칙. identity/session·public/private error를 검토한 schema로 문서화한다.
3. 제공자 adapter 1개의 실제 인증, 검증한 identity의 신규 user 중복 생성 방지, 로그인·Refresh·현재 session 로그아웃·내 session 조회.
4. guest 사용자 row를 만들지 않는 공개 모집 목록·상세 조회. 새 production DB의 빈 결과, filter/페이지, field allowlist와 private 거절을 검증한다. 공개 읽기에 필요한 최소 모델이 없으면 backend에서 먼저 설계한다.
5. actor/인가의 공통 경계와 로그의 credential 제거. 일반 사용자의 operator self-promotion을 거절한다. 실제 첫 operator 부여는 별도 운영 단계다.
6. 확정 계약을 Flutter/Swift가 참조할 수 있는 인계 artifact와 검증 결과.

## 제외

기존 Firebase UID/user/data import·연결·복구, Firebase 삭제, 기존 client 코드 수정, 세 제공자 모두의 통합 완료 주장, 파티·그룹 전체 명령, game proof 본 구현, S3/FCM/Redis와 실제 production 배포를 제외한다. WS 전체 delivery 구현은 후속 작업이며 첫 단위에서는 인증·권한 요구를 계약으로 인계한다.

## 완료 조건과 pytest 행위 검증

| 범위 | 완료 조건 |
|---|---|
| guest | 공개 읽기 가능. guest user/session/profile/사용자 receipt를 생성하지 않음. 미인증 protected 요청 거절 |
| provider 인증 | 무효 code/state/issuer/audience 거절. 동일 identity의 동시 첫 로그인에서 user 1개. 로그인 취소시 user 없음 |
| 자체 session | Access 검증, Refresh 원자 회전·재사용 감지·만료, 응답 유실·동시 갱신, 현재 로그아웃·폐기 정책 검증 |
| principal | client actor/role 위조, 정지 user/session, 타인 자원 접근 거절. 다른 기기 session은 정책대로 격리 |
| public projection | private group·신청·소유 차수·OAuth·운영 필드 노출 없음. filter/정렬/페이지와 빈 DB 정상 응답 |
| 운영 기반 | Alembic으로 빈 DB 재현, health/readiness와 secret 없는 log, 격리된 pytest·rollback 및 미확인 항목 표시 |
| 계약 | backend OpenAPI 검증·version·참조 위치 확정, 후속 WS 메시지·권한 회수 요구 명시 |

구현을 따라 적은 테스트보다 허용·거절, race, 중도 실패와 최소 공개 필드를 검증한다. OAuth mock은 제공자 등록과 실제 callback 성공을 대체하지 않는다. 첫 제공자의 접속 인수는 별도로 확인한다. Flutter 정상 UI는 사용자 실기기 확인 목록으로 인계한다.

## 후속 기능 순서

서버 game proof/Character 소유권 → 파티 생성·신청·참가 → 그룹·범위·역할 → 주간 완료·반복·준비·전환·정리 → event/WS replay → manual/operator → frontend adapters → 신규 서비스 전환·SDK 제거 순서를 제안한다. 그룹 최소 자격 기능은 파티의 그룹 명령보다 먼저 필요하다. 강한 의존성이 있는 작은 기능 단위별로 구현하고 전체를 한 번에 변경하지 않는다.

구버전 Firebase와 신규 서버는 별도 데이터 세계다. 신규 가입·계정 재인증과 local stale ID 격리가 끝나기 전 frontend를 새 서버로 전환하지 않는다. 구서비스 종료·삭제와 신규 production 배포는 별도 운영 작업이다.

## 백엔드 Codex 인계 문구

> LostParty는 신규 FastAPI/PostgreSQL 서버를 빈 DB로 시작합니다. 기존 Firebase 사용자·데이터 이관, UID 연결과 복구를 구현하지 않습니다. Flutter 저장소 docs/backend-migration/09~12와 00~06의 실제 기능 근거를 검토하고, 첫 단위인 신규 소셜 인증·자체 session·guest 공개 조회 기반을 백엔드 저장소에서 설계하세요. backend가 OpenAPI/WS 계약 원본과 SQL/Alembic 설계를 소유합니다. guest UID·회원·사용자별 서버 자료를 만들지 말고 protected command는 서버에서 인가하세요. 먼저 제공자 등록·redirect, token 정책, public 필드와 실제 DB/API 계약을 정리한 뒤 구현 범위와 검증 게이트를 확정하세요. Flutter/Firebase 코드·운영 데이터·배포는 변경하지 않으며 기존 서비스 삭제·이관·마이크로서비스·Redis는 제외합니다.

이 문구는 인계 자료다. 다른 chat에 메시지를 보내거나 새 저장소/task를 생성하지 않았다. 실제 backend 구현 시 사용자의 작업 대상과 승인 범위를 확인한다.
