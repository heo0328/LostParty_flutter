# 캐릭터 전투력 수집·갱신 Backend 협업 요청

2026-10-14. Flutter heo0328/LostParty_flutter에서 요청합니다. 기존 #3 계정/캐릭터 API, #4 등록관리/빈 이름 연결 결과를 재사용하는 다음 단일 구현 구간입니다. 사용자 지시로 계약 검토·확정과 필요한 Backend 구현을 요청합니다. 아래 경로/상한/TTL은 제안이며 정확한 wire와 정책은 Backend가 기존 구조에 맞춰 확정해 인계해 주세요.

## 목적과 확인 근거

사용자가 캐릭터 카드에서 전투력이 표시되지 않는 문제를 확인했습니다. Flutter dev266a7e2(이름 구현5fe636e), Backend dev78a5494a74a2f4a52166aee0bf81ef002866dd2e 기준 조사입니다.

- observations.roster는 일반 siblings 요약에 combat_power=None을 넣습니다. proof=True의 장비 인증 조회만 검색 캐릭터 ArmoryProfile.CombatPower를 읽습니다.
- service의 canonical Character에는 power_fetched_at/기존 수치 유지가 있지만 미인증 preview 캐릭터 응답은 power_stale=true/power_fetched_at=None입니다. 기존 등록·정보갱신은 전체 전투력 수집이 아닙니다.
- 기존 서버 키/provider transport·수치 parser와 캐시/lease를 재사용할 수 있습니다. 현재 transport 동시성2, timeout(3,5), summary cache30분 및 provider quota 경로를 확인했습니다. 새 전투력 호출이 그 제한을 우회하지 않아야 합니다.
- Flutter 서버 캐릭터 화면에 nullable combat_power 표시가 있습니다. 메인 내 계정 로컬 카드는 별도 DB/API이고 sibling DTO에는 전투력이 없습니다. 서버 제공과 로컬 표시 연결을 별도로 수행해야 합니다.

## 요청 범위

1. **장비 인증과 분리된 프로필 전투력 조회**: 서버가 직접 캐릭터 프로필에서 전투력을 수집합니다. 서버명+캐릭터명 응답 일치, 숫자 문자열 정규화(쉼표 포함)·유한값/음수 거절을 기존 parser로 처리합니다. 요청에서 임의 combat_power나 profile JSON을 받지 않습니다. 장비 해제/소유 인증을 전투력 조회의 선행 조건으로 두지 않습니다.
2. **미인증/인증 등록 양쪽 캐시**: 로그인한 회원이 등록한 원정대의 캐릭터는 character_id가 null이어도 표시용 전투력을 조회할 수 있어야 합니다. 미인증 등록에 canonical 계정/캐릭터나 소유/활동 권한을 만들어 주지 않습니다. canonical Character와 미인증 preview 모두 GET에서 최신 캐시·확인 시각·최근 확인 필요 상태를 받을 수 있게 연결합니다. 기존 값/시각이 summary 갱신만으로 지워지거나 새 값으로 위장되지 않아야 합니다.
3. **필요 대상의 작은 묶음 갱신**: 원정대 최대200명을 한 HTTP 요청에서 모두 외부 호출하지 않습니다. Flutter가 현재 표시하려는 캐릭터부터 작은 묶음으로 요청하고 필요한 전체 캐릭터까지 순차 확장할 수 있게 합니다. 일반 GET은 저장/캐시 결과만 반환합니다. 중복 대상 제거·캐시 재사용·동시 호출/전체 호출량/timeout 제한은 기존 경계 안에서 처리합니다. 별도 작업 큐·스케줄러·자동 polling은 요구하지 않습니다.
4. **실패와 부분 성공**: 성공한 캐릭터는 반영하고 실패한 대상은 이전 값과 그 시각을 유지해 오래된 상태로 표시합니다. 최초 값 없음은 null입니다. 실제 응답의0은 허용하지만 실패를0으로 바꾸지 않습니다. 정상 응답의 CombatPower 미제공과 provider 실패, 오래된 값 재사용을 구분하는 최소 결과를 인계해 주세요. 등록/summary 성공을 전투력 전체 성공으로 표시하지 않습니다. 값/시각/stale/실패 상태의 정확한 의미는 계약에 명시해 주세요.

## API 계약 제안

기존 GET /v1/me/game-accounts/{registration_id}/characters의 combat_power/power_fetched_at/power_stale을 우선 재사용합니다. summary와 power의 조회 시각은 구분합니다. 동일 최신 전투력 캐시를 representative_summary에 사용할 수 있다면 별도 profile 재호출 없이 반환합니다.

기존 refresh 확장으로 요청 대상/부분 성공을 명확히 표현하기 어렵다면, 예를 들어 POST /v1/me/game-accounts/{registration_id}/combat-power/refresh 한 개를 제안합니다. 입력은 characters:[{server_name,character_name}]의 작은 목록이며 초기 상한6명·캐시30분을 제안합니다. character_id 필수 입력은 미인증을 막으므로 피합니다. 서버가 해당 회원 등록의 현재 roster 포함 여부를 확인하고 범위 밖/소유권 상실의 표시용 조회 허용 여부를 기존 정책에 맞춰 명시합니다. client user_id/owner_id는 받지 않습니다.

