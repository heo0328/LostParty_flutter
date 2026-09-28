# NEXT WORK — BUG-022 직접 권한 오류 수정과 원정대 이전 복구 설계

> 상태: **F6-I 그룹 반복방 승계 후 목록 동기화 수정 실기기 확인 완료**. 반복방 노출·다른 디바이스 신청/가입·자리 변경·추방·전체 완료 후 두 캐릭터 체크와 다음 주 대기를 사용자가 확인했다. 운영 경계는 수요일 06:00 KST로 복원했다. A2-B·A3·F6-H 게시 보류는 별도 유지한다.

## 다음 단일 작업 — A2-B 참가자 제거 후 listing 동기화

**실행 확정(2026-09-29):** 현재 `fix/bug-022-party-permissions`를 유지하고 F6-I와
이전 미커밋 변경을 보존한다. F6-I·A2-B·A3·F6-H를 검증한 뒤 dev에 한 번 통합한다.
단계별 커밋은 복구 지점이며 dev 완료를 뜻하지 않는다.

- listing patch는 기존 제거 Write Plan의 8개 제거 후 구성 필드와 sourceRevision/updatedAt,
  승계 시 3개 leader Snapshot만 사용한다. revision·회차·모집 중단 상태는 이번에 바꾸지 않는다.
- Rules는 기존 세 필드 요청의 허용 범위를 그대로 보존해 구버전 앱의 추방·탈퇴를 막지
  않는다. 확장 요청은 허용 필드 집합과 변경 후 원본의 구성 8개 필드 일치를 검사한다.
  leader 필드를 쓰거나 실제 방장이 바뀌면 3개 leader 값도 원본과 모두 일치해야 한다.
  구버전 앱의 목록 잔존은 새 앱 사용 전까지 남을 수 있으며 이 호환 분기를 복구로 간주하지 않는다.
- 추가 조회·별도 Transaction·listing 생성/일괄 backfill은 없다. 누락 listing은 기존처럼
  원자 요청 전체가 실패하며 부분 삭제를 허용하지 않는다. 공개방과 마지막 1인 종료는 보존한다.
- 검증: 8인 만석→7인, 일반 탈퇴, 방장 승계, stale listing 교정, 구성/leader/회차 위조,
  listing 누락·단독 쓰기 및 같은 revision 중복 요청을 확인한다. 기존 전체 Rules 회귀도
  유지하며 A3 실패를 삭제하지 않는다. Windows Rules 로딩 503은 반복하지 않고 기존 CI 사용.
- 전체 회귀가 A3에서 막히면 A2-B 통과 범위와 미완료 게이트를 분리 기록하며 운영 게시하지
  않는다. 코드 변경만 설치해 운영 추방을 시험하도록 요청하지 않는다.

F6-I 구현·자동 검증·실기기 결과는 `DEV_LOG.md`의 2026-09-29 기록을 따른다.
이번 신청·가입 성공은 추방된 계정의 목록 재노출이나 직접 재가입 성공을 뜻하지 않는다.

### 남은 항목과 구분

| 우선순위 | 항목 | 남은 작업 |
| --- | --- | --- |
| 1 | A2-B — 확정된 listing 잔존 결함 | 추방·탈퇴 후 목록 Snapshot 동기화 및 제거된 계정의 재노출 확인 |
| 2 | A3 — 직접 재가입 Rules 한도 | 기존 active writer/Rules 중복 검증 구조 대조 후 보안·원자성을 유지하는 수정 |
| 별도 검증·게시 | F6-H | 전체 Rules 회귀와 운영 게시 게이트 충족. 이번 정상 멤버 명령 결과는 부분 근거로 보존 |
| UX 결정 선행 | DE | 재설치 복구·소유권 이전 정리의 진입·확인·실패 복구 정책 확정 |
| 통합 확인 | 완료 반복방 재승계·고아 복구 | 현재 미재현 결함으로 단정하지 않고 기존 미확인 흐름만 확인 |

F6-I의 해결된 목록 미노출은 재개 대상이 아니다. 기존 삭제 방의 승계 미실행 원인까지
소급 확정하거나 BUG-022 전체를 완료 처리하지 않는다. 과거 실패 상세는 아래 이력으로 유지한다.

- 포함: 기존 참가자 제거 Transaction이 이미 계산한 제거 후 인원·멤버·자리·target·역할
  count·방장 승계 값을 같은 listing update에 반영한다. 아래 A2-B 상세 계약을 따른다.
- 제외: A3 직접 재가입 Rules 한도, F6-H 운영 게시, 계정 복구 DE, 전체 데이터 복구.
- 순서: 기존 제거 Write Plan/Rules 대조 → 원본과 listing 동기화 → 경계 회귀 검증 →
  사용자에게 추방·탈퇴 후 해당 계정의 모집 목록 재노출 확인을 요청한다.
- 완료 조건: 제거된 Player/slot/target이 listing에 잔존하지 않고 방장 승계·마지막 1인
  종료·공개방 동작을 보존한다. 재가입 Rules 성공과 목록 노출 성공을 구분한다.
- 설치된 테스트 빌드는 화요일 01:20 설정을 유지한다. 복원된 운영 설정을 사용하려면 새
  빌드가 필요하며 기존 방의 저장된 경계는 소급 변경하지 않는다.

참고: [`BUG_REPORTS.md`](BUG_REPORTS.md)의 `BUG-022`, [`FIRESTORE_PARTY_COMMAND_CONTRACT.md`](../architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md), [`GAME_ACCOUNT_VERIFICATION_CONTRACT.md`](../architecture/GAME_ACCOUNT_VERIFICATION_CONTRACT.md).

### 현재 확인된 기준

- 앱 데이터 삭제·재설치는 새 익명 AuthUid와 새 PlayerId를 만들며, 동일 원정대 재인증은 GameAccount·Character 소유권만 새 Player로 옮긴다.
- 최초 대조 당시 제보 방은 새 Player가 정상 방장이고 모집·membership·`raidState` 연결도 일치했다. 이 근거로 A1 그룹 count와 A2 listing 결함을 분리했다.
- A1은 생성 당시 Snapshot `5`가 아니라 명령 당시 그룹 count의 `N → N-1`을 검증하도록 운영 게시됐다. A2도 참가자 제거 listing update를 허용하도록 게시됐고, 사용자가 기존 문제 방에서 추방 성공을 확인했다.
- 추방 뒤 지난 주차 방 해산은 여전히 실패했다. 현재 주차 대조 방 두 개를 정상 해산한 뒤 콘솔에서 기존 지평 방의 방장 `raidState`가 이미 없는 것을 직접 확인했다. 정상 해산이 과거 `raidStateTargets` 전부를 삭제하려는 현재 계약에서는 누락되거나 다른 모집에 재사용된 state 하나만 있어도 전체 Transaction이 거절된다.
- 따라서 “A1 count 수정 완료 = 기존 지난 주차 방 해산 완료”가 아니다. A1/A2 직접 결함과 F6-F 만료 1회성 방 종료는 서로 다른 완료 조건으로 관리한다.
- F6-F 운영 확인 뒤 현재 주차 AILKER 지평 3단계 방에서 참가 캐릭터 변경을 시도하자, 다른 활성 참가가 없는데도 `다른 확정 참가와 충돌합니다`가 표시됐다. 후보 조회는 종료 모집에 연결된 고아 `raidState`를 교체 가능으로 분류하지만 최종 변경 Transaction은 새 state 문서의 존재만으로 충돌 처리하는 판정 불일치가 확인됐다. 이를 F6-G로 분리한다.

### 설계 원칙

1. `AuthUid → PlayerId`는 LOSTPARTY 사회적 사용자 식별이고, 원정대 인증은 GameAccount·Character 소유 증명이다. 원정대 인증만으로 두 Player가 같은 사람이라고 간주하지 않는다.
2. 재설치한 동일 사용자와 타인이 사용하던 원정대의 새 소유자는 현재 인증 정보만으로 구별할 수 없다. 따라서 그룹 membership, 모집 소유권, 신청·완료 이력은 새 Player에 자동 승계하지 않는다.
3. 이번 제보의 해산 및 참가자 제거 실패는 Player 이전과 무관한 Rules 결함이므로 작업 그룹 A에서 먼저 최소 수정한다.
4. Player 복구와 원정대 소유권 이전 후 상태 정리는 작업 그룹 B로 분리한다. B가 완료되지 않아도 A의 직접 권한 오류 수정·검증을 막지 않는다.
5. 운영 데이터를 콘솔에서 직접 수정하거나 이전 Player의 전체 데이터를 새 Player로 복사하지 않는다.

### 현재 수정의 간소화 기준

- 간소화는 영향 조사·회귀 보호·필수 권한을 생략한다는 뜻이 아니다. 같은 상태를 여러 문서에서
  반복 조회하거나 같은 정책을 여러 Rules validator가 다시 계산하지 않게 만드는 것을 뜻한다.
- 화면 스트림이 이미 가지고 있는 모집 ID·회차·revision·방장 여부는 후보 선별에 재사용한다.
  후보를 찾기 위한 새 전역 쿼리, 그룹별 추가 listener와 전체 데이터 순회를 만들지 않는다.
- Firestore 원본 재확인과 쓰기는 최종 원자 Transaction 한 곳에 모은다. 화면 사전 확인은 UX
  용도이며 Rules와 Transaction의 최종 판정을 대신하지 않는다.
- 정상 현재 회차 방에는 보정 명령을 호출하지 않는다. 실패한 같은
  `recruitmentId + targetCycleKey + revision`은 snapshot 알림마다 자동 반복하지 않고,
  revision 변경·명시적 새로고침·앱 재진입
  중 하나가 있을 때만 다시 시도한다.
- Rules는 active binding, 명령 주체, Character 소유, 그룹 접근, 방 상태·정원, 주간 완료·점유,
  원자 결과 정합성처럼 기능에 필요한 조건은 유지한다. 동일 사실을 recruitment, membership,
  `raidState`, event, listing이 각각 긴 교차문서 순회로 재검증하는 중복은 제거 대상으로 본다.
- Rules 단순화는 새 validator를 기존 긴 OR에 계속 추가하는 방식으로 하지 않는다. 실제 Router/DI에
  연결된 writer를 먼저 대조하고, 사용되지 않는 legacy 분기와 중복 검증을 교체·제거한 최종
  구조에서 표현식 수와 기존 기능을 함께 검증한다.

### 다음 구현 순서

1. F6-I listing 동기화 수정은 구현·표적 검증·사용자 실기기 확인을 마쳤다.
   상세 완료 이력은 DEV_LOG.md를 따르며 다음 A2-B를 별도 범위로 진행한다.
2. A2-B는 기존 참가자 제거 Transaction의 listing update 필드만 원본 모집과 맞춘다. 추가 문서
   읽기·쓰기 없이 추방·탈퇴 후 목록 재노출을 복구한다.
3. F6-I 후속 명령 확인 중 기존 F6-H 미게시·A3 제약과 이번 변경 회귀를 구분한다.
4. A3는 앞선 두 결함과 섞지 않고 실제 active writer/Rules 분기를 대조한 뒤 중복 검증을 교체한다.
   그룹 최초 가입·재가입·신청 승인이 같은 구조로 통과해야 완료한다.
5. 각 구간은 표적 계약과 필요한 최대 8인 Rules 경계만 자동 검증하고, 최종 UX는 사용자가 실기기에서
   확인한다. 한 구간이 실패해도 다음 구간의 조건을 임의로 완화하지 않는다.

### 작업 그룹 A — 직접 Rules 결함 최소 수정

#### A1. 오래된 그룹 모집 해산 count 검증

- `atomicValidGroupLifecycleCount`에서 모집 생성 당시 `oldData.groupActiveRecruitmentCountAfter - 1`을 현재 해산의 기준으로 사용하지 않는다.
- 그룹 원본의 Transaction 전 값을 `get(groupPath)`로, 변경 후 값을 `getAfter(groupPath)`로 확인한다.
- 닫히는 활성 그룹 모집이면 다음 세 조건을 함께 강제한다.
  1. 현재 그룹 count가 1 이상이다.
  2. 그룹 count가 현재 `N → N-1`로 정확히 감소한다.
  3. 모집에 기록하는 `groupActiveRecruitmentCountAfter`가 변경 후 그룹 count와 같다.
- 그룹 문서 자체의 `validAtomicGroupRecruitmentClose` 검증은 유지한다. 모집 Rules와 그룹 Rules가 같은 Transaction의 현재 count 전이를 양쪽에서 확인하게 한다.
- 닫히지 않는 lifecycle 명령은 기존처럼 모집의 count Snapshot을 변경하지 않는다.
- Dart Repository는 이미 현재 그룹 count를 읽어 `N-1`을 쓰므로 제품 코드 변경 없이 Rules와 회귀 fixture만 수정하는 것을 기본안으로 한다.

**A1 구현 상태(2026-09-23):** `firestore.rules`와 독립 scalability proof Rules에 현재 그룹 원본 전후 값을 한 번씩 읽는 전용 helper를 추가했다. 기존 Dart Repository는 변경하지 않았다. 생성 당시 모집 Snapshot `5`, 현재 그룹 count `17`, 해산 후 `16` fixture를 추가했고 새 정적 계약 1건, JS 문법과 `git diff --check`가 통과했다. 전체 정적 계약 파일에는 이번 변경과 무관한 기존 allow 순서 문자열 assertion 1건이 실패하므로 새 계약만 분리 실행했다. 로컬 Firestore Emulator는 Rules 로딩 전에 기존 환경 문제인 HTTP 503 `Network closed for unknown reason`로 중단되어 실제 Rules assertion은 CI 격리 환경에서 확인해야 한다. A1은 운영 배포·실기기 확인 전이며 A2와 전체 Rules 회귀가 끝날 때까지 배포하지 않는다.

#### A2. 그룹 모집 참가자 추방·탈퇴 listing 검증

- `validAtomicMemberRemovalListingUpdate(groupId, recruitmentId, oldData, newData)` 전용 validator를 추가한다.
- 같은 Transaction의 모집 전·후 문서가 기존 `validAtomicRecruitmentMemberRemoval`을 만족하고, 모집의 `groupId`가 경로와 같으며 변경 후에도 `visibility == group`인 경우만 허용한다.
- listing에서 변경 가능한 필드는 `memberCount`, `sourceRevision`, `updatedAt` 세 개로 제한한다.
- 세 값은 각각 변경 후 모집의 `memberCount`, `revision`, `request.time`과 같아야 한다.
- 마지막 1인 제거로 방이 종료되는 경로는 listing update가 아니라 기존 lifecycle/listing delete 계약을 사용한다.
- 공개방은 listing 쓰기를 새로 추가하지 않는다. 누락 listing 자동 생성이나 전체 Snapshot 덮어쓰기도 이번 수정에 포함하지 않는다.

**A2 구현 상태(2026-09-23):** 그룹 listing update에 `validAtomicMemberRemovalListingUpdate`를 연결했다. 같은 Transaction의 모집 전후 문서가 기존 참가자 제거 검증을 통과하고 경로 `groupId`와 그룹 공개 범위가 유지될 때만 listing의 `memberCount`, `sourceRevision`, `updatedAt` 세 필드 변경을 허용한다. 변경 후 값은 모집의 인원수·revision·`request.time`과 일치해야 한다. 제품 Repository는 이미 같은 세 필드를 쓰므로 변경하지 않았다. 방장 추방, 본인 탈퇴와 listing 인원 위조 거절 fixture를 전체 production Rules Emulator 스크립트에 추가했다. Repository·Router·Rules 정적 계약 5건, JS 문법과 `git diff --check`가 통과했다. 로컬 Emulator는 A1에서 Rules 로딩 전 503이 반복 확인되어 같은 실패 명령을 재실행하지 않았으며, A1·A2 실제 Rules 허용·거절과 기존 전체 회귀는 CI 격리 환경에서 확인한다.

**A2-B 추가 확인 — 참가자 제거 후 listing 잔존 필드(2026-09-28):** 문제 방
`eYjsz5OqzcppZCUK3Bts`의 원본 모집은 추방 후 방장 1인, revision 9로 정상 전환됐지만 그룹
listing은 `sourceRevision=9`, `memberCount=1`만 바뀌고 제거된 Player가
`memberPlayerIds/partySlots/raidStateTargets`에 남았으며 역할 count도 이전 값이었다. 그룹 모집
목록은 listing의 `memberPlayerIds`를 사용해 본인 참가 방을 제외하므로, 추방·탈퇴한 사용자가
해당 방을 재가입 후보 목록에서 보지 못할 수 있다. 이는 재가입 Rules 1,000식과 별개로 재가입
진입 UX를 막는 직접 결함이다.

수정은 기존 참가자 제거 Transaction에서 추가 읽기·새 문서·후처리를 만들지 않고, 이미 계산한
`PartyAtomicMemberRemovalWritePlan.recruitmentPatch`의 제거 후 값을 같은 listing update에 포함한다.
최소 동기화 대상은 `memberPlayerIds`, `partySlots`, `raidStateTargets`, `memberCount`,
`dealerCount`, `supportCount`, `nonGroupMemberCount`, `hasAvailableSlot`이며, 방장 승계가 발생하면
`leaderPlayerId/leaderCharacterNameSnapshot/leaderClassNameSnapshot`도 함께 맞춘다.
`sourceRevision/updatedAt`은 기존처럼 유지한다. Rules는 이미 읽는 `getAfter(recruitment)` 결과와
위 필드만 직접 일치시키며, 별도 모집 조회나 전체 Map 재검증을 추가하지 않는다.

최소 검증은 일반 멤버 추방, 본인 탈퇴와 방장 승계 각각에서 원본 모집과 listing의 위 필드가
같은지 확인하고, 추방된 그룹원이 방을 목록에서 다시 볼 수 있는지 확인한다. 공개방은 listing
쓰기가 없고 마지막 1인 종료는 기존 listing delete를 유지한다. 이 수정은 재가입 Transaction
자체의 Rules 1,000식 해결을 대신하지 않는다.

#### A3. 자동 검증

- `tools/party_group_cutover_rules_test.mjs`에 생성 당시 모집 Snapshot count와 현재 그룹 count가 다른 fixture를 추가한다. 예: 모집 Snapshot `5`, 현재 그룹 `17`에서 해산 후 `16`을 허용한다.
- 같은 fixture에서 `4`, `15`, `17` 등 현재 전이와 맞지 않는 count, 그룹 문서 갱신 누락, 비방장 해산은 계속 거절한다.
- 그룹 전용방의 방장 추방, 본인 탈퇴, 탈퇴 후 재가입을 허용하고 listing의 count·revision·시각 변조는 거절한다.
- 공개방의 같은 추방·탈퇴가 listing 없이 유지되는지 대조한다.
- 인원수 반복은 최대 8인 대표 한 건만 추가하고, 마지막 1인 종료·방장 승계처럼 상태 전이가 다른 경계만 별도 최소 사례로 둔다.
- 기존 생성·신청·승인·즉시 가입·자리 이동·개인 완료·반복방·공개 범위 전환·그룹 해산 회귀를 같은 demo Emulator 묶음에서 보존한다.
- 정적 계약 테스트는 새 validator의 allow 연결, 허용 필드 제한과 현재 count 전이식을 고정한다.

**A3 CI 진단(2026-09-24):** 원격 demo Emulator 첫 실행 `35948873935`는 기존 production Rules 회귀 46건과 그룹 이전·탈퇴·해산 회귀 20건을 통과했다. 이후 production 묶음에 오래된 count `5`/현재 count `17`의 `17 → 16` 해산, 위조 count `15`, 그룹 갱신 누락, 탈퇴 후 그룹방 재가입을 추가했다. 보강 실행 `35949253847`에서 count 허용·거절, 추방과 본인 탈퇴는 모두 통과했으나 그룹방 재가입 원자 요청이 1,000식 한도를 초과했다. listing 전체 동기화 validator를 먼저 평가한 `35949904480`, 참가 명령을 `memberCount N → N+1` marker로 먼저 분류한 `35950136462`도 같은 재가입 지점에서 실패했다. 두 보정은 효과가 없어 Rules와 정적 계약에서 되돌렸고, A1·A2 production fixture와 실패 재현만 보존한다. 따라서 A1·A2 직접 수정의 허용·거절 결과는 확보했지만 A3 전체 회귀는 그룹방 재가입 표현식 예산 때문에 미완료이며 운영 배포로 넘어가지 않는다. 다음 작업은 실패 요청의 문서별 표현식 비용을 분리하는 별도 진단 설계를 먼저 확정해야 한다.

**A3 다음 진단·수정 순서(2026-09-24):** 공개방 재가입과 그룹방 재가입의 쓰기 차이는 그룹 membership 확인과 `raidListings` 전체 Snapshot 덮어쓰기다. 먼저 production fixture의 축약 listing을 실제 생성 계약과 같은 모집 전체 Snapshot으로 교체해 fixture 왜곡 여부를 배제한다. 같은 실패가 유지되면 모집 update Rules가 이미 원자 요청 전체의 참가 적합성을 검증한다는 점을 이용해, listing update에서는 모집 참가 validator 전체를 다시 호출하지 않는다. 대신 모집 전후의 `groupId`·`visibility`, `memberCount N → N+1`, `revision N → N+1`, `updatedAt == request.time`과 listing 전체 Map이 `getAfter(recruitment)`와 정확히 같은지만 확인하는 전용 결합 validator를 둔다. 이 방식은 부분 Projection으로 계약을 축소하지 않고 전체 Snapshot 동기화와 위조 거절을 유지하며, 별도 Transaction 분리는 하지 않는다. 전용 validator 적용 전후에는 정상 재가입, listing 필드 위조, 모집과 다른 listing, 공개방 무 listing 흐름을 최소 회귀로 확인한다.

**A3 비용 분리 결과(2026-09-24):** 실제 전체 Snapshot fixture를 사용한 `35952078068`도 같은 1,000식 한도로 실패해 fixture 왜곡을 배제했다. listing에서 모집 참가 validator를 중복 호출하지 않고 전이 marker와 전체 Map 일치만 검사한 `35952427642`, 참가·승인 변경 필드만 부분 갱신하고 해당 필드를 원본과 대조한 `35952736904`에서도 위조 listing 거절은 통과했지만 정상 재가입은 동일하게 한도를 넘었다. 두 구현은 효과가 없어 최종 트리에서 되돌렸다. 현재 근거상 특정 listing 비교식 하나가 아니라 모집·membership·raidState·event·listing 5개 쓰기의 Rules 평가 총량이 병목이다. 다음 구간은 제품 수정 전에 진단 fixture에서 listing 또는 event 쓰기를 각각 제외해 4개 쓰기 경계를 확인하고, 문서별 validator 비용을 줄일 수 있는지 판단한다. 원자성 또는 공용 event/Projection 계약을 완화해야만 통과한다면 임의로 분리 Transaction을 도입하지 않고 설계 결정을 다시 받는다.

**A3 그룹원 확인 비용 결과(2026-09-24):** `35952954093`에서 listing 쓰기를 제외한 모집·membership·raidState·event 4개 쓰기도 한도를 넘었고, `35953072208`에서는 listing과 event를 모두 제외한 3개 쓰기도 동일하게 실패했다. 공개방의 동일 참가 흐름은 4개 쓰기로 통과하므로 문서 수나 listing 자체가 아니라 그룹방 참가 시 membership validator가 수행하는 그룹원 존재 확인이 임계점을 넘기는 조건이다. 이미 확인한 active binding을 재사용해 `isCurrentGroupMember` 대신 membership `exists`만 직접 검사한 `35953245277`도 효과가 없어 되돌렸다. 다음 구간은 모집·membership·raidState·partyEvent 각 match의 긴 OR에서 가입 분기를 식별하기 전에 소비하는 비용을 함께 측정하고, 보안 조건을 줄이지 않는 범위에서 가입 marker를 각 문서에 선배치하는 통합 설계를 먼저 작성한다. 앞서 모집 문서 한 곳만 marker 순서를 바꾼 접근은 실패했으므로 반복하지 않는다.

**A3 통합 OR 선별 결과(2026-09-24):** 모집·membership·`raidState`·listing 네 match에 가입 전용 값싼 marker를 동시에 선배치한 `35954589598`도 그룹방 재가입에서 1,000식 한도를 넘었다. 같은 실행에서 실패 지점 전까지 신규 생성, 수동 완료, 그룹 신청 승인·코드 가입, 공개방 가입, 자리 이동, 추방·탈퇴, 2·4·8인 해산과 A1·A2 허용·거절은 통과해 기존 흐름 회귀는 관찰되지 않았다. 그러나 재가입 개선 효과가 없으므로 통합 순서 변경과 전용 정적 계약은 최종 트리에서 되돌렸다. 이제 OR 순서·listing 비교·쓰기 수 축소를 반복하지 않는다. 다음 구간은 `validAtomicJoinedMembership`과 `validAtomicRaidStateCreate`가 같은 모집·membership·state 결합을 중복 확인하는 지점을 보안 불변식별로 분해하고, 어느 한 validator에서 교차문서 검증을 제거해도 단독 위조 쓰기가 열리지 않는지를 먼저 계약 수준에서 증명한다. 그 증명이 불가능하면 클라이언트 Rules만으로 현재 원자 계약을 유지하는 수정은 중단하고 신뢰 서버 명령 또는 데이터 계약 변경을 별도 선택지로 제시한다.

**A3 교차문서 검증 결과(2026-09-24):** 첫 시도는 신규 membership create Rules가 모집 target과 같은 요청의 raidState를 검증한다는 불변식을 이용해 참가 raidState validator의 중복 target 순회만 제거했다. 단독 raidState 생성, membership 누락, target 불일치는 모두 거절됐지만 CI `35992417272`의 정상 그룹방 재가입은 여전히 1,000식 한도를 넘었다. 두 번째 시도는 제품 Write Plan의 `memberPlayerIds`·`partySlots`·`raidStateTargets` 동일 순서와 신규 참가자 마지막 추가를 계약으로 고정해 membership과 raidState 양쪽의 target 순회를 직접 마지막 인덱스 검증으로 바꿨다. 순서 위조는 거절됐지만 CI `35993347464`의 정상 재가입도 같은 한도에서 실패했다. 두 실행 모두 신규 생성·수동 완료·그룹 승인/코드 가입·공개방 재가입·자리 이동·추방/탈퇴·2/4/8인 해산과 A1/A2는 실패 지점 전까지 통과했다. 효과 없는 변경은 각각 `3d3e442`, `5d95005`에서 되돌렸고 운영 배포하지 않는다.

**A3 구조 결정 지점:** listing/event 쓰기 제거, 그룹 membership 조회 축소, 네 match OR 선별, raidState 한쪽 및 membership·raidState 양쪽의 target 순회 제거까지 정상 재가입의 표현식 한도를 해소하지 못했다. 원자 쓰기를 임의로 나누거나 권한·소유권·주간 완료·그룹 접근·target 결합 검증을 더 삭제하면 부분 성공 또는 위조 참가를 열 수 있으므로 진행하지 않는다. 다음 무료 범위 구현은 모집 update 한 곳에 전체 참가 정책을 배치하고 membership·raidState·event·listing은 같은 revision의 직접 Projection 결합만 확인하는 작업 그룹 C다. 상세 실행 계약은 [`BUG_022_REMAINING_FIX_DESIGN.md`](../architecture/BUG_022_REMAINING_FIX_DESIGN.md)를 따른다.

**A3 서버 전환 조사(2026-09-24):** 저장소에는 Functions 구성이 없고 현재 계약도 Spark를 기준으로 한다. 신뢰 서버 설계는 기술적 최후 대안으로만 보존하며 현재 구현 순서에서 제외한다. 먼저 작업 그룹 C의 가입 전용 권위 validator와 Projection 결합 validator로 중복 정책 평가를 구조적으로 제거한다. 이 전체 재설계가 보안 거절을 유지한 채 Emulator 한도를 통과하지 못한 경우에만 서버 대안을 다시 검토한다.

**작업 그룹 C 실행 결과(2026-09-24):** 모집 update에 권한·그룹 접근·Character 소유·주간 완료·membership·raidState·event·listing 결합을 집중하고 나머지 문서는 같은 revision Projection만 확인하도록 구현했다. 정적 Rules 계약 41건은 통과했지만 전체 CI `35997627746`은 그룹방 재가입에 도달하기 전 기존 공개방 신청 승인에서 1,000식 한도를 넘었다. 승인자 권한 검증은 그대로 두고 Projection 봉투의 중복 조건만 더 줄인 `35998246596`도 같은 지점에서 실패했다. 두 구현 커밋은 `34d694e`, `d73db5a`로 되돌렸고 운영 배포하지 않았다. 따라서 작업 그룹 C의 현재 Spark 설계는 실패로 종료한다. 다음 단일 작업은 (1) 신뢰 서버 참가 명령 또는 데이터 계약 변경을 별도 승인해 C 대안을 설계하거나, (2) C와 독립적인 D 재설치 후 동일 Player 복구로 이동하는 것 중 사용자 결정이 필요하다.

