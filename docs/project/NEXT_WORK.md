# NEXT WORK

## 문서의 역할

이 문서는 Codex와 Cursor가 번갈아 작업하더라도 같은 범위와 판단 기준으로 이어갈 수 있게 하는 단일 실행 지시서다.

- **현재 실행 작업**에 적힌 한 작업만 구현한다.
- **후속 작업 큐**는 순서 확인용이며 현재 작업 범위에 함께 포함하지 않는다.
- 현재 작업을 구현·자동 검증·실기기 확인·문서화·병합한 뒤 다음 항목을 현재 실행 작업으로 올린다.
- 누적 완료 이력은 `DEV_LOG.md`, 전체 현재 상태는 `AI_CONTEXT.md`, 제품·기술 계약은 관련 product/architecture/design 문서를 따른다.
- 작업 시작 시 `git status`, 현재 브랜치와 `git log -3`을 이 문서의 기준 상태와 대조한다.

## 두 AI 인계 방식

### 기본 역할

| 단계 | 주 담당 | 해야 할 일 | 다음 AI에게 남길 내용 |
| --- | --- | --- | --- |
| 계약·범위 검토 | Codex | 문서와 실제 코드·Rules 대조, 설계 충돌과 결정 필요 항목 식별 | 구현 가능한 단위, 포함·제외 범위, 보안 불변식 |
| 구현·표적 검증 | Cursor | 지시된 한 작업 단위의 코드·테스트 구현, 표적 테스트와 analyze | 변경 파일, 테스트 결과, 미해결 충돌, 실기기 확인 항목 |
| 결과 재검토 | Codex | 구현이 계약·Rules·비용 제약과 일치하는지 확인 | 수정 지시 또는 문서화·종료 승인 |
| 수정·최종 검증 | Cursor | 승인된 수정만 반영하고 최종 검증 | 최종 코드 상태와 검증 결과 |
| 문서·Git 종료 | Codex 또는 명시된 담당 | `DEV_LOG`·`AI_CONTEXT`·`NEXT_WORK` 갱신, 승인된 경우 Git 종료 | 다음 작업의 실행 지시서 |

역할은 주 담당을 뜻하며 다른 AI의 코드 수정이나 설계 제안을 금지하지 않는다. 다만 현재 단계의 산출물 없이 다음 단계까지 한 번에 진행하지 않는다.

### 매 인계 시 필수 상태 보고

다음 AI는 이전 대화 내용을 추측하지 않고 아래 항목을 저장소와 이 문서에서 확인한다. 작업을 넘기는 AI도 같은 형식으로 결과를 남긴다.

```text
현재 Task:
현재 단계: 검토 / 구현 / 재검토 / 수정 / 실기기 대기 / 종료
브랜치와 HEAD:
작업 트리 상태:
완료한 범위:
변경 파일:
실행한 검증과 결과:
남은 작업:
결정 또는 사용자 확인 필요 사항:
금지·제외 범위 재확인:
```

- Git 상태나 코드가 문서와 다르면 먼저 차이를 보고하고 임의로 덮어쓰지 않는다.
- 다른 AI가 만든 미커밋 변경은 보존한다. 현재 Task와 겹치면 diff를 읽고 이어서 작업한다.
- 설계 결정이 필요한 충돌은 구현으로 숨기지 않고 `결정 필요`로 인계한다.
- 후속 아이디어는 현재 구현에 포함하지 않고 `NEXT_WORK` 후보 또는 관련 계약 문서에 기록한다.
- 커밋·푸시·Rules 배포·유료 서비스 활성화는 사용자 지시나 현재 단계의 명시적 승인 없이 수행하지 않는다.
- Firebase Rules 배포는 AI가 직접 실행하지 않는다. AI는 검증 후 사용자에게 정확한 배포 명령어를 전달하고, 사용자가 실행 결과를 알려줄 때까지 대기한다.
- 실물 기기 테스트는 사용자가 직접 수행한다. AI는 확인 항목만 전달하며 `flutter devices`, 앱 설치·실행 또는 기기 조작을 시도하지 않는다.

## 현재 기준 상태

| 구분 | 상태 | 비고 |
| --- | --- | --- |
| 통합 기준 | **`main` 최신** | Task-086·반복 레이드 상태·그룹 제품 문서 병합 및 원격 푸시 완료 |
| 완료 기능 | Task-083~086 운영자 기능, 반복 레이드 `금주 진행`·`다음주 대기` 표시 | 실제 24시간 경과 시나리오만 보류 검증 |
| Firestore Rules | Task-086 규칙 **배포됨** | Firebase `lost-party`, 사용자 배포 2026-08-29 |
| 현재 문서 상태 | 그룹 제품 흐름 초안 최신화 | [`../product/GROUP_PRODUCT_FLOW.md`](../product/GROUP_PRODUCT_FLOW.md) |
| 다음 실행 | **그룹 미결정 정책 확정 후 구현 계약 분리** | 알림·공지는 초기 범위 제외 |

### Task-073 확인 완료 사항 (2026-08-27)

- 공통 `PartyEvent` schema·write plan·자기 Player Event 읽기·유형별 Rules
- 신청·멤버십·`partyDisbanded`를 명령 Transaction에 연결
- Drift v8 `partyNotificationReceipts`·unread·현황 알림 아이콘/목록 UI
- 다인 해산: Transaction 읽기 전부 선행 후 쓰기로 수정, 실기기 정상 확인
- FCM·OS 알림·유료 서비스·Emulator는 제외

