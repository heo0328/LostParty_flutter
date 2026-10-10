import assert from 'node:assert/strict';

// Preserve line breaks and all non-whitespace tokens, including literal contents.
export function indentRules(source) {
  const tokens = s => s.match(/'(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*"|[^\s]/g) ?? [];
  let depth = 0;
  const lines = source.replace(/\r\n/g, '\n').trimEnd().split('\n').map(line => {
    const text = line.trim();
    if (!text) return '';
    const masked = text.replace(/'(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*"|\/\/.*$/g, '');
    const closing = masked.match(/^[}\])]+/)?.[0].length ?? 0;
    const continuation = /^(?:&&|\|\||\?|:)/.test(masked) ? 1 : 0;
    const result = '  '.repeat(Math.max(0, depth - closing + continuation)) + text;
    for (const c of masked) {
      if ('{[('.includes(c)) depth++;
      if ('}])'.includes(c)) depth--;
    }
    assert.ok(depth >= 0, 'Unbalanced Rules delimiters');
    return result;
  });
  assert.equal(depth, 0, 'Unbalanced Rules delimiters');
  const result = lines.join('\n') + '\n';
  assert.deepEqual(tokens(result), tokens(source), 'Formatting changed Rules tokens');
  return result;
}
