# AI CONTEXT — 현재 개발 상태와 기준 문서

## 개발·협업 기준

1인 개발, Firebase 구현 제거·자체 Python Backend·단일 Google 로그인. 현재 환경에서 개발하고 관련 앱/Backend 구현 후 테스트한다. 베타 시작 전 개발자료를 비우며 베타 이후 자료는 보존한다. 실제 초기화 실행은 별도 대상/시점 지시가 필요하다. [정책09 D08](../backend-migration/09-migration-decisions.md#d08-개발--베타--운영-데이터-수명--사용자-확정).

설계는 위 환경/방침과 이미 확정된 UX/제품 의도를 선행 조건으로 적용한다. 사용자의 기능 흐름 확인을 기술 조건 전체의 검수로 취급하지 않는다. 작업/문서 책임은 [AGENTS](../../AGENTS.md), 상세 [ai_rules](ai_rules.md), 현재 단일 실행 계획과 유효 후속은 [NEXT_WORK](NEXT_WORK.md)다. 브랜치는 대단원, 소분류 파트 완료에 커밋/푸시, 통합은 대단원 완료 시 별도다. 같은 브랜치에서 지침·버그기록·UI 보완도 처리한다.

## 현재 작업과 실제 코드 상태

작업 브랜치는 `feature/raid-recruitment-scheduling`. 지시문 정상화 e3d4cd20 이후 B 일반 앱 연결c3c68d7e와 일정/개방 입력 연결을 마쳤다. A 기반은 유지하고 일반 BackendApp의 구계약 선택 인자를 제거했다. 서버/DB·dev/main은 변경하지 않았다. 기존 무관 미커밋 플랫폼/DevTools·백업/tools·통계35는 보존한다.

| 영역 | 현재 확인 상태/근거 |
|---|---|
| 모집 B | 04098eae의 새 생성·기본표시/원요청 기반을 일반 main→BackendApp betaWire2에 연결. 참가/관리 Gateway도 profile과 전용 파서를 사용. 고유415PASS/변경분 분석0, 정상회원/기기·남은 화면은 미완료. 설계37 §37.70 |
| 일정/개방 입력 | 다음주 단일 날짜·시간/조율 입력→서명 context→명령, 자동조율 설정의 즉시확정 동의, 출발변경은 제안/수락 유지. 직접425PASS/변경 분석0. 그래프·제안 전용 전체화면은 후속. §37.71 |
| Backend | Issue13 [6396368027](https://github.com/heo0328/lostparty-backend/issues/13#issuecomment-6396368027), source d95e3827/DB0032 개발반영 인계 확인. 실제 Flutter 회원/기기 인수와 구분 |
| 기존 모집 | C/N 생성·상세·검색·참가/신청·관리·일정·완료/정정·기록 경로와 후속 오류수정 구현이 존재함. 최신 베타 일정/메모·일반 경로 연결까지 완료한 것은 아님. 상세 설계37/DEV_LOG |
| 계정/로그인 | Google/Backend 세션, 원정대 조회/등록/인증·기존 카드/활동·대표·설정·캐시/일괄복원·자동 갱신 연결. 개별 캐릭터 갱신은 첫 실기기 수정2ba24d95에서 복구 기록, 다시 미구현 후속으로 두지 않음 |
| 확인 범위 | 기존 개인표/설정복귀·C/N 생성/신청·레벨표시 등 사용자가 보고한 범위는 DEV_LOG 보존. 과거 자동검증 수치·Backend 보고와 실회원/기기 결과를 합산하거나 새 베타 인수로 확대하지 않음 |

## 제품·디자인 지도

- [모집·일정37](../backend-migration/37-raid-scheduling-and-multi-raid-planning.md): 두 주차와 최신 기본출발/조기조율·개인표·메모·번호 계약 및 구현 이력. C/N 생성은 한 명령으로 원자 확정하되 이후 참가·권한·탈퇴·완료는 실제 주차별 독립이다.
- [비활성 기능](INACTIVE_FEATURES.md): IF-001 미완료 종료/같은 주차 재개는 비활성. IF-002 다일/다중후보, IF-003 미정 생성은 일반 생성에서 제외됐다. 일반 일정/개방/제안에서도 다일·미정 편집을 노출하지 않는다.
- Penpot03은 승인된 최신 목표 흐름,02는 실제 앱 대조 후 갱신,04는 이전 시안 보관. 식별자/운영은 설계37 §37.65. 그림 존재를 앱 구현 완료로 해석하지 않는다.
- 계정 카드3열 균등/체크 중앙·우측i, 4인1~4/8인1-1~2-4의 실제 편성번호, 기능별 상세 버튼 위치를 유지한다. 표시/정렬에 이미 받은 유효 자료를 먼저 사용하고 확정 권한/동시성은 서버에서 검증한다.
- [품질/UX](../architecture/DEVELOPMENT_QUALITY_AND_UX_STANDARD.md)·[디자인](../design/LOSTPARTY_DESIGN_SYSTEM_V1_REQUEST.md): 사용자 이해/예측 가능성, 로컬 우선, 데이터 소유·갱신·비동기 수명, 근거 있는 검증. 즉시 전면 리팩토링 지시는 아님.

## 기타 기준과 이력

[계정 연결30](../backend-migration/30-scoped-storage-write-contract.md), [원정대 정책09](../backend-migration/09-migration-decisions.md), [인증36](../backend-migration/36-roster-ownership-dispute-flutter-design.md), [한도34](../backend-migration/34-member-limits-and-room-restrictions.md), [통계35](../backend-migration/35-weekly-member-and-group-statistics.md), [버그](BUG_REPORTS.md). 별도 남은 경계/담당은 NEXT_WORK에서 관리한다.

완료 경과·검증/커밋·실제 사용자 관찰은 [DEV_LOG](DEV_LOG.md). 정리 전 누적 원문은 [이력](history/instruction-state-before-normalization-2026-10-25.md), 감사 발견은 [보고서](INSTRUCTION_AUDIT_2026-10-25.md). 이력의 과거 대기/다음 행동은 현재 실행 지시가 아니다. [전체 문서지도](../README.md).
