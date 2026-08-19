# LOST ARK Open API 사용 설계

## 1. 문서 목적
LOSTPARTY에서 Lost Ark Open API를 사용하기 위한 1차 설계 문서다.
현재까지 공식 API 문서와 실제 캐릭터 조회 결과로 확인한 내용, 그리고 프로젝트에서 사용할 조회/저장/갱신 정책을 정리한다.
상세 응답의 모든 필드를 미리 모델링하지 않고, 실제 화면에서 필요한 데이터가 확정되면 필요한 필드만 추가 분석 및 모델링한다.

## 2. API 인증
Lost Ark Open API 호출에는 발급받은 JWT가 필요하다.

```text
Authorization: bearer {JWT}
Accept: application/json
```

JWT는 조회 대상 게임 계정의 인증 정보가 아니다. 특정 캐릭터 소유자의 로그인은 필요하지 않으며 API 개발자에게 발급된 JWT를 요청 Header에 넣는다.
JWT를 클라이언트 앱에 직접 포함하는 방식은 노출 위험이 있으므로 실제 배포 구조를 정할 때 별도 검토한다.

## 3. 호출 제한
현재 확인한 공식 문서 기준 API 호출 제한은 분당 100회다. 제한 초과 시 HTTP 429가 발생할 수 있다.
프로젝트에서는 불필요한 반복 호출을 피하기 위해 로컬 캐싱과 자동/수동 갱신 정책을 사용한다.

## 4. 계정 캐릭터 목록 조회
Endpoint:

```text
GET /characters/{characterName}/siblings
```

예:

```text
GET /characters/이슈아이/siblings
```

캐릭터 이름 하나를 전달하면 해당 캐릭터와 같은 계정에 속한 캐릭터 목록이 반환된다. 실제 테스트에서는 서버가 다른 캐릭터도 함께 반환되었다. 요청 시 서버명은 별도로 전달하지 않는다.

확인된 응답 데이터:

```text
ServerName
CharacterName
CharacterLevel
CharacterClassName
ItemAvgLevel
```

프로젝트 흐름:

```text
사용자 캐릭터명 입력
→ siblings API 호출
→ 동일 계정 캐릭터 목록 확보
→ CharacterSummary 생성
→ 로컬 저장
→ 캐릭터 카드 목록 표시
```

주의: API가 실제 계정 ID를 제공하는 것은 현재 확인하지 않았다. 앱 내부에서 하나의 캐릭터 그룹처럼 취급할 수 있지만 실제 Lost Ark 계정 고유 ID가 확보된 것으로 간주하지 않는다.

## 5. 캐릭터 상세 조회
Endpoint:

```text
GET /armories/characters/{characterName}
```

예:

```text
GET /armories/characters/이슈아이
```

실제 이슈아이 캐릭터 조회 결과 현재 LOSTPARTY에서 필요하다고 판단한 상세 데이터가 하나의 응답에 포함되는 것을 확인했다.

확인된 최상위 데이터:

```text
ArmoryProfile
ArmoryEquipment
ArmoryAvatars
ArmorySkills
ArmoryEngraving
ArmoryCard
ArmoryGem
ArkPassive
ArkGrid
ColosseumInfo
Collectibles
```

현재 프로젝트에서 우선 사용할 항목:

| 프로젝트 데이터 | API 응답 |
| --- | --- |
| 캐릭터명 | ArmoryProfile.CharacterName |
| 서버명 | ArmoryProfile.ServerName |
| 캐릭터 레벨 | ArmoryProfile.CharacterLevel |
| 직업 | ArmoryProfile.CharacterClassName |
| 아이템 레벨 | ArmoryProfile.ItemAvgLevel |
| 전투력 | ArmoryProfile.CombatPower |
| 장비 | ArmoryEquipment |
| 스킬 | ArmorySkills |
| 각인 | ArmoryEngraving |
| 카드 | ArmoryCard |
| 보석 | ArmoryGem |
| 아크패시브 | ArkPassive |
| 아크그리드 | ArkGrid |

현재 설계에서는 각각의 개별 API 대신 종합 상세 API 1회를 우선 사용한다.

