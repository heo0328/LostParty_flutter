# 나이스단 자동 갱신 복원 설계 — 기존 구조 조사와 UX 협의

> 2026-10-16 최신 구현: 82번째Backend3c8e799를소비해실제provider목록갱신선행을연결했다. source.prepare의ownedPOSTrefresh→새read generation/전체canonical재조회→유효활동집합→상세검사, 앱수명고정명령/ACK·부분실패미소진/성공분보존·Retry-After·회원late차단·원정대진행표시를제공한다. 최종1567PASS·분석0, [인계](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6214686634). 아래77번째누락/미구현은해소전조사이력이며현재실행은NEXT_WORK. 일반GET은저장조회/기본OFF·실provider/기기미확인유지.

## 실제 누락과 필수 순서 — 앱 실행1회 목록 갱신

사용자 확정: 앱 실행1회 갱신은 로스트아크 API 원정대 캐릭터 목록 갱신을 포함한다. 현재 source.prepare→runtime.loadMemberRoster는 저장 metadata/V2 GET만 읽고 상세 Armory를 조회하므로 provider 목록 refresh 선행이 누락됐다. 필요 순서는 본인 원정대별 provider 목록 갱신/서버 반영→전체 canonical/설정 재조회→유효 활성집합 확정→나이스단OFF 제외 상세 검사다. OFF는 목록 갱신 제외가 아니다. 신규 목록 추가는 활동/대표 자동선택이 아니며 실패/부분 응답은 자료 보존·미완료로 남긴다. 회원별1회·준비 실패 미소진·멱등/재시도·세션 fence는 유지한다. [77번째 인계](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6212848615), 다음 Backend 본인 refresh 제공→Flutter 실행 연결. 아래 기존 B/C/1560PASS는 이 provider 목록 선행 완료를 뜻하지 않는다.


> 현재 기준 정정(2026-10-16): 현재 개발환경·개발자료로 개발을 계속한다. 별도 빈 환경/저장공간·기초 재인수는 선행 조건이 아니다. 베타 모집 후 베타 시작 직전에 DB 내용만 비우며 구현·환경을 다시 만들지 않는다. D의 별도 로컬 DB/guest 키 연결은 원래 연결로 복구했다. 기존 회원별 격리·기능/UX는 유지한다. [정정 회신](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6207542428)·[현재 작업](../project/NEXT_WORK.md).

