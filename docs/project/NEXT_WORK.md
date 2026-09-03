# NEXT WORK

## 현재 기준과 이번 범위

- 직전 활동 Character 공개 경로와 레이드 현황 필터 UX는 구현·Android 실기기 확인까지 완료했다. 별도 Projection 없이 활동 ID 목록과 Character 표시 문서를 조합하는 구현을 유지한다.
- 이번 준비 시작점은 `dev` `22ae54b`다. 실제 구현 시작 시 원격과 동기화한 최신 `dev`에서 새 작업 브랜치를 만든다.
- 다음 작업은 **레이드 모집 탭의 파티 모집 목록 필터**다. `모집 만들기` 입력 화면은 대상이 아니다.
- 현재는 분석·계약·실행 계획만 문서화했다. 아래 필터 확장은 아직 구현하거나 테스트하지 않았다.
- 상세 기준: [활동 Character와 필터 계약 §13](../architecture/ACTIVITY_CHARACTER_AND_RAID_FILTER_CONTRACT.md#13-레이드-모집-탭-목록-필터-확장).
- 첫 릴리즈 전에는 PR 없이 검증한 작업 브랜치를 `dev`에 직접 병합·푸시한다. `main`은 변경하지 않는다.

## 목표

가입 전 조회 가능한 파티를 레이드 현황과 같은 필터 UX로 좁혀 본다. 기존 내 방·확정 참가 방 제외, 신청 대기 방 유지, 공개/그룹 조회 권한과 모집 가능 조건을 유지한다.

## 포함 범위

- 전체·일반·그룹, 레이드·난이도 복수 선택
- 그룹만 선택했을 때 가입 그룹·참여 그룹원·활동 Character 선택
- 초기화, 조건 요약, 현재 결과 개수, 선택 복원, 고정 상단 드래그 닫기
- 모집 목록/레이드 현황의 선택값을 Player와 화면 단위로 분리
- 공개 모집 페이징과 그룹 listing 병합 결과를 원본으로 유지하며 로컬 필터 적용
- 참가 Character 확인 중·실패를 구분하고 결과에 미확인 파티를 일치로 섞지 않음
- 조건 때문에 비었을 때도 추가 페이지 로딩·재시도·초기화 경로 제공

## 실행 순서와 완료 조건

### A. 공통 필터 구조와 화면별 저장

- 선택 모델·순수 판정·카탈로그 옵션·라벨·후보 로딩·필터 UI의 재사용 경계를 분리한다.
- `ActiveRaidFilterViewModel`은 현황 데이터에 종속되므로 모집 화면에 직접 연결하지 않는다.
- 기존 현황 선택값을 보존하면서 화면별 저장 키 또는 스키마를 도입한다. 모집 목록은 기본 전체로 시작한다.
- 완료: 동일한 UX를 공유하고 화면 간 선택/초기화가 서로 영향을 주지 않는다. 현황 회귀 테스트 통과.

### B. 모집 목록 기본 필터와 페이징

- `PublicRecruitmentListViewModel`의 원본·필터 결과·cursor·오류·세대 관리를 분리한다.
- 기존 공개 쿼리와 가입 그룹 listing 읽기 구조를 유지하고 공개 조건·레이드·난이도·그룹 조건을 연결한다.
- 첫 페이지 갱신, 추가 페이지, 중복 ID, 늦은 응답을 안전하게 처리한다.
- 빈 결과 자동 보충은 기존 3회 상한을 기준으로 제한하고 이후 명시적 더 불러오기를 제공한다. 재빌드로 상한을 초기화하지 않는다.
- 완료: 첫 페이지에 일치 항목이 없어도 후속 페이지의 일치 모집을 찾을 수 있고 무한 조회가 없다.

### C. 그룹원·Character 참가 조건

- 공개 목록 모델에 참가 Player ID를 전달하고 public/listing 두 매핑 경로를 대조한다.
- 그룹원 후보는 내가 가입한 그룹의 정상 멤버이며 본인은 제외한다. Character 후보는 기존 활동 목록 읽기를 재사용한다.
- 선택한 그룹원들이 실제 해당 레이드에 확정 참가했는지 판정한다. pending 신청자는 참가자로 취급하지 않는다.
- Character 조건이 있을 때 필요한 파티의 membership 표시 정보를 제한적으로 조회한다.
- 조회 대기·실패·재시도·방 revision 변경·갱신에 따른 캐시 무효화 및 오래된 응답 무시를 구현한다.
- 완료: 사용자 내부 Character OR, 사용자 간 AND가 정확하며 정보가 미확인인 방을 일치 결과로 보여주지 않는다.

### D. 최종 검증과 사용자 실기기

- 공통 필터, 저장 분리, public/listing mapper, 모집 ViewModel·위젯과 기존 현황 회귀 테스트
- 첫 페이지 불일치/후속 일치, 원본 빈 목록/필터 빈 목록, 중복·늦은 응답·새로고침·권한 상실·재시도 테스트
- 그룹원 참가/미참가, Character 조건 확인 중/실패, 참가 Character 변경, 활동 해제 후 기존 membership 보존 테스트
- 공개 필터의 그룹 분류는 `visibility`가 아니라 `groupId`임을 회귀로 고정
- 공유 구조와 여러 feature를 변경하므로 최종 코드에서 `flutter analyze --no-pub`와 전체 `flutter test --no-pub` 각 1회
- 실제 실행한 결과·테스트 수·실패/제약을 DEV_LOG에 기록한다. 과거 792개 통과를 이번 변경의 검증 결과로 재사용하지 않는다.
- 사용자 실기기: 모집/현황 선택 독립, 초기화·재진입·드래그 닫기, 가입 전 그룹원·Character 검색, 빈 결과 이후 추가 로딩
- 검증 완료 후 결과 문서화·커밋·dev 직접 병합·푸시하고 다음 작업을 갱신한다.

## 제외 범위

- 모집 생성·수정 폼, 필터를 생성값으로 자동 전달
- 신청 중·완료 기록 필터
- 서버 전체 검색·집계·새 인덱스 및 Rules 권한 확대
- 다른 그룹의 비공개 파티 조회
- 실제 가입 가능성 전체 판정(주간 Claim·전투력·역할 등 추가 필터)
- 기존 membership·Claim·assignment·완료 Snapshot 변경, 자동 탈퇴
- 기존 legacy/Rules 보존 파일 정리 또는 삭제

## 구현 시 참고 파일

- `lib/features/recruitment_list/presentation/pages/recruitment_list_page.dart`
- `lib/features/recruitment_list/presentation/viewmodels/public_recruitment_list_view_model.dart`
- `lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart`
- `lib/features/recruitment_list/data/mappers/party_read_document_mapper.dart`
- `lib/features/raid_status/presentation/viewmodels/active_raid_filter_view_model.dart`
- `lib/features/raid_status/presentation/widgets/raid_status_filter_sheet.dart`
- `lib/features/raid_status/domain/services/raid_status_filter.dart`
- `lib/features/raid_status/domain/services/filtered_page_session.dart`
- `lib/features/raid_status/data/repositories/drift_raid_status_filter_store.dart`
