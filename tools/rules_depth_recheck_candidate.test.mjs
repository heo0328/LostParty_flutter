import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { depthRecheckCandidate } from './rules_depth_recheck_candidate.mjs';
import { rulesFunction } from './roster_complexity_candidate.mjs';
const input = fs.readFileSync('coverage/rules-personal-budget/readable.rules', 'utf8').replaceAll('\r\n', '\n');
const { readable: output } = depthRecheckCandidate(input);
test('B-F1 dispatch and every other guard remain unchanged', () => {
  for (const [, name] of input.matchAll(/function (\w+)\(/g)) {
    if (['personalCompletionCommandMarker', 'personalCompletionTargetsCurrentPlayer'].includes(name)) continue;
    assert.equal(rulesFunction(output, name).text, rulesFunction(input, name).text, name);
  }
  const allows = s => [...s.matchAll(/\ballow\s+[\s\S]*?;/g)].map(m => m[0]);
  assert.deepEqual(allows(output), allows(input));
});
test('marker expression and order including duplicate size guard are preserved', () => {
  const expression = rulesFunction(input, 'personalCompletionCommandMarker').body.trim().slice(7, -1).replace(/\bdata\b/g, 'recruitment');
  assert.equal(rulesFunction(output, 'personalCompletionTargetsCurrentPlayer').text.replace(`(${expression})`, 'personalCompletionCommandMarker(recruitment)'),
    rulesFunction(input, 'personalCompletionTargetsCurrentPlayer').text);
  assert.equal(output.includes('personalCompletionCommandMarker('), false);
});
test('unrecovered A2 and already-transformed inputs cannot be mistaken for B-F1', () => {
  assert.throws(() => depthRecheckCandidate(fs.readFileSync('coverage/rules-listing-safety/readable.rules', 'utf8')));
  assert.throws(() => depthRecheckCandidate(output));
});
