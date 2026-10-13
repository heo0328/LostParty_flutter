# 기존 서비스 발췌 — docs/architecture/OPERATOR_AUTHORIZATION_CONTRACT.md

원본 문서: docs/architecture/OPERATOR_AUTHORIZATION_CONTRACT.md ([현재 문서](../../../../../docs/architecture/OPERATOR_AUTHORIZATION_CONTRACT.md)). 분리일: 2026-10-13.
원본 전체 SHA256: 6ced72fd853987479d7ddb5202164b53795141d81946e62aca92dbe03c2f75c3.
아래는 기존 Firebase 환경의 원문이다. 신규 서버의 실행 지시/배포 승인으로 사용하지 않는다. 행 범위는 분리 직전이며 링크 위치만 조정한다.

<a id="source-0001"></a>

## 발췌 1: ## 1. 목적과 범위

출처: docs/architecture/OPERATOR_AUTHORIZATION_CONTRACT.md · 원본 9~11행 · 원문 절: ## 1. 목적과 범위.

현재 기준은 Firebase Spark 무료 범위의 Anonymous Auth, Firestore 클라이언트
Transaction과 Security Rules다. Callable Functions, Cloud Scheduler, Firebase Admin SDK를
앱에 포함하는 방식과 유료 플랜은 전제하지 않는다.

<a id="source-0002"></a>

## 발췌 2: ## 1. 목적과 범위

출처: docs/architecture/OPERATOR_AUTHORIZATION_CONTRACT.md · 원본 28~28행 · 원문 절: ## 1. 목적과 범위.

- FCM 전송과 OS 알림 도달 보장

<a id="source-0003"></a>

## 발췌 3: ## 3. 운영자 식별

출처: docs/architecture/OPERATOR_AUTHORIZATION_CONTRACT.md · 원본 40~76행 · 원문 절: ## 3. 운영자 식별.

## 3. 운영자 식별

### 3.1 확정 방식

운영자는 Firestore의 `PlayerId` 기반 운영자 지정 문서로 식별한다. 하드코드
PlayerId와 Firebase Auth custom claim은 초기 방식으로 사용하지 않는다.

예시 경로:

```text
operatorAssignments/{playerId}
  schemaVersion: 1
  playerId: string
  status: active | revoked
  createdAt: timestamp (선택, 관리 감사용)
  updatedAt: timestamp (선택, 관리 감사용)
```

초기 Firebase Console 지정에는 `schemaVersion`, 경로와 같은 `playerId`, `status`가
권한 판정 필수 필드다. `createdAt`과 `updatedAt`은 별도 신뢰 관리 도구를 도입할 때
기록하는 권장 감사 필드이며, 값이 없다는 이유로 운영 권한을 거절하지 않는다.

운영 권한을 인정하려면 다음을 모두 만족해야 한다.

1. 현재 Firebase Auth 사용자가 인증돼 있다.
2. `authBindings/{authUid}`가 active이며 대상 PlayerId를 가리킨다.
3. `players/{playerId}`가 active다.
4. `operatorAssignments/{playerId}`가 active다.

### 3.2 관리 경계

- 일반 앱 클라이언트는 운영자 지정 문서를 생성·수정·삭제할 수 없다.
- 운영자 추가·해제는 Firebase Console 또는 별도 신뢰 관리 절차로만 수행한다.
- 운영자는 앱 안에서 다른 운영자를 임명하거나 본인의 운영자 자격을 수정할 수 없다.
- AuthUid와 원본 PlayerId는 일반 사용자 UI 및 일반 로그에 노출하지 않는다.
- 운영자 화면도 사용자 구분에는 짧은 요청 번호 또는 표시 ID를 우선 사용한다.


<a id="source-0004"></a>

## 발췌 4: ## 4. 운영 권한 불변식

출처: docs/architecture/OPERATOR_AUTHORIZATION_CONTRACT.md · 원본 79~79행 · 원문 절: ## 4. 운영 권한 불변식.

- 운영 경로는 일반 사용자 파티 명령과 별도 Repository·Rules 경계를 사용한다.

<a id="source-0005"></a>

## 발췌 5: ## 4. 운영 권한 불변식

출처: docs/architecture/OPERATOR_AUTHORIZATION_CONTRACT.md · 원본 84~84행 · 원문 절: ## 4. 운영 권한 불변식.

- 운영자도 Firestore 문서를 자유 형식으로 수정할 수 없다.

