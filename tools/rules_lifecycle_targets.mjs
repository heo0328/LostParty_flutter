import assert from 'node:assert/strict';
import {rulesFunction} from './roster_complexity_candidate.mjs';

// Complete/advance already have the same room/cycle/status contract in the
// transition helper. Keep its index guard and the disband absence branch.
export function unifyLifecycleTargets(source) {
  for (const name of ['atomicExpectedTargetStateMatches',
    'atomicExpectedTargetMatches', 'atomicAllExpectedTargetsMatch']) {
    const fn = rulesFunction(source, name);
    source = source.slice(0, fn.start) + source.slice(fn.end);
  }
  const fn = rulesFunction(source, 'atomicAllTargetsMatch');
  const branch = `&& ((data.lastCommandType == 'complete' || data.lastCommandType == 'advanceCycle')
          ? atomicAllExpectedTargetsMatch(data, data.lastCommandType == 'complete' ? 'completed' : 'active')
          : (atomicTargetMatchesTransition(data, 0)`;
  const start = fn.text.indexOf("&& ((data.lastCommandType == 'complete'");
  const end = fn.text.indexOf('atomicTargetMatchesTransition(data, 0)', start)
    + 'atomicTargetMatchesTransition(data, 0)'.length;
  assert.ok(start >= 0 && end > start);
  assert.equal(fn.text.slice(start,end).replace(/\s+/g,''), branch.replace(/\s+/g,''),
    'Expected historical target dispatcher');
  const text = (fn.text.slice(0,start) + '&& (atomicTargetMatchesTransition(data, 0)' + fn.text.slice(end))
    .replace('atomicTargetMatchesTransition(data, 7)));', 'atomicTargetMatchesTransition(data, 7));');
  assert.notEqual(text, fn.text);
  source = source.slice(0, fn.start) + text + source.slice(fn.end);
  // Calculate the expected status once, preserving the earlier status-only
  // optimization without retaining a second eight-target call tree.
  source = source.replace('function atomicAllTargetsMatch(data) {',
    "function atomicAllTargetsMatch(data) {\n      let expectedStatus = data.lastCommandType == 'complete' ? 'completed' : 'active';")
    .replace('&& (atomicTargetMatchesTransition(data, 0)',
      "&& (data.commandTargets.size() == 0 || data.lastCommandType in ['complete', 'advanceCycle', 'disband'])\n        && (atomicTargetMatchesTransition(data, 0)");
  source = source.replace(/atomicTargetMatchesTransition\(data, ([0-7])\)/g,
    'atomicTargetMatchesTransition(data, $1, expectedStatus)');
  source = source.replace('function atomicTargetMatchesTransition(data, index)',
    'function atomicTargetMatchesTransition(data, index, expectedStatus)');
  const transition = rulesFunction(source, 'atomicTargetMatchesTransition');
  const stateRead = 'getAfter(atomicRaidStatePath(data.commandTargets[index])).data';
  assert.ok(transition.text.includes(stateRead));
  // Select the deletion branch once per target, instead of evaluating both
  // command equality tests and the redundant OR on every non-disband target.
  source = source.slice(0, transition.start) + `function atomicTargetMatchesTransition(data, index, expectedStatus) {
        return index >= data.commandTargets.size()
          || (data.lastCommandType == 'disband'
            ? !existsAfter(atomicRaidStatePath(data.commandTargets[index]))
            : atomicTargetStateMatches(data,
              ${stateRead}, expectedStatus));
      }` + source.slice(transition.end);
  const state = rulesFunction(source, 'atomicTargetStateMatches');
  source = source.slice(0, state.start) + `function atomicTargetStateMatches(data, state, expectedStatus) {
      return state.recruitmentId == data.recruitmentId
        && state.cycleKey == data.currentCycleKey
        && state.status == expectedStatus;
    }` + source.slice(state.end);
  assert.ok(!/\batomic(?:ExpectedTargetStateMatches|ExpectedTargetMatches|AllExpectedTargetsMatch)\s*\(/.test(source));
  return source;
}
