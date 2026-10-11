// Static user-function call graph only; no compiler, Rules output or network.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { compactExecutableRules } from './rules_executable_compact.mjs';

const inputs = process.argv.length > 2 ? [['selected', process.argv[2], process.argv[3]]] : [
  ['tracked', 'coverage/rules-executable/review/readable.rules', '408f163fc6bf6f06d8a7a628da2e1b2bdd2747d36936d7b2aee995c161e53793'],
  ['R1', 'coverage/rules-listing/readable.rules', '17471d0f4bff19595c90ddb43c28766cbf976d77ba9d0adc0736ff59f4a93667'],
  ['rejected-R3', 'coverage/rules-cleanup/readable.rules', '87edb51493004c826ea57deb110edbb8faaf07a6543cbcb9cec82620ea2a1097'],
];
for (const [label, file, sha] of inputs) {
  const source = fs.readFileSync(file, 'utf8');
  assert.equal(createHash('sha256').update(compactExecutableRules(source).source).digest('hex'), sha);
  const masked = source.replace(/'(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*"|\/\/[^\n]*|\/\*[\s\S]*?\*\//g,
    s => s.replace(/[^\n]/g, ' '));
  const functions = [...masked.matchAll(/\bfunction\s+(\w+)\s*\(/g)].map(m => {
    const open = masked.indexOf('{', m.index);
    let end = open + 1, depth = 1;
    while (depth && end < masked.length) {
      if (masked[end] === '{') depth++;
      if (masked[end] === '}') depth--;
      end++;
    }
    assert.equal(depth, 0);
    return { name: m[1], body: masked.slice(open + 1, end - 1),
      line: source.slice(0, m.index).split('\n').length };
  });
  const byName = new Map(functions.map(f => [f.name, f]));
  assert.equal(byName.size, functions.length);
  const calls = text => [...text.matchAll(/\b(\w+)\s*\(/g)].map(m => m[1]).filter(n => byName.has(n));
  for (const f of functions) f.calls = calls(f.body);
  const memo = new Map();
  function chain(name, stack = []) {
    assert.ok(!stack.includes(name), 'Recursive call: ' + [...stack, name].join(' -> '));
    if (memo.has(name)) return memo.get(name);
    const children = byName.get(name).calls.map(n => chain(n, [...stack, name]));
    const longest = children.sort((a, b) => b.length - a.length)[0] ?? [];
    const result = [name, ...longest];
    memo.set(name, result);
    return result;
  }
  const allowRoots = new Set([...masked.matchAll(/\ballow\s+[^:]+:\s*if\s*([\s\S]*?);/g)]
    .flatMap(m => calls(m[1])));
  const paths = [...allowRoots].map(name => ({ depth: chain(name).length, chain: chain(name) }))
    .sort((a, b) => b.depth - a.depth);
  const repeated = functions.flatMap(f => {
    const counts = new Map();
    for (const n of f.calls) counts.set(n, (counts.get(n) ?? 0) + 1);
    return [...counts].filter(([, count]) => count >= 8).map(([callee, count]) =>
      ({ caller: f.name, callee, staticCallSites: count }));
  });
  const cleanup = functions.filter(f => /^(de(?:Peer|Leader)?CleanupAggregate|r3CleanupAggregate|r3CleanupPolicy\d)$/.test(f.name))
    .map(f => ({ name: f.name, depth: chain(f.name).length, chain: chain(f.name) }));
  console.log(JSON.stringify({ label, sha, maximumUserFunctionDepth: paths[0].depth,
    deepestAllowPaths: paths.filter(p => p.depth === paths[0].depth), cleanup, repeated,
    limitation: 'Static nested user-function depth, excludes allow and built-ins. Repeated sites include alternative branches, NOT actual request counts, expression counts or compiled size.'
  }, null, 2));
}
