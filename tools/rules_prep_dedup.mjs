import assert from 'node:assert/strict';
import {rulesFunction} from './roster_complexity_candidate.mjs';

export function deduplicatePreparation(source) {
  assert.ok(rulesFunction(source, 'bug24PrepState').text.includes('return hasActiveBinding() &&'));
  for (const name of ['sparkPrepRecords', 'bug24PrepMember']) {
    const fn = rulesFunction(source, name);
    assert.ok(fn.text.includes('&& bug24PrepState('));
    assert.ok(fn.text.includes('return hasActiveBinding() && '));
    source = source.slice(0, fn.start)
      + fn.text.replace('return hasActiveBinding() && ', 'return ')
      + source.slice(fn.end);
  }
  const pair = rulesFunction(source, 'bug24PrepPair');
  const allowed = pair.text.match(/affectedKeys\(\)\.hasOnly\(\[([\s\S]*?)\]\)/)[1];
  assert.ok(!allowed.includes("'playerId'"));
  assert.ok(pair.text.includes('member.playerId == currentPlayerId() && oldMember.playerId == member.playerId'));
  source = source.slice(0, pair.start)
    + pair.text.replace(' && oldMember.playerId == member.playerId', '')
    + source.slice(pair.end);
  return source;
}
