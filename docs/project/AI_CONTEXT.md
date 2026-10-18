# AI CONTEXT — 프로젝트 현재 상태

기준2026-10-18. 현재 기능 브랜치 `feature/scoped-account-cache` 마감·dev/main 동일 개발 체크포인트 통합을 사용자가 승인했다. 최종 커밋/원격 상태는 Git과 DEV_LOG 최신 통합 기록을 따른다. 현재 실행 순서는 [NEXT_WORK](NEXT_WORK.md) 하나로 관리하며 과거 원문을 새 지시로 적용하지 않는다.

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

- Flutter V2인증/proof새기기복원·24시간도전/방어·앱내방어안내는미연결이다. Backend7ba6297/[Issue8시간순144번째](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6245920315)는구현/push/로컬반영인계이며Flutter완료아니다. 다음새브랜치/새이슈로분리하고기초로그인·키·첫인증을재개발하지않는다.
- Backendbootstrap [시간순146번째](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6247620588)→Flutter연결147/실기기148/진단149/실측150까지회신. 현재추가Backend대기없음, #8은후속이관/별도승인전OPEN유지.
- 그룹 #12/모집·파티 #13, 한도15/5/10·통계는 [32](../backend-migration/32-backend-domain-prework-requests.md)·[34](../backend-migration/34-member-limits-and-room-restrictions.md)·[35](../backend-migration/35-weekly-member-and-group-statistics.md)를기준으로최신인계후연결한다. G1의과거미게시문구로현재상태를되돌리지않는다.
- 실제active파티소유이전후처리adapter는서버후속이며없으면review_required로보류한다. 기존회원자리/Snapshot·경고·유효캐릭터명시변경은해당파티기능에서구현한다.
- 개별캐릭터세팅갱신버튼복구, DB-03/QA-01/AUTH-01과새기기/재설치/OFF·계정전환실인수는NEXT_WORK의별도후속대장에남긴다.

## UI·협업 공통 기준

기존디자인/조작/카드·주간체크영역을보존한다. 캐릭터이름12자/최대2줄자동축소,지원4직업(바드·도화가·홀리나이트·발키리)만딜러/서포터직접선택,일반직업딜러고정. 숫자화면은소수점없이/시각은초까지,저장정밀도는유지한다. 확인알럿취소왼쪽/긍정오른쪽. 앱내문구는간결하게한다.

공식협업은Backend GitHub Issues다. 보고시브랜치/이슈번호/시간순댓글번호/담당/단계를구분한다. 완료구간은통합하고다른독립기능은새목적브랜치·새이슈로분리한다. 사용자백업/tools/DevTools/플랫폼생성파일은임의커밋/삭제하지않는다. 실기기조작은사용자담당이다.

[문서지도](../README.md)·[정책09](../backend-migration/09-migration-decisions.md)·[후속14](../backend-migration/14-my-account-flutter-integration-plan.md#flutter-follow-up-20261014)·[레거시출처](../../legacy/firebase/README.md).
