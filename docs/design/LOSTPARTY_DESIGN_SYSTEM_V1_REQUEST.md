# LostParty UI / Design System v1 설계 요청서

> 기존 서비스 전용 항목은 [원문·출처 기록](../../legacy/firebase/extracted/docs/design/LOSTPARTY_DESIGN_SYSTEM_V1_REQUEST.md)으로 분리했다. 남은 제품/협업 문맥의 신규 서버 적용 여부는 별도 설계에서 판단한다.

## 적용 상태와 확정 기준

제품 판단의 우선순위는 **사용자가 앱과 현재 페이지의 목적·기능·상태를 이해하고 의도한 행동을 쉽게 수행하는 것**이다(2026-10-23 사용자 확정). 기술/패턴의 표현과 구현 편의보다 이 기준을 우선하며, 개발 판단·측정·후속 최적화 범위는 [공통 품질 기준](../architecture/DEVELOPMENT_QUALITY_AND_UX_STANDARD.md)을 따른다.

이 문서는 LostParty에 실제 적용할 Design System v1 계약이다. 최초 요청서의 후보 가운데 다음 값을 v1 기준으로 확정한다.

Theme·Bottom Navigation·공개 모집 대표 Card 시범 적용 결과를 사용자가 확인하고 디자인 방향을 승인했다. 다른 화면은 기능 작업과 함께 점진적으로 전환한다.

- Material 3와 시스템 폰트를 유지한다.
- v1은 Light Theme만 구현하고 Dark Theme은 후속으로 둔다.
- Primary는 `#725A9F`, App Background는 `#F8F7FA`, Surface·Card·Navigation은 `#FFFFFF`를 사용한다.
- Text Primary는 `#25232A`, Text Secondary는 `#68646F`, Text Disabled는 `#A8A4AD`를 사용한다.
- spacing scale은 `4, 8, 12, 16, 20, 24, 32`다.
- radius는 Small `6`, Medium `12`, Large `16`, Pill `999`다.
- 일반 Card는 흰색 Surface, Large radius, 약한 `#E8E4EC` border와 elevation 0을 기본으로 한다.
- Bottom Navigation은 흰색 Surface와 Lavender 선택 Pill을 유지한다.
- 상태색은 v1에서 success·warning·error·neutral의 최소 semantic 집합만 둔다. Dealer·Support 전용 색상은 실제 역할 Chip 적용 단계에서 확정한다.
- 화면 밀도는 Utility App에 맞춘 중간 밀도를 사용한다. 화면 좌우와 Card 내부는 기본 16, 주요 정보 간격은 8, 밀접한 metadata 간격은 4~6을 기준으로 한다.
- 확인 알럿의 취소/부정 버튼은 왼쪽, 동의/긍정 버튼은 오른쪽에 둔다(2026-10-15 사용자 확정). 대표 빠른 선택의 왕관/상태 설계는 [계약27](../backend-migration/27-representative-quick-selection-ux.md)을 따른다. 관련 없는 기존 화면 일괄 수정은 별도 작업이다.
- 통신 진행만으로 본문에 새 높이를 삽입하거나 기존 조작 영역을 숨겨 레이아웃을 움직이지 않는다. 내 계정은 타이틀 영역의 터치 통과 overlay로 진행을 표시한다. 통신 중을 개별 항목의 오류/정보 아이콘으로 바꾸지 않으며 수동 완료는 기존 체크 표시를 유지한다(2026-10-17 사용자 정정).

### v1 시범 적용 범위

1. 공통 Color·Spacing·Radius token과 Light Theme
2. 기존 Bottom Navigation의 token 적용
3. 공개 모집 대표 Card의 정보 계층·Badge·Surface 적용
4. 자동 테스트와 Android 실기기 확인


### 내 계정 화면 배치 확정 (2026-10-14)

사용자가 현재 디자인 유지와 dev 통합을 승인했다. 화면은 메인 계정 등록 현황 → 부계정 등록 현황 → 계정 도구 순서다. 캐릭터 정보·레이드 현황을 먼저 표시하고 부계정 추가는 부계정 제목 옆에 둔다. 서버 등록 안내·API 토큰/인증·캐릭터 조회 입력과 조회 프로필은 하단 계정 도구에 둔다. 계정 없는 상태는 영역별로 안내하며 기존 카드·대표/표시 순서·관리/수정/삭제/갱신 기능을 유지한다. 이 배치는 서버 UUID와 로컬 계정 데이터를 통합하거나 신규 등록 API를 연결하는 변경이 아니다. 다음 등록 기능에서도 이 정보 순서를 유지한다.

