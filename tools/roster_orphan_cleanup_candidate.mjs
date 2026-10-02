import assert from 'node:assert/strict';
import { personalCompletionCandidate } from './roster_personal_completion_candidate.mjs';

// Demo only: observation/version comparison belongs to the app transaction.
export function orphanCleanupCandidate(source) {
  let rules = personalCompletionCandidate(source);
  for (const [name, data] of [
    ['validLegacyStaleAssignmentDelete', 'data'],
    ['validAtomicStaleRaidStateDelete', 'oldData'],
  ]) {
    const start = rules.indexOf(`    function ${name}(`);
    const end = rules.indexOf('\n    function ', start + 1);
    assert.ok(start >= 0 && end > start, name);
    const before = rules.slice(start, end);
    const after = before.replace('return hasActiveBinding()',
      `return deManualCurrentOwnership(${data}) && hasActiveBinding()`)
      .replace('|| validAtomicStaleRaidStateRecruitment(get(path).data)',
        `|| (get(path).data.raidId == ${data}.raidId
            && validAtomicStaleRaidStateRecruitment(get(path).data))`);
    assert.notEqual(before, after);
    rules = rules.slice(0, start) + after + rules.slice(end);
  }
  return rules;
}
