# Backend 원정대 인증 클라이언트 준비

## 2026-10-17 최신 계약 소비 — 서버 재인증 차단·등록 복구

Backend105번째19c2dcc33630078fa0d88a1dd60e11857a44472b의 고정 계약/OpenAPI를 확인했다. VerificationOut/RegistrationOut schema는 기존고정fixture와동일하며409 ALREADY_VERIFIED가정책에명시됐다. 이거절은미확정쓰기를끝내고이미인증안내/현재등록목록갱신으로처리한다. 기발급challenge가있으면현재GET을읽되임의verified/취소로바꾸지않고장비확인/재전송을반복하지않는다. 다른대상의새시작은사용자명시선택과기존사전검사로만한다. 완료된원명령ACK→현재GET은거절과구분해유지한다.

차단후목록복귀는성공이동과구분하며현재소유목록을갱신해인증됨회색표시에반영한다. 목록에서삭제된본인원정대는기존원정대등록관리진입으로연결복구할수있다. 기존등록POST201이owned/verified이면새registration_id와현재GET을그대로사용하고인증버튼을제공하지않는다. 안내는인증된원정대등록완료이며unconfigured/활동0/대표null은실패가아니다. 새endpoint/DTO·소유추론/분쟁이전·로컬ID승계는추가하지않는다. 종전서버차단/연결복구대기문구는이번105번째소비로대체한다.


최종 전체 **1,590PASS·lib/test 분석0·format/diffcheck**. [106번째 Flutter 결과](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6228427796)로 인계했다. 새 화면·서버 응답의 실제 기기 조합은 미확인이다.

## 최신 정책 — 인증 유지 중 반복 인증 제외

2026-10-16 사용자 확정: 현재 본인 owned 원정대는 이름 뒤 ` - 인증됨`·회색·선택불가로 목록에 남긴다. 삭제/숨김이 아니다. ownership_lost는 과거 verified 이력과 구분해 재시도 후보로 둔다. 직접입력 탭은 `캐릭터 검색`이며 현재 본인 저장목록에 포함된 이름이면 `이미 인증된 원정대입니다.`로 시작하지 않는다. 서버 권위 판정·신규 이름/동시변경/삭제재등록 연결은 102번째 요청 후 Backend105번째에서 보완됐고 위 최신 계약 소비로 연결했다. 클라이언트 사전확인과 서버 최종 판정은 구분한다. 기존 본인 재인증 허용 정책은 최신 지시로 대체된다.

인증 정상 진행 중에는 조회 버튼을 숨긴다. 응답조회실패/기한경과 등에만 `인증 결과 다시 확인`, 미확정원명령 재전송은 `인증 요청 다시 시도`를 제공한다. 등록/대표의 기존 실패복구 조회도 `등록 결과 다시 확인`/`대표 캐릭터 다시 조회`로 목적을 표시한다. 미확정 명령을 새 key로 대체하거나 결과조회만으로 완료 처리하지 않는다.


## 최신 UX — 성공 후 이전 페이지 복귀·간결한 안내

2026-10-16 사용자 실제 장비인증1회 성공 보고와 Backend98번째 VERIFIED/소유연결 확인을 수신했다. 최신 사용자 지시로 성공 뒤 기존 페이지로 복귀하며 캐릭터 관리로 자동 이동하지 않는다. 상태갱신/현재회원·소유검증을 유지한 뒤 이전경로로 pop하고 직접진입으로 이전경로가없으면 내계정으로 이동한다. 과거 성공 상태로 다시 연 화면은 자동 복귀하지 않는다. 안내는 현재대상·해제부위·남은시간·필요한오류/복구행동만 간결하게 표시하며 사용자가 지정한 빨간 갱신안내는 유지한다. 과거 본문 중 성공후관리 전환 설명은 이 최신 지시로 대체한다. 새 문구도 핵심 행동/상태 중심으로 쓰며 인게임 표현은 사용자 조정을 따른다.


## 최신 연결 — 게시된 원정대 내 인증 캐릭터 선택

사용자 확정 표시정책(2026-10-16): 인증 후보와 서버 전체원정대/미리보기/현재상태의 기본 목록은 아이템레벨 숫자 내림차순이며 미확인은 뒤, 동률은 기존 입력순서를 유지한다. 개인 지정 표시순서·활동선택/표시개수는 별개이며 내계정/관리 화면의 기존 displayOrder/rank를 유지한다. 표시 정렬로 서버/로컬 저장목록·캐릭터 ID·인증명령을 바꾸지 않는다.

