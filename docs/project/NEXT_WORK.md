# NEXT WORK — 구간별 디바이스 인수 / 현재 2구간 가입

## 보완 대기 — 레이드 현황 참가 카드 정보 확장 (2026-10-25 조사만)

사용자 요청: 카드에 내 공대장/공대원(4인은 파티장/파티원), 내 참가 캐릭터명, 레이드 이름/난이도를 표시할 데이터가 있는지 먼저 확인하고 추가작업은 후속 기록한다. **이번 UI/모델/API 수정은 하지 않는다.** 현재 우선대기인 신청자 아이템레벨 보완과는 별개다.

| 항목 | 현재 정상 참가 목록의 근거 | 후속 작업 |
|---|---|---|
| 내 역할 | membership-actions-1 viewer.role, 기본 content.target_role/room.my_target_role=leader·member·none | 추가 API 없이 카드 표시 연결. 4/8인 모집 규모(app_capacity·raid game_party_size)를 확인해 파티장/파티원·공대장/공대원 문구를 정하고 현재 참가자 수로 규모를 추정하지 않음 |
| 내 참가 캐릭터명 | content.assignments에 character_id/round/item/실제T/CM은 있으나 character_name/display는 없음 | 기존 회원별 내계정 자료의 정확 UUID 연결을 재사용할 수 있는지 먼저 확인. 누락·캐시수명·회원/T·여러Assignment/캐릭터 대응까지 안전하지 않으면 목록의 본인 표시 투영 계약 보완을 협의. 카드별 상세GET·다른 캐릭터/공대장 이름으로 대체 금지 |
| 레이드·난이도 | content.room.items/game_items의 raid_id/difficulty_id/game_party_size, 앱 CycleRoomCard.items에 이미 보관 | widget.weekly.catalog(기존 계정 카탈로그)로 이름/난이도명 매핑·묶음이면 항목별 표시. 카드별 API 불필요 |

현재 CycleOwnRoomsPage는 제목과 상태/인원만 표시한다. CycleOwnRow.profile은 content에서 card만 옮기고 assignments/target_role을 별도 표시 모델로 노출하지 않으므로 새 표시 getter/모델 연결이 필요하다. 역할은 profile.viewer에서 직접 알 수 있다. 실행06ea4b21의 membership_readers.legacy_membership 및 memberships는 assignments에 character_id만 넣고 이름을 주지 않는 것을 확인했다. 기록 단건의 record.assignments에는 character_name이 있지만 목록 entry에는 record가 없고, 과거/복구 행 content=null이면 정상 참가 card 데이터도 없다. 기록의 이름이 이미 목록에 있다고 해석하지 않는다.

차후 범위는 우선 정상 ‘참가 중’ 카드 표시다. 신청 중은 아직 역할/좌석이 확정된 참가자가 아니며, 기록·relation_only/복구 content없음은 기존 상태 안내/식별자·읽기전용을 보존하고 현재 역할/현재 캐릭터를 과거에 대입하지 않는다. 전체3탭의 표시 범위/정렬·묶음·좁은화면은 구현 착수 설계에서 정한다. 서버 변경이 필요하면 그때 해당 기존 Issue와 협의하며 지금 새 구현을 요청하거나 추가 API를 만들지 않는다. 조사/문서diffcheck만·Flutter시험/실기기/서버·DB/dev/main 변경 없음.

## 현재 작업 — 신청 카드 문구 정리·아이템레벨 미표시 확인 (2026-10-25)

