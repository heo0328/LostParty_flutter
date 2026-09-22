# 2026-09-22 애니메이션 진입 화면·앱 아이콘 적용

- 제공된 941×1672 이미지를 Flutter 진입 화면으로 등록하고 별빛·중앙 글로우·로고 하이라이트를 약 2.2초간 한 번 재생한다. 서비스 초기화와 병렬로 실행하며 초기화가 느리면 마지막 정적 프레임을 유지한 뒤 기존 앱으로 전환한다.
- 고정 디자인 좌표계를 화면의 cover 배율로 중앙 확대해 폴드 접힘·펼침 등 서로 다른 비율에서도 공백 없이 채우도록 조정했다.
- 아이콘 원본 4종을 영문 파일명으로 보관하고 Android 일반·적응형·Android 13 단색 아이콘과 iOS AppIcon 전 슬롯을 생성했다. 재생성용 `tool/generate_app_icons.ps1`을 추가했다.
- 사용자 실기기에서 진입 화면과 앱 아이콘 적용이 정상임을 확인했다. 런처가 적응형 아이콘을 원형으로 마스킹하는 동작도 정상 범위로 판정했다.
- 진입 화면·부트스트랩 Widget 테스트 4건과 변경 Dart 파일 정적 분석, 아이콘 해상도·투명도·XML·iOS 슬롯·영문 파일명 검증, `git diff --check`를 통과했다. 전체 테스트의 기존 무관 경로 16건 실패는 별도 상태로 유지한다.
- 네이티브 스플래시, Firebase 정책·Rules·Indexes·배포는 변경하지 않았다.

# 2026-09-16 C* 기능 복구 F1 — 그룹 이전·탈퇴·1인 해산 자동 계약

- 그룹장 이전은 그룹 원본 1건과 이전·신규 그룹장 membership 2건, 일반 탈퇴·1인 해산은 그룹·본인 membership·membership state·relation의 고정 문서만 갱신함을 재확인했다. 파티 인원·연결 모집 수 비례 Transaction으로 되돌리지 않았다.
- 앱은 1인 그룹 해산 전에 `activeRecruitmentCount == 0`을 검사하지만 Rules에는 같은 불변식이 빠져 있었다. `validGroupDisbandUpdate`에 정수·0 조건을 추가해 활성 그룹 모집이 있는 해산을 서버에서도 거절한다.
- 전체 추적 Rules Emulator 도구에 그룹장 이전→기존 그룹장 탈퇴, 일반 멤버 탈퇴, 1인 해산과 활성 모집 해산 거절을 추가하고 demo 전용 Actions에 연결했다.
- 그룹 Rules·Write Plan·C* 기준선·Rules 경고 표적 테스트 42건 통과. 두 변경 테스트 파일 정적 분석은 최초 동시 실행이 출력 없이 정지해 종료됐지만 파일별 재실행에서 각각 문제 0건으로 완료됐다. 로컬 전체 Rules Emulator는 F0에서 확인한 Windows 업로드 503 때문에 반복하지 않았다.
- 변경 후 Rules SHA-256은 `EB5C6D9AAC313C44A7588495561C666D9A937AE724194D8278E552A83B1A9DF0`이며 운영 미게시다. Actions·Rules 게시·실기기 완료 전에는 F1을 최종 완료로 판정하지 않는다.

# 2026-09-16 C* 기능 복구 F0 — 실행 기준·전체 Rules 회귀 진입점 정리

- 구조 개선 전 `firestore.rules-backup`은 배포 원본이 아닌 로컬 비교 자료로 분류해 ignore 처리했다. 이전 보석 진단 도구는 `test/tool/lost_ark_gem_probe_test.dart`이며 이번 미추적 파일과 무관하다.
- 미추적 생성 권한 도구를 현재 추적 `firestore.rules`의 그룹·모집 생성 기준선인 `tools/party_group_cutover_rules_test.mjs`로 정리했다. demo 프로젝트 전용 GitHub Actions와 정적 계약 테스트를 추가했으며 운영 프로젝트 인증·배포는 사용하지 않는다.
- 기준 해시: Rules `B9185B07241CC93880212616CB14C5823BD55EF7D71D8E4AC38B8D5EA0BA4DA1`, Indexes `87716AC3100BC18065EBE96E1B78D09E37D21BB0E4A87BFA468B056C151EEE03`, 백업 `A66F8AE04AEEE633F3AD30A66A6345C974011B2A95767B3F9955A1573D17E0A7`.
- 로컬 JBR 21에서 Firestore Emulator는 시작했으나 전체 Rules 업로드가 Rules 평가 전 `503 Network closed for unknown reason`으로 종료됐다. 같은 로컬 접근은 반복하지 않고 GitHub Actions를 실제 Emulator 검증 경로로 유지한다.
- 신규 계약 테스트 2건 통과. 원격 Actions 실행은 커밋·push 이후 확인한다. 기능 코드·운영 Rules·Indexes·Firebase 배포는 변경하지 않았다.

# 2026-09-16 실기기 판정 — 생성·가시성만 확인, 나머지 미해결

- 사용자 확인: Rules 게시 이후 **고쳐진 것**은 (1) 레이드 모집방 생성 (2) 그룹 생성 (3) 목록·레이드 현황·상세에 모집이 보이는 것뿐이다.
- 그 외 보고했던 실패(그룹장 이전, 즉시가입, 신청 승인, 신청 불안정, orphan 방의 해산·공개전환·캐릭터변경·모집삭제, Listen deny 등)는 **실기기에서 아직 고쳐지지 않았다**.
- 로컬 코드·계약 테스트에 올라간 후보 수정은 있으나 실기기 완료로 쓰지 않는다. 미해결 목록·orphan 시나리오는 `NEXT_WORK.md` 「실기기 미해결」을 단일 기준으로 한다.
- 캐릭터 변경 OR 포함 Rules 재게시는 503으로 실패해 두었다.

# 2026-09-15 orphan 그룹 전용방·캐릭터 변경·모집 삭제 수정

- 원인: 그룹 탈퇴 후에도 그룹 전용 모집 파티장이 남아 orphan이 되고, 공개 전환 앱이 멤버십을 강제했으며, 모집 삭제가 leave를 호출해 unauthorized가 났다. 캐릭터 변경은 구 assignment Rules를 타고 listing 부분 패치도 deny됐다.
- 수정: 그룹→공개는 비멤버 파티장 허용, 모집 삭제→disband, `validAtomicMemberCharacterChange` OR, listing은 멤버일 때만 전체 sync, 그룹 전용방 파티장 탈퇴는 `activeGroupRaidExists`로 차단.
- Rules 재게시 시도 1회는 `projects/lost-party:test` **503**으로 실패. 즉시 재시도하지 않았다. 앱 재설치로 공개 전환·모집 삭제·승인/가입은 확인 가능하고, 캐릭터 변경은 Rules 재게시 후 확인한다.

# 2026-09-15 가입·승인·Listen deny 수정

- 승인: 원자 `PartyAtomicApprovalWritePlan`이 `resolutionReason: approved`와 `approvalCount` 미증가로 `validApplicationDecision`과 불일치했다. `approvedByApprover` + `approvalCount+1`로 맞췄다.
- 그룹 방 가입/승인: listing `memberCount` 부분 update는 Rules가 거부한다. `PartyRaidListingTx` 전체 Snapshot sync로 바꿨다.
- Listen: 상세가 비리더에게도 applications 전체 list·전원 cycles를 구독해 PERMISSION_DENIED가 났다. 신청 목록은 리더만, cycles는 리더·확정 멤버만 구독한다.
- 승인 경로에서 타 유저 stale `raidState` delete는 Rules상 본인만 가능하므로 본인 즉시가입에서만 삭제한다.
- Rules: `firebase deploy --only firestore:rules --project lost-party` 1회 성공(`compiled successfully`). CLI는 `already up to date, skipping upload`를 표시했으나 `released rules`·`Deploy complete`까지 확인했다. Indexes는 배포하지 않았다. **앱 재설치 후** 신청→승인·즉시가입·그룹 listing·이전을 확인한다.

# 2026-09-15 그룹장 이전·모집 비가시성 수정

- 그룹장 이전: `validAtomicGroupRecruitmentClose`/`Open`이 `lastRecruitmentId` 검사 전에 `getAfter(...).data`를 호출해 OR 평가 오류가 나고 transfer 분기에 도달하지 못했다. 키·string·`existsAfter` 가드 후 Body로 분리했다. UI는 `groupTransferFailureMessage`로 가입 문구 재사용을 끊었다.
- 모집 비가시성: 원자 생성은 `schemaVersion: 2`인데 공개 목록·내 레이드 현황·listing 필터·공개/현황 매퍼가 `1`만 허용했다. 읽기를 v2로 전환하고 membership·application은 v1을 유지했다. 계약 문서·표적 테스트를 갱신했다.
- Indexes 재배포는 불필요. **Close/Open 가드 포함 Rules 재게시와 앱 재설치 후** 실기기에서 이전·목록·현황을 확인한다.

# 2026-09-15 파티·그룹 생성 permission-denied 진단

- 증상: wipe 후 그룹·모집 생성이 `권한을 확인하지 못했습니다`로 실패, 활동 Character 조절은 성공.
- Rules: stale `raidState` delete에 orphan·`incompleteEnded`·만료 1회성을 허용하고, 원자 생성의 `groupActiveRecruitmentCountAfter`를 그룹 `getAfter` 카운트와 맞추며, `groupMembershipState` update의 깨진 list/revision 기본값을 허용했다.
- 앱: 깨진 membership 요약을 빈 상태로 복구, 생성 시 수동 Claim을 먼저 검사, 그룹 카운트 after를 현재+1로 기록, 기본 그룹명 20자 상한을 적용했다.
- 로컬 Firestore Emulator는 Java 미설치로 미실행. 계약·매퍼 테스트로 회귀한다. **수정 Rules 재게시와 최신 앱 재설치가 필요**하다.

# 2026-09-15 파티·그룹 명령 재설계 — Rules·Indexes 게시 완료·wipe 경로 문서화

- 사용자가 운영 `lost-party`에 R7 Rules와 Indexes를 게시했다. 구현·Rules·Indexes 구간은 완료로 본다.
- `NEXT_WORK`에 wipe 보존·삭제 Firebase 경로를 상세히 적었다. 남은 작업은 필요 시 wipe와 디바이스 전체 흐름 회귀다.

# 2026-09-15 파티·그룹 명령 재설계 — R7 legacy Rules 정리

- C* `allow`에서 떼어낸 legacy validator·`validPlayerEvent` fan-out 등 55개 미사용 함수를 제거했다. `validAtomicStaleRaidStateDelete`는 `stateId` 검증을 추가했다.
- `tools/prune_r7_unused_rules_functions.mjs`로 도달 가능성 기준 정리를 재현할 수 있게 했다. Rules 계약 테스트 35건 통과.
- CLI `/test`는 503으로 컴파일 성공 여부를 확정하지 못했다. 이후 사용자가 콘솔에서 Rules·Indexes 게시를 완료했다.

# 2026-09-15 파티·그룹 명령 재설계 — C* Rules 게시 실패·R7 착수

- `firestore.rules-backup`으로 C* Rules 원본을 로컬 보존했다. `firebase deploy --only firestore --project lost-party` 1회는 `/test` 503으로 실패했고 Indexes 업로드에는 도달하지 않았다.
- Firebase 콘솔 게시는 legacy 미사용 validator·`validPlayerEvent` fan-out 등 약 55개 함수가 남아 `Unused function`과 `getAfter`/`request` 문맥 오류로 저장 불가했다. 인덱스 미배포와 무관하다.
- R7로 `allow`에서 떼어낸 legacy 함수 본문을 제거한 뒤 Rules·Indexes 1회 배포, wipe, 디바이스 회귀 순으로 운영 반영한다.

# 2026-09-15 파티·그룹 명령 재설계 — C* Router/DI·읽기·구 경로 차단

- 운영 Router에 원자 create/application/join/visibility/command와 membership·cycle 어댑터를 연결했다. `setRecurrence`는 모집 원본만 갱신하고 `purgeStale`은 `raidState`를 정리한다.
- `partyEvents` audience get/list와 sync/read를 전환했고, 구 assignment·slot·cycle 쓰기·파티 Claim·개인 party event create를 닫았다. 수동 Claim과 분쟁 이벤트는 유지한다.
- 리더 membership·stale raidState delete Rules를 보완했다. 테스트 자료 초기화 절차를 `NEXT_WORK`에 기록했고 운영 배포는 수행하지 않았다.

# 2026-09-15 파티·그룹 명령 재설계 — 운영 Rules R6 Aggregate 멤버십 갱신

- 모집 update에 신청 집계·가입·캐릭터·자리·탈퇴·visibility Aggregate OR를 추가하고 구 join/revision/visibility/removal 분기는 유지했다.
- 원자 가입 membership create·탈퇴 delete는 assignment 대신 `raidState`를 보고, membership 경로의 raidState delete와 그룹 `activeRecruitmentCount` open·visibility listing write OR를 열었다.
- 승인자가 대상 `raidState`를 만들 수 있도록 R5 create 조건을 완화했다.
- R6 계약 테스트를 추가했고 운영 Firebase 배포는 수행하지 않았다. 다음은 C*다.

# 2026-09-15 파티·그룹 명령 재설계 — 운영 Rules R5 membership raidState·partyEvents create

- `validAtomicRaidStateCreate`를 추가해 schemaVersion 2 모집의 `raidStateTargets`와 membership·주간 Claim을 검증하는 create OR를 열었다. lifecycle update/delete는 R2를 유지한다.
- `validAtomicMembershipPartyEvent`를 추가해 생성·가입·신청·캐릭터·자리·탈퇴·추방 이벤트 create OR를 lifecycle create와 병행했다.
- R5 계약 테스트를 추가했고 운영 Firebase 배포는 수행하지 않았다. 다음은 R6다.

# 2026-09-15 파티·그룹 명령 재설계 — 운영 Rules R4 schemaVersion 2 모집 생성

- `validAtomicInitialRecruitment`를 추가해 schemaVersion 2 모집 생성 OR를 `validInitialRecruitment`와 병행했다. v1 생성·slot·assignment 검증은 유지한다.
- 원자 생성은 `partySlots`·`raidStateTargets`·집계 초기값·명령 봉투 null과 leader membership·`raidState` `getAfter`를 검증하고 slot·assignment 경로는 쓰지 않는다.
- R4 계약 테스트를 추가했고 운영 Firebase 배포는 수행하지 않았다. 다음은 R5다.

# 2026-09-15 파티·그룹 명령 재설계 — 운영 Rules R3 그룹 activeRecruitmentCount

- `validInitialGroup`에 `activeRecruitmentCount` 키를 허용하고 생성 시 0을 강제해 Write Plan과 맞췄다.
- `validAtomicGroupRecruitmentClose`에 활성 수 감소·`lastRecruitmentId`·revision·updatedAt만 바꾸는 affectedKeys와 양의 정수 검사를 보강했다.
- R3 계약 테스트를 추가했고 운영 Firebase 배포는 수행하지 않았다. 다음은 R4다.

# 2026-09-15 파티·그룹 명령 재설계 — 운영 Rules R2 lifecycle OR

- 증명 Rules의 lifecycle 검증을 `atomic*` 접두사로 운영 `firestore.rules`에 이식하고, 모집 update·raidState update/delete·partyEvents create·group close·listing update/delete에 OR로 연결했다.
- 구 `validCycleCompletion`·`validRecruitmentDisband`·assignment·Claim·개인 event 경로는 유지했다. raidState create는 계속 닫아 R5에 남긴다.
- `groupId`는 빈 문자열이 아니라 문자열 존재 여부로 판정해 운영 문서의 null/생략과 맞췄다.
- R2 계약 테스트를 추가했고 운영 Firebase 배포는 수행하지 않았다. 다음은 R3다.

# 2026-09-15 파티·그룹 명령 재설계 — 운영 Rules 복구 슬라이스 시작

- 운영 Rules를 R1~R6 추가형 복구 커밋과 C* 연결 묶음으로 구분했다. 구 경로를 닫거나 Router/DI를 바꾸는 단계는 연결 묶음에서만 수행한다.
- R1로 `players/.../raidStates`와 `partyEvents` match 스캐폴드를 추가하고 쓰기는 닫아 두었다. 구 assignment·Claim·개인 event 경로는 유지한다.
- 계약 테스트로 R1 스캐폴드와 증명 Rules 분리를 고정했다. 운영 Firebase 배포는 수행하지 않았다.

# 2026-09-15 파티·그룹 명령 재설계 — 공개↔그룹 전환과 그룹 해산 게이트

- 공개↔그룹 전환 비연결 원자 Repository를 추가했다. `nonGroupMemberCount`·`pendingNonGroupApplicantCount`와 그룹 `activeRecruitmentCount`만으로 전환을 판정·갱신하며 멤버·신청자 전원 그룹 membership 순회를 쓰지 않는다.
- 그룹 생성 Write Plan에 `activeRecruitmentCount: 0`을 넣고, 그룹 해산은 `raidListings.limit(20)` 순회 대신 `GroupActiveRecruitmentWritePlan.validateDisband`를 사용한다.
- 계약 테스트로 원자 visibility Router 미연결과 해산 게이트·생성 초기값을 고정했다. 표적 테스트와 변경 파일 정적 분석이 통과했다.
- 운영 Rules·Router/DI·`partyEvents` 읽기 전환은 수행하지 않았다. 다음은 일괄 연결 단계다.

# 2026-09-15 파티·그룹 명령 재설계 — 생성·신청·가입·승인·캐릭터·자리 원자 Repository

- 생성·신청·재신청·철회, 즉시 가입·승인·거절, 캐릭터 변경·자리 이동의 비연결 Firestore 원자 Repository를 추가했다.
- 신청 거절 Write Plan을 보완해 pending·비그룹 신청 집계를 줄이고 공용 `applicationRejected` 이벤트 한 건만 남긴다. 재신청은 기존 apply 계획으로 pending을 다시 올린다.
- 생성·가입은 `raidState`로 점유·주간 완료를 판정하고 assignment·Claim·slots·개인 event·전원 membership 재조회를 쓰지 않는다. 그룹 생성 시 `activeRecruitmentCount`를 증가시킨다.
- 캐릭터 변경은 이전 `raidState` 삭제와 신규 상태 생성, 자리 이동은 대상 membership 1~2건만 갱신한다.
- 계약 테스트로 운영 Router 미연결과 구 경로 금지를 고정했다. 표적 Write Plan·계약 테스트 16건과 변경 파일 정적 분석이 통과했다.
- 운영 `firestore.rules`·Router/DI·`partyEvents` 읽기 전환은 수행하지 않았다. 다음은 공개↔그룹 전환 Repository와 그룹 해산 `activeRecruitmentCount` 게이트다.

# 2026-09-14 파티·그룹 명령 재설계 — 권장안 확정과 접근량 감사

- 계정·게임 계정·캐릭터 인증 자료는 보존하고, 새 스키마 전환 때 기존 파티·그룹·신청·회차·이벤트 테스트 자료를 초기화하며 구·신 스키마 호환 계층은 만들지 않기로 확정했다.
- 해산 pending 신청자는 서버 이벤트 fan-out 없이 모집 원본 종료로 자동 숨기고 로컬에서 한 번 안내한다. 종료 하위 문서는 첫 출시에서 자동 삭제하지 않고 활성 판정에서 제외한다.
- 완료·취소·주차 전환·해산은 온라인 전용 원자 명령으로 고정하고 오프라인 큐·단계형 후처리를 사용하지 않는다.
- 코드 감사 결과 전체 완료·취소는 고정 3 + `3N`, 주차 전환은 고정 3 + `2N`, 활성 해산은 member/application/assignment/slot과 event가 `N+A`로 증가함을 기록했다. 공개→그룹 전환과 그룹 해산의 20건 절단 순회도 Aggregate로 교체한다.
- 통합 `raidState`, 모집 8칸 구성 요약, 그룹 `activeRecruitmentCount`, 공용 이벤트, 명령 검증 봉투와 최대 8인 목표 예산을 설계 문서에 고정했다. 이 시점에는 앱 코드·Rules·배포를 변경하지 않았다.
- 구·신 스키마를 병행하지 않는 결정 때문에 부분 전환을 `dev`에 순차 병합하지 않는다. 단일 `feature/party-group-command-redesign`에서 Rules 예산 증명, 비연결 구현, 전체 Router/DI 전환, 테스트 자료 초기화와 회귀 검증을 마친 뒤 한 번에 `dev`로 통합한다.
- 설계 커밋 `b595b68`을 로컬 `dev`에 fast-forward 통합했고 사용자 승인 후 `origin/dev`도 같은 시점으로 푸시했다.
- 기능 브랜치에서 운영 `firestore.rules`와 분리된 `tools/party_scalability_proof.rules`, 1·2·4·8인 lifecycle·그룹 해산 및 누락·stale revision·비권한 거절 Emulator 시나리오를 추가했다. 정적 계약 테스트 5건과 JS 문법 검사는 통과했다.
- Android Studio 번들 JBR 21(`D:\dev\android\jbr`)로 Firestore Emulator 자체 기동은 확인했다. 그러나 Rules 로딩, 최소 deny-all 대조군, 단순 REST·클라이언트 쓰기가 모두 `503 Network closed for unknown reason` 또는 HTTP/2 protocol error로 끊겨 Rules 평가까지 도달하지 못했다. Docker는 없고 WSL 배포판도 설치되어 있지 않다. 첫 엔진 검증 게이트는 미통과이며 정상 격리 환경에서 통과하기 전 운영 Rules·Repository·Router 전환은 진행하지 않는다.
- 증명 스크립트가 Rules Test Context와 modular `getFirestore`를 혼용하던 부분을 compat context API로 통일했다. 이는 정상 Emulator 환경에서 실행 자체가 SDK 타입 오류로 막히지 않게 하는 테스트 하네스 수정이며 운영 코드는 변경하지 않는다.
- Windows 호스트 장애를 우회하는 첫 엔진 검증용 GitHub Actions를 추가했다. 기능 브랜치의 증명 파일 변경과 수동 실행에만 반응하고 Ubuntu·JDK 21·`demo-party-scalability` Emulator·전용 Rules 설정만 사용한다. 운영 Firebase 프로젝트 인증이나 배포 단계는 포함하지 않는다.
- GitHub Actions 실행 `34848336222`에서 의존성 설치와 격리 Firestore Emulator Rules 증명이 1분 13초에 모두 통과했다. 1·2·4·8인 lifecycle·그룹 해산과 누락 대상·stale revision·비권한 actor 거절 계약이 실제 Rules 엔진에서 확인되어 첫 구현 게이트를 통과했다. Actions 런타임의 action 버전 사용 중단 예고 두 건은 Rules 컴파일 경고가 아니며 증명 결과에는 영향을 주지 않는다.
- 운영 연결 없이 새 Domain 계약을 추가했다. 통합 `raidState`의 결정적 ID, 최대 8칸 구성 Aggregate와 집계 불변식, 최대 8개 직접 대상 명령 봉투, `expectedRevision`·`lastCommandId` 기반 응답 유실 판정 및 새 Repository 인터페이스를 정의했다. 운영 Repository·Rules·Router/DI는 변경하지 않았고 신규 Domain 6건과 기존 증명 계약 6건, 영향 정적 분석이 통과했다.
- 비연결 Firestore Aggregate 매퍼와 원자 Write Plan을 추가했다. 알 수 없거나 누락된 새 스키마는 추측하지 않고 거절하며, 명령 대상은 현재 고정 슬롯의 Player·Character와 일치해야 한다. 완료·취소·전환은 모집과 모든 `raidState`를 같은 다음 revision으로 만들고 활성 해산은 대상 상태를 삭제하며 완료 후 해산은 대상을 0건으로 제한해 완료 상태를 보존한다. 공용 이벤트는 한 건만 계획하고 8인 최대 쓰기 11건·완료 후 해산 3건을 테스트로 확인했다. 신규·기존 표적 테스트 21건과 정적 분석이 통과했으며 운영 연결은 변경하지 않았다.
- 새 Repository 초안을 운영 연결 없이 작성하던 중 최초 증명이 반복방과 1회성 상태를 충분히 구분하지 않은 것을 발견해 초안을 폐기하고 계약 게이트로 돌아갔다. 반복방 완료는 모집 `active`·회차 `completed`, 완료 취소는 반복방에서만 허용, 미완료 `active` 회차도 다음 주차로 전환 가능, 1회성 완료는 모집 `completed`, 완료 후 해산은 `raidState`를 보존하도록 Rules·Write Plan·Emulator 시나리오를 맞췄다. 공용 이벤트의 actor 필드도 Rules allowlist와 일치시켰다. 운영 Repository·Rules·DI는 변경하지 않았으며 보강된 격리 Actions 재검증 전 Repository 구현을 진행하지 않는다.
- 보강된 GitHub Actions 실행 `34851122346`이 38초에 통과한 뒤 새 Firestore 원자 Repository를 비연결 상태로 구현했다. 한 Transaction에서 인증 바인딩·리더·revision·회차·직접 대상 `raidState`만 검증하고, 모집 Aggregate·최대 8개 상태·그룹 listing 또는 집계·공용 이벤트 한 건을 Write Plan대로 기록한다. 동일 `commandId` 재조회는 이미 적용된 revision을 성공으로 판정한다. 기존 assignment·Claim·개인 event·members·slots 순회는 사용하지 않으며 Router/DI와 운영 Rules는 변경하지 않았다. 관련 Domain·매퍼·Repository 계약 26건과 정적 분석이 통과했다.
- 생성·가입의 기존 Write Plan을 버리지 않고 확장하는 비연결 원자 계획을 추가했다. 기존 membership의 보석·아크그리드 통합 Snapshot은 그대로 보존하고 assignment 대신 최초 revision 1의 `raidState`, 최대 8칸 `partySlots`·전체 `raidStateTargets`와 공용 이벤트 한 건을 만든다. 가입 시 현재 슬롯과 파티 구성 정책을 다시 검증하며 그룹원 여부에 따라 `nonGroupMemberCount`만 증감한다. 모집 revision과 개별 `raidState` revision을 분리해 가입 때 기존 전원 상태를 다시 쓰지 않도록 했고 lifecycle 상태 갱신은 각 상태의 `FieldValue.increment(1)`을 사용한다. 운영 생성·가입 Repository와 Router/DI는 아직 변경하지 않았다.
- 신청·재신청·철회는 membership·`raidState` 없이 모집의 pending 집계와 신청 문서·공용 이벤트만 변경하고, 승인이 확정될 때 가입 계획을 결합하도록 비연결 Write Plan을 추가했다. 그룹 연결 모집은 신청자의 현재 그룹 자격에 따라 `pendingNonGroupApplicantCount`를 함께 증감한다.
- 캐릭터 변경은 대상 membership과 기존 `raidState` 삭제·새 상태 생성, 모집 고정 슬롯·대상 목록과 공용 이벤트만 변경한다. 자리 이동은 빈자리에서 membership 1건, 점유 교환에서 2건만 갱신하며 모집 Aggregate와 이벤트·필요 listing을 포함해 최대 5건으로 제한했다. 파티장 자리 이동, 범위 밖 위치와 파티 구성 위반은 계획 단계에서 거절한다. 기존 Build Snapshot·membership 회귀를 포함한 표적 테스트 15건과 정적 분석이 통과했고 운영 Repository·Rules·Router/DI는 변경하지 않았다.

# 2026-09-14 release/1.0.0 후보 폐기와 파티·그룹 명령 재설계 전환

- 사용자 결정으로 기존 `release/1.0.0` 후보를 폐기했다. 브랜치는 삭제하지 않고 이력·비교용으로 보존하며 출시·`main` 병합 기준에서 제외한다.
- 최신 앱·운영 Rules·새 다인 모집에서도 해산 `permission-denied`가 재현됐다. 모집 중 해산 버튼을 숨기는 임시 UI는 완료 후 방 마무리까지 막아 기존 상태로 복원했다.
- 코드 감사에서 전체 완료·취소·주차 전환·해산, 즉시 가입, Character 변경, 탈퇴·추방, 자리 이동·교환과 일부 그룹 연결 명령이 인원수에 따라 membership·Claim·assignment·slot·개인 event 읽기·쓰기를 늘리는 구조임을 확인했다.
- UI·제품 전체 재개발 대신 Firestore 명령 Repository, Rules, 공용 이벤트와 모집 Aggregate를 재설계한다. Spark에서 앱 종료 후 서버 후처리 완료를 보장할 수 없는 단계형 Projection 방식은 채택하지 않는다.
- 현재 최대 8인 범위의 완료·취소·주차 전환·해산은 통합 `raidState`를 포함한 한 번의 제한 원자 명령으로 확정한다. 종료된 membership·slot·application은 부모 모집 상태로 기능에서 제외하고, 지연 정리는 정확성·사용자 행동과 분리한다. 앱 종료 또는 응답 유실 뒤에는 `status`·`revision`·`lastCommandId` 재조회로 결과를 자동 판정한다.
- 장기 기준은 `docs/architecture/PARTY_GROUP_COMMAND_SCALABILITY_REDESIGN.md`, 첫 단계는 `NEXT_WORK.md`에 기록했다.
- 사용자 결정으로 현재 기능 상태와 알려진 결함 기록을 `dev`의 새 재작업 기준점으로 올린다. 이는 릴리즈 가능 판정이 아니며, `main`과 폐기된 `release/1.0.0`은 구조개선·회귀 검증 완료 전 유지한다.
- 이 기록 시점에는 새 데이터 구조·Repository·Rules 구현과 배포를 시작하지 않았다.

# 2026-09-13 릴리즈 인증 UX·파티 통합 오류 전파 — 사전 조사와 설계

- 장비 인증 Challenge는 `LocalGameAccountVerificationGateway` 메모리에만 두고 앱 프로세스 종료 시 인증 시도도 종료하는 현재 방식을 유지하기로 확정했다. 인증 진행 카드에 앱 종료 시도 종료와 인게임에서 즉시 장비를 조작할 수 있을 때 진행하라는 안내를 추가한다.
- 시작 시 무기·방어구 5부위 중 하나라도 미장착이면 Gateway는 이미 `FormatException`을 던지지만 화면이 모든 형식 오류를 일반 정보 실패로 합치는 원인을 확인했다. 6부위 누락만 식별 가능한 시작 오류와 전용 착용 안내로 분리하고 실제 API/응답 오류의 일반 안내는 유지한다.
- 신청·즉시 참가·Character 변경 후보는 로컬 통합 Build 오류를 표시하지만 선택 결과와 파티 명령·서버 신청·membership은 보석 전용 Snapshot만 전달한다. 이 때문에 아크그리드·아크패시브 오류가 신청자·구성원 카드에서 사라지는 구조적 누락을 확인했다.
- 기존 보석 요약을 유지하면서 신청과 membership에 `buildIntegritySnapshot`을 dual-write하고 생성 리더·신청·직접 참가·승인·Character 변경을 모두 같은 경계로 맞춘다. 과거 null 호환과 오류 Character 선택 허용은 보존한다.
- 구현 전 데이터 수명, Router/DI, 명령·Write Plan·읽기 모델과 Rules의 Character 변경 allowlist를 대조했다. 상세 작업 순서와 회귀 보호 범위는 `NEXT_WORK.md`, 장기 계약은 관련 인증·Build 무결성 문서에 기록한다. 이번 단계에서는 기능 코드를 수정하지 않는다.

# 2026-09-13 다수 활동 Character 저장 권한 한도 — 구현·자동 검증

- 실기기에서 기존 활동 Character 8명은 저장되지만 15명 활성화 시 `permission-denied`가 발생했다. 현재 Repository가 최종 선택 전체를 단일 Transaction에서 다시 쓰고 Rules가 각 Character 소유권 문서를 조회해 원자 작업당 문서 접근 20회 한도를 넘는 것이 원인이다.
- 최종 선택 전체의 Domain 검증은 유지하고 실제 쓰기는 기존 정상 문서를 제외한 차이만 최대 4개씩 처리하도록 변경했다. 각 계정 대표 Character 추가를 먼저, 일반 추가·갱신을 다음, 비활성 삭제를 마지막에 수행한다.
- 여러 묶음은 전체 원자 저장이 아니므로 중간 실패 시 성공으로 확정하지 않는다. 추가 우선 순서로 기존 대표·최소 1명 상태를 보존하고 같은 선택을 재시도하면 남은 차이만 반영해 수렴한다.
- 8→15 신규 7개 `4 + 3` 저장, 15→8 삭제, 본·부계정 대표 우선, 두 번째 묶음 실패 후 재시도, 기존 권한·소유권·화면 저장 회귀를 추가했다.
- Repository·Write Plan·Domain·ViewModel 표적 37건, 계정 기능 전체 256건, 그룹·모집·레이드 소비 경로 26건과 변경 파일 `flutter analyze`, `git diff --check`, Node 진단 도구 문법 검사가 통과했다.
- 실제 Rules Emulator용 15명 분할 저장 검증도 추가했으나 전체 운영 Rules 로딩 단계에서 기존 `503 Network closed for unknown reason`가 재현돼 요청 실행 전 차단됐다. 이를 통과로 기록하지 않으며 실기기 8→15·재진입·15→8 확인이 남았다.
- `firestore.rules`, 그룹·파티·Claim 계약은 변경하지 않았고 Firebase 배포도 수행하지 않았다.
- 사용자가 수정 빌드에서 Character 수 변경 저장과 앱 재실행 후 유지가 정상임을 확인했다. 그룹·레이드 후보 반영과 기존 파티·그룹·주간 완료 기록 보존도 정상으로 확인해 실기기 완료 조건을 통과했다.

# 2026-09-12 Character Build 아이콘 fallback·중립 표시 보정 — 구현·자동 검증

- 실기기 확인에서 카탈로그 미등록 직업의 보석 대상이 API 스킬 밖이어도 아이콘 URL에 `ark_passive`가 포함되면 정상 처리되는 fallback을 확인했다. 실제 API 표본에는 특수 스킬이면서 해당 문자열이 없는 사례도 있어 URL을 모든 판정·후보 추출 근거에서 제외하기로 확정했다.
- 화면은 정상과 판정 불능을 모두 비표기하고 확정 오류만 빨간색으로 표시한다. 내부 unavailable/review와 v1/v2 parser는 오판·과거 데이터 보호를 위해 유지한다.
- 환수사 `둔갑 금술 스킬`, 가디언나이트 `가디언 피어`, 데모닉 `블러드 제노사이드`는 등록하지 않고 오류 회귀 표본으로 사용한다. 실제 캐릭터명과 전체 API 원본은 Git에 커밋하지 않는다.
- mapper에서 아이콘 fallback을 제거하고 카탈로그 미등록 직업도 현재 Character 직업명을 Tooltip 비교 기준으로 사용하게 했다. 공용 Character/Party 상태와 내 계정은 review/unavailable을 숨기고 확정 오류만 표시한다.
- 진단 도구는 여러 캐릭터명을 한 번에 조회해 전체 응답을 OS 임시 폴더에 저장하고 `ArmorySkills`와 승인 카탈로그 양쪽에 없는 후보만 보고한다. 실제 두 캐릭터 조회로 동작을 확인했으며 토큰은 출력·저장하지 않는다.
- 표적 묶음 103건 중 제거한 fallback을 기대하던 과거 테스트 1건을 새 계약에 맞춰 정정했다. mapper 25건과 진단 도구 6건, 변경 파일 analyze가 통과했다. 전체 테스트는 1,032건 통과하고 기존 Firebase 미초기화 `widget_test.dart` 9건만 실패했다. 전체 analyze는 기존 39건이며 신규 문제는 없다.
- `firestore.rules`와 저장 schema는 변경하지 않아 Rules 검사·운영 배포를 수행하지 않았다. 실기기 확인 전에는 `dev`에 병합하지 않는다.

# 2026-09-12 Character Build 확정 오류 판정·표기 — 구현 및 자동 검증

- `codex/implement-build-error-policy`에서 장착 보석 11개 미만, 타 직업 보석, API 스킬·특수 카탈로그 양쪽에 없는 보석과 기존 아크그리드 최소/조건 오류를 빨간 확정 오류로 통일했다. 원본·Tooltip 정보 부족은 중립으로 분리했다.
- Character `buildIntegritySnapshot`과 파티·그룹 `gemValidationSnapshot`의 새 쓰기를 v2로 올렸다. 과거 v1은 당시 의미로 읽고, 누락·손상·알 수 없는 Snapshot은 기존 Character·신청·membership 행을 깨뜨리지 않도록 유지했다.
- 내 계정은 보석 부족·타 직업·스킬 불일치 수를 구체적으로 표시하고, 그룹 활동 목록은 `보석 오류`·`아크그리드 오류`, 파티·그룹 간략 카드는 v2 오류 요약을 표시한다. 계정 갱신과 기존 신청→승인→membership 복사 흐름을 재사용했으며 새 조회·권한 조건·네트워크 호출은 추가하지 않았다.
- 단계별 mapper·Snapshot·계정·그룹·신청/membership 회귀를 통과했다. 최종 파티 상세 42건과 변경 파일 analyze는 통과했다. 전체 테스트는 1,029건 통과, 기존 `test/widget_test.dart` Firebase 기본 앱 미초기화 9건 실패이며 이번 영향 범위의 신규 실패는 0건이다. 전체 analyze는 기존 파일의 40건으로 exit 1이고 이번 변경 파일에는 문제가 없다.
- `firestore.rules`는 변경하지 않아 Rules 계약 검사와 운영 배포를 수행하지 않았다. 실기기 체크리스트 확인 전에는 `dev`에 병합하지 않는다.

# 2026-09-12 Character Build 확정 오류 정의 — 협의 완료

- 빨간 확정 오류를 장착 보석 11개 미만, 타 직업 보석, 현재 API 스킬과 등록 특수 스킬 양쪽에 없는 같은 직업 보석, 질서의 해·달 누락/각 14P 미만, 장착 아크그리드 요구 아크패시브 불충족으로 확정했다.
- 카탈로그 미등록은 중립 사유로 사용하지 않는다. 정상 아이덴티티·Character 고유·아크패시브 생성 스킬은 사용자가 직업·깨달음 분기별 특수 스킬 카탈로그에 점진적으로 추가하며, 등록 후 정상 판정으로 전환한다.
- API·Tooltip 원본 자체의 누락·파싱 실패만 중립 정보 부족으로 남긴다. `ArmoryGem/Gems` 부재를 장착 0개로 오판하지 않고, 확정 장착 개수와 Effects 연결 개수를 분리하도록 구현 계획을 잡았다.
- 현재 `sameClassTargetUnverified` 중립 의미와 새 확정 오류의 소급 혼동을 막기 위해 Character Snapshot v1/v2 호환, 구버전 방어적 읽기와 같은 시각 재산출을 사전 검증한다.
- `NEXT_WORK.md`를 협의 대기에서 구현 가능한 단계·회귀 목록·완료 조건으로 교체했다. 이 구간은 문서만 변경하며 앱 코드·Rules·배포는 변경하지 않는다.

# 2026-09-11 Character Build 오류 표기 재정의 — 협의 우선 기록

- 실기기에서 Build 무결성 상태 표시·관련 회귀 체크리스트는 통과했다.
- Character에 대한 오류·검토 표기(`보석`, `아크그리드`, `보석 확인 필요`, `보석 정보 없음` 등)의 의미와 명확성을 재정의하는 토의가 필요하다.
- 다음 문서 정리의 **제1 작업**은 구현이 아니라 이 표기 계약 협의다. 코드 변경은 합의 확정 후에만 한다. 상세는 `NEXT_WORK.md`.

# 2026-09-11 Character Build 무결성 상태 — 구현·자동 검증·dev 병합

- 브랜치 `cursor/character-build-integrity-status`에서 계정 갱신 최소 표시 Transaction에 `buildIntegritySnapshot`을 동반하고, 그룹원 활동 Character bottom sheet에 상태 라벨을 표시했다.
- 구현: 공용 Snapshot·mapper, 최소 표시 Patch/Sync/Gateway, 일반·수동 재인증 `set`의 `combatPower`·무결성 보존, `GroupRequestCharacter` 방어적 읽기, 활동 목록 Chip UI. Rules·쿼리·DI 추가는 없다.
- 자동 검증: mapper/parser, 최소 표시 Sync·Gateway, 재인증 보존 helper, 그룹 검색 mapper, 그룹원 활동 UI, 자동 갱신 Coordinator 관련 테스트를 통과했다. 전체 `flutter test`의 `widget_test` Firebase 미초기화 9건은 base `5fc0353`에서도 동일해 이번 변경과 무관하다.
- 실기기 체크리스트는 2026-09-11 사용자 확인으로 통과했다. 표기 의미 재정의는 별도 협의 작업으로 남긴다.

# 2026-09-11 AI 작업 자동 진입점 — AGENTS.md


- 사용자가 새 AI 작업마다 개별 문서를 다시 나열하지 않아도 되도록 저장소 루트에 `AGENTS.md`를 추가했다.
- 핵심 실행 게이트로 문서 확인 순서, 구현 전 설계, 기존 완성 기능 회귀 보호, 작업 브랜치 생성·병합·푸시, 검증 완료 판정과 Firestore Rules 1회 배포·실패 후 재시도 제한을 명시했다.
- `docs/README.md`는 문서 설명과 탐색 지도, `ai_rules.md`는 상세 협업 정책으로 유지하고 두 문서의 우선순위와 링크를 새 진입점에 맞게 갱신했다.
- 순수 문서 작업이므로 Flutter 코드·Rules·배포는 변경하지 않으며 `git diff --check`와 문서 링크·내용 검토로 검증한다.

# 2026-09-11 그룹 활동 Character Build 상태 — 사전 설계·회귀 점검

- 그룹원 탭의 활동 Character 목록에는 보석 전용 `gemValidationSnapshot`을 복제하지 않고, Character 문서의 선택 항목 `buildIntegritySnapshot`을 읽는 방향으로 확정했다. 기존 파티·그룹 membership의 `gemValidationSnapshot`은 가입·승인 시점 증거이므로 그대로 유지한다.
- 상태는 `clean/review/error/unavailable`로 단순화하되, 보석과 아크그리드 문제가 동시에 발생할 수 있으므로 `issueCodes`를 함께 저장한다. 최초 코드는 `foreignClassGem`, `sameClassGemUnverified`, `gemUnavailable`, `arkGridMinimum`, `arkGridCondition`이며 우선순위는 `error > review > clean`이다.
- `schemaVersion`, 판정 역할 `role`, `checkedAt`, `catalogVersion`을 포함해 구버전 읽기, 역할 변경, 늦게 도착한 갱신, 카탈로그 변경에 대비한다. 알 수 없는 값과 불완전 필드는 예외를 던지지 않고 상태 표시만 생략한다.
- 계정 자동·수동 갱신이 이미 사용하는 Character 최소 표시 Transaction에 상태를 같이 갱신한다. 그룹 화면은 기존 `characters` 조회와 활동 Character ID 교집합을 유지하며 별도 API·조회·인덱스·쓰기·권한 검사를 추가하지 않는다.
- 그룹·파티 Rules와 명령 검증 순서는 변경하지 않는다. 상태는 표시용이며 가입·승인·초대·양도·해산·Character 선택 가능 여부를 판정하지 않는다. 따라서 이번 구현 계획에는 Rules 배포가 없다.
- 재인증 경로 두 곳의 `transaction.set(characterRef, ...)` 전체 덮어쓰기가 선택 필드인 `combatPower`와 신규 상태를 지울 수 있음을 확인했다. 구현 시 저장된 유효 값을 보존하고 회귀 테스트를 추가한다. 구버전 앱이 지운 값은 새 버전의 다음 성공 갱신에서 복구된다.
- `GroupRequestCharacter`에는 nullable 상태를 방어적으로 추가하고 그룹 활동 Character 행에서만 소비한다. 그룹 검색, 초대, 레이드 상태 필터, 정렬, 동등성 비교에는 영향을 주지 않으며 작은 화면에서는 기존 부제 문자열 결합 대신 보조 행 또는 칩으로 표시한다.
- 기준선 회귀로 계정 갱신·최소 표시 Transaction·시작 갱신·활동 Character Rules·그룹 Rules·그룹원 표시 흐름의 7개 테스트 파일, 79건이 모두 통과했다. 이번 구간은 문서와 구현 계획만 변경하며 앱 코드·Firestore Rules·배포는 수행하지 않는다.

# 2026-09-11 그룹 membership 보석 Snapshot — dev 병합

- 브랜치 `cursor/group-membership-gem-snapshot`을 `dev`에 병합한다.
- 구현: 그룹 생성·신청·승인·코드 가입·본인 Snapshot 갱신에 `gemValidationSnapshot` 전파, 그룹원 목록 행 경고, 공용 Snapshot 모델 승격, Rules allowlist(콘솔 게시).
- 실기기: 파티 지원/가입 후 보석 표기, 그룹 초대 수락·그룹장 양도·해산 회귀를 확인했다. 그룹원 탭 후 활동 Character 목록 보석 표시는 이번 범위가 아니며 정의 대기로 남긴다.
- CLI Rules `/test` 503은 콘솔 붙여넣기 게시로 우회해 운영에 반영했다.

# 2026-09-11 그룹 활동 Character 목록 보석 표시 — 정의 대기 기록

- 실기기에서 그룹원 탭 후 활동 Character 팝업에는 보석 경고가 없고, 파티 모집 경로에만 보인다는 피드백을 받았다.
- 요구: 신청/표시 Character가 A여도 같은 원정대의 B 보석 이상을 그 팝업 리스트에서 확인하고 싶다. 자동 갱신·그룹 데이터 갱신만으로 현재 계약이 이를 보장하지 않는다.
- **구현 전에 제품·아키텍처 정의를 반드시 먼저** 한다. 정의 없이 코드를 넣지 않는다. 대기 항목은 `NEXT_WORK.md` 차후 대기와 `CHARACTER_BUILD_INTEGRITY_CONTRACT.md` §5에 기록했다.

# 2026-09-11 그룹 membership 보석 Snapshot — Rules 콘솔 게시

- 브랜치 `cursor/group-membership-gem-snapshot`에서 그룹 membership·join relation·본인 Snapshot 갱신에 파티와 같은 `gemValidationSnapshot` 다섯 필드를 전파했다.
- CLI `firebase deploy --only firestore:rules --project lost-party`는 두 번 모두 `/projects/lost-party:test` HTTP 503으로 종료돼 Ruleset/Release에 도달하지 않았고, 콘솔에도 해당 시도의 새 게시 이력이 생기지 않았다.
- 사용자가 동일 로컬 `firestore.rules`를 Firebase 콘솔 편집기에 붙여 넣어 즉시 게시에 성공했다. CLI `/test` 503과 콘솔 게시 성공이 같은 소스에서 갈라진 사례로 기록한다.
- 다음 완료 조건은 두 기기 실기기 체크리스트와 `dev` 병합이다. → 파티·그룹 회귀 확인 후 `dev` 병합으로 구간을 닫는다. 활동 Character 목록 보석 UI는 별도 정의 대기.

# 2026-09-10 Character Build 무결성 — 파티 membership 전파

- 브랜치 `codex/party-membership-build-snapshot`에서 신청 Snapshot의 최소 보석 검증 요약을 파티 membership까지 전파했다.
- 승인: 신청 `submittedBuildSnapshot`의 다섯 필드를 `gemValidationSnapshot`으로 재사용. 직접 참가·참가 Character 변경: 선택 역할의 최신 로컬 Build Snapshot을 명령에 실어 기록한다.
- membership DTO·쓰기 계획·방어적 읽기와 구성원 카드 UI를 연결했다. 정상은 숨기고 동일 직업 미확인은 중립, 다른 직업 보석만 빨간 경고다. 과거 membership·불완전 필드는 null로 읽고 아이템 레벨·전투력 표시는 유지한다.
- Character 변경 Rules `affectedKeys`에 `gemValidationSnapshot`만 추가했다. 다섯 필드 스키마 검증 함수는 넣지 않았다.
- 표적·영향 자동 테스트 69건 통과. 변경 파일 analyze는 기존 if 중괄호 info만 남았고 신규 error는 없다.
- 최초 dry-run은 `/projects/lost-party:test`에서 HTTP 503으로 종료됐지만, 동일 최신 Rules의 실제 배포 재시도는 컴파일·Ruleset 업로드·Cloud Firestore Release와 `Deploy complete`까지 모두 성공했다. 동일 소스의 후속 성공으로 직전 503은 일시적인 원격 실패로 판정한다.
- 통합 디바이스 테스트에서 승인·직접 참가·Character 변경 카드 표시를 확인한다.
- 다음 작업은 레이드 목록 로컬 필터·정렬이다.

# 2026-09-08 보석 Snapshot Rules 503 복잡도 완화

- Rules 배포의 `projects/lost-party:test` HTTP 503을 외부 서비스 장애가 아니라 코드 복잡도 우선으로 재진단했다. 188~189개 함수 호출 그래프에는 직접·간접 재귀가 없고 최대 호출 깊이는 6이었다.
- 최근 추가된 보석 Snapshot 검증은 이미 큰 신청·재신청 검증 경로에 별도 함수와 반복 OR로 연결돼 있었다. 1차 평탄화 후 `/test` 컴파일은 성공했으나 신규 Ruleset 저장에서 503이 계속됐다.
- 사용자 지시에 따라 이전 정상 배포 Rules는 건드리지 않고, 현재 보석 구간이 추가한 검증 함수와 호출 2곳만 제거했다. 보석 요약은 서버가 진위를 보장할 수 없는 클라이언트 표시 정보이므로 공식 앱 쓰기 생성기와 방어적 읽기가 담당한다.
- CLI 503 이후 Firebase Console Rules 타임라인에 15:18과 15:48 기록이 생성됐고 15:48이 현재 버전으로 표시됐다. 동일한 현재 Release와 로컬 소스라면 Firebase CLI 15.29.0은 업로드를 생략하므로, CLI의 503만으로 성공·실패를 단정하거나 반복 배포하지 않는다.
- Rules 계약 44건과 파티 신청 Snapshot 쓰기·읽기 19건, 최종 전체 테스트 922건이 통과했다. 로컬 환경에는 Java가 없어 Firestore Emulator 로딩은 실행하지 못했다. 다음은 Console 15:48 활성 소스 확인과 두 계정 실기기 검증이다.

## 2026-09-08 실제 API 보석 진단 기반과 Build 메모 차후 구상

- 배포 앱 UI와 운영 판정기를 바꾸지 않고 실제 Lost Ark Armory를 관찰하는 `tool/lost_ark_gem_probe.dart`와 순수 파서를 추가했다. 토큰은 `LOST_ARK_API_TOKEN` 환경 변수에서만 읽고 원문 응답·Authorization을 저장하거나 출력하지 않는다.
- 장착 보석 `Slot`과 효과 `GemSlot`을 연결하고 장착 보석 Tooltip·효과 설명/Tooltip의 대괄호 중 게임 카탈로그에 등록된 직업명만 추출한다. `[세레나데]`, `[풍요]` 같은 값은 직업에서 제외한다.
- 파서 표적 테스트 4개와 추가 3개 파일 정적 분석이 통과했다. 발키리/홀리나이트의 같은 `신앙 스킬` 직업 범위와 현재 발키리 `신앙 스킬`·바드 `템페스트 스킬` 카탈로그 공백을 고정했다.
- 사용자와 바드·발키리·홀리나이트·도화가의 dealer/support 8개 실제 Build, 보석 88개를 조회했다. 실제 특수 대상명과 Tooltip 직업 일치를 확인했으며 카탈로그와 운영 판정기 교정은 다음 구현 구간으로 남겼다.
- 전체 최적 Build 판정 대신 깨달음·아크그리드 Tooltip 조건, 질서 해·달 존재와 각 14P 이상, 보석 직업 일치의 기본 무결성만 책임지는 계약을 `../architecture/CHARACTER_BUILD_INTEGRITY_CONTRACT.md`에 작성했다.
- 직업·깨달음·질서 해·달·별 계층 메모, 점진적 Build 별칭, 파티 카드 표시, 최소 Build Snapshot과 JSON/서버 MemoPack 공유 구상을 `../product/BUILD_MEMO_SHARING.md`에 차후 작업으로 분리했다. 앱·Drift·Firestore·Rules는 아직 변경하지 않았다.

### 기본 무결성 A — 진단 범위 확장

- 진단 보고서에 카탈로그 감지 상태·branchId·표시 계열·역할, 깨달음 1·4티어, API 스킬 목록을 추가했다.
- 질서의 해·달·별 이름·등급·포인트와 해·달 각 14P 충족 여부를 출력한다. 별은 필수 판정에서 제외하고 혼돈 코어는 진단 요약에서 제외한다.
- 기존 분석기가 파싱한 아크그리드 Tooltip 조건, 충족 여부와 누락 아크패시브를 코어별로 출력한다.
- 표적 테스트를 5개로 확장해 해 17P 충족, 달 13P 미충족, 별 5P 필수 제외와 세 코어 조건 충족을 고정했다. 추가 파일 analyze도 통과했다.
- 앱 운영 판정·카탈로그·로컬 저장·UI·Firestore는 변경하지 않았다. 다음은 B 운영 보석 판정 모델이다.

### 기본 무결성 B — 운영 보석 판정 모델

- 진단 도구에 있던 Tooltip 대괄호 직업 추출을 공용 운영 코드로 이동하고, 장착 보석 `Slot`과 효과 `GemSlot`을 연결해 분석하도록 했다.
- 카탈로그 직업명·별칭만 추출하므로 룬·아이덴티티 대괄호는 직업으로 오인하지 않는다.
- 각 보석에 Tooltip 직업 목록과 `verified`, `sameClassTargetUnverified`, `foreignClass`, `unavailable` 검증 상태를 추가했다.
- 동일 직업 대상 미확인은 info, 다른 직업 보석만 warning으로 분리했다. 기존 `normal/passiveOrIdentity/unknown` 대상 종류는 호환을 위해 유지했다.
- 감지된 깨달음 분기가 있으면 해당 분기에 연결된 최소 특수 대상만 비교한다. 운영 UI·저장·Firestore는 변경하지 않았다.

### 기본 무결성 C — 실제 API 특수 보석 대상 교정

- 게임 카탈로그를 `2026.09.08`로 갱신하고 4직업 dealer/support 8개 실제 Build의 특수 보석 대상명을 분기별로 반영했다.
- 새로 교정된 값은 `템페스트 스킬`, 발키리·홀리나이트의 각 직업 범위 `신앙 스킬`, `심판자 스킬`, `음양 스킬`이다.
- 회귀 fixture 출처를 사용자 협업 실제 API 교차검증으로 바꾸고 `measuredAgainstLiveApi: true`로 고정했다.
- 바드 딜러 분기에서 서포터 전용 `세레나데 스킬`을 정상으로 인정하지 않는 회귀도 추가했다.
- 카탈로그 표적 테스트 34개와 전체 테스트 910개가 통과했다. 변경 파일 표적 analyze는 통과했으며 전체 analyze의 기존 lint 21건은 이 구간에서 수정하지 않았다.

### 기본 무결성 D — 질서 해·달 최소 조건

- 운영 분석 결과에 `ArkGridMinimumIntegrity`를 추가해 질서의 해·달 포인트, 존재 여부, 각 14P 충족 여부와 전체 충족을 명시했다.
- 해·달 누락 warning을 분리하고 혼돈 코어가 질서 코어 누락을 대신하지 않는 회귀를 추가했다.
- 13P 미충족, 해·달 20P 전체 충족과 기존 유물 17P 권장 안내를 함께 검증했다.
- 계정 분석·자동 갱신·저장·상세 화면·진단 도구 표적 테스트 44개와 전체 테스트 912개가 통과했고 변경 파일 표적 analyze도 통과했다. UI·저장·Firestore는 변경하지 않았다.

### 기본 무결성 E — 보석 집계와 내 계정 표시

- `CharacterBuildAnalysis`에 보석 검증 개수와 대표 상태 집계를 추가했다. 다른 직업을 최우선으로 하며 같은 직업 미확인·검증 정보 없음·정상을 분리한다.
- 내 계정 ViewModel이 선호 역할의 최신 로컬 Snapshot에서 전투력과 보석 집계를 함께 읽도록 했다. 전투력이 없는 Snapshot도 보석 검증에는 사용할 수 있다.
- 내 계정 카드에는 정상 시 아무것도 추가하지 않고 같은 직업 미확인·정보 없음은 중립, 다른 직업 보석만 error 색상으로 표시한다.
- 추가 네트워크 호출·DB migration·Firestore·Rules 변경은 없다. 집계·선호 역할 전달·카드·계정 페이지 표적 테스트 48개와 전체 테스트 917개가 통과했고 변경 파일 표적 analyze도 통과했다.
- 디바이스에서 실제 Snapshot 갱신 후 카드 문구와 좁은 폭 말줄임을 통합 검증해야 한다.

## 2026-09-05 Character 자동 갱신 — 실기기 실패 보고와 방향 전환(문서만)

- G 실기기에서 사용자가 교류 직전 자동 갱신 실패를 보고했다. “기존 데이터로 계속할까요?” 확인이 거의 100% 뜨고, Armory API 자동 갱신은 체감이 매우 느리다. 통신 호출 여부는 디버깅하지 않아 확정하지 않았다.
- 나이스단 자동 갱신 허용 UI는 정상이다. 허용을 켠 뒤에도 나이스단 직업 Character가 갱신되지 않고 같은 기존 데이터 안내가 뜨므로, 제외/허용 분기와 확인 UI 경로는 동작하는 것으로 보이며 실제 Armory 갱신 성공이 안 되는 쪽으로 해석했다.
- 사용자가 구현을 중지하고 방향을 바꿨다. 파티 모집·그룹 생성 등 **현재 걸린 모든 교류 시점 자동 갱신 조건을 철회**하고, 자동 갱신은 **앱 실행 시 1회**로 정정한다. 이번 기록에서는 기능 코드를 수정하지 않았다.
- A~F 구현과 G 자동 회귀(전체 테스트 875개, 머지 기준 `185c699`)까지의 상태는 유지한다. 다음 실행 기준은 `NEXT_WORK.md`다.

## 2026-09-04 Character 자동 갱신 G — 자동 회귀와 실기기 대기

- F를 `dev`에 병합했다(기능 `2aeccf5`, 머지 `185c699`). G 브랜치 `cursor/character-refresh-g-regression`에서 통합 회귀를 실행했다.
- 표적: 조정기·최소 Snapshot Gateway/Service·나이스단·그룹 표시·Build 분석·그룹 Character refresh/options와 그룹·모집 도메인 회귀가 통과했다. 영향 범위 analyze 문제 없음.
- 전체 `flutter test --no-pub` 875개가 통과했다.
- Android 실기기 체크리스트는 `NEXT_WORK.md`에 두었다. 일반/나이스단·서포터 겸용 4직업·빠른 실행·실패·서버 동기화·비용 관찰 보고를 기다린다.
- A fixture `measuredAgainstLiveApi: false`는 실기기 Armory 문자열 대조 전까지 유지한다.

## 2026-09-04 Character 자동 갱신 F — 서버 최소 Snapshot 정합성·비용 제어

- `CharacterMinimumDisplaySyncGateway`와 Service를 추가해 교류 갱신 후 Firestore Character의 `itemAvgLevel`·`combatPower`만 값이 달라졌을 때 갱신한다. null로는 기존 서버 값을 지우지 않는다.
- 캐릭터별 Transaction은 binding·Player·Character·소유관계 4회 읽기, 변경 시 1회 쓰기다. 동일값이면 쓰기를 생략한다. Rules·스키마·신규 서버 필드는 변경하지 않았다.
- `CharacterAutoRefreshCoordinator`의 명령 경로(`ensureFresh`)는 동기화 성공 후에만 진행하고 실패 시 blocked다. prefetch 실패는 로컬 갱신을 유지하되 TTL 캐시에 넣지 않아 이후 명령에서 재시도한다.
- 그룹 로컬 표시·생성·가입은 선호 역할 Snapshot을 서버 단일 `combatPower`보다 우선한다. 파티 명령의 선택 역할 Snapshot 사용은 유지한다.
- F 표적 테스트 28개와 변경 파일 analyze가 통과했다. 그룹·account 서비스 회귀 227개와 전체 `flutter test --no-pub` 875개가 통과했다. 다음은 G 회귀·실기기 검증이다.

## 2026-09-04 Character 자동 갱신 C — 공통 조정기

- `CharacterAutoRefreshCoordinator`를 추가해 후보 사전 갱신과 명령 직전 `ensureFresh`가 같은 Character ID single-flight를 공유하도록 했다.
- 성공 결과는 메모리에서 5분 미만 재사용하고 5분 경계부터 다시 조회한다. Armory 요청은 최대 3개이며 대기 중 명령 요청을 후보 사전 갱신보다 먼저 실행한다.
- 결과에 Character ID와 generation을 유지하고 선택 상태 일치 검사 API를 제공한다. 대기 중이거나 실행 중인 사전 갱신에 명령 요청이 합류하면 명령의 역할 문맥을 우선한다.
- 서포터 겸용 직업은 감지된 역할과 4티어 노드, 아크그리드 조건, 모든 보석 대상을 검증한 뒤 감지 역할 Snapshot만 저장한다. 일반 직업은 호출자가 전달한 기존 역할을 유지한다.
- 나이스단 제외 요청은 Armory API를 호출하지 않고 해당 역할의 수동 Snapshot만 사용한다. 갱신 실패·판별 실패 시 기존 정상 Snapshot이 있으면 마지막 저장 시각과 계속 확인 상태를 반환하고, 없으면 차단한다. 실패 결과는 캐시하지 않아 재시도할 수 있다.
- C 표적 테스트 7개와 변경 파일 analyze가 통과했다. 전체 회귀는 857개 통과했다. 파티·그룹 UI와 명령 연결, 서버 최소값 동기화는 변경하지 않았다.

## 2026-09-04 Character 자동 갱신 B — 나이스단 정책과 로컬 설정

- 등록된 본·부계정 전체를 합쳐 아이템 레벨 1700 이상 동일 직업 Character가 2명 이상이면 해당 직업군을 나이스단으로 판정하는 Domain 정책을 추가했다. 1699/1700 경계, 계정 합산, 직업 분리, 원정대 이탈 Character 제외를 테스트했다.
- 나이스단 자동 갱신 허용은 Character별이 아닌 Player별 단일 로컬 설정으로 저장한다. Drift schema 13의 `niceGroupAutoRefreshSettings` 테이블을 추가했으며 기본값은 false다.
- 조건이 사라질 때 설정 행을 삭제하지 않아 휴면 보존하고, 같은 Player가 다시 조건을 충족하면 기존 값을 복원한다. 로컬 DB 재시작 복원 테스트를 추가했다.
- 캐릭터 관리 화면은 나이스단이 감지된 경우에만 전체 직업군 단일 스위치를 표시한다. 설정은 기존 화면의 저장/취소 draft에 포함하며 Firestore에는 전송하지 않는다.
- B 표적 테스트 52개, 전체 `flutter test --no-pub` 850개가 통과했다. 변경 파일 `flutter analyze --no-pub`도 문제 없다.
- 자동 갱신 실행·TTL·single-flight·파티·그룹 연결은 변경하지 않았다. 다음 작업은 C 공통 자동 갱신 조정기다.

## 2026-09-04 Character 자동 갱신 A — 4직업 Build 카탈로그 기반

- 사용자 제공 계약값을 기준으로 바드·홀리나이트·발키리·도화가의 support/dealer 깨달음 1티어 역할과 4티어 교차 검증 노드를 Build 카탈로그에 고정했다.
- 네 직업의 `ArmorySkills` 비노출 아이덴티티·아크패시브 보석 대상과 바드 세레나데 복합 대상을 등록했다. 확인되지 않은 별칭은 추정해 추가하지 않았다.
- 4직업 8역할 최소 Armory fixture를 추가하고 `measuredAgainstLiveApi: false`로 사용자 제공 기준이며 실API 미실측임을 명시했다. 실제 반환 문자열·공백·별칭은 G 실기기 검증 전 최종 대조한다.
- 알려진 직업에서는 `ark_passive` 아이콘만으로 카탈로그 미등록 보석을 정상 판정하지 않도록 Mapper를 강화했다. 카탈로그가 없는 기존 호출의 아이콘 fallback은 유지한다.
- 카탈로그 Mapper/Validator와 Build 분석 표적 테스트 26개, 전체 `flutter test --no-pub` 843개가 통과했다. 변경 Dart 파일 `flutter analyze --no-pub`도 문제 없다.
- 기능 UI·로컬 DB·Firestore 스키마·Rules는 변경하지 않았다. 다음 작업은 B 나이스단 정책과 로컬 설정 모델이다.

## 2026-09-04 교류 행동 기반 Character 자동 갱신 작업 구간 설계

- 일반 Character는 그룹·파티 후보 화면에서 사전 갱신하고 명령 직전에 선택 Character의 최신화를 보장하며, 나이스단은 기존 수동 Snapshot을 유지하는 방향을 확정했다.
- 빠른 실행 경쟁 상태를 막기 위해 갱신 완료 후 명령 재생성, Character ID single-flight와 generation 보호를 계약으로 기록했다.
- 서포터 겸용 4직업은 깨달음 1티어로 역할을 판별해 해당 역할 Snapshot만 갱신한다. 현재 실제 Build 카탈로그는 바드만 지원하므로 홀리나이트·발키리·도화가와 아이덴티티·아크패시브 보석 대상 데이터 확보를 선행 단계로 뒀다.
- 기존 보석 전체 반환 슬롯 순회는 재사용하며 별도 슬롯 검사 체계를 만들지 않는다. 자동 갱신에서 역할·특수 보석 대상 판별 실패 시 기존 정상 Snapshot과 서버 표시값을 덮어쓰지 않는다.
- A 카탈로그 기반, B 나이스단 정책, C 공통 갱신 조정기, D 파티, E 그룹, F 서버 최소 Snapshot, G 회귀·실기기 검증으로 작업 구간을 분리했다.
- 후속 결정으로 나이스단은 등록된 본·부계정 전체의 1700 이상 동일 직업을 합산하고 해당 직업군 전체에 적용한다. 자동 갱신 허용은 나이스단 전체 단일 설정이며 로컬에만 저장한다.
- 도화가·홀리나이트·발키리의 support/dealer 1·4티어 및 아이덴티티 명칭을 사용자 기준으로 기록했다. 기존 공통 아크패시브–아크그리드 조건 교차 검증을 유지하고 4티어 일치를 핵심 검증 근거로 사용한다.
- API 실패 시 기존 정상 Snapshot 유무에 따라 차단/사용자 계속 선택을 나누고, 서버 단일 전투력은 참고값, 파티는 선택 역할, 그룹은 선호 역할 Snapshot을 우선하는 방향을 채택했다. 화면 이탈 시 후속 교류 명령은 실행하지 않는다.
- 기존 정상 Snapshot은 만료 기간 없이 유지하고 마지막 정상 저장 시각만 안내한다. 나이스단 조건이 사라져도 로컬 자동 갱신 허용 설정은 휴면 보존한다. 사전 갱신 TTL 5분과 최대 동시 Armory 요청 3개를 초기값으로 확정했다.
- A~F 각 단계에서 표적 테스트·analyze·필요한 전체 회귀와 문서 갱신을 마친 뒤 dev에 병합하고 다음 단계를 최신 dev에서 시작하도록 실행 규칙을 보강했다. 서버 신규 필드·Rules는 기본 범위에서 제외한다.
- 단일 기준 문서는 `../architecture/CHARACTER_INTERACTION_AUTO_REFRESH_CONTRACT.md`다. 문서만 변경했으며 기능 코드·Firestore 스키마·Rules·테스트는 변경하지 않았다.

## 2026-09-04 신청자 목록 가벼운 표시 구현

- `PartyApplicationSummary`에 `itemLevel?`·`combatPower?` 추가. Mapper `toApplication`에서 `submittedBuildSnapshot` 맵을 읽어 연결. 비정상 snapshot·누락은 null 처리.
- `ClassSynergyService` 신설(`shared/game_catalog/domain/services`). `alwaysPrimaryLabels()`로 항상채용 주요 시너지 레이블만 반환. 서포터 → 빈 목록, 선택채용 제외.
- `_PendingApplicationsSection`을 `_ApplicationCard`로 분리. 신청 카드에 아이템 레벨·전투력·주요 시너지 표시 추가.
- Mapper 테스트 3건 추가, `ClassSynergyService` 표적 테스트 8건 신규. 신규 파일 `flutter analyze --no-pub` 통과.
- Android 실기기 정상 확인. `dev` 병합·푸시 완료(머지 커밋 `a5c39ed`).

## 2026-09-03 신청자 표시 정책 결정 기록

- 사용자가 §11 결정 항목을 문서에 기록하고 커밋하도록 지시했다. 권장안을 1단계 표시 정책·2단계 목록 구현 승인으로 확정한다.
- 목록 우선, 신청 당시 Snapshot 수치·로컬 주요 시너지, 최신 세팅 별도 표시, 누락은 미확인, 선택 채용 미단정, 서포터 제외를 기록했다.
- 특성 요약·전체 상세 권한/재제출/스키마, 시너지 슬롯은 4단계 전 미결정으로 남긴다. 읽기 모델·UI·서버는 이번 커밋에서 바꾸지 않는다.
- 문서만 수정했다. `git diff --check`로 검증하고 Flutter 테스트는 반복하지 않는다.

## 2026-09-03 시너지 활용·신청자 상세 결정 기록 보강

- 사용자 요청으로 CLASS_SYNERGY_CATALOG §9~12에 확정/구현/권장/미결정 상태표를 추가했다. 이 문서를 단일 기준으로 유지한다.
- 목록 요약과 상세 지연 조회, 신청 당시/최신 세팅 분리, 신청 revision과 build 버전, 카탈로그 버전·역할·캐시·권한 경계를 기록했다.
- 현재 수치 두 개가 동일 Armory 캡처에서 온다는 보장은 없으며, 전체 스펙 서버 저장과 과거 카탈로그 재현은 미구현임을 명시했다.
- 단계별 활용 권장안, 사용자 승인 항목, 후속 성능/정합성 체크리스트를 남겼다. 전투력·아이템 레벨 UI와 서버 구조 변경은 계속 보류다.
- 문서만 보강했다. 기존 코드 테스트 831개 결과를 유지하고 Flutter 테스트는 반복하지 않는다.

## 2026-09-03 직업 시너지 카탈로그와 신청자 스펙 검토

- 사용자 제공 데이터로 30개 직업·13개 시너지·특성별 효과·8개 선택 채용 항목을 독립 Dart 카탈로그로 추가했다. 대륙/계열별 표시 순서와 차원술사 방깎 정정을 반영했다.
- 역할/특성 미확인과 서포터 제외, 공통 효과와 특성 추가 효과를 구분한다. 기존 바드 빌드 판별 JSON은 변경하지 않았다.
- 원본 표·변수 사전·사용법·신청자 스펙 표시 검토를 `../product/CLASS_SYNERGY_CATALOG.md` 한 문서에 정리했다.
- 신청 문서에는 submittedBuildSnapshot.itemLevel/combatPower가 이미 있으나 신청 읽기 모델/UI에는 전달되지 않는다. 상세 Armory 원문은 로컬 저장 경로이며 서버 Character는 요약 정보다.
- 로컬 시너지 표시와 최소 신청 요약, 탭 시 상세 지연 조회를 권장안으로 남겼다. 실제 성능 계측이나 1초 이내 보장은 하지 않았다.
- 전투력·아이템 레벨 UI는 상세 표시 정책 확정 후 진행할 요구사항으로만 기록했다. 신청자 UI·기존 런타임·서버 스키마·Rules·배포 변경 없음.
- 검증: 카탈로그 표적 21개, 최종 전체 `flutter test --no-pub` 831개 통과. 신규 코드/테스트 3개 파일의 `flutter analyze --no-pub` 문제 없음.
- 전체 analyze는 수정하지 않은 파일의 기존 19건(경고 1·info 18)으로 exit 1이다. 전체 분석 통과로 기록하지 않는다. `git diff --check` 통과.

## 2026-09-03 모집 탭 목록 필터 구현과 실기기 확인

- 모집 목록에 레이드 현황과 같은 필터 바·시트를 붙이고, Drift 저장 키를 `activeRaids` / `recruitmentList`로 나눴다. 기존 현황 선택은 마이그레이션으로 유지한다.
- 공개 첫 페이지·추가 페이지와 그룹 listing 병합은 원본으로 두고 로컬 필터를 적용한다. 빈 필터 결과는 기존 3페이지 자동 보충 후 명시적 더 불러오기다.
- 공개 요약에 확정 `memberPlayerIds`를 올린다. Character 조건이 있을 때만 membership을 조회하고, 확인 전·실패 방은 일치 목록에 넣지 않는다.
- `flutter analyze --no-pub`는 신규 오류 없음. `flutter test --no-pub` 819개 통과. 사용자가 Android 실기기에서 모집/현황 선택 독립과 목록 필터를 확인했다.
- Rules·인덱스는 변경하지 않았다.

## 2026-09-03 모집 탭 목록 필터 분석과 실행 계획

- 사용자가 대상은 레이드 모집 탭의 파티 목록이며 모집 만들기 입력 화면은 제외한다고 확정했다.
- 현황 필터의 공통 조건/UI를 재사용하되 Player·화면별 선택 저장을 분리하는 방향을 기록했다.
- 공개 모집 페이징과 가입 그룹 listing의 병합 구조, 참가 Player ID 전달, Character 확인 중/실패와 캐시 무효화, 빈 필터 결과의 제한된 추가 조회를 구현 경계로 정했다.
- NEXT_WORK를 공통 필터/저장 → 기본 목록/페이징 → 그룹원/Character → 검증의 다음 실행 계획으로 교체하고 상세 계약 §13을 추가했다.
- 직전 활동 Character 공개 경로·현황 필터 작업은 완료 상태로 유지한다. 이번 모집 필터는 아직 미구현이다.
- 앱 코드·Rules·인덱스 변경 없이 문서만 수정했다. 문서 검토와 `git diff --check`로 검증하고 Flutter 테스트는 실행하지 않는다.

## 2026-09-03 활동 Character 공개 경로와 필터 UX 실기기 확인

- 그룹원 목록은 Projection 컬렉션 없이 `characterActivity` 목록과 Character 표시 문서를 쓴다. 캐릭터 관리 저장과 다른 그룹원의 선택 Character만 보이기가 실기기에서 통과했다.
- 레이드 현황 필터는 초기화, `그룹 공개만`일 때만 그룹원 UI, 상단 드래그 닫기가 실기기에서 통과했다.

## 2026-09-02 활동 Character Rules 컴파일 오류

- 사용자가 `firebase deploy --only firestore:rules --project lost-party`에서 `removedMemberId` 16단 삼항의 닫는 괄호 불일치(174:28)와 파일 끝 `Unexpected '}'`로 컴파일이 실패했다.
- 멤버 제거 ID 조회를 0~7 / 8~15 두 함수로 나눠 중첩을 낮추고 괄호를 맞췄다. Rules 배포는 하지 않는다.

## 2026-09-02 활동 Character 저장 permission-denied 안내

- 실기기에서 캐릭터 관리 저장이 공통 문구 `캐릭터 설정을 서버에 반영하지 못했습니다`로 떨어졌다. 정책 거절이 아니라 Firestore `permission-denied`·연결 실패, 또는 로컬 표시 순서 저장 실패가 원인이다.
- Drift는 원정대 전체 Character ID의 표시 순서를 요구한다. 활동 선택만 넘기면 ArgumentError가 나므로 선택 순서를 앞에 두고 비선택 Character를 이어 붙인다.
- Repository가 Firebase 오류 코드를 매핑한다. 권한이 없으면 Rules 배포 확인을 안내하고, 연결 실패는 재시도를 안내한다.
- Rules는 대표 Character 필드가 없는 기존 `playerGameAccounts`에서도 소유 Character 쓰기를 막지 않도록 맞췄다. Rules 배포는 하지 않는다.

## 2026-09-02 활동 Character 자동 회귀 (E)

- 계약 최종 단계로 전체 `flutter test --no-pub` 792개를 실행해 통과했다. 변경 파일 `flutter analyze --no-pub`는 문제 없다.
- 앱 셸 테스트가 레이드 현황 초기 탭에서 Firebase에 닿아 실패하던 경로를 고쳤다. 활동 Character Repository와 Character 검색 Repository를 테스트에서 주입한다.
- Rules는 배포하지 않는다. 실기기 확인은 사용자 단계다.

## 2026-09-02 진행 중 그룹원·Character 필터 (D3)

- 레이드 현황 `진행 중` 필터에 가입 그룹·그룹원 대표명·Character 칩을 추가한다. 현재 Player는 후보에서 제외한다.
- 그룹원 선택은 사용자 사이 AND, 한 사용자의 Character는 OR다. Character 칩이 없으면 그 사용자의 참가만 요구한다. 이미 참가 중인 비활동 Character는 판정에서 인식하고 새 칩으로는 제시하지 않는다.
- 다른 그룹원의 `characterActivity`는 owner만 읽을 수 있어 Character 칩 후보는 그룹원이 이미 읽는 인증 활성 Character다. 칩 조작은 서버 조회를 만들지 않는다.
- 저장된 그룹 선택이 모두 무효이거나 JSON이 손상되면 전체 보기로 초기화한다. 다음 단위는 E 실기기·회귀 확인이다.

## 2026-09-02 진행 중 기본 필터와 페이징 안전 (D2)

- 레이드 현황 `진행 중` 탭과 목록 사이에 `레이드 필터: 모든 레이드`를 두고 공개 조건·레이드·난이도를 로컬 원본에 적용한다. 칩 조작은 서버 조회를 만들지 않는다.
- 기본 공개 조건은 전체·일반 공개·그룹 공개가 모두 선택된 상태다. 일반과 그룹을 모두 해제하려 하면 전체로 복귀한다. 그룹 공개는 `visibility`가 아니라 `groupId` 기준이다.
- 진행 중 원본은 기존 `watchActiveRaids` membership 스트림이다. 20개 cursor는 공개 모집 목록 계약으로 유지하고, §8 페이징 안전은 `FilteredPageSession` 단위 테스트로 고정했다.
- 필터 선택은 Player별 Drift 테이블에 보존하며 카탈로그에 없는 레이드·난이도는 복원 시 제거한다. 그룹원·Character 필터는 D3다.

## 2026-09-02 그룹 전용 레이드 자격 상실과 제한적 정리 (D1)

- 그룹 탈퇴는 레이드 membership을 자동 삭제하지 않는다. 그룹 전용 레이드에서만 참가 자격 상실로 표시한다.
- 같은 방의 유효 그룹원이 정리 요청을 보내면 Transaction이 요청자의 레이드·그룹 membership과 대상의 그룹 자격 상실을 다시 확인한 뒤 방에서 제외한다.
- 전체 공개 그룹 연결 레이드와 활동 Character 해제는 자격 상실이 아니다. 활성 그룹 전용 레이드가 있으면 그룹 해산은 거절한다.
- Rules는 배포하지 않는다. 다음 단위는 D2 진행 중 기본 필터·페이징이다.

## 2026-09-02 그룹 후보·전투력 보강을 활동 Character로 제한 (C2)

- 그룹 생성·가입 신청·초대코드 가입 후보는 `characterActivity`에 있는 Character만 사용한다.
- 그룹 상세 진입 시 전투력 서버 보강과 본인 인증 Character 목록도 활동 Character만 담는다. 다른 그룹원 목록은 소유 인증 Character를 그대로 읽는다.
- 비활동 Character의 기존 그룹 membership Snapshot은 활동 해제만으로 지우거나 null로 덮지 않는다.
- 다음 단위는 D1 그룹 전용 자격 박탈이다.

## 2026-09-02 레이드 후보를 활동 Character로 제한 (C1)

- 모집 생성 파티장 후보, 신청·참가 후보, 참가 Character 변경 후보는 `characterActivity`에 있는 Character만 사용한다. 메인 화면 표시 개수는 후보 범위를 줄이지 않는다.
- 비활동 Character는 새 후보에서 빠지고 기존 레이드 membership·Claim은 유지한다.
- 다음 단위는 C2 그룹 후보·전투력 적용이다.

## 2026-09-02 캐릭터 관리 UI 초안 저장 (B)

- 캐릭터 관리 화면을 전체 원정대 선택 카드 → 선택된 Character의 대표·순서 → 메인 표시 개수 → 취소·저장 순서로 바꿨다.
- 선택 변경은 로컬 초안에만 반영하고 `저장`에서 `ActivityCharactersRepository`와 로컬 표시 설정을 한 번 쓴다. 실패하면 로컬 영구 상태를 바꾸지 않는다.
- 대표 Character와 마지막 1명은 해제할 수 없고, 0명 저장 요청은 나가지 않는다. 기존 표시 여부 체크박스는 제거했다.
- 레이드·그룹 후보 소비 경로는 바꾸지 않았다. 다음 단위는 C1 레이드 후보 적용이다.

## 2026-09-02 활동 Character 저장 경계를 캐릭터별 문서로 재설계 (A)

- 저장 위치: `players/{playerId}/characterActivity/{characterId}`. 문서가 있으면 활동, 없으면 비활동이다. 가변 ID 목록 한 문서는 Rules가 순회·재귀할 수 없어 사용하지 않는다.
- Domain 명령 `SaveActivityCharactersCommand`, Policy, Firestore Repository를 추가했다. 최소 1명, 대표 Character 포함, active 소유권을 거절한다.
- 이 명령은 Character·playerGameAccounts 인증·소유권 필드를 쓰지 않는다. Rules는 각 쓰기에서 `characters/{characterId}`와 소유권 문서를 확인하고, 같은 계정 대표 활동 문서가 있어야 하며 대표 활동 문서는 삭제할 수 없다. 배포는 하지 않는다.
- 테스트 데이터는 활동 문서를 다시 저장하면 재설정된다. 기존 Character 문서는 삭제하지 않는다.
- 다음 단위는 B 캐릭터 관리 UI다.

## 2026-09-02 모집·현황 리스트 카드 밀도 완료

- 브랜치 `codex/raid-list-card-density`. 모집 리스트와 레이드 현황 진행 중 카드 우상단에 그룹 전용 `그룹` 배지를 추가했다.
- 제목·상태 배지는 유지하고, 난이도·레이드 줄 오른쪽에 파티장 이름만 두며, 인원과 전투력·숙련도 제한을 한 줄로 합쳤다. 목록에서 직업명과 시작 시간은 빼 카드 높이를 줄였다.
- 다음 작업은 그룹 탈퇴·추방·해산 시 그룹 전용 레이드 자격 박탈이다.

## 2026-09-01 raidListings 동기화 원칙 확정 — 문서화만 수행

- 사용자가 다음 작업의 권장안에 동의했다. 원본 모집과 listing은 동일 Firestore Transaction에서 원자적으로 동기화하고, 이번 단계에서는 현재 모집 Snapshot Projection 구조를 유지한다.
- 만석·완료 취소 가능 상태·반복 모집의 다음 주 대기처럼 재노출 가능한 상태는 listing을 삭제하지 않고 최신 인원·자리·회차·상태로 유지한다. 전체 공개 전환과 방 해산처럼 되돌릴 수 없는 종료는 삭제한다.
- 유효한 그룹 전용 모집에 listing이 없으면 해당 모집 변경 시 생성해 자연 복구한다. 변경되지 않은 과거 모집의 일괄 보완은 다음 작업으로 분리한다.
- 구현 전 즉시 가입·승인, 탈퇴·추방, 자리 변경, 완료·취소·회차 전환, 반복 여부, 해산, 카드 정보·공개 범위 변경 경로를 대조한다. Rules는 `getAfter()` 원본과 listing 핵심 필드 일치를 강제하도록 설계한다.
- 제품 문서, 쓰기·읽기 계약, NEXT_WORK와 AI_CONTEXT에 같은 기준을 기록했다. 이번 단계에서는 Dart 코드, Firestore Rules, 인덱스, 배포 설정을 수정하지 않았다.

## 2026-09-01 기존 그룹 listing 보완 착수

- 브랜치 `codex/raid-listings-backfill`. 모집 탭 시작 시 참가 중인 그룹 전용 방의 빠진 listing을 원본 Snapshot으로 만든다.
- listing 전용 create Rules를 열어 모집 revision은 올리지 않는다. 그룹 전용 `recruitments` 목록 쿼리는 쓰지 않는다.

## 2026-09-01 raidListings 원자 동기화 커밋 — 실기기 보류

- 브랜치 `codex/raid-listings-sync`. 그룹 전용 모집을 바꾸는 명령이 같은 Transaction에서 listing을 생성·덮어쓰기·삭제한다.
- 만석·회차 완료·다음 주 대기는 listing을 유지하고, 전체 공개 전환과 방 해산만 삭제한다. Rules는 `getAfter` 원본과 listing `diff` 일치를 강제한다.
- 사용자가 디바이스 미연결로 실기기 확인을 보류하고 커밋 후 기존 listing 보완으로 넘어가라고 지시했다. Rules 배포는 하지 않는다.

## 2026-09-01 listing 동기화 실기기 확인 및 생성 충돌 알림 수정

- listing 동기화·보완은 참가 충돌 알림 외 이상이 없다고 확인했다.
- 같은 레이드 조건으로 생성·해산·재생성할 때, 방은 만들어졌는데 이미 참가 중 알림이 간헐적으로 났다. 생성 Transaction 재시도와 해산 후 남은 점유를 성공/교체로 처리한다.

## 2026-09-01 생성 후 그룹 공개 범위 전환 완료
- 같은 Transaction에서 모집 visibility를 패치하고, 그룹 전용이면 listing을 만들거나 덮어쓰며 전체 공개면 listing을 삭제한다. 전체 공개→그룹 전용은 비그룹 멤버·pending 신청을 거절한다.
- 사용자가 Rules를 배포했다. 비그룹 계정 모집에서 숨김·표시·재숨김을 확인했다. 방장 본인 방은 모집 리스트에서 제외된다.
- 다음 작업은 listing 자리·상태 갱신이다. Git SHA는 로그로 확인한다.

## 2026-09-01 그룹장 이전·탈퇴·해산 완료 기록 및 다음 작업

- 실기기 확인: 1인 해산, 즉시 이전, 이전 후 기존 그룹장 탈퇴, 후임 그룹장 해산.
- 초대코드 원문 미표시·폐기 대화상자 오류 화면, listing 잔여로 인한 해산 오인을 수정했다.
- 다음 작업은 생성 후 `그룹만 공개 ↔ 전체 공개` 전환이다.

## 2026-09-01 그룹장 이전·탈퇴·해산 실기기 확인

- 1인 그룹 해산과 그룹장 즉시 이전이 동작했다.
- 가→나 이전 후 가가 탈퇴하고, 레이드방을 해산한 나가 그룹 해산까지 완료했다. listing 잔여 오인 수정 후 후임 그룹장 해산이 통과했다.

## 2026-09-01 그룹 해산이 해산된 레이드 listing 잔여를 활성으로 오인

- 가→나 이전 후 가가 탈퇴하고 나가 레이드방을 해산해도 그룹 해산이 `그룹만 공개 레이드`로 거절됐다. 레이드 현황은 비어 있었다.
- `raidListings`는 생성 스냅샷이고 Rules가 update/delete를 막아 방 해산 후에도 listing `status`가 `active`로 남는다. 해산 게이트가 listing만 보면 오인한다.
- 해산 차단은 listing을 후보로만 쓰고 `recruitments` 원본의 그룹 전용·active 여부를 확인한다. listing 자리·상태 동기화는 후속이다.

## 2026-09-01 그룹장 즉시 지정 이전·1차 해산 구현

- 브랜치 `codex/group-leader-exit`. 이전은 group leader와 두 membership 역할만 원자 교체하고, 탈퇴는 기존 일반 멤버 명령을 재사용한다.
- 1차 해산은 1인·pending 없음·활성 그룹 전용 레이드 없음·초대코드 없음일 때 soft delete한다. 초대코드가 있으면 먼저 폐기하도록 거절한다.
- 초대코드는 기간 만료가 없다. 원문은 그룹 문서에 없어 앱을 다시 열면 화면에 다시 보이지 않는다. 폐기 대화상자는 컨트롤러를 대화상자 수명에 맞춰 해제한다.
- 해산 Rules는 인원·상태·Projection을 강제하고, pending·레이드 존재는 Transaction 조회로 거절한다.

## 2026-09-01 그룹장 즉시 지정 이전·탈퇴·해산 계약 확정

- 그룹장 이전은 대상 수락을 기다리지 않고 현재 그룹장이 유효한 일반 그룹원을 선택해 즉시 지정하는 방식으로 확정했다.
- 이전 Transaction은 group leader와 두 membership 역할을 원자적으로 교체한다. 기존 그룹장은 일반 멤버로 남고 탈퇴는 기존 명령을 별도로 실행한다.
- 이전 요청 문서, 수락·거절·취소·만료 상태, 알림과 역방향 Projection은 만들지 않는다.
- 그룹 대표 Character는 유지하고 그룹장 표시 Snapshot만 후임자 값으로 바꾼다.
- 1차 해산은 마지막 1인·pending 초대/신청 없음·활성 그룹 전용 레이드 없음 조건에서 soft delete하며, 28일 보관·이력 3개월·연결 레이드 존재 시 물리 삭제 보류를 적용한다.
- 기술 계약: [`../architecture/GROUP_LEADER_EXIT_DISBAND_CONTRACT.md`](../architecture/GROUP_LEADER_EXIT_DISBAND_CONTRACT.md)

## 2026-09-01 그룹장 탈퇴와 후속 기능 순서 확정

- 다음 우선 작업은 그룹 생성자인 정상 그룹장이 다른 유효 그룹원에게 역할을 이전한 뒤 탈퇴하거나 그룹을 해산하는 시스템이다.
- 이 시점에는 이전 요청·수락 방식을 검토했으나, 바로 위 최신 결정에서 즉시 지정 이전으로 대체했다. 탈퇴·해산, revision·동시성과 연결된 그룹 레이드 처리 경계는 별도 Firestore/Rules 계약으로 확정했다.
- 이후 공개 범위 전환, `raidListings` 갱신, 기존 listing 보완, 그룹 전용 자격 박탈을 순서대로 완료한다.
- 레이드 모집·현황 그룹 필터는 위 기능 완료 후 개발한다. 기존 기획은 `GROUP_PRODUCT_FLOW.md` §8·§15에 있으며, 구현 직전 정의·적용 화면·포함/제외 범위·상태 보존·무효 선택 정리·완료 조건을 반드시 재확인한다. 검토와 문서 보완 전에는 필터 코드를 수정하지 않는다.

## 2026-09-01 그룹 전용 모집 리스트 실기기 확인

- 사용자가 그룹만 공개 생성 후 그룹원 레이드 모집 리스트 노출이 동작한다고 확인했다.
- 구현: 생성 시 `groups/{groupId}/raidListings/{recruitmentId}` 스냅샷, 공개 첫 페이지와 경로 기반 listing 합치기, listing 실패 격리, 본인 방 제외.
- 쓰지 않은 방식: `recruitments`에 `visibility==group` 쿼리, 목록 Rules의 문서별 그룹 membership `exists`.
- 남은 후속: 생성 후 공개 전환, listing 자리·상태 갱신, 기존 방 listing 보완, 탈퇴 자격 박탈, 목록 필터 UI.
- Git 종료: 기능 커밋 `61fd464`, `main` 병합 커밋 `25c3b44`. 로컬 `main`과 `origin/main`이 일치한다.

## 2026-08-31 그룹 전용 모집 목록(raidListings)

- 그룹만 공개는 공개 `recruitments` 쿼리에 없어 그룹원 모집 리스트에 안 보였다. `visibility==group`을 `recruitments`에 붙이면 목록 전체가 죽을 수 있어 쓰지 않는다.
- 생성 트랜잭션이 `groups/{groupId}/raidListings/{recruitmentId}`에 모집 스냅샷을 쓴다. 목록은 가입 그룹 경로만 읽고 공개 첫 페이지와 합친다. listing 오류는 공개 목록을 유지한다.
- listing create/list Rules와 앱 반영 후 2026-09-01 실기기에서 그룹원 모집 리스트 노출을 확인했다. listing이 없는 기존 방은 재생성 전까지 안 보일 수 있다.

## 2026-08-31 Rules 복잡도 축소 (R1·이벤트·미사용 함수)

- 사용자가 업로드 실패를 복잡도 한도로 보고 최적화를 지시했다. 브랜치 `codex/recruitment-group-link`에서 목록 수정을 유지한 채 축소했다.
- 가입 membership 네 경로의 필드·시각 검사를 `validNewGroupMemberCore`로 모았다. membership state 키 집합을 공통화하고 리더 승인 추가는 기존 add-member 검사를 재사용한다.
- `validPlayerEvent` 중첩 삼항을 유형별 검증 OR로 바꿨다. 호출되지 않는 joinCode path·수동인증 owner helper 2개를 삭제했다.
- 생성 시 그룹 exists/get은 `let`이 아니라 일반 레이드에서 단락되는 OR로 두었다. 청중 검사는 `isCurrentGroupMember` 대신 membership `exists`만 쓴다. 배포는 하지 않았다.

## 2026-08-31 모집 목록 Rules list 거부 수정

- Rules 배포 후 레이드 모집·현황이 `조회 권한을 확인하지 못했습니다`로 비었다. 생성은 되고 목록만 실패했다.
- `canReadRecruitment`에 그룹 membership `exists`가 들어가 공개 목록·내 현황 `list` 쿼리 전체가 거부되었다. 목록은 `canListRecruitment`(공개/리더/멤버 필드)로 분리했다. 재배포 전에는 운영 목록이 복구되지 않는다.

## 2026-08-31 일반/그룹 레이드 생성 연결 (B)

- 전용 브랜치 `codex/recruitment-group-link`. 생성 화면에 일반/그룹 선택을 넣고, 그룹 레이드는 가입 그룹 하나와 visibility를 실제 저장한다.
- 그룹 전용은 기본값이며 Rules에서 그룹원만 읽기·신청할 수 있다. 생성 트랜잭션은 그룹·membership을 먼저 읽는다.
- 가입 그룹이 없으면 생성을 막는다. 공개 목록에 그룹 전용 모집을 섞는 일, 생성 후 공개 전환, 탈퇴 시 자격 박탈, Rules 배포는 하지 않았다.
- 표적 테스트와 변경 파일 analyze를 통과했다. 커밋은 실기기 확인 뒤 사용자 지시로 진행한다.

## 2026-08-31 모집 생성 UI(A) 실기기 확인 및 Git 종료

- 사용자가 생성 UI·완료 표기 크기를 확인한 뒤 문서 최신화와 기능 커밋·푸시·main 머지 커밋·푸시를 지시했다. 레이드 모집 완료는 정상이다.
- A와 상세 완료 표기를 한 브랜치 `codex/recruitment-create-layout`에 포함한다. B는 다음 작업으로 남긴다. Rules·배포는 변경하지 않았다.
- 표적 테스트와 변경 파일 analyze 결과를 재사용한다. Git 완료 SHA는 실제 로그로 확인한다.

## 2026-08-31 모집 생성 간격·역할 높이 및 완료 표기

- 사용자 실기기: 레이드 모집 완료는 정상. 딜러/서포터 역할 드롭다운이 캐릭터 칸보다 낮고, 생성 폼 항목 간격이 답답했다.
- 역할 칸에 보이지 않는 플로팅 라벨 높이를 맞춰 캐릭터 선택과 같은 높이가 되게 했다. 항목 사이 세로 간격을 16에서 21로 늘렸다.
- 모집 상세 파티 구성 제목 옆에, 이번 회차 완료 후 해산 전 또는 반복방 다음주 대기일 때 `이번주 레이드완료`를 상단 모집 제목과 같은 크기·오류색으로 표시한다.

## 2026-08-31 모집 생성 UI 배치(A) 구현

- 사용자가 Rules 복잡도를 최신 상태에서 해결된 것으로 판단하고 구현을 지시했다. main 15eaf4a에서 `codex/recruitment-create-layout`을 생성했다.
- A만 구현했다. 모집 제목·자동 제목·승인 옵션은 유지하고 레이드/난이도, 최소 전투력/숙련도를 한 줄로 배치한다. 좁은 폭·큰 글꼴에서는 접는다.
- 생성 화면에서만 캐릭터와 작은 역할 드롭다운을 한 줄에 둔다. 눈에 보이는 역할 라벨은 제거하고 접근성 이름은 유지한다. 선택 가능한 역할이 둘일 때만 표시하며 유효한 선호 포지션을 선선택한다.
- 일반/그룹 선택과 groupId 저장(B), Rules·배포는 변경하지 않았다. 공용 폼의 한 줄 배치는 수정 화면에도 적용된다.
- 표적 테스트 18개 통과, 변경 파일 analyze에서 불필요 import 1건을 제거했다. 전체 테스트는 한정 UI 변경으로 실기기 전에 재실행하지 않는다. 커밋은 사용자 지시 후 진행한다.

## 2026-08-31 모집 생성 UI 다음 작업 준비 및 Git 최신화

- 사용자 요청으로 문서화만 수행하던 단계에서 준비 문서의 커밋·푸시 및 main 통합 단계로 전환했다. 단일 그룹 매칭과 기존 UI 요구를 유지하고 NEXT_WORK·AI_CONTEXT의 이전 커밋 제외 문구를 갱신했다.
- 원격 fetch 후 코드 기준 main/origin/main eeba05f 일치를 확인했다. 변경 범위는 제품·인계 문서 5개이며 기존 보존 브랜치와 Rules 사본은 유지한다.
- 다음 구현은 최신 main에서 codex/recruitment-create-layout을 생성하여 A(입력 배치·역할 선택)부터 시작한다. B(일반/그룹 선택·서버 연결)는 별도 작업으로 남긴다.
- 문서 내용 검토와 git diff --check로 검증한다. 앱 코드·의존성·Rules 변경이 없어 Flutter 테스트는 재실행하지 않는다. Git 완료 상태와 커밋 ID는 실제 로그 및 최종 보고로 확인한다.

## 2026-08-31 레이드 생성의 단일 그룹 매칭 확정

- 사용자가 그룹 가입·탈퇴가 쉬운 점을 고려해 한 레이드에 그룹 하나만 매칭하기로 최종 결정했다. 이전 다중 그룹 조건부 비용 검토는 종료했다.
- 생성 화면은 일반/그룹 선택 후 가입 그룹 하나를 드롭다운에서 선택한다. 단일 groupId를 유지하며 groupIds·다중 선택 체크박스·다대다 배정은 제외한다. 목록 필터의 복수 그룹 선택 기획은 별개로 유지한다.
- 기존 UI 배치 요청은 그대로 유지하고 제품 문서·NEXT_WORK·AI_CONTEXT를 일치시켰다. 문서만 수정했으며 코드·Rules·커밋·푸시는 변경하지 않았다.

## 2026-08-31 모집 생성 UI 우선 요청 기록

- 이전 그룹 전투력 수정은 4e4ab37, main 머지 eeba05f로 커밋·푸시 완료했고 사용자 실기기 정상 확인을 기록했다.
- 사용자가 모집 생성 UI를 다음 우선 작업으로 지정했다. 최상단 일반/그룹 선택 및 가입 그룹 드롭다운, 기존 제목 유지, 레이드/난이도·캐릭터/작은 역할·최소 전투력/숙련도 한 줄 배치, 역할 라벨/설명 제거와 유효 선호 포지션 선선택을 제품 문서와 NEXT_WORK에 반영한다.
- 다중 그룹은 비용 부담이 작으면 채택하는 조건부 요구다. 기존 단일 groupId와 public 고정 생성/목록 경로를 확인했으며 UI 선택 상태 비용과 서버 조회·권한·탈퇴 처리 비용을 분리해 검토하기로 했다. 계측 없이 비용이 작다고 확정하지 않는다.
- codex/recruitment-create-ui-plan에서 문서만 수정한다. 코드·Rules 변경, 테스트 실행, 배포·커밋·푸시는 하지 않는다. 문서 diff 및 git diff --check로 확인한다.

## 2026-08-31 그룹 전투력 표시 수정 — 실기기 확인 및 Git 종료 승인

- 기반 99a3598, codex/group-combat-power-display. 준비 이후 사용자 진행 지시로 구현했다. 사용자가 그룹원 간 전투력이 정상 표시됨을 확인하고 기능 커밋·푸시·main 머지 커밋·푸시를 승인했다.
- 로컬 프로필 전투력이 null인 경우 저장 세팅 전투력을 읽지 않는 경로를 회귀 테스트로 재현했다. active 소유 계정·서버 ID·원정대 미누락 캐릭터만 사용하며, 프로필 값이 없을 때 가장 최근 유효 저장 세팅을 읽도록 수정했다.
- 그룹 상세 인증 캐릭터 목록의 읽기 원본인 Character.combatPower를 전용 Gateway로 보강했다. 기존 최소 요약 동기화와 분리하고 추가 Lost Ark API 조회 없이 로컬 캐릭터별 값을 사용한다. active binding·Player·Character/계정 소유를 Transaction에서 확인하고 같은 값 쓰기는 생략한다.
- membership self-refresh의 null 덮어쓰기와 조용한 실패를 수정했다. 실패 안내와 저장 목록 조회를 분리하고 새로고침/상세 조회 연타를 막았다.
- 표적 테스트 21개 통과 후 active Player 검증 사례를 추가했다. 최종 전체 flutter test --no-pub 666개 통과. flutter analyze --no-pub 문제 없음. SDK sealed 타입은 테스트 더블 3곳만 사유를 적어 국소 예외 처리했다. 전체 테스트 이후 앱/테스트 동작 변경은 없으며 문서만 정리했다.
- Transaction Fake는 실제 Repository 콜백의 필드 쓰기·소유 확인·읽기 선행을 검사하며 운영 Rules/동시성을 검증한 것으로 간주하지 않는다.
- 이번 범위에서 발견한 그룹 코드의 불필요한 null 연산 분석 경고도 제거했다. Rules·인덱스·배포 설정·레이드 코드는 변경하지 않았다.
- 사용자 실기기 정상 보고로 BUG-009를 종료했다. 개별 장애 경로까지 실기기 검증했다고 주장하지 않는다. 코드 변화 없이 문서만 수정하므로 기존 전체 테스트 666개·analyze 결과를 재사용하고 git diff --check 및 병합 후 코드 일치·원격 SHA 일치를 확인한다.
- 기존 보존 브랜치 codex/rules-complexity-reduction(ed02b31)는 유지한다. main 통합에는 이 보존 계보의 Rules 정리 25f88ff와 사본도 포함되며, Git 병합은 운영 Rules 배포를 의미하지 않는다. Firebase 배포는 실행하지 않는다.

## 2026-08-31 그룹 전투력 수정 전 보존·작업 준비

- 사용자 최신 확인을 기준으로 레이드 모집·탈퇴·완료 체크, 그룹 생성·초대·탈퇴·초대코드 생성·가입, Rules 배포를 정상 상태로 정정했다. 과거 503 기록은 보존하되 현재 차단으로 취급하지 않는다.
- git status/diff/staged diff/stash 및 이력을 확인했다. 미커밋 앱 코드는 없었고 미추적 Rules 사본 2개만 있었다. 전투력 membership Snapshot·self-refresh는 3df755b에 포함되며 이후 75bedb9까지 lib 변경은 없다.
- 사본 2개의 SHA-256은 동일: 46F2B03DE4DA51FA57068CBC00429C4E15948EFCCBF335746B5FBE9ECB1A672C. 원본 파일명·내용을 유지해 ed02b31에 커밋하고 codex/rules-complexity-reduction을 origin에 푸시했다.
- 수정 준비 브랜치 codex/group-combat-power-display를 ed02b31에서 생성했다. main ea2019a는 수정·병합하지 않는다. 기능 코드·운영 Rules·Firebase 배포 설정 변경 없이 NEXT_WORK를 전투력 단일 작업으로 교체했다.
- 그룹원 목록과 상세 캐릭터 목록의 데이터 경로 불일치, self-refresh 오류 은폐를 조사 대상으로 기록했다. 실제 누락 원인은 아직 확정하지 않았다.
- 이번은 백업·문서 준비 작업이므로 Flutter analyze/test 및 실기기·배포는 실행하지 않는다. 문서 검토와 git diff --check, 최종 원격 커밋 일치 확인으로 검증한다.

## 📌 1. 프로젝트 초기 설계

- Flutter 기반 앱 생성
- Git 연결 완료
- docs 구조 생성 (MVP.md / DEV_LOG.md)

---

## 📌 2. 개발 방식 정의

- ChatGPT → 설계 / 구조 / 작업 분해
- Cursor → 코드 생성
- 작업은 반드시 단계별 진행

---

## 📌 3. 아키텍처 결정

- MVVM 패턴 적용
- feature-first 구조 채택
- repository pattern 도입
- local → remote(Firebase) 전환 가능 구조 설계

---

## 📌 4. 레이드 데이터 설계

### RaidBase
- 레이드 공통 정보
- gateCount / difficultyIds 포함

### RaidVariation
- 실제 모집글에서 사용하는 레이드 단위
- raidId 기준 참조

---

## 📌 5. 모집글 데이터 설계

### 핵심 구조
- raidId 기반 구조
- gateProgress (start / end)
- 역할별 모집 상태 (dealer / support)
- memberSummary

### 조건
- minCombatPower
- experienceLevel (5단계 고정)

### 숙련도
- tryLevel
- clearExp
- multiClearExp
- semiExperienced
- experienced

### 시간
- raidStartAt
- maxPlayHours (null = 클리어시)
- recruitmentOpenedAt
- recruitmentClosedAt

---

## 📌 6. 데이터 관리 방식 결정

- 레이드 데이터는 앱 내부 하드코딩
- repository를 통해 접근
- UI에서 직접 접근 금지
- 추후 Firebase로 교체 가능하게 설계

---

## 📌 7. 폴더 구조 설계 및 생성

- shared/raid_master
- features/recruitment_list

구조:

- domain (entities / repositories)
- data (datasources / repositories)
- presentation (viewmodels / pages / widgets)

---

## 📌 8. 구현 완료 상태

- raid_base.dart 생성 완료
- raid_variation.dart 생성 완료
- raid_master_repository.dart 생성 완료
- local_raid_data_source.dart 생성 완료
- raid_master_repository_impl.dart 생성 완료
- party_recruitment.dart 생성 완료

---

## 📌 9. 당시 작업 기준 상태
- 당시 기준으로 모집글 리스트 기능 구현 직전 상태였음
- 다음 작업 후보로 아래 항목들을 계획했음:
  - local_recruitment_list_data_source.dart 작성
  - mock 모집글 데이터 생성
  - recruitment_list repository 구현

---

## 📌 10. 모집글 리스트 데이터 레이어 구현

다음 파일 작성 완료:

- features/recruitment_list/domain/repositories/recruitment_list_repository.dart
- features/recruitment_list/data/datasources/local_recruitment_list_data_source.dart
- features/recruitment_list/data/repositories/recruitment_list_repository_impl.dart

### 구현 내용
- RecruitmentListRepository 인터페이스 정의
- LocalRecruitmentListDataSource 구현
- mock 모집글 데이터 6개 작성
- RecruitmentListRepositoryImpl 구현
- repository → data source 연결 완료

---

## 📌 11. 테스트 작성 및 실행 확인

다음 테스트 파일 작성 완료:

- test/local_recruitment_list_data_source_test.dart
- test/recruitment_list_repository_test.dart

### 테스트 내용
- LocalRecruitmentListDataSource fetchRecruitments() 결과 검증
- mock 데이터 개수 및 필드값 검증
- recruitment status / null maxPlayHours 케이스 검증
- RecruitmentListRepositoryImpl getRecruitments() 동작 검증
- repository 결과와 data source 결과 일치 여부 검증

### 확인 사항
- flutter analyze 이후 테스트 정상 인식 확인
- 개별 테스트 실행 통과
- 전체 테스트 실행 시 기존 기본 widget_test.dart 영향 여부 별도 확인 필요

## 📌 12. 레이드 데이터 로컬 작업
- 자료 입력
- 각 레이드 데이터가 실제 인게임 데이터와 동일하게 입력되었는지 확인 완료.

---

## Task-002. Recruitment List Presentation Layer 구현

### 완료 파일
- features/recruitment_list/presentation/viewmodels/recruitment_list_view_model.dart
- features/recruitment_list/presentation/pages/recruitment_list_page.dart
- features/recruitment_list/presentation/widgets/recruitment_card.dart
- lib/main.dart
- test/widget_test.dart

### 구현 내용
- RecruitmentListViewModel 구현 완료
  - MVVM 구조 유지
  - Repository를 통해 mock 모집글 데이터 조회
  - loading / error / recruitments 상태 관리
- RecruitmentListPage 구현 완료
  - ViewModel을 통해 데이터 조회
  - 모집글 목록 화면 구성
  - mock 모집글 6개 표시
- RecruitmentCard 구현 완료
  - 모집글 제목
  - 레이드 ID 및 관문 범위
  - 리더 정보
  - 현재 인원 / 최대 인원
  - 딜러 / 서포터 모집 상태
  - 최소 전투력 / 숙련도 / 플레이 시간 표시
- main.dart 연결 완료
  - 앱 시작 화면을 RecruitmentListPage로 변경
- widget_test 수정 완료
  - counter 테스트를 모집글 목록 표시 테스트로 변경

### 검증 결과
- flutter analyze 통과
- flutter test 통과
- 전체 테스트 12개 통과

---

## Task-003. 문서 최신화

### 수정 파일
- docs/AI_CONTEXT.md
- docs/DEV_LOG.md

### 반영 내용
- 현재 브랜치를 feature/recruitment-list-ui 기준으로 정리
- Recruitment List Presentation Layer 완료 상태 반영
- main.dart에서 RecruitmentListPage 실행 상태 반영
- widget_test가 모집글 목록 표시 테스트로 변경된 상태 반영
- flutter analyze 통과 상태 반영
- flutter test 12개 통과 상태 반영
- 다음 작업 후보를 현재 구현 이후 단계로 갱신

### 현재 기준
- 코드 변경 없음
- MVP.md 변경 없음
- ai_rules.md 변경 없음

---

## Task-004. Lost Ark API 로컬 저장 기반 준비

### 추가 의존성
- drift
- drift_flutter
- drift_dev (개발용 코드 생성)

### 사용 목적과 선택 이유
- 계정과 여러 캐릭터의 관계, 마지막 API 갱신 시각, 자동 갱신 설정을 SQLite에 구조화하여 저장
- 장비, 스킬, 각인, 카드, 보석 등 크고 변경 가능성이 있는 상세 API 응답은 JSON으로 함께 보존
- 타입 안전한 쿼리, 트랜잭션, 스키마 버전 및 마이그레이션을 지원하여 단순 JSON 파일보다 안정적인 로컬 데이터 관리 가능
- 기존 MVVM 및 Repository 구조 안에서 저장 구현을 교체하거나 테스트하기 쉬움

### 현재 범위
- 로컬 DB 사용을 위한 의존성만 추가
- DB 테이블, DAO, DataSource 및 Repository 연동은 아직 구현하지 않음
- 실제 저장 구조는 Lost Ark API DTO 범위가 확정된 뒤 구현 예정

---

## Task-005. 앱 셸 및 공통 내비게이션 기반

### 구현 내용
- StatefulShellRoute 기반 하단 탭 구조 적용
- 첫 번째 탭을 내 계정, 두 번째 탭을 파티 모집으로 구성
- PageView 스와이프와 하단 탭 선택 상태 동기화
- 탭별 Navigator 스택과 공통 뒤로가기 기반 구성
- 기존 RecruitmentListPage를 두 번째 탭에 유지

---

## Task-006. Lost Ark API 인증 및 통신 기반

### 인증
- 사용자가 앱에서 Lost Ark JWT를 직접 등록, 변경, 삭제할 수 있는 화면 구현
- flutter_secure_storage로 JWT 보관
- 저장된 JWT 원문을 입력창, 상태 화면 및 로그에 다시 노출하지 않음
- 토큰이 없으면 요청을 시작하지 않고 안내 다이얼로그 표시
- 안내를 닫은 뒤에도 앱의 다른 화면을 계속 탐색할 수 있도록 구성

### 공통 API 클라이언트
- Dio 기반 Lost Ark API 공통 클라이언트 구현
- API base URL과 connect/send/receive timeout 설정
- 요청 직전에 토큰을 읽어 Authorization 헤더 적용
- 401, 404, 429, 5xx, timeout, network, invalid response 오류 분류
- 진단 로그에는 HTTP method와 status만 남기고 URL, header, JWT 제외

### 원정대 캐릭터 조회
- `GET /characters/{characterName}/siblings` endpoint 연동
- DTO와 json_serializable 생성 코드 구성
- API DTO에서 Domain Entity로 변환하는 mapper 구현
- remote data source와 AccountRepository 구현체 연결
- 내 계정 ViewModel에서 조회, 로딩, 결과 및 오류 상태 관리
- 내 계정 화면에서 대표 캐릭터명 입력 후 원정대 캐릭터 목록 표시

### 플랫폼 설정
- Android 인터넷 권한 및 secure storage를 위한 최소 SDK/백업 설정 반영
- iOS Keychain 사용을 위한 entitlements 연결
- flutter_secure_storage 플러그인 등록 파일 반영

### 검증
- Galaxy Z Fold6(SM_F956N) 실기기 빌드 및 설치 성공
- 사용자가 앱에 JWT를 직접 입력한 뒤 저장 동작 확인
- 실제 캐릭터명 검색과 Lost Ark API 응답 표시 확인
- 저장소 민감정보 검사 결과 실제 JWT 없음
- flutter analyze: issue 0개
- flutter test: 전체 46개 통과

### 현재 범위
- siblings 응답은 화면에 표시하지만 Drift 로컬 DB에는 아직 저장하지 않음
- 추가 캐릭터 상세 endpoint 및 계정 상세 화면은 다음 작업 범위

---

## Task-007. 캐릭터 역할별 세팅 저장 설계

### 설계 원칙
- 캐릭터 기본 정보와 역할별 상세 세팅을 분리하여 저장
- 동일 캐릭터를 역할별로 중복 생성하지 않음
- 하나의 캐릭터에 `dealer` 또는 `support` 역할별 스냅샷을 연결
- 직업과 역할을 분리하며 최종 역할은 사용자가 스냅샷 저장 시 선택
- 각인 등 상세 데이터 분석은 역할 추천이나 경고에만 사용
- 자동 분석 결과보다 사용자의 명시적 선택을 우선

### 직업 분류
- 서포터형 직업: 바드, 발키리, 도화가, 홀리나이트
- 서포터형 직업은 `support`와 `dealer` 스냅샷을 각각 저장 가능
- 위 4개 직업을 제외한 모든 직업은 딜러군으로 분류
- 딜러군 직업은 `dealer` 스냅샷만 저장
- 서포터형 직업 목록은 변경 가능성을 고려하여 한 곳에서 관리

### 캐릭터 기본 정보
`Character`

- 캐릭터명
- 서버명
- 직업
- 전투 레벨
- 아이템 레벨
- 기본 정보 마지막 갱신 시각

### 역할별 세팅 스냅샷
`CharacterBuildSnapshot`

- 대상 캐릭터 ID
- 역할: `dealer` 또는 `support`
- 장비
- 각인
- 보석
- 카드
- 전투 특성
- 역할 판정 및 파티 지원에 필요한 상세 정보
- 스냅샷 저장 시각

검색과 비교에 필요한 값은 구조화된 컬럼으로 저장하고, 상세 API 원본 응답은 JSON으로 함께 보존하는 방식을 검토한다.

### 데이터 갱신 흐름
1. 사용자가 게임에서 저장하려는 세팅을 적용한다.
2. 앱에서 해당 캐릭터의 데이터 갱신을 실행한다.
3. 서포터형 직업은 `서포터 세팅` 또는 `딜러 세팅`을 선택한다.
4. 딜러군 직업은 별도 역할 선택 없이 딜러 세팅으로 갱신한다.
5. 앱이 현재 캐릭터 상세 데이터를 API로 조회한다.
6. 선택된 역할의 스냅샷을 신규 저장하거나 최신 데이터로 교체한다.
7. 다른 역할도 저장하려면 게임 내 세팅을 변경한 뒤 다시 갱신한다.
8. API 호출 간격은 고정된 10초 값이 아닌 설정 또는 서버 응답 기준으로 관리한다.
9. `429 Too Many Requests` 응답을 별도로 처리한다.

### 파티 지원 연계
`PartyApplication`

- 모집글 ID
- 캐릭터 ID
- 역할별 스냅샷 ID
- 지원 역할

동작 원칙:

- `dealer` 스냅샷이 있으면 딜러 모집에 지원 가능
- `support` 스냅샷이 있으면 서포터 모집에 지원 가능
- 두 스냅샷이 있는 서포터형 캐릭터는 양쪽 모집에 선택적으로 지원 가능
- 해당 역할의 스냅샷이 없으면 먼저 해당 세팅 저장을 안내

### 구현 전 확정 항목
- 역할별 스냅샷에 포함할 Lost Ark API endpoint와 필드
- 구조화 컬럼과 원본 JSON의 저장 범위
- 스냅샷 유효기간과 갱신 필요 표시 기준
- 파티 지원 당시 스냅샷을 고정할지 최신 스냅샷을 참조할지
- API 호출 간격과 `429` 재시도 정책

### 현재 범위
- 설계 내용만 확정 및 문서화
- Drift table, DAO, local data source는 아직 구현하지 않음
- 파티 지원 기능은 아직 구현하지 않음

### 조회 캐릭터와 대표 캐릭터 구분
- API 조회를 시작할 때 입력한 캐릭터는 `조회 캐릭터`로 정의
- Lost Ark API 응답에서 공식 대표 캐릭터를 얻었다고 간주하지 않음
- 앱의 `대표 캐릭터`는 로컬 계정 그룹 안에서 사용자가 직접 선택
- 최초 등록 시 조회 캐릭터를 대표 캐릭터 기본값으로 사용할 수 있음
- 대표 캐릭터는 같은 계정 그룹 내에서 횟수 및 시간 제한 없이 변경 가능
- 대표 캐릭터 변경은 API 호출 없이 로컬 `representativeCharacterId`만 갱신
- 실제 선택 UI와 Drift 저장은 계정 로컬 저장 구현 단계에서 추가

---

## Task-008. 조회 캐릭터 프로필 및 계정 DB 기반

### 상세 프로필
- `GET /armories/characters/{characterName}`의 `ArmoryProfile` 연동
- 캐릭터명, 서버, 직업, 전투 레벨, 아이템 레벨, 전투력 DTO 구성
- 쉼표가 포함된 아이템 레벨과 전투력을 숫자 Domain 값으로 변환
- API 입력 캐릭터를 `대표 캐릭터`가 아닌 `조회 캐릭터`로 화면에 표시
- Galaxy Z Fold6 실제 API 호출에서 전투력 표시 확인

### Drift 스키마 버전 1
- `game_accounts` 테이블 추가
- `account_characters` 테이블 추가
- 메인/부계정 구분과 조회 캐릭터명 저장
- 로컬 대표 캐릭터 ID 저장
- 계정당 기본 표시 개수 6개 저장
- 캐릭터 표시 여부와 표시 순서 컬럼 준비
- 계정 삭제 시 소속 캐릭터 cascade 삭제
- 동일 계정의 서버명과 캐릭터명 조합 중복 방지

### 로컬 정책
- 대표 캐릭터는 같은 계정 소속 캐릭터만 지정 가능
- 대표 캐릭터 변경에는 API 호출이나 쿨타임 없음
- 표시 개수는 1개 이상으로 변경 가능
- 역할별 상세 스냅샷 테이블은 상세 필드 확정 후 추가

### 검증
- 상세 프로필 remote data source 및 mapper 테스트 추가
- Drift 인메모리 DB 테스트 4개 추가
- flutter analyze: issue 0개
- flutter test: 전체 55개 통과

### 다음 연결 범위
- siblings 결과를 `game_accounts`, `account_characters`에 트랜잭션 저장 완료
- 최초 조회 캐릭터를 대표 캐릭터 기본값으로 설정 완료
- 재조회 시 사용자가 변경한 대표 캐릭터 선택 유지
- Repository의 원격 조회 성공 결과를 LocalDataSource로 전달하도록 연결
- 앱 생명주기에서 AccountDatabase 생성 및 종료 관리
- widget 테스트는 인메모리 DB를 주입하여 파일 DB 중복 사용 방지
- 저장된 계정 데이터를 앱 시작 시 메인 화면에 표시 완료
- 기본 최대 6개 캐릭터를 화면 폭에 따라 2~4열 그리드로 표시
- 6명 미만 계정은 실제 저장된 캐릭터 수만 표시
- 사용자 설정 전 아이템 레벨 내림차순으로 상위 6개 표시
- 사용자 표시 순서가 저장되면 해당 순서를 우선 적용
- 조회 캐릭터의 상세 전투력을 로컬 캐릭터 데이터에 저장
- siblings 재조회 시 기존 전투력, 표시 여부 및 표시 순서 보존
- 대표 캐릭터 카드에 별표 표시
- 최상단 토큰 상태 및 설정 영역 구성
- 대표 캐릭터 변경 및 표시 캐릭터 관리 UI 구현
- 부계정 추가 흐름 구현

---

## Task-009. 계정 캐릭터 관리

### 구현
- 메인 계정 헤더에서 캐릭터 관리 화면으로 이동하는 route 추가
- 계정에 저장된 전체 캐릭터의 표시 여부 변경
- 메인 화면 표시 개수를 1명부터 계정 캐릭터 수까지 조절
- 로컬 대표 캐릭터를 제한 없이 변경하고, 숨김 캐릭터를 대표로 선택하면 자동 표시
- 대표 캐릭터는 메인 화면과 관리 화면에서 항상 첫 번째로 표시
- 대표 캐릭터를 숨기면 계정 내 다른 캐릭터 중 아이템 레벨이 가장 높은 캐릭터가 대표를 승계
- 승계 대상이 숨김 상태라면 자동으로 표시하며, 대체 캐릭터가 없으면 기존 대표를 숨기지 않음
- 드래그로 캐릭터 표시 순서를 변경하고 Drift에 즉시 저장
- 관리 화면에서 돌아오면 메인 계정 그리드를 다시 로드
- 모든 관리 작업은 로컬 DB만 사용하며 Lost Ark API를 호출하지 않음

### 검증
- Drift 가시성 및 표시 순서 저장 테스트 추가
- CharacterManagementViewModel의 대표 캐릭터, 표시 개수, 재정렬 테스트 추가
- Galaxy Z Fold6에서 표시 개수, 숨김, 대표 변경, 재정렬 및 재실행 후 설정 유지 확인
- profile 빌드에서 캐릭터 목록 스크롤 버벅임이 사라진 것을 확인
- AppBar와 본문 배경을 같은 surface 색상으로 통일해 스크롤 시 색상 변화를 제거
- flutter analyze: issue 0개
- flutter test: 전체 67개 통과

### 다음 범위
- 캐릭터 카드 상세 화면 route 구현
- 부계정 추가 흐름 구현

---

## Task-010. 캐릭터 상세 응답 fixture 및 세팅 검증 기반

### 데이터 분석
- 실제 종합 상세 API 응답을 수집한 뒤 개인정보성 프로필 필드를 목 값으로 치환
- 익명화된 전체 응답 fixture를 `test/fixtures/lost_ark`에 저장
- JWT, Authorization header 및 원본 응답 파일은 저장하지 않음
- 보석 11개, 스킬, 룬, 아크패시브 및 아크그리드 구조 확인

### 검증 기반
- 보석 슬롯과 효과 스킬을 `GemSlot`으로 연결
- 피해 증가, 재사용 대기시간 감소 및 지원 효과 문장 보존
- 일반 스킬과 아크패시브/아이덴티티 스킬을 구분
- 스킬 레벨만으로 장착 여부를 판정하지 않음
- 룬이 8개가 아니면 확인 경고 생성
- 아크그리드 발동 조건과 활성 아크패시브 비교
- 질서의 해/달 14P 필수 효과 및 유물 이상 17P 효과 활성 여부 확인
- 질서의 별과 혼돈 코어는 포인트 상태만 제공하고 필수 경고에서는 제외
- 모든 경고는 안내 목적이며 파티 지원 제한과 연결하지 않음

### 검증
- fixture 기반 mapper 테스트 7개 추가
- flutter analyze: issue 0개
- flutter test: 전체 78개 통과

### 역할별 스냅샷 저장
- Drift 스키마 버전 2 적용
- `character_build_snapshots` 테이블 추가
- 캐릭터당 `dealer`, `support` 스냅샷을 각각 하나씩 저장
- 같은 역할 재저장 시 해당 역할만 최신 데이터로 교체
- 반대 역할 스냅샷은 유지
- 전체 API 원본 JSON, 아이템 레벨, 전투력, 저장 시각 및 데이터 버전 저장
- 경고 결과는 규칙 변경을 반영할 수 있도록 원본 JSON에서 다시 계산
- siblings 재조회 시 기존 캐릭터를 update해 ID와 역할별 스냅샷 유지
- 계정에서 사라진 캐릭터만 삭제하고 연결 스냅샷도 cascade 삭제
- 실제 전체 fixture를 딜러 스냅샷으로 저장하고 원문 그대로 복원하는 테스트 추가

---

## Task-011. 캐릭터 상세 화면 및 역할별 세팅 갱신

### 구현
- 캐릭터 카드에서 상세 화면으로 이동하는 route 연결
- 캐릭터 상세 화면에 프로필, 역할 선택, 저장 상태, 경고, 보석 및 아크그리드 결과 표시
- 바드, 발키리, 도화가, 홀리나이트는 딜러/서포터 저장 위치를 선택
- 그 외 직업은 딜러 역할을 기본값으로 사용
- `세팅 저장`/`세팅 갱신` 시 실제 `GET /armories/characters/{characterName}` 호출
- 수신한 전체 JSON을 선택 역할 스냅샷으로 저장하고 분석 결과를 다시 로드
- 같은 역할은 덮어쓰고 반대 역할 스냅샷은 유지
- 누락 토큰, 인증, 호출 제한, 네트워크 및 응답 오류 안내

### 실기기 검증
- Galaxy Z Fold6 profile 빌드 설치
- 실제 API 통신으로 딜러/서포터 데이터를 각각 저장하고 독립 유지되는 것을 확인
- 테스트 fixture는 자동 테스트에서만 사용하며 앱의 상세 갱신에는 사용하지 않음

### 검증
- 전체 armory fixture가 Repository와 Drift를 거쳐 역할 스냅샷으로 저장되는 테스트 추가
- 서포터 역할 선택 및 딜러 기본 역할 ViewModel 테스트 추가
- flutter analyze: issue 0개
- flutter test: 전체 81개 통과

### 확인된 API 특성
- 바드의 `용맹의 세레나데`, `구원의 세레나데`는 `ArmorySkills`의 독립 항목으로 제공되지 않음
- 두 이름은 능력치, 아크패시브 및 아크그리드 Tooltip 설명에만 등장
- 아이덴티티/아크패시브 스킬은 직업별 게임 기준정보로 보완 필요
- 아크그리드 발동 조건은 깨달음 1티어 계열뿐 아니라 4티어 노드 등 추가 조건을 포함할 수 있음

### 다음 작업 후보
1. 직업별 정적 게임 기준정보 JSON 스키마 확정
2. 깨달음 1티어 노드, 인게임 통칭, 역할 및 아이덴티티 스킬 기록
3. 주요 아크그리드 조합과 조건 데이터 기록
4. 정적 기준정보와 분리된 사용자 메모/선호 조합 로컬 DB 설계
5. API 응답을 먼저 분석한 뒤 저장 위치를 선택하는 미리보기 화면 구현
6. 감지 역할과 사용자 선택 역할이 다를 때 안내하되 저장은 제한하지 않음
7. 내 캐릭터와 파티 지원자가 공유하는 캐릭터 요약 카드 재구성
8. 좁은 화면 1열, 펼친 Fold6 2열을 기준으로 가용 폭 기반 반응형 배치 적용

---

## Task-010. 직업별 기준정보 확장 구현 기준 정리

### 확인한 저장소 상태
- 실제 현재 브랜치는 `main`
- 작업 시작 시 `main`과 `origin/main`이 일치하며 작업 트리는 깨끗함
- 기존 문서의 `feature/account-character-dashboard` 현재 브랜치 표기를 실제 상태에 맞게 수정

### 확정한 용어와 데이터 경계
- 직업, 깨달음 1티어 계열, 인게임 통칭, 역할 및 주요 아크그리드 조합을 서로 다른 개념으로 정의
- 직업별 게임 기준정보는 Git으로 버전 관리하는 정적 JSON 카탈로그로 관리
- 캐릭터 개인 메모는 캐릭터 공통 사용자 데이터로 저장
- 선호 조합은 캐릭터별 사용자 선택값으로 저장하고 정적 조합 정의 및 역할별 스냅샷과 분리
- 감지 역할은 안내용 분석 결과이며 사용자가 선택한 저장 역할을 우선
- 역할 불일치는 미리보기에서 안내하되 특수 세팅 저장을 제한하지 않음
- 세팅 갱신 결과는 사용자 승인 전까지 메모리에 유지하고 기존 스냅샷을 변경하지 않음

### 작업 분리 결정
- 이번 작업은 구현 전 문서 기준과 데이터 경계를 확정하는 단위
- 직업별 노드, 통칭, 아이덴티티/아크패시브 스킬 및 아크그리드 조합의 수기 입력은 아직 시작하지 않음
- 다음 작업에서 정적 카탈로그 Domain 모델과 검증 가능한 JSON 구조를 먼저 구현
- 카탈로그 구조 확정 후 한 직업의 최소 데이터를 입력해 분석 흐름을 검증하고 전체 직업 입력으로 확대

### 검증
- 문서만 변경하여 관련 Flutter 테스트 대상 없음
- 코드, 생성 파일 및 Drift 스키마 변경 없음
- 커밋 및 푸시하지 않음

---

## Task-011. 정적 게임 카탈로그 Domain 모델 및 검증

### 구현 내용
- `shared/game_catalog` 공통 영역에 정적 게임 카탈로그 Domain 모델 추가
- 직업, 지원 역할, 깨달음 1티어 계열, 아이덴티티/아크패시브 스킬, 주요 아크그리드 조합 및 코어 요구사항 구조 정의
- 카탈로그 스키마 버전과 데이터 버전을 분리
- account/recruitment feature에 의존하지 않는 카탈로그 전용 역할 타입 정의
- 중복 ID/API 직업명, 빈 필수값, 미지원 역할, 잘못된 계열 참조 및 코어 포인트 범위를 수집형 검증 결과로 반환

### 범위 제외
- 실제 직업별 노드, 통칭, 스킬 및 조합 데이터 입력
- JSON DTO, asset 등록, DataSource 및 Repository 연결
- 기존 역할 타입 통합 및 분석기 연결

### 검증
- 정적 카탈로그 검증 단위 테스트 5개 통과
- 전체 `flutter analyze`와 `flutter test`는 커밋 직전 한 번 실행 예정
- 커밋 및 푸시하지 않음

### Git 작업 절차 보완
- 모든 작업은 작업 단위별 브랜치에서 진행하도록 협업 지침에 명시
- 작업 시작 전 현재 브랜치와 작업 트리 확인을 필수화
- `main` 또는 기본 브랜치에서 직접 수정하지 않고 먼저 작업 브랜치를 생성
- Codex 작업 브랜치는 기본적으로 `codex/` 접두사를 사용

---

## Task-012. 바드 최소 JSON 카탈로그 및 asset 로딩

### 구현 내용
- 카탈로그 JSON asset 등록
- 엄격한 JSON mapper와 asset DataSource 구현
- Domain 검증을 통과한 카탈로그만 반환하는 Repository 구현
- API fixture에서 바드의 `CharacterClassName`이 한글 `바드`임을 확인
- 영문 `BARD`는 직업 별칭으로 기록
- `완벽한 화음` 서포터 계열과 `진실된 용맹` 딜러 계열 입력
- `용맹의 세레나데`, `구원의 세레나데`를 두 계열 공통 아이덴티티 스킬로 입력
- 세부 아크그리드 조합 목록은 비워 두어 1차 범위에서 제외

### 후속 기능으로 기록한 내용
- 직업별 전체 해/달/별 코어 기준정보
- 3코어 조합 통칭과 인게임 UI 숫자 순서 별칭
- 사용자 지정 선호 조합과 조합별 평가 메모
- 파티 지원자의 실제 장착 코어와 사용자 선호 조합 일치 표시

### 검증
- 실제 번들 JSON asset 로딩 포함 카탈로그 관련 테스트 8개 통과
- 전체 `flutter analyze` 통과
- 전체 `flutter test` 89개 통과

### 다음 채팅 인계
- 현재 브랜치: `codex/game-catalog-foundation`
- 다음 작업은 병합된 `main`에서 새 작업 브랜치를 먼저 생성
- 게임 카탈로그를 기존 캐릭터 세팅 분석기에 연결하고 바드 fixture로 계열 및 역할 감지를 검증
- 분석 연결 단계에서는 카탈로그 역할과 기존 스냅샷 역할을 명시적으로 변환
- 저장 전 미리보기, 사용자 메모 DB, 다른 직업 수기 입력 및 세부 아크그리드 조합은 후속 작업으로 유지

---

## Task-013. 작업 그룹 인계 문서 도입 및 main 최신화

### Git 최신화
- 원격 상태를 확인한 뒤 `codex/game-catalog-foundation`을 로컬 `main`에 fast-forward
- 게임 카탈로그 기반 커밋 `3b52088`을 다음 작업의 코드 기준으로 확정
- 문서 추가와 상태 최신화를 포함한 마지막 커밋을 원격 `main`에 푸시하는 절차로 진행

### 문서 운영 방식
- 새 작업 그룹의 실행 명세를 관리하는 `docs/NEXT_WORK.md` 추가
- `NEXT_WORK.md`는 누적 로그가 아니라 작업 그룹 종료 시 다음 작업 내용으로 교체
- 완료 이력은 `DEV_LOG.md`, 프로젝트 전체 현재 상태는 `AI_CONTEXT.md`에서 계속 관리
- 새 채팅에서는 `NEXT_WORK.md`, `AI_CONTEXT.md`, `ai_rules.md`, Git 상태 및 관련 코드를 순서대로 대조
- 문서와 실제 저장소 상태가 다르면 실제 상태를 기준으로 문서를 먼저 갱신

### 다음 작업 그룹
- 게임 카탈로그와 기존 캐릭터 세팅 분석기 연결
- 바드 fixture의 `진실된 용맹`과 `템페스트 필드`로 `딜바드` 및 `dealer` 감지 검증
- 저장 전 미리보기, 사용자 메모 DB, 다른 직업 데이터 및 카드 개편은 제외

### 검증
- `flutter analyze` 통과
- `flutter test` 89개 통과
- 애플리케이션 코드 변경 없음

---

## Task-014. 반복 작업 그룹 및 테스트 최소화 규칙 문서화

### 작업 사이클
- 새 채팅마다 문서와 Git 상태를 먼저 확인하고 코드 수정 전 작업 단위를 제시
- 승인된 첫 번째 작업 단위만 별도 브랜치에서 구현
- 구현 중에는 변경 영역과 직접 관련된 테스트만 실행
- 설계 결정, 실기기 확인 또는 외부 승인이 필요한 시점에만 중간 보고 후 대기
- 최종 커밋 직전에 전체 `flutter analyze`와 `flutter test`를 각각 한 번 실행
- 완료 문서와 다음 채팅용 `NEXT_WORK.md` 최신화를 같은 최종 커밋과 푸시에 포함

### 테스트 최소화
- 전체 테스트의 진행 중 반복 실행을 금지하고 관련 테스트 중심으로 회귀 확인
- 실기기 검증 대기 전후 코드가 같으면 전체 검증을 중복 실행하지 않음
- 순수 문서 변경은 `git diff --check`와 문서 검토를 기본 검증으로 사용

### 변경 범위
- 협업 및 인계 문서만 변경
- 애플리케이션 코드, 테스트 코드 및 의존성 변경 없음

---

## Task-015. 게임 카탈로그 기반 캐릭터 계열 및 역할 감지

### Domain 및 분석
- 카탈로그 감지 결과와 감지 상태 Domain 모델 추가
- 감지 성공, 미지원 직업, 계열 미감지 및 복수 계열 감지를 구분
- 카탈로그 버전, 직업/계열 ID, 표시 이름, 감지 역할 및 일치 노드를 결과로 제공
- `GameCatalogRole`에서 `CharacterBuildRole`로 명시적으로 변환
- 역할 enum을 독립 Domain 파일로 분리하고 기존 snapshot import 호환 유지

### 바드 연결
- 전체 armory fixture의 `진실된 용맹`으로 `딜바드`와 dealer 역할 감지
- `템페스트 필드`를 관련 패시브 근거로 기록
- `완벽한 화음`으로 `바드`와 support 역할 감지
- 감지 역할은 사용자 선택 스냅샷 역할을 변경하지 않음

### 저장 및 앱 연결
- `LocalAccountDataSource`에 `GameCatalogRepository` 주입
- 번들 카탈로그를 한 번 로드해 저장된 armory 원본 JSON 분석에 사용
- 별도 Drift 마이그레이션 없이 기존 스냅샷도 현재 카탈로그 결과를 재생성
- 앱 라우터 조립부에 asset 카탈로그 Repository 연결

### 검증
- 감지 성공, support 계열, 미지원 직업, 미감지, 모호함 및 기존 호출 호환 테스트 추가
- Repository 저장 역할 유지와 카탈로그 분석 결과 로딩 검증
- `flutter analyze` 통과
- `flutter test` 94개 통과
- UI 변경이 없어 별도 실기기 검증 불필요

## Task-016. 캐릭터 세팅 Draft/Commit 저장 경계

### Domain 및 Repository
- API 조회 결과를 저장 전 상태로 표현하는 `CharacterBuildDraft` 추가
- draft에 대상 캐릭터 ID, 원본 JSON, 프로필, 카탈로그 분석 결과 및 조회 시각 포함
- `createCharacterBuildDraft`는 원격 조회와 분석만 수행하고 로컬 DB를 변경하지 않음
- `commitCharacterBuildDraft`는 draft와 사용자 선택 역할을 받아 저장된 스냅샷을 반환
- 감지 역할과 선택 역할이 달라도 선택 역할로 commit 허용
- 기존 상세 화면 호출부는 draft 생성 직후 commit하는 호환 메서드로 유지

### 저장 안전성
- 선택 역할 스냅샷과 최신 캐릭터 프로필을 Drift 단일 트랜잭션으로 저장
- draft의 캐릭터명과 로컬 캐릭터가 일치하는지 commit 시 검증
- 선택하지 않은 반대 역할 스냅샷 유지
- 저장된 스냅샷 로딩 시 현재 번들 카탈로그로 재분석하는 기존 동작 유지

### 범위 제외
- 저장 전 미리보기 UI 및 ViewModel 상태 변경
- 역할 불일치 안내 화면
- draft 장기 보관, 사용자 메모, 카드 변경 및 다른 직업 데이터 입력

### 검증
- draft 생성 후 스냅샷과 프로필이 변경되지 않는 Repository 테스트 추가
- 원본 JSON, 프로필, 분석 결과 및 조회 시각 포함 검증
- 역할 불일치 commit, 선택 역할 저장, 반대 역할 보존 및 프로필 갱신 검증
- 관련 Repository 및 DB 테스트 15개 통과
- `flutter analyze` 통과
- `flutter test` 95개 통과
- UI 변경이 없어 별도 실기기 검증 불필요

---

## Task-017. 작업 그룹 main 최신화 규칙 추가

### 작업 종료 기준
- 기능 브랜치의 구현, 검증, 문서화, 커밋 및 푸시 이후 `main` 병합 단계를 추가
- 검증 성공한 기능 브랜치만 `main`에 병합
- 병합 결과를 원격 `main`에 푸시하고 로컬/원격 최종 커밋 일치 확인
- 충돌 해결이나 병합 과정에서 코드가 변경되면 영향 검증을 다시 실행
- 병합으로 코드가 바뀌지 않으면 기능 브랜치의 최종 검증 결과 재사용

### 검증
- 애플리케이션 코드와 의존성 변경 없음
- `git diff --check`와 문서 내용 검토로 확인

---

## Task-018. 캐릭터 세팅 저장 미리보기 UI

### ViewModel
- 세팅 조회와 저장 진행 상태를 분리하고 현재 draft와 저장 역할을 메모리에서 관리
- API 조회 성공 후에도 기존 스냅샷을 유지하고 사용자 승인 시에만 commit
- 취소 시 draft 폐기, commit 실패 시 draft 유지 및 재시도 가능
- 지원 직업의 dealer/support 선택과 일반 직업의 dealer 제한 유지
- 중복 draft 조회와 중복 commit 방지

### UI
- 캐릭터 상세 화면에 스크롤 가능한 세팅 저장 미리보기 다이얼로그 연결
- 프로필, 조회 시각, 계열 통칭, 감지 역할, 룬 및 분석 경고 표시
- 지원 직업 저장 역할 선택 제공
- 감지 역할과 선택 역할 불일치 또는 자동 감지 실패 안내
- 불일치 상태에서도 특수 세팅 저장 허용
- 취소 시 무저장, 승인 성공 후 저장 스냅샷 화면 갱신

### 검증
- ViewModel의 조회, 취소, 역할 선택 commit, 실패 유지 및 중복 방지 테스트 추가
- Widget의 좁은 화면 스크롤, 분석 표시, 불일치 안내, 취소 및 승인 테스트 추가
- 관련 ViewModel 및 Widget 테스트 9개 통과
- `flutter analyze` 통과
- `flutter test` 102개 통과

### Galaxy Z Fold6 실기기 검증
- profile 빌드 설치 및 실행 완료
- 기존 역할별 저장 세팅 표시 정상
- 세팅 갱신 후 즉시 저장되지 않고 미리보기 팝업 표시
- 프로필, 계열, 감지 역할, 룬 및 경고 표시 정상
- 접힌 화면과 펼친 화면에서 미리보기 배치와 스크롤 정상
- 역할 불일치 안내와 불일치 상태 저장 정상
- 취소 시 기존 데이터 유지, 승인 시 선택 역할만 갱신, 반대 역할 유지 확인
- 캐릭터 컬렉션 카드 크기는 이번 범위에서 변경하지 않아 기존 크기 유지

### 실기기에서 확인한 후속 문제
- 서포터 바드의 세레나데 보석은 용맹과 구원의 세레나데를 함께 강화하는 정상 필수 보석이지만 단순 스킬명 일치로는 미확인 경고가 발생할 수 있음
- 직업 또는 보석명을 분석 코드에 직접 하드코딩하지 않음
- 카탈로그에 보석 대상 별칭 또는 복합 효과 그룹과 관련 특수 스킬 ID를 데이터로 정의하는 후속 작업으로 처리

---

## Task-019. 카탈로그 기반 보석 대상 분류

### 카탈로그 구조
- 직업별 API 보석 대상 표시명과 관련 특수 스킬 ID를 연결하는 `gemSkillTargets` 추가
- 복합 대상 ID, 표시명, 별칭 및 하나 이상의 특수 스킬 참조 지원
- 빈 관련 스킬 목록과 같은 직업에 없는 특수 스킬 참조 검증
- 번들 카탈로그 스키마 버전 2 적용
- 바드 `세레나데 스킬`을 용맹/구원의 세레나데 복합 대상으로 등록

### 분석
- 실제 장착 스킬은 계속 `normal`로 분류
- 현재 직업의 특수 스킬 이름/별칭과 복합 보석 대상 이름/별칭을 `passiveOrIdentity` 근거로 사용
- API 아크패시브 아이콘 근거 유지
- 어느 근거에도 없는 대상만 `unknown` 경고 생성
- 직업별 문자열 조건문 없이 공통 분석기로 처리

### 검증
- 단일 특수 스킬, 바드 복합 세레나데 대상 및 실제 미확인 대상 테스트 추가
- 카탈로그 참조 무결성과 번들 데이터 로딩 테스트 추가
- 관련 카탈로그, 분석기 및 Repository 테스트 27개 통과
- `flutter analyze` 통과
- `flutter test` 106개 통과

### Galaxy Z Fold6 실기기 검증
- 실제 서포터 바드 세팅의 `세레나데 스킬` 보석 재조회
- 기존 미확인 대상 경고가 사라진 것을 확인
- 보석 목록에서 아이덴티티/아크패시브 대상으로 정상 표시 확인
- 발키리 서포터의 `신앙 스킬`도 같은 유형의 직업별 카탈로그 입력 대상으로 기록

---

## Task-020. 서버 기반 파티 모집 및 계정 그룹 아키텍처

### 제품 방향
- 내 계정 캐릭터 표시 기반 이후 실제 레이드 카탈로그와 멀티유저 파티 구성으로 개발 방향 전환
- Lost Ark API에 없는 레이드 정보를 Git 버전 관리 JSON으로 수기 입력
- 레이드 카탈로그와 모집/승인 Domain을 Firebase 연결보다 먼저 확정

### 백엔드
- Firebase Authentication, Firestore, Callable Functions 2nd gen, Transaction 및 App Check 조합 채택
- 실시간 목록/상태는 Firestore, 상태 변경 명령은 Callable Function으로 분리
- 가입 승인, 투표, 정원 및 역할별 자리는 서버 트랜잭션에서 최종 판정
- 클라이언트 제출 캐릭터 정보는 최종 신뢰하지 않고 서버 검증 스냅샷 경계 필요

### 계정 그룹
- 사용자 ID 검색, 소유자 초대 및 상대방 수락 방식
- 그룹 멤버 수 제품 제한 없음
- 무제한 확장을 위해 멤버를 그룹 문서 배열이 아닌 하위 컬렉션으로 저장
- 모집글 공개 범위에 `public`과 `groupOnly` 추가
- 그룹 전용 모집글은 목록, 상세 및 신청 시점 모두 현재 그룹 멤버십 검증
- 초기 가정은 사용자당 소유 그룹 최대 1개와 다른 그룹 다중 가입 허용이며 구현 전 변경 가능

### 문서
- `BACKEND_PARTY_ARCHITECTURE.md` 신규 작성
- 기존 MVP의 그룹 제외 규칙을 최소 계정 그룹 기능 포함으로 변경
- 애플리케이션 코드와 의존성 변경 없음

---

## Task-021. 로컬 우선 파티 모집 구현 순서 명문화

### 배경
- Firebase 연결 전에 목데이터로 모집 목록, 생성, 신청, 승인/투표, 파티 구성 및 계정 그룹 흐름을 확인할 필요가 있음
- 기존 구현 순서는 로컬 Fake Repository 이후 Firebase가 바로 이어져 로컬 UI 검증 범위가 명확하지 않았음

### 변경 내용
- 실제 레이드 데이터와 모집/승인 상태 머신 이후 Fake 다중 사용자 환경을 구성하도록 순서 명시
- 모집 목록·상세·생성, 신청, 승인·투표·파티 구성 UI를 Firebase 전에 구현하고 검증
- 계정 그룹 초대/수락과 그룹 전용 모집도 Domain·Fake·UI 및 로컬 통합 테스트를 먼저 완료
- Firebase Auth, Firestore, Callable Functions, Security Rules 및 App Check는 로컬 흐름 검증 이후 진행
- 현재 다음 작업인 레이드 정적 카탈로그 기반 구현 범위는 유지

### 검증
- 문서만 변경하며 애플리케이션 코드와 의존성은 변경하지 않음

---

## Task-022. 레이드 정적 카탈로그 기반 구현

### 구현
- `shared/raid_catalog`에 레이드 카탈로그 Domain, JSON Mapper, asset DataSource 및 Repository 추가
- 카탈로그 버전/갱신 시각과 레이드·난이도 기준정보 모델 정의
- 모집글 경계를 위한 카탈로그 버전, 레이드 ID, 난이도 ID 및 선택 관문 참조 모델 추가
- Git 버전 관리용 최소 샘플 JSON asset 추가
- 기존 `raid_master` 정적 목록과 모집 UI는 실제 데이터 전환 전까지 유지

### 검증
- 중복 ID, 필수값, 정원/관문/표시 순서/레벨/보상 범위 검증
- 카탈로그 버전 불일치, 비활성 레이드/난이도, 다른 레이드 난이도 및 관문 범위 검증
- 신규 카탈로그 테스트 9개 통과
- `flutter analyze` 통과
- `flutter test` 115개 통과
- UI와 런타임 연결 변경이 없어 실기기 검증 생략

### 다음 작업
- 신뢰 가능한 기준으로 실제 레이드 데이터를 확인하고 카탈로그에 입력
- 실제 데이터 입력 후 기존 `raid_master`와 목 모집글을 새 카탈로그 참조로 전환

---

## Task-023. 실제 레이드 데이터와 파티 편성 기준 입력

### 카탈로그
- 사용자 인게임 확인 기준 5개 레이드와 13개 난이도 입력
- 정식 이름, 상위 필터명, 레이드 별칭과 난이도 표시 별칭 추가
- 일반 골드와 캐릭터 귀속 골드를 별도 필드로 분리
- 4인/8인 구성에 맞춰 파티 수, 필수 서포터 수와 동일 딜러 직업 최대 수 정의

### 연결
- 기존 Dart 정적 레이드 목록 제거
- 기존 `RaidMasterRepository`를 검증된 JSON 카탈로그 호환 Adapter로 전환
- 6개 목 모집글을 카탈로그 버전·레이드 ID·난이도 ID 참조로 변경
- 모집 카드에 `레이드 - 난이도 (별칭)` 표시 추가

### 파티 규칙 경계
- 동일 딜러 직업 제한은 4인 파티 단위로 적용
- 딜러와 서포터가 같은 직업인 경우는 허용
- 실제 가입 판정과 8인 레이드의 양 파티 배치는 후속 모집 상태 머신에서 구현

### 검증
- 카탈로그/목 모집/호환 Repository/카드 표시 대상 테스트 21개 통과
- `flutter analyze` 통과
- `flutter test` 116개 통과
- Galaxy Z Fold6에서 5개 레이드의 `레이드 - 난이도 (별칭)` 표시 확인
- 4인 모집의 딜러 3/서포터 1, 8인 모집의 딜러 6/서포터 2 목표 표시 확인

---

## Task-024. 파티 모집 카드 한글 표기 정리

- 화면 제목, 모집 상태, 리더, 멤버, 딜러 및 서포터 표기를 한글화
- 숙련도 5단계를 `트라이 / 클경 / 다클경 / 반숙 / 숙련`으로 표시
- 시간 제한이 없을 때 기존 문서 의미에 따라 `클리어 시까지`로 표시
- 시간 제한이 있으면 `최대 시간 N시간`으로 표시
- `flutter analyze` 통과, `flutter test` 117개 통과
- Galaxy Z Fold6에서 한글 제목·상태·역할·숙련도·시간 표기와 줄바꿈 확인

---

## Task-025. 앱 공통 숫자 천 단위 표기

- 공용 `DisplayNumberFormatter` 추가
- 아이템 레벨과 전투력의 소수점 두 자리 형식을 유지하면서 천 단위 쉼표 적용
- 모집 카드의 최소 전투력에 천 단위 쉼표 적용
- 인원, 관문, 시간처럼 작은 정수도 같은 정수 포맷 규칙 사용 가능
- `flutter analyze` 통과, 대상 테스트 8개 및 전체 `flutter test` 119개 통과
- Galaxy Z Fold6에서 계정 아이템 레벨·전투력과 모집 최소 전투력의 쉼표 표기 및 카드 레이아웃 확인

---

## Task-026. 모집 조건·파티 배치·가입 승인 정책 Domain

- 레이드 카탈로그의 전체 정원, 파티 수, 서포터 수와 동일 딜러 직업 한도를 파티별 모집 규칙으로 변환
- 4인/8인 레이드의 역할별 자리와 파티별 배치를 탐색하는 순수 Domain 정책 추가
- 동일 파티의 동일 직업 딜러 중복은 거절하고 딜러·서포터 교차 역할은 허용
- 8인 레이드는 동일 직업 딜러 2명을 서로 다른 파티에 배치하고 3명째는 거절
- 파티장 전용, 파티원 1명, 정족수 승인 정책을 상태 머신에서 사용할 값 객체로 정의
- 대상 테스트 13개와 전체 `flutter test` 132개 통과, `flutter analyze` 통과
- UI와 런타임 연결 변경이 없는 순수 Domain 작업이므로 실기기 검증 생략

---

## Task-027. 신청·투표·가입 상태 머신

- 신청의 `pending / approved / rejected / withdrawn` 상태와 투표 Domain 모델 추가
- 모집 중 신청, 사용자별 중복 신청, 현재 파티원 및 역할별 자리 검증 구현
- 파티장 전용, 파티원 1명 및 정족수 정책별 투표 권한과 승인 조건 구현
- 중복 투표를 차단하고 현재 파티원에게서 나온 유효한 표만 정족수에 포함
- 승인 직전 최신 파티 구성을 재검증하고 신청 승인·멤버 추가·역할별 인원·모집 마감을 단일 결과로 변경
- 정원 경쟁으로 가입이 불가능하면 새 투표도 반영하지 않는 원자적 실패 처리
- 거절 및 신청자 본인의 철회와 완료 신청 재처리 차단 구현
- 상태 머신 대상 테스트 13개와 전체 `flutter test` 145개 통과
- UI와 런타임 연결 변경이 없는 순수 Domain 작업이므로 실기기 검증 생략

---

## Task-028. 로컬 다중 사용자 모집 환경

- 현재 사용자를 전환할 수 있는 `FakeUserSession` 추가
- 고정·이동 가능한 Fake Clock과 순차 Fake ID 생성기로 테스트 재현성 확보
- 상태 Aggregate, 공개 모집 요약 읽기 모델 및 별도 Repository 계약 추가
- revision 비교 후에만 저장하는 메모리 Fake Repository 구현
- 모집 생성·신청·철회·투표 명령을 상태 머신과 현재 사용자 세션에 연결
- 성공한 명령만 revision과 갱신 시각을 변경하고 Domain 실패는 저장 상태를 보존
- A 모집 생성 → C 가입 → B 신청 → C 승인 시나리오와 저장 충돌 검증
- 신규 대상 테스트 8개와 전체 `flutter test` 153개 통과
- UI와 런타임 연결 변경이 없는 로컬 기반 작업이므로 실기기 검증 생략

---

## Task-029. 로컬 모집 목록·상세·생성 UI

- 기존 카드 목데이터 목록을 공유 메모리 Aggregate의 공개 모집 읽기 모델로 전환
- 빈 목록 안내와 모집 만들기 진입 버튼 추가
- 대표 캐릭터를 파티장으로 사용하는 모집 생성 화면 구현
- 레이드·난이도, 파티장 역할, 최소 전투력, 숙련도, 최대 시간과 세 승인 정책 입력 지원
- 모집 Aggregate에 카탈로그 참조와 화면 표시용 모집 조건 Metadata 추가
- 모집 상세에서 레이드·조건·승인 방식과 4인/8인 파티별 현재 구성 표시
- 저장소 변경 알림을 구독해 생성과 후속 상태 변경을 목록에 즉시 반영
- 좁은 화면 입력 검증·생성·상세 Widget 테스트와 전체 `flutter test` 154개 통과
- `flutter analyze` 통과
- Galaxy Z Fold6에서 빈 목록, 전체 생성 폼, 상세 1/2파티 구성과 목록 복귀 자동 갱신 확인

---

## Task-030. `내 파티` 화면 및 Firebase 이전 작업 순서 문서화

- 하단 탐색을 `내 계정 / 파티 모집 / 내 파티`로 확장하는 제품 방향 확정
- `내 파티`에서 `참여 중 / 내가 만든 파티 / 신청 중` 상태를 구분하도록 화면 기준 명시
- pending 신청은 실제 파티 가입과 분리하고 상태 확인 및 철회 대상으로 정의
- 신청 UI → 승인·투표 UI → `내 파티` → 그룹 UI → 로컬 통합 검증 → Firebase 순서로 갱신
- `내 파티`는 별도 상태 복제가 아니라 Aggregate의 소유권·멤버십·신청 상태를 조합한 읽기 모델로 정의
- Firebase 연결은 위 로컬 화면과 실기기 흐름을 모두 검증한 뒤 새 작업 탭에서 시작

---

## Task-031. 주간 레이드 완료와 승인 후 캐릭터 교체 규칙 문서화

- KST 매주 수요일 오전 6시를 레이드 주차 경계로 정의
- 캐릭터가 한 난이도를 완료하면 같은 주차의 동일 `raidId` 전체 난이도에 귀속되도록 확정
- 승인된 파티원 누구나 완료를 선언할 수 있고 최초 한 번으로 당시 파티원 캐릭터 전체를 완료 처리
- 완료 선언은 초기 버전에서 추가 동의·투표·개별 확인 없이 즉시 확정
- 파티원은 완료 전까지 승인 역할과 파티 자리를 유지하며 조건을 만족하는 자기 캐릭터로 추가 승인 없이 교체 가능
- 캐릭터 교체 시 소유권, 역할 세팅, 입장 레벨, 주간 귀속, 선택 모집 조건과 동일 딜러 직업 제한을 원자적으로 재검증
- 최소 전투력·클리어 경험·최대 진행 시간은 미입력 시 제한 없음으로 정의
- 주간 귀속 → 신청 → 승인 UI → 캐릭터 교체 → 완료 선언 → `내 파티` → 그룹 → Firebase 순으로 작업 계획 갱신

---

## Task-032. 주간 레이드 귀속과 로컬 신청·철회 UI

- KST 매주 수요일 오전 6시 기준 주차 계산 정책과 경계 테스트 추가
- 캐릭터·레이드·주차 단위의 난이도 공유 귀속 Repository/Fake 구현
- 신청 명령에서 같은 주차 동일 레이드 완료 캐릭터를 저장 변경 없이 차단
- 모집 Metadata에 카탈로그 입장 레벨을 보존하고 최소 전투력·클리어 경험을 nullable 선택 조건으로 변경
- 저장된 역할별 세팅을 기준으로 입장 레벨, 전투력, 주간 귀속, 역할 자리와 동일 딜러 직업 조건을 후보별 판정
- 모집 상세에 지원 후보 Bottom Sheet, pending 상태 및 본인 신청 철회 UI 구현
- 검증 가능한 계정 데이터가 없는 클리어 경험은 조건을 표시하고 신청자 직접 확인 대상으로 안내
- 로컬 타 사용자 4막 노말 목 모집을 초기 목록에 추가해 앱에서 신청 흐름에 진입 가능하도록 구성
- `flutter analyze` 통과, 전체 `flutter test` 161개 통과
- Galaxy Z Fold6에서 목 모집, 제한 없음 표기, 저장 역할 후보, 신청 대기, 철회와 지원 버튼 복귀 확인

---

## Task-033. 신규 모집 가입 정책 단순화

- 신규 모집 가입 방식을 `파티장 승인 / 승인 없이 바로 가입` 두 가지로 확정
- 생성 화면에서 파티원 승인과 정족수 승인 및 정족수 입력 UI 숨김
- 즉시 가입 정책은 신청 조건과 파티 구성을 검증한 뒤 pending 없이 승인 상태와 파티원 배치를 함께 반영
- 파티원 승인과 정족수 정책은 기존 Domain 및 저장 데이터 호환을 위해 내부에 유지
- 다음 작업의 선행 정족수 정책 결정을 제거하고 파티장 승인·거절 UI로 범위 축소
- `flutter analyze` 통과, 전체 `flutter test` 163개 통과
- Galaxy Z Fold6에서 두 가입 방식만 노출, 즉시 가입 선택 및 정족수 입력 미표시 확인

---

## Task-034. 모집 생성 파티장 캐릭터 및 역할 선택

- 본계정·부계정 전체 표시 캐릭터에서 모집 파티장을 선택하고 저장된 역할을 생성 명령에 반영
- 후보별 아이템 레벨, 역할 전투력, 참가 상태와 차단 사유를 표시하고 동일 레이드 pending은 확인 후 종료
- dealer/support 복수 역할 캐릭터의 선호 포지션 저장 및 한 행 역할 전환 UI 구현
- 파티 내 캐릭터 변경에서 동일 캐릭터의 반대 역할로 직접 변경 가능하도록 수정
- 모집 삭제 시 확정 점유 해제, 종료된 신청 뒤 다른 캐릭터 재신청 흐름 보완
- 일정 확인 기능은 기획 확정 전까지 Domain을 유지하고 앱 UI와 런타임 차단에서 숨김
- 세부 후속 개선 항목을 `DETAIL_IMPROVEMENTS.md`에 분리 기록
- 관련 실기기 테스트 통과
- `flutter analyze` 통과, 전체 `flutter test` 201개 통과
# Task-Account-Management. 본계정·부계정 등록 및 관리

- 작업 브랜치: `codex/account-management`
- 기존 Drift 다계정 스키마를 유지하면서 부계정 스냅샷 추가 저장 흐름 구현
- 계정 캐릭터 중복을 기준으로 동일 게임 계정 재등록 방지
- 본계정 승격 시 기존 본계정을 부계정으로 원자 전환하여 본계정 유일성 보장
- 내 계정 화면에 전체 계정 목록, 본계정/부계정 표시, 추가·표시명 수정·본계정 전환 UI 추가
- 각 계정에서 기존 대표 캐릭터 및 표시 캐릭터 관리 화면으로 이동하도록 라우팅 확장
- 데이터 계층의 계정 생성·중복·본계정 전환 규칙 테스트 추가
- `flutter analyze` 통과, 전체 `flutter test` 209개 통과
- 실제 API와 화면 크기별 실기기 검증은 `NEXT_WORK.md` 체크리스트로 이관
- 부계정 등록 다이얼로그의 입력 컨트롤러를 다이얼로그 State가 소유하도록 수정해 닫힘 애니메이션 중 조기 dispose로 발생하던 Flutter 위젯 트리 assertion을 해결
- 부계정 등록부터 다이얼로그 종료 및 목록 갱신까지 재현하는 위젯 회귀 테스트 추가
- 사용자 실기기 체크리스트 전체 통과
- 부계정 삭제 버튼과 확인 다이얼로그 추가; 저장 세팅, 캐릭터, 계정 순서의 명시적 연쇄 삭제 구현
- 빈 계정 표시명은 사용 가능한 `부계정N`으로 자동 지정하고 사용자 지정 표시명 중복은 거부

---

## Task-035. 아이템 레벨 기반 레이드 선택 및 모집 수정 기반

- 저장 세팅 아이템 레벨과 활성 카탈로그를 기준으로 입장 가능한 레이드·난이도를 계산하는 공용 정책 추가
- 입장 가능한 난이도를 `displayOrder`로 정렬하고 최고 난이도를 기본 선택하도록 모집 생성 화면 연결
- 파티장 캐릭터 또는 저장 역할 변경 시 레이드·난이도 선택지와 후보 유효성을 즉시 재검증
- 모집 상세에 파티장 전용 레이드·난이도 수정, 변경 영향 확인 및 낙관적 revision 저장 명령 추가
- 모집 생성·신청·캐릭터 변경 시 참가자의 아이템 레벨 스냅샷을 보존하고 수정 후 입장 레벨 미달 참가자에 경고 표시
- 레이드 변경 시 로컬 확정 참가 점유도 새 레이드·난이도로 교체하고 실패 시 기존 점유로 복구
- 파티장과 확정 파티원에게 수동 알림 버튼, 확인 알럿 및 전송 중 중복 방지 상태 추가
- 실제 FCM 서버 미연결 상태에서는 전송 성공으로 표시하지 않고 Firebase 연결 후 사용 가능함을 안내
- 공용 정책, 모집 수정 및 수동 알림 위젯 회귀 테스트 추가
- `flutter analyze` 및 전체 `flutter test` 통과
- 사용자 1인 로컬 실기기에서 레이드 자동 선택, 모집 수정, 입장 불가능 표시 및 수동 알림 버튼 흐름을 확인했으며 눈에 띄는 이상 없음
- 실제 다중 사용자 동기화와 FCM 전달은 Firebase 연결 이후 별도 검증

---

## Task-036. 전투력 표시와 자동 모집 제목

- 모집 생성, 지원 및 파티 내 캐릭터 변경 후보의 아이템 레벨·전투력 표시 모델 통일
- 큰 숫자의 소수점을 버리고 천 단위 쉼표를 적용하는 공용 포매터 연결
- 최소 전투력 빈 값과 `0`을 제한 없음으로 정규화
- 난이도 별칭, 숙련도와 최소 전투력을 조합한 자동 모집 제목 구현
- 수동 제목 보존과 빈 제목 저장 시 자동 제목 적용 규칙 구현
- 관련 자동 테스트와 정적 분석 통과 후 `main` 병합 및 원격 푸시 완료

---

## Task-037. 전체 모집 수정과 공통 텍스트 입력 UX

- 모집 생성·수정 공용 Draft와 폼 구현
- 제목, 레이드, 난이도, 숙련도, 최소 전투력과 가입 승인 방식 전체 수정 지원
- 제목, 모집 Metadata와 가입 승인 정책을 revision 기반 통합 명령으로 저장
- 파티장, 확정 파티원과 pending 신청자의 변경 영향을 저장 전에 표시
- 수정 화면에도 파티장 아이템 레벨 기반 레이드·난이도 필터 적용
- 편집 중 빈 제목을 유지하고 빈 상태로 저장할 때만 자동 제목 적용
- 값이 있는 단일행 텍스트·숫자 입력에 공통 전체 지우기(X) 동작 적용
- 관련 자동 검증과 Android 실기기 검증 통과
- 기능 커밋 `e8293e0`, 병합 커밋 `414b301`으로 `main` 및 `origin/main` 반영 완료

---

## Task-038. 대형 재설계 기준 상태 준비

- 기존 후속 작업인 최근 레이드 조건 기억을 재설계 승인 전까지 보류
- 지원 화면에는 재사용할 레이드 조건 선택이 없다는 기존 범위 불일치 기록
- Firebase 다중 사용자 전환을 포함해 제품 목표, 소유권, 상태 전이, 저장 기준과 마이그레이션 범위를 다시 산정하기로 결정
- 다음 설계 승인 전에는 코드 구현과 기능 브랜치를 시작하지 않는 기준 확정

---

## Task-039. Firebase 초기 연결 기준 상태 준비

- Firebase 프로젝트 `lost-party`와 FlutterFire CLI를 이용한 플랫폼 연결 설정 반영
- Android 패키지 `com.example.lost_party`와 Firebase 앱 등록 정보 일치 확인
- Android Google Services Gradle Plugin, `google-services.json`, `firebase.json` 및 `firebase_options.dart` 반영
- 생성 Firebase 옵션이 정적 분석 가능한 상태가 되도록 `firebase_core`까지만 초기 의존성에 포함
- Anonymous Auth 실행, Firestore Repository, Player binding, Security Rules 및 파티 데이터 전환은 후속 설계 범위로 유지
- 현재 코드 기준 Player/Firebase 구조 변경 영향과 Firebase 초기 연결 상태를 별도 문서로 기록
- 다음 단계는 Firebase 적용과 메인 파티현황 개편의 제품 정책, 데이터 소유권, 상태 전이 및 작업 단위를 작업 지시서로 확정하는 것

---

## Task-040. Firebase 단계적 구현 전환 문서 정리

- 로컬 Fake 환경에서 제품 흐름과 UI를 검증하기 위해 적용했던 Firebase 전역 구현 보류 단계 종료
- 전체 백엔드 기술 설계 완료를 기다리지 않고 기능 단위 계약과 검증 범위를 먼저 확정한 뒤 단계적으로 구현하는 기준으로 전환
- `NEXT_WORK.md`, `AI_CONTEXT.md`, `FIREBASE_PARTY_PRODUCT_FLOW.md`, `BACKEND_PARTY_ARCHITECTURE.md`의 착수 조건과 구현 순서 통일
- 첫 구현 단위를 Firebase Core 부트스트랩과 Anonymous Auth 준비·실패 진입 정책으로 지정
- 계약이 없는 후속 서버 기능만 보류하고, 계약이 준비된 기능은 독립 브랜치에서 구현·검증하도록 기준 변경

---

## Task-041. Firebase Core 앱 부트스트랩

- 작업 브랜치: `codex/firebase-core-bootstrap`
- 앱 진입 전에 플랫폼별 Firebase 옵션으로 `Firebase.initializeApp()`을 실행하는 외곽 부트스트랩 추가
- 초기화 성공 전에는 기존 `MyApp`, Drift 데이터베이스와 Fake 파티 런타임을 생성하지 않도록 경계 분리
- 초기화 대기 화면과 오류 상세를 노출하지 않는 실패 안내 및 재시도 동작 구현
- 초기화 함수를 주입해 Firebase 런타임 없이 대기·성공·실패·재시도를 검증하는 위젯 테스트 추가
- `flutter analyze` 통과, 전체 `flutter test` 225개 통과
- 사용자가 최신 브랜치를 Android 실기기에서 실행해 Firebase 초기화 후 기존 내 계정과 저장 캐릭터 데이터가 정상 표시되는 것을 확인
- 초기화 실패·재시도는 주입형 위젯 테스트로 검증했으며 정상 진입 실기기 검증과 함께 작업 완료

---

## Task-042. Firebase Anonymous Auth 부트스트랩

- 작업 브랜치: `codex/firebase-anonymous-auth`
- `firebase_auth` 의존성과 Android·Apple·Windows 플랫폼 플러그인 등록 반영
- Firebase Core 초기화 뒤 현재 인증 사용자를 확인하고 기존 사용자가 있으면 재로그인 없이 재사용
- 현재 사용자가 없을 때만 `signInAnonymously()`를 실행하고 인증 완료 전 기존 앱 생성을 지연
- 인증 실패 또는 로그인 결과 누락을 공용 부트스트랩 실패·재시도 흐름으로 전달
- Auth UID를 사용자 화면과 로그에 노출하지 않고 Player binding은 다음 작업으로 분리
- Fake Auth Gateway 기반 기존 사용자 재사용, 최초 로그인, 실패 및 결과 누락 테스트 추가
- `flutter analyze` 통과, 전체 `flutter test` 229개 통과
- Android 실기기에서 최초 익명 로그인, 기존 앱 진입, 기존 캐릭터 데이터 유지와 앱 재실행 확인 완료
- Firebase Console에서 익명 사용자 생성과 재실행 시 불필요한 사용자 추가가 없는 것을 확인해 실기기 검증 통과

---

## Task-043. Firebase Player binding

- 작업 브랜치: `codex/firebase-player-binding`
- `FIREBASE_PLAYER_BINDING_CONTRACT.md`에 `AuthUid -> PlayerId` 최소 데이터 계약, 최초 생성·재사용, 실패 및 Rules 경계 확정
- `cloud_firestore` 의존성과 Android·Apple·Windows 플랫폼 플러그인 등록 반영
- `PlayerSession`, Player binding Repository와 Firestore Store 경계 추가
- `authBindings/{authUid}`와 `players/{playerId}`를 하나의 Firestore Transaction에서 최초 생성하고 기존 binding은 active Player 검증 후 재사용
- Player binding 완료 전 기존 앱 생성을 지연하고 실패를 공용 부트스트랩 재시도 흐름으로 전달
- 자기 AuthUid의 최초 문서 쌍 생성과 단건 읽기만 허용하고 목록·수정·삭제·기존 Player 임의 연결을 차단하는 `firestore.rules` 추가
- Firebase CLI 15.28.1에서 Rules 컴파일 성공 및 `lost-party` 프로젝트 배포 완료
- PlayerSession과 Repository 단위 테스트 추가, `flutter analyze` 통과 및 전체 `flutter test` 234개 통과
- Android 실기기에서 최초 Player와 binding 문서 쌍 생성, 연결 ID 일치 및 기존 Drift 데이터 유지 확인
- 앱 재실행 시 동일 binding을 재사용하고 불필요한 Player 문서가 추가되지 않는 것을 확인해 실기기 검증 통과

---

## Task-044. 게임 계정·캐릭터 식별자와 로컬 소유 인증

- 작업 브랜치: `codex/server-account-character-contract`
- Firestore `GameAccountId`·`CharacterId` 계약과 Drift v4~v6 마이그레이션을 추가했다.
- 장비 6부위 중 1~3개를 무작위 지정하고 10분 안에 해제된 장비와 나머지 스냅샷을 비교하는 클라이언트 인증을 구현했다.
- 가등록 계정 선택과 캐릭터명 직접 입력을 모두 지원하며, 직접 입력 인증 성공 시 로컬 계정을 즉시 생성한다.
- 인증 성공 시 Firestore Transaction으로 소유권을 가져오고 이전 등록자의 로컬 상태를 `ownershipLost`로 동기화한다.
- 인증 완료 배지, 소유권 상실 안내·파티 사용 차단, 원정대에서 사라진 캐릭터의 경고·수동 삭제를 구현했다.
- 유료 서비스 미사용 결정에 따라 Cloud Functions 프로토타입과 관련 에뮬레이터 구성을 최종 브랜치에서 제거했다.
- 초기 단계의 클라이언트 조작 위험을 명시적으로 수용하고 Lost Ark API 토큰은 디바이스 보안 저장소에만 유지한다.
- 관련 표적 테스트 40개와 `flutter analyze`가 통과했고 Android 실기기에서 캐릭터 인증 성공을 사용자가 확인했다.
- 다음 작업은 하단 4탭과 설정 화면의 인증 진입 구조를 설계한 뒤 별도 작업 단위로 진행한다.
- 회고: 비용 제약을 먼저 확인하지 않은 서버 설계와 목적이 불명확한 에뮬레이터 오류 추적이 낭비를 만들었다. 이후에는 설계 전에 비용, 검증 목적과 중단 기준을 문서화한다.

---

## Task-045. 앱 셸 정보 구조 복원 및 확정

- 과거 사용자 논의와 Git 이력을 대조해 하단 탭과 내부 페이지 계층이 평탄화된 문서 충돌을 확인했다.
- 하단 탭을 `레이드 현황 / 내 계정 / 레이드 모집 / 설정` 순서로 확정했다.
- 첫 화면 `레이드 현황` 안에서 상단 페이지 전환으로 `진행 중 / 신청 중 / 완료 기록`을 구분한다.
- 내가 만들었거나 가입이 확정된 방은 `진행 중`, 승인 대기 신청은 `신청 중`, 이번 주 완료와 과거 히스토리는 `완료 기록`에서 관리한다.
- 기존 파티 모집 목록·신청·생성 화면은 세 번째 `레이드 모집` 탭의 역할로 유지한다.
- 게임계정 인증과 API 토큰 관리는 네 번째 `설정` 탭으로 이동하되 내 계정의 상태 기반 복구 진입점과 같은 화면을 공유한다.
- 다음 구현 범위는 앱 셸·라우팅과 최소 진입 화면으로 제한하고 실제 Firestore 읽기 모델은 후속 작업으로 분리한다.

---

## Task-046. 4탭 앱 셸과 설정 진입 구조

- 작업 브랜치: `codex/app-shell-navigation`
- StatefulShellRoute를 `레이드 현황 / 내 계정 / 레이드 모집 / 설정` 4개 branch로 확장했다.
- 레이드 현황에 `진행 중 / 신청 중 / 완료 기록` TabBarView와 읽기 모델 없는 최소 빈 상태를 추가했다.
- 하단 branch를 IndexedStack으로 구성해 탭별 Navigator 상태를 보존하고 레이드 현황 상단 스와이프와 충돌하지 않게 했다.
- 설정 탭에 기존 게임계정 인증과 API 토큰 화면의 진입점을 추가했고 내 계정의 상태 기반 복구 진입점은 유지했다.
- 초기 탭, 4탭 이동, 상단 스와이프, branch 상태 보존, 설정 뒤로가기와 탭 재선택 루트 복귀를 Widget 테스트 6개로 검증했다.
- `flutter analyze` 통과, 전체 `flutter test` 252개 통과.
- Android 실기기 확인을 사용자가 완료했다.
- API 토큰 삭제 전에 계정 데이터 조회·게임계정 인증 등이 정상 작동하지 않음을 알리는 확인창을 추가했고, 취소·확정·삭제 후 미등록 상태를 Widget 테스트로 검증했다.
- 커밋 `84769f8`, 병합 커밋 `23af0b3`으로 기능 브랜치와 `main`에 반영하고 모두 원격 푸시했다.

---

## Task-047. Firestore 파티 읽기 모델 계약과 Repository 경계

- 작업 브랜치: `codex/firestore-party-read-model`
- `FIRESTORE_PARTY_READ_MODEL_CONTRACT.md`에 공개 모집, 내 진행 중 레이드, 내 신청 중 목록의 스키마·쿼리·권한·인덱스를 정의했다.
- 내 파티 복제 문서를 두지 않고 서버 관리 `memberPlayerIds`로 membership 실시간 쿼리를 구성했다.
- Firestore 타입을 Domain에 노출하지 않는 읽기 Entity, Repository, DTO, Mapper와 실시간 Firestore Repository를 추가했다.
- 공개 목록·자기 membership·자기 신청 읽기만 허용하고 파티 관련 클라이언트 쓰기를 금지하는 Rules 초안과 복합 인덱스를 추가했다.
- 파티 서버 쓰기 명령이 없는 상태에서 로컬 생성 후 목록이 사라지는 모순을 피하기 위해 실행 앱의 Repository 교체는 보류했다.
- Firestore Emulator 검증과 Rules·인덱스 배포는 수행하지 않고 서버 명령·다중 사용자 권한 작업 단계로 보류했다.

---

## Task-048. Spark Firestore 파티 명령 계약

- 작업 브랜치: `codex/firebase-party-commands-contract`
- 별도 지시 전까지 Firebase와 다른 외부 서비스의 유료 플랜·결제수단·과금 가능 기능을 사용하지 않는 전역 운영 원칙을 확정했다.
- Cloud Functions가 Blaze 요금제를 요구하는 현재 정책과 충돌하므로 Callable Functions 전제를 제거했다.
- `FIRESTORE_PARTY_COMMAND_CONTRACT.md`에 파티 생성·수정·신청·철회·즉시 가입·승인·거절의 클라이언트 Transaction, Rules, 점유, revision, 오류·재시도 계약을 정의했다.
- Spark에서 Rules로 충분히 강제하기 어려운 레이드·난이도 수정은 초기 서버 전환 범위에서 제외하고 `unsupportedOnSpark`로 구분한다.
- Firestore Emulator, Rules 배포, 유료 서비스 호출은 수행하지 않았다.

---

## Task-049. Firestore 파티 생성과 확정 참가 점유

- 작업 브랜치: `codex/firestore-party-create`
- 파티 생성 명령과 오류 계약, Repository 경계, 입력 Validator를 추가했다.
- active binding에서 PlayerId를 확정하고 서버 Character의 active 소유권·입장 레벨을 다시 검증한다.
- `recruitments/{id}`, `members/{leaderPlayerId}`, `activeRaidAssignments/{characterId_raidId}`를 한 Firestore Transaction에서 생성한다.
- 모집 ID 중복과 기존 확정 참가 점유를 저장 전에 차단하고 Firebase 권한·일시 오류를 Domain 실패로 변환한다.
- Rules에서 파티장 membership과 점유가 함께 생성되고 Character 소유권·파생 필드가 일치하는 초기 생성 형태만 허용하는 초안을 추가했다.
- 저장 계획과 입력 검증 표적 테스트 5개, `flutter analyze --no-pub`가 통과했다.
- Firestore Emulator, Rules 배포, 실행 앱 Repository 교체는 수행하지 않았다.

---

## Task-050. Firestore 승인 대기 신청과 본인 철회

- 작업 브랜치: `codex/firestore-party-applications`
- 신청·철회 명령, Repository 경계와 입력 Validator를 추가했다.
- 신청 시 active binding, 모집 상태·승인 방식·빈자리·기존 멤버·중복 신청·Character 소유권·입장 레벨을 Transaction에서 재검증한다.
- 승인 대기 신청은 application 문서만 생성하고 membership과 확정 참가 점유를 만들지 않는다.
- 본인의 `pending` 신청만 expected revision 일치 시 `withdrawn`으로 전환한다.
- Rules에서 본인의 최초 pending 생성과 `pending -> withdrawn` 허용 필드만 변경하는 형태를 제한했다.
- 저장 계획·입력 검증 표적 테스트 4개와 `flutter analyze --no-pub`가 통과했다.
- Firestore Emulator, Rules 배포, 실행 앱 Repository 교체는 수행하지 않았다.

---

## Task-051. Firestore 즉시 가입과 신청 승인·거절

- 작업 브랜치: `codex/firestore-party-join-approval`
- 즉시 가입, 신청 승인과 거절 명령·Repository 경계·입력 Validator를 추가했다.
- 즉시 가입은 `directJoin` 모집에서 pending 신청을 만들지 않고 멤버십·확정 참가 점유·모집 인원과 revision을 단일 Transaction으로 갱신한다.
- 승인은 파티장 권한, pending 신청과 양쪽 revision, Character 소유권, 확정 참가 점유와 최신 파티 배치를 다시 확인한 뒤 신청·멤버십·점유·모집을 함께 갱신한다.
- 거절은 권한과 revision을 확인한 뒤 pending 신청만 `rejected`로 종료하며 멤버십과 점유를 만들지 않는다.
- 모집 revision과 Transaction에서 다시 읽은 기존 멤버 문서를 결합해 동시 가입 시 오래된 파티 배치가 저장되지 않도록 했다.
- Rules에 모집 가입 갱신, 일반 멤버십·점유 생성과 승인자 신청 결정을 허용하는 결합 불변식을 추가했다.
- 저장 계획·입력 검증 표적 테스트 3개와 `flutter analyze --no-pub`가 통과했다.
- 실행 앱 Repository 교체, Firestore Emulator, Rules 배포와 외부 유료 서비스 호출은 수행하지 않았다.

---

## Task-052. Firestore 확정 파티원 관리

- 작업 브랜치: `codex/firestore-party-membership-management`
- 참가 캐릭터 변경, 본인 탈퇴, 책임자 추방과 가입 승인 권한 변경 명령·Repository·입력 Validator를 추가했다.
- 캐릭터 변경은 역할과 파티 자리를 유지하면서 새 Character 소유권·입장 레벨·점유·같은 파티의 동일 직업 딜러 제한을 재검증하고 기존·신규 점유와 membership을 한 Transaction으로 교체한다.
- 탈퇴·추방은 membership과 점유를 제거하고 모집 인원·빈자리·revision을 함께 갱신한다.
- 책임자 탈퇴 시 Transaction으로 유지되는 `memberPlayerIds` 가입 순서의 첫 잔여 멤버에게 책임자와 승인 권한을 승계하며, 마지막 멤버라면 모집을 `disbanded`로 종료한다.
- 책임자만 다른 현재 멤버의 가입 승인 권한을 부여·회수할 수 있도록 제한했다.
- 다른 확정 파티 사이의 Character 이동·스왑은 이번 단일 파티 명령 범위에서 분리하되 Spark에서 원천 제외하지 않고, 로컬 예상 결과와 양쪽 파티 서버 Transaction을 결합하는 후속 명령으로 정의했다.
- 파티 서버 상태는 최종 진실, 로컬 데이터는 표시·후보 계산용 Projection으로 구분하고 목록·알림·상세 진입 시 최신화한 뒤 명령 시 서버가 revision과 조건을 재검증하는 기준을 읽기 계약에 기록했다.
- Firestore 영속 캐시와 별도 Drift Projection 중 실제 저장 위치, 보존·계정 전환·오프라인 정책은 실행 앱 Repository 전환 전 확정할 후속 설계로 남겼다.
- Rules에 Character 점유 교체, 멤버 제거, 책임자 승계와 승인 권한 변경의 결합 불변식을 추가했다.
- 저장 계획·입력 검증 표적 테스트 5개와 `flutter analyze --no-pub`가 통과했다.
- 실행 앱 Repository 교체, Firestore Emulator, Rules 배포와 외부 유료 서비스 호출은 수행하지 않았다.

---

## Task-053. Firestore 회차 수명주기

- 작업 브랜치: `codex/firestore-party-cycle-lifecycle`
- KST 수요일 오전 6시 기준 회차 경계와 화요일 22시 완료 취소 마감을 계산하는 순수 정책을 추가했다.
- 파티 완료, 반복 파티 완료 취소·재완료, 반복 설정과 만료 회차 전환 명령·Repository·Validator를 추가했다.
- 완료와 미완료 종료 시 `cycles/{cycleKey}`에 당시 참가자 Snapshot을 저장하고 모집 상태와 revision을 같은 Transaction에서 갱신한다.
- 1회성 완료·미완료 회차는 종료하고 반복 파티는 현재 구성을 연속된 다음 회차로 승계한다.
- 유료 스케줄러 대신 앱 동기화 시 현재 멤버가 멱등 전환을 실행하며, Rules가 서버 시간·7일 경계·revision을 최종 검증한다.
- 회차 정책·Validator·저장 계획과 파티 생성 회귀 표적 테스트 12개 및 `flutter analyze --no-pub`가 통과했다.
- 실행 앱 Repository 연결, 사용자 이벤트, 로컬 히스토리, Firestore Emulator, Rules 배포와 외부 유료 서비스 호출은 수행하지 않았다.

---

## Task-054. Player 이벤트와 로컬 히스토리

- 작업 브랜치: `codex/party-events-local-history`
- 회차 완료·미완료 종료·완료 취소 Transaction이 대상 Player별 Firestore 이벤트를 함께 생성하도록 연결했다.
- 이벤트는 안정적인 ID, 회차 revision, Character Snapshot, 서버 발생 시각과 28일 만료 시각을 포함한다.
- Rules에서 해당 회차가 같은 요청에서 변경됐고 대상 Player와 event revision이 Snapshot에 일치할 때만 이벤트 생성을 허용한다.
- Drift schema v7에 `raidHistoryEntries`를 추가하고 이벤트 ID 기반 멱등 동기화, 숨김·재표시와 로컬 완료 정정을 구현했다.
- 재동기화는 서버 상태를 갱신하되 사용자의 숨김과 로컬 정정을 유지한다.
- active Player 이벤트를 시간순으로 읽어 로컬 DB에 반영하는 동기화 서비스를 추가했다.
- 로컬 DB·이벤트·회차 저장 계획 표적 및 회귀 테스트 30개와 `flutter analyze --no-pub`가 통과했다.
- 실행 앱 화면 연결, FCM, TTL 배포, Emulator와 외부 유료 서비스 호출은 수행하지 않았다.

---

## Task-055. Codex·Cursor 역할 전환과 구현 인수인계 문서 정리

- Codex는 설계·계약·작업 분해·문서 정합성·인수인계, Cursor는 주 코드 구현·빌드·표적 테스트를 중심으로 담당하도록 역할을 갱신했다.
- 어느 도구도 코드 수정 또는 설계 제안이 금지되는 구조는 아니며, 계약 변경은 문서에 영향과 제안을 먼저 남기도록 했다.
- `NEXT_WORK.md`를 누적 과거 상태에서 Cursor가 바로 사용할 실행 앱 Firebase 전환 1단계 인수인계 문서로 교체했다.
- 다음 작업의 목표, 확인 파일, 포함·제외 범위, 로컬 Projection 최소 정책과 완료 조건을 명시했다.
- `AI_CONTEXT.md`의 현재 인계 기준을 과거 인계 기록보다 우선하도록 분리하고 오래된 현재 브랜치 표현을 과거 이력으로 정정했다.
- 문서 색인에 Firestore 읽기·명령·이벤트 계약을 추가했다.

---

## Task-056. 실행 앱 Firebase 읽기·이벤트 동기화 전환 1단계

- 작업 브랜치: `cursor/firebase-runtime-stage1`
- `AppBootstrap`을 제네릭화하고 `initializeAppServices`가 `PlayerSession`을 반환하도록 바꿔 Composition Root에 PlayerId를 전달했다.
- `FirestorePartyReadRepository`와 `PartyEventSyncService`를 레이드 현황에 연결하고, 테스트용 Fake 주입 경계를 유지했다.
- `진행 중`은 `watchActiveRaids`, `신청 중`은 `watchApplications`, `완료 기록`은 Drift `loadRaidHistory` + 멱등 이벤트 동기화 ViewModel로 구성했다.
- loading·빈 상태·캐시·오류·로컬 조회 실패를 구분해 표시하고, 로컬 DB 실패 시 동기화를 생략한다.
- Android에서 `libsqlite3.so`(native assets) 누락으로 완료 기록이 실패하던 문제를 전체 재설치로 해소했다.
- 표적 ViewModel/Widget 테스트와 Android 실기기 세 탭 검증을 통과했다.
- Fake 기반 모집·신청 쓰기 UI와 명령 Repository 실행 앱 전환, Emulator, FCM, TTL 배포는 범위 밖이다.

---

## Task-057. 레이드 현황 목록·완료 기록 UX와 읽기 규칙 보강

- 작업 브랜치: `cursor/firebase-runtime-stage1`
- `진행 중` 카드를 레이드·난이도·관문, KST 시작 일정, 인원/남은 자리, 최소 조건 중심으로 표시한다. 시작 시각이 없으면 `시작 시간 미정`이다.
- `신청 중`은 `승인 대기`와 `최근 처리 결과`를 나누고, `superseded` + `recruitmentClosed`는 거절과 구분해 안내한다.
- `완료 기록`에 카탈로그 표시명, 숨김·로컬 정정 메뉴, `숨긴 기록 보기` 토글을 연결했다. 숨김·정정은 Drift에만 남고 재동기화해도 유지된다.
- 빈 목록에서 오프라인 안내가 풀리지 않던 문제를 `snapshots(includeMetadataChanges: true)`로 수정했다.
- `신청 중` collection group 쿼리가 중첩 경로 규칙만으로는 거부되던 문제를 `match /{path=**}/applications/{applicantPlayerId}` `list` 규칙으로 보완하고 `lost-party`에 배포했다.
- 읽기·이벤트 계약 문서에 메타데이터 구독, collection group 규칙, 완료 기록 화면 연결을 반영했다.
- `flutter analyze --no-pub`과 전체 테스트 312개가 통과했다.
- Android 실기기에서 진행 중 탭의 오프라인 안내가 사라지고, 재실행 시 `PERMISSION_DENIED` 로그가 더 이상 나오지 않음을 확인했다.
- 모집 만들기 등 쓰기 UI는 여전히 Fake이므로 만든 방은 레이드 현황에 나타나지 않는다. 목록→상세 진입은 다음 작업이다.

---

## Task-058. 레이드 현황 목록에서 읽기 전용 상세 진입

- 작업 브랜치: `cursor/firebase-runtime-stage1`
- `watchRecruitment`이 `PartyReadDetailSnapshot`으로 문서 누락과 `isFromCache`를 함께 전달하도록 읽기 계약을 맞췄다.
- 진행 중·신청 중 카드는 레이드 현황 Navigator의 `/raid-status/:recruitmentId`로 들어가 탭 상태를 유지한다.
- `PartyReadDetailPage`는 Firestore 읽기만 표시하고 Fake `RecruitmentDetailPage`의 신청·수정 버튼을 연결하지 않는다.
- loading·누락·권한 오류·오프라인 안내를 목록과 같은 문구로 표시한다.
- ViewModel/Widget 표적 테스트와 전체 테스트 323개, `flutter analyze --no-pub`이 통과했다.
- 쓰기 Repository 전환 전까지 로컬에서 만든 방은 이 상세에도 없다.

---

## Task-059. 모집 생성 명령의 실행 앱 Firestore 전환

- 작업 브랜치: `cursor/firebase-runtime-stage1`
- 실행 앱 모집 생성만 `FirestorePartyCreateRepository`에 연결하고, 목록·신청·승인·멤버·회차·Fake 상세는 InMemory 경로를 유지했다.
- 파티장 Character ID는 게임 계정 인증의 `serverCharacterId`를 사용한다. 없으면 명령을 보내지 않고 인증 안내를 표시한다.
- 생성 성공 시 Fake 상세 대신 `/raid-status/{recruitmentId}` 읽기 상세로 이동한다.
- Fake 생성 흐름 회귀와 Firestore 생성 경로 표적 테스트를 통과했다. 전체 테스트 325개, `flutter analyze --no-pub` 통과.
- 인증되지 않은 로컬 캐릭터로 만든 방은 여전히 Firestore 현황에 나타나지 않는다.
- 인증된 캐릭터로 생성이 `permission-denied` 되던 원인은 캐릭터 인증이 아니라, 신규 모집 ID에 대한 `get`이 없는 문서의 `resource.data`를 읽어 거부된 것이다. 존재하지 않는 모집 단건 `get`은 active binding만 요구하도록 Rules를 수정하고 `lost-party`에 배포했다.
- Android 실기기에서 인증된 캐릭터로 모집 생성, `진행 중` 목록 표시, 읽기 전용 상세 진입, 수정 화면 미적용 안내까지 확인했다.

---

## Task-060. 인증 캐릭터 최소 정보 자동 동기화

- 작업 브랜치: `cursor/character-summary-sync`
- `CharacterSummarySyncService`와 `FirestoreCharacterSummarySyncGateway`를 추가했다.
- `내 계정` 진입 시 기존 Drift를 먼저 표시하고, 마지막 성공 시각 기준 1분이 지나면 siblings 최소 요약을 백그라운드 조회한다.
- 변경된 캐릭터명·아이템 레벨·캐릭터 레벨만 Drift에 쓰고, active 소유·`serverCharacterId`가 있는 Character만 Firestore에 반영한다. 변경이 없으면 앱 서버 전송을 생략한다.
- 수동 새로고침은 제한과 무관하며, 네트워크 진행 중 버튼을 비활성한다. 서버 반영 실패는 로컬 성공으로 숨기지 않는다.
- 모집 생성 `invalidCharacter` 메시지에 내 계정 새로고침 안내를 추가했다.
- 조회 캐릭터명 입력란에 메인 계정 대표 캐릭터명을 비어 있을 때 자동 채운다.
- 표적 동기화 서비스·계정 ViewModel/Page·모집 생성 테스트와 `flutter analyze --no-pub`를 통과했다.
- Android 실기기에서 자동 조회, 아이템 레벨 변경 반영, 로컬·서버 불일치 시 새로고침 안내와 갱신 후 모집 생성을 확인했다.
- Rules 필드 단위 강화는 후속 작업으로 남긴다.

---

## Task-061. 신청·철회 명령의 실행 앱 Firestore 전환

- 작업 브랜치: `cursor/party-application-commands`
- `/raid-status/:recruitmentId` 상세에 `FirestorePartyApplicationCommandRepository`와 리더 후보 서비스를 연결했다.
- 신청은 인증된 `serverCharacterId`만 사용하고, 본인 pending 신청은 `revision`으로 철회한다.
- `PartyApplicationSummary.revision`과 `PublicRecruitmentSummary.currentCycleKey`, `watchMyApplication` 읽기 경계를 추가했다.
- Fake 모집 상세(`/recruitments/:id`) UI는 재사용하지 않았다.
- 표적 상세·mapper·현황 테스트와 `flutter analyze --no-pub`를 통과했다.
- 단일 Android 기기(Player 1개)라 타 계정 신청·철회 실기기는 보류했다. 본인 방 신청은 `alreadyMember`로 거절되는 것을 확인했다.
- 철회 후 재신청 Transaction과 공개 목록 UI 연결은 후속으로 남긴다.

---

## Task-062. LostParty Design System v1 기반과 대표 Card 시범 적용

- 작업 브랜치: `codex/design-system-v1-doc`
- `Soft Lavender Gaming Utility` 방향과 Light Theme의 Color·Spacing·Radius token을 확정했다.
- 기존 `main.dart`의 `deepPurple` seed 직접 구성을 `AppTheme.light`로 분리했다.
- Neutral Background와 흰색 Surface, muted purple Primary, 약한 Card border, 버튼 계층의 기본 Theme을 적용했다.
- 기존 Material 3 Bottom Navigation 구조를 유지하면서 흰색 Surface, Lavender 선택 Pill과 선택·비선택 색상 규칙을 연결했다.
- `PublicRecruitmentSummary` 기반 공개 모집 Card를 대표 컴포넌트로 지정하고 제목·모집 상태·난이도·시작 시간·멤버/남은 자리·최소 조건의 정보 계층을 적용했다.
- Theme과 대표 Card 표적 테스트 3개 및 `flutter analyze --no-pub`가 통과했다.
- 기존 `widget_test.dart`는 Router가 테스트 주입과 무관하게 Firebase 기본 인스턴스를 생성하는 기존 결합으로 실패했으며 디자인 범위에서 Router를 변경하지 않았다.
- 사용자가 시범 디자인 방향을 확인하고 승인했다. 전체 화면 일괄 리디자인은 하지 않으며 후속 기능 작업에서 점진적으로 확장한다.

---

## Task-063. 레이드 모집 공개 목록 Firestore 페이징 읽기 전환

- 작업 브랜치: `cursor/public-recruitment-list`
- `PartyReadRepository`에 `watchPublicRecruitmentFirstPage`와 `loadPublicRecruitmentNextPage`를 추가하고 제한 없는 `watchPublicRecruitments`를 제거했다.
- 첫 페이지는 `updatedAt desc` + 문서 ID desc, `limit(20)` 실시간 구독이고, 다음 페이지는 불투명 cursor의 일회 조회다.
- ViewModel은 `recruitmentId`로 병합하고, 첫 페이지 ID 집합 변경 시 추가 페이지를 초기화하며, 명시적 새로고침으로 listener·cursor·추가 오류를 리셋한다.
- `RecruitmentListPage`는 실행 앱에서 `PartyReadRepository`와 현재 `cycleKey`를 사용한다. 카드 탭은 `/raid-status/{id}`로 이동하고 Fake `/recruitments/:id`와 데이터를 섞지 않는다.
- loading·빈 목록·캐시·첫 페이지 오류·추가 loading·추가 오류·마지막 페이지 경계를 표적 ViewModel/Widget 테스트로 검증했다.
- `firestore.indexes.json` 공개 목록 인덱스에 `__name__ desc`를 추가했다. 실제 배포 확인과 Android 실기기 검증은 남긴다.
- Fake 상세·승인·멤버·회차는 InMemory 경로를 유지한다.
- `flutter analyze --no-pub`과 표적 테스트가 통과했다.
- 최신 `main`을 작업 브랜치에 merge한 뒤, Task-063을 `main`에 통합해 다음 작업의 기초를 `main`으로 맞췄다.

---

## Task-064. 파티장·파티원 표시 누락 점검과 다음 작업 재정의

- 작업 브랜치: `codex/document-party-leader-members`
- 기존 Fake 모집 Card에는 파티장 캐릭터명·직업이, Fake 상세에는 파티별 멤버 구성과 자기 캐릭터 변경 진입점이 있었음을 확인했다.
- Firestore 실행 화면의 `PublicRecruitmentSummary`와 `ActiveRaidSummary`는 파티장 PlayerId만 보유하며, 현재 공개 모집·진행 중 Card와 현황 상세에는 파티장 표시가 없다.
- Firestore membership에는 캐릭터명·직업·역할·파티 위치·아이템 레벨·전투력 Snapshot이 저장되지만 읽기 계약 문서에는 아이템 레벨·전투력이 빠져 있었고, 멤버 DTO·Repository stream·상세 UI가 구현되지 않았다.
- 현재 Rules는 확정 멤버만 전체 membership 목록을 읽을 수 있어 공개 상세 방문자에게 파티 구성을 보여 주려면 안전한 공개 필드와 읽기 구조를 먼저 결정해야 한다.
- 파티장 표시는 Firestore 전환 중 누락, 전체 파티원 표시는 읽기 계약·권한·UI 이관 누락으로 분류했다. 자기 캐릭터 변경과 멤버 관리는 기반 구현 후 실행 연결 대기, 파티 내 자리 이동과 다른 파티 사이 이동·스왑은 별도 후속 설계로 구분했다.
- 다음 작업을 파티장 표시 Snapshot, 멤버 읽기 경계, 공개 권한과 목록·상세 UI 복구로 변경하고 즉시 가입·승인·거절을 그 다음 순서로 이동했다.
- 문서만 변경했으므로 Flutter 검증은 실행하지 않고 `git diff --check`와 문서 간 정합성 검토로 검증한다.

---

## Task-065. 파티장·파티원 읽기 모델과 목록·상세 UI 복구

- 작업 브랜치: `cursor/party-leader-members-read`
- 공개 membership 읽기는 Option 1로 확정했다. Rules에서 공개 모집 membership `get`/`list`를 active binding에 허용하고 Domain/UI는 표시 Snapshot만 소비한다.
- 모집 Current State에 `leaderCharacterNameSnapshot` / `leaderClassNameSnapshot`을 추가하고 생성·파티장 캐릭터 변경·책임자 승계 시 같은 Transaction에서 유지한다.
- `PartyMemberDisplay`, `watchRecruitmentMembers`, Mapper 소프트 Snapshot 파싱을 추가했다. 누락 Snapshot은 전체 실패 대신 `정보 없음`으로 표시한다.
- `레이드 모집` Card·`진행 중` Card·`/raid-status/:id` 상세에 파티장과 파티별 구성을 표시한다.
- 표적 Mapper·WritePlan·Card·상세·현황 테스트와 `flutter analyze --no-pub`을 통과했다.
- Android 실기기에서 목록·상세 파티장·파티원 표시를 확인했다.
- `firebase deploy --only firestore:rules --project lost-party`로 Option 1 포함 Rules 전체를 배포했고 Console에서 `canReadPublicRecruitmentMembers`를 확인했다.

---

## Task-066. 즉시 가입·승인·거절 실행 앱 연결

- 작업 브랜치: `cursor/party-join-approve-reject` (`main`의 Task-065 병합 커밋에서 분기)
- `PublicRecruitmentSummary.approvalMode`와 Mapper 매핑을 추가했다.
- `watchRecruitmentApplications`로 방의 신청 목록을 구독한다.
- `PartyReadDetailPage`에 `FirestorePartyJoinCommandRepository`를 연결했다.
  - `directJoin`: 바로 가입(`joinDirectly`)
  - `leaderOnly`: 지원하기·철회 유지, 파티장 pending 승인·거절
- 표적 상세·Mapper 테스트와 `flutter analyze --no-pub`을 통과했다.
- Android 2기기 실기기 검증은 대기 중이다. 사용자는 추가 디바이스로 테스트한 뒤 수정 지시를 다시 내린다.
- **2기기 검증·수정 완료 전까지 `main`에 병합하지 않는다.** 체크리스트는 `NEXT_WORK.md`에 둔다.

### Task-066 1차 실기기 피드백 대응 (브랜치 전용)

- 증상: 재시작 후 지원 시 `신청 권한을 확인하지 못했습니다`, 인증 캐릭터 목록 토스트, 인증 직후 미반영 추정, 인증 진행 UI 재진입 소실.
- Rules: `recruitmentApplicationPath` + `canGetRecruitmentApplication`으로 **없는 application 문서 get**을 허용. 공개 membership 읽기 헬퍼는 유지.
- 앱: Gateway `activeChallenge`로 인증 진행 UI 복원, 인증 바인딩 후 `loadAccounts` 재조회, 신청 후보 없음 메시지 분리.
- **Rules는 사용자/운영자가 `firebase deploy --only firestore:rules`로 재배포해야 신청이 풀린다.** `main` 병합은 재검증 후.

### Task-066 Rules 재배포·재시도 (2026-08-26)

- `firebase deploy --only firestore:rules --project lost-party`로 `canGetRecruitmentApplication` 포함 Rules를 배포했다.
- 배포 전에도 동일 메시지가 났다면 미배포가 원인이었을 가능성이 크다.
- 추가로 신청/즉시가입에 `targetCycleKey`를 쓰도록 클라이언트를 보강했다.

### Task-066 실기기 현황 정리 (꼬임 방지, 2026-08-26)

- **확인됨:** Rules 배포 후 신청(지원하기)·신청 리스트 표시 성공.
- **실패·미수정:** 파티장 **승인**. 신청 get Rules와 별개.
- **미확인:** 거절·철회·즉시가입.
- 브랜치 `cursor/party-join-approve-reject` (`3cfd835` Rules/인증 UX, `ed7ec10` targetCycleKey). `main` 미병합.
- 사용자가 지금 할 테스트·보고 형식은 `NEXT_WORK.md` 「지금 사용자가 할 테스트」에만 둔다.

### Task-066 우선순위 재정의 (2026-08-26 오후)

- 사용자: 거절 후 B의 전 캐릭터가 A의 전 방에 막히는 체감 → **방 단위** 거절 기억 + **재신청 허용** + **N회 거절 안내**가 필요. 합동 테스트는 기능 추가 후.
- **구현 순서:** (A) 내 모집 삭제/해산 → (B) 방 단위 재신청·N회 안내 → (C) 합동 실기기. 승인 단독 수정은 뒤로.
- 기술 메모: 같은 방 재신청 불가는 `apply`의 `application.exists` 거부에 해당. 전역 차단은 재현·분리 예정.

### Task-066 Step A — 내 모집 삭제 1차 (2026-08-26)

- `/raid-status/{id}`에 파티장 **모집 삭제** 연결. 단독 멤버면 membership `leave`로 `disbanded`.
- 다인 방은 아직 해산 불가 안내. Rules 추가 배포 없음.
- 다음: Step B 거절 후 재신청·N회 안내. `main` 미병합.

### Task-066 Step B — 방 단위 재신청 (2026-08-26)

- 거절·철회·superseded 후 같은 `applications/{playerId}`를 `pending`으로 재신청. `rejectionCount` 유지.
- Rules `validApplicationReapply` + 상세 N회 거절·다시 지원하기 UI.
- **Rules 재배포 후** Step C 합동 테스트. `main` 미병합.

### Task-066 Step C 합동 실기기 통과 (2026-08-26)

- 확인: N회 거절 안내·재신청·캐릭터 재선택, 단독 모집 삭제, 승인, 철회, 즉시 가입.
- 브랜치 `cursor/party-join-approve-reject`. **`main` 병합은 사용자 지시 대기.**
- 후속: 다인 해산, 멤버·회차 명령 등 (`NEXT_WORK.md`).

### Task-066 `main` 병합 (2026-08-26)

- `cursor/party-join-approve-reject`를 `main`에 병합·푸시했다.
- 통합 기준은 Task-066(가입·승인·거절·재신청·즉시가입·단독 삭제)까지.
- 다음 작업은 멤버 명령·회차 명령부터 (`NEXT_WORK.md`).

---

## Task-067. 파티 고정 슬롯 구성판과 최종 후속 채팅 요구사항 문서화

- 작업 브랜치: `codex/docs-party-slots-chat`
- 현재 membership의 `partyIndex`는 파티 번호만 나타내며 상세 UI가 이를 자리 번호 계산에 사용해 같은 파티 멤버가 모두 `1자리`로 표시되는 원인을 확인했다.
- `partyIndex`와 파티 내부 `slotIndex`를 분리하고 4인·8인 정원 전체의 점유·빈 슬롯을 Card/Cell 구성판으로 표시하는 방향을 확정했다.
- `1파티 1번`은 4인 파티장, 8인 파티장 겸 공대장 자리로 고정하고 캐릭터 변경은 자리를 유지하며 탈퇴·추방 후 자동 당김 배치를 하지 않는 원칙을 기록했다.
- 빈 슬롯은 우선 `현재 별도 참가 조건 없음`을 표시하고 향후 역할·직업군·시너지 요청 조건을 membership과 분리해 확장한다.
- 파티 상세 멤버 전용 최근 10개 텍스트 채팅은 모든 핵심 파티·슬롯·그룹 기능 이후 가장 마지막에 구현한다. 상세 화면에서만 `limit(10)` 실시간 구독하고 목록·다른 탭에서는 읽지 않는 최소 비용 원칙을 기록했다.
- 문서만 변경했으므로 Flutter 검증은 실행하지 않고 `git diff --check`와 문서 간 정합성 검토로 검증한다.

---

## Task-068. 고정 슬롯 쓰기·구성판·승인 점유 get (2026-08-26)

- 작업 브랜치: `cursor/party-fixed-slots`
- 생성은 `(partyIndex: 0, slotIndex: 0)`, 즉시 가입·승인은 기존 멤버를 재배치하지 않고 빈 슬롯만 배정한다.
- `slotIndex`가 없는 기존 방은 가입 계산 시 리더·`joinedAt`·`playerId`로 점유를 결정적으로 추정하고, UI에서는 자리 미정으로 표시한다.
- 현황 상세에 정원 전체 점유·빈 슬롯 Card 구성판을 연결했다(좁은 화면 1열, 너비 600+ 2열).
- Rules: 생성·가입 `slotIndex` 검증, 캐릭터 변경 시 자리 유지, 승인용 신청자 점유 문서 get 허용.
- 실기기: 즉시 가입·승인 통과. 거절은 기존과 동일.
- 표적 테스트(구성 정책·쓰기 계획·매퍼·구성판·상세)와 변경 파일 `flutter analyze` 통과.
- 다음: 멤버 명령(캐릭터 변경·탈퇴·추방) 실행 앱 연결 (`NEXT_WORK.md`).

---

## Task-069. 파티 구성판 반응형 그룹 배치 (2026-08-26)

- 작업 브랜치: `cursor/party-composition-responsive-layout`
- Slot Card 2열을 제거하고 가용 폭 기준 **파티 그룹** 배치로 전환했다. 좁은 화면은 세로 1열, 넓은 화면은 1·2파티 좌우.
- 실기기에서 펼친 폴드가 미달하던 후보 `720dp`를 `600dp`로 조정했다.
- 넓은 8인에서 같은 자리 좌우 Slot Card 높이를 `IntrinsicHeight`로 맞췄다.
- 표적 위젯 테스트와 `flutter analyze` 통과. 바형·폴드 실기기 디자인 통과.
- 다음: 자기 참가 캐릭터 변경·탈퇴·추방 (`NEXT_WORK.md` Task-070).

---

## Task-070. 자기 참가 캐릭터 변경·탈퇴·추방 (2026-08-26)

- 작업 브랜치: `cursor/party-membership-commands`
- 현황 상세에 `changeCharacter` / `leave` / `kick`을 연결했다. 캐릭터 변경은 역할과 `(partyIndex, slotIndex)`를 유지한다.
- 탈퇴·추방 후 남은 멤버를 앞자리로 당기지 않는다. 다인 해산은 범위 밖이며 단독 모집 삭제만 1인일 때 유지한다.
- `PartyMemberDisplay`에 표시하지 않는 `playerId`·`characterId`를 두어 명령 대상 식별에 쓴다.
- BUG-001: 상세 `recruitmentId` 변경 시 State가 남는 문제를 `ValueKey`와 ViewModel `restart`/`didUpdateWidget`으로 수정했다. 정상 스텝 실기기 통과 후 종료 기록만 `BUG_REPORTS.md`에 남김.
- 표적 테스트·`flutter analyze` 통과. 실기기에서 변경·탈퇴·추방 통과.
- 다음: 완료·완료 취소·종료·해산 (`NEXT_WORK.md` Task-071).

---

## Task-071. 완료·완료 취소·종료·해산 (2026-08-26)

- 작업 브랜치: `cursor/party-cycle-lifecycle`
- 현황 상세에 `complete` / `cancelCompletion` / `setRecurrence` / `advance` / `disband`를 연결했다.
- Rules에 다인·완료 후 해산(`validRecruitmentDisband`)과 완료 후 반복 설정 변경을 추가했고 `lost-party`에 배포했다.
- 1회성 완료 후 진행 중 목록에 `status in [active, completed]`로 **해산 대기**를 남겨 상세 재진입·해산이 가능하게 했다.
- 완료 직후·완료 기록 탭 이벤트 sync, 하단 탭 터치 시 브랜치 루트 복귀를 보강했다.
- 표적 테스트·analyze 통과. 실기기에서 완료·해산·해산 대기 목록 확인.
- 열린 이슈: BUG-002, BUG-005(주간 재완료 미차단), BUG-006(초기 권한 실패 관찰).
- 다음: 알림 서비스 별도 설계 (`NEXT_WORK.md` Task-072).

---

## Task-072. 파티 이벤트 기반 앱 내부 알림·FCM 확장 설계 (2026-08-26)

- 작업 브랜치: `codex/notification-event-design`
- 실제 Party Event, application, membership, read model, Drift v7 히스토리와 Firestore Rules를 문서 계약과 대조했다.
- Spark에서는 `players/{playerId}/events/{eventId}`를 사용자별 비공개 알림 투영본으로 확장하고, 앱 내부 알림을 먼저 구현하기로 결정했다.
- 알림은 성공한 파티 명령의 파생 정보이며 자유 문구를 저장하지 않는다. 명령 Transaction과 유형별 Rules가 상태 전이·수신자·Snapshot·event ID를 검증한다.
- 초기 읽음 상태는 event ID별 Drift 로컬 Projection으로 두고 여러 기기 동기화는 후속으로 보류했다. 완료 히스토리의 숨김·로컬 정정 필드는 읽음 상태로 재사용하지 않는다.
- 가입 신청부터 해산까지 이벤트별 행위자·수신 대상·표시 문구·이동 목적지·제외 대상·Snapshot·중복 방지 기준을 `PARTY_NOTIFICATION_CONTRACT.md`에 기록했다.
- 향후 신뢰 서버가 같은 Player Event를 검증하고 방별 설정·토큰을 확인해 FCM을 전달하는 확장 지점을 정의했다. Flutter의 토큰 조회·FCM 직접 호출·자격 증명 포함은 금지했다.
- 코드, Firestore Rules와 Firebase 배포는 변경하지 않았다. 문서 정합성과 `git diff --check`로 검증한다.
- Codex와 Cursor가 교대로 작업할 때 대화 맥락 없이도 이어갈 수 있도록 `NEXT_WORK.md`를 실행 지시서 형식으로 보강했다. 공통 인계 상태 양식, 단계별 담당, Task-073 코드 확인 지점·불변식·산출물·검증 체크리스트·중단 조건을 추가했다.
- 다음: Task-073 공통 알림 이벤트 schema·Rules 기반.

---

## Task-073. 앱 내부 알림 이벤트·로컬 UI (2026-08-27)

- 작업 브랜치: `cursor/party-notification-event-foundation`
- 공통 `PartyEvent` / write plan / mapper와 자기 Player Event 읽기 Repository를 추가했다.
- Rules에 신청·멤버십·`partyDisbanded` 유형별 create 검증을 넣고 `lost-party`에 배포했다. 일반 create는 열지 않았다.
- 신청·멤버십·해산 명령 Transaction에 이벤트를 연결했다. `partyEnded`·`memberMoved`는 보류했다.
- Drift v8 `partyNotificationReceipts`와 unread 집계, 현황 AppBar 알림 아이콘·목록 UI·문구 템플릿을 추가했다.
- 다인 해산이 실패하던 원인을 Transaction에서 `get`/`delete` 교차 호출로 확인했다. 모든 읽기 후 쓰기로 수정했고 실기기에서 다인 해산이 정상 동작했다.
- FCM·OS 알림·Emulator·유료 서비스는 제외했다.
- Task-073은 `main`에 병합됨. 이후 제품 우선순위 재검토로 상세 채팅은 후순위로 이동했다.

---

## Task-074. 개인 주간 레이드 Claim 계약 문서화 (2026-08-27)

- 작업 브랜치: `codex/weekly-raid-claim-contract`
- 파티 회차 상태, 활성 참가 점유와 개인 캐릭터 주간 완료를 분리하고 서버 Claim을 내 계정 체크박스와 모집 제한의 단일 기준으로 확정했다.
- 파티장·공대장 완료는 당시 구성원 전체 완료, 일반 멤버 완료는 본인 탈퇴와 본인 완료, 내 계정 수동 체크는 앱 밖 완료까지 같은 Claim으로 처리하도록 정리했다.
- Claim을 수동 체크할 때 활성 참가 방이 있으면 명시적 확인 후 탈퇴·점유 해제·pending 종료·Claim 생성을 하나의 Transaction으로 처리한다.
- 체크 해제는 본인의 Claim만 삭제하며 과거 membership·파티·다른 구성원 Claim을 복구하거나 변경하지 않는다.
- 같은 `playerId + characterId + raidId + cycleKey`의 Claim과 활성 점유가 공존할 수 없고, 생성·신청·즉시 가입·승인·캐릭터 변경이 서버에서 Claim을 재검증하도록 계약했다.
- [`../architecture/WEEKLY_RAID_CLAIM_CONTRACT.md`](../architecture/WEEKLY_RAID_CLAIM_CONTRACT.md)를 새 기준 문서로 추가하고 `NEXT_WORK.md`의 다음 구현을 Task-075 읽기 기반 A로 분해했다.
- BUG-005는 이 작업에 흡수하고, 현재 재현되지 않는 BUG-002·006은 재발 시 다시 여는 조건으로 종료 간주했다.
- 코드, Firestore Rules와 Firebase 배포는 변경하지 않았다.

---

## Task-075. 개인 주간 레이드 Claim 기반 A (2026-08-27)

- 작업 브랜치: `codex/weekly-raid-claim-foundation`
- `WeeklyRaidClaim` Domain·DTO·mapper와 현재 Player·현재 주차 전용 Firestore stream Repository를 추가했다.
- 문서 ID는 `cycleKey`, `characterId`, `raidId`를 각각 UTF-8 base64url(no padding)로 인코딩해 `~`로 연결하도록 확정하고 안정성 테스트를 추가했다.
- 내 계정 캐릭터 Card에 입장 가능한 활성 레이드 중 골드 기준 기본 3개를 읽기 전용 체크박스로 표시한다. Claim이 있으면 체크되고 같은 raidId의 난이도는 중복 표시하지 않는다.
- Drift 완료 히스토리·Party Event·기존 InMemory `WeeklyRaidClearRepository`는 변경하거나 Claim 저장소와 합치지 않았다.
- `firestore.rules`에 자기 Player `weeklyRaidClaims` get/list만 허용하고 create/update/delete는 닫았다. 사용자가 Firebase 프로젝트 `lost-party`에 배포했다.
- Firebase 의존 Repository/Gateway를 앱 생성자에서 주입할 수 있게 해 미초기화 위젯 테스트 회귀를 제거했다.
- 기존 테스트의 깨진 한글 기대 문자열 두 건을 실제 제품 문구로 복구했다.
- Claim 표적 테스트 6개, 내 계정 기존 테스트, 앱 위젯 테스트, 전체 `flutter test --no-pub` 421개와 `flutter analyze --no-pub`가 통과했다.
- Claim create/delete, 모집 제한, 활성 파티 탈퇴와 pending 종료 및 개인/전체 완료 변경은 제외했다.
- 실기기에서 새 주간 레이드 표현, 기존 계정 기능과 카드 레이아웃이 정상임을 확인했다. 현재 Claim이 없어 체크박스는 모두 미체크이며 읽기 전용으로 조작되지 않는다.

---

## Task-076. 개인 주간 레이드 Claim 기반 B (2026-08-27)

- 작업 브랜치: `codex/weekly-raid-claim-manual`
- 내 계정 체크박스에서 자기 수동 Claim create/delete를 확인창과 함께 실행하고, 처리 중 같은 항목의 중복 입력을 막는다.
- 활성 assignment 또는 pending 신청이 있으면 상태를 변경하지 않고 사유를 안내한다. 자동 탈퇴·신청 종료는 후속 D 범위다.
- Claim 문서 ID를 Rules가 재구성 가능한 `${cycleKey}_${characterId}_${raidId}`로 교정하고, 읽기 mapper도 문서 ID와 내용의 일치를 검증한다.
- Rules는 본인 Player·소유 Character·현재 7일 주차·수동 source·서버 timestamp·허용 필드·결정적 ID를 검증한다.
- Claim과 신청/assignment의 경쟁 생성을 막기 위해 신청·가입·캐릭터 변경 Rules에 Claim 부재 검사를 최소 선반영했다. 전체 UI 오류 매핑은 Task-077 C에서 완성한다.
- 전체 `flutter test` 424개, `flutter analyze`, Firebase Rules dry-run compile이 통과했다. 사용자가 Rules를 배포했다.
- Android 실기기에서 수동 체크·해제, 앱 종료 후 재실행 상태 유지, 참가 중 동일 레이드 모집 생성 차단과 pending 신청 상태의 체크 차단을 확인했다.
- 파티 완료 후 참가자 Claim 자동 생성은 아직 연결하지 않았으며 Task-079 E 범위다.

---

## Task-077. 개인 주간 레이드 Claim 기반 C (2026-08-27)

- 작업 브랜치: `codex/weekly-raid-claim-recruitment-guards`
- Claim이 있는 캐릭터를 동일 `raidId`의 모집 생성·신청·즉시 가입·참가 캐릭터 변경 후보에서 비활성화하고, 각 명령 Transaction과 Rules가 Claim 부재를 최종 재검증한다.
- 실기기 검증 중 발견된 참가 캐릭터 역할 고정 회귀를 수정했다. 파티 내 역할별 자리와 전체 구성이 허용하면 dealer↔support 변경 및 같은 캐릭터의 반대 역할 설정을 허용한다.
- 역할 변경은 membership, active assignment, 모집 `dealerCount`·`supportCount`를 같은 Transaction에서 갱신한다.
- 레이드 상세에 전체 및 파티별 딜러·서포터 현재/정원을 표시한다. 전체는 모집 집계, 파티별 값은 실제 슬롯 배치를 기준으로 한다.
- 전체 테스트 429개와 `flutter analyze`, Rules dry-run을 통과했고 사용자가 Rules 배포와 Android 실기기 검증을 완료했다.
- `main` 반영 커밋: `0f43463`.

---

## Task-078. 개인 주간 레이드 Claim 기반 D (2026-08-27)

- 작업 브랜치: `codex/weekly-raid-claim-completion-flow`
- 내 계정 체크 전에 동일 Character·raidId·cycleKey의 활성 파티와 pending 신청 영향을 조회하고, 파티명·탈퇴·책임자 승계·단독 해산·신청 종료 건수를 확인창에 표시한다.
- 사용자 확인 후 membership 제거, assignment 삭제, 모집 인원·역할·빈자리·revision 갱신, 필요 시 책임자 승계 또는 단독 해산, 동일 레이드 pending 종료, 본인 Claim 생성과 완료 사유 `memberLeft` 이벤트를 한 Transaction으로 처리한다.
- 일반 멤버 탈퇴에서는 기존 책임자 표시 Snapshot을 보존하고, 책임자 탈퇴에서는 다음 membership Snapshot으로 책임자를 승계한다.
- 완료 종료 신청은 `status: superseded`, `resolutionReason: weeklyRaidCompleted`로 기록하며 같은 캐릭터의 다른 raidId 신청은 유지한다.
- Claim 해제는 과거 파티·신청을 복구하지 않는다. 과거 `approved` application이 남아 있어도 현재 membership이 없다면 같은 문서를 새 revision의 `pending`으로 갱신해 동일 방 재신청을 허용한다.
- Rules 배포와 실기기에서 일반 멤버 탈퇴, 책임자 승계, 단독 해산, pending 종료, 취소 무변경, 완료 사유 알림, Claim 해제 후 재신청을 확인했다.
- 구현 커밋 `ec0def8`, 종료 문서 커밋 `efed5a3`으로 `main`과 `origin/main`에 반영됐다.
- 레이드 상세의 일반 멤버 개인 완료 버튼과 파티장 전체 완료·전원 Claim은 Task-079 E 이후 범위다.

---

## Task-079 사전 설계. 반복 파티 전체 완료 취소 확정 (2026-08-27)

- 반복 파티도 일반 파티와 같은 완료 흐름을 따르되 방과 membership은 다음 회차 준비를 위해 유지한다.
- 책임자의 파티 전체 완료는 당시 전원의 `partyOwner` Claim 생성과 active assignment 해제를 회차 완료와 함께 처리한다.
- 반복 파티 책임자는 KST 화요일 22:00 전, 완료 Snapshot과 현재 membership·책임자·역할·슬롯 및 전원의 해당 Claim이 그대로인 경우에만 전체 완료를 취소할 수 있다.
- 취소는 같은 `sourceRecruitmentId + sourceCompletionRevision`의 `partyOwner` Claim 전원 삭제, assignment 전원 복원, 회차 복구와 취소 이벤트를 하나의 Transaction으로 처리한다.
- 완료 후 Claim 직접 해제, 구성·책임자·역할·슬롯 변경 또는 다른 참가 충돌이 하나라도 있으면 부분 병합하지 않고 전체 취소를 거절한다. 다음 회차 준비 변경은 가능하지만 그 시점부터 이전 완료 취소는 포기한다.
- 책임자는 `manual` 또는 일반 멤버의 `partyMember` Claim을 삭제할 수 없다. 수요일 오전 6시 이후에는 이전 회차를 취소하지 않는다.
- 기존의 부분 병합 복원과 `구성 점검 필요` 전환안은 Claim 기반 초기 구현에서 폐기했다.
- 코드는 변경하지 않았으며 Task-079는 전체 완료·전체 취소 각각의 최대 8인 Transaction과 Security Rules 접근 예산을 계산한 뒤 시작한다.

---

## Task-079. 개인 주간 완료 Claim 기반 E (2026-08-27)

- 작업 브랜치: `cursor/task-079-party-complete-claims`
- 책임자 전용 `파티 전체 완료`로 회차 completed·Snapshot 전원 `partyOwner` Claim 멱등 생성·assignment 전원 삭제·완료 이벤트를 한 Transaction에 연결했다.
- 반복 파티 전체 완료 취소는 Snapshot·membership·책임자·역할·슬롯과 해당 `partyOwner` Claim이 그대로일 때만 Claim 삭제·assignment 복원·회차 복구를 원자적으로 처리한다.
- Rules는 leader-only 완료, `partyOwner` Claim create/delete, 완료 시 assignment 삭제, 취소 시 assignment 복원을 추가했다. membership 일치로 character 소유 get 없이 접근 약 12회(한도 20)를 유지한다.
- UI는 `파티 전체 완료` 라벨과 책임자 전용 표시, 계약 안내 문구를 반영했다.
- 표적 테스트 36개와 `flutter analyze --no-pub` 통과. Rules는 `lost-party`에 배포했다.
- 다중 기기 실기기 검증과 기존 completed 방 assignment 정리는 Task-080 F로 이관했다.

---

## Task-081. 내 계정 주간 레이드 표시 설정 (2026-08-28)

- 작업 브랜치: `cursor/task-081-weekly-raid-display`
- Drift schema 9에 캐릭터별 주간 레이드 표시 설정(`displayCount`, `raidIdsCsv`)을 추가하고 Claim과 분리된 로컬 Repository로 저장한다.
- 기본(미설정)은 골드 추천 상위 3개를 입장 레벨 내림차순으로 표시한다. 사용자 설정이 있으면 선택·순서를 존중하고 자동 추천으로 덮어쓰지 않는다.
- 캐릭터별 수정 UI(0~5·선택 수 일치 시 저장·기본값)와 원정대 일괄 표시 개수 적용을 추가했다. 일괄 적용 시 입장 불가 레이드는 캐릭터별로 자동 축소한다.
- 제품 결정을 반영해 접기/더보기 UI는 제거했고, 선택 개수만큼 항상 표시한다. 고정 높이 Grid overflow를 피하기 위해 캐릭터 카드는 내용 높이 `Wrap` 배치로 바꿨다.
- 계정 헤더는 계정명 단독 줄 + 배지·n/n·아이콘 + `원정대 주간레이드수정` 버튼으로 정리했다.
- 표적 테스트(projector·ViewModel·page) 통과. 에뮬레이터 overflow 수정과 실기기 UI를 확인했다.
- 계약 문서 `FIREBASE_PARTY_PRODUCT_FLOW` §17·`WEEKLY_RAID_CLAIM_CONTRACT` §15를 접기 제거·일괄 개수 반영으로 갱신했다.
- `main` 반영 커밋: `46506e9`.

---

## Task-080. 개인 주간 완료 Claim 기반 F (2026-08-28)

- 작업 브랜치: `cursor/task-080-claim-foundation-f`
- 모집 게이트·후보 UI를 서버 Claim만 보도록 정리하고 로컬 `WeeklyRaidClear` OR을 제거했다.
- E 이전 orphan `activeRaidAssignment`는 Claim으로 바꾸지 않고, 모집 completed/disbanded 또는 cycle completed일 때 본인 점유만 Rules·파티 상세 self-heal로 삭제한다.
- 내 계정 주간 레이드 이름 탭으로 체크 토글을 연결했다.
- 반복 파티 완료 후 다음주 참가 캐릭터 변경은 membership만 갱신한다(이번 주 Claim·새 assignment 없음). 변경 시 전체 완료 취소 포기 안내, 취소 거절 시 구성 변경 문구를 넣했다.
- 재완료 때 이전 Snapshot 캐릭터의 같은 방 `partyOwner` Claim orphan을 정리한다. cycle `completionRevision`은 num을 허용한다.
- 정상 완료·1차 실수 복원 실기기를 확인했다. 의도적 복잡 꼬임은 **BUG-007**로 `BUG_REPORTS.md`에 보류 기록하고, 앱 심화 업그레이드 시 대응한다.
- 일반 멤버 `내 캐릭터 완료` 버튼은 별도 단위로 둔다.
- 표적 테스트·analyze 통과. Rules는 사용자가 `lost-party`에 재배포했다.
- `main` 반영: 구현 `3726be8`, 병합 `c45dba2`.
- 다음 실행: Task-082 레이드 모집에서 내 모집 제외.

---

## Task-082. 레이드 모집에서 내 모집 제외 (2026-08-28)

- 작업 브랜치: `cursor/task-082-exclude-own-recruitments`
- 공개 Firestore 쿼리는 유지하고, data 계층에서 `leaderPlayerId` 또는 `memberPlayerIds`에 현재 Player가 있는 `active` 방을 제외한다. `memberPlayerIds`는 Domain에 새로 노출하지 않는다.
- 신청만 `pending`인 방은 공개 목록에 남긴다. 필터 전 페이지 크기 20을 유지하고, 필터 후 빈 첫 화면은 시작·갱신당 최대 3페이지까지 자동 보충한다.
- 빈 목록 문구로 공개 탐색과 레이드 현황의 역할을 안내한다. Rules는 변경하지 않는다.
- 표적 테스트·analyze 통과. 실기기(1대)에서 내가 만든 방 제외, pending 신청 유지, 현황 목록 정상을 확인했다. 다른 Player 방의 확정 멤버 제외는 2인 환경이 없어 실기기 미실시(같은 함수 테스트로 고정).
- `main` 반영: `6597d7a`.
- 다음 실행: Task-083 운영자 계정 권한 기반 설계.

---

## Task-083. 운영자 계정 권한 기반 설계 (2026-08-28)

- `OPERATOR_AUTHORIZATION_CONTRACT.md`를 추가해 `PlayerId` 기반 운영자 지정과 일반 사용자 권한 분리를 확정했다.
- 사용자가 게임 계정별 짧은 코드를 인게임 일반 채팅에 입력하고 전체 화면을 오픈카톡으로 제출하는 운영자 수동 인증 흐름을 정했다.
- 운영자 판정은 승인·취소·인증 금지로 나누고 Player·대상 GameAccount별 요청 횟수를 판단 자료로 사용한다.
- 기존 active 소유자가 있으면 24시간 재인증 기회를 주며, 방어 성공 시 신규 요청자의 해당 계정 인증을 금지하고 무응답이면 추가 운영 승인 없이 자동 이전한다.
- Spark에는 예약 실행 서버가 없으므로 만료 결과는 자동 확정하되 실제 이전 Transaction은 기한 후 최초 안전한 앱·운영자 접근에서 멱등 반영한다.
- `players.lastSeenAt` 최신값만 새 앱 실행당 한 번 기록하고 운영자 사용자 목록은 접속 기록 없음·오래된 접속순으로 조회한다.
- 로컬 전용 대표 캐릭터·미인증 계정은 추가 업로드하지 않으며 서버에서 대표를 정할 수 없으면 `대표 캐릭터 지정 안 됨`으로 표시한다.
- 사용자 삭제·삭제 대기·강제 삭제와 앱 재설치 우회 차단은 보류했다.
- 다음 구현: Task-084 운영자 권한·마지막 접속 기반.

---

## Task-084 후속 설계. 대표 Character 서버 동기화 (2026-08-28)

- 실기기에서 운영자 `사용자 확인` 진입과 목록 표시를 확인했다.
- 기존 구현은 운영자 read model의 `representativeCharacterName`을 null로 두고 대표 선택은 Drift에만 저장해, 대표 Character가 있는 사용자도 `대표 캐릭터 지정 안 됨`으로 표시됐다.
- active 서버 소유 관계가 있는 계정은 `playerGameAccounts`에 서버 `representativeCharacterId`와 서버 갱신 시각을 동기화한다. 로컬 정수 ID와 미인증 계정 데이터는 업로드하지 않는다.
- 대표 변경은 GameAccount별 5분에 한 번만 성공하며 UI와 Firestore Rules 양쪽에서 제한한다. Rules는 현재 active 소유자, 같은 계정의 active Character, 값 변경, `request.time`을 검증한다.
- 같은 Character 재선택과 저장 중 연속 터치는 쓰기를 만들지 않고, 서버 저장 성공 뒤에만 로컬 대표 선택을 반영한다. 오프라인 변경은 거절한다.
- 기존 로컬 대표는 대응하는 active 서버 Character가 있을 때 계정당 한 번 보강하고 그 시점부터 5분 제한을 적용한다.
- 운영자 목록은 대표가 여러 계정이면 `Character명 외 N개`, 상세는 GameAccount별 대표 Character를 표시한다.
- `RepresentativeCharacterSyncGateway`와 Firestore 구현을 추가해 active 소유 계정의 대표 Character를 서버에서 읽고 Transaction으로 변경한다.
- 내 계정 진입 시 계정별 한 번 로컬 대표를 서버에 보강하거나 기존 서버 대표를 로컬에 조정한다. 캐릭터 관리에서는 서버 저장 성공 뒤에만 로컬 대표를 변경한다.
- Rules는 현재 active 소유자, 같은 GameAccount의 active Character, 실제 값 변경, `request.time`, 이전 변경 후 5분 경과를 검증한다. 해당 Rules는 2026-08-28 Firebase `lost-party`에 배포했다.
- UI는 저장 중 중복 터치와 쿨다운 중 변경을 막고 남은 시간을 표시한다. 운영자 목록은 `Character명 외 N개`, 상세는 계정별 대표 Character를 표시한다.
- 전체 `flutter test` 464건과 `flutter analyze`를 통과했다.
- 실물 기기의 최초 보강·5분 차단·재실행 유지·운영자 목록·상세·일반 Player 차단 확인은 사용자가 수행한다. AI는 확인 항목만 전달하고 기기 조회·설치·실행을 하지 않는다.
- Task-084 운영자 기반 구현은 `d31ce01`, 대표 동기화 준비 문서는 `a7ee7ed`에 반영됐다. `a7ee7ed`에서 `codex/task-084-representative-character-sync`를 생성했다.
- 대표 Character 동기화 구현을 `f15c1b6`으로 작업 브랜치에 커밋했다. 사용자 지시에 따라 브랜치는 실물 기기 테스트와 분리해 `main`에 병합·푸시하고, 해당 테스트는 Task-085 시작 전 필수 게이트로 유지한다.

---

## Task-084b. 대표 초회 보강과 사용자 변경 분리 (2026-08-29)

- 작업 브랜치: `cursor/representative-seed-reconcile`
- 초회 보강은 `representativeCharacterId`만 쓰고 `updatedAt`을 남기지 않아 5분 제한을 시작하지 않는다.
- 사용자가 캐릭터 관리에서 대표를 바꿀 때만 `updatedAt`을 기록하고 5분을 적용한다.
- Drift schema 10에 계정당 서버 대표 맞춤 기록을 추가해, 내 계정 재진입·탭 전환에서 Firestore GET/SET을 생략한다.
- Rules에 `validRepresentativeCharacterSeed`를 추가했다. 사용자가 Firebase `lost-party`에 재배포했다(2026-08-29).
- 표적 테스트와 `flutter analyze`를 통과했다.
- 실기기: 5분 타이머 UI는 정상. 탭 전환 통신은 로그를 보지 않아 화면 확인을 생략하고, 로컬 맞춤 기록 skip 테스트로 대체했다.
- Git 종료: 기능 브랜치를 `main`에 병합하고 원격과 맞춘다.

---

## Task-085. 수동 인증 요청과 운영자 1차 판정 (2026-08-29)

- 작업 브랜치: `cursor/task-085-manual-verification`
- 사용자는 설정에서 게임 계정·증명 캐릭터를 고르고 `LP-` 코드를 받아 인게임 일반 채팅 전체 화면을 운영자 오픈카톡으로 보낸다. 스크린샷은 Firestore에 올리지 않는다.
- 운영자 `수동 인증 확인`에서 대기 요청을 오래된 순으로 보고 승인·취소·인증 금지를 처리한다.
- 승인 시 Lost Ark API roster를 다시 조회하고, 기존 active 소유자가 없을 때만 GameAccount 전체 소유를 요청자에게 확정한다.
- 085 결정: 기존 소유자가 있으면 `existingOwner`로 거절하고 `awaitingOwnerResponse`는 열지 않는다.
- Rules·인덱스를 추가했고, 사용자가 Firebase `lost-party`에 배포했다(2026-08-29).
- 코드 발급 시 없는 인증 금지 문서 get이 permission-denied로 거절되던 문제를 고쳤다. Rules 재배포가 필요하다.
- 내 요청 목록이 `createdAt` 복합 인덱스 구독 실패로 코드가 사라지던 문제를, 단일 필드 조회 후 클라이언트 정렬로 고쳤다.
- 재발급 UI는 제거했다. 새 코드는 요청 취소 후 다시 발급한다.
- 수동 인증 안내에 운영자 오픈채팅방 링크를 연결했다.
- 진행 중 요청은 로컬 게임 계정(원정대) 단위로만 하나 허용한다. 같은 계정의 다른 캐릭터 중복 요청은 거절한다.
- 발급 문서에 null 필드를 넣어 Rules가 거절하던 문제와, 목록 구독이 매 빌드마다 끊기던 문제를 고쳤다. 취소된 요청은 내 요청 목록에 올리지 않는다.
- 운영자 대기 목록은 복합 인덱스 없이 status만 조회한 뒤 오래된 순으로 정렬한다.
- 표적 테스트와 `flutter analyze --no-pub`을 통과했다.
- 커밋은 사용자 지시 시.

---

## Task-086. 기존 소유자 방어·자동 이전·강제 인증 (2026-08-29)

- 작업 브랜치: `cursor/task-086-owner-defense`, 기능 커밋 `8c649ad`
- 구현: 분쟁 상태(`awaitingOwnerResponse`·`defended`·`transferred`), 분쟁 개시, 방어 승인, 기한 후 자동 이전, 운영자 강제 인증, 분쟁 알림 이벤트, 운영자 UI
- Rules·인덱스: `lost-party`에 여러 차례 배포. 최종 Rules는 `validManualVerificationOperatorWrite` 단일 진입점
- Rules 차단 원인: 선택 필드 `defenseOfRequestId`가 없는 일반 요청에서 필드를 직접 읽어 Rules 평가 오류가 발생했다. 존재 여부를 먼저 검사하도록 수정했다.
- 승인 결과를 활성 요청 목록 필터 전에 처리해 요청자 로컬 GameAccount·Character 서버 ID를 연결하고, 같은 GameAccountId의 누락 매핑도 보강한다.
- 수동 인증 화면에 완료 후 재진입·별도 완료 알림 없음·반복/부정확 요청 제한 가능성을 빨간 경고로 표시한다.
- `방어 실패`를 추가했다. 방어 요청은 `ownerDefenseFailed`로 종료하고 신규 요청자에게 즉시 이전하며 기존 소유자에게 자동 인증 금지는 적용하지 않는다.
- 로컬: 전체 `flutter test --no-pub` 488건 통과, `flutter analyze --no-pub` 통과
- 실기기:
  - **동작:** 취소, 일반 승인, 분쟁 개시, 운영자 거절, 방어 승인, 방어 실패, 강제 인증
  - **동작:** 즉시 소유권 이전, 기존 소유자의 레이드 Character 후보 제외, 거절·방어 승인 시 기존 권한 유지
  - **미검증:** 실제 24시간 무응답 후 자동 이전
- BUG-008은 수정·Rules 배포·실기기 확인 후 종료. 해결 경과는 [`TASK-086-OPERATOR-WRITE-BLOCKER.md`](TASK-086-OPERATOR-WRITE-BLOCKER.md)에 보존한다.

---
# 2026-08-30 그룹 제품 흐름 문서화

- 하단 4개 탭을 유지하며 설정 탭을 그룹 탭으로 교체하고, 설정은 내 계정 상단에서 진입하는 방향을 확정했다.
- 그룹 생성·대표 캐릭터·초대·가입 신청·초대코드 즉시 가입, 그룹장/일반 멤버 권한과 승계, 단일 그룹 레이드와 공개 범위 전환, 복수 그룹 목록 필터를 제품 문서에 정리했다.
- 그룹 이력은 `groupId + occurredAt + expireAt`으로 3개월 보관하고, 1개월 미활동 표시·soft delete 후 28일·Spark 운영자 수동 정리 방향을 기록했다.
- 같은 데이터 정리 기반을 일반 레이드와 사용자 데이터에 후속 적용하되 현재 코드·Rules에는 반영하지 않는다.
- 기준 문서: [`../product/GROUP_PRODUCT_FLOW.md`](../product/GROUP_PRODUCT_FLOW.md)

---

## Task-11. 그룹 생성·가입 Firestore/Rules 계약 분리 (2026-08-31)

- 확정된 그룹 제품 정책을 [`../architecture/FIRESTORE_GROUP_MEMBERSHIP_CONTRACT.md`](../architecture/FIRESTORE_GROUP_MEMBERSHIP_CONTRACT.md)로 분리했다.
- 그룹 membership, 활성 관계 요청, 누적 신청 횟수와 신청 금지를 모두 `groupId + playerId` 단위로 고정했다. Character는 검색·표시 Snapshot과 향후 레이드 선택에만 사용한다.
- `groups`, 멤버·요청·통계·금지 하위 문서, Player별 membership state·관계 Projection, 정확한 초대코드 조회 경로를 정의했다.
- 그룹 50명과 Player별 50개 그룹 제한을 그룹 인원·Player 그룹 ID 요약·membership의 같은 Transaction 및 Rules `getAfter()`로 강제한다.
- 그룹 생성, 초대·신청, 수락·승인·거절·금지, 초대코드 생성·폐기·즉시 가입의 상태 전이와 동시성 실패 조건을 확정했다.
- Task-11에서 탈퇴·추방·이전·해산·그룹 레이드·알림·공지는 제외하고 해당 쓰기를 Rules가 미리 허용하지 않도록 했다.

---

## Task-11. 그룹 생성·가입 구현과 부분 실기기 (2026-08-31)

- 작업 브랜치: `cursor/task-11-group-membership`, 기능 커밋 `b673fdb`
- 구현: `lib/features/group` Domain/DTO/WritePlan/Firestore Repository·Rules·인덱스, 4번째 탭 `그룹`, 설정은 내 계정 톱니 진입
- Unit 1~5: 생성·내 그룹·검색·상세, 초대·신청·수락/거절/취소, 그룹장 승인·거절·금지, 초대코드 생성·폐기·공개·즉시 가입, 오류 매핑·요청 현황
- 자동 검증: 그룹 표적 테스트·`flutter analyze --no-pub` 통과 (구현 당시 그룹 137건 수준)
- 실기기 확인(사용자):
  - **동작:** 초대코드 생성, 폐기, 멤버에게 코드 표시 토글
  - **동작:** 코드로 즉시 가입, 그룹 인원 2명 표시
  - **동작:** 생성 시각·마지막 활동 시각 표시
  - **미구현 UI:** 그룹원 목록(카드·상세). Rules는 그룹원 list 허용이나 화면 미연결
  - **계약 제외:** 탈퇴 버튼 없음 → 연속 시나리오 검증이 막힘
- Emulator §12.4–12.5 동시성·Codex 재검토·`main` 병합은 미실시
- 다음 실행: 멤버 목록 UI + 일반 멤버 탈퇴(실기기 연속 검증용), 이후 재검토·병합

---

## Task-11a. 그룹 멤버 목록·탈퇴·표시 Snapshot (2026-08-31)

- 작업 브랜치: `cursor/task-11-group-membership` (Task-11 `b673fdb` 위, 문서·커밋 시점 미병합)
- 구현 범위:
  - 그룹 상세 **멤버 목록 UI**: 그룹장 우선·`joinSequence` 정렬, 카드에 직업·아이템 레벨·전투력
  - 멤버 탭 → 인증 캐릭터 bottom sheet
  - **일반 멤버 탈퇴**: `GroupLeaveWritePlan`, Repository leave 명령, Rules(로컬)
  - **표시 Snapshot**: `displayClassNameSnapshot`, `itemLevelSnapshot`, `combatPowerSnapshot` — 생성·가입·코드 가입 시 저장
  - **본인 Snapshot self-refresh**: 그룹 상세 진입 시 로컬 캐릭터와 비교해 membership만 갱신 (`validGroupMemberSelfSnapshotRefresh`)
  - **전투력 표시**: 타 그룹원은 서버 membership Snapshot을 읽음. 로컬 roster만으로 UI 보강하던 경로 제거
  - Read: `GroupMemberDisplayBuilder`, `loadGroupMembers` + character doc batch get
  - Write lookup: `GroupLocalMemberDisplayLookup` (가입·refresh 쓰기 전용)
- 자동 검증: 그룹 표적 테스트·widget 테스트 포함 ~159건 통과 (구현 시점), `flutter analyze` 통과
- **1차 종료:** 사용자 지시로 `main` 병합·푸시. 전체 기획·설계 재검토 기간에 들어간다.
- **열린 부채:**
  - Firestore Rules **전체 deploy 실패(503)** — leave·self-refresh Rules가 운영에 없을 수 있음
  - Task-11a 실기기(멤버 전투력·타인 Snapshot·탈퇴·재가입) 미실시
- 제외 유지: 그룹장 이전·해산·추방·그룹 레이드·알림·공지

---

## Task-11-R. Firestore Rules 복잡도 차단 (2026-08-31)

- 증상: `firebase deploy --only firestore:rules --project lost-party` 시 전체 Rules (~159KB, ~3470줄)에서 **503/409** 등 API 실패 반복
- 프로브: 검증 함수 본문 ~101개를 `return false` 스텁, `match`·경로 helper 유지 → **~76KB(47.9%)에서 compile·release 성공** (~13초)
- 결론: 문법 오류가 아니라 **단일 Rules 파일 컴파일·업로드 복잡도 한도**에 가깝다. Task-11 leave·Snapshot refresh 추가분도 동일 제약
- 운영 주의: 2026-08-31 저녁 **절반 프로브 Rules가 `lost-party`에 배포됐을 수 있음** → 대부분 쓰기 거부. 전체 원본 재배포는 503으로 실패 확인(사용자)
- 상태: Task-11·11a **코드는 `main`에 보존**. Rules 축소는 **재설계 후 열린 기술 부채**로 유지
- 상세: [`TASK-11-FIRESTORE-RULES-COMPLEXITY.md`](TASK-11-FIRESTORE-RULES-COMPLEXITY.md)

---

## Task-11·11a 1차 마무리와 재설계 대기 (2026-08-31)

- 사용자는 Task-11·11a를 **1차 완료**로 보고 전체 기획·설계를 다시 가져온다.
- Git: `cursor/task-11-group-membership` → `main` 병합·원격 푸시.
- 구현 AI는 새 설계 지시 전까지 추가 기능 구현을 시작하지 않는다.
- 재설계에 반드시 남길 항목: Rules 복잡도(503), 운영 프로브 Rules 잔존 가능, 11a 실기기 미완, Task-12 후보.

## Rules 복잡도 개선 1차 (2026-08-31)

- 별도 `codex/rules-complexity-reduction` 브랜치에서 원본 백업 후 탈퇴 그룹 탐색을 native List 연산으로 바꾸고 표시 Snapshot 갱신의 중복 비교를 제거했다.
- 필수 필드 존재와 허용 변경 필드, 호출자·식별자·값 타입 검사를 유지했다. 앱·스키마 변경 없이 Rules 소스 158,836 → 143,799 bytes.
- 관련 정적 계약 테스트와 Emulator 회귀 시나리오를 보강했다. 최종 표적 Flutter 테스트 33개 통과. 실제 Emulator 검증은 최소 Rules 대조 검사부터 로딩 503으로 막혀 미완료다.
- 사용자 지시에 따라 개선 내용만 기능 브랜치에 커밋한다. 배포·병합·푸시는 하지 않으며 원본 백업은 로컬에 보존한다.

## Rules 추가 개선 시작점·실행 계획 기록 (2026-08-31)

- 1차 개선 커밋 `25f88ff` 이후 사용자가 전체 Rules 배포를 지시했다. `lost-party:test` 컴파일 검사에서 503으로 실패해 새 Rules는 운영 반영되지 않았다.
- 이 커밋을 추가 개선의 기준 코드로 고정하고 같은 전용 브랜치에서 문서 계획을 기록한다. 이번에는 Rules·앱 코드 변경 없음.
- R0 검증 환경, R1 그룹 가입, R2 Player 요약·목록, R3 수정 검사, R4 이벤트, R5 명령 대상 명시, R6 표시/권한 데이터 분리 순으로 변경 대상·검증 기준을 정의했다. R5~R6은 설계 검토 후 별도 착수한다.
- 각 단계는 정상/거절 동작과 기능 보존 근거를 기록하고 독립 커밋으로 관리한다. 시험용 Rules의 운영 배포, 사용자 백업 변경, 무단 병합·푸시는 제외한다.
# 2026-09-02 활동 Character와 레이드 현황 필터 계약

- 인증 원정대 전체와 LOSTPARTY에서 실제 사용하는 활동 Character를 분리하기로 확정했다. 활동 Character는 최소 1명이고 대표 Character를 반드시 포함하며, 기존 참가 Character 비활성화는 새 후보만 제한하고 membership·Claim·완료 기록을 유지한다.
- 캐릭터 관리 화면을 전체 원정대 활동 선택 → 선택 Character 대표·순서 → 메인 표시 개수 → 일괄 저장 구조로 재정의했다. 대표 해제와 마지막 1명 해제를 막고 UI·Repository·Rules에서 중복 검증한다.
- 진행 중 레이드 필터의 공개 조건, 레이드·난이도 조합, 그룹원·Character 계층 선택, 사용자 내부 OR·사용자 간 AND, 실시간 결과 개수와 20개 페이징 방어 계약을 확정했다.
- 그룹 전용 자격 상실 정리는 그룹장뿐 아니라 정상 참가 그룹원도 요청할 수 있고 서버가 요청자와 대상을 재검증하는 것으로 확정했다.
- 구현보다 설계를 먼저 고정했으며 Flutter 코드는 변경하지 않았다. 상세: [`../architecture/ACTIVITY_CHARACTER_AND_RAID_FILTER_CONTRACT.md`](../architecture/ACTIVITY_CHARACTER_AND_RAID_FILTER_CONTRACT.md).

---

# 2026-09-02 첫 릴리즈 전 Git 작업 방식 확정

- 첫 릴리즈 전 통합 기준 브랜치를 `dev`로 정했다.
- 모든 작업은 원격과 동기화한 최신 `dev`에서 작업 단위별 브랜치를 만들어 시작한다.
- 첫 릴리즈 전에는 PR을 사용하지 않고, 검증된 작업 브랜치를 `dev`에 직접 병합한 뒤 `origin/dev`에 푸시한다.
- `main`은 첫 릴리즈 준비 전까지 안정 기준선으로 유지하며, 릴리즈 시점의 반영 절차는 별도로 결정한다.

---

# 2026-09-03 활동 Character 실기기 확인과 후속 보완 범위

- Android 실기기에서 활동 Character 선택·저장과 선택 Character만 레이드 모집 생성 후보로 노출되는 흐름을 확인했다.
- 기존 Character 순서 변경·대표 Character 변경과 완료 처리 표시 체크가 정상 작동했고, 전체 활동 Character 흐름을 정상으로 판단했다.
- 그룹 정보에서 본인은 활동 Character만 보이지만 다른 그룹원은 인증 Character 전체가 보이는 문제를 확인했다.
- 코드 대조 결과 다른 Player의 owner-only `characterActivity`를 읽지 못해 인증 활성 Character 전체를 반환하는 현재 대체 경로가 원인이다. 활동 Character 최소 표시 Projection을 완성하는 후속 작업으로 분리했다.
- 레이드 현황 필터 후속 요구사항으로 초기화 버튼, `그룹 공개만` 상태의 조건부 참여 그룹원 UI, 긴 목록에서도 잡기 쉬운 상단 드래그 닫기 영역을 기록했다.
- 기존 자동 검증 결과 `flutter analyze --no-pub`와 전체 `flutter test --no-pub` 792개 통과는 유지한다. 이번 변경은 문서뿐이므로 Flutter 검증을 반복하지 않는다.

---
## 2026-09-04 Character 자동 갱신 D — 파티 교류 적용

- 모집 생성과 참가 신청·즉시 참가·참가 Character 변경 후보 로딩에 사전 갱신을 연결했다. 반복 파티 다음 회차 변경도 같은 경계를 쓴다.
- 명령 직전에 Character ID와 generation을 확인하고, 갱신 역할과 최소 아이템 레벨·전투력을 재검증해 payload를 다시 만든다.
- 실패 시 기존 정상 Snapshot이 있으면 사용자 확인 후 계속하고, 없으면 차단한다. 갱신과 명령은 기존 저장/제출 잠금 안에서 실행해 중복 명령을 막는다.
## 2026-09-04 Character 자동 갱신 E — 그룹 교류 적용

- 그룹 생성·가입 신청·초대코드 가입 후보에 본인 활동 Character 사전 갱신을 연결하고, 명령 직전에 선택 Character와 generation을 다시 확인한다.
- 직접 초대 수락은 초대 Snapshot의 본인 Character명과 로컬 인증 Character를 대조한 뒤 최신화를 보장한다. 일치하는 본인 Character가 없으면 수락을 차단한다.
- 그룹 상세 표시 보강 전에 본인 활동 Character만 갱신한다. 타 그룹원의 API는 조회하지 않고 기존 membership 읽기 계약을 유지한다.
- 나이스단 제외, API 실패 시 기존 정상 Snapshot 확인, 역할 변경 감지와 버튼 연타 방지는 파티와 동일한 사용자 경계를 사용한다.
## 2026-09-05 앱 실행 1회 갱신 상세 기준과 내 계정 UI 후속 범위(문서만)

- 앱 실행 갱신 대상은 인증된 active 계정의 등록 Character 중 원정대 이탈이 아니고 아이템 레벨 1700 이상인 Character로 확정했다. 1700은 나이스단과 앱 실행 갱신이 공유하는 공통 정책 값으로 두며 기능별로 중복 하드 코딩하지 않는다.
- 나이스단 분류·허용 설정은 현재 구조를 유지한다. 직업별 표기는 자동 테스트만으로 완료 처리하지 않고 다양한 실제 사용자 계정에서 캐릭터별 역할·아이템 레벨·전투력·보석 표시를 확인한다.
- 내 레이드 현황의 초기 Snapshot·기록·알림 로딩과 첫 렌더링 뒤 자동 갱신을 시작해 첫 화면 통신과 경쟁시키지 않는다. 앱 수명당 1회만 실행하고 내 계정 탭에 비차단 통신 인디케이터를 표시한다.
- 내 계정 첫 화면은 토큰 등록 안내/버튼과 게임계정 인증을 한 줄로 축소하고, Character명 입력과 계정 데이터 불러오기를 한 줄로 합친다. 부계정 추가는 작은 보조 액션으로 변경해 Character 현황의 첫 화면 점유율을 높인다.
- 이번 변경은 문서 최신화이며 기능 코드는 수정하지 않았다.
## 2026-09-05 앱 실행 1회 갱신 A — 공통 사용 레벨과 대상 정책

- 아이템 레벨 1700 포함 경계를 `CharacterUsageLevelPolicy` 한 곳으로 분리하고 기존 `NiceGroupPolicy`가 이를 사용하도록 변경했다.
- 앱 실행 갱신 후보용 `StartupCharacterRefreshEligibilityPolicy`를 추가했다. active 소유권 계정의 서버 인증·원정대 소속·1700 이상 등록 Character를 본·부계정 구분 없이 반환한다.
- 1699.99/1700 경계, null 레벨, 본·부계정 포함, 미인증·원정대 이탈·비활성 소유권 제외 테스트와 기존 나이스단·관리 화면 회귀 24개가 통과했다.
- 전체 `flutter test --no-pub` 878개가 통과했고 analyze에는 이번 변경의 신규 문제가 없다.
- 교류 시점 호출 제거, 앱 수명당 1회 조정기, 첫 화면 로딩 장벽과 UI는 후속 B~E 범위로 남겼다.
## 2026-09-05 앱 실행 1회 갱신 B — 기존 교류 갱신 안전 제거

- 모집 생성·지원·즉시 참가·참가 Character 변경 후보의 prefetch와 명령 직전 `ensureFresh`를 제거했다. 반복 파티 다음 회차 변경도 기존 membership 명령만 실행한다.
- 그룹 생성·가입 신청·직접 초대 수락·초대코드 가입·그룹 상세의 Armory 자동 갱신을 제거했다. 기존 Snapshot 계속 사용 확인 다이얼로그, 역할 변경 안내와 교류 전용 generation 상태도 삭제했다.
- 파티·그룹 전용 갱신 래퍼와 UI guard를 삭제하고 Router 주입을 제거했다. 공통 Coordinator, 나이스단 정책, 역할별 로컬 Snapshot과 서버 최소 Snapshot 동기화 구현은 C에서 재사용할 자산으로 보존했다.
- 모집 생성은 저장된 선택 역할 Snapshot으로 최소 아이템 레벨·전투력을 명령 직전에 다시 검사한다. 기존 인증·소유권·파티 구성·revision·중복 실행 방지는 유지했다.
- 교류·명령 표적 회귀 79개와 전체 `flutter test --no-pub` 877개가 통과했다. analyze에는 이번 변경의 신규 문제가 없다.

## 2026-09-05 앱 실행 1회 갱신 C — 앱 수명당 1회 조정기

- `StartupCharacterRefreshOrchestrator`를 추가했다. 동일 인스턴스의 `runOnce()`는 최초 Future를 계속 재사용하므로 중복 호출되어도 계정 로드와 Character 갱신은 앱 수명당 한 번만 실행된다.
- 인증 Player 세션이 있고 A 정책을 통과한 active 소유권·서버 인증·원정대 소속·1700 이상 본·부계정 Character만 대상으로 삼는다. 인증 세션이 없으면 로컬 계정과 설정도 읽지 않고 종료한다.
- 기존 `NiceGroupPolicy`와 Player별 로컬 허용 설정을 적용한다. 나이스단 OFF 요청은 Coordinator의 제외 경로로 전달해 Armory 통신 없이 기존 수동 Snapshot을 유지하고, ON이면 일반 prefetch를 실행한다.
- 기존 `CharacterAutoRefreshCoordinator`를 `CharacterAutoRefreshGateway` 계약으로 노출해 최대 동시 요청 3개, 역할 판별·역할별 Snapshot, 서버 최소 Snapshot 동기화 구현을 그대로 재사용한다.
- Character별 결과·예외를 독립 수집하고 실행 상태에 전체·완료·실패 수를 발행한다. 일부 실패나 계정 로드 실패는 호출자에게 던져 앱 진입을 막지 않으며 확인 팝업도 만들지 않는다.
- C 조정기·기존 Coordinator·대상·나이스단 정책 표적 테스트 22개와 전체 `flutter test` 884개가 통과했다. `flutter analyze`에는 이번 변경의 신규 문제가 없고 기존 21개 항목만 남아 있다.

## 2026-09-05 앱 실행 1회 갱신 D — 첫 화면 장벽과 내 계정 탭 인디케이터

- `RaidStatusPage`가 진행 중·신청 중 목록의 첫 Snapshot 성공 또는 오류, 완료 기록 초기화, 읽지 않은 알림 수 조회, 첫 프레임 렌더링을 모두 확인한 뒤 초기 로딩 완료 콜백을 한 번만 호출하도록 연결했다.
- 완료 기록이나 알림 수 조회가 실패해도 로그만 남기고 장벽은 최종 완료된다. 시작 Character 갱신은 이 콜백 뒤 비차단으로 실행되어 레이드 현황 로딩이나 앱 진입을 기다리게 하지 않는다.
- Router에서 C 조정기와 기존 Coordinator·서버 최소 Snapshot 동기화를 실제 런타임 의존성으로 조립했다. 같은 조정기 인스턴스를 레이드 장벽과 앱 셸이 공유하므로 탭 이동·재진입·수동 새로고침으로 재실행되지 않는다.
- 앱 셸은 조정기 상태를 구독해 실행 중에만 하단 두 번째 `내 계정` 탭 아이콘에 작은 원형 인디케이터를 표시한다. 완료와 일부 실패 모두에서 종료하며 팝업은 추가하지 않았다.
- 첫 Snapshot 성공·오류·콜백 1회, 인디케이터 시작·종료, C 실행 계약과 앱 내비게이션 표적 테스트 42개가 통과했다. 전체 `flutter test` 887개가 통과했고 `flutter analyze`에는 신규 문제가 없이 기존 21개 항목만 남아 있다.

## 2026-09-05 앱 실행 1회 갱신 E — 내 계정 첫 화면 UI 압축

- 기존 세로형 API 토큰 상태 패널과 전체 폭 게임계정 인증 버튼을 하나의 compact 행으로 합쳤다. API 토큰 등록 여부 안내, 등록/관리 버튼, 계정 인증 버튼이 같은 줄에 있으며 기존 설정 경로와 tooltip을 유지한다.
- Character명 입력과 계정 데이터 불러오기를 같은 행에 배치하고 버튼 문구를 `불러오기`로 줄였다. 계정이 있으면 `부계정 추가`는 같은 행의 작은 outlined 아이콘 버튼으로 표시한다.
- 상단 작업 영역의 큰 세로 간격과 전체 폭 버튼 3개를 제거해 저장된 계정·Character 현황이 더 위에서 시작하도록 했다. 조회 검증·네트워크 busy·토큰 누락·부계정 dialog 동작은 변경하지 않았다.
- 360px 모바일 폭에서 두 compact 행의 구성 요소와 오버플로 부재를 검증했다. 내 계정·ViewModel·앱 내비게이션 표적 테스트 20개와 전체 `flutter test` 888개가 통과했고 analyze에는 신규 문제 없이 기존 21개 항목만 남아 있다.

## 2026-09-05 앱 실행 1회 갱신 F — 자동 검증 완료, 실기기·실계정 대기

- 공통 레벨·대상·나이스단·Coordinator·시작 1회 조정기·레이드 장벽·인디케이터·내 계정 UI를 묶은 표적 테스트 86개와 전체 `flutter test` 888개가 통과했다. `flutter analyze`는 신규 문제 없이 기존 21개 항목만 보고한다.
- 정적 호출 대조에서 앱 코드의 `CharacterAutoRefreshCoordinator.ensureFresh` 호출은 제거된 상태이고, 자동 `prefetch` 호출은 `StartupCharacterRefreshOrchestrator` 한 곳에만 남아 있다. 파티·그룹 교류 화면 자동 갱신은 재연결되지 않았다.
- `adb devices -l` 결과 연결 기기가 없었다. `flutter devices`는 출력 없이 대기해 종료했고 `flutter build apk --debug`도 두 차례 실제 Java/Dart 빌드 프로세스와 출력 없이 대기해 성공·실패 판정을 하지 않았다.
- Android 실기기의 첫 화면 로딩·내 계정 탭 인디케이터·탭 이동/백그라운드 복귀 중복 실행 없음·압축 UI 확인과, 바드·홀리나이트·발키리·도화가를 포함한 여러 실제 사용자 계정의 역할·아이템 레벨·전투력·보석 표기 검증은 남아 있다. 자동 검증만으로 전체 완료 처리하지 않는다.

## 2026-09-05 후속 개선 H~K 계획 — 문서만 갱신

- 사용자 요청에 따라 기능 코드는 수정하지 않고 `dev`에서 후속 작업만 문서화했다. 디바이스 테스트 결과는 보류이며 테스트가 필요하다고 명시했다.
- H는 내 계정·그룹 대표 전투력을 마지막 갱신 역할이 아닌 선호 포지션의 역할별 Snapshot으로 고정한다. 파티의 선택 역할 Snapshot은 유지한다.
- I는 내 계정 상단/메인 계정 사이 여백, 제목 우측 원형 새로고침 아이콘, 확인 Alert, 나이스단 제외 전체 갱신, 진행 수 표시를 다룬다. 쿨타임은 갱신 완료 후 10초이며 제한 중 Alert에 빨간색 카운트다운과 비활성 확인 버튼을 표시한다.
- J는 신규 초대코드를 6자리로 줄이고 기존 20자리 호환을 유지한다. 재실행·방장 위임 후 표시를 복원하고 코드 재입력 없이 확인 Alert만으로 폐기한다. 초대코드는 단순 그룹 가입 수단으로 취급한다.
- J 구현 완료: 신규 코드는 혼동 문자를 제외한 6자리로 생성하고 기존 20자리는 파싱·가입 호환을 유지한다. 그룹의 선택 필드 `activeJoinCode`와 코드 문서를 Transaction으로 함께 관리해 앱 재실행·그룹장 위임 뒤에도 표시하며, 확인 Alert만으로 폐기한다. 표적 테스트 74개 통과, 전체 892개 중 891개 통과·비관련 기존 테스트 1개 실패(해당 표적군 독립 실행 통과), analyze 기존 21개를 확인했다. 디바이스 검증은 H~K 통합 단계로 보류한다.
- K는 진행 중 레이드 카드에 가입 신청·추방·참가·참가 Character 변경의 방별 unread 수를 표시한다. 방 상세 진입 즉시 읽음 처리하며 `파티 구성` 우측 팝업은 현재 사용자에게 전달된 방별 이벤트 히스토리만 보여주고 이동 동작은 제공하지 않는다. 기존 `recruitmentId` 연결을 사용하므로 서버 구조 변경은 하지 않는다.
- K 구현 완료: 기존 Drift 알림 receipt를 방별로 분류해 네 이벤트를 전역 알림함에서 제외하고 진행 중 카드 좌상단 숫자 배지로 표시한다. 상세 진입 즉시 해당 방 네 유형만 읽음 처리하며 `파티 구성` 우측 아이콘에서 이동 없는 사용자별 히스토리 팝업을 제공한다. 서버·Rules·인덱스 변경은 없다. 핵심 표적 66개와 전체 896개가 통과했고 analyze 기존 21개를 확인했다. 이전 단일 실패는 J 해산 안내의 오래된 테스트 문구를 현재 UX로 정정해 해소했다. 디바이스 검증은 H~K 통합 체크리스트로 보류한다.
- 이번 커밋에서는 자동·디바이스 테스트를 실행하지 않는다. 문서 diff와 공백 오류만 확인하며 H~K는 모두 미구현 상태다.

### 2026-09-05 H~K 추가 확정

- 디바이스 테스트는 각 구간에서 나누지 않고 H~K 통합 구현이 끝난 뒤 하나의 체크리스트로 진행한다.
- 방별 red badge는 히스토리 팝업 열람이 아니라 모집방 상세 진입 자체로 사라진다.

## 2026-09-05 H/I — 선호 역할 대표 전투력·수동 전체 갱신 완료

- 역할별 Build Snapshot 저장은 그대로 유지하면서, 선호 역할과 다른 역할을 최근 갱신해도 Character 요약 `combatPower`를 덮어쓰지 않도록 로컬 저장 경계를 수정했다.
- 내 계정 Character 카드는 선호 역할 Snapshot 전투력을 표시한다. 그룹 로컬 표시와 Firestore Character 최소 표시 동기화도 같은 선호 역할 값을 우선하며 파티의 선택 역할 Snapshot은 변경하지 않았다.
- 내 계정 상단 기능 구역과 메인 계정 사이 여백을 늘리고 메인 계정 제목 우측 끝에 원형 새로고침 아이콘을 추가했다.
- 아이콘은 확인 Alert 뒤 나이스단을 제외한 인증·active 소유권·원정대 소속·1700 이상 본·부계정 Character를 강제 갱신한다. 시작 자동 갱신과 Coordinator/single-flight를 공유하되 앱 수명당 1회 결과 캐시는 재사용하지 않는다.
- 실행 중 `갱신 중 완료 수/전체 수`를 표시한다. 완료 후 10초 동안 재실행을 제한하며 제한 중 Alert에 빨간색 남은 시간과 비활성 확인 버튼을 표시한다.
- H/I 표적 테스트 59개와 전체 `flutter test --no-pub` 892개가 통과했다. `flutter analyze --no-pub`는 신규 문제 없이 기존 21개 항목만 보고했다.
- 디바이스 테스트는 사용자 결정에 따라 H~K 통합 구현 뒤 단일 체크리스트로 진행하며 현재 결과는 보류다.

## 2026-09-05 실기기 갱신 전체 실패·그룹 생성 권한 오류 대응

- 실기기 2대에서 자동 갱신 미진행 및 수동 갱신 대상 전체 실패를 확인했다.
- Coordinator가 보석 효과 분류 미확인과 아크 그리드 조건 미충족 경고를 저장 차단 오류로 승격하던 검증을 제거했다. 역할 Snapshot 자체를 확정할 수 없는 오류는 유지했다.
- 수동 결과에 Character별 실패 원인을 노출하고 시작 갱신 실패 원인을 로그에 남겼다.
- 전체 테스트 896개가 통과했다. 정적 분석은 이번 변경의 신규 문제 없이 기존 21개 항목만 남았다.
- 그룹 생성 `permission-denied`는 `activeJoinCode` 허용 Rules의 운영 미배포 가능성과 일치한다. 최신 Rules 배포 후 실기기에서 갱신 및 그룹 생성을 재검증한다.

## 2026-09-06 딜러 전용 직업 자동 갱신 역할 수정

- 실계정에서 딜러 전용 직업까지 카탈로그 역할 분기와 4티어 노드 탐지를 요구해 갱신을 차단하던 경계를 확인했다.
- 바드·홀리나이트·도화가·발키리만 복수 역할 탐지를 유지하고, 그 외 직업은 무조건 `dealer`로 저장하도록 공통 `CharacterBuildRolePolicy`를 추가했다.
- Character 상세 UI의 역할 선택 여부도 같은 정책을 사용하도록 중복 직업 목록을 제거했다.
- 딜러 전용 직업의 탐지 결과가 `unsupportedClass`이고 관련 4티어 노드가 없어도 dealer 갱신이 성공하는 회귀 테스트를 추가했다.
- 역할 정책·Coordinator·Character 상세 ViewModel 표적 테스트 22개와 전체 자동 회귀 899개가 통과했다. analyze는 신규 문제 없이 기존 21개 항목만 보고한다. 수정본 실기기 재검증은 계속 필요하다.

## 2026-09-06 그룹 생성 payload 하위 호환 복구

- `firebase-debug.log`에서 최신 Rules 배포가 두 차례 모두 HTTP 503으로 종료돼 운영 Rules가 갱신되지 않은 사실을 확인했다.
- J 작업이 최초 그룹 문서에 추가한 `activeJoinCode: null`이 기존 운영 Rules allowlist에 막혀 그룹 생성 전체가 `permission-denied`가 되는 직접 원인이었다.
- 최초 생성 payload에서 불필요한 `activeJoinCode`를 제거하고 최신 Rules는 해당 필드의 미존재/null을 모두 허용하도록 최소 변경했다. 레이드 생성 및 다른 그룹 생성 계약은 수정하지 않았다.
- 그룹 생성·Rules 표적 테스트 41개와 전체 자동 회귀 899개가 통과했다. analyze는 신규 문제 없이 기존 21개 항목만 보고한다.

## 2026-09-06 실기기 Player/활동 Character 복구 진단

- 연결된 SM-F956N의 Drift DB를 개인정보 값 없이 집계했다. active 서버 계정 1개, 서버 ID가 있는 Character 18개, 원정대 이탈 0개로 로컬 인증 바인딩은 정상이다.
- 그룹·레이드 후보는 현재 Player의 `characterActivity`가 빈 집합이면 인증 Character를 모두 제외하고 있었다. 빈 선택은 저장 정책이 금지하므로 빈 집합을 미초기화로 판정해 기존 fallback을 사용하도록 수정했다.
- 로그에서 일반 사용자 화면의 `syncExpiredDisputes()`가 운영자 전용 전체 쿼리를 실행해 반복 `permission-denied` 미처리 예외를 발생시키는 것을 확인했다. 일반 요청/분쟁 watch의 호출을 제거하고 운영자 큐 경로만 유지했다.
- 운영자 권한은 기존 Player에 남아 있을 수 있으며 새 익명 Player로 자동 이전하지 않는다.
- 관련 표적 테스트 24개와 전체 자동 회귀 899개가 통과했다. 병렬 전체 회귀에서 변경된 기존 기대값 1건을 확인해 미초기화 fallback 기준으로 정정한 뒤 단독 전체 회귀 통과를 재확인했다. analyze 신규 문제는 없다.

## 2026-09-06 서버 연결 복구 선택지 계획 문서화

- 회원가입·로그인을 추가하지 않고 기존 Firebase 익명 인증과 게임 계정 인증을 유지하는 복구 방향을 확정했다.
- 정상 통신에서 Player 연결 부재가 확인된 경우에만 `다시 인증하여 복구`와 `데이터 삭제 후 새로 시작` 두 선택지를 제공한다.
- 재인증 복구는 기존 게임 계정 인증을 복구 모드로 재사용하며, 성공 전에는 로컬 데이터를 삭제하지 않는다.
- 오프라인, 503, `unavailable`, `permission-denied`는 서버 데이터 삭제로 판정하지 않는다. 이 상태에서는 로컬 데이터를 유지하고 재시도만 제공한다.
- 연결 상태 판정, 제한 UI, 인증 복구 모드, 명시적 로컬 초기화, 자동·디바이스 검증을 L1~L5 구현 구간으로 나눠 `NEXT_WORK.md`에 기록했다.
- 이번 변경은 문서만 수정했으며 앱 코드와 Firebase Rules는 변경하지 않았다.

## 2026-09-06 로컬·서버 인증 불일치 대응 최소화

- 앞서 기록한 앱 내부 재인증 복구·재귀속·자동 초기화 계획은 과도한 변경으로 판단해 철회했다.
- 로컬에는 인증 원정대가 있지만 서버의 Player·게임 계정·소유권·Character 관계가 사라져 기존 서버 명령이 실패하는 경우만 대상으로 한다.
- 기존 실패 지점에서 앱 재설치 또는 앱 데이터 삭제 후 현재 게임 인증을 다시 진행하라는 확인 Alert만 제공한다.
- 정상 작동 중인 오프라인·503 처리, 서버 구조·Rules, 앱 시작 조회, 로그인 없는 사용 흐름은 변경하지 않는다.
- 이번 정정도 문서만 수정했으며 기능 코드는 변경하지 않았다.

## 2026-09-06 로컬·서버 인증 불일치 안내 구현

- 그룹·레이드 생성의 기존 `playerBindingMissing`, `ownershipLost` 결과와 인증 세션 소실을 공통 확인 Alert에 연결했다.
- 서버 Character 문서 자체가 사라진 경우를 일반 검증 실패와 구분하는 `serverDataMissing` 결과를 그룹·레이드 생성에 추가했다.
- Alert는 앱 재설치 또는 앱 데이터 삭제 후 기존 게임 계정을 다시 인증하라고 안내하며 `확인` 외의 동작을 제공하지 않는다.
- 기존 오프라인·503·Firestore 권한 오류 처리, 서버 조회 횟수, Rules·스키마는 변경하지 않았다.
- 그룹·레이드 Alert 표적 테스트와 전체 자동 회귀 902개가 통과했다. analyze는 신규 문제 없이 기존 21개 항목만 보고했다.
- 서버 관계 삭제 상태의 실제 기기 검증과 앱 데이터 삭제 후 재인증 복구 확인은 남아 있다.

## 2026-09-07 재인증·생성 연쇄 장애 문서 진단

- 재인증 후 파티 후보는 복원됐지만 그룹·레이드 생성은 계정 불일치 Alert로 계속 실패하고, 이후 인증이 일반 실패 → Challenge 만료 → 장비 정보 처리 실패 순서로 진행된 실기기 증상을 기록했다.
- 로컬 인증 완료 표시와 후보 노출은 로컬 active 소유권·서버 ID 기준이라 서버의 Player·Claim·게임 계정·Character·소유권 전체 정상 여부를 보장하지 않는 것을 코드에서 확인했다.
- 인증 시작은 6부위 전체 장착 기준 Snapshot을 요구하므로 장비를 해제한 상태의 새 인증이 `Incomplete equipment` FormatException으로 실패하며, 현재 UI가 이를 모호한 문구로 표시한다.
- 인증 Claim은 auth binding만 확인하고 Player active를 확인하지 않는 반면 그룹 생성은 Player active를 검사해 두 기능의 성공 기준이 다르다.
- 고아 `characterIdentityClaims`가 삭제된 `gameAccounts`를 가리키면 인증이 StateError로 중단되며, 재설치·앱 데이터 삭제만으로 서버의 고아 Claim은 제거되지 않는다.
- 실제 원인은 현재 UID의 auth binding, Player, 원정대 Claim, gameAccount, Character, playerGameAccount 연결을 Firestore에서 대조한 후 확정한다.
- 서버 상태 확인 전 추가 코드 수정과 현재 Alert 변경의 커밋·배포를 보류한다. 이번 작업은 문서 진단만 수행했다.

## 2026-09-07 앱 데이터 초기화 복구 확인·서버 점검 기록

- 사용자가 앱 재설치 또는 운영체제의 앱 데이터 전체 삭제 후 원정대를 다시 등록·인증하면 그룹·레이드 생성까지 정상 작동하는 것을 확인했다.
- 이번 사례는 클라이언트 초기화로 복구되므로 희박한 불일치를 위한 Player·계정·Character 자동 재귀속과 앱 시작 추가 검사는 보류한다.
- 현재 계정 불일치 Alert와 앱 데이터 초기화 후 재인증을 기본 복구 절차로 유지하고, 실제 운영 반복 사례가 생기면 자동 복구를 재검토한다.
- 저장소 Rules에서 `gameAccounts`, `characters`, `characterIdentityClaims`가 모든 인증 사용자에게 넓은 read/write 권한을 갖는 것을 별도 데이터 무결성 점검 대상으로 기록했다.
- 최근 Rules 배포 503 이력이 있으므로 운영 배포본과 저장소 파일의 일치 여부를 먼저 확인하고, Emulator에서 타 사용자 문서 수정·삭제 가능성을 검증한다.
- Rules 강화는 인증 Transaction과 소유권 이전 등 정상 쓰기 계약을 목록화한 뒤 최소 권한 회귀 테스트와 함께 별도 작업으로 진행한다.
- 장비 일부 해제 상태의 새 인증은 판정 로직 변경 없이 `모든 장비를 정상 착용한 뒤 인증을 다시 시작해 주세요.`라는 별도 UX 개선 후보로 남겼다.
- 이번 작업은 문서만 갱신했으며 앱 코드와 Firestore Rules는 수정하지 않았다.

## 2026-09-07 서버 점검 시점 정정

- 앱 재설치 또는 앱 데이터 전체 삭제 후 재인증으로 현재 장애를 우회할 수 있으므로 서버·Rules·복구 절차 점검은 당장 진행하지 않는다.
- 운영 Rules 대조, Emulator 권한 검증, 백업·초기화 절차와 자동 복구 검토는 현재 작업이 아닌 차후 작업 목록으로 이동했다.
- 이번 정정은 작업 시점과 우선순위만 변경하며 코드·Rules·테스트에는 손대지 않았다.

## 2026-09-07 진행 중 레이드 카드 알림 배지 갱신 지연 기록

- 진행 중 레이드 카드의 방별 숫자 red badge는 표시되지만 참가 Character 변경·승인 이벤트 발생 후 즉시 갱신되지 않고, 모집 상세 진입·복귀 같은 특정 동작 뒤에 보이는 실기기 현상을 확인했다.
- 진행 중 목록은 스트림이지만 Player events는 `.get()` 기반 일괄 sync이며, 카드 count는 Firestore가 아니라 Drift receipt를 수동 재조회해 계산하는 현재 구조를 확인했다.
- 모집 상세 진입이 사용자 전체 event sync를 실행하므로 한 방을 열었다 나온 뒤 다른 방의 누적 badge가 나타날 수 있다. 해당 방은 진입 즉시 읽음 처리돼 badge 관찰이 어려울 수 있다.
- 참가방별 Listener 추가는 후보에서 제외한다. Player events 단일 Listener, 화면 생명주기 단발 sync, 전면 polling, 수동 갱신, 서버 집계/푸시를 비교 후보로만 기록했으며 방향은 선택하지 않았다.
- 즉시성 요구, foreground 범위, 상세 진입 읽음 정책, 다중 기기 읽음 기준을 먼저 결정하고 후보별 읽기 비용·지연·복잡도를 비교한 뒤 구현 방향을 정한다.
- 이번 작업은 문서 기록만 수행했으며 앱 코드·Rules·인덱스·테스트는 변경하지 않았다.

## 2026-09-08 실기기 통과 및 다음 세 항목 협의 전환

- 정상 서버 데이터 상태에서 현재 사용자 관점의 앱 동작을 실기기로 확인해 이번 Rules 축소·신청자 Snapshot 구간은 디바이스 테스트 통과로 판정했다. 서버 데이터가 삭제된 불일치 기기는 정상 회귀와 분리한다.
- 진행 중 레이드 카드 red badge는 앱 재실행 또는 모집 상세의 앱바 뒤로가기 후 갱신되지만, 휴대폰 시스템 뒤로가기 후에는 갱신되지 않았다. 레이드 현황에는 pull-to-refresh가 없다.
- 모집 생성 완료 후 생성 상세에서 뒤로가면 레이드 현황이 아니라 레이드 모집 목록으로 돌아가야 한다는 기대 흐름을 기록했다. 기존 하단 탭의 루트 초기화 방식도 함께 재협의한다.
- 다음 구간은 서버 데이터 불일치 표시, 레이드 현황 새로고침, 하단 탭/생성 복귀 스택 세 항목의 방향을 먼저 협의한다. 이번 문서 갱신에서는 앱 코드·Rules·Router를 수정하지 않았다.

## 2026-09-08 서버 데이터 불일치 표시·재인증 복구 1차

- `codex/account-server-mismatch-recovery`에서 서버 원본 조회에 성공한 경우만 authBinding·Player·gameAccount·playerGameAccount 관계를 확인하고, 부재·비정상을 로컬 `serverMismatch`로 구분했다. 오프라인·503·permission-denied는 기존 로컬 상태를 유지한다.
- 내 계정의 인증 완료 Chip을 서버 불일치 안내로 교체하고, 수동 인증 화면에서 등록된 원정대 Character로 재요청할 수 있게 했다.
- Character Claim은 남았지만 대상 gameAccount가 삭제된 경우 일반 장비 인증과 운영자 승인 수동 인증이 같은 서버 ID로 계정·Character·소유관계를 재생성하도록 기존 중단 조건을 제거했다.
- 관련 화면·Repository·로컬 DB 표적 테스트 59개와 전체 테스트 926개가 통과했다. 전체 analyze는 신규 문제 없이 기존 21개만 보고했다. Rules·스키마·자동 로컬 삭제는 변경하지 않았다.
- 실제 Firestore 부분 삭제 상태의 실기기/Emulator 검증은 남아 있으며, 검증 전 현재 구간을 `dev`에 병합하지 않는다.

## 2026-09-08 승인 완료 후 로컬 재연결 실패 원인 수정

- 지정 Player의 운영 Firestore 관계를 읽기 전용으로 확인했다. authBinding, active Player, gameAccount, playerGameAccount, Character, 승인된 수동 인증 요청은 현재 계정으로 일관되게 연결돼 있어 서버 Authentication-Player 연결 문제는 아니었다.
- 서버가 초기화되기 전에 저장된 기기의 과거 gameAccount/Character ID를 승인 결과의 새 ID로 바꾸려 할 때 로컬 DB의 재매핑 방지 로직이 예외를 냈고, 수동 인증 화면이 이 예외를 숨겨 승인만 되고 기기 연결은 갱신되지 않았다.
- 서버 원본 확인으로 `serverMismatch`가 확정된 계정에 한해서만 서버 ID 재연결을 허용했다. 정상 active 및 실제 소유권 상실 계정의 재매핑 차단은 유지한다.
- 승인 결과 로컬 저장 실패를 화면 문구로 노출하고, 서버 불일치 확인 전에는 기존 보호 로직을 우회할 수 없도록 회귀 테스트를 추가했다. 수정 빌드 실기기에서 기존 승인 결과의 자동 재연결을 확인하기 전에는 `dev`에 병합하지 않는다.
- 실패한 승인 결과를 화면 재빌드마다 무한 재시도하던 가능성도 차단했다. 같은 화면에서는 한 번만 시도하고 다시 진입할 때 재시도한다. 표적 테스트 46개와 전체 테스트 928개가 통과했고 변경 파일 정적 분석도 통과했다.
- 추가 대조 결과 `authBindings`는 익명 Auth UID와 Player의 신원 연결이며 원정대 소유권 테이블이 아니다. 인증 승인 대상은 요청 문서의 `requesterPlayerId`이고 이 값은 요청 기기의 현재 UID binding에서 결정되므로, 다른 사용자의 미인증 로컬 임시등록이 승인 대상을 가로채지 않는다.
- 콘솔에서 Authentication 사용자를 직접 삭제하면 기존 `authBindings`가 고아 문서로 남을 수 있지만 새 UID와 문서 ID가 달라 새 사용자를 잘못 연결하지는 않는다. 이번 패치는 authBinding 재귀속을 추가하지 않으며, 삭제된 Auth 세션 복구는 기존 앱 데이터 초기화 정책을 유지한다.
- 문제 기기에 수정 빌드를 설치하자 별도 인증 조작 없이 인증 계정 상태가 복구됐고, 같은 기기에서 그룹 생성과 레이드 모집 생성이 모두 성공했다. 서버 관계가 정상인 로컬 불일치 복구는 실기기 통과로 판정했다.
- 이어서 발견된 그룹 초대코드 생성 `permission-denied`는 계정 복구와 분리한다. J 기능의 실기기 검증 보류 항목으로 다시 열고 별도 브랜치에서 Rules 판정 순서와 운영 배포본을 확인한다.

## 2026-09-08 그룹 초대코드 생성 권한 회귀 대응

- 신규 그룹과 레이드 모집 생성은 성공했지만 같은 그룹의 초대코드 생성만 `permission-denied`로 재현됐다. J 구현 당시 자동 테스트만 완료하고 실기기 검증을 통합 단계까지 보류했던 항목이다.
- `groups/{groupId}` update의 주석과 달리 초대코드 플래그 판정이 탈퇴·방장 위임·해산·승인 뒤에 배치된 상태를 확인했다. 초대코드 및 표시 정책 판정을 첫 순서로 옮겨 해당 필드 전이를 즉시 검증하게 했고 기존 허용 조건은 변경하지 않았다.
- 관련 Rules 계약·쓰기 계획·화면 테스트 52개가 통과했다. Java가 없어 Emulator를 시작하지 못했고, 배포 없는 Firebase 원격 컴파일 검증은 두 차례 `/test` HTTP 503으로 중단됐다. 실제 Rules 배포는 하지 않았으며 배포 후 실기기 재검증이 필요하다.
- 사용자가 dry-run 503 이후 실제 배포 성공과 초대코드 생성을 확인했다. 일반 멤버에게는 그룹 상세 진입 버튼이 숨겨지고 코드 페이지도 그룹장 외 사용자를 차단해 공개 스위치가 실질적으로 동작하지 않던 UI 누락을 확인했다.
- 모든 그룹원에게 초대코드 진입점을 표시하되 일반 멤버는 공개된 활성 코드의 확인·복사만 허용하고 관리 동작은 숨겼다.
- 실패한 재가입 그룹의 운영 문서를 읽기 전용으로 대조했다. 탈퇴 Player의 membership state는 빈 목록이고 개인 groupRelation은 삭제됐으며, 그룹의 accepted 신청 relation만 최종 이력으로 남아 있었다. 데이터 청소 문제가 아니므로 코드 가입 그룹 update Rules를 복합 탈퇴·이전·해산 판정보다 먼저 평가하도록 옮겼다.
- 표적 테스트 54개와 전체 테스트 930개, 변경 파일 정적 분석이 통과했다. Rules 재배포와 두 기기 실사용 재검증 전에는 `dev`에 병합하지 않는다.
- 사용자가 수정 Rules와 앱으로 일반 그룹원 코드 표시, 코드 가입, 탈퇴 후 같은 코드 재가입, 그룹원 정상 표시를 모두 확인했다. 초대코드 권한·공개·재가입 회귀를 실기기 통과로 판정하고 기능 브랜치를 `dev`에 병합한다.

## 2026-09-10 주차 자동 보정·Rules 경고·그룹 해산 구간 완료

- 한국 수요일 오전 6시 경계에서 만료된 1회성 방을 미완료 종료하고, 반복방을 최초 접근 시 현재 주차로 멱등 승계하는 lazy reconciliation을 구현했다. 현재 주차와 반복방의 canonical assignment는 계속 점유로 유지하며, 과거 미완료 종료 1회성 assignment만 새 생성·참가 Transaction에서 안전하게 교체한다.
- 과거 미완료 종료 데이터가 남은 Character의 동일 레이드 방 생성·참가, 레이드 생성·신청·수락·추방·참가 Character 변경·현황 갱신·그룹장 탈퇴 자동 승계를 실기기에서 확인했다.
- Firebase 콘솔 게시본과 로컬 Rules를 대조해 미사용 인자 1건과 nullable string/map 경고 8건의 원인을 확인했다. 허용 기능·스키마를 제거하지 않고 실제 타입 인자와 boolean 소유 판정으로 바꿔 원격 컴파일 경고를 0건으로 정리했다.
- CLI 503은 `/test`, `/rulesets`, `/releases` 단계를 구분했다. `/rulesets` 503 뒤 콘솔 게시 시각이 갱신된 사례와 `/test` 503으로 게시되지 않은 사례가 모두 있었으므로, 이후에는 응답 코드만으로 반영 여부를 단정하지 않고 콘솔 활성 소스와 성공 로그를 함께 본다.
- 1인 그룹 해산은 허용 함수 내용이 과거 통과본과 같았지만 `groups` update에서 다른 판정 뒤에 놓인 상태였다. `validGroupDisbandUpdate`를 첫 분기로 이동하고 그룹 표적 테스트 43건을 통과시킨 뒤, 사용자 승인 범위에서 Rules 배포를 재시도해 `released rules`와 `Deploy complete`를 확인했다.
- 운영 반영 후 그룹 생성·가입 신청·일반 탈퇴·그룹장 양도·초대코드 파티원 확인·코드 가입·마지막 1인 해산이 모두 실기기에서 정상 동작했다. 수동 인증은 다음 통합 디바이스 테스트에서 필요할 때 함께 확인한다.
- 상세 Rules 장애·경고 기록은 `TASK-11-FIRESTORE-RULES-COMPLEXITY.md`에 보존하고, 현재 실행 문서에는 다음 Character Build membership 구간만 남겼다.

## 2026-09-10 동일 레이드 다른 난이도 신청 후보 회귀 수정

- 동일 `raidId`의 다른 난이도에 이미 확정 참가한 Character가 신청 팝업에 다시 노출되는 실기기 회귀를 조사했다.
- 충돌 Domain 정책은 정상이었지만 앱 라우터의 후보 서비스가 서버 assignment가 아닌 빈 인메모리 저장소와 `local-user`를 사용해 확정 점유를 읽지 못한 것이 원인이었다.
- 최초 Firestore 목록 Reader는 Rules의 `allow list: false`와 충돌해 모집 생성 정보 로딩을 막았다. 이를 즉시 철회하고 canonical assignment 문서 ID를 이용한 개별 `get` Lookup으로 교정했다.
- 개별 문서 존재만 보던 1차 교정은 과거 1회성 미완료 종료 점유까지 현재 참가로 오판했다. 최종 명령과 같은 legacy replacement 정책을 적용해 교체 가능한 stale assignment는 후보 차단에서 제외하고, 현재 주차·반복방 점유만 차단하도록 보완했다.
- 서버 쓰기, Firestore Rules·스키마는 변경하지 않았다. 후보·과거 미완료 점유 정책 표적 테스트 10건과 변경 파일 analyze가 통과했고 실기기 재현 확인을 남겼다.
- 수정 빌드에서 과거 미완료 종료 점유가 남았던 `로리캐남캐안해요` Character로 4막 하드 모집 생성이 정상 동작해 stale assignment 후보 오판 회귀를 실기기 통과로 확정했다.

## 2026-09-10 기존 기능 회귀 방지 작업 원칙 강화

- 작은 기능 추가 뒤 모집 생성·미완료 종료 재생성 등 기존 흐름이 연쇄 중단된 사례를 반영해 구현 전 회귀 방지 게이트를 공통 AI 행동 규칙에 추가했다.
- Repository·Rules 조회 권한·식별자·주차·데이터 생명주기 확인, 기존 Domain 정책 재사용, 실제 라우터/DI 연결 검증 및 직전 실기기 통과 흐름 보존을 필수화했다.
- 다음 동일 딜러 직업 신청 후보 차단 작업에는 모집 생성, 동일 레이드 점유, stale assignment, 반복방, Claim, 4인 차단, 8인 허용, 신청·가입·승인 흐름을 회귀 보호 목록으로 확정했다.

## 2026-09-10 신청 후보 동일 딜러 직업 구성 차단

- 브랜치 `cursor/application-candidate-dealer-class-block`에서 모집 상세 신청·캐릭터 변경 후보가 현재 membership과 파티별 동일 딜러 직업 상한을 반영하도록 연결했다.
- 상세 membership Snapshot과 `maxDealersPerClassPerParty`를 포함한 `partyRules`를 후보 Query에 전달한다. 신청·즉시 가입은 최종 가입과 같은 `assignEmptySlot`, 캐릭터 변경은 자리 유지 `failureForInPlaceReplacement`를 사용한다.
- 모집 생성 후보는 membership을 넘기지 않아 기존 생성 흐름을 유지한다. Firestore Rules·스키마는 변경하지 않았다.
- 표적·영향 자동 테스트 97건과 변경 파일 analyze가 통과했다. BUG-013은 자동 검증 완료·실기기 확인 대기로 갱신했다.
- 실기기에서 4인 동일 딜러 직업 후보 제외와 8인 다른 파티 배치 허용을 확인한다.
- 실기기 피드백: 4인 동일 직업 후보 미노출과 8인 동일 직업 2명 허용을 확인했다. 8인 3번째 동일 딜러 차단 테스트를 고정하고, 변경 가능 캐릭터가 없을 때 안내 SnackBar와 로딩 중 버튼 상태를 보강했다.
- 실기기에서 변경 가능 캐릭터 없음 팝업까지 확인한 뒤 `dev`에 병합했다.

## 2026-09-11 레이드 목록 내 Character 필터·참가 인원 정렬·남은 자리 필터

- 브랜치 `cursor/raid-list-character-filter-local-sort`에서 §14를 구현했다. Firestore Rules·스키마·인덱스는 변경하지 않았다.
- 진행 중 필터 Sheet 최하단에 `내 캐릭터` 다중 선택을 추가하고 membership Character ID로 판정한다.
- 참가 인원은 기본 많은 순 로컬 안정 정렬이며, 목록 행 화살표 터치로 적은 순과 전환한다. 정렬 팝업은 쓰지 않는다.
- 남은 자리는 정렬이 아니라 상단 필터 이후 1~7 다중선택(OR) 2차 필터다. 미선택이면 전체 허용이며 전용 초기화를 둔다.
- 화면별 Drift 저장으로 진행 중/모집 상태를 분리한다. 처리 순서는 상단 필터 → 남은 자리 필터 → 참가 인원 정렬이다.
- 표적 자동 테스트와 변경 파일 analyze가 통과했고, 실기기에서 기존 상단 필터·화살표 토글·남은 자리 칩 필터가 정상임을 확인했다.

## 2026-09-11 그룹 membership 보석 검증 Snapshot 다음 작업 계획

- `ai_rules.md`부터 현재 상태·제품·아키텍처·버그·완료 이력을 대조하고, 파티 membership 안정화 뒤 남겨 둔 그룹 보석 검증 Snapshot 전파를 다음 단일 작업 그룹으로 선정했다.
- 파티에서 검증된 다섯 필드 요약을 재사용하며 그룹 생성·가입 신청·승인·초대 수락·초대코드 가입·본인 Snapshot 갱신별 데이터 출처와 null 호환을 `NEXT_WORK.md`에 고정했다.
- Build 별칭·개인 메모·공유, 전체 Character Snapshot과 서버 복구는 제외하고 Rules 최소 변경, 기존 그룹 명령 회귀, 실제 배포 1회 및 두 기기 통합 확인을 완료 조건으로 정했다.
- 문서 대조 중 발견한 그룹 선호 역할 H 작업, BUG-010과 BUG-011·013의 오래된 상태 문구를 현재 `dev` 및 완료 이력과 일치하도록 정정했다.
- 이번 작업은 문서만 변경했으므로 Flutter 검증은 실행하지 않고 `git diff --check`와 문서 diff로 검증한다.

## 2026-09-12 파티 Build 오류 누락 후속 작업 계획

- 실기기에서 내 계정은 가디언 피어 스킬 불일치를 표시하고 신청자 카드도 빨간 오류를 표시하지만, 새 파티의 파티장 본인 카드에는 같은 오류가 없는 현상을 대조했다.
- 구성원 카드의 본인 예외가 아니라 파티 생성 명령·Write Plan이 파티장 membership에 `gemValidationSnapshot`을 전달하지 않는 것이 원인임을 확인했다. 기존 신청·승인·직접 참가·Character 변경 경로는 같은 요약을 이미 전달한다.
- 그룹 활동 Character 팝업은 로컬 `buildIntegritySnapshot`으로 보석과 아크그리드를 함께 표시한다. 파티 상세의 참가 Character 변경 목록도 같은 공용 표시를 재사용하되, 서버 변경 명령에는 기존 보석 최소 요약만 보내는 경계로 설계했다.
- 새 파티장 Snapshot 저장, 변경 후보의 로컬 통합 상태 표시, 과거 null 호환과 본인/타인 동일 표시를 다음 작업으로 고정했다. 기존 파티 이행, 아크그리드 서버 저장, 후보 차단과 다른 신청 Sheet 확대는 제외했다.
- 생성 소유권·점유·Claim·Transaction 순서, 가입·승인·변경 흐름, 동일 직업/역할 후보 정책, 그룹 활동 교집합을 회귀 보호 목록으로 정했다. 현재 Rules는 초기 파티장 membership의 추가 map을 필드 allowlist로 제한하지 않고 Character 변경에는 이미 `gemValidationSnapshot`을 허용하므로 Rules 수정·배포를 계획하지 않는다.
- 이번 구간은 설계 문서만 변경하며 Flutter 테스트는 실행하지 않고 `git diff --check`와 문서 diff로 검증한다.

### 구현·자동 검증

- 생성 화면 → `PartyCreateCommand` → `PartyCreateWritePlan`에 선택 역할의 보석 최소 요약을 연결하고 파티장 membership에만 저장했다. 모집 원본·assignment·group listing과 Transaction Repository 순서는 바꾸지 않았다.
- 후보 역할 옵션은 같은 로컬 Build에서 `PartyGemValidationSnapshot`과 표시 전용 `BuildIntegritySnapshot`을 함께 만든다. 참가 Character 변경 Sheet는 공용 상태 행으로 보석·아크그리드 복합 오류를 표시하고, 실제 변경 명령에는 기존 보석 요약만 전달한다.
- Write Plan의 v2 map 위치, 생성 화면 명령 전달, 후보 통합 상태, 변경 Sheet 복합 표시와 실제 명령 전송을 테스트로 고정했다. 생성·후보·상세 표적 테스트 63건과 변경 파일 정적 분석이 통과했다.
- `firestore.rules` diff가 없어 Rules 검사·배포는 수행하지 않는다. 신규 파티장 본인/타인 카드, 과거 파티 호환과 실제 Character 변경은 실기기 확인 대기다.

### 실기기 확인·완료

- 사용자가 그룹 레이드 상태에서 오류 Character를 파티장으로 생성했을 때 파티 상세의 파티장 카드에 오류가 정상 표시되는 것을 확인했다. 생성 경로의 `gemValidationSnapshot` 누락 수정은 실기기 통과로 판정한다.
- 참가 Character 변경 목록의 보석·아크그리드 복합 표시와 오류 Character 선택 후 명령 전달은 Widget 테스트로 확인했다. 이 세부 항목의 별도 실기기 관찰 결과는 받지 않았지만 사용자가 현재 기능 구현을 완료 판정했다.
- 새로 가능해진 흐름은 신규 공개·그룹 파티장 카드의 보석 오류 표시와 참가 Character 변경 후보의 보석·아크그리드 오류 안내다. 기존 생성·신청·승인·직접 참가·Character 변경·그룹 조회와 Rules는 변경하지 않았다.
- 자동 검증은 표적 테스트 63건과 변경 파일 정적 분석 통과다. Rules 변경·배포는 없으며 이번 기능을 완료 상태로 닫는다.

### 신청·즉시 참가 선택 목록 확대와 운영 분류

- 사용자의 후속 결정에 따라 현재 브랜치에서 신청·즉시 참가 Character 선택 Sheet에도 참가 Character 변경 목록과 같은 `BuildIntegrityStatusLine`을 적용했다. 정상·판정 불능은 비표기하고 보석·아크그리드 확정 오류만 안내하며 선택 및 기존 신청·즉시 참가 명령은 차단하지 않는다.
- 파티 상세 Widget 테스트 43건과 변경 파일 정적 분석이 통과했다. Firestore 저장·Rules·권한 및 후보 필터는 변경하지 않았다.
- 사용자가 아직 단독 테스트 중이므로 기존 `gemValidationSnapshot` 누락 파티의 마이그레이션은 필요하지 않은 것으로 확정해 범위에서 제거했다.
- 약 60개 직업·분기의 특수 보석 카탈로그 조사는 상시 운영 작업으로 분류했다. 캐릭터명과 로컬 환경 변수 토큰을 이용한 조회, 임시 원본 저장, 미등록 후보 제시와 사용자 승인 후 등록 절차를 `LOST_ARK_API.md`에 기록했다.
- 최종 기능 브랜치를 최신 원격 `dev` 기준과 대조한 뒤 `dev` 병합·푸시 대상으로 확정했다.

# 2026-09-12 세 직업 특수 보석 대상 등록

- 사용자 확인값에 따라 환수사 `야성` → `둔갑 금술 스킬`, 가디언나이트 `드레드 로어` → `가디언 피어`, 데모닉 `멈출 수 없는 충동` → `블러드 제노사이드`를 카탈로그 `2026.09.12`에 등록했다.
- 기존에 세 대상을 미등록 오류 표본으로 사용하던 mapper·진단 도구 테스트를 분기 감지 및 정상 판정 회귀로 전환했다. 세 직업의 다른 분기·스킬은 추정 등록하지 않았고, 분기 미탐지 fallback과 미등록·타 직업·정보 부족 판정은 변경하지 않았다.
- Snapshot schema, UI, Firestore와 Rules는 변경하지 않았다. mapper·진단 도구·카탈로그 로딩/검증 표적 테스트 40건과 변경 테스트 파일 정적 분석이 통과했다. 전체 테스트는 1,033건까지 진행 후 변경과 무관한 `test/widget_test.dart` 9건이 Firebase 기본 앱 미초기화(`[core/no-app]`)로 실패했고, 해당 파일 단독 실행에서도 동일하게 재현됐다. 계정 데이터 갱신 뒤 해당 세 캐릭터의 기존 스킬 불일치 보석 경고가 사라지는지는 실기기 확인 항목이다.

# 2026-09-12 차원술사 특수 보석 대상 등록

- 사용자 확인값에 따라 차원술사 `시간 관리자` → `시간선 스킬`을 카탈로그 `2026.09.12`에 추가했다. mapper·진단 도구·카탈로그 로딩/검증 표적 테스트 40건과 변경 테스트 파일 정적 분석이 통과했다. 다른 분기·스킬, 판정 로직, UI, Snapshot, Firestore와 Rules는 변경하지 않았다.

# 2026-09-12 108개 실계정 표본 기반 Build 카탈로그 확장

- 사용자가 제공한 27직업·Build별 2명, 총 108캐릭터의 종합 Armory 응답을 진단 도구로 조회했다. 원본은 `lost_party_api_probe_830c605b` OS 임시 폴더에만 저장하고 Git에는 포함하지 않았다.
- 실제 `ArkPassive.Effects`의 깨달음 1티어를 기준으로 기존 8직업 카탈로그를 30직업으로 확장했다. 사용자 목록의 구 직업각인명과 현재 API 노드명이 다른 경우 API 실측값을 사용했다.
- `ArmorySkills.Name`에 없고 보석 Tooltip 직업이 현재 직업과 일치한 대상만 분기별 특수 보석으로 등록했다. 108개 원본을 다시 대조해 미등록 같은 직업 대상, 미등록 분기, 타 직업 대상의 오등록이 모두 0건임을 확인했다.
- 인파이터 `이비쥬`의 브레이커 보석 4개와 데빌헌터 `반짝이는레몬버터`의 바드 `천상의 연주`는 카탈로그에서 제외하고 실제 `foreignClass` 오류 회귀 테스트로 고정했다.
- 카탈로그 로딩·검증, mapper·진단 도구 표적 테스트 41건과 계정·공용 카탈로그·진단 도구 영향 회귀 287건, 변경 테스트 파일 정적 분석이 통과했다. UI, Snapshot schema, 로컬 DB, Firestore와 Rules는 변경하지 않았다.

# 2026-09-13 릴리즈 안정화 인증 안내·파티 통합 오류 전파 구현

- 장비 인증 Challenge가 앱 프로세스 메모리에만 유지되는 현재 정책을 화면에 명시했다. 앱 종료 시 남은 시간과 관계없이 시도가 종료된다는 안내와 인게임 장비를 즉시 조작할 수 있을 때 진행하라는 권장을 challenge 카드에 추가했다.
- 무기와 방어구 5부위 중 하나라도 미착용된 시작 실패를 일반 응답 형식 오류와 분리했다. Gateway는 typed `incompleteEquipment` 오류를 반환하고 화면은 완전 착용 후 재시도하라는 전용 문구를 표시한다. 무작위 부위·10분 만료·같은 프로세스 재진입·성공 binding은 변경하지 않았다.
- 후보 역할 옵션의 `BuildIntegritySnapshot`을 파티 생성 리더, 신청·재신청, 직접 참가, 신청 승인과 참가 Character 변경 명령까지 운반한다. 신청은 `submittedBuildSnapshot.buildIntegritySnapshot`, membership은 최상위 `buildIntegritySnapshot`에 저장한다. 승인은 신청 당시 Snapshot을 재사용하며 직접 참가·생성·변경은 선택 당시 로컬 값을 사용한다.
- 신청자와 배정/미배정 구성원 카드는 통합 Snapshot의 보석·아크그리드 복합 오류를 표시한다. 과거·손상·미지원 schema는 통합 정보만 `null`로 낮추고 기존 `gemValidationSnapshot` 표시와 카드·명령을 보존한다. 오류는 참가를 차단하지 않는다.
- Character 변경 Rules의 허용 필드에 `buildIntegritySnapshot`만 추가했다. 소유권, 활동 Character, 역할, 점유, Claim, 동일 직업·파티 구성과 그룹 경로는 변경하지 않았다.
- 인증 Gateway·화면, 파티 Write Plan·조회 mapper·생성·신청·직접 참가·승인 복사·Character 변경·신청자/파티원 카드와 Rules 문자열 계약 표적 테스트 93건이 통과했다. `test/app`, `test/features` 전체 957건도 통과했다.
- 전체 `flutter test`는 기능 테스트 1,047건까지 진행된 뒤 기존 최상위 `test/widget_test.dart`의 Firebase 기본 앱 미초기화(`[core/no-app]`)로 9건 실패했다. 이번 변경 경로와 무관한 기존 테스트 환경 문제로 분리하며 성공으로 기록하지 않는다.
- 전체 `flutter analyze`는 새 오류 없이 완료됐고 기존 스타일 info 37건과 변경하지 않은 테스트 경고 1건을 보고했다. 포맷과 `git diff --check`를 수행했다.
- 새로 가능해진 흐름: 인증 전 장비 준비·앱 종료 정책 인지, 신청 전 후보와 신청자 카드 및 참가 후 파티원 카드의 보석·아크그리드 오류 의미 일치.
- 보존 확인한 흐름: 완전 장착 인증 시작, 손상 응답 일반 안내, 파티 생성·신청·철회·재신청·직접 참가·승인·거절·Character/역할 변경, 파티 구성/주차·Claim과 그룹 연결 화면.
- 미확인 항목: Rules Emulator, 원격 컴파일 경고 0개, 운영 배포, 인증 안내/미착용 문구와 공개·그룹 파티의 신청·승인·직접 참가·Character 변경 실기기 확인. 현재 작업 브랜치 외 `release/1.0.0`, `dev`, `main`은 이동하지 않는다.
- Rules 커밋을 원격 작업 브랜치에 먼저 추적한 뒤 `firebase deploy --only firestore:rules --project lost-party`를 한 번 실행했다. 로컬 소스 확인 뒤 원격 컴파일 `projects/lost-party:test`가 HTTP 503을 반환해 종료됐으며 `/rulesets` 업로드와 `/releases` 반영에는 도달하지 않았다. 컴파일 성공·경고 0개와 운영 반영은 확인되지 않았고 같은 명령을 재시도하지 않았다.

# 2026-09-13 릴리즈 안정화 실기기 완료와 공격대 자리 조정 설계

- 사용자가 인증 진행 안내, 장비 미착용 전용 문구와 신청·참가 이후 통합 Build 오류 지속 표시를 실기기에서 확인했다. BUG-014~016을 완료 상태로 닫았다.
- Rules 503은 동일 조건 테스트 프로젝트 게시 성공, 운영 콘솔 오류 소멸, 로컬 소스 재붙여넣기 시 변경 없음과 실기기 동작을 근거로 간헐적 Firebase 저장 서비스 현상으로 분류했다. 앱·Rules 축소 같은 1차 대응은 하지 않고 재발 시 테스트 프로젝트와 실패 단계를 먼저 대조한다.
- 새로 확인한 8인 Character 변경 문제는 직업 규칙 자체가 아니라 기존 `failureForInPlaceReplacement()`가 현재 파티만 검사하는 데서 발생한다. 신규 참가의 다른 파티 배치 정책은 정상이며 변경 흐름만 확장한다.
- 다음 작업은 제자리 → 다른 파티 유효 빈자리 → 한 명과의 단순 교환 가능성 순서로 배치 계획을 계산한다. 빈자리는 대상만 자동 이동하고, 빈자리 없이 교환 가능하면 Character 변경만 허용한 뒤 파란 구성 안내를 표시한다. 전체 공대 자동 재배치는 하지 않는다.
- 공대장용 빈자리 이동·두 멤버 교환 명령, 기존 `memberMoved` 알림, revision 기반 원자성, Rules 최소 변경과 기존 신청·점유·Claim·그룹 listing 회귀 범위를 `NEXT_WORK.md`와 파티 명령 계약에 기록했다.
- 딜러/서포터 형태는 다른 구성 직업, 같은 역할의 깨달음 분기는 같은 구성 직업으로 확정했다. 16인·연쇄 교환·시너지 자동 추천은 현재 제외한다.
- 이번 구간은 문서 설계만 변경하며 앱 코드·Firestore Rules·운영 데이터는 수정하지 않는다.

# 2026-09-14 공격대 자리 조정 Rules 단순화와 1차 실기기 확인

- 자리 Claim 경로와 Rules 문법을 교정한 뒤, 파티 전체의 역할·동일 직업 조합을 Rules에서 다시 계산하던 구조를 제거했다. 앱은 Transaction에서 최신 membership을 읽어 공용 `PartyCompositionPolicy`로 판정하고, Rules는 인증·소유권·revision·변경 필드와 최소 슬롯 Claim 연결만 검증한다.
- 신규 모집은 `slotLedgerVersion: 2`와 `playerId`, `partyIndex`, `slotIndex`, `updatedAt`만 가진 슬롯 Claim을 사용한다. 버전이 없거나 실험 단계의 버전 1인 과거 모집은 기존 조회·완료·탈퇴를 유지하되 자동 이동과 자리 조정만 지원하지 않는다.
- 표적 테스트 134건, 모집·그룹·파티 상세 영향 회귀 370건과 Rules 계약 2건이 통과했다. 변경 파일 정적 분석은 신규 오류 없이 기존 스타일 info 37건만 확인했고 `git diff --check`를 통과했다.
- 사용자가 수정 Rules를 콘솔에 게시한 뒤, 종전에 모집 생성·가입이 모두 권한 오류로 실패하던 동일 계정으로 추가 인증 없이 모집 생성, 가입과 자리 이동이 정상 작동함을 확인했다. 계정·디바이스 인증 문제가 아니라 Rules 회귀였음을 확인했으며 신규 버전 2 모집의 기본 권한 경로는 실기기 통과로 판정한다.
- 후속 실기기에서 점유된 두 자리의 인원 교환이 정상 작동하고, 같은 파티에 동일 구성 직업이 생기는 교환은 저장되지 않고 안내가 표시되는 것을 확인했다.
- 그룹 생성·그룹장 이전·일반 그룹원 탈퇴·마지막 1인 그룹 해산과 파티 탈퇴 후 재신청도 정상 작동했다.
- 리더 외 확정 참가자가 있는 모집의 해산은 권한 확인 안내와 함께 실패했다. 과거 정상 동작했던 다인 해산의 신규 회귀 `BUG-018`로 기록했으며 사용자 지시 전에는 원인 조사·코드·Rules 수정과 배포를 시작하지 않는다.
- Character 변경 자동 이동·파란 안내 제거, 그룹 listing, 추방·완료와 `memberMoved` 알림은 아직 별도 실기기 결과가 없으므로 전체 기능 완료로 닫지 않는다.

# 2026-09-14 BUG-018 다인 모집 해산 권한 회귀 수정

- 단독 해산과 달리 다인 해산은 파티장 외 멤버에게 `partyDisbanded` 이벤트를 생성한다. 기존 Player event Rules가 type 선분기 없이 모든 계열 validator를 OR로 평가해 무관한 cycle 조회까지 수행하던 경로를 type 선분기로 제한했다.
- v2 모집 해산 Transaction이 슬롯 Claim을 삭제하지 않아 고아 점유가 남는 수명 누락도 확인했다. 모든 membership의 대응 Claim을 먼저 읽어 `playerId`를 검증하고 membership·assignment·listing과 원자적으로 삭제한다. membership 삭제에서 슬롯 부재를 역조회하는 Rules는 8인 문서 접근 한도를 침범할 수 있어 추가하지 않고 기존 슬롯 삭제 권한 검증을 유지했다.
- 기존 `validRecruitmentDisband`, 리더·revision·assignment·listing·이벤트 수신자 검증은 완화하지 않았다.
- 해산·슬롯·이벤트 표적 계약 18건과 모집·파티 상세·그룹 영향 회귀 549건이 통과했고 변경 파일 정적 분석은 문제 0건이었다. 전체 Rules는 로컬 Emulator 시작 단계에서 정상 컴파일됐다.
- 실제 Transaction Emulator 실행은 기존 전체 Rules 재업로드 503과 Node SDK gRPC 전송 오류로 완료하지 못했으며 통과로 기록하지 않는다. 최신 추적본 운영 배포와 공개·그룹 다인 해산 실기기 확인이 남았다.
- 커밋 `a5a28d6`에서 `firebase.json`의 `firestore.rules`와 대상 `lost-party`를 재확인하고 운영 배포를 한 번 시도했다. `/test`는 HTTP 200으로 컴파일 성공·경고 0건이었지만 `/rulesets` POST가 HTTP 503으로 실패해 `/releases` 갱신에는 도달하지 않았다. 운영 활성 Rules는 이전 ruleset을 유지하며 같은 명령을 반복하지 않았다.

# 2026-09-14 파티 원자 탈퇴·승계와 그룹 활성 모집 집계 계획

- 기존 `memberPlayerIds`와 신규 Aggregate `partySlots`의 생성·가입 순서가 동일함을 확인하고, 파티장 탈퇴 시 탈퇴자를 제외한 첫 번째 잔류 Player를 후임으로 삼는 기존 제품 정책을 유지했다.
- 일반 탈퇴·추방은 모집 Aggregate, 대상 membership 삭제, 대상 `raidState` 삭제와 공용 이벤트 한 건만 쓰도록 계획했다. 파티장 탈퇴만 후임 membership 한 건을 추가 갱신하며 최대 쓰기는 5건이다.
- 마지막 한 명의 탈퇴는 일반 제거 계획에서 거절하고 기존 원자 해산 명령으로 분리해 모집 종료와 점유 해제가 갈라지지 않게 했다. 그룹 자격 여부는 직접 대상 문서에서 확인한 boolean으로 `nonGroupMemberCount`만 고정 크기로 조정한다.
- 그룹 원본 `activeRecruitmentCount`의 생성·종료 증감과 0일 때만 해산하는 검증 계획을 추가했다. 연결 모집 최대 20개 순회는 신규 구조에서 사용하지 않는다.
- 신규 및 직접 영향 회귀 14건과 변경 파일 정적 분석이 통과했다. 이 단계는 비연결 Write Plan이며 운영 Repository·Router/DI·Rules와 실제 Firebase는 변경하지 않았다.

# 2026-09-14 그룹 자격 집계 Snapshot과 공개 범위 전환 계획

- 참가·신청 이후 그룹 탈퇴 여부를 현재 시점에서 다시 조회해 과거 집계를 감소시키면 값이 어긋나는 위험을 확인했다. 슬롯에는 `countedAsNonGroupMember`, 신청에는 `countedAsNonGroupApplicant`를 생성 당시 고정해 제거·철회·승인이 동일한 집계를 정확히 되돌리도록 보완했다.
- Aggregate 생성자는 슬롯 Snapshot 합과 `nonGroupMemberCount`가 다르면 거절한다. 캐릭터 변경과 자리 이동·교환은 이 Snapshot을 그대로 보존한다.
- 공개→그룹 전환은 `nonGroupMemberCount`와 `pendingNonGroupApplicantCount`가 모두 0인지 확인하고, 그룹→공개 전환은 listing 삭제와 그룹 `activeRecruitmentCount` 감소를 같은 계획으로 묶었다. 멤버·신청 전체 순회는 사용하지 않는다.
- 신규 및 직접 영향 테스트 37건과 변경 파일 정적 분석이 통과했다. 기존 운영 공개 범위 Repository·Router/DI·Rules 및 Firebase 데이터는 아직 변경하지 않았다.

# 2026-09-14 그룹 모집 완료 수명주기 Repository 보완

- 그룹 전용 1회성 모집 완료가 `activeRecruitmentCount`를 유지하고 listing만 completed로 갱신하던 비연결 Repository 계약 오류를 발견했다. 완료 순간 활성 수를 감소시키고 listing을 삭제하도록 수정했다.
- 활성 상태 해산도 같은 종료 경로를 사용하고, 이미 1회성 완료로 집계가 닫힌 뒤 실행하는 마무리 해산은 그룹 수와 listing을 다시 변경하지 않는다. 반복 모집의 회차 완료·취소·전환은 활성 수와 listing을 유지한다.
- 8인 쓰기 상한은 비그룹 완료 10건, 그룹 일반 수명주기 11건, 그룹 모집 종료 12건, 완료 후 해산 2건으로 다시 계산했다. 이는 Firestore Transaction 문서 쓰기 수이며 Rules의 전체 20회·개별 쓰기 10회 문서 접근 제한과 구분한다.
- 격리 Rules와 Emulator 시나리오에도 1회성 완료 종료 및 완료 후 해산의 이중 감소 방지를 반영했다. 관련 Dart 계약·Repository·Rules 정적 테스트 30건과 변경 파일 정적 분석이 통과했고, GitHub Actions 실행 `34857997972`의 1·2·4·8인 Emulator 증명도 통과했다.

# 2026-09-15 파티 원자 탈퇴·추방 Firestore Repository

- 새 Aggregate 전용 탈퇴·추방 Repository와 Domain 인터페이스를 추가했다. 한 Transaction에서 인증 binding, 모집 원본, 대상 membership·`raidState`, 필요 시 후임 membership만 직접 읽고 모집·대상 삭제·후임 권한·그룹 listing·공용 이벤트를 갱신한다.
- 그룹 자격 상실 정리는 실행자가 현재 파티원 및 그룹원이고 대상이 현재 그룹원이 아닌 경우만 허용한다. 대상이 파티장이면 기존 구현의 누락과 달리 가입 순서 후임의 승인 권한도 함께 승계한다.
- 일반 제거는 공용 모집에서 최대 4건, 그룹 listing 포함 최대 5건이며 파티장 승계는 각각 최대 5·6건이다. 전원 membership 조회, 별도 slot, 기존 assignment·Claim과 Player별 event fan-out은 사용하지 않는다.
- 관련 Write Plan·수명주기 회귀 18건과 변경 파일 정적 분석이 통과했다. 새 Repository는 운영 Router/DI와 Rules에 연결하지 않았고 실제 Firebase에는 접근하지 않았다.

# 2026-09-16 F1 그룹 쓰기 복구 자동 검증·운영 Rules 게시

- 그룹장 이전은 그룹 1건과 membership 2건, 일반 탈퇴·1인 해산은 그룹·본인 membership·membership state·relation의 고정 문서만 쓰는 구조를 유지했다. 파티 인원·그룹원·`raidListings` 수에 따른 fan-out으로 되돌리지 않았다.
- `validGroupDisbandUpdate`에 `activeRecruitmentCount` 정수·0 조건을 추가해 활성 그룹 모집이 있는 1인 그룹의 해산을 서버에서도 차단했다.
- 실제 Rules Emulator 검증 중 과거 membership에 `gemValidationSnapshot` 등 선택 필드가 없을 때의 평가 오류를 확인했다. 세 선택 필드는 누락/null/정상 타입을 허용하되, 갱신 허용 필드와 타입 제한은 그대로 유지했다.
- 그룹장 이전에서 `groups` update OR와 membership update OR가 앞선 무관한 validator를 모두 평가해 표현식 1,000개 한도를 넘는 문제를 확인했다. 이전·role 변경 validator를 각 OR 앞쪽으로 옮겼으며 판정 조건과 쓰기 범위는 완화하지 않았다.
- 표적 Rules 계약 38건과 변경 파일 정적 분석이 통과했다. 로컬 Flutter wrapper의 오래된 전역 lock은 사용자 프로세스를 종료하지 않고 동일 Flutter tool snapshot 직접 실행으로 우회했다.
- GitHub Actions `35055217000`에서 전체 추적 Rules 기준선과 그룹장 이전→기존 그룹장 탈퇴, 일반 탈퇴, 1인 해산, 활성 모집 중 해산 거부가 모두 통과했다.
- 브랜치·원격 HEAD `8600a5b`, `firebase.json`의 Rules 경로와 대상 `lost-party`를 재확인했다. SHA-256 `A8E9D51EF6F52E2B38BAE1F72462B98F78A2DA105B1522C47152B54BBE54BA1B`의 `firestore.rules`만 1회 게시했고 컴파일·업로드·release가 성공했다. Indexes와 다른 Firebase 자원은 게시하지 않았다.
- 실기기 미확인: 그룹장 이전, 이전 그룹장 탈퇴, 일반 멤버 탈퇴, 마지막 1인 해산, 활성 모집 중 해산 차단 안내. 이 확인 전에는 F1을 완료로 닫거나 F2로 넘어가지 않는다.

# 2026-09-16 F1 후속 회귀 — 초대코드 가입

- 실기기에서 그룹 생성·초대 수락·검색 신청 수락·그룹장 이전·일반/기존 그룹장 탈퇴·1인 해산은 통과했고 초대코드 가입만 권한 안내로 실패했다.
- 앱의 코드 가입 Write Plan과 동일한 그룹·멤버·membership state·Player Projection 원자 쓰기를 전체 추적 Rules Emulator에 추가했다. 최초 실행 `35074490029`에서 Firestore Rules 표현식 1,000개 한도 초과를 재현했다.
- 코드 가입 검증을 OR 앞쪽에서 판정하도록 순서를 조정했다. 첫 수정은 기존 탈퇴 회귀가 실패하여 게시하지 않았고, 해산·그룹장 이전·탈퇴 우선순위를 보존한 최종 수정에서 `35075221872`의 코드 가입 및 F1 수명주기 Emulator가 모두 통과했다. Rule 허용 조건과 문서 쓰기 수는 완화·증가시키지 않았다.
- Rules·Write Plan 표적 41건 및 `git diff --check`가 통과했다. 변경 테스트 파일의 `flutter analyze`는 로컬 Flutter 프로세스가 출력 없이 정지하여 완료로 기록하지 않는다.
- 운영 대상 `lost-party`, `firebase.json`의 `firestore.rules` 경로와 최신 추적 Rules SHA-256 `716FDBAF1C993444E6AF2C599328788DA0704206ED193B27F59D492EC480CDE6`를 확인했다. 운영 게시 명령은 자동 안전 심사에서 거절되어 실행되지 않았다. 명시 승인 전에는 재시도·우회하지 않는다. 실기기 코드 가입은 미확인이다.
- 이후 사용자가 Rules를 별도로 게시하고 실기기에서 초대코드 가입 성공을 확인했다. AI는 재배포하지 않았으며 활성 Rules 소스의 해시는 직접 대조하지 않았다. 따라서 정상 코드 가입 회귀 복구는 사용자 실기기 확인으로 기록하고, 무효·폐기 코드와 중복 가입의 이번 실기기 확인은 별도 미확인으로 둔다.

# 2026-09-16 C* 기능 복구 F1 — 그룹 해산 차단 안내 실기기 확인

- 사용자가 1인 그룹의 활성 그룹 전용 모집이 있는 상태에서 그룹 해산이 차단되고 전용 안내가 표시됨을 실기기에서 확인했다. 앞서 확인한 그룹 생성·직접 초대·검색 가입·초대코드 가입·그룹장 이전·일반/기존 그룹장 탈퇴·1인 해산과 함께 F1 주요 흐름을 복구 판정한다.
- Repository의 `activeRecruitmentCount > 0` 전용 실패 결과, Rules의 0 조건, 화면 안내를 대조했고 그룹 Write Plan·안내·Rules 계약 표적 테스트 49건이 통과했다. 이번 확인에서는 기능 코드·Rules·Firebase 배포를 변경하지 않았다.
- 무효·폐기 초대코드와 중복 가입의 이번 실기기 재검증은 최종 회귀에 남긴다. 다른 공대장이 소유한 그룹 전용방을 그룹장이 직접 정리하는 기능은 F4 범위이며 F1 완료로 간주하지 않는다.

# 2026-09-16 C* 기능 복구 F2-A — 신청 재진입 Rules 경계 진단

- 운영 Router의 원자 신청 Repository를 기준으로 공개방 신청→철회→재신청을 demo 전체 Rules Emulator에서 통과시켰다(`35087432007`). 그룹 연결 공개방에서 신청 당시 비그룹 분류가 바뀌는 재신청은 application update 평가의 표현식 1,000개 한도 `PERMISSION_DENIED`로 재현했다(`35087675480`).
- 현재 그룹 membership과 일치하는 `countedAsNonGroupApplicant` 재신청 변경만 허용하고 신청 update의 상태별 Rules 평가를 분리했다. 공개·그룹 전용 재신청 허용/변조 거절과 기존 그룹 F1 회귀가 `35104711642`에서 통과했다. Flutter 표적 46건, 변경 테스트 파일 분석 및 diff 검사도 통과했다.
- Rules SHA-256 `AAB74C69483AE1C46AF69C3D8378F30573581AAA1FCBBB1485181BFBD31255D5`의 운영 게시 시도는 자동 안전 심사에서 거절되어 **명령 자체가 실행되지 않았다**. 운영 Rules 변경·실기기 완료로 기록하지 않으며, 우회·반복 시도 없이 특정 버전의 게시 승인 전까지 보류한다.
- 이후 사용자가 해당 Rules 버전 게시를 승인했다. CLI 실행 결과는 작업 중단으로 복구하지 못했으나, 사용자가 운영에 게시된 Rules와 로컬 파일의 내용이 동일하다고 직접 확인했다. 로컬 해시는 위 값 그대로다. 운영 소스 일치는 사용자 확인이며 CLI 성공 로그·컴파일 경고 0건이나 F2-A 실기기 성공을 의미하지 않는다. 같은 소스 재게시 없이 공개·그룹 전용 신청 상태 전이를 실기기에서 확인한다.

# 2026-09-18 F6-A 특정 캐릭터 권한 오류 진단 완료

- 승인 실패와 수동 완료 실패를 서로 다른 원인으로 분리했다. 전자는 삭제된 모집을 참조하는 `니티야`의 고아 `raidState`, 후자는 `이슈아이`의 수동 완료 사전 검사에서 해산된 그룹방의 접근 불가 pending 신청 부모를 읽는 코드 경로다. 정확한 ID와 근거는 `BUG_REPORTS.md` 2026-09-18 항목을 따른다.
- 수동 완료 Repository에 디버그 단계 로그만 추가한 APK로 첫 실패 지점을 실기기에서 재현했다. 변경 파일 정적 분석 0건, 계정 체크 표적 테스트 5건, 디버그 APK 빌드·데이터 유지 설치가 통과했다. 기능 수정·Rules 게시·서버 데이터 정리는 하지 않았다.
- 다음 작업은 `NEXT_WORK.md` F6-B1의 조회 경계 최소 수정이다. 진단 로그와 문서 변경은 작업 브랜치에 미커밋이며, F6-B1 검증 후 로그 유지/제거를 결정한다.

# 2026-09-18 F6-B1 수동 완료 체크 표적 복구

- 접근할 수 없는 과거 그룹 모집의 pending 신청 부모 조회가 `permission-denied`일 때 해당 신청만 제외하도록 수동 완료 사전 분류를 좁게 수정했다. 정상 부모 조회와 다른 Firebase 오류의 처리, 서버 문서·Rules는 변경하지 않았다.
- 신규 조회 경계 테스트 3건과 기존 내 계정 완료 표적 테스트 5건, 변경 파일 정적 분석이 통과했다. Claim 존재 시 파티 승인 거절은 기존 Rules Emulator 계약 테스트에 포함돼 있으나 이번 변경으로 Emulator를 새로 실행한 결과는 없다.
- 사용자가 `이슈아이` 수동 완료 체크·해제, 완료 상태일 때 동일 레이드 모집의 캐릭터 선택 차단, 정상 pending 신청 1건의 취소 안내와 실제 지원 취소를 확인했다. 임시 단계 로그를 제거해 B1을 완료 판정한다. 주차 전환과 새 `raidState` 통합은 B2/F7에 남기며 전체 F6 완료로 확대 판정하지 않는다.
- 이후 실기기 설치·조작·테스트는 사용자가 수동 진행한다. 에이전트는 코드·자동 검증을 마친 뒤 확인 항목을 전달하고, 필요할 때만 구간 종료 후 로그 수집을 요청한다. 다음 작업은 `NEXT_WORK.md` F6-B2 상세 설계다.

# 2026-09-18 F6-B2 통합 완료 상태 상세 설계

- 운영 Router를 대조해 파티 전체 완료는 원자 lifecycle에서 `raidState active → completed`를 사용하지만 내 계정 표시·수동 완료는 구 `weeklyRaidClaims/activeRaidAssignments`만 사용한다는 전환 간극을 확정했다. 구 Cycle Repository의 Claim fan-out을 복원하지 않는다.
- 신규 완료·참가 원장은 `raidState`, 구 Claim은 state가 없는 과거 데이터의 호환 읽기·해제로 정했다. active state와 Claim이 동시에 있는 불일치는 자동 삭제하지 않는다. 수동 개인 완료와 모집 상세의 파티 전체 완료는 별도 명령으로 유지한다.
- 구현을 B2-A 읽기 Projection, B2-B 파티 밖 수동 state, B2-C 활성 참가 개인 완료, B2-D 해제·반복방 경계로 나눴다. 핵심 Aggregate/membership/state는 앱 재실행 후처리에 의존하지 않고 원자 확정하며, pending 신청 수에 따른 Rules 접근 예산은 구현 전에 검증한다.
- 장기 계약은 `WEEKLY_RAID_CLAIM_CONTRACT.md` §0, 실행 순서와 회귀 조건은 `NEXT_WORK.md` F6-B2에 기록했다. 이번 구간에서는 기능 코드·Rules·배포를 변경하지 않았다. 다음 구현은 B2-A다.

# 2026-09-18 F6-B2 기존 계약·UX 교차검토

- 실제 운영 Router, C* 확장성 계약, 참가 제품 정책과 F6-B2 초안을 다시 대조했다. active 상태를 완료 Claim으로 변환하지 않고 `none/active/completed/legacyActive/legacyCompleted/inconsistent` Projection으로 분리하며 `cycleKey`를 항상 검증하도록 계약을 보정했다.
- 동일 레이드 pending 신청은 최대 파티 인원 8명과 무관하게 늘어날 수 있으므로 전체 신청 종료를 완료 핵심 Transaction에 넣는 초안을 폐기했다. completed `raidState`가 승인·가입을 최종 차단하고, stale pending 무효화·정리는 비핵심 경로로 분리한다.
- 기존 개인 체크 해제 UX를 보존하면 반복방 다음 주차 전환에 필요한 state가 빠질 수 있음을 확인했다. 개인 해제는 자기 완료 state만 삭제하되 파티 완료 취소는 대상 누락 시 전부 거절하고, 다음 주차 전환은 현재 membership을 근거로 누락 active state를 생성하도록 B2-D 완료 조건을 보강했다.
- 구 `activeRaidAssignment`도 Claim과 함께 fallback·불일치 판정에 포함했다. state와 legacy 문서가 동시에 있으면 한쪽 해제 뒤 다른 기록이 되살아나는 회귀를 막기 위해 내용 일치 여부와 무관하게 변경을 차단한다. 활성 파티 개인 완료의 state는 `source: manual`로 전환하되 기존 `recruitmentId`를 감사·Rules 검증용으로 보존한다.
- 페이지·역할별 UX 회귀표를 `NEXT_WORK.md`에 추가하고 `PARTY_PARTICIPATION_RULES.md`의 Claim 최종 원장 표현을 C* state 기준으로 갱신했다. 이번 교차검토는 문서만 수정했고 기능 코드·Rules·배포는 변경하지 않았다.
- 모집 후보는 현재도 `FirestoreActiveRaidAssignmentLookup`과 `PartyCreateOccupancyGate`로 연결 모집의 종료·만료·고아 여부를 추가 판정한다. 공통 주간 Projection은 원장 해석만 담당하고 이 점유 게이트나 내 계정의 탈퇴 영향 계산을 대체하지 않도록 B2-A 연결 순서를 세분화했다.

# 2026-09-19 F6-B2-A 현재 주차 읽기 Projection 구현

- `raidState`·구 Claim·구 assignment를 `active/completed/legacyActive/legacyCompleted/inconsistent`로 해석하는 순수 Projection과 Firestore Repository를 추가했다. 모든 문서의 Player·Character·raidId·cycleKey·문서 ID를 검증하고 state와 legacy가 겹치면 자동 병합하지 않는다.
- 운영 Router의 내 계정·모집 생성·신청 후보에 공통 읽기를 연결했다. completed는 완료로만 표시하고 active는 기존 `PartyCreateOccupancyGate`의 종료·만료·고아 판정을 거쳐 참가 중으로 표시해 두 상태를 중복 경고하지 않는다.
- B2-A는 읽기 단계이므로 현재 `active/completed/inconsistent` state 체크박스를 읽기 전용으로 뒀다. 구 Claim 명령이 state를 변경하지 못하고도 성공을 표시하는 회귀를 막고, 신규 state 쓰기와 활성 참가 개인 완료는 각각 B2-B/C에 남겼다.
- Rules는 본인 `raidStates/activeRaidAssignments` list만 열고 타인 list·legacy assignment 쓰기를 계속 거절한다. 표적 47건, 변경 21개 Dart 파일 analyze, JS 문법과 `git diff --check`가 통과했다. 전체 `flutter test`는 1,171건 통과·17건 실패로 직전 기준선 17건을 유지했고, 전체 analyze는 기존 38건만 보고했다.
- 로컬 Rules Emulator는 Android Studio JBR 21로 기동했으나 Rules 로딩 단계의 기존 `503 Network closed for unknown reason`로 중단돼 허용·거절 시나리오를 실행하지 못했다. 작업 브랜치 GitHub Actions `35412398666`에서는 전체 추적 Rules 회귀와 B2-A 본인 현재 주차 list 허용·타 Player list 거절이 모두 통과했다.
- 사용자 승인 후 SHA-256 `51146C8DF8B12493AE5B3DACAD47D533A74D242C25F57930FAAA49BF2E0280CC`의 `firestore.rules`만 운영 `lost-party`에 1회 게시 시도했다. 원격 컴파일 `/test`가 HTTP 503 `UNAVAILABLE`로 끝나 Ruleset 업로드·release에는 도달하지 않았고 운영 Rules는 갱신되지 않았다. 같은 명령을 반복하지 않으며 새 지시 전에는 실기기 확인·B2-B·`dev/main` 통합을 진행하지 않는다.

# 2026-09-19 F6-B2 완료 UX 회귀 판정과 재설계

- 사용자가 Rules를 콘솔에서 별도로 게시한 뒤 `2인 전체 완료 권한 실패`, `1인 완료·해산 후 완료 기록 누락`, `raidState 완료 체크 해제 불가`를 실기기에서 확인했다. 콘솔 활성 소스와 로컬 해시는 직접 대조하지 않았다.
- 다인 완료 실패는 원자 Repository가 해산 외 lifecycle에서 모든 대상의 private `raidState`를 읽는 반면 Rules는 본인 get만 허용하는 구조로 확정했다. 혼자 완료와 해산 성공·타인 참가 시 완료 실패의 차이를 설명한다.
- 완료 기록 누락은 공용 lifecycle 이벤트에 Character·raid·difficulty·cycle Snapshot이 없고 sync가 네 필드 누락 이벤트를 건너뛰는 구조로 확정했다. 공용 이벤트 한 건 원칙은 유지하되 최대 8명의 수신자별 Character 대상과 공통 레이드 Snapshot을 보존한다.
- B2-A의 읽기 전용 체크박스는 사용자 요구가 아니라 구현 중간 단계에서 추가된 제한이며 기존 개인 해제 계약을 위반한다. 안내 아이콘은 유지하지만 checkbox를 막지 않고 active 개인 완료와 completed 개인 해제 명령까지 연결한 상태만 사용자 완료로 판정한다.
- `파티 전체 완료 → 각자 완료 기록 → 완료방 해산 → 내 계정 체크 유지 → 본인 해제 → 재참가 가능`을 F6-B2-R 하나의 인수 단위로 재정의했다. 구현은 R1~R4로 나누되 전체 앱 Repository 인증 흐름과 실기기 사이클이 통과하기 전 게시 가능·완료·통합 상태로 기록하지 않는다. 이번 구간은 문서 설계만 변경하며 코드·Rules·Firebase 데이터는 수정하지 않았다.

# 2026-09-19 F6-B2-R1 다인 완료 권한 경계 복구

- `FirestorePartyAtomicCommandRepository`가 완료·완료 취소·주차 전환에서 모든 대상 Player의 private `raidState`를 선조회하던 경로를 제거했다. 해산과 동일하게 클라이언트는 대상 경로만 구성하고, 모집 Aggregate 대상 일치와 각 state 전이는 기존 Write Plan·Rules에 맡긴다.
- 인증 binding·모집 Aggregate·필요 시 그룹 원본 읽기, 공용 이벤트 한 건과 최대 8인 제한은 유지했다. Rules·이벤트 Payload·UI·운영 Firebase는 이번 구간에서 변경하지 않았다.
- Repository 계약 5건, Write Plan 9건, lifecycle Rules 계약 5건, 확장성 계약 6건 등 표적 25건과 변경 파일 정적 분석이 통과했다. 실제 앱 인증 흐름의 공개·그룹 1·2·4·8인 Emulator 검증은 R4에 남기므로 전체 완료 UX나 B2 완료로 판정하지 않는다.

# 2026-09-19 F6-B2-R2 공용 완료 이벤트 Snapshot 구현

- 원자 lifecycle Aggregate에 `raidId/difficultyId`를 포함하고, schemaVersion 2 공용 완료·완료 취소 이벤트에 공통 `raidId/difficultyId/cycleKey`와 최대 8개 `completionTargets[{playerId, characterId}]`를 기록한다. 이벤트 문서 수는 한 건으로 유지했다.
- Rules는 변경 후 모집 `partySlots`와 audience·완료 대상을 같은 순서로 최대 8개 한 번씩 검증한다. 각 대상 검증에는 추가 문서 조회가 없으며 schemaVersion 1 lifecycle create는 구 앱 호환 계약으로 유지한다.
- Event Mapper는 공용 대상에서 현재 Player의 Character를 하나만 선택하고, 누락·중복·손상 대상은 완료 기록으로 사용하지 않는다. Sync는 매핑된 Character·레이드·난이도·주차를 Drift 완료 기록에 전달한다.
- 관련 Flutter 표적 63건, 변경 파일 분석, JS 문법과 diff 검사가 통과했다. 로컬 demo Emulator는 기존 Rules 로딩 503으로 중단됐지만 작업 브랜치 GitHub Actions `35417265039`에서 Rules 컴파일·로딩과 1·2·4·8인 lifecycle, 완료 대상 누락·Character 위조 거절이 모두 통과했다. 운영 Rules 배포·실기기 테스트·R3 체크박스 복구는 수행하지 않았고 F6-B2-R 전체 완료로 판정하지 않는다.

# 2026-09-19 F6-B2-R3 개인 완료 체크 UX 계약 정정

- 내 계정 체크박스는 서버의 돌이킬 수 없는 완료 판정이 아니라 사용자가 현재 주차의 레이드 흐름을 관리하는 개인 UX로 확정했다. `방 생성 → 완료 → 체크 해제 → 재생성 → 완료 → 재해제`와 공대장의 실수 완료 뒤 일반 참가자의 개인 해제는 정상 흐름이다.
- 기존 문서의 `inconsistent만 조작 차단` 문구는 이 UX와 충돌하므로 폐기했다. 불일치는 진단 상태로만 사용하며, 본인 소유·Character·raidId·현재 cycle을 검증할 수 있는 완료 state/구 Claim은 한 번의 개인 해제로 제한적으로 정리한다. active state·구 assignment·membership은 보존하고 남은 참가 상태로 모집 가능 여부를 다시 판정한다.
- 소유권이나 식별자를 증명할 수 없는 손상 문서는 자동 삭제하지 않고 구체적인 복구 안내로 보낸다. 개인 해제는 공동 완료 Snapshot·다른 Player·해산된 방을 변경하지 않으며, 파티 전체 완료 취소는 개인 변경이 있으면 계속 원자 거절한다.
- 이번 정정은 계약·실행 문서만 변경했다. R3 기능 코드·Rules·배포는 아직 진행하지 않았으며 다음 구현은 이 계약을 기준으로 한다.

# 2026-09-19 파티 전체 완료 취소 정책 폐기

- 기존 완료 취소는 `다음 주도 함께하기` 방에서 완료 뒤 구성 변경이 없을 때만 허용하는 제한적 공동 롤백이었으나, 복원 상태와 개인 체크 정정이 충돌해 전체 완료 UX를 복잡하게 만드는 것으로 판단했다.
- 같은 주차의 파티 전체 완료 취소 기능을 폐기한다. 모집 상세 버튼, 신규 `cancelCompletion` 호출, Write Plan과 Rules 허용은 제거 대상이며 책임자가 다른 사용자의 완료나 과거 참가 상태를 되돌리는 경로를 제공하지 않는다.
- 잘못된 완료는 각 사용자가 내 계정에서 자기 완료 체크만 해제한다. 반복방은 완료 당시 membership을 유지하고 수요일 06시 새 주차 전환에서 새 `active` 상태를 구성한다.
- R1의 완료·주차 전환 권한 경계와 R2의 완료 이벤트 Snapshot은 계속 유효하다. 당시 함께 추가된 완료 취소 분기만 제거하며 과거 `completionCancelled` 이벤트·Drift 기록은 읽기 호환을 유지한다.
- 이번 단계는 문서만 수정했다. 코드·Rules·배포는 변경하지 않았고 다음 R3 구현 범위에 완료 취소 제거와 개인 체크 조작 복구를 함께 기록했다.

# 2026-09-19 F6-B2-R3 중단 구현 복구·자동 검증 진행

- 중단된 작업 트리를 보존해 개인 완료 명령을 `raidState` 원장에 연결했다. 미참가 수동 완료/해제, 활성 참가자의 탈퇴+완료, 파티장 후임 승계, 마지막 1인 해산, 그룹 listing·활성 수 정리를 각 핵심 Transaction 안에서 처리한다. pending 신청 정리는 인원수와 무관한 비핵심 후처리이며 타인 private state 선읽기와 Player별 이벤트 fan-out을 추가하지 않았다.
- 파티장 개인 완료 Rules에 후임 membership의 Player·Character/Class Snapshot·승인 권한 검증을 추가했다. `weeklyRaidCompleted` 탈퇴 이유, 완료 state 기반 생성·신청·승인 차단, 본인 completed state와 호환 Claim의 제한적 해제를 계약에 반영했다. 파티 전체 완료 취소 실행 경로는 제거하고 과거 이벤트 읽기만 유지한다.
- 반복방 다음 주차 전환은 현재 membership/`partySlots`를 근거로 누락 state를 생성하거나 같은 모집의 기존 state를 갱신한다. 새 주차 시간창은 정확히 7일이며 요청 시각이 시작 이상·종료 미만이어야 한다. 다른 모집·새 주차 수동 완료 state는 덮어쓰지 않는다.
- 개인 완료·해제, 일반 멤버·파티장·마지막 1인, 그룹 전용 마지막 1인, 반복방 state 재생성 및 기존 lifecycle 표적 테스트와 핵심 변경 파일 분석은 통과했다. 전체 `flutter analyze`는 기존 lint를 포함한 50건을 반환했다. 전체 `flutter test`는 계약 갱신 전 1,183건 통과·13건 실패였고, 현재 작업에서 바뀐 legacy assignment 계약 테스트는 갱신 후 단독 통과했다. 기존 활동 Character Rules 문자열 및 Firebase 미초기화 최상위 위젯 테스트 등 기준선 실패는 남아 있어 전체 회귀 통과로 기록하지 않는다.
- 로컬 Firestore Emulator는 CLI 설정 경로와 Android Studio JBR 21을 명시해 기동했으나 Rules 로딩 단계의 기존 `503 Network closed for unknown reason`로 시나리오 전에 중단됐다. 재시도하지 않는다. 운영 Rules 배포와 실기기 조작은 하지 않았으며, 다음 게이트는 작업 브랜치 커밋·demo Rules CI다.

# 2026-09-19 F6-B2-R3 Rules 예산 복구 후속 체크포인트

- R3 구현을 `dfe0440`, Rules 우선순위 보정을 `e660c4c`, 개인 완료 명령 표식과 마지막 1인 전용 경량 검증을 `b5769bf`로 작업 브랜치에 커밋·푸시했다. 현재 `feature/party-group-command-redesign`의 로컬과 원격은 `b5769bf`로 같고 작업 트리는 깨끗하다. `dev/main` 통합과 운영 Rules 게시, 실기기 조작은 하지 않았다.
- `b5769bf`는 기존 모집 Aggregate의 `lastCommand*` 필드에 `personalComplete`를 기록해 개인 완료 하위 쓰기가 같은 원자 명령을 짧게 식별하도록 바꿨다. 새 문서나 Player별 이벤트 복제, 타인 private state 선읽기는 추가하지 않았다.
- GitHub Actions `35443055507`에서 추적 Rules 컴파일, 개인 수동 완료·해제, 반복방 누락 state 재생성, 공개방 마지막 1인 완료·해산, 그룹방 마지막 1인 완료·listing/활성 수 정리가 통과했다. 이전 실행에서 막혔던 마지막 1인 개인 완료는 복구됐다.
- 다음 다인방 시나리오 준비의 정상 신청 생성에서 application create·recruitment update·party event create가 함께 평가되며 Firestore Rules `maximum of 1000 expressions`에 도달했다. 일반 멤버 개인 완료 명령까지 도달하기 전 실패이므로 정상 신청 회귀이며 R3 완료로 볼 수 없다.
- 단순 OR 순서 변경은 이미 실패했다. 다음 작업은 모집 update의 `personalComplete` 표식을 값싼 선행 게이트로 분리해 해당 명령에만 상세 개인 완료 검증을 평가하도록 하는 것이다. 신청 검증을 삭제·완화하지 않으며, 정상 신청·승인 뒤 일반 멤버 완료, 파티장 완료와 승계, 위조 후임 Snapshot 거절 순으로 같은 demo CI에서 확인한다.
- 사용 한도나 세션 중단 시 재개 기준은 대화 요약이 아니라 추적 커밋, 깨끗한 작업 트리, `NEXT_WORK.md`의 첫 실패 단계와 CI 실행 ID다. 미커밋 변경이 있을 때는 소유·목적을 확인하기 전 초기화하지 않고, 검증 가능한 중간 단위는 작업 브랜치에 커밋·푸시한 뒤 남은 실패와 다음 한 동작을 문서에 기록한다.

# 2026-09-19 F6-B2-R3 Rules 표현식 예산 회귀 복구

- `4abdb89 fix: gate personal completion rule evaluation`에서 모집 update가 `personalComplete` 명령 표식을 먼저 확인한 경우에만 개인 완료 상세 Rules를 평가하도록 경량 게이트를 추가했다. 일반 신청·승인 등 다른 명령의 검증 조건은 변경하거나 완화하지 않았다.
- JS 문법, `git diff --check`, R3 정적 계약 테스트 5건이 통과했다. Flutter 묶음 실행 한 번과 `dart format` 단독 실행 한 번이 출력 없이 정지해 중단했으나, 이후 표적 Flutter 테스트를 개별 실행해 정상 통과를 확인했다. 이를 코드 실패로 기록하지 않는다.
- 작업 브랜치 GitHub Actions `35448981992`에서 추적 Rules 컴파일과 전체 회귀가 통과했다. 개인 수동 완료·해제, 반복방 누락 state 재생성, 일반 멤버/파티장/마지막 1인/그룹방 개인 완료, 후임 승계와 위조 Snapshot 거절뿐 아니라 정상 신청·승인, 자리 변경, 추방·재가입, 2·4·8인 해산 및 그룹 회귀가 모두 통과했다.
- R3 자동 검증은 완료했지만 운영 Rules 게시와 실기기 R4 검증은 아직 수행하지 않았다. 다음 게이트는 최신 추적 Rules의 대상 프로젝트·경로·diff 확인 후 운영 게시 1회이며, 이후 사용자가 실기기 흐름을 수동 확인한다. 그 전에는 B2 완료나 `dev/main` 통합으로 판정하지 않는다.

# 2026-09-19 F6-B2-R3 운영 Rules 게시 503 보류

- 배포 전 현재 브랜치 `feature/party-group-command-redesign`, 깨끗한 작업 트리, `firebase.json`의 Rules 경로 `firestore.rules`, `.firebaserc` 기본 프로젝트 `lost-party`를 확인했다. 대상 Rules SHA-256은 `11593015457B155BCE11FEC2D185DEB039D49F62F1C10C70DFEC24012EDA5857`이다.
- `firebase deploy --only firestore:rules --project lost-party`를 정확히 한 번 실행했다. CLI는 Rules 원격 컴파일 `projects/lost-party:test`에서 HTTP 503 `The service is currently unavailable`로 종료됐다. Ruleset 업로드와 release에는 도달하지 않았고 Indexes·Functions는 배포하지 않았다.
- 같은 명령을 반복하지 않는다. 운영 활성 소스는 갱신되지 않은 것으로 단계상 판정하며 콘솔 원본 일치는 별도 확인하지 않았다. 사용자가 결과를 확인하고 콘솔 게시 또는 재시도를 새로 지시하기 전에는 R4 실기기 검증, B2 완료 판정과 `dev/main` 통합을 진행하지 않는다.

# 2026-09-19 테스트 비용 최소화 정책 확정

- 실제 디바이스 2기로 같은 정상 UX 결과를 직접 확인할 수 있으면 동일 자동 UI·통합 테스트를 중복 실행하지 않는다. 자동 검증은 Security Rules 권한·위조 요청·동시성·원자성·주차 경계처럼 실기기로 만들기 어렵거나 안전하지 않은 경계에 집중한다.
- 동일 구현의 인원수 검증은 2인·4인·8인을 반복하지 않고 현재 최대치인 8인 대표 사례 하나를 기본으로 한다. 마지막 1인 해산, 책임자 승계, 권한 거절처럼 상태 전이 자체가 다른 경우에만 별도 최소 사례를 유지한다.
- 중간 작업은 포맷·diff 검토를 기본으로 하고 전체 테스트·분석·CI를 관성적으로 반복하지 않는다. 코드가 바뀌지 않은 동일 검증은 재사용하며, 디바이스 수동 확인은 사용자가 수행한다.

# 2026-09-20 lifecycle 명령 enum 컴파일 회귀 수정

- 개인 완료 Rules marker를 읽기 위해 `PartyAtomicCommandType.personalComplete`를 추가한 뒤 lifecycle 전용 `PartyAtomicWritePlan`의 exhaustive switch가 누락돼 debug build가 실패했다.
- lifecycle command envelope는 개인 완료 marker 생성을 명시적으로 거절하고, Write Plan의 상태 판별도 `personalComplete`를 `false`로 처리하도록 보완했다. 개인 완료는 기존 전용 Repository/Transaction만 사용하며 lifecycle Write Plan의 허용 범위를 넓히지 않는다.
- Domain·Write Plan 표적 테스트 16건이 통과했다. 동일 결과를 확인하는 전체 CI·인원수 반복 테스트·실기기 조작은 실행하지 않았으며, 사용자가 실제 debug build로 확인한다.
# 2026-09-20 F6-B2 정상 완료 사이클 확인과 고아 참가 복구 설계

- 사용자가 앞서 전달한 디바이스 체크리스트의 정상 파티 완료·해산·개인 체크 유지/해제·재참가 흐름이 모두 통과했다고 확인했다. 인원수별 동일 UI 테스트를 추가 반복하지 않는다.
- 별도로 `players/kVn6KZwZQO6or3BjNYqX/raidStates/xseSyVxZXWhKYxlZEucb_kazeros_act4`가 존재하지 않는 모집 `td904kw3PEgWI1GwIfUP`을 `active`로 참조해 참가 표시, 수동 완료 상태 불일치, 신청 후 승인 권한 오류를 일으키는 것을 데이터로 확정했다.
- 정상 완료 흐름의 회귀와 과거 콘솔 삭제로 생긴 고아 데이터를 분리했다. 본인 단건 고아 active state는 F6-D의 명시적 `참가 기록 정리`로 복구하고, 다른 Character·raid의 고아 pending 신청 및 다수 데이터 일괄 정리는 별도 운영 도구 백로그로 유지한다.
- 이번 단계는 설계·문서 정리만 수행했다. 기능 코드·Rules·운영 데이터·브랜치 통합은 변경하지 않았다.

# 2026-09-20 F6-D D1~D3 단건 고아 참가 복구 구현

- 내 계정 수동 완료 영향 확인에서 본인 active party `raidState`의 연결 모집을 단건 조회해 원본 없음·종료·완료·만료 상태를 정상 참가와 분리한다. 존재하지 않는 새로고침 안내 대신 `참가 기록 정리` 확인창을 추가했다.
- 정리 Transaction은 Player·Character·raid·cycle·recruitmentId와 관찰 revision을 다시 검증하고, 여전히 stale인 경우에만 본인 `raidState` 및 정확히 일치하는 구 assignment를 원자 삭제한다. 완료 기록·신청·다른 상태는 변경하지 않으며 정상 활성 모집은 거절한다.
- 기존 stale `raidState` Rules를 재사용하고 구 assignment에 같은 본인·고아 조건의 delete만 추가했다. demo에는 원본 없는 본인 정리 성공, 타인 거절, 정상 활성 모집 거절 대표 시나리오를 추가했다. 공용 이벤트·인원수 비례 조회·후처리는 추가하지 않았다.
- JS 문법, Rules 문자열 계약, ViewModel 표적 9건과 변경 Dart 파일 정적 분석은 통과했다. 로컬 Rules Emulator의 기존 Windows 503은 반복하지 않았고, 작업 브랜치 Actions `35454451057`의 demo Emulator에서 전체 추적 Rules와 기존 그룹 회귀가 통과했다. 변경 Rules SHA-256은 `716402EF95051F6F07B799F275431B9A89718E7BA713A07EEEFB147FDCDCCC94`다. 이후 사용자가 Rules를 콘솔에서 한 차례 게시했다고 확인했으나 활성 소스 해시는 AI가 대조하지 않았다. 사용자 실기기 확인과 후속 신청 전 차단은 남아 있다.

# 2026-09-20 F6-D 이전 주차 고아·신청/승인 UX 설계 보완

- 현재 주차 `2026-09-16`에 다른 Player의 동일 Character·raid 경로에서 `cycleKey=2026-09-09`, `status=active`, `source=party` 문서가 발견됐다. 현재 주차 Projection에서 제외돼 느낌표가 없는 것은 정상이나, 완료 버튼은 고정 경로를 읽고 cycle 불일치로 정리 불가를 반환한다.
- 현재 주차 active 고아는 느낌표+정리, 이전 주차 active 고아는 현재 느낌표 없이 완료·생성·신청·즉시 가입 직전 exact-state 판정에서 정리 안내를 제공하도록 분리했다. 정리는 관찰한 과거 cycle/revision/recruitmentId를 검증하고 원래 동작을 자동 재실행하지 않는다.
- 이전 주차 completed와 유효 반복방은 고아로 삭제하지 않는다. completed는 정상 rollover, 반복방은 승계 또는 참가 충돌로 처리한다. 단순 cycle 불일치만으로 삭제하지 않는다.
- 신청자는 pending 저장 전에 본인 state와 연결 모집을 단건 판정한다. 방장은 타인 private state를 읽지 않으며 과거 pending/경쟁으로 승인 Rules가 거절되면 데이터 오류 안내와 기존 `신청 거절` 버튼을 제공한다. permission 오류의 원인이 항상 신청자 데이터라고 확정할 수 없으므로 자동 거절은 하지 않는다.
- 이번 단계는 설계·문서만 변경했다. 다음 구현 순서는 D4 과거 고아 확장 → D5 신청/즉시 가입 및 Rules 최종 차단 → D6 승인 실패 명시적 거절 UX다.

# 2026-09-20 F6-D D4 이전 주차 고아 판정·정리 구현

- `PartyCreateOccupancyGate.classifyExistingRaidState`를 추가해 고정 `raidState`를 현재/이전 주차 active 고아, 유효 참가 충돌, 현재/이전 주차 completed로 분리했다. 모집 원본 없음·종료·완료·만료 1회성만 고아이며 유효 반복방은 삭제하지 않는다.
- 내 계정 완료 사전 확인은 이전 주차 고아에 현재 참가 느낌표를 추가하지 않고 `지난 주차의 종료된 파티 참가 기록` 정리를 안내한다. 정리 Transaction은 화면의 현재 주차가 아니라 관찰한 state cycleKey·revision·recruitmentId를 재검증한다.
- 이전 주차 completed는 고아가 아니므로 수동 완료와 원자 모집 생성에서 기존 completed state를 본인 delete 계약으로 정리한 뒤 현재 주차 명령을 한 번 재시도한다. 신청·재신청·즉시 가입의 사전 차단은 D5로 유지한다.
- Rules는 변경하지 않았고 운영 배포도 하지 않았다. 공용 분류·기존 점유·ViewModel 표적 테스트 21건과 변경 파일 `flutter analyze`, `git diff --check`가 통과했다. 실기기 설치·조작은 수행하지 않았으며 D4 수동 확인은 사용자 검증으로 남긴다.
- 사용자 실기기에서 과거 고아 완료 데이터의 안내·정리가 정상 작동함을 확인해 D4의 해당 수동 항목을 완료했다.
- 후속 UX 위험을 기록했다. 이전 주차 고아는 현재 Projection에 나타나지 않아 사용자가 쓰기 동작 전에는 알기 어렵다. D5는 신청 저장 전에 신청자에게 정리를 안내해 잘못된 신청이 공대장에게 도달하지 않게 한다. 기존 pending 신청의 승인 실패를 공대장 측에서 자동 거절하는 기능은 현재 미구현이며, D6의 명시적 `신청 거절` 방식을 유지한다. 자동 거절은 오판·revision 경쟁 영향을 검토한 뒤 별도 결정한다.

# 2026-09-20 F6-D D5 신청·재신청·즉시 가입 사전 차단

- 운영 원자 신청·즉시 가입 Repository가 본인의 exact `raidState`와 active state의 연결 모집 한 건을 읽어 D4 공용 수명 판정을 재사용하도록 연결했다. 정상 참가·유효 반복방, 현재 완료, 현재/이전 고아, 이전 완료와 손상 데이터를 서로 다른 결과로 유지했다.
- 고아 결과에는 관찰한 Character·raid·cycle·recruitmentId·revision을 담고 모집 상세의 기존 본인 단건 정리 명령에 연결했다. 사용자가 명시적으로 정리한 뒤 원래 신청·가입을 다시 눌러야 하며 자동 삭제·자동 재신청은 하지 않는다. 이전 completed만 최대 2회 제한 Transaction으로 먼저 정리하고 모든 조건을 다시 읽는다.
- application create/reapply Rules는 최종 exact state가 없어야 pending 저장을 허용한다. 승인자는 타인의 private state를 읽지 않고 승인 실패 안내는 D6로 남겼다.
- 정적 Rules/수명 판정 13건, 모집 상세 46건, 변경 파일 분석, JS 문법과 diff 검사가 통과했다. 작업 브랜치 demo 전체 Rules Actions `35494192803`도 신청·재신청 state 차단과 기존 파티·그룹 회귀를 포함해 통과했다. Rules SHA-256은 `9228699FEB79F2F41AC782B8E4F98FF6AEE1F94248354B954CEF503AB2B65B0C`다. 운영 `lost-party` Rules 게시 1회 시도는 원격 컴파일 `/test` HTTP 503으로 끝나 Ruleset 업로드·release에 도달하지 않았고 운영 Rules는 미반영이다. 같은 명령은 반복하지 않으며 수동 게시·실기기 확인 전에는 D5를 최종 완료로 판정하지 않는다.

# 2026-09-20 F6-D 현재·이전 주차 고아 신청 복구 실기기 확인

- 사용자가 현재 주차 고아는 내 계정의 참가 느낌표와 정리 동작으로, 이전 주차 고아는 평상시 미표시되지만 다른 사용자의 동일 레이드 방 신청 시 나타나는 `참가 기록 정리` 안내로 각각 확인했다.
- 이전 주차 고아 안내에서 사용자가 정리를 선택하자 해당 `raidState`가 실제 삭제됐다. 정리 성공 뒤 신청은 자동 실행되지 않으며 사용자가 다시 신청하는 현재 계약을 유지한다. 고아 신청이 방장에게 pending으로 전달돼 승인 단계에서 반복 거절되는 증상은 신규 신청 경로에서 재현되지 않았다.
- 모집 생성은 연결 모집이 없는 stale state를 생성 Transaction에서 다시 확인해 교체하는 기존 동작이 정상 작동함을 확인했다. 신청·즉시 가입은 사용자에게 고아 상태를 알리고 명시적으로 정리하는 UX로 구분한다.
- CLI 게시 실패 뒤 사용자가 콘솔에서 Rules를 직접 게시했다고 확인했다. 운영 활성 소스 해시는 AI가 독립 대조하지 않았다.
- 이번 확인 뒤 고아 신청 복구에는 추가 기능 수정을 하지 않기로 결정했다. 본인 즉시 가입의 동일 안내 UX, D6의 과거 pending 승인 실패 안내·명시적 거절은 아직 별도 확인·작업 범위다.

# 2026-09-20 F6-D D6 승인 실패 명시적 거절 UX 구현

- 승인 명령이 `permissionDenied`로 끝난 뒤 모집 상세와 신청 목록이 모두 서버 Snapshot이고, 같은 모집·신청 revision의 pending 및 현재 승인 권한이 유지될 때만 `신청자의 참가 데이터에 오류가 있어 승인할 수 없습니다. 해당 신청을 거절해 주세요.` 대화상자를 표시한다.
- `닫기`는 데이터를 변경하지 않는다. `신청 거절`은 대화상자에 사용한 동일 revision으로 기존 bounded reject 명령을 한 번 호출한다. 자동 거절, 타인 private `raidState` 읽기, 새 Repository·Rules·스키마는 추가하지 않았다.
- 신청 목록 Snapshot의 캐시 여부를 화면 상태에 보존해 캐시·revision 변경·일반 권한 실패에는 기존 실패 안내를 유지한다. 정상 승인·기존 거절·직접 가입 흐름도 그대로 둔다.
- 모집 상세 Widget 테스트 49건과 변경 파일 `flutter analyze`가 통과했다. 첫 테스트 실행의 기대 application revision을 fixture 실제 값 3으로 바로잡은 뒤 재실행해 통과했으며 기능 결함은 아니었다. 실기기 설치·조작은 하지 않았다.
- 다음 게이트는 사용자가 과거 pending 대표 1건에서 전용 안내 → 명시적 거절, 그리고 정상 신청 승인 보존을 수동 확인하는 것이다. 본인 즉시 가입 D5 UX와 D7 최소 회귀도 남아 있으며 그 전에는 `dev/main` 통합·릴리즈를 진행하지 않는다.

# 2026-09-20 F6-D 신청 복구·파티 사이클 실기기 확인

- 고아 데이터가 있는 Character로 신청했을 때 정리 안내가 표시됐고, `닫기` 뒤 다시 신청하면 같은 안내가 다시 나타나 데이터가 임의 변경되지 않음을 확인했다.
- 사용자가 명시적으로 데이터를 정리한 뒤 재신청·방장 승인이 성공했다. 이어 참가 Character 변경과 자리 이동도 정상 작동했다.
- 파티 해산 뒤 같은 레이드에 다시 가입할 수 있었고, 파티 전체 완료 시 개인 완료 체크와 서버 데이터가 생성됐다. 이후 개인이 수동으로 체크를 해제하자 개인 완료 데이터가 삭제됐다.
- 이 흐름은 D5 고아 복구, 정상 승인, membership 변경, 자리 원장, 해산, 재참가, 공동 완료와 개인 해제를 한 실제 UX 사이클에서 함께 보존한 근거다.
- 신청 전에 고아 상태가 정리됐으므로 D6의 승인 실패 전용 대화상자는 이번 흐름에서 발생하지 않았다. 전용 안내·명시적 거절은 과거 pending 신청이 남아 있는 대표 데이터가 있을 때만 미확인 항목으로 유지한다.
- 사용자는 pending 신청 뒤 콘솔에 고아 state를 인위 생성하면 D6 실기기 재현이 가능하다고 판단했으나, 데이터 조작 테스트까지 수행하지 않고 현재 방어 구현과 표적 Widget 검증을 근거로 D6를 통과 처리했다.
- 정상 흐름에서는 신청 단계가 먼저 고아를 차단하므로 공대장이 고아 현황을 알 수 없는 것이 의도된 동작이다. 향후 실제 제보에서 승인 실패 뒤 전용 안내 또는 명시적 거절이 동작하지 않으면 D6 공대장 대응이 정상 작동하지 않은 회귀로 판정한다.

# 2026-09-20 다음 구간 F6-C 착수 전 상태 확인

- D6는 표적 자동 검증과 사용자 승인으로 닫았고, 현재 미커밋 코드·테스트·문서는 다음 구현 전에 하나의 체크포인트로 커밋할 대상이다.
- `RecruitmentCreatePage._load`를 실제 확인한 결과 첫 active raid/difficulty를 로드하고 대표 Character의 eligible 목록에서 같은 raid 또는 첫 raid를 자동 선택해 `_raid`, `_difficulty`와 draft를 채운다. `RecruitmentForm`도 두 값을 non-null로 요구하므로 F6-C 초기 선택 교착 해소는 아직 구현되지 않았다.
- 다음 코드 구간은 생성 Repository·Rules·점유/완료 정책을 변경하지 않고, 레이드 미선택 Form 상태와 선택 전 Character/역할 조작, 명시적 저장 차단, 선택 후 기존 후보 재조회·자동 제목·생성 흐름을 연결한다.
- F6-C 사용자 확인 뒤 F7에서 본인 즉시 가입 고아 복구 UX와 과거 미확인 표기를 정리하고 최종 자동·실기기 회귀를 한 번 수행한다. 그 전에는 `dev/main` 통합과 release를 진행하지 않는다.

# 2026-09-20 최소 전투력 제한 후속 작업 정의

- 모집 생성 원본·목록·상세·신청 Snapshot에는 `minCombatPower`와 전투력이 이미 저장·표시되지만, 실제 운영 상세의 후보 서비스와 원자 신청·즉시 가입 명령이 제한을 일관되게 강제하지 않는 상태를 확인했다.
- 이 작업은 F6-C 생성 초기 선택 수정과 섞지 않고 F6-E 독립 검증 단위로 진행한다. 신청자 본인 클라이언트가 계정 갱신으로 가진 선택 역할 Build Snapshot을 기준으로 후보 선택과 쓰기 직전 검사를 수행한다.
- 최소 전투력 제한이 있으면 미달 또는 전투력 정보 없음은 신청·재신청·즉시 가입·참가 Character 변경에서 차단한다. 정상 신규 신청은 신청자 단계에서 끝나므로 공대장이 신청자 private 데이터를 다시 읽지 않는다.
- 사용자는 변조 데이터를 고려하지 않기로 결정했다. 서버 권위 전투력 저장, Rules 위변조 방어와 승인자 측 최신 전투력 조회는 제외한다.
- 현재 실제 앱에 모집방 수정 기능이 없으므로 제한 변경 뒤 기존 pending 신청·멤버 처리 정책은 정하지 않는다. 차후 모집방 수정 기능을 추가할 때 별도로 결정한다. 생성자가 자신의 전투력보다 높은 제한을 입력하는 기존 동작도 이번 범위에서 변경하지 않는다.

# 2026-09-20 F6-C 모집 생성 초기 선택 교착 코드 완료

- 모집 생성 첫 진입에서 대표 Character는 추천 상태로 유지하되 레이드·난이도는 선택하지 않도록 변경했다. 특정 기본 레이드의 기존 참가·완료 상태가 Character 선택과 다른 레이드 접근까지 막던 교착을 제거했다.
- 레이드 선택 전 후보 조회는 Character와 저장 역할 Snapshot만 구성하고 특정 레이드의 점유·완료·일정·파티 구성 조건을 평가하지 않는다. 사용자가 레이드를 고르면 기존 후보 조회를 다시 실행해 모든 제한을 그대로 적용한다.
- Form의 레이드·난이도를 nullable하게 표시하고 미선택 저장에는 `레이드와 난이도를 선택해주세요.`를 안내한다. 첫 레이드 선택 시 기존 자동 제목을 생성하며 이후 난이도·Character 변경 흐름은 기존 로직을 재사용한다.
- 생성 Repository, Firestore Rules, 점유·완료·레벨·역할 정책은 변경하지 않았다. 모집 생성 Flow·Firestore·Form 표적 Widget 테스트 19건과 변경 파일 `flutter analyze`, `git diff --check`가 통과했다.
- 실기기에서는 첫 진입의 대표 Character/레이드 선택 조작, 미선택 저장 안내, 기본 첫 레이드가 불가능한 Character에서 다른 레이드 선택·정상 생성만 사용자가 확인한다. 같은 정상 UI의 자동 반복 검증은 하지 않는다.

# 2026-09-21 F6-C 실기기 확인 및 완료

- 사용자가 모집 생성 화면의 선택 부분이 실기기에서 정상 작동함을 확인했다.
- 코드·표적 Widget 19건·변경 파일 분석과 실기기 선택 흐름 근거를 합쳐 F6-C를 완료 처리했다.
- Rules 변경·배포는 없으며 다음 독립 작업은 F6-E 최소 전투력 신청 제한이다.

# 2026-09-21 F6-E 최소 전투력 제한 구현 전 조사·설계

- 사용자가 모집 생성자에게는 최소 전투력 제한이 작동하지만 신청·승인 가입자에게는 작동하지 않는 현상을 확인했다. 코드 대조 결과 운영 모집 상세는 과거 최소 전투력 판정이 있는 후보 서비스가 아니라 `RecruitmentLeaderCandidateService`를 사용하며 query에 제한값을 전달하지 않는 것을 확인했다.
- 원자 신청·재신청·즉시 가입·승인·Character 변경 Repository는 전투력 Snapshot을 application/membership에 저장하지만 모집 원본의 `minCombatPower`와 비교하지 않는다. 화면 표시가 서버 쓰기 경계를 보장하지 않는 상태다.
- 단일 Domain 판정으로 제한 없음·충족·정보 없음·미달을 구분하고, 운영 후보와 각 원자 명령의 쓰기 직전 게이트에서 재사용하도록 설계했다. 승인 시에는 타인 private 데이터를 읽지 않고 기존 application Snapshot만 비교한다.
- 과거 미달·Snapshot 누락 신청은 승인만 막고 pending을 유지해 공대장이 수동 거절한다. 자동 거절·기존 멤버 추방·Rules/스키마/이벤트 변경·추가 문서 읽기는 하지 않는다.
- 기존 완료·점유·고아·revision·역할·동일 파티 직업·다음 주 함께하기 Character 변경을 회귀 보호 대상으로 고정했다. 현재 단계에서는 코드와 Rules를 수정하지 않았다.
- 사용자는 앱의 물리적·기술적 변조에 대응하지 않기로 확정했다. 전투력을 속일 실익이 낮고 현재 배포된 구버전도 없으므로 구버전 우회와 서버 권위 검증 역시 F6-E 범위에서 제외한다.

# 2026-09-21 F6-E 최소 전투력 제한 코드·표적 검증 완료

- `MinimumCombatPowerPolicy`로 제한 없음·충족·정보 없음·미달을 단일 판정하며 정확한 경계값은 허용한다.
- 운영 모집 상세의 신청·즉시 가입·Character 변경 후보 query에 `minCombatPower`를 전달했다. 제한 미달/정보 없음 역할은 사유와 함께 선택할 수 없고, F6-C의 레이드 미선택 탐색은 보존했다.
- 신청/재신청, 즉시 가입/승인, Character 변경 Transaction이 모집 원본 제한과 command/application Snapshot을 다시 비교한 뒤 기존 쓰기 계획으로 진입한다. 추가 문서 읽기·인원수 비례 쓰기·Rules/스키마 변경은 없다.
- 과거 미달/정보 누락 pending 신청은 승인만 비활성화하고 사유를 표시하며 거절 버튼은 유지한다. Transaction이 같은 실패를 반환해도 D6 일반 권한 실패 복구로 보내지 않는다.
- 변경 파일 `flutter analyze`, Domain 정책·운영 후보·모집 상세 Widget·원자 Repository 연결 계약 표적 테스트와 `git diff --check`가 통과했다. 실기기 설치·조작은 하지 않았다.
- 사용자가 실기기에서 `미달 신청 차단`, `충족 신청 → 승인`, `미달 Character 변경 차단` 3개 흐름을 모두 확인했다. F6-E를 완료 처리하며 Rules 게시는 필요하지 않다.

# 2026-09-21 F7 최종 정리 검증 범위 조정

- 사용자는 리메이크 각 구간에서 이미 통과한 표적 자동·Rules Emulator·실기기 흐름을 F7에서 통합 테스트로 반복하지 않기로 결정했다.
- F7은 코드·Git·문서 상태 대조, 과거 미확인 표기 정리, 실제로 남은 독립 항목의 최소 확인만 수행한다. 코드가 바뀌지 않으면 전체 Flutter·Rules·실기기 회귀를 새로 실행하지 않는다.

# 2026-09-21 F7 최종 대조 완료

- 본인 즉시 가입은 D5의 공용 `PartyRaidStateOccupancyInspector`로 고아 상태를 반환하고 일반 신청과 같은 명시적 단건 정리 UI를 사용한다. 정리 후 원래 명령을 자동 재실행하지 않는 계약도 공유한다.
- 해당 서버 경계는 D5 표적 검증과 demo Actions `35494192803`, 공용 정리 UX는 신청 경로의 사용자 실기기 결과로 근거를 남긴다. 사용자 결정에 따라 즉시 가입 전용 통합 테스트는 반복하지 않았다.
- 과거 전체 Flutter 실패 수와 Rules CLI 503은 당시 진단 이력으로 보존하고 현재 결함으로 재분류하지 않았다. 운영 Rules 활성 소스 해시 독립 대조는 미확인 운영 근거로 유지한다.
- 현재 기능 브랜치는 `dev` 전용 미병합 커밋이 없고 작업 트리가 깨끗한 상태에서 통합 준비를 마쳤다. 새 기능 코드·Rules·Indexes 변경은 발생하지 않았다.

# 2026-09-21 F8-A 고아 신청 정리 구현·자동 검증

- 레이드 현황 신청 카드에서 사용자가 고아 신청 정리를 명시적으로 확인할 수 있게 했다. 서버는 부모 모집이 없거나 종료 상태일 때만 현재 Player의 application 원본 한 건을 삭제한다.
- 활성 모집은 삭제하지 않고 기존 철회를 사용한다. 다른 사용자의 신청, 모집 Aggregate, 멤버, `raidState`, 주간 완료와 이벤트는 변경하지 않는다.
- 변경 파일 분석과 표적 Flutter 테스트가 통과했고, GitHub Actions demo Emulator `35529627164`에서 신규 Rules 경계와 기존 파티·그룹 회귀가 통과했다.
- 사용자가 Firebase 콘솔에서 Rules를 직접 게시하고 실기기에서 고아 신청 삭제가 정상 작동함을 확인했다. AI는 활성 Rules 해시를 독립 대조하지 않았지만 자동 경계 검증과 기능 인수 결과를 합쳐 F8-A를 완료 처리한다.
- 완료 기록 삭제는 공용 이벤트 재동기화와 로컬 tombstone 계약이 필요한 F8-B로 분리한다.

# 2026-09-21 F8-B 완료 기록 삭제 폐기

- 완료 기록을 별도로 삭제해야 할 제품상 이유가 현재 없다고 재판단해 F8-B를 폐기했다.
- 삭제 UI, 로컬 tombstone, Drift 마이그레이션과 서버 공용 이벤트 삭제는 구현하지 않는다. 기존 완료 기록의 숨기기·다시 표시·로컬 정정 기능은 유지한다.
- 이번 결정은 문서 정리만 수행하며 F8-A의 고아 신청 삭제 코드·Rules와 이미 확인된 동작은 변경하지 않는다.

# 2026-09-21 F8 작업 브랜치 종료와 main 이력 대조

- `feature/raid-status-record-removal`은 F8-A 완료와 F8-B 폐기 결정을 반영해 작업 브랜치 범위를 종료한다. 사용자 방침에 따라 아직 `dev`·`main`에는 통합하지 않고 원격 작업 브랜치에 복구 지점을 보존한다.
- `main`에만 보이는 `e09e4a1`, `9ab16a7`은 병합 토폴로지만 별도로 남아 있다. 현재 `main` `9ab16a7`의 tree와 현재 `dev`의 조상 `8950629`의 tree가 `b0536fbbdc935d155a6c503f69492c2683d2faa6`으로 동일하고, 두 병합 원본 부모도 모두 현재 `dev`의 조상임을 확인했다.
- 따라서 `main`의 돌출 이력에서 현재 작업 브랜치로 별도 cherry-pick하거나 복원할 코드·문서는 없다. 이후 `main` 동기화는 개별 과거 merge를 가져오는 방식이 아니라 검증된 최신 `dev` 또는 release 시점을 기준으로 수행한다.

# 2026-09-21 F8 완료 지점 통합 결정

- 사용자의 최신 지시에 따라 GitHub Actions 파이프라인 작업보다 먼저 F8 완료 지점을 `dev`와 `main`의 공통 기준으로 통합한다.
- 과거 `main` 병합 이력은 강제로 지우지 않는다. 작업 브랜치를 `dev`에 반영하고 `main`의 기존 이력을 일반 병합으로 연결한 뒤 두 통합 브랜치가 같은 최종 커밋을 가리키게 한다.
- GitHub Actions 파이프라인 구축·검증은 이 통합 완료 뒤 별도 작업 범위로 진행한다.

# 2026-09-21 F8 완료 지점 dev·main 통합

- `feature/raid-status-record-removal`을 `dev`에 fast-forward한 뒤 기존 `main` 이력을 일반 병합으로 연결했다. 병합 결과 tree는 작업 브랜치와 동일하며 기능 내용의 추가 변경이나 충돌은 없었다.
- `dev`와 `main`을 통합 커밋 `69a29ca`로 맞추고 GitHub 원격에도 각각 푸시했다. 강제 푸시와 이력 삭제는 사용하지 않았다.
- 다음 작업 기준은 이 공통 통합 지점이며 GitHub Actions 파이프라인 구축·검증은 별도 작업으로 시작한다.
# 2026-09-21 BUG-021 그룹 가입 신청 승인 Rules 복구 — 자동 검증 완료

- 동일 그룹에서 여러 Player의 일반 신청 승인이 실패하고 초대코드 가입은 성공한 현상을 데이터 고아가 아닌 공통 Rules 경로로 재분류했다. demo CI `35562516961`에서 최초 membership 생성 승인도 표현식 1,000개 한도로 실패해 원인을 확정했다.
- application 승인 Transaction이 쓰는 다섯 경로의 승인 validator를 값싼 필드 guard와 함께 앞쪽으로 이동했다. 보안 조건, 원자 쓰기 문서 수, 스키마와 제품 Dart 코드는 변경하지 않았다.
- 표적 Rules 문자열 계약 5건, JS 문법과 diff 검사가 통과했다. Actions `35565203228`에서 최초 가입 승인, revision 14의 빈 membership 재가입 승인과 기존 그룹 전체 회귀가 통과했다.
- 작업 브랜치 `fix/group-join-relation-conflict`, Rules 커밋 `96cea59`, 정상 성공 기대값 커밋 `e82fb16`, Rules SHA-256 `907302E0747A28FFFB581DB295E60633C04811EF33E6AE3F161EA5A6CB5B0FD6`다. 운영 Rules 게시·실기기 승인·`dev` 통합은 아직 수행하지 않았다.
- 이후 사용자가 Rules를 콘솔에 게시하고 기존에 승인되지 않던 Player 2명 모두 정상 승인됨을 확인했다. 이 시점에 BUG-021 기능 복구를 완료하고 `dev` 통합만 남겼다.

# 2026-09-21 BUG-021 dev 통합

- 최신 `origin/dev`가 작업 브랜치의 직접 조상임을 확인하고 `fix/group-join-relation-conflict`를 `dev`에 fast-forward했다. 기능 완료 커밋 `063612c`까지 `origin/dev`에 푸시했으며 충돌과 이력 재작성은 없었다.
- 이 완료 기록을 반영한 문서 커밋도 같은 작업 브랜치를 거쳐 `dev`에 통합한다. `main`과 release는 변경하지 않으며 다음 독립 작업은 GitHub Actions 파이프라인 구축·검증이다.

# 2026-09-21 GitHub Android APK Release 파이프라인 준비

- 사용자가 수동으로 만든 release APK를 실기기에 설치해 정상 작동을 확인했다. 현재 Gradle release는 debug key로 서명되고 Android ID는 `com.example.lost_party`이므로 이 결과만으로 반복 가능한 정식 배포 상태로 보지 않는다.
- 정식 Android ID를 `kr.co.heowork0921.lostparty`로 확정했다. Firebase Android 앱 재등록, Gradle·MainActivity·FlutterFire config 일치, 영구 release keystore와 GitHub Secrets, 수동 artifact와 `v*` 태그 GitHub Release의 단계별 계약을 추가했다.
- 현재 Flutter 3.41.6/Dart 3.11.4, CI Java 21, `pubspec.yaml` 1.0.0+1을 기준으로 한다. 아직 앱 ID·Firebase 설정·서명·workflow·외부 GitHub/Firebase 상태는 변경하지 않았다.

# 2026-09-21 정식 Android ID·Firebase 설정 전환

- 사용자가 Firebase 프로젝트 `lost-party`에 `kr.co.heowork0921.lostparty` Android 앱을 등록하고 새 `google-services.json`을 전달했다. 새 Firebase Android app ID는 `1:574337852234:android:2e565a53ade5153dc057b3`다.
- Gradle namespace/applicationId, MainActivity package와 경로, `google-services.json`, `firebase.json`, Android `FirebaseOptions.appId`를 같은 등록값으로 변경했다. 기존 Firebase Android client는 새 앱 확인 전 삭제하지 않았다.
- JSON 연결 검사와 `flutter analyze lib/firebase_options.dart`가 통과했다. 첫 Gradle 검사는 셸 `JAVA_HOME` 부재로 실행 전에 중단됐고, 새 설치 없이 기존 Android Studio JBR `D:\dev\android\jbr`을 해당 명령에만 지정해 `:app:processDebugGoogleServices`가 성공했다.
- APK 빌드·설치·Firebase 초기화·익명 인증·Firestore 진입은 사용자 수동 확인 항목이다. release signing과 GitHub Actions workflow는 아직 변경하지 않았다.

# 2026-09-21 정식 Android ID 실기기 확인·영구 로컬 서명

- 사용자가 정식 package APK가 기존 임시 package 앱과 별도로 설치되고 정상 작동함을 확인했다. 이를 정식 Android ID와 새 Firebase Android 앱 연결의 실기기 통과 근거로 삼는다.
- 저장소 밖에 영구 JKS를 생성하고 Git에서 제외되는 `android/key.properties`를 구성했다. Gradle release buildType의 debug signing을 제거하고 영구 release signingConfig로 전환했다.
- `flutter build apk --release`가 성공했다. 생성 APK의 package는 `kr.co.heowork0921.lostparty`, version은 `1.0.0+1`, 서명 인증서는 `CN=LostParty, OU=Development, O=HeoWork0921`이며 SHA-256 인증서 지문은 `f9b9ee5a2ec4059ef329ae6b2e4b5392f729124c0a4f5f55248c9da8cd8bc5ea`다.
- JKS와 `key.properties`는 Git 변경 목록에 없고 비밀번호를 출력하지 않았다. 다음 단계는 오프라인 백업 확인, GitHub Repository Secrets 등록과 Actions workflow 구현이다.

# 2026-09-21 Android APK Release workflow 로컬 구현

- 로컬 `key.properties`와 CI 환경변수를 함께 지원하도록 release signingConfig 입력 경계를 분리했다. CI는 runner 임시 경로에 JKS만 복원하고 비밀번호 파일은 만들지 않는다.
- `workflow_dispatch`, `v*` tag와 최초 검증용 작업 브랜치 push를 지원하는 workflow를 추가했다. Flutter 3.41.6·Java 21 고정 빌드, package/version/승인 인증서 검증, SHA-256과 7일 artifact를 구성했다.
- 태그는 `pubspec.yaml` versionName 및 `origin/main` 포함 여부를 확인한다. Release 게시는 서명 Secrets가 없는 별도 `contents: write` job에서만 수행하며 기존 Release를 덮어쓰지 않는다.
- 변경 후 로컬 release APK 재빌드가 성공했다. 원격 Secrets 등록·Actions 실행·임시 작업 브랜치 trigger 제거는 아직 수행하지 않았다.
- 사용자가 keystore와 비밀번호의 별도 백업을 완료했다. GitHub Actions Secrets 네 개를 값 노출 없이 등록하고 이름·갱신 시각만 확인했다. 최초 원격 workflow 실행은 작업 브랜치 push 뒤 진행한다.

# 2026-09-21 Android APK Actions artifact 검증

- 첫 원격 run `35591621599`는 APK 빌드와 Secrets 복원까지 성공했지만 새 `apksigner` 출력의 두 번째 콜론 앞 문자열을 지문으로 읽어 검증 단계에서 실패했다. 실제 APK 서명 실패나 키 불일치가 아니므로 서명 설정은 바꾸지 않았다.
- 지문 추출을 마지막 `certificate SHA-256 digest:` 값 기준으로 수정했다. 동시에 key alias와 같은 문자열이 포함된 job output이 Secret으로 오인돼 생략되지 않도록 workflow artifact 이름을 중립화하고, GitHub 공식 Action을 Node 24 기반 최신 major로 올렸다.
- 두 번째 run `35592769624`에서 Secrets 복원, release APK 빌드, package `kr.co.heowork0921.lostparty`, version `1.0.0+1`, 승인 인증서 지문, SHA-256 생성과 7일 artifact 업로드가 모두 통과했다.
- 원격 검증용 작업 브랜치 push trigger는 성공 후 제거했다. 최종 workflow는 수동 artifact와 `v*` 태그 GitHub Release만 제공한다.
- 사용자가 run `35592769624`의 `android-apk-1.0.0-1` artifact를 내려받아 실기기에 정상 설치했고, 앱 실행과 Firebase 기능도 정상 작동함을 확인했다. signed artifact 실기기 게이트를 통과했으며 같은 키의 후속 버전 덮어쓰기 설치는 최초 후속 버전에서 확인한다.
- `dev`와 `main`을 검증 커밋 `0c93b34`로 맞추고 `v1.0.0` 태그를 게시했다. 태그 run `35596035632`에서 signed APK 빌드·검증·artifact 업로드는 통과했지만, checkout 없는 release job의 `gh release create`가 저장소를 자동 판별하지 못해 게시만 실패했다. Release 조회·생성 명령에 `--repo "$GITHUB_REPOSITORY"`를 명시하는 최소 보정을 적용하고, 성공 artifact를 재빌드하지 않는 복구 절차를 사용한다.
- 보정 커밋 `4569245`를 작업 브랜치, `dev`, `main`에 fast-forward 반영했다. 기존 `v1.0.0` 태그는 검증 앱 커밋 `0c93b34`에서 이동하지 않았다.
- run `35596035632`의 성공 artifact를 내려받아 SHA-256 `68e9beaacdf3f475de142630f200f87f03b8efc15251f484cfe0b5045c25460e` 일치를 확인한 뒤 공개 Release `v1.0.0`에 `lostparty-v1.0.0-android.apk`와 `.sha256`을 게시했다. Release는 draft·prerelease가 아니며 임시 복구 파일은 삭제했다.
