# NEXT WORK — BUG-018 다인 모집 해산 권한 회귀 실기기 확인

## 현재 상태

- 현재 브랜치는 `codex/feat-raid-party-reposition`이며 작업 트리는 문서 계획 작성 전 깨끗했다.
- 수정 Rules 게시 후 모집 생성·가입·빈자리 이동·점유 자리 교환과 동일 파티 중복 직업 교환 차단이 실기기에서 정상 작동했다.
- 그룹 생성·그룹장 이전·일반 탈퇴·마지막 1인 해산과 파티 탈퇴 후 재신청도 정상 작동했다.
- 리더 혼자 남은 모집은 해산되지만, 리더 외 확정 참가자가 있는 모집은 파티장이 해산할 때 `permission-denied`로 실패한다. 화면에는 Rules 배포 상태를 확인하라는 권한 안내가 표시된다.
- 해산 Repository와 Firestore Rules의 최소 수정 및 자동 검증을 완료했다. 운영 Rules 배포와 실기기 확인 전까지 완료로 닫지 않는다.
- 운영 CLI는 `/test` 컴파일 성공·경고 0건 뒤 `/rulesets`에서 503이 발생했고, 사용자가 별도 테스트 프로젝트의 콘솔에서도 같은 현재 Rules 게시가 반복적으로 503 실패함을 확인했다. 단일 프로젝트 권한·데이터·요금제 문제보다 현재 Rules 소스 형태가 Ruleset 저장 단계의 내부 복잡도 경계 또는 서비스 결함을 유발할 가능성을 우선한다.

## 구현 결과

- v2 모집 해산은 각 membership의 `partyIndex`·`slotIndex`로 슬롯 Claim을 다시 읽고 `playerId` 일치를 확인한다. 누락·불일치는 `revisionConflict`로 전체 쓰기를 중단한다.
- 검증된 슬롯 Claim은 membership·assignment·group listing과 같은 Transaction에서 삭제한다. 과거 모집은 슬롯 Claim을 요구하지 않는다.
- 슬롯 삭제 Rules는 각 Claim의 소유자와 membership 제거를 연결한다. membership 삭제마다 슬롯 부재를 추가 조회하는 역방향 강제는 8인 복합 쓰기의 Rules 문서 접근 한도를 침범할 수 있어 추가하지 않았다.
- Player event Rules는 `data.type`을 먼저 확인한 뒤 해당 계열 validator만 실행한다. `partyDisbanded`는 무관한 cycle/application/membership validator를 거치지 않는다.
- `validRecruitmentDisband`, 리더 권한, revision, assignment·listing과 lifecycle event 수신자 조건은 완화하지 않았다.

## Rules 게시 503 원인 예상과 최소 축소 계획

### 근거

- `/test`가 HTTP 200으로 성공했으므로 문법 오류나 정적 컴파일 경고는 현재 직접 원인이 아니다.
- `/rulesets` 저장과 테스트 프로젝트 콘솔 게시가 모두 실패하므로 앱 Transaction, 운영 데이터, 특정 Auth 계정 상태는 원인에서 제외한다.
- 직전 콘솔 게시에 성공한 자리 조정 Rules `c4344e6`과 현재 Rules의 유일한 기능 diff는 `validPlayerEvent` dispatcher다. 현재 변경은 5개 OR 호출을 27행의 type 목록·guard 식으로 확장했고 소스가 약 578자 증가했다. 함수 수는 199개로 같다.
- Firebase가 Ruleset의 실제 컴파일 산출물 한계나 내부 오류 기준을 명확히 반환하지 않고 503으로 종료한 과거 사례가 있다. 따라서 파일 크기 자체로 단정하지 않되, 이번 diff를 가장 작은 A/B 경계로 사용한다.

### 1차 수정안

