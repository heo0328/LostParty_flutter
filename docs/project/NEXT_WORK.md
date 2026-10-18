# NEXT WORK — 회원 화면·관리 진입·서버 복원 사용자 확인

## 화면·주간 체크 먼저/자동 상세 나중 연결 완료 — 실기기 확인 대기

현재회원저장서버원정대·선택셀/수치/기존역할요약복원과현재대상주간조회완료뒤에자동Armory2worker를시작하도록binding/controllergate연결. initialCache는먼저표시하되cache준비신호만으로자동을시작하지않는다. weekly는완료signature/관찰generation·회원epoch를고정해빈목록/옛대상/회원응답준비오인을차단한다. 새회원전환에도같은순서, 조회실패는안내/쓰기차단유지후시도완료로인정해무한대기없음. blocked키상태를모든notify마다재시도하지않도록준비false→true경계만재개한다.

검증: 직접회원binding연결/weekly/controller3파일81PASS·변경6파일분석0·format/diffcheck. 주간batch지연시gameArmory0·확정완료entry/표시이후Armory시작/실패해도영구대기없음·현재대상/세대·회원전환gate·기존수동설정저장/미확정명령회귀확인. 기존동시초기roster무효화기대는‘기본읽기먼저공유’로정정, 조기blocked반복이설정재시도를가로막은중간회귀는준비전이감지로해결후최종통과. 전체시험/빌드/기기대행/API·DB/서버작업없음. 캐시schema/레이드쓰기/i/카드디자인/나이스정책/최대2worker미변경.

다음사용자: 동일실기기/계정/설정에서완전종료후debug재실행, ①원정대/활동캐릭터·아이템/전투력·기존빌드요약을표시 ②주간완료체크표시 ③그후자동상세진행표시·개별결과반영,이동안체크초기화/본문이동없는지확인. LoadTiming에서초기회원displayReady와대상있는weeklyBatch완료가automaticRefresh시작보다앞서는지비교. 첫paint/절대속도개선은실기기미확정. feature/scoped-account-cache/799711a유지·기존계측/2worker와이번변경미커밋/미push/dev미반영. 독립Flutter순서변경으로Backend선행API/반복검토요청없음.

## 최신 비교 — 동시2개 실행 확인/성능 개선 미미

SM F956N동일회원사용자첨부1322dee6: initialCache647ms(직전577), 준비1672ms(1471)·HTTP4/1258ms(633), 자동전체6886ms(7079)/HTTP24·3156ms(1788)·오류0. charstart2개중첩→종료마다다음배정·5개end2141/2239/1644/1950/1319ms(개별합9293ms,병렬이므로합산이총시간아님). 자동에서준비를뺀대상처리벽시계약5214ms(직전5608), 감소394ms/약7%. 자동전체감소193ms/약2.7%뿐이다.

후속displayReady3279ms(직전2843), 회원전체4528ms(3965), displayCache594ms(481)/active2214ms(1907). local120회1156ms(958), HTTP13/1549ms(1578), weekly352ms(319)·후순위1245ms병행. 자동+후속displayReady경로합10165ms(9922)로이번1회는243ms늘었다. 앱런치첫paint총시간은아니며단일비교로항상느려짐/평균개선율확정안함. 최초run2interrupted는기존자동관찰generation갱신경계와일치·HTTP오류없음. HTTP0/각단계ok를모든서버저장ACK/화면결과완료로확대하지않는다.

분석: 동시2개작동/대상5개는확인됐으나개별작업이길어져기대만큼단축없음. 고정전체쿼터/CPU/DB/서버중한원인으로단정불가(순차준비HTTP대기도변함). 다음추천단일구간은자동source의role준비/LostArk직접조회/동기분석/로컬저장/서버업로드를고정단계로분리측정해직렬대기·CPU·I/O기여확인. 동시수추가증가/Isolate·DB개편/guard제거/병렬원복을추측으로수행하지않음. 이번은분석/문서만·코드/시험/서버작업변경없음. 기존45PASS/분석0재사용·feature/scoped-account-cache/799711a·미커밋/미push/dev미반영.


## 자동 상세 갱신 최대2개 적용 완료 — 동일 실기기 비교 대기

사용자승인범위만Controller작업배정1→2worker로변경했다. 기존캐릭터조회/분석/로컬저장/서버업로드·현재성guard·나이스단OFF/회원별1회·원정대준비·후속회원복원은불변. 하나완료시다음queued배정·모든worker정리후전체완료. retryIncomplete도2개상한/서버저장만재시도는순차유지. 429/키실패/stale공통오류시새배정중단, 이미진행중인대상의유효로컬결과는보존·늦은권한쓰기차단. 캐시재사용/일괄저장/API/DB/화면개편미포함.

검증: 직접Controller/runtimeSource두파일45PASS·변경3파일분석0·format/diffcheck. 같은원정대2캐릭터실제runtime동시armory대기후각역할저장·업로드/outbox정리,2개상한/빈자리즉시배정/마지막peer기다림·429후3번째배정없음/peer보존을추가확인. 순차1개가정의기존fixture는2개진행에맞게barrier/호출수만정정하고키/세션/dispose·이미commit결과보존검증은유지했다. 전체시험/빌드/기기대행/서버변경없음.

다음사용자: 같은SM F956N/같은로그인계정·사용캐릭터/나이스설정·캐시유지, 앱완전종료뒤기존debug USB명령으로재실행(로그아웃/앱삭제불필요·HotReload만으로회원별1회재실행안됨). [LoadTiming]전체로직전prepare1471ms/5개순차합5598ms/automatic7079ms·후속displayReady2843ms와비교. 새로그의두characterRefresh start중첩과총automatic경과·오류/저장대기·처리대상수를함께확인하며동시개별시간단순합산안함. 효과는실측전확정안함. feature/scoped-account-cache/799711a유지·기존진단포함미커밋/미push/dev미반영. 독립Flutter배정변경이라새Backend API/검토요청추가없음.

## 최신 실기기 로그 — 연결 정상/자동 직렬 상세 갱신 우선

사용자SM F956N첨부f8a10486: 최초cache577ms/HTTP0(local등록135/roster58/presentation25/prefs52/dealer179/support116/listeners2), 자동prepare1471ms+캐릭터5개1434/1113/1048/1020/983ms(합5598), 자동전체7079ms/HTTP24·1788ms/오류0. 이어회원roster445ms,displayCache481ms,activeRestore1907ms,displayReady2843ms/HTTP13·1578ms,후순위1118ms/HTTP9·1532ms/회원전체3965ms. weekly후속319ms/HTTP2·304ms. 실제USB앱서버통신정상확인, 이전VMService로그만으로판정하지않던연결성공을이번로그로구분한다.

회원후속local120회958ms(이전에뮬레이터4391ms), displayCache60회477ms/active60회479ms. listener회원총7ms. 실기기에서도중복읽기존재하나우선병목은자동5캐릭터순차5598ms+준비1471ms후회원복원2843ms가직렬로이어지는구조. source.refresh는현재성/개인role준비→LostArk직접armory→분석→로컬저장→서버업로드이며우리서버HTTP1788ms를뺀5291ms를SQL/서버/분석중하나로단정하지않는다. 조건/통신경로도달라에뮬레이터대비차이를디바이스효과만으로계산하지않는다. displayedReady는최초프레임이아니며자동+복원약9.92초는그작업경로합계/런치전체계측아님.

후속추천우선순위정정: 최신상세갱신직후동일결과/원정대자료를다시읽는경로를좁게설계해중복복원축소→필요한추가측정으로직접게임API/분석/저장을분리한뒤작은동시상한검토. 호출한도/나이스단OFF·회원별1회/원정대현재목록/소유revision/명시편집·보류명령보호는보존. 실제동시수증가/guard제거/새API/구조개편을이로그분석에서실행하지않는다. 이번코드/추가계측·시험/서버작업없음·문서diffcheck만. feature/scoped-account-cache/799711a유지·기존진단미커밋/미push/dev미반영.


## USB 실기기 연결 읽기 전용 점검

사용자가SM F956N/127.0.0.1:8000실행실패를보고해조회만수행. 제한환경의socket/ADB접근오류는재조회로분리했고권한있는조회에서실기기SM_F956N=device·에뮬레이터동시인식, adb -d reverse --list에UsbFfs tcp:8000 tcp:8000존재, PC8000listen/health200(databaseok)확인. debug manifest는cleartext허용·INTERNET있고Backend명시URL우선/httpdebug허용. 현재휴대폰오류로그미확보라앱통신성공/실패원인확정은아니다. 기기설치/실행/포트변경/서버재시작은대행안함.

다음사용자: 기존flutter실행완전종료→adb -s 실제기기ID reverse tcp:8000 tcp:8000→flutter run --debug -d 실제ID --dart-define=BACKEND_BASE_URL=http://127.0.0.1:8000직접실행. 여전히실패시이번실기기콘솔의http_error/category/status/오류문구로비교. 명령의기기이름매칭실패를원인으로확정하지않는다. UI/네트워크코드/시험추가변경없음.


## 현재 작업 — 초기 로딩 사용자 실측 분석 완료/최소 최적화 범위 제안

사용자33ms는SQLite캐시를읽고닫고다시읽는반복측정이며앱의전체복원동등측정은아니다. 새로그b651fce6에서run4 displayCache2117ms/HTTP0, 로컬60호출2106ms. activeRestore6851ms/HTTP11·2844ms, 로컬60호출2284ms. 두단계로원정대3/캐릭터18의prefs/dealer/support각36회·roster/presentation각6회=120고수준호출4391ms(부모span반올림)이며displayReady9783ms의약44.9%다. HTTP13누적3153ms약32.2%, 나머지2239ms는기타대기/가공/저장등으로현계측상미분리. 로컬호출은SQL단일쿼리가아니고검증/transaction내여러query포함이다. 단순DB엔진/서버만의원인으로판정하지않는다.