2026-10-16. [90번째 Backend cc372bfa 인계](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6216253151)의 고정 OpenAPI/StartIn/VerificationTarget/개발안내를 대조해 원정대 선택→기존 Repository의 등록/전체캐릭터 조회→명시선택→주소+version 인증 시작을 연결했다. 활동/대표/visible/count/1700·preview UUID는 후보 필터가 아니다. selection ViewModel의 조회세대/회원fence로 낡은 목록을 차단하며 조회실패/미선택은 시작하지 않는다.

등록 요청은 target_character={server_name,character_name}와 expected_registration_version을 함께 보낸다. 이름 trim/1~64·양수정수·필드짝을 검사하고 중첩 target/외부 body 모두 불변으로 유지한다. 구형 registration_id-only/direct_input은 기존body로 유지한다. 404등록/캐릭터·409revision/identity 거절은 목록/선택 무효화→명시재조회/재선택이며 장비미착용·미확정/replay/현재GET·late차단/성공후관리 흐름은 유지한다. 요약에는 선택서버/이름을 표시한다. GET의 ACCOUNT_BINDING_EVIDENCE_PENDING은 소유연결 보류로 안내한다.

**관련50PASS·lib/test 분석0·format/diffcheck**, [91번째 Flutter 결과](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6216421322). 아래 미게시/대기 문구는 당시 이력이며 새계약 대기는 해소됐다. 새endpoint/DB/journal·Router/DI/flag/키/자료 변경은 없다. 다음 사용자 새빌드 화면/실인증 확인이고 실provider/기기·최초연결실패원인은 미확인이다.


## 최신 구현 — 재진입·응답 유실 UX 선행 보완

2026-10-16. 새 target/version 게시 전 기존 계약으로 가능한 복구 UI를 보완했다. 앱 공용 ViewModel이 시작 대상의 원정대 표시명/ID 또는 직접입력 캐릭터명을 앱 수명 내 보존하고 재진입에도 표시한다. 시작/확인/취소 요청 중·결과 미확정, ACK후GET실패를 구분하며 ID없는 복구불가에서 존재하지 않는 조회를 안내하지 않는다. 원정대 경로는 현재 운영 조회기준을 쓰며 선택 캐릭터를 추정하지 않는다. 표시 문맥은 HTTP body/소유 증거가 아니다. 동일명령/replay후현재GET·세션초기화/late차단과 성공후기존관리는 유지한다. 관련42PASS·변경3파일 분석0·format/diffcheck. [Issue8 87번째 결과](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6215781843). 다음은 Backend 게시→캐릭터 picker/새입력 연결이며 실provider/기기·최초연결실패원인은 미확인이다. 새 schema/영속journal·flag/키/환경/자료 변경 없음.


## 2026-10-16 인증 대상 선택·재진입 복구 계약 대조

[85번째 Backend 제안](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6215438091)과 현재 Flutter 모델·명령/GET 복구를 대조해 [86번째 수용 회신](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6215477051)을 게시했다. registration_id+target_character(서버/이름)+expected_registration_version 입력안은 요구 UX에 맞고 preview UUID/활동1700을 요구하지 않는다. 기존 동일 POST/key/body 회수 후 현재 GET을 재사용하며 별도 결과조회 API/영속 journal은 이번 필수 범위가 아니다. **새 입력은 제안 단계이며 Backend 구현/OpenAPI 게시 전 전송하지 않는다.** 기존 StartIn 배타 계약은 아래 현재 제공 계약이다. 다음 담당은 Backend 게시→Flutter picker·대상요약/단계 보존·복구 UX 연결이다. 실행 계획/검증 경계는 NEXT_WORK를 따른다.


## 기존 장비 인증 재사용 근거 인계 (2026-10-16)

66번째 Backend 자료요청에 대한 회신 https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6210605354 . 고정8f4209deb980660e227134bf1241677875d02e06의 LocalGameAccountVerificationGateway는 최신 siblings/Armory→6부위 완전착용→무작위1~3부위 해제→10분 이내 지정 Type 부재/지정 외 Name·Grade 유지 판정이었다. 당시 challenge는 프로세스 메모리·판정은 클라이언트이며 현재 서버에서 최종 검증하는 근거로 재사용한다. 사용자 요청의 회원/서버·이름/원정대·시도/만료/결과와 타회원 소유 도전 이력은 기존 서버 challenge에 대조한다. 단순 클라이언트 성공 flag로 소유를 부여하지 않는다.

