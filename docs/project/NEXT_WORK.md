# NEXT WORK — 서버 계정 등록 관리 연결

2026-10-14. 기본 프로젝트 D:/dev/projects/lost_party_flutter, 통합 기준 dev. 첫 조회 그룹 구현·자동 검증 및 사용자 1·2·4 인수 완료. 상세 완료 이력은 DEV_LOG, 고정 조회 계약은 [계약16](../backend-migration/16-account-read-flutter-contract.md).

## 다음 그룹의 목표와 범위

[연결 계획14](../backend-migration/14-my-account-flutter-integration-plan.md)의 2번 등록 관리: 캐릭터명 preview → 본/부계정 등록 → 서버 목록에서 등록 캐릭터 확인 → label/본계정 수정·등록 제거·요약 갱신. Backend 구현254cb5d/인계406004e와 원본 contracts/issue3-254cb5d.openapi.json을 사용한다. 서버 API는 구현됐으며 Flutter의 등록 화면·쓰기 adapter가 후속 대상이다.

조회 인수 후 사용자가 문서 정리·dev 병합·push를 승인했다. 이번 마감에서 신규 등록 기능 코드는 작성하지 않았다. 다음 진행 시 API 원본 DTO/오류·Repository·세션·멱등 수명을 조사하고 구체적 설계를 먼저 보완한 뒤 단일 그룹으로 연결한다.

## 현재 요청 구간

사용자 지시로 [Backend 요청17](../backend-migration/17-account-registration-backend-request.md)에 조회 결과 인계와 등록 관리 준비 요청을 작성한다. 기존 #3 댓글의 Flutter 결과 요청에 답하고, 이미 구현된 5개 등록 관리 API를 재사용한다. Backend에 실행 버전/0002·서버 provider key 준비 여부·실제 preview/등록 시험 조건·계약 차이가 있을 때의 최소 보완과 변경 SHA 인계를 요청한다. 키 값/개인정보 게시·서버 DB 조작·새 기능 코드는 제외한다. 게시 후 본문 일치를 확인하고 댓글 URL을 기록하면 이번 요청 구간을 마친다. Backend 회신은 등록 구현 설계에 반영하며 기존 실 provider 보류 정책을 우회하지 않는다.

게시 완료: [Issue #3 요청 댓글](https://github.com/heo0328/lostparty-backend/issues/3#issuecomment-6161970774). 게시 본문과 요청17 일치 확인. 다음은 Backend 회신의 실제 시험 조건을 반영하고 등록 관리 구현 설계를 보완하는 단계다.

## 보호와 구현 전 확인

- 로컬 계정/캐릭터/빌드/키와 서버 UUID·등록 관계를 분리한다. 로컬 자료를 자동 등록하거나 인증 증거로 제출하지 않는다.
- preview는 인증/소유권·활동 생성이 아니다. 등록 후 미인증 상태를 표시하고 본계정 변경·version/삭제 의미를 기존 계약으로 소비한다.
- Idempotency-Key와 payload를 같은 사용자/동작·재전송 동안 유지한다. 응답 유실/REQUEST_IN_PROGRESS/TTL·hash 충돌에서 자동 새 key 쓰기를 하지 않고 동일 요청 복구/GET으로 판별한다.
- 401 세션과 업무403을 구분하고 로그아웃/같은 회원 재로그인/이전 요청 응답을 격리한다. 기존 GET·빈 목록·guest 안내를 보존한다.
- provider key가 없으면 외부 조회에503 UPSTREAM_UNAVAILABLE가 예상된다. 준비 여부는 안전한 방식으로 확인하고 값을 Issue/로그에 출력하거나 Flutter 개인 키를 서버로 자동 업로드하지 않는다.

제외: 장비 인증/소유권 이전·활동/대표 PUT는 다음 별도 그룹, Backend DB/API 변경·배포·데이터 이관/초기화·기기 설치/조작·기존 실험 변경.

## 후속 검증과 현재 Git

자동 검증은 멱등 요청 고정·응답 유실/충돌·회원 변경의 늦은 결과·실패 시 서버/로컬 성공 위장 방지에 집중한다. 등록 UI 연결 후 사용자가 신규 등록·수정·제거와 로컬 보존을 확인한다. 이전 조회 3번(등록 계정의 캐릭터 화면)은 등록이 생긴 후 그 구간의 인수로 확인한다.

현재 사용자 확인: 로그인 서버 빈 목록, 로그아웃 로그인 안내, 1·2·4 통과. 기존 조회 소스 전체1159테스트·분석0, 기본경로 APK 빌드/기능마커 확인은 완료했다. 이번 문서만 변경하므로 Flutter 검증은 반복하지 않는다.

기준 구현 커밋: Firebase 제거 a160c6f, 서버 조회 6f97190. 이전 구간은 dev/origin/dev 3cedd9d로 통합·push 완료했다. Backend 요청 문서는 기존 docs/my-account-backend-phase1에서 작성·게시 검증 완료했고 사용자 승인으로 커밋·dev 통합·push한다. 다음 사용자 지시는 내 계정 화면의 메인 계정→부계정→기타 기능 재배치다. 구체적 설계는 해당 목적 브랜치에서 코드 확인 후 기록한다. 다음 등록 작업은 최신 dev와 목적 브랜치·권한 계약을 다시 확인한 뒤 진행한다. 기존 미추적 실험36개와 원본 작업 트리는 보존하며 다음 기능 승인이나 Git 통합으로 자동 삭제하지 않는다.
