import assert from 'node:assert/strict';
import { prioritizeMemberRemoval, rulesFunction } from './roster_complexity_candidate.mjs';

export function boundRemovalRejections(baseline) {
  let source = prioritizeMemberRemoval(baseline);
  for (const name of ['validAtomicPendingApplicationUpdate', 'validAtomicRecruitmentJoin',
    'validAtomicCharacterRevisionUpdate', 'validAtomicPositionAggregateUpdate',
    'validAtomicRecruitmentMemberRemoval', 'validAtomicRecruitmentVisibilityChange']) {
    assert.ok(rulesFunction(source, name).body.includes('atomicLifecycleMarkerConsumedOrPreserved(oldData, newData)'), name);
  }
  assert.ok(rulesFunction(source, 'atomicValidLifecycleShape').body.includes('newData.lastCommandAt == request.time'));
  const begin = source.indexOf('      allow update:', source.indexOf('    match /recruitments/{recruitmentId}'));
  const end = source.indexOf(';', begin);
  const expression = source.slice(begin, end).replace('      allow update: if ', '');
  const gate = "(!(request.resource.data.get('lastCommandType', '') in ['complete', 'advanceCycle', 'incompleteEnd', 'disband']) || request.resource.data.lastCommandAt == request.time || validRecurrenceChange(resource.data, request.resource.data))";
  for (const name of ['validRecurrenceChange', 'atomicValidLifecycleShape',
    'validAtomicPendingApplicationUpdate', 'validAtomicRecruitmentJoin',
    'validAtomicCharacterRevisionUpdate', 'validAtomicPositionAggregateUpdate',
    'validAtomicRecruitmentMemberRemoval', 'validAtomicRecruitmentVisibilityChange',
    'validPersonalCompletionRecruitmentUpdate', 'validPersonalLastMemberCompletion']) {
    assert.ok(rulesFunction(source, name).body.includes('newData.revision == oldData.revision + 1'), name);
  }
  for (const name of ['deCleanupTransition', 'deLeaderCleanupTransition', 'dePeerCleanupTransition']) {
    assert.ok(rulesFunction(source, name).body.includes('before.revision + 1 == after.revision'), name);
  }
  source = source.slice(0, begin) + `      allow update: if request.resource.data.revision == resource.data.revision + 1 && ${gate} && (${expression})` + source.slice(end);
  const f = rulesFunction(source, 'validAtomicMemberRemovalListingUpdate');
  const heavy = `&& validAtomicRecruitmentMemberRemoval(
          recruitmentBefore,
          recruitmentAfter
        )`;
  const cheap = `&& newData.memberCount == recruitmentAfter.memberCount
        && newData.sourceRevision == recruitmentAfter.revision
        && newData.updatedAt == request.time`;
  assert.ok(f.text.includes(`${heavy}\n        ${cheap}`));
  return source.replace(f.text, f.text.replace(`${heavy}\n        ${cheap}`, `${cheap}\n        ${heavy}`));
}
