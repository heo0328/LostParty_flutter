# Firebase Account Recovery Contract

## 1. 목적

앱 재설치·기기 변경 뒤에도 기존 LOSTPARTY Player와 원정대·그룹·파티 관계를 다시 사용할 수 있도록 Firebase 익명 계정에 복구 가능한 인증 수단을 연결한다.

이번 작업은 새 Player를 기존 Player에 다시 붙이는 Firestore 마이그레이션이 아니다. **현재 익명 Firebase 사용자에 Google 자격 증명을 연결해 같은 AuthUid를 영구 계정으로 승격**하는 방식만 사용한다.

## 2. 식별자와 데이터 보존

```text
기존 익명 Firebase User(AuthUid)
  + Google credential link
-> 같은 Firebase User(AuthUid)
-> 같은 authBindings/{authUid}
-> 같은 PlayerId
-> 기존 원정대·그룹·파티 데이터 유지
```

- 성공 전후 AuthUid는 반드시 같아야 한다.
- `authBindings`, `players`, 그룹, 파티와 게임 계정 문서는 이 명령에서 쓰지 않는다.
- 연결 완료를 위해 Firestore Rules를 변경하지 않는다.
- AuthUid, PlayerId, Google token은 화면과 일반 로그에 노출하지 않는다.

## 3. 연결 정책

- 현재 Firebase 사용자가 있을 때만 연결을 시작한다.
- 이미 Google provider가 연결돼 있으면 성공 상태로 멱등 처리한다.
- 사용자가 Google 선택 창을 취소하면 현재 계정과 데이터는 그대로 둔다.
- Google 자격 증명이 다른 Firebase 사용자에게 이미 연결돼 있으면 자동 로그인·자동 병합·Player 이전을 하지 않는다. 현재 사용자에게 충돌을 안내하고 원래 세션을 유지한다.
- Firebase provider 미설정, 잘못된 자격 증명, 네트워크·요청 제한은 구분 가능한 사용자 안내로 변환한다.
- 연결 성공 뒤 SDK가 반환한 UID가 연결 전 UID와 다르면 성공으로 처리하지 않는다.

## 4. 재설치 복구 정책

재설치 뒤에는 익명 사용자를 새로 만들기 **전에** 사용자가 Google 복구 로그인을 선택할 수 있어야 한다.

1. Firebase Core를 초기화한다.
2. 유지된 Firebase 세션이 있으면 기존 부트스트랩을 계속한다.
3. 세션이 없으면 `기존 계정 복구`와 `새로 시작`을 선택하게 한다.
4. 복구 성공 시 Google 계정의 기존 AuthUid로 Player binding을 조회한다.
5. 새로 시작을 명시적으로 선택한 때만 익명 사용자와 Player binding을 만든다.

연결되지 않은 과거 익명 계정은 재설치 후 신뢰할 수 있게 찾을 자격 증명이 없으므로 클라이언트 추측으로 복구하지 않는다.

## 5. 단계별 범위

### D1 — 기존 계정에 복구 수단 연결

- 설정에서 현재 연결 상태를 보여준다.
- 익명 사용자가 Google 계정을 연결할 수 있게 한다.
- UID 불변과 자격 증명 충돌 거절을 단위 테스트로 보호한다.
- 현재 자동 익명 로그인과 Player binding 부트스트랩은 변경하지 않는다.

### D2 — 재설치 전 복구 진입

- 세션이 없는 시작 상태를 앱 진입 화면에서 분기한다.
- Google 복구 로그인 성공 전에는 새 익명 사용자와 binding을 만들지 않는다.
- 사용자가 `새로 시작`을 선택하면 기존 자동 익명 생성 흐름을 호출한다.
- 기존 세션 보유 사용자는 추가 화면 없이 현재 흐름으로 진입한다.

### D3 — 실기기 검증과 운영 준비

- Firebase Authentication에서 Google provider와 Android 서명 SHA 설정을 확인한다.
- 기존 설치에서 연결 전후 같은 Player·원정대·그룹을 확인한다.
- 앱 삭제·재설치 뒤 Google 복구 로그인으로 같은 Player를 확인한다.
- 이미 다른 LOSTPARTY 사용자에 연결된 Google 계정 충돌 시 현재 데이터가 바뀌지 않는지 확인한다.

## 6. 회귀 보호

- 연결하지 않는 사용자의 기존 익명 로그인과 모든 앱 기능은 그대로 동작한다.
- Google 인증 UI는 사용자가 설정 화면에서 명시적으로 누른 경우에만 연다.
- 연결 실패·취소는 Firebase sign-out이나 새 익명 로그인을 실행하지 않는다.
- 게임 계정 소유권 인증과 Firebase 사용자 복구 인증을 혼동하지 않는다.
- 다른 AuthUid 또는 PlayerId 간 데이터 병합·이전은 별도 신뢰 서버 명령 없이는 제공하지 않는다.
