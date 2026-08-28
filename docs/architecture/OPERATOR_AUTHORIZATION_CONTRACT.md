# 운영자 권한·수동 게임 계정 인증 계약

## 1. 목적과 범위

이 문서는 LOSTPARTY 일반 사용자와 분리된 운영자 권한 경계, 운영자 수동 게임
계정 인증, 기존 소유권 이의 처리, 사용자 확인 화면과 마지막 앱 접속 시각의 제품·데이터
계약을 정의한다.

현재 기준은 Firebase Spark 무료 범위의 Anonymous Auth, Firestore 클라이언트
Transaction과 Security Rules다. Callable Functions, Cloud Scheduler, Firebase Admin SDK를
앱에 포함하는 방식과 유료 플랜은 전제하지 않는다.

이번 계약에서 확정하는 기능은 다음과 같다.

- `PlayerId` 기반 운영자 지정과 일반 사용자 권한과의 분리
- 운영자 오픈카톡과 인게임 일반 채팅 스크린샷을 사용하는 수동 인증
- 기존 active 소유자가 있을 때 24시간 재인증과 조건부 자동 소유권 이전
- 반복·허위 요청에 대한 게임 계정 단위 인증 금지
- 운영자 `사용자 확인` 목록·상세와 마지막 앱 접속 시각

다음은 현재 제외한다.

- 사용자 삭제·삭제 대기·강제 삭제
- 앱 재설치로 새 Anonymous AuthUid·PlayerId를 만드는 우회 차단
- 운영자가 일반 파티 명령을 대신 실행하는 기능
- Player·게임 계정·Character 문서의 자유 형식 편집
- 운영자 앱에 서비스 계정 또는 Admin SDK 비밀값 포함
- FCM 전송과 OS 알림 도달 보장

## 2. 용어

- `운영자`: 별도 운영자 지정 문서에 active로 등록된 Player
- `요청자`: 수동 게임 계정 인증을 요청한 Player
- `기존 소유자`: 대상 GameAccount의 현재 active `ownerPlayerId`
- `인증 캐릭터`: 요청자가 인게임 채팅 증명에 사용하는 Character
- `수동 인증`: 장비 탈착 대신 운영자가 인게임 채팅 스크린샷을 확인하는 인증
- `소유권 방어`: 기존 소유자가 24시간 안에 같은 수동 인증으로 소유권을 재확인하는 절차
- `인증 금지`: 특정 Player가 특정 GameAccount에 대해 추가 인증을 시도하지 못하는 상태

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

## 4. 운영 권한 불변식

- 운영 경로는 일반 사용자 파티 명령과 별도 Repository·Rules 경계를 사용한다.
- 운영자라는 이유로 다른 Player의 신청·승인·탈퇴·추방·Claim 변경을 대신 실행하지 않는다.
- 운영 명령은 허용 필드, 이전 상태, 다음 상태, 운영자 PlayerId와 서버 시각을 검증한다.
- 운영자 명령은 성공한 상태 변경과 감사 이력을 같은 Transaction 또는 검증 가능한
  단계 상태로 남긴다.
- 운영자도 Firestore 문서를 자유 형식으로 수정할 수 없다.
- 수동 인증 승인과 소유권 이전은 GameAccount와 전체 roster Character 단위로 처리한다.
- 민감 ID, 인증 코드와 오픈카톡 대화 내용은 일반 사용자에게 공개하지 않는다.

## 5. 수동 인증의 사용자 흐름

### 5.1 시작 조건

- 사용자는 설정의 게임 계정 인증 화면에서 로컬에 등록된 게임 계정을 선택한다.
- 계정 안에서 인게임 증명에 사용할 캐릭터 하나를 선택한다.
- 요청 단위는 개별 Character가 아니라 선택한 Character가 속한 GameAccount 전체다.
- 한 Player가 여러 게임 계정을 등록했다면 계정별로 각각 요청해야 한다.
- 로컬 조회·가등록만으로는 Character 또는 GameAccount의 서버 소유권이 생기지 않는다.
- 같은 캐릭터 정보는 인증 전까지 여러 기기에 로컬 등록될 수 있다.

