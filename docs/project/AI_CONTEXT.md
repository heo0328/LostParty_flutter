# AI CONTEXT (2026)

## 최우선 현재 상태 — 기존 그룹 레이드 listing 보완 (2026-09-01)

- 다음 우선 작업은 listing이 없는 기존 그룹 전용 모집을 일괄 보완하는 것이다. 방을 바꾸는 동안의 자연 복구는 `codex/raid-listings-sync`에 있다.
- 직전 완료: listing 원자 동기화. 브랜치 `codex/raid-listings-sync`. 만석·완료·다음 주 대기는 listing을 유지하고 전체 공개 전환·방 해산만 삭제한다. 표적 테스트 통과. 디바이스 미연결로 실기기 확인은 보류. Rules 배포는 별도 지시.
- `recruitments` list에 그룹 membership `exists`나 `visibility==group` 쿼리를 쓰지 않는다. 자격 박탈·필터는 그다음이다.

- 파티장이 그룹 레이드 상세에서 `그룹만 공개`를 끄면 전체 공개, 다시 켜면 그룹 전용이 된다. `groupId`는 유지한다. 전체 공개→그룹 전용은 비그룹 멤버·pending 신청이 있으면 거절한다.
- 전환 Transaction이 모집 `visibility`/`revision`만 패치하고, 그룹 전용이면 listing을 만들거나 덮어쓰며 전체 공개면 listing을 삭제한다. `recruitments` list에 그룹 membership `exists`나 `visibility==group` 쿼리를 쓰지 않는다.
- 사용자가 Rules를 배포했다. 비그룹 계정 모집에서 그룹 전용 숨김, 해제 후 표시, 재활성 후 숨김을 확인했다. Git SHA는 로그로 확인한다.
- 다음 우선 작업은 자리·인원·상태에 맞춘 `raidListings` 갱신이다. listing이 없는 기존 방 보완과 그룹 전용 자격 박탈이 그다음이다.
- 2026-09-01 사용자는 다음 구현 원칙에 동의했다. 모집 원본과 listing은 동일 Transaction에서 원자 동기화하고, 현재 모집 Snapshot 구조를 유지한다. 만석·완료 취소 가능·다음 주 대기처럼 재노출 가능한 상태는 최신 값으로 유지하며 전체 공개 전환·방 해산 같은 되돌릴 수 없는 종료는 삭제한다. 그룹 전용 모집의 listing이 없으면 변경 시 자연 복구한다. 과거 방 일괄 보완은 다음 단계다.
- 구현 전 실제 모집 변경 Repository와 공개 카드 매퍼를 대조하고, 상태별 생성·덮어쓰기·삭제 및 동기화 필드를 write plan·Rules 테스트로 고정한다. Rules는 `getAfter()` 원본과 listing 핵심 값의 일치를 강제한다. 상세 기준은 `FIRESTORE_PARTY_COMMAND_CONTRACT.md` §4.2.1과 `NEXT_WORK.md`를 따른다.
- 직전 완료: 그룹장 즉시 이전·1차 해산. 브랜치 `codex/group-leader-exit`, 커밋 `e7ce461`. 활성 그룹 레이드는 모집 원본 status로 판정한다.

- 사용자가 그룹만 공개 방을 만들고 그룹원이 레이드 모집 리스트에서 보는 흐름이 동작한다고 확인했다. 기능 커밋 `61fd464`는 병합 커밋 `25c3b44`로 `main`에 통합·푸시됐고, 로컬 `main`과 `origin/main`이 일치한다.
- 일반 레이드는 `groupId=null`/`public`. 그룹 레이드는 가입 그룹 하나와 `그룹만 공개` 기본값. 생성 트랜잭션이 `groups/{groupId}/raidListings/{recruitmentId}`에 모집 스냅샷을 같이 쓴다.
- 모집 리스트는 공개 `recruitments` 쿼리를 먼저 내보내고, `players/{id}/groupMembershipState/current`의 `activeGroupIds`별 listing을 합친다. listing·state 오류는 공개 목록을 죽이지 않는다.
- `recruitments` list는 `canListRecruitment`(공개/리더/멤버 필드)만 사용한다. 그룹 membership `exists`와 `visibility==group` 목록 쿼리는 쓰지 않는다. listing `list`는 경로의 `isCurrentGroupMember`만 본다.
- 책임자·확정 멤버 본인 방은 모집 리스트에서 제외한다. listing이 없는 생성 이전 그룹 전용 방은 변경 시 자연 복구하고, 손대지 않은 방은 일괄 보완 전까지 안 보일 수 있다.
- 이후 listing 갱신, 기존 listing 보완, 그룹 전용 자격 박탈을 완료하고 마지막에 레이드 모집·현황 그룹 필터를 구현한다.
- 필터 제품 기획은 `GROUP_PRODUCT_FLOW.md` §8·§15에 이미 있다. 필터 구현 직전 정의·적용 화면·포함/제외 범위·상태 보존·무효 선택 정리·완료 조건을 사용자와 반드시 재확인하며, 검토와 문서 보완이 끝나기 전에는 필터 코드를 수정하지 않는다.

## 직전 상태 — 그룹장 즉시 지정 이전·해산 (2026-09-01)

- 브랜치 `codex/group-leader-exit`. 기술 기준 `GROUP_LEADER_EXIT_DISBAND_CONTRACT.md`.
- 그룹장은 유효한 일반 그룹원을 선택해 수락 없이 즉시 그룹장을 넘기고 일반 멤버로 남은 뒤 기존 탈퇴를 별도로 실행한다. 이전 요청 문서는 만들지 않는다.
- 1차 해산은 마지막 1인·pending 관계 없음·활성 그룹 전용 레이드 없음·활성 초대코드 없음에서 soft delete한다.
- 초대코드는 기간 만료가 없다. 원문은 그룹에 없어 앱 재시작 후 화면에 다시 보이지 않으며, 복사해 둔 코드를 입력해야 폐기할 수 있다.

## 직전 상태 — 모집 생성 UI(A) 통합 (2026-08-31)

- `codex/recruitment-create-layout`에서 A를 구현했고 사용자가 실기기 확인 후 커밋·main 머지 커밋·푸시를 지시했다.
- A: 제목 유지, 한 줄 배치, 복수 역할만 작은 드롭다운, 선호 포지션 선선택, 역할/캐릭터 높이 맞춤, 항목 간격 확대. 생성 전용 역할 배치는 수정 화면에 넣지 않았다.
- 모집 상세: 회차 완료 후 해산 전 또는 반복방 다음주 대기에 `이번주 레이드완료`를 상단 모집 제목과 같은 크기·오류색으로 표시. 사용자 실기기에서 모집 완료와 표기 크기를 확인했다.

## 최우선 현재 상태 — 그룹 전투력 수정 실기기 확인 완료 (2026-08-31)

- codex/group-combat-power-display / 기반 HEAD 99a3598에서 구현했다. 사용자가 그룹원 간 전투력 표시의 정상 작동을 확인하고 커밋·main 머지 커밋·푸시를 지시했다. 이전 실기기 대기 기록보다 이 절이 우선한다. 다음 기능은 아직 지정되지 않았다.
- 그룹 로컬 표시값 조회에 가장 최근 유효한 저장 세팅 전투력 fallback, active 소유권 필터를 적용했다. CharacterCombatPowerSyncGateway로 그룹 상세 진입 시 본인 소유 캐릭터별 서버 전투력을 보강한다.
- 본인 membership Snapshot은 로컬 null로 서버 숫자를 지우지 않으며, 실패를 사용자에게 안내하고 저장 목록은 계속 표시한다. 새로고침과 멤버 상세 요청의 중복을 막는다.
- 전체 flutter test --no-pub 666개, flutter analyze --no-pub 문제 없음. 사용자 실기기에서 그룹원 간 전투력 정상 표시를 확인했다. 장애·권한 실패 등 개별 시나리오까지 실기기로 검증한 것으로 확대하지 않는다. 이후 코드 변경 없이 문서만 갱신해 기존 자동 검증을 재사용한다.
- Rules/설정/인덱스·레이드 코드는 변경하지 않았고 배포도 하지 않았다. 기존 Character Rules의 광범위한 쓰기 허용은 별도 부채이며 이번 Repository 검증을 Rules 강화로 혼동하지 않는다.
- 원격 보존 브랜치는 유지한다. 통합 기준은 main이며 사용자 승인에 따라 기능 브랜치 푸시 후 --no-ff 머지 커밋과 main 푸시를 수행한다. 다음 실행은 NEXT_WORK에 따라 사용자 작업 지정을 기다린다.

