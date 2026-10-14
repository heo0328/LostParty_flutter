# 내 계정 Backend 대응 Flutter 작업 계획

2026-10-14. 사용자 지시: Backend가 합의한 #3 작업을 진행·인계하면 그 계약에 대응하는 로컬 Flutter 작업을 진행한다. 이번 기록은 후속 구현 순서를 확정하며 임의 DTO/API 구현을 시작하지 않는다.

## 기준과 현 상태

- [Backend #3](https://github.com/heo0328/lostparty-backend/issues/3), [추가 회신](https://github.com/heo0328/lostparty-backend/issues/3#issuecomment-6159847616), [서버 작업 지시서](13-my-account-backend-phase1-request.md).
- 조회 시 Backend 원격 dev OpenAPI는 기존 인증6API와 health만 제공한다. #3의 확정 REST/DTO/오류/구현 SHA는 미인계다. 정책 합의와 실제 사용 가능한 서버 계약을 구분한다.
- Flutter 원래 checkout은 docs/my-account-backend-phase1, 문서·별도 실험 미커밋이다. Firebase 제거는 별도 refactor/firebase-removal 작업 트리에서 구현/자동 검증 완료·미커밋/dev 미반영이다. 신규 APK 로그인·재실행·로그아웃·로컬 캐릭터 표시는 사용자 통과 확인. 새 기능은 제거 결과를 기반으로 하며 구 Firebase 코드를 다시 연결하지 않는다.

## 단계와 첫 승인 작업 그룹

| 구간 | 목적 | 완료 기준 |
|---|---|---|
| 1. 계약 인수·읽기 연결 | 회원별 등록 목록·캐릭터·전체 설정 조회, 상태 표시 | 원본 OpenAPI/구현 SHA 고정, Repository/DI 연결, 회원 전환/부분 페이지/장애 경계 보호 |
| 2. 등록 관리 | 검색 preview·본/부계정 등록·label/본계정 수정·등록 제거·refresh | 멱등 key/expected version, 응답 유실 복구, 로컬 자료 보존 |
| 3. 서버 장비 인증 | challenge 시작/상태/confirm/cancel, TTL/불일치/인증·소유 상태 | 서버 결과만 인증 기준, 종료/유실/취소·이전 보류 조건 소비 |
| 4. 활동·대표 설정 | 최종 전체 선택과 대표 원자 저장, cooldown·재구성 | 세 expected 값, 전체 페이지 일관성, 저장 실패·409 보존 |

한 번에 진행할 첫 구현 그룹은 1번이다. 나머지 그룹은 순서를 기록하되 독립 구현/검증 단위로 진행한다. Backend 모든 업무 기능의 완성을 기다릴 필요는 없으며, 첫 그룹의 안정된 조회 계약과 구현 SHA를 먼저 인계하면 해당 그룹부터 연결할 수 있다.

## 첫 그룹 구현 설계

1. 서버가 소유한 정확한 경로·DTO·nullable/enum·UTC 날짜·pagination·에러/request_id/Retry-After를 원본 계약으로 고정한다. 로컬 자료형이나 폐기 Firestore map을 새 서버 wire schema로 사용하지 않는다.
2. 기존 AuthSessionController의 accessToken/refresh/로그아웃 정책을 재사용하는 private HTTP 경계를 연결한다. 업무403 OWNERSHIP_REQUIRED를 세션 만료로 오인해 로그아웃하지 않는다. 401의 갱신/재전송 가능 코드·횟수는 실제 계약에 맞추고, 쓰기 동작의 무조건 retry 정책을 만들지 않는다.
3. 회원별 서버 등록 Repository와 응답 모델을 로컬 AccountRepository와 분리한다. 로컬 정수 PK/과거 server ID와 registration/canonical/character UUID를 구분한다. 첫 단계에서는 local DB schema/자료를 일괄 갱신하거나 서버 소유 매핑을 추론하지 않는다.
4. BackendApp의 실제 Router/DI에서 신규 Repository를 주입한다. 비로그인 로컬 계정·캐릭터·빌드 화면을 유지하고 private GET을 보내지 않는다. 로그인 후 서버 등록 영역을 조회한다. 최초 서버 빈 목록과 기존 로컬 캐릭터 표시는 동시에 정상이며 로컬 자료를 지우지 않는다.
5. 등록별 캐릭터와 페이지 독립 settings를 읽는다. 전체 페이지 수집 후 roster_revision/settings_version/ownership_revision이 모두 같고 selection_complete=true일 때만 관리 draft를 만들 수 있다. 중간 페이지 실패/순환 cursor/중복·초과·잘못된 UUID/응답 형식은 정상 빈 목록으로 바꾸지 않는다. CURSOR_STALE은 혼합 상태를 폐기하고 명시 재조회로 처리한다.
6. unconfigured/ownership_lost/needs_reconfiguration 및 confirmed/suspect/missing을 분리해 표시한다. 타인 설정을 사용하지 않으며 suspect/missing은 새 활동 자격을 만들지 않는다. 첫 그룹에서는 조회 상태만 반영하고 서버 설정을 자동 저장하지 않는다.
7. 서버 private 조회 상태는 Base URL origin·회원·세션 세대별로 격리한다. 로그아웃/계정 전환/재로그인 때 private 상태를 지우고 이전 요청의 늦은 응답을 무시한다. 같은 회원 ID로 재로그인해도 이전 세션 응답을 현재 세션으로 인정하지 않는다. 로컬 캐릭터/빌드/API 키는 유지한다.

## 다음 그룹에서 지킬 합의

- 쓰기는 actor+operation scope의 UUIDv4 Idempotency-Key와 고정 payload를 사용한다. timeout/409을 새 key의 자동 쓰기로 대체하지 않는다. 성공 재응답은 결과 복구이며 현재 상태는 GET으로 확인한다.
- 활동 저장은 계정별 전체 집합·대표·expected_settings_version/expected_ownership_revision/expected_roster_revision을 한 요청으로 전송한다. owned_character_ids와 verified 플래그를 서버 권한 증거로 보내지 않는다.
- 대표 최초 seed는 cooldown 없음, 실제 변경5분·누락 대표 복구 우회 없음. 오류 시 전체 선택·대표·서버 version을 성공 상태로 확정하지 않는다.
- provider 근거 확보 전 live 감소 자동 missing 확정/불완전 roster 기반 소유권 이전은 보류한다. 서버 key 준비와 사용자 인게임 장비 조작은 Backend/사용자의 후속 실제 인수다.

## 회귀 보호·검증·제외

보호: Google 로그인/유지 선택별 재실행/로그아웃, 비로그인 로컬 계정·캐릭터·빌드/키, debug URL·로딩 배경, origin별 저장. 서버 빈/장애/재구성 상태를 로컬 삭제나 guest 회원 생성으로 처리하지 않는다.

자동 검증은 guest 무요청, 계정/세션 전환의 늦은 응답, pagination revision 변경·실패·불완전 설정, private 오류 분류에 집중한다. Router/DI 변경 후 최종 전체 flutter test/analyze 여부를 영향에 맞춰 판단한다. 이후 사용자가 새 API와 로컬 기능을 기기에서 확인한다. 문서 준비만 수행한 현재는 Flutter 검증을 반복하지 않는다.

제외: 기존 데이터 이관/삭제, 원격 Google/Firebase 설정 삭제, 모집/파티/그룹/주간/운영 UI, 자동 소유권 병합, Backend DB/API 구현·배포, 사용자 기기 설치/조작. commit/dev 통합/push는 별도 Git 요청 범위에 따라 수행한다.

## 인계·인수 갱신 (2026-10-14)

Backend 구현254cb5d/인계406004e의 작업브랜치 게시와 원본 계약을 확인하고 Flutter 첫 조회 그룹을 실제 연결했다. 고정 계약/현재 흐름은 [조회 계약16](16-account-read-flutter-contract.md), 다음 등록 관리는 NEXT_WORK를 따른다. 사용자1·2·4 통과, 3번은 등록 자료 생성 후 확인한다. 위 계약 미인계/미연결 문구는 초기 계획·준비 당시 기록이며 현재 대기 사유가 아니다.
