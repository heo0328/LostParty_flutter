import fs from 'node:fs';
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { removeRepeatedPersonalCompletion, rulesFunction } from './roster_complexity_candidate.mjs';
const before = fs.readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8').replace(/\r\n/g, '\n');
const after = removeRepeatedPersonalCompletion(before);
test('only three personal completion fallback branches change; every helper is preserved', () => {
  for (const [, name] of before.matchAll(/    function (\w+)\(/g))
    assert.equal(rulesFunction(after, name).text, rulesFunction(before, name).text);
  const allows = s => [...s.matchAll(/allow\s[\s\S]*?;/g)].map(m => m[0]);
  const a = allows(before), b = allows(after);
  assert.equal(a.length, b.length);
  assert.equal(a.filter((v, i) => v !== b[i]).length, 3);
  for (const name of ['validPersonalCompletionRecruitmentUpdate', 'validPersonalCompletionMemberDelete', 'validPersonalCompletionListingUpdate']) {
    const block = b.find(v => v.includes(name + '('));
    assert.ok(block.includes("personalComplete") || block.includes('dePersonalCommand(recruitmentId)'));
    assert.equal(block.split(name + '(').length, 2);
  }
});
test('changed dispatch implication fails closed', () => {
  assert.throws(() => removeRepeatedPersonalCompletion(before.replace('recruitment.lastCommandAt == request.time', 'true')));
});