### 기존 버그 정리

- BUG-002·006은 하단 탭 및 후속 흐름 수정 뒤 재현되지 않아 종료로 간주하고, 같은 증상이 다시 보고되면 새 재현 절차로 연다.
- BUG-005의 주간 재완료 미차단은 독립 버그 패치가 아니라 Task-074~075 개인 주간 완료 Claim 서버 강제 범위에 흡수한다.
- BUG-007(반복 파티 복잡 꼬임)은 정상·1차 복원 경로 밖 보류. 심화 업그레이드 시 [`BUG_REPORTS.md`](BUG_REPORTS.md)를 본다.

## 전체 작업 순서

순서는 다음과 같다. 번호가 뒤인 작업을 앞 작업과 묶어서 구현하지 않는다.

| 순서 | 작업 | 시작 조건 | 결과 |
| --- | --- | --- | --- |
| 1 | Task-069 파티 구성판 반응형 그룹 배치 | **완료** | 모바일 전체 폭 Card, 넓은 화면 파티 좌우 배치 |
| 2 | 자기 참가 캐릭터 변경·탈퇴·추방 연결 | **완료** | 자유로운 멤버십 명령 UI 완성 |
| 3 | 완료·완료 취소·종료·해산 연결 | **완료** | 파티·회차 수명주기 완성 |
| 4 | 알림 서비스 별도 설계 | **Task-072 완료** | Spark 앱 내부 알림 + 향후 FCM 2단계 계약 |
| 5 | 앱 내부 알림 이벤트 schema·Rules 기반 | **Task-073 완료** | 공통 event model과 안전한 create/read 경계 |
| 6 | 신청·멤버십·회차 이벤트와 로컬 알림/UI | **Task-073에 포함 완료** | foreground/재실행 앱 내부 알림 |
| 7 | **개인 주간 완료 Claim 계약** | **Task-074 완료** | 파티·점유·개인 완료 단일 기준 확정 |
| 8 | 개인 주간 완료 Claim 구현 A~F | **A~F 완료** | 체크박스·서버 제한·개인/전체 완료 |
| 8a | 내 계정 주간 레이드 표시 설정 | **Task-081 완료** | 0~5개·선택·원정대 일괄, 접기 없음 |
| 9 | **레이드 모집에서 내 모집 제외** | **완료 (Task-082)** | 공개 모집과 내 현황 분리 |
| 10 | **운영자 계정 권한 기반 설계** | **완료 (Task-083)** | 일반 사용자와 분리된 권한 경계 |
| 10a | **운영자 권한·마지막 접속·대표 동기화** | **완료 (Task-084·084b)** | 운영자 목록, 대표 보강, 사용자 변경 5분 |
| 10b | **수동 인증 요청과 운영자 1차 판정** | **Task-085 완료** | Task-086 브랜치에 포함 |
| 10c | **기존 소유자 24시간 방어와 자동 이전** | **Task-086 완료** | 실제 24시간 경과 검증은 사용자 결정으로 보류 |
| 11 | 그룹 생성·가입 | [`GROUP_PRODUCT_FLOW.md`](../product/GROUP_PRODUCT_FLOW.md)의 필수 미결정 정책 확정 | 그룹 membership 기반 |
| 12 | 그룹 전용 모집 | 그룹 membership 안정화 | 생성 드롭다운과 그룹 Rules |
| 13 | 레이드 모집·현황 공통 필터 | 그룹 공개 범위 확정 | 공통 UX, Firestore/Drift 조회 분리 |
| 14 | 빈 슬롯 역할·직업·시너지 조건 | 슬롯 명령 안정화 | 가입·승인 조건 서버 검증 |
| 15 | 조건 필터 확장 | 슬롯 조건 구현 | 역할·직업·시너지 탐색 |
| 16 | 파티·슬롯 이동과 스왑 | 조건 판정 안정화 | 원자적 위치 변경과 이벤트 |
| 17 | 상세 최근 10개 텍스트 채팅 | 핵심 파티 기능 안정화 | 멤버 전용 최소 채팅 |
| 18 | 참가 일정·신청 자동 만료 | 마지막 | 일정·마감·수요일 06:00 정책 |

## Task-074 완료 설계 기준 — 캐릭터 주간 레이드 귀속 계약

### 목표

파티 회차 상태, 활성 파티 점유와 개인 캐릭터 주간 완료를 분리하고, 레이드 상세 완료 버튼과 내 계정 체크박스가 같은 서버 Claim을 조작하도록 계약을 확정한다.

### 확정 결정

- 서버 Claim 키는 `playerId + characterId + raidId + cycleKey`다.
- 파티장·공대장의 레이드 완료는 파티 회차와 완료 당시 전원의 Claim을 처리한다.
- 일반 파티원의 레이드 완료는 본인 탈퇴와 본인 Claim만 처리하며 파티 회차는 active로 유지한다.
- 내 계정 체크박스는 앱 밖 완료와 개인 완료를 모두 표시·변경하는 서버 Claim UI다.
- 체크 해제는 본인 Claim만 삭제하며 공동 Snapshot·다른 파티원·이전 membership을 변경하지 않는다.
- Claim 생성과 같은 Character·raidId·cycleKey의 active assignment는 공존할 수 없다.
- 활성 파티나 pending 신청이 있는 상태에서 체크하면 영향을 안내하고 확인 후 탈퇴·신청 종료·Claim 생성을 한 Transaction으로 처리한다.