- 현재 27행 dispatcher를 짧은 우선순위 OR로 되돌린다.
- `validLifecycleEvent`를 `validCycleEvent`보다 먼저 평가해 `partyDisbanded`가 성공하면 무관한 cycle 문서를 읽지 않도록 한다.
- 수동 인증 이벤트는 명시적인 `data.type == 'manualVerificationDisputeOpened'` guard 뒤에 validator를 호출하고 cycle보다 먼저 둔다. 나머지 application·membership wrapper는 기존 type 분기를 그대로 재사용한다.
- 예상 형태는 `lifecycle → application → membership → guarded manual verification → cycle`이다. 허용 type·필드·수신자·revision 조건은 바꾸지 않고 dispatcher 표현만 축소한다.

### 게시 판정 순서

1. compact dispatcher의 정적 계약·관련 이벤트 회귀와 전체 Rules 로컬 컴파일을 확인한다.
2. 변경 전후 bytes·행·함수 수와 `c4344e6` 대비 diff를 기록한다.
3. 사용자가 테스트 프로젝트 콘솔에 compact Rules를 먼저 게시한다.
4. compact가 게시되면 현재 dispatcher 표현이 Ruleset 저장 경계를 건드린 것으로 판정하고 운영 게시 후 다인 해산을 확인한다.
5. compact도 실패하면 **코드를 더 삭제하지 않고** 테스트 프로젝트에 직전 성공 기준 `c4344e6` Rules를 게시해 외부 서비스 장애와 현재 소스 요인을 분리한다.
6. 같은 시점에 `c4344e6`도 실패하면 Firebase Rules 서비스 장애로 판정하고 대기한다. `c4344e6`만 성공하면 R4 이벤트 dispatcher·validator의 추가 중복 축소를 별도 설계한다.

이 진단에서 deny-all, 기능 stub, 권한 완화 Rules는 테스트 프로젝트에도 게시하지 않는다. 운영 Rules는 compact 테스트 프로젝트 게시 성공 전에는 변경하지 않는다.

### compact dispatcher 구현·로컬 검증 결과

- `validPlayerEvent`를 `lifecycle → application → membership → guarded manual verification → cycle` 순서의 6행 dispatcher로 축약했다.
- 직전 게시 성공 기준 `c4344e6` 대비 Rules 기능 diff는 이 dispatcher의 평가 순서 변경과 수동 인증 type guard 추가뿐이며, 함수 수는 양쪽 모두 199개다. 작업 트리 줄바꿈 형식이 기준 blob과 달라 단순 byte 수는 진단 지표로 사용하지 않는다.
- 파티 해산·슬롯 원장·이벤트·회차·listing 표적 회귀 18건과 Rules 경고 계약 3건이 통과했다.
- 전체 `firestore.rules`는 로컬 Firestore Emulator에서 컴파일되고 정상 기동됐다.
- 원격 `/rulesets` 저장 성공 여부는 아직 확인하지 않았다. 다음 단계는 사용자가 이 추적본을 별도 테스트 프로젝트 콘솔에 먼저 게시하는 것이다.

## 확인한 기존 계약과 실제 흐름

- 다인 해산은 파티장만 실행하며 모집을 `disbanded`로 바꾸고, 모든 membership과 존재하는 assignment를 삭제하고, 그룹 listing이 있으면 삭제하며, 파티장 외 기존 멤버와 대기 신청자에게 `partyDisbanded` 이벤트를 같은 Transaction에서 기록한다.
- 기존 Repository는 Firestore의 `모든 읽기 후 쓰기` 제약을 지키기 위해 membership·application·assignment와 listing을 먼저 읽은 뒤 삭제·갱신·이벤트 생성을 수행한다.
- `validRecruitmentDisband` 자체의 필드 allowlist와 리더·revision 조건은 2026-08-26 이후 바뀌지 않았다. 따라서 모집 원본 update만을 직접 원인으로 단정하지 않는다.
- 신규 `slotLedgerVersion: 2` 모집은 membership 자리마다 `recruitments/{id}/slots/{partyIndex}_{slotIndex}` Claim을 만들지만, 현재 해산 Transaction은 이 Claim을 읽거나 삭제하지 않는다. 해산 후 고아 슬롯 Claim이 남는 계약 누락은 확정적이다.
- 다인 해산은 단독 해산과 달리 파티장 외 수신자에게 `partyDisbanded` 이벤트를 생성한다. 현재 `validPlayerEvent`는 이벤트 종류를 먼저 분기하지 않고 cycle·application·membership·lifecycle 검사들을 OR로 평가하며, `validCycleEvent`는 type 확인 전에 cycle 문서를 읽는다. 다인일 때만 추가되는 Rules 경로이므로 우선 조사 대상이다.
- 현재 Widget 테스트는 다인 해산 버튼이 명령을 보냈는지만 확인한다. 실제 Repository Transaction과 Rules를 함께 실행하는 다인 해산 계약 테스트가 없어 이번 회귀를 잡지 못했다.

