# 기존 서비스 발췌 — docs/architecture/PARTY_NOTIFICATION_CONTRACT.md

원본 문서: docs/architecture/PARTY_NOTIFICATION_CONTRACT.md ([현재 문서](../../../../../docs/architecture/PARTY_NOTIFICATION_CONTRACT.md)). 분리일: 2026-10-13.
원본 전체 SHA256: 171e2093c7eb4668b66418f3c2e6c69f6d9078c3004ff605909ae911c3a619f0.
아래는 기존 Firebase 환경의 원문이다. 신규 서버의 실행 지시/배포 승인으로 사용하지 않는다. 행 범위는 분리 직전이며 링크 위치만 조정한다.

<a id="source-0001"></a>

## 발췌 1: ## 신규 구조 확정 요약

출처: docs/architecture/PARTY_NOTIFICATION_CONTRACT.md · 원본 5~14행 · 원문 절: ## 신규 구조 확정 요약.

## 신규 구조 확정 요약

- 파티 사건은 `partyEvents/{eventId}` 한 건으로 저장하고 `audiencePlayerIds`로 수신자와 읽기 권한을 고정한다.
- 사용자별 `players/{playerId}/events/{eventId}` 복제는 신규 명령에서 만들지 않는다.
- 읽음은 기기 로컬 receipt/cursor로 관리하며 공용 이벤트 원본을 수정하지 않는다.
- 해산·종료의 pending 신청자는 공용 이벤트 수신자가 아니다. 참조 모집의 `terminalStatus`와 `terminalRevision`으로 신청을 숨기고 `recruitmentId + terminalRevision + terminalStatus` 키의 로컬 안내를 한 번 표시한다.
- 첫 출시에서 이벤트·receipt 자동 만료 정리를 완료 조건으로 두지 않는다. 작은 limit과 cursor로 읽기량을 제한하고, 서버 정리는 추후 운영 작업으로 분리한다.

이하의 사용자별 Player Event 경로·28일 만료·단계별 구현 내용은 현재 구현의 역사적 계약이다. 신규 구현을 설계하거나 검증할 때는 위 요약과 [`PARTY_GROUP_COMMAND_SCALABILITY_REDESIGN.md`](../../../docs/architecture/PARTY_GROUP_COMMAND_SCALABILITY_REDESIGN.md)를 우선한다.


<a id="source-0002"></a>

## 발췌 2: ## 1. 목적과 단계

출처: docs/architecture/PARTY_NOTIFICATION_CONTRACT.md · 원본 21~21행 · 원문 절: ## 1. 목적과 단계.

1. Spark 무료 요금제에서 공통 파티 이벤트 기반 앱 내부 알림을 먼저 구현한다.

<a id="source-0003"></a>

## 발췌 3: ## 1. 목적과 단계

출처: docs/architecture/PARTY_NOTIFICATION_CONTRACT.md · 원본 22~22행 · 원문 절: ## 1. 목적과 단계.

2. 신뢰할 수 있는 서버가 준비되면 같은 이벤트를 검증하고 FCM을 발송한다.

<a id="source-0004"></a>

## 발췌 4: ## 1. 목적과 단계

출처: docs/architecture/PARTY_NOTIFICATION_CONTRACT.md · 원본 24~24행 · 원문 절: ## 1. 목적과 단계.

앱 내부 알림과 FCM에 서로 다른 메시지 생성 로직을 만들지 않는다. 이벤트 `type`과 검증된 Snapshot을 공통 원본으로 사용하고, 앱과 향후 서버가 동일한 메시지 템플릿을 해석한다.

<a id="source-0005"></a>

## 발췌 5: ## 1. 목적과 단계

출처: docs/architecture/PARTY_NOTIFICATION_CONTRACT.md · 원본 26~26행 · 원문 절: ## 1. 목적과 단계.

현재 Task-072는 설계만 확정한다. 앱 UI, Drift migration, Firestore Rules, FCM, TTL과 유료 서비스는 구현하거나 배포하지 않는다.

<a id="source-0006"></a>

## 발췌 6: ## 3. 검토한 저장 방식

