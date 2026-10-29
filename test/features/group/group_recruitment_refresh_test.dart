import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/group/data/backend/group_repository.dart';
import 'package:lost_party/features/recruitment_list/domain/backend_recruitment.dart';
import 'package:lost_party/features/recruitment_list/presentation/viewmodels/cycle_search_view_model.dart';
import '../recruitment_list/backend_recruitment_test.dart' as old;
import '../recruitment_list/cycle_recruitment_test.dart' as cycle;
import '../recruitment_list/cycle_interaction_test.dart' as f;
import '../recruitment_list/group_character_candidates_test.dart' as candidates;
import '../account/backend_read/member_cycles_test.dart' as clock;
import '../../support/server_account_read_fakes.dart';

class GroupSource extends cycle.CycleGateway {
  List<RecruitmentGroupChoice> choices = [
    const RecruitmentGroupChoice(old.groupId, '지인'),
  ];
  @override
  Future<List<RecruitmentGroupChoice>> groups() async => choices;
}

void main() {
  test(
    'membership mutation refreshes alias/characters while preserving independent filters',
    () async {
      final source = GroupSource(),
          api = old.Api(),
          session = ReadSessionFake(),
          changes = ChangeNotifier(),
          groups = GroupChanges();
      var currentRef = candidates.memberRef,
          currentCharacter = candidates.char1,
          reads = 0;
      api.respond = (path, q) async {
        if (path.endsWith('filter-context')) {
          reads++;
          return candidates.contextWire(ref: currentRef);
        }
        if (path.endsWith('character-candidates')) {
          return candidates.pageWire(
            ref: currentRef,
            characters: [candidates.character(currentCharacter, '1770.00')],
          );
        }
        if (path.endsWith('/search')) {
          return f.searchWire(
            (api.requests.last['body'] as Map)['target_cycle_key'],
          );
        }
        throw StateError(path);
      };
      final model = CycleSearchViewModel(
        gateway: f.TestGateway(api, source),
        session: session,
        changes: changes,
        groupChanges: groups,
        scopeKey: () => '${session.userId}/${session.generation}',
      );
      addTearDown(() {
        model.dispose();
        groups.dispose();
        changes.dispose();
        session.dispose();
      });
      await model.load();
      await model.loadGroups();
      await model.selectGroup(old.groupId);
      model.selectCharacter(currentRef, currentCharacter);
      await clock.settled(() => !model.loading);
      final target = model.target, category = model.filter.category;
      currentRef = 'f' * 64;
      currentCharacter = candidates.char2;
      groups.applied();
      await clock.settled(
        () =>
            reads >= 2 &&
            !model.loading &&
            !model.groupLoading &&
            !model.candidateLoading,
      );
      expect(model.target, target);
      expect(model.filter.category, category);
      expect(model.filter.groupId, old.groupId);
      expect(model.filter.members, isEmpty);
      expect(model.candidateMembers.single.ref, currentRef);
      expect(
        model.candidateMembers.single.characters.single.id,
        currentCharacter,
      );
      source.choices = [];
      groups.applied();
      await clock.settled(() => !model.loading && model.groups.isEmpty);
      expect(model.filter.groupIds, isEmpty);
      expect(model.target, target);
    },
  );
}
