# 내 계정 Backend 대응 Flutter 작업 계획

> 2026-10-16 현황: S1~S3/A1/A2/B/C 연결·자동검증 완료(전체1524PASS). 직접 다음은 실제 서버 준비 확인→ON 빌드 수동 인수다. 현재 상태는 아래 후속 대장과 [NEXT_WORK](../project/NEXT_WORK.md)를 따른다. 초기 API 미인계·대표5분 cooldown·자동 갱신 미연결 문구는 당시 계획이며 최신 계약23/27/30을 대체하지 않는다.

2026-10-14. 사용자 지시: Backend가 합의한 #3 작업을 진행·인계하면 그 계약에 대응하는 로컬 Flutter 작업을 진행한다. 이번 기록은 후속 구현 순서를 확정하며 임의 DTO/API 구현을 시작하지 않는다.

## 기준과 현 상태

- [Backend #3](https://github.com/heo0328/lostparty-backend/issues/3), [추가 회신](https://github.com/heo0328/lostparty-backend/issues/3#issuecomment-6159847616), [서버 작업 지시서](13-my-account-backend-phase1-request.md).
- 조회 시 Backend 원격 dev OpenAPI는 기존 인증6API와 health만 제공한다. #3의 확정 REST/DTO/오류/구현 SHA는 미인계다. 정책 합의와 실제 사용 가능한 서버 계약을 구분한다.
- Flutter 원래 checkout은 docs/my-account-backend-phase1, 문서·별도 실험 미커밋이다. Firebase 제거는 별도 refactor/firebase-removal 작업 트리에서 구현/자동 검증 완료·미커밋/dev 미반영이다. 신규 APK 로그인·재실행·로그아웃·로컬 캐릭터 표시는 사용자 통과 확인. 새 기능은 제거 결과를 기반으로 하며 구 Firebase 코드를 다시 연결하지 않는다.

## 단계와 첫 승인 작업 그룹

| 구간 | 목적 | 완료 기준 |
|---|---|---|
| 1. 계약 인수·읽기 연결 | 회원별 등록 목록·캐릭터·전체 설정 조회, 상태 표시 | 원본 OpenAPI/구현 SHA 고정, Repository/DI 연결, 회원 전환/부분 페이지/장애 경계 보호 |
| 2. 등록 관리 | 검색 preview·본/부계정 등록·label/본계정 수정·등록 제거·refresh | 멱등 key/expected version, 응답 유실 복구, 로컬 자료 보존 |
| 3. 서버 장비 인증 | challenge 시작/상태/confirm/cancel, TTL/불일치/인증·소유 상태 | 서버 결과만 인증 기준, 종료/유실/취소·이전 보류 조건 소비 |
| 4. 활동·대표 설정 | 최종 전체 선택과 대표 원자 저장, cooldown·재구성 | 세 expected 값, 전체 페이지 일관성, 저장 실패·409 보존 |

한 번에 진행할 첫 구현 그룹은 1번이다. 나머지 그룹은 순서를 기록하되 독립 구현/검증 단위로 진행한다. Backend 모든 업무 기능의 완성을 기다릴 필요는 없으며, 첫 그룹의 안정된 조회 계약과 구현 SHA를 먼저 인계하면 해당 그룹부터 연결할 수 있다.

## 첫 그룹 구현 설계

1. 서버가 소유한 정확한 경로·DTO·nullable/enum·UTC 날짜·pagination·에러/request_id/Retry-After를 원본 계약으로 고정한다. 로컬 자료형이나 폐기 Firestore map을 새 서버 wire schema로 사용하지 않는다.
2. 기존 AuthSessionController의 accessToken/refresh/로그아웃 정책을 재사용하는 private HTTP 경계를 연결한다. 업무403 OWNERSHIP_REQUIRED를 세션 만료로 오인해 로그아웃하지 않는다. 401의 갱신/재전송 가능 코드·횟수는 실제 계약에 맞추고, 쓰기 동작의 무조건 retry 정책을 만들지 않는다.
3. 회원별 서버 등록 Repository와 응답 모델을 로컬 AccountRepository와 분리한다. 로컬 정수 PK/과거 server ID와 registration/canonical/character UUID를 구분한다. 첫 단계에서는 local DB schema/자료를 일괄 갱신하거나 서버 소유 매핑을 추론하지 않는다.
4. BackendApp의 실제 Router/DI에서 신규 Repository를 주입한다. 비로그인 로컬 계정·캐릭터·빌드 화면을 유지하고 private GET을 보내지 않는다. 로그인 후 서버 등록 영역을 조회한다. 최초 서버 빈 목록과 기존 로컬 캐릭터 표시는 동시에 정상이며 로컬 자료를 지우지 않는다.
5. 등록별 캐릭터와 페이지 독립 settings를 읽는다. 전체 페이지 수집 후 roster_revision/settings_version/ownership_revision이 모두 같고 selection_complete=true일 때만 관리 draft를 만들 수 있다. 중간 페이지 실패/순환 cursor/중복·초과·잘못된 UUID/응답 형식은 정상 빈 목록으로 바꾸지 않는다. CURSOR_STALE은 혼합 상태를 폐기하고 명시 재조회로 처리한다.
6. unconfigured/ownership_lost/needs_reconfiguration 및 confirmed/suspect/missing을 분리해 표시한다. 타인 설정을 사용하지 않으며 suspect/missing은 새 활동 자격을 만들지 않는다. 첫 그룹에서는 조회 상태만 반영하고 서버 설정을 자동 저장하지 않는다.
7. 서버 private 조회 상태는 Base URL origin·회원·세션 세대별로 격리한다. 로그아웃/계정 전환/재로그인 때 private 상태를 지우고 이전 요청의 늦은 응답을 무시한다. 같은 회원 ID로 재로그인해도 이전 세션 응답을 현재 세션으로 인정하지 않는다. 로컬 캐릭터/빌드/API 키는 유지한다.

## 다음 그룹에서 지킬 합의

- 쓰기는 actor+operation scope의 UUIDv4 Idempotency-Key와 고정 payload를 사용한다. timeout/409을 새 key의 자동 쓰기로 대체하지 않는다. 성공 재응답은 결과 복구이며 현재 상태는 GET으로 확인한다.
- 활동 저장은 계정별 전체 집합·대표·expected_settings_version/expected_ownership_revision/expected_roster_revision을 한 요청으로 전송한다. owned_character_ids와 verified 플래그를 서버 권한 증거로 보내지 않는다.
- 대표 최초 seed는 cooldown 없음, 실제 변경5분·누락 대표 복구 우회 없음. 오류 시 전체 선택·대표·서버 version을 성공 상태로 확정하지 않는다.
- provider 근거 확보 전 live 감소 자동 missing 확정/불완전 roster 기반 소유권 이전은 보류한다. 서버 key 준비와 사용자 인게임 장비 조작은 Backend/사용자의 후속 실제 인수다.

## 회귀 보호·검증·제외

보호: Google 로그인/유지 선택별 재실행/로그아웃, 비로그인 로컬 계정·캐릭터·빌드/키, debug URL·로딩 배경, origin별 저장. 서버 빈/장애/재구성 상태를 로컬 삭제나 guest 회원 생성으로 처리하지 않는다.

자동 검증은 guest 무요청, 계정/세션 전환의 늦은 응답, pagination revision 변경·실패·불완전 설정, private 오류 분류에 집중한다. Router/DI 변경 후 최종 전체 flutter test/analyze 여부를 영향에 맞춰 판단한다. 이후 사용자가 새 API와 로컬 기능을 기기에서 확인한다. 문서 준비만 수행한 현재는 Flutter 검증을 반복하지 않는다.

제외: 기존 데이터 이관/삭제, 원격 Google/Firebase 설정 삭제, 모집/파티/그룹/주간/운영 UI, 자동 소유권 병합, Backend DB/API 구현·배포, 사용자 기기 설치/조작. commit/dev 통합/push는 별도 Git 요청 범위에 따라 수행한다.

## 인계·인수 갱신 (2026-10-14)

Backend 구현254cb5d/인계406004e의 작업브랜치 게시와 원본 계약을 확인하고 Flutter 첫 조회 그룹을 실제 연결했다. 고정 계약/현재 흐름은 [조회 계약16](16-account-read-flutter-contract.md), 다음 등록 관리는 NEXT_WORK를 따른다. 사용자1·2·4 통과, 3번은 등록 자료 생성 후 확인한다. 위 계약 미인계/미연결 문구는 초기 계획·준비 당시 기록이며 현재 대기 사유가 아니다.

<a id="flutter-follow-up-20261014"></a>
## Issue 정리와 Flutter 주도 후속 대장 (2026-10-14)

사용자 지시: 완료된 Backend 협업 요청을 연계 기능 때문에 계속 열어 두지 않는다. 후속 설계·구현·미확인 인수는 Flutter가 주관해 이 대장에서 관리하고, 실제 Backend 변경이 필요해질 때 해당 작업의 별도 Issue로 요청한다. 아래는 대기 과제이며 지금 구현을 시작하는 승인이 아니다. 이전 문단의 준비 당시 미인계/미통합/첫 조회 대기 문구는 현재 상태가 아니다.

### 기존 요청의 판정

| Issue | 확인된 완료 근거 | 정리 |
|---|---|---|
| #1 협업 연결 | 이미 CLOSED | 유지 |
| #2 Google 인증 | 이미 CLOSED, 계약519c609·실제 로그인/세션 인계 | 유지, 추가 정책/운영 인수는 AUTH-01 |
| #3 계정 Backend 기반 | Backend254cb5d·보완db0f3ae·dev e807a6f, 자동114개/별도후속10개. Flutter 조회6f97190·등록98ebbff 및 사용자 등록/삭제/재로그인 확인. [서버 완료](https://github.com/heo0328/lostparty-backend/issues/3#issuecomment-6162460687) | 서버 기반 요청을 종료. 장비·활동 Flutter 연결/실provider 인수가 끝났다는 뜻이 아니며 ACCOUNT-01~03으로 명시 이관 |
| #4 등록관리/빈 이름 | Backend d3cb697/dev a6d25aa, Flutter5fe636e/dev266a7e2·push, 사용자 이름4흐름/등록·삭제·재로그인·갱신 확인. [양측 인계 확인](https://github.com/heo0328/lostparty-backend/issues/4#issuecomment-6166402144) | 요청 완료로 종료. 삭제 후 로컬 보존의 미확인 실인수는 QA-01로 분리 |
| #5 수동 전투력 | Backend39188d5/dev8775153, Flutter6beb55e/devccc6b23·push, 전체1204/후속국소70·분석0 및 사용자3흐름. [양측 인계 확인](https://github.com/heo0328/lostparty-backend/issues/5#issuecomment-6168169896) | 요청 완료로 종료. 자동 빌드 갱신은 POWER-01, 설정 API는 #6 |
| #6 회원 나이스단 설정 | Backend79255f0/Flutter2e0764f·dev5cee964/push·사용자3흐름완료, [최종회신6170736672](https://github.com/heo0328/lostparty-backend/issues/6#issuecomment-6170736672) | CLOSED. 자동빌드/전체환경복원은POWER-01/RESTORE-01 |

#3은 원문 전체 제품 흐름이 끝난 것으로 판정하지 않는다. 사용자 지시에 따라 완료된 서버 기반 요청을 종료하고 아직 미구현·미인수인 연결 범위를 별도 Flutter 과제로 분리한 것이다. 과거 문서/댓글의 #3/#4/#5 OPEN 유지 문구는 당시 상태 이력이다.

### 미완료 과제와 다음 행동

모든 항목의 전체 진행·계약 분해·사용자 UX 협의·결과 콜백 주관은 Flutter다. Backend는 아래 명시한 서버 작업이 실제 필요해질 때 협업한다. 기존 Firebase/테스터 자료 이관은 없다.

| ID / 출처 | 남은 작업·상태 | 다음 행동과 완료 조건 |
|---|---|---|
| ACCOUNT-01 / #3 | 등록/인증 대상선택·상태/복구·Router 연결 완료. 실제 장비인증1회/Backend98번째 VERIFIED·소유연결 확인, 최신 전체1579PASS·분석0 | 99번째 성공후이전페이지복귀·간결화 및 기본정렬의 새빌드 실기기 확인만 남음. 완료한 등록/인증을 미구현 단계로 되돌리지 않음. [문서28](28-verification-client-preparation.md) |
| ACCOUNT-02 / #3 | 기본 장비인증/현재소유 신규등록과 본인재인증 구현, 실제 신규 인증1회 성공. 타소유/미연결은 장비확인후에도 ACCOUNT_BINDING_EVIDENCE_PENDING 유지 | 타소유 자동이전/24시간 수동분쟁·live퇴역/claim해제는 별도 미구현. 앱종료로 원명령 key/body가 소실된 인증 자동회수도 미제공. 기본등록/인증 완료를 막는 누락과 구분하며 해당 후속 설계 때 진행 |
| ACCOUNT-03 / #3 | 기존 캐릭터 관리 화면의 현재서버/canonical 활동+대표 원자저장·초기대표/1700/표시·왕관 연결 완료. 별도 E2화면 신설은 철회 | 활동/대표·개인순서 저장·자동갱신의 실사용 확인은 다음 기능 구간이며 기본인증 성공만으로 통과 처리하지 않음. 기존 관리 화면을 재사용하고 중복 화면/API 구현을 요청하지 않음 |
| QA-01 / #4 | 서버 등록 제거 후 기존 로컬 캐릭터·역할빌드 유지의 별도 실기기 확인은 미확인. 결함이 재현된 상태는 아님 | 로컬 보존 코드는 유지. 다음 해당 화면 변경 인수나 릴리즈 점검에 한 번 묶어 확인하고 결과 기록. 등록/이름/재로그인 성공시험을 전부 반복하거나 기존 Issue 종료를 막지 않음 |
| POWER-01 / #5 | B 전체 활성 상세1회/OFF 제외 실행·C 실제 앱 수명/목록/진행·재시도 연결 완료. 최종 전체1524PASS. 기본 기능 flag OFF | [NEXT_WORK](../project/NEXT_WORK.md) 기준 실제 API·DB 준비 확인 후 ON 빌드 수동 인수. 자동 검증을 실provider 통과로 확대하지 않음 |
| RESTORE-01 / #3/#4/#5/#6 | 서버 최소 역할요약/오류/시각·선호/표시/count, 로컬 상세와 영속 명령의 A1/A2·C 복원 연결 완료. P2 원본7027f0b 소비·회원 주목록/구 기기 자료 분리 | POWER-01 인수와 함께 새 기기/재설치 복원·키 없음/OFF 요약/원본 없음·서버 저장 대기를 확인. 구 자료 자동 이전/전체 파티·주간 환경복원은 포함하지 않음. [저장 계약30](30-scoped-storage-write-contract.md) |
| AUTH-01 / 이미 종료한 #2 | 탈퇴/재가입·약관 운영 정책, Android 실기기/release OAuth·HTTPS/운영 인수는 후속. 기본 로그인·유지선택별 재실행·로그아웃 사용자 통과와 구분 | 해당 제품/릴리즈 구간에서 정책·실제 기기/네트워크 장애 인수 범위를 설계하고 필요한 Backend 변경만 별도 요청. 완료된 기본 로그인 인수를 다시 요구하지 않음 |

현재 #1~#7은 종료, #8은 OPEN이다. 최신 등록/인증은 [99번째 Flutter 결과](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6217416791)까지 인계됐고 POWER-01/RESTORE-01은 코드·자동검증 완료/실환경 인수 대기다. 나머지는 별도 승인 그룹 후보/릴리즈 점검이다. 새 Backend 요청은 과제별 실제 서버 변경·계약 질문이 확정될 때 만들고, 종료한 Issue는 기존 근거 링크로만 사용한다. 종료는 미완료 기능을 완료로 바꾸거나 보류 정책을 없애는 조치가 아니다.

2026-10-14 전체DB점검의추가후속 DB-03: 격리메모리DB에서FK0·missing캐릭터삭제뒤build/weekly고아행을재현했다. Flutter담당별도최소정합성수정그룹으로영향/삭제경로확인후수정하며이번조사에서코드는변경하지않았다. 상세근거/전체과제는[보고서24](24-database-design-review.md)를따른다.
