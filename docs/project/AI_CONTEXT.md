# AI CONTEXT — 현재 프로젝트 상태

## 반드시 유지할 핵심 제품 개념

**앱 사용자1명→등록·인증한 실제 게임 원정대 여러 개→원정대별 API 소속 캐릭터 전체 목록**이다. 우리 서버는 provider 결과를 저장해 반복 호출을 줄이고 앱 사용 캐릭터 확인·향후 파티/그룹 기능에 제공한다. API 소속/앱 사용자 귀속·인증/활동 선택/표시 설정을 구분한다. 화면마다 API 재호출하지 않고 회원별 앱 실행1회 갱신에 실제 목록 갱신을 포함한다. 인증 캐릭터 소멸은 원정대 인증을 해제하지 않는다. 장기 원본은 [정책09 D11](../backend-migration/09-migration-decisions.md#d11-핵심-데이터-개념--사용자실제-게임-원정대서버-저장의-역할-2026-10-16-사용자-확정)이며 이후 설계 전 반드시 대조한다.

기준일: 2026-10-17. 현재 실행 순서와 수동 인수 조건은 [NEXT_WORK](NEXT_WORK.md), 구현·검증의 상세 이력은 [DEV_LOG](DEV_LOG.md)를 따른다. 과거 단계의 ‘미연결/다음 A·B·C’ 문구로 현재 상태를 되돌리지 않는다.

## 최신 사용자 확인·Git 통합·후속 조사

2026-10-17 상태·정수/시간 표시 및 다른 기기에서 서버 원정대 목록/인증 상태 정상 확인을 수신했다. 캐릭터 전체/활동·역할 요약 복원 인수로 확대하지 않는다. 사용자 보고의 이름 변경·활동 선택 진입 누락, 인증 버튼 축소/이름 옆 배치·긴 이름 두 줄, 구 기기 자료가 있는 새 기기의 서버→로컬 회원 데이터 경로를 **dev 통합·push 후 분석**한다. 상세 범위는 NEXT_WORK, 완료 이력은 DEV_LOG다. 기존 관리 연결 구현과 사용자 접근 가능은 구분하며 누락을 후속으로 추적한다. dev에서 확인한 기본 OFF→basicOnly 화면의 조기 return·회원 runtime 미생성 경로가 관리 진입/회원 캐릭터 복원을 함께 막는다. 기존 서버 이름 수정은 등록 관리에 있고 현재 표시명 제한은40자다. 분석 상세·수정 순서는 NEXT_WORK다.

## 원정대·숫자 표시 기준 (2026-10-17)

로그인 회원의 미인증 등록도 서버 저장이며 같은 회원의 다른 기기/재설치에서 조회한다. ‘조회용 저장’ 대신 ‘원정대 인증 필요’, 완료 안내는 숨기고 미선택 등 필요한 행동만 표시한다. 아이템레벨·전투력은 화면에서만 정수부를 표시하고 원본 소수점·저장·정렬/판정은 보존한다. 장기 표시 기준은 [디자인 공통 원칙](../design/LOSTPARTY_DESIGN_SYSTEM_V1_REQUEST.md), 검증 결과는 DEV_LOG다.

## 최신 연결 — 실제 API 원정대 목록 갱신 선행 완료

82번째Backend3c8e799의기존POSTrefresh를source.prepare에연결했다. owned원정대provider갱신→전체canonical/설정재조회→활동집합확정→OFF계열제외상세검사순서다. 고정명령/ACK·부분실패준비미소진/성공분보존·기존재시도·옛조회/회원late차단과목록별진행을연결했다. **최종1567PASS·분석0**, [인계](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6214686634)·상세DEV_LOG/다음NEXT_WORK. 일반GET은서버저장조회이며기본OFF·실게임/기기미확인은유지한다. Backend장비재인증/타소유pending은90번째게시·Flutter연결완료이며 실제인수는별도다.

원정대구성은API목록기준/추가외부영구세대근거요구없음, 인증대상C소멸에도B인증유지의사용자확정은정책09D11/26을따른다. 이전77번째의provider목록선행누락은이번코드/자동검증으로해소했다.

## 인증 UX 보완 — 캐릭터 선택·재진입 복구 연결 완료

최신 정책 연결 완료: 현재 owned는 회색 ‘인증됨’·선택 불가, ownership_lost는 재시도 후보다. Backend105번째19c2dcc의409 ALREADY_VERIFIED는 확정 거절/재전송 종료·현재 목록 갱신으로 처리하고, 실제 pending 보존·성공 이동 방지를 연결했다. 재등록201 owned/verified는 새 등록ID·현재GET으로 인증을 복원하고 초기 활동/대표 설정을 보존한다. 최종 전체 **1,590PASS·lib/test 분석0**, [106번째 Flutter 결과](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6228427796). 서버 차단/재등록 연결 대기는 해소됐고 상세·미확인 실기기/Git 상태는 NEXT_WORK/인증28을 따른다.


사용자 실제인증1회 성공과 Backend98번째 VERIFIED/소유연결 기록을 확인했다. 이번1회이며 전체활동/갱신 인수로 확대하지 않는다. 최신 UX는 인증성공→이전페이지복귀(직접진입시내계정), 관리화면강제이동제거·문구간결화를 연결했고 최종전체1579PASS·분석0이다. [99번째 결과](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6217416791)·상세/새복귀UI실기기확인은 NEXT_WORK/인증28을 따른다. 사용자화면은 핵심행동/상태만 짧게 쓰는 원칙을 ai_rules에 기록했다.


Backend90번째 cc372bfa의 target_character+expected_registration_version 게시를 소비해 등록 원정대의 전체캐릭터 명시선택·새요청/오류별재조회/재선택·불변중첩명령·현재GET/보류안내를 기존 인증 화면에 연결했다. 내 계정의 기기조회/인증전 표시를 삭제했다. **인증 관련50PASS·lib/test 분석0**, [91번째 Flutter 결과](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6216421322). 다음 사용자 화면/실장비 인수이며 추가 Backend 대기는 없다. 실제게임/기기·최초연결실패원인은 미확인이고 상세는 인증28/NEXT_WORK다.

## 장비 인증 기존 구현 자료 인계

Issue8 66번째 Backend의 자료 요청에 대해 과거8f4209d 실제 장비 인증/기록을 대조·회신했다.6부위→무작위1~3해제→10분/지정 외 Name·Grade 유지, 과거 클라이언트 판정과 현재 서버 최종 판정의 차이·자동 이전/수동24시간 방어 구분을 인계했다. 사용자 요청의 시도/대상/회원/결과·타소유 도전 이력은 현재 서버 기존 challenge에 대조할 기준이다. 회신 https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6210605354 , 다음 Backend 설계/구현. 상세는 DEV_LOG/인증28, 이번 코드·시험 변경 없음.

## 최신 UX 정정 — 기존 관리 화면 재사용

기존 ‘앱에서 사용할 캐릭터·대표·표시 순서/개수’ 화면을 현재 회원/canonical 서버에 연결한다. 대표 없을 때만1700이상 사용 대상 중 최고 아이템레벨 초기1회 선정, 기존 대표 유지·변경 성공 때 반영/확정 실패는 기존 유지. 별도 복구 화면/사용자 단계를 선제 신설하지 않는다. 응답 유실과 확정 실패의 내부 구분은 유지한다. 공통 기준은 CharacterUsageLevelPolicy.minimumItemLevel=1700. 공식 인계 https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6209360031 . 현재 작업 순서는 NEXT_WORK다. 별도 E1 복구 UX 선행·E2 화면 신설 계획은 적용하지 않는다.

## 최신 채택 정책 D10 — R1 연결 완료

비로그인 기본 로컬 검색/로그인 미인증 조회용 서버 저장/인증 후 사용 선택·상세·활동을 채택했다. R1은 기기 공용 basicOnly 조회/저장·Router 상세 제한·미인증 V1/V2 power 투영·수동 갱신 소유 재검사를 연결했고 **최종 전체1542PASS·lib/test분석0**다. 과거 DB/키/자료는 유지했다. 기존 관리 화면의 현재 서버 저장/초기 대표·1700 기준과 인증 성공 전환까지 연결했고 최종 전체1560PASS·분석0이다. 실제 소유/실기기 인수는 미확인이다. [정책09 D10](../backend-migration/09-migration-decisions.md), [사용자 흐름](../feature-definitions/LOSTPARTY_CORE_USER_FLOW_OVERVIEW.md), 순서는 NEXT_WORK/상세는 DEV_LOG.

## 현재 환경 유지 정정

현재 환경·개발자료로 개발을 계속하며 베타 시작 직전에 DB 내용만 비운다. 환경/기능 재구축과 기초 재인수를 요구하지 않는다. 최신 정정은 https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6207542428 이다.

## 개발 단계·자료 수명 (2026-10-16 사용자 확정)

현재 1단계 개발이며 테스트 자료를 생성·삭제한다. 베타 사용자 모집/준비 후 베타 시작 전에 개발 중 사용한 모든 사용자·서버 기록을 초기화하고, 베타부터 쌓인 사용자 자료는 큰 이슈가 없으면 그대로 운영에 보존한다. [정책09 D08](../backend-migration/09-migration-decisions.md#d08-개발--베타--운영-데이터-수명--사용자-확정-2026-10-16).

Firebase/구 테스트자료 승계와 개발자료 보존형 전환·백업/복원 리허설은 불필요하다. 새 DB 구조 관리·새 회원 자료 저장/재로그인·기기 간 복원은 유지한다. 아래 C의 구 기기 자료 보존 경로·schema13/legacy writer 호환은 당시 구현 상태이며 더는 새 기능의 필수 조건이 아니다. D의 별도 Backend 로컬 DB/guest 키 연결은 잘못된 범위 확장으로 철회하고 원래 연결로 복구했다. 현재 개발자료를 계속 사용하며 별도 자료 진입/전용 안내 정리는 유지한다. 실제 서버·기기 자료 초기화/환경 전환은 하지 않았다.

## 제품 보존·협업 공유 기준

사용자 최신 기준: 앱 기능·UI/UX는 동일하게 유지하고 Firebase 전용 구현·연결/운영 설계는 제거한다. 오래된 화면/로컬 DB·정수ID/분석 모델은 자동 폐기 대상이 아니다. D는 구 자료 승계와 전용 의존을 분리·새 경계로 대체하는 작업이며 제품 기능 삭제로 확대하지 않는다. Backend에는 필요한 제품 설정/제약과 구현/미연결 상태만 [공유 기준31](../backend-migration/31-app-product-policy-handoff.md)로 전달한다. 상세 정책은 [09 D09](../backend-migration/09-migration-decisions.md#d09-제품-기능uiux-유지--firebase-전용-구현-제거--사용자-확정-2026-10-16)다.

## 기존 관리/인증 후 전환 연결 완료

기존 CharacterManagementPage/ViewModel에 회원/canonical gateway·활동+대표 원자 저장·P2 순서/count 저장을 연결했다. 초기 대표는 없을 때만 유효 최고 후보 draft/명시 저장, 공통1700·finite 검사, 기존 대표/부적격 선택 보존을 적용한다. 인증 대상 ID 전달·성공 결과 ID의 현재 소유/전체 목록 재확인→해당 본·부원정대 관리 전환을 연결했다. 최종 전체1560PASS·분석0, 인계 https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6209931176 . 상세는 DEV_LOG·현재 조건은 NEXT_WORK. 기본flag OFF/실소유·기기 미확인은 유지한다.

## 대표 빠른 선택 E1

메인 원정대 왕관·확인창·대표 전용 GET/PUT·응답 유실 동일명령 복구·세션/자격/충돌 경계를 실제 회원 화면에 연결했다. 활동 전체 편집도 기존 관리 화면의 현재 서버 연결을 완료했다. [UX27](../backend-migration/27-representative-quick-selection-ux.md), 검증 상세는 DEV_LOG. 관련 통합18PASS·분석0, 전체 실행1531PASS/신규 fixture1실패는 fixture 수정 후 해당18개 재검증으로 해소했다. 실서버/실기기 통과를 뜻하지 않는다.

## 현재 완료와 다음 구간

**S1~S3·A1/A2·B·C·D 코드 연결/정리·자동검증 완료, 실환경 인수 대기**다. BackendApp/Router·AppShell에 앱 수명의 자동 실행기를 연결했고 ON 로그인 회원별 주목록·역할 요약/로컬 상세·개인 표시 설정·진행/재시도·충돌 해결 UI를 제공한다. [자동 갱신 설계23](../backend-migration/23-nice-group-auto-refresh-design.md), [저장 계약30](../backend-migration/30-scoped-storage-write-contract.md).

- E1 이전 전체 **1524PASS(철회한 namespace 전용4개 제외)**, lib/test 분석0. 저장소 전체 분석은 기존 사용자 tools/roster_rebalance_domain_fixtures.dart의 info3건만 남는다. 실제 SQLite/모의 HTTP 결과이며 실서버/provider·실기기 통과를 의미하지 않는다.
- 기본 `BACKEND_LIFECYCLE_READS_ENABLED=false` 유지. ON 로그인 `/account`는 회원 주목록이다. D에서 구 기기자료 route/button을 제거했으며 비로그인/기본 OFF 로컬 기능은 원래 DB/guest 키 연결을 계속 사용한다.
- 직접 다음: 기존 관리/인증 후 전환 연결과1560PASS 결과를 유지하고 실제 소유 조건이 필요한 연동 확인은 NEXT_WORK를 따른다. 별도 새8001 채택·빈 저장공간·기초 재인수를 개발 선행 단계로 삼은 앞선 순서는 철회했다. 현재 환경과 개발자료로 계속 개발한다. Backend 미완료 실소유 서버 구현은 독립 후속, 사용자 실제 관찰은 나중이다. 주소 점검/신규 기능 인수는 필요한 연동 시점에만 수행한다. 구 DB 보존 upgrade는 선행 조건이 아니다. 실제 적용/재시작/배포는 별도 지시 범위다.

## 실제 소유 증거가 필요한 검증 경계

현재 환경에서 개발을 계속한다. PROVIDER_EVIDENCE_PENDING의 실제 소유/canonical·소멸 확정 서버 후속은 남지만 독립 Flutter 개발 중단이나 새 환경·기초 재인수 조건이 아니다. 실제 소유/활동 대상이 필요한 전체 저장·자동갱신·복원과 대표 변경의 실사용 검증은 해당 조건을 갖춘 뒤 확인하며 사용자 게임 관찰은 나중이다. fixture·빈 목록 성공으로 실사용 통과를 주장하지 않는다. [Backend 정정6207867594](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6207867594).

## 확정 제품·저장 경계

- 앱 실행 중 환경+회원별1회, 앱 사용 활성 캐릭터 전원의 상세를 조회·검사한다. 같은 회원 재로그인/탭/복귀에는 자동 반복하지 않는다. 준비 실패는 실행1회를 소진하지 않는다.
- 나이스단 OFF는 해당 계열 자동 상세 검사 제외·기존 빌드 보존이다. 전체 자동갱신 마스터 스위치나 부정 판정이 아니다. 표시 숨김/count도 검사 대상을 줄이지 않는다.
- 서버는 역할별 핵심 수치·오류 요약·확인 시각과 선호역할/표시/count를 복원하고 상세 원본은 로컬에만 보관한다. 키 미등록/OFF 제외도 마지막 서버요약·설정은 복원하며 원본 없음을 표시한다.
- 로컬 저장 후 서버 실패는 영속 저장 대기로 남긴다. 미완료 상세 재시도와 기존 명령 서버 재전송은 분리하며, 충돌은 명시 서버값 수용으로 해결한다. 역할 불명확/파싱 실패는 기존값을 보존하고 확정 역할의 장비 오류는 해당 계열에 경고와 저장한다.
- Backend 회원·registration·canonical character UUID와 기기 공용 정수PK는 별개다. scoped schema3/8테이블과 기존 기기 schema13을 분리하고 이름 기반 자동 이전/병합·구 자료 삭제는 하지 않는다. 회원/session·소유수명·관찰 세대·CAS로 늦은 결과를 차단한다.
- 확인 알럿은 취소/부정 왼쪽, 변경/긍정 오른쪽이다.

## 완료된 연결 지도

| 구간 | 현재 상태·근거 |
|---|---|
| Google/Backend 회원·세션 | 로그인 유지·로그아웃 기본 사용자 확인 완료. Firebase 실행 경로 제거, 기존 사용자 자료 이관 없음. [Google 계약](../architecture/GOOGLE_LOGIN_CONTRACT.md) |
| 원정대 조회·등록 관리 | 조회/preview/등록·수정·제거·refresh/빈 이름 처리 및 사용자 확인 완료. [계약16](../backend-migration/16-account-read-flutter-contract.md), [19](../backend-migration/19-account-registration-flutter-contract.md), [20](../backend-migration/20-account-auto-label-contract.md) |
| 수동 전투력 | 서버·기기 카드 연결 및 사용자3흐름 확인 완료. [계약22](../backend-migration/22-character-combat-power-flutter-contract.md) |
| 회원 나이스단 설정·개인 API 키 | 서버 저장/복원·현재 사용자 기능 확인·dev 통합/push 완료. 재설치/새 기기·실provider 한도는 별도 미확인. [설계23](../backend-migration/23-nice-group-auto-refresh-design.md), [계약25](../backend-migration/25-member-lostark-key-request.md) |
| 장비 인증 화면 | API client·상태 관리·설정 Router/DI 연결 및 자동검증 완료. 실제 장비/소유 증명·이전 보류 해제는 미확인. [문서28](../backend-migration/28-verification-client-preparation.md) |
| S1~S3 | 회원·환경 캐시/현재 캐릭터·퇴역 이력 조회와 앱 연결 완료. live 소멸/claim 해제는 보류. [ID 설계29](../backend-migration/29-scoped-character-identity-design.md), [저장 계약30](../backend-migration/30-scoped-storage-write-contract.md) |
| A1/A2·B·C/D | 역할 상세/최소요약·설정/표시 저장과 영속 명령, 활성 전체 자동 상세1회·OFF 제외, 앱 수명·회원 주목록/진행 UI 연결과 D 구 자료 승계 분리·제품 기능 보존까지 최종 자동검증 완료. 실환경 인수는 NEXT_WORK |

## 협업·원본·Git

Issue8 병렬 회신 최종 대조: https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6209491349 . Backend6209379848의59b8c23은 D10 미인증/소유상실 power 갱신·성공 replay 차단과 V1/V2/preview/과거 등록 replay 비노출 구현,256PASS·push·현재8000/DB0009·기존자료 유지 반영 보고다. 과거 ‘해당 서버 수정 대기’는 해소됐다. 실제 소유 증거/원정대 연속성·퇴역 확정은 별도 미완료다. Flutter가 이번 실서버/기기를 직접 검증한 것은 아니다.

고정59b8c23 OpenAPI를 기존7027f0b fixture와 직접 비교했다. paths/schemas 동일, x-game-account-policy.combat_power의 access/preview/replay_access 정책3항목만 추가됐다. R1 투영과 일치하며 새 DTO/endpoint·기존 전체시험 반복은 필요하지 않다. 이후 Backend47a2ce4의 활동/대표1700 검증192PASS·현재8000 반영 보고를 확인했다. 초기 최고 후보 draft/기존 명시 PUT 저장은 Flutter 연결을 완료했다. 게시47a2ce4도 paths/schemas는 동일하며 전투력 수집 필터와 활동 검증을 구분한다.

과거6207398915 통합 순서 중 새8001/빈 환경/초기 인수 선행은 사용자 정정으로 철회했다. 당시 SHA/환경/시험 수는 DEV_LOG 이력이다. 현재8000/개발자료를 계속 사용하며 기존 로그인·키 기본 인수를 반복하지 않는다. 공식 협업은 Backend Issues, Issue8은 OPEN을 유지한다.

2026-10-17 Git 통합: 기능209ce85·dev병합0a11b71을push하고로컬/원격dev일치확인. 기존인증/S1~S3/A1/A2/B/C/D/E1/R1·숫자/상태표시가dev에반영됐다. 사용자Rules백업/tools·기존worktree는보존·커밋제외. 후속분석은dev에서수행했고문서만기존기능브랜치에추가해dev로통합한다. 실제최종문서HEAD는Gitlog/원격확인기준이며Backend작업브랜치/API반영과구분한다.

## 분리된 후속·미확인 범위

[후속 대장14](../backend-migration/14-my-account-flutter-integration-plan.md#flutter-follow-up-20261014)에 담당·완료 조건을 둔다. 현재 자동 갱신 인수에 아래 별도 기능을 섞지 않는다.

- 활동 목록 편집은 기존 관리 화면의 현재 서버 연결을 완료했으며 별도 E2 화면을 신설하지 않았다. 대표 전용 왕관 E1은 실제 회원 화면에 연결했고 실사용 검증은 미확인이다. [UX27](../backend-migration/27-representative-quick-selection-ux.md).
- [생명주기26](../backend-migration/26-roster-character-lifecycle-design.md): 새 이름은 신규 ID, 확정 소멸은 간략 이력·개인자료 정리, 미완료 파티의 회원 자리/Snapshot·경고/명시 캐릭터 변경 정책. 실제 provider 근거 없는 live 소멸/소유권 이전·claim 해제는 보류다.
- [DB 점검24](../backend-migration/24-database-design-review.md)의 DB-03: 구 기기 DB 삭제 정합성은 별도 최소 수정 후보다. 새 복원 연결로 해결됐다고 판정하지 않는다.
- QA-01 등록 제거 후 구 로컬 자료 보존, AUTH-01 탈퇴/재가입·릴리즈/OAuth·운영 인수, 파티/그룹/주간 Backend 연결은 별도다.
- 실제 API/provider·기기 디스크·새 기기/재설치, ON 재실행1회/OFF 제외·실패/재시도·회원 전환은 수동 미확인이다. 체크리스트는 NEXT_WORK에만 유지한다.

## 문서·과거 이력

[문서 지도](../README.md), [이전 결정09](../backend-migration/09-migration-decisions.md), [개발 이력](DEV_LOG.md), [레거시 지도](../../legacy/firebase/README.md). 완료 과정·당시 SHA/테스트 수는 DEV_LOG에 보존하며 현재 실행 근거는 이 문서와 NEXT_WORK다.