## 6. 상세 API 호출량
siblings 결과가 18명이라면:

```text
siblings 조회    1회
상세 조회       18회
--------------------
전체            19회
```

종합 상세 API를 사용하면 개별 상세 Endpoint를 각각 호출하는 것보다 호출량을 크게 줄일 수 있다.

## 7. 데이터 저장 기본 정책
캐릭터 상세 데이터는 API 호출에 성공하면 로컬에 저장한다.
수동 갱신과 자동 갱신의 저장 로직은 동일하며 차이는 API 호출을 발생시키는 트리거뿐이다.

```text
refresh(character)
→ Lost Ark 상세 API 호출
→ 응답 디코딩
→ CharacterDetail 생성/갱신
→ 로컬 데이터 저장
→ 화면 갱신
```

## 8. 수동 갱신
현재 정책안:

```text
수동 갱신 쿨타임: 10초
```

```text
[수동 갱신]
→ 10초 쿨타임 확인
→ 상세 API 호출
→ 성공 시 즉시 최신 데이터로 로컬 저장
→ 화면 갱신
```

별도의 미확정 데이터를 유지하지 않는다. 수동 조회에 성공한 데이터도 즉시 최종 데이터로 저장한다.

## 9. 자동 갱신
자동 갱신은 캐릭터별 ON/OFF 설정으로 관리한다.
현재 정책안:

```text
자동 갱신 주기: 30분
```

자동 갱신이 ON인 캐릭터의 상세 화면에 진입했을 때 마지막 API 갱신 시간을 확인한다.

```text
캐릭터 상세 진입
→ 자동 갱신 OFF: 저장 데이터 표시
→ 자동 갱신 ON: 마지막 갱신 후 30분 경과 여부 확인
    → 미경과: 저장 데이터 표시
    → 경과: API 호출 → 로컬 저장 → UI 갱신
```

30분은 API 자체 Rate Limit이 아니라 불필요한 반복 조회를 줄이기 위한 프로젝트 내부 캐시 정책이다.

## 10. 수동 갱신과 자동 갱신 관계
두 기능은 서로 독립적인 트리거다. 자동 갱신 후 30분이 지나지 않았더라도 사용자는 수동 갱신을 실행할 수 있다.

```text
자동 갱신 TTL     : 30분
수동 갱신 쿨타임 : 10초
```

이 값들은 구현 과정에서 변경 가능하다.

## 11. Lost Ark API 데이터 특성 고려
Lost Ark 캐릭터 API 데이터는 항상 앱에서 원하는 대표 세팅과 일치한다고 가정하지 않는다.
여러 캐릭터가 보석을 공유하는 사용자는 종료 전에 보석을 빼둘 수 있고, API에는 그 상태가 반영될 수 있다.

따라서 모든 캐릭터에 자동 갱신을 강제하지 않는다.

```text
보석 등을 공유하는 캐릭터 → 자동 갱신 OFF 사용 가능
항상 현재 세팅을 유지하는 캐릭터 → 자동 갱신 ON 사용 가능
```

잘못된 상태에서 수동 갱신한 경우 정상 세팅으로 변경하고 API 데이터가 갱신된 뒤 다시 수동 갱신하여 수정할 수 있다.

## 12. 현재 예상 데이터 개념
정확한 클래스/파일 구조는 실제 프로젝트 구조를 확인한 뒤 결정한다.

CharacterSummary (siblings):

```text
serverName
characterName
characterLevel
characterClassName
itemAvgLevel
```

CharacterDetail (종합 상세 API):

```text
profile
equipment
skills
engraving
card
gem
arkPassive
arkGrid
```

로컬 관리 메타데이터 후보:

```text
autoRefreshEnabled
lastFetchedAt
```

구체적인 Domain/Data Model 분리는 기존 프로젝트 아키텍처에 맞춰 결정한다.

## 13. JSON 모델링 시 주의사항
API 응답 전체를 그대로 앱 Domain Model로 만들지 않는다.
실제 응답은 매우 크며 일부 데이터는 Tooltip 문자열 내부에 추가 JSON/마크업 구조가 포함되어 있다.

예를 들어 장비 외부 구조는 다음과 같다.