### 기존 디자인·사용 흐름 유지 원칙 (2026-10-17 사용자 확정)

기존 디자인과 UI/UX, 사용자가 설명한 개발 의도를 최대한 유지하며 개발한다. 최신 사용자 승인 변경을 포함한 화면/흐름이 기준이며, 이 원칙을 이유로 이미 승인한 개선을 과거 상태로 일괄 되돌리지 않는다.

- API·데이터 저장·내부 구조를 바꾸더라도 화면 정보 순서, 카드/그리드 형태, 버튼 위치와 기능 진입, 캐릭터 상세 직접 진입, 선택/정렬/취소 방식을 임의로 변경하지 않는다.
- 아직 서버에 연결하지 않은 기능도 기존 진입점과 후속 확장 영역을 보존한다. 미연결 상태가 디자인 삭제·축소의 근거가 되지 않는다.
- 개발자에게 구현하기 좋은 구조인지와 앱 사용자가 이해하고 조작하기 좋은 구조인지를 구분한다. 불필요한 중간 화면·클릭·숫자 입력·장문 안내를 추가하지 않는다.
- 개선이 필요하면 영향받는 기존 흐름, 변경 전후, 사용자의 이점과 추가 조작/영향을 짧게 제안하고 동의한 범위에서 반영한다. 사용자가 이미 지시한 변경은 중복 확인하지 않는다.
- 기존 승인 동작의 버그/레이아웃 깨짐은 최소 수정으로 복구한다. 관련 없는 정상 화면의 재설계를 끼워 넣지 않는다. 서버 권한/오류 복구에 필요한 내부 처리를 장황한 사용자 단계로 노출하지 않는다.

## Penpot 작업·완료 화면 관리 공통 지침

2026-10-28 사용자 확정. 이 절은 기능별 Penpot 러프디자인부터 구현 완료 화면 관리까지 공통 적용한다. 새 작업 방식 문서를 따로 만들지 않고 이 절을 갱신한다.