## 최우선 현재 상태 — 그룹 전투력 표시 수정 준비 (2026-08-31)

- 사용자 최신 실기기 보고: 레이드 모집·탈퇴·완료 체크 정상. 그룹 생성·초대·일반 탈퇴·초대코드 생성·가입 정상. Rules 배포 성공을 현재 운영 기준으로 삼는다.
- 아래 과거의 503 배포 차단·R0 우선 실행·전체 재설계 대기 기록은 현재 실행 지시가 아니다. 409 원인은 로그 없이 동일 내용 중복으로 확정하지 않으며, 다음 실제 Rules 수정 시 재배포 여부를 확인한다. 현재 배포 실험·Rules 최적화는 하지 않는다.
- 남은 사용자 보고: 그룹원 목록과 상세 캐릭터 목록에서 전투력이 누락됨. 기존 그룹 하나는 표시되지만 새 그룹은 본인·그룹원 모두 누락. 원인 확정과 실기기 수정 확인은 아직 미완료다.
- 전투력 membership Snapshot 저장·본인 self-refresh는 `3df755b`에 커밋되어 main과 현재 브랜치에 포함된다. 이 커밋 이후 준비 시작점 `75bedb9`까지 lib 변경은 없고, 미커밋 앱 코드와 stash도 없었다. 코드 유실 증거는 없다.
- 읽기 경로 차이: 그룹원 목록은 membership Snapshot(+Character fallback), 상세 인증 캐릭터 목록은 Character 문서다. Character 최소 정보 동기화에는 combatPower가 없으며, self-refresh는 실패를 삼킨다. 이것이 새 그룹 누락의 확정 원인이라는 뜻은 아니다.
- 보존 지점 `ed02b31`, 브랜치 `codex/rules-complexity-reduction`은 원격 푸시 완료. Rules 사본 2개를 원본 그대로 포함했다. main `ea2019a`는 유지한다.
- 다음 작업 브랜치 `codex/group-combat-power-display`는 보존 지점에서 분기한다. 현재 작업 준비만 수행하며 기능 코드·Rules·배포 설정은 변경하지 않는다. 상세 범위는 `NEXT_WORK.md`를 따른다.
- 이후 문서·규칙에서 과거 상태와 충돌하면 본 절 및 NEXT_WORK의 최신 사용자 보고를 우선한다.

## 과거 작업 기록 — Rules 복잡도 개선 계획 (2026-08-31, 현재 실행 지시 아님)

- 기준 코드 `25f88ff`, 전용 브랜치 `codex/rules-complexity-reduction`. Rules 소스 143,799 bytes, 표적 테스트 33개 통과이나 이후 사용자 지시의 전체 Rules 배포도 컴파일 검사 503으로 실패했다.
- 현재는 추가 코드 변경 전에 시작점·단계별 작업 계획을 문서 커밋으로 고정한다. 다음은 R0 검증 환경 확인 → R1 그룹 가입 검증 공통화이며 나머지는 순차 후속이다.
- 전체/최소 Rules 모두 로컬 Emulator 로딩 오류가 있어 실제 Rules 검증은 미완료다. 정책·UX를 보존하고 스키마 변경은 별도 설계 검토한다. 과거의 전체 재설계 대기 기록보다 NEXT_WORK의 현재 실행이 우선한다.
- 상세: [`TASK-11-FIRESTORE-RULES-COMPLEXITY.md`](TASK-11-FIRESTORE-RULES-COMPLEXITY.md).

## 프로젝트
- LOSTPARTY
- Flutter 기반 로스트아크 레이드 모집 앱
- AI 기반 개발 (ChatGPT + Cursor)

---

## 아키텍처
- MVVM
- feature-first 구조
- repository pattern
- 로컬 캐릭터 데이터와 Firebase 멀티유저 파티 시스템 분리
- Firebase Auth + Firestore + 클라이언트 Transaction + Security Rules 기반. Callable Functions·유료 기능은 별도 지시 전까지 보류

---

## 브랜치 기준
- 통합 기준 브랜치: `main`
- 현재 저장 브랜치와 커밋은 `NEXT_WORK.md`의 기준 상태를 따른다.
- 2026-08-28 Task-084 대표 Character 동기화 구현 `f15c1b6`과 후속 문서를 `main`에 통합했다.
- Task-080 F(Claim-only 게이트·orphan assignment self-heal·다음주 prep 캐릭터 변경·재완료 orphan Claim 정리) 완료. 복잡 꼬임은 BUG-007 보류.
- Task-083에서 `PlayerId` 기반 운영자 지정, 인게임 채팅 스크린샷 수동 인증, 기존 소유자 24시간 방어·자동 이전, 대상 계정 인증 금지, 사용자 확인과 `lastSeenAt` 계약을 확정했다. 사용자 삭제는 보류한다.
- Task-084 운영자 권한·마지막 접속 기반 코드와 Rules·표적 테스트를 구현했다. 전체 테스트 456건과 `flutter analyze`가 통과했고 Rules는 `lost-party`에 배포했다. 실기기 `lastSeenAt`, active 운영자 지정, 설정의 `사용자 확인`과 목록 표시를 확인했다.
- active `playerGameAccounts`의 대표 Character 서버 동기화, 서버 성공 후 로컬 반영, GameAccount별 5분 제한, 운영자 목록·상세 표시를 구현했다. 전체 테스트 464건과 analyze가 통과했고 해당 Rules를 `lost-party`에 배포했다.
- Task-086 기존 소유자 방어·자동 이전·강제 인증 핵심 구현과 Rules 배포·실기기 검증을 완료했다. BUG-008은 선택 필드 `defenseOfRequestId` 부재 Rules 평가 오류를 수정해 종료했다. 취소·일반 승인·분쟁 개시·운영자 거절·방어 승인·방어 실패·강제 인증과 양쪽 레이드 권한 반영을 확인했다. 실제 24시간 무응답 자동 이전만 미검증이다. 기능 커밋은 `8c649ad`다.
- 반복 레이드 진행 목록에 `금주 진행`·`다음주 대기` 상태 배지를 추가한 커밋은 `05a441d`다.
- 그룹 제품 흐름은 [`../product/GROUP_PRODUCT_FLOW.md`](../product/GROUP_PRODUCT_FLOW.md), Task-11 기술 계약은 [`../architecture/FIRESTORE_GROUP_MEMBERSHIP_CONTRACT.md`](../architecture/FIRESTORE_GROUP_MEMBERSHIP_CONTRACT.md)에 정리했다. membership·활성 신청·누적 횟수·신청 금지는 모두 Player 단위다.
- Task-11 구현은 `main`에 병합됐다(기능 커밋 `b673fdb`). 4번째 탭을 그룹으로 바꾸고 설정은 내 계정 톱니로 이동했다. 생성·검색·기본 상세·초대·신청·승인/금지·초대코드 생성·폐기·공개 토글·코드 즉시 가입을 포함한다.
- Task-11a(멤버 목록·일반 탈퇴·표시 Snapshot)도 `main`에 병합됐다(커밋 `3df755b`). membership `combatPowerSnapshot` 등은 가입·생성 시 저장하고, 그룹 상세 진입 시 본인 membership만 self-refresh한다. 타 그룹원 표시는 서버 Snapshot을 읽는다.
- **1차 마무리(2026-08-31):** 사용자는 Task-11·11a 1차를 종료하고 **전체 기획·설계를 재검토**한다. 새 지시 전 추가 구현은 중단한다.
- **과거 진단 기록 — Firestore Rules 복잡도:** 503 원인 확인을 위해 절반 축소 프로브를 1회 배포했으며 이후 원복·추가 수정·정상 배포와 실기기 확인을 완료했다. 프로브 잔존이나 현재 운영 차단으로 취급하지 않는다. 당시 경과는 [`TASK-11-FIRESTORE-RULES-COMPLEXITY.md`](TASK-11-FIRESTORE-RULES-COMPLEXITY.md)에 보존한다.
- 실기기(2026-08-31): Rules 정상 배포 후 레이드 모집·탈퇴·완료 체크, 그룹 생성·초대·탈퇴·초대코드 생성·가입과 그룹원 전투력 표시를 확인했다.

