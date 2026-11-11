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

<a id="release-key-backup"></a>
### B-1. 새 release 키 전환·백업 안내 — 2026-11-07 사용자 확정

사용자는 포맷 전 release 키 원본/비밀번호 백업이 없음을 확인했고, 기존 GitHub Secret에서 키를 회수하는 대신 **새 release 키를 생성해 백업하고 이후 배포를 그 키로 통일**하기로 결정했다. 기존 APK 사용자는 서명 전환 버전에서 앱 삭제→새 APK 설치→동일 Google 계정 재로그인으로 진행하며, 서버의 기존 회원/자료를 유지한다. 기기의 로컬 전용 자료·미전송 작업은 삭제될 수 있음을 게시 안내에 포함한다. 같은 운영 Backend와 올바른 OAuth/허용 목록을 사용해야 한다. iOS·스토어 출시는 별도 준비 대상이다.

**2026-11-11 현재 새키 생성·사용자 독립백업·사본 동일성/store 및 private key 접근 검증·Secret4개와 CI 예상지문 전환을 완료**했다. 실제 공개 버전은 2.1.0+6로 확정했으며 새 OAuth 등록·서명 CI·운영 인수·게시 상태는 NEXT_WORK를 따른다. 전환 전 공개 APK와 기존 운영 OAuth 등록/키를 임의 삭제하거나 변경하지 않는다.

**실행 시점은 추가 기능 개발과 개발 로컬 테스트를 모두 마친 뒤 운영 APK 게시를 준비할 때다.** 현재 승인된 2.1.0 릴리즈 준비에서 새키 전환과 게시 없는 수동 Actions 서명 빌드를 진행한다. OAuth·운영 인수와 실제 APK 공개는 구분하며 공개 게이트를 유지한다.

#### 에이전트의 백업 안내 시점·완료 조건

1. 다음 새 release 키 생성/전환 착수 시, 그리고 그 키로 첫 APK를 게시하기 전에 에이전트가 사용자에게 아래 물리 파일·정보 목록과 보관 방법을 다시 안내한다. 채팅 기억에 의존하지 않고 이 절과 NEXT_WORK를 확인한다. 생성 위치/파일명을 실제 값으로 안내하며 비밀번호 입력/보관은 사용자 통제 아래 처리한다.
2. 사용자가 원본과 별도 백업 사본을 보관했다고 확인하고, 백업 사본의 인증서 지문·alias/비밀번호로 키를 열 수 있는지 확인한 뒤 백업 완료로 표시한다. 사용자에게 비밀번호나 파일을 채팅으로 보내도록 요구하지 않는다. GitHub Secret 등록만으로 별도 백업 완료라 하지 않는다.
3. 비밀값 없이 백업 확인일·파일명·사용자 보관 확인·공개 지문·확인한 범위를 DEV_LOG에 기록한다. 사용자 백업 확인 전에는 새 키의 첫 게시 준비를 완료로 선언하거나 게시하지 않는다. 같은 키를 쓰는 이후 업데이트에서는 기존 백업 기록을 재사용하며 매번 새 키 생성/재백업을 요구하지 않는다. 키/비밀번호가 변경되면 백업도 갱신한다.

#### 릴리즈 준비 시 보관할 물리 파일·저장 정보

