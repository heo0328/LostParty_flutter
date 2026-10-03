import fs from 'node:fs';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
const source=fs.readFileSync('firestore.rules','utf8').replace(/\r\n/g,'\n');
// Only whitespace, comments and custom function identifiers change. Strings and
// every operator/path/field token are preserved. Never run against the backup.
const tokenPattern=/\/\/[^\n]*|\/\*[\s\S]*?\*\/|'(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*"|\s+|[A-Za-z_][A-Za-z_0-9]*|[^\s]/g;
const tokens=source.match(tokenPattern);
assert.equal(tokens.join(''),source);
const names=[...source.matchAll(/\bfunction\s+(\w+)\s*\(/g)].map(m=>m[1]);
assert.equal(new Set(names).size,names.length);
const mapping=new Map(names.map((n,i)=>[n,`rf${i}`]));
for(const n of mapping.values())assert.ok(!tokens.includes(n),'new identifier collision');
const comments=t=>t.startsWith('//')||t.startsWith('/*');
const significant=tokens.filter(t=>!comments(t)&&!/^\s+$/.test(t));
const rewritten=significant.map((t,i)=>mapping.has(t)&&significant[i+1]==='('?mapping.get(t):t);
// Spaces between tokens are valid Rules lexical separators; keep the source's
// original token adjacency instead, compact only runs of whitespace/comments.
let out='';
for(let i=0;i<tokens.length;i++){
 const t=tokens[i];
 if(comments(t)){out+=' ';continue;}
 if(/^\s+$/.test(t)){out+=t.includes('\n')?'\n':' ';continue;}
 let next=i+1;while(next<tokens.length&&(comments(tokens[next])||/^\s+$/.test(tokens[next])))next++;
 out+=mapping.has(t)&&tokens[next]==='('?mapping.get(t):t;
}
out=out.split('\n').map(l=>l.trim()).filter(Boolean).join('\n')+'\n';
const reverse=new Map([...mapping].map(([a,b])=>[b,a]));
const actual=out.match(tokenPattern).filter(t=>!comments(t)&&!/^\s+$/.test(t));
assert.deepEqual(actual,rewritten);
assert.deepEqual(actual.map((t,i)=>reverse.has(t)&&actual[i+1]==='('?reverse.get(t):t),significant);
const dir='coverage/rules-source-compact';fs.mkdirSync(dir,{recursive:true});
fs.writeFileSync(dir+'/candidate.rules',out);
const hash=s=>createHash('sha256').update(s).digest('hex');
const manifest={sourceSha256:hash(source),candidateSha256:hash(out),sourceBytes:Buffer.byteLength(source),candidateBytes:Buffer.byteLength(out),functions:names.length,lexicalEquivalence:true};
fs.writeFileSync(dir+'/manifest.json',JSON.stringify(manifest,null,2));
fs.writeFileSync(dir+'/function-map.json',JSON.stringify(Object.fromEntries(mapping),null,2));
fs.writeFileSync(dir+'/firebase.json',JSON.stringify({firestore:{rules:'candidate.rules'}},null,2));
console.log(JSON.stringify(manifest));
