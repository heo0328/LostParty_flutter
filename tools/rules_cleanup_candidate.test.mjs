import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { cleanupCandidate } from './rules_cleanup_candidate.mjs';
import { rulesFunction } from './roster_complexity_candidate.mjs';

const input = fs.readFileSync('coverage/rules-listing/readable.rules', 'utf8').replaceAll('\r\n', '\n');
const output = cleanupCandidate(input);
test('only the three aggregate validators change; member/event/state safeguards remain byte-identical', () => {
  const changed = new Set(['deCleanupAggregate', 'dePeerCleanupAggregate', 'deLeaderCleanupAggregate']);
  for (const [, name] of input.matchAll(/function (\w+)\(/g)) {
    if (!changed.has(name)) assert.equal(rulesFunction(output, name).text, rulesFunction(input, name).text, name);
  }
  for (const name of changed) assert.ok(!output.includes(`function ${name}(`));
});
test('allow expressions retain their order and only replace aggregate calls', () => {
  let restored = output;
  for (const [kind, name] of ['deCleanupAggregate', 'dePeerCleanupAggregate', 'deLeaderCleanupAggregate'].entries()) {
    restored = restored.replace(`r3CleanupAggregate(resource.data, request.resource.data, ${kind})`, `${name}(resource.data, request.resource.data)`);
  }
  const allows = source => [...source.matchAll(/\ballow\s+[\s\S]*?;/g)].map(m => m[0]);
  assert.deepEqual(allows(restored), allows(input));
});