<a id="source-0006"></a>

## 발췌 6: ### 5.2 코드와 안내

출처: docs/architecture/OPERATOR_AUTHORIZATION_CONTRACT.md · 원본 134~135행 · 원문 절: ### 5.2 코드와 안내.

채팅 부분만 자르거나 캐릭터를 식별할 수 없는 이미지는 운영자가 취소할 수 있다.
스크린샷 파일과 오픈카톡 대화 원본은 Firestore에 업로드하지 않는다.

<a id="source-0007"></a>

## 발췌 7: ## 6. 수동 인증 요청 데이터

출처: docs/architecture/OPERATOR_AUTHORIZATION_CONTRACT.md · 원본 137~174행 · 원문 절: ## 6. 수동 인증 요청 데이터.

## 6. 수동 인증 요청 데이터

권장 문서:

```text
manualVerificationRequests/{requestId}
  schemaVersion: 1
  requesterPlayerId: string
  targetIdentityKey: string
  targetGameAccountId: string | null
  localAccountLabelSnapshot: string
  proofServerName: string
  proofCharacterName: string
  verificationCode: string
  status: pendingProof | approved | cancelled | blocked
        | awaitingOwnerResponse | defended | transferReady
        | transferred | expired
  attemptNumberForTarget: number
  totalAttemptNumberForPlayer: number
  createdAt: timestamp
  expiresAt: timestamp
  reviewedByOperatorPlayerId: string | null
  reviewedAt: timestamp | null
  reviewReason: string | null
  previousOwnerPlayerId: string | null
  disputeOpenedAt: timestamp | null
  ownerResponseDeadlineAt: timestamp | null
  resolvedAt: timestamp | null
  updatedAt: timestamp
```

`targetIdentityKey`는 아직 GameAccountId가 없을 때 선택 Character의 정규화된 서버명과
캐릭터명으로 만든 안정적인 identity claim 키다. 기존 GameAccount가 확인되면 이후
판정은 GameAccountId를 기준으로 한다.

코드 생성과 request create는 호출 Player 본인에게만 허용한다. 요청자는 상태,
운영자 판정, 기한, 시도 횟수나 다른 Player 관련 필드를 임의 변경할 수 없다.


<a id="source-0008"></a>

## 발췌 8: ### 9.1 분쟁 개시

출처: docs/architecture/OPERATOR_AUTHORIZATION_CONTRACT.md · 원본 244~244행 · 원문 절: ### 9.1 분쟁 개시.

- FCM·OS 알림은 현재 필수 조건이 아니며 알림 도달을 보장하지 않는다.

<a id="source-0009"></a>

## 발췌 9: ### 9.4 Spark의 24시간 처리 방식

출처: docs/architecture/OPERATOR_AUTHORIZATION_CONTRACT.md · 원본 281~295행 · 원문 절: ### 9.4 Spark의 24시간 처리 방식.

### 9.4 Spark의 24시간 처리 방식

Spark 클라이언트 구조에는 기한 시각에 백그라운드로 실행되는 신뢰 스케줄러가 없다.
따라서 여기서 `자동 승인`은 **기한이 지나면 추가 운영 판단 없이 결과가 결정된다**는
뜻이다. 실제 Firestore 이전 Transaction은 다음 중 처음 발생한 안전한 시점에 수행한다.

- 요청자 앱이 인증 상태를 다시 확인할 때
- 기존 소유자 앱이 분쟁 상태를 확인할 때
- 운영자가 대기 목록을 열 때
- 후속 신뢰 서버가 도입된 뒤 예약 작업이 실행될 때

Transaction은 `request.time >= ownerResponseDeadlineAt`, 요청 상태와 기존 소유자가
변하지 않았는지 다시 확인해야 한다. 여러 클라이언트가 동시에 확정해도 한 결과로
수렴해야 한다. 기한 전에는 누구도 이전을 확정할 수 없다.


<a id="source-0010"></a>

## 발췌 10: ## 10. 인증 금지 데이터

출처: docs/architecture/OPERATOR_AUTHORIZATION_CONTRACT.md · 원본 296~318행 · 원문 절: ## 10. 인증 금지 데이터.

## 10. 인증 금지 데이터

권장 문서:

```text
manualVerificationBlocks/{playerId_targetGameAccountIdOrIdentityKey}
  schemaVersion: 1
  playerId: string
  targetGameAccountId: string | null
  targetIdentityKey: string
  status: active | revoked
  reason: string
  blockedByOperatorPlayerId: string
  blockedAt: timestamp
  revokedByOperatorPlayerId: string | null
  revokedAt: timestamp | null
```

