# NEXT WORK

## 기준 상태

- 통합 기준 브랜치: `main`
- 기준 상태: Firebase 초기 연결 설정, Player 식별자 검토 및 Firebase 파티 제품 흐름 1차 통합 기준이 `main`에 반영된 상태
- 작업 트리는 깨끗하며 `main`과 `origin/main`이 일치한다.
- Firebase Player binding 구현·Rules 배포·Android 실기기 검증을 완료했으며 다음 단계는 서버 `GameAccountId`·`CharacterId` 계약이다.
- Firebase 프로젝트 및 플랫폼 연결 설정은 완료됐으며 제품 흐름의 주요 정책은 `../architecture/FIREBASE_PARTY_PRODUCT_FLOW.md`에 통합했다.
- 로컬 Fake 환경에서 제품 흐름과 UI를 검증하기 위해 두었던 Firebase 구현 보류 단계는 종료됐다.
- 이제 기능 단위로 데이터 계약·서버 명령·Security Rules·테스트 경계를 먼저 확정한 뒤 Firebase 구현을 단계적으로 진행한다.
- 전체 기술 설계가 한 번에 완료될 때까지 구현을 막지 않는다. 다만 계약과 검증 범위가 정해지지 않은 서버 기능은 먼저 구현하지 않는다.

## 최근 완료 작업

### Player binding 계약·구현

- `authBindings/{authUid}`와 `players/{playerId}`의 최소 스키마 및 최초 생성·재사용 계약을 확정했다.
- Firestore Transaction으로 Player와 binding을 원자 생성하고 기존 binding은 연결된 active Player 검증 후 재사용한다.
- Player binding이 완료될 때까지 기존 앱 진입을 지연하며 실패는 공용 재시도 화면으로 전달한다.
- `cloud_firestore` 의존성과 플랫폼 플러그인 등록을 반영했다.
- 클라이언트 최초 생성과 자기 문서 단건 읽기만 허용하고 목록·수정·삭제·기존 Player 임의 연결을 차단하는 Rules를 배포했다.
- Firebase CLI에서 Rules 컴파일과 `lost-party` 프로젝트 배포를 완료했다.
- `flutter analyze`와 전체 `flutter test` 234개를 통과했다.
- Android 실기기에서 최초 Player와 binding 문서 쌍 생성, 연결 ID 일치, 기존 Drift 데이터 유지와 재실행 시 동일 binding 재사용을 확인했다.
- 재실행 시 불필요한 Player 문서가 추가되지 않는 것을 확인했다.

### Anonymous Auth 부트스트랩

- Firebase Core 초기화 후 기존 인증 사용자가 있으면 그대로 재사용한다.
- 현재 인증 사용자가 없을 때만 `signInAnonymously()`를 호출한다.
- 인증 준비가 완료될 때까지 기존 앱 진입을 지연하고 실패는 공용 재시도 화면으로 전달한다.
- Auth UID는 UI와 로그에 노출하지 않으며 Player binding은 다음 작업으로 분리한다.
- `firebase_auth` 의존성과 플랫폼 플러그인 등록을 반영했다.
- `flutter analyze`와 전체 `flutter test` 229개를 통과했다.
- Android 실기기에서 최초 익명 로그인, 기존 앱 진입, 기존 캐릭터 데이터 유지와 재실행 시 인증 재사용을 확인했다.
- Firebase Console에서 익명 사용자 생성과 재실행 시 불필요한 사용자 추가가 없는 것을 확인했다.

### Firebase Core 앱 부트스트랩 자동 검증

- 앱 진입 전에 플랫폼별 Firebase 옵션으로 `Firebase.initializeApp()`을 실행한다.
- 초기화 중에는 로딩 화면을 표시하고 기존 Drift 및 Fake 파티 런타임 생성을 지연한다.
- 초기화 실패 시 오류 상세를 노출하지 않고 재시도 가능한 안내 화면을 표시한다.
- 테스트에서는 초기화 함수를 주입해 Firebase 없이 대기·성공·실패·재시도 경계를 검증한다.
- `flutter analyze`와 전체 `flutter test` 225개를 통과했다.
- Android 실기기에서 Firebase 초기화 후 기존 내 계정과 저장된 캐릭터 데이터가 정상 표시되는 것을 확인했다.
- 실패·재시도 흐름은 주입형 위젯 테스트로 검증했다.

### Firebase 프로젝트 초기 연결과 구조 검토

