# NEXT WORK

## 문서의 역할

이 문서는 다음 구현 작업의 단일 인수인계 기준이다. 누적 이력은 `DEV_LOG.md`, 전체 제품 규칙은 `AI_CONTEXT.md`와 architecture/product 문서를 사용한다. 작업 시작 시 실제 `git status`, `git log -3`과 대조한다.

## 현재 기준 상태

- 통합 대상: 최신 `main`
- 작업 브랜치: `cursor/public-recruitment-list`
- Task-050~054의 Firestore 명령·Rules·Snapshot·Player 이벤트·Drift 로컬 히스토리 기반 구현을 완료했다.
- Task-056~060에서 레이드 현황 읽기·목록 UX·읽기 전용 상세·모집 생성·인증 캐릭터 최소 정보 동기화를 완료했다.
- Task-061 신청·철회 명령의 실행 앱 연결을 완료했다.
  - `/raid-status/:id` 읽기 전용 상세에 `FirestorePartyApplicationCommandRepository`를 연결했다.
  - 신청 Character는 인증된 `serverCharacterId`만 사용하며, 후보 선택은 `RecruitmentLeaderCandidateService`를 재사용한다.
  - 본인 pending 신청은 `revision`으로 철회하고, 요청 중 버튼을 비활성한다.
  - Fake `/recruitments/:id` 상세 UI는 그대로 두며 데이터를 섞지 않는다.
  - 단일 Android 기기(Player 1개)라 타 계정 신청·철회 실기기 확인은 보류했다. 표적 테스트로 검증했다.
- Task-062에서 LostParty Design System v1의 Theme·token·Bottom Navigation과 공개 모집 대표 Card 시범 적용을 완료하고 사용자 디자인 확인을 통과했다.
- `레이드 모집` 탭 공개 목록은 여전히 `InMemoryRecruitmentStateRepository` Fake다. `watchPublicRecruitments`는 Repository에 있으나 UI에 미연결이다.
- 승인·즉시 가입·멤버·회차는 Fake 경로를 유지한다.
- Firestore Emulator, FCM, TTL 배포와 유료 서비스 호출은 수행하지 않았다.

## 확정된 협업 역할

- Codex는 설계·계약·작업 분해·문서 정합성·인수인계를 중심으로 담당한다.
- Cursor는 주 코드 구현·빌드·표적 테스트를 중심으로 담당한다.
- 디자인 시스템의 설계·구현·시범 적용과 사용자 피드백 반영은 Codex가 담당한다. Cursor는 확정된 디자인 기준을 후속 기능 화면에 적용한다.
- Codex의 코드 수정과 Cursor의 설계 제안을 금지하지 않는다.
- 구현 중 계약 변경이 필요하면 Cursor가 임의 확장하지 않고 영향과 제안을 문서에 먼저 기록한다.
- 완료 시 코드, 테스트, 문서와 실제 Git 상태를 함께 갱신한다.

## 다음 작업 설계 대상: 레이드 모집 공개 목록 Firestore 페이징 읽기 전환

신청·철회는 현황 상세에 연결됐지만, 공개 모집을 고르려면 `레이드 모집` 탭이 서버 목록을 보여야 한다. 현재는 Fake 시드만 쓰므로 재설치·다른 Player에서는 서버에 있는 방이 보이지 않는다.

### 설계 시 고정된 런타임 사실

- `FirestorePartyReadRepository.watchPublicRecruitments(cycleKey:)`가 이미 있다.
- 공개 목록 필터는 `visibility == public`, `status == active`, `manualRecruitmentEnabled`, `hasAvailableSlot`, `targetCycleKey == cycleKey`다.
- 카드 탭 시 `/raid-status/{id}` Firestore 현황 상세로 들어가면 신청·철회가 가능하다.
- Fake `/recruitments/:id` 상세와 데이터를 섞지 않는다.
- 모집 생성은 이미 Firestore이며 성공 시 현황 상세로 이동한다.
- 공개 목록 쿼리에 필요한 복합 인덱스와 공개 `list` Rules는 저장소에 이미 있다. 실제 Firebase 프로젝트의 배포 상태는 실기기 조회로 최종 확인한다.

### 목표

