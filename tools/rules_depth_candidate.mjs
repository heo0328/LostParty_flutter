// B: inline one pure single-caller predicate, preserving every condition and its order.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { pathToFileURL } from 'node:url';
import { rulesFunction } from './roster_complexity_candidate.mjs';
import { compactExecutableRules } from './rules_executable_compact.mjs';
export function depthCandidate(input) {
  let source = input.replaceAll('\r\n', '\n');
  const name = 'personalCompletionCommandMarker';
  assert.equal([...source.matchAll(/\bpersonalCompletionCommandMarker\s*\(/g)].length, 2);
  const marker = rulesFunction(source, name);
  const expression = marker.body.trim().match(/^return ([\s\S]*);$/);
  assert.ok(expression);
  const inlined = expression[1].replace(/\bdata\b/g, 'recruitment');
  source = source.slice(0, marker.start) + source.slice(marker.end);
  assert.equal(source.split(`${name}(recruitment)`).length, 2);
  return source.replace(`${name}(recruitment)`, `(${inlined})`);
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const input = fs.readFileSync('coverage/rules-listing-safety/readable.rules', 'utf8');
  const hash = s => createHash('sha256').update(s).digest('hex');
  assert.equal(hash(compactExecutableRules(input).source), '6f549385d34f54be879bb59d3edf7d8b19e633be5e1de785e375ae368672eeef');
  const readable = depthCandidate(input), source = compactExecutableRules(readable).source;
  fs.mkdirSync('coverage/rules-depth', { recursive: true });
  fs.writeFileSync('coverage/rules-depth/readable.rules', readable);
  fs.writeFileSync('coverage/rules-depth/candidate.rules', source);
  const manifest = { sha256: hash(source), bytes: Buffer.byteLength(source), delta: Buffer.byteLength(source) - 148833 };
  fs.writeFileSync('coverage/rules-depth/manifest.json', JSON.stringify(manifest, null, 2));
  console.log(JSON.stringify(manifest));
}
