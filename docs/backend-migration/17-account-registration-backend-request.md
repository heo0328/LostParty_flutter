## Flutter 조회 결과 인계·다음 등록 관리 구간 Backend 요청

요청 출처: Flutter Codex / 사용자 승인. 다음 목표는 내 계정 탭의 캐릭터명 검색 → 서버 본/부계정 등록 → 등록 캐릭터 조회 → 표시명/본계정 수정·등록 제거·요약 갱신입니다.

### 1. 소비 버전과 현재 Flutter 결과

- Backend 구현/계약: `254cb5de125ab1bcb2aa084e091eae976e9a078a`, 게시 기록 `406004e`, 브랜치 `feat/3-account-restoration`. Backend dev/main에 업무 API가 통합됐다고 가정하지 않습니다.
- Flutter 저장소 `heo0328/LostParty_flutter`: Firebase 실행 경로 제거 `a160c6f`, 서버 조회 구현 `6f97190`, 문서 `363ebc2`, dev 통합/push `3cedd9dd5eda9c1188e66fa3264f386c080f2449`. 이후 이 요청은 문서 작업이며 기능 코드 변경은 없습니다.
- 구현: `GET /v1/me/game-accounts`, `GET /v1/me/game-accounts/{registration_id}/characters`만 연결했습니다. 등록·수정·제거·refresh, challenge, 활동/대표 쓰기 UI는 아직 연결하지 않았습니다.
- 자동 검증: Flutter 조회 경계 25개를 포함해 전체 1,159개 통과. 조회 구현 작업 트리 analyze 0, 기본 프로젝트 Android debug 빌드 성공·조회 기능 포함 확인. fake HTTP/세션 테스트로 회원/세션 전환의 늦은 응답, 401 갱신과 업무403 구분, 전체 페이지/세 revision·전체 settings 일관성, 부분 실패·중복·상한·malformed 응답을 확인했습니다. 실제 Backend 트랜잭션/실 provider 인수 결과가 아닙니다.
- 사용자 에뮬레이터 확인: Google 로그인 후 서버 등록 없음 안내, 로그아웃 후 로그인 필요 안내, 안내한 1·2·4번 정상 및 로컬 화면 보존. Base URL은 `http://10.0.2.2:8000`입니다. 등록이 없어 3번 실제 등록 계정의 캐릭터 화면은 다음 등록 구간에서 확인합니다.
- 이전 직접 읽기 smoke: 호스트 health 200, Bearer 없는 등록 목록 GET 401. `/openapi.json` 404는 업무 API 미구현 근거로 사용하지 않았습니다.
- 이번 조회 인수에서 재현된 Backend 결함은 없습니다. 빈 등록은 정상 결과입니다. 실제 등록/수정/제거/refresh, 활동·대표 저장, challenge pending/만료/취소, 업무 쓰기의 409/429/503·응답 유실 복구는 아직 인수하지 않았습니다. 이번 1·2·4 결과를 신규 쓰기나 재실행 전체 통과로 확대하지 않습니다. Backend 114 pytest는 귀측 보고로 구분합니다.

### 2. 다음 Flutter 구간은 기존 API를 사용합니다

| 기능 | 고정 계약에서 사용할 API | 요청 규칙 |
|---|---|---|
| 캐릭터명 검색/미리보기 | `POST /v1/game-accounts/preview` | `character_name`; 현재 계약에는 Idempotency-Key 필수 헤더 없음 |
| 본/부계정 등록 | `POST /v1/me/game-accounts` | `lookup_character_name`, `label`, `is_main`; UUIDv4 Idempotency-Key |
| 표시명/본계정 수정 | `PATCH /v1/me/game-accounts/{registration_id}` | `expected_version` 및 변경 필드; UUIDv4 Idempotency-Key |
| 등록 제거 | `DELETE /v1/me/game-accounts/{registration_id}` | query `expected_version`, UUIDv4 Idempotency-Key; 성공 204 |
| 서버 요약 갱신 | `POST /v1/me/game-accounts/{registration_id}/refresh` | 빈 object `{}`, UUIDv4 Idempotency-Key |