- **03 작업 중인 화면:** 사용자가 ‘이렇게 만들어질 모습이 내가 생각한 모습과 맞는가’를 눈으로 검토하는 공간이다. 구현 예정 화면도 아이콘·배치·문구를 검토 가능한 완성도로 작성하고, 미결정 부분은 화면 밖에 명시한다. 현재 앱을 옮기는 작업은 실제 구현과 일치시킨다. 실제 작업 시작 시 파일/페이지 이름과 식별자를 조회하며 과거 명칭만으로 페이지를 추정하거나 중복 생성하지 않는다.
- **02 구현 화면:** 실제 개발 완료·확인된 화면을 관리하는 동시에, 앱을 모르거나 설치하지 않은 사람도 ‘무슨 앱이며 무엇을 어떻게 사용하는가’를 이해할 수 있는 디자인 안내서다. 기능 목적·화면 순서·주요 행동과 결과를 디자인 안에서 설명한다. 디자인을 그렸다는 이유만으로 완료 화면으로 분류하지 않는다.
- **보드 구조 (2026-10-31 사용자 확정):**02는 앱 시작·내 계정·레이드 현황·레이드 모집·설정/로그인/인증·그룹을 각각 독립된 기능 설명 보드로 둔다. 전체 앱을 감싸는 거대한 메인 보드는 만들지 않는다.03에서는 작업 단위(예: 그룹 전체 흐름)당 하나의 메인 보드를 두고, 그 안에 화면·기능 섹션별 하위 보드를 배치한다. 목록·요청·상세·생성/가입·관리와 필요한 상태는 해당 섹션에서 구분한다. 메인 보드는 섹션 보드들을 담는 상위 구조이며 섹션을 무관한 최상위 보드로 흩뜨리지 않는다.
- **UX 설명:** 메인 보드에는 전체 진입·이동 흐름과 현재 작업 상태를, 섹션 보드에는 진입→주요 행동→결과·역할/상태 차이·구현 의도를 짧게 표시한다. 사람이 디자인만 보고 동작을 이해할 수 있게 하며, 설명은 앱 화면 바깥의 주석 영역에 두어 실제 사용자 문구/버튼과 구분한다. 설명마다 별도 보드를 추가하지 않고 해당 메인/섹션 안에서 갱신한다.
- **수정 방식:** 기존 기능 보드 안의 대상 섹션을 확인해 직접 갱신한다. 섹션 증감에 따른 상위 크기·아래 섹션 위치와 보드 간 여백도 함께 조정한다. 피드백·버전·날짜별 새 메인 보드나 같은 화면 사본을 계속 추가하지 않는다. 상태 차이 표현이 필요한 하위 보드는 같은 섹션 안에서 필요한 만큼만 둔다. 이전 안 보관이 필요한 경우에도 명시적인 필요 범위만 보존하며 자동 복제하지 않는다.
- **완료 이관 (2026-10-31 사용자 확정):** 개발·화면 확인 완료만으로 자동 이관하지 않는다. 사용자가 별도로 이관을 지시한 경우에만, 실제 구현과 일치하도록03의 기존 메인 보드·하위 섹션을 정리한 뒤 **동일한 메인 보드 묶음을02로 이동**한다.02용 완성본을 자동 복제·재작성하지 않는다. 사용자가 직접 복사한 보드가 있으면 그 객체를 우선 재사용하고 재복제하지 않는다. 따라서03에서부터 완료 화면으로 바로 이관할 수 있는 구조와 이름을 유지한다.
- **부분 완료:** 일부 섹션만 구현됐거나 서버 연결/기기 확인이 남았으면 전체 그룹 보드를 완료로 이동하지 않는다. 작업 중 상태를 기존 섹션에 표시하고, 전체 작업 단위 완료 후에도 사용자 별도 이관 지시까지03에 유지한다.
- **중복/참조 확인:** 이동 시02의 같은 작업 보드와 중복 여부, 하위 계층·섹션 순서·이동 후 실제 화면 대응을 확인한다. 기존 완료 화면이나 다른 작업 보드를 임의 삭제하지 않는다. 가능한 동일 객체/식별자와 연결을 유지하고 이동 결과를 확인한다.
- **MCP 연결:** 로컬 PowerShell MCP를 우선 사용한다. 시간 초과만으로 연결 단절을 확정하지 않는다. 화면/섹션 단위로 명령을 분할하고 응답 시간 초과 뒤에는 읽기로 반영 여부를 확인해 중복 실행을 피한다. 실제 연결 단절·읽기/명령 실행 불능이 확인되면 작업을 중단하고 사용자에게 MCP 재연결 확인을 요청한다. Chrome 직접 제어로 전환하지 않는다.
- **설명과 프로토타입:** 설명 보드와 실제 화면 실행을 구분한다. 전체 앱 프로토타입은 별도 연결 단계이며 설명 보드 완성을 클릭/스크롤 검증 완료로 주장하지 않는다.
- **문서 책임:** 제품 동작은 제품 계약, 현재 디자인 운영 방식은 이 절, 실제 작업 상태/다음 행동은 NEXT_WORK, 완료 이관/검증 경과는 DEV_LOG에 기록한다. 별도 디자인 버전 문서를 무한정 추가하지 않는다. 과거03/04 페이지 운영 이력은 당시 기록이며 현재 작업 방식을 대체하지 않는다.

이번 지침 기록은 Penpot 보드 생성·수정·이동 완료 보고가 아니다. 실제 디자인 작업 때 현재 페이지/보드를 확인하고 위 방식을 적용한다.

### 화면 규격·자산·디자이너 역할 (2026-10-29 사용자 확정)

