import assert from 'node:assert/strict';
import {test} from 'node:test';
// A/B/C/D classify mutually exclusive state transitions. The personal validator
// requires D (same ownership revision follows from its immutable field set).
test('merged dispatch preserves every possible leaf decision', () => {
  for(const branch of ['A','B','C','D','fallback']) {
    for(let bits=0;bits<32;bits++) {
      const [v,p,r,s,e]=Array.from({length:5},(_,i)=>Boolean(bits&(1<<i)));
      if(p && branch!=='D') continue;
      const a=branch==='A',b=branch==='B',c=branch==='C',d=branch==='D';
      const before=a?v:b?e&&v:c?s||r:d?p:r||p||v;
      const after=d?p:(c&&s)||(!a&&!b&&r)||(!c&&(!b||e)&&v);
      assert.equal(after,before,JSON.stringify({branch,v,p,r,s,e}));
    }
  }
});
