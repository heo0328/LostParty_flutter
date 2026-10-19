# NEXT WORK — 인증 상태에 따른 내 계정 화면 선택 복구 설계

## 현재 단일 작업 — 기획·설계 완료, 구현 미착수

설계 커밋 `bd6814b`(로컬·미push·dev 미반영). 사용자 요청에 따라 [#15 결함/대응 설계 회신](https://github.com/heo0328/lostparty-backend/issues/15#issuecomment-6260778211), [#13 F2-A/F2-B 접수·검토 대기 회신](https://github.com/heo0328/lostparty-backend/issues/13#issuecomment-6260778487)을 게시하고 본문을 재조회했다. 다음은 구현 지시 후 최소 수정이며 이번 문서 커밋으로 해결 완료 처리하지 않는다.

2026-10-19 사용자 지시로 자동 로그인 뒤 로컬 화면이 잔류하는 결함의 해결 설계를 시작했다. 목적 브랜치는 `fix/account-auth-screen-selection`이며 종료 목표는 **경로 이동 없이 인증 상태에 맞는 내 계정 화면으로 전환되고 기존 복원·권한·앱 수명 작업이 유지되는 것**이다. 이번 지시는 문서 설계까지이며 기능 코드·서버·기기 조작은 포함하지 않는다.

### 확인 근거와 미확인 범위

- 사용자 추가 확인: **비로그인 상태 → 인증된 원정대 또는 기존 설정/활동 데이터가 있는 회원으로 명시 로그인 → 로그인 성공 뒤에도 해당 회원 데이터로 내 계정 화면이 재구성되지 않음**. 자동 로그인 지연만의 문제가 아니다. 대표 재현/인수 조건을 이 명시 로그인 흐름으로 두며 지연 자동 복원도 같은 화면 전환 경계로 보호한다. 원정대 인증 여부는 회원 화면 선택 조건이 아니며 미인증 등록도 현재 회원의 허용된 투영으로 표시해야 한다.

- `lib/app/backend_app.dart`의 `/account` builder는 `_memberAccount != null && readSession.isAuthenticated`를 한 번 읽어 회원/로컬 페이지를 선택한다. `GoRouter.refreshListenable: auth`만으로 동일 경로의 builder 재실행이 보장되지 않는다. 로컬 페이지 안 서버 패널은 별도 구독하므로 상단 로컬·하단 서버 상태가 혼재할 수 있다.
- `AuthAccountReadSession`은 auth의 인증 여부/회원/세대와 Listenable을 그대로 연결한다. 화면 선택에는 이 기존 신호를 사용하며 별도 로그인 판정 상태를 만들지 않는다.
- `StartupEntryGate`는 서비스 초기화 후 고정4초에 연다. 인증 복원이 그 이후 완료될 수 있다. 기존 설계30의 ‘늦은 인증 확정 후 회원 화면 전환’ 의도와 현재 구독 누락이 불일치한다.
- 앞선 조사에서 동일 경로의 선택 잔류/명시 구독 시 전환을 최소 재현2PASS로 확인했다(`.dart_tool/auth_route_probe_test.dart`, 무시된 조사 자료). 실제 앱 전체 연동·실서버·실기기 통과 증거는 아니다. 해당 분기는 분쟁 구현 이전 `209ce85e`부터 존재하며 이번 조사에서 처음 결함으로 확인했다.
- 서버 자료 삭제·다른 기기의 변경 유실·실제 credential 삭제는 확인하지 않았다. 주소(origin) 변경에 따른 별도 로그인 저장소, 네트워크 실패와 만료는 별개 원인이므로 이 수정으로 해결됐다고 단정하지 않는다.

### 화면·데이터 설계

| 상태/전이 | 화면 선택·행동 |
|---|---|
| 복원 중/인증 중 | 기존 비인증 접근과 공개·로컬 기능 유지. private 권한은 부여하지 않는다. 복원 중을 확정 로그아웃으로 해석하지 않는다. |
| 인증 완료 + 회원 기능 binding 존재 | 현재 경로에서 기존 MemberAccountPage로 자동 교체. 기존 로딩/진행/카드 UI와 scoped cache→현재 서버 복원 순서를 사용한다. |
| 로그아웃/세션 무효 확정 | 기존 로컬 화면으로 전환. 회원 자료 폐기·늦은 응답 차단은 기존 세션/VM guard가 담당한다. |
| 통신 불가/재인증 필요 | 기존 auth 상태·오류/복구 동작 유지. 실패만으로 credential을 삭제하거나 인증 성공으로 가장하지 않는다. |
| 회원 기능 binding 없음 | 기존 fallback 유지. feature flag 변경이나 새 binding 생성은 하지 않는다. |

구현안은 `/account`의 실제 분기 위젯을 기존 `AccountReadSession`의 `ListenableBuilder`로 구독시키는 최소 변경이다. 현재 인증 여부는 매 빌드 시 읽고, 기존 모델·주간VM·runner는 BackendApp 소유 객체를 그대로 전달한다. 화면 builder에서 initialize/refresh/API를 호출하거나 Router를 재생성하지 않는다. 인증 신호가 여러 번 와도 화면 선택 재평가만 수행한다. 로그인 pop·탭 이동·강제 redirect로 전환을 대신하지 않으며 기존 뒤로가기와 탭 스택을 유지한다.

회원 간 전환은 기존 환경+회원+session generation guard로 기존 자료를 비우고 현재 회원 자료만 복원한다. 로컬 검색 원정대는 별도 자료로 보존하고 서버 자료로 덮어쓰거나 회원 소유권으로 승계하지 않는다. 상단/하단이 서로 다른 화면 모드로 남는 현상을 제거하는 것이 목표다. 서버 최신값 반영 자체의 실패가 남으면 별도 근거로 원인을 조사한다.

### 포함·제외 범위와 작업 순서

1. **설계(이번 단계)**: 원인·상태별 화면·회귀/검증/완료 조건을 정리하고 오래된 로그인 문서의 시작·검증 기준을 최신 정책에 맞춘다.
2. **최소 구현(후속 지시 후)**: 실제 `/account` 선택 경계에 기존 인증 구독을 연결한다. 같은 조건이 있는 다른 경로는 직접 영향만 확인하고 무관한 재작성은 하지 않는다.
3. **기능 섹션 최종 검증**: 아래 표적 검증을 한 번 모아 실행하고 수동 확인 항목을 전달한다. 구현 중 반복 전체 테스트는 하지 않는다.
4. **인수·마감**: 사용자 결과와 미확인을 구분해 기록한다. 커밋·dev 통합·push는 실제 구현 검증과 해당 단계 지시에 따라 진행한다.

제외: 시작4초 연장/인증완료까지 전체 앱 차단, 성능 최적화·애니메이션, 새 화면·버튼·카드 리디자인, 로컬/서버 DB 병합·삭제·스키마 변경, 인증 TTL/재시도·bootstrap API 변경, 분쟁 API 재설계, USB 연결 설정 변경, #13 구현. Backend 변경 요청이 없는 Flutter 내부 화면 선택 수정이므로 새 협업 요청은 만들지 않는다. 연동 계약 문제가 확인되면 관련 Issue 최신 댓글을 확인해 별도로 추적한다.

### 회귀 보호·검증·완료 조건

- 대표 인수는 비로그인 내 계정에서 기존 원정대·활동/대표/표시설정이 있는 회원으로 명시 로그인한 뒤, 앱 재실행·탭 왕복 없이 해당 회원의 기존 카드/설정으로 재구성되는지 확인한다. 로그인 화면의 기존 pop 복귀를 포함해 실제 제품 분기 경계를 검증한다. 서버 복원 완료 전에는 기존 회원 로딩 상태를 사용하고 이전 로컬 결과를 회원 자료처럼 유지하지 않는다.

- 핵심 자동 회귀는 지연을 제어한 인증 복원으로 **4초 진입 후 같은 `/account`에 머무른 상태에서 회원 페이지가 나타나는지** 실제 제품 분기 경계에서 검증한다. 고립된 GoRouter 모형2PASS만으로 수정 완료를 판정하지 않는다. 실기기로 재현 시점을 고정하기 어려운 경합이라 이 표적 위젯 검증은 유지한다.
- 같은 경계에서 guest→signedIn→logout, 이전 회원 늦은 응답/다른 회원 전환 시 private 자료 비혼합, 반복 notify 시 추가 initialize/API 없음도 직접 영향 범위로 확인한다. 기존 fake/세션·binding 시험을 재사용하고 동일 정책을 중복 시험하지 않는다.
- 후보 시험: 새 화면 선택 회귀 시험, `test/app/bootstrap/startup_entry_gate_test.dart`, `test/features/auth/login_navigation_test.dart`. auth/회원 binding 코드를 수정하거나 기존 guard에 의문이 생긴 경우에만 해당 `auth_session_controller_test.dart`/`member_account_integration_test.dart`를 추가한다. 변경 파일 정적 분석·format·diffcheck를 수행한다.
- Router 경계의 한 분기 구독에 국한되고 schema/DI/공용 정책/다른 feature를 바꾸지 않으면 전체 Flutter 시험은 생략한다. 영향이 넓어지면 범위를 다시 설명하고 섹션 최종 상태에서 필요 시험을 선정한다. 이번 문서 단계에는 Flutter 시험을 실행하지 않는다.
- 사용자 수동 인수는 구현·자동 검증 후 한 묶음: 로그인 유지 재실행 시 기존 회원 카드/진행 표시, 서버 원정대를 다른 기기에서 바꾼 뒤 재실행 시 현재 회원 서버값 반영, 로그아웃 후 로컬 기능 유지. 연결 가능한 환경에서 사용자가 조작하며 Backend 미준비인 분쟁 결과 인수는 계속 별도 보류한다.
- 완료 조건: 경로 이동/재시작 없이 인증 확정에 따라 올바른 화면 선택, 기존 디자인·4초 진입·회원별1회/최대2worker·기본/주간 우선 순서 보존, 회원/환경 격리·pending/outbox 보호, 표적 검증 근거와 미확인 실기기 범위 기록. 현재는 설계만 완료되어 결함 해결 완료가 아니다.

## 현재 기준

2026-10-19 사용자 승인으로 원정대 인증·분쟁 V2 D1~D4 구현 구간을 마감했다. 구현 `43cd4e9`를 dev에 fast-forward 병합·origin/dev 푸시한 뒤 통합 기록을 정리했다. Backend 작업으로 현재 분쟁 결과의 실서버·디바이스 검증은 불가능하므로 차후 인수로 분리했다. 실기기 통과를 뜻하지 않으며, 인수 대기만으로 현재 브랜치를 계속 열린 구현 작업으로 두지 않는다. 최종 커밋·dev/push 근거는 DEV_LOG를 따른다.

- 공식 추적 [Issue15](https://github.com/heo0328/lostparty-backend/issues/15), 구현/계약과 후속 체크는 [설계36](../backend-migration/36-roster-ownership-dispute-flutter-design.md#9-backend-준비-후-후속-실기기-인수).
- [구현 마감·실기기 후속 이관 회신](https://github.com/heo0328/lostparty-backend/issues/15#issuecomment-6260104075) 게시·재조회 완료. Backend 준비 후 사용자 인수를 재개한다.
- 검증은 D1~D4 직접 영향 테스트·변경 파일 분석 결과를 재사용한다. D4 최종68고유PASS·변경18파일분석0, 코드 변경 없이 문서/Git만 마감하므로 Flutter 시험을 반복하지 않는다.
- 기존 UI·V1 미완료·회원/환경/명령 복구·현재 GET 후 소유 반영과 PARTY_IMPACT_REVIEW_REQUIRED 안전 보류를 보존한다. 배포·DB 변경/자료 삭제·기기 설치/조작·main 반영은 이번 지시에 포함하지 않는다.
- 사용자 백업/tools/DevTools/플랫폼 생성 변경 및 별도 통계 문서 변경은 소유를 보존해 현재 분쟁 커밋에서 제외한다.

## 다음 독립 작업 후보 — Issue13 Q1~Q3 검토

최신 수신: [F2-A 내부 조회](https://github.com/heo0328/lostparty-backend/issues/13#issuecomment-6260548709), [F2-B 후보 HTTP](https://github.com/heo0328/lostparty-backend/issues/13#issuecomment-6260695606). Backend 보고 기준 F2-B 9fb2058은 로컬 커밋·미push, 개발 서버/원본 OpenAPI 미반영이며 신규 Flutter 시험 요청은 없다. Q1~Q3는여전히 미확정이고 현재 화면 재구성 결함 문서화와 분리한다. F3 고정 계약·원격 게시/실행 버전 확인 전 새 API 연결을 시작하지 않는다.

아직 착수하지 않았다. 별도 작업 승인이 있으면 적합한 목적 브랜치를 확인한 뒤 기존 문서/코드와 대조하는 검토만 진행한다. 분쟁 브랜치에 모집 기능 구현을 섞지 않는다.

- 근거: [#13 시간순12번째 계약 제안](https://github.com/heo0328/lostparty-backend/issues/13#issuecomment-6259336924), [13번째 F1 내부 기반 보고](https://github.com/heo0328/lostparty-backend/issues/13#issuecomment-6259515470).
- Q1: 종료 미정·주차를 넘는 일정의 기존 소비/사용자 흐름과 초기 지원 범위 대조.
- Q2: 딜러·서포터 최소 전투력의 실제 수치·출처 대조. 임의 P1 분석값을 서버 검증 증거로 사용하지 않는다.
- Q3: 그룹 탈퇴 후 기존 방 잔류·조회·탈퇴/파티장 이전의 권한/최소 회복 범위 대조.
- 완료 조건: 기존 확정 정책과 충돌하는 지점/기존 기준으로 회신 가능한 내용/사용자 새 결정 필요 항목을 분리해 #13에 회신한다. 신규 API/Flutter 구현·실기기 시험·정책 임의 확정은 제외한다.

## 후속 인수 — 현재 구현 마감과 분리

담당은 Backend 준비 후 사용자 실제 조작, Flutter는 결과 기록과 발견된 문제의 최소 수정이다. 재개 시 최신 실행 Backend 계약·사용자 인수 가능 상태를 확인하고 [설계36 §9](../backend-migration/36-roster-ownership-dispute-flutter-design.md#9-backend-준비-후-후속-실기기-인수)의 한 묶음을 사용한다. 실제 장비·24시간/공통기한·일괄 방어·새 기기/재실행·계정 전환·좁은 화면/큰 글꼴은 아직 통과하지 않았다. 이미 통과한 기존 정상 흐름은 반복 요구하지 않는다.

## 분리된 후속 대장

2026-10-19 협업 회신 게시·재조회 완료: [G1/G2 #12](https://github.com/heo0328/lostparty-backend/issues/12#issuecomment-6259124455), [모집 #13](https://github.com/heo0328/lostparty-backend/issues/13#issuecomment-6259125080), [G3 #16](https://github.com/heo0328/lostparty-backend/issues/16#issuecomment-6259125692), [소멸/이름재사용 #17](https://github.com/heo0328/lostparty-backend/issues/17#issuecomment-6259126286), [첫 기준레벨/수동 제외 #18](https://github.com/heo0328/lostparty-backend/issues/18#issuecomment-6259126990), [통계 #19](https://github.com/heo0328/lostparty-backend/issues/19#issuecomment-6259127594). 현재 #15는 D1~D4 코드/자동 검증을 마쳤고 실제 인수 대기다.

- G1/G2는 Backend 통합 보고를 접수했으며 Flutter 연결은 미완료다. G3 고정 `332a8ab9697ca1a8e0d2ebcc147169c54ce9161c`의 SPEC/OpenAPI와 기존 그룹장 계약을 대조했다. 최소 ACK→현재 GET·즉시 이전 후 별도 탈퇴를 소비하며 실제 모집 원천 전 조건부 해산은 비활성이다. G3는 Backend 작업 브랜치 push 완료·main/dev 미통합 보고 상태다.
- #17은 Backend의 소멸 근거/한계와 최소 계약 검토, #18은 영속 정책/DTO·동시성 초안 인계가 다음 행동이다. 자료 삭제나 과거 미선택 일괄 활성화는 승인하지 않았다.
- #19는 Backend 최종 초안에서 확정 기준과 제안을 분리해 예시를 제시한 뒤 검토한다. 최초 참가 type 고정·함께 집계의 경계 참가/해산 조건·평균 분모·그룹 조회 권한 상세는 미확정이며 #13 독립 구현을 차단하지 않는다.

| 범위 | 현재 상태/다음 행동 |
|---|---|
| 개별 캐릭터 세팅 갱신 | 회원 상세 페이지의 누락 기능. 자동전체 갱신/서버저장 재시도로 대체하지 않으며 별도 복구 작업 필요. |
| 그룹/모집 연결 | [선행32](../backend-migration/32-backend-domain-prework-requests.md), #12/#13의 최신 인계부터 확인. 과거 ‘G1 미게시’ 문구로 되돌리지 않는다. 기존 화면/조작을 재사용한다. |
| 한도/통계 | [한도34](../backend-migration/34-member-limits-and-room-restrictions.md)·[통계35](../backend-migration/35-weekly-member-and-group-statistics.md)의 확정 정책 보존. 기본15/5/10, 주간 KST수요일06시. BM 즉시 도입 아님. |
| 첫1700 신규 활성/수동 제외 보호 | 서버 영속 정책 인계·정식 계약 여부부터 확인. 기존1700은 최초 기본 선택이며 저레벨 수동 사용 허용. |
| 생명주기/이력 | [26](../backend-migration/26-roster-character-lifecycle-design.md)·[29](../backend-migration/29-scoped-character-identity-design.md). API 목록 기준/새 이름 새ID, 파티/이름재사용·claim/퇴역은 해당 기능 계약과 함께 확인. |
| QA/운영 | DB-03 구기기 삭제 정합성, QA-01 등록제거/구자료, AUTH-01 탈퇴재가입·릴리즈/OAuth 인수는 [후속14](../backend-migration/14-my-account-flutter-integration-plan.md#flutter-follow-up-20261014)·[점검24](../backend-migration/24-database-design-review.md). |
| 성능/애니메이션 | 사용자 보류. UI프레임·분석/중복계산·개별 저장 GET3+PUT1 최적화와 별/광채 재적용을 임의 재개하지 않는다. |

## 검증·자료 보존

정상 개발환경/DB/키는 계속 사용하며 베타 시작 직전에만 승인된 DB 내용 초기화를 한다. 새 환경 구축/기초 인수 재시작/Firebase 자료 승계는 요구하지 않는다. 기기 테스트는 사용자가 수행한다.

새 기기/재설치·OFF 제외/실패 재시도·로그아웃/계정 전환·실제 레이드 참가 관계 등 자동시험만으로 인수할 수 없는 잔여 조작은 각 후속의 수동 체크로 묶으며 완료로 확대하지 않는다. 일괄API 실측과 수동완료 성공 보고 등 이미 받은 결과는 반복 요청하지 않는다.

문서 정리 전 상세 단계/당시 SHA·순번/조건은 [원문 기록](history/scoped-account-cache-2026-10-18.md)에 보존했다. 이 원문은 현재 실행 지시가 아니다. 최신 기준은 이 문서·AI_CONTEXT·해당 기능 계약이다.
