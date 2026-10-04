// Keep quoted strings and token boundaries intact; remove comment-only lines.
export function stripRulesComments(source) {
  const marked = source.replace(/'(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*"|\/\/[^\r\n]*|\/\*[\s\S]*?\*\//g,
    value => value.startsWith('/') ? '\u0000' + value.replace(/[^\r\n]/g, ' ') : value);
  return marked.split('\n').filter(line => !(line.includes('\u0000') && line.replaceAll('\u0000', '').trim() === ''))
    .map(line => line.replaceAll('\u0000', '').trimEnd()).join('\n');
}
