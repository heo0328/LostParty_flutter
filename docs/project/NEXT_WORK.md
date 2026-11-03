# NEXT WORK — Android v2.0.0 APK 게시

## 승인·현재 상태 — 2026-11-04

사용자가 새 릴리즈 게시, 버전 2.0.0, 승인한 새 안내문을 기존 안내문 상단에 추가하도록 지시했다. `release/2.0.0`에서 `2.0.0+5`와 누적 안내문을 준비하고 dev/main에 반영했다. `docs/releases/v2.0.0.md` 하단에는 실제 v1.1.2 게시 본문 전체를 보존했다. 기존 Release·태그·파일은 변경하지 않는다.

Backend 운영 지원 대기는 해소됐다. [Issue34 완료 회신](https://github.com/heo0328/lostparty-backend/issues/34#issuecomment-6609667274)에서 v2.0.0 소스 `51b1cb3362c11f899bbbbcd4fb767c68b1c697d5`, 운영 배포 성공과 일괄 GET/POST·기존 참가 유지 수정 지원을 확인했다. [배포 Actions](https://github.com/heo0328/lostparty-backend/actions/runs/41674801953)는 성공이며 DB revision0035·환경/키/자료 보존, health 검증 결과를 인계받았다. Backend 배포를 중복 실행하지 않았다.

## 게시 완료·남은 확인

Native 태그 `v2.0.0`은 main에 포함된 `703f7b8afd8aff52f475da0b32ade853f0e5c210`에 고정했다. [서명 APK Actions41675349499](https://github.com/heo0328/LostParty_flutter/actions/runs/41675349499)는 빌드·앱 ID/버전/기존 서명 인증서 검증·게시까지 성공했다. [공개 Release](https://github.com/heo0328/LostParty_flutter/releases/tag/v2.0.0)에 `lostparty-v2.0.0-android.apk`와 `.sha256`이 첨부됐고 draft/prerelease가 아님을 확인했다. APK SHA-256은 `a9b8f6a0a82be7f567a03a0e008649c26c3ffe05b65193fa4de592d27c755c04`이며 게시 asset digest와 체크섬 파일이 일치한다.

Release 본문을 승인한 누적 안내문 파일로 적용하고 실제 본문 동일성·기존 v1.1.2 본문 전체 하단 보존을 재조회 검증했다. 기존 Release/태그/첨부 파일은 변경하지 않았다. Backend 운영 지원 대기와 Native 게시 작업은 완료이며 [Issue34에 Native 완료 결과](https://github.com/heo0328/lostparty-backend/issues/34#issuecomment-6609824463)를 회신했다.

기능 소스는 기존 전체2817PASS·전체분석0 및 사용자 로컬 인수 시점과 동일하다. 버전·문서 변경에는 diffcheck/본문 보존 검증을 적용하고 전체 Flutter 시험은 반복하지 않았다. 새 APK의 기존 설치본 위 업데이트 설치·운영 실회원 전체 인수는 미확인이고 사용자 담당이다.

완료 기록은 release/2.0.0에서 커밋하고 dev/main을 같은 시점으로 반영·푸시한다. 공개 태그의 소스는 이동하지 않으며 릴리즈 브랜치는 버전 이력으로 보존한다. 별도 남은 표시/제품 개선은 DETAIL_IMPROVEMENTS를 따른다. 기존 dev 방 복구는 제외 범위이며 운영 자료 변경이나 추가 기능 수정은 수행하지 않는다.
