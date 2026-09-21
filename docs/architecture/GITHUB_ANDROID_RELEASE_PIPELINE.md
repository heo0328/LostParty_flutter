# GitHub Android APK Release Pipeline 계약

## 1. 목적

검증된 LOSTPARTY Android 버전을 동일한 앱 ID와 서명으로 빌드하고, Git 태그에 대응하는 GitHub Release 페이지에서 APK를 직접 내려받을 수 있게 한다.

이 계약은 Google Play 배포가 아닌 GitHub Releases를 통한 APK 직접 배포를 우선한다. 현재 수동으로 만든 release APK는 사용자 실기기에서 정상 실행이 확인됐다.

## 2. 확정값

- 정식 Android application ID와 namespace: `kr.co.heowork0921.lostparty`
- Firebase 프로젝트: `lost-party`
- 기준 Flutter: `3.41.6` stable
- 기준 Dart: `3.11.4`
- CI Java: 21, 앱 JVM target: 17
- 버전 원장: `pubspec.yaml`의 `version: <name>+<code>`
- 정식 태그: `v<name>` 형식. 예: `version: 1.0.0+1`은 `v1.0.0`
- 배포 파일: 단일 범용 release APK와 SHA-256 checksum

정식 ID는 릴리즈 후 변경하지 않는다. 변경하면 Android가 다른 앱으로 취급하고 기존 설치본 위에 업데이트할 수 없다.

## 3. 착수 시 상태와 선행 문제

- 착수 시 Android ID는 임시값 `com.example.lost_party`였다.
- 착수 시 `android/app/google-services.json`과 `lib/firebase_options.dart`의 Android Firebase 앱도 임시 ID에 연결돼 있었다.
- 현재 `release` buildType은 debug signingConfig를 사용한다.
- 로컬 `android/key.properties`와 정식 keystore는 저장소에 없다.
- Git tag와 GitHub Release는 아직 없다.

수동 release APK의 실행 성공은 앱 런타임 확인 근거지만, CI 배포 준비 완료를 뜻하지 않는다. GitHub hosted runner의 임시 debug key로 매번 서명하면 다음 APK를 기존 설치본 위에 업데이트하지 못할 수 있으므로 정식 배포에는 하나의 영구 release key를 사용한다.

2026-09-21에 사용자가 Firebase Android 앱 `kr.co.heowork0921.lostparty`를 추가하고 새 설정 파일을 전달했다. Gradle namespace/applicationId, MainActivity package·경로, `google-services.json`, `firebase.json`, Android `FirebaseOptions.appId`를 새 등록값으로 일치시켰다. JSON·정적 분석과 `processDebugGoogleServices`는 통과했으며 APK 빌드·실기기 Firebase 연결은 사용자 확인 전이다.

## 4. 작업 단계

### A. 정식 앱 ID와 Firebase Android 앱 전환

1. Firebase 프로젝트 `lost-party`에 Android 앱 `kr.co.heowork0921.lostparty`를 새로 등록한다.
2. 새 Android 앱의 `google-services.json`과 FlutterFire Android option을 확보한다.
3. 아래 로컬 항목을 같은 ID로 변경한다.
   - `android/app/build.gradle.kts`의 `namespace`, `applicationId`
   - `MainActivity.kt`의 package와 디렉터리
   - `android/app/google-services.json`
   - `lib/firebase_options.dart`의 Android appId·storage/project 연결
4. Firebase 초기화와 익명 인증·Firestore 접근을 새 패키지 APK에서 확인한다.

기존 `com.example.lost_party` Firebase Android 앱 등록은 새 앱의 실기기 확인 전 삭제하지 않는다. Firestore 데이터·Rules·Indexes를 초기화하거나 배포하지 않는다. 앱 ID 변경본은 기존 테스트 앱과 별도 앱으로 설치되며 로컬 익명 인증·Secure Storage·Drift 상태는 자동 승계되지 않는다.

### B. 영구 release 서명

