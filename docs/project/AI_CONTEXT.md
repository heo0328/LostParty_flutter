# AI CONTEXT — 2주 레이드 현황 기획과 현재 구현 상태

기준: 2026-10-23. **F1~F5 코드/자동검증을 마쳤고 사전 참가 표시/선택까지 연결했다.** Backend07c2b671/168경로 소비·표시최종4파일106mock PASS·변경Dart11파일 분석0이다. 과거 F5 독립130 기록과 합산하지 않는다. 실제 정상인증HTTP·실회원/실기기 인수와 F6-B/C는 미확인/미구현이다. F6-A manual v2/구pending 보존은 §37.20에 구현/검증했고(7파일108mock·5Dart분석0), 다음 첫구간은 NEXT_WORK의 F6-B다. B/C와 실제인수는 미완료다.

## 현재 우선 기준

- 제품 정책 원본: [설계37 현재 기준·§36](../backend-migration/37-raid-scheduling-and-multi-raid-planning.md). 흐름 지도는 [핵심 사용자 흐름](../feature-definitions/LOSTPARTY_CORE_USER_FLOW_OVERVIEW.md), 즉시 실행 계획은 [NEXT_WORK](NEXT_WORK.md)다.
- 언제든 이번 주 C/다음 주 N 직접 선택. 서버 KST 수06시 전환·해당 수10시 이후 완료 허용. 내 계정/생성/목록/참가·신청에 주차 선택, 같은 방의 열린 두 회차는 상세 탭으로 표시한다.
- 기존 참가자는 다음 주 참가 선택 시 같은 캐릭터/역할로 즉시 확정하며 재승인 없다. 중복 충돌 시 기존 B는 유지하고 A는 미선택/무점유, 대체 캐릭터 참가·기존 방 확인·닫기를 제공한다. 통합 원자 이동은 제외한다.
- N 활성화자는 N 첫 참가자/공대장이다. 이후 열린 N을 OFF로 철회하는 대신 본인 N 탈퇴·참가 순서 자동 승계, 해당 주차 원하는 참가자에게 직접 위임한다. 다른 주차 공대장/참가/예약은 유지한다. §36.9가 전역 공대장 가정보다 우선한다.
- 추천안사용자채택(§36.11): 마지막1인N탈퇴는N만종료/명시재개허용, 공통제목·공개범위C공대장우선(G1), 초기명시개방만/매주자동개방보류(A1). C자체가없고열린N만있을때N공대장공통관리. 기능구현완료아님.
- 생성 시 함께하기 체크는 C/N을 한 명령으로 모두 생성하거나 모두 실패한다. 이후 참가·탈퇴·승계/위임·완료는 주차별 독립이며 다른 인원 자동참가/매주 새N자동개방은 없다. 선택N은 N만 생성한다.
- 내 계정3열 균등폭·체크 자체 중앙/i 우측 가용폭, 다중행 확장. 파티 번호는 실제 편성 기준4인1~4/8인1-1~2-4. 미선택에 i를 표시하지 않는다.

## 구현·디자인·협업 상태

