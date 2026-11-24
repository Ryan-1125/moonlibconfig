import {spawnSync} from 'node:child_process';
import {writeFileSync,mkdirSync} from 'node:fs';
import {resolve} from 'node:path';
const root=resolve(import.meta.dirname,'..'),work=resolve(root,'.local/semantic-edit');
mkdirSync(work,{recursive:true});
const oracle=resolve(root,process.platform==='win32'?'.local/upstream/oracle.exe':'.local/upstream/oracle');
const input='mask=0xFFFFFFFFL; bits=0x100000000L; port=9000; ratio=-0.0; text="\\xFF"; title="moon"; numbers=[1,2]; nested={ok=true;};';
const moon=spawnSync('moon',['run','tools/semantic-edit','--target','js','--quiet'],{cwd:root,encoding:'utf8',shell:process.platform==='win32'});
if(moon.status!==0)throw Error(moon.stderr);
const rows=moon.stdout.trim().split(/\r?\n/).map(JSON.parse);
function read(text,name){
 const file=resolve(work,name+'.cfg');writeFileSync(file,text);
 const r=spawnSync(oracle,[file],{cwd:work,encoding:'utf8'});
 if(r.status!==0)throw Error(r.stderr);
 return JSON.parse(r.stdout);
}
function set(tree,path,value){
 let current=tree;
 const parts=path.split('.');
 for(const part of parts.slice(0,-1)){
  current=current[1].find(pair=>pair[0]===Buffer.from(part).toString('hex'))[1];
 }
 const pair=current[1].find(pair=>pair[0]===Buffer.from(parts.at(-1)).toString('hex'));
 if(!pair)throw Error('missing target '+path);
 pair[1]=value;
}
function same(a,b){
 if(a[0]!==b[0])return false;
 if(a[0]==='float')return Object.is(Number(a[1]),Number(b[1]));
 if(a[0]==='group')return a[1].length===b[1].length&&a[1].every((p,i)=>p[0]===b[1][i][0]&&same(p[1],b[1][i][1]));
 if(a[0]==='array'||a[0]==='list')return a[1].length===b[1].length&&a[1].every((v,i)=>same(v,b[1][i]));
 return a[1]===b[1];
}
const targets={
 port:['integer','8080'],mask:['integer64','4294967295'],
 title:['string','6e6577'],numbers:['array',[['integer','1'],['integer','3']]],
 'nested.ok':['boolean',false],ratio:['float','0.125'],text:['string','80']
};
const reports=[];
for(const [path,output] of rows){
 if(path==='include-child'){
  const main='service={\n@include "child.cfg"\n}\nport=9000;';
  writeFileSync(resolve(work,'child.cfg'),'mask=0xFFFFFFFFL; bits=0x100000000L;');
  const before=read(main,'multi-before');
  writeFileSync(resolve(work,'child.cfg'),output);
  const after=read(main,'multi-after'),expected=structuredClone(before);
  set(expected,'service.bits',['integer64','5']);
  if(!same(expected,after))throw Error('multifile unrelated semantic change');
  reports.push({path:'service.bits',mode:'original root and edited included child',before,after,result:'passed'});
 }else{
  if(!targets[path])throw Error('unexpected edit '+path);
  const before=read(input,path.replaceAll('.','-')+'-before'),after=read(output,path.replaceAll('.','-')+'-after');
  const expected=structuredClone(before);set(expected,path,targets[path]);
  if(!same(expected,after))throw Error('unrelated value/type changed: '+path);
  reports.push({path,input,output,before,after,result:'passed'});
 }
}
if(reports.length!==8)throw Error('missing edit cases');
const report={reference:'libconfig 1.8.2',platform:process.platform,cases:reports.length,result:'all unrelated values and types preserved',reports};
writeFileSync(resolve(work,'report.json'),JSON.stringify(report,null,2));
console.log(JSON.stringify({cases:reports.length,platform:process.platform,result:report.result}));
