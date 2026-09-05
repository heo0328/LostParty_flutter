# 파티 이벤트 기반 알림 계약

## 1. 목적과 단계

LOSTPARTY 알림은 파티 명령이 성공했음을 보여 주는 파생 정보다. 알림이 파티 상태 변경의 근거나 명령 자체가 되어서는 안 된다.

구현은 두 단계로 나눈다.

1. Spark 무료 요금제에서 공통 파티 이벤트 기반 앱 내부 알림을 먼저 구현한다.
2. 신뢰할 수 있는 서버가 준비되면 같은 이벤트를 검증하고 FCM을 발송한다.

앱 내부 알림과 FCM에 서로 다른 메시지 생성 로직을 만들지 않는다. 이벤트 `type`과 검증된 Snapshot을 공통 원본으로 사용하고, 앱과 향후 서버가 동일한 메시지 템플릿을 해석한다.

현재 Task-072는 설계만 확정한다. 앱 UI, Drift migration, Firestore Rules, FCM, TTL과 유료 서비스는 구현하거나 배포하지 않는다.

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

| 방식 | 장점 | 문제 | 결정 |
| --- | --- | --- | --- |
| 기존 파티/신청/membership 문서를 직접 조회해 알림으로 해석 | 추가 쓰기 없음 | 상태가 덮어써져 과거 사건·발생 시점·중복 방지를 보존하지 못함. 탈퇴·추방 후 권한이 사라지고 신청자 결과 조회도 복잡함 | 사용하지 않음 |
| 모집 아래 공통 이벤트 하나를 모든 대상이 조회 | 사건 원본이 한 문서 | 현재 membership 기준 Rules는 탈퇴·추방된 수신자와 비회원 신청자를 안전하게 계속 허용하기 어렵고, 공개 모집에서는 수신자·행위 정보 노출 위험이 있음 | 앱 알림 저장소로 사용하지 않음 |
| 사용자별 알림 문서를 별도 생성 | 자기 경로 query가 단순하고 탈퇴 후에도 28일 확인 가능 | 자유 형식 클라이언트 쓰기를 허용하면 다른 사용자에게 위조 알림 생성 가능 | 기존 Player Event의 엄격한 투영본으로만 사용 |
| 공통 이벤트 + 로컬 읽음 상태 | 서버 쓰기와 읽기 비용이 작고 기존 Drift 방식과 맞음 | 기기 간 읽음 동기화가 되지 않음 | 초기 권장 모델 |

## 4. 추천 저장 모델

### 4.1 논리 이벤트와 사용자별 투영본

파티 명령 한 번에 하나의 **논리 Party Event**가 발생한다. Spark 단계에서는 별도 공개 공통 이벤트 문서를 만들지 않고, 같은 `eventId`, `type`, 발생 시각과 Snapshot을 대상별 비공개 Player Event에 투영한다.

```text
players/{recipientPlayerId}/events/{eventId}
```

여러 수신자에게 저장되는 문서는 같은 논리 사건을 나타내며 `recipientPlayerId`만 다르다. 향후 서버는 이 사용자별 이벤트 생성 또는 검증된 outbox를 소비하되 `eventId`로 중복 FCM을 방지한다.

이 모델을 선택하는 이유는 다음과 같다.

- 현재 Rules와 동기화 경로를 확장할 수 있다.
- 현재 membership을 잃은 탈퇴자·추방자도 자기 이벤트를 읽을 수 있다.
- 아직 멤버가 아닌 신청자도 승인·거절 결과를 자기 경로에서 안전하게 읽는다.
- 다른 Player의 전체 알림 목록이나 FCM 토큰을 읽을 필요가 없다.
- 공개 모집 문서에 수신자 목록이나 개인 행동 이력을 노출하지 않는다.

### 4.2 최소 필드

모든 이벤트는 최소 다음 의미를 갖는다. 실제 필드 허용 목록은 이벤트 유형별 Rules에서 더 좁게 제한한다.

```text
schemaVersion
eventId
type
recipientPlayerId
recruitmentId
cycleKey?                 // 회차 관련 이벤트
commandRevision           // 모집/application/completion revision 중 해당 사건 기준
actorPlayerId?            // 권한 검증용, UI 비노출
actorCharacterNameSnapshot?
targetPlayerId?           // 권한 검증용, UI 비노출
targetCharacterNameSnapshot?
raidId?
difficultyId?
partyIndex?
slotIndex?
occurredAt
expiresAt
```

