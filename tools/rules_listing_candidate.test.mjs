import test from 'node:test';
import assert from 'node:assert/strict';
import { isDeepStrictEqual as equal } from 'node:util';

// Differential model of the old and new changed-slot selection. Membership
// validation is an arbitrary predicate: optimization must preserve its result.
test('changed-slot extraction preserves every required membership check', () => {
  const slots = [
    { playerId: 'a', characterId: 'a1', ownershipRevision: 0 },
    { playerId: 'a', characterId: 'a2', ownershipRevision: 1 },
    { playerId: 'b', characterId: 'b1' },
  ];
  const lists = [[]];
  for (let size = 1; size <= 4; size++) {
    for (let code = 0; code < 3 ** size; code++) {
      let n = code; const list = [];
      for (let i = 0; i < size; i++) { list.push(slots[n % 3]); n = Math.floor(n / 3); }
      lists.push(list);
    }
  }
  lists.push(Array(8).fill(slots[0]), Array(9).fill(slots[0]));
  for (const before of lists) for (const after of lists) for (let mask = 0; mask < 8; mask++) {
    const valid = slot => Boolean(mask & (1 << slots.indexOf(slot)));
    const contains = slot => before.some(old => equal(old, slot));
    const oldResult = equal(before, after) || (after.length <= 8 && after.every(slot => contains(slot) || valid(slot)));
    const changed = after.filter(slot => !contains(slot));
    const newResult = equal(before, after) || (after.length <= 8 && changed.every(valid));
    assert.equal(newResult, oldResult);
  }
});