---

## 완료 상태

### Firebase 초기 연결 완료와 단계적 구현 전환

- Firebase 프로젝트 ID `lost-party` 기준 FlutterFire 플랫폼 설정 생성 완료
- Android 앱 패키지 `com.example.lost_party` 등록 정보 일치 확인
- Android Google Services Plugin 연결 완료
- Android, iOS, macOS, Web 및 Windows용 `firebase_options.dart` 생성 완료
- 생성 옵션의 컴파일 기반인 `firebase_core`만 초기 연결 의존성으로 반영
- Firebase Core 앱 초기화와 준비·실패·재시도 부트스트랩 구현, 자동 검증 및 Android 실기기 정상 진입 확인 완료
- Anonymous Auth 로그인과 기존 인증 사용자 재사용 부트스트랩 구현, 자동 검증 및 Android 실기기 검증 완료
- `AuthUid -> PlayerId` 최초 생성·재사용 Transaction과 최소 Security Rules 구현·배포, 자동 검증 및 Android 실기기 검증 완료
- 게임 계정·Character와 파티 Firestore 데이터 기능은 아직 미구현
- Firebase Console의 Anonymous Auth와 Seoul 리전 `(default)` Firestore 생성은 사용자 완료 보고 기준
- Auth UID와 LOSTPARTY 영속 Player ID를 분리하는 방향을 사전 검토 문서에 기록
- 로컬 Fake 환경에서 제품 흐름과 UI를 검증하기 위해 두었던 Firebase 전역 구현 보류 정책은 종료
- 각 작업 단위의 데이터 계약, 권한, 실패 처리와 테스트 경계를 먼저 확정한 뒤 Firebase 구현을 단계적으로 진행
- 계약이 확정된 작업은 전체 백엔드 설계 완료를 기다리지 않고 독립 브랜치에서 구현·검증 가능

### 구조
- 폴더 구조 생성 완료
- feature-first 구조 적용
- domain / data / presentation 분리 완료

### 레이드 데이터
- raid_base.dart 구현 완료
- raid_variation.dart 구현 완료
- local_raid_data_source.dart 구현 완료
- raid_master_repository.dart 구현 완료
- raid_master_repository_impl.dart 구현 완료

### 모집글 도메인
- party_recruitment.dart 구현 완료
- PartyRole / RecruitmentStatusType / ExperienceLevel enum 정의 완료

### recruitment_list 데이터 레이어
- recruitment_list_repository.dart 구현 완료
- local_recruitment_list_data_source.dart 구현 완료
- recruitment_list_repository_impl.dart 구현 완료
- mock 모집글 데이터 6개 작성 완료

### recruitment_list presentation layer
- recruitment_list_view_model.dart 구현 완료
- recruitment_list_page.dart 구현 완료
- recruitment_card.dart 구현 완료
- 앱 셸의 세 번째 `레이드 모집` 탭에 RecruitmentListPage 연결 완료
- mock 모집글 6개 화면 표시 완료

### Design System v1

- `Soft Lavender Gaming Utility`를 시각적 방향으로 확정했다.
- Material 3와 시스템 폰트를 유지하고 Light Theme을 우선 적용한다.
- Color·Spacing·Radius token과 공통 `AppTheme.light`를 추가했다.
- Neutral Surface, muted purple Primary, Lavender 선택 상태와 최소 semantic 상태색을 정의했다.
- Bottom Navigation은 흰색 Surface와 Lavender 선택 Pill을 유지한다.
- Firestore 공개 모집 목록에서 사용할 `PublicRecruitmentSummary` 기반 카드를 대표 Card로 시범 적용했다.
- 디자인 방향은 사용자 확인을 통과했으며 다른 화면은 자동 일괄 변경하지 않고 후속 기능 작업과 함께 점진적으로 적용한다.

### 앱 셸 및 내 계정
- StatefulShellRoute 기반 하단 탭 구조 적용 완료
- `레이드 현황 / 내 계정 / 레이드 모집 / 설정` 4탭으로 구성
- 레이드 현황은 `진행 중 / 신청 중 / 완료 기록` 상단 페이지로 구성
- 레이드 현황 읽기는 Firestore Party Read Model과 Drift 완료 기록에 연결됨 (Task-056)
- 진행 중·신청 중 카드와 완료 기록 숨김·정정 UX를 연결함 (Task-057)
- 진행 중·신청 중 카드에서 Firestore 읽기 전용 상세로 진입함 (Task-058)
- 모집 생성만 Firestore 명령으로 연결하고 성공 시 현황 상세로 이동함. Android 실기기에서 진행 중 목록·읽기 전용 상세·수정 미적용 안내를 확인함 (Task-059)
- IndexedStack으로 탭별 Navigator 상태를 보존하고 내부 TabBarView 스와이프와 분리
- Android 뒤로가기와 iOS 화면 전환을 고려한 공통 라우팅 기반 구성

### Lost Ark API 기반
- Dio 공통 클라이언트와 API 설정 구현 완료
- 요청 직전에 JWT를 읽어 Authorization 헤더에 적용
- JWT는 flutter_secure_storage에 보관하며 화면과 로그에 원문을 노출하지 않음
- 토큰이 없으면 네트워크 요청을 시작하지 않고 안내 후 앱 탐색을 계속할 수 있음
- HTTP 상태, 타임아웃, 네트워크 및 응답 형식 오류를 타입으로 구분
- `GET /characters/{characterName}/siblings` 연동 완료
- DTO, JSON 변환, mapper, remote data source, repository 계층 구현 완료
- 내 계정 화면에서 대표 캐릭터명으로 원정대 캐릭터 조회 및 최소 목록 표시
- Galaxy Z Fold6 실기기에서 JWT 저장, 캐릭터 검색, 실제 API 응답 확인 완료
- 종합 상세 API의 `ArmoryProfile` 연동 완료
- 조회 캐릭터의 전투력, 아이템 레벨, 전투 레벨, 직업, 서버 표시 완료

### 캐릭터 역할별 세팅 저장 설계
- 캐릭터 기본 정보와 역할별 상세 세팅 스냅샷을 분리하여 저장
- 동일 캐릭터를 역할마다 중복 저장하지 않고 하나의 캐릭터에 여러 스냅샷 연결
- 역할은 직업이나 각인으로 자동 확정하지 않고 스냅샷 저장 시 사용자가 선택
- 서포터형 직업은 바드, 발키리, 도화가, 홀리나이트의 4개 직업
- 서포터형 직업은 `support`와 `dealer` 스냅샷을 각각 저장 가능
- 그 외 모든 직업은 딜러군으로 분류하고 `dealer` 스냅샷만 저장
- 파티 지원 시 저장된 역할별 스냅샷을 기준으로 지원 가능한 역할 결정
- 역할 판정을 위한 자동 분석은 경고 또는 추천 용도로만 사용하고 사용자 선택을 우선

### 조회 캐릭터와 대표 캐릭터
- `lookupCharacterName`: siblings 및 최초 상세 API 호출에 사용하는 조회 기준 캐릭터명
- `representativeCharacterId`: 사용자가 앱 내부에서 선택한 계정 대표 캐릭터
- Lost Ark API가 공식 대표 캐릭터를 제공한다고 가정하지 않음
- 계정 최초 등록 시 조회 캐릭터를 로컬 대표 캐릭터 기본값으로 사용할 수 있음
- 대표 캐릭터는 같은 로컬 계정 그룹의 캐릭터 중 사용자가 선택
- 미인증 계정은 로컬 설정만 유지하고, active 서버 소유 관계가 있는 계정은 서버 CharacterId를 `playerGameAccounts`에 동기화
- 서버 동기화 계정의 대표 캐릭터 변경은 GameAccount별 5분 제한이며 Rules에서 서버 시각으로 강제
- 초회 보강은 서버 ID만 채우고 5분을 시작하지 않으며, 로컬 맞춤 기록이 있으면 내 계정 재진입에서 Firestore를 호출하지 않음
- 서버 저장 성공 뒤 로컬 값을 반영하고, 같은 값 재선택과 저장 중 연속 터치는 추가 요청을 보내지 않음

