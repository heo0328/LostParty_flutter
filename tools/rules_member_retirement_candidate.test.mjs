import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { memberRetirementCandidate, retiredFunctions } from './rules_member_retirement_candidate.mjs';
import { rulesFunction } from './roster_complexity_candidate.mjs';
const input = fs.readFileSync('coverage/rules-depth-recheck/readable.rules', 'utf8');
const { readable: output } = memberRetirementCandidate(input);
test('all remaining validators including legacy consumption and preparation are byte-identical', () => {
  for (const [, name] of input.matchAll(/function (\w+)\(/g)) {
    if (retiredFunctions.includes(name)) {
      assert.equal(new RegExp(`\\b${name}\\s*\\(`).test(output), false);
    } else assert.equal(rulesFunction(output, name).text, rulesFunction(input, name).text, name);
  }
});
test('the sole permission change closes the old member alternative', () => {
  const allows = s => [...s.matchAll(/\ballow\s+[\s\S]*?;/g)].map(m => m[0]);
  const before = allows(input), after = allows(output);
  assert.equal(before.length, after.length);
  const changes = before.flatMap((text, i) => text === after[i] ? [] : [i]);
  assert.equal(changes.length, 1);
  const i = changes[0];
  assert.equal(after[i], before[i].replace(/validMemberCharacterChange\(\s*recruitmentId,\s*playerId,\s*resource\.data,\s*request\.resource\.data\s*\)/, 'false'));
});
test('wrong or already retired baselines are rejected', () => {
  assert.throws(() => memberRetirementCandidate(output));
  assert.throws(() => memberRetirementCandidate(input.replace('validMemberCharacterChange', 'unexpected')));
});