### 산출물

- [`../architecture/WEEKLY_RAID_CLAIM_CONTRACT.md`](../architecture/WEEKLY_RAID_CLAIM_CONTRACT.md)
- 기존 코드와 충돌 지점 및 단계 A~F 구현 분해
- `NEXT_WORK.md`의 새 우선순위와 다음 실행 작업

### 제외 범위

- Flutter·Firestore Rules·Firebase 배포 변경
- 기존 completed 데이터 이행
- 채팅·그룹·필터·운영자 기능 구현

### 완료 조건

- 문서 간 용어·권한·Transaction·UX가 일치함
- `git diff --check` 통과
- Task-075 구현 지시가 한 작업 그룹 크기로 준비됨

## 완료 작업 — Task-075 개인 주간 완료 Claim 기반 A

### 이번 인계의 시작 상태

| 항목 | 기준 |
| --- | --- |
| 시작 브랜치 | Task-074 계약이 반영된 최신 `main` |
| 새 작업 브랜치 | 구현 담당이 작업 전용 브랜치 생성 |
| 현재 단계 | 구현·자동·실기기 검증과 Rules 배포 완료, Git 종료 전 |
| 앱 동작 기준 | Claim Firestore stream + 내 계정 읽기 전용 Projection 연결 |
| 배포 기준 | 자기 Player 읽기 전용 Rules를 Firebase 프로젝트 `lost-party`에 배포 완료 |
| 실기기 | 카드 레이아웃·읽기 전용 체크박스·기존 기능 정상 확인 완료 |

### 목표

개인 주간 완료 Claim의 Firestore 경로·Domain·Repository 읽기 경계를 만들고, 내 계정 체크박스를 우선 읽기 전용으로 표시한다.

### 포함 범위

- `weeklyRaidClaims` Domain/DTO/mapper/Repository
- 현재 Player 소유 Character의 현재 주차 Claim 읽기
- 내 계정 캐릭터별 주간 레이드 체크박스 읽기 전용 표시
- 기존 Drift 완료 히스토리와 Claim Projection 분리
- 문서 ID escape/hash 규칙 확정 및 테스트

### 반드시 유지할 설계 불변식

- Claim은 Player·Character·raidId·cycleKey 서버 단일 기준이다.
- `difficultyId`는 부가 이력이며 같은 raidId의 난이도를 중복 Claim으로 만들지 않는다.
- 다른 Player의 Claim을 읽거나 임의 변경하지 않는다.
- Drift 완료 이력·Party Event·active assignment를 Claim과 같은 저장소로 합치지 않는다.
- A단계에서는 체크·해제, 탈퇴, 모집 제한과 파티 전체 완료를 구현하지 않는다.

### 제외 범위

- Claim create/delete와 Security Rules 배포
- 모집 생성·신청·가입 제한
- 활성 파티 탈퇴·pending 신청 종료
- 개인 완료·파티 전체 완료 명령 변경
- 채팅·그룹·필터와 기존 데이터 이행

### 완료 조건

- 현재 Player의 이번 주 Claim만 읽을 수 있는 Repository 경계
- 내 계정 체크박스가 Claim을 정확히 표시하되 아직 조작하지 않음
- 기존 완료 기록 화면과 알림 sync 회귀 없음
- 표적 테스트와 `flutter analyze --no-pub` 통과

### 검증 체크리스트

- [x] Claim 키가 Player·Character·raidId·cycleKey를 안정적으로 구분
- [x] 같은 raidId의 난이도는 하나의 체크 상태로 표시
- [x] 자기 Player Claim만 읽음
- [x] Claim 없음=미완료, 있음=완료 표시
- [x] 체크박스 조작은 비활성
- [x] Drift 히스토리 정정과 Claim 상태를 혼합하지 않음
- [x] 표적 테스트·`flutter analyze --no-pub` 통과

### 구현 결과

- `WeeklyRaidClaim` Domain·DTO·mapper·Repository와 자기 Player·현재 `cycleKey` Firestore stream을 추가했다.
- 문서 ID는 B 시작 시 Rules가 재구성할 수 있는 `${cycleKey}_${characterId}_${raidId}`로 교정했다. A의 base64url 방식은 Rules에서 중복 ID를 검증할 수 없어 폐기했다.
- 내 계정은 인증된 `serverCharacterId`가 있는 캐릭터에 입장 가능한 활성 레이드 중 골드 기준 기본 3개를 읽기 전용 체크박스로 표시한다.
- 같은 `raidId`는 난이도와 무관하게 하나의 체크 상태이며 Claim 유무만 반영한다.
- Claim Repository와 기존 Character summary gateway를 앱 생성자에서 주입할 수 있게 해 Firebase 미초기화 테스트 경계를 복구했다.
- `firestore.rules`에는 자기 Player `weeklyRaidClaims` get/list만 추가하고 모든 쓰기를 금지했으며 `lost-party`에 배포했다.
- 전체 `flutter test --no-pub` 421개와 `flutter analyze --no-pub`가 통과했다.

### 실기기·배포 확인 (2026-08-27)

- 사용자가 `firebase deploy --only firestore:rules --project lost-party`로 읽기 전용 Rules 배포를 완료했다.
- 내 계정의 새 주간 레이드 표현과 기존 계정 기능이 정상이다.
- 캐릭터 카드 레이아웃이 정상이며 체크박스가 표시된다.
- 현재 Claim이 없어 모두 미체크 상태이고, 읽기 전용이라 조작되지 않는 것이 확인됐다.