| 대상 | 실제 보관물 | 얻는 위치·필요 여부 |
|---|---|---|
| 새 Android release 개인키 | 새 `.jks` 또는 `.keystore` 원본과 별도 백업 사본 | keytool/Android Studio로 생성한 파일. **필수**이며 웹 콘솔 다운로드로 대체할 수 없음. 실제 생성 경로·파일명은 아직 미정 |
| 키 사용 정보 | keystore 비밀번호, key alias, 해당 key 비밀번호 | 생성 시 정한 값을 암호화된 비밀번호 관리자 등 별도 보안 보관. 비밀번호를 분실하면 파일만으로 서명 준비가 되지 않음 |
| 복원 식별 정보 | 용도, 파일명, alias, 공개 SHA-1/SHA-256, 최초 적용 버전·확인일 | 키의 공개 인증서에서 추출해 백업 사본과 대응시켜 보관. 지문 메모만으로 개인키 복원 불가 |
| 현재 debug 개인키 | `C:\Users\lovea\.android\debug.keystore` | 사용자가 파일 복사 백업 완료를 보고함. 다음 PC 복구에 같은 파일을 재사용하며 release 키와 혼동하지 않음 |
| 로컬 빌드 연결 설정 | `android/key.properties` 또는 사용한 환경변수 이름·연결 방법 | PC에서 release 빌드할 때만 필요. 경로/필드를 재작성할 수 있으므로 개인키를 대신하지 않음. 비밀번호가 들어간 파일을 복사한다면 암호화 보관. CI 전용 배포에 새 로컬 설정 생성을 강제하지 않음 |
| GitHub 서명 설정 | `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`의 대응 기록 | 새 원본/보관 비밀번호로 등록·교체할 때 대응 확인. Base64는 원본에서 다시 만들 수 있으므로 별도 평문 파일 백업 불필요. Secret 화면/API는 원문 다운로드 기능이 아님 |
| OAuth 연결 메모 | Google 프로젝트, Android/Web 클라이언트 ID·용도, 패키지명·공개 지문, Backend 허용 목록 반영 여부 | Google 콘솔의 공개 식별값을 기록. 현재 Google 토큰 검증 흐름에는 OAuth JSON이나 Web client secret 다운로드를 새 필수 백업으로 추가하지 않음. OAuth JSON/APK/공개 인증서는 release 개인키를 포함한 백업이 아님 |

백업 사본은 생성 PC와 독립된 외장 저장장치 또는 암호화된 별도 저장소에 보관한다. 키 파일·비밀번호·key.properties·Base64 원문을 Git/공개 Release/평문 Actions artifact/로그/채팅에 올리지 않는다. 원본과 별도 사본의 바이트/해시 일치와 실제 키 접근 확인을 구분한다. **암호화되지 않은 Base64는 암호화 백업이 아니다.**

#### 전환 실행 때 확인할 순서

새 키 생성→사용자 물리 백업·접근 확인→새 공개 지문 기록→운영 Android OAuth 등록 및 Backend `azp` 허용 설정 협의→GitHub Secret4개와 CI 예상 인증서 지문을 같은 새 키 기준으로 전환→배포 없는 서명 빌드/로그인·기존 서버 회원 연결 확인→사용자 명시 게시 지시 후 삭제·재설치/로컬 자료 영향 안내와 함께 게시한다. 실제 앱 설치·조작은 사용자 담당이다. 서버 설정 변경은 Backend 담당이며 검증 우회나 자료 초기화로 대신하지 않는다. 새 키 전환 후의 업데이트는 같은 키를 재사용한다.

#### Backend 백업 항목·시기 — 기준본 보관·문서 게시 완료

