# Firestore 파티 이벤트와 로컬 히스토리 계약

## 서버 이벤트

- 경로는 `players/{playerId}/events/{eventId}`이며 해당 Player만 읽는다.
- 회차 Transaction은 `partyCompleted`, `partyIncompleteEnded`, `partyCompletionCancelled` 이벤트를 완료 당시 대상 Player별로 함께 생성한다.
- 이벤트 ID는 `recruitmentId + cycleKey + completionRevision + type` 조합으로 멱등성을 보장한다.
- 이벤트는 회차 문서의 상태·revision·Player Snapshot과 결합해 Rules가 검증하며 생성 후 수정·삭제하지 않는다.
- `occurredAt`은 서버 시간이고 `expiresAt`은 약 28일 뒤다. TTL 자동 삭제 설정은 배포 작업에서 별도 확인한다.

## 로컬 히스토리

- Drift v7 `raidHistoryEntries`가 이벤트 ID를 기본 키로 저장한다.
- 서버 상태는 `completed / incompleteEnded / completionCancelled`, 출처는 `partyEvent`다.
- 같은 이벤트를 재동기화하면 서버 상태와 동기화 시각만 갱신하고 `visibility`와 `localStatusOverride`는 유지한다.
- 사용자의 숨김은 서버에 전송하지 않으며 `visible / hidden`으로 로컬에만 저장한다.
- 완료 취소 이벤트가 와도 사용자의 기록을 강제로 변경하지 않고 `localStatusOverride`로 완료 유지 또는 미완료 정정을 선택할 수 있다.

## 동기화

- active Auth binding의 Player 이벤트만 읽어 시간순으로 로컬 DB에 멱등 반영한다.
- 앱 실행, Player 연결 완료, 레이드 현황 진입과 알림 진입이 동기화 계기다.
- 푸시 알림은 동기화 계기일 뿐 로컬 DB의 직접 변경 명령이 아니다.
- `레이드 현황 > 완료 기록`은 Drift 로컬 기록을 단일 기준으로 표시한다. 숨김과 로컬 정정은 이 기기에서만 적용하고 서버에 전송하지 않는다.
- FCM과 OS 알림 권한은 아직 연결하지 않는다.
