import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {readableExecutableRules} from './rules_readable_executable.mjs';
import {compactExecutableRules} from './rules_executable_compact.mjs';
import {indentRules} from './rules_indent.mjs';

test('deployment changes identifiers only across the complete Rules', () => {
  const input = fs.readFileSync('coverage/rules-localization/readable.rules', 'utf8');
  const output = readableExecutableRules(input).source;
  assert.equal(compactExecutableRules(output).source, compactExecutableRules(input).source);
  assert.equal(fs.readFileSync('firestore.rules', 'utf8').replace(/\r\n/g, '\n'), indentRules(output));
  assert.doesNotMatch(output, /\bfunction\s+(?:rf\d+|bug24\w*|de[A-Z]\w*)\s*\(/);
});

test('literal fields, paths and comments are not renamed', () => {
  const input = "function deCurrentOwnership(data) { return data.deCurrentOwnership == 'deCurrentOwnership(' && exists(/deCurrentOwnership/doc); }\n// deCurrentOwnership(\n";
  const output = readableExecutableRules(input).source;
  assert.ok(output.startsWith('function ownershipCurrentOwnership(data)'));
  assert.ok(output.includes("data.deCurrentOwnership == 'deCurrentOwnership('"));
  assert.ok(output.includes('/deCurrentOwnership/doc'));
  assert.ok(output.includes('// deCurrentOwnership('));
});
