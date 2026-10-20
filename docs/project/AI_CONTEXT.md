# AI CONTEXT — 프로젝트 현재 상태

2026-10-20 개인 시간 설정의 최초 등록·수정·동일 일자 추가 시간 등록·앱 재시작 후 동일 계정 데이터 불러오기는 사용자 수동 확인 통과다. [Issue13 회신](https://github.com/heo0328/lostparty-backend/issues/13#issuecomment-6291576691)에 기록했다. 아래의 실서버/기기 인수 대기는 이 네 흐름을 제외한 범위로 갱신한다. 다른 기기 복원도 추가 통과다. 와이파이 OFF/ON 후 통신 가능 시 마지막 저장 데이터가 정상 기록되는 것으로 보인다는 사용자 관찰은 [추가 회신](https://github.com/heo0328/lostparty-backend/issues/13#issuecomment-6291840658)에 기록했다. 회원 격리/익일24h·취소·실패 복구 세부 경계와 최근 관리 복귀/결과 X는 미확인이다. 시간 설정 로컬 커밋6ecb81d·미push/dev미반영, 이번은 문서/회신만 변경한다.

Issue13 최신 Backend 인계는 [61번째 검색 보완](https://github.com/heo0328/lostparty-backend/issues/13#issuecomment-6291232832)의 cc003e9다. 아래의 정렬·자리 wire/커서 보완 대기는 해소됐으며 Flutter 검색 매핑/모집 연결은 미적용이다. 사용자 확인 당시 실행 서버 SHA는 별도 전달받지 않았다. 상세 확인 범위는 NEXT_WORK/DEV_LOG를 따른다.

2026-10-20 자동 갱신 완료결과에X/결과보기표시를추가했다. 후속API/loading·부분실패/서버저장대기와독립된화면숨김이며작업/자료/재시도를취소·삭제하지않는다. 앱소유표시상태로유지·새갱신/회원전환시초기화, 내계정통합36PASS·변경3파일분석0이다. 로컬 UI 수정 커밋 보관·미push/dev미반영·실기기X/결과보기확인대기이며직전관리복귀수정은보존한다. 계약은설계37의자동갱신결과닫기,상세는DEV_LOG다.

2026-10-20 사용자 지시로 같은 브랜치에서 캐릭터 표시 설정의 저장성공/취소 뒤 이전화면 복귀를 복구했다. 실패초안/세션·미확정요청/기존API는보존·후처리연타차단. 기존화면4PASS·변경1파일분석0, 이번복구는로컬 UI 수정 커밋 보관·미push/dev미반영·기기확인대기다. 설정경로는전체Armory/빌드재분석을시작하지않으며순차개인설정조회/저장후검증과시작자동갱신을구분한다. 상세는DEV_LOG·수동확인은NEXT_WORK다.

**현재 우선 기준:** 통합 모집·일정 목표와 `feature/raid-recruitment-scheduling`을 유지한다. Backend66244da 기준 내 계정 개인 시간표 카드·GET/PUT·실제DI 연결/자동검증을 완료했고 실서버·사용자 기기 인수 대기다. 고유48PASS·변경9파일분석0, 시간 설정 기능 커밋으로 보관·미push·dev미반영(실제SHA는Git이력참조). 모집방 복사·생성/상세/예약은 미연결이며 전체 통합 완료가 아니다. 다음 행동은 NEXT_WORK·상세는 설계37 §34/DEV_LOG다.

현재 제품 기준은 [설계37 상단표·§19~22·§27~28](../backend-migration/37-raid-scheduling-and-multi-raid-planning.md), UI 인계는 §24, 소비 설계 대조 마감은 §29다. Backend50번째 보완4판의 필터/명령context를 확인하고 [회신6283811575](https://github.com/heo0328/lostparty-backend/issues/13#issuecomment-6283811575)을 게시했다. 제시 제품 결정/N1과 두 기술 경계 설계 대조는 완료다. 이후 R5 원본 OpenAPI/구현 인계를 받았고 Flutter가 연결할 차례다(§33). 기존 검색 필터의 미반영 입력 보완과 실제 API 동작 인수는 별도다.

Penpot ‘03 변경 예정·흐름’의 내 계정 시간 설정v2를 참고해 접힘·복수구간/5분익일휠·실패초안유지 카드를 구현했다. 사용자는 시안을100%강제하지 않고 기능/계약상 조정을 허용했다. 신규행은 빈 입력, 저장불명/충돌은 명시 복구 흐름이며 기존 계정그리드/하단탭/자동갱신을 유지한다. Penpot 원본은 편집하지 않았다. 실제 기기 시각·저장 인수는 별도다.

모집v2 디자인은 사용자 승인으로 직접 보완했다(설계37 §30~31.1). 현재27개 화면/상태·기존 느낌/3페이지를 유지한다. 인라인 필터는 단일 펼침 안에서 다중선택 칩을 바로 표시하고 앱 Material 접힘/펼침 아이콘을 사용한다. 내계정 보드는 수정하지 않았고 Flutter/API 구현 완료도 아니다. 최신 PNG 시각 검수는 완료했으나 마지막 전체 경계 API 조회는 timeout으로 미완료다.

Issue13 최신은 [Backend58번째 R5 인계](https://github.com/heo0328/lostparty-backend/issues/13#issuecomment-6287055201)다. 구현66244da·원본 OpenAPI를 읽고 원격HEAD514e465가 후행 문서임을 확인했다. 개발API8000/DB0023 반영은 Backend 보고이며 Flutter 실행/실기기 인수와 구분한다. [57번째 필터 입력 요청](https://github.com/heo0328/lostparty-backend/issues/13#issuecomment-6286046186)은 [회신6287178945](https://github.com/heo0328/lostparty-backend/issues/13#issuecomment-6287178945)으로 대응했으며 Backend 최종 정렬·자리 wire/커서 보완 대기다. 이전 R2 미활성/일정503은 당시 상태다. 실제 모집 Router/DI는 pending, 상세 근거는 설계37 §33·다음 행동은 NEXT_WORK다.

2026-10-19 로그인 후 내 계정 화면 재구성 수정 구현·직접 영향43PASS/변경3파일분석0 및 사용자 디바이스3항목 통과. 기존 디자인·4초 진입·앱 소유 복원 보존. fix/account-auth-screen-selection 수정분의 dev 통합/push를 마감하며 상세 근거는 DEV_LOG, 다음 독립 후보는 NEXT_WORK를 따른다. 분쟁 결과 인수는 별도 보류다.

기준2026-10-19. 원정대 인증·분쟁 V2 D1~D4 구현/표적 검증을 마쳤고 사용자 승인으로 현재 구현 구간을 마감하고 구현 43cd4e9를 dev에 병합·푸시했다. D4 최종68고유PASS·변경18파일분석0이다. Backend 작업으로 분쟁 실서버/디바이스 인수가 불가능해 차후 후속으로 이관했으며 통과로 확대하지 않는다. 최종 커밋/통합 상태는 DEV_LOG, 계약·후속 인수는 [설계36](../backend-migration/36-roster-ownership-dispute-flutter-design.md), 다음 독립 후보는 [NEXT_WORK](NEXT_WORK.md)를 따른다.

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

공식협업은Backend GitHub Issues다. 보고시브랜치/이슈번호/시간순댓글번호/담당/단계를구분한다. 완료구간은통합하고다른독립기능은새목적브랜치·새이슈로분리한다. 사용자백업/tools/DevTools/플랫폼생성파일은임의커밋/삭제하지않는다. 실기기조작은사용자담당이다.

[문서지도](../README.md)·[정책09](../backend-migration/09-migration-decisions.md)·[후속14](../backend-migration/14-my-account-flutter-integration-plan.md#flutter-follow-up-20261014)·[레거시출처](../../legacy/firebase/README.md).