## 완료 작업 — Task-076 개인 주간 완료 Claim 기반 B

### 현재 단계

- Flutter·Rules 구현과 자동 검증 완료
- Rules 실제 배포와 실기기 체크/해제 검증 완료
- 커밋 `4798a7c`, 병합 커밋 `0307243`으로 `main` 반영·푸시 완료

### 구현 결과

- 활성 assignment와 pending 신청이 없는 캐릭터에 한해 자기 수동 Claim create/delete 명령을 연결했다.
- 체크/해제 확인창, 처리 중 중복 입력 차단, 실패 사유 안내를 추가했다.
- 본인 Player·소유 Character·현재 7일 주차·허용 필드·결정적 문서 ID를 Rules에서 검증한다.
- Claim과 신청/assignment가 경쟁 상태로 동시에 생성되지 않도록 신청·가입·캐릭터 변경 Rules에 최소 Claim 부재 검사를 선반영했다. 전체 후보 UI와 오류 매핑은 C 범위다.
- 문서 ID는 `${cycleKey}_${characterId}_${raidId}`로 통일하고 읽을 때도 문서 내용과 ID 일치를 검증한다.
- 전체 `flutter test` 424개, `flutter analyze`, Firebase Rules dry-run compile이 통과했다. Rules compile에는 기존 `recruitmentId` 미사용 경고 1개만 남아 있다.

### 실기기·배포 체크리스트

- [x] `firebase deploy --only firestore:rules --project lost-party`
- [x] 참가 파티와 pending 신청이 없는 캐릭터에서 체크 → 확인창 → 체크 유지
- [x] 같은 항목 체크 해제 → 확인창 → 미체크 유지
- [x] 앱 재실행 후 서버 상태가 동일하게 복원됨
- [x] 참가 중 캐릭터는 같은 레이드 모집 생성이 차단되고 수동 Claim과 공존하지 않음
- [x] pending 신청 캐릭터는 체크가 차단되고 신청 상태를 바꾸지 않음
- [x] 기존 내 계정 표현과 기존 기능이 정상임

### 명시적 제외 범위

- 활성 파티 자동 탈퇴와 pending 자동 종료
- 레이드 상세의 개인 완료 버튼
- 파티장 전체 완료와 전원 Claim
- 전체 모집 후보 UI의 Claim 선제 제외

## 완료 작업 — Task-077 개인 주간 완료 Claim 기반 C

### 목표와 구현 범위

- 모집 생성·신청·즉시 가입·참가 캐릭터 변경 후보에 서버 Claim 상태를 표시하고 선택을 차단한다.
- 본인이 실행하는 명령 Transaction에서 결정적 Claim 문서를 읽어 `weeklyRaidCompleted` 전용 실패를 반환한다.
- 승인 명령은 다른 Player의 비공개 Claim을 클라이언트가 읽지 않으며 B에서 배포한 Rules가 최종 차단한다.
- 활성 파티 자동 탈퇴·pending 자동 종료·Claim 생성을 묶는 UX와 Transaction은 Task-078 D로 유지한다.

### 현재 구현 결과

- 생성·신청·캐릭터 변경 후보 서비스가 현재 Player·현재 주차 Claim stream을 함께 읽는다.
- Claim이 있는 Character·raidId 후보는 `이번 주 동일 레이드 완료` 상태와 함께 비활성화된다.
- 생성·신청·즉시 가입·캐릭터 변경 Repository가 자기 Claim을 Transaction에서 재검증한다.
- 명령별 `weeklyRaidCompleted` 실패 유형과 사용자 안내 문구를 추가했다.
- Claim 제한 Rules는 Task-076 B에서 배포한 기준을 그대로 사용한다.
- 실기기 검증 중 발견된 역할 고정 회귀를 함께 수정했다. 참가 캐릭터 변경은 같은 역할뿐 아니라 파티 내 해당 역할 여유가 있으면 dealer↔support 변경을 허용하고, 같은 캐릭터의 반대 역할 설정도 선택할 수 있다.
- 역할 변경 시 membership·active assignment·모집 dealer/support 집계를 한 Transaction에서 갱신하도록 Rules를 확장했으므로 이번 단계는 Rules 재배포가 필요하다.
- 레이드 상세 인원 행에 전체 딜러·서포터 현재/정원을 표시하고, `1파티`·`2파티` 제목에도 해당 파티의 역할별 현재/정원을 표시한다. 전체 값은 모집 집계, 파티별 값은 실제 슬롯 배치를 기준으로 한다.

### 실기기 검증 항목

- [x] 내 계정에서 완료 체크한 캐릭터가 동일 레이드 모집 생성 후보에서 완료 상태로 비활성화됨
- [x] 같은 캐릭터가 동일 레이드 신청·즉시 가입 후보에서 비활성화됨
- [x] 참가 중 캐릭터를 완료 캐릭터로 변경할 수 없음
- [x] 다른 raidId의 모집에는 정상적으로 후보가 됨
- [x] 체크 해제 후 화면 재진입 시 생성·신청·변경 후보가 다시 활성화됨
- [x] 기존 미완료 캐릭터의 생성·신청·즉시 가입이 정상임
- [x] 서포터 참가 중 딜러 여유가 있으면 딜러 설정 캐릭터로 변경 가능
- [x] 딜러 참가 중 서포터 여유가 있으면 서포터 설정 캐릭터로 변경 가능
- [x] 같은 캐릭터의 반대 역할 설정으로 바로 변경 가능
- [x] 역할 자리가 가득 찼거나 동일 딜러 직업 제한에 걸리면 변경이 거절됨
- [x] 상세 인원 행의 전체 딜러·서포터 수와 각 파티 제목의 역할별 수가 실제 배치와 일치함
- [x] 참가 역할 변경 직후 전체 및 해당 파티의 역할별 수가 함께 갱신됨

