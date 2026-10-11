import fs from 'node:fs';
import assert from 'node:assert/strict';
import {initializeTestEnvironment} from '@firebase/rules-unit-testing';
import {doc, setDoc, updateDoc, Timestamp, serverTimestamp} from 'firebase/firestore';
import {assertRulesDenied} from './assert_rules_denied.mjs';

const files = process.argv.slice(2);
assert.equal(files.length, 2);
for (const file of files) {
  const env = await initializeTestEnvironment({projectId: 'demo-party-group-cutover',
    firestore: {host: '127.0.0.1', port: 8080, rules: fs.readFileSync(file, 'utf8')}});
  // Deliberately seeded after-member isolates the group document's existing
  // contract. It does not claim that a standalone membership insertion is valid.
  const cases = [
    {name: 'leader approval', actor: 'leader', delta: 1, ok: true},
    {name: 'self join', actor: 'self', delta: 1, member: true, relation: true, ok: true},
    {name: 'missing join member', actor: 'self', delta: 1, relation: true, ok: false},
    {name: 'wrong sequence', actor: 'self', delta: 1, member: true, sequence: 9, ok: false},
    {name: 'count limit', actor: 'leader', delta: 1, count: 50, ok: false},
    {name: 'extra key', actor: 'leader', delta: 1, extra: {name: 'forged'}, ok: false},
    {name: 'stale revision', actor: 'leader', delta: 1, extra: {revision: 1}, ok: false},
    {name: 'activity member', actor: 'self', member: true, ok: true},
    {name: 'activity relation', actor: 'self', relation: true, ok: true},
    {name: 'activity stranger', actor: 'self', ok: false},
    {name: 'activity missing count', actor: 'self', member: true, missingCount: true, ok: true},
    {name: 'inactive actor', actor: 'self', member: true, inactive: true, ok: false},
  ];
  try {
    for (const c of cases) {
      await env.clearFirestore();
      const count = c.count ?? 1;
      await env.withSecurityRulesDisabled(async ctx => {
        const db = ctx.firestore();
        for (const p of ['leader', 'self']) {
          await setDoc(doc(db, `authBindings/${p}`), {playerId: p, status: 'active'});
          await setDoc(doc(db, `players/${p}`), {status: c.inactive && p === c.actor ? 'inactive' : 'active'});
        }
        await setDoc(doc(db, 'groups/g'), {schemaVersion: 1, status: 'active', leaderPlayerId: 'leader',
          ...(!c.missingCount ? {memberCount: count} : {}), activeRecruitmentCount: 0,
          revision: 1, lastActivityAt: Timestamp.fromMillis(1), updatedAt: Timestamp.fromMillis(1),
          hasActiveJoinCode: false, joinCodeVisibleToMembers: false});
        if (c.member) await setDoc(doc(db, 'groups/g/members/self'), {playerId: 'self', role: 'member', joinSequence: c.sequence ?? count + 1});
        if (c.relation) await setDoc(doc(db, 'players/self/groupRelations/g'), {relation: 'member'});
      });
      const db = env.authenticatedContext(c.actor).firestore();
      const write = updateDoc(doc(db, 'groups/g'), {revision: 2, lastActivityAt: serverTimestamp(), updatedAt: serverTimestamp(),
        ...(c.delta ? {memberCount: count + c.delta} : {}), ...c.extra});
      if (c.ok) await write;
      else await assertRulesDenied(write);
      console.log(`PASS ${c.name}`);
    }
    if (file === files[1]) {
      await env.clearFirestore();
      await env.withSecurityRulesDisabled(async ctx => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'authBindings/self'), {playerId: 'self', status: 'active'});
        await setDoc(doc(db, 'players/self'), {status: 'active'});
        await setDoc(doc(db, 'groups/g/members/self'), {schemaVersion: 1, groupId: 'g', playerId: 'self',
          role: 'member', joinedAt: Timestamp.fromMillis(1), joinSequence: 2, joinedBy: 'application',
          displayCharacterIdSnapshot: 'c', revision: 1, createdAt: Timestamp.fromMillis(1)});
      });
      const db = env.authenticatedContext('self').firestore();
      await updateDoc(doc(db, 'groups/g/members/self'), {displayClassNameSnapshot: [],
        itemLevelSnapshot: 'bad', combatPowerSnapshot: -1, gemValidationSnapshot: false, updatedAt: serverTimestamp()});
      await assertRulesDenied(updateDoc(doc(db, 'groups/g/members/self'), {role: 'leader', updatedAt: serverTimestamp()}));
      await assertRulesDenied(updateDoc(doc(env.authenticatedContext('stranger').firestore(), 'groups/g/members/self'),
        {itemLevelSnapshot: 1, updatedAt: serverTimestamp()}));
      console.log('PASS missing informational name refresh; role/foreign actor denied');
    }
  } finally { await env.cleanup(); }
  console.log(`PASS group update ${file}`);
}
