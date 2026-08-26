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
| 통합 기준 | **`main` = Task-075 A까지** | Claim 읽기 기반·읽기 전용 체크박스 |
| 완료 기능 | 멤버십·회차 수명주기 + 앱 내부 알림(이벤트·Rules·Drift·최소 UI) | Task-068~073 |
| Firestore Rules | 신청·멤버십·해산(`partyDisbanded`) 이벤트 포함 **배포됨** | Firebase 프로젝트 `lost-party` |
| 현재 코드 상태 | `main` | Task-077 C 구현·실기기 검증 완료, Git 종료 진행 |
| 다음 구현 | **Task-078 개인 주간 완료 Claim 기반 D** | Task-077 메인 병합 후 시작 |

### Task-073 확인 완료 사항 (2026-08-27)

- 공통 `PartyEvent` schema·write plan·자기 Player Event 읽기·유형별 Rules
- 신청·멤버십·`partyDisbanded`를 명령 Transaction에 연결
- Drift v8 `partyNotificationReceipts`·unread·현황 알림 아이콘/목록 UI
- 다인 해산: Transaction 읽기 전부 선행 후 쓰기로 수정, 실기기 정상 확인
- FCM·OS 알림·유료 서비스·Emulator는 제외

### 기존 버그 정리

- BUG-002·006은 하단 탭 및 후속 흐름 수정 뒤 재현되지 않아 종료로 간주하고, 같은 증상이 다시 보고되면 새 재현 절차로 연다.
- BUG-005의 주간 재완료 미차단은 독립 버그 패치가 아니라 Task-074~075 개인 주간 완료 Claim 서버 강제 범위에 흡수한다.

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
| 8 | 개인 주간 완료 Claim 구현 A~F | **A·B 완료, C 구현 중** | 체크박스·서버 제한·개인/전체 완료 |
| 9 | 레이드 모집에서 내 모집 제외 | Claim 흐름 안정화 | 공개 모집과 내 현황 분리 |
| 10 | 운영자 계정 권한 기반 설계 | 특정 Player와 기능 확정 전 설계만 | 일반 사용자와 분리된 권한 경계 |
| 11 | 그룹 생성·가입 | 그룹 계약 확정 | 그룹 membership 기반 |
| 12 | 그룹 전용 모집 | 그룹 membership 안정화 | 생성 드롭다운과 그룹 Rules |
| 13 | 레이드 모집·현황 공통 필터 | 그룹 공개 범위 확정 | 공통 UX, Firestore/Drift 조회 분리 |
| 14 | 빈 슬롯 역할·직업·시너지 조건 | 슬롯 명령 안정화 | 가입·승인 조건 서버 검증 |
| 15 | 조건 필터 확장 | 슬롯 조건 구현 | 역할·직업·시너지 탐색 |
| 16 | 파티·슬롯 이동과 스왑 | 조건 판정 안정화 | 원자적 위치 변경과 이벤트 |
| 17 | 상세 최근 10개 텍스트 채팅 | 핵심 파티 기능 안정화 | 멤버 전용 최소 채팅 |
| 18 | 참가 일정·신청 자동 만료 | 마지막 | 일정·마감·수요일 06:00 정책 |

## Task-074 현재 작업 — 캐릭터 주간 레이드 귀속 계약

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

## 다음 실행 예정 — Task-078 개인 주간 완료 Claim 기반 D

- 내 계정 또는 레이드 상세의 개인 완료에서 영향 확인 후 활성 파티 탈퇴·pending 종료·Claim 생성을 하나의 Transaction으로 처리한다.
- 일반 멤버 완료, 책임자 승계·단독 해산과 완료 사유 탈퇴 이벤트를 연결한다.

### 즉시 중단하고 결정 받아야 하는 경우

- Claim 경로가 기존 Player Rules와 안전하게 분리되지 않는 경우
- 문서 ID에 Character/raid 식별자를 안전하게 조합할 수 없는 경우
- 읽기 기반만으로 기존 완료 히스토리 동작을 깨야 하는 경우
- A단계에서 쓰기·탈퇴·Rules 배포가 선행돼야만 화면 표시가 가능한 경우

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

Task-075를 시작할 때 먼저 확인할 문서:

1. [`../architecture/WEEKLY_RAID_CLAIM_CONTRACT.md`](../architecture/WEEKLY_RAID_CLAIM_CONTRACT.md)
2. [`../architecture/FIREBASE_PARTY_PRODUCT_FLOW.md`](../architecture/FIREBASE_PARTY_PRODUCT_FLOW.md)
3. [`../architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md`](../architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md)
4. [`ai_rules.md`](ai_rules.md)

열린 결함:

- [`BUG_REPORTS.md`](BUG_REPORTS.md)

추가로:

- [`AI_CONTEXT.md`](AI_CONTEXT.md)
- [`DEV_LOG.md`](DEV_LOG.md)
- 알림 계약(참고): [`../architecture/PARTY_NOTIFICATION_CONTRACT.md`](../architecture/PARTY_NOTIFICATION_CONTRACT.md)