Task-044 과거 Android 인증 성공 기록·2026-09-13 안내/미착용 문구 실기기 기록은 확인했다. 원본 API 누락/null·지연 측정·현재 Backend live 통과는 미확인이다. 과거 자동 장비 인증의 즉시 이전과 운영자 수동 인증의24시간 소유자 방어는 별개다. 수동 분쟁 UI/의미를 보존하되 옛 저장 구현·이름 기반 영구 ID 연결·새 분쟁 API/자동이전 규칙을 이번 정보회신으로 확정하지 않는다. 다음 Backend 설계·구현 대조이며 기존 기능/자료·기본flag는 유지한다.


> 2026-10-16 최신 연결 결과: registration_id 대상 전달·성공 결과 ID의 현재 소유/전체 canonical 재확인→기존 본·부원정대 관리 화면 전환을 연결했다. 과거 인증 성공 상태의 자동 재이동/다른 회원 늦은 전환을 차단하고 실패 시 인증 결과 재확인을 제공한다. 전체1560PASS·분석0. 기본flag OFF/실제 소유·기기 미확인은 유지한다. [인계](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6209931176)·[현재 작업](../project/NEXT_WORK.md).

> 2026-10-16 인계 갱신: 아래 feature/account-verification-client와1282PASS는 해당 구간 완료 당시 기록이다. 현재 인증 연결은 feature/scoped-account-cache의 후속 작업과 함께 보존됐고 C 최종 전체1524PASS/lib-test분석0을 확인했다. 미커밋·미push·dev미반영이며 장비 실증·소유권/이전 보류 해제는 여전히 미확인이다. 현재 직접 다음은 [NEXT_WORK](../project/NEXT_WORK.md), 활동/대표·왕관 UI는 [후속 대장14](14-my-account-flutter-integration-plan.md#flutter-follow-up-20261014)의 별도 작업이다.


## 현재 작업 — 인증 화면·상태 관리 연결 (2026-10-15)

완료 상태: ServerVerificationViewModel/ServerVerificationPage와 BackendApp의 기존 `/settings/game-account-verification` 진입점·DI를 연결했다. 신규 상태 경계 23개와 기존 클라이언트 13개를 포함해 최종 전체 **1282 PASS**, **lib/test 분석 0**, format/diffcheck 완료. 실기기 빌드·설치/장비 조작은 수행하지 않았다. 현재 feature/account-verification-client 미커밋·미push·dev 미반영이다.

새로 가능해진 흐름은 설정에서 등록 원정대/직접 입력 인증 시작·장비 안내·명시 확인/취소·현재 상태 조회, 회원별 앱 수명 진행 보존·같은 요청 복구·남은 대기시간 표시다. 성공/취소 replay 후 현재 GET, GET 실패 시 조회 재시도, GET만으로 미확정 쓰기 해제 금지, 멱등 충돌/만료의 재조회 후에도 복구 제한 유지와 회원/세션 late 결과 차단을 검증했다. 서버 pending/증거 보류는 그대로 안내한다. 확인한 기존 흐름은 전체 회귀 시험 및 로컬 DB/기존 legacy 인증/키·활동 설정 무변경이다.

미확인 실기기 항목: 설정→인증의 등록/직접 입력, 장비 안내/명시 확인과 실제 보류 문구, 취소 알럿 좌우/뒤로가기·재진입/회원 전환과 대기시간 표시. 장비 판정·소유 검증 완료는 이 화면 구현이나 mock 시험으로 인수하지 않는다. 다음 작업은 서버/로컬 ID의 회원·환경·revision 경계와 서버 활동 선택 연결이다. 로그: .dart_tool/verification-ui-final-tests.log, verification-ui-final-analyze.log.

사용자 선행 작업 진행 승인으로 feature/account-verification-client를 재사용한다. 이번 종료 조건은 설정의 기존 인증 진입점을 게시된 API의 화면/회원별 상태 관리에 연결하고 경계를 검증하는 것이다. 신규 제품 결정 없이 기존 등록 선택/직접 입력, 지정 부위 해제 안내, 명시 확인/취소를 사용한다. Backend 대표 구현 cd3e003·회신6184483999는 원격 게시/개발 API 적용 완료이며 dev/main 미통합이다. 대표·활동·ID 연결은 이번 인증 화면과 별도다.

- 순서: 상태 관리와 불변 요청 복구 → 인증 화면 → 기존 설정 Router/DI 연결 → 경계 테스트·최종 lib/test 분석/전체 테스트 → 기록/Issue 회신. 공용 Router 변경을 포함하므로 최종 전체 검증을 실행한다.
- 데이터/권한: 앱 서비스 수명의 ViewModel이 challenge와 미확정 명령을 메모리에 보존한다. 화면 재진입은 이어서 조회하며 앱 재시작 자동 쓰기는 없다. 회원/세션 변경 시 입력·명령·늦은 결과를 비우고 소유권/로컬 DB를 저장하지 않는다. verified 후 서버 등록 목록은 재조회하며 서버 ID 연결·활동 선택 완료로 확대하지 않는다.
- 요청: 연타/동시 쓰기 차단, 매번 명시 확인에 새 UUIDv4 키, 불확실한 응답은 같은 명령/키만 재시도(24시간 이내). 진행 중/멱등 충돌·만료/파싱 실패는 새 명령으로 우회하지 않는다. GET만 성공했다고 진행 중 쓰기를 완료 처리하지 않는다. 성공/replay 후 현재 GET으로 최신 상태를 확인하며 실패하면 조회 재시도를 제공한다. DELETE204도 현재 GET으로 verified/cancelled/expired를 구분한다.
- 시간/오류: 서버 remaining_seconds에서 화면 경과시간을 차감해 남은 시간만 안내하며 로컬 시각으로 verified/expired를 저장하지 않는다. 만료 추정 시 현재 상태 조회를 제공한다. 호출 제한은 남은 대기시간을 표시하고 자동 confirm/polling은 없다. PROVIDER_EVIDENCE_PENDING/ROSTER_EVIDENCE_PENDING과 알 수 없는 결과는 성공으로 바꾸지 않는다. 서버 한국어 required_slots를 그대로 안내한다.
- 회귀 보호: Google 로그인/회원 키·등록 CRUD/서버 조회/로컬 자료와 양 역할 빌드·기존 legacy 인증 화면 보존. 취소 확인은 취소 왼쪽/긍정 오른쪽. 수동 인증 pending route는 변경하지 않는다.
- 최소 자동 검증: 중복 요청/같은 명령 복구·replay 후 현재 GET/GET 실패·취소 후 verified·서버 시간/대기시간·동일 회원 새세션/다른 회원/화면 dispose·보류 code/late 성공·오류. 정상 화면 조작과 실장비/실기기 확인은 사용자 인수다. provider 증거 보류 해제·자료 삭제/DB mapping·배포/Issue 종료는 제외한다.

2026-10-15. 사용자 `진행 가능한 부분` 지시에 따른 독립 구현 단위다. 종료 조건은 게시된 인증 API의 응답/불변 요청·호출 계층과 회원/계약 경계 검증 완료다. 대표 API/왕관과 서버 인증 UI·ID 연결은 이 단위의 선행 조건이 아니다.

## 계약·흐름

기준은 Backend9e1a255b87b430bca314e8f718fb4176bfe322c8와 기존 원본 snapshot contracts/issue7-9e1a255.openapi.json의 StartIn/VerificationOut, 게시 schemas.py의 source_matches다. 새로운 미게시 대표 DTO를 추측하지 않는다.

- POST /v1/me/game-account-verifications: UUIDv4 멱등key, registration/source+registration_id 또는 direct_input/source+character_name, 201 VerificationOut.
- GET 동일경로/{challenge_id}: 200 VerificationOut.
- POST 동일경로/{challenge_id}/confirm: UUIDv4 key, 빈 JSON 객체, 200 VerificationOut.
- DELETE 동일경로/{challenge_id}: UUIDv4 key, 204/본문없음.
- 응답8필드는 challenge_id/status/required_slots/expires_at/remaining_seconds/result_code/result_reference/registration_id. nullable/상태enum/UUID/UTC/엄격정수를 검사한다. result_code는 계약상 nullable string이며 알려지지 않은 업무code를 임의 성공으로 바꾸지 않는다. pending+PROVIDER_EVIDENCE_PENDING/ROSTER_EVIDENCE_PENDING은 보류 그대로다.

## 소유·저장·권한·연결

기존 BackendRegistrationApi의 Bearer/401회복/오류규칙을 재사용한다. 각 명령은 현재회원·세션세대와 멱등key/body를 생성 시 고정하고 같은명령 재시도 시 바꾸지 않는다. 호출 전후 scope 검증, GET/confirm의 응답challenge ID 일치 및 registration start의 등록ID 일치 확인. guest/잘못된입력/이전세션명령은HTTP0이다. 자동 retry/polling·키발급/직접 Lost Ark 호출·기기 journal/로컬 자료쓰기는 추가하지 않는다.

이 계층은 서버 응답만 반환하며 로컬 소유active/서버ID·활동선택을 저장하지 않는다. 이미 존재하는 GameAccountVerificationGateway/옛화면은 성공 시 로컬 binding을 수행하는 다른 계약이므로 여기서 억지로 구현하지 않는다. UI 단계에서는 검증 완료 후 서버 등록/전체roster를 다시 읽고 ID/회원/origin 연결계약을 별도로 확정한다. 실제장비조작·증거보류해제는 Backend/사용자 범위다.

## 회귀·검증·제외

보호: 기존 Google세션·회원키/설정·원정대CRUD/목록·guest로컬·양역할Snapshot·관리화면불변. 신규파일만 추가하고 Router/DI/DB는 변경하지 않는다.

최소 검증: strict응답/보류code·UUID/UTC/nullable, registration/direct 상호배타입력, GET/confirm/delete의경로·상태/body, 불변명령재시도,guest/같은회원새세션/다른회원late응답,응답대상혼합/잘못된본문. 기존 Dio transport에 부착한 fake HTTP로status/멱등header/204도검증한다. 변경파일format/analyze·표적test/diffcheck를한번모아실행,넓은라우터/공용모델변경이없으면전체Flutter시험반복없음.

현재 feature/account-verification-client를devcc6a0b0에서 생성해 사용한다. 이전에 이 채팅에서 작성한 설계 미커밋과 사용자Rules/tools자료는 보존하고 임의stage/commit하지 않는다. 이번 독립코드·직접관련문서만 구분하며 원격push/dev통합은 아직 요청하지 않았다. 구현결과/검증·한계는 종료 시 이 문서와DEV_LOG/NEXT_WORK에 기록하고 관련Issue에회신한다.

## 구현·검증 결과

ServerAccountVerification은 응답8필드·nullable/상태enum·UUID/UTC/엄격정수와 불변 슬롯 목록을 읽고, unknown 업무code도 원문 상태와 함께 보존한다. ServerVerificationCommand는 두 source의 상호배타 입력과 현재회원/세션·UUIDv4key/불변body/요청대상·성공status를 고정한다. ServerAccountVerificationClient는 기존 BackendRegistrationApi 위에서 start/GET/confirm/DELETE를 호출하며 호출 전후/await 복귀 시 scope와 응답대상을 확인한다. late 오류도 이전회원의업무결과로새세션에반영하지않는다. 자동polling/키재발급·저널·DB쓰기/소유mapping은없다.

신규13개와 재사용하는HTTP·세션경계11개, 합계24개 표적시험 통과. 실제 Dio transport에 fake HTTP를 붙여 POST201/confirm200·빈객체/DELETE204·멱등header와 보류응답을 확인했다. 세파일 정적분석0·format/diffcheck통과. 로그는 .dart_tool/verification-client-tests.log 및 verification-client-analyze.log. 제한환경Dart실행경로오류로format wrapper를중단한뒤동일SDK를정상권한으로실행했고format/시험/분석은완료됐다. 외부API·실provider·기기시험은하지않았다.

새로 가능해진 흐름은 UI/상태기계에서 재사용할 게시된 인증 API 호출 기반이다. 보존 확인은 기존 인증HTTP/세션표적시험 및 기존화면/Router/DI/DB무변경이다. 미확인/후속은 인증 화면의 UX·명시확인/취소/만료·재시도기한 상태기계,검증완료후서버roster재조회·검증된ID연결·활동저장,대표왕관/실기기인수다. 신규계층을추가했을뿐실제인증경로가열린것으로보고하지않는다. 공용런타임/라우터/DB변경없음으로전체Flutter시험/빌드는반복하지않았다. 현재코드·문서는미커밋/dev미반영/미push다.
