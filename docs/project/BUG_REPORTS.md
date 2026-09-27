# 버그 리포트

## BUG-009. 신규 그룹의 멤버 목록·상세 전투력 누락

- 보고: 2026-08-31. 레이드·그룹 생성/초대/탈퇴/코드 가입 및 Rules 배포는 정상이나, 새 그룹의 본인·그룹원 전투력이 보이지 않는다. 기존 그룹 하나에서는 표시된다.
- 상태: **종료**. codex/group-combat-power-display에서 구현·자동 검증 후 사용자가 그룹원 간 전투력 표시의 정상 작동을 확인했다. 원래 증상의 단일 원인을 운영 데이터로 확정한 것은 아니다.
- 확인된 코드 경로: 프로필 전투력이 없을 때 저장 세팅 fallback 없음, 상세 목록이 읽는 Character.combatPower 저장 경로 없음, self-refresh 예외 은폐 및 로컬 null 덮어쓰기 가능.
- 수정: 저장 세팅 fallback·소유 필터, 소유 Character별 전투력 보강 Gateway, membership 숫자 보존, 실패 안내, 중복 요청 차단.
- 검증: 전체 테스트 666개·analyze 통과, 사용자 실기기 정상 확인(2026-08-31). 전투력 수정에서 Rules 변경·배포 없음. 사용자 지시로 커밋·main 머지 커밋·푸시를 진행한다.

실기기·사용 중 발견한 결함을 기록한다. 즉시 수정 범위가 아니면 여기에 남기고, 수정 착수 시 `NEXT_WORK.md`에 작업으로 올린다.

작성 규칙:

- 재현 절차, 기대/실제 결과, 추정 원인을 구분한다.
- AuthUid·토큰·민감 ID는 적지 않는다. 계정·캐릭터는 사용자가 말한 표시명만 쓴다.
- 수정·재현 불가·보류 상태를 이슈마다 갱신한다.

---

## BUG-022. 앱 재설치·동일 원정대 재인증 후 그룹 모집 관리 권한 오류

| 항목 | 내용 |
| --- | --- |
| 상태 | 진행 중 — A1·A2 및 F6-F 운영 확인. F6-G 참가 Character 변경 고아 점유 복구 실기기 성공; F6-F 반복방·현재 주차 회귀 확인 전 |
| 보고일 | 2026-09-23 |
| 관련 화면 | 그룹 전용 파티 모집, 참가자 추방·탈퇴, 모집 해산 |

### 보고 시나리오

1. 동일 디바이스에서 앱 데이터 삭제 또는 앱 재설치로 Firebase 익명 사용자가 바뀐다.
2. 기존에 사용하던 동일 원정대를 새 Player에서 다시 인증한다.
3. 그룹 생성, 타인의 가입 신청 승인과 방 생성은 성공한다.
4. 특정 그룹 모집에서 참가자 추방·탈퇴 또는 방 해산을 실행하면 권한 확인 실패 안내가 표시된다.

### 확보한 사실

- 앱은 Firebase 익명 Auth UID가 없으면 새 익명 UID를 만들고, 해당 UID의 `authBindings`가 없으면 새 `PlayerId`를 생성한다. 앱 데이터 삭제·재설치 뒤에는 기존 Player가 자동 복구되지 않는다.
- 원정대 재인증은 `gameAccounts.ownerPlayerId`, 소속 `characters.ownerPlayerId`와 `playerGameAccounts` 소유 상태를 새 Player 기준으로 갱신한다. 기존 Player의 그룹·모집·신청·`raidState` 전체를 이전하거나 정리하지는 않는다.
- 제보 모집은 재인증 후 현재 Player가 방장이며, 모집 Aggregate·3개 membership·3개 `raidState`의 Player/Character/raid/cycle/recruitment 연결이 서로 일치한다. 신청 승인도 성공했으므로 이 방의 기본 소유권과 참가 구성은 정상 범위다.
- 디바이스 로그에는 해산 시 `PartyAtomicLifecycle permission-denied`, 참가자 제거 시 `PartyAtomicMemberRemoval permission-denied`가 각각 기록됐다. 두 명령은 서로 다른 Rules 경로다.
- 제보 모집의 `groupActiveRecruitmentCountAfter`는 생성 당시 값 `5`이고, 명령 당시 그룹의 `activeRecruitmentCount`는 `17`이다.

### 최초 권한 오류에서 확정된 직접 원인

#### A. 그룹 모집 해산

- Repository는 Transaction에서 현재 그룹 count `17`을 읽어 `16`으로 감소시키고, 모집의 `groupActiveRecruitmentCountAfter`도 `16`으로 쓴다.
- Rules `atomicValidGroupLifecycleCount`는 동시에 변경 후 값이 모집의 기존 Snapshot `5 - 1 = 4`여야 한다고 요구한다.
- 동일 쓰기가 `16`과 `4`를 동시에 만족할 수 없으므로 이 데이터에서 해산은 확정적으로 거절된다.
- 이는 여러 그룹 모집을 만든 뒤 과거에 생성한 방을 닫는 일반적인 순서에서도 발생할 수 있다. 재설치 여부와 무관하게 재현 가능한 계약 결함이다.

#### B. 그룹 모집 참가자 추방·탈퇴

- Repository는 모집·membership·대상 `raidState`를 변경하면서 `groups/{groupId}/raidListings/{recruitmentId}`의 `memberCount`, `sourceRevision`, `updatedAt`도 함께 갱신한다.
- 모집 Aggregate의 참가자 제거 Rules는 존재하지만, `raidListings` update allow에는 참가자 제거 명령을 검증하는 분기가 없다.
- 기존 허용 분기는 개인 완료, 전체 Snapshot 동기화, lifecycle, 공개 범위 전환뿐이므로 위 3필드 부분 갱신은 거절된다.
- 따라서 제보 데이터의 Player 소유권과 무관하게 그룹 전용방 추방·탈퇴 Transaction이 실패한다.

### 현재 결론과 미확정 범위

- 최초 조사 시점의 해산·추방 `permission-denied`는 위 두 Rules 계약 불일치로 각각 설명됐다. 이후 A1/A2 게시 뒤 추방은 성공했지만 지난 주차 방 해산은 계속 실패했고, 아래 운영 콘솔 대조로 별도의 `raidState` 수명주기 충돌이 추가 확인됐다. **재설치 자체를 어느 실패의 직접 원인으로 단정하지 않는다.**
- 다만 새 Player로 원정대 소유권만 이동하고 이전 Player의 활성 파티 상태를 정리하지 않는 구조는 별도의 고아 데이터·점유 충돌 위험이다. 이 구조적 문제는 BUG-022의 직접 수정과 섞지 않고 후속 계정 복구 정책으로 분리한다.
- 이전·현재 AuthUid, 이전 Player의 활성 모집·신청·`raidState` 원본은 아직 대조하지 않았다. 이 자료 없이 과거 Player 데이터가 이번 방에 영향을 줬다고 기록하지 않는다.
- demo Emulator production Rules에서 오래된 count `17 → 16`, 위조 count와 그룹 갱신 누락 거절, 그룹방 추방·본인 탈퇴·listing 위조 거절은 통과했다. 탈퇴 직후 그룹방 직접 재가입은 원자 요청 전체 1,000식 한도로 실패했고, 여러 비용 축소 시도가 효과 없어 모두 되돌렸다. 이 재가입 결과는 별도 작업 C의 실패·원복 이력이다. 이후 A1/A2 Rules는 운영에 게시됐고 A2 추방이 실기기에서 확인됐으나, C 재가입과 아래 F6-F 종료 문제는 완료되지 않았다.

### 2026-09-25 운영 콘솔 대조 — 지난 주차 방 종료가 남은 이유

- 기존 문제 방 `5BCRsQkPRDvje1DrllEM`은 `지평3단 모집`, 그룹 `toAqIvr7zw0XSshhsP9v`, `continueTogether=false`, `status/currentCycleStatus=active`, `currentCycleKey=2026-09-16`, 종료 시각 2026-09-23 06:00 KST다. 추방 성공 뒤 `memberCount=2`, `revision=6`, 모집의 그룹 count Snapshot은 `5`로 남아 있다.
- 같은 그룹의 기존 `zxrz7IKQxq3Q386cktp8`은 `세르카/나이트메어`, 같은 방장 Character, `continueTogether=false`, 같은 지난 주차와 `active` 상태이며 모집의 그룹 count Snapshot은 `6`이다.
- 사용자가 현재 주차에 연속 생성한 대조 방은 공개 지평 방 `bDxr3PCcZo6j1HcVa7PN`과 그룹 세르카 방 `tVzXqc9VKIoszI3R9i8x`다. 둘 다 `currentCycleKey=2026-09-23`이고 2026-09-25 21:44 KST경 정상 해산됐다. 따라서 두 기존 방의 잔류는 “같은 레이드를 연속 생성해서 생긴 한 방의 중복”으로 보지 않는다.
- 현재 지평 방 해산 후, 같은 Character·레이드의 결정적 `raidState` 문서가 존재하지 않는 것을 콘솔에서 직접 확인했다. 반면 기존 지평 방은 생성 당시의 동일 state ID를 `raidStateTargets`에 계속 보존한다. 세르카 역시 기존 방과 현재 주차 대조 방이 같은 결정적 state 경로를 공유하므로 과거 방 종료가 그 경로의 존재·소유 모집을 가정해서는 안 된다.
- 현재 일반 해산은 모집의 모든 `raidStateTargets`를 삭제 대상으로 만들고 Repository가 사전 상태 대조 없이 삭제한다. Rules는 삭제 대상의 기존 데이터가 `active`이며 해당 모집을 가리키는지 확인하므로, 대상이 이미 없거나 이후 모집을 가리키면 전체 해산 Transaction이 거절된다.
- 그러므로 A1의 그룹 count `현재 N → N-1` 수정은 필요했고 운영 게시됐지만, 그것만으로 지난 주차 방의 해산을 완료했다고 판정할 수 없다. A2 추방 성공은 별도 listing 수정이 작동한 근거다. 남은 종료 실패는 만료 1회성 방을 정상 해산 경로로 처리하면서 참가자 state 삭제까지 요구하는 독립 수명주기 결함이다.
- 수정 범위는 F6-F로 제한한다. 만료 1회성 방을 `incompleteEnded`로 전환하고 진행 중 목록에서 제외하되 참가자 `raidState`는 읽기 전제나 쓰기·삭제 대상에 넣지 않는다. 반복방, 현재 주차 방, 정상 완료·해산·추방·자리 변경의 조건과 쓰기 순서는 변경하지 않는다.

### 초기 분석 순서의 현재 판정

1. 오래된 모집 Snapshot과 현재 그룹 count 충돌은 A1 fixture로 재현·검증했고 운영 Rules 게시까지 진행했다.
2. 그룹 전용방 참가자 제거의 listing 거절은 A2 fixture로 재현·검증했고 운영 게시 뒤 기존 문제 방 추방 성공을 확인했다.
3. 공개방 대조와 위조 listing 거절은 자동 검증에 포함했다.
4. 재설치 전·후 Player 전체 승계 대조는 직접 권한 수정과 분리하고, 동일 사용자 복구와 타인 소유권 이전 stale 정리를 통합 작업 그룹 DE로 관리한다. DE는 개발자 UX 결정 게이트를 먼저 거치며 F6-F 완료 조건이 아니다.
5. 그룹방 탈퇴 후 재가입의 1,000식 한도는 작업 C에서 해결되지 않아 원복됐다. F6-F는 재가입 조건이나 권한을 변경하지 않는다.
6. F6-F 화면 분리와 `raidState` 비의존 원자 종료 구현·표적 검증은 2026-09-26 완료했다. CLI는 `/rulesets` 503을 반환했지만 콘솔 신규 게시와 기존 문제 방 `5BCRsQkPRDvje1DrllEM`의 revision `6 → 7`, `active → incompleteEnded`, `lastCommandType: incompleteEnd` 전환으로 실제 운영 반영을 확인했다. 생성 당시 `raidStateTargets`는 보존됐고 그룹 count 결과는 과거 Snapshot `5`가 아닌 현재 기준 `10`으로 기록됐다. 남은 직접 확인은 반복방 승계, 현재 주차 무변경과 미완료 종료 이력 노출이다.

### 2026-09-27 실기기 재현 — 참가 Character 변경의 점유 판정 불일치