- **공통 화면:** 기본 모바일 화면은390×844 디자인 단위, 모서리 반경16, 중립색 `#A8A4AD` 1px 안쪽 테두리로 통일한다. 기기 몸체·카메라 모형 대신 액정 디스플레이 영역을 표현한다. 앱의 실행 해상도를 고정하는 규칙은 아니다. 현재03에 먼저 적용하고 사용자 확인 후02에 적용하며, 기존02를 일괄 변경한 것으로 간주하지 않는다. 이후 기본 모바일 작업도 같은 규격을 사용한다. 태블릿·폴드 등의 별도 반응형 예시는 크기와 목적을 명시한다.
- **화면 수명과 영역:** 긴 내용은 프레임을 무제한 늘리지 않고 스크롤 화면으로 표현한다. 추가 상태·스크롤 위치는 같은 섹션에서 최소한으로 구분한다. 다이얼로그·선택창은 같은 화면 규격 안에서 맥락과 함께 표현한다. 상태바·하단 안전 영역은 같은 기준으로 관리하고 실제 내비게이션·고정 버튼의 위치와 구분한다. 디자인 장식을 앱 UI로 오해하게 하지 않는다.
- **동일 자산:** 프로젝트에서 사용하는 PNG/JPEG/WebP/SVG 등의 로컬 자산을 필요시 Penpot에 업로드·가져와 재사용한다. Flutter `Icons.*`는 동일한 Material 아이콘·스타일의 원본이나 해당 글리프를 정확히 변환한 자산을 사용한다. `○`, `♧` 같은 문자나 닮은 임시 그림으로 대체하지 않는다. 원본의 색·선택/비선택 상태·비율을 확인하고, 확보한 유효 자산은 재사용한다. 파일·접근·업로드 권한이 부족하면 필요한 대상과 이유를 알리고 요청한다. 확보하지 못한 자산을 임의 대체해 완료로 보고하지 않는다.
- **실제 앱 대조:** 현재 화면은 Flutter의 실제 아이콘·크기·간격·색·정렬·버튼/내비게이션 배치와 제공된 실행 화면을 근거로 작성한다. 코드 대조와 기기 확인은 구분하며, 편의를 위한 수동 배치나 러프디자인이라는 명칭으로 괴리를 허용하지 않는다. 향후 화면은 동일한 디자인 시스템과 확정 UX를 따르고 미결정 사항을 실제 구현처럼 보이게 하지 않는다.
- **이해 가능한 안내서:** 메인에 앱/기능의 목적·대상 사용자·읽는 순서를 간결히 두고 섹션에는 진입→행동→결과와 필요한 역할·상태 차이를 설명한다. 내부 API·DB 용어를 이용 설명 대신 나열하지 않는다. 화면 안은 실제 사용자 문구, 화면 밖은 디자인 설명으로 구분한다. 가상 인물·수치는 예시임을 표시하고 개인정보·실제 인증정보를 사용하지 않는다. 기존 메인/섹션 안에서 정리하며 소개용 보드를 계속 추가하지 않는다.
- **검수와 책임:** 디자이너 역할에는 자산 확보·일관된 시각 구성·흐름 전달·실제 구현 대조·최종 눈검수가 포함된다. 섹션별 PNG와 전체 보드를 눈으로 확인해 잘림·겹침·프레임 이탈·가독성을 검사하고, 아이콘/배치/문구/이동 흐름은 실제 앱 근거와 별도로 대조한다. PNG 출력 성공만으로 앱 일치를 선언하지 않는다. 기기 확인은 사용자가 수행하며 미확인·불일치·개선 예정은 명시한다. 기존 구현의 알려진 문제를 디자인에서만 고쳐 완료로 표시하지 않는다.02 이관 전에는 앱을 처음 보는 사람이 목적·핵심 흐름·결과를 이해할 수 있는지도 검토한다.

## 1. 목적

현재 LostParty는 기능 구현을 우선하여 개발되어 왔으며, Flutter/Material 기본 UI에 가까운 형태를 가지고 있다.

기능 구조를 크게 변경하지 않으면서 LostParty만의 일관된 디자인 언어를 만들고자 한다.

이번 작업의 핵심은 개별 화면을 임의로 꾸미는 것이 아니라 다음 순서로 진행하는 것이다.

1. LostParty Design System v1 정의
2. 공통 Theme 및 디자인 토큰 정리
3. 기존 UI에 점진적으로 적용
4. 대표 컴포넌트에서 실제 디자인 검증
5. 검증 후 전체 화면으로 확장

이번 단계에서는 전체 UI를 한 번에 리디자인하지 않는다.

---

## 2. 디자인 방향

LostParty의 기본 디자인 콘셉트는 다음과 같이 정의한다.

> Soft Lavender Gaming Utility

LostParty는 게임 자체가 아니라 Lost Ark 플레이를 보조하는 파티 모집/관리 도구이다.

따라서 Lost Ark 게임 UI의 어두운 배경, 금색 장식, 판타지 스타일 등을 직접 모방하지 않는다.

게임 커뮤니티 도구와 현대적인 Utility App 사이의 느낌을 목표로 한다.

전체적인 컬러 비율은 대략 다음 방향을 따른다.

- Neutral: 약 75%
- Lavender/Purple: 약 15%
- Status Color: 약 10%

보라색으로 앱 전체를 덮지 않는다.

보라색은 LostParty의 브랜드 컬러이면서 동시에 사용자 인터랙션과 선택 상태를 표현하는 색으로 사용한다.

