# 파티·그룹 명령 확장성 재설계

## 1. 상태와 목적

- 2026-09-14 사용자 결정으로 기존 `release/1.0.0` 후보는 폐기한다. 브랜치는 비교·이력용으로만 보존하고 출시·`main` 병합 기준으로 사용하지 않는다.
- 다인 모집 해산이 최신 앱과 운영 Rules에서도 `permission-denied`로 실패했다. 해산 버튼을 숨기는 임시 UI 변경은 철회하고 기존 UI를 유지한다.
- 문제는 해산 한 건에 한정하지 않는다. 현재 일부 파티 명령은 인원수 `N`에 비례해 membership·Claim·assignment·slot·개인 event를 같은 Transaction에서 읽고 쓴다. Firestore Rules의 다중 문서 원자 작업 접근 호출 한도와 결합하면 4인·8인에서만 실패할 수 있다.
- 목표는 UI·제품 정책을 버리는 전면 재개발이 아니라 Firestore 명령 Repository, Rules, 이벤트와 Projection 책임을 인원수와 무관한 경계로 재설계하는 것이다.

## 2. 현재 구조 위험 목록

| 영역 | 현재 증가 요인 | 영향 |
| --- | --- | --- |
| 파티 전체 완료 | 전원 membership·주간 Claim·assignment 조회, 전원 Claim·개인 event 생성, assignment 삭제 | 4·8인에서 Transaction·Rules 한도, 일부 완료·점유 잔존 위험 |
| 완료 취소 | 완료 Snapshot 전원 membership·Claim·assignment 조회, Claim 삭제·assignment 복원·개인 event 생성 | 취소 실패, Claim과 점유 불일치 위험 |
| 다음 주차 전환 | 전원 membership·assignment 조회와 재생성·갱신, 미완료 개인 event 생성 | 반복방이 새 주차로 넘어가지 못하거나 일부 점유가 이전 주차에 남을 위험 |
| 모집 해산 | 전원 membership·assignment·slot 삭제, 신청 전체 확인, 멤버·대기자 개인 event 생성 | 현재 재현된 다인 `permission-denied`, 고아 관계 위험 |
| 자리 이동·교환 | 전원 membership 재조회·구성 계산, 이동 1건당 전원 개인 event 생성; 교환은 두 사건 fan-out | 8인에서 자리 이동만 실패하거나 중복 이벤트가 급증할 위험 |
| 참가 Character 변경 | 자리 결정을 위해 전원 membership 재조회, 변경 사건을 전원 개인 event로 복제 | 인원수에 따른 실패, 자리·직업 구성 Snapshot 불일치 위험 |
| 즉시 가입 | 기존 전원 membership 재조회, 기존 전원에게 `memberJoined` 개인 event 생성 | 방이 찰수록 가입 실패 가능성 증가 |
| 신청 승인 | 자리 결정을 위해 기존 전원 membership 재조회 | 승인 경쟁·8인 근접 상태에서 지연 및 충돌 증가 |
| 탈퇴·추방 | 핵심 변경은 대상 중심이나 전원 개인 event 생성, 파티장 탈퇴 시 후임 membership 추가 갱신 | 인원이 많을 때 정상 탈퇴·승계까지 알림 때문에 실패할 위험 |
| 그룹 전용 전환 | 확정 멤버와 pending 신청자별 그룹 membership 조회 | 인원·신청 증가 시 전환 실패, 조회 시점과 Transaction 상태 불일치 위험 |
| 그룹 해산 사전 검사 | `raidListings` 최대 20개를 순회해 recruitment를 개별 조회 | 20개 이후 활성 모집 누락, 느린 해산 판정 위험 |
| 목록·알림 읽기 | 가입 그룹별 listing 구독, Player별 복제 event 조회 | 그룹 수·이벤트 수 증가에 따른 구독·읽기 비용과 중복 동기화 |

그룹 생성·초대·가입 신청·거절·일반 탈퇴·그룹장 이전처럼 정해진 소수 문서만 다루는 명령은 우선 보존한다. 표시를 위해 전체 멤버 목록을 한 번 읽는 행위 자체는 정상이며, **하나의 상태 변경을 위해 전원을 Transaction에서 재조회하거나 전원별 쓰기를 만드는 구간**과 구분한다.

## 3. 공통 개선 묶음

### A. 공용 이벤트 원본