- Firebase 프로젝트 `lost-party`와 FlutterFire 플랫폼 설정을 생성했다.
- Android 패키지 `com.example.lost_party`와 Firebase Android 앱 등록 정보가 일치한다.
- Android Google Services Plugin과 생성된 Firebase 옵션을 저장소에 반영했다.
- 생성된 옵션이 컴파일될 수 있도록 `firebase_core`까지만 초기 연결 의존성에 포함한다.
- Firebase 앱 초기화와 Anonymous Auth는 구현·검증 완료했다.
- Player binding과 최소 Security Rules는 구현·배포·검증 완료했다.
- 게임 계정·Character 및 파티 Firestore Repository와 해당 Rules는 아직 미구현이며 다음 단계부터 순서대로 구현한다.
- `AuthUid`와 LOSTPARTY 영속 `PlayerId`를 분리하는 방향 및 기존 코드 영향 범위를 별도 문서로 검토했다.

### 아이템 레벨 기반 레이드 선택과 모집 수정 기반

구현 브랜치: `codex/raid-eligibility-defaults` (main 병합 및 실기기 검증 완료)

- 저장 세팅 아이템 레벨을 기준으로 입장 가능한 레이드·난이도만 표시한다.
- 입장 가능한 최고 난이도를 기본 선택하고 캐릭터·역할 변경 시 선택 유효성을 다시 검사한다.
- 모집 수정 결과 입장 불가능해진 참가자를 저장 전에 표시하며 자동 퇴장시키지 않는다.
- 수동 참가자 알림 UI는 Firebase 미연결 상태를 명확히 안내한다.

### 전투력 표시와 자동 모집 제목

구현 브랜치: `codex/combat-power-auto-title` (main 병합 및 자동 검증 완료)

- 모집 생성, 지원 및 파티 내 캐릭터 변경 후보가 공용 세팅 표시 모델을 사용한다.
- 아이템 레벨과 전투력은 소수점을 버리고 천 단위 쉼표로 표시한다.
- 빈 값과 `0`인 최소 전투력은 제한 없음으로 처리한다.
- 제목을 입력하지 않은 경우 난이도 별칭, 숙련도와 최소 전투력으로 자동 제목을 만든다.
- 수동 제목을 조건 변경으로 덮어쓰지 않으며 빈 제목은 저장 시 자동 제목을 적용한다.

### 전체 모집 수정과 공통 입력 UX

구현 브랜치: `codex/full-recruitment-edit` (main 병합 및 Android 실기기 검증 완료)

- 생성·수정 공용 Draft와 폼을 사용해 제목, 레이드, 난이도, 숙련도, 최소 전투력과 가입 승인 방식을 수정한다.
- 제목, 모집 Metadata와 가입 승인 정책을 revision 기반 통합 명령으로 저장한다.
- 파티장, 확정 파티원과 승인 대기 신청자에게 미치는 영향을 저장 전에 표시한다.
- 입장 불가능한 참가자를 자동 퇴장시키거나 승인 대기 신청을 자동 종료하지 않는다.
- 수정 중 뒤로가기 시 미저장 변경 폐기 여부를 확인한다.
- 단일행 텍스트·숫자 입력은 값이 있을 때 우측 전체 지우기(X) 동작을 제공한다.

## 현재 중단 및 보류 상태

### 최근 레이드 조건 기억

- 기존 후속 작업 후보였으나 새 대형 설계가 확정될 때까지 보류한다.
- 현재 지원 흐름은 이미 정해진 모집에 신청하는 구조이므로 `지원 화면에서 레이드 조건 재사용` 요구는 적용 대상이 불명확하다.
- 재개 시 모집 생성 전용인지, 목록 필터까지 포함하는지, 디바이스 공통인지 계정별인지 먼저 결정한다.
- 별도 결정 전에는 로컬 저장 모델이나 UI를 구현하지 않는다.

### Firebase 기반 다중 사용자 전환의 과거 보류 상태

- Firebase 프로젝트와 플랫폼 연결 및 주요 제품 흐름의 1차 확정 전까지 적용했던 전역 구현 보류 정책은 종료됐다.
- 이후에는 각 작업 브랜치가 다루는 데이터 계약, 권한, 실패 처리와 테스트 경계를 먼저 확정한 뒤 해당 범위의 앱 및 서버 코드를 함께 구현할 수 있다.
- Authentication, Firestore, Cloud Functions, FCM, Security Rules와 App Check는 하나의 큰 전환을 구성하므로 단계별 경계가 필요하다.
- 실제 다중 사용자 동기화, 서버 트랜잭션과 알림 전달은 로컬 UI 구현 완료와 별개의 검증 영역으로 취급한다.

## Firebase 단계적 구현에서 정할 항목

