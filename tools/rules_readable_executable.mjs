import assert from 'node:assert/strict';

// Rename callable identifiers only. Fields, string literals and path segments
// remain byte-for-byte intact; historical transforms keep their input names.
export function readableExecutableRules(source) {
  const names = [...source.matchAll(/\bfunction\s+(\w+)\s*\(/g)].map(match => match[1]);
  const explicit = {
    sealIdle: 'isAvailabilityOnlyState',
    sealAudit: 'validAvailabilityAudit',
    sealPrepared: 'hasPreparedAvailabilityAudit',
    sealAdvance: 'validAuditedCycleAdvance',
    sealBlocksClaimAt: 'availabilityAuditBlocksClaimAt',
    sealRemoved: 'availabilityAuditRemoved',
    sealNormalReplacement: 'validAvailabilityAuditReplacement',
    sealParticipateIdle: 'validAvailabilityStubParticipation',
    bug24Unchanged: 'documentUnchangedAfterWrite',
    bug24PrepState: 'isNextWeekPreparationState',
    bug24Advancing: 'isCycleAdvancing',
    bug24PrepDispatch: 'isNextWeekMemberPreparation',
    bug24KnownCompleted: 'isKnownCompletedParticipation',
    bug24AssignmentAvailable: 'isPreparationAssignmentAvailable',
    sparkPrepKnownCompleted: 'isOwnedCompletedPreparationRecord',
    sparkPrepRecords: 'validPreparationRecords',
    bug24PrepListing: 'validPreparationListing',
    bug24PrepEvent: 'validPreparationEvent',
    bug24PrepPair: 'validPreparationMemberPair',
    bug24PrepAggregate: 'validPreparationRecruitment',
    bug24PrepMember: 'validPreparationMembership',
  };
  const functions = Object.fromEntries(names.map(name => [name,
    explicit[name] ?? (name.startsWith('de') && /^de[A-Z]/.test(name)
      ? `ownership${name.slice(2)}` : name)]));
  assert.equal(new Set(Object.values(functions)).size, names.length, 'name collision');
  const tokens = source.match(/\/\/[^\n]*|\/\*[\s\S]*?\*\/|'(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*"|\s+|[A-Za-z_][A-Za-z_0-9]*|[^\s]/g);
  assert.equal(tokens.join(''), source);
  const isTrivia = token => /^\s+$/.test(token) || token.startsWith('//') || token.startsWith('/*');
  const edits = [];
  for (let index = 0; index < tokens.length; index++) {
    if (!Object.hasOwn(functions, tokens[index])) continue;
    let next = index + 1;
    while (next < tokens.length && isTrivia(tokens[next])) next++;
    if (tokens[next] !== '(') continue;
    edits.push([index, tokens[index]]);
    tokens[index] = functions[tokens[index]];
  }
  const result = tokens.join('');
  for (const [index, original] of edits) tokens[index] = original;
  assert.equal(tokens.join(''), source, 'only function identifiers may change');
  return { source: result, functions };
}