- 요청 생성과 승인 전 모두 active block 존재 여부를 확인한다.
- 운영자가 명시적으로 `인증 금지`를 선택한 경우와 기존 소유자가 24시간 안에 방어한
  경우에 생성한다.
- 시도 횟수는 운영자 판단 자료이며 특정 횟수만으로 자동 금지하지 않는다.


<a id="source-0011"></a>

## 발췌 11: ### 11.2 추가 필드와 갱신

출처: docs/architecture/OPERATOR_AUTHORIZATION_CONTRACT.md · 원본 338~338행 · 원문 절: ### 11.2 추가 필드와 갱신.

- Rules는 affected keys가 `lastSeenAt` 하나인지와 값이 `request.time`인지 검증한다.

<a id="source-0012"></a>

## 발췌 12: ### 11.2 추가 필드와 갱신

출처: docs/architecture/OPERATOR_AUTHORIZATION_CONTRACT.md · 원본 341~343행 · 원문 절: ### 11.2 추가 필드와 갱신.

- 새 Player는 최초 생성 때 `lastSeenAt: null`을 포함하고, 기존 Player는 Task-084의
  명시적 데이터 보강 단계에서 null로 맞춘다. Firestore `orderBy`가 필드 없는 문서를
  제외하므로 이 보강을 끝내기 전에는 오래된 접속순 단일 쿼리를 기준으로 삼지 않는다.

<a id="source-0013"></a>

## 발췌 13: #### 12.1.1 계정별 대표 Character 서버 동기화

출처: docs/architecture/OPERATOR_AUTHORIZATION_CONTRACT.md · 원본 383~385행 · 원문 절: #### 12.1.1 계정별 대표 Character 서버 동기화.

- Rules는 affected keys를 두 대표 필드로 제한하고, 현재 active 소유자, 같은 계정의
  active Character, 기존 값과 다른 값, 5분 경과를 모두 검증한다. 서버 필드가 비어
  있는 초회 보강은 `representativeCharacterId`만 변경할 수 있다.

<a id="source-0014"></a>

## 발췌 14: #### 12.1.1 계정별 대표 Character 서버 동기화

출처: docs/architecture/OPERATOR_AUTHORIZATION_CONTRACT.md · 원본 386~387행 · 원문 절: #### 12.1.1 계정별 대표 Character 서버 동기화.

- UI 제한은 안내용이며, 재실행·재설치·변조 클라이언트도 우회하지 못하도록 Rules에서
  같은 제한을 강제한다.

<a id="source-0015"></a>

## 발췌 15: #### 12.1.1 계정별 대표 Character 서버 동기화

출처: docs/architecture/OPERATOR_AUTHORIZATION_CONTRACT.md · 원본 392~394행 · 원문 절: #### 12.1.1 계정별 대표 Character 서버 동기화.

- 기존 로컬 대표는 해당 계정의 서버 필드가 없고 대응하는 active 서버 Character를
  찾을 수 있을 때 계정당 한 번 보강한다. 보강 성공은 로컬 맞춤 기록으로 남기고
  내 계정 재진입·탭 전환에서는 Firestore를 다시 읽거나 쓰지 않는다.

<a id="source-0016"></a>

## 발췌 16: ### 12.3 명시적 제외

출처: docs/architecture/OPERATOR_AUTHORIZATION_CONTRACT.md · 원본 423~425행 · 원문 절: ### 12.3 명시적 제외.

사용자 삭제, 삭제 대기 필터, 즉시 강제 삭제와 Firebase Authentication 사용자 삭제는
현재 보류한다. 사용자 확인 탭은 조회와 수동 인증 운영을 위한 화면이지 일반 Firestore
관리 콘솔이 아니다.

<a id="source-0017"></a>

## 발췌 17: ## 14. 구현 분할

출처: docs/architecture/OPERATOR_AUTHORIZATION_CONTRACT.md · 원본 441~473행 · 원문 절: ## 14. 구현 분할.

## 14. 구현 분할

### Task-084. 운영자 권한·마지막 접속 기반

