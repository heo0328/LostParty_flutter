// B re-evaluation on the recovered B-F1 baseline. No deployment source writes.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { pathToFileURL } from 'node:url';
import { depthCandidate } from './rules_depth_candidate.mjs';
import { compactExecutableRules } from './rules_executable_compact.mjs';
const hash = s => createHash('sha256').update(s).digest('hex');
export function depthRecheckCandidate(input) {
  const baseline = compactExecutableRules(input).source;
  assert.equal(hash(baseline), 'e2a8a7e60bf818f2b5f66af2de453b2ecaa34d4151f77afbaaaa8885ef979772');
  const readable = depthCandidate(input), source = compactExecutableRules(readable).source;
  return { readable, source, manifest: {
    baseline: hash(baseline), sha256: hash(source), bytes: Buffer.byteLength(source),
    delta: Buffer.byteLength(source) - Buffer.byteLength(baseline),
  } };
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const { readable, source, manifest } = depthRecheckCandidate(fs.readFileSync('coverage/rules-personal-budget/readable.rules', 'utf8'));
  const directory = 'coverage/rules-depth-recheck';
  fs.mkdirSync(directory, { recursive: true });
  fs.writeFileSync(`${directory}/readable.rules`, readable);
  fs.writeFileSync(`${directory}/candidate.rules`, source);
  fs.writeFileSync(`${directory}/manifest.json`, JSON.stringify(manifest, null, 2));
  console.log(JSON.stringify(manifest));
}
