# Backend 원정대 인증 클라이언트 준비

## 현재 인계 상태 (2026-10-18)

Backend는 Issue8 시간순144번째에서 V2 구현 `7ba6297c5a574aa14c214bb9d3bf30edb692fc8f`를 인계했다. 아래141번째의 서버 구현 대기는 당시 기록이며 현재 선행 조건이 아니다. Flutter는 `feature/roster-ownership-dispute`·[Issue15](https://github.com/heo0328/lostparty-backend/issues/15)에서 2026-10-19 D1~D4 코드/자동 검증을 마쳤다. D4 직접 영향68고유PASS·변경18파일분석0, 사용자 승인으로 현재 구현 구간을 마감·dev 통합한다. 기존 V1 미완료 요청은 보존하며 공통 상단 안내도 연결했다. Backend 작업으로 현재 불가능한 실제 서버/기기 인수는 차후 후속이며 통과로 확대하지 않는다. 최종 커밋은 DEV_LOG를 따른다. [설계36](36-roster-ownership-dispute-flutter-design.md)과 [NEXT_WORK](../project/NEXT_WORK.md)를 따른다.

## 2026-10-18 141번째 보완안 소비 검토·앱 상단 방어 안내 요구

최신141번째는회원proof목록GET/양측목록·본인진행proof참조, 11동작의엄격DTO/200단일settle예약ACK, 같은원정대다른유효캐릭터명시선택을추가했다. 140번째3공백은이설계로해소가능하며V2별도소비에기술적차단없다. 원정대3건/방어1회동일owner+revision전부종료/먼저성립한분쟁우선처리·이전후나머지종료는141번째Backend사용자확정기준으로반영한다. 이결과는설계검토이며실행OpenAPI/서버/worker검증/Flutter연결완료가아니다.

시간표시: 각시도자자기deadline과기존소유자공통defense_available_until을혼동하지않는다. 방어10분끝은min(시작+10분,공통기한). 앞분쟁취소로공통기한이늘어도발급proof자동연장없음. 맨앞분쟁장애/review_required면뒤분쟁승격하지않고처리대기/검토필요표시. 슬롯경합passed+blocked는장비통과이지분쟁개시/소유성공아님. 일괄방어/이전으로무효화된옛proof늦은응답은새분쟁으로연결하지않는다. 목록발견후해당ID의현재GET·회원/환경/세대/ownershiprevisionguard를재사용한다.

사용자 추가 UI요구(구현지시아님): 앱이 방어요청 데이터를 수신하면 페이지상단제목영역에서간결하게알리고인증/방어페이지로안내할수있어야한다. 문구예시는‘타인이 내 원정대 등록인증을 하였습니다, 인증페이지를 확인하세요’이며표현은소유이전완료와혼동되지않게제안한다. 후보‘원정대 인증 도전이 있습니다 · 확인’, 정확한문구/크기/색/배치는UI구현전확정한다. 외부push는후속,현재는앱내영속안내요구다.

현재구조대조: BackendApp의StatefulShellRoute→AppShell은공통하단탭/Scaffold body만소유하고전페이지공통AppBar가없다. 각Page는자기Scaffold/AppBar를소유하며settings인증등root route는탭shell밖이다. 추후앱수명회원scope안내상태+공통상단표시위젯/필요root경로연결을설계해제목/뒤로가기/기존action터치영역·SafeArea·큰글꼴·본문비이동을보존한다. 기존구수동dispute alert구현을현재V2연결로오인/복구하지않는다.

안내데이터는V2분쟁role=owner active목록과state/phase/defense_available_until/allowed_actions를사용할수있어배너만을위한별도API는현재요청하지않는다. 확인탭은방어에즉시동의/시작하는것이아니라해당분쟁조회/선택으로진입하며일반본인재인증차단은유지한다. 여러분쟁은동일원정대단위로일괄방어상태를알리고개별화면현재값을재조회한다. 방어기간지난분쟁을‘방어가능’으로표시하지않고처리중/검토필요를구분한다. 페이지열람/로그아웃/조회실패만으로서버분쟁을읽음완료·취소·방어성공으로바꾸지않는다. 로그인/복귀조회로복원·같은회원중복요청/낡은응답차단, 배경상시polling/앱밖전달보장없음. 표시주기·닫기/숨김정책·미확인배지는이번에임의추가하지않는다.

다음Backend는141번째확정명세로구현/시험·고정SHA/OpenAPI인계가능. Flutter는실계약인계후원래로그인/계정/인증화면의최소변경UX설계→연결→관련자동검증→기기검증순서다. 관리자고정/Discord·새DB/자료이전·외부push·새화면구현을현재검토에섞지않는다.


최종 소비 검토·UI요구 회신: [#8 시간순 142번째](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6245421798) 원격본문/순번확인, 다음Backend구현인계.

## 2026-10-18 135번째 V2 기술계약 검토

판정: V1호환보존·V2분리·장비통과/분쟁개시/최종소유결과분리·양측분쟁GET·서버UTC기한/권한·worker최종판정방향은Flutter연결가능하다. 아직게시OpenAPI/구현이아니므로실제DTO소비/서버연결완료는아니다. 138~139번째확정(영구금지/재도전대기없음·고정후속/동시정책미정)이135번째옛cooldown/unique제안을대체한다.

현재연결근거: ServerRegistrationPreview는3필드엄격검사, ServerAccountVerification은8필드/V1enum엄격검사. ServerVerificationCommand는V1경로·confirm빈body/DELETE204를고정, Client는단일expectedStatus와Map본문만수용한다. VM은1개challengeID/미확정명령메모리·회원세대fence, Page는verified에서만현재목록복원후복귀하고본인owned사전검사로일반시작차단한다. BackendApp/settings/game-account-verification이현재진입이며구수동UI/Repository가새분쟁을복원하지않는다.

Backend 보완 요청:
1. **정확한OpenAPI**: preview envelope/VerificationV2/DisputeOut/목록items·cursor·feed revision과nullable·enum·상태별필수값·allowed_actions실제문자열, 각POST성공status/본문/error/retry를명시한다. V1에필드를추가해새클라이언트를강제하지않고V2별도DTO/명령/VM을연결해야한다. 202settle은단일200기대transport로읽을수없어상태코드+본문결과계약을정해야한다. 단순예외재요청으로소유완료판정하지않는다.
2. **장비proof발견/복원**: 현재V2 GET/{id}만있고분쟁목록은장비성공전없다. 앱재설치/다른기기에서ID를모르면진행중claim/defenseproof를발견할수없다. actor-scoped현재장비조회나목록/분쟁상세본인진행proof참조등최소계약이필요하다. 로컬journal만으로신규기기복원을완료처리하지않는다. 불명확start응답은같은key재시도와현재결과조회로구분하고새장비명령발급을자동우회로사용하지않는다.
3. **두기한/상태UX**: 장비countdown은equipment_expires_at/server_now, 분쟁은defense_deadline/server_now로독립계산. server_now는화면표시용offset/경과에쓰고복귀시GET재조회. 24시간도달은‘처리중’이며worker결과전이전완료/활동개방/타이머연장안함. dispute_opened/defended는현재Page의verified완료복귀/활동설정콜백에연결하지않는다. unknownphase/action은쓰기비활성·최신조회대상, 실패를성공으로처리하지않는다.
4. **방어진입/표적**: 일반본인ALREADY_VERIFIED는유지하고서버분쟁role/allowed_actions에따라방어전용시작을분리한다. 기존본인사전검사를전체해제하면안된다. 135안의고정target만허용은기존‘등록캐릭터선택방어’제품기준/인증에사용한캐릭터소멸이원정대인증을해제하지않는정책과UX차이가있다. 현소유원정대의다른유효캐릭터를본인이명시선택/서버동일account검증하는방안을검토하거나고정target필수이유/대체경로를제시해야한다. 개명자동매핑/원정대간대상교환을요청한것아니다.
5. **앱내통지/재조회수명**: 분쟁feed는장비상세복원/model.loading/자동갱신완료를기다리지않는앱소유회원scope로시작·복귀시조회한다. 여러화면/복귀에서중복task를만들지않고이전회원응답/페이지dispose와조회소유권을분리한다. visible30초polling은성능/UX구현안이며현재승인된상시polling아님. backendGET이무부작용이면조회가능, 사용자배치/진입은기존계정UI최소확장설계후연결한다. feedcursor stale는동일회원최신첫page조회·상대회원정보비노출.
6. **최종이전후반영**: 현재verified콜백1회만으로worker비동기이전은탐지안된다. 양측분쟁GET/feed변경→현재회원roster/settings/lifecycle/profile/weekly/group대표를현재서버상태로재조회하고ownershiprevision으로이전캐시/늦은결과격리. 새owner는unconfigured/활동빈상태를인증실패로보지않으며옛owner개인자료/주간완료·참가자리승계없음. my_registration_id nullable/생성및한도실패·200결과와멱등ACK/현재GET의관계를정확히명시한다. party후처리미연결시review_required는안전한보류안으로수용가능하나전체실자동이전완료로보고하면안된다.

후속운영자고정은지금DDL/도구를선행하지않되향후policyrevision/최종guard를넣을경계를유지한다. retention90일/동시unique/선착순등운영·제품안은이번기술대조만으로승인하지않는다. 현재검토결과만회신하고새기능코드/테스트를추가하지않았다.


기술 검토 회신: [#8 시간순 140번째](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6237226314) 원격본문/순번검증. 다음Backend계약보완/잔여제품선택.

## 2026-10-18 사용자 확정 — 재도전 제한 없음·향후 운영자 귀속 고정

일반 원정대는 기존 소유자가 방어에 성공해도 **영구 인증금지·별도 재도전 대기시간을 두지 않는다.** 새 시도자의 장비 확인이 다시 성공하면 매번24시간방어가 시작된다. 과거 수동 방어성공 후active금지/135번째재도전24시간cooldown제안은새자동경로에채택하지않는다. 진행중동시분쟁정책은별도미확정이며API쿼터/멱등/중복요청검사는유지한다.

후속 운영자 기능: 현재 오픈카카오톡 문의를 차후 Discord 채널로 변경하고 화면공유 등으로 운영자가 확인해 특정 앱 회원에 원정대 귀속을 고정하거나 해제·소유 조정할 수 있도록 한다. 부정등록·반복역분쟁·일반경로로해결하지못한원정대도문의대상이다. Discord주소/연동·운영자도구/강제이전구현은현재범위가아니며실제URL도미제공이다.

**귀속 고정 시 다른 회원의 일반 인증 도전·24시간 자동 이전을 차단하고 운영자만 해제·조정할 수 있다**고 사용자 확정했다. 현재owner와운영자고정상태를분리하며, 고정해제(프리)는일반규칙으로복귀하는뜻이지일반소유권삭제/타인자동귀속이아니다. 향후고정대상회원·운영자·시각·사유·revision/감사와진행중분쟁/worker최종권한재검사·무효화경계가필요하다. 실제필드명/DDL/API는Backend설계로결정하고일반클라이언트on/off로권한을부여하지않는다. 구저장기술/운영자스크린샷경로를복구하지않는다.

[#8 시간순 138번째](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6237128139)에두사용자답변을반영해수정후원격본문/순번확인. 현재는정책기록·향후확장고려요청이며기능코드/서버/DB/배포변경없음. 다음Backend는동시도전등잔여차이정리·계약안반영. 신규운영자도구를24시간기능의당장선행조건으로확대하지않는다.

## 2026-10-18 136번째 요청 — 기존 동시·반복 도전 조사

조사 원본은 과거 고정 `8f4209deb980660e227134bf1241677875d02e06`이다. 당시 Repository/Rules는 과거 제품·구현 근거로만 읽었다. 현 신규 서버에 과거 저장기술/규칙을 다시 도입하는 요청이 아니다.

| 항목 | 과거 수동 인증 정책·구현 | 현재/새 자동 장비 경로 판단 |
|---|---|---|
| 같은 회원·원정대 중복 | 정책은 Player+원정대 active1건. Repository.createRequest→_activePendingForAccount는 요청자별 조회 후 같은 로컬계정/서버계정/소속 이름으로 비교 | 과거 판정은 pendingProof만 포함. awaitingOwnerResponse는 isPending=false라 분쟁중까지 포괄하는 active1건 보장이 아님 |
| 서로 다른 회원 동시 도전 | 계정 전체의 active1건/선착순/대기열 정책·원자적잠금은 조사 코드에 없음 | Backend135번째 동시1건/선착순은 신규 제안이며 미확정 |
| 기존 소유자 방어 성공 | defended 종료 후 도전자 Player+해당 GameAccount 인증금지 기록. 만료시각 없는 active block, 정책상 운영자 해제 전까지 금지 | 24시간 cooldown이 아님. 다른 원정대/다른 Player 전체 제한 아님. 현 자동 장비에 자동 승계하지 않음 |
| 취소·실패·만료 | 취소는 pendingProof만 종료·정책상 새 코드 재요청 가능. 만료 pending은 active 검사 제외. 취소/불일치/만료 뒤24시간 재도전제한 없음 | 장비/소유방어24시간·멱등재시도24시간·외부호출cooldown과 재도전제한을 구분 |
| 기기/계정 변경 | 요청·금지는 원격Player/원정대 자료라 같은 Player로 복원되면 조회됨. 그러나 새AuthUid/Player 우회대응은 정책상 보류 | 새기기/재설치/Google계정의 동일Player복원까지 검증된 것으로 확대 불가. 새 Google계정은 별도회원이며 과거금지의 동일인 추적근거 없음 |
| 서버 보장 수준 | 과거 create는 query후별도set. Rules.validManualVerificationCreate에는 active고유잠금/금지문서검사가 없음 | UI/Repository 차단을 서버의 동시·위조요청 보장으로 보고하지 않음. block은원격저장됐으나서버차단보장은미흡 |
| 과거 자동 장비 | LocalGameAccountVerificationGateway는 프로세스 _activeChallenge1개/10분, 통과 후 _claimOwnership에서 이전 처리 | 원정대전체/회원전체동시제한아님·재실행복원없음. 24시간방어/방어후금지/재도전쿨다운없음 |
| 현재 앱 연결 | BackendApp→ServerVerificationViewModel/Client의V1장비흐름, 값/미확정명령은메모리·서버challenge조회. 구수동Repository구현은현재제거됨 | 현재24시간분쟁/동시원정대제한/반복제재를연결완료로판정하지않음 |

핵심 근거(모두8f4209d): firestore_manual_verification_repository.dart createRequest:47/_activePendingForAccount:1329/_assertNotBlocked:1271/reviewApproveDefense:560와block쓰기:664/_openDispute:1010, manual_verification_request.dart의isPending, firestore.rules의validManualVerificationCreate:3676·manualVerificationBlocks:3957, local_game_account_verification_gateway.dart activeChallenge:43/start:57/confirm:97/_claimOwnership:165. 제품 원문 OPERATOR_AUTHORIZATION_CONTRACT §5.2/7/9.2는24시간금지가아닌인증금지·재설치우회보류를명시한다. Task086은분쟁개시/방어승인등과즉시이전수동동작기록이며24시간실경과/동시요청/다기기위조방지시험의증거아님.

136번째 추가확정: 앱내안내먼저/외부푸시후속. 135번째 DTO/두기한/양측복원안은V1엄격필드와분리하려는제안으로검토대상이며이번역사조사로승인하지않는다. 다음Backend는기존정책과신규제안차이를정리해사용자결정을받고계약확정한다. 신규동시1건/재도전24시간/영구인증금지어느것도이번조사로도입하지않았다.


조사 회신: [#8 시간순 137번째](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6237012986) 원격본문/순번확인. 다음Backend차이정리/필요사용자결정.

## 2026-10-18 타인 인증 원정대 — 24시간 챌린지 요구

사용자 최신 지시: 다른 Google 계정이 인증한 원정대를 인증 시도하는 사람에게도 **‘타인에게 인증 완료된 원정대입니다.’**를 표시하고 **24시간 소유권 챌린지**를 제공한다. 단순한 신규 장비 인증 화면/10분 타이머만 제공하는 현재 흐름은 이 요구를 충족하지 않는다. 사용자 실측은 다른 기기/다른 회원으로 시도 시 일반 장비 인증 화면과 시간이 진행된다는 것이며, 장비 확인 성공/분쟁 개시·이전 성공까지 보고된 것은 아니다.

기존 장비 확인(10분)과 소유권 방어(24시간)를 구분한다. 현재 VerificationOut에는 타소유 표시/분쟁 상태/24시간 기한이 없고 pending/verified/expired/cancelled와 장비 챌린지 기한만 존재한다. Flutter가 이를 추측하거나 로컬 타이머만 늘려 분쟁으로 표시하지 않는다. 서버가 타소유 여부·분쟁 ID/상태·서버 기준 시작/마감·시도자/기존 소유자의 허용 행동과 복원 조회를 제공해야 한다. 상대 Google 계정 식별정보는 안내에 필요하지 않다.

사용자 추가 확정: **24시간은 새 시도자의 장비 확인 성공 후 시작한다.** 타인 인증 사실은 인증 시도자에게 즉시 안내하며 단순 검색/클릭만으로 방어 기간을 시작하지 않는다. 장비 확인 통과는 즉시 소유 이전 성공이 아니다. 기존 소유자 방어 방법·기간 중 사용제한·만료/방어 성공/실패/동시 도전·취소와 재시도 정책은 Backend가 기존 제품 정책과 대조한 차이를 제시한 뒤 확정한다. 과거 운영자 수동 인증의 화면/저장기술/제재 규칙은 자동 장비 경로에 임의로 승계하지 않는다.

작업 순서: Backend 상태/전이·권한·API 변경안 → 필요한 제품 결정 반영 → 서버 구현/계약 인계 → 기존 Flutter 인증 화면에 간결한 안내와 24시간 상태/복원·양측 행동 연결. 본인 소유 재인증 차단·새 원정대 장비 인증·기존 소유권/ID·활동/파티 정보 보존을 회귀 보호한다. 현재 문서/협업 요청 단계이며 신규 분쟁 API/서버·Flutter 기능 구현 완료가 아니다.


협업 인계: [#8 시간순 133번째](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6236706515), 사용자 시작시점 답변을 같은 댓글에 반영하고 원격 본문/순번 확인. Backend 계약안 회신 대기.

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
