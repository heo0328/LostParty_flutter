# 원정대 인증·분쟁 V2 — Flutter 연결 설계

기준 2026-10-19. **D1~D4 구현 구간 마감·dev 통합 대상**이다. 2026-10-19 사용자가 Backend 작업으로 현재 분쟁 실기기 검증이 불가능함을 알리고, 인수는 차후로 이관한 뒤 현재 구현을 완료·dev 병합/푸시하도록 승인했다. 실제 인수는 미확인 후속이며 현재 구현 마감의 차단 조건이 아니다. 최종 커밋/통합 근거는 DEV_LOG를 따른다. 기존 기본 인증 성공과 현재 계정 복원을 재개발하지 않는다.

- 작업 브랜치: `feature/roster-ownership-dispute`, 기준 `dev/deb2884dfcba6d105781036d174b2e085118606e`.
- 종료 기준: 기존 인증 흐름에 V2 진행 복원·도전/방어·현재 결과 반영·앱내 안내를 연결하고 회원/권한/기한/명령 복구 경계를 검증한다.
- 서버 기준: [Issue8 시간순144번째](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6245920315), Backend `7ba6297c5a574aa14c214bb9d3bf30edb692fc8f`의 [실제 OpenAPI](https://github.com/heo0328/lostparty-backend/blob/7ba6297c5a574aa14c214bb9d3bf30edb692fc8f/openapi/openapi.yaml)·[개발 안내](https://github.com/heo0328/lostparty-backend/blob/7ba6297c5a574aa14c214bb9d3bf30edb692fc8f/docs/ISSUE_8_OWNERSHIP_DISPUTE_DEVELOPMENT.md). 아래는 이 실행 계약을 소비하는 계획이다.
- 장기 정책 출처: [계약28](28-verification-client-preparation.md). 세부 서버 동시성/worker 정책을 클라이언트에 재구현하지 않는다.
- 공식 작업 [Issue15](https://github.com/heo0328/lostparty-backend/issues/15), 출처 인계 [Issue8 시간순153번째](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6249286430). 동시 게시된 [152번째 Backend 통합](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6249274152)의 dev/main `77a1fe53875ddbe1a972361c90468106815c6f5b`·계약 불변도 확인했다. 고정 V2 소비 SHA를 변경할 이유는 없다.

## 1. 현재 코드와 필요한 연결

| 현재 경로/책임 | 확인된 동작 | 이번 변경 경계 |
|---|---|---|
| `lib/app/backend_app.dart` | 앱 수명 V1 client/VM 생성, `/settings/game-account-verification`, 성공 후 현재 서버 재조회·이전 화면 복귀 | V2 controller/명령 저장·목록 발견을 앱 수명에 DI, 기존 route에서 V2 사용, 명시 proof/dispute 진입 추가 |
| `server_account_verification_client.dart`·`server_account_verification.dart` | V1 strict DTO, confirm 빈 body·DELETE204 | V1 형식 유지, V2 strict DTO/별도 client·명령 추가. V2 cancel은 POST200 |
| `server_verification_view_model.dart` | 단일 challenge·미확정 명령 메모리·회원 세대 fencing | V2는 여러 진행 proof/양측 분쟁을 ID로 관리. 기존 V1 pending을 V2 명령으로 변환하지 않음 |
| `server_verification_selection_view_model.dart` | 등록/캐릭터 선택·아이템레벨 정렬·본인 owned 일반 재인증 차단 | 일반 인증 차단 유지. V2 preview 소유 안내와 별도 방어 선택 모드 연결 |
| `server_verification_page.dart` | 간결한 장비 안내·빨간 필수 갱신 문구·좌취소/우확인·성공 복귀 | 선택→장비→분쟁 결과를 해당 단계만 표시. 페이지 dispose로 인증 취소하지 않음 |
| `BackendAccountLifecycle`·회원 model/runtime | 일괄 계정 복원·소유/revision/회원 경계·기본/주간 우선 갱신 | 현재 소유 변경 확인 시 기존 무효화/재조회 경로로 동기화. 별도 소유 DB/빌드 복제 없음 |
| `AppShell`·각 Page의 AppBar | shell은 하단 탭, 각 페이지가 AppBar 소유. 구 수동 인증 alert는 새 V2에 미연결 | 기존 제목을 감싸는 공통 안내 title 위젯을 실제 Backend route에 적용. 구 수동 repository/alert를 V2 근거로 사용하지 않음 |

파일명은 현재 위치 기준이다. 새 파일 후보는 `ownership_verification_models.dart`, `ownership_dispute_models.dart`, `ownership_dispute_client.dart`, `ownership_command_store.dart`, `ownership_dispute_controller.dart`, `ownership_notice_title.dart`로 하되 구현 때 계층/기존 helper 재사용을 우선한다. feature/account 밖에 별도 회원·권한 체계를 만들지 않는다.

## 2. 사용자에게 보이는 흐름

### 일반 인증과 새 인증 도전

1. 기존 ‘원정대 인증’ 진입을 유지한다. ‘등록 원정대 선택 / 캐릭터 검색’과 원정대→캐릭터 선택을 유지하며, 인증된 본인 원정대는 `원정대명 · 인증됨`으로 회색 비활성 표시한다.
2. 캐릭터 검색/최종 대상 확인은 V2 preview의 현재 소유 안내를 사용한다. 본인 소유면 `이미 인증된 원정대입니다.`로 일반 시작을 막는다. 타인 소유면 `다른 사용자에게 인증된 원정대입니다.`와 `장비 확인 후 24시간 방어가 시작됩니다.`를 짧게 표시한다. 검색·선택만으로 분쟁은 시작하지 않는다.
3. 사용자가 ‘인증 시작’을 누르면 장비 확인을 시작한다. 대상 서버/캐릭터·해제할 장비·남은 시간·장비 변경 확인/인증 취소만 노출한다. 진행 proof 대상은 중간에 바꾸지 않는다.
4. 필수 빨간 문구는 유지한다: **장비 변경 이후 캐릭터 선택창으로 이동하여 캐릭터 정보를 갱신하여야 합니다.** 다른 부위 변경 금지·무기/방어구 기본 착용 요건도 필요한 단계에서만 간결하게 안내한다.
5. 결과를 아래와 같이 구분한다. 장비 확인 성공을 소유 성공으로 일괄 처리하지 않는다.

| 현재 서버 결과 | 화면/행동 |
|---|---|
| `passed / verified` | 현재 등록/소유를 재조회하고 기존처럼 이전 화면 복귀. 인증 완료 문구만 짧게 안내 |
| `passed / dispute_opened` | ‘인증 도전 시작’과 서버 만료시각 표시. 분쟁 상세로 이어 현재 결과를 확인하며 ‘인증 완료’로 복귀/활동 해제하지 않음 |
| `passed / blocked` | ‘진행 중인 도전이 있습니다.’ 또는 ‘인증 도전이 가득 찼습니다.’. 성공 proof를 나중에 자동 분쟁으로 재사용하지 않음 |
| `pending / none` | 장비 확인 대기·불일치/조회 지연만 표시. 같은 proof에 허용된 확인/취소 사용 |
| `expired / cancelled / invalidated` | 만료/취소/대상 변경을 구분. 기존 실패를 성공으로 전환하거나 새 인증을 자동 시작하지 않음 |

분쟁 상세는 같은 인증 진입 아래의 선택 상태 또는 하위 경로로 연결한다. 별도 최상위 탭이나 계정 관리 중간 페이지를 추가하지 않는다. 기존 route에 `proofId` 또는 `disputeId`를 명시하며 `registrationId`와의 충돌/잘못된 UUID를 거부한다. URL ID는 조회 대상이지 권한 증거가 아니다.

### 기존 소유자의 방어

1. 앱이 현재 회원의 owner 분쟁을 받으면 제목 영역에서 안내한다. 도전 중에도 기존 소유자의 원정대 사용권을 미리 제거하지 않는다.
2. 안내 터치→원정대별 진행 분쟁 선택/상세→`원정대 방어`→해당 원정대의 유효한 본인 캐릭터 명시 선택→새 장비 확인 순서다. 안내 터치나 화면 진입만으로 방어 명령을 시작하지 않는다.
3. 방어 캐릭터는 원래 인증/도전 대상과 달라도 된다. 같은 원정대·현재 소유/usable·canonical ID/revision을 검사하며 **1700·활동 선택·대표·표시 수로 제한하지 않는다.** 목록은 기존 아이템레벨 내림차순, 임의 이름 자동 매핑 없음.
4. `equipment_expires_at`과 `defense_available_until`은 서버가 정한 값이다. 방어 장비 확인은 최대10분이며 공통 방어기한을 넘기지 않는다. 다른 도전자의 늦은 기한으로 방어 시간을 늘리지 않는다.
5. 방어 성공(`passed / defended`)은 현재 분쟁들을 재조회해 확인하고 기존 진입 화면으로 복귀·‘원정대를 방어했습니다.’ 안내. 같은 현재 소유권에 대한 일괄 종료를 표시하고 다른 진행 proof의 오래된 확인을 차단한다.
6. 이미 끝났거나 기한이 지난 분쟁은 현재 결과/처리 중 안내만 한다. `start_defense`가 없는 상태에 버튼을 만들지 않는다. 등록이 없으면 기존 원정대 등록 흐름을 통해 본인 등록을 복구하며 삭제 등록을 자동 부활시키지 않는다.

### 진행 확인·취소·처리 지연

- 인증 화면에 현재 회원의 ‘진행 중인 인증’과 ‘인증 도전/방어’ 항목을 간결하게 표시한다. 여러 건이면 사용자가 선택하며 최신 한 건을 임의 선택해 다른 원정대 작업으로 덮지 않는다. 현재 대상이1건으로 명확하거나 명시 ID로 진입하면 해당 진행을 바로 연다.
- 도전자는 현재 서버가 허용한 분쟁 취소를 할 수 있다. 장비 인증 취소와 분쟁 취소를 구분한다. 알럿은 취소/부정 왼쪽, 동의/실행 오른쪽이다.
- 24시간 종료 시 로컬에서 이전 완료를 만들지 않는다. `이전 처리 중`, `다시 처리할 예정입니다.`, `확인이 필요합니다.` 등 현재 phase/reason에 맞춘 짧은 안내를 사용한다. `settle`는 예약 ACK이므로200만으로 소유권을 변경하지 않는다.
- 재조회는 화면 복귀/명시 갱신·현재 대상 기한 도달 시 GET으로 처리한다. 일반 상황에서 의미 없는 ‘상태확인’ 버튼을 나열하지 않는다. 조회 실패 때만 `다시 불러오기`, 미확정 명령에는 `요청 다시 확인`을 사용한다. 숨은 자동 confirm/cancel/settle와 상시 polling은 도입하지 않는다.
- 통신 중 본문 높이·카드 순서를 바꾸지 않는다. 기존 탭/제목 통신 표시 방식을 재사용하며 레이드 체크/i를 분쟁 로딩 표시로 사용하지 않는다.

### 2-1. 기존 인증 페이지에 추가하는 표시 방향 (2026-10-19)

사용자 기준은 현재 API 인증 페이지의 디자인과 기존 기능 동작을 최대한 유지하면서 분쟁 상태에 필요한 설명·버튼만 추가하는 것이다. 실제 `ServerVerificationPage`의 제목/16px 본문 여백, 등록 원정대 선택·캐릭터 검색 전환, 원정대/캐릭터 선택, 인증 시작, 기존 장비 안내 카드와 빨간 필수 문구·취소/확인 배치를 기준으로 삼는다. 아래 세부 배치·아이콘·문구는 구현 전 브리핑 제안이며 UI 구현 완료나 별도 디자인 변경 승인으로 간주하지 않는다.

- 일반 인증에는 기존 선택·시작·장비 카드 흐름을 유지한다. 타소유 대상일 때만 선택 영역의 인증 시작 버튼 위에 짧은 소유/24시간 안내를 추가한다.
- 진행 분쟁이 있을 때만 기존 본문에 같은 카드 스타일의 ‘원정대 인증 도전/방어’ 상태 영역을 추가한다. 기존 선택 폼과 장비 카드를 재배치하거나 별도 대시보드/최상위 탭·필수 중간 화면으로 교체하지 않는다. 진행이 한 건이면 카드 안에서 바로 내용을 보여주고, 여러 건이면 해당 영역 안에서 명시 선택한다. 통신 중 카드 순서를 흔들지 않는다.
- owner 카드 제안: 작은 방패 윤곽 아이콘 + ‘원정대 방어 필요’, 대상 원정대·방어 가능 기한·짧은 설명 ‘다른 사용자의 인증 도전이 있습니다.’와 주 버튼 ‘원정대 방어’. 이후 기존 캐릭터 선택·장비 확인 UI를 방어 문맥으로 재사용한다. 방어 버튼이나 안내 진입만으로 서버 방어를 시작하지 않고 캐릭터 선택 후 명시 시작한다.
- challenger 카드 제안: 작은 시계 아이콘 + ‘인증 도전 진행 중’, 대상·기한과 ‘기존 소유자의 방어를 기다리고 있습니다.’를 표시한다. 서버가 허용할 때만 보조 버튼 ‘도전 취소’를 둔다. 장비 확인 성공을 ‘인증 완료’로 표시하지 않는다.
- 기한 이후에는 시계/정보 아이콘과 ‘이전 처리 중’ 또는 ‘확인 필요’를 현재 서버 상태에 맞춰 표시한다. 방어 불가 상태에 ‘원정대 방어’를 노출하지 않는다. 확정 결과는 같은 영역에서 짧게 표시하고 기존 성공 복귀 규칙을 따른다.
- 앱 상단은 기존 확정안대로 제목 아래 작은 ‘원정대 방어 필요 · 확인’, 좁으면 경고 윤곽 아이콘을 사용한다. 색만으로 의미를 전달하지 않고 텍스트/접근성 라벨을 함께 제공한다. 새 전면 팝업·외부 알림·읽음/닫기 기능은 추가하지 않는다.

D1은 DTO/client·명령/journal 기반만 구현하므로 이 표시를 연결하지 않는다. D3/D4에서 이 기준에 맞춰 최소 추가하며, 현재 배치에서 크게 벗어나는 변경이 필요하면 변경 지점과 영향을 먼저 설명한다.

### 2-2. D3 실제 연결 경계

`ServerVerificationPage`는 앱 소유 controller를 받아 새 인증을 같은 배치의 `OwnershipVerificationBody`에 연결한다. 기존 V1 미확정/진행은 V1에서 해소하며 취소/만료 후 새 인증은 V2로 전환한다. 기존 선택 VM/정렬·인증됨 비활성·빨간 장비 문구·취소좌/확인우를 재사용한다. 일반 인증은 ‘인증 시작’에서 preview 후 바로 시작하고, 타소유일 때만 먼저 설명을 표시한 뒤 명시 시작을 받는다.

페이지 소유 `OwnershipVerificationViewModel`은 preview/선택·명시 명령만 조율한다. 방어는 dispute의 본인 registration ID로 기존 strict lifecycle 페이지를 끝까지 조회하고 같은 구조/revision·중복/cursor/최대200 검사를 통과한 usable 캐릭터를 레벨순으로 표시한다. 저레벨·비활동을 제외하지 않고 canonical ID/4개 revision을 전달한다. controller GET·환경/회원 guard를 재사용하며 페이지 종료는 명령 취소/저장 삭제가 아니다.

명시 proofId/disputeId GET, 복수 진행 선택, 이력 조회와 미확정 복구/현재 GET/검토 후 명시 재조정을 연결했다. URL ID는 권한 근거가 아니며 registrationId와 동시 지정·잘못된 UUID는 동작을 막는다. 현재 verified/defended만 성공 복귀하고 dispute_opened/settle 접수는 복귀하지 않는다. 성공 후 앱 controller의 기존 동기화를 재사용하고 standalone 소비만 기존 onVerified를 호출한다. 후속 GET과 복귀 예약 경합 및 회원 전환의 늦은 이동을 막는다. D3 직접 영향84고유PASS·변경7파일분석0, 실제 서버·기기 인수는 미확인이다.

## 3. 앱 상단 안내 — 사용자 선택 확정

사용자 선택: **기존 제목 아래 작은 문구 `원정대 방어 필요 · 확인`, 공간이 좁으면 경고 아이콘으로 축약**한다.

- 기존 AppBar 높이·뒤로가기·우측 action·본문 시작점을 유지하며 `title` 안의2줄 구성으로 표시한다. 큰 글꼴/좁은 폭에서 제목·터치 영역이 맞지 않으면 안내 텍스트만 경고 아이콘으로 축약하고 의미 있는 접근성 라벨을 제공한다. overlay로 기존 버튼을 가리지 않는다.
- 의미는 서버 현재 `viewer_role=owner`, active이며 실제 `start_defense` 또는 이어갈 유효 방어 proof가 확인되는 상태다. 공통기한 이후·처리 보류는 `원정대 인증 처리 중 · 확인` 또는 `원정대 인증 확인 필요 · 확인`으로 구분해 방어 가능으로 오해하지 않게 한다. 레이아웃은 같은 슬롯을 쓴다.
- 로그인 후/복귀 때 앱 소유 controller가 조회한다. 페이지 생성마다 중복 조회하지 않고 로그인/키/상세 자동갱신·bootstrap 완료를 기다리지 않는다. 제목이 있는 Backend 탭·하위/설정 페이지를 같은 위젯으로 연결하고 로그인/런치·모달 위에 강제 배너를 띄우지 않는다.
- 안내 터치는 인증 목록/명시 분쟁 조회로 이어진다. 이미 그 화면이면 중복 push하지 않는다. 뒤로가기는 원래 페이지로 돌아간다.
- 안내를 닫거나 읽음으로 서버 상태를 바꾸는 기능·새 배지 숫자·외부push는 추가하지 않는다. 조회 실패를 해결/빈 정상으로 덮지 않고 마지막 확인 안내를 유지하되 권한 있는 동작은 현재 GET 이후에만 실행한다.

## 4. API·DTO와 권한 경계

D4 실제 연결: Backend MaterialApp builder의 OwnershipNoticeScope는 앱 controller/명시 이동만 제공한다. 실제 Backend 탭·원정대/캐릭터 관리·상세/이력·설정/키·V1/V2 인증 title이 OwnershipNoticeTitle을 사용하며 기존 제목/leading/actions/flexibleSpace·본문은 유지한다. scope가 없거나 안내가 없으면 원래 child를 그대로 반환한다. 제목 위젯은 조회/쓰기 없이 controller를 구독한다. 공간/글꼴을 측정해 2줄이 안 맞으면 제목 옆 48px 경고 아이콘으로 축약하고 접근성 라벨/실행·키보드 조작을 제공한다. 로그인/진입/모달에는 새 안내를 만들지 않는다.

OwnershipNoticeNavigation은 단일 owner면 명시 disputeId, 복수면 선택 진입을 사용한다. 현재 인증 페이지와 연타는 중복 push하지 않고 뒤로가기를 보존한다. URL 표시 옵션과 독립된 GoRouter.state.uri로 실제 현재 경로를 판별한다. 안내는 방어 명령을 보내지 않는다. 실패한 방어 proof를 과거 상태만으로 ‘방어 필요’ 근거로 삼지 않도록 현재 GET 확인도 요구한다. D4 직접 영향68고유PASS·변경18파일분석0이며 최종 사용자 수동 체크는 NEXT_WORK를 따른다.

실제 OpenAPI에서 다음 **11동작**과 필수/nullable/enum·본문을 대조했다. 같은 경로의 GET/POST는 서로 다른 동작이다.

| API | 정상 결과/소비 |
|---|---|
| POST `/v2/game-accounts/preview` | 200 PreviewV2: 기존 preview + ownership_context + server_now. 멱등키 없음 |
| POST `/v2/me/game-account-verifications` | 201 VerificationV2. direct는 source/character_name, 등록은 source/registration_id/expected_registration_version/target_character 필수·상호배타 |
| GET 같은 목록 경로 | purpose=all/claim/defense, view=active/all, limit/cursor |
| GET `.../{proof_id}` | 200 현재 VerificationV2 |
| POST `.../{proof_id}/confirm`, `/cancel` | 각200 VerificationV2, `{expected_version}` |
| GET `/v2/me/ownership-disputes` | role=all/challenger/owner, view=active/all, limit/cursor |
| GET `.../{dispute_id}` | 200 현재 DisputeOut |
| POST `.../{dispute_id}/cancel`, `/settle` | 각200 DisputeOut, `{expected_version}`. settle는 예약 |
| POST `.../{dispute_id}/defenses` | 201 VerificationV2, expected_dispute_version + 현재 캐릭터 selection(등록/캐릭터ID와4개 expected revision) |

- 모든 요청은 기존 BackendRegistrationApi/App Bearer·401 회복·no-store·오류 envelope를 재사용한다. 변경 POST만 UUIDv4 Idempotency-Key를 요구한다. V1 parser/enum을 늘려 억지 호환하지 않는다.
- VerificationV2 필수18필드, DisputeOut 필수16필드, 페이지 envelope `{items,next_cursor,feed_revision,server_now}`를 strict 검사한다. UTC·strict integer>=1·UUID·null·중복/action·상태/결과 조합·요청 ID/대상 일치를 검증한다. 미지 결과/형식은 쓰기 불가·재조회 오류이며 임의 성공이나 V1 fallback을 하지 않는다.
- 목록 기본20/최대100, cursor<=2048. cursor는 actor/filter/feed/논리 기한에 묶인다. 409 CURSOR_STALE이면 같은 회원/필터의 새 첫 페이지부터 다시 모으고 서로 다른 snapshot을 합치지 않는다. 실패/부분 페이지를 전체 빈 목록으로 적용하지 않는다. 무한 자동 재시도 없음.
- 서버 `allowed_actions`는 현재 UI 안내이며 최종 명령도 서버가 검사한다. 클라이언트 타이머·preview·기존 ACK만으로 허용 동작을 추가하지 않는다. proof에서 `view_dispute`를 따라간 뒤 dispute GET을 확인한다.
- 대상 표시 이름은12자/최대2줄 기존 정책, 정렬/저장 정밀도 유지·화면 소수점 없음·시각 초까지다. 타회원 user/등록 UUID나 개인자료를 새로 노출하지 않는다.

## 5. 수명·복원·미확정 명령

앱 수명은 `BackendApp`이 소유한다. controller는 `(환경, 회원UUID, session generation, 요청 ticket)`과 대상 ID/version을 확인한다. 소유 변경 결과 적용에는 최신 ownership/lifecycle/read generation도 확인한다. 페이지 수명은 선택/표시/카운트다운 구독만 소유하며 화면 이탈은 서버 인증 취소가 아니다.

### 시작·복귀와 새 기기

1. 로그인 확정 후 본인 proof active·분쟁 active를 독립 조회(single-flight)한다. 자동 상세 API와 무관하게 진행하고 기본 화면/4초 진입을 막지 않는다. 복귀/명령 결과/기한 도달 이벤트는 같은 조회로 합친다.
2. 시작 응답을 모르는 새 기기는 서버 목록→명시 proof ID 현재 GET→같은 장비 안내/확인/취소로 이어간다. 기기 세션 ID를 인증 신원으로 쓰지 않는다. 키 교체·소유 변경 등 stale proof는 서버 결과를 따른다.
3. known active ID가 목록에서 사라지면 해당 현재 GET으로 terminal을 확인한다. 빈 active 목록을 인증 성공/이전 실패로 추정하지 않는다. 새 기기의 종료 결과는 인증 화면의 view=all 조회/페이지로 확인할 수 있다.
4. 목록과 상세가 바뀌어도 사용자가 고른 캐릭터/진행 proof를 자동 교체하지 않는다. 동일 원정대 묶음은 본인의 현재 registration ID 등 확인된 연결로만 구성한다. 이름만으로 여러 분쟁을 동일 원정대라 확정하지 않는다. 연결이 없는 direct 대상은 별도 항목으로 유지한다.

### 원명령 복구

- 네트워크 전송 전에 회원/환경별 secure storage에 immutable method/path/body/key·생성시각·현재 대상·ACK/현재GET 대기 단계를 기록하는 `OwnershipCommandStore`를 둔다. 기존 SecureMemberWeeklyStore의 저장 패턴/secure storage를 재사용하되 별도 namespace와 스키마버전을 쓰고 기존 주간 key/SQL schema는 변경하지 않는다.
- 토큰·개인API키·장비 원본은 journal에 넣지 않는다. 디스크 저장 실패면 해당 쓰기를 시작하지 않는다. 시작 응답 유실은 원key/body만 복구한다. 명령/ACK 미확정인 동안 같은 대상 새 start로 우회하지 않는다.
- ACK 수신 뒤 현재 GET 실패면 성공 명령을 새 명령으로 재실행하지 않고 현재 조회를 재개한다. GET 성공/목록1건만으로 미확정 원명령 ACK를 수신했다고 단정하지 않는다. 목록의 최근 항목을 이 기기의 원명령이라고 추정하지 않는다.
- ACK 복구는 서버24시간 보장/Retry-After와 충돌 코드를 따른다. 기한이 지났거나 key 충돌이면 blind replay·새 key 자동발급 없이 목록/현재 GET으로 조정하고 명시 새 행동을 받는다.
- 로그아웃/다른 회원/환경 변경은 메모리·타이머·표시를 즉시 분리하고 늦은 응답을 차단한다. 이전 회원 journal은 같은 회원이 돌아왔을 때만 복구 후보로 읽으며 자동 명령 재송신하지 않는다. 같은 회원 새 세션은 현재 인증을 재검증한 후 원명령을 복구할 수 있다.
- V1이 메모리에 가진 pending은 기존 V1 client로만 해소한다. V1 proof/key/body를 V2로 바꾸거나 테스트 자료를 이관하지 않는다. 기본 V1 regression은 보존하고 새 UI의 신규 시작은 V2로 일관되게 보낸다.

### 5-1. D2 구현 계약

`OwnershipDisputeController`는 `BackendApp` 수명에서 한 번 만들고 로그인/복귀·명령 결과·서버 기한 이벤트를 처리한다. 기존 키 복원/캐릭터 bootstrap·상세 갱신·4초 진입을 대기하거나 대체하지 않는다. 환경·회원·세션 identity와 읽기 세대, 단일 store writer를 사용한다. API client에도 환경 유효성 guard를 전달해 journal 저장 중 환경이 바뀌거나 늦게 온 성공/오류가 옛 환경 결과를 새 화면에 반영하지 못한다.

- proof/분쟁/journal을 독립 single-flight로 읽는다. 목록은 끝까지 수집한 뒤 revision·중복ID/cursor 순환을 검사해 원자적으로 표시하며 CURSOR_STALE은 첫 페이지부터1회만 재수집한다. 중간 실패는 마지막 관찰을 유지하고 current 표시를 내린다. 새 기기의 단일 진행만 현재 GET으로 자동 복원하고 여러 건은 명시 선택한다. 재정렬/다른 목록 결과가 사용자 선택을 바꾸지 않는다.
- 알려진 active ID가 목록에서 사라져도 현재 GET에서 종료가 확인될 때까지 관찰을 보존한다. 404/실패는 완료 근거가 아니며 마지막 owner 안내를 ‘확인 필요’로 유지하고 동작 권한은 차단한다. `history()`는 view=all 전체 목록을 반환하며 현재 GET/권한 확인을 대신하지 않는다.
- 로그인/재실행은 미확정 원명령을 자동 POST하지 않는다. `recoverCommand`는 동일 key/body를 명시 복구하며 awaitingCurrent이면 GET만 재개한다. ACK 후 GET 실패를 즉시 POST/GET 반복으로 감추지 않는다. 429/Retry-After는 명시 재시도 최소 대기다.
- 24h 경과·멱등 충돌·확정 revision/terminal 거절은 재조정 대상으로 남긴다. `reviewReconciliation`이 양측 view=all 전체 목록과 알려진 대상 현재 GET을 읽은 뒤, 별도 명시 확인 `acknowledgeReconciliation`으로 `reconciled` 기록을 남긴다. 원key/body/시각은 보존하고 ACK/성공·최근 목록과의 연결을 추정하지 않는다. 동일 key 재전송은 계속 금지하고 새 행동만 새 명령으로 받는다. 이는 DB/서버 자료 삭제나 자료 이전이 아니다.
- 서버 시각+단조 경과시간으로 표시/단발 조회를 계산한다. 같은 기한을 주기 polling하지 않으며 기한 후엔 방어 버튼의 근거로 과거 actions를 사용하지 않는다. 상단용 notice는 owner의 방어 가능/처리 중/검토 필요/조회 확인 필요 상태만 제공하고 UI는 D4에서 연결한다.
- 현재 GET의 verified/defended/transferred/OWNER_CHANGED가 확인되면 기존 lifecycle command gate/read generation을 먼저 무효화하고 기존 등록/계정 bootstrap·설정/역할/주간 재조회 흐름으로 연결한다. 다른 기존 writer가 있으면 stale 읽기를 즉시 막고 동기화 대기를 보존한다. ID/version/결과별 중복 효과와 같은 이벤트의 실패 즉시 반복을 막으며 실패 동기화는 후속 읽기/명시 재시도로 재개한다. 도전 개시/settle ACK만으로 기존 소유권을 제거하지 않는다.

D2 표적 검증은 controller25·V2client21과 별도 직접 회귀128건(총174 고유)이며 전체 Flutter 시험은 미실행이다. 초기 신규 controller 반환 타입/가상 시간 fixture 실패는 해당 파일/실패 사례만 수정·재실행했고 나머지 통과 결과는 재사용했다. 최종 변경5파일 분석0, 실제 서버·실장비/24h·기기 인수 및 V2 UI 연결 완료로 확대하지 않는다.

## 6. 시간·최종 이전·자료 반영

- 장비 남은 시간은 equipment_expires_at, 도전자 자신의24시간은 defense_deadline, 소유자의 실제 방어 가능시간은 defense_available_until이다. server_now+단조 경과시간으로 화면만 계산하고 복귀 때 다시 GET한다. 타이머는 권한/소유를 쓰지 않는다.
- 원정대당 진행3건·장비 성공 시점 정원 검사·선성립 처리·일괄 방어·앞 분쟁 보류·등록 한도20·파티영향 guard는 서버 책임이다. 다른 분쟁 때문에 로컬에서 만료시각을 늘리거나 승자를 고르지 않는다.
- transferred/defended/invalidated 등 현재 결과 변화는 ID/version으로 중복 효과를 막고 기존 계정 runtime을 무효화·서버 bootstrap/등록·소유/lifecycle·설정·역할/주간을 재조회한다. 그룹 대표 projection은 서버가 바꾸며 향후 그룹 화면에서 현재 GET을 소비한다. 미구현 그룹 화면을 이번에 만들지 않는다.
- 도전 시작은 소유 변경이 아니므로 옛 owner의 사용권을 제거하지 않는다. 실제 ownership revision 변경 뒤에만 기존 캐시 접근을 차단한다. 양측이 서로의 개인빌드/설정/주간 완료/그룹 회원/파티 자리를 승계하지 않는다.
- 새 owner의 unconfigured/활동 빈 상태는 ‘활동 캐릭터 미선택’이며 인증 실패가 아니다. 이전 owner의 ownership_lost 등록ID 존재도 사용권으로 해석하지 않는다.
- `PARTY_IMPACT_REVIEW_REQUIRED`는 서버 안전 보류다. 현재 파티 후처리 adapter 미제공 상태를 Flutter가 해결/강제 이전하지 않으며 관련 파티 기능 후속과 연결한다.

## 7. 구현 단위와 회귀 보호

| 구간 | 포함 범위 | 완료 조건 |
|---|---|---|
| D0 | 고정 계약·실경로 대조, 브랜치/이슈 분리·문서·상단 안내 선택 | 설계 완료 |
| D1 | strict DTO/client·immutable 명령·journal·페이지 DTO | 구현/표적55PASS·변경8파일분석0, UI 미연결 |
| D2 | 앱 수명 controller·로그인/복귀 목록·현재 결과·미확정 복구·소유 반영 | 내부 연결/표적검증 완료, 표시·조작 UI는 D3/D4 |
| D3 | 기존 인증 선택·장비 확인 V2 연결, 도전/방어 상세·현재 결과 | 완료. 직접 영향84고유PASS·변경7파일분석0. 본인 재인증 차단·타소유 사전 안내·다른 유효 캐릭터 방어·성공 복귀 유지 |
| D4 | 공통 title 안내·실제 router/DI·회귀/통합 검증·인계 | 코드/자동 검증 완료. 68고유PASS·변경18파일분석0. 구현 마감. 실제 서버/기기 인수는 Backend 준비 후 후속 |

각 구간마다 불필요한 전체 시험/실기기 요청을 반복하지 않는다. 테스트는 함께 작성하고 독립 기능 구간 종료 시 직접 영향 시험을 모은다. D1은 기존 V1/Router/DI/DB/앱 수명을 변경하지 않아 신규V2·기존V1/HTTP/세션5파일 표적시험과 변경8파일분석만 수행했다. D2~D4 최종 연결 때 공유 계약/호출자·저장 경계의 실제 파급으로 전체 시험 필요성을 판단한다. 수정 파일 수/라우팅 명칭만으로 전체 시험을 자동 실행하지 않으며 동일 코드 결과는 재사용한다.

자동 경계: strictDTO/nullable/enum·양측권한·3건/중복 결과 소비·장비/분쟁기한 분리·동시 방어/worker 응답·만료/429·journal 저장 실패/응답 유실/ACK후GET 실패·새 세션/회원/환경/로그아웃 late·부분/cursor stale 목록·빈 목록0권한·최종 이전 전 권한 보존/이전 후 stale 작업 차단. 서버 원자성 시험을 Flutter에 중복 복제하지 않고 계약 소비 경계로 검증한다.

보존 목록: 기존 로그인/키·등록 CRUD/본부계정·본인 재인증 금지·캐릭터 선택/정렬·장비 안내/빨간 문구·성공 복귀·1700 최초 기본/저레벨 수동 사용·대표/활동/표시/count/드래그·나이스단 OFF·캐시 먼저/기본·주간 먼저/상세 후행·일괄GET·최대2worker·수동 체크/i·4초 진입·기존 카드/본문 고정. 관련 과거/누락/재진입/중복/실패도 보호한다.

사용자 기기 확인은 최종 기능 구간에서1회 묶어 전달한다: 새 기기 진행 복원, 타소유 사전 안내/장비 통과 후 도전, 기존 owner 방어/다른 저레벨 비활동 캐릭터 선택, 공통기한·최종 처리/보류, 로그인 전환/응답 유실, 뒤로가기·원래 페이지 복귀, 안내의 좁은 폭/큰 글꼴. 실제24시간/실게임 결과를 모의 시험 통과로 보고하지 않는다.

## 8. 제외·현재 대기

그룹/레이드 구현, 실제 room 소유이전 후처리 adapter, 외부push·운영자고정·Discord·통계/BM·성능최적화·애니메이션·DB초기화/자료이전/삭제·운영배포·기기 설치/조작은 제외다. 기존 개발환경/자료를 유지한다. 현재 V2 연결에 추가 서버 구현 대기는 없으며 계약 충돌이 실제 발견될 때만 Issue15에서 관련 항목을 좁혀 요청한다. [최신 Backend 회신](https://github.com/heo0328/lostparty-backend/issues/15#issuecomment-6249415434)과 실제 상태 기준 #8은 사용자 지시로 주제별 이관 후 보관 종료됐다. 원본은 과거 근거로 보존하고 V2 미완료 작업은 #15에서 이어간다. #16 그룹·#17 생명주기·#18 활동 자동추가·#19 통계는 이 작업에 섞지 않는다.

## 9. Backend 준비 후 후속 실기기 인수

2026-10-19 사용자 지시로 현재 Backend 작업 동안 테스트 불가·차후 재개로 분리했다. D1~D4 코드를 dev에 통합하는 것과 실기기 통과는 구분한다. PARTY_IMPACT_REVIEW_REQUIRED를 임의 해제하지 않는다.

실기기 설치·조작은 사용자가 수행한다. 개발환경/기존 자료를 사용하고 인증을 위한 실제 장비 변경은 사용자가 직접 한다. 두 앱 회원의 도전/방어에는 사용자가 조작 가능한 원정대를 사용한다. 한 항목만 실패하면 해당 증상/시각/화면을 근거로 좁혀 조사하며 정상 항목을 반복하지 않는다.

1. 일반 인증: 기존 선택/검색→장비 변경·빨간 필수 안내→성공 후 원래 화면 복귀. 이미 본인 소유인 원정대는 일반 재인증을 차단한다. 기존 계정/활동·주간 체크/i와 화면 배치를 함께 확인한다.
2. 도전: 앱 회원A 소유 원정대에 회원B가 도전할 때 타소유/24시간 설명을 먼저 표시하고 명시 시작·장비 통과 뒤 ‘인증 도전 시작’과 기한을 표시한다. 이 시점에 인증 완료로 복귀하거나 A 사용권을 제거하지 않는다.
3. 방어/안내: A의 탭·설정·하위 화면에 안내가 나타나며 한 번 진입하고 뒤로가면 원래 화면으로 돌아온다. 같은 원정대의 다른 유효 저레벨/비활동 캐릭터를 선택해 명시 방어하고 장비 통과 뒤 관련 분쟁 결과/성공 복귀를 확인한다. 좁은 폭·큰 글꼴에서는 아이콘/읽기 라벨과 기존 버튼·본문 위치를 확인한다.
4. 복원/실패: 진행 중 화면 이탈·앱 재시작/다른 기기에서 목록→현재 GET으로 복원한다. 미확정 요청은 명시 복구만 하고 ACK후 조회 실패는 현재 GET만 재개한다. 로그아웃/다른 회원 전환 시 이전 진행·이력/늦은 복귀를 노출하지 않는다. 네트워크 실패 때 마지막 확인 안내를 해결로 지우지 않는다.
5. 24시간/공통기한: 실제 서버 시각의 방어 기한·처리 대기/재시도/검토 필요·최종 결과를 확인한다. 기한 후 ‘방어 가능’으로 표시하거나 settle 접수만으로 소유권을 바꾸지 않는다. PARTY_IMPACT_REVIEW_REQUIRED는 미구현 실제 파티 후처리의 정상 보류이므로 강제 이전/실패로 바꾸지 않는다.
6. Backend 준비 후 사용자가 인수를 재개하고 결과를 Issue15와 DEV_LOG에 기록한다. 이상이 발견되면 최신 dev에서 별도 수정 작업으로 재현·수정·직접 검증한다. 이 후속 인수는 현재 구현 구간의 dev 통합을 막지 않으며 실제 통과로 간주하지 않는다.