- 한 사건은 파티 또는 그룹 공용 이벤트 문서 **한 건**으로 저장한다.
- `audiencePlayerIds`, `actorPlayerId`, `targetPlayerId`, `revision`, `occurredAt`으로 읽기 권한과 수신 대상을 표현한다.
- 수신 목록은 `audiencePlayerIds array-contains 현재 Player ID` 조건으로 조회하고, Rules도 같은 audience 포함 여부를 읽기 조건으로 사용한다. 쿼리와 Rules가 서로 다른 조건을 요구해 목록 전체가 거부되는 회귀를 막는다.
- Player별 문서 복제를 핵심 Transaction에서 제거한다. 개인 읽음 상태가 필요하면 이벤트 원본과 분리한 Player별 cursor/receipt로 관리한다.
- 탈퇴·추방·해산 후에도 기존 수신자가 이력을 읽을 수 있도록 이벤트 당시 audience를 권한 기준으로 사용한다.

### B. 모집 Aggregate와 구성 요약

- `recruitments/{id}`를 명령 충돌의 기준으로 유지하고 모든 변경은 `expectedRevision`을 비교한다.
- 현재 자리·역할·구성 직업을 결정적으로 표현하는 고정 최대 8칸 구성 요약을 모집 원본에 둔다.
- 가입·승인·Character 변경·자리 이동은 로컬에서 결과를 계산하되, Rules는 revision과 변경 전후 구성 요약 및 직접 대상 문서만 검증한다.
- 명령마다 전체 membership을 Transaction에서 다시 읽어 같은 구성을 재조립하지 않는다.

### C. 최대 8인 제한 원자 명령

- Cloud Functions가 없는 Spark 환경에서 원래 명령자 재접속에 의존하는 `processing → 후속 단계 → complete` 방식은 사용하지 않는다.
- 완료·취소·주차 전환·해산의 **정확성에 필요한 상태**를 현재 제품 상한인 8명 안에서 한 Firestore Transaction으로 확정한다. Transaction은 전부 성공하거나 전부 실패하므로 앱 종료 뒤 이어서 실행할 핵심 정리가 없어야 한다.
- 기존 `activeRaidAssignment`와 `weeklyRaidClaim`은 Character·레이드별 통합 `raidState`로 교체하는 방향을 기준으로 한다. `active`, `completed`, 문서 없음으로 참가 점유와 이번 주 완료를 한 문서에서 표현한다.
- 모집 원본에는 `revision`, `lastCommandId`, 명령 종류·행위자·대상 `raidState` ID를 담은 제한 크기 명령 검증 정보를 둔다. Rules는 전원 membership을 다시 조립하지 않고 Transaction 후 모집 원본과 직접 대상 문서만 검증한다.
- 완료·취소·주차 전환은 모집·회차·최대 8개 `raidState`·필요 listing·공용 이벤트 1건을 같은 원자 명령으로 처리한다. 활성 모집 해산은 최대 8개 `raidState` 점유를 해제하고, 완료 후 해산은 `completed` 상태를 보존한다.
- 8인 최악 조건에서도 Rules 문서 접근 호출이 Transaction 전체 20회, 개별 쓰기 10회를 넘지 않는다는 Emulator 계약 테스트를 구현 전에 먼저 고정한다. 같은 경로가 캐시될 것이라고 가정해 한도를 계산하지 않는다.

### D. 종료 상태와 비핵심 자료 분리

- `members`, `slots`, `applications`와 과거 회차 자료를 해산 Transaction에서 전부 삭제하지 않는다. 모집 원본의 `completed`·`disbanded` 상태를 활성 여부의 유일한 기준으로 삼는다.
- 종료된 모집의 하위 문서는 신규 신청·승인·자리 변경·점유 판정에 참여할 수 없도록 모든 Repository와 Rules가 부모 상태를 먼저 확인한다.
- 활성 목록은 모집 원본 상태로 제외한다. 참가 신청 목록처럼 부모 조건을 쿼리에 직접 결합할 수 없는 화면은 모집 원본을 확인해 종료 항목을 자동으로 숨기고, 본인 소유의 오래된 Projection만 재진입 시 조용히 정리할 수 있다.
- 지연 정리는 저장공간 관리와 화면 Projection 정돈을 위한 비핵심 작업이다. 실패하거나 아무도 다시 접속하지 않아도 참가·완료·해산의 정확성과 사용자 행동을 막지 않아야 한다.
- 해산 시 pending 신청자 수만큼 쓰기나 이벤트를 복제하지 않는다. 신청자는 자신이 이미 알고 있는 모집 원본의 종료 상태로 결과를 확인하고 앱이 로컬 안내를 구성한다.

### E. 집계값으로 연결 순회 제거

- 공개→그룹 전용 전환은 전원 조회 대신 모집 Aggregate의 그룹 자격 불일치 수·pending 불일치 수를 사용한다.
- 그룹 해산은 그룹 원본의 활성 그룹 모집 수 또는 동등한 Projection을 기준으로 판정한다.
- 집계값 변경은 해당 가입·탈퇴·신청·공개범위 명령과 함께 revision으로 보호한다.

