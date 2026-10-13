# AI CONTEXT — 현재 프로젝트 상태

갱신: 2026-10-14. 인증 작업 브랜치: `feature/google-login`. 사용자 요청에 따라 현재 인증 구현·기획을 dev에 통합한다.

## 현재 작업

다음 작업 그룹은 **로그인·세션 인수 검증과 Firebase 테스트 정리**다. [NEXT_WORK](NEXT_WORK.md)에 포함·제외 범위, 분류 기준, 순서와 완료 조건을 기록했다. 현재는 기획 완료·실행 대기이며 이번 요청에서 코드·테스트·CI를 변경하지 않았다.

Firebase 전용 테스트는 활성 저장소에서 제거하고 Git 이력에 보존한다. 유효한 공통 정책은 유지/이식하고 로컬·신규 인증 테스트는 유지한다. 테스트의 legacy 이동이나 일괄 skip을 기본으로 채택하지 않는다.

## 구현과 인수 상태

- BackendApp 진입점, Android 요청별 nonce Google 인증, Backend 6API adapter, 세션 복원·refresh·로그아웃과 로그인/설정 UI가 작업 트리에 구현돼 있다. 사용자가 에뮬레이터 로그인 성공을 확인했다. 세션 유지·만료·종료 인수와 서버 계약 revision 고정은 남아 있다.
- 비로그인 로컬 계정·캐릭터·빌드·설정은 유지한다. 공개 모집과 그룹·원정대 본 API는 후속 계약 대상이며 현재 준비 안내를 표시한다.
- debug 시작 URL 알럿, 로그인 성공 후 화면 복귀, 기존 로딩 배경 연결과 중앙 Shine 제거를 반영했다. 최신 로딩 수정의 기기 확인은 남아 있다.
- 기존 MyApp/Router와 Firebase 소스·의존성이 남아 있다. 신규 진입점의 Firebase 미사용과 프로젝트에서 Firebase 완전 제거를 구분한다.
- 사용자 지시로 인증 구현·관련 문서를 커밋해 dev에 병합·푸시하는 복구 지점으로 기록한다. 다음 작업 그룹의 실제 테스트 정리·세션 인수는 실행 대기다. 기존 별도 Rules 실험·백업 변경은 보존한다. 과거 전체 검증 실패와 표적 검증 상세는 [DEV_LOG](DEV_LOG.md)에 있다.

## 확정된 이전 정책과 기준 문서

- Firebase 사용자·서버 데이터·테스터 데이터를 이관하지 않고 FastAPI/PostgreSQL을 빈 상태로 시작한다. 로컬 캐릭터·빌드·설정은 보존한다. [이전 결정](../backend-migration/09-migration-decisions.md).
- Google 앱 인증과 게임 원정대 소유권은 별개다. 비로그인 서버 회원 생성 없음, 선택형 로그인 유지, 서버 자체 세션을 사용한다. [Google 로그인 계약](../architecture/GOOGLE_LOGIN_CONTRACT.md), [신규 인증 설계](../backend-migration/11-auth-and-access-design.md).
- Backend endpoint/DTO/SQL 계약은 `heo0328/lostparty-backend`가 소유한다. [협업 Issue #2](https://github.com/heo0328/lostparty-backend/issues/2). 로컬 구현 보고와 원격 반영 여부는 별도 확인한다.
- 신규 서버 전체 조사·설계: [백엔드 문서 지도](../backend-migration/00-overview.md). Firebase 전용 문서는 [레거시 지도](../../legacy/firebase/README.md)와 [출처 대장](../../legacy/firebase/PROVENANCE.md)에 보관하며 과거 실행 지시를 현재 승인으로 사용하지 않는다.
- 이전 설계·문서 보관 작업은 dev `64b09bf`에 통합됐다. 그 이후 인증 구현의 이번 통합과 혼동하지 않는다. 최종 커밋·원격 동기화 결과는 Git 이력과 DEV_LOG를 따른다.

문서 탐색은 [docs 지도](../README.md), 상세 작업은 NEXT_WORK, 완료 이력은 DEV_LOG를 따른다. 과거 전체 문맥은 [원문 발췌](../../legacy/firebase/extracted/docs/project/AI_CONTEXT.md)와 [추가 발췌](../../legacy/firebase/extracted/additional/docs/project/AI_CONTEXT.md)를 참고한다.
