# AI CONTEXT — 현재 프로젝트 상태

갱신: 2026-10-14. 기본 경로 D:/dev/projects/lost_party_flutter. 통합 기준 dev. 사용자 승인으로 Firebase 제거 a160c6f와 Backend 조회 연결 6f97190 및 인수 문서를 dev에 통합·push하는 마감 구간이다. 최종 커밋/원격 동기화는 Git이 기준이며 다음 기능은 서버 등록 관리다.

## 현재 구현과 인수

- Google Credential Manager·Backend 자체 세션·로그인 유지/로그아웃을 사용한다. Firebase SDK/구 MyApp/Router·익명 Player/Firestore 실행 경로를 제거했다. OAuth 등록·로컬 캐릭터/빌드/키는 유지한다.
- Backend #3 구현254cb5d/인계406004e의 원본 계약을 고정하고 서버 등록 목록·등록별 전체 캐릭터/settings 조회를 연결했다. 서버 UUID·상태·private 메모리는 로컬 SQL/정수 PK와 구분한다. [Flutter 조회 계약16](../backend-migration/16-account-read-flutter-contract.md).
- 별도 작업 트리와 기본 프로젝트의 빌드 불일치를 복구했고, 기본 경로에서 조회 기능 포함 APK 빌드를 확인했다. 사용자 1·2·4 통과: 로그인 서버 빈 등록 안내, 로그아웃 로그인 안내와 로컬 화면 보존. 등록이 없어 3번 캐릭터 조회는 후속 인수로 분리했다.
- 기존 조회 소스 전체1159테스트·분석0과 기본 경로 APK 빌드/마커 검증을 기록했다. 기본 경로의 기존 미추적 실험은 보존했으며 소스 동일성으로 자동 검증을 재사용한다. 이번 수동 결과 이후 코드 변경 없음.
- 서버에는 등록 API가 있으며 Flutter 등록·수정·제거 UI/쓰기가 다음 그룹이다. 서버 장비 인증 및 활동·대표 저장 UI는 그다음이다. 다음 실행 근거는 [NEXT_WORK](NEXT_WORK.md), 전체 단계는 [연결 계획14](../backend-migration/14-my-account-flutter-integration-plan.md), 완료 경과는 [DEV_LOG](DEV_LOG.md).

## 기준과 보존 정책

- 기존 Firebase 사용자/서버/테스터 자료는 이관하지 않는다. 로컬 자료는 보존하지만 앱 삭제 시 기기 자료가 사라질 수 있고 Google 로그인만으로 로컬 자료가 복원되지는 않는다. [이전 정책](../backend-migration/09-migration-decisions.md).
- Google 앱 회원 인증과 게임 계정 소유 인증은 별개다. [Google 로그인 계약](../architecture/GOOGLE_LOGIN_CONTRACT.md), [신규 서버 인증 설계](../backend-migration/11-auth-and-access-design.md).
- Backend endpoint/DTO/SQL·권한은 heo0328/lostparty-backend가 소유한다. [Issue #3](https://github.com/heo0328/lostparty-backend/issues/3), [원본 계약 snapshot](../backend-migration/contracts/issue3-254cb5d.openapi.json). 실제 provider 증거/키·장비/소유권 이전 인수는 Backend 보류 정책과 별도 공동 검증 대상이다.
- [테스트 준비15](../backend-migration/15-my-account-test-readiness.md)는 초기 준비 기록과 후속 인계를 구분한다. 모집/파티/그룹/주간·운영 기능 연결은 아직 후속이다.
- Firebase 제거 원본과 조회 원본 작업 트리, 미추적 Rules 실험·백업은 보존한다. 조회 원본은 기본 경로로 브랜치를 옮긴 뒤 detached 상태다. Git 정리 전에 소유/목적과 충돌 여부를 확인한다.
- 기존 서비스 전용 문서는 [레거시 지도](../../legacy/firebase/README.md)에서 보관하며 과거 실행 지시를 신규 서버 승인으로 사용하지 않는다. 전체 문서 지도는 [docs/README](../README.md).