[Issue46 실행 결과](https://github.com/heo0328/lostparty-backend/issues/46#issuecomment-6706589300)와 [최종 인계](https://github.com/heo0328/lostparty-backend/issues/46#issuecomment-6706731221)를 기준으로 한다. Backend source `c62f2a739dc48fda23bf0cc97959b01ae17b0a30`의 [백업 원장](https://github.com/heo0328/lostparty-backend/blob/c62f2a739dc48fda23bf0cc97959b01ae17b0a30/docs/engineering/operations/backup-and-recovery.md)이 실제 경로·복사/다운로드 방법·안내 시점의 원본이다. 과거 운영 실행 보류·복사 방법 회신 대기는 Backend 대화의 별도 사용자 지시와 실행으로 해소됐다. Native가 백업 파일을 직접 읽거나 검증한 것은 아니며 아래는 Backend 인계·사용자 보관 보고의 소비 기록이다.

| 구분·시점 | 현재 상태·다음 행동 |
|---|---|
| 로컬 복구 마감 | debug 키 복사 사용자 보고 완료. Backend `.env`·기존 키4개와 콘솔 자료/다운로드 JSON·Lightsail 기본키도 사용자 보관 보고. 로컬 DB dump는 사용자 제외. 외장 매체 사본은 미확인이며 내장 SSD 보관을 외장하드 완료로 표시하지 않음 |
| AWS 최초 외부 보관 | 2026-11-07 운영 DB·현재 환경·기존 키4종·배포 상태/동결 구성·필요한 복구/접속 구성의 온라인 백업과 PC 내장 SSD 전송 완료. 서버/PC SHA-256 일치·dump 목차/아카이브 내용 확인. 실제 DB/서비스 복원 성공으로 확대하지 않음 |
| 새 Native release 키 생성/첫 게시 전 | 새 키/비밀번호·alias의 별도 사본과 접근 확인은 실행 전. 본 절의 Native 기준·착수 시점을 따르며 Backend 키 교체 지시가 아님 |
| 키·설정·DB/자료 변경 또는 PC/서버 재구성 전후 | Backend가 해당 변경 직전 필요한 최신 사본과 변경 후 유효 키·설정/DB 짝을 안내. 변경 없는 키는 재사용하고 앱 버전 증가만으로 전부 재백업/키 재발급하지 않음 |
| 실제 복원·정기 자동화 | 이번에는 미실행. 개발 재개 선행 조건으로 추가하지 않으며 별도 필요·지시에서 검토 |

운영 백업은 서비스 중단·재배포·키 교체 없이 수행됐다고 인계받았다. 사용자 직접 보관용 사본은 암호화되지 않았으며 Git/채팅/공개 artifact에 게시하지 않는다. 분실한 자동 배포 SSH 개인키 원본은 백업에 포함되지 않았고 정상 동작하는 GitHub 배포 Secret은 유지했다. 원본 회수·보유 여부의 반복 확인이나 Secret 교체를 새 필수 작업으로 만들지 않는다. 사용자 확인 후 별도로 추가한 관리자 SSH 공개키와 기존 배포키를 구분한다.

Issue46은 OPEN이며 추가 Native 구현·동일 기준 재수용·정상 로그인 반복 시험 요청은 없다. 개인 저장 경로·비밀값·백업 파일은 이 문서에 복제하지 않는다.

#### 향후 스토어 준비 때만 확인할 다운로드·보관 항목

- **Google Play:** Play App Signing을 도입하면 앱 서명키와 업로드 키를 구분한다. 직접 보유하는 업로드 `.jks`/비밀번호/alias는 백업하고, 직접 만든 앱 서명키를 Google에 제공한다면 제공 전 원본을 보관한다. Google 생성 앱 서명키는 개인키 파일을 내려받는 방식이 아니며, Play Console에서 받는 공개 인증서(`.der`/`.pem`)와 공개 지문은 API/OAuth 등록·식별 기록용이다. 스토어 서명이 기존 APK와 다르면 연속 업데이트가 되지 않으므로 도입 시 배포 경로를 별도 확정한다.
- **iOS:** Android 키와 별개다. Mac에서 직접 관리하는 배포 인증서를 쓴다면 개인키를 포함한 암호화 `.p12`와 내보내기 비밀번호를 Xcode/키체인에서 백업한다. Developer 사이트의 `.cer`만으로 개인키 백업이 되지 않는다. 수동 프로비저닝 방식일 때 `.mobileprovision`과 Team ID·Bundle ID를 보관하며, 클라우드 관리 인증서는 로컬 `.p12` 내보내기를 필수화하지 않는다. API/APNs 등 별도 서비스의 `.p8` 키를 실제 생성할 때는 콘솔의 일회 다운로드를 즉시 저장하고 해당 Key ID·Team ID/서비스 식별값을 함께 보관한다. 현재 키 생성·iOS 설정 착수 지시는 아니다.

공식 확인(2026-11-07): [Android 앱 서명·키 보관](https://developer.android.com/studio/publish/app-signing), [GitHub Secrets·Base64](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets), [Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756?hl=en), [Apple 서명 인증서 `.p12` 내보내기](https://help.apple.com/xcode/mac/current/en.lproj/dev154b28f09.html), [Apple 서비스 개인키 다운로드](https://developer.apple.com/help/account/keys/create-a-private-key/), [Apple 클라우드 관리 인증서](https://developer.apple.com/help/account/certificates/cloud-managed-certificates/).

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
6. `flutter build apk --release` (2026-11-01부터 주소 옵션 생략 시 AWS `https://lostparty.duckdns.org` 사용. `BACKEND_BASE_URL` 명시값이 있으면 우선하며 설정 계약은 GOOGLE_LOGIN_CONTRACT를 따른다.)
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

## 8. 2.1.0 통합 릴리즈 준비 — 웹·Backend·새 Android키 (2026-11-11)

사용자 확정: 앱2.1.0+6/v2.1.0, 기존 AWS/https://lostparty.duckdns.org 루트 웹, 베타 전 사전 테스트·접속자 제한 없음·현재 운영자료 유지. 최신 사용자 정정으로 APK/GitHub Release 준비는 먼저 진행할 수 있지만 최종 운영 공개는 Backend·웹·APK를 함께 진행한다. 공개 안내문은 docs/releases/v2.1.0.md를 사용자에게 먼저 제시해 확인받고, 승인된 문구로만 게시한다. 서버후반영·웹예정 안내는 공개문에 넣지 않고 실제 공개 시점과 일치시킨다. 현재 준비/미확인 상태는 NEXT_WORK, 공식 협업은 Backend Issue49다. 이 절은 기존 Android 전용 pipeline의 웹 배포 제외를 웹 별도 bundle 준비로 확장하며 기존 APK 태그/서명/게시 검증은 유지한다. 서버측 Caddy/동결Compose·migration·최신 운영백업은 Backend 소유다.

### 웹 산출물

- `powershell -NoProfile -File tool/package_web_release.ps1`은 clean Git source만 게시용으로 빌드한다. 미커밋 단계의 `-AllowDirty`는 검토 후보(`candidate_only=true`)일 뿐 업로드/게시용이 아니다.
- 운영 HTTPS origin·release·로컬 web resources·source-map 미포함으로 빌드한다. 서비스워커 등록 산출물은 거절하며 문서/map/symbols/worker 캐시파일을 배포 site에서 제외한다.
- `build/web-releases/<version>-<code>-<release|candidate>-<UTC>/` 안에 `site/`와 `release-manifest.json`, 출력 루트의 고정 `lostparty-v<version>-web.zip`·동명 `.sha256`·`release-manifest.json`을 만든다. 내부site/manifest는 bundle/에서 생성하며 전달artifact에는 루트3파일만 포함한다. manifest schema1에 source_commit/source_dirty/candidate_only/version/backend_origin/build_mode와 site 상대 파일명·bytes·sha256을 기록한다. manifest는 정적 site 밖에 둔다.
- Backend 인계 시 clean source SHA·bundle hash/manifest를 대조하고 실제 파일 검증 뒤 활성화한다. 버전별 디렉터리는 보존하고 Caddy가 읽는 안정된 상위 디렉터리를 read-only mount한다. host의 current symlink만 bind mount하면 교체가 컨테이너에 안 보일 수 있으므로 parent mount와 내부 상대 symlink를 사용한다. 실제 경로·서버 도구 반영은 Backend가 정한다.
- API/health 보존, 없는 자산404, SPA 화면 fallback, no-cache 재검증 및 WASM MIME을 분리한다. API 권한 오류·없는 JS/WASM을 index.html200으로 바꾸지 않는다. COOP/COEP 추가 없음.

### 새 키 사용자 실행·백업

생성 예정 경로는 `G:\project\LostParty_flutter\android\keystores\lostparty-release-2026.jks`, alias는 `lostparty-release`다. android/.gitignore의 JKS 제외를 먼저 검사하며 파일이 이미 있으면 스크립트가 중단한다. 기존 키/Secret을 덮어쓰지 않는다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tool/new_android_release_key.ps1 -JavaHome G:\dev\Java\jbr-21.0.11
```

키tool의 암호 입력은 사용자 터미널에서만 한다. 암호를 명령 인수·채팅에 쓰지 않는다. 생성 후 원본 파일을 생성PC와 독립된 안전한 저장소에 복사하고 store 암호·alias·key 암호를 별도 보관한다. 원본/사본 SHA-256 일치와 `keytool -list -v -keystore <백업사본> -alias lostparty-release`의 접근 확인을 수행한다. 공개 SHA-1/SHA-256만 공유할 수 있고 키파일·비밀번호·Base64 원문은 공유하지 않는다. 인증서 조회만으로 private key 암호 확인을 대신하지 않으며 서명 빌드로 key 접근도 확인한다.

사용자 별도 사본 보관 보고와 사본의 store/key 접근 확인 전에는 B-1 기준 첫 게시 준비 완료로 처리하지 않는다. 새 공개 지문이 확정된 뒤 OAuth/azp와 Secrets4개·CI EXPECTED_CERT_SHA256을 함께 전환한다. 2026-11-11 18:41 KST 새키 사용자 별도백업 보고·사본동일/alias/store접근·private key 서명검증 통과와 GitHub Secrets4개 갱신을 확인했다. 새 공개 SHA-1은 0a415cda3660ca2f7935deec50e72e7cdc3b70a6, SHA-256은 8ef16c58cbb605e2c74c99c4d8e9f252b00c3dd90837594d5e5ca40f0caed030이며 CI 예상지문도 전환했다. 새Android OAuth client와 운영 Web 원본은 사용자 등록확인, 공개 식별값은 GOOGLE_LOGIN_CONTRACT에 기록했다. Backend azp 대조와 운영 실로그인은 대기다. 서명CI43003690946은 성공했고 내려받은 APK의 인증서/패키지/2.1.0+6·체크섬도 대조했다. 태그/게시·기기 설치는 실행하지 않았다.

### 게시·복귀

Release 본문 원본은 `docs/releases/v2.1.0.md`다. workflow는 태그 소스의 동일 버전 안내문을 checkout해 `--notes-file`로 게시하며 누락 시 실패한다. 새 키 때문에 삭제·재설치·동일 Google 로그인 및 로컬 자료 손실 가능성을 반드시 포함한다. 웹과 APK는 같은 운영 회원/자료를 사용한다.

서명 artifact/새키·OAuth 준비를 검증하고 안내문 사용자 확인 후 최종 게시 시점을 main/dev에 반영해 태그/게시한다. Backend·웹·APK의 최종 공개는 함께 진행하며 준비/적용의 기술 순서와 구분한다. 운영 인수 미확인을 성공으로 처리하지 않는다. 웹은 이전 정적 버전 또는 최초 미공개로 복귀, Backend는 새DB와 호환되는 복귀만 사용하며 새 쓰기를 잃는 dump 덮어쓰기를 하지 않는다. 공개 APK/태그 덮어쓰기·무단 반복배포 없음. Backend 키·정상 배포 SSH Secret은 재사용하고 11월7일 백업을 최신DB로 간주하지 않는다. 실제 운영변경·키 전환/최초 게시 시의 사용자 확인 조건을 현재 실행 게이트로 유지한다.

### Issue49 W3 공동 인계 확정 (2026-11-11)

Backend6792858978/6792885928 수용으로 manual-only Actions artifact(lostparty-web-2.1.0-6-<SHA12>,14일)→동일ZIP의 최종Release asset 승격을 확정했다. artifact 루트는 lostparty-v2.1.0-web.zip·동명.zip.sha256·release-manifest.json, 실제bundle 안은 site/와 동일manifest다. 외피ZIP과실ZIP hash를 구분하고 run/ID/name/expiry·source/hash/내부경로를 인계한다. ZIP entry와 manifest경로는 POSIX /이며 기존 Windows backslash ZIP은 제외한다. 만료/불일치는 새식별자로재인계하고 자동대체/덮어쓰기하지 않는다. Native 빌드/고정물 인계와 Backend 수령검증/inactive staging/활성화로 분담한다. 구APK+신서버는 upgrade거절/원ACK 등 조건부범위이며 Backend 고정후보회귀·최종표가 필요하다. 첫공개 새탭/재접속 기준, 구탭무중단/버전고정asset URL 미지원 한계를 수용했고 이번 URL고정 추가구현을 필수로 하지 않는다. 기술적 적용과 최종공동공개, 협의확정과 실제실물/운영인수는 구분한다.

W3 구현: tool/web_bundle.ps1로 ZIP entry를 /로 직접 작성하고 목록/hash/manifest바이트/안전경로·대소문자중복·symlink를 검증한다. tool/test_web_bundle.ps1의12경계검사를 manual workflow에서도 실행한다. web-release.yml은 workflow_dispatch/workflow_call이고14일보관·contents:read만 사용한다. default등록 전 최초실행은 기존 android-apk-release.yml에 추가한 artifact_target=web의 reusable-call 경로를 사용한다. 이때 Android빌드/Secret/job은 건너뛰며 tag APK게시·기본android선택은 기존대로다. 코드준비와 실제Actions실행/업로드를 구분하고 run/artifactID/expiry는 실행후API로 확정한다.