1. `AuthUid -> PlayerId -> GameAccountId -> CharacterId`의 Firestore 데이터 계약
2. 서버 CharacterId 발급, 소유 검증 및 캐릭터명 변경 추적
3. 파티방, 주차별 회차, 완료·미완료 종료 Snapshot과 다음 회차 준비 구성의 저장 구조
4. 모집 수동 활성화와 빈자리 자동 노출 판정 계약
5. 가입 승인권 부여·회수, 추방, 책임자 승계와 구성 점검의 Transaction 범위
6. 완료·미완료 종료·취소·해산·구성 변경 사용자 이벤트와 28일 TTL
7. 전체 및 방별 알림 설정, FCM 전달과 토큰 수명
8. 로컬 레이드 히스토리, 숨김 및 캐릭터별 0~5개 표시의 Drift 계약
9. 기존 Drift 데이터와 로컬 Fake 데이터의 마이그레이션 또는 폐기 정책
10. Firebase Core 초기화 실패와 Anonymous Auth 준비 중의 앱 진입 정책
11. Emulator Suite, Security Rules, Functions와 다중 사용자 동시성 테스트 경계
12. 각 계약을 독립적으로 검증·병합할 구현 브랜치 단위와 롤백 기준

## 기능 단위 설계·구현 착수 조건

- 통합 제품 흐름의 포함·제외 범위가 문서로 합의된다.
- 핵심 엔티티의 소유권과 단일 기준 저장소가 정의된다.
- 주요 명령의 권한, 검증 주체, 원자성 및 실패 처리가 정의된다.
- 기존 코드에서 재사용·수정·제거할 영역이 구분된다.
- 데이터 마이그레이션과 호환 정책이 정해진다.
- 해당 구현 브랜치가 독립적으로 검증·병합 가능한 크기로 산정된다.
- 위 조건을 만족한 기능은 구현할 수 있으며, 아직 계약이 없는 후속 기능만 보류한다.

## 권장 구현 순서

1. Firebase Core 초기화와 앱 부트스트랩 실패·준비 상태
2. Anonymous Auth와 `AuthUid -> PlayerId` binding
3. 서버 `GameAccountId`·`CharacterId` 계약과 소유 검증
4. Firestore 파티 읽기 모델과 Repository 전환 경계
5. 생성·수정·신청·철회·승인·즉시 가입 Callable Function
6. 참가 캐릭터 변경·탈퇴·추방·승인권·책임자 승계
7. 회차 완료·완료 취소·반복 파티·주차 전환과 Snapshot
8. 사용자 이벤트·로컬 히스토리·FCM·TTL
9. Security Rules·Emulator 동시성 테스트·App Check 강화

## 유지되는 제품 규칙

- 레이드 카탈로그는 `assets/raid_catalog/raid_catalog.v1.json`을 기준으로 한다.
- 참가와 충돌 규칙은 `../product/PARTY_PARTICIPATION_RULES.md`를 기준으로 하되 새 설계에서 변경 여부를 명시한다.
- 최소 전투력의 빈 값과 `0`은 제한 없음으로 처리한다.
- 표시 숫자는 소수점을 버리고 천 단위 쉼표를 적용한다.
- 모집 제목을 입력하지 않은 경우에만 자동 제목을 사용한다.
- 단일행 텍스트·숫자 입력은 값이 있을 때 전체 지우기(X)를 제공하고 읽기 전용·선택형 필드에는 적용하지 않는다.
- 사용자 동의가 필요한 설정은 자동 저장하지 않는다.

## 작업 및 검증 원칙

- 새로운 작업 영역은 최신 `main`에서 `codex/` 기능 브랜치로 분리한다.
- 관련 자동 테스트와 사용자 실기기 검증이 통과한 뒤 기능 브랜치를 `main`에 병합하고 `origin/main`에 푸시한다.
- 실기기에서 확인 가능한 흐름을 대신하기 위한 무의미한 전체 `flutter test` 반복은 하지 않는다.
- 개발 중에는 변경 범위에 맞는 표적 테스트만 실행하고, 사용자가 필요 시 터미널의 전체 테스트 오류 로그를 제공한다.
- 문서의 현재 상태와 실제 브랜치·코드 상태를 함께 갱신한다.

## 참고 문서

- `AI_CONTEXT.md`: 프로젝트 구조와 현재 개발 기준
- `../product/PARTY_PARTICIPATION_RULES.md`: 참가 및 충돌 규칙
- `../architecture/FIREBASE_PARTY_PRODUCT_FLOW.md`: Firebase 파티 제품 흐름 통합 기준
- `../architecture/BACKEND_PARTY_ARCHITECTURE.md`: 기존 Firebase 전환 설계 참고안
- `../architecture/PLAYER_FIREBASE_MIGRATION_REVIEW.md`: Player 식별자와 Firebase 전환 영향 검토
- `../integrations/FIREBASE_INITIAL_SETUP_REVIEW.md`: Firebase 프로젝트 및 플랫폼 초기 연결 확인
- `../product/DETAIL_IMPROVEMENTS.md`: 재설계 이후 다시 평가할 세부 개선 후보
- `DEV_LOG.md`: 완료 작업 이력