**C7 Spark 데이터 계약 대안 설계(2026-09-27):** 유료 Functions 대안은 기존 합의상 제외한다. 다음 후보는 schema v3 모집 Aggregate의 확장 `partySlots`와 개인 `raidState`, application, party event만 가입의 원자 권위 상태로 유지하고, 하위 membership과 그룹 listing을 복구 가능한 읽기 Projection으로 내리는 방식이다. 그룹 listing은 발견 pointer로 남기며 실제 인원·revision은 recruitment에서 읽는다. 기존 v2 방은 멤버·점유를 바꾸지 않는 별도 멱등 migration 뒤 v3 가입을 재시도한다. 제품 코드를 바로 수정하지 않고 먼저 격리 proof에서 직접 가입 3-write·승인 4-write, 위조·누락 거절, 8인 문서 크기·Rules 예산과 v2 migration을 검증한다. proof 및 개발자의 목록 추가 읽기·Projection 지연·앱 전환 UX 승인을 모두 통과하기 전에는 채택하지 않는다. 상세 계약은 [`BUG_022_REMAINING_FIX_DESIGN.md`](../architecture/BUG_022_REMAINING_FIX_DESIGN.md) C7이다.

**C7 proof 결과·폐기(2026-09-27):** 운영 Rules·Flutter와 분리된 직접 재가입 3-write proof를 추가하고, 기존 Aggregate 앞부분 exact preservation과 비그룹원·block·타인 Character·주간 Claim·자리/count·핵심 문서 누락 거절을 포함했다. Actions `36326380626`의 모집 단건 읽기 하네스 불일치와 `36326546696`의 배열 내부 `serverTimestamp()` 제약을 실제 제품 계약에 맞게 교정했다. 최종 `36326680954`에서 정상 그룹 직접 재가입 3-write 자체가 `maximum of 1000 expressions`로 거절됐다. 사전 폐기 조건에 따라 승인 4-write·8인 크기·v2 migration·제품 구현은 중단한다. 운영 `firestore.rules`, Flutter 제품 코드와 운영 데이터는 변경하지 않았고 배포도 없다. 권한·소유권·주간 완료·그룹 접근·원자성 조건 또는 실패 회귀를 줄여 통과시키지 않는다.

**A3 재개 기준 — 기능·Rules 구조 간소화(2026-09-28):** 재가입만 통과시키는 새 예외 validator나
추가 조회를 덧붙이지 않는다. 먼저 실제 Router/DI에 연결된 생성·신청·승인·즉시 가입 writer와
각 Firestore match의 allow 분기를 1:1로 대조한다. 운영 writer가 사용하지 않는 legacy·revert 잔여
분기와 동일 정책의 중복 교차문서 검증을 표시한 뒤, 가입의 필수 조건을 다음 한 묶음으로 유지한다.

1. active binding과 실제 actor
2. 활성 모집·현재 회차·revision·정원과 자리
3. 현재 Character 소유와 동일 레이드 참가·완료 충돌 부재
4. 그룹 전용방의 현재 그룹 membership
5. recruitment와 membership·`raidState`·event·listing 결과의 동일 Player·Character·revision 결합

이 다섯 조건을 문서마다 처음부터 반복 계산하지 않는다. 모집의 명령 전이가 기능 정책을 한 번
판정하고, 나머지 문서는 같은 Transaction의 결정된 결과와 경로·revision만 결합하도록 기존 긴
분기를 **교체**한다. 기존 OR에 새 분기를 추가하는 과거 실패 접근은 반복하지 않는다. 단독 문서
위조, 타인 Character, 비그룹원, 완료·점유 충돌은 계속 거절한다. 변경 전후 Rules 접근 호출과
표현식 수를 비교하고, 최초 그룹 가입·탈퇴 후 재가입·신청 승인이 같은 구조로 통과해야 한다.
이를 위해 새 컬렉션, 추가 Firestore 읽기, 별도 Transaction, Functions와 schema v3를 도입하지
않는다. 실제 active writer를 제거해야 하거나 필수 다섯 조건을 유지하고도 한도를 넘으면 임의로
보안을 더 쌓거나 줄이지 않고 현재 Spark 구조의 한계로 다시 결정한다.

#### A4. 배포와 실기기 확인

- Rules 변경이므로 표적 정적 검사와 demo Emulator 전체 회귀가 통과한 최신 추적본만 운영 프로젝트에 한 번 배포 시도한다.
- 첫 배포 실패 시 반복하지 않고 실패 단계와 활성 소스를 대조한다. 재시도는 진단 보고 후 사용자의 새 지시가 있을 때만 한다.
- 실기기는 그룹 전용방 한 개에서 `참가자 추방 → 재가입 → 본인 탈퇴`, 여러 방을 만든 그룹의 오래된 방 해산을 확인한다.
- 공개방 정상 추방·탈퇴와 그룹의 다른 활성 모집 count가 보존되는지도 함께 확인한다.

### 기존 작업 그룹 B 정책 기준 — 통합 작업 그룹 DE로 구체화

재설치 후 동일 사용자 복구와 타인 원정대 이전 후 고아 데이터 정리는 공통적으로 현재
Character 소유 관계와 과거 Player 데이터의 정합성을 다루므로 하나의 상위 작업 그룹
`DE`로 관리한다. 실제 구현은 동일 Player 복구 단계와 소유권 이전 stale 정리 단계로
분리하며, 상세 기준은
[`BUG_022_REMAINING_FIX_DESIGN.md`](../architecture/BUG_022_REMAINING_FIX_DESIGN.md)의 DE를 따른다.

구현 전에는 개발자 의견을 수렴해 `새로 시작/기존 계정 복구/소유권 이전` 진입 분기,
승계되지 않는 데이터 안내, 사용자 확인과 취소 시점, stale 상태 발견·정리 화면, 충돌·부분
실패·재진입 UX를 먼저 확정한다. 이 UX 승인 전에는 인증·스키마·Rules 코드를 수정하지 않는다.

#### B1. 제품 정책

- 원정대 소유권 이전은 GameAccount·Character의 사용권만 옮긴다. 이전 Player의 그룹, 모집, 신청, 알림, 완료 이력과 파티장 지위는 새 Player로 이전하지 않는다.
- 앱 재설치 후 기존 그룹·이력을 그대로 복구하려면 원정대 인증과 별개의 신뢰 가능한 Player 복구 수단이 필요하다. 새 AuthUid를 기존 Player에 붙이는 기능은 클라이언트 Rules로 열지 않고 운영자 또는 향후 신뢰 서버 명령으로만 설계한다.
- 따라서 B의 기본 목표는 사회적 데이터 승계가 아니라, 이전 소유자가 남긴 Character 기반 활성 상태를 안전하게 무효화·정리하는 것이다.

#### B2. 소유권 세대값

- `gameAccounts`와 소속 `characters`에 단조 증가하는 `ownershipRevision`을 둔다. 소유 Player가 실제로 바뀔 때만 1 증가시키고 같은 Player의 재인증에는 증가시키지 않는다.
- 신규 application, membership, `raidState`의 Character Snapshot에는 생성 당시 `ownerPlayerId`와 `ownershipRevision`을 저장한다.
- 이후 승인·가입·Character 변경·완료·탈퇴 명령은 현재 Character 소유자와 revision이 Snapshot과 모두 같은지 확인한다.
- Player A → B → A처럼 소유권이 되돌아와도 A 시절의 오래된 활성 문서가 다시 유효해지는 ABA 회귀를 revision으로 차단한다.
- 기존 revision 없는 문서는 현재 Character 소유자가 Snapshot Player와 같고 계정 revision이 초기값인 경우에만 legacy 호환한다. 최초 소유권 이전 뒤에는 자동으로 stale 판정하며, 정상 명령으로 다시 저장될 때 최신 revision을 기록한다.

#### B3. 지연 무효화와 정리

- 소유권 이전 Transaction에서 이전 Player의 전체 그룹·모집·신청을 순회하지 않는다. 문서 수가 무제한이고 타인의 사회적 데이터를 새 소유자가 읽는 구조도 허용하지 않기 때문이다.
- 이전 revision의 pending 신청은 승인할 수 없으며 `ownershipChanged` 상태로 명시적 무효화할 수 있게 한다. 단순 `permission-denied`로 숨기지 않는다.
- 이전 revision의 활성 membership을 발견한 모집은 구성 점검 대상으로 판정한다. 정상 멤버 또는 파티장이 실행하는 제한된 정리 명령으로 stale membership과 연결 `raidState`를 제거한다.
- stale 대상이 파티장이면 남은 멤버가 있을 때 기존 승계 규칙으로 파티장을 넘기고, 마지막 1인이면 방을 해산한다. 그룹 membership과 그룹장 권한은 Player 기반이므로 원정대 새 소유자에게 넘기지 않는다.
- 새 소유자의 신규 `raidState`는 최신 ownership revision으로 생성한다. 이전 Player 경로의 stale state는 신규 소유자의 점유로 간주하지 않되, 연결 모집 정리 시 감사 가능한 원자 명령으로 제거한다.
- 화면은 `캐릭터 소유권이 변경되어 신청/참가 상태를 정리해야 합니다`를 별도 안내하고 일반 권한 실패와 구분한다.

#### B4. 통합 작업 그룹 내부 구현·검증 게이트

- DE는 하나의 상위 작업 구간이지만 인증 연결과 Firestore 스키마·파티 Rules의 변경 범위가 다르므로 동일 사용자 복구와 실제 소유권 이전을 각각 독립 체크포인트로 구현·검증한다.
- 최소 회귀는 동일 Player 재인증, A→B 이전, A→B→A 재이전, revision 없는 기존 문서, stale pending 승인 거절·정리, 일반 멤버 stale, 파티장 stale 승계와 마지막 1인 해산이다.
- 타인의 그룹·모집·과거 기록 비공개, 새 Player로의 자동 승계 금지와 이전 Player의 멀티유저 명령 차단을 Rules 계약으로 고정한다.
- 기존 운영 데이터의 일괄 마이그레이션은 하지 않는다. revision 초기화 또는 필요한 최소 backfill이 있다면 읽기 전용 영향 집계와 별도 승인 후 진행한다.

### 구현 순서와 승인 게이트

1. 완료된 A1 해산과 A2 추방·탈퇴 수정은 그대로 보존한다.
2. C7은 격리된 정상 3-write부터 1,000식 한도를 넘어 폐기했다. 승인 4-write, migration과 제품 구현으로 확장하지 않는다.
3. 재가입 C의 다음 변경은 새 Spark 계약 또는 신뢰 서버를 다시 설계·승인하는 별도 결정 전까지 보류한다. 현재 합의상 Functions·Blaze는 선택하지 않는다.
4. DE 구현 전 개발자와 복구·이전 UX 흐름을 확정하고 승인 결과를 문서화한다.
5. DE-D에서 익명 Firebase user를 복구 가능한 로그인 제공자에 연결하고 재설치 전후 같은 UID·Player 복구를 확인한다.
6. DE-E에서 ownershipRevision dual-write·stale 차단·제한 정리를 순차 구현한다. 구현 전 재설치 전·후 Player binding과 이전 Player의 활성 상태는 가능한 범위에서 읽기 전용으로 대조하되, 결과를 A/C의 직접 원인으로 소급하지 않는다.

### 현재 설계 단계 완료 조건

- 직접 권한 오류의 변경 함수, 허용 필드, Emulator 허용·거절 사례와 실기기 확인 항목이 확정된다.
- 원정대 인증과 Player 복구의 책임을 분리하고 자동 사회적 데이터 승계를 금지하는 안전 기준이 확정된다.
- 소유권 재이전 ABA를 포함한 stale 상태 판정과 제한된 정리 방향이 정의된다.
- 구현은 C → DE 순서로 분리하고, DE 안의 동일 사용자 복구와 소유권 이전은 독립 체크포인트로 검증·배포한다는 경계가 문서화된다.

### 현재 제외 범위

- 이 설계 단계의 앱 코드·Rules·운영 데이터 변경과 배포
- 기존 문제 방의 콘솔 수동 보정
- 이전 Player의 그룹·모집·이력 전체를 새 Player로 복사
- 클라이언트가 기존 Player에 새 AuthUid를 직접 연결하는 복구 기능
- A와 B를 한 번에 구현·배포하는 작업 확장

---

## 완료 작업 — 애니메이션 진입 화면 테스트

> 상태: 구현·자동 검증·사용자 실기기 확인을 완료했고 `feature/animated-entry-screen`을 최신 `dev`에 통합·push했다. 다음 제품 작업 선정 전 완료 기록으로 유지한다.

## 현재 단일 작업 — Flutter 진입 화면

- 작업 브랜치: `feature/animated-entry-screen`
- 종료 조건: 기존 Firebase 초기화·재시도·라우팅을 보존하면서 정적 네이티브 스플래시 다음에 약 2.2초의 1회성 Flutter 진입 연출을 표시하고, 초기화 완료 후 기존 앱으로 자연스럽게 전환할 수 있다.

### 포함 범위

1. 제공된 941×1672 로딩 이미지를 Flutter asset으로 등록한다.
2. 하나의 애니메이션 타임라인으로 별빛 1회, 중앙 글로우 1회, 흰색·보랏빛 하이라이트 1회를 실행한다.
3. 이미지와 효과를 같은 디자인 좌표계에서 확대해 화면 비율이 달라도 정렬을 유지한다.
4. 앱 서비스 초기화와 애니메이션을 병렬 실행하고 두 조건이 모두 끝난 뒤 기존 `MyApp`으로 전환한다.
5. 초기화가 오래 걸리면 마지막 정적 프레임을 유지하고, 실패·재시도와 기존 Router/DI 연결은 보존한다.
6. 부트스트랩 완료 게이트와 애니메이션 1회 종료를 좁은 Widget 테스트로 검증한다.
7. 제공된 아이콘 원본을 영문 파일명으로 보관하고 Android 일반·적응형·단색 아이콘과 iOS AppIcon 세트에 적용한다.

### 제외 범위

- 네이티브 Android/iOS 스플래시 교체
- Lottie·영상 패키지 추가
- Firebase 초기화 순서, 인증·Player binding·접속 기록 정책 변경
- 앱 메인 라우팅과 화면별 데이터 로딩 정책 변경

### 회귀 보호

- 초기화 완료 전에는 `MyApp`을 만들지 않는다.
- 초기화 실패 시 기존 오류와 재시도 동작을 유지한다.
- 재시도는 초기화 요청을 정확히 한 번 새로 시작한다.
- 진입 화면 때문에 시작 Character 갱신, Router 생성 또는 Repository 연결 시점이 중복되지 않는다.
- 애니메이션은 무한 반복하지 않으며 마지막 프레임에서 추가 ticker를 계속 실행하지 않는다.

### 완료 조건

- 관련 Widget 테스트와 변경 파일 정적 분석이 통과한다.
- 9:16 및 긴 Android 화면에서 로고·별·하이라이트 정렬을 사용자가 실기기로 확인한다.
- 초기화가 빠른 경우 약 2.2초 뒤 전환되고, 느린 경우 마지막 프레임 유지 후 전환되는지 확인한다.
- 네이티브 스플래시 변경은 별도 승인 작업으로 남긴다.

### 현재 검증 상태

- 진입 화면·부트스트랩 Widget 테스트 4건 통과
- 변경한 Dart 파일 정적 분석 통과
- Android 일반·적응형·단색 아이콘과 iOS AppIcon 전 슬롯 생성 완료
- 아이콘 해상도·투명 채널·Android XML·iOS 슬롯·영문 파일명 검증 통과
- 전체 테스트는 기존 Firestore Rules 계약 및 Firebase 미초기화 Widget 테스트를 포함한 16건 실패로 미통과했으며, 이번 변경 경로의 테스트 실패는 없다.
- 사용자가 실기기에서 진입 화면과 앱 아이콘 적용을 확인했다. Android 런처의 원형 적응형 아이콘 마스크도 정상 동작으로 확인했다.

## 기존 통합 상태 참고

- 기존 `release/1.0.0` 후보는 폐기했다. 브랜치는 이력용으로 보존하되 출시·`main` 병합 기준으로 사용하지 않는다.
- R1~R7·C* 구현과 운영 Rules·Indexes 게시는 완료했다. 운영 Router는 원자 Repository·어댑터를 쓴다.
- 로컬에는 생성·읽기 v2·이전 Close/Open 가드·승인 패치·listing sync·Listen 가드·orphan 공개 전환·모집 삭제→disband·캐릭터 변경 atomic OR·그룹 전용방 파티장 탈퇴 차단 등이 **코드로 들어가 있다**.
- **실기기 판정(2026-09-16 사용자 확인):** 아래 성공 항목은 사용자가 디바이스에서 확인했다. 그 밖의 보고 실패는 로컬 수정·자동 테스트 통과만으로 완료로 쓰지 않는다.
- **2026-09-21 현재 작업:** 파티·그룹 재설계 F7, F8-A와 `BUG-021`은 완료했다. 다음 독립 작업은 정식 Android ID `kr.co.heowork0921.lostparty`, 영구 release 서명과 태그 기반 GitHub APK Release 파이프라인 구축이다. 상세 계약은 [`GITHUB_ANDROID_RELEASE_PIPELINE.md`](../architecture/GITHUB_ANDROID_RELEASE_PIPELINE.md)를 따른다.

## 현재 단일 작업 — GitHub Android APK Release 파이프라인

### 포함 범위

1. Firebase 프로젝트 `lost-party`에 정식 package ID의 Android 앱을 추가하고 Android FlutterFire 설정을 교체한다.
2. Gradle·MainActivity를 `kr.co.heowork0921.lostparty`로 일치시킨다.
3. 한 개의 영구 release keystore를 로컬과 GitHub Actions에서 안전하게 공유하도록 signingConfig와 ignore/Secret 계약을 구성한다.
4. 수동 실행에서는 APK artifact만, `v*` 태그에서는 GitHub Release와 APK·SHA-256을 생성하는 workflow를 추가한다.
5. package/version/signature 검사를 통과한 APK만 게시한다.

### 진행 순서

1. 새 Firebase Android 앱 등록과 설정 파일 확보 — 외부 프로젝트 변경이므로 사용자 승인·로그인 상태를 확인한 뒤 수행
2. 앱 ID·FlutterFire config 전환과 로컬 release APK 빌드
3. 정식 ID 앱의 Firebase Auth·Firestore 실기기 확인
4. release keystore 생성·오프라인 백업 및 GitHub Secrets 등록
5. Actions 수동 artifact 빌드·다운로드·업데이트 설치 확인
6. release workflow의 태그/버전/main 이력 가드 검증
7. 최종 release 승인 시 태그를 푸시해 GitHub Release APK 확인

### 현재 진행 상태