- F6-F 운영 반영 뒤 현재 주차 AILKER 지평의 성당 3단계 방을 새로 생성했다. 다른 사용자의 신청·참가 전이고 진행 중 화면에도 해당 방 하나만 보이는 상태에서 방장 참가 Character 변경을 시도했으나 `다른 확정 참가와 충돌합니다. 캐릭터를 다시 선택해 주세요.`가 표시됐다.
- 화면에 다른 방이 보이지 않는다는 사실만으로 점유 원본 부재를 단정하지 않는다. 현재 코드 대조 결과 후보 조회는 새 Character의 `raidState`와 연결 모집을 읽어 종료 모집의 state를 교체 가능한 고아로 분류하지만, 최종 변경 Transaction은 새 state가 존재하면 현재 주차 완료 이외의 모든 경우를 `participationConflict`로 처리한다.
- F6-F는 과거 모집 종료 시 참가자 state를 무차별 삭제하지 않도록 의도적으로 보존했다. 따라서 해결은 F6-F 종료 명령에 state 삭제를 다시 넣는 것이 아니라, 참가 Character 변경의 후보와 최종 Transaction이 기존 공용 점유 분류를 공유하도록 맞추는 F6-G다.
- 고아로 확정된 경우 변경 Transaction은 쓰지 않고 정확한 state 식별자를 반환하며, 기존 신청·즉시 가입의 단일 고아 정리 명령과 확인 UX를 재사용한다. 정리 후 변경은 자동 재실행하지 않고 사용자가 다시 시도해 최신 조건을 재검증한다.
- 현재 활성 다른 방 참가, 현재 주차 완료, 만료 반복방, 더 새 모집이 소유한 state와 불명확한 연결은 기존처럼 보존·차단한다. 전체 데이터 순회, 자동 덮어쓰기, 과거 방 일괄 삭제와 권한 완화는 범위 밖이다.
- 상세 단계와 완료 조건은 [`NEXT_WORK.md`](NEXT_WORK.md)의 `F6-G` 및 [`FIRESTORE_PARTY_COMMAND_CONTRACT.md`](../architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md) §4.7을 따른다. 2026-09-27 공용 점유 판정·명시적 고아 결과·기존 정리 UX 연결을 구현하고 표적 검증을 통과했다. Rules는 변경하지 않았다. 사용자가 실제 문제 흐름에서 정리 안내를 확인하고, 정리 실행 뒤 Character 변경을 다시 시도해 정상 성공했으므로 F6-G는 완료한다.

### 초기 확정 수정 설계 — A 운영 게시, B 별도 유지

직접 권한 오류와 원정대 이전 후 고아 상태를 두 작업 그룹으로 분리한다.

#### A. 직접 Rules 결함

- 해산 count는 모집 생성 당시 Snapshot이 아니라 Transaction의 현재 그룹 원본 전후 `N → N-1`을 검증하고, 변경 후 모집 count를 변경 후 그룹 count와 일치시킨다.
- 그룹 listing에는 참가자 제거 전용 update validator를 추가한다. 모집 원본의 정상 참가자 제거 명령과 같은 Transaction일 때만 `memberCount`, `sourceRevision`, `updatedAt` 세 필드 변경을 허용하고 변경 후 모집 값과 일치시킨다.
- 오래된 그룹방 닫기, 그룹방 추방·탈퇴·재가입, 공개방 대조, 위조 count/revision/listing과 비방장 명령 거절을 Emulator 회귀로 고정한다.
- Dart Repository의 현재 쓰기 형태는 계약에 맞으므로 A의 기본 변경 범위는 Rules와 회귀 fixture다.
- A1 count와 A2 참가자 제거는 게시됐지만, 그룹방 재가입은 작업 C 실패·원복으로 미완료이며 지난 주차 방 닫기는 F6-F로 분리됐다. 따라서 위 항목 전체를 A 완료로 묶지 않는다.

#### B. 원정대 소유권 이전 안전화

- 원정대 인증은 GameAccount·Character 소유권만 이전하며 그룹·모집·신청·완료 이력과 파티장 지위는 새 Player로 자동 승계하지 않는다.
- 앱 재설치 후 같은 LOSTPARTY Player를 복구하는 기능은 원정대 인증과 분리한다. 새 AuthUid의 기존 Player 재연결은 클라이언트 쓰기로 열지 않고 향후 신뢰 가능한 운영자·서버 명령으로만 설계한다.
- GameAccount·Character에 단조 증가하는 `ownershipRevision`을 두고 Character 기반 신청·membership·`raidState`에 생성 당시 revision을 기록한다. 소유권이 A→B→A로 돌아와도 과거 A 문서가 다시 활성화되지 않게 한다.
- 이전 revision의 신청은 승인 불가·명시적 무효화 대상으로, 활성 membership은 구성 점검·제한된 정리 대상으로 처리한다. stale 파티장이면 기존 승계 규칙을 적용하고 마지막 1인이면 해산한다.
- 이전 Player 전체를 동기 순회하거나 운영 데이터를 일괄 복사하지 않는다. B는 스키마·인증·명령·Rules 영향이 크므로 A 완료 후 별도 승인 작업으로 진행한다.

실행 순서와 완료 조건은 [`NEXT_WORK.md`](NEXT_WORK.md)의 `BUG-022` 수정 설계 구간을 따른다.

---

## BUG-021. 그룹 가입 신청 승인이 Rules 평가 한도로 실패

| 항목 | 내용 |
| --- | --- |
| 상태 | 종료 — Rules 게시 후 기존 실패 Player 2명 승인 확인 |
| 보고일 | 2026-09-21 |
| 관련 화면 | 그룹 가입 신청 승인, 직접 초대 수락, 초대코드 가입 |

### 재현 관찰

1. Player 1이 그룹을 만들고 Player 2·3을 신청 또는 초대로 가입시킨다.
2. Player 2는 가입되지만 Player 3은 `이 그룹에 가입할 수 없습니다.`가 표시된다. 요청 거절은 가능하다.
3. Player 3이 같은 그룹에 초대코드로 가입하면 성공한다.
4. 이전에 정상 승인됐던 Player 2도 새 그룹 재신청 승인에서 같은 증상이 발생했다. 이 Player도 빈 membership 문서가 `revision=6`으로 남아 있다.

### 현재 판단

- 같은 Player·그룹의 초대코드 가입이 성공했으므로 block, 정원, 그룹 비활성, 50개 가입 한도, Player/Character 활성·소유권과 전역 Rules 불일치는 가능성이 낮다.
- 표시 문구는 실제 block뿐 아니라 Firestore `permission-denied`에도 공용이므로 차단되었다는 증거가 아니다.
- 전달된 Player 3의 membership 요약은 빈 배열/count 0/revision 14로 서로 일치한다. 이번 사례의 우선 원인은 아니다.
- 재확인 결과 문제 그룹의 `application/pending` 신청 원본과 Player 3의 `groupRelations/{groupId}` Projection은 모두 존재하고 서로 일치한다. Projection 누락 가설은 폐기한다.
- Player 3의 membership은 빈 배열/count 0이지만 revision 14인 기존 문서다. 승인은 최초 create가 아니라 update Rules를 타며, 그룹장 승인 분기 앞에 일반 탈퇴·본인 가입 분기가 놓여 있다. 과거 같은 Rules OR 평가 순서에서 표현식 1,000개 초과가 반복됐고, 거절은 membership을 쓰지 않으며 초대코드는 본인 가입 분기에서 일찍 성공하므로 현재 현상을 함께 설명한다.
- Player 2도 빈 배열/count 0/revision 6인 기존 문서에서 동일하게 실패해 특정 계정 문제가 아니라 공통 승인 경로로 범위가 넓어졌다.
- demo Rules CI `35562516961`에서 membership 문서가 없는 최초 가입 승인도 `maximum of 1000 expressions`로 거절됐다. 현재 그룹 신청 승인 Transaction 전체가 Rules OR 순서 때문에 예산을 초과하는 회귀로 원인을 확정한다.
- 승인 Transaction이 쓰는 신청 원본, 멤버, membership 요약, Player Projection, 그룹 원본의 application 승인 validator가 각각 무관한 분기 뒤쪽에 있다. 보안 검사를 완화하지 않고 싼 명령 식별 guard와 승인 validator를 앞쪽에 배치하는 최소 Rules 수정이 필요하다.
- 해당 다섯 승인 분기를 값싼 guard와 함께 앞쪽으로 옮긴 뒤 Actions `35565203228`에서 최초 membership 생성 승인과 revision 14의 빈 membership 갱신 승인, 기존 그룹 전체 회귀가 통과했다. 사용자가 Rules를 게시한 뒤 기존에 실패하던 Player 2명 모두 정상 승인됐다.
- 신청 승인은 대상의 private membership 요약을 읽지 않고 배열 합집합·숫자 증가로 병합한다. 이번 데이터는 정상이지만 과거 데이터의 `activeGroupIds`, `activeGroupCount`, `revision` 불일치에 취약한 점은 별도 회귀 경계다.
- 초대코드 가입은 membership과 Player relation을 완성된 형태로 다시 써서 기존 불일치를 정상화했을 수 있다. 따라서 코드 가입 후 데이터는 실패 당시 원인을 보존하지 않을 수 있다.
- 직접 초대 수락까지 동일하게 실패했는지는 최초 실패 동작과 서버 오류 code를 분리해 재확인한다. 신청 승인 실패와 한 원인으로 미리 묶지 않는다.

작업 브랜치 통합 상태는 [`NEXT_WORK.md`](NEXT_WORK.md)의 `BUG-021` 작업 구간을 따른다.

---

## BUG-001. 모집 생성 후 상세가 다른 방(A)을 보여 줌

| 항목 | 내용 |
| --- | --- |
| 상태 | 종료 (수정됨) |
| 보고일 | 2026-08-26 |

상세 `recruitmentId` 변경 시 State·구독이 따라가지 않아, 방 A 상세 후 방 B 생성 시 A가 남을 수 있었다. `ValueKey`·`didUpdateWidget`/`restart`로 수정했고, 정상 스텝 실기기에서 통과 확인 후 종료.

---

## BUG-002. 목록은 4인 노말인데 상세·구성은 8인 공격대처럼 보임

| 항목 | 내용 |
| --- | --- |
| 상태 | 종료 간주 (현재 재현 없음, 재발 시 재개) |
| 보고일 | 2026-08-26 |
| 심각도 | 중간 — 표시·슬롯 해석 불일치, 가입 판단에 영향 가능 |
| 관련 화면 | 레이드 모집 공개 목록, 현황/모집 상세 구성판 |

### 재현에 가까운 절차

1. **이슈** 계정·**이슈** 캐릭으로 특정 던전 방 생성.
2. **곰** 계정·**곰곰** 캐릭으로 같은 파티 참가.
3. 이슈 캐릭이 탈퇴 → 곰곰 캐릭에 파티장(책임자) 위임.
4. 모집 리스트와 실제 참가/상세 구성을 비교.

### 기대 결과

목록·상세·구성판이 같은 정원·파티 구조(예: 4인 노말 1파티)를 보여 준다.

### 실제 결과

- 파티 모집 리스트: **4인 파티 노말**처럼 표시.
- 실제 참가/상세 쪽: **8인 공격대의 다른 파티**처럼 보임.

고정 슬롯·구성판(Task-068/069) **이전**에 만든 방인지, 승계·탈퇴·재생성과 겹친 결과인지는 **미확인**.

### 추정 원인 (가설)

구성판 파티 수는 `ceil(maxMemberCount / membersPerParty)`다. Mapper는 `membersPerParty`가 없으면 **4로 기본값**을 넣는다.

| Firestore | 목록/사용자 체감 | 구성판 |
| --- | --- | --- |
| max=4, perParty=4 (또는 없음→4) | 4인 | 1파티 |
| max=8, perParty=4 (또는 없음→4) | 8자리 구조 | **2파티(공격대처럼)** |

목록 Card가 정원·파티 수를 약하게 보여 주면 “4인 노말”로 읽고, 상세만 8칸 보드로 보일 수 있다. 레거시 방·잘못된 `maxMemberCount`도 같은 체감이 난다.

### 수정 방안

