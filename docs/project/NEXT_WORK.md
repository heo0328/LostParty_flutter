# NEXT WORK

## 현재 우선 작업 — 사용자 다음 지정 대기

현재 단계: **B + 그룹 전용 모집 목록 실기기 확인 완료**. 브랜치 `codex/recruitment-group-link`. 다음 기능은 사용자 지정을 기다린다. 커밋·푸시·main 머지는 지시 후에만 한다.

- 그룹 레이드 생성(일반/그룹, 가입 그룹 하나, `그룹만 공개` 기본값)과 그룹원 레이드 모집 리스트 노출이 동작한다.
- 그룹만 공개는 `groups/{groupId}/raidListings/{recruitmentId}` Projection으로 모집 리스트에 합친다. `recruitments` list에 그룹 membership `exists`나 `visibility==group` 쿼리를 쓰지 않는다.
- 책임자·확정 멤버 본인 방은 모집 리스트에서 제외하고 레이드 현황에서 본다.

후속(지정 전까지 구현하지 않음): 생성 후 그룹만 공개↔전체 공개 전환, listing 스냅샷을 자리·상태 변경에 맞춰 갱신, listing 없는 기존 방 보완, 탈퇴 시 그룹 전용 자격 박탈, 목록 필터 UI(§8).

## 보존 지점

- 기존 보존 브랜치 codex/rules-complexity-reduction / ed02b31 및 Rules 사본 2개는 유지한다.
- 그룹 전투력 수정 4e4ab37 / 통합 eeba05f, 모집 UI 준비 문서 15eaf4a.
- 실제 시작 전에 git status·브랜치·HEAD를 확인하고 다른 미커밋 변경을 보존한다.
