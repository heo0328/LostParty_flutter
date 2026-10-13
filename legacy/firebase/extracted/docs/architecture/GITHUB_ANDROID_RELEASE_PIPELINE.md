# 기존 서비스 발췌 — docs/architecture/GITHUB_ANDROID_RELEASE_PIPELINE.md

원본 문서: docs/architecture/GITHUB_ANDROID_RELEASE_PIPELINE.md ([현재 문서](../../../../../docs/architecture/GITHUB_ANDROID_RELEASE_PIPELINE.md)). 분리일: 2026-10-13.
원본 전체 SHA256: 3ef9a69767b933bfd60a2e7a81e9d2a5760ccf17586594336223368707b8f829.
아래는 기존 Firebase 환경의 원문이다. 신규 서버의 실행 지시/배포 승인으로 사용하지 않는다. 행 범위는 분리 직전이며 링크 위치만 조정한다.

<a id="source-0001"></a>

## 발췌 1: ## 1. 목적

출처: docs/architecture/GITHUB_ANDROID_RELEASE_PIPELINE.md · 원본 7~7행 · 원문 절: ## 1. 목적.

이 계약은 Google Play 배포가 아닌 GitHub Releases를 통한 APK 직접 배포를 우선한다. Actions `35592769624`에서 영구 키로 서명한 artifact APK는 사용자 실기기 설치·실행과 Firebase 연결이 정상임을 확인했다.

<a id="source-0002"></a>

## 발췌 2: ## 2. 확정값

출처: docs/architecture/GITHUB_ANDROID_RELEASE_PIPELINE.md · 원본 12~12행 · 원문 절: ## 2. 확정값.

- Firebase 프로젝트: `lost-party`

<a id="source-0003"></a>

## 발췌 3: ## 3. 착수 시 상태와 선행 문제

출처: docs/architecture/GITHUB_ANDROID_RELEASE_PIPELINE.md · 원본 25~25행 · 원문 절: ## 3. 착수 시 상태와 선행 문제.

- 착수 시 `android/app/google-services.json`과 `lib/firebase_options.dart`의 Android Firebase 앱도 임시 ID에 연결돼 있었다.

<a id="source-0004"></a>

## 발췌 4: ## 3. 착수 시 상태와 선행 문제

출처: docs/architecture/GITHUB_ANDROID_RELEASE_PIPELINE.md · 원본 32~32행 · 원문 절: ## 3. 착수 시 상태와 선행 문제.

2026-09-21에 사용자가 Firebase Android 앱 `kr.co.heowork0921.lostparty`를 추가하고 새 설정 파일을 전달했다. Gradle namespace/applicationId, MainActivity package·경로, `google-services.json`, `firebase.json`, Android `FirebaseOptions.appId`를 새 등록값으로 일치시켰다. JSON·정적 분석과 `processDebugGoogleServices`가 통과했고, 사용자가 새 package APK의 별도 설치와 정상 동작을 확인했다.

<a id="source-0005"></a>

## 발췌 5: ### A. 정식 앱 ID와 Firebase Android 앱 전환

출처: docs/architecture/GITHUB_ANDROID_RELEASE_PIPELINE.md · 원본 38~50행 · 원문 절: ### A. 정식 앱 ID와 Firebase Android 앱 전환.

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


<a id="source-0006"></a>

## 발췌 6: ## 5. 회귀 보호와 실패 처리

출처: docs/architecture/GITHUB_ANDROID_RELEASE_PIPELINE.md · 원본 93~93행 · 원문 절: ## 5. 회귀 보호와 실패 처리.

- 앱 ID·Firebase Android config·서명 변경 외 앱 기능, Firestore Rules, Indexes와 서버 데이터는 변경하지 않는다.

<a id="source-0007"></a>

## 발췌 7: ## 5. 회귀 보호와 실패 처리

출처: docs/architecture/GITHUB_ANDROID_RELEASE_PIPELINE.md · 원본 97~97행 · 원문 절: ## 5. 회귀 보호와 실패 처리.

- Actions에서 실기기 조작을 하지 않는다. 수동 artifact 또는 GitHub Release APK의 설치·실행·Firebase 연결은 사용자가 확인한다.

<a id="source-0008"></a>

## 발췌 8: ## 5. 회귀 보호와 실패 처리

출처: docs/architecture/GITHUB_ANDROID_RELEASE_PIPELINE.md · 원본 98~98행 · 원문 절: ## 5. 회귀 보호와 실패 처리.

- 기존 Rules Emulator workflow와 release workflow를 결합하지 않는다. 릴리즈 직전 필요한 검증은 release 브랜치에서 끝내고 APK workflow는 재현 가능한 빌드·서명·게시만 책임진다.

<a id="source-0009"></a>

## 발췌 9: ## 6. 완료 조건

출처: docs/architecture/GITHUB_ANDROID_RELEASE_PIPELINE.md · 원본 102~102행 · 원문 절: ## 6. 완료 조건.

- 정식 ID의 APK가 실기기에 설치되고 Firebase Auth·Firestore 기본 진입이 정상이다.

<a id="source-0010"></a>

## 발췌 10: ## 7. 제외 범위

출처: docs/architecture/GITHUB_ANDROID_RELEASE_PIPELINE.md · 원본 114~114행 · 원문 절: ## 7. 제외 범위.

- Firebase Rules·Indexes·Functions·Hosting 배포
