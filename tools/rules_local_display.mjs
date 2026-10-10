import assert from 'node:assert/strict';
import {rulesFunction} from './roster_complexity_candidate.mjs';

// Display provenance is a client responsibility. Identity, authority, relation
// state, counters and atomic links remain server-enforced.
export function localizeGroupDisplay(input) {
  let source=input;
  const edit=(name,fn)=>{const f=rulesFunction(source,name);source=source.slice(0,f.start)+fn(f.text)+source.slice(f.end);};
  const members=['validInitialMemberGroupRelation','validAcceptedGroupRelation','validLeaderApprovedGroupRelation','validJoinCodeMemberGroupRelation'];
  for(const name of [...members,'validGroupRequestRelation'])edit(name,text=>{
    text=text.replace(/\s*&& data\.groupNameSnapshot == group\.name/,'')
      .replace(/\s*&& data\.displayCharacterNameSnapshot\s*== (?:member\.displayCharacterNameSnapshot|relation\.characterNameSnapshot)/,'');
    if(name!=='validLeaderApprovedGroupRelation')text=text.replace('let group = getAfter(groupPath(groupId)).data;', '');
    // The common allow gate below now owns these identical checks.
    text=text.replace(/\s*&& validGroupRelationProjectionKeys\(data\)/,'')
      .replace(/\s*&& data\.keys\(\)\.hasOnly\(\[[\s\S]*?\]\)/,'')
      .replace(/\s*&& data\.schemaVersion == 1/,'')
      .replace(/\s*&& data\.groupId == groupId/,'')
      .replace(/\s*&& data\.playerId == playerId/,'')
      .replace(/\s*&& data\.createdAt is timestamp/,'')
      .replace(/\s*&& data\.updatedAt == request\.time/,'');
    return text;
  });
  edit('validGroupRelationProjectionKeys',text=>text.replace('function validGroupRelationProjectionKeys(data)',
    'function validGroupRelationProjectionKeys(playerId, groupId, data)').replace('return data.keys()',
    `return data.schemaVersion == 1 && data.groupId == groupId && data.playerId == playerId
        && data.createdAt is timestamp && data.updatedAt == request.time
        && existsAfter(groupPath(groupId))
        && data.groupNameSnapshot is string && data.groupNameSnapshot.size() <= 256
        && data.displayCharacterNameSnapshot is string && data.displayCharacterNameSnapshot.size() <= 256
        && data.keys()`));
  const start=source.indexOf('      match /groupRelations/{groupId} {');
  const end=source.indexOf('      match /weeklyRaidClaims/{claimId} {',start);
  assert.ok(start>0&&end>start);
  const block=source.slice(start,end),prefix='        allow create, update: if ',a=block.indexOf(prefix),b=block.indexOf(';',a);
  assert.ok(a>0&&b>a);
  source=source.slice(0,start)+block.slice(0,a)+prefix+
    'validGroupRelationProjectionKeys(playerId, groupId, request.resource.data) && ('+
    block.slice(a+prefix.length,b)+')'+block.slice(b)+source.slice(end);
  for(const [name,fields] of [
    ['validGroupApplicantStatsWrite',[['lastCharacterNameSnapshot','characterNameSnapshot'],['lastItemLevelSnapshot','itemLevelSnapshot'],['lastCombatPowerSnapshot','combatPowerSnapshot']]],
    ['validGroupBlockCreate',[['characterNameSnapshot','characterNameSnapshot'],['itemLevelSnapshot','itemLevelSnapshot'],['combatPowerSnapshot','combatPowerSnapshot']]],
  ])edit(name,text=>{
    for(const [field,original] of fields){
      const from=`data.${field} == relation.${original}`;
      assert.ok(text.includes(from));
      text=text.replace(from,field.includes('Name')?`data.${field} is string && data.${field}.size() <= 256`:
        `(data.${field} == null || data.${field} is number)`);
    }
    return text;
  });
  // Pending requests and decisions have disjoint output states. Dispatch once
  // rather than evaluating every create/reissue/decision validator on rejection.
  const joinStart=source.indexOf('      match /joinRelations/{playerId} {');
  const grant=source.indexOf('        allow create:',joinStart);
  const grantEnd=source.indexOf('        allow delete: if false;',grant);
  assert.ok(joinStart>0&&grant>joinStart&&grantEnd>grant);
  source=source.slice(0,grant)+`        allow create: if request.resource.data.kind == 'invitation'
          ? validGroupInvitationCreate(groupId, playerId, 0, 0, true, request.resource.data)
          : validGroupApplicationCreate(groupId, playerId, 0, true, request.resource.data);
        allow update: if request.resource.data.status == 'pending'
          ? (request.resource.data.kind == 'invitation'
            ? validGroupInvitationCreate(groupId, playerId, resource.data.revision,
                resource.data.applicationAttempt, reusableGroupJoinRelation(resource.data), request.resource.data)
            : validGroupApplicationCreate(groupId, playerId, resource.data.revision,
                reusableGroupJoinRelation(resource.data), request.resource.data))
          : ((resource.data.kind == 'application' && resource.data.status == 'pending'
              && request.resource.data.status in ['accepted', 'rejected', 'blocked']
              && validGroupApplicationDecision(groupId, playerId, resource.data, request.resource.data))
            || validGroupJoinRelationDecision(groupId, playerId, resource.data, request.resource.data)
            || validJoinCodeRelationAccept(groupId, playerId, resource.data, request.resource.data));
`+source.slice(grantEnd);
  return source;
}
