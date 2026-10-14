# AI CONTEXT — 현재 프로젝트 상태

2026-10-14. 기준 D:/dev/projects/lost_party_flutter, 통합 dev. Issue6 회원 설정의 문서/Git/최종인계·종료와 전체 데이터베이스 설계 점검을 완료했다. [DB 재점검24](../backend-migration/24-database-design-review.md)를 기준으로 다음 복원 범위를 사용자와 확정한다. DB 점검은 조사·문서 전용이며 코드/DDL/실데이터를 변경하지 않는다. 상세 실행은 [NEXT_WORK](NEXT_WORK.md), 완료 이력은 [DEV_LOG](DEV_LOG.md).

## 완료된 앱 연결

- Google Credential Manager·Backend 자체 회원/세션·로그인 유지/로그아웃 사용. Firebase 실행 경로 제거, 기존 Firebase 사용자/테스터 자료 이관 없음. 기본 로그인/유지선택별 재실행/로그아웃 사용자 확인 완료.
- 서버 등록/전체 원정대 조회·preview/등록·수정·삭제·refresh 연결. 조회6f97190, 등록98ebbff/dev0427232, 빈 label 계약 d3cb697 소비 구현5fe636e/dev266a7e2. 사용자 등록/삭제·재로그인 캐릭터 표시·갱신 안내 및 이름4흐름 확인 완료. [조회16](../backend-migration/16-account-read-flutter-contract.md), [등록19](../backend-migration/19-account-registration-flutter-contract.md), [이름20](../backend-migration/20-account-auto-label-contract.md).
- 수동 전투력 캐시/갱신과 내계정 카드 연결: Backend39188d5, Flutter6beb55e/devccc6b23·push. 전체1204/후속국소70·분석0 및 사용자3흐름 확인. 선호역할Snapshot 우선·회원별서버표시캐시 격리. [계약22](../backend-migration/22-character-combat-power-flutter-contract.md).
- 회원 나이스단 설정: Backend79255f0의 GET/PUT /v1/me/settings. 기존 캐릭터관리 위치·스위치즉시저장, 기본OFF·회원서버저장·같은회원로그인GET복원. Flutter 전체1219/이후국소32·최종lib-test분석0/debug9.4초. 사용자ON/OFF·관리재진입·재로그인복원3흐름 확인. 별도재설치/새기기 전체인수는미확인. Flutter2e0764f/dev5cee964통합·push/최종인계·Issue6종료완료. [설계23](../backend-migration/23-nice-group-auto-refresh-design.md).

## 데이터·실행 경계

- Backend 회원/user UUID와 서버 registration/canonical Character UUID, Flutter 로컬 정수PK는 별개다. 현재 서버 표시값은 로컬계정/역할빌드의완전한복원자료가아니다.
- 현재 로컬캐릭터·dealer/supportSnapshot·선호역할·표시순서/개수·개인API키 등이 남아 있다. Google로그인만으로이전체자료가복원되지는않으며RESTORE-01 설계대상이다. 기존자료이관요청이아니다.
- 회원설정GET/등록GET/전투력캐시GET은병렬. 개인키의siblings요약자동갱신은별도다. 전체Armory/역할빌드runOnce는현재BackendApp에미연결이다. 향후설정GET성공+전체roster준비→같은회원/세션확인→나이스단판정→자동빌드실행을설계해야한다. 조회실패를OFF로바꾸거나실행1회를소진하지않는다.
- 서버계정소유인증과Google회원인증은별개. 장비/이전의PROVIDER_EVIDENCE_PENDING/ROSTER_EVIDENCE_PENDING·누락suspect보류는유지한다. 장비/활동/대표Flutter연결은후속이며현재완료로간주하지않는다.

## 협업·후속

Backend heo0328/lostparty-backend GitHub Issues가공식협업채널이다. 필요한질문/작업/인수만요청하고결과를같은Issue로콜백한다. 완료요청은연계후속때문에열어두지않고Flutter가후속을주관한다. [협업규칙](ai_rules.md#8-2-flutter--backend-github-issues-협업콜백).

#1/#2/#3/#4/#5종료. #3은서버기반완료와장비/활동Flutter미완료를분리종료했다. #6회원설정은양측구현·사용자3흐름/FlutterGit인계완료로종료했다. Backend마지막회신상feat/member-settings push·로컬0004적용·dev미병합이며원격상태를마무리/DB조사시재확인한다.

[Flutter주도후속대장14](../backend-migration/14-my-account-flutter-integration-plan.md#flutter-follow-up-20261014): ACCOUNT-01장비UI/API연결,ACCOUNT-02실provider/소유권/roster증거,ACCOUNT-03활동대표,QA-01등록제거후로컬보존인수,POWER-01전체빌드자동갱신,RESTORE-01환경복원,AUTH-01정책/릴리즈인수. 필요한 Backend 변경은 Flutter 설계 후 별도 Issue로 요청한다.

## 보관 자료

[문서지도](../README.md), [이전결정09](../backend-migration/09-migration-decisions.md), [Google계약](../architecture/GOOGLE_LOGIN_CONTRACT.md), [레거시지도](../../legacy/firebase/README.md). 과거미인계/미인수/OPEN문구는당시이력이며현재실행근거는NEXT_WORK와최신상태다. 사용자미추적Rules백업/tools실험·기존worktree는별도지시없이변경하지않는다.

## DB 재점검 결과

[보고서24](../backend-migration/24-database-design-review.md): Backend게시0004기준19개모델·Flutter schema13/8개테이블과보안저장/메모리를대조했다. 서버회원설정/등록과기기공용계정/빌드·표시환경은별도이며전체환경복원계약이남아있다. 격리메모리DB에서FK0·missing캐릭터삭제후빌드/주간표시고아각1행을재현했고실기기는미검증이다. 복원정답/ID/필드설계와로컬삭제정합성을분리후속으로기록했다. 이번에기능코드/DDL/실자료를바꾸지않았다.

2026-10-15 현재그룹: 사용자순차진행의첫구간인시작등록목록중복조회개선완료. 기존feature/account-backend-read를dev70880bf로FF재사용. 초기등록패널/전투력VM만진행전체목록을회원·세션별공유,명시/쓰기후GET은공유하지않음. 전체1227테스트·lib/test분석0완료,사용자지시로현재완료브랜치를dev에통합·push한다. 다음은자동빌드시작순서설계,이후서버/로컬정답·복원범위UX협의. BackendAPI/DB변경없음.
