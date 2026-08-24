# Firebase 초기 연결 확인

## 1. 문서 목적

이 문서는 2026-08-24에 사용자가 수행한 Firebase 프로젝트 생성 및 FlutterFire 연결 작업을 현재 LOSTPARTY 저장소와 대조한 결과를 기록한다.

이 문서의 범위는 Firebase 초기 연결 상태 확인이다. 최초 작성 이후 생성 옵션의 컴파일 기반인 `firebase_core` 의존성까지 추가됐으며, 앱 초기화, Anonymous Auth 실행, Firestore 데이터 모델 확정 및 기존 Repository 교체는 포함하지 않는다.

Player와 Firebase의 장기 구조 방향은 `../architecture/PLAYER_FIREBASE_MIGRATION_REVIEW.md`를 기준으로 별도 검토한다.

## 2. 확인 기준

확인 결과는 다음 세 종류로 구분한다.

- **코드 확인**: 현재 저장소의 파일과 설정에서 직접 확인한 사실
- **사용자 완료 보고**: Firebase Console 또는 로컬 CLI 실행 결과로 사용자가 완료했다고 전달한 사실
- **미적용/미검증**: 아직 코드에 적용되지 않았거나 현재 저장소만으로 확인할 수 없는 항목

첨부된 초기 설정 정리는 강제 구현 지시가 아니라 사용자가 수행한 외부 설정 작업의 근거로 사용했다.

## 3. 현재 Firebase 준비 상태

| 항목 | 상태 | 확인 내용 |
|---|---|---|
| Firebase 프로젝트 | 사용자 완료 보고 | 프로젝트 ID `lost-party` 생성 및 CLI 인식 완료 |
| FlutterFire CLI 연결 | 코드 확인 | `firebase.json`과 `lib/firebase_options.dart` 생성 확인 |
| Android 앱 등록 | 코드 확인 | Android 패키지명 `com.example.lost_party`가 `google-services.json` 및 Gradle 설정과 일치 |
| Android Google Services Plugin | 코드 확인 | 루트 Android 설정에 플러그인 버전 선언, 앱 모듈에 플러그인 적용 확인 |
| iOS 설정값 | 코드 확인 | `firebase_options.dart`에 iOS 설정 존재 |
| macOS 설정값 | 코드 확인 | `firebase_options.dart`에 macOS 설정 존재 |
| Web 설정값 | 코드 확인 | `firebase_options.dart`에 Web 설정 존재 |
| Windows 설정값 | 코드 확인 | `firebase_options.dart`에 Windows 설정 존재 |
| Linux 설정값 | 미설정 | 생성 파일에서 Linux는 구성되지 않은 플랫폼으로 처리됨 |
| `firebase_core` 패키지 | 코드 확인 | 생성된 `firebase_options.dart`의 컴파일 기반으로 `pubspec.yaml`에 반영됨 |
| `firebase_auth` 패키지 | 미적용 | `pubspec.yaml`에 없음 |
| `cloud_firestore` 패키지 | 미적용 | `pubspec.yaml`에 없음 |
| Firebase 앱 초기화 | 미적용 | `main.dart`에서 `Firebase.initializeApp`을 호출하지 않음 |
| Anonymous Auth 제공자 | 사용자 완료 보고 | Anonymous 인증 사용을 위한 Console 설정 완료로 전달받음 |
| 앱의 Anonymous 로그인 | 미적용 | 로그인 호출 및 인증 세션 구현 없음 |
| Firestore 데이터베이스 | 사용자 완료 보고 | Standard, `(default)`, Seoul, Production mode로 생성 완료 |
| Firestore 컬렉션 | 미생성 | 현재 의도적으로 컬렉션을 수동 생성하지 않음 |
| Firestore Security Rules | 미검증 | Console의 Production mode 외 실제 Rules 내용은 저장소에 없음 |
| Firebase Emulator 설정 | 미적용 | 관련 설정 및 테스트 없음 |

## 4. 저장소에서 확인된 변경

### 4.1 새로 생성된 파일

```text
android/app/google-services.json
firebase.json
lib/firebase_options.dart
```

### 4.2 수정된 파일

```text
android/settings.gradle.kts
android/app/build.gradle.kts
```