---

## 3. 현재 UI에서 유지할 요소

현재 UI에 이미 적용되어 있는 연보라 계열의 방향성 자체는 유지한다.

특히 다음 요소는 LostParty의 디자인 언어로 발전시킨다.

- 진한 보라색 Primary Button
- 선택된 Bottom Navigation 항목의 연보라 Pill
- 연보라색 Badge/Chip
- 밝고 부드러운 전체 UI
- 둥근 형태의 인터랙션 요소

현재 디자인을 완전히 폐기하고 새로운 스타일로 교체하는 것이 목적이 아니다.

현재 디자인에서 좋은 요소를 유지하면서 색상, Surface, Card, Button 등의 규칙을 통일한다.

---

## 4. Color System

### Primary

LostParty의 Primary Color는 채도가 지나치게 높지 않은 muted purple 계열을 사용한다.

기본 후보:

- Purple 700: `#59427F`
- Purple 500: `#725A9F`
- Purple 200: `#D9CCED`
- Purple 100: `#EEE7F7`

기본 Primary는 `#725A9F`를 기준으로 한다.

현재 앱에서 사용되고 있는 진한 보라색 버튼의 분위기를 유지하는 방향이다. 지나치게 밝거나 형광에 가까운 violet 계열은 피한다.

---

## 5. Neutral Color / Surface

현재 앱은 배경, 카드, Bottom Navigation 등의 명도 차이가 작아 화면 전체가 평평하게 보이는 문제가 있다.

이를 해결하기 위해 Surface 계층을 명확하게 분리한다.

### App Background

기본 후보는 `#F8F7FA`다.

거의 흰색에 가까우면서 아주 약한 cool/lavender tone만 가진다. 앱 전체 배경에 강한 보라색 느낌을 주지 않는다.

### Surface / Card

기본값은 `#FFFFFF`이다.

일반 카드와 주요 Surface는 흰색을 기본으로 한다. 현재 일부 카드처럼 연보라/회색 Surface를 기본 카드 배경으로 반복 사용하는 것은 줄인다.

### Bottom Navigation

기본값은 `#FFFFFF`이다.

화면 Background와 Bottom Navigation의 계층을 구분한다. 필요한 경우 매우 약한 divider 또는 elevation만 사용한다.

---

## 6. Text Color

텍스트는 완전한 `#000000` 사용을 최소화하고 neutral 계열을 사용한다.

초기 후보:

- Text Primary: `#25232A`
- Text Secondary: `#68646F`
- Text Disabled: `#A8A4AD`

최종 값은 현재 Flutter Theme 및 접근성 대비를 검토하여 조정 가능하다.

Primary Purple을 일반 본문 텍스트에 남용하지 않는다. Purple text는 선택 상태 또는 브랜드 강조가 필요한 경우에만 사용한다.

---

## 7. Purple 사용 원칙

Purple 500 이상의 진한 색상은 화면에서 차지하는 면적을 제한한다.

주요 사용 대상:

- Primary Action
- Selected State
- Active Tab
- 중요한 Icon
- Focus State
- 브랜드 강조

다음 영역 전체를 진한 보라색으로 채우는 방식은 피한다.

- 전체 화면 Background
- 일반 Card 전체
- Bottom Navigation 전체
- AppBar 전체

즉, 다음 구조를 기본 원칙으로 한다.

> Neutral Surface 위에 Lavender/Purple Accent를 사용하는 구조

---

## 8. Status Color와 Brand Color 분리

모든 정보를 Purple로 표현하지 않는다. Purple은 브랜드/인터랙션 색상이다.

상태 정보는 필요에 따라 별도의 Semantic Color를 사용한다.

향후 정의 대상:

- Success
- Warning
- Error
- Recruiting
- Closed
- Completed

역할 표시가 필요할 경우 다음과 같이 별도 색상 사용을 검토할 수 있다.

- Dealer: muted coral/red 계열
- Support: muted mint/teal 계열

단, 상태색 역시 채도를 낮춰 전체 Soft Lavender 디자인과 충돌하지 않도록 한다. 이번 v1에서 불필요하다면 상태색을 무리하게 추가하지 않아도 된다.

---

## 9. Bottom Navigation

현재 Bottom Navigation의 선택 표현 방식, 특히 선택 항목 뒤의 Lavender Pill을 LostParty의 대표적인 인터랙션 디자인 중 하나로 유지한다.

