# NEXT WORK

## 현재 기준과 이번 범위

- 신청자 목록 가벼운 표시(2단계)를 구현했다. 신청 당시 `itemLevel`·`combatPower` 읽기 모델 연결, 항상채용 주요 시너지 표시, `ClassSynergyService` 신설. 표적 21개·서비스 테스트 8개 통과, 신규 파일 analyze 문제 없음. Android 실기기 확인 완료.
- 큰 구조 변경의 다음 방향은 교류 행동 기반 Character 자동 갱신으로 정리했다. 일반 Character는 그룹·파티 후보 화면에서 사전 갱신하고 명령 직전에 최신화를 보장하며, 나이스단은 기존 수동 Snapshot을 유지한다.
- 설계와 작업 구간의 단일 기준은 [CHARACTER_INTERACTION_AUTO_REFRESH_CONTRACT.md](../architecture/CHARACTER_INTERACTION_AUTO_REFRESH_CONTRACT.md)다. 아직 기능 코드·스키마·Rules는 변경하지 않았다.
- 첫 릴리즈 전에는 PR 없이 검증한 작업 브랜치를 `dev`에 직접 병합·푸시한다. `main`은 변경하지 않는다.

## 다음 작업

다음은 자동 갱신 계약의 **A — 계약·실데이터·카탈로그 기반** 구현과 검증이다.

- 사용자 제공 기준을 바탕으로 바드·홀리나이트·발키리·도화가의 support/dealer 실제 Armory fixture와 1·4티어 노드 반환 문자열을 대조한다.
- ArmorySkills에 직접 나오지 않는 아이덴티티·아크패시브 보석 대상명과 별칭을 확인한다.
- 기존 바드 전용 Build 판별 카탈로그를 네 직업으로 확장하고 Mapper/Validator·Build 분석 표적 테스트를 통과시킨다.

그 뒤 B 나이스단 정책 → C 공통 자동 갱신 조정기 → D 파티 적용 → E 그룹 적용 → F 서버 최소 Snapshot 정합성 → G 회귀·실기기 검증 순서로 진행한다.

나이스단은 등록된 본·부계정 전체의 1700 이상 동일 직업을 합산하고, 직업군 전체가 기존 수동 Snapshot 흐름을 쓰며, 자동 갱신 허용 설정은 로컬에만 저장한다. 조건 해제 시 설정은 휴면 보존한다. 사전 갱신 TTL 5분·최대 동시 요청 3개, 기존 정상 Snapshot 무기한 사용과 마지막 저장 시각 안내도 확정했다.

A 완료 후 문서와 검증 결과를 갱신하고 `dev`에 병합한 다음에만 B를 최신 `dev`에서 시작한다. 단계별 공통 실행·테스트·병합 규칙은 계약 §8을 따른다. 현재 A 착수를 막는 제품 구조 미결정은 없으며, 기존 CLASS_SYNERGY_CATALOG §11의 3~5단계와 별도 기능 전환은 범위에서 제외한다.
