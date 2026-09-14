# NEXT WORK — 파티·그룹 명령 확장성 재설계 1단계

## 현재 상태

- 기존 `release/1.0.0` 후보는 폐기했다. 브랜치는 이력용으로 보존하되 출시·`main` 병합 기준으로 사용하지 않는다.
- 최신 앱과 운영 Rules에서도 다인 모집 해산이 `permission-denied`로 실패했다.
- 해산 버튼을 숨기는 임시 UI 변경은 철회했고 기존 화면을 복원했다. 해산 한 곳을 다시 보정하지 않고 인원수에 비례해 커지는 파티·그룹 명령 전체를 재설계한다.
- 장기 설계와 영향·회귀 목록은 [`../architecture/PARTY_GROUP_COMMAND_SCALABILITY_REDESIGN.md`](../architecture/PARTY_GROUP_COMMAND_SCALABILITY_REDESIGN.md)를 기준으로 한다.
- `feature/party-group-command-redesign`에서 운영 Rules와 분리된 8인 접근 예산 증명 Rules·Emulator 시나리오를 작성했다. 정적 계약 테스트 5건은 통과했다. Android Studio 번들 JBR 21로 Emulator 기동은 확인했지만, 이 PC에서는 최소 deny-all Rules와 단순 REST 쓰기도 동일한 `503 Network closed for unknown reason`으로 끊겨 실제 Rules 허용·거절 게이트는 아직 미통과다.

## 이번 작업 목표

구현 전에 각 명령의 실제 Firestore 읽기·쓰기와 Rules `get/exists/getAfter` 의존을 수치화하고, 최대 8인 제한 원자 명령·통합 `raidState`·공용 이벤트와 모집 Aggregate 계약을 확정한다.

## 포함 범위

1. 파티 생성·신청·가입·승인·탈퇴·추방·승계·Character 변경·자리 이동·완료·취소·주차 전환·해산의 접근량 표 작성
2. 그룹 생성·가입·탈퇴·그룹장 이전·해산·그룹 전용 모집 연결의 접근량 표 작성
3. 1·2·4·8인별 쓰기 수와 Rules 접근 한도 위험 구간 분류
4. 파티·그룹 공용 이벤트 원본, audience와 개인 읽음 cursor 계약 확정
5. 모집 Aggregate 구성 요약과 `expectedRevision`·`lastCommandId` 기반 명령 계약 확정
6. assignment·주간 Claim을 대체할 통합 `raidState`와 8인 완료·취소·전환·해산 원자 명령 계약 확정
7. 앱 종료·응답 유실 후 서버 결과 자동 판정과 종료된 membership·slot·application 지연 정리 계약 확정
8. 확정된 개인 event·개발 테스트 데이터 초기화 범위와 무호환 전환 계약 기록

## 제외 범위

- 이번 1단계에서 Repository·Rules·Firestore 스키마 구현
- 기존 `release/1.0.0`, `dev`, `main` 병합·이동·배포
- 해산 기능만을 위한 추가 임시 Rules 또는 UI 우회
- Cloud Functions·유료 서버 도입

## 현재 브랜치와 구현 착수 게이트

- 2026-09-14 현재 통합 기준 `dev`와 `origin/dev`는 `aab6b41`로 일치한다.
- 현재 설계 브랜치는 최신 `dev`에서 분기한 `docs/party-group-command-redesign`이다. 이 브랜치에서는 접근량 감사와 계약 문서만 다루며 Repository·Rules를 수정하지 않는다.
- `main`과 폐기된 `release/1.0.0`은 현재 구조개선에 병합하지 않는다.
- 현재 문서 변경을 검토·커밋하기 전에는 Repository·스키마·Rules 구현을 시작하지 않는다.
- 문서 설계가 승인되면 `feature/party-group-command-redesign`을 최신 `dev`에서 분기한다. 부분 스키마 전환은 `dev`에 병합하지 않고, 기능 브랜치에서 전체 읽기·쓰기·Rules·Router 전환과 초기화 절차를 검증한 뒤 한 번에 통합한다.
- 설계 문서는 로컬 `dev`에 통합됐고 구조개선 기능 브랜치를 시작했다. 다만 첫 Rules 엔진 검증 전에는 운영 Repository·Rules·Router/DI 전환을 시작하지 않는다.

