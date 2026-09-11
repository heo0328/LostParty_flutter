# NEXT WORK

> 다음에 바로 진행할 단일 작업 그룹의 근거·범위·순서·완료 조건만 관리한다. 완료 경과는 `DEV_LOG.md`로 이동한다.

## 현재 인계 상태

- 통합 기준은 로컬·원격이 같은 `dev`의 `637828a`다.
- 신청 후보 동일 딜러 직업 차단과 §14 레이드 목록 Character 필터·참가 인원 정렬·남은 자리 필터는 구현·자동 검증·실기기 확인 후 `dev`에 반영됐다.
- 파티 신청 `submittedBuildSnapshot`과 파티 membership `gemValidationSnapshot`에는 보석 검증 최소 요약이 전파된다.
- 그룹 membership 전파는 `cursor/group-membership-gem-snapshot`에서 구현·표적 자동 검증·브랜치 푸시까지 완료했다. CLI `firebase deploy`는 `/projects/lost-party:test` HTTP 503으로 두 번 실패했고 Ruleset/Release에 도달하지 않았다. 동일 `firestore.rules`를 Firebase 콘솔 편집기에 붙여 넣어 바로 게시하는 우회로 운영 반영했다. 남은 것은 두 기기 실기기 확인과 `dev` 병합이다.

## 다음 작업 그룹 — 그룹 membership 보석 검증 Snapshot 전파

### 1. 선정 근거

- `CHARACTER_BUILD_INTEGRITY_CONTRACT.md` §8~9는 신청자·파티 구성원·그룹 Character 간략 카드에 같은 보석 검증 요약을 표시하는 것을 장기 계약으로 정했다.
- 신청자와 파티 membership 구간은 이미 완료됐고 그룹 전파만 남아 있어, 새 판정 체계를 만들지 않고 검증된 모델·표시 정책을 재사용할 수 있다.
- 그룹 membership의 기존 전투력 Snapshot 및 본인 새로고침 경로가 안정화됐으므로 과거에 두었던 “파티 membership 안정화 후 별도 산정” 조건은 충족됐다.
- Build 별칭·메모·공유는 별칭 키, wildcard 메모 합성, JSON 버전·충돌 정책 등 추가 제품 결정이 필요하므로 이번 단일 그룹보다 뒤로 둔다.

### 2. 목표

그룹 가입·생성 시점과 본인 표시 Snapshot 새로고침 시 선택된 표시 Character의 최소 보석 검증 요약을 그룹 membership에 저장하고, 그룹원 카드에서 파티 구성원 카드와 같은 정책으로 보여준다.

새 판정 로직을 만들지 않고 기존 `PartyGemValidationSnapshot` 계열 모델, 로컬 Build 분석 결과와 파티 카드 표시 컴포넌트를 가능한 범위에서 재사용한다.

### 3. 고정 데이터 계약

그룹 membership의 선택 필드 `gemValidationSnapshot`은 파티 membership과 동일한 다섯 값만 사용한다.

```text
gemValidationStatus
foreignClassGemCount
unverifiedSameClassGemCount
gemValidatedAt
catalogVersion
```

- 전체 Armory JSON, 보석명, Tooltip 원문과 장비 상세는 Firestore에 저장하지 않는다.
- 과거 membership, 구버전 앱, 로컬 Build 미보유 상태는 필드 부재 또는 `null`을 정상 호환 상태로 읽는다.
- 다섯 값이 불완전하거나 타입이 잘못된 경우 보석 상태만 `검증 정보 없음`으로 낮추고 그룹원 이름·직업·아이템 레벨·전투력 표시는 유지한다.
- 이 요약은 클라이언트가 만든 표시 정보이며 소유권이나 가입 권한의 보안 근거로 사용하지 않는다.
- `displayCharacterIdSnapshot`과 다른 Character의 Build Snapshot을 대입하지 않는다.
- 로컬 값이 없다는 이유로 서버에 저장된 기존 정상 요약을 `null`로 덮어쓰지 않는다.

### 4. 명령별 Snapshot 출처