### 5.2 코드와 안내

권장 표시 형식은 다음과 같다.

```text
LP-7K4M2Q
```

- `LP-` 접두어와 영문 대문자·숫자 6자리
- `0/O`, `1/I/L`처럼 혼동되는 문자는 제외
- 대소문자를 구분하지 않음
- 복사 버튼 제공
- 서버 생성 시각부터 24시간 유효
- Player와 대상 게임 계정 조합에는 active 요청 하나만 허용
- 재발급하면 기존 코드는 즉시 무효화
- 승인·취소·거절·만료된 코드는 재사용하지 않음
- 코드는 자동 인증 비밀번호가 아니라 운영자가 Character명·요청 번호와 함께 대조하는
  짧은 증명값이다.

사용자 화면에는 다음을 표시한다.

- 인증 대상 로컬 계정명
- 인증 캐릭터명과 서버명
- 인증 코드, 복사 버튼과 만료 시각
- 운영자가 남긴 오픈카톡 링크
- 요청 번호
- 요청 취소와 코드 재발급
- 현재 처리 상태

안내 문구는 다음 의미를 포함한다.

> 선택한 캐릭터로 게임에 접속한 뒤 일반 채팅에 인증 코드를 입력하세요. 캐릭터명과
> 채팅 내용이 함께 보이도록 게임 화면 전체를 촬영하여 운영자 오픈카톡으로 보내주세요.

채팅 부분만 자르거나 캐릭터를 식별할 수 없는 이미지는 운영자가 취소할 수 있다.
스크린샷 파일과 오픈카톡 대화 원본은 Firestore에 업로드하지 않는다.

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

## 7. 운영자 수동 인증 확인 화면

운영자 고유 페이지의 `수동 인증 확인`에는 처리 대기 요청을 오래된 순으로 표시한다.

목록·상세에서 확인할 항목:

- 요청 번호와 인증 코드
- 인증 Character명, 서버명과 직업
- 요청 Player 표시 ID
- 로컬 계정 표시명 Snapshot
- 요청 시각과 만료 시각
- 해당 Player의 전체 수동 요청 횟수
- 해당 Player와 대상 GameAccount 조합의 요청 횟수
- 과거 승인·취소 횟수
- 대상 GameAccount의 기존 active 소유자 존재 여부
- 인증 금지 여부
- Lost Ark API로 다시 조회한 최신 roster

운영자 선택은 세 가지다.

### 승인

- 오픈카톡 스크린샷의 Character명과 코드가 요청 문서와 일치할 때 선택한다.
- 기존 active 소유자가 없으면 GameAccount 전체를 요청 Player에게 인증한다.
- 기존 active 소유자가 있으면 즉시 이전하지 않고 24시간 소유권 방어 절차를 연다.

### 취소

- 증거 부족, 코드 불일치, 잘못된 계정 선택 또는 단순 실수에 사용한다.
- 현재 요청만 종료하며 사용자는 새 코드로 다시 요청할 수 있다.
- 취소 사유를 기록한다.

### 인증 금지

- 반복 허위 요청이나 악의적인 시도로 판단할 때 사용한다.
- 초기 금지 범위는 `PlayerId + 대상 GameAccount` 조합이다.
- 해당 Player의 다른 게임 계정 인증까지 막지 않는다.
- 금지 사유, 처리 운영자와 시각을 기록한다.
- 해제는 운영자 전용 후속 명령으로만 허용한다.
- 앱 재설치로 새 AuthUid·PlayerId를 얻는 우회 대응은 보류한다.

## 8. 기존 active 소유자가 없는 승인

운영자가 승인할 때 Lost Ark API로 인증 Character의 현재 roster를 다시 조회한다.
오래된 로컬 Snapshot을 그대로 서버 소유권으로 확정하지 않는다.

승인 명령은 다음을 검증·반영한다.

