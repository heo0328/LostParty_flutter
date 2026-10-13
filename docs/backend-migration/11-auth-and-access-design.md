# 신규 인증·권한 설계안

상태: v0.1 미구현. [09](09-migration-decisions.md)의 확정 정책 적용,세부 token/flow/공개 범위는 설계 제안이다. 기존 익명계정 linking/recovery를 만들지 않는다.

## 주체와 역할

guest는 서버 사용자 record가 없는 상태다. OAuth/OIDC 검증 성공 후에만 신규 내부 user와 social identity를 원자적으로 만든다. same provider subject의 로그인은 같은 user를 재사용한다. 계정 상태(active/disabled 등)는 서버가 authoritative하게 판정한다. internal ID 표현은 backend 명세에서 정한다.

member(일반 로그인 사용자),group leader/member,party leader/승인권한,operator는 scope가 다르다. social provider 로그인은 operator·game owner를 자동 부여하지 않는다. email/name/avatar는 identity matching key 또는 role 근거가 아니다. OIDC의 issuer/subject를 검증 identity로 쓰며 다른 client의 pairwise subject가 같은지 제공자 등록에서 확인한다. [OIDC Core](https://openid.net/specs/openid-connect-core-1_0.html).

Discord 등 OAuth2 제공자의 identity 획득은 그 제공자의 검증된 응답·사용자 API adapter로 정의한다. OAuth2를 자동으로 OIDC ID-token 방식이라고 가정하지 않는다. provider별 실제 endpoint/scope/issuer/JWKS/client 등록은 backend 통합 때 공식 문서를 확인한다. 검증하지 않은 client subject/email을 저장하면 안 된다.

## 로그인 protocol 흐름 — 제안

1. 앱은 지원 제공자를 선택하고 로그인 transaction을 시작한다. state 및 필요 nonce/PKCE challenge를 로그인 요청과 묶고 허용된 redirect/client 환경만 사용한다.
2. native Flutter/Swift는 시스템 브라우저 등 외부 user-agent를 이용한다. native public client의 authorization code flow에는 PKCE를 적용한다. client secret을 앱에 넣지 않는다. [RFC8252](https://www.rfc-editor.org/rfc/rfc8252).
3. backend는 callback 또는 app 전달 증거를 제공자 adapter의 검증 경로로 처리한다. code/state/nonce/redirect/client binding·expiry·single-use와 OIDC 서명/issuer/audience 등 해당 protocol 검증을 수행한다. 서버 callback형과 native code-forward형 중 실제 제공자/redirect에 맞는 변형은 backend가 확정한다.
4. 증거가 유효하면 같은 verified identity의 user를 찾거나 신규 생성한다. 동시 최초 로그인도 하나의 identity와 user만 만들어야 한다. 이 단계에서만 session과 자체 token을 발급한다. 취소/실패는 회원을 만들지 않는다.
5. 앱으로 되돌아가는 URI에 장기 access/refresh credential을 직접 붙이지 않는다. 서버 callback형이면 짧은 수명·일회용 handoff를 원래 앱 transaction과 결합해 교환하는 방식으로 설계한다. provider code/로그인 proof를 일반 API의 bearer로 쓰지 않는다.
6. 신규 user에게 gameAccount/group/party/history는 없다. 제공자 로그인만으로 기존 Firebase 데이터·로컬server ID·운영 role을 승계하지 않는다.

auth transaction state는 short-lived protocol verification 자료다. guest UID/profile·비로그인 조회 이력을 생성하지 않으며 old Firebase binding도 보관하지 않는다. 그 저장수명·청소·rate 제한의 실제 schema는 backend에서 결정한다.

## 자체 token·세션 — 제안 기준

Access는 짧은 수명의 서명 token,Refresh는 예측 불가능한 opaque credential을 기본안으로 한다. 구체 format/서명 algorithm/claim/TTL는 backend 계약에서 확정한다. identity/session identifier 등 최소 정보만 포함하고 email/gameAccount/role 전체를 claims에 복사하지 않는다. 허용 algorithm·서명·issuer/audience·exp를 검사한다.

Refresh 원문은 DB/log에 저장하지 않고 검증용 hash 및 server session 상태를 관리한다. 정상 refresh마다 회전하고 이전 credential은 사용 불가로 만든다. replay 감지 시 해당 session family를 폐기하고 재로그인을 요구하는 안을 사용한다. OAuth 보안 BCP의 rotation/replay 지침을 참고한다. [RFC9700](https://www.rfc-editor.org/rfc/rfc9700).

Refresh 갱신은 DB transaction/조건부 소비로 원자 처리한다. 앱은 동시 여러401 응답에서 refresh 요청을 하나로 모으고 새 token 설치 후 재시도한다. 정상 중복 요청·응답 유실과 탈취 replay를 동일 처리해 사용자가 이유없이 로그아웃되는 경우를 테스트한다. retry/grace/recovery와 TTL 확정은 backend auth 작업의 결정 항목이지 이번 문서에서 완성했다고 주장하지 않는다.

매 private 요청은 server session/account active 상태와 object 권한을 검증한다. Access 서명이 맞아도 폐기된 session·정지 account는 거절하는 설계다. 이 방식으로 current-session logout/정지의 권한 반영을 DB 상태와 연결하며 DB 조회 비용은 운영 부하 측정으로 확인한다. role은 token의 오래된 값으로 판정하지 않는다.

현재 session logout은 서버 revoke 후 앱 token 제거/내 구독 해제다. 네트워크 실패시 local sign-out은 가능하되 server revoke 미완료 상태를 구분하고 짧은 Access expiry/Refresh revocation 정책과 함께 검토한다. 전체기기 logout은 별도 action이다. provider logout과 LostParty session 종료는 다르다. Refresh 실패/expiry/disabled user는 anonymous 계정 생성 대신 guest 상태로 돌아간다.

native credential은 OS secure storage와 메모리 사용을 분리하고 raw token을 URL/log/Drift build JSON에 저장하지 않는다. Flutter web이 실제 지원 범위가 되면 browser token/cookie/CSRF 정책을 별도로 설계한다. 현재 native 제안을 web에 그대로 적용하지 않는다.

## 신규 제공자 추가·계정 관리

초기 원칙 제안: 첫 검증 identity 하나가 user 하나를 만든다. 추가 social provider 연결은 active login + 양쪽 재인증/소유 증명한 경우만 허용하고 다른 user에게 이미 연결된 identity를 자동 이동/병합하지 않는다. email 일치 자동 merge는 없다. link/unlink를 첫 구현에서 지원할지 별도 scope를 정하며 미지원이면 명확히 거절한다.

삭제/재가입시 external identity 재사용과 신규 user/기존 game 관계 처리,탈퇴 중 리더 승계·활성 참가 정리,감사 retention은 후속 제품 결정이다. 이번 초기화 정책은 앞으로 생성될 모든 계정의 무조건 삭제 정책이 아니다. 첫 operator는 신규 계정의 identity를 운영자가 확인 후 별도 provisioning으로 부여한다. 공개 registration payload의 role 요청은 무시/거절한다.

## 권한 matrix — 제안 기본안

| 액션 | guest | 로그인 사용자 | 추가 server 조건 |
|---|---|---|---|
| public 모집 list/detail | 허용된 공개 field | 동일 공개 field | group/private 제외,필터/페이지·PII allowlist |
| group public summary 검색 | 허용 후보 | 허용 후보 |09 D04 범위 승인 필요,private membership/request 제외 |
| 내 profile/session/활동/알림/주간 상태 | 거절 | 본인만 | actor는token,다른userId 입력으로scope변경 금지 |
| 원정대 proof start/confirm | 거절 | 본인만 | 서버 evidence/기한/single-use·게임 API 조회,소유 conflict |
| 파티 create/apply/join | 거절 | 허용된 본인 | active ownership·generation·주간/자리/정원·group 자격 |
| 파티 approve/reject/manage | 거절 | scope role만 | leader/승인권한·대상/current revision·state transition |
| 멤버 leave/change role/Character | 거절 | 해당 권한만 | 자기 scope 또는관리권한,소유권·leader 고정석/배치 |
| group invite/apply/join/leave | 거절 | policy상scope만 | currentmember/leader·차단/만료·50인/50그룹·code |
| group leader transfer/disband/code | 거절 | group leader | member successor·last1·activepartycount consistency |
| 수동 proof request/owner defense | 거절 | requester/currentowner | 관계·만료·재요청·분쟁scope검증 |
| operator users/review/provision | 거절 | 일반user거절 | active operator/감사,제한된provision운영경로 |
| WS | public scope만 | own/group/room scope | subscribe시/권한변경시재인가,replay audience검사 |

guest에 인증 미비 메시지를 반환하되,로그인한 타인·group/private target의 존재를 노출할지 response policy는 contract에서 결정한다. client route/button gating은 UX이며 server deny를 대체하지 않는다.

## 게임 계정 ownership 설계 요구

앱로그인 성공과 game owner 인증을 분리한다. backend가 challenge 발급·baseline/장비 선택·기한·확인 증거 조회·소비를 소유한다. evidence 완료 후 transaction에서 현재 ownership과 identity collision을 재검증해 owner/generation을 갱신한다. client의 verified=true/ownerPlayerId/ownershipRevision은 권한 증거가 아니다.

빈 초기 DB라도 미래 재인증/소유권 이전으로 남은 무효 참가가 생길 수 있다. generation 검증과 group/party cleanup policy는 기존 R05 기능 요구로 유지한다. 원정대 재인증만으로 다른 신규 사용자 계정 전체를 복구/병합하지 않는다. manual/operator force transfer는 reason/evidence·status전이·감사를 별도로 남긴다.

## 필수 검증

invalid/replayed callback·wrong state/nonce/aud/issuer/redirect·동시첫로그인·미인증private request·forged actor/role·정지user/session·Refresh 회전/동시/응답유실/replay·logout후access/WS·다른기기session격리·role회수·identitycollision을 pytest 대상으로 한다. public 요청은 사용자/session/receipt row 생성이 없어야 한다.

Flutter/Swift실기기 browser/callback·알럿·앱 재실행·guest 복귀는 사용자 인수로 확인한다. 제공자 등록 값/정확한 token contract·backend schema는 실제 auth 구현 전 확정하며 이번에 credential 발급/가입/배포를 실행하지 않는다.