1. **데이터 확인 먼저:** 문제 방문서 `maxMemberCount`, `membersPerParty`, `raidId`를 Console에서 확인. 8/4면 표시는 “정상 동작”, 원인은 생성·카탈로그 불일치.
2. **표시 정합:** 목록과 상세에 같은 식의 정원 문구(예: `4인` / `8인(2파티)`)를 쓰고, `maxMemberCount != membersPerParty * partyCount`면 경고.

**코드만으로 “항상 버그”라고 단정하긴 이르다.** 문서 id 한 건의 필드 확인이 선행이다.

### 수정 메모

하단 탭 및 후속 파티 흐름 수정 뒤 같은 증상이 재현되지 않았다. 현재는 종료로 간주하며, 재발 시 새 방의 필드와 정확한 재현 절차를 첨부해 다시 연다.

---

## BUG-003. 회차 완료 후 완료 기록이 비어 보임 / 진행 중에서 사라져 해산 불가

| 항목 | 내용 |
| --- | --- |
| 상태 | 패치됨 |
| 보고일 | 2026-08-26 |
| 관련 | Task-071 |

1회성 완료 후 진행 중 목록에서 사라지고, 완료 기록에도 바로 안 보여 해산 경로가 끊겼다.

- 기록: 완료 직후·완료 기록 탭 sync 보강.
- 목록: `watchActiveRaids`에 `status in [active, completed]`를 넣어 해산 전 방을 **해산 대기**로 남김. 완료 기록의 로컬 미완료 정정은 Firestore 방을 복구하지 않는다.

---

## BUG-004. 하단 탭 전환 시 이전 상세 스택이 남음

| 항목 | 내용 |
| --- | --- |
| 상태 | 패치됨 |
| 보고일 | 2026-08-26 |

모집 탭 갔다가 현황으로 돌아오면 해산·종료로 비었어야 할 상세가 다시 열렸다. 탭 전환 시 브랜치 스택을 유지했기 때문이다.

패치: 탭 터치마다 `goBranch(..., initialLocation: true)`로 해당 탭 루트로 이동.

---

## BUG-005. 같은 레이드 회차 완료 후 재생성·재완료가 막히지 않음

| 항목 | 내용 |
| --- | --- |
| 상태 | Task-074~075 주간 Claim 작업에 흡수 |
| 보고일 | 2026-08-26 |

완료 → (해산) → 같은 레이드 재생성 → 다시 완료를 같은 주차에 반복할 수 있다. 원인은 서버 개인 주간 완료 Claim이 없는 것이다. 별도 임시 패치 대신 [`../architecture/WEEKLY_RAID_CLAIM_CONTRACT.md`](../architecture/WEEKLY_RAID_CLAIM_CONTRACT.md)와 Task-075 이후 단계에서 생성·신청·가입·교체를 함께 차단한다.

---

## BUG-006. 회차 완료·해산이 처음 1~2회 실패하다 이후 성공

| 항목 | 내용 |
| --- | --- |
| 상태 | 종료 간주 (현재 재현 없음, 재발 시 재개) |
| 보고일 | 2026-08-26 |

권한 확인 실패 후 재시도하면 성공하는 경우가 있었다. 이후 Transaction 읽기 후 쓰기 순서 수정과 실기기 검증 뒤 같은 증상이 재현되지 않았다. 재발 시 명령·방 상태·오류 코드를 새로 기록해 다시 연다.

---

## BUG-007. 반복 파티 완료·다음주 캐릭 변경·취소 반복 시 Claim/취소 꼬임

| 항목 | 내용 |
| --- | --- |
| 상태 | 보류 (정상·1차 복원 경로 밖, 심화 업그레이드 시) |
| 보고일 | 2026-08-28 |
| 관련 | Task-080 F |
| 심각도 | 낮음~중간 — 의도적 복잡 조작에서만 두드러짐 |

### 재현에 가까운 절차 (의도적 꼬임)

1. 계정1이 레이드방 생성, 계정2가 캐릭4로 참가.
2. 주간 반복 활성화 → 계정2 참가 캐릭을 3으로 변경 → 파티 전체 완료.
3. 다음주 구성에서 참가 캐릭을 4로 변경 → 전체 완료 취소.
4. 이번주 기준 캐릭을 다시 3으로 변경 → 재완료.
5. 이후 완료/완료 해제(취소)를 반복.

### 기대 결과 (정상 제품 경로)

- 완료 시 당시 membership 전원에 `partyOwner` Claim.
- 구성 변경 없이 마감 전 취소 시 Claim 삭제·assignment 복원·회차 복구.
- 다음주 prep 캐릭터 변경 후에는 **전체 완료 취소 거절**(계약).

### 실제 결과 (복잡 조작)

- 중간 시점부터 재완료 후 내 계정 체크가 안 생기거나, 완료 취소도 실패하기 시작함.
- 정상 사용·1차 실수 복원만으로는 필수로 막히지 않음.

### 추정 원인

- 완료는 **라이브 membership**, 취소는 **완료 Snapshot**을 본다. 캐릭 스왑·다음주 prep·재완료가 겹치면 identity(Claim 문서 키·revision·assignment)가 어긋날 수 있다.
- Task-080 F에서 다음주 prep(membership만)·재완료 orphan Claim 정리·취소 거절 안내를 보강했으나, **모든 비트는 순서의 전수 hardening은 범위 밖**으로 둠.

### 조치

- Task-080 F: 정상·1차 복원 경로와 1차 완화(다음주 prep·orphan 정리)까지 반영. Rules 재배포 완료.
- **심화 대응은 앱 심화 업그레이드 시** 이 이슈를 다시 연다. 당장 `NEXT_WORK` 현재 실행에는 올리지 않는다.

---

## BUG-008. Task-086 운영자 승인·분쟁·강제 인증 permission-denied

| 항목 | 내용 |
| --- | --- |
| 상태 | **종료 — 수정·Rules 배포·실기기 확인 완료** |
| 보고일 | 2026-08-29 |
| 심각도 | 높음 — 해결됨 |
| 브랜치 | `cursor/task-086-owner-defense` (미커밋) |
| 상세 문서 | [`TASK-086-OPERATOR-WRITE-BLOCKER.md`](TASK-086-OPERATOR-WRITE-BLOCKER.md) |

### 재현

1. `lost-party`에 Task-086 Rules가 배포된 상태에서 운영자 계정 로그인
2. `operatorAssignments/{playerId}`·`players/{playerId}`·`authBindings` 모두 active 확인
3. `수동 인증 확인` → 대기 요청 상세
4. **취소** → 성공
5. **승인**(무소유) / **분쟁 개시**(기존 소유자) / **강제 인증** → `PERMISSION_DENIED: Missing or insufficient permissions`

### 기대 결과

운영자가 취소·승인·분쟁 개시·강제 인증을 Rules와 계약대로 처리한다.

### 해결 결과 (2026-08-29)

일반 요청에 없는 선택 필드 `defenseOfRequestId`를 분쟁·강제 인증 Rules가 직접 읽어 평가 오류가 발생했다. 필드 존재 여부를 먼저 검사하도록 수정하고 `lost-party`에 배포한 뒤 일반 승인·분쟁 개시·강제 인증이 실기기에서 통과했다.

### 후속 확인

- 방어 승인·방어 실패·즉시 이전과 양쪽 레이드 권한 반영까지 실기기 확인했다.
- 실제 24시간 무응답 자동 이전만 미검증으로 남긴다.
- Java 부재로 Emulator Rules 통합 테스트는 실행하지 않았다.

---

## BUG-010. 정상 특수 보석 대상이 스킬 미확인으로 표시됨

| 항목 | 내용 |
| --- | --- |
| 상태 | **수정·자동 검증·주요 실기기 확인 완료** |
| 보고일 | 2026-09-08 |
| 심각도 | 중간 — 표기 오류 및 Build 검증 신뢰도 저하 |
| 기준 문서 | [`../architecture/CHARACTER_BUILD_INTEGRITY_CONTRACT.md`](../architecture/CHARACTER_BUILD_INTEGRITY_CONTRACT.md) |

### 재현과 실제 결과

- 발키리 support의 `신앙 스킬`과 바드 dealer의 `템페스트 스킬`이 `보석의 대상 스킬을 확인할 수 없습니다`로 표시됐다.
- 실제 API 진단을 확대해 홀리나이트 support `신앙 스킬`, dealer `심판자 스킬`, 도화가 support `음양 스킬`에서도 같은 카탈로그 공백을 확인했다.
- 바드 support `세레나데 스킬`, 발키리 dealer `종언의 빛`, 도화가 dealer `떠오르는 달`은 현재 카탈로그에서 정상 분류됐다.

### 확인된 원인

- 기존 4직업 fixture는 실제 API 실측이 아닌 사용자 제공 계약값이었고 `신앙`, `심판자`, `음양`처럼 실제 대상명의 `스킬` 접미사가 빠져 있었다.
- 바드 실제 fixture의 `템페스트 스킬`은 카탈로그 없는 호출에서 아이콘 fallback으로 통과했지만, 알려진 직업은 타 직업 오판 방지를 위해 fallback을 차단하므로 현재 카탈로그에서 unknown이 된다.
- 보석 대상명만으로는 발키리와 홀리나이트의 동일한 `신앙 스킬`을 구분할 수 있다. 실제 보석 Tooltip의 `[직업]`을 현재 Character 직업과 함께 비교해야 한다.

### 해결 결과

- 모든 직업의 전체 Build를 선행 수기 입력하지 않는다.
- 실제 확인된 특수 대상명을 교정하고 동일 직업·대상 미확인과 다른 직업 보석을 분리했다.
- 깨달음·아크그리드 기본 조건과 해·달 존재/14P 검사를 구현하고 자동·주요 실계정 검증을 완료했다.
- 파티 신청자와 membership 카드의 최소 보석 검증 Snapshot 전파를 완료했다. 그룹 membership 전파는 현재 `NEXT_WORK.md`의 별도 작업 그룹으로 진행한다.

---

## BUG-011. 주차 경계 후 미완료 종료·반복방 전환 상태 불일치

