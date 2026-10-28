# NEXT WORK — 그룹 1차 API 개발 요청·화면 준비

## 현재 구간

사용자는 2026-10-28 그룹 전체 흐름 조사·설계 문서화에 이어 현재 기획 기준의 Backend 1차 API 개발 요청을 명시했다. 최신 dev bdfe0edf에서 feature/group-backend-integration을 시작했다. 종료 조건은 전체 그룹 설계·연결·검증 후 dev 통합이며 현재 파트는 그룹의 핵심 활용 흐름을 문서/시안에서 명확히 하고 Backend 인계 범위와 맞추는 것이다. 기존 개별 그룹 수정/과거 Task 브랜치는 재사용 목적이 달라 보존했다.

[제품 계약](../product/GROUP_PRODUCT_FLOW.md)·[연결 설계39](../backend-migration/39-group-flutter-integration-design.md)에 기존 UX·식별자/권한·서버 제공 API·조회/명령 수명·단계별 회귀/완료 조건을 정리했다. 현재 그룹 Router는 pending, 기능 연결·자동/실기기 검증은 미착수다. 현재 디자인/기록 파트의 검증은 Penpot 구조·PNG/텍스트·경계와 문서 내용·링크·diffcheck이며 Flutter 시험/설치·서버/DB·자료삭제·dev/main 통합은 하지 않는다.

Backend dev 1b6f57bb의 현재 문서/소스/OpenAPI를 확인해 과거404는 문서이동으로 해소했다. G1/G2 및 관리조회·이전/일반탈퇴는 제공, 해산 write는 현재도 없고 GROUP_RECRUITMENT_STATE_UNAVAILABLE다. 완료 조사/과거 구현 이력은 DEV_LOG로 이관했다.

## 우선 연결·검토할 핵심 흐름

담당 Flutter. `원하는 사람 초대·가입 → 그룹원/활동 캐릭터 확인 → 레이드 모집의 그룹·그룹원·특정 캐릭터 필터 → 기존 상세/참가·신청`을 먼저 사용 가능하게 하는 것이 목표다. 기존 모집37의 후보/필터를 재사용하며 새 membership과 성공 후 갱신을 연결한다. 가입/탈퇴 후 현재 그룹과 캐릭터 후보가 갱신되고 원하는 조합의 모집을 찾을 수 있어야 완료다. 관리/복구 전체 준비를 이 독립 흐름의 선행조건으로 삼지 않는다.

