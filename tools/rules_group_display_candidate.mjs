import assert from 'node:assert/strict';
import { rulesFunction } from './roster_complexity_candidate.mjs';

export function simplifyGroupDisplay(source) {
  const optional = rulesFunction(source, 'validGroupMemberOptionalNumberFields');
  source = source.replace(optional.text, optional.text.replace(
    "return (!('itemLevelSnapshot' in data)",
    "return data.displayClassNameSnapshot is string\n        && data.displayClassNameSnapshot.size() > 0\n        && (!('itemLevelSnapshot' in data)"));
  const fromRelation = rulesFunction(source, 'validGroupMemberSnapshotsFromRelation');
  const fromCharacter = rulesFunction(source, 'validGroupMemberSnapshotsFromCharacter');
  source = source.replace(fromRelation.text + '\n\n', '').replace(fromCharacter.text + '\n\n', '');
  source = source.replaceAll('validGroupMemberSnapshotsFromRelation(data, relation)', 'validGroupMemberOptionalNumberFields(data)');
  source = source.replace(/validGroupMemberSnapshotsFromCharacter\(\s*data,\s*data\.displayCharacterIdSnapshot\s*\)/g,
    'validGroupMemberOptionalNumberFields(data)');
  const refresh = rulesFunction(source, 'validGroupMemberSelfSnapshotRefresh');
  assert.ok(refresh.text.includes('&& newData.displayClassNameSnapshot == character.characterClassName'));
  source = source.replace(refresh.text, refresh.text
    .replace('      let characterId = oldData.displayCharacterIdSnapshot;\n', '')
    .replace('      let character = get(characterPath(characterId)).data;\n', '')
    .replace('        && newData.displayClassNameSnapshot == character.characterClassName\n', ''));
  assert.ok(!source.includes('validGroupMemberSnapshotsFromRelation('));
  assert.ok(!source.includes('validGroupMemberSnapshotsFromCharacter('));
  return source;
}
