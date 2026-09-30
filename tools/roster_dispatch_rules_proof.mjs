import { sharedTargetStatus } from './roster_target_rules_candidate.mjs';
// DE2-B4: no bypass matches, no deployment, no production-source edits.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { collection, getDocs, getDoc, doc, updateDoc, runTransaction, deleteField, increment, serverTimestamp } from 'firebase/firestore';
import { seedRoom, lifecycle, inspectAll, ownershipCandidate } from './roster_ownership_rules_proof.mjs';
import { authUid, cycleKey, recruitmentId, raidId, seedGroupLinkedRoom, runCutoverRegression } from './party_group_cutover_rules_test.mjs';

const tracked = fs.readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8');
function directDispatch(source) {
  const marker = '    match /recruitments/{recruitmentId} {';
  assert.equal(source.split(marker).length, 2);
  const start = source.indexOf('      allow update: if ', source.indexOf(marker));
  const end = source.indexOf('      allow delete: if false;', start);
  assert.ok(start > 0 && end > start);
  const original = source.slice(start, end).trim().replace(/^allow update: if /, '').replace(/;$/, '');
  // Missing legacy marker must still reach the unchanged original expression.
  return source.slice(0, start) + `      allow update: if
        request.resource.data.get('lastCommandType', '') == 'advanceCycle'
          ? validAtomicLifecycleUpdate(resource.data, request.resource.data)
          : (${original});\n` + source.slice(end);
}
function recurrenceFirst(source) {
  const start = source.indexOf('    function validRecurrenceChange(');
  const end = source.indexOf('\n    // R2:', start);
  assert.ok(start > 0 && end > start);
  const original = source.slice(start, end);
  const keyCheck = "newData.diff(oldData).affectedKeys().hasOnly([\n          'continueTogether', 'revision', 'updatedAt'\n        ])";
  assert.equal(original.split(keyCheck).length, 2);
  const reordered = original.replace(`        && ${keyCheck}\n`, '')
    .replace('return hasActiveBinding()', `return ${keyCheck}\n        && hasActiveBinding()`);
  return source.slice(0, start) + reordered + source.slice(end);
}
const fallbackMode = process.env.DISPATCH_SCOPE === 'targets-fallback';
const targetMode = process.env.DISPATCH_SCOPE === 'targets' || fallbackMode;
const buildCandidate = targetMode ? sharedTargetStatus
  : process.env.DISPATCH_SCOPE === 'recurrence' ? recurrenceFirst : directDispatch;
