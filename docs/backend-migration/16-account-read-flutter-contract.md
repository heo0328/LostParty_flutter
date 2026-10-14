# Flutter 회원별 계정 조회 연결

2026-10-14. 작업 feature/account-backend-read. 사용자 승인된 첫 읽기 그룹. 원본 [계약 snapshot](contracts/issue3-254cb5d.openapi.json), Backend 구현254cb5de125ab1bcb2aa084e091eae976e9a078a/인계tip406004eea6045757e24e5c75e3d3418d28830d18. 원본 SHA256 f3873551aa6dd3912b6c855ef2a63f51593eaec028181b9d2a5cee7d08939993. 원격 dev는auth만이어도 고정 작업브랜치 계약을 소비한다.

## 실제 연결

BackendApp의 Dio/AuthSessionController → AuthAccountReadSession → DioBackendAccountReadApi → ServerAccountReadRepository → ServerAccountReadViewModel → MyAccountPage의 서버 등록 영역 및 /account/server/:registrationId 읽기화면. 로컬 AccountRepository/Drift와 정수PK를 재사용하지 않고 별도 UUID 응답모델로 구분한다.

- GET /v1/me/game-accounts와 /v1/me/game-accounts/{registration_id}/characters만 호출한다. 원정대 인증 pending·등록/refresh/설정/활동쓰기 후속. 내계정의 기존 로컬 기능은 계속 이용 가능하다.
- Guest는private 요청없이로그인안내. 로그인/복원완료시등록조회, 최초회원빈목록과로컬캐릭터동시정상. 서버자료는메모리only, 로그인만으로로컬자료를자동등록/인증/삭제하지않는다.
- 회원·세션generation을모든요청/page묶음에확인한다. 로그인/로그아웃/같은회원재로그인·상태변경에서private내용과늦은응답을분리한다. access갱신은기존single-flight재사용. GET ACCESS_EXPIRED401만refresh후1회재전송,다른401/ACCOUNT_DISABLED403은현재세대세션종료,업무OWNERSHIP_REQUIRED403은인증유지.
- strict JSON필드/타입·UUID·UTC시각·상태를고정계약으로읽는다. 숫자문자열 item_level/combat_power는nullable 문자열유지. missing power를0으로표시하지않고power_stale/fetched시각상태를보존한다.
- cursor상한/반복·빈nonterminal·중복등록/캐릭터·전체상한등록20/캐릭터200을검증한다. 한page실패시부분성공을내보내지않는다. 캐릭터전체page의roster/settings/ownership 세값및전체settings내용이같아야완료snapshot을표시한다. 불일치는CURSOR_STALE로재조회안내,자동합병/쓰기없음.
- configuration_state와ownership_status를분리한다. 미인증 preview와confirmed/suspect/missing·eligible/refresh필요를표시한다. 활동/대표는조회된기록만표시하고자격/저장을생성하지않는다. ineligible_character_ids는실제계약의ID목록이며원인별detail DTO는없으므로이유를지어내지않는다.
- raw transport/서버message/token은출력하지않고안전한code기반안내/request_id/Retry-After만전달한다. Dio redirect금지, 새 origin에서는새session store/서비스인스턴스를사용한다.

## 기반·Git 구분

미커밋원본docs와Firebase제거worktree를보존하기위해별도worktree를만들고같은dev a52492f 기준검증된제거결과를선행snapshot으로복제했다. [기반목록/hash](../project/ACCOUNT_READ_PREREQUISITE.json)으로두구간diff를구분한다. 원래docs·실험/백업·제거worktree파일은이번구간에서수정하지않았다. 임의commit/dev통합/push없음.

## 자동·기기 검증

test/features/account/backend_read: guest무요청,ACCESS_EXPIRED1회갱신/다른401·업무403분리,실제AuthController에같은회원새세대/credential삭제검증,전체settings/세revision변경·부분실패/중복/상한/malformed거절,logout/회원전환늦은응답폐기. 기존Auth테스트와전체회귀를함께확인한다. 실Provider/권한/경쟁/rollback은Backend114pytest보고와구분하며Flutterfake를live검증으로보고하지않는다.

사용자 확인은 새APK에서①비로그인로컬캐릭터유지·서버영역로그인안내②Google로그인뒤서버등록목록/최초빈목록과로컬자료동시표시③목록있을시등록캐릭터조회·읽기상태④로그아웃뒤서버내용숨김·로컬유지⑤로그인유지재실행복원이다. 등록이없다면③은첫쓰기구간인수까지미확인으로분리한다. APIkey/증거없이live인증성공을기대하지않는다. 설치/기기조작은사용자가직접한다.

## 기본 실행 경로 복구

2026-10-14 사용자화면의영역부재를기본source/APK와별도조회APK비교로확인하고검증된동일source를D:/dev/projects/lost_party_flutter에이식했다. 현재feature/account-backend-read는기본경로,원본조회worktree는detached로파일보존. 위별도worktree문구는구현당시이력이며기본경로현재상태는NEXT_WORK/DEV_LOG가최신기준이다. 기기APK를직접조작하지않았다.

## 사용자 인수 결과

2026-10-14 기본 경로 최신 빌드에서 사용자 1·2·4 통과. 로그인 후 서버 빈 등록 안내, 로그아웃 후 로그인 필요 안내, 로컬 화면 보존을 확인했다. 서버 등록이 없어 3번 실제 등록 캐릭터 화면은 등록 관리 그룹 인수로 넘긴다. Backend 등록 API는 존재하며 현재 Flutter 쓰기 UI가 미연결이다. 재실행·빌드 편집·실장비 인증까지 이번 보고의 통과 범위를 확대하지 않는다. Git 통합 상태는 NEXT_WORK/AI_CONTEXT를 따른다.