클라이언트가 완성된 자유 문구를 저장하지 않는다. UI는 `type`과 필요한 표시 Snapshot으로 정해진 문구를 만든다. AuthUid, 토큰, 서비스 계정 정보는 이벤트에 저장하거나 UI에 표시하지 않는다.

### 4.3 생성 원칙과 보안

- 가능한 이벤트는 파티 명령의 상태 변경과 같은 Firestore Transaction에서 생성한다.
- `players/*/events/*`에 일반 create 권한을 열지 않는다.
- 이벤트 유형별 Rules가 호출자, 상태의 전후 변화, 정확한 수신자, 허용 필드, `request.time`, event ID와 revision을 검증한다.
- 행위자 본인을 제외하는 이벤트는 Rules에서도 `recipientPlayerId != actorPlayerId`를 확인한다.
- 같은 명령 상태 전이가 없으면 이벤트만 단독 생성할 수 없어야 한다.
- 수신자 전원에게 이벤트가 생성됐는지까지 Security Rules만으로 완전히 보장하기 어려운 명령은 Spark 한계로 기록한다. 클라이언트 Transaction은 전원을 쓰되, 향후 신뢰 서버가 완전성을 보강한다.
- 이벤트 쓰기 수가 Firestore Transaction 한도 또는 Rules 문서 접근 한도에 가까워지는 대규모 그룹 알림은 Spark 범위에서 제외한다. 현재 파티 최대 8인은 대상이다.

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

### 2026-09-05 알림 Projection 후속 변경

- `applicationSubmitted`와 `memberCharacterChanged` 이벤트 생성·보관 계약은 유지하되 레이드 현황 상단 알림 목록과 unread count의 후보에서는 제외한다.
- 가입 신청 확인은 알림 목록 대신 내가 만든 활성 모집방 카드의 pending 신청 수 red badge로 제공한다.
- 신청 데이터는 이미 `recruitments/{recruitmentId}/applications`에 연결되어 있고 방 단위 조회 스트림이 있으므로 신규 서버 필드 없이 구현 가능하다. 현재 `ActiveRaidSummary`에는 건수가 없으므로 소유 방별 클라이언트 구독·pending 집계·해제 및 읽기 비용 검증은 필요하다.
- 구현 과정에서 신규 Rules·인덱스·서버 집계 필드가 필요하다고 확인되면 배지 작업을 중단하고 별도 승인을 받는다.

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
| 완료 취소 | 파티장 | 취소 대상 회차 Snapshot의 전 멤버 | `파티 완료가 취소되었습니다. 기록을 확인해주세요.` | 해당 완료 기록 정정 화면 | 없음 | raid/difficulty·cycle·수신자 캐릭터 | completion revision + `partyCompletionCancelled` |
| 파티 종료 | 시스템 또는 파티장 | 종료 직전 확정 멤버와 필요 시 pending 신청자 | `파티 모집이 종료되었습니다.` | 파티 상세 또는 현황 루트 | 시스템 actor | raid/difficulty·cycle·종료 사유 | recruitment/completion revision + `partyEnded` |
| 모집 해산 | 파티장 | 해산 직전 멤버와 pending 신청자 | `파티 모집이 해산되었습니다.` | 레이드 현황 또는 모집 목록 | 파티장 본인 | raid/difficulty·cycle·대상 캐릭터(신청자) | recruitment revision + `partyDisbanded` |

`partyIncompleteEnded`는 회차 완료 히스토리 동기화에는 유지하지만 초기 알림 노출 여부는 미확정이다. 수요일 자동 전환을 신뢰 서버 없이 보장할 수 없으므로 Spark 클라이언트 명령에서 임의 생성하지 않는다.

### 수신 시점 기준

- 가입·캐릭터 변경·이동은 명령 직전 멤버 집합을 기준으로 하되 새 가입자는 행위자 제외 규칙으로 제외한다.
- 탈퇴는 명령 직전 멤버 집합에서 탈퇴자를 제외한다.
- 추방은 추방 대상과 명령 후 남은 멤버가 받는다.
- 완료·완료 취소는 mutable 현재 membership이 아니라 해당 회차 Snapshot을 기준으로 한다.
- 해산·종료는 상태 변경 직전 멤버와 아직 결과를 기다리는 pending 신청자를 기준으로 한다.
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

