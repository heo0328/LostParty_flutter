# NEXT WORK — 서버 계정 등록 관리 연결

2026-10-14. 기본 경로 D:/dev/projects/lost_party_flutter, 통합 기준 dev. 내 계정 디자인은 사용자 승인으로 메인 계정 등록 현황 → 부계정 등록 현황 → 계정 도구 순서를 확정했다. 디자인 완료/검증 이력은 DEV_LOG, 장기 배치 기준은 [디자인 계약](../design/LOSTPARTY_DESIGN_SYSTEM_V1_REQUEST.md). 이후 등록 기능은 현재 배치를 유지한다.

## 다음 그룹의 목표·범위

[연결 계획14](../backend-migration/14-my-account-flutter-integration-plan.md)의 등록 관리: 캐릭터명 preview → 본/부계정 등록 → 등록 캐릭터 조회 → label/본계정 수정·등록 제거·요약 갱신. Backend 구현254cb5d/인계406004e와 원본 contracts/issue3-254cb5d.openapi.json을 기준으로 한다. 기존5개 API는 구현됐고 Flutter 등록 UI/쓰기 adapter가 후속 대상이다.

[요청17](../backend-migration/17-account-registration-backend-request.md)을 [이슈 #3](https://github.com/heo0328/lostparty-backend/issues/3#issuecomment-6161970774)에 게시·본문 검증 완료했다. 다음 작업 시작 시 최신 회신의 실행 버전/0002·서버 provider key 준비 여부(값 제외)·실 preview/등록 시험 조건과 필요한 계약 보완 SHA를 확인한다. 현재 디자인 통합에서 Backend 회신 조회나 신규 등록 구현을 진행하지 않는다.

## 구현 순서·보호

1. Backend 원본 DTO·오류/멱등·본계정/version·등록 제거 의미와 Flutter Repository/세션 연결을 조사하고 구체적 설계를 먼저 기록한다.
2. 등록 관리 단일 그룹만 연결한다. 로컬 정수 PK/자료와 서버 UUID·등록 관계를 분리하며 로컬 캐릭터/빌드/키를 자동 업로드하거나 삭제하지 않는다. preview/등록을 소유 인증 완료로 취급하지 않는다.
3. 같은 사용자/동작 재전송에 key와 payload를 고정한다. 응답 유실·진행중/TTL·hash 충돌에 자동 새 key 쓰기를 하지 않고 동일 요청 복구와 GET으로 판별한다.
4. 401 세션과 업무403을 구분하고 회원/로그아웃/같은 회원 재로그인의 늦은 응답을 격리한다. 기존 GET·빈 목록·guest 안내와 현재 메인/부계정/도구 배치를 보존한다.
5. 멱등·응답 유실/충돌·회원 전환·실패 시 성공 위장 방지 경계를 검증한 뒤 사용자가 등록·수정·제거·갱신/로컬 보존과 등록된 캐릭터 화면을 확인한다. 조회3번은 실제 등록이 생긴 이 구간에서 인수한다.

서버 key가 없으면 외부조회503 UPSTREAM_UNAVAILABLE가 예상된다. 값은 Issue/로그에 게시하지 않고 provider 증거 보류를 우회하지 않는다. 제외: 장비 인증/소유권 이전·활동/대표 PUT, Backend DB/API 변경·배포·데이터 이관/초기화·기기 설치/조작·기존 실험 변경.

## Git 기준

Firebase 제거 a160c6f·조회6f97190 dev 통합3cedd9d, Backend 요청 문서 통합06758d1은 push 완료했다. 이번 사용자 승인 범위는 내 계정 디자인과 관련 테스트/문서의 커밋·dev 병합·push이며 최종 SHA/원격 일치는 Git 확인이 기준이다. 작업 브랜치 feature/account-character-dashboard는 병합 후 보존/삭제 후보이며 자동 삭제하지 않는다. 다음 기능은 최신 dev에서 목적 브랜치를 확인한다. 기존 미추적 실험/백업36개와 원본 worktree는 그대로 보존한다.