1. 운영자 binding과 운영자 지정이 모두 active다.
2. 요청이 처리 가능한 상태이며 24시간 요청 유효시간 안이다.
3. 요청 Player binding과 Player가 active다.
4. 인증 금지 문서가 없다.
5. 최신 API roster에 인증 Character가 포함된다.
6. 기존 identity claim을 통해 GameAccountId·CharacterId를 재사용하거나 새 ID를 만든다.
7. GameAccount와 전체 roster Character의 `ownerPlayerId`를 요청 Player로 설정한다.
8. `playerGameAccounts`를 active로 설정한다.
9. 요청을 승인 완료로 변경하고 운영 감사 이력을 기록한다.
10. 요청자 앱은 서버명·캐릭터명으로 로컬 행을 대응해 서버 ID를 연결한다.

## 9. 기존 active 소유자가 있는 경우

### 9.1 분쟁 개시

운영자가 신규 요청자의 인게임 증거를 확인하고 `승인`하면 일반 즉시 승인은
차단되고 요청은 `awaitingOwnerResponse`가 된다.

- `disputeOpenedAt`은 운영자 승인 서버 시각이다.
- `ownerResponseDeadlineAt`은 `disputeOpenedAt + 24시간`이다.
- 기존 소유자에게 Player Event 기반 앱 내부 알림을 생성한다.
- FCM·OS 알림은 현재 필수 조건이 아니며 알림 도달을 보장하지 않는다.

알림은 다음 의미를 전달한다.

> 다른 사용자가 이 게임 계정의 수동 인증 증명을 제출했습니다. 24시간 안에 설정의
> 등록된 캐릭터를 통해 수동 인증을 완료하지 않으면 기존 인증 자격이 해지됩니다.

### 9.2 기존 소유자의 방어

- 기존 소유자는 설정의 해당 게임 계정에서 인증 Character를 선택한다.
- 별도 24시간 코드를 발급받고 같은 인게임 일반 채팅 스크린샷 절차를 수행한다.
- 운영자가 기한 안에 기존 소유자의 증거를 승인하면 기존 소유권을 유지한다.
- 신규 요청은 `defended`로 종료한다.
- 신규 요청 Player는 해당 GameAccount에 대해 인증 금지된다.
- 금지는 다른 GameAccount에는 적용하지 않는다.

### 9.3 24시간 무응답과 자동 승인

기존 소유자가 기한 안에 수동 인증을 성공하지 못하면 다음 결과가 자동 확정된다.

- 기존 소유자의 인증 자격과 active 소유권 해지
- 신규 요청 Player에게 GameAccount 전체 소유권 이전
- 기존 `GAME_ACCOUNT_VERIFICATION_CONTRACT.md`의 ownership transfer 후처리 적용
- 이전 소유자의 `playerGameAccounts`를 `ownershipLost`로 변경
- 이전 소유자의 pending 신청 무효화
- 영향을 받는 활성 파티를 구성 점검 필요·모집 비활성 상태로 전환

운영자의 두 번째 승인 버튼은 요구하지 않는다.

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

## 11. 마지막 앱 접속 시각

### 11.1 현재 상태

현재 `players/{playerId}.updatedAt`은 최초 Player 생성 시각이며 앱 접속 때 갱신되지
않는다. 따라서 기존 서버 데이터만으로 마지막 앱 접속을 알 수 없다.

### 11.2 추가 필드와 갱신

`players/{playerId}`에 다음 nullable 필드를 추가한다.

```text
lastSeenAt: timestamp | null
```

- 앱 부트스트랩과 active Player binding 확인이 끝난 뒤 새 앱 실행당 한 번 갱신한다.
- 화면 이동이나 같은 프로세스의 백그라운드 복귀마다 갱신하지 않는다.
- 클라이언트 기기 시각이 아니라 `request.time`을 사용한다.
- 사용자는 자기 Player의 `lastSeenAt`만 갱신할 수 있다.
- Rules는 affected keys가 `lastSeenAt` 하나인지와 값이 `request.time`인지 검증한다.
- 접속 이력 문서를 누적하지 않고 최신 시각만 유지한다.
- 기존 Player에 필드가 없으면 `접속 기록 없음`으로 취급한다.
- 새 Player는 최초 생성 때 `lastSeenAt: null`을 포함하고, 기존 Player는 Task-084의
  명시적 데이터 보강 단계에서 null로 맞춘다. Firestore `orderBy`가 필드 없는 문서를
  제외하므로 이 보강을 끝내기 전에는 오래된 접속순 단일 쿼리를 기준으로 삼지 않는다.

