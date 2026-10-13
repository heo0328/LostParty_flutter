# 기존 서비스 발췌 — docs/architecture/GROUP_LEADER_EXIT_DISBAND_CONTRACT.md

원본 문서: docs/architecture/GROUP_LEADER_EXIT_DISBAND_CONTRACT.md ([현재 문서](../../../../../docs/architecture/GROUP_LEADER_EXIT_DISBAND_CONTRACT.md)). 분리일: 2026-10-13.
원본 전체 SHA256: debd25ea9054d1e7808efd6e937cacbc4e6eca6b22ec1f35a1a9231a60a0b5f8.
아래는 기존 Firebase 환경의 원문이다. 신규 서버의 실행 지시/배포 승인으로 사용하지 않는다. 행 범위는 분리 직전이며 링크 위치만 조정한다.

<a id="source-0001"></a>

## 발췌 1: ## 1. 상태와 목적

출처: docs/architecture/GROUP_LEADER_EXIT_DISBAND_CONTRACT.md · 원본 5~5행 · 원문 절: ## 1. 상태와 목적.

- 상태: 실기기 확인됨. 브랜치 `codex/group-leader-exit`. 커밋 `e7ce461`. 관련 Rules는 사용자가 배포했다.

<a id="source-0002"></a>

## 발췌 2: ## 1. 상태와 목적

출처: docs/architecture/GROUP_LEADER_EXIT_DISBAND_CONTRACT.md · 원본 7~7행 · 원문 절: ## 1. 상태와 목적.

- 실행 환경: Firebase Spark, Flutter 클라이언트 Transaction, Firestore Security Rules

<a id="source-0003"></a>

## 발췌 3: ## 4. 이전 Transaction

출처: docs/architecture/GROUP_LEADER_EXIT_DISBAND_CONTRACT.md · 원본 35~56행 · 원문 절: ## 4. 이전 Transaction.

## 4. 이전 Transaction

### 읽기와 검증

- `groups/{groupId}`가 `active`인지 확인
- 호출자가 현재 `leaderPlayerId`인지 확인
- 호출자의 membership이 `leader`인지 확인
- 대상 membership이 같은 그룹의 유효한 `member`인지 확인
- 대상이 호출자와 다른지 확인
- 명령의 `expectedGroupRevision`과 현재 group revision이 같은지 확인

### 원자적 쓰기

- 그룹 `leaderPlayerId`를 대상 Player로 변경
- 그룹 `leaderDisplayCharacterNameSnapshot`을 대상 membership Snapshot으로 변경
- 대상 membership의 `role`을 `leader`로 변경하고 revision 증가
- 기존 그룹장 membership의 `role`을 `member`로 변경하고 revision 증가
- 그룹 `revision`을 정확히 1 증가
- `updatedAt`, `lastActivityAt`을 `request.time`으로 갱신

하나라도 실패하면 전체 이전을 거절한다. 대상이 선택 후 먼저 탈퇴했거나 역할·revision이 바뀌면 최신 목록을 다시 읽도록 안내한다. 요청 진행 중에는 중복 터치를 막는다.


<a id="source-0004"></a>

## 발췌 4: ## 7. 1차 그룹 해산 허용 조건

출처: docs/architecture/GROUP_LEADER_EXIT_DISBAND_CONTRACT.md · 원본 74~74행 · 원문 절: ## 7. 1차 그룹 해산 허용 조건.

클라이언트 Transaction과 Rules만으로 최대 50명의 membership·Projection을 안전하게 일괄 정리하지 않는다. 1차 해산은 다음을 모두 만족할 때만 허용한다.

<a id="source-0005"></a>

## 발췌 5: ## 9. 해산 Transaction과 보관

출처: docs/architecture/GROUP_LEADER_EXIT_DISBAND_CONTRACT.md · 원본 95~113행 · 원문 절: ## 9. 해산 Transaction과 보관.

## 9. 해산 Transaction과 보관

해산 Transaction은 다음을 함께 처리한다.

- group status를 `softDeleted`로 변경
- `deletedAt`, `updatedAt`, `lastActivityAt`을 `request.time`으로 기록하고 revision 증가
- 마지막 그룹장 membership 삭제
- `players/{leaderPlayerId}/groupRelations/{groupId}` 삭제
- `groupMembershipState/current`에서 groupId 하나 제거하고 count·revision 갱신
- 활성 초대코드가 있다면 코드 문서 삭제 및 그룹 코드 상태 정리

해산된 그룹은 즉시 목록·검색·가입·초대·필터 대상에서 제외한다.

- 그룹 Current State는 soft delete 후 최소 28일 보관한다.
- 완료된 초대·신청·이전 및 그룹 활동 이력은 `expireAt` 기준 3개월 보관한다.
- 활성 전체 공개 레이드가 groupId를 참조하면 그룹 물리 삭제를 보류한다.
- 28일 이후에도 연결 관계나 보관 대상이 있으면 운영자 정리 화면에 차단 사유를 표시한다.
- 예약 서버가 없으므로 물리 삭제는 운영자 수동 정리 대상으로 둔다.


<a id="source-0006"></a>

## 발췌 6: ## 10. Rules와 자동 검증 완료 조건

출처: docs/architecture/GROUP_LEADER_EXIT_DISBAND_CONTRACT.md · 원본 114~128행 · 원문 절: ## 10. Rules와 자동 검증 완료 조건.

## 10. Rules와 자동 검증 완료 조건

- 타인·일반 멤버의 이전 및 해산 거절
- 본인 지정, 비멤버, 탈퇴한 멤버, 현재 그룹장 지정 거절
- 정상 이전 시 group과 두 membership 역할이 함께 변경됨
- revision 충돌과 동시 이전 중 하나만 성공
- 이전 후 기존 그룹장의 일반 탈퇴 성공
- 이전 성공·탈퇴 실패 시 두 명 membership과 새 그룹장 상태 유지
- 멤버 1명 초과, pending 관계, 활성 그룹 전용 레이드가 있는 해산 거절
- 정상 해산 시 group soft delete와 마지막 membership·Player Projection 정리가 함께 반영됨
- softDeleted 그룹의 목록·검색·가입·필터 제외
- 허용되지 않은 필드 추가·삭제와 부분 쓰기 거절

Rules Emulator의 정상·거절·경쟁 조건, 표적 단위·Repository·Widget 테스트와 실기기 2인 이전·탈퇴 흐름을 확인해야 완료다.