## 완료 작업 — Task-078 개인 주간 완료 Claim 기반 D

- 내 계정 체크박스의 개인 완료에서 영향 확인 후 활성 파티 탈퇴·pending 종료·Claim 생성을 하나의 Transaction으로 처리한다.
- 일반 멤버 탈퇴, 책임자 승계·단독 해산과 완료 사유 탈퇴 이벤트를 연결한다. 레이드 상세의 개인 완료 버튼 연결은 후속 범위다.

### 현재 구현 결과

- 체크 전에 동일 Character·raidId·cycleKey의 활성 점유와 승인 대기 신청 영향을 조회한다.
- 일반 멤버는 탈퇴, 책임자는 다음 멤버에게 승계, 단독 책임자는 모집 해산 결과를 확인창에 구분해 표시한다.
- 사용자 확인 후 membership·assignment 제거, 모집 인원/역할/revision 갱신, 책임자 승계 또는 단독 해산, pending 신청 `superseded`, Claim 생성과 `weeklyRaidCompleted` 사유 탈퇴 이벤트를 한 Transaction에 포함한다.
- 같은 캐릭터의 다른 raidId 승인 대기 신청은 종료 대상에서 제외한다.
- Rules는 완료 Claim과 함께 생성되는 신청 종료 및 완료 사유 탈퇴 이벤트만 허용하도록 확장했다.
- 완료 후 Claim을 해제한 사용자가 같은 방에 다시 신청할 때 과거 `approved` application을 실제 membership으로 오인하지 않고, 현재 `memberPlayerIds`에 없으면 해당 문서를 `pending`으로 재사용한다.

### 실기기 검증 항목

- [x] 일반 파티원이 체크하면 파티명과 탈퇴 영향을 안내하고, 확인 후 파티에서 빠지며 Claim이 체크됨
- [x] 책임자가 다인 파티에서 체크하면 다음 책임자 캐릭터를 안내하고 실제 승계됨
- [x] 책임자가 단독 파티에서 체크하면 해산 안내 후 모집이 해산되고 Claim이 체크됨
- [x] 동일 캐릭터·동일 레이드 pending 신청이 있으면 건수를 안내하고 모두 종료됨
- [x] 동일 캐릭터의 다른 레이드 pending 신청은 유지됨
- [x] 취소를 누르면 membership·assignment·pending·Claim이 모두 변경되지 않음
- [x] 처리 후 남은 파티원에게 완료 사유 탈퇴 알림이 표시됨
- [x] 체크 해제는 이전 파티나 신청을 복구하지 않고 새 모집 참가만 다시 허용함
- [x] 완료 탈퇴 후 Claim 해제 시 과거 `approved` 신청을 실제 membership으로 오인하지 않고 같은 방에 재신청 가능

## 완료 작업 — Task-079 개인 주간 완료 Claim 기반 E

### 구현 결과

- 책임자만 `파티 전체 완료`를 실행한다. 일반 멤버 UI·Rules·Repository는 모두 거절한다.
- 완료 Transaction은 회차/모집 completed, Snapshot 전원 `partyOwner` Claim(멱등·기존 Claim 유지), assignment 전원 삭제, 완료 이벤트를 함께 처리한다.
- Claim에는 `sourceRecruitmentId`와 `sourceCompletionRevision`을 저장한다.
- 반복 파티 전체 완료 취소는 화요일 22:00 전, Snapshot·membership·책임자·역할·슬롯·해당 `partyOwner` Claim이 그대로일 때만 Claim 삭제·assignment 복원·회차 복구를 원자적으로 수행한다.
- Rules 접근은 binding·recruitment·cycle 공유와 membership 최대 8회로 약 12회이며, `partyOwner` 경로에서 character 소유 get을 쓰지 않아 한도 20 안이다.
- 표적 테스트 36개와 `flutter analyze --no-pub` 통과. Rules는 `lost-party`에 배포됐다.

### 실기기·다중 기기 검증

다중 사용자 실기기 확인은 Task-080 F에서 수행했다.

## 완료 작업 — Task-080 개인 주간 완료 Claim 기반 F

```text
현재 Task: Task-080 개인 주간 완료 Claim 기반 F
현재 단계: 완료 (`main`, 병합 `c45dba2`)
브랜치: main
```

### 구현 결과

- 모집 게이트·후보 UI **Claim-only**(로컬 `WeeklyRaidClear` 폐기)
- orphan `activeRaidAssignment`: Claim 미변환, completed/disbanded/cycle-completed 시 본인 점유 self-heal(Rules + 파티 상세)
- 내 계정 주간 레이드 **라벨 탭** 토글
- 반복 파티 **완료 후 다음주 캐릭터 변경**: membership만 갱신(Claim·새 assignment 없음), 변경 시 완료 취소 포기 안내
- 재완료 시 Snapshot에 없는 이전 캐릭터 `partyOwner` Claim orphan 정리
- cycle `completionRevision` num 허용, 취소 거절 시 구성 변경 안내 문구