기본 구조:

- Navigation Background: White
- Selected Pill: Purple 100
- Selected Icon: Purple 700 또는 Purple 500
- Selected Label: Text Primary 또는 Purple 700
- Unselected Icon: Neutral Gray
- Unselected Label: Neutral Gray

선택된 항목 전체에 진한 보라색을 사용하지 않는다. 현재 사용 중인 Pill 형태를 유지하되 모든 탭에서 크기, radius, padding이 동일하도록 한다.

---

## 10. Button Hierarchy

버튼을 최소한 다음 계층으로 구분한다.

### Primary Button

가장 중요한 행동에 사용한다.

예:

- 계정 데이터 불러오기
- 세팅 갱신
- 모집글 최종 생성
- 지원하기

스타일:

- Background: Purple 500
- Foreground: White
- 충분한 contrast 유지

한 화면에서 Primary Button이 지나치게 많이 존재하지 않도록 한다.

### Secondary Button

부계정 추가, 게임계정 인증, 설정 관련 보조 행동 등에 사용한다.

스타일 후보:

- White 또는 Transparent Background
- Purple 또는 Neutral Border
- Purple 500/700 Foreground

### Tertiary / Text Action

중요도가 낮은 행동은 TextButton 또는 IconButton 계열로 처리한다. Primary Button과 시각적 경쟁을 하지 않도록 한다.

### Disabled

Disabled 상태에서는 Purple을 유지하면서 opacity만 낮추기보다 Neutral Disabled Color 사용을 우선 검토한다.

---

## 11. Card System

현재 LostParty의 카드 UI는 Flutter/Material 기본 Card의 인상이 강하다.

Design System v1에서는 다음 공통 요소를 결정한다.

- Border Radius
- Internal Padding
- Card 간 Vertical Spacing
- Border 사용 여부
- Shadow/Elevation
- Background Color

기본 방향:

- White Surface
- Medium Rounded Corner
- 매우 약한 Border 또는 Shadow
- 강한 Material Shadow는 피함
- 충분한 내부 여백

Border와 Shadow를 동시에 강하게 사용하지 않는다. 화면마다 서로 다른 Card radius나 elevation을 임의로 사용하지 않는다.

---

## 12. RecruitmentCard를 대표 컴포넌트로 지정

`RecruitmentCard`를 LostParty Design System v1을 처음 검증하는 대표 컴포넌트로 사용한다.

현재 모집 카드가 가진 정보는 유지하면서 정보 계층을 개선한다.

예상 정보:

- 모집글 제목
- Raid
- Difficulty
- Gate
- 시작 시간
- Member 현황
- 남은 자리
- 최소 Item Level
- Experience
- 내가 만든 방 여부
- 모집 상태

단순히 모든 정보를 동일한 Text 형태로 나열하지 않고 중요도에 따라 다음과 같은 시각적 계층을 만든다.

### High Priority

- 모집글 제목
- 모집 상태

### Medium Priority

- Raid / Difficulty / Gate
- 시작 시간
- Member 현황

### Low Priority / Metadata

- 최소 Item Level
- Experience
- 기타 조건

---

## 13. RecruitmentCard의 Color 사용

Card 자체는 기본적으로 White Surface를 사용한다.

Purple은 다음과 같은 작은 영역에서만 사용한다.

- 내가 만든 방 Badge
- Recruiting Badge
- Difficulty Chip
- 선택 상태
- 일부 중요 Icon
- Accent Element

Card 전체를 Lavender로 채우는 방식은 기본 디자인으로 사용하지 않는다. Raid/Difficulty/Status Chip 등을 이용해 LostParty만의 카드 문법을 만드는 방향을 우선 검토한다.

---

## 14. Chip / Badge System

향후 다음 정보가 Badge 또는 Chip으로 표현될 가능성이 있다.

- 내가 만든 방
- 모집중
- 모집마감
- Normal
- Hard
- Nightmare
- Dealer
- Support
- Experience Level

모든 Chip이 동일한 색을 사용할 필요는 없다. 다만 공통적으로 다음 속성은 Design Token화를 검토한다.

- Height
- Horizontal Padding
- Radius
- Font Size
- Font Weight

Chip을 지나치게 많이 사용해 화면이 태그 모음처럼 보이지 않도록 한다.

---

## 15. Typography

새로운 커스텀 폰트를 도입하는 것이 이번 작업의 목적은 아니다.