`android/settings.gradle.kts`에는 Google Services Gradle Plugin 선언이 추가됐다.

```text
com.google.gms.google-services 4.3.15
```

`android/app/build.gradle.kts`에는 앱 모듈의 Google Services Plugin 적용이 추가됐다.

### 4.3 Android 식별자 일치

다음 세 위치의 Android 식별자가 일치한다.

```text
android/app/build.gradle.kts applicationId
android/app/build.gradle.kts namespace
android/app/google-services.json package_name

= com.example.lost_party
```

따라서 현재 Android 앱과 Firebase Android 등록 정보 사이의 패키지명 불일치는 발견되지 않았다.

### 4.4 등록된 Dart 플랫폼 설정

`lib/firebase_options.dart`와 `firebase.json`을 기준으로 다음 플랫폼의 Dart Firebase 설정이 생성됐다.

- Android
- iOS
- macOS
- Web
- Windows

현재 우선 테스트 대상은 Android APK다. 다른 플랫폼은 설정값이 생성됐다는 사실만 확인했으며, 각 플랫폼 빌드와 Firebase 초기화 성공은 아직 검증하지 않았다.

## 5. 현재 앱 초기화 구조와의 관계

현재 `main.dart`는 동기식으로 `MyApp`을 실행한다.

```text
main
  -> runApp(MyApp)
  -> AccountDatabase 생성
  -> createAppRouter
```

Firebase 초기화는 아직 이 흐름에 들어가지 않았다. `lib/firebase_options.dart`의 안내 코드 역시 주석 예시일 뿐 실제 실행 코드가 아니다.

향후 Firebase Core를 적용할 때는 개념적으로 다음 초기화 경계가 필요하다.

```text
WidgetsFlutterBinding.ensureInitialized
  -> Firebase.initializeApp
  -> 앱 의존성 조립
  -> runApp
```

단, Anonymous Auth와 Player binding까지 같은 작업에서 한 번에 구현할지는 별도 작업 범위로 결정한다.

관련 파일:

- `lib/main.dart`
- `lib/app/router/app_router.dart`
- `lib/firebase_options.dart`

## 6. 현재 패키지 상태

현재 `pubspec.yaml`에는 `firebase_core`가 있고 다음 Firebase 기능 패키지는 아직 없다.

```text
firebase_auth
cloud_firestore
```

따라서 생성된 `lib/firebase_options.dart`는 현재 의존성으로 컴파일할 수 있지만, Firebase 앱 초기화와 Auth·Firestore 기능은 아직 적용되지 않았다. CLI 설정 생성과 앱 런타임 적용이 서로 다른 단계에 머물러 있다는 의미다.

다음 패키지의 실제 추가는 각각의 구현 작업이 승인될 때 진행한다.

- Firebase 연결 및 초기화: 반영된 `firebase_core`를 사용해 앱 초기화 구현
- Anonymous Auth 세션: `firebase_auth`
- Firestore 읽기/쓰기: `cloud_firestore`

현재 문서 작업에서는 패키지를 추가하지 않는다.

## 7. Authentication 확인 결과

사용자 완료 보고 기준으로 Firebase Authentication에서 Anonymous 인증 사용 준비가 완료됐다.

현재 저장소에는 다음 구현이 아직 없다.

- 익명 로그인 호출
- 인증 상태 구독
- Auth UID를 노출하는 인증 세션
- Auth UID에서 Player ID를 조회하거나 생성하는 binding
- 인증 실패 및 재시도 처리
- 인증 준비 중 앱 화면 정책

현재 파티 흐름의 `FakeUserSession('local-user')`는 Firebase Auth와 연결되지 않은 로컬 테스트용 세션이다.

Auth UID와 Player ID는 동일시하지 않는다. 권장 경계는 다음과 같다.

```text
Firebase Auth UID
= 현재 인증 주체

Player ID
= LOSTPARTY 내부의 영속 사용자 식별자
```

복구키 기능은 현재 범위에서 구현하지 않지만, 이후 새 Auth UID를 기존 Player ID에 연결할 수 있는 구조를 막지 않아야 한다.

관련 검토 문서:

- `docs/architecture/PLAYER_FIREBASE_MIGRATION_REVIEW.md`

