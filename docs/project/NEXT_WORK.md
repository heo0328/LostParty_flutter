# NEXT WORK — Firebase 실행 코드·SDK·플랫폼 설정 최종 제거

2026-10-14. 상태: 다음 구간 기획·실행 대기. 직전 테스트 전환/안정화는 DEV_LOG와 [분류 대장](TEST_TRANSITION_INVENTORY.md)에 기록했다. 사용자 수동4항목 통과·전체1134테스트 통과. 추적 활성 lib/test/tool 분석 진단0, 전체 분석은 미추적 실험3info가 남는다.

## 목표와 원칙

신규 BackendApp과 로컬 기능·Google Credential Manager를 보존하면서 폐기 Firebase 실행 경로/SDK/플랫폼 결합을 제거한다. 기존 Firebase 사용자·서버 데이터·테스터 자료는 이관하지 않는다. 로컬 계정·캐릭터·빌드·Lost Ark 키를 파괴하거나 신규 회원 소유로 승계하지 않는다.

Google 로그인에 사용하는 기존 Google Cloud/OAuth 프로젝트·Android/Web client 등록은 유지한다. Firebase SDK 제거와 Google OAuth 프로젝트 삭제는 별개다. 콘솔·원격 데이터/제공자 설정을 이번 앱 정리 승인으로 삭제하지 않는다.

## 포함·제외

포함 후보: lib/main.dart의 미사용 MyApp/구 Router·initializer, Firestore adapter·DTO·binding과 SDK 의존성, 폐기 Firebase 전용 tools/배포 실행 경로, Android/iOS 등 Firebase 플랫폼 설정·생성 파일·pubspec/lock. 직접 참조와 실제 사용처를 확인해 파일별 제거/유지/분리 계획을 먼저 확정한다.

제외: 원격 Firebase 프로젝트/데이터·OAuth client 삭제, Backend 업무 API 구현, 동일캐릭터 역할 변경 신규 지원, DB 초기화/마이그레이션, 운영 배포·릴리즈·main 통합, 기존 미추적 실험/백업의 일괄 삭제.

## 구현 전 조사와 순서

1. 최신 dev·기존 목적 브랜치·미커밋 소유를 확인한다. 현재/기존 목적 브랜치가 적합하면 재사용하며 dev에서 직접 수정하지 않는다.
2. Firebase import·DI/Router/SDK·Gradle/플랫폼·도구 참조를 현재 호출 경로와 대조한다. 기존 코드가 사용 중이라는 이유만으로 폐기를 미결정으로 되돌리지 않되, 공통 기능과 혼합된 정책을 임의 삭제하지 않는다.
3. 대장의 이식 대기5파일과 Firebase 타입을 소비하는 공통 정책을 재검토한다. 필요한 정책은 순수 Domain/새 DTO 경계로 분리하며 의미를 유지한다. 새 업무 계약이 없으면 추측 DTO/API를 구현하지 않고 대체 검증 책임을 기록한다.
4. 제거 순서·영향 파일·회귀 보호·완료 조건을 기록한 뒤 코드·의존성·플랫폼 설정을 정리한다. Google nonce bridge·client ID·origin별 세션 저장·로컬 DB/토큰 경계는 유지한다.
5. 최종 format·diff, 전체 flutter test/analyze와 Android 컴파일을 영향에 맞게 확인한다. 설치·기기 조작은 사용자가 수행하며 코드 변경 없는 수동 통과 항목을 반복 요청하지 않는다.
6. 문서·실행 명령을 최신화하고 사용자 승인된 Git 흐름에 따라 dev 통합·push 결과와 별도 미추적 실험 상태를 보고한다.

## 보호·완료 조건

- 비로그인 로컬 기능, 선택형 로그인 유지·복원/로그아웃, 보호 기능 안내, 시작 배경·debug URL, release HTTPS 경계가 유지된다.
- 신규 실행·빌드의 Firebase SDK/초기화 참조가 제거되고 retained 테스트가 공통 정책을 검증한다. Firebase 제거와 모집/그룹 API 구현 완료를 혼동하지 않는다.
- 같은 캐릭터 반대 역할은 제품 요구로 유지하되 현재 폐기 writer에서 미지원이다. Backend 동일 state 원자 update 설계와 함께 구현해야 하며 이 SDK 정리 구간에서 지원 완료로 처리하지 않는다.
- 원격 설정/데이터·Google 등록과 기존 로컬 DB를 삭제하지 않는다. 필요한 사용자 기기 확인과 미추적 분석 한계는 별도 기록한다.