### 계정 로컬 DB 기반
- Drift `game_accounts`, `account_characters` 스키마 버전 1 구현
- 메인/부계정 구분, 계정 표시명, 조회 캐릭터명 저장
- 로컬 대표 캐릭터 ID와 기본 표시 개수 6개 저장
- 대표 캐릭터가 같은 계정 소속인지 저장 계층에서 검증
- 대표 캐릭터와 표시 개수 변경은 API 호출 없이 로컬에서 처리
- siblings API 조회 성공 시 메인 계정과 전체 캐릭터를 트랜잭션 저장
- 최초 조회 캐릭터를 로컬 대표 캐릭터 기본값으로 설정
- 재조회 시 사용자가 변경한 대표 캐릭터가 목록에 남아 있으면 선택 유지
- 저장된 메인 계정과 캐릭터를 앱 시작 시 로컬 DB에서 조회
- 계정당 기본 최대 6개를 반응형 2~4열 캐릭터 그리드로 표시
- 캐릭터가 6명 미만이면 저장된 실제 캐릭터 수만 표시
- 사용자 표시 순서 설정 전에는 아이템 레벨 내림차순으로 상위 6개 표시
- 사용자 표시 순서가 있으면 사용자 설정을 아이템 레벨 정렬보다 우선
- 조회 캐릭터 상세 API의 전투력을 해당 로컬 캐릭터에 저장하여 카드에 표시
- 상세 조회 전 캐릭터의 전투력은 `-`로 표시
- siblings 재조회 시 기존 전투력, 표시 여부 및 사용자 표시 순서 보존

### 테스트
- local_recruitment_list_data_source_test.dart 작성 및 통과
- recruitment_list_repository_impl_test.dart 작성 및 통과
- flutter analyze 이후 테스트 정상 동작 확인
- API 인증 저장소, Dio 클라이언트, DTO mapper, remote data source 테스트 추가
- 내 계정 ViewModel 및 페이지 테스트 추가
- 탭 이동, 스와이프, 토큰 안내 및 토큰 비노출 widget 테스트 추가
- flutter analyze 통과
- flutter test 61개 통과

---

## 데이터 구조 핵심

### RaidBase
- raidBaseId
- name
- partySize
- gateCount
- difficultyIds

### RaidVariation
- raidId
- raidBaseId
- difficultyOrder
- difficultyLabel
- minItemLevel
- clearGold / boundGold (모든 관문 완료 기준, 서로 별도 지급)

### PartyRecruitment
- id
- title
- raid (raidId + gateProgress)
- leader (characterName / className / role)
- memberSummary (currentCount / maxCount)
- recruitmentStatus
  - status (recruiting / closed / completed)
  - roles
    - dealer (current / target / remaining)
    - support (current / target / remaining)
- requirements
  - minCombatPower
  - experienceLevel (5단계)
- schedule
  - raidStartAt
  - maxPlayHours (null = 클리어시)
  - recruitmentOpenedAt
  - recruitmentClosedAt

---

## enum

### PartyRole
- dealer
- support

### RecruitmentStatusType
- recruiting
- closed
- completed

### ExperienceLevel
- tryLevel
- clearExp
- multiClearExp
- semiExperienced
- experienced

---

## 레이드 데이터 관리 방식
- 현재: local hardcoding
- repository 통해 접근
- UI는 데이터 소스 모름
- 추후 Firebase 교체 가능 구조

---

## 현재 상태 요약