## 8. Firestore 확인 결과

사용자 완료 보고 기준으로 다음 데이터베이스 설정이 완료됐다.

```text
Edition: Standard
Database ID: (default)
Region: asia-northeast3 (Seoul)
Security mode: Production mode
```

현재 저장소에는 Firestore Rules, Indexes 또는 Emulator 설정 파일이 없다. 따라서 다음 항목은 로컬 코드만으로 검증하지 않았다.

- 실제 배포된 Security Rules 내용
- 현재 인증 사용자에게 허용되는 읽기/쓰기 범위
- 복합 인덱스
- TTL 또는 백업 정책
- App Check 적용 여부

Firestore 컬렉션을 아직 수동 생성하지 않은 것은 현재 단계에 적합하다. Player, Character, Party, Application 및 History의 소유 관계와 식별자를 확정한 뒤 컬렉션 구조를 결정해야 한다.

## 9. 기존 구조에서 Firebase를 적용할 수 있는 경계

### 그대로 유지 가능한 영역

- Account와 Recruitment의 feature 경계
- Domain/Data/Presentation 분리
- Repository interface를 통한 저장 구현 격리
- `RecruitmentAggregate`와 파티 상태 머신의 핵심 규칙
- 승인 정책과 파티 구성 정책
- 주간 초기화 및 참가 충돌 정책
- 로컬 Drift 캐릭터 캐시와 개인 표시 설정
- In-memory Repository 및 Fake Session 기반 자동화 테스트

### 추가 또는 변경이 필요한 영역

- Firebase Core 초기화
- Firebase Auth를 감싸는 인증 세션
- Auth UID와 Player ID binding
- 서버에서 유지되는 Character ID
- Firestore 실시간 읽기 Repository
- Callable Function 또는 동등한 서버 명령 경계
- Firestore Transaction과 Security Rules
- 파티 완료 상태 및 히스토리 조회 계약
- Current State와 Snapshot의 명시적 분리

기존 Local Repository를 삭제하거나 Firebase 구현으로 즉시 대체하지 않는다. 먼저 같은 Domain 계약 아래 Fake/Local/Firebase 구현의 책임을 분리한다.

## 10. 권장 데이터 분류

### Current State

서버 원본으로 유지할 후보:

- Player와 Auth binding
- 현재 검증된 Character 소유 관계 및 공유 프로필
- 파티 모집글과 모집 상태
- 파티장/공대장
- 현재 파티원
- 지원 및 승인 상태
- 파티 유지 및 진행 상태
- 클리어 상태와 주간 완료 상태

### Snapshot

행동 시점에 고정할 후보:

- 지원 당시 Character 정보와 역할 세팅
- 가입 승인 당시 표시 및 판정 정보
- 완료 당시 파티원과 Character 구성
- 모집 생성 당시 레이드 카탈로그 버전

### Local Preference

로컬에 유지할 후보:

- 필터와 정렬
- 현재 선택 탭
- 캐릭터 카드 표시 여부와 순서
- 선호 역할
- 화면의 접힘/펼침 상태

대표 캐릭터는 Player 식별자가 아닌 표시용 정보다. 대표 캐릭터 설정을 여러 기기에서 동기화할지는 별도 제품 결정이 필요하다.

## 11. 다음 구현 단계 권장안

초기 연결 이후의 작업을 다음과 같이 작은 단위로 분리한다.

### 단계 1. Firebase Core 앱 초기화

범위:

- 반영된 `firebase_core`를 사용한 초기화 경계 구현
- Android에서 `Firebase.initializeApp` 실행
- 기존 `MyApp` 및 AccountDatabase 수명 유지
- 초기화 실패 처리의 최소 정책 결정

예상 영향 파일:

- `pubspec.yaml`
- `pubspec.lock`
- `lib/main.dart`
- 앱 초기화 관련 테스트

검증:

- `flutter analyze`
- 관련 앱 시작/widget 테스트
- Android debug APK 빌드 또는 실기기 시작 확인

### 단계 2. Anonymous Auth 연결

범위:

- `firebase_auth` 추가
- 로그인 UI 없이 익명 인증
- 인증 준비, 성공 및 실패 상태 정의
- Auth UID를 Domain 외부 인증 주체로 노출