`레이드 모집` 탭에서 현재 주차 공개·모집 중 방을 최신순으로 표시한다. 최초 20개만 실시간 구독하고 이후 항목은 20개씩 cursor 기반으로 불러와 제한 없는 전체 snapshot 구독을 피한다. 선택 시 신청·철회가 연결된 Firestore 현황 상세로 진입한다.

### 확정된 페이징 계약

- 페이지 크기는 20개다.
- 첫 페이지는 `updatedAt desc`, 문서 ID desc의 안정 정렬과 `limit(20)`으로 실시간 구독한다.
- 다음 페이지는 마지막 문서 cursor 뒤에서 같은 필터·정렬로 20개를 일회성 조회한다. 모든 로드된 페이지를 별도 실시간 listener로 유지하지 않는다.
- Firestore `DocumentSnapshot`은 Domain과 presentation에 노출하지 않는다. Repository가 해석하는 불투명 cursor를 페이지 결과로 전달한다.
- ViewModel은 `recruitmentId`로 첫 페이지와 추가 페이지를 병합해 중복을 제거한다. 같은 ID는 최신 첫 페이지 snapshot을 우선한다.
- 추가 페이지 결과가 20개보다 적거나 다음 cursor가 없으면 마지막 페이지로 판단한다.
- 추가 조회 중에는 같은 요청을 무시하고, 네트워크 요청을 시작하는 UI 동작을 비활성해 중복 호출을 막는다.
- 첫 페이지 항목의 내용만 바뀌고 ID 집합이 같으면 추가 페이지를 유지하고 ID로 다시 병합한다.
- 새 모집 유입·필터 제외 등으로 첫 페이지의 ID 집합이 바뀌면 사라진 이유를 클라이언트가 안전하게 구분할 수 없으므로 추가 페이지·cursor·추가 오류를 초기화한다. 사용자가 계속 내리면 바뀐 첫 페이지 경계에서 다시 불러온다.
- 사용자가 명시적으로 새로고침하면 첫 페이지 listener와 추가 페이지·cursor·오류 상태를 모두 초기화한다.

### 우선 확인 파일

- `lib/features/recruitment_list/presentation/pages/recruitment_list_page.dart`
- `lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart`
- `lib/app/router/app_router.dart`
- `docs/architecture/FIRESTORE_PARTY_READ_MODEL_CONTRACT.md`
- `docs/architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md` §9

### 포함 범위

1. 공개 목록 Repository 경계를 첫 페이지 실시간 구독과 다음 페이지 cursor 조회로 확장한다. 기존 제한 없는 `watchPublicRecruitments`를 실행 앱 UI에서 사용하지 않는다.
2. `RecruitmentListPage`에 `PartyReadRepository`와 현재 `cycleKey`를 주입한다. InMemory Fake 목록은 실행 앱 공개 목록 경로에서만 제거하고 Fake 상세·생성 회귀 경계는 유지한다.
3. 최초 loading·빈 목록·캐시·오류와 추가 loading·마지막 페이지·추가 오류·재시도를 구분한다.
4. 기존 `LocalRecruitmentCard`의 제목, 레이드·난이도·관문, 인원, 전투력과 숙련도 표시는 재사용한다. 이번 작업에서 카드 대규모 UI 개편은 하지 않는다.
5. 카드 선택 시 `/raid-status/{recruitmentId}`로 이동한다. Fake 상세로 보내지 않으며 레이드 현황 branch 전환과 뒤로가기 복귀를 표적 테스트한다.
6. 모집 생성 진입과 생성 성공 후 `/raid-status/{recruitmentId}` 이동은 유지한다. 목록 복귀 시 Fake reload는 하지 않고 stream 또는 명시적 새로고침을 사용한다.
7. 저장소에 있는 Rules와 인덱스가 실제 쿼리 순서와 일치하는지 확인하고, 실제 배포 누락은 실기기 오류로 최종 확인한다.

### 상태 표시 계약

