# LostParty 백엔드 이전 사전 분석

분석일: 2026-10-13 KST. 기준: `dev`/`e24baab1e62c3d79cf2c9beefffedf7741e31c8a`, 문서 브랜치 `docs/backend-migration-analysis`.

## 최신 정책 — 신규 서버 빈 상태 시작

사용자 확정: 기존 Firebase 사용자·데이터는 마이그레이션하지 않는다. 소셜 로그인으로 신규 계정을 만들고 게임 소유권·파티·그룹 활동도 새로 시작한다. 기존 UID linking/recovery·export/import·이관 실사는 구현 범위에서 제외한다. 실제 Firebase 삭제·기기 데이터 초기화는 별도 실행이며 이번 작업에서 하지 않았다.

신규 설계는 [09 결정 기록](09-migration-decisions.md), [10 서버 구조](10-server-architecture.md), [11 인증·권한](11-auth-and-access-design.md), [12 첫 backend 작업](12-first-backend-work-package.md)을 우선한다. 00~05는 기존 dev의 기능/의존 분석,06은 기능 요구,07~08은 새 정책에 맞춘 위험·개발 계획이다. endpoint/DTO/SQL 물리 구조는 계속 backend 저장소에서 확정한다.

## 읽는 순서와 증거 수준

| 문서 | 용도 |
|---|---|
| [01 Firebase 목록](01-firebase-inventory.md) | SDK·호출 위치 전수 색인, 실제 연결과 잔존 구현 구분 |
| [02 데이터 모델](02-firestore-data-model.md) | 경로·키·필드·자료형·참조·쿼리·인덱스 |
| [03 인증과 권한](03-auth-and-permissions.md) | 현재 인증과 목표 정책, 서버에서 강제할 경계 |
| [04 실시간 구독](04-realtime-subscriptions.md) | 구독별 대상·소비자·수명·오류와 갱신 |
| [05 화면 흐름](05-screen-data-flows.md) | Router → 화면 → 서비스/Repository → 저장소 |
| [06 API 요구사항](06-api-requirements.md) | 향후 GitHub Issues에 등록할 기능 요구사항 |
| [07 위험](07-migration-risks.md) | 계정 연결·원자성·캐시·미확인 데이터와 결정 목록 |
| [08 이전 계획](08-migration-plan.md) | 단계별 입력·산출·완료 게이트 |

문서의 **확인**은 현재 checkout의 소스·설정에 근거한다. **목표 정책**은 사용자의 이번 지시로 확정됐지만 구현되지 않았다. **제안/추정**은 향후 설계 후보이며 **미확인**은 운영 자료 또는 결정이 필요하다. Dart 호출은 실행 결과의 증명이 아니다. 코드 주석·과거 문서보다 실제 Router/DI·Writer·Mapper·Rules를 우선 대조했다. append된 전수 색인은 정적 추출 자료로, 호출 가능성과 운영 사용량을 확정하지 않는다.

## 확인된 현재 시스템

Flutter/Dart → Firebase Core 초기화 → Firebase 익명 Auth → `authBindings`/`players` Transaction → `PlayerSession` → Router의 Firebase Repository 연결이다. 공개 모집을 보여줄 때도 이 bootstrap을 먼저 거친다. 근거: [main.dart](../../lib/main.dart), [initializeAppServices](../../lib/app/bootstrap/app_services_initializer.dart), [createAppRouter](../../lib/app/router/app_router.dart).

Firestore는 파티·그룹·소유권·사용자·수동 인증의 서버 공유 상태다. 클라이언트가 Transaction/Batch의 쓰기 계획을 만들고 Rules가 auth binding, ownership, role, revision, 원자 갱신을 검증한다. 별도 상시 FastAPI 서버 구현은 현재 기준에 없다. SDK 직접 호출은 Repository에 집중되지만 일부 화면이 Firebase 상태·Timestamp를 직접 참조하고, Domain과 로컬 journal에도 SDK 타입 연결이 남는다.