- recruitment_list 기준 Domain / Data / Presentation Layer 1차 구현 완료
- 내 계정이 첫 화면이며 파티 모집은 두 번째 하단 탭에서 접근
- mock 모집글 6개가 RecruitmentCard 목록으로 표시됨
- UI는 ViewModel을 통해 데이터 조회
- ViewModel은 Repository를 통해 mock 데이터 조회
- Lost Ark API JWT 등록 및 안전한 로컬 보관 가능
- 대표 캐릭터명 기반 원정대 캐릭터 조회 가능
- 실제 Android 실기기 API 통신 검증 완료
- Drift로 메인 계정과 전체 캐릭터 기본 정보를 저장함
- 대표 캐릭터, 표시 여부, 표시 개수, 사용자 표시 순서를 로컬에서 관리함
- 대표 캐릭터는 항상 첫 번째로 표시되며, 숨김 시 아이템 레벨이 가장 높은 다른 캐릭터가 대표를 승계함
- Drift v2에서 캐릭터별 dealer/support 상세 JSON 스냅샷을 독립 저장함
- 같은 역할 갱신은 해당 스냅샷만 교체하며 계정 재조회 후에도 스냅샷을 유지함
- 캐릭터 카드에서 상세 화면으로 이동할 수 있음
- 상세 화면의 세팅 저장/갱신은 실제 종합 상세 API를 호출하며 테스트 fixture를 사용하지 않음
- 서포터형 직업은 dealer/support 저장 위치를 선택하고 두 스냅샷을 독립 유지함
- 상세 화면에서 룬, 보석 대상 스킬, 아크그리드 조건 및 포인트 경고를 표시함
- 실제 Fold6에서 딜러/서포터 세팅의 개별 저장 및 유지 확인 완료
- Galaxy Z Fold6 profile 빌드에서 캐릭터 관리 스크롤과 설정 유지 검증 완료
- AppBar와 Scaffold는 동일한 surface 배경을 사용해 스크롤 시 색상 변화가 없음
- 게임 카탈로그와 캐릭터 세팅 분석기가 연결됨
- 바드의 깨달음 1티어 노드로 `바드`/`딜바드` 계열과 support/dealer 역할을 감지함
- 감지 결과는 카탈로그 버전, 계열, 역할 및 일치 노드를 포함하며 사용자 저장 역할을 덮어쓰지 않음
- 미지원 직업, 계열 미감지 및 복수 계열 감지를 정상적인 분석 상태로 구분함
- 기존 armory 원본 JSON을 유지하고 스냅샷 로딩 시 현재 카탈로그로 분석 결과를 재생성함
- `CharacterBuildDraft`로 API 조회/분석과 승인 저장 경계를 분리함
- draft 생성은 원본 JSON, 프로필, 분석 결과 및 조회 시각을 메모리에 반환하며 로컬 DB를 변경하지 않음
- commit은 사용자가 선택한 역할을 우선하며 감지 역할이 달라도 저장을 허용함
- commit 시 선택 역할 스냅샷과 최신 프로필을 단일 트랜잭션으로 저장하고 반대 역할 스냅샷을 보존함
- 캐릭터 상세 화면의 세팅 갱신은 먼저 `CharacterBuildDraft`를 조회하고 스크롤 가능한 미리보기 다이얼로그를 표시함
- 미리보기에서 프로필, 계열 통칭, 감지 역할, 룬 및 분석 경고와 저장 역할을 확인할 수 있음
- 감지 역할과 선택 역할이 다르면 안내하지만 특수 세팅 저장을 허용함
- 취소 시 draft를 폐기하고 기존 데이터를 유지하며 승인 성공 후에만 스냅샷을 다시 로드함
- 조회와 commit 진행 상태를 분리하고 중복 요청 및 중복 저장을 방지함
- Galaxy Z Fold6 profile 빌드에서 미리보기 표시, 접힘/펼침 스크롤, 역할 불일치 안내, 취소 보존 및 선택 역할 저장 검증 완료
- 캐릭터 컬렉션 카드 크기는 이번 미리보기 범위에서 변경하지 않았으며 후속 요약 카드 확장과 가용 폭 기반 반응형 배치에서 조정 예정
- 서포터 바드의 세레나데 보석처럼 하나의 API 대상명이 복수 아이덴티티 스킬 효과를 함께 나타내는 경우가 있어 단순 이름 일치 시 정상 보석이 미확인으로 표시될 수 있음
- 복합 보석 대상은 UI 또는 분석기 하드코딩이 아니라 카탈로그의 별칭/효과 그룹 데이터로 해결할 예정
- 카탈로그 `gemSkillTargets`가 API 보석 대상 표시명과 하나 이상의 특수 스킬 ID 관계를 관리함
- 바드의 `세레나데 스킬`을 용맹/구원의 세레나데 복합 대상으로 분류하며 분석기에 바드 전용 분기를 두지 않음
- 일반 장착 스킬, 카탈로그 특수/복합 대상, 아이콘 근거 및 실제 미확인 대상을 순서대로 구분함
- Galaxy Z Fold6의 실제 서포터 바드 세팅에서 세레나데 보석 미확인 경고 해소와 정상 특수 스킬 표시 확인 완료
- 발키리 서포터의 `신앙 스킬`처럼 다른 직업에도 복합 아이덴티티 대상이 있으므로 실제 응답을 확보해 직업별 카탈로그 데이터로 점진 입력 예정
- Firebase Core, Anonymous Auth, Player binding, 게임계정 소유 인증과 Firestore 읽기 계약까지 반영됐으며 Functions 런타임은 사용하지 않음
- Firebase 파티 사용자 흐름의 최신 기준은 `../architecture/FIREBASE_PARTY_PRODUCT_FLOW.md`이며 기존 백엔드 구조는 `../architecture/BACKEND_PARTY_ARCHITECTURE.md`에서 관리
- AuthUid는 인증과 binding에만 사용하고 파티·신청·그룹에는 LOSTPARTY 영속 PlayerId를 사용
- 공유 파티 회차 상태, 활성 참가 점유와 개인 캐릭터 주간 완료 Claim을 분리
- 개인 Claim은 서버 권위 상태이며 내 계정 체크박스와 모집 생성·신청·가입 제한이 같은 값을 사용
- 파티는 기본 1회성이며 파티장 또는 공대장이 `다음 주도 함께하기`를 켜면 방과 다음 회차 준비 구성을 유지
- 반복 파티 완료 취소는 화요일 22:00까지 책임자만 가능하며, 완료 Snapshot과 현재 membership·책임자·역할·슬롯 및 해당 `partyOwner` Claim이 모두 그대로일 때만 전체 원자 롤백한다.
- 취소 성공 시 같은 `sourceRecruitmentId + sourceCompletionRevision`의 Claim 전원 삭제, assignment 전원 복원과 회차 복구를 함께 처리한다. 한 명이라도 Claim·구성·참가 상태가 바뀌면 부분 병합 없이 거절한다.
- 반복 파티의 다음 회차 준비 변경은 허용하지만 변경 즉시 이전 회차의 전체 완료 취소 권리를 포기하며, 수요일 오전 6시에 새 회차로 전환한다.
- 완료, 미완료 종료, 취소, 구성 변경과 해산 이벤트, 종료된 1회성 원본 및 회차 Snapshot은 28일 보관하고 반복 파티방은 해산할 때까지 유지
- 전체 알림은 새 방의 초기값으로만 사용하고 방별 알림은 독립 설정
- Task-072에서 Spark 앱 내부 알림을 먼저 구현하고 향후 신뢰 서버가 같은 Player Event를 소비해 FCM을 발송하는 2단계 계약을 확정함
- 알림 저장은 `players/{playerId}/events/{eventId}` 사용자별 투영본을 유지하고, 초기 읽음 상태는 별도 Drift 로컬 Projection으로 관리함
- 캐릭터별 주간 레이드 표시는 로컬 Drift에서 0~5개, 기본 3개로 관리하며 같은 raidId의 난이도를 중복 표시하지 않음
- Task-081: 캐릭터별 표기 수정, 원정대 일괄 표시 개수(입장 가능 수만큼 자동 축소), 선택 개수 항상 표시(접기 없음), 계정 헤더 레이아웃·내용 높이 Wrap 배치
- 기본(미설정) 3개 표시 순서는 골드 추천 후 입장 레벨 내림차순
- 개인 진행은 현재 주차 `미완료/완료`, 지난 회차 히스토리는 `완료/미완료 종료`로 구분
- 완료되지 않은 1회성 파티는 수요일 오전 6시에 자동 미완료 종료하며 반복 파티는 현재 구성을 새 회차로 승계
- 가입 승인과 정원 변경은 명령별 Firestore 클라이언트 Transaction과 Security Rules가 함께 검증. Rules로 충분히 보장할 수 없는 명령은 Spark 범위에서 제외
- 모집글 공개 범위는 `public`과 `groupOnly`이며 그룹 전용 글은 현재 멤버만 조회/신청 가능
- 계정 그룹은 사용자 ID 초대와 상대 수락 방식이며 멤버는 하위 컬렉션으로 저장해 제품 인원 제한을 두지 않음
- 초기 정책은 사용자당 소유 그룹 최대 1개, 다른 그룹 다중 가입 허용이며 구현 전 변경 가능
- flutter analyze 통과
- flutter test 188개 통과

---

## 다음 작업

현재 작업 순서와 완료 상태의 단일 기준은 `docs/project/NEXT_WORK.md`다.
Task-085 수동 인증 요청·운영자 1차 판정과 Task-086 기존 소유자 방어·즉시 이전 경로를 `8c649ad`에 구현했다. Rules는 사용자가 `lost-party`에 배포했고 핵심 실기기 검증을 통과했다. 24시간 무응답 자동 이전은 미검증으로 남긴다.
`codex/combat-power-auto-title`에서 전투력 표시 통일과 자동 모집 제목 구현 및 자동 검증을 완료했다.
`codex/full-recruitment-edit`에서 생성·수정 공용 폼, 전체 모집 수정 흐름과 공통 입력 지우기 동작을 구현하고 Android 실기기 검증을 통과했다.
완료 결과는 `main`과 `origin/main`에 통합됐다.

첫 Firebase Core 부트스트랩 구현과 Android 실기기 검증을 완료했다.
다음 단계부터 Firestore 데이터 계약, 클라이언트 Transaction 명령, Security Rules와 검증 범위를 기능 단위로 확정하면서 Firebase 구현을 진행한다.
Player binding의 계약·구현·Rules 배포와 실기기 검증을 완료했으며 다음 단계는 서버 GameAccountId·CharacterId 계약이다.
계약과 검증 범위가 정해진 기능은 구현할 수 있고, 아직 계약이 없는 서버 기능만 보류한다.

모집 생성의 대표 캐릭터 고정은 제품 요구와 맞지 않는다. 대표 캐릭터는 최초 추천값으로만 사용하고, 선택 레이드·난이도 조건을 기준으로 모든 소유 계정의 표시 캐릭터와 저장 역할을 파티장 후보로 제공한다. 레이드 변경으로 기존 선택이 무효가 되면 자동 교체하지 않고 사용자의 재선택을 요구한다.

---

## 직업별 기준정보 및 캐릭터 요약 확장 기준

### 용어
- `직업`: Lost Ark API의 `CharacterClassName`으로 식별하는 캐릭터 클래스
- `계열`: 직업별 깨달음 1티어 노드로 구분하는 세팅 분류
- `인게임 통칭`: 계열이나 주요 조합을 사용자가 부르는 표시 이름이며 API 원문 이름과 분리
- `역할`: 파티 지원 및 역할별 스냅샷 저장에 사용하는 `dealer` 또는 `support`
- `주요 아크그리드 조합`: 특정 계열과 추가 아크패시브 노드 및 코어 조건의 조합

### 데이터 소유와 저장 경계
- 직업, 깨달음 1티어 노드, 통칭, 역할, 아이덴티티/아크패시브 스킬 및 주요 아크그리드 조합은 앱에 포함된 정적 기준정보로 관리
- 정적 기준정보는 Git으로 버전 관리하는 JSON 카탈로그로 제공하고 UI와 분석기는 Repository를 통해 조회
- 캐릭터 개인 메모는 역할별 스냅샷이 아닌 캐릭터 공통 사용자 데이터로 저장
- 선호 조합은 캐릭터별 사용자 선택값으로 저장하고 정적 조합 정의와 분리
- 세팅 스냅샷 갱신, 정적 기준정보 업데이트 및 사용자 메모 수정은 서로의 데이터를 덮어쓰지 않음

