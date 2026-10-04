import test from 'node:test';
import assert from 'node:assert/strict';
import { compactExecutableRules } from './rules_executable_compact.mjs';

test('rename bindings and calls without changing fields, strings or paths', () => {
  const input = `rules_version = '2';
service cloud.firestore {
match /databases/{database}/documents {
function lookup(characterId) {
let snapshot = get(/databases/$(database)/documents/characters/$(characterId));
return snapshot.data.characterId == characterId && snapshot.data.label == 'characterId';
}
match /characters/{characterId} { allow read: if lookup(characterId); }
}}
`;
  const result = compactExecutableRules(input);
  assert.match(result.source, /function rf0\(z0\)/);
  assert.match(result.source, /z1\.data\.characterId == z0/);
  assert.ok(result.source.includes("== 'characterId'"));
  assert.ok(result.source.includes('/databases/$(database)/documents/characters/$(z0)'));
  assert.ok(result.source.includes('match /characters/{characterId} { allow read: if rf0(characterId); }'));
});

test('ambiguous path segments and map keys remain unchanged', () => {
  const result = compactExecutableRules(`function sample(users, value) {
return get(/users/$(users)).data == {value: value};
}`);
  assert.equal(result.renamedBindings, 0);
  assert.ok(result.source.includes('/users/$(users)'));
  assert.ok(result.source.includes('{value: value}'));
});

test('reject names that could capture an existing identifier', () => {
  assert.throws(() => compactExecutableRules('function sample(input) { return input == z0; }'), /collision/);
  assert.throws(() => compactExecutableRules('function sample(input) { return input == rf0; }'), /collision/);
});

test('distinct function scopes receive distinct bindings', () => {
  const result = compactExecutableRules('function first(value) { return value; }\nfunction second(value) { return first(value); }');
  assert.ok(result.source.includes('function rf0(z0) { return z0; }'));
  assert.ok(result.source.includes('function rf1(z1) { return rf0(z1); }'));
});
