import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {test} from 'node:test';
import {rulesFunction} from './roster_complexity_candidate.mjs';
import {unifyLifecycleTargets} from './rules_lifecycle_targets.mjs';
import {indentRules} from './rules_indent.mjs';

const before = execFileSync('git', ['show', '6e7bd11:firestore.rules'], {encoding:'utf8'});
// Verify P1 independently of later, explicitly scoped localization stages.
const after = indentRules(unifyLifecycleTargets(before));
const tokens = source => source.match(/'(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*"|[^\s]/g);
test('only the three removed and three edited target functions change', () => {
  const changed = new Set(['atomicExpectedTargetStateMatches','atomicExpectedTargetMatches',
    'atomicAllExpectedTargetsMatch','atomicAllTargetsMatch','atomicTargetMatchesTransition',
    'atomicTargetStateMatches']);
  for(const match of before.matchAll(/\bfunction\s+(\w+)\(/g)) {
    if(changed.has(match[1])) continue;
    assert.deepEqual(tokens(rulesFunction(after,match[1]).text),
      tokens(rulesFunction(before,match[1]).text),match[1]);
  }
  assert.deepEqual(tokens(indentRules(unifyLifecycleTargets(before))), tokens(after));
});
test('formatting preserves literals and caps consecutive blank lines', () => {
  assert.deepEqual(tokens(indentRules(before)),tokens(before));
  assert.ok(!/\n(?:[\t ]*\n){2}/.test(after));
});
