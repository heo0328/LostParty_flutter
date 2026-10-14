# Backend 작업 지시서 — 내 계정 탭 1차 복원

작성: 2026-10-14. 요청 출처: Flutter Codex / heo0328/LostParty_flutter.
대상: heo0328/lostparty-backend. 연계: https://github.com/heo0328/lostparty-backend/issues/2
Flutter 근거 커밋: a52492f (dev). 인증 원본 계약: 519c609495966a3d785c6671c09bf513b28875a6.

## 1. 요청 목적·결과

사용자 지시로 Firebase 제거보다 **로그인 이후 내 계정 탭 복원**을 먼저 진행한다. 신규 FastAPI/PostgreSQL에 원정대/캐릭터 조회·등록, 서버 장비 인증·인증 상태, 앱 활동 캐릭터 선택·대표 저장의 최소 업무 기반을 구현해 Flutter에 계약을 인계해 달라. 실제 구현 요청이며 이 문서의 REST/테이블 이름은 제안이다. Backend가 검토 후 정확한 OpenAPI/DDL/오류/제약을 확정하고 구현한다.

완성할 사용자 흐름:

1. Google 로그인 → 내 등록 계정 조회(최초 회원은 빈 목록).
2. 캐릭터명 검색 → 최신 siblings 요약 확인 → 본/부계정 등록(미인증).
3. 등록 계정 또는 직접 입력 캐릭터 → 장비 인증 시작 → 인게임 조작 → 서버 확인 → 인증 여부·소유 상태 표시.
4. 인증 계정 전체 캐릭터 → 앱에서 사용할 캐릭터·대표 선택 → 한 번 저장 → 재조회/재로그인 후 같은 설정 확인.
5. 새 캐릭터/누락 캐릭터·타인으로 이전된 계정의 상태를 표시하며 로컬 빌드/캐릭터 자료는 파괴하지 않음.

현재 BackendApp은 로컬 AccountRepository/Drift·Lost Ark API만 주입하고 showServerOwnership=false다. 서버 원정대 인증/활동 Repository는 연결하지 않는다. Google 로그인 성공이 원정대 인증을 의미하지 않는다.

## 2. 확정 입력·보존/제외

- 기존 Firebase 사용자/UID/Player/서버 데이터/테스터 자료를 이관하거나 신규 계정에 연결하지 않는다. 신규 내부 user ID·자체 세션만 사용한다. guest 회원/사용자별 서버 자료를 만들지 않는다.
- 비로그인 기존 로컬 캐릭터 조회·빌드·설정은 계속 사용할 수 있다. 이번 private Backend API는 로그인 필요다. 공개 조회를 위해 private API를 guest에게 열지 않는다.
- 과거 로컬 serverGameAccountId/serverCharacterId·로컬 정수 PK는 인증 증거가 아니다. 로그인만으로 자동 연결하지 않는다. 사용자의 등록 동작과 신규 조회 결과로 새 매핑을 만든다.
- 기존 local build JSON·dealer/support 스냅샷·선호 역할·표시 순서/displayLimit·개인 설정은 로컬에 유지한다. 서버는 소유권/인증/활동·대표의 기준이다. 동기화 실패를 로컬 성공으로 위장하지 않는다.
- 포함: 내 계정 등록/정리, siblings summary, 인증, 활동·대표 설정, 재조회, 새/누락 Character 처리, 권한·경쟁·실패 검증.
- 제외: 파티/모집/그룹/주간 완료/알림/WS 구현, 운영자 수동 인증·분쟁 운영 UI, 빌드 상세 분석/전체 JSON 서버 저장·동기화, 회원탈퇴/정책페이지, 운영 배포, Firebase/OAuth 프로젝트 삭제. 이번에는 Flutter 기능 코드와 Firebase SDK를 변경하지 않는다.

## 3. 용어·식별자·신뢰 경계

