// Differential authorization checks for the common group-member creation gate.
// Synthetic preconditions isolate this document; whole transaction checks are separate.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import {initializeTestEnvironment} from '@firebase/rules-unit-testing';
import {doc, setDoc, updateDoc, Timestamp, serverTimestamp} from 'firebase/firestore';
import {assertRulesDenied} from './assert_rules_denied.mjs';

const files = process.argv.slice(2);
assert.equal(files.length, 2, 'pass baseline and candidate');
const outcomes = [];
for (const file of files) {
  const env = await initializeTestEnvironment({projectId: 'demo-party-group-cutover',
    firestore: {host: '127.0.0.1', port: 8080, rules: fs.readFileSync(file, 'utf8')}});
  const results = [];
  try {
    for (const kind of ['created', 'invitation', 'application', 'joinCode']) {
      for (const variant of ['valid', 'forged-player', 'extra-key', 'bad-number',
        ...(process.env.GROUP_DISPLAY_LOCAL === '1' ? ['bad-display', 'forged-character'] : []), 'stale-time', 'wrong-actor']) {
        await env.clearFirestore();
        await env.withSecurityRulesDisabled(async ctx => {
          const db = ctx.firestore();
          for (const p of ['target', 'leader', 'stranger']) {
            await setDoc(doc(db, 'authBindings', p), {playerId: p, status: 'active'});
            await setDoc(doc(db, 'players', p), {status: 'active'});
          }
          await setDoc(doc(db, 'groups/g'), {status: 'active', leaderPlayerId: kind === 'created' ? 'target' : 'leader',
            memberCount: kind === 'created' ? 1 : 2, revision: 1,
            representativeCharacterId: 'c', leaderDisplayCharacterNameSnapshot: 'name'});
          await setDoc(doc(db, 'players/target/groupMembershipState/current'), {activeGroupIds: ['g']});
          await setDoc(doc(db, 'characters/c'), {ownerPlayerId: 'target', status: 'active', characterName: 'name'});
          if (kind === 'invitation' || kind === 'application') await setDoc(doc(db, 'groups/g/joinRelations/target'), {
            kind, status: 'accepted', targetPlayerId: 'target', characterIdSnapshot: 'c', characterNameSnapshot: 'name'});
        });
        const actor = variant === 'wrong-actor' ? 'stranger' : kind === 'application' ? 'leader' : 'target';
        const db = env.authenticatedContext(actor).firestore();
        const data = {schemaVersion: 1, groupId: 'g', playerId: 'target', role: kind === 'created' ? 'leader' : 'member',
          joinedBy: kind, joinSequence: kind === 'created' ? 1 : 2, revision: 1,
          displayCharacterIdSnapshot: 'c', displayCharacterNameSnapshot: 'name', displayClassNameSnapshot: 'class',
          joinedAt: serverTimestamp(), createdAt: serverTimestamp(), updatedAt: serverTimestamp()};
        if (variant === 'forged-player') data.playerId = 'stranger';
        if (variant === 'extra-key') data.admin = true;
        if (variant === 'bad-number') data.itemLevelSnapshot = 'bad';
        if (variant === 'bad-display') Object.assign(data, {displayCharacterNameSnapshot: 3,
          displayClassNameSnapshot: [], gemValidationSnapshot: false});
        if (variant === 'forged-character') data.displayCharacterIdSnapshot = 'other';
        if (variant === 'stale-time') data.updatedAt = Timestamp.fromMillis(1);
        const operation = setDoc(doc(db, 'groups/g/members/target'), data);
        if (variant === 'valid' || (process.env.GROUP_DISPLAY_LOCAL === '1' && file === files[1]
          && ['bad-number', 'bad-display'].includes(variant))) await operation;
        else if (file === files[0]) {
          // Record a pre-existing exhaustion explicitly; only the candidate must
          // reject these requests without exhausting evaluation.
          let error;
          try { await operation; } catch (e) { error = e; }
          assert.equal(error?.code, 'permission-denied', `${kind}/${variant}`);
          if (/maximum|evaluation limit|service call error/i.test(error.message))
            console.log(`BASELINE exhaustion ${kind}/${variant}`);
        } else await assertRulesDenied(operation);
        results.push(`${kind}/${variant}`);
      }
    }
    for (const operation of ['pending-invitation', 'pending-application', 'pending-reapplication', 'accept-invitation', 'accept-application', 'accept-code']) {
      for (const variant of ['valid', 'bad-revision', 'stale-time', 'extra-key', 'wrong-actor']) {
        await env.clearFirestore();
        const pending = operation.startsWith('pending');
        const kind = operation.endsWith('invitation') ? 'invitation' : 'application';
        const old = {schemaVersion: 1, groupId: 'g', targetPlayerId: 'target', kind, status: 'pending',
          requestedByPlayerId: kind === 'invitation' ? 'leader' : 'target',
          characterIdSnapshot: 'c', characterNameSnapshot: 'name', serverNameSnapshot: 'server',
          characterClassNameSnapshot: 'class', applicationAttempt: kind === 'invitation' ? 0 : 1,
          revision: 1, createdAt: Timestamp.now(), updatedAt: Timestamp.now(), decidedAt: null,
          expiresAt: Timestamp.fromMillis(Date.now() + 86400000)};
        await env.withSecurityRulesDisabled(async ctx => {
          const db = ctx.firestore();
          for (const p of ['target', 'leader', 'stranger']) {
            await setDoc(doc(db, 'authBindings', p), {playerId: p, status: 'active'});
            await setDoc(doc(db, 'players', p), {status: 'active'});
          }
          await setDoc(doc(db, 'groups/g'), {status: 'active', leaderPlayerId: 'leader'});
          await setDoc(doc(db, 'groups/g/members/leader'), {role: 'leader'});
          await setDoc(doc(db, 'players/target/groupRelations/g'), {status: 'pending'});
          await setDoc(doc(db, 'groups/g/applicantStats/target'), {applicationCount: 1});
          if (operation === 'pending-reapplication') {
            const previous = {...old, status: 'rejected'};
            delete previous.applicationAttempt;
            await setDoc(doc(db, 'groups/g/joinRelations/target'), previous);
          }
          if (!pending) {
            await setDoc(doc(db, 'groups/g/joinRelations/target'), old);
            await setDoc(doc(db, 'groups/g/members/target'), {joinedBy: operation === 'accept-code' ? 'joinCode' : kind});
          }
        });
        const actor = variant === 'wrong-actor' ? 'stranger' :
          (operation === 'pending-invitation' || operation === 'accept-application') ? 'leader' : 'target';
        const db = env.authenticatedContext(actor).firestore();
        const data = pending ? {...old, createdAt: serverTimestamp(), updatedAt: serverTimestamp()} :
          {status: 'accepted', revision: 2, decidedAt: serverTimestamp(), updatedAt: serverTimestamp()};
        if (operation === 'pending-reapplication') data.revision = 2;
        if (variant === 'bad-revision') data.revision = 9;
        if (variant === 'stale-time') data.updatedAt = Timestamp.fromMillis(1);
        if (variant === 'extra-key') data.extra = true;
        const ref = doc(db, 'groups/g/joinRelations/target');
        const write = pending ? setDoc(ref, data) : updateDoc(ref, data);
        if (variant === 'valid') await write;
        else await assertRulesDenied(write);
        results.push(`${operation}/${variant}`);
      }
    }
    outcomes.push(results);
    console.log(`PASS ${file}: member creation and forged common fields`);
  } finally { await env.cleanup(); }
}
assert.deepEqual(outcomes[0], outcomes[1]);
console.log('PASS baseline/candidate security parity; explicitly enabled display relaxations checked separately');
