import { test } from 'node:test';
import assert from 'node:assert/strict';
import { scopeFunctions } from './rules_scope_candidate.mjs';
import { memberRemovalBaseline } from './roster_complexity_candidate.mjs';
import { targetScanCandidate } from './rules_target_scan_candidate.mjs';

test('full rules relocation preserves every function and allow; only lexical scope changes', () => {
  const before = targetScanCandidate(memberRemovalBaseline());
  const result = scopeFunctions(before);
  assert.equal(result.functionCount, 274);
  assert.equal(result.allowCount, 118);
  assert.equal(result.matchCount, 34);
  assert.equal(result.placements.length, 187);
  // The transformer asserts exact body/signature uniqueness and allow equality,
  // and verifies every caller can resolve its callee in an ancestor scope.
});

test('shared callees remain visible to callers across collections', () => {
  const input = `service cloud.firestore { match /databases/{database}/documents {
    function shared() { return true; }
    function onlyA() { return shared(); }
    match /a/{id} { allow read: if onlyA(); }
    match /b/{id} { allow read: if shared(); }
  } }`;
  const result = scopeFunctions(input);
  assert.deepEqual(result.placements.map(p => p.name), ['onlyA']);
});

test('wildcard free identifier capture prevents relocation', () => {
  const result = scopeFunctions(`service cloud.firestore { match /databases/{database}/documents {
    function external() { return id == 'x'; }
    match /a/{id} { allow read: if external(); }
  } }`);
  assert.equal(result.placements.length, 0);
});
