import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { leaderBudgetCandidate } from './rules_leader_budget_candidate.mjs';
import { rulesFunction } from './roster_complexity_candidate.mjs';
const input = fs.readFileSync('coverage/rules-listing/readable.rules', 'utf8').replaceAll('\r\n', '\n');
const output = leaderBudgetCandidate(input);
const added = '        && after.partySlots.size() <= 8\n'
  + '        && exists(/databases/$(database)/documents/recruitments/$(before.recruitmentId)/members/$(target.playerId))\n';
test('only leader aggregate gains bounded slots and mandatory member delete; all other functions identical', () => {
  for (const [, name] of input.matchAll(/function (\w+)\(/g)) {
    const next = rulesFunction(output, name).text;
    assert.equal(name === 'deLeaderCleanupAggregate' ? next.replace(added, '') : next, rulesFunction(input, name).text, name);
  }
  assert.ok(output.includes(added));
});
test('only source update dispatch changes; nonleader and stale-marker fallback is exactly preserved', () => {
  const prefix = "(request.resource.data.get('lastCommandType', '') == 'cleanupCompletedLeaderOwnership' && request.resource.data.lastCommandAt == request.time) ? (deLeaderCleanupAggregate(resource.data, request.resource.data)) : (";
  const old = "(request.resource.data.get('lastCommandType', '') == 'cleanupCompletedLeaderOwnership' && deLeaderCleanupAggregate(resource.data, request.resource.data)) || ";
  const allows = source => [...source.matchAll(/\ballow\s+[\s\S]*?;/g)].map(m => m[0]);
  const before = allows(input), after = allows(output);
  assert.equal(before.length, after.length);
  let changed = 0;
  before.forEach((value, index) => {
    if (value === after[index]) return;
    changed++;
    assert.ok(after[index].startsWith('allow update: if ' + prefix));
    assert.equal(after[index].slice(('allow update: if ' + prefix).length, -2),
      value.replace(old, '').slice('allow update: if '.length, -1));
  });
  assert.equal(changed, 1);
});
