// A1-F local candidate only. Never replaces the tracked deployment source.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { pathToFileURL } from 'node:url';
import { compactExecutableRules } from './rules_executable_compact.mjs';
export function leaderBudgetCandidate(input) {
  let source = input.replaceAll('\r\n', '\n');
  const oldBranch = "(request.resource.data.get('lastCommandType', '') == 'cleanupCompletedLeaderOwnership' && deLeaderCleanupAggregate(resource.data, request.resource.data)) || ";
  assert.equal(source.split(oldBranch).length, 2);
  source = source.replace(oldBranch, '');
  const marker = '      allow update: if (request.resource.data.get(\'lastCommandType\', \'\') in [\'advanceCycle\'';
  assert.equal(source.split(marker).length, 2);
  const start = source.indexOf(marker) + '      allow update: if '.length;
  const end = source.indexOf(';', start);
  const original = source.slice(start, end);
  source = source.slice(0, start)
    + "(request.resource.data.get('lastCommandType', '') == 'cleanupCompletedLeaderOwnership' && request.resource.data.lastCommandAt == request.time) ? (deLeaderCleanupAggregate(resource.data, request.resource.data)) : ("
    + original + ')' + source.slice(end);
  // The source must force a real delete so the member's completed-state guard cannot be skipped.
  const guard = '        && target.playerId == before.leaderPlayerId\n';
  assert.equal(source.split(guard).length, 2);
  source = source.replace(guard, guard + '        && after.partySlots.size() <= 8\n'
    + '        && exists(/databases/$(database)/documents/recruitments/$(before.recruitmentId)/members/$(target.playerId))\n');
  return source;
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const input = fs.readFileSync('coverage/rules-listing/readable.rules', 'utf8');
  const baseline = compactExecutableRules(input).source;
  const hash = s => createHash('sha256').update(s).digest('hex');
  assert.equal(hash(baseline), '17471d0f4bff19595c90ddb43c28766cbf976d77ba9d0adc0736ff59f4a93667');
  const readable = leaderBudgetCandidate(input), candidate = compactExecutableRules(readable).source;
  fs.mkdirSync('coverage/rules-leader-budget', { recursive: true });
  fs.writeFileSync('coverage/rules-leader-budget/readable.rules', readable);
  fs.writeFileSync('coverage/rules-leader-budget/candidate.rules', candidate);
  const manifest = { baseline: hash(baseline), sha256: hash(candidate), bytes: Buffer.byteLength(candidate), delta: Buffer.byteLength(candidate) - Buffer.byteLength(baseline) };
  fs.writeFileSync('coverage/rules-leader-budget/manifest.json', JSON.stringify(manifest, null, 2));
  console.log(JSON.stringify(manifest));
}
