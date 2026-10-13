# Backend, Party Recruitment and Account Group Architecture

> 기존 서비스 전용 항목은 [원문·출처 기록](../../legacy/firebase/extracted/docs/architecture/BACKEND_PARTY_ARCHITECTURE.md)으로 분리했다. 남은 제품/협업 문맥의 신규 서버 적용 여부는 별도 설계에서 판단한다.

## 1. 목적

LOSTPARTY의 정적 레이드 기준정보, 멀티유저 파티 모집/신청/승인 및 계정 그룹 전용 모집글을 구현하기 위한 기준 아키텍처다.





---

## 2. 현재 기술 구성

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/architecture/BACKEND_PARTY_ARCHITECTURE.md#source-0005)로 이동했다.

## 3. 신뢰 경계

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/architecture/BACKEND_PARTY_ARCHITECTURE.md#source-0006)로 이동했다.

## 4. 정적 레이드 카탈로그

Lost Ark API가 레이드 기준정보를 제공하지 않으므로 다음 정보는 Git으로 버전 관리하는 JSON 카탈로그에 수기 입력한다.

- 레이드 ID와 표시명
- 난이도와 정렬 순서
- 관문 수와 파티 정원
- 최소 아이템 레벨
- 역할 구성 기본값
- 보상 정보
- 활성/비활성 상태와 데이터 버전


모집글은 임의의 레이드 속성을 신뢰하지 않고 `raidId`, `difficultyId`, `raidCatalogVersion`을 저장한다. 서버는 모집 생성 시 카탈로그를 이용해 관문, 정원 및 최소 레벨을 검증한다.

---

## 5. 파티 모집 데이터

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/architecture/BACKEND_PARTY_ARCHITECTURE.md#source-0008)로 이동했다.

## 6. 모집글 공개 범위

```text
RecruitmentVisibility
  public
  groupOnly
```

### public

- 로그인 사용자에게 공개
- 목록 후보 조회 후 앱에서 캐릭터별 조건을 표시 필터링
- 신청 시 서버가 모든 조건을 다시 검증

### groupOnly

- 모집글의 `groupId`에 가입된 현재 멤버만 조회 가능
- 모집 생성자도 해당 그룹의 현재 멤버여야 함
- 목록 조회뿐 아니라 상세 조회와 신청 시점에도 멤버십을 다시 검증
- 그룹 탈퇴 또는 추방 후에는 새 조회와 신청 권한을 잃음
- 이미 파티에 가입된 사용자의 처리 정책은 파티 멤버십을 우선하며 자동 퇴장시키지 않음


---

## 7. 계정 그룹

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/architecture/BACKEND_PARTY_ARCHITECTURE.md#source-0010)로 이동했다.

## 8. 그룹 초대 상태

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/architecture/BACKEND_PARTY_ARCHITECTURE.md#source-0011)로 이동했다.

## 9. 파티 가입 승인 정책

```text
ApprovalMode
  manualApproval
  directJoin
  anyMember
  quorum

ApprovalPolicy
  mode
  requiredApprovals
  leaderVoteRequired
  rejectionMode
```

- `manualApproval`: 파티장·공대장 또는 책임자가 현재 참가자에게 부여한 가입 승인권자가 승인/거절
- `directJoin`: 신청 조건을 만족하면 별도 승인 없이 같은 명령에서 즉시 가입
- `anyMember`: 현재 파티원 한 명의 승인으로 가입
- `quorum`: 서로 다른 현재 파티원 N명의 승인으로 가입
- 비율 기반 동의는 파티원 수 변경에 따라 의미가 달라지므로 초기 범위에서 제외

초기 제품의 신규 모집 생성 화면은 사용자에게 `파티장 승인`과 `승인 없이 바로 가입`만 제공한다. 전자는 서버의 `manualApproval`, 후자는 `directJoin`에 대응한다. 기존 `leaderOnly` enum을 코드 호환 때문에 유지한다면 파티장과 지정 승인권자를 포함하는 의미로 명시적으로 마이그레이션한다. `anyMember`와 `quorum`은 기존 Domain/저장 데이터 호환을 위해 유지하지만 신규 선택지는 노출하지 않는다.

승인 Function은 인증, 승인 권한, 신청 상태, 중복 투표, 전체 정원, 역할별 자리, 가입 조건 및 승인 수를 한 트랜잭션에서 검증한다.

기준을 만족하면 같은 트랜잭션에서 신청서 승인, 멤버 생성, 전체/역할별 인원 및 모집 상태를 갱신한다.

### 승인 후 캐릭터 교체

- 현재 파티원은 완료 전까지 자기 멤버 문서의 캐릭터만 교체 요청할 수 있다.
- 승인된 역할과 파티 위치는 유지한다.
- 서버는 캐릭터 소유권, 역할 세팅, 카탈로그 입장 레벨, 활성 참가 점유, 선택 모집 조건 및 동일 딜러 직업 제한을 최신 값으로 재검증한다. 사용자가 수정할 수 있는 로컬 개인 완료는 서버 강제 조건으로 사용하지 않는다.
- 교체 후 전체 파티 구성이 유효할 때만 추가 승인 없이 한 트랜잭션으로 멤버 스냅샷을 교체한다.
- 같은 사용자의 본계정과 부계정 캐릭터를 모두 후보로 사용할 수 있다.
- 대상 캐릭터의 같은 레이드 승인 대기 신청은 사용자 확인 후 철회와 교체를 하나의 서버 명령으로 처리한다.
- 대상 캐릭터가 다른 파티에 확정 참가 중이면 단순 교체와 구분해 `이동` 또는 양쪽 파티 조건을 모두 만족하는 `스왑` 명령으로 처리한다.
- 초기 구현은 승인 대기 신청 철회 후 변경을 우선하고, 확정 파티 간 이동·스왑은 다중 문서 트랜잭션과 탈퇴 정책 구현 후 제공한다.

---

## 10. 목록 노출과 신청 검증


```text
recruitmentVisible == true
visibility == public
raidId == selectedRaidId
targetCycleKey >= currentCycleKey
```

- `recruitmentVisible`은 `manualRecruitmentEnabled && hasAvailableSlot`의 서버 관리 결과다.
- 반복 파티 완료 후에는 `targetCycleKey`를 다음 주차로 설정하고 카드에 `다음 주 레이드 구성 현황입니다.`를 표시한다.
- 신청, 승인과 참가 Character 변경은 `targetCycleKey`의 구성에만 반영한다.

그룹 전용 목록은 현재 가입 그룹의 `groups/{groupId}/raidListings`를 읽어 공개 모집 첫 페이지와 합친다.

아이템 레벨, 역할 자리, 숙련도 및 캐릭터별 지원 가능 여부는 앱에서 표시 필터링할 수 있지만, 신청 성공을 보장하지 않는다. 서버가 신청 시 최신 모집 상태와 검증된 캐릭터 스냅샷으로 다시 판정한다.

---

## 11. Firestore Transaction 명령 경계

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/architecture/BACKEND_PARTY_ARCHITECTURE.md#source-0013)로 이동했다.

## 12. Security Rules 기준

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/architecture/BACKEND_PARTY_ARCHITECTURE.md#source-0014)로 이동했다.

## 13. 기능 단위 설계와 단계적 구현 순서

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/architecture/BACKEND_PARTY_ARCHITECTURE.md#source-0015)로 이동했다.

