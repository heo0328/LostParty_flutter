# NEXT WORK

## 기준 상태

- 통합 기준 브랜치: `main`
- 기준 상태: Firebase 초기 연결 설정, Player 식별자 검토 및 Firebase 파티 제품 흐름 1차 통합 기준이 작성된 문서 브랜치
- 작업 트리는 깨끗하며 `main`과 `origin/main`이 일치한다.
- 현재 진행 중인 기능 구현은 없다.
- Firebase 프로젝트 및 플랫폼 연결 설정은 완료됐으며 제품 흐름의 주요 정책은 `../architecture/FIREBASE_PARTY_PRODUCT_FLOW.md`에 통합했다.
- 현재는 기존 문서의 충돌을 정리하고 데이터 계약·서버 명령·Security Rules·테스트 경계를 산정하는 문서 단계다.
- 기술 설계와 첫 구현 작업 범위가 승인되기 전에는 Firebase 기능 코드를 구현하지 않는다.

## 최근 완료 작업

### Firebase 프로젝트 초기 연결과 구조 검토

- Firebase 프로젝트 `lost-party`와 FlutterFire 플랫폼 설정을 생성했다.
- Android 패키지 `com.example.lost_party`와 Firebase Android 앱 등록 정보가 일치한다.
- Android Google Services Plugin과 생성된 Firebase 옵션을 저장소에 반영했다.
- 생성된 옵션이 컴파일될 수 있도록 `firebase_core`까지만 초기 연결 의존성에 포함한다.
- Firebase 앱 초기화, Anonymous Auth 실행, Player binding, Firestore Repository와 Security Rules는 아직 구현하지 않는다.
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

### Firebase 기반 다중 사용자 전환

- Firebase 프로젝트와 플랫폼 연결은 완료했고 주요 제품 흐름은 1차 확정했지만 기술 설계가 확정되기 전에는 앱 초기화와 데이터 기능을 구현하지 않는다.
- Authentication, Firestore, Cloud Functions, FCM, Security Rules와 App Check는 하나의 큰 전환을 구성하므로 단계별 경계가 필요하다.
- 실제 다중 사용자 동기화, 서버 트랜잭션과 알림 전달은 로컬 UI 구현 완료와 별개의 검증 영역으로 취급한다.

## 다음 기술 설계에서 정할 항목

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
12. 기술 설계를 독립적으로 검증·병합할 첫 구현 브랜치 단위와 롤백 기준

## 기술 설계 단계 완료 조건

- 통합 제품 흐름의 포함·제외 범위가 문서로 합의된다.
- 핵심 엔티티의 소유권과 단일 기준 저장소가 정의된다.
- 주요 명령의 권한, 검증 주체, 원자성 및 실패 처리가 정의된다.
- 기존 코드에서 재사용·수정·제거할 영역이 구분된다.
- 데이터 마이그레이션과 호환 정책이 정해진다.
- 첫 구현 브랜치가 독립적으로 검증·병합 가능한 크기로 산정된다.
- 설계 승인 전에는 구현을 시작하지 않는다.

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
