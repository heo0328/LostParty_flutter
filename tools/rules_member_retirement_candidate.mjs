// C1 local candidate only; never edits the tracked deployment source.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { pathToFileURL } from 'node:url';
import { compactExecutableRules } from './rules_executable_compact.mjs';
import { rulesFunction } from './roster_complexity_candidate.mjs';
const hash = s => createHash('sha256').update(s).digest('hex');
export const retiredFunctions = ['validMemberCharacterChange', 'recruitmentSlotPath',
  'recruitmentFirstPartySlotPath', 'recruitmentSecondPartySlotPath'];
export function memberRetirementCandidate(input) {
  const baseline = compactExecutableRules(input).source;
  assert.equal(hash(baseline), 'b6b4003a705ed313c08ecc3aafabed709330a43a2dc0a8069fe9db66f5742971');
  const call = /validMemberCharacterChange\(\s*recruitmentId,\s*playerId,\s*resource\.data,\s*request\.resource\.data\s*\)/g;
  assert.equal([...input.matchAll(call)].length, 1);
  let readable = input.replace(call, 'false');
  for (const name of retiredFunctions) {
    assert.equal([...readable.matchAll(new RegExp(`\\b${name}\\s*\\(`, 'g'))].length, 1,
      `Only the declaration may remain: ${name}`);
    const f = rulesFunction(readable, name);
    readable = readable.slice(0, f.start) + readable.slice(f.end);
  }
  const source = compactExecutableRules(readable).source;
  return { readable, source, manifest: { baseline: hash(baseline), sha256: hash(source),
    bytes: Buffer.byteLength(source), delta: Buffer.byteLength(source) - Buffer.byteLength(baseline),
    retiredFunctions } };
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const result = memberRetirementCandidate(fs.readFileSync('coverage/rules-depth-recheck/readable.rules', 'utf8'));
  const directory = 'coverage/rules-member-retirement';
  fs.mkdirSync(directory, { recursive: true });
  fs.writeFileSync(`${directory}/readable.rules`, result.readable);
  fs.writeFileSync(`${directory}/candidate.rules`, result.source);
  fs.writeFileSync(`${directory}/manifest.json`, JSON.stringify(result.manifest, null, 2));
  console.log(JSON.stringify(result.manifest));
}