automaticRefresh20719ms/HTTP24·4961ms/오류0뒤run4회원복원이시작됐고total13393ms/HTTP22·5424ms, 주간actual후속523ms/HTTP2·488ms가inactive3603ms와병행. 원문에initialCache후반/roster/run3초반행누락과중간‘vent=end...’절단이있어초기cache총시간/최초화면시각/앱시작총시간은산출불가. 보이는initial등록읽기230ms/roster3회45ms/presentation3회45ms/prefs9회181ms만으로초기cache전체를판정하지않는다.

listeners는run4 displayReady총4ms·accountRefresh7ms, automatic16회1ms로동기통지자체가수초원인아님. Flutterbuild/layout/paint는미계측이므로Skipped72/41frames·debug에뮬레이터경고를이수치로배제하거나특정위젯결함으로단정하지않는다. 자동character각수초와HTTP차이에는LostArk직접호출/분석/저장/스케줄링이포함돼서SQL/CPU로동일시불가.

추천다음단일구간: 같은회원/원정대/ownership/lifecycle·편집세대의로컬관찰과설정/역할요약을원정대단위로읽어반복guard DB조회·displayCache/activeRestore재읽기축소. 권한/낡은응답/보류명령/사용자편집은보존하며캐시를검증된쓰기근거로승격하지않음. 우선로컬읽기만수정후같은사용자1회실측으로효과비교, 자동runner병렬수/갱신재실행·주간조기조회는독립후속으로분리. 이번턴은로그분석/문서만, 기능코드/추가계측/시험/서버작업변경없음. 기존진단6PASS/분석0은직전결과재사용·전체시험반복없음. feature/scoped-account-cache/799711a유지·기존미커밋/미push/dev미반영.

## 2026-10-18 현재 진행 복구 지점 커밋·작업 브랜치 push

사용자 지시로 feature/scoped-account-cache의 현재 코드/테스트/제품·협업 문서를 복구 지점으로 커밋하고 같은 원격 작업 브랜치에 push한다. dev/main 병합은 이번 요청에 포함하지 않는다. origin작업브랜치/dev는착수시5eef0d2·HEAD대비0/0확인. 사용자Rules백업2개/tools/DevTools설정·플랫폼자동생성줄바꿈만변경은제외·보존한다.

범위: 기존회원화면/원정대관리진입/캐릭터선택·표시·역할/왕관·주간manual/i/앱수명캐시선행·시작6초상한·진단/기본에뮬레이터URL·대소문자검색/등록조작영역상단배치와관련문서. 분쟁V2/최대3건/24시간/앱상단방어안내·운영자고정/Discord는정책설계만포함하고실행연결완료로보지않는다.

최신협업: [143번째](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6245466325)는142번째기술검토와상단안내요구수용/Backend구현준비이며코드/API/worker구현·반영완료아님. 다음Backend구현·자동검증/고정계약인계→Flutter기존화면최소설계·연결. 별도미완료는주간조회앞당기기/회원캐릭터상세수동갱신복구이며이커밋이해결한것아님. 이하‘미커밋/대기’와개별시험숫자는각시점기록이며현재Git/최종검증은이절·DEV_LOG복구지점절기준이다.

최종검증: 전체flutter test 1641PASS(47초), lib/test analyze 이상0(45.7초), 변경Dart46파일포맷0변경·git diff --check. 서버/DB/기기설치·배포변경없음. 구현/설계복구커밋 c6332dd28dc68ee762149f2762365277756e3486 을 feature/scoped-account-cache에push했고원격SHA일치를확인했다. dev/main은5eef0d2유지·미병합. 백업/tools/DevTools설정·플랫폼자동생성파일만작업트리에보존. 이실제Git결과를기록한문서후속커밋도같은브랜치에push한다.


## 141번째 최종 소비 검토 완료 — Backend 구현 인계 대기

[계약28 최신절](../backend-migration/28-verification-client-preparation.md)에141번째의3공백해소/최대3건·일괄방어/공통기한·순서처리소비가능을기록하고[142번째회신](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6245421798)원격본문/순번확인. Backend는구현/시험·고정OpenAPI인계가능. 그후Flutter기존화면최소변경UX설계→연결→자동/기기확인. 아직실행기능완료아님.

사용자추가UI요구는페이지상단방어안내/인증페이지진입이며지금구현지시아님. AppShell공통하단탭/개별AppBar·root route차이를확인했고기존제목/action터치·본문비이동/회원guard보존으로추후공통연결한다. 별도배너API/외부push/상시polling·관리자도구/DDL추가없음. 문서검토/diffcheck만·기능코드미변경·feature/scoped-account-cache/5eef0d2유지·미커밋/dev미반영/미push.

## 135번째 V2 기술계약 검토 완료 — Backend 보완 회신 대기

[계약28 기술검토절](../backend-migration/28-verification-client-preparation.md)에현재V1DTO/command/client/VM/Page/Router·회원revision과135번째제안을대조했다. V2분리·두기한/소유결과분리·양측GET/worker방향은연결가능. 장비proofID미보유신규기기복원, 정확한OpenAPI/status별shape·enum/actions, 고정방어target과기존등록캐릭터선택UX차이3건을Backend보완요청했다. 비동기이전후양측현재회원자료재조회·늦은캐시/쓰기차단/옛개인자료비상속·일반본인재인증차단보존을명시.

