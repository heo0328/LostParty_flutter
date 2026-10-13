import fs from 'node:fs';
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {test} from 'node:test';
import {rulesFunction} from './roster_complexity_candidate.mjs';
import {unifyLifecycleTargets} from './rules_lifecycle_targets.mjs';
import {localizeGroupNames} from './rules_group_name_local.mjs';
import {indentRules} from './rules_indent.mjs';

const before = indentRules(unifyLifecycleTargets(
  execFileSync('git', ['show', '6e7bd11:firestore.rules'], {encoding: 'utf8'})));
const after = fs.readFileSync('firestore.rules', 'utf8');
const tokens = source => source.match(/'(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*"|[^\s]/g);

test('remove name quality helpers and their calls; preserve every other helper and allow', () => {
  assert.deepEqual(tokens(indentRules(localizeGroupNames(before))), tokens(after));
  const changed = new Set(['validInitialGroup', 'validGroupDisplayName', 'validGroupSearchProjection']);
  for (const [, name] of before.matchAll(/\bfunction\s+(\w+)\(/g)) {
    if (!changed.has(name)) assert.deepEqual(tokens(rulesFunction(after, name).text),
      tokens(rulesFunction(before, name).text), name);
  }
  const allows = source => [...source.matchAll(/allow\s[^:]+:[\s\S]*?;/g)].map(m => tokens(m[0]));
  assert.deepEqual(allows(after), allows(before));
  assert.ok(!/validGroupDisplayName|validGroupSearchProjection/.test(after));
  assert.equal([...before.matchAll(/\bfunction\s/g)].length - [...after.matchAll(/\bfunction\s/g)].length, 2);
});