출처: docs/architecture/PARTY_NOTIFICATION_CONTRACT.md · 원본 43~51행 · 원문 절: ## 3. 검토한 저장 방식.

## 3. 검토한 저장 방식

| 방식 | 장점 | 문제 | 결정 |
| --- | --- | --- | --- |
| 기존 파티/신청/membership 문서를 직접 조회해 알림으로 해석 | 추가 쓰기 없음 | 상태가 덮어써져 과거 사건·발생 시점·중복 방지를 보존하지 못함. 탈퇴·추방 후 권한이 사라지고 신청자 결과 조회도 복잡함 | 사용하지 않음 |
| 모집 아래 공통 이벤트 하나를 모든 대상이 조회 | 사건 원본이 한 문서 | 현재 membership 기준 Rules는 탈퇴·추방된 수신자와 비회원 신청자를 안전하게 계속 허용하기 어렵고, 공개 모집에서는 수신자·행위 정보 노출 위험이 있음 | 앱 알림 저장소로 사용하지 않음 |
| 사용자별 알림 문서를 별도 생성 | 자기 경로 query가 단순하고 탈퇴 후에도 28일 확인 가능 | 자유 형식 클라이언트 쓰기를 허용하면 다른 사용자에게 위조 알림 생성 가능 | 기존 Player Event의 엄격한 투영본으로만 사용 |
| 공통 이벤트 + 로컬 읽음 상태 | 서버 쓰기와 읽기 비용이 작고 기존 Drift 방식과 맞음 | 기기 간 읽음 동기화가 되지 않음 | 초기 권장 모델 |


<a id="source-0007"></a>

## 발췌 7: ## 4. 추천 저장 모델

출처: docs/architecture/PARTY_NOTIFICATION_CONTRACT.md · 원본 52~107행 · 원문 절: ## 4. 추천 저장 모델.

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


<a id="source-0008"></a>

## 발췌 8: ### 2026-09-05 방별 알림 Projection 후속 변경

출처: docs/architecture/PARTY_NOTIFICATION_CONTRACT.md · 원본 131~131행 · 원문 절: ### 2026-09-05 방별 알림 Projection 후속 변경.

- 이벤트는 `players/{playerId}/events`에 있고 각 문서가 이미 `recruitmentId`를 가진다. 기존 조회 결과와 로컬 receipt를 방별로 분류하므로 서버 저장 구조·Rules·인덱스를 변경하지 않는다.

<a id="source-0009"></a>

## 발췌 9: ### 2026-09-05 방별 알림 Projection 후속 변경

출처: docs/architecture/PARTY_NOTIFICATION_CONTRACT.md · 원본 152~152행 · 원문 절: ### 2026-09-05 방별 알림 Projection 후속 변경.

`partyIncompleteEnded`는 회차 완료 히스토리 동기화에는 유지하지만 초기 알림 노출 여부는 미확정이다. 수요일 자동 전환을 신뢰 서버 없이 보장할 수 없으므로 Spark 클라이언트 명령에서 임의 생성하지 않는다.

<a id="source-0010"></a>

## 발췌 10: ## 7. 읽음 상태

출처: docs/architecture/PARTY_NOTIFICATION_CONTRACT.md · 원본 177~177행 · 원문 절: ## 7. 읽음 상태.

- 이벤트 원본은 Firestore, 읽음 여부는 기기 로컬 Projection이다.

<a id="source-0011"></a>

## 발췌 11: ## 8. 읽기와 비용 정책

출처: docs/architecture/PARTY_NOTIFICATION_CONTRACT.md · 원본 185~193행 · 원문 절: ## 8. 읽기와 비용 정책.

## 8. 읽기와 비용 정책

