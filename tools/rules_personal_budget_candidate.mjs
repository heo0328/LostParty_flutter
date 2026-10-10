// B-F1 isolated candidate; never writes the deployment source.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { pathToFileURL } from 'node:url';
import { compactExecutableRules } from './rules_executable_compact.mjs';
export const personalBranch = "(request.resource.data.get('lastCommandType', '') == 'personalComplete' && request.resource.data.lastCommandAt == request.time) ? (dePersonalCompletionBoundary(resource.data, request.resource.data) && validPersonalCompletionRecruitmentUpdate(resource.data, request.resource.data)) : (";
export function personalBudgetCandidate(input) {
  const source = input.replaceAll('\r\n', '\n');
  const marker = "      allow update: if (request.resource.data.get('lastCommandType', '') == 'cleanupCompletedLeaderOwnership'";
  assert.equal(source.split(marker).length, 2);
  assert.equal(source.split(personalBranch).length, 2);
  const start = source.indexOf(marker) + '      allow update: if '.length;
  const end = source.indexOf(';', start);
  const original = source.slice(start, end);
  assert.ok(original.includes(personalBranch));
  return source.slice(0, start) + personalBranch
    + original.replace(personalBranch, '(') + ')' + source.slice(end);
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const input = fs.readFileSync('coverage/rules-listing-safety/readable.rules', 'utf8');
  const hash = s => createHash('sha256').update(s).digest('hex');
  const baseline = compactExecutableRules(input).source;
  assert.equal(hash(baseline), '6f549385d34f54be879bb59d3edf7d8b19e633be5e1de785e375ae368672eeef');
  const readable = personalBudgetCandidate(input), candidate = compactExecutableRules(readable).source;
  const directory = 'coverage/rules-personal-budget';
  fs.mkdirSync(directory, { recursive: true });
  fs.writeFileSync(`${directory}/readable.rules`, readable);
  fs.writeFileSync(`${directory}/candidate.rules`, candidate);
  const manifest = { baseline: hash(baseline), sha256: hash(candidate), bytes: Buffer.byteLength(candidate), delta: Buffer.byteLength(candidate) - Buffer.byteLength(baseline) };
  fs.writeFileSync(`${directory}/manifest.json`, JSON.stringify(manifest, null, 2));
  console.log(JSON.stringify(manifest));
}
