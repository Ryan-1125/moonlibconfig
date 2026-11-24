import {spawnSync} from 'node:child_process';
import {writeFileSync,mkdirSync} from 'node:fs';
import {resolve} from 'node:path';
const root=resolve(import.meta.dirname,'..'), work=resolve(root,'.local/semantic-edit');
mkdirSync(work,{recursive:true});
const input='mask=0xFFFFFFFFL; bits=0x100000000L; port=9000; text="\\xFF"; nested={ok=true;};';
const moon=spawnSync('moon',['run','tools/semantic-edit','--target','js','--quiet'],{cwd:root,encoding:'utf8',shell:process.platform==='win32'});
if(moon.status!==0) throw Error(moon.stderr);
const lines=moon.stdout.trim().split(/\r?\n/);
if(lines.shift()!=='8080') throw Error('edit target did not change');
const output=lines.join('\n');
function read(text,name){
 const file=resolve(work,name+'.cfg');writeFileSync(file,text);
 const r=spawnSync(resolve(root,'.local/upstream/oracle.exe'),[file],{encoding:'utf8'});
 if(r.status!==0) throw Error(r.stderr);
 return JSON.parse(r.stdout);
}
const before=read(input,'before'),after=read(output,'after');
const expected=structuredClone(before);
const port=expected[1].find(pair=>pair[0]===Buffer.from('port').toString('hex'));
if(port[1][0]!=='integer'||port[1][1]!=='9000') throw Error('wrong initial port');
port[1][1]='8080';
if(JSON.stringify(expected)!==JSON.stringify(after))throw Error('unrelated setting value/type changed');
const report={reference:'libconfig 1.8.2 Windows/MSVC',operation:'replace port 9000 with 8080; return original text to same application',input,output,before,after,result:'all unrelated values and types preserved'};
writeFileSync(resolve(work,'report.json'),JSON.stringify(report,null,2));
console.log(JSON.stringify(report,null,2));
