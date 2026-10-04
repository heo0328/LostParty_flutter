import assert from 'node:assert/strict';

// Alpha-renaming only: public fields, strings, paths, operators and call order stay intact.
// Keep the readable source in the generator; emit this format only at its final boundary.
export function compactExecutableRules(source) {
  const pattern = /\/\/[^\n]*|\/\*[\s\S]*?\*\/|'(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*"|\s+|[A-Za-z_][A-Za-z_0-9]*|[^\s]/g;
  const tokens = source.match(pattern);
  assert.equal(tokens.join(''), source);
  const comment = t => t.startsWith('//') || t.startsWith('/*');
  const significant = ts => ts.filter(t => !comment(t) && !/^\s+$/.test(t));
  const original = significant(tokens);
  const names = [...source.matchAll(/\bfunction\s+(\w+)\s*\(/g)].map(m => m[1]);
  assert.equal(new Set(names).size, names.length);
  const mapping = new Map(names.map((n, i) => [n, `rf${i}`]));
  for (const n of mapping.values()) assert.ok(!tokens.includes(n), 'identifier collision');
  let out = '';
  for (let i = 0; i < tokens.length; i++) {
    const t = tokens[i];
    if (comment(t)) { out += ' '; continue; }
    if (/^\s+$/.test(t)) { out += t.includes('\n') ? '\n' : ' '; continue; }
    let next = i + 1;
    while (next < tokens.length && (comment(tokens[next]) || /^\s+$/.test(tokens[next]))) next++;
    out += mapping.has(t) && tokens[next] === '(' ? mapping.get(t) : t;
  }
  out = out.split('\n').map(l => l.trim()).filter(Boolean).join('\n') + '\n';
  const functionRenamed = out;
  const localTokens = out.match(pattern);
  const sig = localTokens.map((t, i) => ({ t, i })).filter(x => !/^\s+$/.test(x.t));
  const edits = [], locals = [];
  let count = 0;
  for (let i = 0; i < sig.length; i++) {
    if (sig[i].t !== 'function') continue;
    const start = i, name = sig[++i].t;
    assert.equal(sig[++i].t, '(');
    const params = [];
    while (sig[++i].t !== ')') if (sig[i].t !== ',') params.push(sig[i].t);
    assert.equal(sig[++i].t, '{');
    const body = i;
    let depth = 1;
    while (depth) { i++; if (sig[i].t === '{') depth++; if (sig[i].t === '}') depth--; }
    const end = i, bindings = [...params];
    for (let j = body + 1; j < end; j++) if (sig[j].t === 'let') bindings.push(sig[j + 1].t);
    const map = new Map();
    for (const n of new Set(bindings)) {
      // Preserve ambiguous unquoted map keys and literal path segments.
      let risky = false;
      for (let j = body + 1; j < end; j++)
        if (sig[j].t === n && (['/', ':'].includes(sig[j - 1].t) || sig[j + 1].t === ':')) risky = true;
      if (risky) continue;
      const next = 'z' + (count++).toString(36);
      assert.ok(!sig.some(x => x.t === next), 'local identifier collision');
      map.set(n, next);
    }
    for (let j = start + 3; j <= end; j++) {
      const t = sig[j].t;
      if (map.has(t) && sig[j - 1].t !== '.') {
        edits.push({ index: sig[j].i, before: t });
        localTokens[sig[j].i] = map.get(t);
      }
    }
    locals.push({ name, mapping: Object.fromEntries(map) });
  }
  const result = localTokens.join('');
  for (const e of edits) localTokens[e.index] = e.before;
  assert.equal(localTokens.join(''), functionRenamed);
  const reverse = new Map([...mapping].map(([a, b]) => [b, a]));
  const reverted = significant(localTokens).map((t, i, a) => reverse.has(t) && a[i + 1] === '(' ? reverse.get(t) : t);
  assert.deepEqual(reverted, original, 'non-comment tokens must reverse exactly');
  return { source: result, functions: Object.fromEntries(mapping), locals, renamedBindings: count };
}