## 4. 기능별 개선안

| 기능 묶음 | 개선안 |
| --- | --- |
| 즉시 가입·승인 | 모집 구성 요약에서 빈자리와 직업 중복을 판정하고 대상 membership·slot·assignment만 쓴다. 가입 사건은 공용 이벤트 1건으로 기록한다. |
| Character 변경·자리 이동·교환 | 구성 요약의 대상 1~2칸만 revision과 함께 변경한다. membership·slot도 대상 1~2명만 갱신하고 공용 이벤트는 실제 사건 수만큼 1~2건 기록한다. |
| 탈퇴·추방·파티장 승계 | 대상과 필요 시 후임 한 명만 변경한다. 구성 요약에서 후임을 결정하고 공용 이벤트 1건을 남긴다. 기존 파티장 개인 탈퇴·자동 승계 제품 정책을 유지한다. |
| 전체 완료 | 모집·cycle·최대 8개 `raidState`를 한 Transaction에서 `completed`로 확정한다. 기존 assignment 삭제와 Claim 생성을 두 종류 문서로 나누지 않는다. |
| 완료 취소 | 완료 Snapshot과 `lastCommandId`를 검증하고 같은 최대 8개 `raidState`를 `completed → active`로 원자 복원한다. 취소 가능 시간과 다른 점유 충돌 검사는 유지한다. |
| 다음 주차 전환 | 모집·cycle과 최대 8개 `raidState`의 `cycleKey`·상태를 한 Transaction으로 전환한다. 이전·새 주차 혼합 상태를 만들지 않는다. |
| 모집 해산 | 모집 원본을 `disbanded`로 확정하고 활성 `raidState`만 최대 8건 해제한다. membership·slot·application은 즉시 삭제하지 않으며 부모 종료 상태로 기능에서 제외한다. 완료 후 마무리 해산은 `completed` `raidState`를 보존한다. |
| 그룹 전용 전환 | 그룹 자격 집계값이 0일 때만 전환하고 listing은 모집 원본의 동일 revision Projection으로 갱신한다. |
| 그룹 해산 | 활성 모집 집계가 0이고 pending 관계·초대코드 조건을 만족할 때만 종료한다. 연결 모집 최대 20개 순회를 제거한다. |
| 목록·알림 | 그룹별 개별 구독과 Player별 이벤트 복제를 공통 조회 가능한 Projection·공용 이벤트와 cursor로 대체한다. 화면용 전체 멤버 조회는 유지한다. |

## 5. 예상 버그와 필수 보완

### 동시성·중복

- 오래된 revision으로 성공하거나 서로 다른 두 명이 같은 슬롯을 차지하는 문제
- 앱 재시도에서 동일 이벤트·Claim·assignment가 중복 생성되는 문제
- 대응: 모든 명령에 `expectedRevision`, 전환 명령에 안정적인 `commandId`, 문서 ID의 결정성, 동일 명령 재실행 결과 고정

### 앱 종료·응답 유실

- Transaction 제출 전 앱 종료: 서버 변경 없음
- Transaction 커밋 후 응답 수신 전 앱 종료: 서버는 이미 전체 상태를 확정했지만 클라이언트가 성공을 기억하지 못하는 상태
- 대응: 다음 실행에서 모집 `status`, `revision`, `lastCommandId`를 읽어 결과를 자동 판정한다. 장기 `processing`, 수동 복구 버튼과 다른 참가자의 재접속을 완료 조건으로 두지 않는다.
- 핵심 명령은 오프라인 큐에 맡기지 않는다. 온라인 Transaction 실패 시 서버는 변경되지 않았음을 안내하고 현재 Snapshot을 다시 읽는다.

### 잔존 하위 문서

- 종료된 모집의 과거 membership·slot·application이 직접 조회되어 유령 참가·신청으로 보이는 문제
- 오래된 application 수만큼 해산 후처리를 다시 만들어 명령 크기가 증가하는 문제
- 대응: 모집 원본 상태 우선의 읽기 모델과 Rules, 종료 항목 자동 숨김, 본인 Projection 지연 정리. 잔존 문서는 점유·완료 판정의 근거로 사용하지 않는다.

### 완료·주간 Claim

- 완료 직후 다른 방 참가 허용, 취소 중 이중 점유, 다음 주차 assignment 혼합
- 대응: 모집 cycle 전환 상태를 참가 Rules의 우선 차단 근거로 사용하고 Claim·assignment 단계 완료 조건을 계약 테스트로 고정

### 이벤트·알림

