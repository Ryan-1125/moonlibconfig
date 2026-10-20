// Original fixed and generated inputs; no upstream test fixtures are copied.
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { resolve } from 'node:path';

const root = resolve(import.meta.dirname, '..');
const work = resolve(root, '.local/differential');
mkdirSync(work, { recursive: true });
const oracle = resolve(root, '.local/upstream/oracle.exe');
const cases = [
  '', 'a=1', 'a=1 b=2', 'a:1;', 'a=1,', 'a=1;;',
  'a={} b=[] c=()', 'a={b=({x=1},[2,3],true)}', 'a=[1,2,]', 'a=(1,2L,true,)',
  'a=[1,2L]', 'a=[{}]', 'a=1 a=2', '_x=1', '*x=1', 'a-b_2=1',
  '#first\na=1 // two\nb=2 /* three */', 'a=1 /*', 'a=', 'a={', 'a=(1 2)',
  'a="hello" /*x*/ " world"', 'a="月亮"', 'a="\\xFF\\x80"',
  'a="\\a\\b\\f\\n\\r\\t\\v\\\\\\\""', 'a="\\u1234"', 'a="\\xG0"', 'a="\\x0"',
  'a="line\nbreak"', 'a="\\x00after"', 'a=TRUE b=fAlSe', 'a=yes',
  ...['0','+1','-1','01','2147483647','2147483648','-2147483648','-2147483649',
    '9223372036854775807','-9223372036854775808','9223372036854775808','-9223372036854775809',
    '1L','1LL','1l','1ll','0xffffffff','0xFFFFFFFFL','0xffffffffffffffff','0x100000000',
    '0b1011','0b11111111111111111111111111111111','0o755','0q755','0o77777777777',
    '0x','0b2','0XFF','-0x1','+0x1','1.0','.5','1.','1e3','1.e3','-0.0',
    '1e-20','1e999','1e-999','NaN','Infinity','1.0L','1e','--1'].map(x => `a=${x}`),
];
// Deterministic generated nested configurations and numeric boundaries.
for (let i = 0; i < 24; i++) cases.push(`s${i}={port=${8000+i}; tag="n${i}"; values=[${i},${i+1}]; peers=({ok=true},${i}L)}`);
for (const n of [Number.MIN_VALUE, Number.MAX_VALUE, Math.PI, Math.E, 1e20, -1e20, 1e-20, -1e-20]) cases.push(`a=${n.toExponential(17)}`);
let seed=0x12345678;
for(let i=0;i<32;i++) {
  seed ^= seed << 13; seed ^= seed >>> 17; seed ^= seed << 5;
  cases.push(`a=${((seed|0)*Math.pow(10,(i%41)-20)).toExponential(17)}`);
}
const byteLiteral = b => 'b"' + [...b].map(n => '\\x'+n.toString(16).padStart(2,'0')).join('') + '"';
const moonCases = cases.map(x => byteLiteral(Buffer.from(x)));
const casesFile=resolve(root,'tools/bridge/cases.mbt');
const originalCases=readFileSync(casesFile);
try {
writeFileSync(casesFile, `// Generated from original differential inputs.\n///|\nfn cases() -> Array[Bytes] { [${moonCases.join(',\n')}] }\n`);
function runMoon() {
  const result = spawnSync('moon', ['run','tools/bridge','--target','js','--quiet'], {cwd:root,encoding:'utf8',shell:process.platform==='win32'});
  if(result.status!==0) throw new Error(result.stderr || result.stdout);
  return result.stdout.trim().split(/\r?\n/).map(x=>JSON.parse(x));
}
function readOracle(input, name) {
  const file = resolve(work, name+'.cfg'), output = resolve(work,name+'.out.cfg');
  writeFileSync(file,input);
  const result=spawnSync(oracle,[file,output],{encoding:'utf8'});
  if(result.error) throw result.error;
  if(result.status!==0 && result.status!==2) throw new Error(`oracle failed: ${result.status}: ${result.stderr}`);
  return result.status===0 ? {ok:true,tree:JSON.parse(result.stdout),output:readFileSync(output)} : {ok:false,error:result.stderr.trim()};
}
function same(a,b) {
  if(a[0]!==b[0]) return false;
  if(a[0]==='float') return Object.is(Number(a[1]),Number(b[1]));
  if(['group','array','list'].includes(a[0])) {
    if(a[1].length!==b[1].length) return false;
    return a[1].every((x,i)=> a[0]==='group' ? x[0]===b[1][i][0]&&same(x[1],b[1][i][1]) : same(x,b[1][i]));
  }
  return a[1]===b[1];
}
const actual=runMoon();
if(actual.length!==cases.length) throw new Error('missing MoonBit results');
const records=[];
const upstreamOutputs=[];
for(let i=0;i<cases.length;i++) {
  const expected=readOracle(cases[i],'input-'+i), result=actual[i];
  let issue=null;
  if(expected.ok!==result[0]) issue='acceptance';
  else if(expected.ok && !same(expected.tree,result[1])) issue='tree';
  if(expected.ok && result[0] && same(expected.tree,result[1])) {
    const back=readOracle(result[2],'moon-output-'+i);
    if(!back.ok || !same(expected.tree,back.tree)) issue='moon-output';
    upstreamOutputs.push({index:i,bytes:expected.output,tree:expected.tree});
  }
  records.push({index:i,input:cases[i],upstreamAccepted:expected.ok,moonAccepted:result[0],issue,upstream:expected.ok?expected.tree:expected.error,moon:result[1]});
}
// Feed the upstream writer's real output back through MoonBit.
writeFileSync(casesFile, `// Generated upstream writer output used only as external test input.\n///|\nfn cases() -> Array[Bytes] { [${upstreamOutputs.map(x=>byteLiteral(x.bytes)).join(',\n')}] }\n`);
const reread=runMoon();
for(let i=0;i<upstreamOutputs.length;i++) {
  const source=upstreamOutputs[i];
  if(!reread[i][0]||!same(source.tree,reread[i][1])) records[source.index].issue='upstream-output';
}
const differences=records.filter(x=>x.issue);
writeFileSync(resolve(work,'report.json'),JSON.stringify({version:'1.8.2',commit:'a42cb47c1526a4f2ed025fcbb2289863375bc898',cases:cases.length,roundtrips:upstreamOutputs.length,differences,records},null,2));
const expectedFile=resolve(root,'tools/expected-differences-windows.json');
let documented=[];
try { documented=JSON.parse(readFileSync(expectedFile,'utf8')); } catch {}
const signature=x=>JSON.stringify([x.input,x.upstreamAccepted,x.moonAccepted,x.issue,x.upstream,x.moon]);
const unexpected=differences.filter(x=>!documented.some(y=>signature(x)===signature(y)));
const missing=documented.filter(x=>!differences.some(y=>signature(x)===signature(y)));
console.log(JSON.stringify({cases:cases.length,roundtrips:upstreamOutputs.length,documentedDifferences:differences.length,unexpected,missing},null,2));
if(unexpected.length||missing.length) process.exitCode=1;
} finally {
  writeFileSync(casesFile,originalCases);
}
