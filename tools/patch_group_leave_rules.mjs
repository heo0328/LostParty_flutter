import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rulesPath = path.join(__dirname, '..', 'firestore.rules');
let rules = fs.readFileSync(rulesPath, 'utf8').replace(/\r\n/g, '\n');

const removedActiveGroupId = fs.readFileSync(
  path.join(__dirname, 'removed_active_group_id.rules.txt'),
  'utf8',
).replace(/\r\n/g, '\n');

function replaceOnce(label, from, to) {
  if (!rules.includes(from)) {
    throw new Error(`Missing patch anchor for ${label}`);
  }
  rules = rules.replace(from, to);
}

replaceOnce(
  'validGroupMemberJoinUpdate',
  `    function validGroupMemberJoinUpdate(groupId, oldData, newData) {
      let member = getAfter(groupMemberPath(groupId, currentPlayerId())).data;
      return newData.diff(oldData).affectedKeys()
          .hasOnly(['memberCount', 'revision', 'lastActivityAt', 'updatedAt'])
        && newData.memberCount == oldData.memberCount + 1
        && newData.memberCount <= 50
        && newData.revision == oldData.revision + 1
        && newData.lastActivityAt == request.time
        && newData.updatedAt == request.time
        && member.joinSequence == newData.memberCount;
    }`,
  `    function validGroupMemberJoinUpdate(groupId, oldData, newData) {
      let memberPath = groupMemberPath(groupId, currentPlayerId());
      return existsAfter(memberPath)
        && newData.diff(oldData).affectedKeys()
          .hasOnly(['memberCount', 'revision', 'lastActivityAt', 'updatedAt'])
        && newData.memberCount == oldData.memberCount + 1
        && newData.memberCount <= 50
        && newData.revision == oldData.revision + 1
        && newData.lastActivityAt == request.time
        && newData.updatedAt == request.time
        && getAfter(memberPath).data.joinSequence == newData.memberCount;
    }

${removedActiveGroupId}

    // 계약 §11a 일반 멤버 탈퇴. 그룹장은 삭제할 수 없다.
    function validGroupMemberSelfLeaveDelete(groupId, playerId, data) {
      let group = getAfter(groupPath(groupId)).data;
      return hasActiveBinding()
        && playerId == currentPlayerId()
        && data.role == 'member'
        && data.playerId == playerId
        && group.status == 'active'
        && group.memberCount == get(groupPath(groupId)).data.memberCount - 1
        && !existsAfter(groupMemberPath(groupId, playerId))
        && !existsAfter(groupRelationPath(playerId, groupId));
    }

    function validGroupMemberLeaveUpdate(groupId, oldData, newData) {
      return isCurrentPlayerActive()
        && oldData.status == 'active'
        && newData.diff(oldData).affectedKeys()
          .hasOnly(['memberCount', 'revision', 'lastActivityAt', 'updatedAt'])
        && newData.memberCount == oldData.memberCount - 1
        && newData.memberCount >= 1
        && newData.revision == oldData.revision + 1
        && newData.lastActivityAt == request.time
        && newData.updatedAt == request.time
        && !existsAfter(groupMemberPath(groupId, currentPlayerId()));
    }

    function validMembershipStateRemove(playerId, docId, oldData, newData) {
      let previousIds = oldData.activeGroupIds;
      let removedGroupId = removedActiveGroupId(
        previousIds,
        newData.activeGroupIds
      );
      return hasActiveBinding()
        && playerId == currentPlayerId()
        && docId == 'current'
        && newData.keys().hasOnly([
          'schemaVersion', 'playerId', 'activeGroupIds', 'activeGroupCount',
          'revision', 'updatedAt'
        ])
        && newData.schemaVersion == 1
        && newData.playerId == playerId
        && newData.activeGroupIds is list
        && newData.activeGroupIds.size() == previousIds.size() - 1
        && previousIds.toSet().difference(newData.activeGroupIds.toSet()).size()
          == 1
        && newData.activeGroupCount == newData.activeGroupIds.size()
        && newData.revision == oldData.revision + 1
        && newData.updatedAt == request.time
        && removedGroupId != ''
        && !existsAfter(groupMemberPath(removedGroupId, playerId))
        && !existsAfter(groupRelationPath(playerId, removedGroupId));
    }

    function validGroupMemberLeaveRelationDelete(playerId, groupId) {
      let group = getAfter(groupPath(groupId)).data;
      return hasActiveBinding()
        && playerId == currentPlayerId()
        && group.status == 'active'
        && group.memberCount == get(groupPath(groupId)).data.memberCount - 1
        && !existsAfter(groupMemberPath(groupId, playerId));
    }`,
);