[Backend112 구현 인계6345290060](https://github.com/heo0328/lostparty-backend/issues/13#issuecomment-6345290060)의 고정소비07c2b671로 사전표시를 연결했다. 기존 두 확인창에 실제ID/날짜/미정·명시선택과 읽기 개방미리보기를 적용하고 닫힌DTO·실제/예정세대·표시서명/입력고정·원pending/ACK를 보호한다. F3 후보/F4 관리/F5 일정·예약 독립구간은 유지한다. 상세는 설계37 §37.18, 검증/Issue·Git 마감은 DEV_LOG다. Backend48PASS/개발반영은 보고수신이며 Flutter106mock 통과와 실제회원/기기 인수를 구분한다. F5 Backend 보완 대기는 없고 F6의 별도 확인은 아래를 따른다.

F6-A 계정 새 수동명령 v2/명시T·scope/data 결과검증 및 schema1→2/wire_version 기반 원v1 pending/표시선호 보존을 구현했다. 원ACK 뒤 실제T만 갱신·수06시/10시·N/party근거·저장실패를 보호한다. 상세는 §37.20/DEV_LOG, 다음은 F6-B 방완료/본인완료·미완료종료다. [Backend116/6355428620](https://github.com/heo0328/lostparty-backend/issues/13#issuecomment-6355428620)에서 정정범위는 확정했고 현재주재개 표시/생성전확인 binding만 Backend 계약보완 대기다. dev통합/실회원/기기 인수는 남는다.

| 구분 | 현재 상태 |
|---|---|
| 커밋 기반 | feature/raid-recruitment-scheduling에 선행 v1복구17f8675·F1 af9e9d3·F2 e42f780·F3 독립 구현121fad3을 보관/원격일치 확인. [F3 결과6337065372](https://github.com/heo0328/lostparty-backend/issues/13#issuecomment-6337065372) 본문 재조회일치. dev6d3f617 미반영·브랜치 유지, 최종문서SHA는 Git 참조 |
| 기존 앱 | 개인표 등록·수정/복원과 계정 설정 복귀/결과 닫기 사용자 확인 완료. v1 생성/기본상세·시간/입장 정책은17f8675에 보관·기존 자동검증 기록 있음. 인증 회원 목록은 F3 v2검색, 비로그인 기존 Pending 유지 |
| 2주차 Flutter | F1 실제주차/선택기·계정summary/3열+i·본인목록/기본 읽기상세·캐시 격리 구현. F1 고유123PASS/14파일 분석0에 이어 F2 고유95PASS/10파일 분석0. 실제 DI는 v2생성/context·같은방T상세/편성 읽기까지 연결. F3 검색/일반 참가·신청/승인/거절/철회·캐릭터 변경 연결, 그룹 캐릭터 필터/선택token·명시더보기 연결. F4 N참가/주차별 탈퇴·승계/위임·편성/공통관리 연결. F5 일정/예약·사전 참가 시간표시 연결 완료. F6-A 수동명령 이행완료/B·C 미구현·전체 기능 인수 미완료 |
| Penpot03 | v3 주차선택5화면과 v4 공대장/번호3화면 반영. 계정 체크/i·v4 실제PNG 검수. 상세 식별자/기준은 설계37·NEXT_WORK |
| Backend | [92번째 실제전환/읽기인계6332478347](https://github.com/heo0328/lostparty-backend/issues/13#issuecomment-6332478347): 개발DB0029/API8000 factory167경로·자료/키 보존 완료 보고. 계약0.4.1/policy4 유지 |
| 계약/다음 | [F2 인계6335852339](https://github.com/heo0328/lostparty-backend/issues/13#issuecomment-6335852339). 구현e42f780 원격일치/사용계약·검증·제한 전달/본문 재조회일치. F4까지 연결/검증 완료, Backend07c2b671/168경로 소비. F5 사전 참가 표시까지 연결 완료/F6 준비. 정상인증HTTP/실회원쓰기·기기 인수 미확인. #19통계별도 |

기존 자동검증과 수동확인은 [DEV_LOG](DEV_LOG.md)에 보존한다. 사용자 확인한 가능 레이드/최고 난이도 기본 선택은 다시 대기로 두지 않는다. F2로 선택T 시간 제한·v2생성/상세를 연결했으며 실제 유효시각 생성 및 2주차 기능의 실서버/실기기 인수는 남는다. 문서 체크포인트와 기능 전체 완료/dev 통합을 구분한다. 기존 미커밋 기능·플랫폼 생성/DevTools·백업/tools·통계35의 별도 검토는 보존한다.

## 핵심 제품·자료 개념

- 앱 회원1명은 실제 LostArk 원정대 여러 개를 등록/인증한다. 원정대 소속 기본 목록은 LostArk API 기준이며 우리 서버는 이를 저장해 반복 호출을 줄이고 활동·파티·그룹에 제공한다. 인증에 사용한 캐릭터 소멸은 원정대 인증을 해제하지 않는다. [정책09 D11](../backend-migration/09-migration-decisions.md).
- 앱 실행 중 환경+회원별1회 실제 목록 갱신→활동 캐릭터 전체 상세 검사다. 나이스단 OFF는 해당 계열 자동검사 제외·기존 빌드 보존이며 표시 숨김/count는 검사 제외가 아니다. 같은 회원 재로그인·탭/복귀는 반복하지 않는다.
- 1700은 최초 기본 선택 기준만이다. 기존 관리 화면에서 저레벨 수동 사용/대표 변경을 허용한다. 신규/첫1700 자동 추가와 사용자 해제 영속화의 별도 후속은 NEXT_WORK.
- 서버에는 역할별 핵심 수치/오류·확인 시각·선호/표시를 복원하고 상세 원본은 기기에 보관한다. 로컬 저장/서버 실패는 영속 대기이며 역할 불명/파싱 실패는 기존 값을 보존한다. 확정 역할의 장비 오류는 해당 역할에 경고와 저장한다.
- 회원/환경 UUID·scoped cache와 구 기기 정수PK를 분리하고 이름 기반 자료 병합/자동 승계·기존자료 삭제를 하지 않는다. 회원/session/ownership/lifecycle/readGeneration/CAS·pending/outbox 경계를 유지한다.
- 현재 개발환경/자료로 개발을 계속하고 베타 시작 직전에 개발자료를 비운다. 환경/기능 재구축/Firebase 자료이전은 요구하지 않는다. 베타부터 자료는 큰 문제가 없으면 운영까지 보존한다.

## 완료된 연결 지도

| 영역 | 현재 연결/계약 |
|---|---|
| 회원/세션·키·설정 | Google/Backend 로그인·세션/로그아웃, 회원 API키·나이스단 설정 저장/복원. [인증](../architecture/GOOGLE_LOGIN_CONTRACT.md)·[25](../backend-migration/25-member-lostark-key-request.md) |
| 원정대 등록/기존 장비인증 | 검색/본·부등록/수정/제거·대소문자검색, 인증캐릭터선택·성공복귀·본인재인증차단. 미인증은기본투영만. [19](../backend-migration/19-account-registration-flutter-contract.md)·[28](../backend-migration/28-verification-client-preparation.md) |
| 회원 내 계정/관리 | 기존 카드·2/3/4열·대표왕관/확인·이름편집·활동/표시/count/드래그 설정과 상세 진입. [27](../backend-migration/27-representative-quick-selection-ux.md)·[30](../backend-migration/30-scoped-storage-write-contract.md) |
| 서버 복원·자동 상세 | 캐시먼저→일괄 GET→기존 요약/주간→최신 실제 목록/상세 최대2worker. 회원/권한/보류명령 보호. Backend8d03e962 bootstrap 기본true, 명시 크기/범위409·미지원404에만기존경로대체. [30](../backend-migration/30-scoped-storage-write-contract.md) |
| 주간 체크 | 기존 추천/선택/확인 UX에 서버 카탈로그/주차·수동완료/정정·점유근거 연결. i는현재모집방참가관계이며완료근거와독립. 파티/반복방의실제API소비는해당기능후속. [33](../backend-migration/33-weekly-raid-flutter-integration.md) |
| 시작/진단 | 정적로딩이미지·서비스초기화후4초고정전환,통신은앱수명지속. LoadTiming/UiTiming은debug한정·민감정보0. 추가성능최적화/애니메이션은사용자보류. |

## 사용자 관찰·검증 범위

일괄 연결의 실제 SM F956N 로그에서 계측Backend76→29요청/기본+주간4661→2883ms,사용자개선수용을받았다. 이후동일구간1443ms+61ms도관측했으나단일실행/조건변동이므로평균/첫paint수치아니다. 4초진입은사용자가수용했다. UI501ms프레임·동기분석최대56ms는관측했고추가개선은보류다. 수동완료성공·기기변경원정대/인증상태복원·실장비인증1회성공등기존사용자결과는DEV_LOG에보존하며모든조작/분쟁인수로확대하지않는다.

최종코드검증·기능브랜치/통합SHA는DEV_LOG최신마감기록을따른다. 기존완료이력은 [DEV_LOG](DEV_LOG.md), 문서정리전원문은 [기록](history/scoped-account-cache-2026-10-18.md)이다.

## 다음 독립 작업·협업

- Flutter V2의 D1~D4 구현 마감. Backend 작업으로 현재 불가능한 실서버·사용자 실기기 인수는 차후 후속으로 분리했다. 현재 GET의 최종 결과만 기존 계정/설정·주간 재조회와 성공 복귀로 연결하며 캐릭터 초기 조회/일괄 API는 변경하지 않았다. 상단 안내는 ‘제목아래작은문구,좁으면아이콘’으로 연결했고 사용자 수동 체크는 NEXT_WORK에 묶었다.
- Backendbootstrap [시간순146번째](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6247620588)→Flutter연결147/실기기148/진단149/실측150/마감151 이후 [시간순153번째](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6249286430)에V2후속Issue15를연결했다. [Issue15 최신 회신](https://github.com/heo0328/lostparty-backend/issues/15#issuecomment-6249415434) 기준 추가Backend대기없음. #8은 주제별 이관 후 보관 종료됐고 V2는 #15에서 계속한다.
- 그룹 #12/모집·파티 #13, 한도15/5/10·통계는 [32](../backend-migration/32-backend-domain-prework-requests.md)·[34](../backend-migration/34-member-limits-and-room-restrictions.md)·[35](../backend-migration/35-weekly-member-and-group-statistics.md)를기준으로최신인계후연결한다. G1의과거미게시문구로현재상태를되돌리지않는다.
- 실제active파티소유이전후처리adapter는서버후속이며없으면review_required로보류한다. 기존회원자리/Snapshot·경고·유효캐릭터명시변경은해당파티기능에서구현한다.
- 개별캐릭터세팅갱신버튼복구, DB-03/QA-01/AUTH-01과새기기/재설치/OFF·계정전환실인수는NEXT_WORK의별도후속대장에남긴다.

## UI·협업 공통 기준

기존디자인/조작/카드·주간체크영역을보존한다. 캐릭터이름12자/최대2줄자동축소,지원4직업(바드·도화가·홀리나이트·발키리)만딜러/서포터직접선택,일반직업딜러고정. 숫자화면은소수점없이/시각은초까지,저장정밀도는유지한다. 확인알럿취소왼쪽/긍정오른쪽. 앱내문구는간결하게한다.

공식협업은Backend GitHub Issues다. 보고시브랜치/이슈번호/시간순댓글번호/담당/단계를구분한다. 구간 종료마다 문서 최신화·커밋·작업 브랜치 푸시로 복구 지점을 남기며 매번 승인을 다시 묻지 않는다(2026-10-22 사용자 확정). dev 통합 시점은 별도이며 다른 독립 기능은 목적 브랜치·관련 이슈를 판단한다. 사용자백업/tools/DevTools/플랫폼생성파일은임의커밋/삭제하지않는다. 실기기조작은사용자담당이다.

[문서지도](../README.md)·[정책09](../backend-migration/09-migration-decisions.md)·[후속14](../backend-migration/14-my-account-flutter-integration-plan.md#flutter-follow-up-20261014)·[레거시출처](../../legacy/firebase/README.md).