| 경로 | 최초 출처 | 저장 원칙 |
| --- | --- | --- |
| 그룹 생성 | 생성자가 선택한 표시 Character의 선호 역할 로컬 Build Snapshot | 있으면 membership에 기록, 없으면 `null` |
| 가입 신청 | 신청자가 선택한 표시 Character의 선호 역할 로컬 Build Snapshot | join relation에 함께 보존하고 승인 시 membership으로 복사 |
| 초대 수락 | 초대 relation에는 초대한 사용자가 알 수 없는 대상의 로컬 Build를 추정하지 않음 | 최초 membership은 `null` 허용, 가입자 본인 새로고침에서 보강 |
| 초대코드 가입 | 가입자가 선택한 표시 Character의 선호 역할 로컬 Build Snapshot | 있으면 membership에 기록 |
| 본인 표시 Snapshot 새로고침 | 현재 membership의 `displayCharacterIdSnapshot`과 일치하는 본인 로컬 Build Snapshot | 기존 전투력 보강과 같은 Transaction에서 보석 요약도 보강 |

초대 수락 경로가 현재 앱 구조에서 가입자 본인의 로컬 Snapshot을 안전하게 전달할 수 있음이 구현 전 확인되면 같은 Transaction에서 기록할 수 있다. 이를 위해 초대 생성 계약을 넓히거나 초대한 사용자가 값을 대신 만들지는 않는다.

### 5. 포함 범위

- 그룹 Domain/DTO/mapper에 nullable 보석 검증 Snapshot 추가
- 그룹 생성·가입 신청·신청 승인·초대 수락·초대코드 가입 write plan의 필드 전파
- 본인 그룹 membership 표시 Snapshot 새로고침에 보석 요약 보강과 기존값 보존 규칙 적용
- 그룹원 read model과 그룹원 카드에 파티 카드와 동일한 상태 표시
- Firestore 그룹 membership·join relation 허용 키와 update `affectedKeys`의 최소 변경
- 구버전 문서, 불완전 맵, 로컬 Snapshot 없음에 대한 방어적 읽기
- 관련 Domain/mapper/Repository/UI/Rules 계약 테스트와 기존 그룹 명령 회귀
- Rules 변경분의 로컬 검증, 실제 운영 배포 1회, 두 사용자 실기기 확인

### 6. 제외 범위

- Build 별칭, 깨달음·질서 해/달/별 조합 표시
- 개인 직업 메모, 메모 팩, JSON 내보내기·가져오기와 서버 공유 코드
- 모든 그룹 Character별 Build Snapshot 저장: 이번에는 membership의 표시 Character 한 명만 대상
- 전체 Armory·보석 상세 서버 저장 또는 서버 측 진위 판정
- 기존 membership 일괄 마이그레이션·백필
- 그룹 대표 Character 자동 변경, 활동 Character 정책 변경
- 보석 검증 알고리즘·카탈로그 자체 수정
- 서버 데이터 무결성 자동 복구, FCM, Functions와 스케줄러

### 7. 구현 전 회귀 방지 게이트

코드 수정 전에 아래 실제 연결을 먼저 확인하고 결과가 문서 가정과 다르면 구현 범위를 넓히지 말고 차이를 기록한다.

1. 그룹 생성·가입 신청·초대 수락·신청 승인·코드 가입 각각의 Repository와 write plan이 membership을 만드는 지점
2. 가입 신청 relation에서 승인 membership으로 표시 Snapshot을 복사하는 경로
3. 그룹 상세 진입 시 본인 Character 보강 → membership self refresh → 목록 재조회 흐름
4. 앱 라우터/DI가 인메모리 대체물이 아니라 운영 그룹 Repository와 실제 Player ID를 연결하는지
5. `groups/{groupId}/members/{playerId}`와 join relation의 현재 Rules allowlist, `getAfter()` 관계 및 update 판정 순서
6. 기존 파티용 보석 Snapshot mapper·표시 Widget을 그룹이 그대로 재사용할 수 있는지와 feature 간 의존 방향

보존할 기존 흐름은 그룹 생성, 직접 초대와 수락, 가입 신청과 승인·거절, 초대코드 가입, 일반 탈퇴, 그룹장 양도, 마지막 1인 해산, 그룹원 전투력 새로고침이다.

### 8. 세부 작업 순서

#### A. 계약·모델 공통화