replaceOnce(
  'validMembershipStateAdd',
  `    function validMembershipStateAdd(playerId, docId, oldData, newData) {
      let previousIds = oldData == null ? [] : oldData.activeGroupIds;
      let previousRevision = oldData == null ? 0 : oldData.revision;
      let addedGroupId = newData.activeGroupIds[
        newData.activeGroupIds.size() - 1
      ];
      let member = getAfter(groupMemberPath(addedGroupId, playerId)).data;
      return hasActiveBinding()
        && playerId == currentPlayerId()
        && docId == 'current'
        && newData.keys().hasOnly([
          'schemaVersion', 'playerId', 'activeGroupIds', 'activeGroupCount',
          'revision', 'updatedAt'
        ])
        && newData.schemaVersion == 1
        && newData.playerId == playerId
        && newData.activeGroupIds is list
        && newData.activeGroupIds.size() == previousIds.size() + 1
        && newData.activeGroupIds.size() <= 50
        && newData.activeGroupIds.toSet().size()
          == newData.activeGroupIds.size()
        && newData.activeGroupIds.toSet().difference(previousIds.toSet())
          == [addedGroupId].toSet()
        && newData.activeGroupCount == newData.activeGroupIds.size()
        && newData.revision == previousRevision + 1
        && newData.updatedAt == request.time
        && member.playerId == playerId;
    }`,
  `    function validMembershipStateAdd(playerId, docId, oldData, newData) {
      let previousIds = oldData == null ? [] : oldData.activeGroupIds;
      let previousRevision = oldData == null ? 0 : oldData.revision;
      return hasActiveBinding()
        && playerId == currentPlayerId()
        && docId == 'current'
        && newData.keys().hasOnly([
          'schemaVersion', 'playerId', 'activeGroupIds', 'activeGroupCount',
          'revision', 'updatedAt'
        ])
        && newData.schemaVersion == 1
        && newData.playerId == playerId
        && newData.activeGroupIds is list
        && newData.activeGroupIds.size() == previousIds.size() + 1
        && newData.activeGroupIds.size() > 0
        && validMembershipStateAddMember(
          playerId,
          newData.activeGroupIds[newData.activeGroupIds.size() - 1],
          newData,
          previousIds,
          previousRevision
        );
    }

    function validMembershipStateAddMember(
      playerId,
      addedGroupId,
      newData,
      previousIds,
      previousRevision
    ) {
      let member = getAfter(groupMemberPath(addedGroupId, playerId)).data;
      return newData.activeGroupIds is list
        && newData.activeGroupIds.size() == previousIds.size() + 1
        && newData.activeGroupIds.size() <= 50
        && newData.activeGroupIds.toSet().size()
          == newData.activeGroupIds.size()
        && newData.activeGroupIds.toSet().difference(previousIds.toSet())
          == [addedGroupId].toSet()
        && newData.activeGroupCount == newData.activeGroupIds.size()
        && newData.revision == previousRevision + 1
        && newData.updatedAt == request.time
        && member.playerId == playerId;
    }`,
);