- **A 설정 전환 완료:** 사용자가 Firebase Android 앱 `kr.co.heowork0921.lostparty`를 등록하고 설정 파일을 전달했다. Gradle namespace/applicationId, MainActivity, `google-services.json`, `firebase.json`, Android `FirebaseOptions.appId`를 정식 ID와 Firebase app ID `1:574337852234:android:2e565a53ade5153dc057b3`로 맞췄다.
- 새 JSON client 존재·app ID 연결 검사, `flutter analyze lib/firebase_options.dart`, 기존 Android Studio JBR을 사용한 `:app:processDebugGoogleServices`가 통과했다.
- 사용자가 새 package APK가 기존 앱과 별도로 설치되고 정상 작동함을 확인해 정식 ID·Firebase 전환 게이트를 통과했다.
- **B 로컬 서명 완료:** 영구 JKS와 Git에서 제외되는 `android/key.properties`를 구성하고 Gradle release buildType을 해당 키로 전환했다. `flutter build apk --release`가 성공했으며 APK package `kr.co.heowork0921.lostparty`, version `1.0.0+1`, 인증서 `CN=LostParty, OU=Development, O=HeoWork0921`를 확인했다. 키와 비밀번호는 Git 변경 목록에 없다.
- **C workflow 원격 artifact 검증 완료:** CI는 비밀번호 파일을 만들지 않고 네 Repository Secrets를 환경변수로 전달한다. package/version/승인 인증서 검증, SHA-256, 7일 artifact, tag/main 이력 가드와 기존 Release 덮어쓰기 차단을 구성했다. 첫 실행 `35591621599`는 새 `apksigner` 출력 파싱 오류로 검증 단계에서 실패했으며 실제 빌드·서명 실패가 아니었다. 파싱을 수정한 `35592769624`에서 signed APK 검증과 artifact 업로드가 통과했다.
- **Secrets 등록 완료:** 사용자가 keystore·비밀번호의 별도 백업을 완료했고 GitHub Actions Secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`를 값 노출 없이 등록했다.
- **D signed artifact 실기기 확인 완료:** 임시 작업 브랜치 push trigger 제거본을 원격에 반영했고, 사용자가 성공 run `35592769624`의 artifact APK를 내려받아 실기기에 설치한 뒤 앱과 Firebase 기능이 정상 작동함을 확인했다.
- **E 통합·v1.0.0 게시 완료:** 작업 브랜치와 `dev`, `main`을 검증 커밋 `0c93b34`로 맞추고 `v1.0.0` 태그를 게시했다. 태그 run `35596035632`에서 signed APK 빌드·검증·artifact 업로드가 통과했다. checkout 없는 release job의 저장소 자동 판별 실패는 `--repo "$GITHUB_REPOSITORY"` 명시로 보정했고, 같은 성공 artifact의 SHA-256을 재검증한 뒤 공개 GitHub Release에 APK와 체크섬을 게시했다.
- **다음 게이트:** 릴리즈 파이프라인 작업은 종료한다. 기존 Firebase Android 앱 등록의 삭제 여부는 별도 운영 정리 작업으로 결정하고, 같은 키의 덮어쓰기 설치는 최초 후속 버전에서 확인한다.

### 완료 게이트

- 새 ID의 설치·Firebase 연결은 실기기에서 확인했다. 같은 키의 후속 버전 덮어쓰기 설치는 최초 후속 버전에서 확인한다.
- Secret 누락·버전 불일치·main 밖 태그·중복 Release는 게시 전에 실패한다.
- workflow는 앱 기능·Firestore·브랜치·태그를 임의 변경하지 않는다.
- 구현·Actions 검증·실기기 확인 전에는 `dev`에 통합하지 않는다.

## 완료 작업 — BUG-021 그룹 가입 신청 승인 Rules 회귀

참고: [`BUG_REPORTS.md`](BUG_REPORTS.md)의 `BUG-021`, [`FIRESTORE_GROUP_MEMBERSHIP_CONTRACT.md`](../architecture/FIRESTORE_GROUP_MEMBERSHIP_CONTRACT.md) §5~§8.

### 확인된 재현 경계

- 최초 관찰에서는 같은 앱 빌드에서 Player 2가 승인되고 Player 3만 실패하는 것으로 보였으나, 재신청 결과 Player 2도 동일하게 실패했다. 현재 그룹 신청 승인의 공통 회귀다.
- Player 3의 요청 거절과 같은 그룹의 초대코드 즉시 가입은 성공했다.
- 이 문구는 `blocked`와 Firestore `permission-denied`를 함께 표시하므로 화면 문구만으로 차단 여부를 확정하지 않는다.
- 초대코드 가입도 `blockedPlayers`, 활성 그룹 수 50개 제한, 그룹 정원, Player/Character 소유권과 활성 상태를 검사한다. 같은 Player가 같은 그룹에 코드로 가입했으므로 이 공통 조건과 전역 Rules·그룹 자체 장애는 우선 원인에서 제외한다.

### 코드 대조 결과와 1차 가설

1. 전달된 Player 3의 `groupMembershipState/current`는 `activeGroupIds=[]`, `activeGroupCount=0`, `revision=14`, `schemaVersion=1`, 같은 `playerId`로 확인됐다. 배열과 count가 일치하므로 이번 사례의 1차 원인을 membership 요약 불일치로 보지 않는다.
   이전에 승인이 성공했던 Player 2도 재신청 승인 시 동일하게 실패했고, 이 Player 역시 `activeGroupIds=[]`, `activeGroupCount=0`, `revision=6`인 기존 membership 문서를 가진다. 따라서 특정 디바이스·Player 하나의 고아 상태가 아니라 **빈 membership 문서가 남아 있는 재가입 계정의 공통 경로**로 범위를 수정한다.
2. 재확인 결과 문제 그룹 `p7RU5Dm8IfAMmGZg2hSv`에는 Player 3의 `joinRelations/{playerId}`와 `players/{playerId}/groupRelations/{groupId}`가 모두 존재하며, `application/applied`, `pending`, `sourceRevision=1`, Snapshot과 시각도 서로 일치한다. Projection 누락 가설은 폐기한다.
3. demo Rules CI `35562516961`에서 membership 문서가 아예 없는 최초 가입 승인도 `PERMISSION_DENIED`로 실패했고 Emulator가 `maximum of 1000 expressions`를 명시했다. 따라서 빈 membership update만의 문제가 아니라 **현재 그룹 신청 승인 Transaction 전체의 Rules 평가 예산 회귀**로 원인을 확정한다. 과거 계정별 성공 차이는 현재 데이터 고아가 아니라 이후 Rules OR가 늘거나 순서가 밀린 시점 차이로 본다.
4. 실패 로그는 한 승인 Transaction의 `joinRelations update`, `members create`, `groupMembershipState create/update`, `groupRelations create/update`, `groups update`에서 동시에 표현식 한도 도달을 가리킨다. 현재 각 allow에서 application 승인 분기가 일반 초대·신청·탈퇴·원자 모집 분기 뒤쪽에 있어, 승인과 무관한 validator를 먼저 평가한다. 이 저장소에서 그룹장 이전·초대코드·모집 신청 update도 같은 원인으로 실패했고 관련 분기를 앞쪽으로 옮겨 복구한 이력이 있다.
5. 신청 승인은 그룹장이 대상 Player의 private membership을 읽지 못하므로 `activeGroupIds=arrayUnion(groupId)`, `activeGroupCount=increment(1)`, `revision=increment(1)` 병합 쓰기를 보낸다. 전달 데이터라면 결과는 ID 1개/count 1/revision 15로 논리적으로 유효하므로 데이터 값 자체보다 Rules 평가 경로를 먼저 검증한다.
6. 추가한 회귀는 membership 문서가 없는 최초 승인과 빈 membership/revision 14 재가입 승인을 모두 성공 조건으로 둔다. Rules 평가 순서 수정 뒤 두 사례와 기존 전체 회귀가 Actions `35565203228`에서 함께 통과했다.

구현 상태: 제품 Dart 코드는 변경하지 않았다. `joinRelations`, `members`, `groupMembershipState`, Player `groupRelations`, `groups`의 application 승인 분기를 값싼 명령 식별 guard와 함께 앞쪽으로 옮겼다. 승인 조건·Transaction 문서 수·저장 스키마는 유지했다. 표적 정적 계약 5건과 전체 demo Rules 회귀 Actions `35565203228`이 통과했고, 추적 Rules SHA-256은 `907302E0747A28FFFB581DB295E60633C04811EF33E6AE3F161EA5A6CB5B0FD6`다. 사용자가 같은 Rules를 운영에 게시한 뒤 기존 승인 실패 Player 2명 모두 정상 승인됨을 확인했다.

### 조사 순서

1. 같은 증상이 다시 발생한 시점에 동작을 `신청 생성`, `그룹장 승인`, `초대 생성`, `초대 대상 수락`으로 구분하고 최초 실패 명령과 Firebase 오류 code를 기록한다.
2. 실패 Transaction 직전 아래 exact 문서만 대조한다. 전체 Player나 그룹을 순회하지 않는다.
   - `players/{targetPlayerId}/groupMembershipState/current`
   - `players/{targetPlayerId}/groupRelations/{groupId}`
   - `groups/{groupId}/joinRelations/{targetPlayerId}`
   - `groups/{groupId}/members/{targetPlayerId}` 존재 여부
   - `groups/{groupId}/blockedPlayers/{targetPlayerId}` 존재 여부
   - `groups/{groupId}`의 `status`, `leaderPlayerId`, `memberCount`, `revision`
3. **완료:** 보안 조건을 삭제하지 않고 승인임을 식별하는 싼 필드 guard 뒤 `validGroupApplicationDecision`, `validApprovedGroupMember`, `validLeaderApprovedMembershipStateAdd`, `validLeaderApprovedGroupRelation`, `validGroupLeaderApproveUpdate`를 각 관련 allow의 앞쪽에서 평가하게 했다.
4. **완료:** 최초 승인과 빈 membership 재가입 승인, 초대코드 가입, 그룹 생성·탈퇴·그룹장 이전·1인 해산을 같은 demo CI `35565203228`에서 검증했다. Rules 조건·문서 수·Transaction 구조는 바꾸지 않았다.
5. **완료:** 사용자가 검증된 Rules를 운영에 게시한 뒤 기존 승인 실패 Player 2명의 일반 가입 신청 승인을 실기기에서 확인했다. Indexes·Functions는 배포하지 않았다.

### 회귀 보호와 완료 조건

- 그룹 생성, 정상 Player의 신청·승인, 직접 초대·수락·거절, 초대코드 가입, 일반 탈퇴, 그룹장 이전과 마지막 1인 해산을 보존한다.
- block·50개 제한·정원·타인 조작은 계속 거절하며 private membership state를 그룹장에게 새로 공개하지 않는다.
- 인원수 비례 조회·쓰기, 전원 순회, Cloud Functions와 콘솔 수동 정리를 도입하지 않는다.
- 원인은 demo Rules CI로 확정했다. 수정은 승인 validator 평가 순서와 싼 guard에 한정하고 실제 UX는 사용자가 실기기에서 확인한다.
- 분석·수정·자동 검증·운영 게시·실기기 확인을 마쳤고 작업 브랜치를 최신 `origin/dev`에 fast-forward 통합했다. `main`은 변경하지 않았다.

### 실기기 확인됨 (고쳐진 것)

1. 레이드 모집방 생성
2. 그룹 생성
3. 공개 목록·레이드 현황·상세에 schemaVersion 2 모집이 보임
4. 그룹 직접 초대·수락, 검색 가입 신청·수락, 일반 그룹원 탈퇴, 그룹장 이전·이전한 기존 그룹장 탈퇴, 마지막 1인 해산
5. 초대코드 가입(사용자가 Rules 별도 게시 후 확인)
6. 수정 빌드에서 가입 신청 승인(2026-09-17 사용자 실기기 확인). 즉시 가입·재진입 후 전체 상태 검증은 별개다.
7. `이슈아이`의 수동 완료 체크 가능(2026-09-18 사용자 확인). 동일 레이드의 접근 불가 신청·정상 pending 영향 안내·체크 해제 등은 별도 회귀 항목이다.

### 실기기 복구 현황 (남은 항목 우선)

우선순위는 재현 빈도와 차단 범위다. 한 번에 하나의 승인된 묶음만 고친다.

| ID | 증상 | 비고 / 로컬에 있는 후보 수정 |
| --- | --- | --- |
| D1 | 그룹장 이전 permission-denied | **복구 확인:** 이전·기존 그룹장 탈퇴와 활성 그룹 모집 중 해산 차단 안내 실기기 통과 |
| D2 | 즉시 가입방 참가 실패 | 승인 필드·listing sync 등 앱 패치 있음. 실기기 미확인 |
| D3 | 신청 승인(수락) 실패 | 타인 `raidState` 읽기 제거 후 승인 버튼 실기기 통과. 멤버·상태 재진입 검증은 남음 |
| D4 | 신청 자체 중구난방 / 전부 실패처럼 보임 | Listen 가드·Rules/앱 불일치 혼재 가능. 원인 재분리 필요 |
| D5 | orphan: 그룹 탈퇴 후 그룹 전용방 해산 실패 | 해산 경로·문구 재확인 |
| D6 | orphan: 전체 공개(공개범위) 변경 실패 | 비멤버 파티장 그룹→공개 허용 앱 패치 있음. 실기기 미확인 |
| D7 | orphan: 참가 캐릭터 변경 권한 실패 | `validAtomicMemberCharacterChange`는 로컬 Rules에 있음. **캐릭터 OR 포함 재게시 503으로 미반영 가능** |
| D8 | orphan: 모집 삭제 → 「이 동작을 할 권한이 없습니다」 | UI를 leave→disband로 바꾼 패치 있음. 실기기 미확인 |
| D9 | 상세 `applications`/`cycles` Listen PERMISSION_DENIED 로그 | 리더·멤버만 구독하도록 가드 있음. 로그 재현 여부 재확인 |

### orphan 재현 시나리오 (D5~D8)

1. A 계정 그룹 생성  
2. B 계정 그룹 가입  
3. B 계정 그룹 전용 모집방 생성  
4. B 계정 그룹 탈퇴  
5. B가 해당 모집에서 해산 / 전체 공개 / 캐릭터 변경 / 모집 삭제 시도 → 실패

예방: 로컬은 그룹 전용방 파티장 탈퇴를 `activeGroupRaidExists`로 막도록 바꿨다. 이미 orphan인 방의 D5~D8 복구와 별개다.

### 운영 반영·배포

1. R7·초기 Rules·Indexes 게시 — **완료**
2. 생성·이전 등 Rules 재게시 — 사용자 확인으로 **게시됨**
3. 캐릭터 변경 OR를 포함한 최신 추적 Rules — F1 검증 뒤 2026-09-16 운영 `lost-party`에 게시 완료. 이전 `/test` 503 미반영 상태를 대체함
4. 실기기 회귀 — 위 **실기기 미해결** 목록을 기준으로 진행. 로컬 패치만으로 완료 표기하지 않음

## 운영 Rules 복구 커밋 슬라이스

기능 브랜치에서 Rules만 바꿀 때는 아래 순서를 지키며, 각 커밋은 단독 revert 가능한 복구 지점이다. 현재 연결된 운영 앱이 깨지지 않도록 **OR 추가·닫힌 스캐폴드**만 허용한다.

| ID | 커밋 의도 | 포함 | 단독 revert 시 | 상태 |
| --- | --- | --- | --- | --- |
| R1 | `raidStates`·`partyEvents` 경로 스캐폴드 | match 추가, 쓰기는 닫힘 | 미사용 경로만 제거 | 완료 |
| R2 | lifecycle envelope·raidState 검증 OR 추가 | 증명 Rules 이식, 구 cycle/disband 유지 | 미사용 OR만 제거 | 완료 |
| R3 | 그룹 `activeRecruitmentCount` 생성·종료 | `validInitialGroup` 키 허용, close 분기 | 구 그룹 생성 키 복원 | 완료 |
| R4 | schemaVersion 2 모집 생성 분기 | v1 생성 유지 + 원자 생성 OR | v2 생성 문만 제거 | 완료 |
| R5 | 비lifecycle raidState create·partyEvents | 가입·신청·탈퇴 등 이벤트 유형 | 미사용 create 검증 제거 | 완료 |
| R6 | Aggregate 멤버십 갱신 분기 | 가입·승인·캐릭터·자리·탈퇴·visibility OR | 미사용 update 분기 제거 | 완료 |
| C* | Router/DI·읽기·구 경로 차단·자료 초기화 | 앱 연결과 함께만 | 부분 배포·`dev` 병합 금지 | 완료 |
| R7 | legacy 미사용 validator·event 제거 | C* `allow`에서 떼어낸 함수 본문 삭제 | R7 revert | 완료 |

### C* 테스트 자료 초기화(wipe) — Firebase 경로

프로젝트: `lost-party`. Auth·계정·캐릭터는 보존하고 **파티·그룹 거래성 자료만** 삭제한다.

#### 보존 (삭제하지 않음)

- Firebase Authentication 사용자
- `authBindings/{authUid}`
- `players/{playerId}` 본문(상태·lastSeen 등)
- `players/{playerId}/weeklyRaidClaims/{claimId}` 중 `source == 'manual'`인 문서
- `players/{playerId}/characterActivity/{characterId}`
- `gameAccounts/{gameAccountId}`
- `characters/{characterId}`
- `characterIdentityClaims/{claimId}`
- `playerGameAccounts/{ownershipId}`
- `operatorAssignments/{playerId}`
- `accountVerificationChallenges/{challengeId}`, `activeAccountVerificationChallenges/{playerId}`
- `manualVerificationRequests/{requestId}`, `manualVerificationBlocks/{blockId}`
- `groups/{groupId}` 본문·`members`·가입 관계 등(그룹 자체는 유지). 다만 아래 listing·카운트 필드는 정리한다.

#### 삭제 대상 (경로)

1. **모집 Aggregate와 하위 문서**
   - `recruitments/{recruitmentId}`
   - `recruitments/{recruitmentId}/members/{playerId}`
   - `recruitments/{recruitmentId}/applications/{applicantPlayerId}`
   - `recruitments/{recruitmentId}/applications/{applicantPlayerId}/votes/{voterPlayerId}`
   - `recruitments/{recruitmentId}/slots/{slotId}` (예: `0_0`)
   - `recruitments/{recruitmentId}/cycles/{cycleKey}`

2. **공용 파티 이벤트**
   - `partyEvents/{eventId}`

3. **플레이어별 점유·구 스키마·파티 출처 이벤트·그룹 요약**
   - `players/{playerId}/raidStates/{stateId}` — **모집만 지우고 남기면 생성 시 stale delete가 필요해진다. 반드시 함께 삭제.**
   - `players/{playerId}/activeRaidAssignments/{assignmentId}`
   - `players/{playerId}/events/{eventId}` — 파티 명령 fan-out 출처만. `type == 'manualVerificationDisputeOpened'` 등 수동 인증 분쟁 이벤트는 보존해도 된다.
   - `players/{playerId}/weeklyRaidClaims/{claimId}` — 생성 테스트 레이드·주차와 겹치면 `raidState` create가 거절된다. `source == 'manual'`도 해당 캐릭터·레이드·주차면 삭제하거나 다른 레이드로 테스트한다.
   - `players/{playerId}/groupMembershipState/current` — 깨진 `activeGroupIds`/`revision`이면 그룹 생성이 deny될 수 있다. 문서 삭제 또는 `activeGroupIds: []`, `activeGroupCount: 0`, `revision: 0`으로 재작성.
   - `players/{playerId}/groupRelations/{groupId}` — 삭제된 그룹 ID 잔여는 정리한다.

4. **그룹 모집 listing·카운트**
   - `groups/{groupId}/raidListings/{recruitmentId}`
   - `groups/{groupId}` 문서 필드: `activeRecruitmentCount`를 `0`으로, `lastRecruitmentId`는 제거하거나 null로 맞춘다(그룹 문서를 통째로 지우지 않는다).

5. **wipe 후**
   - 앱을 재실행하고 공개/그룹 모집 **신규 생성**부터 회귀한다.
   - Indexes 빌드가 `Enabled`인지 콘솔에서 확인한 뒤 `partyEvents` audience 조회를 본다.

콘솔에서 컬렉션 단위로 비우거나, 테스트용 스크립트·수동 삭제로 위 경로만 처리한다. Auth·캐릭터·수동 Claim을 포함한 전체 프로젝트 삭제는 하지 않는다.

## 현재 작업 목표 — C* 전환 후 기능 복구

새 원자 구조를 되돌리지 않고, C* 전환 뒤 멈춘 그룹·파티 모집 기능을 이전 제품 계약대로 복구한다. D1~D9는 우선 장애 목록이며, 구조 전환이 공유 경로에 미친 회귀까지 함께 확인한다. 로컬 후보 패치나 자동 테스트만으로 완료 처리하지 않고 **현재 운영 Rules와 최신 앱을 사용한 실기기 성공**을 기능별 완료 기준으로 삼는다.

## 복구 원칙

1. `schemaVersion 2` 모집 Aggregate, 통합 `raidState`, 공용 `partyEvents`, 최대 8인 원자 명령을 유지한다. 구 assignment·개인 event fan-out 구조로 되돌리지 않는다.
2. 한 번에 하나의 실패 묶음만 재현한다. 실패한 Transaction의 읽기·쓰기 문서, `expectedRevision`, Rules OR 분기와 실제 Firebase 오류 단계를 확인한 뒤 수정한다.
3. Rules가 원인이라는 근거 없이 Rules를 넓히지 않는다. 앱 Write Plan·저장 Snapshot·Router 입력 불일치이면 앱에서 고친다.
4. Rules 수정이 필요한 묶음만 표적 계약과 전체 Rules Emulator 검증 후 운영 게시한다. 같은 소스 반복 게시나 503 추측 수정은 하지 않는다.
5. 이미 확인된 그룹 생성·모집 생성·v2 가시성을 각 묶음의 선행 회귀로 보존한다.
6. 기존 orphan 방 복구와 신규 orphan 생성 방지를 구분한다. 예방이 성공해도 이미 orphan인 방의 해산·공개 전환·캐릭터 변경·모집 삭제를 완료로 보지 않는다.
7. 기능 브랜치는 모든 핵심 흐름의 실기기 회귀가 끝날 때까지 `dev`·`main`에 병합하지 않는다.

## 기능 복구 범위

### 그룹

- 생성, 검색·상세·멤버 표시
- 초대·수락·거절·취소
- 가입 신청·승인·거절·차단 해제
- 초대코드 생성·공개 설정·폐기·코드 가입
- 일반 멤버 탈퇴
- 그룹장 이전 후 기존 그룹장 탈퇴
- 마지막 1인 그룹 해산
- 활성 그룹 전용 모집이 있을 때 탈퇴·해산 차단과 안내

### 파티 모집

- 공개·그룹 전용 모집 생성, 목록·현황·상세 읽기
- 신청·철회·거절·재신청
- 즉시 가입과 신청 승인
- 참가 캐릭터 변경, 빈자리 이동, 점유 자리 교환
- 일반 탈퇴·추방·가입 순서 기반 파티장 승계
- 공개↔그룹 전용 전환과 `raidListings` 동기화
- 그룹 자격 상실 멤버 정리와 orphan 방 복구
- 완료·반복 설정·수요일 06시 주차 전환·해산. 파티 전체 완료 취소는 2026-09-19 결정으로 제거 대상
- 공용 이벤트 조회와 종료된 하위 문서의 비활성 처리

## 복구 작업 단위

### F0. 실행 기준 고정과 재현 도구 정리

참고: [`PARTY_GROUP_COMMAND_SCALABILITY_REDESIGN.md`](../architecture/PARTY_GROUP_COMMAND_SCALABILITY_REDESIGN.md), [`BUG_REPORTS.md`](BUG_REPORTS.md), [`TASK-11-FIRESTORE-RULES-COMPLEXITY.md`](TASK-11-FIRESTORE-RULES-COMPLEXITY.md).

- 콘솔에 게시한 소스가 현재 추적 `firestore.rules`와 같은지 게시 시각·소스 또는 SHA-256으로 기록한다.
- 필요한 Index가 `Enabled`인지 확인한다. Index 오류와 Rules deny를 같은 증상으로 취급하지 않는다.
- 신규 schemaVersion 2 테스트 방과 기존 orphan 방을 구분해 테스트 ID·계정 역할·명령 직전 revision을 기록한다.
- 미추적 `tools/create_permission_rules_test.mjs`는 보석 도구가 아니라 현재 전체 Rules의 그룹·모집 생성 권한 검사다. 정식 C* 전체 Rules 회귀 도구 `tools/party_group_cutover_rules_test.mjs`로 이름과 범위를 정리하고 추적한다. 별도 Rules 사본 없이 루트 `firebase.json`의 추적 원본을 demo Emulator에서 사용한다.
- `firestore.rules-backup`은 구조 개선 전 로컬 백업이다. 배포 원본으로 사용하지 않으며 저장소 상태를 흐리지 않도록 ignore 대상으로 정리한다.
- 사용자가 수정한 `AGENTS.md`는 별도 문서 변경으로 보존하고, 기능 복구 코드와 같은 커밋에 섞지 않는다.

완료 조건: 운영 소스 기준, 테스트 데이터 기준, 재현 계정 역할과 자동 검사 진입점이 한 번에 식별된다.

현재 결과(2026-09-16):

- 사용자가 콘솔에서 직접 게시한 기준의 로컬 추적 Rules SHA-256은 `B9185B07241CC93880212616CB14C5823BD55EF7D71D8E4AC38B8D5EA0BA4DA1`, Indexes SHA-256은 `87716AC3100BC18065EBE96E1B78D09E37D21BB0E4A87BFA468B056C151EEE03`이다. 이후 실기기 재현은 이 Git 시점과 해시를 기준으로 기록한다.
- `firestore.rules-backup`은 SHA-256 `A66F8AE04AEEE633F3AD30A66A6345C974011B2A95767B3F9955A1573D17E0A7`의 구조 개선 전 로컬 백업으로 분류하고 `.gitignore`에 추가했다.
- 생성 권한 임시 도구를 `party_group_cutover_rules_test.mjs`로 정리했다. 루트 `firebase.json`과 추적 Rules를 쓰는 demo 전용 GitHub Actions 및 정적 계약 테스트를 추가했다. 운영 인증·배포 명령은 포함하지 않는다.
- 로컬 JBR 21에서 Emulator 자체는 시작됐지만 `initializeTestEnvironment`의 전체 Rules 업로드가 기존 Windows 환경 문제인 `503 Network closed for unknown reason`으로 Rules 평가 전에 종료됐다. 같은 로컬 접근은 반복하지 않으며 GitHub Actions 실행을 원격 엔진 검증 기준으로 사용한다.
- 신규 계약 테스트 2건은 통과했다. GitHub Actions 실제 실행은 기능 브랜치 커밋·push 이후 확인한다.

### F1. 그룹 쓰기 복구

참고: [`FIRESTORE_GROUP_MEMBERSHIP_CONTRACT.md`](../architecture/FIRESTORE_GROUP_MEMBERSHIP_CONTRACT.md), [`GROUP_LEADER_EXIT_DISBAND_CONTRACT.md`](../architecture/GROUP_LEADER_EXIT_DISBAND_CONTRACT.md), [`PARTY_GROUP_COMMAND_SCALABILITY_REDESIGN.md`](../architecture/PARTY_GROUP_COMMAND_SCALABILITY_REDESIGN.md).

F1 주요 흐름은 2026-09-16 실기기에서 복구 확인했다. 초대코드 가입도 사용자가 Rules 게시 후 성공을 확인했고, 활성 그룹 전용 모집이 있는 1인 그룹의 해산 차단 안내까지 확인했다. 다음 구현 대상은 F2다. 무효·폐기 코드 및 중복 가입의 이번 실기기 재검증은 최종 회귀 때 확인한다.

- 범위: 초대코드로 신규 가입하는 기존 트랜잭션 및 해당 Rules 경로만 재현·수정한다. 그룹 전용 모집과 비그룹원 표시는 F4의 별도 정책·작업으로 유지한다.
- 순서: 실제 Write Plan과 읽기/쓰기 세트를 전체 추적 Rules Emulator에 재현 → 실패한 문서·검증식/예산 확인 → 최소 수정 및 허용/거절 회귀 → Rules 계약·관련 테스트 → 변경 Rules 게시와 실기기 재확인.
- 보호: 그룹 생성·직접 초대·검색 신청/승인·그룹장 이전·탈퇴·해산은 기존 의미를 바꾸지 않는다. 가입자 외 문서를 전원 순회하거나 인원 비례 쓰기를 추가하지 않는다.
- 완료: 정상 코드는 가입 및 멤버/상태/Projection/인원수 일치, 무효·폐기 코드와 중복 가입은 안전하게 처리되고, 기존 F1 경로도 회귀하지 않음을 자동·실기기 결과로 확인한다.
- 진행 결과: 실제 가입 Write Plan을 복제한 전체 Rules Emulator에서 정상 코드 가입이 표현식 1,000개 한도로 거절됨을 재현했다(`35074490029`). 코드 가입을 먼저 평가하되 기존 그룹장 이전·탈퇴·해산 우선순위를 보존한 Rules로 `35075221872`에서 정상 가입과 F1 수명주기 회귀가 함께 통과했다. 정적 Rules·Write Plan 표적 41건도 통과했다. AI의 운영 게시 시도는 안전 심사에서 차단됐으나, 이후 사용자가 Rules를 별도로 게시하고 실기기 초대코드 가입 성공을 확인했다. 게시된 활성 소스의 해시는 별도 대조하지 않았으므로 추적 Rules SHA-256 `716FDBAF1C993444E6AF2C599328788DA0704206ED193B27F59D492EC480CDE6`과 동일하다고 단정하지 않는다. 이 초대코드 가입 회귀는 사용자 확인 기준 복구됐고, 무효·폐기 코드 및 중복 가입의 이번 실기기 재검증은 미확인이다.

우선 D1 그룹장 이전을 재현하되, 같은 `groups/{groupId}` update OR를 공유하는 일반 탈퇴·마지막 1인 해산·가입 승인도 함께 회귀한다.

검사 순서:

1. 앱이 보낸 group/membership state/relation/member 쓰기와 revision을 확인한다.
2. `validAtomicGroupRecruitmentClose/Open`이 해당 명령에서 문서를 선조회하지 않고 clean false로 빠지는지 확인한다.
3. transfer 성공 뒤 leader·member role, Player relation, membership state와 화면 갱신이 모두 일치하는지 확인한다.
4. 활성 그룹 모집이 있는 그룹장·파티장의 금지 동작은 권한 오류가 아니라 계약된 안내로 끝나는지 확인한다.

완료 조건: 그룹장 이전, 기존 그룹장 탈퇴, 일반 멤버 탈퇴, 마지막 1인 해산과 기존 그룹 생성이 실기기에서 통과한다.

현재 결과(2026-09-16, F1 주요 실기기 흐름 확인):

- 그룹장 이전은 그룹 1건과 이전·신규 그룹장 membership 2건, 일반 탈퇴와 1인 해산은 그룹·본인 membership·membership state·relation의 고정 문서만 갱신한다. 파티 인원이나 `raidListings` 수에 따른 Transaction fan-out은 사용하지 않는다.
- 앱의 1인 해산은 `activeRecruitmentCount == 0`을 검사했지만 Rules의 `validGroupDisbandUpdate`에는 같은 조건이 없었다. Rules에도 정수·0 조건을 추가해 우회 클라이언트가 활성 그룹 모집을 남기고 해산하지 못하게 했다.
- 전체 Rules Emulator 시나리오에 그룹장 이전 → 기존 그룹장 탈퇴, 일반 멤버 탈퇴, 1인 해산 성공과 활성 모집 1건일 때 해산 거절을 추가했다. GitHub Actions는 같은 demo 프로젝트에서 생성 기준선과 F1 시나리오를 각각 실행한다.
- 그룹 Rules·Write Plan·C* 기준선·Rules 경고 표적 테스트 42건과 변경 테스트 파일별 정적 분석이 통과했다. 최초 두 파일 동시 분석은 Flutter 프로세스가 출력 없이 정지해 종료했지만, 파일별 재실행은 각각 문제 0건으로 완료됐다.
- CI 실동작에서 과거 membership의 선택 Snapshot 필드 누락 평가 오류와 그룹장 이전의 Rules 표현식 1,000개 한도 초과를 발견했다. 선택 필드는 누락/null/정상 타입을 허용하고, 검증 조건을 완화하지 않은 채 그룹장 이전·role 변경 분기를 OR 앞쪽으로 옮겨 비용을 줄였다.
- GitHub Actions 실행 `35055217000`에서 전체 추적 Rules 생성 기준선과 F1 그룹 수명주기 Emulator 시나리오가 모두 통과했다. 앞선 실패 실행은 테스트 SDK API 오류와 위 두 Rules 회귀를 찾은 진단 근거로 유지한다.
- 운영 게시본 Rules SHA-256은 `A8E9D51EF6F52E2B38BAE1F72462B98F78A2DA105B1522C47152B54BBE54BA1B`이다. `firebase deploy --only firestore:rules --project lost-party` 1회 실행으로 컴파일·업로드·release가 성공했으며 Indexes 등 다른 자원은 게시하지 않았다.
- 그룹장 이전·이전 후 탈퇴·일반 탈퇴·1인 해산은 사용자 실기기 테스트에서 통과했다. 활성 그룹 전용 모집이 있는 1인 그룹의 해산 시도도 차단되고 전용 안내가 표시됨을 사용자가 확인했다.
- 해산 차단 경로의 로컬 계약 재확인: Repository는 `activeRecruitmentCount > 0`에서 `activeGroupRaidExists`를 반환하고 Rules도 그룹 해산을 `activeRecruitmentCount == 0`일 때만 허용한다. 관련 표적 테스트 49건이 통과했다. F4의 그룹장 레이드 관리가 구현되기 전에는 다른 공대장의 방을 그룹장이 직접 정리할 수 없다.

### F2. 참가 진입 복구

참고: [`PARTY_PARTICIPATION_RULES.md`](../product/PARTY_PARTICIPATION_RULES.md), [`FIRESTORE_PARTY_COMMAND_CONTRACT.md`](../architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md), [`WEEKLY_RAID_CLAIM_CONTRACT.md`](../architecture/WEEKLY_RAID_CLAIM_CONTRACT.md).

D2 즉시 가입, D3 신청 승인, D4 신청 불안정을 **신청 상태 전이 → 확정 참가 → 화면 재진입** 순서로 복구한다. 현 Router는 `FirestorePartyAtomicApplicationCommandRepository`와 `FirestorePartyAtomicJoinCommandRepository`를 실제 상세에 주입한다. 두 클래스의 오래된 “Router 미연결” 주석과 구 계약 문서의 `activeRaidAssignment` 서술을 실행 기준으로 삼지 않는다. 현재 기준은 schemaVersion 2 모집 Aggregate, Player별 `raidState`, 공용 `partyEvents`, 신청 원본 및 그룹 `raidListings`다.

#### F2-0. 생성→목록→후보→신청 계약 재정렬 (F2-A/B보다 선행)

참고: [`FIRESTORE_PARTY_READ_MODEL_CONTRACT.md`](../architecture/FIRESTORE_PARTY_READ_MODEL_CONTRACT.md), [`PARTY_PARTICIPATION_RULES.md`](../product/PARTY_PARTICIPATION_RULES.md), [`BUG_REPORTS.md`](BUG_REPORTS.md) BUG-019.

2026-09-17 실기기에서 새 공개방 신청의 `unknown` 오류, 기존 방의 타인 목록 미표시, 점유 캐릭터의 생성 후보 표시 누락과 생성 `permission-denied`가 함께 보고됐다. `BUG-019`의 확인/미확정 근거를 기준으로 아래를 **한 번에 설계하되 구현은 순서대로 검증 가능한 작은 구간으로 분리**한다. 기존 F1 그룹 흐름, 그룹 전용방 및 정상 공개방을 회귀 보호하고, 구 assignment 구조는 복원하지 않는다.

1. **증거 고정:** 실패한 신청 방과 보이지 않는 기존 방을 구분해 ID·공개/그룹·승인 방식·주차·`revision/status/visibility/manualRecruitmentEnabled/hasAvailableSlot`를 기록한다. 신청 방의 슬롯/비그룹/pending 집계, 생성 실패 캐릭터의 `raidState(status/cycleKey/recruitmentId)`와 연결 모집 상태, 실제 Firebase 오류 코드를 특정 문서로만 읽는다. 두 기기의 Player ID 구분, Router 생성 시 고정된 주차 키와 수요일 06시 전후 재진입도 확인한다. 목록 쿼리 필터로 의도대로 제외된 방인지 갱신/권한 오류인지 판정하기 전에는 필터를 넓히지 않는다.
2. **저장 불변식 복구:** 현재 공개·무그룹 초기 슬롯은 `countedAsNonGroupMember=false`인데 `nonGroupMemberCount=1`이며 신청 Repository가 Domain Aggregate 생성에서 서버 쓰기 전에 실패한다. 무그룹 방의 비그룹 집계 `0`을 기준으로 생성·가입·탈퇴/추방·캐릭터 변경·공개 범위 명령의 슬롯 Snapshot과 카운트를 대조하고, Rules 초기 생성 검증과 그룹 연결 공개방의 별도 의미를 함께 고정한다. `PartyAtomicCreateWritePlan.fromBase()` 결과를 즉시 `PartyAtomicDocumentMapper.aggregate()`로 읽는 왕복 테스트와 공개/그룹/그룹 연결 공개방 1→2명 전이 테스트를 추가한다. 기존 잘못 저장된 방은 수·소유·주차 확인 뒤 제한적 복구 또는 테스트 데이터 정리를 별도 결정하며 임의 삭제하지 않는다.
3. **후보·서버 판정 정렬:** Router의 후보 `FirestoreActiveRaidAssignmentLookup`이 구 `activeRaidAssignments`를 읽는 동안 생성/가입 명령은 `raidStates`를 쓴다. 조회를 현재 문서로 정렬하고 active/completed/이전 주차·만료 1회성·반복방·orphan 상태를 생성 `PartyCreateOccupancyGate` 및 주간 Claim 정책과 맞춘다. 생성 화면은 `candidate.canSelect`/역할 선택 가능성의 공통 결과를 사용해 동일 레이드 참가·이번 주 완료를 빨간 표시하고 선택을 막는다. 제출 직전 Transaction 재검증과 구체적 실패 안내는 유지한다.
4. **생성 permission-denied 분리:** 기존 점유의 연결 모집 `get`, stale `raidState` 교체, 신규 모집/membership/event의 각 Rules 쓰기 중 최초 실패 문서를 Emulator로 재현한다. 실제 서버 실패 단계가 확인된 경로만 앱 또는 Rules에서 최소 수정한다. 단순히 권한 분기를 넓히지 않는다.
5. **목록·신청 재검증:** 공개 목록의 현재 주차·활성·수동 모집·빈자리·타인 필터를 그대로 두고 저장값과 일치하는 방만 노출한다. 생성 결과가 read model과 Aggregate 양쪽에 유효한지 확인한 뒤 최초 신청→철회→재신청, 그룹 연결 공개방과 그룹 전용방, 즉시 가입·승인까지 진행한다. 화면 재진입과 구주차 전환도 포함한다.

완료 게이트: 새 공개/그룹 방의 생성→다른 계정 목록/상세→신청 또는 즉시 가입이 같은 원본·주차·집계를 사용하고, 점유/완료 캐릭터가 생성 전 후보에서 차단되며, 서버 경쟁 거절에는 구체적 안내가 나온다. 공개·그룹 생성, F1 그룹 수명주기, 주간 Claim, 1·2·4·8인 대표 Rules Emulator와 최대 3계정 실기기를 회귀한다. Rules 변경 시 계약/경고 검사 후 배포 정책을 별도로 적용하며 Indexes 게시·기존 운영 데이터 변경·`dev/main` 병합은 현 단계에서 제외한다.

진행(2026-09-17, 작업 브랜치 체크포인트 `887a0fb`·`6110013`): 공개·무그룹 신규 방의 초기 `nonGroupMemberCount`를 슬롯 Snapshot과 같은 `0`으로 맞췄고 가입 증분도 실제 추가 슬롯의 `countedAsNonGroupMember`를 기준으로 계산한다. Rules 초기 생성 조건과 전체 Emulator 생성 fixture를 같은 값으로 정렬했다. 생성 Write Plan→Aggregate 읽기 왕복과 공개방 1→2인 가입, 그룹 전용방 왕복을 표적 테스트로 고정했다. 생성 후보의 서버 조회를 구 `activeRaidAssignments`에서 `raidStates`로 변경하고 active 점유는 생성 명령의 `PartyCreateOccupancyGate`를 재사용한다. 생성 화면은 후보의 전체 `canSelect`를 적용한다. 직접 영향 Flutter 표적 42건, 변경 파일 정적 분석과 diff 검사는 통과했다. 전체 추적 Rules Emulator 및 F1 회귀 CI `35114485069`도 커밋 `7f8e269`에서 통과했다. CI 로그의 의도된 거절 테스트 `PERMISSION_DENIED`와 도구의 Node deprecation 경고는 Rules 컴파일 경고 수의 확인을 대신하지 않는다. 운영 게시, 기존 불일치 방 처리, 실제 방 데이터 대조와 실기기 회귀는 아직 완료하지 않았다. 기존 운영 Rules는 사용자 확인 게시본을 그대로 유지하며 새 Rules는 아직 게시하지 않았다.

운영 데이터 대조 및 재현(2026-09-17): `이슈하이`의 세 방은 모두 `targetCycleKey=2026-09-09`, `continueTogether=false`, `cycleEndsAt=2026-09-16 06:00 KST`, `status=active`라 현재 주차 공개 목록 제외는 의도된 쿼리 결과다. 세 방 모두 초기 슬롯의 `countedAsNonGroupMember=false`인데 `nonGroupMemberCount=1`이라 기존 방 신청 Aggregate 실패 대상이다. 기존 방 문서의 수동 변경은 보류한다. 이전 주차 1회성 active 방/raidState를 만들고 현행 생성 명령처럼 동일 Transaction에서 stale raidState `delete`→`set`하는 Emulator 회귀 `35168119595`는 Rules 1,000식 평가 한도의 `permission-denied`로 실패했다. 이는 새 주차 생성 거부의 재현 가능한 경로다(실제 실패 캐릭터의 raidState는 아직 읽지 않았으므로 개별 사건 확정은 유보).

다음 최소 수정: (a) `raidState`가 기존 모집의 만료된 1회성 점유임을 서버 문서·주차·종료시각으로 재검증하는 **단독 원자 삭제**를 생성 전 실행하고, (b) 새 모집·membership·raidState·공용 이벤트 생성은 기존 원자 Transaction을 유지한다. 삭제와 생성 사이 앱 종료/실패 시에는 이미 만료된 점유만 제거되고 기존 모집 문서는 유지되며 사용자가 재시도할 수 있어야 한다. 동일 주차 active·반복방·주간 Claim·소유권 불명 상태는 정리하지 않는다. 동시 변경은 삭제 Transaction과 생성 Transaction에서 각각 재검증하고 경쟁 시 구체적 충돌로 반환한다. 먼저 Emulator에서 stale 단독 삭제→새 생성 성공 및 반복방/이번 주 active 삭제 거부를 고정한 뒤 Repository를 수정한다. Rules 표현식을 단순히 완화하거나 전체 모집 문서를 삭제하지 않는다.

구현 진행: 전체 Rules Emulator CI `35168309443`에서 동일 Transaction 교체 거부, 만료 1회성 `raidState` 단독 삭제→신규 모집 원자 생성 성공을 확인했다. 생성 Repository는 점유 교체 판정 시 첫 Transaction에서 stale state만 삭제하고, 두 번째 Transaction에서 인증·캐릭터·점유·주간 Claim·그룹 상태를 다시 읽고 새 모집을 생성하도록 변경했다. 현재 주차 active 및 만료 반복방 삭제 거부까지 포함한 최종 Rules/F1 회귀 CI `35168721155`가 통과했고, 변경 Repository 분석 0건·직접 영향 Flutter 표적 27건도 통과했다. 전체 `flutter test`는 17건 실패, 전체 `flutter analyze`는 기존 파일을 포함해 38건 지적을 반환해 원인 분리 전에는 전체 회귀 완료로 간주하지 않는다. 실기기 생성/신청은 미검증이다. Rules는 이 수정에서 새로 변경하지 않았으며 운영에는 앞선 초기 생성 집계 Rules 수정본도 아직 미게시다. 새 앱의 `nonGroupMemberCount=0` 생성과 새 Rules의 초기 생성 조건은 함께 적용해야 하므로 운영 게시와 새 빌드 디바이스 테스트의 시점을 조율한다.

#### F2-A. 신청 상태 전이와 실패 지점 분리

참고: [`FIRESTORE_PARTY_COMMAND_CONTRACT.md`](../architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md), [`PARTY_PARTICIPATION_RULES.md`](../product/PARTY_PARTICIPATION_RULES.md).

1. 운영 게시 Rules·인덱스와 현재 앱 빌드의 기준을 확인한다. 공개/그룹 전용 방, 직접 참가/승인 방을 구분하고 actor Player·recruitmentId·applicationId, 명령 전 `revision/status/cycleKey`와 Firebase 오류 `code`를 기록한다. “신청 실패”가 명령 Transaction, 권한 있는 읽기·Listen, 화면 갱신 중 어느 단계인지 분리한다. Listen 자체의 일반 역할별 재설계는 F3에 남긴다.
2. 신청 생성 → 본인 철회 → 재신청, 파티장 거절 → 재신청, 승인 후 탈퇴 → 재신청을 각각 `applications/{playerId}`의 같은 문서 전이로 고정한다. `pending` 중복 거절, `revision` 증가, `approvalCount` 재신청 초기화, `rejectionCount` 유지, 신청 당시 `countedAsNonGroupApplicant`와 모집의 pending 집계 증감을 확인한다. 신청 대기는 `raidState` 확정 점유를 만들지 않는다.
3. 실제 Write Plan의 모집·신청·공용 이벤트 쓰기와 `validPendingApplication`/재신청/철회/결정 Rules를 현재 전체 Rules Emulator에 재현한다. Windows 로컬 전체 Rules 업로드 503은 이미 분리된 환경 문제이므로 같은 시도를 반복하지 않고 demo 전용 GitHub Actions를 엔진 검증 경로로 사용한다. 결함이 재현된 문서와 Rules 분기만 좁게 수정한다.

현재 진행(2026-09-16): 공개방 신청→철회→재신청은 전체 Rules Emulator `35087432007`에서 통과했다. 그룹 연결 공개방에서 재신청 시 `countedAsNonGroupApplicant`가 바뀌는 경계는 `35087675480`에서 신청 update의 표현식 1,000개 한도 `PERMISSION_DENIED`로 재현했다. 재신청 허용 필드에 해당 Snapshot을 추가하되 현재 그룹 membership과 일치시켰고, 신청 update는 새 상태별 분기만 평가하도록 조정했다. 수정본 `35104429826`, 그룹 전용방의 정상/변조 재신청까지 확장한 `35104711642`의 전체 추적 Rules·F1 회귀가 통과했다. 관련 Flutter 표적 46건, 변경 테스트 파일 분석과 `git diff --check`가 통과했다. 최신 Rules SHA-256은 `AAB74C69483AE1C46AF69C3D8378F30573581AAA1FCBBB1485181BFBD31255D5`이다. 최초 운영 게시 시도는 안전 심사에서 명령 실행 전 거절됐다. 이후 사용자가 이 버전의 게시를 승인했으나 CLI 결과는 작업 중단으로 확인하지 못했다. 사용자는 현재 운영 게시 Rules와 로컬 파일의 내용이 동일함을 직접 확인했다. 따라서 소스 일치는 사용자 확인으로 기록하고, CLI 컴파일 경고 수·게시 시각·실기기 성공은 확인하지 않은 상태로 둔다. 동일 Rules의 재게시 없이 F2-A 실기기 신청→철회→재신청 결과를 먼저 받는다.

실기기 피드백: 최초 신청에서 `신청을 처리하지 못했습니다.`가 표시됐다. 원자 신청 Repository에 추가한 디버그 빌드 전용 로그로 `PartyAtomicDocumentMapper.aggregate()`의 `ArgumentError: 모집 Aggregate 집계가 올바르지 않습니다`를 확인했다. 서버 쓰기 전 저장 문서와 Domain 불변식의 불일치이며 이 신청의 Rules `permission-denied`는 아니다. 신청 쓰기·Rules·사용자 안내는 아직 변경하지 않았다. F2-0의 생성 집계 복구와 기존 방 처리 방향을 먼저 확정하고, 실패 방의 실제 저장값을 확인하기 전에는 F2-A를 완료로 처리하지 않는다.

#### F2-B. 즉시 가입과 승인 확정

참고: [`FIRESTORE_PARTY_COMMAND_CONTRACT.md`](../architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md), [`WEEKLY_RAID_CLAIM_CONTRACT.md`](../architecture/WEEKLY_RAID_CLAIM_CONTRACT.md), [`BUG_REPORTS.md`](BUG_REPORTS.md) 승인 실패 기록.

실기기 디버그 근거(2026-09-17): 가입 승인 버튼에서 모집 문서와 신청 문서 읽기는 성공했고, `FirestorePartyAtomicJoinCommandRepository._join`의 신청자 `players/{applicantPlayerId}/raidStates/{characterId}_{raidId}` `transaction.get`에서 `permission-denied`가 발생했다(실기기 10:45 KST). Rules의 raidState `get`은 `playerId == currentPlayerId()`만 허용한다. 따라서 승인 쓰기/Rules 조합은 아직 실행되지 않았으며 과거의 승인 쓰기 추정 패치를 성공으로 취급하지 않는다. 다음 최소 수정은 승인 actor가 타인 raidState를 읽지 않고, 신규 raidState `create`와 주간 Claim의 기존 서버 Rules가 중복·완료 점유를 최종 거부하도록 하는 것이다. 본인 즉시 가입은 기존 상태 조회·stale 판정을 유지한다. 먼저 Emulator에서 정상 승인 및 타인 raidState 단건 get 거부, 기존 점유/Claim 승인 거부를 재현하고 그 뒤 Repository만 좁게 변경한다. 승인 완료 후 다른 문서의 Rules 한도·권한 실패가 드러나면 동일 명령의 첫 실패 지점을 다시 로그로 확인한다.

수정·검증(2026-09-17): 승인 경로만 신청자 `raidState`의 Transaction 읽기를 생략하고 본인 즉시 가입의 읽기/충돌 판정은 유지했다. 승인자 타인 state `get` 거부·정상 승인 성공은 전체 Rules Emulator CI `35171953952`, 기존 점유와 주간 완료 시 승인 거부까지 포함한 CI `35172188208`에서 통과했다. Repository·계약 테스트 분석 0건, 직접 영향 Flutter 표적 12건 통과. **사용자가 수정 빌드의 가입 승인 성공을 실기기에서 확인했다.** 멤버·상태/신청 화면의 재진입 일관성과 즉시 가입은 별도 확인이 남았다. 현 규칙에서는 충돌 거절도 `permission-denied`로 매핑될 수 있다. 이 승인 수정에서 Rules는 변경하지 않았다.

2026-09-18 후속 판정: `니티야`의 4막 승인 실패는 삭제된 모집 원본을 참조하는 기존 `active raidState`와 연결됐다. 같은 방장·신청자 Player의 다른 Character 승인은 성공했으므로 일반 승인 전체의 권한 오류로 취급하지 않는다. 신청 단계가 기존 active 점유를 허용하고 승인에서 모호한 권한 팝업이 되는 경계는 F6-D로 분리한다. 서버 고아 문서의 수동 정리는 이번 기능 복구에서 제외한다. 상세 근거는 `BUG_REPORTS.md` 2026-09-18 항목이다.

4. 즉시 가입은 신청 문서 없이 본인 actor가, 승인은 현재 승인권자가 `pending` 신청자를 확정한다. 두 경로의 성공 결과가 모집 `partySlots/memberPlayerIds`·인원/역할/그룹 집계·revision, 대상 membership·`raidState`, 그룹 listing 전체 Snapshot, 공용 이벤트 1건에서 일치하는지 비교한다. 승인 전이는 `approvedByApprover`, `approvalCount + 1`, pending 집계 −1이며 신청 당시 그룹 집계 Snapshot을 사용한다.
5. Rules의 읽기·쓰기 순서를 따로 검증한다. 가입/승인 모두 소유 Character·주간 Claim·현재 회차·정원·역할/동일 파티 직업·기존 확정 점유·그룹 접근 권한을 Transaction에서 재판정한다. 승인자가 타인의 stale `raidState`를 지우지 않으며, 본인 즉시 가입의 stale 정리도 Rules가 허용하는 경우에만 수행한다. 다중 승인·가입 경쟁, revision 충돌, 중단 후 재시도에서 멤버·점유·이벤트·집계가 중복되지 않아야 한다.

#### F2-C. 연결 검증과 완료 게이트

참고: [`PARTY_GROUP_COMMAND_SCALABILITY_REDESIGN.md`](../architecture/PARTY_GROUP_COMMAND_SCALABILITY_REDESIGN.md), [`FIRESTORE_PARTY_READ_MODEL_CONTRACT.md`](../architecture/FIRESTORE_PARTY_READ_MODEL_CONTRACT.md).

6. 각 수정 뒤에는 기존 모집/그룹 생성과 v2 목록·현황·상세, F1 이전·탈퇴·초대코드·해산 차단을 회귀 보호한다. 표적 Domain/Write Plan/Rules 계약과 전체 Rules Emulator의 허용·거절 케이스를 먼저 통과시키고, Rules가 실제 변경됐을 때만 배포 절차를 적용한다. Indexes 게시가 새로 필요하면 별도 명시 지시를 받는다.
7. 자동 검증 후 최대 3계정 실기기에서 공개·그룹 전용 각각 신청/철회/거절/재신청/승인/즉시 가입을 확인한다. 같은 레이드 복수 pending은 허용하되 첫 확정 참가 뒤 중복 확정은 차단하고, 만석·역할/직업 충돌·주간 완료·구 회차 및 앱 재진입을 대표 경계로 확인한다. 4·8인 경계와 경쟁은 Emulator로 보강하고 8대 디바이스를 요구하지 않는다.

완료 조건: D2~D4의 실제 실패 지점과 수정 근거가 기록되고, 공개/그룹 방의 신청 상태 전이·확정 참가가 자동/실기기에서 일관되게 통과한다. 권한 오류나 재시도에서 부분 성공·중복 저장이 없고 기존 F0/F1 흐름이 유지된다. F3 Listen 전체·F4 orphan/그룹장 관리·F5 자리 조정·F6 회차 수명주기 구현은 이번 묶음에서 제외한다.

### F3. 상세 읽기와 Listen 복구

참고: [`FIRESTORE_PARTY_READ_MODEL_CONTRACT.md`](../architecture/FIRESTORE_PARTY_READ_MODEL_CONTRACT.md), [`FIRESTORE_PARTY_COMMAND_CONTRACT.md`](../architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md).

D9를 독립 묶음으로 처리한다. 공개 방문자, 신청자, 확정 멤버, 파티장별로 허용된 구독이 다르므로 화면 진입 시 실제로 연 Listener를 역할별로 대조한다.

- 신청 전체 목록은 파티장만 구독한다.
- 본인 신청은 본인 단건 경로만 구독한다.
- 구 `cycles`는 리더·확정 멤버만 읽고, v2 회차 상태는 모집 Aggregate를 기준으로 표시한다.
- 구독 권한이 없는 역할은 Listener를 시작하지 않으며 로그에 `PERMISSION_DENIED`를 남기지 않는다.

완료 조건: 네 역할의 상세 진입·이탈·재진입에서 화면과 로그가 정상이고 기존 목록·현황 가시성이 유지된다.

### F4. orphan 예방과 복구

참고: [`PARTY_GROUP_COMMAND_SCALABILITY_REDESIGN.md`](../architecture/PARTY_GROUP_COMMAND_SCALABILITY_REDESIGN.md), [`FIRESTORE_PARTY_COMMAND_CONTRACT.md`](../architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md), [`BUG_REPORTS.md`](BUG_REPORTS.md).

D5~D8을 같은 재현 시나리오로 시작한다. 사용자가 확인한 정책상 **현재 그룹장에게 그룹 전용방의 전체 공개 전환·모집 해산 두 권한만 추가**하며, 방 참가 여부는 조건이 아니다. 공대장·그룹장 역할을 합치거나 그룹장 Player ID를 모든 모집에 복제하지 않는다. 계약은 `docs/product/GROUP_PRODUCT_FLOW.md` §9.3을 따른다.

#### 조사로 확인한 기존 경계와 선행 회귀

- 그룹 상세에는 연결 모집 관리 화면이 없다. 공개 모집 목록은 신청 가능한 현재 주차 방을 필터링하므로 만석·모집 일시 중단·이번 주차 완료 반복방을 관리 목록 대신 사용할 수 없다.
- `groups/{groupId}/raidListings`는 그룹원에게 읽기가 허용되고 정상 명령에서 원자 동기화되지만 과거 누락 가능성이 있다. 그룹의 `activeRecruitmentCount`가 남아도 listing만으로는 누락 방을 찾아낼 수 없다.
- 현재 원자 해산·공개 전환 Repository, Rules 및 상세 버튼은 모집 `leaderPlayerId`만 허용한다. 그룹장이 방 참가자가 아니면 기존 모집 상세의 일부 하위 자료도 읽을 수 없다. 전용 관리 카드는 모집 원본의 허용된 요약만 사용한다.
- 전체 공개 전환 뒤에도 모집 `groupId`는 남는다. 현재 `PartyAtomicWritePlan.closesActiveGroupRecruitment`와 `groupListingAction`, Rules의 `atomicClosesActiveGroupRecruitment`는 일부 경로에서 `groupId`만 보고 그룹 집계·listing을 다시 변경할 수 있다. **공개 전환 후 완료·해산·다음 명령의 이중 감소 또는 없는 listing 갱신**을 먼저 고쳐 회귀로 고정한다. `visibility == group`이며 아직 활성 집계 대상일 때만 그룹 수·listing을 변경해야 한다.
- 8인 원자 해산은 Rules 문서 접근 예산이 이미 최대치에 근접한다. 그룹장 권한을 추가하는 get/getAfter가 개별 쓰기 10회·전체 20회 또는 표현식 1,000개 한도를 넘지 않는지 실제 Emulator로 증명한다. 캐시를 가정하지 않는다.

#### 포함 범위와 순서

1. 원본 모집 기준 관리 목록의 읽기 계약을 먼저 증명한다. 기준은 `groupId == 현재 그룹 && visibility == group && status == active`로 고정한다. 그룹장만 페이지를 열고, 방당 제목·레이드·난이도·공대장·인원·반복/회차 상태를 본다. 완료된 1회성·해산·전체 공개 방은 제외하고, 이번 주 완료된 활성 반복방과 만석방은 포함한다. 목록은 페이지네이션으로 끝까지 조회하며 첫 20건만으로 전체라고 판정하지 않는다. 이 정확한 원본 쿼리에 필요한 Firestore Rules list 계약·복합 인덱스를 Emulator에서 선검증한다. Rules 비용 안에서 원본 쿼리를 안전하게 허용할 수 없다면 불완전한 `raidListings`만으로 화면을 만들지 말고, 조회 계약과 누락 복구 방안을 다시 설계한 뒤 진행한다. 인덱스 운영 게시가 필요하면 별도 명시 지시를 받는다.
2. 그룹 상세에 `그룹 레이드 관리` 버튼과 전용 화면을 연결한다. `activeRecruitmentCount > 0`인데 원본 목록이 비거나 최종 전체 건수와 다르면 불일치를 표시하고 그룹 해산 성공처럼 안내하지 않는다. 자동 카운트 재작성이나 listing 삭제로 덮지 않는다. 누락 원본/집계 복구는 정확한 모집 ID·revision을 확인할 수 있는 별도 진단 경로로 다룬다.
3. 전체 공개 전환은 현재 공대장 **또는** 해당 그룹의 현재 그룹장만, 모집이 그룹 전용·active일 때 허용한다. 기존 visibility Transaction에서 모집·그룹 활성 수·listing 삭제를 함께 확정하고 groupId 이력은 유지한다. 그룹장이 아닌 일반 그룹원과 다른 그룹장은 거절한다.
4. 모집 해산도 현재 공대장 **또는** 해당 그룹의 현재 그룹장만 그룹 전용방에서 허용한다. 그룹장 명령은 기존 최대 8명 `raidState` 해제·모집 종료·그룹 수 감소·listing 제거·공용 이벤트의 원자 계약을 그대로 충족한다. `lastCommandActorPlayerId`와 실제 호출자를 맞추되 모집 공대장·멤버십은 변경하지 않는다. 완료·주차 전환·신청 승인·자리 조정 권한은 기존 공대장 정책을 유지한다. 파티 전체 완료 취소 기능은 역할과 관계없이 제거한다.
5. 기존 orphan 방의 공대장 명령(D5~D8: 공개 전환·캐릭터 변경·모집 삭제→해산·직접 해산)을 다시 검증한다. 그룹장은 추가 두 명령만 실행한다. 그룹 전용방 공대장의 그룹 탈퇴를 막는 현행 로컬 가드는 새 구조와 과거 orphan 복구의 실기기 확인 뒤 제거 여부를 결정한다.

#### 회귀·완료 조건

- 3개 이하 계정으로 그룹장·방 공대장·일반 그룹원을 분리해 권한을 확인한다. 그룹장 이전 직후 새 그룹장만 관리할 수 있어야 하며, 그룹장이 방에 참가하지 않아도 두 명령이 가능해야 한다.
- 목록에는 활성 반복방(이번 주 완료 포함), 만석, 모집 일시 중단이 보이고 완료된 1회성·해산·전체 공개는 보이지 않는다. 그룹 해산 차단 수와 목록 전체 건수가 같거나, 불일치가 명시적으로 드러난다. 오래된 listing, 원본 누락과 20건 초과도 점검한다.
- 그룹장 공개 전환/해산 뒤 집계는 정확히 한 번 감소하고 그룹장 단독 그룹 해산이 가능하다. 전체 공개로 전환한 방은 기존 공대장이 완료·해산·다음 주차 전환을 계속할 수 있으며 그룹 집계·listing을 다시 건드리지 않는다.
- 기존 공대장 명령, 과거 orphan 방 복구, 일반 공개방 권한, 1·2·4·8인 원자 해산과 Rules 접근 한도를 표적·전체 Emulator 및 실기기로 확인한다. 완료 전까지 `dev`·`main` 통합이나 운영 배포 완료 판정을 하지 않는다.

### F5. 파티 구성 변경 회귀

참고: [`PARTY_PARTICIPATION_RULES.md`](../product/PARTY_PARTICIPATION_RULES.md), [`FIRESTORE_PARTY_COMMAND_CONTRACT.md`](../architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md), [`CHARACTER_BUILD_INTEGRITY_CONTRACT.md`](../architecture/CHARACTER_BUILD_INTEGRITY_CONTRACT.md).

2026-09-17 복구 후보: 승인 성공 직후 사용자가 자리 변경·추방·해산 실패를 보고했다. 자리 변경 Rules의 멤버 projection 갱신이 폐기된 `slots` 문서를 요구하던 불일치를 `partySlots` 전후 위치 확인으로 바꿨다. 추방은 타인 개인 `raidState`의 Transaction 읽기를 생략하고 삭제를 Rules에 검증시키며, 본인 탈퇴의 상태 읽기는 유지한다. demo 전체 Rules CI `35190655744`는 2인 이동·추방·활성 해산과 기존 그룹 회귀, `35190876922`는 점유 자리 교환·4/8인 활성 해산, `35191028614`는 완료방 해산 시 개인 완료 상태 보존, `35191866476`는 그룹 연결 방 해산의 집계·listing 정리, `35192360261`은 추방 후 직접 재가입까지 통과했다. CI fixture의 본인 제거를 `추방`이라 표기한 음성 테스트는 실제 타인 추방 테스트가 아니어서 바로잡았다. 앱 저장소와 Rules의 표적 분석·테스트는 통과했다. 최신 Rules SHA-256은 `3BA4889260B3BF74B1303E34ECFEF2B3D2A74284E59F0354A97BFC9D5D5F6FD4`다. 최초 운영 Rules 게시 시도는 안전 심사에서 명령 실행 전에 거절됐고, 사용자의 별도 명시 승인 후 `firebase deploy --only firestore:rules --project lost-party` 1회가 컴파일 경고 없이 release까지 성공했다. 다른 자원은 게시하지 않았다. 수정 디버그 APK를 데이터 유지 설치했고 **자리 변경·참가자 추방·실제 재가입 완료·참가자 있는 활성 방 해산 후 재참가 가능 상태를 사용자 실기기에서 확인했다.** 같은 테스트 시간대 `PartyAtomicJoin permission-denied` 로그가 3건 있었으나 최종 재가입은 성공했다. 당시 반복 시도나 다른 대상 방의 실패인지 확정할 자료가 없어 별도 재현 전까지 원인·복구 완료를 주장하지 않는다. 앱 재진입 후 상태·완료방·그룹 전용방의 실기기 검증은 별도다. 중단된 전체 `flutter test`를 다시 끝까지 실행한 결과 1,157건 통과·17건 실패로, 앞선 전체 실행의 실패 수와 같다. 전체 회귀 통과로 표시하지 않으며 실패 테스트의 기존 결함/신규 영향 분리는 F7에서 수행한다.

- 참가 캐릭터 변경의 membership·Aggregate slot·`raidState` 교체가 한 Transaction에서 일치한다.
- 자리 이동·교환은 같은 파티의 동일 직업 제한을 유지하고 다른 파티 이동 가능 정책을 보존한다.
- 탈퇴·추방·파티장 승계는 대상과 필요 후임만 바꾸며 그룹 listing과 공용 이벤트를 동기화한다.
- 보석·아크그리드 `buildIntegritySnapshot` 표시를 보존한다.

완료 조건: 4인과 8인 대표 구성에서 변경·이동·교환·탈퇴·추방·승계가 통과한다.

### F6. 회차 수명주기 회귀

참고: [`WEEKLY_RAID_CLAIM_CONTRACT.md`](../architecture/WEEKLY_RAID_CLAIM_CONTRACT.md), [`PARTY_GROUP_COMMAND_SCALABILITY_REDESIGN.md`](../architecture/PARTY_GROUP_COMMAND_SCALABILITY_REDESIGN.md), [`RAID_CATALOG_DATA.md`](../product/RAID_CATALOG_DATA.md), [`BUG_REPORTS.md`](BUG_REPORTS.md).

활성 해산은 타인 개인 `raidState` 읽기를 생략하고 Rules의 전원 대상·삭제 검증을 사용한다. 완료 후 해산은 기존처럼 대상 상태를 읽거나 삭제하지 않는다. 전체 완료·취소·회차 전환은 이번 수정 범위가 아니며 별도 실기기 회귀가 필요하다.

2026-09-18 후속 판정: `이슈아이`의 모든 레이드 수동 체크는 구 assignment나 해당 Character Claim 잔여가 아니라 `_loadConflictContext`의 접근 불가 그룹방 신청 부모 읽기에서 먼저 실패한다. 바로 아래 F6-B1에서 이 조회 경계만 우선 복구한다. 수동 `weeklyRaidClaims`와 새 파티 `raidState`의 별도 계약 간극·완료방 해산 후 체크 누락은 F6-B2로 유지한다.

2026-09-17 실기기 신규 회귀: 완료방 해산 후 내 계정의 완료 체크가 보이지 않는다. 또 모집 생성 첫 진입은 대표 캐릭터와 첫 레이드(4막)를 암묵적 기본값으로 사용한다. 대표 캐릭터로 이미 4막 방을 생성·참가했거나 이번 주 완료한 뒤 다시 들어오면 그 기본 조합이 생성 불가능하여 캐릭터/레이드 선택이 함께 막힌다. 캐릭터가 많은 원정대에서는 다른 캐릭터→다른 레이드→원래 대표 캐릭터 순서로 우회할 수 있지만, 캐릭터가 하나인 사용자에게는 우회 경로도 없다. 완료방 해산의 원자 Write Plan은 완료 `raidState`를 보존하지만 내 계정 체크 UI는 구 `weeklyRaidClaims`만 구독한다. 생성 페이지는 기본 레이드에서 `candidate.canSelect`가 거짓이면 대표 캐릭터를 초기 선택하지 않고, 캐릭터가 없으면 레이드 옵션을 비운다. **저장 상태 보존 테스트의 통과를 UI 완료 체크 통과로 취급하지 않는다.**

복구 설계: (1) 실기기 해당 `raidState`의 `cycleKey/status/source/recruitmentId`와 구 Claim 존재 여부를 읽기 전용으로 대조해 완료 명령·해산·표시 중 첫 불일치를 확정한다. (2) 주간 완료 읽기를 수동 Claim과 파티 `raidState`가 일관된 하나의 화면 판정으로 합치되 주차 경계·개인 체크 해제·중복 상태의 우선순위를 계약 테스트로 고정한다. 신규 명령에 구 Claim 복제 쓰기를 추가하지 않으며 파티 전체 완료 취소는 제거한다. (3) 모집 생성의 초기 레이드 선택을 비우고 대표 캐릭터를 탐색 기준으로 유지하는 사용자 제안을 우선 검토한다. 캐릭터의 역할·아이템 레벨에 맞는 레이드 목록을 보여주되, 선택 레이드가 없을 때는 저장을 불허한다. 현재 Form과 draft가 선택 레이드/난이도를 필수로 받는 구조이므로 null 초기 상태의 UI·검증·제목 생성 영향을 함께 설계한다. 대표 캐릭터가 어느 레이드에도 참가할 수 없더라도 캐릭터 변경은 가능해야 한다. **기존 생성·참가·이번 주 완료 차단을 완화하지 않고**, 선택한 레이드의 후보 재판정과 서버 최종 검증을 유지한다. (4) 기본 대표 캐릭터의 동일 레이드 생성·참가·완료 각각에서 다른 레이드 선택, 단일 캐릭터/다중 캐릭터, 레이드 미선택 저장 거절, 기존 정상 생성, 완료 후 해산 체크 유지, 반복방/주차 전환을 자동·실기기로 검증한다. 이 묶음에서 Rules 변경이 필요하다고 확인되기 전에는 재게시하지 않는다.

- 활성 방 완료, 반복방 완료, 개인 체크 해제, 반복 설정 변경, 수요일 06시 주차 전환, 활성/완료 후 해산을 검증한다. 파티 전체 완료 취소 버튼·명령이 노출되지 않고 서버에서도 거절되는지를 포함한다.
- 모집과 최대 8개 `raidState`가 전부 반영되거나 전부 미반영되는지 확인한다.
- 수동 주간 Claim과 파티 `raidState` 충돌, 종료 하위 문서의 비활성 처리와 내 계정 체크 표시를 함께 확인한다.

완료 조건: 1·2·4·8인 자동 계약과 3계정 이하 대표 실기기 시나리오가 통과한다.

#### F6 후속 실행 순서 — B1 표적 복구 확인, B2 상세 설계 대기 (2026-09-18)

두 결함을 하나의 권한 패치로 합치지 않는다. 현재 실기기에서 성공한 방 생성·신청 거절·정상 캐릭터 승인·자리 변경·추방·활성 해산은 매 단계 회귀 보호한다. 정확한 ID·시각·데이터 근거는 `BUG_REPORTS.md`의 2026-09-18 항목에만 둔다.

1. **F6-A — 첫 실패 지점 확인: 완료.** `니티야`의 4막 승인 실패는 삭제된 모집 원본을 가리키는 기존 `active raidState`와 부합한다. 같은 방장·신청자 Player의 다른 Character 승인은 실기기에서 성공했다. `이슈아이`의 모든 수동 완료 체크 실패는 별개로, 해산된 그룹 전용방의 잔존 pending 신청 부모를 `_loadConflictContext`가 읽다가 `permission-denied` 되는 지점까지 확인했다. 그룹은 `softDeleted`/멤버 0명이다. 두 서버 상태 모두 현재 보존하며 수동 정리하지 않는다. 원인 확인용 임시 단계 로그는 B1 검증 후 제거했다.
   - 참고: [`BUG_REPORTS.md`](BUG_REPORTS.md) 2026-09-18 원인별 데이터 근거, [`DEV_LOG.md`](DEV_LOG.md) F6-A 진단 이력.
2. **F6-B1 — 수동 체크 장애의 최소 복구: 완료.** 접근 불가·종료된 방의 pending 신청이 다른 레이드의 수동 완료를 막지 않도록 신청 이력 조회/분류만 수정한다. 부모 모집 `get`이 `permission-denied`인 신청은 현재 수동 완료 명령에서 조작 가능한 대상으로 간주하지 않고 **그 신청만 건너뛴다**. 다른 Firebase 오류·정상적으로 읽히는 현재 주차 신청은 건너뛰지 않는다. 접근 가능한 같은 레이드 pending 신청의 영향 안내·기존 철회/정리 흐름은 유지한다. 건너뛴 신청을 서버에서 자동 삭제·거절·철회하지 않으며, 이후 승인 시 Claim 존재를 Rules가 최종 거부한다. Rules와 서버 데이터는 변경하지 않았다.
   - 완료 근거: 부모 모집 읽기의 `permission-denied`만 해당 신청을 제외하는 최소 변경과 표적 테스트 8건·변경 파일 분석 통과. 사용자가 `이슈아이` 수동 체크·해제, 완료 상태에서 동일 레이드 모집 캐릭터 선택 차단, 정상 pending 신청 1건 안내 및 실제 취소를 확인했다. 다른 Firebase 오류 전파는 자동 테스트, Claim 존재 시 승인 거절은 기존 Rules Emulator 계약으로 보호한다. 임시 단계 로그는 제거했다. 주차 전환과 새 `raidState` 통합은 B2/F7 범위이며 B1 완료를 F6 전체 완료로 확장하지 않는다.
   - 참고: [`WEEKLY_RAID_CLAIM_CONTRACT.md`](../architecture/WEEKLY_RAID_CLAIM_CONTRACT.md) §3·§5·§6, [`BUG_REPORTS.md`](BUG_REPORTS.md) 2026-09-18, [`DEV_LOG.md`](DEV_LOG.md) F6-A/B1 기록, `tools/party_group_cutover_rules_test.mjs`의 Claim 존재 시 승인 거절 계약.
   - 적용 경계: `FirestoreWeeklyRaidClaimRepository._loadConflictContext`의 pending 신청별 `recruitmentRef.get()`만 좁게 처리했다. 조회 쿼리·Character/주차 필터와 `createManualClaim` Transaction의 정상 대상 쓰기 집합은 그대로 두고, 사전 영향 확인(`inspectManualClaimImpact`)과 실제 체크(`createManualClaim`)가 같은 분류 함수를 계속 사용한다.
   - 검증 경계: 접근 불가 부모의 예외가 **그 신청 하나만** 제외되고 `unavailable` 등 다른 예외는 기존 실패로 남는 것을 신규 테스트로 고정했다. 읽을 수 있는 동일 레이드 신청의 안내·취소는 실기기에서 확인했다. Claim 이후 승인은 기존 Rules의 `hasWeeklyRaidClaimAfter` 계약이 최종 거부한다. 새 `raidState` 점유와 완료 표시의 통합은 B2로 분리한다.
3. **F6-B2 — 주간 상태/체크 표시 통합: B2-A 중간 상태 회귀 확인, 완료 UX 복구 우선.** 수동 `weeklyRaidClaims`와 파티 `raidState`가 생성·신청 후보, 수동 체크/해제, 완료방 해산 후 내 계정 표시에서 일관되게 해석되도록 계약을 설계한다. 기존 활성 참가 시 탈퇴·승계·pending 신청 안내, `source: manual/party`, 다른 난이도의 같은 `raidId`, 수요일 06시를 보존한다. 파티 전체 완료 취소는 제거하고 새 파티 명령에 구 Claim 복제 쓰기를 추가하지 않는다. **내 계정 수동 체크의 참가 중 영향 확인·탈퇴와 모집 상세의 파티 전체 완료는 서로 다른 명령**이지만, 사용자에게 제공하는 완료 사이클은 아래 F6-B2-R의 하나의 인수 단위로 검증한다.
   - 참고: [`WEEKLY_RAID_CLAIM_CONTRACT.md`](../architecture/WEEKLY_RAID_CLAIM_CONTRACT.md) §3.2·§5.3·§5.4·§6·§11·§12, [`FIRESTORE_PARTY_COMMAND_CONTRACT.md`](../architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md), [`BUG_REPORTS.md`](BUG_REPORTS.md) 완료방 해산 체크 누락 기록.
   - 확인된 실제 간극: 운영 Router의 파티 완료는 `PartyAtomicCycleCommandAdapter → FirestorePartyAtomicCommandRepository`로 연결되어 최대 8명의 `raidState`를 `active → completed`로 바꾼다. 반면 내 계정 표시·수동 체크는 `FirestoreWeeklyRaidClaimRepository`의 구 `weeklyRaidClaims/activeRaidAssignments`만 사용한다. 따라서 완료방 해산 후 체크 누락과 활성 `raidState`가 있어도 수동 체크 가능한 현상은 같은 전환 미완료에서 발생한다. 구 `FirestorePartyCycleCommandRepository`의 Claim 쓰기를 운영 기준으로 되살리지 않는다.

   **B2-A — 현재 주차 읽기 Projection**

   1. 본인 `raidStates`를 읽는 Repository/Mapper를 만들고 내 계정·모집 후보가 동일한 **주간 상태 Projection**을 사용하게 한다. active state를 완료 전용 `WeeklyRaidClaim`으로 변환하지 않고 `none/active/completed/legacyActive/legacyCompleted/inconsistent`를 명시한다. Rules는 현재 Player의 자기 하위 list만 열고 타인 list를 계속 거절한다. 현재 주차 제한은 Repository 쿼리와 Projection의 `cycleKey` 검증으로 강제한다.
   2. `completed state → 완료`, `active state → 참가 중`, state 없음 + 구 Claim → 호환 완료, state 없음 + 구 assignment → 호환 참가 순으로 합친다. 현재 주차 state와 legacy 문서가 동시에 있으면 내용이 같아 보여도 `inconsistent`로 반환한다. 한쪽 해제 뒤 다른 기록이 다시 체크·점유로 나타나는 회귀를 막기 위해 자동 병합·부분 삭제하지 않는다.
   3. 문서 ID에 주차가 없으므로 모든 판정에서 state의 `cycleKey`를 검증한다. 완료방 해산이 현재 주차 completed state를 보존한 뒤 내 계정 체크가 유지되고, 이전 주차 state는 현재 체크·참가 제한에 영향을 주지 않는 것을 고정한다.
   4. Projection은 저장 원장 해석만 공유한다. 모집 생성·신청 후보의 active 상태는 기존 `FirestoreActiveRaidAssignmentLookup`/`PartyCreateOccupancyGate`가 수행하는 연결 모집 종료·만료·고아 판정을 보존하고, 내 계정은 탈퇴·승계·단독 해산 영향 계산을 별도로 유지한다. 공통 타입 도입을 이유로 두 UX의 정책을 하나의 boolean으로 축약하지 않는다.
   5. 구현은 `Projection 타입·순수 병합 테스트 → 본인 list Rules 계약 → Repository 읽기 → 내 계정 표시 연결 → 모집 후보 연결 및 기존 점유 게이트 회귀` 순서로 나눠 각 단계 diff를 검토한다.

   **B2-A 구현 상태 정정(2026-09-19):** 읽기 Projection·Rules·Router 연결과 자동 검증은 완료했지만, 대응 쓰기 명령 없이 `raidState` 체크박스를 읽기 전용으로 노출한 것은 기존 해제 UX를 깨뜨린 회귀다. 사용자의 운영 게시·실기기 확인에서 이 문제가 드러났으므로 B2-A를 독립 완료 또는 게시 가능한 단계로 취급하지 않는다. 기존 `canToggle` 차단 테스트는 제품 계약이 아니라 제거·대체해야 할 회귀 근거다.

   **F6-B2-R — 완료 UX 복구: 현재 최우선 작업 구간**

   하나의 사용자 흐름은 `파티 전체 완료 → 완료 기록 → 완료방 해산 → 내 계정 체크 유지 → 본인 체크 해제 → 동일 레이드 재참가 가능`이다. 내부 코드는 아래처럼 나누되 전체 흐름이 통과하기 전에는 어느 중간 구간도 운영 완료로 판정하지 않는다.

   1. **R1 전체 완료 권한 경계:** 현재 앱 Repository가 `complete/advanceCycle`에서 모든 대상의 private `raidState`를 직접 읽는 구조를 제거한다. 당시 함께 수정된 `cancelCompletion` 경로는 제품 폐기 대상이며 R1의 완료·주차 전환 개선은 그대로 유지한다. 모집 Aggregate의 고정 대상과 Rules의 각 update·`getAfter` 검증으로 1·2·4·8인의 상태가 전부 반영되거나 전부 거절되게 한다. 해산에서 이미 적용한 타인 private read 제거 원칙을 완료 명령에도 맞추되, 대상 누락·추가·stale revision·비공대장은 계속 거절한다. 각 state 쓰기마다 전체 대상을 다시 검사하는 `8×8` Rules 평가나 인원수 비례 이벤트 복제는 도입하지 않는다.
      - **로컬 구현 완료(2026-09-19):** 원자 lifecycle Repository에서 대상 `raidState`의 `transaction.get()`과 클라이언트 문서 사전 판정을 제거했다. 인증 binding·모집 Aggregate·필요 시 그룹 원본만 읽으며, 모집 대상 일치와 각 state 전이는 기존 Write Plan·Rules가 검증한다. Repository·Write Plan·lifecycle Rules·확장성 계약 표적 테스트 25건과 변경 파일 분석이 통과했다. Rules·이벤트 형식·운영 Firebase는 변경하지 않았다. 실제 인증 클라이언트의 공개·그룹 1·2·4·8인 실행은 R4 완료 게이트로 남긴다.
   2. **R2 공용 완료 이벤트와 기록:** Player별 이벤트 fan-out은 되살리지 않는다. 공용 이벤트 한 건에 공통 `raidId/difficultyId/cycleKey`와 최대 8명의 `playerId/characterId` 완료 대상 Snapshot을 넣고, 수신자는 자기 대상을 선택해 완료 기록을 생성한다. Rules allowlist·대상 일치·최대 8명·이벤트 재전송 거절을 검증한다. 필드 누락을 조용히 성공 처리하는 기존 sync 테스트를 완료 기록 생성/누락 거절 테스트로 보강한다.
      - **완료(2026-09-19):** lifecycle 이벤트 schemaVersion 2의 완료 이벤트에 공통 레이드 정보와 `completionTargets`를 기록한다. 당시 구현한 완료 취소 이벤트 생성 분기는 제거 대상이며 과거 이벤트 읽기만 유지한다. Rules는 모집 `partySlots`와 audience·대상 배열을 최대 8개까지 같은 순서로 검증하고 문서 추가 조회는 하지 않는다. 기존 schemaVersion 1은 구 앱 호환 create만 유지한다. Event Mapper가 현재 Player의 Character를 선택하고 sync가 그 값을 Drift 완료 기록에 사용한다. 관련 Flutter 표적 63건, 변경 파일 분석, JS 문법과 diff 검사가 통과했다. 로컬 demo Emulator는 기존과 같은 Rules 로딩 503으로 중단됐지만 작업 브랜치 GitHub Actions `35417265039`에서 1·2·4·8인 lifecycle, 완료 대상 누락·Character 위조 거절을 포함한 격리 Rules 검증이 통과했다. 운영 Rules는 게시하지 않았고 실제 앱 전체 사이클은 R4에 남긴다.
   3. **R3 완료 조작 UX 복구:** 먼저 모집 상세의 `전체 완료 취소` 버튼과 신규 호출 경로를 제거하고, Domain/Adapter/Write Plan/Rules의 `cancelCompletion` 허용 분기를 폐쇄한다. 과거 `completionCancelled` 이벤트·Drift 기록의 읽기 Mapper는 호환용으로 유지한다. 이어서 `active`는 미체크와 오른쪽 참가 안내 아이콘을 함께 표시하고 체크박스 선택은 영향 확인 후 B2-C 개인 완료 명령으로 연결한다. `completed`는 체크와 완료 안내 아이콘을 함께 표시하고 본인이 해제할 수 있게 B2-B/D 자기 state 삭제 명령으로 연결한다. 안내 아이콘은 조작을 설명할 뿐 체크박스를 비활성화하는 조건이 아니다. `inconsistent`도 일괄 차단하지 않는다. 본인·Character·raidId·현재 cycle이 검증된 완료 근거가 있으면 체크 표시와 해제 경로를 제공하고, 완료 근거만 제한적으로 정리하며 active 참가 근거는 보존한다. 소유권이나 식별자가 검증되지 않는 손상 데이터만 임의 변경 없이 구체적인 복구 안내로 보낸다.

      **R3 과거 중단·재개 이력(2026-09-19, 현재 완료)**

      - 브랜치는 `feature/party-group-command-redesign`, 최신 커밋은 `b5769bf fix: bound personal completion rule evaluation`이다. 로컬·`origin/feature/party-group-command-redesign`은 같은 커밋이고 작업 트리는 깨끗하다. R3 변경은 `dev/main`에 반영되지 않았으며 운영 Rules도 게시하지 않았다.
      - R3 복구 구현은 `dfe0440`, 개인 완료 Rules 우선순위 조정은 `e660c4c`, 개인 완료 명령 표식과 마지막 1인 전용 Rules 경량화는 `b5769bf`에 각각 추적·푸시됐다. 과거 미커밋 초안을 다시 찾거나 되살리지 말고 이 커밋부터 이어간다.
      - `b5769bf`는 기존 Aggregate의 `lastCommand*`에 `personalComplete` 명령 표식을 기록한다. 마지막 1인 모집 갱신과 membership 삭제는 이 표식을 사용하는 전용 검증 경로로 분리했으며 새 문서, Player별 이벤트 fan-out, 타인 private state 선읽기는 추가하지 않았다.
      - GitHub Actions `35443055507`에서 Rules 컴파일, 개인 수동 완료·해제, 개인 해제로 빠진 반복방 state의 다음 주차 재생성, 공개방 마지막 1인 완료·해산, 그룹방 마지막 1인 완료·listing/활성 수 정리까지 통과했다.
      - `b5769bf` CI는 다인방 검증 준비 중 가입자의 `applicationTxn(..., 'apply')`에서 application create·recruitment update·party event create가 함께 평가되며 `maximum of 1000 expressions`에 도달했다. 원인은 모든 모집 update가 무거운 개인 완료 상세 검증을 먼저 평가한 것이며, 단순 OR 순서 변경으로 해결하지 않았다.
      - 후속 커밋 `4abdb89 fix: gate personal completion rule evaluation`에서 `lastCommandType == personalComplete`, actor와 단일 target을 확인하는 값싼 `personalCompletionCommandMarker`를 모집 update의 선행 게이트로 추가했다. 표식이 맞을 때만 개인 완료 상세 검증을 호출하며 정상 신청·승인·가입·자리 변경·추방·해산의 기존 검증은 완화하지 않았다.
      - GitHub Actions `35448981992`가 전체 통과했다. Rules 컴파일, 정상 신청·철회·재신청·승인, 일반 멤버 개인 완료, 파티장 개인 완료 후 승계, 위조 후임 Snapshot 거절, 마지막 1인·그룹 마지막 1인 완료, 자리 변경·추방·재가입, 2·4·8인 해산, 그룹 생성·가입·승계·탈퇴·해산 회귀를 확인했다.
      - 당시 R3 코드·Rules 자동 검증은 완료했고 SHA-256 `11593015457B155BCE11FEC2D185DEB039D49F62F1C10C70DFEC24012EDA5857`의 추적 Rules 게시 시도는 원격 컴파일 `/test`의 HTTP 503으로 실패했다. 이후 사용자가 Rules를 별도로 게시하고 정상 데이터의 R4 실기기 흐름을 확인했으므로 이 항목은 현재 재개 지시가 아니라 장애 이력이다.

      **R3 재개 순서**

      1. 현재 미커밋 diff와 신규 파일을 보존한 채 R3 계약별 변경표를 다시 만들고, 위 확정 승계 Rules 결함을 먼저 수정한다.
      2. B2-B/C/D의 Write Plan·Repository·Router/DI·Projection·Rules가 같은 식별자와 원자 경계를 쓰는지 대조한다. 반복방 다음 주차와 legacy/불일치 경계가 초안에 실제 구현됐는지도 코드 근거로 판정하고 누락만 보완한다.
      3. 코드 포맷, JS 문법, `git diff --check` 후 개인 수동 체크/해제, 일반 멤버·파티장·마지막 1인 완료, 그룹 전용방, 완료 취소 미노출·서버 거절의 표적 Flutter/Rules 계약 테스트를 실행한다.
      4. 변경 범위가 Router·공용 Domain·Rules에 걸치므로 변경 파일 분석과 전체 `flutter analyze`, 전체 `flutter test`를 최종 상태에서 한 번 실행한다. 실패는 이번 변경 회귀와 기존 결함을 근거로 분리해 기록한다.
      5. 로컬 Emulator 503이 계속되면 같은 실패를 반복하지 않고, 검증 가능한 커밋을 작업 브랜치에 남긴 뒤 기존 demo Rules CI로 1·2·4·8인 및 거부 사례를 확인한다. CI 전이나 실패 상태에서는 운영 Rules를 게시하지 않는다.
      6. 자동 검증과 문서 기록이 끝난 후에만 R3 코드·Rules·테스트를 한 검증 단위로 커밋·작업 브랜치 푸시한다. 사용자는 그 뒤 R4 체크리스트로 실기기를 수동 확인한다. 실기기 설치·조작은 에이전트가 수행하지 않는다.

      **R3 구현 상태(2026-09-20): 코드·Rules·정상 데이터 실기기 검증 완료.** 파티장 개인 완료의 후임 membership·리더 Snapshot 검증을 보완했다. 파티 밖 수동 `raidState` 완료·해제, 활성 참가자의 탈퇴/승계/마지막 1인 해산과 완료 원자 전환, 그룹 listing·활성 수 정리, 완료 기반 생성·신청·승인 차단을 같은 계약으로 연결했다. 개인 완료 이벤트는 일반 탈퇴와 구분하도록 `reason=weeklyRaidCompleted`를 기록하되 공용 이벤트 한 건 원칙을 유지한다. 반복방은 개인이 이전 완료 state를 지웠더라도 현재 `partySlots`를 근거로 다음 주차 active state를 upsert하며, 현재 시간은 새 주차 시작 이상·종료 미만이어야 한다. 새 주차 수동 완료나 다른 모집 state는 Rules가 덮어쓰기를 거절한다. 삭제된 모집을 참조하는 기존 고아 state는 R3 정상 흐름이 아니라 F6-D 복구 대상으로 분리한다.

      파티 전체 완료 취소의 신규 UI·Domain·Adapter·Write Plan·Rules 실행 경로는 제거했고 과거 이벤트 읽기만 유지했다. 개인 완료·해제 및 lifecycle 표적 Flutter/정적 Rules 계약은 통과했으며 핵심 변경 13개 파일 분석은 0건이다. 전체 분석은 기존 파일을 포함한 50건, 전체 테스트는 계약 테스트 갱신 전 실행 기준 1,183건 통과·13건 실패였다. 이번 작업의 낡은 legacy assignment 문자열 기대는 현재 제한적 자기 정리 계약으로 갱신해 단독 통과했으며, 기존 활동 Character Rules 문자열·Firebase 기본 앱 미초기화 위젯 등 기준선 실패를 전체 성공으로 숨기지 않는다. 로컬 Emulator는 Android Studio JBR 21로 기동했으나 Rules 로딩 단계의 기존 HTTP 503으로 실행되지 않았다. demo CI `35448981992`에서 추적 Rules 전체 회귀가 통과했지만 운영 게시와 실기기 수동 검증 전에는 B2 전체 완료로 판정하지 않는다.

   4. **R4 한 사이클 검증: 정상 데이터 흐름 완료, 고아 상태는 F6-D로 분리.** 현재 자동 검증에서 확인한 정상 흐름을 인원수별로 다시 반복하지 않는다. Rules 접근·표현식 예산의 인원 확장 검증은 최대치 8인 대표 사례 하나를 기준으로 하고, 마지막 1인 해산·책임자 승계·권한/위조 거절처럼 상태 전이가 다른 최소 사례만 별도로 유지한다. 사용자는 디바이스 2기로 `완료 → 완료방 해산 → 내 계정 체크 유지 → 본인 체크 해제 → 재참가 가능`과 개인 완료·승계 대표 흐름을 수동 확인했다. 반복방은 공동 완료 취소 없이 다음 주차에 현재 membership으로 새 active 상태를 구성해야 한다. 다만 삭제된 모집을 참조하는 기존 `active raidState` 한 건은 참가 표시·수동 완료·신청 승인 불일치를 일으켰으며 정상 R4 회귀가 아니라 F6-D 고아 복구 대상으로 확정했다.

   **회귀 보호:** 기존 1인 완료, 자리 이동·교환, 추방·재가입, 활성 해산, 그룹 전용 listing/활성 수, 정상 신청 승인, B1 pending 신청 처리와 수요일 06시 주차 경계를 보존한다. Rules가 바뀌면 전체 추적 Rules CI·경고 확인 후 별도 게시 절차를 따르며, 실기기 설치·조작은 사용자가 수행한다.

   **B2-B — 파티 밖 수동 체크·해제**

   1. 신규 수동 완료는 구 Claim 대신 `source: manual`, `status: completed`, `recruitmentId: null`, `revision: 1`인 raidState를 생성한다. 같은 주차 수동 state 체크는 멱등이며 다른 난이도도 같은 `raidId` 키를 공유한다. legacy active assignment가 남아 있으면 이를 덮어쓰지 않고 불일치로 거절한다.
   2. 자기 completed state는 출처와 관계없이 개인 체크 해제할 수 있고, state가 없고 구 Claim만 있으면 기존 Claim 해제를 호환 경로로 유지한다. completed state와 구 Claim이 함께 있으면 한 번의 해제 명령으로 검증된 본인·현재 주차 완료 근거를 함께 제거한다. active state/assignment가 완료 근거와 함께 있으면 완료 근거만 제거하고 참가 근거는 보존한다. 소유권·Character·raidId·cycleKey가 맞지 않는 문서는 임의 삭제하지 않는다.
   3. completed state를 먼저 원자 확정해 이후 승인·즉시 가입·생성·캐릭터 변경을 서버에서 거절한다. 같은 레이드 pending 수는 무제한일 수 있으므로 전부를 핵심 Transaction에 넣지 않고, UI Projection에서 즉시 무효 처리한 뒤 비핵심 정리 경로로 `superseded/weeklyRaidCompleted`를 반영한다. application Rules의 구 Claim 전용 조건을 통합 state 기준으로 정렬하되 신청자 개인 state를 파티장에게 노출하지 않는다.

   **B2-C — 활성 참가 중 개인 완료**

   1. 내 계정에서만 영향 확인 후 `탈퇴하고 완료 처리`를 실행한다. 일반 멤버는 Aggregate/membership/목표 slot 제거와 본인 state 완료 전환, 파티장은 후임 승계, 마지막 1인은 모집 해산과 state 완료 보존을 한 Transaction에서 처리한다. 이때 state는 `source: manual`로 바꾸고 기존 `recruitmentId`를 원인 추적·Rules 검증용으로 보존하며 revision을 증가시킨다.
   2. 기존 `PartyAtomicMemberRemovalWritePlan`의 인원·역할·slot·그룹 listing·승계 계산을 공통 정책으로 재사용하되, 일반 탈퇴의 state 삭제를 그대로 호출한 뒤 별도 완료 쓰기를 덧붙이지 않는다. 개인 완료 전용 Write Plan/Rules 분기로 원자성을 증명한다.
   3. 모집 상세의 `파티 전체 완료`는 기존 lifecycle 명령을 그대로 사용한다. 활성 참가를 발견했다는 이유로 이 명령을 차단하거나 수동 완료 안내를 띄우지 않는다.

   **B2-D — 해제·반복방·호환 경계**

   1. `source: manual/party` 모두 개인 체크 해제는 자기 completed state만 삭제하고 공동 완료 Snapshot은 바꾸지 않는다. 파티 전체 완료 취소 명령·버튼·Rules 허용은 제거하고 과거 `completionCancelled` 이벤트 읽기만 유지한다.
   2. 반복방의 다음 주차 전환은 개인 해제로 이전 state가 없어도 현재 membership을 기준으로 새 주차 active state를 생성할 수 있게 Write Plan과 Rules를 확장한다. 기존 문서는 같은 반복방의 직전 주차 state일 때만 갱신하며, 새 주차 수동 완료나 다른 모집의 active state는 덮어쓰지 않고 명령 전체를 거절한다. 그렇지 않으면 개인 해제가 방을 영구 정지시키거나 반대로 실제 완료·참가를 소실시키므로 완료 조건으로 인정하지 않는다.
   3. 과거 Claim·assignment는 bulk migration 없이 fallback 읽기·해제만 유지한다. 신규 명령이 legacy 원장과 state를 dual-write하지 않는다. 불일치는 진단 상태로 유지하되, 본인 소유와 현재 주차 식별이 증명되는 완료 근거는 체크박스 한 번으로 제한적으로 수렴시킨다. 증명할 수 없는 손상 데이터만 별도 안전 복구 백로그로 보낸다.

   **회귀·완료 기준**

   - 자동: 실기기로 안전하게 확인하기 어려운 Rules 권한·위조 요청·원자성·주차 경계와 최대 8인 표현식 예산만 검증한다. 인원수별 동일 흐름은 8인 대표 사례로 통합하고, 마지막 1인·책임자 승계처럼 상태 전이가 다른 경우만 최소 사례로 둔다. 정상 UI·UX와 pending 0·1·다수 같은 반복 조합은 디바이스 결과와 코드 검토로 확인하며 자동 테스트를 관성적으로 늘리지 않는다.
   - 보존: 기존 방 생성·신청·승인·즉시 가입·캐릭터 변경의 완료 차단, 자리 변경·추방·활성 해산, 그룹 listing/집계, B1의 접근 불가 신청 처리와 정상 pending 취소를 보호한다.
   - 실기기: 사용자가 수동 체크/해제, 참가 중 영향 안내와 탈퇴·승계/단독 해산, 파티 전체 완료 후 체크 유지, 완료 취소 미노출, 반복방 다음 주차 대표 흐름을 확인한다. 에이전트는 설치·조작하지 않는다.
   - Rules가 변경되므로 전체 B2 자동 검증과 경고 확인 전에는 운영 게시하지 않는다. 운영 게시·실기기 확인 전 B2 완료나 `dev/main` 통합으로 표시하지 않는다.

   **페이지·역할별 UX 회귀 보호**

   | 사용자 위치 | 보존할 정상 흐름 | 새 구조에서 막아야 할 회귀 |
   | --- | --- | --- |
   | 내 계정 / 일반 사용자 | 미참가 Character 수동 체크·해제, 완료 시 체크 유지, 완료·해제 후 같은 레이드 흐름 반복 | active 참가를 무시한 중복 완료, 소유권 미확인 legacy 자동 삭제, 과거 cycle 표시, 불일치 분류만으로 개인 해제 차단 |
   | 내 계정 / 참가자 | 영향 안내 확인 후 탈퇴와 개인 완료, 파티장이면 승계, 마지막 1인이면 해산 | 일반 탈퇴로 state를 먼저 삭제한 뒤 완료가 따로 실패하는 부분 저장 |
   | 모집 상세 / 공대장 | 전원 파티 완료, 완료방 해산, 반복방 다음 주차 유지 | 개인 수동 완료의 active 차단을 전원 완료에 적용, 폐기된 완료 취소 버튼·명령 잔존 |
   | 반복방 / 공대장·파티원 | 새 주차 진입 시 완료 체크 초기화와 현재 멤버 active 재구성 | 개인 해제로 state가 빠진 멤버 때문에 전환 전체 실패 |
   | 모집 생성·신청 / 일반 사용자 | completed 비활성, active 참가 안내, pending 복수 신청 | 오래된 pending 정리 수에 비례한 핵심 Transaction, 상태 충돌을 일반 권한 오류로만 표시 |
   | 승인 / 공대장 | 정상 신청 승인, 이미 참가·완료된 신청은 서버 최종 거절 | 타인 private state 조회 허용, 모든 권한 오류를 신청자 문제로 단정, 자동 거절. 전용 게이트를 충족하면 `신청자의 참가 데이터에 오류가 있어 승인할 수 없습니다. 해당 신청을 거절해 주세요.`와 명시적 거절 선택을 제공 |

   B2 구현 중 위 표의 다른 페이지를 편의상 같은 ViewModel 조건으로 묶지 않는다. 특히 내 계정 개인 명령과 모집 상세 공동 명령, 표시 Projection과 서버 최종 권한 검증은 각각 독립 테스트를 둔다.

   **구현 순서:** B2-A Projection 타입·읽기·본인 list Rules → R1 다인 완료 권한 경계 → R2 공용 완료 이벤트 → R3 체크박스 개인 완료·해제 명령 → R4 실제 앱 전체 사이클 검증. B2-A·R1·R2·R3와 정상 데이터 R4를 완료했다. 삭제된 모집을 참조하는 과거 고아 state는 B2 정상 완료 사이클과 구분해 F6-D에서 복구한다.
4. **F6-C — 모집 생성 초기 선택 교착 해소: 완료.** 첫 진입에서 레이드를 자동 선택하지 않고 대표 캐릭터를 탐색 기준으로 둔다. 레이드·난이도 미선택 저장은 차단하되, 기본 4막이 불가능해도 다른 레이드와 Character 변경에 접근 가능해야 한다. null 레이드의 Form/draft/자동 제목·역할 변경/재진입, 단일·다중 Character와 기존 정상 생성을 자동·실기기로 검증한다. 점유·완료·레벨·역할 및 서버 최종 거절은 완화하지 않는다.
   - **착수 전 실제 코드 확인(2026-09-20):** `RecruitmentCreatePage._load`는 첫 active raid/difficulty를 읽은 뒤 대표 Character의 eligible 목록에서 같은 raid 또는 첫 항목을 다시 선택하고, `_raid/_difficulty`와 draft를 즉시 채운다. `RecruitmentForm`도 non-null `selectedRaid/selectedDifficulty`를 요구한다. 따라서 F6-C는 아직 구현되지 않았으며 단순 기본값 제거만으로 끝나지 않는다. Form의 미선택 표현, raid 선택 전 후보·역할 변경, 저장 검증과 자동 제목을 함께 null-safe하게 설계해야 한다.
   - **변경 경계:** 후보의 점유·완료·아이템 레벨·역할 판정과 생성 Repository/Rules는 바꾸지 않는다. 화면 초기 선택과 Form 상태만 수정하고, 사용자가 레이드를 선택한 뒤에는 기존 후보 재조회·난이도 선택·제목 생성·저장 명령을 재사용한다.
   - **최소 완료 기준:** 기본 대표 Character가 첫 레이드를 생성/완료해도 화면 진입 직후 Character와 레이드 선택 UI가 모두 조작 가능해야 한다. 레이드 미선택 저장은 구체적으로 차단하고, 생성 가능한 다른 레이드 선택 또는 다른 Character 변경 후 정상 생성 가능해야 한다. 사용자가 이 UX를 실기기로 확인하며 동일 정상 UI 자동 반복은 하지 않는다.
   - **구현 결과(2026-09-20):** Form의 레이드·난이도를 nullable 미선택 상태로 열고 대표 Character 후보는 특정 레이드 점유·완료 조건을 적용하지 않은 탐색용 조회로 구성한다. 레이드 선택 시에만 기존 후보 재조회와 제한 판정을 실행하고 자동 제목을 생성한다. 미선택 저장 안내, 선택 전 Character 접근, 선택 후 동일 레이드 차단과 기존 생성 저장을 포함한 Widget 19건 및 변경 파일 분석이 통과했다. Repository·Rules·점유/완료 정책은 변경하지 않았다.
   - **실기기 완료 근거(2026-09-21):** 사용자가 첫 진입의 선택 부분이 정상 작동함을 확인하고 기능 완료를 승인했다. 동일 정상 UI 자동 검증은 반복하지 않는다.
   - 참고: [`RAID_CATALOG_DATA.md`](../product/RAID_CATALOG_DATA.md), [`PARTY_PARTICIPATION_RULES.md`](../product/PARTY_PARTICIPATION_RULES.md), [`BUG_REPORTS.md`](BUG_REPORTS.md) 기본 4막 교착 기록.
5. **F6-D — 고아 참가 복구와 신청/승인 경계 보완: 다음 구현 구간.** 기존 `active raidState`가 있어도 신청은 pending으로 접수되고 승인에서 Rules update 거부가 모호한 권한 팝업이 되는 흐름을 아래 순서로 분리한다. 정상 참가·완료 경로와 고아 데이터 정리를 한 조건문으로 합치지 않는다.
   1. **D1 단건 판정:** 내 계정에서 active 상태를 조작할 때 본인 state의 식별자·현재 주차·revision을 검증하고 연결 모집을 단건 조회한다. 모집이 없거나 `PartyCreateOccupancyGate`의 stale 상태이면 `orphanActive`로 반환한다. 실제 활성 모집·멤버면 기존 탈퇴/승계/마지막 1인 해산 후 완료 흐름을 유지한다.
   2. **D2 사용자 복구:** `orphanActive`에는 존재하지 않는 새로고침을 안내하지 않고 `종료되거나 삭제된 파티의 참가 기록이 남아 있습니다.`와 `참가 기록 정리`를 제공한다. 명시적 확인 뒤 본인의 orphan `raidState`만 삭제하며, 같은 키의 legacy assignment가 있으면 동일 식별자·cycle·recruitmentId가 검증될 때만 함께 원자 삭제한다. 완료 state·Claim·다른 레이드·Character·신청은 변경하지 않는다. 정리 후 실시간 Projection이 `none`이 되면 사용자가 수동 완료 여부를 다시 선택한다.
   3. **D3 Rules 경계:** 현재 Rules의 `validAtomicStaleRaidStateDelete`가 모집 원본 부재와 종료·완료·만료 상태에 한해 본인 active party state 삭제를 허용하는 계약을 재사용한다. legacy assignment 동시 삭제가 필요할 때만 같은 고아 조건의 좁은 delete OR를 추가한다. 활성 모집, 타 Player, 식별자·recruitmentId 위조, completed state 삭제는 이 명령으로 거절한다. 목록 N+1 조회·서버 후처리·Player별 이벤트 fan-out은 추가하지 않는다.
   4. **D4 이전 주차 고아 확장:** `inspectManualClaimImpact`의 cycle 불일치 즉시 실패를 base identity 검증과 수명 판정으로 분리한다. 이전 주차 active + 모집 없음/종료/완료/만료 비반복방은 `historicalOrphanActive`로 반환하되 현재 Projection의 느낌표는 만들지 않는다. 정리 명령에는 현재 주차가 아니라 관찰한 state cycleKey·revision·recruitmentId를 전달한다. 이 exact-state 분류를 완료 체크뿐 아니라 같은 고정 경로를 쓰는 모집 생성·신청·즉시 가입의 공통 판정으로 재사용한다. 정상 활성 반복방은 승계/참가 충돌로 유지하고, 이전 주차 completed는 고아 정리와 분리된 정상 rollover 경로로 보존한다.
   5. **D5 신청자 사전 차단:** 후보 목록의 현재 주차 표시를 N+1 부모 조회로 확장하지 않는다. 신청·재신청·즉시 가입 Transaction이 본인 exact `raidState`를 읽고 `PartyCreateOccupancyGate`와 같은 수명 판정을 사용한다. 정상 active는 `동일 레이드 참가 중`, 현재/이전 주차 active 고아는 `참가 기록 정리 필요`, 현재 completed는 `이번 주 완료`로 저장 전에 반환한다. 고아는 자동 삭제·자동 재신청하지 않는다. 이전 주차 completed만 정상 rollover 정책으로 안전하게 제거/교체한 뒤 진행하며 active 고아와 같은 분기로 합치지 않는다. Rules의 application create/reapply에도 최종 `raidState` 부재 조건을 추가해 앱 선검사 뒤 경쟁을 차단한다.
   6. **D6 승인자 안내와 명시적 거절:** 승인자는 타인의 private `raidState`를 읽거나 정리하지 않는다. 과거 pending 또는 신청 뒤 상태 변경으로 승인 Rules가 거절되고, 화면상 pending·승인 권한·revision 전제가 유지되는 경우 `신청자의 참가 데이터에 오류가 있어 승인할 수 없습니다. 해당 신청을 거절해 주세요.` 대화상자와 `닫기`/`신청 거절`을 제공한다. `신청 거절`은 기존 bounded reject Transaction만 재사용하며 자동 거절은 금지한다. 일반 인증·Rules 게시본 불일치 가능성이 있는 모든 permission 오류를 데이터 오류로 확정하지 않도록 적용 조건을 승인 경로의 보존된 전제로 제한한다.
      - **전용 안내 게이트:** 승인 명령 자체가 `permissionDenied`로 끝났고, 실패 직후 모집과 신청 목록이 모두 서버 Snapshot이며 같은 `recruitmentId`·모집 revision을 유지하고 대상 신청도 같은 application revision의 `pending`이고 현재 사용자의 승인 가능 상태가 유지될 때만 전용 대화상자를 연다. 신청 목록 Snapshot의 캐시 여부를 화면 상태에 보존해 오프라인 캐시를 최신 pending으로 오인하지 않는다. 하나라도 달라졌으면 상태 변경 또는 기존 일반 실패 안내로 끝내고 거절 동작을 제안하지 않는다.
      - **명시적 거절:** `닫기`는 아무 데이터도 바꾸지 않는다. `신청 거절`은 대화상자에 사용한 동일 모집·신청 revision으로 기존 `reject` 명령을 한 번 호출한다. 그 사이 상태가 바뀌면 기존 `revisionConflict`·`applicationNotPending`·권한 실패를 그대로 표시하고 신청을 임의 변경하지 않는다.
      - **변경 경계:** `PartyJoinFailure`와 승인·거절 Repository, Firestore Rules, applicant private state 읽기, 신청 데이터 스키마는 변경하지 않는다. 상세 화면에 신청 목록 Snapshot의 캐시 여부를 보존하고 승인 실패 분기와 대화상자를 연결하는 범위만 수정한다. 즉시 가입의 `permissionDenied`, 정상 승인·일반 거절·네트워크 실패는 기존 문구와 흐름을 유지한다.
      - **회귀 보호:** 정상 승인 성공, 기존 거절 성공, 전용 안내에서 닫기, 전용 안내에서 거절 성공, 대화상자 이후 revision 변경으로 거절 실패, 게이트를 충족하지 않는 일반 `permissionDenied`를 구분한다. 동일 UI를 실기기와 자동으로 반복하지 않고 위 분기만 표적 Widget 테스트로 검증한 뒤 사용자가 과거 pending 대표 1건을 수동 확인한다.
   7. **D7 최소 검증:** Rules는 모집 원본 없음인 본인 orphan state 정리 성공, 활성 모집·타인·위조·completed 거절, legacy assignment 동시 정리와 raidState 잔존 신청 거절만 자동 검증한다. 실기기는 현재 주차 고아 1건, 이전 주차 고아 1건, 정상 active/반복방 대표 1건만 확인한다. 신청자에서는 `신청 차단 → 정리 → 재신청`, 방장에서는 과거 pending 승인 실패 안내 → 명시적 거절을 확인한다. 이전 주차 completed는 오류 안내 없이 현재 주차 완료·생성·신청이 가능해야 한다. 기존 방 생성·신청·승인·즉시 가입·자리 변경·추방·해산·완료/해제 및 그룹 흐름을 회귀 보호한다.

   **D1~D3 구현 상태(2026-09-20): 코드·자동 검증 및 현재 주차 단건 복구 실기기 확인 완료.** 내 계정의 수동 완료 영향 확인이 연결 모집 없음 또는 종료·완료·만료 상태를 단건 판정해 `orphanedParticipation`으로 분리하고, 별도 확인창의 `참가 기록 정리` 명령이 관찰한 Player·Character·raid·cycle·recruitmentId·revision을 Transaction에서 다시 검증한다. 성공 시 본인 active party `raidState`와 동일한 구 assignment만 원자 삭제하며 완료 기록·신청·다른 상태는 변경하지 않는다. Rules는 기존 stale state 삭제 계약을 재사용하고 구 assignment에 같은 본인·고아 조건의 delete만 추가했다. 정상 활성 모집과 타인 정리는 거절하는 demo 대표 시나리오를 추가했으며, JS 문법·변경 파일 정적 분석·표적 Flutter 9건과 작업 브랜치 demo Rules Emulator Actions `35454451057`이 통과했다. 사용자가 Rules를 콘솔에서 게시하고 현재 주차 고아의 느낌표·명시적 정리·실제 삭제를 확인했다. 운영 활성 소스 해시는 AI가 독립 대조하지 않았다. 이후 발견된 이전 주차 고아와 신청 최종 차단은 D4·D5에서 구현·검증했다.

   **D4 구현 상태(2026-09-20): 코드·표적 자동 검증 및 이전 주차 고아 실기기 확인 완료.** 고정 `raidState`의 수명 판정을 공용 `PartyCreateOccupancyGate.classifyExistingRaidState`로 분리해 현재/이전 주차 active 고아, 유효 참가 충돌, 현재/이전 주차 completed를 구별한다. 내 계정 완료 사전 확인은 이전 주차 active가 모집 없음·종료·완료·만료 1회성일 때만 현재 느낌표 없이 `지난 주차의 종료된 파티 참가 기록` 정리를 안내하며, 정리 명령에는 관찰한 state cycleKey·revision·recruitmentId를 전달한다. 유효 반복방은 정리하지 않는다. 이전 주차 completed는 고아 정리로 보내지 않고 수동 완료 및 모집 생성에서 기존 completed 문서를 본인 delete 계약으로 정리한 뒤 현재 주차 쓰기를 재시도한다. Rules는 변경하지 않았고 운영 배포도 하지 않았다. 공용 분류·기존 점유·ViewModel 표적 테스트 21건과 변경 파일 분석이 통과했고, 사용자가 과거 고아 완료 데이터 정리가 정상 작동함을 확인했다.

   **D5 착수 설계(2026-09-20): 구현 전 연결점 확인 완료.** 운영 Router는 모집 상세의 신청·재신청을 `FirestorePartyAtomicApplicationCommandRepository`, 즉시 가입을 `FirestorePartyAtomicJoinCommandRepository`에 직접 연결한다. 구 `RecruitmentCommandService`나 레거시 신청 Repository는 수정 대상이 아니다. 다음 구현은 아래 경계만 한 검증 단위로 다룬다.

   1. 신청·재신청과 본인 즉시 가입 Transaction에서 정확한 `characterId + raidId` state를 읽고, active일 때 참조 모집 한 건만 추가 조회해 D4의 공용 수명 판정을 호출한다. 정상 active/유효 반복방은 참가 충돌, current completed는 주간 완료, current·historical orphan active는 정리 필요로 구분한다. 후보 목록 전체의 부모 모집 N+1 조회나 승인자의 타인 state 읽기는 추가하지 않는다.
   2. orphan 결과에는 관찰한 Character·raid·cycle·recruitmentId·revision을 함께 반환한다. 모집 상세는 기존 `WeeklyRaidClaimCommandRepository.cleanupOrphanParticipation`을 주입받아 `참가 기록 정리`를 명시적으로 선택할 수 있게 하며, 성공 후 신청·즉시 가입을 자동 재실행하지 않는다. 현재 주차 후보의 기존 참가/불일치 표시는 완화하지 않고, 현재 목록에 나타나지 않는 이전 주차 고아도 버튼 실행 시 같은 복구 UX로 수렴시킨다.
   3. historical completed는 create와 같은 최대 2회 bounded Transaction으로 기존 completed state만 먼저 삭제하고 모든 조건을 다시 읽어 원래 명령을 실행한다. active orphan 자동 삭제, 자동 신청, 신청 문서 수정은 하지 않는다.
   4. application create/reapply Rules는 최종 상태에서 해당 applicant의 exact `raidState`가 존재하지 않아야 한다. 기존 completed Claim/state 검사와 병행하되 정상 신청·철회·재신청의 현재 조건, 그룹 분류와 표현식 예산을 완화하지 않는다. direct join은 기존 raidState create 계약이 점유 경쟁을 최종 거절하는지 계약 테스트로 고정하고 불필요한 중복 Rules 조회를 추가하지 않는다.
   5. D5 자동 검증은 공용 수명 분기와 Rules의 `state 잔존 신청 거절/정리 후 신청 성공` 대표 사례만 추가한다. 신청·재신청·즉시 가입의 정상 UI는 동일 결과 자동 테스트를 반복하지 않고 구현 종료 뒤 사용자가 디바이스 2기로 `차단 → 명시적 정리 → 다시 신청/가입`을 확인한다. 승인 실패 안내·명시적 거절은 D6 범위로 남긴다.

   **D5 구현 상태(2026-09-20): 코드·Rules·자동 검증 완료, 신청 실기기 확인 완료.** 신청·재신청과 본인 즉시 가입은 exact state와 연결 모집 한 건을 공용 수명 판정으로 분류한다. 정상 active/유효 반복방은 참가 충돌, current completed는 주간 완료, current·historical orphan active는 관찰 식별자를 포함한 정리 필요 결과로 반환한다. 모집 상세는 기존 단건 정리 Repository를 재사용해 사용자가 `참가 기록 정리`를 명시적으로 선택하게 하며 성공 뒤 원래 신청·가입을 자동 재실행하지 않는다. historical completed는 최대 2회 Transaction 중 첫 회에서 기존 state만 삭제하고 두 번째 회에서 모든 조건을 다시 읽어 신청·즉시 가입을 수행한다. application create/reapply Rules는 최종 exact state 부재와 legacy Claim 부재를 함께 요구한다. 승인자의 타인 state 읽기와 D6 안내는 변경하지 않았다. 표적 Rules/수명 판정 13건, 모집 상세 46건, 변경 파일 정적 분석과 JS 문법·diff 검사가 통과했고 demo 전체 Rules Actions `35494192803`도 통과했다. 추적 Rules SHA-256은 `9228699FEB79F2F41AC782B8E4F98FF6AEE1F94248354B954CEF503AB2B65B0C`다. CLI 게시 1회는 원격 컴파일 `/test`의 HTTP 503으로 실패했으나, 이후 사용자가 콘솔에서 Rules를 직접 게시했다고 확인했다. AI가 운영 활성 소스 해시를 독립 대조하지는 않았다. 사용자 실기기에서는 현재 주차 고아의 느낌표·정리와 이전 주차 고아의 신청 시 안내·명시적 정리·실제 state 삭제가 모두 확인됐다. 정리 성공 뒤 신청은 자동 실행되지 않으며 사용자가 다시 신청한다. 본인 즉시 가입의 같은 UX는 아직 별도 실기기 확인 전이다.

   **D6 구현 상태(2026-09-20): 통과.** 승인 `permissionDenied` 뒤에도 모집 상세와 신청 목록이 모두 서버 Snapshot이고, 같은 모집·신청 revision의 pending 및 현재 승인 권한이 유지될 때만 전용 안내를 연다. `닫기`는 쓰지 않고 `신청 거절`은 대화상자에 사용한 revision으로 기존 reject 명령만 호출한다. 신청 목록 캐시 여부를 화면 상태에 보존해 캐시·상태 변경·일반 권한 실패에는 기존 안내를 유지한다. `PartyJoinFailure`, 승인·거절 Repository, Rules, 스키마와 타인 private state 읽기는 변경하지 않았다. 모집 상세 Widget 테스트 49건과 변경 파일 정적 분석이 통과했고 정상 재신청·승인도 실기기에서 확인했다. 정상 흐름은 신청 전에 고아를 정리하므로 전용 대화상자를 실기기에서 재현하려면 pending 생성 뒤 콘솔로 고아를 인위 생성해야 한다. 사용자는 이 조작 테스트를 생략하고 방어 경로 자동 검증을 근거로 D6를 통과 처리했다. 향후 실제 제보에서 승인 실패 뒤 이 전용 안내·명시적 거절이 동작하지 않으면 공대장 측 대응 회귀로 판정한다.

   **과거 재현과 해결(2026-09-20):** 다른 Player의 `players/Grn71r8G1pvCEvLAtpVB/raidStates/hTfsqNxwHm5Oo4GL8zcK_kazeros_act4`는 이전 주차 active state라 현재 Projection의 느낌표에는 나타나지 않았고, 초기 구현에서는 쓰기 경로를 점유했다. D4·D5는 연결 모집의 missing/stale 여부를 Transaction에서 다시 검증한 경우에만 정리를 허용한다. 사용자가 같은 유형의 이전 주차 고아로 신청했을 때 안내와 실제 삭제가 정상 작동함을 확인했으므로 이 재현은 해결 근거로 보존한다.

   **현재 주차 해결 근거:** `players/kVn6KZwZQO6or3BjNYqX/raidStates/xseSyVxZXWhKYxlZEucb_kazeros_act4`가 존재하지 않는 모집 `td904kw3PEgWI1GwIfUP`을 참조해 참가 느낌표와 승인 실패를 일으킨 과거 재현을 D1~D3의 기준 데이터로 사용했다. 구현 후 사용자가 현재 주차 고아의 느낌표와 명시적 정리를 확인했다. 다른 Character·raid의 해산방 pending 신청 두 건은 이 증상의 직접 원인이 아니며 아래 운영 정리 백로그에 남긴다.
   - 참고: [`FIRESTORE_PARTY_COMMAND_CONTRACT.md`](../architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md), [`PARTY_PARTICIPATION_RULES.md`](../product/PARTY_PARTICIPATION_RULES.md), [`BUG_REPORTS.md`](BUG_REPORTS.md) `니티야` 고아 점유 기록.

6. **F6-E — 최소 전투력 신청 제한 실동작: F6-C와 분리된 후속 코드 구간.** 착수 시점에는 `minCombatPower`가 생성 원본·목록·상세·신청 Snapshot에 저장·표시되어도 운영 후보 query와 원자 명령이 일관되게 강제하지 않는 연결 공백이 있었다. 현재 코드 연결은 완료했고 실기기 UX 확인을 대기한다.
   - **판정 주체:** 신청자 본인 클라이언트가 계정 갱신으로 보유한 선택 역할 Build Snapshot의 전투력을 사용한다. 변조 데이터, 서버 권위 전투력 저장과 Rules 기반 위변조 방지는 고려하지 않는다.
   - **신청 UX:** 제한 미달 또는 전투력 정보 없음인 Character/역할은 후보에서 사유와 함께 선택 불가로 표시한다. 신청·재신청 실행 직전 현재 모집 Aggregate의 고정 `minCombatPower`와 제출 Snapshot을 다시 비교하고 application 쓰기 전에 거절한다.
   - **우회 차단:** 신청 문서가 없는 즉시 가입과 참가 Character 변경에도 동일 판정을 적용한다. 공대장 승인 시 신청자의 private 데이터를 새로 읽지 않으며 Rules와 승인 원자 명령에 권위 검증을 추가하지 않는다.
   - **현재 제외:** 실제 앱에 모집 조건 수정 기능이 없으므로 제한 상향·하향 뒤 기존 pending 신청과 파티원 처리 정책은 정하지 않는다. 모집 수정 기능을 구현할 때 별도 계약으로 결정한다. 생성자가 자신의 전투력보다 높은 제한을 입력하는 기존 동작도 이번 작업에서 새로 변경하지 않는다.
   - **변경 예상 위치:** 상세 후보 query/서비스, 신청·재신청 Repository 사전 검증, 즉시 가입 및 Character 변경 사전 검증, 실패 사유·표적 테스트다. Firestore 스키마·Rules·공용 이벤트·인원수 비례 조회는 변경하지 않는다.
   - **회귀 보호:** 제한 없음 모집, 정확히 최소값과 초과 Character, 미달·null 전투력, 신청·재신청·즉시 가입·Character 변경을 구분한다. 기존 아이템 레벨·점유·완료·역할·동일 파티 직업·고아 복구 조건은 그대로 먼저 또는 함께 만족해야 한다.
   - 참고: [`FIRESTORE_PARTY_COMMAND_CONTRACT.md`](../architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md) 4.3 최소 전투력 판정 계약, [`MVP.md`](../product/MVP.md) 모집글 작성/지원.

   **구현 전 실제 연결·충돌 조사(2026-09-21):**

   1. 운영 Router의 모집 상세는 과거 `RecruitmentApplicationCandidateService`가 아니라 생성 화면과 공유하는 `RecruitmentLeaderCandidateService`를 사용한다. 과거 서비스에는 최소 전투력 후보 판정이 있으나 운영 상세의 `RecruitmentLeaderCandidateQuery`에는 `minCombatPower`가 없으므로 현재 신청·즉시 가입·Character 변경 후보에는 실제 차단이 적용되지 않는다.
   2. `FirestorePartyAtomicApplicationCommandRepository`는 모집 원본과 Character의 입장 레벨·소유권·점유를 확인하지만 `command.combatPower`와 모집 제한을 비교하지 않는다. `FirestorePartyAtomicJoinCommandRepository`도 즉시 가입 또는 신청 Snapshot의 전투력을 membership에 복사할 뿐 제한을 검사하지 않는다. `FirestorePartyAtomicMemberMutationRepository` 역시 변경 Character 전투력을 저장만 한다.
   3. 모집 생성자의 기존 제한 검사는 그대로 둔다. F6-E는 모집 생성·수정, 전투력 산식, 계정 갱신과 Build Snapshot 생성, Firestore Rules·스키마·이벤트·인원 집계를 변경하지 않는다.
   4. 앱의 물리적·기술적 변조는 대응하지 않는다. 전투력을 속여 제한 모집에 참가할 실익이 낮고 현재 외부 배포된 구버전도 없으므로, 변조·구버전 우회를 위한 서버 권위 검증은 F6-E 완료 조건이 아니다.

   **확정 구현 설계:**

   1. `제한 없음 / 충족 / 정보 없음 / 미달`을 구분하는 단일 Domain 판정 정책을 둔다. 제한과 전투력이 같으면 충족이며, 제한이 있을 때 전투력 `null`은 미달과 같은 차단 대상이지만 사용자 문구는 `전투력 정보 없음`으로 구분한다.
   2. 운영 상세의 신청·즉시 가입과 Character 변경 후보 query에 모집의 `minCombatPower`를 전달한다. `RecruitmentLeaderCandidateService`는 선택 역할 Build Snapshot의 전투력으로 역할별 거절 사유를 만들며, F6-C의 레이드 미선택 탐색과 모집 생성 후보에는 이 제한을 새로 적용하지 않는다.
   3. UI 후보 차단만 신뢰하지 않는다. 신청·재신청 Transaction은 현재 모집 Aggregate 제한과 `PartyApplyCommand.combatPower`, 즉시 가입은 `PartyDirectJoinCommand.combatPower`, Character 변경은 `PartyChangeCharacterCommand.combatPower`를 쓰기 직전에 같은 정책으로 다시 비교한다. 기존 인증·모집 상태·revision·Character 소유권·입장 레벨·점유/완료·고아 판정·파티 구성 검증의 순서와 결과를 재작성하지 않고 기존 쓰기 계획 직전의 추가 게이트로 둔다.
   4. 승인 Transaction은 신청자의 private Character/`raidState`를 추가 조회하지 않는다. 이미 읽는 모집의 고정 제한과 application `submittedBuildSnapshot.combatPower`만 비교한다. 제한 미달 또는 Snapshot 누락이면 승인만 거절하고 신청은 `pending`으로 유지해 공대장이 기존 거절 버튼을 선택할 수 있게 한다. 과거 미달 신청도 같은 방식으로 차단하며 자동 거절·자동 삭제하지 않는다.
   5. `PartyApplicationFailure`, `PartyJoinFailure`, `PartyMembershipFailure`에 최소 전투력 미충족을 일반 `invalidCharacter`와 구분한 결과를 추가한다. 신청자에게는 최소 전투력 미달/정보 없음 안내를, 공대장에게는 `신청 캐릭터가 최소 전투력을 충족하지 않아 승인할 수 없습니다. 신청을 거절해 주세요.`를 표시한다. 이 결과는 D6의 `permissionDenied` 기반 고아 승인 복구 안내로 보내지 않는다.
   6. 승인 목록에서는 application Snapshot과 모집 제한만으로 미달·정보 없음 상태를 표시하고 승인 버튼만 비활성화한다. 거절 버튼은 유지한다. 제한을 충족한 정상 신청과 제한 없는 방의 기존 승인 UX는 그대로 둔다.

   **회귀 위험과 보호 기준:**

   - 전투력 제한 때문에 기존 `weeklyRaidCompleted`, `participationConflict`, `orphanedParticipation`, `stateInconsistent`, revision 충돌과 파티 구성 실패가 일반 전투력 오류로 덮이지 않게 한다. 후보 UI의 선차단과 Transaction 최종 게이트를 분리하되 서버 쓰기 전 기존 상태 검증은 보존한다.
   - 제한이 없는 방은 `combatPower == null`도 지금처럼 신청·즉시 가입·승인·Character 변경이 가능해야 한다. 제한값과 정확히 같은 전투력도 허용한다.
   - 이미 확정 참가한 미달 멤버를 자동 추방하거나 기존 membership을 수정하지 않는다. 이후 Character 변경 대상만 현재 제한을 만족해야 한다.
   - 다음 주 함께하기 상태의 Character 변경에도 같은 모집 제한을 적용하되, 완료 기록 유지와 다음 주 준비 예외는 변경하지 않는다.
   - 비교는 기존 Aggregate와 command/application Snapshot만 사용하므로 추가 Firestore 문서 읽기, 인원수 비례 호출, 개인 이벤트 fan-out과 Rules 배포가 없어야 한다.

   **최소 검증:** Domain 판정의 제한 없음·정확한 경계·미달·정보 없음, 운영 후보의 역할별 차단, 신청/재신청·즉시 가입·승인·Character 변경의 쓰기 직전 대표 게이트, 제한 없는 기존 흐름과 D6 승인 오류 분리를 표적으로 검증한다. 동일 UI 자동 반복은 하지 않으며 사용자는 실기기 두 대로 `미달 신청 차단`과 `충족 신청 → 승인`, 필요하면 즉시 가입 또는 Character 변경 대표 한 건만 확인한다. Rules가 바뀌지 않으므로 Emulator·운영 게시를 수행하지 않는다.

   **완료 상태(2026-09-21):** 단일 Domain 정책, 운영 후보 query, 신청·즉시 가입/승인·Character 변경 Transaction 게이트를 연결했다. 미달/정보 없음 신청은 승인만 비활성화하고 거절은 유지한다. 변경 파일 분석과 Domain·후보·상세 Widget·Repository 연결 계약 표적 테스트를 통과했고, 사용자가 실기기에서 미달 신청 차단·충족 신청 승인·미달 Character 변경 차단을 모두 확인했다.

D6·F6-C·F6-E는 코드·표적 검증·실기기 근거로 닫았다. 다음 F7에서 본인 즉시 가입의 D5 복구 UX, 문서의 과거 미확인 표기, 최종 회귀를 한 번 정리한다. 운영 Rules 활성 소스 대조는 별도 미확인 근거로 남기며, F7 전에는 `dev/main` 통합과 릴리즈를 보류한다.

#### F6-F — 지난 주차 1회성 방 미완료 종료와 진행 중 분리 (운영 문제 방 전환 확인, 회귀 확인 전)

기존 `진행 중` 읽기는 `active/completed` 상태만 기준으로 합치고 만료된 모든 `active` 방에 같은 다음 회차 전환을 시도해, `continueTogether == false`인 지난 주차 1회성 방이 서버에서 계속 `active`로 남을 수 있었다. F6-F는 BUG-022 파티장 권한 수정과 분리된 회차 수명주기 후속 작업으로, 현재는 화면 분리와 단일 방 원자 종료 구현까지 반영됐다.

**2026-09-25 운영 데이터 근거:**

- 기존 지평 그룹방 `5BCRsQkPRDvje1DrllEM`과 세르카 그룹방 `zxrz7IKQxq3Q386cktp8`은 모두 `continueTogether=false`, `currentCycleKey=2026-09-16`, `status/currentCycleStatus=active`인 지난 주차 1회성 방이다. 같은 그룹에 속하지만 raid는 각각 `horizon_cathedral`, `serca`로 다르다.
- 현재 주차에 만든 공개 지평 방 `bDxr3PCcZo6j1HcVa7PN`과 그룹 세르카 방 `tVzXqc9VKIoszI3R9i8x`은 각각 정상 해산됐다. 지평 대조 방 해산 뒤 같은 Character·레이드의 `raidState` 문서가 존재하지 않는 것을 직접 확인했다.
- 기존 지평 방은 그 state ID를 생성 당시 `raidStateTargets`에 계속 갖고 있다. 현재 정상 해산 구현은 모든 target을 삭제하고 Rules는 삭제 전 state가 해당 모집을 가리키도록 요구하므로, 누락 state 때문에 전체 해산이 거절될 수 있다. 세르카도 기존·현재 주차 방이 같은 결정적 state 경로를 공유하므로 동일하게 과거 target의 현재 소유를 가정할 수 없다.
- 이 근거로 F6-F는 A1 count 보정의 재수정이 아니라, 만료 1회성 방을 정상 해산과 분리하는 수명주기 명령으로 확정한다.

**확정 처리 분기:**

1. 현재 회차의 `active` 방은 기존처럼 표시하고 변경하지 않는다.
2. 만료된 반복방(`continueTogether == true`)은 기존 lazy 다음 회차 전환만 수행한다. membership과 방을 승계하고 다음 주에도 진행 중으로 유지하며, 미완료 종료 명령의 대상이 되지 않는다.
3. 만료된 1회성 방(`continueTogether == false`)은 진행 중 목록에서 즉시 제외하고, 발견된 모집 한 건에 한해 멱등 미완료 종료 Transaction을 실행한다. 모집과 현재 회차를 `incompleteEnded`로 바꾸되 자동 완료·해산·삭제·소유권 이전으로 처리하지 않는다.
4. `completed`는 기존 해산 UX를 위해 표시하고 `disbanded/incompleteEnded`는 표시하지 않는다. 이미 끝난 방에는 쓰기를 수행하지 않는다.

**구현 경계와 순서:**

1. **완료(2026-09-25):** `현재 / 만료 반복 / 만료 1회성 / 이미 종료`를 구분하는 단일 순수 판정과 표적 테스트를 추가했다. 진행 중 읽기 모델에 `cycleEndsAt`을 연결했으며, 필드가 없는 과거 문서는 기존처럼 표시한다.
2. **완료(2026-09-25):** 진행 중 Projection에서 만료 1회성 방만 즉시 제외하고 후속 종료 대상 ID를 별도로 보존한다. 현재 주차 방, 만료 반복방과 `completed` 해산 대기 방은 기존처럼 표시한다. 새 종료 명령이 없는 이 단계에서는 숨긴 1회성 방을 기존 반복방 reconciliation에 보내지 않는다.
3. **구현 완료(2026-09-26):** 원자 lifecycle에 target 없는 `incompleteEnd`를 추가했다. 기존 lazy `advanceCycle` 진입점은 반복방이면 그대로 다음 회차 전환을 사용하고, 1회성이면 별도 종료 명령으로 변환한다. Transaction과 Rules는 양쪽 `active`, `continueTogether == false`, `request.time >= cycleEndsAt`, 예상 `revision/currentCycleKey`와 고정 변경 필드만 허용한다.
4. **구현 완료(2026-09-26):** 성공 시 모집을 `incompleteEnded`로 바꾸고 활성·빈자리 표식과 revision을 갱신하며 `partyIncompleteEnded` 공용 lifecycle 이벤트 한 건을 쓴다. 그룹 전용방은 같은 Transaction에서 listing을 삭제하고 현재 그룹 count를 `N -> N-1`로 갱신하며, 공개방은 그룹 쓰기를 만들지 않는다.
5. **구현 완료(2026-09-26):** 종료 명령의 command target과 `raidState` 읽기·쓰기 목록을 비웠다. `raidStateTargets`·`partySlots`는 보존하며, 누락 state나 다른 모집이 재사용 중인 state를 종료 조건이나 삭제 대상으로 삼지 않는다.
6. **구현 완료(2026-09-26):** 화면에서 숨긴 만료 1회성 ID도 단일 방 reconciliation 대상으로 전달한다. 실패·오프라인이면 화면에서는 계속 제외하고 다음 스트림 갱신·화면 새로고침에 재시도한다. 전체 순회·스케줄러·Functions·일괄 migration은 추가하지 않았다.

**2026-09-26~27 자동 검증·운영 확인 상태:** 변경 Dart 파일 표적 분석 0건, F6-F 정책·목록·Write Plan·Aggregate·Rules 계약과 기존 R2/R3/C* Rules 계약을 합쳐 52건이 통과했고 JS Rules fixture 문법도 통과했다. R3의 낡은 문자열 배치 검사는 권한 조건 변경 없이 현재 OR 체인 존재 여부를 확인하도록 교정했다. 로컬 Firestore Emulator는 Java 미설치로 시작하지 못했다. SHA-256 `01E06015969D8CA7183BAAB66E7F887A69B94200B07F448EBF84A3B542AB66A6`의 Rules 배포 CLI는 원격 컴파일 성공·경고 0개 뒤 `/rulesets` HTTP 503을 반환했지만, 이후 콘솔의 신규 게시 시각과 운영 문제 방의 신규 `incompleteEnd` 명령 실행으로 실제 활성화를 확인했다. 기존 지평 방 `5BCRsQkPRDvje1DrllEM`은 revision `6 → 7`, `status/currentCycleStatus: active → incompleteEnded`, 활성·빈자리 표식 false, `lastCommandType: incompleteEnd`로 전환됐고 생성 당시 `raidStateTargets/partySlots`는 보존됐다. 모집의 그룹 count 결과는 생성 당시 Snapshot `5`가 아니라 Transaction 당시 현재 그룹 기준 결과 `10`으로 기록됐다. 남은 확인은 반복방의 다음 회차 승계, 현재 주차 방 무변경과 미완료 종료 이력 노출이며 그 전에는 F6-F 전체 완료나 `dev` 통합으로 표기하지 않는다.

**F6-F 실기기 경계 검증 순서(2026-09-27):** 운영 기본값은 KST 수요일 06:00으로 유지한다. 빠른 경계 검증이 필요하면 먼저 `RaidCycleSchedule` 기본값을 **현재보다 충분히 뒤인 같은 요일·시각**으로 임시 변경하고 그 빌드를 설치한다. 그런 다음 경계 **전에** 공개 1회성·그룹 1회성·공개 반복·그룹 반복 방을 생성해야 각 방의 `targetCycleKey/currentCycleKey/cycleStartedAt/cycleEndsAt`이 같은 임시 경계로 저장된다. 경계 후 앱을 재실행해 1회성 두 방의 진행 중 제외·`incompleteEnded` 전환과 반복 두 방의 다음 회차 승계를 확인한다. 임시 시각으로 바꾸기 전에 생성한 방은 기존 `cycleEndsAt`을 보존하므로 이 테스트 대상으로 사용하지 않는다. 확인 후에는 코드와 경계 테스트를 KST 수요일 06:00으로 원복하고 `dev`·`main`·release에 임시값을 통합하지 않는다. Rules·저장 스키마·기존 방의 저장 시각은 수정하지 않는다.

**회귀 보호:** 기존 완료·해산·추방·자리 변경·참가·반복 설정과 반복방 membership 승계의 판단, 제약, 권한과 쓰기 순서를 임의로 바꾸지 않는다. 참가자 구성 Snapshot과 모집 원본은 보존하며 기존 stale `raidState` 판정·정리 범위를 이 작업을 이유로 넓히지 않는다.

**최소 검증과 완료 조건:** 현재 1회성 무변경, 만료 1회성 숨김·단일 종료, 만료 반복방 전환·미종료, 이미 종료된 방 no-op을 표적으로 검증한다. Rules/Transaction은 종료 시각 전 거절, 반복방 거절, status·revision·반복 설정 변조 거절, 동시 재시도 멱등성, 공개방 무그룹 쓰기, 그룹 listing 삭제와 현재 count `N -> N-1`을 확인한다. 추가로 (a) 생성 당시 target `raidState`가 없음, (b) 같은 state 경로가 더 새 주차·다른 모집을 가리킴 두 사례에서 미완료 종료는 성공하고 새 state는 보존되는지 검증한다. 인원수 확장은 8인 대표 한 건만 사용하고 상태 전이가 다른 경계만 별도로 둔다. 사용자는 수정 빌드에서 `지난 주차 1회성 방이 진행 중에서 사라지고 미완료 종료 이력으로 남는지`, `다음 주도 함께하기 방이 다음 회차로 넘어가 계속 보이는지`, `현재 주차 방이 그대로인지`를 실기기로 확인한다. 자동 검증과 사용자 실기기 확인 전에는 완료 또는 `dev` 통합으로 판정하지 않는다.

#### F6-G — 참가 캐릭터 변경의 종료 모집 점유 판정 정렬 (완료)

**관찰된 재현:** F6-F가 운영 반영된 뒤 사용자가 현재 주차 AILKER 지평의 성당 3단계 방을 새로 만들고, 다른 사용자의 신청·참가가 없는 상태에서 방장 자신의 참가 Character 변경을 시도했다. 지난 주차 방은 진행 중 화면에서 모두 제외됐지만 변경은 `다른 확정 참가와 충돌합니다. 캐릭터를 다시 선택해 주세요.`로 거절됐다. 실패한 변경 명령은 최종 쓰기 전에 중단되므로 현재 방 membership과 기존 Character 점유는 그대로 보존된 상태로 본다.

**확인된 원인 경계:** 후보 목록의 점유 조회는 `raidState`와 연결 모집을 함께 읽고 공용 점유 정책으로 `부모 없음 / completed / disbanded / incompleteEnded / 만료 1회성`을 교체 가능한 고아 상태로 분류한다. 반면 최종 `changeCharacter` Transaction은 새 Character의 결정적 `raidState` 문서가 존재하면 현재 주차 완료 여부만 확인한 뒤 나머지를 모두 `participationConflict`로 반환한다. 따라서 F6-F가 참가자 state를 안전하게 보존한 것이 직접 결함이 아니라, 캐릭터 변경 후보와 최종 명령이 동일 state를 서로 다르게 판정하는 것이 직접 결함이다.

**수정 설계:**

1. 최종 변경 Repository가 새 Character의 `raidState`를 단순 존재 여부로 판정하지 않고, 후보 조회·생성·가입에서 사용하는 기존 점유 분류와 같은 기준으로 검사한다. 공용 정책을 복제한 새 조건문을 만들지 않는다.
2. state가 없으면 현재 캐릭터 변경 Transaction을 그대로 수행한다. 현재 유효한 다른 모집 참가, 회차 조정 전 반복방 점유와 현재 주차 완료는 기존 오류로 계속 차단한다.
3. `active` state가 종료되거나 없는 모집을 가리켜 고아로 확정되면 변경 Transaction은 membership·모집·기존/신규 state를 전혀 쓰지 않고 `PartyOrphanedRaidParticipation` 식별자를 포함한 별도 결과를 반환한다.
4. 화면은 신청·즉시 가입에서 이미 사용하는 단일 고아 참가 정리 확인창과 `cleanupOrphanParticipation` 명령을 재사용한다. 서버가 관찰한 state의 Player·Character·raid·cycle·recruitment·revision과 부모 상태를 다시 검증한 경우에만 해당 고아 state 한 건을 삭제한다.
5. 정리 성공 뒤 캐릭터 변경을 자동 재시도하지 않는다. 사용자가 다시 Character를 선택하면 최신 모집 revision, 슬롯·역할·직업 제한, 소유권·레벨·주간 완료와 점유를 처음부터 재검증한다. 이는 정리와 변경 사이의 동시 변경을 성공으로 오인하지 않기 위한 경계다.
6. state가 더 새 모집을 가리키거나 식별자가 달라졌거나 부모 판정이 불명확하면 삭제·덮어쓰기하지 않고 거절한다. 과거 방 전체 순회, Player 전체 정리, F6-F `incompleteEnd`의 state 삭제, 자동 migration은 추가하지 않는다.

**회귀 보호 목록:**

- 현재 활성 다른 방 참가 Character는 계속 변경 후보·최종 명령에서 차단한다.
- 현재 주차 완료 Character, 입장 레벨 미달, 소유권 불일치, 역할 정원과 동일 파티 중복 직업 제한은 그대로 유지한다.
- 만료 반복방은 기존 lazy 회차 승계가 먼저이며 고아로 임의 삭제하지 않는다.
- 같은 Character 역할 변경, 기존 Character 점유 삭제와 새 점유 생성, membership·Aggregate·revision의 원자 갱신 순서는 변경하지 않는다.
- 신청·즉시 가입의 기존 고아 정리 UX와 정상 생성·승인·추방·해산·자리 이동, F6-F 미완료 종료 계약은 수정하지 않는다.
- 기존 정리 Rules로 계약을 충족하면 Rules를 변경·재배포하지 않는다. 구현 조사에서 새 Rules 변경이 불가피한 근거가 확인될 때만 별도 diff와 계약 검증 범위를 먼저 기록한다.

**최소 구현·검증 순서:**

1. **구현 완료(2026-09-27):** membership 결과 모델에 고아 참가 payload를 전달할 명시적 결과를 추가하고, 화면을 기존 정리 UX에 연결했다.
2. **구현 완료(2026-09-27):** 최종 Transaction의 새 Character 점유 판정을 공용 `PartyRaidStateOccupancyInspector` 분류에 맞췄다. 고아 결과에서는 membership·모집·기존/신규 state를 쓰지 않는다.
3. **표적 검증 완료(2026-09-27):** 종료 모집 연결 state의 고아 분류, 현재 유효 active 차단, Repository의 공용 판정 사용·자동 삭제 부재, 정리 뒤 캐릭터 변경 자동 재시도 부재를 확인했다. 현재 완료·반복방·불명확 state의 기존 차단 분기도 유지했다.
4. 기존 cleanup Rules와 명령은 변경하지 않았다. 따라서 Rules 재배포도 하지 않는다.
5. 사용자는 실기기에서 종료 방 점유가 남은 Character를 선택해 `정리 안내 → 정리 성공 → 수동 재선택 → 변경 성공`을 확인한다. 동시에 실제 활성 다른 방 Character와 현재 주차 완료 Character가 계속 차단되고, 현재 모집이 실패 중 사라지거나 기존 Character가 빠지지 않는지 확인한다.

**자동 검증 기록(2026-09-27):** 점유 정책 8건, 원자 membership Repository 계약 7건과 F6-G 상세 화면 단독 Widget 테스트가 통과했고 변경 파일 `flutter analyze`는 0건이다. 상세 화면 전체 테스트에서는 F6-G를 포함한 나머지 테스트가 통과했으나, 기존 `방 진입 즉시 이벤트를 읽음 처리하고 구성 옆 팝업에 표시한다` 1건이 로컬 이벤트 조회 0건으로 실패했다. F6-G 변경 경로와 무관하므로 이 구간에서 수정하지 않았다.

**실기기 확인(2026-09-27):** 기존 충돌이 발생하던 Character를 선택하자 참가 기록 정리 안내가 표시됐고, 사용자가 정리를 실행한 뒤 Character 변경을 다시 시도해 정상 성공했다. 정리 직후 자동 변경되지 않는 계약도 함께 확인됐다. 공용 점유 정책의 실제 활성 참가·현재 완료·반복방 보존은 표적 자동 검증으로 유지하며, F6-G를 완료 처리한다.

**완료 결과:** 원인과 무관한 권한·조건을 완화하지 않고 위 재현을 기존 단일 고아 정리 경로로 복구했다. 자동·실기기 검증을 충족해 F6-G는 완료했지만, F6-F의 별도 회귀 확인 전에는 BUG-022 전체 종료 또는 `dev` 통합으로 표기하지 않는다.

#### F6-H — 반복방 승계 후 멤버 명령과 실행 중 회차 갱신 (구현 완료·Rules/실기기 검증 전)

**실기기·운영 데이터 근거(2026-09-27):**

- KST 일요일 19:00으로 임시 경계를 설정한 빌드로 18:55에 방을 생성했다. 경계 후 1회성 방은 진행 중 목록에서 제외됐고 반복 방만 남아 F6-F의 핵심 분류는 통과했다.
- 지평의 성당 3단계 `n9RmAeyRdY5mUEANJaQP`은 19:01에 `advanceCycle`, revision `4 → 5`, `currentCycleKey/targetCycleKey=2026-09-27`, `currentCycleStatus=active`, `cycleStartedAt=2026-09-27 19:00 KST`, `cycleEndsAt=2026-10-04 19:00 KST`로 승계됐다.
- 벨가르딘 하드 `toae6qAv7mS5eA8Q6zLW`도 같은 새 회차로 승계된 뒤 19:09에 `complete`, revision `6`, `currentCycleStatus=completed`로 정상 완료됐다.
- 활성 새 회차인 지평 방에서 Character 변경, 다른 참가자 추방, 다른 참가자 자리 이동이 모두 `permission-denied`로 실패했다. 이는 소유권·Player 불일치나 승계 실패가 아니다.
- 경계 직후 같은 앱 프로세스에서 새 모집 생성은 `모집 생성 권한을 확인할 수 없습니다`로 실패했지만 앱 재실행 후 성공했다.

**원인 A — 지속 명령 기록과 현재 Transaction 종류의 혼동:**

1. lifecycle Transaction은 모집에 `lastCommandId/lastCommandType/lastCommandActorPlayerId/lastCommandAt/commandTargets`를 저장한다. 이 값은 멱등성·감사 기록으로 Transaction 종료 후에도 남는다.
2. Rules의 `validAtomicRaidStateCreate`, `validAtomicMembershipPartyEvent`, `validAtomicMembershipRaidStateDelete`는 `!atomicIsLifecycleCommand(recruitment)`을 요구한다. 이 함수는 현재 요청에서 lifecycle 메타데이터가 **변경됐는지**가 아니라 저장된 `lastCommandType`이 lifecycle 문자열인지만 본다.
3. `advanceCycle` 뒤 `lastCommandType=advanceCycle`가 남은 방에서 후속 멤버 명령은 Aggregate·membership·`raidState`·event 쓰기를 올바르게 계획해도 Rules에서 lifecycle 명령으로 오인된다.
4. Character 변경은 기존 state 삭제·신규 state 생성·membership event에서, 추방·탈퇴는 state 삭제·event에서 거절된다. 자리 이동은 `raidState`를 쓰지 않지만 `membersRepositioned` event가 거절돼 전체 Transaction이 실패한다.
5. 같은 guard를 쓰는 신청 승인·즉시 가입·재가입·신청 event도 lifecycle 이후 같은 원인으로 실패할 수 있다. 제보된 세 명령만 예외 처리하지 않고 공유 계약을 바로잡아야 한다.

**원인 B — 앱 수명에 고정된 현재 회차:**

1. `app_router.dart`는 Router 조립 시 `PartyCyclePolicy.keyFor(DateTime.now())`를 한 번 계산해 `currentCycleKey/currentCycle`로 보관한다.
2. 레이드 현황·내 계정·모집 목록·모집 생성 Router가 같은 Snapshot을 받는다. 앱 실행 중 경계를 넘어도 생성 명령은 이전 회차를 전송하고 서버 Rules가 거절한다.
3. 생성 화면에는 `cycleKey` 미주입 시 제출 직전 현재 시간으로 계산하는 기존 fallback이 있지만, 운영 Router가 고정 키를 항상 주입해 fallback을 사용하지 않는다.
4. 앱 재실행 후에는 Router가 새 키를 계산하므로 생성이 성공한다. 이는 Rules 배포·Auth·소유권 문제가 아니다.

**수정 원칙:**

- `!atomicIsLifecycleCommand(...)`를 단순 삭제하거나 `signedIn()`·방장 여부만으로 대체하지 않는다. 실제 lifecycle 요청에 위조된 membership event·`raidState` 쓰기를 끼워 넣을 수 있게 되므로 권한 완화다.
- lifecycle 메타데이터는 “직전 명령의 멱등성 기록”이지 방이 계속 lifecycle Transaction 중이라는 lock이 아니다. 후속 명령은 기존 revision·소유권·상태·점유·Claim·구성 검증을 모두 통과한 같은 Transaction에서만 이전 lifecycle 마커를 소진한다.
- 반복 방 `i` 표시는 새 회차에도 승계된 확정 참가를 뜻하므로 유지한다. F6-F 1회성 미완료 종료의 보존 state·수동 고아 정리와 혼합하지 않는다.
- 임시 테스트 경계는 운영 계약이 아니다. 현재 작업 트리의 KST 일요일 19:00을 코드·테스트·문서 계약의 KST 수요일 06:00으로 원복한 뒤만 실제 수정 커밋·`dev` 통합을 검토한다.

**H1 설계 — 후속 명령의 lifecycle 마커 소진:**

1. 공용 Write Plan helper로 `commandTargets=[]`, `lastCommandId=null`, `lastCommandType=null`, `lastCommandActorPlayerId=null`, `lastCommandAt=null`을 만든다. 이는 별도 쓰기가 아니라, 허용된 후속 Aggregate 명령의 revision 증가·기능 변경과 같은 원자 Transaction에만 포함한다.
2. Character 변경, 자리 이동, 탈퇴·추방, 신청 승인·즉시 가입·재가입, 신청 생성·철회·거절 중 recruitment revision을 바꾸고 membership event/개인 state를 함께 쓰는 원자 경로를 전수 조사한다. 제보된 세 Repository에만 예외를 넣지 않는다.
3. 각 Rules Aggregate validator는 기존 허용 필드에 마커 필드를 무조건 추가하지 않는다. **oldData가 lifecycle 마커를 가진 경우에만** 새 값이 빈 target·null 메타데이터인지 검증하고, 그 요청의 기존 Aggregate 전이·revision·`request.time`·작업 주체 검증을 모두 유지한다.
   - Rules 구현에서는 nullable 필드를 map/string helper 인수로 넘기지 않는다. 필드 존재 여부와 타입을 먼저 확인한 뒤 직접 비교해 null 평가로 인한 예기치 않은 거절·허용을 막는다.
4. 마커를 소진한 `getAfter(recruitment)`에서만 기존 membership event·`raidState` create/delete 분기가 평가되게 한다. 실제 `complete/advanceCycle/incompleteEnd/disband/personalComplete` Transaction은 계속 기존 lifecycle 마커·target·event 정합성을 요구하며 membership 분기를 탈 수 없다.
5. 마커 소진 후에도 lifecycle event와 이력은 불변 `partyEvents`에 남는다. 후속 revision의 명령이 성공한 뒤 이전 lifecycle 요청은 기존 계약대로 conflict다.
6. `atomicIsLifecycleCommand`·lifecycle validator·소유권·현재 상태·주간 Claim·직업/역할/자리·그룹 listing/count 조건은 완화하지 않는다. `completed/disbanded/incompleteEnded` 방을 활성 회차로 취급하지 않는다.

**H2 설계 — 현재 회차를 제출·구독 시점에 갱신:**

1. `PartyCyclePolicy`를 복제하거나 화면별 요일·시각 계산을 추가하지 않는다. 공용 정책과 clock을 쓰는 단일 runtime 회차 제공자를 Router/DI에 연결한다.
2. 모집 생성은 화면 진입 때 받은 문자열이 아니라 **제출 직전** 제공자의 현재 키를 사용한다. 기존 `RecruitmentCreatePage` fallback과 같은 공용 정책 결과를 쓰며 서버 Rules 검증은 그대로 둔다.
3. 모집 목록·신청 목록·내 계정 주간 표시처럼 회차 키로 스트림을 구독하는 화면은 제공자가 경계 변경을 알리면 기존 구독을 해제하고 새 키로 정확히 한 번 재구독한다. 기존 필터·정렬·로컬 선택은 보존한다.
4. 앱이 포그라운드에 있어 timer가 지연될 수 있으므로 예정 경계 timer만 믿지 않고 app resume·수동 새로고침·주요 명령 제출에서 현재 키를 재확인한다. 중복 Listener·중복 생성 요청을 만들지 않는다.
5. 경계 직전 키 계산 후 서버 Transaction 중 경계가 지나는 경쟁은 Rules가 거절하게 둔다. 실패를 성공으로 숨기거나 새 recruitment ID로 자동 중복 재시도하지 않고, 현재 회차로 새로고침한 뒤 사용자가 다시 제출하게 한다.
6. 기존 방의 `cycleStartedAt/cycleEndsAt`을 현재 앱 설정으로 소급 재계산하지 않는다. 방은 생성·승계 시 저장된 경계를 계속 권위 값으로 사용한다.

**예상 영향과 회귀 보호:**

| 영향 경로 | 잘못 수정했을 때의 문제 | 보존 계약 |
|---|---|---|
| 실제 lifecycle 명령 | guard 삭제 시 위조 event/state를 끼워 넣을 수 있음 | lifecycle 마커·target·revision·actor·event 검증 유지 |
| 신청·승인·즉시 가입 | 보고된 세 액션만 패치하면 반복방 재모집이 거절됨 | 공용 마커 소진 계약을 모든 원자 membership/application 경로에 동일 적용 |
| Character 변경 | 점유·Claim·소유·레벨·구성 제약이 약화될 수 있음 | F6-G 공용 점유 판정과 기존 Validator/Write Plan 순서 유지 |
| 자리 이동 | event만 허용하면 위조 알림 생성 가능 | 실제 `partySlots`·membership 위치·revision 전이와 event를 같은 Transaction으로 묶음 |
| 추방·탈퇴 | 타인 state 삭제 권한이 넓어질 수 있음 | 방장/본인, 단일 제거, Aggregate target 제거, listing revision 동기 유지 |
| 그룹 전용방 | listing/count가 모집 revision과 어긋날 수 있음 | 현재 그룹 원본 count, listing `sourceRevision`, 그룹 membership 조건 유지 |
| 완료·해산·미완료 종료 | 활성 멤버 명령으로 오판할 수 있음 | `status/currentCycleStatus` 게이트 유지, 종료 방을 새로 활성화하지 않음 |
| 멱등 재시도 | 마커 정리로 직전 lifecycle 성공을 잊을 수 있음 | 후속 revision 성공 전에는 기존 회복 유지, 후속 성공 후 이전 요청은 conflict |
| 경계 전후 화면 | 서로 다른 키로 query/write할 수 있음 | 단일 runtime 제공자, 경계·resume의 1회 재구독, 제출 직전 재확인 |
| 기존 저장 방 | 현재 schedule로 소급 변경될 수 있음 | 저장된 `cycleEndsAt`을 보존, 일괄 migration 없음 |

**구현 순서:**

1. **H1-A Rules/Write Plan 계약:** 원자 recruitment 쓰기 경로를 전수하고 공용 lifecycle 마커 소진 patch와 Rules helper를 추가한다. 이 단계에서 Router·시간 제공자는 변경하지 않는다.
2. **H1-B 안전 검증:** 반복 승계 후 Character 변경·자리 이동·추방·탈퇴·신청 승인/즉시 가입을 표적 Rules Emulator로 확인한다. 기존 정상방의 같은 명령과 lifecycle 위조·타인·종료 상태·Claim/점유 충돌 거절을 함께 고정한다.
3. **H2-A runtime 회차 제공자:** 기존 `PartyCyclePolicy`를 단일 clock 경계로 연결하고 Router의 고정 Snapshot 주입을 제거한다. 화면별 재구독·제출 시점을 한 구간씩 연결한다.
4. **H2-B 경계 검증:** fake clock으로 재실행 없이 경계를 넘겨 생성 명령·모집 query·신청 query·내 계정 표시가 한 회차로 바뀌는지 확인한다. background resume와 경계 경쟁 거절도 별도로 확인한다.
5. **최종 Rules/DI 대조:** 변경 Rules 계약, JS 문법, 경고 0개, 변경 Dart 표적 분석을 확인한다. Rules Emulator가 환경 문제로 막히면 문자열 계약만으로 완료 판정하지 않는다.
6. **운영 게이트:** 임시 일요일 19:00을 수요일 06:00으로 원복한 최종 diff를 확인한다. Rules는 검증 완료 후 현재 추적본을 정확히 한 번만 게시 시도하며, Indexes·Functions·기존 데이터 migration은 제외한다.

**구현 상태(2026-09-27):**

- H1은 `complete/advanceCycle/incompleteEnd/disband` 직전 명령 봉투만 식별하는 공용 Write Plan patch를 추가했다. 신청·가입·승인·캐릭터 변경·자리 이동·탈퇴/추방·공개 범위 변경은 기존 Aggregate validator를 모두 통과한 같은 Transaction에서만 `commandTargets`와 `lastCommand*`를 비운다. 일반방과 `personalComplete` 봉투는 변경하지 않는다.
- Rules는 위 여섯 Aggregate validator의 기존 허용 필드·revision·actor·상태·점유 조건을 유지하면서 lifecycle 마커의 정확한 소진 또는 비lifecycle 마커 보존을 추가 검증한다. `validAtomicRaidStateCreate/Delete`와 membership event의 실제 lifecycle 차단은 유지했다.
- H2는 앱 수명의 `PartyCycleRuntime`을 Router `refreshListenable`로 연결했다. 경계 timer와 app resume·레이드 현황 탭 재선택에서 현재 회차를 확인하고, 키가 실제 변경된 경우에만 레이드 현황 신청 목록·내 계정·모집 목록 화면을 새 key로 재생성한다. 모집 생성은 제출 직전 회차를 다시 계산해 화면 진입 값보다 우선한다.
- 임시 일요일 19:00 기본값은 운영 계약인 KST 수요일 06:00으로 원복했다. 기존 모집 문서의 저장된 회차 경계에는 migration이나 소급 계산을 하지 않는다.
- runtime/생성 제출/Write Plan/Rules 정적 계약을 포함한 표적 Flutter 26건과 변경 Dart 파일 분석, JS 문법, `git diff --check`가 통과했다. 과거 R5 문자열 테스트 한 건은 현재 소스의 `membership OR lifecycle` 순서와 반대인 오래된 assertion으로 기존 기준선 실패임을 재확인했으며 이번 수정으로 순서를 바꾸지 않았다.
- production Rules Emulator 시나리오에는 lifecycle 마커 미소진 거절, 소진 후 자리 이동·추방·신청 성공을 추가했다. 저장소의 JDK 21로 로컬 Emulator 자체는 기동했지만 추적 Rules 로딩 단계에서 기존 Windows 환경과 같은 HTTP 503 `Network closed for unknown reason`가 발생해 시나리오 평가에는 도달하지 못했다. 같은 로컬 명령은 반복하지 않으며, 원격 작업 브랜치의 격리 CI 회귀 전에는 문자열 계약만으로 완료 판정하지 않는다.
- 원격 Actions `36318200515`에서는 Rules 컴파일과 F6-H 신규 허용·거절 사례, 기존 그룹방 탈퇴까지 모두 통과했다. 그 다음 별도 범위인 `그룹방 탈퇴 후 직접 재가입`이 기존과 같은 1,000식 한도로 실패했다. 마지막 성공 CI에는 이 재현 케이스가 없었고 케이스 추가 이후 실행은 동일 실패를 계속 기록했으므로 F6-H가 만든 신규 회귀로 보지 않는다. 다만 전체 회귀 성공 조건은 충족하지 못했으므로 운영 Rules 게시와 F6-H 완료 판정은 보류한다. 이를 통과시키려고 재가입 테스트·권한·원자성 조건을 임의로 완화하지 않는다.

**최소 완료 조건:**

- 활성 반복방이 `advanceCycle` 후에도 기존과 같은 주체·구성·점유 제약으로 Character 변경, 자리 이동, 추방·탈퇴, 신청·가입을 수행할 수 있다.
- 위 명령이 성공해도 실제 lifecycle 명령의 target·event·state 검증, 방장/본인 권한, 주간 Claim·점유·구성·그룹 listing/count 제약은 기존과 동일하다.
- 종료·미완료 종료·해산 방, 타인·위조 요청, 잘못된 revision·회차·event·state 조합은 계속 거절된다.
- 앱을 재실행하지 않아도 경계 후 새 모집은 새 회차로 생성되고, 회차 기반 목록·표시는 중복 구독 없이 새 키로 전환된다.
- 기존 방의 저장 경계와 F6-F 1회성 `incompleteEnded`, F6-G 단일 고아 정리, 완료·해산·개인 완료, 공개/그룹 방의 기존 흐름은 변경하지 않는다.
- 자동 검증·Rules 게시·사용자 실기기 확인 전에는 F6-H 완료, BUG-022 전체 종료 또는 `dev` 통합으로 표기하지 않는다.

#### F6-I — 그룹 반복방 승계 진단 이력 (최신 확정 원인·수정은 문서 상단)

아래는 삭제된 이전 방과 첫 진단 단계의 이력이다. 새 샘플은 원본 승계 성공·listing 회차
누락으로 원인이 확정되어 추가 방장 로그 수집은 현재 수정의 선행 조건이 아니다.
2026-09-29 수정 결과와 검증은 `DEV_LOG.md` 최신 항목을 따른다.

**2026-09-28 첫 구현 구간:** 기존 active snapshot에서 만료 반복방 중 현재 방장인
항목의 ID·revision을 선별하고 기존 reconciler의 첫 실행 결과를 목표 회차와 함께 기록한다.
동일 ID·목표 회차·revision의 실패는 자동 재호출하지 않으며 revision 변경, 명시적
새로고침 또는 앱 재실행 때 재시도한다. 목록 후보는 순차 실행한다. 1회성 종료는 기존
F6-F 명령을 유지한다. Rules·승계 Transaction·listing 쓰기·저장된 회차 경계는 이 진단
구간에서 변경하지 않는다. 후보/권한 선별, 중복·실패 억제, 재시도와 결과 연결을 표적
검증한 뒤 사용자 디버그 실행의 `PartyCycleReconcile` 결과로 실제 원인을 확정한다.
이 구간의 종료는 진단 경로 준비이며 그룹 반복방 버그 또는 F6-I 전체 완료가 아니다.

**첫 구간 결과:** 후보 선별·revision별 결과 보존·순차 실행·명시적 재시도와 디버그
로그 연결을 완료했다. 표적 28건 통과 후 상세/목록 동시 진입의 실제 gateway 중복
억제를 보강해 서비스 11건을 재검증했다(기존 다른 표적 결과 재사용, 최종 관련 29건).
변경 파일 정적 분석과 diff 검사를 수행했다. 상세 진입의 기존 호출 자체는 보존하며,
방장 후보 제한과 revision별 자동 실패 억제는 진행 중 목록 경로에 적용한다.
새 Firestore 조회·쓰기·Rules 변경·배포는 없다. 상세 이력은 `DEV_LOG.md`를 따른다.

**다음 필요한 근거:** 사용자가 디버그 빌드로 문제 방의 방장 계정에서 레이드 현황을
열고 `PartyCycleReconcile` 로그를 수집한다. `command`는 명령의 원래 실패값,
`read`는 gateway 읽기 오류 code, 최종 행은 모집 ID·관찰 revision·이전/목표 회차와
결과를 기록한다. 같은 snapshot의 반복 실패는 억제하며 레이드 현황 탭 재선택으로
명시적 재시도를 할 수 있다. 로그가 없다면 후보 입력/역할·만료 분류부터 확인하며
성공으로 해석하지 않는다. 저장된 임시 경계를 변경하거나 테스트 방을 일괄 정리하지 않는다.

후속 대조: lifecycle listing patch는 현재 회차 필드를 갱신하지 않지만 그룹 목록은
현재 회차 키를 요구한다. 이는 승계 성공 후 목록 노출의 확인 지점으로 남기며 실제
승계 실패의 원인으로 단정하지 않는다. A2-B와 A3는 위 구현 순서에 따라 별도 수행한다.

**확인된 현상(2026-09-28):** 그룹 반복방 `eYjsz5OqzcppZCUK3Bts`는
`continueTogether=true`, `status=active`인 상태로 이전 회차
`2026-09-21`에 남았고 `advanceCycle` 이벤트가 없었다. 같은 조건의 공개 반복방
`9R4u8gHNSUwMDJcBKh9Z`는 현재 회차 `2026-09-28`로 정상 승계됐다. 문제 방 원본 모집은
revision 9, 방장 1인과 방장 `raidState`를 유지하지만 그룹 listing에는 제거된 두 번째 멤버와
과거 party slot·target이 남아 있다.

**원인 재검토(2026-09-28):** 최초에 “그룹 listing의 현재 회차 필터에서 먼저 빠져 승계 ID가
전달되지 않았다”고 판단했으나 현재 코드와 맞지 않아 철회한다. 레이드 현황은 listing이 아니라
원본 `recruitments`를 방장·멤버 조건으로 구독한다. `expiredRecurring`은 진행 중 목록에 유지되고,
ViewModel 변경 listener가 `LazyCycleReconciler`를 호출한다. 따라서 새 listing 탐색 경로를 만드는
것은 불필요한 조회·구조 추가이며 실제 원인을 가릴 수 있다. 현재 확정된 것은 승계 성공 이벤트가
없다는 사실까지다. 기존 호출이 시작되지 않았는지, 시작 후 `permissionDenied/invalidData/
temporarilyUnavailable` 중 어디에서 실패했는지는 반환 결과를 버리고 있어 아직 확정되지 않았다.

**단순 구조 목표:** 확인 범위나 회귀 보호를 줄인다는 뜻이 아니다. 목록·상세·참가 상태·그룹
Projection과 Rules에 미치는 영향은 모두 확인하되, 같은 문제를 처리하는 새 상태·새 복구 명령·
별도 백그라운드 시스템을 추가하지 않는다. 이미 구현된 단일
`ActiveRaidSummary → LazyCycleReconciler → advanceCycle` 흐름에서 실패 지점을 확인하고 그 한
곳만 바로잡는다. 방의 회차 계산, 승계 Transaction, 파티장 권한과 참가자 state 생성 규칙은
가능한 한 기존 구현을 그대로 사용한다. 기존 구조 때문에 여러 연결 지점을 고쳐야 한다면 직접
영향 구간은 함께 수정하되, 동일 판정을 화면·Repository·Rules에 각각 새로 복제하지 않는다.

**포함 범위:**

1. `ActiveRaidFilterViewModel`이 이미 수행하는 회차 분류에서 `expiredRecurring` ID·revision·방장
   여부를 별도 후보로 보존한다. 현재 회차 방 전체를 reconciler에 보내지 않는다.
2. 기존 `LazyCycleReconciler`의 반환 결과를 ID와 함께 소비해 최초 실패 종류를 남긴다. 이 확인을
   위해 새 Firestore 읽기나 쓰기, event 문서 또는 운영용 상태 필드를 추가하지 않는다.
3. 현재 Player가 모집의 방장인 만료 반복방에만 기존 방장 전용 승계 명령을 시도한다.
   파티원에게 새 권한을 주거나 Rules 조건을 완화하지 않는다.
4. 같은 `ID + 목표 회차 + revision`의 중복·실패 반복 호출을 합친다. 여러 후보는 한꺼번에
   무제한 실행하지 않는다.
5. 확인된 실패가 원본 모집·참가 state·listing·Rules 중 한 곳의 실제 불일치이면 기존
   `advanceCycle` Transaction 안에서 그 직접 원인만 수정한다. 별도 복구 Transaction을 만들지
   않는다.
6. 승계 성공 뒤에는 현재 목록 필터와 상세 화면이 갱신된 원본 데이터를 받아 기존 방식으로
   표시·동작한다.

**독립 문제로 분리할 범위:** 아래 항목은 이번 결함과 직접 인과관계가 없다는 확인 없이 단순히
무시하지 않는다. 조사 결과 직접 원인이거나 F6-I 수정으로 깨지는 구간이면 필요한 범위에 포함하고,
그렇지 않은 독립 문제일 때만 별도 작업으로 유지한다.

- 후보 발견을 위한 신규 `raidListings` listener·추가 recruitment N건 조회
- 원인과 무관한 `raidListings` 전체 스키마 재설계, 전체 Snapshot 일괄 복구 또는 과거 문서 migration
- Cloud Functions, 예약 실행, 전역 `recruitments` 순회와 유료 플랜 기능
- 방장이 앱을 실행하지 않아도 서버가 자동으로 회차를 넘기는 기능
- 파티원에게 `advanceCycle` 권한 부여, 기존 Rules 권한·소유권·완료 조건 완화
- 그룹방 직접 재가입 1,000식 문제와 재설치·원정대 소유권 이전 고아 정리

**구조 선택 기준:**

- 만료 반복방 판정은 기존 공용 회차 정책 한 곳을 사용한다.
- 레이드 현황의 기존 원본 모집 snapshot을 후보 입력으로 사용하고, 최종 상태 판정과 쓰기는 기존
  승계 Transaction 한 곳에서 수행한다.
- 기존 listing 불일치가 승계 누락의 직접 원인으로 확인되면 필요한 동기화는 같은 승계
  Transaction 안에서 처리한다. 이를 피하려고 후처리·재시도용 별도 상태를 추가하지 않는다.
- Rules 변경이 필요 없다고 미리 단정하지 않는다. 기존 승계 쓰기 계약과 실제 쓰기가 다르면
  그 불일치만 수정하고 권한·소유권·완료 조건은 유지한다.
- 영향 분석에서 발견한 회귀는 숨기거나 범위 밖으로 밀어내지 않는다. 현재 수정의 직접 결과이면
  같은 구간에서 해결하고, 독립 결함이면 근거와 사용자 영향을 기록해 별도로 결정한다.

**기존 기능 보호:**

- 현재 회차 방은 후보가 아니므로 아무 쓰기도 하지 않는다.
- `continueTogether=false`인 1회성 방은 F6-F의 `incompleteEnd` 경로를 그대로 사용한다.
- 공개 반복방의 기존 발견·승계 경로는 변경하지 않는다.
- 만석, 모집 일시 중단과 이번 회차 완료 여부는 화면 노출 조건일 뿐, 이전 회차 반복방을
  발견하는 조건으로 재사용하지 않는다. 최종 승계 가능 여부는 원본 모집과 기존 Transaction이
  판단한다.
- 승계는 기존 계약의 모집 문서·참가자 `raidState`·그룹 listing 원자 경계를 따른다. listing
  불일치가 이번 승계 실패와 무관하다고 확인된 경우에만 전면 정합성 수정은 분리한다.

**최소 검증:**

1. 만료된 그룹 반복방이 기존 active snapshot에서 승계 후보로 전달되고 결과가 유실되지 않는다.
2. 현재 회차 방은 보정 호출 대상이 아니며, 그룹 1회성 방은 기존 F6-F 경로만 사용한다. 공개
   반복방은 동일 공용 후보 판정을 계속 사용한다.
3. 비방장 사용자는 승계 쓰기를 시도하지 않는다.
4. 같은 방·회차·revision이 목록 갱신으로 여러 번 발견되어도 실패 요청까지 반복 실행되지 않는다.
5. 사용자 실기기에서는 그룹 반복방 한 건으로 경계를 넘긴 뒤 `i` 표시, 그룹 모집 목록 노출,
   Character 변경·자리 이동·추방·완료를 확인한다. 공개 반복방과 1회성 방 전체 조합을 다시
   반복 테스트하지 않는다.

**완료 조건:** 그룹 반복방의 기존 승계 호출이 성공하고, 승계 후 기존 기능과 직접 영향 구간이
정상 작동하는 것을 확인한다. 현재 회차 방에 대한 불필요한 원본 재조회와 같은 실패 요청의 반복
Rules 평가가 늘지 않아야 한다. 기존 구조상 필요한 연결 수정은 누락하지 않되, 새 데이터 모델·
새 권한·새 백그라운드 처리처럼 구조를 더 복잡하게 만드는 선택이 정말 필요해지면 우회 구현을
추가하지 않고 근거와 대안을 먼저 검토한다.

#### 후속 백로그 — 안전한 테스트 데이터 정리 도구 (F6 범위 밖)

참고: [`BUG_REPORTS.md`](BUG_REPORTS.md) 고아 `raidState`와 콘솔 단독 삭제 이력, [`PARTY_GROUP_COMMAND_SCALABILITY_REDESIGN.md`](../architecture/PARTY_GROUP_COMMAND_SCALABILITY_REDESIGN.md) 원자 명령·후처리 경계.

사용자가 콘솔에서 모집 문서를 단독 삭제하면 개인 점유·신청 참조가 남을 수 있다. 전체 Firebase 초기화는 이번 복구 방법이 아니다. F6-D는 본인이 화면에서 마주친 단일 고아 참가 상태만 서버 재검증 후 복구한다. 여러 Player·Character의 고아 상태와 해산·삭제된 부모 아래 남은 pending 신청을 찾고 일괄 정리하는 운영 도구는 별도 작업으로 유지한다. 연결 문서 목록의 읽기 전용 진단, 대상별 백업·미리보기, 명시적 확인, 제한된 정리와 사후 무결성 검사를 설계하며 그룹·인증·Character 등 무관한 데이터는 지우지 않는다.

### F7. 최종 통합 판정

참고: [`PARTY_GROUP_COMMAND_SCALABILITY_REDESIGN.md`](../architecture/PARTY_GROUP_COMMAND_SCALABILITY_REDESIGN.md), [`BUG_REPORTS.md`](BUG_REPORTS.md), [`DEV_LOG.md`](DEV_LOG.md), [`TASK-11-FIRESTORE-RULES-COMPLEXITY.md`](TASK-11-FIRESTORE-RULES-COMPLEXITY.md).

- F1~F6 리메이크의 각 단계에서 이미 통과한 표적 자동·Rules Emulator·실기기 UX 검증을 다시 반복하지 않는다.
- F7은 최종 코드·Git·문서 상태를 대조하고, 과거 미확인 표기와 실제로 남은 항목만 분리한다. 코드가 바뀌지 않았다면 전체 `flutter test`·전체 `flutter analyze`·전체 Rules Emulator·실기기 통합 회귀를 새로 실행하지 않는다.
- 본인 즉시 가입 D5 고아 복구 UX처럼 아직 확인되지 않은 독립 항목만 필요한 최소 실기기 확인으로 남긴다.
- 미해결 항목이 있으면 기능 브랜치를 유지하며 `dev`·`main`·release를 움직이지 않는다.
- 남은 항목을 확인한 뒤 문서 완료 이력을 `DEV_LOG`로 옮기고 최신 `dev`에 통합한다. 새 release는 그 이후 별도 결정한다.

**F7 대조 결과(2026-09-21):**

- 본인 즉시 가입은 `FirestorePartyAtomicJoinCommandRepository.joinDirectly`가 D5의 공용 점유 판정을 통해 현재/이전 주차 고아를 `orphanedParticipation`으로 반환하고, 모집 상세가 일반 신청과 같은 `_offerOrphanCleanup`으로 연결한다. 정리 후 즉시 가입을 자동 재실행하지 않는 기존 계약도 유지한다.
- D5 수명 판정·Rules 경계는 기존 표적 검증과 demo Actions `35494192803`에서 통과했고, 신청 경로의 같은 정리 UX는 사용자가 실기기에서 확인했다. 즉시 가입 전용 통합 테스트는 반복하지 않는다.
- 과거 전체 Flutter 실패 17/13건과 Rules CLI 503은 `DEV_LOG`의 당시 진단 이력으로 유지한다. F7에서 재실행하거나 현재 기능 결함으로 재분류하지 않았다.
- 운영 Rules 활성 소스 해시는 AI가 독립 대조하지 않은 운영 근거로 남긴다. 이후 Rules를 바꾸지 않았고 Rules 의존 실기기 흐름이 통과했으므로 `dev` 통합을 막는 신규 결함으로 보지 않는다.
- 현재 브랜치는 `dev` 시점을 포함하며 `dev` 전용 미병합 커밋은 없다. `main`의 별도 merge 커밋은 이 기능 브랜치의 통합 기준이 아니며 `main`·release 단계에서 별도 대조한다.

## F8 — 레이드 현황 기록 정리

### F8-A 승인 대기 고아 신청 실제 삭제

목적은 일반 신청 이력을 임의로 숨기는 것이 아니라, 모집 원본이 없거나 더 이상 신청을 처리할 수 없는 상태인데 `applications/{playerId}`만 남아 `신청 중` collection group 조회에 계속 나타나는 고아 문서를 사용자가 직접 정리하는 것이다.

- 활성 모집의 `pending` 신청은 삭제하지 않는다. 기존 상세의 `신청 철회` 명령을 사용한다.
- 삭제 대상은 현재 Player가 신청자인 문서이면서 부모 모집이 존재하지 않거나 `completed`, `disbanded`, `incompleteEnded`인 경우로 제한한다.
- Rules가 삭제 시점의 신청 소유권과 부모 모집 상태를 직접 검증한다. 클라이언트의 화면 판정만으로 삭제를 허용하지 않는다.
- 성공하면 application 원본이 삭제되어 collection group 목록에서도 사라진다. 모집 Aggregate, 멤버, `raidState`, 주간 완료 기록과 공용 이벤트는 쓰지 않는다.
- 활성 모집과 동시에 상태가 바뀐 신청은 Rules가 삭제를 거절한다. 실패를 성공처럼 숨기거나 로컬 tombstone으로 덮지 않는다.
- 화면은 각 신청 카드에서 고아 정리를 실행할 수 있어야 한다. 정상 pending에는 철회를 안내하고, 고아 정리 실패 시 해당 항목을 유지한다.

검증은 Rules 계약의 본인+부모 없음/종료 삭제 허용, 활성 부모·타인 신청 삭제 거절과 Repository 매핑만 자동화한다. 정상 화면 흐름은 사용자가 실기기 한 사례로 확인한다. Rules가 변경되므로 계약 검사와 게시본 대조 후 별도 게시 절차를 따른다.

**완료(2026-09-21):** 신청 카드의 명시적 확인 UI, 단건 삭제 Repository와 Rules 검증을 구현했다. 변경 파일 분석, Rules 문자열 계약, 레이드 현황 Widget 테스트가 통과했다. GitHub Actions demo Emulator `35529627164`에서 부모 없음·종료 부모의 본인 삭제 허용, 활성 부모·타인 삭제 거절과 기존 파티·그룹 전체 회귀가 통과했다. 추적 Rules SHA-256은 `6691D744E2D816D2618F1C8B2C8EFF7CB1C607F09CC238A11AE955C57583310B`다. 사용자가 같은 Rules를 Firebase 콘솔에서 직접 게시하고 실기기에서 고아 신청 삭제가 정상 작동함을 확인했다. 활성 게시 소스 해시는 AI가 독립 대조하지 않았지만 기능 인수 결과를 근거로 F8-A를 완료 처리한다.

### F8-B 완료 기록 삭제 — 폐기(2026-09-21)

완료 기록을 별도로 삭제해야 할 제품상 이유가 현재 없다고 재판단해 이 구간을 폐기한다. 삭제 UI, 로컬 tombstone, 데이터베이스 마이그레이션과 서버 이벤트 삭제는 구현하지 않는다. 기존 `숨기기/다시 표시`와 로컬 정정 기능은 그대로 유지하며, 향후 실제 사용자 문제와 삭제 요구가 확인될 때에만 별도 신규 작업으로 다시 설계한다.

## 실패 조사 시 필수 근거

각 실패마다 아래만 기록하고 추측 패치를 시작하지 않는다.

```text
기능 / 계정 역할 / recruitmentId 또는 groupId
명령 직전 schemaVersion·revision·status·visibility
앱이 계획한 읽기·쓰기 문서 경로
Firebase 오류 code·단계와 첫 실패 로그
관련 Rules 허용 분기와 get/exists/getAfter 수
같은 빌드에서 보존 확인한 선행 정상 흐름
```

## 제외 범위

- 원자 Aggregate·`raidState` 구조 폐기 또는 legacy 쓰기 복원
- Cloud Functions·유료 서버 도입
- 16인 공격대 선행 구현
- 파티·그룹과 무관한 UI 개편
- 실기기 근거 없이 D1~D9를 완료 처리
- 복구가 끝나기 전 `dev`·`main` 통합 또는 release 생성

## 현재 설계 단계 완료 조건

- D1~D9와 이전 정상 기능을 빠짐없이 복구 묶음 F1~F6에 배치한다.
- 각 묶음의 원인 조사 순서, 수정 경계, 자동·실기기 완료 조건이 정의된다.
- 미추적 백업·Rules 테스트의 용도를 분류한다.
- 기능 코드와 Rules를 수정하지 않은 상태로 사용자 승인을 받는다.