- 기존 파티의 보석 검증 Snapshot 모델과 방어적 parser 위치를 확인한다.
- 그룹이 recruitment feature의 UI나 data 구현을 역참조하지 않도록 공용 Domain 값 객체로 올릴지, 작은 공유 mapper만 둘지 현재 의존 구조에 맞춰 결정한다.
- `GroupMember`, `GroupMemberDisplaySnapshot`, `GroupMemberDisplay`에 nullable 요약을 추가한다.
- 완전한 다섯 값, `null`, 필드 부재, 불완전·잘못된 타입의 읽기 결과를 테스트로 고정한다.

#### B. 생성·가입 write plan 전파

- 그룹 생성과 초대코드 가입은 선택 Character의 선호 역할 Build에서 요약을 만든다.
- 가입 신청은 relation에 요약을 기록하고 승인 시 값 전체를 그대로 membership에 전달한다.
- 직접 초대 relation은 타인의 로컬 Build를 추정하지 않고 `null`을 유지한다. 수락 시 로컬 값을 안전하게 제공할 기존 경로가 없으면 가입 직후 self refresh로 보강한다.
- 가입 실패·재시도·동시 승인에서 기존 revision, 정원, membership state와 멱등성 계약을 변경하지 않는다.

#### C. 본인 Snapshot 보강

- 기존 그룹 상세 본인 전투력 보강 경로에 같은 표시 Character의 보석 요약을 연결한다.
- itemLevel·combatPower·보석 요약 중 일부만 새 값이 있어도 기존 서버 값을 소실하지 않는 merge 규칙을 적용한다.
- 실제 값이 같으면 불필요한 Transaction과 revision 증가를 만들지 않는다.
- 활동 Character에서 빠진 표시 Character, 소유권 상실, 서버 ID 불일치와 로컬 Snapshot 부재는 기존 오류·보존 정책을 따른다.

#### D. 읽기·UI 표시

- 그룹 member mapper가 선택 필드를 방어적으로 읽도록 한다.
- 그룹원 카드에는 정상 상태를 추가 표시하지 않는다.
- 동일 직업·대상 미확인과 검증 불가는 중립 안내, 다른 직업 보석만 빨간 경고로 표시한다.
- 보석 요약 오류 때문에 그룹원 목록 전체가 실패하지 않도록 한다.
- 카드 높이와 탭 대상은 기존 그룹 UI를 유지하고 Build 별칭·메모 공간은 미리 만들지 않는다.

#### E. Firestore Rules 최소 변경

- membership 및 필요한 join relation의 문서 키 allowlist에 `gemValidationSnapshot`만 추가한다.
- 본인 Snapshot 갱신의 `affectedKeys`에 해당 필드를 추가하되 기존 호출자·Player binding·Character 소유권·revision 조건을 완화하지 않는다.
- 파티 membership 계약과 같이 다섯 내부 값의 진위를 Rules에서 재검증하지 않는다. map/null 허용 여부와 변경 가능한 명령 경계만 제한한다.
- 생성·초대·신청·코드 가입·탈퇴·이전·해산 분기 순서를 유지하고 Rules 컴파일 경고 0개를 완료 조건으로 둔다.

#### F. 문서화와 Git 종료

- 구현 결과, 실제 필드 출처의 예외, 자동·실기기 검증, Rules 배포 결과를 `DEV_LOG.md`에 기록한다.
- `CHARACTER_BUILD_INTEGRITY_CONTRACT.md`의 그룹 대기 상태와 `FIRESTORE_GROUP_MEMBERSHIP_CONTRACT.md`의 Snapshot 계약을 실제 구현에 맞게 갱신한다.
- 완료 뒤 `NEXT_WORK.md`에서는 상세를 제거하고 다음 단일 그룹만 남긴다.
- 기능 브랜치를 `dev`에 직접 병합·푸시하고 로컬·원격 `dev`의 최종 커밋 일치와 깨끗한 작업 트리를 확인한다.

### 9. 자동 검증 계획

기능 섹션이 모두 연결된 뒤 아래를 한 묶음으로 실행한다.

