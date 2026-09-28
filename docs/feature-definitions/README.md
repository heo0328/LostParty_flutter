# LOSTPARTY 기능 정의 문서

이 폴더는 개별 Repository·Rules 구현보다 사용자가 앱에서 경험하는 기능의 전체 흐름과 기능 간 연결을 정리한다.

- 인증, 레이드, 그룹처럼 여러 기능 영역을 하나의 사용자 흐름으로 연결한 문서
- 화면 분기, 사용자 행동, 주요 식별자와 데이터 책임을 함께 설명하는 문서
- 외부 도식화나 제품 흐름 검토의 기준이 되는 상위 문서

세부 데이터 구조와 Transaction·Security Rules 계약은 `../architecture`, 장기 제품 정책은 `../product`, 현재 작업 상태와 이력은 `../project`의 문서를 따른다. 이 폴더는 해당 세부 계약을 복제하거나 대체하지 않는다.

## 문서 목록

- [`LOSTPARTY_CORE_USER_FLOW_OVERVIEW.md`](LOSTPARTY_CORE_USER_FLOW_OVERVIEW.md): 게임 계정·원정대 인증부터 일반 레이드, 그룹과 그룹 전용방까지 이어지는 핵심 사용자 흐름 통합 지도