## 원인 가설과 판정 순서

1. **해산 이벤트 Rules 경로**: 리더 외 멤버에게 생성되는 `partyDisbanded` 이벤트가 불필요한 이벤트 validator 평가, 존재하지 않는 cycle/application 경로 접근 또는 문서 접근 예산 때문에 거절되는지 확인한다.
2. **슬롯 Claim 수명 누락**: v2 모집 해산 시 membership만 삭제하고 슬롯 Claim을 남기는 현재 Transaction을 확인하고, Claim 동시 삭제를 포함한 완전한 해산 Write Plan을 고정한다.
3. **복합 Transaction의 Rules 접근 예산**: recruitment, 각 membership·assignment·slot, group listing과 수신자 event 검증이 4인·8인 및 대기 신청 포함 상태에서 Firestore 다중 문서 요청 한도를 넘는지 Emulator 로그로 계산한다.
4. **그룹 listing 분기**: 공개 모집과 그룹 모집을 분리해 listing 삭제 Rules가 원인인지 확인한다. 공개 모집에서도 재현되면 listing은 주원인에서 제외한다.
5. **기존/신규 방 호환**: `slotLedgerVersion`이 없는 과거 방과 v2 신규 방을 분리해, 최근 슬롯 원장 변경과의 인과를 확인한다.

권한 안내 문구만으로 특정 함수가 원인이라고 확정하지 않는다. 최소 재현 Transaction에서 실패한 write와 Rules 평가 로그를 확보한 뒤 수정 지점을 결정한다.

## 구현 준비안

### 1. 재현 계약 테스트

- `tools/party_disband_rules_test.mjs`를 추가해 Firebase Emulator에서 운영 Rules와 실제 해산 Write Plan에 해당하는 Transaction을 실행한다.
- 최소 표본은 `단독`, `2인 공개 v2`, `2인 그룹 v2`, `2인 과거 방`, `8인 v2`, `완료 후 해산`, `대기 신청 포함`이다.
- 2인 공개 v2를 기준으로 이벤트 생성 유무를 분리해 lifecycle event가 직접 거절 지점인지 확인한다. 슬롯 Claim 삭제 유무도 별도 대조해 원인과 데이터 정합성 보완을 구분한다.
- 성공 후 모든 membership·assignment·slot·group listing의 부재, recruitment의 `disbanded` 상태·빈 멤버 목록·revision 증가와 수신자 event 존재를 검증한다. 실패 Transaction에는 부분 삭제가 없어야 한다.

### 2. 최소 수정 원칙

- 해산 Repository가 v2 모집의 슬롯 Claim을 membership·assignment와 함께 먼저 읽고 같은 Transaction에서 삭제하도록 한다. 과거 방은 슬롯 Claim 부재를 허용한다.
- 이벤트가 원인이면 `validPlayerEvent`를 `data.type` 기반 dispatcher로 바꿔 해당 유형 validator만 평가한다. `partyDisbanded`에서 무관한 cycle/application/membership 조회를 하지 않는다.
- 실제 실패 근거 없이 `validRecruitmentDisband`, membership·assignment 소유권, revision, listing 동기화 또는 이벤트 수신자 검증을 완화하지 않는다.
- Rules 문서 접근 한도가 원인이면 검증을 삭제하는 방식이 아니라 동일 문서 접근의 중복 제거와 type 선분기를 우선한다. 그래도 8인+대기 신청에서 한도를 넘으면 이벤트 fan-out만 해산 상태 변경과 분리할지 별도 제품 결정을 요청한다.

