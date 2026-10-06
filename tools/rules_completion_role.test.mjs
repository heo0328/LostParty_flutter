import fs from 'node:fs';
import assert from 'node:assert/strict';
import test from 'node:test';

test('completion compatibility keeps ownership and limits role changes to complete', () => {
  // Run integrate_roster_rules.mjs --check --review before this contract.
  const result = fs.readFileSync(new URL('../coverage/rules-executable/review/readable.rules', import.meta.url), 'utf8');
  const start = result.indexOf('    function validAtomicRaidStateUpdate(');
  const end = result.indexOf('    function validAtomicRaidStateDelete(', start);
  const body = result.slice(start, end);
  assert.ok(body.includes("!('role' in oldData) || oldData.role == newData.role"));
  assert.ok(body.includes('atomicAdvanceStateMatchesSlot(recruitment, newData)'));
  assert.ok(body.includes('oldData.cycleKey == recruitment.currentCycleKey'));
  assert.ok(body.includes("!newData.diff(oldData).affectedKeys().hasAny(['role'])"));
  assert.ok(body.includes('deCurrentOwnership(oldData)'));
  assert.ok(body.includes('newData.revision == oldData.revision + 1'));
  assert.ok(body.includes("oldData.status == 'active'"));
});