- 탈퇴·해산 뒤 수신자가 이벤트를 못 읽거나 반대로 비수신자가 읽는 문제
- 읽음 처리 cursor가 새 이벤트를 건너뛰는 문제
- 기존 Player event와 신규 공용 event가 중복 노출되는 문제
- 대응: 이벤트 당시 audience 기반 Rules, `(occurredAt, eventId)` 정렬 cursor, dual-read 기간 또는 테스트 데이터 초기화 방침, 중복 제거 키

### 구성·자리

- 모집 Aggregate 구성 요약과 membership·slot Projection 불일치
- 딜러/서포터형 동일 직업 구분, 파티별 동일 구성 직업 제한, 빈자리·교환 판정 회귀
- 대응: 기존 `PartyCompositionPolicy`를 단일 계산기로 유지하고 Write Plan·Rules·읽기 Projection이 같은 결과를 계약 테스트로 공유

### 그룹 연결

- 그룹 탈퇴 후 그룹 전용 모집 자격 집계가 줄지 않거나 전체 공개 모집까지 잘못 차단하는 문제
- listing과 recruitment revision이 달라 그룹 목록이 오래된 상태로 보이는 문제
- 대응: 그룹 자격 변화 명령별 집계 갱신표, listing 원본 revision 일치, 공개/그룹 경계 회귀 테스트

### 과거 데이터·릴리즈 폐기

- 공개 출시본은 없으므로 사용자 데이터 마이그레이션을 기본 전제로 삼지 않는다.
- 현재 개발·테스트 데이터는 새 스키마와 섞지 않는다. 단계별 전환 때 초기화 범위 또는 최소 호환 범위를 명시적으로 결정한다.
- `release/1.0.0` 브랜치는 삭제하지 않지만 출시 후보·병합 기준에서 제외한다.

## 6. 작업 순서

1. 모든 파티·그룹 명령의 현재 읽기·쓰기·Rules 접근을 표로 고정하고 1·2·4·8인 예상량을 기록한다.
2. `raidState` 통합 계약과 완료·취소·주차 전환·해산의 8인 최악 Transaction 쓰기·Rules 접근량을 먼저 설계한다.
3. 모집 Aggregate 구성 요약, revision·`lastCommandId`와 제한 크기 명령 검증 계약을 설계한다.
4. 공용 이벤트 원본·audience·읽음 cursor 계약을 설계하고 기존 개인 event 의존 화면을 목록화한다.
5. 종료된 모집의 membership·slot·application을 읽는 모든 화면·명령을 조사하고 부모 상태 우선 및 지연 정리 계약을 확정한다.
6. 가입·승인 → Character 변경·자리 이동 → 탈퇴·승계 순으로 고정 크기 명령으로 전환한다.
7. 완료·취소·주차 전환·해산을 제한된 원자 명령으로 전환한다.
8. 그룹 자격·활성 모집 집계를 도입해 전원·연결 모집 순회를 제거한다.
9. Rules를 기능 단위로 축소하고 각 단계마다 이전 정상 흐름을 회귀 검증한다.
10. 자동 Emulator에서 1·2·4·8인, 공개·그룹, 정상·충돌·앱 종료 후 재조회·재시도를 검증한 뒤 새 릴리즈 후보를 만든다.

## 7. 완료 조건

- 일반 명령은 직접 대상 수만큼만 접근하고, 전체 명령은 현재 최대 8인 경계 안에서 단일 Transaction으로 끝난다.
- 8인 전체 완료·취소·주차 전환·활성 해산이 Rules 전체 20회·개별 쓰기 10회 접근 한도를 캐시 가정 없이 통과한다.
- 파티 1·2·4·8인 자동 테스트가 모두 존재하고 같은 결과를 보장한다.
- 앱 종료 시 핵심 상태는 전부 반영 또는 전부 미반영이며, 재실행 후 `lastCommandId`로 결과를 자동 복구한다.
- 종료 후 남은 하위 문서가 활성 목록·신청·점유·주간 완료 판정에 영향을 주지 않는다.
- 생성·신청·승인·즉시 가입·탈퇴·추방·승계·Character 변경·자리 이동·완료·취소·주차 전환·해산과 그룹 연결 흐름을 모두 회귀 확인한다.
- Rules 경고 0개, 전체 Rules 컴파일, 허가된 배포와 3개 이하 실기기의 대표 사용자 흐름을 통과한다.
- 이후에만 새 릴리즈 브랜치와 버전을 만든다.

## 8. 제외 범위

- UI 디자인 전면 개편
- Character Build·보석·아크그리드 판정 재작성
- 레이드·직업 카탈로그 변경
- 유료 서버·Cloud Functions 도입은 별도 사용자 결정 전까지 제외
