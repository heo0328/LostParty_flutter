# NEXT WORK

## 현재 기준과 이번 범위

- 신청자 목록 가벼운 표시(2단계)를 구현했다. 신청 당시 `itemLevel`·`combatPower` 읽기 모델 연결, 항상채용 주요 시너지 표시, `ClassSynergyService` 신설. 표적 21개·서비스 테스트 8개 통과, 신규 파일 analyze 문제 없음. Android 실기기 확인 완료.
- 교류 행동 기반 Character 자동 갱신의 A~E를 구현했다. 파티와 그룹의 본인 후보 사전 갱신, 명령 직전 최신화·재검증, 그룹 상세 본인 표시 Snapshot 보강까지 연결됐다.
- 설계와 작업 구간의 단일 기준은 [CHARACTER_INTERACTION_AUTO_REFRESH_CONTRACT.md](../architecture/CHARACTER_INTERACTION_AUTO_REFRESH_CONTRACT.md)다. 아직 기능 코드·스키마·Rules는 변경하지 않았다.
- C 표적 테스트 7개, 전체 테스트 857개와 변경 파일 analyze가 통과했다. A fixture는 실API 미실측 상태이며 반환 문자열·공백·별칭은 G 실기기 검증 전 대조한다.
- 첫 릴리즈 전에는 PR 없이 검증한 작업 브랜치를 `dev`에 직접 병합·푸시한다. `main`은 변경하지 않는다.

## 다음 작업

다음은 자동 갱신 계약의 **F — 서버 최소 Snapshot 정합성·비용 제어** 구현과 검증이다.

- 실제 값이 달라졌을 때만 Firestore Character 최소 표시 필드를 갱신한다.
- 파티는 선택 역할 Snapshot, 그룹은 선호 역할 Snapshot을 우선하고 서버 단일 전투력은 참고값으로 유지한다.
- 서버 최소값 동기화가 필요한 명령은 동기화 성공 뒤 실행하며 실패하면 명령을 차단한다.
- 기존 Rules·Transaction 허용 범위와 read/write 비용을 검증한다.

그 뒤 G 회귀·실기기 검증 순서로 진행한다.

나이스단은 등록된 본·부계정 전체의 1700 이상 동일 직업을 합산하고, 직업군 전체가 기존 수동 Snapshot 흐름을 쓰며, 자동 갱신 허용 설정은 로컬에만 저장한다. 조건 해제 시 설정은 휴면 보존한다. 사전 갱신 TTL 5분·최대 동시 요청 3개, 기존 정상 Snapshot 무기한 사용과 마지막 저장 시각 안내도 확정했다.

F 완료 후 문서와 검증 결과를 갱신하고 `dev`에 병합한 다음에만 G를 최신 `dev`에서 시작한다. 단계별 공통 실행·테스트·병합 규칙은 계약 §8을 따른다. 기존 CLASS_SYNERGY_CATALOG §11의 3~5단계와 별도 기능 전환은 범위에서 제외한다.