- 게임 계정은 입력 캐릭터로 조회한 siblings 전체 단위다. 게임 서버별 원정대는 ServerName으로 구분해 표시할 수 있다. 전체 게임계정과 서버별 원정대의 소유 범위를 혼동하지 않는다.
- 앱 회원 user_id, 내 등록 registration_id, 인증 대상 game_account_id, character_id는 서로 구분한다. 제안은 서버 발급 UUID다. 등록은 본인 UI 관리 관계, 인증은 canonical 게임계정의 현재 소유 증명이다.
- 인증 전에는 canonical 계정/캐릭터 ID가 없을 수 있다. 미인증 조회에는 registration_id/서버명/캐릭터명 및 preview 정보를 주고 미인증 ID를 권한있는 character_id처럼 사용하지 않는다.
- 외부 API가 영속 계정/캐릭터 식별자를 제공한다고 가정하지 않는다. 서버명+캐릭터명 관찰키/검증된 siblings 중첩으로 기존 canonical ID 재사용 여부를 검증한다. 이미 서로 다른 canonical 계정과 중첩하면 조용히 병합/이전하지 말고 IDENTITY_CONFLICT로 거절한다.
- 이름 변경 자동 추적/소유권 추론은 제외한다. 누락된 이름을 신규 캐릭터와 자동 병합하지 않는다. provider 실제 응답에서 지원되는 식별자·범위를 Backend가 근거와 함께 인계한다.
- 소유자·상태·대표 자격·revision·활동 자격은 서버가 판정한다. 요청의 user_id/owner_id/authUid/verified=true, 장비 snapshot/해제 슬롯/발생시각, 전체 owned_character_ids를 신뢰하지 않는다.

## 4. 필요한 논리 데이터 칼럼 (물리 테이블/DDL은 Backend 확정)

| 데이터 | 최소 필드·제약·수명 |
|---|---|
| 내 계정 등록 | id, user_id(FK), canonical_game_account_id(nullable), lookup_character_name, label, is_main, registration_status, version, created_at/updated_at. 같은 회원의 중복 등록을 제어하고 활성 본계정은 최대1개. 미인증 자료와 인증 소유관계를 구분 |
| 게임 계정·소유권 | id, status, active_owner_user_id(nullable), ownership_revision, verified_at, updated_at. current owner 단일성·검증 성공에만 소유 확정. 이전 이력은 별도 audit |
| canonical 캐릭터 | id, game_account_id, server_name, character_name, class_name, character_level, item_level, combat_power(nullable), roster_status(confirmed/missing), summary_fetched_at, version. 관찰 identity 키의 중복/소속 충돌 방지; nullable power를0으로 위조하지 않음 |
| 회원별 활동·대표 설정 | user_id, game_account_id, activity_character_ids(관계 테이블 권장), representative_character_id(nullable 초기값), configuration_state(unconfigured/configured), version, representative_changed_at/next_change_at. 기존 owner의 선택을 새 owner에게 승계하지 않음 |
| 장비 인증 challenge | id, actor_user_id, registration_id/source, lookup_character_name/server_name, canonical_candidate_id(nullable), ownership_revision_at_start, status, 서버 baseline6부위(type/name/grade), required_slots, 서버 siblings 기준, created_at/expires_at, attempt_count/last_checked_at, verified_at/result_reference, client_request_key. 비밀 baseline은 private 서버 저장; 응답에는 필요한 안내/상태만 |
| 소유권 이전 audit·요청 dedup | 이전/새 소유자·대상·ownership_revision·challenge/result·서버 시각, 요청 hash/result. 최소 필요한 감사자료만 보관하고 OAuth subject/email/token을 섞지 않음 |

summary/preview cache·challenge·dedup·audit의 보관/청소 주기와 pagination/최대 payload를 계약에 명시해 달라. 제안: preview/challenge는 만료 후 짧은 청소 유예, 미인증 등록은 사용자 삭제까지, 미사용 raw upstream JSON은 장기 저장하지 않음. 개발용 빈 DB migration만 준비하며 기존 데이터 import 없음.

## 5. API 작업 목록 — 경로는 제안

기존 /v1 인증6API와 Bearer principal을 재사용한다. 아래 추가 API는 모두 본인 scope다. JSON은 snake_case, UTC ISO8601, strict allowlist DTO, 기존 error{code,message,request_id} 형식을 확장한다.

