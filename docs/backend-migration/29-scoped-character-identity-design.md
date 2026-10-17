# 회원·환경별 서버 캐릭터 연결 설계

> 2026-10-16 현재 적용: 이 설계의 회원/환경·canonical ID·소유수명 경계를 S1~S3 캐시와 A1/A2 저장·B 자동 실행·C 앱/회원 주목록에 연결했고 최종 전체1524PASS/lib-test분석0이다. 아래 초기 writer 조사·공백은 당시 근거로 보존한다. 현재 저장/실행 계약은 [30](30-scoped-storage-write-contract.md)/[23](23-nice-group-auto-refresh-design.md), 실제 서버 준비·ON 빌드 수동 인수는 [NEXT_WORK](../project/NEXT_WORK.md)를 따른다. 기본 flag OFF·구 기기 schema13/자료 보존, 활동/왕관/파티 신규 연결과 live 소멸/claim 해제는 별도다.


최신 상태(2026-10-15): Backend L1a/L1b 원본 게시와 Flutter S1/S2/S3a·S3b gated 앱 DI/현재 상태·이력 화면 구현/자동검증 완료(최종전체1394PASS·분석0). [계약30 §8](30-scoped-storage-write-contract.md#8-s3-app-runtime조회-화면-연결-계약)/[NEXT_WORK](../project/NEXT_WORK.md)의 실제 대상 환경 준비·사용자 수동 인수와 Git 통합이 남았다. 기본 플래그OFF다. 아래 미회신/저장 계층 미구현 문구는 최초 설계 당시 이력이다. 실제 DB0007/실행API 전환·live 증거/퇴역·기기자료 정리는 계속 보류다.

저장 구조 후속(2026-10-15): [scoped storage/writer 계약30](30-scoped-storage-write-contract.md)에서 별도 캐시 DB·typed scope/ref·초기4테이블·FK/CAS·세션/commit 경합 순서·legacy writer 분리와 S1 구현 종료 조건을 정의했다. 이번은 설계이며 schema13/코드/실자료는 변경하지 않았다. 아래 저장 계층 미확정 문구는29 작성 시점의 구간 구분이며 세부 계약은30을 따른다.

인계 완료: [Issue8 L1a/L1b 구현 요청6185091368](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6185091368)을 게시·원격 본문 일치 확인했다. 실제 Backend 착수/구현 결과는 아직 미회신이다. 아래 계약이 이번 수용 범위이며 이전 전체 미수용/추가 요청 없음 기록을 이 범위에서 대체한다.

2026-10-15. 사용자 `진행합시다` 지시에 따른 서버/로컬 ID 연결 조사·설계와 Issue8 L1 구현 인계 단위다. 기능/Drift 스키마·기기 자료는 이번에 수정하지 않는다. 기존 인증 화면 구현의 직접 후속이므로 feature/account-verification-client를 재사용한다. HEAD/origin-dev는 cc6a0b0, 이전 인증/설계 미커밋과 사용자 Rules/tools는 보존한다. Backend 기준은 대표 구현 cd3e003과 조사 회신6184587789, 생명주기 보완6183941103이다.

## 1. 실제 연결 경로와 공백

| 근거 | 현재 사실 | 새 연결에서 필요한 경계 |
|---|---|---|
| `lib/features/account/data/local/account_database.dart` GameAccounts/AccountCharacters, schema13 | 기기 공용 정수 PK·nullable 서버 ID, 회원/환경/등록ID/revision 없음. 서버 ID unique index도 기기 전체 범위 | 기존 행의 서버 ID만으로 현재 회원·환경 귀속을 인정하지 않음 |
| 같은 파일 `bindServerIdentity` | 로컬 계정 소속/중복/일반 재매핑 거절은 transaction으로 검증. serverMismatch이면 재매핑 허용, 저장 시 소유 상태를 active로 변경 | 현대 Backend 연결에서 그대로 호출하지 않음. 단순 mismatch 확인/이름 일치로 다른 ID를 덮거나 active 권한을 생성하지 않음 |
| `domain/entities/server_account_identity_binding.dart` | 로컬 PK/서버 ID map만 전달, 회원·환경·세션·관찰 revision/출처 없음 | 기존 객체를 새 서버 소유 증명 객체처럼 사용하지 않음 |
| `data/datasources/local_account_data_source.dart`와 DB `applyRosterSummarySync` | profile은 메인 로컬계정의 이름으로 갱신, roster는 로컬계정 내 서버/이름으로 기존 행을 찾고 누락 해제 | 서버 세대 행을 이 이름 기반 writer에 넣으면 이름 재사용 시 과거 빌드/ID가 이어질 수 있음. 새 경로는 별도 ID 기반 writer 필요 |
| `presentation/viewmodels/server_combat_power_view_model.dart` `powerFor`/`refreshForLocal` | 서버 표시 cache는 현재 회원 세대로 격리하지만 로컬 카드와의 대조는 서버/이름. 개인 역할 Snapshot은 우선 보존 | 표시 대응은 신원 연결 증거가 아님. 향후 세대 기반 표시에서는 검증된 scope/ID를 요구하며 기존 이름 overlay를 그대로 재사용하지 않음 |
| `domain/server_account_read_repository.dart` | 전체 페이지/중복/cursor·소유/roster/settings revision 일치·회원 세대를 검사 | 활용 가능. V1 characters에는 등록 version/lifecycle revision이 없으므로 임의로 채우지 않음 |
| `app/backend_app.dart` | 공용 로컬 DB와 AccountRepository에 서버 ownership gateway 없음. 인증은 서버 목록을 재조회하고 로컬 binding은 하지 않음 | 현재 화면 완료와 로컬 소유/ID·활동 연결 완료를 구분 |
| `test/features/account/data/local/account_database_test.dart` | 기존 bind 원자성/중복/foreign account/재매핑 거절·serverMismatch 예외 시험 존재 | 기존 계약 보호 근거이며 회원/origin/세대 연결 검증이 이미 있다는 근거는 아님 |

이 공백은 기존 비로그인·기기 공용 자료 정책 자체를 취약점으로 판정하는 것이 아니다. 서버 소유/세대 정보를 새로운 경로에 연결할 때 필요한 추가 계약이다.

## 2. 연결 식별자와 정답 저장소

- 서버 리소스 식별은 `(Backend 환경, App user_id, game_account_id, character_id)`다. registration_id는 회원의 등록 관계로 별도 보관하며 canonical account/character ID 대신 쓰지 않는다. 이름/서버/직업/레벨은 표시·조회 속성이고 빌드 이전/권한의 식별자가 아니다.
- Backend 환경 키는 현재 배포 설정의 정규화된 API base URI다. 현재 root 경로에서는 origin과 같지만 같은 origin의 서로 다른 base path는 구분해야 한다. 슬래시/기본 포트 정규화 규칙을 구현 계약에서 고정하며 임의 호스트 alias를 합치지 않는다. 환경 변경 시 이전 세션·in-flight 결과를 무효화한다.
- 지속 자료의 회원 귀속과 일회 요청 세대를 구분한다. 캐시는 환경/회원/서버 ID에 귀속하고, 요청은 추가로 현재 session generation을 캡처한다. 재로그인은 캐시를 새로 소유하는 사건이 아니며 최신 서버 자격 재조회 전 동작은 허용하지 않는다.
- 서버 소유/상태/활동/대표는 서버가 정답이다. 저장한 mapping이나 로컬 active 값은 서버 권한 증명서가 아니다. 최종 대표/활동/미래 파티 명령은 서버에서 현재 소유/ID/생명주기/revision을 다시 검사한다.
- `lifecycle_revision`은 해당 ID의 변경 세대 검사값이며 새 물리 캐릭터를 보장하는 외부 영구 ID가 아니다. 내부 UUID 역시 upstream 영구 동일성의 증거로 설명하지 않는다.

## 3. 자료 수명과 쓰기 전제

| 자료 | 연결 방침 |
|---|---|
| 기존 로컬 전용 캐릭터/역할 빌드·선호·순서/주간 설정 | 그대로 보존. 같은 이름·사용자 확인만으로 서버 캐릭터로 승격/빌드 승계하지 않음 |
| 과거 server ID만 있는 기기 행 | 회원/환경 출처가 없으므로 자동 연결 대상 아님. serverMismatch 예외로 재매핑하지 않음 |
| 같은 환경/회원·동일 ID의 출처를 보존한 새 캐시 | 최신 서버 전체 조회와 revision 확인 후 같은 ID에만 갱신. logout/소유 상실 뒤 사용 자격은 재검증 |
| 새 canonical ID | 해당 scope의 빈 캐시/새 개인 빌드 공간으로 시작. 기존 이름 행·다른 회원 자료를 재활용하지 않음 |
| preview/null canonical ID | 등록/preview 세대에 묶인 표시 자료만. 활동·왕관/퇴역 적용 대상 아님 |
| suspect/retired/불일치/삭제된 등록 | 신규 사용 차단/확인 필요. 기존 개인 자료 파괴 정리는 별도 퇴역 계약과 정확한 ID mapping이 있을 때만 |

설계상 서버 scope별 캐시/연결 metadata는 기기 공용 legacy 행과 분리한다. 필요한 정보는 환경·회원·등록 관계·canonical IDs·최종 확인 revision/시각·출처·연결 상태다. 한 로컬 행을 여러 회원/서버 ID의 공유 빌드 저장 공간으로 만들지 않는다. 정확한 Drift 테이블/키·기존 unique index와의 공존 및 생성/소유/삭제 writer는 **다음 저장 계층 설계·구현 단위**에서 검증한다. 이번 문서는 schema13을 수정하거나 기존 서버 ID를 일괄 역귀속시키는 migration이 아니다.

전체 환경 복원, 로그인 화면의 주목록 교체, 게스트 빌드 수동 가져오기/연결 UX는 여기서 새 제품 정책으로 채택하지 않는다. 출처 없는 자료의 연결을 보류하면 현재 승인 범위는 이 선택 없이 진행할 수 있다.

## 4. 준비·검증·저장 흐름

1. 현재 환경/회원/세션을 캡처한다. 인증 pending/unknown result를 verified로 승격하지 않는다. 서버 저장 상태 GET은 새 소유 인증 수행이 아니며, 서버가 현재 소유자로 인정한 scope만 후속 준비 대상으로 삼는다.
2. 등록 목록과 선택 등록의 전체 characters를 읽고 등록 ID/account ID·소유/설정/roster revision을 대조한다. V1에서는 전체 등록 목록을 앞뒤로 읽어 해당 등록의 version/account/소유/roster/settings 변화를 검사한다. 중간 변경/페이지 실패/중복/빈 비정상 응답이면 준비 결과 전체를 폐기하고 명시 재조회한다. V1에 없는 lifecycle revision은 추정하지 않는다.
3. L1의 V2 현재 상태 원본 계약을 받으면 그 필수nullable/enum/등록·소유·roster/lifecycle revision/cursor를 strict parser로 읽는다. 전체 페이지 수집은 **서버 저장 snapshot 일관성** 검사이며 provider 전체성 보장으로 확대하지 않는다.
4. 로컬에 같은 환경/회원/ID의 입증된 연결이 있는지 검사한다. 다른 ID/출처 불명·다른 회원·다른 로컬 소속 충돌은 전체 연결 계획을 거절한다. 새로운 서버 ID에는 새 빈 공간만 계획하며 이름으로 옛 행을 선택하지 않는다.
5. 저장 직전 scope/session·연결 metadata/local row revision을 재검사하고 캐시/연결 metadata를 한 기기 transaction으로 반영한다. 부분 실패는 rollback. 기기 transaction은 서버와 분산 원자성을 보장하지 않으므로 최신 서버 자격은 최종 명령에서 재검증한다.
6. 정상 연결 뒤에만 서버 활동 선택 adapter/공유 settings_version·대표 저장을 다음 구간에서 연결한다. 인증/자료조회 실패를 OFF·빈 활동·소유 상실/퇴역 확정으로 쓰지 않는다. 자동 대표 선택·이름 변경 매칭은 없다.

기존 이름 기반 local profile/summary writer가 새 scope/ID 기반 자료를 변경하지 못하도록 경로를 분리하는 것이 쓰기 활성화 선행 조건이다. 기존 코드에 if 몇 개만 추가하거나 오래된 gateway를 그대로 DI에 넣어 완료로 처리하지 않는다.

## 5. 백엔드 L1 인계 범위

공식 조사6184587789의 공개 문서 확보 완료/해당 보장 미기재와 긍정 관찰·소멸 부재 증거 분리 판정을 검토 결과로 수용한다. 이를 증거 부족의 해소나 기능 완성으로 확대하지 않는다. 사용자의 이번 진행 지시를 근거로 **L1 중 P1 기반+현재 상태 읽기/기존 경로 차단**을 명시적으로 구현 요청한다.

| 구간 | 요청/완료 조건 |
|---|---|
| L1a ID/모델·원자성 | 기존 canonical UUID/소속 참조 보존·재사용 불가 ID, lifecycle/revision·NameClaim/퇴역 이력 기반. claim 유일성/lock 순서·충돌 사전진단/backfill/migration을 격리 DB에서 검증. 기존 missing 자동 retired 이관 금지 |
| L1a 기존 writer/캐시 | canonical_candidate/reconcile의 이름 중첩만에 의한 동일 원정대/소유 이전·suspect 자동 복구 차단. 신뢰된 연결 없는 분기는 pending/거절, 보존된 정상 preview/표시 조회는 유지. canonical ID/lifecycle/키·회원 scope와 preview 등록 세대 캐시 분리, 과거 이름 cache를 새 세대/이력 증거로 복사 금지 |
| L1a 기존 명령 보호 | preview/refresh/등록·challenge/confirm/활동·대표/power 전 경로 현재 상태·scope/등록/소유/roster/claim/lifecycle/키revision fencing. 네트워크 lock 밖, commit 재검증, 멱등 replay는 과거 결과이며 권한 재생성0. 구현된 대표 API/5분 제한 폐지 보존 |
| L1b 상태 읽기 | V2 characters 현재 상태·이력 GET만 독립 게시. preview는 null canonical/lifecycle·usable=false. 현재 조회의 자격은 최종 명령 허가가 아님. 회원/cursor/revision/nullable·enum·오류를 원본 OpenAPI에 고정하고 V1 필드/enum에 몰래 추가 금지 |

L1a를 먼저 완성·원격 게시하고 L1b를 이어서 인계할 수 있다. Flutter의 화면/저장 계층 구현을 기다릴 필요가 없다. endpoint/물리 DDL은 Backend 소유이며 기존 제안의 수정이 필요하면 소스/OpenAPI와 소비 영향표를 같은 이슈에 게시한다. L1b wire를 Flutter가 미리 추측해 구현하지 않는다.

이번 수용은 개발 브랜치 코드·migration 파일 작성/격리 PostgreSQL 시험·원격 계약 게시까지다. **개발/운영 DB migration 적용·API 재기동/배포·실자료 backfill/삭제는 요청하지 않는다.** live 자동 퇴역/claim 해제·소유 이전/동일 세대 복구의 증거 부족 분기는 비활성으로 유지한다. 내부 검증은 서버 전용 모의 evidence adapter로 하되 외부 요청/관리자 임의 boolean으로 증거를 위조하는 API를 만들지 않는다.

V1 필드 shape를 유지하되 이름 단독 추론·복구의 제한과 suspect 사용 차단은 이 구현 단위에서 수용한다. 단, 기존 환경에 실제 적용하는 시점은 Flutter 소비 영향 대조 후 별도다. retired 운영 목록/count/대표 요약 제외 방향은 유지하지만 L1에서 실제 퇴역을 열지 않는다. V2 refresh/lookup-recovery·신뢰된 퇴역/기기 삭제·파티 전체/영구 보관 정책은 다음 구간이다. AUTH 운영 보관기간을 이 코드 수용으로 확정하지 않는다.

## 6. 회귀 보호와 최소 검증

- 기존 UUID·활동/대표 FK 보존, 정상 등록/본부전환/이름/preview 표시·유효 대표 변경/활동 설정 보존. 로그인/키/회원설정 DTO와 기존5분 제한 제거 불변.
- 격리 PostgreSQL에서 동일 이름의 양방향 관찰 순서·동시 claim, 증거 없는 신규 연결/복구/소유 이전 거절, stale/폐기된 ID의 권한 부활0, 외부 호출 실패/부분·빈 응답 삭제0을 확인한다.
- 이전 세대 power/preview/lease/challenge/replay, 다른 회원/키 교체/등록 삭제·메인 ABA·late commit, transaction 중도 실패/rollback·멱등/중복 이력 경계를 검증한다. 종료 전이·claim 해제는 모의 증거 전용이며 live 활성화 시험이 아니다.
- V1 schema 불변/의도한 의미 변화 목록, 새 V2 strict·필수nullable/preview·cursor stale/전체 페이지 revision·타 회원 이력 거절/GET 쓰기0을 검증한다. 기기 연결은 향후 환경/회원/ID/세대 충돌·출처 없는 과거 행·부분 페이지/재진입/세션 전환·원자 저장 실패를 시험한다.
- 이번 Flutter 산출은 조사/설계·협업 회신이다. 코드 변경이 없으므로 기존 최종 전체1282PASS/분석0은 이전 구현의 결과로만 보존하고 재실행하지 않는다. 문서 diffcheck·출처/내용 대조만 실행한다. 미확인은 L1 실제 구현/게시 계약·새 scoped storage·실장비/실기기/왕관 사용이다.

인계 완료 시 Backend는 각 단위의 구현/OpenAPI SHA·브랜치/commit/push/dev 반영 여부, migration 격리 검증과 실제 DB 미적용 여부, 자동검증 수/내용과 미확인 live 범위를 Issue8에 회신한다. Flutter는 이를 받은 뒤 별도 소비 단위를 연결하고 결과를 같은 이슈에 회신한다. 이번 로컬 설계는 미커밋/미push이며 필수 요청은 이슈 댓글 본문에 직접 게시한다.