const dispatch = buildCandidate(tracked);
const combined = buildCandidate(ownershipCandidate);
const coverageDirectory = new URL('../coverage/roster-targets/', import.meta.url);
async function captureCoverage(label, phase, rules) {
  fs.mkdirSync(coverageDirectory, { recursive: true });
  const response = await fetch('http://127.0.0.1:8080/emulator/v1/projects/demo-party-group-cutover:ruleCoverage');
  assert.ok(response.ok, `coverage endpoint: ${response.status}`);
  fs.writeFileSync(new URL(`${label}-${phase}.json`, coverageDirectory), JSON.stringify(await response.json()));
  fs.writeFileSync(new URL(`${label}.rules`, coverageDirectory), rules);
  fs.writeFileSync(new URL(`${label}-manifest.json`, coverageDirectory), JSON.stringify({
    rulesSha256: createHash('sha256').update(rules).digest('hex'),
    interval: 'after seed and snapshot; immediately after target advance transaction before snapshot',
    limitation: 'Return-value coverage, not exact per-write expression cost.',
  }, null, 2));
}
async function snapshot(env) {
  const result = await inspectAll(env);
  await env.withSecurityRulesDisabled(async ctx => {
    const events = await getDocs(collection(ctx.firestore(), 'partyEvents'));
    result.events = events.docs.map(d => ({ id: d.id, ...d.data() })).sort((a, b) => a.id.localeCompare(b.id));
  });
  return result;
}
const failures = [];
async function check(name, action) {
  try { await action(); console.log(`PASS DISPATCH: ${name}`); return true; }
  catch (error) { failures.push(name); console.error(`FAIL DISPATCH: ${name}: ${error.message}`); return false; }
}
if (fallbackMode) {
  // Same B7 candidate, only the missing incompleteEnd boundary; no full rerun.
  const env = await initializeTestEnvironment({ projectId: 'demo-party-group-cutover',
    firestore: { rules: dispatch, host: '127.0.0.1', port: 8080 } });
  const leader = env.authenticatedContext(authUid).firestore();
  const member = env.authenticatedContext('joiner-auth').firestore();
  async function seedExpired() {
    await seedRoom(env, leader);
    await seedGroupLinkedRoom(env, leader, { includeJoinerGroupMember: true });
    await env.withSecurityRulesDisabled(ctx => updateDoc(doc(ctx.firestore(), 'recruitments', recruitmentId),
      { continueTogether: false }));
  }
  async function withGroupSnapshot() {
    const result = await snapshot(env);
    await env.withSecurityRulesDisabled(async ctx => {
      result.group = (await getDoc(doc(ctx.firestore(), 'groups', result.room.groupId))).data();
    });
    return result;
  }
  async function endIncomplete(nonEmptyTargets = false) {
    await runTransaction(member, async tx => {
      const ref = doc(member, 'recruitments', recruitmentId);
      const room = (await tx.get(ref)).data();
      const groupRef = doc(member, 'groups', room.groupId);
      const group = (await tx.get(groupRef)).data();
      const nextCount = group.activeRecruitmentCount - 1;
      const eventId = `incompleteEnd_${recruitmentId}_${room.revision}`;
      tx.update(ref, {
        status: 'incompleteEnded', currentCycleStatus: 'incompleteEnded',
        manualRecruitmentEnabled: false, hasAvailableSlot: false,
        commandTargets: nonEmptyTargets ? room.raidStateTargets : [],
        groupActiveRecruitmentCountAfter: nextCount, revision: room.revision + 1,
        lastCommandId: eventId, lastCommandType: 'incompleteEnd', lastCommandActorPlayerId: 'player-2',
        lastCommandAt: serverTimestamp(), updatedAt: serverTimestamp(),
      });
      tx.update(groupRef, { activeRecruitmentCount: nextCount, lastRecruitmentId: recruitmentId,
        revision: increment(1), updatedAt: serverTimestamp() });
      tx.delete(doc(member, 'groups', room.groupId, 'raidListings', recruitmentId));
      tx.set(doc(member, 'partyEvents', eventId), {
        schemaVersion: 2, eventId, recruitmentId, type: 'partyIncompleteEnded', commandId: eventId,
        commandRevision: room.revision + 1, audiencePlayerIds: room.memberPlayerIds,
        actorPlayerId: 'player-2', occurredAt: serverTimestamp(), raidId: room.raidId,
        difficultyId: room.difficultyId, cycleKey: room.currentCycleKey,
        completionTargets: room.partySlots.map(slot => ({ playerId: slot.playerId, characterId: slot.characterId })),
      });
    });
  }
  try {
    const passed = await check('8-member incompleteEnd preserves states and closes group listing', async () => {
      await seedExpired();
      const before = await withGroupSnapshot();
      await assertSucceeds(endIncomplete());
      const after = await withGroupSnapshot();
      assert.equal(after.room.status, 'incompleteEnded');
      assert.equal(after.room.revision, before.room.revision + 1);
      assert.deepEqual(after.states, before.states);
      assert.equal(after.listing, undefined);
      assert.equal(after.group.activeRecruitmentCount, before.group.activeRecruitmentCount - 1);
      assert.equal(after.events.length, before.events.length + 1);
    });
    if (passed) await check('incompleteEnd nonempty targets denied atomically', async () => {
      await seedExpired();
      const before = await withGroupSnapshot();
      await assertFails(endIncomplete(true));
      assert.deepEqual(await withGroupSnapshot(), before);
    });
  } finally { await env.cleanup(); }
} else if (process.env.DISPATCH_SCOPE === 'baseline') {
  const env = await initializeTestEnvironment({ projectId: 'demo-party-group-cutover',
    firestore: { rules: tracked, host: '127.0.0.1', port: 8080 } });
  try {
    await check('baseline normal 8-member group complete', async () => {
      const db = env.authenticatedContext(authUid).firestore();
      await seedRoom(env, db);
      await seedGroupLinkedRoom(env, db, { includeJoinerGroupMember: true });
      await assertSucceeds(lifecycle(db, 'complete'));
    });
  } finally { await env.cleanup(); }
  await check('baseline existing full cutover regression', () => runCutoverRegression(tracked));
} else {
const regressionPassed = !targetMode || await check('target candidate existing full cutover regression', () => runCutoverRegression(dispatch));
for (const [label, rules] of [['dispatch', dispatch], ['ownership', combined]]) {
  if (targetMode && label === 'ownership' && failures.length) {
    console.log('SKIP ownership: plain target candidate has not passed acceptance gates');
    continue;
  }
  const env = await initializeTestEnvironment({ projectId: 'demo-party-group-cutover',
    firestore: { rules, host: '127.0.0.1', port: 8080 } });
  const db = env.authenticatedContext(authUid).firestore();
  async function seed() {
    await seedRoom(env, db);
    await seedGroupLinkedRoom(env, db, { includeJoinerGroupMember: true });
  }
  try {
    if (label === 'dispatch' && process.env.DISPATCH_SCOPE === 'recurrence') {
      await check('recurrence marker preservation and authority', async () => {
        for (const marker of [null, 'missing', 'advanceCycle', 'complete', 'legacyCommand']) {
          await seed();
          await env.withSecurityRulesDisabled(ctx => updateDoc(doc(ctx.firestore(), 'recruitments', recruitmentId),
            { lastCommandType: marker === 'missing' ? deleteField() : marker }));
          const before = await snapshot(env);
          const patch = { continueTogether: false, revision: increment(1), updatedAt: serverTimestamp() };
          await assertFails(updateDoc(doc(env.authenticatedContext('joiner-auth').firestore(), 'recruitments', recruitmentId), patch));
          await assertFails(updateDoc(doc(db, 'recruitments', recruitmentId), { ...patch, title: 'forged' }));
          assert.deepEqual(await snapshot(env), before);
          await assertSucceeds(updateDoc(doc(db, 'recruitments', recruitmentId), patch));
          const after = await snapshot(env);
          assert.equal(after.room.continueTogether, false);
          assert.equal(after.room.revision, before.room.revision + 1);
          assert.equal(after.room.lastCommandType, before.room.lastCommandType);
          assert.equal(Object.hasOwn(after.room, 'lastCommandType'), Object.hasOwn(before.room, 'lastCommandType'));
          assert.deepEqual(after.states, before.states);
          assert.deepEqual(after.events, before.events);
        }
      });
    }
    let normalPassed = false;
    await check(`${label} normal 8-member group advance`, async () => {
      await seed();
      const before = await snapshot(env);
      if (targetMode) await captureCoverage(label, 'before', rules);
      try { await assertSucceeds(lifecycle(db, 'advanceCycle')); }
      finally { if (targetMode) await captureCoverage(label, 'after', rules); }
      const after = await snapshot(env);
      assert.equal(after.room.revision, before.room.revision + 1);
      assert.equal(after.room.currentCycleKey, cycleKey);
      assert.equal(after.states.length, 8);
      assert.ok(after.states.every(s => s.status === 'active' && s.cycleKey === cycleKey));
      assert.equal(after.listing.sourceRevision, after.room.revision);
      assert.deepEqual(after.listing.partySlots, after.room.partySlots);
      assert.equal(after.events.length, before.events.length + 1);
      normalPassed = true;
    });
    let completePassed = false;
    if (targetMode) completePassed = await check(`${label} independent normal 8-member group complete`, async () => {
      await seed();
      const before = await snapshot(env);
      await assertSucceeds(lifecycle(db, 'complete'));
      const after = await snapshot(env);
      assert.equal(after.room.currentCycleStatus, 'completed');
      assert.equal(after.room.revision, before.room.revision + 1);
      assert.equal(after.states.length, 8);
      assert.ok(after.states.every(s => s.status === 'completed' && s.cycleKey === after.room.currentCycleKey));
      assert.equal(after.listing.sourceRevision, after.room.revision);
      assert.equal(after.events.length, before.events.length + 1);
    });
    if (!normalPassed || (targetMode && (!completePassed || !regressionPassed))) continue;
    if (label === 'dispatch') {
      for (const tamper of ['role', 'character', 'omit-state', 'target-player', 'target-state', 'non-leader',
        ...(targetMode ? ['state-status', 'state-cycle', 'state-recruitment'] : [])]) {
        await check(`reject ${tamper} atomically`, async () => {
          await seed();
          const before = await snapshot(env);
          const attacker = tamper === 'non-leader' ? env.authenticatedContext('joiner-auth').firestore() : db;
          await assertFails(lifecycle(attacker, 'advanceCycle', {
            tamper, actorPlayerId: tamper === 'non-leader' ? 'player-2' : 'player-1',
          }));
          assert.deepEqual(await snapshot(env), before);
        });
      }
      if (targetMode) for (const tamper of ['omit-state', 'state-status', 'state-cycle', 'state-recruitment']) {
        await check(`complete reject ${tamper} atomically`, async () => {
          await seed();
          const before = await snapshot(env);
          await assertFails(lifecycle(db, 'complete', { tamper }));
          assert.deepEqual(await snapshot(env), before);
        });
      }
      await check('legacy ownership fields and command marker absent', async () => {
        await seed();
        const before = await inspectAll(env);
        await env.withSecurityRulesDisabled(async ctx => {
          await updateDoc(doc(ctx.firestore(), 'recruitments', recruitmentId), {
            lastCommandType: deleteField(),
            partySlots: before.room.partySlots.map(({ ownershipRevision, ...slot }) => slot),
          });
          for (const slot of before.room.partySlots) {
            await updateDoc(doc(ctx.firestore(), 'players', slot.playerId, 'raidStates', `${slot.characterId}_${raidId}`),
              { ownershipRevision: deleteField() });
          }
        });
        await assertSucceeds(lifecycle(db, 'advanceCycle'));
      });
    }
    for (const type of ['complete', 'advanceCycle']) {
      let typePassed = type === 'advanceCycle';
      if (type === 'complete' && targetMode) typePassed = completePassed;
      if (type === 'complete' && !targetMode) await check(`${label} normal 8-member complete`, async () => {
        await seed();
        await assertSucceeds(lifecycle(db, type));
        typePassed = true;
      });
      if (!typePassed) continue;
      for (const returned of [false, true]) {
        await check(`${label} ${type} ${returned ? 'A-B-A' : 'transfer'}`, async () => {
          await seed();
          const before = await snapshot(env);
          const target = before.room.partySlots.at(-1);
          await env.withSecurityRulesDisabled(ctx => updateDoc(doc(ctx.firestore(), 'characters', target.characterId), {
            ownerPlayerId: returned ? target.playerId : 'new-owner', ownershipRevision: returned ? 3 : 2,
          }));
          if (label === 'dispatch') await assertSucceeds(lifecycle(db, type));
          else {
            await assertFails(lifecycle(db, type));
            assert.deepEqual(await snapshot(env), before);
          }
        });
      }
    }
  } finally { await env.cleanup(); }
}
// Reuse existing commands and assertions instead of copying their implementations.
if (!targetMode) await check('existing full cutover regression with dispatch only', () => runCutoverRegression(dispatch));
}
assert.deepEqual(failures, [], 'dispatch proof failed; no production adoption');
console.log(`DE2-B4 scope ${process.env.DISPATCH_SCOPE || 'candidate'} passed; no production adoption.`);