### 분석과 역할 선택
- 깨달음 1티어 노드와 직업별 기준정보로 계열 및 역할을 감지
- 감지 역할은 추천과 경고를 위한 분석 결과이며 저장 역할을 자동 확정하지 않음
- 실제 저장 위치는 사용자가 선택한 역할을 우선
- 감지 역할과 선택 역할이 다르면 미리보기에서 안내하고 특수 세팅 저장은 허용
- API에서 새 세팅을 조회한 뒤 메모리에서 분석하고, 사용자 승인 전에는 기존 로컬 스냅샷을 변경하지 않음

### 카드와 반응형 화면
- 캐릭터 요약 카드는 캐릭터명, 직업, 계열 통칭, 역할, 개인 메모, 선호 조합 및 경고 요약을 공통 표현 대상으로 사용
- 내 캐릭터와 파티 지원자는 동일한 요약 표현 모델을 사용하되 각 기능의 도메인 데이터는 분리
- 좁은 화면은 1열, 펼친 Fold 화면은 2열을 중심으로 기기 종류가 아닌 실제 가용 폭으로 열 수를 결정

### 단계별 입력 원칙
- 첫 구현 단계에서는 정적 기준정보의 구조와 검증 규칙을 먼저 구현
- 직업별 노드, 통칭, 스킬 및 조합의 수기 입력은 카탈로그 구조가 확정된 뒤 별도 작업 단위로 진행
- 수기 입력은 우선 한 직업의 최소 샘플로 구조와 분석 흐름을 검증한 다음 전체 직업으로 확대

### 정적 카탈로그 Domain 구현 상태
- `shared/game_catalog`에 feature와 독립적인 정적 카탈로그 Domain 모델 구현 완료
- 카탈로그 버전, 직업, 계열, 특수 스킬, 주요 아크그리드 조합 및 코어 요구사항 모델 정의 완료
- 기존 account/recruitment 역할 타입은 변경하지 않고 카탈로그 전용 역할 타입을 사용하며 실제 분석 연결 단계에서 명시적으로 변환
- 스키마 버전, 필수 문자열, 중복 식별자, 지원 역할, 계열 참조 및 코어 포인트 범위 검증 구현 완료
- JSON asset 로딩 계층과 바드 최소 데이터까지 구현했으며 다른 직업 데이터는 아직 입력하지 않음

### 바드 1차 카탈로그 데이터
- Lost Ark API의 직업명은 fixture에서 확인된 한글 `바드`를 사용하고 영문 `BARD`는 별칭으로 저장
- 기본 역할은 `support`, 지원 역할은 `dealer`와 `support`
- `완벽한 화음`은 통칭 `바드`, 역할 `support`, 관련 추가 노드는 `세레나데 코드`
- `진실된 용맹`은 통칭 `딜바드`, 역할 `dealer`, 관련 추가 노드는 `템페스트 필드`
- `용맹의 세레나데`와 `구원의 세레나데`는 두 계열이 공통으로 사용하는 아이덴티티 스킬로 분류
- 세부 아크그리드 코어 조합은 1차 카탈로그에 입력하지 않음

### 아크그리드 상세 조합 후속 범위
- 1차 앱에서는 계열/추가 노드 발동 조건과 14P 최소 효과 및 유물 이상 17P 효과만 검증
- 직업별 전체 해/달/별 코어 수기 입력은 앱 1차 완성 이후 진행
- 사용자가 3코어 조합을 선택해 통칭과 숫자 순서 별칭을 지정하는 기능은 후속 범위
- 조합별 개인 메모와 지원자 장착 조합 일치 표시는 후속 범위
- 정적 코어 기준정보, 실제 장착 코어에서 계산한 일치 결과 및 사용자 메모를 서로 분리

### 현재 Cursor 인계 기준

- 최신 실행 작업 기준은 `docs/project/NEXT_WORK.md`이며 이 절 아래의 과거 인계 목록보다 우선한다.
- Task-050~054에서 Firestore 신청·가입·멤버 관리·회차 수명주기·Player 이벤트와 Drift v7 로컬 히스토리 기반을 구현했다.
- Task-056에서 실행 앱 Firebase 읽기·이벤트 동기화 1단계를 완료했다. 레이드 현황 세 탭은 Firestore 읽기 stream과 Drift 완료 기록을 사용한다.
- Task-057에서 진행 중·신청 중 카드, 완료 기록 숨김·정정 UX, 빈 목록 오프라인 안내 수정, `신청 중` collection group 규칙을 배포했다.
- Task-058에서 레이드 현황 목록을 Firestore 읽기 전용 상세(`/raid-status/:recruitmentId`)에 연결했다. Fake 모집 상세와 데이터를 섞지 않는다.
- Task-059에서 모집 생성만 Firestore 명령 Repository로 연결했다. Android 실기기에서 인증된 캐릭터로 만든 방이 `진행 중`에 나타나고 읽기 전용 상세로 연결되는 것을 확인했다.
- 신규 모집 단건 `get`이 문서 부재에서 거부되지 않도록 Rules를 보완해 `lost-party`에 배포했다.
- Task-060에서 인증 캐릭터 최소 정보 자동 동기화를 완료했다. `내 계정` 진입 시 1분 제한 siblings 조회, 변경분만 Drift·Firestore 반영, 수동 새로고침·대표 캐릭터명 자동 채움·서버 미반영 안내를 적용했고 Android 실기기에서 확인했다.
- Task-061에서 읽기 전용 현황 상세에 신청·철회 Firestore 명령을 연결했다. 신청 Character는 `serverCharacterId`만 사용한다. 단일 기기라 타 Player 신청 실기기는 보류하고 표적 테스트로 검증했다.
- Task-063에서 `레이드 모집` 공개 목록을 Firestore 페이징 읽기로 전환하고 `main`에 통합했다. 첫 20개 실시간 구독과 cursor 추가 조회, `/raid-status/{id}` 진입을 연결했다. Android 실기기·인덱스 배포 확인은 남는다.
- Task-064에서 파티장·파티원 표시 누락을 점검하고 다음 작업을 읽기/UI 복구로 재정의했다.
- Task-065에서 파티장 Snapshot·`PartyMemberDisplay`·`watchRecruitmentMembers`·공개 membership Rules(Option 1)·목록/상세 UI 복구를 완료하고 `main`에 통합했다.
- Task-066에서 즉시 가입·승인·거절·방 단위 재신청·N회 안내·단독 모집 삭제를 현황 상세에 연결하고 실기기에서 통과한 뒤 **`main`에 병합**했다. Rules(신청 get·재신청)는 `lost-party`에 배포된 상태다.
- Task-068에서 `partyIndex`/`slotIndex` 고정 슬롯 쓰기, 빈 슬롯 배정, 현황 상세 구성판 Card, 승인 시 신청자 점유 get Rules를 구현하고 실기기에서 즉시 가입·승인을 확인한 뒤 **`main`에 병합**했다. Rules(슬롯·점유 get)는 `lost-party`에 배포된 상태다.
- Task-069에서 구성판을 파티 그룹 반응형 배치로 바꾸고 breakpoint `600dp`·같은 자리 좌우 높이 맞춤을 적용해 바형·폴드 실기기에서 통과한 뒤 **`main`에 병합**했다.
- Task-070에서 현황 상세에 자기 참가 캐릭터 변경·탈퇴·추방을 연결하고, 상세 `recruitmentId` 재구독(BUG-001)을 반영해 실기기에서 통과한 뒤 **`main`에 병합**했다.
- Task-071에서 회차 완료·완료 취소·반복 설정·주차 전환·다인/완료 후 해산을 현황 상세에 연결하고, 1회성 완료 후 **해산 대기** 목록·이벤트 sync·탭 루트 복귀를 반영해 실기기에서 통과한 뒤 **`main`에 병합**했다. Rules(해산·완료 후 반복 설정)는 `lost-party`에 배포된 상태다.
- Task-072에서 알림 설계를 `PARTY_NOTIFICATION_CONTRACT.md`로 확정하고 **`main`에 병합**했다. FCM은 신뢰 서버와 유료 플랜 합의 전까지 보류한다.
- Task-073에서 공통 Party Event·유형별 Rules·신청/멤버십/해산 이벤트 연결·Drift 알림 receipt·현황 알림 UI를 구현했다. 다인 해산 Transaction 읽기 순서 버그를 수정해 실기기에서 확인한 뒤 **`main`에 병합**했다. Rules(알림 이벤트)는 `lost-party`에 배포됐다.
- Task-074에서 파티 회차·활성 점유·개인 주간 완료를 분리한 [`../architecture/WEEKLY_RAID_CLAIM_CONTRACT.md`](../architecture/WEEKLY_RAID_CLAIM_CONTRACT.md)를 작성해 `main`에 병합했다.
- Task-075 A에서 Claim Domain·DTO·mapper·Firestore 읽기 Repository와 내 계정 읽기 전용 체크박스를 연결했다. 자기 Player 읽기 Rules를 `lost-party`에 배포했고, 실기기에서 카드 레이아웃·모두 미체크인 읽기 전용 체크박스·기존 기능이 정상임을 확인했다. 전체 테스트 421개와 analyze가 통과했다.
- Task-079 E에서 책임자 전용 `파티 전체 완료`와 반복 파티 제한적 전체 완료 취소를 연결했다. `partyOwner` Claim·assignment 삭제/복원 Rules를 `lost-party`에 배포했고, 표적 테스트 36개와 analyze가 통과했다. 다중 기기 실기기는 Task-080 F에서 확인했다.
- Task-080 F에서 Claim-only 게이트·orphan assignment self-heal·다음주 prep 캐릭터 변경·재완료 orphan Claim 정리를 구현하고 실기기를 확인했다. Rules는 사용자가 `lost-party`에 재배포했다. 복잡 꼬임은 BUG-007 보류.
- Task-082에서 공개 모집 목록이 data 계층에서 현재 Player의 책임자·확정 멤버 방을 제외한다. Firestore 쿼리와 Rules는 바꾸지 않는다. 실기기(1대)에서 내가 만든 방 제외·pending 신청 유지·현황 목록 정상을 확인했다.
- 네트워크 요청을 시작하는 버튼은 진행 중 연타·중복 요청을 막는 공통 UI 규칙을 적용한다.
- Codex는 설계 계약, 문서 정합성, 작업 분해와 인수인계를 중심으로 유지하되 필요한 코드 수정은 가능하다.
- 유료 플랜·결제수단·과금 가능 기능, Emulator, FCM과 TTL 배포는 별도 승인 전까지 제외한다.
- Firestore SDK 캐시를 파티 Current State의 1차 로컬 Projection으로 사용하고 완료 히스토리만 Drift에 영속 저장하는 최소 정책을 적용 중이다.