로컬 Drift는 게임 계정·캐릭터·빌드 원본, UI 설정, 파티 이력과 알림 receipt를 저장한다. `SecureApiTokenStore`의 Lost Ark API JWT는 게임 API용으로 앱 로그인 token과 다르다. `CompletedCleanupJournal`은 확정한 정리 요청의 재시도 자료를 secure storage에 저장한다. 이 데이터는 Firestore export만으로 복구할 수 없다.

Lost Ark API는 Dio로 Flutter에서 직접 조회한다. `LocalGameAccountVerificationGateway`는 메모리 challenge와 장비 관찰로 검증하고 Firestore 소유권을 기록한다. 신규 서버에서는 이 신뢰 경계를 다시 설계해야 한다. 앱 로그인과 게임 원정대 소유 증명은 서로 다른 인증이다.

## 확정된 목표와 이번 제외

| 영역 | 사용자 확정 기준 |
|---|---|
| 클라이언트 | Flutter/Dart, 향후 Swift/SwiftUI |
| 서버 | Python 3, FastAPI, Pydantic v2, SQLAlchemy 2, Alembic, 기능별 모듈형 모놀리스 |
| 데이터·통신·검증 | PostgreSQL, REST + WebSocket, 서버 권한 검증 + DB 제약, pytest |
| 인증 | Discord/Google/Apple OAuth2 또는 OIDC, 자체 Access/Refresh Token |
| 비로그인 | 실행·공개 읽기 허용. 임시 UID/회원/사용자별 서버 데이터 생성 금지. 식별 필요 기능은 로그인 알럿 |
| 개발·운영 | Windows 11/WSL2 Ubuntu/Docker Desktop/Compose, Caddy, AWS Lightsail Linux amd64 |
| 조건부 | 파일 필요 시 S3, 푸시 필요 시 FCM 유지 |
| 초기 제외 | Cognito/Lambda/API Gateway/RDS/Redis/Kafka/Kubernetes/마이크로서비스 |

이 문서는 기능 요구사항과 서버에서 보장할 불변식을 인계한다. endpoint 이름·HTTP method·요청/응답 schema·SQL table/DDL·token 구체 수명·WebSocket message schema를 확정하지 않는다. GitHub Issues, DB/API, 배포를 생성하지 않았다. 미래 기술의 실제 버전 호환·OAuth 제공자 설정·인프라 용량은 별도 설계/검증 대상이다.

## 기준 브랜치의 의미

중단한 `fix/party-participation-consistency`의 `f3836dd`는 이번 기준에 포함하지 않는다. 따라서 `groups/{id}/raidListings` 복사 읽기/쓰기/backfill이 현재 조사 대상이며 L1의 복사 제거를 현재 구현으로 적지 않는다. 같은 이유로 후보 clock/주차 화면 보완과 역할 변경도 다른 브랜치의 결과를 현재 사실로 혼합하지 않는다.

기존 `AI_CONTEXT`의 “push/merge/dev 반영 없음”은 작성 시점 기록이다. 실제 Git 기준은 이미 dev에 통합된 e24baab이다. 이번 문서가 실행 상태의 최신 구분을 제공하며 과거 이력은 삭제하지 않는다. 시작 시 `raid_cycle_schedule.dart`는 Git modified 표시가 있었으나 내용 diff는 없었고 기본값은 KST 수요일06시였다. 기존 미추적 실험·백업은 보존했다.

## 조사 한계와 검증

운영 Firestore/Auth/Rules Release/인덱스를 조회하지 않았다. 문서 수, 실제 schema 혼재, Auth 제공자 구성, 고아 참조, 활성 Rules와 소스 일치, 비용/트래픽은 미확인이다. 로컬 `firebase.json`/`.firebaserc`가 `lost-party`를 가리킨다는 사실만 확인했다. Functions/Storage/FCM은 현재 앱 SDK 사용이 없는 것과 운영 서비스 부재를 구분한다.

검증은 전수 검색, Router 연결 대조, 문서 근거/링크와 명칭 검사, `git diff --check`, 문서 외 추적 파일 SHA 불변 확인이다. 문서 전용이므로 Flutter 테스트/빌드·Emulator·실기기·배포를 실행하지 않았다. 실제 런타임 회귀나 신규 API의 안전성을 검증한 것은 아니다.
