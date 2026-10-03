// Read-only source audit. Reports static reachability, not compiled bytecode or runtime cost.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
const source = fs.readFileSync('firestore.rules', 'utf8').replace(/\r\n/g, '\n');
const masked = source.replace(/'(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*"|\/\/[^\n]*|\/\*[\s\S]*?\*\//g,
  s => s.replace(/[^\n]/g, ' '));
const line = pos => source.slice(0,pos).split('\n').length;
function close(open) {
  let depth=1, i=open+1;
  while (depth && i<masked.length) { if(masked[i]==='{')depth++;if(masked[i]==='}')depth--;i++; }
  assert.equal(depth,0);return i;
}
const functions=[...masked.matchAll(/\bfunction\s+(\w+)\s*\(/g)].map(m=>{
  const open=masked.indexOf('{',m.index),end=close(open);
  return {name:m[1],line:line(m.index),start:m.index,end,body:source.slice(open+1,end-1),bytes:Buffer.byteLength(source.slice(m.index,end))};
});
const names=new Set(functions.map(f=>f.name));
assert.equal(names.size,functions.length);
const calls = text => [...text.matchAll(/\b(\w+)\s*\(/g)].map(m=>m[1]).filter(n=>names.has(n));
for(const f of functions) f.calls=calls(masked.slice(masked.indexOf('{',f.start)+1,f.end-1));
// Match captures contain braces; the body opening is the brace after its path and whitespace.
const matches=[...masked.matchAll(/\bmatch\s+([^\n]+?)\s+\{/g)].map(m=>({path:source.slice(m.index+6,m.index+m[0].length-1).trim(),start:m.index,end:close(m.index+m[0].length-1)}));
const allows=[...masked.matchAll(/\ballow\s+([^:]+):\s*if\s*([\s\S]*?);/g)].map(m=>({
  line:line(m.index),path:matches.filter(x=>x.start<m.index&&x.end>m.index).map(x=>x.path).join(''),
  operations:m[1].trim(),calls:calls(m[2]),bytes:Buffer.byteLength(source.slice(m.index,m.index+m[0].length)),
}));
const byName=new Map(functions.map(f=>[f.name,f]));
function walk(name,stack=[]) {
  assert.ok(!stack.includes(name),'recursive call '+[...stack,name].join(' -> '));
  return [name,...byName.get(name).calls.flatMap(n=>walk(n,[...stack,name]))];
}
const reached=new Set();
for(const a of allows){a.reachable=[...new Set(a.calls.flatMap(n=>walk(n)))];a.reachable.forEach(n=>reached.add(n));}
function depth(n){return 1+Math.max(0,...byName.get(n).calls.map(depth));}
const groups=new Map();
for(const f of functions){const key=f.body.replace(/\s+/g,' ').trim();groups.set(key,[...(groups.get(key)??[]),f.name]);}
const report={sha256:createHash('sha256').update(source).digest('hex'),bytes:Buffer.byteLength(source),
  functionCount:functions.length,matchCount:matches.length,allowCount:allows.length,
  maximumHelperDepth:Math.max(...functions.map(f=>depth(f.name))),
  unreachable:functions.filter(f=>!reached.has(f.name)).map(f=>f.name),
  identicalBodies:[...groups.values()].filter(x=>x.length>1),
  allows,functions:functions.map(({body,start,end,...f})=>({...f,reachable:reached.has(f.name)}))};
fs.mkdirSync('coverage/rules-audit',{recursive:true});
fs.writeFileSync('coverage/rules-audit/source-inventory.json',JSON.stringify(report,null,2));
console.log(JSON.stringify({...report,allows:undefined,functions:undefined},null,2));
