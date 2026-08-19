# AI CONTEXT (2026)

## 프로젝트
- LOSTPARTY
- Flutter 기반 로스트아크 레이드 모집 앱
- AI 기반 개발 (ChatGPT + Cursor)

---

## 아키텍처
- MVVM
- feature-first 구조
- repository pattern
- local → firebase 전환 고려

---

## 현재 브랜치
- feature/recruitment-list-ui

---

## 완료 상태

### 구조
- 폴더 구조 생성 완료
- feature-first 구조 적용
- domain / data / presentation 분리 완료

### 레이드 데이터
- raid_base.dart 구현 완료
- raid_variation.dart 구현 완료
- local_raid_data_source.dart 구현 완료
- raid_master_repository.dart 구현 완료
- raid_master_repository_impl.dart 구현 완료

### 모집글 도메인
- party_recruitment.dart 구현 완료
- PartyRole / RecruitmentStatusType / ExperienceLevel enum 정의 완료

### recruitment_list 데이터 레이어
- recruitment_list_repository.dart 구현 완료
- local_recruitment_list_data_source.dart 구현 완료
- recruitment_list_repository_impl.dart 구현 완료
- mock 모집글 데이터 6개 작성 완료

### recruitment_list presentation layer
- recruitment_list_view_model.dart 구현 완료
- recruitment_list_page.dart 구현 완료
- recruitment_card.dart 구현 완료
- main.dart에서 RecruitmentListPage 연결 완료
- mock 모집글 6개 화면 표시 완료

### 테스트
- local_recruitment_list_data_source_test.dart 작성 및 통과
- recruitment_list_repository_impl_test.dart 작성 및 통과
- flutter analyze 이후 테스트 정상 동작 확인
- widget_test.dart를 모집글 목록 표시 테스트로 수정 완료
- flutter analyze 통과
- flutter test 12개 통과

---

## 데이터 구조 핵심

### RaidBase
- raidBaseId
- name
- partySize
- gateCount
- difficultyIds

### RaidVariation
- raidId
- raidBaseId
- difficultyOrder
- difficultyLabel
- minItemLevel
- rewardGold

### PartyRecruitment
- id
- title
- raid (raidId + gateProgress)
- leader (characterName / className / role)
- memberSummary (currentCount / maxCount)
- recruitmentStatus
  - status (recruiting / closed / completed)
  - roles
    - dealer (current / target / remaining)
    - support (current / target / remaining)
- requirements
  - minCombatPower
  - experienceLevel (5단계)
- schedule
  - raidStartAt
  - maxPlayHours (null = 클리어시)
  - recruitmentOpenedAt
  - recruitmentClosedAt

---

## enum

### PartyRole
- dealer
- support

### RecruitmentStatusType
- recruiting
- closed
- completed

### ExperienceLevel
- tryLevel
- clearExp
- multiClearExp
- semiExperienced
- experienced

---

## 레이드 데이터 관리 방식
- 현재: local hardcoding
- repository 통해 접근
- UI는 데이터 소스 모름
- 추후 Firebase 교체 가능 구조

---

## 현재 상태 요약

- recruitment_list 기준 Domain / Data / Presentation Layer 1차 구현 완료
- main.dart에서 RecruitmentListPage 실행
- mock 모집글 6개가 RecruitmentCard 목록으로 표시됨
- UI는 ViewModel을 통해 데이터 조회
- ViewModel은 Repository를 통해 mock 데이터 조회
- Firebase 연동은 아직 없음
- flutter analyze 통과
- flutter test 12개 통과

---

## 다음 작업

1. AI_CONTEXT.md / DEV_LOG.md 기준으로 작업 상태 유지
2. 모집글 mock 데이터와 raid master 데이터의 raidId 정합성 확인
3. RecruitmentCard 표시 문구와 도메인 용어 정리
4. MVP 범위 내 다음 화면 결정
   - 모집글 상세
   - 모집글 작성
   - 모집글 지원

---

## 주의 사항

- UI에서 DataSource 직접 접근 금지 (Repository만 사용)
- entity에 json/serialization 로직 아직 추가하지 않음
- repository에 비즈니스 로직 추가 아직 하지 않음