| 기능 | 제안 API | 입력/결과·보장 |
|---|---|---|
| 검색 미리보기 | POST /v1/game-accounts/preview | character_name → siblings 요약·server_fetched_at·preview 표시. 읽기만 하며 소유권/활동/대표 생성 없음 |
| 내 등록 조회 | GET /v1/me/game-accounts | 등록 id/label/is_main, game_account_id(nullable), verification/ownership 상태, ownership_revision, representative summary, settings_version/configuration_state, character_count. 타인 회원정보는 반환하지 않음 |
| 등록 | POST /v1/me/game-accounts | lookup_character_name,label,is_main, 재전송 식별 → 서버 재조회 후 미인증 registration. preview/client summary를 인증자료로 저장하지 않음 |
| 등록 설정 | PATCH /v1/me/game-accounts/{registration_id} | label/is_main/expected_version. 본계정 전환을 원자 처리; ownership/verified/identity 필드 쓰기 금지 |
| 등록 제거 | DELETE /v1/me/game-accounts/{registration_id} | 조건부 version·재전송 보호. 자기 등록/활동 사용관계만 종료; canonical 캐릭터·로컬 빌드/DB를 파괴하지 않음. 소유권 포기/이전과 같은 API로 혼합하지 않음. 본계정 제거 후 처리 규칙 명시 |
| 캐릭터·설정 조회 | GET /v1/me/game-accounts/{registration_id}/characters | 요약·roster_status, ownership/verification, 활동 여부·대표·settings_version·ownership_revision·requires_configuration. 미인증 summary와 권한있는 UUID 구분. 목록 page/cursor·정렬 확정 |
| 원정대 갱신 | POST /v1/me/game-accounts/{registration_id}/refresh | 서버 siblings 재조회 → summary update/신규·누락 처리·부분실패·fetched_at. UI GET마다 전체 Armory 상세 호출 없음 |
| 인증 시작 | POST /v1/me/game-account-verifications | registration_id 또는 direct-input character_name + source·재전송 식별. 서버 fresh siblings+Armory로6부위 확인 후10분 challenge. 미완전 장착은 challenge 생성 안 함 |
| 인증 상태 | GET /v1/me/game-account-verifications/{challenge_id} | actor만 조회, pending/verified/expired/cancelled·remaining/required_slots·최종 결과 reference. baseline/raw upstream/private 다른 사용자 자료 없음 |
| 인증 확인 | POST /v1/me/game-account-verifications/{challenge_id}/confirm | 서버 Armory 재조회·판정 후 원자 소유/Character/상태 반영. 같은 challenge 성공 재호출은 같은 결과, 회원/계정/캐릭터 중복 없음 |
| 인증 취소 | DELETE /v1/me/game-account-verifications/{challenge_id} | 본인 pending 취소, 멱등. 만료/취소 후 confirm 거절. 인증 성공을 취소로 되돌리지 않음 |
| 활동·대표 저장 | PUT /v1/me/game-accounts/{registration_id}/character-settings | 최종 activity_character_ids, representative_character_id, expected_settings_version, expected_ownership_revision. 해당 계정 설정만 한 transaction에서 교체하고 다른 본/부계정 선택 보존 |

사용하는 request correlation/dedup header/body·키 형식·TTL·같은 키의 다른 payload409·응답유실 재조회 방법을 확정해 달라. 권장: actor+operation scope에 유일한 Idempotency-Key와 request hash; transport 재전송은 새 소유권 이전을 만들지 않음. secret/token을 URL·Issue·로그에 기록하지 않음.

응답은 즉시 내 계정 UI 갱신에 충분한 확정 ID·status/version/ownership_revision·representative/활동 설정·server_fetched_at·next_change_at를 포함하거나 이를 얻을 재조회 API를 명시한다. 등록/소유권/활동 상태를 하나의 boolean verified로 축약하지 않는다.

## 6. 서버 장비 인증 정책

기존 기능 기준을 새 서버 신뢰 경계로 이식한다. Firebase path/Player binding/Rules는 재현하지 않는다.