### 과거 다음 채팅 인계 기록

아래 목록은 구현 이력 보존용이며 현재 작업 지시로 사용하지 않는다.
- 본계정·부계정 등록 및 관리 완료: 부계정 추가·삭제, 표시명 수정, 본계정 전환 및 계정별 캐릭터 관리 지원
- 빈 부계정 표시명은 중복되지 않는 `부계정N`으로 자동 지정하고 사용자 지정 표시명 중복은 거부
- 본계정 유일성과 부계정 삭제 시 저장 세팅·캐릭터·계정의 명시적 연쇄 삭제 보장
- 계정 관리 자동 테스트, `flutter analyze`, 전체 `flutter test` 209개 및 사용자 실기기 체크리스트 통과
- 과거 다음 작업은 캐릭터 아이템 레벨 기반 레이드·난이도 필터와 최고 난이도 기본 선택이었으며 현재 지시는 `docs/project/NEXT_WORK.md`를 따른다.
- 모집 생성에서 본계정·부계정 전체 표시 캐릭터 중 파티장과 저장 역할을 선택하는 기능 완료
- 복수 역할 캐릭터는 선호 포지션을 저장하고 후보 목록에서 한 행으로 표시하며 역할을 직접 전환 가능
- 내 파티에서 동일 캐릭터의 dealer/support 역할을 다른 캐릭터 경유 없이 바로 변경 가능
- 모집 삭제와 확정 점유 해제, 종료된 신청 후 다른 캐릭터 재신청 흐름 완료
- 일정 확인 기능은 기획 확정 전까지 Domain 코드는 유지하고 앱 UI 및 런타임 차단에서 숨김
- 관련 사용자 실기기 테스트 통과
- 바드 카탈로그 기반 계열 및 역할 감지 구현 완료
- Player별 회차 이벤트와 Drift 로컬 히스토리 동기화 기반 구현 및 자동 검증 완료
- 다음 구현은 `docs/project/NEXT_WORK.md`와 실제 최신 `main` 상태를 대조해 Cursor 작업으로 시작
- 제품 방향을 레이드 정적 카탈로그와 서버 기반 파티 모집/그룹 흐름으로 전환
- 카탈로그 파티 기준을 사용하는 모집 조건과 가입 승인 정책 Domain 구현 완료
- 신청·투표·가입 상태 머신 구현 완료
- FakeUserSession, Fake Repository, Fake Clock/ID 기반 로컬 다중 사용자 환경 구현 완료
- 로컬 Aggregate 기반 모집 목록·상세 및 모집 생성 UI 구현 완료
- 과거 다음 첫 단위는 내 계정 캐릭터를 사용하는 신청 UI였으며 현재는 완료된 이력이다.
- 신청·승인 UI 다음에 하단 `내 파티` 탭을 추가하고 `참여 중 / 내가 만든 파티 / 신청 중`을 분리해 표시
- 승인 대기 신청은 실제 가입 파티와 섞지 않고 신청 상태 확인·철회 대상으로 관리
- 다음 항목은 Firebase 전환 전 기존 로컬 구현 상태이며 새 통합 제품 정책과 구분함
- 레이드 주차는 KST 수요일 오전 6시 기준이며 기존 로컬 구현은 캐릭터가 한 난이도를 완료하면 같은 주차의 동일 레이드 전체 난이도에 귀속 처리
- 기존 로컬 구현은 승인된 파티원 한 명의 완료 선언으로 당시 파티원 캐릭터 전체의 주간 완료를 기록
- 파티원은 완료 전에 승인 역할·파티 자리를 유지하면서 조건을 만족하는 자기 캐릭터로 추가 승인 없이 교체 가능
- 최소 전투력·클리어 경험·최대 진행 시간은 미입력 시 제한 없음이며 카탈로그 입장 레벨과 파티 구성 규칙은 항상 적용
- KST 수요일 오전 6시 주차 계산, 난이도 공유 귀속 Fake 및 신청 명령 차단 구현 완료. Firebase 전환 시 로컬 완료는 사용자가 정정 가능한 1차 차단으로 변경 예정
- 저장된 역할 스냅샷을 기준으로 입장 레벨·전투력·기존 로컬 주간 귀속·파티 구성을 판정하는 신청 후보 UI 구현 완료
- 상세에서 신청·pending 확인·본인 철회 흐름과 제한 없음 표기 구현 완료
- 로컬 타 사용자 4막 노말 목 모집을 앱 시작 시 제공해 실기기 신청 흐름 검증 가능
- 신규 모집 가입 방식은 `파티장 승인 / 승인 없이 바로 가입` 두 가지로 단순화
- 즉시 가입은 조건 검증과 파티 배치를 신청 명령에서 완료하고 pending 상태를 만들지 않음
- 파티원 승인과 정족수 승인은 신규 생성 화면에서 숨기고 Domain 호환 목적으로만 유지
- Firebase 연결 전에는 모집/승인/그룹 Domain, Repository 및 Widget 자동화 테스트를 검증하고 실제 다중 사용자 승인 실기기 검증은 Firebase 연결 후 수행
- 파티 신청·확정 참가·캐릭터 변경의 최신 제품 규칙은 `docs/product/PARTY_PARTICIPATION_RULES.md`를 기준으로 사용
- 본계정과 부계정은 같은 실제 사용자의 소유이므로 같은 파티 중복 참가와 동시간대 확정 참가를 금지
- 동일 계정의 다른 캐릭터를 타 사용자처럼 사용하는 승인 실기기 테스트는 금지하며 실제 다중 사용자 승인 검증은 Firebase 연결 후 수행
- pending 복수 신청은 허용하되 최초 승인·즉시 가입·모집 생성만 확정 점유권을 얻고 충돌 pending은 자동 종료
- 실물 디바이스 테스트 시 작업자는 최신 APK 빌드 가능 브랜치와 체크리스트를 제공하고 사용자가 직접 빌드·설치
- `ActiveRaidAssignment`, `ParticipationConflictPolicy` 및 Fake Repository로 확정 참가 충돌 Domain 구현 완료
- 같은 모집의 동일 사용자, 같은 캐릭터·레이드, 사용자 단위 일정 겹침과 불명확한 일정 상태를 구분
- 모집 생성·즉시 가입·승인 명령에 확정 점유 획득 연결 완료
- 최초 확정 시 같은 사용자·캐릭터·레이드의 다른 pending을 `superseded`로 자동 종료하고 지연 경쟁도 점유 저장소에서 차단
- 로컬 Aggregate 저장 실패 시 점유 해제 보상 처리, Firebase에서는 점유·멤버십·pending 종료 단일 트랜잭션 필요
- 신청 후보의 `동일 레이드 신청 중 N개 / 참가 중 / 일정 충돌 / 일정 확인 필요 / 주간 완료` 구조화 읽기 모델과 상태 칩 UI 완료
- 기존 로컬 구현에서 pending은 비차단 안내, 확정 참가·일정·주간 완료는 차단 상태로 구분한다. 최종 Firebase 구조에서는 서버 Claim이 주간 완료를 강제하고 내 계정 체크박스가 같은 Claim을 조작한다.
- Account Repository의 본계정·부계정 전체 조회 계약을 추가했고 신청 후보 서비스가 모든 소유 계정의 표시 캐릭터를 통합 조회함
- 모집 생성·즉시 가입에서 동일 레이드 pending 건수를 확인하고 동의 시 기존 신청을 종료하는 UI 완료
- 승인형 모집의 복수 승인 대기 신청은 그대로 유지
- 파티 내 캐릭터 변경 후보·명령 구현 완료: 현재 역할 유지, 본계정·부계정 후보, 주간 완료·참가·구성 조건 검증, 확정 점유 원자 교체
- 대상 캐릭터에 동일 레이드 pending이 있으면 명시적 확인 없이는 Domain 명령이 거절되고, 확인 시 변경 성공 후 해당 pending을 종료
- 다른 확정 파티에서의 이동·스왑은 Firebase 트랜잭션 단계로 유지하며 다음 로컬 후보는 파티 탈퇴 Domain