기존 구현을 재작성하거나 동일 API를 추가할 필요는 없습니다. Flutter는 preview/등록을 소유 인증 성공으로 취급하지 않으며 서버 UUID와 로컬 정수 ID·자료를 분리합니다. 같은 사용자/동작의 재전송은 key와 payload를 고정하고, 응답 유실·진행중 응답은 동일 요청 복구와 GET으로 판별합니다. 자동 새 key 쓰기나 로컬 자료 자동 등록은 하지 않습니다.

### 3. Backend에 요청하는 준비·보완 범위

1. **등록 구간의 실제 테스트 준비 상태를 인계해 주세요.** 실행 중인 로컬 서버가 위 업무 구현 버전과 additive `0002`를 사용하는지, 기존 실행/검증 기록을 기준으로 확인해 주세요. 이를 위해 DB 초기화·자료 삽입·운영 배포를 진행하지 마세요. 서버가 아직 다른 버전이라면 현재 버전과 필요한 안전한 실행 절차를 먼저 알려주세요.
2. **서버용 `LOSTARK_API_TOKEN` 준비 여부를 값 없이 알려주세요.** 아직 준비되지 않았다면 사용자가 로컬에서 설정할 파일 위치·변수명·적용 절차만 안내해 주세요. 키 값이나 `.env` 본문을 Issue에 게시하지 마세요. Flutter 개인 API 키를 자동 업로드하는 방식은 사용하지 않습니다. 키가 없을 때 외부 조회의 `503 UPSTREAM_UNAVAILABLE`는 예상 제한으로 다룹니다.
3. **실제 preview → 등록 → 등록/캐릭터 GET을 시험할 수 있는 조건을 명확히 해 주세요.** 현재 provider adapter가 실제 siblings/summary 응답을 소비할 준비가 됐는지, 기존에 확보한 검증 근거와 미확인 사항을 나눠 인계해 주세요. 실응답과 계약이 다르면 이번 등록·요약 조회에 필요한 adapter/오류 처리만 보완하고, 식별정보를 제거한 근거와 변경 SHA를 제공해 주세요. 장비 소유권 인수 전체 완료를 등록 UI 연결의 선행 조건으로 만들지는 않습니다.
4. **고정 계약과 런타임 차이가 있으면 대상만 보완해 주세요.** 경로·필수 헤더·nullable·본계정/version·DELETE replay·진행중/상한/외부 실패 의미가 기존 계약과 같은지 기존 테스트/문서를 기준으로 인계해 주세요. 차이가 없는 영역의 코드 수정이나 114개 전체 재검증을 반복할 필요는 없습니다. 변경이 필요하면 새 구현 SHA, 원본 OpenAPI 및 변경 요약, 대상 회귀 결과를 회신해 주세요. 기존 인증6API·회원 principal/세션 정책과 완료된 두 조회 API는 보존합니다.

### 4. 완료 인계와 제외 범위

회신에 구현/실행 버전, 등록 구간의 키 준비 여부(값 없음), 바로 시험 가능한 기능과 예상 제한, 필요한 사용자 로컬 준비 절차를 구분해 주세요. 수정했다면 계약/코드 SHA와 실행한 대상 검증을 함께 남겨 주세요. Flutter는 이를 반영해 등록 UI/Repository를 연결한 후 신규 등록·수정·제거·갱신 및 로컬 보존을 사용자에게 한 번에 인수 요청하겠습니다. 결함이 발견되면 동작·기대/실제·HTTP status/error.code/request_id를 비밀정보 없이 보고하겠습니다.

`PROVIDER_EVIDENCE_PENDING`, `ROSTER_EVIDENCE_PENDING`, refresh 누락의 suspect 보류 정책은 유지합니다. 공개 mock/증거 우회, 임의 소유권/성공 fixture의 개발 DB 삽입, Firebase/테스터 데이터 이관, DB 초기화, 운영 배포는 요청하지 않습니다. 장비 인증·소유권 이전 및 활동/대표 쓰기 Flutter 연결은 이후 별도 그룹입니다. Issue #3은 열어 둡니다.
