# NEXT WORK

## 현재 기준과 이번 범위

- 신청자 목록 가벼운 표시(2단계)를 구현했다. 신청 당시 `itemLevel`·`combatPower` 읽기 모델 연결, 항상채용 주요 시너지 표시, `ClassSynergyService` 신설. 표적 21개·서비스 테스트 8개 통과, 신규 파일 analyze 문제 없음. Android 실기기 확인 완료.
- 교류 행동 기반 Character 자동 갱신의 A~D를 구현했다. 파티 후보 사전 갱신과 생성·신청·즉시 참가·참가 Character 변경 명령 직전 최신화·재검증까지 연결됐다.
- 설계와 작업 구간의 단일 기준은 [CHARACTER_INTERACTION_AUTO_REFRESH_CONTRACT.md](../architecture/CHARACTER_INTERACTION_AUTO_REFRESH_CONTRACT.md)다. 아직 기능 코드·스키마·Rules는 변경하지 않았다.
- C 표적 테스트 7개, 전체 테스트 857개와 변경 파일 analyze가 통과했다. A fixture는 실API 미실측 상태이며 반환 문자열·공백·별칭은 G 실기기 검증 전 대조한다.
- 첫 릴리즈 전에는 PR 없이 검증한 작업 브랜치를 `dev`에 직접 병합·푸시한다. `main`은 변경하지 않는다.

## 다음 작업

다음은 자동 갱신 계약의 **E — 그룹 교류 적용** 구현과 검증이다.

- 그룹 생성·신청·가입과 대표/활동 Character 변경 후보에 사전 갱신을 적용한다.
- 각 명령 직전에 선택 Character를 `ensureFresh`하고 갱신 Snapshot으로 payload와 표시값을 다시 만든다.
- 선택 변경·역할 변경·기존 Snapshot fallback·버튼 연타 방지를 그룹 테스트로 고정한다.

그 뒤 F 서버 최소 Snapshot 정합성 → G 회귀·실기기 검증 순서로 진행한다.

나이스단은 등록된 본·부계정 전체의 1700 이상 동일 직업을 합산하고, 직업군 전체가 기존 수동 Snapshot 흐름을 쓰며, 자동 갱신 허용 설정은 로컬에만 저장한다. 조건 해제 시 설정은 휴면 보존한다. 사전 갱신 TTL 5분·최대 동시 요청 3개, 기존 정상 Snapshot 무기한 사용과 마지막 저장 시각 안내도 확정했다.

E 완료 후 문서와 검증 결과를 갱신하고 `dev`에 병합한 다음에만 F를 최신 `dev`에서 시작한다. 단계별 공통 실행·테스트·병합 규칙은 계약 §8을 따른다. 기존 CLASS_SYNERGY_CATALOG §11의 3~5단계와 별도 기능 전환은 범위에서 제외한다.