### 검증

- Task-079 E + F 실기기 체크리스트 통과(화요일 22:00 취소방지는 환경상 미실시)
- 정상 완료·1차 실수 복원 경로 확인
- `firestore.rules` **lost-party 재배포 완료**(사용자)
- 표적 테스트·analyze 통과

### 범위 밖 (완료 조건이 아님)

- 일반 멤버 `내 캐릭터 완료` 버튼 → 별도 단위
- 의도적 복잡 꼬임 심화 hardening → **BUG-007**로 기록, 앱 심화 업그레이드 시

### 남은 Git

- [x] 브랜치 커밋·`main` 병합 (`3726be8` / `c45dba2`)
- [x] `origin/main` 푸시 완료

## 완료 작업 — Task-082 레이드 모집에서 내 모집 제외

```text
현재 Task: Task-082 레이드 모집에서 내 모집 제외
현재 단계: 완료 (`main`, `6597d7a`)
브랜치: cursor/task-082-exclude-own-recruitments
```

### 구현 결과

- 기존 공개 Firestore 쿼리는 유지하고, data 계층에서 `leaderPlayerId`·`memberPlayerIds`로 현재 Player의 책임자·확정 멤버 방을 제외한다.
- `memberPlayerIds` 전체를 `PublicRecruitmentSummary`에 올리지 않는다. Rules는 변경하지 않는다.
- 신청만 `pending`인 방은 공개 목록에 남긴다.
- 필터 전 페이지 크기 20·cursor를 유지하고, 필터 후 빈 첫 화면은 시작·갱신당 최대 3페이지 자동 보충한다.
- 빈 목록 안내로 공개 탐색과 레이드 현황의 역할을 구분한다.

### 검증

- 표적 테스트(mapper 제외 판정, ViewModel 자동 보충 한도, 빈 안내 UI)·`flutter analyze --no-pub` 통과
- 실기기(1대): 내가 만든 방 제외, pending 신청 방 유지, 현황 목록 정상
- 다른 Player 방의 확정 멤버 제외는 2인 환경이 없어 실기기 미실시. 같은 제외 함수의 멤버 분기는 테스트로 고정

### 남은 Git

- [x] 브랜치 커밋·`main` 반영 (`6597d7a`, fast-forward)
- [x] `origin/main` 푸시 완료

## 완료 작업 — Task-086 기존 소유자 24시간 방어와 자동 이전

```text
현재 Task: Task-086 기존 소유자 24시간 방어와 자동 이전
현재 단계: 완료 (`main` 병합·Rules 배포·핵심 실기기 검증·원격 푸시)
기능 커밋: 8c649ad
보류 검증: 실제 24시간 무응답 후 자동 이전(구현 미완료나 병합 차단 항목 아님)
해결 이력: docs/project/TASK-086-OPERATOR-WRITE-BLOCKER.md
```

선택 필드 `defenseOfRequestId` 부재를 보호하지 않은 Rules 오류를 수정·배포해 BUG-008을 종료했다. 취소·일반 승인·분쟁 개시·운영자 거절·방어 승인·방어 실패·강제 인증과 소유권 이전 후 양쪽 레이드 권한 반영을 실기기에서 확인했다. 승인 결과 로컬 연결과 수동 인증 재진입 안내도 반영했다. 전체 테스트 488건과 analyze가 통과했다. 실제 24시간 무응답 자동 이전은 사용자 결정에 따라 보류한 추가 검증이며 Task 완료·병합을 막지 않는다.

### 085에서 기록한 결정

기존 소유자가 있으면 승인을 거절하고 `existingOwner`를 반환한다. `awaitingOwnerResponse`는 열지 않는다.

---

## 완료 작업 — Task-085 수동 인증 요청과 운영자 1차 판정

```text
현재 Task: Task-085 수동 인증 요청과 운영자 1차 판정
현재 단계: 완료 (`8c649ad`에 Task-086과 함께 통합, `main` 병합·원격 푸시)
Rules 상태: 배포 완료
검증 상태: 자동 검증·핵심 실기기 확인 완료
```

### 구현 결과

- 설정 `수동 인증`: 로컬 계정·증명 캐릭터 선택, `LP-` 코드 발급·복사·취소, 24시간 만료. 재발급 버튼은 두지 않음
- 오픈카톡은 안내 문구만. 저장소에 링크를 넣지 않고 스크린샷은 Firestore에 올리지 않음
- 운영자 `수동 인증 확인` 대기 목록(오래된 순)과 상세 승인·취소·인증 금지
- 무소유 GameAccount만 승인 Transaction으로 전체 roster 소유 확정. 요청자 앱은 승인 후 로컬 서버 ID 연결
- 기존 소유자가 있으면 승인 버튼을 막고 `existingOwner`로 거절. 086 분쟁 상태는 만들지 않음
- 장비 탈착 인증 경로는 유지

### 검증

- 표적 테스트와 `flutter analyze --no-pub` 통과
- Rules·인덱스는 사용자가 Firebase `lost-party`에 배포 완료(2026-08-29)

### 사용자 확인 항목

