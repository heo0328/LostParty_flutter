# Firebase Player Binding Contract

> 원본 문서: `docs/architecture/FIREBASE_PLAYER_BINDING_CONTRACT.md` · 이동일:2026-10-13. 기존 서비스의 보관 문서이며 신규 서버의 실행 기준이 아니다.

## 1. 목적과 범위

Firebase Authentication의 `AuthUid`를 LOSTPARTY 영속 사용자 식별자인 `PlayerId`에 연결하는 최초 서버 데이터 계약이다.

이번 범위는 다음만 포함한다.

- 인증된 설치의 최초 Player 생성
- 기존 Auth binding과 Player 재사용
- Player binding 완료 전 앱 진입 대기
- 클라이언트의 binding 변경·삭제 및 임의 Player 연결 차단

복구키, 새 AuthUid 재연결, 공개 프로필, 게임 계정과 Character 서버 이전은 포함하지 않는다. 재연결은 향후 신뢰할 수 있는 서버 명령으로만 제공한다.

## 2. 식별자 관계

```text
Firebase AuthUid
-> authBindings/{authUid}
-> PlayerId
-> players/{playerId}
```

- `AuthUid`는 인증과 binding 문서 경로에만 사용한다.
- `PlayerId`는 Firestore 자동 문서 ID로 최초 생성한다.
- 파티, 신청, 그룹과 권한에는 `PlayerId`를 사용한다.
- 두 식별자는 UI와 일반 로그에 노출하지 않는다.

## 3. Firestore 데이터 계약

```text
authBindings/{authUid}
  schemaVersion: 1
  playerId: string
  status: active
  linkedAt: server timestamp
  updatedAt: server timestamp

players/{playerId}
  schemaVersion: 1
  status: active
  createdAt: server timestamp
  updatedAt: server timestamp
```

Player 최초 생성에는 공개 표시명이나 대표 캐릭터를 요구하지 않는다. 해당 필드는 제품 기능이 실제로 필요해질 때 별도 계약으로 추가한다.

## 4. 최초 생성과 재사용

### 기존 binding

1. 현재 AuthUid의 binding 문서를 읽는다.
2. `schemaVersion`, `status`와 `playerId`를 검증한다.
3. 연결된 Player 문서가 존재하고 active인지 검증한다.
4. `PlayerSession(authUid, playerId)`를 반환한다.

### 최초 binding

하나의 Firestore Transaction에서 다음을 처리한다.

1. binding이 존재하지 않는지 확인한다.
2. 새 Player 문서 ID를 생성한다.
3. Player 문서와 binding 문서를 함께 생성한다.
4. 두 문서에 동일한 서버 요청 시각을 기록한다.
5. 생성된 PlayerId로 PlayerSession을 반환한다.

동시 최초 요청은 Firestore Transaction 재시도로 수렴하며 최초 성공한 binding을 이후 요청이 재사용한다.

## 5. Security Rules 경계

- 인증 사용자는 자기 AuthUid의 binding 문서만 단건 조회할 수 있다.
- binding 및 Player 목록 조회는 허용하지 않는다.
- 최초 생성은 자기 binding이 없고 대상 Player도 아직 없을 때만 허용한다.
- 같은 원자 요청의 binding과 Player가 서로 같은 PlayerId를 참조해야 한다.
- binding과 Player의 클라이언트 update/delete는 허용하지 않는다.
- 기존 Player에 새 AuthUid를 클라이언트가 연결할 수 없다.
- Player 단건 읽기는 현재 AuthUid의 binding이 해당 PlayerId를 가리킬 때만 허용한다.

현재 규칙은 `firestore.rules`가 단일 기준이다. 배포 전에는 Production mode의 기존 규칙 때문에 Player binding이 실패하는 것이 정상이다.

## 6. 앱 부트스트랩 순서

```text
Firebase Core
-> Anonymous Auth
-> Player binding 조회 또는 생성
-> 기존 MyApp과 Drift/Fake 런타임 생성
```

어느 단계에서든 실패하면 공용 부트스트랩 실패 화면을 표시하고 사용자가 다시 시도할 수 있다.

## 7. 실패 정책

- binding 형식이 잘못됐거나 Player가 없으면 자동 복구하지 않고 실패한다.
- 클라이언트는 기존 binding을 수정하거나 새 Player로 갈아끼우지 않는다.
- Auth UID와 Player ID 및 원본 Firebase 오류 상세는 사용자 화면에 표시하지 않는다.
- 재시도는 같은 AuthUid의 기존 binding을 우선 재사용한다.

## 8. 검증 경계

- Domain: 빈 AuthUid/PlayerId 거부와 두 식별자 분리
- Repository: AuthUid 정규화, PlayerSession 반환 및 저장 오류 전달
- Auth: 기존 인증 재사용과 최초 익명 로그인
- Rules: 자기 binding 최초 생성, 기존 binding 재사용, 타인 읽기 및 update/delete 거부
- 실기기: 최초 실행 후 문서 1쌍 생성, 재실행 후 같은 문서 재사용, 기존 Drift 데이터 유지

Rules 동시성 및 거부 시나리오는 Firebase Emulator 도입 후 자동화한다. 그 전에는 Rules 배포와 Android 실기기 검증을 병합 조건으로 사용한다.
