# Google 로그인 — Flutter 연동 정책

작성: 2026-10-13, 갱신: 2026-10-14. 상태: 확정 Backend 계약 소비 확인, 사용자 Google 로그인 및 안내한 수동4항목 통과. 테스트 전환·안정화 완료; 고급 서버 경계·신규 업무 API는 별도 근거/후속 범위.
작업 브랜치: `feature/google-login`. 신규 서버 인증 요구는 [Backend Issue #2](https://github.com/heo0328/lostparty-backend/issues/2)로 전달했다.

## 사용자 확정 정책

### 계정 문의용 회원 ID 표시 (2026-10-23)

설정의 Google 로그인 정보 아래에 로그인한 본인의 Backend 내부 회원 ID(`AuthSessionController.userId`/`AuthUser.id`) 전체 값과 복사 버튼, ‘계정 문의 시 회원 ID를 함께 알려주세요.’ 안내를 제공한다. 기존 인증 상태 값을 재사용하며 추가 API·별도 저장은 없다. 비로그인/인증 복원 중에는 숨긴다. 회원 ID는 문의 대상 식별용이며 소유권 인증이나 권한 증거로 사용하지 않는다. 세션 ID·토큰은 표시하지 않는다.

### 2026-10-14 합의안 기준 Flutter 연결

사용자가 [최종 검토안](https://github.com/heo0328/lostparty-backend/issues/2#issuecomment-6149545526)에 [동의](https://github.com/heo0328/lostparty-backend/issues/2#issuecomment-6149615842)하고 동일 API가 작성된다고 가정한 Flutter 작업을 승인했다. 아래 구현은 승인된 검토안으로 시작했고, 후속 검증에서 확정 Backend 계약과 대조했다. 소비 SHA·대조 결과는 아래 확정 계약 절을 따른다.

- `main()`은 신규 BackendApp을 실행한다. Firebase SDK 초기화·익명 로그인·Player 생성·실행 기록 없이 로컬 계정 탭으로 진입한다. Firebase 제거 구간에서 구 MyApp/Router·익명 Player/Firestore adapter·SDK·플랫폼 설정을 삭제했다. 기존 Google OAuth 프로젝트·Credential Manager 연결은 유지한다.
- 실제 HTTP adapter는 `/v1` challenge/login/me/session/refresh/logout 6API의 합의된 snake_case DTO를 사용한다. transaction secret과 refresh request ID는 안전 난수32바이트의43자base64url, challenge hash는 전달ASCII문자열의SHA-256소문자hex64다. Google proof 교환은 자동 재시도하지 않는다.
- 로그인 화면의 한 Google 버튼과 유지checkbox·가입 안내를 연결했다. 성공 후 이전 화면으로 pop하며 작업 자동 제출 없음. 설정에서 로그인상태/유지선택/로그아웃을 제공한다. 정책 URL은 실제HTTPS설정이 있을 때만 링크를 표시하고 미설정 개발버전에는 준비 안내를 표시한다. 정책/탈퇴 미확정 상태를 정식 배포 완료로 판정하지 않는다.
- 앱 공통 세션은 Backend 내부회원과 자체token만 사용한다. 복원에는/me확인을 사용하고access만료에는single-flight refresh, 종료·정지에는credential해제하며silent Google 로그인으로 재생성하지 않는다.
- 유지선택일 때 origin별 secure storage의단일JSON에user/tokens/pending oldrefresh/requestID/시작시각/전송횟수를 함께 저장한다. 미선택은메모리만 사용하고저장값을제거한다. 전송전에횟수를기록하며 총3회·60초미만·동일쌍재전송,1/3초backoff·429Retry-After범위를적용한다. 서버의복구시각/오류가최종기준이다.
- 복구409는재인증필요,401/403은현재세션정리,일시네트워크장애는credential·유지선택을즉시삭제하지않는다. logout/재로그인/폐기epoch로늦은결과를차단하고저장교체/삭제를직렬화한다. 서버logout미확인은locallogout과구분한다.
- 로컬 AccountRepository와캐릭터/빌드/토큰설정화면을재사용한다. 새경로에는Firestoregateway·serverSync를주입하지않고기존Firebase소유인증badge를표시하지않는다. local원본/과거ID는삭제하지않고새권한으로승계하지않는다.
- 공개모집목록/필터UI는접근가능하지만Backend공개API계약이없어준비안내와unavailable조회상태를표시한다. 성공한빈결과나Firebase조회로대체하지않는다. 그룹/원정대/private기능은로그인알럿과준비화면이며본구현은후속계약의존성이다.

#### 실행 설정·인수

현재 시작 정책은 [scoped 복원 계약30](../backend-migration/30-scoped-storage-write-contract.md)의 후속 정정을 따른다. 기존 정적 이미지를 서비스 초기화부터4초 표시한 뒤 인증/자료 준비와 무관하게 앱으로 진입하며 앱 소유 복원 작업은 계속한다. 애니메이션 추가는 보류다. 과거2200ms·인증완료 대기·debug URL 알럿 정책은 적용하지 않는다.

Debug는 `BACKEND_BASE_URL` 명시값을 우선 사용하고 미지정 시 Android 에뮬레이터용 `http://10.0.2.2:8000`으로 즉시 초기화한다. 주소 입력 알럿은 없다. debug 전용 네트워크 설정은 개발 HTTP를 허용한다. release에는 `BACKEND_BASE_URL`의 HTTPS 주소가 필수다. `GOOGLE_SERVER_CLIENT_ID`는 확인된 공개 Web client가 기본값이다. `TERMS_URL`·`PRIVACY_URL`에는 확정된 HTTPS 주소를 설정한다. 앱 비밀키는 dart-define에 넣지 않는다. 인증정보는 origin별 저장이므로 접속 주소가 달라지면 동일 서버라도 기존 로그인 저장값을 자동 공유하지 않는다.

Backend실행후사용자가에뮬레이터에서앱실행·Google선택/취소·최초가입/재로그인·유지선택별앱재시작·응답유실복구·로그아웃·로컬빌드를검증한다. Windows→WSL접속과서버nonce claim/서명검증·release등록은별도확인이다. 에이전트는기기설치/조작하지않았다.

- Android 우선, 신규 FastAPI/PostgreSQL Backend를 사용한다. 기존 Firebase 사용자·UID·Player·데이터를 연결하거나 이관하지 않는다.
- 앱 실행에 로그인을 강제하지 않는다. 비로그인은 서버 회원·guest UID·사용자별 서버 자료를 생성하지 않는다.
- 기존 로컬 계정·캐릭터 조회·빌드 관리와 기본 설정은 비로그인에서도 유지한다. 원정대 인증은 로그인 후에만 가능하다.
- Google 로그인은 앱 회원 인증이다. 게임 원정대 소유권이나 운영 권한을 부여하지 않으며 기존 소유권·역할 검증을 대체하지 않는다.
- 보호된 기능 선택 시 `로그인이 필요합니다.` 알럿과 `취소`/`로그인` 버튼을 제공한다. 로그인 후 원래 화면으로 복귀하며 요청한 쓰기는 자동 재실행하지 않는다.
- 가입·로그인은 한 화면/Google 버튼으로 통합한다. 첫 인증 성공은 신규 가입, 재로그인은 동일 회원을 사용한다. 별도 닉네임·비밀번호 입력과 최초 동의 전용 화면은 두지 않는다. 가입 안내와 서비스 약관·개인정보 처리방침 링크는 제공한다.
- 로그인 유지 여부는 사용자가 선택한다. 선택한 경우 기기 안전 저장소로 복원 정보를 보관하고 다음 실행에서 Backend로 세션을 확인한다. 미선택은 인증정보를 메모리에만 보관하고 새 앱 실행을 비로그인으로 시작한다. 화면 이동·일시적 백그라운드 전환은 로그아웃하지 않는다.
- 기존 로컬 데이터는 삭제하지 않는다. 과거 서버 ID와 로컬 캐릭터 정보는 새 회원의 소유권 증거가 아니다.


### 2026-10-14 확정 Backend 계약 대조

- 소비 계약: Backend `519c609495966a3d785c6671c09bf513b28875a6`, [추적 OpenAPI](https://github.com/heo0328/lostparty-backend/blob/519c609495966a3d785c6671c09bf513b28875a6/openapi/openapi.yaml). 파일 SHA-256 `7e62e9def16c5388760e1b3877ef52e618d254a4b32ab708305e850c39e434b0`.
- 확인한 Backend checkout은 `e6c72e48276bf43367284cbbc36163d57389ca5d`이며 dirty 없음. 계약 인계 기록은 [Issue 댓글](https://github.com/heo0328/lostparty-backend/issues/2#issuecomment-6151318353). 과거 /health만 존재·계약 미인계 문구는 아래 이력의 당시 상태다.
- challenge 201, Google 로그인 200, me/session 200, refresh 200/복구409, logout 204와 request/response snake_case 필드를 Flutter adapter/모델과 대조했다. canonical 32-byte base64url·ASCII SHA-256·Bearer·회원 상태와 세션 날짜 필드가 일치한다. challenge 300초, access 600초, remember 절대30일/idle7일, 미유지 절대12시간/idle2시간, recovery60초/추가2회도 합의와 일치한다.
- `tests/test_auth.py`는 로그인/무guest, TTL, canonical/strict DTO, refresh 복구·재사용 폐기·동시성·원자 rollback·logout·위조/정지/만료를 검증한다. `tests/test_google.py`는 서명/claims/nonce/허용 azp·제공자 실패·민감정보 로그 제외를 검증한다. Backend 문서의 46개 통과는 Backend 기록된 결과이며 이번 Flutter 작업에서 DB 테스트를 반복 실행하지 않았다.
- 현재 Windows localhost:8000 조회는 연결 실패했다. 서버를 임의로 시작하거나 DB/설정 변경하지 않았다. 추적된 계약 소비 확인과 현재 실행 서버 응답 검증을 구분하며 실제 세션 인수는 서버 실행 후 사용자가 진행한다.

## 화면과 인증 경계

| 기능 | 비로그인 | 로그인 후 조건 |
|---|---|---|
| 공개 모집 목록·상세·필터 | 허용 | 동일 공개 조회 |
| 로컬 계정·캐릭터 조회·빌드·설정 | 기존 기능 유지 | 기존 기능 유지 |
| 원정대 인증·수동 인증 요청 | 로그인 알럿 | 기존 인증 절차 |
| 모집 생성·신청·참가 | 로그인 알럿 | 원정대 소유·참가 조건 추가 검사 |
| 내 파티·신청·이력·내 그룹·요청 | 안내 화면, private 요청 미시작 | 본인 scope |
| 그룹 가입·생성·관리 | 로그인 알럿 | 소유권·멤버/리더 권한 추가 검사 |
| 운영 기능 | 허용하지 않음 | 서버 운영 권한 필요 |

하단 탭 자체를 막지 않고 private 영역에 안내를 표시한다. 공개 그룹 검색/요약의 필드 범위는 Backend 계약으로 확정하며 private 회원·신청 정보는 공개하지 않는다. 공개 응답 계약이 없는 상태에서 기존 private API를 guest용으로 사용하지 않는다.

Google 버튼은 공식 브랜딩을 따른다. 로그인 유지 체크박스의 최초 기본값은 해제를 제안 기본값으로 사용한다. Google 인증 취소는 원래 화면으로 돌아오고 오류로 표시하지 않는다. Backend 검증/세션 발급이 완료돼야 로그인 성공이다.

## 세션·데이터 수명

- 로그인 상태는 앱 공통 세션 서비스가 소유하고 Router/DI와 Repository가 이를 참조한다. View에서 Firebase currentUser 또는 Google 계정 존재만으로 앱 로그인 성공을 판정하지 않는다.
- 복원 중에는 공개·로컬 기능을 유지하고 private 작업을 대기시킨다. 일시 네트워크 실패와 세션 만료/폐기를 구분하며 연결 장애만으로 보관 credential을 삭제하지 않는다.
- 동시 갱신은 한 요청으로 모은다. 회전·응답 유실·재시도·token TTL의 실제 정책은 Backend 계약 인계 후 구현한다.
- 명시적 로그아웃은 현재 세션만 폐기하고 기기 credential/private 구독·캐시를 해제한다. 서버 폐기 실패는 로컬 로그아웃과 구분해 표시한다. 로컬 빌드·설정은 유지한다.
- 계정 전환·늦게 도착한 이전 계정 응답·앱 재진입에서 다른 회원의 private 데이터가 섞이지 않게 한다. Google identity를 Lost Ark API credential로 사용하지 않는다.
- 회원 탈퇴 API와 앱 안내는 별도 계약을 따른다. Google 계정 삭제와 구분한다.

## 구현 전 조사와 계약 인계 이력

> 이 절은 구현 전 조사·단계별 이력이다. 현재 진입점과 구현 상태는 위 Flutter 연결 절과 AI_CONTEXT를 따른다. 사용자 Google 로그인 성공은 확인됐으며, 원격 OpenAPI와 로컬 구현 보고는 구분한다. 남은 계약 고정·세션 인수는 NEXT_WORK에서 관리한다.

기준 Flutter 커밋은 `64b09bfb515ea5e81e798175b99d293a9a8a9a35`다. `lib/main.dart`의 bootstrap/MyApp와 `lib/app/router/app_router.dart`는 필수 PlayerSession을 받는다. `app_services_initializer.dart`는 Firebase 익명 인증→Player 생성/연결→실행 기록을 수행하며 Router의 Repository는 Firebase UID/binding을 사용한다. 내부 user ID를 Firebase playerId 자리에 대입하지 않는다.

Backend OpenAPI 0.1.0은 2026-10-14 재조회 시에도 GET /health만 있다. #2에는 인증·갱신 복구 설계와 사용자 결정 인계 댓글이 있으며 정확한 DTO·오류·API 구현/계약 SHA는 아직 인계되지 않았다. API adapter·bootstrap 전환은 계약 인계 후 진행한다. 서버 API와 독립적인 Android nonce bridge는 아래 선택에 따라 먼저 구현한다.

### 2026-10-14 등록 입력과 현재 구현 단위

- 기존 `lost-party` Google/Firebase 프로젝트를 재사용한다. 사용자 제공 Web Client ID는 `574337852234-vdkvdobbq8es2rdpumc1icqt6ja3a3cr.apps.googleusercontent.com`이다. 이는 공개 설정이며 secret이 아니다.
- 패키지는 `kr.co.heowork0921.lostparty`. 사용자 콘솔 화면의 Android SHA-1 `6B:B4:A0:BC:30:6B:D2:0C:85:F5:24:EB:B5:00:BA:20:8B:2B:B2:05`가 로컬 debug 인증서와 일치했다. 다른 등록 `DF:13:...:06:43`의 release 매칭은 미확인이다.
- 콘솔 게시 상태는 프로덕션/외부, 데이터 액세스 목록은 비어 있다. 추가 Google API 권한을 요청하지 않는다. 실제 Google 인증은 미검증이다.
- 사용자는 Firebase 익명 공급자를 비활성화했다고 확인했으며 Backend 개발 중 기존 앱 테스트 중지를 수용했다. 새 코드로 익명 인증을 성공 처리하거나 재활성화하지 않는다.
- 개발 서버는 로컬, 에뮬레이터 우선·가능하면 사용자 실기기 테스트다. 후보 URL은 호스트 localhost:8000, 에뮬레이터 10.0.2.2:8000이며 WSL 전달/Android 접속·HTTP 예외는 미검증이다. 일반 설정에 운영 HTTP 허용을 추가하지 않는다.
- 이름·email·avatar·lastSeen은 초기 서버 저장에서 제외한다. 지원/개발 연락 이메일은 heowork0319@gmail.com, 도메인 없음·향후 Discord 문의 채널 예정이다. 약관/개인정보 URL은 미확정이다.
- Backend 댓글의 사용자 결정 인계: Access 10분, remember=true 절대30일/idle7일, false 절대12시간/idle2시간. 갱신 응답 복구는 최초 성공 commit+60초 미만, 같은 old refresh/request ID로 추가2회(최초 포함 최대3회)다. 암호화 응답/오류 DTO·보관 원자성 상세는 계약 검토 중이다.
- 구현 선택: Flutter MethodChannel → Android Credential Manager의 Google 버튼 흐름. 매 호출마다 serverClientId/서버 nonce를 전달하고 idToken만 반환한다. singleton initialize 재호출·nonce 재사용 우회는 없다. API 요청·회원 생성·세션 저장·앱 로그인 상태 변경은 이 모듈이 수행하지 않는다.
- 현재 포함 파일: Google 인증 증거 Domain/gateway, Dart channel adapter, Android bridge/Activity 연결·직접 의존성, channel 경계 테스트. 완료 조건은 Dart 테스트/표적 분석·Android debug 컴파일이며 정상 Google UI/nonce claim 검증은 서버 challenge 준비 후 사용자가 수행한다. 기존 main/bootstrap/Router/Firestore와 공개·로컬 화면은 이번 구간에서 변경하지 않는다.
- 검증 완료: Dart 경계 테스트6개·표적 flutter analyze·Gradle :app:compileDebugKotlin·git diff --check 통과. Credentials 1.6.0/GoogleID 1.2.0 사용. GoogleID 1.2.1은 Kotlin metadata 2.4와 현재 compiler2.2 호환 오류로 제외했고 기존 Kotlin 설정은 유지했다. MethodChannel의 동시 요청/취소/재호출·잘못된 결과·민감 오류 제거를 검증했으며 실제 token signature/nonce claim은 서버 검증·사용자 인수 대상으로 남아 있다.

공식 근거: [Android Credential Manager](https://developer.android.com/identity/sign-in/credential-manager-siwg-implementation), [Credentials 안정 버전](https://developer.android.com/jetpack/androidx/releases/credentials).

1. Backend 인증 방식(code/callback 또는 native 증거 교환), 회원·세션 API와 오류/재시도 계약, 검증 결과 및 계약 SHA.
2. 개발 API 접속 주소, Android debug/release Google client 등록과 필요한 공개 설정, 테스트 방법. secret/token은 문서·Issue·로그에 기록하지 않는다.
3. 로그인 유지별 세션 수명/복원/회전/로그아웃 정책과 가입 안내·탈퇴 계약.
4. guest 공개 모집과 기존 private 기능의 신규 principal 전환 의존성. 원정대/파티/그룹 전체 구현을 이 인증 작업에 함께 확장하지 않는다.
5. 실제 서비스 약관·개인정보 처리방침 URL. 아직 제공되지 않았으며 가짜 링크로 대체하지 않는다.

## 회귀 보호와 검증

- 기존 bootstrap 오류·재시도, 공개 모집 필터/페이지·빈 결과, 로컬 계정·캐릭터·빌드 읽기/편집을 보존한다.
- 로컬 원본/과거 ID는 유지하되 신규 소유권으로 인정하지 않는다. 로그인 후에도 미인증 원정대·권한 거절 조건을 유지한다.
- 첫 가입/재로그인·취소, 알럿 연타, 원래 화면 복귀·자동 제출 없음, 유지 선택별 새 실행, 만료·일시 장애·갱신 실패, 계정 전환·로그아웃 중 응답을 확인한다.
- 기존 관련 테스트는 `test/app/bootstrap`, `test/app/router`, account Repository/ViewModel 및 public_recruitment_list_view_model 영역이다. 익명 회원 생성 기대는 신규 경로에서 guest 무생성 기대와 구분한다.
- 자동 테스트는 세션 복원/갱신 동시성·폐기/늦은 응답·저장 경계에 집중한다. Router/DI라는 이름만으로 전체 시험을 실행하지 않고 `ai_rules.md` §8-1의 영향 기반 검증을 따른다. 현재 화면 선택 복구의 표적 범위와 전체 시험 생략 조건은 NEXT_WORK에 기록한다.
- Google 선택창·callback·재실행·백그라운드·정상 화면 회귀는 사용자가 Android 실기기로 확인한다. 에이전트가 설치·조작하지 않는다.

일반 인증 설계 근거는 [신규 인증 설계](../backend-migration/11-auth-and-access-design.md), 현재 실행 순서는 [NEXT_WORK](../project/NEXT_WORK.md), 준비·검증 이력은 [DEV_LOG](../project/DEV_LOG.md)를 따른다.