## 12. 운영자 사용자 확인 탭

### 12.1 목록

운영자 페이지의 `사용자 확인` 탭은 앱의 Player를 조회한다.

목록 표시:

- 서버에 동기화된 계정별 대표 Character가 하나면 Character명
- 대표 Character가 여러 계정에 있으면 첫 Character명과 `외 N개`
- 서버에 동기화된 대표 Character가 없으면 `대표 캐릭터 지정 안 됨`
- 마지막 앱 접속일 또는 `접속 기록 없음`
- 서버 인증 GameAccount 보유 여부
- Player 상태

미인증 GameAccount와 Character는 목록 때문에 새로 서버에 올리지 않는다. 다만 active
서버 소유 관계가 있는 GameAccount의 대표 Character 선택은 아래 계약에 따라 의도적으로
서버에 동기화한다. 여러 계정 중 임의의 Character 하나를 Player 전체 대표로 간주하지
않는다.

#### 12.1.1 계정별 대표 Character 서버 동기화

대표 Character는 GameAccount별 선택이다. 로컬 Drift의 정수 ID를 서버에 올리지 않고,
이미 서버에 존재하는 Character 문서 ID만 소유 관계 문서에 기록한다.

```text
playerGameAccounts/{ownershipId}
  representativeCharacterId: string | null
  representativeCharacterUpdatedAt: timestamp | null
```

- `representativeCharacterId`는 active이고 현재 Player가 소유하며 같은 GameAccount에
  속하는 서버 Character만 허용한다.
- 최초 서버 동기화와 이후 변경 시각은 클라이언트 시각이 아닌 `request.time`이다.
- 변경 제한은 Player 전체가 아니라 GameAccount별 5분이다.
- 최초 지정은 즉시 허용하고, 사용자가 대표 Character를 바꾼 뒤 5분 동안 같은
  GameAccount의 대표 Character를 다시 변경할 수 없다. 초회 보강은 `updatedAt`을
  쓰지 않으므로 쿨다운을 시작하지 않는다.
- Rules는 affected keys를 두 대표 필드로 제한하고, 현재 active 소유자, 같은 계정의
  active Character, 기존 값과 다른 값, 5분 경과를 모두 검증한다. 서버 필드가 비어
  있는 초회 보강은 `representativeCharacterId`만 변경할 수 있다.
- UI 제한은 안내용이며, 재실행·재설치·변조 클라이언트도 우회하지 못하도록 Rules에서
  같은 제한을 강제한다.
- 저장 중에는 선택 버튼을 비활성화하고 같은 Character 재선택은 서버 요청을 보내지
  않는다. 제한 중에는 다음 변경 가능 시각 또는 남은 시간을 표시한다.
- 대표 Character 변경은 온라인에서만 수행한다. 서버 저장 성공 뒤 로컬 대표 선택을
  반영하며, 서버 저장이 실패하면 로컬 값도 변경하지 않는다.
- 기존 로컬 대표는 해당 계정의 서버 필드가 없고 대응하는 active 서버 Character를
  찾을 수 있을 때 계정당 한 번 보강한다. 보강 성공은 로컬 맞춤 기록으로 남기고
  내 계정 재진입·탭 전환에서는 Firestore를 다시 읽거나 쓰지 않는다.
- 운영자 상세는 각 GameAccount의 대표 Character를 따로 표시한다.

기본 정렬:

1. `lastSeenAt`이 없는 사용자
2. 마지막 접속이 가장 오래된 사용자
3. 최근 접속 사용자

대량 목록은 페이지 단위로 조회하고 운영자 지정이 active인 사용자에게만 list를
허용한다.

