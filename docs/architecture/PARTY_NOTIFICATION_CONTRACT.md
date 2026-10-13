# 파티 이벤트 기반 알림 계약

> 기존 서비스 전용 항목은 [원문·출처 기록](../../legacy/firebase/extracted/docs/architecture/PARTY_NOTIFICATION_CONTRACT.md)으로 분리했다. 남은 제품/협업 문맥의 신규 서버 적용 여부는 별도 설계에서 판단한다.

> 2026-09-14 확장성 재설계 결정: 신규 구조는 Player별 이벤트 fan-out 대신 `audiencePlayerIds`를 가진 공용 이벤트 원본을 사용한다. 해산 당시 확정 멤버는 공용 이벤트 수신 대상이 될 수 있지만 pending 신청자별 서버 이벤트는 만들지 않는다. 신청자는 모집 원본의 종료 상태로 항목을 숨기고 기기에서 한 번만 안내한다. 아래 Player별 투영본 내용은 현재 구현 근거이며 신규 구현 계약보다 우선하지 않는다.

## 신규 구조 확정 요약

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/architecture/PARTY_NOTIFICATION_CONTRACT.md#source-0001)로 이동했다.

## 1. 목적과 단계

LOSTPARTY 알림은 파티 명령이 성공했음을 보여 주는 파생 정보다. 알림이 파티 상태 변경의 근거나 명령 자체가 되어서는 안 된다.

구현은 두 단계로 나눈다.




## 2. 현재 구현으로 가능한 범위

현재 구현에는 다음 기반이 있다.

- 사용자별 이벤트 경로: `players/{playerId}/events/{eventId}`
- 읽기 권한: active Auth binding의 현재 Player만 자기 이벤트를 `get/list`
- 현재 이벤트: `partyCompleted`, `partyCompletionCancelled`, `partyIncompleteEnded`
- 회차 명령 Transaction이 회차 상태와 대상 Player별 이벤트를 함께 기록
- `recruitmentId + cycleKey + eventRevision + type` 기반 안정적 이벤트 ID
- 약 28일 `expiresAt`과 생성 후 수정·삭제 금지
- 앱 실행·Player 연결·레이드 현황 진입 시 이벤트를 읽는 동기화 서비스
- Drift v7 `raidHistoryEntries`가 완료 계열 이벤트를 `eventId` 기본 키로 멱등 반영

따라서 현재 구조는 완료 계열 이벤트를 앱 내부 알림에도 표현할 수 있는 기반을 이미 갖는다. 다만 현재 동기화 코드는 완료 히스토리 3종 외 이벤트를 거부하고, 알림 목록·읽음 상태·실시간 listener가 없으며, 가입·멤버십 명령은 이벤트를 기록하지 않는다.

## 3. 검토한 저장 방식

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/architecture/PARTY_NOTIFICATION_CONTRACT.md#source-0006)로 이동했다.

## 4. 추천 저장 모델

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/architecture/PARTY_NOTIFICATION_CONTRACT.md#source-0007)로 이동했다.

## 5. 이벤트 ID와 중복 방지

한 논리 사건의 모든 수신자 투영본은 같은 안정적 `eventId`를 쓴다. 경로가 Player별로 분리되어 충돌하지 않는다.

| 사건 | 기준 |
| --- | --- |
| application 생성·재신청 | `recruitmentId + applicationPlayerId + applicationRevision + applicationSubmitted` |
| 승인·거절·철회 | `recruitmentId + applicationPlayerId + applicationRevision + type` |
| 즉시 가입 | `recruitmentId + joinedPlayerId + recruitmentRevision + memberJoined` |
| 탈퇴·추방·캐릭터 변경 | `recruitmentId + targetPlayerId + recruitmentRevision + type` |
| 파티/슬롯 이동 | `recruitmentId + targetPlayerId + recruitmentRevision + memberMoved` |
| 완료 계열 | 기존 `recruitmentId + cycleKey + completionRevision + type` |
| 종료·해산 | `recruitmentId + cycleKey + recruitmentRevision + type` |

재시도는 같은 경로에 같은 사건을 쓰며 새 알림을 만들지 않는다. 서로 다른 재신청은 application revision이 달라 별도 사건이다.

## 6. 이벤트별 수신 대상과 표시

### 2026-09-05 방별 알림 Projection 후속 변경

- 진행 중 레이드 카드 좌상단에는 현재 사용자가 읽지 않은 `applicationSubmitted`, `memberKicked`, `memberJoined`, `memberCharacterChanged` 이벤트 수를 숫자 red badge로 표시한다. pending 신청 수가 아니라 사용자별 unread event 수다.
- 해당 모집방 상세에 진입하는 즉시 위 네 유형의 방별 이벤트를 읽음 처리한다. 이벤트 히스토리 팝업을 열었는지는 읽음 처리 조건이 아니다.
- 상세의 첫 `파티 구성` 제목 행 우측 알림 아이콘은 해당 `recruitmentId`의 사용자 수신 이벤트 히스토리를 팝업으로 표시한다. 항목 터치 이동은 제공하지 않는다.
- 팝업은 방 전체 감사 로그가 아니라 현재 사용자에게 전달된 이벤트 이력이다. 구현 중 서버 변경이 필요하면 리스트업 범위를 중단하고 별도 승인을 받는다.