## 회귀 보호 목록

- 단독 공개 모집 해산과 리더 외 멤버가 있는 공개 모집 해산
- 그룹 전용 모집 해산 및 `raidListings` 원자 삭제
- 활성 모집 해산과 1회성 완료 후 해산 대기 방 해산
- membership·assignment·v2 slot Claim 완전 삭제, 과거 방의 slot 부재 호환
- 파티장 외 기존 멤버와 pending 신청자 `partyDisbanded` 이벤트, 행위자 이벤트 제외
- 파티 탈퇴 후 재신청, 일반 탈퇴·추방·책임자 승계
- 모집 생성·신청·직접 참가·승인과 자리 이동·교환
- 그룹 생성·그룹장 이전·일반 탈퇴·마지막 1인 그룹 해산
- revision 충돌·비리더 해산·이미 종료된 방 거절과 Transaction 원자성

## 수행한 검증과 남은 순서

1. 해산·슬롯·이벤트 표적 계약 18건이 통과했다.
2. 모집 전체·파티 상세·그룹 영향 회귀 549건이 통과했다.
3. 변경 Dart 파일 정적 분석은 문제 0건이며 전체 Rules는 로컬 Emulator 시작 단계에서 정상 컴파일됐다.
4. 실제 다인 Transaction Emulator 테스트는 전체 Rules 재업로드 503과 Node SDK gRPC 전송 오류로 실행되지 않았다. 이를 통과로 기록하지 않는다.
5. 커밋 `a5a28d6`의 최신 추적본으로 운영 배포를 한 번 시도했다. `/test` 원격 컴파일은 성공하고 경고가 없었지만 `/rulesets` 업로드가 HTTP 503으로 실패해 새 Rules는 운영에 반영되지 않았다. `/releases` 갱신에는 도달하지 않았으며 재시도하지 않는다.
6. 사용자가 로컬 `firestore.rules`를 콘솔에서 게시하거나 별도 재배포를 지시한 뒤, 같은 앱 빌드로 공개/그룹 2인 이상 모집 해산과 기존 정상 흐름을 실기기에서 확인한다.

## 완료 조건

- 파티장이 리더 외 확정 참가자가 있는 공개·그룹 모집을 해산할 수 있다.
- 해산 성공 후 recruitment 외 membership·assignment·v2 slot Claim과 group listing이 계약대로 정리되고 부분 상태가 남지 않는다.
- 해산 이벤트가 지정 수신자에게 한 번 기록되고 행위자에게는 생성되지 않는다.
- 단독·완료 후·과거 모집 해산과 기존 생성·가입·탈퇴·재신청·자리 조정·그룹 명령이 회귀하지 않는다.
- Rules 변경 시 Emulator 계약, 정적 Rules 계약, 원격 컴파일 경고 0개와 허가된 운영 배포 결과를 기록한다.

## 제외 범위

- 해산 UX와 안내 문구 변경
- 알림 시스템 전체 재설계 또는 FCM 추가
- 과거 해산 방에 남은 고아 slot Claim의 일괄 마이그레이션·삭제
- 역할·직업 구성 정책과 자리 조정 알고리즘 변경
- Firestore Rules 전면 재작성과 다른 collection 권한 재설계

## 차후 후보

- 앱을 종료하지 않은 채 수요일 06:00 KST 주차 경계를 통과할 때 Router 생성 시 계산된 `currentCycleKey` 자동 갱신
- 딜러 직업·깨달음 분기별 특수 보석 대상의 점진적 카탈로그 추가
- 룬·각인·카드·엘릭서 등 통합 무결성 상태 확장
- Build 별칭·직업 메모·JSON 공유: `BUILD_MEMO_SHARING.md`
- 직업 시너지 선택·필터: `CLASS_SYNERGY_CATALOG.md`
- 서버 데이터 무결성·고아 binding/claim·복구 절차
- `characters` Rules의 넓은 `signedIn()` 읽기·쓰기 권한 재설계
