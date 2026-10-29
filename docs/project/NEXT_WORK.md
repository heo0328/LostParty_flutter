# NEXT WORK — 레이드 모집 그룹 연결·표시 수정

## 현재 작업·기준

현재 브랜치 feature/group-backend-integration을 유지한다. 기존 그룹 잔여 기능은 사용자 전체 정상 보고로 인수했다. 이번 범위는 생성 그룹 선택→그룹 전용 기본값, 일반 모집의 최초 그룹 연결, 카드 서버 그룹명, 비그룹원의 참가자 소속 표시 네 항목이다. 기존 통과를 반복 시험 조건으로 되돌리지 않는다.

생성은 기존 생성 API 한 번, 생성 후 사용자의 명시적 최초 연결은 기존 공통설정 API 한 번으로 연결+공개범위를 원자 처리한다. 사전 조회/검토와 동일 원본문·키 복구는 별개다. [공통 단일 명령 원칙](ai_rules.md#6-architecture-principles), [그룹 제품 §9](../product/GROUP_PRODUCT_FLOW.md), [모집37](../backend-migration/37-raid-scheduling-and-multi-raid-planning.md), [연결39](../backend-migration/39-group-flutter-integration-design.md)를 따른다. A→B 교체/연결해제·방복제·이중 원장은 제외한다.

## 상태·담당·다음 행동

| 항목 | 현재 상태·담당 | 다음 행동·완료 조건 |
|---|---|---|
| 생성 그룹 선택 | Flutter: 선택 시 groupId와 groupOnly를 함께 설정. 연결 없음은 public. 이후 명시 public 선택은 그룹 유지 | 기존 생성 본문·명령 1회 보존 검증 후 기기 확인 |
| 일반 방 최초 연결 | Backend 고정계약 대기 | [Issue16 승인 구현 요청](https://github.com/heo0328/lostparty-backend/issues/16#issuecomment-6502336731): 기존 common-context/common-settings에서 대상 그룹 증거·C/N 공통영향/권한·원자 처리와 직접 검증 인계. 고정 필드 확인 전 Flutter 요청을 추측하지 않음 |
| 카드 그룹명·상태 | 배지 구현, 기존 내 그룹명 대조는 임시이며 서버 DTO 대기 | [Issue12 표시 요청](https://github.com/heo0328/lostparty-backend/issues/12#issuecomment-6501551683). 소속 밖 공개 연결 그룹 포함 서버 표시값을 목록 조회에 함께 제공. 카드별 조회 금지 |
| 비그룹원 소속 표시 | 사용자 제보, 원인 조사/Backend 대응 확인 필요 | 기본 상세는 room.group_id에 따라 배지, 현재 cycle_member_reads는 대상 사용자 소속 계산. 실제 membership/application reader 경로에서 같은 응답인지 Backend 인계 후 최소 수정. null을 false로 간주하지 않음 |
| Penpot03 | 기존 그룹 보드·390×844 유지, 현재 초대 화면만 최신화/PNG 확인 | 기존 생성/상세/모집 카드의 실제 변경분 대조·같은 섹션 갱신. 전체 디자인/내비게이션 일치 검증과02 이동은 미완료 |

최신 실행 인계는5d24244b/DB0034(초대 검색/역할표시), 업무 계약c3814452다. 이번 최초 연결·카드 그룹명 확장의 구현/반영 완료를 의미하지 않는다. Backend 계약→서버 구현/직접검증 및 Flutter 연결→검증·커밋/푸시·Issue회신→실제 개발환경 반영 확인→사용자 인수 순서다. 기존 환경·자료 수명 정책을 유지하고 실제 배포/DB변경·초기화/dev-main 통합은 별도다.

## 보호·검증·완료

원본문/멱등키·과거 ACK/새membership·성공 후 조회실패·회원/환경/늦은응답, 기존 C/N 참가/신청/배정/일정/예약/완료를 보존한다. 실패한 연결에 부분 상태가 남지 않아야 한다. 그룹 선택/공통설정 성공 뒤 목록·상세·필터/context·그룹 레이드 자료를 갱신한다.

자동시험은 최초 연결 동시성/현재 권한·revision·원자성, 응답 유실·원ACK, 조회자별 같은 소속 표시·그룹명/null 경계에 집중한다. Flutter 직접 시험·분석/포맷/diff 검토, 공용 영향이 표적 시험으로 설명되지 않을 때 전체 시험으로 확대한다. 기기는 변경된 생성 기본값·일반 방 최초 연결·공개 왕복·비그룹원 배지·카드 긴 이름만 확인한다. 기존 로그인/인증·그룹 정상시험은 반복하지 않는다.

현재 파트의 미커밋 공통 지침/사용자 인수 기록은 관련 구현 커밋에 함께 보관한다. 통계35와 기존 미추적 사용자 자료는 보존한다. 소분류 보관은 작업 브랜치 local/origin 일치로 판단하고 전체 완료/서버 반영/기기 인수와 구분한다.

## 범위 밖

G-RECOVERY 복구승계·운영정리/자료삭제·웹소켓/공지/통계는 제외. 나머지 보류/미채택 후속은 [차후 수정안](../product/DETAIL_IMPROVEMENTS.md)에 통합하며 같은 내용을 새 문서로 늘리지 않는다. 완료 이력·기기 인수 출처는 [DEV_LOG](DEV_LOG.md), 디자인 작업 운영은 [공통 지침](../design/LOSTPARTY_DESIGN_SYSTEM_V1_REQUEST.md#penpot-작업완료-화면-관리-공통-지침)을 따른다.