기존 시스템 폰트를 유지하더라도 최소한 다음 Typography 역할을 구분한다.

- Page Title
- Section Title
- Card Title
- Body
- Metadata
- Caption
- Button Label
- Badge Label

각 화면에서 임의의 fontSize/fontWeight를 직접 지정하는 것을 줄이고 Theme/TextStyle 기반으로 통일하는 방향을 검토한다.

---

## 16. Spacing System

AI에 의해 화면별 spacing 값이 제각각 생성되지 않도록 공통 spacing scale을 정의한다.

예시 후보:

- 4
- 8
- 12
- 16
- 20
- 24
- 32

필요하지 않은 13, 17, 19 등의 임의 spacing 값을 화면별로 추가하지 않는다.

특히 다음 값은 공통화한다.

- Screen Horizontal Padding
- Section 간 Vertical Spacing
- Card Internal Padding
- Card 간 Spacing
- Button 내부 Padding
- Icon/Text 간격

현재 프로젝트의 기존 UI 구조를 확인한 뒤 적절한 값을 제안한다.

---

## 17. Radius System

Rounded UI는 LostParty의 디자인 특성으로 유지한다. 단, 화면마다 서로 다른 radius를 무작위로 사용하지 않는다.

예를 들어 다음 정도의 체계를 검토한다.

- Small: Badge / Chip
- Medium: Input / 일반 Button
- Large: Card
- Full/Pill: Bottom Navigation Selected Indicator 및 특정 Action

실제 숫자는 현재 UI를 분석한 뒤 결정한다.

---

## 18. Icon

기존 Material Icon을 당장 전부 교체할 필요는 없다. 다만 다음 규칙을 통일한다.

- Icon size
- Icon color
- Text와의 spacing
- Selected / Unselected 상태
- Semantic 상태 Icon

장식 목적으로 불필요한 Icon을 추가하지 않는다. Icon은 정보 전달 또는 인터랙션을 보조하는 용도로 사용한다.

---

## 19. Empty State

현재 `진행 중인 레이드가 없습니다.` 화면과 같은 Empty State도 Design System 대상에 포함한다.

Empty State의 기본 구조를 통일한다.

- Icon
- Primary Message
- Secondary Description
- 필요할 경우 Action

Empty State 전체에 Purple을 많이 사용하지 않는다. Icon 또는 작은 Accent 정도에만 브랜드 컬러를 사용할 수 있다.

---

## 20. 화면 밀도

현재 LostParty는 Utility App이므로 지나치게 큰 UI 요소와 과도한 여백을 사용하지 않는다.

특히 모집 목록처럼 여러 정보를 빠르게 확인해야 하는 화면은 정보 밀도를 적절히 유지한다. 반대로 모든 정보를 작은 글씨로 압축하지 않는다.

목표는 다음과 같다.

> 한눈에 필요한 정보를 파악할 수 있으면서 답답하지 않은 UI

---

## 21. Design Token 우선

가능하다면 화면 내부에 색상과 spacing을 직접 하드코딩하기보다 Design Token / Theme 기반 구조를 사용한다.

예:

- AppColors
- AppSpacing
- AppRadius
- AppTextStyles

단, 기존 프로젝트 구조를 먼저 분석한 후 현재 Architecture에 맞는 위치와 이름을 제안한다.

불필요하게 거대한 Design System Framework를 만들지 않고 MVP 규모에 적절한 단순한 구조를 유지한다.

---

## 22. Dark Mode

이번 Design System v1에서는 Dark Mode 구현을 우선 목표로 하지 않는다.

먼저 Light Theme의 디자인 언어를 완성한다. Dark Theme은 Light Theme이 안정화된 이후 별도 단계에서 파생한다.

다만 Theme 구현 과정에서 향후 Dark Theme 추가가 지나치게 어려워지는 하드코딩은 피한다.

---

## 23. 이번 작업에서 하지 않을 것

다음 작업을 한 번에 진행하지 않는다.

- 전체 화면 일괄 리디자인
- 모든 Widget 재작성
- Architecture 변경
- 새로운 상태관리 도입
- 새로운 UI Framework 도입
- 불필요한 Animation 추가
- Dark Mode 동시 구현
- 모든 Card를 한 번에 교체
- 게임 UI를 직접 모방하는 디자인
- 기능 로직 변경

이번 작업의 목적은 기능 변경이 아니라 디자인 기반을 만드는 것이다.

---

## 24. 권장 작업 순서