- [x] Firebase `lost-party`에 Rules와 인덱스 배포
- 일반 사용자: 코드 발급·복사·취소, 같은 로컬 계정(원정대)에 active 요청 하나. 다른 부계정은 별도 요청 가능
- 운영자: 대기 목록, 무소유 승인 후 요청자 로컬 연결, 취소와 금지 구분
- 기존 소유자 계정은 085에서 승인되지 않음
- 일반 사용자는 운영자 대기 목록에 진입·판정할 수 없음

### Task-085 당시 구현 전 범위 메모

아래 내용은 구현 전 계획을 보존한 역사 기록이며 현재 작업 상태나 남은 체크리스트가 아니다. 최종 상태는 위 `구현 결과`·`검증`과 Task-086 완료 기록이 우선한다.

```text
현재 Task: Task-085 수동 인증 요청과 운영자 1차 판정
현재 단계: 검토 후 구현 대기
브랜치: 최신 main에서 새 작업 브랜치 생성
```

### 목표

설정에서 게임 계정 단위 수동 인증 요청을 만들고, 운영자가 인게임 채팅 스크린샷을
대조해 승인·취소·인증 금지를 처리한다. 이번 단위는 **기존 active 소유자가 없는**
GameAccount만 승인 즉시 소유로 확정한다.

### 시작 조건

- 최신 `main` (Task-084b 포함)
- 작업 시작 전 `git status`와 `git log -3`을 이 문서와 대조
- `main`에서 직접 수정하지 않고 전용 브랜치를 먼저 생성

### 확인 문서

1. [`../architecture/OPERATOR_AUTHORIZATION_CONTRACT.md`](../architecture/OPERATOR_AUTHORIZATION_CONTRACT.md) §5~8, §14 Task-085
2. [`../architecture/GAME_ACCOUNT_VERIFICATION_CONTRACT.md`](../architecture/GAME_ACCOUNT_VERIFICATION_CONTRACT.md)
3. [`../architecture/GAME_ACCOUNT_CHARACTER_FIREBASE_CONTRACT.md`](../architecture/GAME_ACCOUNT_CHARACTER_FIREBASE_CONTRACT.md)
4. [`ai_rules.md`](ai_rules.md)

### 포함 범위

- `manualVerificationRequests` Domain·DTO·Repository·Rules
- 사용자: 로컬 등록 계정·증명 캐릭터 선택, `LP-` 코드 발급·복사, 만료·재발급·취소, 오픈카톡 안내
- 요청 단위는 Character가 아니라 선택한 Character가 속한 GameAccount
- Player와 대상 계정 조합에 active 요청 하나만 허용
- 운영자 `수동 인증 확인` 대기 목록(오래된 순)과 요청 횟수
- 승인·취소·인증 금지. 취소는 재요청 가능, 금지는 `PlayerId + 대상 GameAccount`
- 기존 active 소유자가 없을 때만 승인 Transaction으로 GameAccount 전체 소유 확정
- 승인 시 오래된 로컬 Snapshot을 그대로 쓰지 않고 Lost Ark API roster를 다시 조회
- 요청자 앱은 서버명·캐릭터명으로 로컬 행에 서버 ID를 연결
- 스크린샷 파일과 오픈카톡 원본은 Firestore에 올리지 않음

### 반드시 유지할 불변식

- Spark. Callable Functions·유료 플랜·Emulator는 별도 승인 없이 사용하지 않음
- 요청 create는 본인 Player만. 요청자는 상태·운영자 판정·기한·시도 횟수를 임의 변경하지 않음
- 운영 명령은 active 운영자 지정과 binding을 함께 검증
- AuthUid·토큰·민감 ID를 일반 UI·로그에 노출하지 않음
- 장비 탈착 인증 경로를 이 작업에서 제거하거나 덮어쓰지 않음

### 제외 범위

- Task-086: 기존 소유자 24시간 방어, 무응답 자동 이전, ownershipLost 후처리 완성
- 사용자 삭제·삭제 대기·강제 삭제
- 앱 재설치로 새 PlayerId를 만드는 우회 차단
- 그룹·채팅·필터·Claim 변경
- FCM·OS 알림

기존 소유자가 있는 승인에서 즉시 이전하지 않고 `awaitingOwnerResponse`만 남기는 것은
086 범위다. 085에서는 그 상태를 만들더라도 방어·이전 Transaction을 구현하지 않는다.
구현 중 기존 소유자 분기를 완전히 막을지, 상태만 열어둘지는 계약 §9와 맞춰 한 줄로 기록한다.

### 완료 조건

- 사용자 요청 발급·복사·재발급·취소가 Rules와 함께 동작
- 운영자만 대기 목록을 읽고 승인·취소·금지를 실행
- 무소유 GameAccount 승인이 서버 소유권과 로컬 바인딩을 맞춘다
- 표적 테스트와 `flutter analyze --no-pub` 통과
- Rules는 검증 후 사용자에게 배포 명령을 전달하고 배포 결과를 기다림
- 실물 기기 테스트는 사용자가 수행. AI는 기기 조회·설치·실행을 하지 않음

### 당시 검증 체크리스트와 최종 결과

- [x] 본인만 요청을 만들고 조회·취소할 수 있음
- [x] 코드는 24시간 만료. 최종 UX에서는 재발급 버튼을 제공하지 않음
- [x] 같은 Player·대상 계정에 active 요청이 둘 이상 생기지 않음
- [x] 일반 사용자는 운영자 대기 목록과 판정 명령을 쓸 수 없음
- [x] 무소유 계정 승인 후 요청자 로컬에 서버 ID가 연결됨
- [x] 스크린샷을 서버에 업로드하지 않음
- [x] 표적 테스트·`flutter analyze --no-pub` 통과