### 12.2 상세

상세에서는 서버에 이미 존재하는 데이터만 보여준다.

- 사용자 표시 ID
- Player 생성일과 마지막 앱 접속일
- 서버 GameAccount 목록
- GameAccount별 active·ownershipLost 등 인증 소유 상태
- 서버 Character 목록
- 수동 인증 요청·승인·취소 횟수
- active 인증 금지 내역

AuthUid와 원본 PlayerId는 일반 표시 항목으로 노출하지 않는다. 로컬에만 있는
미인증 계정과 Character는 운영자에게 보이지 않는다.

### 12.3 명시적 제외

사용자 삭제, 삭제 대기 필터, 즉시 강제 삭제와 Firebase Authentication 사용자 삭제는
현재 보류한다. 사용자 확인 탭은 조회와 수동 인증 운영을 위한 화면이지 일반 Firestore
관리 콘솔이 아니다.

## 13. 감사 이력

다음 운영 행위는 최소 감사 이력을 남긴다.

- 수동 인증 승인·취소·인증 금지
- 기존 소유권 이의 절차 개시
- 기존 소유자 방어 승인
- 24시간 만료 자동 이전 확정
- 인증 금지 해제

감사 이력에는 action type, 대상 요청 ID, 대상 GameAccountId 또는 identity key,
처리 운영자 PlayerId, 서버 처리 시각과 사유를 기록한다. 사용자에게는 필요한 상태와
사유만 보여주고 내부 식별자를 노출하지 않는다.

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

### Task-086. 기존 소유자 24시간 방어와 자동 이전

- 기존 active 소유자 감지와 앱 내부 알림
- 기존 소유자 수동 인증 방어
- 방어 성공 시 신규 요청자 대상 GameAccount 인증 금지
- 만료 후 추가 운영 승인 없는 소유권 이전 Transaction
- ownershipLost·신청·활성 파티 후처리

각 Task는 문서·Rules·코드·표적 테스트·필요한 실기기 검증을 같은 단위에서 맞춘다.
Rules 배포와 Emulator 사용은 별도 승인 절차를 따른다.

## 15. 완료 검증 기준

- 일반 사용자가 운영자 문서를 list하거나 운영 명령을 호출할 수 없다.
- revoked 운영자는 운영자 페이지와 명령을 사용할 수 없다.
- 사용자는 자기 수동 인증 요청만 생성·조회·취소할 수 있다.
- 인증 코드는 Player·대상 계정·24시간 기한에 묶인다.
- 운영자 취소와 인증 금지가 구분된다.
- 기존 소유자가 없을 때만 1차 승인으로 즉시 소유권을 확정한다.
- 기존 소유자가 있으면 24시간 전 즉시 이전이 불가능하다.
- 기존 소유자 방어 성공 시 신규 요청자의 해당 계정 인증이 차단된다.
- 기한 후 자동 이전은 추가 운영 승인을 요구하지 않고 동시 요청에도 한 번만 적용된다.
- `lastSeenAt`은 본인 필드만 서버 시각으로 갱신할 수 있다.
- 대표 Character 변경은 같은 GameAccount에서 서버 기준 5분에 한 번만 성공한다.
  초회 보강은 이 제한을 시작하지 않는다.
- 대표 Character는 같은 active GameAccount에 속한 본인 active 서버 Character만 가능하다.
- 운영자 사용자 목록은 오래된 접속순이며 로컬 전용 데이터를 요구하지 않는다.
- 사용자 삭제 기능이 포함되지 않는다.

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
- 전체 테스트 464건과 `flutter analyze` — 완료(2026-08-28)
- 실기기 5분 타이머 UI 정상. 탭 전환 통신 로그 확인은 생략하고 표적 테스트로 대체. Task-085로 진행

Rules 배포 전 새 앱 코드는 `lastSeenAt` update가 거절되어 부트스트랩 재시도 화면을
표시한다. 따라서 앱 빌드 배포보다 Firestore Rules 배포를 먼저 수행한다.
