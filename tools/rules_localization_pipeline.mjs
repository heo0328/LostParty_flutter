import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {canonicalListings} from './rules_listing_candidate.mjs';
import {leaderBudgetCandidate} from './rules_leader_budget_candidate.mjs';
import {personalBudgetCandidate} from './rules_personal_budget_candidate.mjs';
import {depthRecheckCandidate} from './rules_depth_recheck_candidate.mjs';
import {memberRetirementCandidate} from './rules_member_retirement_candidate.mjs';
import {localizeGroupDisplay} from './rules_local_display.mjs';
import {rulesFunction} from './roster_complexity_candidate.mjs';
import {compactExecutableRules} from './rules_executable_compact.mjs';

export function localizationPipeline(input){
  const stages=[];
  const measure=(name,source)=>{const compact=compactExecutableRules(source).source;
    stages.push({name,bytes:Buffer.byteLength(compact),sha256:createHash('sha256').update(compact).digest('hex')});return source;};
  let source=measure('tracked-baseline',input);
  assert.equal(stages[0].sha256,'408f163fc6bf6f06d8a7a628da2e1b2bdd2747d36936d7b2aee995c161e53793');
  source=measure('R1-canonical-listing',canonicalListings(source));
  source=leaderBudgetCandidate(source);
  const unused=rulesFunction(source,'atomicHasGroupId');source=source.slice(0,unused.start)+source.slice(unused.end);
  source=measure('A2-leader-dispatch',source);
  source=measure('B-F1-personal-dispatch',personalBudgetCandidate(source));
  source=measure('B-depth',depthRecheckCandidate(source).readable);
  source=measure('C1-member-retirement',memberRetirementCandidate(source).readable);
  source=measure('local-display-and-common-projection',localizeGroupDisplay(source));
  return {source,stages};
}