> 2026-10-16 정책 정정: 현재는 베타 이전 개발 단계다. 개발 자료는 베타 전 전체 초기화하며 구 Firebase/테스트 자료 승계·보존형 전환은 요구하지 않는다. 아래 구 기기자료 경로/schema13·정수ID 호환 보존은 당시 C 구현 기록이며 신규 기능의 필수조건에서 제외한다. 새 회원 scoped 저장/자동실행·영속대기·재로그인/기기 간 복원은 유지하고 구 실행 의존 정리는 별도 D로 진행한다. [정책09 D08](09-migration-decisions.md#d08-개발--베타--운영-데이터-수명--사용자-확정-2026-10-16)/[NEXT_WORK](../project/NEXT_WORK.md). 실제 자료 삭제나 코드 제거는 아직 실행하지 않았다.

## C 앱 수명·회원별 주목록/진행 UI 연결 완료 (2026-10-16)

BackendApp가 같은 lifecycle runtime/API/session/remote/catalog/cooldown과 실제 회원 설정·키/gate를 사용해 BackendMemberAccount를 한 번 생성·initialize한다. B controller와 회원 목록 VM은 앱이 소유하며 AppShell/page는 구독만 한다. ON 로그인 `/account`는 회원별 주목록, `/account/device-characters`는 기존 기기 자료다. 기본 BACKEND_LIFECYCLE_READS_ENABLED=false 및 guest·기기 schema13/구 int-ID writer는 보존했다. 아래 착수/B/A 단계의 ‘다음 C·미연결’은 당시 이력이다.

동시 전체 준비는 회원/session/readGeneration 단위로 공유한다. 키 없음/OFF 제외여도 서버 최소 요약·선호/표시/count는 복원하고 상세 원본 없음·미확정/캐시를 표시한다. profile 하나로 양역할+설정을 관찰하며 새 저장은 기존 fresh plan/현재 소유수명·guard/CAS로만 허용한다. 기존 mapper로 로컬 상세를 읽고 UUID를 구 정수ID writer에 전달하지 않는다. 표시 필터/count는 자동 상세 대상에 영향을 주지 않는다.

계정 탭 진행·첫 화면 비차단·준비 해결/결과 수·미완료 상세/서버 저장 별도 재시도·남은 대기시간·설정 변경 안내·선호/표시/순서/count 편집을 연결했다. 숨김 캐릭터도 표시 설정에서 접근하고 로컬 변경/서버 대기/충돌·명시 서버값 수용을 구분한다. 미완료 서버 저장의 개별 해결은 배치 대기 수도 반영한다. 상세 검사 중 개인자료 편집은 잠시 막아 경합을 줄이며 회원 나이스단 설정 변경은 시작 snapshot 정책을 유지한다. 열린 확인창도 회원/session을 다시 검사하고 취소좌/변경우를 따른다.

최종 전체1524PASS(기존1514+신규10), lib/test 분석0. 저장소 전체 analyze는 기존 사용자 tools/roster_rebalance_domain_fixtures.dart의 info3건만 남는다. 실제 SQLite/모의 HTTP에서 준비 공유·전체 상세/복원 경합·키 없음·OFF 숨김·로컬 선반영/같은 명령 재시도·회원 전환 지연 응답/확인창·계정 gate 지연 ACK·개별 해결 집계·페이지 폐기 후 앱 runner 보존을 검증했다. 실제 서버/provider·새 기기/재설치·실기기 인수는 미확인이다. 다음 순서와 수동 체크리스트는 [NEXT_WORK](../project/NEXT_WORK.md), 협업 회신은 DEV_LOG다. 추가 제품 결정/Backend 코드 수정 요청은 없으며 실제 서버 적용/기능 ON은 별도 준비 확인 후다.

## C 착수 설계·회귀 게이트 (2026-10-16)

사용자 `진행합니다`로 C 앱 수명/회원별 주목록·진행 UI를 구현한다. feature/scoped-account-cache/cc6a0b0와 이전 미커밋/사용자 자료를 보존한다. 새 schema/API·왕관/파티·활동 선택 신규 기능·실서버 적용/배포는 제외한다. 기존 BACKEND_LIFECYCLE_READS_ENABLED 기본false를 유지하며 ON의 로그인 경로에만 새 회원 화면을 주입한다. OFF/guest는 기존 화면·새 DB/V2 0호출이며 실제 서버 준비 전 무조건 ON하지 않는다.

순서/완료: (1) runtime의 현재 회원 전체 roster 준비 조회를 B/목록 복원 사이 세션·readGeneration별로 공유하고 A1 역할 캐시 표시 read/단일 profile 기반 역할+개인설정 복원을 연결 (2) app 소유 binding이 현재 설정/키/계정gate→B access·source.changes를 주입, controller와 회원 목록 VM만 소유하고 page/shell은 구독만 수행 (3) 회원별 원정대 섹션/역할 요약·상세원본·P2 선호/표시/순서/count와 준비/진행/해결/각재시도·충돌 화면 (4) ON 로그인/guest/OFF Router·원래 기기자료 경로/보존·dispose·회원 전환/동시 복원·자동 갱신 핵심 경계 및 최종 전체 test/analyze·format/diffcheck/Issue 회신.

ON 로그인 `/account`는 canonical 회원 주목록 하나이며 기존 기기 자료는 `/account/device-characters`로 접근한다. 비로그인·OFF는 기존 MyAccountPage를 보존한다. 원정대 등록/관리·인증·키·기존 서버 상태/이력 routes는 유지한다. 새 캐릭터 상세는 UUID와 역할 저장공간을 읽고 local int-ID 상세 writer에 전달하지 않는다. 로컬 원본이 있으면 기존 분석 mapper로 장비 항목을 표시하고 없으면 마지막 요약/확인시각·원본없음을 알린다. 선호/표시/순서는 단건 문서 저장, count는 원정대별1~200·기본6이며 숨김 캐릭터는 표시 설정 경로에서 재접근 가능하다. 회원 전환 중 열린 dialog는 captured scope/session을 재확인한다.

캐시 먼저 표시 후 현재 등록/전체 roster·P2 profile/설정 복원을 수행한다. 캐시/실패·미수집은 현재 서버 확인 성공/기본값으로 승격하지 않는다. role/profile 복원과 B Armory가 경합해도 row CAS/현재 관찰 guard를 유지하고 UI read가 새 로컬 pending을 덮지 않게 한다. B 완료·명시 재시도 후 목록을 갱신하되 Armory를 새로 호출하지 않는다. 탭 spinner는 B 진행/준비, 본문에는 처리/전체·saved/경고/incomplete/excluded/serverPending와 원인을 표시한다. cooldown은 표시만 갱신하고 실패한 상세/서버 저장·개인설정 전송/충돌 수용을 분리한다. 설정 문구는 실제 ON 연결 여부에 따라 ‘준비 중’ 또는 앱 수명1회/OFF예외로 표시한다.

회귀 보호: 기기 schema13/구 자료·원래 MyAccountPage/상세/관리·비로그인/OFF/V1·S1~S3/A1/A2/B·키/인증/나이스단 의미·좌취소/우긍정. 실기기로 보는 정상 UI 자동 테스트는 중복하지 않고 회원/세션/지연 응답·준비 공유/중복·캐시 및 미확정 보존·동시쓰기/처리중 대화상자·dispose/라우트 소유 등 자동 경계에 집중한다. 실환경 DB0007~0009/API 미전환은 별도 준비/인수이며 코드 연결 완료와 구분한다.

## B 실행부 구현·검증 완료 (2026-10-16)

UUID 전체 roster projection·공용 NiceGroupCandidate 정책, RuntimeStartupRefreshSource와 앱 수명 ScopedStartupRefreshController를 구현했다. **전체1514PASS(기존1479+신규35), 최종 직접 경계35PASS/분석0**. 아래 B 착수 설계의 포함 범위를 완료했고 현재 앱 생성/Router·화면 주입은 **C 후속**이다. 실기기 인수나 실제 서버 자동실행 완료가 아니다.

준비 실패/부분 roster·키/설정 미준비는 미소진, 준비 후 환경+회원별1회·대상0 종료·동시진입 공유, 시작 설정/대상 고정·OFF 제외·양역할/경고 저장을 연결했다. 남은 UUID만 최신 조건으로 재시도하고 새 대상/기존 성공/정책 제외를 편입하지 않는다. 키/회원/관찰 무효화는 늦은 원자 저장을 차단한다. 로컬 commit receipt는 이후 취소와 구분해 보존하고 서버 pending은 상세 재조회 없이 별도 재전송한다. 429 대기 만료는 자동 요청을 실행하지 않는다.

### C가 소비할 실행 연결 계약

- BackendApp 수명에 단일 source/controller를 생성하고 명시 initialize한다. source/runtime/remote/catalog/session/cooldown은 같은 객체를 공유한다. 페이지는 상태만 구독하고 controller를 생성/폐기하지 않는다. 기존 AppShell runner의 폐기 소유를 먼저 대조한다.
- `readAccess`는 현재 회원 설정 value가 존재하고 !busy/!hasPending/failure없음일 때만 bool/settingsVersion을 제공한다. 개인키는 configured/localReady·현재 value/version·!busy/!hasPending/failure없음이 준비 조건이다. 미준비는 null이며 false/임의version을 넣지 않는다. keyVersion은 키 복원/교체/삭제 중 즉시 null이다.
- 계정 변경 요청의 pending gate를 accountChangesPending에 전달하고, 설정/키/계정 gate 변경을 source.changes로 알린다. runtime.invalidateReads의 readGeneration은 B 준비/실행 snapshot에 포함돼 DB row 미변경이어도 transaction guard에서 취소한다. 완료 후 새 준비 없이 이전 배치를 재사용하지 않는다.
- 회원별 registry는 controller 앱 수명만 유지한다. 같은회원 재로그인/탭/복귀 자동 반복은 없고 미완료 명시 재시도다. 로그아웃/회원전환 시 공개 items는 즉시 현재 scope로 한정한다. 전체 앱 재시작은 새 controller이므로 새1회다.
- `startIfReady`, `retryIncomplete`, `retryServerSaved`는 별도다. serverPending은 local saved/경고와 함께 집계되며 incomplete 상세 대상에 넣지 않는다. 서버 재시도는 키/나이스단 준비를 요구하지 않고 A1의 현재 접근/멱등·수명 검증을 따른다. conflict/review/blocked 해결은 명시 A1 server-value 수용 등 후속 UI에서 안내한다.
- 화면 상태는 phase/failure·items/total/processed/saved/warning/incomplete/excluded/serverPending·settingsChanged와 공용 cooldown을 소비한다. 첫 화면을 기다리게 하지 않는다. 실제 canonical 주목록/기존 자료 별도 경로·P2 설정/역할 요약은 C에 연결한다.

새 DB/endpoint·server contract 변경은 없다. API/실DB0007~0009 미전환 및 live 보류는 그대로다. 검증/회신과 다음 단일 C 범위는 DEV_LOG/NEXT_WORK를 따른다.

## B 착수 설계·회귀 게이트 (2026-10-16)

사용자 `진행`으로 B만 구현한다. app/controller 수명의 환경+회원 registry와 explicit initialize/startIfReady·미완료 재시도·서버 저장 재시도를 준비한다. C의 BackendApp/Router/화면 생성·실행 주입은 아직 켜지 않는다. 기존 feature/scoped-account-cache/cc6a0b0·이전 미커밋/사용자 자료를 보존한다.

순서: UUID 순수 전체 roster projection→나이스단 공용 분류 입력 확장→실제 runtime/catalog/Armory adapter→앱 수명 controller의 준비·1회/취소·재시도 상태→핵심 경계/전체회귀·분석·문서/Issue 인계. 새로운 DB/API는 없고 A1/P2 원본7027f0b·schema3를 소비한다.

adapter는 현재 인증/회원 설정 GET 성공·미확정 설정 없음/개인키 로컬복원·version/카탈로그와 전체 등록·소유 원정대 complete roster를 같은 세션에서 준비한다. preview/소유상실은 자격 제외, owned roster 하나 실패는 준비 실패/1회 미소진이다. 전체 활동 UUID를 선택하며 표시 설정/상위 개수/1700 필터로 활성 대상을 줄이지 않는다. NiceGroupPolicy는 local 모델을 만들지 않는 공용 후보 입력을 받아 기존 직업정규화·사용레벨/2명 분류를 그대로 재사용한다. 분류는 전체 현재 active roster의 캐릭터(활동 미선택 포함)를 사용하고 suspect/retired는 분류에서 제외한다. 활동 대상의 레벨 제한과 나이스단 분류의 기존 사용레벨 정책은 별개다.

처음 실제 시작할 때 registry를 동기 선점한다. 준비·키·설정 변경/조회 실패는 미소진, 같은회원 새세션도 실행 이력 유지, 새 회원/환경은 분리한다. 시작 대상/설정은 고정하며 설정 변경은 다음 실행/명시 미완료 재시도부터다. 키/회원/수명·등록 변경은 A1 plan 발급 전후/Armory 후/원자 저장 내부 guard로 차단한다. 이미 커밋된 저장은 기록하고 서버 전송 실패는 별도 pending이며 상세 재조회 미완료로 되돌리지 않는다.

미완료 재시도는 최초 실패/중단 UUID만 최신 준비·활동/자격/나이스단 정책으로 재평가하고 성공·새 캐릭터/기존 정책제외를 편입하지 않는다. 429는 공용 cooldown deadline을 표시하고 미완료를 남기며 만료가 자동 네트워크를 실행하지 않는다. 서버 저장 재시도는 기존 유효 A1 명령만 처리하며 Armory/키 준비·나이스단ON을 새 조건으로 요구하지 않는다. session/private 상태는 즉시 분리하고 돌아온 회원은 명시 재시도다.

회귀 보호/완료: 기본 OFF/guest0호출·기존 startup/나이스단 정책/기기 schema13·S1~S3/A1/A2, 준비 실패/동시진입·회원별1회/대상0·전체활동/숨긴대상/레벨·OFF분류/역할실패/장비경고·local commit후취소/서버pending·회원/키/등록/수명 guard·429/실패만재시도·dispose 경계를 검증한다. UI/디바이스 테스트·실API/배포·자료이관/삭제·왕관/파티/Git통합은 제외한다.

## A2 개인설정·원정대 표시 저장 기반 완료 (2026-10-16)

사용자 `a2 진행합니다` 승인으로 P2 원본7027f0b를 대조·연결했다. strict 실제 preferences/원정대표시 GET/PUT, scoped schema3·영속 초안/명령·등록/소유/캐릭터 guard와 CAS·재실행/충돌/명시 서버값 수용, 캐시 표시 복원·원정대별 순수 표시 정렬을 구현했다. **전체1479PASS(신규47)/lib·test분석0**. 상세 장기 계약·원본 해시는 [계약30 상단](30-scoped-storage-write-contract.md), 완료 이력은 DEV_LOG를 따른다. P1 역할 wire는 유지하고 profile의 preferences만 P2 실제 저장값으로 읽으며 과거 가상값을 설정 저장 성공으로 승격하지 않는다.

다음은 **B 활성 대상 상세1회 자동 실행 controller**, 이후 C 회원별 주목록/진행·재시도 화면이다. A2는 명시 호출 기반이며 자동 Armory 조회나 화면 전환을 켜지 않았다. 나이스단 OFF 제외·반대 역할 보존·시작 당시 설정과 대상 고정·로그아웃 지연 저장 차단 등 기존 합의는 유지한다. 추가 제품 선택은 현재 없고 아직 디바이스 테스트 단계가 아니다. 아래 A1 당시 ‘다음 A2/P2 대기’는 이력이다.

## A1 저장 기반 구현·자동검증 완료 (2026-10-16)

사용자 ‘백엔드 대기 동안 가능한 작업 진행’ 승인으로 P1 원본6e4f625만 소비하는 strict 역할 GET/PUT·기존 분석/역할 정책 projection·회원별 상세/요약·영속 전송 대기를 구현했다. **최종 전체1432PASS(기존1394+신규38), lib/test 분석0**, format/diffcheck다. 실제 임시 SQLite·모의 HTTP 검증이며 실서버/기기 인수가 아니다. 아래 P1 수신 당시 ‘다음 A1/코드 변경 없음’은 당시 이력이다.

- scoped DB schema2는 기존4캐시 위에 역할기록/명령2테이블과 account/character 복합 FK용 고유 index만 추가한다. 기존행 migration 보존·기기 schema13/구 int-ID writer·반대 역할/설정 보존을 확인했다.
- canonical 전체 roster/등록·소유수명·현재 P1 GET/세션/키·run guard·row CAS를 transaction 시작/끝에 확인한다. 원본/최신 요약과 미발송 명령은 원자 저장하며 발송 명령은 변경하지 않는다. 지원 직업도 현재 패시브/카탈로그 근거 없이 선호역할로 새 자동 저장하지 않는다. 장비 오류는 확정 계열에 저장하고 unavailable/nullable 수치·시각을 보존한다.
- 응답 유실·재실행은 같은 key/body를 복구하고 429는 수신 시점 고정 deadline을 사용한다. 최초 발송24시간 초과/시계 역행은 자동 전송을 멈추며 다른 기기 version은 자동 보정하지 않는다. 지연 ACK는 해당 명령만 확정하고 최신 초안/반대 역할을 지우지 않는다. 명시 서버값 수용 API와 상태를 준비했으며 UI는 후속이다.
- runtime의 단일 DB/API/session에 명시 prepare/save/read/sync를 연결했다. 기본 OFF/guest에 새 DB·HTTP0을 보존한다. **자동 Armory 실행·회원 주목록/진행 화면은 미연결**이며 아직 디바이스 테스트를 요청하지 않는다.

작업 중 [Backend P2 완료6195735441](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6195735441)을 수신했다. 불변 원본7027f0b와 실제 preferences 교체/새 개인설정·원정대표시 경로는 **다음 A2에서 원본 전체 대조 후 소비**한다. P1 가상 preferences를 실제 복원으로 적용하지 않았다. 다음 순서 A2→B 자동 실행→C 회원 주목록/진행 UI이며 추가 사용자 결정은 현재 없다. Backend143PASS는 격리/mock 결과, 실DB/API 미전환이다. 다음 범위·Git/회신은 [NEXT_WORK](../project/NEXT_WORK.md), 완료 이력은 DEV_LOG를 따른다.

## P1 구현·원본 수신 완료 — Flutter A1 연결 가능 (2026-10-15)

[Backend P1 완료6194881739](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6194881739)의 정확한 원본을 확보·검토했다. **구현/계약 SHA `6e4f625c3b62c92ec412373b33ed8a3441af8149`**, [원문](https://github.com/heo0328/lostparty-backend/blob/6e4f625c3b62c92ec412373b33ed8a3441af8149/openapi/openapi.yaml), 로컬 [원본 snapshot](contracts/issue8-6e4f625.openapi.yaml), SHA256 `52a2c491c293a97813cf46ce4eff487b889ba0481de0654f4fcf0b5cc9c9cd6b`. 현재 원격 b31e7c85는 이 원본 이후 인계 문서만 바꾼1개 후속 commit이며 구현 소비 기준은6e4f625다. feature branch push됐고 dev/main 미통합이다.

- 실제 P1은 personal-profile GET과 role-summaries/{role} PUT 두 경로, 새 schema7개다. 이전 c91af2e와 전체 기존 paths/components를 YAML/JSON 파싱·수치형 표기1/1.0 동등 정규화 후 비교해 변경0을 확인했다. 무결성4상태/카탈로그·summary11필드·strict/필수nullable/상한·수치 regex를 수용 계약과 대조했다. 데이터·실제 API를 조회한 검증은 아니다.
- **preferences는 P2 미구현의 고정 가상값**이다. version1/preferred_role=null/visible=true/display_order=null/saved_at=null만 제공되며 이를 사용자 설정 저장 ACK/복원 완료로 취급하거나 기존 설정을 덮지 않는다. P2에는 별도 게시 스키마가 필요하다. P1 원본에 미래 개인설정 PUT/원정대 표시 계약을 추가해 해석하지 않는다.
- Backend 보고 최종171PASS는 격리 PostgreSQL/mock fixture 결과다. 이전108과 합산하지 않으며 Flutter 시험/실provider·기기 통과가 아니다. 실제 실행 서버/DB0007·0008/API는 미전환이므로 원본 게시와 실환경 준비를 구분한다. 이 상태는 Flutter A1 모의 구현·검증을 막지 않는다.

[수신·대조 회신/P2 요청6195124835](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6195124835)을 게시했다. **Flutter 직접 다음은 A1 strict P1 adapter·scoped 역할 상세/서버요약/영속 대기·오류/충돌 연결**이다. Backend는 별도 P2 개인설정/원정대별 표시/정리 경계 코드·격리검증·OpenAPI/불변SHA 게시를 요청받았다. 실제DB migration 실행·API환경 전환/배포·기기 설치/인수·실자료 이관/삭제·live 퇴역 보류 해제는 요청하지 않았다. 현재 사용자 지시는 문서 회신 확인이므로 이번에는 원본/문서 대조·계획 갱신만 했으며 기능코드 변경/테스트 재실행은 없다.

## 수정 계약 수용·Backend P1 구현 요청 (2026-10-15)

사용자 `진행합니다`로 [수정안6193183186](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6193183186)을 실제 Flutter와 대조해 수용하고 [P1 구현 요청6193638580](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6193638580)을 게시했다. 아래 ‘미합의/수정 회신 대기’는 당시 이력이며 **제품/계약 합의는 완료, 실제 P1 코드·검증·OpenAPI 원본 게시 대기**가 현재 상태다. P2 개인표시/선호는 계약 수용됐지만 P1 인계 후 별도 구현 단위로 요청한다. 실DB migration 실행/배포·기기 인수 승인은 아니다.

- summary의 outcome은 제거하고 필수 `integrity_status`/`catalog_version`을 사용한다. clean=빈issues, review=warning1개이상/error없음, error=error1개이상, unavailable=빈issues또는warning/error없음. 카탈로그는 nullable 식별자로 별도 보존하며 null 여부로 정상 판정을 추정하지 않는다. 최종 P1 OpenAPI를 받기 전 wire DTO/HTTP adapter를 구현하지 않는다.
- 원정대별 presentation-settings의 등록/계정/소유·등록version/개인version·visible_count/saved_at7필드, strict1~200/기본6개·nullable saved_at을 수용했다. 회원 전역 endpoint/기본전체표시는 폐기다. 같은 소유수명 재등록은 현재 신뢰된 canonical 연결로 복원하고 옛 경로/불명확 명령을 새 등록에 자동 이식하지 않는다. 기존 visible 필터 후 대표 우선 정렬과 부합하며 숨긴 대표를 강제로 보이게 하지 않는다.
- 나이스단은 회원 bool 하나이며 캐릭터/원정대별 override를 추가하지 않는다. 활성 대상 상세1회와 OFF예외, 기존 유효 pending의 복구 분리는 유지한다. 준비 조건·회원 전환/취소·오류 저장/반대 역할 보존 합의도 유지한다.

### Flutter A 저장·동기화 구현 준비

P1의 최종 wire/필수·null/오류·소유수명/멱등을 검증한 뒤 다음 최소 A1을 구현한다. 이 순서는 P1 코드 제공을 가정해 endpoint를 먼저 호출하는 계획이 아니다.

1. 서버 canonical 조회 캐시와 역할별 기기 상세/서버 확정 요약·전송 대기를 분리한다. 개인자료는 `(환경+회원, character UUID, ownership_revision, role)`로 구분해 같은 회원이라도 새 소유수명에 옛 자료를 승계하지 않는다. lifecycle_revision은 분석 출처/저장 fence이며 소유수명 대체키가 아니다. 기존 schema13/로컬정수PK는 건드리지 않는다.
2. 조회·역할판정/검증이 성공한 로컬 상세/요약 초안과 outbox를 한 transaction에 기록한다. outbox는 미발송 초안과 발송 후 불명확 명령을 분리하고 불변 command ID/key/body/예상version·대상/관찰 소유수명·최초발송시각/상태를 갖는다. ACK는 해당 명령만 정리하며 이후 새 초안·반대 역할·다른 회원 자료를 지우지 않는다.
3. 현재 same-member scope/session/소유수명·캐릭터 관찰/키/run 유효성·row version을 원자 저장 경계에서 재검증한다. 로그아웃/키교체/삭제 후 늦은 응답을 UI에서만 숨기고 DB에 쓰는 것을 허용하지 않는다. 서버 replay ACK는 현재 요약이 아니라 과거 명령 확인이고 최신 서버값은 GET으로 수집한다.
4. 수치 문자열/UTC/null·카탈로그/분석규칙·issue 고정 범주와4상태 조합을 순수 projection에서 검사하고 기존 mapper/역할 정책을 재사용한다. info/슬롯별 notice를 그대로 오류로 업로드하거나20개를 임의 절단하지 않는다. 새로운 분석 규칙 version은 schema/dataVersion과 독립적으로 관리한다.
5. 최소 A1 검증은 소유수명/회원/같은이름새UUID·양역할 독립, 빈issues unavailable, 역할 실패 보존/경고 저장, 로컬상세+outbox rollback, 새 초안 뒤늦은 ACK, 명령 유실/restart/24시간 보수복구·version 충돌, transaction 중 취소/키/수명 변경에 집중한다. P2 API가 없을 때 개인설정 쓰기/주목록 전환을 성공으로 표시하지 않는다.

A1 이후 A2 개인설정/표시 복원과 B 실행 controller/C 단일 주목록을 연결한다. Backend P1 인계만으로 전체 자동 갱신 또는 디바이스 테스트 단계라고 보고하지 않는다. 공통 준비/진행·재시도·화면 흐름 설계는 P1 게시 대기 중에도 정리할 수 있고 실제 adapter/저장 migration은 최종 계약을 확인한 후다.

## Backend 계약 검토 수신·Flutter 대조 (2026-10-15)

[제안6191634445](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6191634445)을 원문 전체 확인하고 실제 Flutter 모델/정책과 대조했다. Backend 보고 상태는 구현/OpenAPI c91af2e·작업 HEAD dc09901이며 **새 구현/원본·DDL 없음, 미합의 계약안**이다. [Flutter 회신6192838766](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6192838766)에서 부분 수용과 아래 두 보완을 요청했다. 새 wire 소비/구현·실DB/배포 승인이 아니다.

- 수용: canonical 원본과 별도 personal-profile/role-summary/preferences 분리, 회원+UUID+소유수명/역할 격리·GET 무쓰기/양역할 독립version·nullable 기본값, 출처시각/서버 ACK 구분·provider/활동·대표 불변, 현재 수명/권한과 replay 검사, 같은key/body/24시간 보수 복구·오래된 대기 자동덮기 금지, 단건 제한 동시성 복원. 부분 rank ACK도 저장 대기를 구분하는 조건으로 수용하며 새 batch API는 요구하지 않는다.
- **보완1 — 판정 불가 복원:** 실제 BuildIntegritySnapshot은 clean/review/error/unavailable과 nullable catalogVersion을 가진다. mapper는 issueCodes=[]여도 grid 최소근거가 없으면 unavailable일 수 있어 제안 outcome success/warning+issues만으로 정상/확인불가를 항상 복원할 수 없다. typed integrity_status 또는 동등 필드/valid 조합과 nullable catalog_version 보존을 요청했다. 성공한 분석과 정상 빌드는 같은 개념이 아니다. 역할 판정/통신/파싱·로컬 저장 실패는 기존대로 업로드하지 않는다.
- **보완2 — 기존 원정대 표시 UX:** 현 GameAccounts.displayLimit 기본6개와 원정대별 대표→사용자 순서→아이템레벨 내림차순→이름 정렬을 보존해야 한다. 회원별 단일 주목록은 원정대 섹션을 없앤다는 결정이 아니다. Backend 제안의 회원 전역 rank/기본 전체표시 대신 회원+canonical 원정대/소유수명별 표시 개수·정렬 복원을 요청했다. 정확한 DTO/경로·상한은 수정 제안 대기다. 사용자에게 전역 표시 전환을 승인받았다고 추정하지 않는다.
- 모델 대조: 현재 dealer/support 모두 profile CombatPower/ItemAvgLevel을 저장하고 별도 버프력/서포터 점수 모델이 없어 이번 nullable 수치안은 수용 가능하다. 원본 string 정규화·finite/길이 검사 후 plain decimal로 보내며 스키마 dataVersion을 분석 규칙 version으로 재해석하지 않는다. 기존 통합7종 코드와 추가 notice는 고정 대문자 범주로 정규화·중복제거, 상세 slot/자유문장은 로컬 전용이다. 최대20/strict 형태는 요약 범주 기준 수용 가능하고 임의 절단/정보성 안내의 오류 승격은 하지 않는다.
- **나이스단 의미 정정 완료:** 기존 회원 공통 bool 하나를 유지한다. false는 나이스단 직업군으로 분류된 활성 캐릭터를 자동 대상에서 제외한다는 뜻이며 새 캐릭터별 bool/override/AND 규칙을 요청하지 않았다. OFF 변경으로 원본을 새로 조회하지 않으며 기존 유효 pending 전송 복구와 새 분석을 구분한다. 이를 다시 사용자 결정 대기로 돌리지 않는다.

현재 대기는 Backend의 두 보완 계약 회신이다. 사용자가 이미 정한 세 제품 선택은 유지하고 공통 실행/동기화·화면 설계는 계속 정리 가능하다. 새 endpoint/DTO를 추측해 구현하지 않는다.

## 사용자 확정 — 복원 범위·저장 대기·회원별 주목록 (2026-10-15)

사용자가 아래 세 추천안을 모두 선택했다. 이 절은 아래 ‘저장 개념 재확인/추가 UI 결정’ 당시 미선택 상태를 대체한다. 기능코드/DB 변경 지시는 아니며, 확정 정책을 저장/동기화·화면 계약으로 구체화하는 설계 단계다.

1. **서버 최소 복원:** 회원/원정대/캐릭터 신원·활성 목록·나이스단 설정에 더해, dealer/support 각각의 핵심 수치·오류 요약·확인 시각과 선호 역할·표시 설정을 복원한다. 보석/스킬/패시브/그리드 상세 원본·분석 원문은 로컬 전용이다. 현재 역할을 조회해도 반대 역할의 마지막 저장 요약을 지우지 않는다.
2. **로컬 우선 반영·서버 저장 대기:** 상세 조회/판정과 유효성 검증·로컬 원자 저장이 성공하면 현재 기기 화면에 반영한다. 서버 미확정 상태는 ‘서버 저장 대기’로 표시하고 같은 회원/환경·같은 캐릭터 수명의 유효 자료만 재전송한다. HTTP 성공/ACK 전에는 다른 기기 복원 완료로 표시하지 않는다. 로컬 저장도 실패한 경우 성공으로 표시하지 않는다.
3. **로그인 주목록 하나:** 로그인 회원의 canonical ID 목록을 주목록으로 표시하고, 기기의 기존 공용 캐릭터 자료는 ‘이 기기에 저장된 기존 캐릭터’ 같은 별도 경로에서 유지한다. 두 목록을 일반 주화면에 중복 나열하지 않는다. 기존 자료를 이름으로 자동 연결/이전/삭제하지 않는다. 기존 기기 자료 접근과 비로그인 로컬 동작은 보존한다.

### 서버 요약·개인설정 계약 검토 범위

- 역할 요약: 캐릭터 UUID+role, 전투력/아이템 레벨의 nullable 값·관찰 시각, 분석 성공/경고 상태, 구조화된 오류 코드/최소 요약, 분석 규칙 버전·출처와 동시 수정용 version. 상세 원본/키/토큰/장비 툴팁 전체는 업로드하지 않는다. 입력 길이/코드 개수 제한은 Backend와 확정한다. 클라이언트 분석 요약을 기존 서버 provider 전투력 관찰·소유/활동 자격을 덮는 값으로 취급하지 않는다.
- 개인설정: 선호 역할 nullable, 표시 여부/순서/개수 등 주목록 복원에 필요한 값. 활동/대표는 기존 canonical 설정을 재사용하며 표시 설정으로 활동 여부를 바꾸지 않는다. 주간 완료 이력·전체 기기 환경/원문 이관까지 자동 확대하지 않는다.
- Backend c91af2e OpenAPI 대조: V1 character-settings는 활동/대표·revision만, member-settings는 나이스단 bool/version만 제공한다. V1/V2 character와 power refresh도 역할별 빌드 요약/오류·선호역할/개인 표시 복원 계약이 아니다. 따라서 확정 범위의 **요약·개인설정 read/write·version/멱등/경합 계약 보완이 필요**하며 endpoint/DDL/wire를 Flutter가 임의 확정하지 않는다. 기존 S3b 단계의 ‘추가 Backend 요청 없음’과 이번 신규 승인 범위를 구분한다.

### 로컬 저장 대기·재전송 설계

scoped 역할 자료와 업로드 대기 레코드를 같은 로컬 transaction으로 기록한다. 대기 레코드는 환경+회원+캐릭터 UUID+role/설정 종류, 불변 operation ID·payload·예상 서버 version·관찰 수명과 상태를 가진다. 앱 종료 후에도 남되 토큰/키는 넣지 않는다. 새 세션의 같은 회원이 로그인하면 현재 등록/소유·캐릭터 수명/서버 version을 재확인한 후 재전송하고 다른 회원 전환 시 전송/표시를 중단한다. 미확정 요청은 동일 멱등키/body로 재전송하며, 서버와 경합하면 현재값 확인 후 오래된 결과로 덮어쓰지 않는다. 전송 중 body를 바꾸지 않고 뒤의 새 결과는 별도 순서로 관리한다. 무한 재시도/고빈도 polling 대신 복구 기회·명시 재시도/공용 cooldown을 사용한다. 실제 재시도 기한·충돌코드는 Backend 계약에 따른다.

조회/분석 실패, 회원/키 변경 중 늦게 온 결과는 대기 업로드로 되살리지 않는다. 이미 유효하게 저장한 관찰의 요약 재전송은 상세 Armory 재검사와 다르며, 나이스단 OFF를 이유로 상세 조회를 재시작하지 않는다. 나이스단 OFF 캐릭터는 마지막 서버 요약/로컬 상세를 유지한다. 다른 기기는 아직 미전송된 값 대신 마지막 서버 확정값을 보며 이를 현재 기기와 항상 같다고 보장하지 않는다.

### 사용자 화면·새 기기

로그인/재실행은 해당 회원 캐시로 즉시 표시한 뒤 서버 요약/설정을 복원한다. 캐시 없는 새 기기에서는 로딩 후 서버 목록·역할별 요약·선호/표시 설정을 보여준다. 대상 활성 캐릭터는 나이스단 OFF 예외를 적용해 화면 진입과 무관하게 전원의 상세를1회 갱신한다. 서버 복원 성공을 상세 검사 완료로 표시하지 않는다. OFF 나이스단은 재설치 후에도 강제 검사하지 않으며, 원본이 없으면 ‘마지막 저장 요약’과 확인 시각을 표시하고 상세 자료가 없음을 알린다. 저장된 요약조차 없으면 ‘저장된 정보 없음’이며 새 정상/오류를 추정하지 않는다.

진행 결과는 로컬 저장 완료·경고·조회 미완료·정책 제외·서버 저장 대기를 구분한다. 조회 실패의 ‘미완료 다시 시도’와 저장만 실패한 ‘서버 저장 재시도’를 혼동하지 않는다. 기존 API 캐시와 로컬 pending의 우선순위를 version/상태로 관리해 서버의 이전 확정값이 현재 기기 pending 화면을 조용히 덮지 않게 한다. 회원 전환은 즉시 private 화면/작업을 분리하고 해당 회원만 복원한다.

## 사용자 교정 — 활성 캐릭터 상세 자동 조회와 나이스단 예외 (2026-10-15)

이 절이 아래 검토안의 대상/조회 시점 설명보다 우선한다. **앱에서 사용하도록 활성화한 모든 캐릭터**를 앱 실행 중 회원별1회 상세 조회해 전투력·보석/스킬 일치·아크패시브/역할·아크그리드 오류를 검사한다. 캐릭터 상세 화면을 여는 것이 검사 선행 조건이 아니다. 원정대 전체 등록 캐릭터를 무조건 상세 조회하거나 화면에 보이는 상위 카드만 조회하는 것도 아니다. 앱 활동 활성화와 표시 개수/순서는 구분한다.

**나이스단 자동 갱신 OFF는 필수 UX 예외다.** 동일 직업 캐릭터 간 보석을 돌려 쓰고 종료 전에 창고에 보관하는 사용 방식을 지원한다. OFF인 나이스단 캐릭터는 활성 상태여도 실행 시 자동 상세 조회/검사/덮어쓰기에서 제외하고 기존 저장 빌드·오류 정보·확인 시각을 유지한다. ON이면 활성 나이스단도 동일하게 상세 조회/검사한다. 제외는 실패/부정 의심으로 표시하거나 미완료 재시도에 자동 편입하지 않는다.

이 요구를 이유로 파티 생성/참가/캐릭터 변경 때 강제 재검사를 새로 추가하거나 나이스단 예외를 우회하는 제한을 설계하지 않는다. 기존 서버 소유/활동 권한 검증은 별개이며, 새 ‘최신 검사 없으면 사용 금지’ 정책을 이번 기능에 끼워 넣지 않는다. 과거 대화의 강제 재검사 제안은 철회한다. 정책상 제외와 실제 조회 실패를 구분하며, 조회 실패로 새 정상 판정을 만들지 않는다.

대상 공식: **앱 사용 활성 캐릭터 집합 − (나이스단 허용 OFF일 때 나이스단 집합)**. 기존 나이스단 분류 근거는 유지하되, 자동 대상에 별도 미합의 레벨 필터를 추가하거나 비활성 캐릭터를 편입하지 않는다. 역할 판정 실패 보존/역할 확정 후 경고 저장·진행/재시도·준비 조건과 회원 격리 합의는 유지한다. 현재 구현 완료가 아니라 설계 기준 수정이다.

## 다음 구현 기획 — 회원별 전체 빌드 자동 갱신 (2026-10-15)

사용자 최신 지시는 **기획·설계와 UI/UX 추가 동의 여부 확인**이다. 이번에는 기능코드/DB/플래그를 변경하지 않는다. S3b는 서버 현재 상태·이력 조회 연결 완료이며 자동 갱신 완료가 아니다. S3b의 1394PASS/분석0은 조회 연결의 검증이다. 자동 갱신 전체 연결과 검증 전에는 자동 갱신 디바이스 테스트를 요청하지 않는다.

### 설정 의미와 기존 합의

- `nice_group_auto_refresh_enabled`는 나이스단을 자동 갱신 대상에 **포함할지** 정하는 회원 설정이다. 전체 자동 갱신을 끄는 마스터 스위치가 아니다. ON이면 대상 나이스단도 포함하고 OFF이면 나이스단을 제외한다. 현재 기본OFF·즉시 서버 저장/재로그인 복원은 이미 구현·사용자 확인됐다. 새 전체 ON/OFF 설정/API는 이번 제안에 추가하지 않는다.
- `BACKEND_LIFECYCLE_READS_ENABLED`는 서버 V2 조회 경로의 개발 설정으로 별개다. 자동 갱신 허용값/실행 완료 상태로 사용하지 않는다. 안전한 V2 ID/관찰이 없는 환경은 준비 안 됨으로 표시하며 기존 이름 기반 writer로 우회하지 않는다.
- 아래 ‘사용자 확정 UX’ 1~9는 유지한다. 회원별 앱 수명 1회, 비차단 첫 화면, 내 계정 탭 진행/화면 완료 수, 결과 요약·미완료만 재시도·대기시간, 시작 시 설정 고정, 회원 전환 중단/저장 차단을 다시 묻지 않는다. 앱 완전 종료 후 새 실행은 새 1회이며 foreground 복귀는 새 실행이 아니다.

### 초기 UI 검토 경과 — 상단 사용자 확정으로 대체

초기 결과 표시 위치 질문에는 사용자가 저장 개념부터 확인하도록 요청했다. 이후 저장 구조 설명과 세 선택지를 거쳐 **회원별 단일 주목록·기존 기기 자료 별도 접근**으로 확정했다. 초기 서버 영역 별도 표시안/미선택 상태는 현재 기준이 아니다. 기존 자료를 이름으로 자동 연결/덮어쓰지 않는 격리 원칙은 유지한다. 상단 정책 확정은 기능코드가 이미 구현됐다는 뜻이 아니다.

### 저장 개념 재확인 — 현재 구현과 제안의 구분

| 구분 | 현재 실제 저장 | 한계/아직 없는 것 |
|---|---|---|
| Backend 회원 자료 | 회원 UUID의 원정대 등록, canonical 원정대/캐릭터 UUID·소유/상태·활동/대표 설정과 서버 전투력 관찰 등 | Flutter가 분석한 역할별 전체 빌드를 서버에 저장/복원하는 경로는 이번 구현에 없음 |
| 기기 기존 AccountDatabase/schema13 | GameAccounts/AccountCharacters의 로컬 정수 PK, 캐릭터마다 dealer/support 빌드, 선호역할/표시/순서·주간 설정 | 캐릭터/원정대 행에 회원 UUID FK가 없어 로그인 회원별 완전 격리/소유 정답으로 볼 수 없음. nullable server ID만 있다고 회원 귀속이 입증되는 것도 아님 |
| 기기 새 ScopedAccountCacheDatabase/schema1 | 환경+회원별 scope 아래 서버 등록/원정대/캐릭터 ID와 조회 상태를 저장하는 4개 캐시 테이블 | 역할 빌드/선호역할/표시환경 테이블은 아직 없음. OFF에서는 새 DB도 열지 않음 |
| 다음 검토안 | 회원별 서버 캐릭터 UUID 아래 dealer/support 빌드를 분리 보관하는 기기 저장 공간 | 아직 설계안이며 새 schema/자동 실행/화면 전환은 미구현. 서버 전체 환경 복원과 별개 |

제품 소유 관계는 **앱 회원 → 여러 원정대 → 각 캐릭터 → 역할별 빌드**로 설명한다. 서버의 원정대/캐릭터 신원과 기기에 보관하는 분석 빌드는 같은 정보가 아니다. 기기 캐시는 서버 관찰을 보관하는 사본이며 소유권을 만드는 저장이 아니다. 개명은 새 ID/새 개인 공간, 다른 사람이 같은 이름을 쓰더라도 이전 빌드를 자동 승계하지 않는 기존 합의를 유지한다. 이 관계를 확인한 뒤 저장 위치/복원 범위와 화면을 결정한다.

### 데이터 흐름과 실행 준비

1. BackendApp 수명의 실행 controller가 같은 인증 세션·회원설정 VM·MemberLostArkKey·S3 runtime 및 공용 registration 조회를 구독한다. 화면이 실행기를 생성/소유하지 않는다. 기존 AppShell은 runner.dispose()를 호출하는 경로가 있으므로 app 소유 연결에서 중복 폐기를 제거할 경계를 명시한다.
2. 로그인/환경·회원 확정 → 회원설정 GET 성공(저장 미확정 요청 없음) → 등록 전체 목록과 대상 가능한 원정대의 V2 전체 roster 성공 → 직접 Armory 호출에 필요한 개인 키 복원/유효 version·카탈로그 준비 순이다. 병렬 준비는 가능하나 모두 같은 회원/세션이어야 한다. 캐시/부분 조회·설정 null/실패를 false 또는 준비 성공으로 사용하지 않는다. 서버 소유 미확인/미사용 상태는 제외 사유로 구분하고 권한을 승격하지 않는다. 하나의 대상 원정대 조회가 실패하면 전체 직업 중복 판정을 먼저 실행하지 않는다.
3. 최신 사용자 교정의 앱 활동 활성 집합을 기준으로 나이스단 허용 OFF 예외를 적용한다. 기존 NiceGroupPolicy의 직업 중복 분류·역할/무결성 정책은 재사용하지만 예전 startup의1700 필터를 근거 없이 활성 대상에서 재차 제외하는 조건으로 복사하지 않는다. UUID 기반 순수 입력 projection을 만들되 가짜 local int PK/과거 소유 ID를 만들지 않는다. 표시 개수/정렬은 대상 범위를 줄이지 않는다.
4. 실행 명세는 scope(환경+회원), session generation/run ID, 등록/소유/roster/lifecycle 관찰, 캐릭터 UUID, 설정 version/허용값, 키 version과 대상 집합을 캡처한다. 대상 확정 후의 설정 변경은 현재 실행에 적용하지 않는다. 등록 삭제/소유·캐릭터 이상/키 교체·로그아웃은 해당 작업의 저장 유효성을 무효화한다. 새 대상은 진행 중 집합에 끼워 넣지 않는다.
5. 개인 키로 기존 LostArkCharacterRemoteDataSource.fetchCharacterArmory를 대상 캐릭터 모두에 자동 호출한다. 상세 화면 진입까지 분석을 미루지 않는다. 서버 전투력 캐시 GET이나 기존 /combat-power/refresh를 전체 보석/패시브/그리드 분석의 대체로 쓰지 않는다. 응답 서버/이름/직업과 요청 관찰을 대조하고 이름 일치만으로 신규 canonical ID를 생성/연결하지 않는다.

### 안전한 역할 저장 — 다음 구현의 선행 A 구간

현재 CharacterBuildDraft/Coordinator/job cache는 local int ID이고 기존 commit은 기기 공용 AccountDatabase를 쓴다. 그대로 startup에 연결하지 않는다. 계약30의 ScopedBuildSnapshots를 **기존 별도 캐시 DB schema1의 증분 migration**으로 추가하고 `(scope,character UUID,role)`별로 저장한다. 같은 scope Character FK, 계정/캐릭터 수명·분석 dataVersion/rawJson·확인 시각·키 version·row version을 검증한다. 기존 lost_party/schema13·local 캐릭터/빌드/주간 자료 이관은 없다. 서버에만 있는 새 UUID는 이 회원의 새 역할 저장 공간을 사용하며 과거 이름/다른 회원 빌드를 승계하지 않는다. 로컬 목록 자동 가져오기 결정을 대신하지 않는다.

순수 CharacterBuildAnalysisMapper/역할·무결성 정책은 재사용하되, 새 draft/ref/fence와 scoped repository로 원자 저장한다. 고정 역할 직업은 기존 정책, 겸용 직업은 활성 깨달음 판정이 필요하다. 구 Coordinator의 expectedRole fallback·개별 수동 역할 선택으로 자동 판정 실패를 메우지 않는다. 역할 불명/파싱 실패는 양쪽 기존 빌드를 보존한다. 역할 확정+보석/아크그리드 오류는 해당 역할 빌드와 경고를 저장하며 반대 역할·선호 역할은 변경하지 않는다. 새 서버 빌드를 이름 기반 ServerCombatPowerViewModel.store나 local 카드에 합치지 않는다.

쓰기 직전 현재 scope/세션/run·키 version·등록 및 캐릭터의 현재 관찰/usable·row version을 검사하고, DB transaction/CAS 안에서 Character/head와 역할 row를 다시 검사한다. SQL 대기 중 취소된 경우 transaction 완료 전 guard로 rollback한다. 이미 원자 커밋 경계에 진입해 승인된 저장과 이후 취소된 미완료 작업을 구분하며, UI 결과 무시만으로 late 저장 차단을 주장하지 않는다. 같은 UUID/역할의 수동 저장과 경합하면 row version 충돌로 자동 저장을 거절한다. 기기 공용 local 저장은 별도 행이므로 간섭하지 않는다. 테스트에서 취소·삭제/수명 변경·동시 저장을 실제 transaction 경계로 검증한다.

### 실행 상태·진행·다시 시도

| 상태 | 내 계정 표시·동작 |
|---|---|
| 준비 중/준비 실패 | 설정/원정대/개인 키 확인 상태와 해당 해결 버튼. 준비 실패는 자동 실행 1회 미소진. 키 해결/명시 조회 성공 시 조건을 다시 평가 |
| 실행 중 | 탭 진행 표시·`처리 X/Y`와 저장/미완료 수. 첫 화면과 다른 탭은 사용 가능. 시작 시 설정 유지 안내 |
| 종료 | `저장 N명(경고 W명 포함) · 미완료 F명 · 정책 제외 E명`. 경고 저장은 저장 완료이며 실패/재시도 대상과 중복 집계하지 않음 |
| 호출 제한/중단 | 미완료 대상·남은 대기시간·재시도 버튼 비활성. 시간 만료만으로 자동 재호출하지 않음 |
| 로그아웃/회원 변경 | 이전 회원 화면·대기 요청 폐기. 완료 저장은 해당 scope에 보존. 돌아온 회원은 재검증 후 미완료만 명시 재시도 |

준비 조건을 모두 만족한 뒤 최초 실제 작업을 시작할 때 회원별 1회 상태를 원자 전이한다. 동일 회원 재로그인/탭/foreground는 재실행하지 않는다. 대상0명은 정상 판정 완료로 표시하고 반복 시작하지 않는다. 실행 기록은 앱 메모리에서 환경+회원별 유지하고 private 표시 상태는 세션별로 분리한다. 전체 앱 재시작 뒤에는 저장된 회원설정을 다시 GET하고 새 실행을 준비한다. 성공 캐시를 세션/회원/키/수명이 다른 job에 재사용하지 않는다.

미완료 재시도는 최초 미완료 UUID 집합만 대상으로 최신 설정/키/현재 자격·roster를 다시 검증한 별도 실행이다. 이미 저장된 대상은 재호출하지 않는다. 최신 설정이나 자격 변경으로 제외된 대상은 이유를 알리고 재시도 집합에서 제외한다. 새 캐릭터 자동 편입·전체 재갱신으로 확대하지 않는다. 대기 deadline은 기존 공용 cooldown을 사용하고 표시 timer는 HTTP를 실행하지 않는다. 이름/파싱 실패는 기존 빌드 보존·오류 요약이며 무한 재시도가 아니다.

### 구현 순서·완료 조건

- **A 저장/판정 기반:** scoped 역할 schema migration·draft/ref/write plan/transaction guard·정책 재사용. 저장/권한 경계 중심 테스트를 작성한다. 실행 DI/자동 호출을 먼저 켜지 않는다.
- **B 실행 연결:** 준비 barrier·회원별 run registry·전체 대상 판정·Armory/역할별 저장·미완료 재시도·취소/버전 경계와 app 수명을 연결한다.
- **C 화면/최종 검증:** 선택된 목록에 진행/결과/경고 빌드·해결/재시도 버튼을 연결하고 설정 안내의 ‘준비 중’ 문구를 실제 동작 기준으로 변경한다. UI/Router/DI 최종 전체 flutter test/analyze·format/diffcheck 후 한 번의 사용자 인수 체크리스트를 전달한다.

A/B 중간 결과를 ‘자동 갱신 완료’ 또는 ‘디바이스 테스트 단계’로 보고하지 않는다. C까지 실행 연결과 자동 검증이 끝난 뒤 ON 저장→앱 완전 종료/재시작→설정 복원→1회 갱신/해당 역할 저장, OFF의 나이스단 제외·탭/복귀 중복 방지·실패/재시도·회원 전환을 사용자가 확인한다. 실제 대상 V2 API가 준비돼 있지 않으면 그 연동 인수만 별도 미확인으로 남기며 Flutter 코드/모의검증을 Backend 개발 대기로 바꾸지 않는다. 서버에 새 전체 빌드 저장 API·공용 키·Firebase 재연결을 요구하지 않는다. 왕관/활동 변경·파티·legacy 삭제/복원·live proof/퇴역 보류 해제·배포/Issue 종료는 제외한다.

근거: BackendApp의 memberSettings/MemberLostArkKey/read runtime·remote scopeIdentity, CharacterBuildDraft의 int ID, Coordinator._run/expectedRole fallback, LocalAccountDataSource.commitCharacterBuildDraft, StartupCharacterRefreshEligibilityPolicy/NiceGroupPolicy, AppShell runner 소유, 계약30 §3/§5. S3b 최종 회신6190026125 이후 Backend 새 댓글은 없으며 HEAD/origin-dev cc6a0b0와 이전 미커밋을 보존했다. 이번은 소스·문서 검토이며 기능 테스트를 반복 실행하지 않는다.

## 현재 기준 — 자동 갱신 UX 확정 (2026-10-15)

이 절은 아래 과거 조사·협의 이력보다 우선하는 최신 사용자 합의다. 회원설정 #6과 회원키 #7은 완료·종료됐고, Flutter dev cc6a0b0/Backend dev 72f6301에 통합됐다. 전체 빌드 자동 실행은 아직 미연결이다.

### 사용자 확정 UX

1. 앱 실행 중 회원별 자동 실행은 1회다. 같은 회원 재로그인·탭 이동·앱 foreground 복귀로 반복하지 않는다. 다른 회원은 자신의 준비 조건과 실행 상태를 사용한다.
2. 회원/세션 확정, 회원설정 GET 성공, 전체 등록 원정대/대상 roster 준비, 해당 경로의 개인 키 준비가 모두 끝난 뒤 시작한다. 준비 실패/미완료는 설정 OFF가 아니며 실행 1회를 소진하지 않는다.
3. 준비 실패·키 미등록은 내 계정에서 상태와 해결 버튼을 제공한다. 명시적인 조회 재시도 또는 키 등록/복원으로 준비가 완료되면 자동 시작한다. 자동 polling/무한 재시도 요구가 아니다.
4. 첫 화면 사용을 막지 않는다. 실행 중 내 계정 탭에 진행 표시, 내 계정 화면에 완료 수/전체 수를 표시한다.
5. 종료 후 결과 요약과 미완료 대상 다시 시도 버튼을 제공한다. 호출 제한 중에는 남은 대기시간을 표시한다. 정상 저장 완료 대상은 미완료 재시도에 다시 포함하지 않는다.
6. 바드·홀리나이트·도화가·발키리는 현재 활성 깨달음 근거로 dealer/support를 확정해 해당 역할 Snapshot만 갱신한다. 반대 역할 Snapshot과 선호 역할은 보존한다. 역할 판정 불가 또는 응답 파싱 실패는 기존 빌드를 보존하고 미완료로 처리한다. 선택/선호 역할을 판정 실패의 대체 근거로 쓰지 않는다.
7. 역할을 확정했지만 보석 부족·타 직업/스킬 불일치 보석·아크그리드 오류가 있으면 해당 계열에 저장하고 오류 요약을 표시한다. 이런 저장을 역할 판정 실패와 섞지 않는다. 기존 공통 분석/통합 무결성 요약을 재사용하며 최적 세팅을 보증하지 않는다.
8. 갱신 중 나이스단 허용 설정 변경은 현재 작업에 소급 적용하지 않는다. 시작 시 확정한 값으로 마치고 변경값은 다음 갱신부터 적용한다고 안내한다. 기본 OFF·캐릭터관리 즉시 서버 저장 UX는 유지한다.
9. 로그아웃/회원 전환 시 이전 작업을 중단하고 늦은 결과 저장을 차단한다. 이미 완료한 저장은 유지한다. 돌아온 회원은 자동 반복/자동 재개 없이 미완료 대상 명시 재시도를 제공한다. 실제 저장 직전 회원·세션/실행 유효성을 확인해야 하며 UI 응답 무시만으로 충족하지 않는다.

### 선행 설계 — 원정대 이름 변경·누락·삭제 (2026-10-15)

최신 사용자 정책과 미완료 파티/이름 재사용 설계는 [계약26](26-roster-character-lifecycle-design.md)에서 관리한다. 정상 전체 조회의 확정 소멸은 간략 이력 후 개인자료 정리, 새 이름은 신규로 처리한다. 미완료 파티는 기존 회원 자리/당시 Snapshot을 유지하고 확인 필요 경고 후 본인의 명시 변경/탈퇴로 처리한다.

사용자는 서버 등록 캐릭터가 로컬에 없을 때 저장 공간을 자동 생성할지 선택하기 전에, 캐릭터명 변경·삭제 등 원정대 변경 처리를 먼저 해결하도록 지시했다. 따라서 이 선행 설계를 현재 작업으로 두고 자동 생성 선택/자동 갱신 구현은 보류한다. 위 자동 갱신 UX 합의는 유지한다.

확인된 현재 동작:

- Flutter AccountDatabase.applyRosterSummarySync는 원정대 안의 서버명+캐릭터명으로 대조한다. 새 이름은 새 로컬 PK로 추가하고 응답에서 빠진 기존 이름은 isRosterMissing=true로 남긴다. 같은 키가 다시 나타나면 같은 로컬 행의 누락을 해제한다. 이 처리는 실제 개명·삭제·동명이름 재사용의 증명이 아니다.
- CharacterSummarySyncService는 실패/빈 응답을 적용하지 않지만, 비어 있지 않은 불완전 목록의 전체성을 입증하는 계약은 없다. 요약 적용은 기존 행별 시각을 일부 검사하지만 누락 처리 전체에 같은 최신성 검사가 없다. 겹친 재조회/늦은 응답이 새 상태를 되돌리지 않도록 원정대 단위 세대/직렬화가 필요하다.
- 기존 조회 기준 lookupCharacterName이 개명/삭제되면 그 이름의 siblings 조회가 실패하고 자동 대체 조회 경로가 없다. 새 이름/같은 원정대의 다른 캐릭터로 재조회하는 UX와 동일 원정대 확인이 필요하다. 조회 실패를 원정대 전체 삭제로 바꾸지 않는다.
- Backend 72f6301의 observations.roster가 소비하는 외부 관찰키도 서버명+이름이다. service.reconcile는 일치 행은 기존 canonical ID로 유지하고 신규 이름은 새 canonical ID를 만든다. 누락은 disappearance_validated가 있어야 missing, 아니면 suspect다. 현재 live adapter는 이 증거를 제공하지 않고, 감소 roster 기반 소유권 이전의 ROSTER_EVIDENCE_PENDING도 유지된다. canonical UUID는 서버가 부여한 ID이며 외부 개명 추적 근거가 아니다.
- Flutter 로컬 직접 summary 경로는 Backend의 suspect/증거 보류를 소비하지 않는다. 로컬 missing을 실제 캐릭터 삭제나 서버 소유/활동 자격 확정으로 해석하지 않도록 두 상태의 의미와 화면을 정리해야 한다.
- DB.deleteMissingCharacter는 missing 행을 명시 삭제하지만 종속 빌드/주간 표시를 직접 지우지 않는다. DB24 DB-03의 FK 비활성/고아행 재현과 연결된다. 삭제 UX를 이번 범위로 확정하면 이 직접 종속 정합성은 같은 구현 단위에서 해결하며 광범위 FK/DB 정리는 포함하지 않는다.

사용자 확정: 이름 변경 연결/빌드 승계는 하지 않는다. 새 이름은 신규 등록하며 사라진 이름은 간략 이력 후 기존 개인자료 정리다. 실패·불완전 응답은 소멸 확정이 아니므로 보존한다. 파티·완료 당시 Snapshot과 미완료 참가 회원의 자리는 별도 보존한다. 이름만으로 소유/활동 자격을 생성·이전하지 않는다. 전체성 증거와 ID 생명주기/FK/이름 재사용의 Backend 계약은 구현 전 검토가 필요하다.

이후 기술 설계는 대표/조회 기준 이름 복구, 이름 재사용·재등장, 파티 참조 보존, 부분/역순 응답·회원전환 중 저장, 삭제 직후 늦은 Armory/summary 재삽입 방지의 경계를 다룬다. 기존 계약13의 누락 보존과 이름 고유키는 이번 새 정책에 맞춰 검토해야 하며 구현 완료로 표시하지 않는다. 필요한 Backend 협업은 계약26에서 분리하고 #3을 다시 열거나 증거 보류를 우회하지 않는다.

근거: Flutter account_database.dart:1085/1291, CharacterSummarySyncService._syncAccount, 서버 계약13/조회16 및 DB24. Backend immutable 72f6301의 app/game_accounts/service.py:301/395/479, observations.py:9/33/55를 직접 조회했다. 실provider/키/운영DB는 조회하지 않았다.

### 구현 전 남은 기술 설계

- 현재 BackendApp의 준비 소스·전체 roster와 로컬 캐릭터 ID 연결, 회원별 실행 상태 수명/중복 방지, 키 교체·등록 삭제 중 실행 무효화와 저장 직전 검증을 조사한다. 기존 로컬 DB가 기기 공용이라는 점을 회원격리 완료로 오인하지 않는다.
- 대상 제외/경고 저장/미완료를 구분한 진행 수·결과 모델, 재시도 시 현재 roster/설정/키 재검증과 중복 저장 방지를 정의한다. 설정 변경 시 현재 작업에 대한 확정 값과 다음 명시 재시도에서 쓸 최신 값의 경계를 명시한다.
- 수동 상세 저장은 현재 사용자가 고른 역할을 받는 별도 흐름이다. 이번 자동 저장 합의를 수동 선택 UI 변경 승인으로 확대하지 않는다. 기존 Coordinator의 판정 근거 부재 시 expectedRole fallback은 새 자동 경로에서 허용하지 않는다.
- 전체 수동 갱신/진행 중 개별 저장과의 충돌, 현재 수동 profile 전투력 표시와 역할 Snapshot 우선순위를 정리한다. 전체 환경 서버 복원·새 전체 빌드 저장 API는 별도 설계이며 필요성이 확인된 Backend 변경만 요청한다.
- 회귀 보호와 최소 경계 검증, 단계별 구현 범위/완료 조건을 NEXT_WORK에 확정한 뒤 구현한다. 이번 UX 확정은 자동 실행 기능 구현 완료 또는 과거 Firebase 경로 재연결 승인이 아니다.

코드 근거: CharacterBuildAnalysisMapper(보석/깨달음/아크그리드), CharacterAutoRefreshCoordinator._validateDraft/_run(역할/저장), LocalAccountDataSource 및 AccountDatabase(역할별 저장), MyAccountViewModel/ServerCombatPowerViewModel(선호 역할 표시). 기존 테스트는 역할별 저장·반대 역할 보존·오류 분석과 경고 저장을 구분한다. 이번에는 코드/기기/실provider 호출과 테스트 재실행 없이 조사·합의만 수행했다.

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

## 2026-10-15 — 시작 등록 목록 중복 조회 통합

사용자 순차 진행 지시의 첫 그룹으로 등록 목록 조회를 개선했다. ServerAccountReadRepository는 인증 복원으로 시작하는 등록 패널과 전투력 표시 VM의 목록 요청만 같은회원+세션세대의 진행 Future로 공유한다. 전체 페이지 수집/검증이 끝난 결과를 함께받으며 완료/실패뒤진행항목을제거한다. 완료결과캐시/TTL이나백그라운드재시도는추가하지않았다.

기본 loadRegistrations/load/reload는공유하지않는다. 등록/삭제/수정/멱등현재상태확인후GET은진행중초기조회와별도로새HTTP요청을시작해이전응답을재사용하지않는다. 새회원/동일회원새세션은분리하고기존requireAccountReadScope/VM늦은응답격리를유지한다.

정상로그인유지·토큰유효·각목록1페이지·등록원정대N개·오류없음인시작흐름은Backend요청4+N에서3+N으로1건감소한다(GETme1+회원설정1+등록목록1+원정대별캐릭터N). 페이지분할/토큰갱신/실패재시도는별도다. 원정대요약LostArk직접조회와전체빌드미연결상태는바뀌지않는다.

자동검증은공유VM실제초기화·전체페이지공유·성공후재조회/실패복구·다른회원/새세션격리·과거정리로새진행조회삭제금지·쓰기뒤신규GET 등7개추가를포함해전체1227개통과,lib/test분석0. 화면/DB/API계약변경이없어이미성공한기기시험을다시요청하지않는다. Backend수정/새Issue불필요. 현재feature/account-backend-read미커밋·dev미반영/미push상태다.


2026-10-15 Git마무리: 사용자dev머지/push지시에따라검증이끝난중복조회구간을반영한다. feature/account-backend-read의잔여구현/필수검증은없다. 전체1227/분석0을재사용하고실험자료/기존브랜치는보존한다. 다음자동빌드실행순서는별도설계그룹이며기능코드에함께연결하지않았다.
