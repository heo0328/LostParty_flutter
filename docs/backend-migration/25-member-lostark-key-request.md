# 회원별 Lost Ark API 키 — Flutter 연결 계약

2026-10-15. 사용자 승인: 모바일에서 한 번 등록해 서버와 현재 기기에 저장하고, 모바일에서 가능한 조회는 직접 호출한다. 재설치·다른 기기 로그인은 본인 서버 키를 가져와 보안 저장소에 저장한다. Firebase/테스터 자료이관·기존 기기 키 자동 업로드·공용 키 자동 배정은 없다.

## 소비 계약과 협업 근거

Backend `9e1a255b87b430bca314e8f718fb4176bfe322c8`, feat/member-settings push·dev/main 미병합. [구현/로컬0006·API 인계6172992882](https://github.com/heo0328/lostparty-backend/issues/7#issuecomment-6172992882). 공용 JWT 설정/실행 제거와 독립 암호화 설정은 Backend 보고로 확인했다. Flutter에서 서버 내부/실키를 독립 시험한 것으로 확대하지 않는다.

[고정 OpenAPI](contracts/issue7-9e1a255.openapi.json), 저장 파일 SHA256 `5217dcedeca895c96ed014b8df13b80be291165871a013f2cbaaf3f16030aded`. API/DDL 원본은 Backend 소유다. [초기 요구Issue7](https://github.com/heo0328/lostparty-backend/issues/7),[초기계약수용6172158382](https://github.com/heo0328/lostparty-backend/issues/7#issuecomment-6172158382),[UX/제한/복원요청6172594991](https://github.com/heo0328/lostparty-backend/issues/7#issuecomment-6172594991),[추가계약수용6172746952](https://github.com/heo0328/lostparty-backend/issues/7#issuecomment-6172746952),[인계확인6173015145](https://github.com/heo0328/lostparty-backend/issues/7#issuecomment-6173015145). 이전 원문 다운로드 없음/서버·기기 별도 관리 추천은 사용자 최신 방향으로 대체했다.

## API·상태

| 요청 | 입력·성공 |
|---|---|
| GET /v1/me/lostark-api-key | metadata configured/version/updated_at. 미등록 초기false/1/null |
| PUT 같은 경로 | token/expected_version, UUIDv4 Idempotency-Key →200 metadata |
| DELETE 같은 경로 | query expected_version·body없음, UUIDv4 key →200 metadata |
| POST 같은 경로/restore | expected_version 한필드·멱등키없음 → token/version |

앱 Bearer로 본인 회원/세션 확인, no-store. PUT는 strict compact JWT형식/16KiB·공백/접두사 거절과 암호화 저장만 수행하며 서명/실제 provider 유효성 검증이 아니다. 앱은 `API 키를 등록했습니다.`로 안내한다. 기존 서버 키 원문은 입력창에 표시하지 않는다.

metadata·restore는 정확한 필드/엄격 정수/버전 일치를 검사한다. 복원은 실제 Lost Ark 호출이나 키 버전 변경을 하지 않는다. LOSTARK_KEY_NOT_CONFIGURED/REJECTED/CHANGED/UNAVAILABLE는 앱 자체401과 구분한다. 키미등록/거절/변경은 키 관리 진입을 제공하고 앱 로그아웃으로 처리하지 않는다.

## Flutter 실행·저장 흐름

MemberLostArkKey는 현재 회원 키의 단일 상태/기기 토큰 소스다. BackendApp의 기존 설정 /settings/api-token에서 MemberKeyPage를 연결한다. 내 계정 캐릭터 중심 배치는 유지하며 앱 시작에 등록 알럿을 강제하지 않는다.

1. 로그인/자동로그인: metadata→configured면restore→현재 회원/서버별 FlutterSecureStorage에 token/version 저장. 회원/서버/세션 세대가 바뀐 늦은 복원은 무시한다. 시작 진행 복원은 직접 API 키 read가 기다린다.
2. 명시 등록/교체: PUT→현재metadataGET→현재버전restore→기기 저장. 과거 멱등 성공을 현재 키로 오인하지 않는다. 저장 후 화면 유지·입력 정리, 별도 외부 검증/원래 기능 자동 재실행 없음.
3. 명시 삭제: 확인 알럿→DELETE→현재metadata/필요복원으로 기기 상태 동기화. 기존 캐릭터/원정대/역할Snapshot은 삭제하지 않는다.
4. 서버 성공·기기 저장 실패는 서버 성공 안내와 기기 저장 오류를 따로 표시한다. `키 다시 불러오기`는 restore로 복구하며 PUT를 다시 만들지 않는다.
5. 응답 유실은 화면 메모리의 같은 UUIDv4/body/version으로 명시 재시도. REQUEST_IN_PROGRESS 대기 준수, 24시간 기한·충돌/만료 제외. 버전 충돌은 pending을 해제하고 현재 키 확인 후 새 명시 결정. 화면 종료/회원 변경에 미완료 입력을 정리하며 원문 대기 명령을 디스크에 저장하지 않는다.
6. 페이지 진입/앱 foreground 복귀에도 metadata/restore로 현재 상태를 확인한다. 조회 실패는 알 수 없음이며 이전 버전으로 새 키 저장을 진행하지 않는다. 전 기기 실시간 동기화는 보장하지 않는다.
7. 로그아웃/회원·세션 전환은 메모리/대기 요청 정리 및 이전 회원 기기 키 삭제를 직렬화한다. 서버 키는 유지한다. 회원 기기 키를 guest 저장소에 복사하지 않는다. guest의 기존 직접 조회·기기용 등록은 별도 게스트 저장소/진입점으로 유지한다.

일반 직접 조회는 복원된 메모리 키를 사용하며 매 Lost Ark 요청마다 Backend를 경유하지 않는다. 로컬 HTTP 결과는 회원/세션/키버전이 바뀌면 반환하지 않는다. 키를 일반 설정/로그/오류/Issue에 남기지 않는다. 회원별 키 소유권과 로컬 캐릭터 DB의 기존 기기 공용 저장은 다른 책임이며 이번에 DB 복원 범위를 확대하지 않는다.

## 호출 제한·재시도

[공식 가이드](https://developer-lostark.game.onstove.com/usage-guide): client당100/min,429 및 X-RateLimit-Limit/Remaining/Reset. Reset은 UNIX epoch초다. Backend의 자체token80/min 예산과 provider 한도를 구분한다.

- 직접 호출에서429 또는 성공 Remaining0을 관찰하면 유효한 미래300초 이내 Reset을 사용한다. 누락/비정상/과거/ms모양/과도미래는60초 fallback. 현재200 응답은 성공 유지, 추가 호출만 차단한다.
- ApiCooldown은 관찰 deadline을 max로 유지한다. 같은 키는 대기 유지, 다른 키/회원은 분리한다. 로컬 차단만으로 대기를 계속 연장하지 않으며 기한 종료 후 명시 재시도한다. 자동sleep/retry나 전체기기 호출량 동기화 서비스는 없다.
- 단건 오류의 error.retry_after_seconds/retry_at은 optional nullable, 제한일 때 두값. HTTP429 RATE_LIMITED/HTTP503 UPSTREAM_RATE_LIMITED·Retry-After를 처리한다. 앱은 upstream 대기를 직접/서버 외부 호출에 공유한다.
- PowerResult에는 required nullable 두 시간 필드를 추가해 strict DTO를 새 계약으로 갱신했다. 제한 failed/deferred는 두값·그외null쌍. 부분결과에서도 deadline을 안내·보류한다. 과거 멱등 replay의 시각이 지났으면 새 명시 명령으로 진행한다. 이미 저장된 숫자/시각과 GET은 유지한다.
- 내 계정 조회·캐릭터 상세 갱신·서버 등록/전투력 영역에 남은 초와 키 관리 안내를 연결했다. 제한을 키 교체/Google 로그아웃으로 처리하지 않는다. 다른 기기 추가 사용으로 재시도 시 다시 제한될 수 있다.

## 검증·현재 상태

feature/member-lostark-key에서 Flutter 구현·자동 검증과 현재 기능 사용자 정상 보고를 마쳤다. 사용자 지시로 이 완료 단위를 dev에 통합·push하며 적용 SHA는 Git 이력/Issue7 최종 인계에서 추적한다. 기존 문서 변경/사용자 Rules·tools 보존. 전체1246테스트 통과 후 metadata 재조회 실패의 이전버전 조작 방지 국소 보완·관련12개통과,최종lib/test분석0. 표적58개도 통과했고 실패mock의 JSON content-type 누락을 고친 후 최종 전체를 수행했다. 로그는 .dart_tool/member-key-final-tests.log/member-key-metadata-final.log/member-key-final-analyze.log. 이후 문구 정리의 관련46개 통과·최종 분석0/debugAPK15.5초 성공은 DEV_LOG에 기록했다.

회귀보존:Google세션/설정·원정대CRUD/이름/전투력·선호역할Snapshot·guest로컬조회. 신규 mock 경계:형식/버전·응답유실동일명령·로그아웃중복원/저장·기기저장부분실패·제한epoch/fallback/Remaining0·늦은응답/새DTO. 사용자는 키 등록/삭제와 캐릭터 검색 등 현재 구현 구간 정상 동작을 보고했고 [6173934017](https://github.com/heo0328/lostparty-backend/issues/7#issuecomment-6173934017)에회신했다. 내부키저장위치구분은사용자시험으로요구하지않는다. 재설치/다른기기·provider헤더/한도상세는별도미확인이다.

아래는 완료 구간의 수동 안내 이력이며 현재 정상 흐름을 다시 대기시키지 않는다. 당시 안내는 새 빌드에서①로그인→설정의API키직접등록→기기저장표시→내계정직접조회/서버원정대미리보기②로그아웃·재로그인/재실행시재입력없이복원·조회③명시키교체/삭제후저장캐릭터유지·새조회차단·재등록 복구. 한도는mock으로검증하며 실제100회소진을요구하지않는다. 재설치/별도디바이스는가능한경우추가인수이며일반재로그인통과를그인수로확대하지않는다.

전체빌드자동갱신/역할저장API·장비증거보류해제·DB고아정리·Firebase자료이관·운영배포/Issue종료는이번범위가아니다.
