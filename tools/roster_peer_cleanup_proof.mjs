// DE2-E5: bounded peer cleanup, then first remaining successor. Demo fixtures only.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { doc, getDoc, setDoc, updateDoc, deleteDoc, runTransaction, serverTimestamp } from 'firebase/firestore';
import { assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { peerCleanupCandidate } from './roster_peer_cleanup_candidate.mjs';
import { runCleanupProof } from './roster_completed_cleanup_proof.mjs';
import { lifecycle } from './roster_ownership_rules_proof.mjs';
import { recruitmentId } from './party_group_cutover_rules_test.mjs';
const rules = peerCleanupCandidate(fs.readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'));
const directory = new URL('../coverage/roster-leader/', import.meta.url);
fs.mkdirSync(directory, { recursive: true });
fs.writeFileSync(new URL('candidate.rules', directory), rules);
fs.writeFileSync(new URL('manifest.json', directory), JSON.stringify({ sha256: createHash('sha256').update(rules).digest('hex') }));
const results = await runCleanupProof(rules, async ({ env, seed, snapshot, check, getSlots }) => {
  async function setup(staleCount = 7) {
    await seed();
    await env.withSecurityRulesDisabled(async ctx => {
      for (const [i, slot] of getSlots().entries()) {
        for (const ref of [doc(ctx.firestore(), 'characters', slot.characterId), doc(ctx.firestore(), 'gameAccounts', `de-account-${slot.playerId}`)]) {
          await updateDoc(ref, { ownerPlayerId: i < staleCount ? 'new-owner' : slot.playerId, ownershipRevision: i < staleCount ? 2 : 1 });
        }
        await setDoc(doc(ctx.firestore(), 'authBindings', `peer-${slot.playerId}`), { playerId: slot.playerId, status: 'active' });
      }
      await setDoc(doc(ctx.firestore(), 'authBindings', 'peer-outsider'), { playerId: 'outsider', status: 'active' });
    });
  }
  const client = actor => env.authenticatedContext(`peer-${actor}`).firestore();
  async function request(kind = 'peer', actor = getSlots()[7].playerId) {
    const { room } = await snapshot();
    const targetIndex = kind === 'peer' ? 1 : 0;
    return { kind, actor, commandId: `peer-${kind}-${room.revision}`, expectedRevision: room.revision,
      targetIndex, targetPlayerId: room.partySlots[targetIndex].playerId,
      targetCharacterId: room.partySlots[targetIndex].characterId,
      actorIndex: room.partySlots.findIndex(s => s.playerId === actor), observedOwnershipRevision: 2,
      ...(kind === 'peer' ? { leaderIndex: 0, observedLeaderRevision: 2 } : { successorIndex: 1, priorGenerations: room.partySlots.map(s => s.ownershipRevision) }) };
  }
  async function command(req, tamper = null, barrier = null) {
    const db = client(req.actor);
    return runTransaction(db, async tx => {
      const ref = doc(db, 'recruitments', recruitmentId), eventRef = doc(db, 'partyEvents', req.commandId);
      const room = (await tx.get(ref)).data();
      const type = req.kind === 'peer' ? 'ownershipPeerRemoved' : 'ownershipLeaderRemoved';
      const target = room.partySlots.find(s => s.playerId === req.targetPlayerId);
      if (!target) {
        const event = (await tx.get(eventRef)).data();
        assert.ok(event && event.type === type && event.commandId === req.commandId && event.recruitmentId === recruitmentId
          && event.actorPlayerId === req.actor && event.targetPlayerId === req.targetPlayerId && event.targetCharacterId === req.targetCharacterId
          && event.expectedRevision === req.expectedRevision && event.observedOwnershipRevision === req.observedOwnershipRevision
          && (req.kind !== 'peer' || event.observedLeaderRevision === req.observedLeaderRevision), 'retry mismatch');
        return 'already-applied';
      }
      let successor, member;
      if (req.kind === 'leader') {
        successor = room.partySlots[req.successorIndex];
        member = (await tx.get(doc(db, 'recruitments', recruitmentId, 'members', successor.playerId))).data();
      }
      if (barrier) await barrier();
      const remaining = room.partySlots.filter(s => s.playerId !== target.playerId);
      if (tamper === 'remaining-slot') remaining[0] = { ...remaining[0], classKey: 'forged' };
      const composition = { partySlots: remaining, memberPlayerIds: remaining.map(s => s.playerId), memberCount: remaining.length,
        raidStateTargets: room.raidStateTargets.filter(s => s.playerId !== target.playerId),
        dealerCount: room.dealerCount - (target.role === 'dealer' ? 1 : 0), supportCount: room.supportCount - (target.role === 'support' ? 1 : 0),
        nonGroupMemberCount: room.nonGroupMemberCount - (target.countedAsNonGroupMember ? 1 : 0), hasAvailableSlot: true,
        ...(successor ? { leaderPlayerId: successor.playerId, leaderCharacterNameSnapshot: member.characterNameSnapshot, leaderClassNameSnapshot: member.classNameSnapshot } : {}) };
      const ownershipCleanup = { expectedRevision: req.expectedRevision, targetIndex: req.targetIndex, actorIndex: req.actorIndex,
        observedOwnershipRevision: req.observedOwnershipRevision,
        ...(req.kind === 'peer' ? { leaderIndex: req.leaderIndex, observedLeaderRevision: req.observedLeaderRevision }
          : { successorIndex: req.successorIndex, priorGenerations: req.priorGenerations }) };
      const revision = room.revision + 1;
      tx.update(ref, { ...composition, revision, updatedAt: serverTimestamp(), commandTargets: [], ownershipCleanup,
        lastCommandType: req.kind === 'peer' ? 'cleanupCompletedPeerOwnership' : 'cleanupCompletedLeaderOwnership',
        lastCommandId: req.commandId, lastCommandActorPlayerId: req.actor, lastCommandAt: serverTimestamp() });
      if (tamper !== 'omit-member') tx.delete(doc(db, 'recruitments', recruitmentId, 'members', target.playerId));
      if (successor && tamper !== 'omit-successor') tx.update(doc(db, 'recruitments', recruitmentId, 'members', successor.playerId), { canApproveApplications: true, updatedAt: serverTimestamp() });
      if (tamper !== 'omit-listing') tx.update(doc(db, 'groups', room.groupId, 'raidListings', recruitmentId), { ...composition, sourceRevision: revision, updatedAt: serverTimestamp() });
      if (tamper !== 'omit-event') tx.set(eventRef, { schemaVersion: 1, eventId: req.commandId, commandId: req.commandId, recruitmentId,
        type, commandRevision: revision, expectedRevision: room.revision, actorPlayerId: req.actor,
        targetPlayerId: target.playerId, targetCharacterId: target.characterId, observedOwnershipRevision: req.observedOwnershipRevision,
        ...(successor ? { successorPlayerId: successor.playerId, priorGenerations: req.priorGenerations }
          : { leaderPlayerId: room.leaderPlayerId, observedLeaderRevision: req.observedLeaderRevision }),
        audiencePlayerIds: room.memberPlayerIds, occurredAt: serverTimestamp() });
      if (tamper === 'delete-state') tx.delete(doc(db, 'players', target.playerId, 'raidStates', `${target.characterId}_${room.raidId}`));
      return 'applied';
    });
  }
  let normal = false;
  await check('peer maximum six removals then leader succession and advance', async () => {
    await setup(); const before = await snapshot();
    for (let i = 0; i < 6; i++) {
      const req = await request();
      assert.equal(await assertSucceeds(command(req)), 'applied');
      const after = await snapshot();
      assert.equal(after.room.memberCount, 7 - i);
      assert.deepEqual(after.states, before.states); assert.deepEqual(after.group, before.group); assert.deepEqual(after.groupMembers, before.groupMembers);
      assert.deepEqual(after.listing.partySlots, after.room.partySlots);
      assert.equal(await command(req), 'already-applied'); assert.deepEqual(await snapshot(), after);
    }
    const req = await request('leader');
    await assertSucceeds(command(req));
    const after = await snapshot();
    assert.equal(after.room.memberCount, 1); assert.equal(after.room.leaderPlayerId, getSlots()[7].playerId);
    assert.equal(after.members[0].canApproveApplications, true); assert.deepEqual(after.states, before.states);
    assert.deepEqual(after.events.filter(e => !e.id.startsWith('peer-')), before.events);
    await assertSucceeds(lifecycle(client(req.actor), 'advanceCycle', { actorPlayerId: req.actor, ownershipSnapshot: true }));
    const advanced = await snapshot(); assert.deepEqual(advanced.states.slice(0, 7), before.states.slice(0, 7));
    assert.equal(advanced.states[7].status, 'active'); normal = true;
  });
  if (!normal || process.env.LEADER_PROOF_SCOPE === 'peer-chain-only') return;
  for (const scenario of ['current-target', 'unknown-target', 'current-leader', 'unknown-leader', 'stale-actor', 'outsider', 'stale-generation', 'stale-revision',
    'missing-member', 'omit-member', 'omit-event', 'omit-listing', 'remaining-slot', 'delete-state']) {
    await check(`peer rejects ${scenario} atomically`, async () => {
      await setup(); const req = await request();
      await env.withSecurityRulesDisabled(async ctx => {
        const slot = getSlots()[scenario.includes('leader') ? 0 : scenario === 'stale-actor' ? 7 : 1];
        if (scenario.startsWith('current-') || scenario === 'stale-actor') for (const ref of [doc(ctx.firestore(), 'characters', slot.characterId), doc(ctx.firestore(), 'gameAccounts', `de-account-${slot.playerId}`)])
          await updateDoc(ref, { ownerPlayerId: scenario === 'stale-actor' ? 'new-owner' : slot.playerId, ownershipRevision: scenario === 'stale-actor' ? 2 : 1 });
        if (scenario.startsWith('unknown-')) await deleteDoc(doc(ctx.firestore(), 'characters', slot.characterId));
        if (scenario === 'missing-member') await deleteDoc(doc(ctx.firestore(), 'recruitments', recruitmentId, 'members', req.targetPlayerId));
      });
      if (scenario === 'outsider') req.actor = 'outsider';
      if (scenario === 'stale-generation') req.observedOwnershipRevision--;
      if (scenario === 'stale-revision') req.expectedRevision--;
      const before = await snapshot(); await assertFails(command(req, scenario)); assert.deepEqual(await snapshot(), before);
    });
  }
  await check('peer concurrent duplicate requests converge once', async () => {
    await setup(); const req = await request(); const before = await snapshot();
    const outcome = await Promise.all([command(req), command(req)]);
    assert.ok(outcome.includes('applied')); assert.ok(outcome.every(x => ['applied', 'already-applied'].includes(x)));
    const after = await snapshot(); assert.equal(after.room.revision, before.room.revision + 1); assert.equal(after.room.memberCount, 7);
    assert.deepEqual(after.states, before.states);
  });
  await check('leader distinct valid actor and first successor', async () => {
    await setup(1); const req = await request('leader');
    await assertSucceeds(command(req)); const after = await snapshot();
    assert.equal(after.room.leaderPlayerId, getSlots()[1].playerId);
    // The persistent marker must not block the new leader's independent permission update.
    await assertSucceeds(updateDoc(doc(client(getSlots()[1].playerId), 'recruitments', recruitmentId, 'members', req.actor),
      { canApproveApplications: true, updatedAt: serverTimestamp() }));
  });
}, { skipRegression: true });
if (results.every(r => r.passed) && process.env.LEADER_PROOF_SCOPE !== 'peer-chain-only') results.push(...await runCleanupProof(rules));
fs.writeFileSync(new URL('results.json', directory), JSON.stringify(results, null, 2));