- 첫 snapshot 전에는 중앙 loading을 표시한다.
- 첫 snapshot이 비어 있으면 빈 목록을 표시하며, 캐시 snapshot이면 빈 상태 위에도 오프라인 안내를 표시한다.
- 첫 페이지 캐시 데이터는 정상 목록으로 표시하고 오프라인 안내를 함께 표시한다.
- 첫 성공 데이터가 없는 상태의 오류는 전체 오류 화면과 재시도를 제공한다.
- 기존 데이터가 있는 상태의 첫 페이지 후속 오류는 목록을 유지하고 인라인 오류를 표시한다.
- 다음 페이지 조회 중에는 목록 하단 loading을 표시한다.
- 다음 페이지 조회 실패는 기존 목록을 유지하고 하단 오류와 재시도를 표시한다.
- 마지막 페이지에서는 추가 요청과 하단 loading을 중단한다.
- 명시적 새로고침은 첫 페이지와 추가 페이지 상태를 모두 초기화한다.

### 제외 범위

- FCM과 OS 알림 권한
- Firestore TTL 정책 배포
- Cloud Functions, Blaze 전환과 결제수단 연결
- Firestore Emulator 실행
- 승인·즉시 가입·멤버·회차 명령 전환
- Fake 상세 UI 전면 제거(경로만 분리 유지 가능)
- 철회 후 재신청 Transaction
- 대규모 UI 개편

### 완료 조건

- 서버에 있는 현재 주차 공개 모집이 최신순으로 `레이드 모집` 탭에 나타난다.
- 최초 조회는 20개를 넘지 않고, 하단 도달 시 다음 20개를 중복 요청 없이 불러온다.
- 같은 모집이 페이지 사이에 중복 표시되지 않고 추가 조회 실패 시 기존 목록이 유지된다.
- 첫 페이지의 추가·변경·제거가 실시간 반영되고 ID 경계 변경 시 추가 페이지가 초기화되어 오래된 복사본이 다시 나타나지 않는다.
- 카드에서 Firestore 현황 상세로 들어가 신청 흐름이 이어지고, 뒤로가기로 모집 목록과 스크롤 위치에 복귀한다.
- loading·빈 목록·캐시·첫 페이지 오류·추가 loading·추가 오류·마지막 페이지의 표적 ViewModel/Widget 테스트가 통과한다.
- `flutter analyze --no-pub`와 변경 범위 표적 테스트가 통과한다.
- Android 실기기에서 공개 목록 첫 페이지·추가 로드·상세 진입을 확인하고, 배포된 인덱스 누락 오류가 없는지 확인한다.
- 남은 Fake 범위와 다음 전환 단위를 문서에 기록한다.

## 후속 순서

1. 레이드 모집 공개 목록 Firestore 읽기 전환
2. 즉시 가입·승인·거절
3. 멤버·회차 명령
4. 캐릭터 이동·스왑 예상 결과와 다중 파티 Transaction 설계
5. 그룹과 그룹 전용 모집

## 지속 운영 제약

- 별도 지시 전까지 외부 서비스의 유료 플랜·결제수단·초과 과금 가능 기능을 사용하지 않는다.
- Emulator Suite는 사용하지 않는다. 필요하면 목적·발견할 실패·종료 조건을 제시하고 명시적 승인을 받는다.
- 실기기 흐름을 대신하기 위한 무의미한 전체 테스트 반복을 하지 않는다.
- AuthUid, API 토큰과 민감한 식별자를 UI·로그·문서 예시에 노출하지 않는다.
- Android Drift(`sqlite3` native assets) 빌드 산출물을 임의로 삭제하지 않는다. 정리 후엔 전체 재설치(`flutter run`)가 필요하다.
- Lost Ark API·Firestore 등 네트워크 요청을 시작하는 버튼은 요청 진행 중 비활성 또는 동일 동작 무시로 연타·중복 요청을 막는다. 화면마다 예외를 두지 않는 공통 UI 규칙이다.

## 참고 문서

- `AI_CONTEXT.md`
- `DEV_LOG.md`
- `ai_rules.md`
- `../architecture/FIREBASE_PARTY_PRODUCT_FLOW.md`
- `../architecture/FIRESTORE_PARTY_READ_MODEL_CONTRACT.md`
- `../architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md`
- `../architecture/FIRESTORE_PARTY_EVENT_CONTRACT.md`
- `../architecture/GAME_ACCOUNT_CHARACTER_FIREBASE_CONTRACT.md`
- `../architecture/GAME_ACCOUNT_VERIFICATION_CONTRACT.md`
- `../product/PARTY_PARTICIPATION_RULES.md`
