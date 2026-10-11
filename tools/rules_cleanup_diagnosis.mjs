// Bounded local diagnosis. Never edits Rules or contacts a remote project.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { compactExecutableRules } from './rules_executable_compact.mjs';
import { runCleanupProof } from './roster_completed_cleanup_proof.mjs';
import { lifecycle } from './roster_ownership_rules_proof.mjs';
import { doc, updateDoc, runTransaction, Timestamp, serverTimestamp } from 'firebase/firestore';
import { recruitmentId, authUid, playerId, cycleKey, cycleWindow } from './party_group_cutover_rules_test.mjs';

const endpoint = 'http://127.0.0.1:8080/emulator/v1/projects/demo-party-group-cutover';
const label = process.env.R3_DIAGNOSIS_LABEL;
const root = 'coverage/rules-cleanup/diagnosis';
const stages = [];
const a1 = process.env.RULES_A1 === '1';
const guardKeys = ['guardSchemaVersion', 'guardRecruitmentId', 'guardRoomRevision', 'guardCycleKey',
  'guardCycleStartedAt', 'guardCycleEndsAt', 'guardSlotIndex', 'guardCheckedAt'];
const withoutGuard = state => state == null ? state : Object.fromEntries(
  Object.entries(state).filter(([key]) => !guardKeys.includes(key)));
