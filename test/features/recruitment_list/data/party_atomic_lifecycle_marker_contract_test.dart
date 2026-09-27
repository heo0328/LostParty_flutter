import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final rules = File('firestore.rules').readAsStringSync();

  test('모든 비lifecycle Aggregate Write Plan이 같은 마커 소진 helper를 쓴다', () {
    for (final path in [
      'lib/features/recruitment_list/data/mappers/party_atomic_membership_write_plan.dart',
      'lib/features/recruitment_list/data/mappers/party_atomic_application_write_plan.dart',
      'lib/features/recruitment_list/data/mappers/party_atomic_member_mutation_write_plan.dart',
      'lib/features/recruitment_list/data/mappers/party_atomic_member_removal_write_plan.dart',
      'lib/features/recruitment_list/data/mappers/party_atomic_visibility_write_plan.dart',
    ]) {
      expect(
        File(path).readAsStringSync(),
        contains('lifecycleMarkerConsumptionPatch(aggregate)'),
        reason: path,
      );
    }
  });

  test('후속 Aggregate validator는 lifecycle 마커를 소진하거나 보존한다', () {
    expect(
      rules,
      contains('function atomicLifecycleMarkerConsumedOrPreserved('),
    );
    for (final validator in [
      'validAtomicPendingApplicationUpdate',
      'validAtomicRecruitmentJoin',
      'validAtomicCharacterRevisionUpdate',
      'validAtomicPositionAggregateUpdate',
      'validAtomicRecruitmentMemberRemoval',
      'validAtomicRecruitmentVisibilityChange',
    ]) {
      final start = rules.indexOf('function $validator(');
      final end = rules.indexOf('\n    }', start);
      expect(start, greaterThanOrEqualTo(0), reason: validator);
      expect(
        rules.substring(start, end),
        contains('atomicLifecycleMarkerConsumedOrPreserved(oldData, newData)'),
        reason: validator,
      );
    }
  });

  test('실제 lifecycle 요청은 membership event와 state 분기를 계속 탈 수 없다', () {
    expect(rules, contains('return !atomicIsLifecycleCommand(recruitment)'));
    expect(rules, contains('&& !atomicIsLifecycleCommand(recruitment)'));
  });
}