## 확정 결정

- 계정·캐릭터 인증 자료는 보존하고 기존 파티·그룹 거래성 테스트 자료는 새 스키마 전환 때 초기화한다. 구·신 스키마 호환 계층은 만들지 않는다.
- 해산 pending 신청자별 서버 이벤트는 만들지 않는다. 모집 원본 종료 확인으로 숨기고 로컬 1회 안내를 표시한다.
- 종료 하위 문서는 첫 출시에서 자동 정리하지 않으며 활성 판정에서만 완전히 제외한다.
- 완료·취소·주차 전환·해산은 온라인 전용 원자 명령이고 오프라인 큐를 사용하지 않는다.

## 회귀 보호 목록

- 모집 생성, 신청·철회·거절·승인·즉시 가입
- 파티장 탈퇴와 가입 순서 기반 후임 승계
- 일반 탈퇴·추방 후 재신청
- 파티별 동일 구성 직업 제한과 딜러/서포터형 구분
- 빈자리 이동·점유 자리 교환·중복 직업 안내
- 주간 완료 체크, 완료 취소, 반복방 수요일 06시 전환
- 공개·그룹 전용 목록과 그룹 자격 상실 정리
- 그룹 생성·가입·탈퇴·그룹장 이전·마지막 1인 해산
- 보석·아크그리드 통합 오류 Snapshot 표시

## 작업 순서

1. 현재 명령·Rules 접근량을 코드 근거와 함께 표로 작성한다.
2. 위험 구간을 개인 event fan-out, 전체 membership 재조회, 전원 Projection 동시 갱신, 연결 문서 순회로 묶는다.
3. 8인 원자 명령, 통합 `raidState`, 모집 Aggregate와 `lastCommandId` 계약 초안을 작성한다.
4. 공용 이벤트의 audience 조회·Rules 조건과 종료 하위 문서의 읽기 차단·지연 정리 계약을 작성한다.
5. 기능별 전환 순서와 자동·실기기 검증표를 확정한다.
6. 문서 승인 후 단일 구조개선 기능 브랜치에서 Rules 예산 증명부터 시작하고, 전체 전환 전에는 `dev`에 부분 병합하지 않는다.

현재 실행 위치는 6번의 첫 Rules 예산 증명이다. 운영 프로젝트가 아닌 정상 동작하는 격리 Emulator 환경에서 다음을 실행해 1·2·4·8인 성공과 누락 대상·stale revision·비권한 actor 거절을 모두 확인해야 다음 구현으로 이동한다. 현재 Windows 호스트에서는 JBR 21로 Emulator가 시작되지만 Firestore 쓰기 전송이 503으로 끊긴다. Docker는 설치되어 있지 않고 WSL 배포판도 없으므로 동일 호스트 재시도는 검증으로 인정하지 않는다.

이를 대체하기 위해 `party-scalability-proof.yml`을 기능 브랜치의 관련 증명 파일 push와 수동 실행에만 연결한다. Ubuntu·JDK 21·demo 프로젝트 Emulator와 전용 설정·Rules만 사용하며 운영 Firebase 인증·배포는 수행하지 않는다. 이 실행이 모두 통과해야 운영 구조 구현으로 이동한다.

```powershell
firebase emulators:exec --only firestore --project demo-party-scalability "node tools/party_scalability_rules_test.mjs"
```

## 완료 조건

- 모든 파티·그룹 명령이 고정 크기·인원 비례·연결 수 비례 중 하나로 분류된다.
- 1·2·4·8인에서 위험한 명령과 그 원인이 누락 없이 기록된다.
- 공용 이벤트, 구성 Aggregate, revision, 통합 `raidState`, 8인 원자 명령과 앱 종료 후 결과 판정 계약이 구현 가능한 수준으로 확정된다.
- 비핵심 하위 문서 정리 실패가 사용자 흐름과 데이터 정확성을 막지 않는다는 것이 읽기·Rules 계약으로 증명된다.
- 각 구현 단계의 영향 기능과 자동·실기기 검증 범위가 정해진다.
- 코드 구현 없이 문서 검토 상태로 사용자 승인을 받는다.