- 이벤트 원본은 Firestore, 읽음 여부는 기기 로컬 Projection이다.
- 알림 목록을 열었다는 이유만으로 전체를 자동 읽음 처리하지 않고, 항목 선택 또는 명시적 전체 읽음 동작의 도입 여부를 UI 작업에서 정한다.
- 초기에는 여러 기기, 재설치 사이 읽음 상태를 동기화하지 않는다. 새 기기에서는 최근 28일 이벤트가 다시 읽지 않음으로 보일 수 있음을 허용한다.
- 완료 이벤트의 `raidHistoryEntries.visibility/localStatusOverride`는 알림 읽음과 의미가 다르므로 재사용하지 않는다.
- 기기 간 읽음 동기화가 제품 요구가 되면 `players/{playerId}/notificationState` 또는 사용자별 receipt를 별도 계약으로 추가한다. 모든 이벤트 문서를 update 가능하게 바꾸지 않는다.

## 8. 읽기와 비용 정책

- 앱 foreground에서는 현재 Player의 최근 이벤트 query를 실시간 구독한다.
- 앱 재실행·Player binding 완료 시 최근 이벤트를 일회 동기화한다.
- 초기 목록은 `occurredAt desc`와 작은 limit(예: 20)만 사용하고, 전체 28일 이벤트를 매 화면 진입마다 무제한 읽지 않는다.
- 알림 아이콘의 unread count는 로컬에 동기화된 최근 이벤트와 로컬 receipt로 계산한다.
- 완료 히스토리 동기화와 알림 동기화는 같은 Firestore query 결과를 공유할 수 있지만, Drift 완료 기록과 알림 receipt는 서로 다른 Projection으로 유지한다.
- 이벤트 만료 후 로컬 알림 보관 기간은 구현 전에 정한다. 초기 권장은 Firestore와 같은 28일이다.

## 9. Spark에서 보안상 금지하는 구조

- Flutter가 다른 Player 경로에 임의 type, 문구, 수신자를 넣어 create하는 일반 권한
- 공개 모집 하위 컬렉션을 모든 사용자의 공용 알림함으로 사용하는 구조
- 현재 membership만으로 과거 이벤트 읽기 권한을 판정하는 구조
- Flutter가 다른 사용자의 FCM 토큰을 읽거나 FCM HTTP API를 직접 호출하는 구조
- 서비스 계정, 서버 키, FCM 발송 자격 증명을 앱이나 공개 문서에 포함하는 구조
- 알림 문서를 먼저 쓰고 이를 파티 상태 변경의 근거로 사용하는 구조
- 완료 히스토리의 로컬 정정·숨김을 서버 알림 읽음 상태로 오해하는 구조

## 10. 앱 내부 알림 구현 작업 분해

Task-072 이후 실제 구현은 한 작업에 묶지 않고 다음 순서로 나눈다.

1. **알림 이벤트 schema·Rules 기반**
   - 이벤트 enum/DTO/mapper, 이벤트 ID 생성기
   - 자기 Player Event 읽기 query와 이벤트별 create Rules 테스트
   - 현재 완료 이벤트 하위 호환 유지
2. **신청 이벤트 연결**
   - 신청·재신청·철회·승인·거절 Transaction에 대상별 이벤트 추가
   - 비회원 신청자와 파티장 수신 권한 검증
3. **가입·멤버십 이벤트 연결**
   - 즉시 가입·탈퇴·추방·캐릭터 변경 Transaction 이벤트
   - 명령 전/후 멤버 집합과 추방 대상 처리 검증
4. **회차·종료 이벤트 확장**
   - 기존 완료 3종을 공통 알림 모델로 읽기
   - 종료·해산 대상과 pending 신청자 처리
5. **로컬 알림 Projection**
   - Drift migration과 event receipt/readAt
   - 제한 query, 멱등 sync, unread 계산
6. **최소 UI**
   - 알림 아이콘·읽지 않은 개수·최근 목록·읽음 처리
   - 이벤트별 문구와 파티 상세/완료 기록 딥링크