문구/기록 `58600023` 작업브랜치 commit/push, [Issue26 사용자 결과·레벨 누락6386174761](https://github.com/heo0328/lostparty-backend/issues/26#issuecomment-6386174761) 회신·게시본문 MATCH 확인. 다음 Backend는 기존신청 포함 레벨 출처/nullable·소유안전 보완 인계, Flutter는 해당항목만 후속 연결/확인이다. dev/main 미반영·기존 브랜치 유지다.

두 문구 수정 완료: clean→‘세팅 이상 없음’, 카드의 ‘좌석 미확정’ 삭제·승인대기는 유지. 변경2파일 analyze 문제0·포맷/diffcheck/리뷰, 문자열 변경이어서 Flutter시험 반복 없음. Backend6386031663/6444c18b의 새프로필 개발반영 인계 후 사용자 보고1/2는 아이템레벨 외 정상 범위통과로 기록한다. 기존 미반영/전체기기미확인 표현은 당시 기록이다. 철회·만료 등 별도 상태의 포괄통과로 확대하지 않는다.

아이템레벨 원인: 실행06ea4b21의 cycle_commands.apply 생성은 admission.core.identity.display를 저장하며 participation_core가 참조하는 groups.admission_core.display는 server_name/character_name/class_name만 반환한다. cycle_lists는 이 app.display를 그대로 제공한다. Flutter의 display.item_level 접근과 작성 예시에는 레벨이 있었지만 실제 저장 snapshot에는 없는 차이다. 이전 ‘실제 display에 레벨 제공’ 판단을 정정한다. 원본 실회원 응답 조회·DB 변경은 없으며 코드상 누락 경로를 근거로 Backend에 해당 항목 보완을 요청한다. 신규 신청 저장만 바꿔도 이미 존재하는 신청의 누락은 해소되지 않으므로 과거 snapshot/조회 보완의 출처·nullable·소유변경 안전성을 함께 인계받는다. 앱 추가조회/provider·타역할/최소조건 대입·임의 backfill은 하지 않는다. 이 항목은 Backend 대응/실제표시 재확인 대기다.

사용자가 표시 테스트1/2를 아이템레벨 ‘확인 필요’ 한 항목 외 정상이라고 보고했다. 신청자 카드 clean 문구를 ‘세팅 이상 없음’으로 바꾸고 ‘좌석 미확정’을 삭제한다. 기존 오류/경고·마지막성공 전투력/승인대기 안내·원명령/주차·목록 갱신 시점은 유지한다. 문구 변경은 포맷/변경파일분석/diffcheck·내용대조만 수행하고 정상 UI를 복제한 신규시험·기존 전체시험 반복은 하지 않는다.

아이템레벨은 앱이 신청 display.item_level을 읽지만 실제 저장 snapshot 생성부의 제공 여부를 확인해 Backend에 구체 인계한다. 다른 필드값/타인자료/현재레벨을 임의 대입하거나 카드별 추가 조회·계약 외 fallback은 하지 않는다. 원인과 실제 회원자료를 구분하며 이 항목을 완료로 표시하지 않는다. 기존 작업브랜치2b05ecd1 유지·무관 dirty 보존, 문서/Issue26 수동결과·필요수정회신 및 구간commit/push·dev/main미반영.

## 구현 결과 — 신청 카드 실데이터·본인 승인 대기 연결

구현 `ac9fe621` 작업 브랜치 commit/push, [Issue26 결과·예시 정합성6385536441](https://github.com/heo0328/lostparty-backend/issues/26#issuecomment-6385536441) 회신·게시본문 MATCH 확인. Backend는 작성 상세8예시의 항목/배정 참조 보완과 실제 소비차이만 대응, 새프로필 실제 개발 반영은 별도 승인/인계 후다. Flutter 코드는 검증 완료·기기 인수 대기이며 dev/main 미반영·브랜치 유지다.

Backend06ea4b21의 application-display-1을 전용 읽기 모델/Gateway로 연결했다. 신청 카드의 선택역할 마지막 성공 전투력·현재 분석/오류·소유연결 불가·미확인을 구분하고, v2 일반 상세는 본인 유효pending이면 신청버튼 대신 “공대장의 승인 대기중입니다.”를 표시한다. 참가관계 우선·accepted이력/만료·철회 후 기존 진입 조건을 보존한다. 기존 cycleDetail/applicationPage·쓰기용 재검사/DTO·내신청/단건review·membership/기록 경로는 유지한다.

목록 전용 ViewModel이 표시 행/커서·접근수명/epoch를 소유하며 회원·환경/session/readGeneration·T/dispose/늦은 응답·명령 후 기존조회 도착을 격리한다. 기존 신청자 확인/새로고침/더보기·같은 기기 명령 후 갱신 시점은 유지했다. 페이지 분석시점과 최소값에 따른 target_revision 차이는 허용하되 방/T·세대/신청 revision·커서/중복·빈 후속페이지를 검증한다. 카드별 GET/전체내신청조회·provider/자동갱신·기본응답 fallback은 없다.

최종 검증: 신규 **68PASS** + 기존 직접11파일 **345PASS**, 합계 **413PASS**. 변경 구현8파일/시험2파일 analyze 문제0·포맷·diffcheck/리뷰 완료. 신규68에는 Backend 작성예시의 목록9개 수용/상세8개 정합성 거절 시험이 포함된다. 원본 상세8개는 room.items/game_items=[]인데 Assignment/formation이 항목을 참조해 기존 파서가 거절한다. 원본 fixture는 그대로 보관하고 상태/HTTP 시험에는 대응 room.items를 채운 별도 합성 자료를 사용했다. 실제 서버가 같은 불일치라는 증거는 없고 Backend에 작성자료 보완만 요청한다. 기존 검증을 완화하지 않았다.

다음은 새프로필의 정확한 **개발 반영 인계 후** 카드 전투력/분석·pending 재진입/철회·만료·수락 후 흐름의 소수 디바이스 확인이다. 실제개발은 기존484ca171/fdd256ea/177·DB0031로 새프로필 미반영 기준이며 실회원·기기 성공은 미확인이다. 서버/DB/기기·dev/main 변경·전체시험 반복 없음, 목록갱신 정책/웹소켓/IF-001/BUG-025·일반오류 원인 추정수정은 제외했다. 문서·Issue26 결과/미확인·작성예시 차이를 회신하고 기존 브랜치 commit/push로 보관한다. 무관 dirty 보존.

## 다음 구현 준비 완료 — Issue26 카드 실데이터·본인 승인 대기 연결

2026-10-24 사용자 구현 진행 승인: 기준4136ce6b에서 아래 준비 범위를 착수한다. 전용 표시 모델/조회·신청표시 VM·카드/일반상세 상태 연결과 직접 검증을 수행하며 기존 쓰기·membership/기록·갱신 시점은 보존한다. 준비 단계의 ‘코드 미수정’은 당시 기록이며 이번 착수부터 구현한다. 서버 미반영 상태는 유지하며 서버/DB·기기/dev/main 변경은 하지 않는다.

준비 문서 `2bdf9976` 작업 브랜치 commit/push. [Issue26 실행 인계 수신·준비 결과6385307413](https://github.com/heo0328/lostparty-backend/issues/26#issuecomment-6385307413) 회신·게시본문 MATCH 확인. 다음 담당은 Flutter 구현이며 새프로필 서버 반영/기기 인수는 별도 대기다. dev/main 미반영·기존 브랜치 유지다.

근거: [Backend 구현 인계6385227653](https://github.com/heo0328/lostparty-backend/issues/26#issuecomment-6385227653), source **06ea4b214591f475d422f4599ca10260cda83d08** / feat/raid-recruitment. 합의 문서/실행 OpenAPI의 두 GET 입력·ApplicationDisplay 모델과 검증집계를 확인했다. Backend는 고유28PASS(신규17+기존명령8+membership3), 기본116/후보177 계약 보존·DB오류503 SERVICE_UNAVAILABLE 정정을 인계했다. **실제 개발은 여전히 source484ca171/이미지fdd256ea·177경로/DB0031이며 새 프로필은 미반영**이다. 경로 수로 반영 여부를 판단하지 않는다. 아래 ‘Backend 구현 대기’는 해소됐고 현재는 Flutter 구현 착수 준비 상태다.

이번 사용자 요청은 작업 준비이므로 기능 코드를 수정하지 않는다. 브랜치 feature/raid-recruitment-scheduling·기준fda8f3ad를 유지하고 무관 dirty를 보존한다. 준비 문서 검토·Issue 회신·commit/push만 수행하며 구현/실기기 성공을 주장하지 않는다.

### 구현 순서와 책임

1. **전용 조회 모델/Gateway:** application-display-1 상수·불변 Analysis/PowerComparison/신청 항목·페이지/MyApplication/일반 상세 envelope 모델을 분리한다. 필수/nullable·닫힌 shape·방/T/세대·역할/versions/issues/시각·display_reason 정합성·1MiB를 검증한 후 확장 필드를 제거한 복사본으로 기존 CycleOwnRow/parseCycleDetail을 재사용한다. 원본을 수정하지 않는다. 기존 AnalysisIssue/정밀값·scope 검증을 재사용하되 후보API의 supported/allowed 모델을 표시용 자격판정으로 오용하지 않는다.
2. **Repository 연결:** 기존 Repository가 별도 표시 조회 인터페이스를 구현한다. 목록 GET은 기존 실제T/state=pending/limit20/cursor에 reader_profile만 추가하고, 일반 상세 GET도 실제T/profile로 조회한다. 기존 CycleInteractionGateway.applicationPage·cycleDetail(승인 decisionBody 등 쓰기 전 조회 포함)/기본 DTO는 보존한다. 기존 내신청 목록/단건review·membership-actions-1/anchor·다른 일반 조회는 바꾸지 않는다. 새 조회 실패/미지원·누락을 기본응답으로 fallback하지 않는다.
3. **목록 상태/카드:** 신청 표시 전용 ViewModel이 조회 rows/cursor/error/opened/epoch와 회원·환경/session/readGeneration/room/T/dispose 수명을 소유한다. 현 위젯은 로컬 rows와 generation만 소유하므로 표시 계약 연결 시 접근 변경에 남은 행과 늦은 응답도 격리한다. 기존 ‘신청자 확인/새로고침/더 보기·같은 기기 명령 후 갱신’ 시점은 유지한다. 동일 신청 중복·커서 순환·세대/신청 revision 혼합을 거절하고 실패한 더보기를 빈 성공으로 합치지 않는다. 페이지별 분석 evaluated_at은 달라도 허용한다. 카드별 GET/context/전체내신청조회·provider/자동분석은 추가하지 않는다.
4. **카드 표현:** 기존 이름/직업·역할/레벨 snapshot·카드/승인거절 버튼을 유지하면서 실제 선택역할 마지막 성공 전투력과 현재 분석 clean/review/error/unavailable·issues를 구분한다. 현재 오류+마지막 성공값 동시 표시, head/성공 없음·소유/연결 불가·실제 조회 실패를 구분한다. 전투력 없음은0으로 바꾸지 않고 clean/meets를 승인가능 문구/버튼 자격으로 쓰지 않는다. 승인/거절은 기존 review/POST·원pending/ACK를 따른다.
5. **상세 상태/안내:** BackendRecruitmentDetailViewModel의 v2 일반 상세(reader==null)만 전용 읽기를 선택한다. 기존 member/record reader와 Router 경로·식별자는 유지한다. 현재 참가/권한→유효pending 안내→기존 신청 진입 조건 순서로 노출하며 pending은 “공대장의 승인 대기중입니다.”로 신청버튼을 대체한다. accepted이력으로 참가를 만들지 않는다. 만료/철회·거절·취소/없음도 자동허용하지 않고 기존 조건/context를 따른다. 새 필드 누락/조회 실패/로딩·회원/T 변경에서는 이전 신청 진입을 열지 않는다. 로컬 시간 경과만으로 pending을 없애거나 신규 쓰기를 하지 않으며 기존 새로고침/재진입·수명 갱신으로 최신 상태를 확인한다.
6. **검증·마감:** 아래 직접 시험을 최종 상태에서 묶고 변경 파일 분석·포맷/diffcheck/리뷰→문서 최신화/Issue26 정확 구현SHA·결과·미확인회신→작업브랜치commit/push로 보관한다. 코드 영향이 표적으로 설명되지 않을 때만 전체시험을 확대한다. 서버 교체·DB·기기·dev/main통합은 별도이며 이번 준비/후속 앱 구현에서 수행하지 않는다.

### 회귀 보호 및 완료 조건

- 계약: 추가 필드 누락/임의값·잘못된scope/역할·타인/T/세대·필수nullable/분석-비교 불일치·크기 초과 거절, current오류+retained 성공/소유변경/head없음과 서비스실패 구분. 기본/쓰기·본인신청목록·단건review·membership/기록 파서에 새 필드 강제 금지.
- 상태: 현재참가/pending/null·terminal/accepted 후 탈퇴를 구분, 만료 경계는 서버시각. 회원·환경/session/readGeneration/T 전환·연속조회/dispose/늦은 응답·더보기 실패·접근권한 상실에서 자료/버튼 격리. 기록 진입은 기존 읽기전용 유지·신규 표시 조회/쓰기0.
- 직접 기존 시험: cycle_interaction·application_detail_navigation·membership_readers/membership_presentation·backend_recruitment/cycle_recruitment 및 기존 admission_candidates의 원ACK/재송·승인/거절/철회 경계 중 호출 영향만 묶는다. 원ACK 성공 후 표시조회 실패는 쓰기를 다시 실행하지 않는다. 생성·캐릭터변경·일정/완료/해산·C/N 연관 영향이 발견되면 해당 기존 시험도 포함한다. 수동5구간은 구현/회귀 제외 기준이 아니다.
- 서버 정확 반영 인계 후 사용자 소수 확인: (1) 공대장 카드의 전투력/현재분석·정보없음 구분 (2) 본인 pending 상세 재진입의 대기안내/신청버튼 없음 (3) 철회·만료 후 기존진입/수락 후 참가·변경 유지. 기존 통과3항목 전체를 이유없이 반복하지 않는다. 변경/반대파티·주차교차 관련 인수는 계속 추적한다.

제외: 신청 목록 진입/갱신 정책 변경·자동 polling/실시간/웹소켓·알림, 일반오류 원인 추정수정, 리디자인/IF-001/BUG-025. 이번 준비 검증은 문서diffcheck/계약·호출자 대조만이며 Flutter시험/실회원 요청은 실행하지 않는다. Backend28·작성22/정적15·이전Flutter493/56은 새 시험으로 합산하지 않는다.

## 현재 인계 — Issue26 신청 표시 프로필 제안1 소비 검토

소비 기준 `84b132a2` commit/push, [Issue26 수용6384902537](https://github.com/heo0328/lostparty-backend/issues/26#issuecomment-6384902537) 회신·게시본문 MATCH 확인. 다음 담당은 Backend 읽기 구현/실행 인계이며 같은 정책 재수용이나 전체시험 반복은 요구하지 않았다. 현재 작업 브랜치 유지·dev/main 미반영이다.

사용자 진행 지시로 [Backend 제안6384757210](https://github.com/heo0328/lostparty-backend/issues/26#issuecomment-6384757210), source `f0c7665c`의 계약 문서/closed schema·작성22응답을 현재 Repository/Router/ViewModel/카드와 대조했다. **제안1을 소비 가능으로 수용하며 Backend 읽기 구현·실행 계약 인계를 기다린다.** 아직 앱/서버에 새 프로필이 구현됐다는 의미는 아니다. 기존2d94d462/feature/raid-recruitment-scheduling을 재사용하며 무관 dirty를 보존한다.

- 새 `application-display-1`은 공대장 신청 목록과 일반 상세에만 사용한다. 기존 기본·쓰기 조회/본인 신청 목록·단건review/`membership-actions-1`·기록 경로를 유지하고 두 프로필을 결합하거나 자동 fallback하지 않는다. 닫힌 모델에서 추가 필드를 검증한 후 기존 기본 항목/상세 파서를 재사용할 수 있다. 일반 상세 선택은 현재 reader==null 경계, 참가·기록 reader 경로는 유지한다.
- 목록 comparison/analysis/display_reason은 필수 nullable이다. 저장 display와 현재 페이지 evaluated_at의 역할 전투력/분석을 분리하고 성공본/현재 오류를 섞지 않는다. analysis가 없거나 연결 불가인 상태·실제 조회 실패를 구분한다. 카드 상태는 전체 승인 판정이 아니며 기존 review/POST를 계속 따른다. 페이지별 분석 시각 차이를 허용하고 후보API처럼 전페이지 동일 분석 snapshot을 요구하지 않는다. 프로필 cursor/회원·session/방/T·세대·신청 revision 경계/최대크기·no-store는 계약대로 검증한다.
- 상세 my_application은 필수 nullable, 객체4필드 검증 후 현재 참가→유효pending→기존신청조건 순으로 표시한다. accepted는 참가 관계를 만들지 않는다. 만료 경계는 server_now, 조회실패/필드누락은 없음으로 취급하지 않는다. pending 만료·철회/수락 후 재진입도 최신 조회·기존 권한을 따르며 로컬 시각/옛 성공 힌트만으로 신청 진입을 열지 않는다.
- 다음 Backend: 합의한 read-only/bulk 구현·직접 권한/소유·역할/세대·C/N·만료·자료 실패 경계와 기존DTO/ACK 회귀, 정확 SHA·실행 OpenAPI/개발 반영 여부 인계. 같은 전체시험 반복 요청은 아니다. 그 후 Flutter가 전용 조회 DTO/Gateway/시트·상세 상태 연결, 이전 카드 배치·원pending/ACK·기록/비동기 격리 보호와 직접 시험을 수행한다. 서버 교체는 별도 승인이다.

이번 구간은 계약 검토·문서/Issue 회신만이며 기능 코드·API/DB/기기 변경·Flutter 시험 반복·dev/main통합은 없다. 신청 목록 진입/갱신 시점·실시간/웹소켓·일반오류 원인수정은 포함하지 않는다. 문서diffcheck와 코드·계약 내용대조만 수행하며 작성 예시를 실행시험으로 집계하지 않는다.

## 현재 작업 — 신청·파티 카드 및 대기 안내 UI (2026-10-24)

구현 `c85715c5` 작업 브랜치 commit/push. [Issue26 인수 결과·조회 계약 요청6384482003](https://github.com/heo0328/lostparty-backend/issues/26#issuecomment-6384482003) 회신·게시본문 MATCH 확인. Backend 담당: 카드 일괄 전투력/오류·상세 본인 pending 최소 투영/호환 계약 제안. Flutter는 계약 수신 후 실제 표시·대기 안내 연결, 사용자 카드 디자인 확인 대기다. 목록 갱신 정책은 후속 협의다.

카드 디자인 구현/변경3파일 analyze 문제0·관련 기존3파일56PASS·포맷/diffcheck 완료. 신청자는 이름/직업·역할/아이템레벨/전투력/오류 상태 영역과 거절(Outlined)/승인(Filled) 버튼, 파티 구성원은 기존 자리·권한·추방 조작을 유지한 테두리 카드다. 전투력/오류 정보는 미제공으로 ‘확인 필요’이며 실제 판정을 꾸미지 않는다. 본인 pending 안내와 실제 수치 연결은 아래 Backend 계약 보완 후 남은 작업이다. 신규 카드 모양의 사용자 확인은 대기다.

사용자가 후보/역할·신청·수락/갱신 세 항목과 신청카드 상세 진입 정상 통과를 보고했다. 재진입 후 신청 캐릭터 선택의 일반 오류와 신청 대기 버튼 노출은 별도 UX 문제로 기록한다. 이번 승인 범위는 신청자 카드(직업/아이템레벨/전투력/오류 상태 영역)·승인/거절 버튼·파티 구성 카드의 경계, 이미 알려진 본인 신청/참가 상태에 따른 안내다. 기존 진입 루트/목록 조회·갱신 시점/실시간 정책은 변경하지 않는다.

현재 신청 목록 display와 상세의 my_target_role을 사용한다. 목록에는 전투력/분석 상태, 일반 상세에는 본인 pending 상태가 없으므로 임의 추정·다른 계정 자료/캐릭터별 추가 조회로 대체하지 않는다. 누락 영역은 확인 필요로 표시하고 Backend에 일괄 표시/본인 상태 계약을 요청한다. 만료/철회·회원/주차 변경 후에도 과거 경로의 pending 힌트를 계속 믿는 오표시를 피하기 위해 이번에는 Router 힌트를 추가하지 않는다. pending 안내/버튼 숨김의 완결은 서버의 실제 방/T별 본인 상태를 받은 뒤 연결한다. 참가자의 기존 신청 버튼 숨김은 유지한다. 서버 권한/승인·거절·원ACK/기록읽기전용/주차 전환은 보존한다.

순서: 기존 표시/경로 조사→최소 상태 전달·카드/버튼 적용→변경 파일 분석/포맷·diff 검토와 직접 경계/라우팅 회귀만 확인→문서·Issue26 테스트 결과/필요 필드 인계·작업 브랜치 commit/push. 정상 카드 모양을 반복 자동 UI 시험하지 않고 사용자 수동 확인을 우선한다. 신규 카드의 최종 모양/다중 파티·좁은 화면은 사용자 확인 대기, 전체 시험/서버·DB·기기 조작/dev/main통합은 없다.

## 현재 다음 행동 — Issue26 개발 반영 수신, 로그인 앱 소수 인수

[Backend 회신6383315604](https://github.com/heo0328/lostparty-backend/issues/26#issuecomment-6383315604)과 연결된 rollout 문서를 확인했다. 구현 source484ca171/반영 근거0096319b, 실제 개발177경로·DB0031/양 intent 후보GET 반영 완료 보고다. 계약 변경 없음, migration·실회원 업무자료 수정 없이 전후108표/780행·설정/키 불변을 확인했고 실행 OpenAPI/HTTP8건 검증·API/DB healthy를 인계했다. 이는 Backend 보고/근거 확인이며 Flutter가 서버나 실회원 명령을 재실행한 것은 아니다. 아래 과거 ‘개발176·미반영/반영 대기’는 당시 상태이며 현재 대기는 **정상 로그인 실회원·사용자 디바이스 인수**다.

다음 사용자 수동 확인은 최신 구현 f89c009f 포함 앱에서 같은 대상 방/주차를 사용해 ①신청 후보와 허용 역할/기본 선택 ②신청 성공 후 원방 상세 유지·신청 목록 반영 ③공대장 수락 후 양쪽 참가/인원·계정 표시 갱신의 세 항목부터 진행한다. 실패 시 해당 단계·선택 주차·비식별 오류 문구/code만 받아 최소 재현 후 Issue26에 회신한다. 캐릭터 변경/반대 파티 동의와 관련 기존 흐름·C/N 직접 영향도 후속 인수에서 유지하며 1~5를 구현 제외 기준으로 쓰지 않는다.

이번 확인에서는 기능 코드·서버/DB·기기/배포·dev/main 변경과 시험 반복을 하지 않았다. 자체 Flutter493PASS·Backend 격리45PASS·배포HTTP8건은 별개 근거다. 정상 로그인 신청/승인·변경 성공은 아직 미확인이다. 같은 정책 재수용/반복 검증을 요청하는 댓글은 추가하지 않고 실제 소비 차이가 발생하면 회신한다.

## 구현 결과 — Issue26 통합 후보·자격 연결 (2026-10-24)

구현 **`f89c009f`** 작업 브랜치 commit/push. [Issue26 결과6382646003](https://github.com/heo0328/lostparty-backend/issues/26#issuecomment-6382646003)에 정확 SHA/493PASS·미확인 인수를 회신하고 게시본문 MATCH 확인했다. 연결 도구 작성403은 기존 GitHub CLI 인증으로 게시했다. 같은 정책 재수용/전체시험 반복은 요청하지 않았다. dev/main 미반영·작업 브랜치 유지다.

신청·캐릭터 변경 두 intent의 후보 조회/선택·최신 확인·원ACK 성공 식별을 함께 구현했다. 실행 기준은 Backend `484ca171`의 계약177이며, 아래 착수 계획과 이전의 ‘문서만/구현 대기’ 상태는 이번 결과로 갱신한다. 전용 AdmissionCandidatesGateway/불변 DTO, 순차 전페이지 수집과 시트 소유 AdmissionSelectionViewModel을 추가했고 기존 쓰기 본문·멱등키·원pending 복구는 유지했다.

- 자격은 신규 GET만 사용한다. 동일 snapshot/actor/정책/세대/계수·집계, UUID 순서·커서·최종 개수를 검사한 뒤 한 번에 표시하며 응답 1MiB를 제한한다. 기본 캐릭터 목록으로 대체하지 않는다. 기존 characters()는 표시·대표·선호 역할 결합용이며 UUID/등록 연결 누락 시 1회 재조회 후 명시 오류다.
- 기존 카드·원정대별 레벨 정렬/대표·허용 선호 역할을 유지했다. 지원 불가 역할은 비활성화하고 원후보0/조건탈락0/전투력 부족·미달/조회 실패를 구분한다. 자동 캐릭터 갱신은 실행하지 않는다.
- 변경 확인창에 주차·변경 캐릭터/역할과 기존→대상 파티를 표시한다. 확인 후 최신 context/actor·교체 revision/배치가 달라지면 쓰기를 막고 후보·확인을 갱신한다. 다른 캐릭터를 자동 제출하지 않는다. 수락 불가는 구체 사유를 표시하고 신청 유지·거절/철회 계약을 보존한다.
- 화면/후보/미리보기는 회원·환경·세션/readGeneration/조회 epoch/dispose로 격리한다. 성공 종료는 방/T/intent/원명령 key가 일치하는 ACK만 인정하고, 응답 불명은 기존 원명령 재송이다. ACK 후 조회 실패는 성공을 취소하거나 중복 쓰기하지 않는다. 즉시 가입은 기존 계약이다.

최종 검증: 신규 후보·선택·변경 경계 **60 PASS**, 기존 직접 영향 15파일 **433 PASS**(합계493); 변경 구현6파일+신규 시험1파일 analyze 문제0, 포맷/diffcheck·diff 검토. 처음 발견한 누락 import/분석 경고와 여러 페이지 역할 참조를 수정한 최종 결과다. 표적 시험으로 공용 Controller/시트·기존 생성/상세·기록/일정·완료/탈퇴·추방/주차 연결을 설명하므로 전체 시험 반복은 하지 않았다.

다음 행동은 개발 서버 신규 API 반영 상태 확인 후 사용자 수동 2구간의 소수 항목(후보/허용 역할 → 신청·수락 → 조건 변경 사유/거절·철회)부터 진행한다. 반대 파티 변경은 구현·자동 검증했고 관련 수동 인수도 추적한다. 실제 개발176/DB0031 기준 신규 API 실회원/기기 성공은 미확인이다. 서버 배포/DB 변경·기기 조작·dev/main 통합은 하지 않았다. 웹소켓·IF-001·BUG-025·리디자인 제외, 무관 dirty 보존. 작업 브랜치 commit/push 및 Issue26 결과 회신으로 보관한다.

### 착수 시 기록한 구현 순서

사용자 승인 계획으로 현재060a2032/feature/raid-recruitment-scheduling에서 구현한다. Backend484ca171 실행계약177을 기준으로 전용불변 DTO/Gateway·기존Repository 구현→동일snapshot 전페이지 수집·시트소유 ViewModel→신청/변경 선택·반대파티동의/최신재확인→원ACK 성공식별·수락불가사유→직접영향 검증/문서/Issue26 회신·작업브랜치 commit/push 순서다. 현재 API176/DB0031 미반영이며 서버/DB/기기조작·dev/main통합은 하지 않는다.

새후보는 자격원본, 기존characters()는 표시/대표/선호역할 결합용이다. 누락시1회재조회후오류, 임의후보제외/기본목록fallback 없음. 회원/환경/세션/readGeneration·room/T/intent·epoch/dispose격리, 기존정렬/카드·일정선택/원pending·ACK/신청상세경로·즉시가입을 보존한다. 신청/변경을 함께 연결하며 생성·일정/완료/해산·주차 영향도 보호한다. 수동시험5구간은 구현제외기준이 아니다.

검증은 신규 DTO/페이지/선택·actor/쓰기0/성공식별·지연격리 경계와 기존 interaction/reader/목록·생성/관리·일정/완료·탈퇴/추방/재개 직접시험을 최종묶음으로 실행하고 변경분 분석·포맷/diffcheck/리뷰한다. 표적으로 설명되지 않는 공용영향이 발견될 때만 전체시험으로 확대한다. 웹소켓·IF-001활성화·BUG-025·리디자인 제외, 정상로그인/실회원·기기는 서버반영후 사용자 소수항목으로 확인한다.

## 최우선 정정 — 5구간은 수동 테스트 분량 구분, 구현 제외 기준이 아님

문서 `8112a2bb` commit/push. [Issue26 정정6382315586](https://github.com/heo0328/lostparty-backend/issues/26#issuecomment-6382315586) 게시본문 MATCH 확인. 통합구현/전체연결 보호와 수동시험분량 구분을 전달했으며 추가반복수용/시험회신 요청은 없다.

2026-10-24 사용자 정정: 1~5는 사용자에게 한 번에 요구할 디바이스 테스트 양을 나누는 단위다. **설계·구현·성공 판정은 생성→가입→상세 조작→완료/해체→C/N 전체가 유기적으로 연결되어 성공해야 한다.** 현재2를 확인한다는 이유로 생성/캐릭터변경·일정/완료·해산/다음주 연결을 조사·수정·회귀 범위에서 제외하지 않는다. 이전통과도 변경의 직접영향을 받으면 필요한 재확인을 수행한다. 별도기능을 무관하게 추가하지 않는 범위관리와 관련정상흐름을 보호하는 영향분석을 구분한다.

Issue26은 이미 신청·캐릭터변경의 통합계약/UX를 확정한 하나의 연결 작업이다. source484ca171의 신규후보GET 두intent·공통자격/원명령·반대파티 동의/실패보존과 생성/주차/일정·완료에 미치는 영향을 함께 검토·연결한다. ‘2이므로apply만연결/변경문맥은3까지제외’로 해석하지 않는다. Backend 구현/격리45PASS·177계약 인계는 받았으나 실제개발176/DB0031에는 미반영이다. 현재는 이 정정의 문서/협업기록만 하며 기능구현을 새로 착수한 것은 아니다.

사용자에게는 여전히 현재 테스트 묶음의 소수항목부터 제시한다. 다른묶음의 관련수정/회귀가 필요하면 영향과 이유를 설명해 해당항목만 재확인하고, 이미통과한 전체표를 이유없이 반복하지 않는다. 개별묶음 통과는 부분인수 기록이며 제품전체성공/릴리즈승인이 아니다. 아래 ‘2가입부터 구현/다른구간후속’처럼 구현범위를 수동시험순서로 제한할 수 있는 표현은 이 정정이 우선한다. 장기기준은 설계37 §37.54다.

## 현재 인계 — Issue26 성공·실패 UX 확정 (2026-10-24)

문서 `e7bfe113` commit/push. [Issue26 UX 확정6381816954](https://github.com/heo0328/lostparty-backend/issues/26#issuecomment-6381816954) 게시본문 MATCH 확인. 사용자 두 결정/6항목 성공·실패·계약2 소비 판단/다음 담당을 전달했다. 다음은 Backend의 직접 계약 차이 확인과 확정범위 구현/실행 인계다.

사용자 요청으로 Backend 보완 계약2(77be3a95/6381680561)를 실제 선택/확인·원명령 처리와 대조하고, 사용자에게 필요한 두 결정을 확인했다. **8인 변경의 반대 파티 이동은 확인창에 대상 파티를 표시하고 동의 후 실행**, **수락 불가 시 대기 신청 유지·공대장에게 사유 표시·거절/철회 가능**으로 확정했다. 서버 구현에 전달할 6개 UX 항목과 단계별 성공/실패는 [설계37 §37.53](../backend-migration/37-raid-scheduling-and-multi-raid-planning.md)이 기준이다.

현재 2구간은 후보/역할 선택→신청 확인→최신 자격 검사→pending 저장→수락/거절·철회와 양쪽 화면 결과를 다룬다. 정상 신청은 시트를 닫고 원래 방 상세를 유지하며 신청 목록을 갱신한다. 승인 성공은 실제 참가 목록/계정 i/인원·검색 캐시를 갱신한다. 후보 로딩/실패와 원후보0/조건탈락0·전투력 missing/below를 구분하고, 자격 변경은 같은 방/T에서 후보를 갱신해 유효한 기존 선택만 유지한다. 다른 캐릭터를 자동 제출하지 않는다. 결과 불명은 원요청 확인, ACK 뒤 조회실패는 조회만 재시도한다. 권한 오류는 자격탈락 빈목록으로 숨기지 않는다.

3구간 캐릭터 변경은 서버가 도출한 현재 actor/Assignment와 최신 context의 targets.party_no를 비교해 이동할 파티를 명시한다. 최종 재검사에서 배치/자격/actor가 달라지면 POST 없이 확인을 갱신한다. 승인 시 신청에 저장된 파티를 자동 재배치하는 기능은 추가하지 않는다. 실패 시 기존 참가/자리/예약·다른T를 보존하고 성공 후 같은 상세에 새 상태를 반영한다. 실제 변경 디바이스 인수는 3구간에서 수행한다.

다음 Backend: 확정 UX와 계약2의 성공/실패·토큰/배치/상태 전이가 일치함을 확인하고 필요한 wire/직접 검증 항목만 보완한 뒤 구현·실행 계약/정확 SHA·개발 반영 여부를 인계한다. 계약2의 역할지원·전투력·사유 우선순위는 §37.53 소비 판단으로 정리했으며 같은 제품정책 재수용/기존 전체시험을 반복 요청하지 않는다. 이번은 문서·Issue26 인계만이며 앱/서버 코드·DB/기기·시험 실행·dev/main 통합은 없다. 전체 성공을 현재 실행 중인 기능으로 표시하지 않는다.

## 디바이스 수동 확인 순서 — 5구간으로 분량 나눔

전체 기능의 긴 테스트표를 한 번에 반복 전달하지 않는다. 아래 구간을 **현재구간 테스트 → 발견문제 최소수정/관련자동검증 → 해당항목 재확인 → 구간마감/문서·작업브랜치보관 → 다음구간** 순서로 진행한다. 같은 정상항목은 관련코드/계약이 바뀌지 않으면 재시험하지 않는다. 구간통과는 dev/main통합·릴리즈완료와 별개다.

| 구간 | 사용자 확인 범위 | 현재 상태 |
|---|---|---|
| 1. 모집 생성 | 생성조건 선택·생성성공/상세진입·새생성 | 사용자 보고 범위 통과: C/N 단독·동시생성. 미실행 생성조건까지 포괄통과로 확대하지 않음 |
| **2. 가입 행위** | 신청·참가·수락/거절·철회, 후보캐릭터/역할·레벨/전투력/완료·점유/직업구성 판별과 가입결과 반영 | **현재 진행 구간**. 기존재신청 수락/거절·생성자검색제외 통과보존. Issue26 계약/서버반영·후보목록 연결과 신청상세 수정본 재확인 필요 |
| 3. 방 내부 행위 | 레이드조건/설정·편성/위임·참가캐릭터 변경·일정/제안·투표/참가확인 | 사용자 수동시험은2 다음묶음. 연관설계/구현·자동경계와 필요한회귀는 현재작업과함께확인 |
| 4. 완료·해체 | 주차/개인완료·탈퇴·승계·해산·완료해제와 기록/목록 결과 | 사용자 수동시험은3 다음묶음. 관련영향은미리보호하며 비활성 IF-001은 재소개하지 않음 |
| 5. 이번주·다음주 분리 | 함께하기·주차별 참가/캐릭터/공대장·일정/완료/탈퇴·해산의 독립성, 주차전환 | 사용자 수동시험의 교차흐름묶음. 주차격리/연결 구현은모든작업에서보호하고 직접영향만재확인 |

구간마다 사용자에게는 **이번에 실행할 소수 항목과 기대결과만** 전달한다. 다른구간 이슈는 후속기록으로 보존하고 현재인수를 무관하게 확대하지 않는다. 현재2구간을 전부마쳤다고 표시하지 않으며 다음첫행동은 Issue26 최신보완계약 검토/정확실행인계 후 가입후보·실제가입 연결의 필요한 수정이다. 서버인계전 불가능한 시험을 사용자에게 반복요청하지 않는다. 가능한 현구간 확인(신청상세 수정본 등)은 준비조건이 있을 때만 제시한다.

코드변경의 회귀보호는 구간경계와 별개다. 공용정책/Router·저장·권한에 직접영향이 있으면 필요한 자동경계/영향항목을 확인하되 전체실기기표로 확대하지 않는다. C/N·회원격리/원pending·ACK는 모든구간의 보호기준이고 5구간 전에는 무시하는것이 아니다. 기존실기기 설치/조작은 사용자담당이며 소수항목 실패 시 정확증상부터 최소수정한다. 아래 과거 ‘전체인수에묶음/전체체크리스트’ 순서보다 이 최신방식이 우선한다. Backend계약 협업/웹소켓별도협의·dev/main미반영은 유지한다.

## 최신 사용자 확정 — 신청·캐릭터 변경의 통합 자격 기준

문서 `71e279ed` commit/push. [Issue26 최신조건6381254676](https://github.com/heo0328/lostparty-backend/issues/26#issuecomment-6381254676) 게시본문 MATCH 확인. 전투력/변경문맥까지 범위를보완해전달했고 Backend 계약회신대기다.

2026-10-24 사용자 지시로 **신청과 캐릭터변경 모두** 레벨·선택역할 전투력·선택T 동일raid 완료/다른방 실제참가·4인파티 역할/직업구성을 고려한다. 이전 Issue26 제안/Flutter6381216870의 ‘전투력은 후보제외에서 빼고 선택후context만 안내’ 범위는 이 최신요구로 보완한다. 선택목록에서도 사용할 수 없는 캐릭터/역할을 미리 제외하되 정보누락을0/성공/빈목록으로 위장하지 않으며 후보미리보기와 실제POST·승인의 최종검증은 같은정책을 재사용한다. 상세는 [설계37 §37.52](../backend-migration/37-raid-scheduling-and-multi-raid-planning.md).

파티구성은 각4인단위의 **동일딜러직업 중복금지**다. 딜러발키리+서포터발키리는 허용, 8인은 동일딜러직업이각파티1명씩최대2명 가능하나 같은파티2명은 불가다. 전체직업명만세어딜러/서포터조합을금지하지 않는다. 캐릭터변경은 본인교체대상 자리/기존참가만 제외한 가상구성으로 검증하고 다른방점유/완료는 계속차단, 검증/저장실패시 기존본인참가·다른T는보존한다. 기존역할정원·지원4직업/일반dealer고정은 유지한다.

다음 Backend: Issue26에 전투력포함 후보판정·캐릭터변경문맥(자기참가제외/동시성)까지 계약범위 보완과 신규read/기존context·POST·승인의 공통검증표/실행차이를 회신한다. 기존apply전용GET을 임의로change에호출하지 않으며 변경용endpoint/DTO·전투력누락/오래됨/경고자료 처리는 닫힌계약으로 제안받는다. 다음Flutter는 그 계약대조/합의후 후보조회·역할선택·실제쓰기를 연결한다. 현재코드수정/서버반영·실기기검증은 미완료, 이번은 문서/Issue회신·diffcheck/작업브랜치보관만이다.

## 현재 단일 작업 — Issue26 후보계약 소비 검토·회신 (2026-10-24)

문서 `1501867b` commit/push. [Issue26 검토6381216870](https://github.com/heo0328/lostparty-backend/issues/26#issuecomment-6381216870) 게시본문 MATCH 확인. 역할일치 보완1건과 나머지소비안·다음담당을 회신했으며 Backend 보완계약 회신대기다.

[Backend6381161170](https://github.com/heo0328/lostparty-backend/issues/26#issuecomment-6381161170)의 source6e0063c7/개발안내·제안문/closed schema·작성예시3개를 현재 Flutter0a0d2838의 characters()/RecruitmentCharacter·선택sheet/기존역할정책·페이지/scope와 대조했다. 기존신청검사 보완은 Backend 구현/격리고유25PASS지만 **실제 개발API176/DB0031 미반영**, 후보GET은 미합의·미구현이다. 아래 ‘Backend구현 전체대기’는 이 구분으로 갱신한다. 장기근거/소비차이는 [설계37 §37.51](../backend-migration/37-raid-scheduling-and-multi-raid-planning.md).

일괄조회·현재scope/불변snapshot·역할별Permission·raw/eligible count·빈화면/오류 구분은 소비 가능하다. 단 **일반직업 dealer고정/지원4직업만 복수역할**인 기존 UI와 ‘직업명 신규제한 없음/양역할판정’의 관계를 Backend가 닫아야 한다. 일반직업 support-only를 후보로 세면 화면에서 선택가능한역할이0이 된다. 기존제품역할로 후보/eligible count를 일치시키고 unsupported-role의 wire표현/거절코드를 제안/명시해 달라고 회신한다. 현재닫힌 enum에 임의코드를 만들거나 정상후보를 앱에서 조용히 추가제외하지 않는다. 4직업목록/원정대·선호역할 코드는 §37.51 근거를 따른다.

Flutter소비안: UUID순 전송페이지는 동일snapshot/count/room·T/세대/catalog·중복/커서상한·누락을 확인해 전체수집 후 원정대별 레벨순으로 한번에 반영한다. 페이지단위 재정렬/첫페이지 대표임의선택·구snapshot 병합을 하지 않는다. 표시는 기존회원scope의 원정대표시/대표UUID·선호역할 자료를 ID로 결합해 재사용하고 권한판정 원본은 새서버후보이다. 표시자료가 없거나 엇갈리면 기존일괄계정갱신으로 회복하고 불일치를 숨겨 후보0건으로 만들지 않는다. 후보마다 context/원정대GET은 추가하지 않는다. 허용된선호역할 우선·불가면 유효역할, 일반직업 dealer고정과 4지원직업 역할전환은 보존한다. 최초로딩/실패와 raw0·eligible0를 구분하고 회원/환경/session/readGeneration·room/T/선택·dispose에 epoch 격리를 적용한다. snapshot token은 쓰기token이 아니다.

다음 Backend: 역할일치 차이의 보완계약/예시를 회신하고 합의후 신규후보GET 구현·직접검증/정확SHA·실행계약·개발반영여부를 인계한다. 일반직업/복수역할·복수페이지 예시 보완만 요청하고 같은전체시험 재실행을 요구하지 않는다. Flutter는 그 인계 후 전용read상태/선택목록에 연결한다. 이번은 문서·정적소비검토/Issue26회신만이며 Dart/의존성/API·DB·디바이스 변경/시험반복·dev/main통합 없음. 웹소켓은 별도UX협의후속이고 신청상세 수정본 재인수는 유지한다.

## 별도 후속 등록 — 웹소켓 목록 갱신 사전 협의

사용자 요청(2026-10-24)으로 [설계37 §37.50](../backend-migration/37-raid-scheduling-and-multi-raid-planning.md)에 웹소켓 기반 목록 갱신을 후속 등록했다. **첫 작업은 무엇을 언제 갱신하고 화면에서 어떻게 표현할지 사용자·Flutter·Backend가 협의하는 것**이며 구현/endpoint·구독/자동재조회 정책은 미확정이다. 이번은 기록만 하고 서버 구현 요청·기능코드 수정은 하지 않는다. 현재 신청후보 계약/상세 재인수 순서를 대체하지 않는다.

## 완료 수정 — 신청목록 카드의 대상주차 상세 연결

구현 `63b77872` commit/push. [Issue13 결과6380903829](https://github.com/heo0328/lostparty-backend/issues/13#issuecomment-6380903829) 게시본문 MATCH 확인. 실제N신청 상세 재인수는 미확인, 별도후보계약 요청은 유지한다.

사용자 다음주 신청카드 진입시 멤버/정보 누락·다음주 개방버튼 노출을 보고했다. 실제 BackendApp의 CycleOwnRoomsPage.onRoom이 모든 탭에 membershipDetailLocation을 적용해 신청자까지 활성Member 전용reader로 보내는 회귀를 확인했다. 신청목록에는 별도의 일반상세 callback을 전달하고 선택한 실제T를 보존한다. 참가중/기록의 profile·anchor, 신청철회/원요청/필터/캐시는 유지한다. 조회실패화면의 무조건open/reopen 노출은 이 잘못된진입의 부수증상이며 이번은 신청경로 직접원인만 수정한다.

구현순서: 명시 신청callback/일반상세경로 → 실제 선택T/신청·참가·기록 경로분리 경계검증 → 관련직접 reader/목록·신청 시험/변경분석·포맷/diffcheck → 문서·Issue13 결과회신·구간commit/push. Router/DI의 국소callback 변경이므로 무관전체시험은 생략하고 파급증거가 있으면 확대한다. 후보목록 서버계약 보완은 별도대기로 유지하고 서버/DB·디바이스조작/dev/main통합은 제외한다.

실제 onApplicationRoom 필수callback을 분리해 `/recruitments/:room?target_cycle_key=T` 기본상세로 연결했다. 참가/기록의 명시profile/anchor는 보존했다. 직접4파일 단일117mock PASS(신규 실제목록위젯 C/N2건 포함), 변경Dart3파일분석0·포맷/diffcheck/리뷰. 다음 사용자 재확인: 다음주 신청카드→신청한N 상세의 실제멤버/레이드·일정 표시, 이번주로 잘못이동하거나 참가전용조회 오류화면이 나오지 않음. 이 실제인수는 미확인이고 후보목록 계약대기는 아래대로 유지한다.

## 현재 단일 후속 — 신청 시 동일 딜러 직업 구성 검사 (2026-10-24)

후보목록 UX 문서 `c59aefbd` commit/push. [Issue13 후보계약 보완6380816312](https://github.com/heo0328/lostparty-backend/issues/13#issuecomment-6380816312) 게시본문 MATCH 확인. Backend 일괄후보 계약 제안/기존신청검사 보완 대기이며 Flutter 목록제외는 아직 미구현이다.

최신 사용자 UX 보완: **신청 캐릭터 선택 목록 자체에서** 선택방/실제T/레이드·난이도의 레벨미달 및 동일4인파티 딜러직업 중복으로 불가능한 캐릭터를 제외한다. 선택후 버튼비활성/오류만으로 완료하지 않는다. 현 characters()는 인증/활동 후보만 반환하고 room/T 정보가 없으므로 아직 이 요구를 충족하지 않는다. scope/T/방별 후보의 일괄자격 조회·기존정책 재사용 계약을 Backend와 고정한 뒤 Flutter 목록을 연결한다. 캐릭터별 context N회·선행 멤버전체GET/로컬정책복제를 기본해법으로 두지 않는다.

역할을 둘다 쓰는 캐릭터는 유효한 역할이 하나라도 있으면 유지하고 불가능한 역할을 가능한 것으로 취급하지 않는다. 8인반대파티 유효배치·동일T 모든묶음raid/난이도 기준, 기존 대표/원정대 정렬·선호역할을 보존한다. 원후보0건은 기존 인증/활동안내, 필터후0건은 ‘이 모집에 신청 가능한 캐릭터가 없습니다.’ 안내, 조회실패/미확인은 오류·재시도로 구분한다. 전회원·다른방/T·오래된세대 응답은 후보를 덮지 못하며 목록제외는 POST/승인 최종검증을 대체하지 않는다. 구체 HTTP/DTO는 미합의이며 임의endpoint를 호출하지 않는다. 이번은 기존요청의 UX·후보계약 보완 전달, 기능코드 미변경이다.

문서 `ef4ec432` commit/push. [Issue13 수정 요청6380773556](https://github.com/heo0328/lostparty-backend/issues/13#issuecomment-6380773556) 게시본문 MATCH 확인. Backend 기존validator 재사용/실행 인계 대기이며 앱·서버 수정 완료가 아니다.

사용자가 4인방의 동일딜러 직업 신청이었다고 보완했고, 승인시점이 아닌 **신청 단계부터 기존 구성상 불가능한 신청 차단**을 요청했다. 기존 실패의 원code는 없지만 서버15e143ae에서 실제 누락 경계를 확인했다. 상세 제품/협업 기준은 [설계37 §37.48](../backend-migration/37-raid-scheduling-and-multi-raid-planning.md).

현재 Backend cycle_commands.preflight는 apply에 pending=true로 cycle_admission.admit_bundle(validate_only=true)를 호출하며 그 경로는 core._slot을 건너뛴다. 실제 신청POST도 pending=true다. 그 때문에 확정 참가자와 동일딜러 직업이어도 신청이 생성될 수 있고 승인시에야 ROOM_COMPOSITION_CONFLICT가 발생한다. Flutter 신청UI·body/Controller는 서버 permission 거절을 이미 표시/차단하므로 앱에 멤버전체GET/별도 구성정책을 중복 추가하지 않는다.

다음 담당 Backend: 기존 동일4인파티 딜러직업/역할 구성 검사를 읽기전용으로 재사용해 apply context와 신청POST 양쪽에 적용하고, 현 확정참가자 기준 불가이면 기존 permission/reason·오류를 반환한다. 8인 반대파티 유효배치/기존 승인 재검사·경쟁보호는 유지한다. 대기신청 간 동일직업 금지/자리선점·주간점유/예약 생성/새정원정책은 요청하지 않는다. 직접 구성/위조POST·C/N/반대파티·미점유 경계 검증 후 정확SHA/실행계약·개발반영을 인계한다.

다음 Flutter: 서버 인계 후 기존 reader/button/Controller 거절·요청0과 승인 재검증을 직접 확인하며 필요할 때만 최소 수정한다. 이번은 정책/확인근거·Issue13 서버 수정 요청/문서 보관이며 Dart/서버/DB 코드를 수정하지 않았다. 문서 diffcheck/내용대조만 수행하고 기존126mock/분석은 반복하지 않는다. 다른 정상캐릭터로 가능한 인수는 계속할 수 있으며 dev/main통합/배포는 미완료다.

## 최신 사용자 인수 — 재신청 승인 성공 (2026-10-24)

문서 `184e636c` commit/push. [Issue13 결과6380750571](https://github.com/heo0328/lostparty-backend/issues/13#issuecomment-6380750571)·[Issue24 결과6380750772](https://github.com/heo0328/lostparty-backend/issues/24#issuecomment-6380750772) 게시본문 MATCH 확인. 새 Backend 요청 없이 추가참가자 인수를 계속한다.

사용자 실제 결과: C/N 동시생성·각 주차 단독생성 정상, 생성자 본인 참가방 검색 제외 정상. 최초 신청 승인 실패 보고 뒤 오류문구 확인을 위해 재신청했을 때 **수락 성공**을 확인했다. 사용자는 최초 신청이 동일 직업이었을 가능성을 제시했고 당시 오류문구는 기억하지 못한다. 추가 참가자의 검색 제외/다인 후속 인수 전체를 통과로 확대하지 않는다.

현재 f56aae65/feature/raid-recruitment-scheduling의 UI→review/application GET→decisionBody→원POST/ACK와 Backend15e143ae의 cycle_commands.application/process를 정적으로 대조했다. 승인 permissions는 신청자 selection/targets·현재 자격·주간점유·자리·일정을 재검사하고 거절은 별도 조건이다. 앱은 approve/reject를 같은 사전검증 경로로 처리하되 승인만 일반 cycle ACK를 사용한다. 현재 사용자 오류문구·버튼상태/code/request_id가 없어 실패단계와 원인은 미확정이다. UI가 approve.allowed=false의 reason을 일반 권한안내로 가리는 경로는 확인했지만 실제 원인으로 단정하거나 권한검사를 우회하지 않는다.

추가 확인: Backend15e143ae participation_core._slot은 같은 **4인 파티 내부의 동일 딜러 직업 중복**, 서포터 중복/딜러3석 초과를 ROOM_COMPOSITION_CONFLICT로 거절한다. 8인은 다른 파티의 동일 직업까지 금지하는 조건이 아니다. 선택된 party_no 기준이며 신청대기 자체는 자리확정이 아니다. 이 제한은 현 계약/설계37의 기존 정책이다. 이번 실제 실패가 이 코드였는지는 원요청 근거가 없어 확정하지 않는다.

다음: 추가 참가자의 선택T 검색 제외·내참가/계정i 갱신부터 전체 인수를 계속한다. 같은 파티의 중복 없는 유효한 캐릭터도 승인 실패하면 그때 오류문구·대상T/code/request_id로 단계 구분 후 최소 수정한다. 현재 기능코드/정책·서버/DB 불변, 근거 없는 우회수정/기존126 시험 반복은 없다. 사용자 성공/최초실패 미확정·정책근거를 Issue13, 생성자 검색 통과/추가참가자 미확인을 Issue24에 회신한다. 실기기 전체인수·dev/main통합은 미완료다.

## 다음 단일 작업 — 정상 로그인·전체 디바이스 인수

구현 `0d6d960b` commit/push·원격일치. [Issue24 결과6380382368](https://github.com/heo0328/lostparty-backend/issues/24#issuecomment-6380382368) 게시본문 MATCH 확인. 126mock/분석0·구현범위와 정상로그인/기기 미확인·다음담당을 인계했으며 새 Backend 요청은 없다.

Issue24 구현/직접 자동검증 완료(2026-10-24). 기존 더보기 요청의 서버409/CURSOR_STALE에 같은 실행·회원/환경/실제T/필터로 첫페이지를 최대1회 읽고 기존페이지를 교체한다. 복구 중 로딩/epoch를 유지하고 로컬 무결성 실패·첫페이지/권한·통신오류는 자동 회복하지 않는다. 기존 그룹회복과 재진입하지 않으며 실제영향T 캐시 무효화는 보존했다. 상세 근거는 [설계37 §37.47](../backend-migration/37-raid-scheduling-and-multi-raid-planning.md)·DEV_LOG다.

검증: 직접4파일 단일126mock PASS(신규20 포함), 변경Dart3파일 분석 중 style1건 수정 후 해당시험파일 재분석 최종0, 포맷/diffcheck/diff검토. 기존 C의413과 합산하지 않는다. 실제 로그인 개발API/실회원·기기/성능은 미실행이다. 다음은 아래 전체 연결 인수 순서이며 별도 기능 구현을 먼저 완료했다고 확대하지 않는다.

사용자 담당: 가입 전 검색/선택T 참가 방 제외·탈퇴 뒤 재노출 → 단독/C+N 생성·상세/새생성 → 내참가/계정i/기록 → 다인 참가·일정 → 탈퇴·승계·혼합권한 해산 → 재참가 후 옛기록/회원·주차 전환, 폴드/큰글자. 조건이 없는 행은 미충족으로 남기고 서버/DB/가짜인증으로 만들지 않는다. 재현 차이는 기대·실제/대상T/code/request_id로 분류해 필요한 최소 수정과 같은Issue 회신을 한다. BUG-025는 별도 미확정 조사이며 릴리즈 전 필수 수정 여부를 판단한다. recover_leadership UX·IF-001 비활성·dev/main 미반영 유지, 이번 준비/구현은 작업브랜치 보관이다.

## 완료 구간의 구현 기준 — Issue24 (2026-10-24)

사용자 ‘1번 구간 작업 준비’ 후 ‘작업 진행합니다’ 지시로 준비 커밋 `9fc30912`에서 아래 한 구간을 구현·검증했다. 최신 Issue24 댓글6371617690/API176·DB0031을 재확인했으며 추가 Backend 구현 대기는 없다. 아래는 구현 기준이며 다음 미구현 작업 목록이 아니다.

### 근거·소유와 현재 차이

- 현재 `feature/raid-recruitment-scheduling`·기준 `55547375`와 origin 일치, dev/origin/dev `6d3f6170` 미통합. 기존 통계35·플랫폼 생성·DevTools/백업/tools dirty는 보존한다.
- [Backend 최신 개발 인계6371617690](https://github.com/heo0328/lostparty-backend/issues/24#issuecomment-6371617690): source `15e143ae`/반영 `920cc059`·API176/DB0031. 추가 Backend 구현 대기는 없다. 선택 실제T/현gen 본인 participating/review+활성Member 제외는 서버 SQL 페이지 전 책임이며 앱은 기존 search 요청/응답·필터·정렬/집계를 그대로 소비한다. 새flag/선행 본인목록GET/카드별GET·앱 후처리 제외는 추가하지 않는다.
- `CycleSearchViewModel`이 화면 수명의 rows/cursor/digest·(T,filter.signature) 메모리 캐시/epoch를 소유한다. 실제 `cycleScopeKey`는 API환경/회원/세션generation/readGeneration이다. Repository는 기존 읽기 POST `/v2/raid-rooms/search`와 엄격 parser를 담당한다. 새 계층/공용 저장소/의존성은 필요 없다.
- 현재 search의 CURSOR_STALE은 rows/cursor/캐시 폐기+오류 표시까지만 한다. 서버 만료뿐 아니라 로컬 반복cursor/digest 불일치도 같은 code로 만든다. **서버 HTTP409 만료 회복과 로컬 응답 무결성 실패를 구분**해야 기존 잘못된 응답 거절을 약화시키지 않는다.
- `CycleParticipationController.changed`의 실제T mutation은 해당T 모든 필터 캐시를 폐기하고 선택T만 refresh한다. 생성은 createdTargetKeys별, 새 탈퇴/해산은 실제 affectedTargets별로 통지한다. effects=[]의 관계종료는 B의 내목록/계정 갱신이며 가짜 검색 영향T를 만들지 않는다. 현재 연결을 재작성하지 않는다.

### 구현 범위·처리 순서

1. 검색 실행의 회원/환경 scope·epoch·실제T·필터를 고정한다. 더보기의 기존 cursor를 보낸 요청이 **서버 status409/code CURSOR_STALE**로 실패했고 같은 실행이 유효할 때만 자동 회복한다. cursor 없는 첫페이지 실패, 로컬 반복cursor/페이지digest 불일치·INVALID_RESPONSE, 다른scope/위조 INVALID_REQUEST400·권한/통신오류·CYCLE_CHANGED는 자동 회복하지 않는다.
2. 만료된 검색의 rows/cursor/digest/커서 방문집합과 해당 (T,filter.signature) 캐시를 먼저 폐기한다. 같은 고정T/필터로 cursor=null인 첫페이지를 **최대1회** 요청하고 성공한 새 페이지로 교체한다. 구페이지 이어붙이기/다른T 이동·필터 초기화/주차 메타GET/재귀 무한 재시도는 없다. 로딩은 회복을 포함한 한 실행 동안 유지해 더보기/갱신 중복을 막는다.
3. 기존 그룹 후보/필터context 재획득과 검색cursor 회복을 별도 원인으로 구분하되, 한 사용자 검색 실행에서 자동 회복들이 서로 재진입해 무제한 요청을 만들지 않게 공통 실행 경계에 묶는다. 단순 검색cursor 만료는 후보/context를 추가 조회하지 않는다. 후보 실패·재획득/selectionPending의 기존 안전 조건은 보존한다.
4. 회복 실패는 최신 오류를 기존 오류/재시도 UI로 표시하고 비운 목록/커서를 유지한다. 사용자의 명시 갱신은 별도 실행이다. 회원/환경/readGeneration 변경·로그아웃, 필터/주차 선택·mutation 갱신·dispose가 실행을 무효화하면 이전 응답과 finally가 새 rows/loading/failure를 변경하지 못한다. scope 변경 뒤 회복 요청을 시작하지 않는다.
5. 기존 실제영향T 캐시 무효화와 선택T만 refresh를 보호한다. C/N 양쪽 효과·숨은 반대T·여러 필터 캐시와 진행 중 조회를 검증한다. 주차 경계의 CYCLE_CHANGED를 다른 실제T로 자동 치환하지 않으며 기존 메타/선택기 갱신 흐름을 사용한다. 타기기 실시간push/새 자동 polling은 추가하지 않는다.

### 회귀·검증과 완료 조건

- 주 변경 후보: `cycle_search_view_model.dart`, 직접 경계 `cycle_interaction_test.dart`; 그룹 회복 전파가 있으면 `group_character_candidates_test.dart`. 실제 화면/Repository/Controller/Router는 필요한 근거가 없는 한 수정하지 않는다.
- 자동 표적: 서버409 더보기→첫페이지1회/요청T·필터 동일/구행 미병합, 첫페이지 재실패와 일반오류 재시도0, 로컬 반복cursor·digest 오류 기존 거절, 회복 중 회원/환경·실제T/필터 전환·늦은응답/dispose, 중복 더보기, 영향T 캐시만 폐기·다중T 알림/구조회 격리, 그룹context/후보 회복의 유한 경계.
- 최종 직접 영향 묶음은 `cycle_interaction_test.dart`·`group_character_candidates_test.dart`·`membership_actions_test.dart`·`membership_presentation_test.dart`를 기본으로 한다. 신규 실행 전 기존 시험과 중복을 검토하고 변경이 직접 전파된 파일만 확대한다. 변경파일 분석·포맷·diffcheck/diff리뷰를 수행한다. 저장/공용Domain/Router·서버계약은 불변이므로 전체 Flutter 시험/분석 반복은 기본값으로 하지 않는다.
- 사용자 정상 디바이스 확인은 이번 코드 구간 종료 후 전체 연결 인수에 묶는다: 선택T 참가 방 검색 제외/탈퇴 뒤 기존조건에 따른 재노출, 반대T 보존, 필터/정렬·더보기/갱신, C/N·회원 전환. 자동/mock 통과를 정상 로그인 개발API/실회원·실기기/성능 통과로 표현하지 않는다.
- 구현 종료 후 문서 최신화·작업브랜치 commit/push·Issue24 결과 회신/게시본문 확인. 추가 Backend 요청은 실제 계약 차이/재현이 있을 때만 한다. 이번 준비 자체는 새 서버 요청/반복 시험 회신을 만들지 않는다.
- 제외: Issue25 기록/명령 재구현, recover_leadership 실행UX, IF-001 활성화, BUG-025 수정, 시간picker 재디자인, 서버/DB/디바이스 조작·dev/main통합/배포. 준비 완료는 구현/인수 완료가 아니다.

## 현재 상태 (2026-10-24)

## 별도 후속 등록 — 자동 빌드 갱신 완료·카드 표시 일치

사용자 요청으로 [BUG-025](BUG_REPORTS.md#bug-025-최초-자동-빌드-갱신-완료-후-캐릭터-카드-전투력-미표시-2026-10-24-후속-조사ux-검증-대기)에 최초 빈 캐릭터의 자동 갱신 완료/전투력 미표시 관찰과 자동·수동 경로 차이, 조사/UX 정의·테스트/필요 시 최소 수정 순서를 등록했다. 원인은 미확정·코드수정/실기기 재현은 미실행이다. 저장 성공뿐 아니라 카드 반영·완료 안내/실패·재시도까지 검증하고, 릴리즈 인수에서 필수 수정 여부를 판단한다. 이번은 문서 등록만이며 아래 B 구현을 진행한 것이 아니다. 상세는 BUG-025가 단일 기준이고 기존 B/C·24후속과 IF-001 비활성은 유지한다.

## 완료 구간 B — 실제 메뉴·성공 화면·관계 종료 알림

구현 `0487788a` commit/push·원격일치. [Issue25 결과6372783376](https://github.com/heo0328/lostparty-backend/issues/25#issuecomment-6372783376) 게시본문 MATCH를 확인했다. 실제 UI 연결/295mock·분석0과 C/24후속·정상로그인/실기기 미확인을 구분해 인계했으며 새 Backend 요청은 없다.

기존 설계/Issue25 최신6371981415까지 확인해 B를 구현했다. 실제 상세의 기존 두 탈퇴/해산 버튼은 이제 전용 menu option별 visible/permission·최신 Impact 확인과 A의 원명령을 사용한다. 현재T 본인관계 또는 지속관계 종료는 원key당1회 선택T 내목록으로 복귀하고, 반대T만 해산해 현재참가가 남으면 현재상세를 유지한다. effects=[]도 별도 관계종료 이벤트로 C/N 내목록/계정을 갱신하며 가짜T효과를 만들지 않는다. 계정 갱신은 이미 실제효과로 요청한 T를 중복 요청하지 않고 한도는 기존 신규명령 context의 서버 원본을 사용한다.

직접10파일 고유295mock PASS(178+별도116+신규1; 마지막추가 뒤 membership49만 재확인·중복합산 없음), 변경Dart9파일 최종분석0·포맷/diffcheck/리뷰. 원pending/구명령·완료/추방/개인완료탈퇴/읽기전용·IF-001 비활성, 중앙탈퇴/기존빨간해산폭을 보존했다. 세부 결과/근거와 실회원·실기기 미확인은 [설계37 §37.45](../backend-migration/37-raid-scheduling-and-multi-raid-planning.md)와 DEV_LOG가 기준이다. 현재 feature/raid-recruitment-scheduling 유지·기존무관dirty 보존·dev/main 미반영, 구간 commit/push로 보관한다. Backend source15e143ae·API176/DB0031과 계약 차이/새차단 요청은 없다.

## 완료 구간 C — 명시 조회·본인 기록 연결

구현 `0c5ae941` commit/push·원격일치. [Issue25 결과6373322164](https://github.com/heo0328/lostparty-backend/issues/25#issuecomment-6373322164) 게시본문 MATCH 확인. 실제 C연결/413mock·분석0과 가입 전 기본조회 보존·실회원/기기 미확인·24검색후속을 인계했으며 새 Backend 요청은 없다.

사용자 승인 계획을 먼저 기록하고 상세/일정/내목록의 전용 불변 profile·Member+CM 기록 anchor/Router·캐시/표시를 연결했다. 정상 content는 기존 parser를 재사용하며 새profile 오류의 기본조회 fallback은 없다. Backend profile은 활성Member 전용이므로 내참가/기록·계정i·생성 성공/자기충돌처럼 소속확정 진입에만 명시하고, 가입 전 검색 상세 기본조회/신청·쓰기용reader·원pending을 보존했다.

현재 참가/복구상태와 고정 자기기록을 분리하고 같은Member 재참가CM을 별도 행으로 유지한다. 기록은 당시 캐릭터/레이드·완료/종료·본인 일정만 읽고 신규menu/preview/write0, 일정도 같은anchor다. 정확기록은 주차 전환 뒤 유지되며 관계만 있는 행에는 가짜기록 링크를 만들지 않는다. B 성공1회이탈/반대T 유지·관계알림·IF-001 비활성을 보존했다.

직접14파일413mock PASS(신규49 포함·이전295 합산 없음), 변경Dart14파일분석의 style9건 수정 후 해당3파일 재분석 최종0·포맷/diffcheck/리뷰. 실제기록위젯/일정2GET·신규쓰기0을 포함한다. 상세 근거/회귀·원설계 중복CM 예시의 거절·현재/기록식별자와 실회원 미확인은 [설계37 §37.46](../backend-migration/37-raid-scheduling-and-multi-raid-planning.md)/DEV_LOG가 기준이다. 현재 feature/raid-recruitment-scheduling 유지·무관dirty 보존·구간commit/push, dev/main 미반영이다.

## 별도 다음 구간 — Issue24 검색 회복 / 전체 사용자 인수

Issue25 A/B/C 코드·직접경계 자동검증을 연결했으며 정상 로그인 개발API·실회원/실기기/성능 인수는 미확인이다. 다음은 별도 승인 구간에서 Issue24의 기존 검색 CURSOR_STALE 시 동일 회원/환경·실제T·필터를 보존한 첫페이지 제한 회복과 캐시 무효화를 점검/연결한다. 구페이지 이어붙이기·반복재시도·필터초기화/다른주차 이동은 하지 않는다. 설계37 §37.43과 실제 검색 ViewModel을 다시 대조하고 최신 Issue24부터 확인한다. 이번 C에 검색 코드를 섞지 않았다.

전체 연결 인수는 가입 전 검색/단독·C+N생성→내참가/계정i→정상상세/일정→B 탈퇴·혼합권한해산/승계→기록·재참가/그룹탈퇴→회원/주차전환과 폴드/큰글자 순서로 사용자에게 묶어서 전달한다. 자료/시각이 없는 실제복구·다인/전환 행만 조건 미충족으로 구분하며 서버/DB 조작·가짜인증으로 만들지 않는다. 실제차이는 대상T/기대·실제/오류code·request_id로 분류하고 관련 Issue에 회신한다. 기존 자동검증을 변화 없이 반복하지 않는다.

recover_leadership 실행UX는 제품 승인 전 제안, IF-001은 비활성이다. BUG-025와 통계/기타 기능·모집pending 영속화·새과거주차검색은 별도후속이며 dev/main통합·배포는 인수/필수결함 판정 전 수행하지 않는다.

## 완료한 A의 설계·보존 범위 — Issue25 전용 context·원명령·ACK

사용자 진행 승인. Backend 구현15e143ae/반영920cc059, [24 개발반영6371617690](https://github.com/heo0328/lostparty-backend/issues/24#issuecomment-6371617690)·[25 개발반영6371618996](https://github.com/heo0328/lostparty-backend/issues/25#issuecomment-6371618996)의 API176/DB0031 인계로 아래 과거 Backend미구현/미반영 대기는 해소됐다. 첫 독립 그룹은25 전용 모델/엄격 검증·Gateway/Repository·기존app-owned Controller 원요청복구 연결이다. 현재branch d555f2a8 재사용·기존무관dirty 보존. 생성/계정·구cancel/leave/end/D22/E23 원transport/ACK·24h/IF-001 비활성을 회귀보호한다.

데이터/권한은 서버 context option/Impact가 원본이며 클라이언트는 선택옵션/actor/room/C/viewT·대상T/gen/ID/상태·revision규칙과 원ACK 일치만 검증한다. 확인후 최신context 재조회·선택옵션의 의미변경은POST0, token/발급시각만변경은새token으로발급. 원본문/key/Impact는 메모리pending에고정하고 retry는GET없이원명령만재송한다. 새endpoint를 구end/leave 또는 순차요청으로 치환하지 않는다.

순서: 실행schema/합성DB예시 대조 → 불변Context/선택preview·전용ACK검증 → 현재DI의 Repository/Gateway·Controller 연결 → 원ACK/변조/옵션격리·혼합역할/빈effects/회원전환/중복/유효기한·직접기존 경계 묶음검증 → 문서·Issue25 인계/commit/push. 실제버튼/성공화면·관계종료알림은 B, profile/기록Router는 C, 검색커서/캐시는24 독립후속이다. A에서 성공사건은 원결과를 별도로 보관하고 빈effects에 가짜T알림을 발생시키지 않는다. 따라서 A완료를 정상버튼/빈effects 화면갱신까지 완료로표시하지 않는다.

완료조건은 전용 HTTP 원명령/ACK·기존pending회귀 시험/변경파일분석·포맷/diffcheck와 코드리뷰·문서/원격보관이다. 저장/Router/사용자UI/서버권한 불변으로 표적시험을 사용하고 무관전체시험/실회원쓰기·기기조작/서버·DB/dev/main통합은 제외한다. recover_leadership은 계약검증만 보존하며 제품UI는 제안상태다.

## 다음 작업 — Backend 구현·실행 계약 인계 확인

24/6369761914·25/6369762510(합성 예시6369763243/6369763925)의 보완 계약을 현재 bce1f0d7의 검색/상세/실제 Router·원명령/ACK·목록/기록과 대조했다. 기존 네 소비 차이는 해소됐고 추가 차단 계약 요구는 없다. [24 검토6370137482](https://github.com/heo0328/lostparty-backend/issues/24#issuecomment-6370137482)·[25 검토6370138718](https://github.com/heo0328/lostparty-backend/issues/25#issuecomment-6370138718) 게시본문 MATCH. 상세는 [설계37 §37.43](../backend-migration/37-raid-scheduling-and-multi-raid-planning.md)이며 아래 과거 ‘계약 보완 대기’보다 이 상태가 우선한다. 새 기능/실행 OpenAPI·개발API/DB 반영 인계는 아직 없으며 37개 예시는 합성 설계 자료다.

다음 Backend: 정의한 구현 구간의 정확 SHA/push·실행 OpenAPI/개발API·DB 여부/대표 실제 응답·직접 검증 결과를 인계한다. 이미 수용한 정책/합성 예시 검증을 반복 요청하지 않는다. 다음 Flutter는 그 인계와 구현 지시 후 (1)24 기존검색 갱신/제한된 커서 회복 (2)25 전용 DTO/원명령·ACK (3)실제 menu/성공1회 이탈·반대T만 해산시 현재화면 유지·빈effects 관계종료 알림 (4)명시 profile/옛 기록 anchor Router 연결을 독립 검증 단위로 구체화한다. old pending/24h ACK·일반 일정/완료·기존 readonly·회원/T 격리·IF-001 비활성은 보존한다. 복구 UI는 제안이며 추가 상시버튼/필수단계로 승인된 것이 아니다.

이번 검토 완료 조건은 문서 diffcheck/소비 근거 대조·각 Issue 게시본문 재조회·작업브랜치 commit/push다. 기능코드/API/의존성 변경·반복 Flutter 시험/분석·서버/DB/기기 조작·dev/main 통합은 제외했다. 기존 N단독 생성 수정본·추가 인증 회원이 필요한 다인 실기기 인수와 IF-001 숨김 확인은 유지한다.

## 최신 완료 구간 — 미완료 종료·같은 주차 재개 비활성화

구현 `ddf4bfd0` commit/push·원격일치. [Issue13 최종 정책6370006371](https://github.com/heo0328/lostparty-backend/issues/13#issuecomment-6370006371) 게시본문 MATCH 확인. Backend에는 활성 기능 문서의 비활성 보존 분리만 인계했고 endpoint/기록 삭제·새24/25 범위 확대는 요청하지 않았다.

구현/직접 검증 완료: 앱 기본 컨트롤러에서 버튼/전용 신규 조회·preview·쓰기를 차단했고 기존 원pending 재송은 보존했다. outcome/resume/schedule/departure 4파일119mock PASS(신규3+기존116), 변경Dart6파일분석0·포맷/diffcheck. [비활성 기능 대장 IF-001](INACTIVE_FEATURES.md) 신설·문서 지도/제품 흐름 연결 완료. 실서버/실기기 숨김·정상 기능 인수는 사용자 확인 대기이며 다음 담당은 기존 Backend24/25 계약 보완이다. 구간 commit/push로 보관하고 dev/main 통합은 제외한다.

사용자 최종 결정으로 다일 일정에도 미완료 종료/같은 주차 재개를 사용하지 않는다. 아래 §37.41 당시의 ‘다일만 노출/삭제 보류’보다 이번 결정이 우선한다. 구현은 보존하며 앱 버튼과 전용 신규 조회·preview·쓰기 진입을 막는다. 기존 원pending 재송/ACK·기록 조회는 유지한다. 일반 일정 변경, 완료/개인완료, 다음주 개방·탈퇴/해산은 별개다.

순서: 현재 호출 경계 확인 → 컨트롤러 기본 비활성 및 UI 공통 진입 차단 → 신규 요청 0건/기존 pending 복구와 완료 보존의 직접 경계 검증 → 비활성 기능 대장 신설·설계/흐름/문서 지도 연결 → Issue13 정책 변경 인계·구간 commit/push. 기존 전용 대장은 확인되지 않아 `INACTIVE_FEATURES.md`를 신설한다. 서버 endpoint/자료 물리삭제, 새 탈퇴 계약 구현, dev/main 통합·실기기 조작은 제외한다.

회귀 보호: 현재/다음주·회원 격리, 일반 완료·개인완료후탈퇴, 일반 일정 변경·다음주 개방, 기존 원요청 복구/읽기 전용 기록과 직전 버튼 정렬/해산 폭. 공유 저장/Router 변경 없이 직접 영향 시험·변경파일 분석/포맷/diffcheck로 검증하며 사용자에게 버튼 숨김/정상 완료·일정의 실기기 확인을 넘긴다.

## 최신 UI 결과 — 탈퇴 중앙 정렬·해산 폭 확대 / 미완료 종료 다일 제한

구현 `e25e7ca2` commit/push·원격일치, [Issue13 결과6369674584](https://github.com/heo0328/lostparty-backend/issues/13#issuecomment-6369674584) 게시본문MATCH. 다음은사용자UI확인과기존24/25계약보완수신이다. 새다일서버권한/기능삭제·새탈퇴명령연결이아닌UI표시변경임을인계했다.

구현/검증 완료: 상세탈퇴 Wrap 중앙/줄바꿈 중앙, 해산 가로padding32/폭약20%확대, 확정KST출발일2개이상에서만 기존 미완료종료 노출. 관련2파일35mock PASS(새1+기존34)/변경Dart3파일분석0·포맷/diffcheck. 삭제검토/보존·근거는 [설계37 §37.41](../backend-migration/37-raid-scheduling-and-multi-raid-planning.md)·DEV_LOG. 실기기배치/큰글자·폴드/실제다일표시·기존중단재개는사용자확인대기다. Backend24/25 계약보완대기는아래와같이유지하며UI구간은작업브랜치commit/push로보관한다.

사용자 요청으로 상세 하단의 이번주(선택N이면 다음주) 탈퇴/모두탈퇴를 가운데 정렬하고 해산 버튼 가로 여백을 늘려 기본 폭 대비 약20% 확대한다. 기존 위치·색/텍스트·아이콘·글자 크기/터치·원명령은 유지한다. Backend25 새 동작/권한/노출 계약을 먼저 구현한 것으로 표시하지 않는다.

미완료 종료는 본인 탈퇴와 달리 파티 전체 남은C 진행/예약을 중단하고 같은C 재개를 가능하게 하므로 완전 삭제하지 않는다. 이번 UI는 서버 confirmed_starts_at의 **KST 출발일이 둘 이상**인 실제 다일 일정에서만 기존 미완료 종료를 노출한다. 후보중1회·날짜미정/단일일자/같은날복수타임/한타임익일종료를 다일로 추정하지 않는다. 새 판정 때문에 plan 추가GET/로컬 생성초안 참조·서버권한 복제는 하지 않는다. 기존 C/수10시/함께하기/실참가 조건과 미완료종료의 전체영향/확인·원pending·재개는 유지한다. 삭제 가능성·새탈퇴/해산과 차이는 설계37 후속절에 남긴다.

회귀 보호: 기존 버튼 콜백/권한·C/N/회원 격리, 완료/개인완료후탈퇴·중단/재개·원요청복구/읽기전용 기록. 검증은 KST 날짜 경계의 좁은 predicate 시험+직접기존 outcome 경계, 변경파일 포맷/분석·diffcheck를 묶고 정상 배치/폴드·큰글자는 사용자 담당이다. 공유 저장/Router/서버계약 불변으로 무관전체시험 생략. 완료 후 UI/정책·제한을 문서/관련Issue에 필요한 범위로 인계하고 작업브랜치 commit/push, dev/main 통합 제외.

## 병행 대기 — Issue24·25 소비 검토 완료 / Backend 계약 보완 대기

사용자 ‘진행합니다’로 [Backend137 설계 인계6368822874](https://github.com/heo0328/lostparty-backend/issues/13#issuecomment-6368822874)와 Issue24/25 설계안1을 실제 Router/DI·검색/캐시·상세/원명령·review/종료회원 기록과 대조했다. [24 회신6369170940](https://github.com/heo0328/lostparty-backend/issues/24#issuecomment-6369170940)/[25 회신6369171307](https://github.com/heo0328/lostparty-backend/issues/25#issuecomment-6369171307) 게시본문 MATCH를 확인했다. 상세 판단·코드 근거는 [설계37 §37.40](../backend-migration/37-raid-scheduling-and-multi-raid-planning.md), 완료 이력은 DEV_LOG를 따른다. 기존174경로/DB0030·Dart/API/원pending/시험 결과는 유지한다.

- 다음 Backend: #24 기존검색shape/semantics·CURSOR_STALE·directory head 경계를 고정한다. #25 menu 옵션별 접근격리(현재T미참가/반대T리더 포함), Impact→ACK의 후상태/revision 규칙, review/null리더의 명시 reader·표시근거, 종료회원 자기기록 detail/plan/목록의 closed wire/대표예시·기존클라이언트 호환을 보완하고 구현 구간을 고정한다. 이미 확정한3행동/동일시험 재수용 대기가 아니다.
- 다음 Flutter: Backend 보완 수신 시 위 차이 해소 여부 검토. 구현 승인·정확한 인계 후 기존검색의 제한된 첫페이지 회복/영향T 캐시와 새전용6필드/ACK·빈effects 회원관계종료/1회이탈·복구/기록 reader를 연결한다. 복구 기능은 기존3행동의 필수단계로 만들지 않고 기존 review 안내 영역의 명시진입 UX 제안으로 남긴다. 제품/UI 최종 승인과 기술적 소비가능을 구분한다.
- 완료 조건/제외: 이번 문서 구간은 diffcheck/내용·호출대조와 각Issue 회신/본문재조회·commit/push로 보관한다. 미합의 endpoint 호출/기능코드·서버/DB/기기조작·반복 전체시험·dev/main통합 없음. 새기능 구현/DB반영 승인은 별도 단계다. 기존 N단독 생성 수정본/다인 실기기 조건 대기도 유지한다.

## 직전 확정 그룹 — 탈퇴·해산 제품 정책 갱신

사용자 최신 지시와 추가 답변으로 확정했다. 상세 단일 기준은 [설계37 §37.39](../backend-migration/37-raid-scheduling-and-multi-raid-planning.md)다. 기존 ‘공대장 사전위임 필요/마지막1인만 해산/다인해산 제외/버튼 숨김 제안’은 이 구간의 최신 정책으로 대체하며, 이전 구현이 이미 변경된 것으로 표시하지 않는다.

[Issue13 정책 갱신6367266418](https://github.com/heo0328/lostparty-backend/issues/13#issuecomment-6367266418)에 확정 범위/이전 요청 대체·원pending 보존·담당/완료조건을 전달하고 게시본문 MATCH를 확인했다. 다음 담당은 Backend의 새 계약/구현·검증/실행 인계이며, Flutter는 기존 명령의 효과를 임의 변경하지 않는다.

- 이번주/다음주 탈퇴: 보고 있는 주차의 본인 참가만 종료. 공대장이면 남은 주차 참가 순서로 자동 승계, 아무도 없으면 해당 주차 종료. 반대 주차 유지. C도 허용하고 사전 위임·인원수를 탈퇴 거절 조건으로 삼지 않는다.
- 모두 탈퇴: 본인의 C/N 관계를 한 명령으로 종료하면서 각 주차 독립 자동 승계/빈 주차 종료. 어느 주차의 공대장이든 사전 위임을 요구하지 않는다.
- 모집 해산: 본인이 공대장인 C/N 주차 전체가 고정 대상. 양쪽 공대장이면 양쪽, 한쪽만 공대장이면 그 주차만. 다인 가능·전체 참가자 탈퇴/점유·예약 정리, 반대 비공대장 주차의 본인/타인 참가 유지. 확인창에 실제 대상 날짜·‘해산 대상 주차의 모든 파티원이 탈퇴 처리됩니다.’ 표시. 과거 완료/감사 기록 물리삭제나 완료처리는 하지 않는다.
- 노출: 참가관계가 있는 상세의 두 탈퇴 버튼은 인원수·승계 가능 여부로 숨기지 않는다. 해산은 C/N 중 공대장 주차가 있으면 표시하며 마지막1인 조건을 제거한다. 기존 위치·빨강/흰글씨 단독 해산 버튼은 유지. 중복요청/확인 중 권한·대상 변경 방어는 유지한다.
- 순서/담당: 문서·Issue13 최신 정책 인계 → Backend의 원자 명령/context·정확한 영향 주차/승계/권한·기존 원pending/ACK 호환 설계 및 구현/검증·실행SHA 인계 → Flutter DTO/버튼 노출/확인/성공이동·주차별 캐시 갱신/직접 경계 검증 → 사용자 기능 섹션 인수. Backend 계약 없이 기존 end/leave를 새효과로 호출하거나 두 취소POST를 순차 실행하지 않는다.
- 완료 조건: C/N 각 단독/양쪽·공대장 역할 혼합·마지막1인/남은참가자·동시탈퇴/승계/review 경계·해산 대상 권한변경/원ACK/타주차·완료근거 보존을 계약/시험과 대조한다. 정상 UI는 사용자 실기기에서 확인한다. 이번은 설계·인계 전용이라 Dart/API/의존성 불변·Flutter 시험 반복 없음, 문서 diffcheck/내용 대조 후 commit/push. dev/main 통합·서버/DB/기기조작 제외.

검색의 본인 참가 방 SQL 페이지 전 제외 요청과 수정본 N 단독 생성 사용자 재확인, 추가 인증 회원이 필요한 기존 인수 조건 미충족은 별도 그대로 유지한다.

## 직전 구간 — 2차 실기기 피드백 원인 확인·N 단독 생성 복구

구현 `407328ef` commit/push·원격 일치. [Issue13 회신6366977367](https://github.com/heo0328/lostparty-backend/issues/13#issuecomment-6366977367)에 N 원인/21mock·분석0·실기기 미확인과 검색 SQL 제외/C 탈퇴 보완의 담당·완료조건을 인계하고 게시본문 MATCH를 확인했다. 다음 담당은 Backend 계약/구현 인계이며 앱 수정본 N 단독 생성은 사용자 재확인 대기다.

- 사용자 결과: 1번 통과(개별 세부 항목까지 확대하지 않음), C 단독/C+N 생성·마지막1인 모집 해산 정상. N 단독 생성은 일반 오류, 참가한 방이 모집 검색에 노출됨. 추가 인증 원정대/회원이 없어 가입·다인 탈퇴/승계 인수는 조건 미충족이다.
- 확인 근거: Backend0eed67c4 cycle_creation.preflight 및 test_n_target_does_not_create_third_week는 continuation=false인 N도 effect=target_only다. 앱 context/ACK·합성 fixture는 N이면 target_is_next로 잘못 가정했다. 기존 C/C+N·원요청 재송·실제T/C+14 방어를 보존하며 N 단독의 효과 검증/fixture를 고친다. Repository HTTP 회귀와 잘못된 effect 거절을 추가하고 cycle_recruitment_test·변경파일 분석/포맷/diffcheck를 한 번 묶는다. 공용 저장/Router/권한 불변으로 전체시험은 생략한다.
- 검색 제외는 서버 SQL 페이지 전 실제 선택T의 본인 CycleMember 참가를 제외하는 방향으로 요청한다. 로컬 목록/캐시·페이지 이후 필터로 대체하지 않으며 반대T 참가만으로 숨기지 않는다. Backend 인계 후 소비/실기기를 확인한다.
- 탈퇴 불일치: cycle_leadership.prepare_cancel은 next_only=True여서 C는 TARGET_CYCLE_NOT_FUTURE로 거절한다. N 마지막1인은 close_target 허용, 전역 leave는 열린 주차 리더일 때 LEADERSHIP_RESOLUTION_REQUIRED이며 end는 전체 마지막1인 조건이다. 기존 문서의 C/N 주차탈퇴 공통 설명과 실제 C 버튼이 서버와 다르다. Backend에 C 단일탈퇴/승계·마지막T종료 계약 보완을 요청하며 임의로 end/완료 연속명령으로 치환하지 않는다. 탈퇴/해산 버튼 숨김·통합은 별도 UX 제안으로 남기고 승인 전 재배치하지 않는다.
- N 단독 생성 수정·직접21mock PASS(신규2+기존19)·변경2파일 분석0/포맷/diffcheck 완료. 원인/소비 근거·회귀는 설계37 §37.38에 기록했다. 사용자 수정본 N 단독 생성 인수는 아직 미확인이다. 아래 과거 합동 인수 대기와 함께 검색 제외/C 탈퇴 Backend 보완을 추적한다. 정확SHA·결과/미확인은 Issue13에 회신하고 문서·작업 브랜치 commit/push로 보관한다. 서버/DB/기기 조작·dev/main 통합은 제외한다.

설정 회원 ID 표시·복사 UI 구현 완료. 사용자 ‘1. 통과’는 보고한 범위에서만 수용하며 로그아웃/복원·큰글자 등 세부 항목 전체 통과로 확대하지 않는다. 기존 인증 상태/로그인/저장/API 계약은 유지했다. 상세는 DEV_LOG를 따르며 아래 합동 인수 대기를 유지한다.

사용자 신규계정 인수 피드백 반영 완료: 내 계정 ‘계정 도구’의 원정대 등록·관리 진입을 첫 줄의 전체 폭 단독 FilledButton.icon으로 변경했다. 기존 onManage/Router·등록·인증/저장 흐름과 다른 도구는 유지한다. 아이콘24·최소높이48/가변 텍스트 높이를 사용한다. 포맷/해당파일 분석0/diffcheck·호출연결 검토 완료, 실기기에서 신규/기존계정의 버튼 표시·터치/기존관리 진입·폴드/큰글자 확인은 사용자 담당이다. API/권한 변경이 없어 Backend 계약 요청과 정상 UI 자동시험은 추가하지 않았다. 아래 합동 인수 대기를 유지한다.

B 구현 `797c16b3cfcffda849428593fe6c12502eb27499` commit/push·원격 일치 후 [Issue13 결과6364976336](https://github.com/heo0328/lostparty-backend/issues/13#issuecomment-6364976336)에 소비계약/159mock·분석0/미확인·합동인수 순서를 회신하고 게시본문 MATCH를 확인했다.

A 구현 `e9d2783d51ba079c0a3fe6ae88f5a4099b58978a` commit/push·원격 일치 후 [Issue13 결과6364089791](https://github.com/heo0328/lostparty-backend/issues/13#issuecomment-6364089791)에 계약/94mock·분석0/미확인·다음 B를 회신했다. 한도로 중단됐던 게시본문 재조회도 재개해 MATCH를 확인했다. 코드 변화가 없어 통과한 시험은 반복하지 않았다.

E23 구현 `b6720079b363703d49c0a43e5f78142b1849ed34` commit/push·원격 일치 후 [Issue23 결과6363846643](https://github.com/heo0328/lostparty-backend/issues/23#issuecomment-6363846643)에 사용 계약/검증·실회원/기기 미확인·다음 A/B를 회신하고 게시본문 MATCH를 확인했다.

D22 구현 fece2003·[Issue22 결과6363334658](https://github.com/heo0328/lostparty-backend/issues/22#issuecomment-6363334658)에 이어 E23 현재/양T 참가자 추방을 구현했다. Backend 소비0eed67c453040b332653fd2071e6cd2e1eeed503/174경로·DB0030이다. 카드 빨간 X의 고정대상·option별 권한/의미 재확인·원명령/전용 ACK·현재 탭 유지·효과T별 갱신이 연결됐다. **관련6파일 고유178mock PASS(신규45+직접기존133)·lib/test분석0**. 구현/검증 상세는 [설계37 §37.35](../backend-migration/37-raid-scheduling-and-multi-raid-planning.md)·DEV_LOG를 따른다. 실회원/기기 인수는 미확인, dev/main 미반영이다. 아래 과거 E23 설계/계약대기 문구보다 이 상태가 우선한다.

## 다음 첫 그룹 — 사용자 실기기 합동 인수

사용자 진행 승인으로 B를 구현했다. [설계37 §37.37](../backend-migration/37-raid-scheduling-and-multi-raid-planning.md)의 current/ended·review 복구·보관 회원 기록 소비/읽기전용 진입 연결, **관련7파일159mock PASS(신규19+직접기존140)·lib/test분석0**이다. D22/E23/A/B 코드와 직접 자동 경계는 완료됐으며 정상 실회원 HTTP/기기 인수는 미확인이다. 기존 아래 B미완료·계약대기 문구는 이 상태가 우선한다.

다음은 사용자 직접 설치/기기 조작으로 아래 기능 섹션을 확인한다. 기존 전체 인수표 §37.24의 준비조건/미실행 항목을 유지하며 이미 정상 확인한 레벨/최고난이도·신규생성 재진입을 다시 미확인으로 돌리지 않는다. 에이전트는 기기 조작/실회원 쓰기를 자동 실행하지 않는다.

| 순서 | 사용자 확인 | 기대 결과 |
|---|---|---|
| 1 | C/N 참가중·신청중·기록 | 실제 선택T 참가/복구만 참가중, 완료/탈퇴/중단은 기록, 단순미선택은 참가이력 없음·다른T 보존 |
| 2 | 전체완료/N없는 방의 기록 상세·일정 | 참가중/검색에서 제외·기존 회원 기록 열람 가능, 새 편집/참가/완료/함께하기 불가·원기록 보존 |
| 3 | 완료C+열린N, stopped 미완료 종료 | 열린N 참가/공대장/일정 유지, active 방 stopped 재개 흐름 유지·보관과 구분 |
| 4 | 내 계정에서 파티완료 수동 해제/취소·재완료 | 본인표시만 해제, 타인/N/당시 방기록 보존, 좌석/예약 자동복구 없음·취소쓰기0 |
| 5 | 나혼자 완료처리이후 탈퇴 | 선택1개완료/잔여본인참가취소·해당T탈퇴/승계·실제T목록복귀, 타인/N 보존 |
| 6 | 카드 X 현재 주차만/함께 | 동일사람 반대다른캐릭터·권한차이 확인, 현재만 반대보존·함께 양T제거·현재탭 유지 |
| 7 | 폴드/큰 글자·실제 재시작/복구 | 확인창 줄바꿈/대상날짜·버튼 의미, 계정 영속 원요청 복구. 모집관리 pending은 메모리 수명이며 앱종료복구 완료로 보지 않음 |

자료가 없는 review/null-card·승계/후계없음·수06/10시·양T권한 차이 등은 해당 행만 조건 미충족/별도시각 대기로 남긴다. 서버시각/DB수정·가짜인증으로 조건을 만들지 않는다. 실제 관찰 차이는 완료 기대/실제·대상T·오류code/request_id로 분류하고 직접원인의 최소 수정/검증·같은 Issue 회신을 한다. 정상로그를 선제 요구하지 않는다.

현재 feature/raid-recruitment-scheduling 유지·무관dirty 보존, dev/main 미반영이다. 인수 결과/필수 결함·명시후속 정리 전 통합/배포는 하지 않는다. 시간선택 UI 재디자인은 Penpot 확인 전 구현 제외, 통계/과거 새화면·모집pending 영속복구/서버·DB조작도 별도후속이다. Backend에 이미 인계한 같은 정책/시험을 재요청하거나 새 기능 범위를 확대하지 않는다.

## A 완료 해제 결과와 수동 확인

기존 설계 §37.27 A를 실제 계약과 대조해 구현했다. Backend8bbcfc8c의 정정2경로/관련8schema는 현재0eed67c4와 동일함을 확인했다. 계정 party/manual 본인 완료의 전용 context·확인/재검사·schema3/v3 영속 요청·원ACK·실제T 갱신 연결, **4파일 단일94mock PASS(신규34+기존직접60)·lib/test분석0**. 상세는 [설계37 §37.36](../backend-migration/37-raid-scheduling-and-multi-raid-planning.md)와 DEV_LOG다. 아래 과거 A설계/계약대기는 이 상태로 대체한다.

- 사용자 실기기 미확인: 파티완료 해제/취소, 다른 참가자·C/N 보존, 완료 재체크/재참가, 재시작·안내. 이전 모집방/자리/예약의 자동복구는 없다. 새 과거/은퇴 화면은 만들지 않았다.
- 새 v3는 디스크 저장 후 POST하고 원본문/token/key를 보존하며 ACK 후 조회실패는 재정정으로 바꾸지 않는다. schema1/2 v1/v2 PUT true/false 원요청은 계속 원transport로 복구한다. 기존 새완료 C/수10시·활동/카탈로그 제한은 유지했다.

## E23 수동 확인과 보존 경계

- 사용자 실기기 미확인: C/N 카드 고정대상/취소·현재만·함께, 반대 다른 캐릭터인 동일회원/주차별 권한 차이, current_only 반대 참가 보존·both 양T 실제 제거, 현재 탭/목록 갱신과 폴드/큰 글자.
- 기존 단일T pending은 원API/원본문·Key로 복구한다. both 불가를 current_only/옛API로 자동 치환하지 않으며 잘못된 ACK는 pending을 유지한다. ACK 뒤 조회 실패는 재추방의 사유가 아니다. 모집 pending은 메모리 수명이며 앱종료 영속복구는 미구현이다.
- feature/raid-recruitment-scheduling 유지·무관 dirty 보존. 시간UI/다인강제해산·매주자동개방/통계·과거 새화면·모집pending 영속복구·서버/DB/기기조작은 제외한다.

## 최신 UI 구간 결과와 서버 보완 대기 (2026-10-23)

주차완료 primary/완료아이콘·한줄단독, 선택C/N의이번주/다음주탈퇴, **서버허용 마지막1인만**탈퇴/새모집사이중앙빨강·흰글씨/아이콘 모집해산으로반영했다. 사용자가다인강제해산확장없이마지막1인유지를확정했다. 상세는설계37 §37.30/DEV_LOG, 관리/주차상세2파일52mock PASS·변경presentation/시험분석0,실기기미확인이다.

**[개인완료후탈퇴 요청6360708926](https://github.com/heo0328/lostparty-backend/issues/13#issuecomment-6360708926) Backend계약대기:** 사용자요구는개인선택raid완료+선택T명시탈퇴/리더승계. 현재personal은assignment완료/참가completed만이며승계/탈퇴없어새이름으로보장하지않고기존나만완료유지. 다중raid나머지본인참가취소영향·다른T보존·한명령원자성/ACK·CAS/원재송의정확계약인계후별도연결한다. globalleave는열린주공대장일때먼저위임필요, end는마지막지속회원1인이다. complete_item은선택raid전원이며다중raid전체일괄완료가아니다. UI이름만으로이차이를감추지않는다.

## 다음 작업 — Backend 완료정정 인계 대조 후 A 구현

기능 영역별 버튼 배치 보완은 구현·포맷/변경2파일 분석0·diffcheck/호출조건 검토를 마쳤다. 상세는 설계37 §37.29와 DEV_LOG, 실기기 배치는 사용자 확인 대기다. 작업 브랜치에 보관하고 dev/main 통합은 제외한다.

**최신 인계 수신:** [Backend6360251618](https://github.com/heo0328/lostparty-backend/issues/13#issuecomment-6360251618)이 완료정정/보관 구현을 `8bbcfc8cb89e69eb1f9747a0fcf2e919e41c3b76`·170경로/DB0030으로 인계했다. 아래 과거 'Backend 구현/최종 인계 대기'는 해소되었고 **Flutter의 고정 OpenAPI/예시/구현 대조·소비가 다음 단계**다. 현재 앱 소비2940824는 아직 변경하지 않았다. 이번 UI 배치 작업에서 새 정정 API를 연결한 것은 아니다.

다음 순서: 인계된 개발 안내/OpenAPI/8예시와 §37.27의 nullable/기록접근·기존pending 호환을 대조 → A 본인 완료 해제 구현/직접검증 → 결과를 같은 Issue에 회신/commit·push → B 목록/보관 소비. 인계에는 C수06~10시/과거T 본인 완료 취소 허용이 명시되어 있으며 완료 생성 C수10시 제한과 구분한다. 함께추방은 별도계약 대기다. 이미 회신된 계약을 같은 질문으로 재요청하지 않는다. 서버 정상실회원/기기 인수·dev/main 통합은 미완료다.

## 현재 구간 결과 — 상세 관리 UX 재배치 (2026-10-23)

구현 `1d6c0c1a` commit/push·원격일치, [결과6360353809](https://github.com/heo0328/lostparty-backend/issues/13#issuecomment-6360353809) 게시원문MATCH. 다음은 수정본 사용자 실기기 인수와 함께추방/완료정정 Backend 인계 확인이다.

완료정정 인계대기와 독립적으로 사용자 최신 상세UX 지시를 적용했다. 설계37 §37.28, 최종5파일144mock PASS/lib·test분석0. [함께추방계약 요청6360210574](https://github.com/heo0328/lostparty-backend/issues/13#issuecomment-6360210574) 원문MATCH·Backend회신대기다. 현재X는현재T고정대상확인/추방까지만이며3선택/양T처리는미구현이다. 포함: 공대장 빨간X 카드고정대상 현재T추방, 다음주선택은N실제개방/본인미참가때만, 위임은상단요약아래/내캐릭터변경은파티구성위버튼, 완료는구성아래·관리메뉴위, 현재T탈퇴/모두탈퇴는메뉴아래·새모집위. 새모집유지. 데이터/권한은기존읽기·관리preview/원명령을재사용한다. 확인중주차/회원전환·대상변경/중복·실패를보호한다. 두주차동일회원함께추방은현재한T명령만있어Backend계약요청/대기이며두명령순차실행으로위장하지않는다. 레이아웃/버튼정상흐름은사용자실기기, 고정대상·권한/세대경계는기존관리시험과직접표적으로검증한다. 기능코드·문서구간commit/push, dev/main통합제외.

## 향후 작업에 적용할 품질 기준

공통 기준은 [Backend Issue21](https://github.com/heo0328/lostparty-backend/issues/21)로 전달·게시원문MATCH 확인했다. Backend 담당의 자체 규칙/문서 반영과 적용 범위 회신 대기다. 이 추적은 Issue13 완료정정 인계와 별개이며, 같은 요청을 반복 게시하거나 자동 감시하지 않는다.

[개발 품질·데이터 흐름·UX 기준](../architecture/DEVELOPMENT_QUALITY_AND_UX_STANDARD.md)을 이후 구현 판단에 적용한다. 사용자 이해/조작·상태의 예측 가능성을 우선하고 패턴·API·캐시·비동기 수명을 선택한 이유와 검증 근거를 작업 규모에 맞게 남긴다. 현 기능 구현을 전면 리팩토링으로 확대하지 않는다. Python 대체와 실회원/기기 인수를 마친 서비스 복구 릴리즈의 배포·안정 상태 확인 시, 사용자에게 배포 main 기준 후속 최적화 브랜치 검토가 가능한 시점임을 안내한다. 지금 최적화 브랜치 생성·dev/main 병합·배포 지시는 아니다.

## 첫 구현 단위 — A 개인 완료 해제

사용자 설계/진행 지시로 정책검토 §37.26을 다시 대조하고 **파일별 구현·저장 호환·검증 설계 §37.27**을 확정했다. 최신Issue는127이며 Backend126은 여전히 미구현 제안이므로 실행 API 연결은 최종인계 후 시작한다. 같은 수용/시험 요청을 반복 댓글로 남기지 않는다.

1. 최종 SHA/OpenAPI·실행/DB상태와 복구관계 nullable/회원기록 접근 인계 확인.
2. 새 정정DTO·MemberRaidClient GET/POST·MemberWeeklyViewModel의 확인/제출/ACK/실제T조회, 기존 계정 확인창 연결. 카드마다 사전조회하지 않고 완료해제 터치시에만 context를 읽는다.
3. durable pending schema3/명령version3를 추가하되 schema1/2·원PUT true/false/key/body/ack는 보존한다. target=실제T와 expected_cycle=관측C를 분리하고 원ACK 복구가 현재C/token만료로 막히지 않게 한다.
4. 기능구간 최종 표적시험: 새정정 경계 + member_manual_completion_test/member_weekly_test/member_cycles_test, 변경분분석·포맷/diffcheck. 제한된writer/read전파로 무관전체시험 반복없음; 공용영향이 확인되면 그때 확대한다. 완료 후 문서/같은Issue결과·commit/push.

A 다음 **B 목록·보관방 읽기**에서 실제current/ended/all·review복구/기록detail/plan·stopped재개/열린N을 최종wire로 연결한다. A/B를 추정스키마로 한꺼번에 구현하지 않는다. 구체 상태전이·회귀/완료조건은 §37.27을 단일기준으로 삼는다. 시간UI·과거목록 신설·서버/DB조작·dev/main병합은 제외한다.

이번은 부족했던 구현상세 설계를 보완한 문서구간이며 기능코드/190mock상태는 그대로다. 정상실기기 검증은 A/B완결 후 사용자 담당으로 묶는다.

## 최신 계약 검토 결과 (2026-10-23)

[Backend126 제안6358628814](https://github.com/heo0328/lostparty-backend/issues/13#issuecomment-6358628814)를 대조해 [Flutter 검토6358680312](https://github.com/heo0328/lostparty-backend/issues/13#issuecomment-6358680312)에서 두 방향을 수용했다(게시원문MATCH). **계약 제안 단계·Backend 미구현/새소비SHA없음**, 현재2940824 유지다. 상세차이와 보호/검증은 설계37 §37.26을 따른다.

- 다음 담당 Backend: 본인완료정정·방/목록수명 구현/경계검증·정확한 원격SHA/실행OpenAPI·개발/DB반영 여부 인계. review_required/legacy복구관계의 card/cycle/gen nullable 예시와 기존회원 기록detail/plan 접근·권한을 최종 wire에 명시한다.
- 다음 Flutter: 인계 뒤 별도context/정정ACK·원pending호환/수동완료생성 보존, 취소권한 C/playable/활동/catalog 분리, current/ended/all·review복구/보관기록·stopped재개·열린N 격리를 직접영향으로 연결·검증한다. 구현 전 최종계약 확인, 미합의API/가짜성공 없음. 과거T API지원을 이유로 C/N선택기에 과거이력화면을 임의추가하지 않는다.
- 이번 사용자 요청은 계약 확인으로 기능코드는 변경하지 않았다. 기존190시험 재실행 없음·정적대조/문서 diffcheck. 첫수정 실기기 인수·서버정책 실제해결·dev/main통합은 여전히 미완료이며 시간UI변경은 제외한다.

아래 1차 수정 기록의 '계약 대기'는 위 제안 수용/최종 wire 보완·구현 인계 대기로 갱신된다.

## 2026-10-23 사용자 피드백에 따른 현재 작업

Flutter 구현 **2ba24d95 commit/push·원격일치 확인**. [결과 회신6358397626](https://github.com/heo0328/lostparty-backend/issues/13#issuecomment-6358397626) 게시원문MATCH. 서버 완료정정/방수명 계약 대기·사용자 수정본 재확인 단계이며 dev/main은 미반영이다.

- 포함: 계정 체크박스 시각 크기20% 축소(3열 중앙/터치영역 유지), 실제 회원 캐릭터 상세의 개별 Armory 갱신 복구, 생성·지원·변경의 선호 역할 초기값/선택 역할 전투력, 선택 캐릭터/주차의 참가·완료 레이드 생성 후보 제외, 참가중 목록의 실제 주차 참가 상태 필터.
- 시간 선택 UI는 **구현하지 않는다**. 사용자 최신 지시대로 Penpot 검토용 방안만 제안한다.
- 최신 제품 정책: 본인 완료는 파티 완료 출처라도 수동 해제할 수 있어야 한다. 완료 해제가 참가·좌석·예약의 자동 복구를 의미하지 않는다. 전체 완료 후 다음주가 없는 방은 활성 모집/참가중에서 제거하고 캐릭터 완료 기록만 보존한다. 다음주가 열려 있으면 그 주차를 보존한다. 기존 수동 출처만 해제 계약은 이 요구를 충족하지 않으므로 Issue13에 서버 보완을 요청한다. 가짜 로컬 성공/미합의 API/실데이터 삭제를 추가하지 않는다.
- 현재 결과: Flutter 독립 수정 구현·최종8파일190mock PASS/lib·test분석0. 상세 설계37 §37.25/DEV_LOG. [서버 보완 요청6358203104](https://github.com/heo0328/lostparty-backend/issues/13#issuecomment-6358203104) 게시원문MATCH·회신대기. 다음은 수정본 실기기 재확인과 정확한 완료정정/방수명 계약 소비이며, dev/main 통합은 보류한다.
- 순서: 현재 계약/원인 대조 → 독립 Flutter 수정 → 새 서버 정책 요청/회신 대조 → 직접 영향 검증 → 문서/Issue 회신/작업 브랜치 commit/push. 서버 계약 미확보 항목은 명시 대기한다.
- 보호: 생성 성공 실제T 상세/새 생성 초기화, 레벨/최고난이도, 캐릭터 변경 후 실제 참가 캐릭터의 완료, C/N·회원 격리/원명령 재송, 기존 갱신 분석·로컬 저장/서버 재시도·반대 역할 snapshot, 페이지 커서/기록 조회를 유지한다. 누락/오래된 주간 조회를 참가 가능으로 확정하지 않으며 최종 서버 context가 쓰기를 검증한다.
- 사용자 확인: 레벨별 후보/최고난이도, 생성 성공 상세·새 생성 진입, 캐릭터 변경 후 변경 캐릭터 완료는 정상. 전체 인수표를 통과로 확대하지 않는다. 미확인 시나리오는 아래 기존 인수표를 유지한다.

아래는 첫 피드백 이전 인수 준비 기준이며, 충돌하면 위 최신 수정 범위가 우선한다.

기준: 2026-10-23. **F1~F5와 F6-A/B 코드·자동검증 완료, F6-C도 Backend121/2940824의 정확한 계약으로 구현·자동검증했다.** 현재 소비29408243192ed3a37a347ade046db26ad2d918b9/168경로·policy4다. C는 새37+기존직접영향116의 5파일 단일153mock PASS·변경Dart7파일 분석0이다. 이전 구간의 시험 수와 합산하지 않는다. 실제 정상인증HTTP·실회원/기기 인수는 전체 기능섹션에 묶으며 미확인이다. feature/raid-recruitment-scheduling 보관·dev6d3f617 미병합·기존무관dirty를 유지한다. 완료 상세는 설계37 §37.21~37.23/DEV_LOG, 다음 전체 인수 준비는 아래를 따른다.

## 1. 현재 근거·준비 상태

- 제품 계약: [설계37 §36](../backend-migration/37-raid-scheduling-and-multi-raid-planning.md). 네이티브 데이터 흐름·파일별 책임/화면·F1~F6·검증/디바이스 게이트는 같은 문서 **§37**을 단일 기준으로 사용한다.
- [Backend92 인계6332478347](https://github.com/heo0328/lostparty-backend/issues/13#issuecomment-6332478347): 개발DB0029/API8000 two-cycle167경로·새worker 전환과 health/자료보존 완료 보고. 실행 준비 대기로 되돌리지 않는다. 정상인증 HTTP·Flutter 적용/기기·실회원쓰기 인수는 미확인이다.
- 소비 계약0.4.1/policy4·고정hash fb4c7d065594a9a0e7e8288e5f73179f90b078b68ac4323d1aade5c7a63b42f1, 게시SHA3c26cdb6/기능소스f276342/실행image ccc787cb9ccb를 구분한다. 게시SHA의 실제 실행 OpenAPI167경로와 첫 읽기 API·DTO를 직접 대조했다.
- 실제 Flutter Router: 계정 v2 C/N summary·개인표, 내 참가 /raid-status v2 본인목록·target 쿼리 기본 읽기상세가 연결됐다. 인증 회원 모집목록은 v2 search이며 비로그인 기존 Pending 화면은 유지한다. 실제 생성은 v2 context/POST, 상세는 v2 detail+실제T로 전환했고 target 없는 직접 진입은 인증메타 C를 조회한다. 원ACK/불변본문·세션/주차 격리를 유지하며 실제 생성 성공은 사용자 인수 미확인이다.
- 과거7방/관계는 C/N 밖이다. 현재검색0건은 정상이며 legacy/not_selected를 활성참가·i·현재좌석으로 표시하거나 자동탈퇴/한도회복하지 않는다.

## 2. 확정 정책과 영향 화면

| 영역 | 확정 요구 |
|---|---|
| 주차 | 서버 KST 수06시 C, N=C+7일. 언제든 C/N 선택. 수00시 개방 조건·C+14 신규 모집 없음 |
| 완료 | 해당 주차가 C이고 수10시 이후에만 완료 체크/정정·개인 완료·이번주 미완료 종료 허용 |
| 네이티브 | 내 계정·생성·모집 목록·내 참가/신청에 선택기와 실제 날짜. 같은 방 상세는 열린 C/N 탭. 확인 창은 실제 대상 날짜 고정 |
| 함께하기 | C 공대장의 N 활성화 시 본인이 N 첫 참가자/공대장. 다른 기존 참가자는 직접 선택·같은 캐릭터/역할로 즉시 확정, 승인제 재승인 없음 |
| 생성 체크 | C생성+함께하기 체크는 한 생성 명령으로 C/N과 본인 첫 참가를 모두 확정하거나 모두 실패. 생성 이후 탈퇴·승계/위임·완료는 T별 독립. 선택T=N은 N만 생성/C+14 없음 |
| 충돌 | B의 N 동일raid 점유 유지, A 미선택/자리·예약0. 다른 캐릭터 바로 참가/기존 참가 확인/닫기. 직접 B의 N 취소 후 A 참가, 자리 보장·통합 원자 이동 없음 |
| 탈퇴/관리 | 열린 N을 옵션 OFF로 철회하지 않음. 본인 N 탈퇴·N 참가 순서 자동 승계. 해당 주차 참가자에게 직접 위임 가능, 위임만으로 본인 탈퇴 안 함. C/N 영향 격리 |
| 계정 카드 | 3열 균등폭·체크 자체 중앙 고정, i는 체크 우측 가용폭 내 축소. 4개 이상 다중행. i는 선택 주차 실제 참가일 때만 표시 |
| 파티 구성 | 4인1~4 / 8인1-1~2-4. 실제 편성 기준, 빈자리 번호 유지·근거 없으면 자리 미정. 공대장 배지는 별도 |
| 한도/통계 | 같은 방 C/N은 고유room1개·기본10. 미래 참가/완료를 C 통계에 섞지 않음. 사전취소 통계는 #19 별도 결정 |
| 전환/예약 | 수06시 같은 UUID/실제cycle 유지, 라벨 전환·권한 재검사. N 변경/취소가 C 예약·완료를 정리하지 않음. 실제 참가와 일정 확인은 별개 |

## 3. 다음 작업 — 실제 회원·사용자 디바이스 인수

전체 인수 준비의 기존 설계37 §37.8/37.23을 실행해 **§37.24**에 실제 main/Router/DI·생성재진입/target·갱신 경로 근거지도와 인수 실행표를 작성했다. 코드의 연결은 정적 확인했으며 기능코드/의존성 변경·설치·실회원/기기 조작은 하지 않았다. 기존153mock/7파일분석0은 재사용하고 같은 시험을 반복하지 않았다.

현재 인계: 문서2019cefe commit/push·원격일치 후 [Flutter123 인수 준비6357755003](https://github.com/heo0328/lostparty-backend/issues/13#issuecomment-6357755003)에 15행미실행/정적대조·사용자 첫인수 순서/미확인을 회신하고 게시원문 MATCH를 확인했다. 다음 착수는 최신 Issue13·사용자 실제결과부터 대조한다.

**다음 첫 행동:** 사용자가 기존 정상 로그인/소유 인증 환경에서 §37.24의 U01→U02→U03을 수행해 C/N 계정·목록/생성·상세/새생성 재진입을 확인한다. 통과 후 U04~U08 검색/참가/다음주관리/일정, U09~U11 완료·종료/재개, U12 회원/결과불명 보호 순서다. T01/T02는 실제 수06/10시 조건에 별도로 기록하고 V01 화면 확인은 각 단계와 함께 수행한다. 앱 설치/조작은 사용자 담당이며 에이전트가 자동 진행하지 않는다.

- 전체 체크리스트/정확한 준비조건·기대결과·담당·결과양식·후속판정은 **[설계37 §37.24](../backend-migration/37-raid-scheduling-and-multi-raid-planning.md)**를 단일 기준으로 사용한다. 모든 U/T/V 행은 현재 미실행이다.
- 필요한 자료: 정상 회원 공대장A/참가자B와 입장 가능한 실제 캐릭터·레이드/개인표, C/N 비교할 방. 그룹/최대8인/시각 자료가 없으면 해당 행만 조건 미충족·시각 대기로 남긴다. 가짜회원/JWT/DB수정·서버시각변경으로 조건을 만들지 않는다.
- 사용자 결과 수신 뒤 Flutter가 실제 관찰/오류code·request_id/실제T로 원인을 구분하고 필요한 최소 수정·직접검증/문서/Issue13 회신을 한다. 정상흐름 로그를 선제 요구하거나 Backend에 같은 정책/시험을 반복 요청하지 않는다.
- 통합 게이트: 실회원HTTP/기기·성능 인수는 미확인이다. 정적준비 완료를 인수완료로 바꾸거나 dev/main 병합·운영배포하지 않는다. 실제 결과와 필수결함/보류·명시후속을 정리한 뒤 통합 여부를 판단한다. 현재 작업브랜치 유지·dev6d3f617 미반영이다.
- 별도후속: 앱종료 후 모집관리pending 영속복구·통계19·완료취소/참가/예약복구 역명령은 구현 완료로 간주하지 않는다. 계정 기존 schema/원pending·개인표·비로그인 Pending·다른회원/T 격리는 보존한다.

## 4. 디바이스 전 후속 순서와 협업

F1/F2 코드·자동검증 완료 후 F3목록·신규참가/신청/승인 → F4다음주특례·탈퇴/승계·위임/편성·공통관리 → F5일정/투표·확인/예약 → F6완료/정정·재개/통합. 세부완료조건·회귀는 설계37 §37.5~37.8, 기존사용자흐름/디자인은 §36이다. 단위별범위를고정하고정상UI디바이스시험을중간마다반복요청하지않는다.

후보 초안1/Flutter102 검토와 Backend103의 페이지 밖 선택 검증 보완은 [Backend104](https://github.com/heo0328/lostparty-backend/issues/13#issuecomment-6340348412) 구현/개발 반영 인계로 해소됐다. 현재 후보 소비SHA0afd879/168경로와 고정 기반0.4.1/policy4·canonical SHA를 구분한다. F3 결과·실제 원격 구현 커밋/사용계약·자동검증/실서버·기기 미확인은 같은Issue13에 회신한다. 신규 계약 충돌/실제 인수 차이가 있을 때만 해당 근거로 후속 요청한다.

## 5. 기존 구현과 인수 보존

- 개인표 등록/수정·동일 일자 추가·재시작/다른 기기 복원, 계정 관리 저장/취소 복귀·자동갱신 결과 닫기는 사용자 정상 확인 완료다. 과거48PASS/관리4PASS·계정36PASS는 DEV_LOG 근거를 유지한다.
- v1 생성/기본 상세는 구현95고유PASS, 재진입 복구21PASS, 로컬 시간/입장 정책37PASS·각 변경 분석0의 과거 기록이 있다. F2 최종 직접 영향 검증은 DEV_LOG의 고유95PASS를 따른다. 과거 수치를 더해 최종 전체 시험 수로 보고하지 않는다.
- 캐릭터별 가능 레이드/난이도·최고 가능 기본 선택은 사용자 정상 확인 완료. 시간 선택 회색/차단·유효 미래시각 생성의 최종 인수는 남는다. Backend 오류 보존11건409/SCHEDULE_BEFORE_FLOOR 회신은 수신 완료이며 새 원인 확인 대기로 되돌리지 않는다.
- 미확인: 완전 오프라인/앱 종료 후 결과불명 복구, 회원 전환/소유 상실·익일24h/부분 실패, 실제2주차 서버/API·디바이스 인수. 설치/기기 조작은 사용자가 한다.

## 6. 디자인·관련 문서와 별도 후속

Penpot03의 최신v2 카드/색감·인라인 필터 유지. 숙련도 다중선택, 좌측 참가인원 글자 터치 정렬·우측 남은자리, 그룹원별2열 캐릭터/그룹원 내부 아이템레벨 순서를 보존한다. v3(id9e65c694-d2eb-8038-8008-d1c1339a0015)5화면과 v4(id12e99482-847a-803e-8008-d1daccf18a9f)3화면이 최신 주차/승계 시안이다. 계정 체크+i 정렬과 v4는 실제PNG 검수 완료다. Penpot 데이터는 Git에 포함되지 않으며 문서는 보드 식별자/기준을 기록한다.

한도34·통계35, #12그룹/#15분쟁·#16조건부해산/#17소멸/#18활동/#19통계 및 신규1700/활동 선택·DB-03/QA-01/AUTH-01은 별도 후속이다. 현재2주차 준비에 무관 기능을 섞지 않는다. 완료 경과와 과거 협의는 [DEV_LOG](DEV_LOG.md), 전체 지도는 [AI_CONTEXT](AI_CONTEXT.md)를 따른다.