디자인은 기존03 메인/관련 섹션에서 이 흐름의 가시성을 우선 보완한다. 새 별도 그룹 운영 기능·화면을 늘리지 않으며 기존 관리 기능의 정책/권한은 유지한다. 기능 구현/사용자 인수는 아직 미완료다. [Issue12 핵심 흐름 협업 회신](https://github.com/heo0328/lostparty-backend/issues/12#issuecomment-6465156288)을 게시·재조회 확인했다.

## 1차 그룹 화면 디자인 — 검토 대기

Penpot `03 작업중인 화면`에서 기존 메인 보드 `그룹 · 사용자 흐름과 화면`(0f0035d1-2d8f-8071-8008-dbabf5c8d408)을 갱신했다. [보드 열기](https://design.penpot.app/#/workspace?team-id=cd444aaf-0d8c-801b-8008-d058a5328d8d&file-id=cd444aaf-0d8c-801b-8008-d058e3181ffd&page-id=0f0035d1-2d8f-8071-8008-dba78bf41adc&board-id=0f0035d1-2d8f-8071-8008-dbabf5c8d408).

메인 보드 하나 안에8개 흐름 섹션/16개 화면과 공통 상태 가이드1개를 배치했다. 목록/요청→검색/생성→가입/코드→상세/초대→정보/코드관리→신청/금지→이전/탈퇴/해산→그룹 레이드 순서다. 메인과 각 섹션에 UX/권한·결과·구현 의도를 짧게 표시했다. 모든 인물/스펙은 가상 자료다.

구조·텍스트/경계 검사와 전체/대표 상세·이전해산 PNG 검수를 마쳤다. 현재는 사용자 검토 전1차 러프디자인이며 클릭 프로토타입·앱 구현·API/기기 인수가 아니다. 실제 화면 배치/문구는 사용자 피드백으로 같은 보드를 수정한다. 서버 미제공 기능은 요청 상태로 구분했다. 최신 사용자 기준으로 그룹장 별도 공개전환/해산 버튼을 제거하고 같은 섹션을 그룹원 공통 목록→기존 레이드 상세 진입으로 수정했다. 해당 레이드 공대장의 기존 관리 권한을 사용한다. 그룹 개발·화면 확인 완료 후에만 같은 메인 보드 묶음을02로 이동한다. 운영은 [기존 디자인 공통 지침](../design/LOSTPARTY_DESIGN_SYSTEM_V1_REQUEST.md#penpot-작업완료-화면-관리-공통-지침)을 따른다.

## 1차 API 개발 요청과 다음 행동

| 항목 | 담당·현재 상태 | 다음 행동·완료 조건 |
|---|---|---|
| G-DISPLAY: 멤버 스펙/활동 캐릭터·금지목록·활동시각/요청배지 | Backend Issue12 / 92c1702f 설계 제안 확인, 미구현 | Backend 명세/구현 인계, Flutter gemValidationSnapshot·integrity 표시의 issues/code 소비 매핑 대조. opt-in/집계 기준은 설계39 |
| G-MANAGE/G-RAID: 조건부 그룹 해산·추방·대표·그룹 모집 | Backend Issue16 / cb9b6b9c 권한 정정 설계 수용·미구현 | 정정 설계로 구현 인계. 그룹장 별도 context/공개전환/해산 제외. 해산검사·방 안내/기존 참가보존 계약·구현 인계. 1인/다인 강제종료 선택은 대기 항목 아님 |
| G-RECOVERY: 유효 후임 없는 계정자격상실 | 현재 서버 보장/기존 정책 먼저 대조 | 기술 범위로 해결 안 되는 경우만 사용자 결정. 단순 그룹탈퇴와 혼동 금지 |
| 후속 구현 | Flutter / 그룹탭 연결은 미착수·Backend는 1차 개발 요청됨 | 계약 회신 반영 후 조회/생성→관계/코드→이전/탈퇴→미제공 관리/레이드 순서의 해당 구현 구간 확정. 전체 완료로 성급히 표시하지 않음 |

협업: [Issue12 1차 표시자료 API 개발 요청](https://github.com/heo0328/lostparty-backend/issues/12#issuecomment-6464116834) · [Issue16 1차 그룹 관리 API 개발 요청](https://github.com/heo0328/lostparty-backend/issues/16#issuecomment-6464117245). 사용자 명시 지시로 이전 ‘계약 확인만/구현 요청 아님’ 단계에서 개발 요청으로 전환했다. Backend는 명세를 먼저 게시하고 확정 범위의 독립 구현·직접검증·source/OpenAPI·push·개발환경 반영/실행상태·미확인을 인계한다. 추가 제품 결정이 필요한 부분만 분리하며 시안/Flutter 소비회신으로 전체 서버 구현을 대기하지 않는다. Backend 회신은 [Issue12](https://github.com/heo0328/lostparty-backend/issues/12#issuecomment-6464713065)·[Issue16](https://github.com/heo0328/lostparty-backend/issues/16#issuecomment-6464713503)에서 확인했다. 두 회신은 설계 제안이며 실행 API/OpenAPI·서버/DB 변경0, Flutter 연결/실기기 미실행이다. Backend 자체 승인 구간이 설계까지였다는 보고와 기존 Flutter 개발 요청을 구분하며 실제 구현 완료로 표시하지 않는다. [Issue16 최신 권한 정정 회신](https://github.com/heo0328/lostparty-backend/issues/16#issuecomment-6464943488)을 게시·재조회 확인했다. [Backend 정정 수용 회신](https://github.com/heo0328/lostparty-backend/issues/16#issuecomment-6465101118)에서 전용 명령 제외를 확인했다. 권한 정정 대기는 해소됐고 실제 구현 인계는 남았다. Flutter 기능코드는 이번에 수정하지 않는다.

## 현재 구간 밖의 차후 수정안

모집 기기 인수·dev/main 통합은 완료 이력(DEV_LOG)을 따른다. 제안 정밀도·보류 UX·웹소켓·생성 복귀 제보·제품/계정/출시 후속의 현재 상태·담당·완료 조건은 [차후 수정안](../product/DETAIL_IMPROVEMENTS.md)에 통합했다. 이 파일에는 같은 수정안을 다시 복제하지 않는다. 그룹 설계 착수로 기존 보류가 해제된 것은 아니다.

그룹 정원 초과 예외의 범위 질문은 해소됐다. 기존 정원 초과 제한은 유지하며, 그룹 해산/삭제 후 기존 레이드 보존과 사라진 그룹을 통한 신규 모집 불가 기준은 제품 계약 §13·설계39 G-RAID에 통합했다. 일반 그룹 해산의 허용 조건 변경으로 확대하지 않는다. [Issue16 범위 확인 회신](https://github.com/heo0328/lostparty-backend/issues/16#issuecomment-6463878563)을 게시·재조회 확인했다.