### Phase 1 — 현재 프로젝트 분석

현재 프로젝트에서 다음을 먼저 확인한다.

- Theme 정의 위치
- Color 하드코딩 현황
- TextStyle 사용 현황
- Card 스타일
- Button 스타일
- Bottom Navigation 구현
- RecruitmentCard 구현
- 공통 Widget 구조

코드는 아직 수정하지 않는다.

### Phase 2 — Design System v1 제안

분석 결과를 기준으로 다음을 확정한다.

- Color Tokens
- Typography
- Spacing
- Radius
- Surface
- Button hierarchy
- Card rule
- Chip/Badge rule
- Bottom Navigation rule

현재 문서의 색상 값은 방향성을 위한 후보이므로 프로젝트의 기존 UI와 비교 후 필요한 경우 소폭 조정할 수 있다. 단, 전체적인 Soft Lavender 방향은 유지한다.

### Phase 3 — Theme / Token 기반 구현

확정된 Design System을 코드 구조에 반영한다. 가능한 한 기존 기능 로직에는 영향을 주지 않는다.

### Phase 4 — Bottom Navigation 적용

현재 디자인을 크게 변경하지 않고 새로운 Color/Token 규칙을 적용한다. 현재의 Selected Lavender Pill 디자인은 유지한다.

### Phase 5 — RecruitmentCard 시범 적용

RecruitmentCard 하나에 새로운 Design System을 적용한다. 이 단계에서 LostParty의 대표적인 Card 디자인을 만든다.

### Phase 6 — 사용자 확인

여기서 작업을 중단한다. 전체 화면으로 자동 확장하지 않는다.

실제 Emulator/Device에서 결과를 확인한 뒤 다음 단계 진행 여부를 결정한다.

### Phase 7 — 전체 화면 확장

사용자가 디자인 방향을 승인한 경우에만 다음 화면으로 순차 확장한다.

예:

- 레이드 현황
- 내 계정
- Character Detail
- 파티 모집
- 설정
- 기타 화면

---

## 25. Codex 작업 요청

현재 프로젝트를 먼저 분석하고 위 Design System v1 방향을 실제 프로젝트 구조와 비교한다.

바로 전체 UI를 수정하지 않는다. 우선 다음 결과를 보고한다.

1. 현재 Theme/Color/TextStyle 구조
2. 하드코딩된 디자인 값이 주로 존재하는 위치
3. 공통화할 수 있는 디자인 요소
4. Design System v1을 적용하기 위해 추가/수정할 파일 후보
5. 현재 구조를 최대한 유지하는 최소 변경 방안
6. RecruitmentCard를 대표 컴포넌트로 개선할 구체적인 디자인 제안
7. 예상 작업 순서
8. 각 단계에서 수정될 파일 범위
9. 기존 기능에 영향을 줄 가능성이 있는 부분

이 분석 결과를 먼저 제시하고 사용자 승인 없이 전체 UI 리팩터링을 시작하지 않는다.

---

## 26. 최종 목표

LostParty의 디자인 목표는 화려함이 아니다.

사용자가 앱을 보았을 때 다음과 같은 느낌보다

> 기본 Flutter Material 화면

다음과 같은 인상을 받을 수 있도록 만드는 것이 목표다.

> LostParty라는 하나의 제품

이를 위해 새로운 장식 요소를 많이 추가하기보다 다음 요소의 일관성을 우선한다.

- Color
- Surface
- Typography
- Spacing
- Radius
- Card
- Button
- Navigation
- Badge
- 상태 표현

LostParty의 시각적 아이덴티티는 다음을 중심으로 구축한다.

> Neutral Surface + Soft Lavender Accent + Muted Purple Primary

## 숫자·원정대 상태 공통 표시 원칙 (2026-10-17)

아이템레벨·전투력은 소수점 이하를 버린 정수부와 천 단위 쉼표로 표시한다. 시간은 초까지만 표시한다. 원본/API/서버·로컬 저장 및 정렬·자격 판정에는 소수점 정밀도를 유지하며 표시 문자열을 다시 저장하지 않는다. 미확인 값은 기존 미확인 안내를 유지한다. 원정대 상태는 인증·활동 선택 완료 문구를 반복하지 않고 인증 필요/활동 캐릭터 미선택·재선택처럼 필요한 행동만 표시한다. 로그인 회원의 미인증 등록도 서버에 저장되며 같은 회원의 다른 기기/재설치 로그인에서 조회된다.