- 앱 foreground에서는 현재 Player의 최근 이벤트 query를 실시간 구독한다.
- 앱 재실행·Player binding 완료 시 최근 이벤트를 일회 동기화한다.
- 초기 목록은 `occurredAt desc`와 작은 limit(예: 20)만 사용하고, 전체 28일 이벤트를 매 화면 진입마다 무제한 읽지 않는다.
- 알림 아이콘의 unread count는 로컬에 동기화된 최근 이벤트와 로컬 receipt로 계산한다.
- 완료 히스토리 동기화와 알림 동기화는 같은 Firestore query 결과를 공유할 수 있지만, Drift 완료 기록과 알림 receipt는 서로 다른 Projection으로 유지한다.
- 이벤트 만료 후 로컬 알림 보관 기간은 구현 전에 정한다. 초기 권장은 Firestore와 같은 28일이다.


<a id="source-0012"></a>

## 발췌 12: ## 9. Spark에서 보안상 금지하는 구조

출처: docs/architecture/PARTY_NOTIFICATION_CONTRACT.md · 원본 194~203행 · 원문 절: ## 9. Spark에서 보안상 금지하는 구조.

## 9. Spark에서 보안상 금지하는 구조

- Flutter가 다른 Player 경로에 임의 type, 문구, 수신자를 넣어 create하는 일반 권한
- 공개 모집 하위 컬렉션을 모든 사용자의 공용 알림함으로 사용하는 구조
- 현재 membership만으로 과거 이벤트 읽기 권한을 판정하는 구조
- Flutter가 다른 사용자의 FCM 토큰을 읽거나 FCM HTTP API를 직접 호출하는 구조
- 서비스 계정, 서버 키, FCM 발송 자격 증명을 앱이나 공개 문서에 포함하는 구조
- 알림 문서를 먼저 쓰고 이를 파티 상태 변경의 근거로 사용하는 구조
- 완료 히스토리의 로컬 정정·숨김을 서버 알림 읽음 상태로 오해하는 구조


<a id="source-0013"></a>

## 발췌 13: ## 10. 앱 내부 알림 구현 작업 분해

출처: docs/architecture/PARTY_NOTIFICATION_CONTRACT.md · 원본 204~232행 · 원문 절: ## 10. 앱 내부 알림 구현 작업 분해.

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


<a id="source-0014"></a>

## 발췌 14: ## 11. 향후 FCM 확장

출처: docs/architecture/PARTY_NOTIFICATION_CONTRACT.md · 원본 233~250행 · 원문 절: ## 11. 향후 FCM 확장.

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


<a id="source-0015"></a>

## 발췌 15: ## 12. 전체·방별 설정

출처: docs/architecture/PARTY_NOTIFICATION_CONTRACT.md · 원본 256~256행 · 원문 절: ## 12. 전체·방별 설정.

- Spark 앱 내부 알림 1차에서는 복잡한 세부 설정 UI를 구현하지 않는다.

<a id="source-0016"></a>

## 발췌 16: ## 12. 전체·방별 설정

출처: docs/architecture/PARTY_NOTIFICATION_CONTRACT.md · 원본 257~257행 · 원문 절: ## 12. 전체·방별 설정.

- 향후 서버는 FCM 발송 전에 설정을 확인하지만, 이벤트 원본 자체는 히스토리·앱 동기화를 위해 설정과 무관하게 생성하는 것을 기본안으로 한다.

<a id="source-0017"></a>

## 발췌 17: ## 13. 미확정 항목

출처: docs/architecture/PARTY_NOTIFICATION_CONTRACT.md · 원본 272~272행 · 원문 절: ## 13. 미확정 항목.

10. 공용 이벤트 이후 향후 FCM 서버 전환 조건

<a id="source-0018"></a>

## 발췌 18: ## 14. 다른 작업과의 우선순위

출처: docs/architecture/PARTY_NOTIFICATION_CONTRACT.md · 원본 278~278행 · 원문 절: ## 14. 다른 작업과의 우선순위.

2. 앱 내부 알림 구현 1단계(이벤트 schema·Rules)

<a id="source-0019"></a>

## 발췌 19: ## 14. 다른 작업과의 우선순위

출처: docs/architecture/PARTY_NOTIFICATION_CONTRACT.md · 원본 284~284행 · 원문 절: ## 14. 다른 작업과의 우선순위.

8. FCM은 신뢰 서버와 유료 플랜을 별도 승인한 뒤 진행