### 기준 계약

- [`../architecture/OPERATOR_AUTHORIZATION_CONTRACT.md`](../architecture/OPERATOR_AUTHORIZATION_CONTRACT.md)

## 완료 작업 — Task-083 운영자 계정 권한 기반 설계

### 확정 결과

- 운영자는 Firestore `operatorAssignments/{playerId}`의 active 지정과 현재 AuthUid→PlayerId binding을 함께 검증한다.
- 일반 사용자는 운영자 지정 문서를 쓰거나 운영 명령을 호출할 수 없다.
- 사용자는 등록 게임 계정별로 24시간 수동 인증 코드를 받고, 인게임 일반 채팅 전체 화면을 오픈카톡으로 운영자에게 전달한다.
- 운영자는 요청별 승인·취소·인증 금지를 선택하고 Player·대상 GameAccount별 시도 횟수를 확인한다.
- 기존 active 소유자가 있으면 운영자 1차 승인 뒤 기존 소유자에게 24시간 수동 재인증 기회를 준다.
- 기존 소유자가 방어하면 소유권을 유지하고 신규 요청자는 해당 GameAccount 인증 금지된다.
- 무응답이면 추가 운영 승인 없이 신규 요청자에게 자동 이전한다. Spark에서는 기한 후 최초 안전한 앱·운영자 접근이 이전 Transaction을 물리적으로 확정한다.
- 운영자 사용자 확인은 서버 데이터만 사용하며 마지막 앱 접속은 `players.lastSeenAt` 최신값 하나만 기록한다.
- 사용자 삭제·삭제 대기·강제 삭제와 재설치 우회 차단은 보류한다.

### 산출물

- [`../architecture/OPERATOR_AUTHORIZATION_CONTRACT.md`](../architecture/OPERATOR_AUTHORIZATION_CONTRACT.md)
- Task-084~086 구현 분할

## 완료 작업 — Task-081 내 계정 주간 레이드 표시 설정

### 구현 결과

- Drift schema 9 `characterWeeklyRaidDisplays`: 캐릭터별 `displayCount`·`raidIdsCsv` 로컬 저장
- `WeeklyRaidDisplayProjector`: 입장 가능 후보, 기본 골드 top-3→입장 레벨 내림차순, 사용자 설정 존중, 원정대 일괄 시 개수 클램프
- 캐릭터별 표기 수정 다이얼로그(0~5·선택 일치 시 저장·기본값 복원)
- 계정 헤더: 계정명 단독 줄, 배지·n/n·수정 아이콘, `원정대 주간레이드수정` 일괄 개수 적용
- 접기/더보기 제거. 선택 개수만큼 항상 표시. 캐릭터 카드는 고정 Grid 높이 대신 내용 높이 `Wrap` 배치
- Claim 체크/해제 계약은 변경하지 않음

### 검증

- 표적 테스트(projector·ViewModel·page) 통과
- 에뮬레이터 overflow 수정 후 내 계정 진입·카드 표시 확인
- 실기기에서도 헤더·일괄 적용·다레이드 표시 UI 확인

## 후속 작업별 범위 메모

### 14~15. 조건과 필터

- 빈 슬롯 조건 문서·저장·판정 계약을 먼저 확정한다.
- 전체 공개 목록 필터는 같은 역할·직업·시너지 판정 기준을 사용한다.
- 레이드 현황의 진행 중·신청 중·완료 기록은 공개 목록과 같은 필터 표현·조작을 재사용한다.
- UI와 필터 값 객체는 재사용할 수 있지만 Firestore query와 Drift 완료 기록 Repository를 하나로 합치지 않는다.

## 지속 운영 제약

- 유료 플랜·결제·과금 가능 기능 금지(별도 지시 전)
- Emulator는 명시 승인 후에만 사용
- AuthUid·토큰·민감 ID 비노출
- Drift native assets 임의 삭제 금지
- 네트워크 버튼 연타·중복 요청 방지
- 계약 변경이 필요하면 코드보다 문서를 먼저 수정
- 한 작업 그룹에 후속 기능을 끼워 넣지 않음

## 참고 문서

Task-084를 시작할 때 먼저 확인할 문서:

1. [`../architecture/OPERATOR_AUTHORIZATION_CONTRACT.md`](../architecture/OPERATOR_AUTHORIZATION_CONTRACT.md)
2. [`../architecture/FIREBASE_PLAYER_BINDING_CONTRACT.md`](../architecture/FIREBASE_PLAYER_BINDING_CONTRACT.md)
3. [`../architecture/GAME_ACCOUNT_CHARACTER_FIREBASE_CONTRACT.md`](../architecture/GAME_ACCOUNT_CHARACTER_FIREBASE_CONTRACT.md)
4. [`../product/DETAIL_IMPROVEMENTS.md`](../product/DETAIL_IMPROVEMENTS.md)
5. [`ai_rules.md`](ai_rules.md)

열린 결함:

- [`BUG_REPORTS.md`](BUG_REPORTS.md)

추가로:

- [`AI_CONTEXT.md`](AI_CONTEXT.md)
- [`DEV_LOG.md`](DEV_LOG.md)
- 알림 계약(참고): [`../architecture/PARTY_NOTIFICATION_CONTRACT.md`](../architecture/PARTY_NOTIFICATION_CONTRACT.md)
