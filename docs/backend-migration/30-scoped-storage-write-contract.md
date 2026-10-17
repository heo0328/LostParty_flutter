# 회원·환경별 캐시 저장과 쓰기 경로 분리 계약

> 현재 기준 정정(2026-10-16): 현재 개발환경·개발자료로 개발을 계속한다. 별도 빈 환경/저장공간·기초 재인수는 선행 조건이 아니다. 베타 모집 후 베타 시작 직전에 DB 내용만 비우며 구현·환경을 다시 만들지 않는다. D의 별도 로컬 DB/guest 키 연결은 원래 연결로 복구했다. 기존 회원별 격리·기능/UX는 유지한다. [정정 회신](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6207542428)·[현재 작업](../project/NEXT_WORK.md).

> 2026-10-16 정책 정정: 현재는 베타 이전 개발 단계다. 개발 자료는 베타 전 전체 초기화하며 구 Firebase/테스트 자료 승계·보존형 전환은 요구하지 않는다. 아래 구 기기자료 경로/schema13·정수ID 호환 보존은 당시 C 구현 기록이며 신규 기능의 필수조건에서 제외한다. 새 회원 scoped 저장/자동실행·영속대기·재로그인/기기 간 복원은 유지하고 구 실행 의존 정리는 별도 D로 진행한다. [정책09 D08](09-migration-decisions.md#d08-개발--베타--운영-데이터-수명--사용자-확정-2026-10-16)/[NEXT_WORK](../project/NEXT_WORK.md). 실제 자료 삭제나 코드 제거는 아직 실행하지 않았다.

## C 화면 소비·복원 경계 (2026-10-16)

scoped schema3/8테이블·기기 schema13과 P2 원본7027f0b는 변경하지 않았다. runtime.loadMemberRoster는 회원/session/readGeneration별 전체 준비 flight를 B/목록 복원이 공유하고 각 소비자의 key/settings guard는 공유 결과 전후 독립 검사한다. 최초 소비자의 키 상태를 다른 소비자의 권한으로 사용하지 않는다. restoreCharacterPersonalData는 단일 fresh profile을 양역할 및 P2 설정 관찰로 반영하며 각 저장소의 fence/CAS를 그대로 적용한다. 여러 저장소 전체를 묶은 새 원자 transaction이라고 해석하지 않는다.

readCachedRoleBuild는 현재 같은 scope/등록/소유수명의 비퇴역 캐릭터 표시 자료만 반환한다. fromCache=true는 fresh write plan/ACK가 아니며 수집 전은 null이다. MemberAccountViewModel은 캐시→현재 전체 roster→개인정보 순으로 복원하고 B 완료 후 현재값을 다시 읽되 Armory를 재실행하지 않는다. 편집은 fresh plan·로컬 원자 초안/명령·서버 전송 순이며 pending/충돌을 유지한다. 회원/session/readGeneration 변경과 app dispose는 늦은 화면 반영/ACK를 차단한다.

BackendMemberAccount는 app 소유이고 페이지는 dispose하지 않는다. ON 로그인 회원 주목록/기존 기기 자료 경로 분리·키 없음/OFF에서도 서버요약 복원·상세 원본 없음·선호/표시/count·진행/재시도 UI를 연결했다. 최종 전체1524PASS/lib-test 분석0, 실제 환경 인수는 [NEXT_WORK](../project/NEXT_WORK.md)다. 아래 A1/A2/B ‘UI 미연결/다음 C’는 당시 이력이다.

B 소비 경계(2026-10-16): source/controller가 A1/P2 저장 plan에 회원/session·키/실행·runtime.readGeneration guard를 넘긴다. 원정대 변경 요청의 invalidateReads는 row 변경 전에도 세대를 올려 늦은 자동 저장을 막는다. 로컬 commit 완료 통지와 이후 업로드/취소를 구분하며 서버 pending 재전송은 Armory를 부르지 않는다. schema3/8테이블과 원본7027f0b는 불변이다. B 실행/다음 C 연결 계약은 [설계23 상단](23-nice-group-auto-refresh-design.md)을 따른다.

## A2 개인설정·표시 저장 구현 (2026-10-16)

소비 계약은 Backend **7027f0b690e1c232fafc5d09faa9d6c169c99962**, [정확한 원본](contracts/issue8-7027f0b.openapi.yaml), SHA256 `fe78017938fc4c3ac7c66e5b6f7a756b676f381abd0d21cf4fb0786afeb765c1`이다. 기존 모든 paths/역할 schema는 불변, PersonalProfileOut.preferences의 참조만 실제 PersonalPreferences로 교체·옛 가상 schema 제거, 새5schema·2paths/3operations·profile policy 변경을 대조했다. 현재 profile parser는 P2 실제5필드를 읽는다. 아래 A1의 가상값 전용 경계는 당시 원본 소비 이력이다.

scoped DB **schema3/8테이블**은 schema2의6테이블과 기존행을 보존하고 아래2개만 추가한다. schema1→3 직접 증분도 지원한다. 기존 기기 schema13/구 자료 이관·삭제는 없다.

| 테이블 | 키·관계·수명 |
|---|---|
| ScopedSettingRecords | scope+kind+canonical target+ownership_revision PK/row CAS. preferences 대상은 character UUID, presentation은 account UUID. same-scope account FK와 nullable account+character 복합 FK, kind/target/양의revision 제약 |
| ScopedSettingCommands | 같은 설정기록 FK/자원별 활성 명령1개·등록 FK. 원래 registration ID/key/body/최초발송시각/고정deadline·ready/retry/conflict/review/blocked 보존. 설정종류는 키에 포함되며 역할 outbox와 분리 |

`ScopedSettingsRepository`는 fresh P2 GET과 현재 등록 metadata·소유수명을 대조해 전용 plan을 발급한다. preferences만 complete canonical roster/현재 캐릭터·수명/usable을 요구한다. presentation count는 캐릭터 선택이 아니므로 **metadata만으로 비메인·suspect 포함 계정에 저장 가능**하다. transaction 전후 session/scope/등록 및 필요한 roster/character row fence·외부 guard, 설정 row CAS를 검사한다. 로컬 초안+미발송 명령 원자 저장/중도 실패 rollback·발송 명령 불변/후속 초안 분리·ACK 해당 명령만 확정은 A1과 같은 원칙이다.

P2 defaults/no-op은 version1/saved_at=null이며, custom 값 저장/기본 복귀는 단조 version/UTC시각을 보존한다. GET은 pending을 만들지 않는다. 같은 소유수명 새 등록에서는 확정 설정을 GET으로 복원하지만 옛 명령을 새 경로에 이식하지 않는다. 원정대 label 변경 후 원래 발송 명령의 replay ACK는 과거 registration_version일 수 있으므로 해당 명령 검증 후 현재 GET으로 다시 읽는다. 미발송 오래된 version/등록 fence를 자동 보정하지 않는다. 응답 유실·재실행은 같은 key/body, 429 수신시각 deadline, 첫발송24시간 상한/시계 역행·충돌은 명시 검토/서버값 수용을 사용한다.

캐시 read는 같은 회원/환경의 현재 캐시 등록·소유수명에 한정하고 `fromCache=true`인 표시 관찰만 반환한다. 미수집은 null이며 기본 설정 복원 성공을 만들지 않는다. 캐시로 쓰기 plan을 발급하지 않고 새 저장 전 fresh GET이 필요하다. 세션 전환/폐기·runtime close는 늦은 반영을 차단한다. runtime 명시 prepare/readCached/read/save/sync/useServer만 연결하며 자동실행/UI 전환은 하지 않는다.

순수 `projectScopedAccountPresentation`은 한 원정대의 명시 복원/대기 preferences를 입력받아 visible 필터→현재대표→rank(null 후순위)→아이템레벨 내림차순(null 후순위)→이름→UUID 정렬 후 저장 count로 제한한다. hidden 대표 강제표시·rank 재번호화·활동 대상 축소·이름 기반 연결은 없다. 개별 rank ACK를 전체 정렬 완료로 처리하지 않는다.

최종 전체1479PASS(신규47)/lib·test 분석0. 이전 A1/S1~S3·schema1/2 실제 임시파일 migration·모의 HTTP/FK/원자성/회원·소유수명/등록해제·재등록/지연 ACK/멱등/429/24시간을 검증했다. 실DB/API·기기 인수와 구분하며 다음은 [NEXT_WORK](../project/NEXT_WORK.md)의 B 자동실행이다.

## A1 역할 저장·전송 대기 구현 (2026-10-16)

현재 별도 scoped DB는 **schema2**다. 아래 S1 당시 schema1/4테이블 기록은 이력이며, 기존4테이블/행 위에 ScopedRoleRecords/ScopedRoleCommands 두 테이블만 증분 추가한다. 전자는 scope+character UUID+ownership_revision+role PK, scope+account+character 복합 FK/row CAS/payload다. 부모 캐릭터의 동일 복합키 고유 index를 먼저 준비한다. 후자는 같은 역할기록 FK와 자원별 활성 명령1개·UUIDv4 key/불변 body·최초 발송시각/고정 retry deadline/상태를 가진다. 기기 공용 AccountDatabase schema13은 변경하지 않는다.

`ScopedRoleRepository`는 fresh P1 profile과 현재 complete canonical roster의 등록/소유·캐릭터 수명을 대조해 전용 plan을 발급한다. 모든 저장 transaction 전후에 scope/session/소유 관찰/row version·발급 당시 외부 키/run guard를 다시 검사한다. 분석 결과와 미발송 outbox 원자 저장, 발송 후 새 초안 분리, 정확한 명령 ACK·다른 역할 독립, 다른 회원 지연 결과 차단을 적용한다. 과거 ACK는 현재 서버값으로 간주하지 않으며 GET으로 확인한다. conflict/review/blocked는 자동 expected-version 보정 없이 명시 서버값 수용만 허용한다.

`ScopedRoleSync`/runtime은 명시 prepare/save/read/sync API만 제공한다. 재실행 복구·429 수신시각 deadline·첫발송24시간 보수 상한·같은 자원 진행 요청 공유를 적용한다. P1 strict DTO/nullable·UTC·무결성4상태와 가상preferences를 지키며 미래 P2 실제설정을 아직 복원하지 않는다. 기본 OFF·기존 UI 흐름/DB0호출은 유지한다. 자동 상세 조회/controller·화면은 후속이다.

최종 전체1432PASS/분석0, migration 실제 기존행·FK/rollback·동시 초안/지연 ACK·재시작/멱등·version 경합을 포함한다. [설계23 상단](23-nice-group-auto-refresh-design.md)/[NEXT_WORK](../project/NEXT_WORK.md) 참조. P2 원본7027f0b 도착 후 다음 A2에서 preferences 호환 변경과 개인설정/원정대표시 저장을 별도 연결한다.

P1 최신 원본(2026-10-15): Backend6e4f625의 [정확한 OpenAPI snapshot](contracts/issue8-6e4f625.openapi.yaml)과 제공 범위/strict·가상preferences를 확인했다. 다음 Flutter A1은 이 P1의 역할요약 GET/PUT·scoped 상세/서버요약·영속 대기만 연결하며 P2 개인설정 원본은 별도다. 검토/해시·후속 인계는 [설계23 상단](23-nice-group-auto-refresh-design.md)을 따른다. 기존 S1~S3 캐시/기기자료 보존·자동 갱신 OFF 예외를 변경하지 않는다.

## 후속 범위 확정 — 역할 요약 복원·개인설정·저장 대기

2026-10-15 사용자 선택으로 [설계23 상단](23-nice-group-auto-refresh-design.md)의 서버 최소 복원/로컬 상세 원본, 로컬 우선 반영·서버 저장 대기, 회원별 단일 주목록·기존 기기 자료 별도 접근을 확정했다. 아래 S1~S3 당시의 ‘기존 주목록 미교체/새 서버 API 요청 없음’은 그 단계의 범위이며 이번 새 복원 범위를 금지하는 정책이 아니다. canonical scope/UUID 격리·기존 자료 자동 이관/삭제 금지는 유지한다.

후속 저장 설계에는 scoped 역할/개인설정과 영속 전송 대기를 포함한다. payload/서버 예상version·멱등/수명 검증과 local snapshot+대기의 원자 저장, 재실행·다른 회원/기기 충돌을 계약으로 먼저 정한다. 새 endpoint/DDL·최종 wire·migration 버전은 Backend 계약과 실제 구현 단계에서 확정하며 이번 문서 선택으로 이미 구현됐다고 표시하지 않는다. 활동 활성 전원 상세 검사와 나이스단 OFF 예외는 설계23 최신 규칙을 따른다.

## S3b 실행 DI·현재 상태/이력 화면 구현 (2026-10-15)

사용자 `진행합니다` 승인 범위에서 BackendAccountLifecycle app 소유 binding과 실제 Router/서버 패널을 연결했다. 시작 설정 `BACKEND_LIFECYCLE_READS_ENABLED`는 기본false이며 OFF에는 기존 V1 상세/전투력 흐름과 새 DB/V2 0호출을 유지한다. ON의 기존 `/account/server/:registrationId`는 V2 현재 상태, `/power`는 기존 V1 전투력 보조 화면, `/account/character-retirements`는 회원별 이력이다. 현재 상태 GET 실패를 V1 성공/빈 목록으로 대체하지 않는다.

화면은 현재 canonical/preview·이전 관찰/metadata-only·확인 시각·소유/설정/캐릭터 이상·실패/대기를 구분한다. 등록0개에도 이력 진입이 가능하며 명시 더 보기·처음부터 재조회만 제공한다. 이력은 나가기/회원 전환 때 폐기하고 DB를 열지 않는다. 계정 변경 요청 시작은 조회 최신성을 무효화하고 추가 조회를 막으며 종료 후 metadata/선택 roster를 재조회한다. 결과가 불확실한 기존 쓰기 요청은 읽기 성공만으로 확정하지 않는다. 늦은 다른 회원 callback과 dispose 결과를 차단한다.

검증은 **최종 전체1394PASS(선행1382+신규12)/lib·test분석0**, format/diffcheck다. 초기1393PASS 후 인증 완료 callback이 이전 진행 GET에 합류하지 않도록 보완·1경계를 추가해 최종1394PASS로 확정했다. 실행별 수치를 합산하지 않는다. 로그 `.dart_tool/scoped-ui-final-tests.log`(67초)/`scoped-ui-final-analyze.log`(8.3초). 회신은 NEXT_WORK/DEV_LOG에서 추적한다. 모의 HTTP/SQLite 및 자동 검증이며 기본 디스크 경로·실제 서버·실기기 인수와 구분한다. 기존 로컬 빌드/역할·주간 자료/schema13·키/인증·V1 전투력은 유지한다. 현재 저장된 대표/활동 정보는 읽기 표시만 하며 왕관 변경/활동 선택·파티·빌드 자동갱신은 후속이다. 실서버 ON은 여전히 아래 §8.6 준비/승인 조건을 따른다.

## S3a runtime/controller 구현 완료 (2026-10-15)

[결과 회신6189141597](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6189141597) 게시·원격 본문 일치 확인. Backend에 새 수정/반복시험·DB전환/배포를 요청하지 않았다.

사용자 `다음 작업을 진행합니다` 승인으로 ScopedAccountRuntime/ScopedAccountViewModel과 경계 검증을 구현했다. **최종 전체1382PASS(선행1353+신규29)/lib·test분석0**, format/diffcheck. 초기 신규27개 포함 S1/S2 연계98PASS 후 분석의 미사용/스타일10건을 정리하고 서로 다른 원정대 queue·외부 token 무효화2경계를 보강해 전체1382PASS로 확정했다. 두 실행은 합산하지 않는다. 로그 `.dart_tool/scoped-runtime-final-tests.log`(79초)/`scoped-runtime-final-analyze.log`. 최종 검증 뒤 기능코드 변경 없음.

- `data/scoped_account_runtime.dart`: 명시 DB factory·별도 drift_flutter 이름 lost_party_server_cache 준비, enabled 기본false·guest/비활성0호출·lazy 단일 connection. runtime이 factory connection을 소유하면 진행 중 작업 정리 뒤 한 번 close하고, ownsDatabase=false의 외부 connection·공용 Dio/세션은 닫지 않는다. HTTP의 즉시 물리 취소가 아니라 session/token의 논리 취소이며 close는 이미 진행 중인 작업 종료를 기다린다. factory 실패는 명시 재시도 가능하고 DB 삭제/재생성은 없다.
- 같은 readSession/accountApi/공유 ServerAccountReadRepository만 받으며 실제 URI/불변 base path·release HTTPS/debug 허용 HTTP를 확인한다. 중복 슬래시 축약으로 의도한 prefix와 달라지는 설정은 거절한다. 기존 auth/key origin 저장 정책은 바꾸지 않았다.
- S2 client는 선택적 공용 Repository 주입·shareInFlight·성공 typed metadata 반환만 확장했다. 초기 진행 중 V1 GET 공유와 명시 새 GET·count/대표 요약을 보존한다. S1에는 invalidateReads()만 공개해 현재 관찰은 남기고 token/receipt를 즉시 무효화한다. FK/CAS/스키마·strict DTO/권한 정책을 복제하거나 완화하지 않았다.
- `presentation/viewmodels/scoped_account_view_model.dart`: 명시 initialize 이후 세션별 초기화/캐시 hydrate·서버 empty 구분, 등록 metadata와 선택 roster의 queue/동일 작업 공유·명시 무효화/현재 선택 재조회, canonical receipt와 preview 성공 stamp, 오류/이전 관찰/대기 deadline을 구현했다. 미선택 원정대 전체나 이력·키/provider를 자동 조회하지 않는다. 세션 listener의 같은회원 새세대/다른회원/로그아웃은 rows/selection/history/error/timer를 동기 비우고 늦은 결과를 막는다. ViewModel dispose와 runtime close의 소유는 분리했다.
- 이력은 open/restart/loadMore/close의 명시 한 페이지이며 DB를 열지 않는다. close/회원 전환은 rows/continuation을 버리고, 소비된 continuation의 실패는 이전 prefix를 보존하되 needsRestart로 표시한다. deadline은 수신 시 고정하고 timer는 표시만 갱신한다. 서버 ACK·기기 삭제/영속 이력/무제한 자동 수집은 없다.
- 신규 `scoped_account_runtime_test.dart`29개: 비활성/guest·초기 GET 공유/재진입·typed count·디스크 empty/서버 empty·canonical/preview·부분 실패/등록 제거·metadata-roster 경합/서로 다른 account queue·현재 세션 외부 token 충돌·같은/다른회원/지연 factory·URI/환경·history restart/late/deadline·DB 실패/소유 close·실제 임시 SQLite 재실행 stale 관찰을 확인했다. 직접 DB/모의 HTTP 검증이며 실기기 기본 경로·실서버 인수가 아니다.

새로 가능: S3b에서 단일 runtime/state에 현재 서버 원정대/이력 화면과 명시 관리·인증 callback을 연결할 수 있다. 보존 확인: 전체 기존 회귀·AccountDatabase schema13/양역할·V1/인증/키·전투력·기존 실행 DI/Router/화면 불변(이번 변경 기준). 미확인: gated 실행 주입·drift_flutter 실제 기기 경로·서버 V2/실provider·장비 소유/활동/왕관 인수. Backend DB0007/실행API 전환·실자료 정리·배포/proof/퇴역 보류 해제는 없다. 현재 feature/scoped-account-cache/cc6a0b0 유지·신규/이전 변경 미커밋·미push·dev미반영이다. 다음은 S3b다.

## S3 실행 연결 설계 확정 (2026-10-15)

[설계 회신6187560938](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6187560938) 게시·원격 본문 일치 확인. 상세는 §8, 다음 구현은 NEXT_WORK다.

사용자 `설계 진행` 승인으로 실제 BackendApp/Router·인증·기존 목록/전투력·S1/S2 코드를 대조해 §8을 확정했다. **이번은 문서 설계이며 기능코드/DDL/실행 설정을 수정하지 않았다.** 다음 단일 구현은 S3a runtime/controller와 주입 가능한 연결 경계다. 이어지는 S3b에서 서버 영역 UI/Router를 연결한다. 기존 앱 주목록/빌드 자동갱신·활동/왕관은 제외한다. 서버 DB0007/실행 API 전환은 별도 승인·준비가 필요하며 S3a/S3b 코드·모의검증을 막지 않는다. 현재 필요한 새 제품 결정이나 Backend API 변경 요청은 없다.

## S2 조회 adapter 구현 상태 (2026-10-15)

결과 [Issue8 회신6187403079](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6187403079) 게시·원격 본문 일치 확인. 현재 실행 계획은 [NEXT_WORK](../project/NEXT_WORK.md)다.

사용자 `연결 진행합니다` 승인으로 S1 직접 후속을 같은 feature/scoped-account-cache에서 구현했다. **신규42개 포함 전체1353PASS/lib·test분석0**, format/diffcheck. 최종 로그 `.dart_tool/lifecycle-final-tests.log`/`lifecycle-final-analyze.log`. 초기33개 중 fixture cascade 오류2개를 수정해33PASS 후 오류·세션/ID 경계를 보강해42PASS, 최종 전체1353PASS다. 서로 합산하지 않는다.

원본은 Backend **c91af2e003877daacb833aaa0c109eae11b72816**, [로컬 OpenAPI snapshot](contracts/issue8-c91af2e.openapi.json)과 `server_character_lifecycle.dart`/`server_character_lifecycle_client.dart`가 기준이다. API 자체는 Bearer/no-store 읽기이며 기존 Dio transport의 인증복구/오류/대기 metadata를 재사용한다. GET body/쓰기·provider 직접 호출은 없다.

- 새4DTO의 모든 속성/nullable·enum/UUID/UTC·positive revision을 검사한다. 기존 SettingsOut은 재사용하며 optional selection_complete=true를 존중하고 비교 전에 default/UTC를 정규화한다. settings_version은 envelope가 아니라 settings 내부다.
- 먼저 V1 등록 전체 목록을 S1에 적용하고 roster token을 발급한다. V2 모든 페이지의 등록/account/main/소유/roster/전체 settings를 현재 metadata와 대조한다. 차이는 REVISION_CONFLICT, 페이지끼리 차이는 CURSOR_STALE로 거절하고 재조회가 필요하다. label은 검증된 등록 metadata에서만 얻는다. 같은 등록/캐릭터 중복·서버/이름 중복·반복/빈 cursor·200명 초과/부분 실패는 roster를 저장하지 않는다.
- V1 등록의 미인증 roster_revision=null과 V2 양수 revision은 [service.reg_out](https://github.com/heo0328/lostparty-backend/blob/c91af2e003877daacb833aaa0c109eae11b72816/app/game_accounts/service.py), [lifecycle_reads.characters](https://github.com/heo0328/lostparty-backend/blob/c91af2e003877daacb833aaa0c109eae11b72816/app/game_accounts/lifecycle_reads.py)를 대조했다. canonical account가 없는 preview에 한해서 V2와 같은 registration.version을 generation으로 매핑한다. canonical account가 있는데 revision이 누락되면 INCOMPLETE_METADATA로 거절한다. 출처 없는 null을 0/1/active로 채우지 않는다.
- canonical 관찰은 실제 UUID/account/lifecycle/usable·profile로 S1에 적용한다. preview/소유상실은 canonical ID/revision=null·usable=false이며 preview 표시 payload에 보존한다. fresh power는 유지할 수 있다. power 값/시각은 구조 revision 없이 달라질 수 있으므로 페이지 간 동일성을 요구하지 않는다. 같은 이름 새 ID는 새 행이며 미관찰 옛 ID는 보존 관찰에만 남는다.
- 서버 환경/base path·동일 session 객체/회원세대·scope와 S1 token/CAS를 함께 검사한다. 늦은 응답·동일회원 재로그인·다른 회원/환경·dispose/새 요청에 의해 이전 적용은 차단한다. cache receipt는 현재 관찰의 신선도이며 서버의 사용 허가가 아니다.
- 퇴역 이력은 명시 호출당 최대50개 한 페이지만 반환한다. continuation은 client/회원/세션/환경/history revision·순서에 묶인 일회용 opaque 객체다. 새 첫 페이지 조회가 이전 순회를 무효화하며 중복 history ID/cursor·revision 변경을 거절한다. 연속 순회의 중복 검사용 메모리는10000건으로 제한하고 초과 시 HISTORY_READ_LIMIT를 반환한다. 이는 서버 보관기간/이력 삭제 정책이 아니다. 이력의 영속 저장·기기자료 삭제/ACK/무제한 자동 수집은 없다.

보존 검증: V1/인증/키·기존 캐시/DB/역할·주간 정상 흐름 전체 회귀, 401 단일 refresh·서버409/403/404/429의 code/status/request ID/retry metadata 전달·네트워크/부분 실패 보존. 메모리 SQLite/모의 HTTP이며 실제 V2 서버 호출 결과가 아니다. 현재 Backend 실제DB0007/실행 API 미전환이므로 런타임 DI/Router·기본 디스크캐시/화면·실장비/자료/배포를 변경하지 않았다. 다음 S3는 실행 연결 설계다. S1/인증/설계와 이번 S2 모두 미커밋·미push·dev미반영이다.

## S1 현재 구현 상태 (2026-10-15)

최종 완료: 신규29개 경계 포함 **전체1311PASS/lib·test분석0**, format/diffcheck. [S1 결과 회신6187076006](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6187076006) 게시·본문 일치 확인. 로그는 `.dart_tool/scoped-cache-final-tests.log`/`scoped-cache-final-analyze.log`. 초기에표적25PASS→추가경계전체1310PASS→preview관찰보존보완후최종1311PASS이며서로누적하지않는다. 메모리DB/모의세션시험이며 실서버/실기기/API소비 검증이 아니다. 현재 feature/scoped-account-cache 미커밋·미push·dev미반영, 다음은 S2 조회 adapter다.

사용자 구현 승인으로 feature/scoped-account-cache에서 S1을 구현했다. 기존 auth 브랜치와 같은 cc6a0b0에서 분기하고 이전 인증/설계 미커밋·Rules/tools를 그대로 보존했다. 새 domain normalized 모델·ScopedAccountCacheDatabase(schema1/4테이블/생성물)·ScopedCharacterCacheRepository·메모리 경계 시험을 추가했다. 실행 DI/Router/네트워크·디스크 기본 연결과 기존 schema13은 변경하지 않았다. 아래 ‘설계 전용’은 문서 최초 작성 시점이며 현재 구간은 이 절이 우선이다.

- 환경/회원·typed ref, 불변 요청 token·조회순서/CAS, 전체 등록/roster 원자 적용, composite FK/RESTRICT, metadata_only/complete·미관찰 보존, 런타임 receipt/회원·동일회원 새세션·환경 전환·dispose 차단을 구현했다.
- 소유 revision이 가려진 관찰이 와도 이전 revision 하한값을 잃지 않도록 head에 소유/roster/settings epoch별 high-water metadata를 보존한다. 등록 목록만 새로 수신했을 때도 이 하한값을 갱신하며 complete roster payload와 일부 설정을 혼합하지 않는다. 새 소유 수명의 settings version 초기화와 같은 수명의 후퇴를 구분한다.
- 현재 제품의 개명=신규ID 정책에 따라 같은 캐시 ID의 서버/이름 교체는 거절한다. 새 ID/같은 이름은 새 행이며 과거 행을 남긴다. 같은 ID lifecycle revision 갱신은 제자리 관찰 갱신·퇴역 ID 부활 거절이다. 개인 역할 테이블은 아직 만들지 않았다.
- `readCharacter`는 미관찰 행도 반환할 수 있는 보존 관찰값이다. 현재 roster/receipt를 거치지 않고 해당 값의 usable을 최신 사용 허가로 사용하지 않는다. `readRoster`는 구조가 일치하는 최신 complete 관찰의 표시 payload를 반환하므로 ownership-lost/preview의 fresh 표시값과 소유/사용 자격을 분리한다.
- 내부 모델/fixture는 API DTO가 아니다. L1a6f3d029/185PASS와 L1bc91af2e/별도113·57PASS 게시 회신을 수신했으며 dev/main 미통합·실DB/실행API 미적용 상태다. 다음 S2는 이 원본 계약으로 strict DTO/전체 페이지·오류/coherence adapter를 연결한다.

자동 검증 결과·실제 회신 링크는 아래 S1 완료 기록과 DEV_LOG를 따른다. 기존 사용자 자료를 새 회원에 연결하거나 앱의 현재 캐릭터 목록을 교체한 것으로 보고하지 않는다.

설계 결과는 [Issue8 회신6185868981](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6185868981)으로 게시·원격 본문 일치 확인했다. 기존 L1a/L1b 요청은 유지하며 새 Backend 변경/반복 시험 요청은 없다. 다음은 §6의 S1 격리 저장 기반 구현이다.

2026-10-15. 사용자 `진행`으로 승인한 **설계 전용** 구간이다. [ID 연결29](29-scoped-character-identity-design.md)의 저장 구조·revision·writer 경계를 구체화한다. 기능코드/Drift 생성물·schema13·실제 DB/자료·Router는 변경하지 않는다. feature/account-verification-client/HEAD·origin-dev cc6a0b0를 재확인했고 이전 인증/설계 미커밋과 사용자 Rules/tools는 보존한다. Issue8 최신6185091368의 L1a/L1b 요청은 유효하며 착수/완료 회신은 아직 없다.

## 1. 저장소와 식별자

`AccountDatabase`/`lost_party`(schema13)는 기기 공용 로컬 기능 전용으로 유지한다. 새 서버 캐시는 별도 Drift DB `ScopedAccountCacheDatabase`/`lost_party_server_cache`(초기 schema1)에 둔다. 이 이름은 Flutter 내부 설계이며 Backend endpoint/DDL 제안이 아니다. 기존 DB/테이블명·unique index·정수 PK는 바꾸지 않고 두 DB 사이 FK나 자동 자료 이동을 만들지 않는다.

별도 DB를 택하는 이유는 현재 이름 기반 update/delete와 정수 ID를 받는 공용 Repository가 새 행을 직접 변경할 수 없도록 하기 위해서다. 내부 row PK가 우연히 같아도 상대 저장소의 ID로 전달하지 않는다. 처음부터 API/UI 전체를 새 DB로 교체하지 않고 다음의 타입과 Repository로 경계를 고정한다.

| 타입/키 | 고정 의미 |
|---|---|
| `StorageScope` | 정규화 Backend API base URI + 서버 App user UUID. 게스트 scope를 임의 생성하지 않음 |
| `ScopedCharacterRef` | scope + canonical game_account UUID + character UUID. 이름과 local int PK를 받을 수 없음 |
| `ScopedRegistrationRef` | scope + registration UUID. canonical ID와 별개 |
| `SessionFence` | 프로세스 수명의 runtime ID + session generation + scope epoch. 영속 소유권으로 저장하지 않음 |
| `ReadFence` | 등록/소유/roster/settings revision, 존재하는 경우 lifecycle revision, local aggregate version·request sequence |

환경 키 정규화는 scheme/host 소문자·HTTP80/HTTPS443 기본 포트 생략·빈 경로와 root `/` 동일 처리까지만 한다. root 이외 경로의 대소문자/percent encoding/중복 슬래시/끝 슬래시는 임의 합치거나 decode하지 않는다. query/fragment/userinfo는 거절하고 DNS alias·IP·localhost를 합치지 않는다. 같은 host의 다른 API base path도 다른 환경이다. 비HTTP(S)는 거절하고 HTTP 허용 여부는 기존 debug 설정을 따른다. UUID는 서버 계약에 맞게 검증/소문자화한다. 토큰/키는 환경/식별자 구성요소가 아니다.

이 규칙은 캐시의 scope다. 기존 AuthSessionStore/회원 키 저장소의 origin 정책을 이번에 바꾸거나 모든 인증 환경 분리가 해결됐다고 표시하지 않는다. 서버 URI로부터 actual transport base path를 일관되게 만드는 adapter는 런타임 연결 구간의 확인 항목이다.

## 2. 논리 테이블·제약

아래는 구현 가능한 로컬 저장 계약이며 **새 API wire를 추측하는 표가 아니다.** 서버 nullable/enum/버전 의미는 게시된 원본 DTO에서 검증 후 정규화한다. V1에 없는 필드에 0/1/active를 채워 V2 자료처럼 저장하지 않는다.

| 테이블 | PK/관계 | 최소 저장 필드·제약 |
|---|---|---|
| `CacheScopes` | 내부 scope_id PK, `(environment_key,user_id)` unique | local_version>=1·registration_snapshot_sequence>=0(0은 미수집). 환경과 회원은 생성 후 변경 불가. 토큰·인증키 없음 |
| `CachedRegistrations` | `(scope_id,registration_id)` PK | game_account_id nullable·registration_version>=1, label/is_main, 정규화 preview·미인증 상태, fetched_at·local_version, last_seen_registration_sequence. scope별 현재 snapshot에서 is_main 최대1을 전체 등록 적용 transaction에서 검증. canonical account 연결은 같은 scope의 AccountHead만 참조 |
| `CachedAccountHeads` | `(scope_id,game_account_id)` PK | ownership/roster/settings revision·소유/설정 상태·활동 ID목록/nullable 대표·조회시각, source_contract, snapshot_sequence>=0/local_version>=1·coverage(metadata_only/complete). 서로 다른 응답의 settings 일부 필드를 조합하지 않음 |
| `CachedCharacters` | `(scope_id,character_id)` PK, `(scope_id,game_account_id)`→AccountHeads | game_account_id 생성 후 재할당 금지. 표시 필드/서버 power 관찰·출처시각, nullable lifecycle_state/revision·usable/blocked_reason, last_seen_snapshot_sequence·row_version>=1. 이름은 unique PK/업데이트 대상 탐색 키가 아님 |
| `ScopedBuildSnapshots` (후속 역할 저장) | `(scope_id,character_id,role)` PK, 동일scope Character FK | role=dealer/support, 기존 빌드형식 rawJson/dataVersion·수치/captured_at, source_lifecycle_revision·키version·row_version. 다른 역할은 별도 행. API키/인증정보를 payload에 포함하지 않음 |
| `ScopedCharacterPreferences` (후속 개인설정) | `(scope_id,character_id)` PK, 동일scope Character FK | preferred_role nullable·visibility/order·주간 표기 등 기기 개인설정. 서버 활동 목록·대표를 이 테이블에서 권한으로 결정하지 않음 |

처음 구현할 저장 기반은 **앞의 네 캐시 테이블과 read/apply/CAS**다. 두 개인자료 테이블은 키/수명만 이 계약에서 고정하고 역할 저장/관리 연결 구현 단위에서 추가한다. 초기 schema에 필요 없는 테이블을 선제 생성하지 않는다. 향후 migration은 그 시점의 실제 버전에서 증분으로 작성한다.

Canonical Characters의 같은 scope 내 character_id 중복은 거절한다. game_account_id를 포함한 composite unique/FK를 개인자료가 필요로 할 경우 함께 명시해 계정이 섞이지 않게 한다. scope는 같아도 다른 account로 ID를 이동시키는 UPSERT는 금지한다. 등록 ID의 account 연결 변경은 일반 캐시 갱신으로 이식하지 않고 검증된 새로운 서버 snapshot으로 해당 등록 관계만 갱신한다. 이전 account/개인자료는 재사용/연쇄 삭제하지 않는다.

FK는 새 DB connection마다 활성화하고 composite 관계 위반을 실제 transaction 시험으로 확인한다. scope/account/character FK의 운영자료 제거는 RESTRICT로 두며, 자동 cascade로 빌드를 삭제하는 공개 API를 첫 구간에 만들지 않는다. 현재 shared DB의 FK/고아 문제(DB-03)를 이 변경에 섞어 전역 수리하지 않는다.

## 3. snapshot·revision·수명

- 한 등록의 모든 페이지를 원본 계약대로 수집한 뒤 immutable `ValidatedRosterSnapshot`을 만든다. snapshot의 scope·등록관계·account·ownership/roster/settings revision과 중복 ID/nullable·enum이 모두 검증돼야 한다. 페이지별 DB 반영은 금지한다. V1 조회는29의 앞뒤 등록 대조를 적용하며 V1 자료의 lifecycle revision은 null로 남긴다.
- 등록 전체 목록도 별도 validated snapshot으로 적용한다. scope의 registration_snapshot_sequence를 증가시키고 포함된 등록의 last_seen 값을 동일하게 기록한다. 현재 목록/메인 판정은 두 값이 일치하는 등록에만 적용한다. 목록에서 빠진 등록 row와 그 account/개인자료는 남기되 신규 사용/현재 목록 대상에서 제외한다. 서버 삭제/퇴역이라고 추정하지 않는다.
- 등록 목록에만 등장한 새 account의 FK parent는 coverage=metadata_only/snapshot_sequence=0으로 생성할 수 있다. 이를 빈 원정대 전체 조회 성공으로 취급하지 않는다. 기존 complete head를 등록 요약만으로 부분 덮어쓰지 않고, 현재 등록 revision과 head가 불일치하면 receipt를 무효화한다. 전체 characters 검증 후에만 coverage=complete와 새 snapshot sequence를 함께 적용한다.
- `source_contract`는 원격 계약 SHA/DTO 버전을 뜻한다. 부분 응답/호환 안 되는 버전·출처 없는 legacy server ID는 승격하지 않는다. source fetched_at과 기기가 받은 시각은 각각 저장하며 기기 시각으로 서버 revision을 대신하지 않는다.
- 같은 scope/동일 리소스의 등록/소유/roster/lifecycle revision이 후퇴한 관찰은 적용하지 않는다. settings version은 같은 ownership/configuration 수명 안에서만 비교하며, 새 ownership 수명의 새 설정version을 과거 설정에 덮어 비교하지 않는다. 수명 전환이 검증되면 새 settings snapshot으로 교체하되 기존 개인 빌드는 유지한다. 새 설정인지 확인 불가하면 재조회/보류하고 임의 version 초기화를 하지 않는다. source 계약이 지원하지 않는 revision 비교는 값 생성 대신 미검증으로 남긴다.
- AccountHeads의 `snapshot_sequence`는 로컬 CAS용 증가값이다. 서버 revision과 이름이 비슷해도 의미를 혼용하지 않는다. Character의 last_seen sequence가 현재 head와 다르면 `이번 저장 snapshot에서 미관찰`일 뿐 retired 증거가 아니다. 원본이 명시한 usable/lifecycle 또는 재조회 필요 표시로 신규 사용을 제한하며 빌드/claim을 삭제하지 않는다.
- 서버 settings snapshot은 해당 account의 head와 하나의 검증 묶음으로 교체한다. 대표만 변경한 응답을 근거로 활동 목록을 빈 값으로 덮지 않는다. 향후 대표 성공/replay 후 현재 GET 및 전체설정 version 대조를 통과한 결과로만 일관된 묶음을 적용한다.
- 앱 재시작/회원 재로그인 후 캐시는 과거 관찰값이다. 영속 usable/owned 값만으로 명령을 허용하지 않는다. 런타임의 `ValidationReceipt`(현재 runtime/세션/scope와 적용 local_version 일치)가 없으면 재조회가 필요하다. Receipt는 저장하지 않으며 서버 명령의 최종 권한 검사도 생략하지 않는다.
- logout/환경·회원 전환은 현재 scope의 메모리 receipt·작업/draft를 즉시 무효화한다. 다른 scope 자료를 보여주지 않으며 기존 기기 공용 자료와 과거 scope 캐시는 자동 삭제하지 않는다. 새 회원의 같은 UUID/이름도 별도 scope다. 명시 회원탈퇴/캐시 제거·보관기간 정책은 별도다.
- 새 character ID는 새 공간이며 과거 이름의 build/preference를 가져오지 않는다. **같은 ID의 lifecycle revision 변경은 새 캐릭터 생성과 다르다.** 기존 양 역할 snapshot을 보존하고 source revision 불일치로 재검증 대상으로 표시한다. suspect/소유상실 역시 자동 개인자료 삭제 사유가 아니다.

## 4. 저장 API와 transaction 순서

새 `ScopedCharacterCacheRepository`는 typed scope/ref를 필수로 받는다. 숨겨진 전역 currentUser나 이름으로 대상을 보충하지 않는다. 예상 내부 API는 `readScope`, `readRegistration`, `readCharacter(ref)`, `applyRegistrationSnapshot(plan)`, `applyRosterSnapshot(plan)`이다. `bindLocalId`/`markOwned`/`deleteByName`은 제공하지 않는다. 화면에서 raw table/DB executor에 접근하지 않는다.

쓰기 계획은 scope/session fence·관찰 revision·expected local_version·request sequence·완성된 normalized snapshot으로 구성한다. 외부 네트워크는 transaction 전에 끝낸다.

1. service가 scope별 조회 sequence를 발급하고 현재 session fence와 local_version을 캡처한다. 새 명시 조회가 시작되면 이전 조회의 적용 자격을 무효화한다. 초기 공유 GET은 실제 동일 요청의 소비자에만 같은 sequence를 사용한다.
2. 원본 DTO 전체 페이지를 검증한다. scope 변경/등록 삭제·revision 충돌/유효하지 않은 응답은 적용 계획을 만들지 않는다. 실패를 빈 snapshot으로 변환하지 않는다.
3. scope별 직렬 apply queue에서 현재 session/scope·마지막 조회 sequence·expected local_version을 확인한다. 다른 refresh가 먼저 적용했으면 stale 계획을 거절한다. CAS 충돌을 최신 version으로 바꿔 자동 덮어쓰지 않는다.
4. DB transaction 안에서 local_version과 불변 ID/account 관계·FK를 다시 확인한다. 새 account/character는 같은 scope로 생성, 같은 ID의 허용 필드만 갱신한다. head+전체 character 관찰/등록관계+local_version 증가를 원자 반영한다. 이름별 UPDATE/DELETE·서버가 보내지 않은 row의 파괴 삭제는 없다.
5. 비동기 작업이 끝난 뒤 transaction callback 반환 직전에도 session fence를 검사한다. 불일치가 관찰되면 예외로 rollback한다. 성공 후 현재 receipt/local_version 일치를 다시 확인한 결과만 UI/후속 쓰기에 노출한다. 부분 cache를 성공 상태로 표시하지 않는다.
6. 캐시가 적용됐어도 서버/기기 사이 원자성은 없다. 서버가 이후 소유/상태를 바꿀 수 있으므로 실제 명령은 최신 서버 revision/권한 검증을 계속 요구한다.

CAS 기준은 등록 전체 목록에는 scope.local_version, 원정대 적용에는 해당 등록 local_version/현재 등록목록 sequence와 account head.local_version이다. 존재하지 않는 head는 예상값 absent로 비교한다. 서버 원문 revision·로컬 조회 request sequence·DB row version은 각각 검사하고 서로 대용하지 않는다. 초기 header만 있는 상태나 실패한 재조회는 신규 자격 receipt를 발급하지 않는다.

세션 전환과 SQLite COMMIT을 하나의 원자 연산이라고 주장하지 않는다. 마지막 fence 검사 이후 COMMIT과 세션 변경이 경합하면 이전 scope의 캐시 transaction이 먼저 완료될 수 있다. **새 scope에 쓰거나 새 회원 화면에 노출하지 않으며 receipt는 폐기**한다. 전환이 commit 전 검사에 먼저 관찰된 경우 rollback0, 이미 완료된 이전 scope transaction은 삭제로 되돌리지 않는다. 이 순서와 dispose/새 runtime은 경계 시험으로 고정한다. 현재 auto-refresh의 ‘늦은 개인 빌드 저장 차단’은 향후 역할 writer에서 별도 fence로 검증하며 metadata cache의 이 설명으로 완화하지 않는다.

## 5. 실제 writer별 분리

| 현재 writer/소비자 | 보존할 기존 경로 | 새 서버 자료 경로 |
|---|---|---|
| `LocalAccountDataSource.saveCharacterProfile` | shared DB의 기존 메인 계정/이름 update | Scoped ref와 검증한 응답 대상/서버 관찰로 Character cache 갱신. 함수를 그대로 호출하지 않음 |
| DB `saveMainAccountSnapshot`/`applyRosterSummarySync`, CharacterSummarySyncService | 계정 내 이름 대조·missing 표시, 기존 guest/local UX | 완성된 서버 ID snapshot만 새 DB에 적용. ‘이름 재출현→missing 해제’를 서버 lifecycle 해제로 변환하지 않음 |
| `bindServerIdentity`/`updateServerOwnershipStatuses` | 기존 계약·serverMismatch 시험 보존 | 기존 DB 호출 없음. 서버 소유 관찰값만 캐시하고 현재 receipt/최종 서버 명령으로 자격 확인 |
| `AccountRepositoryImpl.create/commitCharacterBuildDraft` 및 DB role 저장 | 기존 int characterId·역할 snapshot/선호 수치 보호 | 순수 분석/역할 정책은 재사용하되 별도 Scoped draft/ref/fence를 받는 writer 필요. 이름 기반 commit/기존 int-ID에 주입 금지 |
| `CharacterAutoRefreshCoordinator`/startup orchestrator | 기존 int ID job/cache와 generation 동작 | 원래 job map에 서버 ID를 가짜 int로 넣지 않음. 새 job key=(scope,character UUID), read fence/키version/설정 실행 snapshot·중단을 새 adapter에서 검증. 자동 실행은 아직 연결하지 않음 |
| CharacterManagementViewModel | 기존 로컬 visibility/순서/대표 저장·선택 | 서버 활동/대표는 서버 명령으로 저장. 새 서버 draft는 scope/등록/settings version을 캡처하고 개인표시와 서버 성공을 혼동하지 않음. 기존 optional gateway를 억지 주입하지 않음 |
| `ServerCombatPowerViewModel.powerFor/refreshForLocal` | 현재 기기 로컬 표시 UX를 이번에 바꾸지 않음 | 새 서버 카드/ref에는 scope/ID 관찰만 사용. 이름 overlay를 신원·새 build/이력값의 근거로 사용하지 않음 |
| `deleteMissingCharacter`/`deleteAccount`, 주간 표기/과거 party 자료 | 기존 삭제·표기 계약은 별도 DB에 보존 | 최초 Scoped store에는 퇴역/개인자료 purge API 없음. 미래 이력/정리 적용은 정확한 scope/ID/수명·명시 종속삭제·적용 ledger와 함께 별도 구현 |

역할 저장을 연결할 때는 기존 CharacterBuildRolePolicy/무결성 분석 결과를 재사용한다. 역할 불명/파싱 실패는 양 역할·선호를 보존하며 역할 확정+장비 오류는 해당 역할 행과 오류 요약만 저장한다. 반대 역할/선호·다른 회원/이전 ID를 변경하지 않는다. 서버 profile의 표시 power로 개인 선호역할 snapshot을 덮지 않는다. 이 구간의 상세 raw payload·분석 버전 검증은 기존 빌드 계약을 따른다.

## 6. 구현 단위와 활성화 순서

| 단계 | 포함/종료 조건 | 대기 여부 |
|---|---|---|
| S1 캐시 기반 | 새 DB/앞4테이블·typed scope/ref/fence와 저장 계획·원자 apply/read/CAS·메모리 시험. schema1 신규 생성만, 실행 DI/네트워크/기존 DB 이관 없음 | Backend 완료 없이 구현 가능. 내부 fixture를 실제 V2 DTO로 보고하지 않음 |
| S2 서버 조회 adapter | 게시 L1b 원본 SHA로 strict DTO·페이지/등록 coherence·검증 snapshot·source/version을 만들고 격리 저장소에 연결 | 정확한 원본 OpenAPI 수신 필요. 예상 필드를 먼저 허용하지 않음 |
| S3 실행 연결 | app scope/session controller/캐시 read 상태·기존 local 경로와 UI 구분·dispose/재진입·FK 실제연결 검증 | S1/S2 통과 후 별도 범위. 로그인 주목록 교체를 이번 설계로 승인하지 않음 |
| S4 활동/대표·개인자료 | 서버 활동/공유 settings_version·대표 왕관 및 scope별 역할/개인설정, 기존 정상 흐름 인수 | 기능별 연결 단위로 분리. live 소유/장비 증거 보류를 우회하지 않음 |

S1에서는 파일을 정의/시험만 하며 새 디스크 DB가 앱 시작에 자동 생성되도록 DI하지 않는다. 전체 빌드 자동 갱신·기존 DB migration/고아 정리·게스트 이관·실자료 삭제·Backend 배포·Issue 종료는 이 단계에 포함하지 않는다. 다음 구현 지시는 S1을 대상으로 삼을 수 있으며 별도 제품 결정은 필요 없다.

## 7. 회귀·최소 시험·완료 판정

| 대표 경계 | 필요한 판정 |
|---|---|
| 같은 UUID/이름, 다른 회원·환경·API base path | 서로 다른 scope row. 조회·쓰기·build 수치 섞임0 |
| 같은 scope/이름, 다른 character ID | 둘은 다른 row/새 빈 개인 공간. 이름 unique나 이전 build 복사 없음 |
| 같은 ID 다른 account 요청/중복 ID·잘못된 FK | transaction 전체 거절/부분 적용0 |
| 같은 ID lifecycle revision 변경 | cache 갱신/재검증, 과거 개인 snapshot 보존. ID 재할당 없음 |
| stale session/runtime/조회 sequence·CAS·서버 revision 후퇴 | 적용 전 거절, commit 중 경합은 §4 순서대로 이전scope 한정·노출0. 소유 수명 전환 뒤 settings version 초기화는 별도 정상 경계 |
| 부분 페이지/불량 shape/cursor stale/404·429·key/네트워크 실패 | 계획 미생성·기존 정상 cache/양역할·기기 로컬 자료 불변 |
| 전체 등록 목록의 메인 변경/등록 미관찰·metadata_only head | 현재 목록/메인은 최신 sequence 기준, 개인자료 삭제0·전체 roster receipt 발급0 |
| metadata→character 사이 실패/FK 위반·CAS 실패 | 모든 신규/갱신 row·버전 rollback |
| 서버 settings 변경·대표 replay/GET 실패 | 과거 응답으로 현재 활동/대표 덮기 금지. 재조회/명시 복구 후 새 묶음 적용 |
| 재시작/동일회원 새세션/다른회원/게스트·dispose | receipt 무효, 자동 쓰기/claim·소유 부활 없음 |
| legacy DB와 새 DB 동시 존재 | 기존 테이블 행/빌드/주간 표기·index/schema13 불변, 기존 writer가 새 DB를 받지 않음 |

S1 시험은 메모리 DB의 두 scope/두 account·이름 재사용 대표 사례와 transaction/FK/sequence/CAS/전환 순서에 집중한다. 정상 UI 자동 시험·실장비/실키를 선행 조건으로 추가하지 않는다. 새 DB/공용 모델을 실제 연결하는 단계에서 최종 lib/test 분석·전체 시험 필요성을 판단한다. 이번 설계는 문서 내용/소스대조·링크/whitespace·git diff --check만 검증하며 기존 인증 전체1282PASS/분석0은 이전 구현 결과로 보존한다.

설계 완료는 scope/키·FK·null/출처·수명·writer·transaction/경합 순서·S1 완료 조건이 정의되고 NEXT_WORK에 다음 단위가 기록된 상태다. 실제 저장·API/화면 연결·실기기 검증을 완료로 보고하지 않는다. 새 Backend 변경 요청은 없고 L1a/L1b 기존 요청을 유지한다.

## 8. S3 app runtime·조회 화면 연결 계약

### 8.1 실제 진입점과 소유

| 현재 근거 | S3 연결 방침 |
|---|---|
| BackendApp._initializeServices/_createRouter | 선택한 Backend base URI·단일 AuthAccountReadSession/accountApi를 새 runtime에도 그대로 전달한다. 새 세션 wrapper를 따로 만들지 않는다. environment는 runtime 수명 동안 불변이다 |
| ServerAccountReadViewModel/ServerCombatPowerViewModel | 기존 V1 초기 목록 조회를 같은 ServerAccountReadRepository가 shareInFlight로 공유한다. S2 내부에서 별도 Repository를 만드는 현재 구조는 S3a에서 주입 가능하게 바꾸고 초기 등록 수집도 같은 진행 중 GET을 공유한다. 명시/쓰기 후 GET은 새로 실행한다. S2 등록 적용 성공 후 같은 수집의 typed metadata를 반환하도록 확장해 원정대 count/대표 요약을 별도 GET 없이 표시한다. normalized cache에 없는 count를 현재 캐릭터 수로 추정하지 않는다 |
| MyAccountPage.serverAccountsSection, ServerAccountsPanel | 기기 캐릭터 주목록과 분리된 기존 ‘등록한 원정대’ 영역을 사용한다. 기기 local AccountRepository/양역할/표시·주간 자료를 교체하지 않는다 |
| /account/server/:registrationId | V2 활성 환경에서는 현재 상태 전용 상세로 연결한다. 기존 V1 캐릭터·전투력 화면은 /account/server/:registrationId/power의 보조 진입점으로 보존한다. V2 비활성 환경에서는 기존 route/동작을 유지한다 |
| /settings/game-account-verification onVerified / 관리 화면 복귀 | 현재 GET 재수집으로 metadata/선택 roster를 무효화·갱신한다. 쓰기/replay 응답 자체를 캐시의 현재 상태로 적용하지 않는다 |
| BackendApp.dispose | 새 controller 작업/노출 무효화→session listener 제거·client/cache dispose→진행 중 DB 작업 정리→새 DB close 순서를 runtime 소유자가 책임진다. caller가 주입한 DB/HTTP를 page가 닫지 않는다 |

이름은 설계용이다. 새 앱 수명 객체는 `ScopedAccountRuntime`, 상태는 `ScopedAccountViewModel`로 제한하며, 별도의 전역 서비스 프레임워크나 범용 event bus를 만들지 않는다. Runtime은 DB factory/client/cache를 소유하고 ViewModel은 조회 상태·generation·timer·사용자 의도를 담당한다. page는 ref/표시 모델만 받고 raw DB를 읽지 않는다.

### 8.2 디스크·환경·회원 수명

- S3a는 QueryExecutor/DB factory를 주입받는 runtime과 기존 drift_flutter 방식의 **별도** `lost_party_server_cache` factory를 준비한다. 기존 `lost_party`/schema13·키 저장소를 열어 변환하거나 합치지 않는다. S1 schema1/FK는 유지한다.
- S3b에서 V2 활성 조건을 만족한 로그인 회원이 처음 서버 영역을 조회할 때 lazy open한다. 게스트·비활성 환경은 새 DB open/새 V2 요청0이다. 앱 시작 화면은 이 캐시/네트워크 완료를 기다리지 않는다. 앱 수명 DB connection 하나를 재사용하며 등록/화면마다 새 connection을 만들지 않는다.
- 데이터 key는 기존 StorageScope(base URI+member UUID) 그대로다. 화면에는 현재 scope 자료만 읽는다. 최초 hydrate는 토큰 복원 완료 뒤 현재 회원이 확정된 경우만 가능하며, 이전 디스크 자료는 ‘이전 확인 정보’다. 재로그인/재시작은 receipt를 복원하지 않는다.
- 회원·동일회원 새세션·로그아웃 때 화면 rows/receipt/선택·history/continuation/error/timer를 **동기적으로 먼저 비우고** 조회 generation을 증가시킨다. DB/HTTP await 뒤에는 runtime/session/요청 ticket을 모두 대조한다. 과거 scope의 디스크 row는 자동 삭제하지 않는다. 로그아웃해도 기기 local 주목록은 기존 정책대로 남는다.
- 환경 변경은 기존 Dio.options.baseUrl을 수정하지 않고 old runtime을 폐기한 뒤 새 transport/session/runtime으로 재구성한다. 현재 앱의 설정은 시작 시 선택이며 실행 중 환경 변경 UI를 추가하지 않는다. 기존 allowedAuthBaseUrl 정책대로 release HTTPS/debug만 HTTP를 허용한다.
- 요청 URI는 cache scope와 동일한 설정에서 만든다. root와 일반 prefix 경로를 지원하고 전체 request URI의 host/scheme/port/base path를 모의 transport에서 확인한다. 현재 Dio5.9.2 RequestOptions.uri는 baseUrl+path 결합 후 중복 슬래시를 축약하므로, 비root base의 중복 슬래시를 조용히 합쳐 다른 scope의 경로로 호출하지 않는다. S3a runtime 구성 검사에서 의도 URI와 실제 URI가 달라지는 설정은 연결 오류로 거절한다. scope 정규화 자체를 느슨하게 바꾸거나 auth 공용 transport를 전면 재작성하지 않는다.
- 기존 AuthSessionStore/회원 키 storage가 origin 기준인 것은 별도 경계다. 새 캐시의 base-path 격리만으로 기존 인증·키의 환경 분리까지 완료됐다고 보고하지 않는다. 현재 root 환경의 정책을 유지하며 base-path 지원 검증은 실제 요청 URI와 세션 설정을 함께 확인한다.
- DB open/읽기/쓰기 실패는 해당 서버 영역의 저장 오류로 처리한다. 자동 DB 삭제·재생성·schema rollback이나 실패를 빈 roster로 치환하지 않는다. UI에는 재시도와 정상 local 기능을 남긴다.

### 8.3 조회 순서·중복·무효화

현재 상태/이력 GET은 서버 저장 관찰을 읽는 요청이므로 회원 Lost Ark 키·나이스단 설정 GET 완료를 추가 선행 조건으로 만들지 않는다. 기존 키 복원/설정은 병렬 흐름을 유지한다. 키가 필요한 전투력 명령·직접 provider 조회·전체 빌드 자동실행의 준비 조건은 각각 기존 계약을 따른다.

1. 활성+signedIn → 현재 scope의 캐시 hydrate(있으면 stale 표시)와 서버 등록 전체 조회를 시작한다. 초기 목록 소비자는 runtime의 한 future를 공유하고 기존 V1 shared repository에도 shareInFlight=true를 전달한다. 세션별 첫 초기화 완료 후 탭 이동/같은 화면 재진입/앱 복귀만으로 다시 시작하지 않는다. 이는 전체 Armory 자동갱신의 회원별1회 정책과 다른 조회 수명이다.
2. 등록 목록 전체 성공 뒤 S2가 S1 metadata를 원자 적용한다. 전체 등록 목록이 성공해 0건이면 그때만 ‘등록한 원정대 없음’이다. 디스크 readRegistrations=[]만으로 서버 목록 0건을 확정하지 않는다. 이 단계에서 캐릭터 전체를 조회한 것으로 표시하지 않는다.
3. 현재 상태 상세 진입 때 해당 registration의 V2 전체 페이지를 수집한다. 로그인 시작에 모든 원정대를 V2로 추가 수집하지 않는다. 같은 등록의 동시 진입/연타는 진행 중 future를 공유한다. 서로 다른 등록의 조회도 전체 metadata 교체와 경합하지 않도록 controller queue로 순서를 관리한다.
4. metadata 갱신은 진행 중 roster의 이전 token을 무효화한다. 이미 진행 중인 조회를 새 metadata 위에 뒤늦게 적용하지 않는다. 현재 화면이 계속 요구하는 선택 등록은 metadata 완료 후 한 번 새 조회를 예약한다. 무관한 모든 등록을 자동 재조회하지 않는다. S1이 거절한 token/CAS를 새 version으로 바꿔 자동 재적용하지 않는다.
5. 명시 ‘다시 조회’는 새 작업이다. 해당 화면은 busy 동안 동일 동작을 막는다. 구조 충돌/목록에서 제거된 등록은 metadata부터 다시 확인하며, 자동 무한 재시도/폴링을 하지 않는다. 서버 404도 V2 미배포/등록 부재를 error.code와 metadata로 구분하기 전에는 빈 성공으로 처리하지 않는다.
6. 관리 화면의 등록/수정/메인 변경/제거·정보 갱신 뒤와 인증 verified 뒤에는 현재 등록 GET을 무효화한다. 현재 콜백과 쓰기 VM의 실제 명령 시작/종료를 최소한의 명시 callback/revision으로 연결한다. notice 문자열이나 모든 notifyListeners를 쓰기 성공 신호로 파싱하지 않는다. 쓰기 시작 시 기존 receipt를 보류하고 성공/불확실 종료 후에는 GET을 요구한다. 명확한 거절도 최신 관찰 없이 새로운 권한을 만들지 않는다.
7. 전투력 명령 경로는 기존 V1을 유지한다. 보조 화면 복귀 시 선택된 V2 roster를 다시 조회해 표시 관찰을 갱신하며, 명령의 과거 멱등 응답을 cache에 직접 덮지 않는다. V2 row를 ServerCombatPowerViewModel.store/powerFor에 주입하거나 이름으로 local 빌드/캐시를 합치지 않는다. local 전투력 수동 확인·선호역할 snapshot 우선은 기존대로다.

S3는 원정대별 전체 snapshot의 원자성만 보장한다. 여러 원정대에 걸친 하나의 서버 snapshot/분산 transaction을 주장하지 않는다. background/tab-resume 자동 재조회나 전체 자동빌드는 후속 합의 범위에서 연결한다.

### 8.4 화면 상태와 행동

coverage(등록 요약만/전체 canonical/preview), freshness(이전 관찰/이번 세션 조회 성공), operation(idle/loading/error)은 별개로 둔다. `usable`, `owned`, `configured` 또는 `complete` 하나만으로 최신 상태/명령 허가를 표시하지 않는다. runtime은 현재 registration 목록의 성공 여부와 세션/operation stamp를 메모리에 보관한다.

| 상태 | 사용자 표시/행동 |
|---|---|
| guest | 기존 로그인 안내. 서버 회원 자료·history는 즉시 숨김 |
| feature 비활성 | 기존 V1 원정대/전투력 화면 유지. V2 준비 UI/미배포 오류를 사용자에게 자동 노출하지 않음 |
| cache hydrate/서버 조회 중 | 서버 영역의 진행 표시. 기존 같은 scope 정보가 있으면 ‘이전 확인 정보 · 다시 확인 중’, 빈 화면은 loading. local 주목록/앱 첫 화면은 사용 가능 |
| metadata_only | 원정대 이름·본/부 구분은 표시 가능. ‘캐릭터 상태 확인 필요’와 상세 진입. 0명/전체 정상으로 간주하지 않음 |
| 현재 canonical 전체 조회 성공 | ID별 현재 profile·활동/대표의 저장된 선택·suspect/claim 경고를 읽기 표시. receipt는 신선도 확인만이며 활동/대표/파티 버튼을 새로 활성화하지 않음 |
| preview/소유상실 조회 성공 | ‘미인증 미리보기’/‘원정대 재인증 필요’. 수치가 fresh일 수 있으나 자격 완료로 표시하지 않음 |
| 조회 실패·캐시 있음 | ‘이전 확인 정보 · 최신 상태 확인 실패’, 대상별 경고/재시도. 서버 row/개인자료를 삭제하거나 성공 건수로 포함하지 않음 |
| 실패·캐시 없음 | 오류와 재시도/로그인·인증 등 해당 해결 동작. ‘캐릭터 없음’으로 대체하지 않음 |
| 정상 전체 목록/roster 0건 | 해당 성공 범위에 한해 빈 상태 표시. 삭제·퇴역 추론/정리는 수행하지 않음 |

S1의 accountId=null preview는 head/receipt가 없고 readRoster.complete=false다. S3 controller는 **S2 refreshRoster 정상 반환+같은 runtime/session/request stamp+다시 읽은 현재 등록**으로 ‘이번 preview 조회 성공’을 별도로 표현한다. 이를 canonical complete/receipt로 위조하거나 DB 필드를 추가해 소유 권한으로 저장하지 않는다. 초기 디스크 preview는 stale이며 `display.preview` 유무만으로 이번 조회 성공을 판정하지 않는다. ownership_lost에 account head/receipt가 있더라도 사용 권한과 분리한다.

S3b 상세는 lifecycle·blocked_reason에 따른 읽기 경고(‘캐릭터 확인 필요’, ‘캐릭터 정보 충돌’, ‘원정대 재인증 필요’)와 확인 시각을 제공한다. 내부 SHA/UUID·DB명은 일반 UI에 표시하지 않는다. 새 대표 왕관/활동 선택/빌드 저장·파티 신청 버튼은 이 구간에 추가하지 않는다. 기존 전투력 확인 화면으로의 버튼과 퇴역 이력 진입을 제공한다. 이력은 현재 캐릭터 선택 후보로 노출하지 않는다.

### 8.5 퇴역 이력·오류·대기시간

- 이력 경로는 회원 단위 `/account/character-retirements`다. ‘등록한 원정대’ 영역의 ‘사라진 캐릭터 기록’에서 진입한다. 특정 원정대가 제거되거나 등록이0개여도 회원의 이력은 조회 가능하다. 서버 이력인 점을 구분하고 local missing 목록과 합치지 않는다.
- 진입 시 첫 페이지를 명시 조회하고 ‘더 보기’로 다음 한 페이지만 가져온다. 전체 수를 추정하거나 자동 스크롤 fetch를 추가하지 않는다. 같은 페이지 요청 중 버튼을 비활성화한다. 이력은 화면/세션 메모리 수명이며 뒤로가기/dispose/회원 전환 때 continuation과 rows를 폐기한다.
- 서버/이름/직업/마지막 전투력·아이템 레벨과 퇴역 시각을 표시한다. 수치 null은 ‘미확인’, 각 수치의 확인 시각은 있을 때만 표시한다. retired_at을 power/아이템 관찰 시각으로 사용하지 않는다. 새 이름/새 소유자와 자동 매칭하거나 캐릭터 복원/삭제 액션을 제공하지 않는다.
- S2 continuation은 전송 전에 소비되는 일회용 객체다. 다음 페이지 network/파싱/서버 오류가 나면 같은 continuation을 재사용할 수 없으므로 목록을 불완전 상태로 표시하고 **‘처음부터 다시 조회’**를 제공한다. 새 첫 페이지 결과가 성공하기 전 기존 rows를 최신 전체로 표시하지 않는다. CURSOR_STALE/revision 변경 때도 다른 세대의 이력을 이어 붙이지 않는다. 첫 페이지 성공0건에 한해 이력 없음이다.
- API rate limit는 retryAt 우선, retryAfter는 수신 시각+duration으로 고정한 deadline으로 계산하고 재build마다 초기화하지 않는다. 1초 timer는 표시만 갱신하고 요청을 실행하지 않는다. dispose/로그아웃 때 정리하며 남은 시간동안 해당 재시도를 막는다. deadline이 없으면 임의 대기시간을 생성하지 않는다.
- NETWORK_UNAVAILABLE/5xx는 재시도, CURSOR_STALE/REVISION_CONFLICT·cache CAS 충돌은 등록부터 현재 GET, REGISTRATION_NOT_FOUND는 목록 확인, OWNERSHIP_REQUIRED/blocked 상태는 인증 안내, 401/ACCOUNT_DISABLED는 기존 auth 처리다. raw/알 수 없는404·INVALID_RESPONSE·CONTRACT_MISMATCH는 조회 불가이며 V1 결과로 V2 성공을 가장하지 않는다. DB 오류는 저장/읽기 오류로 구분한다. 이전세대 SESSION_CHANGED/STALE_READ/dispose 결과는 새 화면의 오류로도 노출하지 않는다.

### 8.6 활성화·완료 조건과 구현 순서

원본 계약 게시와 실행 서버 준비는 별개다. S3b는 시작 시 불변인 `BACKEND_LIFECYCLE_READS_ENABLED` 설정(기본false)으로 활성화한다. 서버 capability endpoint를 추측하거나 첫404를 보고 영구 지원불가/삭제를 저장하지 않는다. 플래그 OFF는 기존 V1 흐름이며, ON에서 V2 실패를 V1으로 자동 fallback하지 않는다. 따라서 V2 성공과 오래된 관찰이 섞이지 않는다.

실환경 ON 전에는 대상 환경의 L1a/L1b 코드·DB0007 적용/실행 API 버전·승인과 준비 완료 회신을 같은 Issue에서 확인해야 한다. 이 설계는 DB migration/배포를 요청하거나 승인하지 않는다. Flutter의 S3a/S3b 코드·모의검증은 이 준비를 기다리지 않고 진행한다. live 장비proof/퇴역·claim해제 보류는 플래그와 무관하게 유지한다.

| 단위 | 포함/종료 조건 |
|---|---|
| S3a runtime/controller (구현 완료) | DB factory·같은 readSession/공유 registrations 주입, lazy open/수명·scope/URI 검사, session별 hydrate/초기화·등록/roster queue/receipt/preview 성공 stamp·무효화·대기/오류·history controller. S3a 당시 실행 앱/Router/화면은 제외했고 S3b에서 연결했다 |
| S3b 앱/화면 연결 (구현 완료) | BackendApp gated DI/서버 패널·현재 상태/V1 전투력 보조 route/회원 이력·관리/인증 callback을 연결했다. 검증/미확인 및 다음 실환경 인수 조건은 상단 결과와 NEXT_WORK를 따른다 |
| 실서버 인수 | 별도 승인/Backend 준비 확인 뒤 해당환경 ON 빌드에서 사용자가 수동 확인한다. 서버 GET/preview·기존 전투력·회원 전환/오류·이력(실제 존재 여부 포함)을 구분하고 실자료 퇴역을 시험 목적으로 만들지 않는다 |

S3a 최소 자동검증은 주입 DB open/close 소유·게스트/비활성0호출, 같은 session/API와 실제 URI prefix, 초기 V1 GET 공유/명시새조회, runtime queue/중복/metadata 중간변경, 디스크 empty와 서버 empty 구분, null-head preview 성공 stamp, 같은/다른회원 전환·queued hydrate/late/dispose, 부분 실패 보존, history 소비된 continuation 실패와 재시작·deadline을 묶는다. S1/S2에서 이미 검증한 FK/DTO 정책을 복제해 새로 구현하지 않는다. S3b Router/DI 변경 최종 상태에서는 전체 Flutter test/analyze를 한 번 실행하며 단순 정상 UI 조작은 사용자 수동 검증으로 남긴다.

수동 확인은 서버 패널·기존 local 카드/빌드·등록 관리/인증 재진입·전투력 보조 화면·preview/경고/기록 페이지·로그아웃/재로그인/뒤로가기·통신 실패/재시도다. 실제 준비되지 않은 상태·모의 이력만 확인한 항목을 live 통과로 표시하지 않는다. 설계 당시에는 소스/계약/문서·diffcheck만 했고, 후속 S3a/S3b 구현 최종 검증은 상단 결과를 따른다. 현재 사용자 수동 항목은 NEXT_WORK에 모았다.
