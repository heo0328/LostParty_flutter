# NEXT WORK — 로컬 개발 환경 복구 마감·서명 후속

## 승인·현재 상태 — 2026-11-07

사용자 지시로 PC 포맷 후 네이티브 개발 환경, 로컬 dev 서버 연동, 운영 서버·APK 배포 설정을 점검했다. 기존 Flutter 3.41.6/Dart 3.11.4/Java21과 Git 기준 설정·고정 의존성을 복구했고, GitHub CLI·Git 권한/push dry-run·IDE 확장을 확인했다. 사용자가 dev 로컬 에뮬레이터의 Google 로그인 정상 동작을 확인했다. 앱 코드 변경이나 신규 운영 배포 없이 개발 재개 기반을 복구했다. 검증·장애 경과는 DEV_LOG, 현재 공개 서명 식별표는 [Google 로그인 계약](../architecture/GOOGLE_LOGIN_CONTRACT.md#포맷-후-로컬-복구oauth-서명-식별-2026-11-07)에 둔다.

이전 v2.0.0 게시 작업은 완료됐다. 태그/서명 CI/체크섬·Backend 인계는 DEV_LOG와 docs/releases/v2.0.0.md의 기존 근거를 유지하며 다시 실행하지 않는다. 현재 main/dev 원격 소스는2fd87438이고, 복구 기록은 docs/local-development-recovery에서 보관한다. dev/main 통합은 별도다.

## 현재 파트·완료 조건

- 포함: 사용자 로컬 로그인 인수와 복구 검증 기록 마감, 공개 운영 APK의 체크섬/서명 지문 대조, 현재 문서의 완료/미완료 구분. 문서 내용·링크·git diff --check를 확인하고 같은 파트로 커밋·푸시한다.
- 제외: 신규 기능/오류 안내 UX 수정, 전체 앱 정상 흐름 재인수, Backend 코드/환경·Google 콘솔 변경, 키 생성/삭제, 운영서버 배포·새 APK 게시·dev/main 병합. 전체 기능2817PASS와 이번 복구의 인증 세션15PASS·분석0/debug APK 빌드 결과를 구분하며 문서 변경으로 시험을 반복하지 않는다.
- 완료: 복구 완료 기록과 유효 후속이 정합하고, 작업 브랜치 local/origin 동일 커밋·관련 미커밋 없음. 복구 후 공개 APK의 기존 파일 체크섬/승인 서명 일치도 확인했다.

## 남은 사용자 확인·다음 행동

1. **OAuth 정리:** 운영 APK의 서명 추출은 완료했다. 사용자가 콘솔의 기존 Android 클라이언트를 식별표와 대조하고 과거 debug 키를 쓰는 다른 환경이 없는지 확인한다. 실제 삭제는 확인 후 사용자 지시에 따른다. 담당·완료 조건은 [차후 수정안](../product/DETAIL_IMPROVEMENTS.md#로컬-환경-복구--google-oauth-android-클라이언트-정리)을 따른다. 정상 개발 재개의 차단 조건은 아니다.
2. **서명키 보관·로컬 release 빌드:** 사용자가 현재 debug 키 백업과 기존 release 키/비밀번호 백업 보유를 확인한다. 로컬 release 빌드가 필요할 때 ignored android/key.properties 또는 환경변수 연결을 복구하고 승인 인증서와 대조한다. 현재 로컬 key.properties는 없으며 CI의 서명 Secret4개 존재·기존 서명 CI 성공은 확인했다. Secret 값은 조회하지 않았고 다음 승인된 CI 빌드의 유효성은 별도다. CI 배포에 로컬 서명 파일 복원을 필수화하지 않는다.
3. **향후 실제 게시:** 사용자가 새 버전 게시를 지시할 때 버전명/build code·Backend 호환·고정 source/tag·기존 서명·실제 업데이트 설치를 확인한다. 기존 운영 앱 정상 사용 보고와 공개 health200/카탈로그200/미인증me401을 새 APK 전체 인수로 확대하지 않는다.

별도 제품 개선은 DETAIL_IMPROVEMENTS의 유효 범위를 따르며 이번 복구 완료를 새 기능 착수 승인으로 사용하지 않는다. Backend는 자체 에이전트가 복구를 진행한 범위이고 이번 사용자 보고에 대한 별도 Issue 댓글 요청은 없다.
