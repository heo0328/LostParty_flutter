// DE2-E. Reuse D regression/fixtures, then prove bounded leader succession.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { doc, getDoc, setDoc, updateDoc, deleteDoc, runTransaction, serverTimestamp } from 'firebase/firestore';
import { assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { leaderCleanupCandidate } from './roster_leader_cleanup_candidate.mjs';
import { runCleanupProof } from './roster_completed_cleanup_proof.mjs';
import { lifecycle } from './roster_ownership_rules_proof.mjs';
import { playerId, recruitmentId } from './party_group_cutover_rules_test.mjs';

const rules = leaderCleanupCandidate(fs.readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'));
const directory = new URL('../coverage/roster-leader/', import.meta.url);
fs.mkdirSync(directory, { recursive: true });
fs.writeFileSync(new URL('candidate.rules', directory), rules);
fs.writeFileSync(new URL('manifest.json', directory), JSON.stringify({ sha256: createHash('sha256').update(rules).digest('hex') }));
const results = await runCleanupProof(rules, async ({ env, selfDb, seed, snapshot, check, getSlots }) => {
  async function setup(lastOnly = false) {
    await seed();
    const slots = getSlots();
    await env.withSecurityRulesDisabled(async ctx => {
      for (const [index, slot] of slots.entries()) {
        const stale = index === 0 || (lastOnly && index < 7);
        for (const ref of [doc(ctx.firestore(), 'characters', slot.characterId), doc(ctx.firestore(), 'gameAccounts', `de-account-${slot.playerId}`)]) {
          await updateDoc(ref, { ownerPlayerId: stale ? 'new-owner' : slot.playerId, ownershipRevision: stale ? 2 : 1 });
        }
        await setDoc(doc(ctx.firestore(), 'authBindings', `leader-proof-${index}`), { playerId: slot.playerId, status: 'active' });
      }
    });
    const before = await snapshot(), successorIndex = lastOnly ? 7 : 1;
    return { commandId: 'leader-cleanup-command', expectedRevision: before.room.revision,
      targetIndex: 0, actorIndex: successorIndex, successorIndex,
      observedOwnershipRevision: 2, priorGenerations: slots.map((_, i) => i < successorIndex ? 2 : 1) };
  }
  async function command(request, tamper = null) {
    const slots = getSlots(), actor = slots[request.actorIndex].playerId;
    const client = env.authenticatedContext(`leader-proof-${request.actorIndex}`).firestore();
    return runTransaction(client, async tx => {
      const ref = doc(client, 'recruitments', recruitmentId);
      const room = (await tx.get(ref)).data();
      const eventRef = doc(client, 'partyEvents', request.commandId);
      if (!room.memberPlayerIds.includes(playerId)) {
        const event = (await tx.get(eventRef)).data();
        assert.ok(event && event.type === 'ownershipLeaderRemoved' && event.commandId === request.commandId
          && event.recruitmentId === recruitmentId && event.targetPlayerId === playerId
          && event.targetCharacterId === slots[0].characterId && event.actorPlayerId === actor
          && event.successorPlayerId === slots[request.successorIndex].playerId
          && event.expectedRevision === request.expectedRevision
          && event.observedOwnershipRevision === request.observedOwnershipRevision, 'retry mismatch');
        assert.deepEqual(event.priorGenerations, request.priorGenerations);
        return 'already-applied';
      }
      const target = room.partySlots[request.targetIndex], successor = room.partySlots[request.successorIndex];
      const successorRef = doc(client, 'recruitments', recruitmentId, 'members', successor.playerId);
      const member = (await tx.get(successorRef)).data();
      const remaining = room.partySlots.filter(s => s.playerId !== target.playerId);
      const composition = { partySlots: remaining, memberPlayerIds: remaining.map(s => s.playerId),
        memberCount: remaining.length, raidStateTargets: room.raidStateTargets.filter(s => s.playerId !== target.playerId),
        dealerCount: room.dealerCount - (target.role === 'dealer' ? 1 : 0),
        supportCount: room.supportCount - (target.role === 'support' ? 1 : 0),
        nonGroupMemberCount: room.nonGroupMemberCount - (target.countedAsNonGroupMember ? 1 : 0), hasAvailableSlot: true,
        leaderPlayerId: successor.playerId, leaderCharacterNameSnapshot: tamper === 'name' ? 'forged' : member.characterNameSnapshot,
        leaderClassNameSnapshot: member.classNameSnapshot };
      const revision = room.revision + 1;
      const { commandId, ...ownershipCleanup } = request;
      tx.update(ref, { ...composition, revision, updatedAt: serverTimestamp(), commandTargets: [],
        lastCommandType: 'cleanupCompletedLeaderOwnership', lastCommandId: commandId,
        lastCommandActorPlayerId: actor, lastCommandAt: serverTimestamp(), ownershipCleanup });
      if (tamper !== 'omit-member') tx.delete(doc(client, 'recruitments', recruitmentId, 'members', target.playerId));
      if (tamper !== 'omit-successor') tx.update(successorRef, { canApproveApplications: tamper !== 'permission', updatedAt: serverTimestamp() });
      if (tamper !== 'omit-listing') tx.update(doc(client, 'groups', room.groupId, 'raidListings', recruitmentId), {
        ...composition, sourceRevision: revision, updatedAt: serverTimestamp(),
        ...(tamper === 'listing-leader' ? { leaderPlayerId: playerId } : {}) });
      if (tamper !== 'omit-event') tx.set(eventRef, { schemaVersion: 1, eventId: commandId, commandId, recruitmentId,
        type: 'ownershipLeaderRemoved', commandRevision: revision, expectedRevision: room.revision,
        actorPlayerId: actor, targetPlayerId: target.playerId, targetCharacterId: target.characterId,
        successorPlayerId: successor.playerId, observedOwnershipRevision: request.observedOwnershipRevision,
        priorGenerations: request.priorGenerations, audiencePlayerIds: room.memberPlayerIds, occurredAt: serverTimestamp() });
      return 'applied';
    });
  }
  let simplePassed = false;
  await check('leader succession first eligible and repeat', async () => {
    const request = await setup(), before = await snapshot();
    assert.equal(await assertSucceeds(command(request)), 'applied');
    const after = await snapshot();
    assert.equal(after.room.leaderPlayerId, 'player-2');
    assert.equal(after.room.memberCount, 7);
    assert.equal(after.members.find(m => m.id === 'player-2').canApproveApplications, true);
    assert.deepEqual(after.states, before.states);
    assert.deepEqual(after.group, before.group);
    assert.deepEqual(after.groupMembers, before.groupMembers);
    assert.deepEqual(after.events.filter(e => e.id !== request.commandId), before.events);
    assert.equal(after.listing.leaderPlayerId, 'player-2');
    assert.equal(await command(request), 'already-applied');
    assert.deepEqual(await snapshot(), after);
    await assert.rejects(command({ ...request, successorIndex: 2 }), /retry mismatch/);
    await assertSucceeds(lifecycle(selfDb, 'advanceCycle', { actorPlayerId: 'player-2', ownershipSnapshot: true }));
    const advanced = await snapshot();
    assert.deepEqual(advanced.states[0], before.states[0]);
    assert.ok(advanced.states.slice(1).every(s => s.status === 'active'));
    simplePassed = true;
  });
  if (simplePassed) {
    for (const scenario of ['later-successor', 'stale-actor', 'unknown-prior', 'stale-revision', 'stale-generation',
      'name', 'permission', 'omit-member', 'omit-successor', 'omit-listing', 'omit-event', 'listing-leader']) {
      await check(`leader rejects ${scenario} atomically`, async () => {
        const request = await setup();
        if (scenario === 'later-successor') request.successorIndex = 2;
        if (scenario === 'stale-revision') request.expectedRevision--;
        if (scenario === 'stale-generation') request.observedOwnershipRevision--;
        await env.withSecurityRulesDisabled(async ctx => {
          if (scenario === 'stale-actor') await updateDoc(doc(ctx.firestore(), 'characters', getSlots()[1].characterId), { ownershipRevision: 2, ownerPlayerId: 'new-owner' });
          if (scenario === 'unknown-prior') {
            request.successorIndex = 2; request.actorIndex = 2;
            await deleteDoc(doc(ctx.firestore(), 'characters', getSlots()[1].characterId));
          }
        });
        const before = await snapshot();
        await assertFails(command(request, scenario));
        assert.deepEqual(await snapshot(), before);
      });
    }
    // A legitimate maximum scan. Failure is a scalability blocker, never a security pass.
    await check('leader maximum scan last eligible', async () => {
      const request = await setup(true), before = await snapshot();
      try { await assertSucceeds(command(request)); }
      catch (error) { assert.deepEqual(await snapshot(), before); throw error; }
      const after = await snapshot();
      assert.equal(after.room.leaderPlayerId, getSlots()[7].playerId);
      assert.deepEqual(after.states, before.states);
      assert.equal(after.room.memberCount, 7);
    });
  }
});
fs.writeFileSync(new URL('results.json', directory), JSON.stringify(results, null, 2));
