# 내 계정 Backend #3 테스트 준비

2026-10-14. 이번 범위: Backend 결과/테스트 범위 확인, 읽기 smoke 확인, Flutter 연결 후 검증 절차 준비. 기능 구현·인증정보 입력·업무 쓰기·기기 설치는 수행하지 않는다.

## 인계 상태와 실제 확인

근거: [Backend 구현·검증 결과](https://github.com/heo0328/lostparty-backend/issues/3#issuecomment-6160605157).

- Backend 보고: 업무12API, additive0002 신규11테이블, 로컬 OpenAPI16경로/19operation. 격리 PostgreSQL17 테스트114개 통과(기존auth46+장비/transport37+업무31). 이는 Backend 보고이며 Flutter에서 pytest를 재실행한 결과가 아니다.
- Backend는 개발 DB에 additive migration과 로컬 API 갱신을 수행했다고 보고한다. 원격 신규 계약/구현 SHA는 없음, 미커밋·미push. 로컬 원본 openapi/openapi.yaml 및 docs/ISSUE_3_DEVELOPMENT.md를 커밋된 원격 상태로 인계해야 재현 가능한 계약 소비 기준이 된다.
- 직접 확인: Windows http://127.0.0.1:8000/health →200, Bearer 없이 GET /v1/me/game-accounts →401. /openapi.json →404라 실행 서버에서 계약 본문을 확보하지 못했다. 404를 업무 기능 미구현 증거로 해석하지 않는다.
- 원격 dev OpenAPI blob9042931bb061afb98f0a16de1481107d8db7c7fe는 기존auth6API/health만 포함한다. #2 명세로 #3 DTO를 구현/검증하지 않는다. 댓글만으로 실제 response JSON 세부 형식을 추측하지 않는다.
- 현재 Flutter BackendApp은 showServerOwnership=false와 원정대 인증 pending이다. 현재 APK의 로그인 성공/로컬 캐릭터 표시는 신규 업무 API 인수 결과가 아니다.
- 소스 인계/운영 문서의 서버 key 준비 방법·오류/fixture·sanitized 예제를 확보한 후 Flutter 연결 계획14의 첫 그룹부터 진행한다. Backend checkout/DB/비밀 설정은 이번에 변경하지 않았다.

## 공통 준비물

1. #3 구현 커밋 SHA와 원본 OpenAPI/개발 문서·migration·검증 결과. 각 빌드/테스트 기록에 Backend SHA, 계약 hash, Flutter branch/commit 또는 dirty 상태를 함께 기록한다.
2. 현재 Android debug Base URL은 http://10.0.2.2:8000. 호스트의 localhost 접속 성공은 에뮬레이터 접속 성공과 구분한다. 실디바이스는 호스트 LAN 주소와 같은 네트워크/접속 허용이 필요하며 사용자가 직접 확인한다.
3. 회원별 registered account와 로컬 캐릭터 자료를 분리한다. 과거 Firebase/테스터 자료 import·local DB 초기화 없음. 최초 서버 빈 목록은 정상이다.
4. 실제 장비 비교/key/upstream은 Backend 안전한 로컬 설정과 사용자 인게임 조작 준비가 필요하다. 값·Bearer·refresh·Google proof·장비 baseline을 Issue/로그/스크린샷에 포함하지 않는다.
5. 모의 테스트의 사용자/등록/캐릭터 자료는 Flutter adapter fake 및 Backend 격리 fixture만 사용한다. 개발 DB에 성공용 소유권/권한을 임의 삽입하거나 공개 mock/증거 우회를 추가하지 않는다.

## 테스트 매트릭스

| 범위 | 준비 방식/책임 | 기대 결과·통과 조건 |
|---|---|---|
| 서버 접속·guest | 읽기 smoke, 이번 수행 | health200·미인증업무401; 원정대/회원 생성 없음 |
| 최초 로그인·빈 등록 | Flutter 조회 연결 후 사용자 | 서버 빈 목록과 기존 로컬 캐릭터가 함께 표시, 로컬 삭제 없음 |
| 회원/세션 격리 | Flutter fake 경계 테스트 | 로그아웃·다른 회원/같은회원 새세션의 늦은 응답 폐기, private 상태 해제·로컬 유지 |
| 전체 페이지·settings | Flutter fake 경계 + Backend fixture | selection_complete, 페이지 독립 전체 선택, roster/settings/ownership 세 값 일치; 중간 실패/중복/초과/순환cursor에서는 저장 불가 |
| CURSOR_STALE·revision409 | fake/격리 fixture | 혼합 draft 폐기·최신 재조회, 자동 덮어쓰기/재제출 없음 |
| preview·등록·수정·제거·refresh | 쓰기 연결 후 사용자/provider | 본계정/상한/version/빈목록/상태와 등록제거 의미 확인, canonical/local build 삭제 없음 |
| 멱등·응답 유실 | Flutter HTTP fake·Backend 기존 DB 경계 | 같은 key/hash 유지·진행중409+Retry-After2·DELETE204 replay; 자동 새key 쓰기 없음·GET으로 현재 결과 확인 |
| malformed/503/429/403 | Flutter HTTP fake·키 없는 실제 요청은 후속 | 실패를 정상 빈 roster로 적용하지 않음, Retry-After 안내, OWNERSHIP_REQUIRED로 Google 세션을 임의 종료하지 않음 |
| 인증 pending/expired/cancel | 연결 후 fake 및 사용자 | source registration/direct_input, confirm/refresh 빈object; TTL후 자동재시작/confirm 없음·최신GET상태 기준 |
| 인증 성공·소유권 이전·rollback | Backend 격리 fixture 보고114 근거, Flutter fake | UI 상태·settings/ownership 구분·이전 owner 자격/늦은저장 거절; 실제 live 성공과 구분 |
| 활동·대표 | 설정 연결 후 fake/격리 fixture | 계정별 전체집합과 세 expected 값·최소1명·대표포함·첫seed예외/이후5분, 오류시 원자보존·다른계정 설정 유지 |
| suspect/복귀·재구성 | fixture/fake | 기록/ID/로컬빌드 보존, 새활동자격 제외, 정상복귀 기존ID·needs_reconfiguration 표시·대표cooldown우회 없음 |
| 로컬 회귀 | 각 연결 구간 최종 APK 사용자 | 비로그인 캐릭터/빌드/키·Google 로그인·재실행·로그아웃·debug URL/배경 유지 |

정상 기기 UI를 자동 UI 테스트로 전부 중복하지 않는다. 자동 검증은 위조하기 어려운 권한·경쟁·rollback은 Backend pytest, Flutter는 경계 오류·늦은 응답·부분 목록·멱등 소비에 집중한다. 소스 없는 현재는 기존114개를 임의 재실행하지 않는다.

## 실제 provider 테스트의 예상 제한

- 서버 key가 없으면 외부조회가 필요한 preview/등록/인증 시작 등은503 UPSTREAM_UNAVAILABLE로 예상된다(Backend 보고). 이번에는 key 설정 여부를 읽거나 이 쓰기를 실행하지 않았다.
- 장비 schema/해제 표현 미실증 상태에서 live 비교가 맞아도 pending+PROVIDER_EVIDENCE_PENDING이며 소유 확정 성공을 기대하지 않는다.
- canonical 감소 roster를 이용한 이전은 ROSTER_EVIDENCE_PENDING. refresh 누락은 suspect, 자동 missing 확정 없음. 이 보류를 우회해 성공으로 처리하지 않는다.
- 실제 장비6부위/1~3해제·API 지연·quota·소유권 이전 최종 인수는 sanitized 실응답 근거와 Backend 보류 정책 보완 후 공동 검증한다. mock 성공을 실제 통과로 보고하지 않는다.

## 실행 순서·결과 기록

1. 커밋된 #3 계약 인수·원본 hash 비교 및 정확한 source/빈body/DELETE query/세 expected 값 확인.
2. Flutter 연결 계획14의 조회 그룹 구현/자동 경계 검증 후 새 APK에서 빈등록·상태·로컬 보존 확인.
3. 등록 관리 → 장비 인증 → 활동/대표 순서로 API 연결과 각 구간 인수. 계약/코드 변경 없는 기존 로그인 수동 결과는 재사용하고 영향을 받는 항목만 재확인한다.
4. 실제key/provider/장비 인수는 별도 조건 충족 후 실행. 백엔드 DB에 fixture를 임의 주입하지 않는다.
5. 보고에는 실제 수행 주체/버전, 요청 method/path, 기대/실제HTTP·안전한 code/request_id, 사용자 재현 순서·키준비 여부(값 없음), 로컬 보존 결과, 미실행 이유를 기록한다. 예상 오류와 결함을 구분한다.

현재 완료: 테스트 범위 검토·읽기smoke·테스트 준비 문서. 미실행: 신규 업무 Flutter 연결/로그인 회원 업무요청/CRUD·장비조작/신규API기기검증. 브랜치 docs/my-account-backend-phase1 미커밋·dev미반영·미push, 기존 Firebase 제거 작업 트리 보존.

## 인계·인수 갱신 (2026-10-14)

Backend 구현254cb5d/인계406004e의 작업브랜치 게시와 원본 계약을 확인하고 Flutter 첫 조회 그룹을 실제 연결했다. 고정 계약/현재 흐름은 [조회 계약16](16-account-read-flutter-contract.md), 다음 등록 관리는 NEXT_WORK를 따른다. 사용자1·2·4 통과, 3번은 등록 자료 생성 후 확인한다. 위 계약 미인계/미연결 문구는 초기 계획·준비 당시 기록이며 현재 대기 사유가 아니다.