1. 시작은 본인 유효 세션, 서버 fresh siblings와 Armory 응답으로 입력 캐릭터를 확인한다. 무기/투구/어깨/상의/하의/장갑6부위 모두 장착해야 함. 중복·파싱 불가 응답은 성공/장비 해제로 해석하지 않음.
2. 서버 안전 난수로6개 중 중복 없이1~3개를 선택한다. 서버 baseline은 각 Type+Name+Grade이며 Tooltip은 내구도 등 변동 때문에 비교 기준에서 제외한다. 클라이언트는 지정 부위를 고를 수 없음.
3. 서버 clock 기준10분 TTL, now>=expires_at이면 만료. 지정 부위가 전부 API에서 사라지고 나머지6부위 항목이 baseline과 동일해야 성공. 액세서리/스톤/팔찌 변경은 판정 대상 아님, 성공 후 장비 복구 여부를 요구하지 않음.
4. API 갱신 지연/지정 슬롯 남음/비지정 슬롯 변경은 pending으로 재확인 가능. API 장애/invalid snapshot은 소유권을 바꾸지 않음. 기존처럼10분 내 확인 가능하되 API 보호용 per-user/challenge rate limit과429 Retry-After를 명시하고 즉시 무제한 자동 polling은 금지한다.
5. challenge actor·등록 관계·현재 account 상태/ownership_revision과 최신 서버 roster를 commit 전에 재검증한다. 취소/만료/다른 회원 challenge·소비된 거래·교차계정 캐릭터를 거절한다. 네트워크 대기 동안 DB lock을 오래 잡지 않고 최신 revision 조건으로 확정한다.
6. 이전 정책은 fresh 장비 인증 성공 시 게임 계정 전체·소속 Character의 소유권 이전을 허용했다. 이번 신규 서버도 단일 current-owner·revision 증가·이전 owner 등록의 ownership_lost·활동/대표 자격 해제를 한 transaction으로 처리하는 방향을 요청한다. 타인 원정대 조회/등록 자체는 이전을 일으키지 않음. 기존 owner의 활동 선택·개인설정은 새 owner에 복사하지 않음.
7. 이번에 파티/그룹 자료는 생성하지 않는다. 향후 도입될 업무 명령은 current ownership_revision을 다시 검증해야 한다. 동시 두 인증/활동 저장 충돌 시 한 결과만 유효하며 부분 이전/중복 owner/삭제한 정상 캐릭터가 없어야 한다.
8. 앱 종료 시 진행 인증은 UI 종료·가능하면 cancel 요청으로 끝낸다. cancel 전달이 실패해도 서버TTL로 종료하며 재로그인만으로 자동 confirm하지 않는다. server challenge와 장비조작 안내·재확인 상태를 신규 Flutter에 연결할 수 있게 DTO를 제공한다.

캐릭터명 변경/캐릭터 삭제 뒤 identity 중첩이 불완전하거나 서로 다른 계정과 충돌하면 실패·명시적 재인증/확인 상태로 남긴다. 자동으로 다른 소유자 계정을 병합하지 않는다.

## 7. 앱 활동 캐릭터·대표 불변식

- 조회/등록/소유 인증과 앱 활동을 분리한다. 최초 빈 회원·미인증 등록은 정상 상태다. 최초 인증 후 activity 설정 전에는 unconfigured로 응답하고 자동으로 전체 캐릭터를 활동 처리하지 않는다.
- Flutter는 최초 관리 화면에서 인증에 사용한 캐릭터를 대표 후보로 제안할 수 있지만, 실제 저장 전 서버 활동 자격이 생겼다고 표시하지 않는다. 첫 정상 저장으로 대표/활동을 함께 확정한다.
- 설정된 각 인증 계정은 활동 최소1명·대표1명이며 대표는 그 계정의 선택 집합에 포함되어야 한다. 본/부계정 전체 선택은 회원에 합산되지만 계정별 저장으로 다른 계정 활동이 삭제되지 않는다.
- actor가 현재 active owner, 대상 Character가 같은 game_account_id 소속·confirmed/active인지 서버에서 확인한다. duplicate/타인/누락/소유 상실/비활성 ID를 거절한다. 소유권 version이 바뀌면 stale save409, 성공처럼 처리하지 않음.
- 새 siblings 캐릭터는 비활동 기본값, 기존 ID·유효한 선택/대표는 유지한다. 누락은 missingFromLatestRoster로 표시하고 자동 삭제/재배정하지 않는다. 대표가 누락되면 needs_reconfiguration과 서버 사용 불가 상태를 명시하고 유효 대표·선택의 원자 교체를 지원한다.
- 활동 해제는 기존 소유 인증을 해제하거나 캐릭터를 삭제하지 않는다. 후속 파티·완료 자료가 생겨도 활동 해제 자체가 자동 탈퇴/이력 삭제를 하지는 않는 계약이다.
- 기존 대표 변경 cooldown5분을 제안 유지한다. 최초 대표 seed는 cooldown을 시작하지 않고 같은 대표 재전송은 변경 시각을 갱신하지 않는다. 대표/활동 교체를 별도 쓰기로 나눠 대표가 비활동인 중간 상태를 만들지 않는다. 서버 next_change_at/REPRESENTATIVE_COOLDOWN을 인계해 UI가 안내하도록 한다.
- 표시 순서/displayLimit은 이번에 로컬 유지한다. displayLimit은 활동 수 이내이고 선택 대상이 활동8명/표시6명이면 활동8명 전체가 앱 대상이라는 의미를 유지한다. 선택·대표 쓰기는 화면의 저장1회, 실패 시 성공 상태로 로컬 확정하지 않음.
- 등록 마지막 제거·모든 소유권 상실·미설정 상태에는 활동0이 가능하다. 현재 유효한 configured 계정을 유지한 채 저장으로 임의0명을 만드는 것은 거절한다. 예외/초기화 상태를 DTO로 구분해 최소1명 정책과 충돌하지 않게 한다.