예상 영향 파일:

- `pubspec.yaml`
- 인증 session/service 신규 파일
- 앱 초기화 또는 composition root
- 인증 테스트

검증:

- Fake 인증 단위 테스트
- Emulator 또는 테스트 Firebase 프로젝트에서 익명 사용자 생성 확인
- 재실행 시 같은 설치본의 인증 유지 확인

### 단계 3. Player binding 계약 확정

범위:

- `PlayerId` Domain 정의
- `AuthUid -> PlayerId` 조회/생성 계약
- 기존 파티 `userId` 필드의 의미를 Player ID로 확정
- 복구 기능은 제외하되 재연결 가능한 구조 유지

예상 영향 파일:

- Player Domain 및 Repository 신규 파일
- `recruitment_runtime.dart`
- 파티 entity/state/service 및 관련 테스트
- `../architecture/PLAYER_FIREBASE_MIGRATION_REVIEW.md`
- 확정 후 `../architecture/BACKEND_PARTY_ARCHITECTURE.md`

검증:

- 한 Auth UID가 하나의 Player에 연결되는 테스트
- 다른 Auth UID를 같은 Player에 재연결할 수 있는 데이터 구조 검토
- 파티 중복 참가 규칙이 Player 기준으로 유지되는 테스트

### 단계 4. Firestore 읽기와 서버 데이터 모델

범위:

- `cloud_firestore` 추가
- Player, Character, Recruitment 및 Snapshot 구조 확정
- 실시간 목록/상세 조회 계약
- Security Rules 및 Emulator 설정

검증:

- Rules 단위 테스트
- 인증/비인증 읽기 권한 테스트
- 두 사용자 간 실시간 상태 반영 테스트
- 인덱스와 쿼리 가능성 검토

### 단계 5. 파티 명령의 서버 전환

범위:

- 모집 생성, 지원, 승인, 캐릭터 변경, 완료를 순차 이전
- 서버 Transaction으로 정원과 상태 전이 보장
- 로컬 Fake 상태 머신과 서버 규칙의 동등성 유지

검증:

- 동시 신청과 마지막 자리 승인 경쟁
- 중복 신청과 중복 투표
- 권한 없는 상태 변경
- 완료와 주간 귀속의 원자적 반영

## 12. 구현 전 결정이 필요한 사항

- Firebase Core 초기화 실패 시 앱 전체를 막을지 로컬 Account 화면을 허용할지
- Anonymous Auth 완료 전 보여줄 화면 또는 로딩 정책
- Player 최초 생성 시 필요한 최소 프로필 필드
- Player 표시명과 검색용 ID 제공 여부
- 서버 Character ID 생성 및 동일 캐릭터 판정 기준
- 대표 캐릭터 설정의 서버 동기화 여부
- 파티 수명주기와 완료 상태
- 지원 Snapshot에 포함할 최소 필드와 서버 검증 수준
- 다중 Player 필터의 대상 선택 방식과 최대 인원
- Firestore 읽기 권한 및 공개/그룹 전용 범위
- 개발 단계에서 Firebase Emulator를 필수로 사용할지
- 테스트 Firebase 프로젝트와 운영 프로젝트를 분리할 시점

## 13. 현재 결론

Firebase 프로젝트와 FlutterFire 설정 파일 생성, Android 앱 등록 및 Gradle Plugin 연결은 현재 저장소에서 확인됐다. Android 패키지명도 Firebase 등록 정보와 일치한다.

그러나 앱은 아직 Firebase를 실행하지 않는다. Firebase 패키지, Core 초기화, Anonymous 로그인, Player binding, Firestore Repository 및 Security Rules는 모두 후속 단계다.

따라서 현재 상태는 다음과 같이 정의한다.

```text
Firebase 프로젝트 및 플랫폼 설정 생성 완료
Android 네이티브 연결 설정 완료
Firebase Core 의존성 반영 완료, 앱 초기화는 미적용
Auth 및 Firestore 애플리케이션 기능은 미구현
```

다음 코드 작업은 Firebase Core 초기화만 독립 작업 단위로 검토한 뒤 진행하는 것이 적절하다.