출력은 각 대상의 식별키·수치/확인시각/stale 및 성공/미제공/실패의 최소 상태입니다. 실제 캐릭터 전체 정보나 raw profile 저장은 필요 없습니다. 인증·오류·Retry-After/멱등 replay·동일 key/body는 기존 transport 정책과 일관되게 하고, 최신 등록 version/roster 변경 중 결과 반영 규칙을 명시해 주세요. 삭제/회원 변경/재시도 중 캐시 적용만으로 소유권·설정 revision을 변경하지 않습니다. 기존 쓰기 계약254cb5d/d3cb697과 경로의 기본 동작은 유지합니다.

새 칼럼/테이블/API는 필요한 최소만 선택해 주세요. 이 제안을 구현 전 간단히 검토하고 정확한 요청/응답·캐시/상한·실패 의미를 Issue에서 확정한 뒤 구현해 인계해 주세요. 불필요한 새 기능이나 동작마다 승인 단계를 추가하지 않습니다.

## Flutter 대응과 완료 조건

Backend 계약 인계 후 Flutter는 서버 캐릭터 화면의 요청/결과를 연결하고, 로그인한 현재 회원의 등록 캐릭터 캐시를 서버명+캐릭터명으로 정확히 매칭해 내 계정 로컬 카드 표시에도 연결할 계획입니다. 표시 매칭은 소유 인증이나 ID 자동 이전이 아닙니다. 서버 전투력은 현재 프로필 관찰값이고 사용자가 선택한 dealer/support 로컬 빌드 Snapshot을 덮어쓰지 않습니다. 선호 역할 Snapshot이 있는 카드는 기존 역할별 표시를 우선하고, 서버 값의 적용 대상/표시 상태를 Flutter 설계에 기록합니다. 회원/로그아웃 시 서버 표시 캐시는 격리합니다. 비로그인·서버 미등록 로컬 캐릭터는 기존 로컬 흐름을 유지합니다.

완료 조건:
- 장비 인증 없이 등록한 캐릭터와 인증 캐릭터 모두 실제 제공 전투력이 GET에 표시됨.
- 캐시 재사용/수동 대상 갱신과 partial 실패에서 값·시각·상태가 맞고 범위 밖 대상은 거절됨.
- 등록·빈이름·본부전환·로그인/재로그인·로컬 역할별 빌드에 회귀가 없음.
- 캐시 hit·미인증 ID없음·잘못된값/응답 식별불일치·부분실패·중복/상한/범위 밖·동일요청 재전송 등 직접 영향 경계만 검증. 이미 통과한 이름/등록 테스트를 불필요하게 반복하지 않음.
- 구현/push·소비 원본 OpenAPI SHA, 정확한 필드·오류·상한/TTL·실행방법과 자동/실provider 미검증을 구분해 회신. 실앱 인수는 Flutter 연결 뒤 사용자에게 필요한 항목을 한 번에 안내.

## 제외

기존 사용자/테스터 데이터 이관·복구, 전체 빌드JSON 서버 저장/역할 분석, 장비 인증·소유권 이전/활동·대표 쓰기, 모집/파티/그룹·별도 job queue, DB초기화·운영배포·기기 자동조작. 토큰/실캐릭터명/민감 raw 응답은 Issue에 올리지 않습니다. 이번은 서버 조회·전투력 캐시 및 계약 보완 요청이며 Flutter 기능 구현은 계약 인계 후입니다.

## Issue5 계약 검토 회신 (2026-10-14)

[Backend검토6166675659](https://github.com/heo0328/lostparty-backend/issues/5#issuecomment-6166675659): 기본1700이상·입력20명·처리예산20초·TTL30분·동시2/quota80·부분결과6상태/고정reason·미인증캐시·GEToverlay 제안. 공통상수/parser대상22통과는Backend보고이며REST/cache/실profile미구현·미검증/새SHA없음.

[Flutter회신6166739099](https://github.com/heo0328/lostparty-backend/issues/5#issuecomment-6166739099) 게시·본문일치확인. 기존CharacterUsageLevelPolicy.minimumItemLevel=1700 재사용, 초기6제안→20입력/20초예산소비가능. 현재Dio receiveTimeout10초라전투력요청에만30초를설계하고서버예산대기/진행호출포함상한을확정받는다. deferred는명시다음묶음/새key,유실·진행중은동일key/body복구,자동polling없음. 정확한GET/POST상태필드·reason/시각·충돌오류/nullable·원본OpenAPI/구현SHA/push인계대기. Flutter기능코드변경없음.

## Backend 구현 보고 확인·게시 인계 대기

[구현보고6166983632](https://github.com/heo0328/lostparty-backend/issues/5#issuecomment-6166983632): POST전투력refresh/200items·GET필수power_checked_at(nullable)/power_status/power_reason(nullable)·회원별캐시0003/TTL30분·실패10초억제·20초예산/30초클라이언트방향 구현·로컬적용완료보고. 대상42개와후속3개는별도실행,실profile/앱미인수. 새코드/OpenAPI미커밋·미push/새SHA없음.

[Flutter확인6167001322](https://github.com/heo0328/lostparty-backend/issues/5#issuecomment-6167001322) 게시·재조회일치. 새GET3필드가현재StrictDTO에영향있음을확인했고실제게시SHA·원본계약후연결한다. 이전d3cb697/기반78a5494를새계약SHA로사용하지않는다. 사용자추가결정/Backend재테스트요청없음,게시승인은Backend사용자흐름을따른다. Flutter기능코드는아직변경없음.