let deadline;
function config() {
  if (!deadline) deadline = setTimeout(() => {
    console.error('Cleanup diagnosis exceeded 90 seconds; completed stages remain on disk.');
    process.exit(2);
  }, 90000).unref();
  assert.match(label ?? '', /^[a-z-]+$/);
  const rules = fs.readFileSync(process.env.ROSTER_COMPLEXITY_RULES_FILE, 'utf8');
  if (a1) assert.equal(createHash('sha256').update(rules).digest('hex'),
    '17471d0f4bff19595c90ddb43c28766cbf976d77ba9d0adc0736ff59f4a93667', 'A1 only accepts the R1 baseline');
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
  const result = { name, startedAt: new Date().toISOString(), sha256: createHash('sha256').update(rules).digest('hex') };
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
function recordFixture(data) {
  const summary = fixtureSummary(data);
  if (a1) for (const member of summary) {
    assert.equal(member.memberGeneration, member.slotGeneration);
    assert.equal(member.sameCharacter, true);
  }
  fs.writeFileSync(`${root}/${label}-fixture.json`, JSON.stringify(summary, null, 2));
}
// Match the current writer's per-target transaction order, without reading private peer states.
async function certify(db, expected, index) {
  return runTransaction(db, async tx => {
    const binding = (await tx.get(doc(db, 'authBindings', authUid))).data();
    assert.equal(binding.status, 'active'); assert.equal(binding.playerId, playerId);
    const room = (await tx.get(doc(db, 'recruitments', recruitmentId))).data();
    assert.equal(room.revision, expected.revision); assert.equal(room.leaderPlayerId, playerId);
    assert.deepEqual(room.partySlots, expected.partySlots);
    const slot = room.partySlots[index], window = cycleWindow(cycleKey);
    tx.set(doc(db, 'players', slot.playerId, 'raidStates', `${slot.characterId}_${room.raidId}`), {
      playerId: slot.playerId, characterId: slot.characterId, raidId: room.raidId,
      ownershipRevision: slot.ownershipRevision ?? 0, guardSchemaVersion: 1,
      guardRecruitmentId: recruitmentId, guardRoomRevision: room.revision, guardCycleKey: cycleKey,
      guardCycleStartedAt: Timestamp.fromDate(window.startedAt), guardCycleEndsAt: Timestamp.fromDate(window.endsAt),
      guardSlotIndex: index, guardCheckedAt: serverTimestamp(),
    }, { merge: true });
  });
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
  recordFixture(await snapshot());
  for (let i = 0; i < 6; i++) {
    const req = await request(), before = await snapshot();
    const result = await stage(`peer-removal-${i + 1}`, async () => {
      assert.equal(await command(req), 'applied');
      const after = await snapshot();
      assert.equal(after.room.memberCount, 7 - i);
      for (const key of ['states', 'group', 'groupMembers']) assert.deepEqual(after[key], before[key], key);
      assert.deepEqual(after.listing, after.room);
      assert.equal(await command(req), 'already-applied'); assert.deepEqual(await snapshot(), after);
    });
    if (!result.passed) return;
  }
  const req = await request('leader');
  const before = await snapshot();
  fs.writeFileSync(`${root}/${label}-leader-input.json`, JSON.stringify({ req, before }, null, 2));
  const result = await stage('leader-succession-write', () => command(req), true);
  if (!result.passed) await stage('leader-failure-atomicity', async () => assert.deepEqual(await snapshot(), before));
}
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  config();
  await runCleanupProof(null, async ({ env, db, seed, snapshot, cleanup }) => {
    const returned = process.env.R3_DIAGNOSIS_CASE === 'returned';
    const req = await seed({ returned });
    await alignFixture(env, snapshot);
    recordFixture(await snapshot());
    const before = await snapshot();
    const applied = await stage('participant-cleanup-write', () => cleanup(db, req), true);
    if (!applied.passed || returned) return;
    const cleaned = await snapshot();
    const receipt = await stage('receipt-read', async () => {
      assert.equal(await cleanup(db, req), 'already-applied'); assert.deepEqual(await snapshot(), cleaned);
      for (const key of ['states', 'group', 'groupMembers']) assert.deepEqual(cleaned[key], before[key], key);
      assert.equal(cleaned.room.memberCount, 7); assert.deepEqual(cleaned.listing, cleaned.room);
    });
    if (!receipt.passed) return;
    if (a1) {
      const raw = await stage('legacy-uncertified-advance', () => lifecycle(db, 'advanceCycle', { ownershipSnapshot: true }));
      assert.equal(raw.passed, false); assert.equal(raw.code, 'permission-denied');
      assert.ok(!raw.error.includes('maximum of 1000'), 'budget failure is not an expected denial');
      assert.deepEqual(await snapshot(), cleaned);
      for (let index = 0; index < cleaned.room.partySlots.length; index++) {
        const result = await stage(`advance-certification-${index}`, () => certify(db, cleaned.room, index));
        if (!result.passed) return;
      }
      const preserved = await stage('certification-preserves-core', async () => {
        const certified = await snapshot();
        for (const key of ['room', 'listing', 'members', 'events', 'group', 'groupMembers'])
          assert.deepEqual(certified[key], cleaned[key], key);
        assert.deepEqual(certified.states.map(withoutGuard), cleaned.states.map(withoutGuard));
      });
      if (!preserved.passed) return;
    }
    const advanced = await stage('advance-write', () => lifecycle(db, 'advanceCycle', { ownershipSnapshot: true }));
    if (a1 && advanced.passed) await stage('advance-postconditions', async () => {
      const after = await snapshot();
      assert.equal(after.room.revision, cleaned.room.revision + 1);
      assert.equal(after.room.currentCycleKey, cycleKey); assert.equal(after.room.currentCycleStatus, 'active');
      assert.deepEqual(after.listing, after.room);
      for (const key of ['members', 'group', 'groupMembers']) assert.deepEqual(after[key], cleaned[key], key);
      for (let index = 0; index < before.room.partySlots.length; index++) {
        const slot = before.room.partySlots[index];
        if (slot.playerId === req.targetPlayerId) assert.deepEqual(after.states[index], before.states[index]);
        else {
          assert.equal(after.states[index].status, 'active'); assert.equal(after.states[index].cycleKey, cycleKey);
          assert.equal(after.states[index].revision, cleaned.states[index].revision + 1);
        }
      }
      assert.equal(after.events.length, cleaned.events.length + 1);
    });
  }, { skipRegression: true });
}