문구의 `{행위 캐릭터}`, `{대상 캐릭터}`는 이벤트에 고정된 표시 Snapshot이다. 권한은 Snapshot이 아니라 PlayerId, application, membership과 명령 상태 전이로 판정한다.

| 이벤트 | 행위자 | 수신 대상 | 앱 내부 표시 문구 | 이동 목적지 | 제외 대상 | 필요한 Snapshot | 중복 방지 기준 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 가입 신청 | 신청자 | 발생 시점 파티장. 승인권자 확대는 후속 결정 | `{행위 캐릭터}님이 가입을 신청했습니다.` | 파티 상세의 신청 영역 | 신청자 | 신청 캐릭터명·직업·역할 | application revision + `applicationSubmitted` |
| 신청 승인 | 승인권자 | 신청자 | `가입 신청이 승인되었습니다.` | 파티 상세 | 승인자와 기존 멤버 | 신청 캐릭터명, 승인 결과 | application revision + `applicationApproved` |
| 신청 거절 | 승인권자 | 신청자 | `가입 신청이 거절되었습니다.` | 파티 상세 또는 신청 결과 | 승인자와 기존 멤버 | 신청 캐릭터명, 거절 횟수 선택 | application revision + `applicationRejected` |
| 신청 철회 | 신청자 | 발생 시점 파티장 | `{행위 캐릭터}님이 가입 신청을 철회했습니다.` | 파티 상세의 신청 영역 | 신청자 | 신청 캐릭터명 | application revision + `applicationWithdrawn` |
| 즉시 가입 | 가입자 | 명령 전 확정 멤버 | `{행위 캐릭터}님이 파티에 참가했습니다.` | 파티 상세 | 가입자 | 캐릭터명·직업·역할·파티/슬롯 | recruitment revision + `memberJoined` |
| 파티원 탈퇴 | 탈퇴자 | 명령 전 멤버 중 탈퇴자를 제외한 사람 | `{행위 캐릭터}님이 파티에서 탈퇴했습니다.` | 파티 상세 | 탈퇴자 | 캐릭터명·기존 파티/슬롯 | recruitment revision + `memberLeft` |
| 파티원 추방 | 파티장 | 추방 대상과 명령 후 남은 멤버 | `{대상 캐릭터}님이 파티에서 제외되었습니다.` | 대상: 모집/현황 루트, 남은 멤버: 파티 상세 | 파티장 본인 | 대상 캐릭터명·기존 파티/슬롯 | recruitment revision + `memberKicked` |
| 참가 캐릭터 변경 | 해당 멤버 | 명령 전 확정 멤버 | `{이전 캐릭터}님이 참가 캐릭터를 {새 캐릭터}(으)로 변경했습니다.` | 파티 상세 | 변경한 본인 | 이전·새 캐릭터명/직업·유지된 역할/슬롯 | recruitment revision + `memberCharacterChanged` |
| 파티 또는 슬롯 이동 | 파티장 또는 권한 있는 이동 주체 | 이동 대상과 현재 확정 멤버 | `{대상 캐릭터}님의 위치가 변경되었습니다.` | 파티 상세 | 행위자 본인만 제외하되 대상이면 수신 | 대상 캐릭터명·이전/새 파티·슬롯 | recruitment revision + `memberMoved` |
| 회차 완료 | 파티장 | 완료 Snapshot의 전 멤버 | `파티 회차가 완료되었습니다.` | 해당 완료 기록 | 없음 | raid/difficulty·cycle·수신자 캐릭터·완료 구성 | completion revision + `partyCompleted` |
| 완료 취소(과거 호환) | 생성 안 함 | 과거 이벤트의 기존 수신자 | 기존 문구를 히스토리에서만 표시 | 해당 완료 기록 | 없음 | 과거 payload | 과거 `partyCompletionCancelled` 읽기 전용 |
| 파티 종료 | 시스템 또는 파티장 | 종료 직전 확정 멤버 | `파티 모집이 종료되었습니다.` | 파티 상세 또는 현황 루트 | 시스템 actor, pending 신청자는 로컬 파생 안내 | raid/difficulty·cycle·종료 사유 | recruitment/completion revision + `partyEnded` |
| 모집 해산 | 파티장 | 해산 직전 확정 멤버 | `파티 모집이 해산되었습니다.` | 레이드 현황 또는 모집 목록 | 파티장 본인, pending 신청자는 로컬 파생 안내 | raid/difficulty·cycle | recruitment revision + `partyDisbanded` |


### 수신 시점 기준

