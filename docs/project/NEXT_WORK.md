# NEXT WORK — 그룹 전체 흐름 설계·계약 보완

## 현재 구간

사용자는 2026-10-28 그룹 전체 흐름 조사·설계 문서화를 승인했다. 최신 dev bdfe0edf에서 feature/group-backend-integration을 시작했다. 종료 조건은 전체 그룹 설계·연결·검증 후 dev 통합이며 이번 파트는 문서화만 보관한다. 기존 개별 그룹 수정/과거 Task 브랜치는 재사용 목적이 달라 보존했다.

[제품 계약](../product/GROUP_PRODUCT_FLOW.md)·[연결 설계39](../backend-migration/39-group-flutter-integration-design.md)에 기존 UX·식별자/권한·서버 제공 API·조회/명령 수명·단계별 회귀/완료 조건을 정리했다. 현재 그룹 Router는 pending, 기능 연결·자동/실기기 검증은 미착수다. 현재 설계 문서 파트의 검증은 내용·링크·diffcheck이며 Flutter 시험/설치·서버/DB·자료삭제·dev/main 통합은 하지 않는다.

Backend dev 1b6f57bb의 현재 문서/소스/OpenAPI를 확인해 과거404는 문서이동으로 해소했다. G1/G2 및 관리조회·이전/일반탈퇴는 제공, 해산 write는 현재도 없고 GROUP_RECRUITMENT_STATE_UNAVAILABLE다. 완료 조사/과거 구현 이력은 DEV_LOG로 이관했다.

## 계약 확인 대기와 다음 행동

| 항목 | 담당·현재 상태 | 다음 행동·완료 조건 |
|---|---|---|
| G-DISPLAY: 멤버 카드 스펙/활동 캐릭터 펼침·금지목록 표시·활동시각/요청배지 | Backend Issue12 / 계약 확인 요청 | 기존 UX를 유지할 최소 공개자료·일괄조회/식별자·cursor/수명·총수 지원 또는 재사용 계약 회신, Flutter 설계 반영 |
| G-MANAGE/G-RAID: 해산·추방·대표/복구승계·비참가 그룹장 방관리 | Backend Issue16 / 현재 미제공·계약 확인 요청 | 실제 모집 원본/권한·CAS·ACK·기존 참가보존 및 그룹 소멸 후 기존 방 유지/신규 그룹모집 차단 계약과 구현 제공 범위 제시. 미정 제품 선택만 Flutter와 분리 협의 |
| G-RECOVERY: 유효 후임 없는 계정자격상실 | 현재 서버 보장/기존 정책 먼저 대조 | 기술 범위로 해결 안 되는 경우만 사용자 결정. 단순 그룹탈퇴와 혼동 금지 |
| 후속 구현 | Flutter / 이번은 설계만 승인 | 계약 회신 반영 후 조회/생성→관계/코드→이전/탈퇴→미제공 관리/레이드 순서의 해당 구현 구간 확정. 전체 완료로 성급히 표시하지 않음 |

협업: [Issue12 표시자료 계약 질문](https://github.com/heo0328/lostparty-backend/issues/12#issuecomment-6463441052) · [Issue16 관리/실제 모집 검사 질문](https://github.com/heo0328/lostparty-backend/issues/16#issuecomment-6463441628). 게시 후 재조회·본문 일치를 확인했다. 기존15/5·즉시이전·기존 레이드 유지·코드 정책은 결정 완료이며 재질문하지 않는다. 서버 준비가 필요한 기능을 숨기거나 기존 UI를 축소하지 않는다. 모집/계정 정상 흐름은 회귀 보호하며 이전 기기 인수를 반복하지 않는다.

## 현재 구간 밖의 차후 수정안

모집 기기 인수·dev/main 통합은 완료 이력(DEV_LOG)을 따른다. 제안 정밀도·보류 UX·웹소켓·생성 복귀 제보·제품/계정/출시 후속의 현재 상태·담당·완료 조건은 [차후 수정안](../product/DETAIL_IMPROVEMENTS.md)에 통합했다. 이 파일에는 같은 수정안을 다시 복제하지 않는다. 그룹 설계 착수로 기존 보류가 해제된 것은 아니다.

그룹 정원 초과 예외의 범위 질문은 해소됐다. 기존 정원 초과 제한은 유지하며, 그룹 해산/삭제 후 기존 레이드 보존과 사라진 그룹을 통한 신규 모집 불가 기준은 제품 계약 §13·설계39 G-RAID에 통합했다. 일반 그룹 해산의 허용 조건 변경으로 확대하지 않는다. [Issue16 범위 확인 회신](https://github.com/heo0328/lostparty-backend/issues/16#issuecomment-6463878563)을 게시·재조회 확인했다.
