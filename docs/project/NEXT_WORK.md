# NEXT WORK



## 현재 기준과 이번 범위



- 교류 행동 기반 Character 자동 갱신 A~F를 구현했다. F는 서버 최소 Snapshot 정합성·비용 제어다.

- `CharacterMinimumDisplaySyncService`와 Firestore Gateway로 `itemAvgLevel`·`combatPower`를 값이 달라졌을 때만 갱신한다. 캐릭터별 Transaction은 기존 전투력 보강과 같이 binding·Player·Character·소유관계 4회 읽기, 변경 시 1회 쓰기다. Rules·스키마는 변경하지 않았다.

- 명령 직전(`ensureFresh`) 동기화 실패는 명령을 차단한다. prefetch 실패는 로컬 갱신을 유지하되 TTL 캐시에 넣지 않아 이후 명령 경로에서 재시도한다.

- 그룹 표시·생성·가입은 선호 역할 Snapshot을 서버 단일 `combatPower`보다 우선한다. 파티 명령은 기존처럼 선택 역할 Snapshot을 쓴다.

- F 표적 테스트 28개(조정기·서비스·Gateway·그룹 표시)와 변경 파일 analyze가 통과했다. 그룹·account 서비스 회귀 227개와 전체 `flutter test --no-pub` 875개가 통과했다.



## 다음 작업



다음은 자동 갱신 계약의 **G — 회귀·실기기 검증과 문서 종료**다.



- Domain, Mapper, 로컬 DB, Coordinator, 파티·그룹 Repository/UI 표적 테스트와 영향 범위 analyze·전체 test

- Android 실기기에서 일반/나이스단, 4개 서포터 겸용 직업, 빠른 실행, 실패·재시도 확인

- 요청 횟수와 Firestore read/write 변화 기록

- 완료 후 `DEV_LOG.md`에 실기기 결과를 남기고 `NEXT_WORK.md`를 다음 단일 작업으로 교체



나이스단·TTL·최대 동시 요청·역할 Snapshot 우선 등 확정 정책은 유지한다. 단계별 공통 실행·테스트·병합 규칙은 계약 §8을 따른다. CLASS_SYNERGY_CATALOG §11의 3~5단계와 별도 기능 전환은 범위에서 제외한다.



F 완료 브랜치를 `dev`에 병합·푸시한 뒤 최신 `dev`에서 G를 시작한다. `main`은 변경하지 않는다.


