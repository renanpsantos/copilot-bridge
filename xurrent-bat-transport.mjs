// Preserve MCP stdin/stdout while executing the project's original startup BAT once.
import {spawn} from 'node:child_process';
import {readFileSync,writeFileSync} from 'node:fs';
import path from 'node:path';
import {createInterface} from 'node:readline';
const [bat,dataDir]=process.argv.slice(2);
if(!bat||!dataDir)throw new Error('Xurrent launcher configuration missing');
const root=path.dirname(bat);
if(/[%!^"\r\n]/.test(root)||/[%!^"\r\n]/.test(dataDir))throw new Error('Unsupported special character in Xurrent folder');
// CMD requires CRLF reliably. The execution copy preserves the original %~dp0.
const original=readFileSync(bat,'utf8').replace(/^\uFEFF/,'');
const normalized=original.replace(/%~dp0/gi,()=>root+path.sep).replace(/\r?\n/g,'\r\n');
const generated=path.join(dataDir,'xurrent-start.generated.cmd');
writeFileSync(generated,normalized,'utf8');
const env={...process.env,PATH:path.dirname(process.execPath)+';'+(process.env.PATH||'')};
delete env.LUCY_MCP_KEY;delete env.NGROK_AUTHTOKEN;
const child=spawn(process.env.ComSpec||'cmd.exe',['/d','/s','/c','""'+generated+'""'],{
 cwd:root,env,windowsHide:true,windowsVerbatimArguments:true,stdio:['pipe','pipe','pipe']
});
process.stdin.pipe(child.stdin);
process.stdin.on('error',()=>{});child.stdin.on('error',()=>{});
child.stderr.pipe(process.stderr);
const lines=createInterface({input:child.stdout,crlfDelay:Infinity});
lines.on('line',line=>{
 const clean=line.replace(/^\uFEFF/,'').trim();
 try{
  const msg=JSON.parse(clean);
  if(msg && msg.jsonrpc==='2.0')process.stdout.write(clean+'\n');
  else if(clean)process.stderr.write('[Xurrent BAT] '+clean+'\n');
 }catch{if(clean)process.stderr.write('[Xurrent BAT] '+clean+'\n')}
});
child.on('error',error=>{console.error('Xurrent BAT failed: '+error.message);process.exit(1)});
child.on('exit',code=>process.exit(code??1));
