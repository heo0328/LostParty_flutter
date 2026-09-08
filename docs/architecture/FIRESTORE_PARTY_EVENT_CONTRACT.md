# Firestore 파티 이벤트와 로컬 히스토리 계약

파티 이벤트 전체를 앱 내부 알림과 향후 FCM의 공통 원본으로 확장하는 기준은 [`PARTY_NOTIFICATION_CONTRACT.md`](PARTY_NOTIFICATION_CONTRACT.md)를 따른다. 이 문서는 현재 구현된 완료 계열 이벤트와 Drift 완료 히스토리 Projection의 세부 계약이다.

## 서버 이벤트

- 경로는 `players/{playerId}/events/{eventId}`이며 해당 Player만 읽는다.
- 회차 Transaction은 `partyCompleted`, `partyIncompleteEnded`, `partyCompletionCancelled` 이벤트를 완료 당시 대상 Player별로 함께 생성한다.
- 이벤트 ID는 `recruitmentId + cycleKey + completionRevision + type` 조합으로 멱등성을 보장한다.
- 이벤트는 회차 문서의 상태·revision·Player Snapshot과 결합해 Rules가 검증하며 생성 후 수정·삭제하지 않는다.
- `occurredAt`은 서버 시간이고 `expiresAt`은 약 28일 뒤다. TTL 자동 삭제 설정은 배포 작업에서 별도 확인한다.
- Task-073부터 create는 `validPlayerEvent`로 type별 분기한다. 완료 3종은 기존 `validCycleEvent`를 유지하고, 신청·멤버십·해산(`partyDisbanded`) type은 같은 Transaction의 상태 전이가 있을 때만 허용한다. `memberMoved`·`partyEnded`와 일반 create는 아직 열지 않는다.
- 완료 계열 payload는 `keys().hasOnly`로 허용 필드를 제한하며 자유 문구·AuthUid·토큰 필드를 거부한다.

## 로컬 히스토리

- Drift v7 `raidHistoryEntries`가 이벤트 ID를 기본 키로 저장한다.
- 서버 상태는 `completed / incompleteEnded / completionCancelled`, 출처는 `partyEvent`다.
- 같은 이벤트를 재동기화하면 서버 상태와 동기화 시각만 갱신하고 `visibility`와 `localStatusOverride`는 유지한다.
- 사용자의 숨김은 서버에 전송하지 않으며 `visible / hidden`으로 로컬에만 저장한다.
- 완료 취소 이벤트가 와도 과거 Drift 히스토리 표시는 사용자의 `localStatusOverride`를 유지한다. 다만 허용된 파티 전체 완료 취소 Transaction은 출처가 일치하는 서버 Claim을 삭제하므로 현재 주차 내 계정 체크박스는 미완료로 갱신된다.
- 완료 3종 외 type(알림·미래 type 포함)은 히스토리 sync에서 건너뛰며 전체 sync 실패로 만들지 않는다.

## 로컬 알림 receipt

- Drift v8 `partyNotificationReceipts`가 알림 후보 이벤트의 로컬 Projection이다.
- 권장 필드: `eventId`, `playerId`, `type`, `recruitmentId`, `occurredAt`, `expiresAt`, `readAt`, `firstSyncedAt`, `lastSyncedAt`와 표시용 Snapshot.
- 같은 이벤트를 재동기화해도 `readAt`은 유지하고 서버 표시 필드·`lastSyncedAt`만 갱신한다.
- unread는 만료되지 않았고 `readAt`이 null인 receipt 수로 계산한다.
- 가입 신청·추방·참가·참가 Character 변경은 전역 알림 목록에서 제외하고 `recruitmentId`별 unread로 계산해 진행 중 레이드 카드에 표시한다.
- 모집 상세 진입은 해당 방의 위 네 유형 receipt만 일괄 읽음 처리한다. 상세의 히스토리는 현재 Player에게 전달된 로컬 receipt만 표시한다.
- 완료 히스토리의 숨김·로컬 정정과 알림 읽음은 서로 다른 Projection이며 재사용하지 않는다.

## 동기화

- active Auth binding의 Player 이벤트만 읽어 시간순으로 로컬 DB에 멱등 반영한다.
- 한 번의 이벤트 query로 완료 히스토리와 알림 receipt Projection을 함께 갱신할 수 있다.
- 앱 실행, Player 연결 완료, 레이드 현황 진입과 알림 진입이 동기화 계기다.
- 푸시 알림은 동기화 계기일 뿐 로컬 DB의 직접 변경 명령이 아니다.
- `레이드 현황 > 완료 기록`은 Drift 로컬 기록을 단일 기준으로 표시한다. 숨김과 로컬 정정은 이 기기에서만 적용하고 서버에 전송하지 않는다.
- 최근 이벤트 읽기 Repository는 자기 Player 경로에서 `occurredAt desc`와 작은 limit만 사용한다.
- 알림 UI는 receipt·unread count를 소비하는 후속 작업이다. FCM과 OS 알림 권한은 신뢰할 수 있는 서버가 준비될 때까지 연결하지 않는다.