if (!rules.includes('function validGroupMemberDocumentKeys(data)')) {
  replaceOnce(
    'validGroupJoinRelationKeys insert',
    `    function validGroupJoinRelationKeys(data) {
      return data.keys().hasOnly([
        'schemaVersion', 'groupId', 'targetPlayerId', 'kind', 'status',
        'requestedByPlayerId', 'characterIdSnapshot', 'characterNameSnapshot',
        'serverNameSnapshot', 'characterClassNameSnapshot', 'itemLevelSnapshot',
        'combatPowerSnapshot', 'applicationAttempt', 'revision', 'createdAt',
        'expiresAt', 'decidedAt', 'updatedAt'
      ]);
    }`,
    `    function validGroupJoinRelationKeys(data) {
      return data.keys().hasOnly([
        'schemaVersion', 'groupId', 'targetPlayerId', 'kind', 'status',
        'requestedByPlayerId', 'characterIdSnapshot', 'characterNameSnapshot',
        'serverNameSnapshot', 'characterClassNameSnapshot', 'itemLevelSnapshot',
        'combatPowerSnapshot', 'applicationAttempt', 'revision', 'createdAt',
        'expiresAt', 'decidedAt', 'updatedAt'
      ]);
    }

    function validGroupMemberDocumentKeys(data) {
      return data.keys().hasOnly([
        'schemaVersion', 'groupId', 'playerId', 'role', 'joinedAt',
        'joinSequence', 'joinedBy', 'displayCharacterIdSnapshot',
        'displayCharacterNameSnapshot', 'displayClassNameSnapshot',
        'itemLevelSnapshot', 'combatPowerSnapshot',
        'revision', 'createdAt', 'updatedAt'
      ]);
    }

    function validGroupMemberOptionalNumberFields(data) {
      return (data.itemLevelSnapshot == null || data.itemLevelSnapshot is number)
        && (data.combatPowerSnapshot == null
          || data.combatPowerSnapshot is number);
    }

    function validGroupMemberSnapshotsFromRelation(data, relation) {
      return data.displayClassNameSnapshot == relation.characterClassNameSnapshot
        && data.itemLevelSnapshot == relation.itemLevelSnapshot
        && data.combatPowerSnapshot == relation.combatPowerSnapshot
        && validGroupMemberOptionalNumberFields(data);
    }

    function validGroupMemberSnapshotsFromCharacter(data, characterId) {
      let character = get(characterPath(characterId)).data;
      return data.displayClassNameSnapshot == character.characterClassName
        && validGroupMemberOptionalNumberFields(data)
        && (
          data.combatPowerSnapshot == null
          || (character.combatPower is number
            && data.combatPowerSnapshot == character.combatPower)
        );
    }`,
  );
}

replaceOnce(
  'groupMembershipState update',
  `        allow update: if validMembershipStateAdd(
          playerId,
          docId,
          resource.data,
          request.resource.data
        ) || validLeaderApprovedMembershipStateAdd(
          playerId,
          docId,
          resource.data,
          request.resource.data
        );`,
  `        allow update: if validMembershipStateRemove(
          playerId,
          docId,
          resource.data,
          request.resource.data
        ) || validMembershipStateAdd(
          playerId,
          docId,
          resource.data,
          request.resource.data
        ) || validLeaderApprovedMembershipStateAdd(
          playerId,
          docId,
          resource.data,
          request.resource.data
        );`,
);

replaceOnce(
  'groupRelations delete',
  `        allow delete: if false;
      }

      match /weeklyRaidClaims/{claimId} {`,
  `        allow delete: if validGroupMemberLeaveRelationDelete(playerId, groupId);
      }

      match /weeklyRaidClaims/{claimId} {`,
);

replaceOnce(
  'groups update',
  `      allow update: if validGroupLeaderApproveUpdate(
        resource.data,
        request.resource.data
      ) || validGroupJoinCodeFlagUpdate(
        resource.data,
        request.resource.data
      ) || validGroupJoinCodeVisibilityUpdate(
        resource.data,
        request.resource.data
      ) || validGroupJoinCommandUpdate(
        groupId,
        resource.data,
        request.resource.data
      );`,
  `      // 일반 멤버 탈퇴는 join·승인 경로보다 먼저 판정한다.
      allow update: if validGroupMemberLeaveUpdate(
        groupId,
        resource.data,
        request.resource.data
      ) || validGroupLeaderApproveUpdate(
        resource.data,
        request.resource.data
      ) || validGroupJoinCodeFlagUpdate(
        resource.data,
        request.resource.data
      ) || validGroupJoinCodeVisibilityUpdate(
        resource.data,
        request.resource.data
      ) || validGroupJoinCommandUpdate(
        groupId,
        resource.data,
        request.resource.data
      );`,
);

replaceOnce(
  'members delete',
  `        allow update, delete: if false;
      }

      // Unit 4는 초대·신청 처리에 더해 코드 가입이 pending 요청을`,
  `        allow update: if false;
        allow delete: if validGroupMemberSelfLeaveDelete(
          groupId,
          playerId,
          resource.data
        );
      }

      // Unit 4는 초대·신청 처리에 더해 코드 가입이 pending 요청을`,
);

fs.writeFileSync(rulesPath, rules.replace(/\n/g, '\r\n'), 'utf8');
console.log('Patched firestore.rules');