## 8. 외부 API·조회·갱신·오류

- 서버가 Lost Ark API를 호출해 장비 proof/roster를 검증한다. 앱이 보내는 JSON을 proof로 쓰지 않는다. 계정 summary는 siblings, 인증은 Armory 종합 상세가 필요하다. provider key는 서버 환경의 private 설정으로 관리하는 방안을 권장하며 준비 여부는 Backend가 보고한다. 앱에 key 하드코딩/Issue 첨부를 요구하지 않는다. 사용자별 key 필요 여부가 다르면 별도 계약으로 보고하며 임의 credential 업로드 API를 만들지 않는다.
- 수동 refresh와 자동 summary 갱신의 요청 합치기·upstream429/timeout·최대 동시성/요청량을 명시한다. 시작 후보 정책은 summary30분·수동10초이며 이는 앱 기존 캐시 기준일 뿐 provider 실제 rate limit을 대신하지 않는다. 인증 proof는 오래된 summary/장비cache로 성공시키지 않는다.
- API 실패/일부 서버 누락을 정상 빈 roster로 덮어써 Character·선택·대표를 삭제하지 않는다. 전체성 보장이 없는 응답은 roster reconciliation을 거절/보류한다. null combat power는 최근 정상값을 파괴하지 않고 stale/조회시각을 구분한다. 1차 summary로 full 빌드 JSON을 매회 조회하지 않는다.
- GET 내 계정에서 다른 소유자의 user_id/email·OAuth subject·장비baseline·challenge·private 설정을 노출하지 않는다. 본인에게 ownership_lost와 재인증 필요만 안내한다. unrelated path는404 등 비노출 정책을 정의한다.
- 제안 오류:401 ACCESS_*/SESSION_*,403 OWNERSHIP_REQUIRED,404 REGISTRATION_NOT_FOUND/CHARACTER_NOT_FOUND,409 REVISION_CONFLICT/IDENTITY_CONFLICT/REPRESENTATIVE_COOLDOWN,400 INVALID_REQUEST/EMPTY_ACTIVITY_SELECTION/REPRESENTATIVE_REQUIRED/EQUIPMENT_INCOMPLETE,429 RATE_LIMITED,503 UPSTREAM_UNAVAILABLE. 장비 mismatch는200 pending + result_code로 재확인 가능 상태를 주는 방안이다. 정확한 status/code/재시도/부분성공 정책은 OpenAPI에 확정한다.

## 9. Backend 작업 순서·검증·인계 완료 조건

