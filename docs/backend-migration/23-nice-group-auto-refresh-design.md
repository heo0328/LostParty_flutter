# 나이스단 자동 갱신 복원 설계 — 기존 구조 조사와 UX 협의

2026-10-14. 사용자 지시: 다음 구간은 설계이며 앱의 기능적 UX는 사용자와 협의한다. Firebase 사용 당시 갱신 범위를 조사했고, 이후 사용자 확정 사항에 따라 회원 설정 Backend 요청을 게시했다. 과거 동작 자체를 새 Backend 적용 결정으로 간주하지 않는다. Flutter 기능 구현 전이다.

## 조사 기준

Firebase 제거 직전 커밋 a52492f28c0046a90c3a8d35df00e0c14f241fe6(a160c6f의 parent)을 git show로 확인했다. 현재 dev는 ccc6b23이며 최근 profile 전투력 연결은 계약39188d5를 소비한다. 과거 실행 지시를 새 서비스 승인으로 재사용하지 않고 데이터 이관도 하지 않는다.

핵심 원본 경로:
- lib/main.dart: MyApp.initState에서 Router를 한 번 생성.
- lib/app/router/app_router.dart:240 로컬 나이스단 설정 Repository, :282 StartupCharacterRefreshOrchestrator 및 Coordinator/Firestore 최소표시 Gateway 주입, :469 레이드 현황 첫 로딩 완료 후 runOnce 호출.
- lib/features/account/domain/services/startup_character_refresh_eligibility_policy.dart / nice_group_policy.dart / startup_character_refresh_orchestrator.dart / character_auto_refresh_coordinator.dart.
- lib/features/account/data/repositories/account_repository_impl.dart / local_nice_group_auto_refresh_settings_repository.dart, data/local/account_database.dart, data/gateways/firestore_character_minimum_display_sync_gateway.dart.

## 실제 Firebase 시절 흐름

앱 실행 → MyApp 수명의 Router 생성 → 레이드 현황의 첫 프레임·초기 목록/부가자료 로딩 완료 → runOnce → 로컬 계정/캐릭터 로드 → 대상과 나이스단/허용 설정 판정 → Flutter가 Lost Ark 종합Armory 직접 조회 → 프로필·빌드 분석/역할 판정 → 해당 역할 로컬 Snapshot 저장 → Firestore 최소 표시정보 반영.

| 항목 | 코드에서 확인한 동작 |
|---|---|
| 자동 실행 시점 | 내 계정 페이지마다가 아니라 앱 수명당1회. runOnce가 같은 Future를 보관하므로 탭 재진입·배경 복귀로 재실행하지 않음 |
| 실행 대상 | active 소유 계정, 서버 Character ID 존재, 원정대 이탈 아님, 아이템 레벨1700이상. 활동 선택/isVisible/화면 표시 개수로 제외하는 조건은 없음 |
| 나이스단 판정 | 본·부계정 전체에서 이탈하지 않은1700이상 동일 직업2명 이상이면 그 직업군 전체. 계정별로 따로 세지 않음 |
| 허용 OFF | 나이스단 직업군은 Armory 자동조회/저장 제외, 기존 수동 Snapshot 사용. 일반 직업군만 갱신 |
| 허용 ON | 나이스단도 일반 대상과 함께 종합Armory 조회/역할 Snapshot 갱신에 포함 |
| 설정 저장 | Flutter 로컬 Drift DB NiceGroupAutoRefreshSettings. playerId별 enabled/updatedAt, 기본false. Firestore 설정 저장이 아님 |
| 원본 조회 | Flutter LostArkApiClient/SecureApiTokenStore로 /armories/characters/{name} 종합 응답 조회. Firebase가 원본API를 대신 수집한 구조가 아님 |
| 로컬 저장 범위 | 종합 응답 rawJson과 분석·프로필의 아이템레벨/전투력/조회시각을 dealer/support 역할별 Snapshot에 저장. 전투력 한 칼럼만 갱신하는 기능이 아님 |
| 역할과 카드 | 감지 역할의 Snapshot을 갱신. preferredRole과 다른 역할은 캐릭터 카드의 기본combatPower를 덮어쓰지 않음. 반대 역할 Snapshot은 유지 |
| Firestore 반영 | characters의 itemAvgLevel/combatPower/buildIntegritySnapshot 등 최소 표시정보. 전체Armory JSON을 Firestore에 저장하는 흐름 아님. 선호 역할이 다르면 그 역할의 저장 Snapshot을 표시 기준으로 사용하거나 전투력 갱신을 생략 |
| 호출/실패 | Coordinator 동시3개, 정상 결과 메모리 TTL5분·동일 캐릭터 진행 요청 공유. 역할 판정/조회 실패는 기존 Snapshot fallback. 로컬 저장 후 서버 반영 실패를 로컬 저장도 실패한 것으로 단순화하지 않음 |
| 사용자 표시 | 첫 화면 진입은 자동갱신을 기다리지 않음. 내 계정 탭에 비차단 진행 인디케이터. 자동 개별 실패 알럿을 띄우는 흐름 아님 |
| 기존 전체 수동 갱신 | runManualExcludingNiceGroup(force:true). 나이스단은 허용ON이어도 이 전체수동경로에서 제외. 캐릭터 상세의 개별 세팅 저장/갱신은 별도 경로 |

