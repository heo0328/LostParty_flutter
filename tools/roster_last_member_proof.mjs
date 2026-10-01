// DE2-F: existing completed-room disband boundary, demo only.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { doc, getDoc, setDoc, updateDoc, deleteDoc, runTransaction, serverTimestamp } from 'firebase/firestore';
import { assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { peerCleanupCandidate } from './roster_peer_cleanup_candidate.mjs';
import { runCleanupProof } from './roster_completed_cleanup_proof.mjs';
import { playerId, recruitmentId } from './party_group_cutover_rules_test.mjs';

const rules = peerCleanupCandidate(fs.readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'));
const directory = new URL('../coverage/roster-leader/', import.meta.url);
fs.mkdirSync(directory, { recursive: true });
fs.writeFileSync(new URL('candidate.rules', directory), rules);
fs.writeFileSync(new URL('manifest.json', directory), JSON.stringify({ sha256: createHash('sha256').update(rules).digest('hex') }));
await runCleanupProof(rules, async ({ env, db, seed, snapshot, check }) => {
  async function setup(state = 'completed') {
    await seed();
    await env.withSecurityRulesDisabled(async ctx => {
      const admin = ctx.firestore();
      const ref = doc(admin, 'recruitments', recruitmentId);
      const room = (await getDoc(ref)).data();
      const slot = room.partySlots.find(s => s.playerId === playerId);
      const patch = { partySlots: [slot], memberPlayerIds: [playerId], memberCount: 1,
        raidStateTargets: room.raidStateTargets.filter(t => t.playerId === playerId),
        dealerCount: slot.role === 'dealer' ? 1 : 0, supportCount: slot.role === 'support' ? 1 : 0,
        nonGroupMemberCount: slot.countedAsNonGroupMember ? 1 : 0, hasAvailableSlot: true };
      await updateDoc(ref, patch);
      await updateDoc(doc(admin, 'groups', room.groupId, 'raidListings', recruitmentId), patch);
      for (const old of room.partySlots.filter(s => s.playerId !== playerId)) {
        await deleteDoc(doc(admin, 'recruitments', recruitmentId, 'members', old.playerId));
      }
      for (const ownerRef of [doc(admin, 'characters', slot.characterId), doc(admin, 'gameAccounts', `de-account-${playerId}`)]) {
        await updateDoc(ownerRef, { ownerPlayerId: 'new-owner', ownershipRevision: 2 });
      }
      const stateRef = doc(admin, 'players', playerId, 'raidStates', `${slot.characterId}_${room.raidId}`);
      if (state === 'missing') await deleteDoc(stateRef);
      if (state === 'replaced') await updateDoc(stateRef, { recruitmentId: 'new-room', ownershipRevision: 3, status: 'active' });
      await setDoc(doc(admin, 'authBindings', 'last-new-owner'), { playerId: 'new-owner', status: 'active' });
    });
    const before = await snapshot();
    return { commandId: `last-disband-${before.room.revision}`, expectedRevision: before.room.revision };
  }
  async function disband(req, tamper = null, client = db, actor = playerId) {
    return runTransaction(client, async tx => {
      const roomRef = doc(client, 'recruitments', recruitmentId);
      const eventRef = doc(client, 'partyEvents', req.commandId);
      const room = (await tx.get(roomRef)).data();
      if (room.status === 'disbanded' && tamper !== 'replay-write') {
        const event = (await tx.get(eventRef)).data();
        assert.ok(event && event.type === 'disband' && event.commandId === req.commandId
          && event.commandRevision === req.expectedRevision + 1 && event.actorPlayerId === actor
          && event.recruitmentId === recruitmentId && room.lastCommandId === req.commandId, 'retry mismatch');
        return 'already-applied';
      }
      const groupRef = doc(client, 'groups', room.groupId);
      const group = (await tx.get(groupRef)).data();
      tx.update(roomRef, { status: 'disbanded', manualRecruitmentEnabled: false, hasAvailableSlot: false,
        commandTargets: [], groupActiveRecruitmentCountAfter: group.activeRecruitmentCount - 1,
        revision: req.expectedRevision + 1, lastCommandId: req.commandId, lastCommandType: 'disband',
        lastCommandActorPlayerId: actor, lastCommandAt: serverTimestamp(), updatedAt: serverTimestamp() });
      if (tamper !== 'omit-group') tx.update(groupRef, { activeRecruitmentCount: group.activeRecruitmentCount - 1,
        lastRecruitmentId: recruitmentId, revision: group.revision + 1, updatedAt: serverTimestamp() });
      if (tamper !== 'omit-listing') tx.delete(doc(client, 'groups', room.groupId, 'raidListings', recruitmentId));
      if (tamper !== 'omit-event') tx.set(eventRef, { schemaVersion: 1, eventId: req.commandId,
        commandId: req.commandId, recruitmentId, type: 'disband', commandRevision: req.expectedRevision + 1,
        audiencePlayerIds: room.memberPlayerIds, actorPlayerId: actor, occurredAt: serverTimestamp() });
      if (tamper === 'delete-state') {
        const slot = room.partySlots[0];
        tx.delete(doc(client, 'players', slot.playerId, 'raidStates', `${slot.characterId}_${room.raidId}`));
      }
      return 'applied';
    });
  }
  let normal = false;
  for (const state of ['completed', 'missing', 'replaced']) {
    await check(`last member disband preserves ${state} state and history`, async () => {
      const req = await setup(state), before = await snapshot();
      assert.equal(await assertSucceeds(disband(req)), 'applied');
      const after = await snapshot();
      assert.equal(after.room.status, 'disbanded');
      assert.equal(after.group.activeRecruitmentCount, before.group.activeRecruitmentCount - 1);
      assert.deepEqual(after.states, before.states);
      assert.deepEqual(after.members, before.members);
      assert.deepEqual(after.groupMembers, before.groupMembers);
      for (const event of before.events) assert.deepEqual(after.events.find(e => e.id === event.id), event);
      await env.withSecurityRulesDisabled(async ctx => assert.equal((await getDoc(doc(ctx.firestore(), 'groups', before.room.groupId, 'raidListings', recruitmentId))).exists(), false));
      assert.equal(await disband(req), 'already-applied');
      assert.deepEqual(await snapshot(), after);
      await assert.rejects(disband({ ...req, commandId: 'different-command' }));
      if (state === 'completed') normal = true;
    });
  }
  if (!normal) return;
  for (const tamper of ['omit-group', 'omit-listing', 'omit-event', 'delete-state', 'stale-revision', 'new-owner', 'replay-write']) {
    await check(`last member rejects ${tamper}`, async () => {
      const req = await setup();
      if (tamper === 'replay-write') await assertSucceeds(disband(req));
      const before = await snapshot();
      if (tamper === 'stale-revision') req.expectedRevision--;
      const client = tamper === 'new-owner' ? env.authenticatedContext('last-new-owner').firestore() : db;
      await assertFails(disband(req, tamper, client, tamper === 'new-owner' ? 'new-owner' : playerId));
      assert.deepEqual(await snapshot(), before);
    });
  }
}, { skipRegression: true });
