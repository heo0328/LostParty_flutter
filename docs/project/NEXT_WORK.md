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

## 현재 기준 상태

| 구분 | 상태 | 비고 |
| --- | --- | --- |
| 통합 기준 | **`main` = Task-080 F 완료** | 병합 `c45dba2` |
| 완료 기능 | 멤버십·회차 + 알림 + Claim A~F + 내 계정 표기 설정 | Task-068~081 |
| Firestore Rules | Claim A~F·다음주 prep·orphan self-heal **배포됨** | Firebase `lost-party` |
| 현재 코드 상태 | **`main`** | Task-080 F 병합 후 |
| 다음 구현 | **Task-082 레이드 모집에서 내 모집 제외** | 공개 목록 UX |

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
| 9 | **레이드 모집에서 내 모집 제외** | **다음 실행 (Task-082)** | 공개 모집과 내 현황 분리 |
| 10 | 운영자 계정 권한 기반 설계 | 특정 Player와 기능 확정 전 설계만 | 일반 사용자와 분리된 권한 경계 |
| 11 | 그룹 생성·가입 | 그룹 계약 확정 | 그룹 membership 기반 |
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
- origin 푸시는 사용자 지시 시

## 다음 실행 작업 — Task-082 레이드 모집에서 내 모집 제외

```text
현재 Task: Task-082 레이드 모집에서 내 모집 제외
현재 단계: 정책 확정 / 구현 시작 가능
브랜치: 신규 (예: cursor/task-082-exclude-own-recruitments)
작업 트리: main = Task-080 F 완료
```

### 목표

공개 레이드 모집 목록에서 **내가 책임자이거나 이미 참가 중인 방**을 제외하거나 분리해, 공개 탐색과 내 현황(레이드 현황)의 역할을 분명히 한다.

### 시작 전 확인

- 시작 전 확인: Task-080 F가 `main`에 있는지(Rules는 이미 재배포됨)
- 공개 목록 쿼리·`PublicRecruitmentSummary`·현황 탭 경계를 [`FIRESTORE_PARTY_READ_MODEL_CONTRACT.md`](../architecture/FIRESTORE_PARTY_READ_MODEL_CONTRACT.md)와 대조

### 확정 정책

- 공개 모집 목록에서 `leaderPlayerId == currentPlayerId`이거나 `memberPlayerIds`에 현재 PlayerId가 포함된 `active` 방을 제외한다. 책임자가 멤버 배열에도 들어가는 정상 데이터와 별개로 두 조건을 모두 검사한다.
- 신청만 `pending`인 방은 공개 목록에 유지한다. 승인되어 실제 멤버가 되는 즉시 제외하며, `rejected`·`withdrawn` 방도 다른 공개 조건을 만족하면 유지한다.
- Firestore에는 `array-not-contains`가 없으므로 기존 공개 쿼리는 유지하고, **data 계층에서 문서 원문의 책임자·멤버 ID를 검사한 뒤** `PublicRecruitmentSummary`로 변환한다. 전체 `memberPlayerIds`를 Domain·presentation에 새로 노출하지 않는다.
- 서버 페이지 크기 20과 cursor는 필터 전 원문 기준이다. 화면 항목 수가 20보다 적어도 정상이며, 사용자가 목록 하단 240px에 접근하면 기존처럼 다음 페이지를 자동 로딩한다. 별도 `더 보기` 버튼은 두지 않는다.
- 필터 결과가 0개이고 다음 cursor가 있어 스크롤이 생기지 않는 경우에만 다음 페이지를 제한적으로 자동 보충한다. 한 번의 시작·갱신에서 최대 3페이지까지만 연속 조회해 무제한 읽기를 막는다.
- 첫 페이지 실시간 snapshot에서 가입 승인·탈퇴·책임자 승계가 반영될 때마다 필터를 다시 적용한다. 필터 후 첫 페이지 ID 집합이 바뀌면 기존 계약대로 추가 페이지와 cursor를 초기화한다.
- 공개 결과가 최종적으로 비면 `참여 가능한 공개 모집이 없습니다. 내가 참여 중인 파티는 레이드 현황에서 확인할 수 있습니다.` 취지로 공개 탐색과 내 현황의 역할을 안내한다.

### 구현 확인 지점

- `PartyReadRepository` 공개 목록 API에 현재 Player 식별자를 전달하되, Firestore·PlayerId 타입을 presentation에 노출하지 않는다.
- 첫 페이지 실시간 구독과 cursor 기반 추가 페이지 모두 동일한 제외 함수를 사용한다.
- 필터로 인한 빈 첫 화면의 제한적 자동 보충, 하단 스크롤 자동 로딩, 추가 조회 실패 `다시 시도`, pull-to-refresh가 함께 동작하는지 확인한다.
- 기존 정렬·빈 자리·현재 주차 조건과 레이드 현황 쿼리는 변경하지 않는다.

### 제외 범위

- 그룹 전용 모집, 공통 필터 확장, Claim 계약 변경
- 그룹·채팅·운영자 기능
- BUG-007 심화 hardening

### 완료 조건

- 공개 목록과 내 현황의 역할이 문서·UI에서 분리됨
- 책임자·확정 멤버 제외, 신청 중 유지, 제한적 자동 보충 정책이 Repository·ViewModel 테스트로 고정됨
- 표적 테스트·analyze·실기기 확인
- `DEV_LOG`·`AI_CONTEXT`·`NEXT_WORK` 갱신 후 Git 종료

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

Task-082를 시작할 때 먼저 확인할 문서:

1. [`../architecture/FIRESTORE_PARTY_READ_MODEL_CONTRACT.md`](../architecture/FIRESTORE_PARTY_READ_MODEL_CONTRACT.md)
2. [`../architecture/FIREBASE_PARTY_PRODUCT_FLOW.md`](../architecture/FIREBASE_PARTY_PRODUCT_FLOW.md)
3. [`../architecture/WEEKLY_RAID_CLAIM_CONTRACT.md`](../architecture/WEEKLY_RAID_CLAIM_CONTRACT.md) (Claim 경계 유지)
4. [`ai_rules.md`](ai_rules.md)

열린 결함:

- [`BUG_REPORTS.md`](BUG_REPORTS.md)

추가로:

- [`AI_CONTEXT.md`](AI_CONTEXT.md)
- [`DEV_LOG.md`](DEV_LOG.md)
- 알림 계약(참고): [`../architecture/PARTY_NOTIFICATION_CONTRACT.md`](../architecture/PARTY_NOTIFICATION_CONTRACT.md)