[#8 시간순 140번째](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6237226314) 원격본문/순번확인. 이후141번째보완수신및최종회신완료. 현재대기는최상단참조. 현검토로DTO/field/unique/cooldown/retention90일/polling정책을자동승인하지않았고새UI/코드/서버/DB/기기시험미변경. 문서내용검토/diffcheck만·feature/scoped-account-cache/5eef0d2유지·미커밋/dev미반영/미push.

## 최신 확정 — 재도전 제한 없음·향후 운영자 귀속 고정

[계약28](../backend-migration/28-verification-client-preparation.md)에사용자두답변반영: 일반원정대방어성공후영구금지/별도재도전대기없음, 매번장비성공후24시간방어. 운영자귀속고정이면일반도전/자동이전차단·운영자만해제/조정. 현재owner와고정/프리분리·프리가소유권삭제아님. Discord문의/화면공유검증·운영자도구는후속이며현재DDL/API/서버구현범위로확대하지않는다. 동시도전은이후141번째최대3건/일괄방어/순서처리확정으로대체·APIquota/멱등유지.

[#8 시간순 138번째](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6237128139) 수정본문/순번확인. 다음Backend는최신기준반영·잔여동시정책차이정리/계약회신. 문서검토/diffcheck만·기능코드미변경·feature/scoped-account-cache유지·미커밋/dev미반영/미push.

## 136번째 기존 정책 조사 회신 완료 — Backend 차이 정리 대기

[계약28 조사절](../backend-migration/28-verification-client-preparation.md)에고정8f4209d수동/자동장비·Rules/현재Router대조를기록했다. 과거수동동일Player+원정대pendingProof중복차단은있지만분쟁awaitingOwnerResponse/서로다른회원전체동시1건서버보장은없다. 방어성공은해당도전자+원정대인증금지였고24시간cooldown아님. 취소/실패/만료후별도24시간제한없음. 새Player/재설치우회대응은과거보류. 현재신규장비경로에수동제재/24시간분쟁은미연결이다.

[#8 시간순 137번째](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6237012986)에근거/한계회신·원격본문/순번확인. 다음담당Backend는135번째제안과차이를정리해사용자선택을받는다. 이번조사로동시1건/재도전24시간/영구금지를확정하지않음. 앱내안내먼저·외부푸시후속은136번째확정. 문서diffcheck만·기능코드/서버/DB/기기시험미변경·feature/scoped-account-cache유지·미커밋/dev미반영/미push.

## 현재 작업 — 타소유 원정대 안내·24시간 챌린지 계약

사용자 지시로 [인증 계약28의 2026-10-18 절](../backend-migration/28-verification-client-preparation.md)에 요구/현재 결손·순서를 기록했다. 타인 소유 인증 시도자에게 안내와24시간챌린지가 필요하다. 현재10분장비화면은24시간분쟁구현이 아니다. 24시간은 새 시도자 장비 확인 성공 후 시작으로 사용자 확정. Backend에는 현재 DTO 결손과 상태/전이·권한·복원 API 제안을 요청했다. 기능코드를 먼저 변경하지 않는다. 135~136번째설계/기존정책조회수신후조사회신완료, 다음은Backend차이정리와남은제품선택이다. 기존 정상인증/소유권/개발자료는 보존한다.


[#8 시간순 133번째](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6236706515) 원격본문/순번 확인. 132번째 영어검색28ea022 보완 후 사용자 혼합대소문자 검색 성공 확인·결과 회신 완료. HTTP오류 조사에서 과거3건 원인은 미특정으로 유지한다.

## 원정대 등록 화면 배치 — 기기 확인 대기

미리보기 버튼 → 계정 표시명·메인 계정 선택·조회 목록 저장 → 미리보기 캐릭터 목록 순서로 이동 완료. 변경 페이지 분석0·포맷/diffcheck. 기존 preview 조건·저장 활성 조건/콜백·목록 정렬은 보존했다. 긴 목록에서도 스크롤 전 저장이 가능한지 사용자 확인만 남는다. 단순 위젯 이동으로 신규 자동 UI시험/Backend 댓글·변경 요청은 추가하지 않았다. feature/scoped-account-cache 유지·미커밋/미push/dev미반영. 상세 이력 DEV_LOG.

## 영어 대소문자 검색 — 사용자 확인 완료

사용자가 소문자·대문자를 섞은 입력으로 정상 검색되는 것을 확인했다. Flutter 입력 비교 보완/Backend132번째28ea022 보완 후 검색 실패 해소로 정리한다. [134번째 결과 회신](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6236754707) 원격본문/순번 확인. 등록/장비인증 전체·24시간분쟁 성공으로 확대하지 않고 기존 인증 반복은 요구하지 않는다. 상세 검증/경과는 DEV_LOG. 133번째24시간챌린지 Backend계약회신은 별도 대기.

## 2026-10-18 사용자 실측·질문 대조 — 주간 체크 후순위/개별 갱신 누락

새에뮬레이터실행: initialCache971ms/HTTP0, 최초roster1515ms/HTTP1중단(오류0), automaticRefresh19633ms/우리서버24요청·누적3958ms/오류0. 준비3834ms/4요청, 캐릭터5개3828/3194/2669/2642/3446ms로순차처리. LostArk직접콜/분석/로컬저장은단계경과에포함되나우리서버HTTP시간에포함되지않으므로19.633-3.958을SQL시간으로단정하지않는다. 자동뒤회원복원displayCache2603ms, activeRestore6431ms, displayReady10162ms/HTTP13, 후순위3745ms, 전체13918ms/22요청/오류0. 실제weekly는그뒤662ms/2요청이며후순위와병행한다. 계측HTTP오류0/단계ok지만사진의역할서버저장대기/모든빌드최종ACK까지성공으로확대하지않는다.

원인확인: weekly._modelChanged/refresh는model.loading동안대기하고 _characters는!cached·현재소유인visible행만대상으로한다. schema1 weeklyStore는display/pending만보존하고완료_entries는메모리이므로앱새실행의마지막확인체크캐시가없다. 체크변경권한에는현재주차/소유/서버원장검증이필요하나체크표시까지장비상세복원을기다려야할기술적필요는없다. 후속개선은현재원정대/캐릭터신원확인과상세빌드복원의준비신호를분리해weekly를앞당기고, 동일회원/현재주차마지막확인표시는서버조회성공전쓰기불가로분리설계한다. 미확인을미완료/리셋으로표시하지않는다. 이번은조사/기록이며주간정책/캐시schema를임의수정하지않았다.

MemberCharacterPage의appbar는제목만있고단일캐릭터게임상세재조회버튼/VM실행경로가없다. 기존CharacterDetailPage의‘세팅갱신’은다른구기기화면이며현재회원상세에연결되지않았다. 대표/표시설정복구와별개인기존기능누락으로확정, 복구목록에기록한다. 단순전체model.refresh나서버저장재시도를게임상세갱신으로대체하지않는다. 후속은현재회원/소유/수명/키·호출제한·동시자동작업/캐릭터계열저장·보류명령보존·페이지해제/로그아웃late차단을기존도메인과대조해단일대상갱신을연결한다.

USB실기기: Android공식adb reverse를사용하면같은WiFi없이PC8000연결가능. 사용자가USB디버깅승인후`adb -d reverse tcp:8000 tcp:8000`,`flutter devices`로실기기ID확인,`flutter run -d 실제ID --dart-define=BACKEND_BASE_URL=http://127.0.0.1:8000`을직접수행한다. 에뮬레이터기본10.0.2.2와실기기reverse주소는구분한다. 에이전트는기기설치/조작을대행하지않았다. 이번은로그/코드/공식문서조사만·기능코드미변경/시험반복없음·feature/scoped-account-cache미커밋/미push/dev미반영.

새정상HTTP실측/주간순서·개별갱신누락회신: [#8 시간순 130번째](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6236034852) 원격본문/순번확인. 두Flutter후속은미구현이며서버추가작업을임의선행조건으로만들지않는다.

## 에뮬레이터 Base URL 알럿 제거 완료

사용자지시로debug시작URL선택알럿을제거했다. BACKEND_BASE_URL명시값우선/미지정debug는http://10.0.2.2:8000을써서initState에서즉시서비스초기화한다. 기존에는알럿확인뒤초기화/API·6초타이머가시작됐고선택시간은제외였으나이제선택단계가없다. LoadTiming은여전히개별단계시작기준이며로그인복원전체/앱런치누적시간이아니다. release HTTPS검증·미설정오류/권한·원장·시작이미지/애니메이션·앱수명/최대6초규칙은불변이다.

공통bootstrap9PASS·해당분석0·format/diffcheck. 제거된알럿배경전용widget시험은대상이사라져삭제했고공통진입이미지/애니메이션/게이트검증은기존별도시험으로유지했다. 알럿없는실앱초기화에단순기대값만바꾼초기시험은nativeDrift비동기타이머를fixture가소유하지않아실패했으며그이유로정상앱실행에우회코드를추가하지않았다. 새자동시험/전체회귀반복은추가하지않았다. 사용자에뮬레이터다음실행에서URL선택없이시작되는지만확인하면된다. 이번은독립로컬시작UI변경이라Backend추가변경/반복댓글요청없음. feature/scoped-account-cache유지·기존미커밋/미push/dev미반영·서버/키/DB/배포/실기기대행없음.

## 실측 환경 추가 설명 — 서버 작업 완료 후 비교

사용자가오류3건로그의실행당시Backend작업중이었다고설명했다. 새첨부는직전측정과동일내용이므로재실행/보완진단결과로계산하지않는다. 활동복원20.429초/전체28.201초는서버작업영향가능성있는관찰이며정상성능/Flutter결함확정근거로사용하지않는다. HTTP0캐시756ms는별도보존. 현재기능/timeout/권한을추측수정하지않고서버안정후사용자새로그를대조한다. 반복기기테스트요청없음. [#8 시간순 129번째](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6235262201) 원격본문/순번검증완료.

## 현재 진단 보완 — 시작 갱신 실측의 중단/HTTP 오류

사용자새로그1회: 초기cache756ms(직전3323ms), run2 roster1883ms/interrupted·HTTP오류0/총2657ms. 한참뒤run3 roster863ms·displayCache2061ms·activeRestore20429ms/HTTP11·누적47929ms/HTTP오류3·전체28201ms/HTTP22/오류3/interrupted. weekly후속2163ms, 비활동4833ms는겹친다. 전체1회provider갱신을켜기전과이후작업범위가달라총성능직접비교는하지않는다. 초기cache는개선됐으나실제첫프레임/6초진입과전체갱신성공은현로그만으로미확인이다.

코드상source목록적용의invalidateReads가이전회원조회guard를중단할수있고runner종료후model.refresh가다시실행된다. 오류3건은종류/HTTPstatus미기록이라timeout/5xx등을확정할수없다. 자동runner가초기cache콜백Zone을상속할수있어일부시도가회원run에귀속될수있는진단경계도확인했다. 고정오류분류/상태코드(응답없음0)와automaticRefresh별도root·prepare/캐릭터상세단계진단을추가완료했다. URL/UUID/메시지/응답원문미기록, 오류재전파/기존예외·guard·요청순서/timeout/동시상한/자동ON정책불변. 관련진단/컨트롤러·회원/공통API회귀69PASS·변경3파일분석0·format/diffcheck. 계측만변경해직전전체1639시험은반복하지않는다. #8에실측/보완결과·서버보존오류응답확인을요청하고기기재실행은사용자가한다. 다음사용자는[LoadTiming] 전체(automaticRefresh/prepareRefresh/characterRefresh 및http_error행포함)를제공한다. 원인추측우회수정/서버배포/Git통합없음.

새실측/계측보완회신: [#8 시간순 128번째](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6235202558) 원격본문/순번확인. Backend보존실패응답확인및사용자새진단로그대기.

## 시작 화면 선행 준비 구현 완료 — 사용자 실행 확인 대기

기존시작이미지/2.2초애니메이션을유지하고BackendApp소유StartupEntryGate를연결했다. 세션복원완료+초기활동캐시표시준비이면애니메이션뒤메인진입, 서비스초기화후6초상한(개발서버주소입력시간제외)에도메인으로넘기고앱소유복원/1회갱신은계속한다. 인증미확정은기존비인증권한/이전회원자료비노출을유지하고한번메인진입후시작화면으로되돌리지않는다. 시작페이지는API/DB/runner를생성·dispose하지않으며binding.initialize도일회로보호한다.

최초캐시는activity캐릭터prefs/역할요약만우선복원하고비활동은기본관찰행유지. 최초표시준비신호는현재scope/세대guard뒤발행·회원변경시자료와함께리셋된다. 실앱의automaticRefreshEnabled를명시true로연결해기존runner가캐시준비뒤일회초기화되고, 키/설정/전체원정대조건성공시앱수명으로실행한다. 같은회원재로그인/탭이동재실행없음·나이스단OFF제외·소유/lifecycle/CAS/늦은편집보호는기존정책을재사용한다. 환경bool기본값/나이스단회원값은변경하지않았다. 새그룹API/마지막탭복원/DB스키마·자료이관/서버배포는미추가. 장기계약30의시작흐름절참조.

최종전체 **1639PASS·lib/test분석0·format/diffcheck**. 새7경계(준비/애니메이션/6초상한·재시작타이머불연장·회원전환·gate종료/작업독립·실제캐시먼저/초기화1회·지연조회로그아웃차단)를추가했고기존OFF/회원별1회/페이지해제·원장/편집회귀를함께확인했다. 첫분석info1개중괄호만수정후전체분석0재확인, 동작변화없어전체시험반복없음. 실제기기속도/실provider갱신·다른탭중진행은미확인이다. feature/scoped-account-cache/5eef0d2·미커밋/미push/dev미반영·기존사용자Rules/tools/플랫폼변경보존.

수동확인: ① 캐시있는로그인회원은애니메이션/캐시준비후메인, 늦으면서비스초기화후약6초에넘어가남은진행지속 ② 비로그인/키미등록·통신실패에도메인진입가능·이전회원캐시노출없음 ③ 진행중탭이동/화면재진입해도작업중단/중복없고캐릭터결과반영 ④ 로그아웃/회원변경시이전결과저장/표시없음 ⑤ 준비된키/설정에서실제원정대목록→활동상세1회·나이스단OFF예외/같은회원반복0 확인. 사용자가디버그실행[LoadTiming]행을제공하면이전12.936/16.771초와비교하되mock속도를실기기개선으로단정하지않는다. 기기설치/조작은사용자담당이다.

최신Issue: #8 126번째까지기존계정API변경없음. #12 11번째L0/fcbb840·12번째G1/73744be실행API인계접수, #13 8번째통계제안수신. G1계약소비/통계귀속검토는후속이며시작API에혼합하지않는다. 결과/접수회신링크는아래추가한다.

시작흐름결과/G1인계접수 회신: [#8 시간순 127번째](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6235003257) · [#12 시간순 13번째](https://github.com/heo0328/lostparty-backend/issues/12#issuecomment-6234990359). 원격전체재조회로본문/순번일치확인. 다음은사용자새빌드실제관찰이며그룹G1연결과통계안검토는별도후속이다.

## 로딩 진단 구현 완료 — 사용자 로그 분석 수신

기존feature/scoped-account-cache/5eef0d2·미커밋변경을보존해debug전용 [LoadTiming]을연결했다. `displayReady`까지와`inactiveRestore`/전체를분리하고캐시/roster/초기선택/활동복원·주간캐시/catalog/cycle/배치별단계의ms·실제Dio시도수·누적대기ms/오류수를기록한다. 주간복원은별도run,중첩합산주의·인증API자체카운트제외·민감정보미기록·출력실패불변을 [계약30 진단절](../backend-migration/30-scoped-storage-write-contract.md#로딩-시간-진단-2026-10-17)에기록했다. UI/조회순서/동시상한/캐시·원장·권한·flag/서버/DB는불변이다.

검증: 회원/주간/진단54PASS, 공통조회/인증/등록/보완진단63PASS(진단4개중복포함;서로다른총113개), 변경6파일분석0·format/diffcheck. schema/Router/DI/서버계약변화없이진단래퍼만추가한범위라전체1628시험은반복하지않는다. 실제기기지연원인/개선효과는아직미확인이다. 새기능코드미커밋/미push/dev미반영·기존Rules/tools/플랫폼변경보존.

### 사용자 실행 로그 수신·분석

2026-10-17 제공한 에뮬레이터 debug 1회 로그(run2): initialCache3323ms/HTTP0, roster1309ms/HTTP2·727ms, initialSelection1ms/HTTP0, displayCache1797ms/HTTP0, activeRestore6498ms/HTTP11·누적4372ms, displayReady12936ms/HTTP13·누적5099ms. inactiveRestore3830ms/HTTP9·누적3473ms, accountRefresh16771ms/HTTP22·누적8573ms. 별도weekly run1은279ms/2요청(카탈로그/주차), run3은754ms/2요청(주차/실제배치). 후자는inactive와겹치므로전체시간에더하지않는다. 모든단계ok/HTTP오류0이다.

확인: HTTP0인캐시두구간만5120ms(화면사용가능12936ms의약40%)이며활동복원이6498ms다. 로컬서버만의문제라는설명은불충분하다. 최초캐시의 _emit은3323ms후, 현재검증/활동복원완료loading해제는12936ms후이며실제프레임paint는별도다. DB오픈/쿼리/직렬화·스케줄링/프레임경합의각기여도와HTTP내네트워크/서버처리시간은현로그만으로분리하지않는다.

코드근거: _readSections는캐시·표시캐시·활동복원준비단계에서전체캐릭터의prefs/dealer/support캐시를개별순차호출한다. 각store.readCached는scope/등록/캐릭터수명검증·DBtransaction을반복한다. 이중복순차읽기는개선후보이나삭제/검증우회없이원정대단위읽기또는동일세대자료재사용을설계해야한다. 현재서버동시상한3증가·API배치신설/DB인덱스무근거추가·guard제거·캐시쓰기권한승격은하지않는다. 다음권장작업은회원/세대/소유검증을보존한캐시읽기중복최소화의한정설계후구현이며이번로그분석에서는코드를수정하지않았다. 현재실기기1회관찰을다른디바이스/전체성능으로확대하지않는다.

실측 분석 회신: [#8 시간순 126번째](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6234537650), 원격순번/본문확인. 실제초기캐시/표시캐시중복읽기최적화는후속작업이며기능코드미변경.

## 현재 설계 — 사용자/그룹 주간 통계

[설계35](../backend-migration/35-weekly-member-and-group-statistics.md)에 KST수요일06시주차·공개/그룹이용·가입그룹수·완료/미완료종료분리·함께하기수·그룹별생성/결과통계요구를기록한다. 개인수동완료는제외하고통계와Claim/현재방상태/한도는분리한다. 주중한번이라도확정참가한고유항목집계/주차를넘긴미완료회차는미완료종료집계/마감06시함께하기값으로3기준확정했다. Backend #12/#13최신9/6번째까지대조·새회신없음. 이번은설계/이슈인계만, 기능코드/DB/배포/BM/통계화면/Git통합제외·기존feature/scoped-account-cache미커밋보존.실행 완료는 아니다.

주간 통계 인계: [#12 시간순 10번째](https://github.com/heo0328/lostparty-backend/issues/12#issuecomment-6232896201) · [#13 시간순 7번째](https://github.com/heo0328/lostparty-backend/issues/13#issuecomment-6232893737). 원격 전체 댓글 재조회로 순번/본문 확인. 다음 Backend 명세/원천 이력·마감/작업 구간 제안이며, 아직 서버 기록 기능·조회 UI는 미구현이다.

## 최신 확정 — 세 한도 차원별 영향/그룹 정원 상속 예외

[설계34](../backend-migration/34-member-limits-and-room-restrictions.md)의3질문 답변 완료. 개인레이드초과→직접참가 공개/그룹레이드 제한, 개인가입그룹초과→직접참가 그룹전용레이드만 제한, 두 개인초과 모두 기존그룹운영 정상. 그룹5/5는 기존그룹레이드 정상/새그룹증가만 거절한다. **그룹자체18/15는 운영유지·신규회원확정차단·탈퇴/추방/이전허용이지만 그그룹 모든그룹전용레이드는 정지**, 그룹원일반공개레이드 무관이다. 앞선 연결방상속전면거절/정원도미전파 추천은 폐기한다. 상세 문제회원 문구/탭 현재수÷개인한도는 유지한다. Backend #12 7번째/#13 4번째 영향표와 후속8/5번째의미확정질문을 이최종기준으로 정정 요청한다. 이번은 문서/회신이며 기능코드/서버/DB/실기기/Git통합 제외, feature/scoped-account-cache 미커밋 변경 보존.

최종 답변 인계: [#12 시간순 9번째](https://github.com/heo0328/lostparty-backend/issues/12#issuecomment-6232797572) · [#13 시간순 6번째](https://github.com/heo0328/lostparty-backend/issues/13#issuecomment-6232799560). 원격 순번/본문 일치 확인. 다음 Backend 공통명세 영향표/회복표 반영·단계별 구현, Flutter 최종 API 인계 후 연결. 추가 사용자 제품결정 대기는 현재 없다.

## 대기 중 독립 작업 후보 조사 — 2026-10-17

사용자 요청은 탐색이며 기능 코드를 수정하지 않았다. feature/scoped-account-cache/5eef0d2·기존 미커밋 변경 보존. 최신 [#8 124번째](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6232557892)는 access log에 duration이 없어 서버/클라이언트 기여도 분리 불가, 자동 추가 영속 정책 설계 전이다. [#12 6번째](https://github.com/heo0328/lostparty-backend/issues/12#issuecomment-6232576104)는 계정별15/5/10·전체 관련방 차단 요구 수용/공통 계약 설계 전이며 구현 완료가 아니다. #13은3번째까지다.

- **추천 첫 작업: Flutter 복원 단계별 시간 진단 준비.** MemberAccountViewModel.refresh의 디스크 캐시→현재 roster→최초 선택 초기화(해당 시)→활동 요약 복원/화면 사용 가능→비활동 복원, 후속 주간 상태 조회의 소요시간·호출 수를 구분할 진단 설계/구현이 서버 DTO 변경 없이 가능하다. 디버그 전용·단계명/소요/건수/실패코드만 기록하고 토큰·키·이름·UUID·응답 원문은 기록하지 않는다. 실제 서버 처리시간으로 오인하지 않으며 이번 후보는 조회 병렬 수/저장 순서/권한/화면을 변경하지 않는다. 자동검증은 진단 비활성 때 동작 불변·실패/중도취소에도 기존 처리 불변·민감정보 미포함 경계에 한정한다. 이후 사용자가 기존 앱 실행으로 실제 로그를 수집하면 병목을 특정한다. 아직 이 진단 코드도 미구현이다.
- **두 번째: 기존 그룹 화면 재사용·연결 대응표 설계.** group_tab/search/create/detail 등 화면과 GroupRead/CreateRepository·GroupCharacterOptionLoader는 존재하지만 BackendApp의 그룹 route는 pending이다. 기존 탭/검색/생성/가입/상세 조작을 보존해 G1 가능 기능과 G2/G3 미지원 기능, 현재 회원/canonical UUID 후보 연결 및 기존50/50 상수·안내 제거 위치를 표로 정리할 수 있다. 서버 DTO/한도 상태 필드는 추측 구현하지 않으며 route 활성 연결은 정식 계약 인계 후다. 기존 화면을 새로 디자인하거나 로컬자료를 회원 데이터로 승격하지 않는다.

대기: 실제 그룹/모집 생성·가입/추방/회복 및 한도 조회/방 차단 쓰기, 신규/첫1700 자동 추가·수동 제외 영속화, 완료 후 잔류/다음주 i 관계 연결은 서버 계약을 받는다. 현재 전체1628PASS 결과가 있는 기존 역할·이름·원정대 주간 설정/활동 우선 복원을 다시 개발 과제로 돌리지 않는다. 이번 조사는 코드/서버 변경 없이 문서 내용 대조와 diffcheck만 수행한다. 새 댓글/반복 회신·실기기 대행·커밋/push/dev통합 없음.

## 현재 설계 — 사용자별 한도·초과 시 방 진행 제한

[설계34](../backend-migration/34-member-limits-and-room-restrictions.md)에 사용자별 계정 한도·기본 그룹15/가입5·한도 감소 후 기록 보존/진행 차단·탈퇴/추방 허용을 기록한다. 현재는 설계와 #12/#13 협업 전달만 포함하며 BM/기능 코드·DB/배포·Git 통합은 제외한다. 기존 feature/scoped-account-cache와 미커밋 변경을 보존한다. 사용자 답변으로 현재 그룹장 정원15/가입 그룹5/모든 원정대 캐릭터의 생성·참가 모집 합산10/초과 회원의 관련 방 전체 제한·정리 후 해제를 확정했다. Backend에 기존 고정15/5를 계정별 기본값으로 확장하는 요구와 차단/회복 경계를 알린다. 완료 조건은 문서/원격 댓글 확인·다음 담당 기록, 후속 구현은 최종 계약 이후다.

한도 설계 인계 완료: [#12 시간순 5번째 댓글](https://github.com/heo0328/lostparty-backend/issues/12#issuecomment-6232562970) · [#13 시간순 3번째 댓글](https://github.com/heo0328/lostparty-backend/issues/13#issuecomment-6232565592). 원격 전체 재조회로 순번/본문 일치 확인. 다음 담당은 Backend 명세/작업 구간 회신이며 Flutter 한도·제한 기능은 미구현이다.

동시 회신 대조: #12 4번째 Backend는 이전 15/5·활동 선택·검색 정정을 수용했고, #13 2번째는 현재 방 관계/점유/완료 분리를 수용했다. 이후 게시한 한도 확장(#12 5번째/#13 3번째)에 대한 구현 수용/완료 회신은 아직 아니다. 이번 숫자 기본값의 계정별 확장과 방 차단은 별도 명세 반영 대기다.

## 협업 검토 — #12 G1 명세/내부 기초 인계

2026-10-17 최신 이슈8/10/11/12/13 조회. 새댓글은 #12 1번째 명세6232074318·2번째 내부기초6232311355이며 e5e97c8/feat/raid-services 게시service/spec를 직접 대조했다. Backend118PASS 보고·HTTP/router/OpenAPI 미연결·현재개발DB0011/0012 미적용이다. 아직 Flutter 호출/기기시험 대상 API가 아니다. 이번은 계약/회신·문서만 수행하고 그룹기능 코드는 수정하지 않는다.

소비 검토: 공개 최소요약/회원상세·멤버 권한 분리와 snapshot/회원membership 보존은 현재 검색 route의 protected=false/기존 그룹흐름과 충돌없음. 기존 활동계약§6.1/GroupCharacterOptionLoader는 그룹생성·가입 표시캐릭터를 앱사용집합에서 고르므로 명세의 ‘활동선택 비필수’는 정정이 필요하다. 표시수/대표/1700 하한과는 별개이며 현재 활동집합+소유/usable을 서버transaction에서 검사한다. 검색은 기존 ‘그룹명 또는 그룹대표캐릭터명’과 검색어 공백/영문대소문자/분리한글 정규화 UX를 보존하도록 명세 보완을 요청한다. 이름/검색키를 identity로 쓰지 않는다.

사용자 추가결정: **그룹당 최대 15명·사용자당 가입 그룹 최대 5개**로 확정했다. 기존 MVP 제한없음 충돌을 정정하고 Backend 필수policy hook에 명시 기준을 연결하도록 회신한다. 앞서 선택한 50명/50개는 최신 사용자 정정으로 취소했다. 그룹 정원은 생성자/그룹장을 포함한 현재 회원 15명, 사용자 한도는 직접 생성한 그룹을 포함한 현재 가입 그룹 5개다. 종료된 membership은 제외한다. 기존 Flutter 그룹 상수/안내의 50/50은 그룹 API 연결 시 15/5로 정렬할 미구현 항목이다. 제한 미확정을 이유로 G1이 계속 보류되지 않도록 상태/담당을 명확히 한다. 다음 Backend는 HTTP/목록·cursor/OpenAPI·현재환경 반영 후 인계, Flutter는 게시된 최종계약을 소비한다. 새실행/DDL 적용·그룹화면 구현/실기기·Git통합/이슈종료는 이번 회신범위가 아니다.

회신 완료: [#12 시간순 3번째 댓글](https://github.com/heo0328/lostparty-backend/issues/12#issuecomment-6232491349)에 최종 15/5, 활동 선택 필수·검색 UX 대조와 다음 Backend HTTP 구간을 게시했다. 원격 전체 댓글 재조회로 순번/본문 일치를 확인했다. 다른 확인 이슈에는 새 회신이 없어 중복 댓글을 달지 않았다.

## 현재 작업 — 기존 역할/이름/원정대 주간 설정 복구·사용 캐릭터 우선 복원

Flutter 구현·최종 전체 **1628PASS·lib/test분석0·format/diffcheck** 완료. 캐시 요약 표시·활동 summary 최대3병렬 우선·비활동은 캐시에만 반영·편집 시 늦은 결과 무효화,4직업 직접 역할선택/일반직업 딜러만·12자2줄 이름·원정대 주간 개수 일괄 설정을 연결했다. 기존 개인 완료/i·overlay/권한·멱등·설정/대표는 보존했다. 실제 기기 표시/속도·역할/일괄설정 재진입은 사용자 확인 대기다. 새 자동 추가는 아직 실행하지 않으며 [#8 122번째 서버 계약 요청](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6232394235)의 원격 본문/시간순 순번 확인·회신 대기다. 실제 provider 갱신/자동flag 변경과 저장요약 복원을 혼동하지 않는다. feature/scoped-account-cache/5eef0d2·미커밋/미push/dev·main미반영·기존 사용자 자료 보존. 결과 회신 링크는 아래 추가한다.

결과 인계: [#8 123번째 복원/UI 결과](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6232443346)·[#11 6번째 일괄표시 복구 결과](https://github.com/heo0328/lostparty-backend/issues/11#issuecomment-6232443478) 게시 후 원격 본문/순번 일치 확인. 다음 사용자 수정 빌드 이름·역할·일괄표시와 초기/후속 대기 확인, Backend는 #8 121번째 시간 조사·122번째 신규/최초1700·수동제외 영속 계약 회신이다. #13 방 관계/i 후속은 별도 유지한다.

2026-10-17 사용자 요청/선택 확정: 역할 선택은 바드/도화가/홀리나이트/발키리만 딜러·서포터 직접 선택, 나머지는 딜러 고정/불필요한 선호역할·서포터 빈칸 미노출. 기존 캐릭터 표시 설정은 보존한다. 이름은 최대12자 기준 원문 전체를2줄 내 글자크기 조절/고정영역으로 표시하고 왕관은 보존한다. 기존 원정대 주간레이드수정 버튼/0..5 일괄 설정을 회원별 저장소에 복구한다.

조회 설계: 캐시→서버 canonical목록/표시→사용 캐릭터 summary 우선→비사용 summary 후순위, summary GET 최대3개 동시 처리. 원정대/canonical 소유 전체목록 검증은 유지한다. 비사용 캐릭터의 후순위 결과는 캐시에만 반영해 사용 중인 화면/열린 편집값을 덮어쓰지 않는다. 실제 쓰기/관리·회원전환/관찰세대 변경 때 후순위 guard를 무효화한다. 마지막 서버 요약은 표시 자료로 사용하되 캐시를 현재 쓰기 권한으로 승격하지 않는다. visible만이 아니라 activityIds 전체를 우선한다. 백그라운드 전체 network완료 전 사용캐릭터 단계 완료 시 loading을 해제하고 별도 restoring 진행만 AppBar overlay에 표시한다. 로스트아크/provider 호출·자동runnerflag 변경은 이번 복원 최적화와 분리한다.

자동 추가 확정: 새로 발견되거나 최초1700 도달 캐릭터만 추가, 사용자 명시 해제 제외. 현재 저장 계약은 해제출처/과거 기준을 구분하지 못하므로 이름/기기 캐시만으로 추측해 전체설정을 자동저장하지 않는다. Backend에 회원/원정대별 제외 보존·최초도달/발견 기준·멱등/CAS·기기 간 복원을 요청하며 해당 서버 계약 제공 전 자동 추가는 미완료로 둔다. 기존1700 최초선택/수동저레벨/대표·순서·표시수는 유지한다.

순서: 현재 UI/Domain/원장·DI/캐시원자성 대조→UI복구·주간일괄영속화→활동우선/병렬/후순위중단→경계테스트·영향범위 전체test/analyze→문서/관련#8/#11 인계. 회귀: 역할정책/정밀값·개별주간선택·일괄실패 rollback·다른회원/설정변경 late·활동0/초기선택·순차CAS/권한/제한·비사용결과의UI덮어쓰기0. 기존 feature/scoped-account-cache/5eef0d2·미커밋/사용자 자료 보존, 새 API·DB/schema/자료이전·자동flag/배포·기기조작/Git통합은 제외한다.

## 최신 정정 — i는 남아 있는 모집방 참가 관계만 표시

Flutter 잘못된 party근거 i 제거·현재 participation i 유지 완료, 관련18PASS·변경2파일분석0·format/diffcheck. [#11 5번째 정정 회신](https://github.com/heo0328/lostparty-backend/issues/11#issuecomment-6232280275)·[#13 1번째 기존 방 관계 계약 요청](https://github.com/heo0328/lostparty-backend/issues/13#issuecomment-6232280402) 게시 후 원격 본문/순번 일치 확인. 다음 담당 Backend #13 방 membership 조회 계약/구현, 이후 Flutter 완료 후 잔류·반복방 i 연결이다. 개인 완료는 현재 사용 가능하며 전체 방 관계 구현은 미완료로 구분한다. feature/scoped-account-cache·미커밋/미push/dev미반영 보존.

사용자 기존 정책 재확인: 미완료 참가 대기/진행 방, 이번주 완료 후 해산 전 방, 다음주 함께하기의 유지된 참가 관계에는 i를 표시한다. 수동 완료/파티 완료 근거만으로 i를 만들지 않고 해산·탈퇴로 참가 관계가 끝나면 완료 체크와 무관하게 i를 제거한다. 직전 ‘파티 완료 근거 안내’ 해석은 잘못됐다. 체크(주간 완료)와 i(현재 방 관계)는 독립이다.

최소 수정은 현재 Flutter party 완료근거만으로 info를 만드는 투영 제거·현재 participation 안내 유지다. 현 #11 첫 DTO는 완료근거와 participation의 동시 존재를 금지하므로 완료 후 잔류 membership/다음주 유지 관계를 완전히 표현하지 못한다. 이를 완료근거로 추정하거나 strict DTO를 임의 완화하지 않는다. 기존 #13 파티/반복방 조회 계약에 현재 membership과 주간 점유/완료 분리 요구를 회신하며 서버 계약 인계 후 완료 후 i 연결을 진행한다. 새 UI/서버 기능 전체 착수·완료근거 삭제·권한/저장 변경은 제외한다. 기존통신 overlay/배치 보호 유지, 관련18경계 검증·분석/diffcheck와 #11 정정 회신 후 실제 미구현 범위를 명시한다.

## 현재 — 수동 체크 UI 회귀 수정 완료·기기 확인 대기

사용자 실제 체크→알럿→완료 처리 성공 보고를 수신했다. 본문 통신 진행바/정상 pending 삽입·일반 manual의 i를 제거하고 타이틀 내부 고정 overlay로 진행을 옮겼다. PUT→후속GET→정리의 단일 busy 범위와 편집아이콘 자리 유지로 전체 행의 i/본문 움직임을 막는다. 마지막 확인 체크만 표시하고 서버 확인 전 중복 변경은 계속 차단한다. 최종 관련 **47PASS+카드/기존페이지16PASS=63PASS·변경5파일분석0·format/diffcheck**. 서버/Router/DI/schema는 바꾸지 않아 전체1622시험은 반복하지 않았다. 이번 새 빌드의 실제 기기 꿀렁임/i 제거·타이틀 표시 확인은 사용자 담당이다. 초기 로딩 지연 조사는 아래 별도 대기이며 이 UI 수정으로 서버 속도 해결을 주장하지 않는다.

feature/scoped-account-cache/5eef0d2 유지·미커밋/미push/dev·main미반영·기존 변경 보존. [#11 4번째 Flutter 실제 성공 수신/회귀 수정 결과](https://github.com/heo0328/lostparty-backend/issues/11#issuecomment-6232264894)를 게시하고 원격 본문/순번 일치 확인. Backend 추가 구현/재검증 요청 없음.

### 이번 수정 설계

2026-10-17 사용자 완료 체크 실제 성공 보고·UI 회귀 수정 승인. 원인은 writing/후속GET 중 ready=false를 전체 행의 ‘확인 필요’ tooltip으로 연결하고, normal manual 완료도 completed info로 표시하며 본문 진행바/정상 pending 문구·편집버튼 제거가 배치에 영향을 준 것이다. 서버 저장 권한과 현재GET 검증은 유지하고 마지막 확인 표시와 통신 진행 표시를 분리한다.

포함: 내 계정의 회원/주간 통신 표시는 AppBar 내부 하단 고정 overlay(터치 통과·높이 변화0)로 이동, 정상 PUT→GET→명령정리 동안 본문 안내 삽입 금지·체크/편집 영역 유지, 일반 수동 완료/미완료의 불필요 i 제거. 파티 근거/실제 오류 안내와 실패 복구·중복 쓰기 차단·동일키/회원/주차 경계는 보존한다. 기존 회원 화면과 VM의 한정 수정이며 실제 요청 순서/범위 최적화·서버/API/권한/탭 리디자인·자동flag/Git통합은 제외한다. 이전 로딩 지연 조사/#8 회신 대기는 별도 유지한다. 기존 feature/scoped-account-cache·미커밋 변경 재사용/보존.

회귀 보호/완료: 정상 수동 체크→확인·해제 전후 last-known 표시/레이아웃 동일, 저장 중 중복0·비대상 tooltip 변화0, 실패하면 기존 값/복구 유지, 세션late·주차/CAS/party 근거 회귀를 표적 검증하고 관련 분석·format/diffcheck 후 #11에 사용자 실제 성공/수정 결과를 회신한다. 기기 설치/조작은 사용자 담당이다.

## 현재 조사 — 앱 시작·내 계정 상단 로딩 지연

2026-10-17 사용자 로그/지연 조사 요청. 기능 코드·디자인 변경 없이 현재 요청 경로와 서버 실측을 대조한다. 제공 EGL app_time_stats/ApkAssets는 HTTP 소요시간이 아니다. 호스트127.0.0.1:8000 공개GET 실측은 catalog200/3.541ms·cycle200/2.403ms이며 에뮬레이터 경로/인증 API 전체 지연으로 확대하지 않는다.

MemberAccountViewModel.refresh는 loadMemberRoster 뒤 각 원정대 presentation/메인 representative 및 전체 캐릭터 personal-profile을 순차 복원한다. 숨김/미선택 캐릭터도 포함하며 model.loading은 전체 복원 동안 유지된다. 이후 MemberWeeklyViewModel이 catalog→cycle→weekly 배치를 읽는다. 공개 응답만으로 서버 전체 문제를 확정하지 않는다. [#8 121번째 조사 요청](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6232169604)의 원격 본문/순번을 확인했고 Backend 최근 실제 읽기 요청의 서버 처리/반복/오류 시간 회신 대기다. Flutter 누적 순차 GET/기기 캐시 처리와 구분한다. 사용자 토큰/재인증·기기 대행·DB/자료/설정 변경·무근거 병렬화/새 API는 제외한다. 현재 feature/scoped-account-cache·기존 미커밋 변경 보존.

## 현재 — 기존 주간 체크박스 서버 연결 코드 완료·기기 확인 대기

기존 카드에 공개 카탈로그/주차·본인 주간 상태·개인 완료/정정을 연결했다. 기존 추천/선택·카드 배치·설정 진입은 유지한다. 최종 전체 **1622PASS·lib/test 분석0·format/diffcheck**. 계약/저장 수명과 범위는 [연결33](../backend-migration/33-weekly-raid-flutter-integration.md), 완료 상세는 DEV_LOG다. 표시할 레이드 설정은 회원/환경별 이 기기 보관이며 완료 원장은 서버 저장이다. 실제 회원 서버 쓰기/기기 확인은 아직이다.

인계: [#10 3번째 Flutter 결과](https://github.com/heo0328/lostparty-backend/issues/10#issuecomment-6230533662)·[#11 3번째 Flutter 결과](https://github.com/heo0328/lostparty-backend/issues/11#issuecomment-6230533862)·[#8 120번째 정책 수신 회신](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6230534018) 게시 후 원격 본문/시간순 순번 일치 확인. 추가 Backend 수정 요청/Issue 종료 없음. 다음 담당은 사용자 기기 확인, Backend #12 독립 진행·#13 파티/점유 후속이며 현 주간 개인 완료 연결을 서버 대기로 되돌리지 않는다.

다음 사용자 확인: 기존 카드 체크/취소·개인 완료 해제·재진입 복원, 표기 레이드 선택/0개 숨김. 실제 파티 연결/참가 중 영향 확인·전체 완료는 후속이며 자동 상세 갱신 flag false 유지. 로그인/키/장비 인증 반복 또는 개발자료 초기화 없이 현재 환경에서 진행한다. feature/scoped-account-cache/5eef0d2·미커밋/미push/dev·main미반영·브랜치 유지.

## 이번 작업 설계 — 기존 주간 체크박스의 카탈로그·주차/서버 원장 연결

2026-10-17 사용자 진행 승인. #10 2번째 d7f762f/31PASS, #11 2번째 bce6133/83PASS·현재8000 반영 보고를 소비한다. 기존 feature/scoped-account-cache/5eef0d2와 미커밋/사용자 자료 보존. 분야별 신규 기능이 아니라 한 사용자 흐름(기존 카드 주간 체크)의 공개 카탈로그/서버 주차→본인 상태→완료/정정 연결을 묶는다.

순서: DTO/공개 무인증 조회·기존 projector 연결 → 앱 소유 회원별 주간 controller/저장소 → MemberAccountPage 기존 카드/체크·표시 편집 연결 → 세션/주차/배치/멱등/원자응답 검증·분석/전체회귀·#10/#11 결과 회신. 신규 화면/임의 레이아웃 변경 없이 카드/하단 영역·기존 선택/대표/외부설정 유지.

데이터/권한: 서버 UUID와 세션·환경으로 조회/쓰기, 캐릭터50개 배치 상한·카탈로그 전체 raid 조합/누락/중복과 주차/version 일치 검증. 저장 요약과 체크를 기기 공용 local int ID로 쓰지 않는다. 공개카탈로그는 로그인/개인키 없이 조회하며 private 원장은 기존 Bearer transport를 사용한다. GET 실패를 미완료로 표시하거나 체크 허용하지 않는다. 서버 cycle UTC/KST 시작일·경계 이후 재조회·늦은응답 차단.

수명: app 소유 controller에 현재GET/실행중 상태, 회원+환경별 secure store에 주간 수동 명령 key/body/시작시각과 표시 설정만 보관한다. 전송전 저장·응답유실 동일키 재전송·24시간/Retry-After·충돌 후 재조회, 다른회원/환경 late 응답과 보관결과 분리. 성공ACK는 현재GET과 구분하며 현재 주차/현재 소유를 재확인한다. 표시 preference는 기존0..5/레이드 선택·기본3 추천UI 재사용, 서버표시 API가 없으므로 이기기 회원별 설정이며 새기기 복원 기능으로 주장하지 않는다.

포함: 비점유 개인 완료 true·manual 근거 정정 false. party근거/현재점유 보존·확정결과서버기준. 미지원 PARTICIPATION_CONFIRMATION_REQUIRED는 짧게안내하고 자동탈퇴/자동확인 없음. 새 파티/그룹/전체완료/영향확인 API·공용자동flag ON·자료이관/초기화·서버배포·실기기대행은 제외한다. 기존 저레벨서버반영/조회지연 미확인은 별도로 유지한다.

회귀보호: 원래카드/왕관/주간영역·선택/대표/표시·설정, API실패시거짓미완료없음, 캐릭터잘못된섞임/부분배치/카탈로그변경/주차경계·완료manual/party구분·중복요청/replay·장치재실행/회원전환·제한대기·권한상실. 테스트는실기기로확인하기어려운경계중심이며이번DI/공용투영영향으로최종전체test/analyze실행.

## 내 계정 왕관 — 시각 조정 완료

비선택 왕관만 기존 대비 불투명도50% 적용. 선택 대표/터치·변경과 관리 페이지는 유지, 관련2파일 분석0·format/diffcheck. 실제 흐림 정도만 사용자 확인 대기이며 기존 저레벨 서버 저장/통신 보완 대기는 아래 그대로다. 기능 브랜치 유지·미커밋/미push·dev미반영.

## 직전 — Flutter 보완 완료·저레벨 서버 반영 인계 수신

최신 [#8 119번째 Backend 완료 인계](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6230483893)를 확인했다. d33f873/feat/raid-services push·기존8000 반영 보고, 활동20PASS와 직접영향244PASS는 별도 실행이다. 게시 activity_policy/OpenAPI를 직접 대조해 수동 하한 제거/lifecycle·claim 유지·초기1700 분리를 확인했다. HTTP DTO 변화 없이 Flutter 추가 parser 변경은 불필요하다. 서버 선행 대기는 해소됐고 실제 저레벨 선택/대표 저장·재진입/속도는 사용자 기기 확인으로 남는다. 아래 ‘대기’는 요청 당시 경과이며 최신 현재 상태가 아니다.

최종 **1605PASS·lib/test 분석0·format/diffcheck**. 원정대 전체/1700 미만 수동 선택·초기1700 분리, 관리 나이스단 제거/외부 유지, 저장 드래그 변경분만P2·ACK 현재목록 재사용·뒤로 전체조회 제거를 구현했다. 같은2캐릭터 저장 요청은22→9회이며 실기기 시간측정은 아니다. 메인 대표GET1회 외 전체 회원profile 재복원 없음. 현재 세션/generation의 gateway 확인 자료와 캐시 구조/전체 캐릭터 일치를 검사하고 무효 디스크 캐시는 현재 권한으로 승격하지 않는다.

다음 담당: Backend는 [#8 115번째 정책 요청](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6230281148)의 활동 자격/대표·V1/V2 projection 레벨 분리와 적용 SHA/실행 반영을 회신한다. [116번째 Flutter 결과 댓글](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6230345749) 게시, #13 본문 하한도 정정했다. 서버 미반영 상태에서 낮은 레벨 실저장 통과로 보지 않는다. 사용자 기기 확인은 서버 반영 후 저레벨 선택·저장/재진입, 기본 선택1700·원래 선택/대표 유지, 나이스단 관리내미노출/외부 유지, 저장/단순복귀 속도를 확인한다. 실제 외부 API 지연/기기 시간과 예전 조회 실패 원인은 아직 미확인이다. feature/scoped-account-cache·미커밋/미push·dev/main 미반영 유지.

2026-10-17 사용자 승인: 원정대 전체 캐릭터 표시/현재 유효 본인 캐릭터는1700 미만도 수동 사용 선택,1700은 최초 기본 선택에만 적용한다. 관리 페이지의 나이스단 설정 제거·외부 설정/표시 설정 유지. 현재 Backend activity_policy.eligible/require_eligible도1700을강제하므로 기존#8에 정책 변경/서버 보완을 요청한다. 서버 반영 전 실저장 성공으로 표시하지 않는다. 레이드 입장레벨·소유/lifecycle 차단은 유지한다.

통신 조사 근거: gateway.load의 회원 전체목록/원정대·presentation/캐릭터profile 순차조회, save의 전후 loadMemberRoster+선택 캐릭터별P2 순서/presentation sync+마지막_load, onSaved 회원전체refresh, openCharacters의뒤로복귀 전체refresh다. 포함은 대상 원정대 조회 재사용·변경 없는 P2쓰기/재조회와 단순복귀 조회 제거이며 fresh현재GET/권한·revision·동일명령복구·미완료 보존을 우회하지 않는다. 회귀 목록은저레벨수동선택/초기1700/실종차단·소유상실/응답유실/설정충돌·불변외부표시·서버GET회수/취소0쓰기다. 실제 네트워크 지연 시간은 기기에서 미확인이므로 코드 호출수와 실측을 구분한다.

## Backend 분야별 선행 요청 — #10/#11 첫 구간 수신·#12/#13 후속

#10 2번째와 #11 2번째는 게시 구현/개발 API 반영 인계다. 위 주간 체크 연결에서 소비했고 실제 파티/그룹·점유 중 완료/전체 완료와 기기 인수는 포함하지 않는다. 아래 회신 대기는 최초 게시 당시 이력이며 #10/#11 첫 구간의 현재 상태로 해석하지 않는다.

[#10 공통 카탈로그](https://github.com/heo0328/lostparty-backend/issues/10) → [#11 주간 상태](https://github.com/heo0328/lostparty-backend/issues/11)·[#12 그룹](https://github.com/heo0328/lostparty-backend/issues/12)(독립 진행) → [#13 모집·파티](https://github.com/heo0328/lostparty-backend/issues/13). 4개OPEN/본문 일치 확인. [#8 114번째 댓글·순서 인계](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6229923232), 상세 인덱스/미확정 분리는 [32 선행 요청](../backend-migration/32-backend-domain-prework-requests.md). 다음 담당 Backend는 분야별 명세/독립 구현을 해당 이슈에 회신한다. Flutter 기존 기기 확인/미확인 조회 오류는 아래 그대로이며 이번 요청을 이유로 모두 대기하지 않는다.

2026-10-17 사용자 승인: 세부 UX 보완과 병행할 수 있도록 확정 제품 규칙만 추출해 공통 카탈로그·주간 상태·그룹·모집/파티의 선행 명세/구현 요청을 분야별 새 이슈로 게시한다. 기존 이슈 전체 및 #8 최신113번째, Backend main860c84a/OpenAPI를 대조했다. 기존 계정·설정/키·캐릭터 API를 중복 요청하지 않고 #8 생명주기/분쟁은 기존 추적을 유지한다.

포함: 자립적인 이슈 본문에 행위/조회·최소 필드·권한/원자성·식별자·완료 조건·의존 순서·미확정 항목을 기록한다. endpoint/SQL 최종 계약은 Backend 소유이며 제안 경로를 확정 계약처럼 강제하지 않는다. 먼저 분야별 명세/서버 구현을 진행하고 Flutter 활성 연결은 후속 검토다. 완료 기준은 실제 생성 이슈 링크/본문·상태 확인 및 협업 순서 인덱스다.

제외: UI 구현/기존 코드 수정·자료 이전·현재 환경/DB 초기화·배포·기본flag 변경·실시간/푸시·운영자/분쟁 신규 기능 일괄 착수. 현재 개발환경에서 진행하고 베타 직전에만 자료 초기화한다. 상세 제품 문서의 과거 저장 기술/자료 승계 요구는 전달하지 않는다.

충돌은 숨기지 않는다: MVP의 무제한 그룹/누구나 전체 완료 문구와 상세 제품/현재 Domain의 그룹50·책임자 전체 완료가 다르다. 그룹50/회원50은 현재 코드 기준안으로 표시하되 최종확정으로 단정하지 않고 한계값 고정/전체 완료 권한의 운영 활성화는 확인 후다. 종료시간 불명확 일정의 기본값·새 승인정족수·주간 표시/새 API 세부는 별도 확인하되 독립 기초 명세/구현은 진행하도록 요청한다.

## 계정 도구 UI 정리 — 코드 완료·화면 확인 대기

범위: 계정 도구 버튼과 나이스단 설정을 하나의 카드 안에 상시 표시하고 접힘 항목 제거. API 관리·사라진 캐릭터명 기록으로 이름 통일, 서버 저장 정보 GET 재조회 버튼의 범위를 이름에 명시한다. 저장/권한/자동 실행 flag·회원값은 변경하지 않는다. 회귀 보호는 설정 조회/저장·회원전환/응답유실 경계와 기존 카드/진입 콜백이다. 화면 정리와 설정 경계 기존 검증·분석/diffcheck로 확인하며 전체 시험을 불필요하게 반복하지 않는다.

구현/검증 완료: 계정 도구 카드에 접힘 없이 상시 표시, ‘로스트아크 API 관리’/‘사라진 캐릭터명 기록’/‘서버 정보 다시 불러오기’로 진입/화면 이름을 통일했다. 기존 설정·회원·조회 경계 **52PASS·lib/test 분석0·format/diffcheck**. 저장/API/자동 실행 동작 변경 없음. 실기기 그룹 배치/이름·수동OFF 후 재진입 유지 확인은 사용자 담당이며 현재 계정 ON 변경 이력은 미확인이다. UI 수정만으로 Backend 추가 회신/반복 검증을 요구하지 않는다. 기존113번째 계약/미커밋·미push 상태 유지.

나이스단 기본OFF는 Backend main 모델/서비스와 Flutter fallback에서 확인했다. ON 화면은 서버 GET true 표시 경로이며 실제 회원의 변경 이력은 미확인이다. 임의 OFF 저장·자료 초기화 없이 사용자가 직접 조작하도록 유지한다. Issue8 최신113번째, API 변경 없음.

## 최신 결과 — 사용 선택·표시 UX 코드 완료 / 기기 확인 대기

[113번째 Flutter 결과](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6229801409) 게시·본문/순번 확인. 최종 **1601PASS·lib/test 분석0·format/diffcheck**. 아래 승인 범위 구현 완료. 새 Backend API 요청 없음. 기존 configured 선택은 유지하고 최초 unconfigured만 전체 유효 캐릭터/최고 레벨 대표를 저장한다. 새 흐름/기존 보존·실패 경계 상세는 DEV_LOG와 계약30에 기록했다. 미커밋·미push·dev/main 미반영 상태다.

사용자 기기 확인: ① 표시 수1..사용 선택 수 조절/취소(선택1명은 고정) ② 표시 설정 음영·활성/비활성·드래그 저장/재진입 ③ 최초1700 기준 전체 기본 선택·기존 선택 미변경 ④ 내 계정 카드→캐릭터 상세 직접 진입, 전체 목록은 기존 등록 관리에서 확인.

실제 조회 실패 원인은 미확정이다. 최신112번째와 Backend main의 V2/설정 구현을 대조했으나 API 변경 없음. 등록 관리→원정대 캐릭터에서 재현되면 디버그 `Roster read failed: code=..., status=...` 한 줄을 확보해 원인을 판별한다. 실패/캐시를 현재 소유 권한으로 승격하지 않았고 인증을 다시 요구하는 잘못된 안내만 정정했다.

## 현재 작업 — 사용 선택·표시 UX 복구 (2026-10-17)

사용자 승인 범위: 사용 선택 수를 상한으로 하는 표시 수 슬라이더(0명은 선택 안내, 1명은 고정), 음영 행/활성·비활성 라디오/드래그 표시 순서, 대표 우선·나머지 아이템레벨 기본 정렬. 초기 설정이 unconfigured일 때만 현재 소유/전체 조회·공통1700 자격을 충족한 전체 캐릭터를 기본 선택하고 최고 레벨 대표를 기존 명령으로 저장한다. configured/needs_reconfiguration·사용자 선택은 덮어쓰지 않는다. 응답 유실은 기존 gateway 명령을 보존한다.

내 계정의 중복 원정대 목록 진입을 제거하고 기존 카드 상세 직접 진입과 관리 경로는 유지한다. 관리 목록 페이지의 잘못된 소유 안내를 정정하며 조회 실패는 권한을 우회하지 않고 원인을 조사한다. Issue8 최신112번째까지 API 변경 없음(Backend110번째 계약 유지).

회귀 보호: 취소 쓰기0, 회원 전환/늦은 응답 차단, 불완전 목록 초기화 금지, 설정 완료 재초기화 금지, 소수 원본/정수 표시·기존 카드와 하단 영역·대표/활동 저장/대기 보존. 기존 API·UUID·권한/버전 정책을 재사용하며 서버/자료/flag 변경은 제외한다. 구현 후 관련 경계 검증·분석·diff 검토, 결과/미확인 기기 항목과 실제 API 실패 근거를 기록한다.

## 직전 — 표시 인원수 취소·기존 카드 회귀 복구 완료

2026-10-17 사용자 보고의 포커스 입력 후 취소 오류를 수정 전 재현했다. showDialog 반환 직후 컨트롤러를 폐기해 닫힘 애니메이션 중 TextField가 이미 폐기된 컨트롤러를 사용하는 것이 첫 원인이었고 `_dependents.isEmpty`가 이어졌다. 표시 수와 같은 구조의 캐릭터 표시 설정 입력을 route가 소유하는 TextFormField로 변경했다. 취소/뒤로/바깥 닫기 쓰기0·표시 수 유지 검증 완료.

회원 화면은 기존 AccountCharacterCard와2/3/4열 배치를 재사용하도록 복구했다. 하단 주간 레이드의 기본3행 공간/후속 체크박스 영역을 보존하며 미연결 상태를 가짜 체크값/쓰기 기능으로 만들지 않는다. 기존 왕관·상세/회원 UUID·캐시/설정·정수 표시와 원본 정밀도는 유지한다.

최종 전체 **1,598PASS·lib/test 분석0·format/diffcheck**, [112번째 회귀 결과](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6229647060) 본문/순번 확인. 새 Backend 요청 없음. 다음은 수정 빌드에서 표시 수 창 취소/뒤로/바깥 닫기·카드/하단 영역·대표 왕관/상세 진입 확인이다. 직전111번째의 자동1596PASS만으로 기존 디자인과 취소 실기기 통과까지 확정했던 해석은 정정한다. 미연결 기능 때문에 원형 UI를 축소하지 않는 기준을 ai_rules에 추가했다.

## 직전 완료

2026-10-17 사용자 구현 지시로 **R1/R2 구현·R3 자동 검증 완료**, 실기기 확인 대기다. 기존 Backend API가 범위를 충족해 새 이슈를 등록하지 않았다. [110번째 Backend](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6228957999)의 통합860c84a/계약19c2dcc를 재확인했고 [111번째 Flutter 결과](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6229534730)를 게시·본문/순번 확인했다. 장기 설계는 [저장 계약30](../backend-migration/30-scoped-storage-write-contract.md#회원-화면관리-진입서버-복원-연결-설계-2026-10-17), 상세 검증/경과는 DEV_LOG다.

기본 빌드의 로그인 회원은 회원 주목록/캐시에 연결했다. 서버 목록·canonical 캐릭터·역할 요약/표시 설정 복원은 키 없이 가능하며, 구 기기 공용 자료와 이름 병합하지 않는다. 기존 자동 실행 flag false를 유지하고 runner 초기화·AppShell/관리·진행 UI를 분리했다. provider 제한 중에도 서버 GET 복원이 가능하고 실제 서버429는 Retry-After를 지킨다.

본→부원정대→계정 도구 순서를 유지하고 이름 수정·owned 캐릭터 관리 진입을 복구했다. 기존 이름 편집 알럿/쓰기 명령을 공용화했다. 인증은 이름 바로 오른쪽 축소 버튼·긴 이름 최대2줄/터치영역48px, owned는 숨김이다. 조회 중에는 관리 아이콘을 없애지 않고 비활성화한다.

직전 R1/R2 전체 **1,596PASS·lib/test 분석0**는 이전 검증이며 이번 회귀 복구의 최종 결과는 위1598PASS다. 새 실제 기기의 캐릭터·설정 복원과 관리 저장은 아직 미확인이다. 이전 새 기기 목록·인증 상태 사용자 통과는 유지하고 이번 전체 흐름 통과로 확대하지 않는다.

## 다음 사용자 확인 — 한 번에 수행

1. 기존 기기 공용 원정대가 있는 기기에서 같은 회원 로그인: 서버의 본/부원정대·캐릭터가 주목록에 나타나고 구 공용 목록이 섞이지 않는지 확인한다. 키 없이도 저장 요약·표시 설정이 복원되는지 본다. 서버에 없는 상세 원본은 ‘상세 조회 필요’로 표시된다.
2. 본/부원정대 이름 수정·취소 후 재진입, 현재 이름/자동 이름과 기존 메인 여부가 유지되는지 확인한다. 현재 이름 제한40자다.
3. 인증된 원정대 ‘캐릭터 관리’에서 활동/대표·표시 순서/개수 저장→이전 화면/재진입 반영을 확인한다. 활동0이어도 관리 진입 가능하며 1700/소유 자격 정책을 유지한다.
4. 미인증/소유상실의 인증 버튼이 이름 바로 오른쪽인지, 긴 이름/큰 글꼴에서 이름이2줄·버튼/아이콘과 겹치지 않는지 확인한다. 현재owned에는 재인증 버튼이 없어야 한다. 인증 성공의 이전페이지 복귀를 보존한다.
5. 로그아웃/다른 회원 전환에서 이전 회원 목록·열린 편집창이 남지 않는지 확인한다. 부분 조회 실패는 이전 확인 자료/실패 표시와 재시도를 사용하며 자료를 삭제하지 않는다.

기기 설치·조작은 사용자 담당이다. 이 확인을 위해 앱/자료 초기화·반복 장비 인증을 필수로 요구하지 않는다. 기본 자동 실행 OFF는 유지되므로 이번 단계에서 자동 상세 갱신이 실행된다고 안내하지 않는다.

## 후속·제외

기본 자동 실행 ON·전체 앱1회 provider/상세 실인수는 별도다. 기존 opt-in true의 전체목록선행·회원별1회·나이스단OFF/역할저장·미완료 재시도는 자동 회귀로 보존했다. 분쟁/소유 이전·자동퇴역/파티·그룹·새 API/DB/schema·Firebase 자료이관/삭제·서버/키/자료/환경/배포는 추가하지 않았다. 실제 계약 모순이 발견되면 사용자 지시대로 필요한 Backend 작업만 별도 새 이슈에 요청한다. 현재 추가 Backend 대기는 없다.

## Git

feature/scoped-account-cache HEAD5eef0d2 유지. 이번 코드·테스트·설계 문서는 **미커밋·미push·dev/main 미반영**이며 기존dev/main동일시점5eef0d2는 그대로다. 사용자 Rules 백업/tools와 기존 플랫폼 registrant 변경3개를 해시 확인 후 보존, 브랜치 유지. 실기기 결과 수신 후 해당 범위만 보완·기록하며 별도 지시 없이 Git 통합/배포·Issue종료를 수행하지 않는다.
