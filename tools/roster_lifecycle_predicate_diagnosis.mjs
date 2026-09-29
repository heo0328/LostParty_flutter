// DIAGNOSTIC ONLY: probes isolate predicates, not transaction authorization.
// No deployments; all fixtures and probe writes use a demo Emulator project.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import { initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc, serverTimestamp, Timestamp } from 'firebase/firestore';
import { seedRoom } from './roster_ownership_rules_proof.mjs';
import { authUid, playerId, recruitmentId, raidId, cycleKey, cycleWindow } from './party_group_cutover_rules_test.mjs';

const predicates = {
  actor: 'atomicLifecycleActorAllowed(d.before, d.after)',
  shape: 'atomicValidLifecycleShape(d.before, d.after)',
  state: 'atomicValidLifecycleState(d.before, d.after)',
  incompleteShape: 'atomicValidIncompleteEndShape(d.before, d.after)',
  targets: 'atomicAllTargetsMatch(d.after)',
  groupCount: 'atomicValidGroupLifecycleCount(d.before, d.after)',
  aggregateAll: 'validAtomicLifecycleUpdate(d.before, d.after)',
  commandIncludes: 'atomicCommandIncludes(d.after, d.targetPlayer, d.stateId)',
  slotMatch: 'atomicAdvanceStateMatchesSlot(d.after, d.nextState)',
  stateUpdate: 'validAtomicRaidStateUpdate(d.targetPlayer, d.stateId, d.oldState, d.nextState)',
  event: 'validAtomicLifecyclePartyEvent(d.event)',
};
const source = fs.readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8');
const marker = '  match /databases/{database}/documents {';
if (source.split(marker).length !== 2) throw new Error('Rules insertion marker drift');
const rules = source.replace(marker, marker + '\n' + Object.entries(predicates).map(([name, expression]) => `
    match /dePredicateProbes/${name} {
      function probe() { let d = request.resource.data; return ${expression}; }
      allow create: if probe();
    }
`).join('\n'));
const env = await initializeTestEnvironment({ projectId: 'demo-party-group-cutover',
  firestore: { rules, host: '127.0.0.1', port: 8080 } });
try {
  const db = env.authenticatedContext(authUid).firestore();
  await seedRoom(env, db);
  const before = (await getDoc(doc(db, 'recruitments', recruitmentId))).data();
  const window = cycleWindow(cycleKey);
  const eventId = `advanceCycle_${recruitmentId}_${before.revision}`;
  const after = { ...before, status: 'active', currentCycleStatus: 'active',
    currentCycleKey: cycleKey, targetCycleKey: cycleKey,
    cycleStartedAt: Timestamp.fromDate(window.startedAt), cycleEndsAt: Timestamp.fromDate(window.endsAt),
    completedAt: null, completedByPlayerId: null, commandTargets: before.raidStateTargets,
    revision: before.revision + 1, lastCommandId: eventId, lastCommandType: 'advanceCycle',
    lastCommandActorPlayerId: playerId, lastCommandAt: serverTimestamp(), updatedAt: serverTimestamp() };
  let oldState;
  let nextState;
  const slot = before.partySlots.at(-1);
  const stateId = `${slot.characterId}_${raidId}`;
  await env.withSecurityRulesDisabled(async ctx => {
    const admin = ctx.firestore();
    oldState = (await getDoc(doc(admin, 'players', slot.playerId, 'raidStates', stateId))).data();
    await setDoc(doc(admin, 'recruitments', recruitmentId), after);
    for (const target of before.partySlots) {
      await updateDoc(doc(admin, 'players', target.playerId, 'raidStates', `${target.characterId}_${raidId}`),
        { cycleKey, status: 'active' });
    }
  });
  nextState = { ...oldState, schemaVersion: 1, playerId: slot.playerId, characterId: slot.characterId,
    raidId, difficultyId: before.difficultyId, recruitmentId, role: slot.role,
    source: 'party', status: 'active', cycleKey, revision: oldState.revision + 1, updatedAt: serverTimestamp() };
  delete nextState.completedAt;
  const event = { schemaVersion: 1, eventId, recruitmentId, type: 'advanceCycle', commandId: eventId,
    commandRevision: before.revision + 1, audiencePlayerIds: before.memberPlayerIds,
    actorPlayerId: playerId, occurredAt: serverTimestamp() };
  console.log('DIAG fixture', JSON.stringify({ now: new Date().toISOString(), cycleKey,
    oldKey: before.currentCycleKey, oldEnds: before.cycleEndsAt.toDate().toISOString(),
    newStart: window.startedAt.toISOString(), newEnd: window.endsAt.toISOString(),
    slots: before.partySlots.length, targets: before.raidStateTargets.length,
    target: slot, oldStateKeys: Object.keys(oldState), nextStateKeys: Object.keys(nextState) }));
  const results = {};
  for (const name of Object.keys(predicates)) {
    try {
      await setDoc(doc(db, 'dePredicateProbes', name), {
        before, after, oldState, nextState, targetPlayer: slot.playerId, stateId, event,
      });
      results[name] = 'true';
    } catch (error) {
      results[name] = error.message;
    }
    console.log(`DIAG ${name}: ${results[name]}`);
  }
  assert.ok(Object.values(results).every(result => result === 'true'),
    'one or more isolated predicates failed; inspect DIAG output');
  console.log('DIAG finished: probe results are not security or transaction acceptance.');
} finally { await env.cleanup(); }
