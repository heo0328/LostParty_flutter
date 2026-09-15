import fs from 'node:fs';

const rulesPath = new URL('../firestore.rules', import.meta.url);
const rules = fs.readFileSync(rulesPath, 'utf8').replace(/\r\n/g, '\n');

function braceDiff(source) {
  const stripped = source.replace(/\{[a-zA-Z][a-zA-Z0-9]*\}/g, '__PATH__');
  let depth = 0;
  for (const line of stripped.split('\n')) {
    depth += (line.match(/\{/g) ?? []).length;
    depth -= (line.match(/\}/g) ?? []).length;
  }
  return depth;
}

function extractFunctions(source) {
  const functions = new Map();
  const fnStart = /^\s*function\s+(\w+)\s*\(/gm;
  let match;
  while ((match = fnStart.exec(source)) !== null) {
    const name = match[1];
    const start = match.index;
    let i = source.indexOf('{', fnStart.lastIndex);
    if (i < 0) {
      throw new Error(`Missing body for function ${name}`);
    }
    let depth = 0;
    let end = -1;
    for (; i < source.length; i += 1) {
      const ch = source[i];
      if (ch === '{') depth += 1;
      if (ch === '}') {
        depth -= 1;
        if (depth === 0) {
          end = i + 1;
          break;
        }
      }
    }
    if (end < 0) {
      throw new Error(`Unclosed body for function ${name}`);
    }
    let blockStart = start;
    while (blockStart > 0 && source[blockStart - 1] !== '\n') {
      blockStart -= 1;
    }
    let blockEnd = end;
    if (blockEnd < source.length && source[blockEnd] === '\n') {
      blockEnd += 1;
    }
    functions.set(name, {
      name,
      blockStart,
      blockEnd,
      body: source.slice(start, end),
    });
    fnStart.lastIndex = end;
  }
  return functions;
}

const functions = extractFunctions(rules);
const fnNames = [...functions.keys()];
const callees = new Map(fnNames.map((name) => [name, new Set()]));
for (const name of fnNames) {
  const body = functions.get(name).body;
  for (const other of fnNames) {
    if (other !== name && body.includes(`${other}(`)) {
      callees.get(name).add(other);
    }
  }
}

const allowIdx = rules.indexOf('match /authBindings');
if (allowIdx < 0) {
  throw new Error('Could not locate allow rules block');
}
const allowBlock = rules.slice(allowIdx);
const roots = new Set(fnNames.filter((name) => allowBlock.includes(`${name}(`)));
const reachable = new Set(roots);
const stack = [...roots];
while (stack.length > 0) {
  const name = stack.pop();
  for (const dep of callees.get(name) ?? []) {
    if (!reachable.has(dep)) {
      reachable.add(dep);
      stack.push(dep);
    }
  }
}

const unused = fnNames
  .filter((name) => !reachable.has(name))
  .sort((a, b) => functions.get(b).blockStart - functions.get(a).blockStart);

let pruned = rules;
for (const name of unused) {
  const { blockStart, blockEnd } = functions.get(name);
  pruned = pruned.slice(0, blockStart) + pruned.slice(blockEnd);
}

const staleNeedle = 'function validAtomicStaleRaidStateDelete(playerId, stateId, oldData)';
const staleStart = pruned.indexOf(staleNeedle);
if (staleStart >= 0) {
  const staleEnd = pruned.indexOf(
    'function validAtomicInitialLeaderMembership',
    staleStart,
  );
  const staleBlock = pruned.slice(staleStart, staleEnd);
  const fixedBlock = staleBlock.replace(
    /return hasActiveBinding\(\)\n\s+&& playerId == currentPlayerId\(\)/,
    "return hasActiveBinding()\n        && stateId == oldData.characterId + '_' + oldData.raidId\n        && playerId == currentPlayerId()",
  );
  pruned = pruned.slice(0, staleStart) + fixedBlock + pruned.slice(staleEnd);
}

if (!/^\s*function\s+\w+\s*\(/m.test(pruned)) {
  throw new Error('Function declarations look malformed after prune');
}
if (pruned.includes('}function ') || /\n\s*unction valid/.test(pruned)) {
  throw new Error('Detected truncated function keyword after prune');
}

const diff = braceDiff(pruned);
if (diff !== 0) {
  throw new Error(`Brace imbalance after prune: ${diff}`);
}

fs.writeFileSync(rulesPath, pruned);
console.log(`Removed ${unused.length} unused functions. Reachable ${reachable.size}.`);
