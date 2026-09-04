# NEXT WORK

## 현재 기준과 이번 범위

- 신청자 목록 가벼운 표시(2단계)를 구현했다. 신청 당시 `itemLevel`·`combatPower` 읽기 모델 연결, 항상채용 주요 시너지 표시, `ClassSynergyService` 신설. 표적 21개·서비스 테스트 8개 통과, 신규 파일 analyze 문제 없음. Android 실기기 확인 완료.
- 교류 행동 기반 Character 자동 갱신의 A 카탈로그, B 나이스단 정책, C 공통 조정기를 구현했다. 5분 TTL·최대 동시 3개·single-flight·명령 우선순위·generation·정상 Snapshot fallback 계약이 자동 테스트로 고정됐다.
- 설계와 작업 구간의 단일 기준은 [CHARACTER_INTERACTION_AUTO_REFRESH_CONTRACT.md](../architecture/CHARACTER_INTERACTION_AUTO_REFRESH_CONTRACT.md)다. 아직 기능 코드·스키마·Rules는 변경하지 않았다.
- C 표적 테스트 7개, 전체 테스트 857개와 변경 파일 analyze가 통과했다. A fixture는 실API 미실측 상태이며 반환 문자열·공백·별칭은 G 실기기 검증 전 대조한다.
- 첫 릴리즈 전에는 PR 없이 검증한 작업 브랜치를 `dev`에 직접 병합·푸시한다. `main`은 변경하지 않는다.

## 다음 작업

다음은 자동 갱신 계약의 **D — 파티 교류 적용** 구현과 검증이다.

- 모집 생성 Character 후보 진입 시 사전 갱신하고 생성 직전 선택 Character에 `ensureFresh`를 적용한다.
- 참가 신청·즉시 참가 후보와 실행, 참가 Character 변경, 반복 파티 다음 회차 Character 변경에 같은 경계를 적용한다.
- 갱신 완료 Snapshot으로 최소 조건과 요청 역할을 다시 검증하고 명령 payload를 새로 만든다.
- 빠른 실행·버튼 연타·선택 변경·역할 변경·기존 Snapshot fallback 확인 흐름을 Widget/Repository 테스트로 고정한다.

그 뒤 E 그룹 적용 → F 서버 최소 Snapshot 정합성 → G 회귀·실기기 검증 순서로 진행한다.

나이스단은 등록된 본·부계정 전체의 1700 이상 동일 직업을 합산하고, 직업군 전체가 기존 수동 Snapshot 흐름을 쓰며, 자동 갱신 허용 설정은 로컬에만 저장한다. 조건 해제 시 설정은 휴면 보존한다. 사전 갱신 TTL 5분·최대 동시 요청 3개, 기존 정상 Snapshot 무기한 사용과 마지막 저장 시각 안내도 확정했다.

D 완료 후 문서와 검증 결과를 갱신하고 `dev`에 병합한 다음에만 E를 최신 `dev`에서 시작한다. 단계별 공통 실행·테스트·병합 규칙은 계약 §8을 따른다. 기존 CLASS_SYNERGY_CATALOG §11의 3~5단계와 별도 기능 전환은 범위에서 제외한다.