- 가입·캐릭터 변경·이동은 명령 직전 멤버 집합을 기준으로 하되 새 가입자는 행위자 제외 규칙으로 제외한다.
- 탈퇴는 명령 직전 멤버 집합에서 탈퇴자를 제외한다.
- 추방은 추방 대상과 명령 후 남은 멤버가 받는다.
- 완료는 mutable 현재 membership이 아니라 해당 회차 Snapshot을 기준으로 한다. 완료 취소 이벤트는 신규 생성하지 않는다.
- 해산·종료 공용 이벤트는 상태 변경 직전 확정 멤버를 기준으로 한다. pending 신청자는 참조 모집의 종료 상태를 읽어 신청 항목을 숨기고 로컬 1회 안내를 만든다.
- 알림 생성 뒤 membership이 바뀌어도 해당 Player Event는 28일 동안 자기 경로에서 읽을 수 있다.

## 7. 읽음 상태

초기 읽음 상태는 **Drift 로컬 DB**에 `eventId`별로 저장한다.

권장 필드:

```text
eventId (primary key)
playerId
readAt nullable
firstSyncedAt
lastSyncedAt
```

- 알림 목록을 열었다는 이유만으로 전체를 자동 읽음 처리하지 않고, 항목 선택 또는 명시적 전체 읽음 동작의 도입 여부를 UI 작업에서 정한다.
- 초기에는 여러 기기, 재설치 사이 읽음 상태를 동기화하지 않는다. 새 기기에서는 최근 28일 이벤트가 다시 읽지 않음으로 보일 수 있음을 허용한다.
- 완료 이벤트의 `raidHistoryEntries.visibility/localStatusOverride`는 알림 읽음과 의미가 다르므로 재사용하지 않는다.
- 가입 신청·추방·참가·참가 Character 변경은 전역 알림함이 아니라 진행 중 카드의 방별 unread 숫자로 표시한다. 해당 모집 상세에 진입하면 팝업 열람 여부와 무관하게 그 방의 네 유형만 읽음 처리한다.
- `파티 구성` 우측 히스토리 팝업은 현재 Player에게 전달된 해당 방 receipt만 시간순으로 보여 주며 항목 이동 동작은 없다.
- 기기 간 읽음 동기화가 제품 요구가 되면 `players/{playerId}/notificationState` 또는 사용자별 receipt를 별도 계약으로 추가한다. 모든 이벤트 문서를 update 가능하게 바꾸지 않는다.

## 8. 읽기와 비용 정책

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/architecture/PARTY_NOTIFICATION_CONTRACT.md#source-0011)로 이동했다.

## 9. Spark에서 보안상 금지하는 구조

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/architecture/PARTY_NOTIFICATION_CONTRACT.md#source-0012)로 이동했다.

## 10. 앱 내부 알림 구현 작업 분해

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/architecture/PARTY_NOTIFICATION_CONTRACT.md#source-0013)로 이동했다.

## 11. 향후 FCM 확장

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/architecture/PARTY_NOTIFICATION_CONTRACT.md#source-0014)로 이동했다.

## 12. 전체·방별 설정

- 전체 알림 설정은 새 파티에 적용할 초기 기본값이다.
- 방별 알림 설정은 가입 시 복사된 뒤 독립적으로 유지한다.
- 필수 결과 알림(본인 신청 승인·거절, 본인 추방)을 사용자가 끌 수 있는지는 미확정이다. 완료 취소 알림은 신규 생성하지 않는다.

## 13. 미확정 항목

실제 구현 전에 다음을 작업 단위에서 확정한다.

1. 가입 신청을 파티장만 받을지 모든 `canApproveApplications` 멤버가 받을지
2. 거절 알림에 누적 거절 횟수를 표시할지
3. 추방 알림 선택 시 삭제된 상세의 읽기 전용 Snapshot을 제공할지 목록으로 보낼지
4. ~~해산·종료 pending 신청자 처리~~ — 모집 원본 종료 확인, 자동 숨김, 로컬 1회 안내로 확정
5. `partyIncompleteEnded`를 사용자 알림으로 노출할지 완료 기록에만 반영할지
6. 알림 목록 초기 limit과 추가 페이지 제공 여부
7. 항목 선택 시 읽음, 화면 노출 시 읽음, 전체 읽음 중 최소 UX
8. 로컬 이벤트/receipt 자동 정리 시점 — 첫 출시 완료 조건에서 제외, 추후 운영 결정
9. 필수 결과 이벤트와 선택 가능한 방별 알림의 구분
11. 향후 Cloud Functions와 별도 서버의 비용·운영·재시도 비교

## 14. 다른 작업과의 우선순위

1. Task-072 알림 계약 문서화 — 현재 작업
3. 앱 내부 알림 구현 2단계(명령별 이벤트·로컬 Projection·최소 UI)
4. 상세 최근 10개 텍스트 채팅
5. 빈 슬롯 조건, 공개 목록 필터, 레이드 현황 필터
6. 파티·슬롯 이동/스왑 이벤트는 해당 명령 구현과 함께 확장
7. 그룹 모집 이벤트는 그룹 기능 구현과 함께 확장

열린 BUG-002/005/006은 알림 계약에 섞지 않고 별도 우선순위로 관리한다.