| 항목 | 내용 |
| --- | --- |
| 상태 | **당시 legacy assignment 범위 종료 — 현재 v2 `raidState`/Aggregate의 만료 1회성 종료는 BUG-022 F6-F로 구현·운영 전환 확인, 회귀 확인 전** |
| 보고일 | 2026-09-09 |
| 심각도 | 높음 — 새 레이드 생성 차단 및 반복 그룹방 노출 실패 |
| 기준 문서 | [`NEXT_WORK.md`](NEXT_WORK.md#2026-09-09-차후-작업--주차-경계와-레이드-회차-전환-전수-점검) |

### 실기기 보고

- 수요일 주차 경계 뒤 만료된 방에 `다음 회차 전환`이 노출됐다.
- 1회성 방을 미완료 종료해도 동일 Character·레이드의 새 모집방 생성이 계속 거절됐다.
- 반복 그룹방을 전환한 뒤 그룹원의 모집 목록에서 방이 보이지 않았고, 공개 범위 변경도 권한 확인 실패로 안내됐다.
- 사용자에게 `다음 회차 전환`과 `모집글 삭제·해산`이 사실상 같은 기능처럼 보였다.

### 우선 확인 결과

- 반복방 활성 승계와 1회성 미완료 종료 분기는 코드에 존재하며 제품 의도와 일치한다.
- 1회성 미완료 종료가 기존 `activeRaidAssignments`를 정리하지 않는 반면 새 방 생성의 stale 점유 교체 쓰기는 현재 assignment Rules update 계약과 맞지 않는다. 새 방 생성 차단의 우선 원인이다.
- 그룹 모집 목록은 빈자리까지 요구하므로 정원이 찬 반복방은 현재 계약상 표시되지 않는다. 빈자리가 있던 사례인지와 전환 후 listing 필드는 운영 데이터 대조가 필요하다.
- 닫힌 `incompleteEnded` 방은 공개 범위 변경 대상이 아니므로 현재 Repository가 이를 거절한다. 반복방이 닫혔다면 서버의 전환 직전 `continueTogether`부터 추적한다.
- KST 수요일 06시 값은 여러 정책과 로컬 경로에 중복 하드코딩돼 있으며 단일 테스트 설정으로 교체할 수 없는 상태다.

### 확정 기획 보정

- 주차 전환은 사용자가 상세에서 버튼을 누르는 방식이 아니다. KST 수요일 06시에 이전 주차의 미완료 회차가 자동 종료돼야 한다.
- 1회성 방은 종료 후 일반 목록에서 사라지고, 반복방만 같은 방·구성을 새 주차의 활성 회차로 자동 승계한다.
- 종료된 이전 회차는 어떤 경우에도 새 주차의 생성·신청·참가 점유를 막지 않는다.
- 현재 `다음 회차 전환` 버튼은 제거 또는 비노출 대상으로 변경한다.

### 해결 결과

- Spark 요금제를 유지하고 예약 서버 작업 없이 최초 접근 시 실행되는 방 단위 멱등 `LazyCycleReconciler`를 구현했다.
- 만료된 1회성 방은 미완료 종료하고 반복방은 현재 주차로 승계하며, 교체 가능한 과거 assignment가 새 생성·참가를 막지 않도록 정리했다.
- Rules 경고 0개와 실제 배포를 확인했고, 과거 미완료 종료 데이터가 있는 Character의 생성·참가 및 반복방 승계를 실기기에서 확인했다.
- 위 완료 판정은 당시 `activeRaidAssignments` 교체와 기존 lazy reconciliation 범위다. 이후 도입된 v2 모집 Aggregate·`raidStateTargets` 경로에서 만료 1회성 방이 `active`로 남고 정상 해산이 누락·재사용 state 삭제 때문에 거절되는 현상은 이 완료 근거에 포함되지 않는다. 현재 처리는 BUG-022의 F6-F를 따른다.

---

## BUG-012. 동일 레이드 다른 난이도 신청 후보에 확정 참가 Character가 노출됨

| 항목 | 내용 |
| --- | --- |
| 상태 | **수정·실기기 검증 완료** |
| 보고일 | 2026-09-10 |
| 심각도 | 높음 — 동일 Character·raidId 확정 참가 계약의 사전 안내 누락 |
| 기준 문서 | [`../product/PARTY_PARTICIPATION_RULES.md`](../product/PARTY_PARTICIPATION_RULES.md) |

### 재현

- Character로 4막 하드 모집을 생성해 확정 참가한다.
- 같은 Character로 4막 노말 등 동일 `raidId`의 다른 모집에 신청한다.
- 기존에는 신청 Character 선택 목록에서 제외됐지만 서버 점유가 있어도 다시 노출됐다.

### 원인과 수정

- 동일 레이드 충돌 정책은 난이도를 제외한 `characterId + raidId`로 정상 판정하고 있었다.
- 실제 앱 라우터가 후보 서비스에 Firestore의 `players/{playerId}/activeRaidAssignments` 대신 실행 중 비어 있는 인메모리 저장소와 `local-user` 세션을 연결해 서버 확정 점유를 읽지 못했다.
- 최초 수정에서 컬렉션 목록 조회를 연결했으나 Rules가 `get`만 허용하고 `list`를 금지해 모집 생성 정보 로딩이 `permission-denied`로 중단되는 후속 회귀가 발생했다.
- 목록 조회를 폐기하고 기존 canonical 문서 ID인 `{serverCharacterId}_{raidId}`를 이용한 정확한 문서 `get`으로 교정했다.
- 첫 개별 조회는 문서 존재만으로 차단해 과거 1회성 `incompleteEnded` assignment까지 현재 참가로 오판했다. 최종 생성·가입 명령과 같은 `LegacyEndedAssignmentReplacementPolicy`를 적용해 현재 주차·반복방 점유만 차단하고 교체 가능한 과거 미완료 종료 점유는 후보에서 허용하도록 다시 교정했다.
- 실제 `PlayerId`, 서버 Character ID와 `raidId`로 충돌을 판정하며 생성·신청 Transaction, Rules와 서버 스키마는 변경하지 않았다.

### 검증

- 동일 서버 Character ID가 하드에 점유된 상태에서 노말 신청 후보가 `동일 레이드 참가 중`으로 차단되는 회귀 테스트를 추가했다.
- 후보·과거 미완료 점유 정책 표적 테스트 10건과 변경 파일 정적 분석이 통과했다.
- 실기기에서 과거 1회성 미완료 종료 assignment가 남은 Character로 4막 하드 모집을 정상 생성했다. 동일 레이드 다른 난이도 신청 후보 차단은 다음 통합 확인에도 포함한다.

---

## BUG-013. 4인 파티에서 방장과 동일한 딜러 직업이 신청 후보에 노출됨

| 항목 | 내용 |
| --- | --- |
| 상태 | **종료 — 실기기 확인·`dev` 반영 완료** |
| 보고일 | 2026-09-10 |
| 심각도 | 높음 — 파티별 동일 딜러 직업 제한의 신청 사전 차단 누락 |
| 기준 문서 | [`../product/PARTY_PARTICIPATION_RULES.md`](../product/PARTY_PARTICIPATION_RULES.md) |

### 원인

- 카탈로그와 `PartyCompositionPolicy`는 4인 1파티의 동일 딜러 직업 상한을 1명으로 올바르게 정의한다.
- 모집 상세 신청 팝업은 현재 membership·파티 구성 없이 생성용 `RecruitmentLeaderCandidateService`를 호출해 방장과 신청 Character의 직업 중복을 판정할 수 없다.
- 최종 즉시 가입·승인 배치는 다시 검증하지만 승인 대기 신청 후보 단계에는 누락돼 있다. 이 경로는 최근 assignment 수정에서 제한을 제거한 것이 아니라 기존 신청 화면 연결의 검증 공백이다.

### 수정

- 상세 읽기 모델의 membership과 `PublicRecruitmentSummary.partyRules`를 신청·캐릭터 변경 후보 Query에 전달한다.
- 신청·즉시 가입 후보는 최종 가입과 같은 `PartyCompositionPolicy.assignEmptySlot`으로 판정한다.
- 캐릭터 변경은 자리 유지 `failureForInPlaceReplacement`로 membership 명령과 같은 파티 단위 제한을 적용한다.
- 모집 생성 후보는 membership을 넘기지 않아 기존 생성 흐름을 유지한다.

### 검증

- 표적·영향 자동 테스트와 변경 파일 analyze가 통과했다.
- 실기기: 4인 동일 딜러 직업 후보 미노출, 8인 동일 직업 2명 신청 허용을 확인했다.
- 8인 동일 직업 3번째 차단과 변경 가능 캐릭터 없음 알림은 자동 테스트로 고정했고 실기기 재확인을 남긴다.

---

## BUG-014. 장비 인증의 앱 종료 정책 안내 누락

| 항목 | 내용 |
| --- | --- |
| 상태 | **종료 — 자동 수정·실기기 확인 완료** |
| 보고일 | 2026-09-13 |
| 심각도 | 낮음 — 의도된 로컬 수명 정책을 사용자가 인증 전에 알기 어려움 |
| 기준 문서 | [`NEXT_WORK.md`](NEXT_WORK.md) |

### 확정 정책

- 인증 화면은 Gateway의 동기 `activeChallenge`를 읽어 같은 앱 수명 안의 화면 재진입만 복원한다.
- 실제 Challenge의 기준 장비·지정 부위·siblings·만료 시각은 `LocalGameAccountVerificationGateway._activeChallenge` 메모리에만 있다. 현재 Firestore에는 Challenge 문서가 없고 앱 프로세스가 종료되면 실제 데이터가 사라진다.
- 이는 현재 로컬 인증 방식의 의도된 수명 정책으로 유지한다. 앱 재시작 복원과 기기 보안 저장소 저장은 구현하지 않는다.

### 보완 방향

- challenge 진행 카드에 앱이 종료되면 남은 시간과 관계없이 현재 인증 시도가 종료된다고 알린다.
- 원정대 인증은 인게임에서 장비를 즉시 조작할 수 있는 상황에 진행하도록 권장한다.
- 같은 프로세스의 화면 재진입 복원과 다시 인증해 새 challenge를 만드는 기존 흐름은 유지한다.

### 수정 결과

- 진행 카드에 앱 종료 시 인증 종료와 인게임 즉시 조작 권장 문구를 추가했다.
- challenge 메모리 수명, 같은 프로세스 재진입 복원과 앱 재실행 후 새 시도 정책은 변경하지 않았다.
- 화면 Widget 테스트와 인증 Gateway 회귀 테스트를 통과했고 사용자가 실제 기기에서 안내 문구를 확인했다.

---

## BUG-015. 후보의 아크그리드 오류가 신청자·파티원 카드에서 사라짐

| 항목 | 내용 |
| --- | --- |
| 상태 | **종료 — 운영 소스 일치·실기기 확인 완료** |
| 보고일 | 2026-09-13 |
| 심각도 | 높음 — 신청 전 경고와 타인이 보는 신청·참가 정보가 불일치 |
| 기준 문서 | [`../architecture/CHARACTER_BUILD_INTEGRITY_CONTRACT.md`](../architecture/CHARACTER_BUILD_INTEGRITY_CONTRACT.md) |

### 원인

- 후보 목록은 로컬 `BuildIntegritySnapshot`으로 보석과 아크그리드 복합 오류를 표시한다.
- 선택 결과와 신청·직접 참가·Character 변경 명령은 `PartyGemValidationSnapshot`만 전달한다.
- 서버 신청 `submittedBuildSnapshot`과 membership도 보석 전용 Snapshot만 저장·읽으므로 아크그리드·아크패시브 오류를 재구성할 데이터가 없다.

### 해결 방향

- 기존 보석 요약은 유지하면서 통합 `buildIntegritySnapshot`을 신청·membership에 함께 저장한다.
- 생성 리더·신청·직접 참가·승인·Character 변경의 모든 쓰기와 방어적 읽기를 같은 계약으로 맞춘다.
- 오류는 표시 정보이며 참가 차단으로 바꾸지 않는다. 과거 null 문서는 계속 경고 없이 읽는다.

### 수정 결과

- 파티 생성 리더·신청·재신청·직접 참가·승인·Character 변경에 역할별 `buildIntegritySnapshot`을 연결했다.
- 신청은 `submittedBuildSnapshot` 내부, membership은 최상위 map에 저장하며 승인 시 신청 당시 값을 방어적으로 복사한다.
- 신청자와 배정/미배정 파티원 카드가 통합 오류를 우선 표시하고, 과거 문서는 기존 보석 오류 표시를 유지한다.
- Rules allowlist와 계약 테스트를 갱신했다.
- 2026-09-13 `lost-party` 운영 배포를 한 번 시도했으나 원격 컴파일 `/test`에서 HTTP 503으로 종료됐다. Ruleset 업로드와 Release에는 도달하지 않았으므로 운영 미반영이며 즉시 재시도하지 않았다.
- 이후 동일 조건 테스트 프로젝트 게시가 성공했고 운영 콘솔 오류도 사라졌다. 로컬 Rules를 다시 붙여 넣었을 때 변경점이 없어 게시 버튼이 비활성화됐으며, 사용자가 신청·참가 이후 통합 오류가 지속 표시되는 것을 실기기에서 확인했다.

---

## BUG-016. 인증 시작 장비 미착용이 일반 정보 실패로 표시됨

| 항목 | 내용 |
| --- | --- |
| 상태 | **종료 — 자동 수정·실기기 확인 완료** |
| 보고일 | 2026-09-13 |
| 심각도 | 낮음 — 사용자가 필요한 조치를 알 수 없음 |
| 기준 문서 | [`../architecture/GAME_ACCOUNT_VERIFICATION_CONTRACT.md`](../architecture/GAME_ACCOUNT_VERIFICATION_CONTRACT.md) |

### 원인

- 인증 시작은 무기와 방어구 5부위 중 하나라도 미장착이면 Gateway에서 `FormatException`을 발생시킨다.
- 화면의 공통 실행기는 장비 누락, Character 불일치와 실제 응답 파싱 실패를 모두 같은 `FormatException`으로 받아 `캐릭터 또는 장비 정보를 처리할 수 없습니다.`로 표시한다.

### 해결 방향

- 6부위 미착용을 식별 가능한 인증 시작 오류로 분리하고 `인증을 시작하려면 무기와 방어구 5부위를 모두 착용한 뒤 다시 시도해 주세요.`를 표시한다.
- 실제 API 오류·응답 누락·파싱 실패의 일반 안내는 유지한다.
- challenge 생성, 무작위 부위 선택과 인증 성공 판정은 변경하지 않는다.

### 수정 결과

- 장비 미착용을 문자열 비교가 아닌 `incompleteEquipment` 전용 시작 오류로 분리했다.
- 무기·방어구 5부위 완전 장착 성공, 일부 누락, 손상된 응답을 Gateway 테스트로 분리하고 화면 문구를 Widget 테스트로 고정했다.
- 사용자가 실제 기기에서 장비 미착용 전용 문구가 일반 정보 실패와 분리되는 것을 확인했다.

---

## BUG-017. 8인 Character 변경이 다른 파티 배치 가능성을 보지 않음

| 항목 | 내용 |
| --- | --- |
| 상태 | **구현 완료 — 실기기 부분 확인** |
| 보고일 | 2026-09-13 |
| 심각도 | 중간 — 유효한 다른 파티 배치가 있어도 Character 변경 후보가 차단됨 |
| 기준 문서 | [`NEXT_WORK.md`](NEXT_WORK.md), [`../architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md`](../architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md) |

### 원인

- 현재 `failureForInPlaceReplacement()`는 변경 대상의 기존 `partyIndex`만 검사한다.
- 다른 파티의 유효한 빈자리 또는 한 명과의 자리 교환으로 각 파티의 중복을 해소할 수 있는지는 후보와 최종 Transaction 모두 검사하지 않는다.
- 가입 배치는 다른 파티를 찾지만 확정 멤버 Character 변경은 슬롯 유지 계약이라 두 흐름이 갈라져 있다.

### 확정 해결 정책

- 제자리 변경이 불가능하면 다른 파티의 유효한 빈자리로 변경 대상만 이동한다.
- 빈자리가 없고 한 명과의 단순 교환으로 해결 가능하면 Character 변경을 먼저 허용하고 중복 카드에 파란 `동일 직업 · 자리 조정 필요`를 표시한다. 자동 교환은 하지 않는다.
- 공대장은 별도 자리 조정 명령으로 빈자리 이동 또는 두 멤버 교환을 수행하고 영향받는 멤버에게 알림을 남긴다.
- 구성 키는 일반 깨달음 분기가 아니라 정규 직업+역할이다. 전체 자동 재배치, 16인과 시너지 자동 추천은 제외한다.

### 확인 결과

- 수정 Rules 게시 후 추가 인증 없이 모집 생성·가입·자리 이동이 정상 작동했다.
- 점유된 두 자리의 인원 교환이 정상 작동했다.
- 교환 결과 같은 파티에 동일 구성 직업이 생기는 경우 저장되지 않고 안내가 표시되는 것을 확인했다.
- Character 변경에 따른 다른 파티 빈자리 자동 이동, 교환 가능 상태의 파란 안내와 조정 후 제거 및 `memberMoved` 알림은 별도 실기기 확인이 남아 있다.

---

## BUG-018. 확정 참가자가 있는 모집 해산이 권한 오류로 실패

| 항목 | 내용 |
| --- | --- |
| 상태 | **재현 유지 — 단독 수정 중단, 파티·그룹 명령 확장성 재설계로 전환** |
| 보고일 | 2026-09-14 |
| 심각도 | 높음 — 기존 다인 모집 해산 기능 회귀 |
| 기준 문서 | [`../architecture/PARTY_GROUP_COMMAND_SCALABILITY_REDESIGN.md`](../architecture/PARTY_GROUP_COMMAND_SCALABILITY_REDESIGN.md) |

### 증상과 경계

- 리더 외 확정 참가자가 있는 모집에서 파티장이 해산을 시도하면 권한 확인 안내가 표시되고 해산되지 않는다.
- 같은 수정 Rules 환경에서 모집 생성·가입·자리 이동·점유 자리 교환과 파티 탈퇴 후 재신청은 정상 작동한다.
- 그룹 생성·그룹장 이전·일반 탈퇴·마지막 1인 해산도 정상 작동하므로 계정 전체 권한 또는 그룹 명령 장애와 분리한다.

### 작업 게이트

- 과거 실기기에서 정상 확인된 다인 해산의 회귀로 취급한다.
- compact Rules 게시와 최신 앱 재빌드 뒤에도 재현되어 해산만의 추가 보정은 중단했다. 현재 단계에서는 전체 명령 접근량과 새 계약을 문서로 확정하며 코드·Rules 수정과 배포를 진행하지 않는다.
- `validRecruitmentDisband`의 본문은 과거 다인 해산 통과 이후 바뀌지 않았으므로 이 함수의 조건을 추측으로 완화하지 않는다.

### 조사 결과와 우선 가설

- v2 모집은 membership별 슬롯 Claim을 생성하지만 현재 해산 Repository는 membership과 assignment만 삭제하고 `slots` 문서를 읽거나 삭제하지 않는다. 해산 뒤 고아 Claim이 남는 수명 계약 누락은 확정이다.
- 리더 외 확정 멤버가 있을 때는 그 멤버에게 `partyDisbanded` 이벤트를 생성한다. 단독 해산에는 이 write가 없으므로 단독 성공·다인 실패를 가르는 가장 좁은 실행 차이다.
- 이벤트 Rules의 `validPlayerEvent`는 type 선분기 없이 여러 validator를 OR로 연결하고, `validCycleEvent`는 type 검사 전에 cycle을 읽는다. 무관한 경로 접근 또는 복합 Transaction 문서 접근 예산 초과 가능성을 Emulator 평가 로그로 먼저 확인한다.
- 현재 테스트는 화면에서 다인 해산 명령 전송과 개별 Write Plan만 확인하며 실제 다인 Transaction+Rules 계약을 실행하지 않는다. 이 공백 때문에 회귀가 자동 검증을 통과했다.

### 확정 전 수정 계획

- 실제 운영 Rules로 단독/2인, 공개/그룹, 과거/v2, active/completed와 이벤트·슬롯 삭제 유무를 분리한 Emulator 최소 재현을 만든다.
- v2 해산은 모든 슬롯 Claim을 membership·assignment·listing과 같은 Transaction에서 삭제하도록 수명 계약을 보완한다.
- 이벤트가 직접 실패 지점이면 이벤트 type별 dispatcher로 바꿔 `partyDisbanded` 검증에서 무관한 cycle/application/membership validator를 실행하지 않는다.
- Rules 검증 완화나 알림 제거는 첫 수정안으로 사용하지 않는다. 8인과 pending 신청 포함 상태의 접근 한도가 dispatcher 정리 후에도 초과할 때만 이벤트 fan-out 분리를 별도 협의한다.

### 수정 결과

- v2 해산 Transaction이 모든 membership의 대응 슬롯 Claim을 읽어 소유자를 확인한 뒤 membership·assignment와 함께 삭제하도록 보완했다. 슬롯 불일치는 부분 정리 없이 `revisionConflict`로 중단한다.
- 슬롯 삭제 Rules는 기존처럼 Claim 소유자와 membership 제거를 연결한다. membership 삭제마다 슬롯 부재를 역으로 조회하면 8인 복합 쓰기의 Rules 문서 접근 한도를 넘을 위험이 있어 추가하지 않았다.
- `validPlayerEvent`는 이벤트 type을 먼저 분기하고 해당 validator만 평가하도록 바꿨다. 다인 해산 이벤트가 무관한 cycle/application/membership Rules 조회를 실행하지 않는다.
- 리더 권한·revision·모집 해산 필드·assignment·group listing·이벤트 수신자 검증은 완화하지 않았다.
- 표적 계약 18건과 모집·파티 상세·그룹 영향 회귀 549건, 변경 파일 정적 분석이 통과했다. 전체 Rules는 로컬 Emulator 시작 단계에서 컴파일됐다.
- 실제 다인 Transaction Emulator 실행은 기존 전체 Rules 재업로드 503 및 SDK gRPC 전송 오류로 검증하지 못했다. 운영 배포와 공개·그룹 다인 해산 실기기 확인 전에는 종료하지 않는다.
- 커밋 `a5a28d6` 추적본으로 운영 배포를 정확히 한 번 시도했다. `projects/lost-party:test` 원격 컴파일은 성공하고 경고가 없었으나 `projects/lost-party/rulesets` 생성이 HTTP 503으로 실패했다. Release 갱신은 수행되지 않았고 즉시 재시도하지 않는다.
- 사용자가 같은 현재 Rules를 별도 테스트 프로젝트 콘솔에서도 반복 게시했으나 동일한 503이 발생했다. 특정 운영 프로젝트 권한·데이터 문제는 우선순위에서 제외한다.
- 직전 게시 성공본 `c4344e6`과 현재 Rules의 유일한 기능 차이는 5개 OR 호출을 type guard 목록으로 확장한 `validPlayerEvent`다. `/test`는 성공하므로 문법이 아니라 Ruleset 저장 산출물의 복잡도 경계 또는 해당 식을 처리하는 Firebase 내부 오류 가능성을 1순위로 둔다.
- 다음 수정은 dispatcher를 `lifecycle → application → membership → guarded manual verification → cycle`의 짧은 OR로 축소하는 것뿐이다. 해산 이벤트의 cycle 선조회는 계속 방지하며 권한 조건은 완화하지 않는다. 테스트 프로젝트 compact 게시 실패 시에는 직전 `c4344e6` 기준도 같은 시점에 대조하고, 둘 다 실패하면 서비스 장애로 분류해 추가 코드 축소를 중단한다.
- 위 compact dispatcher 구현을 완료했다. 관련 표적 18건, Rules 경고 계약 3건과 전체 Rules 로컬 Emulator 컴파일·기동이 통과했다. 원격 게시 성공은 아직 확인하지 않았으므로 BUG-018은 닫지 않으며, 운영 배포 전에 테스트 프로젝트 콘솔 게시 결과를 확인한다.
- compact Rules 운영 게시와 최신 앱 재빌드 후 새 다인 방에서도 같은 `permission-denied`가 재현됐다. 해산 버튼을 숨기는 임시 변경은 완료 후 마무리 흐름까지 훼손하므로 철회하고 기존 UI를 복원했다. `BUG-018`을 단독 보정하지 않고 인원수 비례 명령 전체 재설계로 승격하며 상세 기준은 `PARTY_GROUP_COMMAND_SCALABILITY_REDESIGN.md`에서 관리한다.

---

## BUG-019. 원자 모집 생성·목록·후보·신청 상태 불일치

| 항목 | 내용 |
| --- | --- |
| 상태 | **첫 수정 구간 자동 검증 통과 — 기존 방·생성 권한 오류 조사 대기** |
| 보고일 | 2026-09-17 |
| 심각도 | 높음 — 새 공개방 신청 불가, 생성 후보와 서버 점유 판정 불일치 |
| 실행 계획 | [`NEXT_WORK.md`](NEXT_WORK.md) F2-0/F2-A |

### 확인된 사실

- 디버그 에뮬레이터의 최초 신청 로그는 `PartyAtomicApplication unexpected ArgumentError: 모집 Aggregate 집계가 올바르지 않습니다.`이며, `PartyAtomicDocumentMapper.aggregate()`가 서버 쓰기 전에 중단됐다. 따라서 이 신청 실패를 Rules `permission-denied`로 분류하지 않는다.
- 그룹 연결이 없는 공개방 생성 Write Plan은 첫 슬롯 `countedAsNonGroupMember = false`, `nonGroupMemberCount = 1`을 함께 저장한다. Domain Aggregate는 집계와 슬롯의 `true` 개수가 같아야 한다고 검사한다. 현재 Rules는 이 공개방 생성 조합을 허용하고, 기존 자동 테스트도 서로 다른 값의 결합을 검사하지 않았다. 이는 신규 공개방 신청 실패의 재현 가능한 코드 원인이다.
- 생성 후보 서비스에 연결된 `FirestoreActiveRaidAssignmentLookup`은 구 `players/{playerId}/activeRaidAssignments`를 읽는다. 현재 원자 생성 명령은 새 `raidStates`에 점유를 쓰고 검사한다. 따라서 후보의 ‘동일 레이드 참가 중’ 표시가 서버 명령의 최종 차단과 다를 수 있다. 생성 화면의 `_canChooseCandidate`도 후보의 전체 `canSelect`가 아니라 일정 충돌·레벨만 검사한다.
- 서버가 `permission-denied`를 반환한 특정 캐릭터의 재생성 실패는 별도 현상이다. 명령이 읽은 기존 `raidState`·연결 모집, 주차와 실패한 Rules 문서를 확인하기 전에는 첫 신청 오류와 동일 원인이라고 단정하지 않는다.
- 다른 사용자에게 기존 방이 보이지 않는 이유도 미확정이다. 공개 목록 쿼리는 `schemaVersion == 2`, `visibility == public`, `status == active`, 수동 모집 활성, 빈자리, 현재 `targetCycleKey`를 모두 요구한다. Router는 주차 키를 생성 시 한 번 계산해 화면에 전달하므로 수요일 06시 경계 전후 앱 재진입 상태도 확인한다. 타인 계정이 실제로 다른 Player ID인지와 어느 저장 필드가 다른지 읽기 전에는 노출 필터를 완화하지 않는다.

### 복구 경계

- 먼저 문제 방과 생성 실패 캐릭터의 특정 문서만 읽기 전용으로 확인한다. 모집 ID·`revision/status/visibility/manualRecruitmentEnabled/hasAvailableSlot/targetCycleKey/partySlots/nonGroupMemberCount/pending` 집계, 대상 `raidState`의 상태·주차·모집 ID 및 Firebase 오류 코드를 기록한다. 계정 전체 자료를 초기화하거나 방을 추측으로 삭제하지 않는다.
- 공개방 무그룹 집계의 단일 의미를 슬롯 Snapshot·모든 가입/탈퇴 Write Plan·Domain·Rules·테스트에서 일치시킨다. 그룹 ID가 없는 방의 비그룹원 집계는 `0`으로, 그룹 연결 방에서는 실제 비그룹 멤버 Snapshot만 세는 안을 기준으로 검증한다. 기존 잘못 저장된 테스트방은 범위와 수를 확인한 뒤 별도 복구/정리 결정을 받는다.
- 생성·신청 후보는 운영 `raidState`와 현재 주간 완료 자료를 읽되, 생성 Transaction의 최종 재검증을 유지한다. 빨간 차단 표시와 선택 불가, 동시 변경 시 서버 거절 안내를 함께 계약 테스트로 고정한다.
- 목록 미표시는 실제 저장 필드와 쿼리 조건을 비교해 정상 주차/비공개/만석 제외인지 읽기·갱신 결함인지 분리한다. 정상 제외 조건은 유지한다.
- 상세 작업 순서·자동/실기기 회귀 게이트는 `NEXT_WORK.md` F2-0을 따른다. 신규 방의 코드·Rules 초안과 후보 조회를 수정했지만 운영 Rules·데이터는 변경하지 않았으며, 전체 Emulator와 실기기 확인 전에는 완료로 처리하지 않는다.

추가 제보(2026-09-17): 미노출/생성 충돌 확인 대상의 방장 캐릭터는 `이슈하이`이며 방 제목은 `카제노말모집`, `지평1단 모집`, `4막하드 모집`이다. 제목은 고유 ID가 아니므로 이 세 방의 `recruitmentId`와 각 문서의 목록 필터 필드, `이슈하이`의 해당 레이드별 `raidState`를 읽기 전에는 동일 원인으로 묶거나 데이터를 변경하지 않는다. 전체 Rules Emulator CI `35114485069`는 통과했으나 운영 데이터의 상태를 증명하지 않는다.

콘솔 문서 대조: 세 방의 ID는 각각 `7eel6EoHVWwuQQFjkrbg`, `EbsqL1WN2GVgjU7dP7Y7`, `EmWQl5sD4yRn5j5ut4UB`이다. 모두 공개·active·수동 모집·빈자리이고 `targetCycleKey=2026-09-09`, `cycleEndsAt=2026-09-16 06:00 KST`, `continueTogether=false`라 현재 주차 목록에서 빠지는 것은 정상이다. 모두 `partySlots[0].countedAsNonGroupMember=false`/`nonGroupMemberCount=1` 불일치가 확인됐다. 실제 `raidStates` 문서는 아직 받지 못했지만 동일한 과거 주차 점유를 Emulator에 재현한 CI `35168119595`는 현행 한 Transaction `delete`→`set` 생성 시 Rules 1,000식 한도 `permission-denied`로 실패했다. 해결 범위와 안전 게이트는 `NEXT_WORK.md` F2-0을 따른다.

추가 원인 확인: 본인 레이드 현황의 `watchActiveRaids`는 `status in [active, completed]`만 조회하고 주차로 거르지 않는다. 이 세 문서는 여전히 `active`여서 계속 보인다. 화면의 lazy 회차 보정은 `PartyAtomicCycleCommandAdapter._executeLifecycle`에서 `PartyAtomicDocumentMapper.aggregate`를 먼저 생성하는데, 위 불일치로 `ArgumentError`가 나면 보정 명령 전에 실패한다. 따라서 단순한 테스트 기간 표시 문제가 아니라 저장 불변식 때문에 자동 종료가 막힌 상태다. 콘솔에서 모집 문서만 삭제하면 하위 membership·신청 및 별도 `raidState`가 남을 수 있으므로 임의 삭제하지 않는다. 세 문서와 각 연결 state를 백업·대조한 뒤 `nonGroupMemberCount`의 제한적 보정과 lazy 종료 재시도를 별도 복구 단위로 검증한다.

---

## BUG-020. 파티 완료 수명주기의 권한·기록·개인 해제 회귀

| 항목 | 내용 |
| --- | --- |
| 상태 | **복구 진행 중 — R1·R2 완료, R3~R4 미완료** |
| 보고일 | 2026-09-19 |
| 심각도 | 매우 높음 — 다인 전체 완료 불가 및 성공 완료의 기록·해제 UX 손상 |
| 실행 계획 | [`NEXT_WORK.md`](NEXT_WORK.md) F6-B2-R |

### 실기기 재현

- 공대장 Character로 A 레이드 모집 생성 → 다른 계정 가입 → 파티 전체 완료 시 `권한을 확인할 수 없습니다.`로 실패한다.
- 같은 모집의 해산은 성공한다.
- 같은 Character·레이드로 다시 혼자 모집 생성 → 파티 전체 완료와 해산은 성공하지만 완료 기록 화면에는 기록이 없다.
- 내 계정에는 완료 상태가 표시돼도 체크박스로 해제할 수 없다. 참가·완료 안내 `i` 표시는 유용하지만 안내를 이유로 체크박스 자체를 비활성화하는 것은 기존 UX 위반이다.

### 확인된 서로 다른 원인

1. `FirestorePartyAtomicCommandRepository`가 해산 외 lifecycle 명령에서 모든 대상 Player의 private `raidState`를 `transaction.get()`한다. Rules는 자기 Player 경로만 읽게 하므로 타인 한 명이 추가되는 순간 완료가 `permission-denied` 될 수 있다. 해산은 2026-09-17 수정에서만 이 읽기를 생략해 서로 다른 결과가 난다.
2. 원자 lifecycle의 공용 `partyEvents` 완료 문서에는 `characterId/raidId/difficultyId/cycleKey`가 없다. 완료 기록 sync는 네 필드가 모두 있을 때만 Drift 기록을 만들고 누락 시 조용히 건너뛴다.
3. B2-A가 새 state 쓰기 명령 미연결을 이유로 `active/completed/inconsistent`를 모두 `canToggle=false`로 만들었다. 이는 사용자가 요구한 제품 정책이 아니라 구현 중간 단계를 운영에 노출한 회귀이며, 기존 `완료 상태 유지 후 본인 해제 가능` 계약과 충돌한다.

### 테스트가 놓친 이유

- 확장성 Rules Emulator lifecycle 시나리오는 모집만 읽고 타인 state를 바로 update하므로 실제 앱 Repository의 private state 선읽기를 재현하지 않는다.
- Repository 계약 테스트는 Transaction·컬렉션 사용 문자열만 확인하며 인증된 2인 실제 실행을 하지 않는다.
- 완료 이벤트 테스트는 type 분류만 검사하고 완료 기록에 필요한 Snapshot 필드와 실제 Drift 기록 생성을 검증하지 않는다.

### 복구 기준

- 공용 이벤트 한 건과 최대 8인 Aggregate 구조는 유지한다. Player별 이벤트 fan-out은 복원하지 않는다.
- 완료 명령의 타인 private read를 제거하고 Rules가 Aggregate 대상·각 state update·revision을 검증한다.
- 각 state 쓰기에서 전체 대상을 다시 검사하는 `8×8` Rules 평가를 금지하고, 공개·그룹 1·2·4·8인을 실제 앱 Repository와 같은 인증 흐름으로 검증한다.
- 공용 완료 이벤트에 공통 레이드·난이도·주차와 최대 8명의 Player·Character 대상을 보존해 수신자별 기록을 만든다.
- `active` 안내 아이콘과 `completed` 안내 아이콘은 유지하되 체크박스 조작을 막지 않는다. active 선택은 영향 확인과 개인 완료, completed 해제는 본인의 현재 주차 완료 근거만 제거하는 명령으로 연결한다. `inconsistent`도 일괄 차단하지 않고 검증된 완료 근거는 한 번의 해제로 정리하며 active 참가 근거는 보존한다. 소유권·식별자를 증명할 수 없는 손상 데이터만 별도 복구 안내로 보낸다.
- 내 계정 체크는 개인 진행 관리 UX이므로 `방 생성 → 완료 → 체크 해제 → 재생성 → 완료 → 재해제`를 정상 흐름으로 회귀 검증한다. 공대장의 실수로 전체 완료된 일반 참가자도 자기 완료 체크를 해제할 수 있어야 한다.
- 파티 전체 완료 취소는 반복방 여부와 관계없이 폐기한다. 모집 상세 버튼·신규 명령·Rules 허용을 제거하고, 반복방은 수요일 06시 다음 주차로만 전환한다. 과거 `completionCancelled` 이벤트와 로컬 히스토리는 읽기 호환만 유지한다.
- 완료 판정은 `2인 이상 전체 완료 → 각자 완료 기록 → 완료방 해산 → 체크 유지 → 한 명만 해제 → 해제한 Player 재참가 가능·나머지 완료 유지` 전체 사이클의 자동·실기기 통과다.

---

## 백로그 연결

### 2026-09-20 삭제된 모집을 참조하는 active raidState 확정

- 실기기 정상 완료 사이클은 통과했으나 한 Character의 4막이 실제 참가방 없이 `참가 중`으로 표시되고, 수동 완료 시 `이 캐릭터의 참가·완료 기록이 일치하지 않습니다. 새로고침 후 다시 확인해 주세요.`가 노출됐다. 별도 새로고침 기능은 없고 서버 고아 데이터는 재구독으로 복구되지 않으므로 문구도 부정확하다.
- 확인 문서는 `players/kVn6KZwZQO6or3BjNYqX/raidStates/xseSyVxZXWhKYxlZEucb_kazeros_act4`다. `status: active`, `source: party`, `cycleKey: 2026-09-16`, `recruitmentId: td904kw3PEgWI1GwIfUP`, `revision: 1`이며 `recruitments/td904kw3PEgWI1GwIfUP` 원본은 존재하지 않는다. 고아 참가 기록으로 확정한다.
- 완료 근거와 겹쳐 빨간 불일치 표시가 나던 다른 항목은 사용자가 개인 체크 해제 후 사라졌지만, 이 active state는 연결 모집이 없어 탈퇴·승계·해산 후 완료 전환을 할 수 없으므로 남았다. 완료 체크→해제로 우회 삭제하지 않는다.
- 다른 Character·raid에 해산된 방을 참조하는 pending 신청 두 건도 남아 있으나 이 4막 참가 표시의 직접 원인은 아니다. 본인 단건 orphan active 복구는 F6-D, 다수 고아 신청·상태의 운영 진단/정리는 별도 백로그로 분리한다.
- 해결 계약은 [`WEEKLY_RAID_CLAIM_CONTRACT.md`](../architecture/WEEKLY_RAID_CLAIM_CONTRACT.md) §0.7과 [`NEXT_WORK.md`](NEXT_WORK.md) F6-D를 따른다. 이 최초 재현 시점에는 서버 문서를 보존하고 코드·Rules·데이터를 변경하지 않았으며, 이후 D1~D3 구현·검증 및 사용자 Rules 게시가 진행됐다.

### 2026-09-20 이전 주차 active 고아의 비표시·쓰기 차단

- 다른 Player `Grn71r8G1pvCEvLAtpVB`의 `raidStates/hTfsqNxwHm5Oo4GL8zcK_kazeros_act4`는 `status=active`, `source=party`, `cycleKey=2026-09-09`, `recruitmentId=VjtZmBAeUGIiFOMPF6Xx`, `revision=1`이다. 현재 앱 주차는 `2026-09-16`이다.
- 현재 주차 Projection 쿼리는 과거 cycle을 제외하므로 내 계정 참가 느낌표가 없는 것은 계약상 정상이다. 그러나 완료 체크는 Character·raidId의 고정 문서 경로를 직접 읽어 cycle 불일치에서 `안전하게 정리할 수 없음`으로 종료한다.
- 연결 모집 `VjtZmBAeUGIiFOMPF6Xx`의 존재·상태는 아직 제공되지 않았으므로 이 문서를 실제 고아로 최종 확정하거나 삭제하지 않는다. missing/종료/완료/만료 비반복 상태가 재검증될 때만 `historicalOrphanActive`로 정리한다. 유효 반복방이면 정상 승계/참가 충돌로 남긴다.
- 후속 설계는 현재 주차 느낌표를 과거 데이터까지 확장하지 않는다. 완료·생성·신청·즉시 가입의 exact-state preflight에서만 과거 active 고아를 발견하고 신청자 본인에게 정리를 안내한다. 방장은 타인 private state를 읽지 않으며 승인 실패 시 명시적 신청 거절 UX를 제공한다.
- 정상 신규 신청에서는 신청자 preflight가 고아 상태를 먼저 안내·정리하므로 공대장이 고아 현황을 보지 않는 것이 정상이다. 과거 pending 또는 신청 뒤 경쟁 상태에서 승인 `permissionDenied`가 발생했는데도 공대장 화면에 전용 데이터 오류 안내와 명시적 `신청 거절` 선택이 나오지 않는다는 제보가 들어오면, 신청자 복구 문제가 아니라 D6 공대장 대응 회귀로 우선 분류한다. 이를 재현하기 위한 콘솔 고아 데이터 인위 생성 테스트는 2026-09-20 사용자 결정으로 생략했고 표적 Widget 테스트를 완료 근거로 삼는다.
- D4 코드 반영(2026-09-20): 공용 exact-state 수명 판정으로 이전 주차 active를 missing/종료/완료/만료 1회성 고아와 유효 반복방 충돌로 분리했다. 내 계정 정리는 관찰한 과거 cycle·revision·recruitmentId를 사용하고 현재 주차 느낌표는 추가하지 않는다. 이전 주차 completed는 고아 정리 대신 수동 완료·모집 생성의 정상 rollover로 처리한다. Rules 변경·배포는 없으며 사용자가 실제 과거 고아 데이터의 안내·정리 성공을 확인했다. 유효 반복방의 실기기 확인은 남아 있다.
- 신청 경계 해결: 과거 고아는 평상시 표시하지 않되 D5가 신청 저장 전 본인 exact-state를 검증하고 정리를 안내한다. 고아 데이터 상시 발견과 공대장 자동 거절 여부는 [`../product/DETAIL_IMPROVEMENTS.md`](../product/DETAIL_IMPROVEMENTS.md)의 장기 개선 후보로 분리한다.
- D5 실기기 확인(2026-09-20): 이전 주차 고아를 가진 Character로 다른 사용자의 동일 레이드 방에 신청하면 pending 저장 전에 `참가 기록 정리` 안내가 나타나고, 사용자의 명시적 확인 뒤 해당 고아 state가 실제 삭제되는 것을 확인했다. 정리 뒤 신청은 자동 실행하지 않고 사용자가 다시 누른다. 현재 주차 고아는 기존 참가 느낌표와 정리가 정상 작동해 두 주차의 사용자 복구 경계가 확인됐다. 모집 생성은 연결 모집이 없는 stale state를 Transaction에서 다시 확인한 뒤 기존 생성 재시도 계약으로 교체하며, 이 동작을 신청의 명시적 정리 UX와 구분한다.

### 2026-09-18 승인 실패와 수동 완료 실패 — 별도 원인으로 분리

현재 판정:

- `니티야` 4막 승인 실패: 같은 Character·raid의 `active raidState`가 삭제된 모집 원본을 참조한다. 정상 다른 Character 승인은 성공했다. 고아 점유를 현재 데이터 특이 사례로 분류하며, 신청이 이를 사전에 차단하지 않고 승인에서 모호한 권한 오류가 되는 코드/UX 경계는 F6-D에서 보완한다. 삭제 경위는 사용자 기억과 부합하지만 확정 이력은 없다.
- `이슈아이` 모든 레이드 수동 완료 실패: 해산된 그룹 전용 모집의 잔존 pending 신청을 조회하면서 접근 불가한 부모 모집을 읽는 것이 실기기 첫 실패 지점이었다. 그룹은 `softDeleted`/멤버 0명이다. F6-B1에서 해당 부모 읽기의 `permission-denied`만 신청 단위로 제외했다. 사용자가 수동 체크·해제와 정상 pending 신청 안내·취소를 확인해 이 증상은 해결됐다. 새 `raidState`와 Claim의 통합 문제는 F6-B2로 분리한다.
- 두 사례를 하나의 Rules 권한 문제로 합치거나 서버 문서를 즉석에서 삭제하지 않는다. 아래는 조사 당시의 가설·로그·문서 대조를 시간순으로 보존한 근거이며, 초기 `미확정` 문구보다 위 최신 판정이 우선한다. 다음 순서는 `NEXT_WORK.md` F6을 따른다.

조사 경과:

- 사용자 실기기 제보: 같은 원정대의 다른 캐릭터는 수동 완료 체크/해제가 되지만 한 캐릭터는 `완료 상태를 변경할 권한이 없습니다.`가 나온다. 이 캐릭터는 새 모집 생성과 들어온 신청 거절은 되지만 신청 승인 시 `가입 권한을 확인하지 못했습니다.`가 나온다. 콘솔에서는 과거 버그 방의 `recruitments/{id}` 하위 `members`·`applications`를 삭제했으며, 개인 `raidStates`·구 `activeRaidAssignments`·`weeklyRaidClaims`와 모집 원본 Aggregate 정리 여부는 확인되지 않았다. 문제 캐릭터명·레이드 ID·방 ID·실패 시각과 실제 첫 거절 문서도 아직 없다. **두 증상이 동일 원인이라는 판정이나 서버 데이터 삭제는 하지 않는다.**
- 코드 확인: 내 계정 수동 완료 명령은 구 `weeklyRaidClaims`와 `activeRaidAssignments`를 읽고/쓰며, Rules는 Claim 생성 때 Character 소유와 `!existsAfter(activeRaidAssignment)`를 요구한다. 새 파티 생성·승인은 통합 `raidState`를 사용한다. 따라서 신규 방에서 활성 `raidState`만 있는 캐릭터의 수동 완료 명령은 그 점유를 감지하지 못하는 **확정된 코드 계약 누락**이다. 동시에 구 assignment가 남은 캐릭터는 다른 결과를 낼 수 있다. 이번 특정 캐릭터의 `permission-denied`가 바로 그 때문인지는 데이터 없이 확정하지 않는다.
- 승인과 거절은 쓰기 집합이 다르다. 승인은 모집 Aggregate·신청·새 멤버·신청자 `raidState`·listing·공용 이벤트를 갱신하지만 거절은 신청·모집·공용 이벤트만 갱신한다. 따라서 거절 성공은 승인 경로의 권한·데이터 정합성을 증명하지 않는다. 하위 `members`만 수동 삭제했다면 원본 `memberPlayerIds/partySlots/memberCount` 및 개인 `raidState`와의 불일치 가능성이 있으나, 이번 방의 실제 저장값 없이는 단정하지 않는다.
- 다음 확인(읽기 전용): 실패 캐릭터의 서버 Character ID/소유 Player ID와 해당 레이드·주차의 Claim, 구 assignment, `raidState`; 승인 실패 방의 원본 `revision/status/partySlots/memberPlayerIds/memberCount/raidStateTargets`, 실제 남은 멤버·신청 문서; 승인 신청자의 Character/Claim/`raidState`; 같은 빌드의 첫 Firebase 실패 단계와 시각을 대조한다. 다른 정상 캐릭터/방과 비교한다. 개인 문서나 방을 임의로 재생성·삭제하지 않는다.
- 분류 기준: 과거 콘솔 수동 삭제와 연결된 고립된 불일치가 증명되면 데이터 복구/정리 후보로만 남긴다. 정상 신규 데이터에서도 재현되거나 구 Claim·새 `raidState` 계약 충돌이 입증되면 F2 승인·F6 수동 완료 회귀의 코드 수정 대상으로 승격한다. 각각의 허용/거절 Rules 계약과 생성→신청→승인·수동 완료/해제·다른 캐릭터 회귀를 먼저 고정한다.
- F6-A 1차 읽기 확인(2026-09-18): 연결된 실기기 `R3CX70B43JR`의 기존 logcat에 `PartyAtomicJoin FirebaseException code=permission-denied`가 00:17:16·00:19:31·00:19:38에 남아 있다. 로그에는 모집/캐릭터 ID와 거절 문서 경로가 없어 제보 방의 실패로 확정할 수 없다. 수동 Claim Repository는 Firebase 오류 코드를 UI 실패로 매핑하지만 같은 디버그 로그를 남기지 않는다. 승인 코드는 신청자 `raidState`를 읽지 않고 `transaction.set`하며, 해당 문서가 이미 있으면 Rules의 `create`가 아니라 제한된 `update` 분기를 통과해야 한다. 과거 하위 문서만 삭제하고 신청자 `raidState`가 남은 경우 승인만 거절되는 것은 **가능한 가설**이나, 실제 대상 문서 확인 전에는 원인으로 채택하지 않는다. 추가로 00:18:18의 `PartyAtomicLifecycle` 권한 로그는 별도 명령이므로 두 제보 증상의 증거로 합치지 않는다.
- F6-A 대상 식별 정보: 문제 캐릭터명은 `이슈아이`이며, 사용자가 `3XQrYsdTOh6KllKZbyEi`를 해당 방의 `recruitments` 문서 ID로 확인했다. Firebase 콘솔의 읽기 전용 접근이 Google 계정 재인증 단계에서 차단되어 운영 문서 원본·하위 문서·개인 상태 대조는 미실시다. 사용자의 콘솔 조회 결과 또는 적법한 읽기 접근이 확보되기 전까지 두 권한 실패의 공통 원인, 데이터 단독 결함 및 코드 수정 필요 여부를 확정하지 않는다.
- F6-A 사용자 제공 하위 문서 대조: 제공된 application은 신청자 `니티야`(`applicantPlayerId=Grn71r8G1pvCEvLAtpVB`, `characterId=VcZhYtLEQI6d1fj8j7O3`), 회차 `2026-09-16`, 00:19:26 생성, 최종 `rejected`/`rejectedByApprover`, `rejectionCount=1`, `approvalCount=0`, `revision=2`, 00:20:09 결정이다. 제공된 member는 방장 `이슈아이`(`playerId=kVn6KZwZQO6or3BjNYqX`, `characterId=8GbZgoPyBFqGDnsmPxsf`), `canApproveApplications=true`, 0파티 0번 자리다. 신청이 생성된 뒤 거절되기 전인 00:19:31·00:19:38의 실기기 `PartyAtomicJoin permission-denied` 로그와 시간상 부합하지만 로그에 방 ID가 없어 같은 명령으로 확정하지 않는다. 최종 신청 상태가 `rejected`인 것은 뒤이은 거절의 결과이며, 승인 시도 당시 `pending`이 아니었다는 증거는 아니다. 모집 원본 Aggregate, 신청자 `raidState`와 Claim 및 실패 문서 경로가 없어 승인 실패의 첫 원인은 미확정이다.
- 이후 사용자가 잘못 선택했던 다른 방 `53xQOHjl2BC1jiWxPFKw`의 원본·member·application을 별도로 제공했다. 원본은 `schemaVersion=2`, `raidId=kazeros_act4`, `status=disbanded`, `revision=14`, `memberCount=2`이며 `lastCommandType=disband`(2026-09-17 15:54:35)다. 이 방의 같은 방장 `이슈아이`와 신청자 Player `Grn71r8G1pvCEvLAtpVB`의 **다른 캐릭터** `니티얌`(`hP1JfmaTtXgfTOZX7KSj`)은 2026-09-17 15:53:45 승인되어 application `approved`/`approvalCount=1`, member와 `partySlots`에 반영됐다. 9월 18일 실패 제보 방 `3XQrYsdTOh6KllKZbyEi`와 혼동하지 않는다. 이 비교 자료는 동일 방장·신청자 Player의 이전 승인 성공을 보여주지만 현재 실패 방 원본이나 신청자 캐릭터의 `raidState`를 대신하지 못한다. 해산된 방의 `partySlots`·targets 잔존은 수명주기 계약 대조 전에는 데이터 오류로 판정하지 않는다.
- 실패 제보 방 `3XQrYsdTOh6KllKZbyEi`의 상위 문서를 사용자가 추가 제공했다. `schemaVersion=2`, `raidId=kazeros_act4`, `targetCycleKey=2026-09-16`, 방장 Character `8GbZgoPyBFqGDnsmPxsf`, `memberPlayerIds/partySlots/raidStateTargets` 각각 방장 1명, `memberCount=1`, `pendingApplicationCount=0`, 최종 `revision=4`, `status=disbanded`, `lastCommandType=disband`(2026-09-18 00:59:18)로 서로 맞는다. 신청 `니티야`는 00:20:09에 `rejected`로 끝났으므로 최종 집계 0도 일치한다. 사용자가 01:03에 같은 방에서 다시 승인 버튼을 눌러 `가입 권한을 확인하지 못했습니다.`를 봤다고 보고했으나, 이는 **해산·거절 이후**다. 현재 Repository `_join`은 원본 읽기 뒤 revision/status를 검사해 종료 방에는 `recruitmentClosed`, 처리된 신청에는 `applicationNotPending`을 반환해야 하므로, 이 01:03 오류를 00:19 당시 pending 승인 실패의 재현으로 취급할 수 없다. 버튼이 실제 어느 문서/빌드의 명령을 실행했는지 로그 ID가 없으며, 01:03 표시의 별도 원인도 미확정이다. 최종 Aggregate는 정합하므로 이 자료만으로 과거 수동 삭제로 인한 원본 불일치를 입증하지 않는다.
- 실기기 logcat 재확인: `PartyAtomicJoin permission-denied`는 00:59:44 및 01:03:33·01:03:49에도 있다. 따라서 01:03 팝업과 Repository의 Firebase 권한 예외는 실제로 대응하지만, 로그에 첫 거절 경로/방 ID가 없고 01:03 저장본은 이미 `disbanded`/`rejected`다. 해당 시점은 정상 pending 승인 Write Plan까지 도달했음을 보여주지 않는다. 새 활성 방·pending 신청에서 버튼을 누르는 즉시 원본/신청 revision·상태와 신청자 개인 `raidState`를 잡아야 원인을 분리할 수 있다.
- 대조군 실기기 성공(2026-09-18 01:10): 같은 방장 `이슈아이`가 새 활성 공개 방 `9DCSALiBRkO8sZ6sxzCU`(`raidId=horizon_cathedral`, stage3)에서 같은 신청자 Player `Grn71r8G1pvCEvLAtpVB`의 **다른 캐릭터** `피에티아`(`zrkfjLHRQD4lYeDqkdW4`) 신청을 승인했다. 제공된 원본은 `revision=3`, `memberCount=2`, `partySlots/memberPlayerIds/raidStateTargets` 2명, `pendingApplicationCount=0`; application은 `approved/approvedByApprover`, `approvalCount=1`, member의 `joinedBy`가 방장 Player다. 따라서 방장 계정의 일괄 승인 불가, 승인 UI/Rules 전체 불능 가설은 배제된다. 실패 4막/`니티야`와 레이드·신청 Character가 함께 달라졌으므로 어느 차이가 원인인지는 아직 모른다. 우선 `니티야`의 `players/Grn71r8G1pvCEvLAtpVB/raidStates/VcZhYtLEQI6d1fj8j7O3_kazeros_act4` 및 같은 Character/raid의 주간 Claim·과거 점유 존재를 읽기 전용 확인한다.
- 신청자 개인 상태 확인: 사용자가 제공한 `players/Grn71r8G1pvCEvLAtpVB/raidStates/VcZhYtLEQI6d1fj8j7O3_kazeros_act4`는 `cycleKey=2026-09-16`, `difficultyId=normal`, `status=active`, `source=party`, `recruitmentId=TIaqi4sw0rKvC24Izq5m`(2026-09-16 생성)이다. 즉 실패 방 `3XQrYsdTOh6KllKZbyEi`와 **같은 Character·raid·주차**의 기존 점유가 실제로 있다. 승인 명령은 타인 `raidState` 읽기 없이 같은 문서에 `set`하므로, 문서가 이미 있으면 `create`가 아니라 lifecycle 전용 `update` Rules를 만나 승인 Transaction이 `permission-denied` 되는 설명과 부합한다. 이 상태에서는 신청 승인을 성공시키는 것이 맞는지부터 기존 방 상태로 판정해야 한다. 기존 방이 활성이라면 중복 참가 차단 자체는 정상이며 신청 가능/UI 오류 설명의 개선 과제다. 기존 방이 종료됐다면 `raidState` 잔류 불변식/정리 결함 후보가 된다. `recruitments/TIaqi4sw0rKvC24Izq5m`의 `status/currentCycleKey/partySlots`를 확인하기 전까지 둘 중 하나로 확정하지 않는다. 방장 `이슈아이`의 수동 완료 체크 권한 실패는 별도 Player/Character 상태이므로 이 신청자 점유만으로 설명하지 않는다.
- 코드 경계 확인: 신청 Repository는 본인 `raidState`를 읽지만 같은 주차 `completed`만 차단하고 기존 `active`를 차단하지 않는다. Rules의 `validPendingApplication`도 Character 소유·주간 Claim 등을 확인하지만 기존 `raidState` 활성 점유는 확인하지 않는다. 그래서 `니티야`의 pending 신청 생성은 현 코드상 가능하고, 그 뒤 승인은 기존 `raidState` 문서 업데이트가 lifecycle 전용 Rules에 막힐 수 있다. 이 **신청 시점의 활성 점유 누락**은 코드/UX 보완 대상으로 기록하되, 기존 `TIaqi4sw0rKvC24Izq5m`의 실제 상태를 먼저 확인해 정상 중복 차단과 orphan 정리를 구별한다.
- 사용자가 콘솔에서 `recruitments/TIaqi4sw0rKvC24Izq5m`가 **존재하지 않음**을 확인했다. 따라서 `니티야`의 4막 `active raidState`는 실제 모집 원본이 없는 고아 점유다. 이 상태에서 같은 `raidState` 경로를 승인 명령이 `set`하면 create가 아닌 lifecycle 전용 update Rules에 막히므로 `permission-denied`가 발생하는 설명이 데이터와 코드 모두에 부합한다. 사용자의 과거 콘솔 모집 삭제가 이 고아 상태를 만들었을 가능성은 높지만 삭제 시각·원본 이력이 없어 생성 경위는 확정하지 않는다. 정상 신규 모집의 승인 경로가 동일 계정에서 성공한 점도 이 방/Character 특이 데이터 결함과 일치한다. 복구는 대상 Player·Character·raid·cycle과 누락 모집 원본을 백업·대조한 별도 승인 절차로 분리한다. 현재 F6-A에서는 `raidState`를 수동 삭제하지 않는다. 아울러 신청 명령이 고아 또는 기존 활성 점유를 pending 신청 전에 분류하지 못해 방장에게 불명확한 권한 팝업을 전달하는 코드/UX 결함은 F6-D의 최소 보완 대상으로 남긴다. 방장 `이슈아이`의 수동 완료 권한 오류와 공통 원인은 아직 입증되지 않았다.
- 수동 완료 별도 실기기 조사(2026-09-18 01:36~01:38): 사용자가 `이슈아이`는 모든 레이드 체크가 권한 팝업으로 실패한다고 확인했다. Player `kVn6KZwZQO6or3BjNYqX`에 구 `activeRaidAssignments` 컬렉션은 없으며 4막 `weeklyRaidClaims`에는 다른 Character `B0CSx2z6wm74Y47ZiFgX`의 수동 Claim만 있다. 진단 로그 추가 APK를 설치해 재현한 결과 완료 Claim Transaction 이전 `_loadConflictContext`의 `applicationRecruitment.get/sAGFlEIyuPaXHttfrRvx`에서 `permission-denied`가 났다(`belgardin` 01:38:22; 앞선 빌드에서 `belgardin`·`horizon_cathedral`도 동일 단계). 이 함수는 해당 Player/주차의 모든 application을 먼저 조회하고 `pending`이면서 `이슈아이` Character인 문서마다 부모 모집을 읽은 후 `raidId`를 비교한다. 따라서 하나의 읽기 불가 pending 신청 모집이 다른 레이드의 수동 체크까지 막을 수 있는 코드 구조가 확인됐다. `recruitments/sAGFlEIyuPaXHttfrRvx`의 존재·visibility·groupId·status, 연결 application 상태를 콘솔 읽기 전용으로 확인하기 전에는 삭제 고아 데이터인지 그룹 접근권 변경인지 판정하지 않는다. 진단 로깅 외 기능·Rules·서버 데이터 변경 없음.
- 사용자가 콘솔에서 `recruitments/sAGFlEIyuPaXHttfrRvx`의 `status=disbanded`, `visibility=group`, `groupId=39tvz2fQaSPcXR0WXN9T`를 확인했다. 즉 모집 원본은 존재하며 종료된 그룹 전용 방이다. Rules의 `canReadRecruitment`는 그룹 전용방에 대해 현재 그룹 membership 또는 해당 방 leader/member를 요구한다. 실기기 `permission-denied`는 이 읽기 권한이 현재 충족되지 않는 상황과 부합한다. 해산 명령은 application을 즉시 삭제하지 않는 장기 계약이고, 수동 Claim 코드가 `pending` application의 부모를 레이드 판별 전에 읽는 구조가 이 종료 이력을 모든 레이드 완료 체크 장애로 증폭시킨다. 그룹 membership 및 이 방의 leader/member 관계는 아직 사용자 데이터로 확인하지 않았으며, 읽기 거부를 단순 Rules 오작동으로 보지 않는다. 수정 전에는 접근 불가 pending 신청의 처리 정책(무시/본인 철회/서버 정리)과 완료 Claim의 최종 차단 보장을 계약으로 결정해야 한다.
- 그룹 원본 추가 확인: `groups/39tvz2fQaSPcXR0WXN9T`는 2026-09-16 18:01:03 `status=softDeleted`, `memberCount=0`, `activeRecruitmentCount=0`, `lastRecruitmentId=sAGFlEIyuPaXHttfrRvx`이며 멤버 컬렉션이 없다. 따라서 해당 그룹 membership을 통한 `canReadRecruitment` 허용 경로는 현재 없다. 이 방의 leader/member 여부는 별도 필드로 확인하지 않았지만 실기기 단건 get 거부가 그 경로도 충족되지 않음을 보여준다. **해산된 그룹 모집의 잔존 pending 신청 → 부모 read deny → 전체 수동 완료 체크 실패**가 재현된 직접 원인이다. 그룹장 Player와 모집방 leader는 서로 다른 개념이므로 그룹 원본의 `leaderPlayerId`가 `이슈아이` Player라고 해서 모집방 읽기 권한을 추정하지 않는다. 데이터 임의 삭제 없이 코드의 영향 차단·이력 처리 계약을 별도 F6-B 수정으로 설계한다.
- 사용자 이력 진술: `이슈아이`로 여러 레이드 모집방을 생성해 테스트하던 중 일부 방의 해산·신청·목록 표시가 비정상적이어서 Firebase 콘솔에서 여러 `recruitments` 문서를 강제 삭제한 기억이 있다. 이는 모집 원본이 없는 `니티야`의 고아 `raidState`가 만들어진 경위와 부합하지만 삭제된 정확한 ID/시각은 미확인이다. 반면 `이슈아이` 완료 체크를 막은 `sAGFlEIyuPaXHttfrRvx` 모집 원본은 현재 `disbanded`로 존재하므로, 이 증상까지 콘솔의 모집 문서 삭제 하나로 설명하지 않는다. 직접 실패 원인은 접근 불가한 종료 그룹방 신청 이력을 수동 완료 검사에서 읽는 코드 경로다.

---

- 열린 항목은 현재 Task와 **별도**로 추적한다.
- 재현이 안정되거나 수정에 들어가면 `NEXT_WORK.md`에 조사/수정 단위로 명시한다.