예: 서포터 역할을 카드에 선택한 캐릭터가 현재 딜 세팅이면, 자동조회로 dealer Snapshot을 갱신하더라도 카드/서버 표시전투력은 저장된 support Snapshot 기준을 유지할 수 있다. 따라서 원본API 수치가 변했다고 항상 카드 표시전투력이 같은 값으로 바뀌는 구조는 아니었다.

코드상 자동 저장 전 검사는 역할 판정 경로를 확인한 것이다. 모든 보석/장비 검증 항목이 저장을 일괄 차단했다고 확대하지 않는다. 과거 자동 테스트/문서 이력과 실제 앱에서 매회 성공했는지도 구분한다.

## 현재와 다른 점

현재 BackendApp은 구 startup/manual runner와 나이스단 설정 Repository/playerId를 주입하지 않는다. 새 서버 전투력은 profiles 한정 관찰값·회원별 서버캐시이며, Flutter는 GET 표시와 사용자가 누른 POST를 사용한다. 로컬 전체빌드 Snapshot은 새 전투력값으로 저장하지 않는다. 현재 수동 전투력 버튼은1700선별을 하지만 나이스단 허용 설정과 연동하지 않았다.

따라서 새 POST를 앱 실행 시 호출하는 것만으로 옛 전체빌드 자동갱신이 복원되지는 않는다. 이전 active소유/서버ID 조건도 새 미인증 등록 표시조회와 구분해 재설계한다.

## 사용자 확정 사항 (2026-10-14)

- 자동 갱신은 전투력 숫자만이 아니라 전체Armory/역할별 빌드 갱신을 대상으로 한다. 현재 수동 profile전투력 API의 기능 확정과는 별도다.
- 나이스단 여부는 계정·원정대 자료를 로드한 뒤 기존 공통1700/동일직업2명 이상 정책으로 계산한다. 데이터 미로딩은 판정 전이며 자동갱신허용OFF와 구분한다.
- 나이스단 자동 갱신 허용은 회원별 설정이며 초기 기본값은 OFF다. 허용값은 로컬 전용이 아니라 서버에 저장한다. Google 로그인으로 식별되는 신규 Backend 내부 user_id를 기준으로 조회·수정한다.
- 기기 변경·앱 재설치·앱 데이터 삭제 후에도 같은 Google 회원으로 로그인하면 서버에 저장한 설정/계정 자료를 다시 불러와 같은 데이터 환경을 복원하는 것을 설계 목표로 한다. 기존 Firebase 자료 이관 요청이 아니다.

## 설정 데이터 흐름·기술 경계

