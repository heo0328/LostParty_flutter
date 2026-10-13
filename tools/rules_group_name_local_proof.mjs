import fs from 'node:fs';
import assert from 'node:assert/strict';
import {initializeTestEnvironment} from '@firebase/rules-unit-testing';
import {doc, writeBatch, setDoc, getDoc, getDocs, query, collection, where, orderBy, limit, serverTimestamp, Timestamp} from 'firebase/firestore';
import {assertRulesDenied} from './assert_rules_denied.mjs';
import {seedBase, authUid, playerId, characterId} from './party_group_cutover_rules_test.mjs';

const files = ['coverage/rules-group-name-local/before.rules', 'firestore.rules'];
const results = [];
for (const [version, file] of files.entries()) {
  const env = await initializeTestEnvironment({projectId: 'demo-party-group-cutover',
    firestore: {host: '127.0.0.1', port: 8080, rules: fs.readFileSync(file, 'utf8')}});
  const cases = [
    {name: 'normal bounded search', ok: true},
    {name: 'malformed informational name', patch: {name: 42}, localOnly: true},
    {name: 'missing informational name', omitName: true, localOnly: true},
    {name: 'control character name', patch: {name: '\u0000bad'}, localOnly: true},
    {name: 'malformed search projections', patch: {normalizedName: [], normalizedRepresentativeCharacterName: null}, localOnly: true},
    {name: 'foreign representative', foreign: true},
    {name: 'inactive binding', inactiveBinding: true},
    {name: 'inactive player', inactivePlayer: true},
    {name: 'missing member', omit: 'member'},
    {name: 'missing membership state', omit: 'state'},
    {name: 'missing relation', omit: 'relation'},
    {name: 'foreign leader ID', patch: {leaderPlayerId: 'foreign'}},
    {name: 'wrong initial count', patch: {memberCount: 2}},
    {name: 'group limit exceeded', atLimit: true},
  ];
  try {
    for (const c of cases) {
      await env.clearFirestore();
      const ids = c.atLimit ? Array.from({length: 50}, (_, i) => `old-${i}`) : [];
      await seedBase(env, {membershipState: c.atLimit ? {schemaVersion: 1, playerId,
        activeGroupIds: ids, activeGroupCount: 50, revision: 1, updatedAt: Timestamp.now()} : null});
      await env.withSecurityRulesDisabled(async ctx => {
        const db = ctx.firestore();
        if (c.foreign) await setDoc(doc(db, `characters/${characterId}`), {ownerPlayerId: 'foreign'}, {merge: true});
        if (c.inactiveBinding) await setDoc(doc(db, `authBindings/${authUid}`), {status: 'inactive'}, {merge: true});
        if (c.inactivePlayer) await setDoc(doc(db, `players/${playerId}`), {status: 'inactive'}, {merge: true});
      });
      const db = env.authenticatedContext(authUid).firestore();
      const groupId = 'new-group';
      const paths = {group: `groups/${groupId}`, member: `groups/${groupId}/members/${playerId}`,
        state: `players/${playerId}/groupMembershipState/current`, relation: `players/${playerId}/groupRelations/${groupId}`};
      const group = {schemaVersion: 1, status: 'active', name: '테스트의 그룹', normalizedName: '테스트의 그룹',
        representativeCharacterId: characterId, representativeCharacterNameSnapshot: '테스트',
        normalizedRepresentativeCharacterName: '테스트', representativeServerNameSnapshot: '루페온',
        leaderPlayerId: playerId, leaderDisplayCharacterNameSnapshot: '테스트', memberCount: 1,
        activeRecruitmentCount: 0, revision: 1, hasActiveJoinCode: false, joinCodeVisibleToMembers: false,
        lastActivityAt: serverTimestamp(), createdAt: serverTimestamp(), updatedAt: serverTimestamp(), deletedAt: null,
        ...c.patch};
      if (c.omitName) delete group.name;
      const docs = {group, member: {schemaVersion: 1, groupId, playerId, role: 'leader', joinedBy: 'created',
        joinSequence: 1, displayCharacterIdSnapshot: characterId, displayCharacterNameSnapshot: '테스트',
        revision: 1, joinedAt: serverTimestamp(), createdAt: serverTimestamp(), updatedAt: serverTimestamp()},
      state: {schemaVersion: 1, playerId, activeGroupIds: [...ids, groupId], activeGroupCount: ids.length + 1,
        revision: c.atLimit ? 2 : 1, updatedAt: serverTimestamp()},
      relation: {schemaVersion: 1, groupId, playerId, relation: 'member', requestStatus: null,
        groupNameSnapshot: '테스트의 그룹', displayCharacterNameSnapshot: '테스트', expiresAt: null,
        sourceRevision: 1, createdAt: serverTimestamp(), updatedAt: serverTimestamp()}};
      const batch = writeBatch(db);
      for (const [key, data] of Object.entries(docs)) if (c.omit !== key) batch.set(doc(db, paths[key]), data);
      const expected = Boolean(c.ok || (c.localOnly && version === 1));
      if (expected) await batch.commit();
      else {
        await assertRulesDenied(batch.commit());
        await env.withSecurityRulesDisabled(async ctx => {
          for (const key of ['group', 'member', 'relation'])
            assert.equal((await getDoc(doc(ctx.firestore(), paths[key]))).exists(), false, `${c.name}: atomic ${key}`);
          const state = await getDoc(doc(ctx.firestore(), paths.state));
          assert.deepEqual(state.exists() ? state.data().activeGroupIds : [], ids, `${c.name}: state unchanged`);
        });
      }
      if (c.ok) {
        const found = await getDocs(query(collection(db, 'groups'), where('status', '==', 'active'),
          orderBy('normalizedName'), where('normalizedName', '>=', '테스트'),
          where('normalizedName', '<=', '테스트\uf8ff'), limit(20)));
        assert.deepEqual(found.docs.map(d => d.id), [groupId]);
      }
      results.push({version: version ? 'after' : 'before', name: c.name, allowed: expected});
      console.log(`PASS ${version ? 'after' : 'before'} ${c.name}`);
    }
  } finally { await env.cleanup(); }
}
fs.writeFileSync('coverage/rules-group-name-local/decisions.json', JSON.stringify(results, null, 2));