```text
Type
Name
Icon
Grade
Tooltip
```

품질, 세부 옵션, 개별 아이템 레벨 등의 일부 정보는 Tooltip 내부에 포함되어 있다.

구현 원칙:

```text
화면/기능에서 필요한 데이터 결정
→ API 응답에서 위치 확인
→ 필요한 DTO 필드만 모델링
→ 필요한 경우 Tooltip 추가 파싱
→ Domain Model로 변환
```

상세 JSON 전체를 처음부터 모델로 변환하지 않는다.

## 14. ItemAvgLevel / CombatPower 타입 주의
실제 응답에서 다음 값은 숫자처럼 보이지만 문자열로 전달된다.

```json
"CombatPower": "3,382.29",
"ItemAvgLevel": "1,766.66"
```

비교/필터링/계산에 사용할 경우 쉼표 제거 후 숫자 타입으로 변환해야 한다. API DTO에서는 원본 타입을 유지하고 Domain 변환 과정에서 숫자화하는 방식도 고려한다.

## 15. Rate Limit 관리
자동 30분과 수동 10초 정책은 API Rate Limit 자체를 대체하지 않는다.
향후 API 호출 계층에서는 HTTP 429를 정상적으로 처리해야 한다.

추가 검토 항목:

```text
최근 API 호출량 관리
429 처리
재시도 정책
API 응답 Header의 Rate Limit 정보 활용
```

현재는 종합 상세 API 1회로 필요한 상세 데이터를 대부분 확보하므로 불필요하게 개별 상세 Endpoint를 병렬 호출하지 않는다.

## 16. 인증 토큰 보안 TODO
현재 API 테스트에서는 직접 발급한 JWT를 사용한다.
실제 앱 배포 시 JWT를 모바일 앱 바이너리 또는 일반 로컬 설정에 그대로 포함하면 토큰 추출 가능성이 있다.

배포 전에 다음 구조를 결정한다.

```text
앱에서 Lost Ark API 직접 호출
vs
자체 Backend/Proxy를 통한 호출
```

현재 미확정이다. JWT를 Git Repository에 커밋하지 않는다.

## 17. 현재 미확정 / TODO
- 실제 화면에 표시할 상세 데이터 범위
- 각 상세 데이터 DTO 구조
- 장비 Tooltip 파싱 범위
- 보석 Tooltip 파싱 필요 여부
- 각인 세부 데이터 사용 범위
- 스킬/트라이포드 데이터 사용 범위
- 아크패시브 표시 범위
- 아크그리드 표시 범위
- 카드 세트 효과 표시 범위
- 로컬 저장소 기술 선택 및 저장 구조
- 자동 갱신 ON/OFF 기본값
- 자동 갱신 30분 최종 확정
- 수동 갱신 10초 최종 확정
- HTTP 429 처리 정책
- JWT 보관 및 실제 배포 환경의 API 호출 구조

## 18. 현재 확정된 기본 흐름

```text
[최초 등록]
캐릭터명 입력
→ siblings API
→ 캐릭터 목록 생성
→ CharacterSummary 로컬 저장

[상세 조회]
캐릭터 카드 선택
→ 저장된 CharacterDetail 표시
→ 자동 갱신 ON + 30분 경과 시 refresh(character)

[수동 갱신]
사용자 갱신 버튼
→ 10초 쿨타임 확인
→ refresh(character)

[공통 refresh]
GET /armories/characters/{characterName}
→ 응답 디코딩
→ 필요한 데이터 추출
→ CharacterDetail 갱신
→ lastFetchedAt 갱신
→ 로컬 저장
→ UI 갱신
```

## 19. 사용 API 요약
계정 캐릭터 목록:

```text
GET /characters/{characterName}/siblings
```

용도: 최초 캐릭터 그룹 등록, CharacterSummary 확보.

캐릭터 종합 상세:

```text
GET /armories/characters/{characterName}
```

용도: 프로필, 전투력, 장비, 스킬, 각인, 카드, 보석, 아크패시브, 아크그리드.

현재 LOSTPARTY의 캐릭터 상세 갱신은 이 종합 Endpoint 1회를 기본으로 한다.
