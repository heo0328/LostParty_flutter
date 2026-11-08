# NEXT WORK — Issue17 Native 구현 기획·설계

## 현재 파트·범위 — 2026-11-08

사용자와 Issue17의 누락 참가 캐릭터 발견·갱신·명시 교체 UX5항목을 확인하고 [공식 회신](https://github.com/heo0328/lostparty-backend/issues/17#issuecomment-6719423066)을 게시했다. 합의 상세는 [계약26 현재 절](../backend-migration/26-roster-character-lifecycle-design.md)에 둔다. 이전 개발 재개 전 문서 정리와 Issue34/38/46 최신화 게시 경과는 DEV_LOG/아래 근거를 보존한다.

- 완료: 사용자 계획을 [계약26의 Native 구현 기획·설계](../backend-migration/26-roster-character-lifecycle-design.md#issue17--native-구현-기획설계-2026-11-08)에 반영했다. 배지·주차별 권한·기존 변경 버튼, 상세 주차 선택 아래 안내/갱신, 활동 관리 왕복, 원본/표시 분리, 남은 참가만 교체, 명령/조회 수명과 회귀 책임을 확정했다.
- 현재 상태: [Backend 개발서버 반영 회신](https://github.com/heo0328/lostparty-backend/issues/17#issuecomment-6721249386)에서 기존 dev DB0036·새 실행 소스 및 실제 계약 지원을 인계했다. 이전 서버 미지원 대기는 해소됐다. [구현 게시 회신](https://github.com/heo0328/lostparty-backend/issues/17#issuecomment-6721299358) 기준 Backend 구현·계약은 `4c37c2bebbb9eb8950770a240b6e20b7b468399c`로 push됐으며 기존 OpenAPI 해시·로컬 실행 지원은 유지된다. Native 신규 DTO·실제 앱 연결·기기 인수는 미완료다. 이번은 개발 전 문서 커밋이며 기능 코드는 변경하지 않는다.
- 협업: [Native 설계·지원 인계 확인 회신](https://github.com/heo0328/lostparty-backend/issues/17#issuecomment-6721323343)을 게시하고 재조회 본문 일치를 확인했다. 추가 Backend 변경·반복 시험 요청 없이 다음 담당은 Native 후속 구현이다.
- 제외/보류: 코드/Native 화면 구현·Penpot·기기 시험은 후속 구현 지시까지 보류. 소유권 이전15·활동 자동추가18·자동 퇴역/claim해제·자료 삭제·웹소켓 구현·서버/DB 추가 변경·운영 배포·APK 게시·Issue 종료는 별도다.
- 디자인 확인: 이번 작업은 사용자 확정으로 Penpot 선확인을 생략한다. 합의한 기존 화면/배치에 따라 기능 개발 후 사용자 디바이스 테스트에서 화면·사용 흐름을 확인한다. Penpot 시안 승인을 개발 선행 조건으로 두지 않는다.
- 저장/검증: 사용자 지시로 dev86e53e11 기준 생성한 feature/raid-character-missing-recovery를 유지한다. 이번에는 개발 전 현재 누적된 최신 변경 전체를 로컬 커밋하며 푸시·dev 병합은 하지 않는다. 특정 파일 선택 지시가 없으면 추적 제외 파일 외의 변경을 임의로 나누거나 남기지 않는다. 댓글 재조회·문서 diff/링크·git diff --check를 확인하고 문서 변경으로 Flutter 시험을 반복하지 않는다.

## 후속 구현 순서·완료 조건

구현 지시 후 아래 순서로 같은 작업 그룹을 진행한다. 각 단계마다 별도 승인이나 커밋을 요구하지 않는다. 연결 대상은 기존 dev 로컬 서버이며 운영 반영을 선행 조건으로 삼지 않는다.

1. Backend 실제 실행 OpenAPI를 기준으로 지원 query 조합·DTO·확장 응답 검증 연결.
2. 누락 presence와 공용 원본 보존/일반 표시 분리, 남은 활성 참가(M)만 교체하고 완료·종료분(P) 보존. 후보·미리보기·최종 명령 대상 일치와 상세·일정·후속 명령 해석 연결.
3. 앱 공통 경고 상태·성공 후 영향 범위 갱신. 정상0/미조회/권한 없음·실패 구분, 회원/환경/주차/관계 전환·늦은 응답 보호. 저장된 원요청/ACK 불변.
4. 기존 하단/주차 선택/카드 배지·상세 안내·활동 관리 저장/취소 후 원래 방/실제 주차/변경 흐름 복귀 연결.
5. 주차별 권한·부분 완료/기록 보존·중복/응답 유실/원요청 복구·늦은 응답을 자동 검증. 공용 계정·모집 영향 때문에 최종 전체 `flutter test`·`flutter analyze` 수행 후 사용자 기기 확인 항목 전달.

일반 앱 진입→DI/Router→화면→조회/명령→성공 후 관련 계정·경고·목록·상세 갱신까지 연결해야 기능 연결 완료다. 상세→목록 무변경 복귀의 캐시/스크롤, 기존 정상 참가·신청·일정·완료·탈퇴, 주간 참가 원본과 완료 기록을 회귀 보호한다. Backend 개발 실자료에는 참가 방이 없어 새 상세/부분 완료 명령의 실자료 검증은 아직 없으며, 기존 격리 시험을 Native/사용자 인수로 확대하지 않는다.

## 확인된 개발 기준선

PC 포맷 후 Flutter3.41.6/Dart3.11.4/Java21·기존 설정/고정 의존성 복구와 사용자 dev 로컬 에뮬레이터 Google 로그인 인수를 마쳤다. 복구 당시 분석0/debug APK 빌드·인증 세션15PASS와 이전 기능 전체2817PASS는 서로 다른 검증 범위이며 이번에 다시 실행한 결과가 아니다. 공개 서명 식별표는 [Google 로그인 계약](../architecture/GOOGLE_LOGIN_CONTRACT.md#포맷-후-로컬-복구oauth-서명-식별-2026-11-07)을 따른다.

복구 문서는 docs/local-development-recovery의7be30088에서 보관했고 dev/main 통합 지점은86e53e11이다. 현재 로컬 main/dev와 저장된 origin/main·origin/dev 참조가 일치한다. 2026-11-08 원격 직접 조회는 네트워크 제한으로 확인하지 못했으므로 원격 최신성을 재검증했다고 표시하지 않는다. 미추적 devtools_options.yaml은 보존한다. 기존 v2.0.0 게시도 완료 이력이며 재실행 대상이 아니다.

## 유효 후속·다음 행동

1. **웹소켓 검토 예정·현재 미착수:** 현재는 Issue17 Native 구현 기획·설계이며 웹소켓은 별도다. 후속 논의 기준은 [설계37 §37.50](../backend-migration/37-raid-scheduling-and-multi-raid-planning.md)이며 대상·시점·화면 표현부터 협의한다. 다른 기기 탈퇴/방 해체에 따른 참가 목록·내 계정 참가 표시·열린 상세 갱신 요구를 포함한다. 이벤트/HTTP·구독 계약이나 구현 범위를 이번에 확정하지 않는다.
2. **새 release 키 전환·자동 게시 검증:** 추가 기능 개발과 개발 로컬 테스트를 모두 마친 뒤 운영 APK 게시 준비 시 진행한다. 기존 Secret 키 회수 대신 새 키 생성·백업 후 서명 통일이 사용자 결정이다. 지금 키 생성·Secret/CI/OAuth 변경·수동 Actions 시험을 진행하거나 개발 재개 조건으로 요구하지 않는다. 실행 순서·백업 안내와 사본 접근 확인 조건은 [릴리즈 계약 B-1](../architecture/GITHUB_ANDROID_RELEASE_PIPELINE.md#release-key-backup)을 따른다. 실제 게시 버전은 미정이며 게시 자체는 별도 지시가 필요하다.
3. **Backend 백업·회신/기록 완료:** [최종 인계](https://github.com/heo0328/lostparty-backend/issues/46#issuecomment-6706731221) 기준 로컬 고정자료는 사용자 보관 보고, 운영 기준본은 온라인 생성·PC 내장 SSD 전송·파일 무결성 확인 및 Backend 문서 게시 완료다. 로컬 DB dump는 사용자 제외, 외장 매체 사본은 미확인, 실제 DB/서비스 복원·정기 자동화는 미실행이다. 추가 Native 구현·반복 수용/로그인 시험 요청은 없다. Issue46은 OPEN 유지하며 다음은 사용자 파일 보관과 이후 관련 변경 시 Backend의 필요한 최신 사본 안내다. 복원 시험·정기 자동화를 개발 재개 선행 조건으로 추가하지 않는다.
4. **그 밖의 차후 수정안:** [DETAIL_IMPROVEMENTS](../product/DETAIL_IMPROVEMENTS.md)의 확정/보류/미채택 상태를 따른다. 이번 문서 정리를 별도 제품 개선·전면 기술 진단의 착수 승인으로 사용하지 않는다.

## Issue 종료 준비 — 게시·재조회 완료 (2026-11-08)

- [Issue34 최신화 회신](https://github.com/heo0328/lostparty-backend/issues/34#issuecomment-6718443740): 양측 v2.0.0 배포/게시 완료로 과거 통합·게시 대기를 교체했다. 운영 전체 인수 미확인·다음 서명 전환은 별도 후속이다.
- [Issue38 최신화 회신](https://github.com/heo0328/lostparty-backend/issues/38#issuecomment-6718445004): 양측 구현·검증·로컬 사용자 인수와 후속 운영/Native 게시를 반영했다. 원요청 종료 가능이다.
- [Issue46 최신화 회신](https://github.com/heo0328/lostparty-backend/issues/46#issuecomment-6718450091): 합의한 요청 완료로 체크리스트·다음 담당을 교체했다. 상세 백업 정보는 재게시하지 않고 기존 최종 회신을 참조한다. 원요청 종료 가능이다.