1. 이 지시서와 기존 #2 계약을 읽고 schema/ownership/외부API key 준비·REST/오류·초기 대표/활동·중복 계정 식별·cooldown 정책을 검토해 답변한다. endpoints는 제안이므로 변경 근거를 제시해 합의한다. 기존 Firebase 조건문/Rules를 복사하지 않는다.
2. 내 등록/summary 조회·등록·수정·제거 + provider adapter + PostgreSQL migration을 하나의 검증 단위로 구현한다.
3. 서버 challenge/confirm/cancel·canonical identity·소유권 확정/이전과 audit를 원자적으로 구현한다.
4. 활동·대표 atomic save와 current-owner/version 검사, 새/누락 roster·재구성을 구현한다.
5. 실제 DB pytest: guest/타인 요청 거절, actor/verified/장비 위조 거절,10분 경계·API 지연/오류/429·재전송/응답 유실, 동일 identity 동시등록/인증·충돌/rollback, ownership transfer와 늦은활동 save, 대표/최소1명/cooldown·초기seed, 새/누락·부분roster·등록제거·다른 계정 설정 보존을 최소 사례로 검증한다. 실기기로 위조하기 어려운 서버 경계에 집중한다.
6. 커밋 SHA·원본 OpenAPI·migration·sanitized 예제·오류 표·정책/상한·실행방법·테스트 결과와 미검증 실제provider/기기 항목을 Issue에 인계한다. mock proof 통과를 실제 장비/API 인수 통과로 보고하지 않는다.
7. Flutter가 확정 계약으로 Repository/DI/내 계정·인증·캐릭터 관리 화면을 연결한 후 사용자가 수동 인수한다. 기존 로그인/비로그인 로컬 흐름은 회귀 보호한다. 이번 Issue를 Backend 코드만 작성했다고 임의로 닫지 않는다.

Backend 기록 방식: 프로젝트 AGENTS/ai_rules → NEXT_WORK(현재 단일 그룹의 근거·포함/제외·순서·완료 조건) → AI_CONTEXT(전체 상태·기준 문서 지도) → 관련 계약 확인. DEV_LOG는 필요한 키워드 이력만 검색한다. 완료 시 새로 가능해진 흐름/보존 확인/자동 검증/미확인 기기·운영 항목을 기록하고 NEXT_WORK를 다음 그룹으로 교체한다. 코드·테스트·문서는 같은 검증 단위로 남기고 최신 dev 통합/push·Git 한계를 보고한다. Backend 저장소 자체 AGENTS·현지 정책을 우선 적용한다.

## 10. Flutter 조사 근거 (과거 계약을 자동 이관하지 않음)

- lib/app/backend_app.dart: 로컬 계정/summary 연결, 서버 ownership 표시 숨김, 인증/원정대 기능 pending.
- lib/features/account/domain/entities/local_game_account.dart: 본/부계정·local/server ID 분리, 대표/표시 수·누락 상태.
- lib/features/account/domain/policies/activity_characters_policy.dart / entities/save_activity_characters_command.dart: 소유·활성·대표 포함·중복/순서/최소1명 검증.
- lib/features/account/presentation/viewmodels/character_management_view_model.dart: local draft·한 번 저장·대표/활동/순서/표시 수 흐름.
- lib/features/account/domain/repositories/representative_character_sync_gateway.dart:5분 cooldown·최초seed 예외.
- lib/features/account/data/gateways/local_game_account_verification_gateway.dart 및 docs/architecture/GAME_ACCOUNT_VERIFICATION_CONTRACT.md:6부위·1~3해제·10분·fresh API·이전/누락 정책.
- docs/architecture/ACTIVITY_CHARACTER_AND_RAID_FILTER_CONTRACT.md: 활동과 로컬 표시·원정대 인증 분리.
- docs/backend-migration/06-api-requirements.md OWN-01/02·CHAR-01/02 및09·10·11: 신규 서버·빈 데이터·권한/계약 책임.

위 경로의 소스는 Flutter a52492f에서 확인할 수 있다. 이전 Firebase 배포/이전 자료는 요구 분석 근거이며 실제 Firebase 변경 승인이나 SQL/API 구현 완료 근거가 아니다.

## 2026-10-14 추가 계약 회신

[Flutter 회신](https://github.com/heo0328/lostparty-backend/issues/3#issuecomment-6159847616). A/B 소비 가능 방향: 전체 settings와 페이지 분리, 전체 페이지의 roster_revision/settings_version/ownership_revision 일치 후 draft 생성, PUT expected_roster_revision 추가, CURSOR_STALE/409 재조회·사용자 재확인. suspect 비자격/needs_reconfiguration·기존 선택/ID/로컬 자료 보존, provider 근거 합의 전 roster 감소의 자동 missing/해당 불완전 roster 소유권 이전 보류. 대표 복구 cooldown 우회 없음 유지. 멱등 replay의 삭제 리소스·만료 challenge 복구와 principal 검증 조건 보완 요청. TTL/rate limit 초기안 소비 가능; 서버 key 준비·실 provider 증거는 미확인. 정확한 OpenAPI/DDL/SHA는 Backend 인계 대기이며 이번 회신으로 API 구현/인수 완료를 주장하지 않는다.
