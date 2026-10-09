import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { depthCandidate } from './rules_depth_candidate.mjs';
import { rulesFunction } from './roster_complexity_candidate.mjs';
const input = fs.readFileSync('coverage/rules-listing-safety/readable.rules', 'utf8').replaceAll('\r\n', '\n');
const output = depthCandidate(input);
test('only marker and its sole caller change; all guards including close-body remain identical', () => {
  for (const [, name] of input.matchAll(/function (\w+)\(/g)) {
    if (['personalCompletionCommandMarker', 'personalCompletionTargetsCurrentPlayer'].includes(name)) continue;
    assert.equal(rulesFunction(output, name).text, rulesFunction(input, name).text, name);
  }
  const allows = s => [...s.matchAll(/\ballow\s+[\s\S]*?;/g)].map(m => m[0]);
  assert.deepEqual(allows(output), allows(input));
});
test('restoring the inlined predicate exactly recovers the prior caller', () => {
  const expression = rulesFunction(input, 'personalCompletionCommandMarker').body.trim().slice(7, -1).replace(/\bdata\b/g, 'recruitment');
  assert.equal(rulesFunction(output, 'personalCompletionTargetsCurrentPlayer').text.replace(`(${expression})`, 'personalCompletionCommandMarker(recruitment)'),
    rulesFunction(input, 'personalCompletionTargetsCurrentPlayer').text);
  assert.equal(output.includes('personalCompletionCommandMarker('), false);
});
