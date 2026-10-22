import express from 'express';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StreamableHTTPServerTransport } from '@modelcontextprotocol/sdk/server/streamableHttp.js';
import { ListToolsRequestSchema,CallToolRequestSchema,isInitializeRequest } from '@modelcontextprotocol/sdk/types.js';
import { readFileSync,writeFileSync,existsSync } from 'node:fs';
import { randomUUID,timingSafeEqual } from 'node:crypto';
import path from 'node:path';
import { execFile } from 'node:child_process';
import { fileURLToPath } from 'node:url';
const appVersion=JSON.parse(readFileSync(new URL('./app-version.json',import.meta.url),'utf8').replace(/^\uFEFF/,'')).version;

const config=JSON.parse(readFileSync(process.argv[2],'utf8').replace(/^\uFEFF/,''));
const key=process.env.LUCY_MCP_KEY;
delete process.env.LUCY_MCP_KEY;
delete process.env.NGROK_AUTHTOKEN;
if(!key || key.length<32) throw new Error('Missing bridge key');
const dataDir=path.dirname(process.argv[2]);
const statusFile=path.join(dataDir,'bridge-status.json');
const stopFile=path.join(dataDir,'stop');
const clients=[];
let xurrentTransport;
let startupStage='Lucy: inicializar MCP';
let startupPending=true;
const startupErrors=new Map();
function captureStartupError(label,stream){
 stream?.on('data',chunk=>{
  if(startupPending)startupErrors.set(label,((startupErrors.get(label)||'')+chunk.toString()).slice(-6000));
 });
}
function safeDiagnostic(value){
 return String(value).split(key).join('[REDACTED]')
  .replace(/Bearer\s+[^\s"']+/gi,'Bearer [REDACTED]')
  .replace(/((?:password|senha|token|secret|api[-_ ]?key)["']?\s*[:=]\s*)(?:"[^"]*"|'[^']*'|[^\s,;]+)/gi,'$1[REDACTED]');
}
function reportStartupFailure(error){
 console.error('Lucy MCP v'+appVersion+' - Falha ao iniciar MCP. Etapa: '+startupStage);
 console.error(safeDiagnostic(error?.message||error));
 for(const [label,tail]of startupErrors)console.error('--- '+label+' (stderr de inicializacao) ---\n'+safeDiagnostic(tail));
}
async function closeUpstreams(){
 // Stop the owned BAT tree while its stdio wrapper PID is still live.
 if(xurrentTransport?.pid){
  await new Promise(resolve=>execFile('taskkill.exe',['/PID',String(xurrentTransport.pid),'/T','/F'],{windowsHide:true},()=>resolve()));
 }
 await Promise.allSettled(clients.map(c=>c.close()));
}
async function readCatalog(c){
 const all=[];let cursor;
 do{const page=await c.listTools(cursor?{cursor}:{});all.push(...page.tools);cursor=page.nextCursor;}while(cursor);
 return all;
}
const client=new Client({name:'lucy-team-bridge',version:appVersion});
clients.push(client);
const stdio=new StdioClientTransport({command:config.node,args:[config.script],stderr:'pipe'});
captureStartupError('Lucy',stdio.stderr);
const startupTimer=setTimeout(()=>{reportStartupFailure('MCP initialization timed out');void closeUpstreams().finally(()=>process.exit(1))},145000);
const routes=new Map();
let lucyTools=0,xurrentTools=0;
let upstream;
try{
 await client.connect(stdio);
 startupStage='Lucy: listar ferramentas';
 upstream=await readCatalog(client);lucyTools=upstream.length;
 for(const t of upstream)routes.set(t.name,{client,tool:t});
 if(config.xurrentPath){
  startupStage='Xurrent: inicializar MCP pelo BAT';
  const bat=path.join(config.xurrentPath,'iniciar-mcp.bat');
  const entry=path.join(config.xurrentPath,'mcp-server','server.js');
  if(!existsSync(bat)||!existsSync(entry))throw new Error('Configured Xurrent folder is incomplete');
  const xc=new Client({name:'lucy-xurrent-bridge',version:appVersion});clients.push(xc);
  // The BAT itself starts the only server process. Filter its banners outside MCP.
  const helper=fileURLToPath(new URL('./xurrent-bat-transport.mjs',import.meta.url));
  const xt=new StdioClientTransport({command:config.node,args:[helper,bat,dataDir],cwd:config.xurrentPath,env:{...process.env,XURRENT_MCP_PORT:'9595'},stderr:'pipe'});
  xurrentTransport=xt;
  captureStartupError('Xurrent MCP',xt.stderr);
  await xc.connect(xt);
  startupStage='Xurrent: listar ferramentas';
  const catalog=await readCatalog(xc);xurrentTools=catalog.length;
  for(const t of catalog){
   const name='xurrent_'+t.name;
   if(routes.has(name))throw new Error('Duplicate MCP tool name');
   routes.set(name,{client:xc,tool:t});
   upstream.push({...t,name});
  }
 }
}catch(err){clearTimeout(startupTimer);reportStartupFailure(err);await closeUpstreams();process.exit(1);}
clearTimeout(startupTimer);
startupPending=false;startupErrors.clear();
const tools=upstream.map(t=>{
 if(!config.connection || !t.inputSchema?.properties?.connection) return t;
 return {...t,inputSchema:{...t.inputSchema,properties:{...t.inputSchema.properties,connection:{...t.inputSchema.properties.connection,enum:[config.connection],default:config.connection}}}};
});
const sessions=new Map();
let serial=Promise.resolve();
const app=express();app.disable('x-powered-by');
app.use((req,res,next)=>{
 const hosts=[`127.0.0.1:${config.port}`,`localhost:${config.port}`];
 if(!hosts.includes(req.headers.host))return res.status(403).send('Invalid host');
 if(req.headers.origin && !hosts.map(h=>'http://'+h).includes(req.headers.origin))return res.status(403).send('Invalid origin');
 const got=Buffer.from(req.headers.authorization??'');const expected=Buffer.from('Bearer '+key);
 if(got.length!==expected.length || !timingSafeEqual(got,expected))return res.set('WWW-Authenticate','Bearer realm="lucy"').status(401).send('unauthorized');
 next();
});
app.get('/status',(_req,res)=>res.json({ready:true,version:appVersion,tools:tools.length,lucyTools,xurrentTools,connection:config.connection||null}));
app.use(express.json({limit:'1mb'}));
app.all('/mcp',async(req,res)=>{
 try{
  const id=req.headers['mcp-session-id'];let entry=id?sessions.get(id):null;
  if(!entry){
   if(id)return res.status(404).send('Unknown session');
   if(req.method!=='POST'||!isInitializeRequest(req.body))return res.status(400).send('Initialize required');
   if(sessions.size>=16)return res.status(503).send('Session limit');
   const server=new Server({name:'lucy-team-http',version:appVersion},{capabilities:{tools:{}}});
   server.setRequestHandler(ListToolsRequestSchema,async()=>({tools}));
   server.setRequestHandler(CallToolRequestSchema,async(request)=>{
    const route=routes.get(request.params.name);if(!route)throw new Error('Unknown tool');
    const tool=route.tool;
    const args={...(request.params.arguments??{})};
    if(route.client===client && config.connection && tool.inputSchema?.properties?.connection){
     if(args.connection && args.connection!==config.connection)throw new Error('Connection outside configured scope');
     args.connection=config.connection;
    }
    // Serialized calls avoid simultaneous global switches within this instance.
    const call=serial.then(()=>route.client.callTool({name:tool.name,arguments:args},undefined,{timeout:90000}));
    serial=call.catch(()=>{});return await call;
   });
   const transport=new StreamableHTTPServerTransport({sessionIdGenerator:()=>randomUUID(),enableJsonResponse:true,onsessioninitialized:sid=>sessions.set(sid,entry)});
   entry={server,transport,touched:Date.now()};transport.onclose=()=>sessions.delete(transport.sessionId);
   await server.connect(transport);
  }
  entry.touched=Date.now();await entry.transport.handleRequest(req,res,req.body);
 }catch{if(!res.headersSent)res.status(502).send('MCP request failed');}
});
const listener=app.listen(config.port,'127.0.0.1',()=>{
 writeFileSync(statusFile,JSON.stringify({ready:true,version:appVersion,pid:process.pid,tools:tools.length,lucyTools,xurrentTools,port:config.port,connection:config.connection||null}));
 console.log('Lucy MCP v'+appVersion+' bridge ready');
});
let stopping=false;
async function stop(){if(stopping)return;stopping=true;clearInterval(timer);listener.close();await Promise.allSettled([...sessions.values()].map(e=>e.server.close()));await closeUpstreams();writeFileSync(statusFile,JSON.stringify({ready:false}));process.exit(0);}
const timer=setInterval(()=>{
 if(existsSync(stopFile)){void stop();return;}
 for(const [id,e]of sessions)if(Date.now()-e.touched>900000){sessions.delete(id);void e.server.close();}
},1000);
process.on('SIGINT',stop);process.on('SIGTERM',stop);
process.on('uncaughtException',()=>{console.error('Bridge stopped unexpectedly');void stop();});