1. 서버의 회원별 설정을 읽고 등록 계정/원정대 자료를 불러온다. 실제 순서는 첫 화면/자동실행 트리거 UX 설계에서 확정한다.
2. 설정이 처음 생성될 때 서버 기본 false. 로컬 캐시에 값이 없다는 이유로 먼저 false를 서버에 쓰지 않는다. 이미 저장된 true는 로그인 조회로 복원한다.
3. 전체 계정 자료로 나이스단 직업군을 계산하고, 서버에서 읽은 허용값으로 해당 직업군의 빌드 자동 갱신 포함 여부를 판단한다. 미조회·조회 실패를 서버 저장값 false로 간주하지 않는다.
4. 사용자 변경은 인증된 본인 회원 설정으로 서버 저장한다. 로컬은 표시/재실행을 돕는 캐시다. 저장 중·실패·오프라인의 스위치 표시와 재시도 UX는 사용자와 협의한다.
5. 회원 변경/로그아웃은 이전 회원 설정과 진행 중 응답을 격리한다. 재설치 복원은 신규 서버 회원 자료를 읽는 방식이며 기기 Player ID를 재사용하지 않는다.

논리 설정 nice_group_auto_refresh_enabled:boolean(default false)와 조회/수정 계약이 필요하다. 같은 범위의 기존 회원 설정 API가 있으면 확장하고 없을 때 최소 API를 요청한다. 실제 endpoint·version/동시 수정 규칙·저장형식은 Backend 계약 단계에서 확정한다. 원정대별 소유권/활동설정에 전역 허용값을 중복 저장하지 않는다.

## 같은 데이터 환경 복원과 후속 범위

나이스단 허용값의 서버 저장은 확정했다. 동일 환경을 완성하려면 역할별 저장 빌드·선호 역할·캐릭터 표시/순서·표시 개수 등 현재 로컬 전용 자료도 서버 복원 범위를 설계해야 한다. 특히 나이스단OFF에서 사용하는 수동 Snapshot은 현재 게임 세팅 재조회만으로 과거 저장 상태를 재현한다고 볼 수 없다.

현재 서버 등록/이름과 전투력 캐시의 연결 완료를 전체 로컬 환경 복원 완료로 확대하지 않는다. 각 항목의 기존 서버 제공 여부·복원 우선순위·역할별 빌드 저장 범위/형식은 조사·UX 협의 후 정한다. 이번 사용자 발언만으로 모든 로컬 JSON 업로드나 기존 데이터 이관을 구현하지 않는다. 과거 #5의 전체빌드JSON 제외는 그 수동 전투력 구현 구간의 범위이며 새 복원 설계의 영구 금지가 아니다.

## 남은 UX 협의

1. 앱 실행1회 기준과 처음guest에서 로그인/회원변경/재로그인 시 실행 기준. 내 계정 매진입을 과거 동작으로 간주하지 않는다.
2. 나이스단 설정 위치와 로딩/저장 실패 표시. 기본OFF·회원별서버저장은 확정이며 다시 선택을 요청하지 않는다.
3. 수동 전투력 버튼/전체 빌드 갱신과 나이스단 제외의 관계, 개별 갱신·진행/부분실패/미처리 안내.
4. 동일 데이터 환경을 복원할 항목의 순서와 역할별 빌드/표시 설정의 사용자 흐름.

위 UX 합의와 서버 복원 요구를 바탕으로 데이터 흐름·저장 주체·기존 정책 재사용·Router/DI·한번 실행 가드·수동/자동 중복·회원/late응답·검증과 완료 조건을 구체화한다. Flutter 기능 구현·기기 시험은 아직 시작하지 않는다.

## Backend 요청 (2026-10-14)

