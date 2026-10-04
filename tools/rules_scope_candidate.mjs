import assert from 'node:assert/strict';

// Source-only relocation. Never changes a predicate, signature, or allow expression.
export function scopeFunctions(source) {
  const mask = source.replace(/'(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*"|\/\/[^\n]*|\/\*[\s\S]*?\*\//g,
    s => s.replace(/[^\n]/g, ' '));
  function close(open) {
    let depth = 1, end = open + 1;
    while (depth && end < mask.length) {
      if (mask[end] === '{') depth++;
      if (mask[end] === '}') depth--;
      end++;
    }
    assert.equal(depth, 0);
    return end;
  }
  const matches = [...mask.matchAll(/\bmatch\s+([^\n]+?)\s+\{/g)].map(m => ({
    path: m[1].trim(), start: m.index, open: m.index + m[0].length - 1,
    end: close(m.index + m[0].length - 1),
  }));
  const scopes = pos => matches.filter(m => m.start < pos && pos < m.end);
  const root = matches.find(m => m.path === '/databases/{database}/documents');
  assert.ok(root);
  const funcs = [...mask.matchAll(/\bfunction\s+(\w+)\s*\(([^)]*)\)/g)].map(m => {
    const open = mask.indexOf('{', m.index), end = close(open);
    return { name: m[1], args: m[2].split(',').map(x => x.trim()), start: m.index,
      end, text: source.slice(m.index, end), body: mask.slice(open + 1, end), scope: root };
  });
  const names = new Map(funcs.map(f => [f.name, f]));
  assert.equal(names.size, funcs.length);
  const calls = text => [...text.matchAll(/\b(\w+)\s*\(/g)].map(m => m[1]).filter(n => names.has(n));
  for (const f of funcs) {
    assert.equal(scopes(f.start).at(-1), root, 'input must have root functions');
    f.calls = calls(f.body);
    f.users = [];
  }
  const allows = [...mask.matchAll(/\ballow\s+[^:]+:\s*if\s*([\s\S]*?);/g)];
  function mark(name, scope, stack = []) {
    assert.ok(!stack.includes(name), 'recursive function');
    const f = names.get(name);
    f.users.push(scope);
    for (const next of f.calls) mark(next, scope, [...stack, name]);
  }
  for (const a of allows) for (const n of calls(a[1])) mark(n, scopes(a.index).at(-1));
  const ancestor = (a, b) => a.start <= b.start && a.end >= b.end;
  const lca = list => matches.filter(m => list.every(x => ancestor(m, x))).at(-1);
  for (const f of funcs) {
    f.scope = f.users.length ? lca(f.users) : root;
    // Do not introduce lexical wildcard capture of an existing free identifier.
    const wildcards = scopes(f.scope.open + 1).filter(m => m !== root)
      .flatMap(m => [...m.path.matchAll(/\{(\w+)/g)].map(x => x[1]));
    if (wildcards.some(n => !f.args.includes(n) && new RegExp(`\\b${n}\\b`).test(f.body))) f.scope = root;
  }
  let changed;
  do {
    changed = false;
    for (const f of funcs) for (const name of f.calls) {
      const callee = names.get(name), next = lca([callee.scope, f.scope]);
      if (next !== callee.scope) { callee.scope = next; changed = true; }
    }
  } while (changed);
  for (const f of funcs) for (const n of f.calls) assert.ok(ancestor(names.get(n).scope, f.scope));
  const edits = [], placements = [];
  for (const m of matches) {
    const moved = funcs.filter(f => f.scope === m && m !== root);
    if (!moved.length) continue;
    edits.push({ start: m.open + 1, end: m.open + 1, text: '\n' + moved.map(f => '    ' + f.text).join('\n\n') + '\n' });
    for (const f of moved) {
      const lineStart = source.lastIndexOf('\n', f.start) + 1;
      const start = source.slice(lineStart, f.start).trim() === '' ? lineStart : f.start;
      edits.push({ start, end: f.end, text: '' });
      placements.push({ name: f.name, originalLine: source.slice(0, f.start).split('\n').length,
        destination: scopes(m.open + 1).map(x => x.path).join('') });
    }
  }
  let result = source;
  for (const e of edits.sort((a, b) => b.start - a.start)) result = result.slice(0, e.start) + e.text + result.slice(e.end);
  for (const f of funcs) assert.equal(result.split(f.text).length, 2, f.name);
  const allowText = s => [...s.matchAll(/\ballow\s+[^:]+:\s*if\s*[\s\S]*?;/g)].map(m => m[0]);
  assert.deepEqual(allowText(result), allowText(source));
  return { source: result, placements, functionCount: funcs.length, matchCount: matches.length, allowCount: allows.length };
}
