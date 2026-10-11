import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { personalBudgetCandidate, personalBranch } from './rules_personal_budget_candidate.mjs';
import { rulesFunction } from './roster_complexity_candidate.mjs';
const input = fs.readFileSync('coverage/rules-listing-safety/readable.rules', 'utf8').replaceAll('\r\n', '\n');
const output = personalBudgetCandidate(input);
test('every validator including ownership, event, listing and cleanup guards is unchanged', () => {
  for (const [, name] of input.matchAll(/function (\w+)\(/g))
    assert.equal(rulesFunction(output, name).text, rulesFunction(input, name).text, name);
});
test('only recruitment update moves the exact personal branch; fallback and time guard are preserved', () => {
  const allows = s => [...s.matchAll(/\ballow\s+[\s\S]*?;/g)].map(m => m[0]);
  const before = allows(input), after = allows(output);
  assert.equal(before.length, after.length);
  let changed = 0;
  before.forEach((value, index) => {
    if (value === after[index]) return;
    changed++;
    assert.ok(after[index].startsWith('allow update: if ' + personalBranch));
    assert.equal(after[index].slice(('allow update: if ' + personalBranch).length, -2),
      value.slice('allow update: if '.length, -1).replace(personalBranch, '('));
  });
  assert.equal(changed, 1);
  assert.equal(output.split(personalBranch).length, 2);
  assert.throws(() => personalBudgetCandidate(output));
});