1. 사용자가 장기 보관할 release keystore를 로컬에서 한 번 생성하고 별도 백업한다.
2. keystore와 비밀번호를 Git에 커밋하지 않는다.
3. 로컬 빌드는 ignored `android/key.properties`로, CI는 GitHub Repository Secrets로 같은 키를 복원한다.
4. Secret 이름은 다음으로 고정한다.
   - `ANDROID_KEYSTORE_BASE64`
   - `ANDROID_KEYSTORE_PASSWORD`
   - `ANDROID_KEY_ALIAS`
   - `ANDROID_KEY_PASSWORD`
5. CI 종료 시 runner 임시 keystore는 작업 공간과 함께 폐기된다.

서명키를 잃으면 기존 GitHub APK 설치본에 업데이트할 수 없다. 비밀번호와 원본 keystore의 오프라인 백업은 파이프라인 완료 조건이다.

### C. GitHub Actions 빌드와 Release 게시

하나의 workflow에서 두 진입점을 분리한다.

- `workflow_dispatch`: release APK를 빌드·검증하고 Actions artifact로만 보관한다. Git tag나 GitHub Release를 만들지 않는다.
- `push.tags: v*`: 태그가 검증된 `main` 이력에 포함되고 `pubspec.yaml` 버전과 일치할 때만 같은 APK를 빌드해 GitHub Release에 게시한다.

작업 순서는 다음과 같다.

1. repository checkout
2. Java 21과 Flutter 3.41.6 고정 설치
3. `flutter pub get`
4. Secrets로 임시 keystore와 `key.properties` 구성
5. 태그 실행이면 `v<pubspec versionName>` 일치 및 태그 커밋의 `main` 포함 여부 검사
6. `flutter build apk --release`
7. APK 서명 유효성, package ID, versionName/versionCode 검사
8. `lostparty-<tag>-android.apk`로 이름 변경 및 `.sha256` 생성
9. 수동 실행은 짧은 보존 기간의 workflow artifact 업로드
10. 태그 실행은 `contents: write`의 기본 `GITHUB_TOKEN`으로 GitHub Release 생성 및 두 파일 첨부

workflow가 tag를 자동 생성하거나 브랜치를 병합하지 않는다. release 안정화가 끝나 `main`과 `dev`를 최종 release 시점으로 맞춘 뒤 사람이 해당 커밋에 태그를 생성·푸시한다.

## 5. 회귀 보호와 실패 처리

- 앱 ID·Firebase Android config·서명 변경 외 앱 기능, Firestore Rules, Indexes와 서버 데이터는 변경하지 않는다.
- Secret이 없거나 package/version/signature 검사가 실패하면 Release를 만들지 않는다.
- 같은 태그의 Release 또는 asset이 이미 있으면 덮어쓰지 않고 실패시킨다.
- 빌드 실패 뒤 태그를 다른 커밋으로 강제 이동하지 않는다. 원인을 수정하고 새 버전 태그를 사용하거나, 아직 공개 전인 잘못된 태그의 처리 여부를 사용자가 결정한다.
- Actions에서 실기기 조작을 하지 않는다. 수동 artifact 또는 GitHub Release APK의 설치·실행·Firebase 연결은 사용자가 확인한다.
- 기존 Rules Emulator workflow와 release workflow를 결합하지 않는다. 릴리즈 직전 필요한 검증은 release 브랜치에서 끝내고 APK workflow는 재현 가능한 빌드·서명·게시만 책임진다.

## 6. 완료 조건

- 정식 ID의 APK가 실기기에 설치되고 Firebase Auth·Firestore 기본 진입이 정상이다.
- 같은 release key로 만든 후속 build가 기존 정식 ID 앱 위에 업데이트 설치된다.
- 수동 workflow가 APK artifact와 checksum을 만든다.
- 테스트 태그가 아닌 실제 승인 태그에서 GitHub Release와 직접 다운로드 가능한 APK가 생성된다.
- APK의 package ID, version, 서명 인증서와 checksum이 기록된다.
- keystore·비밀번호·`key.properties`가 Git 이력과 Actions 로그에 노출되지 않는다.

## 7. 제외 범위

- Google Play Console, Play App Signing과 AAB 게시
- iOS·Windows·웹 배포
- 자동 버전 증가, 자동 태그 생성, 자동 `dev`/`main` 병합
- Firebase Rules·Indexes·Functions·Hosting 배포
- 기존 임시 패키지 앱의 로컬 데이터 마이그레이션
