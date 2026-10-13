# GitHub Android APK Release Pipeline 계약

> 기존 서비스 전용 항목은 [원문·출처 기록](../../legacy/firebase/extracted/docs/architecture/GITHUB_ANDROID_RELEASE_PIPELINE.md)으로 분리했다. 남은 제품/협업 문맥의 신규 서버 적용 여부는 별도 설계에서 판단한다.

## 1. 목적

검증된 LOSTPARTY Android 버전을 동일한 앱 ID와 서명으로 빌드하고, Git 태그에 대응하는 GitHub Release 페이지에서 APK를 직접 내려받을 수 있게 한다.


## 2. 확정값

- 정식 Android application ID와 namespace: `kr.co.heowork0921.lostparty`
- 기준 Flutter: `3.41.6` stable
- 기준 Dart: `3.11.4`
- CI Java: 21, 앱 JVM target: 17
- 버전 원장: `pubspec.yaml`의 `version: <name>+<code>`
- 정식 태그: `v<name>` 형식. 예: `version: 1.0.0+1`은 `v1.0.0`
- 배포 파일: 단일 범용 release APK와 SHA-256 checksum

정식 ID는 릴리즈 후 변경하지 않는다. 변경하면 Android가 다른 앱으로 취급하고 기존 설치본 위에 업데이트할 수 없다.

## 3. 착수 시 상태와 선행 문제

- 착수 시 Android ID는 임시값 `com.example.lost_party`였다.
- 착수 시 `release` buildType은 debug signingConfig를 사용했다.
- 착수 시 로컬 `android/key.properties`와 정식 keystore는 저장소에 없었다.
- Git tag와 GitHub Release는 아직 없다.

수동 release APK의 실행 성공은 앱 런타임 확인 근거지만, CI 배포 준비 완료를 뜻하지 않는다. GitHub hosted runner의 임시 debug key로 매번 서명하면 다음 APK를 기존 설치본 위에 업데이트하지 못할 수 있으므로 정식 배포에는 하나의 영구 release key를 사용한다.


같은 날 영구 JKS와 ignored `android/key.properties`를 만들고 Gradle release signingConfig를 해당 키로 전환했다. 로컬 release APK는 package `kr.co.heowork0921.lostparty`, version `1.0.0+1`, 인증서 `CN=LostParty, OU=Development, O=HeoWork0921`로 검증했다. keystore와 비밀번호는 Git 변경 목록에 포함되지 않는다. GitHub Secrets 등록과 Actions workflow 구현은 다음 단계다.

## 4. 작업 단계

### A. 정식 앱 ID와 Firebase Android 앱 전환

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/architecture/GITHUB_ANDROID_RELEASE_PIPELINE.md#source-0005)로 이동했다.

### B. 영구 release 서명

1. 사용자가 장기 보관할 release keystore를 로컬에서 한 번 생성하고 별도 백업한다.
2. keystore와 비밀번호를 Git에 커밋하지 않는다.
3. 로컬 빌드는 ignored `android/key.properties`로 키를 읽는다. CI는 GitHub Repository Secrets를 환경변수로 Gradle에 전달하고 runner 임시 경로에 keystore만 복원한다. 비밀번호가 담긴 파일은 CI 작업 공간에 만들지 않는다.
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
4. Secrets로 runner 임시 keystore를 복원하고 서명값을 환경변수로 전달
5. 태그 실행이면 `v<pubspec versionName>` 일치 및 태그 커밋의 `main` 포함 여부 검사
6. `flutter build apk --release`
7. APK 서명 유효성, package ID, versionName/versionCode 검사
8. `lostparty-<tag>-android.apk`로 이름 변경 및 `.sha256` 생성
9. 검증 결과를 짧은 보존 기간의 workflow artifact로 업로드
10. 수동 실행은 artifact까지만 제공하고, 태그 실행은 별도 최소 권한 job이 `contents: write`의 기본 `GITHUB_TOKEN`으로 GitHub Release 생성 및 두 파일 첨부

workflow가 tag를 자동 생성하거나 브랜치를 병합하지 않는다. release 안정화가 끝나 `main`과 `dev`를 최종 release 시점으로 맞춘 뒤 사람이 해당 커밋에 태그를 생성·푸시한다.

작업 브랜치에서 Secrets·서명·artifact를 검증하는 동안에만 해당 브랜치 push trigger를 두었고, Actions `35592769624` 성공 뒤 제거했다. 최종 workflow는 `workflow_dispatch`와 `v*` tag만 유지한다.

최초 `v1.0.0` run `35596035632`는 signed APK 검증과 artifact 업로드까지 통과했으나 checkout 없는 release job이 저장소를 자동 판별하지 못했다. `gh release view/create`에 `--repo "$GITHUB_REPOSITORY"`를 명시해 이후 태그 게시 경로를 보정했으며, `v1.0.0`은 같은 성공 artifact의 체크섬을 재검증한 뒤 공개 Release로 복구했다.

## 5. 회귀 보호와 실패 처리

- Secret이 없거나 package/version/signature 검사가 실패하면 Release를 만들지 않는다.
- 같은 태그의 Release 또는 asset이 이미 있으면 덮어쓰지 않고 실패시킨다.
- 빌드 실패 뒤 태그를 다른 커밋으로 강제 이동하지 않는다. 원인을 수정하고 새 버전 태그를 사용하거나, 아직 공개 전인 잘못된 태그의 처리 여부를 사용자가 결정한다.

## 6. 완료 조건

- 같은 release key로 만든 후속 build가 기존 정식 ID 앱 위에 업데이트 설치된다.
- 수동 workflow가 APK artifact와 checksum을 만든다.
- 테스트 태그가 아닌 실제 승인 태그에서 GitHub Release와 직접 다운로드 가능한 APK가 생성된다.
- APK의 package ID, version, 서명 인증서와 checksum이 기록된다.
- keystore·비밀번호·`key.properties`가 Git 이력과 Actions 로그에 노출되지 않는다.

## 7. 제외 범위

- Google Play Console, Play App Signing과 AAB 게시
- iOS·Windows·웹 배포
- 자동 버전 증가, 자동 태그 생성, 자동 `dev`/`main` 병합
- 기존 임시 패키지 앱의 로컬 데이터 마이그레이션
