# NEXT WORK — 전투력 수집·갱신 협업 설계 준비

2026-10-14. #4 서버 빈 이름 계약 Flutter 연결은 구현·전체1193테스트/분석0·debug APK33.4초 빌드·사용자 신규 이름4흐름 인수 완료했다. 소비 계약은 d3cb697bb6ebb988b63bd99c588bc1b64a93650d이며 원본 snapshot은 contracts/issue4-d3cb697.openapi.json이다. 완료 상세는 [DEV_LOG](DEV_LOG.md), 장기 기준은 [이름 계약20](../backend-migration/20-account-auto-label-contract.md).

[사용자 결과 회신](https://github.com/heo0328/lostparty-backend/issues/4#issuecomment-6166283832) 완료. 현재 사용자 지시는 이 구간 커밋·dev 머지·push와 적용 SHA 인계다. 이름 작업 이후 새 기능 구현/Backend 요청은 다음 지시를 기다린다. #3/#4를 임의로 종료하지 않는다.

## 다음 후보의 목표와 근거

캐릭터 전체 전투력 수집·저장/갱신 → 앱 표시 연결을 설계한다. 기존 조사 e807a6f observations.py는 일반 siblings를 combat_power=None으로 매핑하고 proof 조회만 검색 캐릭터의 ArmoryProfile.CombatPower를 채운다. 서비스에는 power_fetched_at/power_stale과 이전 값 유지가 있다. 최신 Backend 상태를 착수 시 다시 대조한다.

Flutter 서버 캐릭터 화면은 combat_power 표시 UI가 있고 로컬 내 계정은 별도 SQL·API 데이터를 사용한다. 로컬 sibling DTO에는 전투력이 없고 검색 캐릭터 프로필 조회/역할별 빌드 전투력은 별도 흐름이다. 서버 값 제공만으로 로컬 카드까지 연결됐다고 가정하지 않는다.

## 설계 순서·완료 기준 후보

1. 최신 Issue와 기존 전투력 API/캐시·실행 버전을 확인해 미처리 인계가 있으면 우선 처리한다.
2. 서버 캐릭터 화면/로컬 카드에서 사용할 값과 갱신 경로를 구분한다. 조회량·캐시 수명·부분 실패·역할별 빌드 관계를 현재 제품 요구에 맞춰 정한다.
3. 기존 API로 가능한지 먼저 판단하고 Backend에 필요한 수집/저장/응답 보완만 협업 내역으로 산출한다. 동일 기능의 endpoint·DB를 중복 요청하지 않는다.
4. 확정 계약 인계 후 Flutter 연결/직접 영향 경계 검증과 필요한 사용자 확인만 수행한다. 결과와 미확인은 관련 Issue에 회신한다.

완료 기준 후보: 신규 등록/정보 갱신 이후 실제 전투력 표시, 값 없음/조회 실패·최근 확인 필요 상태 구분, 전투력을0이나 조회 성공으로 위장하지 않음, 기존 이름/등록·로그인·재로그인·갱신 흐름 유지.

제외: 기존 사용자/테스터 데이터 이관, 전체 빌드JSON 서버 저장, 장비 인증·소유권 이전·활동/대표 구현, 모집/파티/그룹, 원격 데이터 초기화·운영 배포·기기 자동 조작. 이 항목들은 별도 구간이다.

## Git·대기 상태

기존 feature/account-backend-registration의 승인된 코드·테스트·관련 문서만 커밋하고 최신 origin/dev에 일반 merge·push한다. 사용자 인수 이후 코드 변화가 없어 최종 검증을 재사용한다. 기존 실험/백업36개는 제외하고 그대로 유지한다. 통합 후 dev/origin/dev 일치와 추적 파일 변경 없음을 확인하고 적용 SHA를 Backend #4에 회신한다. 작업 브랜치는 유지/삭제 후보이며 main은 변경하지 않는다.
