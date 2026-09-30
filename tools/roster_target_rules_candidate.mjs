// B7 demo-only transformation; never deploy this generated candidate.
import assert from 'node:assert/strict';
export function sharedTargetStatus(source) {
  const start = source.indexOf('    function atomicAllTargetsMatch(data) {');
  const end = source.indexOf('    function atomicValidLifecycleShape(', start);
  assert.ok(start > 0 && end > start);
  const original = source.slice(start, end);
  const calls = Array.from({ length: 8 }, (_, index) => `atomicTargetMatchesTransition(data, ${index})`).join('\n        && ');
  assert.equal(original.split(calls).length, 2);
  const helpers = `    function atomicExpectedTargetStateMatches(data, state, expectedStatus) {
      return state.recruitmentId == data.recruitmentId
        && state.cycleKey == data.currentCycleKey
        && state.status == expectedStatus;
    }

    function atomicExpectedTargetMatches(data, index, expectedStatus) {
      return index >= data.commandTargets.size()
        || atomicExpectedTargetStateMatches(data,
          getAfter(atomicRaidStatePath(data.commandTargets[index])).data, expectedStatus);
    }

    function atomicAllExpectedTargetsMatch(data, expectedStatus) {
      return ${Array.from({ length: 8 }, (_, index) => `atomicExpectedTargetMatches(data, ${index}, expectedStatus)`).join('\n        && ')};
    }

`;
  const replaced = original.replace(calls, `((data.lastCommandType == 'complete' || data.lastCommandType == 'advanceCycle')
          ? atomicAllExpectedTargetsMatch(data, data.lastCommandType == 'complete' ? 'completed' : 'active')
          : (${calls}))`);
  return source.slice(0, start) + helpers + replaced + source.slice(end);
}