- operator assignment 읽기와 Rules helper
- `players.lastSeenAt` 새 앱 실행당 1회 갱신
- 새 Player의 null 초기값과 기존 Player의 null 보강 절차
- 운영자 전용 라우트·페이지 진입 차단
- `사용자 확인` 목록·상세의 서버 데이터 read model
- 계정별 대표 Character 서버 동기화와 서버 강제 5분 변경 제한
- 운영자 목록의 `Character명 외 N개`와 상세의 계정별 대표 Character 표시
- 사용자 삭제와 수동 인증 쓰기는 제외

### Task-085. 수동 인증 요청과 운영자 1차 판정

- 사용자 코드 발급·복사·오픈카톡 안내·상태 화면
- 운영자 대기 목록과 요청 횟수
- 승인·취소·인증 금지
- 기존 소유자가 없는 GameAccount의 수동 인증
- 085 구현 결정: 기존 소유자가 있으면 승인을 거절하고 `existingOwner`를 반환한다. `awaitingOwnerResponse`는 열지 않는다.

### Task-086. 기존 소유자 24시간 방어와 자동 이전

- 기존 active 소유자 감지와 앱 내부 알림
- 기존 소유자 수동 인증 방어
- 방어 성공 시 신규 요청자 대상 GameAccount 인증 금지
- 방어 실패 시 기존 소유자 자동 인증 금지 없이 신규 요청자에게 즉시 이전
- 만료 후 추가 운영 승인 없는 소유권 이전 Transaction
- ownershipLost·신청·활성 파티 후처리

각 Task는 문서·Rules·코드·표적 테스트·필요한 실기기 검증을 같은 단위에서 맞춘다.
Rules 배포와 Emulator 사용은 별도 승인 절차를 따른다.


<a id="source-0018"></a>

## 발췌 18: ## 16. Task-084 구현 상태

출처: docs/architecture/OPERATOR_AUTHORIZATION_CONTRACT.md · 원본 493~521행 · 원문 절: ## 16. Task-084 구현 상태.

## 16. Task-084 구현 상태

2026-08-28 코드 기준 다음이 구현됐다.

- 새 Player 문서의 `lastSeenAt: null` 초기값
- active binding 부트스트랩 완료 후 앱 실행당 한 번 서버 시각 갱신
- `operatorAssignments/{playerId}` 본인 단건 확인과 active 운영자 Rules helper
- 일반 사용자의 Player list 차단과 active 운영자의 Player list 허용
- 기존 Player의 누락 `lastSeenAt`을 운영자 최초 목록 진입에서 null로 보강
- 설정의 운영자 전용 `사용자 확인` 진입점
- 접속 기록 없음·오래된 접속순 사용자 목록과 더 보기
- 서버 GameAccount·Character·소유 상태만 사용하는 사용자 상세
- active 서버 소유 계정의 대표 Character 최초 보강과 서버 성공 후 로컬 반영
- GameAccount별 대표 Character 변경 5분 제한과 서버 시각 검증
- 운영자 목록의 `Character명 외 N개` 요약과 상세의 계정별 대표 표시
- 서버에서 대표 Character가 확정되지 않은 계정은 `대표 캐릭터 지정 안 됨` 표시

외부 적용 상태는 다음과 같다.

- 변경된 Firestore Rules를 Firebase `lost-party`에 배포 — 완료(2026-08-28)
- Firebase Console에서 실제 실기기 PlayerId의 active `operatorAssignments` 문서 생성 — 완료(2026-08-28, 잘못 지정한 기존 문서 삭제 확인)
- 실기기 앱 재실행 후 `lastSeenAt` 갱신 — 완료(2026-08-28)
- 실기기에서 운영자 진입과 사용자 목록 표시 — 완료(2026-08-28)
- 계정별 대표 Character 서버 동기화·5분 제한과 목록·상세 표시 — 코드·Rules·자동 검증 완료, Rules 배포 완료(2026-08-28)
- 초회 보강과 사용자 변경 분리, 로컬 맞춤 기록으로 탭 재진입 전송 생략 — 코드·자동 검증 완료(2026-08-29). Rules 재배포 완료(사용자, 2026-08-29)
- Task-085 수동 인증 요청·운영자 1차 판정 — 코드·표적 테스트 완료(2026-08-29). Rules·인덱스 배포 완료(사용자, 2026-08-29). 실기기 확인은 사용자 수행

Rules 배포 전 새 앱 코드는 `lastSeenAt` update가 거절되어 부트스트랩 재시도 화면을
표시한다. 따라서 앱 빌드 배포보다 Firestore Rules 배포를 먼저 수행한다.
