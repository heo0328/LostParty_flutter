// Read-only post-processing of the demo Emulator artifact. No Firebase writes.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';

const directory = process.argv[2];
assert.ok(directory, 'Usage: node tools/roster_lifecycle_coverage_summary.mjs <artifact-directory>');
const read = name => JSON.parse(fs.readFileSync(path.join(directory, name), 'utf8'));
const hash = source => createHash('sha256').update(source).digest('hex');
const key = node => JSON.stringify(node.sourcePosition);
function flatten(nodes, result = new Map()) {
  for (const node of nodes) {
    assert.ok(!result.has(key(node)), 'duplicate coverage source position');
    result.set(key(node), node);
    flatten(node.children ?? [], result);
  }
  return result;
}
function valueLabel(value) {
  if ('boolValue' in value) return String(value.boolValue);
  if ('undefined' in value) return 'undefined';
  if (Object.keys(value).length === 0) return 'empty-value';
  return Object.keys(value).join(',');
}
function delta(before, after) {
  const previous = new Map((before?.values ?? []).map(item => [JSON.stringify(item.value), item.count]));
  const result = {};
  for (const item of after.values ?? []) {
    const count = item.count - (previous.get(JSON.stringify(item.value)) ?? 0);
    assert.ok(count >= 0, 'coverage count decreased; cannot subtract snapshots');
    previous.delete(JSON.stringify(item.value));
    if (count) result[valueLabel(item.value)] = (result[valueLabel(item.value)] ?? 0) + count;
  }
  assert.ok([...previous.values()].every(count => count === 0), 'coverage value disappeared');
  return result;
}
const selections = [
  ['recurrence result', 1301, 14],
  ['target transition result', 1369, 14],
  ['target state match result', 1361, 14],
  ['all targets result', 1380, 14],
  ...Array.from({ length: 8 }, (_, i) => [`target ${i} call`, 1385 + i, 12]),
  ['lifecycle result', 1506, 14],
  ['lifecycle actor call', 1507, 12],
  ['lifecycle shape call', 1508, 12],
  ['lifecycle state call', 1509, 12],
  ['lifecycle incomplete shape call', 1510, 12],
  ['lifecycle targets call', 1511, 12],
  ['lifecycle group count call', 1512, 12],
  ['raidState update result', 1575, 7],
  ['membership removal result', 2237, 7],
];
const summary = {
  warning: 'Reported return-value deltas only; not exact budget cost or chronological trace. Zero does not prove not entered. undefined/empty-value are preserved without interpreting them as permission denial.',
  variants: {},
};
for (const variant of ['baseline', 'directFull']) {
  const before = read(`${variant}-before.json`);
  const after = read(`${variant}-after.json`);
  const manifest = read(`${variant}-manifest.json`);
  const source = fs.readFileSync(path.join(directory, `${variant}.rules`), 'utf8');
  assert.equal(before.rules.files.length, 1);
  assert.equal(after.rules.files.length, 1);
  assert.equal(before.rules.files[0].content, source);
  assert.equal(after.rules.files[0].content, source);
  assert.equal(hash(source), manifest.rulesSha256);
  const b = flatten(before.report);
  const a = flatten(after.report);
  const lines = source.split('\n');
  const observations = selections.map(([label, line, column]) => {
    const matches = [...a.values()].filter(node => node.sourcePosition.line === line && node.sourcePosition.column === column);
    matches.sort((left, right) => right.sourcePosition.endOffset - left.sourcePosition.endOffset);
    assert.ok(matches.length, `missing source position ${line}:${column}`);
    const node = matches[0];
    return { label, position: node.sourcePosition, source: lines[line - 1].trim(), values: delta(b.get(key(node)), node) };
  });
  summary.variants[variant] = { manifest, observations };
}
const output = JSON.stringify(summary, null, 2) + '\n';
fs.writeFileSync(path.join(directory, 'summary.json'), output);
for (const [variant, { observations }] of Object.entries(summary.variants)) {
  console.log(variant);
  for (const item of observations) console.log(`${item.label} ${JSON.stringify(item.values)}`);
}