[Issue6 — 회원별 나이스단 자동 빌드 갱신 허용 설정 저장·복원](https://github.com/heo0328/lostparty-backend/issues/6)에 확정 사항의 구현을 요청했다. Backend dev 4eb23f5dc4048e75e4e27e9f56a2f6f0ec9cc940의 원본 OpenAPI에는 원정대별 character-settings만 있고 회원 공통 나이스단 필드는 없었다. 기본 false·회원별 GET/명시적 수정·세션/재설치 복원·회원 격리·기존 true 덮어쓰기 방지와 정확한 계약/구현 SHA 인계를 요청했다. Backend 회신 대기이며 API 경로·DTO·동시 수정 규칙은 아직 미확정이다. 전체 빌드/표시 환경 복원은 후속 계약 제안 대상으로 전달했고 일괄 구현을 요청하지 않았다. UI/실행 UX는 계속 사용자와 협의한다.

## Issue6 게시 계약 확인·설정 UX 제안 (2026-10-14)

[연결 요청6168992033](https://github.com/heo0328/lostparty-backend/issues/6#issuecomment-6168992033)과 immutable 79255f0f77602c26a215bf0340331eb697417ff4의 OpenAPI/ISSUE_6_MEMBER_SETTINGS.md를 직접 확인했다. Backend feat/member-settings는22개검증·로컬API/DB0004적용·push완료, dev/main미병합이다. 앞선 회신대기/경로미확정 문구는 이 인계로 대체한다.

- GET /v1/me/settings: Bearer, 필수boolean nice_group_auto_refresh_enabled와 필수정수version>=1만응답. 미설정false/version1, 조회는쓰기없음.
- PUT 동일경로: Bearer+UUIDv4 Idempotency-Key, boolean과expected_version 두필드만필수. 변경시version증가/no-op유지, stale version409은GET후사용자새결정, 같은key/body24시간replay·진행중Retry-After2·유실동일명령복구. 현재상태는GET으로확인.
- 기존인증/계정/전투력DTO는불변. 새설정DTO만연결하며 회원/세션세대격리·미조회/실패와false구분·자동false저장금지.

사용자 UX 질문을 제시했다: (1) 회원공통설정이므로 앱설정화면 배치 추천, 대안은 기존캐릭터관리. (2) 스위치변경즉시서버저장·저장중조작차단/실패안내·재시도 추천, 대안은별도저장버튼. 아직 사용자응답전이므로 추천안을확정하거나화면코드를수정하지않는다. 기존캐릭터관리의나이스단스위치와중복동작하지않게실제연결시한설정원천을사용한다.

이번설정API연결은허용값저장/복원까지이며전체빌드자동실행을시작하지않는다. 원정대/나이스단판정·전체빌드/표시환경복원과실행트리거는후속설계다. 현재 docs/my-account-backend-phase1의문서만수정하며기능구현착수는UX합의후분리한다.

## 사용자 UX 확정·첫 구현 그룹 (2026-10-14)

사용자가 기존 캐릭터 관리 화면 유지·스위치 변경즉시저장을 선택했다. 기존 나이스단 해당직업표시 위치에 회원 공통 설정을 연결한다. 하단 캐릭터 저장/취소와 독립이며 설정 스위치는 즉시 서버확정, 로컬 캐릭터 draft 취소로 되돌리지 않는다. 저장중/조회중 중복변경을 막고 실패안내/동일요청재시도를 제공한다. 비로그인은 로그인안내, 미조회/조회실패는OFF로확정하지않는다. 자동빌드미연결상태에서는허용설정저장단계임을표시한다.

범위: immutable79255f0 원본snapshot/새설정모델·공유회원설정VM·기존HTTP경계재사용·BackendApp DI/캐릭터관리화면주입. 로그인/새세션은GET으로복원, member/session변경은pending/캐시/늦은응답격리. PUT명령은고정key/body/version/시작시각,유실/진행중은같은명령수동재시도·RetryAfter/24시간준수. version충돌은GET후사용자재선택,멱등충돌/만료는GET확인후명시종료. 성공/replay뒤GET현재값확인. DB/기존활동/대표/표시순서저장경로·등록/전투력불변.

회귀목록: 비로그인로컬관리/하단저장취소, 본부계정/다중화면공유설정, 첫조회실패true덮기금지, 세션/회원전환중GET/PUT, 유실/RetryAfter/기한/replay후다른기기값·revision충돌, malformed boolean/version. 자동검증은새모델/명령복구/회원격리경계·기존캐릭터관리/등록/로그인테스트와최종analyze·필요전체test. 실기기인수는설정ON/OFF→화면재진입→재로그인/새환경복원만사용자에게묶어안내한다.

브랜치 feature/member-settings: 설정연결·검증완료가종료조건. 기존문서미커밋/미추적실험을보존하고이구간에서임의커밋/push하지않는다. 자동빌드실행/서버빌드복원·장비/활동Backend추가는제외.

## Flutter 설정 연결 구현 결과 (2026-10-14)

사용자 확정: 기존 캐릭터 관리 화면 유지·변경 즉시 저장. feature/member-settings에서 MemberSettingsViewModel과Controls를추가하고BackendApp의공유수명/세션경계에주입했다. 캐릭터관리의기존나이스단영역만교체하며하단캐릭터저장/취소와독립이다. optional이없는기존로컬/테스트경로는보존했다. 로그인시GET·관리진입시GET으로복원하고GET은설정쓰기를발생시키지않는다. 게스트는무요청·로그인안내,설정미조회/실패는null로분리한다.

새모델은boolean/intversion/정확한두키만허용. PUT명령은UUIDv4/key·불변body/version·회원/세션/시작시각을보관한다. 저장중중복차단,네트워크/불명확성공은동일명령수동재시도. RetryAfter대기와24시간기한,멱등충돌/만료는서버GET성공후사용자명시확인종료. version충돌은GET으로현재값확인후사용자재선택이며자동덮기없음. 성공/replay후현재값은GET으로확인한다. 늦은다른회원GET/PUT는결과·후속GET을폐기한다. 조회실패가이전PUT의대기시간을단축하지않는다.

원본snapshot contracts/issue6-79255f0.openapi.json은게시원본바이트이며SHA256 6659943b2064e15fd054f7a98426afc432d8d33b53ccb3806c3ac3e3d049ffd3. 전체1219/이후국소관련32·최종lib-test분석0. 사용자기기설정ON/OFF·화면재진입·재로그인/새환경복원은인수대기다. 자동빌드실행은미구현이며화면에도준비중을안내한다. 적용Flutter SHA는아직없고미커밋·dev미반영/미push다.

## 시작 API 호출 흐름 조사·갱신 선행 조건 (2026-10-14)

사용자가 설정 인수1/2/3(ON/OFF즉시저장·화면재진입·동일Google회원재로그인복원) 성공을 보고했다. 별도 재설치/앱데이터삭제·새기기 인수까지 완료했다고 확대하지 않는다. 사용자 후속질문에 따라 아래는 코드 기반 조사·설계이며 자동갱신 기능은 수정하지 않았다.

### 현재 실제 흐름

1. BackendApp._initializeServices가 Auth/HTTP/Router 및 공유VM을 먼저 생성하고 _restoreSession을 시작한다. MemberSettings/등록조회/전투력표시VM은 인증상태를 구독한다. 게스트 상태에서는 회원 private GET/PUT를 보내지 않는다.
2. 저장된로그인유지가있으면 AuthSessionController.restore는필요시refresh회복을수행하고GET /v1/me를검증한뒤signedIn을알린다. 로그인이없으면guest이며UI에서로그인후signedIn을알린다.
3. signedIn을받은VM들은비차단병렬로시작한다. 설정VM은 GET /v1/me/settings, 등록패널VM은 GET /v1/me/game-accounts 전체페이지, 전투력표시VM은 별도같은등록목록GET뒤등록별characters전체페이지를읽는다. 이들사이에설정GET완료를보장하는await는없다. 완료순서는서버/네트워크에따라달라진다. 등록목록의중복GET은현재구조의조회중복이며데이터경쟁의증거나이번수정대상은아니다.
4. 시작화면은인증restore완료와배경애니메이션완료를기다릴뿐,설정/등록/모든캐릭터조회완료를기다리지는않는다. 첫화면을띄운것은전체데이터준비완료를뜻하지않는다.
5. MyAccountViewModel.initialize는토큰상태/카탈로그/로컬계정/표시환경을읽고,개인LostArk키와로컬계정이있으면syncRosterSummaries(force:false)를비차단으로시작한다. 계정별 /characters/{name}/siblings를직접LostArk에서읽고최근요약시각1분제한을적용한다. 이자료는직업/캐릭터/아이템레벨요약이며전투력·전체Armory/역할Snapshot갱신이아니다. BackendApp의summary syncGateway는null이다. 설정허용값과무관하게원정대요약을불러오는것은현재동작이다.
6. 서버전투력의시작/재로그인은캐시GET뿐이다. /combat-power/refresh POST는현재버튼명시동작으로만호출한다. 설정스위치PUT는사용자변경만이며관리화면진입은GET이다.
7. 전체lib에서runOnce 호출부는없고StartupCharacterRefreshOrchestrator의정의만남아있다. BackendApp은startup/manual runner를주입하지않는다. 따라서현재빌드에서설정GET전기본OFF로전체빌드자동갱신을시작하는실행경로는없다. 이것은향후연결의순서보장이구현됐다는뜻이아니다.

### 확인된 향후 위험

회원설정VM은초기/세션변경/조회중value=null이고성공시MemberSettings(false/true)가된다. Controls의value?.enabled??false는비활성스위치그림용이며현재자동갱신판정에쓰이지않는다. 이표시용기본값을새실행기에복사하면미조회OFF오판가능성이생긴다.

남아있는구StartupCharacterRefreshOrchestrator는필요할때설정Repository를await하므로원래도단순화면OFF를먼저쓰는구조는아니지만, _loadNiceGroupRefreshEnabled가조회예외를false로바꾼다. runOnce는 _runFuture를영구보관한다. 그대로재연결하면실제서버ON이어도설정실패를OFF로간주해나이스단제외후실행1회를소진하고,나중에설정GET이성공해도자동재실행하지않을수있다. 구playerId/소유ID조건도현재계약과맞춘설계가필요하다.

### 새 자동갱신 연결 시 선행 조건

- 회원/세션확정 → 필요한회원설정GET성공과대상계정/전체roster준비(병렬조회가능) → 같은회원/세션인지확인 → 전체계정나이스단판정 → 명시적인서버true/false로대상계산 → 자동빌드갱신시작.
- 준비중/설정조회실패는false가아니라대기/실패상태. 준비전에는갱신을시작하거나앱1회실행완료로소진하지않는다. OFF가정으로먼저실행했다가ON복원후또실행하는방식은사용하지않는다.
- 기존값과화면표시는유지하며실패를어떻게다시시도할지는다음자동갱신UX/작업그룹에서합의한다. 회원변경·로그아웃·조회중설정변경에대한설정version/실행시점값·late결과격리도그때정한다. 지금설정변경만으로즉시전체빌드갱신을실행하지않는다.
- 회귀검증후보: 설정응답지연중갱신0건,roster먼저도착중0건,실패후성공ON대상을포함하고OFF대상을제외,준비실패는1회가드미소진,회원전환이전대상폐기,동일실행중복차단. 서버full-build계약/실행기구현은별도이며현재테스트를추가/실행하지않았다.

근거: backend_app.dart:114/144/149/380, MemberSettingsViewModel._onSession/reload, ServerAccountReadViewModel._onSession/load, ServerCombatPowerViewModel._onSession/reload, MyAccountViewModel.initialize/syncRosterSummaries, CharacterSummarySyncService, StartupCharacterRefreshOrchestrator.runOnce/_loadNiceGroupRefreshEnabled. 기능코드변경없이조사했다.


## 회원설정구간 종료 준비 (2026-10-14)

사용자가Issue6마무리와전체DB설계점검을지시했다. 회원설정ON/OFF·관리재진입·동일회원재로그인3흐름성공/전체1219후국소32·분석0/APK9.4초를재사용해feature/member-settings를커밋/dev통합·push하고최종인계후Issue6를종료한다. 자동빌드/전체환경복원·새기기별도인수는후속대장14에유지한다. 다음은전체저장구조의조사이며코드/DDL변경없음. 앞선미커밋/인수대기문구는당시이력이다.
