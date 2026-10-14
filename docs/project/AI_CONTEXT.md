# AI CONTEXT — 현재 프로젝트 상태

갱신: 2026-10-14. 기본 경로 D:/dev/projects/lost_party_flutter. 통합 기준 dev. 서버 등록 관리·로컬 빈 이름 자동 표시·정보 갱신 응답/안내 수정은 구현·자동 검증 완료. 사용자가 서버 등록·삭제·재로그인 뒤 원정대 표시 및 최신 갱신 안내 정상 동작을 확인했다. 현재 구간을 dev에 통합·push하고 대기한다. 전투력 수집·갱신 연결은 후속 필요로 기록했으며 구현은 시작하지 않는다. 상세 실행 기준은 [NEXT_WORK](NEXT_WORK.md), 완료 경과는 [DEV_LOG](DEV_LOG.md).

## 현재 구현과 인수

- Google Credential Manager·Backend 자체 세션·로그인 유지/로그아웃을 사용한다. Firebase SDK/구 MyApp/Router·익명 Player/Firestore 실행 경로를 제거했다. OAuth 등록·로컬 캐릭터/빌드/키는 유지한다.
- Backend #3 구현254cb5d/인계406004e의 원본 계약을 고정하고 서버 등록 목록·등록별 전체 캐릭터/settings 조회를 연결했다. 서버 UUID·상태·private 메모리는 로컬 SQL/정수 PK와 구분한다. [Flutter 조회 계약16](../backend-migration/16-account-read-flutter-contract.md).
- 별도 작업 트리와 기본 프로젝트의 빌드 불일치를 복구했고, 기본 경로에서 조회 기능 포함 APK 빌드를 확인했다. 사용자 1·2·4 통과: 로그인 서버 빈 등록 안내, 로그아웃 로그인 안내와 로컬 화면 보존. 당시 등록 자료가 없어 3번 캐릭터 조회는 후속 인수로 분리했고, 이후 등록 관리 구간에서 사용자가 등록 원정대 캐릭터 표시를 확인했다. 전체 페이지/세 revision의 실제 데이터 검증까지 확대하지 않는다.
- 기존 조회 소스 전체1159테스트·분석0과 기본 경로 APK 빌드/마커 검증을 기록했다. 기본 경로의 기존 미추적 실험은 보존했으며 소스 동일성으로 자동 검증을 재사용한다. 이 결과는 조회 구현의 검증 기록이며, 이후 화면 배치 변경은 별도 페이지10개 테스트/분석으로 검증했다.
- Flutter preview/등록·수정·제거·갱신 UI/쓰기를 연결했다. [등록 연결 계약19](../backend-migration/19-account-registration-flutter-contract.md). 사용자가 서버 등록·삭제·재로그인 후 등록 원정대 캐릭터 표시를 확인했으며 정보 갱신 안내도 정상 확인했고, 서버 표시명/본계정 수정의 전체 인수와 #3 장비/활동 기능 인수는 남아 있다. 서버 장비 인증 및 활동·대표 저장 UI는 그다음이다. 다음 실행 근거는 [NEXT_WORK](NEXT_WORK.md), 전체 단계는 [연결 계획14](../backend-migration/14-my-account-flutter-integration-plan.md), 완료 경과는 [DEV_LOG](DEV_LOG.md).
- [등록 관리 Backend 요청17](../backend-migration/17-account-registration-backend-request.md): 조회 결과를 #3에 인계하고 실행 버전·서버 키 준비 여부·실 provider 등록 시험 조건과 필요한 최소 보완을 요청한다. 기존 API를 중복 개발하지 않는다.
- [새 등록 구간 제안18](../backend-migration/18-account-registration-integration-proposal.md), [Backend #4](https://github.com/heo0328/lostparty-backend/issues/4): #3 보완db0f3ae/계약254cb5d 유지 인계를 근거로 키 준비·실 provider/등록 검증과 필요한 보완을 별도 추적한다. 후속 키 준비/실provider 인수는 #4에서 추적한다.

## 협업 채널

다른 공유 방식 채택 전까지 Backend GitHub Issues를 협업 채널로 사용한다. 피드백·테스트 요청은 필요시만 하며 모든 작업마다 요구하지 않는다. 협업 요청에 대응한 결과와 필요한 인계는 기록하고 회신한다. 현재 승인 구간의 관련 댓글 회신은 상시 승인된다. [공통 협업·콜백 규칙](ai_rules.md#8-2-flutter--backend-github-issues-협업콜백).

## 기준과 보존 정책

- 기존 Firebase 사용자/서버/테스터 자료는 이관하지 않는다. 로컬 자료는 보존하지만 앱 삭제 시 기기 자료가 사라질 수 있고 Google 로그인만으로 로컬 자료가 복원되지는 않는다. [이전 정책](../backend-migration/09-migration-decisions.md).
- Google 앱 회원 인증과 게임 계정 소유 인증은 별개다. [Google 로그인 계약](../architecture/GOOGLE_LOGIN_CONTRACT.md), [신규 서버 인증 설계](../backend-migration/11-auth-and-access-design.md).
- Backend endpoint/DTO/SQL·권한은 heo0328/lostparty-backend가 소유한다. [Issue #3](https://github.com/heo0328/lostparty-backend/issues/3), [원본 계약 snapshot](../backend-migration/contracts/issue3-254cb5d.openapi.json). 실제 provider 증거/키·장비/소유권 이전 인수는 Backend 보류 정책과 별도 공동 검증 대상이다.
- [테스트 준비15](../backend-migration/15-my-account-test-readiness.md)는 초기 준비 기록과 후속 인계를 구분한다. 모집/파티/그룹/주간·운영 기능 연결은 아직 후속이다.
- Firebase 제거 원본과 조회 원본 작업 트리, 미추적 Rules 실험·백업은 보존한다. 조회 원본은 기본 경로로 브랜치를 옮긴 뒤 detached 상태다. Git 정리 전에 소유/목적과 충돌 여부를 확인한다.
- 기존 서비스 전용 문서는 [레거시 지도](../../legacy/firebase/README.md)에서 보관하며 과거 실행 지시를 신규 서버 승인으로 사용하지 않는다. 전체 문서 지도는 [docs/README](../README.md).

## 후속 상태

- 로컬 빈 이름 자동 표시 완료: 기존 label/schema13 사용, 미입력은 현재 본·부계정 위치별 자동 이름, 입력값은 그대로 표시. [이름 계약20](../backend-migration/20-account-auto-label-contract.md). 서버 빈 이름 연결은 Backend #4 계약 인계 후 진행한다.
- RefreshOut.registration 응답 처리와 갱신 수/서버 조회 시각 안내 완료, 사용자 정상 동작 확인. [등록 계약19](../backend-migration/19-account-registration-flutter-contract.md).
- 전투력 표시 UI는 존재하지만 일반 원정대 조회에서 전체 캐릭터 전투력을 수집·갱신하는 연결은 미구현. 서버/로컬 데이터 출처와 후속 범위는 NEXT_WORK에 기록했다. 장비 인증·활동/대표 저장도 후속이며 이번 통합을 #3 전체 완료로 취급하지 않는다.
