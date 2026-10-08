// Bounded local diagnosis. Never edits Rules or contacts a remote project.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { compactExecutableRules } from './rules_executable_compact.mjs';
import { runCleanupProof } from './roster_completed_cleanup_proof.mjs';
import { lifecycle } from './roster_ownership_rules_proof.mjs';
import { doc, updateDoc } from 'firebase/firestore';
import { recruitmentId } from './party_group_cutover_rules_test.mjs';

const endpoint = 'http://127.0.0.1:8080/emulator/v1/projects/demo-party-group-cutover';
const label = process.env.R3_DIAGNOSIS_LABEL;
const root = 'coverage/rules-cleanup/diagnosis';
const stages = [];
let deadline;
function config() {
  if (!deadline) deadline = setTimeout(() => {
    console.error('Cleanup diagnosis exceeded 90 seconds; completed stages remain on disk.');
    process.exit(2);
  }, 90000).unref();
  assert.match(label ?? '', /^[a-z-]+$/);
  const rules = fs.readFileSync(process.env.ROSTER_COMPLEXITY_RULES_FILE, 'utf8');
  const readable = fs.readFileSync(process.env.R3_READABLE, 'utf8');
  const compact = compactExecutableRules(readable);
  assert.equal(compact.source, rules);
  fs.mkdirSync(root, { recursive: true });
  return { rules, compact };
}
// Opt-in only. The first attempted report exceeded this cap; do not raise it
// to hide a diagnostic limitation. Exit 0 means observations were recorded,
// not that the observed Rules request passed.
async function profile(rules, compact) {
  const response = await fetch(`${endpoint}:ruleCoverage`, { signal: AbortSignal.timeout(15000) });
  assert.ok(response.ok, `coverage HTTP ${response.status}`);
  const chunks = []; let bytes = 0;
  for await (const chunk of response.body) {
    bytes += chunk.length;
    if (bytes > 8 * 1024 * 1024) throw Error('single-request coverage exceeds 8 MiB cap');
    chunks.push(chunk);
  }
  const data = JSON.parse(Buffer.concat(chunks).toString());
  assert.equal(data.rules.files[0].content, rules);
  const originalNames = Object.fromEntries(Object.entries(compact.functions).map(([a, b]) => [b, a]));
  const ranges = [...rules.matchAll(/function (\w+)\([^)]*\) \{/g)].map(m => {
    let end = m.index + m[0].length, depth = 1;
    while (depth && end < rules.length) { if (rules[end] === '{') depth++; if (rules[end] === '}') depth--; end++; }
    return { start: m.index, end, name: originalNames[m[1]] ?? m[1] };
  });
  const groups = {}; const errors = [];
  function visit(node) {
    const p = node.sourcePosition;
    if (p) {
      const name = ranges.find(f => p.currentOffset >= f.start && p.currentOffset < f.end)?.name ?? `allow:${p.line}`;
      const group = groups[name] ??= { samples: 0, trueSamples: 0, falseSamples: 0, errorSamples: 0 };
      for (const v of node.values ?? []) {
        group.samples += v.count;
        if (v.value?.boolValue === true) group.trueSamples += v.count;
        if (v.value?.boolValue === false) group.falseSamples += v.count;
        if (v.value?.errorValue) {
          group.errorSamples += v.count;
          errors.push({ name, line: p.line, error: v.value.errorValue });
        }
      }
    }
    for (const child of node.children ?? []) visit(child);
  }
  data.report.forEach(visit);
  return { bytes, groups, errors, limitation: 'Coverage expression samples are not the official evaluation budget counter.' };
}
export async function stage(name, action, collect = false) {
  const { rules, compact } = config();
  const reload = await fetch(`${endpoint}:securityRules`, { method: 'PUT',
    signal: AbortSignal.timeout(15000), body: JSON.stringify({ rules: { files: [{ content: rules }] } }) });
  assert.ok(reload.ok, 'reset single-operation coverage');
  const result = { name, sha256: createHash('sha256').update(rules).digest('hex') };
  try { result.value = await action(); result.passed = true; }
  catch (error) { result.passed = false; result.code = error.code; result.error = error.message; }
  stages.push(result);
  fs.writeFileSync(`${root}/${label}.json`, JSON.stringify(stages, null, 2));
  if (collect && process.env.R3_CAPTURE_PROFILE === '1') {
    try { result.profile = await profile(rules, compact); }
    catch (error) { result.profileError = error.message; }
    fs.writeFileSync(`${root}/${label}.json`, JSON.stringify(stages, null, 2));
  }
  console.log(JSON.stringify({ name, passed: result.passed, code: result.code, error: result.error,
    coverageBytes: result.profile?.bytes }));
  return result;
}
function fixtureSummary(data) {
  return data.room.partySlots.map(slot => {
    const member = data.members.find(m => m.id === slot.playerId);
    return { player: slot.playerId, slotGeneration: slot.ownershipRevision ?? 0,
      memberGeneration: member?.ownershipRevision ?? 0,
      sameCharacter: member?.characterId === slot.characterId };
  });
}
async function alignFixture(env, snapshot) {
  if (process.env.R3_ALIGN_FIXTURE !== '1') return;
  const data = await snapshot();
  await env.withSecurityRulesDisabled(async context => {
    for (const slot of data.room.partySlots) {
      await updateDoc(doc(context.firestore(), 'recruitments', recruitmentId, 'members', slot.playerId),
        { ownershipRevision: slot.ownershipRevision });
    }
  });
}
export async function diagnosePeer({ env, setup, snapshot, request, command }) {
  config();
  await setup();
  await alignFixture(env, snapshot);
  for (let i = 0; i < 6; i++) await command(await request());
  fs.writeFileSync(`${root}/${label}-fixture.json`, JSON.stringify(fixtureSummary(await snapshot()), null, 2));
  const req = await request('leader');
  await stage('leader-succession-write', () => command(req), true);
}
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  config();
  await runCleanupProof(null, async ({ env, db, seed, snapshot, cleanup }) => {
    const returned = process.env.R3_DIAGNOSIS_CASE === 'returned';
    const req = await seed({ returned });
    await alignFixture(env, snapshot);
    fs.writeFileSync(`${root}/${label}-fixture.json`, JSON.stringify(fixtureSummary(await snapshot()), null, 2));
    const applied = await stage('participant-cleanup-write', () => cleanup(db, req), true);
    if (!applied.passed || returned) return;
    const receipt = await stage('receipt-read', () => cleanup(db, req));
    if (!receipt.passed) return;
    await stage('advance-write', () => lifecycle(db, 'advanceCycle', { ownershipSnapshot: true }));
  }, { skipRegression: true });
}