- Domain/mapper: 정상·중립·위험·검증 불가·null·불완전 맵 파싱
- write plan: 생성, 신청 relation, 승인 복사, 초대 수락 null 호환, 코드 가입, self refresh 기존값 보존
- Repository: 실제 Player ID와 표시 Character ID 사용, 동일값 no-op, 실패 시 기존 목록 유지
- UI: 정상 숨김, 중립 안내, 빨간 경고, 과거 membership 표시 유지
- Rules 계약: 허용 키, update `affectedKeys`, 관계 복사, 기존 소유권·revision·정원·역할 이전·삭제 조건 보존
- 영향 회귀: 그룹 생성·초대·신청·승인·코드 가입·탈퇴·그룹장 양도·1인 해산·전투력 보강
- 변경 파일 `flutter analyze`
- Rules·공용 Domain·여러 가입 경로를 함께 변경하므로 최종 상태에서 전체 `flutter test`와 전체 `flutter analyze` 각 1회

중간 A~E 구간에서는 테스트 코드를 함께 작성하되 코드 포맷, `git diff --check`, diff 검토만 수행한다. 인증·Rules 기반이 잘못됐는지 구분해야 할 때만 가장 좁은 테스트를 예외로 먼저 실행한다.

### 10. Rules 배포 게이트

1. 현재 기능 브랜치, `firebase.json`의 대상이 `firestore.rules`인지, 대상 Firebase 프로젝트와 최종 diff를 다시 확인한다.
2. 로컬 테스트·정적 분석·Rules 계약 검사와 전체 최종 검증을 먼저 통과시킨다.
3. `--dry-run`을 중복 실행하지 않고 최신 추적본을 실제 운영 프로젝트에 정확히 1회 배포 시도한다.
4. 실패하면 즉시 반복하지 않는다. `/test`·`/rulesets`·`/releases` 실패 단계, 컴파일 경고, 콘솔 게시 시각·활성 소스와 직전 성공본 diff를 보고한다.
5. 재배포는 사용자의 새 지시가 있을 때만 1회 수행한다.

### 11. 통합 실기기 체크리스트

두 Player·두 기기에서 자동 검증 완료와 Rules 배포 성공 뒤 한 번만 요청한다.

1. 보석 정상 Character로 그룹 생성 후 그룹원 카드에 불필요한 경고가 없는지 확인
2. 다른 직업 보석 Character로 가입 신청 → 승인 후 상대 기기의 그룹원 카드에 빨간 경고가 보이는지 확인
3. 동일 직업·대상 미확인 또는 검증 정보 없음은 빨간색이 아닌 중립 안내인지 확인
4. 직접 초대 수락 직후 값이 없더라도 가입이 막히지 않고, 대상 사용자가 그룹 상세를 새로고침하면 요약이 보강되는지 확인
5. 초대코드 가입과 앱 재실행 후 Snapshot이 유지되는지 확인
6. 과거 membership 또는 Snapshot 없는 Character가 이름·직업·아이템 레벨·전투력을 계속 표시하는지 확인
7. 그룹원 전투력 새로고침, 탈퇴, 그룹장 양도와 마지막 1인 해산이 그대로 동작하는지 확인
8. 다음 통합 확인에 묶인 수동 인증 및 파티 membership Build Snapshot 표시도 함께 회귀 확인

### 12. 완료 조건

- 모든 그룹 membership 생성 경로의 Snapshot 출처와 null 처리 방식이 코드·테스트·문서에서 일치한다.
- 그룹원 카드가 파티 구성원 카드와 같은 보석 경고 정책을 사용한다.
- 과거 문서·불완전 데이터·로컬 Snapshot 부재가 가입이나 그룹 목록 전체를 차단하지 않는다.
- 기존 그룹 명령과 전투력 보강 회귀가 자동 검증을 통과한다.
- 최종 전체 `flutter test`, 전체 `flutter analyze`, Rules 계약 검사가 통과하고 Rules 컴파일 경고가 0개다.
- 최신 Rules 실제 배포 결과가 확인되고 통합 실기기 체크리스트가 통과한다.
- 완료 문서 정리 후 기능 브랜치가 `dev`에 병합·푸시되며 로컬·원격 `dev`가 일치한다.

## 차후 대기

- Build 별칭·직업 메모·JSON 공유: `BUILD_MEMO_SHARING.md`의 단계별 제품 결정을 먼저 확정
- 여러 일반 딜러 직업의 보석 판정 실계정 확대 검증
- 서버 데이터 무결성·고아 binding/claim·복구 절차: 반복 사례가 확인될 때 별도 착수
- 직업 시너지 선택·필터: `CLASS_SYNERGY_CATALOG.md`