### 레이드 정적 카탈로그 기반 구현 상태
- `shared/raid_catalog`에 feature와 독립적인 Domain, Mapper, Validator 및 Repository 구현 완료
- 카탈로그 스키마/데이터 버전, 갱신 시각, 레이드 ID/이름/정원/관문 수/활성 상태 정의
- 난이도 ID/이름/표시 순서/최소 아이템 레벨/보상 골드/활성 상태 정의
- 모집 참조는 `catalogVersion`, `raidId`, `difficultyId`, `selectedGates`로 검증
- 중복 ID, 빈 목록/문자열, 숫자 범위, 버전 불일치, 비활성 항목, 잘못된 난이도 참조 및 관문 범위 검증 완료

### 실제 레이드 카탈로그 입력 상태
- 사용자 인게임 확인 기준 주력 레이드 5개와 난이도 13개 입력 완료
- 4막, 종막, 세르카, 지평의 성당, 벨가르딘을 상위 필터 단위로 사용
- 일반/귀속 골드 분리, 정식 이름/표시명/별칭 및 난이도 표시 별칭 지원
- 4인 파티당 서포터 1명과 동일 딜러 직업 1명 제한을 카탈로그 수용 한도로 정의
- 기존 `raid_master` 정적 Dart 목록 제거 후 검증된 JSON Repository 기반 호환 매핑으로 전환
- 목 모집글은 `catalogVersion + raidId + difficultyId`를 참조하고 카드에 사용자 표시명을 출력

---

## 주의 사항

- UI에서 DataSource 직접 접근 금지 (Repository만 사용)
- JWT를 소스, 문서, 로그, 테스트 결과에 기록하지 않음
- 실제 토큰은 flutter_secure_storage를 통해서만 저장
- API DTO와 Domain Entity를 mapper로 분리
- Drift 저장 계층은 구현됐으며 스키마 변경 시 migration과 생성 코드 갱신 필요
- 서포터형 직업 목록 변경 가능성을 고려해 한 곳에서 관리
- 직업별 기준정보는 앱에 포함된 버전 관리 JSON, 사용자 메모는 로컬 DB로 분리
- 수기 기준정보를 `ArmorySkills`에 합쳐 장착 스킬로 오인하지 말고 별도 카테고리로 참조
- 아크그리드 조건은 깨달음 1티어 계열과 추가 활성 노드를 각각 검증
- API 호출 간격을 코드에 고정하지 않고 설정값 또는 서버 응답 기준으로 관리

## 2026-08-25 계정 소유 인증 인계

- 작업 브랜치는 `codex/server-account-character-contract`이며 `main`의 `0376cb4`에서 분기했다.
- `GameAccountId`·`CharacterId` 계약, Drift v6 매핑, 장비 소유 인증, 인증 완료 표시, 직접 입력 인증과 소유권 상실 차단을 구현했다.
- 인증은 Lost Ark API 토큰을 디바이스에 보관하고 앱이 장비 1~3개 해제 여부를 10분 안에 판정하는 Spark 전용 구조다.
- 유료 Firebase 서비스는 현재 사용하지 않는다. Functions 프로토타입은 최종 브랜치에서 제거했다.
- 클라이언트 판정 조작 위험은 초기 단계에서 수용하며, 서버 권한 검증은 사용자가 비용과 필요성을 별도로 승인할 때만 재검토한다.
- 사용자가 Android 실기기에서 캐릭터 인증 성공을 확인했다. 에뮬레이터는 현재 완료 조건이 아니다.
- 하단 탭은 `레이드 현황 / 내 계정 / 레이드 모집 / 설정`으로 확정했다.
- 첫 화면 `레이드 현황`은 상단 페이지 전환으로 `진행 중 / 신청 중 / 완료 기록`을 구분하며 완료 기록을 별도 하단 탭으로 분리하지 않는다.
- 기존 `내 계정`은 두 번째 탭, 기존 `파티 모집`은 `레이드 모집`이라는 세 번째 탭으로 이동한다.
- 설정 탭에는 `내 게임계정 인증`, Lost Ark API 토큰과 앱 공통 설정을 배치한다.
- 4탭 앱 셸·라우팅과 최소 진입 화면 구현을 완료했고 Widget 테스트 6개, `flutter analyze`, 전체 `flutter test` 252개가 통과했다.
- Android 실기기 확인을 완료했고 API 토큰 삭제 경고·확인 절차도 추가했다. 커밋 `84769f8`, 병합 커밋 `23af0b3`으로 `main`에 반영했다.
- 읽기 모델은 커밋 `0d94caf`, 병합 커밋 `7f9976e`으로 `main`에 반영했다.
- 당시 작업 브랜치는 `codex/firebase-party-commands-contract`였다. 이 항목은 과거 이력이며 현재 브랜치는 Git 상태로 확인한다. 유료 서비스 금지 원칙은 계속 유지한다.
- 파티 명령은 Spark의 Firestore 클라이언트 Transaction과 Security Rules를 기준으로 한다. Callable Functions와 서버 전용 검증은 보류한다.
- 명령 계약은 커밋 `ed93f90`, 병합 커밋 `1295cd6`으로 `main`에 반영했다.
- 파티 생성은 커밋 `b89ddb1`, 병합 커밋 `9652231`으로 `main`에 반영했다.
- 승인 대기 신청과 본인 철회 Transaction은 후속 가입·멤버·회차·이벤트 작업과 함께 구현 완료했다. 실행 앱 Repository 전환은 아직 남아 있다.
- 다음 설계부터 비용 제약, 검증 목적, 실패 시 중단 기준을 구현 전에 확인하고 목적 없는 전체 테스트나 에뮬레이터 반복을 피한다.
