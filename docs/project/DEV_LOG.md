# 개발 이력

## 2026-10-17 — 사용자 실기기 결과·dev 통합 지시

사용자가 상태 문구/정수 표시/시간 초 단위 정상과 새 기기 로그인에서 같은 회원의 서버 원정대 목록·인증 상태 표시를 확인했다. [108번째 Flutter 결과](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6228832537)로 회신했다. 전체 캐릭터/활동 설정·역할 요약의 로컬 복원과 자동 상세 갱신 통과로 확대하지 않았다.

이름 변경·활동 캐릭터 선택 진입 누락, 인증 버튼의 이름 바로 오른쪽 절반 크기/긴 이름 두 줄, 구 기기 공용 자료가 있는 새 기기의 서버→로컬 회원 데이터 연결은 사용자 지시 순서대로 **현재 완료 구간 커밋·dev merge·push 이후 분석**한다. NEXT_WORK에 빠뜨리지 않고 기록했다. 기존 기능이 있다는 문서와 실제 진입 가능은 별개로 판별한다. 후속 코드는 이번 통합에 추가하지 않는다.

최종 전체1,591PASS·lib/test 분석0 이후 코드 변경 없음으로 검증 재사용·diffcheck. 기존 Rules 백업/tools는 해시 대장으로 보존하고 현재 기능 관련 docs/lib/test만 커밋한다. 실제 통합/원격 확인 결과는 후속 Git 보고를 기준으로 한다. main/서버/DB/키/자료/flag·기기조작·Issue종료는 변경하지 않는다.

## 2026-10-17 — 원정대 상태·숫자 표시 간결화

사용자 화면 지시와 등록19/실제 회원 GET·POST/표시 경로를 대조했다. 미인증 로그인 회원의 등록도 서버에 남고 같은 회원 조회로 복원하는 구조다. 재설치/다른 기기 실험을 새로 수행한 것은 아니다. NEXT_WORK에 표시 계층/원본 보존·경계/순서를 기록한 후 구현했다.

- 새로 가능: 조회용 저장→원정대 인증 필요, owned/활동 configured의 완료 안내 숨김, 활동 캐릭터 미선택·재인증/재선택 필요 표시. 기존/회원 원정대 목록·상세/등록에서 동일 적용했다. 기기/회원 카드·관리·상세·인증 후보·등록 미리보기·현재/퇴역·그룹 레벨/전투력에 공통 정수 표시를 적용했다.
- 보존 확인: formatter만 정수부를 표시하며 API 문자열/수치·DB/schema·서버/로컬 원본과 정렬/판정·활동/대표/인증 정책은 그대로다. null/잘못된 값은 기존 미확인 문구를 사용한다. 시간 초 단위 정책 유지.
- 검증: wire 문자열/콤마·소수점 버림·미확인/비유한값 경계 추가, 기존 UI 기대값만 정수로 갱신했다. 최종 전체 **1,591PASS**, lib/test 분석0·format/diffcheck. 여러 feature의 공통 표시 영향으로 전체 검증을 1회 실행했다. 로그 `.dart_tool/number-ui-full-final.log`, `number-ui-analysis-final.log`. 초기 편집의 formatter 파일 인코딩 오류를 UTF-8로 수정한 후 최종 검증했다. 폴더 format이 만든 무관한 3개 파일의 변경은 정확한 해당 텍스트만 되돌렸다(HEAD 덮어쓰기는 자동 승인 검토가 거절해 수행하지 않음).
- 미확인 실기기: 새 화면 안내/정수 표시·다른 기기/재설치. 사용자 기기 설치·조작/서버·DB/자료/flag 변경은 수행하지 않았다.
- 협업: [107번째 Flutter 표시 결과](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6228564592) 본문/순번 확인. Backend 응답의 정수화 불필요·추가 작업/회신 요청 없음. feature/scoped-account-cache 유지, 미커밋·미push·dev 미반영·기존 변경 보존.

## 2026-10-17 — 서버 재인증 차단·동일회원 재등록 복구 연결

Backend105번째19c2dcc 고정 계약/OpenAPI와 기존 인증·등록·Router를 대조하고 NEXT_WORK에 범위/회귀 보호를 먼저 기록했다. 성공 DTO는 기존 fixture와 동일했다.

- 새로 가능: 409 ALREADY_VERIFIED 확정 거절은 원명령 대기/재전송을 종료하고 이미 인증 안내·현재 목록을 갱신한다. 필요하면 기존 원정대 등록 관리로 진입한다. 재등록201 owned/verified는 인증 복원 안내·새 등록ID/현재GET으로 표시하고 인증 버튼을 제공하지 않는다. unconfigured·활동0·대표null을 정상 상태로 둔다.
- 보존 확인: 기발급 challenge의 실제 pending(현재GET 실패 포함), 임의 성공/취소·성공 이동 방지, 완료된 원명령 동일key/body ACK 복구→현재GET, 회원 전환/late 차단 및 기존 소유상실/타소유 도전. 기존 성공 후 이전페이지 복귀도 유지한다.
- 검증: 신규 경계 검증을 포함한 최종 전체 **1,590PASS**, lib/test 분석0·format/diffcheck. 첫 결합 실행의 등록 테스트 import 이름 충돌은 UI alias로 수정하고 해당37PASS 후 전체를 검증했다. 최종 분석의 테스트 중괄호 info1건을 정리해 분석0을 재확인했다. 로그 `.dart_tool/auth-owner-full-final.log`, `auth-owner-analyze-final.log`. 이전 결과와 합산하지 않는다.
- 미확인 실기기: 새 안내/목록 갱신과 두 서버 응답의 실제 기기 조합. 기존 실제 인증 성공을 초기 인수로 되돌리지 않으며 반복 실인증/자료 삭제·재등록을 요구하지 않았다. 소유 이전/24시간 분쟁·앱종료후 명령 복구는 별도다.
- 협업: [106번째 Flutter 결과](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6228427796) 게시·본문/실제 순번 확인. 추가 Backend 선행 작업/제품 결정 요청 없음. feature/scoped-account-cache HEADcc6a0b0·기존 변경 보존·미커밋/미push/dev미반영·브랜치 유지. 서버/DB/키/flag·개발자료·기기 설치/조작·배포·Issue종료/Git통합 없음.

## 2026-10-16 — 앱 실행1회 provider 목록 갱신 선행 연결

사용자 연결 지시/82번째Backend3c8e799에 따라고정안내/OpenAPI·기존source/runtime/controller/회원UI를대조하고NEXT_WORK설계후구현했다. StartupRosterRefresh가현재owned등록별기존POSTrefresh({},UUIDv4key)를실행하고source.prepare는ACK후read generation무효화/전체canonical재조회뒤batch를생성한다. 데이터계층의원정대진행을선택적Domain인터페이스로controller/UI에전달해기존fake/실행정책을보존했다.

- 새로가능: 실제API목록갱신→서버반영/재조회→현재활동대상→상세검사. 부분실패/ACK후GET실패는준비1회미소진·전체상세보류, 앱수명고정명령/ACK로동일요청/미완료만재시도하고성공원정대provider재호출0. 원정대목록진행·신규/확인필요수·실패와상세/서버저장대기를구분한다. requires_refresh는suspect표시다.
- 보존확인: 일반GET의DB조회, 사용자/복수원정대/소속·활동·표시분리, OFF상세제외/목록갱신·빌드보존, 기존1회/준비실패미소진·역할/개인outbox/회원전환fence·관리/왕관/인증. DB/키/자료/flag/환경불변.
- 검증: 신규7경계로순서/상세재시도POST0·유실동일명령/재로그인·ACK후GET실패·429고정기한/자동재시도0·로그아웃late·복수원정대실패성공분보존·suspect제외/신규UUID자동선택0. 초기직접45PASS/8실패(공유GET횟수+미해제fixture·새revision/presentation·옛조회fencing기대)를원인대조후fixture/기대보완, 회원직접18PASS. 최종전체 **1567PASS**, lib/test분석0·format/diffcheck. 중간분석중괄호info2건수정. logs .dart_tool/startup-roster-full-final.log / startup-roster-analysis-final.log. 고정3c8e799와7027f0b원본paths/schemas동일직접확인.
- 미확인: 실provider/게임/기기·ON전체사용자인수/새기기. 명령보존은앱수명, 새영속journal아님. Backend장비재인증/타소유pending·퇴역/claim해제/물리정리·24시간분쟁은별도이며이번완료로표시하지않음.
- 협업: [82번째요청소비결과](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6214686634)게시·본문/순번확인. 추가API/제품결정요청없고Backend독립후속을계속할수있음. feature/scoped-account-cache HEADcc6a0b0·기존변경/사용자Rules/tools보존·미커밋/미push/dev미반영·브랜치유지. 새원격FlutterSHA·기기조작/서버재시작/배포·자료초기화/이관/환경전환·Issue종료·Git통합없음.

## 2026-10-16 — 핵심 데이터 정의 Backend 보충 인계

78번째 Backend의76·77번째 수용을 확인하고 사용자1명/복수 실제 원정대·서버 저장의 반복호출 절감/파티·그룹 기반·활동/표시 분리를 [79번째](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6213474915)로 보충했다. 게시본문 일치/순번 확인·문서diffcheck. 다음 Backend 목록갱신 구현→Flutter 실행연결 유지, 코드/시험/환경/flag·Git통합 변경 없음.

## 2026-10-16 — 핵심 사용자/원정대/API/서버 저장 개념 영구 기록

사용자가 반드시 기억할 핵심으로 확정한 사용자1명→복수 실제 게임 원정대→API 소속 전체 목록, 서버의 반복 API 호출 절감/저장·향후 파티/그룹/활동 데이터 제공 책임을 정책09 D11에 기록했다. 사용자 귀속/인증·원정대 구성·활동 선택·표시 설정을 분리하고 원정대 인증의 특정 캐릭터 의존 금지·실행1회 실제 목록 갱신을 명시했다. AI_CONTEXT/NEXT_WORK에 원본 확인 지점을 추가했다. 기능 코드·API·DB/자료·flag·시험 결과 변경 없음, 문서diffcheck/내용 검토. 기존 미커밋/미push·dev미반영·feature/scoped-account-cache 유지.

## 2026-10-16 — 원정대 인증 유지/API 목록 기준 확정·자동 목록 갱신 누락 인계

사용자는 인증대상C의 소멸과 B원정대 인증을 분리하고 ‘원정대 구성은 로스트아크 API 목록, 그외 확인 없음’으로 답변했다. [75번째 정정](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6212808011)에 이어 [76번째](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6212824900)로 본인 갱신 정책 질문 대기를 해소했다. 관찰되지 않은 동명 재생성의 API 한계를 설명하되 외부 영구세대 근거를 일상 갱신의 필수 조건으로 추가하지 않는다. 내부 소유/충돌 검사·새이름 신규ID/이상 즉시차단·타회원/종료ID 권한 승계 금지는 유지한다.

추가 사용자 지시로 앱 실행1회 실제 source/runtime 경로를 확인했다. 자동 prepare의loadMemberRoster는 서버 저장 metadata/V2 GET이며 이후Armory상세만 조회하고 provider siblings 갱신 명령이 없음을 확인했다. [77번째](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6212848615)로 Backend 본인refresh→Flutter 목록갱신 선행/재조회/활성대상확정/상세검사 순서를 인계했다. 나이스단OFF는 상세 제외/목록은갱신, 실패부분응답 자료보존·인증유지/미완료를 명시했다. 아직 선행 연결 구현 완료 아님.

새 앱 흐름 없음(정책/조사/문서/회신), 기존 코드/DB/자료/키·환경/flag 보존. 이전1560PASS/분석0은 기존결과로 유지하고 새 목록선행 검증으로 확대하지 않음·시험 반복 없음. 문서diffcheck·댓글본문/순번 확인, 실기기/게임·서버적용/배포·Issue종료/Git통합 없음. feature/scoped-account-cache·기존 미커밋/미push/dev미반영 유지.

## 2026-10-16 — 73번째 본인 갱신/타소유 pending 계약 대조

사용자 진행 지시로 정책26/연결29와 실제 인증 client·VM·화면을 대조했다. 새이름 신규UUID·누락 suspect·기존대표/활동 자동쓰기 없음은 기존 방향과 일치하나 같은 서버/이름의 관찰 사이 삭제/재생성 미식별 수용은 명시 근거를 찾지 못해 사용자에게 범위 한정 허용(추천)/근거 확보 전 보류를 질문했다. 답변 전 승인으로 회신하지 않았다. 타소유 도전 발급/장비 확인 후 pending·ACCOUNT_BINDING_EVIDENCE_PENDING은 현재 parser/상태·취소·만료·verified만 이동과 호환돼 독립 Backend 진행 가능으로 [74번째](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6212641213)에 회신했다. 현재 전용 문구 부재는 일반 보류 처리와 구분했다.

13d9f68 게시 OpenAPI를7027f0b와 직접 비교해 paths/schemas 동일. 새 앱 흐름 없음/기존 코드·DB·자료/flag/환경 보존,1560PASS/분석0은 기존 결과로 재사용·시험 반복 없음. 문서diffcheck·게시본문/순번 확인. 미확인: 사용자 선택/본인 연결 허용·실게임/기기·타소유 서버 구현. feature/scoped-account-cache·기존 미커밋/미push/dev 미반영 유지, 배포/Issue종료/Git통합 없음.

## 2026-10-16 — Issue8 기존 장비 인증 구현 자료 회신

66번째 Backend6210508071 요청/사용자 지시로 실제 과거8f4209d Gateway와 현재 preview/UI/제품 장비 계약, Task-044/086·2026-09-13의 필요한 이력만 대조했다. 최신 siblings/전체Armory·6부위/랜덤1~3해제·Type/Name/Grade·10분·재확인·프로세스 수명, 과거 클라이언트 판정/소유 반영과 현재 서버 최종 판정의 차이를 근거 링크와 함께 회신했다. 조회 실패·parser 느슨함/confirm 이후 기한 미검사·당시 서버 감사 challenge 미구현을 새 서버에서 그대로 복제할 기준과 구분했다. 과거 Android 인증 성공/안내 경험은 확인했지만 raw 응답/반영 지연과 현재 live 통과는 미확인이다.

다른 회원 인증 원정대의 도전 이력을 누락하지 않는 사용자 기준을 인계했다. 과거 자동 장비 인증의 소유 이전과 운영자 수동 인증의24시간 방어/분쟁이 별개임을 설명했다. Firebase 전용 writer·자료 승계/이름 기반 ID 재사용은 재도입하지 않고 현재 서버 challenge에 요청 회원·대상서버/이름·원정대·시도/만료/결과를 기록하고 confirm 재조회/최종 검증하는 책임을 전달했다. 인계 https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6210605354 , 다음 Backend 재사용/보완 설계·구현. 댓글 순번/작성 측/단계/다음 담당을 구분한다.

새 앱 흐름 없음(조사/문서/회신), 기존 코드/DB·자료/키/flag/환경·Router 보존. 기존1560PASS/분석0 재사용·Flutter 시험 반복 없음, 문서diffcheck/소스·Git/댓글 본문 대조. 실제 게임/기기 관찰·서버 적용/배포·Issue 종료·Git통합 없음. feature/scoped-account-cache HEAD/origin-dev cc6a0b0·기존 미커밋/미push·dev 미반영·브랜치 유지.

## 2026-10-16 — 기존 캐릭터 관리/초기 대표·1700·인증 후 전환 연결

Backend6209623492/47a2ce4 인계와 사용자 진행 지시로 기존 CharacterManagementPage/ViewModel에 scoped gateway를 연결했다. 화면 안 정수 ID는 UUID의 임시 투영이고 로컬 계정 DB/소유 매핑에는 쓰지 않는다. 현재 소유·전체 canonical·revision 재조회와 기존 활동 전체집합+대표 원자 PUT, shared runtime 잠금/CAS를 사용한다. 대표 없을 때만 현재 선택집합 안 최고 유효 후보, 빈 선택이면 전체 최고 유효1명만 draft에 제시하고 명시 저장한다. 기존 대표/부적격 선택은 자동 교체·삭제하지 않는다. 공통1700 정책에 finite 검사를 추가하고 lifecycle/claim 검사와 함께 적용했다.

새로 가능: 회원 목록/상태→기존 관리 UI→현재 서버의 활동/대표 저장, P2 기존 영속 outbox로 순서/count 저장(선호역할/visible 보존), 인증 대상 ID 전달→성공 결과 ID의 현재 소유/전체 목록 확인→해당 본·부원정대 관리 화면 전환. 왕관/취소좌·변경우 재사용. 응답 유실/ACK 후 GET·개인설정·최종 재조회 실패는 같은 앱 수명 key/body/저장 흐름으로 확인하며 늦은 회원 결과와 과거 ACK 후 개인설정 덮어쓰기를 막는다. 예전 인증 성공으로 새 페이지를 이동시키지 않고 전환 실패 재확인을 제공한다.

보존 확인: R1 기본 조회/상세 비노출, 현재 owned 수동 상세/전투력·역할, 자동 회원별1회/OFF 제외·기존 빌드/표시·키·대표 왕관·기존 관리 로컬 흐름. DB/schema/키/자료/주소/기본flag는 유지했다. 불확실 전체설정은 앱 수명 메모리이며 새 journal/복구 UI·E1 원 PUT 종결 보장 신설은 아님. 기존 선택 UUID가 현재 목록에 없으면 임의 삭제하지 않고 오류로 차단한다.

검증: 신규18개 경계. 직접 영향66PASS→최초 전체1558PASS, 이후 최종 재조회 실패·과거 ACK 경계2개와 보존 보완 후 직접14PASS→최종 전체1560PASS, lib/test 분석0·format/diffcheck. 중간 분석의pushReplacement void await1오류/중괄호info·미사용import를 수정했다. 로그 .dart_tool/character-management-full-tests-final.log / character-management-analysis-final.log.47a2ce4 게시 원본과7027f0b fixture paths/schemas 동일 직접 확인.

미확인 실기기: 실제 소유/provider·새 기기/재설치/ON 빌드 전체 UX. 기능은 회원/canonical ON 경로이며 기본flag OFF 실행에 노출된 것으로 보고하지 않는다. 실제 소유/연속성·퇴역 보류 유지, 초기 환경/로그인 재인수 요청 없음. 인계 https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6209931176 . 추가 Backend API/사용자 결정 요청 없음.

feature/scoped-account-cache HEADcc6a0b0/미커밋·미push·dev 미반영·브랜치 유지. 기존 변경/사용자 Rules/tools 보존, 새 원격 Flutter SHA 없음. DB/자료 초기화·환경 재구축·배포/서버 조작·flag ON·기기 설치·Issue 종료·Git 통합 없음.

## 2026-10-16 — Issue8 병렬 회신 최종 대조·순서 통합

최신 사용자 UX6209360031와 Backend6209379848까지 대조했다. 서버59b8c23의 미인증/소유상실 power·replay 차단/기본 응답 비노출256PASS·push·기존8000/DB0009·자료 유지 반영 보고를 확인했다. 고정 OpenAPI와7027f0b fixture를 직접 구조 비교해 paths/schemas 동일·combat_power 정책 주석3개 추가만 확인했다. 과거 서버 power/cache 수정 대기는 해소됐지만 live 소유 증거/원정대 연속성·퇴역 확정 미완료는 별도로 유지한다.

NEXT_WORK의 과거 복구 시스템 우선/별도E2 화면 계획을 제거하고 기존 관리 UI→현재 회원/canonical 원자 설정 저장→초기 최고레벨1회/공통1700 양측 경계→인증 후 해당 화면 전환으로 순서를 통합했다. 대표 존재 시 유지·확정 실패 기존값, 응답 유실 내부 일관성만 최소 보완. 서버 초기 선정/활동 저장1700 직접 강제 미구현을 전투력 수집 필터와 분리했다. 새8001/빈 환경/기초 재인수는 철회 상태로 유지한다. 공식 회신: https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6209491349 .

새 앱 흐름 없음(문서/회신만), 기존 코드/DB/키·기본flag/환경 보존. R1 전체1542PASS/분석0과 Backend256PASS는 기존 결과로 구분해 인용, Flutter 시험 반복 없음. 이번 서버 실호출/실provider·실기기 미확인. 검증은 게시 원본/댓글 대조·문서 내용 검토·git diff --check. feature/scoped-account-cache/기존 변경 보존·미커밋·미push·dev 미반영·브랜치 유지. 자료 초기화/배포/Issue 종료/Git 통합 없음.

## 2026-10-16 — 기존 캐릭터 관리 UI 재사용·대표 초기1회 UX 정정

사용자가 별도 대표 복구 UX/평행 캐릭터 선택 화면 제안을 정정했다. 실제 CharacterManagementPage/ViewModel의 ‘앱에서 사용할 캐릭터’·대표·표시순서/개수 및 기존 활동 Repository 연결점을 확인했다. 공통 CharacterUsageLevelPolicy.minimumItemLevel=1700도 확인했다. 기존 대표 유지, 대표가 없을 때만 유효 사용 대상 중 최고 아이템레벨 초기1회 선정, 변경 성공 전 기존 표시/확정 실패 기존 유지 기준을09/27/NEXT_WORK/AI_CONTEXT에 기록했다. 별도 새 복구 화면/사용자 단계 선제 추가를 철회하되 응답 유실을 원 PUT 실패로 오인하지 않는 서버 일관성은 유지한다. 초기 대표 저장은 활동 집합 내 대표 제약과 기존 저장 흐름을 대조하며 전체 활동 자동추가/메인 전환을 함께 만들지 않는다.

Backend https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6209360031 정책 인계·원격 본문 확인. 이번은 기존 코드 조사·설계 축소 정정으로 신규 앱 흐름 없음/정상 코드 변경 없음. R1 전체1542PASS/분석0 재사용, 문서 diffcheck만 수행. 실서버·실기기·연결 구현 미확인. feature/scoped-account-cache/미커밋·미push·dev미반영·브랜치 유지, 기존 자료·사용자 Rules/tools 보존. DB/키/기기/환경/flag·배포/Issue 상태 변경 없음.


## 2026-10-16 — R1 이전 Backend 회신 항목별 확인 답변

사용자 요청으로 완료보고 이전 Backend6208988839를 재확인했다. 해당 회신은 R1에 이미 반영한 근거이며 별도 항목별 답변을 https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6209178794 에 게시·본문 일치 확인했다. 조회용 저장 유지, 미인증 power/replay 서버 권한·과거 cache 응답 투영 미완료, 최소 profile DTO와 전체Armory/인증 내부 장비조회 구분, owned/선택 전 분리와 파티/그룹 미래 서버 요구를 명시했다. Flutter 투영값은 현재 소비값이며 Backend 최종 계약 강제가 아님을 설명하고 실제 값/오류/필요 계약 차이·구현SHA 인계를 요청했다.

새 구현 흐름 없음/기존 기능 변경 없음. R1 전체1542PASS·분석0 재사용, 코드/테스트 변경 없어 반복 실행하지 않음. 미확인 실서버/기기 및 E1/E2/인증 전환 경계 유지. 문서·회신만 수정·diffcheck, feature/scoped-account-cache/기존 미커밋 변경 보존·미push·dev미반영·브랜치 유지. 서버/자료/flag·배포/Issue 상태 변경 없음.


## 2026-10-16 — D10 R1 기본 조회·상세 접근 분리 구현

사용자 진행 지시로 R1만 구현했다. Backend6208988839의 미인증 전투력 갱신/replay·과거 cache 노출 변경 필요 회신을 확인했고 기존8000/DB/자료로 개발을 계속했다.

- 새로 가능: 실제 BackendApp 기기 공용 DI의 basicOnly Repository/화면. siblings 검색 후 profile/전체Armory 추가 호출 생략, 기본 필드만 신규 저장. 실제 전투레벨은 수집값 대신 필수컬럼0, 기술 ID/서버/원정대 관계는 유지. 기기 공용 cache의 전투력/역할/소유 매핑은 반환값에서 제외하고 snapshot 조회는 빈 결과, profile/draft/빌드 저장·갱신은 거절. 과거 DB 행/키 삭제·새 DB 생성 없음.
- 실제 UI/Router: 기기 기본 카드에 이름/직업/아이템레벨만 표시, 인증 안내. legacy 상세/관리 deep link는 소유 안내로 차단, 일반 상세/관리 구현 자체는 삭제하지 않음. 미인증 서버 저장 문구를 조회용 저장으로 구분. 인증 성공→선택 연결은 E2 후속이며 이번 완료 주장 없음.
- V1/V2 응답 엄격 검증 뒤 미인증/소유상실 power/시각/상태 안전 투영. metadata 대표 요약도 소유/canonical/revision 확인 없으면power제외. 원본 응답/DB 비파괴. 소유 canonical 회원 상세는 현재 소유·관찰 상태를 확인하고 과거 cache/로딩·실패 상태에서 상세 노출하지 않음.
- 수동 전투력 최초 요청/재시도/결과 반영 전 최신 소유 재검사. 소유 없는 대상 POST0·재시도0, 현재 권한 없어도 local power fallback 하는 이전 표시 제거. 서버의 최종 권한·replay 검증은 별도 필요. 실제 소유 서버 구현 완료로 확대하지 않음.
- 보존 확인: 정상 owned V1 전투력·canonical 회원 상세/역할 저장·대표 E1·자동1회/나이스단OFF·표시/키·기본 검색·소유 인증 내부 장비 조회와 현재 환경. 기존 key/DB 경로/기본feature flag 변경 없음. 미인증이던 정상 기능은 이번 D10 승인 범위에서 제한.
- 검증: 최초 전체1538PASS/4실패(과거 preview power 보존 기대2/소유 metadata fixture·첫 갱신 진입 경계). 제한 대상 기대값과 fixture/진입 수정, 소유 값 기대는 보존. 직접 영향149PASS/분석0 뒤 공용 DTO/Router 최종 전체 **1542PASS**, lib/test 분석 **0**, format/diffcheck 통과. 신규10개 경계 검증. 로그 .dart_tool/basic-access-r1-tests-final.log 및 basic-access-r1-analysis-final.log.
- 미확인 실기기: 실제 소유/canonical 성공·서버 D10 권한/응답 반영과 실기기 화면/로그아웃/재실행·전송 경계. 기존 로그인/키 초기 재인수·기기 설치·게임 관찰 요청 없음. 기능 섹션 연결 후 사용자 테스트로 묶는다.
- 협업: https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6209153163 회신·본문 일치 확인. Backend 미인증 power/cache/replay 및 live 소유 증거 후속 유지. 다음은 E1 미확정 명령 복구 최소 보완, E2 및 인증 전환 연결이며 R1 완료로 대체하지 않음.
- Git: feature/scoped-account-cache HEADcc6a0b0, 이전 변경/사용자 Rules/tools 보존. R1 포함 미커밋·미push·dev미반영·브랜치 유지. DB/자료삭제·새환경·배포·flag ON·Issue종료·Git통합 없음.


## 2026-10-16 — D10 조회용 저장·인증 후 상세/활동 정책 채택과 구현 준비

사용자가 ‘미인증 조회용 서버 등록 유지, 인증 후 상세/활동 허용’ 안을 채택하고 구현 완료 뒤 테스트로 재확인하기로 했다. 현재 환경·개발자료 유지 기준으로 필수 문서/Git·관련 코드/최신Issue를 대조해 설계·준비만 진행했다.

- 확정 제품 정책은09 D10, 사용자 화면 흐름은 핵심 흐름 지도에 반영. guest 이름/직업/아이템레벨 로컬 기본 목록, 로그인 미인증 조회용 저장/복원·인증필요 표시, 인증 후 본·부원정대 사용 subset+대표 명시 선택과 상세·조건부 활동. 주 ‘인증하고 사용하기’/보조 ‘조회 목록에 저장’. 인증만으로 자동 메인/활동/대표 선택 없음. 자동 상세1회·NiceGroup OFF 예외·visible/count 분리 유지.
- 실제 차이: MyAccountViewModel.fetchCharacters의 siblings 후 fetchCharacterProfile, remote data source의 전체Armory 호출 및 AccountRepositoryImpl의 profile 로컬 저장 확인. UI만 숨기지 않고 Router·서비스·쓰기/캐시/기본flag OFF·늦은 응답 경계를 변경할 범위를 R1에 기록. 기존 정상 owned 분석/저장 기능·원래 DB/키·현재 데이터는 유지한다.
- 이후 구간: E1 미확정 명령 종결/재진입 최소 보완, E2 atomic 활동 선택과 인증 대상 전달·성공 registration_id→선택 화면 연결. 기능 섹션 구현/자동 경계 검증 후 사용자 실기기 체크리스트를 묶으며 초기 로그인/환경 재인수로 되돌리지 않음.
- Backend에 https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6208967265 로 사용자 채택·제품 경계·담당과 미인증 수동 전투력/상세 API·응답 권한 차이 대조를 요청했다. 게시 본문 일치 확인. 내부 인증용 장비 조회는 유지하며 새 API/DTO/DB 구조·lease 값을 임의 확정하지 않음. 서버 회신 대기는 해당 차이만 추적하며 독립 Flutter 준비/개발을 중단하는 조건이 아니다.
- 새로 가능해진 앱 흐름: 없음(정책/계획 준비). 기존 흐름 코드 변경 없음. 미확인: 새 정책 실제 호출/저장 제한·인증→E2·실소유/실기기 전체. 검증은 문서/관련 코드 대조·git diff --check; 기능 코드를 수정하지 않아 Flutter 시험/분석 반복 없음.
- feature/scoped-account-cache HEADcc6a0b0/origin-dev조회cc6a0b0, 기존 미커밋82항목/사용자 Rules/tools 보존. 정책/문서 포함 미커밋·미push·dev미반영·브랜치 유지. DB/키 삭제·이전/별도환경·배포/서버조작·flag ON·기기 설치·Issue 종료·Git 통합 없음.


## 2026-10-16 — 등록/인증/사용 캐릭터 재검토 회신

Backend6208702210의5개 연결 질문과6208670274의E1 복구 질문을 실제 Router/화면/ViewModel/client·기존 시험으로 대조해 https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6208744179 에 답변했다.

- 등록·소유 상태/설정 상태 별도 표시·등록/직접 입력 인증4경로·지정 장비/남은 시간/취소/명시 재시도·증거 보류를 인증 완료로 표시하지 않는 흐름은 연결돼 있다.
- 누락: 등록별 인증 진입 registration_id 사전선택 전달, verified 결과 registration_id→해당 소유 본·부원정대 canonical/활동 편집 진입, E2 활동 전체 집합+대표 atomic 편집/저장과 draft/충돌 복구. 현재 일반 재조회만 하는 성공 callback을 위 전환 완료로 해석하지 않음.
- E1: 동일 옛 GET은 pending 유지. 하지만 GET revision 변화로 해제, 광범위4xx/409 명확 실패 분류, 세션/재실행 미보존은 보완 필요. 앞선 ‘재실행만 부족’ 사용자 요약도 불충분해 실제 조건 전체를 회신했다. 서버 CAS만으로 안전하다고 확정하지 않음.
- 기존 인증 전체1282/후속1524·E1 전체1531통과/fixture1실패→직접영향18PASS/분석0 이력을 재사용. 원 PUT 종결·재진입 안전성/E2 편집/인증 성공→E2 전환·실서버/실기기 검증 완료로 확대하지 않음. 이번 코드/테스트 변경·반복 실행 없음. 새 흐름 구현 없음, 기존 정상 흐름 변경 없음.
- NEXT_WORK에 최소 보완/독립 E2/전환 연결을 구분 기록. 사용자 제품 정책 추가 결정·새 API 요구·새 환경·기초 재인수 요청 없음. 실제 소유 증거 Backend 후속과 실게임 관찰 나중 기준 유지.
- feature/scoped-account-cache HEADcc6a0b0, 기존 변경 보존/미커밋·미push·dev미반영·브랜치 유지. DB/자료/주소/flag·기기·서버·배포/Issue 상태 변경 없음.


## 2026-10-16 — E1 회원 메인 원정대 대표 왕관 연결

현재 환경·개발자료 유지 지시와 Backend6207867594를 확인하고 ACCOUNT-03 중 대표 전용 빠른 선택만 연결했다. 활동 전체 편집은 다음 E2이며 새 환경·기초 재인수로 돌아가지 않는다.

- 새로 가능: MemberAccountPage의 메인 원정대 표시 목록에 채움/윤곽18px 왕관(48px hit target), 취소좌/변경우 확인, 대상 진행 표시, 대표 전용 GET/PUT·현재 상태 확인/동일 명령 재시도·Retry-After 초 표시. 엄격 P2 DTO/UUID·4종 revision·멱등 key/body. 서버 확인 후 회원 목록과 대표 우선 정렬 반영.
- 권한/수명: 본인 메인 원정대·활동/confirmed/active/usable·표시 설정 확인/실제 표시 후보만 변경. cached/GET 실패/숨김/현재 대표 재클릭 차단. 알럿 뒤 재검증·직전 최신 roster 확인, 연타/중복 알럿 차단. 회원/환경/세션/관찰 세대가 바뀐 늦은 결과 차단. 불명확 결과는 앱 수명 동안 명령 고정, 재실행은 GET+서버 CAS로 확인. 최근 GET revision 진전이면 오래된 미완료 명령 해소.
- 보존 확인: 기존 Google 로그인/키·회원 표시/선호/count/역할·자동1회와 NiceGroup OFF 제외·숨김 캐릭터 검사 정책·상세 진입·원래 DB/guest 키. 대표 전용 쓰기는 활동 전체·표시/빌드·파티 참가를 변경하지 않는다. API 주소·DB/schema·기본 flag OFF·서버/환경 변경 없음.
- 검증: 최초 전체 flutter test 실행1531PASS/신규 fixture1실패. 오류는 모의 JSON의 계약 차단 코드/Map 타입으로 확인하고 fixture 수정. 최종 직접 영향 member_account_integration_test **18/18PASS(신규8)**, lib/test 정적 분석0, 포맷·diffcheck. 마지막 표시 후보 제한 보완 후 같은18개/분석 재검증. 넓은 코드 경계 변경이 없어 전체 재실행 대신 직접 영향 묶음으로 해소했다.
- 미확인 실기기: 실제 소유/canonical·실서버 변경/다기기 충돌·시각/터치/알럿·응답 유실 UI는 사용자가 해당 조건 준비 후 확인. fixture 성공을 실사용 통과로 판정하지 않음. 이전 기본 기능 전체 재인수 요청 없음.
- 인계: https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6208245362 결과 회신·원격 본문 일치 확인. 추가 Backend 계약/정책 변경·반복 검토 요청 없음. 다음 E2는 NEXT_WORK.
- Git: feature/scoped-account-cache HEAD cc6a0b0 유지. 이전 변경·사용자 Rules/tools 보존. E1 포함 미커밋·미push·dev미반영, 브랜치 유지. 배포/기기 조작/데이터 삭제/Issue 종료 없음.


## 2026-10-16 — 현재 개발환경 유지 정정·저장 연결 복구

자료 미승계를 별도 빈 개발환경/저장공간·기초 재인수 절차로 확대한 Flutter 판단을 철회했다. 현재 환경·개발자료로 계속 개발하고 베타 직전에 DB 내용만 비운다. 기능·환경 재구축을 요구하지 않는다.

- 바로잡은 흐름: BackendApp의 AccountDatabase/SecureApiTokenStore 원래 연결 복구. 잘못 추가한 BackendLocalData/helper·전용 테스트4개 제거. 실제 DB/키 내용 복사·삭제 없음.
- 보존 확인: 회원 scoped 저장/키·자동1회/OFF 제외·C 화면/로컬 기능·권한 경계 및 Firebase 전용 안내 정리 유지. API 주소·flag·서버 설정 변경 없음.
- 검증: 전체 flutter test 1524PASS, flutter analyze lib test 문제0, Dart format 변경0, git diff --check 통과. 과거1528은 철회한 전용4개를 포함한 당시 이력.
- 미확인 실기기: 설치/조작·실서버 소유 증명·전체 자동갱신 인수를 실행한 결과가 아니다. 기존 완료 흐름의 기초 재인수는 요구하지 않는다.
- 협업: https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6207542428 정정/완료 결과 반영·원격 본문 일치 확인. 과거 통합6207398915에도 철회 표시. Backend에 현재 환경 개발 계속 전달. 별도 환경 삭제 요청/실행 없음.
- Git: feature/scoped-account-cache, 미커밋·미push·dev미반영. 이전 기능/문서·사용자 Rules/tools 보존, 브랜치 유지.


## 2026-10-16 통합 정리 검토 수신·Backend 구현/HEAD 표기 보완

- 사용자 검토 회신 확인 요청으로 [Backend 검토6207472610](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6207472610)을 확인했다. 작업 순서/정책 이견·추가 질문/P2 변경 요청은 없고 기본 준비와 실제 증거 후속의 독립성/전체 인수 보류를 수용했다.
- Backend 구현/구성 기준4bdaea6976d209c85e0388e7a2b56ecab8a4b9a2는 불변, 최신 원격HEAD ee0023a2744ab63fc3feeccf6e5f98c608767d6c를 직접 ref/compare로 확인했다. 후속1커밋은 NEXT_WORK/AI_CONTEXT/DEV_LOG3문서만 변경이다. 기존 통합 댓글6207398915의 표기를 같은 댓글에서 보완·본문 일치 확인하고 중복 수신 댓글을 게시하지 않았다.
- NEXT_WORK·AI_CONTEXT에 수신·표기와 다음 순서를 반영했다. 남은 기본 준비는 대상 플랫폼/기기·호스트 접근 방식 결정→해당 /health 도달→실제 Base URL 확정이다. 호스트 loopback8001을 실기기 LAN 공개로 취급하지 않는다. 실제 관찰은 사용자 결정대로 나중이며 D 원격SHA/기기 결과는 여전히 미확인이다.
- 코드·실서버/포트·앱설정/설치·flag·DB/자료·배포·Issue 상태 변경 없음. 문서 diffcheck·내용 검토, Flutter 시험 반복 없음. 기존 D1528PASS/Backend65PASS 자동 근거 및 실인수 미확인 보존. feature/scoped-account-cache 유지·미커밋/미push/dev미반영이다.

## 2026-10-16 Issue8 시간순·최신 실행기준 통합 게시

- 사용자 `수정/토의/각자 결과 순서가 섞여 있으니 최신 답글로 순차 정리` 요청. 본문·전체41댓글의 게시 시각/구간과 최신6207306535를 대조했다. KST로 대표/L1/V2/S1~S3→P1/P2→A1/A2/B/C→정책 정정/제품 수용→D→새 환경/도구 순서의 주요 경과를 정리했다. 과거 계약 검토·구현/준비·실인수 상태를 혼합하지 않았다.
- Backend6207306535 수신: SHA4bdaea6976d209c85e0388e7a2b56ecab8a4b9a2의 새 환경 안내/관찰 도구 안내/compose.fresh 원문을 읽어 보고와 대조했다. 별도 fresh 프로젝트/volume/network·호스트8001/DB0009·health/P2 7027f0b OpenAPI 일치·준비 당시 주요테이블0건은 Backend 보고이며 Flutter 모바일 직접 검증으로 주장하지 않았다. 기존8000/DB0006 유지다.
- Backend 최신65PASS는 도구/격리 시험이며 사용자 JWT/게임 관찰·실소유 서버 구현은 미완료다. 사용자 결정은 도구 준비 후 실제 검증은 나중이다. ready_for_review/새DB/flag/fixture가 proof/canonical·전체 인수를 의미하지 않는다.
- [Issue8 최신 통합 정리6207398915](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6207398915) 게시·원격 본문 일치 확인. 현재 정책/완료 결과·원본/실행환경/Git·다음 기본 인수 준비→사용자 기본 결과 / 독립 증거 관찰·서버 구현 / 조건 충족 후 전체 인수를 통합했다. D 미실행/새 환경 미구성/제품 회신 대기/보존 화면 필수 등은 이전 상태라고 명시했다. 실제 변경 결과만 후속 회신하고 정책 검토를 반복 요구하지 않는다.
- NEXT_WORK·AI_CONTEXT·공유31에 최신 기준 링크와 새 환경 수신/실소유 보류를 반영했다. 새로 가능: 흩어진 댓글을 실행 순서와 담당·완료 조건으로 한 번에 파악할 수 있다. 기존 제품 합의/코드·검증 근거·구 자료 미승계/사용자 자료는 보존했다.
- 순수 문서/협업 정리라 Flutter 시험은 반복하지 않았다. 기존 D1528PASS/lib-test분석0 로그 재확인·git diff --check·문서/링크/본문 검토. 실기기/실provider·소유 서버 구현/전체 인수는 미확인. 이번에는 코드·실DB/기기/자료·서버 구성/재시작·배포·기능ON·Git/Issue 상태 변경 없음. feature/scoped-account-cache/cc6a0b0 유지·미커밋/미push/dev미반영이다.

## 2026-10-16 Flutter D 구 자료 승계 진입 분리·신규 로컬 저장 연결

- 사용자 `진행 가능한 작업을 진행합니다` 승인으로 필수 문서/실제 main→BackendApp/Router·DB/키/모집 소비·정책09/공유31과 최신 Backend6207049997을 대조하고 NEXT_WORK에 실제 D 설계/포함·제외·순서·회귀 게이트를 먼저 기록했다. feature/scoped-account-cache/HEAD·최신 origin/dev cc6a0b0 및 이전 변경/사용자 Rules·tools를 보존했다.
- 조사: 활성 lib/pubspec/Android 빌드에 Firebase SDK/실행 호출은 이미 없었다. 남은 구 서비스 자동 채택 지점은 BackendApp의 기본 lost_party DB/기존 guest key, 회원 화면의 device-characters 진입과 전용 복구 안내였다. 로컬 화면/DB·정수ID/분석 mapper·모집의 로컬 소비는 제품 기능에 필요하므로 유지했다.
- 새로 가능해진 흐름: BackendLocalData가 Backend origin+API path를 안정적SHA256으로 식별해 환경별 새 DB/guest secure key를 주입한다. 같은 환경 재실행 유지·다른 서버/경로/프로토콜/포트 격리. 구 lost_party DB·lost_ark_api_jwt를 읽기/검색/복사/import/삭제하지 않는다. BackendApp·OFF/guest 조회·관리/상세/분석·모집은 새 executor/store를 실제 소비한다. 회원ON 주목록은 기존 scoped 경로다.
- device-characters route·onLegacy/기존 기기자료 버튼을 제거했다. 활동/운영자 readiness의 Firebase Console/Rules·기존 저장소 전용 복구 안내를 제품/서버 상태 표현으로 바꿨으며 실제 권한 허용·쓰기 판정은 변경하지 않았다. 순수 로컬 DB 기본 생성자/기존 standalone 테스트는 남지만 main 실행은 새 factory를 사용한다.
- 보존 확인: 제품 조회/관리·상세/분석/비로그인 허용·모집 UI, 로컬 schema13·정수ID·순수 모델, 신규 Backend Google/session·회원키·설정·V1·S1~S3/A1/A2/B/C·역할/선호/표시·영속전송·자동1회/OFF·권한/수명/멱등. P2 7027f0b/API·scoped schema3/기기 schema13 변경과 새 권한/API 요청은 없다. 구 데이터 호환/승계 자체를 제품 완료 조건으로 유지하지 않는다.
- 검증: 최종 전체 **1528PASS(기존1524+신규4)**(52초), lib/test 분석0. 로그 `.dart_tool/d-full-test.log`, `d-analysis.log`. 관련 Dart format·git diff --check·diff/신규파일/UTF-8·문서 링크 검토. 신규 시험은 실제 임시 SQLite의 구/새 파일 분리·새 로컬 생성/재실행·환경 분리와 secure store의 구 키 미채택·새 키 유지/다른 환경 삭제 격리·잘못된 namespace 거절이다. 서로 다른 임시 파일/독립 executor를 쓰는 동시DB 시험에서 Drift 중복 인스턴스 경고는 출력됐으나 통과했다. 초기 format은 파일 반영 후 SDK telemetry 경로 권한 오류를 출력했고 최종 허용된 SDK test/analyze·포맷 상태/diff를 확인했다. 사용자 tools의 기존 전체분석 info3건은 변경하지 않았다.
- [Backend6207154064](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6207154064) 착수/우선순위도 수신했다. 실제 소유 증거를 최우선으로 하고 새 DB/API 준비와 Flutter D를 독립 진행한다는 인계이며 인증/환경 준비 완료로 표시하지 않았다. [Flutter D 결과6207225790](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6207225790) 게시·원격 본문 일치 확인, 추가 계약 수정/반복시험 요청 없음.
- 미확인 실기기: 실제 모바일 새 DB/secure 경로·guest 신규 키/조회·새 회원 기본 흐름·실provider·재설치. canonical/실소유/roster·서버 활동 대상이 필요한 전체 저장·자동갱신·복원은 Backend 증거 후속 준비 전 보류다. 빈0건/fixture/이름/bool/DB seed로 우회하지 않는다. 다음은 새 환경 API/구현 revision 인계 확인→기본 인수, 증거/활동 대상 준비 후 전체 인수다.
- 비실행/Git: 기본 flag OFF 유지. 구 파일/키·DB/볼륨/Firebase/기기자료 삭제·베타 초기화·API 재시작/서버 구성/배포·기기 설치/조작·proof/퇴역/claim해제 보류 해제·파티/운영/왕관/활동 신규 구현·Issue종료·Git통합 없음. 이전 인증/S1~S3/A1/A2/B/C/문서·사용자 Rules/tools 보존. feature/scoped-account-cache 유지, D 포함 미커밋·미push·dev미반영·새 인계SHA없음이다.

## 2026-10-16 Backend 제품/UX 검토 수용 확인

- 사용자 `회신을 확인합니다`에 따라 [Backend6207049997](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6207049997)을 확인했다. 기능/guest UX 유지·Firebase 전용/구 자료 승계 의존 제거 방향과 P2 7027f0b 일치 수용, 추가 제품 질문/계약 수정 불필요, 앞선 기본/전체 인수 구분 답변 대기 해소를 명시했다.
- NEXT_WORK·AI_CONTEXT·공유31에 수용을 기록했다. D 방향 검토 정보는 충분하고 사용자 착수 지시에 따라 독립 구현 가능하다. live proof/전체 실인수 보류와 Backend 새 DB/API 준비는 별도로 유지한다. 같은 정책 회신은 반복하지 않고 실제 D 결과/새 계약 차이에만 콜백한다.
- 문서/수신 확인만 수행했다. D 코드·DB/기기/자료·API/배포·Issue종료·Git 변경 없음. git diff --check·문서 검토, Flutter 재시험 없음. 기존 C1524PASS 모의 근거/미확인 실인수 그대로다. feature/scoped-account-cache 유지·미커밋/미push/dev미반영이다.

## 2026-10-16 앱 제품 설정·UX 공유 / Firebase 전용 구현 제거 기준

- 사용자 지시: Flutter의 장기 개발에서 확정된 앱 설정 중 Backend에 필요한 제품 정보는 공유한다. 기능/UI·UX는 동일하게 유지하고 Firebase 전용 구현·설계는 제거·미승계한다. 정책09 D09·공유 기준31을 작성하고 NEXT_WORK/AI_CONTEXT/문서 지도를 연결했다.
- 현재 SettingsPage·BackendApp·AppShell·회원 설정 controls와 대표 UX/현재 파티 제품 제약을 대조했다. 공유31에는 제품 정책/저장·복원 경계·현재 구현/후속 상태만 추출했다. 나이스단/자동1회·키/회원·역할 오류·visible/선호/순서/count·대표/활동 구분·회원1자리/이상 캐릭터 명시 변경·공통 확인/실패 UX를 공유했다. 과거 저장 기술/권한 규칙·호환 원장·운영/배포 구현은 새 계약으로 인계하지 않았다.
- D 범위 보완: 구 자료 승계 진입/전용 의존 제거는 기능 삭제 지시가 아니다. 조회·관리/상세 분석/설정·비로그인 허용 기능과 UX는 새 경계로 유지·대체한다. Drift/정수ID/화면·순수 mapper는 그 자체가 Firebase 전용이 아니며 실제 참조·제품 역할로 분류한 뒤 제거 범위를 정한다. 기존 D 문구를 화면/로컬 저장 일괄 폐기로 읽지 않도록 정정했다.
- [Backend 제품 공유6206946439](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6206946439) 게시·본문 일치 확인. 현재 UI 메뉴와 신규 Backend 연결 완료를 구분했다. 예: 수동 인증은 pending route/운영자 설정 repository 미주입이다. 새 기능 전체 착수·API 변경 요청은 없고 P2 원본7027f0b·소유 증거 보류/기본 인수 구분을 유지한다.
- 새로 가능: Backend가 필요한 제품 설정과 Flutter 실제 소비/미완료 범위를 기존 전용 기술과 혼합하지 않고 대조할 수 있다. 사용자 기능·UX·현재 코드/설정·권한 경계는 보존했다. 새 기능/실환경·실기기 완료를 주장하지 않는다.
- 문서/소통만 변경해 Flutter 시험은 반복하지 않고 기존 C1524PASS/lib-test분석0 근거를 유지한다. git diff --check·신규 문서 공백/UTF-8·링크/내용 검토를 수행했다. 코드·DB/자료·기기·배포/기능ON·Issue종료·Git통합 없음. feature/scoped-account-cache 유지·미커밋/미push/dev미반영이다.

## 2026-10-16 착수 전 Backend 회신 확인·새 회원 소유 증거 인수 경계

- 사용자 `작업을 시작하기전에 백엔드와 소통부터 / 회신확인`에 따라 이슈8 최신6206816156을 확인했다. 양측 개발/베타/운영 정책과 구 보존형 전환 폐기·새 기능 유지 기준은 일치했고 Backend는 새 빈 DB의 canonical 인수 준비1건을 질문했다.
- Backend 보고: live adapter가 proof_validated를 생성하지 않고 confirm은 PROVIDER_EVIDENCE_PENDING이며 preview로 canonical·소유/활동 자격을 만들지 않는다. Flutter runtime/설정 store의 owned/account·canonical/수명 guard와 기존 보류 안내를 대조했다. 새 DB/ON만으로 전체 실인수가 가능하다는 단순 순서를 바로잡았다.
- [Flutter 회신6206873992](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6206873992) 게시·본문 일치 확인. 환경 준비 후 새 로그인/키/회원설정·등록 preview/조회·빈목록/인증 시작·조회·취소·보류 안내는 기본 인수 후보, canonical/소유·현재 roster/활동 대상 준비 후 역할/개인설정 저장·전체상세/OFF제외·영속명령·기기 복원은 별도 인수 보류로 구분했다. count는 metadata 계약이지만 유효 등록/account·소유수명 자격이 필요하다. 빈0건/기본값/fixture를 실사용자 통과로 보지 않는다.
- NEXT_WORK·AI_CONTEXT에 barrier와 담당을 반영했다. D는 범위 기록만 있으며 새 회원 진입/UI 구현은 아직 없다. D 구 의존 정리와 Backend 새 DB 구성 준비는 독립 진행 가능하고 proof 후속은 Backend가 추적한다. Flutter가 fixture/이름/bool/DB seed나 새 우회 API로 증거를 대신하지 않는다.
- 새로 가능: 기본 인수/소유 증거 필요한 인수/독립 진행 구간을 구분해 작업 상호대기를 방지한다. 기존 제품 기능/권한 경계·C1524PASS 모의 근거는 유지한다. 실환경/실provider·실기기 인수는 미확인이다.
- 이번에는 소통·문서만 변경했다. git diff --check·문서/링크 검토, Flutter 재시험 없음. 코드·DB/볼륨/Firebase/기기 조작/배포·기능ON·Issue종료·Git통합 없음. feature/scoped-account-cache 유지, 미커밋/미push/dev미반영이다.

## 2026-10-16 개발·베타·운영 데이터 수명 확정 / 보존형 전환 전제 정정

- 사용자가 현재1단계 개발·자료 생성/삭제→베타 모집/준비→베타 전 개발 사용자/서버기록 전체 초기화→큰 이슈가 없으면 베타 자료를 보존해 운영하는 흐름을 직접 확정했다. 정책09 D08을 장기 기준으로 추가했다. 실제 데이터 삭제/초기화는 실행하지 않았다.
- 조사한 이슈 요청6185091368의 backfill/migration은 신규 PostgreSQL 내부 구조 변경이었다. 0007의 기존행 상태/NameClaim 채움, 0008/0009의 신규 테이블 생성 코드에 Firebase import는 없었다. 그러나 이것만으로 개발자료 보존형 작업이 필요하다고 판단할 수는 없다. Backend 회신6206662757은 기존 테스트 DB 백업/격리복원/보존 migration 리허설로 확장한 것이 Backend 판단 오류였고 그 계획을 폐기했다고 명시했다. Flutter의 P1/P2 구조 관리 코드 요청과 해당 확장을 구분해 기록한다.
- 새로 가능한 협업: 개발자료 보존/구 시스템 호환을 필수 조건에서 제외하고 새 빈 DB/최신 API·Flutter 환경을 기준으로 준비한다. 정책09·NEXT_WORK·AI_CONTEXT·설계23/계약30·문서 지도를 정정했다. 다음 D 후보로 `/account/device-characters`·구 목록/정수ID 관리/상세 routes·AccountDatabase/Repository/summary DI·모집 목록 소비의 구 의존 분리와 관련 조건 정리를 기록했다. 이번 정책 정리에서 D 코드 제거가 완료됐다고 표시하지 않았다.
- 유지 범위: 새 회원 scoped 저장/환경·UUID·소유수명/권한·멱등, 역할요약/개인설정·로컬 상세/영속대기·자동1회/OFF 제외·재로그인/기기 간 복원. 합의 API7027f0b 변경 필요는 현재 발견하지 않았다. 구 자료를 가져오지 않는 것과 새 시스템의 정상 자료 저장 기능을 제거하는 것은 구분한다.
- [Flutter 정책 수용·범위 회신6206739088](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6206739088) 게시·본문 일치 확인. Backend에는 새 DB 구성/실행 revision·API 준비, Flutter에는 D 정리 후 구 상태 미채택 테스트 환경/ON 빌드 조건을 각각 기록했다. 새 환경 준비 완료 회신과 실기기 인수는 미확인이다.
- 검증: 문서 내용/링크·git diff --check. 기능 코드 불변으로 기존 C1524PASS/lib-test분석0을 재사용하고 Flutter 시험은 반복하지 않았다. DB/볼륨/Firebase/기기 삭제·초기화/배포·기능ON·Issue종료·Git통합 없음. feature/scoped-account-cache/cc6a0b0 유지, 기존 변경/사용자 자료 보존·미커밋/미push/dev미반영이다.

## 2026-10-16 현재 상태 문서 정합성 갱신

- 사용자 `일단 현재 상황까지 문서 최신화` 요청에 따라 기능 코드 변경 없이 현재 문서·Git·검증 로그·Issue8을 대조했다. Issue8은 OPEN/댓글32개, 최신 C 결과6197881822 이후 추가 회신 없음, HEAD·읽기 조회한 origin/dev cc6a0b0를 확인했다.
- AI_CONTEXT를 현재 상태/기능 지도 중심으로 정리하고 오래된 ‘자동 실행 미연결·복원 계약 없음’ 상태를 제거했다. 상세 완료 과정은 아래 기존 A1/A2/B/C 이력에 보존한다. NEXT_WORK는 실제 환경 준비→ON 빌드 수동 인수의 담당·범위·완료 조건과 C 회신 링크를 명시했다.
- 후속 대장14의 인증 화면/POWER-01/RESTORE-01을 코드·자동검증 완료/실환경 미확인으로 바로잡고 활동/대표·왕관·live 증거/구 DB 정합성·릴리즈 인수와 분리했다. DB 조사24·인증28·ID29는 당시 조사/브랜치/수치와 현재 적용 상태를 구분하고 문서 지도도 갱신했다.
- 새로 가능해진 흐름: 코드 완료/실환경 대기/별도 후속을 문서 진입점과 대장에서 일관되게 파악할 수 있다. 기존 기능·합의·코드/테스트/사용자 Rules·tools는 보존했다.
- 검증: 기존 최종 전체1524PASS·lib/test분석0 및 전체 analyze의 사용자 tools info3건 로그를 재확인했다. 문서만 변경하므로 Flutter 검증은 반복하지 않고 git diff --check·변경 문서 링크/내용 검토를 수행했다. 실제 API/provider·기기/재설치 수동 인수는 미확인 그대로다.
- 협업: C 결과/대기 상태가 이미 회신됐고 새로운 계약·구현·테스트 결과가 없어 중복 Issue 댓글은 게시하지 않았다. 배포·기능ON·Issue종료·Git통합은 하지 않았다. feature/scoped-account-cache 유지, 미커밋·미push·dev미반영이다.

## 2026-10-16 Flutter C 앱 수명·회원별 주목록/진행 UI 연결

- 사용자 `진행합니다` 승인으로 설계23에 실제 DI/Router·데이터 흐름·소유·포함/제외·회귀 게이트를 먼저 기록했다. 최신 Issue8 B 회신6197379381과 origin/dev cc6a0b0를 확인했으며 새로운 Backend 실환경 준비 회신은 없었다.
- 새로 가능해진 흐름: BackendApp가 같은 lifecycle/runtime/API/session/remote/catalog/cooldown과 실제 설정/키/gate로 앱 소유 BackendMemberAccount를 한 번 생성·initialize한다. AppShell 진행 표시와 ON 로그인 회원 주목록·기존 기기 자료 별도 경로, 회원별 역할 수치/오류/시각·로컬 상세/원본 없음, P2 선호/표시/순서/count 편집·숨김 캐릭터 재접근을 연결했다. 첫 화면 비차단·준비 해결/처리수/전체수·미완료 상세/서버 저장 별도 재시도·대기시간·충돌/명시 서버값 수용·설정 snapshot 안내를 제공한다.
- 전체 준비는 회원/session/readGeneration별 B/복원이 공유하고 profile 하나로 양역할/P2 설정을 관찰한다. 캐시는 표시만 허용하고 새 쓰기는 fresh plan/현재 소유수명·guard/CAS로 진행한다. 로컬 선반영/서버 실패 pending을 유지하며 개별 역할 해결도 배치 대기 수에 반영한다. 키 없음/OFF 제외여도 서버 최소요약/설정은 복원한다. 열린 확인창은 회원/session 재검사·취소좌/긍정우, 페이지 폐기는 앱 runner를 종료하지 않는다.
- 보존 확인한 기존 흐름: 기기 schema13/정수PK·기존 목록/상세/관리·자료 무이전/무삭제, scoped schema3/8테이블 및 S1~S3/A1/A2/B, 양역할·나이스단OFF 예외·키/인증·V1·기본 OFF/guest 새 DB/V2 무호출. 자동 상세 대상은 표시 숨김/count와 독립이다. P2 원본7027f0b/API·서버 schema 변경은 없다.
- 검증: 신규 실제 SQLite/모의 HTTP 연결 경계10PASS 후 최종 전체 **1524PASS(기존1514+신규10)**·lib/test 분석0. 최종 role 재시도 대기시간 표시까지 반영해 전체1524를 다시 확정했다. 로그 `.dart_tool/c-integration.log`, `c-full-test.log`(38초), `c-lib-test-analysis.log`, `c-full-analysis.log`. 전체 flutter analyze는 기존 사용자 tools/roster_rebalance_domain_fixtures.dart의 info3건(상대 lib import2/print1)만 남는다. 해당 파일은 수정하지 않았다. 관련 Dart format·git diff --check·신규파일 공백/변경 검토 완료.
- 신규 검증: 공유 준비/전체 상세·프로필 복원 경합, 키 없음, OFF 숨김 복원, 로컬 선반영·같은 key/body 재시도, 로그아웃 지연 응답, 미확정 설정 보존, 계정 변경 gate의 지연 ACK 차단·명령 보존, 개별 서버 해결 집계, 회원 전환 중 열린 확인창 저장 차단, 상세 페이지 폐기 후 앱 runner 보존. 초기 시험 실패는 fixture가 기존 나이스단 레벨 조건/실제 personal-preferences 경로를 따르지 않은 오류로 수정했고 제품 정책은 바꾸지 않았다.
- [Issue8 C 결과6197881822](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6197881822) 게시·원격 본문 일치 확인. 추가 Backend 코드 수정/반복 mock 시험·제품 선택을 요청하지 않았다. 직접 다음은 실제 대상 API·DB 준비 확인→ON 빌드 사용자 수동 인수이며 NEXT_WORK에 체크리스트를 정리했다.
- 미확인 실기기 항목: 실제 P1/P2/V2 API/provider·기기 디스크 경로·재설치/새 기기·설정 복원/앱 재실행1회·OFF 제외·수동 실패/재시도·회원 전환/기존 기기 자료 인수. 기본 BACKEND_LIFECYCLE_READS_ENABLED=false 유지, 실제 DB0007~0009 적용·API 재시작/환경전환/배포·기기 설치/조작·실자료 이관/삭제·live proof/퇴역/claim해제 보류 해제·Issue종료는 수행하지 않았다.
- Git: feature/scoped-account-cache/HEAD 및 최신 origin/dev cc6a0b0 유지. 이전 인증/S1~S3/A1/A2/B/문서·사용자 Rules/tools 보존, C 포함 미커밋·미push·dev미반영·새 인계SHA없음. 실환경 인수/별도 Git 정리 전까지 브랜치 유지다.


## 2026-10-16 Flutter B UUID 상세 자동 갱신 실행부

- 사용자 `진행`으로 B만 구현했다. AGENTS/ai_rules/NEXT_WORK/AI_CONTEXT/지도·설계23/저장30/직접 관련 이력과 실제 Git·기존 int-ID startup/나이스단·설정/키/remote/runtime을 대조했고 설계23에 B 포함/제외·순서/완료·회귀 경계를 먼저 기록했다. 소비 계약7027f0b/새 API·DB schema 없음, C 실제 app/Router·화면 주입은 제외했다.
- 새로 가능해진 흐름: ScopedRefreshTarget/Batch·전체 roster 순수 projection, RuntimeStartupRefreshSource·ScopedStartupRefreshController를 추가했다. 현재 설정 GET/키 version·카탈로그/전체 등록·소유 roster 준비 뒤 환경+회원별 앱수명1회 선점, 부분/준비 실패 미소진, 동시진입/재진입 공유·대상0 종료·같은회원 새세션 자동반복0·회원별 결과 분리를 구현했다.
- 활성 UUID 전체의 Armory→기존 역할/무결성 분석→A1 원자 저장→요약 전송을 연결했다. 표시/상위 개수·별도1700 필터로 활성 대상을 줄이지 않는다. NiceGroupPolicy의 기존 정규화/사용레벨·2명 분류만 NiceGroupCandidate 공용 입력으로 추출해 전체 현재 active roster(활동 미선택 포함)에 적용했다. OFF는 상세/덮어쓰기0·정책 제외이며 실패/부정이 아니다. 역할불명은 보존·장비오류는 확정 계열+경고 저장·반대역할/선호는 보존한다.
- 시작 설정/대상 고정·설정변경 안내·미완료만 최신 조건 재시도/성공·신규·기존제외 미편입, 429 공용 deadline/자동 재호출 없음·미완료 보존, 서버 저장만 별도 재시도를 제공한다. 로컬 저장/서버pending은 상세 미완료와 구분한다. commit 완료 통지 후 취소라도 이미 저장된 결과는 보존하며 다른 회원 화면에 노출하지 않는다.
- 키/세션/현재 관찰·run guard를 A1 transaction에 전달하고 runtime.readGeneration을 추가했다. invalidateReads가 계정 요청 시작 시 DB row가 바뀌기 전에도 이전 배치의 늦은 저장을 막는다. accountChangesPending 준비 gate·source.changes와 app 단일 initialize/dispose 소유 계약을 설계23에 기록했다. source의 VM readiness callback과 actual BackendApp/Router 주입은 C가 담당한다.
- 보존 확인: 기존 startup/나이스단 결과·기기 공용 schema13/구 정수PK 자료, scoped schema3/8테이블/S1~S3/A1/A2·원자성/멱등/양역할, 키/인증/V1/기본 OFF·guest0호출. 실제 runtime/SQLite·모의 backend/provider로 저장/요약 전송·실패/키교체/등록변경/관찰무효화 후 지연 저장 차단을 확인했다.
- 검증: 초기에 신규 모델/adapter/controller만 분석해 nullable 접근2건을 수정하고 스타일을 정리한 뒤 B33PASS. gate/무효화2경계 보강 후 **전체1514PASS(기존1479+신규35)**, 이후 서버 저장만 재시도할 때 상세 정책 변경을 독립 처리하도록 좁게 보강하고 **최종 B35PASS/lib·test분석0**. format/diffcheck·변경/공백 검토 완료. `.dart_tool/b-final-tests.log`(40초), `b-final-boundary-tests.log`, `b-final-analysis.log`. 실행별 수치를 합산하지 않는다. dart fix의 복수 경로 인수는 허용되지 않아 한 디렉터리씩 실행했고 분석의 불필요 null 단언1건도 정리했다.
- [Issue8 B 회신6197379381](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6197379381) 게시·원격 본문 일치 확인. 최신 Backend 회신은 P2 완료이며 추가 Backend 수정/반복시험·실환경 전환을 요청하지 않았다.
- 미확인/후속: C의 실제 app 수명/DI/Router·회원별 단일 주목록/기존 기기자료 별도 경로·P2 설정/역할 표시·진행/재시도/충돌 해결 UI. B는 명시 생성/initialize 기반이며 아직 디바이스 인수 단계가 아니다. 실제 V2/P1/P2 API/provider/기기·DB0007~0009 적용/배포/자료이관·삭제·live proof/퇴역/claim해제·Issue종료는 없다.
- Git: feature/scoped-account-cache/HEAD 및 최신 origin/dev cc6a0b0 확인, 이전 인증/S1~S3/A1/A2/문서·사용자 Rules/tools 보존. B 포함 미커밋·미push·dev미반영·새 인계SHA없음. C 후속을 위해 브랜치 유지한다.

## 2026-10-16 Flutter A2 개인설정·원정대 표시 저장/복원

- 사용자 `a2 진행합니다` 승인. P2 7027f0b 개발문서/최신 Issue8·원본 OpenAPI 전체를 P1과 대조했다. 기존 paths와 역할 schema는 불변, profile의 preferences 참조만 실제 설정으로 교체·옛 가상 schema 제거/새5schema·2paths/3operations·profile policy 변경이다. 정확한 원본은 contracts/issue8-7027f0b.openapi.yaml, SHA256 fe78017938fc4c3ac7c66e5b6f7a756b676f381abd0d21cf4fb0786afeb765c1. 코드 전에 NEXT_WORK에 A2 범위/순서/완료·회귀 경계를 기록했다.
- 새로 가능해진 흐름: strict P2 선호역할/visible/display_order 및 원정대 visible_count GET/PUT·정확한 ACK, 실제 preferences profile 복원·기본값 no-op/version·저장시각. scoped DB schema3에 설정기록/명령2테이블을 추가하고 현재 등록/소유수명·캐릭터/세션·외부 guard/CAS로 로컬 초안+명령을 원자 저장했다. 발송 명령 불변·후속 초안/정확한 ACK·같은 key/body 재실행·429 수신 deadline/24시간 검토·충돌/명시 서버값 수용을 구현했다. UUIDv4 key 생성만 A1/A2 공용 순수 helper로 추출했다.
- 원정대 count는 metadata만 요구하고 비메인/일부 suspect를 막지 않는다. 개인설정은 현재 complete roster/캐릭터 근거를 사용한다. 삭제된 등록 경로는 차단하고 같은 소유수명 재등록 시 확정 설정만 현재 GET으로 복원하며 옛 명령은 새 경로로 이식하지 않는다. label 변경 후 원래 명령 replay와 최신 GET의 등록 version을 구분했다. 개별 rank ACK는 해당 캐릭터만 확정한다.
- runtime 같은 DB/API/session에 명시 prepare/readCached/read/save/sync/useServer를 연결했다. 네트워크 없는 캐시 복원은 fromCache 표시 관찰이며 새 쓰기 plan/ACK가 아니다. 미수집은 null이다. 순수 원정대 표시 projection은 visible→대표→rank→아이템레벨내림차순→이름→UUID 후 count 제한이며 hidden 대표·중복 rank를 보존한다. 실제 화면/자동 실행은 켜지 않았다.
- 보존 확인: 기존6캐시/역할 테이블·schema1/2 실제 기존행 migration·기기 공용 schema13/구 정수PK 자료, A1 역할 outbox/양역할·활동/대표·나이스단bool, S1~S3·키/인증/V1/기본 OFF·guest 무호출. profile parser만 P2 실제 설정으로 전환했으며 가상 기본값을 저장 성공으로 이관하지 않았다.
- 검증: A2+직접 영향106PASS 후 경계 추가, **전체1479PASS(기존1432+신규47)/최종 lib·test 분석0**, 관련 format·diffcheck/원본/변경 검토. 로그 `.dart_tool/a2-final-tests.log`(41초)/`a2-final-analysis.log`. 전체 후 테스트 스타일6건 정리로 신규47PASS(15초), 전송 직전 session guard 보강으로 직접 회원 경계2PASS(1초)·lib/test 분석0. 각 실행을 합산하지 않는다. Windows flutter.bat의 정규식 파이프 인수 해석으로 한 실행이 테스트 시작 전 실패했고 단일 member 필터로 바로잡았다. schema 생성은 해당 Drift 파일만 build_runner로 수행했다.
- [Issue8 A2 회신6196639685](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6196639685) 게시·원격 본문 일치 확인. 추가 Backend 수정/반복 시험·실환경 전환은 요청하지 않았다. Backend143PASS는 격리/mock 보고로만 보존한다.
- 미확인/후속: B 활성 전체 상세1회·나이스단OFF 제외 controller, C 회원별 주목록·진행/재시도 UI·실제 DI/Router 및 최종 인수. 아직 디바이스 테스트 단계가 아니다. 실제 P2/V2 서버/provider/기기경로·실DB0007/0008/0009 적용/배포·자료 이관/삭제·live proof/퇴역·claim해제 보류 해제·Issue종료는 없다.
- Git: feature/scoped-account-cache/HEAD·최신 origin/dev cc6a0b0 확인. 이전 인증/S1~S3/A1/문서·사용자 Rules/tools 보존. A2 포함 미커밋·미push·dev미반영·새 인계SHA없음, B/C 후속을 위해 브랜치 유지.

## 2026-10-16 Flutter A1 역할 요약·로컬 상세/영속 전송 대기

- 사용자 ‘백엔드 대기 동안 가능한 작업 진행’ 승인으로 앞서 확정한 저장 정책의 A1만 구현했다. 소비 원본은 Backend P1 6e4f625이며 새 제품 정책/전체 자동갱신 마스터 설정은 추가하지 않았다.
- 새로 가능해진 흐름: strict P1 GET/역할 PUT·기존 분석/역할 정책 projection, scope+UUID+소유수명+role별 상세 원본/요약·서버 확정 상태/최신 초안·전송 대기 저장. scoped DB schema1→2 두 테이블/복합FK·row CAS·세션/키/run/현재 관찰 guard, 원자 저장/rollback, 불변 key/body·재실행/응답 유실 복구·429 deadline·24시간 보수 중단/충돌·지연 ACK 후 새 초안 보존을 구현했다. runtime의 같은 DB/API/session에 명시 호출 API를 연결했으며 화면/자동 호출은 아직 없다.
- 보존 확인: 기존4조회캐시/실제 schema1 기존행 migration·기기 공용 schema13/정수PK 자료, 양역할/선호 설정·이전 역할 판정 흐름, 키/인증·V1 전투력·S1~S3와 기본 OFF/guest 무호출. P1 가상 preferences를 실제 설정 복원으로 적용하지 않았다. 새 자동 projection은 지원 직업의 현재 패시브/카탈로그 근거 없이 선호역할을 대체 근거로 쓰지 않는다.
- 검증: 최종 전체 Flutter **1432PASS(기존1394+신규38), lib/test 분석0**·관련 Dart format·git diff --check·변경 검토. 로그 `.dart_tool/role-a1-final-tests.log`(60초)/`role-a1-final-analysis.log`. 초기 신규27개 국소 통과 후 경계 보강, 초기 전체1431PASS/1FAIL은 OFF 진입의 동기 예외를 Future matcher에 직접 전달한 테스트 오류여서 closure로 수정했다. 분석 스타일2건도 정리 후 최종 전체1432로 확정했다. 실행별 수치를 합산하지 않는다. build_runner는 schema변경마다 scoped 생성 파일만 재생성했다.
- [Issue8 결과6196135272](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6196135272) 게시·원격 본문 일치 확인. 추가 Backend 수정/반복 시험·실환경 전환을 요청하지 않았다.
- 작업 중 [P2 완료6195735441](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6195735441) 수신. 원본7027f0b 확보/hash는 NEXT_WORK에 기록했다. 댓글 수신/원본 확보이며 전체 P2 대조/구현은 다음 A2다. P1 const preferences가 실제 설정으로 교체되는 호환 변경을 다음 단계에서 명시 소비한다. Backend143PASS는 격리/mock 결과이며 Flutter 수치와 별개다.
- 미확인/후속: A2 개인설정·원정대표시/복원, B 자동 상세1회·나이스단OFF 제외 controller, C 회원별 주목록·진행/해결 UI. 현재는 디바이스 인수 단계가 아니다. 실제 P1/P2 서버/provider·기기 경로/실기기, DB0007/0008/0009 적용·배포/실자료 정리·live proof/퇴역·claim해제는 실행하지 않았다.
- feature/scoped-account-cache/HEAD cc6a0b0 유지, 최신 origin/dev도 같은 SHA. 이전 인증/S1~S3/문서·사용자 Rules/tools 보존, A1 포함 미커밋·미push·dev미반영·새 인계SHA없음. 후속을 위해 브랜치 유지한다.

## 2026-10-13 기존 서비스 문서 레거시 분리

- 사용자 요청으로 legacy/firebase를 만들고 전용문서26개를 원래 docs 분류 경로로 이동했다. 혼합28문서의834항목과 추가정리8발췌은 원본 파일/절/분리직전행/내용SHA를 기록해 보관했다. 일반 제품·공용 협업 정책은 유지했고 옛 실행/배포자료가 새 서버의 자동 지시가 되지 않도록 지도·지침을 정리했다.
- 원문은 삭제 없이 이동/추출했으며 상대링크를 현재 경로로 조정했다. 이전 archive와 로컬Notion 자료의 잘못된 상대링크211개도 명확히 식별한 원본으로 연결하고 LINK_REPAIRS에 기록했다. backend-migration13파일은 보관 대상에서 제외했다. private 자료는 새 보관 위치에서도 Git 추적 제외를 유지한다.
- 검증: 1차이동/발췌 본문 보존대조,추가발췌 출처기록·상대링크/참조·diff 및 코드/설정·backend-migrationSHA 확인. 문서정리외 새 앱흐름 없음,Flutter/Emulator·실기기·Firebase 원격조회/배포·데이터삭제 없음.
- docs/backend-migration-analysis 유지·이번 작업 미커밋/push·dev미반영·merge없음. 기존 미추적실험/백업과 시작시점 작업결과 보존. 현재 문서에서 과거 기술/실행 내용은 보관지도에서 확인한다.

> 기존 서비스 전용 항목은 [원문·출처 기록](../../legacy/firebase/extracted/docs/project/DEV_LOG.md)으로 분리했다. 남은 제품/협업 문맥의 신규 서버 적용 여부는 별도 설계에서 판단한다.

## 2026-10-13 빈 데이터 신규 서버 설계

- 사용자 「기존 데이터/사용자 마이그레이션 없이 초기화」 및 「설계 진행」 지시로 신규 서버 빈 시작 정책을 반영했다. 이전UID/Player linking·분실자복구·export/import/census·기존operator승계/dualwrite를제외했다. 기존Firebase자료실제삭제·기기local자료파괴적초기화는승인/실행하지않았다.
- 09 결정 기록,10 서버구조,11 인증/권한,12 첫backend 작업패키지를추가하고00/02/03/06/07/08과문서지도를최신화했다. 신규user/socialidentity/session/gameownership 분리,guest회원/UID없음,모듈별책임·command원자성/DB제약·persistedevent/WS인가와첫login/publicread 단위를설계했다.
- 확정과제안구분: stack·guest정책·이관없음은사용자확정. 공개field/tokenTTL/추가provider연결/local보존·격리/첫operator는설계안/결정항목이다. 실제endpoint/DTO/SQL/Alembic는별도backend저장소에서확정한다. 신규DB에도미래소유권변경·중복/race·주차권한정책은필요하다.
- 외부기준확인: RFC8252 native OAuth 외부브라우저/PKCE,RFC9700 Refresh회전,OIDC identity 검증,SQLAlchemy task별Session·PostgreSQL CHECK/UNIQUE/FK 경계. 출처는10/11에연결했다. provider특정endpoint/credential이나실제DB/API를생성하지않았다.
- 검증범위: 문서링크·과거이관범위불일치/현재계약구분·diff검사와비문서추적파일SHA대조. code/Rules/config·운영Firebase/Auth/DB/배포·실기기·테스트실행/Issues/새repo/chat없음. 문서작성외새로동작하는앱흐름은없다.
- 기존미추적실험/백업·임시파일상태보존,현재docs/backend-migration-analysis 유지. 이번문서미커밋·push/merge/dev반영없음. backend첫작업은12의provider/계약/저장소준비이며자동코드착수하지않는다.

## 2026-10-13 dev 기준 백엔드 이전 사전 분석

- 사용자 지시로 dev e24baab에서 docs/backend-migration-analysis를 생성했다. docs/backend-migration/00~08 지정9문서 및 문서 지도/현재 작업을 작성했다. 신규 기능 구현이 아니라 Firebase 의존/데이터/권한/구독/화면/API 기능 요구/이전 위험과 단계 계획의 코드 근거 인계다.
- 조사: lib390 Dart 중 Firebase 관련62파일, SDK 경로·값·query 정적 source1909행 색인, Writer/DTO/Mapper78파일 field1340행 증거, snapshots21호출 전수 context, 복합index16선언과 Rules match/actual Router 연결 확인. 정적 출현 수이며 실제 실행 coverage/운영 사용량이 아니다.
- 보존 확인: 앱/Rules/설정/데이터 변경 없이 코드 추적. 원본 비문서 추적파일887개 SHA 비교·문서 상대링크/경로·query/permission 명칭 대조 및 diff 검사로 검증한다. 기존 테스트/실험/백업 유지. 문서 전용이므로 Flutter/Emulator/실기기 검증은 수행하지 않았다.
- 확인된 경계: 익명 Auth/Player 생성이 진입 선행 조건,게임 장비 인증은 client 메모리 검증,UID와Player 분리,aggregate/state/legacy schema와group listing 복사 공존,Drift/secure journal 기기전용. 실제 생성 Router와 비연결 주석 불일치·가짜 상세 DI·활동 projection 미연결·승인권한 adapter invalidRequest를 분리 기록했다.
- 미확인: 운영 Auth/데이터 census·활성 Rules/index·트래픽/비용,기존 익명 사용자 OAuth 연결/복구·공개 field/로컬 데이터 정책. FastAPI/SQL/API/WS 스키마와 token 수명은 후속 backend 설계에서 확정한다. Firebase 접속·배포·actual Issues·backend 구현 없음.
- 현재 문서 브랜치 유지,이번 산출 미커밋·push/merge/dev 반영 없음. 이전 코드 작업 브랜치 f3836dd의P1/P2/L1은 현재 baseline에 미포함이다. 실제 작업 완료 판정은 NEXT_WORK와 채팅 검증 결과를 따른다.

## 2026-10-11 성공본 커밋·운영 게시 완료

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0001)로 이동했다.

## 2026-10-11 B1+A2 전체 기능 Rules 테스트 게시 성공

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0002)로 이동했다.

## 2026-10-11 남은 A 구조와 B 로컬 이전 비교 설계

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0003)로 이동했다.

## 2026-10-11 한도 중단 구간 재개·최종 기록 확인

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0004)로 이동했다.

## 2026-10-11 공통 구조 통합 후보 구현·테스트 게시 실패

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0005)로 이동했다.

## 2026-10-11 운영 Rules 전체 구조 재설계 문서

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0006)로 이동했다.

## 2026-10-11 다른 함수군 삭제 진단 게시 성공

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0007)로 이동했다.

## 2026-10-10 사용자 요청: 구간별 수정 중단·상황 기록과 보존

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0008)로 이동했다.

## 2026-10-10 2-2 준비 표시 대조 검토 — 미채택

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0009)로 이동했다.

## 2026-10-10 2-1 준비 검사 중복 제거

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0010)로 이동했다.

## 2026-10-10 1-2 전환 출력 통합 — 누적 구현/게시 실패

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0011)로 이동했다.

## 2026-10-10 주차 인증·전환 호출 정리 — 로컬 완료/게시 실패

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0012)로 이동했다.

## 2026-10-09 B 깊이 후보 재판정·로컬 채택 (미커밋)

- 새로 가능해진 흐름: B-F1 복구 위 marker 통합을 안전하게 생성하는 별도 진입점 추가.
  b6b4003a/148794bytes, 최대깊이6→5·정리4 유지·41bytes 감소. 앱 기능 변화 없음.
- 보존 확인: 개인18·정리16·현재/과거 표식4·그룹집계22, 서버60건 통과. 정적3건으로
  B-F1 allow/다른 함수 불변·marker 식/순서 보존·옛 A2 입력 거절 확인. 상세 축소 설계 §32.
- 후속 로컬 기준으로 채택. 추적본/운영 승격·30% 대폭 축소·게시 실패 해결 완료가 아니다.
  다음 C는 구형 쓰기 계약의 의존·버전별 전환 설계이며 이번에는 자동 착수하지 않았다.
- 검증: 후보 생성·정적3건·구문·깊이·diff, Emulator1.22.0/영어 locale 서버60건.
  실기기 개인 완료/승계/그룹 전환·최종 운영 인수는 미확인, 원격 API/게시0.
- 기존 목적 브랜치에서 미커밋 유지. 브랜치 생성·커밋·푸시·머지 없음, 사용자4파일/추적본 보존.

## 2026-10-09 B-F1 개인 완료 분기 복구 (미커밋)

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0013)로 이동했다.

## 2026-10-09 작업 현황 문서 최신화 (미커밋)

- NEXT_WORK를 B-F1 단일 실행 범위와 이후 C~F 대기 계획 중심으로 정리했다.
  과거 누적 계획·우선 장애 컨텍스트는 archive/RULES_REDUCTION_2026-10-09_WORK_HISTORY.md에 보존했다.
- AI_CONTEXT·문서 안내·축소 설계·복잡도 문서의 현재 상태를 B-F 조사 완료/결함 미수정으로 맞췄다.
  A1-F/A2 정상 채택 보류, B 미채택, 게시·대폭 축소·운영 인수 미완료를 구분했다.
- 직전 조사 체크포인트 b63f105와 로컬 origin 작업 참조 일치를 확인했다. 이번 원격 재조회는 없다.
- 새 앱 흐름/기능 변경 없음. 기존 검증 결과를 재사용했으며 문서 내용·상대 링크·diff 검사만 수행했다.
  실기기 개인 완료/승계와 운영 인수는 계속 미확인이다.
- 사용자 지시대로 기존 브랜치에서 문서만 수정했다. 브랜치 생성·커밋·푸시·머지·배포 없음.

## 2026-10-09 B-F 개인 완료 실패 분리 — A1-F 회귀 확인

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0014)로 이동했다.

## 2026-10-09 B 단일 호출 통합 후보 평가·채택 보류

- 새로 가능: personalCompletionCommandMarker를 유일 호출자에 통합한 격리 후보 생성.
  조건/순서·중복 size 검사까지 유지, 최대깊이6→5·41bytes 감소. 앱 기능/운영 변화 없음.
- 보존: 정적2건으로 다른 모든 함수/allow 불변과 caller 원문 복원 확인. 그룹집계22건 통과.
  개인완료18건 중16건 통과(타인/inactive binding/부재 원본 포함).
- 실패: 개인 방장 완료 및 event 누락에 평가 한도. 같은 입력의 A2 기준도16/18로 동일 실패.
  새 회귀로 단정하지 않지만 정상 경계가 실패하므로 후보 채택 보류. 상세 설계 §29.
- close-body 통합은 existsAfter 뒤 getAfter 순서를 유지하기 어려워 미적용.
  정확한 평가식/문서접근 수·compiled 크기·원격 경고/게시 효과는 미측정.
- 검증: Node 정적2건·구문·diff·깊이 분석, demo Emulator 개인 기준/후보 및 후보 그룹집계.
  Emulator 종료. Flutter/앱 빌드·운영 API/배포0. 실기기 개인 완료/승계 인수는 미확인.
- 기존 목적브랜치에 커밋/푸시, dev/main 미통합·브랜치 유지. 사용자4파일/추적본/채택A2 보존.
  다음 B-F 기준 개인완료 실패와 과거 R1 통과 기록 대조. 대폭 축소/게시 문제 해결 미완료.

## 2026-10-09 A2 목록 안전성·부분 보정 실패 처리

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0015)로 이동했다.

## 2026-10-09 A1-F 승계 평가 한도 로컬 수정

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0016)로 이동했다.

## 2026-10-09 A1 실제 writer 기준 fixture 정합화·기준 승계 결함 분리

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0017)로 이동했다.

## 2026-10-08 호출 깊이 개선을 잔여 실행 구간에 통합

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0018)로 이동했다.

## 2026-10-08 최초 기획 정합성·Rules 호출 깊이 검토

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0019)로 이동했다.

## 2026-10-08 전체 Rules 저장·명령 계약 축소 가능량 조사

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0020)로 이동했다.

## 2026-10-08 R3 event 검증 재배치 설계·크기 증가로 미채택

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0021)로 이동했다.

## 2026-10-08 R3 실패 연산 분리·fixture 계약 차이 확인

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0022)로 이동했다.

## 2026-10-08 R3 소유권 정리 통합 로컬 후보·평가 한도 회귀로 미채택

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0023)로 이동했다.

## 2026-10-08 R3 명령 책임 설계·소유권 정리 후보 선정

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0024)로 이동했다.

## 2026-10-08 대화 중단 후 복구 점검·R2 로컬 축소 실측

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0025)로 이동했다.

## 2026-10-08 R1 공개 전환 이후 종료 집계 보완

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0026)로 이동했다.

## 2026-10-08 R1 writer 중복 API 제거·종료 listing 재생성 차단

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0027)로 이동했다.

## 2026-10-08 R1 목록 전용 서버 경계30건 검증

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0028)로 이동했다.

## 2026-10-08 R1 목록 누락의 평가 한도 회귀 보완

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0029)로 이동했다.

## 2026-10-08 R1 변경 슬롯 평가 비용 보완

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0030)로 이동했다.

## 2026-10-08 R1 로컬 목록 후보 — 재개 검증·평가 한도 회귀

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0031)로 이동했다.

## 2026-10-08 11:16 KST 운영 Rules 성공본 복원

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0032)로 이동했다.

## 2026-10-08 첫 구간 기준 조사와 운영 전체 차단 발견

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0033)로 이동했다.

## 2026-10-08 Rules 전체 영향 기획 재검토·문서 복구 지점

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0034)로 이동했다.

## 2026-10-07 Rules 대폭 축소 조사·설계

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0035)로 이동했다.

## 2026-10-07 조사 내역 문서 보존·작업 보류

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0036)로 이동했다.

## 2026-10-07 22:22~22:23 KST 제한 스코프 후보 격리 게시1회 실패

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0037)로 이동했다.

## 2026-10-07 HTTP/2 정상화 후 제한 스코프 후보5개 회귀 통과

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0038)로 이동했다.

## 2026-10-07 사용자 일반 터미널 재현·AdGuard 대조 준비

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0039)로 이동했다.

## 2026-10-07 로컬 Emulator 연결 원인 분리 — Rules 외 최소 HTTP/2 실패

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0040)로 이동했다.

## 2026-10-07 Rules 제한 스코프 후보 생성 — 정적 통과·Emulator 검증 보류

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0041)로 이동했다.

## 2026-10-07 Rules 격리2회 대조 — 기준 성공·후보 활성화400 재현

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0042)로 이동했다.

## 2026-10-07 Rules 게시 차단 1단계 로컬 비교 완료

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0043)로 이동했다.

## 2026-10-07 Rules 게시 차단 해결 기획·설계

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0044)로 이동했다.

## 2026-10-07 Rules CLI 디버그 게시 1회 — 최초 실패 400, 후속 409 확인

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0045)로 이동했다.

## 2026-10-07 BUG-024 보완본 재게시 — 컴파일 통과·활성화 실패

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0046)로 이동했다.

## 2026-10-07 BUG-024 실제 앱·추적 Rules 도입과 실기기 전 검증

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0047)로 이동했다.

## 2026-10-07 BUG-024 Spark C 상세 설계·격리된 8인 선행 검증 완료

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0048)로 이동했다.

## 2026-10-07 BUG-024 Spark A 격리 후보 구현·한도 검증 실패

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0049)로 이동했다.

## 2026-10-07 BUG-024 서버안 비용 전제 누락 확인·Spark 대안 재설계

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0050)로 이동했다.

## 2026-10-07 BUG-024 구현 후보 검증 실패·서버 트랜잭션 후속 설계

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0051)로 이동했다.

## 2026-10-07 BUG-024 분석·설계 문서화

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0052)로 이동했다.

## 2026-10-06 Android 1.1.1 공개 게시 완료

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0053)로 이동했다.

## 2026-10-06 BUG-023 완료 — 실제 두 방 성공 및 재발 방지 기록

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0054)로 이동했다.

## 2026-10-05 완료 상태 문서 정합성 최신화

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0055)로 이동했다.

## 2026-10-05 Android 1.1.0 공개 게시 완료

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0056)로 이동했다.

## 2026-10-05 Android 1.1.0 릴리즈 준비

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0057)로 이동했다.

## 2026-10-05 현재 구간 완료·dev/main 통합 승인

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0058)로 이동했다.

## 2026-10-05 안내 방식 변경

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0059)로 이동했다.

## 2026-10-05 사용자 관점 변경 안내·실기기 결과 정리

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0060)로 이동했다.

## 2026-10-05 12:03 KST — 운영 Rules 게시 성공

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0061)로 이동했다.

## 2026-10-05 02:10 KST — 테스트 프로젝트 전체 Rules 활성화 성공

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0062)로 이동했다.

## 2026-10-05 사용자 요청 — 실제 Rules 주석 전부 제거

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0063)로 이동했다.

## 2026-10-05 그룹 표시 검사 축소 완료·검증 기록

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0064)로 이동했다.

## 2026-10-05 01:15 KST — 배치 수정본 운영 게시1회, 활성화 실패

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0065)로 이동했다.

## 2026-10-05 함수 scope 배치 실험 — 서버 검사 재현 성공, 최종 배포 실행 차단

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0066)로 이동했다.

## 2026-10-05 00:58 KST — 정리 공통화본 게시1회 실패

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0067)로 이동했다.

## 2026-10-05 정리 Aggregate 동일 본문 공통화 — 제한 CI 통과

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0068)로 이동했다.

## 2026-10-04 소유권 읽기 재사용 후보를 실제 Rules에 직접 반영

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0069)로 이동했다.

## 2026-10-04 17:21 KST 검증본 게시 1회 — 업로드 성공·활성화 실패

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0070)로 이동했다.

## 2026-10-04 일반 추방·정리 거절 한도 수정본 승격

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0071)로 이동했다.

## 2026-10-04 제한 검증의 정상 회귀와 음성 평가 한도 분리

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0072)로 이동했다.

## 2026-10-04 대상 비교 축소 통과 및 중복 요청 거절 비용 보완

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0073)로 이동했다.

## 2026-10-04 — 대상 검색 축소 후보 실패 확인, 운영 게시 전 검증 중단

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0074)로 이동했다.

## 2026-10-04 — 거절 조기 검사 후보: 표식 사례 개선, 목록 위조는 잔존

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0075)로 이동했다.

## 2026-10-04 — 일반 제거 후보 정상 경계 통과, 거절 한도 잔존으로 채택 보류

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0076)로 이동했다.

## 2026-10-04 — Rules 전면 조사·기준선·실패 발생 시점 구분

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0077)로 이동했다.

## 2026-10-04 00:38 KST — 개인 완료 중복 제거본 게시1회 실패

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0078)로 이동했다.

## 2026-10-04 — 개인 완료 중복 fallback3곳 제거 검증·반영

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0079)로 이동했다.

## 2026-10-04 — 분할 성공 보고와 전체 무손실 축소 실패

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0080)로 이동했다.

## 2026-10-03 21:57 KST — 검증된 멤버 순서 수정본 게시1회 실패

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0081)로 이동했다.

## 2026-10-03 — 멤버 검증 순서 최소 수정, 기존 빈자리 변경 정상화

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0082)로 이동했다.

## 2026-10-03 — 자리 변경 중복 평가 제거 후보와 기준본 한도 실패

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0083)로 이동했다.

## 2026-10-03 — 테스트 프로젝트 게시 비교 및 복원 실패

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0084)로 이동했다.

# 2026-10-03 3구간 완료 — 정리 한도 수정·후보 검증·최종 Rules 반영

- 기존 슬롯8칸 반복 확인에 동등한 hasAll 빠른 경로를 추가했다. 최대8 제한과 신규/변경 슬롯의
  membership 차수 fallback은 보존한다. 단독 후보에서 기준본의 정리 한도 실패를 해소했다.
- CI37107454891은 생성 문자+ 오류로 컴파일 실패했고 11ca675에서 교정했다.
  CI37107631737은 수정/중복제거/이벤트분기 후보 각각61건 통과. 최종 같은 해시의
  CI37107959996 참가11건도 통과했다. 최종본72개 서버 사례이며 전체 회귀가 아니다.
- 새로 가능: 제한 CI의8인 무효참가 연쇄정리→승계→전환 정상 실행. 보존 확인: 과거 완료state와
  그룹 관계, 재시도/동시요청 원자성, 타인/변조/누락 쓰기 거절, 신규/legacy참가·재이전 거절·8인교환.
  실기기는 전부 미확인, 운영 게시503과 로컬HTTP2는 별도 미해결이다.
- 소유권/상태 비교 공통화와 이벤트 종류 직접 분기만 반영. 앱/스키마 무변경,
  사용자 초기화 설정 보존. 운영 게시/실기기/dev/main 병합/전체 회귀 없음.
- fix/roster-reauth-isolation에서 단계별 aed7f98→11ca675→bf0de02 복구 지점 push 완료.
  최종 반영과 문서도 같은 브랜치에 커밋/push한다. 상세는 TASK-11 최신 절을 따른다.

# 2026-10-03 제한 CI 실행 — 기준본 peer 정리 한도 실패

- 사용자 승인으로 기존 workflow에 complexity-comparison을 추가하고 dfd79fa 커밋/push 후
  demo CI37106260020을1회 실행했다. 전체 회귀/운영 배포 없음.
- 정적6건/생성 일치 통과, 기준본 최대8인 peer 연쇄정리 시나리오는 모집 update 평가식1000으로
  실패했다. 실패 후 자동 중단하여 두 후보/last-member는 실행하지 않았다. 후보 회귀로 판정하지 않는다.

# 2026-10-03 후속 로컬 HTTP/2 대조 진단

- 실행 환경의 전송 문제로 범위는 좁혔지만 구체적인 차단 주체는 미확정이다. 운영 Release503과
  동일 원인이라는 주장은 하지 않는다. 시스템 설정 무변경, 진단 프로세스 종료.
- 후보/배포 원본 변경 없음. 사용자는 격리 CI 확대 대신 로컬 진단 결과 기록 후 보류를 선택했다.
  원격 실행/운영 게시 없음. 전체 회귀 생략과 사용자 초기화 설정 보존을 유지한다.
  문서 diff 검사 후 전용 작업 브랜치에 진단 결과만 커밋/push한다. dev/main은 미반영이다.

# 2026-10-03 Rules 복잡도 후보 구현 — 정적 검증 완료·실행 검증 차단

- 사용자 승인 두 단계를 배포 원본과 분리된 변환으로 구현했다. 공통화 224298 bytes/274함수,
  이벤트 분기 추가 224358 bytes, 기준본 227459 bytes/279함수. 정적 호출 깊이 모두6이다.
- 새로 가능해진 제품 흐름 없음. 동일 소유권/상태 검사와 목록 비교를 공통화하고 이벤트 경로만
  종류별 후보를 만들었다. 모집/member/listing의 독점 분기는 잔존 marker/독립 명령 때문에 유지했다.
  권한·소유권·승계·스키마·앱 변경 없음. 정적 검토에서는 방장 전용 비교와 기존 allow를 보존했다.
- 제한 비교 runner와 명령/이벤트 종류 위조·잔존 marker event 재생성 거절 사례를 준비했다.
  원본 경로 override는 이 runner에서만 사용하며 과거 fixture/기본 proof 경로를 보존한다.

# 2026-10-03 14:37 DE 재게시 — 업로드 성공·활성화 503 분리

- 신규 4fedbc05 및 최근 5개 Ruleset은 로컬 SHA 11ef3dde…와 완전 일치.
  사용자 첨부의 /rulesets 503과 시간상 부합하는 저장본도 존재한다. 업로드 손실 추정은
  정정하고 저장/활성화 분리로 설명한다. 콘솔의 특정 선택 화면 자체는 미대조다.
- 180개 이력, 227459 bytes 소스/232551 bytes source JSON은 공개 제한 이내.
  컴파일된 크기와 서버 503 근본 원인은 미확인. 정상 권한/기능을 삭제하지 않았다.
- CLI updateOrCreateRelease가 모든 PATCH 실패에 create를 시도하는 코드 확인.
  최종409는 기존 Release 중복 생성의 후속 오류. 상세 근거와 지원용 정보는
  [게시 진단](../../legacy/firebase/docs/project/ROSTER_RULES_PUBLISH_DIAGNOSIS.md)에 기록했다. 지원 메시지는 보내지 않았다.
- 기존 검증 원본 무변경이라 테스트 반복 생략. 문서 diff 검사, 전용 브랜치 결과 커밋/push.
  dev/main 미반영, 사용자 초기화 설정 보존, 신규 실기기는 활성화 성공 전 대기.

# 2026-10-03 DE 통합 Rules 게시 1회 실패 — 사용자 전체 회귀 생략 결정

- 새 workflow의 기본 브랜치 미등록 404는 기존 workflow에 제한 실행 경로를 연결해 해결했다.
  중단 중 자동 승인 검토가 사용량 한도로 실패한 로그 조회는 미실행이었다. 사용자 재개 후 조회했다.
- 게시 전후 활성 ruleset `e46f131e-920a-4773-bc25-2ef4b7ff9169`, updateTime
  `2026-09-29T09:26:45.388946Z`, SHA256
  `e8baa2e4824d9200ab8a76fe07d7155578ba6982ca9b29941b9b7f55a6b3b1a5`로 동일함을 API 조회로 확인했다.
  통합 로컬 SHA256은 `11ef3dde97ac202f488d1a12d861c2cf20c13e50ef9c5c3e1dc45e1fdc3af151`이다.
  demo 컴파일 경고 미관찰. 운영 컴파일은 503이므로 성공/경고 0 확정이 아니다.
- 운영 실패만으로 특정 기능/복잡도를 원인으로 단정하거나 권한을 완화하지 않았다.
  재게시 반복 금지. 사용자 후속 지시 또는 직접 게시 결과를 확인한 뒤 실기기 13항목을 진행한다.
  [실기기 목록](ROSTER_REAUTH_DEVICE_CHECKLIST.md)에 준비/기대 결과/3기기 한계를 기록했다.
- fix/roster-reauth-isolation 유지, 통합/도구 커밋 1b32eb3→fca7f9c→3fdafe9→3e4316a push 완료.
  결과 문서도 같은 브랜치에 커밋/push한다. dev/main 미반영, 사용자 초기화 설정 변경 보존.

# 2026-10-03 DE 파트 1 — 마지막 1인 해산·중단 요청 복구 마무리

- 새로 연결: stale가 확인된 마지막 기존 공대장의 완료 반복방 해산. 모집 종료·그룹 count/listing·
  disband event를 같은 거래에서 쓰고, 기존 일반 해산과 달리 member/개인 state는 보존한다.
- 확인한 정리 요청을 기기에 저장한 후 전송한다. 응답 유실·앱 종료 후 레이드 현황의
  `참가 정리 처리 결과`에서 같은 event로 수동 확인/재시도한다. 서버 receipt를 먼저 확인하므로
  이미 참가에서 제외되어 방을 읽지 못해도 결과를 확인할 수 있다. 계정별 요청 분리,
  확인한 시각의 나노초 보존, 저장 실패 시 전송 금지, 불명 결과 보관을 적용했다.
- 정리 event 3종을 기존 알림에 연결했다. 완료 이력으로 투영하지 않고 알림은 현황으로 이동한다.
  기기 기록 삭제는 별도 확인하며 서버 취소가 아님을 안내한다. 자동 실행/일괄 정리는 없다.
- 보존 확인: 일반/peer/승계 계획, 마지막 1인 참가·완료 기록, 다른 사용자/요청 저장,
  기존 event mapper와 알림 계약. 표적/기존 테스트 17건 통과, 변경 10파일 analyze 무결함,
  포맷·내용/diff 검토. 최초 brace 형식 1건은 수정했다.

# 2026-10-03 DE 파트 1 — 공대장 상실 시 제한 정리·승계 연결

- 사용자와 남은 범위를 두 파트(관계 정리 마무리 / 통합·실기기)로 고정했다.
- 새로 연결: 유효 기존 참가자의 stale 공대장 아래 peer 단건 정리와 첫 잔여 후임 승계.
  최신 차수·모집 revision·대상/후임 membership과 확인한 승계 정보를 최종 거래에서 재검증한다.
  상세 확인창에 후임 이름을 표시하고 정상/unknown 대상 또는 뒤순번 승계는 허용하지 않는다.
- 보존: 일반 참가자 본인/유효 공대장 정리, 기존 활성 탈퇴/추방 무변경. 개인 state/claim 및
  완료 이력·그룹 membership은 쓰지 않는다. 후임 승인권한과 모집/listing 표시를 원자 갱신한다.
# 2026-10-03 DE — 완료 반복방 일반 참가자 정리 앱 연결

- 새로 연결: 실제 Router의 별도 Repository, 상세 화면의 참가 자격 확인/대상 확인,
  최신 거래의 모집 revision·member 갱신 시각·현재 소유권 차수 재검증과 단건 원자 저장.
  대상 본인 또는 현재 소유권이 유효한 공대장만 일반 참가자 정리를 실행한다.
- 보존: 활성 탈퇴/추방 경로 무변경. 개인 raidState/claim·그룹 membership·완료 이력은
  정리 거래의 읽기/쓰기 대상에서 제외한다. 모집/member/listing/event만 변경한다.
- 검증: 최대 8인 구성·순서 보존/권한·상태 거절/정확한 event 재시도/차수 경계 4건 통과.
  변경 4파일 analyze 무결함, 포맷/diff check 통과. 최초 잘못된 화면 getter 및 brace 경고 수정.
  일반 D/E5 서버 후보는 무변경으로 기존 결과를 재사용하며 새 Dart 거래 실행 검증은 아니다.
- 전용 fix/roster-reauth-isolation 유지, 단계 커밋/push. dev/main 통합과 운영 배포 없음.
  사용자 raid_cycle_schedule.dart 로컬 변경 보존. 상세 설계 §22.12/NEXT_WORK를 따른다.
# 2026-10-02 DE2-H3 — 고아 active 참가 기록 정리 보호

- 새로 연결한 흐름: 계정 화면과 방 상세(신청/가입/Character 변경)의 확인 당시 state/assignment
  관찰을 정리 명령에 전달한다. 최종 거래가 최신 소유권과 두 원본 버전을 비교하고, 교체/재인증/
  일부 기록 변경/unknown이면 삭제하지 않는다. 같은 권위에서 두 기록 부재는 멱등 성공한다.
- 보존 확인: demo 서버의 부모 부재·완료·해산·미완료 종료와 legacy 0 정상 정리, 완료 이력/event
  보존. 낡은 state/assignment·소유자 이전/재이전·새 방 state·부모 raid 불일치·inactive 권위와
  혼합 삭제를 원자 거절했다. 서버는 확인창 버전을 알 수 없으며 이 보호는 앱 거래 책임이다.
- 검증: 77c4c5c / CI 37018576574 15/15, SHA256
  bfe1a21420cdae392d28c0900634440e83eb07326afca467b6896dc63f1a7d99.
  관찰 정책 5+ViewModel 7 = 12/12, 변경 6파일 analyze 무결함, JavaScript 구문·diff check 통과.
  처음 CI dispatch는 선택 목록 들여쓰기 때문에 422로 실행 전 거절되어 해당 설정만 수정했다.
  첫 Dart 포맷의 사용자 캐시 권한 오류는 허용된 실행으로 해결했다.
# 2026-10-02 DE2-H3 — 완료·취소 실제 앱 연결

- 실제 Router가 사용하는 WeeklyRaidStatusCommandRepository와 Page/ViewModel에 확인 전 관찰을 연결했다.
  신규 완료는 현재 소유권 차수를 저장하고 과거 차수 점유/claim/assignment를 현재 이용 근거에서 제외한다.
- 새로 보호한 경계: 확인 이후 재인증·다른 방 참가·완료 삭제 후 재생성·주차 변경은 최종 transaction에서
  관찰과 대조해 거절한다. 취소는 현재 완료만 삭제하며 과거 차수 기록과 active 참가를 보존한다.
- 참가 중 완료는 기존 제거/승계/해산 Write Plan을 재사용하며 확인 당시 모집 revision,
  member/slot 차수와 후임 현재 권위를 대조한다. pending 후처리는 확인 전 신청 버전과 최신 완료/소유권을
  검증해 새 신청을 종료하지 않는다. 확인 관찰은 서버 권한을 대신하는 토큰이 아니다.
- 검증: 관찰 경계 4건+기존 ViewModel 7건 = 11/11, 변경 코드/테스트 6파일 analyze 무결함,
  포맷·diff check 통과. 첫 분석의 불필요 null 연산 2건/brace 4건을 수정했다.
  기존 체크 요청·projection·고아 정리 전달·표시 설정 흐름을 ViewModel 수준에서 보존 확인했다.

# 2026-10-02 DE2-H3 — 참가 중 개인 완료 서버 경계

- a9f6732 / CI 36977516726: 개인 완료 15+파티 밖 수동 완료 22 = 37/37 통과.
  SHA256 `46e7e4d15115b7d86ff833f5220d72450bfc40706b4cf8978cdb7e7f256d960e`.
- 새로 검증한 흐름: 8인 일반 참가자 완료·공대장 완료 후 승계·마지막 1인 그룹방 해산.
  state/member/slot 및 현재 권위 차수 불일치, stale 후임, 필수 7종 쓰기 누락은 전체 거절한다.
- 보존 확인: 다른 참가자 state와 그룹 membership, 기존 수동 완료·취소/과거 이력 22건.
  일반 참가자를 마지막 슬롯에 배치했다. 모든 역할·배치·legacy 개인 완료 조합의 전수 검증은 아니다.
- 직전 후보 baseline에서도 8인 정상 요청 실패를 확인했다. 직접 명령 분기, 개인 완료에 한정한
  exact target map 비교, 필수 후임 쓰기의 소유권 검증 분담으로 비용을 줄였다.
  후보 생성기의 줄바꿈 오인으로 후임 검사가 application에 삽입된 오류는 수정·재검증했다.
  실패 실행 번호와 세부 판정은 설계 §22.9에 보존했다. 실패 당시 거절만으로 보안 완료를 주장하지 않는다.
- 사용량 한도로 baseline commit/push/CI 명령이 실행 전 차단됐고 사용자 재개 후 수행했다.
- 미확인: 실제 완료/취소 앱 연결·고아 정리·전체 회귀·운영 이식/배포·사용자 실기기.
  전용 브랜치 commit/push 유지, dev/main 미반영. 사용자 초기화 설정 변경 보존.

# 2026-10-02 DE2-H3 — 파티 밖 수동 완료·취소 서버 후보

- 실제 Router/Repository의 차수 미확인과 pending 후처리의 재신청 경쟁을 조사하고 설계 §22.8에 기록했다.
- 최초 CI 36974335271은 검증 도구의 snapshot 반환 누락으로 실패했다. 정상 서버 요청은 성공했으나
  사후 비교가 불가능했으므로 당시 거절/원자 보존 결과도 완료 근거로 사용하지 않는다.
- 반환값을 명시 저장하고 독립 claim/assignment 차단 4건을 추가한 9180e77 / CI 36974569566은
  22/22 통과했다. 새로 확인한 흐름은 현재 차수 수동 완료·과거 차수 state 대체와 다른 이력 보존이다.
  기존 legacy 완료 취소·active 보존, stale 취소/위조/복합 삭제 전체 거절도 확인했다.
- 활성 참가 완료/승계/고아 정리/후처리와 실제 앱 연결·실기기는 아직 미완료다.
  전용 브랜치 체크포인트만 남기며 dev/main 통합·배포는 수행하지 않는다. 사용자 초기화 변경 보존.

# 2026-10-02 DE2-H3 — 후보·주간 현황의 소유권 차수 읽기

- 세 원본 record의 차수를 보존하고 최신 Character/계정 판정 후 기존 주간 projector에 전달한다.
  과거 차수는 제외하고 현재 관계는 유지, 불명확하거나 손상된 권위는 오류로 전달한다.
- 기록별 Character/계정 공유 구독, 의존성 제거 취소, 지연 이벤트/오류 후 낡은 결과 차단을 연결했다.
  후보 단건 lookup도 읽기 transaction과 공통 점유 inspector를 사용한다.
- 검증: 스트림/소유권 3+기존 projector 4+lookup 계약 1 = 8건 통과. 변경 분석 무결함·diff check 통과.
  앞선 한도 차단은 명령 실행 전 승인 검토 실패였고 이번 사용자 재개 후 검증 완료했다.
- 전용 브랜치 commit/push, dev/main 미반영. 사용자 초기화 변경 보존. 다음 수동 완료 쓰기는 §22.7 참조.

# 2026-10-02 DE2-H3 — 캐릭터 변경의 과거 참가 부활 차단

- 기존 변경 경로가 새 Character만 검증하고 이전 member 차수를 확인하지 않는 누락을 발견했다.
  공통 member update guard로 atomic/legacy 경로를 보호하고 실제 Repository도 이전 소유권을 확인한다.
- 새 Character의 inspector에 소유권을 전달해 과거 점유 대체를 연결했다. 이전 state가 불일치하면 거절.
- 950d1e8 / CI 36966494266 통과 후 공통 guard로 확장한 최종 6146fef / CI 36966679938 22/22 통과.
  정상 최대 8인 변경 보존·구세대 참가 변경의 원자 거절을 확인했다. 변경 Repository analyze 무결함.
- 후보 목록은 단건 lookup 외 주간 상태 projection도 사용함을 확인했다. 차수 정보가 합치기 전에
  사라지는 문제로 공통 읽기 단계 설계를 §22.6에 기록했다. 후보 목록 수정 완료로 처리하지 않는다.

# 2026-10-02 DE2-H3 — 직접 가입·승인 시점 변경·8인 Character 변경

- CI 36965944125: 신규 직접 가입/승인 시점 점유 변경 및 기존 경계 통과, 8인 Character 변경 실패.
  변경 경로의 차수 미구분 weekly completion 검사가 남아 있었고 fallback 평가 한도에 도달했다.
- 063132c / CI 36966140325: 해당 claim 검사를 차수 기준으로 정렬한 뒤 21/21 통과.
  같은 owner 재취득 차수 3→5 사례로 실제 서버의 오래된 승인 거절도 검증했다.
- 새 서버 후보 흐름: 직접 가입 및 최대 8인 제자리 Character 변경의 구세대 점유 대체.
  보존 확인: 과거 room/event/claim, 현재 차수 점유, 실패 거래 원자성 및 기존 17건.
- 미확인: 그룹/다른 파티 이동 결합, 앱 Character 변경/후보/수동 완료 연결, 전체 회귀·실기기.
  상세/후보 해시는 설계 §22.5. JS 문법/diff check 수행, Flutter 무변경으로 재실행 없음.

# 2026-10-02 DE2-H3 — 생성·신청·가입 점유 판정 앱 연결

- 공통 PartyOwnershipRecordPolicy로 식별자·차수·state 상태를 검증한다. Create 별도 경로와
  Application/본인 Join의 inspector에 적용했다. 실제 Router의 Repository 주입도 확인했다.
- 새 연결: 과거 차수 점유는 선삭제 없이 신청/생성 진행, 최종 참가 Write Plan으로 대체.
  구세대 weekly claim은 보존하고 현재 차수 claim은 제한한다. unknown은 거절한다.
- 기존 보호: 현재 차수 주차/고아 정책, 승인자의 신청자 private 조회 금지, 원자 Write Plan 유지.
- 검증: 신규 정책 3건+기존 소유권 4건, 총 7건 통과. 변경 파일 6개 analyze 무결함, diff check 통과.
  정상 UI의 중복 자동 테스트 및 중간 전체 테스트는 실행하지 않았다. baseline 22 실패/51 analyze 유지.

# 2026-10-02 DE2-H3 — 구세대 점유 원자 대체 서버 proof

- 중단된 CI 36886677940은 13건 통과. 필수 쓰기 누락 4건을 추가한 072df61 /
  CI 36965088067은 17/17 통과했다. JS 문법·git diff --check 통과.
- 새로 검증한 흐름: 과거 active/completed/legacy 점유가 있어도 현재 차수로 신규 생성·신청·승인 가능.
  신청은 과거 state를 보존하고 승인 시 교체한다. 승인자의 private state 조회는 계속 거절된다.
- 보존 확인: 과거 room/event/claim, 현재·손상 차수의 state, 누락 쓰기 실패의 전체 데이터,
  두 생성 경쟁에서 하나만 저장. 미확인 범위와 후보 해시는 설계 §22.3을 따른다.

# 2026-10-02 DE2-H3 — 참가 차수 서버 경계 검증

- 중단 지점의 후보 생성기를 복구했다. 최초 CI 36876958794의 컴파일 오류는 trailing-space 검색이
  모집 update 대신 하위 member부터 그룹까지 감싼 원인이다. 정확한 줄 시작/세미콜론 경계로 제한했다.
- de88e8b / CI 36883705580: 10 통과, 정상 8인 교환 1건 평가 한도 실패. 위치 전용 쓰기에 기존
  validMemberPositionChange를 먼저 평가하도록 보정했다. 기존 권한/validator는 제거하지 않았다.
- 84f5ad1 / CI 36884163312: 11/11 통과. 정상/legacy 생성·신청·승인, 차수 위조 원자 거절,
  재이전 후 오래된 승인 차단·명시 재신청, 최대 8인 자리 교환의 기존 차수 보존을 확인했다.
- JS 문법/diff check 통과. Flutter 변경 없음으로 Flutter 테스트 미실행. 기존 22 실패/51 analyze 유지.
  동일 전용 브랜치에 체크포인트 commit/push, dev/main 미반영. 사용자 초기화 변경 보존.
# 2026-10-01 DE2-H2 — 실제 참가 경로 최신 소유권 연결

- 생성·신청·즉시 가입/승인·참가 Character 변경에 공통 계정/Character 소유권 조회 연결.
  같은 transaction에서 확인한 차수를 H1 Write Plan에 전달한다. 이전 신청의 제출 차수를 현재 값으로
  덮어쓰지 않으며 재이전 후 오래된 승인도 거절한다. 신청자의 private state를 승인자가 읽지 않는다.
- current/ownershipChanged/unknown을 구분. 읽기 실패·권위 문서 부재/불일치·미래/손상 차수를
  정리 근거로 삼지 않는다. 아직 구세대 점유 대체나 정리 UI가 연결됐다는 뜻은 아니다.
- 검증: legacy·A-B-A·계정 불일치·손상/미래 차수 정책 4건 통과. 실제 Repository 포함 변경 파일
  analyze에서 신규 test lint 1건 수정 후 재분석 무결함. 무관한 전체 포맷 차이는 제거, diff check 통과.

# 2026-10-01 DE2-G2 / H1 — 차수 서버 검증과 참가 Snapshot 보존

- G2 최초 CI 36841529052는 검증 도구 Snapshot 반환 오류로 실패. 거절 PASS도 보존 근거로 사용하지 않았다.
  수정 527ea62 / CI 36874438459는 15/15 통과. 차수 전이·legacy·삭제/누락/감소·불일치·원자성,
  동시 인증의 유효 거래와 명시 재시도 수렴 확인. 후보 해시와 한계는 설계 §21.1.
- H1: 슬롯의 선택 차수를 누락과 명시 0으로 구분. 생성/가입/member/state/신청 Write Plan이 차수를
  받을 수 있고, 캐릭터 변경은 새 차수, 자리 교환은 원래 차수, 주차 전환은 참가 슬롯 차수를 유지한다.
- 검증: 관련 33건 중 초기 32 통과/새 null fixture 1 실패. fixture Map 타입 보정 후 해당 4건 재검증 통과.
  변경 파일 analyze의 신규 lint 7건을 수정하고 해당 파일 재분석 무결함. git diff --check 통과.

# 2026-10-01 DE2-F / DE2-G — 마지막 1인 해산 proof와 실제 인증 차수

- 사용자 승인: 실기기 전 잔여 구간을 순차 진행. fix/roster-reauth-isolation 고정.
- F: 기존 해산의 목록/event 누락·완료 state 삭제가 허용되는 서버 경계를 확인했다.
  제한 guard+기존 lifecycle 직접 분기 후보 e7f447e, CI 36840397200에서 10/10 통과.
  중간 실패는 설계 §20에 기록했고 정상 실패를 보안 성공으로 세지 않았다.
- G: 자동·수동 공통 인증에 신규 1/legacy 0/같은 owner 유지/실제 이전 +1 정책 연결.
  기존 Character의 계정·owner·차수 불일치 및 참조 계정 부재를 쓰기 전 거절한다.
  missingFromLatestRoster Character에도 같은 차수를 기록한다.
- 검증: 차수·legacy·재이전·손상 정책 4건+기존 인증 시작 3건=7건 통과, 변경 4파일 analyze 무결함,
  diff 확인. 광범위 기존 포맷 변경은 제거했다. 전체 검사·실기기는 실행하지 않았다.
- 미완료: 인증 차수 서버 강제/동시 인증, 참가 Snapshot 및 신규 이용/정리 UX, 운영 반영과 실기기.
  사용자 초기화 수정 보존, dev/main 병합 없음. 같은 브랜치에 복구 지점을 기록한다.

# 2026-10-01 DE2-E5 재개 — 제한 정리/승계 demo 48건 통과

- 사용량 한도로 자동 승인 검토가 완료되지 않아 실행 전 중단된 커밋·push·CI를 재개했다.
  4af81d9를 fix/roster-reauth-isolation에 커밋·push, CI 36838000885 전체 성공.
- 새로 확인한 demo 흐름: 최대 8인에서 6명 단건 정리 후 방장 승계/주차 전환, 다른 호출자와
  후임의 정상 승계, 동시 중복 요청 후 명령 대조 재시도, 부분 진행 중단/재개가 통과했다.
- 신규 22건+기존 D 26건=48건 통과. 기존 active 탈퇴/추방·본인/방장 정리·다른 방 state,
  완료 기록/그룹 관계 보존을 확인했다. 위조/부분 쓰기 거절과 조회 후 소유권 변경도 검증했다.
- 실제 앱에 새로 연결된 기능은 없다. 인증은 admin fixture이며 제품 인증 차수/Snapshot/UI,
  마지막 1인·public/legacy 전체 조합·실기기 및 모든 동시 조합은 미확인이다.
- origin/dev 68f0508 유지 확인. 운영 배포·dev/main 통합 없음. 기존 전체 22 실패/analyze 51건과
  사용자 초기화 변경 보존. 상세 해시/비용 한계는 설계 §19.2, 다음은 DE2-F 마지막 1인 경계.
- 문서 마감도 같은 브랜치에 커밋·push하고 브랜치를 유지한다.

# 2026-10-01 DE2-E4 재설계 — 단건 정리 후 승계 권고

- 원정대만 읽기는 현재 연결 불변/Character 부재 unknown/legacy 계약을 그대로 보존하지
  못한다. 단순 조회 제거는 채택하지 않고 일반 stale 단건 정리 후 첫 잔여 후임 승계를 권고했다.
- 사용자 결정 대기: stale 공대장이 있는 완료 반복방에서 유효 일반 참가자에게 다른 일반
  stale 한 명의 정리 권한을 제한 허용하는 예외. 승인 전 구현하지 않는다.
- 검증: 문서 내용·코드 근거 대조, git diff --check. 문서만 변경해 Flutter/CI를 반복하지 않았다.
  문서를 동일 브랜치에 커밋·push하며 dev/main 통합·배포 없이 브랜치를 유지한다.

# 2026-10-01 DE2-E3 최대 후임 탐색 계측·분담 후보 미채택

- fix/roster-reauth-isolation에서 bc82548 진단, 995e3f8 분담 실험을 커밋·push했다.
  origin/dev 68f0508 유지 확인. dev/main 통합·운영 배포 없음.
- 새로 가능해진 제품 흐름 없음. 기존 후보 CI 36828924578은 앞순번 0–4 통과 이후 실패했고,
  분담 후보 CI 36829347691도 0–5 통과/6 반환 미완료·평가 한도 및 계정 get 오류로 실패했다.
  정확한 접근 횟수는 미확정이며 분담 후보는 미채택이다. 상세 근거·해시는 설계 §17.
- 보존 확인: 두 실패에서 모집·전체 state·member·listing·event·그룹 snapshot 불변.
  기존 E2 생성기와 운영 소스는 변경하지 않았다. 기존 39건을 새 후보 통과로 전용하지 않는다.
- 검토 중 대상 member 누락 시 분담 검사 생략 가능성과 잔존 명령 마커의 일반 권한 변경 차단
  위험도 기록했다. 해당 추가 경계는 코드 검토 결과이며 아직 실행 재현하지 않았다.
- 검증: JS 문법/생성 hook, 단일 최대 proof 각 1회, 전후 coverage 대조, git diff --check.
  Flutter 미실행, 기존 전체 테스트 22 실패/analyze 51건 보존. 사용자 초기화 변경 유지.
- 미확인: 최대 승계 정상화·다른 actor/후임·실제 동시성·제품 인증/UI 연결·실기기·마지막 1인.
- 다음 DE2-E4는 소유권 원장/식별자 계약 조사·비용 재설계다. 같은 분담 조정을 반복하지 않는다.
  문서도 동일 작업 브랜치에 커밋·push하여 복구 지점을 남기고 브랜치를 유지한다.

# 2026-10-01 DE2-E2 정상 첫 후임 승계 통과·최대 탐색 차단 분리

- fix/roster-reauth-isolation 유지. ff89505 계측, 1e28bf8 최소 보정 커밋/push.
  원격 dev 68f0508을 확인했고 dev/main 반영·운영 배포는 하지 않았다.
- 원인 근거: CI 36827641598에서 fixture 이후 단일 거래 coverage를 수집했다.
  모집 소유권/순서/구성/listing 대조 true 이후 마지막 event 대조 반환이 없어 누적 비용을 좁혔다.
  동일 actor/후임 소유권 중복 검사와 후임 뒤 슬롯 평가를 줄였고 권한/유효성 조건은 유지했다.
- 새로 확인: CI 36827919490에서 정상 첫 후임 승계·승인 권한/listing 갱신·동일 요청 재시도·
  남은 7명의 주차 전환 성공. 신규 위조/부분 쓰기 원자 거절 12건도 통과했다.
- 보존 확인: 기존 26건 회귀 유지, 완료 state/event·그룹 관계 보존. 최종 40건 중 39건 통과.
- 남은 실패: 이전 공대장과 앞순번 6명이 stale이고 마지막 슬롯만 유효한 8인 승계는 평가 한도
  오류로 실패했다. 실패 전후 snapshot은 동일하다. 문서 접근 한도/최초 소진 지점은 미확정이다.
- 미확인: 최대 탐색 정상화·실제 동시성·다른 actor/후임·제품 인증/UI 연결·실기기·마지막 1인.
  Flutter 검사 미실행, 기존 22 실패/analyze 51건 유지. 사용자 초기화 설정과 운영 소스는 보존했다.
- 다음 DE2-E3는 복수 stale 앞순번의 검증 비용 설계. 상세 및 해시는 설계 §16.3.
  문서도 같은 브랜치에 커밋/push하고 브랜치를 유지한다.

# 2026-10-01 DE2-E 공대장 승계 설계·최초 proof 평가 한도 차단

- fix/roster-reauth-isolation 유지, 89ffd8d 설계/demo 도구 커밋·push. 원격 dev는 68f0508로 확인했다.
- 조사/설계: 기존 Router→Adapter→remove Repository는 첫 잔여 슬롯을 후임으로 지정한다.
  소유권 정리에는 유효한 첫 후임이 필요하며, stale 공대장이 있으면 일반 stale 선행 정리가
  권한 때문에 불가능할 수 있다. unknown을 건너뛰지 않는 별도 승계 명령을 설계 §16에 기록했다.
- 새 흐름 검증: CI 36748905075에서 첫 정상 8인 승계가 PERMISSION_DENIED/1,000식 평가 한도
  오류로 실패했다. 신규 승계 성공 없음. 최대 탐색과 신규 위조 거절은 실행 전 중단됐다.
- 보존 확인: 같은 후보에서 기존 DE2-D 26건 전부 통과. 일반 참가자 정리·이력 보존·재시도·
  주차 전환·활성방 탈퇴/추방 및 원자 거절은 유지됐다. D 생성 해시 동일성도 확인했다.
- 검증: JS 문법, 후보 생성 hook/해시, demo CI 1회, artifact 원문/results 대조, git diff --check.
  최초 원인 조건은 미확정이다. 문서 접근 한도나 최대 탐색 실패로 과대 해석하지 않는다.
- 다음 DE2-E2: 단일 정상 승계의 coverage/쓰기 경계로 최초 실패를 분리하고 최소 보정한다.
  동일 명령 반복이나 보호 조건 삭제 없이 결과를 문서에 보존했다. dev/main 반영·배포 없음.
  결과 문서도 같은 작업 브랜치에 커밋·push하며 브랜치를 유지한다.

# 2026-09-30 DE2-D 완료 반복방 일반 참가자 정리 proof 통과

- fix/roster-reauth-isolation 유지. 8c284e1 및 보강 9dd6d2b 커밋/push.
  CI 36724586757(22건), 최종 36725053530(26건) 모두 success. 변경 후에만 재검증했다.
- 새로 확인: 8인 완료 반복방에서 유효 공대장/기존 본인이 stale 일반 참가자를 제한 정리한다.
  A→B→A도 구분하며 완료 state/event, 교체·부재 state를 보존한다. 동일 요청 재시도 무변경,
  요청 불일치 거절과 남은 7명의 다음 주 전환까지 demo에서 확인했다.
- 보존 확인: 기존 활성 그룹방 탈퇴·추방 2건, 기존 완료 이력·다른 참가자 state·그룹 관계 유지.
  권한/소유권 unknown·낡은 요청·부분 쓰기·변조의 원자 거절 19건. 전체 cutover 통과는 주장하지 않는다.
- 미확인: stale 공대장/마지막 1인, 실제 동시 실행·응답 유실·인증/제품 연결·실기기.
  인증 상태는 admin 주입이며 기존 소유권 문서 write 신뢰 한계가 남는다.
- 다음 DE2-E는 stale 공대장 정리·승계. 여러 stale 선행 정리와 호출 권한의 관계부터 조사한다.
  문서도 같은 브랜치에 커밋/push한다. dev/main 반영·배포 없으며 브랜치를 유지한다.

# 2026-09-30 DE2-C 누락 state·legacy 소유권 proof 통과

- 새로 확인: 정상 8인 마지막 state create+기존 7개 update 전환, 전체 완료,
  차수 필드 없는 legacy 0 혼합 전환이 계정/Character/슬롯/state 대조와 함께 통과했다.
- 보존/거절: 소유자 변경·A→B→A·필수 문서 부재·손상/불일치 차수·참가 Snapshot 누락·
  슬롯 동시 위조·state 차수 위조/감소/삭제 등 16건의 모집/state/listing/event 원자 보존.
  B7 공유 함수 추출의 해시 동일성을 확인했다. 해당 후보 전체 cutover 통과를 주장하지 않는다.
- 미확인: 실제 인증 차수 전이·동시 경쟁·전체 state 누락·완료방 정리·제품 연결·실기기.
  정상 UI를 추가 실행하지 않았고 사용자 실기기 테스트 요청 단계도 아니다.
- 검증: JS 문법, 문자열 hook 확인, B7 해시 대조, demo CI 1회, git diff --check.
  로컬 CRLF hook 실패는 정규화 비교로 확인했다. GitHub 로그 읽기 502는 CI 실패와 구분한다.
  Flutter 전체 검사는 미실행, 기존 22 실패/analyze 51건 유지. 배포·dev/main 통합 없음.
- 상세와 후보 해시는 설계 §14. 결과 문서를 같은 브랜치에 커밋/push하고 다음 DE2-D로 인계한다.

# 2026-09-30 DE2-B7 target 명령 판별 분리 후보 통과

- 새로 확인한 demo 흐름: 정상 8인 그룹 주차 전환·전체 완료가 단독/소유권 결합 모두 성공.
  소유권 결합의 stale 및 A→B→A 전환/완료는 모집/state/listing/event 불변으로 거절됐다.
- 보존: 단독 후보의 기존 cutover 전체(전환 후 추방·재가입·Character 변경·해산), 전환 위조
  9종/완료 위조 4종 원자 거절, 제한 legacy 전환. 후보 원문·coverage·해시는 설계 §13에 기록했다.
- 기존 cutover에 미완료 종료 사례가 없음을 확인하고 포함됐다는 초기 안내/설계를 정정했다.
  후보 변경 없이 5bb02c2 / CI 36706232887에서 해당 경계만 추가 실행: 정상 8인 미완료 종료의
  state 보존·listing 삭제/count 감소/event 생성, nonempty targets 원자 거절 모두 통과.
- 미확인: 운영 이식·실기기·누락 state 소유권 검사·legacy 이행·인증/실제 동시 경쟁·완료 반복방 정리.
  소유권 결합 전체 cutover 통과로 확대하지 않는다. B7 demo 채택이 DE 전체 구현 완료는 아니다.
- 중단 뒤 추가 CI success를 확인하고 결과 문서를 같은 브랜치에 커밋/push한다. 다음 DE2-C는
  누락 state/legacy 소유권 판별의 설계·demo proof이며 개발 브랜치를 계속 유지한다.

# 2026-09-30 DE2-B6 Rules coverage 자료 확보

- fix/roster-reauth-isolation 고정. 0ed6c26 측정 도구·설계 커밋/push 후 demo CI
  [36704079227](https://github.com/heo0328/LostParty_flutter/actions/runs/36704079227) 1회 success.
  성공은 측정 완료이며 원본 8인 전환은 계속 expression-limit, 직접 분기는 allowed다.
- 공식 coverage JSON을 seed 이후/거래 직후로 구분하고 원문·해시와 artifact(30일)를 보관했다.
  판독 스크립트로 원문 일치·해시·위치 중복·선택 반환값의 단조 증가를 검증했다.
  핵심 결과·재현 명령·자료 한계는 설계 §12에 기록했다. 정확한 비용/초과 식은 미확정이다.
- 새 앱 흐름 없음. demo 직접 분기의 8state/주차/listing revision, 원본 거절 시 모집/state/listing
  불변을 확인했다. 이번 snapshot에는 event가 없고 완료/추방은 재검증하지 않았다.
  B4 직접 분기의 기존 회귀는 그대로 미해결이며 실기기·소유권/legacy 구현도 미완료다.
- 검증: Node 문법, git diff --check, demo 측정 CI 및 확보한 artifact의 오프라인 판독.
  Flutter 전체 test/analyze는 실행하지 않았다. 기존 22건 실패/analyze 51건 기준은 유지한다.
- 측정 결과와 판독 도구도 같은 원격 브랜치에 커밋/push한다. dev/main 미병합·운영 배포 없음.
  사용자 초기화 파일 변경 보존. 다음은 DE2-B7 target 반복 명령 판별 축소 설계·단일 proof다.

# 2026-09-30 DE2-B5 명령 선택 설계·recurrence 순서 후보 검증

- 전용 브랜치 고정. Router/Adapter/Write Plan과 모집 validator를 대조해 설계 §11에 명령별
  경로·marker 소진/보존·missing/null 경계를 기록했다. marker만으로 전체 명령을 분류하지 않는다.
- 5921dfb / CI 36700305266 failure. recurrence의 marker 5종 보존·비방장/추가 필드 거절,
  기존 cutover 전체 회귀와 전환 후 추방은 통과. 단독/ownership 결합 모두 8인 전환 한도 실패.
- 새 앱 흐름 없음. 보존 확인은 위 demo 범위. 정상 전환 실패로 이후 보안·소유권 사례와
  별도 8인 그룹 전체 완료는 미실행이며 실기기도 미실행. 전체 기능 완료로 판정하지 않는다.
- 검증: Node 문법, git diff --check, demo CI 1회. 동일 후보 재실행·Flutter 전체 검사 없음.
- 설계·실험 결과를 같은 브랜치에 커밋/push한다. 사용자 초기화 파일 변경 보존,
  dev/main 미병합·운영 배포 없음. 다음 DE2-B6는 평가 자료 확보; 연쇄 미세 변경은 중단한다.

# 2026-09-30 DE2-B4 보안·회귀 proof — 완료/추방 회귀로 후보 채택 불가

- 새로 확인한 demo 흐름: 직접 분기의 정상 8인 그룹 전환, 역할/Character/target 위조·state 누락·
  비방장 거절과 모집/state/listing/event 원자 보존. ownership 결합의 정상 전환 및 stale/A→B→A 거절.
- 회귀 발견: 후보의 정상 8인 그룹 전체 완료와 마커 소진 후 추방이 1,000식 실패.
  원본은 같은 완료와 기존 cutover 전체 회귀를 통과했다. 원본 통과를 후보 통과로 확대하지 않는다.
- 보존 확인한 기존 흐름은 원본의 완료·추방·재가입·해산·Character 변경·그룹 목록 계약이다.
  후보에서는 전체 회귀가 추방에서 중단됐으므로 이후 항목은 미검증이다.
- 정상 complete 실패 상태의 소유권 거절 출력은 보안 근거에서 제외했다. 후속 도구는
  명령별 정상 통과를 선행 조건으로 고정했다. 원본 대조 외 같은 후보 반복 실행은 하지 않았다.
- 결과: DE2-B4 검증 수행 완료, 수용 게이트 실패. 다음 DE2-B5는 명령 선택 구조 설계부터 진행.
  상세 설계 §10. 체크포인트와 문서 마감은 같은 브랜치 커밋·push, dev/main 미반영·브랜치 유지.

# 2026-09-30 DE2-B3 원자 거래 진단 완료 · 직접 분기 최소 후보 확보

- fix/roster-reauth-isolation 고정. ddd351f/CI 36610449568에서 모집 Aggregate 경계로 실패를 좁혔다.
- 0459649/CI 36697760555에서 전체 lifecycle/targets 제외/targets 전체/첫·마지막 target/대조군 모두 허용.
  임의 조건 생략의 진단 성공과 전체 validator를 유지한 직접 분기의 성공을 구분했다.
- 80d05e5/CI 36698068865의 동일 실행에서 원본 expression-limit, 전체 직접 분기 allowed를 확인.
  command 분기 평가 경로가 수정 지점이다. 정확한 함수별 비용 측정·보안 회귀 완료는 아니다.
- 새로 확인한 흐름: demo에서 실제 8인 그룹 advanceCycle 원자 쓰기 성공, 모집 revision/주차,
  state 8개 active/주차, listing sourceRevision 일치. 거절 거래 데이터 전체 불변 확인.

# 2026-09-30 DE2-B2 개별 predicate 진단 완료 · 원자 거래 실패 유지

- fix/roster-reauth-isolation 고정. 099a4ed와 demo 진단 CI 36609173357로 11개 개별 조건 true 확인.
- actor/shape/state/incomplete/targets/groupCount/aggregate 전체/commandIncludes/마지막 slot/state update/event를 분리했다.
  시간·필수 필드 불일치의 근거는 발견하지 못했다. 실제 8인 원자 거래 성공으로 확대하지 않는다.
- 다음 DE2-B3: 동일 원자 write set에서 Aggregate/state/event/listing 누적 검증 경계를 분리.
  기존 조건을 근거 없이 제거하거나 반복 미세 최적화하지 않는다. 상세 설계 §8.

# 2026-09-30 DE2-B 비용 후보 비교 — 주차 전환 미해결

- tools proof의 실제 advance 쓰기를 set(merge:true)와 runtime 필드로 정렬하고 역할/Character/
  target 위조·쓰기 누락, 그룹 listing, 8인 해산 사례를 추가했다.
- 8944714/CI 36606500265의 직접 target 맵 비교, af45781/CI 36606825983의 슬롯 조회 분리,
  a0795c5/CI 36607243281의 명령 조기 분기 모두 정상 advanceCycle 실패를 유지했다.
- 후보의 8인 complete와 stale/A→B→A 거절, 그룹 complete/listing, 8인 해산, 신규 소유자
  별도 방 생성, 기존 제한 정리/교체 state 보호는 통과했다. 정상 advance 실패 중 위조 거절은
  단독 보안 근거로 인정하지 않는다. 후보는 채택하지 않았고 전체 결과는 failure다.
- 새 앱 흐름: 없음. 보존 확인: 위 demo 범위만. 실기기/그룹 주차 전환/소유권 기능은 미완료.
- 검증: node --check, git diff --check, demo CI 세 차례. 전체 Flutter/운영 배포 없음.
- 다음 DE2-B2는 개별 validator의 첫 실패를 진단한다. 같은 helper의 미세 수정이나 조건 삭제로
  녹색을 만들지 않는다. 상세 근거와 미확인 범위는 설계 §7에 기록했다.

# 2026-09-29 DE2 최소 서버 proof — 부분 통과·주차 전환 경계 발견

- fix/roster-reauth-isolation 유지. 테스트 checkpoint 570108c까지 원격 push. dev/main 병합 없음.
- tools/roster_ownership_rules_proof.mjs와 기존 fixture의 명시적 export/직접 실행 guard,
  선택형 ownership-proof CI를 추가했다. 기존 테스트 기본값은 유지한다.
- 최종 CI 36581670667은 전체 failure. baseline 정상 8인 complete와 현재 소유권 변경 후에도
  오래된 완료가 허용되는 상태를 재현했다. Aggregate 일괄 소유권 후보는 한도 실패로 채택하지 않았다.
- 단건 state 소유권 후보는 정상 8인 complete와 구소유자/A→B→A 거절·원자 보존을 통과했다.
  새 Player의 같은 Character 별도 모집 생성은 과거 방/state를 변경하지 않고 성공했다.
  기존 공대장의 stale 일반 멤버 정리, private read/delete 거절, 다른 방 state 오삭제 거절도 확인했다.
- 기존 completed 반복방에는 기존 제거 명령이 거절되므로 별도 정리 명령이 필요하다.
- baseline/후보 모두 8인 advanceCycle은 1,000식 한도에서 실패했다. 기존 실기기 통과 범위를
  부정하거나 모든 반복방의 장애로 확대하지 않으며, 다음 DE2-B에서 해당 최대치 경계를 조사한다.
- 초기 두 실패는 difficultyId fixture 누락과 테스트 callback 반환 누락으로 보정했다.
  전체 시도·실패 근거와 미확인 항목은 DE 설계 §6에 기록했다.
- 새 앱 흐름: 구현 전. 보존 확인: demo에서 기존 경계의 일부 확인, 운영 무변경.
  미확인: group listing 포함, 누락 state/legacy, 인증/신청/가입 통합, 실제 경쟁, 실기기.

# 2026-09-29 DE1 코드 조사·계약 구체화

- 새 Player의 raidState 경로는 분리되어 과거 state가 모든 신규 가입을 막는다는 가설은
  입증하지 못했다. 기존 슬롯 잔존, lifecycle 현재 소유권 미조회, A→B→A 차수 구분 부재,
  completed 반복방에 기존 removal을 사용할 수 없는 조건을 코드로 확인했다.
- 설계 §5에 경로별 검증 시나리오, legacy 0/신규 1 차수, 단건 정리 권한, 완료 기록 보존,
  동시성·전환 순서와 DE2 최소 서버 proof를 기록했다. 운영 장애의 실제 재현 결과로 확대하지 않는다.
- 검증: 내용 대조와 git diff --check. Flutter/Emulator는 이번 문서 조사에서 실행하지 않았다.
- 다음: 최대 8인 lifecycle 비용, private state 보호 정리, completed 반복방과 신규 이용 재현 proof.
  비용·원자성은 proof 전까지 검증 완료로 판정하지 않는다. dev/main 중간 병합 없음.

# 2026-09-29 DE 원정대 재인증 격리 설계와 전용 브랜치 운영

- 사용자는 기존 사용자 복구·그룹/이력 승계보다 새 사용자 인증 후 정상 이용을 선택했다.
  이전 무효 신청·참가는 별도 제한 정리하며 다른 원정대·정상 그룹·과거 이력은 보존한다.
- 설계 브랜치 docs/roster-reauth-design에서 문서만 dev에 반영한 뒤 fix/roster-reauth-isolation에
  진입한다. 개발·자동/실기기·회귀·문서 종료까지 해당 브랜치 고정, 중간 통합 금지를 사용자 승인으로 명시했다.
- 기존 Google 복구 브랜치는 별도 보존한다. 기존 검사 22건 실패/analyze 51건도 미해결 기준으로 보존한다.
- Git 반영 결과는 문서 커밋과 dev 원격 일치, 최종 개발 브랜치 checkout으로 확인한다. main에는 반영하지 않는다.

# 2026-09-29 전체 검사 결과 고지 후 main 통합 명시 승인

- dev는 a43e6f0까지 반영됐다. 사용자는 전체 테스트 22건 실패·정적 분석 51건과
  미분류 상태를 안내받은 뒤에도 충분한 기능 검증을 근거로 현재 dev의 main 병합을 승인했다.
- 이번 통합에 한해 앞선 main 보류를 해제한다. 실패를 통과로 변경하지 않으며 테스트
  노후화·환경 문제·제품 회귀 분류는 후속 작업으로 남긴다. 이후 작업의 포괄 예외가 아니다.
- 원격 main은 dev의 조상으로 충돌 없는 fast-forward 통합 대상이다. 병합 과정에서 코드
  변경이 없으므로 기존 서버 CI·실기기 근거를 재사용하고 동일 검사를 반복하지 않는다.

# 2026-09-29 사용자 검증 범위 마감 및 dev·main 통합 승인

- 사용자는 BUG-017 만석 사례가 현재 실기기 테스트 불가하고 크리티컬하지 않으므로
  낮은 우선순위 참고로 유지하도록 결정했다. 자동 검증은 통과했으며 통합 차단 조건에서 제외한다.
- 사용자는 반복방 처리와 고아 데이터 삭제·복구 기능도 정상 작동했다고 확인했다.
  시험한 범위는 정상화로 기록하고 새 버그가 발생하면 해당 사례만 데이터·로그로 재조사한다.
  모든 조합 검증이나 만석 실기기 완료를 주장하지 않는다.
- dev는 승인된 개발 통합으로 반영하되 main은 AGENTS.md §3.3의 안정 브랜치 기준에 따라
  전체 실패 원인 분류·해결 전 보류한다. 만석 실기기 참고 항목이 통합 차단 원인은 아니다.
  다음 작업은 전체 검사 실패 분류이며 DE 설계는 그 이후다.

# 2026-09-29 BUG-017 사용자 Rules 게시 및 부분 실기기 통과

- 미확인 실기기: 8인 만석에서 단일 교환으로 정상 구성이 가능할 때 자동 자리 교환 없이
  제자리에서 Character만 변경되는 흐름. 연계된 파란 안내 표시·공대장 교환 후 해제도
  이번 보고로 완료 처리하지 않는다. 해당 저장 처리는 기존 자동 검증 통과 근거를 유지한다.
- 보존 확인: 앞서 확인한 F6-I 및 그룹방 탈퇴·추방·재가입 통과는 유지한다. 이번 보고를
  모든 명령·직업·역할 조합이나 반복방 재승계·F6-H 전체 재검증으로 확대하지 않는다.
- 운영 게시 상태를 사용자 게시 확인으로 갱신한다. AI 배포는 이전에 실행 전 거절됐으며,
  이후 사용자가 게시했다. AI는 운영 활성 소스·해시를 독립 대조하지 않았다.
  이 보고로 추가 게시 승인이나 재배포가 필요하다고 간주하지 않는다.

# 2026-09-29 BUG-017 배치 복원·전체 서버 검증 완료 — 당시 운영 게시 승인 대기

- 초기 CI `36544333862`의 8인 변경은 1,000식 한도 초과였다. 슬롯별 반복 검사를
  대상 제외 목록의 동등성 비교로 바꾼 `36544797646`에서는 8인 제자리 변경이 통과하고
  빈자리 이동만 한도 초과가 남았다. membership의 두 target 순회를 두 필드 맵 직접
  비교로 바꾸고 타인 target 목록 보존도 강제한 표적 CI `36545074208`은 통과했다.
- 새로 가능해진 흐름(코드·서버 검증): 다른 파티 빈자리로 본인만 이동하는 Character 변경,
  만석에서 교환 가능성을 확인한 제자리 변경, 그룹 listing과 membership의 원자 동기화.
- 보존 확인: 점유/범위 밖 위치·타인 슬롯/target 변조·stale revision·이전 점유 삭제 누락
  거절 및 롤백, 신규 Character의 기존 active/completed 상태 덮어쓰기 거절. 기존 파티·그룹
  가입·승인·자리 이동·탈퇴·추방·재가입·완료·회차·그룹 이전/해산 회귀도 통과했다.
- 미확인 실기기: 실제 후보 선택·자동 이동·다른 디바이스 반영, 만석 파란 안내와 공대장
  조정 후 안내 해제, 변경 이후 정상 명령. 반복방 재승계·F6-H 전체도 별도 미완료다.
- 사용자 초기화 설정 SHA-256 `82AAC07A7E426F9E6B94E31CBCAF9FCEBD44B8C6CE3F4B55EB11B5C76FA257B0`
  보존. 구현·검증 커밋은 `46829e9`, `308002f`, `a4d3181`, `243a6ee`로 목적 브랜치에 push했다.
  현재 `fix/bug-022-party-permissions` 유지, 운영 미게시·실기기 대기·dev 미반영이다.

# 2026-09-29 Rules 게시 후 그룹방 실기기 통과 및 BUG-017 재조사 기록

- 새로 확인한 흐름: 게시 후 그룹방 탈퇴·추방·재가입. 보존 확인 근거: 사용자는 게시 전에도
  해산·완료가 가능했다고 보고했다. 게시 후 전체 해산·완료 재검증으로 확대하지 않는다.
- 미확인 실기기: 완료 반복방의 다음 경계 재승계, 승계 직후 모든 명령, F6-H 전체 흐름.
  이번 통과만으로 반복방 재승계·F6-H 전체를 완료 처리하지 않는다.
- 이번 변경은 문서 4개뿐이다. 내용 대조·git diff --check로 검증하고 Flutter 테스트는
  반복하지 않는다. 초기화 설정의 사용자 변경은 보존했다. 현재 목적 브랜치 유지,
  문서 미커밋·push 없음·dev 미반영, 코드 수정·운영 배포·데이터 변경 없음.

# 2026-09-29 A3 재현 전제 정정 및 전체 Rules 회귀 통과

- 승인형 직접 가입 거절·롤백은 보존하고, directJoin 그룹방의 최초 가입·탈퇴 후 재가입,
  추방 후 최대 8인 재가입을 검증했다. 그룹 신청 승인 fixture도 실제 writer처럼 원본과
  listing을 같은 Transaction에 기록한다. 원본·listing·membership·raidState 결과를 확인한다.
- 새로 확인한 흐름: 정상 그룹 직접 가입/재가입과 그룹 신청 승인. 보존 확인: A2-B 제거
  경계 및 F6-H marker 회귀, 기존 전체 파티/그룹 서버 회귀. 승인형 직접 가입은 계속 거절한다.
- A3의 정상 재가입 한도 결함 판정은 철회한다. 과거 C/C7 실험 실패 자체를 소급해 성공으로
  바꾸지는 않는다. 거절 요청의 1,000식 진단은 정상 요청 성공과 구분한다.

# 2026-09-29 A2-B 참가자 제거 listing 동기화 구현 및 서버 검증

- 변경: 기존 제거 Write Plan의 8개 구성 값과 sourceRevision/updatedAt을 동일 listing
  update에 전달하고 방장 승계 시 leader Snapshot 3개도 전달한다. 추가 문서 조회·쓰기,
  비동기 복구·스키마 변경 없이 기존 Transaction 범위를 유지했다.
- 새로 가능해진 흐름(서버 검증): 제거된 Player·slot·target 및 역할 count를 목록에서 함께
  제거하며 만석→빈자리와 방장 승계도 동기화한다. stale listing도 제거 명령에서 교정한다.
- 보존 확인: CI에서 공개방 승인·추방·직접 재가입, 자리 변경, 해산, lifecycle marker 소비,
  그룹 추방·본인 탈퇴와 구버전 listing 요청을 확인했다. 마지막 1인의 일반 탈퇴 거절은
  기존 Write Plan 테스트로 유지한다.
- 검증: 표적 Flutter 테스트 11건 PASS, 변경 Dart 4파일 analyze 0 issues, format,
  node --check 및 git diff --check 통과. 첫 계약 테스트의 실제 inline 참조와 다른 문자열
  기대를 수정한 뒤 통과했으며 제품 경로를 테스트 기대에 맞춰 재작성하지 않았다.
- [CI 36461139608](https://github.com/heo0328/LostParty_flutter/actions/runs/36461139608),
  대상 `3440e6b`: 8인 제거·stale 교정, 구성/leader/회차/설정 위조 거절과 원자 롤백,
  listing 누락 거절, 구버전 호환, 방장 승계, 같은 revision 중복 제거 단 한 건 커밋 PASS.
  listing 단독 위조 거절에는 1,000식 한도 오류도 관찰되어 이 사례는 거절·롤백 근거로만
  사용한다. 정상 제거들은 성공했다. 전체 CI는 기존 A3 그룹방 직접 재가입 1,000식에서
  실패했으며 뒤의 회귀와 별도 그룹 탈퇴/해산 step은 실행되지 않았다.
- Git: 기존 F6-I는 `5a14e67`, A2-B는 `3440e6b`로 구분 커밋·push했다. 현재 브랜치
  `fix/bug-022-party-permissions` 유지, dev 미반영. 다음 A3 해결·전체 검증 후 F6-H 게시와
  통합을 판단한다. 이번 결과를 BUG-022 전체 완료로 판정하지 않는다.

# 2026-09-29 해결·잔여 버그 문서 최신화

- 사용자 요청으로 BUG_REPORTS에 최신 판정 요약을 추가하고 BUG-022의 오래된 상태 표기를
  갱신했다. F6-I 그룹 반복방 목록 미노출의 실기기 해결과 A2-B/A3 미해결, F6-H 검증·게시
  보류, DE UX 결정 선행을 분리했다. NEXT_WORK의 다음 단일 작업은 A2-B로 유지한다.
- 이번 신청·가입 성공을 탈퇴 후 직접 재가입 성공으로 확대하지 않았고, 완료한 반복방의
  다음 경계 재승계 등 미확인 항목을 신규 확정 결함과 구분했다. 과거 실패 이력은 보존한다.

# 2026-09-29 F6-I 실기기 확인 및 운영 경계 복원

- 사용자 실기기 결과: 반복방이 모집 탭에 표시됐고 다른 디바이스에서 신청하여 가입까지
  성공했다. 자리 변경·추방이 정상 동작했다. 주간 전체 완료 후 방의 두 캐릭터가 체크되고
  다음 주 대기 상태가 되는 것을 확인했다. F6-I의 제보된 목록 미노출 수정은 실기기까지
  확인 완료로 판정한다.
- 새로 가능해진 흐름: 주차 승계 후 그룹 반복방 목록 재노출과 신청·가입 진입.
- 보존 확인: 자리 변경·추방·전체 완료·참가 캐릭터 완료 체크·다음 주 대기.
- 공용 RaidCycleSchedule의 테스트 화요일 01:20을 운영 수요일 06:00 KST로 복원했다.
  설치된 테스트 앱과 기존 방의 저장된 경계는 소급 변경하지 않는다.

# 2026-09-29 F6-I 테스트 경계 화요일 01:20 변경

- 사용자 지정으로 임시 월요일 21:00을 KST 화요일 01:20으로 대체했다.
- 공용 RaidCycleSchedule의 요일·시·분만 변경했다. 이전 방의 저장된 경계는 수정하지 않는다.
  두 디바이스에 새 빌드를 설치한 후 9/29 01:20 전에 새 그룹 반복방을 생성해야 한다.
- 검증: 실제 공용 정책으로 경계 1초 전 키 2026-09-22, 경계 시각 키 2026-09-29,
  이전 종료/다음 시작 일치 및 다음 종료 10/6 01:20 KST를 확인했다. diff 검사 통과.
- 이전 기록의 10/5 21:00 테스트 예상은 이전 설정 기준이다. 현재 시험은 새 샘플로 수행하며
  운영 수요일 06:00 복원 게이트를 유지한다. 미커밋, dev 통합·push·빌드 설치·배포 없음.

# 2026-09-29 F6-I 승계 후 그룹 listing 동기화 누락 수정

- 보존 확인: 최대 8인 승계 11-write, 만석/모집 중단 보존, 완료 마커 초기화,
  Timestamp 타입, 원본 map 불변, 공개방 무그룹 동작과 기존 완료·해산·1회성 종료,
  stale revision/target 거절, 동일 Transaction 연결을 표적 검증했다.
- 미확인 실기기: 새 빌드의 정상 주차 승계 후 원본/listing 회차 일치, 비참가 그룹원의
  모집 탭 노출, i 표시와 기존 멤버 명령. 이미 전환된 샘플은 자동으로 재승계하지 않는다.
  해당 샘플은 다음 정상 경계(현재 임시 설정에서 2026-10-05 21:00 KST)에 수정 경로로
  동기화되며 지금 즉시 복구되었다고 판정하지 않는다. 운영 수동 수정은 수행하지 않았다.
- Git: fix/bug-022-party-permissions 유지. 기존 진단·월요일 21시 설정 미커밋 변경을
  보존했고 이번 수정도 미커밋이다. dev 통합·push·배포 없음. 실기기 대기 상태이며
  테스트용 경계를 운영 수요일 06:00으로 복원하기 전 통합하지 않는다.

# 2026-09-28 F6-I 재현 샘플용 임시 주차 경계

- 사용자가 기존 문제 방 데이터 삭제를 알려 새 샘플 생성으로 전환했다.
- 사용자 지정에 따라 공용 `RaidCycleSchedule`을 KST 월요일 21:00으로 임시 변경했다.
  새 빌드에서 경계 전에 그룹/공개 반복방을 생성하고 방장 계정으로 승계 로그를 확인한다.

# 2026-09-28 F6-I 그룹 반복방 승계 진단 첫 구간

- 새로 가능해진 흐름: 진행 중 원본 snapshot에서 만료 반복방의 현재 방장 후보와 revision을
  전달한다. 관찰한 모집 ID·목표 회차·revision의 결과를 보존하고 실패 반복 호출을 억제한다.
  후보는 순차 처리하며 revision/목표 회차 변경, 명시적 새로고침·앱 재실행에서 재시도한다.
  디버그 `PartyCycleReconcile`은 gateway 읽기 오류, 명령 실패값과 최종 결과를 구분한다.
- 보존 확인: 현재 회차·경계 필드 누락 방은 새 보정 후보가 아니며 비방장 반복방은 표시를
  유지하되 목록 승계 쓰기를 시도하지 않는다. 공개 반복방은 같은 후보 정책을 쓰고 1회성은
  기존 F6-F 명령을 유지한다. 상세/목록 동시 진입은 실제 gateway 호출 하나를 공유한다.
  서버 소유권·권한·state·event·listing 쓰기와 기존 상세 진입 호출은 변경하지 않았다.
- 미확인 실기기: 문제 그룹방의 첫 실패 종류·단계, 실제 승계와 이후 목록/참가 상태/명령.
  사용자가 디버그 빌드를 실행해 로그를 제공한 뒤 확정 원인만 수정한다. F6-I 전체는 미완료다.
- 후속: lifecycle listing 회차 필드 누락은 승계 후 노출 확인 지점이다. A2-B·A3와 분리하며
  새 조회·전체 Snapshot 복구·운영 수동 정리를 추가하지 않았다.
- Git: `fix/bug-022-party-permissions`의 미커밋 변경으로 유지, dev 통합·push·배포 없음.
  원격 조회는 네트워크 연결 실패로 확인하지 못했다. 기존 로컬 추적 상태는 원격보다 3커밋 앞섰다.

# 2026-09-27 BUG-022 C7 schema v3 격리 proof 폐기

- 기존 Aggregate 항목 보존, 비그룹원·block·타인 Character·주간 Claim·자리/count 위조와 핵심 문서 누락 거절을 포함했다. Actions `36326380626`의 모집 단건 읽기 차단과 `36326546696`의 배열 내부 서버 시각 제약은 proof 하네스 문제로 교정했다.
- 권한·소유권·주간 완료·그룹 접근·원자성 조건이나 실패 회귀를 삭제하지 않았고, 운영 게시·실기기 변경은 없다. 재가입 C는 새 계약의 별도 승인 전까지 미완료·보류다.

# 2026-09-27 F6-G 참가 Character 변경 고아 점유 복구 실기기 확인

- 현재 주차 모집에서 다른 활성 참가가 없는 Character 변경이 `다른 확정 참가와 충돌합니다`로 거절된 원인을, 후보 조회와 최종 Transaction의 `raidState` 수명 판정 불일치로 확정했다.
- 최종 변경 Transaction을 기존 공용 `PartyRaidStateOccupancyInspector` 판정에 맞추고, 종료 모집에 연결된 고아 state는 쓰기 없이 명시적 결과로 반환해 기존 단일 참가 기록 정리 확인창으로 연결했다.
- 점유 정책 8건, 원자 membership Repository 계약 7건과 F6-G Widget 표적 테스트가 통과했고 변경 파일 정적 분석은 0건이었다. 상세 전체 Widget 묶음의 기존 이벤트 읽음 테스트 1건은 로컬 이벤트 조회 0건으로 실패해 별도 상태로 유지했다.

# 2026-09-27 F6-F 운영 게시·기존 문제 방 미완료 종료 확인

- 기존 지평의 성당 3단계 그룹방 `5BCRsQkPRDvje1DrllEM`은 revision `6 → 7`, `status/currentCycleStatus: active → incompleteEnded`, `manualRecruitmentEnabled/hasAvailableSlot: false`, `lastCommandId: incompleteEnd_5BCRsQkPRDvje1DrllEM_6`, `lastCommandType: incompleteEnd`로 전환됐다.
- 방 문서는 삭제·해산되지 않고 `partySlots`, `memberPlayerIds`, 생성 당시 `raidStateTargets`가 그대로 보존됐다. `groupActiveRecruitmentCountAfter`는 과거 모집 Snapshot `5`가 아니라 명령 당시 현재 그룹 기준 결과 `10`으로 기록돼 F6-F와 A1의 결합 경계도 운영에서 작동했다.
- 지난 주차 1회성 문제 방의 진행 중 제외와 서버 미완료 종료는 확인됐다. 반복방 다음 회차 승계, 현재 주차 방 무변경, `partyIncompleteEnded` 이력 노출은 아직 별도 확인 전이므로 F6-F 전체 완료·`dev` 통합은 보류한다.

# 2026-09-26 F6-F 2단계 — 만료 1회성 방 원자 미완료 종료

- 기존 lazy 회차 보정 진입점에서 반복방은 종전 `advanceCycle`을 유지하고, 만료된 1회성 방만 target 없는 `incompleteEnd` 원자 명령으로 분리했다. 현재 주차 방과 기존 완료·해산·추방·자리 변경의 조건은 변경하지 않았다.
- 종료 Transaction은 모집을 `incompleteEnded`로 고정 전이하고 공용 `partyIncompleteEnded` 이벤트를 한 건 생성한다. 그룹방은 현재 그룹 count를 다시 읽어 `N -> N-1`로 갱신하고 listing을 삭제하며, 공개방은 그룹 문서를 쓰지 않는다.
- 참가자 `raidState`는 명령 target, Transaction 읽기와 쓰기에서 모두 제외했다. 생성 당시 `raidStateTargets`와 `partySlots`는 감사 Snapshot으로 보존하므로 누락 state나 이후 모집이 재사용한 state를 삭제·덮어쓰지 않는다.
- 숨겨진 만료 1회성 모집 ID도 화면 reconciliation에 전달해 다음 스트림 갱신·새로고침에서 멱등 재시도한다. 전체 모집/그룹 순회, 스케줄러, Functions와 migration은 추가하지 않았다.

# 2026-09-24 BUG-022 작업 그룹 C Spark 통합 실패·원복

- 모집 update 한 곳에서 참가 권한·그룹 접근·Character 소유·주간 완료와 membership·raidState·event·listing 결합을 검증하고, 동반 문서는 같은 revision의 Projection만 확인하는 C 설계를 구현했다.
- 승인자 권한 검증은 유지하고 동반 Projection 봉투의 중복 조건만 더 줄인 `35998246596`도 같은 공개방 승인 지점에서 실패했다. 권한을 자체 검증하지 않는 application 빠른 분기는 보안 검토에서 제외하고 커밋하지 않았다.

# 2026-09-24 BUG-022 미완료 버그 Spark 수정 설계

- C는 모집 update에서 권한·그룹 자격·Character 소유·주간 완료·구성 정책을 한 번 검증하고 membership·raidState·event·listing은 같은 revision의 직접 Projection 결합만 확인하도록 설계했다. 단독/누락/변조 쓰기 거절과 기존 생성·승인·탈퇴·추방·해산 회귀를 완료 조건으로 둔다.
- E는 GameAccount·Character의 `ownershipRevision`과 application·membership·raidState Snapshot으로 A→B→A 재이전의 stale 상태 재활성화를 막고, 사회적 데이터 자동 승계 없이 제한 정리 명령을 사용한다.

# 2026-09-24 BUG-022 그룹방 재가입 Rules 한계 확정

- 그룹방 탈퇴 후 재가입은 listing/event 제거, 그룹 membership 조회 축소, OR 선별과 membership·raidState target 중복 검증 축소를 각각 적용해도 1,000식 한도를 넘었다. 마지막 두 전체 회귀는 `35992417272`, `35993347464`다.
- 단독 raidState·membership 누락·target 불일치와 배열 순서 위조는 계속 거절됐고, 기존 신규 생성·수동 완료·그룹 승인/코드 가입·공개방 재가입·자리 이동·추방/탈퇴·2/4/8인 해산은 실패 지점 전까지 보존됐다.
- 안전 조건을 더 삭제하거나 원자 쓰기를 분리하지 않는다. 다음 구현은 신뢰 서버 참가 명령 또는 명시적 명령/증명 문서 기반 계약 중 하나를 선택하고 전환·멱등성·구버전·배포 순서를 별도 설계한 뒤 진행한다.

# 2026-09-23 BUG-022 재설치·재인증 후 파티 권한 오류 분석 기록

- 제보 방은 현재 Player가 방장이고 참가 관계도 일치하므로 재설치 이전 Player 데이터 충돌을 직접 원인으로 확정하지 않았다.
- `BUG_REPORTS.md`에 `BUG-022`의 확보 사실·미확정 범위·재현 순서·해결 후보를 기록하고 `NEXT_WORK.md`를 분석 재개 지점으로 갱신했다.

# 2026-09-22 애니메이션 진입 화면·앱 아이콘 적용

- 제공된 941×1672 이미지를 Flutter 진입 화면으로 등록하고 별빛·중앙 글로우·로고 하이라이트를 약 2.2초간 한 번 재생한다. 서비스 초기화와 병렬로 실행하며 초기화가 느리면 마지막 정적 프레임을 유지한 뒤 기존 앱으로 전환한다.
- 고정 디자인 좌표계를 화면의 cover 배율로 중앙 확대해 폴드 접힘·펼침 등 서로 다른 비율에서도 공백 없이 채우도록 조정했다.
- 아이콘 원본 4종을 영문 파일명으로 보관하고 Android 일반·적응형·Android 13 단색 아이콘과 iOS AppIcon 전 슬롯을 생성했다. 재생성용 `tool/generate_app_icons.ps1`을 추가했다.
- 사용자 실기기에서 진입 화면과 앱 아이콘 적용이 정상임을 확인했다. 런처가 적응형 아이콘을 원형으로 마스킹하는 동작도 정상 범위로 판정했다.
- 진입 화면·부트스트랩 Widget 테스트 4건과 변경 Dart 파일 정적 분석, 아이콘 해상도·투명도·XML·iOS 슬롯·영문 파일명 검증, `git diff --check`를 통과했다. 전체 테스트의 기존 무관 경로 16건 실패는 별도 상태로 유지한다.
- `feature/animated-entry-screen`의 기능·문서 커밋을 `dev`에 fast-forward 통합하고 원격 `dev`와 같은 커밋으로 맞췄다.

# 2026-09-16 C* 기능 복구 F1 — 그룹 이전·탈퇴·1인 해산 자동 계약

- 그룹장 이전은 그룹 원본 1건과 이전·신규 그룹장 membership 2건, 일반 탈퇴·1인 해산은 그룹·본인 membership·membership state·relation의 고정 문서만 갱신함을 재확인했다. 파티 인원·연결 모집 수 비례 Transaction으로 되돌리지 않았다.

# 2026-09-16 C* 기능 복구 F0 — 실행 기준·전체 Rules 회귀 진입점 정리


# 2026-09-16 실기기 판정 — 생성·가시성만 확인, 나머지 미해결

- 그 외 보고했던 실패(그룹장 이전, 즉시가입, 신청 승인, 신청 불안정, orphan 방의 해산·공개전환·캐릭터변경·모집삭제, Listen deny 등)는 **실기기에서 아직 고쳐지지 않았다**.
- 로컬 코드·계약 테스트에 올라간 후보 수정은 있으나 실기기 완료로 쓰지 않는다. 미해결 목록·orphan 시나리오는 `NEXT_WORK.md` 「실기기 미해결」을 단일 기준으로 한다.

# 2026-09-15 orphan 그룹 전용방·캐릭터 변경·모집 삭제 수정

- 수정: 그룹→공개는 비멤버 파티장 허용, 모집 삭제→disband, `validAtomicMemberCharacterChange` OR, listing은 멤버일 때만 전체 sync, 그룹 전용방 파티장 탈퇴는 `activeGroupRaidExists`로 차단.

# 2026-09-15 가입·승인·Listen deny 수정

- 승인: 원자 `PartyAtomicApprovalWritePlan`이 `resolutionReason: approved`와 `approvalCount` 미증가로 `validApplicationDecision`과 불일치했다. `approvedByApprover` + `approvalCount+1`로 맞췄다.
- Listen: 상세가 비리더에게도 applications 전체 list·전원 cycles를 구독해 PERMISSION_DENIED가 났다. 신청 목록은 리더만, cycles는 리더·확정 멤버만 구독한다.

# 2026-09-15 그룹장 이전·모집 비가시성 수정

- 그룹장 이전: `validAtomicGroupRecruitmentClose`/`Open`이 `lastRecruitmentId` 검사 전에 `getAfter(...).data`를 호출해 OR 평가 오류가 나고 transfer 분기에 도달하지 못했다. 키·string·`existsAfter` 가드 후 Body로 분리했다. UI는 `groupTransferFailureMessage`로 가입 문구 재사용을 끊었다.
- 모집 비가시성: 원자 생성은 `schemaVersion: 2`인데 공개 목록·내 레이드 현황·listing 필터·공개/현황 매퍼가 `1`만 허용했다. 읽기를 v2로 전환하고 membership·application은 v1을 유지했다. 계약 문서·표적 테스트를 갱신했다.

# 2026-09-15 파티·그룹 생성 permission-denied 진단

- 증상: wipe 후 그룹·모집 생성이 `권한을 확인하지 못했습니다`로 실패, 활동 Character 조절은 성공.
- 앱: 깨진 membership 요약을 빈 상태로 복구, 생성 시 수동 Claim을 먼저 검사, 그룹 카운트 after를 현재+1로 기록, 기본 그룹명 20자 상한을 적용했다.

# 2026-09-15 파티·그룹 명령 재설계 — Rules·Indexes 게시 완료·wipe 경로 문서화


# 2026-09-15 파티·그룹 명령 재설계 — R7 legacy Rules 정리

- C* `allow`에서 떼어낸 legacy validator·`validPlayerEvent` fan-out 등 55개 미사용 함수를 제거했다. `validAtomicStaleRaidStateDelete`는 `stateId` 검증을 추가했다.

# 2026-09-15 파티·그룹 명령 재설계 — C* Rules 게시 실패·R7 착수


# 2026-09-15 파티·그룹 명령 재설계 — C* Router/DI·읽기·구 경로 차단

- 운영 Router에 원자 create/application/join/visibility/command와 membership·cycle 어댑터를 연결했다. `setRecurrence`는 모집 원본만 갱신하고 `purgeStale`은 `raidState`를 정리한다.
- `partyEvents` audience get/list와 sync/read를 전환했고, 구 assignment·slot·cycle 쓰기·파티 Claim·개인 party event create를 닫았다. 수동 Claim과 분쟁 이벤트는 유지한다.

# 2026-09-15 파티·그룹 명령 재설계 — 운영 Rules R6 Aggregate 멤버십 갱신

- 모집 update에 신청 집계·가입·캐릭터·자리·탈퇴·visibility Aggregate OR를 추가하고 구 join/revision/visibility/removal 분기는 유지했다.
- 원자 가입 membership create·탈퇴 delete는 assignment 대신 `raidState`를 보고, membership 경로의 raidState delete와 그룹 `activeRecruitmentCount` open·visibility listing write OR를 열었다.
- 승인자가 대상 `raidState`를 만들 수 있도록 R5 create 조건을 완화했다.

# 2026-09-15 파티·그룹 명령 재설계 — 운영 Rules R5 membership raidState·partyEvents create

- `validAtomicRaidStateCreate`를 추가해 schemaVersion 2 모집의 `raidStateTargets`와 membership·주간 Claim을 검증하는 create OR를 열었다. lifecycle update/delete는 R2를 유지한다.
- `validAtomicMembershipPartyEvent`를 추가해 생성·가입·신청·캐릭터·자리·탈퇴·추방 이벤트 create OR를 lifecycle create와 병행했다.

# 2026-09-15 파티·그룹 명령 재설계 — 운영 Rules R4 schemaVersion 2 모집 생성

- `validAtomicInitialRecruitment`를 추가해 schemaVersion 2 모집 생성 OR를 `validInitialRecruitment`와 병행했다. v1 생성·slot·assignment 검증은 유지한다.
- 원자 생성은 `partySlots`·`raidStateTargets`·집계 초기값·명령 봉투 null과 leader membership·`raidState` `getAfter`를 검증하고 slot·assignment 경로는 쓰지 않는다.

# 2026-09-15 파티·그룹 명령 재설계 — 운영 Rules R3 그룹 activeRecruitmentCount

- `validInitialGroup`에 `activeRecruitmentCount` 키를 허용하고 생성 시 0을 강제해 Write Plan과 맞췄다.
- `validAtomicGroupRecruitmentClose`에 활성 수 감소·`lastRecruitmentId`·revision·updatedAt만 바꾸는 affectedKeys와 양의 정수 검사를 보강했다.

# 2026-09-15 파티·그룹 명령 재설계 — 운영 Rules R2 lifecycle OR

- 구 `validCycleCompletion`·`validRecruitmentDisband`·assignment·Claim·개인 event 경로는 유지했다. raidState create는 계속 닫아 R5에 남긴다.
- `groupId`는 빈 문자열이 아니라 문자열 존재 여부로 판정해 운영 문서의 null/생략과 맞췄다.

# 2026-09-15 파티·그룹 명령 재설계 — 운영 Rules 복구 슬라이스 시작

- R1로 `players/.../raidStates`와 `partyEvents` match 스캐폴드를 추가하고 쓰기는 닫아 두었다. 구 assignment·Claim·개인 event 경로는 유지한다.

# 2026-09-15 파티·그룹 명령 재설계 — 공개↔그룹 전환과 그룹 해산 게이트

- 공개↔그룹 전환 비연결 원자 Repository를 추가했다. `nonGroupMemberCount`·`pendingNonGroupApplicantCount`와 그룹 `activeRecruitmentCount`만으로 전환을 판정·갱신하며 멤버·신청자 전원 그룹 membership 순회를 쓰지 않는다.
- 그룹 생성 Write Plan에 `activeRecruitmentCount: 0`을 넣고, 그룹 해산은 `raidListings.limit(20)` 순회 대신 `GroupActiveRecruitmentWritePlan.validateDisband`를 사용한다.
- 계약 테스트로 원자 visibility Router 미연결과 해산 게이트·생성 초기값을 고정했다. 표적 테스트와 변경 파일 정적 분석이 통과했다.

# 2026-09-15 파티·그룹 명령 재설계 — 생성·신청·가입·승인·캐릭터·자리 원자 Repository

- 신청 거절 Write Plan을 보완해 pending·비그룹 신청 집계를 줄이고 공용 `applicationRejected` 이벤트 한 건만 남긴다. 재신청은 기존 apply 계획으로 pending을 다시 올린다.
- 생성·가입은 `raidState`로 점유·주간 완료를 판정하고 assignment·Claim·slots·개인 event·전원 membership 재조회를 쓰지 않는다. 그룹 생성 시 `activeRecruitmentCount`를 증가시킨다.
- 캐릭터 변경은 이전 `raidState` 삭제와 신규 상태 생성, 자리 이동은 대상 membership 1~2건만 갱신한다.
- 계약 테스트로 운영 Router 미연결과 구 경로 금지를 고정했다. 표적 Write Plan·계약 테스트 16건과 변경 파일 정적 분석이 통과했다.

# 2026-09-14 파티·그룹 명령 재설계 — 권장안 확정과 접근량 감사

- 계정·게임 계정·캐릭터 인증 자료는 보존하고, 새 스키마 전환 때 기존 파티·그룹·신청·회차·이벤트 테스트 자료를 초기화하며 구·신 스키마 호환 계층은 만들지 않기로 확정했다.
- 해산 pending 신청자는 서버 이벤트 fan-out 없이 모집 원본 종료로 자동 숨기고 로컬에서 한 번 안내한다. 종료 하위 문서는 첫 출시에서 자동 삭제하지 않고 활성 판정에서 제외한다.
- 완료·취소·주차 전환·해산은 온라인 전용 원자 명령으로 고정하고 오프라인 큐·단계형 후처리를 사용하지 않는다.
- 코드 감사 결과 전체 완료·취소는 고정 3 + `3N`, 주차 전환은 고정 3 + `2N`, 활성 해산은 member/application/assignment/slot과 event가 `N+A`로 증가함을 기록했다. 공개→그룹 전환과 그룹 해산의 20건 절단 순회도 Aggregate로 교체한다.
- 설계 커밋 `b595b68`을 로컬 `dev`에 fast-forward 통합했고 사용자 승인 후 `origin/dev`도 같은 시점으로 푸시했다.
- 생성·가입의 기존 Write Plan을 버리지 않고 확장하는 비연결 원자 계획을 추가했다. 기존 membership의 보석·아크그리드 통합 Snapshot은 그대로 보존하고 assignment 대신 최초 revision 1의 `raidState`, 최대 8칸 `partySlots`·전체 `raidStateTargets`와 공용 이벤트 한 건을 만든다. 가입 시 현재 슬롯과 파티 구성 정책을 다시 검증하며 그룹원 여부에 따라 `nonGroupMemberCount`만 증감한다. 모집 revision과 개별 `raidState` revision을 분리해 가입 때 기존 전원 상태를 다시 쓰지 않도록 했고 lifecycle 상태 갱신은 각 상태의 `FieldValue.increment(1)`을 사용한다. 운영 생성·가입 Repository와 Router/DI는 아직 변경하지 않았다.
- 신청·재신청·철회는 membership·`raidState` 없이 모집의 pending 집계와 신청 문서·공용 이벤트만 변경하고, 승인이 확정될 때 가입 계획을 결합하도록 비연결 Write Plan을 추가했다. 그룹 연결 모집은 신청자의 현재 그룹 자격에 따라 `pendingNonGroupApplicantCount`를 함께 증감한다.

# 2026-09-14 release/1.0.0 후보 폐기와 파티·그룹 명령 재설계 전환

- 사용자 결정으로 기존 `release/1.0.0` 후보를 폐기했다. 브랜치는 삭제하지 않고 이력·비교용으로 보존하며 출시·`main` 병합 기준에서 제외한다.
- 코드 감사에서 전체 완료·취소·주차 전환·해산, 즉시 가입, Character 변경, 탈퇴·추방, 자리 이동·교환과 일부 그룹 연결 명령이 인원수에 따라 membership·Claim·assignment·slot·개인 event 읽기·쓰기를 늘리는 구조임을 확인했다.
- 현재 최대 8인 범위의 완료·취소·주차 전환·해산은 통합 `raidState`를 포함한 한 번의 제한 원자 명령으로 확정한다. 종료된 membership·slot·application은 부모 모집 상태로 기능에서 제외하고, 지연 정리는 정확성·사용자 행동과 분리한다. 앱 종료 또는 응답 유실 뒤에는 `status`·`revision`·`lastCommandId` 재조회로 결과를 자동 판정한다.
- 장기 기준은 `legacy/firebase/docs/architecture/PARTY_GROUP_COMMAND_SCALABILITY_REDESIGN.md`, 첫 단계는 `NEXT_WORK.md`에 기록했다.
- 사용자 결정으로 현재 기능 상태와 알려진 결함 기록을 `dev`의 새 재작업 기준점으로 올린다. 이는 릴리즈 가능 판정이 아니며, `main`과 폐기된 `release/1.0.0`은 구조개선·회귀 검증 완료 전 유지한다.

# 2026-09-13 릴리즈 인증 UX·파티 통합 오류 전파 — 사전 조사와 설계

- 장비 인증 Challenge는 `LocalGameAccountVerificationGateway` 메모리에만 두고 앱 프로세스 종료 시 인증 시도도 종료하는 현재 방식을 유지하기로 확정했다. 인증 진행 카드에 앱 종료 시도 종료와 인게임에서 즉시 장비를 조작할 수 있을 때 진행하라는 안내를 추가한다.
- 시작 시 무기·방어구 5부위 중 하나라도 미장착이면 Gateway는 이미 `FormatException`을 던지지만 화면이 모든 형식 오류를 일반 정보 실패로 합치는 원인을 확인했다. 6부위 누락만 식별 가능한 시작 오류와 전용 착용 안내로 분리하고 실제 API/응답 오류의 일반 안내는 유지한다.
- 신청·즉시 참가·Character 변경 후보는 로컬 통합 Build 오류를 표시하지만 선택 결과와 파티 명령·서버 신청·membership은 보석 전용 Snapshot만 전달한다. 이 때문에 아크그리드·아크패시브 오류가 신청자·구성원 카드에서 사라지는 구조적 누락을 확인했다.
- 기존 보석 요약을 유지하면서 신청과 membership에 `buildIntegritySnapshot`을 dual-write하고 생성 리더·신청·직접 참가·승인·Character 변경을 모두 같은 경계로 맞춘다. 과거 null 호환과 오류 Character 선택 허용은 보존한다.

# 2026-09-13 다수 활동 Character 저장 권한 한도 — 구현·자동 검증

- 최종 선택 전체의 Domain 검증은 유지하고 실제 쓰기는 기존 정상 문서를 제외한 차이만 최대 4개씩 처리하도록 변경했다. 각 계정 대표 Character 추가를 먼저, 일반 추가·갱신을 다음, 비활성 삭제를 마지막에 수행한다.
- 여러 묶음은 전체 원자 저장이 아니므로 중간 실패 시 성공으로 확정하지 않는다. 추가 우선 순서로 기존 대표·최소 1명 상태를 보존하고 같은 선택을 재시도하면 남은 차이만 반영해 수렴한다.
- 8→15 신규 7개 `4 + 3` 저장, 15→8 삭제, 본·부계정 대표 우선, 두 번째 묶음 실패 후 재시도, 기존 권한·소유권·화면 저장 회귀를 추가했다.
- Repository·Write Plan·Domain·ViewModel 표적 37건, 계정 기능 전체 256건, 그룹·모집·레이드 소비 경로 26건과 변경 파일 `flutter analyze`, `git diff --check`, Node 진단 도구 문법 검사가 통과했다.
- 사용자가 수정 빌드에서 Character 수 변경 저장과 앱 재실행 후 유지가 정상임을 확인했다. 그룹·레이드 후보 반영과 기존 파티·그룹·주간 완료 기록 보존도 정상으로 확인해 실기기 완료 조건을 통과했다.

# 2026-09-12 Character Build 아이콘 fallback·중립 표시 보정 — 구현·자동 검증

- 실기기 확인에서 카탈로그 미등록 직업의 보석 대상이 API 스킬 밖이어도 아이콘 URL에 `ark_passive`가 포함되면 정상 처리되는 fallback을 확인했다. 실제 API 표본에는 특수 스킬이면서 해당 문자열이 없는 사례도 있어 URL을 모든 판정·후보 추출 근거에서 제외하기로 확정했다.
- 화면은 정상과 판정 불능을 모두 비표기하고 확정 오류만 빨간색으로 표시한다. 내부 unavailable/review와 v1/v2 parser는 오판·과거 데이터 보호를 위해 유지한다.
- 환수사 `둔갑 금술 스킬`, 가디언나이트 `가디언 피어`, 데모닉 `블러드 제노사이드`는 등록하지 않고 오류 회귀 표본으로 사용한다. 실제 캐릭터명과 전체 API 원본은 Git에 커밋하지 않는다.
- mapper에서 아이콘 fallback을 제거하고 카탈로그 미등록 직업도 현재 Character 직업명을 Tooltip 비교 기준으로 사용하게 했다. 공용 Character/Party 상태와 내 계정은 review/unavailable을 숨기고 확정 오류만 표시한다.
- 진단 도구는 여러 캐릭터명을 한 번에 조회해 전체 응답을 OS 임시 폴더에 저장하고 `ArmorySkills`와 승인 카탈로그 양쪽에 없는 후보만 보고한다. 실제 두 캐릭터 조회로 동작을 확인했으며 토큰은 출력·저장하지 않는다.

# 2026-09-12 Character Build 확정 오류 판정·표기 — 구현 및 자동 검증

- `codex/implement-build-error-policy`에서 장착 보석 11개 미만, 타 직업 보석, API 스킬·특수 카탈로그 양쪽에 없는 보석과 기존 아크그리드 최소/조건 오류를 빨간 확정 오류로 통일했다. 원본·Tooltip 정보 부족은 중립으로 분리했다.
- Character `buildIntegritySnapshot`과 파티·그룹 `gemValidationSnapshot`의 새 쓰기를 v2로 올렸다. 과거 v1은 당시 의미로 읽고, 누락·손상·알 수 없는 Snapshot은 기존 Character·신청·membership 행을 깨뜨리지 않도록 유지했다.
- 내 계정은 보석 부족·타 직업·스킬 불일치 수를 구체적으로 표시하고, 그룹 활동 목록은 `보석 오류`·`아크그리드 오류`, 파티·그룹 간략 카드는 v2 오류 요약을 표시한다. 계정 갱신과 기존 신청→승인→membership 복사 흐름을 재사용했으며 새 조회·권한 조건·네트워크 호출은 추가하지 않았다.

# 2026-09-12 Character Build 확정 오류 정의 — 협의 완료

- 빨간 확정 오류를 장착 보석 11개 미만, 타 직업 보석, 현재 API 스킬과 등록 특수 스킬 양쪽에 없는 같은 직업 보석, 질서의 해·달 누락/각 14P 미만, 장착 아크그리드 요구 아크패시브 불충족으로 확정했다.
- 카탈로그 미등록은 중립 사유로 사용하지 않는다. 정상 아이덴티티·Character 고유·아크패시브 생성 스킬은 사용자가 직업·깨달음 분기별 특수 스킬 카탈로그에 점진적으로 추가하며, 등록 후 정상 판정으로 전환한다.
- API·Tooltip 원본 자체의 누락·파싱 실패만 중립 정보 부족으로 남긴다. `ArmoryGem/Gems` 부재를 장착 0개로 오판하지 않고, 확정 장착 개수와 Effects 연결 개수를 분리하도록 구현 계획을 잡았다.
- 현재 `sameClassTargetUnverified` 중립 의미와 새 확정 오류의 소급 혼동을 막기 위해 Character Snapshot v1/v2 호환, 구버전 방어적 읽기와 같은 시각 재산출을 사전 검증한다.

# 2026-09-11 Character Build 오류 표기 재정의 — 협의 우선 기록

- 실기기에서 Build 무결성 상태 표시·관련 회귀 체크리스트는 통과했다.
- Character에 대한 오류·검토 표기(`보석`, `아크그리드`, `보석 확인 필요`, `보석 정보 없음` 등)의 의미와 명확성을 재정의하는 토의가 필요하다.
- 다음 문서 정리의 **제1 작업**은 구현이 아니라 이 표기 계약 협의다. 코드 변경은 합의 확정 후에만 한다. 상세는 `NEXT_WORK.md`.

# 2026-09-11 Character Build 무결성 상태 — 구현·자동 검증·dev 병합

- 브랜치 `cursor/character-build-integrity-status`에서 계정 갱신 최소 표시 Transaction에 `buildIntegritySnapshot`을 동반하고, 그룹원 활동 Character bottom sheet에 상태 라벨을 표시했다.
- 실기기 체크리스트는 2026-09-11 사용자 확인으로 통과했다. 표기 의미 재정의는 별도 협의 작업으로 남긴다.

# 2026-09-11 AI 작업 자동 진입점 — AGENTS.md


- 사용자가 새 AI 작업마다 개별 문서를 다시 나열하지 않아도 되도록 저장소 루트에 `AGENTS.md`를 추가했다.
- `docs/README.md`는 문서 설명과 탐색 지도, `ai_rules.md`는 상세 협업 정책으로 유지하고 두 문서의 우선순위와 링크를 새 진입점에 맞게 갱신했다.

# 2026-09-11 그룹 활동 Character Build 상태 — 사전 설계·회귀 점검

- 그룹원 탭의 활동 Character 목록에는 보석 전용 `gemValidationSnapshot`을 복제하지 않고, Character 문서의 선택 항목 `buildIntegritySnapshot`을 읽는 방향으로 확정했다. 기존 파티·그룹 membership의 `gemValidationSnapshot`은 가입·승인 시점 증거이므로 그대로 유지한다.
- 상태는 `clean/review/error/unavailable`로 단순화하되, 보석과 아크그리드 문제가 동시에 발생할 수 있으므로 `issueCodes`를 함께 저장한다. 최초 코드는 `foreignClassGem`, `sameClassGemUnverified`, `gemUnavailable`, `arkGridMinimum`, `arkGridCondition`이며 우선순위는 `error > review > clean`이다.
- `schemaVersion`, 판정 역할 `role`, `checkedAt`, `catalogVersion`을 포함해 구버전 읽기, 역할 변경, 늦게 도착한 갱신, 카탈로그 변경에 대비한다. 알 수 없는 값과 불완전 필드는 예외를 던지지 않고 상태 표시만 생략한다.
- 계정 자동·수동 갱신이 이미 사용하는 Character 최소 표시 Transaction에 상태를 같이 갱신한다. 그룹 화면은 기존 `characters` 조회와 활동 Character ID 교집합을 유지하며 별도 API·조회·인덱스·쓰기·권한 검사를 추가하지 않는다.
- 재인증 경로 두 곳의 `transaction.set(characterRef, ...)` 전체 덮어쓰기가 선택 필드인 `combatPower`와 신규 상태를 지울 수 있음을 확인했다. 구현 시 저장된 유효 값을 보존하고 회귀 테스트를 추가한다. 구버전 앱이 지운 값은 새 버전의 다음 성공 갱신에서 복구된다.
- `GroupRequestCharacter`에는 nullable 상태를 방어적으로 추가하고 그룹 활동 Character 행에서만 소비한다. 그룹 검색, 초대, 레이드 상태 필터, 정렬, 동등성 비교에는 영향을 주지 않으며 작은 화면에서는 기존 부제 문자열 결합 대신 보조 행 또는 칩으로 표시한다.

# 2026-09-11 그룹 membership 보석 Snapshot — dev 병합

- 브랜치 `cursor/group-membership-gem-snapshot`을 `dev`에 병합한다.
- 실기기: 파티 지원/가입 후 보석 표기, 그룹 초대 수락·그룹장 양도·해산 회귀를 확인했다. 그룹원 탭 후 활동 Character 목록 보석 표시는 이번 범위가 아니며 정의 대기로 남긴다.

# 2026-09-11 그룹 활동 Character 목록 보석 표시 — 정의 대기 기록

- 실기기에서 그룹원 탭 후 활동 Character 팝업에는 보석 경고가 없고, 파티 모집 경로에만 보인다는 피드백을 받았다.
- 요구: 신청/표시 Character가 A여도 같은 원정대의 B 보석 이상을 그 팝업 리스트에서 확인하고 싶다. 자동 갱신·그룹 데이터 갱신만으로 현재 계약이 이를 보장하지 않는다.
- **구현 전에 제품·아키텍처 정의를 반드시 먼저** 한다. 정의 없이 코드를 넣지 않는다. 대기 항목은 `NEXT_WORK.md` 차후 대기와 `CHARACTER_BUILD_INTEGRITY_CONTRACT.md` §5에 기록했다.

# 2026-09-11 그룹 membership 보석 Snapshot — Rules 콘솔 게시

- 브랜치 `cursor/group-membership-gem-snapshot`에서 그룹 membership·join relation·본인 Snapshot 갱신에 파티와 같은 `gemValidationSnapshot` 다섯 필드를 전파했다.
- 다음 완료 조건은 두 기기 실기기 체크리스트와 `dev` 병합이다. → 파티·그룹 회귀 확인 후 `dev` 병합으로 구간을 닫는다. 활동 Character 목록 보석 UI는 별도 정의 대기.

# 2026-09-10 Character Build 무결성 — 파티 membership 전파

- 브랜치 `codex/party-membership-build-snapshot`에서 신청 Snapshot의 최소 보석 검증 요약을 파티 membership까지 전파했다.
- 승인: 신청 `submittedBuildSnapshot`의 다섯 필드를 `gemValidationSnapshot`으로 재사용. 직접 참가·참가 Character 변경: 선택 역할의 최신 로컬 Build Snapshot을 명령에 실어 기록한다.
- membership DTO·쓰기 계획·방어적 읽기와 구성원 카드 UI를 연결했다. 정상은 숨기고 동일 직업 미확인은 중립, 다른 직업 보석만 빨간 경고다. 과거 membership·불완전 필드는 null로 읽고 아이템 레벨·전투력 표시는 유지한다.
- 표적·영향 자동 테스트 69건 통과. 변경 파일 analyze는 기존 if 중괄호 info만 남았고 신규 error는 없다.
- 통합 디바이스 테스트에서 승인·직접 참가·Character 변경 카드 표시를 확인한다.
- 다음 작업은 레이드 목록 로컬 필터·정렬이다.

# 2026-09-08 보석 Snapshot Rules 503 복잡도 완화

- 최근 추가된 보석 Snapshot 검증은 이미 큰 신청·재신청 검증 경로에 별도 함수와 반복 OR로 연결돼 있었다. 1차 평탄화 후 `/test` 컴파일은 성공했으나 신규 Ruleset 저장에서 503이 계속됐다.

## 2026-09-08 실제 API 보석 진단 기반과 Build 메모 차후 구상

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0274)로 이동했다.

## 2026-09-05 Character 자동 갱신 — 실기기 실패 보고와 방향 전환(문서만)

- G 실기기에서 사용자가 교류 직전 자동 갱신 실패를 보고했다. “기존 데이터로 계속할까요?” 확인이 거의 100% 뜨고, Armory API 자동 갱신은 체감이 매우 느리다. 통신 호출 여부는 디버깅하지 않아 확정하지 않았다.
- 나이스단 자동 갱신 허용 UI는 정상이다. 허용을 켠 뒤에도 나이스단 직업 Character가 갱신되지 않고 같은 기존 데이터 안내가 뜨므로, 제외/허용 분기와 확인 UI 경로는 동작하는 것으로 보이며 실제 Armory 갱신 성공이 안 되는 쪽으로 해석했다.
- 사용자가 구현을 중지하고 방향을 바꿨다. 파티 모집·그룹 생성 등 **현재 걸린 모든 교류 시점 자동 갱신 조건을 철회**하고, 자동 갱신은 **앱 실행 시 1회**로 정정한다. 이번 기록에서는 기능 코드를 수정하지 않았다.
- A~F 구현과 G 자동 회귀(전체 테스트 875개, 머지 기준 `185c699`)까지의 상태는 유지한다. 다음 실행 기준은 `NEXT_WORK.md`다.

## 2026-09-04 Character 자동 갱신 G — 자동 회귀와 실기기 대기

- F를 `dev`에 병합했다(기능 `2aeccf5`, 머지 `185c699`). G 브랜치 `cursor/character-refresh-g-regression`에서 통합 회귀를 실행했다.
- 표적: 조정기·최소 Snapshot Gateway/Service·나이스단·그룹 표시·Build 분석·그룹 Character refresh/options와 그룹·모집 도메인 회귀가 통과했다. 영향 범위 analyze 문제 없음.
- 전체 `flutter test --no-pub` 875개가 통과했다.
- Android 실기기 체크리스트는 `NEXT_WORK.md`에 두었다. 일반/나이스단·서포터 겸용 4직업·빠른 실행·실패·서버 동기화·비용 관찰 보고를 기다린다.
- A fixture `measuredAgainstLiveApi: false`는 실기기 Armory 문자열 대조 전까지 유지한다.

## 2026-09-04 Character 자동 갱신 F — 서버 최소 Snapshot 정합성·비용 제어

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0275)로 이동했다.

## 2026-09-04 Character 자동 갱신 C — 공통 조정기

- `CharacterAutoRefreshCoordinator`를 추가해 후보 사전 갱신과 명령 직전 `ensureFresh`가 같은 Character ID single-flight를 공유하도록 했다.
- 성공 결과는 메모리에서 5분 미만 재사용하고 5분 경계부터 다시 조회한다. Armory 요청은 최대 3개이며 대기 중 명령 요청을 후보 사전 갱신보다 먼저 실행한다.
- 결과에 Character ID와 generation을 유지하고 선택 상태 일치 검사 API를 제공한다. 대기 중이거나 실행 중인 사전 갱신에 명령 요청이 합류하면 명령의 역할 문맥을 우선한다.
- 서포터 겸용 직업은 감지된 역할과 4티어 노드, 아크그리드 조건, 모든 보석 대상을 검증한 뒤 감지 역할 Snapshot만 저장한다. 일반 직업은 호출자가 전달한 기존 역할을 유지한다.
- 나이스단 제외 요청은 Armory API를 호출하지 않고 해당 역할의 수동 Snapshot만 사용한다. 갱신 실패·판별 실패 시 기존 정상 Snapshot이 있으면 마지막 저장 시각과 계속 확인 상태를 반환하고, 없으면 차단한다. 실패 결과는 캐시하지 않아 재시도할 수 있다.
- C 표적 테스트 7개와 변경 파일 analyze가 통과했다. 전체 회귀는 857개 통과했다. 파티·그룹 UI와 명령 연결, 서버 최소값 동기화는 변경하지 않았다.

## 2026-09-04 Character 자동 갱신 B — 나이스단 정책과 로컬 설정

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0276)로 이동했다.

## 2026-09-04 Character 자동 갱신 A — 4직업 Build 카탈로그 기반

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0277)로 이동했다.

## 2026-09-04 교류 행동 기반 Character 자동 갱신 작업 구간 설계

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0278)로 이동했다.

## 2026-09-04 신청자 목록 가벼운 표시 구현

- `PartyApplicationSummary`에 `itemLevel?`·`combatPower?` 추가. Mapper `toApplication`에서 `submittedBuildSnapshot` 맵을 읽어 연결. 비정상 snapshot·누락은 null 처리.
- `ClassSynergyService` 신설(`shared/game_catalog/domain/services`). `alwaysPrimaryLabels()`로 항상채용 주요 시너지 레이블만 반환. 서포터 → 빈 목록, 선택채용 제외.
- `_PendingApplicationsSection`을 `_ApplicationCard`로 분리. 신청 카드에 아이템 레벨·전투력·주요 시너지 표시 추가.
- Mapper 테스트 3건 추가, `ClassSynergyService` 표적 테스트 8건 신규. 신규 파일 `flutter analyze --no-pub` 통과.
- Android 실기기 정상 확인. `dev` 병합·푸시 완료(머지 커밋 `a5c39ed`).

## 2026-09-03 신청자 표시 정책 결정 기록

- 사용자가 §11 결정 항목을 문서에 기록하고 커밋하도록 지시했다. 권장안을 1단계 표시 정책·2단계 목록 구현 승인으로 확정한다.
- 목록 우선, 신청 당시 Snapshot 수치·로컬 주요 시너지, 최신 세팅 별도 표시, 누락은 미확인, 선택 채용 미단정, 서포터 제외를 기록했다.
- 특성 요약·전체 상세 권한/재제출/스키마, 시너지 슬롯은 4단계 전 미결정으로 남긴다. 읽기 모델·UI·서버는 이번 커밋에서 바꾸지 않는다.
- 문서만 수정했다. `git diff --check`로 검증하고 Flutter 테스트는 반복하지 않는다.

## 2026-09-03 시너지 활용·신청자 상세 결정 기록 보강

- 사용자 요청으로 CLASS_SYNERGY_CATALOG §9~12에 확정/구현/권장/미결정 상태표를 추가했다. 이 문서를 단일 기준으로 유지한다.
- 목록 요약과 상세 지연 조회, 신청 당시/최신 세팅 분리, 신청 revision과 build 버전, 카탈로그 버전·역할·캐시·권한 경계를 기록했다.
- 현재 수치 두 개가 동일 Armory 캡처에서 온다는 보장은 없으며, 전체 스펙 서버 저장과 과거 카탈로그 재현은 미구현임을 명시했다.
- 단계별 활용 권장안, 사용자 승인 항목, 후속 성능/정합성 체크리스트를 남겼다. 전투력·아이템 레벨 UI와 서버 구조 변경은 계속 보류다.
- 문서만 보강했다. 기존 코드 테스트 831개 결과를 유지하고 Flutter 테스트는 반복하지 않는다.

## 2026-09-03 직업 시너지 카탈로그와 신청자 스펙 검토

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0279)로 이동했다.

## 2026-09-03 모집 탭 목록 필터 구현과 실기기 확인

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0280)로 이동했다.

## 2026-09-03 모집 탭 목록 필터 분석과 실행 계획

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0281)로 이동했다.

## 2026-09-03 활동 Character 공개 경로와 필터 UX 실기기 확인

- 그룹원 목록은 Projection 컬렉션 없이 `characterActivity` 목록과 Character 표시 문서를 쓴다. 캐릭터 관리 저장과 다른 그룹원의 선택 Character만 보이기가 실기기에서 통과했다.
- 레이드 현황 필터는 초기화, `그룹 공개만`일 때만 그룹원 UI, 상단 드래그 닫기가 실기기에서 통과했다.

## 2026-09-02 활동 Character Rules 컴파일 오류

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0282)로 이동했다.

## 2026-09-02 활동 Character 저장 permission-denied 안내

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0283)로 이동했다.

## 2026-09-02 활동 Character 자동 회귀 (E)

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0284)로 이동했다.

## 2026-09-02 진행 중 그룹원·Character 필터 (D3)

- 레이드 현황 `진행 중` 필터에 가입 그룹·그룹원 대표명·Character 칩을 추가한다. 현재 Player는 후보에서 제외한다.
- 그룹원 선택은 사용자 사이 AND, 한 사용자의 Character는 OR다. Character 칩이 없으면 그 사용자의 참가만 요구한다. 이미 참가 중인 비활동 Character는 판정에서 인식하고 새 칩으로는 제시하지 않는다.
- 다른 그룹원의 `characterActivity`는 owner만 읽을 수 있어 Character 칩 후보는 그룹원이 이미 읽는 인증 활성 Character다. 칩 조작은 서버 조회를 만들지 않는다.
- 저장된 그룹 선택이 모두 무효이거나 JSON이 손상되면 전체 보기로 초기화한다. 다음 단위는 E 실기기·회귀 확인이다.

## 2026-09-02 진행 중 기본 필터와 페이징 안전 (D2)

- 레이드 현황 `진행 중` 탭과 목록 사이에 `레이드 필터: 모든 레이드`를 두고 공개 조건·레이드·난이도를 로컬 원본에 적용한다. 칩 조작은 서버 조회를 만들지 않는다.
- 기본 공개 조건은 전체·일반 공개·그룹 공개가 모두 선택된 상태다. 일반과 그룹을 모두 해제하려 하면 전체로 복귀한다. 그룹 공개는 `visibility`가 아니라 `groupId` 기준이다.
- 진행 중 원본은 기존 `watchActiveRaids` membership 스트림이다. 20개 cursor는 공개 모집 목록 계약으로 유지하고, §8 페이징 안전은 `FilteredPageSession` 단위 테스트로 고정했다.
- 필터 선택은 Player별 Drift 테이블에 보존하며 카탈로그에 없는 레이드·난이도는 복원 시 제거한다. 그룹원·Character 필터는 D3다.

## 2026-09-02 그룹 전용 레이드 자격 상실과 제한적 정리 (D1)

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0285)로 이동했다.

## 2026-09-02 그룹 후보·전투력 보강을 활동 Character로 제한 (C2)

- 그룹 생성·가입 신청·초대코드 가입 후보는 `characterActivity`에 있는 Character만 사용한다.
- 그룹 상세 진입 시 전투력 서버 보강과 본인 인증 Character 목록도 활동 Character만 담는다. 다른 그룹원 목록은 소유 인증 Character를 그대로 읽는다.
- 비활동 Character의 기존 그룹 membership Snapshot은 활동 해제만으로 지우거나 null로 덮지 않는다.
- 다음 단위는 D1 그룹 전용 자격 박탈이다.

## 2026-09-02 레이드 후보를 활동 Character로 제한 (C1)

- 모집 생성 파티장 후보, 신청·참가 후보, 참가 Character 변경 후보는 `characterActivity`에 있는 Character만 사용한다. 메인 화면 표시 개수는 후보 범위를 줄이지 않는다.
- 비활동 Character는 새 후보에서 빠지고 기존 레이드 membership·Claim은 유지한다.
- 다음 단위는 C2 그룹 후보·전투력 적용이다.

## 2026-09-02 캐릭터 관리 UI 초안 저장 (B)

- 캐릭터 관리 화면을 전체 원정대 선택 카드 → 선택된 Character의 대표·순서 → 메인 표시 개수 → 취소·저장 순서로 바꿨다.
- 선택 변경은 로컬 초안에만 반영하고 `저장`에서 `ActivityCharactersRepository`와 로컬 표시 설정을 한 번 쓴다. 실패하면 로컬 영구 상태를 바꾸지 않는다.
- 대표 Character와 마지막 1명은 해제할 수 없고, 0명 저장 요청은 나가지 않는다. 기존 표시 여부 체크박스는 제거했다.
- 레이드·그룹 후보 소비 경로는 바꾸지 않았다. 다음 단위는 C1 레이드 후보 적용이다.

## 2026-09-02 활동 Character 저장 경계를 캐릭터별 문서로 재설계 (A)

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0286)로 이동했다.

## 2026-09-02 모집·현황 리스트 카드 밀도 완료

- 브랜치 `codex/raid-list-card-density`. 모집 리스트와 레이드 현황 진행 중 카드 우상단에 그룹 전용 `그룹` 배지를 추가했다.
- 제목·상태 배지는 유지하고, 난이도·레이드 줄 오른쪽에 파티장 이름만 두며, 인원과 전투력·숙련도 제한을 한 줄로 합쳤다. 목록에서 직업명과 시작 시간은 빼 카드 높이를 줄였다.
- 다음 작업은 그룹 탈퇴·추방·해산 시 그룹 전용 레이드 자격 박탈이다.

## 2026-09-01 raidListings 동기화 원칙 확정 — 문서화만 수행

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0287)로 이동했다.

## 2026-09-01 기존 그룹 listing 보완 착수

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0288)로 이동했다.

## 2026-09-01 raidListings 원자 동기화 커밋 — 실기기 보류

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0289)로 이동했다.

## 2026-09-01 listing 동기화 실기기 확인 및 생성 충돌 알림 수정

- listing 동기화·보완은 참가 충돌 알림 외 이상이 없다고 확인했다.
- 같은 레이드 조건으로 생성·해산·재생성할 때, 방은 만들어졌는데 이미 참가 중 알림이 간헐적으로 났다. 생성 Transaction 재시도와 해산 후 남은 점유를 성공/교체로 처리한다.

## 2026-09-01 생성 후 그룹 공개 범위 전환 완료

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0290)로 이동했다.

## 2026-09-01 그룹장 이전·탈퇴·해산 완료 기록 및 다음 작업

- 실기기 확인: 1인 해산, 즉시 이전, 이전 후 기존 그룹장 탈퇴, 후임 그룹장 해산.
- 초대코드 원문 미표시·폐기 대화상자 오류 화면, listing 잔여로 인한 해산 오인을 수정했다.
- 다음 작업은 생성 후 `그룹만 공개 ↔ 전체 공개` 전환이다.

## 2026-09-01 그룹장 이전·탈퇴·해산 실기기 확인

- 1인 그룹 해산과 그룹장 즉시 이전이 동작했다.
- 가→나 이전 후 가가 탈퇴하고, 레이드방을 해산한 나가 그룹 해산까지 완료했다. listing 잔여 오인 수정 후 후임 그룹장 해산이 통과했다.

## 2026-09-01 그룹 해산이 해산된 레이드 listing 잔여를 활성으로 오인

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0291)로 이동했다.

## 2026-09-01 그룹장 즉시 지정 이전·1차 해산 구현

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0292)로 이동했다.

## 2026-09-01 그룹장 즉시 지정 이전·탈퇴·해산 계약 확정

- 그룹장 이전은 대상 수락을 기다리지 않고 현재 그룹장이 유효한 일반 그룹원을 선택해 즉시 지정하는 방식으로 확정했다.
- 이전 Transaction은 group leader와 두 membership 역할을 원자적으로 교체한다. 기존 그룹장은 일반 멤버로 남고 탈퇴는 기존 명령을 별도로 실행한다.
- 이전 요청 문서, 수락·거절·취소·만료 상태, 알림과 역방향 Projection은 만들지 않는다.
- 그룹 대표 Character는 유지하고 그룹장 표시 Snapshot만 후임자 값으로 바꾼다.
- 1차 해산은 마지막 1인·pending 초대/신청 없음·활성 그룹 전용 레이드 없음 조건에서 soft delete하며, 28일 보관·이력 3개월·연결 레이드 존재 시 물리 삭제 보류를 적용한다.
- 기술 계약: [`../architecture/GROUP_LEADER_EXIT_DISBAND_CONTRACT.md`](../architecture/GROUP_LEADER_EXIT_DISBAND_CONTRACT.md)

## 2026-09-01 그룹장 탈퇴와 후속 기능 순서 확정

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0293)로 이동했다.

## 2026-09-01 그룹 전용 모집 리스트 실기기 확인

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0294)로 이동했다.

## 2026-08-31 그룹 전용 모집 목록(raidListings)

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0295)로 이동했다.

## 2026-08-31 Rules 복잡도 축소 (R1·이벤트·미사용 함수)

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0296)로 이동했다.

## 2026-08-31 모집 목록 Rules list 거부 수정

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0297)로 이동했다.

## 2026-08-31 일반/그룹 레이드 생성 연결 (B)

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0298)로 이동했다.

## 2026-08-31 모집 생성 UI(A) 실기기 확인 및 Git 종료

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0299)로 이동했다.

## 2026-08-31 모집 생성 간격·역할 높이 및 완료 표기

- 사용자 실기기: 레이드 모집 완료는 정상. 딜러/서포터 역할 드롭다운이 캐릭터 칸보다 낮고, 생성 폼 항목 간격이 답답했다.
- 역할 칸에 보이지 않는 플로팅 라벨 높이를 맞춰 캐릭터 선택과 같은 높이가 되게 했다. 항목 사이 세로 간격을 16에서 21로 늘렸다.
- 모집 상세 파티 구성 제목 옆에, 이번 회차 완료 후 해산 전 또는 반복방 다음주 대기일 때 `이번주 레이드완료`를 상단 모집 제목과 같은 크기·오류색으로 표시한다.

## 2026-08-31 모집 생성 UI 배치(A) 구현

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0300)로 이동했다.

## 2026-08-31 모집 생성 UI 다음 작업 준비 및 Git 최신화

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0301)로 이동했다.

## 2026-08-31 레이드 생성의 단일 그룹 매칭 확정

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0302)로 이동했다.

## 2026-08-31 모집 생성 UI 우선 요청 기록

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0303)로 이동했다.

## 2026-08-31 그룹 전투력 표시 수정 — 실기기 확인 및 Git 종료 승인

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0304)로 이동했다.

## 2026-08-31 그룹 전투력 수정 전 보존·작업 준비

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0305)로 이동했다.

## 📌 1. 프로젝트 초기 설계

- Flutter 기반 앱 생성
- Git 연결 완료
- docs 구조 생성 (MVP.md / DEV_LOG.md)

---

## 📌 2. 개발 방식 정의

- ChatGPT → 설계 / 구조 / 작업 분해
- Cursor → 코드 생성
- 작업은 반드시 단계별 진행

---

## 📌 3. 아키텍처 결정

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0306)로 이동했다.

## 📌 4. 레이드 데이터 설계

### RaidBase
- 레이드 공통 정보
- gateCount / difficultyIds 포함

### RaidVariation
- 실제 모집글에서 사용하는 레이드 단위
- raidId 기준 참조

---

## 📌 5. 모집글 데이터 설계

### 핵심 구조
- raidId 기반 구조
- gateProgress (start / end)
- 역할별 모집 상태 (dealer / support)
- memberSummary

### 조건
- minCombatPower
- experienceLevel (5단계 고정)

### 숙련도
- tryLevel
- clearExp
- multiClearExp
- semiExperienced
- experienced

### 시간
- raidStartAt
- maxPlayHours (null = 클리어시)
- recruitmentOpenedAt
- recruitmentClosedAt

---

## 📌 6. 데이터 관리 방식 결정

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0307)로 이동했다.

## 📌 7. 폴더 구조 설계 및 생성

- shared/raid_master
- features/recruitment_list

구조:

- domain (entities / repositories)
- data (datasources / repositories)
- presentation (viewmodels / pages / widgets)

---

## 📌 8. 구현 완료 상태

- raid_base.dart 생성 완료
- raid_variation.dart 생성 완료
- raid_master_repository.dart 생성 완료
- local_raid_data_source.dart 생성 완료
- raid_master_repository_impl.dart 생성 완료
- party_recruitment.dart 생성 완료

---

## 📌 9. 당시 작업 기준 상태
- 당시 기준으로 모집글 리스트 기능 구현 직전 상태였음
- 다음 작업 후보로 아래 항목들을 계획했음:
  - local_recruitment_list_data_source.dart 작성
  - mock 모집글 데이터 생성
  - recruitment_list repository 구현

---

## 📌 10. 모집글 리스트 데이터 레이어 구현

다음 파일 작성 완료:

- features/recruitment_list/domain/repositories/recruitment_list_repository.dart
- features/recruitment_list/data/datasources/local_recruitment_list_data_source.dart
- features/recruitment_list/data/repositories/recruitment_list_repository_impl.dart

### 구현 내용
- RecruitmentListRepository 인터페이스 정의
- LocalRecruitmentListDataSource 구현
- mock 모집글 데이터 6개 작성
- RecruitmentListRepositoryImpl 구현
- repository → data source 연결 완료

---

## 📌 11. 테스트 작성 및 실행 확인

다음 테스트 파일 작성 완료:

- test/local_recruitment_list_data_source_test.dart
- test/recruitment_list_repository_test.dart

### 테스트 내용
- LocalRecruitmentListDataSource fetchRecruitments() 결과 검증
- mock 데이터 개수 및 필드값 검증
- recruitment status / null maxPlayHours 케이스 검증
- RecruitmentListRepositoryImpl getRecruitments() 동작 검증
- repository 결과와 data source 결과 일치 여부 검증

### 확인 사항
- flutter analyze 이후 테스트 정상 인식 확인
- 개별 테스트 실행 통과
- 전체 테스트 실행 시 기존 기본 widget_test.dart 영향 여부 별도 확인 필요

## 📌 12. 레이드 데이터 로컬 작업
- 자료 입력
- 각 레이드 데이터가 실제 인게임 데이터와 동일하게 입력되었는지 확인 완료.

---

## Task-002. Recruitment List Presentation Layer 구현

### 완료 파일
- features/recruitment_list/presentation/viewmodels/recruitment_list_view_model.dart
- features/recruitment_list/presentation/pages/recruitment_list_page.dart
- features/recruitment_list/presentation/widgets/recruitment_card.dart
- lib/main.dart
- test/widget_test.dart

### 구현 내용
- RecruitmentListViewModel 구현 완료
  - MVVM 구조 유지
  - Repository를 통해 mock 모집글 데이터 조회
  - loading / error / recruitments 상태 관리
- RecruitmentListPage 구현 완료
  - ViewModel을 통해 데이터 조회
  - 모집글 목록 화면 구성
  - mock 모집글 6개 표시
- RecruitmentCard 구현 완료
  - 모집글 제목
  - 레이드 ID 및 관문 범위
  - 리더 정보
  - 현재 인원 / 최대 인원
  - 딜러 / 서포터 모집 상태
  - 최소 전투력 / 숙련도 / 플레이 시간 표시
- main.dart 연결 완료
  - 앱 시작 화면을 RecruitmentListPage로 변경
- widget_test 수정 완료
  - counter 테스트를 모집글 목록 표시 테스트로 변경

### 검증 결과
- flutter analyze 통과
- flutter test 통과
- 전체 테스트 12개 통과

---

## Task-003. 문서 최신화

### 수정 파일
- docs/AI_CONTEXT.md
- docs/DEV_LOG.md

### 반영 내용
- 현재 브랜치를 feature/recruitment-list-ui 기준으로 정리
- Recruitment List Presentation Layer 완료 상태 반영
- main.dart에서 RecruitmentListPage 실행 상태 반영
- widget_test가 모집글 목록 표시 테스트로 변경된 상태 반영
- flutter analyze 통과 상태 반영
- flutter test 12개 통과 상태 반영
- 다음 작업 후보를 현재 구현 이후 단계로 갱신

### 현재 기준
- 코드 변경 없음
- MVP.md 변경 없음
- ai_rules.md 변경 없음

---

## Task-004. Lost Ark API 로컬 저장 기반 준비

### 추가 의존성
- drift
- drift_flutter
- drift_dev (개발용 코드 생성)

### 사용 목적과 선택 이유
- 계정과 여러 캐릭터의 관계, 마지막 API 갱신 시각, 자동 갱신 설정을 SQLite에 구조화하여 저장
- 장비, 스킬, 각인, 카드, 보석 등 크고 변경 가능성이 있는 상세 API 응답은 JSON으로 함께 보존
- 타입 안전한 쿼리, 트랜잭션, 스키마 버전 및 마이그레이션을 지원하여 단순 JSON 파일보다 안정적인 로컬 데이터 관리 가능
- 기존 MVVM 및 Repository 구조 안에서 저장 구현을 교체하거나 테스트하기 쉬움

### 현재 범위
- 로컬 DB 사용을 위한 의존성만 추가
- DB 테이블, DAO, DataSource 및 Repository 연동은 아직 구현하지 않음
- 실제 저장 구조는 Lost Ark API DTO 범위가 확정된 뒤 구현 예정

---

## Task-005. 앱 셸 및 공통 내비게이션 기반

### 구현 내용
- StatefulShellRoute 기반 하단 탭 구조 적용
- 첫 번째 탭을 내 계정, 두 번째 탭을 파티 모집으로 구성
- PageView 스와이프와 하단 탭 선택 상태 동기화
- 탭별 Navigator 스택과 공통 뒤로가기 기반 구성
- 기존 RecruitmentListPage를 두 번째 탭에 유지

---

## Task-006. Lost Ark API 인증 및 통신 기반

### 인증
- 사용자가 앱에서 Lost Ark JWT를 직접 등록, 변경, 삭제할 수 있는 화면 구현
- flutter_secure_storage로 JWT 보관
- 저장된 JWT 원문을 입력창, 상태 화면 및 로그에 다시 노출하지 않음
- 토큰이 없으면 요청을 시작하지 않고 안내 다이얼로그 표시
- 안내를 닫은 뒤에도 앱의 다른 화면을 계속 탐색할 수 있도록 구성

### 공통 API 클라이언트
- Dio 기반 Lost Ark API 공통 클라이언트 구현
- API base URL과 connect/send/receive timeout 설정
- 요청 직전에 토큰을 읽어 Authorization 헤더 적용
- 401, 404, 429, 5xx, timeout, network, invalid response 오류 분류
- 진단 로그에는 HTTP method와 status만 남기고 URL, header, JWT 제외

### 원정대 캐릭터 조회
- `GET /characters/{characterName}/siblings` endpoint 연동
- DTO와 json_serializable 생성 코드 구성
- API DTO에서 Domain Entity로 변환하는 mapper 구현
- remote data source와 AccountRepository 구현체 연결
- 내 계정 ViewModel에서 조회, 로딩, 결과 및 오류 상태 관리
- 내 계정 화면에서 대표 캐릭터명 입력 후 원정대 캐릭터 목록 표시

### 플랫폼 설정
- Android 인터넷 권한 및 secure storage를 위한 최소 SDK/백업 설정 반영
- iOS Keychain 사용을 위한 entitlements 연결
- flutter_secure_storage 플러그인 등록 파일 반영

### 검증
- Galaxy Z Fold6(SM_F956N) 실기기 빌드 및 설치 성공
- 사용자가 앱에 JWT를 직접 입력한 뒤 저장 동작 확인
- 실제 캐릭터명 검색과 Lost Ark API 응답 표시 확인
- 저장소 민감정보 검사 결과 실제 JWT 없음
- flutter analyze: issue 0개
- flutter test: 전체 46개 통과

### 현재 범위
- siblings 응답은 화면에 표시하지만 Drift 로컬 DB에는 아직 저장하지 않음
- 추가 캐릭터 상세 endpoint 및 계정 상세 화면은 다음 작업 범위

---

## Task-007. 캐릭터 역할별 세팅 저장 설계

### 설계 원칙
- 캐릭터 기본 정보와 역할별 상세 세팅을 분리하여 저장
- 동일 캐릭터를 역할별로 중복 생성하지 않음
- 하나의 캐릭터에 `dealer` 또는 `support` 역할별 스냅샷을 연결
- 직업과 역할을 분리하며 최종 역할은 사용자가 스냅샷 저장 시 선택
- 각인 등 상세 데이터 분석은 역할 추천이나 경고에만 사용
- 자동 분석 결과보다 사용자의 명시적 선택을 우선

### 직업 분류
- 서포터형 직업: 바드, 발키리, 도화가, 홀리나이트
- 서포터형 직업은 `support`와 `dealer` 스냅샷을 각각 저장 가능
- 위 4개 직업을 제외한 모든 직업은 딜러군으로 분류
- 딜러군 직업은 `dealer` 스냅샷만 저장
- 서포터형 직업 목록은 변경 가능성을 고려하여 한 곳에서 관리

### 캐릭터 기본 정보
`Character`

- 캐릭터명
- 서버명
- 직업
- 전투 레벨
- 아이템 레벨
- 기본 정보 마지막 갱신 시각

### 역할별 세팅 스냅샷
`CharacterBuildSnapshot`

- 대상 캐릭터 ID
- 역할: `dealer` 또는 `support`
- 장비
- 각인
- 보석
- 카드
- 전투 특성
- 역할 판정 및 파티 지원에 필요한 상세 정보
- 스냅샷 저장 시각

검색과 비교에 필요한 값은 구조화된 컬럼으로 저장하고, 상세 API 원본 응답은 JSON으로 함께 보존하는 방식을 검토한다.

### 데이터 갱신 흐름
1. 사용자가 게임에서 저장하려는 세팅을 적용한다.
2. 앱에서 해당 캐릭터의 데이터 갱신을 실행한다.
3. 서포터형 직업은 `서포터 세팅` 또는 `딜러 세팅`을 선택한다.
4. 딜러군 직업은 별도 역할 선택 없이 딜러 세팅으로 갱신한다.
5. 앱이 현재 캐릭터 상세 데이터를 API로 조회한다.
6. 선택된 역할의 스냅샷을 신규 저장하거나 최신 데이터로 교체한다.
7. 다른 역할도 저장하려면 게임 내 세팅을 변경한 뒤 다시 갱신한다.
8. API 호출 간격은 고정된 10초 값이 아닌 설정 또는 서버 응답 기준으로 관리한다.
9. `429 Too Many Requests` 응답을 별도로 처리한다.

### 파티 지원 연계
`PartyApplication`

- 모집글 ID
- 캐릭터 ID
- 역할별 스냅샷 ID
- 지원 역할

동작 원칙:

- `dealer` 스냅샷이 있으면 딜러 모집에 지원 가능
- `support` 스냅샷이 있으면 서포터 모집에 지원 가능
- 두 스냅샷이 있는 서포터형 캐릭터는 양쪽 모집에 선택적으로 지원 가능
- 해당 역할의 스냅샷이 없으면 먼저 해당 세팅 저장을 안내

### 구현 전 확정 항목
- 역할별 스냅샷에 포함할 Lost Ark API endpoint와 필드
- 구조화 컬럼과 원본 JSON의 저장 범위
- 스냅샷 유효기간과 갱신 필요 표시 기준
- 파티 지원 당시 스냅샷을 고정할지 최신 스냅샷을 참조할지
- API 호출 간격과 `429` 재시도 정책

### 현재 범위
- 설계 내용만 확정 및 문서화
- Drift table, DAO, local data source는 아직 구현하지 않음
- 파티 지원 기능은 아직 구현하지 않음

### 조회 캐릭터와 대표 캐릭터 구분
- API 조회를 시작할 때 입력한 캐릭터는 `조회 캐릭터`로 정의
- Lost Ark API 응답에서 공식 대표 캐릭터를 얻었다고 간주하지 않음
- 앱의 `대표 캐릭터`는 로컬 계정 그룹 안에서 사용자가 직접 선택
- 최초 등록 시 조회 캐릭터를 대표 캐릭터 기본값으로 사용할 수 있음
- 대표 캐릭터는 같은 계정 그룹 내에서 횟수 및 시간 제한 없이 변경 가능
- 대표 캐릭터 변경은 API 호출 없이 로컬 `representativeCharacterId`만 갱신
- 실제 선택 UI와 Drift 저장은 계정 로컬 저장 구현 단계에서 추가

---

## Task-008. 조회 캐릭터 프로필 및 계정 DB 기반

### 상세 프로필
- `GET /armories/characters/{characterName}`의 `ArmoryProfile` 연동
- 캐릭터명, 서버, 직업, 전투 레벨, 아이템 레벨, 전투력 DTO 구성
- 쉼표가 포함된 아이템 레벨과 전투력을 숫자 Domain 값으로 변환
- API 입력 캐릭터를 `대표 캐릭터`가 아닌 `조회 캐릭터`로 화면에 표시
- Galaxy Z Fold6 실제 API 호출에서 전투력 표시 확인

### Drift 스키마 버전 1
- `game_accounts` 테이블 추가
- `account_characters` 테이블 추가
- 메인/부계정 구분과 조회 캐릭터명 저장
- 로컬 대표 캐릭터 ID 저장
- 계정당 기본 표시 개수 6개 저장
- 캐릭터 표시 여부와 표시 순서 컬럼 준비
- 계정 삭제 시 소속 캐릭터 cascade 삭제
- 동일 계정의 서버명과 캐릭터명 조합 중복 방지

### 로컬 정책
- 대표 캐릭터는 같은 계정 소속 캐릭터만 지정 가능
- 대표 캐릭터 변경에는 API 호출이나 쿨타임 없음
- 표시 개수는 1개 이상으로 변경 가능
- 역할별 상세 스냅샷 테이블은 상세 필드 확정 후 추가

### 검증
- 상세 프로필 remote data source 및 mapper 테스트 추가
- Drift 인메모리 DB 테스트 4개 추가
- flutter analyze: issue 0개
- flutter test: 전체 55개 통과

### 다음 연결 범위
- siblings 결과를 `game_accounts`, `account_characters`에 트랜잭션 저장 완료
- 최초 조회 캐릭터를 대표 캐릭터 기본값으로 설정 완료
- 재조회 시 사용자가 변경한 대표 캐릭터 선택 유지
- Repository의 원격 조회 성공 결과를 LocalDataSource로 전달하도록 연결
- 앱 생명주기에서 AccountDatabase 생성 및 종료 관리
- widget 테스트는 인메모리 DB를 주입하여 파일 DB 중복 사용 방지
- 저장된 계정 데이터를 앱 시작 시 메인 화면에 표시 완료
- 기본 최대 6개 캐릭터를 화면 폭에 따라 2~4열 그리드로 표시
- 6명 미만 계정은 실제 저장된 캐릭터 수만 표시
- 사용자 설정 전 아이템 레벨 내림차순으로 상위 6개 표시
- 사용자 표시 순서가 저장되면 해당 순서를 우선 적용
- 조회 캐릭터의 상세 전투력을 로컬 캐릭터 데이터에 저장
- siblings 재조회 시 기존 전투력, 표시 여부 및 표시 순서 보존
- 대표 캐릭터 카드에 별표 표시
- 최상단 토큰 상태 및 설정 영역 구성
- 대표 캐릭터 변경 및 표시 캐릭터 관리 UI 구현
- 부계정 추가 흐름 구현

---

## Task-009. 계정 캐릭터 관리

### 구현
- 메인 계정 헤더에서 캐릭터 관리 화면으로 이동하는 route 추가
- 계정에 저장된 전체 캐릭터의 표시 여부 변경
- 메인 화면 표시 개수를 1명부터 계정 캐릭터 수까지 조절
- 로컬 대표 캐릭터를 제한 없이 변경하고, 숨김 캐릭터를 대표로 선택하면 자동 표시
- 대표 캐릭터는 메인 화면과 관리 화면에서 항상 첫 번째로 표시
- 대표 캐릭터를 숨기면 계정 내 다른 캐릭터 중 아이템 레벨이 가장 높은 캐릭터가 대표를 승계
- 승계 대상이 숨김 상태라면 자동으로 표시하며, 대체 캐릭터가 없으면 기존 대표를 숨기지 않음
- 드래그로 캐릭터 표시 순서를 변경하고 Drift에 즉시 저장
- 관리 화면에서 돌아오면 메인 계정 그리드를 다시 로드
- 모든 관리 작업은 로컬 DB만 사용하며 Lost Ark API를 호출하지 않음

### 검증
- Drift 가시성 및 표시 순서 저장 테스트 추가
- CharacterManagementViewModel의 대표 캐릭터, 표시 개수, 재정렬 테스트 추가
- Galaxy Z Fold6에서 표시 개수, 숨김, 대표 변경, 재정렬 및 재실행 후 설정 유지 확인
- profile 빌드에서 캐릭터 목록 스크롤 버벅임이 사라진 것을 확인
- AppBar와 본문 배경을 같은 surface 색상으로 통일해 스크롤 시 색상 변화를 제거
- flutter analyze: issue 0개
- flutter test: 전체 67개 통과

### 다음 범위
- 캐릭터 카드 상세 화면 route 구현
- 부계정 추가 흐름 구현

---

## Task-010. 캐릭터 상세 응답 fixture 및 세팅 검증 기반

### 데이터 분석
- 실제 종합 상세 API 응답을 수집한 뒤 개인정보성 프로필 필드를 목 값으로 치환
- 익명화된 전체 응답 fixture를 `test/fixtures/lost_ark`에 저장
- JWT, Authorization header 및 원본 응답 파일은 저장하지 않음
- 보석 11개, 스킬, 룬, 아크패시브 및 아크그리드 구조 확인

### 검증 기반
- 보석 슬롯과 효과 스킬을 `GemSlot`으로 연결
- 피해 증가, 재사용 대기시간 감소 및 지원 효과 문장 보존
- 일반 스킬과 아크패시브/아이덴티티 스킬을 구분
- 스킬 레벨만으로 장착 여부를 판정하지 않음
- 룬이 8개가 아니면 확인 경고 생성
- 아크그리드 발동 조건과 활성 아크패시브 비교
- 질서의 해/달 14P 필수 효과 및 유물 이상 17P 효과 활성 여부 확인
- 질서의 별과 혼돈 코어는 포인트 상태만 제공하고 필수 경고에서는 제외
- 모든 경고는 안내 목적이며 파티 지원 제한과 연결하지 않음

### 검증
- fixture 기반 mapper 테스트 7개 추가
- flutter analyze: issue 0개
- flutter test: 전체 78개 통과

### 역할별 스냅샷 저장
- Drift 스키마 버전 2 적용
- `character_build_snapshots` 테이블 추가
- 캐릭터당 `dealer`, `support` 스냅샷을 각각 하나씩 저장
- 같은 역할 재저장 시 해당 역할만 최신 데이터로 교체
- 반대 역할 스냅샷은 유지
- 전체 API 원본 JSON, 아이템 레벨, 전투력, 저장 시각 및 데이터 버전 저장
- 경고 결과는 규칙 변경을 반영할 수 있도록 원본 JSON에서 다시 계산
- siblings 재조회 시 기존 캐릭터를 update해 ID와 역할별 스냅샷 유지
- 계정에서 사라진 캐릭터만 삭제하고 연결 스냅샷도 cascade 삭제
- 실제 전체 fixture를 딜러 스냅샷으로 저장하고 원문 그대로 복원하는 테스트 추가

---

## Task-011. 캐릭터 상세 화면 및 역할별 세팅 갱신

### 구현
- 캐릭터 카드에서 상세 화면으로 이동하는 route 연결
- 캐릭터 상세 화면에 프로필, 역할 선택, 저장 상태, 경고, 보석 및 아크그리드 결과 표시
- 바드, 발키리, 도화가, 홀리나이트는 딜러/서포터 저장 위치를 선택
- 그 외 직업은 딜러 역할을 기본값으로 사용
- `세팅 저장`/`세팅 갱신` 시 실제 `GET /armories/characters/{characterName}` 호출
- 수신한 전체 JSON을 선택 역할 스냅샷으로 저장하고 분석 결과를 다시 로드
- 같은 역할은 덮어쓰고 반대 역할 스냅샷은 유지
- 누락 토큰, 인증, 호출 제한, 네트워크 및 응답 오류 안내

### 실기기 검증
- Galaxy Z Fold6 profile 빌드 설치
- 실제 API 통신으로 딜러/서포터 데이터를 각각 저장하고 독립 유지되는 것을 확인
- 테스트 fixture는 자동 테스트에서만 사용하며 앱의 상세 갱신에는 사용하지 않음

### 검증
- 전체 armory fixture가 Repository와 Drift를 거쳐 역할 스냅샷으로 저장되는 테스트 추가
- 서포터 역할 선택 및 딜러 기본 역할 ViewModel 테스트 추가
- flutter analyze: issue 0개
- flutter test: 전체 81개 통과

### 확인된 API 특성
- 바드의 `용맹의 세레나데`, `구원의 세레나데`는 `ArmorySkills`의 독립 항목으로 제공되지 않음
- 두 이름은 능력치, 아크패시브 및 아크그리드 Tooltip 설명에만 등장
- 아이덴티티/아크패시브 스킬은 직업별 게임 기준정보로 보완 필요
- 아크그리드 발동 조건은 깨달음 1티어 계열뿐 아니라 4티어 노드 등 추가 조건을 포함할 수 있음

### 다음 작업 후보
1. 직업별 정적 게임 기준정보 JSON 스키마 확정
2. 깨달음 1티어 노드, 인게임 통칭, 역할 및 아이덴티티 스킬 기록
3. 주요 아크그리드 조합과 조건 데이터 기록
4. 정적 기준정보와 분리된 사용자 메모/선호 조합 로컬 DB 설계
5. API 응답을 먼저 분석한 뒤 저장 위치를 선택하는 미리보기 화면 구현
6. 감지 역할과 사용자 선택 역할이 다를 때 안내하되 저장은 제한하지 않음
7. 내 캐릭터와 파티 지원자가 공유하는 캐릭터 요약 카드 재구성
8. 좁은 화면 1열, 펼친 Fold6 2열을 기준으로 가용 폭 기반 반응형 배치 적용

---

## Task-010. 직업별 기준정보 확장 구현 기준 정리

### 확인한 저장소 상태
- 실제 현재 브랜치는 `main`
- 작업 시작 시 `main`과 `origin/main`이 일치하며 작업 트리는 깨끗함
- 기존 문서의 `feature/account-character-dashboard` 현재 브랜치 표기를 실제 상태에 맞게 수정

### 확정한 용어와 데이터 경계
- 직업, 깨달음 1티어 계열, 인게임 통칭, 역할 및 주요 아크그리드 조합을 서로 다른 개념으로 정의
- 직업별 게임 기준정보는 Git으로 버전 관리하는 정적 JSON 카탈로그로 관리
- 캐릭터 개인 메모는 캐릭터 공통 사용자 데이터로 저장
- 선호 조합은 캐릭터별 사용자 선택값으로 저장하고 정적 조합 정의 및 역할별 스냅샷과 분리
- 감지 역할은 안내용 분석 결과이며 사용자가 선택한 저장 역할을 우선
- 역할 불일치는 미리보기에서 안내하되 특수 세팅 저장을 제한하지 않음
- 세팅 갱신 결과는 사용자 승인 전까지 메모리에 유지하고 기존 스냅샷을 변경하지 않음

### 작업 분리 결정
- 이번 작업은 구현 전 문서 기준과 데이터 경계를 확정하는 단위
- 직업별 노드, 통칭, 아이덴티티/아크패시브 스킬 및 아크그리드 조합의 수기 입력은 아직 시작하지 않음
- 다음 작업에서 정적 카탈로그 Domain 모델과 검증 가능한 JSON 구조를 먼저 구현
- 카탈로그 구조 확정 후 한 직업의 최소 데이터를 입력해 분석 흐름을 검증하고 전체 직업 입력으로 확대

### 검증
- 문서만 변경하여 관련 Flutter 테스트 대상 없음
- 코드, 생성 파일 및 Drift 스키마 변경 없음
- 커밋 및 푸시하지 않음

---

## Task-011. 정적 게임 카탈로그 Domain 모델 및 검증

### 구현 내용
- `shared/game_catalog` 공통 영역에 정적 게임 카탈로그 Domain 모델 추가
- 직업, 지원 역할, 깨달음 1티어 계열, 아이덴티티/아크패시브 스킬, 주요 아크그리드 조합 및 코어 요구사항 구조 정의
- 카탈로그 스키마 버전과 데이터 버전을 분리
- account/recruitment feature에 의존하지 않는 카탈로그 전용 역할 타입 정의
- 중복 ID/API 직업명, 빈 필수값, 미지원 역할, 잘못된 계열 참조 및 코어 포인트 범위를 수집형 검증 결과로 반환

### 범위 제외
- 실제 직업별 노드, 통칭, 스킬 및 조합 데이터 입력
- JSON DTO, asset 등록, DataSource 및 Repository 연결
- 기존 역할 타입 통합 및 분석기 연결

### 검증
- 정적 카탈로그 검증 단위 테스트 5개 통과
- 전체 `flutter analyze`와 `flutter test`는 커밋 직전 한 번 실행 예정
- 커밋 및 푸시하지 않음

### Git 작업 절차 보완
- 모든 작업은 작업 단위별 브랜치에서 진행하도록 협업 지침에 명시
- 작업 시작 전 현재 브랜치와 작업 트리 확인을 필수화
- `main` 또는 기본 브랜치에서 직접 수정하지 않고 먼저 작업 브랜치를 생성
- Codex 작업 브랜치는 기본적으로 `codex/` 접두사를 사용

---

## Task-012. 바드 최소 JSON 카탈로그 및 asset 로딩

### 구현 내용
- 카탈로그 JSON asset 등록
- 엄격한 JSON mapper와 asset DataSource 구현
- Domain 검증을 통과한 카탈로그만 반환하는 Repository 구현
- API fixture에서 바드의 `CharacterClassName`이 한글 `바드`임을 확인
- 영문 `BARD`는 직업 별칭으로 기록
- `완벽한 화음` 서포터 계열과 `진실된 용맹` 딜러 계열 입력
- `용맹의 세레나데`, `구원의 세레나데`를 두 계열 공통 아이덴티티 스킬로 입력
- 세부 아크그리드 조합 목록은 비워 두어 1차 범위에서 제외

### 후속 기능으로 기록한 내용
- 직업별 전체 해/달/별 코어 기준정보
- 3코어 조합 통칭과 인게임 UI 숫자 순서 별칭
- 사용자 지정 선호 조합과 조합별 평가 메모
- 파티 지원자의 실제 장착 코어와 사용자 선호 조합 일치 표시

### 검증
- 실제 번들 JSON asset 로딩 포함 카탈로그 관련 테스트 8개 통과
- 전체 `flutter analyze` 통과
- 전체 `flutter test` 89개 통과

### 다음 채팅 인계
- 현재 브랜치: `codex/game-catalog-foundation`
- 다음 작업은 병합된 `main`에서 새 작업 브랜치를 먼저 생성
- 게임 카탈로그를 기존 캐릭터 세팅 분석기에 연결하고 바드 fixture로 계열 및 역할 감지를 검증
- 분석 연결 단계에서는 카탈로그 역할과 기존 스냅샷 역할을 명시적으로 변환
- 저장 전 미리보기, 사용자 메모 DB, 다른 직업 수기 입력 및 세부 아크그리드 조합은 후속 작업으로 유지

---

## Task-013. 작업 그룹 인계 문서 도입 및 main 최신화

### Git 최신화
- 원격 상태를 확인한 뒤 `codex/game-catalog-foundation`을 로컬 `main`에 fast-forward
- 게임 카탈로그 기반 커밋 `3b52088`을 다음 작업의 코드 기준으로 확정
- 문서 추가와 상태 최신화를 포함한 마지막 커밋을 원격 `main`에 푸시하는 절차로 진행

### 문서 운영 방식
- 새 작업 그룹의 실행 명세를 관리하는 `docs/NEXT_WORK.md` 추가
- `NEXT_WORK.md`는 누적 로그가 아니라 작업 그룹 종료 시 다음 작업 내용으로 교체
- 완료 이력은 `DEV_LOG.md`, 프로젝트 전체 현재 상태는 `AI_CONTEXT.md`에서 계속 관리
- 새 채팅에서는 `NEXT_WORK.md`, `AI_CONTEXT.md`, `ai_rules.md`, Git 상태 및 관련 코드를 순서대로 대조
- 문서와 실제 저장소 상태가 다르면 실제 상태를 기준으로 문서를 먼저 갱신

### 다음 작업 그룹
- 게임 카탈로그와 기존 캐릭터 세팅 분석기 연결
- 바드 fixture의 `진실된 용맹`과 `템페스트 필드`로 `딜바드` 및 `dealer` 감지 검증
- 저장 전 미리보기, 사용자 메모 DB, 다른 직업 데이터 및 카드 개편은 제외

### 검증
- `flutter analyze` 통과
- `flutter test` 89개 통과
- 애플리케이션 코드 변경 없음

---

## Task-014. 반복 작업 그룹 및 테스트 최소화 규칙 문서화

### 작업 사이클
- 새 채팅마다 문서와 Git 상태를 먼저 확인하고 코드 수정 전 작업 단위를 제시
- 승인된 첫 번째 작업 단위만 별도 브랜치에서 구현
- 구현 중에는 변경 영역과 직접 관련된 테스트만 실행
- 설계 결정, 실기기 확인 또는 외부 승인이 필요한 시점에만 중간 보고 후 대기
- 최종 커밋 직전에 전체 `flutter analyze`와 `flutter test`를 각각 한 번 실행
- 완료 문서와 다음 채팅용 `NEXT_WORK.md` 최신화를 같은 최종 커밋과 푸시에 포함

### 테스트 최소화
- 전체 테스트의 진행 중 반복 실행을 금지하고 관련 테스트 중심으로 회귀 확인
- 실기기 검증 대기 전후 코드가 같으면 전체 검증을 중복 실행하지 않음
- 순수 문서 변경은 `git diff --check`와 문서 검토를 기본 검증으로 사용

### 변경 범위
- 협업 및 인계 문서만 변경
- 애플리케이션 코드, 테스트 코드 및 의존성 변경 없음

---

## Task-015. 게임 카탈로그 기반 캐릭터 계열 및 역할 감지

### Domain 및 분석
- 카탈로그 감지 결과와 감지 상태 Domain 모델 추가
- 감지 성공, 미지원 직업, 계열 미감지 및 복수 계열 감지를 구분
- 카탈로그 버전, 직업/계열 ID, 표시 이름, 감지 역할 및 일치 노드를 결과로 제공
- `GameCatalogRole`에서 `CharacterBuildRole`로 명시적으로 변환
- 역할 enum을 독립 Domain 파일로 분리하고 기존 snapshot import 호환 유지

### 바드 연결
- 전체 armory fixture의 `진실된 용맹`으로 `딜바드`와 dealer 역할 감지
- `템페스트 필드`를 관련 패시브 근거로 기록
- `완벽한 화음`으로 `바드`와 support 역할 감지
- 감지 역할은 사용자 선택 스냅샷 역할을 변경하지 않음

### 저장 및 앱 연결
- `LocalAccountDataSource`에 `GameCatalogRepository` 주입
- 번들 카탈로그를 한 번 로드해 저장된 armory 원본 JSON 분석에 사용
- 별도 Drift 마이그레이션 없이 기존 스냅샷도 현재 카탈로그 결과를 재생성
- 앱 라우터 조립부에 asset 카탈로그 Repository 연결

### 검증
- 감지 성공, support 계열, 미지원 직업, 미감지, 모호함 및 기존 호출 호환 테스트 추가
- Repository 저장 역할 유지와 카탈로그 분석 결과 로딩 검증
- `flutter analyze` 통과
- `flutter test` 94개 통과
- UI 변경이 없어 별도 실기기 검증 불필요

## Task-016. 캐릭터 세팅 Draft/Commit 저장 경계

### Domain 및 Repository
- API 조회 결과를 저장 전 상태로 표현하는 `CharacterBuildDraft` 추가
- draft에 대상 캐릭터 ID, 원본 JSON, 프로필, 카탈로그 분석 결과 및 조회 시각 포함
- `createCharacterBuildDraft`는 원격 조회와 분석만 수행하고 로컬 DB를 변경하지 않음
- `commitCharacterBuildDraft`는 draft와 사용자 선택 역할을 받아 저장된 스냅샷을 반환
- 감지 역할과 선택 역할이 달라도 선택 역할로 commit 허용
- 기존 상세 화면 호출부는 draft 생성 직후 commit하는 호환 메서드로 유지

### 저장 안전성
- 선택 역할 스냅샷과 최신 캐릭터 프로필을 Drift 단일 트랜잭션으로 저장
- draft의 캐릭터명과 로컬 캐릭터가 일치하는지 commit 시 검증
- 선택하지 않은 반대 역할 스냅샷 유지
- 저장된 스냅샷 로딩 시 현재 번들 카탈로그로 재분석하는 기존 동작 유지

### 범위 제외
- 저장 전 미리보기 UI 및 ViewModel 상태 변경
- 역할 불일치 안내 화면
- draft 장기 보관, 사용자 메모, 카드 변경 및 다른 직업 데이터 입력

### 검증
- draft 생성 후 스냅샷과 프로필이 변경되지 않는 Repository 테스트 추가
- 원본 JSON, 프로필, 분석 결과 및 조회 시각 포함 검증
- 역할 불일치 commit, 선택 역할 저장, 반대 역할 보존 및 프로필 갱신 검증
- 관련 Repository 및 DB 테스트 15개 통과
- `flutter analyze` 통과
- `flutter test` 95개 통과
- UI 변경이 없어 별도 실기기 검증 불필요

---

## Task-017. 작업 그룹 main 최신화 규칙 추가

### 작업 종료 기준
- 기능 브랜치의 구현, 검증, 문서화, 커밋 및 푸시 이후 `main` 병합 단계를 추가
- 검증 성공한 기능 브랜치만 `main`에 병합
- 병합 결과를 원격 `main`에 푸시하고 로컬/원격 최종 커밋 일치 확인
- 충돌 해결이나 병합 과정에서 코드가 변경되면 영향 검증을 다시 실행
- 병합으로 코드가 바뀌지 않으면 기능 브랜치의 최종 검증 결과 재사용

### 검증
- 애플리케이션 코드와 의존성 변경 없음
- `git diff --check`와 문서 내용 검토로 확인

---

## Task-018. 캐릭터 세팅 저장 미리보기 UI

### ViewModel
- 세팅 조회와 저장 진행 상태를 분리하고 현재 draft와 저장 역할을 메모리에서 관리
- API 조회 성공 후에도 기존 스냅샷을 유지하고 사용자 승인 시에만 commit
- 취소 시 draft 폐기, commit 실패 시 draft 유지 및 재시도 가능
- 지원 직업의 dealer/support 선택과 일반 직업의 dealer 제한 유지
- 중복 draft 조회와 중복 commit 방지

### UI
- 캐릭터 상세 화면에 스크롤 가능한 세팅 저장 미리보기 다이얼로그 연결
- 프로필, 조회 시각, 계열 통칭, 감지 역할, 룬 및 분석 경고 표시
- 지원 직업 저장 역할 선택 제공
- 감지 역할과 선택 역할 불일치 또는 자동 감지 실패 안내
- 불일치 상태에서도 특수 세팅 저장 허용
- 취소 시 무저장, 승인 성공 후 저장 스냅샷 화면 갱신

### 검증
- ViewModel의 조회, 취소, 역할 선택 commit, 실패 유지 및 중복 방지 테스트 추가
- Widget의 좁은 화면 스크롤, 분석 표시, 불일치 안내, 취소 및 승인 테스트 추가
- 관련 ViewModel 및 Widget 테스트 9개 통과
- `flutter analyze` 통과
- `flutter test` 102개 통과

### Galaxy Z Fold6 실기기 검증
- profile 빌드 설치 및 실행 완료
- 기존 역할별 저장 세팅 표시 정상
- 세팅 갱신 후 즉시 저장되지 않고 미리보기 팝업 표시
- 프로필, 계열, 감지 역할, 룬 및 경고 표시 정상
- 접힌 화면과 펼친 화면에서 미리보기 배치와 스크롤 정상
- 역할 불일치 안내와 불일치 상태 저장 정상
- 취소 시 기존 데이터 유지, 승인 시 선택 역할만 갱신, 반대 역할 유지 확인
- 캐릭터 컬렉션 카드 크기는 이번 범위에서 변경하지 않아 기존 크기 유지

### 실기기에서 확인한 후속 문제
- 서포터 바드의 세레나데 보석은 용맹과 구원의 세레나데를 함께 강화하는 정상 필수 보석이지만 단순 스킬명 일치로는 미확인 경고가 발생할 수 있음
- 직업 또는 보석명을 분석 코드에 직접 하드코딩하지 않음
- 카탈로그에 보석 대상 별칭 또는 복합 효과 그룹과 관련 특수 스킬 ID를 데이터로 정의하는 후속 작업으로 처리

---

## Task-019. 카탈로그 기반 보석 대상 분류

### 카탈로그 구조
- 직업별 API 보석 대상 표시명과 관련 특수 스킬 ID를 연결하는 `gemSkillTargets` 추가
- 복합 대상 ID, 표시명, 별칭 및 하나 이상의 특수 스킬 참조 지원
- 빈 관련 스킬 목록과 같은 직업에 없는 특수 스킬 참조 검증
- 번들 카탈로그 스키마 버전 2 적용
- 바드 `세레나데 스킬`을 용맹/구원의 세레나데 복합 대상으로 등록

### 분석
- 실제 장착 스킬은 계속 `normal`로 분류
- 현재 직업의 특수 스킬 이름/별칭과 복합 보석 대상 이름/별칭을 `passiveOrIdentity` 근거로 사용
- API 아크패시브 아이콘 근거 유지
- 어느 근거에도 없는 대상만 `unknown` 경고 생성
- 직업별 문자열 조건문 없이 공통 분석기로 처리

### 검증
- 단일 특수 스킬, 바드 복합 세레나데 대상 및 실제 미확인 대상 테스트 추가
- 카탈로그 참조 무결성과 번들 데이터 로딩 테스트 추가
- 관련 카탈로그, 분석기 및 Repository 테스트 27개 통과
- `flutter analyze` 통과
- `flutter test` 106개 통과

### Galaxy Z Fold6 실기기 검증
- 실제 서포터 바드 세팅의 `세레나데 스킬` 보석 재조회
- 기존 미확인 대상 경고가 사라진 것을 확인
- 보석 목록에서 아이덴티티/아크패시브 대상으로 정상 표시 확인
- 발키리 서포터의 `신앙 스킬`도 같은 유형의 직업별 카탈로그 입력 대상으로 기록

---

## Task-020. 서버 기반 파티 모집 및 계정 그룹 아키텍처

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0308)로 이동했다.

## Task-021. 로컬 우선 파티 모집 구현 순서 명문화

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0309)로 이동했다.

## Task-022. 레이드 정적 카탈로그 기반 구현

### 구현
- `shared/raid_catalog`에 레이드 카탈로그 Domain, JSON Mapper, asset DataSource 및 Repository 추가
- 카탈로그 버전/갱신 시각과 레이드·난이도 기준정보 모델 정의
- 모집글 경계를 위한 카탈로그 버전, 레이드 ID, 난이도 ID 및 선택 관문 참조 모델 추가
- Git 버전 관리용 최소 샘플 JSON asset 추가
- 기존 `raid_master` 정적 목록과 모집 UI는 실제 데이터 전환 전까지 유지

### 검증
- 중복 ID, 필수값, 정원/관문/표시 순서/레벨/보상 범위 검증
- 카탈로그 버전 불일치, 비활성 레이드/난이도, 다른 레이드 난이도 및 관문 범위 검증
- 신규 카탈로그 테스트 9개 통과
- `flutter analyze` 통과
- `flutter test` 115개 통과
- UI와 런타임 연결 변경이 없어 실기기 검증 생략

### 다음 작업
- 신뢰 가능한 기준으로 실제 레이드 데이터를 확인하고 카탈로그에 입력
- 실제 데이터 입력 후 기존 `raid_master`와 목 모집글을 새 카탈로그 참조로 전환

---

## Task-023. 실제 레이드 데이터와 파티 편성 기준 입력

### 카탈로그
- 사용자 인게임 확인 기준 5개 레이드와 13개 난이도 입력
- 정식 이름, 상위 필터명, 레이드 별칭과 난이도 표시 별칭 추가
- 일반 골드와 캐릭터 귀속 골드를 별도 필드로 분리
- 4인/8인 구성에 맞춰 파티 수, 필수 서포터 수와 동일 딜러 직업 최대 수 정의

### 연결
- 기존 Dart 정적 레이드 목록 제거
- 기존 `RaidMasterRepository`를 검증된 JSON 카탈로그 호환 Adapter로 전환
- 6개 목 모집글을 카탈로그 버전·레이드 ID·난이도 ID 참조로 변경
- 모집 카드에 `레이드 - 난이도 (별칭)` 표시 추가

### 파티 규칙 경계
- 동일 딜러 직업 제한은 4인 파티 단위로 적용
- 딜러와 서포터가 같은 직업인 경우는 허용
- 실제 가입 판정과 8인 레이드의 양 파티 배치는 후속 모집 상태 머신에서 구현

### 검증
- 카탈로그/목 모집/호환 Repository/카드 표시 대상 테스트 21개 통과
- `flutter analyze` 통과
- `flutter test` 116개 통과
- Galaxy Z Fold6에서 5개 레이드의 `레이드 - 난이도 (별칭)` 표시 확인
- 4인 모집의 딜러 3/서포터 1, 8인 모집의 딜러 6/서포터 2 목표 표시 확인

---

## Task-024. 파티 모집 카드 한글 표기 정리

- 화면 제목, 모집 상태, 리더, 멤버, 딜러 및 서포터 표기를 한글화
- 숙련도 5단계를 `트라이 / 클경 / 다클경 / 반숙 / 숙련`으로 표시
- 시간 제한이 없을 때 기존 문서 의미에 따라 `클리어 시까지`로 표시
- 시간 제한이 있으면 `최대 시간 N시간`으로 표시
- `flutter analyze` 통과, `flutter test` 117개 통과
- Galaxy Z Fold6에서 한글 제목·상태·역할·숙련도·시간 표기와 줄바꿈 확인

---

## Task-025. 앱 공통 숫자 천 단위 표기

- 공용 `DisplayNumberFormatter` 추가
- 아이템 레벨과 전투력의 소수점 두 자리 형식을 유지하면서 천 단위 쉼표 적용
- 모집 카드의 최소 전투력에 천 단위 쉼표 적용
- 인원, 관문, 시간처럼 작은 정수도 같은 정수 포맷 규칙 사용 가능
- `flutter analyze` 통과, 대상 테스트 8개 및 전체 `flutter test` 119개 통과
- Galaxy Z Fold6에서 계정 아이템 레벨·전투력과 모집 최소 전투력의 쉼표 표기 및 카드 레이아웃 확인

---

## Task-026. 모집 조건·파티 배치·가입 승인 정책 Domain

- 레이드 카탈로그의 전체 정원, 파티 수, 서포터 수와 동일 딜러 직업 한도를 파티별 모집 규칙으로 변환
- 4인/8인 레이드의 역할별 자리와 파티별 배치를 탐색하는 순수 Domain 정책 추가
- 동일 파티의 동일 직업 딜러 중복은 거절하고 딜러·서포터 교차 역할은 허용
- 8인 레이드는 동일 직업 딜러 2명을 서로 다른 파티에 배치하고 3명째는 거절
- 파티장 전용, 파티원 1명, 정족수 승인 정책을 상태 머신에서 사용할 값 객체로 정의
- 대상 테스트 13개와 전체 `flutter test` 132개 통과, `flutter analyze` 통과
- UI와 런타임 연결 변경이 없는 순수 Domain 작업이므로 실기기 검증 생략

---

## Task-027. 신청·투표·가입 상태 머신

- 신청의 `pending / approved / rejected / withdrawn` 상태와 투표 Domain 모델 추가
- 모집 중 신청, 사용자별 중복 신청, 현재 파티원 및 역할별 자리 검증 구현
- 파티장 전용, 파티원 1명 및 정족수 정책별 투표 권한과 승인 조건 구현
- 중복 투표를 차단하고 현재 파티원에게서 나온 유효한 표만 정족수에 포함
- 승인 직전 최신 파티 구성을 재검증하고 신청 승인·멤버 추가·역할별 인원·모집 마감을 단일 결과로 변경
- 정원 경쟁으로 가입이 불가능하면 새 투표도 반영하지 않는 원자적 실패 처리
- 거절 및 신청자 본인의 철회와 완료 신청 재처리 차단 구현
- 상태 머신 대상 테스트 13개와 전체 `flutter test` 145개 통과
- UI와 런타임 연결 변경이 없는 순수 Domain 작업이므로 실기기 검증 생략

---

## Task-028. 로컬 다중 사용자 모집 환경

- 현재 사용자를 전환할 수 있는 `FakeUserSession` 추가
- 고정·이동 가능한 Fake Clock과 순차 Fake ID 생성기로 테스트 재현성 확보
- 상태 Aggregate, 공개 모집 요약 읽기 모델 및 별도 Repository 계약 추가
- revision 비교 후에만 저장하는 메모리 Fake Repository 구현
- 모집 생성·신청·철회·투표 명령을 상태 머신과 현재 사용자 세션에 연결
- 성공한 명령만 revision과 갱신 시각을 변경하고 Domain 실패는 저장 상태를 보존
- A 모집 생성 → C 가입 → B 신청 → C 승인 시나리오와 저장 충돌 검증
- 신규 대상 테스트 8개와 전체 `flutter test` 153개 통과
- UI와 런타임 연결 변경이 없는 로컬 기반 작업이므로 실기기 검증 생략

---

## Task-029. 로컬 모집 목록·상세·생성 UI

- 기존 카드 목데이터 목록을 공유 메모리 Aggregate의 공개 모집 읽기 모델로 전환
- 빈 목록 안내와 모집 만들기 진입 버튼 추가
- 대표 캐릭터를 파티장으로 사용하는 모집 생성 화면 구현
- 레이드·난이도, 파티장 역할, 최소 전투력, 숙련도, 최대 시간과 세 승인 정책 입력 지원
- 모집 Aggregate에 카탈로그 참조와 화면 표시용 모집 조건 Metadata 추가
- 모집 상세에서 레이드·조건·승인 방식과 4인/8인 파티별 현재 구성 표시
- 저장소 변경 알림을 구독해 생성과 후속 상태 변경을 목록에 즉시 반영
- 좁은 화면 입력 검증·생성·상세 Widget 테스트와 전체 `flutter test` 154개 통과
- `flutter analyze` 통과
- Galaxy Z Fold6에서 빈 목록, 전체 생성 폼, 상세 1/2파티 구성과 목록 복귀 자동 갱신 확인

---

## Task-030. `내 파티` 화면 및 Firebase 이전 작업 순서 문서화

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0310)로 이동했다.

## Task-031. 주간 레이드 완료와 승인 후 캐릭터 교체 규칙 문서화

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0311)로 이동했다.

## Task-032. 주간 레이드 귀속과 로컬 신청·철회 UI

- KST 매주 수요일 오전 6시 기준 주차 계산 정책과 경계 테스트 추가
- 캐릭터·레이드·주차 단위의 난이도 공유 귀속 Repository/Fake 구현
- 신청 명령에서 같은 주차 동일 레이드 완료 캐릭터를 저장 변경 없이 차단
- 모집 Metadata에 카탈로그 입장 레벨을 보존하고 최소 전투력·클리어 경험을 nullable 선택 조건으로 변경
- 저장된 역할별 세팅을 기준으로 입장 레벨, 전투력, 주간 귀속, 역할 자리와 동일 딜러 직업 조건을 후보별 판정
- 모집 상세에 지원 후보 Bottom Sheet, pending 상태 및 본인 신청 철회 UI 구현
- 검증 가능한 계정 데이터가 없는 클리어 경험은 조건을 표시하고 신청자 직접 확인 대상으로 안내
- 로컬 타 사용자 4막 노말 목 모집을 초기 목록에 추가해 앱에서 신청 흐름에 진입 가능하도록 구성
- `flutter analyze` 통과, 전체 `flutter test` 161개 통과
- Galaxy Z Fold6에서 목 모집, 제한 없음 표기, 저장 역할 후보, 신청 대기, 철회와 지원 버튼 복귀 확인

---

## Task-033. 신규 모집 가입 정책 단순화

- 신규 모집 가입 방식을 `파티장 승인 / 승인 없이 바로 가입` 두 가지로 확정
- 생성 화면에서 파티원 승인과 정족수 승인 및 정족수 입력 UI 숨김
- 즉시 가입 정책은 신청 조건과 파티 구성을 검증한 뒤 pending 없이 승인 상태와 파티원 배치를 함께 반영
- 파티원 승인과 정족수 정책은 기존 Domain 및 저장 데이터 호환을 위해 내부에 유지
- 다음 작업의 선행 정족수 정책 결정을 제거하고 파티장 승인·거절 UI로 범위 축소
- `flutter analyze` 통과, 전체 `flutter test` 163개 통과
- Galaxy Z Fold6에서 두 가입 방식만 노출, 즉시 가입 선택 및 정족수 입력 미표시 확인

---

## Task-034. 모집 생성 파티장 캐릭터 및 역할 선택

- 본계정·부계정 전체 표시 캐릭터에서 모집 파티장을 선택하고 저장된 역할을 생성 명령에 반영
- 후보별 아이템 레벨, 역할 전투력, 참가 상태와 차단 사유를 표시하고 동일 레이드 pending은 확인 후 종료
- dealer/support 복수 역할 캐릭터의 선호 포지션 저장 및 한 행 역할 전환 UI 구현
- 파티 내 캐릭터 변경에서 동일 캐릭터의 반대 역할로 직접 변경 가능하도록 수정
- 모집 삭제 시 확정 점유 해제, 종료된 신청 뒤 다른 캐릭터 재신청 흐름 보완
- 일정 확인 기능은 기획 확정 전까지 Domain을 유지하고 앱 UI와 런타임 차단에서 숨김
- 세부 후속 개선 항목을 `DETAIL_IMPROVEMENTS.md`에 분리 기록
- 관련 실기기 테스트 통과
- `flutter analyze` 통과, 전체 `flutter test` 201개 통과
# Task-Account-Management. 본계정·부계정 등록 및 관리

- 작업 브랜치: `codex/account-management`
- 기존 Drift 다계정 스키마를 유지하면서 부계정 스냅샷 추가 저장 흐름 구현
- 계정 캐릭터 중복을 기준으로 동일 게임 계정 재등록 방지
- 본계정 승격 시 기존 본계정을 부계정으로 원자 전환하여 본계정 유일성 보장
- 내 계정 화면에 전체 계정 목록, 본계정/부계정 표시, 추가·표시명 수정·본계정 전환 UI 추가
- 각 계정에서 기존 대표 캐릭터 및 표시 캐릭터 관리 화면으로 이동하도록 라우팅 확장
- 데이터 계층의 계정 생성·중복·본계정 전환 규칙 테스트 추가
- `flutter analyze` 통과, 전체 `flutter test` 209개 통과
- 실제 API와 화면 크기별 실기기 검증은 `NEXT_WORK.md` 체크리스트로 이관
- 부계정 등록 다이얼로그의 입력 컨트롤러를 다이얼로그 State가 소유하도록 수정해 닫힘 애니메이션 중 조기 dispose로 발생하던 Flutter 위젯 트리 assertion을 해결
- 부계정 등록부터 다이얼로그 종료 및 목록 갱신까지 재현하는 위젯 회귀 테스트 추가
- 사용자 실기기 체크리스트 전체 통과
- 부계정 삭제 버튼과 확인 다이얼로그 추가; 저장 세팅, 캐릭터, 계정 순서의 명시적 연쇄 삭제 구현
- 빈 계정 표시명은 사용 가능한 `부계정N`으로 자동 지정하고 사용자 지정 표시명 중복은 거부

---

## Task-035. 아이템 레벨 기반 레이드 선택 및 모집 수정 기반

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0312)로 이동했다.

## Task-036. 전투력 표시와 자동 모집 제목

- 모집 생성, 지원 및 파티 내 캐릭터 변경 후보의 아이템 레벨·전투력 표시 모델 통일
- 큰 숫자의 소수점을 버리고 천 단위 쉼표를 적용하는 공용 포매터 연결
- 최소 전투력 빈 값과 `0`을 제한 없음으로 정규화
- 난이도 별칭, 숙련도와 최소 전투력을 조합한 자동 모집 제목 구현
- 수동 제목 보존과 빈 제목 저장 시 자동 제목 적용 규칙 구현
- 관련 자동 테스트와 정적 분석 통과 후 `main` 병합 및 원격 푸시 완료

---

## Task-037. 전체 모집 수정과 공통 텍스트 입력 UX

- 모집 생성·수정 공용 Draft와 폼 구현
- 제목, 레이드, 난이도, 숙련도, 최소 전투력과 가입 승인 방식 전체 수정 지원
- 제목, 모집 Metadata와 가입 승인 정책을 revision 기반 통합 명령으로 저장
- 파티장, 확정 파티원과 pending 신청자의 변경 영향을 저장 전에 표시
- 수정 화면에도 파티장 아이템 레벨 기반 레이드·난이도 필터 적용
- 편집 중 빈 제목을 유지하고 빈 상태로 저장할 때만 자동 제목 적용
- 값이 있는 단일행 텍스트·숫자 입력에 공통 전체 지우기(X) 동작 적용
- 관련 자동 검증과 Android 실기기 검증 통과
- 기능 커밋 `e8293e0`, 병합 커밋 `414b301`으로 `main` 및 `origin/main` 반영 완료

---

## Task-038. 대형 재설계 기준 상태 준비

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0313)로 이동했다.

## Task-039. Firebase 초기 연결 기준 상태 준비

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0314)로 이동했다.

## Task-040. Firebase 단계적 구현 전환 문서 정리

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0315)로 이동했다.

## Task-041. Firebase Core 앱 부트스트랩

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0316)로 이동했다.

## Task-042. Firebase Anonymous Auth 부트스트랩

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0317)로 이동했다.

## Task-043. Firebase Player binding

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0318)로 이동했다.

## Task-044. 게임 계정·캐릭터 식별자와 로컬 소유 인증

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0319)로 이동했다.

## Task-045. 앱 셸 정보 구조 복원 및 확정

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0320)로 이동했다.

## Task-046. 4탭 앱 셸과 설정 진입 구조

- 작업 브랜치: `codex/app-shell-navigation`
- StatefulShellRoute를 `레이드 현황 / 내 계정 / 레이드 모집 / 설정` 4개 branch로 확장했다.
- 레이드 현황에 `진행 중 / 신청 중 / 완료 기록` TabBarView와 읽기 모델 없는 최소 빈 상태를 추가했다.
- 하단 branch를 IndexedStack으로 구성해 탭별 Navigator 상태를 보존하고 레이드 현황 상단 스와이프와 충돌하지 않게 했다.
- 설정 탭에 기존 게임계정 인증과 API 토큰 화면의 진입점을 추가했고 내 계정의 상태 기반 복구 진입점은 유지했다.
- 초기 탭, 4탭 이동, 상단 스와이프, branch 상태 보존, 설정 뒤로가기와 탭 재선택 루트 복귀를 Widget 테스트 6개로 검증했다.
- `flutter analyze` 통과, 전체 `flutter test` 252개 통과.
- Android 실기기 확인을 사용자가 완료했다.
- API 토큰 삭제 전에 계정 데이터 조회·게임계정 인증 등이 정상 작동하지 않음을 알리는 확인창을 추가했고, 취소·확정·삭제 후 미등록 상태를 Widget 테스트로 검증했다.
- 커밋 `84769f8`, 병합 커밋 `23af0b3`으로 기능 브랜치와 `main`에 반영하고 모두 원격 푸시했다.

---

## Task-047. Firestore 파티 읽기 모델 계약과 Repository 경계

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0321)로 이동했다.

## Task-048. Spark Firestore 파티 명령 계약

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0322)로 이동했다.

## Task-049. Firestore 파티 생성과 확정 참가 점유

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0323)로 이동했다.

## Task-050. Firestore 승인 대기 신청과 본인 철회

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0324)로 이동했다.

## Task-051. Firestore 즉시 가입과 신청 승인·거절

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0325)로 이동했다.

## Task-052. Firestore 확정 파티원 관리

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0326)로 이동했다.

## Task-053. Firestore 회차 수명주기

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0327)로 이동했다.

## Task-054. Player 이벤트와 로컬 히스토리

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0328)로 이동했다.

## Task-055. Codex·Cursor 역할 전환과 구현 인수인계 문서 정리

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0329)로 이동했다.

## Task-056. 실행 앱 Firebase 읽기·이벤트 동기화 전환 1단계

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0330)로 이동했다.

## Task-057. 레이드 현황 목록·완료 기록 UX와 읽기 규칙 보강

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0331)로 이동했다.

## Task-058. 레이드 현황 목록에서 읽기 전용 상세 진입

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0332)로 이동했다.

## Task-059. 모집 생성 명령의 실행 앱 Firestore 전환

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0333)로 이동했다.

## Task-060. 인증 캐릭터 최소 정보 자동 동기화

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0334)로 이동했다.

## Task-061. 신청·철회 명령의 실행 앱 Firestore 전환

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0335)로 이동했다.

## Task-062. LostParty Design System v1 기반과 대표 Card 시범 적용

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0336)로 이동했다.

## Task-063. 레이드 모집 공개 목록 Firestore 페이징 읽기 전환

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0337)로 이동했다.

## Task-064. 파티장·파티원 표시 누락 점검과 다음 작업 재정의

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0338)로 이동했다.

## Task-065. 파티장·파티원 읽기 모델과 목록·상세 UI 복구

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0339)로 이동했다.

## Task-066. 즉시 가입·승인·거절 실행 앱 연결

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0340)로 이동했다.

## Task-067. 파티 고정 슬롯 구성판과 최종 후속 채팅 요구사항 문서화

- 작업 브랜치: `codex/docs-party-slots-chat`
- 현재 membership의 `partyIndex`는 파티 번호만 나타내며 상세 UI가 이를 자리 번호 계산에 사용해 같은 파티 멤버가 모두 `1자리`로 표시되는 원인을 확인했다.
- `partyIndex`와 파티 내부 `slotIndex`를 분리하고 4인·8인 정원 전체의 점유·빈 슬롯을 Card/Cell 구성판으로 표시하는 방향을 확정했다.
- `1파티 1번`은 4인 파티장, 8인 파티장 겸 공대장 자리로 고정하고 캐릭터 변경은 자리를 유지하며 탈퇴·추방 후 자동 당김 배치를 하지 않는 원칙을 기록했다.
- 빈 슬롯은 우선 `현재 별도 참가 조건 없음`을 표시하고 향후 역할·직업군·시너지 요청 조건을 membership과 분리해 확장한다.
- 파티 상세 멤버 전용 최근 10개 텍스트 채팅은 모든 핵심 파티·슬롯·그룹 기능 이후 가장 마지막에 구현한다. 상세 화면에서만 `limit(10)` 실시간 구독하고 목록·다른 탭에서는 읽지 않는 최소 비용 원칙을 기록했다.
- 문서만 변경했으므로 Flutter 검증은 실행하지 않고 `git diff --check`와 문서 간 정합성 검토로 검증한다.

---

## Task-068. 고정 슬롯 쓰기·구성판·승인 점유 get (2026-08-26)

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0341)로 이동했다.

## Task-069. 파티 구성판 반응형 그룹 배치 (2026-08-26)

- 작업 브랜치: `cursor/party-composition-responsive-layout`
- Slot Card 2열을 제거하고 가용 폭 기준 **파티 그룹** 배치로 전환했다. 좁은 화면은 세로 1열, 넓은 화면은 1·2파티 좌우.
- 실기기에서 펼친 폴드가 미달하던 후보 `720dp`를 `600dp`로 조정했다.
- 넓은 8인에서 같은 자리 좌우 Slot Card 높이를 `IntrinsicHeight`로 맞췄다.
- 표적 위젯 테스트와 `flutter analyze` 통과. 바형·폴드 실기기 디자인 통과.
- 다음: 자기 참가 캐릭터 변경·탈퇴·추방 (`NEXT_WORK.md` Task-070).

---

## Task-070. 자기 참가 캐릭터 변경·탈퇴·추방 (2026-08-26)

- 작업 브랜치: `cursor/party-membership-commands`
- 현황 상세에 `changeCharacter` / `leave` / `kick`을 연결했다. 캐릭터 변경은 역할과 `(partyIndex, slotIndex)`를 유지한다.
- 탈퇴·추방 후 남은 멤버를 앞자리로 당기지 않는다. 다인 해산은 범위 밖이며 단독 모집 삭제만 1인일 때 유지한다.
- `PartyMemberDisplay`에 표시하지 않는 `playerId`·`characterId`를 두어 명령 대상 식별에 쓴다.
- BUG-001: 상세 `recruitmentId` 변경 시 State가 남는 문제를 `ValueKey`와 ViewModel `restart`/`didUpdateWidget`으로 수정했다. 정상 스텝 실기기 통과 후 종료 기록만 `BUG_REPORTS.md`에 남김.
- 표적 테스트·`flutter analyze` 통과. 실기기에서 변경·탈퇴·추방 통과.
- 다음: 완료·완료 취소·종료·해산 (`NEXT_WORK.md` Task-071).

---

## Task-071. 완료·완료 취소·종료·해산 (2026-08-26)

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0342)로 이동했다.

## Task-072. 파티 이벤트 기반 앱 내부 알림·FCM 확장 설계 (2026-08-26)

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0343)로 이동했다.

## Task-073. 앱 내부 알림 이벤트·로컬 UI (2026-08-27)

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0344)로 이동했다.

## Task-074. 개인 주간 레이드 Claim 계약 문서화 (2026-08-27)

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0345)로 이동했다.

## Task-075. 개인 주간 레이드 Claim 기반 A (2026-08-27)

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0346)로 이동했다.

## Task-076. 개인 주간 레이드 Claim 기반 B (2026-08-27)

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0347)로 이동했다.

## Task-077. 개인 주간 레이드 Claim 기반 C (2026-08-27)

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0348)로 이동했다.

## Task-078. 개인 주간 레이드 Claim 기반 D (2026-08-27)

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0349)로 이동했다.

## Task-079 사전 설계. 반복 파티 전체 완료 취소 확정 (2026-08-27)

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0350)로 이동했다.

## Task-079. 개인 주간 완료 Claim 기반 E (2026-08-27)

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0351)로 이동했다.

## Task-081. 내 계정 주간 레이드 표시 설정 (2026-08-28)

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0352)로 이동했다.

## Task-080. 개인 주간 완료 Claim 기반 F (2026-08-28)

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0353)로 이동했다.

## Task-082. 레이드 모집에서 내 모집 제외 (2026-08-28)

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0354)로 이동했다.

## Task-083. 운영자 계정 권한 기반 설계 (2026-08-28)

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0355)로 이동했다.

## Task-084 후속 설계. 대표 Character 서버 동기화 (2026-08-28)

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0356)로 이동했다.

## Task-084b. 대표 초회 보강과 사용자 변경 분리 (2026-08-29)

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0357)로 이동했다.

## Task-085. 수동 인증 요청과 운영자 1차 판정 (2026-08-29)

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0358)로 이동했다.

## Task-086. 기존 소유자 방어·자동 이전·강제 인증 (2026-08-29)

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0359)로 이동했다.

# 2026-08-30 그룹 제품 흐름 문서화

- 하단 4개 탭을 유지하며 설정 탭을 그룹 탭으로 교체하고, 설정은 내 계정 상단에서 진입하는 방향을 확정했다.
- 그룹 생성·대표 캐릭터·초대·가입 신청·초대코드 즉시 가입, 그룹장/일반 멤버 권한과 승계, 단일 그룹 레이드와 공개 범위 전환, 복수 그룹 목록 필터를 제품 문서에 정리했다.
- 기준 문서: [`../product/GROUP_PRODUCT_FLOW.md`](../product/GROUP_PRODUCT_FLOW.md)

---

## Task-11. 그룹 생성·가입 Firestore/Rules 계약 분리 (2026-08-31)

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0362)로 이동했다.

## Task-11. 그룹 생성·가입 구현과 부분 실기기 (2026-08-31)

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0363)로 이동했다.

## Task-11a. 그룹 멤버 목록·탈퇴·표시 Snapshot (2026-08-31)

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0364)로 이동했다.

## Task-11-R. Firestore Rules 복잡도 차단 (2026-08-31)

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0365)로 이동했다.

## Task-11·11a 1차 마무리와 재설계 대기 (2026-08-31)

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0366)로 이동했다.

## Rules 복잡도 개선 1차 (2026-08-31)

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0367)로 이동했다.

## Rules 추가 개선 시작점·실행 계획 기록 (2026-08-31)

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0368)로 이동했다.

# 2026-09-02 활동 Character와 레이드 현황 필터 계약

- 인증 원정대 전체와 LOSTPARTY에서 실제 사용하는 활동 Character를 분리하기로 확정했다. 활동 Character는 최소 1명이고 대표 Character를 반드시 포함하며, 기존 참가 Character 비활성화는 새 후보만 제한하고 membership·Claim·완료 기록을 유지한다.
- 진행 중 레이드 필터의 공개 조건, 레이드·난이도 조합, 그룹원·Character 계층 선택, 사용자 내부 OR·사용자 간 AND, 실시간 결과 개수와 20개 페이징 방어 계약을 확정했다.
- 그룹 전용 자격 상실 정리는 그룹장뿐 아니라 정상 참가 그룹원도 요청할 수 있고 서버가 요청자와 대상을 재검증하는 것으로 확정했다.
- 구현보다 설계를 먼저 고정했으며 Flutter 코드는 변경하지 않았다. 상세: [`../architecture/ACTIVITY_CHARACTER_AND_RAID_FILTER_CONTRACT.md`](../architecture/ACTIVITY_CHARACTER_AND_RAID_FILTER_CONTRACT.md).

---

# 2026-09-02 첫 릴리즈 전 Git 작업 방식 확정

- 첫 릴리즈 전 통합 기준 브랜치를 `dev`로 정했다.
- 모든 작업은 원격과 동기화한 최신 `dev`에서 작업 단위별 브랜치를 만들어 시작한다.
- 첫 릴리즈 전에는 PR을 사용하지 않고, 검증된 작업 브랜치를 `dev`에 직접 병합한 뒤 `origin/dev`에 푸시한다.
- `main`은 첫 릴리즈 준비 전까지 안정 기준선으로 유지하며, 릴리즈 시점의 반영 절차는 별도로 결정한다.

---

# 2026-09-03 활동 Character 실기기 확인과 후속 보완 범위

- Android 실기기에서 활동 Character 선택·저장과 선택 Character만 레이드 모집 생성 후보로 노출되는 흐름을 확인했다.
- 기존 Character 순서 변경·대표 Character 변경과 완료 처리 표시 체크가 정상 작동했고, 전체 활동 Character 흐름을 정상으로 판단했다.
- 그룹 정보에서 본인은 활동 Character만 보이지만 다른 그룹원은 인증 Character 전체가 보이는 문제를 확인했다.
- 코드 대조 결과 다른 Player의 owner-only `characterActivity`를 읽지 못해 인증 활성 Character 전체를 반환하는 현재 대체 경로가 원인이다. 활동 Character 최소 표시 Projection을 완성하는 후속 작업으로 분리했다.
- 레이드 현황 필터 후속 요구사항으로 초기화 버튼, `그룹 공개만` 상태의 조건부 참여 그룹원 UI, 긴 목록에서도 잡기 쉬운 상단 드래그 닫기 영역을 기록했다.
- 기존 자동 검증 결과 `flutter analyze --no-pub`와 전체 `flutter test --no-pub` 792개 통과는 유지한다. 이번 변경은 문서뿐이므로 Flutter 검증을 반복하지 않는다.

---
## 2026-09-04 Character 자동 갱신 D — 파티 교류 적용

- 모집 생성과 참가 신청·즉시 참가·참가 Character 변경 후보 로딩에 사전 갱신을 연결했다. 반복 파티 다음 회차 변경도 같은 경계를 쓴다.
- 명령 직전에 Character ID와 generation을 확인하고, 갱신 역할과 최소 아이템 레벨·전투력을 재검증해 payload를 다시 만든다.
- 실패 시 기존 정상 Snapshot이 있으면 사용자 확인 후 계속하고, 없으면 차단한다. 갱신과 명령은 기존 저장/제출 잠금 안에서 실행해 중복 명령을 막는다.
## 2026-09-04 Character 자동 갱신 E — 그룹 교류 적용

- 그룹 생성·가입 신청·초대코드 가입 후보에 본인 활동 Character 사전 갱신을 연결하고, 명령 직전에 선택 Character와 generation을 다시 확인한다.
- 직접 초대 수락은 초대 Snapshot의 본인 Character명과 로컬 인증 Character를 대조한 뒤 최신화를 보장한다. 일치하는 본인 Character가 없으면 수락을 차단한다.
- 그룹 상세 표시 보강 전에 본인 활동 Character만 갱신한다. 타 그룹원의 API는 조회하지 않고 기존 membership 읽기 계약을 유지한다.
- 나이스단 제외, API 실패 시 기존 정상 Snapshot 확인, 역할 변경 감지와 버튼 연타 방지는 파티와 동일한 사용자 경계를 사용한다.
## 2026-09-05 앱 실행 1회 갱신 상세 기준과 내 계정 UI 후속 범위(문서만)

- 앱 실행 갱신 대상은 인증된 active 계정의 등록 Character 중 원정대 이탈이 아니고 아이템 레벨 1700 이상인 Character로 확정했다. 1700은 나이스단과 앱 실행 갱신이 공유하는 공통 정책 값으로 두며 기능별로 중복 하드 코딩하지 않는다.
- 나이스단 분류·허용 설정은 현재 구조를 유지한다. 직업별 표기는 자동 테스트만으로 완료 처리하지 않고 다양한 실제 사용자 계정에서 캐릭터별 역할·아이템 레벨·전투력·보석 표시를 확인한다.
- 내 레이드 현황의 초기 Snapshot·기록·알림 로딩과 첫 렌더링 뒤 자동 갱신을 시작해 첫 화면 통신과 경쟁시키지 않는다. 앱 수명당 1회만 실행하고 내 계정 탭에 비차단 통신 인디케이터를 표시한다.
- 내 계정 첫 화면은 토큰 등록 안내/버튼과 게임계정 인증을 한 줄로 축소하고, Character명 입력과 계정 데이터 불러오기를 한 줄로 합친다. 부계정 추가는 작은 보조 액션으로 변경해 Character 현황의 첫 화면 점유율을 높인다.
- 이번 변경은 문서 최신화이며 기능 코드는 수정하지 않았다.
## 2026-09-05 앱 실행 1회 갱신 A — 공통 사용 레벨과 대상 정책

- 아이템 레벨 1700 포함 경계를 `CharacterUsageLevelPolicy` 한 곳으로 분리하고 기존 `NiceGroupPolicy`가 이를 사용하도록 변경했다.
- 앱 실행 갱신 후보용 `StartupCharacterRefreshEligibilityPolicy`를 추가했다. active 소유권 계정의 서버 인증·원정대 소속·1700 이상 등록 Character를 본·부계정 구분 없이 반환한다.
- 1699.99/1700 경계, null 레벨, 본·부계정 포함, 미인증·원정대 이탈·비활성 소유권 제외 테스트와 기존 나이스단·관리 화면 회귀 24개가 통과했다.
- 전체 `flutter test --no-pub` 878개가 통과했고 analyze에는 이번 변경의 신규 문제가 없다.
- 교류 시점 호출 제거, 앱 수명당 1회 조정기, 첫 화면 로딩 장벽과 UI는 후속 B~E 범위로 남겼다.
## 2026-09-05 앱 실행 1회 갱신 B — 기존 교류 갱신 안전 제거

- 모집 생성·지원·즉시 참가·참가 Character 변경 후보의 prefetch와 명령 직전 `ensureFresh`를 제거했다. 반복 파티 다음 회차 변경도 기존 membership 명령만 실행한다.
- 그룹 생성·가입 신청·직접 초대 수락·초대코드 가입·그룹 상세의 Armory 자동 갱신을 제거했다. 기존 Snapshot 계속 사용 확인 다이얼로그, 역할 변경 안내와 교류 전용 generation 상태도 삭제했다.
- 파티·그룹 전용 갱신 래퍼와 UI guard를 삭제하고 Router 주입을 제거했다. 공통 Coordinator, 나이스단 정책, 역할별 로컬 Snapshot과 서버 최소 Snapshot 동기화 구현은 C에서 재사용할 자산으로 보존했다.
- 모집 생성은 저장된 선택 역할 Snapshot으로 최소 아이템 레벨·전투력을 명령 직전에 다시 검사한다. 기존 인증·소유권·파티 구성·revision·중복 실행 방지는 유지했다.
- 교류·명령 표적 회귀 79개와 전체 `flutter test --no-pub` 877개가 통과했다. analyze에는 이번 변경의 신규 문제가 없다.

## 2026-09-05 앱 실행 1회 갱신 C — 앱 수명당 1회 조정기

- `StartupCharacterRefreshOrchestrator`를 추가했다. 동일 인스턴스의 `runOnce()`는 최초 Future를 계속 재사용하므로 중복 호출되어도 계정 로드와 Character 갱신은 앱 수명당 한 번만 실행된다.
- 인증 Player 세션이 있고 A 정책을 통과한 active 소유권·서버 인증·원정대 소속·1700 이상 본·부계정 Character만 대상으로 삼는다. 인증 세션이 없으면 로컬 계정과 설정도 읽지 않고 종료한다.
- 기존 `NiceGroupPolicy`와 Player별 로컬 허용 설정을 적용한다. 나이스단 OFF 요청은 Coordinator의 제외 경로로 전달해 Armory 통신 없이 기존 수동 Snapshot을 유지하고, ON이면 일반 prefetch를 실행한다.
- 기존 `CharacterAutoRefreshCoordinator`를 `CharacterAutoRefreshGateway` 계약으로 노출해 최대 동시 요청 3개, 역할 판별·역할별 Snapshot, 서버 최소 Snapshot 동기화 구현을 그대로 재사용한다.
- Character별 결과·예외를 독립 수집하고 실행 상태에 전체·완료·실패 수를 발행한다. 일부 실패나 계정 로드 실패는 호출자에게 던져 앱 진입을 막지 않으며 확인 팝업도 만들지 않는다.
- C 조정기·기존 Coordinator·대상·나이스단 정책 표적 테스트 22개와 전체 `flutter test` 884개가 통과했다. `flutter analyze`에는 이번 변경의 신규 문제가 없고 기존 21개 항목만 남아 있다.

## 2026-09-05 앱 실행 1회 갱신 D — 첫 화면 장벽과 내 계정 탭 인디케이터

- `RaidStatusPage`가 진행 중·신청 중 목록의 첫 Snapshot 성공 또는 오류, 완료 기록 초기화, 읽지 않은 알림 수 조회, 첫 프레임 렌더링을 모두 확인한 뒤 초기 로딩 완료 콜백을 한 번만 호출하도록 연결했다.
- 완료 기록이나 알림 수 조회가 실패해도 로그만 남기고 장벽은 최종 완료된다. 시작 Character 갱신은 이 콜백 뒤 비차단으로 실행되어 레이드 현황 로딩이나 앱 진입을 기다리게 하지 않는다.
- Router에서 C 조정기와 기존 Coordinator·서버 최소 Snapshot 동기화를 실제 런타임 의존성으로 조립했다. 같은 조정기 인스턴스를 레이드 장벽과 앱 셸이 공유하므로 탭 이동·재진입·수동 새로고침으로 재실행되지 않는다.
- 앱 셸은 조정기 상태를 구독해 실행 중에만 하단 두 번째 `내 계정` 탭 아이콘에 작은 원형 인디케이터를 표시한다. 완료와 일부 실패 모두에서 종료하며 팝업은 추가하지 않았다.
- 첫 Snapshot 성공·오류·콜백 1회, 인디케이터 시작·종료, C 실행 계약과 앱 내비게이션 표적 테스트 42개가 통과했다. 전체 `flutter test` 887개가 통과했고 `flutter analyze`에는 신규 문제가 없이 기존 21개 항목만 남아 있다.

## 2026-09-05 앱 실행 1회 갱신 E — 내 계정 첫 화면 UI 압축

- 기존 세로형 API 토큰 상태 패널과 전체 폭 게임계정 인증 버튼을 하나의 compact 행으로 합쳤다. API 토큰 등록 여부 안내, 등록/관리 버튼, 계정 인증 버튼이 같은 줄에 있으며 기존 설정 경로와 tooltip을 유지한다.
- Character명 입력과 계정 데이터 불러오기를 같은 행에 배치하고 버튼 문구를 `불러오기`로 줄였다. 계정이 있으면 `부계정 추가`는 같은 행의 작은 outlined 아이콘 버튼으로 표시한다.
- 상단 작업 영역의 큰 세로 간격과 전체 폭 버튼 3개를 제거해 저장된 계정·Character 현황이 더 위에서 시작하도록 했다. 조회 검증·네트워크 busy·토큰 누락·부계정 dialog 동작은 변경하지 않았다.
- 360px 모바일 폭에서 두 compact 행의 구성 요소와 오버플로 부재를 검증했다. 내 계정·ViewModel·앱 내비게이션 표적 테스트 20개와 전체 `flutter test` 888개가 통과했고 analyze에는 신규 문제 없이 기존 21개 항목만 남아 있다.

## 2026-09-05 앱 실행 1회 갱신 F — 자동 검증 완료, 실기기·실계정 대기

- 공통 레벨·대상·나이스단·Coordinator·시작 1회 조정기·레이드 장벽·인디케이터·내 계정 UI를 묶은 표적 테스트 86개와 전체 `flutter test` 888개가 통과했다. `flutter analyze`는 신규 문제 없이 기존 21개 항목만 보고한다.
- 정적 호출 대조에서 앱 코드의 `CharacterAutoRefreshCoordinator.ensureFresh` 호출은 제거된 상태이고, 자동 `prefetch` 호출은 `StartupCharacterRefreshOrchestrator` 한 곳에만 남아 있다. 파티·그룹 교류 화면 자동 갱신은 재연결되지 않았다.
- `adb devices -l` 결과 연결 기기가 없었다. `flutter devices`는 출력 없이 대기해 종료했고 `flutter build apk --debug`도 두 차례 실제 Java/Dart 빌드 프로세스와 출력 없이 대기해 성공·실패 판정을 하지 않았다.
- Android 실기기의 첫 화면 로딩·내 계정 탭 인디케이터·탭 이동/백그라운드 복귀 중복 실행 없음·압축 UI 확인과, 바드·홀리나이트·발키리·도화가를 포함한 여러 실제 사용자 계정의 역할·아이템 레벨·전투력·보석 표기 검증은 남아 있다. 자동 검증만으로 전체 완료 처리하지 않는다.

## 2026-09-05 후속 개선 H~K 계획 — 문서만 갱신

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0370)로 이동했다.

## 2026-09-05 H/I — 선호 역할 대표 전투력·수동 전체 갱신 완료

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0371)로 이동했다.

## 2026-09-05 실기기 갱신 전체 실패·그룹 생성 권한 오류 대응

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0372)로 이동했다.

## 2026-09-06 딜러 전용 직업 자동 갱신 역할 수정

- 실계정에서 딜러 전용 직업까지 카탈로그 역할 분기와 4티어 노드 탐지를 요구해 갱신을 차단하던 경계를 확인했다.
- 바드·홀리나이트·도화가·발키리만 복수 역할 탐지를 유지하고, 그 외 직업은 무조건 `dealer`로 저장하도록 공통 `CharacterBuildRolePolicy`를 추가했다.
- Character 상세 UI의 역할 선택 여부도 같은 정책을 사용하도록 중복 직업 목록을 제거했다.
- 딜러 전용 직업의 탐지 결과가 `unsupportedClass`이고 관련 4티어 노드가 없어도 dealer 갱신이 성공하는 회귀 테스트를 추가했다.
- 역할 정책·Coordinator·Character 상세 ViewModel 표적 테스트 22개와 전체 자동 회귀 899개가 통과했다. analyze는 신규 문제 없이 기존 21개 항목만 보고한다. 수정본 실기기 재검증은 계속 필요하다.

## 2026-09-06 그룹 생성 payload 하위 호환 복구

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0373)로 이동했다.

## 2026-09-06 실기기 Player/활동 Character 복구 진단

- 연결된 SM-F956N의 Drift DB를 개인정보 값 없이 집계했다. active 서버 계정 1개, 서버 ID가 있는 Character 18개, 원정대 이탈 0개로 로컬 인증 바인딩은 정상이다.
- 그룹·레이드 후보는 현재 Player의 `characterActivity`가 빈 집합이면 인증 Character를 모두 제외하고 있었다. 빈 선택은 저장 정책이 금지하므로 빈 집합을 미초기화로 판정해 기존 fallback을 사용하도록 수정했다.
- 로그에서 일반 사용자 화면의 `syncExpiredDisputes()`가 운영자 전용 전체 쿼리를 실행해 반복 `permission-denied` 미처리 예외를 발생시키는 것을 확인했다. 일반 요청/분쟁 watch의 호출을 제거하고 운영자 큐 경로만 유지했다.
- 운영자 권한은 기존 Player에 남아 있을 수 있으며 새 익명 Player로 자동 이전하지 않는다.
- 관련 표적 테스트 24개와 전체 자동 회귀 899개가 통과했다. 병렬 전체 회귀에서 변경된 기존 기대값 1건을 확인해 미초기화 fallback 기준으로 정정한 뒤 단독 전체 회귀 통과를 재확인했다. analyze 신규 문제는 없다.

## 2026-09-06 서버 연결 복구 선택지 계획 문서화

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0374)로 이동했다.

## 2026-09-06 로컬·서버 인증 불일치 대응 최소화

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0375)로 이동했다.

## 2026-09-06 로컬·서버 인증 불일치 안내 구현

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0376)로 이동했다.

## 2026-09-07 재인증·생성 연쇄 장애 문서 진단

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0377)로 이동했다.

## 2026-09-07 앱 데이터 초기화 복구 확인·서버 점검 기록

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0378)로 이동했다.

## 2026-09-07 서버 점검 시점 정정

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0379)로 이동했다.

## 2026-09-07 진행 중 레이드 카드 알림 배지 갱신 지연 기록

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0380)로 이동했다.

## 2026-09-08 실기기 통과 및 다음 세 항목 협의 전환

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0381)로 이동했다.

## 2026-09-08 서버 데이터 불일치 표시·재인증 복구 1차

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0382)로 이동했다.

## 2026-09-08 승인 완료 후 로컬 재연결 실패 원인 수정

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0383)로 이동했다.

## 2026-09-08 그룹 초대코드 생성 권한 회귀 대응

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0384)로 이동했다.

## 2026-09-10 주차 자동 보정·Rules 경고·그룹 해산 구간 완료

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0385)로 이동했다.

## 2026-09-10 동일 레이드 다른 난이도 신청 후보 회귀 수정

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0386)로 이동했다.

## 2026-09-10 기존 기능 회귀 방지 작업 원칙 강화

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0387)로 이동했다.

## 2026-09-10 신청 후보 동일 딜러 직업 구성 차단

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0388)로 이동했다.

## 2026-09-11 레이드 목록 내 Character 필터·참가 인원 정렬·남은 자리 필터

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0389)로 이동했다.

## 2026-09-11 그룹 membership 보석 검증 Snapshot 다음 작업 계획

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0390)로 이동했다.

## 2026-09-12 파티 Build 오류 누락 후속 작업 계획

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0391)로 이동했다.

# 2026-09-12 세 직업 특수 보석 대상 등록

- 사용자 확인값에 따라 환수사 `야성` → `둔갑 금술 스킬`, 가디언나이트 `드레드 로어` → `가디언 피어`, 데모닉 `멈출 수 없는 충동` → `블러드 제노사이드`를 카탈로그 `2026.09.12`에 등록했다.
- 기존에 세 대상을 미등록 오류 표본으로 사용하던 mapper·진단 도구 테스트를 분기 감지 및 정상 판정 회귀로 전환했다. 세 직업의 다른 분기·스킬은 추정 등록하지 않았고, 분기 미탐지 fallback과 미등록·타 직업·정보 부족 판정은 변경하지 않았다.

# 2026-09-12 차원술사 특수 보석 대상 등록


# 2026-09-12 108개 실계정 표본 기반 Build 카탈로그 확장

- 사용자가 제공한 27직업·Build별 2명, 총 108캐릭터의 종합 Armory 응답을 진단 도구로 조회했다. 원본은 `lost_party_api_probe_830c605b` OS 임시 폴더에만 저장하고 Git에는 포함하지 않았다.
- 실제 `ArkPassive.Effects`의 깨달음 1티어를 기준으로 기존 8직업 카탈로그를 30직업으로 확장했다. 사용자 목록의 구 직업각인명과 현재 API 노드명이 다른 경우 API 실측값을 사용했다.
- `ArmorySkills.Name`에 없고 보석 Tooltip 직업이 현재 직업과 일치한 대상만 분기별 특수 보석으로 등록했다. 108개 원본을 다시 대조해 미등록 같은 직업 대상, 미등록 분기, 타 직업 대상의 오등록이 모두 0건임을 확인했다.
- 인파이터 `이비쥬`의 브레이커 보석 4개와 데빌헌터 `반짝이는레몬버터`의 바드 `천상의 연주`는 카탈로그에서 제외하고 실제 `foreignClass` 오류 회귀 테스트로 고정했다.

# 2026-09-13 릴리즈 안정화 인증 안내·파티 통합 오류 전파 구현

- 장비 인증 Challenge가 앱 프로세스 메모리에만 유지되는 현재 정책을 화면에 명시했다. 앱 종료 시 남은 시간과 관계없이 시도가 종료된다는 안내와 인게임 장비를 즉시 조작할 수 있을 때 진행하라는 권장을 challenge 카드에 추가했다.
- 무기와 방어구 5부위 중 하나라도 미착용된 시작 실패를 일반 응답 형식 오류와 분리했다. Gateway는 typed `incompleteEquipment` 오류를 반환하고 화면은 완전 착용 후 재시도하라는 전용 문구를 표시한다. 무작위 부위·10분 만료·같은 프로세스 재진입·성공 binding은 변경하지 않았다.
- 후보 역할 옵션의 `BuildIntegritySnapshot`을 파티 생성 리더, 신청·재신청, 직접 참가, 신청 승인과 참가 Character 변경 명령까지 운반한다. 신청은 `submittedBuildSnapshot.buildIntegritySnapshot`, membership은 최상위 `buildIntegritySnapshot`에 저장한다. 승인은 신청 당시 Snapshot을 재사용하며 직접 참가·생성·변경은 선택 당시 로컬 값을 사용한다.
- 신청자와 배정/미배정 구성원 카드는 통합 Snapshot의 보석·아크그리드 복합 오류를 표시한다. 과거·손상·미지원 schema는 통합 정보만 `null`로 낮추고 기존 `gemValidationSnapshot` 표시와 카드·명령을 보존한다. 오류는 참가를 차단하지 않는다.
- 전체 `flutter analyze`는 새 오류 없이 완료됐고 기존 스타일 info 37건과 변경하지 않은 테스트 경고 1건을 보고했다. 포맷과 `git diff --check`를 수행했다.
- 새로 가능해진 흐름: 인증 전 장비 준비·앱 종료 정책 인지, 신청 전 후보와 신청자 카드 및 참가 후 파티원 카드의 보석·아크그리드 오류 의미 일치.
- 보존 확인한 흐름: 완전 장착 인증 시작, 손상 응답 일반 안내, 파티 생성·신청·철회·재신청·직접 참가·승인·거절·Character/역할 변경, 파티 구성/주차·Claim과 그룹 연결 화면.

# 2026-09-13 릴리즈 안정화 실기기 완료와 공격대 자리 조정 설계

- 사용자가 인증 진행 안내, 장비 미착용 전용 문구와 신청·참가 이후 통합 Build 오류 지속 표시를 실기기에서 확인했다. BUG-014~016을 완료 상태로 닫았다.
- 새로 확인한 8인 Character 변경 문제는 직업 규칙 자체가 아니라 기존 `failureForInPlaceReplacement()`가 현재 파티만 검사하는 데서 발생한다. 신규 참가의 다른 파티 배치 정책은 정상이며 변경 흐름만 확장한다.
- 다음 작업은 제자리 → 다른 파티 유효 빈자리 → 한 명과의 단순 교환 가능성 순서로 배치 계획을 계산한다. 빈자리는 대상만 자동 이동하고, 빈자리 없이 교환 가능하면 Character 변경만 허용한 뒤 파란 구성 안내를 표시한다. 전체 공대 자동 재배치는 하지 않는다.
- 딜러/서포터 형태는 다른 구성 직업, 같은 역할의 깨달음 분기는 같은 구성 직업으로 확정했다. 16인·연쇄 교환·시너지 자동 추천은 현재 제외한다.

# 2026-09-14 공격대 자리 조정 Rules 단순화와 1차 실기기 확인

- 신규 모집은 `slotLedgerVersion: 2`와 `playerId`, `partyIndex`, `slotIndex`, `updatedAt`만 가진 슬롯 Claim을 사용한다. 버전이 없거나 실험 단계의 버전 1인 과거 모집은 기존 조회·완료·탈퇴를 유지하되 자동 이동과 자리 조정만 지원하지 않는다.
- 후속 실기기에서 점유된 두 자리의 인원 교환이 정상 작동하고, 같은 파티에 동일 구성 직업이 생기는 교환은 저장되지 않고 안내가 표시되는 것을 확인했다.
- 그룹 생성·그룹장 이전·일반 그룹원 탈퇴·마지막 1인 그룹 해산과 파티 탈퇴 후 재신청도 정상 작동했다.
- Character 변경 자동 이동·파란 안내 제거, 그룹 listing, 추방·완료와 `memberMoved` 알림은 아직 별도 실기기 결과가 없으므로 전체 기능 완료로 닫지 않는다.

# 2026-09-14 BUG-018 다인 모집 해산 권한 회귀 수정

- 기존 `validRecruitmentDisband`, 리더·revision·assignment·listing·이벤트 수신자 검증은 완화하지 않았다.

# 2026-09-14 파티 원자 탈퇴·승계와 그룹 활성 모집 집계 계획

- 기존 `memberPlayerIds`와 신규 Aggregate `partySlots`의 생성·가입 순서가 동일함을 확인하고, 파티장 탈퇴 시 탈퇴자를 제외한 첫 번째 잔류 Player를 후임으로 삼는 기존 제품 정책을 유지했다.
- 일반 탈퇴·추방은 모집 Aggregate, 대상 membership 삭제, 대상 `raidState` 삭제와 공용 이벤트 한 건만 쓰도록 계획했다. 파티장 탈퇴만 후임 membership 한 건을 추가 갱신하며 최대 쓰기는 5건이다.
- 마지막 한 명의 탈퇴는 일반 제거 계획에서 거절하고 기존 원자 해산 명령으로 분리해 모집 종료와 점유 해제가 갈라지지 않게 했다. 그룹 자격 여부는 직접 대상 문서에서 확인한 boolean으로 `nonGroupMemberCount`만 고정 크기로 조정한다.
- 그룹 원본 `activeRecruitmentCount`의 생성·종료 증감과 0일 때만 해산하는 검증 계획을 추가했다. 연결 모집 최대 20개 순회는 신규 구조에서 사용하지 않는다.

# 2026-09-14 그룹 자격 집계 Snapshot과 공개 범위 전환 계획

- 참가·신청 이후 그룹 탈퇴 여부를 현재 시점에서 다시 조회해 과거 집계를 감소시키면 값이 어긋나는 위험을 확인했다. 슬롯에는 `countedAsNonGroupMember`, 신청에는 `countedAsNonGroupApplicant`를 생성 당시 고정해 제거·철회·승인이 동일한 집계를 정확히 되돌리도록 보완했다.
- Aggregate 생성자는 슬롯 Snapshot 합과 `nonGroupMemberCount`가 다르면 거절한다. 캐릭터 변경과 자리 이동·교환은 이 Snapshot을 그대로 보존한다.
- 공개→그룹 전환은 `nonGroupMemberCount`와 `pendingNonGroupApplicantCount`가 모두 0인지 확인하고, 그룹→공개 전환은 listing 삭제와 그룹 `activeRecruitmentCount` 감소를 같은 계획으로 묶었다. 멤버·신청 전체 순회는 사용하지 않는다.

# 2026-09-14 그룹 모집 완료 수명주기 Repository 보완

- 그룹 전용 1회성 모집 완료가 `activeRecruitmentCount`를 유지하고 listing만 completed로 갱신하던 비연결 Repository 계약 오류를 발견했다. 완료 순간 활성 수를 감소시키고 listing을 삭제하도록 수정했다.
- 활성 상태 해산도 같은 종료 경로를 사용하고, 이미 1회성 완료로 집계가 닫힌 뒤 실행하는 마무리 해산은 그룹 수와 listing을 다시 변경하지 않는다. 반복 모집의 회차 완료·취소·전환은 활성 수와 listing을 유지한다.

# 2026-09-15 파티 원자 탈퇴·추방 Firestore Repository

- 새 Aggregate 전용 탈퇴·추방 Repository와 Domain 인터페이스를 추가했다. 한 Transaction에서 인증 binding, 모집 원본, 대상 membership·`raidState`, 필요 시 후임 membership만 직접 읽고 모집·대상 삭제·후임 권한·그룹 listing·공용 이벤트를 갱신한다.
- 그룹 자격 상실 정리는 실행자가 현재 파티원 및 그룹원이고 대상이 현재 그룹원이 아닌 경우만 허용한다. 대상이 파티장이면 기존 구현의 누락과 달리 가입 순서 후임의 승인 권한도 함께 승계한다.
- 일반 제거는 공용 모집에서 최대 4건, 그룹 listing 포함 최대 5건이며 파티장 승계는 각각 최대 5·6건이다. 전원 membership 조회, 별도 slot, 기존 assignment·Claim과 Player별 event fan-out은 사용하지 않는다.

# 2026-09-16 F1 그룹 쓰기 복구 자동 검증·운영 Rules 게시

- 그룹장 이전은 그룹 1건과 membership 2건, 일반 탈퇴·1인 해산은 그룹·본인 membership·membership state·relation의 고정 문서만 쓰는 구조를 유지했다. 파티 인원·그룹원·`raidListings` 수에 따른 fan-out으로 되돌리지 않았다.
- `validGroupDisbandUpdate`에 `activeRecruitmentCount` 정수·0 조건을 추가해 활성 그룹 모집이 있는 1인 그룹의 해산을 서버에서도 차단했다.
- 그룹장 이전에서 `groups` update OR와 membership update OR가 앞선 무관한 validator를 모두 평가해 표현식 1,000개 한도를 넘는 문제를 확인했다. 이전·role 변경 validator를 각 OR 앞쪽으로 옮겼으며 판정 조건과 쓰기 범위는 완화하지 않았다.
- 실기기 미확인: 그룹장 이전, 이전 그룹장 탈퇴, 일반 멤버 탈퇴, 마지막 1인 해산, 활성 모집 중 해산 차단 안내. 이 확인 전에는 F1을 완료로 닫거나 F2로 넘어가지 않는다.

# 2026-09-16 F1 후속 회귀 — 초대코드 가입

- 실기기에서 그룹 생성·초대 수락·검색 신청 수락·그룹장 이전·일반/기존 그룹장 탈퇴·1인 해산은 통과했고 초대코드 가입만 권한 안내로 실패했다.
- 코드 가입 검증을 OR 앞쪽에서 판정하도록 순서를 조정했다. 첫 수정은 기존 탈퇴 회귀가 실패하여 게시하지 않았고, 해산·그룹장 이전·탈퇴 우선순위를 보존한 최종 수정에서 `35075221872`의 코드 가입 및 F1 수명주기 Emulator가 모두 통과했다. Rule 허용 조건과 문서 쓰기 수는 완화·증가시키지 않았다.

# 2026-09-16 C* 기능 복구 F1 — 그룹 해산 차단 안내 실기기 확인

- 사용자가 1인 그룹의 활성 그룹 전용 모집이 있는 상태에서 그룹 해산이 차단되고 전용 안내가 표시됨을 실기기에서 확인했다. 앞서 확인한 그룹 생성·직접 초대·검색 가입·초대코드 가입·그룹장 이전·일반/기존 그룹장 탈퇴·1인 해산과 함께 F1 주요 흐름을 복구 판정한다.
- 무효·폐기 초대코드와 중복 가입의 이번 실기기 재검증은 최종 회귀에 남긴다. 다른 공대장이 소유한 그룹 전용방을 그룹장이 직접 정리하는 기능은 F4 범위이며 F1 완료로 간주하지 않는다.

# 2026-09-16 C* 기능 복구 F2-A — 신청 재진입 Rules 경계 진단


# 2026-09-18 F6-A 특정 캐릭터 권한 오류 진단 완료

- 승인 실패와 수동 완료 실패를 서로 다른 원인으로 분리했다. 전자는 삭제된 모집을 참조하는 `니티야`의 고아 `raidState`, 후자는 `이슈아이`의 수동 완료 사전 검사에서 해산된 그룹방의 접근 불가 pending 신청 부모를 읽는 코드 경로다. 정확한 ID와 근거는 `BUG_REPORTS.md` 2026-09-18 항목을 따른다.
- 다음 작업은 `NEXT_WORK.md` F6-B1의 조회 경계 최소 수정이다. 진단 로그와 문서 변경은 작업 브랜치에 미커밋이며, F6-B1 검증 후 로그 유지/제거를 결정한다.

# 2026-09-18 F6-B1 수동 완료 체크 표적 복구

- 사용자가 `이슈아이` 수동 완료 체크·해제, 완료 상태일 때 동일 레이드 모집의 캐릭터 선택 차단, 정상 pending 신청 1건의 취소 안내와 실제 지원 취소를 확인했다. 임시 단계 로그를 제거해 B1을 완료 판정한다. 주차 전환과 새 `raidState` 통합은 B2/F7에 남기며 전체 F6 완료로 확대 판정하지 않는다.
- 이후 실기기 설치·조작·테스트는 사용자가 수동 진행한다. 에이전트는 코드·자동 검증을 마친 뒤 확인 항목을 전달하고, 필요할 때만 구간 종료 후 로그 수집을 요청한다. 다음 작업은 `NEXT_WORK.md` F6-B2 상세 설계다.

# 2026-09-18 F6-B2 통합 완료 상태 상세 설계

- 운영 Router를 대조해 파티 전체 완료는 원자 lifecycle에서 `raidState active → completed`를 사용하지만 내 계정 표시·수동 완료는 구 `weeklyRaidClaims/activeRaidAssignments`만 사용한다는 전환 간극을 확정했다. 구 Cycle Repository의 Claim fan-out을 복원하지 않는다.
- 신규 완료·참가 원장은 `raidState`, 구 Claim은 state가 없는 과거 데이터의 호환 읽기·해제로 정했다. active state와 Claim이 동시에 있는 불일치는 자동 삭제하지 않는다. 수동 개인 완료와 모집 상세의 파티 전체 완료는 별도 명령으로 유지한다.

# 2026-09-18 F6-B2 기존 계약·UX 교차검토

- 실제 운영 Router, C* 확장성 계약, 참가 제품 정책과 F6-B2 초안을 다시 대조했다. active 상태를 완료 Claim으로 변환하지 않고 `none/active/completed/legacyActive/legacyCompleted/inconsistent` Projection으로 분리하며 `cycleKey`를 항상 검증하도록 계약을 보정했다.
- 동일 레이드 pending 신청은 최대 파티 인원 8명과 무관하게 늘어날 수 있으므로 전체 신청 종료를 완료 핵심 Transaction에 넣는 초안을 폐기했다. completed `raidState`가 승인·가입을 최종 차단하고, stale pending 무효화·정리는 비핵심 경로로 분리한다.
- 기존 개인 체크 해제 UX를 보존하면 반복방 다음 주차 전환에 필요한 state가 빠질 수 있음을 확인했다. 개인 해제는 자기 완료 state만 삭제하되 파티 완료 취소는 대상 누락 시 전부 거절하고, 다음 주차 전환은 현재 membership을 근거로 누락 active state를 생성하도록 B2-D 완료 조건을 보강했다.

# 2026-09-19 F6-B2-A 현재 주차 읽기 Projection 구현

- 운영 Router의 내 계정·모집 생성·신청 후보에 공통 읽기를 연결했다. completed는 완료로만 표시하고 active는 기존 `PartyCreateOccupancyGate`의 종료·만료·고아 판정을 거쳐 참가 중으로 표시해 두 상태를 중복 경고하지 않는다.
- B2-A는 읽기 단계이므로 현재 `active/completed/inconsistent` state 체크박스를 읽기 전용으로 뒀다. 구 Claim 명령이 state를 변경하지 못하고도 성공을 표시하는 회귀를 막고, 신규 state 쓰기와 활성 참가 개인 완료는 각각 B2-B/C에 남겼다.

# 2026-09-19 F6-B2 완료 UX 회귀 판정과 재설계

- 완료 기록 누락은 공용 lifecycle 이벤트에 Character·raid·difficulty·cycle Snapshot이 없고 sync가 네 필드 누락 이벤트를 건너뛰는 구조로 확정했다. 공용 이벤트 한 건 원칙은 유지하되 최대 8명의 수신자별 Character 대상과 공통 레이드 Snapshot을 보존한다.
- B2-A의 읽기 전용 체크박스는 사용자 요구가 아니라 구현 중간 단계에서 추가된 제한이며 기존 개인 해제 계약을 위반한다. 안내 아이콘은 유지하지만 checkbox를 막지 않고 active 개인 완료와 completed 개인 해제 명령까지 연결한 상태만 사용자 완료로 판정한다.

# 2026-09-19 F6-B2-R1 다인 완료 권한 경계 복구


# 2026-09-19 F6-B2-R2 공용 완료 이벤트 Snapshot 구현

- 원자 lifecycle Aggregate에 `raidId/difficultyId`를 포함하고, schemaVersion 2 공용 완료·완료 취소 이벤트에 공통 `raidId/difficultyId/cycleKey`와 최대 8개 `completionTargets[{playerId, characterId}]`를 기록한다. 이벤트 문서 수는 한 건으로 유지했다.
- Event Mapper는 공용 대상에서 현재 Player의 Character를 하나만 선택하고, 누락·중복·손상 대상은 완료 기록으로 사용하지 않는다. Sync는 매핑된 Character·레이드·난이도·주차를 Drift 완료 기록에 전달한다.

# 2026-09-19 F6-B2-R3 개인 완료 체크 UX 계약 정정

- 내 계정 체크박스는 서버의 돌이킬 수 없는 완료 판정이 아니라 사용자가 현재 주차의 레이드 흐름을 관리하는 개인 UX로 확정했다. `방 생성 → 완료 → 체크 해제 → 재생성 → 완료 → 재해제`와 공대장의 실수 완료 뒤 일반 참가자의 개인 해제는 정상 흐름이다.
- 기존 문서의 `inconsistent만 조작 차단` 문구는 이 UX와 충돌하므로 폐기했다. 불일치는 진단 상태로만 사용하며, 본인 소유·Character·raidId·현재 cycle을 검증할 수 있는 완료 state/구 Claim은 한 번의 개인 해제로 제한적으로 정리한다. active state·구 assignment·membership은 보존하고 남은 참가 상태로 모집 가능 여부를 다시 판정한다.
- 소유권이나 식별자를 증명할 수 없는 손상 문서는 자동 삭제하지 않고 구체적인 복구 안내로 보낸다. 개인 해제는 공동 완료 Snapshot·다른 Player·해산된 방을 변경하지 않으며, 파티 전체 완료 취소는 개인 변경이 있으면 계속 원자 거절한다.

# 2026-09-19 파티 전체 완료 취소 정책 폐기

- 기존 완료 취소는 `다음 주도 함께하기` 방에서 완료 뒤 구성 변경이 없을 때만 허용하는 제한적 공동 롤백이었으나, 복원 상태와 개인 체크 정정이 충돌해 전체 완료 UX를 복잡하게 만드는 것으로 판단했다.
- 잘못된 완료는 각 사용자가 내 계정에서 자기 완료 체크만 해제한다. 반복방은 완료 당시 membership을 유지하고 수요일 06시 새 주차 전환에서 새 `active` 상태를 구성한다.
- R1의 완료·주차 전환 권한 경계와 R2의 완료 이벤트 Snapshot은 계속 유효하다. 당시 함께 추가된 완료 취소 분기만 제거하며 과거 `completionCancelled` 이벤트·Drift 기록은 읽기 호환을 유지한다.

# 2026-09-19 F6-B2-R3 중단 구현 복구·자동 검증 진행

- 중단된 작업 트리를 보존해 개인 완료 명령을 `raidState` 원장에 연결했다. 미참가 수동 완료/해제, 활성 참가자의 탈퇴+완료, 파티장 후임 승계, 마지막 1인 해산, 그룹 listing·활성 수 정리를 각 핵심 Transaction 안에서 처리한다. pending 신청 정리는 인원수와 무관한 비핵심 후처리이며 타인 private state 선읽기와 Player별 이벤트 fan-out을 추가하지 않았다.
- 반복방 다음 주차 전환은 현재 membership/`partySlots`를 근거로 누락 state를 생성하거나 같은 모집의 기존 state를 갱신한다. 새 주차 시간창은 정확히 7일이며 요청 시각이 시작 이상·종료 미만이어야 한다. 다른 모집·새 주차 수동 완료 state는 덮어쓰지 않는다.

# 2026-09-19 F6-B2-R3 Rules 예산 복구 후속 체크포인트

- `b5769bf`는 기존 모집 Aggregate의 `lastCommand*` 필드에 `personalComplete`를 기록해 개인 완료 하위 쓰기가 같은 원자 명령을 짧게 식별하도록 바꿨다. 새 문서나 Player별 이벤트 복제, 타인 private state 선읽기는 추가하지 않았다.
- 단순 OR 순서 변경은 이미 실패했다. 다음 작업은 모집 update의 `personalComplete` 표식을 값싼 선행 게이트로 분리해 해당 명령에만 상세 개인 완료 검증을 평가하도록 하는 것이다. 신청 검증을 삭제·완화하지 않으며, 정상 신청·승인 뒤 일반 멤버 완료, 파티장 완료와 승계, 위조 후임 Snapshot 거절 순으로 같은 demo CI에서 확인한다.
- 사용 한도나 세션 중단 시 재개 기준은 대화 요약이 아니라 추적 커밋, 깨끗한 작업 트리, `NEXT_WORK.md`의 첫 실패 단계와 CI 실행 ID다. 미커밋 변경이 있을 때는 소유·목적을 확인하기 전 초기화하지 않고, 검증 가능한 중간 단위는 작업 브랜치에 커밋·푸시한 뒤 남은 실패와 다음 한 동작을 문서에 기록한다.

# 2026-09-19 F6-B2-R3 Rules 표현식 예산 회귀 복구

- JS 문법, `git diff --check`, R3 정적 계약 테스트 5건이 통과했다. Flutter 묶음 실행 한 번과 `dart format` 단독 실행 한 번이 출력 없이 정지해 중단했으나, 이후 표적 Flutter 테스트를 개별 실행해 정상 통과를 확인했다. 이를 코드 실패로 기록하지 않는다.

# 2026-09-19 F6-B2-R3 운영 Rules 게시 503 보류

- 같은 명령을 반복하지 않는다. 운영 활성 소스는 갱신되지 않은 것으로 단계상 판정하며 콘솔 원본 일치는 별도 확인하지 않았다. 사용자가 결과를 확인하고 콘솔 게시 또는 재시도를 새로 지시하기 전에는 R4 실기기 검증, B2 완료 판정과 `dev/main` 통합을 진행하지 않는다.

# 2026-09-19 테스트 비용 최소화 정책 확정

- 동일 구현의 인원수 검증은 2인·4인·8인을 반복하지 않고 현재 최대치인 8인 대표 사례 하나를 기본으로 한다. 마지막 1인 해산, 책임자 승계, 권한 거절처럼 상태 전이 자체가 다른 경우에만 별도 최소 사례를 유지한다.
- 중간 작업은 포맷·diff 검토를 기본으로 하고 전체 테스트·분석·CI를 관성적으로 반복하지 않는다. 코드가 바뀌지 않은 동일 검증은 재사용하며, 디바이스 수동 확인은 사용자가 수행한다.

# 2026-09-20 lifecycle 명령 enum 컴파일 회귀 수정

- lifecycle command envelope는 개인 완료 marker 생성을 명시적으로 거절하고, Write Plan의 상태 판별도 `personalComplete`를 `false`로 처리하도록 보완했다. 개인 완료는 기존 전용 Repository/Transaction만 사용하며 lifecycle Write Plan의 허용 범위를 넓히지 않는다.
- Domain·Write Plan 표적 테스트 16건이 통과했다. 동일 결과를 확인하는 전체 CI·인원수 반복 테스트·실기기 조작은 실행하지 않았으며, 사용자가 실제 debug build로 확인한다.
# 2026-09-20 F6-B2 정상 완료 사이클 확인과 고아 참가 복구 설계

- 사용자가 앞서 전달한 디바이스 체크리스트의 정상 파티 완료·해산·개인 체크 유지/해제·재참가 흐름이 모두 통과했다고 확인했다. 인원수별 동일 UI 테스트를 추가 반복하지 않는다.
- 별도로 `players/kVn6KZwZQO6or3BjNYqX/raidStates/xseSyVxZXWhKYxlZEucb_kazeros_act4`가 존재하지 않는 모집 `td904kw3PEgWI1GwIfUP`을 `active`로 참조해 참가 표시, 수동 완료 상태 불일치, 신청 후 승인 권한 오류를 일으키는 것을 데이터로 확정했다.
- 정상 완료 흐름의 회귀와 과거 콘솔 삭제로 생긴 고아 데이터를 분리했다. 본인 단건 고아 active state는 F6-D의 명시적 `참가 기록 정리`로 복구하고, 다른 Character·raid의 고아 pending 신청 및 다수 데이터 일괄 정리는 별도 운영 도구 백로그로 유지한다.

# 2026-09-20 F6-D D1~D3 단건 고아 참가 복구 구현

- 내 계정 수동 완료 영향 확인에서 본인 active party `raidState`의 연결 모집을 단건 조회해 원본 없음·종료·완료·만료 상태를 정상 참가와 분리한다. 존재하지 않는 새로고침 안내 대신 `참가 기록 정리` 확인창을 추가했다.
- 정리 Transaction은 Player·Character·raid·cycle·recruitmentId와 관찰 revision을 다시 검증하고, 여전히 stale인 경우에만 본인 `raidState` 및 정확히 일치하는 구 assignment를 원자 삭제한다. 완료 기록·신청·다른 상태는 변경하지 않으며 정상 활성 모집은 거절한다.

# 2026-09-20 F6-D 이전 주차 고아·신청/승인 UX 설계 보완

- 현재 주차 `2026-09-16`에 다른 Player의 동일 Character·raid 경로에서 `cycleKey=2026-09-09`, `status=active`, `source=party` 문서가 발견됐다. 현재 주차 Projection에서 제외돼 느낌표가 없는 것은 정상이나, 완료 버튼은 고정 경로를 읽고 cycle 불일치로 정리 불가를 반환한다.
- 현재 주차 active 고아는 느낌표+정리, 이전 주차 active 고아는 현재 느낌표 없이 완료·생성·신청·즉시 가입 직전 exact-state 판정에서 정리 안내를 제공하도록 분리했다. 정리는 관찰한 과거 cycle/revision/recruitmentId를 검증하고 원래 동작을 자동 재실행하지 않는다.
- 이전 주차 completed와 유효 반복방은 고아로 삭제하지 않는다. completed는 정상 rollover, 반복방은 승계 또는 참가 충돌로 처리한다. 단순 cycle 불일치만으로 삭제하지 않는다.

# 2026-09-20 F6-D D4 이전 주차 고아 판정·정리 구현

- `PartyCreateOccupancyGate.classifyExistingRaidState`를 추가해 고정 `raidState`를 현재/이전 주차 active 고아, 유효 참가 충돌, 현재/이전 주차 completed로 분리했다. 모집 원본 없음·종료·완료·만료 1회성만 고아이며 유효 반복방은 삭제하지 않는다.
- 내 계정 완료 사전 확인은 이전 주차 고아에 현재 참가 느낌표를 추가하지 않고 `지난 주차의 종료된 파티 참가 기록` 정리를 안내한다. 정리 Transaction은 화면의 현재 주차가 아니라 관찰한 state cycleKey·revision·recruitmentId를 재검증한다.
- 이전 주차 completed는 고아가 아니므로 수동 완료와 원자 모집 생성에서 기존 completed state를 본인 delete 계약으로 정리한 뒤 현재 주차 명령을 한 번 재시도한다. 신청·재신청·즉시 가입의 사전 차단은 D5로 유지한다.
- 사용자 실기기에서 과거 고아 완료 데이터의 안내·정리가 정상 작동함을 확인해 D4의 해당 수동 항목을 완료했다.
- 후속 UX 위험을 기록했다. 이전 주차 고아는 현재 Projection에 나타나지 않아 사용자가 쓰기 동작 전에는 알기 어렵다. D5는 신청 저장 전에 신청자에게 정리를 안내해 잘못된 신청이 공대장에게 도달하지 않게 한다. 기존 pending 신청의 승인 실패를 공대장 측에서 자동 거절하는 기능은 현재 미구현이며, D6의 명시적 `신청 거절` 방식을 유지한다. 자동 거절은 오판·revision 경쟁 영향을 검토한 뒤 별도 결정한다.

# 2026-09-20 F6-D D5 신청·재신청·즉시 가입 사전 차단

- 운영 원자 신청·즉시 가입 Repository가 본인의 exact `raidState`와 active state의 연결 모집 한 건을 읽어 D4 공용 수명 판정을 재사용하도록 연결했다. 정상 참가·유효 반복방, 현재 완료, 현재/이전 고아, 이전 완료와 손상 데이터를 서로 다른 결과로 유지했다.
- 고아 결과에는 관찰한 Character·raid·cycle·recruitmentId·revision을 담고 모집 상세의 기존 본인 단건 정리 명령에 연결했다. 사용자가 명시적으로 정리한 뒤 원래 신청·가입을 다시 눌러야 하며 자동 삭제·자동 재신청은 하지 않는다. 이전 completed만 최대 2회 제한 Transaction으로 먼저 정리하고 모든 조건을 다시 읽는다.

# 2026-09-20 F6-D 현재·이전 주차 고아 신청 복구 실기기 확인

- 사용자가 현재 주차 고아는 내 계정의 참가 느낌표와 정리 동작으로, 이전 주차 고아는 평상시 미표시되지만 다른 사용자의 동일 레이드 방 신청 시 나타나는 `참가 기록 정리` 안내로 각각 확인했다.
- 이전 주차 고아 안내에서 사용자가 정리를 선택하자 해당 `raidState`가 실제 삭제됐다. 정리 성공 뒤 신청은 자동 실행되지 않으며 사용자가 다시 신청하는 현재 계약을 유지한다. 고아 신청이 방장에게 pending으로 전달돼 승인 단계에서 반복 거절되는 증상은 신규 신청 경로에서 재현되지 않았다.
- 모집 생성은 연결 모집이 없는 stale state를 생성 Transaction에서 다시 확인해 교체하는 기존 동작이 정상 작동함을 확인했다. 신청·즉시 가입은 사용자에게 고아 상태를 알리고 명시적으로 정리하는 UX로 구분한다.
- 이번 확인 뒤 고아 신청 복구에는 추가 기능 수정을 하지 않기로 결정했다. 본인 즉시 가입의 동일 안내 UX, D6의 과거 pending 승인 실패 안내·명시적 거절은 아직 별도 확인·작업 범위다.

# 2026-09-20 F6-D D6 승인 실패 명시적 거절 UX 구현

- 승인 명령이 `permissionDenied`로 끝난 뒤 모집 상세와 신청 목록이 모두 서버 Snapshot이고, 같은 모집·신청 revision의 pending 및 현재 승인 권한이 유지될 때만 `신청자의 참가 데이터에 오류가 있어 승인할 수 없습니다. 해당 신청을 거절해 주세요.` 대화상자를 표시한다.
- 신청 목록 Snapshot의 캐시 여부를 화면 상태에 보존해 캐시·revision 변경·일반 권한 실패에는 기존 실패 안내를 유지한다. 정상 승인·기존 거절·직접 가입 흐름도 그대로 둔다.
- 모집 상세 Widget 테스트 49건과 변경 파일 `flutter analyze`가 통과했다. 첫 테스트 실행의 기대 application revision을 fixture 실제 값 3으로 바로잡은 뒤 재실행해 통과했으며 기능 결함은 아니었다. 실기기 설치·조작은 하지 않았다.
- 다음 게이트는 사용자가 과거 pending 대표 1건에서 전용 안내 → 명시적 거절, 그리고 정상 신청 승인 보존을 수동 확인하는 것이다. 본인 즉시 가입 D5 UX와 D7 최소 회귀도 남아 있으며 그 전에는 `dev/main` 통합·릴리즈를 진행하지 않는다.

# 2026-09-20 F6-D 신청 복구·파티 사이클 실기기 확인

- 고아 데이터가 있는 Character로 신청했을 때 정리 안내가 표시됐고, `닫기` 뒤 다시 신청하면 같은 안내가 다시 나타나 데이터가 임의 변경되지 않음을 확인했다.
- 사용자가 명시적으로 데이터를 정리한 뒤 재신청·방장 승인이 성공했다. 이어 참가 Character 변경과 자리 이동도 정상 작동했다.
- 파티 해산 뒤 같은 레이드에 다시 가입할 수 있었고, 파티 전체 완료 시 개인 완료 체크와 서버 데이터가 생성됐다. 이후 개인이 수동으로 체크를 해제하자 개인 완료 데이터가 삭제됐다.
- 이 흐름은 D5 고아 복구, 정상 승인, membership 변경, 자리 원장, 해산, 재참가, 공동 완료와 개인 해제를 한 실제 UX 사이클에서 함께 보존한 근거다.
- 신청 전에 고아 상태가 정리됐으므로 D6의 승인 실패 전용 대화상자는 이번 흐름에서 발생하지 않았다. 전용 안내·명시적 거절은 과거 pending 신청이 남아 있는 대표 데이터가 있을 때만 미확인 항목으로 유지한다.
- 사용자는 pending 신청 뒤 콘솔에 고아 state를 인위 생성하면 D6 실기기 재현이 가능하다고 판단했으나, 데이터 조작 테스트까지 수행하지 않고 현재 방어 구현과 표적 Widget 검증을 근거로 D6를 통과 처리했다.
- 정상 흐름에서는 신청 단계가 먼저 고아를 차단하므로 공대장이 고아 현황을 알 수 없는 것이 의도된 동작이다. 향후 실제 제보에서 승인 실패 뒤 전용 안내 또는 명시적 거절이 동작하지 않으면 D6 공대장 대응이 정상 작동하지 않은 회귀로 판정한다.

# 2026-09-20 다음 구간 F6-C 착수 전 상태 확인

- D6는 표적 자동 검증과 사용자 승인으로 닫았고, 현재 미커밋 코드·테스트·문서는 다음 구현 전에 하나의 체크포인트로 커밋할 대상이다.
- `RecruitmentCreatePage._load`를 실제 확인한 결과 첫 active raid/difficulty를 로드하고 대표 Character의 eligible 목록에서 같은 raid 또는 첫 raid를 자동 선택해 `_raid`, `_difficulty`와 draft를 채운다. `RecruitmentForm`도 두 값을 non-null로 요구하므로 F6-C 초기 선택 교착 해소는 아직 구현되지 않았다.
- F6-C 사용자 확인 뒤 F7에서 본인 즉시 가입 고아 복구 UX와 과거 미확인 표기를 정리하고 최종 자동·실기기 회귀를 한 번 수행한다. 그 전에는 `dev/main` 통합과 release를 진행하지 않는다.

# 2026-09-20 최소 전투력 제한 후속 작업 정의

- 모집 생성 원본·목록·상세·신청 Snapshot에는 `minCombatPower`와 전투력이 이미 저장·표시되지만, 실제 운영 상세의 후보 서비스와 원자 신청·즉시 가입 명령이 제한을 일관되게 강제하지 않는 상태를 확인했다.
- 이 작업은 F6-C 생성 초기 선택 수정과 섞지 않고 F6-E 독립 검증 단위로 진행한다. 신청자 본인 클라이언트가 계정 갱신으로 가진 선택 역할 Build Snapshot을 기준으로 후보 선택과 쓰기 직전 검사를 수행한다.
- 최소 전투력 제한이 있으면 미달 또는 전투력 정보 없음은 신청·재신청·즉시 가입·참가 Character 변경에서 차단한다. 정상 신규 신청은 신청자 단계에서 끝나므로 공대장이 신청자 private 데이터를 다시 읽지 않는다.
- 현재 실제 앱에 모집방 수정 기능이 없으므로 제한 변경 뒤 기존 pending 신청·멤버 처리 정책은 정하지 않는다. 차후 모집방 수정 기능을 추가할 때 별도로 결정한다. 생성자가 자신의 전투력보다 높은 제한을 입력하는 기존 동작도 이번 범위에서 변경하지 않는다.

# 2026-09-20 F6-C 모집 생성 초기 선택 교착 코드 완료

- 모집 생성 첫 진입에서 대표 Character는 추천 상태로 유지하되 레이드·난이도는 선택하지 않도록 변경했다. 특정 기본 레이드의 기존 참가·완료 상태가 Character 선택과 다른 레이드 접근까지 막던 교착을 제거했다.
- 레이드 선택 전 후보 조회는 Character와 저장 역할 Snapshot만 구성하고 특정 레이드의 점유·완료·일정·파티 구성 조건을 평가하지 않는다. 사용자가 레이드를 고르면 기존 후보 조회를 다시 실행해 모든 제한을 그대로 적용한다.
- Form의 레이드·난이도를 nullable하게 표시하고 미선택 저장에는 `레이드와 난이도를 선택해주세요.`를 안내한다. 첫 레이드 선택 시 기존 자동 제목을 생성하며 이후 난이도·Character 변경 흐름은 기존 로직을 재사용한다.
- 실기기에서는 첫 진입의 대표 Character/레이드 선택 조작, 미선택 저장 안내, 기본 첫 레이드가 불가능한 Character에서 다른 레이드 선택·정상 생성만 사용자가 확인한다. 같은 정상 UI의 자동 반복 검증은 하지 않는다.

# 2026-09-21 F6-C 실기기 확인 및 완료

- 사용자가 모집 생성 화면의 선택 부분이 실기기에서 정상 작동함을 확인했다.
- 코드·표적 Widget 19건·변경 파일 분석과 실기기 선택 흐름 근거를 합쳐 F6-C를 완료 처리했다.

# 2026-09-21 F6-E 최소 전투력 제한 구현 전 조사·설계

- 사용자가 모집 생성자에게는 최소 전투력 제한이 작동하지만 신청·승인 가입자에게는 작동하지 않는 현상을 확인했다. 코드 대조 결과 운영 모집 상세는 과거 최소 전투력 판정이 있는 후보 서비스가 아니라 `RecruitmentLeaderCandidateService`를 사용하며 query에 제한값을 전달하지 않는 것을 확인했다.
- 원자 신청·재신청·즉시 가입·승인·Character 변경 Repository는 전투력 Snapshot을 application/membership에 저장하지만 모집 원본의 `minCombatPower`와 비교하지 않는다. 화면 표시가 서버 쓰기 경계를 보장하지 않는 상태다.
- 단일 Domain 판정으로 제한 없음·충족·정보 없음·미달을 구분하고, 운영 후보와 각 원자 명령의 쓰기 직전 게이트에서 재사용하도록 설계했다. 승인 시에는 타인 private 데이터를 읽지 않고 기존 application Snapshot만 비교한다.
- 사용자는 앱의 물리적·기술적 변조에 대응하지 않기로 확정했다. 전투력을 속일 실익이 낮고 현재 배포된 구버전도 없으므로 구버전 우회와 서버 권위 검증 역시 F6-E 범위에서 제외한다.

# 2026-09-21 F6-E 최소 전투력 제한 코드·표적 검증 완료

- `MinimumCombatPowerPolicy`로 제한 없음·충족·정보 없음·미달을 단일 판정하며 정확한 경계값은 허용한다.
- 운영 모집 상세의 신청·즉시 가입·Character 변경 후보 query에 `minCombatPower`를 전달했다. 제한 미달/정보 없음 역할은 사유와 함께 선택할 수 없고, F6-C의 레이드 미선택 탐색은 보존했다.
- 과거 미달/정보 누락 pending 신청은 승인만 비활성화하고 사유를 표시하며 거절 버튼은 유지한다. Transaction이 같은 실패를 반환해도 D6 일반 권한 실패 복구로 보내지 않는다.
- 변경 파일 `flutter analyze`, Domain 정책·운영 후보·모집 상세 Widget·원자 Repository 연결 계약 표적 테스트와 `git diff --check`가 통과했다. 실기기 설치·조작은 하지 않았다.

# 2026-09-21 F7 최종 정리 검증 범위 조정


# 2026-09-21 F7 최종 대조 완료

- 본인 즉시 가입은 D5의 공용 `PartyRaidStateOccupancyInspector`로 고아 상태를 반환하고 일반 신청과 같은 명시적 단건 정리 UI를 사용한다. 정리 후 원래 명령을 자동 재실행하지 않는 계약도 공유한다.
- 해당 서버 경계는 D5 표적 검증과 demo Actions `35494192803`, 공용 정리 UX는 신청 경로의 사용자 실기기 결과로 근거를 남긴다. 사용자 결정에 따라 즉시 가입 전용 통합 테스트는 반복하지 않았다.

# 2026-09-21 F8-A 고아 신청 정리 구현·자동 검증

- 레이드 현황 신청 카드에서 사용자가 고아 신청 정리를 명시적으로 확인할 수 있게 했다. 서버는 부모 모집이 없거나 종료 상태일 때만 현재 Player의 application 원본 한 건을 삭제한다.
- 활성 모집은 삭제하지 않고 기존 철회를 사용한다. 다른 사용자의 신청, 모집 Aggregate, 멤버, `raidState`, 주간 완료와 이벤트는 변경하지 않는다.
- 완료 기록 삭제는 공용 이벤트 재동기화와 로컬 tombstone 계약이 필요한 F8-B로 분리한다.

# 2026-09-21 F8-B 완료 기록 삭제 폐기

- 완료 기록을 별도로 삭제해야 할 제품상 이유가 현재 없다고 재판단해 F8-B를 폐기했다.
- 삭제 UI, 로컬 tombstone, Drift 마이그레이션과 서버 공용 이벤트 삭제는 구현하지 않는다. 기존 완료 기록의 숨기기·다시 표시·로컬 정정 기능은 유지한다.

# 2026-09-21 F8 작업 브랜치 종료와 main 이력 대조

- `feature/raid-status-record-removal`은 F8-A 완료와 F8-B 폐기 결정을 반영해 작업 브랜치 범위를 종료한다. 사용자 방침에 따라 아직 `dev`·`main`에는 통합하지 않고 원격 작업 브랜치에 복구 지점을 보존한다.
- `main`에만 보이는 `e09e4a1`, `9ab16a7`은 병합 토폴로지만 별도로 남아 있다. 현재 `main` `9ab16a7`의 tree와 현재 `dev`의 조상 `8950629`의 tree가 `b0536fbbdc935d155a6c503f69492c2683d2faa6`으로 동일하고, 두 병합 원본 부모도 모두 현재 `dev`의 조상임을 확인했다.
- 따라서 `main`의 돌출 이력에서 현재 작업 브랜치로 별도 cherry-pick하거나 복원할 코드·문서는 없다. 이후 `main` 동기화는 개별 과거 merge를 가져오는 방식이 아니라 검증된 최신 `dev` 또는 release 시점을 기준으로 수행한다.

# 2026-09-21 F8 완료 지점 통합 결정

- 사용자의 최신 지시에 따라 GitHub Actions 파이프라인 작업보다 먼저 F8 완료 지점을 `dev`와 `main`의 공통 기준으로 통합한다.
- 과거 `main` 병합 이력은 강제로 지우지 않는다. 작업 브랜치를 `dev`에 반영하고 `main`의 기존 이력을 일반 병합으로 연결한 뒤 두 통합 브랜치가 같은 최종 커밋을 가리키게 한다.
- GitHub Actions 파이프라인 구축·검증은 이 통합 완료 뒤 별도 작업 범위로 진행한다.

# 2026-09-21 F8 완료 지점 dev·main 통합

- `feature/raid-status-record-removal`을 `dev`에 fast-forward한 뒤 기존 `main` 이력을 일반 병합으로 연결했다. 병합 결과 tree는 작업 브랜치와 동일하며 기능 내용의 추가 변경이나 충돌은 없었다.
- `dev`와 `main`을 통합 커밋 `69a29ca`로 맞추고 GitHub 원격에도 각각 푸시했다. 강제 푸시와 이력 삭제는 사용하지 않았다.
- 다음 작업 기준은 이 공통 통합 지점이며 GitHub Actions 파이프라인 구축·검증은 별도 작업으로 시작한다.
# 2026-09-21 BUG-021 그룹 가입 신청 승인 Rules 복구 — 자동 검증 완료

- application 승인 Transaction이 쓰는 다섯 경로의 승인 validator를 값싼 필드 guard와 함께 앞쪽으로 이동했다. 보안 조건, 원자 쓰기 문서 수, 스키마와 제품 Dart 코드는 변경하지 않았다.

# 2026-09-21 BUG-021 dev 통합

- 최신 `origin/dev`가 작업 브랜치의 직접 조상임을 확인하고 `fix/group-join-relation-conflict`를 `dev`에 fast-forward했다. 기능 완료 커밋 `063612c`까지 `origin/dev`에 푸시했으며 충돌과 이력 재작성은 없었다.
- 이 완료 기록을 반영한 문서 커밋도 같은 작업 브랜치를 거쳐 `dev`에 통합한다. `main`과 release는 변경하지 않으며 다음 독립 작업은 GitHub Actions 파이프라인 구축·검증이다.

# 2026-09-21 GitHub Android APK Release 파이프라인 준비

- 사용자가 수동으로 만든 release APK를 실기기에 설치해 정상 작동을 확인했다. 현재 Gradle release는 debug key로 서명되고 Android ID는 `com.example.lost_party`이므로 이 결과만으로 반복 가능한 정식 배포 상태로 보지 않는다.

# 2026-09-21 정식 Android ID·Firebase 설정 전환


# 2026-09-21 정식 Android ID 실기기 확인·영구 로컬 서명

- 저장소 밖에 영구 JKS를 생성하고 Git에서 제외되는 `android/key.properties`를 구성했다. Gradle release buildType의 debug signing을 제거하고 영구 release signingConfig로 전환했다.
- `flutter build apk --release`가 성공했다. 생성 APK의 package는 `kr.co.heowork0921.lostparty`, version은 `1.0.0+1`, 서명 인증서는 `CN=LostParty, OU=Development, O=HeoWork0921`이며 SHA-256 인증서 지문은 `f9b9ee5a2ec4059ef329ae6b2e4b5392f729124c0a4f5f55248c9da8cd8bc5ea`다.
- JKS와 `key.properties`는 Git 변경 목록에 없고 비밀번호를 출력하지 않았다. 다음 단계는 오프라인 백업 확인, GitHub Repository Secrets 등록과 Actions workflow 구현이다.

# 2026-09-21 Android APK Release workflow 로컬 구현

- 로컬 `key.properties`와 CI 환경변수를 함께 지원하도록 release signingConfig 입력 경계를 분리했다. CI는 runner 임시 경로에 JKS만 복원하고 비밀번호 파일은 만들지 않는다.
- `workflow_dispatch`, `v*` tag와 최초 검증용 작업 브랜치 push를 지원하는 workflow를 추가했다. Flutter 3.41.6·Java 21 고정 빌드, package/version/승인 인증서 검증, SHA-256과 7일 artifact를 구성했다.
- 태그는 `pubspec.yaml` versionName 및 `origin/main` 포함 여부를 확인한다. Release 게시는 서명 Secrets가 없는 별도 `contents: write` job에서만 수행하며 기존 Release를 덮어쓰지 않는다.
- 변경 후 로컬 release APK 재빌드가 성공했다. 원격 Secrets 등록·Actions 실행·임시 작업 브랜치 trigger 제거는 아직 수행하지 않았다.
- 사용자가 keystore와 비밀번호의 별도 백업을 완료했다. GitHub Actions Secrets 네 개를 값 노출 없이 등록하고 이름·갱신 시각만 확인했다. 최초 원격 workflow 실행은 작업 브랜치 push 뒤 진행한다.

# 2026-09-21 Android APK Actions artifact 검증

- 첫 원격 run `35591621599`는 APK 빌드와 Secrets 복원까지 성공했지만 새 `apksigner` 출력의 두 번째 콜론 앞 문자열을 지문으로 읽어 검증 단계에서 실패했다. 실제 APK 서명 실패나 키 불일치가 아니므로 서명 설정은 바꾸지 않았다.
- 지문 추출을 마지막 `certificate SHA-256 digest:` 값 기준으로 수정했다. 동시에 key alias와 같은 문자열이 포함된 job output이 Secret으로 오인돼 생략되지 않도록 workflow artifact 이름을 중립화하고, GitHub 공식 Action을 Node 24 기반 최신 major로 올렸다.
- 두 번째 run `35592769624`에서 Secrets 복원, release APK 빌드, package `kr.co.heowork0921.lostparty`, version `1.0.0+1`, 승인 인증서 지문, SHA-256 생성과 7일 artifact 업로드가 모두 통과했다.
- 원격 검증용 작업 브랜치 push trigger는 성공 후 제거했다. 최종 workflow는 수동 artifact와 `v*` 태그 GitHub Release만 제공한다.
- `dev`와 `main`을 검증 커밋 `0c93b34`로 맞추고 `v1.0.0` 태그를 게시했다. 태그 run `35596035632`에서 signed APK 빌드·검증·artifact 업로드는 통과했지만, checkout 없는 release job의 `gh release create`가 저장소를 자동 판별하지 못해 게시만 실패했다. Release 조회·생성 명령에 `--repo "$GITHUB_REPOSITORY"`를 명시하는 최소 보정을 적용하고, 성공 artifact를 재빌드하지 않는 복구 절차를 사용한다.
- 보정 커밋 `4569245`를 작업 브랜치, `dev`, `main`에 fast-forward 반영했다. 기존 `v1.0.0` 태그는 검증 앱 커밋 `0c93b34`에서 이동하지 않았다.
- run `35596035632`의 성공 artifact를 내려받아 SHA-256 `68e9beaacdf3f475de142630f200f87f03b8efc15251f484cfe0b5045c25460e` 일치를 확인한 뒤 공개 Release `v1.0.0`에 `lostparty-v1.0.0-android.apk`와 `.sha256`을 게시했다. Release는 draft·prerelease가 아니며 임시 복구 파일은 삭제했다.

# 2026-09-25 BUG-022 운영 데이터 대조와 완료 범위 정정

- 운영 콘솔에서 기존 지난 주차 그룹방 `5BCRsQkPRDvje1DrllEM`(지평)과 `zxrz7IKQxq3Q386cktp8`(세르카)이 모두 `continueTogether=false`, 지난 주차, `active` 상태로 남은 것을 확인했다. 현재 주차 대조 방 `bDxr3PCcZo6j1HcVa7PN`, `tVzXqc9VKIoszI3R9i8x`은 정상 해산됐다.
- 현재 주차 지평 방 해산 뒤 같은 Character·raid의 결정적 `raidState`가 존재하지 않는 것을 직접 확인했다. 기존 방은 동일 경로를 생성 당시 `raidStateTargets`로 보존하고 있으며, 일반 해산은 모든 target 삭제를 요구하므로 누락되거나 다른 모집에 재사용된 state가 전체 Transaction을 막을 수 있다.
- 2026-09-10 BUG-011의 완료 이력은 당시 `activeRaidAssignments` 교체와 lazy reconciliation 범위로 유지한다. 이후 v2 모집 Aggregate·`raidState` 경로에서 드러난 지난 주차 1회성 방 종료·진행 중 분리는 별도 F6-F이며 현재는 설계 보강만 완료되고 구현·자동 검증·실기기 확인은 남아 있다.

# 2026-09-25 F6-F 1단계 — 진행 중 목록 수명주기 분리

- 진행 중 읽기 모델에 모집의 `cycleEndsAt`을 연결하고, 현재·만료 반복·만료 1회성·이미 종료 상태를 구분하는 순수 정책을 추가했다.
- 만료된 `continueTogether=false` 방만 진행 중 원본 목록에서 제외하고 다음 단계의 단건 종료 대상 ID로 보존한다. 현재 주차 방, 만료 반복방과 `completed` 해산 대기 방은 기존 표시를 유지한다. `cycleEndsAt`이 없는 과거 문서도 기존처럼 표시한다.



## 2026-10-09 — C 구형 계약 종료 조사·설계

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0508)로 이동했다.

## 2026-10-09 — C1 구 member fallback 폐쇄 로컬 채택

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0509)로 이동했다.

## 2026-10-09 — D 정확한 대상 표현 후보 검증·목표 미달

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0510)로 이동했다.

## 2026-10-09 — D-X 단일 명단·명령 책임 확대 설계

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0511)로 이동했다.

## 2026-10-09 — D-X1 중간 체크포인트: 8인 완료 책임 분리

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0512)로 이동했다.

## 2026-10-10 — D-X1 준비 배치 추가 경계

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0513)로 이동했다.

## 2026-10-09 — D-X1 기본 캐릭터/역할 검증, 재배치 호환 보류

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0514)로 이동했다.

## 2026-10-09 — D-X1 공개방 생성·참가 하위 구조 검증

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0515)로 이동했다.

## 2026-10-09 — D-X1 재배치 호환·방장 후속 자리 로컬 검증

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0516)로 이동했다.

## 2026-10-09 — D-X1 공개방 개인완료·승계·마지막1인 로컬 통합

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0517)로 이동했다.

## 2026-10-09 — D-X1 공개방 전체완료 상태 로컬 통합

- 새로 가능한 앱 기능 없음. 단일 roster 후보에 전체완료와 반복방 회차 상태·완료 당시 이벤트를 통합했다(설계 §42).
- 보존 확인: 전체완료49건+기존222건, 총271건. 인증된 생성→8인 참가→전체완료 연속 확인.
  명단 불변, party 완료, 과거 역할 누락 보충/불일치 거절, 권한/소유권·누락/위조/동시 요청을 검증했다.
- 반복방 status=active/currentCycleStatus=completed를 구분해 일반 명령 재사용을 차단했다. 준비 명령은 후속이다.
- 후보7a3a3e26/35391bytes·깊이4. 새 코드 교체 예산5962bytes 초과, 전체 축소 목표/X1 미완료.
- 검증: Emulator271건, 로컬 컴파일200/빈 응답, Node 문법·깊이·diff. 앱 변경 없어 전체 Flutter 검증 생략.
- 미확인 실기기/운영, 그룹/legacy/해제·준비/advance·reader는 후속. 다음 준비/인증/advance는 미착수.
- fix/recurring-next-week-character-change 미커밋 유지, 사용자4파일/추적본 보존. 브랜치 생성·커밋·푸시·머지·dev 반영·운영 API/배포 없음.

## 2026-10-10 — D-X1 준비 변경 기본 경계 검증·중단 작업 재개

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0518)로 이동했다.

## 2026-10-10 — D-X1 공개 반복방 대상 인증·전원 주차 전환

- 새 앱 기능 없음. 격리 후보에 대상별 guard 인증과 전원 원자 advanceCycle을 연결했다(설계 §45).
- 보존 확인: 인증 core 보존·중도 실패, 최대8인 기존/타방/manual 완료·활성·부재 전환,
  인증 후 준비 변경→기존 인증 거절→전원 재인증→새 구성 전환, 소유권/누락/위조/동시 요청58건 통과.
- 전환 구성 검사를 일반 proofShape로 합쳤을 때 event1000식 초과가 재현됐다. 변경되지 않는 캐릭터 중복 대조를
  반복하지 않는 전용 명단 partition/구성 검사로 분리해 해소했다. 잘못된 역할/직업/자리 구성은 거절한다.
- 최종1a5d402c/47007bytes·깊이4, 새 코드 예산17578bytes 초과. 전체 축소/게시 해결/X1 미완료.
- 검증: 최종 SHA의 인증58+기존356=414건 통과. 로컬 컴파일200/빈 응답, Node 문법·깊이·diff.
  전체 Flutter 검증은 앱 불변으로 생략. 추적408f163f·사용자4파일 SHA 불변 확인.
- 미확인: guard 소비/제거와 전체 legacy writer 결합, 소유권 정리·그룹/reader, 앱/운영·실기기.
  실기기 완료 이력 보존·주차 전환·실패 안내·준비 재인증은 앱 연결 후 사용자 확인 대상이다.
- 기존 fix/recurring-next-week-character-change 미커밋 유지. 브랜치 생성·커밋·푸시·머지·dev 반영·배포 없음.

## 2026-10-10 — D-X1 인증 stub의 정상 참가 교체

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0519)로 이동했다.

## 2026-10-10 — D-X1 legacy Claim 결합과 인증 전후 우회 검증

- 새 앱 기능 없음. 격리 후보에 C1의 manual Claim create/delete를 연결하고 기존 소유권/주차/시간/assignment 조건을 보존했다(설계 §47).
- 보존 확인: 신규 후보57건+기존463건=520건 통과. C1 공통42건과 before/after 검사 제거 변이2건도 별도 통과.
  정상 생성·삭제/소유 차수0 호환, 인증 이후 Claim·동시 인증+Claim·stub 교체+Claim과 부분 표식 우회를 검증했다.
- 미완료1건: 서로 다른 batch의 인증/Claim 동시 요청은 상호 exists에서 Service call error로 둘 다 실패했다.
  한도/서비스 오류를 정상 거절로 세지 않았다. 같은 재시도 대신 실패 로그를 보존하고 다음 원인 분리 조사로 명시했다.
- 최종f2741903/49905bytes·깊이4.2348bytes 증가·잠정 교체 예산20476bytes 초과. 전체 축소/게시 해결 미완료·조건부 후보.
- 검증: 로컬 컴파일200/빈 응답(경고 항목 없음), Node 문법·깊이·diff. 추적408f163f·사용자4파일 SHA 보존.
- 미확인 실기기: 앱 연결 후 완료/해제·인증 충돌 안내는 사용자 확인 대상이다. 현재 앱/DI 불변으로 Flutter 전체 검증 생략.
- 다음은 동시성 오류 원인 분리. 잔여 guard 소비/소유권 정리·그룹/reader·전체 비용은 후속으로 유지.
  fix/recurring-next-week-character-change 미커밋 유지, 브랜치 생성·커밋·푸시·머지·dev 반영·운영 API/배포 없음.

## 2026-10-10 — D-X1 동시 인증/Claim 서비스 오류 원인 분리

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0520)로 이동했다.

## 2026-10-10 — D-X1 일반 캐릭터 변경 대상 인증 stub 교체

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0521)로 이동했다.

## 2026-10-10 — D-X1 active 개인완료 인증 보존 계약

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0522)로 이동했다.

## 2026-10-10 — D-X1 파티 밖 인증 stub 수동완료

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0523)로 이동했다.

## 2026-10-10 — Rules 최적화 실행 방향과 작업 단위 교정

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0524)로 이동했다.

## 2026-10-10 — 최종 성공 기준을 게시 안정화로 명확화

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0525)로 이동했다.

## 2026-10-10 — 감소율 목표 폐기와 작은 작업 단위 반영

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0526)로 이동했다.

## 2026-10-10 — 2-1 최종 후보와 검증 기록 대조 완료

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0527)로 이동했다.

## 2026-10-10 — 2-2~3-2 실제 Rules 반영과 로컬 통합 완료

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0528)로 이동했다.

## 2026-10-10 — 4-1 운영 준비

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0529)로 이동했다.

## 2026-10-10 — 4-1/4-2 게시 실패 진단

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0530)로 이동했다.

## 2026-10-10 — 활성화400 요청·구조 원인 조사

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0531)로 이동했다.

## 2026-10-10 — Rules 들여쓰기 정리 완료

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0532)로 이동했다.

## 2026-10-10 — 사용자 요청 Rules 보존 커밋과 의심군 선정

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0533)로 이동했다.

## 2026-10-10 — 1순위 제거 비교본 테스트 프로젝트 게시 성공

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0534)로 이동했다.

## 2026-10-10 1순위 함수군 단독 게시 비교

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0535)로 이동했다.

## 2026-10-10 전체 Rules 세 방향 간소화 설계

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0536)로 이동했다.

## 2026-10-10 1-1 인증 검사 간소화

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0537)로 이동했다.

## 2026-10-10 18:58 KST 1-1 운영 게시1회 실패

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0538)로 이동했다.

## 2026-10-10 사용자 직접 게시본 읽기 조사

- 사용자 게시 성공 확인: 운영7a441b1f/183844bytes,19:10 KST. 함수 정의11개 삭제 외 공백 제외 차이 없음.
- 미정의 함수 호출151곳이 남아 기능 정상화로 판정하지 않음. 인증/그룹권한/주차 인증 관련 영향. 실제 요청/실기기는 미확인.
- 원격 GET·정적 비교만 수행, 에이전트 게시/복구0회. 로컬e4a6c4cc와 기존 미커밋 보존.
- 문서 미커밋, 기존 브랜치 유지, push/dev 반영 없음. 상세 통합 설계의 사용자 직접 게시본 확인 절.


## 2026-10-10 공통 권한 직접식 구현·운영 게시 실패

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/DEV_LOG.md#source-0539)로 이동했다.
## 2026-10-13 — 신규 서버 문서·기존 자료 보관 Git 통합

- 사용자 후속 지시: 현재 문서 변경 커밋, 최신 origin/dev 확인, dev 병합·푸시.
- 새로 가능해진 흐름: 백엔드 분석·설계 13문서와 출처가 기록된 기존 자료 보관을 dev 기준으로 공유한다.
- 보존 확인: 기존 앱 코드·설정과 backend-migration 보관 제외 정책, 추적 제외된 private 자료 및 로컬 실험·백업.
- 검증: 전용 문서 원문 비교, 상대링크·발췌 앵커·코드펜스 검사와 git diff --check 통과. 순수 문서 작업으로 Flutter 테스트·실기기 확인은 수행하지 않았다.
- 실제 서비스 배포·데이터 변경 없음. 통합 커밋과 원격 반영 결과는 Git 이력에서 확인한다.

## 2026-10-13 — Google 로그인 구현 준비·Backend 계약 대기

- 사용자 Google 로그인 작업 시작 지시로 feature/google-login을 재사용했다. Android·신규 Backend, 비로그인 로컬 기능 유지, 원정대 인증은 로그인 후, 통합 가입/로그인, 사용자 선택형 로그인 유지·원래 화면 복귀 정책을 GOOGLE_LOGIN_CONTRACT와 NEXT_WORK에 기록했다.
- Backend 요청 Issue #2 생성·조회 근거를 연결했다. bfc51e4d9a8a5ced360247a8c60bf370f7ca84ad 확인 시 댓글 0개, OpenAPI 0.1.0은 GET /health만 존재한다. 인증 방식/DTO·세션 정책·Google 등록·개발 접속 주소·서비스 정책 URL이 아직 없어 실제 연동 코드는 착수하지 않았다.
- 조사: main/bootstrap은 필수 PlayerSession, Router/DI는 Firebase UID/binding을 사용한다. 신규 user ID를 Firebase playerId로 대입하지 않으며 공개/로컬 회귀와 세션 수명·계정 격리 검증 목록을 준비했다.
- 새로 가능해진 흐름: 실행 계획·회귀 보호·Backend 인계 입력 확인. 실제 Google 로그인/앱 흐름 추가는 아직 없음.
- 보존 확인: 앱 코드·설정·의존성 변경 없음. 기존 raid_cycle_schedule 변경 표시와 미추적 실험/백업을 보존했다. 런타임 회귀 통과를 주장하지 않는다.
- 검증: git diff --check와 문서 diff/상대링크·내용 검토. 문서만 변경하여 flutter test/analyze는 실행하지 않았다.
- 미확인 실기기: 실제 Google 계정 선택/인증·재실행·로그인 유지·로그아웃·기존 공개/로컬 흐름. API 계약 인계 후 구현·자동 검증을 마치고 사용자 확인 예정.
- feature/google-login 유지·준비 문서 미커밋, dev 미반영·push/merge 없음. Backend 코드/운영 데이터/배포 및 추가 Issue 변경 없음.

## 2026-10-14 — Android Google 요청별 nonce bridge

- 사용자 다음 작업 지시로 feature/google-login에서 API와 독립적인 Google 인증 증거 획득 모듈을 구현했다. Flutter MethodChannel→Android Credential Manager Google 버튼 흐름으로 매 호출의 serverClientId/nonce를 전달한다. 반환은 ID token 증거이며 회원/session 생성과 로그인 성공 상태는 Backend가 소유한다.
- 확인된 Google 프로젝트/Web client·현재 package/debug SHA 일치·프로덕션/외부·빈 권한목록, 최소 프로필 제외·이메일·로컬 서버/에뮬레이터 우선·익명 공급자 중지 정책을 계약에 기록하고 Backend #2 댓글6149284949로 인계했다. Backend OpenAPI는 여전히 /health만 있으며 새 댓글 없음 확인.
- 새로 가능해진 흐름: 호출별 nonce와 Google 증거 획득 native bridge/credential state 해제, 중복·취소·잘못된 결과·민감 오류 제거. 화면/실제 Backend 회원 로그인은 아직 불가.
- 보존 확인: 기존 main/bootstrap/Router·Firestore·공개/로컬 화면과 pubspec.lock은 변경하지 않았다. 기존 raid_cycle_schedule 변경 표시와 미추적 실험/백업 보존. 익명 공급자 중지 후 기존 앱 실행 실패 가능 상태는 남아 있으며 우회 로그인 구현 없음.
- 검증: Dart format, 경계 테스트6개 통과, 표적 flutter analyze 이슈0, Gradle :app:compileDebugKotlin 통과, git diff --check 통과. GoogleID1.2.1의 Kotlin metadata2.4/현재compiler2.2 호환 오류를 실제 로그로 확인 후1.2.0으로 조정해 통과했다. Credentials1.6.0, Kotlin/AGP 설정 유지.
- 첫 묶음 테스트 출력이 잘려 결과를 확정하기 위해 --no-pub --reporter expanded로 재확인했다. Router/공용세션 미변경 구간이므로 전체 Flutter 검증은 후속 연결 최종 상태로 남겼다.
- 미확인: 실제 Google UI·ID token nonce claim/서버 검증·release 서명 매칭·에뮬레이터/WSL 접속·실기기/HTTPS. 서버 challenge/API 인계 후 사용자 기기 인수 진행. 설치·기기조작·실인증을 에이전트가 수행하지 않았다.
- 브랜치 유지·코드/문서 미커밋·dev 미반영·push/merge 없음. Backend에는 공개 등록 정보와 구현 선택만 댓글로 전달했고 서버코드/데이터/배포 변경 없음.

## 2026-10-14 — 合의된 API 검토안 기준 Flutter 로그인·세션 연결

- 사용자 #2 최종 검토안 동의 및 API가 합의대로 작성된다는 가정의 Flutter 구현 승인. 실제 OpenAPI SHA는 아직 미인계이며 소비 기준은 댓글6149545526/동의6149615842다.
- 새로 가능해진 흐름: BackendApp으로 익명회원/Player 생성 없이 실행, 로컬 계정 탭 접근, Google 통합 가입·로그인/유지 선택/설정·로그아웃, /v1 인증6API adapter와 DTO, origin별 secure 단일JSON·pending/횟수 기록·single-flight/60초미만 총3회복구, 409/401/403/일시장애 구분·epoch 늦은응답 격리. 실제 서버/Google 성공은 미확인이다.
- 보존 확인: 로컬 AccountRepository·캐릭터·빌드·LostArk 토큰 설정과 원본 DB 사용. 새 entry에서 Firebase 초기화/익명 호출과 private gateway를 사용하지 않고 과거소유권badge는 표시하지 않는다. 기존 MyApp/Router는 레거시 기준용으로 보존한다. Firebase 데이터/설정·기존 raid_cycle_schedule 변경 표시·미추적 실험/백업은 불변.
- 서버 의존성: 공개 모집은 기존 필터/목록UI+준비안내/unavailable 상태이며 실제조회는 후속 public API 필요. 원정대/그룹/private 기능은 로그인알럿/준비화면이다. 빈 성공결과·Firebase fallback·가짜회원로그인은 없다. 약관/개인정보 링크는 설정된 실제HTTPS URL만 사용한다.
- 의존성: 기존crypto3.0.7을직접의존성으로전환, 다른 Dart 패키지업그레이드없음. debug만10.0.2.2/localhost/127.0.0.1의로컬HTTP허용, release는HTTPS필수. 설정/실행방법은 GOOGLE_LOGIN_CONTRACT에기록.
- 검증: 인증경계25개통과, 변경파일분석0이슈, Android 최종 compileDebugKotlin/processDebugMainManifest통과, format/diff검토/git diff --check통과.
- 최종전체 flutter test:1224통과/109실패. HEAD원본을임시폴더에git archive로추출해1199통과/109실패를확인했고, 실패109개의식별자는최종상태와전부동일했다. 기존Rules계약/레거시Firebase core/no-app등을이번그룹에서수정하지않는다. 추가25테스트전부통과이며새실패없음.
- 전체flutter analyze는coverage의과거baseline/실험복사본·기존테스트오류까지포함해227건을보고했다. 변경된auth파일블록스타일1건은보완했고최종변경파일분석은0이슈다. 다른기존경고/보관코드오류는범위외로유지한다.
- 미확인사용자기기: localhost↔WSL↔10.0.2.2접속, Google선택/취소·서명/nonce실검증, 유지선택별새실행·local/보호화면회귀·서버recovery·실기기/release。Backend구현/실OpenAPI인계후대조·인수하며에이전트설치/기기조작없음。
- feature/google-login의코드·문서미커밋,dev/push/merge미반영·브랜치유지。실제서버개발/배포·Firebase삭제변경없음。

## 2026-10-14 — Debug 시작 Base URL 입력

- 사용자 요청으로 debug 앱의 새 실행마다 Base URL 알럿과 텍스트 필드를 추가했다. BACKEND_BASE_URL이 있으면 표시하고 없거나 입력이 비면 http://10.0.2.2:8000을 사용한다. 유효한 HTTP/HTTPS 주소를 확인한 뒤 해당 주소로 서비스·세션을 초기화한다. 주소는 이번 실행에만 적용하며 저장하지 않는다.
- 새로 가능해진 흐름: 빌드 변경 없이 개발 서버 주소를 입력해 사용. origin별 안전 보관 키를 그대로 사용한다.
- 보존 확인: release의 알럿 없음·HTTPS 필수 정책과 기존 로컬/로그인 화면 유지. 사용자 런타임 입력을 지원하기 위해 debug 전용 network config만 HTTP 개발 주소를 허용했다. 선택 전 DB/Dio/세션 복원 요청은 시작하지 않는다.
- 검증: Dart format, 변경 파일 flutter analyze 이슈0, 기존 API/주소 정책 테스트4개 통과, git diff --check. 작은 초기 UI 변경으로 전체 Flutter 테스트·Android 빌드는 반복하지 않았다.
- 미확인 사용자 기기: 새 앱 실행 기본값 표시, 빈 입력, 잘못된 주소 안내, 입력 주소의 실제 API 접속. 새 프로세스 실행에서 확인하며 hot reload만으로 알럿을 다시 표시하지 않는다.
- feature/google-login 유지·미커밋·dev/push/merge 미반영. 기존 변경·실험/백업 보존.

## 2026-10-14 — 로딩 중앙 빛 스윕 제거

- 사용자 요청으로 LostPartyEntryScreen의 _LogoShine 호출과 전용 구현을 제거했다.
- 새로 가능해진 흐름: 중앙을 가로지르는 빛 효과 없이 로딩 연출 표시.
- 보존 확인: 배경 이미지·LogoGlow·상단 별 반짝임, 2200ms 타이밍과 한 번만 실행되는 완료 콜백. Google 로그인·debug URL 초기화는 수정하지 않았다.
- 검증: 기존 표적 테스트1개 통과, 표적 flutter analyze 이슈0, Dart format/git diff --check 통과. 작은 시각 변경으로 전체 Flutter 검증은 반복하지 않았다.
- 미확인 기기 항목: 로딩 화면의 실제 표시. 에이전트 기기 설치/조작 없음.
- feature/google-login 유지·변경 미커밋·dev/push/merge 미반영, 기존 작업 결과 보존.

## 2026-10-14 — 로그인 성공 후 pushed 화면 복귀 수정

- 사용자 신고: Google 선택 후 빨간 오류는 사라졌으나 로그인 화면에 머묾. 서버 최근 challenge201/Google교환200을 확인하고 pushed 로그인+auth Router refresh 최소 테스트에서 화면 복귀 실패를 재현했다. 직접 로그인 진입 fallback은 기존에도 통과했다.
- 원인/수정: 성공 콜백이 ListenableBuilder의 갱신 context에서 즉시 탐색했다. State의 context에서 Router를 확보하고 인증 갱신 후 post-frame에 pop/fallback go를 수행하도록 해당 처리만 수정했다. mounted/로그인 상태를 재확인하여 화면 이탈·로그아웃 뒤 탐색하지 않는다.
- 새로 가능해진 흐름: 로그인 성공 시 원래 화면으로 복귀, 직접 진입은 /account로 이동. 쓰기 자동 실행 없음.
- 보존 확인: 인증 API·nonce·세션 수명·취소/실패 처리와 로그인 유지·로컬 데이터 정책 불변.
- 검증: 수정 전 pushed 복귀 테스트 실패/직접 진입 통과 → 수정 후 둘 다 통과. 기존 인증 경계 포함27개 통과, 변경파일 분석·format/git diff --check 통과. 한정된 탐색 수정으로 전체 Flutter 검증은 반복하지 않음.
- 미확인 사용자 기기: 수정 빌드에서 실제 Google 로그인 후 이전 화면 복귀·설정의 로그인 상태. 서버 코드/설정 변경과 에이전트 기기 설치/조작 없음.
- feature/google-login 유지·미커밋·dev/push/merge 미반영, 이전 변경 보존.

## 2026-10-14 — Backend 시작 로딩 배경 복구

- 사용자 로그인 성공 확인 후 로딩 배경 누락 신고. 이미지 파일은 불변이고 main의 BackendApp 전환에서 기존 entry 호출이 빠진 직접 원인을 확인했다.
- 수정: LostPartyEntryScreen에 embedded 옵션을 추가하고 신규 시작 화면에 연결했다. debug URL 선택 알럿 뒤에도 배경을 표시하며, 세션 복원·2200ms 연출 완료 후 Router로 전환한다. 중첩 MaterialApp 없이 기존 효과를 재사용한다.
- 새로 가능해진 흐름: 새 bootstrap의 로딩 배경·연출 표시 복구.
- 보존 확인: 중앙 Shine 제거 상태, Glow·별·원본 이미지·완료 콜백, debug Base URL 알럿과 익명 회원 무생성 정책. 사용자 Google 로그인 정상 확인은 이 수정 이전 결과이며 이후 기기 회귀는 미확인이다.
- 검증: 실제 BackendApp 첫 프레임 배경+URL 알럿·MaterialApp1개 재현 테스트와 기존 연출 테스트2개 통과, 표적 analyze 이슈0·format/git diff --check 통과, 이미지 diff 없음. 한정된 로딩 연결로 전체 검증은 반복하지 않았다.
- 미확인 사용자 기기: 새 실행의 배경/알럿·로딩 완료 후 화면 전환. 에이전트 설치·기기 조작 없음.
- feature/google-login 유지·미커밋·dev/push/merge 미반영, 이전 작업 결과 보존.

## 2026-10-14 — 로그인·세션 인수 검증과 테스트 전환 기획

- 사용자 확정: Firebase 폐기·빈 서버 시작·기존 사용자/테스터 데이터 이관 없음. Firebase 전용 테스트는 Git 이력에 남기고 제거하며 유효한 공통 정책은 유지/이식, 로컬·신규 인증 테스트는 유지한다.
- NEXT_WORK를 다음 단일 작업 그룹으로 정리했다. 파일별 분류 대장, helper/fixture/Firestore CI 실행 경로, 서버 계약 근거, 인수 체크리스트와 최종 전체 검증·Git 종료 조건을 설계했다. 조사 시점 test의 *_test.dart는 218개이며 전수 분류/삭제 목록 확정은 실행 단계다.
- AI_CONTEXT의 과거 미구현·미통합 상태를 현재 상태와 구분해 최신 지도에 정리했다. 사용자 로그인 성공은 확인 완료, 세션 유지·만료·로그아웃과 최신 로딩 화면은 인수 대기로 기록했다.
- 새로 가능해진 흐름: 다음 구간의 실행 기준과 검증 책임을 문서에서 확인할 수 있다. 이번에는 앱 기능을 변경하지 않았다.
- 보존 확인: 기존 코드·테스트·CI·설정과 미커밋 실험/백업을 수정하거나 삭제하지 않았다. Firebase SDK/소스 전체 제거와 원격 데이터 삭제는 이번 범위에서 제외했다.
- 미확인: 파일별 최종 분류, 실제 서버 계약 revision과 기기 인수 항목. 이번 기획으로 검증 통과나 Firebase 완전 제거를 선언하지 않는다.
- 검증: 문서 내용·상대 링크 확인과 git diff --check. 순수 문서 기획으로 Flutter 테스트/분석·기기 조작을 반복하지 않았다. feature/google-login 미커밋, dev 반영·push 없음.

## 2026-10-14 — Google 로그인 구현·다음 구간 기획 dev 통합

- 사용자 dev 병합·push 지시로 feature/google-login의 인증 구현·관련 테스트·debug URL 알럿·로딩 복구·정책 문서와 다음 작업 계획을 하나의 복구 지점으로 기록한다. 최신 origin/dev는 64b09bf로 추가 변경이 없었다.
- 새로 가능해진 흐름: 현재 Google 로그인 구현과 다음 작업 기준을 dev에서 공유한다. 테스트 전환·세션 인수 그룹 자체의 실행/완료를 의미하지 않는다.
- 보존 확인: 별도 Rules 실험·백업과 기존 raid_cycle_schedule 변경 표시를 staging에서 제외했다. 테스트 삭제·Firebase SDK/데이터 삭제·main 변경·운영 배포는 수행하지 않는다.
- 최종 전체 flutter test: 1227개 통과/109개 실패. 보관된 HEAD 기준 로그와 실패 식별자 109개를 대조해 차이 0개를 확인했다. 인증·화면 복귀·로딩 테스트는 통과했으며 전체 테스트 통과로 판정하지 않는다.
- 최종 flutter analyze: 224건. 과거 coverage 사본·기존 테스트/소스·별도 실험 문제를 포함한다. 병합 대상 Dart 파일의 분석 결과는 별도로 확인했다. 포맷 검사에서 안내 문구 줄바꿈 1곳을 정리했고 동작 변화는 없다. git diff --check 통과.
- 첫 sandbox Flutter 실행은 진행되지 않아 중단하고 SDK 접근 권한으로 재실행했다. 실제 검증 로그는 추적 제외된 tools/google_login_premerge_test.log·google_login_premerge_analyze.log에 보관한다. 원격/로그에 인증정보를 추가하지 않았다.
- 미확인 기기: 로그인 유지·만료·로그아웃 및 최신 로딩 화면. 사용자 Google 로그인 성공 확인은 보존하고 NEXT_WORK의 체크리스트를 다음 구간으로 유지한다.
- 최종 병합 커밋과 origin/dev 동기화는 Git 이력으로 확인한다. 작업 브랜치는 유지하며 별도 실험/백업이 남아 있으므로 작업 트리 전체가 깨끗하다고 보고하지 않는다.

## 2026-10-14 — 테스트 전환 실행·인증 계약 소비 확인

- 현재 dev 7db7bde를 기존 feature/google-login에 fast-forward하여 다음 승인 구간을 시작했다. 변경·미추적 Rules 실험/백업의 소유를 보존하며 새 브랜치·commit/push는 만들지 않았다.
- 새로 가능해진 흐름: 기본 flutter test에서 Firebase 익명 인증/Player binding·Firestore Rules/adapter·폐기 MyApp 검증을 제외하고 현재 검증 책임을 분류 대장에서 확인한다. Firebase 전용 테스트41개·전용 GitHub Actions3개·미사용 Firestore transaction fake1개를 Git 원본 확인 후 제거했다. legacy 이동·skip·분석 exclude 변경 없음.
- 기존218개를 분류: 제거41, 유지172, 신규 업무 계약 후 이식 대기5(실행 유지). 신규 auth_session_store_test 1파일/3검증을 추가해 남은 테스트178파일. Node/Rules 수동 도구는 전용 CI 호출을 종료하고 의존성·미추적 실험 보호를 위해 원본을 보존했다. 도구·Firebase 실행 소스/SDK 최종 제거는 후속이다.
- 보존 확인: 로컬 AccountDatabase·캐릭터·빌드·Lost Ark API·공통 정책/Validator·Write Plan 테스트, 모집 fake 검증, 공통 party_read_fakes·fixture, Android release workflow, 앱/SDK/설정·데이터 모두 불변. 삭제한 테스트/helper를 참조하는 남은 테스트 파일0개 확인.
- 계약 소비: Backend519c609495966a3d785c6671c09bf513b28875a6, 추적OpenAPI hash7e62e9def16c5388760e1b3877ef52e618d254a4b32ab708305e850c39e434b0. checkoute6c72e4 clean, 6API/DTO·오류·session TTL·nonce/hash·복구상한을 Flutter와 대조했다. Backend46개 통과는 서버 기록된 결과이며 이번에 DB/서버 테스트를 반복하지 않았다. Windows localhost:8000은 연결 실패; 서비스 시작/DB/설정 수정/Issue 게시 없음.
- 검증: 전체 flutter test --no-pub 1126통과/8실패. 추가된 origin별 저장격리·새 인스턴스 복원·Lost Ark 키 보존3건과 기존 auth27건 모두 통과. 남은 실패8개의 식별자는 이전109실패 목록에 모두 포함돼 새 실패없음. 전체 통과나 기기 인수 완료로 판정하지 않는다.
- 전체 flutter analyze --no-pub 224건: coverage 과거사본170, lib기존49, test기존2, tools실험3. 신규 저장 검증 파일의 분석 결과0. broad exclude/소스 정리로 기존 분석 문제를 감추지 않았다. 신규 파일 format·문서 링크/diff 검사 완료. 검증 로그는 추적 제외 tools/google_login_transition_test.log·google_login_transition_analyze.log.
- 유지한 실패: 로컬 notification receipt2, notification ViewModel2, raid status page2, party detail page2. 알림 fixture의 고정된2026-09-23 만료시각과 실제 now 조회는 후속 테스트 수명 검토 근거다. 반대 역할 후보 위젯 미발견은 별도 정책/fixture 대조가 필요하며 현재 인증 경계의 직접 원인으로 확인하지 않았다. 관련 정상 코드와 테스트를 임의로 삭제·수정하지 않았다.
- 미확인 기기: 유지 선택별 앱 완전 종료/재실행, 일시 서버 장애 후 복원·만료/로그아웃, 보호 기능 취소/복귀·자동 제출 없음, 로컬 데이터 보존·로딩 배경/debug URL. 사용자 설치/조작이 필요한 현재 구간 인수이며 에이전트가 수행하지 않았다.
- 작업 구간은 자동 정리 구현 완료·기존 실패/사용자 인수 남음. feature/google-login 미커밋·이번 변경dev미반영/push없음, 브랜치 유지. 기존 인증 구현의 dev7db7bde 통합은 유효하다.

- 추가 확인: 전체 로그의 파일별 출력에 신규 storage 테스트가 나타나지 않아 해당 파일을 표적으로 재확인했고 3건 모두 통과했다. 코드 변경 없이 전체 묶음은 반복하지 않았다.

## 2026-10-14 — 로그인 유지 선택·해제별 재실행 사용자 인수 통과

- 사용자 보고로 로그인 유지 선택 시 앱 재실행의 로그인 복원, 해제 시 재실행의 비로그인 결과를 각각 통과로 기록했다. NEXT_WORK 체크리스트와 AI_CONTEXT를 갱신했다.
- 이번 확인은 유지 선택별 로그인 상태에 한정한다. 로그아웃 후 재실행, 만료·정지·일시 장애, origin 변경 기기 확인, 로컬 데이터 보존과 최신 로딩 화면은 별도 미확인 상태를 유지한다.
- 기능 코드·테스트 변경 없음. 기존 자동 검증 결과를 재사용하고 git diff --check·문서 변경 내용으로 확인했다. 기존 8개 테스트 실패·분석224건의 상태는 바뀌지 않는다.
- feature/google-login 유지·현재 구간 미커밋, dev 반영/push 없음. 기존 변경·실험·백업 보존.

## 2026-10-14 — 안내한 수동 인수 항목 전체 통과 정정

- 사용자가 “다 통과”라고 정정했다. 앞서 전달한 4개 항목 전체(로그인 유지 선택/해제별 재실행, 로그아웃 후 재실행, 로컬 캐릭터·빌드 보존 및 로딩 배경·URL 알럿)를 사용자 수동 통과로 기록한다. 직전 답변에서 두 항목만 통과로 제한한 해석을 정정하며 같은 항목을 재요청하지 않는다.
- 사용자에게 해당 4개로 안내하지 않은 만료·정지·위조/동시성·origin 변경 등 상세 경계는 기존 자동 검증/별도 근거와 구분한다. 사용자 통과 보고를 자동 테스트8실패·분석224건 통과로 확대하지 않는다.
- NEXT_WORK·AI_CONTEXT 갱신, 문서 내용 및 git diff --check 확인. 코드/테스트 변경과 Flutter 검증 반복 없음. feature/google-login 미커밋·이번 변경dev미반영/push없음, 기존 산출물 보존.

## 2026-10-14 — 유지 테스트 안정화·검증 기준 정리 완료

- 사용자 승인으로 이전 테스트 전환의 후속 실패8개와 분석224건을 정리했다. 기존 feature/google-login에서 미커밋 전환 변경을 보존·재사용했으며 안내한 수동4항목 전체 통과 결과를 다시 요청하지 않았다.
- 원인: 알림7실패는 fixture 만료일2026-09-23/10-06 이후 실제시각으로 조회한 테스트 수명 문제다. DB 직접 조회에 기존 now 인자를 명시하고 UI/ViewModel은 실제 SQL에 cutoff만 고정하는 FixedClockAccountDatabase를 사용한다. 기본2026-09-10은 fixture 발생 뒤·만료 전이며 임의 장기 만료나 조회 결과 fake로 우회하지 않았다.
- 나머지1실패는 제품 요구(같은 캐릭터 반대 역할 변경)와 현재 UI/원자 WritePlan의 미지원이 불일치했다. b3461cb diff·WritePlan 거절과 legacy DEV_LOG source-0508/0509의 미완료 기록을 확인하고 UI 테스트를 현재 거절 경계·타캐릭터 후보 보존·무명령 전송 검증으로 맞췄다. 제품 요구를 폐기하지 않으며 신규 Backend 동일 state update 계약으로 인계한다. 동작을 열어 서버 실패를 유발하는 UI만의 수정은 하지 않았다.
- 분석: coverage 과거 baseline 사본170건은 Git 제외 생성물이며 analyzer coverage/** 경계를 명시했다. 활성 lib/test/tool을 제외하지 않았다. 추적 Firestore adapter4파일49개의 중괄호 lint와 test2개 경고를 정리했다. adapter 변경은 중괄호/공백을 제거한 원본·변경본 문자 대조가 모두 동일해 분기/반환/쓰기 순서 보존 확인. 제품 정책·서버 요청·DB 스키마 변화 없음.
- 새로 가능해진 흐름: 날짜 경과에도 유지 테스트 전체 검증을 재현하며 현재 지원/미지원 범위를 구분한다. 보존 확인: 알림 멱등·읽음·수신자·방·만료 경계, 타캐릭터 역할 변경·구성/WritePlan 정책, 로그인·시작 화면 및 로컬 데이터. 기존41테스트/3CI/1helper 제거와 신규origin저장3검증도 함께 검증됐다.
- 검증: 수정 후 관련95테스트 통과. 최종 전체 flutter test --no-pub 1134개 모두 통과. 최종 flutter analyze --no-pub는3건(info)으로 종료1이며 전부 기존 미추적 tools/roster_rebalance_domain_fixtures.dart의 상대lib import2/print1이다. 추적 활성 lib/test/tool 진단0, 신규 오류없음. 포맷12파일 변경0·git diff --check·문서 링크 확인.
- 미추적 실험/백업 파일은 hash 대조로 보존한다. 전체 분석 통과0건이라고 보고하지 않으며 남은3건을 숨기려고 tools 전체 exclude나 사용자 파일 수정을 하지 않았다.
- 사용자 기기: 안내한4개 인수 전부 통과 기록을 재사용한다. 이번에는 정상 런타임 흐름 변경 없이 테스트/분석 경계만 정리해 중복 기기 테스트를 요청하지 않는다. 신규 업무 API·동일캐릭터 역할 지원·Firebase 최종 SDK 제거·운영 배포는 미구현/미실행이다.
- Git: 사용자 승인 범위대로 전환·안정화 변경을 의미별 커밋으로 남겨 최신 origin/dev와 병합·push한다. 최종 커밋/동기화는 Git 이력에서 확인하고 별도 실험·백업의 dirty 상태를 분리해 보고한다. main·기존 브랜치는 유지한다.

## 2026-10-14 — 내 계정 Backend 1차 지시서 작성·Issue #3 게시

- 사용자 최신 요청으로 Firebase SDK 제거 전 내 계정 탭 복원을 위한 설계·Backend 구현 요청을 우선했다. dev a52492f의 Repository/DI·로컬 데이터·장비 인증·활동/대표 정책과 #2 확정 계약/최신 인계 댓글을 대조했다.
- docs/my-account-backend-phase1 생성: 내 계정 Backend 지시서·Issue 게시가 끝나면 종료되는 독립 문서 작업. 기존 계정/인증·분석 브랜치는 다른 완료 범위라 재사용하지 않았고 기존 dirty 실험/백업을 보존했다.
- 새로 가능해진 흐름: Backend가 13-my-account-backend-phase1-request의 명시적 요구로 계정 등록/summary·서버 장비 challenge/소유권·활동/대표 저장을 단계별 구현/계약 인계할 수 있다. 12개 기능/API 제안과 기본 칼럼·ID/권한/수명·오류·원자성·pytest·기록 방법을 작성했다.
- 게시: https://github.com/heo0328/lostparty-backend/issues/3 — [API] 내 계정 탭 1차 복원: 원정대 인증·캐릭터 조회·활동 선택 Backend 구현 요청. #1/#2 외 중복 요청 없음 확인 후 새 Issue를 생성했고 제목/본문을 로컬 지시서와 대조했다. 기존 Issue/PR·Backend 코드·DB는 변경하지 않았다.
- 보존 확인: 비로그인 로컬 기능·캐릭터/빌드/표시순서/토큰, Google 인증6API·내부 principal, 빈 신규 서버 정책. Firebase 과거 ID/사용자·테스터 데이터를 연결하지 않으며 조회/인증/활동 상태를 구분했다. 대표5분·최초seed예외 및 최초 unconfigured·ownership transfer 적용은 Backend 검토 전 제안으로 인계한다.
- 정확한 REST/DTO/DDL·identity 식별/충돌·provider key 준비·동시 인증/대표·등록 제거 의미는 Backend 검토/계약 인계 필요. 업체 응답/실제 장비 인증·신규 API·Flutter UI 연결은 미구현·미검증이다.
- 검증: 문서 내용/상대링크·git diff --check, Issue read-back 비교. 문서·Issue만 변경해 Flutter 테스트/analyze·기기 조작을 반복하지 않았다.
- 현재 계획/문서 지도를 내 계정 Backend 요청 우선으로 갱신했고 Firebase 실행 코드·SDK/플랫폼 제거는 후속으로 남겼다. 문서 미커밋, dev 반영/push 없음; docs/my-account-backend-phase1 유지.

## 2026-10-14 — Backend Issue #3 추가 계약 회신

- 사용자 확인: Firebase 제거 신규 APK에서 로그인·재실행·로그아웃 정상, 로컬 캐릭터 표시. 빌드 편집/저장·다른 OS 인수까지 확대 해석하지 않는다.
- 추가 요구6159800130을 확인하고 [회신](https://github.com/heo0328/lostparty-backend/issues/3#issuecomment-6159847616) 게시 후 body-file과 게시 본문 일치를 재조회로 검증했다. 전체 settings/page 분리·세 version/revision 일치·expected_roster_revision·409 사용자 재확인, suspect 비자격/재구성·로컬 보존·실 provider 근거 전 자동 missing/불완전 roster 이전 보류 방향을 회신했다. DELETE replay 및 만료 challenge 현재 상태 복구 보완 요청. key 준비·실 provider는 미확인.
- 새로 가능: Backend 추가 정의에 Flutter 소비 방향 전달. 기존 로그인·로컬 표시 보존은 사용자 확인; 신규 #3 API/권한/실 provider 인수는 아직 안 됐다.
- 문서만 기록, diff check·게시 본문 검증. 코드/설정/Backend DB 변경·Flutter 테스트 반복·commit/dev 통합/push 없음. docs/my-account-backend-phase1 미커밋 유지, 별도 Firebase 작업 트리도 미커밋 유지.

## 2026-10-14 — Backend 인계 후 Flutter 대응 작업 순서 확정

- 사용자 지시로 Backend 협의 구현 뒤 로컬 대응 계획을 기록했다. #3 최신 댓글·원격 dev OpenAPI 확인: 인증6API/health만 있고 업무 API/구현 SHA는 아직 미인계. 기존 AuthSessionController의 accessToken/refresh와 BackendApp의 로컬 AccountRepository/Router/DI를 조사했다.
- 14-my-account-flutter-integration-plan에 조회→등록→인증→활동/대표 순서, 첫 단일 그룹의 경계·권한·pagination/revision·private 세션 격리·기존 로컬 보존·검증을 기록하고 NEXT_WORK를 교체했다. 조회 계약이 먼저 인계되면 전체 Backend 완성을 기다리지 않고 해당 그룹부터 진행한다.
- 새로 가능: Backend 인계 후 Flutter 실행 범위/순서가 명확해짐. 보존: 기능 코드·SDK 제거 작업 트리·로컬 원본·별도 실험 변경 없음. 실제 #3 연결/기기 확인 미실행. 문서 검토·diff check만 실행, Flutter 테스트 반복 없음.
- docs/my-account-backend-phase1 미커밋 유지, dev 미반영·미push. Backend 댓글 추가 게시나 자동 작업 예약은 하지 않았다.

## 2026-10-14 — Backend #3 결과 확인·테스트 준비

- 이슈6160605157의 로컬12업무API/11테이블·114pytest 보고를 확인, Backend 보고와 직접 수행을 분리했다. 미커밋/미push·원격dev계약은 기존인증만이라 #2를 업무DTO로 대체하지 않는다.
- 직접읽기 확인: Windows localhost:8000 health200, 미인증GET등록401, /openapi.json404. WSL distro 조회는 sandbox 접근거절로 반환돼 재시도/설정변경하지 않았다. 로컬Backend checkout 두 후보경로 없음. 소스/개발문서를 확보했다고 주장하지 않는다.
- 새로 가능: 테스트 매트릭스·준비조건·실행순서/안전한결과기록 정의(15-my-account-test-readiness). 코드/Backend DB 변경·로그인/Bearer 입력·업무쓰기·기기조작 없음. 원격/로컬계약 인수와 Flutter조회연결이 다음실행 조건이다.
- 보존: 기존로그인/로컬자료/Firebase제거 작업트리·실험 변경없음. 실provider pending증거/roster보류/키없는503을 예상제한으로 명시. 업무API기기인수 미실행. 문서diff검사만, Flutter기존테스트 반복없음.
- docs/my-account-backend-phase1 미커밋/dev미반영·미push, 브랜치유지. Issue 댓글 추가게시 없음.

## 2026-10-14 — 에뮬레이터 서버 영역 부재: 기본 실행 경로 정렬

- 사용자화면:API토큰카드부터표시,서버에등록한계정영역없음. 기본source에주입없고기본APKkernel에서ServerAccountsPanel/DioBackendAccountReadApi/서버문구3마커모두없음,조회APK에는모두존재함을직접확인. 설치기기APK는읽거나조작하지않아단정하지않는다. 별도worktree와기본경로차이를충분히안내하지않은실행정렬문제다.
- 최소복구:기존feature/account-backend-read를기본workspace로재배치(조회worktree는동일HEAD detached,파일보존). 동일base·대상diff충돌검사후검증된source/제거결과개별복제. 새조회파일/테스트/고정계약추가,기존문서/미추적실험은보존. ignored.dart_tool에이전문서4개·미추적hash보관.
- 새로가능:기본프로젝트에서빌드/실행해도내계정API토큰카드위에서버등록영역연결. Domain/UI조회로직은검증된원본과byte일치,소스테스트1159/분석0기존결과재사용. 로컬DB/키·원격DB·Google설정변경없음. 앱삭제뒤서버조회는회원등록관계에따르며기기자료자동복구/옛Firebase이관과구분한다.
- 미확인:기본새APK의기기화면/신규Backend회원등록조회. 사용자에게카드존재1항목부터확인하도록명확히전달한다. 기기설치/삭제/ADB조회·인증된서버요청없음. Git미커밋/dev미반영·미push유지.

- 복구최종검증:기본경로Androiddebug빌드61.9초성공,APKkernel기능3마커존재·Firebase플러그인부재,기존미추적39개hash보존확인. 식별쉬운동일APK사본 lostparty-account-read-debug.apk 제공,표준app-debug.apk와SHA256일치. 소스논리수정없어기존1159검증재사용·diffcheck.

## 2026-10-14 — 서버 계정 조회 구간 사용자 인수 1·2·4 통과

- 사용자 보고: 로그인하면 서버 등록 없음 안내, 로그아웃하면 로그인 후 서버 계정을 볼 수 있다는 안내. 안내한 1·2·4번 모두 정상 확인했다. 기본 프로젝트 실행 경로 복구 후 서버 영역 표시와 로그인/guest 전환의 실기기 확인이다.
- 새로 가능해진 흐름: 신규 회원의 서버 빈 등록 목록을 앱에서 정상 조회하고 로그인 상태에 따라 서버 영역을 전환한다. 사용자가 1번을 포함해 통과라고 확인한 로컬 화면 보존을 기록한다. 빌드 편집/저장, 키 보존, 유지 선택 재실행까지 새로 수동 통과했다고 확대 해석하지 않는다.
- 3번 등록된 계정의 전체 캐릭터 화면은 등록이 없어 미확인이다. Backend에는 고정 계약의 preview/등록 CRUD API가 있으며 Flutter 등록 관리 UI/쓰기 연결이 아직 없다. 'Backend 등록 시스템 없음'으로 기록하지 않고 다음 등록 관리 구간에서 계정 생성 후 확인한다.
- 자동 검증은 기존 조회 소스1159테스트/분석0 결과와 기본경로 APK 빌드 성공·기능마커 검증을 재사용한다. 이번에는 코드 변경 없이 문서만 반영, diff check만 실행한다. 서버 DB/설정·기기 조작·Issue 댓글 게시·commit/dev 통합/push 없음.
- 현재 조회 구간은 구현·자동 검증·가용한 사용자 1·2·4 인수 완료. 등록 자료가 필요한 3번은 후속 인수로 분리한다. Git은 feature/account-backend-read 미커밋·dev 미반영·미push 상태이며 통합 전 브랜치를 유지한다.

## 2026-10-14 — Firebase 제거 복구 지점 커밋

사용자가 문서 최신화·dev 병합·push를 승인했다. 검증된 선행 Firebase 제거/UTC 공통 정책 이식·플랫폼/Rules 도구 정리를 현재 feature/account-backend-read에서 별도 의미의 커밋으로 분리한다. 제거 원본은 dev a52492f, source/test 원본 복구 목록은 FIREBASE_REMOVAL_MANIFEST, 후속 조회 기반 hash는 ACCOUNT_READ_PREREQUISITE다. Google OAuth/비밀 설정·로컬 DB·기기 설치/원격 DB 변경 없음. 원본 제거1134테스트 및 최종 조회1159검증은 각 당시 결과로 구분하며 현재 코드 동일성과 사용자 인수를 근거로 재사용한다.

## 2026-10-14 — 완료 구간 문서 최신화·dev 통합 마감

- 사용자 명시 승인에 따라 Firebase 제거 a160c6f, 서버 계정 조회 6f97190을 별도 의미의 커밋으로 기록하고 요구·연결/테스트 준비·인수 문서를 최신화한다. 원격 origin/dev는 시작 기준 a52492f와 같았다. 문서 커밋 후 최신 원격을 다시 확인해 feature/account-backend-read를 dev에 일반 merge하고 push한다. 최종 결과는 Git HEAD/dev/origin/dev와 종료 보고로 확인한다.
- 새로 가능해진 흐름은 Firebase SDK 없는 BackendApp과 로그인 회원의 서버 등록/전체 캐릭터/settings 읽기다. 사용자1·2·4 통과, 서버 등록API는 구현돼 있지만 Flutter 등록/인증/활동쓰기는 다음 그룹이며 3번 실제 등록 캐릭터는 후속 인수다.
- 최종 소스는 기존1159테스트/분석0 통과 작업 트리와 byte/줄바꿈 정규화 비교 일치했고 기본 경로 Android debug 빌드·kernel3마커를 확인했다. 코드가 바뀌지 않아 전체 검증을 반복하지 않았다. 문서 diff/스테이징 목록/고정 계약hash와 기존 미추적36개hash를 검증한다.
- 기존 미추적 실험·백업36개는 커밋/삭제/이동하지 않고 그대로 보존한다. phantom 수정으로 표시되던 raid_cycle_schedule.dart는 실제 diff가 없으며 파일 내용을 변경하지 않는다. 원래 worktree·main·기존 local/remote 브랜치는 삭제하거나 갱신하지 않는다. 순수 관련 문서와 검증된 코드만 통합하고 운영 배포/Backend DB 변경/새 API 쓰기 없음.
- 현재 작업 feature/account-backend-read는 통합 후 삭제 후보로만 분류하며 자동 삭제하지 않는다. 별도 원본 worktree에는 미커밋 snapshot이 있어 보존/정리 지시 전 그대로 유지한다. 현재 기본 checkout은 dev로 종료하며 추적 변경 없음과 기존 미추적 보존을 구분해서 보고한다.

## 2026-10-14 — 등록 관리 Backend 요청·조회 결과 인계

- 사용자가 지시한 Backend 요청 작업을 사용 한도 중단 뒤 재개했다. 최신 #3의 6161587868 Flutter 결과 요청을 확인하고 [회신/작업 요청](https://github.com/heo0328/lostparty-backend/issues/3#issuecomment-6161970774)을 게시했다. 소비 Backend SHA254cb5d와 Flutter dev 통합3cedd9d·조회 구현6f97190, 1159 자동 검증과 사용자1·2·4 인수, 등록 자료가 필요한3번 및 아직 미연결인 쓰기 범위를 구분했다.
- 새로 가능해진 흐름: Backend가 다음 등록 관리 구간의 필요 준비와 Flutter 검증 근거를 이슈에서 확인할 수 있다. 기존5개 등록 API 재개발을 요청하지 않고 로컬 실행 버전/0002·서버 Lost Ark key 준비 여부(값 제외)·실 preview/등록 시험 조건·계약 차이가 있을 때만 최소 보완과 변경 SHA 인계를 요청했다. 실제 등록/장비/활동 인수를 완료로 보고하지 않았다.
- 보존: Flutter 기능 코드·설정·기존 로컬 자료·원본 worktree·미추적 실험/백업을 수정하지 않았다. Backend 코드/DB·운영 배포·자료 초기화·provider 증거 우회는 요청하지 않았다. 서버 키 준비·실 provider와 등록된 캐릭터 화면의 사용자 인수는 후속이다.
- 검증: 요청 문서/고정 계약·현재 Git 및 최신 댓글 대조, 게시 본문과 body-file 일치 재조회, 문서 diff check. 코드 변경이 없어 Flutter 테스트/analyze/빌드를 반복하지 않았다.
- 기존 docs/my-account-backend-phase1을 dev3cedd9d로 fast-forward해 재사용했다. 요청17 및 관련 지도/계획/로그는 미커밋·dev 미반영·미push, 브랜치 유지. 이전 구현 구간 dev/origin/dev 통합·push 완료와 이번 문서 상태를 구분한다.

## 2026-10-14 — Backend 요청 문서 통합 승인

사용자가 현재 작업의 커밋·dev 병합·push와 이후 내 계정 디자인 수정을 지시했다. 게시 검증된 요청17과 관련 문서5개만 커밋하며 기존 미추적 실험36개는 제외·보존한다. 순수 문서 diff 검토/diff check를 재사용하고 최신 origin/dev를 확인해 통합한다. 새 화면 작업은 메인 계정→부계정→기타 기능 순서 재배치 완료를 종료 조건으로 별도 목적 브랜치에서 진행한다. Git 최종 SHA/동기화는 실행 결과가 기준이다.

## 2026-10-14 — 내 계정 화면 캐릭터·레이드 우선 배치

- 이전 Backend 요청 문서26f11fd를 dev에 병합06758d1하고 일반 push 후 실제 origin/dev SHA 일치를 확인했다. 미추적 실험/백업36개는 제외·보존했다. 기존 feature/account-character-dashboard를 dev로 fast-forward해 재사용하며 별도 새 브랜치를 만들지 않았다.
- 사용자 요청으로 구현 전 NEXT_WORK에 순서/보호/범위를 기록하고 메인 계정 등록 현황 → 부계정 등록 현황 → 계정 도구 순서로 재배치했다. 메인 계정 최초36px 여백을 제거하고 기존 캐릭터 카드·레이드 정보를 상단에 배치, 부계정 추가를 부계정 제목 옆으로 이동했다. 서버 등록 안내·API 토큰/인증·조회 입력/조회 프로필은 하단 도구에 유지한다.
- 새로 가능해진 흐름: 첫 화면에서 등록된 메인 캐릭터 정보를 먼저 보고 부계정과 도구를 이어서 이용한다. 메인/부계정 없는 상태를 별도로 안내한다. 기존 계정·캐릭터의 자료/대표·표시순서·소유 상태·누락 경고와 확인/편집/갱신 콜백은 재사용하며 Router/DI·Repository·DB·Auth/Backend 계약을 바꾸지 않았다.
- 검증: 기존 내 계정 페이지 테스트10개 통과(360×800 순서/카드 화면 내 배치·인증/상실/불일치 표시·누락 삭제·조회/입력 검증·부계정 추가/삭제·수동갱신), 변경Dart2파일 분석0, 포맷·diff check. 기존 테스트의 이동된 버튼 접근/레이아웃 기대만 수정했다. 도구가 재생성한 플랫폼 plugin 파일은 HEAD와 내용 동일 확인 후 인덱스 표시만 정리했다. 공용/정책 변경이 없어 전체1159 검증은 반복하지 않았다.
- 미확인 실기기: 실제 메인/부계정 캐릭터 수에서 화면 밀도, 하단 서버 로그인 안내·토큰/조회 도구 접근, 관리·주간 표시/부계정 추가. APK 설치/기기조작·서버 쓰기는 실행하지 않았다. 기본 프로젝트 최신 작업 브랜치에서 사용자가 빌드해 확인한다.
- 디자인 작업은 feature/account-character-dashboard 미커밋·dev 미반영·미push로 사용자 인수 대기, 브랜치 유지. Backend 등록 관리/실provider 후속은 별도 그룹으로 보존한다.

## 2026-10-14 — 내 계정 디자인 확정·dev 통합 승인

- 사용자가 현재 내 계정 디자인 유지를 확정하고 dev 병합·push를 지시했다. 배치만 승인받았으며 개별 도구/레이드/서버 쓰기 동작을 새로 실기기 통과했다고 확대 기록하지 않는다. 신규 기능 코드 수정 없이 완료 디자인과 기존 페이지 테스트/관련 문서를 함께 커밋한다.
- 새로 가능해진 흐름: 메인 캐릭터/레이드 정보를 먼저 보고 부계정과 하단 도구를 이용하는 배치가 통합 기준에 반영된다. 보존 근거는 기존 페이지10개 테스트의 조회/추가·삭제/갱신/상태 표시 회귀 통과와 diff 검토다. 실제 캐릭터 수/기기별 밀도와 개별 도구 조작의 추가 실기기 기록은 없다.
- 검증은 직전 최종 소스의 페이지10개·변경Dart2파일 분석0·포맷 통과를 재사용한다. 이후 기능 코드는 바뀌지 않아 테스트/빌드를 반복하지 않는다. 문서 내용/diff check·staged 대상·기존 미추적36개 hash·최신 origin/dev를 확인한다.
- feature/account-character-dashboard를 dev에 일반 병합 후 일반 push한다. 종료는 dev/origin/dev의 최종 SHA 일치·추적 변경 없음으로 확인하고 기존 미추적36개/원본 worktree는 보존한다. 해당 작업 브랜치는 유지하며 삭제 후보로만 분류한다. Backend 요청 회신/등록 관리 구현·main 병합·운영 배포는 이번 범위 밖이다.

## 2026-10-14 — 서버 등록 관리 신규 Backend 이슈 제안

- 사용자 지시로 다음 등록 연결 작업 전 신규 [Backend 이슈 #4](https://github.com/heo0328/lostparty-backend/issues/4)를 생성했다. 제목: [Integration] 서버 계정 등록 관리: 실제 API 검증·Flutter 연동 인계 제안. #3 최신6162243552와 게시된 계획을 확인해 계약254cb5d·보완db0f3ae·게시f5b4a2a 및 완료된 lease409 Retry-After 수정/대상10개 결과를 근거로 분리했다.
- 새로 가능: 다음 Backend 구간의 키 준비 지원·실 siblings/summary 및 사용자 등록 CRUD 인수·재현된 차이 최소 보완·버전 인계를 #4에서 추적한다. 기존5개 등록 API 재작성/완료된 헤더 수정은 요청하지 않았다. 사용자 키 준비와 Flutter UI 연결 이후 공동 인수이며 서버 키는 최신 Backend 보고상 미준비다.
- 보존: 기존 #3/#2/PR·Backend 코드/DB·운영 상태·Flutter 기능/디자인·로컬 자료를 변경하지 않았다. 원정대 장비 증거/소유권 이전·활동/대표 쓰기 인수는 이후 별도 범위다. 실제 등록/API/provider 테스트는 이번에 실행하지 않았다.
- 검증: 기존 이슈 목록/최신 인계/게시 계획 확인, 신규 이슈 본문과 요청18 일치 재조회, 문서 내용·diff check. 문서/Issue 제안만 수행해 Flutter 테스트/빌드를 반복하지 않았다.
- 기존 docs/my-account-backend-phase1을 dev69d3aaa로 fast-forward해 재사용. 관련 문서는 미커밋·dev 미반영·미push이며 브랜치 유지, 기존 실험/백업36개와 원본 worktree 보존. 새 기능 구현은 시작하지 않았다.

## 2026-10-14 — #3 완료를 위한 Flutter 서버 등록 관리 연결

- 사용자 지시로 #3 본문/최신 인계 및 #4 상태를 확인했다. #3 Backend 보완db0f3ae·계약254cb5d를 소비해 다음 단일 등록 관리 그룹을 구현했다. #4 제안 당시 미커밋 문서는 보존하며 feature/account-backend-registration을 기본 경로에 생성했다.
- 새로 가능해진 흐름: 하단 계정 도구→서버 계정 등록·관리→캐릭터 검색 preview/메인·부 등록→목록/캐릭터 조회→label/main 수정·refresh·확인 후 등록 제거. 요청 유실에서는 key/body를 유지한 명시 재시도와 GET 결과 확인을 제공한다. 서버 UUID/상태와 로컬 자료를 합치지 않는다.
- 보존 확인: 기존 Auth session/generation·읽기Repository/Strict DTO/401/업무403 정책을 사용하고 이전 전체1159테스트가 최종상태에서 통과했다. 새17개는 불변key/body·DELETEquery/204·preview만료/잘못된JSON·401동일요청재전송·403·429/진행중대기·late session·24h와 GET복구·응답대상UUID/malformed성공을 검증했다. 로컬 DB/API키·대표/표시·기존 디자인을 변경하지 않았고 기존 실험/백업36개hash보존을 확인했다.
- 최초검증에서 신규 테스트의 필수 인수/스타일과 빈 Retry-After 배열fixture 문제를 수정했다. 필요한 대상17개 경계와 최종 전체1176테스트 통과, lib/test 분석0·포맷/diff check, Androiddebug 빌드37.9초·APK기능마커 확인. 공개mock/개발DB삽입/secret출력 없이 fake Dio를 사용했다. 이번 테스트를 실제provider/서버transaction 인수로 보고하지 않는다.
- 기본APK build/app/outputs/flutter-apk/app-debug.apk SHA256 1f42b5c5734f75501eaba765d55d983af4ba78a31078986785e4356bcd50e633. 기기설치/조작은 하지 않았다. 사용자는 서버키준비 후 검색/등록·두조회/수정/갱신/등록제거·로컬보존을 확인한다. 최신Backend보고 key미설정으로503이예상되며 실제등록/조회3번 인수는 남아있다.
- 메모리command는 앱 수명 동안만 유지한다. 재실행은 GET만하고 이전 쓰기를 자동재현하지 않는다. 세션/회원변경은입력·preview·진행요청/late응답을격리한다. 장비challenge·소유권이전·활동/대표쓰기와 live인수는다음그룹이라 #3 Issue를종료하거나전체완료로표시하지않았다.
- feature/account-backend-registration 미커밋·dev 미반영·미push로 사용자인수대기, 브랜치유지. 원본worktree/기존브랜치 보존, BackendDB/원격Google설정·운영배포/Issue추가댓글변경없음.

## 2026-10-14 — 서버 등록·삭제·재로그인 후 원정대 표시 사용자 확인

- 사용자 직접 확인: Google 로그인 이후 서버 캐릭터 정보 등록과 삭제, 로그아웃 후 재로그인 시 등록해 둔 원정대 캐릭터들이 표시됨. 실제 서버 등록 자료와 재로그인 뒤 조회 유지에 대한 수동 통과로 기록했다. 이전 서버키미준비 보고는 준비 당시 이력이며 현재 실제 등록이 불가능하다고 보고하지 않는다. key/env·DB를 직접 검사한 것은 아니다.
- 새로 가능해진 흐름의 사용자 확인: 서버 등록/제거와 같은 회원 재로그인 후 등록 원정대 캐릭터 표시. 보존 근거는 서버 등록이 재로그인 후 유지됐다는 사용자 보고다. 삭제 후 기존 로컬 캐릭터/빌드 보존, 수정/메인 전환·정보갱신, 재실행/재설치·소유권/장비인증·실provider형식전체 인수까지 통과로 확대하지 않는다.
- 남은 등록관리 수동 확인은 표시명/메인 변경·정보갱신·등록제거 후 로컬보존으로 좁혔다. 장비 인증·활동/대표 저장은 이후 독립 그룹이며 #3 전체완료로 표시하거나 Issue를 닫지 않았다.
- 이번 변경은 문서뿐이다. diff check/내용 검토, 기존 최종1176테스트·분석0/debug빌드 결과 재사용; 코드·API/DB·기기조작·테스트반복·새 Issue 댓글 게시/commit/dev병합/push 없음. feature/account-backend-registration 미커밋·dev 미반영·미push/브랜치유지, 기존 원본·실험/백업 보존.

## 2026-10-14 — 미입력 이름 자동 표시 단순 구현

- 사용자 최종 지시를 적용해 미입력값은 위치에따른자동이름, 입력값은그이름을표시하도록구현했다. 처음착수시추가했던 customLabel컬럼/schema14·기존이름복사migration·자동이름스위치는중단/정정지시후제거했다. schema13유지·기존label필드만사용, 불필요해진Drift생성과도구의DTO생성파일삭제는원래상태로복구했다. 별도데이터보존/이관·패턴판별을구현하지않았다.
- 새로가능: 새본계정/빈이름부계정등록·수정에서빈label을저장, 조회시본계정은메인 계정/부계정은id순서부계정 n을계산한다. 표시값이입력필드에저장되지않아본부전환에서표시만바뀐다. 입력한이름은그대로표시하고비워서저장하면자동이다. 현재이미입력값으로저장된문자열은사용자가지우면자동으로표시한다.
- 검증: 전체1178테스트/lib-test분석0·diffcheck, 빈이름본부전환/삭제후번호·사용자이름유지/비워서전환을새2개Repository/실메모리DB테스트로확인. 기존등록/로그인/캐릭터흐름도전체묶음통과. 사용자기기설치/조작/실서버이름변경은하지않았다.
- Backend #4 댓글6163006876에올렸던새필드/보존제안은최종단순규칙으로정정하고본문일치재조회했다. existing label빈문자열/nullable요청·PATCH생략/명시빈값의의미만확정하도록요청했으며과거데이터복구/보존을요구하지않았다. 서버계약인계전wire를임의변경하지않아현재서버자동이름은후속이다.
- feature/account-backend-registration 기존미커밋결과포함미커밋·dev미반영·미push,브랜치유지. 새기능코드외Git통합/원격DB삭제/운영배포없음. 기본debugAPK의사용자인수는이름빈값/직접값·본부전환이름표시다.

## 2026-10-14 — 정보 갱신 RefreshOut 응답 처리 수정

- 사용자1번진행지시로기존feature/account-backend-registration에서갱신파싱만수정했다. 계약254cb5d RefreshOut은registration wrapper인데원RegistrationOut으로읽던Flutter오류였다. 계획/NEXT_WORK기록후실제wrapper회귀에서정상갱신과진행중재시도2실패를수정전재현했다.
- 새로가능: POST refresh {}성공을내부registration으로검증해pending종료/처리안내후기존페이지GET으로최신목록을확인한다. 미인증added_count=0도성공이며유효하지않은wrapper/타입/등록ID는INVALID_RESPONSE로남는다. 원본동작확인:기존등록/PATCH/DELETE/401·업무403/세션·멱등key/payload경계가대상묶음에서통과했다. 이번수정에새데이터저장·서버DB/API/이름계약/UI변경을섞지않았다.
- 검증: server backend_read49개(기존42+신규7)통과·변경3Dart파일분석0·포맷/diffcheck·AndroiddebugAPK빌드19.4초성공. 이전잘못된flat refreshfixture를실제응답구조로정정. 국소parser수정이라직전전체1178검증을반복하지않았고전체1185통과로보고하지않는다. 코드/빌드실행과실서버/기기인수는구분한다.
- 미확인기기:서버계정등록관리의정보갱신버튼후처리안내/현재목록재조회. 새기본APK제공,기기설치/조작/업무API호출없음. 기능과관련문서미커밋·dev미반영·미push,현재브랜치유지. 기존미커밋작업/실험/백업및원본worktree는수정/삭제하지않았다. 외부이슈댓글이나서버계약을새로변경하지않았다.

## 2026-10-14 — 정보 갱신 확인 방법·화면 안내 개선

- 사용자보고:진입후일반완료문구가깜빡이고목록이같아무엇을확인해야하는지불명확. 실제결과수가없고app수명의ViewModel에이전notice가남는표시문제였다. API추가나데이터설계없이기존RefreshOut결과를사용해표시를수정했다.
- 새로가능:정보갱신성공에계정명/새캐릭터·확인필요수/서버조회시각·추가갱신필요여부표시,목록카드에도서버조회시각. 새진입은이전완료안내만지워새실행처럼보이지않는다. 미완료요청/오류·세션/멱등흐름은그대로이며진입refresh자동요청없음.
- 검증:Backend읽기/등록대상50개·변경3파일분석0·포맷/diffcheck통과. 기존정상0추가에구체문구검증과완료notice초기화를확인,새미확인명령유지경계1개를추가했다. 전체테스트를불필요하게반복하지않았다. 실제기기는정보갱신후현재결과/서버시각확인대기다.
- feature/account-backend-registration의기존미커밋결과에포함,dev미반영/미push·브랜치유지. 서버코드/DB·이름계약·외부Issue게시/기기설치/조작없음.

## 2026-10-14 — 등록 관리·자동 이름·갱신 구간 dev 통합과 전투력 후속 기록

- 사용자 최신 지시로 현재 구간을 커밋·dev 일반 병합·push 후 대기한다. 최신 갱신 안내는 사용자가 정상 작동을 확인했다. 새로 가능해진 흐름: 서버 등록/관리와 요청 결과 확인, 로컬 빈 이름의 위치별 표시, 실제 갱신 수·서버 조회 시각 확인. 서버 등록·삭제·같은 회원 재로그인 뒤 원정대 표시는 앞선 사용자 확인을 재사용한다.
- 보존 확인: 전체1178테스트·lib/test 분석0 당시 로그인/로컬/등록 흐름과 이름 정책 검증, 이후 국소 갱신 수정의 읽기/등록 대상50개·변경파일 분석0·debug APK19.9초 성공. 이번에는 문서만 갱신해 동일 Flutter 테스트/빌드를 반복하지 않는다. diff/staged 검토·diff check와 기존 미추적36개 hash를 확인한다.
- 전투력 조사: 표시 UI/nullable DTO는 존재한다. Backend dev e807a6f의 observations.py는 일반 siblings→combat_power=None, proof 조회만 검색 캐릭터 ArmoryProfile.CombatPower를 채운다. 로컬 sibling DTO에도 전투력 필드가 없고 별도 검색 프로필만 조회한다. 전체 캐릭터 전투력 수집·저장/갱신·앱 표시 연결을 NEXT_WORK 후속으로 기록했으며 구현·새 Backend Issue 요청은 시작하지 않았다.
- 미확인 실기기 항목: 서버 표시명/메인 수정의 전체 흐름, 등록 제거 후 로컬 자료, 재설치·장비 인증/소유권 이전·활동/대표 저장. 서버 빈 이름은 Backend 계약 인계 대기다. 현재 구간 통합이 #3 전체 완료나 전투력 구현 완료를 뜻하지 않는다.
- Git: feature/account-backend-registration 결과와 관련 문서만 커밋해 최신 origin/dev에 통합·push한다. 기존 실험/백업36개는 그대로 두고 작업 브랜치는 유지/삭제 후보다. main/Backend 코드·원격 데이터/Issue·운영 배포는 변경하지 않는다. 통합 종료 SHA와 원격 일치는 실행 결과로 확인한다.

## 2026-10-14 — Backend GitHub Issues 협업·콜백 공통 규칙 명문화

- 사용자 요청: 별도 공유 방식 채택 전까지 Backend Issues를 협업 채널로 사용하고 구간별 피드백·작업·테스트 요청의 기록과 콜백을 빠뜨리지 않는다. 이번 문서 작업은 사용자 명시 지시에 따라 dev에서 직접 진행했다.
- 조사 결과: Backend 요청13/17/18에는 Issue 인계·회신 내용이 있었으나 모든 작업에 자동 적용하는 공통 콜백 규칙은 없었다. AGENTS.md에 핵심 실행 규칙, ai_rules.md에 착수 확인→요청 추적→결과/미해결 회신→후속 담당/완료 조건→게시 재확인과 문서 링크 기록을 추가했다. 승인된 구간의 관련 Issue 댓글 회신은 상시 승인으로 명시했다.
- 새로 가능: 이후 작업에서 로컬 기록/사용자 보고와 Backend 회신을 함께 완료 조건으로 확인한다. 기존 기능 코드·API/DB·Issue/PR은 변경하지 않았다. 미확인 실기기 항목은 추가 없으며 이전 후속 범위는 유지한다.
- 검증: 문서 내용·상대 링크 대상·git diff --check. 순수 문서라 Flutter 테스트/빌드를 반복하지 않는다. 현재 dev의 문서 수정은 미커밋·미push이며 기존 실험/백업 파일은 그대로다.

- 추가 명확화: 피드백·테스트 요청은 협업상 필요시만 수행한다. 모든 작업의 요청/댓글 의무화와 확인된 결과의 반복 요구를 배제하고, 실제 협업 요청에 대한 결과 회신·필요한 인계는 유지한다. 문서만 수정, 미커밋·미push 유지.

- 사용자 후속 커밋·푸시 지시: 협업 규칙 문서5개만 dev에서 커밋·일반 push한다. 최신 원격 dev와 차이 없음 확인, diff check/내용 검토 통과. 기능 코드와 외부 Issue는 변경하지 않고 기존 미추적 실험/백업을 제외한다.

## 2026-10-14 — Issue 우선 미처리 인계 조사

- #3/#4 OPEN 최신 댓글과 Backend dev40aea9b를 확인. #4 빈 이름 계약d3cb697은 a6d25aa에 통합되어 인계 대기 문구를 정정했다. Flutter 빈 label wire/DTO/전체 목록 번호 연결이 남아 신규 API 요청 산출을 우선하지 않는다.
- 기존 등록관리 결과의 누락 회신을 Issue4 댓글6164864407로 게시·본문 재조회 일치 확인. 실제 사용자 확인과 자동 검증·미확인을 구분했고 새 Backend 작업/테스트를 요구하지 않았다.
- 문서 조사만 수행: docs/my-account-backend-phase1을 dev2bc70d8로 fast-forward 재사용, NEXT_WORK/AI_CONTEXT 정정. diff check/내용 검토, 기능·API/DB·기기/Flutter 테스트·빌드 변경 없음. 미커밋·dev 미반영·미push, 기존 실험/백업 유지.

## 2026-10-14 — 다음 서버 빈 이름 연결 설계·문서 통합

- 사용자 지시로 NEXT_WORK를 다음 단일 구간의 근거·포함/제외·계약/데이터 흐름·순서·회귀·완료 조건으로 재정리했다. Backend d3cb697 새 빈 이름 연결을 우선하고 전투력·장비/활동은 후속으로 둔다. 이름 계약20과 AI_CONTEXT에 최신 인계 상태를 반영했다.
- 새로 가능: 다음 착수 시 기존 feature/account-backend-registration 재사용 판단부터 새 wire/DTO/전체목록표시·신규인수·Issue회신까지 진행 기준 확인. 기존 코드·등록/로그인 흐름과 확인 결과는 변경하지 않았다. 신규 미확인 실기기 항목은 이름미입력/clear·본부전환/번호이며 아직 실행하지 않았다.
- 문서만 변경해 내용 검토/diff check 수행, Flutter 테스트/빌드 반복 없음. docs/my-account-backend-phase1에서 관련 문서4개만 커밋·최신 dev 일반 병합·push하고 원격 일치를 확인한다. 기존 실험/백업36개·브랜치 유지, 기능·새Backend요청/테스트·Issue종료·main/배포 변경 없음.

## 2026-10-14 — 서버 빈 이름 계약 Flutter 연결 구현

- 사용자 작업 진행 지시로 기존 feature/account-backend-registration을 dev44d6cde로 fast-forward 재사용. 원본 d3cb697 snapshot/sha256 기록, 기존 스키마 차이는 RegisterIn/PatchIn/RegistrationOut 및 label 정책뿐임을 대조했다.
- 새로 가능: 서버 빈label 등록/clear·빈응답 DTO·전체 GET 순서 자동 번호, 지정 이름 유지, 목록/수정/삭제·상태확인 표시. 저장값과 표시값 분리, 이름 입력창은 저장label 사용. 기존 공통 AccountLabelPolicy를 사용하며 새 칼럼/DBmigration/이관·이름패턴판별 없음.
- 보존 확인: 전체1193테스트/lib-test분석0·포맷/diffcheck. 신규7개는 페이지/번호/본부전환/삭제·빈PATCH동일key재시도/빈응답·불량label/다른필수값, 기존 로그인·등록/TTL·204·갱신/세션경계 함께 통과. Router/DI·DB/HTTP추가 없이 계정공통모델/정책 영향 검증으로 전체를 최종1회 실행했다. 기존 실험/백업36개 hash동일.
- Debug APK33.4초 빌드 성공, 사용자기기설치/조작 없음. 미확인 실기기: 이름미입력등록·지정이름/clear·본부전환·지정이름포함 부계정번호. 이전 등록/재로그인·갱신 통과는 반복 요구하지 않는다. 전투력/장비/활동은 범위 밖.
- [Issue4 회신6166099894](https://github.com/heo0328/lostparty-backend/issues/4#issuecomment-6166099894) 게시·본문일치 재조회. 소비SHA/자동검증과 실제인수대기·미커밋/미push 상태를 구분했고 새 Backend 작업/테스트는 요구하지 않았다. 새Fluttercommit없음, feature브랜치 유지·dev미반영·미push로 사용자 인수 대기.

## 사용자 인수 완료 (2026-10-14)

사용자가 신규 이름 확인4항목을 전부 정상 작동으로 확인했다. 미입력 등록/자동표시·지정이름/clear·본부전환·지정이름 포함 번호 인수 완료. [Issue4 결과 회신](https://github.com/heo0328/lostparty-backend/issues/4#issuecomment-6166283832) 게시·본문재조회 일치 확인. 코드 변화 없이 전체1193테스트/분석0/debug빌드 결과를 재사용한다. 현재 feature/account-backend-registration의 기능/문서 미커밋·dev미반영·미push, 다음은 Git정리·통합 인계다. 장비/전투력/활동은 후속으로 유지한다.

## 2026-10-14 — 서버 자동 이름 사용자 인수 결과 Git 통합

- 사용자 진행 지시로 구현·snapshot·테스트·관련 문서를 커밋해 dev에 일반 merge·push한다. 전체1193테스트/분석0/debug33.4초 및 신규 이름4흐름 사용자 통과를 재사용하고 코드 변화가 없어 반복 검증하지 않는다. 내용/diff/staged검토와 원격dev 최신 여부를 확인한다.
- 현재 새로 가능한 서버 빈이름/clear·본부전환/전체목록번호 흐름 완료. 기존 등록/세션/갱신 검증 보존, 미확인 장비·전투력·활동/대표 등은 후속으로 둔다. NEXT_WORK를 전투력 협업 설계 후보로 정리했으며 새API 요청·구현을 시작하지 않았다.
- 통합 적용 SHA와 소비계약d3cb697을 Backend #4에 회신하고 재조회 확인한다. feature브랜치는 유지/삭제 후보, dev/origin/dev일치·추적변경없음으로 마무리한다. 실험/백업36개 제외, main/운영배포·원격DB 변경 없음.

## 2026-10-14 — 전투력 수집·갱신 Backend 협업 요청

- 사용자 진행 지시로 최신 #4/Backend dev78a5494를 확인했다. 기존 이름/Git인계는 상대확인6166402144로 해소됐고 새처리요구없음. 최신observations/service/provider의 일반combat_power=None/proof만수집·미인증power정보·canonical캐시·quota/동시성/timeout 경로를 대조했다.
- 새로 가능: 요청21과 [Issue5](https://github.com/heo0328/lostparty-backend/issues/5) 생성·본문일치 재조회로 프로필전투력/미인증캐시·필요대상작은묶음·부분실패/미제공·GET반환·최소API확정/구현 인계를 요청했다. 상한6/TTL30분은 제안이다. main로컬카드도 서버화면과별도연결해야함과 역할Snapshot 비덮어쓰기·회원격리를 명시했다.
- 보존: 기존 이름/등록·인증·DB/Flutter코드 변경 없음. 미확인 실제provider/앱표시·Backend새계약은 인계후이며 테스트 통과로 확대하지 않는다. 작업은 설계/Issue요청만으로 문서내용/diffcheck/본문검증, Flutter테스트/빌드/업무API호출 반복 없음.
- docs/my-account-backend-phase1을 최신dev266a7e2에서재사용, 관련문서미커밋·dev미반영·미push. 기존 실험/백업 유지. #3/#4종료·main/배포·원격초기화 없음.

## 2026-10-14 — Issue5提案 소비 검토 회신

- 최신Backend6166675659확인,기존Flutter1700상수·Dio10초·StrictGET DTO대조. 20명/20초 및부분상태소비가능,전투력만30초타임아웃연결과deferred/replay규칙을6166739099로회신·재조회일치확인. 정확한DTO/GET상태/서버총예산·구현계약SHA인계대기.
- Backend22테스트는상수/parser보고이며전체REST/실provider완료아님. 문서/회신만변경,Flutter코드/테스트/빌드·서버DB변경없음. diffcheck/내용검토, docs/my-account-backend-phase1미커밋/dev미반영/미push유지.

## 2026-10-14 — Issue5 구현·로컬적용 보고 확인

- Backend6166983632확인: REST/cache0003·GET새필수3필드·대상42/후속3별도·실profile미인수·미커밋/미push. FlutterStrictDTO새필드거절영향과게시SHA대기를6167001322회신/본문일치확인했다. 문서/diffcheck만,기능/테스트/빌드변경없음. 기존문서브랜치미커밋/dev미반영/미push유지.

## 2026-10-14 — 39188d5 전투력 Flutter 연결

- 사용자Backend게시/재개지시로Issue5최신6167071680와원본39188d5를확인하고snapshot고정. docs브랜치미커밋요청/회신문서를유지한채feature/character-combat-power생성(dev266a7e2기반),정확한범위/데이터흐름/회귀를NEXT_WORK에먼저명시했다.
- 새로가능:GET새필수3필드/POSTStrict검증·power요청만30초·기존등록VM불변key/본문/단일pending재사용·실제0/부분결과안내·GET표시캐시,서버화면/내계정머리글속도계·로컬카드server/name매칭·선호역할Snapshot우선·회원세대리셋/lateGET폐기. 초기GET만하며POST자동polling없음,로컬DB/roleSnapshot쓰기없음.
- 검증:새전투력경계와기존읽기/등록68통과→전체1204/lib-test분석0. 최종검토새등록직후cache목록누락/조회중회원변경보완·신규2경계후관련70/최종분석0통과. 국소보완뒤전체를반복하지않으며전체1206통과로확대하지않는다. fakeDio로부분결과/불량형식/숫자·대상/동일key·timeout·0·선호role/서버명매칭·회원변경·1700/20명순서를확인했다.
- 보존:기존등록/빈이름/204/세션·GET정책/로컬빌드는테스트/diff로확인. 포맷범위를넓게실행해7개무관파일도포맷된것을확인했다. 초기clean/순수공백trailingcomma비교증명뒤HEAD복구,추가리팩터링없음. 기존실험/백업36개hash동일. 미확인실제profiles/사용자카드표시는새APK인수로남긴다.
- 최종debug빌드/Issue회신뒤feature브랜치미커밋/dev미반영·미push로인수대기. 서버서비스·DB·기기조작/원격배포·main/Issue종료·장비/활동확대없음.

최종APK11.4초빌드성공. [Issue5 구현 회신6167414628](https://github.com/heo0328/lostparty-backend/issues/5#issuecomment-6167414628) 게시·본문일치재조회확인. 실제전투력수집/카드표시는사용자인수전,새Fluttercommit없음/feature브랜치미커밋·dev미반영·미push상태다.

## 사용자 전투력 인수·기존 자동갱신 조사 (2026-10-14)

사용자가새APK1/2/3서버수치·로컬카드/역할우선·로그아웃재로그인표시캐시를모두정상확인했다. [Issue5결과6167529348](https://github.com/heo0328/lostparty-backend/issues/5#issuecomment-6167529348) 회신·재조회일치확인. 코드변화없이기존검증재사용,미커밋/dev미반영/미push이며Git정리대기.

사용자브리핑요청으로기존StartupCharacterRefreshOrchestrator/NiceGroupPolicy/eligibility·AppShell/BackendApp을조사했다. 기존정책은페이지매진입이아니라앱수명1회(runOnce)이며active소유/서버CharacterID/1700이상/이탈제외,동일직업2명이상나이스단·허용OFF제외/ON포함,전체ArmoryBuild draft검증/역할Snapshot갱신이다. 현재BackendApp은AppShell startup runner·MyAccount manual runner·CharacterManagement nice설정repository/playerId를주입하지않아미연결이다. 내계정initialize의자동sync는siblings요약이며전투력수집아니다. 이번ServerCombatPower는GET캐시+명시POST수동이고나이스정책과연동하지않는다. 자동갱신복원은추가후속으로만기록,이번조사는코드수정/새Backend요청/테스트반복없이수행했다.

## 2026-10-14 — 전투력 구간 dev 통합·자동갱신 설계 준비

- 사용자문서최신화/commit·push/2번준비지시. 신규3흐름인수와Backend확인6167564129를현재완료상태로반영하고NEXT_WORK를나이스단설정·앱실행1회설계준비로교체했다. 이전조건/현재미연결구분·설정회원key/저장위치·실행가드·profile전투력과전체Build책임을확인항목으로둔다. 기능구현/새Backend요청없음.
- 전투력새로가능/보존흐름은계약22와사용자3흐름통과근거를재사용한다. 전체1204뒤국소70/최종분석0·debug11.4초이후기능코드변화없음,테스트/빌드반복없이diff/staged/최신origin-dev·36백업hash검증으로통합한다. 미확인모든provider원본/실장애·나이스단자동실행은후속으로남긴다.
- feature/character-combat-power구현/테스트/원본snapshot/직접관련문서만커밋·원격작업브랜치push→dev일반merge·push. 적용SHA·소비39188d5와완료/미확인을Issue5회신·재조회한다. 작업브랜치유지/삭제후보,dev/origin-dev일치·추적변경없음확인. 기존실험/백업36개·main/원격DB·운영설정유지.

## 2026-10-14 — 나이스단 자동갱신 기존 구조 조사·UX협의 설계

- 사용자설계지시와기능적UX사전협의조건을적용. Firebase제거직전a52492f28c0046a90c3a8d35df00e0c14f241fe6의main/router·설정Repository/DB·Coordinator·로컬draft저장·Firestore최소표시Gateway를git show로대조해문서23에원본경로/동작을기록했다. 실제순서는레이드초기로딩/첫frame→앱1회→active/serverID/1700·나이스판정→Flutter종합Armory→역할Snapshot로컬저장→서버최소표시다. 설정도로컬Player별DB였음을확인했다.
- 새로가능:과거전투력갱신이전체빌드갱신에포함됐고서버는최소값만저장했다는근거로복원범위를협의할수있다. 대상은화면표시/활동선택으로제외하지않았고전체수동은나이스단항상제외였다. UX범위/시점/설정/수동처리4항목은미확정이다.
- 기존동작보존:기능코드/Backend/API·DB·기기/테스트변경없음,기존資料이관없음. #5최신6168169896에서Git인계해소/새요구없음을확인했으며새반복댓글/요청은게시하지않았다.
- 검증은내용/역사소스대조·diffcheck. docs/my-account-backend-phase1을devccc6b23에서ff재사용,문서미커밋/dev미반영/미push·브랜치유지. 실기기추가인수없음/기존실험·백업유지.

## 2026-10-14 — 빌드 갱신 범위·나이스단 서버 설정 사용자 확정

- 사용자가자동갱신범위를전체빌드로확정하고나이스단허용기본OFF·서버회원별저장을요구했다. 기기변경/재설치/데이터삭제뒤동일Google회원로그인으로같은설정/데이터환경복원을목표로기록했다. 기존Firebase이관과구분한다.
- 문서23/NEXT_WORK/AI_CONTEXT에서미확정항목을갱신하고설정미조회와저장false구분·회원격리·최소설정API검토를설계했다. 전체동일환경에는로컬역할Snapshot/선호역할/표시순서등별도복원설계가필요함을분리했다. 실행/저장실패·수동UX는협의전으로유지한다.
- 기능코드/서버요청/API·DB변경없음,문서내용/diffcheck만검증. docs/my-account-backend-phase1미커밋·dev미반영/미push·기존실험유지,새실기기항목없음.

## 2026-10-14 — 나이스단 회원 설정 Backend Issue6 요청

- 사용자 지시로 최신 Issue 목록/Issue5 회신과 Backend dev 4eb23f5 OpenAPI를 확인했다. 기존 원정대 활동/대표 설정과 회원 공통 허용값을 구분하고 중복 Issue가 없는 것을 확인했다.
- https://github.com/heo0328/lostparty-backend/issues/6 생성: 기본false·회원별 서버 GET/수정·동일Google회원의 새세션/기기/재설치 복원, 회원격리·재시도/동시수정 계약과 실제 구현/OpenAPI SHA·push/적용/서버검증 인계 요청. 전체Armory/역할빌드·표시환경복원은 후속 계약 제안이며 일괄구현 요청이 아니다.
- 새로 가능: Backend가 확정된 설정 요구를 기준으로 구현할 협업 요청을 게시했다. 구현/연동 완료는 아니다. 보존: Flutter 기능코드·기존 수동전투력/로그인/등록 흐름 변경없음. 미확인: 신규서버설정/API/기기복원은 Backend회신·Flutter연결 후 검증한다.
- 검증: Issue 본문 게시 확인·문서 내용 검토·git diff --check. 순수문서/협업요청으로 Flutter테스트/빌드 반복없음. docs/my-account-backend-phase1 유지·문서 미커밋·dev미반영/미push, 기존 미추적 백업/실험은 유지.

## 2026-10-14 — 완료 Backend Issue 정리·Flutter 주도 후속 이관

- 사용자 지시로 전체6개 Issue와 원래 요청/완료·최신회신, 관련 계약/실제 BackendApp Router를 대조했다. #1/#2는 기존CLOSED. #3 서버기반 구현·Flutter조회/등록은 완료이나 장비route pending/활동저장 미연결·실provider증거 보류가 남아 전체제품완료가 아닌 후속분리 종료로 판단. #4 등록/이름·#5 수동전투력은 양측구현/게시·인계와사용자확인완료로 종료했다. #6은 착수회신6168785700·구현SHA대기로OPEN유지.
- 완료근거/미완료항목/Flutter주관·다음행동·로컬문서미게시상태를 각 종료댓글에 명시하고 게시본문을 재조회·일치확인한 뒤 Completed로 닫았다. #3 댓글6168888648, #4 댓글6168889958, #5 종료댓글은 각 Issue 최신댓글. 기존 과거 OPEN문구는 당시 이력으로 보존한다.
- 작업대장은 새 파일을 늘리지 않고 연결계획14#flutter-follow-up-20261014에 기록: ACCOUNT-01장비Flutter연결, ACCOUNT-02실provider/이전/감소roster증거, ACCOUNT-03활동/대표연결, QA-01등록제거뒤로컬보존의미확인인수, POWER-01앱실행전체빌드, RESTORE-01빌드/표시환경복원, AUTH-01인증정책/실기기release운영후속. 각각 출처·상태·담당·다음행동·완료조건을 명시했다. 현재우선순위POWER-01/#6·RESTORE-01설계유지.
- ai_rules협업절에 완료요청과후속범위분리·Flutter주관기록·필요Backend변경별도요청·승인범위종료기준을 기록했다. NEXT_WORK/AI_CONTEXT의 오래된전투력Git대기/이름미인수문구를정정하고 후속대장으로연결했다.
- 새로가능: 완료된협업요청이후속때문에대기하지않고Flutter대장에서후속착수근거를추적. 보존: 기능코드/기존인수·API/DB/보류정책변경없음. 미확인: 대장의미구현/미인수를통과로바꾸지않음. 검증: Issue종료상태·게시본문재조회/대장검토·git diff --check. 순수문서/Issue관리라Flutter테스트/빌드반복없음.
- docs/my-account-backend-phase1 유지, 이번/기존설계문서미커밋·dev미반영·미push. 기존미추적백업/실험보존. 코드구현·main/배포·기기/서버조작없음.


## 2026-10-14 — Issue6 계약 직접 확인·설정 UX 협의

- 사용자 다음진행 지시로 Backend 연결요청6168992033과 immutable79255f0의 원본OpenAPI/연결문서를 직접확인. GET/PUT회원설정·엄격DTO/version/멱등·GET실패와false구분·회원격리를설계23에기록하고NEXT_WORK/AI_CONTEXT의인계대기를정정했다.
- 회원공통앱설정위치/즉시저장·저장중차단·실패/재시도를추천하고기존캐릭터관리/별도저장대안을질문했다. 사용자UX응답대기이며추천안을확정하거나기능코드를수정하지않았다. Backend에는계약확인·UX협의상태를Issue6에회신/재조회했다.
- 새로가능: 게시계약기준으로설정연결을계획가능. 보존: 기존기능/API/DB변경없음. 미확인: Flutter설정연결/새환경복원인수. 검증: 문서검토·diffcheck,순수문서라Flutter테스트/빌드반복없음. docs/my-account-backend-phase1 유지·미커밋/dev미반영/미push.

## 2026-10-14 — 회원 나이스단 설정 Flutter 연결 완료·인수 대기

- 사용자 UX 선택은 기존 캐릭터관리 위치·변경즉시저장. feature/member-settings를 생성해 종료조건을 설정연결/검증으로 정의했고 기존 미커밋 문서/미추적 실험을 보존했다. 실행계획을 설계23에 먼저 기록했다.
- 새 MemberSettingsViewModel/Controls, BackendApp 공유DI와기존캐릭터관리나이스단영역을연결했다. 본·부계정회원공통값·하단캐릭터저장취소와독립즉시PUT,로그인/새세션GET복원·미조회/실패와false구분·게스트무요청/로그인안내. 기존로컬관리optional경로·활동/대표/표시저장·등록/수동전투력·Google세션은유지했다.
- 소비Backend79255f0/원본snapshot issue6-79255f0.openapi.json SHA256 6659943b2064e15fd054f7a98426afc432d8d33b53ccb3806c3ac3e3d049ffd3. 기존인증/계정DTO·DB불변,새설정만엄격2필드boolean/intversion. key/body/version/회원세대/기한불변명령·유실/RetryAfter·기한/멱등충돌reviewGET/명시종료·revision충돌GET/사용자새선택·성공replay뒤GET현재값·lateGET/PUT격리.
- 검증: 초기관련29개통과(초기parser테스트의teardown미초기화는수정). 응답불일치/PUT뒤GET실패경계추가후전체1219테스트/제품lib-test분석0. 최종검토에서GET실패가이전RetryAfter대기를해제하는국소경계보완1개후관련32/최종분석0통과. 전체1220통과로확대하지않는다. 초기root분석의새curly안내4개수정,기존미추적tools3개info는손대지않고제품lib/test최종0확인. 최종debugAPK9.4초빌드성공·포맷/diffcheck/구현diff검토완료. 초기APK26.9초는이전상태이며최종APK기준은9.4초다.
- 새로가능: 기존캐릭터관리에서회원설정을즉시서버저장하고GET복원할앱연결. 보존확인:기존캐릭터관리테스트/전체회귀,로컬DB/빌드·등록/인증코드불변. 미확인:실Backend설정쓰기/ONOFF·화면재진입·재로그인/재설치같은회원복원은사용자인수대기. 전체빌드자동실행/전체환경복원미구현을화면/문서에서구분했다. 에이전트기기설치/조작/DB쓰기없음.
- Issue6에소비SHA·구현/자동검증·인수/미실행과Git상태를회신하고본문재조회일치확인했다. 신규Backend수정/이미통과한시험재요청없음. 현재feature/member-settings,기능/문서미커밋·dev미반영/미push,기존미추적실험보존/브랜치유지. 사용자확인후결과콜백과Git정리가남는다.

## 2026-10-14 — 회원 설정 사용자1/2/3성공·앱 시작 API순서 조사

- 사용자ON/OFF즉시저장·관리재진입·동일Google회원재로그인복원3항목성공. 별도재설치/새기기인수미확인은유지. Issue6에결과와코드변경없음/Git미게시상태를회신·본문재조회일치확인.
- 앱초기설정OFF→서버ON복원전자동갱신경쟁질문을실제BackendApp/Auth/회원설정/등록읽기/전투력VM/MyAccount/summary/남은runner로조사. 인증restore와애니메이션후화면표시이며설정/roster완료대기없음. signedIn뒤privateGET은병렬,전투력은캐시GET뿐. 개인키있을때siblings로컬요약자동갱신은별도이며전체Armory/빌드갱신아님. 현재runOnce호출/DI없으므로설정GET전전체빌드자동실행경로없음.
- 향후위험: 남은구runner는설정await후예외를false로바꾸고runOnceFuture를보관한다. 그대로연결하면서버ON의설정실패를OFF로제외한채1회를소진할수있음. 설정미조회null/실패와명시false를구분하고회원설정GET성공+전체roster준비뒤동일회원세대/나이스판정→실행하는순서를설계23/NEXT_WORK에기록. 등록목록중복GET은후속호출정리후보로만기록하며현재정상코드재작성없음.
- 새로가능: 현재실제API흐름과미래갱신선행조건을검토가능. 보존:기능코드/API/DB변경없음·기존사용자인수/자동검증유지. 미확인:전체빌드실행/시작게이트미구현과별도새환경복원. 검증:read-only코드검색/호출부대조·문서내용검토/diffcheck. 코드불변으로테스트/빌드/기기조작반복없음. feature/member-settings유지·미커밋/dev미반영/미push.


## 2026-10-14 — Issue6 최종Git정리·전체DB설계점검 착수계획

사용자Issue6마무리지시로회원설정/계약/자동검증/3흐름성공을정리해commit/dev통합/push·최종Issue콜백/종료를진행한다. 전체1219후국소32·최종분석0/APK9.4초이후코드변경없어재검증재사용. 기존독립문서협업정리는별도커밋으로분리하고미추적실험36개/기존브랜치·main보존. 이후문서브랜치에서전체Drift/보안저장/메모리·Backendmodels/migrations/API를대조하고복원/회원ID/수명/소유·미구현경계를보고하는단일조사그룹을계획했다. 코드/DDL/실데이터변경없음.

## 2026-10-14 — Issue6 종료·전체 DB 설계 재점검 완료

- 독립협업정리61acebd와회원설정기능/계약/검증2e0764f를분리커밋했다. origin/dev ccc6b23최신확인후feature/member-settings push·일반merge dev5cee9648fe53ff259f967e402edfebd1f0a9a001/push·local/origin일치확인. 기존미추적Rules/tools36개와브랜치보존,main불변. [Issue6 최종회신6170736672](https://github.com/heo0328/lostparty-backend/issues/6#issuecomment-6170736672)본문재조회후CLOSED확인. 사용자3흐름과전체1219뒤국소32/분석0/APK9.4초재사용,새기기별도인수미확인유지.
- 문서브랜치 docs/my-account-backend-phase1을dev에서FF재사용해다음단일조사를수행. Backend dev4eb23f5와게시79255f0/0004원본의auth/game/member모델·migration0001~0004·cleanup/서비스/멱등·OpenAPI와Flutter schema13/8개테이블·SecureStorage·메모리/DI를대조. PostgreSQL업무19개(관리테이블제외),로컬8개를보고서24에매핑했다. 실서버DB접속/자료덤프/키출력/DDL변경없음.
- 발견: 서버설정/등록과로컬기기공용계정/빌드·표시환경이별도이며복원연결/회원scope·안정ID/역할Snapshot서버저장계약이남아있음. 전체빌드자동갱신선행조건·비활성schema/모집주간미구현·서버보관수명/삭제를정리. 현재서버구조전면재설계근거로확대하지않음.
- 실제검증은격리NativeDatabase.memory한개probe1개. PRAGMA foreign_keys=0, deleteMissingCharacter이후빌드1행/주간표시1행잔존을재현했다. probe통과는문제재현관찰이고정상화통과가아님. 실제기기DB상태/재현미실행,별도최소정합성수정DB-03으로기록. 임시파일/로그는.dart_tool만사용해제품코드/기존DB미변경.
- 새로가능: 현재저장구조·소유/ID/복원범위와미구현·재현문제를보고서24에서검토가능. 보존:기능코드/기존인수·서버DDL/실자료불변. 미확인:운영DB/실기기FK·새환경복원·서버전체동시성/탈퇴정책. 검증:소스/고정계약대조·메모리probe1·diffcheck/문서검토. 이미검증된회원설정기능전체테스트/빌드를반복하지않음.
- 문서/후속대장·AI_CONTEXT/NEXT_WORK를최신화해다음은복원범위/정답저장소확정과DB-03별도후속으로둔다. 문서최종검증후dev통합/push해보고서를공유하며Backend새기능요청/DB변경은하지않는다.

## 2026-10-15 — 시작 등록 목록 중복 조회 개선

- 사용자 순차진행지시의 첫그룹으로 시작 중복GET을 선택했다. AGENTS/ai_rules/NEXT_WORK/AI_CONTEXT/문서지도·기존조회/소비VM·쓰기뒤review/페이지명시재조회 흐름과 #5최신종료회신을확인했다. 기존feature/account-backend-read를dev70880bf에서FF재사용,새브랜치/Backend요청/기존실험수정없음.
- ServerAccountReadRepository의초기opt-in shareInFlight만회원+세션세대별진행Future를공유한다. 전체pagination/검증후불변결과공유·성공/실패정리,새세션은공유안함. 등록/전투력VM의인증상태초기load만opt-in. 기본load/reload·쓰기후/멱등상태확인은항상새GET이라이전진행응답을재사용하지않는다. 결과TTL/백그라운드polling/DTO/DB/Router변경없음.
- 새로가능: 정상단일페이지로그인시등록목록HTTP2→1,전체Backend시작4+N→3+N(토큰유효/실패없음기준). 보존확인:초기공유VM결과·페이지전체성·성공재조회/실패복구·회원/새세션/늦은응답·쓰기후신규GET과기존등록/이름/전투력/회원설정전체회귀.
- 검증: 신규7개포함전체1227테스트통과(.dart_tool/registration-flight-tests.log,56초),제품lib/test분석0(.dart_tool/registration-flight-analyze.log,45.6초),변경파일포맷/diffcheck/최종diff검토. 실제기기패킷개수측정은미실행,전체빌드자동갱신/서버환경복원은미구현유지. UI/API계약변경없어성공한기기인수/Backend시험·APK빌드반복없음.
- feature/account-backend-read 유지·미커밋/dev미반영/미push,기존Rules/tools미추적실험보존. 다음그룹은자동빌드시작순서설계와그뒤서버/로컬정답/복원범위협의이며이번구현에다른DB정합성수정을섞지않았다.

## 2026-10-15 — 등록 목록 중복 조회 dev 통합

사용자완료작업commit/dev병합·push지시에따라feature/account-backend-read의잔여항목을확인했다. 구현/자동검증/관련문서는완료,미확인실기기패킷계수는새UI필수인수가아니므로대기사유로두지않는다. 최종전체1227/분석0·포맷/diff를재사용하며코드불변이라검증을반복하지않는다. 최신origin/dev확인후코드/신규7개경계/관련문서를같은단위로commit·일반merge/push한다. NEXT_WORK를다음자동빌드실행순서설계로교체했고UI/설정/실패재시도는사용자협의전구현하지않는다. Backend수정/Issue콜백이필요한새계약/요청이없어종료이슈에독립로컬개선댓글을추가하지않는다. main/DB/기기와기존미추적Rules/tools를변경하지않고작업브랜치는유지/삭제후보로둔다. 최종적용/통합SHA·원격일치는실행후보고한다.

## 2026-10-15 — 회원 개인 Lost Ark API 키 서버 저장·호출 전환 요청

- 사용자 요구로 자동갱신설계보다 회원개인키구간을 우선했다. dev2dd821f(중복조회1c294d6통합완료)에서기존문서브랜치 docs/my-account-backend-phase1을FF재사용했다. FlutterAPI토큰화면/기기secure store와Backend dev4eb23f5 provider/observations/router/power_service를소스로확인. 서버공용LOSTARK_API_TOKEN/조회name기준cache와provider-global quota를확인했으며실제키값/환경파일은읽지않았다.
- 요청25와신규Backend Issue7(https://github.com/heo0328/lostparty-backend/issues/7)에user UUID당개인JWT암호화저장/상태GET·명시등록교체삭제·원문미반환/로그·오류·멱등result노출금지·모든provider회원키사용·공용fallback0·키오류와앱401분리·cache/lease/quota·교체삭제중version/late결과·회원격리/동일회원재로그인을요청. 정확한wire/DDL/validation은Backend검토회신대기다. 본문게시후재조회일치확인.
- Flutter진입점/로컬직접호출키와서버저장UX는계약후사용자협의,현재기기키자동전송/서버키원문다운로드없음. 로컬직접호출/비로그인기능은임의제거하지않았다. 09의O04미결정사항을최신확정으로갱신하고NEXT_WORK/AI_CONTEXT/문서지도·DB24후속을연결했다.
- 새로가능: Backend가회원별credential저장/실제호출전환을구현할검토가능요청. 아직구현/인수완료아님. 보존:Flutter기능·현재인증/설정/등록/수동전투력·실제DB/환경/키불변. 미확인:새schema/API·서버암호화키준비/두회원격리/Flutter UI연동은후속. 검증:원본소스/중복Issue확인·게시본문대조·문서내용/diffcheck,순수요구문서라Flutter테스트/빌드반복없음. 현재docs/my-account-backend-phase1미커밋/dev미반영/미push,기존Rules/tools실험보존.

## 2026-10-15 — 회원 키 계약 수용·공용 테스트 키 제거 요청

- 사용자 동의로 Issue7 제안6172016640의 저장/유효성 분리와 메타데이터·버전/멱등·회원 키 호출/캐시/오류 계약을 수용했다. 댓글6172158382로 Backend 구현 착수와 현재 공용 테스트 JWT의 설정 원천/실행 제거·해당 API 적용을 요청하고 게시 본문을 대조했다. 키값/환경파일을 조회하거나 게시하지 않았다.
- 사용자도 직접 개인 키를 등록한다. 기존 공용/기기 키의 자동 등록은 없으며 미등록 새 외부 호출은 공용 캐시와 무관하게 차단한다. 기존 저장 자료 GET·Google 세션·회원 설정·원정대 데이터는 유지하는 계약이다. 외부 발급 키 자체의 폐기나 DB 초기화는 요청하지 않았다.
- 새로 가능: 수용된 계약에 따른 Backend 구현 및 공용 키 없는 UX 시험 준비. 보존 확인: Flutter lib/test 무변경·기존 미추적 실험 보존. 미확인: Backend 실제 공용 키 제거/실행 반영·암호화/API 구현·개인 키 UX 연동. 검증: 게시 본문 일치·문서 검토/diffcheck, 순수 문서라 Flutter 테스트/빌드 미반복. docs/my-account-backend-phase1 미커밋/dev미반영/미push이며 Backend 완료로 간주하지 않는다.

## 2026-10-15 — Backend 대기 중 회원 키 UX 설계 초안

- 사용자 요청으로 기존 API 토큰 화면/설정/내 계정 진입 및 기기 전용 ApiTokenStore 연결을 확인하고 요청25에 UX 초안을 기록했다. 등록 상태 확인/오류/명시 저장·교체·삭제/응답 유실·회원 및 서버 전환·실제 키 거절을 구분하고 성공을 유효성 인증으로 표시하지 않는다. 내 계정 캐릭터 목록 위에 큰 영역을 추가하지 않는 안이다.
- 서버 등록 기본·기기용 별도 관리와 이중 저장/서버 전환의 선택을 사용자에게 협의 요청했다. 나머지 화면 유지·복귀 시 자동 명령 재실행 없음 등도 초안이며 미확정이다. Backend 수용6172211262 이후 구현/공용 키 제거 인계는 대기다. UX 초안을 완료 API로 오인할 테스트 요청/불필요한 Issue 댓글은 추가하지 않았다.
- 새로 가능: 사용자와 검토할 화면/상태/연결 설계. 보존 확인: 제품 코드/lib/test·기기 키/서버 설정 무변경. 미확인: UX 사용자 확정·Backend 구현·실기기. 검증: 관련 코드/문서 검토·diffcheck, 문서만 변경해 Flutter 테스트/빌드 생략. 기존 docs/my-account-backend-phase1 유지·미커밋/dev미반영/미push, 미추적 Rules/tools 보존.

## 2026-10-15 — 서버 호출 제한 사용자 안내·기기 키 복원 협업 요청

- 공식 가이드의429/Limit·Remaining·Reset(epoch) 확인을 기반으로 사용자 지시를 반영했다. Backend6172571002/38d66dad 인계와 게시 개발 안내를 확인해 기존 key API/공용 키 제거 완료와 아직 없는 재시도 시각/원문 복원 계약을 구분했다.
- 6172594991에 provider429의 키별 대기·단건/HTTP200 batch별 retry metadata·누락/비정상 시 유한 대기와 Flutter 안내/명시 재시도를 요청했다. 기존 서버80/min과 외부100/min을 구분하며 전체 호출량 동기화 서비스나 실키 한도소진 시험은 추가하지 않았다. 사용자 제시 서버·기기 동시 저장 및 본인 키 새기기 복원 방향도 별도 최소 계약 검토로 전달, 기존 metadata GET 변경을 확정하지 않았다. 게시 본문 일치 확인.
- 요청25/NEXT_WORK/AI_CONTEXT에서 앞선 원문 다운로드 없음/Backend 미구현 문구를 최신 후속으로 명시 대체했다. 새로 가능: 양측이 구현할 제한 안내와 키 복원 계약 검토. 보존 확인: Flutter 코드·실제키/환경 변경 없음. 미확인: 보완 계약/구현·Flutter 실연동·실기기. 검증: 공식 문서/게시 개발 안내 확인·댓글 대조·diffcheck, 문서 작업으로 테스트/빌드 생략. docs/my-account-backend-phase1 미커밋/dev미반영/미push, 기존 미추적 실험 보존.

## 2026-10-15 — Issue7 추가 계약 검토·수용 회신

- 최신6172711200과 Flutter PowerResult strict 필드 검사를 대조하고 공식 usage-guide의 UNIX Reset 예시를 확인했다. 서버429 deadline/단건·batch retry metadata 및 POST 본인 키 restore/version/no-dedup이 요청 UX에 맞아6172746952로 수용·구현 진행을 회신, 게시 일치 확인했다.
- 성공 Remaining0은 현재 성공을 유지하고 다음 호출부터 대기, 늦은 제한 정보의 token/deadline max와 업무 fencing 유지, 현 Flutter 빌드와 PowerResult 새 필드 비호환을 인계했다. 새로 가능: 양측 추가 계약 확정과 Backend 구현 착수. 보존 확인: lib/test·키/환경 무변경. 미확인: Backend 보완 구현·새 OpenAPI SHA·Flutter 연결/실기기. 검증: 공식 문서·최신 Issue·관련 DTO 검토/diffcheck, 코드 불변으로 테스트/빌드 생략. 현재 docs/my-account-backend-phase1 미커밋/dev미반영/미push·기존 실험 보존.

## 2026-10-15 — Issue7 보완 구현 인계 확인

Backend6172992882의SHA9e1a255b87b430bca314e8f718fb4176bfe322c8 원본OpenAPI를 받아 restore 및 optional오류/required nullable PowerResult 시간 필드를 대조했다. 합의 일치·다음Flutter담당을6173015145로 회신. 새로 가능: 확정 구현계약 기준 Flutter 연결 착수 준비. 보존 확인: lib/test·키/환경 무변경. 미확인: Flutter 연결/자동검증·실키복원/provider헤더/기기·서버내부독립검증. Backend는 mock151/24/4 각실행·로컬0006/API·작업브랜치push/dev미병합 보고. 검증: 원본계약 대조·문서diffcheck,코드불변으로Flutter시험 미반복. docs/my-account-backend-phase1 미커밋/dev미반영/미push,기존실험보존.

## 2026-10-15 — Flutter 회원 키 관리·복원·호출 제한 연결

- 사용자구현승인으로feature/member-lostark-key 생성(종료조건:회원키/기기복원/제한UX연결과검증·인수준비). 기존목적브랜치없음·origin/dev2dd821f직접확인,기존문서미커밋과Rules/tools36개보존. 문서25를현재계약으로정리하고구현전NEXT_WORK에흐름/소유권·범위/회귀/완료조건을기록했다.
- Backend9e1a255b87b430bca314e8f718fb4176bfe322c8 소비. 고정OpenAPI사본SHA2565217dcedeca895c96ed014b8df13b80be291165871a013f2cbaaf3f16030aded. 기존ApiTokenStore/인증session·등록API재사용. MemberLostArkKey와회원/서버별securestorage·MemberKeyPage를기존route에연결,원문보안응답/로그미출력·서버저장과유효성분리·명시등록교체삭제·GET→restore·기기부분실패와재복원. 로그인/재실행/페이지/foreground재확인,logout이전회원기기정리·서버보존·직렬화/세대·키버전late응답차단. guest키는회원키와별도이며자동업로드하지않는다.
- ApiCooldown의Remaining0/429·epoch초/최대미래300초/비정상60초fallback·deadline max·같은키유지/다른키분리. 직접조회·상세갱신/서버preview·전투력batch에안내/명시retry. GameErrorDetail시간·PowerResult required nullable시간쌍·신규keyreason연결. Google로그아웃으로변환하지않고저장자료열람/숫자·Snapshot유지. 응답유실동일명령/24h·버전충돌과상태GET실패알수없음을구분한다. DB/Backend/자동전체빌드갱신은변경없음.
- 검증: 최초전체1242PASS+새mock1실패(임의JSON응답헤더누락),해당content-type수정후표적58PASS·최종전체1246PASS(41초). 이후metadataGET실패시이전버전조작금지국소보완+신규1경계,관련12PASS. 전체재반복대신직접영향검증재사용,최종lib/test분석0(4.1초)·debugAPK build8.7초·포맷/diffcheck/最終diff검토. SDK제한환경resolvedExecutable오류는승인된정상SDK실행으로해결. 분석의중괄호14스타일은해당조건문만fix한뒤0확인. 로그.dart_tool/member-key-final-tests.log,member-key-metadata-final.log,member-key-final-analyze.log,member-key-build.log.
- 새로가능:앱에서서버개인키등록/복원·기기저장과제한대기흐름. 보존확인:기존Google/회원설정·등록/이름/전투력·역할Snapshot/guest회귀시험. 미확인:실제개인키·provider/기기연동·再설치/다른디바이스·OS저장실패·운영TLS. 기기설치/조작·실키한도소진/원문자료요청없음. 수동3흐름은NEXT_WORK에구체화했다.
- 이슈6173350024로소비SHA·미커밋/미push·자동/실미확인·次행동회신,게시본문재조회일치. feature/member-lostark-key 유지·미커밋/dev미반영/미push·main불변. 사용자commit/push지시없는현재단계에서는실행하지않았다. Backend에불필요한재시험/추가수정요청·Issue종료없음.

## 2026-10-15 — 사용자 인수 피드백·안내 문구 정리

사용자는 키 등록/삭제가 제대로 되는 것으로 보인다고 보고했다. 재로그인/재설치/다른기기와 나머지 조회 인수까지 통과로 확대하지 않는다. 원정대 상세의 문의식별자 UUID와 개발/서버 중심 문구를 지적해 동일 feature/member-lostark-key에서 연결 화면의 표시만 수정했다.

- 문의식별자는 서버 오류요청 추적용 request_id다. 일반화면의 UUID 노출 2곳을 제거하고 오류 모델/API 식별정보는 유지했다. 미구현 문의 버튼/외부 전송은 추가하지 않았다.
- 서버계정캐릭터→원정대캐릭터,서버계정관리→원정대관리,미인증→원정대인증전,활동설정전→활동캐릭터선택전으로 목적을 명시했다. 전투력 버튼은 전투력갱신으로 짧게 두고 대상1700/최대20명은 설명으로 분리했다. 캐시는최근정보사용·미처리는다음에확인,키저장성공은API키를등록했습니다로정리했다. 인증/등록/실제키유효성의동작은변경없고사용자에게유효성보증으로표시하지않는다.
- 새로가능: 내계정 관련화면의 개발용 표현/추적번호 없는 사용자 안내. 보존확인: API/권한/저장·키등록삭제/멱등 흐름불변. 미확인: 문구 최종 실기기 표시와 남은 사용자 인수. 검증:관련기존46개PASS·최종lib/test분석0(18초)·포맷/diffcheck/문구검토. 순수표시수정으로전체1246/후속12 기능검증을반복하지않았다. 디버그APK재생성결과는최종로그참조. 기존사용자미추적실험보존,미커밋/dev미반영/미push·브랜치유지.

문구정리최종debugAPK15.5초PASS. [사용자부분확인·문구회신6173742113](https://github.com/heo0328/lostparty-backend/issues/7#issuecomment-6173742113) 게시·재조회본문일치완료. Backend재시험요청없음.

## 2026-10-15 — 회원 키 구간 사용자 정상 보고·키 사용 경로 확인

사용자는 캐릭터검색등현재구현구간이정상작동한다고보고했다. 등록/삭제앞선결과와함께수용하며키저장위치/HTTP내부구분을추가수동인수로요구하지않는다. BackendApp의MemberLostArkKey→LostArkApiClient→fetchSiblings/Armory 직접경로,로그인restore기기키read와서버명령Bearer경로를재확인했다. 키원문/실패킷관찰은미실행이며Backend회원키선택은인계계약/검증보고기준이다.

새로확인:현재구현기능일반사용정상보고. 보존:제품코드/실제키불변·기존자동결과재사용. 미확인:조건별재설치/별도기기·실제provider한도,보고없는상세시험을개별통과로확대하지않음. 문서/diffcheck검증만수행,코드불변이라테스트/빌드반복없음. 이슈최신6173751445확인후6173934017로결과/키경로/미확인·미커밋미push상태를회신하고게시일치확인. 전체앱문구점검은후속이다. 다음사용자지시로Git정리/실제SHA인계,feature/member-lostark-key유지·dev미반영·Issue종료/Backend재시험요청없음.

## 2026-10-15 — 회원 키 완료 단위 문서 정리·dev 통합

사용자가 문서정리·commit/merge/push를 지시했다. 작업 기준과 최신 origin/dev가 모두2dd821f임을fetch로확인했고추가코드/충돌은없다. 사용자 기본기능정상보고와 자동 전체1246/국소12·문구46/분석0/debug15.5초를재사용한다. 코드는불변이라실행시험을반복하지않고문서/diffcheck·stage검토만진행한다.

NEXT_WORK를완료로그에서다음전체빌드자동갱신시작순서설계로교체했다. 키metadata/restore가추가돼과거시작3+N은당시기준임을명시했다. AI_CONTEXT/README/09/24/25의이전미결정·원문복원불가·미구현표현을최신계약/사용자정상보고로정리했다. 전체앱문구점검·재설치/다른기기·실provider한도는별도후속/미확인으로유지한다. 새로운기능/서버설정/Issue종료는수행하지않는다.

코드·경계시험·고정OpenAPI·연결문서를같은기능단위로commit하고작업브랜치에복구지점을push한뒤,최신origin/dev재확인→일반merge→devpush/원격일치검증을수행한다. 최종SHA는Git이력과Issue7최종회신으로추적한다. 기존문서준비자료는이번회원키계약/후속연결범위이며사용자Rules백업2개/tools34개는stage하지않는다. 브랜치는유지/통합후삭제후보,main불변이다. 새로가능:완료기능의공유된dev기준. 보존확인:기존인수/자동검증동일코드·실험자료. 미확인실기기는앞선보고범위를유지한다.

## 2026-10-15 — 자동 빌드 갱신 UX 합의·역할 저장 경계 확인

사용자가 보석/아크패시브/아크그리드 근거로 dealer/support에 맞게 저장할 준비를 재확인하도록 요청했다. 공통 분석기·Coordinator·수동 상세 저장·로컬 DB·역할별 표시와 기존 테스트를 대조했다. 자동 경로의 역할별 저장과 반대 역할/선호 역할 보존, 오류 검출과 저장 차단의 구분을 확인했다. 수동 상세는 선택 역할 저장이며 판정 실패의 expectedRole fallback은 새 자동 경로에서 허용하지 않는 설계가 필요하다.

사용자 선택으로 회원별 앱 실행1회, 준비 후 자동 시작(준비 실패는1회 미소진), 비차단 탭/완료수 표시, 미완료 명시 재시도와 제한 대기시간, 역할 확정시 오류 요약과 해당계열 저장, 시작설정 고정, 회원전환 중단/늦은 저장 차단을 확정했다. 상세 계약은 설계23의 현재 기준에 한 번만 기록했고 NEXT_WORK는 남은 기술 설계로 정리했다. 회원키 Flutter8644c81/devcc6a0b0 및 Backend dev72f6301 통합·push 회신, Backend가 닫은 #7의Completed종료(API/CLI 확인,2026-10-15 11:29 KST)로 오래된 대기를 정정했다. CLI 인증도 정상 확인했다. 이번에 새 Issue/댓글/서버 변경은 없다.

새로 가능해진 흐름: 구현 전 사용할 사용자 합의 UX/역할 저장 기준 확보이며 실행 기능은 아직 미구현. 보존 확인한 기존 흐름: 코드/테스트/DB/main·사용자 Rules/tools 실험 불변. 미확인 실기기 항목: 새 자동 실행/진행/실패·중단 UX 전체이며 기존 회원키·설정 인수를 반복 대기로 바꾸지 않음. 검증: 관련 코드·테스트 내용/문서 검토와 git diff --check, 순수 문서라 Flutter 테스트/빌드 재실행 없음. 기존 docs/my-account-backend-phase1을dev까지FF재사용, 문서 미커밋·dev미반영·미push. 이후 준비/ID/세션·키 변경/저장 직전 검증·재시도/수동 충돌을 기술 설계한다.

### 원정대 변경 선행 설계로 순서 조정

사용자는 로컬 저장 공간 자동 생성 선택보다 캐릭터명 변경·삭제 대응을 먼저 해결하도록 지시했다. Flutter summary 적용/누락 수동 삭제와 Backend immutable72f6301의service/observations/provider를읽어현재서버명+이름대조·개명자동연결없음·live누락suspect/증거보류를확인했다. 로컬은빠진행을missing으로남기며비어있지않은부분응답/역순응답의누락처리와조회기준캐릭터개명후조회복구가설계경계다. 누락행명시삭제의종속빌드/주간고아정리는기존DB-03과직접연결된다. 설계23/NEXT_WORK에근거와선행범위를기록하고사용자확인승계/기기삭제정책을질문했다. 아직응답전이므로자동병합·자료승계/삭제·새Backend요청은확정/실행하지않았다. 코드/DDL·실자료/키·실provider불변,문서검토/diffcheck만수행하고미커밋상태를유지한다.

### 소멸 이력·신규 등록·미완료 파티/이름 재사용 정책 확정

사용자는 인증 원정대 새 이름을 신규로 등록하고, 정상 전체 조회에서 사라짐이 확인된 기존 캐릭터는 서버/이름/직업/마지막전투력/아이템레벨의 간략 이력만 남긴 뒤 개인자료를 정리하도록 확정했다. 개명 전후 빌드/설정 승계는 하지 않는다. 파티/완료 Snapshot은 보존하며 미완료 파티는 기존 회원 자리/당시정보·확인필요 경고를 유지하고 본인이 유효한 캐릭터로 명시 변경/탈퇴한다는 선택을 받았다. 다른 원정대가 옛 이름을 사용할 때 참가/권한이 넘어가지 않는 설계를 요구했다.

Backend72f6301 models.py의 서버+이름 전역unique와 service의기존관찰키/canonical추론을확인해새이름생명주기계약필요를확인했다. 기존Flutter파티WritePlan은playerId/characterId와표시Snapshot·raidState를분리하지만신규Backend파티는pending미구현임을대조했다. 확정정책/현재공백/ID참조보존·이름재사용/조회순서·지연응답·8인파티상태경계·최소검증을계약26에분리하고README/설계23/NEXT_WORK/AI_CONTEXT를연결했다. 물리이력/전체성증거/FK·API는Backend검토전이며새Issue/구현을시작하지않았다.

새로가능:확정된원정대생명주기와미래파티연결의설계기준. 보존확인:제품코드/DB/키/실험자료불변. 미확인실기기:전체새정책·실provider누락증거·신규Backend파티기능이며기존완료를확대하지않음. 검증은원본코드/문서내용·git diff --check,Flutter시험반복없음. docs/my-account-backend-phase1에서문서미커밋·dev미반영·미push를유지한다.

### 이상 캐릭터 즉시 사용 차단과 기존 참가 복구 명확화

사용자는 기존 파티의 모든 참가자에게 캐릭터 이상을 표시하고, 본인은 새 이름b를 포함한 조건을만족하는다른본인캐릭터로변경할수있어야하며, 이전a는이상감지순간신규파티/신청/그룹에사용불가임을명확히했다. 계약26/NEXT_WORK에 이상감지즉시사용차단과정상전체조회소멸확정후삭제의두단계,서버최종명령검증·기존회원membership기반변경/탈퇴허용을추가했다. 단순조회실패를캐릭터별이상/소멸로확정하지않고Backend감지/해소계약은검토대기다. 문서내용/diffcheck만검증했으며코드/DB/Issue변경·시험반복·commit/push없음.

## 2026-10-15 — 원정대 생명주기 Backend Issue8 계약 검토 요청 게시

사용자가 다음 단계인새Backend계약검토요청게시를승인했다. 필수진입문서/Git/현재계약과기존Issue목록을대조해동일요청이없고#1~#7완료임을확인했다. 최신Backenddev821c7581e022393e86174258a35235a4891b9cc8와조사72f6301의compare는#7종료기록문서4개뿐이며관련소스불변이다. 기존docs/my-account-backend-phase1과설계미커밋/사용자Rules·tools를보존했다.

https://github.com/heo0328/lostparty-backend/issues/8 에정상전체성/이상즉시사용차단·확정소멸정리/이력·이름재사용ID/소유추론·참조·최소API/원자성/멱등과단계별구현범위의검토를게시했다. 미래파티의회원별자리·경고/명시교체·동시간대중복금지와이름재사용권한격리를인계하되파티전체구현은제외했다. 이번은검토요청이며기능구현/DDL적용·실자료삭제·운영배포승인이아님을명시했다. 로컬설계26이아직미커밋/미push임을밝히고상대가읽을필수요구/질문/완료조건은이슈본문에실었다.

인증복구된gh CLI로게시후원격본문을파일과개행정규화대조해일치/OPEN/댓글0확인. NEXT_WORK/AI_CONTEXT/계약26/README에같은링크·Backend담당/회신대기·다음최신댓글확인절차를기록했다. 자동감시없음. 새로가능:Backend가검토할공식요청과담당/완료조건확보. 보존확인:기존앱·DB·키·완료Issue·main/기존실험자료불변. 미확인:새계약/기능/실provider/실기기미구현·미검증. 검증:원격기준/중복·게시본문재조회/문서diffcheck,문서/협업만변경해Flutter시험반복없음. 문서는현재브랜치미커밋/dev미반영/미push,브랜치유지다.

## 2026-10-15 — Issue8 Backend 검토안 수신·보완 질문 회신

사용자 회신확인 지시로6183753309의A/B/C제안을전문조회했다. lifecycle3상태/NameClaim/퇴역이력·V2 read/refresh/복구/이력과V1차단제안은아직문서초안이며Backend기능/OpenAPI/migration/새자동검증없음이다. 정책방향은일치하나live전체성/세대연속성증거부족으로추가·퇴역·복구가보류돼실제제공기능을분리해야함을확인했다. 대표재구성cooldown우회는새제품예외미수용,이력전투력은서버profile값이며로컬선호역할Snapshot과다를수있다.

6183781483(https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6183781483)으로실제근거확보/조사종료조건·분기가능성,대표cooldown경계,V1/V2전환/IDmapping/캐시선행범위의보완을회신하고원격본문일치를재조회했다. 구현착수/전체계약수용·실자료삭제·배포승인이아님을명시,계약26/NEXT_WORK는보완회신대기로갱신했다. 코드/DB/키불변·신규시험미실행,검증은원격댓글/문서대조·diffcheck다. 현재설계브랜치미커밋/dev미반영/미push를유지한다.

## 2026-10-15 — 메인 원정대 대표 왕관 UI/UX·공통 알럿 배치 확정

사용자는내계정에서보이도록선택한메인원정대캐릭터의대표를노란파스텔채움왕관·나머지를윤곽왕관으로표시하고터치시대표변경확인알럿의취소좌/변경우를지정했다. 이취소/긍정배치를앱공통규칙으로확정했다. 기존카드이름오른쪽대표별표·visibleCharacters대표우선정렬·로컬대표ID와BackendApp미주입representativesync를대조해계약27에범위/상태·선택자격·요청유실/충돌·관리draft공유·API논리요구를설계했다. 회원전체대표/부계정빠른선택으로확대하지않고실제기능코드는바꾸지않았다.

Backend6183888735의UX요청과6183941103보완을확인했다. 신규추가긍정증거/소멸전체성분리·퇴역V1목록제외·P0~P3/mapping/cache전환제안은별도미수용으로기록하고,대표5분제한폐지/전용API방향에맞춘UX를6183971014(https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6183971014)로회신했다. 게시본문재조회일치,정확한대표API계약회신대기. 계약27/설계시스템/ai_rules의버튼배치와NEXT_WORK/AI_CONTEXT/README/계약26을갱신했다. 기존알럿일괄수정/Backend전체계약수용·구현/DDL/배포요청없음.

새로가능:대표빠른선택의검토가능UX/API요구확보. 보존확인:앱코드/DB/main·기존사용자Rules/tools자료불변. 미확인실기기:새왕관/알럿/저장상태/서버연결전체. 검증:관련소스/계약검토·댓글본문일치·git diff --check,순수설계라Flutter시험/빌드반복없음. 현재docs/my-account-backend-phase1미커밋/dev미반영/미push·브랜치유지다.

## 2026-10-15 — 대표 전용 API 검토안 수신 확인

사용자답변확인지시로Issue8의Backend6184022477(https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6184022477)을읽고계약27/NEXT_WORK와대조했다. 신규representative GET/PUT·필수5입력/10응답필드·등록/설정/소유/roster검사·메인한정/활동보존·기존PUT cooldown제거·GET복구/no-op/replay는왕관UX방향과일치한다. 현재실소유인증/활동설정·안전한serverIDmapping준비가사용선행조건이며API구현만으로모든현재사용자가사용가능해지지않음을구분했다. 제안은Backend미커밋/미push·기능/OpenAPI/DB/시험·새SHA없음이다. 이번은답변확인/로컬검토기록이며구현착수요청·전체lifecycle수용/배포승인으로전달하지않았다. 코드/DB/키불변,문서diffcheck만검증하고미커밋/dev미반영/미push상태를유지한다.

## 2026-10-15 — 대표 API 계약 수용·Backend 독립 구현 요청·Flutter 의존성 조사

사용자가양측고착해소의단계진행을승인했다. 최신Issue8에새변경/중복요청이없는것을확인한뒤6184022477대표API계약을수용하고6184322765(https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6184322765)로GET/PUT·네revision/자격·활동보존·기존PUT포함5분제한제거·멱등/현재GET복구의독립구현/표적검증을요청했다. Backend는Flutter왕관/인증연결을기다리지않도록명시,구현/원본OpenAPI SHA·commit/push/dev/검증인계를완료조건으로요청했다. 게시본문재조회일치확인. 실제착수/구현완료는아직미회신이다.

Flutter는BackendApp인증pending/관리화면의서버활동repo·대표gateway미주입·로컬대표저장,AccountRepository의IdentityMapping/DB.bindServerIdentity존재와현재검증된연결실행흐름부재를대조했다. 계약27에읽기준비→인증/증거→명시ID매핑→원정대별활동/공유설정version→게시대표API/왕관의담당/완료조건을기록했다. 기존playerId전역/Firebase gateway재연결·이름기반자동매핑/삭제는하지않는다. Backend API구현은선행실사용준비와독립이며실제왕관인수완료와구분한다.

NEXT_WORK현재실행을양측담당분리로바꾸고원정대전체설계는후속보존,AI_CONTEXT/계약26에도독립수용링크를남겼다. 새로가능:공식수용/구현요청으로Backend대기원인해소·Flutter선행작업조사정리. 보존확인:제품코드/DB/키/main/사용자Rules·tools불변. 미확인:Backend새구현/계약SHA·Flutter인증/활동/ID실사용·왕관전체미구현. 검증:관련소스/댓글본문·문서검토/diffcheck,코드불변으로시험반복없음. 설계docs/my-account-backend-phase1미커밋/dev미반영/미push,브랜치유지다. lifecycle전체/배포·migration적용/실자료삭제·Issue종료는승인/요청하지않았다.

## 2026-10-15 — Backend 대기와 독립한 원정대 인증 클라이언트 구현

사용자가진행가능한부분수행을지시했다. 게시9e1a255원본OpenAPI의4경로/StartIn·VerificationOut과Backend schemas.py의source_matches를대조해데이터/불변명령·호출계층을독립구간으로정의하고구현전계약28/NEXT_WORK에기록했다. 기존목적브랜치목록을확인한뒤종료조건을인증클라이언트/경계검증완료로정한feature/account-verification-client를devcc6a0b0에서생성/확인했다. 이채팅설계미커밋/사용자Rules·tools는보존했다.

ServerAccountVerification strict8응답/nullable·UUID/UTC/status·보류code,ServerVerificationCommand의등록/직접입력상호배타·회원/세션·key/body불변,ServerAccountVerificationClient의기존HTTP재사용/응답대상·전후scope/late오류차단을추가했다. UI/DI/Router/DB·옛verificationGateway/소유binding·증거보류는변경없음. 제한환경의Dart포맷실행경로오류후wrapper를중단하고정상SDK권한에서format성공,표적신규13+기존HTTP/세션11=24PASS·세파일분석0·diffcheck완료. 공용실행/라우터/DB변경없어전체Flutter시험/빌드는반복하지않았다.

관련Issue8의6184482730(https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6184482730)으로실제구현/자동검증과미커밋·미push·새SHA없음/UI미연결을구분회신하고원격본문일치를확인했다. Backend대표독립구현은계속진행하도록담당경계를유지했으며추가서버수정/재시험요청없음. 새로가능:추후화면/상태기계에서재사용할인증4경로기반. 보존확인:기존HTTP/실제auth세션표적시험·제품런타임/로컬자료불변. 미확인실기기:새인증UI·실장비/proof·ID연결/활동/왕관전체. 다음은인증화면/상태기계UX설계다. 현재feature/account-verification-client미커밋/dev미반영/미push·브랜치유지,main/배포/실자료/키변경없음.

## 2026-10-15 — 서버 인증 화면·상태 관리·Router 연결

사용자가 추가 제품 결정 없이 진행 가능한 선행 작업을 승인했다. feature/account-verification-client를 재사용하고 계약28에 먼저 포함/제외·데이터/권한·작업 순서·회귀/완료 조건을 기록했다. Backend 대표 완료6184483999의 cd3e003 원격 구현 안내와 dev/main 미통합·개발 API 적용 상태를 확인했다. 추가 공식 schema 조사6184587789도 수신했으며 schema 접근조사 완료와 영구 ID/생성세대·소멸/전체성 보장 미기재를 구분해 계약26에 기록했다. L1 전체 수용이나 장비 proof/자동 퇴역 live 보류 해제는 하지 않았다.

ServerVerificationViewModel은 앱 서비스 수명의 불변 요청/UUIDv4 키와 challenge, 서버 남은 시간·호출 제한·명시 재시도를 관리한다. 성공/replay/DELETE204 뒤 현재 GET, 실패한 GET 재조회, GET만으로 미확정 명령 해제 금지, 멱등 충돌/만료 후 GET으로 복구 제한이 풀리지 않는 경계와 24시간 재시도 상한을 적용했다. 회원/세션 변경·late 성공/오류/소유자 dispose를 차단한다. ServerVerificationPage는 등록 원정대/직접 입력·지정 부위 안내·명시 확인/취소/만료·증거 보류와 취소 알럿 좌우를 표시한다. BackendApp의 기존 설정 진입점에 DI/Router 연결, verified 후 서버 목록 재조회만 수행한다. 로컬 소유/ID/활동 저장과 자동 polling/confirm은 없다.

검증: 초기 전체1279PASS 후 멱등 오류 뒤 GET이 재전송 제한을 해제할 수 있는 경계를 보완하고 신규 회귀를 추가, 최종 전체1282PASS(이전1246+클라이언트13+신규 상태23). 최종 lib/test 분석0, format/git diff --check 및 diff 검토 완료. 초기 분석의 중괄호 안내8개는 수정했다. 로그 .dart_tool/verification-ui-final-tests.log 및 verification-ui-final-analyze.log. 실제 provider/장비/기기 설치·조작/서버 자료 쓰기는 수행하지 않았다.

새로 가능해진 흐름: 설정→내 게임계정 인증에서 서버 인증 명령과 진행/보류·재진입·같은 요청 복구를 사용. 보존 확인한 기존 흐름: 전체 회귀시험과 기존 Google/회원키/등록·로컬 DB/legacy 인증·양 역할 자료 무변경. 미확인 실기기: 등록선택/직접입력·장비 안내/보류·취소 알럿·재진입/회원 전환/대기시간 실제 표시 및 실장비 인증. 이 화면 구현을 소유 검증이나 ID/활동/왕관 완료로 확대하지 않는다. 다음은 서버/로컬 ID의 회원·환경·revision 소유 경계 설계와 이후 서버 활동 선택 연결이다.

공식 결과 회신: https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6184636914 . Backend 인계/조사 수신·실제 Flutter 변경/검증·미확인을 구분하고 추가 Backend 수정/시험은 요청하지 않았다. 현재 feature/account-verification-client 유지, 코드/관련 문서 미커밋·미push·dev 미반영. 기존 설계 미커밋/사용자 firestore.rules-backup1012/1013·tools는 보존, main/배포/DB·migration/자료삭제/Issue 종료는 변경하지 않았다.

## 2026-10-15 — 회원·환경별 서버 ID 연결 설계·L1a/L1b 구현 인계

사용자가 Backend에 착수 요청된 미완료 작업이 없다는 확인 뒤 `진행합시다`로 서버 ID 설계/L1 대조·회신을 승인했다. AGENTS/ai_rules/NEXT_WORK/AI_CONTEXT/README와 관련26/24·Issue8 본문/최신댓글을 확인했다. 현재feature/account-verification-client/HEAD와origin-dev cc6a0b0·기존 local/origin 목적 브랜치를 대조하고, 인증 직접 후속의 계약 설계이므로 브랜치를 재사용했다. 기존 미커밋 인증/설계·사용자Rules 백업/tools는 유지했다.

schema13 GameAccounts/AccountCharacters·ServerAccountIdentityBinding/Repository·DB.bindServerIdentity·summary/profile writer·서버 power 표시/등록 전체페이지 read·Backend cd3e003 models를 읽었다. 기존 mapping에는 회원/환경/revision provenance가 없고 mismatch 재매핑/active 저장 예외가 있으며, 로컬 이름 기반 writer와 서버 표시 대조는 세대 동일성 증거가 아님을 확인했다. 기존 원자성/중복/소속/재매핑 시험은 보존 근거이며 현대 scope 검증 통과로 확대하지 않았다.

계약29에 환경(정규화 API base URI)/회원/등록관계/canonical ID·lifecycle/세션과 서버 자격·기기 metadata 수명을 분리했다. 출처 없는 기존 행/같은 이름 빌드 승계·자동연결/삭제 금지, 새 ID 빈 개인 공간, V1 앞뒤 등록/전체페이지 revision 대조와 V2 실제계약 후 소비, 저장 전 scope/local revision·기기 transaction 및 최종 서버 자격 재검증을 설계했다. exact Drift schema·writer 분리/DI·활동·왕관은 별도 다음 단위다. 로그인 주목록 교체·게스트 가져오기/전체복원은 새로 채택하지 않았다.

공식 schema 조사6184587789와 보완6183941103의 긍정관찰/부재증거 분리·보장 미기재 판정을 수용했다. Backend L1a 기존 UUID/NameClaim·이력 기반/이름 단독 소유·복구 차단/캐시·전경로 fencing, L1b V2 현재characters·이력 GET의 개발브랜치 코드/migration 파일·격리 PostgreSQL 검증/원격계약 인계를6185091368(https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6185091368)로 명시 요청하고 본문 일치를 재조회했다. Backend는 Flutter UI/저장 연결을 기다리지 않으며 L1a부터 독립 게시할 수 있다. V1 shape 보존/의도된 보수적 제한 수용·외부 호출/네트워크 lock·기존대표/5분제한폐지 보호와 구체 검증/담당/완료조건을 인계했다. liveproof·퇴역/claim해제/소유추정·L2/L3/개발·운영DB적용/backfill/자료삭제·API재기동/배포/파티전체/Issue종료는 제외했다.

NEXT_WORK를 현재 단일범위/담당/대기·다음scoped storage설계로 교체하고 완료 상세의 중복 누적을 줄였다. AI_CONTEXT의 중복·과거 미회신 상태를 최신 요약으로 정리하고 README/26/29에 수용/실제요청 링크를 반영했다. 실제 Backend 착수/완료는 아직 미회신이다.

새로 가능해진 흐름: Flutter 연결 설계와 구체 L1 착수 범위가 원격에서 읽히므로 Backend의 미요청 대기 원인을 해소. 보존 확인: 기능코드/DB/기기/키·기존 인증/양 역할 빌드/회원자료 무변경, 출처 없는 과거 자료 역귀속 없음. 검증: 코드·문서·원격 댓글/Backend모델 대조, 게시본문일치·문서 diffcheck/링크 점검. 기능 변경이 없어 전체1282PASS/lib-test분석0은 이전 인증 구간 근거로 보존하고 반복 실행하지 않았다. 미확인실기기: 실제 소유/서버ID연결·활동/왕관, L1 구현/계약/DB시험은 상대 후속이다. 현재브랜치유지·설계/인증미커밋·미push·dev미반영,main불변.

## 2026-10-15 — 회원·환경별 캐시 DB·writer 분리 세부 설계

사용자가 다음 scoped storage/writer 설계를 진행하도록 승인했다. 필수 진입 문서와 계약29·실제 schema13/빌드·summary/profile/관리·자동갱신/삭제 경로를 대조하고 feature/account-verification-client/HEAD·origin-dev cc6a0b0·기존 목적 브랜치·미커밋 상태를 확인했다. 현재 목적 브랜치를 재사용하고 이전 인증/설계 및 사용자Rules/tools는 보존했다. Issue8 최신은 L1요청6185091368이며 신규Backend착수/완료회신은 없었다.

계약30에 기존 lost_party/schema13과 별도 ScopedAccountCacheDatabase/lost_party_server_cache·초기schema1의 scope/등록/accounthead/character4캐시 테이블을 설계했다. 환경키/회원·typed scoped ref·immutable UUID/account관계·composite FK/RESTRICT, 등록/캐릭터 미관찰 snapshot sequence·metadata_only/complete 및 source/nullable·local/server revision·CAS·전체페이지 원자 적용을 정의했다. 등록 요약만 있는 상태를 빈 전체 원정대 성공으로 보지 않는다. 기존 데이터 역귀속/빌드 자동복사·name fallback·가짜정수ID·서버자격 생성은 없다.

runtime receipt/session fence·요청sequence·row version을 분리하고 조회/쓰기 전후 검사·rollback·commit/session 경합의 한계를 명시했다. 이전scope commit이 먼저완료될수있어도새회원scope에저장/노출하지않으며persisted usable/owned로명령을열지않는다. 같은ID의lifecycle revision변경은개인빌드보존/재검증,새ID는다른공간으로구분했다. profile/summary/bind/build/관리/coordinator/power/삭제 writer별 legacy보존과신규경계를정의했다. 역할정책순수분석은재사용하고양역할/선호보존은후속writer에서검증한다. 개인build/preference테이블은키/수명만정하고초기4테이블구현에선제생성하지않는다.

다음구현S1은실행DI/네트워크/화면없이새저장소·typed fence/read/apply/CAS와메모리DB경계시험만수행할수있도록종료조건을확정했다. Backend L1b원본계약은S2adapter의선행이며S1구현을막지않는다. 문서29/README/AI_CONTEXT를연결하고NEXT_WORK를S1단일계획으로교체했다. 설계결과6185868981(https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6185868981)을게시·원격본문일치확인,기존L1요청을유지하고추가Backend수정/시험을요청하지않았다.

새로가능:독립S1저장기반구현의키/제약·검증/회귀·완료조건확정. 보존확인:이번기능코드/DDL·schema13/기기자료/키/Router/DI무변경·기존양역할자료보존. 미확인실기기:실제scope저장/API/활동/왕관·소유장비인수는아직미구현/미확인. 검증은소스/문서대조·링크/whitespace/gitdiffcheck·회신본문일치이며기존인증1282PASS/분석0은이전결과로보존하고재실행하지않았다. 현재feature/account-verification-client유지·코드/문서미커밋/dev미반영/미push,실DB/삭제/배포/Issue종료없음.

## 2026-10-15 — S1 회원·환경별 격리 캐시 DB 구현

사용자가API연결선행진행을승인했다. 필수문서/계약30·실제기준/최신Issue8과Git/목적브랜치목록을대조했다. 기존feature/account-verification-client는인증목적이고scoped/cache기존브랜치가없어,S1저장기반/메모리검증을마치면종료하는feature/scoped-account-cache를cc6a0b0에서생성·확인했다. 이전인증코드/설계미커밋과사용자Rules/tools를이동·stage·덮어쓰기하지않고보존했다. NEXT_WORK에구현순서/최종검증범위를먼저기록했다.

새5파일은domain/scoped_cache_models.dart, data/local/scoped_account_cache_database.dart와해당Drift생성물, data/repositories/scoped_character_cache_repository.dart, test/features/account/backend_read/scoped_character_cache_test.dart다. 내부StorageScope/typed refs·정규화immutable snapshot/UTC·UUID·source/null·별도schema1/4테이블·FK/RESTRICT·기본디스크연결없음을구현했다. build_runner는새g.dart한개filter로생성했고기존AccountDatabase/생성물/Router/DI를변경하지않았다. 내부모델/fixture는Backend wire DTO가아니다.

Repository는회원/환경·runtime/session/조회순서token·등록/head local-version CAS·전체등록/원정대transaction/read·receipt를구현했다. metadata_only/complete·현재snapshot미관찰은분리하고기존행을파괴하지않는다. 소유revision가림후하한값보존·새소유수명의settings reset과후퇴구분·동일캐릭터ID/account·이름불변/퇴역ID부활거절·새이름ID별도행을적용했다. 같은ID의lifecycle revision변경은관찰갱신이며개인자료테이블은추가하지않았다. source/구조가일치하는최신complete관찰의표시payload를반환해ownership-lost preview fresh수치와소유/사용자격을분리했다. retained readCharacter는과거관찰일수있어최신허가로사용하지않도록문서화했다.

자동검증: 초기생성타입컴파일범위분석에서중괄호info2개수정, 표적25PASS후lib/test분석의unused import1개제거. ID개명/부활·unknown lifecycle경계보완후전체1310PASS, preview표시payload보존경계수정/시험추가후 **최종전체1311PASS(기존1282+신규29)**·**lib/test분석0**·format/diffcheck완료. 둘을합산하지않는다. 메모리SQLite의4테이블/schema1/FK활성·legacyDB별도보존,scope분리·참조/재할당/후퇴/부활,transaction중도failure rollback·독립RepositoryCAS·queuedDB작업중회원전환·새runtime receipt거절을확인했다. 로그 .dart_tool/scoped-cache-final-tests.log / scoped-cache-final-analyze.log. 전체최종검증뒤코드는변경하지않았다.

Backend L1a6f3d029/6186038066과L1bc91af2e/6186143574의구현/원본게시수신을기록하고, dev/main미통합·실DB0007미적용/실행API미전환·별도185/113/57시험결과/proof보류를구분했다. 결과6187076006(https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6187076006)을게시·원격본문일치확인했다. 추가Backend수정/실키/반복시험·DB적용/재배포/삭제/Issue종료요청은없다. NEXT_WORK를S2정확한L1b현재캐릭터/이력조회adapter·DTO/페이지/오류/정규화캐시연결구간으로교체했다.

새로가능:독립된S1 격리 캐시의typedread/apply/CAS/receipt를S2에서재사용. 보존확인:전체회귀와기존DB/양역할·표시/주간자료·인증/키·Router/DI무변경. 미확인실기기:새캐시runtime/UI/네트워크/API소비·실장비/소유·활동/왕관모두후속이다. 앱에새DB가자동생성되도록연결하거나기기설치/조작하지않았다. 현재feature/scoped-account-cache유지·S1/기존인증/문서미커밋·미push·dev미반영,main·실서버/DB/키자료불변이다.

## 2026-10-15 — S2 현재 캐릭터·퇴역 이력 조회 API adapter

사용자 `연결 진행합니다` 승인으로 필수 진입 문서/계약30·Git/기존 목적 브랜치와 Issue8 최신 댓글을 대조했다. S1에 직접 종속되는 조회/캐시 adapter이므로 feature/scoped-account-cache/cc6a0b0를 재사용했다. origin/dev도 cc6a0b0를 유지함을 확인했다. 이전 인증/설계·S1과 사용자 Rules/tools 미커밋은 보존했다. NEXT_WORK에 구현 순서·정합성/회귀 보호를 먼저 기록했다.

Backend c91af2e003877daacb833aaa0c109eae11b72816 OpenAPI를 contracts/issue8-c91af2e.openapi.json에 고정했다. 신규 domain/server_character_lifecycle.dart의 4DTO는 모든 필수/nullable·enum/UUID/UTC·revision을 검사하며 기존 SettingsOut/관찰 parser를 재사용한다. selection_complete optional true 기본값·수치 문자열/null을 보존한다. source service.reg_out와 lifecycle_reads.characters를 대조해 preview의 V1 roster_revision=null→V2 registration.version generation만 명시 매핑했고 canonical 누락은 거절한다.

신규 data/server_character_lifecycle_client.dart는 기존 Bearer transport로 GET2개를 호출한다. V1 등록 전체→S1 metadata→roster token→V2 전체페이지 구조/현재 metadata 대조→S1 원자 적용을 연결했다. 등록/account/main/소유/roster/전체 settings·중복ID/이름/반복cursor/최대200·오류/부분결과·늦은 회원/환경을 거절한다. power 관찰 시각/값은 구조 revision 불변 내 차이를 허용한다. preview/소유상실은 canonical ID/revision null과 usable=false를 유지하고 fresh 표시값만 보존한다. 이름 재사용 새 ID와 과거 미관찰 ID는 분리하며 기존 개인자료 writer를 호출하지 않는다.

퇴역 이력은 명시 한 페이지/최대50 조회·typed DTO와 client/회원/세션/환경/history revision에 묶인 일회용 continuation이다. 새 순회/중복/늦은 결과를 차단한다. 중복 검사용 연속 순회10000건의 메모리 상한은 로컬 읽기 한도이며 서버 보관기간이 아니다. 이력 영속 저장·삭제/ACK·무제한 자동 수집을 추가하지 않았다.

검증: 신규 server_character_lifecycle_client_test.dart 초기33개 중 fixture cascade 범위 오류2개를 바로잡아33PASS 후 경계를 보강해42PASS. 최종 **전체1353PASS(기존1311+신규42)**·**lib/test분석0**·format/diffcheck와 신규 파일 공백/원본 snapshot 대조를 완료했다. 4DTO 필수속성 전수누락/추가·UTC/null/type·preview fresh·구조/권한/cursor/최대200·부분 batch 무반영·401 단일 refresh·409/403/404/429 code/status/request ID/retry metadata·네트워크 보존·회원/동일회원 재로그인/환경/late/latest·이름 재사용·history continuation을 모의 HTTP/메모리SQLite에서 검증했다. 최종 로그 .dart_tool/lifecycle-final-tests.log(41초)/lifecycle-final-analyze.log. 전체 검증 뒤 기능 코드는 변경하지 않았다.

결과 [6187403079](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6187403079)를 같은 Issue8에 게시하고 원격 본문 일치를 확인했다. 추가 Backend 수정/반복시험·배포/실DB적용/삭제·증거 보류 해제/Issue종료 요청은 없다. 계약30/README/AI_CONTEXT를 갱신하고 NEXT_WORK는 S3 실행 연결 설계로 전환했다.

새로 가능: opt-in V2 현재 roster 조회→S1 검증 캐시 적용/receipt와 회원별 퇴역 이력 페이지 조회. 보존 확인: 전체 기존 회귀와 V1/인증/키/전투력·S1/기존DB·역할/주간자료·실행 Router/DI 불변. 미확인 실기기: 실행 DI/기본 디스크/화면·실제 V2 서버/provider·소유/장비proof/퇴역·활동/왕관 인수는 미연결/미확인이다. 실제 Backend DB0007/실행 API 미전환을 유지하며 설치/조작·자료 이관/파괴정리하지 않았다. 현재 feature/scoped-account-cache 유지·신규/기존 변경 미커밋·미push·dev미반영·main 불변, 브랜치 유지가 필요하다.

## 2026-10-15 — S3 app runtime·서버 조회 실행 연결 설계

사용자 `설계 진행` 지시에 따라 문서 설계만 수행했다. 필수 진입 문서·계약29/30과 현재 BackendApp/_createRouter/readSession·MyAccountPage 서버 영역·V1 Read/Registration/Power/Verification 및 S1/S2를 대조했다. Issue8 최신은 Backend L1b6186143574와 Flutter S2 회신6187403079이며 새 Backend 변경 요청은 없었다. feature/scoped-account-cache/HEAD·origin-dev cc6a0b0·관련 기존 local/origin 브랜치와 미커밋을 확인해 S1/S2 직접 후속 설계로 같은 브랜치를 재사용했다.

계약30 §8에 수명/소유·등록 metadata/선택 roster queue·실제 URI·회원/세션 fence·hydration/receipt/preview·이력/오류·배포 준비 조건을 확정했다. 기존 serverAccountsSection만 새 서버 경로 대상으로 삼고 local 캐릭터 주목록/빌드·표시·주간은 보존한다. S3b는 V2 현재 상태 상세를 연결하며 기존 V1 전투력 화면은 보조 route로 유지한다. 이름 기반 power cache에 V2를 합치지 않는다. 다음 S3a는 주입 가능한 runtime/controller·별도 DB factory와 S2 공유 registration Repository/성공 typed metadata 반환만 구현하고, 실제 BackendApp/Router/gated UI 연결은 S3b 단위다.

조사에서 확인한 경계: V1 초기 목록은 기존 공용 Repository가 공유하지만 S2는 별도 Repository를 생성하므로 주입 경계가 필요하다. S1의 account-null preview는 head/receipt·complete가 없어 이번 조회 성공 stamp를 controller에 별도로 둔다. 디스크 empty는 서버 empty가 아니며 부분/오류를 삭제/퇴역으로 저장하지 않는다. S2 history continuation은 전송 전에 일회 소비되므로 실패 시 처음부터 재조회한다. Dio5.9.2 options.dart의 baseUrl+path/중복슬래시 축약을 확인해 URI 의도와 실제가 다른 설정은 runtime 구성에서 거절하도록 했다. 기존 인증/키 origin 분리 한계는 cache base-path 격리와 구분한다.

활성화는 S3b 시작 설정 BACKEND_LIFECYCLE_READS_ENABLED 기본false다. OFF 기존 V1 유지, ON V2 오류를 V1 성공으로 바꾸지 않는다. 현재 상태/이력 GET은 개인 API 키·나이스단 설정 완료를 새로 기다리지 않는다. Flutter S3a/S3b 코드·모의검증은 Backend 배포를 기다릴 필요가 없고, 실환경 ON/사용자 인수만 별도 승인과 대상 코드/DB0007/실행 API 준비 확인 후다. 추가 제품 결정이나 Backend API 변경은 필요하지 않다. 실배포/DB적용·live proof/퇴역·claim해제·자료 삭제/ACK는 계속 제외한다.

S3a/S3b 자동검증·한 번의 사용자 수동 확인 항목과 종료 조건을 계약30에 기록하고 NEXT_WORK를 S3a 단일 구현 범위로 교체했다. AI_CONTEXT의 선행 S1/S2 상세를 축약하고 README의 오래된 다음 작업 문구를 바로잡았다. [설계 회신6187560938](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6187560938)을 게시하고 원격 본문 일치를 확인했다. Backend 새 수정/반복시험·DB전환/배포 요청은 없다.

새로 가능: S3a를 추가 제품 결정/Backend 변경 없이 구현할 수 있는 경계·단계/완료조건이 확정됐다. 보존 확인: 기능코드/설정/DDL·실제 DB/키/서버·기존 local/역할 흐름은 무변경이며 BackendApp/S1/S2/직접 관련 테스트의 시작/종료 SHA256 일치도 확인했다. 미확인 실기기: runtime/UI·실제 V2/API/디스크·소유/장비·활동/왕관은 아직 미구현 또는 미인수다. 검증은 문서/소스/원본·링크·git diff --check이며 이전 최종전체1353PASS/lib-test분석0을 반복 실행하지 않았다. 현재 feature/scoped-account-cache 유지·이번 문서/이전 인증/S1/S2 미커밋·미push·dev미반영·main 불변, 브랜치 유지 필요.

## 2026-10-15 — S3a 서버 캐시 runtime/controller 구현

사용자 `다음 작업을 진행합니다` 승인으로 S3a를 구현했다. 필수 문서/계약30 §8·실제 S1/S2/세션/초기 조회 공유와 기존 경계 시험, Issue8 최신6187560938을 대조했다. feature/scoped-account-cache를 직접 후속으로 재사용하고 HEAD·origin-dev cc6a0b0·관련 local/origin 브랜치와 이전 인증/설계/S1/S2·사용자 Rules/tools 미커밋을 확인·보존했다. NEXT_WORK에 착수/실제 API 최소 확장·검증 순서를 먼저 기록했다.

신규 data/scoped_account_runtime.dart는 같은 readSession/accountApi·공용 registration Repository, 불변 환경/실제 request URI·HTTP debug 정책, 주입 factory/lazy 단일 connection·별도 drift_flutter DB 이름, 세션/호출 전후 fence를 제공한다. 생성/게스트/비활성은 새 DB/HTTP0이다. runtime factory connection은 ownsDatabase=true일 때 진행 tracked 작업 종료 후 한 번 닫고 false의 외부 connection과 Dio/인증 세션은 보존한다. 즉시 논리 무효화와 이미 실행 중인 DB/HTTP 종료 대기를 구분한다. DB 실패를 빈 성공·삭제/자동 재생성으로 바꾸지 않는다. AccountDatabase/Drift schema·생성물은 변경하지 않았다.

S2 ServerCharacterLifecycleClient는 공용 ServerAccountReadRepository 선택적 주입/동일 API-session 검사, refreshRegistrations shareInFlight와 성공 typed metadata 반환만 보완했다. 초기 진행 중 GET 공유·명시 새 GET·count/대표 요약과 기존 wire/오류/preview 정책을 보존한다. S1 ScopedCharacterCacheRepository에는 관찰을 남기고 token/receipt를 동기 폐기하는 invalidateReads()만 추가했다. FK/CAS/정규화/역할·권한 정책을 복제하지 않았다.

신규 ScopedAccountViewModel은 명시 initialize 후 세션별 초기화, 캐시 hydrate/서버 empty 구분·metadata/선택 roster queue/동일 작업 공유·명시 invalidation/현재 선택 재조회·canonical receipt와 null-head preview 성공 stamp·이전 관찰/오류·fixed deadline을 관리한다. 회원/동일회원 새세대·로그아웃은 private rows/selection/history/error/timer를 즉시 비우고 queued/늦은 결과를 억제한다. metadata 중간 변경과 외부 token 충돌은 오래된 snapshot 재적용 없이 재조회로 복구한다. 이력은 명시 open/restart/loadMore/close 한 페이지·DB미사용이며 소비된 continuation 실패는 불완전 prefix+needsRestart다. timer는 표시만 갱신한다. 미선택 원정대/이력·키/provider 자동 조회나 서버 ACK·자료 정리는 없다.

검증: 신규 scoped_account_runtime_test.dart 초기27개 포함 S1/S2 표적98PASS. 분석 미사용 helper/스타일10건을 정리하고 서로 다른 account queue·같은 세션 외부 무효화2경계를 보강했다. 최종 **전체1382PASS(선행1353+신규29)**·**lib/test분석0**·format/diffcheck·신규 공백 검토. 두 실행은 합산하지 않는다. 비활성/guest0·초기 공유/재진입·typed count·disk empty/server empty·canonical/preview·부분/제거·metadata-roster 경합/account queue·same/different session/late factory·URI/환경·history restart/late/deadline·DB실패/소유close·실제 임시 SQLite 재실행 stale 관찰을 확인했다. .dart_tool/scoped-runtime-final-tests.log(79초)/scoped-runtime-final-analyze.log. 최종 검증 뒤 기능코드는 변경하지 않았다.

[결과 회신6189141597](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6189141597)을 같은 Issue8에 게시하고 원격 본문 일치를 확인했다. 계약30/29·README/AI_CONTEXT 상태를 갱신하고 NEXT_WORK를 S3b 단일 실행 DI/Router·서버 현재 상태/이력 화면 연결로 전환했다. 추가 Backend API 변경/반복시험·실DB적용/배포·proof/퇴역 보류 해제/Issue종료 요청은 없다. 실제 Backend DB0007/실행 API 전환·실환경 플래그ON/사용자 인수는 별도 승인/준비 확인 후다.

새로 가능: S3b에서 동일 app runtime/state에 서버 현재 상태와 이력 UI·명시 관리/인증 callback을 연결할 실행 기반. 보존 확인: 최종 전체 기존 회귀·V1/인증/키/전투력·기존DB/schema13/양역할·주간자료·기존 실행 BackendApp/Router/화면(이번 변경 기준). 미확인 실기기: 실제 gated DI/기본 drift_flutter 디스크 경로·V2 서버/provider·장비 소유·활동/왕관 인수는 후속이다. 앱의 기본 factory 호출/실자료/기기 설치·조작은 하지 않았다. 현재 feature/scoped-account-cache/cc6a0b0 유지·신규/기존 변경 미커밋·미push·dev미반영·main 불변, 다음 S3b를 위해 브랜치 유지 필요.

## 2026-10-15 — S3b gated 앱 DI·현재 상태/이력 화면 연결

사용자 `진행합니다` 승인으로 S3b를 진행했다. 필수 진입 문서·계약30 §8·최신 Issue8과 실제 API/Router/DI/쓰기 흐름을 대조하고 NEXT_WORK에 포함·제외/순서/회귀 보호 목록을 먼저 기록했다. feature/scoped-account-cache/HEAD·origin-dev cc6a0b0를 재확인해 재사용했으며 이전 인증/설계/S1/S2/S3a와 사용자 Rules/tools 미커밋을 보존했다. 최신 Backend 회신은 L1b6186143574/원본c91af2e이며 새 변경 요청은 없다.

BackendAccountLifecycle이 같은 session/API/공유 registration Repository의 runtime/state와 DB 수명을 소유한다. BACKEND_LIFECYCLE_READS_ENABLED 기본false로 OFF 기존 V1 서버 패널/상세·전투력과 새 DB/V2 0호출을 유지한다. ON은 서버 패널·현재 상태 상세, 기존 V1 전투력 보조 /power, 회원 이력 /account/character-retirements다. 과거 관찰/metadata-only·현재 canonical/preview·확인 시각·소유/설정·캐릭터 이상/오류/대기를 구분하고 조회 실패를 빈 성공이나 V1 성공으로 바꾸지 않는다. 등록0개 이력 진입·명시 더 보기/처음부터 재조회·나가기 폐기, 회원 전환/늦은 응답 차단을 연결했다. 새 로컬 writer·역할/식별자 합치기·이력 DB/ACK는 없다.

기존 ServerRegistrationViewModel에 scope가 붙은 시작/종료 callback만 최소 추가했다. 시작은 현재성을 무효화하고 겹친 GET을 막으며 종료는 metadata/선택 roster를 재조회한다. 쓰기의 결과 불확실 pending은 읽기 성공으로 확정하지 않는다. 관리/인증 복귀는 이전 진행 GET을 새 성공으로 재사용하지 않고 명시 무효화 후 새로 조회한다. 같은 회원/다른 회원 세대 fence·app close 소유를 유지하고 history dispose는 무통지 정리로 build 중 notify를 피했다.

검증: 신규 scoped_account_ui_test.dart 최종12개. 기본OFF 무IO/생산 route·V1 전투력 경로·V2 404 실패 유지·등록0개 이력·로그아웃 즉시 제거/이력 무DB·이탈 뒤 late/dispose·쓰기 중 GET 차단/실제 명령 성공과 불확실 pending 보존·이전회원 callback·인증 callback/진행 GET 경합을 검증했다. 위젯 테스트의 fake/real 비동기 구간을 분리해 모의 SQLite/Completer 대기를 바로잡았다. 초기 전체1393PASS/분석0 뒤 최종 검토에서 인증 GET 경합을 보완·1경계를 추가했으며 최종 **전체1394PASS(선행1382+신규12)**·**lib/test분석0**·format/diffcheck·diff 검토다. 실행별 결과를 합산하지 않는다. 최종 로그 .dart_tool/scoped-ui-final-tests.log(67초)/scoped-ui-final-analyze.log(8.3초). 최종 전체 검사 이후 기능코드 변경 없음.

[Issue8 결과6190026125](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6190026125)을 게시하고 원격 본문 일치를 확인했다. README/AI_CONTEXT/계약29·30을 현재 상태로 맞추고 NEXT_WORK에 실제 대상 환경 준비·승인/한 번의 사용자 수동 체크리스트·미커밋 정리/dev 통합을 남겼다. Backend 추가 수정/반복시험·DB 전환/배포·Issue 종료 요청은 없다.

새로 가능해진 흐름: ON 구성에서 앱 서버 원정대 현재 상태/회원 이력과 관리·인증 후 새 조회, 기존 전투력 보조 진입을 사용할 코드 연결. 보존 확인한 기존 흐름: 최종 전체회귀의 V1/전투력·인증/키/로컬 빌드/양역할·주간/schema13·S1/S2/S3a와 기본OFF 무IO. 미확인 실기기 항목: 실제 gated 화면 인수·기본 디스크 경로/재실행·실제 V2 서버/provider·장비 소유/활동/왕관. 모의 HTTP/SQLite 통과이며 실제 대상 코드·DB0007/실행 API 준비와 별도 승인 전에는 실환경 ON으로 안내하지 않는다. 기기 설치·조작/서버 배포·실DB/실자료·키 변경은 없다.

현재 feature/scoped-account-cache/cc6a0b0 유지·이번/이전 변경 미커밋·미push·dev미반영·main 불변이다. 코드·자동검증 구간은 완료됐지만 저장소 통합/실환경 인수는 미완료이며 브랜치 유지가 필요하다.

## 2026-10-15 — 자동 갱신 다음 구간 기획·저장 개념 재확인 우선

사용자는 S3b 조회 연결을 전체 자동 갱신 완료/디바이스 테스트 단계로 설명한 오류를 지적했고, 다음 자동 갱신 구간의 기획·UX 동의 필요 여부를 확인하도록 지시했다. 필수 문서·실제 저장/분석/준비 소스·최신 Issue8(6190026125)과 Git을 대조했다. 기능코드/DB/플래그는 변경하지 않았다. 기존 자동1회/진행/미완료 재시도·경고 저장/설정 시작값·회원 전환 UX는 유지한다.

설계23에 설정 의미(나이스단 포함 허용값과 별도 V2 개발 플래그), 회원별 역할 저장/판정 A→준비/실행 B→화면/최종검증 C를 검토안으로 기록했다. 구 int-ID Coordinator·기기 공용 commit을 그대로 startup에 연결하지 않고 scope/UUID 역할 저장과 transaction guard가 선행해야 한다. 새 전체 마스터 설정/API나 Backend 변경 요청은 만들지 않았다. S3b의1394PASS/분석0은 조회 연결 결과이며 자동 갱신 완료를 뜻하지 않는다.

추가 UI 질문은 결과를 서버 원정대 영역에 표시할지, 기존 주목록의 회원별 전환까지 포함할지 1건이었다. 사용자 회신은 ‘일단 캐릭터의 저장되는 개념부터 작업 전에 확인’이므로 A/B 선택을 추정하지 않았다. NEXT_WORK를 저장 개념 재확인으로 바꾸고 설계23에 Backend 회원 소속/ID, 기기 공용 정수PK 캐릭터·역할 빌드, 새 회원별4테이블 조회 캐시와 미구현 역할 저장 대조를 기록했다. 두 목록 유지를 최종 UX로 정한 것도 아니며 저장/복원 개념 확인 후 화면·구현 범위를 확정한다.

새로 가능해진 흐름: 자동 갱신 구현 전에 실제 저장과 제안을 구분해 검토할 문서/단계 기준. 보존 확인: 기능코드/기존 자료·설정·키·실환경 무변경. 미확인 실기기: 자동 실행은 미연결이며 지금 사용자 테스트를 요청하지 않는다. 검증은 직접 소스/계약/문서·git diff --check이며 문서만 변경해 Flutter 검사를 반복하지 않았다. Issue8에 대한 새 요청 대응이 아닌 독립 Flutter 기획이므로 변화 없는 회신/Backend 재시험 요청은 게시하지 않았다.

현재 feature/scoped-account-cache/HEAD·origin-dev cc6a0b0를 재확인해 직접 후속 설계에 재사용했다. 이전 미커밋·Rules/tools를 보존했고 이번 문서도 미커밋·미push·dev미반영이다. 브랜치 유지·실자료/배포 변경 없음.

## 2026-10-15 — 사용자 교정: 활성 캐릭터 전체 상세 검사·나이스단 OFF 필수 예외

사용자는 앱 사용 활성 캐릭터 모두를 실행당1회 상세 조회해 오류를 검사해야 하며, 동일 직업 캐릭터 간 보석 공유/종료 전 창고 보관 UX상 나이스단 OFF는 반드시 자동 검사 제외로 유지해야 한다고 명확히 교정했다. 상세 화면 진입까지 분석을 미루거나 예외 대상을 파티 행동 시 강제 검사하는 제안은 요구와 달라 철회했다.

설계23 상단에 최신 우선 규칙과 대상 공식(앱 활동 활성 집합에서 OFF 나이스단 제외)을 기록하고 본문의 대상 판정/상세 조회 단계를 바로잡았다. NEXT_WORK/AI_CONTEXT에도 동기화했다. 활성과 표시 개수는 별개이며 비활성 대상/추가 미합의 레벨 필터를 넣지 않는다. OFF 대상은 호출·덮어쓰기 없이 기존 빌드/오류/확인 시각을 유지하고 실패·부정 판정·미완료 재시도에 자동 포함하지 않는다. 소유/활동의 기존 서버 권한과 새 검사 의무를 혼동하지 않는다.

새로 가능: 요구에 맞춘 자동 조회 대상/예외/시점 설계 기준. 보존: 나이스단 설정/수동 저장 UX와 기능코드·DB·실자료 무변경. 미확인: 저장/복원 설계·전체 자동 실행은 미구현이며 사용자 기기 테스트 요청 없음. 문서 검토/diffcheck만 수행하고 기능 테스트는 반복하지 않았다. feature/scoped-account-cache 유지, 문서/이전 변경 미커밋·미push·dev미반영. Backend 변경/배포 요청 없음.

## 2026-10-15 — 서버 최소 복원·로컬 저장 대기·회원별 단일 주목록 확정

사용자가 세 추천안을 모두 선택했다. 서버에는 역할별 핵심 수치·오류 요약/확인 시각과 선호역할/표시 설정을 복원용으로 보관하고 상세 원본은 로컬에 둔다. 서버 저장 실패 시 유효한 로컬 결과를 먼저 표시하되 서버 저장 대기 상태로 유지해 같은 회원의 유효 자료만 재전송한다. 로그인 주목록은 회원별 하나이며 기존 기기 공용 자료는 별도 경로로 보존하고 자동 연결/이관/삭제하지 않는다. 활성 캐릭터 전체 상세1회·나이스단OFF 필수 제외는 유지한다.

설계23에 최소 필드·로컬 원자 snapshot+영속 대기, 회원/환경/캐릭터 수명·version/멱등 경합·새 기기/원본 없음/로컬 pending와 서버 확정값 구분을 기록했다. OFF 대상은 새 기기에서도 서버 마지막 요약을 복원할 뿐 강제 상세 검사하지 않는다. 로그인 주목록 전환/서버 요약 복원은 이제 승인된 설계 범위이며 과거 S3b의 주목록 미변경/새 API 없음은 그 단계의 이력이다. NEXT_WORK/AI_CONTEXT/README/계약30을 맞췄다.

게시 c91af2e OpenAPI의 전체 paths와 Character/Lifecycle/Settings/Power 관련 schemas를 대조했다. character-settings는 활동/대표/revision, member-settings는 나이스단 bool/version이므로 역할별 오류 요약·선호/표시 복원용 read/write 계약이 없다. 새로운 필드를 기존 endpoint에 임의 송신하거나 provider 전투력 관찰로 취급하지 않는다. [이슈8 계약 검토 요청6191438610](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6191438610)을 게시하고 원격 본문과 로컬 원문 일치를 확인했다. Backend 담당의 기존/신규 계약 범위·정확한 원본/상한·소유/수명·version/멱등·다른 기기 충돌 회신을 대기한다. 계약 검토 요청이며 구현/DB적용·배포·Issue종료 승인이 아니다. Flutter 공통 실행·저장/화면 설계는 계속 정리 가능하고 새 wire adapter만 회신에 의존한다.

새로 가능: 저장/복원·동기화와 주목록 UX를 확정 기준으로 설계 가능. 보존 확인: 기능코드/DB·활성 대상과OFF예외·기존 자료/키/실환경 무변경. 미확인: 자동 실행/새 저장 API·주목록·영속대기는 아직 구현 전이며 기기 시험 요청 없음. 문서/소스·원본 대조·git diff --check만 검증했고 이전 전체1394PASS/분석0은 S3b 조회 연결 결과로만 보존했다. feature/scoped-account-cache/HEAD cc6a0b0 유지·이번/이전 변경 미커밋·미push·dev미반영, 사용자 Rules/tools 보존·브랜치 유지다.

## 2026-10-15 — Backend 저장·복원 계약안 대조·부분 수용 회신

사용자 ‘검토 회신 확인’ 지시로 이슈8 최신6191634445 원문 전체를 확보해 검토했다. Backend는 구현/OpenAPI c91af2e·작업HEAD dc09901, 새 구현/DDL/게시 원본 없는 미합의 제안이라고 명시했다. 이를 API 구현 완료/실환경 준비로 확대하지 않았다. 역할별 nullable 수치·요약/개인설정 분리·회원/소유수명 격리·version/멱등/영속대기와 별도 provider 관찰 보호 방향은 수용 가능하다.

실제 CharacterProfileDto/CharacterBuildSnapshot에는 dealer/support 모두 CombatPower/ItemAvgLevel만 있어 별도 버프력 metrics는 요구하지 않았다. BuildIntegritySnapshot/mapper는 clean/review/error/unavailable·catalogVersion을 가지며 issues가 비어 있어도 unavailable이 가능해 outcome success/warning만으로 정상 복원을 보장하지 못한다. typed 무결성 상태/동등 표현·카탈로그 출처 보존을 보완 요청했다. notice의 소문자/slot/정보성 안내를 그대로 strict issues로 보내지 않고 기존 통합7종 및 고정 범주로 정규화/중복제거·severity 매핑하는 adapter가 필요하다.

현재 GameAccounts.displayLimit 기본6개와 원정대별 대표/사용자순서/아이템레벨/이름 정렬을 확인했다. 회원 주목록 하나라는 선택을 전역 rank/기본 전체표시 변경 승인으로 해석하지 않았다. 기존 원정대별 표시 개수/정렬 복원으로 Backend 제안 수정을 요청했다. 부분 rank ACK는 저장 대기를 분리해 수용 가능하며 새 atomic batch는 요청하지 않았다. 나이스단 OFF는 기존 회원 공통 bool로 분류된 직업군을 제외한다는 뜻이고 캐릭터별 새 bool/override를 요구한 것이 아니라고 정정했다.

[Flutter 회신6192838766](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6192838766)을 게시하고 원격 본문 일치를 확인했다. 설계23/NEXT_WORK/AI_CONTEXT에 부분 수용·두 보완·수정 계약 회신 대기를 기록했다. 제품 세 선택을 다시 묻지 않으며 공통 실행/저장·화면 설계는 계속 가능하고 새 wire adapter만 합의/게시 계약 이후다. Backend 구현/실DB/배포 승인이 아니다.

새로 가능: 실제 분석 출력/기존 화면과 맞는 계약 수정 기준을 인계했다. 보존 확인: 기능코드/DB/플래그·기존 UX·활성전체/OFF예외·회원 공통 설정·실자료 무변경. 미확인: 새 기능/API/자동 실행은 아직 미구현·기기 인수 없음. 소스/계약/문서·diffcheck만 수행하고 Flutter 검사를 반복하지 않았다. feature/scoped-account-cache 유지·이번/이전 변경 미커밋·미push·dev미반영이며 사용자 Rules/tools와 브랜치를 보존했다.

## 2026-10-15 — 수정 계약 수용·Backend P1 역할요약 구현 요청

사용자 ‘진행합니다’ 승인으로 최신 이슈8 수정6193183186을 확인·대조했다. outcome 제거/무결성4상태·nullable catalog, 원정대별7필드 표시 DTO·기본6개/1~200·기존 정렬/등록해제경계, 회원 나이스단bool 유지가 두 보완 요청을 충족한다. 기존 캐릭터 관리 표시 개수는1 이상이고 visible 필터가 대표 우선보다 먼저라 숨긴 대표를 강제로 보이게 하지 않는 안과도 부합한다. 정확한 분석 실패/경고 저장·수치/소유수명/멱등·부분 ACK 원칙을 함께 수용했다.

[계약 수용/P1 구현 요청6193638580](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6193638580)을 게시하고 원격 본문 일치를 확인했다. 담당 Backend의 이번 범위는 역할요약 GET/PUT·기반 additive migration 코드/권한·양역할독립version·멱등/원자ACK 최소 격리검증·OpenAPI 불변원본/SHA와 원격push·제공 P1/P2 범위 인계다. P2 개인표시/선호는 계약 수용됐지만 P1 인계 후 다음 단위로 요청한다. 실DB migration 실행/서버 재시작·API환경전환/배포·자료 이관/삭제·live 증거 보류 해제·기기 설치/조작/Issue종료는 승인·요청하지 않았다.

설계23/NEXT_WORK/AI_CONTEXT/README에 계약 합의 완료·실제P1 구현게시 대기 상태를 기록했다. Flutter A1 준비는 scope+canonical UUID+ownership_revision(+role) 개인자료, lifecycle 관찰 fence, 로컬 상세/요약초안+outbox 원자 저장, 발송명령/새초안 분리·ACK의 정확한명령 정리,4상태/카탈로그/분석규칙 매핑과 최소 경계다. 게시 OpenAPI 전 예상 wire DTO/adapter·실제 DB migration을 구현하지 않는다. A1 뒤 P2 인계/A2 개인표시·B 실행/C 단일 주목록이 남으며 P1 인계만으로 전체 자동 갱신/디바이스 테스트 단계라고 보고하지 않는다.

새로 가능: 합의된 계약의 Backend P1 구현 인계와 Flutter A1의 구체적 저장/동기화 검증 순서. 보존 확인: 기능코드/DB/플래그·기존 자료/키·활성전체/OFF예외·단일 회원주목록 합의 불변. 미확인: P1 실제 API/자동 실행/새 저장·기기 인수는 미제공/미구현 상태. 검증은 수정원문·실제 정책 대조/문서/diffcheck이며 기능 테스트를 반복하지 않았다. feature/scoped-account-cache/cc6a0b0 유지·이번/이전 변경 미커밋·미push·dev미반영, Rules/tools 보존·브랜치 유지다.

## 2026-10-15 — Backend P1 원본 수신·대조 / Flutter A1 연결 가능

사용자 ‘문서 회신 확인’ 지시로 Backend P1완료6194881739를 확인했다. 불변 구현/원본6e4f625c3b62c92ec412373b33ed8a3441af8149의 openapi/openapi.yaml과 ISSUE_8_ROLE_SUMMARIES_DEVELOPMENT를 API로 확보했다. 원본바이트 snapshot contracts/issue8-6e4f625.openapi.yaml의 SHA256은52a2c491c293a97813cf46ce4eff487b889ba0481de0654f4fcf0b5cc9c9cd6b다. 원격브랜치는b31e7c85로전진했으나6e4f625의후속1개·인계문서만변경한commit임을compare API로확인했다. 제공 구현SHA는6e4f625고dev/main미통합이다.

일회성 Dart/YAML 파서로 이전 c91af2e JSON snapshot과 전체 기존 paths/components를 비교했다. JSON/YAML의1/1.0수치형표기를의미상동등정규화한뒤기존항목변경0, 새경로2/schema7추가를확인했다. 실제개인자료조회8필드/역할PUT입력4·응답7/summary11필드와필수nullable·무결성4상태/카탈로그·strict·숫자패턴(정수/소수예시)을대조했다. preferences는P2미구현고정가상기본값(const version1/null/true/null/null)이고저장ACK/복원완료가아니다. 미래P2스키마로확대하거나기존개인설정을이기본값으로덮지않는다.

Backend보고최종171PASS(79.99초)는격리PostgreSQL/mockprovider결과이며이전108과합산하지않았다. 실제서버는대표구간/DB0007·0008·P1/V2미전환이므로원본게시를실API/실기기준비완료로보고하지않는다. Flutter A1 모의구현·검증은가능하다. 이번은회신확인단계라기능코드를수정하거나Flutter테스트·실API/DB·플래그를실행하지않았다.

[수신회신/P2구현요청6195124835](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6195124835)을게시하고원격본문일치를확인했다. 앞서합의한P1인계후별도P2순서에따라개인선호/표시·원정대표시계약/정리경계코드·격리검증·정확한OpenAPI/불변SHA게시를요청했다. 실DBmigration실행/API전환·배포·실자료정리·live증거보류해제·기기인수/Issue종료는승인/요청하지않았다. P2대기는P1소비A1을막지않는다.

NEXT_WORK/AI_CONTEXT/README/설계23·계약30을Flutter A1 strict역할요약adapter·scoped상세/서버요약·영속대기·오류충돌연결가능으로갱신했다. 새로가능: 미게시wire추측없이P1기반A1구현착수가능. 보존확인: 기능코드/기존DB·자료·활성전체상세1회/나이스단OFF예외·회원별주목록합의불변. 미확인: Flutter자동실행/새저장연결·P2·실환경/기기인수는후속이다. 검증은원본/문서/구조비교·diffcheck이며기능시험을반복하지않았다. feature/scoped-account-cache/cc6a0b0유지·이번/이전변경미커밋·미push·dev미반영, 사용자Rules/tools보존·브랜치유지다.


## 2026-10-16 — 인증 대상 선택·응답 유실 UX 조사

사용자 실기기 보고로 등록 경로 인증 캐릭터 선택 누락과 start 미확정 시 선택영역 은폐·재진입 지속을 확인했다. CTA 세 곳을 원정대 인증으로 변경했다. 새로 가능해진 흐름은 문구 통일뿐이며 인증 picker/복구 동작은 아직 구현하지 않았다. 기존 인증 요청·판정·소유/세션 흐름은 변경하지 않았다. 고정3c8e799 StartIn의 상호배타 입력을 확인해 Issue8 84번째 Flutter 댓글 https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6215164426 에 등록+대상 캐릭터 계약/불확정 start 회수 경로 확인을 요청했다. NEXT_WORK에 UX 검토안·회귀 경계 기록. 최초 네트워크 오류 원인·실인증/재진입 수정 검증은 미확인이다. 문구/문서 변경으로 전체 Flutter 시험 반복 없이 diffcheck·문구 검토. feature/scoped-account-cache 유지·기존 변경 보존·미커밋/미push/dev 미반영.


## 2026-10-16 — 인증 계약 제안 대조·수용 회신

Issue8 85번째 Backend 회신과 고정3c8e799 StartIn·Flutter 등록version/캐릭터주소·불변명령/실행후현재GET을 대조했다. target_character+expected_registration_version 제안을 수용하고 86번째 Flutter 댓글 https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6215477051 에 다음 Backend 구현/검증/OpenAPI 게시를 인계했다. 새로 가능해진 것은 추가 사용자 결정 없는 다음 계약 구현 착수이며 새 picker/복구 기능 완료가 아니다. 기존 동일POST/key/body→ID회수→현재GET 경로를 재사용하고 새 결과조회 API/journal은 요구하지 않았다. 구형digest/strict8필드응답·미게시필드전송금지와 대상/버전오류 인계를 명시했다. 보존 확인: 기능코드·소유/활동/1700/세션/기존자동목록갱신 불변. 미확인: Backend 새계약/본인재인증/타소유pending 실제구현·실provider/기기·최초연결오류원인. 검증은 원본/코드/회신대조·원격댓글본문/순번검증·diffcheck이며 문서만 변경해 Flutter시험 반복 없음. feature/scoped-account-cache/cc6a0b0·기존변경보존·미커밋/미push/dev미반영·브랜치유지.


## 2026-10-16 — 인증 재진입·응답 유실 복구 UX 선행 보완

사용자 진행 승인 후 필수문서/현재Git·Issue8 최신86번째를 확인했다. 새target/version 미게시이므로 기존API를 유지하고 NEXT_WORK에 선행 범위/회귀/검증을 먼저 기록했다. 앱 공용 ServerVerificationViewModel에 불변 표시문맥(원정대표시명/등록ID 또는 직접이름)과 pendingAction을 두고 세션 변경 시 제거한다. Page에 재진입 대상요약·시작/확인/취소 진행/미확정, ACK후GET실패 안내·ID없는복구불가 안내를 연결하고 제목도 원정대 인증으로 통일했다. UI문맥은 서버body에 추가하지 않는다. 등록대상은 기존운영조회기준이므로 캐릭터명을 추정하지 않는다.

새로 가능: 화면을 나갔다 다른원정대경로로 다시 들어와도 원명령대상과 복구단계를 확인하고 기존같은요청으로 이어가기. 보존 확인: 실제 인증 handoff/상태/client42PASS의 중복/Retry-After·confirm/cancel/replay/현재GET·세션late/성공관리전환. 신규3경계는 재진입원대상/동일keybody→GET/새wire없음, ACK후GET실패/재진입POST0·로그아웃정보제거, ID없는멱등복구불가에서없는조회/새시작차단이다. 변경3파일 분석0·format/diffcheck·검토 완료. 로그 .dart_tool/auth-recovery-tests.log, auth-recovery-analyze.log. View/표시문맥에 한정되고 Router/DI/공용wire/schema변경없어 전체Flutter시험 반복 없음.

미확인: Backend새계약·본인재인증/타소유pending·캐릭터picker연결·실provider/기기·최초연결오류원인. 복구UI선행완료와 인증전체완료를 구분했다. Issue8 87번째 https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6215781843 에 결과/다음담당을 회신하고 원격본문/순번검증. feature/scoped-account-cache/cc6a0b0·기존변경보존·미커밋/미push/dev미반영·브랜치유지. flag/서버/키/DB/개발자료·환경/배포/기기조작·Issue종료 변경없음.


## 2026-10-16 — 원정대 인증 캐릭터 선택 연결·내 계정 문구 삭제

사용자 보고로 원정대선택후목록누락을 재확인했다. 기존 Page는 등록목록만읽었으며 Backend90번째cc372bfa가 게시한 새 target/version을 아직소비하지않았다. 필수문서/Git·최신댓글과 고정OpenAPI StartIn/VerificationTarget를 대조하고 NEXT_WORK에 범위/회귀/순서를 기록했다. 내계정 basicOnly의 기기조회/소유인증전 Text를삭제했으며 기존권한제한은보존했다.

새 ServerVerificationSelectionViewModel은 기존 Repository의 최신등록/해당전체캐릭터조회·계정표시정책을재사용하고 조회세대/회원fence·선택무효화를소유한다. Page에 원정대별후보/이름·서버·직업·아이템레벨선택과미선택시시작불가를연결했다. 후보는활동/대표/표시/1700·previewUUID로제한하지않는다. domain VerificationTarget와 paired version검사·중첩불변body를추가하고구형/direct요청body는유지했다. 서버등록/주소/revision/identity거절은명시재조회·재선택으로복귀하며자동대체시작하지않는다. 원명령요약에선택주소를보존하고binding보류는현재GET코드도유지해소유성공으로오인하지않게했다.

검증: 선행48PASS뒤 버전거절실제페이지재조회/새version전송과binding보류경계를추가해 최종50PASS·lib/test분석0·format/diffcheck. 실행합산없음. 신규/보완시험은 중첩불변/짝/범위·preview저레벨·조회전환/로그아웃late·실패/무효선택차단·실제picker유실재진입동일명령·버전거절후새목록명시선택/새version·보류비승격이다. 기존인증상태/client/성공관리handoff도통과했다. 로그 .dart_tool/auth-target-tests-final.log, auth-target-analyze-final.log. 인증로컬domain/선택/UI에한정되고Router/DI/schema변경없어전체Flutter시험반복없음.

새로가능: 등록원정대내캐릭터를선택해해당주소/최신등록version으로인증시작·재진입복구. 보존확인: 구registration/directwire·중복/Retry-After/replay후GET·confirm/cancel·세션late·성공관리 연결. 미확인: 실게임/provider/기기·최초연결오류원인. 사용자확인은NEXT_WORK에정리했다. Issue8 91번째 https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6216421322 에90번째소비결과/한계를회신하고원격본문/순번검증. feature/scoped-account-cache/cc6a0b0·기존변경보존·미커밋/미push/dev미반영·브랜치유지. 환경/자료/키/DB/flag·서버재시작/배포/기기조작/Issue종료변경없음.


## 2026-10-16 — 인증 장비 변경 후 갱신 필수 안내 강조

사용자 요청으로 ServerVerificationPage 장비 변경 대기의 ‘API 정보 갱신에 도움이 됩니다’ 안내를 ‘장비 변경 이후 캐릭터 선택창으로 이동하여 캐릭터 정보를 갱신하여야 합니다.’로 교체하고 별도 Text에 빨간색/굵게 적용했다. 비지정부위 변경금지 안내는 일반색으로 분리했다. 새로 가능해진 표시는 갱신이 필수라는 안내의 시각적 강조이며 인증 요청/판정/시간/복구·버튼 동작은 변경하지 않았다. 실기기 빨간문구/줄바꿈은 미확인이다. 표현/스타일만 변경해 format·diffcheck/소스검토로 검증하며 기능시험은 반복하지 않는다. feature/scoped-account-cache 유지·기존 변경 보존·미커밋/미push/dev미반영·브랜치유지.


## 2026-10-16 — 서버 원정대·인증 후보 기본 아이템레벨 정렬

사용자 요청으로 인증 후보/서버캐릭터·등록미리보기·현재상태 목록을 공통 rosterByItemLevel의 숫자 내림차순으로 표시했다. 콤마 숫자 파싱·null/비정상/비유한 값 후순위·동률 입력순서 유지이며 원본 리스트를 정렬/저장하지 않는다. 인증 selection의 표시 getter·기존V1/V2/preview 조회표시에만 적용해 사용자 displayOrder/rank를 소유한 내계정/관리/활동저장에는 영향이 없다. NEXT_WORK에 포함/제외와 회귀를 먼저 기록하고 필수문서/Git·기존 개인순서 정책·97번째 Backend 파서인계를 확인했다. 이번은 서버 변경/협업요청이 필요한 구간이 아니므로 반복 확인댓글은 게시하지 않았다.

새로가능: 전체조회·인증후보의 높은 아이템레벨 우선표시. 보존확인: 기존 로컬 개인순서/관리draft/selection/session·scopedUI 34PASS. 변경6파일 최종정적분석0·format/diffcheck/소스검토. 초기분석의LifecycleCharacter전용getter차이를 기존wire접근으로바로잡고최종분석통과했다. 로그 .dart_tool/roster-order-tests.log, roster-order-analyze-final.log. 표시에한정되어새동일UI시험/전체시험반복없음. 미확인: 실제화면순서/기기. feature/scoped-account-cache 유지·기존변경보존·미커밋/미push/dev미반영·브랜치유지, API/DB/schema/flag/키/자료/인증판정변경없음.


## 2026-10-16 — 실제인증 성공 수신·이전페이지복귀/안내간결화

사용자가 실제장비인증1회성공과 성공후화면잔류/과한텍스트를보고했다. 필수문서/Git·98번째Backend start201/confirm200·VERIFIED/소유연결/감사1개를대조했다. lifecycleOFF에는성공후이동이없고ON에서는관리화면강제전환이었다. NEXT_WORK에새UX/회귀를기록하고Page에성공완료콜백/이전Navigator복귀를연결했다. BackendApp은현재상태/현재회원·소유검증을유지한뒤이전경로pop·직접진입시/account복귀로바꾸었다. 과거verified재진입과로그아웃/화면이탈late이동차단은유지한다.

대상/해제부위/남은시간/필요한오류·복구행동만남기고중복설명·구현문구를삭제/축약했다. 빨간갱신안내는유지했다. 인증화면의외부조회실패/연결실패도간결하게구분했다. 미래문구에도핵심행동/상태만간결하게쓰며인게임표현은사용자가조정한다는원칙을ai_rules에기록했다. 앱전체기능/문구일괄개편은하지않았다.

새로가능: 성공후원래페이지로복귀·짧은인증안내. 보존확인: 새성공조회/1회복귀경계와기존과거성공재진입/회원late·미확정/replay/보류·현재소유검증, 인증관련51PASS. Router콜백변경영향으로최종전체1579PASS·lib/test분석0·format/diffcheck·검토. 로그 .dart_tool/auth-return-full.log, auth-return-analyze.log. 미확인: 이번새복귀/간결화UI실기기. 사용자의기존실인증1회성공은수신완료이며전체활동/대표/자동갱신/분쟁인수로확대하지않는다.

Issue8 99번째 https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6217416791 에성공수신/후속UX결과를회신하고원격본문/순번검증. feature/scoped-account-cache/cc6a0b0·기존변경보존·미커밋/미push/dev미반영·브랜치유지. 서버/DB/키/자료/flag/계약·배포/재시작/추가POST·기기조작/Issue종료변경없음.


## 2026-10-16 — 원정대 등록·인증 완료/누락 점검

사용자 요청으로 필수문서·등록19/인증28/후속14·실제 Router/reload/성공복귀·메모리복구/수동인증placeholder·최신Issue8 98/99와Git/기존검증로그를 대조했다. 등록·삭제·재로그인/갱신의기존사용자확인과실제장비인증1회/VERIFIED·현재소유연결이확인됐고최신전체1579PASS/분석0이다. 확인범위에서기본흐름필수구현누락은발견하지못했다. 새복귀/간결화·기본정렬실기기확인·기존미커밋Git통합이잔여이며기능재구축대기로해석하지않는다.

후속14 ACCOUNT-02의실장비미인수/ACCOUNT-03의활동UI미구현표현이현재코드/실제결과와달라 최신상태로정정했다. 타소유이전/24시간분쟁·앱종료후명령자동회수·live퇴역은별도미구현, 활동/대표/자동갱신실인수는다음구간으로구분했다. QA-01삭제후로컬보존확인은기존별도릴리즈점검이며미재현결함으로유지한다. 코드/서버/자료변경없고문서diffcheck/검토로검증·Flutter시험반복없음. feature/scoped-account-cache/cc6a0b0·기존변경보존·미커밋/미push/dev미반영·브랜치유지.


## 2026-10-16 — 인증 유지 중 재인증 제외·검색/복구 UX

사용자최신정책과100/101번째삭제재등록/direct보류점검을대조하고102번째Backend요청을게시했다. owned는회색이름-인증됨/선택불가로남기며ownership_lost과거verified는차단하지않는다. selection의load·시작전fresh등록/version확인과캐릭터검색의현재owned전체저장목록이름대조를추가해알려진인증대상은POST0으로알린다. 실패/로그아웃late는새시작을허용하지않는다. 새서버wire없이표시용ALREADY_VERIFIED를사용한다. 정상pending조회버튼을숨기고인증결과재확인/원명령재시도, 등록결과재확인/대표재조회로버튼목적을명시했다. 기존불변key/body·replay후GET·제한/세션·성공복귀는유지한다.

검증: 최종관련56PASS·lib/test분석0·format/diffcheck. 신규5경계는owned행/검색POST0·lost후보·소유변경차단/선택무효화·검색logoutlate·정상조회숨김/실패시복구다. 초기신규시험의FormField.items접근은내부DropdownButton검사로수정, 분석info4건중괄호수정후최종통과. 로그 .dart_tool/auth-no-repeat-tests-final.log / auth-no-repeat-analyze-final.log. 한정된selection/화면·표시변경으로Router/DI/schema/서버DTO불변, 전체1579시험반복없음.

새로가능: 현재인증목록을다시선택하지않고검색중알려진본인원정대안내. 보존확인: 기존인증/복구/성공복귀회귀. 미확인: 새UI기기/미관찰이름·동시변경의서버차단, 삭제재등록연결공백. 이번103번째 https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6217851176 에선행결과/서버미완료를회신하고102번째/결과본문과순번검증했다. feature/scoped-account-cache/cc6a0b0·기존변경보존·미커밋/미push/dev미반영·브랜치유지. 서버/DB/키/자료/flag/배포·기기조작/Issue종료변경없음.


## 2026-10-16 — 서버 시각 표시 소수점 제거

사용자 요청으로 서버 등록/조회·전투력 확인·대표 변경 가능·회원키 변경·역할요약 확인/미리보기 유효시각의 raw DateTime 표시를 초 단위로 통일했다. 공통 localDateTimeToSeconds를 추가하고 기존 scopedTime/serverRegistrationTimeLabel도 동일함수에 위임했다. 날짜/기기현지시각은 유지하며 서버/저장/전송의 UTC/정밀도·계산은 변경하지 않는다. 앞으로도 소수점초를 사용자에게 노출하지 않는 원칙을 ai_rules에 기록했다. 새로가능: 과한 소수점 없는 시각표시. 보존확인: 날짜/현지시간·기존 초단위표시/서버DTO/시간판정 불변. 미확인: 새기기화면표시. 변경7파일정적분석0·format/diffcheck/소스검토, 표시만변경해 기능/전체시험반복없음. 로그 .dart_tool/time-seconds-analyze.log. feature/scoped-account-cache 유지·기존변경보존·미커밋/미push/dev미반영·브랜치유지, 서버/자료/DB/키/flag변경없음.