7. **실기기 다중 사용자 검증**
   - foreground 실시간, 종료 후 재실행 동기화
   - 재시도 중복 방지, 탈퇴·추방 후 자기 이벤트 읽기

각 단계는 현재 파티 명령의 제품 동작을 확장하지 않고 이벤트 기록·표시만 추가한다.

## 11. 향후 FCM 확장

```text
파티 명령 성공
→ 공통 논리 Party Event의 사용자별 Player Event 기록
→ 신뢰할 수 있는 서버가 이벤트와 상태 전이를 검증
→ 서버가 수신 대상·전체/방별 알림 설정·토큰 상태 확인
→ eventId 기준 중복 방지 후 FCM 발송
→ 앱은 같은 Player Event를 내부 알림 목록에 표시
```

- Cloud Functions 또는 별도 서버 선택은 Blaze/운영 비용 합의 때 결정한다.
- 서버만 FCM 토큰과 발송 자격 증명에 접근한다.
- FCM payload는 `eventId`, 안전한 route 식별자와 최소 type만 전달하며 신뢰 데이터로 사용하지 않는다.
- 푸시 선택 시 앱은 Player Event를 다시 읽고 권한과 최신 화면 상태를 확인한다.
- FCM 실패가 파티 명령을 롤백하지 않는다. 서버는 eventId별 발송 상태와 재시도 정책을 별도로 관리한다.
- FCM 추가 후에도 앱 내부 알림 저장·UI·읽음 Projection을 교체하지 않는다.

## 12. 전체·방별 설정

- 전체 알림 설정은 새 파티에 적용할 초기 기본값이다.
- 방별 알림 설정은 가입 시 복사된 뒤 독립적으로 유지한다.
- 필수 결과 알림(본인 신청 승인·거절, 본인 추방, 완료 취소)을 사용자가 끌 수 있는지는 미확정이다.
- Spark 앱 내부 알림 1차에서는 복잡한 세부 설정 UI를 구현하지 않는다.
- 향후 서버는 FCM 발송 전에 설정을 확인하지만, 이벤트 원본 자체는 히스토리·앱 동기화를 위해 설정과 무관하게 생성하는 것을 기본안으로 한다.

## 13. 미확정 항목

실제 구현 전에 다음을 작업 단위에서 확정한다.

1. 가입 신청을 파티장만 받을지 모든 `canApproveApplications` 멤버가 받을지
2. 거절 알림에 누적 거절 횟수를 표시할지
3. 추방 알림 선택 시 삭제된 상세의 읽기 전용 Snapshot을 제공할지 목록으로 보낼지
4. 해산·종료 시 pending 신청자에게 남길 최소 Snapshot과 상세 접근 방식
5. `partyIncompleteEnded`를 사용자 알림으로 노출할지 완료 기록에만 반영할지
6. 알림 목록 초기 limit과 추가 페이지 제공 여부
7. 항목 선택 시 읽음, 화면 노출 시 읽음, 전체 읽음 중 최소 UX
8. 로컬 이벤트/receipt를 28일 뒤 자동 정리할 시점
9. 필수 결과 이벤트와 선택 가능한 방별 알림의 구분
10. 클라이언트 Transaction의 수신자 이벤트 완전성 한계를 수용할 기간과 서버 전환 조건
11. 향후 Cloud Functions와 별도 서버의 비용·운영·재시도 비교

## 14. 다른 작업과의 우선순위

1. Task-072 알림 계약 문서화 — 현재 작업
2. 앱 내부 알림 구현 1단계(이벤트 schema·Rules)
3. 앱 내부 알림 구현 2단계(명령별 이벤트·로컬 Projection·최소 UI)
4. 상세 최근 10개 텍스트 채팅
5. 빈 슬롯 조건, 공개 목록 필터, 레이드 현황 필터
6. 파티·슬롯 이동/스왑 이벤트는 해당 명령 구현과 함께 확장
7. 그룹 모집 이벤트는 그룹 기능 구현과 함께 확장
8. FCM은 신뢰 서버와 유료 플랜을 별도 승인한 뒤 진행

열린 BUG-002/005/006은 알림 계약에 섞지 않고 별도 우선순위로 관리한다.
